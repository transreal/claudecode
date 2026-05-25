---
name: snapshot-lifecycle-and-diff
description: |
  SourceVault.wl Stage 8 の snapshot lifecycle + vN diff 設計。
  page-hashes.json (Stage 4B) を使った snapshot 間の page hash 差分計算、
  snapshot meta の LifecycleStatus を更新することで Bundle が lazy に自動 stale 化される
  passive consumer pattern、events/source-events.jsonl への append-only event log、
  VersionedUpdate / Retraction / SourceDeletion / SchemaChange の 4 種 event、
  RefreshSnapshot による diff + Stale + SupersededBy + event 一括処理、Phase 2/3 への伏線。
  仕様書 §4.2.1 / §5.2 / §7.4 / §11.4 の最小実装。
---

# Snapshot Lifecycle + vN Diff 設計 (Stage 8)

「arXiv の論文が v2 → v3 に更新されたら、生成コードが自動 stale 化される」仕組みを、
**Bundle 側を一切触らずに** 実現する設計。

## キーアイデア: Bundle は Passive Consumer

Stage 6c の `iBundleComputeStatus` は **毎回 snapshot meta を file から読む**。
これにより、snapshot meta の `LifecycleStatus` を書き換えるだけで、すべての参照 Bundle が
次回 `BundleStatus` 呼出時に自動的に新しい status を返す。

```
   [SourceVaultMarkSnapshotStale]
              ↓
   snapshot meta.LifecycleStatus = "Stale"
              ↓
              (lazy, on demand)
              ↓
   SourceVaultBundleStatus[bid]
              ↓
   iBundleComputeStatus が snapshot meta を毎回読込
              ↓
   いずれかの snapshot が "Stale" → bundle も "Stale"
```

**利点**:

- Bundle 側に broadcast invalidation のロジックが要らない
- snapshot を fixup したら Bundle が自動で `"Current"` に戻る
- 一貫性が保証される (snapshot meta が single source of truth)

**欠点**:

- `BundleStatus` 呼出のたびに snapshot meta を file 読込 (cache なし、Phase 2 で改善予定)
- Bundle 数 × 参照 snapshot 数の file I/O が走る

これは「**読込頻度 < 書込頻度** であれば最適」な設計判断。Bundle status は監査時のみ確認、
snapshot lifecycle 変更は稀、というユースケースに合致する。

## Source Lifecycle Event の 4 種 (仕様書 §4.2.1)

| Event | 例 | Bundle 影響 | 実装 |
|---|---|---|---|
| `VersionedUpdate` | arXiv v2 → v3 | `"Stale"` | `SourceVaultMarkSnapshotStale` / `SourceVaultRefreshSnapshot` |
| `Retraction` | 論文公式取り下げ | `"Invalidated"` | `SourceVaultMarkSnapshotInvalidated` |
| `SourceDeletion` | URL 404 | (Phase 2 で `"NeedsReview"`) | `SourceVaultSourceEventAppend` (手動) |
| `SchemaChange` | API 形式変更 | (Phase 2 で `"Frozen"`) | `SourceVaultSourceEventAppend` (手動) |

Phase 1 では **VersionedUpdate と Retraction を自動化** し、SourceDeletion / SchemaChange は
手動 event 記録のみ。これらが Bundle Status に影響するのは Phase 2 で実装。

## events/source-events.jsonl の形式

```json
{"EventId":"evt-1747625300000-a1b2c3","EventType":"VersionedUpdate","SourceId":"src-arxiv-1706.03762","OldSnapshotId":"snap-sha256-cd...","NewSnapshotId":"snap-sha256-xy...","Reason":"arXiv v2 has been released","Timestamp":"2026-05-19T...","DiffSummary":{"AddedPages":2,"RemovedPages":0,"ChangedPages":3,"UnchangedPages":10}}
```

- **append-only JSONL** (Stage 5 と同じパターン)
- 1 event 1 行
- `iSanitizeForJSON` を必ず通す (`Missing[]` 等の対応)
- 読込は `ReadByteArray` + `ByteArrayToString` + `StringSplit` 経路 (罠 #20)

`SourceVaultSourceEvents` は filter option (`SourceId` / `SnapshotId` / `EventType`) で全件読込
+ in-memory filter。**Phase 2 で by-source / by-type インデックスを追加** すれば O(filter hit)
に高速化可能。

## Page Hash Diff の実装

Stage 4B で `page-hashes.json` が `<PrivateVault>/parsed/by-snap/<snapshotId>/page-hashes.json`
に保存されている (page 番号 → hash の Association)。

```mathematica
iComputePageHashDiff[hashes1_Association, hashes2_Association] :=
  Module[{keys1, keys2, common, added, removed, changed = {}, unchanged = {}},
    keys1 = Keys[hashes1];
    keys2 = Keys[hashes2];
    common = Intersection[keys1, keys2];
    added = Complement[keys2, keys1];       (* v2 にしかない *)
    removed = Complement[keys1, keys2];     (* v1 にしかない *)
    Scan[Function[k,
      Module[{h1, h2},
        h1 = Lookup[hashes1, k, ""];
        h2 = Lookup[hashes2, k, ""];
        If[h1 === h2,
          AppendTo[unchanged, k],
          AppendTo[changed, k]]
      ]], common];
    ...
  ];
```

**ポイント**:

- JSON parse 結果は **キーが String** (page 番号も `"1"`, `"2"`, ...)。`ToExpression` で `Integer`
  化してから Sort して返す
- 結果は **set/dict diff の標準形**: `Added` / `Removed` / `Changed` / `Unchanged`
- equation block 単位の diff は Phase 2 (現状は page 単位のみ)

## RefreshSnapshot — 高レベル refresh API の合成

```mathematica
SourceVaultRefreshSnapshot[oldSnapId, newSnapId, reason] :=
  Module[{diff, updateResult, eventResult, oldMeta, sourceId},
    (* 1. diff 計算 (page hashes がない場合は失敗するが続行) *)
    diff = Quiet[SourceVaultDiffVersions[oldSnapId, newSnapId]];

    (* 2. 旧 snapshot を Stale + SupersededBy 設定 *)
    iUpdateSnapshotLifecycle[oldSnapId, "Stale",
      <|"SupersededBy" -> newSnapId|>];

    (* 3. event 記録 (DiffSummary 込み) *)
    iAppendSourceEvent[<|
      "EventType" -> "VersionedUpdate",
      "SourceId" -> sourceId,
      "OldSnapshotId" -> oldSnapId,
      "NewSnapshotId" -> newSnapId,
      "Reason" -> reason,
      "DiffSummary" -> <|"AddedPages" -> _, ...|>
    |>];
    ...
  ];
```

3 ステップを atomic に扱う API だが、**Phase 1 では真の atomicity は保証していない** 
(Step 2 と Step 3 の間に kernel crash したら inconsistent)。Phase 2 で transactional write を
検討。

## SourceVaultBundlesForSnapshot — 影響範囲の可視化

```mathematica
SourceVaultBundlesForSnapshot[snapshotId_String] :=
  Module[{ids, hits = {}},
    ids = SourceVaultBundleList[];                  (* 全 bundle id *)
    Scan[Function[bid,
      Module[{b, sources, snapshotIds},
        b = iBundleLoad[bid];
        sources = Lookup[b, "Sources", {}];
        snapshotIds = Cases[sources, a_Association :> Lookup[a, "SnapshotId", ""]];
        If[MemberQ[snapshotIds, snapshotId],
          AppendTo[hits, bid]]
      ]], ids];
    hits
  ];
```

**現状は線形スキャン** (Bundle 数 × Sources 数 の比較)。1000 件規模なら問題ないが、それ以上は
Phase 2 で逆引きインデックスを作る。Stage 6c Phase 2 の双方向リンクと統合。

## 罠カタログ対応 (Stage 8 実装で踏んだもの)

| # | 罠 | 状況 |
|---|---|---|
| #11 | `\uXXXX` 文字列リテラル | **295 件混入** → Python re.sub で一括修正 (Stage 6c の 72 件を超える失敗)。新規コード追加前に grep チェックを習慣化すべき |
| #15 | Map + Function + Return | `iComputePageHashDiff` の Scan + Function は Return 未使用、OK |
| #16 | Quiet@Check | 全箇所 `Quiet[expr]` 単独 |
| #20 | Windows `ReadList` | `iLoadSourceEvents` も `ReadByteArray` + `ByteArrayToString` + `StringSplit` 経路 |

**教訓**: 同じ罠 #11 を Stage 6c (72 件) → Stage 8 (295 件) と踏み続けた。**新規コードを書く
前に「Wolfram の文字列リテラル内の Unicode は `\:XXXX` 一択」を最初に思い出す** 必要がある。
今回からは新規コード追加直後に `grep '\\u[0-9a-fA-F]\{4\}' SourceVault.wl` を必須化。

## Phase 1 (今) の制約

- diff は page hash レベルのみ (equation block / table / claim 単位は未対応)
- 自動 fetch (arXiv 定期 refresh) は network が必要なので未実装
- event log を Bundle Status 計算で参照していない (Lifecycle のみ)
- `SourceVaultBundlesForSnapshot` は線形スキャン
- atomicity は保証されない (transactional write は Phase 2)

## Phase 2 / Phase 3 ロードマップ

**Phase 2**:

- **claim-level diff**: `SourceVaultDiffClaims[v1, v2, topic, schema]` — Stage 5 の claim を再抽出して `ContentHash` 比較
- event log を Bundle Status 計算で参照:
  - `SourceDeletion` event あり → bundle `"NeedsReview"`
  - `SchemaChange` event あり → bundle `"Frozen"`
- 自動 fetch: `SourceVaultRefresh[sourceRef]` で arXiv abs URL を叩いて latest version 検出
- 双方向リンク cache (Bundle 検索 O(1) 化、Stage 6c Phase 2 と統合)
- transactional write (RefreshSnapshot の atomicity)

**Phase 3**:

- **contradiction 検出** (§12.3): 同じ subject/predicate に異なる object → bundle 自動 `"NeedsReview"` + `contradictions.md` 生成
- **equation block hash** — TeX/MathML 単位の diff (§7.5)
- Petri net 化 (Stage 7 と統合)

## チェックリスト

- [ ] `iSanitizeForJSON` を event append 前に必ず呼ぶ
- [ ] `iEnsureRoots[]` を全 Stage 8 public API の冒頭で呼ぶ
- [ ] page hash JSON のキーは String なので `ToExpression` で Integer 化してから Sort
- [ ] `\u` ではなく `\:` で Unicode 文字エスケープ (罠 #11、**Stage 6c+8 で踏み続けたので最優先**)
- [ ] event log 読み込みは `ReadByteArray` 経路 (罠 #20)
- [ ] RefreshSnapshot は SupersededBy を必ず設定
- [ ] snapshot lifecycle 変更後に Bundle Status を呼ぶと自動 stale 化を確認

## 仕様書との対応

| 仕様書節 | Phase 1 実装状況 |
|---|---|
| §4.2.1 Source lifecycle events | ✓ 4 種 event 全対応 (VersionedUpdate/Retraction は自動、SourceDeletion/SchemaChange は手動 append) |
| §5.2 Refresh (`SourceVaultRefresh`) | △ `SourceVaultRefreshSnapshot[old, new, reason]` のみ。`SourceVaultRefresh[sourceRef]` (自動 fetch) は Phase 2 |
| §5.3 Status (`SourceVaultDiffVersions`) | ✓ page hash diff (Added/Removed/Changed/Unchanged) |
| §7.4 arXiv 更新時の扱い | △ step 1 (新 snapshot 保存) は Stage 1.5、step 2-4 (diff + bundle status 更新) は Stage 8、step 5 (Orchestrator 連携) は Phase 2 |
| §7.5 バージョン差分の単位 | △ PDF file hash / page text hash は ✓、equation block / claim 単位は Phase 2/3 |
| §11.4 Refresh net | × Petri net 化は Stage 7 完了後 (Phase 2) |
| §12.3 contradiction 検出 | × Phase 3 |
