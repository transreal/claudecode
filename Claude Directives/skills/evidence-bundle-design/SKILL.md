---
name: evidence-bundle-design
description: |
  SourceVault.wl Stage 6c の Evidence Bundle 設計。
  生成物 (.wl/.md/.tex/.nb 等) が依存した source/snapshot/claim を bundle として記録、
  snapshot LifecycleStatus 集約による自動 stale 検出、手動 Invalidate の永続化、
  bundles/<bundleId>.json による 1 bundle 1 ファイル設計、
  Status 計算の優先順位 (Manual > Invalidated > NeedsReview > Stale > Current)、
  Phase 2/3 (階層集約・hash-based stale・contradiction 検出) への伏線。
  仕様書 §4.6/§5.7/§12.2/§17.5 の最小実装。
---

# Evidence Bundle 設計 (Stage 6c)

「ある生成物 (例: simulation.wl) は、どの論文の page 3-4 のどの claim に依存しているか」を
記録し、source が更新されたら生成物の stale を自動検出する仕組み。

## なぜ Bundle が必要か

LLM が生成した `simulation.wl` を 6 ヶ月後に見直したら…

- どの論文の v1 を見て書いたか覚えていない
- v3 が出てパラメータが変わっているのに気付かない
- 同じ問題を扱う別 claim と矛盾しているのに監査できない

これらを **生成物単位で記録** するのが Evidence Bundle。仕様書では `*.source-bundle.json` 形式で
生成物と並列に置く案もあるが、Stage 6c Phase 1 では `<PrivateVault>/bundles/<bundleId>.json` の
中央管理に統一。

## データモデル (仕様書 §4.6 ベース)

```mathematica
<|
  "BundleId"           -> "bundle-ODE-Simulation-Example-1747624123456-a1b2c3",
  "Name"               -> "ODE-Simulation-Example",
  "Kind"               -> "SimulationExample" | "LaTeXExport" | "Notebook" | _String,
  "GeneratedAt"        -> "2026-05-19T12:34:56",
  "GeneratedFiles"     -> {"simulation.wl", "simulation.nb"},
  "Sources"            -> {<|"SourceId" -> "src-...", "SnapshotId" -> "snap-..."|>, ...},
  "SourceSpans"        -> {<|"SnapshotId" -> "snap-...", "Locator" -> <|"Pages" -> {3,4}|>, "Role" -> "ExtractionInput"|>, ...},
  "Claims"             -> {"claim-...", ...},
  "Generator"          -> <|"Tool" -> "ClaudeOrchestrator",
                             "WorkflowId" -> "wf-...",
                             "ModelIntent" -> "code-heavy",
                             "ResolvedModel" -> "claude-sonnet-4-6"|>,
  "ManualInvalidation" -> Missing["NotInvalidated"] | <|"Reason" -> _, "InvalidatedAt" -> _|>,
  "ParentBundle"       -> Missing["NoParent"] | _String,
  "ChildBundles"       -> {}
|>
```

**ポイント**:

- `Sources` と `SourceSpans` を別フィールドで持つ — 「使った snapshot 全部」と「具体的にどのページ範囲か」を分離
- `Claims` は string id のみ (lazy reference) — 実体は ClaimStore にある
- `Generator` は workflow trace の最小情報 — Phase 2 で WorkflowRun full integration
- `ManualInvalidation` は手動 invalidate の永続化レコード

## Status 計算の優先順位

`iBundleComputeStatus` の判定順序 (上から優先):

```
1. ManualInvalidation あり          → "Invalidated"
2. いずれかの snapshot が "Invalidated" → "Invalidated"
3. いずれかの snapshot が見つからない (削除済み) → "NeedsReview"
4. いずれかの snapshot が "Stale" / "Frozen" → "Stale"
5. すべて "Current" or 未定義       → "Current"
```

### なぜ手動 Invalidate を最優先にするか

claim 自体に問題があったり、生成コードのバグが見つかった場合、source が `"Current"` であっても
**bundle 単位で「これは信用するな」とマークしたい**。これを snapshot 状態と独立に管理できる。

「やり直し」たい場合は `SourceVaultBundleDelete` → 再 `SourceVaultBundleCreate`。手動 Invalidate を
解除する API は意図的に提供しない (audit trail を残すため)。

### なぜ `"NeedsReview"` を `"Stale"` より優先するか

`"Stale"` は「source が更新されただけ」で、bundle 自体は再現可能。`"NeedsReview"` は
**snapshot 自体が消失** している状態で、再現不能。後者の方が深刻なので優先。

### 実装パターン (Wolfram Language)

```mathematica
iBundleComputeStatus[bundle_Association] :=
  Module[{manualInvalid, sources, snapshotIds, lifecycles,
          affectedSnaps = {}, missingSnaps = {}, finalStatus, reason},
    manualInvalid = Lookup[bundle, "ManualInvalidation", Missing[]];
    If[AssociationQ[manualInvalid],
      Return[<|"Status" -> "Invalidated", "Reason" -> "Manual: " <> ...|>]];
    
    sources = Lookup[bundle, "Sources", {}];
    snapshotIds = Cases[sources, a_Association :> Lookup[a, "SnapshotId", ""]];
    
    lifecycles = Map[Function[snapId,
      Module[{meta, lc},
        meta = iSnapshotMetaLoad[snapId];
        If[!AssociationQ[meta],
          AppendTo[missingSnaps, snapId]; "Missing",
          lc = Lookup[meta, "LifecycleStatus", "Current"];
          If[lc =!= "Current", AppendTo[affectedSnaps, ...]];
          lc]]], snapshotIds];
    
    finalStatus = Which[
      MemberQ[lifecycles, "Invalidated"], "Invalidated",
      Length[missingSnaps] > 0,           "NeedsReview",
      MemberQ[lifecycles, "Stale"] || MemberQ[lifecycles, "Frozen"], "Stale",
      True, "Current"];
    ...
  ];
```

**`Map[Function[..., Module[...]]]` は罠 #15 に該当しない**: Return/Throw を使わず、Module の
最後の式 `lc` が普通に評価されて Map の結果になる。罠 #15 は `Map[Function[..., Return[v, Function]]]`
の組み合わせ。

## 物理ストレージ: 1 bundle = 1 JSON

```
<PrivateVault>/bundles/
  bundle-<safeName>-<timestamp>-<6 hex random>.json
  bundle-Paper-2026-Q2-Notebook-1747624234567-d4e5f6.json
  bundle-ODE-Simulation-Example-1747624123456-a1b2c3.json
  ...
```

**判断理由**:

- ClaimStore は append-only JSONL (高頻度 append) なのに対し、Bundle は **少数の生成物単位** で
  作成頻度が低い → 1 file 1 record の素朴な JSON で良い
- 検索は `FileNames["bundle-*.json", dir]` で全列挙 → 件数が少ないので高速
- 編集競合は基本起こらない (1 つの bundle を同時に複数 process が編集することはない)
- 100 〜 1000 件程度の規模を想定。10 万件なら別ストア検討

## 罠カタログ対応 (Stage 6c 実装で確認)

| # | 罠 | 回避 |
|---|---|---|
| #11 | `\uXXXX` 文字列リテラルが Wolfram でエスケープされない | usage 文字列・コメント内含めて全て `\:XXXX` 形式に統一。Python `re.sub` で一括変換 |
| #15 | `Map[Function[..., Return[...]]]` で `$Failed` | `iBundleComputeStatus` は Return/Throw 使わず Module の最後の式評価で済ます |
| #16 | `Quiet@Check[expr, $Failed]` 偽陰性 | `Quiet[ReadByteArray[...]]` 単独 + 型チェック (`ByteArrayQ`) |
| #20 | `ReadList[..., "String", "UTF-8"]` Windows 空配列 | `iBundleLoad` も `ReadByteArray` + `ByteArrayToString` + `ImportString[..., "RawJSON"]` 経路 |

**注意**: Stage 6c 実装中に **`\u` を 72 件追加してしまった**ことが発覚。usage 文字列内の例示
(`"\u4f8b: ..."` のつもり) とコメント内 (`Sources \u306e\u5404 ...`) で混入。Wolfram の文字列
リテラル内では `\u4f8b` は **そのまま 6 文字** として保存されて、表示が `\u4f8b:` になる。
正しくは `\:4f8b` (= "例")。

**教訓**: Wolfram で日本語/Unicode 文字を string literal に入れるときは、**`\:XXXX` 形式を**
**常に使う**。Python のエスケープ感覚で `\u` を書かない。

## Phase 1 (今) の制約

- 単一 bundle の CRUD + status 計算のみ
- 親子 bundle は **保存はするが集約計算は未実装** (フィールドだけ予約)
- claim/source は文字列 ID のみで参照 (lazy reference、検証なし)
- `iBundleComputeStatus` は毎回 snapshot meta を file から読む (cache なし、1000 件規模で遅くなる可能性)

## Phase 2 / Phase 3 ロードマップ

**Phase 2**:

- 階層 bundle の status 集約 (`"AggregatedFromChildren"` — 子 bundle の status を集計)
- 双方向リンク (`SourceVaultBundlesForClaim[claimId]`, `BundlesForSource[sourceId]`)
- WorkflowRun 自動連携 (ClaudeOrchestrator が workflow 終了時に自動 bundle 生成)
- Bundle status の cache (file mtime ベース invalidation)

**Phase 3 (Stage 8 領域と重なる)**:

- hash-based stale 検出 (§12.2):
  - parsed text hash の変化 → bundle 自動 stale
  - extractor prompt hash の変化 → 当該 claim を使った bundle が stale
  - compiled registry と seed の乖離
- contradiction 検出 (§12.3): 同じ subject/predicate に異なる object の claim 検出 →
  bundle 自動 `"NeedsReview"` + `contradictions.md` への追記

## チェックリスト

- [ ] BundleId は `bundle-<safeName>-<timestamp>-<rnd>` パターン
- [ ] `iSanitizeForJSON` を save 前に必ず呼ぶ
- [ ] `iEnsureRoots[]` を全 public API の冒頭で呼ぶ
- [ ] Status 計算は ManualInvalidation 最優先 → snapshot lifecycle 集約 → Current
- [ ] 手動 Invalidate を解除する API は提供しない (audit trail)
- [ ] `\u` ではなく `\:` で Unicode 文字エスケープ (罠 #11)
- [ ] JSON 読み込みは `ReadByteArray` + `ByteArrayToString` 経路 (罠 #20)

## 仕様書との対応

| 仕様書節 | Phase 1 実装状況 |
|---|---|
| §4.6 Evidence Bundle データモデル | ✓ 主要フィールド全実装 (Notebook 階層は Phase 2) |
| §5.7 公開 API (Create/Status/Invalidate) | ✓ + Get/List/Delete 追加 |
| §8.4 Evidence bundle 性質 | ✓ 監査・stale 判定が中心 |
| §12.2 stale bundle 検出 | △ snapshot lifecycle のみ。hash-based は Phase 3 |
| §17.5 生成物の stale 判定例 | ✓ `SourceVaultBundleStatus` で Reason 返却 |
| §22.3 GeneratedArtifact record | △ Phase 1 では Generator field のみ。full integration は Phase 2 |
| §25.7 EvidenceBundle と WorkflowRun の関係 | △ DerivedFrom フィールドは予約のみ。完全連携は Phase 2 |
