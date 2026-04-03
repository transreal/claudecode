---
name: package-merge-pattern
description: Use when implementing or modifying code that updates .wl package files via LLM responses. Covers function extraction, partial-response merge, full-file detection, new-function insertion, stream-json progress parsing, and safety validation patterns. Essential for ClaudeUpdatePackage, ClaudeFixSeparation, and any future LLM-driven code update workflows.
---

# パッケージマージパターン

LLM レスポンスでパッケージソースコードを部分更新するときの具体的な実装パターン集。

## 1. 関数ブロック抽出 (`iExtractFunctions`)

### アルゴリズム

行頭から始まる関数定義（`:=` または `= (` を含む行）を検出し、次の関数定義が来るまでの全行をその関数のブロックとして蓄積する。

```mathematica
iExtractFunctions[code_String] :=
  Module[{lines, blocks, current, nameRe},
    lines = StringSplit[code, "\n"];
    nameRe = RegularExpression["^([a-zA-Z\\$][a-zA-Z0-9\\$]*)\\s*[\\[\\(]"];
    blocks = <||>;
    current = None;
    Scan[Function[line,
      Module[{m},
        m = StringCases[line, nameRe :> "$1"];
        If[Length[m] > 0 && !StringStartsQ[line, " "] && !StringStartsQ[line, "\t"] &&
           (StringContainsQ[line, ":="] || StringContainsQ[line, "= ("]),
          current = First[m];
          If[!KeyExistsQ[blocks, current], blocks[current] = ""];
          blocks[current] = blocks[current] <> line <> "\n",
          If[current =!= None,
            blocks[current] = blocks[current] <> line <> "\n"]
        ]
      ]
    ], lines];
    blocks  (* <|"funcName" -> "定義全文\n...\n", ...|> *)
  ];
```

### 重要な性質

- 同名関数の複数定義（パターン違い）は同一ブロックに蓄積される
- `BeginPackage[...]`、`Begin["`Private`"]` 等のパッケージ構造行は、直前の関数ブロックに含まれる（行頭だが `:=` を含まないため）
- `Options[func] = {...}` は独立した関数ブロックとして抽出される
- **元コードとレスポンスの両方に同一アルゴリズムを適用するため、マッチングが保証される**

### 注意点

- コメント行 `(* ... *)` は直前の関数ブロックに含まれる
- インデントされた行（スペースまたはタブで始まる）は継続行として扱われる
- 複数行にまたがる関数定義は、最初の行で関数名が決まり、以降はインデント行として追従する

## 2. マージパターン

### 基本マージ（関数単位差し替え）

```mathematica
Module[{code = origCode, updBlks, mergedCount = 0},
  updBlks = iExtractFunctions[llmResponse];
  Scan[Function[fn,
    Module[{oldDef, newDef},
      oldDef = Lookup[origBlocks, fn, ""];
      newDef = Lookup[updBlks, fn, ""];
      If[oldDef =!= "" && newDef =!= "",
        code = StringReplace[code, oldDef -> newDef, 1];
        mergedCount++]
    ]
  ], Keys[updBlks]];
  (* mergedCount > 0 なら成功 *)
  code
]
```

### 全ファイル判定

```mathematica
respIsFullFile = StringContainsQ[response, "BeginPackage["] &&
                 StringContainsQ[response, "EndPackage["] &&
                 StringLength[response] > StringLength[origCode] * 0.7;
```

3 条件すべてを満たす場合のみ全ファイルとして採用する。`BeginPackage` だけでは判定不十分（関数の中に文字列リテラルとして含まれることがある）。

### 新規関数の挿入

元コードに存在しない新規関数がレスポンスに含まれる場合、4段階フォールバックで挿入位置を決定する:

```mathematica
If[Length[newOnlyFuncs] > 0,
  Module[{insertCode, codeBefore = code, inserted = False},
    insertCode = StringJoin[Lookup[updBlks, #, ""] & /@ newOnlyFuncs];
    (* 戦略1: End[] + EndPackage[] が隣接する標準構造 *)
    code = StringReplace[code,
      RegularExpression["(\\n\\s*End\\[\\]\\s*;?\\s*\\n\\s*EndPackage\\[\\])"] :>
      "\n" <> insertCode <> "$1", 1];
    If[code =!= codeBefore, inserted = True];
    (* 戦略2: 最後の End[] の直前に挿入（非標準構造対応） *)
    If[!inserted,
      code = codeBefore;
      code = StringReplace[code,
        RegularExpression["(\\n\\s*End\\[\\]\\s*;?\\s*\\n)(?![\\s\\S]*End\\[\\])"] :>
        "\n" <> insertCode <> "$1", 1];
      If[code =!= codeBefore, inserted = True]];
    (* 戦略3: StringPosition で最後の End[] を探して直前に挿入 *)
    If[!inserted, (* ... StringPosition ベースのフォールバック ... *)];
    (* 戦略4: End[] すら無い場合は末尾に追加 *)
    If[!inserted, code = codeBefore <> "\n" <> insertCode];
    (* 挿入成否を検証して通知 *)
    If[inserted,
      nbPrint[nb2, "新規関数を追加: " <> StringRiffle[newOnlyFuncs, ", "]],
      nbPrint[nb2, Style["⚠ 新規関数の挿入位置を検出できませんでした", ...]]]
  ]
]
```

#### 非標準パッケージ構造への対応

`maildb.wl` のように `EndPackage[]` がファイル先頭付近（エクスポート宣言直後）にあり、`End[]` が末尾にある構造では、戦略1の `End[]; EndPackage[]` 隣接パターンがマッチしない。戦略2が `[\\s\\S]*` を使った改行横断の否定先読みで最後の `End[]` を特定し、その直前に挿入する。

```
非標準構造の例 (maildb.wl):
  BeginPackage["Maildb`"];
  EndPackage[];              ← エクスポート宣言直後
  Begin["Maildb`Private`"];
  ...
  End[];                     ← 戦略2がここの直前に挿入
```

**重要**: 挿入の成否を必ず検証する（`code =!= codeBefore`）。旧実装では `StringReplace` がマッチしなくても成功メッセージが表示され、挿入失敗が隠蔽されていた。

## 3. プロンプト構築パターン

### targets 判定済み（選択した関数のみ送信）

```
Below are selected function definitions from the package `Pkg.wl`.
Modify them according to the instruction. Return ONLY the modified functions.
```

### targets 未判定（ファイル全体送信）

```
Below is the COMPLETE source of the Mathematica package `Pkg.wl`.
Modify ONLY the functions that need to change according to the instruction.
Return ONLY the modified function definitions (not the entire file).
IMPORTANT: Do NOT return the entire file. Return ONLY the functions you actually changed.
All unchanged functions will be preserved automatically by the merge system.
```

**重要**: ファイル全体を送る場合でも「修正した関数のみ返せ」と指示する。マージシステムが未変更関数を保持することを LLM に伝えることで、LLM が全体を返そうとして途中で切れるリスクを防ぐ。

### セクションラベルの切り替え

```mathematica
If[Length[targets] === 0,
  "COMPLETE SOURCE (modify only what is needed):\n",
  "CURRENT FUNCTIONS:\n"
]
```

## 4. レスポンス抽出パターン

### デリミタベースの抽出

```mathematica
beginMark = "===BEGIN_FUNCTIONS===";
endMark   = "===END_FUNCTIONS===";
extracted = iExtractBetweenMarkers[response, beginMark, endMark];
```

### フォールバック: コードブロックからの抽出

デリミタが見つからない場合、Markdown コードブロックから抽出:

```mathematica
codeBlocks = StringCases[response,
  RegularExpression["```(?:mathematica|wolfram)?\n([\\s\\S]*?)```"] :> "$1"];
If[Length[codeBlocks] > 0,
  result = StringJoin[Riffle[codeBlocks, "\n\n"]]]
```

## 5. JS プレースホルダー処理

`$JSSource` のような巨大な文字列リテラルは、マージ時の `StringReplace` が意図しない置換を行うリスクがある。

```mathematica
jsPlaceholder = "(* %%JS_SOURCE_DO_NOT_MODIFY%% *)";
jsBlock = First[StringCases[currentCode,
  RegularExpression["(?s)(\\$JSSource\\s*=\\s*\".*?\"\\s*;)"] :> "$1"], ""];
(* 送信前にプレースホルダーに置換 *)
If[jsBlock =!= "",
  currentCode = StringReplace[currentCode, jsBlock -> jsPlaceholder, 1]];
(* マージ後にプレースホルダーを元に戻す *)
If[jb =!= "", code = StringReplace[code, jp -> jb, 1]];
```

## 6. stream-json プログレスパース

Claude Code の `--output-format stream-json` 出力をリアルタイムで解析し、プログレス表示に使う。

### イベント種別とカウンター

| イベント | 条件 | カウンター | 表示 |
|---------|------|-----------|------|
| `thinking_delta` | `delta.type === "thinking_delta"` | `thinkingFragments` | `(思考:N)` |
| `text_delta` | `delta.type === "text_delta"` | `textFragments` | `(テキスト:N)` |
| `tool_use` | `content_block_start` + `content_block.type === "tool_use"` | `toolUses` | `(ツール:N)` |
| `message_stop` | `event.type === "message_stop"` | — | ステータス「応答完了」 |
| `result` | `j.type === "result"` | — | ステータス「完了」 |

### 差分読み取り

```mathematica
iUpdateStreamProgress[key, outFile] :=
  (* 前回読んだ行数 (lineCount) 以降の新規行のみをパース *)
  (* 新規行ごとに iParseStreamJsonLine でパースし、カウンターを更新 *)
```

ファイル全体を毎回パースするのではなく、前回の `lineCount` 以降の行のみを読む差分方式。1 秒間隔の `CreateScheduledTask` で呼び出される。

### 表示フォーマット

```
Claude に問い合わせ中... {elapsed}s | {status} (思考:{N}) (テキスト:{N}) (ツール:{N})
```

- `elapsed`: プロセス起動からの経過秒数
- `status`: 現在の状態（「初期化」「思考中」「テキスト生成中」「ツール実行中: {toolName}」「応答完了」「完了」）
- 各カウンターは 0 の場合は非表示

## 7. 安全検証チェックリスト

マージ後の `newCode` に対して行う最終検証:

1. **サイズ比**: `StringLength[newCode] >= StringLength[origCode] * 0.5`
2. **関数数比**: `Length[iExtractFunctions[newCode]] >= Length[iExtractFunctions[origCode]] * 0.5`（元が 3 関数以上の場合）
3. **構造保持**: 元コードに `BeginPackage[` があれば、`newCode` にも `BeginPackage[` と `EndPackage[` が必要
4. **API エラー排除**: `iIsAPIErrorResponse[response]` が True なら処理中止

検証失敗時は上書きをブロックし、新バージョンを履歴ディレクトリに保存してユーザーに手動確認を促す。
