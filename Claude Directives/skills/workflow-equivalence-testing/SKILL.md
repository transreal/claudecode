---
name: workflow-equivalence-testing
description: ClaudeOrchestrator`Workflow`Diff` (動作差分 harness) を使って shim 経路と元 stategraph 実装の意味的等価性を検証するパターン。Mode-agnostic と Mode-aware なテストの区別、ReplayTestFile による既存テストの両モード比較、結果分類 (BothPass / OnlyOff / OnlyOn / BothFail) を扱う。Use when migrating stategraph tests to verify shim equivalence (Stage B Week 2c-4 onward), debugging mode-specific test failures, or designing new tests that should work under both $UseWorkflowShim = True and False.
---

# Workflow 等価性テスト (両モード比較)

`ClaudeOrchestrator_workflow_diff_harness.wl` (Stage B Week 2c-4 prelude で実装) で、shim 経路 (`$UseWorkflowShim = True`) と元 stategraph 実装 (`$UseWorkflowShim = False`) の動作等価性を検証するパターン。本 skill は harness の使い方と、テストファイルの分類 (Mode-agnostic vs Mode-aware) を扱う。

## Public API 一覧

```mathematica
ClaudeOrchestrator`Workflow`Diff`ClaudeStateGraphDiffHarness[graph, opts]
  → graph を Mode OFF/ON で実行 (RunStateGraph sync ベース)、runtime state 比較
  → 戻り値: <|"Mode_OFF", "Mode_ON", "Diffs", "Equivalent"|>

ClaudeStateGraphReplay[heldExpr]            (HoldFirst)
  → 任意の式を Mode OFF/ON で 2 回評価して結果比較
  → 戻り値: <|"OFF", "ON", "Equal", "OFF_OK", "ON_OK"|>

ClaudeStateGraphReplayVerificationTest[args]   (HoldAll)
  → VerificationTest を Mode OFF/ON で評価し Outcome 比較
  → 戻り値: <|"Outcome_OFF", "Outcome_ON", "BothPass", "OnlyOff", "OnlyOn", "BothFail", "DiffMode", ...|>

ClaudeStateGraphReplayTestFile[path, opts]
  → テストファイルを Mode OFF/ON で 2 回 Get、結果蓄積変数を比較
  → 戻り値: <|"OFF", "ON", "Comparison", "BothPassCount", "OnlyOffCount", ...|>

ClaudeStateGraphFormatDiffReport[result]
ClaudeStateGraphReplayTestFileFormat[result]
  → 結果整形 Print (chain 用に元 result を返す)
```

## Mode-agnostic vs Mode-aware の区別

ReplayTestFile に流せるかどうかの判定基準:

### Mode-agnostic なテスト (ReplayTestFile に適している)

- 内部で `iSetShimMode` を呼ばない
- 外側の `$UseWorkflowShim` 設定に従って動く
- 例: `test_workflow.wl`, `test_workflow_shim.wl`, `test_workflow_shim_snapshot.wl`、典型的な既存 stategraph テスト
- ReplayTestFile に流すと「両モードで pass = shim と元実装が意味的に等価」という強い保証になる ← **Week 2c-4 の主目的**

### Mode-aware なテスト (ReplayTestFile に適さない)

- 各テスト内部で `iSetShimMode[True/False]` を切り替え、Mode の効果を直接検証
- 例: `test_workflow_shim_dispatcher.wl`、`test_workflow_shim_diff.wl`
- ReplayTestFile に流しても外側の Mode 設定は無意味で、2 回実行する分テスト件数が倍になるだけ
- timing dependent な失敗 (registry 混雑時など) も発生しうる
- **これらは単独実行 (Get) で十分**

## ReplayTestFile の運用パターン (Week 2c-4 本番想定)

### 1. テストファイル冒頭で結果格納変数名を確認

```mathematica
(* テストファイルの冒頭にある典型的なパターン *)
If[!ListQ[$shimTestResults], $shimTestResults = {}];
iAddTest[result_] := AppendTo[$shimTestResults, result];

(* このファイルなら ResultsVar -> "$shimTestResults" *)
```

### 2. ReplayTestFile を実行

```mathematica
report = ClaudeOrchestrator`Workflow`Diff`ClaudeStateGraphReplayTestFile[
  "F:\\path\\to\\existing_tests.wl",
  "ResultsVar"  -> "$shimTestResults",
  "ClearBefore" -> True
];
```

### 3. Format で可視化

```mathematica
ClaudeOrchestrator`Workflow`Diff`ClaudeStateGraphReplayTestFileFormat[report];
(*
  ─── ClaudeStateGraphReplayTestFile Report ───
    Total      : 111
    Both pass  : 105
    Only OFF   : 6  (shim 側補強候補)     ← 重要、Week 2c-4 で対応
    Only ON    : 0  (元実装 bug 候補?)
    Both fail  : 0
*)
```

### 4. shim 側補強候補を抽出

```mathematica
shouldFix = Select[report[["Comparison"]], TrueQ[#[["OnlyOff"]]] &];
(* 各 TestID を手がかりに shim 側 semantic を補強 *)
```

## 結果分類の意味

| 分類 | 条件 | 解釈 |
|---|---|---|
| `BothPass` | OFF=Success, ON=Success | shim と元実装が等価 (ゴール) |
| `OnlyOff` | OFF=Success, ON=Fail | **shim 側の補強が必要** |
| `OnlyOn` | OFF=Fail, ON=Success | 元実装の隠れた bug を新発見した可能性 |
| `BothFail` | OFF=Fail, ON=Fail | テスト自体の問題、graph 設計問題、または両モード共通の bug |

`OnlyOff` を最小化するのが Week 2c-4 のゴール。

## DiffHarness の重要な設計判断 (Stage B Week 2c-4 prelude で確定)

### RunStateGraph (sync) ベースで実装する

`LLMStateGraphCreate` 直接呼びだと Mode ON (shim 経由) で `ClaudeRunWorkflow` が呼ばれず、polling 寄生だけで実行されるため、registry 混雑時に timeout する。`RunStateGraph["Async" -> False]` なら両モードで graph 完了が保証される。

詳細は `workflow-shim-forwarding-design` skill の「shim Create は ClaudeRunWorkflow を呼ばない」セクションを参照。

### 比較対象フィールド (iCompareRuntimes)

- `Status.Status` (Done / Failed / Cancelled / ...)
- `State.Path.Length` と `State.Path.Contents`
- `State.Stages.Keys`, `State.Stages.Type`
- `State.Accumulator.Keys`
- `Trace.Length`, `Trace.Types.Sequence`

## 副作用と Hold attribute

- `ClaudeStateGraphReplay` は **HoldFirst** で式を 2 回評価する
- 副作用を持つ式 (snapshot 作成、Print、registry への登録等) は 2 回起こる
- **graph 実行をテストしたいなら DiffHarness を使うべき** (Replay は単純な式の機構テスト用)

## TestResultObject の扱い (罠 #10)

ReplayTestFile 内部で TestResultObject から TestID を取り出す際は indexed access (`r["TestID"]`) を使う。`Lookup[r, "TestID"]` は機能しない (常に default を返す)。詳細は `wolfram-syntax-pitfalls` §4.7 を参照。

## 関連

- `workflow-shim-forwarding-design` (shim 設計、Create が ClaudeRunWorkflow を呼ばない仕様)
- `workflow-shim-prefix-scheme` (命名規則)
- `wolfram-syntax-pitfalls` §4.6〜§4.8 (`UnsameQ` 演算子、`TestResultObject` Lookup、Unicode エスケープ)
- `runtime-orchestrator-boundary` (Workflow / Runtime 境界)
- Week 2c-4 prelude 進捗ノート

## 寿命

Stage B Week 2c-4 本番 (既存 111 件テスト統合) と Stage C 開始まで主要レファレンス。Stage C で `$UseWorkflowShim = True` がデフォルトになると、両モード比較の必要性は低下し、本 skill は履歴的記録に縮退する。
