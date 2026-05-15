---
name: workflow-shim-prefix-scheme
description: ClaudeOrchestrator`Workflow`Shim` で XSM (LLMStateGraph) を WorkflowNet に変換するときの命名規則と、PSG (ParallelSubgraph) の inner ノード ネストでの命名衝突回避。Use when working on shim implementation or extending WorkflowNet generation logic, especially when adding a new node type or considering inner node nesting.
---

# Workflow shim 命名 prefix scheme

`ClaudeOrchestrator_workflow_shim.wl` (Stage B Week 2c-1 以降) で XSM の Node / Edge を WorkflowNet の Place / Transition に変換するときの命名規則。

## 命名のフォーマット

| 対象 | top-level | PSG inner | PSG ネスト |
|---|---|---|---|
| Node X の入口 place | `place_X_in` | `place_<P>__X_in` | `place_<P>__<Q>__X_in` |
| Node X の出口 place | `place_X_out` | `place_<P>__X_out` | `place_<P>__<Q>__X_out` |
| Node X の handler trans | `trans_X_handle` | `trans_<P>__X_handle` | `trans_<P>__<Q>__X_handle` |
| PSG P の split trans | `psg_P_split` | `psg_<Pouter>__P_split` | `psg_<Pouter>__<Pmid>__P_split` |
| PSG P の join trans | `psg_P_join` | `psg_<Pouter>__P_join` | `psg_<Pouter>__<Pmid>__P_join` |
| Edge from→to | `edge_<from>_to_<to>` | (PSG inner には Edge は無い) | 同左 |

`__` (二重 underscore) を区切り文字として使う。

## 制約

> **nodeId に `__` を含めてはならない**

PSG の inner として展開されるとき名前衝突するため reserved character。`iValidateNodeId` で実行時検証する:

```mathematica
iValidateNodeId[nodeId_String] :=
  If[StringContainsQ[nodeId, "__"],
    Throw[$Failed, "InvalidNodeId: ..."]
  ]
```

## 実装パターン

### prefix オプションの伝播

すべての builder / handler factory に `prefix_String:""` を OptionalPattern として追加する。デフォルト `""` で top-level 呼び出しは無修飾と等価:

```mathematica
iPlaceInName[nodeId_String, prefix_String:""] :=
  "place_" <> prefix <> nodeId <> "_in";

iNodeToPartialNet[node_Association, prefix_String:""] :=
  Module[{...},
    iValidateNodeId[node["Id"]];
    Switch[node["Type"],
      ...,
      "ParallelSubgraph", iParallelSubgraphToPartialNet[node, prefix],
      ...
    ]
  ];
```

`Map[iNodeToPartialNet, Values[nodes]]` のような既存呼び出しが OptionalPattern により無修正で動く。

### PSG での再帰的展開

PSG の inner が PSG / Decision でも同じ `iNodeToPartialNet` で再帰展開する:

```mathematica
iParallelSubgraphToPartialNet[node_Association, prefix_String:""] :=
  Module[{nodeId, innerNodes, innerPrefix, innerNets, ...},
    nodeId      = node["Id"];
    innerPrefix = prefix <> nodeId <> "__";    (* 親 PSG の prefix を被せる *)
    
    innerNets = KeyValueMap[
      Function[{innerId, innerNode},
        iNodeToPartialNet[innerNode, innerPrefix]    (* 再帰 *)
      ],
      innerNodes
    ];
    ...
  ]
```

### handler 内での binding access

Handler factory も prefix を保持して binding key を作る:

```mathematica
iMakeNodeHandler[nodeId_String, handler_, type_String,
                  prefix_String:""] :=
  Function[binding,
    Module[{inToken},
      inToken = binding[[iPlaceInName[nodeId, prefix]]];   (* prefix-aware *)
      ...
    ]
  ];
```

これにより handler が起動されたとき、binding 内のキーが prefix 付きの正確な名前になっていても正しく取り出せる。

## 許容される inner 型

`iParallelSubgraphToPartialNet` 内で:

```mathematica
allowedInnerTypes = {"Stage", "Compute", "Decision", "ParallelSubgraph"};
```

Terminal は inner として意味がないので除外。Subprocess 等の未対応型は `PSGInnerNodeUnsupported` で Throw する。

## XSMSentinel token の Payload 構造

```mathematica
<|"Kind"     -> "XSMSentinel",
  "Payload"  -> <|
    "GlobalState" -> <|
      "Stages"       -> <||>,    (* stategraph 互換性、Week 2c-2a 以降 *)
      "Path"         -> {},
      "Accumulator"  -> <||>,
      "InputContext" -> <||>,
      ...handler が累積 merge した keys...
    |>,
    "Path"        -> {nodeIds}    (* Stage/Compute/Decision で append *)
  |>|>
```

- Stage / Compute Node の handler は GlobalState を `Join` で merge し、Path に nodeId を append
- Decision Node は handler 戻り値 `<|"Pass" -> Bool, ...|>` を `GlobalState["Decisions"][nodeId]` に **nodeId で隔離格納** (複数 Decision の衝突回避)
- Stage / Compute / Decision Node の handler は **`Stages[nodeId][Output]` 形式にも格納** (stategraph 慣習との互換性、Week 2c-2a 以降)
- PSG split は同じ payload を全 inner に配る (`iProduceOutputTokens` の自然な動作)
- PSG join は全 inner の GlobalState を `Fold[Join, <||>, ...]` で merge し、`JoinFn` (Optional) で追加更新

## テスト確認のパターン

prefix 付きの命名を検証するときは **`Cases[..., StringExpression]` を避ける** (Pattern Blank の罠、`wolfram-syntax-pitfalls` §4.5 参照)。代わりに `MemberQ` で具体的な名前を直接確認する:

```mathematica
(* OK: 具体名で MemberQ *)
{MemberQ[places, "place_P19a__X_in"],
 MemberQ[places, "place_P19b__X_in"]}

(* NG: StringExpression 内の "_" は Pattern Blank *)
Cases[places, "place_P19" ~~ _ ~~ "__X_in"]   (* 0 件にマッチ *)
```

## 関連

- `Workflow_Migration_StageB_Design_Notes.md` §4 (shim 戦略)
- `wolfram-syntax-pitfalls` §4.5 (StringExpression の `_` 罠)
- `runtime-orchestrator-boundary` (XSMSentinel token の placement)
- `workflow-shim-forwarding-design` (forwarding 戦略、本 skill と相補的)
- Week 2c-1 / 2c-2a / 2c-2b 進捗ノート

## 寿命

Stage B Week 2c-4 完了 (旧 LLMStateGraph* API forwarding 完了 + 既存 111 件統合) まで主要レファレンス。Stage C で stategraph deprecated 化されると、本 skill の役割は履歴的記録に縮退する。
