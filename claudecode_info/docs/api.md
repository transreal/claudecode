# claudecode API リファレンス

Claude Code CLI を Mathematica から呼び出すパッケージ。LLM 連携・コード生成・パッケージ管理・ドキュメント生成・ノートブック書き込み等の機能を提供する。

## 基本問い合わせ関数

### ClaudeQuery[prompt, opts]
Claude Code に prompt を送って応答文字列を返す (同期)。`ClaudeQuery[session, prompt]` でセッション履歴と直前出力を考慮。`ClaudeQuery[{text, Image[...], File[path], ...}]` でマルチモーダル入力。
→ String
Options: WebSearch -> True (無料), WebFetch -> False (課金、Fallback->True 必須), Fallback -> False, Timeout -> Automatic (秒), Model -> Automatic, PrivacyLevel -> Automatic

### ClaudeQuerySync[prompt, opts]
prompt を送り応答文字列を同期で返す。WindowStatusArea に経過時間表示。履歴・ノートブック書き込みなしの軽量版。
→ String
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic
例: `ClaudeQuerySync[prompt, Model -> {"anthropic", "claude-sonnet-4-6"}]`

### ClaudeQueryBg[prompt, opts]
FrontEnd 操作・ScheduledTask 生成なしで同期問い合わせ。SocketListen ハンドラや ScheduledTask コールバック等の非同期コンテキストから安全に呼べる (rule 95)。
→ String
Options: Fallback -> False, Model -> Automatic, Timeout -> Automatic

### ClaudeQueryAsync[prompt, callback, nb, opts]
非同期問い合わせ。完了時に `callback[応答文字列]` を呼ぶ。nb は出力先 NotebookObject。WindowStatusArea に経過時間表示。
→ JobId
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic

### ClaudeQueryAsyncSilent[prompt, callback, opts]
ノートブック UI 表示なしで非同期問い合わせ。
→ JobId

### ClaudeEnsureSilentNotebook[]
サイレント実行用ノートブックを準備して返す。
→ NotebookObject

### ClaudeMath[task]
Mathematica コード生成に特化したプロンプトで Claude を呼ぶ。
→ String

### ClaudeExtractCode[response] → String
応答から最初の ```mathematica ブロックを抽出。

### ClaudeExtractAllCode[response] → List
応答から全 ```mathematica ブロックをリストで返す。

### ClaudeWriteResponse[nb, text, opts]
マークダウン形式テキストをノートブックのセルとして展開。
→ Null
Options: AutoEvaluate -> False

## コード生成・評価

### ClaudeEval[task, opts]
コードを非同期で生成・表示・実行。タスク説明から Mathematica コードを生成し評価セルに挿入。
→ Null
Options: Model -> Automatic, AutoPrivate -> False, PrivacySpec -> None, Mode -> Automatic, DryRun -> False, Fallback -> False, Timeout -> Automatic
例: `ClaudeEval["フィボナッチ数列を計算"]`

### ContinueEval[task, opts]
直前 ClaudeEval の結果を踏まえてタスクを継続実行。
→ Null
Options: ClaudeEval と同じ + Inherit -> True

### ContinueUpdate[task, opts]
直前生成コードを部分更新。
→ Null

### ClaudeSpec[task]
ノートブック内容からプログラム仕様を生成。`ClaudeSpec[{"task", image, ...}]` で画像付き。パレットからはセル選択で呼出可。
→ String

### ClaudeDebug[code, opts] → Null
コードのデバッグ支援。

### ClaudeReview[opts] → Null
コードレビュー実行。

### ClaudeReviewChunked[opts] → Null
分割コードレビュー (大規模ファイル対応)。

## パッケージ管理 (alias、本体は ClaudePackageManager.wl)

### ClaudeCreatePackage[name, spec] → Null
新規パッケージ作成。

### ClaudeUpdatePackage[name, instructions, opts] → Null
既存パッケージをバックアップ・差分更新・検証・再ロードを伴って更新。

### ClaudeUpdatePackageViaRuntime[name, instructions, opts] → Null
Runtime 経由でパッケージ更新。

### ClaudeUpdatePackageHistory[name] → List
パッケージ更新履歴を返す。

### ClaudeRestorePackage[name, opts] → Null
バックアップから復元。

### ClaudeBackupDataset[opts] → Dataset
バックアップ一覧。

### ClaudeMigrateBackupHistory[] → Null
バックアップ履歴を移行。

### ClaudeConvertToPaclet[name] → Null
.wl パッケージを Paclet に変換。

### ClaudeBuildTransactionAdapter[opts] → Association
トランザクション用アダプタ構築。

### ClaudeCheckSeparation[packageName] → Association
NBAccess 分離原則違反を検査。

### ClaudeFixSeparation[packageName] → Null
分離原則違反を修正。

## ドキュメント生成

### ClaudeCreateDocumentation[name, opts] → Null
パッケージドキュメント (README, api.md, guide.nb 等) を生成。リミット到達時は自動停止し再実行で続行、README.md は最後に生成。
Options: References -> {}, Demos -> {}, Disclaimer -> {}, License -> "", Acknowledgments -> {}, Model -> Automatic

### ClaudeUpdateDocumentation[name, instructions, opts] → Null
既存ドキュメントを部分更新。
Options: ClaudeCreateDocumentation と同じ

## ディレクティブ管理

### ClaudeAddDirective[name, content, opts] → Null
ディレクティブ (rules/skills) を追加。

### ClaudeUpdateDirective[name, content, opts] → Null
ディレクティブを更新。

### ClaudeRestoreDirective[name, opts] → Null
バックアップから復元。

### ClaudeListDirectives[] → List
登録済ディレクティブ一覧。

### ClaudeDirectiveBackupDataset[] → Dataset
ディレクティブバックアップ一覧。

### ClaudeSyncDirectives[opts] → Null
ディレクティブを Claude 作業ディレクトリに同期。

## セッション管理

### CreateClaudeSession[opts] → SessionId
新規セッション作成。
Options: Inherit -> False

### ClaudeRestoreSession[id] → Null
セッション復元。

### ClaudeListSessions[] → List
セッション一覧。

### ClaudeDeleteSession[id] → Null
セッション削除。

### ClaudeShowHistory[id] → Null
セッション履歴を表示。

### ClaudeSessionStatus[] → Association
現在セッションの状態。

### ClaudeCompactHistory[opts] → Null
履歴を要約してコンパクト化。

### ClaudeHistorySize[] → Integer
履歴サイズ取得。

## 添付ファイル

### ClaudeAttach[path|url, opts] → Null
ファイル/URL を Claude セッションに添付。
Options: Keywords -> {}, Title -> "", Refetch -> False

### ClaudeDetach[id] → Null
添付解除。

### ClaudeAttachments[] → List
添付一覧。

### ClearAttachments[] → Null
全添付クリア。

## 機密データ

### MarkConfidential[sym] → Null
変数を機密としてマーク。

### UnmarkConfidential[sym] → Null
機密マーク解除。

### IsConfidential[sym] → Boolean
機密判定。

### Confidential[expr] → ConfidentialWrapper
式を機密ラップ。

### NonConfidential[expr] → expr
ラップ解除。

### ScanConfidentialCells[nb] → List
機密セルを走査。

## Web 検索・取得

### ClaudeWebSearch[query, opts] → String
Claude Code CLI 経由で Web 検索 (無料)。

### ClaudeWebFetch[url, opts] → String
Web ページ取得 (課金、Fallback 必須)。

### WebSearch[query, opts] → String
ClaudeWebSearch エイリアス。

### WebFetch[url, opts] → String
ClaudeWebFetch エイリアス。

## レート制限

### ClaudeRateLimitStatus[] → Association
レート制限状態取得。

### ClaudeRateLimitClear[] → Null
レート制限カウンタクリア。

## ステータス・制御

### ClaudeStatus[] → Association
パッケージ実行状態。

### ClaudeAbort[] → Null
進行中処理を中止。

### ClaudeCommand[slashCmd] → String
Claude Code CLI スラッシュコマンド実行 (例: `ClaudeCommand["/init"]`)。

### ClaudePrepareCommit[opts] → String
git コミットメッセージ生成。

### ClaudeShowAccessConfig[] → Null
アクセス権設定表示。

### ClaudeQueryShowContext[] → Null
プロンプト送信前コンテキストを表示。

### ShowClaudePalette[] → Null
Claude パレットを開く。

## Runtime API

### ClaudeBuildRuntimeAdapter[opts] → Association
Runtime アダプタ Association を構築。`"DefaultTimeoutSeconds"` キーを含む。
Options: ExecutionTimeoutSeconds -> 30 (実行タイムアウト秒)

### ClaudeStartRuntime[adapter, opts] → RuntimeId
Runtime を起動。

### ClaudeEvalViaRuntime[runtimeId, task, opts] → Null
Runtime 経由で ClaudeEval 相当を実行。

### ClaudeApproveProposal[runtimeId, proposalId] → Null
Runtime 提案を承認して実行。

### ClaudeRuntimeSnapshot[runtimeId] → SnapshotId
Runtime 状態を保存。

### ClaudeRuntimeRestore[snapshotId] → Null
スナップショット復元。

### ClaudeRuntimeListSnapshots[] → List
スナップショット一覧。

### ClaudeRegisterDAGRuntime[runtimeId, dagId] → Null
DAG と Runtime を関連付け。

## NotebookLLMGraph

### NotebookLLMGraph[nb] → Graph
ノートブックから LLM 依存グラフを生成。

### NotebookLLMGraphBuild[nb, opts] → Graph
グラフを構築。

### NotebookLLMGraphPlot[graph] → Graphics
グラフ可視化。

### NotebookLLMGraphPlotL2[graph] → Graphics
L2 (実行レベル) グラフ可視化。

### NotebookLLMGraphNodes[graph] → List
ノードリスト。

### NotebookLLMGraphValidate[graph] → List
検証エラー一覧。

### NotebookLLMGraphFetchResponse[graph, nodeId] → String
ノードの応答取得。

### NotebookLLMGraphFetchL2[graph, nodeId] → Association
L2 ノード詳細取得。

### NotebookLLMGraphSubSteps[graph, nodeId] → List
サブステップ取得。

### NotebookLLMGraphErrors[graph] → List
エラー一覧。

### NotebookLLMGraphUpdateL2Status[graph, nodeId, status] → Null
L2 ステータス更新。

### NotebookLLMGraphRerun[graph, nodeId] → Null
ノード再実行。

### NotebookLLMGraphInvalidateDownstream[graph, nodeId] → Null
下流ノードを無効化。

### NotebookLLMGraphSummary[graph] → Association
グラフ概要。

### NotebookLLMGraphExtractThread[graph, nodeId] → List
スレッド抽出。

### NotebookLLMGraphApplyThread[graph, thread] → Null
スレッド適用。

## LLMGraphExecute / LLMGraphDAG

### LLMGraphExecute[graph, opts] → ExecId
グラフを並列実行。

### LLMGraphExecuteStatus[execId] → Association
実行状態。

### LLMGraphExecuteCancel[execId] → Null
実行キャンセル。

### LLMGraphDAGCreate[spec, opts] → DAGId
DAG ジョブ作成。

### LLMGraphDAGStatus[dagId] → Association
DAG 状態。

### LLMGraphDAGCancel[dagId] → Null
DAG キャンセル。

### LLMGraphDAGStop[dagId] → Null
DAG 停止。

### LLMGraphDAGRetry[dagId, nodeId] → Null
ノード再試行。

### LLMGraphDAGRebuild[dagId] → Null
DAG 再構築。

### LLMGraphDAGFindByContext[ctx] → List
コンテキストから DAG 検索。

### LLMGraphDAGInspect[dagId] → Association
DAG 詳細。

### LLMGraphDAGMarkFailed[dagId, nodeId] → Null
ノード失敗扱い。

### LLMGraphDAGSnapshot[dagId] → SnapshotId
DAG 状態保存。

### LLMGraphDAGRestore[snapshotId] → Null
DAG 状態復元。

### LLMGraphDAGListSnapshots[] → List
スナップショット一覧。

### LLMGraphDAGPlot[dagId] → Graphics
DAG 可視化。

### LLMGraphDAGMergeHistory[dagId] → Null
履歴マージ。

## クラウド送信 Preflight

### ClaudeCloudSendPreflightDecision[ctx] → Association
クラウド送信前判定。

### ClaudeCloudSendPreflightError[ctx] → String
エラー文字列。

### ClaudeCloudSendPreflightFailure[ctx] → Failure
失敗オブジェクト。

### ClaudeCloudSendPreflightGuardDryRun[ctx] → Association
ガードのドライラン。

### ClaudeCloudSendPreflightAudit[] → Dataset
監査ログ。

### ClaudeCloudSendPreflightLog[] → List
ログ取得。

### ClaudeCloudSendPreflightLogClear[] → Null
ログクリア。

### ClaudeCloudSendPreflightLogSummary[] → Association
ログ要約。

### ClaudeCloudSendPreflightFailureCell[] → Cell
失敗セル生成。

### ClaudeCloudSendPreflightLogDataset[] → Dataset
ログ Dataset。

## ノートブック処理

### NBFileTranslate[spec] → Association
ノートブックファイル仕様を変換。

### ClaudeProcessFile[path, opts] → Null
ファイル処理。

## 編集モード (claudecode_editmodes)

### ClaudeAppendBlockToPackage[name, block, opts] → Null
パッケージ末尾にブロック追加。

### ClaudeInsertBeforeAnchorInPackage[name, anchor, block, opts] → Null
アンカー前にブロック挿入。

### ClaudeParseEditModeResponse[response] → Association
編集モード応答をパース。

### ClaudeAutoDetectEditMode[response] → String
編集モードを自動判定。

### ClaudeBuildEditModePromptInstructions[mode] → String
編集モード用プロンプト指示生成。

### ClaudeUpdatePackageWithMode[name, instructions, mode, opts] → Null
モード指定でパッケージ更新。

## 並列処理・優先度

### ClaudeBeginHighPriority[] → Null
高優先度モード開始。

### ClaudeEndHighPriority[] → Null
高優先度モード終了。

### ClaudeBeginParallelKernels[] → Null
ParallelKernels の事前起動。

### ClaudeRegisterPollingTick[key, fn] → Null
共有ポーリングタスクに登録。

### ClaudeUnregisterPollingTick[key] → Null
登録解除。

### ClaudePollingTickKeys[] → List
登録キー一覧。

## ユーティリティ

### cleanOutput[str] → String
出力文字列クリーンアップ。

### stripANSI[str] → String
ANSI エスケープ除去。

## 変数

### $ClaudeModel
型: {provider_String, model_String} tuple
初期値: {"claudecode", "claude-opus-4-7"}
Claude CLI に渡すモデル。provider は claudecode/chatgptcodex/anthropic/openai/lmstudio。

### $ClaudePrivateModel
型: {provider, model, url} List
秘密データ処理用ローカルモデル。AutoPrivate -> True 時に使用。
例: `{"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}`

### $ClaudeTestModel
型: String, 初期値: $ClaudeModel と同じ
分離検証用モデル。

### $ClaudeTimeout
型: Integer, 初期値: 1200
タイムアウト秒数。

### $ClaudeVerbose
型: Boolean, 初期値: False
詳細ログ出力フラグ。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code の作業ディレクトリ。配下の .claude/CLAUDE.md, .claude/rules/, .claude/skills/ を読ませる。

### $OpenaiWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "OpenAI Working"}]
OpenAI Codex 作業ディレクトリ。

### $ChatgptWorkingDirectory
型: String
ChatGPT Codex 作業ディレクトリ。

### $ChatgptCodexExe
型: String
ChatGPT Codex CLI 実行ファイルパス。

### $ChatgptAccessibleDirs
型: List
Codex CLI に Read 許可するディレクトリ。

### $ChatgptCodexHomeDirectory
型: String
Codex CLI ホームディレクトリ。

### $ChatgptCodexPermissionProfile
型: String
Codex CLI 権限プロファイル。

### $ChatgptCodexApprovalPolicy
型: String
Codex CLI 承認ポリシー。

### $ChatgptCodexModel
型: String | Automatic
Codex CLI モデル指定。

### $ChatgptCodexHarnessMode
型: String
Codex CLI ハーネスモード。

### $ChatgptCodexRetainTempProjects
型: Boolean
Codex 一時プロジェクト保持フラグ。

### $ChatgptCodexSourceExposureMode
型: String
Codex ソース公開モード。

### $ClaudeCLIHarnessMode
型: String
Claude CLI ハーネスモード。

### $ClaudeAccessibleDirs
型: List of String, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリ。

### $ClaudeFallbackModels
型: List of {provider, model[, url]}, 初期値: {{"anthropic", "claude-opus-4-7"}, {"openai", "gpt-5.5"}}
フォールバックモデル優先順位。NBAccess`NBSetFallbackModels に同期される。

### $ClaudeDocRetryDelay
型: Integer, 初期値: 60
ドキュメント生成のリトライ待機秒数。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
ドキュメント生成の最大リトライ回数。

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースの最大文字数。

### $ClaudeDocModel
型: String tuple, 初期値: $iModelSonnet
ドキュメント生成・更新時モデル。

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval の再帰深度上限。0 で再帰禁止。

### $ClaudeEvalMode
型: Symbol
ClaudeEval の実行モード。

### $ClaudeEvalHook
型: Function | None
ClaudeEval フック関数。

### $ClaudeEvalAutoThreshold
型: Number
自動実行閾値。

### $ClaudeEvalVerbose
型: Boolean
ClaudeEval 詳細ログ。

### $ClaudeEvalAutoLLMMinLength
型: Integer
自動 LLM 振り分け最小長。

### $ClaudeEvalAutoLLMMinNewlines
型: Integer
自動 LLM 振り分け最小改行数。

### $ClaudeEvalNaturalDispatch
型: Boolean
自然言語振り分けフラグ。

### $ClaudeEvalNaturalVerbose
型: Boolean
自然言語振り分け詳細ログ。

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
外部パッケージがキーワード登録するための Association。プロンプトにキーワード含むと該当 api.md を自動注入。
例: `$ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒"}`

### $ClaudeSnapshots
型: String, 初期値: $ClaudeWorkingDirectory/snapshots
LLMGraphDAG スナップショット保存ディレクトリ。

### $ClaudeRoutingProviders
型: List
ルーティングプロバイダ一覧。

### $UseClaudeRuntime
型: Boolean
Runtime 使用フラグ。

### $ClaudeLastRuntimeId
型: RuntimeId
直前 Runtime ID。

### $ClaudeRuntimeAsyncExecution
型: Boolean
コード実行の非同期化 (ParallelSubmit) フラグ。

### $ClaudeRuntimeAsyncForce
型: Boolean
非同期実行強制フラグ。

### $ClaudeRuntimeAsyncSuppressInputEval
型: Boolean
非同期時 Input セル評価抑制フラグ。

### $ClaudePriorityModeUntil
型: AbsoluteTime
高優先度モードの終了時刻。

### $LLMGraphMaxConcurrency
型: Integer
LLMGraph 最大並列数。

### $LLMGraphAutoStopThreshold
型: Integer
LLMGraph 自動停止閾値。

### $ClaudeCloudSendPreflightLog
型: List
クラウド送信 Preflight ログ。

### $ClaudeCloudSendPreflightLogMaxLength
型: Integer
ログ最大長。

### $ClaudeCloudSendPreflightLogFile
型: String
ログファイルパス。

### $ClaudeCloudSendPreflightContextResolver
型: Function
コンテキスト解決関数。

### $ClaudeCloudSendRoutePolicy
型: Association
送信ルートポリシー。

### $claudecodeVersion
型: String
パッケージバージョン。

### $iMediaMaxImageSize
型: Integer
メディア最大画像サイズ。

### $ClaudeEditModesVersion
型: String
編集モードバージョン。

### $ClaudeEditModeAppendTagOpen
型: String
追記モード開始タグ。

### $ClaudeEditModeAppendTagClose
型: String
追記モード終了タグ。

### $ClaudeEditModeInsertTagClose
型: String
挿入モード終了タグ。

## オプションシンボル (共通)

### Fallback
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True で Claude Code 利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみフォールバックする。
デフォルト: False

### AutoPrivate
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True で秘密変数アクセス時、生成コードに Model -> $ClaudePrivateModel, PrivacySpec -> Automatic を付与。
デフォルト: False

### AutoEvaluate
ClaudeWriteResponse 等のオプション。True でコードセル自動評価。
デフォルト: False

### StartTime
開始時刻指定。

### Timeout
タイムアウト秒数指定。デフォルト Automatic ($ClaudeTimeout 参照)。

### TargetFiles
対象ファイルリスト。

### TargetFunctions
対象関数リスト。

### Mode
動作モード指定。

### DryRun
True で実際の変更を行わずプランのみ表示。

### Inherit
ContinueEval/CreateClaudeSession で前コンテキストを継承。

### License
ClaudeCreateDocumentation/Update のオプション。空文字列で GitHubREST`$GitHubLicenseHolder が非空なら MIT 自動挿入。
例: `License -> "MIT"`

### Model
モデル指定。tuple {provider, model} または String。
例: `Model -> {"anthropic", "claude-sonnet-4-6"}`

### WebFetch
ClaudeQuery オプション。True で Web ページ取得有効 (課金、Fallback->True 必須)。
デフォルト: False

### WebSearch
ClaudeQuery オプション。True で Web 検索有効 (無料)。
デフォルト: True

### RepeatInterval
繰り返し間隔。

### PrivacySpec
プライバシー仕様。AutoPrivate -> True 時 Automatic。

### Keywords
ClaudeAttach オプション。検索用キーワード。

### Title
ClaudeAttach オプション。添付タイトル。

### Refetch
ClaudeAttach オプション。True で URL 再取得。

### Owner
GitHub 等のオーナー指定。

### Repository
GitHub リポジトリ名。

### Branch
ブランチ名。

### BaseBranch
ベースブランチ名。

### References
ClaudeCreateDocumentation オプション。参考文献 URL/書籍名リスト。
例: `References -> {"https://...", "書籍名"}`

### Demos
ClaudeCreateDocumentation オプション。デモ動画/使用例 URL リスト。

### Disclaimer
ClaudeCreateDocumentation オプション。免責事項文言リスト (README.md にのみ反映)。

### Acknowledgments
ClaudeCreateDocumentation オプション。謝辞文言リスト (README.md にのみ反映)。

### PrivacyLevel
ClaudeQuerySync/Async オプション。0.0-1.0 でプライバシーレベル指定。0.5 超で $ClaudePrivateModel に自動切替。

## 関連パッケージ

- [NBAccess](https://github.com/transreal/NBAccess) — ノートブック読み書き・プライバシー管理
- [github](https://github.com/transreal/github) — GitHubREST 連携
- [ClaudePackageManager](https://github.com/transreal/ClaudePackageManager) — パッケージ管理本体 (ClaudeUpdatePackage 等)
- [ClaudeRuntime](https://github.com/transreal/ClaudeRuntime) — Runtime 基盤
- [NotebookExtensions](https://github.com/transreal/NotebookExtensions) — ノートブック拡張