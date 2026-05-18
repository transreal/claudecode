# claudecode API リファレンス

Claude Code CLI と Anthropic/OpenAI API を Mathematica から統合的に呼び出すパッケージ。LLM 連携、セッション管理、ノートブック編集、DAG 実行、ドキュメント生成等を提供。

## 主要関数: LLM 問い合わせ

### ClaudeQuery[prompt, opts]
Claude Code に prompt を送り応答文字列を同期で返す。`ClaudeQuery[session, prompt]` で履歴と直前出力を考慮。マルチモーダル入力 `{text, Image[...], File[path], ...}` 可。
→ String
Options: WebSearch -> True (無料), WebFetch -> False (課金, Fallback->True 必須), Fallback -> False, Timeout -> Automatic, Model -> Automatic, PrivacyLevel -> Automatic

### ClaudeQuerySync[prompt, opts]
同期軽量版。WindowStatusArea に経過時間表示。履歴/ノートブック書き込みなし。
→ String
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic

### ClaudeQueryBg[prompt, opts]
FrontEnd 操作・ScheduledTask 生成なしで同期問い合わせ。SocketListen ハンドラ・ScheduledTask コールバック等の非同期コンテキストから安全。
→ String
Options: Fallback -> False, Model -> Automatic, Timeout -> Automatic

### ClaudeQueryAsync[prompt, callback, nb, opts]
非同期問い合わせ。完了時 `callback[応答文字列]` を呼ぶ。カーネルブロックなし。
→ JobObject
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic

### ClaudeQueryAsyncSilent[prompt, callback, nb, opts]
ClaudeQueryAsync の WindowStatusArea 出力を抑制した版。
→ JobObject

### ClaudeEnsureSilentNotebook[nb]
nb をサイレント出力対応にする。
→ NotebookObject

### ClaudeMath[task]
Mathematica コード生成に特化したプロンプトで Claude を呼ぶ。
→ String

### ClaudeExtractCode[response] → String
応答から最初の ```mathematica ブロックを抽出。

### ClaudeExtractAllCode[response] → List of String
応答から全 ```mathematica ブロックを抽出。

### ClaudeWriteResponse[nb, text, opts]
マークダウン形式テキストをノートブックのセルに展開。
→ Null
Options: AutoEvaluate -> False

## コード生成と実行

### ClaudeEval[task, opts]
コードを非同期生成・表示・実行。デフォルトセッションに履歴を保存。`ClaudeEval[{text, data, ...}]` で混在入力、`ClaudeEval[session, task]` で指定セッション。
→ TaskObject
Options: AutoEvaluate -> True (生成 Input セル自動実行), StartTime -> Now (開始時刻 DateObject), RepeatInterval -> None (繰り返し実行; `{Quantity[1,"Hours"], 5}` で最大 5 回), Timeout -> Automatic, Fallback -> False, Model -> Automatic, AutoPrivate -> False, PrivacySpec -> None

例: `ClaudeEval["plot Sin", RepeatInterval -> Quantity[2, "Hours"]]`
例: `ClaudeEval[task, Model -> $ClaudePrivateModel, AutoPrivate -> True]`

### ContinueEval[session, instruction, opts]
指定セッションで継続実行。`ContinueEval[instruction]` でデフォルト、`ContinueEval[]` で "エラーを修正してください"。
→ TaskObject
Options: StartTime -> Now, Timeout -> Automatic

### ContinueUpdate[opts] / ContinueUpdate[instruction] / ContinueUpdate[{instr, img}] / ContinueUpdate[pkgName, instr]
直前の ClaudeUpdatePackage 結果を踏まえバグ修正を継続。
→ TaskObject
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now

### ClaudeSpec[task] / ClaudeSpec[{task, image, ...}]
ノートブック内容からプログラム仕様を生成。
→ String

### ClaudeDebug[task] → String
デバッグ支援用プロンプトで Claude を呼ぶ。

### ClaudeReview[task] → String
コードレビュー実行。

### ClaudeReviewChunked[task] → String
大規模コードを分割してレビュー。

## セッション管理

### CreateClaudeSession[name, opts]
名前付きセッションを作成。`CreateClaudeSession[session]` で既存履歴を継承、`CreateClaudeSession[]` でデフォルト履歴継承。
→ Session
Options: Inherit -> True

### ClaudeRestoreSession[] / ClaudeRestoreSession[name] → Session
デフォルトまたは指定名のセッションをリストア。

### ClaudeListSessions[] → List
ノートブック内全セッション一覧。

### ClaudeDeleteSession[name] / ClaudeDeleteSession[name, "All"] → Null
セッション削除。"All" 指定で履歴も削除。

### ClaudeShowHistory[] / ClaudeShowHistory[session] / ClaudeShowHistory[name] → Null
セッション履歴を表示。

### ClaudeSessionStatus[] → Association
全セッションの状態 Association。

### ClaudeCompactHistory[session] → Null
履歴を圧縮。

### ClaudeHistorySize[session] → Integer
履歴サイズを返す。

## アタッチメント

### ClaudeAttach[path, opts] / ClaudeAttach[url, opts] / ClaudeAttach[session, path, opts]
参照資料をセッションに添付。URL は PDF 化キャッシュ。
→ Null
Options: Keywords -> {} (プロンプト中の語にマッチで自動注入), Title -> None, Refetch -> False

### ClaudeDetach[id] / ClaudeDetach[session, id] → Null
添付を解除。

### ClaudeAttachments[] / ClaudeAttachments[session] → List
添付一覧。

### ClearAttachments[] / ClearAttachments[session] → Null
全添付削除。

## ディレクティブ管理

### ClaudeAddDirective[name, content, opts] → Null
CLAUDE.md / rules / skills にディレクティブを追加。

### ClaudeRestoreDirective[name] → Null
削除済みディレクティブを復元。

### ClaudeListDirectives[] → List
登録ディレクティブ一覧。

### ClaudeUpdateDirective[name, content] → Null
ディレクティブを更新。

### ClaudeDirectiveBackupDataset[] → Dataset
バックアップ一覧。

### ClaudeSyncDirectives[] → Null
ディレクティブを同期。

## ドキュメント生成

### ClaudeCreateDocumentation[pkg, opts]
パッケージのドキュメント (README.md, api.md, spec.md, guide.nb) を生成。
→ Null
Options: References -> {} (参考文献 URL/書名リスト), Demos -> {} (デモ URL リスト), Disclaimer -> {} (免責文言), Acknowledgments -> {} (謝辞), License -> "" (空: GitHubLicenseHolder 非空時 MIT 自動), Model -> Automatic, Owner -> "", Repository -> "", Branch -> "", BaseBranch -> ""

### ClaudeUpdateDocumentation[pkg, opts]
ドキュメントを更新。
→ Null
Options: ClaudeCreateDocumentation と同じ

## パッケージ・コマンド

### ClaudeCommand[cmd, args] → String
Claude Code カスタムコマンドを実行。

### ClaudeCheckSeparation[pkg] → Association
パッケージの分離可能性を検証。

### ClaudeFixSeparation[pkg] → Null
分離検証結果を踏まえ修正。

### ClaudeStatus[] → Association
パッケージ全体の状態を返す。

### ClaudeAbort[] → Null
進行中の Claude 処理を中断。

### ClaudePrepareCommit[opts] → String
変更要約から git コミットメッセージを生成。

### NBFileTranslate[file, opts] → File
ノートブックファイル変換。

### ClaudeProcessFile[file, opts] → Null
ファイル単位のClaude処理。

## ノートブック LLM グラフ

### NotebookLLMGraph[nb] → Graph
ノートブックの LLM 呼び出し依存グラフ。

### NotebookLLMGraphPlot[nb, opts] → Graphics
依存グラフ描画。

### NotebookLLMGraphBuild[nb] → Graph
グラフ構築 (キャッシュ更新)。

### NotebookLLMGraphNodes[nb] → List
ノードリスト。

### NotebookLLMGraphValidate[nb] → Association
グラフ整合性検証。

### NotebookLLMGraphFetchResponse[nb, node] → String
ノードの応答を取得。

### NotebookLLMGraphSubSteps[nb, node] → List
サブステップ列挙。

### NotebookLLMGraphFetchL2[nb] → Association
レベル 2 詳細取得。

### NotebookLLMGraphErrors[nb] → List
エラーノード列挙。

### NotebookLLMGraphUpdateL2Status[nb] → Null
L2 ステータス更新。

### NotebookLLMGraphPlotL2[nb] → Graphics
L2 グラフ描画。

### NotebookLLMGraphRerun[nb, node] → TaskObject
ノードを再実行。

### NotebookLLMGraphInvalidateDownstream[nb, node] → Null
下流ノードのキャッシュを無効化。

### NotebookLLMGraphSummary[nb] → Dataset
グラフ統計サマリ。

### NotebookLLMGraphExtractThread[nb, node] → List
ノードに至るスレッドを抽出。

### NotebookLLMGraphApplyThread[nb, thread] → Null
スレッドを適用。

## LLMGraph 実行 (DAG)

### LLMGraphExecute[graph, opts] → JobObject
LLM グラフを並列実行。

### LLMGraphExecuteStatus[job] → Association
実行状態取得。

### LLMGraphExecuteCancel[job] → Null
実行キャンセル。

### LLMGraphDAGCreate[spec, opts] → DAGObject
DAG を作成。

### LLMGraphDAGStatus[dag] → Association
DAG 状態。

### LLMGraphDAGCancel[dag] → Null
DAG 中止。

### LLMGraphDAGStop[dag] → Null
DAG 停止 (再開可)。

### LLMGraphDAGRetry[dag, node] → Null
失敗ノードを再試行。

### LLMGraphDAGRebuild[dag] → Null
DAG 再構築。

### LLMGraphDAGFindByContext[ctx] → DAGObject
コンテキストから DAG 取得。

### LLMGraphDAGInspect[dag] → Association
DAG 内部状態詳細。

### LLMGraphDAGMarkFailed[dag, node] → Null
ノードを失敗扱いに。

### LLMGraphDAGSnapshot[dag, name] → File
DAG スナップショット保存。

### LLMGraphDAGRestore[name] → DAGObject
スナップショットから復元。

### LLMGraphDAGListSnapshots[] → List
スナップショット一覧。

### LLMGraphDAGPlot[dag, opts] → Graphics
DAG 描画。

### LLMGraphDAGMergeHistory[dag1, dag2] → DAGObject
履歴をマージ。

## ランタイム (実行プロポーザル)

### ClaudeBuildRuntimeAdapter[opts] → Association
ランタイム用アダプタを構築。アダプタは `DefaultTimeoutSeconds` キーを保持。
Options: ExecutionTimeoutSeconds -> 30 (秒)

### ClaudeStartRuntime[adapter, opts] → RuntimeId
ランタイムを開始。

### ClaudeEvalViaRuntime[runtime, task, opts] → Null
ランタイム経由で評価。

### ClaudeApproveProposal[proposalId] → Null
プロポーザルを承認。

### ClaudeRuntimeSnapshot[runtime, name] → File
ランタイムスナップショット保存。

### ClaudeRuntimeRestore[name] → RuntimeId
ランタイム復元。

### ClaudeRuntimeListSnapshots[] → List
スナップショット一覧。

### ClaudeRegisterDAGRuntime[dag, runtime] → Null
DAG とランタイムを関連付け。

## レート制限・状態

### ClaudeRateLimitStatus[] → Association
レート制限状態。

### ClaudeRateLimitClear[] → Null
レート制限カウンタクリア。

### ClaudeShowAccessConfig[] → Null
アクセス設定を表示。

### ClaudeQueryShowContext[prompt] → String
送信されるコンテキストをプレビュー。

## Web 連携

### ClaudeWebSearch[query, opts] → List
Claude Code 経由 Web 検索 (無料)。

### ClaudeWebFetch[url, opts] → String
URL を Claude が取得・要約 (課金あり)。

### WebSearch[query] → List
別名: ClaudeWebSearch。

### WebFetch[url] → String
別名: ClaudeWebFetch。

## 機密データ

### MarkConfidential[var] → Null
変数を機密としてマーク。

### UnmarkConfidential[var] → Null
機密マークを解除。

### IsConfidential[var] → True | False
機密か判定。

### Confidential[expr] → ConfidentialWrapper
式を機密としてラップ。

### NonConfidential[expr] → expr
ラップ解除。

### ScanConfidentialCells[nb] → List
ノートブックの機密セル一覧。

## パレット

### ShowClaudePalette[] → NotebookObject
ClaudeCode パレットを表示。

## パッケージ管理 (ClaudePackageManager.wl 移管。alias 経由で呼び出し可)

### ClaudeBackupDataset[] → Dataset
バックアップ一覧。

### ClaudeMigrateBackupHistory[] → Null
履歴形式を移行。

### ClaudeRestorePackage[pkg, opts] → Null
パッケージ復元。

### ClaudeUpdatePackageHistory[pkg] → Dataset
更新履歴。

### ClaudeCreatePackage[name, opts] → Null
新規パッケージ作成。

### ClaudeUpdatePackage[pkg, instruction, opts] → TaskObject
LLM でパッケージ更新。

### ClaudeConvertToPaclet[pkg, opts] → File
Paclet 形式へ変換。

### ClaudeBuildTransactionAdapter[opts] → Association
トランザクションアダプタ構築。

### ClaudeUpdatePackageViaRuntime[pkg, instr, opts] → Null
ランタイム経由更新。

## 編集モード

### ClaudeAppendBlockToPackage[pkg, content] → Null
パッケージ末尾追記。

### ClaudeInsertBeforeAnchorInPackage[pkg, anchor, content] → Null
アンカー直前に挿入。

### ClaudeParseEditModeResponse[response] → Association
LLM 編集レスポンスをパース。

### ClaudeAutoDetectEditMode[response] → String
編集モード自動判定。

### ClaudeBuildEditModePromptInstructions[mode] → String
編集モード用プロンプト指示生成。

### ClaudeUpdatePackageWithMode[pkg, mode, instr] → Null
指定編集モードでパッケージ更新。

## 並列・優先度

### ClaudeBeginParallelKernels[] → Null
ParallelKernels を前置起動。

### ClaudeBeginHighPriority[] → Null
高優先度モード開始。

### ClaudeEndHighPriority[] → Null
高優先度モード終了。

### ClaudeRegisterPollingTick[key, fn] → Null
共有ポーリングに tick 登録。

### ClaudeUnregisterPollingTick[key] → Null
tick 解除。

### ClaudePollingTickKeys[] → List
登録キー一覧。

## ユーティリティ

### cleanOutput[text] → String
出力テキストの整形。

### stripANSI[text] → String
ANSI エスケープ除去。

## グローバル変数

### $ClaudeModel
型: {String, String} (tuple) または String, 初期値: {"claudecode", "claude-opus-4-7"}
Claude CLI/API に渡すモデル。`{provider, model}` 形式 (`provider` ∈ `"claudecode"|"anthropic"|"openai"|"lmstudio"`)。

### $ClaudePrivateModel
型: {String, String, String} 等, 初期値: 未設定
秘密データ処理用ローカルモデル。AutoPrivate -> True 時に使用。
例: `$ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}`

### $ClaudeDocModel
型: tuple, 初期値: $iModelSonnet
ドキュメント生成・更新で使うモデル。

### $ClaudeTestModel
型: String, 初期値: $ClaudeModel
分離検証用モデル。

### $ClaudeTimeout
型: Integer, 初期値: 1200
ClaudeQuery/ClaudeEval のタイムアウト秒。

### $ClaudeVerbose
型: True | False, 初期値: False
True で詳細ログを Messages に出力。

### $ClaudeMDPath
型: String, 初期値: ""
読み込む CLAUDE.md のパス。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md 内容。

### $ClaudeWorkingDirectory
型: String, 初期値: `FileNameJoin[{$HomeDirectory, "Claude Working"}]`
Claude Code の作業ディレクトリ。`.claude/CLAUDE.md`, `.claude/rules/`, `.claude/skills/` を読ませる。

### $ClaudeAccessibleDirs
型: List of String, 初期値: `{$packageDirectory}`
Claude Code に Read 許可する追加ディレクトリ。

### $ClaudeSnapshots
型: String, 初期値: `FileNameJoin[{$ClaudeWorkingDirectory, "snapshots"}]`
LLMGraphDAG スナップショット保存先。

### $ClaudeFallbackModels
型: List of {provider, model} or {provider, model, url}, 初期値: `{{"anthropic", $iModelOpus}, {"openai", "gpt-5.5"}}`
フォールバックモデル優先順位。NBAccess に同期される。

### $ClaudeDocRetryDelay
型: Numeric, 初期値: 60
ドキュメント生成のリトライ待機秒。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
ドキュメント生成の最大リトライ回数。

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースの最大文字数。

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval の再帰最大深度。0 で再帰禁止。

### $ClaudeEvalMode
型: Symbol, 初期値: Automatic
ClaudeEval の動作モード。

### $ClaudeEvalHook
型: Function | None, 初期値: None
ClaudeEval 完了時フック。

### $ClaudeEvalAutoThreshold
型: Numeric, 初期値: (実装依存)
自動 LLM 呼び出し閾値。

### $ClaudeEvalVerbose
型: True | False, 初期値: False
ClaudeEval 詳細ログ。

### $ClaudeEvalAutoLLMMinLength
型: Integer
自動 LLM 起動の最小文字数。

### $ClaudeEvalAutoLLMMinNewlines
型: Integer
自動 LLM 起動の最小改行数。

### $claudecodeVersion
型: String
パッケージバージョン。

### $ClaudePackageKeywordMap
型: Association, 初期値: `<||>`
外部パッケージのキーワード登録。プロンプトに該当語があると当該パッケージの api.md が自動注入される。
例: `$ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒切"}`

### $ClaudeRoutingProviders
型: List, 初期値: (実装依存)
ルーティング対象プロバイダ一覧。

### $UseClaudeRuntime
型: True | False, 初期値: False
ランタイム経由実行を有効化。

### $ClaudeLastRuntimeId
型: String | None
直近ランタイム ID。

### $ClaudeRuntimeAsyncExecution
型: True | False
コード実行を ParallelSubmit で非同期化。

### $ClaudeRuntimeAsyncForce
型: True | False
非同期実行を強制。

### $ClaudeRuntimeAsyncSuppressInputEval
型: True | False
非同期実行時の Input セル評価を抑制。

### $ClaudePriorityModeUntil
型: AbsoluteTime | None
高優先度モード有効期限。

### $LLMGraphMaxConcurrency
型: Integer
LLMGraph 並列度上限。

### $LLMGraphAutoStopThreshold
型: Integer
LLMGraph 自動停止閾値。

### $ClaudeSnapshots
型: String
LLMGraphDAG スナップショット保存先 (再掲)。

### $ClaudeEditModesVersion
型: String
編集モード仕様バージョン。

### $ClaudeEditModeAppendTagOpen
型: String
追記モード開始タグ。

### $ClaudeEditModeAppendTagClose
型: String
追記モード終了タグ。

### $ClaudeEditModeInsertTagClose
型: String
挿入モード終了タグ。

### $iMediaMaxImageSize
型: Integer
マルチモーダル送信画像の最大サイズ。

## オプションシンボル

以下は関数オプション値として用いられる公開シンボル。

### Fallback
True | False (デフォルト False)。Claude Code 利用不可時にフォールバックモデルへ自動切替。

### AutoPrivate
True | False (デフォルト False)。True で秘密変数アクセス時に `Model -> $ClaudePrivateModel, PrivacySpec -> Automatic` を自動付与。

### AutoEvaluate
True | False (デフォルト True)。ClaudeEval 生成 Input セルの自動実行。

### StartTime
DateObject (デフォルト Now)。実行開始時刻。

### Timeout
Numeric | Automatic。API タイムアウト秒。

### TargetFiles
List。対象ファイル。

### TargetFunctions
List。対象関数名。

### Mode
String。動作モード。

### DryRun
True | False。実行せず計画のみ。

### Inherit
True | False (デフォルト True)。CreateClaudeSession で履歴継承。

### License
String。ドキュメント生成のライセンス文。

### Model
Automatic | String | {provider, model} | {provider, model, url}。使用モデル。

### WebFetch
True | False。Web 取得有効化。

### WebSearch
True | False (デフォルト True)。Web 検索有効化。

### RepeatInterval
None | Quantity | {Quantity, Integer}。ClaudeEval の繰返間隔と最大回数。

### PrivacySpec
None | Automatic | Spec。プライバシ仕様。

### Keywords
List of String (デフォルト {})。ClaudeAttach のキーワード自動注入。

### Title
String | None (デフォルト None)。ClaudeAttach タイトル。

### Refetch
True | False (デフォルト False)。ClaudeAttach の URL 再取得。

### Owner
String。GitHub オーナー名。

### Repository
String。GitHub リポジトリ名。

### Branch
String。ブランチ名。

### BaseBranch
String。ベースブランチ名。

### References
List。ドキュメント参考文献。

### Demos
List。ドキュメントデモ URL。

### Disclaimer
List of String。免責文言。

### Acknowledgments
List of String。謝辞文言。

## 関連パッケージ

- [NBAccess](https://github.com/transreal/NBAccess) — ノートブック読み書き・プライバシ管理 (依存)
- [ClaudePackageManager](https://github.com/transreal/ClaudePackageManager) — パッケージ管理 API の実体
- [ClaudeRuntime](https://github.com/transreal/ClaudeRuntime) — ランタイム連携
- [github](https://github.com/transreal/github) — GitHubREST 連携