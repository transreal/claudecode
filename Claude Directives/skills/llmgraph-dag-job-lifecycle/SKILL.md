---
paths:
  - "**/*.{wl,wls,m,nb}"
---

# LLMGraphDAG ジョブのライフサイクルと registry 観察パターン

## 概要

`claudecode.wl` の `LLMGraphDAGCreate` で起動した DAG ジョブには、外から扱うときに躓きやすい 2 つの挙動がある:

1. **完了したジョブは registry から自動削除される** (全ノード正常完了時)
2. **registry シンボル `$iLLMGraphDAGJobs` の context 解決が予測しにくい** (claudecode.wl が `Begin["`Private`"]` を持たない非標準構造のため)

本 skill はこれら 2 つの挙動と、それぞれの安全な扱い方をまとめる。

## 挙動 1: ジョブの自動削除

`claudecode.wl` の `LLMGraphDAGCreate` で起動した DAG ジョブは、**全ノードが正常完了 (failure なし) で完了すると `$iLLMGraphDAGJobs` から自動削除される**。これはメモリリーク防止のための意図的な設計である。

ただし、テストや結果取得のため後から `LLMGraphDAGStatus[jobId]` を呼んでも `Missing["JobNotFound", jobId]` が返るので、**正しい結果取得パターン** を理解しておくこと。

### claudecode.wl の挙動 (該当コード)

```mathematica
(* claudecode.wl L21186-21196: 全ノード terminal 判定後 *)
If[doneCount >= totalCount,
  Module[{onComplete = Lookup[job, "onComplete", None]},
    If[onComplete =!= None, Quiet[onComplete[job]]]];   (* ← ここで callback 発火 *)
  Quiet @ iLLMGraphDAGRecordHistory[job];
  ...
  If[Length[failedIds] > 0,
    job["completedAt"] = AbsoluteTime[];
    $iLLMGraphDAGJobs[jobId] = job,                          (* ← 失敗ノードあり: 残す *)
    $iLLMGraphDAGJobs = KeyDrop[$iLLMGraphDAGJobs, jobId]];  (* ← 全 done: 削除! *)
  KeyDropFrom[$claudeProgress, jobId];
  Return[]];
```

### 失敗パターン: 完了後の LLMGraphDAGStatus による結果取得

```mathematica
(* ❌ 動作しない: 全ノード正常完了したジョブは registry から消えている *)
jobId = LLMGraphDAGCreate[<|
  "nodes" -> <|...|>,
  "taskDescriptor" -> <|...|>,
  "context" -> <||>|>];

Pause[5];   (* DAG が完了するのを待つ *)

status = LLMGraphDAGStatus[jobId];
(* status = Missing["JobNotFound", "dag-..."] *)

result = Lookup[Lookup[status, "nodes", <||>], "n2", <||>]["result"];
(* result = $Failed (シンボルが取れない) *)
```

これを「DAG が壊れている」「LLMGraphDAGCreate が機能しない」と誤判定しない。**registry から消えるのは正常動作**。

### 正しいパターン: onComplete callback で結果捕捉

```mathematica
(* ✅ 正しいパターン: onComplete で外部スコープに結果を保存 *)
Module[{n2Result = None, completed = False, jobId},
  jobId = LLMGraphDAGCreate[<|
    "nodes" -> <|
      "n1" -> iLLMGraphNode["n1", "sync", "test", {},
        Function[{job}, <|"value" -> 21|>]],
      "n2" -> iLLMGraphNode["n2", "sync", "test", {"n1"},
        Function[{job},
          Module[{prev = Lookup[
              Lookup[job["nodes"], "n1", <||>], "result", <||>]},
            <|"doubled" -> 2 * Lookup[prev, "value", 0]|>]]]|>,
    "taskDescriptor" -> <|"name" -> "...",
      "categoryMap" -> <|"test" -> "sync"|>|>,
    "context" -> <||>,
    "onComplete" -> Function[{job},
      n2Result = Lookup[
        Lookup[job["nodes"], "n2", <||>], "result", $Failed];
      completed = True]|>];
  
  (* completed フラグで完了を検出 *)
  Module[{waited = 0, dt = 0.5, maxWait = 15},
    While[waited < maxWait && !TrueQ[completed],
      Pause[dt]; waited += dt]];
  
  (* n2Result が完了結果を保持している *)
  n2Result   (* → <|"doubled" -> 42|> *)
]
```

### 失敗ジョブだけは registry に残る

L21193-21194 の通り、**failure を含む完了は registry に残る** (`completedAt` 付きで保存される)。これにより:

```mathematica
(* 失敗ジョブの調査は LLMGraphDAGStatus で可能 *)
status = LLMGraphDAGStatus[jobId];
(* status = <|"JobID" -> ..., "Failed" -> ..., ...|> ← 取得可能 *)

(* 全ノード正常完了は registry から消えるので status 取得不可 *)
```

## 挙動 2: $iLLMGraphDAGJobs の context 解決問題

**外部から `ClaudeCode\`$iLLMGraphDAGJobs` を参照しても、claudecode.wl 内部の `$iLLMGraphDAGJobs` と異なるシンボルに解決されることがある**。これは claudecode.wl が `Begin["`Private`"]` を持たない非標準構造で、シンボルの公開・private 区別が予測しにくいことに起因する。

### 失敗パターン: 外部から Keys で覗く

```mathematica
(* ❌ 期待通り動作しないことがある *)
Module[{slowJobId, legacyKeys},
  slowJobId = LLMGraphDAGCreate[<|
    "nodes" -> <|"n" -> iLLMGraphNode["n", "sync", "test", {},
      Function[{job}, Pause[5]; <|"v" -> 1|>]]|>,
    "taskDescriptor" -> <|"name" -> "test",
      "categoryMap" -> <|"test" -> "sync"|>|>,
    "context" -> <||>|>];
  Pause[0.5];   (* tick 前なので job は登録されているはず *)
  
  legacyKeys = Quiet @ Keys @ ClaudeCode`$iLLMGraphDAGJobs;
  MemberQ[legacyKeys, slowJobId]
  (* False になることがある!
     外部参照では context が違うシンボルに解決される可能性 *)
]
```

`LLMGraphDAGCreate`/`LLMGraphDAGStatus`/`onComplete` 等の **claudecode.wl 内部から見える** `$iLLMGraphDAGJobs` と、**外部から `ClaudeCode\`$iLLMGraphDAGJobs` で参照する** シンボルが、context 解決の都合で**別シンボル**になる場合がある。書き込み・読み込みは内部で一貫しているが、外部からの直接観察は不可。

### 正しいパターン: handler 内部から観察

handler は claudecode.wl の `node["handler"][job]` 形式で呼び出されるため、**handler 内では claudecode.wl と同じ context** で `$iLLMGraphDAGJobs` が解決される。ここから観察すれば確実に取得可能。

```mathematica
(* ✅ 正しいパターン: handler 内部から registry を観察 *)
Module[{capturedKeys = None, completed = False, jobId},
  jobId = LLMGraphDAGCreate[<|
    "nodes" -> <|
      "obs" -> iLLMGraphNode["obs", "sync", "test", {},
        Function[{job},
          (* handler 内 = claudecode.wl の context 解決 *)
          capturedKeys = Keys[ClaudeCode`$iLLMGraphDAGJobs];
          <|"observed" -> True|>]]|>,
    "taskDescriptor" -> <|"name" -> "registry-observe",
      "categoryMap" -> <|"test" -> "sync"|>|>,
    "context" -> <||>,
    "onComplete" -> Function[{job}, completed = True]|>];
  
  Module[{waited = 0, dt = 0.5, maxWait = 15},
    While[waited < maxWait && !TrueQ[completed],
      Pause[dt]; waited += dt]];
  
  (* capturedKeys に handler 実行時点の registry が記録されている *)
  capturedKeys
]
```

handler 実行中はジョブがまだ registry に登録されているので、handler 自身の jobId が `capturedKeys` に含まれているはず。

### 比較: LLMStateGraph 側の registry

`ClaudeStateGraph\`Private\`$iLLMStateGraphRuntimes` は `Begin["`Private`"]` で明示的に Private context に置かれているため、外部から `ClaudeStateGraph\`Private\`$iLLMStateGraphRuntimes` で参照しても **正しく取得できる**。

```mathematica
(* ✅ LLMStateGraph 側は外部参照で OK *)
sgKeys = Quiet @ Keys @ ClaudeStateGraph`Private`$iLLMStateGraphRuntimes;
```

これは ClaudeStateGraph.wl が標準的な BeginPackage / Begin / End / EndPackage 構造を持つため。claudecode.wl の非標準構造との対比で覚えておくとよい。

## チェックリスト: DAG ジョブの結果取得テスト

`LLMGraphDAGCreate` の動作確認テストを書く時:

- [ ] **`onComplete` callback** で結果を外部 `Module` 変数に保存しているか?
- [ ] callback で setting した完了フラグ (例: `completed = True`) を `Pause`/`While` ループで監視しているか?
- [ ] **`LLMGraphDAGStatus[jobId]` だけ** で完了確認しようとしていないか? (完了後は JobNotFound になる)
- [ ] テストの handler は外部副作用なしか? (副作用ありだと並列実行で不具合)
- [ ] registry の中身を覗きたい時、**外部から `ClaudeCode\`$iLLMGraphDAGJobs` を参照していないか**? handler 内部から観察するパターンを使う。

## 関連ルール・スキル

- `rules/95-scheduled-task-safety.md` セクション C — LLMGraph DAG フレームワーク
- `skills/package-namespace-migration/SKILL.md` — 関連: パッケージ間の context 解決の罠

## 参考: 確立過程の検証履歴

このスキルは以下の検証セッション (Phase R-3 + Q-2a, 2026-04-30) で確立された:

| 検証 | 失敗症状 | 判明した原因 |
|---|---|---|
| result5/result6 | `n2 result: $Failed` | (誤った仮説で迷走: shadowing と誤認) |
| result7 | `Missing["JobNotFound", jobId]` (全ケース) | claudecode.wl L21194-21195 の自動削除 |
| result8 | LegacyDAG 7/7 PASS、RegistryIsolation のみ FAIL | 外部参照の context 解決問題 |
| result9 | **84/84 PASS** | handler 内部観察で context 違いを完全回避 |
