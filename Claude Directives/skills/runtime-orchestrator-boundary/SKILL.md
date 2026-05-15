---
name: runtime-orchestrator-boundary
description: ClaudeRuntime と ClaudeOrchestrator の責務境界、特に並列化の許容範囲を判定する。Use when adding new functionality to either ClaudeRuntime or ClaudeOrchestrator, especially involving parallelism, retry, approval, worker spawning, or workflow state. Workflow Migration プロジェクト (stategraph → ClaudeOrchestrator`Workflow` 吸収) の Stage A〜C を進める間は常時参照。
---

# Runtime / Orchestrator boundary

## 主軸の問い

> **その機能が扱う state は、ターンを跨いで残るか?**

- 残らない → **ClaudeRuntime** (DAG-internal parallelism, DAG-IP)
- 残る → **ClaudeOrchestrator** (Workflow-level parallelism, WF-LP)

これは hard 判定基準。判断に迷ったら Orchestrator 側に倒す。

## なぜこの境界が必要か

`ClaudeRuntime_stategraph.wl` が Runtime 拡張として育っていたが、実体は workflow engine (multi-token / Petri net) であり、Runtime ではなく Orchestrator の領分。Phase 31 で「並列 worker に live notebook 書込みをさせて壊れた」事例があり、その再発を防ぐためにも境界を明確にする必要がある。

詳細は `Workflow_Migration_ABC_Spec.md` および `ClaudeOrchestrator_Runtime_StateGraph_Integration_Spec.md` を参照。

## 判定表

| パターン | 担当層 | 理由 |
|---|---|---|
| 1 turn 内で複数 web_search を並列発火 (Phase 32k Step 3 AsyncToolExec で実装済み) | Runtime (DAG-IP) | turn を跨がない。`iToolUseAndContinue` hybrid 経路 + `iScheduleAsyncToolExecPoll` で別 OS プロセス並列実行 |
| ParseProposal で複数 expression を独立解析 | Runtime (DAG-IP) | turn を跨がない |
| context assembly での並列ファイル読み込み | Runtime (DAG-IP) | 純関数的、turn を跨がない |
| 複数 sub-prompt を並列に出して map-reduce | Runtime (DAG-IP) | turn 内で閉じる |
| 複数 worker をスポーンして長時間 LLM を回す | Orchestrator (WF-LP) | turn を跨ぐ、approval が絡みうる |
| Worker pool 管理 | Orchestrator (WF-LP) | スケジューリングが本質 |
| Retry / Repair ループ | Orchestrator (WF-LP) | 状態が永続化される必要がある |
| Approval 待ち | Orchestrator (WF-LP) | place の滞留として表現される |
| Pause / Resume | Orchestrator (WF-LP) | snapshot/restore が一級扱い |
| Notebook commit ordering | Orchestrator (WF-LP) | single committer 原則 |
| Package update transaction | Orchestrator (WF-LP) | 多段の transition が必要 |

## ClaudeRuntime に入れていいもの

- BuildContext (複数ソースからの並列読み取り)
- QueryProvider (プロバイダ呼び出しは sequential、ただし同一 turn 内の複数 prompt は parallel map 可)
- ParseProposal / ValidateProposal (純関数的並列化)
- DispatchDecision
- ExecuteProposal (副作用が turn 内で完結する場合のみ)
- RedactResult / NormalizeResult
- 1 turn 内の tool call の並列発火 (= AsyncToolExec、Phase 32k Step 3 で実装) — `iToolUseAndContinue` hybrid 経路 + `iScheduleAsyncToolExecPoll`。詳細は skill `async-tool-execution`

## ClaudeRuntime に入れてはいけないもの

- 複数 worker のスポーン
- approval wait
- retry policy の所有
- workflow snapshot / restore
- notebook commit 順序の管理
- multi-turn の状態維持
- Package transaction の所有

## ClaudeOrchestrator (および ClaudeOrchestrator`Workflow`) に入れていいもの

- WorkflowNet / Place / Transition / Token の管理
- worker token の発行と回収
- transition firing 条件の判定
- approval token / artifact token / package transaction token の管理
- retry / repair / pause / resume
- snapshot / restore
- single committer の起動と target notebook 束縛

## ClaudeOrchestrator に入れてはいけないもの

- 1 turn 内の純関数的計算
- prompt 構築の細部
- LLM provider 呼び出しの低レベル詳細
- ParseProposal / ValidateProposal の実装
- DAG-internal な並列 map

## Code review checklist

新規 PR / 変更で以下のいずれかに該当する場合、本 skill を再確認すること。

- [ ] 新しい並列化を導入する
- [ ] state を Module / DynamicModule で長時間保持する
- [ ] notebook への書き込みを行う
- [ ] retry / approval / pause / resume の仕組みを追加する
- [ ] tool call を非同期で行う
- [ ] worker, agent, runtime, transition, place, token などの語彙を追加する

確認項目:

1. 追加する state はターンを跨いで残るか?
2. 残るならば、それは Orchestrator に置かれているか?
3. 残らないならば、それは Runtime の DAG-IP として表現されているか?
4. notebook 書き込みを行うなら、それは single committer transition か?
5. 並列化を行うなら、それは独立な純関数の map か?

## 違反例 (Phase 31 の教訓)

以下は過去に実際に起きた **反例** である。

- 並列 worker に live notebook 書き込みを期待した → `EvaluationNotebook[]` が現在の notebook を安定に指さなかった
- worker 間で Mathematica 変数を共有しようとした → CLI サブプロセスでは共有できなかった
- 自然言語サマリだけで先行サブターン結果を次に渡した → 依存解決に失敗
- `<tool_call>` タグと Mathematica proposal を一つの runtime で混線させた → どちらも壊れた

これらは全て **「workflow state を Runtime に持たせた」結果** である。本 skill はこの再発を防ぐためにある。

## ClaudeRuntimeExecuteTransition による境界の実装的検証 (Stage B Day 4c)

Stage B Week 1 Day 4c で `ClaudeRuntime`ClaudeRuntimeExecuteTransition[adapter, contextPacket]` を新設し、Workflow の Transition (Executor=`"ClaudeRuntime"`) の実行点として組み込んだ。本 skill の境界判定をコード側で強制する設計になっている。

### adapter の signature

```mathematica
adapter = <|
  "BuildContext"     -> Function[{ctxPacket}, ctx],
  "QueryProvider"    -> Function[{ctx, ctxPacket}, proposal],
  "ValidateProposal" -> Function[{proposal, ctxPacket},
                          True | False | <|"Valid" -> Bool, ...|>],
  "ExecuteProposal"  -> Function[{proposal, ctxPacket}, execResult],
  "RedactResult"     -> Function[{execResult, ctxPacket}, redacted]
|>
```

`ClaudeRunTurn` 系の adapter とほぼ同じだが、**`ShouldContinue` を意図的に除外している**。multi-turn ループは Workflow 側の transition 連鎖でしか表現できなくする (= Orchestrator に強制) のがこの除外の目的。

### context packet の伝播経路

Workflow 側の `iBuildContextPacket[trans, binding]` が以下を集約して context packet を組み立て、adapter に渡す:

```mathematica
<|"TransitionName"      -> trans["Name"],
  "Binding"              -> binding,
  "InputTokens"          -> iFlattenBinding[binding],
  "Role"                 -> Lookup[accessPolicy, "Role"],
  "DirectiveBundle"      -> Lookup[accessPolicy, "DirectiveBundle"],
  "DirectivePrompt"      -> Lookup[accessPolicy, "DirectivePrompt"],
  "AllowedCapabilities"  -> Lookup[accessPolicy, "AllowedCapabilities"],
  "OutputSchema"         -> Lookup[runtimeSpec, "OutputSchema"],
  "Model"                -> Lookup[runtimeSpec, "Model"]|>
```

DirectiveBundle や AllowedCapabilities など、本来 Orchestrator が管理する情報が adapter に届く形にしている (Runtime 側は使うだけで保持しない)。

### この API が境界を強制する仕組み

| 機能 | adapter signature 上の扱い | 境界の効果 |
|---|---|---|
| 1 turn 内の純関数計算 | `BuildContext` 〜 `RedactResult` の 5 stage に集約 | Runtime に閉じ込め可能 |
| multi-turn loop / continuation | adapter 上に存在しない | Workflow の transition 連鎖で表現する以外ない |
| retry policy | adapter 上に存在しない | Workflow が transition 単位で retry する |
| approval | adapter 上に存在しない | place 滞留として表現される |
| commit ordering | adapter 上に存在しない | single committer transition が担う |

### Stage 失敗の戻り値構造

```mathematica
<|"Status" -> "Failed",
  "Reason" -> "...",
  "Stage"  -> "BuildContext" | "QueryProvider" | "ValidateProposal" |
              "ExecuteProposal" | "RedactResult",
  ... (Stage に応じた付加情報)|>
```

各 stage は `Quiet @ Check[...]` で例外捕捉し、`<|"OK" -> False, "Reason" -> "ExceptionInStage: ..."|>` の形に正規化してから上に伝播する。これにより adapter 内の予期せぬ例外が Workflow 全体を壊さない。

### ValidateProposal の戻り値の正規化

Validate は 3 形式 (`True` / `False` / `<|"Valid" -> Bool, ...|>`) を許容する `iValidationOK` で統一判定する:

```mathematica
iValidationOK[r_] := Which[
  r === True,                  True,
  r === False,                 False,
  AssociationQ[r],             TrueQ[Lookup[r, "Valid", False]],
  True,                        False
]
```

「Valid なら ExecuteProposal、不正なら短絡 fail」のセマンティクスを統一。

### 関連

- Stage B Day 4c の進捗ノート (Day4c_progress_notes.md)
- Workflow_Migration_StageB_Design_Notes.md §7 (Directives 連携)
- ClaudeRuntime.wl の usage 文 (`ClaudeRuntimeExecuteTransition::usage`)
- ClaudeOrchestrator_workflow.wl の `iExecuteClaudeRuntimeBranch`

## 例外

明確な例外はない。ただし以下は「境界をまたぐ補助層」として両方から利用される:

- `NBAccess` (hard safety、両方から呼ばれる)
- `LLMGraph` (永続化基盤、両方からアクセス)
- `claudecode_base` (低レベルユーティリティ)

これらは Runtime / Orchestrator どちらにも属さない supporting layer。

## 関連

- `Workflow_Migration_ABC_Spec.md` § 8 (境界判定の根拠)
- `ClaudeOrchestrator_Runtime_StateGraph_Integration_Spec.md` §3 (DAG / Petri net 役割分担)
- `claude_multi_agent_orchestration_spec.md` §5 (worker / committer の責務)
- skills/association-mutation-patterns (Workflow engine 実装中に踏みやすい Mathematica 固有の罠)
- skills/async-tool-execution (DAG-IP の具体例: 1 turn 内 tool 並列発火の実装)
- rules/100-async-tool-execution (AsyncToolExec の必須ルール)

## 寿命について

本 skill は Workflow Migration Stage C 完了 (stategraph deprecated 化) まで always-on。Stage C 後は内容の大半が「ClaudeOrchestrator`Workflow` の自然な構造」として組み込まれるため、skill としての価値は減る。その時点で削除または「歴史的記録」として `archived/` 等に移すことを検討する。
