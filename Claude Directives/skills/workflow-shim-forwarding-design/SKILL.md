---
name: workflow-shim-forwarding-design
description: ClaudeOrchestrator`Workflow`Shim` で旧 LLMStateGraph* API を WorkflowNet 経由に forwarding するときの設計パターン (mapping registry、Stages[nodeId][Output] 二重格納、Trace event 変換、Create の 2 ステップ化)。Use when extending or maintaining the Shim* forwarding APIs (Create, Status, State, Cancel, List, Trace, RecordHistory, RunStateGraph), especially for Snapshot integration or new API additions in Stage B Week 2c-2 onwards.
---

# Workflow shim forwarding 設計

`ClaudeOrchestrator_workflow_shim.wl` (Stage B Week 2c-2 以降) で旧 LLMStateGraph* API と等価な動作を WorkflowNet 経由で実現するための設計パターン。本 skill は `workflow-shim-prefix-scheme` (命名規則) と相補的で、こちらは「forwarding 戦略」を扱う。

## 主要な設計判断

### 1. mapping registry で Private symbol 直接依存を回避

XSM の `runtimeId` (`sg-...`) と Workflow の `wid` (`wf-...`) を双方向に対応付ける registry を shim 内に持つ。さらに、Trace 変換などで必要な元情報も別 registry で保持し、`ClaudeOrchestrator`Workflow`Private`$iWorkflowNets` への直接アクセスを避ける。

```mathematica
$iSGRidWidMap   = <||>;   (* sgRid -> wid *)
$iWidSGRidMap   = <||>;   (* wid -> sgRid *)
$iSGRidGraphMap = <||>;   (* sgRid -> 元の XSM graph *)
$iSGRidOptsMap  = <||>;   (* sgRid -> opts (InitialContext / MaxTotalIterations) *)
$iSGRidWfMap    = <||>;   (* sgRid -> 生成時の WorkflowNet 構造 *)
```

`$iSGRidWfMap` は特に重要:
- Trace 変換時に `wf[["Transitions"]][transName][["RuntimeSpec"]]` を引いて NodeId / NodeType を解決
- Status 計算や Snapshot で wf 全体が必要なときに使える
- `$iWorkflowNets` (workflow.wl の Private symbol) への依存を回避

### 2. Create の 2 ステップ化(wf 捕捉のため)

```mathematica
(* NG: 一括だと wf を捕捉できない *)
wid = ClaudeCreateWorkflowFromStateGraph[graph];

(* OK: 2 ステップで分離 *)
wf  = ClaudeWorkflowFromStateGraph[graph];                                   (* 構造捕捉 *)
wid = ClaudeOrchestrator`Workflow`ClaudeCreateWorkflowNet[wf];               (* 登録 *)
$iSGRidWfMap = Append[$iSGRidWfMap, sgRid -> wf];                            (* 保存 *)
```

`ClaudeCreateWorkflowFromStateGraph` 自体は維持(他の用途のため)。Shim の Create だけが 2 ステップに分離する。

### 3. Stages[nodeId][Output] 二重格納

Stage / Compute / Decision Node の handler で、shim native の直接 merge と並立する形で `Stages[nodeId][Output]` 形式にも格納する:

```mathematica
iMakeNodeHandler[nodeId_String, handler_, type_String, prefix_String:""] :=
  Function[binding,
    Module[{inToken, gs, newGS, mergedGS, output, stages, newStages, ...},
      ...
      (* 1. shim native: GlobalState に直接 merge *)
      mergedGS = If[AssociationQ[newGS], Join[gs, newGS], gs];
      
      (* 2. stategraph 互換: Stages[nodeId][Output] にも格納 *)
      output    = If[AssociationQ[newGS], newGS, <||>];
      stages    = Lookup[mergedGS, "Stages", <||>];
      newStages = Append[stages, nodeId -> <|
        "Output"  -> output,
        "EndTime" -> AbsoluteTime[]
      |>];
      mergedGS  = Append[mergedGS, "Stages" -> newStages];
      ...
    ]
  ];
```

これにより:
- 新規コードは `gs[["computed"]]` のような直接アクセスで書ける
- 既存 stategraph 互換コードは `gs[["Stages", "V27", "Output", "computed"]]` で同じ値が取れる
- 両方の慣習が両立し、既存テストを壊さずに forwarding 経路を提供できる

トレードオフ: token Payload サイズが少し大きくなるが、Snapshot サイズへの影響は微小。

### 4. Trace event 変換マトリクス

Workflow trace の `"Event"` / `"Timestamp"` 形式を XSM trace の `"Type"` / `"Time"` 形式に変換する。`TransitionFired` event は transition の `RuntimeSpec[NodeType]` を引いて種類別に分岐:

| workflow event | nodeType | XSM event Type |
|---|---|---|
| `TransitionFired` | `Stage` / `Compute` | `NodeProcessed` |
| `TransitionFired` | `Decision` | `DecisionMade` |
| `TransitionFired` | `ParallelSubgraph-split` | `ParallelStarted` |
| `TransitionFired` | `ParallelSubgraph-join` | `ParallelJoined` |
| `TransitionFired` | (空、Edge transition) | `EdgeFired` |
| `TokenSubmitted` | — | `TokenSubmitted` |
| `WorkflowPaused` | — | `Paused` |
| `WorkflowResumed` | — | `Resumed` |
| `WorkflowCancelled` | — | `Cancelled` (PreviousStatus 含む) |

各 XSM event には `NodeId` / `NodeType` / `TransitionName` を含めて、stategraph 経路と workflow 経路の両方の identifier を保持する。

#### GraphCreated event の prepend

LLMStateGraphCreate の慣習では trace の先頭に `GraphCreated` event がある。workflow trace にはこれに相当するものがないので、shim 側で prepend する:

```mathematica
iExtractTrace[sgRid_String] :=
  Module[{wfTrace, sgTrace, firstTime, ...},
    wfTrace = ClaudeWorkflowTrace[wid];
    sgTrace = Map[iWorkflowEventToSGTraceEvent[#, transitions]&, wfTrace];
    
    firstTime = If[Length[wfTrace] > 0,
                   Lookup[First[wfTrace], "Timestamp", 0], 0];
    Prepend[sgTrace, <|
      "Type"        -> "GraphCreated",
      "Time"        -> firstTime,
      "InitialNode" -> Lookup[graph, "InitialNode", "?"]
    |>]
  ];
```

### 5. Status の workflow native 拡張キー

`iExtractStatus[sgRid]` の戻り値は LLMStateGraphStatus 互換の 11 キー (`RuntimeId`, `Status`, `CurrentNode`, ...) **に加えて** `WorkflowId` / `WorkflowStatus` の 2 キーを含める。これにより:

- 既存 stategraph 互換コードは 11 キーで動く
- forwarding 経路の debug や workflow native 操作には 2 キー追加情報を使える

### 6. CurrentNode の逆算ロジック

XSM の単一 `CurrentNode` を WorkflowNet の multi-token 状態から逆算するため、**sentinel token の Payload.Path の最後**を採用:

```mathematica
iCurrentNodeFromState[wid, graph] :=
  Module[{state, sentinelTokens, lastToken, path, ...},
    state = ClaudeWorkflowState[wid];
    sentinelTokens = Select[Values[state[["Tokens"]]],
      Lookup[#, "Kind", ""] === "XSMSentinel" &];
    
    If[Length[sentinelTokens] === 0,
      Return[graph["InitialNode"]]];
    
    lastToken = First @ SortBy[sentinelTokens, -Lookup[#, "CreatedAt", 0] &];
    path = Lookup[lastToken[["Payload"]], "Path", {}];
    
    If[Length[path] === 0, graph["InitialNode"], Last[path]]
  ];
```

Path は handler で append されるので、最後の要素 = 直近通過した nodeId。Path が空 = まだ何も fire していない (Submit 直後) = `graph["InitialNode"]`。

## Public API のテンプレート

各 forwarding API は概ね以下の構造を取る:

```mathematica
ShimLLMStateGraphXxx[sgRid_String, ...] :=
  Module[{wid, ...},
    wid = iSGRidToWid[sgRid];
    If[wid === $Failed, Return[Missing["RuntimeNotFound", sgRid]]];
    
    ... wid を使って ClaudeOrchestrator`Workflow` の API を呼ぶ ...
    ... 戻り値を stategraph 形式に変換する ...
  ];
```

3 つのバリエーション:

1. **薄いラッパー** (Cancel / List): wid に変換して workflow API を呼ぶだけ
2. **状態抽出** (Status / State): workflow state から stategraph 形式の Association を組み立てる
3. **形式変換** (Trace): event リストを stategraph 形式にマッピング

`RecordHistory` は LLMGraph 統合が必要なため Stage C 以降での本実装に温存し、Week 2c-2b ではスケルトン (status/state/trace を集約した Association を返す) としている。

## 既存テストへの影響範囲

shim 内で完結する設計のため、既存 stategraph.wl への影響を Week 2c-2d まで遮断できる:

- Week 2c-1 / 2c-2a / 2c-2b は shim とテストファイルだけ変更
- 既存 `Stage E (36) + Stage B (35) + Stage C (40) = 111 件テスト` は無変更
- Week 2c-2d で stategraph.wl の Public API 内部を Shim 系への forwarding に切替時に影響開始

## shim Create は ClaudeRunWorkflow を呼ばない (Stage B Week 2c-4 prelude で発覚)

### 設計の意図

`ShimLLMStateGraphCreate[graph]` は次の 3 つだけを行う:

1. WorkflowNet を `ClaudeWorkflowFromStateGraph` で構築
2. `ClaudeCreateWorkflowNet` で wid を発行
3. `ClaudeSubmitToken[wid, sentinelToken]` で初期 token を投入

そして sgRid を返す。**`ClaudeRunWorkflow` は呼ばない**。これは元実装の `LLMStateGraphCreate` が「runtimeId を即返して、graph 実行は polling 寄生に任せる」async-create semantics を持つため、shim 側もこれに合わせる。

### 落とし穴

graph 実行は `ClaudeOrchestrator` の `$iSharedPollingTask` (claudecode の polling task に寄生) で進むが、registry 状態によっては polling が遅延し、`LLMStateGraphCreate + Pause + LLMStateGraphStatus` 形式のテストで Status が `"Pending"` のまま timeout する。テスト環境で他の dispatch テスト (25 件等) が前段で実行され大量の runtime が registry に積まれていると顕在化する。

```mathematica
(* これは混雑時に Mode ON で fail する可能性がある *)
rid = LLMStateGraphCreate[graph];
Pause[0.5];
status = LLMStateGraphStatus[rid][["Status"]];   (* "Done" 期待だが "Pending" になりうる *)
```

### 解決策: graph 完了を保証したいなら RunStateGraph (sync) を使う

`RunStateGraph[..., "Async" -> False]` は両モードで graph 完了まで待つ:

- Mode OFF: 元実装の sync 実行
- Mode ON: `ShimRunStateGraph` → `ClaudeRunWorkflow Sync` で完了まで polling

```mathematica
(* 推奨 *)
runResult = RunStateGraph[graph, "Async" -> False, "MaxWait" -> 30];
status = runResult[["Status"]];   (* 完了が保証される *)
```

### テスト設計への含意 (Week 2c-4 で重要)

両モード等価性をテストするには、**graph 完了を保証する API を使うべき**:

| 用途 | API | graph 完了保証 |
|---|---|---|
| Async create を直接テスト | `LLMStateGraphCreate` | なし (polling 寄生に依存) |
| Sync 実行を直接テスト | `RunStateGraph["Async" -> False]` | あり |
| 既存 async テストを両モード比較 | `ClaudeStateGraphReplayTestFile` (Mode-agnostic 限定) | テストファイル設計次第 |

新規テスト設計では `RunStateGraph` を優先し、`LLMStateGraphCreate + Pause` パターンは避けるのが安全。

## 関連

- `workflow-shim-prefix-scheme` (命名規則、本 skill と相補的)
- `runtime-orchestrator-boundary` (Workflow / Runtime の境界判定)
- `association-mutation-patterns` (`Append` で Association に新規キー、`ReplacePart` 不可)
- `wolfram-syntax-pitfalls` §4.5〜§4.8 (StringExpression `_`、`UnsameQ` 演算子、`TestResultObject` Lookup、Unicode エスケープ)
- `workflow-equivalence-testing` (Mode-agnostic / Mode-aware の区別、ReplayTestFile 運用)
- Week 2c-2a / 2c-2b / 2c-4 prelude 進捗ノート

## 寿命

Stage B Week 2c-4 完了 (既存 111 件テスト統合) まで主要レファレンス。Stage C で stategraph deprecated 化されると、forwarding 経路自体が「ClaudeOrchestrator`Workflow` の自然な使い方」として吸収されるため、本 skill の役割は履歴的記録に縮退する。
