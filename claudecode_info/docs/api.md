# claudecode API リファレンス

ClaudeCode` パッケージの公開シンボル一覧。Claude Code CLI / 各種 LLM プロバイダ経由でノートブック内から問い合わせ・コード生成・自動実行・パッケージ操作を行う。

provider 概念: `claudecode`=Anthropic CLI (Pro/Max サブスク内・課金なし), `chatgptcodex`=ChatGPT Codex CLI (サブスク内・課金なし), `anthropic`=Anthropic API直接 (課金), `openai`=OpenAI API (課金), `lmstudio`=ローカル LLM (課金なし)。`$ClaudeModel` は tuple `{provider, model}` 形式。

## 問い合わせ系

### ClaudeQuery[prompt, opts]
Claude に問い合わせ、応答を非同期にノートブックへ書き出す主関数。provider=="claudecode" は進捗付き非同期経路で実行。
→ 応答テキスト/タスクオブジェクト
Options: Fallback -> False, Model -> Automatic, AutoPrivate -> False, PrivacyLevel -> Automatic, Timeout -> Automatic, WebSearch, WebFetch

### ClaudeQuerySync[prompt, opts]
prompt を送り応答文字列を同期的に返す。WindowStatusArea に経過時間表示。セッション履歴・ノートブック書き込みは行わない軽量版。
→ String
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic
モデルルーティング: Model->Automatic かつ PrivacyLevel<0.5 で CLI、>0.5 で `$ClaudePrivateModel`、Model->{"provider","model"} で指定モデルを API 経由。
例: `ClaudeQuerySync["Hello"]`, `ClaudeQuerySync[prompt, Model -> {"anthropic","claude-sonnet-4-6"}]`

### ClaudeQueryBg[prompt, opts]
FrontEnd 操作・ScheduledTask 生成なしで同期問い合わせし応答文字列を返す。SocketListen ハンドラ・ScheduledTask コールバック等の非同期コンテキストから安全に呼べる (rule 95 準拠の URLRead 代替)。
→ String
Options: Fallback -> False, Model -> Automatic, Timeout -> Automatic, NonBlocking -> False
画像付きマルチモーダル可: `ClaudeQueryBg[{prompt, img}, NonBlocking -> True, Timeout -> ...]`。provider=="claudecode" では Image を tmp PNG に書き出し CLI に渡し OCR/vision 可能。

### ClaudeQueryAsync[prompt, callback, nb, opts]
非同期問い合わせ。完了時に callback[応答文字列] を呼ぶ。nb は出力先 NotebookObject。
→ タスクオブジェクト

### ClaudeQueryAsyncSilent[prompt, callback, opts]
ノートブック UI 出力を抑制した非同期問い合わせ。
→ タスクオブジェクト

### ClaudeEnsureSilentNotebook[] → NotebookObject
非表示の出力用ノートブックを確保して返す。

### ClaudeWriteResponse[nb, text, opts]
マークダウン形式テキストをノートブックのセルとして展開する。見出し・リスト・コードブロック等を適切なセルスタイルに変換。
→ Null
Options: AutoEvaluate -> False (Trueで生成コードセルを自動評価)
例: `ClaudeWriteResponse[EvaluationNotebook[], response, AutoEvaluate -> True]`

### ClaudeMath[prompt, opts]
数式・数学タスク向けの問い合わせラッパー。
→ 応答

### ClaudeExtractCode[text] → String
応答テキストから最初のコードブロックを抽出する。

### ClaudeExtractAllCode[text] → List
応答テキストから全コードブロックを抽出する。

### ClaudeQueryShowContext[prompt] / ClaudeQueryShowContext[]
問い合わせ時に Claude へ渡すコンテキスト (CLAUDE.md・ファイルアクセス情報等) を表示する。

## 評価・自動実行系

### ClaudeEval[prompt, opts]
自然言語タスクからコードを生成し評価する。秘密変数・ファイルアクセスを考慮。Paid プロバイダ ({anthropic|openai,...}) 指定時は NBAccess の課金許可をチェックし、禁止なら明示エラーで停止。
→ 評価結果
Options: Model -> Automatic, AutoPrivate -> False, PrivacySpec -> Automatic, Fallback -> False, Timeout -> Automatic, AutoEvaluate
例: `ClaudeEval["売上データを集計してグラフ化"]`, `ClaudeEval[prompt, AutoPrivate -> True]`

### ContinueEval[prompt, opts]
直前の ClaudeEval/会話文脈を継続して評価する。秘密変数の構造調査と連携。
→ 評価結果
Options: Model, AutoPrivate, PrivacySpec, Fallback, Timeout

### ContinueUpdate[prompt, opts]
継続文脈で既存出力を更新する。
→ 評価結果

### ClaudeSpec[task] / ClaudeSpec[{task, image, ...}]
ノートブック内容からプログラムの仕様を生成する。画像付き指定可。パレットからセル選択で呼び出し可能。
→ 仕様テキスト

### ClaudeDebug[prompt, opts]
コードのデバッグ支援問い合わせ。
→ 応答

### ClaudeReview[target, opts]
コードレビューを行う。
→ レビュー結果

### ClaudeReviewChunked[target, opts]
大きな対象を分割してレビューする。
→ レビュー結果

### $ClaudeEvalMode
型: String/Symbol
ClaudeEval の動作モード。

### $ClaudeEvalHook
型: Function/None
ClaudeEval 実行時のフック。

### $ClaudeEvalAutoThreshold
型: Number
自動実行判定のしきい値。

### $ClaudeEvalVerbose
型: Bool
ClaudeEval の詳細ログ出力フラグ。

### $ClaudeEvalAutoLLMMinLength
型: Integer
LLM 自動ディスパッチを行う最小プロンプト文字数。

### $ClaudeEvalAutoLLMMinNewlines
型: Integer
LLM 自動ディスパッチを行う最小改行数。

### $ClaudeEvalNaturalDispatch
型: Bool
自然言語ディスパッチの有効化フラグ。

### $ClaudeEvalNaturalVerbose
型: Bool
自然言語ディスパッチの詳細ログフラグ。

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval が再帰的に ClaudeEval/ContinueEval を生成する連鎖の最大深度。0 で再帰禁止。

## セッション・履歴系

### CreateClaudeSession[opts] → セッションID
新しい Claude セッションを作成する。
Options: Inherit (既存セッションを継承)

### ClaudeRestoreSession[id, opts]
保存済みセッションを復元する。
Options: Inherit

### ClaudeListSessions[] → List
全セッション一覧を返す。

### ClaudeDeleteSession[id] → Null
セッションを削除する。

### ClaudeSessionStatus[] / ClaudeSessionStatus[id]
セッション状態を表示・返却する。

### ClaudeShowHistory[] / ClaudeShowHistory[id]
セッション履歴を表示する。

### ClaudeHistorySize[] → Integer
現在の履歴サイズを返す。

### ClaudeCompactHistory[opts]
履歴をコンパクション (要約圧縮) する。

### Inherit
型: Option symbol
CreateClaudeSession/ClaudeRestoreSession 等で既存文脈の継承を指定するオプション/シンボル。

## 添付・レート制限系

### ClaudeAttach[spec, opts]
ファイル・URL を会話に添付する。
Options: Keywords, Title, Refetch
例: `ClaudeAttach["https://example.com/doc.pdf", Keywords -> {"仕様"}]`

### ClaudeDetach[spec] → Null
添付を解除する。

### ClaudeAttachments[] → List
現在の添付一覧を返す。

### ClearAttachments[] → Null
全添付を削除する。

### ClaudeRateLimitStatus[] → Association
レート制限の状態を返す。

### ClaudeRateLimitClear[] → Null
レート制限状態をクリアする。

## 機密データ系

### MarkConfidential[var] / MarkConfidential[var, spec] → Null
変数を機密としてマークする。

### UnmarkConfidential[var] → Null
機密マークを解除する。

### IsConfidential[var] → Bool
機密かどうかを判定する。

### Confidential[expr] / NonConfidential[expr]
式を機密 / 非機密としてラップするヘッド。

### ScanConfidentialCells[] / ScanConfidentialCells[nb]
ノートブック内の機密セルを走査する。

## Web 系

### ClaudeWebSearch[query, opts]
Web 検索を実行する。
→ 検索結果

### ClaudeWebFetch[url, opts]
URL を取得する。
→ 取得内容

### WebFetch[url] / WebSearch[query]
ClaudeWebFetch / ClaudeWebSearch の短縮シンボル。

### WebFetch / WebSearch (option)
ClaudeQuery 等で Web 取得・検索ツールの有効化を指定するオプション。

## ドキュメント生成系

### ClaudeCreateDocumentation[packageName, opts]
パッケージの包括的ドキュメント一式を生成する。リミット到達時自動停止、再実行で未生成分のみ続行。README.md は最後に生成。
→ Null
Options: References, Demos, Disclaimer, License, Acknowledgments, Model

### ClaudeUpdateDocumentation[packageName, instruction, opts]
既存ドキュメントを部分更新する。
Options: References, Demos, Disclaimer, License, Acknowledgments, Model

### References (option)
URL や書籍名のリスト。README.md に参考文献セクションを追加。例: `References -> {"https://...", "書籍名"}`

### Demos (option)
デモ動画・使用例の URL リスト。README.md に反映。

### Disclaimer (option)
免責事項に追加する文言のリスト。

### License (option)
空文字列(デフォルト): GitHubREST`$GitHubLicenseHolder が非空なら MIT を自動挿入。文字列指定でそのまま挿入。例: `License -> "MIT"`

### Acknowledgments (option)
謝辞に追加する文言のリスト。

### $ClaudeDocRetryDelay
型: Number, 初期値: 60
ドキュメント生成のリトライ待機秒数。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
ドキュメント生成の最大リトライ回数。

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースの最大文字数。

### $ClaudeDocModel
型: tuple/String, 初期値: Sonnet 系最新 ({"claudecode","claude-sonnet-4-6"})
ドキュメント生成・更新に使うモデル。"" で `$ClaudeModel` と同じ。

## ディレクティブ系

### ClaudeAddDirective[type, content, opts]
rules/skills 等のディレクティブを追加する。

### ClaudeUpdateDirective[name, instruction, opts]
既存ディレクティブを更新する。

### ClaudeRestoreDirective[name, opts]
ディレクティブを復元する。

### ClaudeListDirectives[] → List
ディレクティブ一覧を返す。

### ClaudeDirectiveBackupDataset[] → Dataset
ディレクティブのバックアップ履歴を返す。

### ClaudeSyncDirectives[opts]
ディレクティブを同期する。

## パッケージ操作系 (ClaudePackageManager.wl へ移管、alias 経由で呼出可)

### ClaudeUpdatePackage[packageName, instruction]
パッケージの修正・機能追加・バグ修正。バックアップ・差分更新・検証・再ロードを自動実行。手動 Import/Export 書き換えは禁止。
例: `ClaudeUpdatePackage["Maildb", "showMailsのデフォルト表示数を30に変更"]`

### ClaudeUpdatePackageWithMode[packageName, instruction, mode, opts]
編集モード (Append/Insert 等) を指定したパッケージ更新。
Options: Mode

### ClaudeCreatePackage[packageName, spec]
新規パッケージを作成する。

### ClaudeConvertToPaclet[packageName]
パッケージを Paclet に変換する。

### ClaudeUpdatePackageHistory[packageName] → Dataset
更新履歴を返す。

### ClaudeRestorePackage[packageName, opts]
パッケージをバックアップから復元する。

### ClaudeBackupDataset[] → Dataset
バックアップ履歴を返す。

### ClaudeMigrateBackupHistory[]
バックアップ履歴を移行する。

### ClaudeBuildTransactionAdapter[opts] → Association
トランザクションアダプタを構築する。

### ClaudeUpdatePackageViaRuntime[packageName, instruction, opts]
ランタイム経由でパッケージ更新を行う。

## 編集モード系

### ClaudeAppendBlockToPackage[packageName, block, opts]
パッケージ末尾にブロックを追記する。

### ClaudeInsertBeforeAnchorInPackage[packageName, anchor, block, opts]
アンカー直前にブロックを挿入する。

### ClaudeParseEditModeResponse[response] → Association
LLM の編集モード応答を解析する。

### ClaudeAutoDetectEditMode[response] → String
応答から編集モードを自動判定する。

### ClaudeBuildEditModePromptInstructions[mode] → String
編集モード用のプロンプト指示文を構築する。

### $ClaudeEditModesVersion
型: String
編集モード機能のバージョン。

### $ClaudeEditModeAppendTagOpen / $ClaudeEditModeAppendTagClose
型: String
追記ブロックの開始/終了タグ。

### $ClaudeEditModeInsertTagClose
型: String
挿入ブロックの終了タグ。

## NBAccess 分離原則・コミット系

### ClaudeCheckSeparation[packageName] → 結果
NBAccess 分離原則の違反を検証する。`$NBSeparationIgnoreList` 登録パッケージは対象外。

### ClaudeFixSeparation[packageName]
分離原則違反を修正する。

### ClaudePrepareCommit[opts]
変更概要を集約しコミットメッセージを整形・準備する。

## ファイル処理・CLI 系

### ClaudeCommand[slashCommand] → 結果
Claude Code CLI のスラッシュコマンドを実行する。例: `ClaudeCommand["/review"]`

### ClaudeStatus[] → Association
現在の状態を返す。

### ClaudeAbort[] → Null
進行中の処理を中断する。

### ClaudeShowAccessConfig[]
ファイルアクセス設定を表示する。

### NBFileTranslate[spec, opts]
ノートブックファイルの変換・翻訳を行う。

### ClaudeProcessFile[path, instruction, opts]
ファイルを処理する。

### ShowClaudePalette[] → NotebookObject
Claude 操作パレットを表示する。Provider ボタン (claudecode→chatgptcodex→anthropic→openai→lmstudio 循環) と Model ボタン (現プロバイダの候補列循環) を持つ。

### cleanOutput[text] → String
出力テキストを整形する。

### stripANSI[text] → String
ANSI エスケープシーケンスを除去する。

## NotebookLLMGraph 系

### NotebookLLMGraph[nb, opts] → グラフ
ノートブックから LLM 依存グラフを構築する。

### NotebookLLMGraphBuild[nb, opts]
グラフを構築 (内部)。

### NotebookLLMGraphPlot[graph, opts]
グラフを描画する。

### NotebookLLMGraphPlotL2[graph, opts]
L2 レベルでグラフを描画する。

### NotebookLLMGraphNodes[graph] → List
ノード一覧を返す。

### NotebookLLMGraphValidate[graph] → 結果
グラフを検証する。

### NotebookLLMGraphFetchResponse[node] → String
ノードの応答を取得する。

### NotebookLLMGraphFetchL2[node]
L2 ノードの応答を取得する。

### NotebookLLMGraphSubSteps[node] → List
サブステップを返す。

### NotebookLLMGraphErrors[graph] → List
グラフ内エラーを返す。

### NotebookLLMGraphUpdateL2Status[node, status]
L2 ノードの状態を更新する。

### NotebookLLMGraphRerun[graph, node, opts]
指定ノードを再実行する。

### NotebookLLMGraphInvalidateDownstream[graph, node]
下流ノードを無効化する。

### NotebookLLMGraphSummary[graph] → Association
グラフのサマリを返す。

### NotebookLLMGraphExtractThread[graph] → List
スレッドを抽出する。

### NotebookLLMGraphApplyThread[graph, thread]
スレッドを適用する。

## LLMGraph 実行系

### LLMGraphExecute[graph, opts]
グラフを実行する。
Options: RepeatInterval

### LLMGraphExecuteStatus[] → Association
実行状態を返す。

### LLMGraphExecuteCancel[] → Null
実行をキャンセルする。

### $LLMGraphMaxConcurrency
型: Integer
LLMGraph 実行の最大並列数。

### $LLMGraphAutoStopThreshold
型: Number
自動停止のしきい値。

## LLMGraphDAG 系

### LLMGraphDAGCreate[spec, opts] → DAGid
DAG ジョブを作成する。

### LLMGraphDAGStatus[id] → Association
DAG 状態を返す。

### LLMGraphDAGInspect[id] → Association
DAG の詳細を返す。

### LLMGraphDAGCancel[id] / LLMGraphDAGStop[id]
DAG をキャンセル/停止する。

### LLMGraphDAGRetry[id, opts]
失敗ノードをリトライする。

### LLMGraphDAGRebuild[id, opts]
DAG を再構築する。

### LLMGraphDAGFindByContext[ctx] → id
コンテキストから DAG を検索する。

### LLMGraphDAGMarkFailed[id, node]
ノードを失敗としてマークする。

### LLMGraphDAGPlot[id, opts]
DAG を描画する。

### LLMGraphDAGSnapshot[id] → snapshot
DAG をスナップショット保存する (`$ClaudeSnapshots` 配下)。

### LLMGraphDAGRestore[snapshot]
スナップショットから復元する。

### LLMGraphDAGListSnapshots[] → List
スナップショット一覧を返す。

### LLMGraphDAGMergeHistory[id]
履歴をマージする。

### iLLMGraphNode[...] (公開済み内部)
LLMGraph ノードコンストラクタ。ClaudeStateGraph 連携用。

## ランタイム系

### ClaudeBuildRuntimeAdapter[opts] → Association
ランタイムアダプタ Association を構築する。
→ Association
Options: "ExecutionTimeoutSeconds" -> 30 ("DefaultTimeoutSeconds" キーとして保持)

### ClaudeStartRuntime[adapter, opts] → ランタイムID
ランタイムを開始する。

### ClaudeEvalViaRuntime[adapter, prompt, opts]
ランタイム経由で評価する。

### ClaudeApproveProposal[proposal, opts]
ランタイムが提示した実行提案を承認する。

### ClaudeRuntimeSnapshot[id] → snapshot
ランタイム状態をスナップショット保存する。

### ClaudeRuntimeRestore[snapshot]
スナップショットから復元する。

### ClaudeRuntimeListSnapshots[] → List
ランタイムスナップショット一覧を返す。

### ClaudeRegisterDAGRuntime[id, adapter]
DAG にランタイムを登録する。

### ClaudeBeginParallelKernels[opts]
ParallelKernels を前置起動する。

### $UseClaudeRuntime
型: Bool
ランタイム使用フラグ。

### $ClaudeLastRuntimeId
型: String
直近のランタイムID。

### $ClaudeRoutingProviders
型: List
ルーティング対象プロバイダ一覧。

### $ClaudeRuntimeAsyncExecution
型: Bool
コード実行を非同期 (ParallelSubmit) 化するフラグ。

### $ClaudeRuntimeAsyncForce
型: Bool
非同期実行を強制するフラグ。

### $ClaudeRuntimeAsyncSuppressInputEval
型: Bool
非同期時に入力評価を抑制するフラグ。

### $ClaudeSnapshots
型: String, 初期値: `$ClaudeWorkingDirectory/snapshots`
DAG スナップショット保存ディレクトリ。

## グローバル設定変数

### $ClaudeModel
型: tuple `{provider, model}`, 初期値: `{"claudecode","claude-opus-4-7"}`
Claude CLI / 各プロバイダに渡すモデル指定。"" は省略時 CLI デフォルト。

### $ClaudeTimeout
型: Integer, 初期値: 1200
問い合わせのタイムアウト秒数。

### $ClaudeVerbose
型: Bool, 初期値: False
詳細ログ出力フラグ。

### $ClaudeStandardFont
型: String, 初期値: "Yu Gothic UI"
ClaudeEval 生成コードで強制する標準フォント名。

### $ClaudePrivateModel
型: tuple, 例: `{"lmstudio","openai/gpt-oss-20b","http://127.0.0.1:1234"}`
秘密データ処理用ローカルモデル。AutoPrivate -> True 時に使用。

### $ClaudeTestModel
型: String/tuple, 初期値: `$ClaudeModel`
分離検証用モデル。

### $ClaudeFallbackModels
型: List, 初期値: `{{"chatgptcodex","gpt-5.5"},{"anthropic",{...opus}},{"openai","gpt-5.5"}}`
フォールバックモデル優先順位。各要素は {provider, model} または {provider, model, url}。NBAccess に同期。

### $ClaudeWorkingDirectory
型: String, 初期値: `FileNameJoin[{$HomeDirectory,"Claude Working"}]`
Claude Code 作業ディレクトリ。配下の .claude/CLAUDE.md, rules/, skills/ を読ませる。

### $OpenaiWorkingDirectory
型: String, 初期値: `FileNameJoin[{$HomeDirectory,"OpenAI Working"}]`
OpenAI 作業ディレクトリ。

### $ClaudeAccessibleDirs
型: List, 初期値: `{$packageDirectory}`
Claude Code に Read 許可する追加ディレクトリ。NotebookDirectory は初回使用時にダイアログで許可確認。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索/手動上書き可。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。

### $ClaudePackageKeywordMap
型: Association
外部パッケージがキーワードを登録する。プロンプトにキーワードが含まれると対応 api.md がコンテキストに自動注入。各パッケージが自身のロード時に登録。例: `$ClaudePackageKeywordMap["maildb"] = {"メール","mail","〆切"}`

### $claudecodeVersion
型: String
パッケージバージョン。

### $iMediaMaxImageSize
型: Number/Integer
マルチモーダル送信時の画像最大サイズ。

### $ClaudePriorityModeUntil
型: AbsoluteTime
高優先度モードの有効期限。

## ChatGPT Codex CLI 設定

### $ChatgptCodexExe
型: String
Codex CLI 実行ファイルパス。

### $ChatgptWorkingDirectory
型: String
Codex 作業ディレクトリ。

### $ChatgptAccessibleDirs
型: List
Codex に許可するアクセス可能ディレクトリ。

### $ChatgptCodexHomeDirectory
型: String
Codex のホームディレクトリ。

### $ChatgptCodexPermissionProfile
型: String
Codex の権限プロファイル。

### $ChatgptCodexApprovalPolicy
型: String
Codex の承認ポリシー。

### $ChatgptCodexModel
型: String/Symbol, 初期値: Automatic
Codex の使用モデル。"Automatic" は CLI 既定。

### $ChatgptCodexHarnessMode
型: String
Codex のハーネスモード。

### $ChatgptCodexRetainTempProjects
型: Bool
一時プロジェクトを保持するフラグ。

### $ChatgptCodexSourceExposureMode
型: String
ソース露出モード。

### $ClaudeCLIHarnessMode
型: String
Claude CLI のハーネスマテリアライズモード。

## オプションシンボル一覧

ClaudeQuery / ClaudeEval / ContinueEval 系で使用する共通オプション (シンボル名のみ公開、デフォルトは関数依存):

### Fallback
True で CLI 利用不可時にフォールバックモデルへ自動切替。アクセスレベルに応じ利用可能モデルのみ対象。デフォルト False。

### AutoPrivate
True で秘密変数アクセスタスクの生成コードに Model -> `$ClaudePrivateModel`, PrivacySpec -> Automatic を付与。デフォルト False。

### AutoEvaluate
ClaudeWriteResponse 等で生成コードセルを自動評価するか。デフォルト False。

### Model
プロバイダ・モデル指定。Automatic / {"provider","model"} / {"provider","model","url"}。

### PrivacySpec
機密データの構造仕様。Automatic で自動推定。

### Timeout
タイムアウト秒数。Automatic で `$ClaudeTimeout`。

### Mode
編集モード等の動作指定。

### DryRun
True で実際の変更を行わず予定のみ表示。

### TargetFiles / TargetFunctions
処理対象ファイル / 関数の限定。

### StartTime / RepeatInterval
スケジュール実行の開始時刻・繰り返し間隔。

### Keywords / Title / Refetch
ClaudeAttach 等での添付メタ指定。Refetch でキャッシュ無視再取得。

### Owner / Repository / Branch / BaseBranch
GitHub 連携時のリポジトリ指定。

### Inherit / License / WebFetch / WebSearch / References / Demos / Disclaimer / Acknowledgments
それぞれ上記関連関数のオプション (前述)。