---
name: orchestrator-file-contents-handler
description: |
  ClaudeOrchestrator の Single Committer phase で `file_contents` 宣言を
  deterministic に処理するハンドラの設計記録 (Phase 21 / Step 6)。
  worker が「ファイル作成しました」とハルシネーションしても実書き込みが
  起きるのは file_contents 宣言経由のみ、という Single Source of Truth
  を確立した。NBAccess`NBFileExport を AccessibleDirs ガード下で呼び、
  LLM Cell 書き payload が無ければ早期 Committed として返す。
---

# Orchestrator file_contents Handler

このドキュメントは ClaudePackageManager の Phase 21 (Step 6) で実装した
file_contents handler の設計と、開発で得た知見を記録する。

## 目的

LLM worker が成果物としてファイル作成を宣言する場合の確実な実書き込み経路。
worker は「副作用なし」原則を維持しつつ、`payload.file_contents` (List of
`<|"path" -> ..., "content" -> ...|>`) を artifact に含めることで、
Commit phase が deterministic にファイルを書く。

これにより:
- worker が「ファイル作成しました」とハルシネーションしても、`file_contents`
  宣言が無ければ何も書かれない (検証可能)
- Single Committer 原則を維持しつつ deterministic な file write が単独で完結

## アーキテクチャ

```
worker LLM
    ↓ artifact に file_contents 宣言を含める
    ↓ 副作用なし (Single Committer 原則)
Reduce phase (artifact 集約)
    ↓
ClaudeCommitArtifacts (Public)
    ↓ direct retry loop (Quiet @ Check 罠を bypass、罠 #16 参照)
iCommitArtifactsOnce
    ├── 走査ループで全 Association を allAssocs に集約
    │   + file_contents をリストアップ
    ├── NBAccess`NBFileExport で実書き込み (AccessibleDirs ガード下)
    ├── 失敗があれば earlyResult = "Failed"
    ├── LLM payload (expression/cells/code/HeldExpr) 無し →
    │   earlyResult = "Committed" + Details = "FileContentsOnly"
    └── If[earlyResult === None,
          通常 LLM Commit phase, ← LLM Cell 書きが必要なときのみ
          earlyResult]            ← 早期終了
```

## 設計判断

### 1. 純粋な if/else gate (Catch/Throw も Return も使わない)

罠 #12, #15, #16 を回避するため:

```mathematica
Module[{..., earlyResult},
  earlyResult = None;
  
  ... handler 処理で earlyResult を設定 ...
  
  If[earlyResult === None,
    
    通常 LLM Commit phase まるごと,    (* then 節 *)
    
    earlyResult                        (* else 節 *)
  ]
]
```

- Catch/Throw 不使用: 罠 #15 (Map 後の Throw が Check を触発)
- Return 不使用: 罠 #12 (ネスト Module でスコープ問題)
- Quiet/Check 不使用 in wrapper: 罠 #16 (messages 0 件でも `$Failed`)

### 2. Stack-based 走査ループ (Module 局所関数定義を避ける)

```mathematica
Module[{queue, cur, fc, payload, wa},
  queue = {reducedArtifact};
  While[Length[queue] > 0,
    cur = First[queue];
    queue = Rest[queue];
    If[AssociationQ[cur],
      AppendTo[allAssocs, cur];
      fc = Lookup[cur, "file_contents", None];
      If[ListQ[fc], AppendTo[fileContentsList, fc]];
      payload = Lookup[cur, "Payload", None];
      If[AssociationQ[payload], queue = Append[queue, payload]];
      wa = Lookup[cur, "WorkerArtifacts", None];
      If[AssociationQ[wa], queue = Join[queue, Values[wa]]]
    ]
  ]
]
```

理由: Module 内で `f[x_] := ...` のような DownValues 定義は環境依存の衝突を
起こす可能性があるため、データ構造 (queue) と While ループだけで解決する。
1 度の走査で fileContentsList と allAssocs を同時に集める (効率的)。

### 3. Wrapper の direct retry loop

罠 #16 回避のため `iRetryableInvoke` (Quiet @ Check ベース) を bypass する:

```mathematica
ClaudeCommitArtifacts[targetNotebook, reducedArtifact, opts] :=
  Module[{retryMax, attempt, result, classification, finalResult},
    retryMax = Max[1, OptionValue["CommitRetryMax"]];
    attempt = 0;
    result = $Failed;
    classification = "Retryable";
    While[attempt < retryMax,
      attempt++;
      result = iCommitArtifactsOnce[targetNotebook, reducedArtifact, opts];
      classification = Which[
        !AssociationQ[result], "Retryable",
        Lookup[result, "Status", ""] === "Committed", "Success",
        Lookup[result, "Status", ""] === "NotImplemented", "Permanent",
        True, "Retryable"];
      If[classification === "Success" || classification === "Permanent",
        Break[]]
    ];
    finalResult = If[AssociationQ[result], result, <|"Status" -> "Failed"|>];
    ...
  ]
```

## NBAccess 連鎖ロード

ClaudeOrchestrator.wl が file_contents handler から `NBAccess`NBFileExport[]`
を直接呼ぶため、明示的な依存ロードを `BeginPackage` 直後に置く。罠 #13 を
回避するため `$Path` を一時的に prepend:

```mathematica
BeginPackage["ClaudeOrchestrator`"];

Block[{$CharacterEncoding = "UTF-8",
       iOrchPkgDir = Which[
         StringQ[$InputFileName] && $InputFileName =!= "",
           DirectoryName[$InputFileName],
         StringQ[Quiet @ Symbol["Global`$packageDirectory"]],
           Symbol["Global`$packageDirectory"],
         True, Directory[]]},
  Quiet @ Block[{$Path = Prepend[$Path, iOrchPkgDir]},
    Needs["NBAccess`", "NBAccess.wl"]]];
```

これで `<< ClaudeOrchestrator.wl` 単独でも NBAccess が連鎖ロードされる
(claudecode.wl 経由と同等)。

## NBFileExport / NBFileImport ファサード仕様 (Phase 21)

NBAccess.wl 側に追加した。

- `NBFileExport[path, content, Format -> "Text", Overwrite -> True]` —
  `NBGetAccessibleDirs[]` (TaggingRules) でガードされた場所への書き込み
- `NBFileImport[path]` — Object/Schema 分離。AccessLevel 不足時も Schema は返る
- 戻り値: `<|"Status" -> "OK"|"Denied"|"ExecutionFailed", "Path" -> ..., 
  "BytesWritten" -> ..., "Decision" -> "Permit"|"Deny", "ReasonClass" -> ...|>`

## file_contents-only mode の判定

LLM Cell 書き不要かどうかは、reducedArtifact / Payload / WorkerArtifacts の
**全 Association** を再帰的に見て、`expression` / `expressions` / `cells` /
`code` / `HeldExpr` のいずれかキーが存在するかで判定する:

```mathematica
hasLLMPayload = AnyTrue[allAssocs,
  Function[a,
    AnyTrue[
      {"expression", "expressions", "cells", "code", "HeldExpr"},
      Function[k, KeyExistsQ[a, k]]]]]
```

これらキーが無ければ「ファイル作成だけ」のタスクと判定し、LLM Commit phase を
skip して Status="Committed", Details="FileContentsOnly" を返す。

## 検証済みテスト (v15 production)

mockArtifact:
```mathematica
<|"TaskId"  -> "test-handler",
  "Status"  -> "Success",
  "Payload" -> <|
    "summary"       -> "create hello.txt via file_contents",
    "file_contents" -> {
      <|"path"    -> "C:\\test_facade\\hello.txt",
        "content" -> "Hello from file_contents handler!"|>
    }
  |>|>
```

期待される verbose ログ:
```
[commit-files] 1 file_contents entries declared, executing via NBFileExport
[commit-files] 1 written, 0 failed
[commit-files] file_contents-only mode: no LLM commit payload, returning early as Committed
```

期待される result:
```mathematica
<|"Status"  -> "Committed",
  "Details" -> "FileContentsOnly",
  "FileContentsResults" -> {<|"Status" -> "OK", "Path" -> ..., "BytesWritten" -> 33, ...|>},
  "ReducedArtifact" -> ...|>
```

## 開発で得た重要な知見

1. **`Quiet @ Check[..., $Failed]` は signal handling として fragile** (罠 #16)。
   value-based fail 判定 (Status="Failed" を見る) を優先する。

2. **Map 評価後の Return / Throw は危険** (罠 #15)。フラグ変数で gate するのが
   最も安全。

3. **AccessibleDirs は EvaluationNotebook[] の TaggingRules** に保存される。
   テストでは `NBSetAccessibleDirs[...]` を **同じセル**で実行する必要がある
   (kernel 再起動で消える)。

4. **Verbose Print は production で 3 種類に絞る**:
   - `[commit-files] N entries declared` (進捗)
   - `[commit-files] N written, M failed` (集計)
   - `[commit-files] file_contents-only mode: ...` (モード通知)

   AccessibleDirs / NBFileExport 戻り値詳細などは debug 専用で撤去する。

## 次のステップ (PENDING)

- Step 5: LLMGraph 記録 — file_contents handler の各フェーズを 
  `iRuntimeRecordTurnToLLMGraph` で記録
- Step C: 既存テスト (50/50, 105/105 など) の継続合格確認
- Phase B: ConversationState に InputTaintLevel 追加
- Phase B: worker adapter の動的 accessSpec 設定
