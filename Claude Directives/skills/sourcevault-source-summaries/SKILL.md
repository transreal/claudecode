---
name: sourcevault-source-summaries
description: |
  SourceVault.wl の ingest 済みソース行 (SourceVaultSources / SourceVaultArXiv) の
  Summary 列を埋める設計 (2026-06-24 実装)。arXiv ソースは ingest 時にアブストラクトを
  arXiv API から取得し $Language へ翻訳して meta["Summary"] に格納する (iIngestURL フック、
  同期/非同期両カバー、TimeConstrained best-effort)。既存ソースは公開 API
  SourceVaultBackfillArXivSummaries[] で backfill。翻訳は cloud LLM (arXiv は公開なので
  PL 0.0)、iSVLooksLikeLLMError ゲートで利用制限/エラー本文の保存を防ぐ、失敗時は原文 fallback。
  Use when implementing or modifying source-row Summary population, arXiv abstract fetch,
  ingest-time enrichment, or summary translation in SourceVault. 表示パスを LLM-free に保つ
  原則と headless $Language 罠を含む。
---

# SourceVault ソース行サマリー (arXiv アブストラクト翻訳) (2026-06-24 実装)

`SourceVaultSources` / `SourceVaultArXiv` の共通行スキーマには `Summary` 列があるが、従来 arXiv ソースでは誰も `meta["Summary"]` を書かず**常に空**だった。この機構は arXiv ソースに「アブストラクトを `$Language` へ翻訳した要約」を持たせる。

土台は `skills/notebook-management-extraction` (notebook の `SourceVaultNotebookSummary`) や `skills/llm-extraction-pipeline` とは別系統で、**ソース行 (source meta) の Summary フィールド**を対象にする点が違う。

## 公開 API

> **core / View 分離 (2026-08-29)**: `SourceVaultSources` / `SourceVaultArXiv` / `SourceVaultSummaries` は **連想リストを返す core**、表示は `…View` (`SourceVaultSourcesView` 等) が担う。行データを LLM/後段処理へ渡すときは core、ユーザーに見せるときは View。表示行数の上限は View 層 (`$SourceVaultCatalogViewMaxRows`)。

- `SourceVaultBackfillArXivSummaries[opts]` — 既存 arXiv ソースのうち Summary 未設定 (または過去の LLM エラー本文) のものに、アブストラクトを取得・翻訳して付与する。ingest フックと同じ `iSVArXivAttachSummary` を共用。
  - Options: `"Force" -> False` (True で既存 Summary も再生成)、`"Model" -> Automatic`、`"Limit" -> Automatic|n` (処理件数の上限、お試し用)
  - 戻り値: `<|"Candidates", "Updated", "AlreadyPresent", "NoAbstract", "Failed", "Language", "Results"|>`

- `SourceVaultBackfillSourceSummaries[opts]` (2026-08-29 追加) — **web / local ソース**用。arXiv のようなアブストラクト API が無いので、**ingest 済み snapshot の本文 (plaintext) を LLM で要約**して `meta["Summary"]` に書く。本体は `iSVSourceAttachSummary`。
  - Options: `"Kind" -> {"web","local"}` (既定。`All` で arxiv も)、`"Sources" -> All|{sourceId...}`、`"Force"`、`"Limit" -> 10`、`"Model" -> Automatic`、`"MaxChars" -> Automatic` (`$SourceVaultSourceSummaryMaxChars`=12000)、`"TimeoutSeconds" -> 120`
  - 戻り値: `<|"Candidates", "Updated", "AlreadyPresent", "NoText", "Quarantined", "Failed", "Remaining", "Language", "Results"|>`
  - **モデルは行の PrivacyLevel で決まる** (`iCallSummaryLLM`: `PL > 0.5` → `$ClaudePrivateModel` = ローカル、以下 → クラウド CLI)。**PL 不明は fail-safe で 1.0 = ローカル**。
  - **本文は UNTRUSTED データ境界で包んでから渡す** (`SourceVaultWrapUntrustedText` へ弱結合、未ロード時は内蔵 preamble)。prescan が quarantined と判定したら **LLM へ渡さず** `Status -> "Quarantined"`。これは webingest `SourceVaultSummarizeText` の既定 `QuarantinePolicy -> "Block"` と同方針。
  - 本文抽出は `iExtractTextPages` (pdf/html/txt/md)。`TimeConstrained` で `"TimeoutSeconds"` を上限にし、超えたら `NoText` (巨大 PDF で止めない)。
  - 書き込むキー: `Summary` / `SummarySource`(`"DocumentText"`) / `SummaryLanguage` / `SummaryModel` / `SummaryInputChars` / `SummaryFetchedAt`。
  - テスト: `test codes/SourceVault_sourcesummary_backfill_test.wls` (meta store / 本文抽出 / `iCallSummaryLLM` を Block で差し替える決定的テスト。実 LLM 不要)。
  - **罠**: `iCallSummaryLLM` は **`SourceVault`** 公開文脈にピン留めされた単一シンボル (SourceVault.wl L1245 の設計メモ: スタブ差し替えを確実に効かせるため)。テストで `SourceVault`Private`iCallSummaryLLM` を Block しても効かない。

## ingest 自動付与 (今後の動作)

- フックは `iIngestURL` の `iLockRelease[lockInfo]` 直後に置く (`isArXivHint && StringQ[arXivId]` のとき)。lock を**解放してから** network + LLM を呼ぶ。
- **同期・非同期の両方をカバー**: 非同期経路 (`iIngestURLAsync`) は DAG handler 内で `iIngestURL` を `Asynchronous -> False` で再入するので、フックを `iIngestURL` 1 箇所に置けば両方通る (非同期では翻訳が background DAG ノード内で走る)。
- `TimeConstrained[..., 90, Null]` + `Quiet@Check[..., Null]` で囲む。**翻訳が失敗・タイムアウトしても ingest は成功扱い** (Summary が空になるだけ)。網羅外は早期 return の `AlreadyCurrent` (= 既存ソースの再 ingest) で、これは backfill が拾う。

## 内部関数 (構成)

- `iSVArXivMetaFetchBatch[ids]` — arXiv API (`export.arxiv.org`) の `<entry>` から **`<summary>` を `"Abstract"` として抽出** (従来は Title/Authors/Published のみ)。session 内 failed-cache (`$iSVArXivFetchFailed`) への記録は従来どおりだが、その**読み**は `iSVSourcesEnrich` の needIds フィルタだけ。`iSVArXivMetaFetchBatch` 自体は毎回 fetch するので attach/backfill は stale-skip しない。
- `iSVEffectiveLang[]` — `$Language` から `"Japanese"` か `"English"` の 2 値 (`iL` と同じ判定)。
- `iSVTranslateAbstract[abstract, model]` — `$Language` へ翻訳。目標が English なら arXiv abstract は元々英語なので**原文そのまま返す** (LLM 往復省略)。それ以外は `iCallSummaryLLM[prompt, model, 0.0]`。戻り値 `<|"Text", "Translated", "Lang"|>`。翻訳プロンプトは短く安定 (「自然な〈言語〉へ・常体・訳文のみ出力」) なので `.wl` 内に保持 (rule 02 の「半年後にも有効か」=Yes。`iBuildNotebookSummaryPrompt` と同じ前例)。
- `iSVArXivAttachSummary[sourceId, arXivId, model, force]` — attach 本体。meta を再 load → 既存正常 Summary があり `!force` なら `AlreadyPresent` → abstract 取得 → 翻訳 → `meta` に書き戻し → API entry のついでに欠落メタ (Title/Authors/Published) も補完。戻り値 `"OK"|"AlreadyPresent"|"NoAbstract"|"Failed"`。

meta に書くフィールド: `Summary` / `SummarySource` (`"arXivAbstract"`) / `SummaryLanguage` / `SummaryTranslated` / `SummaryFetchedAt`。

## 設計の核心

- **翻訳は cloud LLM で可**。arXiv は公開 web データなので `PrivacyLevel 0.0` (< 0.5 = 機密閾値未満)。`iCallSummaryLLM` に `0.0` を渡すと model が `Automatic` (CLI cloud) に解決される。プライバシー上 cloud 送信して問題ないデータ。
- **エラーゲートを必ず通す**。`iCallSummaryLLM` は内部で `iSVLooksLikeLLMError` を呼び、利用制限本文 (`"session limit"` 等) や HTTP エラー本文を `Status -> "Failed"` に落とす。これにより**エラー文が要約として保存されない**。新しい要約保存経路を足すときは必ずこのゲートを通すこと (memory: サマリーLLMエラー検出ゲート / `rules/90-api-error-handling.md` と同根)。backfill の対象判定でも `iSVLooksLikeLLMError[既存Summary]` を「未設定扱い」に含め、過去に混入したエラー文を再生成で上書きする。
  - **実地で 529 がすり抜けた (2026-06-25)**: 翻訳 LLM が `"API Error: 529 Overloaded. This is a server-side issue, usually ..."` を正常応答として返し要約保存された。当初ゲートは `"Error:"` 前置 / `StatusCode=` しか見ておらず `"API Error:"` 前置・`Overloaded` を取りこぼした。`iSVLooksLikeLLMError` に `"API Error"` 前置 / `overloaded` / `server-side issue` / `rate_limit` / HTTP 4xx-5xx (429/500/502/503/504/529) + error-keyword の regex を追加。ゲート補強後は plain `SourceVaultBackfillArXivSummaries[]` (Force 不要) で当該行が候補化され再翻訳される。
- **失敗時は原文 fallback**。LLM 未ロード・エラー・空のときは翻訳済みでなく**原文アブストラクト**を `Summary` に入れ (`SummaryTranslated -> False`)、空欄よりはマシな状態にする。
- **表示パスは LLM-free に保つ**。`iSVSourcesEnrich` / `iSVSourceEnrichOne` (= `SourceVaultSources` 行取得時に走る) は network のみのメタ補完 (Title/Authors/Published) に留め、**翻訳 (LLM) を入れない**。重い翻訳は ingest フックと backfill でだけ行う。一覧表示が LLM 呼び出しで遅く・不安定になるのを防ぐ。

## headless $Language 罠 (運用上の最重要点)

backfill は**必ず FrontEnd セッション (または `$Language = "Japanese"` を明示設定したカーネル) で実行する**。`wolframscript` などの headless カーネルは `$Language` 既定が `"English"` のため、`iSVEffectiveLang[]` が `"English"` を返し、**翻訳されず英語原文のアブストラクトがそのまま格納される**。これは `skills`/memory の「背景カーネルの $Language 継承」と同根 (背景ドライバには `$Language` を config 経由で渡して先頭設定する)。

```mathematica
(* FE セッションで *)
Needs["SourceVault`"]   (* 既ロードなら Get["SourceVault`"] で再読込 *)
SourceVaultBackfillArXivSummaries[]            (* Summary 未設定の arXiv を一括付与 *)
SourceVaultArXivView[]                          (* 付与結果を確認 (View = 表) *)
```

## 編集可能サマリーノート (Eagle と同じ枠組み) (2026-06-25 追加)

`SourceVaultSourcesView` / `SourceVaultArXivView` / `SourceVaultSummariesView` の表で**タイトルまたはサマリー preview をクリックすると、要約を編集可能なノートブックで開く**。Eagle の `SourceVaultEagleShowSummary` と同一の枠組みを arXiv / web / local の全 ingest ソースに展開したもの。

- 公開 `SourceVaultShowSourceSummary[sourceId, "Fresh" -> False]`。挙動:
  1. 保存済みノート (`iSVSourceSummaryNoteFile[sourceId]`) があればそれを `NotebookOpen` (= **ユーザー追記が正本**)。
  2. 無ければ record (Title/著者/出版/URL/要約/PL/要約言語) から `CreateDocument` で生成し、末尾に保存ボタンを置く。
- 保存ボタンのラベルは Eagle と同一: 「このノートを保存する (補足を追記したら押す。以後この保存版が開きます)」。実体は `Button[..., NotebookSave[ButtonNotebook[], p], Method -> "Queued"]` で、`p` は `With` でリテラル埋め込み (再オープン後も動くよう System` シンボルのみで構成)。
- 保存先 `iSVSourceNotesDir[]` = `<PrivateVault>/sources/summary-notes/`。ファイル名 `<安全名>_<sourceId>.nb` (`iSVSourceNoteSafeName` で Windows 不正文字を `_` 化・60 字 cap)。`iSVSourceSummaryNoteFile` は `FileNames["*"<>sourceId<>".nb", dir]` で照合 (Eagle と同じ id 末尾アンカー)。
- スタイルは公開 `$SourceVaultSummaryNotebookStyle` (既定 `"SourceVault default.nb"`、Eagle サマリーノートと同じ)。SourceVault.wl コアは eagle ファイルに依存しないよう**自前の style シンボル**を持つ。

**配線**: グリッド `iSVRenderRowsGrid` の既定タイトルアクションを `iSVSourceShowInfo` (旧: meta Dataset 窓) から `SourceVaultShowSourceSummary` に変更し、サマリー preview セルも同じ `act` を呼ぶ Button にした。`$iSVRowTitleActions` に登録済みの kind (`eagle` / `mail` / `workflow`) は各自のアクションを保持し影響を受けない。default (Automatic) が効くのは `arxiv` / `web` / `local` のみ ＝ 今回の対象そのもの。

**設計上の注意**:
- 自動サマリーの有無に関わらず枠組みは働く。web/local は自動要約が無くても placeholder + ユーザー追記で同じ編集ノートになる (Eagle で summary 未生成の item と同じ)。
- 編集ノートは record の `Summary` を**書き戻さない** (Eagle と同じ。保存版 .nb がそのまま正本)。一覧の Summary 列テキストは record 由来のまま。
- 旧 `iSVSourceShowInfo` (meta Dataset 窓) は定義は残るが既定からは外れた。フル meta は `SourceVaultStatus[id]` 等で参照。

## 関連 skills / rules

- `skills/notebook-management-extraction` — notebook 側の `SourceVaultNotebookSummary` (別系統。あちらは notebook 本文の LLM 要約、こちらは source 行の arXiv abstract 翻訳)
- `skills/llm-extraction-pipeline` — LLM 構造化抽出の prompt/parse パターン (要約系の一般則)
- `rules/90-api-error-handling.md` — API エラー時にデータ (要約含む) を保存しない原則。`iSVLooksLikeLLMError` ゲートの根拠
- `rules/103-sourcevault-datastore-safety.md` — source meta 書き込み安全規約 (atomic write、破壊操作の DryRun)
- memory: `arxiv-summary-translate-ingest` / `sourcevault-summary-llm-error-gate` / `background-kernel-language-inherit`
