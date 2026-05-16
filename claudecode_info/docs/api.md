# claudecode API リファレンス

Claude Code CLI を Mathematica から呼び出すパッケージ。NBAccess・GitHubREST に依存。

## クエリ関数

### ClaudeQuery[prompt, opts] → String
Claude Code に prompt を送り応答文字列を返す（同期）。
Options: WebSearch -> True (無料), WebFetch -> False (課金, Fallback->True 必須), Fallback -> False, Timeout -> Automatic, Model -> Automatic, PrivacyLevel -> Automatic
マルチモーダル: `ClaudeQuery[{text, Image[...], File[path], ...}]` で画像/PDF/音声を送信。
session 指定: `ClaudeQuery[session, prompt]`。

### ClaudeQuerySync[prompt, opts] → String
同期版。WindowStatusArea に経過時間を表示。セッション履歴・ノートブック書き込みなし軽量版。
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic
Model ルーティング: Automatic+PrivacyLevel<=0.5 で CLI, >0.5 で $ClaudePrivateModel, {provider,model} 明示で API 経由。

### ClaudeQueryBg[prompt, opts] → String
SocketListen ハンドラ・ScheduledTask コールバック等の非同期コンテキストから安全に呼べる同期版。FrontEnd 操作・ScheduledTask 生成なし。
Options: Fallback -> False, Model -> Automatic, Timeout -> Automatic

### ClaudeQueryAsync[prompt, callback, nb, opts]
非同期問合せ。完了時 callback[応答] を呼ぶ。nb は出力先 NotebookObject。
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic

### ClaudeMath[task] → String
Mathematica コード生成に特化したプロンプトで Claude を呼ぶ。

### ClaudeExtractCode[response] → String
応答から最初の ```mathematica ブロックを抽出。

### ClaudeExtractAllCode[response] → List
応答から全 ```mathematica ブロックをリストで返す。

### ClaudeWriteResponse[nb, text, opts]
マークダウン形式テキストをノートブックのセルとして展開。
Options: AutoEvaluate -> False

## 評価系

### ClaudeEval[task, opts] → TaskObject
コードを非同期生成・表示しデフォルトセッションに履歴保存。
マルチモーダル: `ClaudeEval[{text, data, Image[...], ...}]` で Dataset/Image/任意式混在可。
session 指定: `ClaudeEval[session, task]`。
Options: AutoEvaluate -> True, StartTime -> Now, RepeatInterval -> None, Timeout -> Automatic, Model -> Automatic, AutoPrivate -> False, Fallback -> False, PrivacySpec -> Automatic
例: `ClaudeEval[task, StartTime -> Now + Quantity[3,"Hours"]]`
例: `ClaudeEval[task, RepeatInterval -> Quantity[2,"Hours"]]`
例: `ClaudeEval[task, RepeatInterval -> {Quantity[1,"Hours"], 5}]`（最大 5 回）

### ContinueEval[opts] → TaskObject
ContinueEval[instruction, opts] → TaskObject
ContinueEval[session, instruction, opts] → TaskObject
直前の応答を踏まえて継続。引数なしは "エラーを修正してください" で継続。
Options: StartTime -> Now, Timeout -> Automatic

### ContinueUpdate[opts]
ContinueUpdate[instruction, opts]
ContinueUpdate[{instruction, img}, opts]
ContinueUpdate[pkgName, instruction, opts]
直前の ClaudeUpdatePackage 結果を踏まえてバグ修正を継続。
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now

### ClaudeSpec[task] → String
ClaudeSpec[{task, image, ...}] → String
ノートブック内容から仕様書を生成。パレットからセル選択で呼出可。

### ClaudeDebug[code] → String
コードのデバッグ支援。

### ClaudeReview[content] → String
レビュー支援。

### ClaudeReviewChunked[content] → String
チャンク分割レビュー。

## セッション管理

### CreateClaudeSession[name, opts] → Session
CreateClaudeSession[session, opts] → Session
CreateClaudeSession[opts] → Session
名前付きセッションを作成。デフォルトでデフォルト履歴を継承。
Options: Inherit -> True

### ClaudeRestoreSession[] → List
ClaudeRestoreSession[name] → Session
セッション一覧またはリストア。

### ClaudeListSessions[]
ノートブック内全セッション一覧を表示。

### ClaudeDeleteSession[name]
ClaudeDeleteSession[name, "All"]
指定セッション削除。"All" で履歴も削除。

### ClaudeShowHistory[] / ClaudeShowHistory[session] / ClaudeShowHistory[name]
セッション履歴を表示。

### ClaudeSessionStatus[]
デフォルトセッションの状態を表示。

### ClaudeCompactHistory[session]
セッション履歴を圧縮。

### ClaudeHistorySize[session] → Integer
履歴サイズを返す。

### ClaudeShowAccessConfig[]
アクセス設定を表示。

### ClaudeQueryShowContext[]
最後のクエリのコンテキストを表示。

## 添付ファイル

### ClaudeAttach[path, opts]
ClaudeAttach[url, opts]
ClaudeAttach[session, path, opts]
参考資料をアタッチ。URL は PDF 化してキャッシュ。
Options: Keywords -> {}, Title -> None, Refetch -> False

### ClaudeDetach[path]
ClaudeDetach[session, path]
アタッチを解除。

### ClaudeAttachments[]
ClaudeAttachments[session]
添付一覧。

### ClearAttachments[]
ClearAttachments[session]
全添付を解除。

## 機密データ

### MarkConfidential[var] / MarkConfidential[var, level]
変数を機密としてマーク。level: 0.0–1.0。

### UnmarkConfidential[var]
機密マークを解除。

### IsConfidential[var] → Bool
機密判定。

### Confidential[expr] → Expr
式を機密ラッパで包む。

### NonConfidential[expr] → Expr
機密解除ラッパ。

### ScanConfidentialCells[]
ノートブック内の機密セルを走査。

## ディレクティブ

### ClaudeAddDirective[name, content, opts]
CLAUDE.md/rules/skills を追加。

### ClaudeRestoreDirective[name]
ディレクティブを復元。

### ClaudeListDirectives[]
ディレクティブ一覧。

### ClaudeUpdateDirective[name, instruction]
ディレクティブ更新。

### ClaudeDirectiveBackupDataset[] → Dataset
バックアップ履歴データセット。

### ClaudeSyncDirectives[]
ディレクティブを $ClaudeWorkingDirectory/.claude/ に同期。

## ドキュメント生成

### ClaudeCreateDocumentation[pkgName, opts]
パッケージのドキュメント一式を生成。リミット時自動停止し再実行で続行。README は最後。
Options: References -> {}, Demos -> {}, Disclaimer -> {}, Acknowledgments -> {}, License -> "", Model -> Automatic, Owner -> "", Repository -> "", Branch -> "main", BaseBranch -> "main"

### ClaudeUpdateDocumentation[pkgName, instruction, opts]
既存ドキュメントを部分更新。
Options: References -> {}, Demos -> {}, Disclaimer -> {}, Acknowledgments -> {}, License -> "", Model -> Automatic, TargetFiles -> All

## パッケージ管理

注: ClaudeCreatePackage, ClaudeUpdatePackage, ClaudeBackupDataset, ClaudeMigrateBackupHistory, ClaudeRestorePackage, ClaudeUpdatePackageHistory, ClaudeConvertToPaclet は ClaudePackageManager.wl に移管済み。alias 経由で呼出可。

### ClaudeCheckSeparation[pkgName] → Dataset
NBAccess 分離原則違反を検査。

### ClaudeFixSeparation[pkgName]
分離原則違反を修正。

### ClaudeCommand[cmd] → String
Claude Code CLI のスラッシュコマンド実行。例: `ClaudeCommand["/init"]`

### ClaudeStatus[]
パッケージ状態を表示。

### ClaudeAbort[]
進行中処理を中断。

### ClaudePrepareCommit[opts]
変更履歴からコミットメッセージを準備。

## ランタイム

### ClaudeBuildRuntimeAdapter[opts] → Association
ランタイムアダプタを構築。
Options: "ExecutionTimeoutSeconds" -> 30, "DefaultTimeoutSeconds" -> 30

### ClaudeStartRuntime[adapter] → RuntimeId
ランタイム起動。

### ClaudeEvalViaRuntime[runtimeId, task]
ランタイム経由で評価。

### ClaudeApproveProposal[proposalId]
提案を承認。

### ClaudeRuntimeSnapshot[runtimeId] → SnapshotId
ランタイム状態を保存。

### ClaudeRuntimeRestore[snapshotId]
スナップショットから復元。

### ClaudeRuntimeListSnapshots[] → List
スナップショット一覧。

### ClaudeRegisterDAGRuntime[runtimeId]
DAG ランタイムを登録。

## レート制限

### ClaudeRateLimitStatus[] → Association
レート制限の状態。

### ClaudeRateLimitClear[]
レート制限カウンタをクリア。

## Web

### ClaudeWebSearch[query] → String
ClaudeWebFetch[url] → String
Web 検索 / Fetch（CLI 経由、Fetch は要 Fallback->True）。

### WebSearch[query] → String
WebFetch[url] → String
別名（Wolfram 組込関数名と衝突するため要注意）。

## ノートブック LLM グラフ

### NotebookLLMGraph[opts] → Graph
現ノートブックの LLM 呼出グラフを構築。

### NotebookLLMGraphPlot[opts] → Graphics
ノートブック LLM グラフを可視化。

### NotebookLLMGraphBuild[opts] → Graph
LLM グラフ構築。

### NotebookLLMGraphNodes[] → List
ノード一覧。

### NotebookLLMGraphValidate[] → Bool
グラフ検証。

### NotebookLLMGraphFetchResponse[nodeId] → String
ノード応答取得。

### NotebookLLMGraphSubSteps[nodeId] → List
サブステップ取得。

### NotebookLLMGraphFetchL2[nodeId] → String
L2 応答取得。

### NotebookLLMGraphErrors[] → List
エラー一覧。

### NotebookLLMGraphUpdateL2Status[nodeId, status]
L2 ステータス更新。

### NotebookLLMGraphPlotL2[opts] → Graphics
L2 グラフ可視化。

### NotebookLLMGraphRerun[nodeId]
ノード再実行。

### NotebookLLMGraphInvalidateDownstream[nodeId]
下流ノードを無効化。

### NotebookLLMGraphSummary[] → Association
グラフサマリ。

### NotebookLLMGraphExtractThread[nodeId] → List
NotebookLLMGraphApplyThread[nodeId, thread]
会話スレッド抽出・適用。

## LLM グラフ実行（DAG）

### LLMGraphExecute[graph, opts] → JobId
LLM グラフを非同期実行。

### LLMGraphExecuteStatus[jobId] → Association
実行状態。

### LLMGraphExecuteCancel[jobId]
実行をキャンセル。

### LLMGraphDAGCreate[spec, opts] → DAGId
DAG を作成。

### LLMGraphDAGStatus[dagId] → Association
DAG 状態。

### LLMGraphDAGCancel[dagId] / LLMGraphDAGStop[dagId]
DAG をキャンセル/停止。

### LLMGraphDAGRetry[dagId, nodeId]
ノードをリトライ。

### LLMGraphDAGRebuild[dagId]
DAG を再構築。

### LLMGraphDAGFindByContext[ctx] → DAGId
コンテキストから DAG を検索。

### LLMGraphDAGInspect[dagId] → Association
DAG 詳細を取得。

### LLMGraphDAGMarkFailed[dagId, nodeId]
ノードを失敗扱いに。

### LLMGraphDAGSnapshot[dagId] → SnapshotId
DAG スナップショット保存。

### LLMGraphDAGRestore[snapshotId]
DAG スナップショット復元。

### LLMGraphDAGListSnapshots[] → List
DAG スナップショット一覧。

### LLMGraphDAGPlot[dagId] → Graphics
DAG 可視化。

### LLMGraphDAGMergeHistory[dagId]
履歴をマージ。

## 並列・優先度

### ClaudeBeginParallelKernels[]
ParallelKernels を前置起動。

### ClaudeBeginHighPriority[duration]
ClaudeEndHighPriority[]
高優先度モードの開始/終了。

### ClaudeRegisterPollingTick[key, fn]
ClaudeUnregisterPollingTick[key]
ClaudePollingTickKeys[] → List
共有ポーリングのフック登録/解除。

## ファイル/編集モード

### NBFileTranslate[path] → String
ノートブックファイルを翻訳。

### ClaudeProcessFile[path, opts]
ファイル処理。

### ClaudeAppendBlockToPackage[pkgName, block]
パッケージ末尾にブロックを追記。

### ClaudeInsertBeforeAnchorInPackage[pkgName, anchor, content]
アンカー前にコンテンツ挿入。

### ClaudeParseEditModeResponse[response] → Association
編集モード応答をパース。

### ClaudeAutoDetectEditMode[content] → String
編集モードを自動判定。

### ClaudeBuildEditModePromptInstructions[mode] → String
編集モード用プロンプト指示文を生成。

### ClaudeUpdatePackageWithMode[pkgName, instruction, mode, opts]
編集モード指定でパッケージ更新。

## パレット

### ShowClaudePalette[]
Claude Code パレットを表示。

## ユーティリティ

### cleanOutput[str] → String
出力をクリーンアップ。

### stripANSI[str] → String
ANSI エスケープを除去。

## 変数

### $ClaudeModel
型: {String, String} | String, 初期値: {"claudecode", "claude-opus-4-7"}
モデル指定。tuple {provider, model} 形式。provider: "claudecode"|"anthropic"|"openai"|"lmstudio"。

### $ClaudePrivateModel
型: {String, String, String} | String, 初期値: 未定義
ローカル秘密処理用モデル。例: `{"lmstudio","openai/gpt-oss-20b","http://127.0.0.1:1234"}`

### $ClaudeTestModel
型: String | List, 初期値: $ClaudeModel と同じ
分離検証用モデル。

### $ClaudeDocModel
型: String | List, 初期値: $iModelSonnet
ドキュメント生成用モデル。

### $ClaudeFallbackModels
型: List, 初期値: `{{"anthropic","claude-opus-4-7"},{"openai","gpt-5.5"}}`
フォールバック優先順位。NBAccess に自動同期。

### $ClaudeTimeout
型: Integer, 初期値: 1200
タイムアウト秒数。

### $ClaudeVerbose
型: Bool, 初期値: False
詳細ログ出力フラグ。

### $ClaudeWorkingDirectory
型: String, 初期値: `FileNameJoin[{$HomeDirectory, "Claude Working"}]`
Claude Code 作業ディレクトリ。配下の .claude/CLAUDE.md, rules/, skills/ を読込。

### $ClaudeMDPath
型: String, 初期値: ""
読込済み CLAUDE.md のパス。

### $ClaudeMDContent
型: String, 初期値: ""
CLAUDE.md の内容。

### $ClaudeAccessibleDirs
型: List, 初期値: `{$packageDirectory}`
Claude Code に Read 許可する追加ディレクトリ。

### $ClaudeSnapshots
型: String, 初期値: `$ClaudeWorkingDirectory/snapshots`
LLMGraphDAG スナップショット保存先。

### $ClaudeDocRetryDelay
型: Number, 初期値: 60
ドキュメント生成リトライ待機秒。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
ドキュメント生成最大リトライ回数。

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースの最大文字数。

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval の再帰最大深度。0 で再帰禁止。

### $ClaudeEvalMode
型: String | Automatic, 初期値: Automatic
評価モード。

### $ClaudeEvalHook
型: Function | None, 初期値: None
評価フック。

### $ClaudeEvalAutoThreshold
型: Number, 初期値: 自動
自動 LLM 切替閾値。

### $ClaudeEvalVerbose
型: Bool, 初期値: False
評価系の詳細ログ。

### $ClaudeEvalAutoLLMMinLength
型: Integer
LLM 自動判定の最小コード長。

### $ClaudeEvalAutoLLMMinNewlines
型: Integer
LLM 自動判定の最小改行数。

### $claudecodeVersion
型: String
パッケージバージョン。

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
外部パッケージがキーワードを登録するための連想。プロンプト中のキーワードに応じて対応パッケージの api.md が自動注入される。
例: `$ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒切"}`

### $ClaudeRoutingProviders
型: List
ルーティング対象プロバイダ一覧。

### $UseClaudeRuntime
型: Bool, 初期値: False
ランタイム経由実行を有効化。

### $ClaudeLastRuntimeId
型: String
最後に起動したランタイム ID。

### $ClaudeRuntimeAsyncExecution
型: Bool, 初期値: False
ランタイムコード実行を ParallelSubmit で非同期化。

### $ClaudeRuntimeAsyncForce
型: Bool, 初期値: False
非同期実行の強制適用。

### $ClaudeRuntimeAsyncSuppressInputEval
型: Bool, 初期値: False
Input セルの自動評価を抑制。

### $ClaudePriorityModeUntil
型: AbsoluteTime | None
高優先度モードの終了時刻。

### $LLMGraphMaxConcurrency
型: Integer
LLM グラフ最大同時実行数。

### $LLMGraphAutoStopThreshold
型: Number
自動停止閾値。

### $ClaudeSnapshots
型: String
DAG スナップショット保存先。

### $iMediaMaxImageSize
型: Integer
マルチモーダル送信画像の最大サイズ。

### $ClaudeEditModesVersion
型: String
編集モード仕様のバージョン。

### $ClaudeEditModeAppendTagOpen / $ClaudeEditModeAppendTagClose
型: String
追記モードのタグ文字列。

### $ClaudeEditModeInsertTagClose
型: String
挿入モードの終了タグ文字列。

## 共通オプションシンボル

### Fallback
True: Claude Code 利用不可時にフォールバックモデルへ自動切替。False (デフォルト): エラーを返す。

### AutoPrivate
True: 秘密変数にアクセスするタスクで自動的に Model -> $ClaudePrivateModel, PrivacySpec -> Automatic を付与。

### AutoEvaluate
生成された Input セルの自動実行制御。デフォルト True。

### StartTime
TaskObject の実行開始時刻 (DateObject)。

### Timeout
API フォールバックのタイムアウト秒数。Automatic で 600。

### TargetFiles / TargetFunctions
ドキュメント/操作対象の限定。

### Mode
編集/動作モード。

### DryRun
True で実行せず計画のみ。

### Inherit
セッション履歴継承。

### License
README ライセンスセクションの内容。空文字列でデフォルト MIT 自動挿入。

### Model
Claude モデル指定。{provider, model} 形式。

### WebFetch / WebSearch
ClaudeQuery のオプション。WebSearch は無料デフォルト True、WebFetch は課金で False (Fallback->True 必須)。

### RepeatInterval
ClaudeEval/ContinueEval の繰返間隔。`Quantity[2,"Hours"]` または `{Quantity[1,"Hours"], 5}`。

### PrivacySpec
プライバシ仕様。

### Keywords / Title / Refetch
ClaudeAttach のオプション。

### Owner / Repository / Branch / BaseBranch
GitHub 連携時のリポジトリ指定。

### References / Demos / Disclaimer / Acknowledgments
ドキュメント生成セクション。

## 関連パッケージ

- [NBAccess](https://github.com/transreal/NBAccess) — ノートブック読書き・プライバシ管理（必須依存）
- [github](https://github.com/transreal/github) — GitHubREST API ラッパ（License 自動挿入で利用）
- [ClaudePackageManager](https://github.com/transreal/ClaudePackageManager) — ClaudeCreatePackage/UpdatePackage/ConvertToPaclet 等の移管先
- [ClaudeRuntime](https://github.com/transreal/ClaudeRuntime) — ランタイム関連
- [NotebookExtensions](https://github.com/transreal/NotebookExtensions) — ノートブック拡張