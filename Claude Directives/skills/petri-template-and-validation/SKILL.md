---
name: petri-template-and-validation
description: 自由文プロンプトから LLM が直接 Petri net を生成する現方式を、テンプレートベース生成 + 検証ノード入りメタワークフローに置き換える長期設計提案。proposePetriNet 自体を Petri net で表現し、validation / fault-injection simulation / approval を transition として組み込む構想。Imai 先生の構想記録 (引き継ぎ事項)。
---

# Petri net 生成のテンプレート化 + メタワークフロー化 (設計提案)

本 skill は **未実装の長期設計提案** を記録する引き継ぎ書類。Imai 先生
(Stage B Migration 進行中) の構想を skill として保存することで、後続
セッションが当時の議論を再構築せずに着手できるようにする。

## 動機

現状の `proposePetriNet` は LLM (Claude Opus 等) に自由文プロンプトと
$petriNetGuide を渡して、生の Mathematica WorkflowNet コードを書かせる
方式。これは以下の問題を抱える:

1. **生成 net の構造的バグが頻発する**
   - retry を Merge 下流に置く (`petri-retry-patterns` skill 参照)
   - AND/XOR-merge を取り違える (`petri-and-xor-merge` skill 参照)
   - Trial counter 不足の無限ループ (現静的検査で検出される類)
   - モデル名を勝手に書き換える (`petri-multi-provider-generation` 参照)

2. **静的検査リトライでも直らない**
   review.nb の例: 静的検査が "INFINITE LOOP RISK" を 4 回連続検出
   したが、LLM は 4 回とも同じパターンを再生成して直せず。検出ルールが
   ある問題ですら、生成 LLM は構造的に逸脱したパターンを書き続ける。

3. **検証と実行が分離していない**
   生成 → 検証 → 実行が個別関数の連結で、各段階のデータフローが
   ad-hoc。失敗パスでの再生成 / 人間 approval / fallback がコード中に
   分散している。

## 設計提案: メタワークフロー化

`proposePetriNet` 自体を Petri net で表現する (self-hosting)。

### メタワークフローの構造案

```
[UserPrompt token]
       ↓
[ParseIntent transition]
   出力: <|"Intent" -> "fan-out-review", "Reviewers" -> {...},
           "RetryPolicy" -> {...}, "MergePolicy" -> "AND"|>
       ↓
[ParsedIntent place]
       ↓
[SelectTemplate transition]   (* テンプレート集から最適な雛形を選択 *)
       ↓
[TemplateBound place]
       ↓
[InstantiateTemplate transition]  (* パラメータ埋め: reviewer 名, 各 model, 各プロンプト *)
       ↓
[DraftNet place]
       ↓
[ValidateStatic transition]   (* 静的検査: AND/XOR、Trial カウンタ、孤立 place 等 *)
       ↓
   (OK ↓)                         (NG → [DraftRevise place] → ErrorReport)
[StaticValidatedNet place]
       ↓
[SimulateFaults transition]   (* fault-injection 動的検査 *)
   入力: net + 失敗シナリオ集 ({worker fail, merge fail, 全 worker fail, ...})
   出力: 各シナリオでの net 終端状態 (Done / Stuck / 想定外 deadlock)
       ↓
   (全シナリオ OK ↓)              (想定外 → [SimRevise] → 再生成 / 人間 approval)
[SimulationPassedNet place]
       ↓
[ApprovalGate transition]    (* 自動 / 人間 (sample.nb の Approve/Cancel) *)
       ↓
[ApprovedNet place]
       ↓
[Instantiate transition]      (* ClaudeCreateWorkflowNet[net] *)
       ↓
[RunnableWid place]
```

各 transition は WorkflowTransition として実装。LLM 呼び出し
(ParseIntent / SelectTemplate / RegenerateNet 等) は ClaudeRuntime
経由で行い、retry policy / approval は外側の Workflow が担う
(runtime-orchestrator-boundary 準拠)。

## テンプレート集の構造

`$packageDirectory/petri_templates/` 等に分類して配置:

```
petri_templates/
  fan-out-review/
    SPEC.md                   # 適用条件、パラメータ仕様
    template.wl               # WorkflowNet を返す関数 (パラメータ受け取り)
    test_cases.wl             # テンプレート単体テスト
  pipeline-with-validation/
    ...
  ensemble-with-voting/
    ...
  retrieval-augmented/
    ...
  multi-step-reasoning/
    ...
```

各テンプレートは **検証済みの正しい構造** を持つ。LLM の役目は

1. ユーザのプロンプトから intent を抽出
2. テンプレート集から適合パターンを選ぶ
3. パラメータ (reviewer 名、model 名、prompt 文等) を埋める

の 3 つに限定される。**net の構造そのものは LLM が書かない。**

## 検証関数の設計

### 静的検査 (ValidateStatic transition)

入力: WorkflowNet Association
出力: <|"Valid" -> True/False, "Errors" -> {...}, "Warnings" -> {...}|>

検査項目 (Petri net 理論ベース):

| 検査 | 種別 | 既存 |
|---|---|---|
| 全 Place が transition から到達可能 (= reachability) | 構造 | 一部 |
| 全 Place から Final まで到達可能 (= proper termination) | 構造 | 不在 |
| Deadlock-free (= liveness) | 構造 | 不在 |
| AND-merge transition の InputArc 構成が適切 (Place 個別 or Multiplicity>1) | パターン | 不在 |
| Retry loop に Trial counter Guard があるか + GiveUp が対応しているか | パターン | 部分的 |
| Worker transition に LLM 呼び出しがある場合 RetryPolicy または Trial 制御 | パターン | 不在 |
| Place 名 / Transition 名の規約 (e.g. Source, Done) | 命名 | 部分的 |

Soundness 検査 (van der Aalst の WF-net soundness) は標準アルゴリズムが
あり、Mathematica の Graph 機能 + 到達可能性解析で実装可能。

### 動的検査 (SimulateFaults transition)

入力: 検証済み net + 失敗シナリオ集 (デフォルト 8〜10 個)

各シナリオを **実 LLM を呼ばず** に sandbox 実行:

```
シナリオ例:
  - "WorkerOpus 1 回 fail、それ以外 OK"  → 期待: WorkerOpus retry → 成功 → Done
  - "WorkerOpus 全 retry fail"           → 期待: 該当 transition が enabled 終了 → Stuck
  - "WorkerChatGPT 全 retry fail"        → 期待: 同上
  - "両 Worker fail"                     → 期待: Stuck (peer review 不完全)
  - "Merge handler fail"                 → 期待: retry → 成功 or Stuck
  - "正常パス (全成功)"                  → 期待: Done with FinalResult
```

各 handler を fault-injection 用の stub に差し替えて
`ClaudeRunWorkflow` を実行、最終 marking と Trace を期待値と比較。

実装ポイント:
- handler を `Function[binding, faultStub[scenarioName, transitionName, binding]]`
  のように包む
- `iExecutePureFunction` 自身は変更不要
- LLM 呼び出しは一切しないので高速

### Soundness の参考実装スケッチ

```mathematica
iCheckWorkflowSoundness[net_Association] :=
  Module[{g, transitions, places, source, finals,
          reachableFromSource, canReachFinal, deadlockedStates},
    g = iWorkflowAsGraph[net];
    source = net[["SourcePlace"]];
    finals = net[["FinalPlaces"]];

    (* 1. すべての node が source から到達可能 *)
    reachableFromSource = VertexOutComponent[g, source];
    unreachable = Complement[VertexList[g], reachableFromSource];

    (* 2. すべての node から final までの path がある *)
    canReachFinal = AssociationMap[
      AnyTrue[finals, FindPath[g, #, ##2, Infinity, 1] =!= {} &] &,
      VertexList[g]];
    unproductive = Keys[Select[canReachFinal, !# &]];

    (* 3. 既存の trace を使った reachability 列挙
       小規模 net (< 50 place + token < 10) は完全展開が現実的 *)
    deadlockedStates = iEnumerateDeadlocks[net];

    <|"Sound" -> (unreachable === {} && unproductive === {} &&
                  deadlockedStates === {}),
      "UnreachableNodes" -> unreachable,
      "UnproductiveNodes" -> unproductive,
      "DeadlockedStates" -> deadlockedStates|>
  ];
```

`iEnumerateDeadlocks` は Petri net の到達可能集合 (reachability set) を
BFS で列挙し、各状態で enabled な transition 集合を計算、空かつ
final place に token が無い状態を集める。

## 利点 (移行後)

1. 構造的バグの大部分がテンプレート設計時に潰される
2. LLM の役目がパラメータ埋めに限定されるため、生成失敗率が劇的に下がる
3. 検証と実行が同じ Petri net 上のフローとして見える (= 観測可能)
4. テンプレートの追加 / 改善が既存テンプレートに影響しない (modular)
5. `petri-retry-patterns` / `petri-and-xor-merge` 等の skill が
   テンプレート設計の一次資料になり、保守の単一情報源化が進む

## 段階的移行プラン

Stage 1 (rules/02 準拠の skill 整備) — **完了済み**
- `petri-multi-provider-generation` (Provider/Model)
- `petri-and-xor-merge` (AND/XOR)
- `petri-retry-patterns` (per-worker retry)
- `petri-template-and-validation` (本 skill, 設計記録)

Stage 2 (検証関数の単独実装)
- `iCheckWorkflowSoundness` を `ClaudeOrchestrator_workflow.wl` の検証
  ヘルパとして追加
- `proposePetriNet` の出力に対して呼び出し、警告を表示 (現静的検査の置換)

Stage 3 (fault-injection sim の単独実装)
- `simulatePetriNet[net, scenarios]` を新設
- handler stub 機構 + `ClaudeRunWorkflow` 経由

Stage 4 (テンプレート集の整備)
- 5〜10 個の主要テンプレートを `petri_templates/` に配置
- 各テンプレート用の `test_cases.wl` (sim ベース)

Stage 5 (メタワークフロー化)
- `proposePetriNet` を Petri net 表現に書き直す
- ParseIntent → SelectTemplate → InstantiateTemplate →
  ValidateStatic → SimulateFaults → ApprovalGate → Instantiate

Stage 6 (汎用知識データベース化, CLAUDE.md の引き継ぎ事項)
- テンプレートおよび検証 skill を、petri に限らない汎用「workflow
  pattern catalog」として再構成
- 他の DAG / pipeline 系 (LLMGraph, Stage B Workflow Migration) と
  共通の検証基盤に集約

各 Stage は独立に着手・延期可能。Stage 2 から先は Workflow Migration
Stage C 完了後の着手が安全。

## 関連 skill / rule

- `rules/02-llm-instructions-not-in-source.md` — テンプレートと skill
  の境界を維持する
- `skills/runtime-orchestrator-boundary` — Validation / Simulation も
  Orchestrator 側 (turn-を跨ぐ state) として実装する
- `skills/petri-retry-patterns` — 本 skill の Stage 1 成果物の 1 つ
- `skills/petri-and-xor-merge` — 同上
- `skills/petri-multi-provider-generation` — 同上

## 寿命

本 skill は Stage 5 完了まで always-on の引き継ぎ書類。Stage 5 後は
"歴史的経緯" として archived/ に移動を検討。
