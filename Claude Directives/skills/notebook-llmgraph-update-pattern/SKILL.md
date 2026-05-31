---
name: notebook-llmgraph-update-pattern
description: 外部パッケージ (ClaudeStateGraph 等) から NotebookLLMGraph のノードを追加・更新するときの正しいパターン。誤ると書き込んだノードが直後の NotebookLLMGraphNodes[] で見えないバグになる。直接キャッシュ更新 + Flush、必要な Public 化シンボルを扱う。Use when adding or updating NotebookLLMGraph nodes from an external package, or when written nodes are not visible afterward.
paths:
  - "**/*.{wl,wls,m,nb}"
---

# NotebookLLMGraph 更新の正しいパターン

外部パッケージ (ClaudeStateGraph 等) から `NotebookLLMGraph` のノードを追加・更新する際に守るべきパターン集。誤ったパターンを使うと、書き込んだノードが直後の `NotebookLLMGraphNodes[]` で見えないという厄介なバグが発生する。

## 1. 落とし穴: `iSaveNotebookLLMGraph` 単独はキャッシュを更新しない

`claudecode.wl` の `iSaveNotebookLLMGraph[nb, graph]` は `CurrentValue[nb, {TaggingRules, ...}]` に `Compress[graph]` を書き込むだけで、**メモリキャッシュ `$iLLMGraphCache` を更新しない**。

```mathematica
(* claudecode.wl の実装 *)
iSaveNotebookLLMGraph[nb_NotebookObject, llmGraph_Association] := (
  Quiet[CurrentValue[nb,
    {TaggingRules, "claudecode", "LLMGraph"}] =
      Compress[llmGraph]];
  llmGraph);
```

一方、参照側 `iLLMGraphGetCached[nb]` はキャッシュヒットを優先する:

```mathematica
iLLMGraphGetCached[nb_NotebookObject] :=
  If[$iLLMGraphCacheNB === nb && AssociationQ[$iLLMGraphCache],
    $iLLMGraphCache,                  (* キャッシュヒット → 古い値が返る *)
    iLoadNotebookLLMGraph[nb]];
```

このため、外部パッケージが

```mathematica
graph["Nodes"][newNodeID] = newNode;
Quiet @ ClaudeCode`iSaveNotebookLLMGraph[nb, graph];   (* ← TaggingRules には書けるが... *)

(* 直後 *)
ClaudeCode`NotebookLLMGraphNodes[nb]   (* キャッシュ参照で newNodeID が見えない *)
```

という症状が出る。

## 2. 正しいパターン: 直接キャッシュ更新 + Flush

`LLMGraphDAGRecordHistory` (claudecode.wl 内の正規実装) と同じパターンを使う:

```mathematica
graph["Nodes"]        = updatedGraphNodes;
graph["LastModified"] = AbsoluteTime[];

(* キャッシュを直接更新してから TaggingRules に Flush *)
ClaudeCode`$iLLMGraphCache   = graph;
ClaudeCode`$iLLMGraphCacheNB = nb;
Quiet @ ClaudeCode`iLLMGraphFlush[nb];
```

`iLLMGraphFlush[nb]` の中身は:

```mathematica
iLLMGraphFlush[nb_NotebookObject] :=
  If[AssociationQ[$iLLMGraphCache] && $iLLMGraphCacheNB === nb,
    iSaveNotebookLLMGraph[nb, $iLLMGraphCache];
    $iLLMGraphCache];
```

つまり、**「キャッシュ変数に書き込む → Flush で TaggingRules へ反映」** という2段階で初めて整合する。

## 3. 必要な Public 化シンボル (claudecode.wl)

外部パッケージから `ClaudeCode\`X` 形式でアクセスするため、claudecode.wl の BeginPackage 直後の `Quiet[ClearAll[..., X, ...]]` リストに以下を含める必要がある:

```mathematica
(* 最低限必要な 5 シンボル *)
iLLMGraphGetCached, iSaveNotebookLLMGraph, iNewLLMNode,
iNewNotebookLLMGraph, iLLMGraphMergeTwoGraphs,

(* キャッシュ更新パターン用 (本 skill のため) *)
$iLLMGraphCache, $iLLMGraphCacheNB, iLLMGraphFlush,
```

これらは `Begin["\`Private\`"]` 内で定義済みでも、ClearAll リスト経由で Public 名前として登録される。

## 4. 完全実装例: 外部パッケージからのノード記録関数

```mathematica
(* ClaudeStateGraph.wl 内の Private 関数 *)
iStateGraphRecordToLLMGraph[runtimeId_String] :=
  Module[{rt, nb, graph, graphNodes, sgPrefix, ...},
    rt = $iLLMStateGraphRuntimes[runtimeId];
    If[!AssociationQ[rt], Return[]];
    
    nb = Lookup[rt, "Notebook", $Failed];
    If[!MatchQ[nb, _NotebookObject], Return[]];
    
    (* 1. 既存グラフを取得 *)
    graph = Quiet @ Check[ClaudeCode`iLLMGraphGetCached[nb], None];
    If[!AssociationQ[graph], Return[]];
    graphNodes = Lookup[graph, "Nodes", <||>];
    If[!AssociationQ[graphNodes], graphNodes = <||>];
    
    (* 2. ノードを追加・更新 *)
    sgPrefix = "sg-" <> ToString[Round[rt["StartTime"]]] <> "-" <>
               StringTake[runtimeId, -6];
    Do[Module[{nlgID = sgPrefix <> "-" <> stateNodeId, nodeData},
      nodeData = ClaudeCode`iNewLLMNode[nlgID, "Compute", "Public",
        <|"Instruction" -> ..., "Status" -> ..., (* etc *)|>];
      graphNodes[nlgID] = nodeData
    ], {stateNodeId, Keys[rt["Graph"]["Nodes"]]}];
    
    (* 3. グラフを更新 *)
    graph["Nodes"]        = graphNodes;
    graph["LastModified"] = AbsoluteTime[];
    
    (* 4. キャッシュ更新 + Flush (順序重要!) *)
    ClaudeCode`$iLLMGraphCache   = graph;
    ClaudeCode`$iLLMGraphCacheNB = nb;
    Quiet @ ClaudeCode`iLLMGraphFlush[nb];
    
    Null];
```

## 5. テストでの検証パターン

### 5.1 動的キー検出 (Private シンボル参照を回避)

テストパッケージから `ClaudeStateGraph\`Private\`$iLLMStateGraphRuntimes` のような Private シンボルに直接アクセスすると、 `BeginPackage` の依存関係に含まれていない context のシンボルとして誤解釈され、`ToString[Round[...]]` が文字列のまま埋め込まれる事故が起きる。

代わりに **NotebookLLMGraph に書き込まれたキー側から動的検出** する:

```mathematica
iFindSgKey[graphNodes_Association, suffix_String] :=
  SelectFirst[Keys[graphNodes],
    StringStartsQ[#, "sg-"] && StringEndsQ[#, suffix] &,
    None];

(* 使い方 *)
graphAfter = ClaudeCode`NotebookLLMGraphNodes[nb];
startKey = iFindSgKey[graphAfter, "-Start"];   (* 実機の prefix を知らずに引き当て *)
```

これで実機の prefix 計算 (UnixTime や AbsoluteTime に依存) を再現する必要がなくなる。

### 5.2 デバッグ用キャッシュダンプ

テスト失敗時の診断用に、キャッシュ状態を可視化するヘルパーを用意しておくと原因特定が早い:

```mathematica
iDumpGraphState[label_String, nb_] :=
  Module[{nodes, sgKeys, cache},
    nodes  = ClaudeCode`NotebookLLMGraphNodes[nb];
    sgKeys = Select[Keys[nodes], StringStartsQ[#, "sg-"] &];
    cache  = ClaudeCode`$iLLMGraphCache;
    Print["[", label, "] NodeCount=", Length[nodes],
      " sg-* count=", Length[sgKeys],
      " cache=", If[AssociationQ[cache],
        "Association(" <> ToString[Length[Lookup[cache, "Nodes", <||>]]] <> ")",
        ToString[Head[cache]]]];
    sgKeys];
```

`NotebookLLMGraphNodes` の件数とキャッシュの件数が**ズレていれば**、Flush 漏れまたは context 解決ミスの可能性が高い。

## 6. アンチパターン集

### ❌ アンチパターン1: TaggingRules のみ更新

```mathematica
ClaudeCode`iSaveNotebookLLMGraph[nb, updatedGraph];   (* キャッシュは古い *)
```

直後の `NotebookLLMGraphNodes[nb]` で更新前の状態が返る。

### ❌ アンチパターン2: キャッシュのみ更新

```mathematica
ClaudeCode`$iLLMGraphCache = updatedGraph;   (* TaggingRules は古い *)
```

ノートブックを保存→再オープンすると消える。次のセッションで失われる。

### ❌ アンチパターン3: 順序が逆

```mathematica
Quiet @ ClaudeCode`iLLMGraphFlush[nb];          (* 古いキャッシュを Flush *)
ClaudeCode`$iLLMGraphCache = updatedGraph;       (* 後から更新しても TaggingRules は古い *)
```

Flush は「現在のキャッシュ→TaggingRules」コピーなので、キャッシュ更新が先でなければならない。

### ✅ 正しい順序

```mathematica
ClaudeCode`$iLLMGraphCache   = updatedGraph;     (* 1. キャッシュ更新 *)
ClaudeCode`$iLLMGraphCacheNB = nb;                (* 2. 対応 nb を記録 *)
Quiet @ ClaudeCode`iLLMGraphFlush[nb];            (* 3. TaggingRules へ反映 *)
```

## 7. 関連する skill / rule

- `llmgraph-dag-job-lifecycle` — LLMGraphDAG ジョブの自動削除挙動と registry 観察
- `package-namespace-migration` — Public/Private シンボルアクセスの context 罠
- `wolfram-syntax-pitfalls` — 編集時の構文落とし穴 (本 skill と関連)
- `nbaccess-separation-check` — 基盤パッケージ間の分離原則
