# Claude Directives

Wolfram Language / Mathematica 開発環境における Claude Code 用ディレクティブ一式。
claudecode.wl・NBAccess.wl・github.wl の3つの基盤パッケージと連携し、
ノートブック操作・パッケージ管理・GitHub 連携・機密データ保護の設計原則とベストプラクティスを定義する。

## 構成

```
Claude Directives/
  CLAUDE.md                  ← メインディレクティブ（セッション方針・操作ルール・参照先の集約）
  README.md                  ← このファイル
  rules/                     ← 絶対に破ってはいけない設計・安全・アクセス制約
    00-autoeval-prohibited.md   自動実行禁止操作（AutoEvaluate 禁止リスト）— 最優先ルール
    01-wolfram-general.md       Wolfram Language 基本制約
    02-math-typeset.md          数式タイプセットルール
    10-nbaccess.md              NBAccess 分離原則・セル直接操作禁止・ボタン再実行防止
    11-core-package-dependency.md 基盤パッケージの依存方向制約
    12-function-name-verification.md Mathematica 関数名・定数名の検証制約
    20-api-key-security.md      API キー管理・SystemCredential 直接使用禁止
    30-encoding-safety.md       UTF-8 エンコーディング・正規表現・JSON ファイル書き込み (ExportString RawJSON は ISO8859-1) の安全ルール
    40-pde-constraints.md       PDE モデリング制約
    50-file-path.md             ファイルパス解決ルール
    55-nbdir-access.md          NotebookDirectory アクセス制御
    60-confidential-structure.md 機密データ構造・Confidential ラッピング制約
    70-external-language-output.md R/Python 等の外部言語出力制約
    80-package-operations.md    パッケージ操作制約（ClaudeUpdatePackage 必須等）
    81-cuda-package-operations.md CUDA パッケージ操作制約
    85-safe-merge.md            パッケージ更新マージ安全性制約
    90-api-error-handling.md    API エラー・利用制限ハンドリング
    95-scheduled-task-safety.md ScheduledTask・非同期処理の安全制約（A-E: デッドロック防止/独自タスク禁止/LLMGraph DAG/deferred sync runState/LMStudio、F: Front End API 不可視と Memory Registry Fallback）
    96-web-search-recommendation.md Web 検索推奨ルール
    99-adapter-tool-flow.md     adapter 経由 tool-based ClaudeEval の実装ルール（R1〜R7）
    100-async-tool-execution.md AsyncToolExec(Phase 32k Step 3 Phase A〜D2)の必須ルール
    101-sourcevault-stage-status.md SourceVault.wl 開発時の前提制約 (paths 制約: SourceVault*.wl / sourcevault*.md)。Phase 35 依存・iSanitizeForJSON 必須・ReadByteArray 経路必須等

  skills/                    ← 特定タスクの具体手順とパターン集
    wolfram-general/            Wolfram Language コーディング手順・出力方針
    notebook-path-policy/       ファイルパス解決パターン
    nbaccess-notebook-access/   NBAccess API リファレンスと推奨パターン
    nbaccess-separation-check/  NBAccess 分離原則の検証・修正手順（静的走査+LLM判定）
    api-key-handling/           API キー取得の正しい実装手順
    wl-encoding-and-regex/      `.wl` ソース内のエスケープ (`\:XXXX`)・正規表現の検証手順
    wl-runtime-byte-io/         実行時の文字列⇔バイト変換 (HTTP ボディ / JSON ファイル I/O)。ExportString["RawJSON"] (→ISO8859-1) と WriteRawJSONString (→UTF-8) の戻り値エンコード差、二重 encode 回避 (罠 #55)、HTTPRequest Body に ByteArray
    pde-modeling/               PDE 実装ステップ
    confidential-data-handling/ 機密データのラッピング手順
    confidential-structure-probe/ 秘密変数の構造調査と ContinueEval 連携手順
    external-language-output/   R/Python 等の外部言語コード出力パターン
    doc-generation/             ドキュメント生成の継続・README 構造ルール
    github-operations/          GitHub パッケージ管理・PR管理・Fallback・ボタン再実行防止
    package-merge-pattern/      LLM レスポンスによるパッケージ部分更新のマージ・安全検証パターン
    maildb-operations/          maildb パッケージの API 使用パターン
    system-open/                SystemOpen によるファイル・フォルダ・ノートブックの開き方
    adapter-tool-flow-debugging/ adapter 経路 ClaudeEval の異常診断手順
    async-tool-execution/       AsyncToolExec(Phase 32k Step 3)の設計・運用・デバッグ
    runtime-orchestrator-boundary/ ClaudeRuntime と ClaudeOrchestrator の責務境界
    package-hook-installation-patterns/ 既存パッケージの公開シンボルに hook を装着する安全テンプレ (DownValues swap / Memory Registry Fallback)
    llm-prompt-template-override/ 既存 LLM prompt template に外部からドキュメント・指示を注入する prompt engineering パターン (XML タグ + placeholder 置換)
    claudecode-cli-vision/      claudecode.wl Phase 35 で claudecode CLI 経路で multimodal/vision を有効化する設計 (iClaudeQueryBgAPIMultimodal の 1 行リダイレクト + 既存 iNormalizePrompt の画像対応)
    ocr-backend-design/         SourceVault Stage 4C の 3 backend OCR (ClaudeVision/TextRecognize/Custom) 設計。上下分割+30px overlap、Mode/ForceOCR、診断機構 (OCRAttempted/OCRFailReasons/Verbose)
    llm-extraction-pipeline/    LLM 構造化抽出パイプライン設計。Schema 駆動 prompt 構築、5 段階 JSON parse fallback (bracket counting/partial recovery)、iSanitizeForJSON
    jsonl-store-pattern/        Append-only JSONL + 3 重インデックス (master + by-X) パターン。Windows 罠 #20 (ReadList) 対応の ReadByteArray 経路、安全な OpenAppend、StoreStatus debug
    claim-dedup-and-compact/    SourceVault Stage 6a の claim dedup + Compact 設計。by-source scope dedup、最古残し DeleteDuplicatesBy、Windows 対応 atomic write (path.tmp → DeleteFile → RenameFile)、.bak.<ISODateTime> backup
    evidence-bundle-design/     SourceVault Stage 6c の Evidence Bundle 設計。生成物 → source/snapshot/claim 依存記録、snapshot LifecycleStatus 集約による自動 stale 検出、bundles/<bundleId>.json ストレージ
    snapshot-lifecycle-and-diff/ SourceVault Stage 8 の snapshot lifecycle + vN diff 設計。page-hashes.json 活用、lazy passive consumer による Bundle 自動 stale 化、events/source-events.jsonl event log
    nbauthorize-2-stage-decisions/ SourceVault Stage 6d の NBAuthorize 2 段階統合設計。SourceVaultExtract に sendDecision + persistDecision、SourceVaultContext は RequireApproval も block、iSpecFromClaim、AccessDecisions レスポンス
    compiled-registry-and-seed/  SourceVault Stage 6b の Compiled Registry + Seed bootstrap 設計。seeds/ + compiled/{public,private}/、SourceVaultLookup / Resolve / ClaudeResolveModel、優先順位 sort、Stage 1 旧定義削除の経緯
    notebook-management-extraction/ SourceVault Stage 9 P0 + P1 の Notebook 拡張設計。Safe parse (HoldComplete + whitelist)、TodoItem 抽出、TaggingRules > StrikeThrough 優先順位、Header / Todo 状態の独立保存、7 種 lint、deterministic FindNotebooks クエリ、SourceVaultMarkTodo、SourceVaultNotebookSummary、mtime cache、MakeExpression 第一選択化
    sourcevault-sync-relink-uuid/ SourceVault の notebook source 鮮度管理・移動追跡・UUID 同定 (notebook-management-extraction から分離)。SourceVaultSync (mtime 鮮度トークン)、SourceVaultRelinkSources (UUID / 内容ハッシュ / ファイル名の 3 段照合、シンボリックパス解決で別 PC のパス差を誤検出しない)、Notebook UUID 埋め込み (TaggingRules、非破壊)
    nbaccess-semantic-api/      NBAccess Stage 9 P1 で追加された semantic API 7 個 (NBReadHeader / NBReadTodos / NBFindCellByPredicate + 書き込み系 4 個) の設計詳細。FrontEnd 不要のファイル直接編集、AccessLevel RBAC + DryRun、CellPath、Header フィルタ、NBReadHeader 3 経路 fallback、罠 #26-#28 対応
    claudeeval-security-guard-placement/ ClaudeEval/ClaudeQuery にセキュリティ・プライバシーガードを追加するときの配置位置。$UseClaudeRuntime=True で Runtime Bridge 経由になるとバイパスされる落とし穴、Deny は最前段 (dispatch 前)・Substitute は共通入口
```

## 主要な設計原則

### NBAccess 分離原則 (`rules/10-nbaccess.md`)
ノートブックのセルへの直接アクセスを禁止し、すべて NBAccess の公開 API 経由で操作する。
`NotebookWrite`, `CellPrint`, `EvaluationCell[]`, `SelectionMove`, `CurrentValue[..., TaggingRules]` 等の直接使用は、NBAccess.wl と NotebookExtensions.wl を除き一切認めない。

### 基盤パッケージの依存方向制約 (`rules/11-core-package-dependency.md`)
claudecode.wl と NBAccess.wl は他のパッケージ（maildb, GitHubREST 等）に一切依存してはならない。依存方向は常に一方向: 任意のパッケージ → 基盤パッケージ。

### ScheduledTask・非同期処理の安全制約 (`rules/95-scheduled-task-safety.md`)
ScheduledTask に関する2つの制約を統合: (A) ClaudeEval の ScheduledTask チェーン内から ClaudeQuery / ExternalEvaluate を呼ぶことの禁止（デッドロック防止）、(B) パッケージが UI ポーリング用に独自の CreateScheduledTask を作成することの禁止（動的評価オーバーフロー防止）。FrontEnd 通信を行わない純粋計算タスクや、リアルタイム性が必要なインタラクティブプログラムは例外だが、ドキュメントに明記が必要。 さらに §F として **scheduled task コンテキスト (LLMGraph DAG worker 等) での Front End API 不可視性** ルールを追加: `EvaluationNotebook[]` / `SelectedNotebook[]` などは scheduled task 経路では主 notebook を返さない。Notebook TaggingRule 経由のコンテキスト共有が必要な hook は **Memory Registry Fallback** パターン (Private 変数で並行記録) を必須とする (SourceVault A5 hook で実証)。

### AsyncToolExec 経路の必須ルール (`rules/100-async-tool-execution.md`)
`$UseClaudeRuntime = True` 経路で 1 turn 内に複数 tool (web_search 等) を別 OS プロセスで並列実行する Phase 32k Step 3 (Phase A〜D2) の規範。`ParallelSubmit` / `SessionSubmit` / 独自 `ScheduledTask` を禁止し `StartProcess` + 既存 polling tick 基盤を使うこと、`AsyncToolExecScheduled` 返却時の callback 早期 return、`Index` キーによる tool 順序保持、API key の file 経由など 11 ルール。詳細手順は `skills/async-tool-execution`。

### SourceVault.wl 開発前提 (`rules/101-sourcevault-stage-status.md`)
`SourceVault*.wl` / `sourcevault*.md` 編集時の paths 制約付き短 rule。**Stage 9 P1 完成** (`v2026-05-19-stage-9-p1-step8-nbreadheader-boxdata-filter`、Stage 1〜5 + 6a/6b/6c/6d/8 + 9 P0 + 9 P1)、claudecode.wl は **Phase 35 以降必須**、NBAccess.wl は **5471 行 → 6436 行に拡張** (semantic API 7 個追加)。JSONL/JSON append 時の `iSanitizeForJSON` 必須、読み込みは `ReadByteArray` 経路必須 (罠 #20)、検索 API は `iEnsureRoots[]` 必須、**Wolfram 文字列リテラル内の Unicode 文字は `\:XXXX` で書く** (罠 #11、累計 1107 件混入の最大エラー源)、**`\:` の後は必ず 4 桁 hex** (罠 #11 補足)、**Stage 8 連動**: snapshot Stale → Bundle 自動 stale、**Stage 6d 2 段階 authorization**: sendDecision + persistDecision、**Stage 6b Registry**: compiled → seed fallback、ClaudeResolveModel 互換 wrapper、**Stage 9 Safe Parse**: HoldComplete + whitelist で notebook header を評価せずに取り出し、Todo Status は TaggingRules > StrikeThrough > Default 優先順位、Header Status と Todo cell 状態は独立保存して合成 lint で判定、**Stage 9 P1 拡張**: SourceVaultMarkTodo (NBAccess `NBWriteTodoStatus` 薄ラッパー)、mtime ベース cache (`SourceVaultIndexNotebook[path]` の `"Cached"` / `"SourceMTime"` / `"ForceReindex"`)、Header parser MakeExpression 第一選択化 (副作用回避)、NBReadHeader 3 経路 fallback (Notebook TaggingRules → Cell TaggingRules → BoxData MakeExpression) + `iNBIsHeaderLikeAssoc` Header フィルタ、書き込み系 API は AccessLevel >= 0.7 必須 + default DryRun = True + atomic write (tmp + Rename)、**罠 #26-#28** 追加 (CellGroupData ネスト、Module+HoldComplete のローカル変数残存、ImportString RawJSON Windows path 失敗)。詳細設計は `skills/ocr-backend-design`, `skills/llm-extraction-pipeline`, `skills/jsonl-store-pattern`, `skills/claim-dedup-and-compact`, `skills/evidence-bundle-design`, `skills/snapshot-lifecycle-and-diff`, `skills/nbauthorize-2-stage-decisions`, `skills/compiled-registry-and-seed`, `skills/notebook-management-extraction`, `skills/nbaccess-semantic-api`, `skills/claudecode-cli-vision`。

### Fallback 絶対順守要件 (`rules/90-api-error-handling.md`)
`Fallback -> True` を明示的に指定しない限り、LLM のレート制限エラー時に代替処理を行ってはならない。エラーは `Failure[...]` として上位に伝播させ、処理を確実に停止する。エラーメッセージをデータとして利用する（リポジトリ名やファイル内容に変換する等）ことは禁止。

### パッケージ操作制約 (`rules/80-package-operations.md`)
パッケージの更新は `ClaudeUpdatePackage` 経由で行い、`Import`/`Export` による手動読み書きは禁止。関数名は `_info/docs/api.md` に記載されたもののみ使用し、推測で生成しない。

## インストール

このディレクトリを `$packageDirectory` に配置します。claudecode.wl 関数が自動的にディレクティブを検出・活用します。

```
$packageDirectory/
  Claude Directives/
    CLAUDE.md
    rules/
      00-autoeval-prohibited.md
      01-wolfram-general.md
      ...
    skills/
      wolfram-general/SKILL.md
      nbaccess-notebook-access/SKILL.md
      ...
```

GitHub 連携で `Claude Directives` フォルダをリポジトリに含める場合:

```mathematica
GitHubCreateRepository["claudecode", ExtraDirectories -> {"Claude Directives"}]
```

## 基盤パッケージとの関係

| パッケージ | 役割 | 主な関連ルール |
|---|---|---|
| `NBAccess.wl` | ノートブックセルアクセスの一元化層 | `rules/10-nbaccess.md` |
| `claudecode.wl` | Claude Code CLI 連携・パッケージ管理・非同期タスク管理 | `rules/80-package-operations.md`, `rules/90-api-error-handling.md`, `rules/95-scheduled-task-safety.md` |
| `github.wl` | GitHub REST API 連携・リポジトリ管理 | `skills/github-operations/SKILL.md`, `rules/90-api-error-handling.md` |
