---
paths:
  - "**/SourceVault*.wl"
  - "**/sourcevault*.md"
---

# SourceVault.wl 開発の前提

## バージョンと依存

- 現行バージョン: **Stage 9 P1 完成 + P1 拡張 Steps 1-8 完成 + 次フェーズ (Sync / Relink / モデルレジストリ / UUID) 完成** (`v2026-05-22-stage-9-p1-next-phase`)
  - P1 拡張 Steps 1-8 = CloudPublishable / パレット / UpcomingSchedule / 自然言語ルーター / クロス PC パス正規化 / 概要スキーマ化制約 / 数値 PrivacyLevel + 承認ゲート / 再起動後高速化
  - 次フェーズ = SourceVaultSync クローラー骨格 / SourceVaultRelinkSources ファイル移動追跡 / モデルレジストリ動的更新 / Notebook UUID 埋め込み機構 / 小さな残課題 2 件 (UpcomingSchedule クロス PC リンク + SourceVaultSetSnapshotPrivacyLevel)
- **claudecode.wl は Phase 35 以降が必須** (`v2026-05-18-phase-35-claudecode-cli-vision`)
  - Phase 35 で `iClaudeQueryBgAPIMultimodal` に CLI リダイレクトが追加され、`$ClaudeModel = {"claudecode", ...}` のままで vision OCR / multimodal が無課金で動作する
  - Phase 35 未満では Stage 4C ClaudeVision backend は `"Error: multimodal API は現在 Anthropic のみ..."` で失敗する
- ファイル規模 (次フェーズ完了時点): NBAccess.wl **6946 行** / claudecode.wl **28187 行** / SourceVault.wl **10734 行**
- **完成済み Stage**: 1 (ingest) / 2 (NBAccess hook P1-P4) / 3 (Context) / 4A (URL/arXiv) / 4B (page extraction + cache) / 4C (3 OCR backends) / 5 (Claim extraction) / 6a (Claim dedup + Compact) / 6c (Evidence Bundle Phase 1) / 8 (vN diff + lifecycle) / 6d (NBAuthorize 2-stage) / 6b (Compiled Registry) / 9 P0 (Notebook Management) / 9 P1 (NBAccess semantic API + SourceVaultMarkTodo + mtime cache + MakeExpression first) / 9 P1 拡張 Steps 1-8 (UpcomingSchedule + PrivacyLevel 体系 + 再起動後高速化) / **次フェーズ (Sync 骨格 + Relink + モデルレジストリ + UUID 埋め込み)**

## ストレージレイアウト

- ClaimStore root: `<PrivateVault>/claims/`
  - `claims.jsonl` (master、append-only、`SourceVaultClaimStoreCompact` で uniq 化可能)
  - `by-topic/<topic>.jsonl`
  - `by-source/<sourceId>.jsonl`
  - `*.bak.<timestamp>` (Compact 時の自動 backup、手動掃除)
- **BundleStore root: `<PrivateVault>/bundles/`**
  - `bundle-<safeName>-<timestamp>-<rnd>.json` (1 bundle = 1 ファイル)
  - 手動 invalidate は `"ManualInvalidation"` フィールドに永続化
- **EventLog: `<PrivateVault>/events/source-events.jsonl`** (Stage 8)
  - append-only JSONL、Stage 5/6a と同じ ReadByteArray 経路で読込
- **Seed/Compiled Registry** (Stage 6b)
  - `<PrivateVault>/seeds/<topic>-seed.json` (bootstrap 用)
  - `<PrivateVault>/compiled/public/<topic>.json` (production)
  - `<PrivateVault>/compiled/private/<topic>.json` (user routing override)
- **Notebook Index** (Stage 9 P0)
  - `<PrivateVault>/notebooks/sources/nb-src-<hash16>.json` (NotebookSourceRecord、シンボリックパスのハッシュ ID)
  - `<PrivateVault>/notebooks/snapshots/snap-sha256-<hash>.json`
  - `<PrivateVault>/notebooks/todos/by-notebook/nb-src-<...>.jsonl`
  - `<PrivateVault>/notebooks/review/overdue.jsonl` (append-only)
  - `<PrivateVault>/notebooks/lint/notebook-lint.jsonl` (append-only)
  - `<PrivateVault>/notebooks/sync/sync-history.jsonl` (append-only、次フェーズ Sync)
  - `<PrivateVault>/notebooks/sync/last-sync.json` (直近 sync 状態、次フェーズ Sync)
  - `<PrivateVault>/notebooks/relink/relink-log.jsonl` (append-only、次フェーズ Relink)
- Page cache: `<PrivateVault>/parsed/by-snap/<snapshotId>/pages/<NNNN>.txt`
- Page hashes: `<PrivateVault>/parsed/by-snap/<snapshotId>/page-hashes.json` (Stage 8 の diff 基盤)
- **`SourceVaultResetStore` の削除対象**: `sources` / `snapshots` / `summaries` / `todos` / `review` / `lint` / `sync` / `relink` の 8 ディレクトリ。**運用開始後は安易な全削除をしない** (rule 103)

## 設計上の必須ルール

- JSONL/JSON append/save 時は **`iSanitizeForJSON` を必ず経由** (Missing[]/DateObject/Symbol を Null/String に変換)。これを通さないと `Missing[]` で `ExportString[..., "RawJSON"]` が `$Failed` を返す
- JSON/JSONL 読み込みは **`ReadByteArray` + `ByteArrayToString` + `StringSplit`** 経路を使う。`ReadList[..., "String", "UTF-8"]` は Windows で空配列を返す (罠 #20)
- ClaimStore / BundleStore / EventLog / Registry 関連の API は冒頭で **`iEnsureRoots[]` を呼ぶ**
- **Claim dedup の scope は by-source ファイル単位**: master 全件読込ではなく、`iLoadClaimHashesForSource[sourceId]` で per-source の hash set
- **Compact の atomic write は `path.tmp` → `RenameFile`** パターン。Windows 用に既存 path は事前 `DeleteFile`
- **Bundle Status 計算の優先順位**: `ManualInvalidation` > snapshot `"Invalidated"` > snapshot 消失 (`"NeedsReview"`) > snapshot `"Stale"/"Frozen"` > すべて `"Current"`
- **Stage 8 連動**: `SourceVaultMarkSnapshotStale` / `Invalidated` / `RefreshSnapshot` は snapshot meta を書き換え + event log append の **2 段操作**。Bundle 側は lazy で再評価
- **Stage 6d 2 段階 authorization**: `SourceVaultExtract` は sendDecision + persistDecision の 2 段。Decision = Permit/Screen で続行、RequireApproval / Deny で早期 return。`"AuthorizationCheck" -> False` で skip 可能
- **Stage 6b Registry 優先順位**: `compiled/<channel>/<topic>.json` → seed fallback。複数 match なら Availability > Freshness > Class で sort。`AllowSeed -> False` で seed 禁止可能。`ClaudeResolveModel[provider, intent]` は `SourceVaultResolve["Model", ...]` の wrapper (旧 WikiDBResolveModel 置換)
- **Stage 9 Notebook Safe Parse**: 先頭セルから Header Association を `Import["Text"]` + `ToExpression[..., HoldComplete]` で **評価せずに** 取り出し、whitelist (String/Integer/Bool/Missing/DateObject/List of String/Association) を通過したものだけ採用。`RunProcess` / `Get` / `Import` / `URLRead` 等は `UnsafeExpression` で拒否
- **Stage 9 P1 Header parser 優先順位 (MakeExpression 第一選択化)**: 副作用回避のため `iNotebookHeaderParse[path]` は **(B) `Import["Notebook"]` + `MakeExpression[box, StandardForm]` を第一選択** → fallback で **(A) `Import["Initialization"]`** (InitializationCell の中身を評価する副作用あり)。戻り値に `"Source"` フィールド (`"MakeExpression"` / `"Initialization"`) を追加して経路を明示
- **Stage 9 Todo 判定優先順位**: (1) `TaggingRules["TodoStatus"]` → (2) `FontVariations -> {"StrikeThrough" -> True}` → (3) Default "Open"。`StatusSource` フィールドで判定根拠を追跡可能
- **Stage 9 重要原則**: Header の `Status` field と Todo cell の状態は **独立に保存** し、合成判定 (lint) で不整合を検出。「Header Status だけで notebook 状態を判定しない」
- **Stage 9 P1 mtime ベース cache**: `SourceVaultIndexNotebook[path]` は冒頭で `UnixTime[FileDate[path, "Modification"]]` (Integer) と snapshot record の `"SourceMTime"` フィールドを比較し、一致なら **完全な Index 結果を再構築して返す** (透過的キャッシュ)。Header/Todo は再抽出するが `Import["Notebook"]` / `SemanticHash` 計算をスキップ。新オプション `"ForceReindex" -> True` で強制再 index。戻り値に `"Cached"` / `"SourceMTime"` フィールド追加
- **Stage 9 P1 NBAccess semantic API**: NBAccess に高レベル API 7 個追加 (`NBReadHeader` / `NBReadTodos` / `NBFindCellByPredicate` / `NBWriteHeader` / `NBWriteTodoStatus` / `NBSetCellOptionsByPredicate` / `NBSetCellTaggingRuleByPredicate`)。**読み取り系は AccessLevel >= 0 (default 0.5)**、**書き込み系は AccessLevel >= 0.7 必須 (default 0.7)**、書き込み系のデフォルトは `DryRun -> True`、atomic write (tmp + Rename) で FrontEnd なしでファイル直接編集可能
- **Stage 9 P1 SourceVaultMarkTodo**: NBAccess の `NBWriteTodoStatus` への薄いラッパー。target は Integer (Todo Index) / String (TodoId) / Association (`<|"Index" -> _, "Text" -> _|>`) を受け付け、内部で `iSVResolveTodoTarget` で正規化。`"AutoReindex" -> True` (default) で実行時のみ `SourceVaultIndexNotebook` を自動呼び出し
- **Stage 9 P1 NBReadHeader 3 経路 fallback**: (1) Notebook 全体 TaggingRules > SourceVault → (2) 全 Cell の TaggingRules > SourceVault → (3) Input cell の BoxData → MakeExpression → (4) None。経路 (1)(2) では **Header フィルタ `iNBIsHeaderLikeAssoc`** で TodoItem cell の `<|"TodoStatus" -> "..."|>` のような Todo metadata を除外 (Header らしいキー Keywords/Status/Deadline/NextReview/Owner/PathHint/Title のいずれかを含むもののみ Header と認める)。Source フィールド値: `"TaggingRules"` / `"HeaderCell"` / `"BoxData"` / `"None"`
- **Wolfram 文字列リテラル内の Unicode 文字は `\:XXXX` で書く** (罠 #11)。`\u` は不可。新規コード追加時は事前に `grep '\\u[0-9a-fA-F]\{4\}' SourceVault.wl` でチェック (Stage 6c で 72 件、Stage 8 で 295 件、Stage 6d で 94 件、Stage 6b で 380 件、Stage 9 P0 で 266 件、Stage 9 P1 で 0 件維持 (Python 一括変換で `\u` → `\:` を自動化) → 累計 1107 件踏んだ。最大の継続的エラー源)
- **`\:` の後は必ず 4 桁 hex**。`\:a7` のような 2 桁では `Syntax::snthex` エラーでロード失敗 (罠 #11 補足)
- **罠 #26 (Stage 9 P1 で発見)**: `Import["Notebook"]` の戻り値は `Notebook[{Cell[CellGroupData[{Cell[...], ...}, Open]], ...}]` でセルが CellGroupData ネスト。トップレベルの `cells[[i]]` だけ見ても通常 Cell に到達できない。`iFlattenCells` / `iNBFlattenCells` パターンで **再帰展開** する
- **罠 #27 (Stage 9 P1 で発見)**: `Module` 内のローカル変数を `HoldComplete[localVar]` でラップすると、Module を抜けた後にローカル変数のシンボル名 (`pkg\`Private\`var$NNNN`) がそのまま残る。値を保持するには `With[{c = localVar}, HoldComplete[c]]` のように **`With` の Block-substitution** を使う
- **罠 #28 (Stage 9 P1 で発見)**: `ImportString[str, "RawJSON"]` は **Windows path のバックスラッシュ** (`"C:\\\\Users\\\\..."`) を含む JSON 値で `$Failed` を返す不具合。JSON 読み込みでは **3 段階 fallback** (`ImportString "RawJSON"` → `Developer\`ReadRawJSONString` → `ImportString "JSON"`) を用意。`iLoadJSONFromFile` で実装済み

### Stage 9 P1 拡張 Steps 1-8 (2026-05-21) の必須ルール

- **Step 1 CloudPublishable**: `NBSetCloudPublishable[path, True|False]` は「レガシーなノートブック資産か、PrivacyLevel 準拠ノートか」を宣言するだけのフラグ。プライバシー操作そのものではない。`NBGetCloudPublishable` / `NBClearCloudPublishable` と対で、Notebook 全体の TaggingRules > SourceVault > "CloudPublishable" に保存
- **Step 3 SourceVaultUpcomingSchedule**: 「今日から N 日以内」に Deadline / NextReview が入る notebook を Dataset で返す。オプション Scope / Period / IncludeOverdue / Recursive / Refresh / FallbackToCloud / StatusFilter / UseCache。差分キャッシュ `$iSVIndexCache` でファイル単位、変更なしファイルは再 index しない
- **Step 4 自然言語ルーター**: `$ClaudeEvalNaturalDispatch` (既定 True)。`iClaudeEvalTryDispatch` の**最上段**に注入し、「予定/スケジュール/タスク/upcoming」→ `SourceVaultUpcomingSchedule`、「概要を更新/refresh summary」→ `SourceVaultRefreshAllSummaries` に振り分け。パターン照合は `StringContainsQ` (罠 #43 回避)
- **Step 5 クロス PC パス正規化**: `$SourceVaultCloudRoots` のシンボル名 (`$onWork` 等) を使い、`iSVSymbolicPath[abs]` で絶対パスを `{"$onWork", "folder", "file.nb"}` のルート相対パスに変換。`iNotebookRefFromPath` はこのシンボリックパスから ID をハッシュ → PC / OS をまたいで安定 (罠 #45)。`$ClaudeWorkingDirectory` 等 PC 固有フォルダは `$SourceVaultCloudRoots` に**含めない**
- **Step 5 SourceVaultResetStore**: `"Confirm" -> True` で notebooks ストアを全削除。Confirm なしは DryRun。NotebookRef 方式変更時の旧データ破棄に使う
- **Step 6 概要のスキーマ化制約**: 「概要は定義上クラウド投入可能なスキーマ情報である」と定義し、そう生成させる。`iBuildNotebookSummaryPrompt` に CRITICAL PRIVACY CONSTRAINT (個人名は役割に一般化、メール/電話/住所/認証情報を含めない) を課し、生成後 `iSVValidateSummarySchema` で正規表現検証 (メール/電話/認証 URL/API キー混入)、違反なら概要を破棄し `Status: "SchemaViolation"`。判定問題を生成制約問題に変換 (罠 #46)
- **Step 6 snapshot の PrivacyLevel**: `snapshotRecord` に `"PrivacyLevel"` / `"PrivacyLevelSource"` / `"AcquisitionContext"` フィールド。ローカル `.nb` は `iSVSnapshotPrivacyLevel` が `NBAccess`NBFileSpec` の判定を継承 (混在は最大値=安全側、判定不能は 1.0)。snapshot 単位なので版ごとに PrivacyLevel が変わり得る
- **Step 7 数値 PrivacyLevel 操作**: `NBMarkCellConfidential` を数値レベル対応に拡張。`NBMarkCellConfidential[nb, idx]` は 1.0 (従来互換)、`NBMarkCellConfidential[nb, idx, level]` は任意の 0.0-1.0。`level > 0.5` で赤背景マーク。数値 `privacyLevel` タグを claudecode TaggingRules に保存し `NBCellPrivacyLevel` が最優先で読む。`PrivacySpec` オプション必須
- **Step 7 承認ゲート**: PrivacyLevel 操作関数 (`NBMarkCellConfidential` / `NBSetSnapshotPrivacyLevel`) を `$NBApprovalHeads` に登録するだけで、ClaudeRuntime / Orchestrator が当該式の評価時に承認ゲートを発火させる。NBAccess 側で能動的に Approval を呼ぶコードは書かない。操作の上げ下げ両方が承認対象
- **Step 7 NBAccess → SourceVault 依存は許容**: 「全内部データは NBAccess が仲介する」設計のため NBAccess が上位、SourceVault が下位。`NBSetSnapshotPrivacyLevel` が SourceVault snapshot を扱ってよい
- **Step 8 再起動後高速化**: `snapshotRecord` に Header / Todos を `Compress` 文字列 (`"HeaderCompressed"` / `"TodosCompressed"`) で永続化。`SourceVaultIndexNotebook` の cache hit ブランチはこれを `Uncompress` で復元し `.nb` Import を回避。Mathematica 再起動後でも mtime 一致ファイルは高速 (実測: 初回 736 秒 → 2 回目 0.68 秒)。`Compress` は `DateObject` / `Quantity` / `Missing` を型保持で往復 (罠 #48)
- **Step 8 メモリ枯渇対策**: `iSVGetCachedRecords` は全 record をメモリに積まず、`iSVLightRecord` で UpcomingSchedule が使うフィールド (Header の日付/Keywords/Status、Todo カウント) だけの軽量レコードを保持。record 全体は `=.` で即解放、25 件ごとに `ClearSystemCache["Notebooks"]` (罠 #49)
- **Step 8 ファイルサイズ閾値**: `$SourceVaultMaxFileSizeMB` (既定 50)。`SourceVaultIndexNotebook` は `.nb` を読む前に `FileByteCount` をチェックし、閾値超えは Import せず `snap-toolarge-...` の軽量 snapshot (`"Skipped" -> True`, `"SkipReason" -> "FileTooLarge"`, `"FileSizeMB"`) を作る。シミュレーション結果埋め込みの巨大 `.nb` (数百 MB〜GB) によるメモリ枯渇・ハングを防ぐ (罠 #51)

### 次フェーズ Sync / Relink / モデルレジストリ / UUID (2026-05-22) の必須ルール

**このフェーズの開発で `sources/` ストアを実際に破損させたため、データストア書き込みの安全規約を `rules/103-sourcevault-datastore-safety.md` として独立させた。SourceVault のストア書き込みコードを書く・直すときは rule 103 を必ず読む。**

- **Sync クローラー骨格**: 公開 API 4 個 — `SourceVaultSelectSources` (Scope 配下の .nb を source descriptor 化) / `SourceVaultSyncPlan` (鮮度判定、dry-run、Fresh/Stale/Missing/NeverIndexed に分類) / `SourceVaultSync` (Stale を再 index) / `SourceVaultSyncStatus`。鮮度トークンはローカル mtime のみ実装、web (ETag/Last-Modified/TTL) は抽象の枠だけ予約。**PrivacyLevel は単調** — 再 index で PrivacyLevel が下がったら `SourceVaultSetSnapshotPrivacyLevel` で旧値に引き上げ警告を記録。一括同期の `FallbackToCloud` 既定は `"Deny"`。ストア `notebooks/sync/`
- **Relink ファイル移動追跡**: `SourceVaultRelinkSources`。`OriginalPath` が消えた notebook source を検出し、Scope 配下から移動先を **(1) 埋め込み UUID → (2) 内容ハッシュ完全一致 → (3) ファイル名一意一致** の順で照合。`iSVRelinkSources` プレースホルダーを置換 (後方互換エイリアス保持)。非破壊 (旧 record に Superseded マーク)。ストア `notebooks/relink/`
  - **移動判定はシンボリックパス解決ベース** — `OriginalPath` の生 `FileExistsQ` でなく、`SymbolicPath` を `iSVResolvePath` で現 PC 解決して実在判定。別 PC のパス差を移動と誤検出しない (rule 103-5)
  - **NameOnly は弱い証拠** — UUID/ContentHash 一致は自動適用するが、ファイル名一致は `ApplyNameOnly -> True` のときのみ適用 (既定はレポートのみ)。連番ファイル群の誤マッチ防止 (rule 103-6)
  - **StaleDuplicate 判定** — マッチ先が既に別の現役 record の指す実ファイルなら「移動」でなく「旧 PC index の残骸」。`livePathSet` (現役 record の実ファイルパス集合) で実パス判定。`DeleteStale -> True` で残骸 record を削除 (既定 False は非破壊マーク)
  - `SourceVaultIndexNotebook` の sourceRecord に `SymbolicPath` と `SourceUUID` フィールドを追加 (Relink の判定基盤)
- **モデルレジストリ動的更新**: 公開変数 `$SourceVaultModelEndpoints` + API 3 個 — `SourceVaultModelEndpointStatus` (到達性チェック、401/403 も到達=Online) / `SourceVaultDetectLocalModels` (LM Studio 等の OpenAI 互換 /v1/models からモデル推測) / `SourceVaultRefreshModelRegistry` (cloud + local からモデル取得し compiled registry にマージ)。取得エントリは `Source -> "auto-fetch"`、seed/manual は温存
  - **API キーは NBAccess の管轄** — cloud は `NBAccess\`NBGetAPIKey`、local は `NBAccess\`NBGetLocalLLMAPIKey[provider, url]` 経由でのみ取得。SourceVault は `SystemCredential` も生キー文字列も一切触らない (rule 20)
  - **ローカル endpoint は `$ClaudePrivateModel` を優先** — `iSVResolveLocalEndpoint` が (1) 明示 Endpoint → (2) `ClaudeCode\`$ClaudePrivateModel` の url (provider 一致時) → (3) `$SourceVaultModelEndpoints` 設定、の順で解決。LM Studio を別ホストに置いても追従
  - **`URLRead` に `TimeConstraint` オプションは無い** — `TimeConstrained[URLRead[...], 秒, $Failed]` で囲む (罠 #53)
- **Notebook UUID 埋め込み機構**: 公開 API 3 個 — `SourceVaultNotebookUUID` (読み取り) / `SourceVaultEnsureNotebookUUID` (無ければ生成して埋め込み) / `SourceVaultEnsureNotebookUUIDFolder` (folder 一括)。UUID は notebook の TaggingRules `SourceVault > NotebookUUID` に保存 (`nbuuid-` + `CreateUUID`)。ファイル名変更・内容編集をまたいで安定し、Relink の最も信頼できる照合キー。書き込みは `NBFileOpen` (Visible->False) 経由。`EnsureNotebookUUIDFolder` の巨大ファイルは `Skipped` (`Failed` と別カウント)
- **罠 #52 (このフェーズで発見、重大)**: `Return[expr, Module]` は「最も内側の同名 `Module`」から抜ける。関数全体を抜けたい早期 return を内側 `Module[{tmp}, ...]` の中に書くと、内側 Module だけ抜けて処理が後続に流れる。Relink で `Linked` 判定後の早期 return が内側 Module に閉じ込められ、全件が照合ループに流れて `Relinked` が膨張した。早期 return は**関数本体の `Module` レベル**に置く
- **罠 #53 (このフェーズで発見)**: `URLRead[req, fmt, TimeConstraint -> n]` は `URLRead::optx` で静かに失敗し `$Failed` を返す。`TimeConstraint` は `URLRead` のオプションではない
- **罠 #54 (このフェーズで発見)**: `::usage` 本文の文字列リテラル内に出てくる `"..."` は必ず `\"...\"` にエスケープする。怠ると usage 文字列が途中で終了し `MessageName::messg` でロード失敗。配布前に全 usage の引用符バランスを機械検査する
- **Dataset の Button セル省略 (このフェーズで再確認)**: Dataset はセル内 Button 等のインタラクティブ要素を構造的に `...` 省略する。クリック可能セルを含む表は `Grid` を使う (UpcomingSchedule の `iSVFormatScheduleDataset` で対応済み)

## 関連 skill (詳細設計)

- `skills/ocr-backend-design` — Stage 4C の 3 backend 設計、上下分割 + 30px overlap、診断機構
- `skills/claudecode-cli-vision` — Phase 35 修正の構造、CLI 経路で vision を回す仕組み
- `skills/llm-extraction-pipeline` — Stage 5 全体、5 段階 JSON parse fallback、サニタイズ
- `skills/jsonl-store-pattern` — 3 重インデックス append-only JSONL パターン
- `skills/claim-dedup-and-compact` — Stage 6a の dedup + Compact 設計
- `skills/evidence-bundle-design` — Stage 6c の Evidence Bundle 設計
- `skills/snapshot-lifecycle-and-diff` — Stage 8 の lifecycle event + page hash diff 設計
- `skills/nbauthorize-2-stage-decisions` — Stage 6d の sendDecision + persistDecision 設計
- `skills/compiled-registry-and-seed` — Stage 6b の compiled registry + seed bootstrap 設計
- `skills/notebook-management-extraction` — **Stage 9 P0/P1 + 次フェーズの Notebook 拡張設計** (Safe parse + whitelist、Todo Status 優先順位、Header / Todo 状態の独立保存、7 種 lint、FindNotebooks クエリ、NBAccess semantic API 統合、SourceVaultMarkTodo、mtime cache、次フェーズの Sync クローラー / Relink 3 段照合 / UUID 埋め込み機構を含む)
- `skills/nbaccess-semantic-api` — **Stage 9 P1 の NBAccess 高レベル API 設計** (読み取り 3 個 + 書き込み 4 個、AccessLevel RBAC、DryRun、atomic write、3 経路 Header fallback、Header フィルタ)
- `skills/compiled-registry-and-seed` — **Stage 6b の compiled registry + seed bootstrap 設計 + 次フェーズのモデルレジストリ動的更新** (`$SourceVaultModelEndpoints`、cloud/local エンドポイントからのモデル取得、auto-fetch マージ)
- `skills/wolfram-syntax-pitfalls` — 罠 #11, #11 補足, #16, #20, #26, #27, #28 (Wolfram 構文系) + #35-#51 (P1 拡張) + **#52-#54 (次フェーズ: Return[expr, Module] スコープ / URLRead に TimeConstraint なし / ::usage 内ダブルクォートのエスケープ)**

## データストア書き込みの安全規約 (運用開始後は必読)

SourceVault の運用が始まると `notebooks/` 配下のストアは日々の作業記録になり、`SourceVaultResetStore` での全削除は事実上できなくなる。ストアを破壊するバグを作り込まないため、ストア書き込みコードを書く・直すときは **`rules/103-sourcevault-datastore-safety.md` を必ず読む**。要点:

- 破壊的操作は `DryRun` 既定 `True`、削除と非破壊マークは別オプション、全削除は二重確認
- 早期 return (`Return[..., Module]`) のスコープを確認 (罠 #52)
- 同一性判定は派生 ID でなく実体 (実パス / 内容ハッシュ) で行う
- 多段照合は信頼度で「自動適用」と「レポートのみ」を分ける
- 破壊的操作は DryRun 結果を人間が検証してから `DryRun -> False`
- atomic write (tmp + Rename) を徹底、戻り値に変更件数の集計を含める

## 既知の制約 (Phase 2/3 で対応予定)

- ~~claim dedup なし~~ **Stage 6a で解消**
- ~~Evidence Bundle 未実装~~ **Stage 6c Phase 1 で解消**
- ~~snapshot lifecycle 化なし~~ **Stage 8 で解消**
- ~~NBAuthorize の sendDecision/persistDecision 未統合~~ **Stage 6d で解消**
- ~~Compiled registry 未実装~~ **Stage 6b で解消 (Phase 1 完成)**
- ~~Notebook を first-class source 化~~ **Stage 9 P0 で解消**
- `StoreClaims -> False` の dry run は検索 API で拾えない
- 階層 bundle の status 集約は Stage 6c Phase 2
- WorkflowRun 自動連携 (ClaudeOrchestrator → bundle 自動生成) は Stage 6c Phase 2
- claim-level diff は Stage 8 Phase 2
- 自動 fetch (arXiv 定期 refresh) は Stage 8 Phase 2
- event log を Bundle Status 計算で参照していない → Stage 8 Phase 2
- contradiction 検出 (§12.3) は Stage 8 Phase 3
- `Screen` decision の redaction は Stage 6d Phase 2
- `SourceVaultBundleCreate` の CreateBundle authorize は Stage 6d Phase 2
- per-claim authorize (batch ではなく claim ごと) は Stage 6d Phase 2
- claim → registry の自動 compile は Stage 6b Phase 2 (`SourceVaultCompileFromClaims[topic, schema]`)
- channel lint (private 由来 claim の public 混入検出) は Stage 6b Phase 2
- cloud-safe registry mirror は Stage 6b Phase 2 (§11)
- `NotebookSemanticHash` / `HeaderHash` / `TodoHash` / `CellHashes` は **Stage 9 P1 で部分対応** (`NotebookSemanticHash` 完成、その他は次フェーズ)
- ~~`SourceVaultNotebookSummary` (LLM 要約)~~ **Stage 9 P1 Step 5 で解消**
- ~~`SourceVaultMarkTodo`~~ **Stage 9 P1 Step 6 で解消** (NBAccess `NBWriteTodoStatus` への薄いラッパー)
- ~~file mtime ベースの index skip~~ **Stage 9 P1 Step 7 で解消**
- ~~Header parser の MakeExpression 第一選択化~~ **Stage 9 P1 Step 8 で解消**
- ~~NBAccess に高レベル semantic API~~ **Stage 9 P1 で解消** (読み取り 3 個 + 書き込み 4 個)
- ~~近日 Deadline / NextReview の一覧化~~ **P1 拡張 Step 3 で解消** (`SourceVaultUpcomingSchedule`)
- ~~ClaudeEval 自然言語からの SourceVault 呼び出し~~ **P1 拡張 Step 4 で解消** (`$ClaudeEvalNaturalDispatch`)
- ~~クロス PC でのパス非互換~~ **P1 拡張 Step 5 で解消** (`iSVSymbolicPath` シンボリックパス)
- ~~snapshot の PrivacyLevel 体系~~ **P1 拡張 Step 6/7 で解消** (snapshot PrivacyLevel フィールド + 概要スキーマ化制約 + セル数値 PrivacyLevel)
- ~~Mathematica 再起動後の index 再実行が遅い~~ **P1 拡張 Step 8 で解消** (Header/Todo の Compress 永続化、初回 736 秒 → 2 回目 0.68 秒)
- NBAccess privacy profile による route 分岐は Stage 9 Phase 3 (P2)
- ClaudeEval / ClaudeOrchestrator 統合は Stage 9 Phase 3 (P2)
- バッチ Todo 操作 (`SourceVaultMarkTodos[path, [{idx1, "Done"}, {idx2, "Pass"}]]`) は Stage 9 Phase 3
- Notebook 全体の TaggingRules > SourceVault Header migration (既存 BoxData 形式 → TaggingRules 形式) は Stage 9 Phase 3
- ~~モデルレジストリ~~ **次フェーズで解消** (`$SourceVaultModelEndpoints` + `SourceVaultModelEndpointStatus` / `DetectLocalModels` / `RefreshModelRegistry`、cloud/local エンドポイント、`$ClaudePrivateModel` url 優先)
- ~~SourceVaultSync クローラー~~ **次フェーズで骨格完成** (`SourceVaultSelectSources` / `SyncPlan` / `Sync` / `SyncStatus`、鮮度トークン抽象、PrivacyLevel 単調)
- ~~ファイル移動の追跡~~ **次フェーズで解消** (`SourceVaultRelinkSources`、UUID / 内容ハッシュ / ファイル名の 3 段照合、シンボリックパスベース移動判定、StaleDuplicate 判定)
- ~~`SourceVaultUpcomingSchedule` の SystemOpen リンクのクロス PC 対応~~ **次フェーズで解消** (Grid + symbolic path 保持 + 評価時 `iSVResolvePath`)
- ~~`NBSetSnapshotPrivacyLevel` の委譲先 `SourceVaultSetSnapshotPrivacyLevel`~~ **次フェーズで解消**
- ~~Notebook への UUID 埋め込み機構~~ **次フェーズで解消** (`SourceVaultNotebookUUID` / `EnsureNotebookUUID` / `EnsureNotebookUUIDFolder`、TaggingRules `SourceVault > NotebookUUID`)

### 次フェーズの残課題 (今後)

- Sync の web source (URL / arXiv) 実 fetch は未実装 (鮮度トークンの抽象枠のみ)。Orchestrator 経由の非同期実行も未対応 (現状は同期)
- Relink の UUID 照合は notebook に UUID が埋め込まれている場合のみ発動。既存 notebook には `SourceVaultEnsureNotebookUUIDFolder[$onWork]` で一括付与してから使う。UUID 付与は notebook の mtime を変えるため「UUID 付与 → 全件 index → 以降安定」の順序で行う
- モデルレジストリの取得モデルは `Class` (Heavy/Mid/Light) と `Intent` が `Unknown`/`Null`。Intent ベース lookup (`iCompiledLookupModel`) に乗せるには分類ステップが必要
- `iSVSymbolicPath` が旧 PC の Dropbox パス (`C:\Users\imai_\Dropbox\On Work\...` 等) を `{"$onWork", ...}` に正規化できない。`$SourceVaultCloudRoots` に旧ルートのエイリアスを登録できれば、複数 PC をまたいだ二重登録を未然に防げる (現状は Relink の StaleDuplicate 判定で事後的に掃除)
- `SourceVaultIngest` 時の UUID 自動付与 (取り込み元フォルダのファイルにも UUID を付ける)
- NBAccess へのパス正規化展開 (Step 5 の `iSVSymbolicPath` 正規化を NBAccess `NBFileSpec` 等にも適用)
