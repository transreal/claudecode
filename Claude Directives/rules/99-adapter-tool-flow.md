---
paths:
  - "**/{claudecode,ClaudeRuntime,ClaudeOrchestrator}*.{wl,wls,m}"
---

# 99 — adapter 経由 tool-based ClaudeEval の実装ルール

## 対象

`$UseClaudeRuntime = True` のときに走る adapter 経路:

- `iClaudeEvalViaRuntimeBridge` → `ClaudeStartRuntime` → `ClaudeBuildRuntimeAdapter`
  → `ClaudeRuntime` の proposal loop → `adapter["ExecuteTools"]` → `iToolExecWebSearch`/`iToolExecWebFetch` 等

このパスを扱う関数 (特に `iAdapterBuildPrompt` / `iToolResultsToPromptText` /
`iToolExecWeb*` / `iRuntimeDisplayResult`) を修正するときの規範。

## 前提となる流れ

```
Turn 1: LLM が <tool_call> を出す
        ↓ ParseProposal
        ↓ adapter["ExecuteTools"]  ← tool 実行
        ↓ ConversationState.Messages に {Type:"ToolUse", ToolCalls, ToolResults} 追加
        ↓ ContinuationInput に同じ tool 結果を set → Outcome="ContinuationPending"
Turn 2: iStepBuildContext → adapter["BuildContext"] → contextPacket 作成
        ↓ adapter["QueryProvider"] → iAdapterBuildPrompt[contextPacket, convState]
        ↓ convState の Messages (過去 turn) + input (今回の ToolResult) を混ぜて prompt 化
        ↓ LLM 呼び出し
        ↓ LLM 最終応答 (TextOnly または新 tool_call or mathematica code block)
Turn N: TextOnly + [DONE] → iRuntimeDisplayResult が notebook に書き込み
```

この流れで **情報が turn 間でどう伝播するか** を意識せずに関数を変更すると、
「LLM に過去 tool 結果が渡らない」「LLM の最終コードブロックが捨てられる」
等の debug の難しい事故が起きる。

## 必須ルール

### R1: tool 結果の本文は必ず `Result` キーに入れる

`iToolExec*` 系が返す Association の **必須キー優先順**:

```mathematica
<|"Success" -> True,
  "Result"  -> <本体: 1500-3000 chars の LLM 要約や実データ>,  (* ★ prompt に注入される *)
  "Summary" -> <1 行メタ情報: "Web search completed (N chars)">|>
```

- **`Result` は prompt 経由で LLM に渡される「本文」** として扱う
- **`Summary` は UI 表示用の 1 行要約** として扱う
- tool 結果表示セル (`\[RightArrow] Tools: ...`) は `Summary` を使う
- LLM 向け prompt 生成 (`iToolResultsToPromptText`) は `Result` を使う

### R2: `iToolResultsToPromptText` の Which 優先順は `Result > RedactedResult > Summary`

過去 turn の tool 結果を prompt に注入する `iToolResultsToPromptText` では、
**本文を持つキーを最優先**する:

```mathematica
(* ✅ 正しい順序 *)
resultText = Which[
  StringQ[Lookup[result, "Result", None]],          result["Result"],
  StringQ[Lookup[result, "RedactedResult", None]],  result["RedactedResult"],
  StringQ[Lookup[result, "Summary", None]],         result["Summary"],
  True, ...]
```

```mathematica
(* ❌ 禁止: Summary が最優先だと本文が prompt に注入されず、LLM は過去 tool 結果が
   見えずに「再検索」と称して同じクエリを繰り返す *)
resultText = Which[
  StringQ[Lookup[result, "Summary", None]], result["Summary"],  (* ← 先頭に置くな *)
  ...]
```

### R3: tool 結果本文に「hint」を付けるなら本文の**末尾**に、肯定的表現で

tool chaining を抑制するためのヒントを tool 結果に付与する場合:

```mathematica
(* ✅ 本文を最初に見せ、末尾に軽い肯定的ヒント *)
"Result" -> result <> "\n\n" <>
  "[TOOL-HINT: The passage above is an LLM-prepared summary. " <>
  "Treat the facts as authoritative source for your final answer. " <>
  "Typically a second call is not needed.]"
```

```mathematica
(* ❌ 禁止: 本文の前に否定的「do NOT」を連ねると LLM は結果を不信モードで読み、
   豊富な結果があっても「不十分」と誤認してハルシネーションする *)
"Result" -> "[NOTE: do NOT run additional calls. This is final.]\n\n" <> result
```

### R4: adapter の Options 更新は `ClaudeStartRuntime` 側と一致させる

`iClaudeEvalViaRuntimeBridge` から `ClaudeStartRuntime` に渡す Option
(特に `MaxContinuations`, `SyncProvider`, `MaxToolIterations`) は、
他の adapter 作成箇所 (`ClaudeBuildRuntimeAdapter`, `ClaudeBuildTransactionAdapter`
など) の既定値と整合させる。

```mathematica
(* ✅ 他の adapter 作成箇所すべてで MaxContinuations -> 3 なら揃える *)
"MaxContinuations" -> 3,

(* ❌ 禁止: 片方だけ 1 にすると tool 実行後の継続 turn が足りず、
   tool_call 生テキストが committer に渡って Column に詰まれる *)
"MaxContinuations" -> 1,
```

### R5: `iRuntimeDisplayResult` の「最終 turn コードブロック抽出 skip」は
応答にコードが実在しない場合に限る

```mathematica
(* ✅ 正しい: 応答に mathematica code block が実在するかを candidateBlocks で先に判定 *)
candidateBlocks = StringCases[response,
  RegularExpression["```(?:mathematica|wolfram)?\\n([\\s\\S]*?)```"] :> "$1"];
If[((lastTurnIsTextOnly && hasPriorCodeInMsgs) || lastTurnRenderedByPhase20) &&
   Length[candidateBlocks] === 0,
  blocks = {},  (* 応答にコード無し → skip OK *)
  blocks = iMergeDependentBlocks[candidateBlocks]]  (* コードあり → 必ず使う *)
```

```mathematica
(* ❌ 禁止: 応答内コードブロックの有無を確認せず blocks={} にすると、
   LLM が tool 使用後の最終 turn に書いた Column[{Style[...], Hyperlink[...]}] が
   捨てられ、textOnly (前文のみ) が fallback Column[{"まとめます", ...}] に詰まる *)
If[lastTurnIsTextOnly && hasPriorCodeInMsgs, blocks = {}, ...]
```

### R6: `isAfterDaemon` による text 出力 skip は「[DONE] 以外に実質内容がない」時だけ

```mathematica
(* ✅ [DONE] を除いた実質テキストが一定長以上あれば表示する *)
If[TrueQ[isAfterDaemon] && StringQ[textOnly],
  Module[{meaningfulText},
    meaningfulText = StringTrim[StringReplace[textOnly,
      ("[DONE]" | "[done]" | "[Done]") -> ""]];
    If[StringLength[meaningfulText] >= 20,
      isAfterDaemon = False]]];
```

Phase 20 の当初想定(`[DONE]` だけの確認応答は表示不要)は、**tool 結果を踏まえた
LLM の自然言語まとめ**が `[DONE]` で閉じる場合に誤適用されやすい。実質内容の
長さ判定を必ず挟む。

### R7: rate-limit 判定は `status` フィールドを見る

`rate_limit_event` の `status` が `"allowed"` の通知は「まだ使える」進捗情報。
記録せずに `Return[None]` すること。`ResetsAt` の未来時刻に引っかかると誤って
"Rate limit active" が出る。

```mathematica
(* ✅ status=allowed はスキップ *)
If[ToLowerCase[ToString[Lookup[rateInfo, "status", ""]]] === "allowed",
  Return[None]];

(* ClaudeRateLimitStatus[] 側でも Status="allowed" の古いレコードを自動クリア *)
statusLC = ToLowerCase[ToString[Lookup[info, "Status", ""]]];
If[statusLC === "allowed",
  $iLastRateLimitInfo = None;
  Return[None]];
```

## tool 結果の「見えない」兆候の捉え方

LLM の応答に以下の表現が 2 回以上現れたら **過去 turn tool 結果が prompt に
届いていない** のサイン:

- 「過去の検索結果が見えないため、改めて検索します」
- 「再度検索します」「別のクエリで」「十分な情報が得られなかった」
- 同一トピックを微妙に違う表現で何度も検索する

対処は R2 (優先順) と、`ConversationState.Messages` から Turn 履歴が消えていないかの確認。

## 関連参照

- Rule: `100-async-tool-execution` - AsyncToolExec (Phase D の hybrid 経路) の必須ルール。本ルール (99) は sync 経路を含む adapter 全般の規範、100 は AsyncToolExec 特有の規範
- Skill: `adapter-tool-flow-debugging` - 診断手順と ClaudeTurnTrace の読み方 (AsyncToolExec の trace パターン含む)
- Skill: `async-tool-execution` - Phase 32k Step 3 (Phase A〜D2) の設計とフロー
- Rule: `95-scheduled-task-safety` - ScheduledTask 内からの禁止操作、D節 deferred sync runState (AsyncToolExec の基礎パターン)
- Rule: `11-core-package-dependency` - 基盤パッケージの依存方向
