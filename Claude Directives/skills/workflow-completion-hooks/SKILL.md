---
name: workflow-completion-hooks
description: ClaudeOrchestrator`Workflow` の completion hook 機構の使い方と設計上の注意点。Use when implementing event-driven workflow completion handling, when wrapping LLMStateGraph OnGraphComplete callbacks via the shim, or when adding new use cases that need to know "this workflow finished" without polling. Workflow Migration Stage B Week 2c-2c で導入された機構。
---

# Workflow completion hooks

## 主軸の問い

> **workflow が完了したことを polling せずに知りたいか?**

- Yes (event-driven 後段処理が要る) → **completion hook を使う**
- No (戻り値で十分、または `ClaudeWaitWorkflow` で polling して問題ない) → 使わない

## 何を解決するための機構か

`ClaudeOrchestrator`Workflow`` の Async モード (`ClaudeRunWorkflow[wid, "Async" -> True]`) は呼び出し側に sgRid だけを返して polling tick で進む。完了を知るには:

(a) `ClaudeWaitWorkflow[wid]` で block する
(b) `ClaudeAsyncJobInfo[wid]` を polling する
(c) **completion hook を登録して event-driven で受け取る** ← 本機構

(a)/(b) は呼び出し側が「待つ責任」を負う。(c) は workflow 側が「完了を伝える責任」を負う。複数 workflow を並列に走らせて完了順に処理したい場合や、別スレッドのコードに完了を伝えたい場合は (c) しか選択肢がない。

## API

```mathematica
ClaudeRegisterCompletionHook[wid_String, fn_]
   → <|"WorkflowId", "HookCount", "FiredImmediately"|>

ClaudeUnregisterCompletionHooks[wid_String]
   → <|"WorkflowId", "Removed"|>
```

`fn` は **1 引数の Function** で、次の Association を受け取る:

```mathematica
<|"WorkflowId"        -> "wf-...",
  "Status"            -> "Done"|"Cancelled"|"Failed"|...,
  "TerminationReason" -> "ReachedFinalPlace"|"Timeout"|"MaxStepsReached"|
                         "Cancelled"|"Stuck"|"NeedsApproval"|"Blocked"|
                         "WorkflowDisappeared",
  "Mode"              -> "Sync"|"Async"|"Immediate",
  "ElapsedSec"        -> _Real,
  "Steps"             -> _Integer,
  "FinalMarking"      -> <|placeName -> {tids}, ...|>,
  "EndTime"           -> _Real|>
```

## 発火セマンティクス

### 一回限り発火

`iFireCompletionHooks` は発火**前**に `KeyDropFrom[$iWorkflowCompletionHooks, wid]` で hooks を消去するため、同じ wid に対して二度発火することはない。

### 例外隔離

各 hook は `Quiet @ Check[hook[completionInfo], Null]` で囲まれているため、1 つの hook が例外を投げても他の hook の発火を阻害しない。

### 発火点

| 経路 | 発火位置 | Mode value |
|---|---|---|
| `ClaudeRunWorkflow[Async->False]` | `iRunWorkflowSync` 戻り値**直前** | `"Sync"` |
| `ClaudeRunWorkflow[Async->True]` の polling tick | `iMarkAsyncCompleted` 内 | `"Async"` |
| 既に完了済み workflow への登録時 | `ClaudeRegisterCompletionHook` 内 | `"Immediate"` |

### 完了済み workflow への登録 = 即時発火

```mathematica
(* race condition 回避: workflow が既に終わっていても hook は呼ばれる *)
result = ClaudeRegisterCompletionHook[wid, fn];
result["FiredImmediately"]   (* True なら登録ではなく即時発火だった *)
```

## 典型的な使い方

### パターン1: Async 完了通知

```mathematica
wid = ClaudeCreateWorkflowNet[spec];
ClaudeSubmitToken[wid, token];

ClaudeRegisterCompletionHook[wid, Function[info,
  Print["完了: ", info["Status"], " in ", info["ElapsedSec"], "s"];
]];

ClaudeRunWorkflow[wid, "Async" -> True];
(* この時点で呼び出し側は他の処理を進められる *)
```

### パターン2: 複数 workflow の completion-driven 後段処理

```mathematica
collected = {};
allDone = False;
expectedCount = Length[graphs];

Do[
  wid = launchWorkflow[graph];
  ClaudeRegisterCompletionHook[wid, Function[info,
    AppendTo[collected, info];
    If[Length[collected] >= expectedCount, allDone = True];
  ]],
  {graph, graphs}
];

(* polling せずに allDone を待つ別ロジック *)
```

### パターン3: Shim 経由 RunStateGraph の OnGraphComplete

shim が内部でこのパターンを使っている。`iMakeStateGraphCallbackAdapter` で workflow completion info → stategraph runtime 形式 Association に変換して元 callback を呼ぶ。

```mathematica
hookAdapter = iMakeStateGraphCallbackAdapter[sgRid, wid, callback];
ClaudeRegisterCompletionHook[wid, hookAdapter];
```

## 設計上の注意点

### 1. hook の中で重い処理を直接やらない

Sync 経路の場合、hook は `iRunWorkflowSync` の return より前で呼ばれる。hook 内で長時間 block するコードを書くと `ClaudeRunWorkflow` の戻りも遅れる。Async 経路でも同様 (polling tick の中で呼ばれるので、tick が長引く)。

重い処理が要るなら、hook の中で flag だけセットして、別経路で処理するパターンを推奨。

### 2. hook の中で別 workflow を起動するのは OK

`iFireCompletionHooks` は発火前に hooks を消去するので、hook 内で `ClaudeRegisterCompletionHook` を別 wid に対して呼んでも再入問題は起きない。同 wid に対しても安全 (workflow は既に完了しているので fire することがない)。

### 3. workflow が消されている場合

`iMarkAsyncCompleted` 内で `KeyExistsQ[$iWorkflowNets, wid]` を確認し、消えていれば `Status -> "Unknown"`, `FinalMarking -> <||>` で fire する (`reason -> "WorkflowDisappeared"`)。hook 側で `Status` を必ず確認すること。

### 4. Cancel と hook の関係

`ClaudeCancelWorkflow[wid]` を呼ぶと:
- Sync 中だった場合: `terminationReason = "Cancelled"` (実際は status 経由) で hook 発火
- Async 中だった場合: `iWorkflowAsyncTick` の次回呼び出しで Cancel 検知 → `iMarkAsyncCompleted[wid, "Cancelled"]` → hook 発火

つまり Cancel しても hook は確実に呼ばれる。Cancel と hook unregister のレースが心配なら、明示的に `ClaudeUnregisterCompletionHooks[wid]` してから Cancel する。

### 5. snapshot/restore との関係

`ClaudeSnapshotWorkflow` は **hook を保存しない** (Function は serialize しないため意図的)。Restore 後、再度 `ClaudeRunWorkflow` する場合は `ClaudeRegisterCompletionHook` を再登録する必要がある。

## 実装内部

### Registry

```mathematica
$iWorkflowCompletionHooks   (* Association: wid -> List of fn *)
```

`Begin["`Private`"]` 内で初期化。Snapshot には含めない。

### iFireCompletionHooks

```mathematica
iFireCompletionHooks[wid_String, completionInfo_Association] :=
  Module[{hooks},
    hooks = Lookup[$iWorkflowCompletionHooks, wid, {}];
    If[Length[hooks] === 0, Return[]];
    KeyDropFrom[$iWorkflowCompletionHooks, wid];   (* 再入防止 *)
    Do[
      Quiet @ Check[hook[completionInfo], Null],
      {hook, hooks}
    ];
  ];
```

ポイント:
- `KeyDropFrom` は `Quiet @ Check` の前に行う (発火中の例外で hooks が残ったまま再入されるのを防ぐ)
- `Do` のループ変数 `hook` は Module 内のローカル

### Sync 発火 (iRunWorkflowSync)

戻り値を直接 return する代わりに、Module を入れ子にして:

```mathematica
Module[{result, finalMarking},
  finalMarking = iComputeCurrentMarking[wid];
  result = <|...|>;
  iFireCompletionHooks[wid, <|... "Mode" -> "Sync", ...|>];
  result    (* 最後に result を返す *)
]
```

### Async 発火 (iMarkAsyncCompleted)

`$iWorkflowAsyncJobs[wid]` を `"Status" -> "Completed"` に更新した**後**に fire。

```mathematica
AssociateTo[$iWorkflowAsyncJobs, wid -> ...];
(* ↑ ここで $iWorkflowAsyncJobs は Completed 状態 *)
iFireCompletionHooks[wid, <|... "Mode" -> "Async", ...|>];
(* hook が ClaudeAsyncJobInfo[wid] を呼ぶと "Completed" が返る *)
```

## アンチパターン

### NG: hook を runtime 内で持つ

ClaudeRuntime に hook 機構を持たせるのは Runtime/Orchestrator boundary 違反 (workflow state を Runtime に持たせる)。**hook は必ず Workflow 側**。

### NG: hook を ScheduledTask で別スレッド起動

Mathematica のスレッドモデル上、別 ScheduledTask で hook を呼ぶと evaluation race が起きる。同期的に発火する設計を維持する。

### NG: hook の中で hook を fire しようとする

`iFireCompletionHooks` を直接呼ばない。Public API (`ClaudeRegisterCompletionHook` など) で完了済みなら自動的に fire する仕組みになっている。

## 関連

- `runtime-orchestrator-boundary` - Workflow 側に hook を置く根拠
- `workflow-shim-forwarding-design` - shim 経由で stategraph callback 互換にする adapter
- `Workflow_Migration_StageB_Design_Notes.md` §7 (Directives 連携) — DirectiveBundle と hook の関係 (将来)

## 寿命について

本 skill は `ClaudeOrchestrator`Workflow`` が deprecated でない限り恒常的に有効。Stage C 完了後も使い続けられる。
