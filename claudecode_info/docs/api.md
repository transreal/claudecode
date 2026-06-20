# claudecode API リファレンス

## クエリ関数

### ClaudeQuery[task, opts]
Claude CLI にテキストクエリを送信してノートブックにレスポンスを出力する。
→ String | $Failed
Options: Model -> $ClaudeModel, Timeout -> $ClaudeTimeout, Fallback -> False, AutoPrivate -> False, WebSearch -> False, WebFetch -> False, OutputMode -> Automatic, AutoCellize -> False, PrivacySpec -> Automatic, Integrations -> Automatic

### ClaudeQuerySync[task, opts]
ClaudeQuery の同期版。結果文字列を直接返す。
→ String | $Failed
Options: ClaudeQuery と同じ

### ClaudeQueryBg[task, opts]
バックグラウンド非同期クエリ。ノートブックセルに非同期で結果を書き込む。
→ String (タスクID) | $Failed
Options: Model, Timeout, NonBlocking -> True, Fallback, AutoPrivate

### ClaudeQueryAsync[task, opts]
コールバック付き非同期クエリ。
→ String (タスクID) | $Failed

### ClaudeQueryAsyncSilent[task, opts]
結果セルを作成しない非同期クエリ。内部ツール使用向け。
→ String | $Failed

### ClaudeEnsureSilentNotebook[]
サイレントノートブック (バックグラウンド出力先) を確保する。
→ NotebookObject

### ClaudeWriteResponse[text]
テキストをノートブックのレスポンスセルとして書き込む。
→ CellObject

### ClaudeMath[task, opts]
数式生成に特化したクエリ。TraditionalForm 出力を優先する。
→ Expression | $Failed

### ClaudeExtractCode[response]
LLM レスポンス文字列からコードブロックを抽出する。
→ String | $Failed

### ClaudeExtractAllCode[response]
LLM レスポンス文字列から全コードブロックをリストで抽出する。
→ {String...}

## 評価・コード生成

### ClaudeEval[task, opts]
タスクからコードを生成しノートブック内で評価する。ClaudeSpec + 生成 + 実行の統合関数。
→ Expression | $Failed
Options: Model -> $ClaudeModel, Timeout -> $ClaudeTimeout, Fallback -> False, AutoPrivate -> False, AutoEvaluate -> True, AutoCellize -> False, PrivacySpec -> Automatic, OutputMode -> Automatic, WebSearch -> False, WebFetch -> False

### ContinueEval[task, opts]
前回の ClaudeEval 結果を踏まえて継続タスクを実行する。
→ Expression | $Failed
Options: ClaudeEval と同じ

### ContinueUpdate[task, opts]
ContinueEval の変種。前回出力セルをインプレースで更新する。
→ Expression | $Failed

### ClaudeSpec[task]
### ClaudeSpec[{task, image, ...}]
ノートブック内容からプログラムの仕様を生成する。パレットからセル選択で呼び出し可能。画像付きリスト形式でマルチモーダル入力も可能。
→ String

### ClaudeDebug[task, opts]
デバッグ用クエリ。エラーメッセージと現在のノートブックコンテキストを自動付加する。
→ Expression | $Failed

### ClaudeReview[task, opts]
コードレビュー用クエリ。指定ファイルまたは現在のノートブックを対象にレビューを実施する。
→ String | $Failed
Options: TargetFiles -> Automatic, TargetFunctions -> All, Mode -> "review"

### ClaudeReviewChunked[task, opts]
大規模コードを分割してレビューする。
→ String | $Failed

## セッション管理

### CreateClaudeSession[name, opts]
名前付き Claude セッションを作成する。過去の会話履歴を持つセッションコンテキストを確立する。
→ String (セッションID) | $Failed
Options: Inherit -> None (継承元セッション名)

### ClaudeRestoreSession[name]
保存済みセッションをリストアする。
→ True | $Failed

### ClaudeListSessions[]
保存済みセッション一覧を返す。
→ {String...}

### ClaudeDeleteSession[name]
指定セッションを削除する。
→ True | $Failed

### ClaudeShowHistory[opts]
現在のセッション会話履歴をノートブックに表示する。
→ Null
Options: OutputMode -> "dataset"

### ClaudeCompactHistory[]
会話履歴を圧縮して長い会話のコンテキストを縮小する。
→ True | $Failed

### ClaudeHistorySize[]
現在の会話履歴のサイズ (文字数) を返す。
→ Integer

### ClaudeSessionStatus[]
現在のセッション状態を表示する。
→ Dataset | Null

## 添付ファイル

### ClaudeAttach[file, opts]
ファイルまたは URL をセッションの添付ファイルとして登録する。
→ Association | $Failed
Options: Keywords -> {}, Title -> Automatic, Refetch -> False

### ClaudeDetach[id]
添付ファイルをセッションから除去する。
→ True | $Failed

### ClaudeAttachments[]
現在の添付ファイル一覧を返す。
→ Dataset

### ClearAttachments[]
全添付ファイルをクリアする。
→ Null

## 状態・制御

### ClaudeStatus[]
Claude CLI の現在の状態 (実行中/待機中/エラー) を返す。
→ Association

### ClaudeAbort[]
実行中の Claude CLI プロセスを中止する。
→ True | $Failed

### ClaudeRateLimitStatus[]
レートリミット状態を確認する。
→ Association

### ClaudeRateLimitClear[]
レートリミットカウンタをリセットする。
→ Null

### ClaudeCommand[cmd]
Claude Code CLI スラッシュコマンドを実行する。
→ String | $Failed
例: ClaudeCommand["/compact"]

### ClaudeShowAccessConfig[]
現在のアクセス設定 (許可ディレクトリ、プロバイダ等) を表示する。
→ Null

### ClaudeQueryShowContext[]
次回クエリに使用されるコンテキスト内容をプレビュー表示する。
→ String

### ShowClaudePalette[]
Claude Code 操作パレットをノートブックに表示する。
→ Null

## 機密データ

### MarkConfidential[var]
変数を機密としてマークする。ClaudeEval でのコード生成時にローカルモデル使用を強制する。
→ var

### UnmarkConfidential[var]
機密マークを解除する。
→ var

### IsConfidential[var]
変数が機密マークされているか確認する。
→ True | False

### Confidential[expr]
式を機密ラッパーで包む。
→ Confidential[expr]

### NonConfidential[expr]
機密ラッパーを外す。
→ expr

### ScanConfidentialCells[]
現在のノートブック内の機密変数を含むセルをスキャンする。
→ {CellObject...}

## Web 機能

### ClaudeWebSearch[query, opts]
Claude CLI 経由でウェブ検索を実行する。
→ String | $Failed
Options: Timeout -> $ClaudeTimeout

### ClaudeWebFetch[url, opts]
Claude CLI 経由で URL のコンテンツを取得する。
→ String | $Failed
Options: Timeout -> $ClaudeTimeout

### WebSearch[query]
ClaudeWebSearch の簡略形。
→ String | $Failed

### WebFetch[url]
ClaudeWebFetch の簡略形。
→ String | $Failed

## ドキュメント生成

### ClaudeCreateDocumentation[packageName, opts]
パッケージの包括的ドキュメント一式 (api.md, README.md 等) を新規生成する。リミット到達時に自動停止し、再実行で未生成分のみ続行する。README.md は最後に生成される。
→ True | $Failed
Options: References -> {}, Demos -> {}, Disclaimer -> {}, License -> "", Acknowledgments -> {}, Model -> $ClaudeDocModel, DryRun -> False

### ClaudeUpdateDocumentation[packageName, instruction, opts]
既存ドキュメントを指示に従って部分更新する。
→ True | $Failed
Options: References -> {}, Demos -> {}, Disclaimer -> {}, License -> "", Acknowledgments -> {}, Model -> $ClaudeDocModel

## ディレクティブ管理

### ClaudeAddDirective[name, content, opts]
CLAUDE.md にディレクティブを追加する。
→ True | $Failed
Options: DryRun -> False

### ClaudeUpdateDirective[name, content, opts]
既存ディレクティブを更新する。
→ True | $Failed

### ClaudeRestoreDirective[name]
バックアップからディレクティブをリストアする。
→ True | $Failed

### ClaudeListDirectives[]
登録済みディレクティブ一覧を返す。
→ Dataset

### ClaudeDirectiveBackupDataset[]
ディレクティブのバックアップ履歴を Dataset で返す。
→ Dataset

### ClaudeSyncDirectives[]
ディレクティブをファイルシステムと同期する。
→ True | $Failed

## NBAccess 分離検証

### ClaudeCheckSeparation[packageName]
パッケージの NBAccess 分離原則違反を検証する。結果をキャッシュし ClaudeFixSeparation で再利用される。
→ Association | $Failed

### ClaudeFixSeparation[packageName]
ClaudeCheckSeparation の検出結果に基づいて分離違反を修正する。
→ True | $Failed

## コミット準備

### ClaudePrepareCommit[opts]
変更差分を解析してコミットメッセージ候補を生成する。
→ String | $Failed
Options: BaseBranch -> "main", Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, Baseline -> Automatic, DryRun -> False

## NotebookLLMGraph

### NotebookLLMGraph[nb]
ノートブックの LLM 依存グラフを取得または構築する。
→ Graph | $Failed

### NotebookLLMGraphBuild[nb, opts]
ノートブックから LLM グラフを再構築する。
→ Graph | $Failed
Options: Model -> $ClaudeModel

### NotebookLLMGraphPlot[nb, opts]
LLM グラフを可視化する。
→ Graphics | $Failed

### NotebookLLMGraphNodes[nb]
グラフのノード一覧を返す。
→ {Association...}

### NotebookLLMGraphValidate[nb]
グラフの整合性を検証する。
→ True | {String...}

### NotebookLLMGraphFetchResponse[nb, nodeId]
指定ノードの LLM レスポンスを取得する。
→ String | $Failed

### NotebookLLMGraphSubSteps[nb, nodeId]
ノードのサブステップ一覧を返す。
→ {Association...}

### NotebookLLMGraphFetchL2[nb, nodeId]
L2 (詳細) レスポンスを取得する。
→ String | $Failed

### NotebookLLMGraphErrors[nb]
グラフ内のエラーノード一覧を返す。
→ {Association...}

### NotebookLLMGraphUpdateL2Status[nb, nodeId, status]
L2 ステータスを更新する。
→ True | $Failed

### NotebookLLMGraphPlotL2[nb, opts]
L2 グラフを可視化する。
→ Graphics | $Failed

### NotebookLLMGraphRerun[nb, nodeIds, opts]
指定ノードを再実行する。
→ True | $Failed

### NotebookLLMGraphInvalidateDownstream[nb, nodeId]
指定ノードの下流ノードを無効化する。
→ {String...} (無効化されたノードID)

### NotebookLLMGraphSummary[nb]
グラフのサマリーを返す。
→ Association

### NotebookLLMGraphExtractThread[nb, nodeId]
ノードのスレッドを抽出する。
→ {Association...}

### NotebookLLMGraphApplyThread[nb, thread]
スレッドをグラフに適用する。
→ True | $Failed

## LLMGraphDAG

### LLMGraphDAGCreate[spec, opts]
DAG 形式の LLM グラフを作成する。
→ String (DAG ID) | $Failed
Options: Model -> $ClaudeModel, Timeout -> $ClaudeTimeout

### LLMGraphDAGStatus[dagId]
DAG の実行状態を返す。
→ Association

### LLMGraphDAGCancel[dagId]
DAG 実行をキャンセルする。
→ True | $Failed

### LLMGraphDAGStop[dagId]
DAG 実行を停止する。
→ True | $Failed

### LLMGraphDAGRetry[dagId, nodeId]
失敗したノードを再試行する。
→ True | $Failed

### LLMGraphDAGRebuild[dagId]
DAG を再構築する。
→ String (新 DAG ID) | $Failed

### LLMGraphDAGFindByContext[context]
コンテキストに一致する DAG を検索する。
→ {String...}

### LLMGraphDAGInspect[dagId]
DAG の詳細情報を表示する。
→ Dataset | Null

### LLMGraphDAGMarkFailed[dagId, nodeId]
指定ノードを失敗状態にマークする。
→ True | $Failed

### LLMGraphDAGSnapshot[dagId, opts]
DAG のスナップショットを保存する。
→ String | $Failed
Options: Title -> Automatic

### LLMGraphDAGRestore[dagId, snapshotName]
スナップショットから DAG をリストアする。
→ True | $Failed

### LLMGraphDAGListSnapshots[dagId]
DAG のスナップショット一覧を返す。
→ {String...}

### LLMGraphDAGPlot[dagId, opts]
DAG を可視化する。
→ Graphics | $Failed

### LLMGraphDAGMergeHistory[dagId1, dagId2]
2 つの DAG 履歴をマージする。
→ String (新 DAG ID) | $Failed

### LLMGraphExecute[graph, opts]
LLM グラフを実行する。
→ Association | $Failed
Options: Model -> $ClaudeModel, Timeout -> $ClaudeTimeout

### LLMGraphExecuteStatus[taskId]
実行タスクの状態を返す。
→ Association

### LLMGraphExecuteCancel[taskId]
実行タスクをキャンセルする。
→ True | $Failed

## ランタイム

### ClaudeBuildRuntimeAdapter[opts]
ClaudeRuntime 用のアダプタ Association を構築する。"DefaultTimeoutSeconds" キーを持つ。
→ Association
Options: ExecutionTimeoutSeconds -> 30 (NBExecuteHeldExpr に渡すタイムアウト秒; proposal["ExpectedSeconds"] > adapter["DefaultTimeoutSeconds"] > 30 の優先順で適用)
例: adapter = ClaudeBuildRuntimeAdapter["ExecutionTimeoutSeconds" -> 60]

### ClaudeStartRuntime[adapter, opts]
ランタイムセッションを開始する。
→ String (ランタイムID) | $Failed

### ClaudeEvalViaRuntime[task, runtimeId, opts]
ランタイム経由でタスクを評価する。
→ Expression | $Failed
Options: Timeout -> $ClaudeTimeout

### ClaudeApproveProposal[proposalId]
提案されたコードの実行を承認する。
→ True | $Failed

### ClaudeRuntimeSnapshot[runtimeId, opts]
ランタイム状態のスナップショットを保存する。
→ String | $Failed

### ClaudeRuntimeRestore[runtimeId, snapshotName]
スナップショットからランタイムをリストアする。
→ True | $Failed

### ClaudeRuntimeListSnapshots[runtimeId]
ランタイムスナップショット一覧を返す。
→ {String...}

### ClaudeRegisterDAGRuntime[dagId, runtimeId]
DAG とランタイムを関連付ける。
→ True | $Failed

### ClaudeBeginParallelKernels[]
並列カーネルを事前起動する (Phase 32k)。
→ Null

## ファイル変換・出力

### NBFileTranslate[file, targetLang, opts]
ノートブックファイルを他言語/形式に変換する。
→ String (出力ファイルパス) | $Failed
Options: Model -> $ClaudeModel, OutputMode -> Automatic

### ClaudeProcessFile[file, task, opts]
ファイルに対して LLM タスクを実行する。
→ String | $Failed

### cleanOutput[text]
出力テキストから不要なフォーマットを除去する。
→ String

### stripANSI[text]
ANSI エスケープシーケンスを除去する。
→ String

## 編集モード (EditModes)

### ClaudeAppendBlockToPackage[packageName, block]
パッケージファイルにコードブロックを追記する。
→ True | $Failed

### ClaudeInsertBeforeAnchorInPackage[packageName, anchor, block]
パッケージファイル内のアンカー行の前にブロックを挿入する。
→ True | $Failed

### ClaudeParseEditModeResponse[response]
LLM の編集モードレスポンスをパースして差分操作リストを返す。
→ {Association...}

### ClaudeAutoDetectEditMode[packageName]
パッケージのコンテキストから最適な編集モードを自動選択する。
→ "append" | "insert" | "replace"

### ClaudeBuildEditModePromptInstructions[mode, opts]
指定編集モード用のプロンプト指示文を構築する。
→ String

### ClaudeUpdatePackageWithMode[packageName, instruction, mode, opts]
指定編集モードでパッケージを更新する。
→ True | $Failed

## パレット サービスコントロール

### ClaudeRegisterPaletteServiceControl[spec]
ShowClaudePalette の Privacy セクション直下に start/stop トグルを登録する。spec は Association で "Id", "RunningQ" (→True|False|Missing の Function), "Start", "Stop", "RunningLabel", "StoppedLabel", "UnknownLabel" を必須キーとし、省略可能な "RunningColor", "StoppedColor" を持つ。各 Label は String または 0 引数 Function。同一 Id の再登録で上書き。ShowClaudePalette[] で反映される。
→ String (Id)

### ClaudeUnregisterPaletteServiceControl[id]
パレットサービストグルを id で削除する。
→ Null

## ポーリング・優先制御

### ClaudeRegisterPollingTick[key, func]
定期ポーリングコールバックを登録する。
→ True

### ClaudeUnregisterPollingTick[key]
ポーリングコールバックを解除する。
→ True

### ClaudePollingTickKeys[]
登録済みポーリングキー一覧を返す。
→ {String...}

### ClaudeEnqueueFinalAction[func]
セッション終了時に実行するアクションをエンキューする。
→ Null

### ClaudeBeginHighPriority[secs]
指定秒数の間、高優先度モードに移行する。
→ Null

### ClaudeEndHighPriority[]
高優先度モードを終了する。
→ Null

## グローバル変数

### $ClaudeModel
型: {String, String} | String, 初期値: {"claudecode", ""}
使用モデルを指定する tuple {provider, modelName}。provider は "claudecode" (Claude Code CLI, Pro/Max サブスク内、課金なし), "chatgptcodex" (ChatGPT Codex CLI, サブスク内), "anthropic" (Anthropic API, 課金), "openai" (OpenAI API, 課金), "lmstudio" (ローカル LLM, 課金なし)。
例: $ClaudeModel = {"claudecode", "claude-opus-4-8"}

### $ClaudeAdvisaryModel
型: String | {String, String}, 初期値: "chatgptcodex"
仕様レビュー Orchestrator ワークフローでの Codex (アドバイザリ) ロールに使用するモデル/プロバイダ。Claude Code ロールは $ClaudeModel を使用する。

### $ClaudeStandardFont
型: String, 初期値: "Yu Gothic UI"
ClaudeEval が生成する出力コード (Grid/Column/Style/Button 等) で統一使用するフォント名。プロンプトに埋め込まれ FontFamily 指定を強制する。ロード後に任意のフォント名に変更可能。

### $ClaudePrivateModel
型: {String, String} | {String, String, String}, 初期値: 未設定
機密データ処理用ローカルモデル指定。AutoPrivate -> True 時に機密変数を含むタスクで使用される。
例: $ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}

### $ClaudeTimeout
型: Integer, 初期値: 1200
ClaudeQuery/ClaudeEval 等のデフォルトタイムアウト秒数。

### $ClaudeVerbose
型: Boolean, 初期値: False
True で履歴コンパクション等の詳細ログを Messages に出力する。

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code CLI の作業ディレクトリ。配下の .claude/CLAUDE.md, .claude/rules/, .claude/skills/ を Claude Code が参照する。

### $OpenaiWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "OpenAI Working"}]
OpenAI/ChatGPT Codex CLI の作業ディレクトリ。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索または手動上書き可能。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。空の場合は CLAUDE.md が見つからないか内容が空。

### $ClaudeSnapshots
型: String, 初期値: FileNameJoin[{$ClaudeWorkingDirectory, "snapshots"}]
LLMGraphDAG スナップショットの保存ディレクトリ。

### $ClaudeAccessibleDirs
型: {String...}, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。iPrepareClaudeProjectDirectory が一時的に settings.json に注入する。ノートブックの TaggingRules に NBSetAccessibleDirs で永続化も可能。NotebookDirectory は初回使用時にダイアログで許可確認される ($packageDirectory 配下を除く)。

### $ClaudeFallbackModels
型: {{String...}...}, 初期値: {{"chatgptcodex","gpt-5.5"},{"anthropic","claude-opus-4-8"},{"openai","gpt-5.5"}}
フォールバックモデル優先順位リスト。各要素は {provider, modelName} または {provider, modelName, url}。内部的に NBAccess`NBSetFallbackModels に同期される。

### $ClaudeDocModel
型: {String, String} | String, 初期値: {"claudecode", "claude-sonnet-4-6"}
ドキュメント生成/更新時に使用するモデル。"" で $ClaudeModel と同じモデルを使用。

### $ClaudeDocRetryDelay
型: Numeric, 初期値: 60
ドキュメント生成のリトライ待機秒数。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
ドキュメント生成の最大リトライ回数。

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースコードの最大文字数。

### $ClaudeDocUpdateStaleSeconds
型: Numeric, 初期値: 1800
ドキュメント更新チェーン多重起動ガードのタイムスタンプ有効期限 (秒)。この時間を超えると stale とみなしロックを自動解放する。

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval が再帰的に ClaudeEval を生成する際の最大深度。0 で再帰禁止。大きくすると多段階自動タスク連鎖が可能。

### $ClaudeEvalMode
型: String | Automatic, 初期値: Automatic
ClaudeEval の評価モード。

### $ClaudeEvalHook
型: Function | None, 初期値: None
ClaudeEval 実行前に呼ばれるフック関数。

### $ClaudeEvalAutoThreshold
型: Integer
ClaudeEval の自動評価閾値 (文字数)。

### $ClaudeEvalVerbose
型: Boolean, 初期値: False
ClaudeEval の詳細ログ出力フラグ。

### $ClaudeEvalAutoLLMMinLength
型: Integer
自然言語自動 LLM 判定の最小テキスト長。

### $ClaudeEvalAutoLLMMinNewlines
型: Integer
自然言語自動 LLM 判定の最小改行数。

### $ClaudeEvalNaturalDispatch
型: Boolean
自然言語ディスパッチ有効化フラグ。

### $ClaudeEvalNaturalVerbose
型: Boolean
自然言語ディスパッチの詳細ログフラグ。

### $ClaudeEvalNotebookContext
型: Boolean | Automatic
ClaudeEval でノートブックコンテキストを含めるか。

### $ClaudeEvalLastProposedExprString
型: String
最後に提案されたコード文字列。デバッグ用。

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
外部パッケージがキーワードを登録する Association。プロンプトにキーワードが含まれると対応パッケージの api.md がコンテキストに自動注入される。claudecode.wl 自体はパッケージ非依存。各パッケージが自身のロード時に登録する。
例: $ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "受信"}

### $ClaudePackageAuxKeywordMap
型: Association, 初期値: <||>
補助 api_<aux>.md の注入条件を登録する Association。形式: <|pkg -> <|aux -> {キーワード...}|>|>。キーワードが task に含まれると aux の api_<aux>.md が注入される。未登録の補助 api は従来通り常に注入される (後方互換)。
例: $ClaudePackageAuxKeywordMap["SourceVault"] = <|"eagle" -> {"Eagle", "Exif"}|>

### $ClaudePaletteServiceControls
型: {Association...}, 初期値: {}
ShowClaudePalette の Privacy セクション直下に表示される start/stop サービストグルのレジストリ。外部パッケージが ClaudeRegisterPaletteServiceControl で登録する。claudecode.wl 自体はパッケージ中立。

### $LLMGraphMaxConcurrency
型: Integer
LLM グラフの最大並行実行数。

### $LLMGraphAutoStopThreshold
型: Integer
LLM グラフの自動停止閾値 (エラー数)。

### $ClaudeRoutingProviders
型: {String...}
ルーティング対象プロバイダリスト。

### $UseClaudeRuntime
型: Boolean, 初期値: False
ClaudeRuntime 経由での評価を有効にするフラグ。

### $ClaudeLastRuntimeId
型: String | None
最後に使用したランタイム ID。

### $ClaudeRuntimeAsyncExecution
型: Boolean
ランタイムの非同期実行 (ParallelSubmit) 有効化フラグ (Phase 32)。

### $ClaudeRuntimeAsyncForce
型: Boolean
非同期実行を強制するフラグ。

### $ClaudeRuntimeAsyncSuppressInputEval
型: Boolean
非同期実行時の入力評価抑制フラグ。

### $claudecodeVersion
型: String
パッケージのバージョン文字列。

### $ClaudeEditModesVersion
型: String
編集モードモジュール (claudecode_editmodes.wl) のバージョン文字列。

### $ClaudeEditModeAppendTagOpen
型: String
追記モードの開始タグ文字列。

### $ClaudeEditModeAppendTagClose
型: String
追記モードの終了タグ文字列。

### $ClaudeEditModeInsertTagClose
型: String
挿入モードの終了タグ文字列。

## ChatGPT Codex 統合

### $ChatgptCodexExe
型: String
ChatGPT Codex CLI の実行ファイルパス。

### $ChatgptWorkingDirectory
型: String
ChatGPT Codex CLI の作業ディレクトリ ($OpenaiWorkingDirectory と同値)。

### $ChatgptAccessibleDirs
型: {String...}
ChatGPT Codex CLI に許可する追加ディレクトリリスト。

### $ChatgptCodexHomeDirectory
型: String
ChatGPT Codex CLI のホームディレクトリ。

### $ChatgptCodexPermissionProfile
型: String
Codex の権限プロファイル名。

### $ChatgptCodexApprovalPolicy
型: String
Codex の承認ポリシー ("auto" | "confirm" 等)。

### $ChatgptCodexModel
型: String | Automatic, 初期値: Automatic
Codex CLI が使用するモデル名。Automatic で CLI 既定モデルを使用。パレットで "chatgptcodex" プロバイダ選択時に $iPaletteModelName と同期される。

### $ChatgptCodexHarnessMode
型: String
Codex CLI ハーネスモード。

### $ChatgptCodexRetainTempProjects
型: Boolean
一時プロジェクトを保持するか。

### $ChatgptCodexSourceExposureMode
型: String
ソースコードの Codex への公開モード。

### $ClaudeCLIHarnessMode
型: String
Claude CLI ハーネスモード (Phase 4)。

## オプション

### Fallback
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: Claude Code 利用不可時に $ClaudeFallbackModels の優先順でフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。False (デフォルト): エラーをそのまま返す。

### AutoPrivate
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: 機密変数にアクセスするタスクの場合、生成コードに Model -> $ClaudePrivateModel, PrivacySpec -> Automatic を付与する。False (デフォルト): 通常動作。

### AutoEvaluate
ClaudeEval のオプション。True (デフォルト): 生成コードを自動評価する。False: コードセルを生成するが評価しない。

### AutoCellize
ClaudeQuery/ClaudeEval のオプション。True: レスポンスを自動的にセル化する。False (デフォルト): 通常出力。

### Integrations
ClaudeQuery/ClaudeQueryAsync のオプション。lmstudio モデル使用時のみ有効。LM Studio /api/v1/chat の MCP サーバ/プラグインリストを指定する。Automatic (デフォルト): $ClaudeLMStudioIntegrations → SourceVault の順で解決。明示リストを渡すと最優先される。
例: Integrations -> {"mcp/exa"}

### OutputMode
ClaudeQuery/ClaudeEval のオプション。出力形式を指定する。Automatic (デフォルト): コンテキストに応じて自動選択。

### PrivacySpec
ClaudeQuery/ClaudeEval のオプション。Automatic (デフォルト): 機密変数検出時に自動処理。

### RepeatInterval
一部クエリ関数のオプション。定期繰り返し実行の間隔秒数を指定する。

### Model
ClaudeQuery/ClaudeEval/ClaudeCreateDocumentation 等のオプション。このクエリのみに使用するモデル/プロバイダ tuple を指定する。グローバル $ClaudeModel を上書きする。

### WebSearch
ClaudeQuery/ClaudeEval のオプション。True: CLI の WebSearch ツール許可フラグを付与する。False (デフォルト)。

### WebFetch
ClaudeQuery/ClaudeEval のオプション。True: CLI の WebFetch ツール許可フラグを付与する。False (デフォルト)。

### Timeout
ClaudeQuery/ClaudeEval/ClaudeBuildRuntimeAdapter 等のオプション。タイムアウト秒数。デフォルト $ClaudeTimeout。

### DryRun
ClaudeAddDirective/ClaudePrepareCommit 等のオプション。True: 実際の変更を行わずに結果をプレビューする。False (デフォルト)。

### Mode
ClaudeReview/ClaudeUpdatePackageWithMode 等のオプション。動作モードを指定する文字列。

### TargetFiles
ClaudeReview のオプション。レビュー対象ファイルのリスト。Automatic (デフォルト): 現在のノートブック。

### TargetFunctions
ClaudeReview のオプション。レビュー対象関数のリスト。All (デフォルト): 全関数。

### Inherit
CreateClaudeSession のオプション。継承元セッション名。None (デフォルト)。

### References
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。README.md に追加する参考文献 (URL または書籍名) のリスト。
例: References -> {"https://...", "書籍名"}

### Demos
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。README.md に反映するデモ動画/使用例 URL のリスト。
例: Demos -> {"https://youtu.be/..."}

### Disclaimer
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。README.md の免責事項セクションに追加する文言リスト。

### License
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。"" (デフォルト): GitHubREST`$GitHubLicenseHolder が非空なら MIT ライセンスを自動挿入。文字列指定: そのままライセンステキストとして挿入。
例: License -> "MIT"

### Acknowledgments
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。README.md の謝辞セクションに追加する文言リスト。免責事項の前に配置される。

### Keywords
ClaudeAttach のオプション。添付ファイルの検索キーワードリスト。

### Title
ClaudeAttach のオプション。添付ファイルのタイトル。Automatic (デフォルト): URL またはファイル名から自動生成。

### Refetch
ClaudeAttach のオプション。True: キャッシュを無視して URL を再取得する。False (デフォルト)。

### Owner
ClaudePrepareCommit のオプション。GitHub リポジトリオーナー名。

### Repository
ClaudePrepareCommit のオプション。GitHub リポジトリ名。

### Branch
ClaudePrepareCommit のオプション。対象ブランチ名。

### BaseBranch
ClaudePrepareCommit のオプション。比較基準ブランチ名。デフォルト "main"。

### Baseline
ClaudePrepareCommit のオプション。差分比較のベースラインコミット。

### StartTime
一部クエリ関数のオプション。処理開始タイムスタンプを指定する。