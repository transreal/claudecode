# claudecode API リファレンス

Claude Code CLI と Anthropic/OpenAI/LMStudio API を統合する Wolfram Language パッケージ。LLM 呼び出し、コード生成・評価、ドキュメント生成、セッション管理、LLM グラフ実行を提供する。

## クエリ関数

### ClaudeQuery[prompt, opts]
Claude Code に prompt を送り応答文字列を返す(同期)。
→ String
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic, WebSearch -> True, WebFetch -> False
例: `ClaudeQuery[{"画像を説明", Image[...], File["a.pdf"]}]` でマルチモーダル入力。
例: `ClaudeQuery[session, prompt]` でセッション履歴を考慮。

### ClaudeQuerySync[prompt, opts]
同期版。WindowStatusArea に経過時間を表示するが、セッション履歴やノートブック書き込みは行わない軽量版。
→ String
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic

### ClaudeQueryBg[prompt, opts]
FrontEnd 操作・ScheduledTask 生成なしで Claude に同期問い合わせ。SocketListen ハンドラや ScheduledTask コールバックから安全に呼べる(rule 95)。
→ String
Options: Fallback -> False, Model -> Automatic, Timeout -> Automatic, NonBlocking -> False

### ClaudeQueryAsync[prompt, callback, nb, opts]
非同期問い合わせ。完了時に `callback[応答]` を呼ぶ。
→ JobObject
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic

### ClaudeQueryAsyncSilent[prompt, callback, nb, opts]
ClaudeQueryAsync のサイレント版。WindowStatusArea 更新を抑制。
→ JobObject

### ClaudeEnsureSilentNotebook[nb] → Null
nb のサイレント実行設定を有効化する。

### ClaudeWriteResponse[nb, text, opts] → Null
マークダウン形式テキストをノートブックのセルとして展開する。
Options: AutoEvaluate -> False

### ClaudeMath[task] → String
Mathematica コード生成に特化したプロンプトで Claude を呼ぶ。

### ClaudeExtractCode[response] → String
応答から最初の ` ```mathematica ` ブロックを抽出。

### ClaudeExtractAllCode[response] → List
応答から全 ` ```mathematica ` ブロックをリストで返す。

### ClaudeQueryShowContext[prompt, opts] → String
プロンプトに付与される最終コンテキスト(CLAUDE.md・履歴等)を表示する診断用関数。

## コード評価

### ClaudeEval[task, opts]
タスクからコードを非同期生成・実行・表示する。
→ JobObject
Options: Fallback -> False, AutoPrivate -> False, AutoEvaluate -> True, Model -> Automatic, PrivacySpec -> Automatic, Timeout -> Automatic, Mode -> Automatic, DryRun -> False
例: `ClaudeEval["平均を計算", AutoPrivate -> True]` で秘密変数アクセス時にローカルモデルを使用。

### ContinueEval[task, opts] → JobObject
直前の ClaudeEval の文脈・出力を継承して追加タスクを実行。

### ContinueUpdate[opts] → JobObject
直前の応答をそのまま再評価/更新する。

### ClaudeSpec[task]
ノートブック内容からプログラム仕様書を生成。
→ String
`ClaudeSpec[{task, image, ...}]` で画像付き仕様生成。

### ClaudeDebug[opts] → JobObject
直前のエラーセルをデバッグする提案を生成。

### ClaudeReview[opts] → JobObject
ノートブックまたはコードのレビューを実施。

### ClaudeReviewChunked[opts] → JobObject
長大なコードをチャンク分割してレビュー。

## ドキュメント生成

### ClaudeCreateDocumentation[packageName, opts]
パッケージから README.md / api.md / guide ノートブックを新規生成。
→ String (生成パス) | $Failed
Options: References -> {}, Demos -> {}, Disclaimer -> {}, Acknowledgments -> {}, License -> "", Model -> Automatic, Owner -> "", Repository -> "", Branch -> "main", BaseBranch -> "main"

### ClaudeUpdateDocumentation[packageName, instruction, opts]
既存ドキュメントを差分更新する。
→ String | $Failed
Options: References -> {}, Demos -> {}, Disclaimer -> {}, Acknowledgments -> {}, License -> "", Model -> Automatic, TargetFiles -> All, Mode -> Automatic, DryRun -> False

## ディレクティブ管理

### ClaudeAddDirective[type, name, content, opts] → String
.claude/rules/ または .claude/skills/ にディレクティブファイルを追加。
Options: Mode -> "create"

### ClaudeUpdateDirective[type, name, content] → String
既存ディレクティブを更新。

### ClaudeRestoreDirective[type, name, version] → String
バックアップから復元。

### ClaudeListDirectives[opts] → List
登録済みディレクティブ一覧。
Options: Mode -> "all"

### ClaudeDirectiveBackupDataset[] → Dataset
バックアップ履歴を Dataset で返す。

### ClaudeSyncDirectives[opts] → List
ディレクティブを GitHub などと同期。

## セッション管理

### CreateClaudeSession[name, opts] → Association
新セッションを作成。
Options: Inherit -> None

### ClaudeRestoreSession[name] → Association
保存済みセッションを復元。

### ClaudeListSessions[] → List
セッション名リスト。

### ClaudeDeleteSession[name] → Null

### ClaudeShowHistory[session] → Null
セッションの履歴を表示。

### ClaudeSessionStatus[session] → Association

### ClaudeCompactHistory[session, opts] → Association
履歴を要約圧縮。

### ClaudeHistorySize[session] → Integer

### ClaudeClearAllHistory[] → Null
全履歴クリア。

## 添付ファイル

### ClaudeAttach[spec, opts] → List
ファイル/URL を現在のセッション添付に追加。
Options: Keywords -> {}, Title -> "", Refetch -> False

### ClaudeDetach[spec] → List

### ClaudeAttachments[] → List
添付一覧。

### ClearAttachments[] → Null

## レート制限・状態

### ClaudeRateLimitStatus[] → Association
### ClaudeRateLimitClear[] → Null
### ClaudeStatus[] → Association
### ClaudeAbort[] → Null
### ClaudeCommand[cmd, opts] → String
任意の Claude CLI コマンドを実行。

### ClaudeShowAccessConfig[] → Null
アクセス許可構成を表示。

### ClaudeCheckSeparation[packageName] → Association
パッケージの公開/非公開分離を検査。

### ClaudeFixSeparation[packageName, opts] → JobObject
ClaudeCheckSeparation の結果を基に修正。

## 機密データ

### MarkConfidential[sym] → Null
シンボルを機密としてマーク。

### UnmarkConfidential[sym] → Null

### IsConfidential[sym] → True|False

### Confidential[expr] → Confidential[expr]
機密ラッパ。

### NonConfidential[expr] → expr

### ScanConfidentialCells[nb] → List
ノートブック中の機密セルを列挙。

## Web 検索/取得

### ClaudeWebSearch[query, opts] → String
### ClaudeWebFetch[url, opts] → String
### WebSearch[query, opts] → String
### WebFetch[url, opts] → String

## NBFile・コミット

### NBFileTranslate[spec, opts] → String
ノートブックファイル仕様を翻訳。

### ClaudeProcessFile[path, instruction, opts] → String
ファイルに対する指示処理。

### ClaudePrepareCommit[opts] → String
変更要約からコミットメッセージを生成。

## クラウド送信プリフライト

### ClaudeCloudSendPreflightDecision[ctx] → Association
クラウド送信前の許可判定。

### ClaudeCloudSendPreflightError[ctx] → String|Null
### ClaudeCloudSendPreflightFailure[ctx] → Association|Null
### ClaudeCloudSendPreflightGuardDryRun[ctx] → Association
### ClaudeCloudSendPreflightAudit[opts] → Dataset
### ClaudeCloudSendPreflightLog[] → List
### ClaudeCloudSendPreflightLogClear[] → Null
### ClaudeCloudSendPreflightLogSummary[] → Association
### ClaudeCloudSendPreflightLogDataset[] → Dataset
### ClaudeCloudSendPreflightFailureCell[failure] → Cell

## パレット・UI

### ShowClaudePalette[] → NotebookObject
Claude 操作パレットを開く。

## ランタイム/トランザクション

### ClaudeBuildRuntimeAdapter[opts] → Association
ランタイム実行アダプタを構築。
Options: ExecutionTimeoutSeconds -> 30, DefaultTimeoutSeconds -> 30

### ClaudeStartRuntime[adapter, opts] → Association
ランタイム開始。

### ClaudeEvalViaRuntime[task, adapter, opts] → Association
ランタイム経由で ClaudeEval 実行。

### ClaudeApproveProposal[id] → Association
AwaitingApproval 状態の提案を承認。

### ClaudeRuntimeSnapshot[id] → String
### ClaudeRuntimeRestore[snapshotId] → Association
### ClaudeRuntimeListSnapshots[] → List
### ClaudeRegisterDAGRuntime[name, adapter] → Null

## LLM グラフ (Notebook 単位)

### NotebookLLMGraph[nb] → Association
### NotebookLLMGraphBuild[nb, opts] → Association
### NotebookLLMGraphPlot[nb, opts] → Graphics
### NotebookLLMGraphPlotL2[nb, opts] → Graphics
### NotebookLLMGraphNodes[nb] → List
### NotebookLLMGraphValidate[nb] → Association
### NotebookLLMGraphFetchResponse[nb, nodeId] → String
### NotebookLLMGraphSubSteps[nb, nodeId] → List
### NotebookLLMGraphFetchL2[nb, nodeId] → Association
### NotebookLLMGraphErrors[nb] → List
### NotebookLLMGraphUpdateL2Status[nb, nodeId, status] → Null
### NotebookLLMGraphRerun[nb, nodeId, opts] → JobObject
### NotebookLLMGraphInvalidateDownstream[nb, nodeId] → Null
### NotebookLLMGraphSummary[nb] → Association
### NotebookLLMGraphExtractThread[nb, nodeId] → List
### NotebookLLMGraphApplyThread[nb, thread] → Null

## LLM グラフ DAG 実行

### LLMGraphExecute[graph, opts] → Association
### LLMGraphExecuteStatus[id] → Association
### LLMGraphExecuteCancel[id] → Null
### LLMGraphDAGCreate[nodes, opts] → String
### LLMGraphDAGStatus[id] → Association
### LLMGraphDAGCancel[id] → Null
### LLMGraphDAGStop[id] → Null
### LLMGraphDAGRetry[id, nodeId] → Null
### LLMGraphDAGRebuild[id] → Null
### LLMGraphDAGFindByContext[ctx] → List
### LLMGraphDAGInspect[id] → Association
### LLMGraphDAGMarkFailed[id, nodeId, reason] → Null
### LLMGraphDAGSnapshot[id] → String
### LLMGraphDAGRestore[snapshotId] → String
### LLMGraphDAGListSnapshots[] → List
### LLMGraphDAGPlot[id] → Graphics
### LLMGraphDAGMergeHistory[ids] → Association

## 編集モード (Phase 36)

### ClaudeAppendBlockToPackage[packageName, block, opts] → String
パッケージ末尾にブロックを追記。

### ClaudeInsertBeforeAnchorInPackage[packageName, anchor, block, opts] → String
アンカー直前にブロックを挿入。

### ClaudeParseEditModeResponse[response] → Association
編集モードタグ付き応答をパース。

### ClaudeAutoDetectEditMode[response] → String
応答から編集モードを自動判定。

### ClaudeBuildEditModePromptInstructions[mode] → String

### ClaudeUpdatePackageWithMode[packageName, instruction, mode, opts] → String

## ポーリング/優先度

### ClaudeRegisterPollingTick[key, fn] → Null
共有ポーリングタスクに tick 関数を登録。

### ClaudeUnregisterPollingTick[key] → Null
### ClaudePollingTickKeys[] → List
### ClaudeBeginHighPriority[seconds] → Null
### ClaudeEndHighPriority[] → Null
### ClaudeBeginParallelKernels[opts] → Null
ParallelKernels を前置起動。

## ユーティリティ

### cleanOutput[s] → String
ANSI/制御文字を除去。

### stripANSI[s] → String

## グローバル変数

### $ClaudeModel
型: {String, String} | String, 初期値: {"claudecode", "claude-opus-4-7"}
使用モデルを {provider, modelName} で指定。provider は "claudecode" | "chatgptcodex" | "anthropic" | "openai" | "lmstudio"。

### $ClaudePrivateModel
型: {String, String, String}, 初期値: ローカル LM Studio 設定
AutoPrivate -> True 時に使用するローカルモデル。
例: `$ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}`

### $ClaudeTestModel
型: String|List, 初期値: $ClaudeModel と同じ
分離検証用モデル。

### $ClaudeFallbackModels
型: List, 初期値: {{"anthropic", $iModelOpus}, {"openai", "gpt-5.5"}}
フォールバック優先順位。各要素は {provider, model} または {provider, model, url}。

### $ClaudeTimeout
型: Integer, 初期値: 1200
タイムアウト秒数。

### $ClaudeVerbose
型: Boolean, 初期値: False
詳細ログ出力。

### $ClaudeMDPath
型: String, 初期値: ""
CLAUDE.md のパス。

### $ClaudeMDContent
型: String, 初期値: ""
CLAUDE.md の内容。

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code 作業ディレクトリ。

### $OpenaiWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "OpenAI Working"}]

### $ChatgptWorkingDirectory
型: String
ChatGPT Codex 用作業ディレクトリ。

### $ChatgptCodexExe
型: String
ChatGPT Codex CLI 実行パス。

### $ChatgptAccessibleDirs
型: List
Codex CLI に許可する追加ディレクトリ。

### $ChatgptCodexHomeDirectory
型: String

### $ChatgptCodexPermissionProfile
型: String

### $ChatgptCodexApprovalPolicy
型: String

### $ChatgptCodexModel
型: String|Automatic

### $ChatgptCodexHarnessMode
型: String

### $ChatgptCodexRetainTempProjects
型: Boolean

### $ChatgptCodexSourceExposureMode
型: String

### $ClaudeCLIHarnessMode
型: String

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリ。NotebookDirectory 初回使用時はダイアログで許可確認。

### $ClaudeSnapshots
型: String, 初期値: FileNameJoin[{$ClaudeWorkingDirectory, "snapshots"}]
DAG スナップショット保存先。

### $ClaudeDocRetryDelay
型: Number, 初期値: 60
ドキュメント生成リトライ待機秒。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースの最大文字数。

### $ClaudeDocModel
型: String|List, 初期値: $iModelSonnet
ドキュメント生成用モデル。

### $ClaudeEvalMode
型: Symbol, 初期値: Automatic
### $ClaudeEvalHook
型: Function|None
### $ClaudeEvalAutoThreshold
型: Number
### $ClaudeEvalVerbose
型: Boolean
### $ClaudeEvalAutoLLMMinLength
型: Integer
### $ClaudeEvalAutoLLMMinNewlines
型: Integer
### $ClaudeEvalNaturalDispatch
型: Boolean
### $ClaudeEvalNaturalVerbose
型: Boolean
### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval の再帰最大深さ。

### $claudecodeVersion
型: String

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
パッケージ別キーワード登録。プロンプトに該当キーワードを含むと api.md がコンテキスト注入される。

### $LLMGraphMaxConcurrency
型: Integer
LLM グラフ DAG の最大同時実行数。

### $LLMGraphAutoStopThreshold
型: Number

### $ClaudeRoutingProviders
型: List
ルーティング対象プロバイダ一覧。

### $UseClaudeRuntime
型: Boolean
ランタイム経由実行フラグ。

### $ClaudeLastRuntimeId
型: String

### $ClaudeRuntimeAsyncExecution
型: Boolean
コード実行を ParallelSubmit で非同期化。

### $ClaudeRuntimeAsyncForce
型: Boolean

### $ClaudeRuntimeAsyncSuppressInputEval
型: Boolean

### $ClaudeSnapshots
DAG スナップショットパス(再掲)。

### $iMediaMaxImageSize
型: Integer
マルチモーダル送信時の画像最大サイズ。

### $ClaudePriorityModeUntil
型: AbsoluteTime|None
高優先度モード終了時刻。

### $ClaudeCloudSendPreflightLog
型: List
クラウド送信プリフライト履歴。

### $ClaudeCloudSendPreflightLogMaxLength
型: Integer

### $ClaudeCloudSendPreflightLogFile
型: String
永続化先ファイル。

### $ClaudeCloudSendPreflightContextResolver
型: Function
コンテキスト解決関数。

### $ClaudeCloudSendRoutePolicy
型: Association
ルートラベルポリシー。

### $ClaudeEditModesVersion
型: String

### $ClaudeEditModeAppendTagOpen
型: String
### $ClaudeEditModeAppendTagClose
型: String
### $ClaudeEditModeInsertTagClose
型: String

## オプションシンボル

以下は各関数で使用される公開オプション名。

### Fallback
True で Claude Code 利用不可時にフォールバックモデルへ切替。

### AutoPrivate
True で秘密変数アクセス時に $ClaudePrivateModel + PrivacySpec -> Automatic を自動付与。

### AutoEvaluate
ClaudeWriteResponse でセル書き込み後に自動実行するか。

### StartTime
ジョブ開始時刻指定。

### Timeout
秒単位のタイムアウト。Automatic で $ClaudeTimeout 使用。

### TargetFiles
ClaudeUpdateDocumentation の更新対象ファイル指定 (All | {"README.md", "api.md", ...})。

### TargetFunctions
レビュー/分離検証対象の関数群。

### Mode
動作モード切替 ("create" | "update" | "auto" など)。

### DryRun
True で実際の書き込み/実行を行わず計画のみ返す。

### Inherit
CreateClaudeSession で親セッション継承。

### License
ドキュメント生成時のライセンス指定。"" で GitHubREST 既定。

### Model
モデル指定。Automatic | "modelName" | {"provider", "modelName"} | {"provider", "modelName", "url"}。

### WebFetch
True で Web フェッチ許可(課金あり、Fallback -> True 必須)。

### WebSearch
True で Web 検索許可(無料、デフォルト True)。

### RepeatInterval
ポーリング間隔秒。

### PrivacySpec
プライバシ仕様 (Automatic | レベル数値 | リスト)。

### Keywords
ClaudeAttach のキーワードタグ。

### Title
添付の表示名。

### Refetch
True で URL 添付を再取得。

### Owner
GitHub オーナー名。

### Repository
GitHub リポジトリ名。

### Branch
GitHub ブランチ名。

### BaseBranch
ベースブランチ名。

### References
ドキュメントの参考文献リスト。

### Demos
デモ動画/使用例 URL リスト。

### Disclaimer
免責事項テキストリスト。

### Acknowledgments
謝辞テキストリスト。

### PrivacyLevel
0.0(機密でない)〜1.0(機密)。0.5 超で $ClaudePrivateModel を自動使用。

### NonBlocking
ClaudeQueryBg を非ブロッキング実行とするフラグ。

## 関連パッケージ

- [NBAccess](https://github.com/transreal/NBAccess) — ノートブック読み書き・プライバシ管理
- [ClaudePackageManager](https://github.com/transreal/ClaudePackageManager) — パッケージ管理機能(ClaudeBackupDataset/ClaudeRestorePackage/ClaudeCreatePackage/ClaudeUpdatePackage/ClaudeConvertToPaclet 等を移管)
- [ClaudeRuntime](https://github.com/transreal/ClaudeRuntime) — ランタイム実行基盤
- [ClaudeOrchestrator](https://github.com/transreal/ClaudeOrchestrator) — 複数 LLM 呼び出しのオーケストレーション
- [SourceVault](https://github.com/transreal/SourceVault) — プロバイダ/モデル登録の単一情報源
- [NotebookExtensions](https://github.com/transreal/NotebookExtensions)
- [PresentationListener](https://github.com/transreal/PresentationListener)