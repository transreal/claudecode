# claudecode API Reference

claudecode パッケージは Wolfram Language から Claude Code CLI / Anthropic API / OpenAI API / LM Studio / ChatGPT Codex CLI を統合し、ノートブック上で LLM クエリ・コード生成・評価・ドキュメント生成・マルチステップ DAG を実行する。依存: [NBAccess](https://github.com/transreal/NBAccess), [GitHubREST](https://github.com/transreal/github)。

## グローバル変数

### $ClaudeModel
型: {String, String}, 初期値: {"claudecode", ""}
LLM プロバイダとモデルを指定するタプル {provider, modelName}。provider は "claudecode"（Claude Code CLI・Pro/Max サブスク内・課金なし）, "anthropic"（Anthropic API 直接・課金あり）, "openai"（OpenAI API・課金あり）, "lmstudio"（ローカル・課金なし）, "chatgptcodex"（ChatGPT Codex CLI）のいずれか。modelName は "" で各 CLI のデフォルトモデルを使用。
例: $ClaudeModel = {"claudecode", "claude-opus-4-8"}

### $ClaudeAdvisaryModel
型: {String, String} または String, 初期値: {"chatgptcodex", "Automatic"}
仕様レビュー合意ワークフローにおける Codex アドバイザリーロールのモデル指定。$ClaudeModel と同形式。Automatic は Codex CLI デフォルトモデルを使用。
例: $ClaudeAdvisaryModel = {"chatgptcodex", "gpt-5.5"}

### $ClaudeTimeout
型: Integer, 初期値: 1200
ClaudeQuery・ClaudeEval 等のタイムアウト秒数。

### $ClaudeVerbose
型: Boolean, 初期値: False
True のとき履歴コンパクション等の詳細ログを Messages に出力する。

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code CLI の起動作業ディレクトリ。配下の .claude/CLAUDE.md, rules/, skills/ を Claude Code に読み込ませる。

### $OpenaiWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "OpenAI Working"}]
OpenAI 系 CLI (Codex 含む) の作業ディレクトリ。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。$packageDirectory 以外のディレクトリは初回使用時にダイアログで確認しノートブックの TaggingRules に永続化する。NBSetAccessibleDirs でも永続化可能。
例: $ClaudeAccessibleDirs = {$packageDirectory, "C:\\Users\\...\\作業フォルダ"}

### $ClaudeFallbackModels
型: List, 初期値: {{"chatgptcodex","gpt-5.5"},{"anthropic","claude-opus-4-8"},{"openai","gpt-5.5"}}
フォールバックモデル優先順位。各要素は {provider, modelName} または {provider, modelName, url}。NBAccess`NBSetFallbackModels に自動同期される。

### $ClaudePrivateModel
型: List, 初期値: なし
秘密データ処理用ローカルモデル指定。AutoPrivate -> True 時に使用。
例: $ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索されるか手動で上書きできる。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。空の場合は CLAUDE.md が見つからなかったか内容がない。

### $ClaudeSnapshots
型: String, 初期値: FileNameJoin[{$ClaudeWorkingDirectory, "snapshots"}]
LLMGraphDAG スナップショットの保存ディレクトリ。

### $ClaudeDocModel
型: {String, String} または String, 初期値: {"claudecode", "claude-sonnet-4-6"}
ドキュメント生成・更新時に使用するモデル。"" で $ClaudeModel と同じモデルを使用。ユーザーが未カスタマイズなら最新 Sonnet に自動更新される。

### $ClaudeDocRetryDelay
型: Number, 初期値: 60
ドキュメント生成のリトライ待機秒数。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
ドキュメント生成の最大リトライ回数。

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースコードの最大文字数。

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval が再帰的に ClaudeEval/ContinueEval を生成する際の最大深度。0 で再帰禁止。大きくすると多段階タスク連鎖が可能。

### $ClaudeEvalMode
型: Symbol
ClaudeEval の動作モード。

### $ClaudeEvalHook
型: Function
ClaudeEval 実行時に呼び出されるフック関数。

### $ClaudeEvalAutoThreshold
型: Integer
ClaudeEval の自動実行文字数閾値。

### $ClaudeEvalAutoLLMMinLength
型: Integer
自然言語ディスパッチの最小文字数。

### $ClaudeEvalAutoLLMMinNewlines
型: Integer
自然言語ディスパッチの最小改行数。

### $ClaudeEvalNaturalDispatch
型: Boolean, 初期値: False
True のとき自然言語入力を自動で ClaudeQuery にディスパッチする。

### $ClaudeEvalNaturalVerbose
型: Boolean
自然言語ディスパッチの詳細出力フラグ。

### $ClaudeEvalVerbose
型: Boolean
ClaudeEval の詳細出力フラグ。

### $ClaudeEvalNotebookContext
型: Boolean
ClaudeEval でノートブックコンテキストを送信するか。

### $ClaudeEvalLastProposedExprString
型: String
ClaudeEval が最後に提案した式の文字列。

### $claudecodeVersion
型: String
パッケージバージョン文字列。

### $ClaudeTestModel
型: String または {String, String}, 初期値: $ClaudeModel
分離検証 (ClaudeCheckSeparation) で使用するモデル。

### $ClaudeStandardFont
型: String, 初期値: "Yu Gothic UI"
ClaudeEval が生成する出力コード (Grid/Column/Style/Button 等) で統一的に使用するフォント名。プロンプトに埋め込まれ FontFamily 指定を強制する。ロード後に任意フォント名に変更可能。

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
外部パッケージがキーワードを登録する Association。プロンプトにキーワードが含まれると対応パッケージの api.md がコンテキストに自動注入される。各パッケージが自身のロード時に登録する。claudecode.wl 側はパッケージ非依存。
例: $ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒切"}

### $ClaudePackageAuxKeywordMap
型: Association, 初期値: <||>
補助 api_<aux>.md の注入条件を登録する Association。形式: <|pkg -> <|aux -> {キーワード...}|>|>。キーワードがタスクに含まれる場合のみ対応 aux の api_<aux>.md を注入する。未登録の補助 api は従来通り常に注入される。
例: $ClaudePackageAuxKeywordMap["SourceVault"] = <|"eagle" -> {"Eagle", "Exif"}|>

### $ClaudePaletteServiceControls
型: List, 初期値: {}
ShowClaudePalette の Privacy セクション下に表示する開始/停止トグルのレジストリ。各要素は Association で "Id", "RunningQ" (0引数 Function → True|False|Missing), "Start", "Stop", "RunningLabel", "StoppedLabel", "UnknownLabel" キーを持つ。オプションで "RunningColor", "StoppedColor"。各 *Label は String または 0引数 Function (レンダリング時評価)。

### $UseClaudeRuntime
型: Boolean, 初期値: False
True のとき ClaudeEval は ClaudeRuntime 経由でコードを実行する。

### $ClaudeLastRuntimeId
型: String
最後に使用した ClaudeRuntime の ID。

### $ClaudeRuntimeAsyncExecution
型: Boolean
ClaudeRuntime でのコード実行を非同期 (ParallelSubmit) で行うか。

### $ClaudeRuntimeAsyncForce
型: Boolean
非同期実行を強制するフラグ。

### $ClaudeRuntimeAsyncSuppressInputEval
型: Boolean
非同期実行時に入力セルの評価を抑制するフラグ。

### $ClaudeRoutingProviders
型: List
ルーティング対象プロバイダリスト。

### $LLMGraphMaxConcurrency
型: Integer
LLMGraph の最大並列実行数。

### $LLMGraphAutoStopThreshold
型: Integer
LLMGraph の自動停止閾値。

### $ClaudeEditModesVersion
型: String
EditModes モジュールのバージョン。

### $ClaudeEditModeAppendTagOpen
型: String
Append 編集モードの開始タグ。

### $ClaudeEditModeAppendTagClose
型: String
Append 編集モードの終了タグ。

### $ClaudeEditModeInsertTagClose
型: String
Insert 編集モードの終了タグ。

### $ChatgptCodexExe
型: String
ChatGPT Codex CLI 実行ファイルのパス。

### $ChatgptWorkingDirectory
型: String
ChatGPT Codex CLI の作業ディレクトリ。

### $ChatgptAccessibleDirs
型: List
ChatGPT Codex CLI に許可するディレクトリリスト。

### $ChatgptCodexHomeDirectory
型: String
Codex CLI のホームディレクトリ。

### $ChatgptCodexPermissionProfile
型: String
Codex CLI のパーミッションプロファイル。

### $ChatgptCodexApprovalPolicy
型: String
Codex CLI の承認ポリシー。

### $ChatgptCodexModel
型: String または Symbol, 初期値: Automatic
Codex CLI のモデル指定。Automatic で CLI デフォルトモデルを使用。$iPaletteProvider が "chatgptcodex" のときパレットから同期される。

### $ChatgptCodexHarnessMode
型: String
Codex CLI ハーネスモード。

### $ChatgptCodexRetainTempProjects
型: Boolean
Codex CLI の一時プロジェクトを保持するか。

### $ChatgptCodexSourceExposureMode
型: String
Codex CLI へのソースコード公開モード。

### $ClaudeCLIHarnessMode
型: String
Claude CLI ハーネスモード。

## クエリ関数

### ClaudeQuery[prompt]
ノートブックのセル内容を LLM に問い合わせ、返答をノートブックセルに書き込む。
→ Null (セル出力)
Options: Model -> $ClaudeModel, Timeout -> $ClaudeTimeout, Fallback -> False, AutoPrivate -> False, WebSearch -> Automatic, WebFetch -> Automatic, PrivacySpec -> Automatic, NonBlocking -> False, Integrations -> Automatic, OutputMode -> Automatic

### ClaudeQuerySync[prompt]
ClaudeQuery の同期版。結果を String として返す。
→ String

### ClaudeQueryBg[prompt]
バックグラウンドで LLM クエリを実行する。マルチモーダル (画像付き) 対応。provider が "claudecode" の場合は CLI にリダイレクト。
→ 結果 String または ScheduledTask
Options: Model -> $ClaudeModel, Timeout -> $ClaudeTimeout, NonBlocking -> False, Fallback -> False, WebSearch -> Automatic, WebFetch -> Automatic
例: ClaudeQueryBg[{prompt, img}, NonBlocking -> True, Timeout -> 120]

### ClaudeQueryAsync[prompt]
非同期で LLM クエリを実行する。
→ ScheduledTask オブジェクト

### ClaudeQueryAsyncSilent[prompt]
非同期クエリ (ノートブック出力なし)。

### ClaudeEnsureSilentNotebook[] → NotebookObject
サイレントノートブックを確保する。バックグラウンド出力先として使用。

### ClaudeWriteResponse[text] → Null
LLM 応答テキストをノートブックセルに書き込む。

### ClaudeMath[prompt]
数式計算特化クエリ。Mathematica コードの提案を返す。
→ String

### ClaudeExtractCode[response] → String
LLM 応答から最初のコードブロックを抽出する。

### ClaudeExtractAllCode[response] → List
LLM 応答からすべてのコードブロックを抽出する。

### ClaudeEval[task]
自然言語タスクを LLM に渡し、生成されたコードをノートブックで評価する。有料プロバイダ使用時は NBAccess 許可を事前確認する。
→ 評価結果 (任意の式)
Options: Model -> $ClaudeModel, Timeout -> $ClaudeTimeout, AutoPrivate -> False, AutoEvaluate -> True, AutoCellize -> True, Fallback -> False, WebSearch -> Automatic, WebFetch -> Automatic, PrivacySpec -> Automatic, OutputMode -> Automatic

### ContinueEval[task]
前回の ClaudeEval セッションに続けてタスクを実行する。
→ 評価結果

### ContinueUpdate[task]
既存コードを更新する形でタスクを続行する。
→ 評価結果

## 仕様生成

### ClaudeSpec["task"] → String
ノートブック内容からプログラムの仕様を生成する。パレットからはセル選択で呼び出し可能。

### ClaudeSpec[{"task", image, ...}] → String
画像付きで仕様を生成する。

### ClaudeSpecStatus[]
現在のノートブックプロジェクト (TaggingRule SourceVaultSpecProjectId) の仕様/合意下書き状態を表示する。プロジェクトがない場合は実行中バックグラウンド合意ジョブを一覧表示。SourceVault のみ使用 (ワークフローエンジン不要)。
→ セル出力

### ClaudeSpecStatus["project"]
指定プロジェクトの仕様バージョン数・最新評決・最新 sv:// URI・最終更新時刻・バックグラウンドジョブ稼働状況を報告する。
→ Association

### ClaudeSpecVersions[]
現在のノートブックプロジェクトのすべての仕様・レビューバージョンを Dataset で返す。
→ Dataset (カラム: Role, Round, Verdict, Seq, CreatedAtUTC, URI)

### ClaudeSpecVersions["project"]
指定プロジェクトのバージョン一覧を返す。SourceVault ポインタチェーン orch/<project>/spec と orch/<project>/review を参照。
→ Dataset

### ClaudeSpecVersions["project", role]
role は "spec", "review", "requirements" のいずれかで絞り込む。
→ Dataset

### ClaudeSpecText[uri] → String
sv:// URI (ClaudeSpecVersions の URI カラム) から仕様・レビュー・要件のテキストを返す。sv://snapshot/Class/hex と sv://snapshot/Class:hex の両形式および生の snapshot:Class:hex ref に対応。

### ClaudeOpenSourceVaultURI[uri] → NotebookObject または $Failed
sv:// スナップショット URI を解決し、内容 (メタデータグリッド + Text 本文、レビューは Findings も含む) を新規ノートブックウィンドウで開く。仕様/合意フローが書き込む sv:// リンクのクリックアクション。

### CreateImplementationWorkflow[name, approvedSpec]
承認済み設計仕様を SourceVault_workflows/<name>/ 下の SVWorkflow_<Name> パッケージとして実装する。実装者 ($ClaudeModel) がパッケージを書き、検証者 ($ClaudeAdvisaryModel) が仕様対比チェックを行い合意まで繰り返す。進行状況は WindowStatusArea に表示。完了時に起動関数を登録しサマリをノートブックに書き込む。approvedSpec は sv:// URI・スナップショット ref・生テキストのいずれかを受け付ける。
→ バックグラウンドジョブ ID
Options: "Notes" -> "", "ClaudeModel" -> $ClaudeModel, "AdvisaryModel" -> $ClaudeAdvisaryModel, "MaxRounds" -> 5, "Nb" -> Automatic, "Launch" -> False

### LaunchImplementationWorkflow[name, args] → Association
CreateImplementationWorkflow で生成した codified ワークフローをロードして起動する。
Association キー: "LaunchContext", "Entry", "Result"

## デバッグ・レビュー

### ClaudeDebug[expr]
式をデバッグする。LLM によるエラー解析と修正提案を返す。

### ClaudeReview[code]
コードをレビューする。LLM によるレビューコメントを返す。

### ClaudeReviewChunked[code]
大きなコードをチャンク分割してレビューする。

## セッション管理

### CreateClaudeSession[name]
新しい Claude セッションを作成する。
→ String (セッション ID)
Options: Inherit -> None (継承元セッション名)

### ClaudeRestoreSession[name]
保存済みセッションを復元する。

### ClaudeListSessions[] → Dataset
利用可能なセッション一覧を返す。

### ClaudeDeleteSession[name]
セッションを削除する。

### ClaudeShowHistory[]
現在のセッション会話履歴を表示する。

### ClaudeSessionStatus[] → Association
現在のセッション状態を返す。

### ClaudeCompactHistory[]
会話履歴を圧縮する。

### ClaudeHistorySize[] → Integer
現在の履歴サイズ (トークン数概算) を返す。

### ClaudeQueryShowContext[]
現在クエリに送信されるコンテキスト内容を表示する。

### ClaudeShowAccessConfig[]
現在のアクセス設定 (許可ディレクトリ等) を表示する。

### ClaudeStatus[] → Association
Claude Code CLI の状態を確認する。

### ClaudeAbort[]
実行中の ClaudeQuery/ClaudeEval を中断する。

## レート制限

### ClaudeRateLimitStatus[] → Association
現在のレート制限状態を返す。

### ClaudeRateLimitClear[]
レート制限状態をクリアする。

## アタッチメント

### ClaudeAttach[keyword, content]
キーワードでコンテンツをアタッチする。URL の場合は自動キャッシュ。
Options: Keywords -> Automatic, Title -> Automatic, Refetch -> False

### ClaudeDetach[keyword]
指定キーワードのアタッチメントを削除する。

### ClaudeAttachments[] → Dataset
現在のアタッチメント一覧を返す。

### ClearAttachments[]
すべてのアタッチメントを削除する。

## Web 検索・取得

### ClaudeWebSearch[query] → String
LLM 経由で Web 検索を実行する。

### ClaudeWebFetch[url] → String
指定 URL のコンテンツを取得する。

### WebSearch[query]
ClaudeWebSearch の別名。

### WebFetch[url]
ClaudeWebFetch の別名。

## 機密データ管理

### MarkConfidential[expr]
式を機密としてマークする。LLM に送信しない。
→ 機密ラップされた式

### UnmarkConfidential[expr]
機密マークを解除する。

### IsConfidential[expr] → Boolean
式が機密マークされているか確認する。

### Confidential
機密セルのスタイルマーカー。

### NonConfidential
非機密セルのスタイルマーカー。

### ScanConfidentialCells[] → List
ノートブック内の機密セルをスキャンして一覧を返す。

## ドキュメント生成

ClaudePackageManager.wl に実装が移管済み。claudecode 経由でも alias として呼び出し可能。

### ClaudeCreateDocumentation["pkgName"]
パッケージの包括的ドキュメント一式を生成する。リミット到達時に自動停止し、再実行で未生成分のみ続行する。README.md は最後に生成される。
Options: References -> {}, Demos -> {}, Disclaimer -> {}, License -> "", Acknowledgments -> {}, Model -> $ClaudeDocModel, DryRun -> False

### ClaudeUpdateDocumentation["pkgName", "更新指示"]
既存ドキュメントを部分更新する。
Options: References -> {}, Demos -> {}, Disclaimer -> {}, License -> "", Acknowledgments -> {}, Model -> $ClaudeDocModel

## ディレクティブ管理

### ClaudeAddDirective["name", content]
CLAUDE.md にディレクティブを追加する。

### ClaudeRestoreDirective["name"]
ディレクティブを復元する。

### ClaudeListDirectives[] → Dataset
現在のディレクティブ一覧を返す。

### ClaudeUpdateDirective["name", content]
既存ディレクティブを更新する。

### ClaudeDirectiveBackupDataset[] → Dataset
ディレクティブのバックアップ Dataset を返す。

### ClaudeSyncDirectives[]
ディレクティブを同期する。

## パッケージ操作 (ClaudePackageManager.wl 経由)

以下は [ClaudePackageManager](https://github.com/transreal/ClaudePackageManager) に実装があり claudecode から alias で呼び出せる。

### ClaudeUpdatePackage["pkgName", "更新指示"]
パッケージを修正・機能追加・バグ修正する。バックアップ・差分更新・検証・再ロードを自動実行。直接 Import/Export でソースを書き換えてはならない。

### ClaudeCreatePackage["pkgName", "仕様"]
新しいパッケージを作成する。

### ClaudeConvertToPaclet["pkgName"]
パッケージを Paclet 形式に変換する。

### ClaudeUpdatePackageWithMode["pkgName", "更新指示"]
EditMode 対応の差分更新を行う。

### ClaudeBackupDataset["pkgName"] → Dataset
バックアップ Dataset を取得する。

### ClaudeRestorePackage["pkgName", timestamp]
バックアップから復元する。

### ClaudeUpdatePackageHistory["pkgName"]
更新履歴を確認する。

### ClaudeGenerateDocumentation["pkgName"]
包括的ドキュメント一式を生成する (ClaudeCreateDocumentation の alias)。

### ClaudeUpdateDocumentation["pkgName", "更新指示"]
既存ドキュメントを部分更新する。

### ClaudeCommand["command"]
Claude Code CLI のスラッシュコマンドを実行する。
例: ClaudeCommand["/help"]

## 分離検証

### ClaudeCheckSeparation["pkgName"] → Association
NBAccess 分離原則を検証する。結果は $iSeparationCheckCache にキャッシュし ClaudeFixSeparation で再利用。$NBSeparationIgnoreList 登録パッケージ (NBAccess, NotebookExtensions) は対象外。

### ClaudeFixSeparation["pkgName"]
分離原則違反を自動修正する。ClaudeCheckSeparation のキャッシュ結果を使用。

## コミット準備

### ClaudePrepareCommit[] → String
変更サマリを収集し Git コミットメッセージを生成する。

## ファイル処理

### NBFileTranslate[spec]
ノートブックファイルを翻訳・変換する。
Options: TargetFiles -> {}, TargetFunctions -> {}, Mode -> Automatic, Model -> $ClaudeModel

### ClaudeProcessFile[path]
ファイルを LLM で処理する。
Options: Model -> $ClaudeModel, Mode -> Automatic

## NotebookLLMGraph

### NotebookLLMGraph[nb] → Association
指定ノートブックの LLM 依存グラフオブジェクトを返す。

### NotebookLLMGraphBuild[nb] → Association
ノートブックから LLM グラフを構築する。

### NotebookLLMGraphPlot[nb] → Graphics
LLM グラフを可視化する。

### NotebookLLMGraphNodes[nb] → List
グラフの全ノード一覧を返す。

### NotebookLLMGraphValidate[nb] → Association
グラフの整合性を検証する。

### NotebookLLMGraphFetchResponse[nb, nodeId]
指定ノードの LLM 応答を取得・更新する。

### NotebookLLMGraphSubSteps[nb, nodeId] → List
ノードのサブステップ一覧を返す。

### NotebookLLMGraphFetchL2[nb, nodeId]
L2 (詳細) 応答を取得する。

### NotebookLLMGraphErrors[nb] → List
グラフ内のエラーノード一覧を返す。

### NotebookLLMGraphUpdateL2Status[nb, nodeId, status]
L2 ノードのステータスを更新する。

### NotebookLLMGraphPlotL2[nb, nodeId] → Graphics
L2 グラフを可視化する。

### NotebookLLMGraphRerun[nb, nodeId]
指定ノードを再実行する。

### NotebookLLMGraphInvalidateDownstream[nb, nodeId]
指定ノードの下流を無効化する。

### NotebookLLMGraphSummary[nb] → Association
グラフサマリを返す。

### NotebookLLMGraphExtractThread[nb, nodeId]
スレッドを抽出する。

### NotebookLLMGraphApplyThread[nb, nodeId, thread]
スレッドを適用する。

## LLMGraphDAG

### LLMGraphExecute[graph] → String
LLM グラフを実行し実行 ID を返す。

### LLMGraphExecuteStatus[id] → Association
実行状態を返す。

### LLMGraphExecuteCancel[id]
実行をキャンセルする。

### LLMGraphDAGCreate[spec] → String
DAG を作成し DAG ID を返す。

### LLMGraphDAGStatus[id] → Association
DAG の実行状態を返す。

### LLMGraphDAGCancel[id]
DAG をキャンセルする。

### LLMGraphDAGStop[id]
DAG を停止する。

### LLMGraphDAGRetry[id]
失敗した DAG ノードをリトライする。

### LLMGraphDAGRebuild[id]
DAG を再構築する。

### LLMGraphDAGFindByContext[context] → String または $Failed
コンテキストから DAG を検索し DAG ID を返す。

### LLMGraphDAGInspect[id] → Association
DAG の詳細を検査する。

### LLMGraphDAGMarkFailed[id, nodeId]
ノードを失敗としてマークする。

### LLMGraphDAGSnapshot[id] → String
DAG のスナップショットを保存しスナップショット ID を返す。

### LLMGraphDAGRestore[snapshotId]
スナップショットから DAG を復元する。

### LLMGraphDAGListSnapshots[] → List
利用可能なスナップショット一覧を返す。

### LLMGraphDAGPlot[id] → Graphics
DAG を可視化する。

### LLMGraphDAGMergeHistory[id1, id2]
2 つの DAG の履歴をマージする。

## ClaudeRuntime

### ClaudeBuildRuntimeAdapter[opts] → Association
コード実行用 RuntimeAdapter を構築する。adapter["DefaultTimeoutSeconds"] にタイムアウトを保持。
Options: "ExecutionTimeoutSeconds" -> 30

### ClaudeStartRuntime[adapter] → String
ランタイムを起動し ID を返す。

### ClaudeEvalViaRuntime[adapter, expr]
RuntimeAdapter 経由で式を評価する。タイムアウト優先順: proposal["ExpectedSeconds"] > adapter["DefaultTimeoutSeconds"] > 30。
→ 評価結果

### ClaudeApproveProposal[adapter, proposal]
ランタイムに提案された実行を承認する。

### ClaudeRuntimeSnapshot[id] → String
ランタイム状態のスナップショットを保存しスナップショット ID を返す。

### ClaudeRuntimeRestore[snapshotId]
ランタイムをスナップショットから復元する。

### ClaudeRuntimeListSnapshots[] → List
ランタイムスナップショット一覧を返す。

### ClaudeRegisterDAGRuntime[dagId, runtimeId]
DAG にランタイムを登録する。

## 編集モード

### ClaudeAppendBlockToPackage["pkgName", block] → True または $Failed
パッケージにブロックを追記する (AppendMode)。

### ClaudeInsertBeforeAnchorInPackage["pkgName", anchor, block] → True または $Failed
アンカーの直前にブロックを挿入する (InsertMode)。

### ClaudeParseEditModeResponse[response] → List
LLM 応答から EditMode 形式のパッチを解析する。

### ClaudeAutoDetectEditMode[response] → "append" | "insert" | "replace" | None
LLM 応答から EditMode を自動判別する。

### ClaudeBuildEditModePromptInstructions[mode] → String
EditMode 用プロンプト指示文を生成する。

## パレット・UI

### ShowClaudePalette[]
Claude Code パレットを表示する。モデル選択 (Provider + Model の 2 ボタン)、プライバシー設定、サービス制御 ($ClaudePaletteServiceControls のトグル) を提供する。

### ClaudeRegisterPaletteServiceControl[spec] → String
ShowClaudePalette の Privacy セクション下に開始/停止トグルを登録する。spec は Association で "Id", "RunningQ" (0引数 Function → True|False|Missing), "Start", "Stop", "RunningLabel", "StoppedLabel", "UnknownLabel" キーを持つ。オプションで "RunningColor", "StoppedColor"。同一 Id は置換。登録後 ShowClaudePalette[] を再実行して反映する。

### ClaudeUnregisterPaletteServiceControl[id]
パレットサービストグルを削除する。

## ポーリング・優先度制御

### ClaudeRegisterPollingTick[key, func]
ポーリングティックにコールバック関数を登録する。

### ClaudeUnregisterPollingTick[key]
ポーリングティックのコールバックを解除する。

### ClaudePollingTickKeys[] → List
登録済みポーリングキー一覧を返す。

### ClaudeEnqueueFinalAction[action]
セッション完了時に実行するアクションをエンキューする。

### ClaudeBeginHighPriority[]
高優先度モードを開始する。$ClaudePriorityModeUntil を設定。

### ClaudeEndHighPriority[]
高優先度モードを終了する。

### ClaudeBeginParallelKernels[]
並列カーネルを事前起動する。ParallelSubmit 実行前に呼び出す。

## オプションシンボル

### Model
使用する LLM を {provider, modelName} タプルまたは "" で指定。ClaudeQuery/ClaudeEval/ClaudeQueryBg 等で使用。

### Fallback
True のとき Claude Code 利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。デフォルト: False

### AutoPrivate
True のとき秘密変数にアクセスするタスクのコードに Model -> $ClaudePrivateModel と PrivacySpec -> Automatic を付与する。デフォルト: False

### AutoEvaluate
ClaudeEval で生成コードを自動実行するか。デフォルト: True

### AutoCellize
生成コードを自動でセル化するか。デフォルト: True

### Timeout
クエリのタイムアウト秒数。デフォルト: $ClaudeTimeout

### StartTime
タスク開始時刻 (AbsoluteTime 値)。

### NonBlocking
True のとき非同期クエリを実行しノートブックをブロックしない。デフォルト: False

### Integrations
lmstudio モデル時のみ有効。LM Studio /api/v1/chat の MCP サーバー/プラグインリストを指定。Automatic で $ClaudeLMStudioIntegrations → SourceVault の順で解決。明示リストを渡すと最優先される。デフォルト: Automatic
例: Integrations -> {"mcp/exa"}

### WebSearch
Web 検索ツールの使用可否。Automatic で内部フラグ ($iAllowWebSearch) を参照。

### WebFetch
Web 取得ツールの使用可否。

### PrivacySpec
プライバシー仕様。Automatic で NBAccess から解決。

### OutputMode
出力モード。

### RepeatInterval
繰り返し実行の間隔秒数。

### Keywords
アタッチメントのキーワードリスト。

### Title
アタッチメントのタイトル。

### Refetch
True のとき URL キャッシュを無視して再取得する。デフォルト: False

### DryRun
True のとき実際の変更を行わず内容だけ確認する。デフォルト: False

### Inherit
セッション継承元の名前。CreateClaudeSession で使用。

### Owner
GitHub リポジトリオーナー名。

### Repository
GitHub リポジトリ名。

### Branch
Git ブランチ名。

### BaseBranch
プルリクエストのベースブランチ。

### Baseline
比較基準となるリビジョン。

### References
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。URL や書籍名のリストを指定すると README.md に参考文献セクションを追加する。
例: References -> {"https://...", "書籍名"}

### Demos
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。デモ動画・使用例の URL リストを README.md に反映する。
例: Demos -> {"https://youtu.be/...", "https://example.com/demo.nb"}

### Disclaimer
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。免責事項セクションに追加する文言のリスト。
例: Disclaimer -> {"本ツールは研究目的専用です"}

### License
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。"" (デフォルト) では GitHubREST`$GitHubLicenseHolder が非空なら MIT ライセンスを自動挿入。文字列指定でそのままライセンステキストとして挿入。
例: License -> "MIT"

### Acknowledgments
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。謝辞セクションに追加する文言のリスト。指定時は README.md の免責事項の前に配置される。
例: Acknowledgments -> {"本研究は JSPS 科研費の助成を受けた"}

### TargetFiles
ファイル変換・処理対象のファイルリスト。NBFileTranslate 等で使用。

### TargetFunctions
処理対象の関数名リスト。

### Mode
処理モード。NBFileTranslate 等で使用。