---
name: adapter-tool-flow-debugging
description: Use when the user reports odd behavior in adapter-path ClaudeEval (i.e. $UseClaudeRuntime = True). Typical symptoms include the tool_call text being written into a Column[{...}] cell verbatim, the LLM complaining "過去の検索結果が見えない" and re-searching repeatedly, the final LLM response not appearing in the notebook, web_search looping 4+ times, or LLM hallucinating an answer while ignoring rich tool results. This skill covers ClaudeTurnTrace, ConversationState inspection, and how to tell from an event trace where in the turn pipeline things went wrong.
---

# Adapter tool-flow Debugging Skill

`$UseClaudeRuntime = True` のときに走る adapter 経路
(`iClaudeEvalViaRuntimeBridge` → ClaudeRuntime proposal loop → `iToolExec*`)
で起きる症状を診断する手順。Phase 30 系列のデバッグから抽出した。

## 症状カタログ

| 症状 | 疑う場所 |
|---|---|
| tool_call の生テキストが `Column[{"<tool_call name=...>"}]` に詰められる | `MaxContinuations = 1` 等、継続 turn 不足 |
| LLM が「過去の検索結果が見えない」と言って同一クエリを繰り返す | `iToolResultsToPromptText` の優先順が `Summary` 先頭 |
| tool 結果は豊富なのに LLM が hallucination 応答する | tool 結果 prefix に否定的 `[NOTE: do NOT ...]` |
| Notebook に最終テキスト応答が出ない (tool summary のみ) | `isAfterDaemon` 過剰適用で text 書き込み skip |
| LLM が書いた `Column[{Style[...], Hyperlink[...]}]` が `Column[{"まとめます", "[DONE]"}]` に化ける | `lastTurnIsTextOnly && hasPriorCodeInMsgs` で blocks={} された |
| 使っていないのに「Rate limit active」表示 | `rate_limit_event` の `status="allowed"` 誤記録 |
| "ClaudeRuntime: 起動失敗" で即 $Failed | Kernel リセット推奨。`ClaudeBuildRuntimeAdapter` の Option 不整合 |

## 診断の基本セット

### 1. バージョン確認

ユーザが最新の `claudecode.wl` を実際にロードしているかを最初に確認する。
Load 時 Print は抑声されているので、`$claudecodeVersion` を出させる。

```mathematica
$claudecodeVersion
$ClaudeOrchestratorVersion
```

### 2. rate limit 状態

```mathematica
ClaudeRateLimitStatus[]
(* 期待: None。もし Association なら Source/Status フィールドを見る。
   Source="rate_limit_event" かつ Status="allowed" なら進捗通知の誤記録 → ClaudeRateLimitClear[] *)
```

### 3. イベントトレース

`ClaudeTurnTrace[$ClaudeLastRuntimeId]` で Type の系列を見る:

```mathematica
ClaudeTurnTrace[$ClaudeLastRuntimeId] // Dataset
```

正常な 1-tool 実行は概ね:

```
Created → StatusChange → TurnStarted → ContextBuilt → ProviderLaunched
→ ProviderQueried → ProposalParsed → ToolUseDetected → ToolsExecuted
→ ToolContinuationScheduled → StatusChange → StatusChange
→ TurnStarted → ContextBuilt → ProviderLaunched → ProviderQueried
→ ProposalParsed → TextOnlyResponse → StatusChange
```

**異常のパターン**:

- `ToolsExecuted` が 4 回以上連続 → tool chaining。Rule 99 R3 参照
- 最後が `BudgetExhausted` → `ToolLoopBudgetExhausted` → LLM が tool を呼び続けて
  MaxToolIterations=6 を超過した
- `TextOnlyResponse` の後に `StatusChange` で Done だが notebook に何も出ない
  → `iRuntimeDisplayResult` の text skip バグ (Rule 99 R6)

### 4. ConversationState.Messages を直接見る

過去 turn が LLM に渡っているか、tool 結果が記録されているかを確認。

```mathematica
Module[{rt, msgs},
  rt = ClaudeRuntime`Private`$iClaudeRuntimes[$ClaudeLastRuntimeId];
  msgs = Lookup[Lookup[rt, "ConversationState", <||>], "Messages", {}];
  Dataset @ Map[
    Function[m,
      <|"Turn"           -> Lookup[m, "Turn"],
        "Compacted"      -> TrueQ[Lookup[m, "Compacted", False]],
        "Type"           -> Lookup[m, "Type", "?"],
        "HasToolCalls"   -> (ListQ[Lookup[m, "ToolCalls", None]] &&
                             Length[Lookup[m, "ToolCalls", {}]] > 0),
        "HasToolResults" -> (ListQ[Lookup[m, "ToolResults", None]] &&
                             Length[Lookup[m, "ToolResults", {}]] > 0),
        "TextRespLen"    -> StringLength[ToString[Lookup[m, "TextResponse", ""]]]|>],
    msgs]]
```

**確認ポイント**:

- `Compacted=True` の turn は本文が失われている。`$MaxConversationMessages` を超えていないか
- `HasToolCalls=True` でも `HasToolResults=True` でないなら tool 実行失敗を疑う
- 最終 turn の `TextRespLen` が非ゼロなのに notebook に出てないなら `iRuntimeDisplayResult`

### 5. tool 結果の中身を覗く

LLM がどんな tool 結果を受け取っていたかを直接プレビュー:

```mathematica
Module[{rt, msgs, toolMsgs},
  rt = ClaudeRuntime`Private`$iClaudeRuntimes[$ClaudeLastRuntimeId];
  msgs = Lookup[Lookup[rt, "ConversationState", <||>], "Messages", {}];
  toolMsgs = Select[msgs, ListQ[Lookup[#, "ToolResults", None]] &];
  Dataset @ Map[
    Function[m,
      <|"Turn" -> Lookup[m, "Turn"],
        "Tool" -> StringRiffle[
          Map[Lookup[#, "Name"] &, Lookup[m, "ToolCalls", {}]], ", "],
        "Query" -> StringTake[ToString[
          Lookup[First[Lookup[m, "ToolCalls", {<||>}], <||>],
                 "Input", <||>]], UpTo[150]],
        "ResultLen" -> StringLength[Lookup[
          First[Lookup[m, "ToolResults", {<||>}], <||>], "Result", ""]],
        "ResultHead" -> StringTake[Lookup[
          First[Lookup[m, "ToolResults", {<||>}], <||>], "Result", ""],
          UpTo[400]]|>],
    toolMsgs]]
```

**判定基準**:

- `ResultLen < 100` → tool 経由で本文が取れていない。`iToolExec*` の問題
- `ResultLen > 1000` かつ内容が正しい → tool は OK。問題は prompt 構築か最終出力処理
- `Result` に `[NOTE:]` や `[TOOL-HINT:]` prefix があれば Phase 30.4-30.6 の影響域

### 6. LLM 最終応答 (LastProposal) の全文を見る

```mathematica
Module[{rt, lp},
  rt = ClaudeRuntime`Private`$iClaudeRuntimes[$ClaudeLastRuntimeId];
  lp = Lookup[rt, "LastProposal", <||>];
  <|"HasProposal" -> Lookup[lp, "HasProposal"],
    "HasToolUse"  -> Lookup[lp, "HasToolUse"],
    "TextResponse" -> StringTake[
      ToString[Lookup[lp, "TextResponse", ""]], UpTo[3000]]|>]
```

- `TextResponse` に ```mathematica ... ``` コードブロックがあるのに notebook に
  書かれない → Rule 99 R5 (code block skip ガード)
- `TextResponse` が「まとめます」「検索で情報が得られなかった」等で短い →
  tool 結果が LLM に届いていない。R2 を疑う

## 系統的な切り分けフロー

```
「ClaudeEval が期待通り動かない」
   ↓
$claudecodeVersion が最新？ (No → ファイル更新 + カーネルリセット)
   ↓ Yes
ClaudeRateLimitStatus[] = None？ (No → ClaudeRateLimitClear[])
   ↓ Yes
ClaudeTurnTrace で ToolsExecuted の回数は？
   ├ 4 回以上 → tool chaining。Rule 99 R3 (tool hint) を確認
   ├ 0 回    → LLM が tool を呼んでいない。adapter["AvailableTools"] や prompt を確認
   └ 1-3 回  → ConversationState.Messages で tool 結果が記録されている
              ↓
              tool 結果本文 (ResultLen) は十分？
              ├ No  → iToolExec* の実装 (Phase 30.1 のような signature 不整合)
              └ Yes → LLM 最終応答 (LastProposal.TextResponse) に有意な内容は？
                     ├ No  → tool 結果が LLM に届いていない。R2 (優先順)
                     └ Yes → notebook 書き込み側の問題。R5 (blocks skip) / R6 (isAfterDaemon)
```

## 具体事例: Phase 30 系列の教訓

1. **Phase 30.1**: `iToolExecWebSearch` のシグネチャが `ClaudeWebSearch` の実装と
   不整合 (MaxItems オプション vs 1 引数)。tool 呼び出し → "Web search failed"

2. **Phase 30.2**: `iClaudeEvalViaRuntimeBridge` だけ `MaxContinuations=1` で
   他の adapter 作成箇所はすべて 3 だった。tool 実行後 1 turn しか回らず破綻

3. **Phase 30.3**: `rate_limit_event` の `status="allowed"` を誤記録。使用量進捗の
   定期通知を「rate-limit ヒット」と解釈して Retry UI 表示

4. **Phase 30.4 → 30.6**: tool 結果に `[NOTE: do NOT chain]` と否定的 prefix を
   付けると LLM が結果を不信モードで読み、ハルシネーション。`[TOOL-HINT: treat as
   authoritative]` と末尾に肯定的表現で置き直した

5. **Phase 30.5**: `isAfterDaemon` フラグが tool 後の LLM まとめ応答まで
   「ダミー `[DONE]` 応答」と誤認して text 書き込みを skip

6. **Phase 30.7**: `lastTurnIsTextOnly && hasPriorCodeInMsgs` で blocks={} にする
   最適化が、LLM の最終 turn に書いた `Column[{Style[...], Hyperlink[...]}]` も
   捨てていた。応答に code block 実在判定を追加

7. **Phase 30.8**: `iToolResultsToPromptText` の優先順が `Summary` 先頭で、
   過去 turn の tool 結果本文が prompt に注入されず、LLM が「過去の検索結果が
   見えない」と困惑して同じクエリを何度も投げていた

## 参照

- Rule: `99-adapter-tool-flow.md` — 規範ルール
- `claudecode.wl` 実装: `iAdapterBuildPrompt` (L21687), `iToolResultsToPromptText`
  (L22164), `iRuntimeDisplayResult` (L23602), `iToolExecWebSearch` / `iToolExecWebFetch`
- `ClaudeRuntime.wl` 実装: `iToolUseAndContinue` (L1278), `iStepDispatchDecision`
  (L1123), `iCompactConversationHistory` (L2271)
