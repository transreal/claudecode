---
name: llm-extraction-pipeline
description: |
  LLM (Claude Code CLI / Anthropic API 等) を使った構造化情報抽出パイプライン
  の設計テンプレ。Schema 駆動 prompt 構築、頑健な JSON parser (bracket counting +
  truncated 復旧)、iSanitizeForJSON サニタイズ、verbose モードによる診断機構を
  含む。SourceVault.wl Stage 5 (Claim extraction) で実装済み・実証済み。
---

# LLM-Backed Extraction Pipeline 設計テンプレ

## 全体フロー

```
source text (page text, document, etc.)
  ↓ iBuildExtractionPrompt (schema → JSON shape を prompt に埋め込み)
prompt
  ↓ ClaudeCode`ClaudeQueryBg (NonBlocking, Timeout)
LLM JSON response (markdown fence / 解説文付き / truncated もありうる)
  ↓ iParseExtractionJSON (5 段階 fallback)
items (List of Association)
  ↓ iNormalizeClaim / iValidateClaim (ID 生成, ContentHash, Required field check)
records
  ↓ iSanitizeForJSON + JSONL append
ClaimStore (master + by-X indexes)
```

## 5 段階の堅牢な JSON parse

LLM 応答は形式が乱れがち。次の 5 段階 fallback で **可能な限り回収** する:

```mathematica
iParseExtractionJSON[respText_String, outputShape_String] :=
  Module[{cleaned, parsed, jsonBlock, recovered, fenceMatch},
    cleaned = StringTrim[respText];
    
    (* 1. markdown code fence 剥がし *)
    fenceMatch = StringCases[cleaned,
      RegularExpression["(?s)```(?:json)?\\s*(.+?)\\s*```"] :> "$1"];
    If[Length[fenceMatch] > 0, cleaned = First[fenceMatch]];
    cleaned = StringTrim[cleaned];
    
    (* 2. 空シグナル *)
    If[cleaned === "[]" || cleaned === "null" || cleaned === "",
      Return[<|"Status" -> "OK", "Items" -> {}|>]];
    
    (* 3. まず全体 parse *)
    parsed = Quiet[ImportString[cleaned, "RawJSON"]];
    
    (* 4. 失敗したら bracket extraction (解説文付き対応) *)
    If[parsed === $Failed,
      jsonBlock = iExtractFirstJSONBlock[cleaned];
      If[StringQ[jsonBlock],
        parsed = Quiet[ImportString[jsonBlock, "RawJSON"]]]];
    
    (* 5. まだ失敗なら partial recovery (truncated 復旧) *)
    If[parsed === $Failed,
      recovered = iRecoverPartialJSONArray[cleaned];
      If[ListQ[recovered] && Length[recovered] > 0,
        Return[<|"Status" -> "OK",
          "Items" -> recovered,
          "Note" -> "PartialRecovery: " <> ToString[Length[recovered]] <>
            " object(s) recovered from truncated response"|>]]];
    
    If[parsed === $Failed,
      Return[<|"Status" -> "Failed",
        "Reason" -> "JSONParseFailed",
        "Sample" -> StringTake[cleaned, UpTo[400]],
        "FullLength" -> StringLength[cleaned]|>]];
    
    (* 6. shape 正規化 *)
    Which[
      outputShape === "Single",
        ...,  (* Association を {Association} に *)
      True,
        ...   (* List か単一 Association を List に統一 *)
    ]
  ];
```

## Bracket counting で解説文付き JSON を抽出

LLM が `Here are the claims:\n\n[{...}, {...}]\n\nNote: ...` 形式で返すケースに対応。
**最初の `[` または `{` から、文字列内 bracket を無視してマッチする閉じ括弧まで**を切り出す:

```mathematica
iExtractFirstJSONBlock[text_String] :=
  Module[{posBrack, posBrace, startPos, openCh, closeCh,
          chars, n, depth, inStr, esc, ch, result},
    posBrack = StringPosition[text, "[", 1];
    posBrace = StringPosition[text, "{", 1];
    Which[
      Length[posBrack] > 0 && Length[posBrace] > 0,
        If[posBrack[[1, 1]] < posBrace[[1, 1]],
          startPos = posBrack[[1, 1]]; openCh = "["; closeCh = "]",
          startPos = posBrace[[1, 1]]; openCh = "{"; closeCh = "}"],
      Length[posBrack] > 0, startPos = posBrack[[1, 1]]; openCh = "["; closeCh = "]",
      Length[posBrace] > 0, startPos = posBrace[[1, 1]]; openCh = "{"; closeCh = "}",
      True, Return[Missing["NoBracket"]]
    ];
    
    chars = Characters[text];
    n = Length[chars];
    depth = 0; inStr = False; esc = False;
    result = Missing["Truncated"];
    
    Catch[
      Do[
        ch = chars[[i]];
        If[inStr,
          If[esc, esc = False,
            If[ch === "\\", esc = True,
              If[ch === "\"", inStr = False]]],
          Which[
            ch === "\"", inStr = True,
            ch === openCh, depth = depth + 1,
            ch === closeCh,
              depth = depth - 1;
              If[depth === 0,
                result = StringTake[text, {startPos, i}];
                Throw[Null]]
          ]],
        {i, startPos, n}]];
    result
  ];
```

**ポイント**:

- `Catch[..., Do[..., Throw[Null]]]` で早期 break (罠 #15 を避けるため `Return` でなく `Throw`)
- 文字列内の `[` `{` `"` は `inStr` フラグで無視
- バックスラッシュ escape (`esc`) で `\"` をハンドル

## Truncated 復旧 (partial recovery)

LLM 応答が切れている (バッファ問題、Timeout 等) ケースに対応。**`[`の中で完全な`{...}`object だけを拾う**:

```mathematica
iRecoverPartialJSONArray[text_String] :=
  Module[{posStart, startIdx, chars, n, depth, inStr, esc, ch,
          objStart, objStrings, parsed},
    posStart = StringPosition[text, "[", 1];
    If[!ListQ[posStart] || Length[posStart] === 0, Return[{}]];
    startIdx = posStart[[1, 1]] + 1;
    
    chars = Characters[text];
    n = Length[chars];
    objStrings = {};
    depth = 0; inStr = False; esc = False; objStart = 0;
    
    Do[
      ch = chars[[i]];
      If[inStr,
        If[esc, esc = False,
          If[ch === "\\", esc = True,
            If[ch === "\"", inStr = False]]],
        Which[
          ch === "\"", inStr = True,
          ch === "{", If[depth === 0, objStart = i]; depth = depth + 1,
          ch === "}",
            depth = depth - 1;
            If[depth === 0 && objStart > 0,
              AppendTo[objStrings, StringTake[text, {objStart, i}]];
              objStart = 0]
        ]],
      {i, startIdx, n}];
    
    parsed = Map[Function[s, Quiet[ImportString[s, "RawJSON"]]], objStrings];
    parsed = Select[parsed,
      AssociationQ[#] || (ListQ[#] && AllTrue[#, RuleQ]) &];
    Map[If[AssociationQ[#], #, Association[#]] &, parsed]
  ];
```

`[{"a":1}, {"b":2}, {"c":` のような途中切れでも 2 object を回収。

## Schema 駆動 prompt 構築

Schema は次のような Association:

```mathematica
<|"Name" -> "NumericFacts",
  "Description" -> "Extract numeric facts: ...",
  "Fields" -> {
    <|"Name" -> "Quantity", "Type" -> "String", "Required" -> True,
      "Description" -> "Name of the quantity"|>,
    <|"Name" -> "Value", "Type" -> "Number", "Required" -> True,
      "Description" -> "The numeric value"|>,
    ...
  },
  "OutputShape" -> "List"|>
```

これから prompt を **自動生成**:

```
You are extracting structured claims from a source document. Read the SOURCE TEXT below
and extract claims according to the SCHEMA.

## SCHEMA: NumericFacts
Extract numeric facts: ...

Fields to extract per claim:
1. Quantity (String, required): Name of the quantity
2. Value (Number, required): The numeric value
...

## OUTPUT FORMAT
Respond with ONLY a JSON array (no prose, no markdown code fences). Schema:
[
  {
    "Quantity": <string>,
    "Value": <number>,
    ...
  },
  ...
]

If no claims can be extracted, respond with [].

## SOURCE TEXT
[Page N]
...
```

LLM が `prose, no markdown fences` を無視しても、5 段階 parser で回収する設計。

## iSanitizeForJSON — JSON 非互換型の自動変換

Mathematica の JSON encoder は **`Missing[]` / `Automatic` / `None` / `DateObject` 等を
encode できない**。これが `iClaimsAppendJSONL` で `$Failed` を引き起こす罠を踏みやすい。

サニタイズで再帰的に変換:

```mathematica
iSanitizeForJSON[expr_] :=
  Which[
    AssociationQ[expr],
      Association[KeyValueMap[#1 -> iSanitizeForJSON[#2] &, expr]],
    ListQ[expr],
      Map[iSanitizeForJSON, expr],
    StringQ[expr] || NumericQ[expr] || expr === True || expr === False ||
      expr === Null,
      expr,                                  (* JSON 互換型 *)
    MissingQ[expr],
      Null,                                  (* Missing[...] → null *)
    Head[expr] === DateObject,
      DateString[expr],                      (* 日時 → 文字列 *)
    True,
      ToString[expr, InputForm]              (* fallback: シンボルやその他 *)
  ];
```

**呼出側**で**書込みの直前に**通す:

```mathematica
iClaimsAppendJSONL[path_String, claim_Association] :=
  Module[{sanitized, line, strm},
    sanitized = iSanitizeForJSON[claim];                              (* ← サニタイズ必須 *)
    line = Quiet @ ExportString[sanitized, "RawJSON", "Compact" -> True];
    If[!StringQ[line],
      Return[<|"Status" -> "Failed", "Reason" -> "JSONEncodeFailed"|>]];
    ...
  ];
```

**注意**: 書込み側で SourceSpan 等を構築するときも `Missing[]` を default にしない。`Null` に統一しておくと二重防御:

```mathematica
(* ❌ JSON 化失敗の原因 *)
"Pages" -> Lookup[span, "Pages", Missing[]]

(* ✓ 修正後 *)
pagesVal = Lookup[span, "Pages", Null];
If[MissingQ[pagesVal] || pagesVal === Automatic, pagesVal = Null];
... "Pages" -> pagesVal
```

## Verbose 診断機構 ($SourceVaultExtractVerbose)

LLM 呼出の所要時間と応答長を Print で見える化:

```mathematica
iCallExtractorLLM[prompt_String, timeout_:180] :=
  Module[{resp, verbose, t0, elapsed},
    verbose = TrueQ[If[ValueQ[SourceVault`$SourceVaultExtractVerbose],
      SourceVault`$SourceVaultExtractVerbose, False]];
    
    If[verbose,
      Print["[SourceVaultExtract] calling ClaudeQueryBg with prompt of ",
        StringLength[prompt], " chars (timeout=", timeout, "s)..."]];
    t0 = AbsoluteTime[];
    resp = Quiet[
      ClaudeCode`ClaudeQueryBg[prompt,
        NonBlocking -> True, Timeout -> timeout]];
    elapsed = Round[AbsoluteTime[] - t0, 0.1];
    
    If[verbose,
      Print["[SourceVaultExtract] response in ", elapsed, "s: ",
        Which[
          StringQ[resp],
            "String(" <> ToString[StringLength[resp]] <> " chars)",
          resp === $Failed, "$Failed",
          True, ToString[Head[resp]]
        ]]];
    
    Which[
      !StringQ[resp], <|"Status" -> "Failed", "Reason" -> "NonStringResponse"|>,
      StringStartsQ[resp, "Error:"], <|"Status" -> "Failed",
        "Reason" -> "LLMError",
        "Message" -> StringTake[resp, UpTo[300]]|>,
      True, <|"Status" -> "OK", "Response" -> resp, "Elapsed" -> elapsed|>
    ]
  ];
```

出力例:

```
[SourceVaultExtract] calling ClaudeQueryBg with prompt of 7811 chars (timeout=180s)...
[SourceVaultExtract] response in 41.7s: String(13952 chars)
```

これで:
- prompt 長が想定範囲か
- 応答時間が Timeout 不足/十分か
- 応答長が短すぎる (= 早期切断) or 妥当か

を即判別できる。

## 失敗時の詳細 RawResponseHead/Tail (debug 用)

JSON parse 失敗時、**先頭 1500 文字 + 末尾 1500 文字** を別フィールドに保存。
truncation か文法エラーかを判別:

```mathematica
If[Lookup[parseResult, "Status", ""] =!= "OK",
  Module[{rawResp = llmResult["Response"]},
    Return[<|"Status" -> "Failed",
      "Reason" -> "ParseFailed",
      "ParseResult" -> parseResult,
      "RawResponseLength" -> StringLength[rawResp],
      "RawResponseHead" -> StringTake[rawResp, UpTo[1500]],
      "RawResponseTail" -> If[StringLength[rawResp] > 1500,
        StringTake[rawResp, -Min[1500, StringLength[rawResp]]],
        ""]|>]]];
```

末尾が `]` で正しく閉じていれば JSON 文法エラー、途中で切れていれば truncation。

## 設計上の判断

| 判断 | 理由 |
|---|---|
| Schema は Association、組込み + custom inline 両対応 | 永続登録 (`SourceVaultRegisterSchema`) と単発 inline の両方で使えるように |
| LLM 出力は **JSON のみ** (markdown / 解説禁止) を要求 | parse 容易化、ただし 5 段階 fallback で乱れても回収 |
| `iCallExtractorLLM` 戻り値を Association `<|"Status"|>` 形式に | エラーパスを呼出側で明示判定 |
| iSanitizeForJSON は **書込み直前 1 箇所** | 計算ロジックに侵入しない、サニタイズの単位を明確 |
| ContentHash も sanitized 経由で計算 | hash の安定性 (Missing[] 入りでも同じ hash) |

## 適用タイミング

- 新規の構造化抽出パイプライン: この skill のテンプレで設計を始める
- LLM 出力 parse で `ParseFailed` が頻発する時: 5 段階 fallback に書き換える
- JSON 化で `$Failed` が出る時: `iSanitizeForJSON` を書込み直前に通す
- 「呼ばれていない」「沈黙」と思える時: verbose flag + Print 二重化を最初に入れる

## 関連

- skill `claudecode-cli-vision`: LLM 呼出経路 (Phase 35)
- skill `jsonl-store-pattern`: 抽出された claim の永続化
- skill `wolfram-syntax-pitfalls`: 罠 #15 (Map+Function+Return), 罠 #16 (Quiet@Check), 罠 #20 (Windows JSONL ReadList)
- SourceVault.wl Stage 5 実装 (v2026-05-19-stage-5-claim-retrieval-fix)
