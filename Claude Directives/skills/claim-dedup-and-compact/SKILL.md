---
name: claim-dedup-and-compact
description: |
  SourceVault.wl Stage 6a の claim dedup + Compact 設計。
  by-source ファイル単位の ContentHash 照合による書込み時 dedup、
  master 全体の DeleteDuplicatesBy + atomic rewrite による Compact、
  最古残し (Reverse → DeleteDuplicatesBy → Reverse) パターン、
  Windows 対応の path.tmp + DeleteFile + RenameFile atomic write、
  .bak.<ISODateTime> backup の運用。dedup scope の意図的な制約。
---

# Claim dedup + Compact パターン (Stage 6a)

JSONL append-only ストア (jsonl-store-pattern 参照) の上で「同じ内容を 2 回書かない」と
「過去分の重複を圧縮する」を両立する設計。SourceVault.wl Stage 6a で実装・実証済み。

## 設計の出発点

Stage 5 まで: append-only。LLM が同じ source から同じ事実を 2 回抽出すると 2 行積まれる。

Stage 6a: 2 段構え。

| 機能 | タイミング | 既定 |
|---|---|---|
| 書込み時 dedup | `SourceVaultExtract` の Store フェーズ | True |
| 全体 Compact | `SourceVaultClaimStoreCompact[]` (オンデマンド) | DryRun: False / Backup: True |

書込み時 dedup は **per-source の hash set 読込のみ**。master 全件読込を避けることでホットパスを高速に保つ。Compact は重い操作だが手動起動なのでコストを吸収できる。

## 書込み時 dedup の scope: by-source 単位

**意図的な制約**。`ContentHash` (Subject/Predicate/Object/SourceSpan の SHA-256) で照合するが、
スコープは「同じ source の `by-source/<sourceId>.jsonl`」のみ。

### この設計を選んだ理由

1. **パフォーマンス**: master 全件読込は O(N)。複数 source で蓄積するほど遅くなる。per-source なら新規 source なら 0 件読込。
2. **意味**: 異なる論文に同じ事実が書いてあるのは「別 evidence」として残したい。dedup したければ呼び出し側で `GatherBy[..., "ContentHash"]`。
3. **`ContentHash` に `SourceSpan` を含めている**: 厳密には異なる source の同じ事実は別 hash になるが、prompt や schema 揺れで一致するケースもあり得るので、scope で明示的に切る。

### 実装パターン (Wolfram Language)

```mathematica
iLoadClaimHashesForSource[sourceId_String] :=
  Module[{path, claims, hashes},
    If[!StringQ[sourceId] || sourceId === "" || sourceId === "unknown",
      Return[<||>]];
    path = iClaimsBySourcePath[sourceId];
    If[!FileExistsQ[path], Return[<||>]];
    claims = iClaimsLoadJSONL[path];
    hashes = Select[
      Map[Lookup[#, "ContentHash", ""] &, claims],
      StringQ[#] && # =!= "" &];
    AssociationThread[hashes, ConstantArray[True, Length[hashes]]]
  ];
```

**呼び出し側 (Extract の Store フェーズ)**:

```mathematica
If[dedupEnabled,
  Module[{existingHashes, keep},
    existingHashes = iLoadClaimHashesForSource[sourceIdForIndex];
    keep = Select[claims, Function[c,
      Module[{h = Lookup[c, "ContentHash", ""]},
        !(StringQ[h] && h =!= "" &&
          KeyExistsQ[existingHashes, h])]]];
    dedupSkipped = Length[claims] - Length[keep];
    claims = keep
  ]];
```

`AssociationThread[hashes, ConstantArray[True, Length[hashes]]]` で hash set を Association に
する → `KeyExistsQ` で O(1) チェック。

## レスポンス契約: ExtractedCount / DedupSkipped を追加

Stage 5 までは `Count` だけ。Stage 6a で **LLM 抽出数と実 store 数を分離** する:

```mathematica
<|
  "Status" -> "OK",
  "Count" -> Length[claims],            (* 実 store 数 (= dedup 後の数) *)
  "ExtractedCount" -> extractedCount,   (* LLM が抽出した総数 (dedup 前) *)
  "DedupSkipped" -> dedupSkipped,       (* skip 数 = ExtractedCount - Count *)
  ...
|>
```

呼び出し側は `if r["DedupSkipped"] > 0` で「重複が発生した」ことを判定できる。

## Compact: 最古残し DeleteDuplicatesBy パターン

`DeleteDuplicatesBy` は **最初に出てきた要素を残す**。append-only JSONL では「最初に書かれた行」が
master の先頭側にあるので、**そのまま `DeleteDuplicatesBy` を使うと最古が残る**。

ただし「最新を残したい」用途もあり得るので、両対応のために **Reverse → DeleteDuplicatesBy → Reverse**
パターンが汎用的。

```mathematica
(* 最古を残す: DeleteDuplicatesBy をそのまま使う *)
deduped = DeleteDuplicatesBy[all, Lookup[#, "ContentHash", ""] &];

(* 最新を残す: Reverse → DeleteDuplicatesBy → Reverse *)
dedupedRev = DeleteDuplicatesBy[Reverse[all], Lookup[#, "ContentHash", ""] &];
deduped = Reverse[dedupedRev];
```

SourceVault Stage 6a は **最古残し** を採用。理由: 最初の抽出が一番文脈情報が豊富なケースが多い (LLM がプロンプトの細部に注意を向けている)。reproducibility のためにも最古を保存する方が自然。

**Key default**: `Lookup[#, "ContentHash", ToString[Lookup[#, "ClaimId", ""]]]` のように
`ContentHash` 欠落時には `ClaimId` をフォールバックキーにする (互換性のため)。

## Compact の atomic write (Windows 対応)

POSIX `rename(2)` は atomic だが、Windows の `MoveFile` は **既存ファイルがあると失敗** する。
そのため:

```mathematica
iClaimsAtomicWrite[path_String, lines_List] :=
  Module[{tmp, strm, ok = True},
    iEnsureDir[DirectoryName[path]];
    tmp = path <> ".tmp";
    strm = Quiet[OpenWrite[tmp, BinaryFormat -> True,
      CharacterEncoding -> "UTF-8"]];
    If[Head[strm] =!= OutputStream,
      Return[<|"Status" -> "Failed", "Reason" -> "OpenTmpFailed"|>]];
    (* write all lines ... *)
    Close[strm];
    (* atomic rename: 既存 path は delete してから RenameFile *)
    If[FileExistsQ[path], Quiet[DeleteFile[path]]];
    Quiet[RenameFile[tmp, path]];
    If[!FileExistsQ[path],
      Return[<|"Status" -> "Failed", "Reason" -> "RenameFailed"|>]];
    <|"Status" -> "OK", "Path" -> path|>
  ];
```

**Step 3 (DeleteFile) と Step 4 (RenameFile) の間にクラッシュすると path が消えた状態になる**。
これは Windows の本質的制約。確率は低いが、必ず Backup を取っておくことを推奨。

## Backup: `.bak.<ISODateTime>` パターン

```mathematica
ts = DateString["ISODateTime", "DateSeparator" -> "", "TimeSeparator" -> ""];
(* → "20260519T123045" *)

bak = path <> ".bak." <> ts;
Quiet[CopyFile[p, bak]];
```

すべてのインデックスファイル (master + by-topic/*.jsonl + by-source/*.jsonl) を 1 タイムスタンプで
コピー。**rollback は手動 CopyFile**:

```mathematica
CopyFile[
  "....jsonl.bak.20260519T123045",
  "....jsonl",
  OverwriteTarget -> True]
```

定期的な `.bak.*` 掃除は **Stage 6a の責任外**。別途スクリプトで運用する。

## by-topic / by-source の再構築

Compact は master を rewrite するだけでは不十分。**by-topic と by-source も整合性を保つ必要がある**:

```mathematica
iClaimsRewriteAll[uniqClaims_List] :=
  Module[{...},
    (* 既存 by-topic, by-source ファイル全削除 *)
    Scan[Function[p, Quiet[DeleteFile[p]]],
      Join[FileNames["*.jsonl", topicDir], FileNames["*.jsonl", sourceDir]]];
    (* claim ごとに topic/source へ振り分け *)
    Scan[Function[c, ...], uniqClaims];
    (* それぞれ atomic write *)
    iClaimsAtomicWrite[masterPath, masterLines];
    KeyValueMap[{topic, lns} |-> iClaimsAtomicWrite[iClaimsByTopicPath[topic], lns], claimsByTopic];
    KeyValueMap[{src, lns} |-> iClaimsAtomicWrite[iClaimsBySourcePath[src], lns], claimsBySource]
  ];
```

**順序が重要**:

1. 既存 by-topic, by-source を **削除**
2. master の uniq claim から **振り分けマップ** を作る (`claimsByTopic`, `claimsBySource` Association)
3. **atomic write で順次再構築**

途中で失敗しても master は最後に書き換わるので、master だけ古い (= pre-dedup) のままなら次の Compact でリトライ可能。

## Verbose 診断

```mathematica
SourceVault`$SourceVaultExtractVerbose = True;

(* dedup 発動時の Print 出力 *)
(* [SourceVaultExtract] Dedup: 5 claim(s) skipped (already in by-source/src-arxiv-1706.03762.jsonl) *)
```

dedup が「動いたかどうか」を実時間で確認できる。CI で `DedupSkipped` を assert すれば
regression もキャッチできる。

## DryRun サポート

Compact は破壊的操作なので、まず DryRun で件数を確認するパターンを推奨:

```mathematica
SourceVaultClaimStoreCompact["DryRun" -> True]
(* → <|"BeforeCount" -> 47, "AfterCount" -> 38, "Removed" -> 9, "DryRun" -> True|> *)

SourceVaultClaimStoreCompact[]  (* 実行 *)
```

DryRun=True は **ファイルに一切触らない**。read → dedup → 件数計算で return する。

## 罠 (Stage 6a 実装中に踏んだもの)

| # | 罠 | 回避 |
|---|---|---|
| #15 | `Scan[Function[c, Module[..., Return[Null, Module]]]]` は罠 #16 と組み合わさって `$Failed` を返す | フラグ変数 `ok = True/False` + `If[ok, ...]` gate を使う |
| #20 | by-source ファイル読込で `ReadList[..., "String", "UTF-8"]` が Windows で空配列 | `ReadByteArray` + `ByteArrayToString` + `StringSplit[..., RegularExpression["\\r?\\n"]]` パターン (jsonl-store-pattern 参照) |
| — | `Block[{X}, ...]` で X の Options も退避される (罠 #18) | Compact 実装ではトップレベル symbol しか書き換えないので無関係。新規実装では注意 |

## 拡張ポイント

- **Bloom filter による高速 dedup**: 10 万件規模になったら `iLoadClaimHashesForSource` を Bloom filter キャッシュに変更
- **Incremental compact**: 全 rewrite ではなく、変更があった by-source ファイルだけ rewrite
- **Lock**: 並列 Compact 起動を防ぐ advisory lock (Stage 9 で考える)
- **Backup の自動掃除**: `RetentionDays` オプション (現状は手動)
- **dedup scope の拡張**: `"DedupScope" -> "BySource" | "ByTopic" | "Global"` (現状は固定)

## チェックリスト

- [ ] `iSanitizeForJSON` を JSON 化前に必ず呼ぶ (`Missing[]` 等を Null/String に)
- [ ] `iEnsureRoots[]` を Compact 関数の冒頭で呼ぶ
- [ ] DryRun でまず件数確認 → 実行
- [ ] Backup を切るのは CI 等の自動運用に限る
- [ ] `Reverse → DeleteDuplicatesBy → Reverse` で最古残し (採用済みパターン)
- [ ] atomic write は `path.tmp` → `DeleteFile[path]` → `RenameFile[tmp, path]` (Windows 対応)
- [ ] `ExtractedCount` / `DedupSkipped` レスポンス追加 (debug & assertion 用)
