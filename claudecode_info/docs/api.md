# claudecode API Reference

claudecode パッケージは Wolfram Language / Mathematica から Claude Code CLI および各種 LLM プロバイダーを呼び出すための統合インターフェースを提供する。依存: [NBAccess](https://github.com/transreal/NBAccess), [github](https://github.com/transreal/github) (GitHubREST`)。

## 基本設定変数

### $ClaudeModel
型: {String, String} (tuple), 初期値: {"claudecode", "claude-sonnet-4-6"}
Claude CLI に渡すプロバイダーとモデル名のペア。形式: {provider, modelName}。provider は "claudecode" | "anthropic" | "openai" | "lmstudio" | "chatgptcodex"。
例: $ClaudeModel = {"claudecode", "claude-opus-4-8"}; $ClaudeModel = {"anthropic", "claude-sonnet-4-6"}

### $ClaudeAdvisaryModel
型: {String, String} | String, 初期値: {"chatgptcodex", "Automatic"}
仕様レビュー・合意形成ワークフローでのアドバイザリー役 (Codex) のモデル指定。$ClaudeModel と同形式。bare provider string "chatgptcodex" も受け付ける。例: {"chatgptcodex", "gpt-5.5"}

### $ClaudeTimeout
型: Integer, 初期値: 1200
ClaudeQuery / ClaudeEval 等のタイムアウト秒数。

### $ClaudeVerbose
型: Boolean, 初期値: False
True で履歴コンパクション等の詳細ログを Messages に出力する。

### $ClaudeStandardFont
型: String, 初期値: "Yu Gothic UI"
ClaudeEval が生成する出力コード (Grid/Column/Style/Button 等) で統一的に使用するフォント名。プロンプトに埋め込まれ FontFamily 指定を強制する。

### $ClaudePrivateModel
型: {String, String} | {String, String, String}, 初期値: なし
秘密データ処理用ローカルモデル指定。AutoPrivate -> True 時に機密変数を含むタスクに使用される。
例: $ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code を起動する作業ディレクトリ。配下の .claude/CLAUDE.md, .claude/rules/, .claude/skills/ を Claude Code に読ませる。

### $OpenaiWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "OpenAI Working"}]
OpenAI / ChatGPT Codex CLI の作業ディレクトリ。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。iPrepareClaudeProjectDirectory が一時 settings.json に Read 許可を注入する。ノートブックの TaggingRules に NBSetAccessibleDirs で永続化可能。$packageDirectory 配下以外の新規ディレクトリは初回使用時にダイアログで許可を確認する。

### $ClaudeFallbackModels
型: List, 初期値: {{"chatgptcodex","gpt-5.5"},{"anthropic","claude-opus-4-8"},{"openai","gpt-5.5"}}
フォールバックモデル優先順位。各要素は {"provider", "modelName"} または {"provider", "modelName", "url"}。NBAccess`NBSetFallbackModels に自動同期される。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索されるか手動で上書きできる。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。内容が空の場合、CLAUDE.md が見つからなかったか内容がない。

### $ClaudeSnapshots
型: String, 初期値: FileNameJoin[{$ClaudeWorkingDirectory, "snapshots"}]
LLMGraphDAG スナップショットの保存ディレクトリ。

### $ClaudeDocModel
型: {String, String} | String, 初期値: {"claudecode", "claude-sonnet-4-6"}
ドキュメント生成・更新時に使用するモデル。"" で $ClaudeModel と同じモデルを使用。StringMatchQ[$ClaudeDocModel, "claude-sonnet-*"] なら自動的にタプル形式の最新 Sonnet に更新される。

### $ClaudeDocRetryDelay
型: Number, 初期値: 60
ドキュメント生成のリトライ待機秒数。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
ドキュメント生成の最大リトライ回数。

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースの最大文字数。

### $ClaudeDocUpdateStaleSeconds
型: Number, 初期値: 1800
ClaudeUpdateDocumentation の非同期ドキュメント更新チェーンのストール検出秒数。このタイムアウトを超えたロックは自動解放される。

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval が再帰的に ClaudeEval を生成する際の最大深度。0 で再帰禁止。値を大きくすると多段階の自動タスク連鎖が可能。

### $ClaudeEvalMode
型: String | Automatic
ClaudeEval の動作モード。

### $ClaudeEvalHook
型: Function | None
ClaudeEval の実行前後フック関数。

### $ClaudeEvalAutoThreshold
型: Integer
自動評価の文字数閾値。

### $ClaudeEvalVerbose
型: Boolean
ClaudeEval の詳細ログ。

### $ClaudeEvalAutoLLMMinLength
型: Integer
自動 LLM ディスパッチの最小文字数。

### $ClaudeEvalAutoLLMMinNewlines
型: Integer
自動 LLM ディスパッチの最小改行数。

### $ClaudeEvalNaturalDispatch
型: Boolean
自然言語ディスパッチの有効フラグ。

### $ClaudeEvalNaturalVerbose
型: Boolean
自然言語ディスパッチの詳細ログ。

### $ClaudeEvalNotebookContext
型: Boolean | Automatic
ノートブックコンテキストをプロンプトに含めるか。

### $ClaudeEvalLastProposedExprString
型: String
最後に ClaudeEval が提案した式の文字列。デバッグ用。

### $claudecodeVersion
型: String
パッケージバージョン文字列。

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
外部パッケージがキーワードを登録する Association。プロンプトにキーワードが含まれると対応パッケージの api.md がコンテキストに自動注入される。各パッケージが自身のロード時に登録する。
例: $ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〆切"};

### $ClaudePackageAuxKeywordMap
型: Association, 初期値: <||>
補助 api_<aux>.md の注入条件を登録する Association。形式: <|pkg -> <|aux -> {キーワード...}|>|>。未登録の補助 api は常に注入される (後方互換)。
例: $ClaudePackageAuxKeywordMap["SourceVault"] = <|"eagle" -> {"Eagle", "Exif"}|>;

### $ClaudePaletteServiceControls
型: List, 初期値: {}
ShowClaudePalette の Privacy セクション下に表示するサービストグルのレジストリ。外部パッケージが登録する。各エントリは <|"Id"->id, "RunningQ"->(Function[]->True|False|Missing[]), "Start"->Function[], "Stop"->Function[], "RunningLabel"->label, "StoppedLabel"->label, "UnknownLabel"->label, (opt)"RunningColor"->color, "StoppedColor"->color|>。各 *Label は String または 0 引数 Function。

### $LLMGraphMaxConcurrency
型: Integer
LLMGraph の最大並列実行数。

### $LLMGraphAutoStopThreshold
型: Integer
LLMGraph の自動停止閾値 (エラー数上限)。

### $LLMGraphDAGStallSeconds
型: Number
LLMGraphDAG のストール検出秒数。

### $LLMGraphDAGMaxJobSeconds
型: Number
LLMGraphDAG の最大ジョブ実行秒数。

### $UseClaudeRuntime
型: Boolean
ClaudeRuntime を使用するかどうかのフラグ。

### $ClaudeLastRuntimeId
型: String
最後に起動したランタイムの ID。ClaudeStartRuntime が設定する。

### $ClaudeRoutingProviders
型: List
ルーティングプロバイダーリスト。

### $ClaudeRuntimeAsyncExecution
型: Boolean
ランタイムコード実行を非同期 (ParallelSubmit) で行うかどうか (Phase 32)。

### $ClaudeRuntimeAsyncForce
型: Boolean
非同期実行を強制するフラグ。

### $ClaudeRuntimeAsyncSuppressInputEval
型: Boolean
入力評価を抑制するフラグ。

### $ClaudeParallelKernelCount
型: Integer
並列カーネル数。ClaudeBeginParallelKernels が設定する。

### $ClaudeMailFetchAsync
型: Boolean, 初期値: True
新着メール取得 (SourceVaultMailFetchNew) を別プロセス (wolframscript) で非同期実行し FrontEnd を塞がないかどうか。決定論的な「新着メール」ルートで使用し、現在の一覧を即返ししてバックグラウンドで取得・完了時に通知する。False で従来の同期 fetch に戻す (ライセンス席が逼迫して別プロセス起動が不安定な環境向け)。

### $ClaudePriorityModeUntil
型: AbsoluteTime
高優先度モードの終了絶対時刻。ClaudeBeginHighPriority が設定する。

### $ClaudeEditModesVersion
型: String
編集モードシステムのバージョン。

### $ClaudeEditModeAppendTagOpen
型: String
追記モードの開始タグ文字列。

### $ClaudeEditModeAppendTagClose
型: String
追記モードの終了タグ文字列。

### $ClaudeEditModeInsertTagClose
型: String
挿入モードの終了タグ文字列。

### $ChatgptCodexExe
型: String
ChatGPT Codex CLI の実行ファイルパス。

### $ChatgptWorkingDirectory
型: String
ChatGPT Codex の作業ディレクトリ。

### $ChatgptAccessibleDirs
型: List
ChatGPT Codex にアクセス許可するディレクトリリスト。

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
型: String | Symbol, 初期値: Automatic
Codex のモデル。"Automatic" または Symbol Automatic で CLI 既定モデルを使用。

### $ChatgptCodexHarnessMode
型: String
Codex ハーネスモード。

### $ChatgptCodexRetainTempProjects
型: Boolean
一時プロジェクトを保持するかどうか。

### $ChatgptCodexSourceExposureMode
型: String
ソースコードの公開モード。

### $ClaudeCLIHarnessMode
型: String
Claude CLI ハーネスモード (Phase 4)。

### $ClaudeCloudSendPreflightLog
型: List, 初期値: {}
クラウド送信プリフライト監査ログのインメモリバッファ。ClaudeCloudSendPreflightLogClear でクリア。

### $ClaudeCloudSendPreflightLogMaxLength
型: Integer
$ClaudeCloudSendPreflightLog の最大エントリ数。超過時は古いエントリを削除。

### $ClaudeCloudSendPreflightContextResolver
型: Function | None
プリフライト判定時のコンテキスト解決フック。外部パッケージが登録する。

### $ClaudeCloudSendRoutePolicy
型: Association | String
クラウド送信のルーティングポリシー設定。

### $ClaudeCloudSendPreflightLogFile
型: String
プリフライト監査ログの永続化ファイルパス。

## LLM クエリ関数

### ClaudeQuery[task, opts]
LLM に問い合わせてテキスト応答をノートブックセルに出力する。task は String または {String, Image, ...} (マルチモーダル)。
→ String | $Failed
Options: Model -> $ClaudeModel, Fallback -> False, AutoPrivate -> False, Timeout -> $ClaudeTimeout, WebFetch -> False, WebSearch -> False, PrivacySpec -> Automatic, Integrations -> Automatic, OutputMode -> Automatic, AutoCellize -> True, NonBlocking -> False, RepeatInterval -> None

### ClaudeQuerySync[task, opts]
ClaudeQuery の同期バージョン。セルへの出力なしに文字列を返す。
→ String | $Failed
Options: ClaudeQuery と同じ

### ClaudeQueryBg[task, opts]
バックグラウンドで LLM に問い合わせる。マルチモーダル ({task, Image[...]}) 対応。claudecode プロバイダーでも vision 利用可能 (Phase 35: iClaudeQueryRawNonBlocking 経由で CLI にリダイレクト)。
→ String | $Failed
Options: ClaudeQuery と同じ + NonBlocking -> False (True でノンブロッキング)

### ClaudeQueryAsync[task, opts]
非同期クエリ。ScheduledTask 経由で実行し完了時にセルに書き込む。
→ Null
Options: ClaudeQuery と同じ + StartTime -> Now

### ClaudeQueryAsyncSilent[task, opts]
非同期クエリ (セル出力なし)。
→ Null

### ClaudeWriteResponse[text, nb]
テキストをノートブック nb のセルに書き込む。
→ Null

### ClaudeMath[task, opts]
数学的問い合わせ。LaTeX / Mathematica 出力を優先するプロンプト付き。
→ String | $Failed

### ClaudeExtractCode[response]
LLM 応答テキストから最初のコードブロックを抽出する。
→ String | Missing["NotFound"]

### ClaudeExtractAllCode[response]
LLM 応答テキストからすべてのコードブロックを抽出する。
→ List[String]

### ClaudeEnsureSilentNotebook[]
サイレント (非表示) ノートブックオブジェクトを確保して返す。バックグラウンド処理用。
→ NotebookObject

### ClaudeDebug[opts]
Claude Code セッション・ランタイム状態のデバッグ情報を出力する。
→ Null

## ClaudeEval / コード生成

### ClaudeEval[task, opts]
LLM に WL コードを生成させてノートブックに評価セルとして出力する。ContinueEval / ContinueUpdate のチェーンを生成可能。$ClaudeEvalMaxDepth で再帰深度を制限する。
→ Null
Options: Model -> $ClaudeModel, Fallback -> False, AutoPrivate -> False, AutoEvaluate -> False, AutoCellize -> True, Timeout -> $ClaudeTimeout, WebFetch -> False, WebSearch -> False, PrivacySpec -> Automatic, OutputMode -> Automatic, NonBlocking -> False

### ContinueEval[task, opts]
直前の ClaudeEval のコンテキストを引き継いで評価を継続する。ClaudeEval が生成したコード内で使用する。
→ Null
Options: ClaudeEval と同じ

### ContinueUpdate[task, opts]
直前の ClaudeEval のコンテキストを引き継いで更新する。ClaudeEval が生成したコード内で使用する。
→ Null

## 仕様・設計ワークフロー

### ClaudeSpec[task]
ノートブック内容からプログラムの仕様を生成する。パレットからセル選択で呼び出し可能。
→ Null (セルに出力)

### ClaudeSpec[{task, image, ...}]
画像付きで仕様を生成する。
→ Null (セルに出力)

### ClaudeReview[packageName, opts]
パッケージのコードレビューを LLM で実行してノートブックセルに出力する。
→ Null

### ClaudeReviewChunked[packageName, opts]
大規模パッケージをチャンク分割してレビューする。$ClaudeDocMaxChunkChars を超えるソースに使用する。
→ Null

### ClaudeSpecStatus[]
現在のノートブックのプロジェクト (TaggingRule SourceVaultSpecProjectId) の仕様/合意形成ドラフティングステータスを表示する。ノートブックプロジェクトがない場合は実行中のバックグラウンド合意形成ジョブを一覧表示する。
→ Dataset | Null

### ClaudeSpecStatus["project"]
指定プロジェクトのステータスを報告する (spec/review バージョン数、最新 verdict、最新 sv:// URI、最終更新時刻、バックグラウンドジョブ実行中かどうか)。
→ Dataset

### ClaudeSpecVersions[]
現在のノートブックのプロジェクトの全 spec/review バージョンを Dataset として一覧表示する。列: Role, Round, Verdict, Seq, CreatedAtUTC, URI。
→ Dataset

### ClaudeSpecVersions["project"]
指定プロジェクトの全バージョンを Dataset として返す。
→ Dataset

### ClaudeSpecVersions["project", role]
role を "spec" | "review" | "requirements" に限定して一覧表示する。
→ Dataset

### ClaudeSpecText[uri]
sv:// URI (ClaudeSpecVersions の URI 列) から spec/review/requirements バージョンのテキストを返す。sv://snapshot/Class/hex・sv://snapshot/Class:hex・生の snapshot:Class:hex ref を受け付ける。
→ String

### ClaudeOpenSourceVaultURI[uri]
sv:// スナップショット URI を解決し内容を新規ノートブックウィンドウで開く (メタデータグリッド + Text 本体。review は Findings も含む)。sv:// リンクのクリックアクション。
→ NotebookObject | $Failed

### CreateImplementationWorkflow[name, approvedSpec, opts]
承認済み設計仕様を SVWorkflow_<Name> パッケージとして SourceVault_workflows/<name>/ 配下に実装する。approvedSpec は sv:// URI、スナップショット ref、または生テキスト。$ClaudeModel が実装担当、$ClaudeAdvisaryModel が検証担当。複雑な作業はステージ分割して補助仕様をレビューしてから実装する。進捗は WindowStatusArea に表示。完了時に生成ワークフローの起動関数を登録してサマリーをノートブックに書き込む。
→ String (バックグラウンドジョブ id)
Options: "Notes" -> "" (追加指示), "ClaudeModel" -> $ClaudeModel, "AdvisaryModel" -> $ClaudeAdvisaryModel, "MaxRounds" -> 3, "Nb" -> Automatic (ターゲットノートブック), "Launch" -> True (完了後自動起動)

### LaunchImplementationWorkflow[name, args]
CreateImplementationWorkflow で生成したコード化ワークフロー name をロードして起動する。SourceVault`SourceVaultLoadWorkflow[name] でロードし WorkflowInfo["Launch"] を args で呼び出す。
→ Association (<|"context"->..., "entry"->..., "result"->...|>)

### ClaudeImplStatus[]
現在のノートブックの spec-impl ワークフロー実行状況を表示する: 現在フェーズ、実行中モデル、ステージ、ラウンド、メッセージ、SourceVault 成果物/検証チェーン数、最新 verdict。実行中は WindowStatusArea にも自動表示される。
→ Dataset

### ClaudeImplStatus["workflow"]
指定ワークフロー (実行中または完了済み) のステータスを報告する。
→ Dataset

### ClaudeImplMonitor[]
ClaudeImplStatus[] を約 2 秒ごとに自動更新するライブ Dynamic パネルを返す。ノートブックセルに配置して監視する。
→ Dynamic

## セッション管理

### CreateClaudeSession[opts]
新しい Claude セッションを作成してノートブックに履歴を関連付ける。
→ String (セッション id)
Options: Inherit -> None (継承元セッション id), Timeout -> $ClaudeTimeout, Model -> $ClaudeModel

### ClaudeRestoreSession[sessionId]
保存済みセッションを復元する。
→ True | $Failed

### ClaudeListSessions[]
保存済みセッション一覧を表示する。
→ Dataset

### ClaudeDeleteSession[sessionId]
セッションを削除する。
→ True | $Failed

### ClaudeShowHistory[opts]
現在のセッション履歴を表示する。
→ Dataset

### ClaudeSessionStatus[]
現在のセッションのステータス (モデル、履歴サイズ、レート制限等) を表示する。
→ Dataset

### ClaudeCompactHistory[opts]
セッション履歴を圧縮する (古い会話を要約に置換)。
→ Null

### ClaudeHistorySize[]
現在のセッション履歴のサイズ (トークン概算) を返す。
→ Integer

### ClaudeRateLimitStatus[]
現在のレート制限ステータスを表示する。
→ Dataset

### ClaudeRateLimitClear[]
レート制限カウンターをクリアする。
→ Null

### ClaudeStatus[]
Claude Code プロセスの全体ステータスを表示する。
→ Dataset

### ClaudeAbort[]
実行中の Claude Code プロセスを中断する。
→ Null

### ClaudeProcessList[]
実行中の Claude Code プロセス一覧を表示する。
→ Dataset

## 添付・Web

### ClaudeAttach[url, opts]
URL を現在のセッションに添付する。コンテンツをキャッシュしてコンテキストに含める。
→ String (添付 id) | $Failed
Options: Refetch -> False, Keywords -> Automatic, Title -> Automatic

### ClaudeAttach[file, opts]
ファイルを現在のセッションに添付する。
→ String (添付 id) | $Failed
Options: Keywords -> Automatic, Title -> Automatic

### ClaudeDetach[id]
添付を解除する。
→ True | $Failed

### ClaudeAttachments[]
現在の添付一覧を表示する。
→ Dataset

### ClearAttachments[]
すべての添付をクリアする。
→ Null

### ClaudeWebSearch[query, opts]
Web 検索を実行してコンテキストに取り込む。
→ List[Association] | $Failed
Options: TaskTypes -> Automatic, Keywords -> Automatic

### ClaudeWebFetch[url, opts]
URL のコンテンツを取得してコンテキストに取り込む。
→ String | $Failed
Options: Refetch -> False, Keywords -> Automatic

### WebSearch[query, opts]
ClaudeWebSearch のエイリアス。ClaudeQuery / ClaudeEval 内部から使用される。

### WebFetch[url, opts]
ClaudeWebFetch のエイリアス。ClaudeQuery / ClaudeEval 内部から使用される。

### ClaudeQueryShowContext[]
現在のクエリコンテキスト (ファイルアクセス設定、履歴、添付等) を表示する。
→ Null

## ドキュメント生成

### ClaudeCreateDocumentation[packageName, opts]
パッケージの包括的ドキュメント一式 (api.md, overview.md, README.md 等) を生成する。リミット到達時に自動停止し再実行で未生成分のみ続行する。README.md は最後に生成される。
→ True | $Failed
Options: References -> {} (URL/書籍リスト。README.md 参照文献セクションに追加), Demos -> {} (デモ URL リスト。README.md に反映), Disclaimer -> {} (免責事項テキストリスト。README.md のみ), License -> "" (ライセンス文字列。空で GitHubREST`$GitHubLicenseHolder 非空なら MIT 自動挿入), Acknowledgments -> {} (謝辞テキストリスト。README.md のみ), Model -> $ClaudeDocModel, Keywords -> Automatic, Title -> Automatic

### ClaudeUpdateDocumentation[packageName, instruction, opts]
既存ドキュメントを instruction に従って部分更新する。非同期連鎖で進行するため $ClaudeDocUpdateStaleSeconds 超のロックは自動解放される。
→ True | $Failed
Options: ClaudeCreateDocumentation と同じ

## ディレクティブ管理 (CLAUDE.md)

### ClaudeAddDirective[content, opts]
CLAUDE.md / rules / skills にディレクティブを追加する。
→ True | $Failed
Options: Mode -> "rule" | "skill" | "md"

### ClaudeRestoreDirective[id]
バックアップからディレクティブを復元する。
→ True | $Failed

### ClaudeListDirectives[]
現在のディレクティブ一覧を表示する。
→ Dataset

### ClaudeUpdateDirective[id, content]
ディレクティブを更新する。
→ True | $Failed

### ClaudeDirectiveBackupDataset[]
ディレクティブのバックアップ履歴を Dataset として返す。
→ Dataset

### ClaudeSyncDirectives[]
ディレクティブをファイルシステムと同期する。
→ True | $Failed

### ClaudeShowAccessConfig[]
現在のアクセス設定 (アクセス可能ディレクトリ、権限等) を表示する。
→ Null

## クラウド送信プリフライト

LLM へのクラウド送信前に何が送られるかを監査・制御するシステム。外部パッケージ (SourceVault 等) が $ClaudeCloudSendPreflightContextResolver にフックを登録して使用する。

### ClaudeCloudSendPreflightDecision[context]
コンテキスト context に対するクラウド送信プリフライト判定を返す。ルーティングポリシーとコンテキスト解決結果に基づいて送信可否を決定しログに記録する。
→ Association (decision, route, reason)

### ClaudeCloudSendPreflightError[context, msg]
プリフライト処理中のエラーを記録してエラー Association を返す。
→ Association

### ClaudeCloudSendPreflightFailure[context, reason]
プリフライト失敗 (送信禁止) を記録して失敗 Association を返す。
→ Association

### ClaudeCloudSendPreflightGuardDryRun[context]
ドライランモードでプリフライト判定をシミュレートする。実際の送信は行わない。
→ Association

### ClaudeCloudSendPreflightAudit[]
現在の $ClaudeCloudSendPreflightLog から監査サマリーを生成して返す。
→ Dataset

### ClaudeCloudSendPreflightLog[]
$ClaudeCloudSendPreflightLog の全エントリを Dataset として返す。
→ Dataset

### ClaudeCloudSendPreflightLogClear[]
$ClaudeCloudSendPreflightLog をクリアする。
→ Null

### ClaudeCloudSendPreflightLogSummary[]
プリフライトログのサマリー (件数、ルート分布、失敗数) を返す。
→ Association

### ClaudeCloudSendPreflightFailureCell[context, reason]
プリフライト失敗をノートブックセルとして表示する。
→ Null

### ClaudeCloudSendPreflightLogDataset[]
永続化ログファイル ($ClaudeCloudSendPreflightLogFile) から全エントリを Dataset として読み込む。
→ Dataset

## パッケージ操作補助

### ClaudeCheckSeparation[packageName]
パッケージの NBAccess 分離原則 (ノートブック依存コードが Private にあるか) を検証する。結果は $iSeparationCheckCache にキャッシュされ ClaudeFixSeparation で再利用される。$NBSeparationIgnoreList 登録パッケージ (NBAccess, NotebookExtensions) は対象外。
→ Association (violations, summary)

### ClaudeFixSeparation[packageName]
ClaudeCheckSeparation で検出された分離原則違反を修正する。$iSeparationCheckCache のキャッシュを使用する。
→ True | $Failed

### ClaudeCommand["/command"]
Claude Code CLI のスラッシュコマンドを実行する。
→ String | $Failed
例: ClaudeCommand["/compact"], ClaudeCommand["/status"]

### ClaudePrepareCommit[opts]
Git コミット用のメッセージを自動生成して表示する。変更サマリーを収集してフォーマットする。
→ String (コミットメッセージ)
Options: BaseBranch -> "main", Branch -> Automatic, Owner -> Automatic, Repository -> Automatic, DryRun -> False

## NBFileTranslate / ClaudeProcessFile

### NBFileTranslate[files, opts]
ノートブックファイルを LLM で翻訳・変換する。
→ True | $Failed
Options: Model -> $ClaudeModel, TargetFiles -> Automatic, OutputMode -> Automatic

### ClaudeProcessFile[file, task, opts]
ファイルを LLM で処理する (翻訳・要約・変換等)。
→ String | $Failed
Options: Model -> $ClaudeModel, OutputMode -> "text"

## LLMGraph

### NotebookLLMGraph[nb]
ノートブック nb の LLMGraph (セル間依存グラフ) オブジェクトを取得または作成する。
→ Association

### NotebookLLMGraphBuild[nb, opts]
ノートブックの LLMGraph を構築または再構築する。
→ Association

### NotebookLLMGraphPlot[nb, opts]
LLMGraph を視覚化する。
→ Graphics

### NotebookLLMGraphNodes[nb]
LLMGraph のノード一覧を返す。
→ List

### NotebookLLMGraphValidate[nb]
LLMGraph の整合性を検証する。
→ Association

### NotebookLLMGraphFetchResponse[nb, nodeId]
指定ノードの LLM 応答を取得する。
→ String | Missing

### NotebookLLMGraphSubSteps[nb, nodeId]
指定ノードのサブステップを返す。
→ List

### NotebookLLMGraphFetchL2[nb, nodeId]
L2 (詳細化レイヤー) の応答を取得する。
→ String | Missing

### NotebookLLMGraphErrors[nb]
LLMGraph のエラーノード一覧を返す。
→ List

### NotebookLLMGraphUpdateL2Status[nb, nodeId, status]
L2 ステータスを更新する。
→ True | $Failed

### NotebookLLMGraphPlotL2[nb, opts]
L2 グラフを視覚化する。
→ Graphics

### NotebookLLMGraphRerun[nb, nodeId, opts]
指定ノードを再実行する。
→ Null

### NotebookLLMGraphInvalidateDownstream[nb, nodeId]
指定ノードの下流ノードを無効化する。
→ Null

### NotebookLLMGraphSummary[nb]
LLMGraph のサマリー情報を返す。
→ Association

### NotebookLLMGraphExtractThread[nb, nodeId]
ノードからスレッド (会話履歴チェーン) を抽出する。
→ List

### NotebookLLMGraphApplyThread[nb, thread]
スレッドをノートブックに適用する。
→ Null

以下は Phase R-6 で外部パッケージ (ClaudeStateGraph 等) からの参照用に Public 化された LLMGraph 内部ヘルパー:

### iLLMGraphGetCached[nb]
LLMGraph キャッシュから nb のグラフを取得する。
→ Association | Missing

### iSaveNotebookLLMGraph[nb, graph]
LLMGraph を $iLLMGraphCache に保存する。
→ Null

### iNewLLMNode[opts]
新規 LLMGraph ノード Association を生成する。
→ Association

### iNewNotebookLLMGraph[nb]
新規 LLMGraph Association を生成して nb に関連付ける。
→ Association

### iLLMGraphMergeTwoGraphs[g1, g2]
2 つの LLMGraph をマージする。
→ Association

### iLLMGraphFlush[nb]
nb の LLMGraph キャッシュをフラッシュする。
→ Null

## LLMGraphDAG

### LLMGraphDAGCreate[tasks, opts]
タスクリストから有向非循環グラフ (DAG) 形式の LLM ジョブを作成して実行を開始する。
→ String (DAG id)
Options: Model -> $ClaudeModel, Timeout -> $ClaudeTimeout, TargetFiles -> {}, TargetFunctions -> {}, Baseline -> None, DryRun -> False

### LLMGraphDAGStatus[dagId]
DAG の実行ステータスを表示する。
→ Dataset

### LLMGraphDAGCancel[dagId]
DAG の実行をキャンセルする。
→ True | $Failed

### LLMGraphDAGStop[dagId]
DAG の実行を停止する。
→ True | $Failed

### LLMGraphDAGRetry[dagId]
失敗した DAG を再試行する。
→ True | $Failed

### LLMGraphDAGRebuild[dagId]
DAG を再構築して実行を再開する。
→ String (新 DAG id)

### LLMGraphDAGFindByContext[context]
コンテキストから DAG を検索する。
→ String (DAG id) | Missing

### LLMGraphDAGInspect[dagId]
DAG の詳細情報を表示する。
→ Association

### LLMGraphDAGMarkFailed[dagId, nodeId]
DAG の指定ノードを失敗マークする。
→ True | $Failed

### LLMGraphDAGSnapshot[dagId, opts]
DAG のスナップショットを $ClaudeSnapshots 配下に保存する。
→ String (スナップショット id)

### LLMGraphDAGRestore[snapshotId]
スナップショットから DAG を復元する。
→ String (DAG id)

### LLMGraphDAGListSnapshots[]
保存済みスナップショット一覧を返す。
→ Dataset

### LLMGraphDAGPlot[dagId, opts]
DAG を視覚化する。
→ Graphics

### LLMGraphDAGMergeHistory[dagId1, dagId2]
2 つの DAG 履歴をマージする。
→ String (マージ済み DAG id)

### LLMGraphExecute[graph, opts]
LLMGraph を実行する。
→ String (ジョブ id)
Options: Model -> $ClaudeModel, Timeout -> $ClaudeTimeout

### LLMGraphExecuteStatus[jobId]
LLMGraph 実行のステータスを返す。
→ Dataset

### LLMGraphExecuteCancel[jobId]
LLMGraph 実行をキャンセルする。
→ True | $Failed

## ランタイム

### ClaudeBuildRuntimeAdapter[nb, opts]
ノートブック nb 用のランタイムアダプター Association を構築する。ClaudeStartRuntime / ClaudeEvalViaRuntime で使用する。
→ Association
Options: "ExecutionTimeoutSeconds" -> 30 (アダプターの adapter["DefaultTimeoutSeconds"] キーに保持される既定タイムアウト秒数。Phase 29 追加)

### ClaudeStartRuntime[adapter]
ランタイムを起動する。$ClaudeLastRuntimeId に id を記録する。
→ String (ランタイム id)

### ClaudeEvalViaRuntime[adapter, code, opts]
ランタイム経由でコードを評価する。LLM が提案した式を安全な環境で実行する際に使用する。タイムアウト優先順位: proposal["ExpectedSeconds"] > adapter["DefaultTimeoutSeconds"] > 30。
→ Association (result, status)

### ClaudeApproveProposal[adapter, proposal]
LLM の提案 (proposal Association) を承認してランタイムで実行する。proposal["ExpectedSeconds"] に予想秒数を含めるとタイムアウトが自動延長される。
→ Association (result)

### ClaudeRuntimeSnapshot[runtimeId]
ランタイム状態のスナップショットを保存する。
→ String (スナップショット id)

### ClaudeRuntimeRestore[snapshotId]
スナップショットからランタイムを復元する。
→ String (ランタイム id)

### ClaudeRuntimeListSnapshots[]
ランタイムスナップショット一覧を返す。
→ Dataset

### ClaudeRegisterDAGRuntime[dagId, runtimeId]
DAG とランタイムを関連付ける。
→ True

### ClaudeBeginParallelKernels[n]
並列カーネル n 個を事前起動する。LLMGraphDAG の実行前に呼び出すと起動コストを節約できる。$ClaudeParallelKernelCount を設定する。
→ Null

### ClaudeBeginHighPriority[seconds]
high priority モードを seconds 秒間有効にする。$ClaudePriorityModeUntil を現在時刻 + seconds に設定する。
→ Null

### ClaudeEndHighPriority[]
high priority モードを終了する。
→ Null

## ポーリング・スケジューリング

### ClaudeRegisterPollingTick[key, func, interval]
ポーリング Tick に func を key で登録する。interval 秒ごとに func[] を呼び出す。
→ key

### ClaudeUnregisterPollingTick[key]
ポーリング Tick から key を削除する。
→ Null

### ClaudePollingTickKeys[]
登録済みポーリング Tick キー一覧を返す。
→ List

### ClaudeEnqueueFinalAction[func]
現在のクエリ完了後に実行するアクションをキューに登録する。
→ Null

## パレット・UI

### ShowClaudePalette[]
Claude Code コントロールパレットを表示する。Provider 選択 (claudecode/chatgptcodex/anthropic/openai/lmstudio を循環)、Model 選択 (現プロバイダーの候補列を循環)、Effort、Fallback、有料 API 許可、$ClaudePaletteServiceControls 登録サービスコントロール等を含む。
→ NotebookObject

### ClaudeRegisterPaletteServiceControl[spec]
パレットサービスコントロールを $ClaudePaletteServiceControls に登録する。同じ Id を再登録すると置換される。ShowClaudePalette[] を再実行すると反映される。
→ String (Id)

### ClaudeUnregisterPaletteServiceControl[id]
パレットサービスコントロールを id で削除する。
→ Null

## 機密管理

### MarkConfidential[expr]
式を機密としてマークする。Confidential[expr] でラップされる。
→ Confidential[expr]

### UnmarkConfidential[confidential]
機密マークを解除して内部値を返す。
→ expr

### IsConfidential[expr]
式が機密かどうかを返す。
→ True | False

### Confidential[expr]
機密データのラッパーヘッド。AutoPrivate -> True 時に $ClaudePrivateModel へのルーティングをトリガーする。

### NonConfidential[expr]
非機密として明示的にマークするラッパーヘッド。

### ScanConfidentialCells[nb]
ノートブック nb の機密セルをスキャンして一覧表示する。
→ Dataset

## 編集モード (Edit Modes)

### ClaudeAppendBlockToPackage[packageName, block, opts]
パッケージファイルにブロックを $ClaudeEditModeAppendTagOpen / Close タグ形式に従って追記する。
→ True | $Failed

### ClaudeInsertBeforeAnchorInPackage[packageName, anchor, block, opts]
パッケージファイルの anchor の前にブロックを $ClaudeEditModeInsertTagClose タグ形式に従って挿入する。
→ True | $Failed

### ClaudeParseEditModeResponse[response]
LLM の edit mode 応答 (append/insert タグ付き) をパースしてパッチリストを返す。
→ List[Association]

### ClaudeAutoDetectEditMode[packageName]
パッケージサイズ等から最適な編集モード ("full" | "append" | "insert") を自動選択する。
→ String

### ClaudeBuildEditModePromptInstructions[mode, opts]
指定編集モード用のプロンプト指示文字列を生成する。ClaudeUpdatePackage の内部で使用する。
→ String

### ClaudeUpdatePackageWithMode[packageName, instruction, mode, opts]
編集モード mode を指定してパッケージを更新する。ClaudeUpdatePackage の内部実装。
→ True | $Failed

## ユーティリティ

### cleanOutput[text]
LLM 出力テキストから不要なヘッダー・末尾空白等を除去する。
→ String

### stripANSI[text]
テキストから ANSI エスケープシーケンスを除去する。CLI 出力のクリーンアップに使用する。
→ String

## オプション一覧

以下のシンボルが ClaudeQuery / ClaudeEval / ClaudeQueryBg 等のオプションキーとして使用される:

- `Fallback` → False: True で Claude Code 利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする
- `AutoPrivate` → False: True で機密変数を含むタスク時に Model -> $ClaudePrivateModel, PrivacySpec -> Automatic を付与する
- `AutoEvaluate` → False: ClaudeEval でコード生成後に自動評価する (ClaudeEval のみ)
- `AutoCellize` → True: 応答を自動でノートブックセルに変換する
- `Model` → $ClaudeModel: 使用モデルの {provider, modelName} tuple または String
- `Timeout` → $ClaudeTimeout: タイムアウト秒数
- `WebFetch` → False: True でプロンプト内 URL を自動フェッチする
- `WebSearch` → False: True で Web 検索ツールを有効化する
- `PrivacySpec` → Automatic: プライバシー設定 (Automatic で AutoPrivate に従う)
- `Integrations` → Automatic: lmstudio モデル時の MCP サーバー / plugin リスト。明示リストが最優先。Automatic は $ClaudeLMStudioIntegrations → SourceVault の順で解決する
- `OutputMode` → Automatic: 出力形式 ("text" | "cell" | Automatic)
- `NonBlocking` → False: ClaudeQueryBg で True にするとノンブロッキング
- `RepeatInterval` → None: 繰り返し実行の間隔 (秒)
- `StartTime` → Now: ClaudeQueryAsync の実行開始時刻
- `References` → {}: ClaudeCreateDocumentation の参照 URL / 書籍リスト
- `Demos` → {}: ClaudeCreateDocumentation のデモ URL リスト
- `Disclaimer` → {}: ClaudeCreateDocumentation の免責事項テキストリスト (README.md のみ)
- `License` → "": ClaudeCreateDocumentation のライセンス文字列 (README.md のみ)
- `Acknowledgments` → {}: ClaudeCreateDocumentation の謝辞テキストリスト (README.md のみ)
- `DryRun` → False: 変更をシミュレートするがファイルに書き込まない
- `TargetFiles` → {}: レビュー / DAG 対象ファイルリスト
- `TargetFunctions` → {}: レビュー / DAG 対象関数リスト
- `Baseline` → None: 比較ベースライン
- `BaseBranch` → "main": ベースブランチ
- `Branch` → Automatic: 対象ブランチ
- `Owner` → Automatic: GitHub リポジトリオーナー
- `Repository` → Automatic: GitHub リポジトリ名
- `Keywords` → Automatic: キーワードリスト
- `Title` → Automatic: タイトル文字列
- `Refetch` → False: キャッシュを無視して再フェッチする
- `TaskTypes` → Automatic: Web 検索のタスクタイプ
- `Inherit` → None: セッション継承元 id
- `Mode` → Automatic: 動作モード ("full" | "append" | "insert" 等)