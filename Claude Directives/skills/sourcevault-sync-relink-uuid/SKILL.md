---
name: sourcevault-sync-relink-uuid
description: |
  SourceVault.wl の notebook source 鮮度管理・移動追跡・UUID 同定の設計
  (2026-05-22 完成、Stage 9 P1 の次フェーズ)。SourceVaultSync (mtime 鮮度トークンで
  Stale な .nb を再 index)、SourceVaultRelinkSources (UUID / 内容ハッシュ / ファイル名の
  3 段照合で移動した notebook を再リンク、シンボリックパス解決で別 PC のパス差を移動と誤検出しない、
  StaleDuplicate 残骸判定)、Notebook UUID 埋め込み (TaggingRules SourceVault>NotebookUUID、
  非破壊、ファイルと一緒に移動)。Use when implementing or modifying notebook source crawling,
  freshness/staleness detection, file-move tracking, re-linking, or notebook UUID embedding
  in SourceVault. notebooks/sync, notebooks/relink ストアの設計を含む。
---

# SourceVault Sync / Relink / UUID 埋め込み (2026-05-22 完成)

notebook を first-class source として扱う SourceVault で、ソースの鮮度を保ち、ファイル移動を追跡し、移動に強い同定キー (UUID) を供給する 3 つの機構。Notebook Management 拡張 (`skills/notebook-management-extraction`) の上に乗る次フェーズ。

## SourceVaultSync — クローラー骨格

巡回して鮮度の落ちた notebook source を再 index する仕組み。公開 API 4 個。

- `SourceVaultSelectSources[opts]` — Scope 配下の .nb を走査し source descriptor 化
- `SourceVaultSyncPlan[opts]` — 各 source の鮮度を判定 (dry-run、副作用なし)。`Fresh` / `Stale` / `Missing` / `NeverIndexed` に分類
- `SourceVaultSync[opts]` — Stale な source を `SourceVaultIndexNotebook` で再 index
- `SourceVaultSyncStatus[]` — 直近 sync の状態 (`sync/last-sync.json`)

設計の核心:

- **鮮度トークン抽象** — `iSVFreshnessToken` がローカルファイルは mtime (`UnixTime`) を返す。web (ETag / Last-Modified / TTL) は `Kind -> "Web"` の枠だけ予約 (`NotImplemented`)。鮮度判定は「現トークン vs 記録済みトークン」の比較
- **PrivacyLevel は単調** — 再 index で snapshot の PrivacyLevel が下がったら、`SourceVaultSetSnapshotPrivacyLevel` で旧値に引き上げ、`PrivacyWarnings` に記録。プライバシーは「下げる方向」に自動変化させない
- **一括同期の安全側既定** — `FallbackToCloud -> "Deny"` が既定。多数ファイルの一括処理でクラウド送信を暗黙に許可しない
- ストア `notebooks/sync/` — `sync-history.jsonl` (append-only) + `last-sync.json`

## SourceVaultRelinkSources — ファイル移動追跡

`OriginalPath` が消えた notebook source の移動先を探して再リンク。`iSVRelinkSources` プレースホルダーを置換 (後方互換エイリアス保持)。

**3 段照合 (信頼度の高い順)**:

1. **埋め込み UUID** — TaggingRules `SourceVault > NotebookUUID`。最も信頼でき、ファイル名・内容が変わっても追跡可能
2. **内容ハッシュ** — `RawContentHash` の完全一致
3. **ファイル名一意一致** — Scope 内に同名ファイルが 1 つだけのとき

設計の核心 (rule 103 に直結):

- **移動判定はシンボリックパス解決ベース** — 「移動したか」は `OriginalPath` の生 `FileExistsQ` でなく、record の `SymbolicPath` を `iSVResolvePath` で現 PC 解決して実在判定する。別 PC のパス差 (`C:\Users\imai_\...` vs `F:\Dropbox\...`) を移動と誤検出しない
- **強い証拠と弱い証拠を分ける** — UUID / 内容ハッシュ一致は自動適用するが、ファイル名一致 (`NameOnly`) は弱い証拠なので `ApplyNameOnly -> True` のときのみ適用。既定はレポートのみ。連番ファイル群 (`計算と自然 01`〜`25`) の誤マッチ防止
- **StaleDuplicate 判定** — マッチ先が既に別の現役 record の指す実ファイルなら、それは「移動」でなく「旧 PC index の残骸」。Relink 開始時に「全現役 record の実ファイルパス集合」(`livePathSet`) を構築し、マッチ先がそこに含まれるかを**実パスで**判定 (NotebookRef のハッシュ衝突を避ける)。`DeleteStale -> True` で残骸 record を削除 (既定 False は非破壊マーク `RelinkStatus -> "StaleDuplicate"`)
- **非破壊** — `DryRun` 既定 `True`。`DryRun -> False` でも旧 record は削除せず `Superseded` マークのみ (`DeleteStale` を除く)
- 戻り値に `ByMethod` (UUID / ContentHash / NameOnly 別件数)、`StaleDuplicateCount`、`StaleDeletedCount`
- ストア `notebooks/relink/relink-log.jsonl`

開発中、`Linked` 判定の早期 return を内側 `Module` に閉じ込めたバグ (罠 #52) で全件が照合ループに流れ `Relinked` が膨張した。修正後は 366 ファイルで `Linked: 365 / Relinked: 0` に収束。

## Notebook UUID 埋め込み機構

Relink の最上位照合キーを供給する基盤。公開 API 3 個。

- `SourceVaultNotebookUUID[path]` — 埋め込み UUID を読む (読み取りのみ)
- `SourceVaultEnsureNotebookUUID[path, opts]` — UUID が無ければ生成して埋め込む。`Force` で再生成
- `SourceVaultEnsureNotebookUUIDFolder[dir, opts]` — folder 一括付与

設計の核心:

- UUID は notebook の **TaggingRules `SourceVault > NotebookUUID`** に保存 (`nbuuid-` + `CreateUUID`)。CloudPublishable と同じ名前空間。Header (Initialization セル) でなく TaggingRules を選ぶことで、ファイル本文を書き換えず非破壊、かつファイルと一緒に移動する
- 書き込みは `NBFileOpen` (`Visible -> False`) → `NBSetTaggingRule` → `NBFileSave` → `NBFileClose`
- `SourceVaultIndexNotebook` の sourceRecord に `SourceUUID` と `SymbolicPath` フィールドを追加 — index 時に埋め込み UUID とシンボリックパスを記録し、Relink の照合・移動判定の基盤データにする
- `EnsureNotebookUUIDFolder` の巨大ファイルは `Skipped` (`Failed` と別カウント) — TaggingRules 書き込みには巨大 notebook を開く必要があるため、サイズ閾値超えはスキップ

運用注意: UUID 付与は notebook の mtime を変えるため、「**UUID 一括付与 → 全件 index → 以降 Sync で安定運用**」の順序で行う。付与直後に Sync を走らせると全件 Stale 判定になる。

## 関連 skills / rules

- `skills/notebook-management-extraction` — このフェーズの土台 (Header / Todo / lint / FindNotebooks)
- `skills/nbaccess-semantic-api` — TaggingRules 書き込み API (NBSetTaggingRule 等)
- `skills/compiled-registry-and-seed` — モデルレジストリの動的更新 (SourceVaultRefreshModelRegistry 等) はこちら
- `rules/103-sourcevault-datastore-safety.md` — データストア書き込み安全規約・シンボリックパス解決
- `skills/wolfram-syntax-pitfalls` — 罠 #52 (内側 Module の早期 return)
