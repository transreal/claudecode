---
description: SourceVault の一覧・検索 API は「連想リストを返す core」と「表を返す View (…View)」の対。ユーザーに見せる一覧は必ず View、後段処理へ渡すのは core。素の Dataset/Grid を手組みしない
paths:
  - "**/SourceVault*.{wl,wls,m,nb}"
---

# 108 — core は連想、表示は View (SourceVault 共通)

**必須**: SourceVault の一覧・検索 API は **core (連想リストを返す)** と **View (`…View`、表を返す)** の対で用意されている。ユーザーへ提示する一覧は必ず View を呼ぶ。core の戻り値をそのまま出力セルに置いたり、素の `Dataset`/`Grid`/`Column` で表を手組みしたりしない (行アクション ▶開く / タイトルクリックの種別別ハンドラが失われる)。自前 `Select` で絞った行リストも `…View[rows]` に渡す。

| core (連想リスト) | View (ユーザー提示用の表) |
|---|---|
| `SourceVaultSummaries[query, opts]` | `SourceVaultSummariesView[query, opts]` / `[rows]` |
| `SourceVaultSources[query, opts]` | `SourceVaultSourcesView[query, opts]` / `[rows]` |
| `SourceVaultArXiv[query, opts]` | `SourceVaultArXivView[query, opts]` / `[rows]` |
| `SourceVaultEagleSummaries[query, opts]` | `SourceVaultEagleSummariesView[query, opts]` / `[rows]` |
| `SourceVaultMailSearchIndex[query, opts]` | `SourceVaultMailSearchIndexView[...]` (rule 106) |

```mathematica
rows = SourceVaultSummaries["可逆計算", "Providers" -> {"sources", "eagle"}];
hit  = Select[rows, Lookup[#, "PrivacyLevel", 1.0] < 0.5 &];   (* 後段処理は core の連想で *)
SourceVaultSummariesView[hit]                                   (* ✅ 提示は View に渡す *)
Dataset[KeyTake[#, {"Title", "Date"}] & /@ hit]                 (* ❌ 手組み禁止 *)
```

## 設計則 (新しい API を足すとき)

- **core**: `List[Association]` を返す純データ関数。`"Limit"` は**データ件数**の意味のみ。UI を返さない。
- **View**: `Grid`/`Dataset`+UI を返す。**一度に描画する行数の上限は View 層だけで掛ける** (`$SourceVaultCatalogViewMaxRows`、`$SourceVaultMailViewMaxRows`、`"MaxRows"` オプション)。行リスト直渡しのオーバーロード `View[rows:{__Association}]` を必ず用意し、`OptionsPattern` 版より**前**に定義する (Association 列が OptionsPattern にマッチしうるため)。
- **privacy**: core は `SourceVaultPrivateResult[rows, pl]`、View は `SourceVaultPrivateView[expr, pl]` (SourceVault_privacy.wl の正準 exit) を通す。
- `"Format" -> "Grid"` は後方互換のための委譲口。新しいコードでは View 関数名を使う。

## 横断検索の行アクション

`SourceVaultSummariesView` の行クリックは種別ごとに正準の表示関数へ飛ぶ (`$iSVRowTitleActions` / `$iSVRowOpenActions`):
arxiv/web/local → `SourceVaultShowSourceSummary`、eagle → `SourceVaultEagleShowSummary`、
**mail → `SourceVaultMailShowBody` (返信・翻訳・アジェンダ操作つきの本文窓)、▶開く → `SourceVaultMailThreadNotebook`**。
新しい provider を足したら**表示アクションも登録する** (低漏洩ヘッダだけのスタブ窓を新設しない)。

## 関連

- `rules/106-mail-list-view-output.md` — メール一覧の View 必須 (always-on)
- `rules/13-prefer-existing-functions.md`
