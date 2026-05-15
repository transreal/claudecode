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
| **ステータスバーが「ClaudeRuntime: 処理中... Ns」のまま止まる(Phase D2 表示が出ない)** | AsyncToolExec の polling tick が登録できていない、または `$claudeProgress[pollKey]` の追加情報が `ClaudeRegisterPollingTick` より先に書かれて全置換で消された(rule 100 R8 / skill `async-tool-execution`) |
| **`CurrentPhase = "QueryProvider"` で 10 分以上 stuck**、trace 5 件のみ | Phase D の責任範囲外。LLM 応答取得段階で止まっている。`$ClaudeRuntimeAsyncExecution = False` と過去 runtime / polling tick 残骸の干渉が典型(rule 100 R10) |
| **DAG が完了したのに notebook に何も出力されない** | `iAsyncToolExecFinalize` の continuation turn 起動が失敗。`iOnTurnComplete` の `AsyncToolExecScheduled` 早期 return が抜けて callback が暴発した可能性、または `Metadata["Notebook"]` が落ちている可能性 |
| **`Active = False` だが `ClaudeStatus[]` に古い `ClaudeRuntimeAsyncExec_*` polling tick が残る** | Phase 32 の AsyncExecution polling tick の残骸。`ClaudeUnregisterPollingTick` で個別に解除するか、Mathematica 再起動 |
| **tool 1 つは成功、もう 1 つが Anthropic `overloaded_error` で失敗** | Anthropic API 側の一時的過負荷。Phase D の問題ではない。再試で解消。ただし生 stdout が text セルに長大に漏れる場合があり、それは Phase 30 系列の延長 |

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

**AsyncToolExec 経路 (`$ClaudeRuntimeToolAsyncDefault = True`) の正常パターン**:

```
Created → StatusChange → TurnStarted → ContextBuilt → ProviderLaunched
→ ProviderQueried → ProposalParsed → ToolUseDetected
→ ToolClassified (TotalCalls=N, SyncCount=K, AsyncCount=N-K)
→ AsyncToolExecStarted (TotalAsync, InitialRunning, MaxConcurrent=4)
→ TurnAwaitingAsync (Outcome="AsyncToolExecScheduled")  ← この turn はここで終わる
→ AsyncToolExecTick × N
→ AsyncToolExecCompleted (ToolCount, Elapsed)
→ ToolsExecuted → ToolContinuationScheduled
→ (continuation turn)
→ ... TurnComplete
```

**AsyncToolExec 経路の異常パターン**:

- `TurnAwaitingAsync` の後に `AsyncToolExecTick` が来ない → polling tick が登録できていない。`ClaudePollingTickKeys[]` で `ClaudeRuntimeToolExec_*` が登録されているか確認
- `AsyncToolExecTick` は来るが `AsyncToolExecCompleted` に到達しない → `SubmitToolAsync` の戻り値の `Process` が `ProcessStatus["Finished"]` にならない。Anthropic API 過負荷の場合は timeout 経由で Failed として完了する
- `AsyncToolExecCompleted` 後に `ToolsExecuted` が無く沈黙 → `iAsyncToolExecFinalize` 内の continuation turn 起動が失敗。`Metadata["Notebook"]` が落ちている、または `iOnTurnComplete` の早期 return 漏れで callback が暴発(rule 100 R2)
- `TurnAwaitingAsync` 後に何故か別の `TurnStarted` が来る → `AsyncToolExecScheduled` の早期 return が抜けて callback が新しい turn を起動した

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

### 7. AsyncToolExec の状態を見る (Phase D 経路のとき)

`$ClaudeRuntimeToolAsyncDefault = True` で hybrid 経路が動いているときの診断:

```mathematica
(* runtime の進行段階 *)
rid = $ClaudeLastRuntimeId;
rt = ClaudeRuntime`Private`$iClaudeRuntimes[rid];
{rt["Status"], rt["CurrentPhase"], rt["TurnCount"]}
(* 正常完了後: {"Idle", "TurnComplete", N}
   AsyncToolExec 待ちの最中: {"Running", "AwaitingAsyncTool", N} 
   LLM 推論段階 stuck: {"Running", "QueryProvider", N} ← Phase D の責任外 *)

(* AsyncToolExec の現状 *)
ClaudeRuntimeToolExecDiagnose[rid]
(* <|"Active" -> True|False,
     "Finalized" -> True|False,
     "QueueSize", "RunningSize", "CollectedSize",
     "Elapsed", "TotalAsync", "MaxConcurrent"|> *)

(* polling tick が登録されているか *)
Select[ClaudePollingTickKeys[],
  StringStartsQ[#, "ClaudeRuntimeToolExec_"] &]

(* tick 表示の現状 *)
Lookup[ClaudeCode`Private`$claudeProgress,
  Select[Keys[ClaudeCode`Private`$claudeProgress],
    StringStartsQ[#, "ClaudeRuntimeToolExec_"] &]]
(* "disp" キーに Phase D2 の表示文字列が見えるはず:
   "ClaudeRuntime: Web検索並列実行中... 6s | Run:1 Done:1/2" 等 *)

(* 完了済みの直近 AsyncToolExec の summary *)
rt["LastAsyncToolExecResult"]
(* <|"Outcome" -> "AsyncToolExecCompleted", "Elapsed", "ToolCount",
     "AsyncCount", "ToolResults" -> {...}|> *)
```

**判定基準**:

- `Active -> False, Finalized -> True` だが `Status = "Running"`、`CurrentPhase` が `AwaitingAsyncTool` のまま動かない → Finalize の continuation 起動が失敗。callback 早期 return 漏れの可能性(rule 100 R2)
- `Active -> True` で `Elapsed` が極端に大きい(120s 超) → 個別 tool が timeout していない。Anthropic API 側の問題か、tick の `ProcessStatus` チェックが効いていない
- `polling tick` 一覧に `ClaudeRuntimeToolExec_*` が**ない** → tick 登録が失敗、または finalize 後に解除済み(正常)
- `polling tick` 一覧に**複数**の `ClaudeRuntimeToolExec_*` がある → 過去 runtime の残骸。Cancel 漏れで干渉する可能性
- `$claudeProgress` の `disp` キーに "Web検索並列実行中" が**ない**が、claudecode の `iLLMGraphDAGTick` 表示「ClaudeRuntime: 処理中... Ns」が出ている → Phase D 経路に入っていない、または Phase D2 の表示更新コードに不備(rule 100 R8 / R9)

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

- Rule: `99-adapter-tool-flow.md` — 規範ルール (R1〜R7、tool 結果 / 順序 / hint / Options 整合)
- Rule: `100-async-tool-execution.md` — AsyncToolExec の必須ルール (R1〜R11、Phase D の設計原則)
- Skill: `async-tool-execution` — Phase A〜D2 の hybrid 経路の設計とフロー
- `claudecode.wl` 実装: `iAdapterBuildPrompt` (L21687), `iToolResultsToPromptText`
  (L22164), `iRuntimeDisplayResult` (L23602), `iToolExecWebSearch` / `iToolExecWebFetch`
- `claudecode.wl` の DAG tick 表示: `iLLMGraphDAGTick` (L21391-) — L21866 の "ClaudeRuntime: 処理中... Ns" は「全ノード完了/失敗で onComplete 未呼出」状態を意味する
- `ClaudeRuntime.wl` 実装: `iToolUseAndContinue` (L1429-, Phase D で hybrid 化), `iScheduleAsyncToolExecPoll` (L2484-), `iAsyncToolExecTickFn` (L2716-), `iAsyncToolExecFinalize` (L2944-), `iOnTurnComplete` (L1940-, L2141 で AsyncToolExecScheduled 早期 return), `ClaudeRuntimeToolExecDiagnose`, `ClaudeRuntimeCancelAsyncToolExec`
