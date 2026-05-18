---
name: async-handler-pattern
description: ClaudeOrchestrator Workflow で「handler が非同期 LLM 呼び出しを投げて Status -> AwaitingLLM を返し、 callback または engine timer 経由で完了する」Z 案パターンの正しい書き方と落とし穴。 WorkflowNet, WorkflowTransition, ClaudeQueryAsyncSilent, ClaudeCompleteHandlerOutput, ClaudeAwaitingTransitions, AwaitingLLMTimeout, DefaultAwaitingLLMTimeout, ClaudeSnapshotWorkflow, ClaudeRestoreWorkflow, $iRestoreFallbackTimeout を扱うとき、または「非同期 handler」「awaiting LLM」「Z 案」「awaitId」「AwaitingLLMTransitions」「callback handler」「handler が AwaitingLLM」のいずれかの言葉が出たら必ずこのスキルを参照する。 また workflow が AwaitingLLM 状態で停滞している、 timeout 発火が動かない、 snapshot 復元後に完了しない、 callback が二重発火する、 といった症状の診断にも使う。

---

# 非同期 handler パターン (Z 案)

`ClaudeOrchestrator.Workflow` で transition の handler から **非同期 LLM 呼び出し** を投げ、 LLM 応答到着まで workflow 全体をブロックせずに待つパターン。 Stage 2-A〜D (2026-05-17) で正式に確立。

## 基本フロー

1. handler が `<|"Status" -> "AwaitingLLM"|>` を返す (即座)
2. engine が input token を **consume**、 output token は **produce せず** 保留
3. `AwaitingLLMTransitions[awaitId]` レジストリに登録 (Trace に `TransitionAwaiting` event)
4. LLM 応答到着時に callback が `ClaudeCompleteHandlerOutput[wid, awaitId, output]` を呼ぶ
5. engine が output token を produce、 transition firing 完了

## handler テンプレート

```mathematica
asyncHandler = Function[binding,
  Module[{wid, aid, prompt},
    wid    = $ClaudeCurrentWid;          (* Awaiting handler 内のみ動的束縛 *)
    aid    = $ClaudeCurrentAwaitId;
    prompt = binding[["Input", "Payload", "text"]];

    (* 非同期 LLM 呼び出しを投げる *)
    ClaudeQueryAsyncSilent[prompt,
      "OnResponse" -> Function[response,
        ClaudeCompleteHandlerOutput[wid, aid,
          <|"Payload" -> <|"echo" -> response|>|>]]];

    (* 即座に AwaitingLLM を返す *)
    <|"Status" -> "AwaitingLLM"|>]];
```

## 動的束縛 ($ClaudeCurrent* 系)

Awaiting handler 内**でのみ** Block で動的束縛される変数:

| 変数 | 内容 |
|---|---|
| `$ClaudeCurrentWid` | 現在の workflow id |
| `$ClaudeCurrentAwaitId` | 現在の await id (ClaudeCompleteHandlerOutput に渡す) |
| `$ClaudeCurrentTransition` | 現在の transition 名 |
| `$ClaudeCurrentBinding` | binding Association (closure が効かない場合の fallback) |

handler 外で参照すると `Missing["NotInHandler"]` を返す。 callback の closure に必要な値は handler 内で **必ず** 局所変数にコピーしてから使う (callback は handler 外で評価されるため)。

## engine 側 timeout (C 拡張, 2026-05-17)

callback が来ない場合のセーフティーネットとして engine が自動的にタイマーを仕掛ける:

### transition 個別
```mathematica
WorkflowTransition["Echo",
  ...,
  "RuntimeSpec" -> <|
    "Handler"            -> asyncHandler,
    "AwaitingLLMTimeout" -> 30.0    (* 30 秒 *)
  |>]
```

### workflow 全体のデフォルト
```mathematica
WorkflowNet[...,
  "DefaultAwaitingLLMTimeout" -> 60.0    (* 60 秒 *)
]
```

### 優先順序
`trans.RuntimeSpec.AwaitingLLMTimeout` > `wf.DefaultAwaitingLLMTimeout` > なし (timer 仕掛けない)

値は `NumericQ && > 0` のときのみ有効。 `None` (デフォルト) なら現状互換挙動。

### timeout 発火時の挙動
engine は自動的に `ClaudeCompleteHandlerOutput` を呼び、 fallback Payload を構築:
```mathematica
<|"Payload" ->
    Append[元の partialPayload,
      <|"_timeout" -> True, "_handler" -> transitionName|>]|>
```
元の `partialPayload` は保持され、 `_timeout` と `_handler` が追加されるだけ。

## Snapshot / Restore (D 拡張, 2026-05-17)

`ClaudeSnapshotWorkflow[wid]` は AwaitingLLM 状態を含む全状態を `.wl` (meta.wl + workflow.wl) で保存。

`ClaudeRestoreWorkflow[snapDir]` は新 wid で復元し、 復元時に各 AwaitingLLM entry に **engine timer を再仕掛け** する:

- callback (Function closure) は復元できない
- timer のみ復活、 元の timeout 設定 (transition / workflow) を尊重
- どちらも未指定の場合は `$iRestoreFallbackTimeout` (デフォルト 0.1 秒)
- fallback Payload に `_restored -> True` を追加、 後段 transition が Restore 起源を識別可能:
  ```mathematica
  <|"_timeout" -> True, "_handler" -> tname, "_restored" -> True|>
  ```

Restore 前に `$iRestoreFallbackTimeout` を書き換えれば調整可能 (例: 60 秒に伸ばす)。

## 二重発火安全性

`ClaudeCompleteHandlerOutput` は対応する awaitId が `AwaitingLLMTransitions` に**存在しない**場合、 silent discard:
- Trace に `TransitionCallbackDiscarded` event を記録
- 戻り値 `<|"Status" -> "Discarded", "Reason" -> "NoSuchAwaiting"|>`

どちらの順序でも安全:
- timer 先発火 → callback 遅着 → silent discard
- callback 先着 → timer 後発火 → silent discard

## observability との組み合わせ

`ClaudeOrchestrator_observability.wl` v0.2.1 以降:

| 機能 | 挙動 |
|---|---|
| `iObsMakeHandlerWrapper` | AwaitingLLM Status を第一級として認識 |
| `traceTransitions[wid]` Dataset | Status カラムが "AwaitingLLM" 表示 |
| `$ObservedHandlerLog` | OutputStatus フィールドに "AwaitingLLM" 記録 |

instrument で包んでも Z 案動作は壊れない。

## よくある間違い

### NG: callback も timeout も仕掛けない
```mathematica
(* 永遠 AwaitingLLM 状態に陥る *)
Function[binding, <|"Status" -> "AwaitingLLM"|>]
```
最低でも transition か workflow に `AwaitingLLMTimeout` を入れるか、 handler 内で `SessionSubmit[ScheduledTask[...]]` を仕込む。

### NG: $ClaudeCurrentWid を callback 内で参照
```mathematica
(* callback は handler 外で評価される、 Missing が入る *)
ClaudeQueryAsyncSilent[prompt,
  "OnResponse" -> Function[response,
    ClaudeCompleteHandlerOutput[
      $ClaudeCurrentWid,    (* ← NG *)
      $ClaudeCurrentAwaitId,
      ...]]]
```
**OK: handler 内で局所変数に保存してから closure で渡す**:
```mathematica
With[{wid = $ClaudeCurrentWid, aid = $ClaudeCurrentAwaitId},
  ClaudeQueryAsyncSilent[prompt,
    "OnResponse" -> Function[response,
      ClaudeCompleteHandlerOutput[wid, aid, ...]]]];
```

### NG: Output に "Payload" ラップを忘れる
```mathematica
(* engine が payload キーを認識しない可能性 *)
ClaudeCompleteHandlerOutput[wid, aid, <|"echo" -> response|>]
```
**OK**:
```mathematica
ClaudeCompleteHandlerOutput[wid, aid, <|"Payload" -> <|"echo" -> response|>|>]
```

## デバッグの基本

| 確認したいこと | コマンド |
|---|---|
| 現在 awaiting 中の entry 一覧 | `ClaudeAwaitingTransitions[wid]` |
| 各 transition の Status | `traceTransitions[wid]` (observability) |
| 現在の token 配置 | `ClaudeOrchestrator\`Workflow\`Private\`$iWorkflowNets[wid][["Tokens"]]` |
| Trace event 履歴 | `ClaudeWorkflowTrace[wid]` |
| $iRestoreFallbackTimeout | `ClaudeOrchestrator\`Workflow\`Private\`$iRestoreFallbackTimeout` |

`AwaitingLLMTimeout` 機構で発火された Payload は `_timeout=True / _handler=tname` (timeout) または上記に `_restored=True` 追加 (Restore) のフラグで識別できる。 後段 transition は Lookup でこれらを検査して「LLM 応答失敗 vs 正常」を判別できる。

## 関連 skill

- `runtime-orchestrator-boundary`: WF レベル並列化と Runtime レベル並列化の責務境界
- `adapter-tool-flow-debugging`: adapter 経由 LLM call の問題診断
- `wolfram-general`: Wolfram トラップ一覧 (#11, #15, #16, #17, #18, #19 等)
