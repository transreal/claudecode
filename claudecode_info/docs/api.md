# claudecode API リファレンス

LLM 向け API 仕様書。Claude Code CLI / Anthropic API / OpenAI API / LMStudio を統合した Mathematica パッケージ。

## グローバル変数

### $ClaudeModel
型: List | String, 初期値: {"claudecode", "claude-opus-4-7"}
Claude CLI に渡すモデル名。tuple {provider, model} 形式。provider は "claudecode" | "anthropic" | "openai" | "lmstudio"。

### $ClaudePrivateModel
型: List, 初期値: 未設定
秘密データ処理用のローカルモデル指定。AutoPrivate -> True 時に使用。
例: $ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}

### $ClaudeTestModel
型: List | String, 初期値: $ClaudeModel と同じ
分離検証用モデル。

### $ClaudeDocModel
型: List, 初期値: $iModelSonnet
ドキュメント生成・更新用モデル。Sonnet 系最新。

### $ClaudeTimeout
型: Integer, 初期値: 1200
ClaudeQuery/ClaudeEval のタイムアウト秒数。

### $ClaudeVerbose
型: Boolean, 初期値: False
詳細ログ出力フラグ。True で履歴コンパクション等の詳細ログを Messages に出力。

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code 起動時の作業ディレクトリ。.claude/CLAUDE.md, .claude/rules/, .claude/skills/ を読ませる。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれた CLAUDE.md のパス。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。

### $ClaudeFallbackModels
型: List, 初期値: {{"anthropic", $iModelOpus}, {"openai", "gpt-5.5"}}
フォールバックモデル優先順位。各要素は {"provider", "modelName"} または {"provider", "modelName", "url"}。

### $ClaudeSnapshots
型: String, 初期値: FileNameJoin[{$ClaudeWorkingDirectory, "snapshots"}]
LLMGraphDAG スナップショット保存ディレクトリ。

### $ClaudeDocRetryDelay
型: Integer, 初期値: 60
ドキュメント生成のリトライ待機秒数。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
ドキュメント生成の最大リトライ回数。

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースの最大文字数。

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval の再帰的生成の最大深度。0 で再帰禁止。

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
パッケージキーワード登録マップ。プロンプトにキーワードが含まれると対応 api.md を自動注入。
例: $ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒切"}

### $ClaudeEvalMode
型: String, 初期値: 未設定
ClaudeEval の動作モード。

### $ClaudeEvalHook
型: Function, 初期値: 未設定
ClaudeEval のフック関数。

### $ClaudeEvalAutoThreshold
型: Integer, 初期値: 未設定
ClaudeEval 自動実行の閾値。

### $ClaudeEvalVerbose
型: Boolean, 初期値: 未設定
ClaudeEval の詳細出力フラグ。

### $ClaudeEvalAutoLLMMinLength
型: Integer
LLM 自動実行の最小プロンプト文字数。

### $ClaudeEvalAutoLLMMinNewlines
型: Integer
LLM 自動実行の最小改行数。

### $claudecodeVersion
型: String
パッケージバージョン。

### $ClaudeRoutingProviders
型: List
ランタイムプロバイダールーティング設定。

### $UseClaudeRuntime
型: Boolean
ClaudeRuntime 使用フラグ。

### $ClaudeLastRuntimeId
型: String
直近に作成された Runtime の ID。

### $ClaudeRuntimeAsyncExecution
型: Boolean
コード実行を非同期化 (ParallelSubmit) するフラグ。

### $ClaudeRuntimeAsyncForce
型: Boolean
強制非同期実行フラグ。

### $ClaudeRuntimeAsyncSuppressInputEval
型: Boolean
入力セル評価を抑制するフラグ。

### $LLMGraphMaxConcurrency
型: Integer
LLMGraph の最大並列度。

### $LLMGraphAutoStopThreshold
型: Integer
LLMGraph 自動停止閾値。

### $ClaudeEditModesVersion
型: String
エディットモード機能のバージョン。

### $ClaudeEditModeAppendTagOpen
型: String
追記モードの開始タグ。

### $ClaudeEditModeAppendTagClose
型: String
追記モードの終了タグ。

### $ClaudeEditModeInsertTagClose
型: String
挿入モードの終了タグ。

### $ClaudePriorityModeUntil
型: DateObject
高優先モードの終了予定時刻。

## オプションシンボル

### Fallback
True で Claude Code 利用不可時に $ClaudeFallbackModels の各モデルを自動試行。デフォルト False。

### AutoPrivate
True で秘密変数アクセス時に Model -> $ClaudePrivateModel, PrivacySpec -> Automatic を自動付与。デフォルト False。

### AutoEvaluate
ClaudeEval/ClaudeWriteResponse 生成セルの自動実行制御。デフォルト True (ClaudeEval) / False (Write)。

### StartTime
ClaudeEval/ContinueEval の実行開始時刻 (DateObject)。例: Now + Quantity[3, "Hours"]。

### Timeout
API フォールバックのタイムアウト秒数。Automatic で 600 秒。

### TargetFiles
ClaudeReview 等の対象ファイルリスト。

### TargetFunctions
ClaudeReview 等の対象関数リスト。

### Mode
動作モード切替。

### DryRun
True で実際の変更を行わずシミュレート。

### Inherit
CreateClaudeSession で履歴を継承するか。デフォルト True。

### License
ClaudeCreateDocumentation/ClaudeUpdateDocumentation 用。"" でデフォルト MIT 自動挿入。

### Model
モデル指定。Automatic / {"provider","model"} / String。

### WebFetch
ClaudeQuery で Web 取得を許可するか。デフォルト False (課金あり、Fallback->True 必須)。

### WebSearch
ClaudeQuery で Web 検索を許可するか。デフォルト True (無料)。

### RepeatInterval
ClaudeEval の繰り返し実行間隔。例: Quantity[2, "Hours"] / {Quantity[1,"Hours"], 5}。

### PrivacySpec
プライバシー仕様。Automatic で秘密変数自動検出。

### Keywords
ClaudeAttach 用キーワード登録。リスト。

### Title
ClaudeAttach 用タイトル。

### Refetch
ClaudeAttach で URL 再取得するか。デフォルト False。

### Owner
GitHub リポジトリ owner 指定。

### Repository
GitHub リポジトリ名指定。

### Branch
ブランチ名指定。

### BaseBranch
ベースブランチ指定。

### References
ClaudeCreateDocumentation 用。URL や書籍名リスト。README.md に参考文献セクション追加。

### Demos
ClaudeCreateDocumentation 用。デモ URL リスト。README.md に反映。

### Disclaimer
ClaudeCreateDocumentation 用。免責事項文言リスト。

### Acknowledgments
ClaudeCreateDocumentation 用。謝辞文言リスト。

## クエリ系関数

### ClaudeQuery[prompt, opts] → String
Claude Code に prompt を送り応答文字列を返す (同期)。
Options: WebSearch -> True, WebFetch -> False, Fallback -> False, Timeout -> Automatic, Model -> Automatic, PrivacyLevel -> Automatic, AutoPrivate -> False

### ClaudeQuery[session, prompt, opts] → String
セッション履歴と直前の出力/エラーを考慮して回答。

### ClaudeQuery[{text, Image[...], File[path], ...}, opts] → String
マルチモーダル入力。画像/PDF/音声を API に直接送信。

### ClaudeQuerySync[prompt, opts] → String
WindowStatusArea に経過時間を表示する軽量同期版。セッション履歴・ノートブック書き込みなし。
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic

### ClaudeQueryBg[prompt, opts] → String
FrontEnd 操作・ScheduledTask 生成なしの同期問い合わせ。SocketListen ハンドラや ScheduledTask コールバック等の非同期コンテキストから安全に呼べる (rule 95)。
Options: Fallback -> False, Model -> Automatic, Timeout -> Automatic

### ClaudeQueryAsync[prompt, callback, nb, opts] → JobObject
非同期問い合わせ。完了時に callback[応答文字列] を呼ぶ。
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic
例: ClaudeQueryAsync["Hello", Print, EvaluationNotebook[]]

### ClaudeMath[task] → String
Mathematica コード生成に特化したプロンプトで Claude を呼び出す。

### ClaudeExtractCode[response] → String
Claude 応答から最初の ```mathematica ブロックを抽出。

### ClaudeExtractAllCode[response] → List
Claude 応答から全 ```mathematica ブロックをリストで返す。

### ClaudeWriteResponse[nb, text, opts] → Null
マークダウン形式テキストをノートブックのセルに展開。
Options: AutoEvaluate -> False

## 評価系関数

### ClaudeEval[task, opts] → Null
コードを非同期で生成・表示し、デフォルトセッションに履歴保存。
Options: AutoEvaluate -> True, StartTime -> Now, RepeatInterval -> None, Timeout -> Automatic, AutoPrivate -> False, Model -> Automatic, Fallback -> False
例: ClaudeEval[task, RepeatInterval -> {Quantity[1,"Hours"], 5}]
例: ClaudeEval[{"プロット作成", Dataset[...]}]

### ClaudeEval[{text, data, ...}, opts] → Null
テキスト・Dataset・Image・一般式の混在入力。

### ClaudeEval[session, task, opts] → Null
指定セッションに履歴保存。

### ContinueEval[opts] → Null
"エラーを修正してください" でデフォルトセッション継続。

### ContinueEval[instruction, opts] → Null
追加指示でデフォルトセッション継続。

### ContinueEval[session, instruction, opts] → Null
指定セッションで継続。Options: StartTime -> Now, Timeout -> Automatic

### ContinueUpdate[opts] → Null
直前の ClaudeUpdatePackage の結果を踏まえてバグ修正継続。
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now

### ContinueUpdate[instruction, opts] → Null
追加指示で継続。

### ContinueUpdate[{instruction, img}, opts] → Null
テキスト+画像で継続。

### ContinueUpdate[pkgName, instruction, opts] → Null
指定パッケージの直前の更新を継続。

### ClaudeSpec[task] → String
ノートブック内容からプログラム仕様を生成。

### ClaudeSpec[{task, image, ...}] → String
画像付き仕様生成。

### ClaudeDebug[codeOrFile, errorMsg] → String
デバッグ支援。エラーメッセージ付きでコード解析。

### ClaudeReview[args, opts] → String
コードレビュー。
Options: TargetFiles, TargetFunctions, Mode, DryRun

### ClaudeReviewChunked[args, opts] → String
チャンク分割レビュー。

## セッション管理

### CreateClaudeSession[name, opts] → Session
名前付きセッション作成。
Options: Inherit -> True

### CreateClaudeSession[session, opts] → Session
既存セッションの履歴を継承して新セッション。

### CreateClaudeSession[opts] → Session
デフォルト履歴継承の新セッション。

### ClaudeRestoreSession[] → Null
デフォルトセッションをリストア。

### ClaudeRestoreSession[name] → Null
指定名セッションをリストア。

### ClaudeListSessions[] → List
ノートブック内全セッション一覧。

### ClaudeDeleteSession[name] → Null
セッション削除。

### ClaudeDeleteSession[name, "All"] → Null
セッションと全履歴削除。

### ClaudeShowHistory[] → Null
デフォルトセッション履歴表示。

### ClaudeShowHistory[session|name] → Null
指定セッション履歴表示。

### ClaudeSessionStatus[] → Association
セッション状態取得。

### ClaudeCompactHistory[] → Null
履歴をコンパクト化。

### ClaudeHistorySize[] → Integer
履歴サイズ取得。

## アタッチメント

### ClaudeAttach[path, opts] → Null
ファイルをデフォルトセッションに添付。
Options: Keywords -> {}, Title -> None, Refetch -> False

### ClaudeAttach[url, opts] → Null
URL を PDF 化してキャッシュ添付。

### ClaudeAttach[session, path, opts] → Null
指定セッションに添付。

### ClaudeDetach[path] → Null
デフォルトセッションからデタッチ。

### ClaudeDetach[session, path] → Null
指定セッションからデタッチ。

### ClaudeAttachments[] → List
デフォルトセッションのアタッチメント一覧。

### ClaudeAttachments[session] → List
指定セッションのアタッチメント一覧。

### ClearAttachments[] → Null
デフォルトセッションの全アタッチメントクリア。

### ClearAttachments[session] → Null
指定セッションの全アタッチメントクリア。

## 機密データ

### MarkConfidential[var] → Null
変数を機密としてマーク。

### UnmarkConfidential[var] → Null
機密マーク解除。

### IsConfidential[var] → Boolean
機密判定。

### Confidential[expr] → ConfidentialWrapper
機密ラッパー。

### NonConfidential[expr] → expr
非機密ラッパー。

### ScanConfidentialCells[] → List
ノートブック中の機密セルを走査。

## レート制限

### ClaudeRateLimitStatus[] → Association | None
最後に検出された Claude CLI の rate-limit 情報を返す。検出なしなら None。
返り値キー: "Detected", "Source" ("rate_limit_event"|"result"|"legacy"), "RateLimitType", "ResetsAt", "ResetsAtUnix", "HttpStatus", "Message", "IsUsingOverage"

### ClaudeRateLimitClear[] → Null
保持された rate-limit 情報を手動クリア。

## Web 系

### ClaudeWebSearch[query, opts] → String
Web 検索 (無料)。

### ClaudeWebFetch[url, opts] → String
URL 取得 (課金、Fallback 必須)。

### WebFetch[url, opts] → String
ClaudeWebFetch のエイリアス。

### WebSearch[query, opts] → String
ClaudeWebSearch のエイリアス。

## UI / パレット

### ShowClaudePalette[] → Null
Claude パレットを表示。Provider/Model 切替ボタンあり。

### ClaudeQueryShowContext[] → Null
クエリコンテキスト表示。

### ClaudeShowAccessConfig[] → Null
アクセス設定表示。

### ClaudeStatus[] → Association
ステータス取得。

### ClaudeAbort[] → Null
実行中のクエリ中止。

## CLI / コマンド

### ClaudeCommand[command] → String
Claude Code CLI のスラッシュコマンドを実行。例: ClaudeCommand["/help"]

### ClaudeCheckSeparation[packageName] → Association
NBAccess 分離原則の違反を検査。

### ClaudeFixSeparation[packageName] → Null
分離原則違反を修正。

### ClaudePrepareCommit[opts] → String
Git コミットメッセージ生成。

## ドキュメント生成

### ClaudeCreateDocumentation[packageName, opts] → Null
パッケージドキュメント (api.md, README.md 等) を生成。
Options: References -> {}, Demos -> {}, Disclaimer -> {}, Acknowledgments -> {}, License -> "", Owner, Repository, Branch, Model

### ClaudeUpdateDocumentation[packageName, instruction, opts] → Null
既存ドキュメントを部分更新。
Options: References, Demos, Disclaimer, Acknowledgments, License, Model

## ディレクティブ管理

### ClaudeAddDirective[name, content, opts] → Null
ディレクティブ (.claude/rules/skills) を追加。

### ClaudeRestoreDirective[name] → Null
ディレクティブ復元。

### ClaudeListDirectives[] → List
ディレクティブ一覧。

### ClaudeUpdateDirective[name, content] → Null
ディレクティブ更新。

### ClaudeDirectiveBackupDataset[] → Dataset
バックアップ一覧。

### ClaudeSyncDirectives[] → Null
ディレクティブ同期。

## NotebookLLMGraph

### NotebookLLMGraph[nb] → Graph
ノートブックの LLM 呼び出しグラフ取得。

### NotebookLLMGraphPlot[nb] → Graphics
グラフ可視化。

### NotebookLLMGraphBuild[nb] → Graph
グラフ構築。

### NotebookLLMGraphNodes[nb] → List
全ノード取得。

### NotebookLLMGraphValidate[nb] → Association
グラフ検証。

### NotebookLLMGraphFetchResponse[node] → String
ノードの応答取得。

### NotebookLLMGraphSubSteps[node] → List
サブステップ取得。

### NotebookLLMGraphFetchL2[node] → List
L2 ノード取得。

### NotebookLLMGraphErrors[nb] → List
エラー一覧。

### NotebookLLMGraphUpdateL2Status[node, status] → Null
L2 ステータス更新。

### NotebookLLMGraphPlotL2[nb] → Graphics
L2 グラフ可視化。

### NotebookLLMGraphRerun[node, opts] → Null
ノード再実行。

### NotebookLLMGraphInvalidateDownstream[node] → Null
下流ノード無効化。

### NotebookLLMGraphSummary[nb] → Association
グラフサマリ。

### NotebookLLMGraphExtractThread[nb] → List
スレッド抽出。

### NotebookLLMGraphApplyThread[nb, thread] → Null
スレッド適用。

## LLMGraphExecute

### LLMGraphExecute[graph, opts] → Association
LLMGraph を実行。

### LLMGraphExecuteStatus[id] → Association
実行ステータス取得。

### LLMGraphExecuteCancel[id] → Null
実行キャンセル。

## LLMGraphDAG

### LLMGraphDAGCreate[graph, opts] → String
DAG ジョブ作成。ID を返す。

### LLMGraphDAGStatus[id] → Association
DAG ステータス取得。

### LLMGraphDAGCancel[id] → Null
DAG キャンセル。

### LLMGraphDAGStop[id] → Null
DAG 停止。

### LLMGraphDAGRetry[id, nodeId] → Null
ノード再試行。

### LLMGraphDAGRebuild[id] → Null
DAG 再構築。

### LLMGraphDAGFindByContext[context] → List
コンテキスト検索。

### LLMGraphDAGInspect[id] → Association
詳細検査。

### LLMGraphDAGMarkFailed[id, nodeId] → Null
ノードを失敗マーク。

### LLMGraphDAGSnapshot[id] → String
スナップショット作成。

### LLMGraphDAGRestore[snapshotId] → String
スナップショット復元。

### LLMGraphDAGListSnapshots[] → List
スナップショット一覧。

### LLMGraphDAGPlot[id] → Graphics
DAG 可視化。

### LLMGraphDAGMergeHistory[id1, id2] → Null
履歴マージ。

## Runtime

### ClaudeBuildRuntimeAdapter[opts] → Association
Runtime アダプタ Association を構築。
Options: "ExecutionTimeoutSeconds" -> 30 ("DefaultTimeoutSeconds" として保持される)
例: adapter = ClaudeBuildRuntimeAdapter["ExecutionTimeoutSeconds" -> 60]

### ClaudeStartRuntime[adapter, opts] → String
Runtime を起動し ID を返す。

### ClaudeEvalViaRuntime[runtimeId, task, opts] → Null
Runtime 経由で ClaudeEval を実行。

### ClaudeApproveProposal[runtimeId, proposalId] → Null
提案を承認して実行。

### ClaudeRuntimeSnapshot[runtimeId] → String
Runtime スナップショット作成。

### ClaudeRuntimeRestore[snapshotId] → String
Runtime スナップショット復元。

### ClaudeRuntimeListSnapshots[] → List
Runtime スナップショット一覧。

### ClaudeRegisterDAGRuntime[runtimeId] → Null
DAG Runtime 登録。

## 並列・スケジューリング

### ClaudeBeginHighPriority[duration] → Null
高優先モード開始。$ClaudePriorityModeUntil を設定。

### ClaudeEndHighPriority[] → Null
高優先モード終了。

### ClaudeBeginParallelKernels[] → Null
ParallelKernels を前置起動。

### ClaudeRegisterPollingTick[key, fn] → Null
共有ポーリングティックに関数登録。

### ClaudeUnregisterPollingTick[key] → Null
ポーリングティック登録解除。

### ClaudePollingTickKeys[] → List
登録済みキー一覧。

## ファイル処理

### NBFileTranslate[nb, opts] → Null
ノートブックファイル翻訳。

### ClaudeProcessFile[path, opts] → String
ファイル単位処理。

## エディットモード (Phase 36)

### ClaudeAppendBlockToPackage[packageName, block] → Null
パッケージ末尾にブロック追加。

### ClaudeInsertBeforeAnchorInPackage[packageName, anchor, block] → Null
アンカー直前にブロック挿入。

### ClaudeParseEditModeResponse[response] → Association
LLM 応答からエディットモード指示をパース。

### ClaudeAutoDetectEditMode[response] → String
応答から編集モードを自動検出。

### ClaudeBuildEditModePromptInstructions[mode] → String
エディットモード用プロンプト指示生成。

### ClaudeUpdatePackageWithMode[packageName, instruction, mode, opts] → Null
モード指定パッケージ更新。

## ユーティリティ

### cleanOutput[text] → String
出力テキストのクリーンアップ。

### stripANSI[text] → String
ANSI エスケープシーケンス除去。

## モデルルーティング動作

Model -> Automatic かつ PrivacyLevel <= 0.5: Claude Code CLI を使用 (Pro/Max サブスク内、課金なし)
Model -> Automatic かつ PrivacyLevel > 0.5: $ClaudePrivateModel を自動使用 (ローカル)
Model -> {"claudecode", "..."}: Claude Code CLI 経由
Model -> {"anthropic", "..."}: Anthropic API 直接 (課金)
Model -> {"openai", "..."}: OpenAI API (課金)
Model -> {"lmstudio", "...", "url"}: ローカル LMStudio (課金なし)

$ClaudeModel または Model が {anthropic|openai, ...} (有料プロバイダ) の場合、NBAccess 許可をチェック。許可なら CLI で進む、未許可は明示エラーで停止 (iClaudePaidModelGuard)。

## マルチモーダル入力パターン

ClaudeQuery / ClaudeEval / ContinueUpdate / ContinueEval / ClaudeSpec は List 入力でマルチモーダル可。
- Image[...]: 画像直接送信
- File[path]: ローカルファイル
- Dataset[...]: 表データ
- URL[...]: Web リソース
- 一般 Wolfram 式

例: ClaudeEval[{"このデータを可視化", Dataset[data], Image[img]}]