# CLAUDE.md

## ⛔ 最優先ルール 1: AutoEvaluate 禁止操作 (`rules/00-autoeval-prohibited.md`)

**以下の操作は `AutoEvaluate -> True` で自動実行されるコードに絶対に含めてはならない。このルールは他のすべてのルール・スキルに優先する。**

- **保護対象定数の変更** (`=`, `AppendTo`, `PrependTo`) — `$ClaudeModel`, `$ClaudePrivateModel`, `$ClaudeTestModel`, `$ClaudeFallbackModels`, `$ClaudeAccessibleDirs`, `$ClaudeDocMaxRetries`, `$ClaudeEvalMaxDepth`, `$NBPrivacySpec`, `$NBConfidentialSymbols`, `$NBSendDataSchema`, `$NBSeparationIgnoreList`
- **`ClaudeAttach` の実行** — セッションへのファイルアタッチは手動実行のみ許可
- **`SystemCredential` の使用** — 認証情報へのアクセスは手動実行のみ許可

これらの操作が必要な場合は `AutoEvaluate -> False` で出力し、ユーザーに手動実行を促すこと。詳細は `rules/00-autoeval-prohibited.md` を参照。

## ⛔ 最優先ルール 2: LLM 指示文・スキル・慣習を `.wl` にハードコードしない (`rules/02-llm-instructions-not-in-source.md`)

**LLM にコード生成・分析・推論を指示するテキスト、特にシステム外要因 (モデルのバージョンアップ、API 仕様変更、ベストプラクティス更新等) で変更されうる情報は `.wl` ソースコードに直書きせず、`Claude Directives` の `skills/` または `rules/` に置く。** このルールは他のすべてのルール (00 を除く) に優先する。

ハードコードしてはいけないものの例:

- **モデル枝番** (`gpt-5`, `gpt-4.1`, `claude-opus-4.7` 等の具体名) — `iPrefixMatchCapability` のようなコード分岐に枝番を書かない。`Provider` (anthropic / openai / lm-studio) と `Class` (Heavy/Mid/Light × Cloud/Local) の汎用判定だけを残し、具体モデル名は `$ClaudeModelCapabilities` のテーブル登録に閉じる。
- **LLM 生成プロンプト本体** (`$petriNetGuide`, `$petriNetGuideExtras` 等) — テンプレート文字列で LLM に「こう書け」と指示する内容は skill ファイルに置く。`.wl` ロード時に skill ファイルから読み込んで動的に組み立てる。
- **ベストプラクティス・命名規約・反パターン・言い回し** — 「`Quiet@Check` を使うな」「`gpt-5` を `gpt-4o` に書き換えるな」のような **LLM が読むべき指示** は skill / rules。
- **API キー名・環境変数名以外の認証情報の扱い** — 個別のプロバイダ手順書は skill。

`.wl` に書いてよいもの:

- 構造化データ (Capability Association、Schema 定義、enum 値)
- ロジック (関数本体、状態遷移、データ変換)
- 公開 API のシグネチャと usage 文字列

判定が迷う場合: **「これは半年後にも有効か?」** が `No` または `わからない` なら skill。**「これは LLM が読んで真似る雛形か?」** が `Yes` なら skill。

詳細は `rules/02-llm-instructions-not-in-source.md` を参照。関連 skill: `skills/llm-instruction-separation`。

## セッション開始時の基本方針

- まず対象ファイルとその周辺依存を読んでから編集する。
- 公開シンボル・ノートブック UX・既存ワークフローを壊さない最小差分を優先する。

## ディレクティブ構造

- `rules/` — 絶対に破ってはいけない設計・安全・アクセス制約。
- `skills/` — 特定の解析・修正・レビューの具体手順とパターン集。LLM への生成指示文も含む。
- タスクに最も近いスキルを参照し、常に rules の制約を遵守する。

将来的には `knowledge/` (汎用知識データベース) も併設する想定。skill より長期不変な「特定パッケージとは独立な背景知識」(数学、計算機科学の基礎、Wolfram Language の言語仕様抜粋等) を置く。導入時期は別途判断。

## インストール済みスキル

- `wolfram-general` — Wolfram Language コーディング手順・出力方針
- `notebook-path-policy` — ファイルパス解決パターン
- `nbaccess-notebook-access` — NBAccess API リファレンスと推奨パターン
- `nbaccess-separation-check` — NBAccess 分離原則の検証・修正手順
- `api-key-handling` — API キー取得の正しい実装手順
- `wl-encoding-and-regex` — `.wl` ソース内のエスケープ (`\:XXXX`)・正規表現の検証手順 (実行時バイト I/O は `wl-runtime-byte-io` に分離)
- `wl-runtime-byte-io` — 実行時の文字列⇔バイト変換 (HTTP 送受信ボディ、JSON ファイル読み書き) で日本語が化けないための手順。`ExportString["RawJSON"]` (→ ISO8859-1) と `Developer`WriteRawJSONString` (→ UTF-8) の戻り値エンコード差、二重 encode 回避 (罠 #55)、`HTTPRequest` Body に ByteArray を渡す原則
- `pde-modeling` — PDE 実装ステップ
- `confidential-data-handling` — 機密データのラッピング手順
- `confidential-structure-probe` — 秘密変数の構造調査と ContinueEval 連携手順
- `external-language-output` — R/Python 等の外部言語コードの出力パターン
- `doc-generation` — ドキュメント生成の継続・README 構造ルール
- `github-operations` — GitHub パッケージ管理・PR 管理・インストール手順
- `package-merge-pattern` — LLM レスポンスによるパッケージ部分更新のマージ・安全検証パターン
- `package-namespace-migration` — 既存パッケージから新パッケージへの関数移管時の context path / shadowing 罠と回避パターン
- `llmgraph-dag-job-lifecycle` — LLMGraphDAG ジョブの自動削除挙動と registry 観察パターン (onComplete 経由 / handler 内部観察)
- `notebook-llmgraph-update-pattern` — 外部パッケージから NotebookLLMGraph にノードを追加する際の正しいキャッシュ更新 + Flush パターン
- `wolfram-syntax-pitfalls` — `Module` 閉じ位置誤りや `Quiet` のエラー隠蔽など、LLM ベースの大規模 .wl 編集で頻発する構文上の罠と診断手順
- `ui-output-font-customization` — ClaudeEval/SourceVault の表・リスト出力フォント (`$ClaudeStandardFont`/`iSVStandardFont`) を設定追従させる実装パターンと「フォントが効かない」切り分け (罠 #56–#58: ClearAll 順序 / Button ラベル内関数の未評価 / Hyperlink フォント上書き)
- `maildb-operations` — メール操作。正準は **SourceVault mail サブシステム** (`SourceVault_maildb.wl`: `SourceVaultMailFetchNew` / `MailView` / `SearchMailSnapshots` / `InferMailDerivedBatch` / `RegisterMailAccount`)。旧 `maildb.wl` は `maildb_legacy.wl` に改名され参照専用 (showMails/searchFromMails/mailEnsureLoaded は legacy)。privacy>0.5 はローカル LLM。
- `system-open` — SystemOpen によるファイル・フォルダ・ノートブックの開き方
- `runtime-orchestrator-boundary` — ClaudeRuntime と ClaudeOrchestrator の責務境界、特に並列化の許容範囲（Workflow Migration プロジェクト）
- `association-mutation-patterns` — Mathematica で Association を更新するときの安全パターン（`ReplacePart` 罠、`Append`/`Join` の使い分け）
- `llm-instruction-separation` — LLM 生成指示文・モデル名・慣習を `.wl` にハードコードしない原則と移行手順
- `petri-multi-provider-generation` — petri_from_prompt 系で multi-provider レビューネットを生成する際の Provider/Model 指定ルール (旧 `$petriNetGuideExtras` の置き場)
- `petri-and-xor-merge` — petri_from_prompt 系で AND-merge / XOR-merge / AND-distribute / XOR-distribute を選択する設計指針 (peer review は AND-merge)
- `petri-retry-patterns` — petri_from_prompt 系で fan-out 並列 worker の失敗を retry する Petri net を生成する際の正しい配線指針 (per-worker retry vs Verdict 下流 rerun antipattern の区別)
- `petri-template-and-validation` — proposePetriNet をテンプレート化 + 検証ノード入りメタワークフロー化する長期設計提案 (引き継ぎ書類)
- `async-tool-execution` — `$UseClaudeRuntime = True` 経路で `iToolUseAndContinue` の hybrid 化により tool (web_search 等) を別 OS プロセスで並列実行する Phase 32k Step 3 (Phase A〜D2) の設計・運用・デバッグ
- `async-handler-pattern` — ClaudeOrchestrator Workflow で handler が `Status -> "AwaitingLLM"` を返す Z 案パターン (callback / engine timer / Snapshot/Restore)
- `package-hook-installation-patterns` — 既存パッケージの公開シンボル (e.g. ClaudeAttach) に hook を装着する安全テンプレ。Block 撤廃 / DownValues swap helper / CheckAbort 復元 / `opts___` pass-through / Enable-Disable 冪等性 / Memory Registry Fallback (SourceVault P1〜P4 で検証)
- `llm-prompt-template-override` — 既存パッケージの LLM prompt template に外部からドキュメント・指示を注入する prompt engineering パターン。XML タグ命名 (`<sources>` vs `<attached-documents>`) / HTML コメント指示文 / `{{DEPENDENCY_SECTION}}` ラベル StringReplace 置換 / prepend fallback の 2 段階 (SourceVault A5 hook で検証)
- `claudecode-cli-vision` — claudecode.wl Phase 35 で provider == "claudecode" CLI 経路でも multimodal/vision が無課金で動く設計。`iClaudeQueryBgAPIMultimodal` の 1 行リダイレクトと既存 `iNormalizePrompt` の画像対応実装の組合せ
- `ocr-backend-design` — SourceVault.wl Stage 4C の 3 backend OCR (ClaudeVision/TextRecognize/Custom) 設計。上下分割+30px overlap、Mode=Force/ForceOCR、PyMuPDF/native 2段 fallback、OCRAttempted/OCRFailReasons/Verbose 診断、PDFIndex 由来コード移植時の罠 #16 対応
- `llm-extraction-pipeline` — LLM 構造化抽出パイプライン設計。Schema 駆動 prompt 構築、5 段階 JSON parse fallback (markdown fence/bracket counting/partial recovery)、iSanitizeForJSON、Verbose 診断 (SourceVault Stage 5 で実証)
- `jsonl-store-pattern` — Append-only JSONL + 3 重インデックス (master + by-topic + by-source) パターン。Windows CRLF 対応 (罠 #20)、安全な OpenAppend + ReadByteArray 読込、StoreStatus debug ヘルパ、dedup の前提となる ContentHash 設計
- `claim-dedup-and-compact` — SourceVault.wl Stage 6a の claim dedup + Compact 設計。by-source scope の書込み時 dedup、最古残し DeleteDuplicatesBy パターン、Windows 対応 atomic write (path.tmp → DeleteFile → RenameFile)、.bak.<ISODateTime> backup、ExtractedCount/DedupSkipped レスポンス契約
- `evidence-bundle-design` — SourceVault.wl Stage 6c の Evidence Bundle 設計。生成物 → source/snapshot/claim 依存記録、snapshot LifecycleStatus 集約による自動 stale 検出、Status 計算優先順位 (Manual > Invalidated > NeedsReview > Stale > Current)、bundles/<bundleId>.json ストレージ、罠 #11 (\u → \:) 教訓
- `snapshot-lifecycle-and-diff` — SourceVault.wl Stage 8 の snapshot lifecycle + vN diff 設計。page-hashes.json (Stage 4B) を活用した page hash 集合 diff、lazy passive consumer pattern による Bundle 自動 stale 化、events/source-events.jsonl event log、VersionedUpdate/Retraction/SourceDeletion/SchemaChange 4 種 event、罠 #11 累計 367 件混入の反省
- `nbauthorize-2-stage-decisions` — SourceVault.wl Stage 6d の NBAuthorize 2 段階統合設計。SourceVaultExtract に sendDecision + persistDecision 追加、SourceVaultContext は RequireApproval も block、4 種 Decision の扱い (Permit/Screen/RequireApproval/Deny)、iSpecFromClaim による AccessLabel 継承、batch 判定 (代表 1 件) の理由、"AuthorizationCheck" -> False opt-out、AccessDecisions レスポンスフィールド
- `compiled-registry-and-seed` — SourceVault.wl Stage 6b の Compiled Registry + Seed bootstrap 設計。seeds/<topic>-seed.json + compiled/<channel>/<topic>.json の 2 階建て、SourceVaultLookup / SourceVaultResolve / ClaudeResolveModel 互換 wrapper、Availability/Freshness/Class 優先順位 sort、public/private channel 分離、AllowSeed -> False 厳格モード、Stage 1 旧定義削除の経緯、累計 841 件の罠 #11 反省
- `notebook-management-extraction` — SourceVault.wl Stage 9 P0 + P1 の Notebook Management 拡張。Mathematica notebook を first-class source として登録、先頭 Input セルを HoldComplete + whitelist で safe parse、TodoItem cell を TaggingRules > StrikeThrough heuristic > Default の優先順位で Done 判定、Header.Status と Todo cell 状態の独立保存と合成 lint、7 種 lint (HeaderStatusTodoButNoOpenTodos / DeadlinePast / TodoCellStatusHeuristicOnly 等)、SourceVaultFindNotebooks の deterministic クエリ、Stage 6c/8/6d との接続点。**Stage 9 P1 拡張**: SourceVaultMarkTodo (NBAccess NBWriteTodoStatus への薄いラッパー)、SourceVaultNotebookSummary (LLM 要約)、mtime ベース cache (`SourceVaultIndexNotebook[path]` の `"Cached"` / `"SourceMTime"` / `"ForceReindex"`)、Header parser MakeExpression 第一選択化 (副作用回避、`"Source"` フィールド `"MakeExpression"` / `"Initialization"`)、NBAccess semantic API 統合
- `nbaccess-semantic-api` — NBAccess.wl Stage 9 P1 で追加された semantic API 7 個の設計詳細。FrontEnd 不要のファイル直接編集パイプライン (`Import["Notebook"]` → 編集 → `Export[..., "NB"]` の atomic write)、AccessLevel RBAC + DryRun 安全機構 (書き込み系 >= 0.7 必須、default DryRun = True)、CellPath (List of Integer) による CellGroupData ネスト対応の cell 位置記録、iNBIsHeaderLikeAssoc フィルタ (Header と Todo metadata の区別)、NBReadHeader の 3 経路 fallback (Notebook TaggingRules → Cell TaggingRules → BoxData MakeExpression)、With[{c=v}, HoldComplete[c]] による DryRun の Before/After 値埋め込み (罠 #27 回避)、CellGroupData の iNBFlattenCells 再帰展開 (罠 #26 回避)、SourceVaultMarkTodo の薄いラッパー設計、Stage 9 P0 Approval Workflow 経路 (NBOpenAuthorized + NBProcessFile) との使い分け、Stage 9 Phase 3 (P2) ロードマップ
- `sourcevault-sync-relink-uuid` — SourceVault.wl の notebook source 鮮度管理・移動追跡・UUID 同定 (notebook-management-extraction から分離)。SourceVaultSync (mtime 鮮度トークンで Stale な .nb を再 index)、SourceVaultRelinkSources (UUID / 内容ハッシュ / ファイル名の 3 段照合、シンボリックパス解決で別 PC のパス差を移動と誤検出しない、StaleDuplicate 残骸判定)、Notebook UUID 埋め込み (TaggingRules SourceVault>NotebookUUID、非破壊、ファイルと一緒に移動)
- `claudeeval-security-guard-placement` — ClaudeEval/ClaudeQuery にセキュリティ・プライバシーガード (クラウド送信拒否、Private ノートブック保護等) を追加するときの配置位置。`$UseClaudeRuntime=True` で Runtime Bridge 経由になるとバイパスされる落とし穴、Deny は最前段 (dispatch 前)・Substitute は共通入口という原則、両経路での発火確認
- `promptrouter-contextplan-routing` — ClaudeEval が LM Studio 等の短コンテキストモデルでトークン超過 (n_keep >= n_ctx) する事故の診断と X0a (context budget) 実装メモ。**真因は `iPackageDocsContext` のキーワード過剰マッチ**(「モデル」等の汎用語が SourceVault の広い `$ClaudePackageKeywordMap` に部分一致し api.md を 104K 注入。tools/notebook/CLAUDE.md は主因でない)。対策は**単一チョークポイント**(`iClaudeSysPrompt` / `iResolveLMStudioIntegrations` / `iPackageDocsContext` / 新設 `iAssembleContextForPlan`)で `$UseClaudeRuntime` True/False 両経路を被覆、planning フラグ `$ClaudeEvalContextPlanning`(LegacyFull で退避)と各 char budget。**主因は推測でなく実測**(各 context 関数の StringLength)で特定する。保存済み候補 UI の堂々巡りは別件 (saved-prompt 提案 / spec §10.3)
- `routing-power-policy` — 実行環境の電源状態（AC/バッテリー）に応じて light ルーティングのモデル階層を Local/Cloud/Off に自動・手動切替する機能。**状態 `ClaudeCode`$ClaudeRoutingModelPolicy`**(Automatic=AC→Local/バッテリー→Cloud)、電源検出 `iDetectACPower`(Windows PowerShell `root\wmi BatteryStatus.PowerOnline`、~30秒キャッシュ)、`ShowClaudePalette` の「ルート」トグル(雲状態ボタンと同型)。**package-neutral**(claudecode 所有・SourceVault 弱参照、rule 11)。契約層 `SourceVaultResolveModelForPromptRouter` が Light routing のみ policy 反映(`Off`→RoutingDisabled、`Cloud`→AllowedTrustDomains `{"Cloud"}`、privacy≥0.5 は Cloud より優先)。**rule 02**: Haiku を直書きせず Light×Cloud クラスで解決。**モデル分類ギャップ解消済み**: 契約 query を `Class` ベース(`Light-Local`/`Light-Cloud`)に翻訳し実モデルまで解決(`iResolveRawTrustDomain` も `Class` から trust domain 導出)。`iModelStatusLabel` で status bar に実モデル名表示
- `runtime-confidential-automark` — Runtime ClaudeEval (`$UseClaudeRuntime=True`) が**無関係/既存/承認ボタン直後のセルを confidential 誤マーク**する事故の診断と修正。原因 2 つ: (1) auto-mark が dispatch 時 cell 数+位置範囲ベースで非同期中の増加セル/末尾セルを巻き込む → identity 差分 `iAutoMarkCellsAddedSince`(書込み直前 `Cells[nb]` スナップショット)に置換。(2) ローカルモデルが accessLevel 1.0 で**無条件 autoMark** → echo した良性コードセルを機密化 → 変数昇格 → `iPrecisionConfidentialCheck` の依存スキャン(`NBTransitiveDependents`/`NBScanDependentCells`)が**連鎖**して無関係セルをマーク → `iShouldBlanketMarkConfidential`(既存機密 or 明示 high-privacy のときだけマーク)でゲート。診断手がかり: 誤マークセルの TaggingRules に eval `history` が乗る(ジョブアンカー)、eval 完了前なのにマーク済み(=連鎖)、`AwaitingApproval` は early Return で success 経路の auto-mark を通らない
- `mathematica-style-slides` — Mathematica ノートブック・プレゼンと連続表示しても違和感がない 16:9 スライド画像 (PNG) を作る手順。HTML/CSS + ヘッドレス Edge レンダリングのパイプライン (日本語が確実・段組が容易)、デッキの見た目仕様 (白背景 / オレンジ見出し `#e07c14` / マルーン四角ビュレット `#9d1c1c` / 第3階層グレー `#8a8a8a` / ノーブレット段落説明)、**Hiragino フォントパレット** (本文 ProN W3・見出し ProN W6＝本文とかな字形をそろえる・強調 Std W4・丸ゴシック・明朝・極太は StdN W8。太字は font-weight でなくファミリ切替で出す)、図は右カラム段組 (Mathematica が苦手な多段組を HTML で再現)、配色は暖色統一。実例 `Templates/Slides/mathematica-style-twocolumn-slide.html` ・ `mathematica-style-bullets-levels.html`

## ファイル読み込みルール

- ファイル名だけが指定された場合（フルパスでない場合）は、
  `FileNameJoin[{Quiet @ Check[NotebookDirectory[], $packageDirectory], ファイル名}]`
  でパスを構築する。`Import["ファイル名"]` のようにカレントディレクトリ依存のコードを生成しない。

## Excel インポート方針（必須）

- Excel ファイルをインポートするときは、明示的に Table 等と指定されない限り **必ず `{"Dataset"}` 形式** で読み込む。
  1行目をキー（列名）として使用する。ただし、1行目からデータが始まっている場合（1行目と2行目以降が同じタイプの項目）であれば、キーを列番号で生成する。
- **シートが1枚の場合**（結果リストの長さが1）: `First @ Import[...]` でリストを外し、単一の Dataset を返す。
- **シートが複数の場合**（結果リストの長さが2以上）: Dataset のリストとしてそのまま返す。

## パッケージドキュメント参照ルール

- `$packageDirectory` 内のパッケージ（`.wl` または Paclet）について質問・指示を処理するとき、まずそのパッケージのドキュメントが存在するか確認する。
  - 単一 `.wl` の場合: `$packageDirectory/<パッケージ名>_info/docs/`
  - Paclet の場合: `$packageDirectory/<パッケージ名>/docs/`
- **api.md ファースト原則**: パッケージの関数を使うコードを生成するとき、またはパッケージの関数について質問されたとき:
  1. **まず api.md を参照する。** api.md にはすべての公開関数・定数・オプション・引数・戻り値・使用例が記載されており、api.md だけで大多数の問題を解決できる。
  2. **api.md で不明な点がある場合のみ**、ソースコード（`.wl`）を直接読む。
  3. api.md に記載されていない関数やオプションを推測で生成してはならない。
- ドキュメントが存在し、かつソースコード（`.wl`）の最終更新日時よりドキュメントの方が新しい場合は、全ドキュメントを参考情報として活用できる。
- ソースコードがドキュメントより新しい場合でも、**api.md のシグネチャ・オプション情報は有効**（API は頻繁に変わらないため）。
- ドキュメントは `ClaudeCreateDocumentation["パッケージ名"]` で生成、`ClaudeUpdateDocumentation["パッケージ名", "更新指示"]` で更新できる。
  - 第二引数で大域的な指示を与えられる: `ClaudeCreateDocumentation["pkg", "日本語で簡潔に"]`
  - `References -> {"URL", "書名"}` で参考文献、`Demos -> {"URL"}` でデモ動画を README に追加。
  - `Disclaimer -> {"追加免責事項"}` で免責事項に追記。指示文中の URL も自動検出。
  - `License -> ""` で MIT ライセンス自動挿入（`$GitHubLicenseHolder` が設定済みの場合）。文字列指定でカスタムライセンス。

## パッケージ操作ルール（必須）

- プロンプトにパッケージ名やファイル名が含まれている場合、`$packageDirectory` 内に該当するパッケージ（`.wl` ファイルまたは Paclet フォルダ）が存在する可能性を**第一に**考えること。
- パッケージの更新・修正タスクには、必ず `ClaudeUpdatePackage["パッケージ名", "更新指示"]` を使用する。
  - `Import`/`ReadString` でソースコードを読み込んで手動で書き換えるコードを生成してはならない。
  - `Export`/`Put` でパッケージファイルを直接上書きするコードを生成してはならない。
  - `ClaudeUpdatePackage` はバックアップ・差分更新・検証・再ロードを自動で行う。
- パッケージの新規作成には `ClaudeCreatePackage["パッケージ名", "仕様"]` を使用する。
- パッケージに関する質問（変更でなく情報提供）には、ドキュメント参照ルールに従い、docs があればそれを先に参照する。
- パッケージの Paclet 変換には `ClaudeConvertToPaclet["パッケージ名"]` を使用する。
- Claude Code CLI のスラッシュコマンドは `ClaudeCommand["/command"]` で実行できる。
- NBAccess 分離原則の検証には `ClaudeCheckSeparation["パッケージ名"]` を使用する。
  - 違反の修正には `ClaudeFixSeparation["パッケージ名"]` を使用する。
  - `$NBSeparationIgnoreList` に登録されたパッケージ（NBAccess, NotebookExtensions）は検査対象外。
- ドキュメント生成 `ClaudeCreateDocumentation` はリミット到達時に自動リトライし、再実行で未生成分のみ続行する。
- `_info/design/` フォルダが存在すれば、README の「設計思想」セクション生成時に参考にする（優先度: docs > コード > design メモ）。

### ClaudeAttach のファイル/URL アタッチとキーワード自動注入

`ClaudeAttach` はファイルだけでなく URL もアタッチできる。URL は WeasyPrint で PDF に変換し `claude_attachments/` にキャッシュされる。

```mathematica
(* ファイルアタッチ *)
ClaudeAttach["report.pdf", Keywords -> {"売上", "revenue"}, Title -> "Q3売上レポート"]

(* URL アタッチ: HTML を PDF 化してキャッシュ *)
ClaudeAttach["https://example.com/docs/api-guide", 
  Keywords -> {"API", "ガイド"}, Title -> "外部APIガイド"]

(* Refetch -> True で再取得・上書き *)
ClaudeAttach["https://example.com/docs/api-guide", Refetch -> True]
```

**キーワード/タイトルによる自動注入**: プロンプト中に登録済みキーワードまたはタイトルが含まれると、該当するアタッチメントが自動的にプロンプトに注入される（セッションに明示的にアタッチされていなくても）。メタデータは `claude_attachments/_meta.json` に永続化される。

**Refetch の動作**:
- `Refetch -> False`（デフォルト）: キャッシュ済みならファイルコピー/URL取得をスキップし、Keywords/Title の変更のみメタデータに記録。
- `Refetch -> True`: ファイルを再コピーまたは URL を再取得して上書きし、メタデータも更新。

### ClaudeEval の再帰呼び出しと複合タスクの分解

- **「使う」と「更新する」の区別（最重要）**: パッケージ名がプロンプトに含まれていても、パッケージの関数を呼び出して**計算・処理・分析・表示**を行う指示には `ClaudeUpdatePackage` を生成してはならない。api.md を確認し、既存の関数で実現できるなら、その関数を呼ぶコードを生成する。
  - ✅ `ClaudeEval["倍数計算で3倍する計算を"]` → 既存の3倍関数を呼ぶコード
  - ✅ `ClaudeEval["maildbでメールを検索して"]` → `searchFromMails[...]` を呼ぶコード
  - ❌ 上記のような利用指示に対して `ClaudeUpdatePackage` を生成する → **禁止**
- **ClaudeEval が ClaudeUpdatePackage を生成してよいのは、パッケージの変更が明示的に要求されている場合のみ。** 「追加して」「修正して」「変更して」「バグを直して」等の変更系動詞がある場合に限る。
- **再帰深さの上限**: `$ClaudeEvalMaxDepth`（デフォルト 5）で制御される。この上限を超える再帰呼び出しは自動的にブロックされる。
- **複合タスクの分解**: 1つのプロンプトに複数の独立した変更指示が含まれる場合、ClaudeEval は複数の `ClaudeUpdatePackage` 呼び出しに分解して生成すべきである。
  - 例: 「markSize を動的にし、配色を改善し、exportSVG を追加して」→ 3回の `ClaudeUpdatePackage` に分解
  - 各呼び出しが独自のバックアップを作成するため、途中で問題が起きてもロールバック可能
  - 変更が相互依存する場合（「X を追加し、Y から X を呼ぶ」）は分解しない
- **分解数の上限**: `$ClaudeEvalMaxDepth` を超えない範囲で分解する。超える場合は関連変更をグループ化する。
- **thinking トリガーの伝播**: ユーザーが「死ぬ気で」「じっくり考えて」等と書いた場合、生成する `ClaudeUpdatePackage` の instruction に適切な think トリガー（`ultrathink`/`think hard`/`think`）を先頭に挿入する。
- **⛔ AutoEvaluate 禁止操作**: `AutoEvaluate -> True` で実行されるコードには保護対象定数の変更、`ClaudeAttach`、`SystemCredential` を**絶対に含めてはならない**。詳細は `rules/00-autoeval-prohibited.md` を参照。

## CUDA パッケージサポート

- プロンプトに「CUDA」「GPU計算」等のキーワードが含まれると、`cuda.wl` 拡張が自動ロードされ CUDA モードになる。
- `cuda.wl` は `$packageDirectory` に配置する。ロードできない場合は警告を表示し、純粋 Mathematica コードで続行する。
- CUDA ソース (.cu) とバイナリは `<パッケージ名>.cuda/` に格納される。
- 既存パッケージに `.cuda/` ディレクトリがあれば、更新時も自動的に CUDA モードが有効になる。
- 詳細は `rules/81-cuda-package-operations.md` を参照。

## GitHub パッケージ管理ルール

- **GitHub 関連の指示を受けたとき、Web 検索に頼らず、まず自分の GitHub リポジトリ（GitHubREST パッケージ）で操作すること。**
  - 「GitHub から xxx をダウンロード/インストール/更新して」→ まず `$packageDirectory` に xxx が存在するか確認し、`GitHubUpdatePackage["xxx"]` または `GitHubInstallPackage["xxx"]` を使う。
  - Web 検索を行うのは、自分のリポジトリに該当パッケージが存在せず、かつ外部の公開リポジトリを明示的に指定された場合のみ。
- 基盤パッケージ (claudecode.wl, NBAccess.wl, github.wl) は手動で `$packageDirectory` に配置する。
- それ以外のパッケージのインストールは `GitHubInstallPackage["パッケージ名"]` を使用する。
  - 「xxx をインストールして」→ `GitHubInstallPackage["xxx"]`
  - 「xxx を更新して」「xxx の最新版をダウンロードして」→ `GitHubUpdatePackage["xxx"]`
- GitHub へのアップロードには `GitHubRefreshAndCommit` を使用する。
- PR 管理には `GitHubPullRequestDataset` (Dataset 表示) または個別関数を使用する。
- 日本語パッケージ名は `GitHubRepoDBSet` でリポジトリ名を登録する。
- ローカル作業フォルダは `$packageDirectory/GithubRepositories/` に統一。

### 基盤パッケージ API 参照ルール（必須）

**コードを生成する際に基盤パッケージ (github.wl, claudecode.wl, NBAccess.wl) の関数を使う場合、必ずそのパッケージの `_info/docs/api.md` に記載された関数名・オプション名のみを使用すること。** 存在しない関数名を推測で生成してはならない。

- `github_info/docs/api.md` — GitHubREST の全関数と正確なオプション
- `claudecode_info/docs/api.md` — ClaudeCode の全関数と正確なオプション
- `NBAccess_info/docs/api.md` — NBAccess の全関数と正確なオプション

**その他のパッケージ（Maildb 等）にも `_info/docs/api.md` が存在する場合がある。** メール関連の操作では `maildb_info/docs/api.md` を参照し、存在しない場合は `skills/maildb-operations` スキルに従うこと。

api.md とこのファイルや skills の記載が矛盾する場合は **常に api.md を信頼** する。api.md よりソースコードが新しい場合はソースコードを直接確認する。

### 基盤パッケージの依存方向制約（必須）

**claudecode.wl と NBAccess.wl は他のパッケージ（maildb, GitHubREST 等）に一切依存してはならない。** 依存方向は常に一方向:

```
任意のパッケージ ──uses──→ claudecode.wl / NBAccess.wl
```

- 基盤パッケージに `Needs`/`Get`/シンボル参照で他パッケージへの依存を追加する → ❌ 禁止
- 基盤パッケージのシステムプロンプト (`$claudeMathPromptPrefix` 等) に特定パッケージ固有の情報を埋め込む → ❌ 禁止
- 他パッケージが基盤パッケージの API を使用する → ✅ 正しい方向

**ClaudeUpdatePackage / ClaudeCreatePackage でコード生成中に基盤パッケージの API 変更が必要と判断した場合:**
- コード生成を即座に中断し、必要な変更内容と理由を出力してユーザーの判断を仰ぐ。
- 基盤パッケージの変更を含むコードを自動生成してはならない。

詳細は `rules/11-core-package-dependency.md` を参照。

### パッケージキーワード自動注入機構

`$ClaudePackageKeywordMap` は外部パッケージがキーワードを登録するための Association である。ClaudeEval/ClaudeQuery のプロンプトにキーワードが含まれると、対応パッケージの `api.md` が自動注入される。

```mathematica
(* 外部パッケージが自身のロード時に登録する例 *)
If[AssociationQ[ClaudeCode`$ClaudePackageKeywordMap],
  ClaudeCode`$ClaudePackageKeywordMap["maildb"] =
    {"メール", "mail", "〆切", "showMails", ...}
];
```

- 基盤パッケージ側はキーワード→パッケージ名のマッピングのみ保持し、パッケージ固有ロジックを一切持たない。
- 各パッケージは `_info/docs/api.md` に自身の完全な API リファレンスを記載しておくこと。

### メール操作のセキュリティルーティング原則

メールの **privacy / PrivacyLevel フィールド（セキュリティレベル）が 0.5 を超えるメールは `$ClaudeModel`（クラウド LLM）に投入してはならない。** `$ClaudePrivateModel`（ローカル LLM）で処理すること。

- 正準のメールシステムは **SourceVault mail サブシステム**（`SourceVault_maildb.wl`）。本文は暗号化・ヘッダは平文+token（件名は設計上暗号化しない）。永続データの復号には `NBAccess`$NBCredentialBackend = "SystemCredential"` が必須（Memory backend だと別鍵で復号不可＝データ消失）。
- `SourceVaultSearchMailSnapshots[..., MaxPrivacy -> 0.5]` で公開メールのみに絞れる。snapshot の `Derived.PrivacyLevel` がルーティング基準。
- IMAP アカウント・所有者 identity・グループ重みは**ソースにハードコードせず** vault config（`SourceVaultRegisterMailAccount` 等）とユーザDB #1 に外部化する（rule 03）。
- 旧 `maildb.wl`（`maildb_legacy.wl`）の `mailAskLLM` 等はセキュリティレベルでモデルを自動分配する（移行参照）。
- 詳細は `skills/maildb-operations` スキルと `SourceVault_info/docs/`、設計前提は `rules/101-sourcevault-stage-status` の「暗号化・メール・identity サブシステム」節を参照。

## Wolfram Language 関数名検証ルール（必須）

**Mathematica に存在しない関数名・定数名・オプション名を推測で生成してはならない。** 

- `FileQ[path]` → ❌（正しくは `FileExistsQ[path]`）
- `DirectoryExists[path]` → ❌（正しくは `DirectoryQ[path]`）
- `StringEmpty[str]` → ❌（正しくは `str === ""`）
- api.md に記載されていないパッケージ関数やオプション → ❌

不確実な場合は `Names["*File*"]` での検索や `?FunctionName` でのドキュメント確認を行い、存在を確認してから使用すること。詳細は `rules/12-function-name-verification.md` を参照。

### PR ワークフローの正しいパターン

PR を作成する場合、以下の **いずれか** を使う。存在しない `GitHubCreateBranch`, `GitHubPushFile` 等を生成してはならない。

```mathematica
(* 推奨: 一発で refresh → ブランチ作成 → commit → PR *)
GitHubSubmitPullRequest["pkg", "PRタイトル", "コミットメッセージ",
  Body -> "PR本文"]

(* 手動: まず別ブランチにコミット、次に PR 作成 *)
GitHubRefreshAndCommit["pkg", "commit msg",
  Branch -> "feature/xxx", CreateBranch -> True]
GitHubCreatePullRequest["pkg", "PRタイトル",
  Branch -> "feature/xxx", Body -> "PR本文"]
```

### API エラー・利用制限ハンドリング（必須）

- API レスポンスの有効性判定には必ず `iIsAPIErrorResponse[response]` を使用する。
- エラー時はファイルに書き込まない（ドキュメント、ソースコード、要約等すべて）。
- 連続 API 呼び出しでは最初のエラーで以降をすべてスキップする（fail-fast）。
- エラー時はフォールバック表示で代替し、エラーメッセージ自体をデータとして保存しない。
- 詳細は `rules/90-api-error-handling.md` を参照。

## ClaudeEval のスケジューリング

- `StartTime -> Now + Quantity[3, "Hours"]` で遅延実行。
- `RepeatInterval -> Quantity[2, "Hours"]` で周期的に繰り返し実行。
  - `RepeatInterval -> {Quantity[1, "Hours"], 5}` で最大5回。
  - `TaskObject` が返るので `TaskRemove[]` で停止可能。
  - `RepeatInterval` は `ClaudeEval` のみの機能。`ClaudeUpdatePackage` 等には `StartTime` のみ。

### ScheduledTask・非同期処理の制約（必須）

claudecode は ScheduledTask ベースの非同期基盤を提供する。パッケージ開発では以下の2つの制約を厳守すること:

**A. ScheduledTask 内からの禁止操作**（ClaudeEval 経由で呼ばれる場合）:
- ❌ `ClaudeQuery` を ScheduledTask 内から呼ぶ → デッドロック
- ❌ 同一評価ブロック内で `ClaudeQuery` を2回以上呼ぶ → フリーズ
- ❌ `ExternalEvaluate["Python", ...]` → サブプロセスがブロック
- ✅ `LLMSynthesize[prompt]` / `URLRead[HTTPRequest[...]]` → 同期 HTTP で安全

**B. 独自 ScheduledTask 作成の禁止**:
- ❌ パッケージ内で `CreateScheduledTask` を使い UI ポーリングや FrontEnd 更新ループを構築する
- ✅ `iClaudeQueryAsyncWithProgress[]` で claudecode の共有ポーリング基盤に委譲する
- ✅ FrontEnd 通信を行わない純粋計算タスクは例外（ドキュメントに明記）
- ✅ PresentationListener のようにリアルタイム性が必要な場合も例外（ドキュメントに明記）

詳細は `rules/95-scheduled-task-safety.md` を参照。

### 複数 LLM 呼び出しの非同期処理: LLMGraph DAG（必須）

複数の LLM 呼び出しを依存関係を持たせて実行する場合（OCR→要約→保存 等）、
claudecode の **LLMGraph DAG フレームワーク** を使用すること:

- `LLMGraphDAGCreate[<|"nodes"->..., "taskDescriptor"->..., "onComplete"->...|>]` でジョブを作成・起動
- ノードは `iLLMGraphNode[id, type, category, deps, handler]` で定義
- `type`: `"sync"`（即時実行）/ `"claude-cli"`・`"python"`（StartProcess + 自動ポーリング）
- `taskDescriptor["categoryMap"]` でノードカテゴリを抽象カテゴリ（`"cli"`, `"cli-vision"`, `"process"`, `"sync"`）にマッピング
- 並列度は `$LLMGraphMaxConcurrency` がデフォルト。ジョブ固有オーバーライドは `taskDescriptor["maxConcurrency"]`
- ❌ 独自 ScheduledTask で LLM プロセスをポーリングする実装は禁止

詳細は `rules/95-scheduled-task-safety.md` セクション C を参照。

### 1 turn 内 tool call の並列実行: AsyncToolExec(Phase 32k Step 3)

`$UseClaudeRuntime = True` + `ClaudeRuntime\`$ClaudeRuntimeToolAsyncDefault = True` のとき、`iToolUseAndContinue` は hybrid 経路に入り、tool 呼び出しを sync / async に振り分けて async tool (web_search 等) を別 OS プロセスで並列実行する。

- **メインカーネル解放**: tool 実行中も別セル評価可能
- **3 秒間隔 polling**: 既存 `ClaudeRegisterPollingTick` 基盤を再利用、独自 ScheduledTask を作らない (rule 95 §B 違反を避ける)
- **`StartProcess` ベース**: Phase 32j v1 の SessionSubmit + ScheduledTask クラッシュ実績を回避
- **state machine**: Queue / Running / Collected の 3 段、MaxConcurrent=4

実証済みフラグ組み合わせ (3 種類のみ、それ以外は想定外):

| `$UseClaudeRuntime` | `$ClaudeRuntimeAsyncExecution` | `$ClaudeRuntimeToolAsyncDefault` | 用途 |
|---|---|---|---|
| False | True (default) | False (default) | claudecode 旧経路(常時) |
| True | False | True | DAG + Phase D 単独 (result11 で 54.4s 実証) |
| True | True (default) | True | DAG + Phase 32 + Phase D 統合(本流) |

詳細は `skills/async-tool-execution` および `rules/100-async-tool-execution.md`。デバッグは `skills/adapter-tool-flow-debugging` の症状カタログと §7 (AsyncToolExec の状態を見る) を参照。

## バックアップ・履歴管理

- `ClaudeBackupDataset["pkg"]` — パッケージのバックアップ履歴を Grid 表示。#0行でローカル最新版に復元可能。
- `ClaudeBackupDataset[]` — 全パッケージのバックアップ履歴を一括表示。
- `ClaudeDirectiveBackupDataset[]` — Claude Directives の更新履歴を Grid 表示。#0行で復元可能。
- `GitHubCommitDataset["pkg"]` — GitHub コミット履歴を Grid 表示。Pull で過去コミットに巻き戻し可能。#0行でローカル最新版に復元。
- いずれも起動時にローカル最新版のスナップショットを SHA-256 ハッシュ付きで保存する。
- Pull で巻き戻した後にファイルを編集していた場合、ローカル最新版への復元時に警告を表示する。

## データストアの破壊防止（SourceVault 運用開始後は必須）

SourceVault の運用が始まると、`<PrivateVault>/notebooks/` 配下のストア（`sources` / `snapshots` / `summaries` / `todos` / `review` / `lint` / `sync` / `relink`）は日々の作業記録そのものになり、開発初期のように `SourceVaultResetStore` で気軽に全削除して作り直すことはできなくなる。

SourceVault・NBAccess のストア書き込みコードを書く・直すときは **`rules/103-sourcevault-datastore-safety.md` を必ず読む**。要点:

- 破壊的操作（削除・上書き）は `DryRun` オプションを持ち既定を `True` にする。実変更は明示的な `DryRun -> False` のときだけ。
- ファイルの物理削除と非破壊マーク（`RelinkStatus` 等）は別オプションに分け、削除系オプションの既定は `False`。
- 全削除 API は二重の明示確認（`Confirm -> True` なしは DryRun）。
- 早期 return `Return[expr, Module]` は「最も内側の同名 `Module`」から抜ける。関数全体を抜けたい早期 return を内側 `Module[{tmp}, ...]` の中に書くと処理が後続に流れる（罠 #52）。
- レコードの同一性・実在性は派生 ID（パスのハッシュ）でなく実体（実パス・内容ハッシュ）で判定する。
- 多段照合は信頼度で「自動適用」と「レポートのみ」を分ける。
- 破壊的操作を `DryRun -> False` で実行する前に、必ず `DryRun -> True` の結果を人間が検証する。
- 書き込みは atomic write（`path.tmp` → 検証 → `RenameFile`）、戻り値に変更件数の集計を含める。
