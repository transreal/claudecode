---
paths:
  - "**/{claudecode,ClaudeRuntime,ClaudeOrchestrator}*.{wl,wls,m}"
---

# 100 — Async Tool Execution 設計の必須ルール

## 対象

`$UseClaudeRuntime = True` + `ClaudeRuntime\`$ClaudeRuntimeToolAsyncDefault = True` で走る AsyncToolExec 経路 (Phase 32k Step 3 Phase A〜D2)。

- `iToolUseAndContinue` の hybrid 経路
- `iScheduleAsyncToolExecPoll` / `iAsyncToolExecTickFn` / `iAsyncToolExecFinalize`
- adapter の `SubmitToolAsync` / `CollectToolAsync` / `CancelToolAsync`
- `iOnTurnComplete` / `ClaudeApproveProposal*` の `AsyncToolExecScheduled` 早期 return

このパスを変更する PR で以下を守ること。

## R1: 並列実行に `ParallelSubmit` / `SessionSubmit` / 独自 `ScheduledTask` を使わない

Phase 32j v1 で SessionSubmit + ScheduledTask クラッシュ実績(memory)があり、AsyncToolExec はその回避策として実装されている。tool の並列実行は **必ず以下のパターン**で行う:

```mathematica
(* ✅ 正しいパターン: 別 OS プロセスを起動して polling tick で監視 *)
proc = StartProcess[{"powershell", "-File", ps1File, ...}];
(* ProcessObject は即返却される → メインカーネル非ブロック *)

(* polling は claudecode の既存基盤に委ねる *)
ClaudeRegisterPollingTick[pollKey, tickFn, IntervalSeconds -> 3]
```

```mathematica
(* ❌ 禁止: ParallelSubmit を使ってカーネル並列で web_search を走らせる *)
jobs = ParallelSubmit /@ tasks;
results = ParallelEvaluate[...];   (* Wolfram カーネル間の競合・サブプロセス孤立 *)

(* ❌ 禁止: SessionSubmit + ScheduledTask の組み合わせ
   → Phase 32j v1 で実証済みクラッシュ要因 *)
SessionSubmit[ScheduledTask[...]];

(* ❌ 禁止: パッケージ内で独自に CreateScheduledTask
   → rule 95 §B 違反 *)
RunScheduledTask[
  Module[{},
    If[ProcessStatus[proc] === "Finished", ...]],
  1]
```

詳細は `rules/95-scheduled-task-safety.md` 節 B（独自 ScheduledTask 禁止）と節 D（deferred sync runState）を参照。

## R2: `AsyncToolExecScheduled` を返した turn は callback で **早期 return**

`iToolUseAndContinue` が `<|"Outcome" -> "AsyncToolExecScheduled", ...|>` を返した turn は **まだ完了していない**。`iOnTurnComplete` および `ClaudeApproveProposal*` で必ず早期 return すること:

```mathematica
(* ✅ 正しい: AsyncToolExecScheduled を見たら TurnAwaitingAsync を記録して即 return *)
If[outcome === "AsyncExecutionScheduled" ||         (* Phase 32 *)
   outcome === "AsyncToolExecScheduled",            (* Phase D *)
  iAppendEvent[runtimeId, <|"Type" -> "TurnAwaitingAsync",
                            "Outcome" -> outcome|>];
  Return[]];

(* この後 polling tick が完走 → iAsyncToolExecFinalize が
   ConversationState を反映 + 新しい ClaudeRunTurn を起動する *)
```

```mathematica
(* ❌ 禁止: AsyncToolExecScheduled でも Done 扱いの後段処理を走らせる
   → DAG が「完了」を誤検出して "ClaudeRuntime: 処理中... Ns" 表示に切り替わり
     ユーザに「止まったように見える」UX 事故 *)
If[outcome === "AsyncToolExecScheduled",
  iScheduleNextTurn[...]];       (* これは Finalize 側の仕事 *)
iRuntimeDisplayResult[...];      (* AsyncToolExec 中に notebook 書込みが暴発 *)
```

callback 抑制が漏れていると、Image で「ClaudeRuntime: 処理中... 232s」のような「ノード完了したのに onComplete が呼ばれない」表示に切り替わる(claudecode の `iLLMGraphDAGTick` L21866 の True 分岐)。

## R3: tool 結果は `Index` キーで元順序を保持し、`iToolExecMergeResults` でマージする

`iClassifyToolCalls` で sync / async に振り分けるとき、元 `toolCalls` の position を `Index` キーに保持する:

```mathematica
(* ✅ 正しい: Index 保持 *)
classified = <|
  "SyncCalls"  -> {<|"Call" -> tc1, "Index" -> 1|>,
                   <|"Call" -> tc3, "Index" -> 3|>},
  "AsyncCalls" -> {<|"Call" -> tc2, "Index" -> 2|>,
                   <|"Call" -> tc4, "Index" -> 4|>}
|>;

(* マージ時に Index で元順序復元 *)
merged = iToolExecMergeResults[toolCalls, syncResultsByIdx, asyncResultsByIdx]
```

```mathematica
(* ❌ 禁止: sync を先に並べて async を後ろに追加するだけだと
   LLM に渡す tool_result の順序が tool_use の順序とずれる *)
merged = Join[syncResults, asyncResults]    (* 順序が tool_use と一致しない *)
```

`Index` 復元を怠ると、Anthropic API の制約「tool_result は対応する tool_use と同じ順序で並べる」に違反し、API エラーまたは LLM の誤読を招く。

## R4: `SubmitToolAsync` 失敗時は **既に submit した tool を Cancel** してから fallback

`iScheduleAsyncToolExecPoll` で N 個 submit 中に途中で `SubmitToolAsync` が失敗した場合、以下のいずれかを選ぶ:

| 選択肢 | 動作 |
|---|---|
| 全 abort | 既に Running の tool を `CancelToolAsync` で kill → `AsyncToolExecFailed` で Finalize |
| sync fallback | 同上 + その後 `iToolUseAndContinueSyncLegacy` に落とす |

```mathematica
(* ✅ 正しい: 部分失敗時に既存 Running を Cancel してから fallback *)
If[!AssociationQ[submitResult] || !MatchQ[Lookup[submitResult, "Process"], _ProcessObject],
  (* 既に Running の Cancel *)
  Do[adapter["CancelToolAsync"][r], {r, alreadyRunning}];
  iAppendEvent[runtimeId, <|"Type" -> "AsyncToolExecFailed",
                            "Reason" -> "SubmitFailed"|>];
  (* sync legacy に fallback *)
  Return[iToolUseAndContinueSyncLegacy[runtimeId, ...]]]
```

```mathematica
(* ❌ 禁止: 「途中まで async / 残りを sync」の混在
   → tool 順序が壊れる、Cancel もれの孤立プロセスが残る *)
If[submitFailed,
  syncResults = adapter["ExecuteTools"][remainingCalls];   (* これがダメ *)
  ...]
```

レビュー §3.6 参照。

## R5: ConversationState への反映は sync 経路と同じ関数経由

`iAsyncToolExecFinalize` は **`iToolUseAccumulateAndContinue` を呼んで** sync 経路と同じ shape で ConversationState.Messages に追加する:

```mathematica
(* ✅ 正しい: Finalize は merge → accumulate → ClaudeRunTurn 再起動 *)
merged = iToolExecMergeResults[toolCalls, syncByIdx, asyncByIdx];
{newConvState, contInput} = iToolUseAccumulateAndContinue[
  runtimeId, currentMsgs, toolCalls, merged, textResp];
(* ConversationState.Messages に "ToolUse" Type で append *)

(* nb は Metadata 経由で取り回す *)
ClaudeRunTurn[runtimeId, contInput, "Notebook" -> $Failed]
```

```mathematica
(* ❌ 禁止: Async 専用の異なる shape で Messages に書く
   → adapter-tool-flow-debugging skill の診断が機能しなくなる
     (skill は "ToolUse"/"ToolCalls"/"ToolResults" を前提) *)
AppendTo[msgs, <|"Type" -> "AsyncToolResult", "AsyncData" -> ...|>]
```

## R6: pollKey は runtime + turn + UUID で **同一 turn 内多重 schedule も衝突しない**

```mathematica
(* ✅ 正しい: pollKey にすべての必要要素を含める *)
pollKey = "ClaudeRuntimeToolExec_" <> runtimeId <> "_" <>
          ToString[turnIndex] <> "_" <> CreateUUID[]
(* 例: ClaudeRuntimeToolExec_rt-1778803257-93671_1_abf63460-...-a9f *)
```

```mathematica
(* ❌ 禁止: turn を含めないと continuation turn 内で再 tool 実行する場合に衝突 *)
pollKey = "AsyncToolExec_" <> runtimeId
```

`ClaudeRegisterPollingTick` は key 重複時に古い tick を上書きしてしまうので、weak unique key の設計を死守する。

## R7: API key は **file 経由**で子プロセスに渡す(タスクライン漏洩防止)

PowerShell で Anthropic API を叩く場合(`web_search`, 将来の `web_fetch`):

```mathematica
(* ✅ 正しい: 一時 file に key を書いて子プロセスから読ませる *)
keyFile = FileNameJoin[{$workDir, "anth_key_" <> CreateUUID[] <> ".txt"}];
Export[keyFile, apiKey, "Text"];

(* PowerShell スクリプト内で *)
(* $apiKey = (Get-Content -Raw -Path "$keyFile").Trim()
   Remove-Item -Path "$keyFile" -Force -ErrorAction SilentlyContinue *)

proc = StartProcess[{"powershell", "-File", ps1File, "-KeyFile", keyFile, ...}];

(* Mathematica 側も後始末を試みる *)
Quiet @ DeleteFile[keyFile]
```

```mathematica
(* ❌ 禁止: API key をコマンドライン引数で渡す
   → tasklist / Process Explorer で平文露出 *)
proc = StartProcess[{"powershell", "-File", ps1File,
                     "-ApiKey", apiKey, ...}];
```

これは Phase A の中核改修。`iQueryAnthropicAPIWithWebSearch` を 3 段(`iPrepareWebSearchPS1` / `StartProcess` / `iCollectWebSearchResult`)に分解した目的の一つがこれ。

## R8: `$claudeProgress[pollKey]` への書き込みは `ClaudeRegisterPollingTick` **の後**

`ClaudeRegisterPollingTick` は内部で `$claudeProgress[key] = <|...基本キー...|>` で全置換するため、**先に書いた追加情報は消える**:

```mathematica
(* ✅ 正しい順序 *)
ClaudeRegisterPollingTick[pollKey, tickFn, IntervalSeconds -> 3];

If[KeyExistsQ[ClaudeCode`Private`$claudeProgress, pollKey],
  ClaudeCode`Private`$claudeProgress[pollKey, "disp"]   = initialDisp;
  ClaudeCode`Private`$claudeProgress[pollKey, "nb"]     = nbForStatus;
  ClaudeCode`Private`$claudeProgress[pollKey, "caller"] = "ClaudeRuntime:Async-Tools";
  ...]
```

```mathematica
(* ❌ 禁止: 先に書き込む → 全置換で消える *)
ClaudeCode`Private`$claudeProgress[pollKey] = <|"disp" -> initialDisp, ...|>;
ClaudeRegisterPollingTick[pollKey, tickFn, ...];   (* ここで全置換される *)
```

ステータスバーの「0s のまま止まる」UX 不具合(Phase D2 開始時の主症状)の典型原因。

## R9: WindowStatusArea 更新には **runtime metadata 経由で取得した nb** を使う

`iAsyncToolExecTickFn` の中で notebook を `EvaluationNotebook[]` から取得すると、polling tick の評価コンテキストには現在 notebook が存在せず `$Failed` になる:

```mathematica
(* ✅ 正しい: Metadata["Notebook"] から取得、Head チェック *)
nbForStatus = Lookup[Lookup[rt, "Metadata", <||>], "Notebook", $Failed];
If[Head[nbForStatus] === NotebookObject,
  Quiet[CurrentValue[nbForStatus, WindowStatusArea] = dispText]]
```

```mathematica
(* ❌ 禁止: tick fn から EvaluationNotebook[] を呼ぶ
   → polling 経路ではコンテキストが無く $Failed *)
nb = EvaluationNotebook[];
CurrentValue[nb, WindowStatusArea] = ...   (* セルが無いので無視される *)
```

ClaudeRunTurn 起動時に `Metadata["Notebook"]` に元 nb を保存しておくこと。Phase D の `iAsyncToolExecFinalize` で次の turn を起こす際も `"Notebook" -> $Failed` を渡し、ClaudeRunTurn 側が `Metadata` から取り戻す設計。

## R10: フラグ組み合わせは **実証済みパターン**のみ使う

下表以外の組み合わせは想定外で、bug を引き起こしやすい:

| `$UseClaudeRuntime` | `$ClaudeRuntimeAsyncExecution` | `$ClaudeRuntimeToolAsyncDefault` | 用途 |
|---|---|---|---|
| `False` | `True` | `False` | claudecode 旧経路(常時動作) |
| `True` | `False` | `True` | DAG + Phase D 単独(result11.nb で 54.4s 実証) |
| `True` | `True` | `True` | DAG + Phase 32 + Phase D 統合(本流) |

```mathematica
(* ❌ 危険: $UseClaudeRuntime = True で AsyncExecution = False、
   かつ過去 runtime / polling tick の残骸がある状態
   → QueryProvider 段階で 10 分以上 stuck の事故報告あり *)
```

長時間 stuck したら(数分以上 trace が進まない)、`ClaudeRuntimeToolExecDiagnose[rid]` と `ClaudeTurnTrace[rid]` で診断 → ダメなら **Mathematica 完全再起動**。詳細は skill `adapter-tool-flow-debugging` の「症状カタログ」と skill `async-tool-execution` の「状態をクリーンアップする手順」を参照。

## R11: legacy fallback を残す

`iResolveToolAsync[rt, adapter]` が False を返したとき、または adapter に async API キーが欠けているとき、`iToolUseAndContinue` は **無条件で `iToolUseAndContinueSyncLegacy` に fallback** すること:

```mathematica
(* ✅ 正しい: 安全側に倒す *)
If[!iResolveToolAsync[rt, adapter] ||
   !(KeyExistsQ[adapter, "SubmitToolAsync"] &&
     KeyExistsQ[adapter, "CollectToolAsync"] &&
     KeyExistsQ[adapter, "AsyncToolNames"]),
  Return[iToolUseAndContinueSyncLegacy[runtimeId, ...]]]
```

これにより以下が保証される:

- Phase D 改修前と互換性のあるカスタム adapter は壊れない
- ToolAsync = False の明示的指定が常に効く
- 万一 hybrid 経路で問題が起きたときに **runtime ごとに切り戻せる**

## 関連参照

- Skill: `async-tool-execution` — 設計の全体像、フロー、デバッグ手順
- Skill: `adapter-tool-flow-debugging` — turn pipeline 異常の系統的切り分け
- Skill: `runtime-orchestrator-boundary` — 「1 turn 内の tool call 並列発火」が Runtime 側に置かれる根拠
- Rule: `95-scheduled-task-safety.md` 節 D — `StartProcess` + 既存 polling tick パターンの基礎
- Rule: `99-adapter-tool-flow.md` — adapter 経路 tool flow 一般の規範
