# claudecode API Reference
Wolfram Language から Claude Code CLI を操作するパッケージ。セッション管理・非同期評価・LLMグラフ・パッケージ自動更新を提供する。

## グローバル変数

### $ClaudeModel
型: String, 初期値: ""
Claude CLI に渡すモデル名。"" は Claude Code 自身のデフォルトモデルを使用。例: `$ClaudeModel = "claude-opus-4-6"`

### $ClaudePrivateModel
型: List, 初期値: {{"lmstudio","openai/gpt-oss-20b","http://127.0.0.1:1234"}} 相当
機密データ処理用ローカルモデル指定。`AutoPrivate -> True` 時に使用。形式: `{"provider","modelName"}` または `{"provider","modelName","url"}`

### $ClaudeTestModel
型: String, 初期値: $ClaudeModel
分離検証用モデル。`ClaudeCheckSeparation`/`ClaudeFixSeparation` で使用。

### $ClaudeTimeout
型: Number, 初期値: 1200
ClaudeQuery/ClaudeEval 等のタイムアウト秒数。

### $ClaudeVerbose
型: Boolean, 初期値: False
True にすると履歴コンパクション等の詳細ログを Messages に出力する。

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory,"Claude Working"}]
Claude Code を起動する作業ディレクトリ。配下の .claude/CLAUDE.md, .claude/rules/, .claude/skills/ を Claude Code に読み込ませる。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。手動上書き可能。例: `$ClaudeMDPath = "C:\\proj\\CLAUDE.md"`

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。空の場合は CLAUDE.md が見つからなかったか内容なし。

### $ClaudeSnapshots
型: String, 初期値: FileNameJoin[{$ClaudeWorkingDirectory,"snapshots"}]
LLMGraphDAG スナップショットの保存ディレクトリ。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。iPrepareClaudeProjectDirectory が一時的に settings.json へ注入する。NotebookDirectory はダイアログで許可確認($packageDirectory 配下を除く)。例: `$ClaudeAccessibleDirs = {$packageDirectory, "C:\\Users\\...\\作業フォルダ"}`

### $ClaudeFallbackModels
型: List, 初期値: {{"anthropic",$iModelOpus},{"openai","gpt-5"}}
フォールバックモデル優先順位。各要素は `{"provider","modelName"}` または `{"provider","modelName","url"}`。内部的に NBAccess`NBSetFallbackModels に同期される。

### $ClaudeDocModel
型: String, 初期値: 最新 Sonnet モデル
ドキュメント生成・更新時に使用するモデル。"" で $ClaudeModel と同じモデルを使用。例: `$ClaudeDocModel = "claude-sonnet-4-6"`

### $ClaudeDocRetryDelay
型: Number, 初期値: 60
ドキュメント生成のリトライ待機秒数。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
ドキュメント生成の最大リトライ回数。

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースの最大文字数。

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval が再帰的に ClaudeEval を生成する際の最大深度。0 で再帰禁止。

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
外部パッケージがキーワードを登録するための Association。プロンプトにキーワードが含まれると対応パッケージの api.md が自動注入される。各パッケージが自身のロード時に登録する。例: `$ClaudePackageKeywordMap["maildb"] = {"メール","mail","〒切"}`

### $LLMGraphMaxConcurrency
型: Integer
LLMGraphDAG の最大並列ジョブ数。

### $LLMGraphAutoStopThreshold
型: Number
LLMGraphDAG の自動停止閾値。

### $ClaudeRoutingProviders
型: List
クエリルーティング対象のプロバイダリスト。

### $UseClaudeRuntime
型: Boolean
True のとき ClaudeEval/ClaudeUpdatePackage を ClaudeRuntime 経由で実行する。

### $ClaudeLastRuntimeId
型: String
最後に使用した ClaudeRuntime の ID。

### $ClaudeEvalMode
型: Symbol
ClaudeEval の動作モード制御変数。

### $ClaudeEvalHook
型: Function
ClaudeEval 実行時に呼ばれるフック関数。

### $ClaudeEvalAutoThreshold
型: Number
ClaudeEval の自動 LLM 呼び出し判定閾値。

### $ClaudeEvalVerbose
型: Boolean
ClaudeEval の詳細ログ出力フラグ。

### $ClaudeEvalAutoLLMMinLength
型: Integer
ClaudeEval 自動 LLM 呼び出しの最小文字数。

### $ClaudeEvalAutoLLMMinNewlines
型: Integer
ClaudeEval 自動 LLM 呼び出しの最小改行数。

### $claudecodeVersion
型: String
パッケージバージョン文字列。

## オプションシンボル

### Fallback
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: Claude Code 利用不可時にフォールバックモデルへ自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。False (デフォルト): エラーをそのまま返す。

### AutoPrivate
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: 機密変数にアクセスするタスクの場合、生成コードに `Model -> $ClaudePrivateModel, PrivacySpec -> Automatic` を付与する。False (デフォルト): 通常動作。

### AutoEvaluate
ClaudeEval/ClaudeWriteResponse のオプション。True (デフォルト): 生成された Input セルを自動実行する。False: 実行せず表示のみ。

### StartTime
ClaudeEval/ContinueEval/ClaudeUpdatePackage のオプション。実行開始時刻を DateObject で指定。例: `StartTime -> Now + Quantity[3, "Hours"]`

### Timeout
ClaudeEval/ContinueEval/ClaudeQuerySync/ClaudeQueryBg/ClaudeQueryAsync のオプション。API タイムアウト秒数。Automatic は $iFallbackTimeout (600秒)。

### RepeatInterval
ClaudeEval のオプション。繰り返し実行間隔。例: `RepeatInterval -> Quantity[2,"Hours"]`(2時間ごと)、`RepeatInterval -> {Quantity[1,"Hours"],5}`(1時間ごと最大5回)。None (デフォルト): 1回のみ。

### TargetFunctions
ClaudeUpdatePackage のオプション。更新対象の関数名リスト。Automatic で自動判定。

### TargetFiles
ClaudeUpdateDocumentation のオプション。更新対象ファイルリスト。Automatic で自動判定。例: `TargetFiles -> {"api.md"}`

### Mode
ClaudeUpdateDocumentation のオプション。"Update"(既存更新, デフォルト) または "Create"(新規作成)。

### DryRun
ClaudePrepareCommit/ClaudeMigrateBackupHistory のオプション。True: 変更せず確認のみ。False (デフォルト): 実際に実行。

### Inherit
CreateClaudeSession のオプション。True (デフォルト): デフォルト履歴を継承。False: 独立したセッションを作成。

### Model
ClaudeQuerySync/ClaudeQueryBg/ClaudeQueryAsync のオプション。Automatic: プライバシーレベルに応じて自動選択。`{"provider","model"}`: 指定モデルを API 経由で使用。

### WebSearch
ClaudeQuery/ClaudeEval のオプション。True (デフォルト): Web 検索を許可。False: 禁止。

### WebFetch
ClaudeQuery/ClaudeEval のオプション。True: Web フェッチを許可(課金あり、Fallback->True 必須)。False (デフォルト)。

### Keywords
ClaudeAttach のオプション。キーワードリストを登録すると、プロンプト中にキーワードが含まれる際にそのアタッチメントが自動注入される。例: `Keywords -> {"PDF","論文"}`

### Title
ClaudeAttach のオプション。アタッチメントのタイトルを明示指定。None (デフォルト): 自動推定。

### Refetch
ClaudeAttach のオプション。True: URL キャッシュを無視して再取得。False (デフォルト)。

### PrivacySpec
ClaudeQuerySync/ClaudeQueryAsync のオプション。プライバシーレベル指定。Automatic で自動判定。

### Owner
ClaudePrepareCommit のオプション。GitHub リポジトリオーナー名。Automatic で自動検出。

### Repository
ClaudePrepareCommit のオプション。GitHub リポジトリ名。Automatic で自動検出。

### Branch
ClaudePrepareCommit のオプション。対象ブランチ名。Automatic で自動検出。

### BaseBranch
ClaudePrepareCommit のオプション。ベースブランチ名。Automatic で自動検出。

### References
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。URL や書籍名のリストを指定すると README.md に参考文献セクションを追加。例: `References -> {"https://...","書籍名"}`

### Demos
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。デモ動画や使用例の URL リストを指定すると README.md に反映。例: `Demos -> {"https://youtu.be/...","https://example.com/demo.nb"}`

### Disclaimer
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。免責事項セクションに追加する文言のリスト。例: `Disclaimer -> {"本ツールは研究目的専用です"}`

### License
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。"" (デフォルト): GitHubREST`$GitHubLicenseHolder が非空なら MIT ライセンスを自動挿入。文字列指定: そのままライセンステキストとして挿入。例: `License -> "MIT"`, `License -> "Apache-2.0 License..."`

### Acknowledgments
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。謝辞セクションに追加する文言のリスト。指定時は README.md の免責事項の前に配置。例: `Acknowledgments -> {"本研究は JSPS 科研費の助成を受けた"}`

## クエリ・評価

### ClaudeQuery[prompt] → String
Claude Code に prompt を送り、応答文字列を同期的に返す。セッション履歴・ノートブック書き込みを含む通常版。
```
ClaudeQuery[session, prompt]
ClaudeQuery[{text, Image[...], File[path], ...}]  (* マルチモーダル *)
```
Options: WebSearch -> True, WebFetch -> False, Fallback -> False, Timeout -> Automatic

### ClaudeQuerySync[prompt, opts] → String
セッション履歴・ノートブック書き込みなしの軽量版クエリ。WindowStatusArea に経過時間を表示する。
→ String
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic
例: `ClaudeQuerySync[prompt, Model -> {"anthropic","claude-sonnet-4-6"}]`

### ClaudeQueryBg[prompt, opts] → String
FrontEnd 操作・ScheduledTask 生成なしで Claude に同期問い合わせする。SocketListen ハンドラ・ScheduledTask コールバック等の非同期コンテキストから安全に呼び出せる。
→ String
Options: Fallback -> False, Model -> Automatic, Timeout -> Automatic

### ClaudeQueryAsync[prompt, callback, nb, opts] → TaskObject
Claude に非同期で問い合わせ、完了時に `callback[応答文字列]` を呼ぶ。カーネルをブロックしない。WindowStatusArea に経過時間を表示する。
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic
例: `ClaudeQueryAsync["Hello", Print, EvaluationNotebook[]]`

### ClaudeWriteResponse[nb, text, opts] → Null
マークダウン形式のテキストをノートブックのセルとして展開する。見出し・リスト・コードブロック等を適切なセルスタイルに変換する。
Options: AutoEvaluate -> False

### ClaudeMath[task] → Null
Mathematica コード生成に特化したプロンプトで Claude を呼び出す。

### ClaudeExtractCode[response] → String
Claude の応答から最初の \`\`\`mathematica ブロックを抽出する。

### ClaudeExtractAllCode[response] → List
Claude の応答から全 \`\`\`mathematica ブロックをリストで返す。

### ClaudeSpec[task] → Null
ノートブック内容からプログラムの仕様を生成する。`ClaudeSpec[{task, image, ...}]` で画像付き仕様生成。パレットからセル選択で呼び出し可能。

### ClaudeEval[task, opts] → TaskObject
コードを非同期で生成・表示し、デフォルトセッションに履歴を保存する。`ClaudeEval[{text, data, ...}]` でテキスト・Dataset・Image・一般式を混在可能。`ClaudeEval[session, task]` で指定セッションに履歴を保存。
Options: AutoEvaluate -> True, StartTime -> Now, RepeatInterval -> None, Timeout -> Automatic, Fallback -> False

### ContinueEval[session, instruction, opts] → TaskObject
指定セッションで継続する。`ContinueEval[instruction]` はデフォルトセッション。`ContinueEval[]` は "エラーを修正してください" でデフォルトセッションを継続する。
Options: StartTime -> Now, Timeout -> Automatic

### ContinueUpdate[opts] → Null
直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を継続する。`ContinueUpdate["instruction"]` で追加指示付き継続。`ContinueUpdate[{"instruction",img}]` でテキスト+画像で継続。`ContinueUpdate["pkgName","instruction"]` で指定パッケージの直前の更新を継続。
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now

### ClaudeDebug[codeOrFile, errorMsg] → Null
デバッグ支援を非同期で求める(即座に返る)。

### ClaudeReview[codeOrFile] → Null
コードのレビューを非同期で行う。30000文字超は自動チャンク分割する。

### ClaudeReviewChunked[codeOrFile] → Null
ファイルをチャンク分割して非同期レビューする。

## セッション管理

### CreateClaudeSession["name"] → Session
名前付きセッションを作成する(デフォルト履歴を継承)。`CreateClaudeSession[session]` は既存セッションの履歴を継承した新セッションを作成。`CreateClaudeSession[]` はデフォルト履歴を継承した新セッションを作成。`CreateClaudeSession[Inherit->False]` は独立したセッションを作成。

### ClaudeRestoreSession[] → Null
デフォルトセッションをリストアする。`ClaudeRestoreSession["name"]` で指定名のセッションをリストアする。

### ClaudeListSessions[] → Null
ノートブック内の全セッションを一覧表示する。

### ClaudeDeleteSession["name"] → Null
指定名のセッションを削除する。`ClaudeDeleteSession["name","All"]` でセッションとその全履歴を削除する。

### ClaudeShowHistory[] → Null
デフォルトセッションの履歴を表示する。`ClaudeShowHistory[session]` または `ClaudeShowHistory["name"]` で指定セッションの履歴を表示。

### ClaudeSessionStatus[] → Null
デフォルトセッションの状態を表示する。`ClaudeSessionStatus[name]` で指定名のセッションの状態を表示。アクセス可能ディレクトリ・アタッチメント・作業ディレクトリのファイル等を確認できる。

### ClaudeCompactHistory[] → Null
セッション履歴をコンパクション(圧縮)する。

### ClaudeHistorySize[] → Integer
セッション履歴のサイズを返す。

### ClaudeStatus[] → Null
現在実行中の全 Claude タスクのリアルタイム状態を表示する。各タスクの経過時間・状態(思考中/テキスト生成中/ツール実行中)・生成済みテキスト断片数・思考断片数・ツール使用数を表示。

### ClaudeAbort[] → Null
実行中の全 Claude タスクを停止する。Claude Code プロセスの強制終了・ScheduledTask の停止・フォールバックタスクのキャンセルを行う。パレットの「実行停止」ボタンからも呼び出し可能。

## アタッチメント管理

### ClaudeAttach[path, opts] → Null
デフォルトセッションに参考資料をアタッチする。`ClaudeAttach[url]` は URL のページを PDF 化してキャッシュしアタッチする。`ClaudeAttach[session, path]` で指定セッションにアタッチする。アタッチされたファイルは ClaudeQuery/ClaudeEval 時に自動的に Read される。
Options: Keywords -> {}, Title -> None, Refetch -> False

### ClaudeDetach[path] → Null
デフォルトセッションからファイルをデタッチする。`ClaudeDetach[session, path]` で指定セッションからデタッチする。

### ClaudeAttachments[] → List
デフォルトセッションのアタッチメント一覧を返す。`ClaudeAttachments[session]` で指定セッションの一覧を返す。

### ClearAttachments[] → Null
デフォルトセッションの全アタッチメントをクリアする。`ClearAttachments[session]` で指定セッションの全アタッチメントをクリアする。

## パッケージ管理

### ClaudeCreatePackage[name, prompt] → Null
prompt に従って name.wl を新規作成し $packageDirectory に保存する。

### ClaudeUpdatePackage[packageName, prompt, opts] → TaskObject
$packageDirectory にある packageName.wl を Claude の支援でアップデートし、バックアップを作成する。prompt には文字列または `{文字列, Image, File[".../file.pdf"], ...}` を指定可能。
Options: TargetFunctions -> Automatic, StartTime -> Now, Fallback -> False, "UpdateApiMd" -> Automatic
例: `ClaudeUpdatePackage["pkg","修正指示", StartTime -> Now + Quantity[1,"Hours"]]`
`"UpdateApiMd" -> False` で api.md の自動更新をスキップ。

### ClaudeRestorePackage[packageName] → Null
直前のバックアップを復元する。

### ClaudeUpdatePackageHistory[] → List
全パッケージの ClaudeUpdatePackage 呼び出し履歴を表示しリストで返す。`ClaudeUpdatePackageHistory[packageName]` で指定パッケージの更新履歴を表示しリストで返す。各エントリは `<|"Package"->…,"Timestamp"->…,"Directory"->…|>`。

### ClaudeBackupDataset[packageName] → Grid
指定パッケージのバックアップ履歴を Review/Pull/Delete ボタン付き Grid で表示する。`ClaudeBackupDataset[]` で全パッケージのバックアップ履歴を表示。Review はバックアップ内容を確認、Pull は復元、Delete はその履歴を削除。

### ClaudeMigrateBackupHistory[packageName, opts] → Null
既存の history 内の生 .wl バックアップを差分形式(.wl.cz / .wl.cdiff)に変換して容量を削減する。`ClaudeMigrateBackupHistory[packageName, DryRun->True]` で削除せず容量削減の見積もりを表示。`ClaudeMigrateBackupHistory[]` で全パッケージに対して実行する。

### ClaudeConvertToPaclet[packageName] → Null
$packageDirectory の packageName.wl を Paclet 形式に変換する。packageName/ フォルダを作成し、Kernel/, Documentation/, PacletInfo.wl 等を生成する。元の .wl ファイルはバックアップ後に削除される。

## ドキュメント管理

### ClaudeCreateDocumentation["packageName", opts] → Null
パッケージの詳細なドキュメント一式を Claude で自動生成する。$packageDirectory 内の packageName.wl または packageName/ Paclet を対象とする。単一 .wl: $packageDirectory/packageName_info/docs/ に出力。Paclet: $packageDirectory/packageName/docs/ に出力。
Options: References -> {}, Demos -> {}, Disclaimer -> {}, License -> "", Acknowledgments -> {}

### ClaudeUpdateDocumentation["packageName", opts] → Null
ソース差分に基づき全ドキュメントを自動更新する。`ClaudeUpdateDocumentation["packageName","更新指示"]` で指示に従ってドキュメントを更新する。ノートブックのコンテキストも参照可能。
Options: TargetFiles -> Automatic, Mode -> "Update", References -> {}, Demos -> {}, Disclaimer -> {}, License -> "", Acknowledgments -> {}
例: `ClaudeUpdateDocumentation["claudecode","api.md のみ更新して"]`
例: `ClaudeUpdateDocumentation["pkg","...", TargetFiles -> {"api.md"}]`

## ディレクティブ管理

### ClaudeAddDirective[target, description] → Null
Claude で description を整形し、Claude Directives フォルダのファイルに追加して `InstallClaudeDirectives[]` を実行する。target は "CLAUDE.md" またはスキル名(例: "wolfram-general")。元ファイルは自動バックアップされる。

### ClaudeRestoreDirective[target] → Null
ClaudeAddDirective の直前のバックアップを復元し `InstallClaudeDirectives[]` を実行する。target は "CLAUDE.md" またはスキル名。

### ClaudeListDirectives[] → Null
Claude Directives フォルダの CLAUDE.md と全スキルの一覧を表示する。

### ClaudeUpdateDirective[] → Null
ソースコードと Claude Directives の整合性をチェックし、不整合を自動修正する。`ClaudeUpdateDirective[text]` は text の内容を Claude で解釈し CLAUDE.md / rules / skills の適切なファイルに反映する。ノートブックのコンテキストも参照可能。

### ClaudeDirectiveBackupDataset[] → Grid
Claude Directives の更新履歴を Review/Pull/Delete ボタン付き Grid で表示する。履歴は `ClaudeUpdateDirective[text]` や `ClaudeAddDirective` の実行時に自動保存される。

### ClaudeSyncDirectives[dir] → Null
指定ディレクトリ dir のファイルを Claude Directives フォルダと比較し、dir 側が新しいファイルで Claude Directives を更新する。dir にだけ存在するファイルもコピーする。Claude Directives 側にしかないファイルはそのまま。例: `ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]`

## コミット管理

### ClaudePrepareCommit[packageName, opts] → Null
前回の GitHub コミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを生成して `GitHubRefreshAndCommit` 実行コマンドを Input セルとして出力する。`ClaudePrepareCommit[packageName, subject]` は1行目を指定し、本文は自動収集。
Options: Fallback -> False, DryRun -> False, Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, BaseBranch -> Automatic

## Web ツール

### ClaudeWebSearch[query] → String
Web 検索を実行し、結果をテキストで返す。Anthropic API の web_search ツールを使用する。

### ClaudeWebFetch[url] → String
指定 URL の内容を取得し、要約・抽出して返す。`ClaudeWebFetch[url, prompt]` は取得内容に対して prompt の指示を実行する。

## アクセス管理・デバッグ

### ClaudeQueryShowContext[] → Null
デバッグ用: 次の ClaudeQuery が送信するノートブックコンテキストを表示する。

### ClaudeShowAccessConfig[] → Null
デバッグ用: Claude Code のファイルアクセス設定を表示する。$ClaudeAccessibleDirs・NBGetAccessibleDirs[]・生成される settings.json・CLI フラグを確認可能。

### ClaudeCheckSeparation[packageName] → Association
パッケージの分離検証を行い、結果を返す。$ClaudeTestModel を使用する。

### ClaudeFixSeparation[packageName] → Null
ClaudeCheckSeparation の結果に基づき、分離上の問題を自動修正する。

### ClaudeCommand[cmd] → String
任意の Claude Code CLI コマンドを実行し、出力を返す。

### ClaudeRateLimitStatus[] → Association | None
最後に検出された Claude CLI の rate-limit 情報を Association で返す。rate-limit になっていなければ None。
キー: "Detected"(検出時刻), "Source"("rate_limit_event"|"result"|"legacy"), "RateLimitType"("five_hour"|...), "ResetsAt"(復旧予定時刻), "ResetsAtUnix"(Unix timestamp), "HttpStatus"(429), "Message"(文字列), "IsUsingOverage"(Boolean)
例: `info = ClaudeRateLimitStatus[]; If[AssociationQ[info], If[info["ResetsAt"] > Now, Print["復旧まで待機: ", info["ResetsAt"]]]]`

### ClaudeRateLimitClear[] → Null
内部に保持された rate-limit 情報を手動でクリアする。誤検出や status=allowed の進捗通知によりブロックがかかってしまった際に使用する。

## パレット

### ShowClaudePalette[] → Null
Claude Code 操作用のパレットを表示する。

## 機密データ管理

### MarkConfidential[] → Null
現在のセルを機密マークする。`MarkConfidential[cell]` で指定セルを機密マークする。機密セルは ClaudeEval/ClaudeQuery のプロンプトから除外される。

### UnmarkConfidential[] → Null
現在のセルの機密マークを解除する。`UnmarkConfidential[cell]` で指定セルの機密マークを解除する。

### IsConfidential[cell] → Boolean
セルが機密マークされているかを返す。`IsConfidential[]` は現在のセルが機密かを返す。

### Confidential[expr] → expr の評価値
式を評価し、その Input/Output セルを自動的に機密マークする。例: `Confidential[secretData = Import["secret.csv"]]`

### NonConfidential[expr] → expr の評価値
式を評価し、その Input/Output セルの機密マークを明示的に解除する。機密変数や機密依存変数の値に依存していても機密解除として扱う。例: `result = NonConfidential[Mean[secretData]]`

### ScanConfidentialCells[] → Null
ノートブック全セルをスキャンし、機密変数を参照するセルを自動的に機密マークする。明示的に UnmarkConfidential されたセルはスキップされる。

## LLMグラフ

### NotebookLLMGraph[...] → Graph
ノートブックから LLM グラフを構築する。

### NotebookLLMGraphPlot[...] → Graphics
LLM グラフを可視化する。

### NotebookLLMGraphBuild[...] → Null
LLM グラフをビルドする。

### NotebookLLMGraphNodes[...] → List
LLM グラフのノード一覧を返す。

### NotebookLLMGraphValidate[...] → Null
LLM グラフを検証する。

### NotebookLLMGraphFetchResponse[...] → Null
LLM グラフのレスポンスを取得する。

### NotebookLLMGraphSubSteps[...] → List
LLM グラフのサブステップを返す。

### NotebookLLMGraphFetchL2[...] → Null
L2 レベルのレスポンスを取得する。

### NotebookLLMGraphErrors[...] → List
LLM グラフのエラー一覧を返す。

### NotebookLLMGraphUpdateL2Status[...] → Null
L2 ステータスを更新する。

### NotebookLLMGraphPlotL2[...] → Graphics
L2 グラフを可視化する。

### NotebookLLMGraphRerun[...] → Null
LLM グラフを再実行する。

### NotebookLLMGraphInvalidateDownstream[...] → Null
下流ノードを無効化する。

### NotebookLLMGraphSummary[...] → String
LLM グラフのサマリーを返す。

### NotebookLLMGraphExtractThread[...] → List
スレッドを抽出する。

### NotebookLLMGraphApplyThread[...] → Null
スレッドを適用する。

### LLMGraphExecute[...] → Null
LLM グラフを実行する。

### LLMGraphExecuteStatus[...] → Association
LLM グラフ実行のステータスを返す。

### LLMGraphExecuteCancel[...] → Null
LLM グラフ実行をキャンセルする。

## LLMグラフDAG

### LLMGraphDAGCreate[...] → DAGObject
LLM グラフ DAG を作成する。

### LLMGraphDAGStatus[...] → Association
DAG のステータスを返す。

### LLMGraphDAGCancel[...] → Null
DAG をキャンセルする。

### LLMGraphDAGStop[...] → Null
DAG を停止する。

### LLMGraphDAGRetry[...] → Null
DAG をリトライする。

### LLMGraphDAGRebuild[...] → Null
DAG を再構築する。

### LLMGraphDAGFindByContext[...] → DAGObject
コンテキストから DAG を検索する。

### LLMGraphDAGInspect[...] → Association
DAG を詳細検査する。

### LLMGraphDAGMarkFailed[...] → Null
DAG ノードを失敗としてマークする。

### LLMGraphDAGSnapshot[...] → Null
DAG のスナップショットを保存する。保存先: $ClaudeSnapshots。

### LLMGraphDAGRestore[...] → Null
DAG のスナップショットを復元する。

### LLMGraphDAGListSnapshots[...] → List
DAG のスナップショット一覧を返す。

### LLMGraphDAGPlot[...] → Graphics
DAG を可視化する。

### LLMGraphDAGMergeHistory[...] → Null
DAG の履歴をマージする。

## ランタイム

### ClaudeBuildRuntimeAdapter[...] → Adapter
Claude ランタイムアダプタを構築する。

### ClaudeStartRuntime[...] → RuntimeObject
Claude ランタイムを起動する。

### ClaudeEvalViaRuntime[...] → Null
ランタイム経由で ClaudeEval を実行する。

### ClaudeBuildTransactionAdapter[...] → Adapter
トランザクションアダプタを構築する。

### ClaudeUpdatePackageViaRuntime[...] → Null
ランタイム経由でパッケージを更新する。

### ClaudeApproveProposal[...] → Null
ランタイムの提案を承認する。

### ClaudeRuntimeSnapshot[...] → Null
ランタイムのスナップショットを保存する。

### ClaudeRuntimeRestore[...] → Null
ランタイムのスナップショットを復元する。

### ClaudeRuntimeListSnapshots[...] → List
ランタイムのスナップショット一覧を返す。

### ClaudeRegisterDAGRuntime[...] → Null
DAG ランタイムを登録する。

## ファイル処理・ユーティリティ

### NBFileTranslate[...] → Null
ノートブックファイルを翻訳する。

### ClaudeProcessFile[...] → Null
ファイルを Claude で処理する。

### cleanOutput[expr] → String
出力を整形・クリーンアップする。

### stripANSI[str] → String
文字列から ANSI エスケープシーケンスを除去する。