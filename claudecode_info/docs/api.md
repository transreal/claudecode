# claudecode API リファレンス

Claude Code CLI を Mathematica から呼び出し、コード生成・実行・ノートブック操作・ドキュメント生成・パッケージ管理を行うパッケージ。

## クエリ系関数

### ClaudeQuery[prompt, opts]
Claude Code に prompt を送信し応答文字列を返す（同期）。
→ String
Options: WebSearch -> True (無料), WebFetch -> False (課金, Fallback->True 必須), Fallback -> False, Timeout -> Automatic, Model -> Automatic, PrivacyLevel -> Automatic

### ClaudeQuery[session, prompt, opts]
セッション履歴と直前出力/エラーを考慮して回答。
→ String

### ClaudeQuery[{text, Image[...], File[path], ...}, opts]
マルチモーダル入力。画像/PDF/音声を API に送信。
→ String

### ClaudeQuerySync[prompt, opts]
同期問い合わせの軽量版。WindowStatusArea に経過時間表示、履歴/ノートブック書込なし。
→ String
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic

### ClaudeQueryBg[prompt, opts]
SocketListen ハンドラ・ScheduledTask 等の非同期コンテキストから安全に呼べる同期問い合わせ。FrontEnd 操作・ScheduledTask 生成なし。
→ String
Options: Fallback -> False, Model -> Automatic, Timeout -> Automatic
例: ClaudeQueryBg[prompt, NonBlocking -> True, Timeout -> 60]

### ClaudeQueryAsync[prompt, callback, nb, opts]
非同期問合せ。完了時 callback[応答文字列] を呼ぶ。
→ TaskObject
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic

### ClaudeQueryAsyncSilent[prompt, callback, nb, opts]
ClaudeQueryAsync のサイレント版（WindowStatusArea 更新なし）。
→ TaskObject

### ClaudeMath[task, opts]
Mathematica コード生成特化プロンプトで呼び出し。
→ String

### ClaudeWriteResponse[nb, text, opts]
Markdown 文字列をノートブックのセルとして展開。
→ Null
Options: AutoEvaluate -> False

### ClaudeExtractCode[response] → String
応答から最初の ```mathematica ブロック抽出。

### ClaudeExtractAllCode[response] → List
全 ```mathematica ブロックをリストで返す。

### ClaudeEnsureSilentNotebook[] → NotebookObject
非表示の silent notebook を確保。

## 実行系関数

### ClaudeEval[task, opts]
コードを非同期生成・表示し、デフォルトセッションに履歴保存。
→ TaskObject | Null
Options: AutoEvaluate -> True (Input セル自動実行), StartTime -> Now, RepeatInterval -> None (Quantity 指定で繰返実行; {Quantity, n} で回数制限), Timeout -> Automatic, Fallback -> False, AutoPrivate -> False, Model -> Automatic, PrivacySpec -> Automatic
例: ClaudeEval["平均値を求めて"]
例: ClaudeEval[task, RepeatInterval -> {Quantity[2, "Hours"], 5}]
例: ClaudeEval[task, StartTime -> Now + Quantity[3, "Hours"]]

### ClaudeEval[{text, data, Image[...], ...}, opts]
混在入力（テキスト/Dataset/Image/一般式）。
→ TaskObject

### ClaudeEval[session, task, opts]
指定セッションに履歴保存。
→ TaskObject

### ContinueEval[opts]
"エラーを修正してください" でデフォルトセッション継続。
→ TaskObject

### ContinueEval[instruction, opts]
追加指示を付けてデフォルトセッション継続。
→ TaskObject

### ContinueEval[session, instruction, opts]
指定セッションで継続。
→ TaskObject
Options: StartTime -> Now, Timeout -> Automatic

### ContinueUpdate[opts]
直前の ClaudeUpdatePackage の結果を踏まえバグ修正継続。
→ TaskObject

### ContinueUpdate[instruction, opts]
追加指示で継続。

### ContinueUpdate[{instruction, img}, opts]
テキスト+画像で継続。

### ContinueUpdate[pkgName, instruction, opts]
指定パッケージの直前更新を継続。
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now
例: ContinueUpdate["上半円の境界線が欠けているので修正して"]

### ClaudeSpec[task, opts]
ノートブック内容からプログラム仕様を生成。
→ String

### ClaudeSpec[{task, image, ...}, opts]
画像付きで仕様生成。

### ClaudeDebug[expr] → 各種
エラー診断・修正案を提示。

### ClaudeReview[target, opts] → String
コード/ノートブックをレビュー。

### ClaudeReviewChunked[target, opts] → String
大規模対象をチャンク分割してレビュー。

## セッション管理

### CreateClaudeSession[name, opts] → String
名前付きセッション作成（デフォルト履歴を継承）。
Options: Inherit -> True

### ClaudeRestoreSession[name] → String
保存済みセッションを復元。

### ClaudeListSessions[] → List
セッション一覧。

### ClaudeDeleteSession[name] → Null
セッション削除。

### ClaudeShowHistory[session] → 表示
セッション履歴表示。

### ClaudeShowHistory[] → 表示
デフォルトセッション履歴表示。

### ClaudeSessionStatus[] → Association
現セッション状態。

### ClaudeCompactHistory[session] → Null
履歴を要約圧縮。

### ClaudeHistorySize[session] → Integer
履歴サイズ取得。

### ClaudeRateLimitStatus[] → Association
レート制限状況取得。

### ClaudeRateLimitClear[] → Null
レート制限カウンタクリア。

## 添付ファイル

### ClaudeAttach[path] → Null
ファイル/URL をデフォルトセッションに添付。

### ClaudeAttach[session, path] → Null
指定セッションに添付。

### ClaudeDetach[path] → Null
添付解除。

### ClaudeAttachments[session] → List
添付一覧。

### ClearAttachments[session] → Null
全添付クリア。

## 機密データ

### MarkConfidential[var] → Null
変数を機密マーク。

### UnmarkConfidential[var] → Null
機密マーク解除。

### IsConfidential[var] → Boolean
機密判定。

### Confidential[expr] → Confidential[expr]
機密ラッパー。

### NonConfidential[expr] → expr
ラッパー除去。

### ScanConfidentialCells[nb] → List
ノートブック内の機密セル走査。

## Web 検索/取得

### ClaudeWebSearch[query, opts] → String
Web 検索（無料、Claude Code 経由）。

### ClaudeWebFetch[url, opts] → String
URL 取得（課金、Fallback->True 必須）。

### WebSearch[query] → String
ClaudeWebSearch の別名。

### WebFetch[url] → String
ClaudeWebFetch の別名。

## ノートブック・ファイル処理

### NBFileTranslate[spec] → 各種
ノートブックファイル仕様を変換。

### ClaudeProcessFile[path, instruction, opts] → 各種
ファイルを Claude に処理させる。

### ClaudeEnsureSilentNotebook[] → NotebookObject
非表示作業用ノートブック確保。

### ClaudeQueryShowContext[] → 表示
現クエリのコンテキスト表示。

### ClaudeShowAccessConfig[] → 表示
アクセス許可設定表示。

### ClaudePrepareCommit[opts] → String
Git コミットメッセージ準備。

## CLI/コマンド

### ClaudeCommand[cmd, opts] → String
Claude Code CLI のスラッシュコマンド実行（例: "/init", "/review"）。
例: ClaudeCommand["/init"]

### ClaudeStatus[] → 表示
Claude Code 起動状態。

### ClaudeAbort[] → Null
進行中のクエリを中断。

### ClaudeCheckSeparation[pkgName] → Association
NBAccess 分離原則違反を検査。

### ClaudeFixSeparation[pkgName, opts] → 各種
分離原則違反を自動修正。

## ドキュメント生成

### ClaudeCreateDocumentation[pkgName, opts] → 各種
パッケージドキュメント一式を生成。リミット到達で自動停止、再実行で続行。README.md は最後。
Options: References -> {}, Demos -> {}, Disclaimer -> {}, Acknowledgments -> {}, License -> "", Model -> Automatic, Owner -> Automatic, Repository -> Automatic, Branch -> Automatic

### ClaudeUpdateDocumentation[pkgName, instruction, opts] → 各種
既存ドキュメントを部分更新。
Options: References, Demos, Disclaimer, Acknowledgments, License, TargetFiles -> All, Model -> Automatic

## ディレクティブ管理

### ClaudeAddDirective[name, content, opts] → Null
ディレクティブ追加。

### ClaudeRestoreDirective[name, opts] → Null
バックアップから復元。

### ClaudeListDirectives[] → List
ディレクティブ一覧。

### ClaudeUpdateDirective[name, instruction, opts] → Null
ディレクティブ更新。

### ClaudeDirectiveBackupDataset[] → Dataset
バックアップ履歴データセット。

### ClaudeSyncDirectives[opts] → Null
ディレクティブ同期。

## ランタイム/プロポーザル

### ClaudeBuildRuntimeAdapter[opts] → Association
ランタイムアダプタ構築。
Options: "ExecutionTimeoutSeconds" -> 30 (デフォルトタイムアウト、"DefaultTimeoutSeconds" キーで保持)

### ClaudeStartRuntime[adapter, opts] → String
ランタイム起動。runtime ID を返す。

### ClaudeEvalViaRuntime[runtimeId, task, opts] → 各種
ランタイム経由評価。

### ClaudeApproveProposal[runtimeId, proposalId, opts] → 各種
提案を承認・実行。

### ClaudeRuntimeSnapshot[runtimeId] → String
ランタイム状態スナップショット。

### ClaudeRuntimeRestore[snapshotId] → String
スナップショット復元。

### ClaudeRuntimeListSnapshots[] → List
スナップショット一覧。

### ClaudeRegisterDAGRuntime[runtimeId, dagId] → Null
DAG とランタイム関連付け。

## LLMGraph / DAG

### NotebookLLMGraph[nb] → Graph
ノートブックの LLM 呼び出しグラフ構築。

### NotebookLLMGraphPlot[nb, opts] → Graphics
グラフ可視化。

### NotebookLLMGraphBuild[nb] → Graph
グラフ構築（プロット無し）。

### NotebookLLMGraphNodes[nb] → List
ノード一覧取得。

### NotebookLLMGraphValidate[nb] → Association
妥当性検査。

### NotebookLLMGraphFetchResponse[nb, nodeId] → String
ノードの応答取得。

### NotebookLLMGraphFetchL2[nb, nodeId] → 各種
L2 応答取得。

### NotebookLLMGraphSubSteps[nb, nodeId] → List
サブステップ取得。

### NotebookLLMGraphErrors[nb] → List
グラフ内エラー一覧。

### NotebookLLMGraphUpdateL2Status[nb, nodeId, status] → Null
L2 ステータス更新。

### NotebookLLMGraphPlotL2[nb, opts] → Graphics
L2 グラフプロット。

### NotebookLLMGraphRerun[nb, nodeId, opts] → 各種
ノード再実行。

### NotebookLLMGraphInvalidateDownstream[nb, nodeId] → Null
下流ノード無効化。

### NotebookLLMGraphSummary[nb] → Association
グラフ要約。

### NotebookLLMGraphExtractThread[nb, nodeId] → List
スレッド抽出。

### NotebookLLMGraphApplyThread[nb, thread] → Null
スレッド適用。

### LLMGraphExecute[graph, opts] → TaskObject
グラフ実行。

### LLMGraphExecuteStatus[taskId] → Association
実行状態。

### LLMGraphExecuteCancel[taskId] → Null
実行キャンセル。

### LLMGraphDAGCreate[spec, opts] → String
DAG 作成、DAG ID を返す。

### LLMGraphDAGStatus[dagId] → Association
DAG 状態。

### LLMGraphDAGCancel[dagId] → Null
DAG キャンセル。

### LLMGraphDAGStop[dagId] → Null
DAG 停止。

### LLMGraphDAGRetry[dagId, nodeId, opts] → Null
ノード再試行。

### LLMGraphDAGRebuild[dagId, opts] → Null
DAG 再構築。

### LLMGraphDAGFindByContext[ctx] → List
コンテキストから DAG 検索。

### LLMGraphDAGInspect[dagId] → Association
詳細検査。

### LLMGraphDAGMarkFailed[dagId, nodeId] → Null
ノードを失敗マーク。

### LLMGraphDAGSnapshot[dagId] → String
DAG スナップショット保存。

### LLMGraphDAGRestore[snapshotId] → String
DAG 復元。

### LLMGraphDAGListSnapshots[dagId] → List
スナップショット一覧。

### LLMGraphDAGPlot[dagId, opts] → Graphics
DAG 可視化。

### LLMGraphDAGMergeHistory[dagId, historyId] → Null
履歴マージ。

## クラウド送信プリフライト

### ClaudeCloudSendPreflightDecision[ctx] → String
送信可否判定。

### ClaudeCloudSendPreflightError[ctx] → String
エラー詳細。

### ClaudeCloudSendPreflightFailure[ctx] → Association
失敗情報。

### ClaudeCloudSendPreflightGuardDryRun[ctx] → Association
ドライラン検証。

### ClaudeCloudSendPreflightAudit[ctx] → Dataset
監査情報。

### ClaudeCloudSendPreflightLog[] → List
プリフライトログ。

### ClaudeCloudSendPreflightLogClear[] → Null
ログクリア。

### ClaudeCloudSendPreflightLogSummary[] → Association
ログ要約。

### ClaudeCloudSendPreflightFailureCell[ctx] → Cell
失敗セル生成。

### ClaudeCloudSendPreflightLogDataset[] → Dataset
ログを Dataset で取得。

## エディットモード

### ClaudeAppendBlockToPackage[pkgName, block, opts] → Null
パッケージ末尾にブロック追加。

### ClaudeInsertBeforeAnchorInPackage[pkgName, anchor, block, opts] → Null
アンカー直前に挿入。

### ClaudeParseEditModeResponse[response] → Association
編集モード応答をパース。

### ClaudeAutoDetectEditMode[response] → String
編集モード自動判定。

### ClaudeBuildEditModePromptInstructions[mode] → String
モード別プロンプト命令生成。

### ClaudeUpdatePackageWithMode[pkgName, instruction, mode, opts] → 各種
モード指定でパッケージ更新。

## ポーリング・優先度

### ClaudeRegisterPollingTick[key, fn] → Null
共有ポーリングタスクにコールバック登録。

### ClaudeUnregisterPollingTick[key] → Null
登録解除。

### ClaudePollingTickKeys[] → List
登録キー一覧。

### ClaudeBeginHighPriority[durationSec] → Null
高優先度モード開始。

### ClaudeEndHighPriority[] → Null
高優先度モード終了。

### ClaudeBeginParallelKernels[opts] → Null
ParallelKernels 前置起動。

## パレット・UI

### ShowClaudePalette[] → NotebookObject
クライアントパレット表示。

## 変数

### $ClaudeModel
型: List | String, 初期値: {"claudecode", "claude-opus-4-7"}
{provider, model} tuple。"claudecode"=Anthropic CLI (Pro/Max サブスク内、課金なし)、"anthropic"=API直接、"openai"=OpenAI API、"lmstudio"=ローカル LLM。

### $ClaudePrivateModel
型: List, 初期値: 未設定
機密データ処理用ローカルモデル。AutoPrivate -> True 時に使用。
例: $ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}

### $ClaudeTestModel
型: List | String, 初期値: $ClaudeModel
分離検証用モデル。

### $ClaudeFallbackModels
型: List, 初期値: {{"anthropic", $iModelOpus}, {"openai", "gpt-5.5"}}
フォールバックモデル優先順位。各要素は {provider, modelName} または {provider, modelName, url}。NBAccess`NBSetFallbackModels に同期される。

### $ClaudeTimeout
型: Integer, 初期値: 1200
ClaudeQuery/ClaudeEval タイムアウト秒数。

### $ClaudeVerbose
型: Boolean, 初期値: False
詳細ログ出力フラグ。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれた CLAUDE.md パス。

### $ClaudeMDContent
型: String, 初期値: ""
CLAUDE.md 内容。

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code 作業ディレクトリ。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Read 許可追加ディレクトリリスト。

### $ClaudeSnapshots
型: String, 初期値: $ClaudeWorkingDirectory/snapshots
DAG スナップショット保存ディレクトリ。

### $ClaudeDocRetryDelay
型: Number, 初期値: 60
ドキュメント生成リトライ待機秒数。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
ドキュメント生成最大リトライ回数。

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソース最大文字数。

### $ClaudeDocModel
型: List | String, 初期値: $iModelSonnet
ドキュメント生成/更新時モデル。

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval 再帰最大深度。0 で再帰禁止。

### $ClaudeEvalMode
型: Symbol, 初期値: Automatic
評価モード。

### $ClaudeEvalHook
型: Function | None, 初期値: None
評価フック関数。

### $ClaudeEvalAutoThreshold
型: Integer
自動評価しきい値。

### $ClaudeEvalVerbose
型: Boolean
評価詳細ログ。

### $ClaudeEvalAutoLLMMinLength
型: Integer
LLM 自動振分け最小長。

### $ClaudeEvalAutoLLMMinNewlines
型: Integer
LLM 自動振分け最小改行数。

### $ClaudeEvalNaturalDispatch
型: Boolean
自然言語ディスパッチ有効化。

### $ClaudeEvalNaturalVerbose
型: Boolean
自然言語ディスパッチ詳細ログ。

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
パッケージキーワードマップ。プロンプトにキーワードが含まれると対応 api.md がコンテキストに自動注入。
例: $ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒切"}

### $ClaudeRoutingProviders
型: List
ルーティング対象プロバイダ。

### $UseClaudeRuntime
型: Boolean
ランタイム経由実行フラグ。

### $ClaudeLastRuntimeId
型: String
最後に起動したランタイム ID。

### $ClaudeRuntimeAsyncExecution
型: Boolean
ランタイム非同期実行 (ParallelSubmit) フラグ。

### $ClaudeRuntimeAsyncForce
型: Boolean
非同期実行強制フラグ。

### $ClaudeRuntimeAsyncSuppressInputEval
型: Boolean
入力評価抑制フラグ。

### $ClaudeCloudSendPreflightLog
型: List
プリフライトログバッファ。

### $ClaudeCloudSendPreflightLogMaxLength
型: Integer
ログ最大長。

### $ClaudeCloudSendPreflightLogFile
型: String
ログ永続化ファイル。

### $ClaudeCloudSendPreflightContextResolver
型: Function | None
コンテキスト解決関数。

### $ClaudeCloudSendRoutePolicy
型: Symbol | Association
ルートポリシー。

### $ClaudePriorityModeUntil
型: DateObject | None
優先度モード期限。

### $LLMGraphMaxConcurrency
型: Integer
LLMGraph 最大並列数。

### $LLMGraphAutoStopThreshold
型: Integer
自動停止しきい値。

### $ClaudeEditModesVersion
型: String
編集モードバージョン。

### $ClaudeEditModeAppendTagOpen
型: String
追加モード開始タグ。

### $ClaudeEditModeAppendTagClose
型: String
追加モード終了タグ。

### $ClaudeEditModeInsertTagClose
型: String
挿入モード終了タグ。

### $claudecodeVersion
型: String
パッケージバージョン。

### $iMediaMaxImageSize
型: Integer
画像最大サイズ。

## オプションシンボル

### Fallback
True: Claude Code 利用不可時にフォールバックモデルへ自動切替。False (デフォルト): エラーをそのまま返す。

### AutoPrivate
True: 機密変数アクセス時に Model -> $ClaudePrivateModel, PrivacySpec -> Automatic を自動付与。False (デフォルト)。

### AutoEvaluate
ClaudeEval/ClaudeWriteResponse で生成された Input セルの自動実行制御。デフォルト True (ClaudeEval), False (ClaudeWriteResponse)。

### StartTime
ClaudeEval/ContinueEval で実行開始時刻を DateObject で指定。例: StartTime -> Now + Quantity[3, "Hours"]

### RepeatInterval
ClaudeEval で繰返実行間隔。例: RepeatInterval -> Quantity[2, "Hours"] または {Quantity[1, "Hours"], 5}

### Timeout
API フォールバックタイムアウト秒数。Automatic は 600 秒。

### Model
{provider, model} tuple またはモデル名。Automatic は $ClaudeModel。

### PrivacyLevel
0.0〜1.0。0.5 超で $ClaudePrivateModel に自動ルーティング。Automatic は機密マークから判定。

### PrivacySpec
プライバシー仕様。Automatic で自動判定。

### TargetFiles
ClaudeUpdateDocumentation で対象ファイル指定。All で全ファイル。

### TargetFunctions
対象関数指定。

### Mode
動作モード指定。

### DryRun
True で実行なし検証のみ。

### Inherit
CreateClaudeSession でデフォルト履歴継承。デフォルト True。

### License
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のライセンス指定。空文字でデフォルト MIT (GitHubREST`$GitHubLicenseHolder が非空なら)。

### References
README.md に参考文献セクション追加。URL/書籍名のリスト。

### Demos
README.md にデモセクション追加。URL のリスト。

### Disclaimer
免責事項セクション追加文言リスト。

### Acknowledgments
謝辞セクション追加文言リスト。

### WebFetch
ClaudeQuery オプション。False (デフォルト, 課金回避)。

### WebSearch
ClaudeQuery オプション。True (デフォルト, 無料)。

### RepeatInterval
ClaudeEval 繰返実行。

### PrivacySpec
プライバシー仕様。

### Keywords
ドキュメント検索キーワード。

### Title
ドキュメントタイトル。

### Refetch
URL キャッシュ無視再取得。

### Owner
GitHub オーナー名。Automatic で自動判定。

### Repository
GitHub リポジトリ名。Automatic で自動判定。

### Branch
GitHub ブランチ名。Automatic で main/master 自動判定。

### BaseBranch
PR ベースブランチ。

## 内部公開シンボル（外部パッケージから参照可）

### iLLMGraphNode
LLMGraph ノード作成内部関数。

### iMakeBat
Claude Code CLI 起動用バッチ作成。

### cleanOutput
ANSI コード/制御文字を除去。

### stripANSI
ANSI エスケープシーケンス除去。