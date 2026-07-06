---
name: sourcevault-packageapi-narrowing
description: Use when locating a function, option, symbol, or "where is X handled/implemented" inside this system's own packages (SourceVault, ClaudeOrchestrator, ClaudeRuntime, NBAccess, claudecode, github) — i.e. the initial narrowing step of a code-investigation task, before reading files. Prefer SourceVault MCP packageapi mining over a broad full-text rg sweep of $packageDirectory. Covers concept-token query discipline, sourcevault_get view=body, freshness (StaleDocs) handling, filters.packages scoping, and the bounded grep fallback.
---

# SourceVault packageapi で対象を絞り込む（MCP first, grep bounded fallback）

このシステム自身のパッケージ（SourceVault / ClaudeOrchestrator / ClaudeRuntime / NBAccess /
claudecode / github）の中で「どの関数か」「どこで X を扱っているか」を探す局面の手順。
`$packageDirectory` 全体への広い `rg` から始めない。

## なぜ

- 広い全文検索（`rg --files` → `rg -n "SourceVault|MCP|log|ingest|..."`）は
  `bak\` / `test codes\` / `_info\history\` / `GithubRepositories\`（ミラー重複）/
  無関係パッケージまで拾い、初動の token・往復・判断負荷が膨らむ（実測で 1 万件超のヒット）。
- `sourcevault_search kinds=["packageapi"]` は各パッケージの `api*.md` を**関数粒度**で索引し、
  signature / summary / package / freshness 付きの候補を返す。`sv://packageapi/...` は PublicDoc で
  body 取得も grant 不要。**ただし自然文やキーワード束クエリでは精度が落ちる**ため、下記の
  クエリ規律を守る。

## 手順

1. **可用性確認は 1 回だけ**: セッション最初に `sourcevault_catalog` で `packageapi` が
   available か確認する（毎回は呼ばない）。
2. **1 呼び出し 1 概念トークンで反復**: `sourcevault_search kinds=["packageapi"]` を、
   `ingest` / `rollup` / `adapter` / `mcp` / `runtime` / `machine` / `snapshot` / `privacy` /
   `log` のような**単一概念トークン**で引く。合計 **3〜6 トークンまで**、各 `limit` は 5〜10。
   - 自然文（"where are the logs handled"）や `A|B|C` の交替束を 1 クエリに詰めない。
   - 同一クエリの結果はセッション内で使い回す（再問い合わせしない）。
3. **package を絞れるなら `filters.packages`**: 例
   `filters.packages=["SourceVault","ClaudeOrchestrator"]`。canonical 名
   （`SourceVault` / `ClaudeOrchestrator` / `ClaudeRuntime` / `NBAccess` / `claudecode` / `github`）で渡す。
4. **本文確定は `sourcevault_get view=body|contract|guided`**（packageapi は grant 不要）で
   上位候補の URI / Symbol を取得する。`sourcevault_get` が tool として見えないクライアントでは、
   search 結果の snippet / signature で候補を絞り、その file を Read へ移る。
5. **鮮度を見る**: 結果の `Freshness` が `StaleDocs`（api ドキュメントがソースより古い可能性）の候補は、
   採用前に当該実装ファイルを短く確認する。`Fresh` は原則そのまま一次候補にしてよい。
6. **全文検索は fallback、境界を切る**: 次のいずれかのときだけ `rg` に落ちる —
   packageapi が扱わないもの（ソース本文の実装詳細、on-disk のログ/パス、未文書化シンボル）、
   候補 0 件、`StaleDocs` が上位を占める、MCP 応答が所定秒数を超える。
   フォールバックは広く撫でず `rg -g "SourceVault*.wl" -g "ClaudeOrchestrator*.wl"` のように
   **glob で境界を切る**（`bak\` / `test codes\` / `GithubRepositories\` を避ける）。

## 注意（性能の但し書き）

- `sourcevault_search` は 1 回あたり数十秒〜約 2 分かかる場合がある（環境・kernel 状態・index rebuild 依存）。
  本手順の主効果は **件数削減・往復（推論ステップ）削減・context 汚染回避**であって「常に wall time が速い」ではない。
  だから手順 6 のフォールバック条件（0 件 / StaleDocs 上位 / タイムアウト）を必ず併記して使う。
- これは「**コードベースの API を絞り込む**」手順。「**過去の実行ログを引く**」用途とは別レイヤ
  （後者は取込済みコンテンツ索引 `kinds=["search"]` や将来の `llmlog` adapter の話）。

## 対象外・非適用

- 外部（非本システム）ライブラリや、Wolfram 標準関数の探索には使わない（それは通常の検索・ドキュメントで）。
- packageapi は `api*.md` のみを索引する。未文書化シンボルや「どのファイルの何行か」は grep / Read が要る。

## 関連

- 設計・比較の根拠: `ドキュメント/sourcevault_mining_narrowing_vs_fulltext_proposal_v0_1.md`
- MCP 露出仕様: `SourceVault_info/docs/api_packageapi.md`
- ランカー実装: `SourceVault_packageapi.wl`（`SourceVaultPackageApiSearch`）
- MCP adapter: `SourceVault_mcp.wl`（`iSVPackageApiAdapterSearch`）
