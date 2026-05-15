---
name: async-tool-execution
description: Use when adding or modifying tool execution logic in the adapter path (`$UseClaudeRuntime = True`), especially when introducing parallel tool calls (e.g. `web_search`, future `web_fetch`), worrying about main kernel blocking during tool execution, or debugging AsyncToolExec state machine. Covers the Phase 32k Step 3 (Phase A-D2) design: how `iToolUseAndContinue` hybrid path classifies sync/async tool calls, how `iScheduleAsyncToolExecPoll` runs them in separate OS processes via `StartProcess`, and how `iAsyncToolExecFinalize` re-enters `ClaudeRunTurn` after completion. Also covers the WindowStatusArea update contract (Phase D2) for "0 sec stuck" prevention.
---

# AsyncToolExec — `iToolUseAndContinue` hybrid 経路の async tool 実行

## 概要

`$UseClaudeRuntime = True` + `ClaudeRuntime\`$ClaudeRuntimeToolAsyncDefault = True` のとき、`iToolUseAndContinue` は **hybrid 経路**に入り、tool 呼び出しを「sync (mathematica_eval 等)」と「async (web_search 等)」に振り分けて、async tool は別 OS プロセスで並列実行する。これにより **web_search 中もメインカーネルがブロックされず、別セル評価が可能**になる。

Phase 32j v1 の SessionSubmit + ScheduledTask クラッシュ実績(memory)を回避するため、**ParallelSubmit / SessionSubmit / 独自 ScheduledTask は使わず**、`StartProcess` + 既存の `ClaudeRegisterPollingTick` 経由で実装する。

## 関連する 5 段階の実装 (Phase A〜D2)

| Phase | 役割 | 主要関数 / フィールド |
|---|---|---|
| A | `iQueryAnthropicAPIWithWebSearch` を 3 段分解 + API key を file 経由化 (tasklist 漏洩防止) | `iPrepareWebSearchPS1`, `iCollectWebSearchResult`, `iQueryAnthropicAPIWithWebSearchSync` |
| B | adapter に async API を追加 | adapter キー: `AsyncToolNames`, `MaxConcurrentTools`, `SubmitToolAsync`, `CollectToolAsync`, `CancelToolAsync` |
| C | `ClaudeRuntime` 側に AsyncToolExec state machine を構築 | `iAsyncToolExecPollKey`, `iClassifyToolCalls`, `iAsyncToolExecSubmitOne`, `iScheduleAsyncToolExecPoll`, `iAsyncToolExecTickFn`, `iToolExecMergeResults`, `iAsyncToolExecFinalize`, `ClaudeRuntimeCancelAsyncToolExec`, `ClaudeRuntimeToolExecDiagnose` |
| D | `iToolUseAndContinue` を hybrid 化、`iAsyncToolExecFinalize` を ConversationState 反映 + ClaudeRunTurn 再起動 に拡張 | `$ClaudeRuntimeToolAsyncDefault`, `iResolveToolAsync`, `iToolUseAndContinueSyncLegacy`, `iToolUseAccumulateAndContinue` |
| D2 | WindowStatusArea + `$claudeProgress[pollKey]` を毎 tick 更新(「0s のまま止まったように見える」UX 解消) | `iScheduleAsyncToolExecPoll` 末尾、`iAsyncToolExecTickFn` 末尾 |

実証バージョン: `ClaudeRuntime.wl` `2026-05-14-phase-32k-step3-phaseD2-progress-display-updates`。`claudecode.wl` は `2026-05-14-phase-32k-step3-phaseB-adapter-async-api` のまま。

## フラグの組み合わせ表(実証済み)

| `$UseClaudeRuntime` | `$ClaudeRuntimeAsyncExecution` | `$ClaudeRuntimeToolAsyncDefault` | 経路 | 実証ファイル |
|---|---|---|---|---|
| False | True (default) | False (default) | claudecode 旧経路 | (常時) |
| True | False | True | DAG + Phase D | result11.nb (54.4s で完走、AsyncToolExecCompleted) |
| True | True (default) | True | DAG + Phase 32 + Phase D | result13 再試 (本流の想定組み合わせ。`Anthropic_API_Overloaded_error_result13.nb` で別クエリで成功) |

⚠️ **`$ClaudeRuntimeAsyncExecution = False` と `$UseClaudeRuntime = True` を組み合わせると、過去 runtime / polling tick の残骸との干渉で「LLM 推論段階 (QueryProvider) で 10 分以上止まる」事故が起きやすい**。実証済みの上の 3 行の組み合わせのみ使う。

## 経路分岐: `iResolveToolAsync` の優先度

`iToolUseAndContinue` は呼び出し冒頭で `iResolveToolAsync[rt, adapter]` を評価する:

```mathematica
iResolveToolAsync[rt_Association, adapter_Association] := Module[{meta, runtimeOpt, adapterOpt},
  meta = Lookup[rt, "Metadata", <||>];
  runtimeOpt = Lookup[meta, "ToolAsync", Automatic];
  Which[
    runtimeOpt === True, True,
    runtimeOpt === False, False,
    True,
      adapterOpt = Lookup[adapter, "ToolAsync", Automatic];
      Which[
        adapterOpt === True, True,
        adapterOpt === False, False,
        True, TrueQ[$ClaudeRuntimeToolAsyncDefault]]]]
```

優先度: **runtime metadata > adapter > global default**。runtime ごと / adapter ごとに上書きでき、安全のため明示 False は常に最強の override。

`iResolveToolAsync` が True でも、adapter に `AsyncToolNames` / `SubmitToolAsync` / `CollectToolAsync` が揃っていなければ自動的に **legacy 経路 (`iToolUseAndContinueSyncLegacy`)** にフォールバックする。

## hybrid 経路のフロー

```
iToolUseAndContinue
  ├ iResolveToolAsync が False or adapter 不揃い → iToolUseAndContinueSyncLegacy (Phase D 以前と同じ)
  └ True かつ adapter 揃い:
      ├ iClassifyToolCalls で sync 配列 / async 配列 (Index 保持) に振分け
      ├ sync 部分は adapter["ExecuteTools"] で先行実行(R: §3.3 準拠)
      ├ async 部分が空 → iToolUseAccumulateAndContinue で legacy と同じ形式に蓄積
      └ async あり → iScheduleAsyncToolExecPoll:
          ├ MaxConcurrent (=4) まで Queue → Running に昇格
          ├ adapter["SubmitToolAsync"] で各 async tool を別 OS プロセスで起動(StartProcess)
          ├ ClaudeRegisterPollingTick で 3 秒間隔の tick を登録 → pollKey
          ├ $claudeProgress[pollKey] を初期化 + WindowStatusArea 初期表示  ← Phase D2
          └ <|"Outcome" -> "AsyncToolExecScheduled", PollKey, InitialRunning, QueueRemaining|>

(以降は polling tick で進む)

iAsyncToolExecTickFn (3 秒毎)
  ├ Running を走査: ProcessStatus[proc] === "Finished" → adapter["CollectToolAsync"] で結果回収 → Collected へ
  ├ Timeout 超過は Failed として Collected へ移し adapter["CancelToolAsync"] で kill
  ├ Queue → Running へ昇格(MaxConcurrent 維持)
  ├ AsyncToolExec フィールド更新 ($iClaudeRuntimes[rid])
  ├ AsyncToolExecTick イベント記録
  ├ $claudeProgress[pollKey] と WindowStatusArea を更新  ← Phase D2
  └ 全完了 (Queue=∅, Running=∅) → iAsyncToolExecFinalize

iAsyncToolExecFinalize
  ├ ClaudeUnregisterPollingTick(pollKey)
  ├ iToolExecMergeResults: 元 toolCalls 順に sync 結果と async 結果を Index で復元
  ├ summary (Outcome="AsyncToolExecCompleted", Elapsed 等) を rt["LastAsyncToolExecResult"] にセット
  ├ AsyncToolExec フィールドを <|"Finalized" -> True|> にマーク (積極的に消さない)
  ├ AsyncToolExecCompleted イベント記録
  ├ iToolUseAccumulateAndContinue で ConversationState.Messages 追加 + ContinuationInput 構築
  └ Outcome=ContinuationPending なら ClaudeRunTurn[runtimeId, contInput, "Notebook"->$Failed] を起動
     (nb は Metadata 経由で ClaudeRunTurn 側が再取得する)

iOnTurnComplete
  └ outcome === "AsyncToolExecScheduled" → TurnAwaitingAsync イベントだけ記録して早期 return
     (これがないと callback が誤って Done 扱いし、notebook 書き込みが暴発する)
```

## adapter 拡張 5 キー (Phase B)

```mathematica
adapter = <|
  ... 既存キー ...,

  (* Phase B 追加 *)
  "AsyncToolNames"     -> {"web_search"},          (* async 対象 tool 名のリスト *)
  "MaxConcurrentTools" -> 4,                       (* 同時実行上限 *)
  "ToolAsync"          -> Automatic,               (* True/False/Automatic、Automatic は global default を見る *)

  "SubmitToolAsync"   -> Function[{toolCall, contextPacket},
    (* 戻り値: <|"Process" -> ProcessObject[...], "OutFile" -> "...", "ToolName", "ToolId",
                 "Index", "StartTime", "Timeout", ...|> *)
    ...],

  "CollectToolAsync"  -> Function[{runningEntry},
    (* 戻り値: <|"ToolName", "ToolId", "Success" -> _Boolean,
                 "Result" -> "<本文>", "Summary" -> "<1行>"|> *)
    ...],

  "CancelToolAsync"   -> Function[{runningEntry},
    Quiet @ KillProcess[Lookup[runningEntry, "Process", None]];
    Quiet @ DeleteFile[Lookup[runningEntry, "OutFile", ""]];
    ]
|>
```

### pollKey の構造

```
ClaudeRuntimeToolExec_<runtimeId>_<turnIndex>_<UUID>
```

例: `ClaudeRuntimeToolExec_rt-1778803257-93671_1_abf63460-18bd-4d69-a520-1bd046436a9f`

turnIndex を含めるのは、同一 runtime で複数 turn が tool 実行する場合(continuation turn の中でさらに tool 呼び出し)に競合しないため。UUID は同一 turn 内で複数回 schedule する可能性に対する保険。

## 必須遵守事項

### A. callback 抑制(レビュー §3.1)

`AsyncToolExecScheduled` を返した turn は **まだ完了していない**。`iOnTurnComplete` で以下を必ず実施:

```mathematica
If[outcome === "AsyncExecutionScheduled" ||         (* Phase 32 *)
   outcome === "AsyncToolExecScheduled",            (* Phase D *)
  iAppendEvent[runtimeId, <|"Type" -> "TurnAwaitingAsync", "Outcome" -> outcome|>];
  Return[]];
```

加えて `ClaudeApproveProposal` / `ClaudeApproveProposalWithTimeout` でも同じ outcome を即時 return すること(両方で AsyncExecutionScheduled / AsyncToolExecScheduled をスルー判定する)。

ここを抜くと、AsyncToolExec の polling 中に「DAG 視点では全ノード完了」扱いされて claudecode の `iLLMGraphDAGTick` (L21866) が `"ClaudeRuntime: 処理中... Ns"` の表示に切り替わり、ユーザに「実行が止まったように見える」UX 事故が起きる。

### B. 元順序の復元(レビュー §3.2)

`iClassifyToolCalls` は元 `toolCalls` の position を `Index` キーで保持する:

```mathematica
classified = <|
  "SyncCalls"  -> { <|"Call" -> ..., "Index" -> 1|>, <|"Call" -> ..., "Index" -> 3|>, ... },
  "AsyncCalls" -> { <|"Call" -> ..., "Index" -> 2|>, ... }|>
```

`iToolExecMergeResults[toolCalls, syncByIdx, asyncByIdx]` は Index で結果を集めて元 `toolCalls` の順序に並べ直す。これを LLM に渡す ConversationState には**元順序**で記録する。

### C. polling 登録失敗時は sync fallback ではなく Cancel(レビュー §3.6)

`SubmitToolAsync` が失敗した場合、すでに submit 済みの Running を **`CancelToolAsync` で kill** してから legacy sync 経路に落とすか、Failed として Finalize する。「途中まで async / 残りを sync」の混在は禁止 — tool 順序の整合が壊れる。

### D. ConversationState 反映は sync 経路と同じ関数経由

`iAsyncToolExecFinalize` は `iToolUseAccumulateAndContinue` を呼んで sync 経路と同じ shape で ConversationState.Messages に追加する。`Messages` の Type は `"ToolUse"`、`ToolCalls`、`ToolResults`、`TextResponse` を含む dict。これにより adapter-tool-flow-debugging skill の診断手順が async / sync 共通で使える。

### E. WindowStatusArea + `$claudeProgress` の毎 tick 更新 (Phase D2)

`iScheduleAsyncToolExecPoll` の末尾で初期表示、`iAsyncToolExecTickFn` の末尾で毎 tick 更新する:

```mathematica
(* iScheduleAsyncToolExecPoll 末尾 *)
nbForStatus = Lookup[Lookup[rt, "Metadata", <||>], "Notebook", $Failed];
If[Head[nbForStatus] =!= NotebookObject, nbForStatus = $Failed];

initialDisp = "ClaudeRuntime: Web検索並列実行中... 0s | " <>
  ToString[Length[submittedRunning]] <> "/" <>
  ToString[Length[asyncCallsWithIndex]];

If[AssociationQ[ClaudeCode`Private`$claudeProgress] &&
   KeyExistsQ[ClaudeCode`Private`$claudeProgress, pollKey],
  (* ClaudeRegisterPollingTick が先に基本キーを登録するので、その上に追加情報を載せる *)
  ClaudeCode`Private`$claudeProgress[pollKey, "startTime"]    = AbsoluteTime[];
  ClaudeCode`Private`$claudeProgress[pollKey, "status"]       = "Web検索並列実行中";
  ClaudeCode`Private`$claudeProgress[pollKey, "disp"]         = initialDisp;
  ClaudeCode`Private`$claudeProgress[pollKey, "nb"]           = nbForStatus;
  ClaudeCode`Private`$claudeProgress[pollKey, "toolUses"]     = Length[asyncCallsWithIndex];
  ClaudeCode`Private`$claudeProgress[pollKey, "textFragments"] = 0;
  ClaudeCode`Private`$claudeProgress[pollKey, "thinkingFragments"] = 0;
  ClaudeCode`Private`$claudeProgress[pollKey, "caller"]       = "ClaudeRuntime:Async-Tools"];

If[Head[nbForStatus] === NotebookObject,
  Quiet[CurrentValue[nbForStatus, WindowStatusArea] = initialDisp]];

(* iAsyncToolExecTickFn 末尾 *)
elapsed = Round[AbsoluteTime[] - startT, 1];
runC    = Length[newRunning];
doneC   = Length[collected];
totalC  = Length[Lookup[asyncRefresh, "ToolCalls", {}]];

dispText = "ClaudeRuntime: Web検索並列実行中... " <> ToString[elapsed] <>
           "s | Run:" <> ToString[runC] <>
           " Done:" <> ToString[doneC] <> "/" <> ToString[totalC];

If[StringQ[pollKey] && pollKey =!= "" && KeyExistsQ[ClaudeCode`Private`$claudeProgress, pollKey],
  ClaudeCode`Private`$claudeProgress[pollKey, "disp"]     = dispText;
  ClaudeCode`Private`$claudeProgress[pollKey, "toolUses"] = totalC];

If[Head[nbForStatus] === NotebookObject,
  Quiet[CurrentValue[nbForStatus, WindowStatusArea] = dispText]];
```

⚠️ **`$claudeProgress[pollKey]` への書き込み順序**: `ClaudeRegisterPollingTick` を**呼んだ後**に追加情報を書く。先に書くと `ClaudeRegisterPollingTick` が `$claudeProgress[key] = <|...|>` で全置換し、追加情報が消える。

### F. API key を file 経由(Phase A)

PowerShell で Anthropic API を叩く場合、API key を **タスクラインに置かず**、一時 file に書いて `Get-Content` で読ませる:

```powershell
$apiKey = (Get-Content -Raw -Path "$keyFile").Trim()
Remove-Item -Path "$keyFile" -Force -ErrorAction SilentlyContinue
```

Mathematica 側は `iPrepareWebSearchPS1` で key file 作成 → PowerShell 起動 → 直後に file 削除を試みる(子プロセス読込との競合は PowerShell 側で扱う)。`tasklist` / `ps -ef` への key 漏洩を防ぐ。

## 状態確認 API

| API | 用途 |
|---|---|
| `ClaudeRuntimeToolExecDiagnose[runtimeId]` | Active / Finalized / Queue/Running/Collected サイズ、各 Index、Elapsed |
| `ClaudeTurnTrace[runtimeId]` | AsyncToolExec 系イベント (ToolClassified, AsyncToolExecStarted, AsyncToolExecTick, AsyncToolExecCompleted, TurnAwaitingAsync, ToolsExecuted, ToolContinuationScheduled) |
| `ClaudeRuntime\`Private\`$iClaudeRuntimes[rid]["LastAsyncToolExecResult"]` | summary (Outcome, Elapsed, ToolCount, AsyncCount, ToolResults) |
| `ClaudeRuntime\`Private\`$iClaudeRuntimes[rid]["AsyncToolExec"]` | 進行中なら state machine、完了済みなら `<|"Finalized" -> True, "LastSummary" -> ...|>` |
| `ClaudeRuntimeCancelAsyncToolExec[rid]` | 進行中の Running を全部 Cancel + tick unregister + Finalized=True |
| `ClaudePollingTickKeys[]` | 登録中 polling tick 一覧 (`ClaudeRuntimeToolExec_*` を grep して残骸チェック) |

## 正常な trace パターン (1 async tool turn)

```
Created → StatusChange → TurnStarted → ContextBuilt → ProviderLaunched
→ ProviderQueried → ProposalParsed → ToolUseDetected
→ ToolClassified (TotalCalls=N, SyncCount=K, AsyncCount=N-K)
→ AsyncToolExecStarted (TotalAsync, InitialRunning, MaxConcurrent=4)
→ TurnAwaitingAsync (Outcome="AsyncToolExecScheduled")           ← この turn はここで終わる
→ AsyncToolExecTick (CompletedIdxs={1}, Running=1, Queue=0)       ← polling
→ AsyncToolExecTick (CompletedIdxs={2}, Running=0, Queue=0)
→ AsyncToolExecCompleted (ToolCount=N, Elapsed≈50s)
→ ToolsExecuted (ToolCount=N)
→ ToolContinuationScheduled
→ StatusChange → StatusChange
→ TurnStarted (continuation turn)
→ ContextBuilt → ProviderLaunched → ProviderQueried → ProposalParsed
→ ValidationComplete → ResultRedacted → ContinuationScheduled
→ ... → TurnComplete
```

result11.nb で実証済み(37 イベント、Elapsed 54.4s、ToolCount=2、AsyncCount=2)。

## 異常パターンとデバッグ

| 症状 | 疑う場所 |
|---|---|
| 「ClaudeRuntime: 処理中... Ns」が止まる(Phase D2 表示が出ない) | `iScheduleAsyncToolExecPoll` 末尾の `$claudeProgress[pollKey, ...]` 書込が失敗。pollKey が `ClaudeRegisterPollingTick` 後に初期化されていないか確認。Or claudecode の `iLLMGraphDAGTick` L21866 表示が優位 (Phase D 経路に入っていない) |
| `Keys[$iClaudeRuntimes] = {}` だが ClaudeEval は実行中 | runtime ID は完了後も保持されるので、これは古い state のクリア漏れ。あるいは ClaudeEval が claudecode の旧経路で動いている(`$UseClaudeRuntime` 確認) |
| 10 分以上 stuck で `CurrentPhase = "QueryProvider"` | LLM 推論段階で止まっている(Phase D の責任範囲外)。`$ClaudeRuntimeAsyncExecution = False` + 過去 runtime の polling tick 残骸の干渉が典型。Mathematica 再起動 + 実証済み組み合わせで再試 |
| `Active = False` で trace が 5 件しかない(`Created, StatusChange, ContextBuilt, ProviderLaunched, TurnStarted`) | ProviderQueried に到達していない = LLM 応答が来ていない。`ClaudeRateLimitStatus[]`、Anthropic 側 overloaded_error、`$claudeProgress[dag-...]` を確認 |
| DAG 完了したのに notebook に出力なし | iAsyncToolExecFinalize の continuation turn 起動が失敗。Metadata["Notebook"] が落ちている可能性、または `iOnTurnComplete` の AsyncToolExecScheduled 早期 return が抜けて callback が暴発した可能性 |
| tool 1 つが成功、もう 1 つが Anthropic `overloaded_error` で失敗 | tool 結果は届くが、生 stdout が text セルに大量に漏れることがある(Phase 30 系列の延長で対処すべき軽微な課題) |

## 状態をクリーンアップする手順

「動作が変だが Mathematica を再起動したくない」場合の手順:

```mathematica
(* 1. 走行中 runtime を全部 cancel *)
Scan[ClaudeRuntimeCancel, Keys[ClaudeRuntime`Private`$iClaudeRuntimes]];

(* 2. polling tick を全部解除 *)
Scan[ClaudeUnregisterPollingTick, ClaudePollingTickKeys[]];

(* 3. DAG job / progress テーブルを初期化 *)
ClaudeCode`Private`$iLLMGraphDAGJobs = <||>;
ClaudeCode`Private`$claudeProgress  = <||>;

(* 4. フラグをデフォルトに *)
$UseClaudeRuntime              = False;
$ClaudeRuntimeAsyncExecution   = True;     (* デフォルト *)
ClaudeRuntime`$ClaudeRuntimeToolAsyncDefault = False;
```

ただし**多重 runtime / 多重 polling tick が干渉した状態は完全に拭えないことが多い**。10 分以上 stuck したら **Mathematica を完全再起動**するのが結局一番速い。

## 今後の拡張

- **Phase E**: `web_fetch` を async 化する。設計上 `web_search` と完全に同じパターン(`AsyncToolNames` に `"web_fetch"` を追加 + `SubmitToolAsync` の実装を分岐)。
- **Phase F**: tool エラー時の gracefully recovery。1 つ失敗、1 つ成功のケースで LLM が「N 個中 K 個取得できなかった」を読みやすい形に渡す。
- **API 過負荷時の retry**: 現在は `overloaded_error` を素通しで LLM に渡している。Phase A 内で短い backoff + retry を入れる余地あり(2 回まで等)。

## 関連参照

- Rule: `100-async-tool-execution.md` — async tool 実行設計の必須ルール
- Rule: `99-adapter-tool-flow.md` — adapter 経路 tool flow の規範(R1〜R7)
- Rule: `95-scheduled-task-safety.md` — D節(deferred sync runState)が AsyncToolExec の `StartProcess` パターンの基礎
- Skill: `adapter-tool-flow-debugging` — turn pipeline 異常の系統的切り分け
- Skill: `runtime-orchestrator-boundary` — 「1 turn 内の tool call 並列発火」が ClaudeRuntime 側に置かれる根拠
- Skill: `llmgraph-dag-job-lifecycle` — `$iLLMGraphDAGJobs` の registry と onComplete タイミング(AsyncToolExec の上位 DAG 視点)
