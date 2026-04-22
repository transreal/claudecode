# claudecode API Reference

ClaudeCode パッケージ — Mathematica から Claude Code CLI および Anthropic API を利用するためのインターフェース。

## グローバル変数

### $ClaudeModel
型: String, 初期値: ""
Claude CLI に渡すモデル名。"" は Claude Code 自身のデフォルトモデルを使用。例: $ClaudeModel = "claude-opus-4-6"

### $ClaudePrivateModel
型: List, 初期値: {{"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}}
秘密データ処理用ローカルモデル指定。AutoPrivate -> True 時に秘密変数を含むタスクの生成コードに使用。形式: {"provider", "modelName"} または {"provider", "modelName", "url"}

### $ClaudeDocModel
型: String, 初期値: Sonnet 系最新モデル
ドキュメント生成・更新時に使用するモデル。"" で $ClaudeModel と同じモデルを使用。例: $ClaudeDocModel = "claude-sonnet-4-6"

### $ClaudeTestModel
型: String, 初期値: $ClaudeModel
分離検証用モデル。ClaudeCheckSeparation で使用。

### $ClaudeTimeout
型: Integer, 初期値: 1200
ClaudeQuery/ClaudeEval 等のタイムアウト秒数。

### $ClaudeVerbose
型: Boolean, 初期値: False
True で履歴コンパクション等の詳細ログを Messages に出力。

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code を起動する作業ディレクトリ。このディレクトリ配下の .claude/CLAUDE.md, .claude/rules/, .claude/skills/ を Claude Code に読ませる。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索されるか手動で上書きできる。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。空の場合、CLAUDE.md が見つからなかったか内容がない。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。NotebookDirectory は初回使用時にダイアログで許可を確認($packageDirectory 配下を除く)。許可結果はノートブックの TaggingRules に永続化される。例: $ClaudeAccessibleDirs = {$packageDirectory, "C:\\Users\\...\\作業フォルダ"}

### $ClaudeFallbackModels
型: List, 初期値: {{"anthropic", "claude-opus-4-6"}, {"openai", "gpt-5"}}
フォールバックモデル優先順位。各要素は {"provider", "modelName"} または {"provider", "modelName", "url"}。内部的に NBAccess`NBSetFallbackModels に同期される。

### $ClaudeSnapshots
型: String, 初期値: $ClaudeWorkingDirectory/snapshots
LLMGraphDAG スナップショットの保存ディレクトリ。

### $ClaudeDocRetryDelay
型: Number, 初期値: 60
ドキュメント生成のリトライ待機秒数。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
ドキュメント生成の最大リトライ回数。

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースの最大文字数。

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
外部パッケージがキーワードを登録するための Association。プロンプトにキーワードが含まれると対応パッケージの api.md がコンテキストに自動注入される。各パッケージが自身のロード時に登録する。claudecode.wl 側はパッケージ非依存。例: $ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒切"}

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval が再帰的に ClaudeEval を生成する際の最大深度。0 で再帰禁止。大きくすると多段階の自動タスク連鎖が可能。

### $ClaudeEvalMode
型: String
ClaudeEval の動作モード。

### $ClaudeEvalAutoThreshold
型: Integer
ClaudeEval の自動 LLM 呼び出しのしきい値。

### $ClaudeEvalVerbose
型: Boolean, 初期値: False
ClaudeEval の詳細ログ出力フラグ。

### $ClaudeEvalAutoLLMMinLength
型: Integer
自動 LLM 呼び出しの最小テキスト長。

### $ClaudeEvalAutoLLMMinNewlines
型: Integer
自動 LLM 呼び出しの最小改行数。

### $claudecodeVersion
型: String
claudecode パッケージのバージョン文字列。

### $LLMGraphMaxConcurrency
型: Integer
LLMGraph の最大並列実行数。

### $LLMGraphAutoStopThreshold
型: Integer
LLMGraph の自動停止しきい値。

### $UseClaudeRuntime
型: Boolean, 初期値: False
True で ClaudeRuntime 経由で ClaudeEval を実行する。

### $ClaudeLastRuntimeId
型: String
最後に使用した ClaudeRuntime の ID。

### $ClaudeRoutingProviders
型: List
ルーティングプロバイダのリスト。

## クエリ・評価

### ClaudeQuery[prompt] → String
Claude Code に prompt を送り、応答文字列を返す（同期）。セッション履歴やノートブック書き込みを行う通常版。
ClaudeQuery[session, prompt] でセッション履歴と直前の出力/エラーを考慮して回答。
ClaudeQuery[{text, Image[...], File[path], ...}] でマルチモーダル入力。画像/PDF/音声を API に直接送信。
Options: WebSearch -> True (デフォルト,無料), WebFetch -> False (課金あり,Fallback->True 必須), Fallback -> False, Timeout -> Automatic

### ClaudeQuerySync[prompt, opts] → String
Claude に prompt を送り、応答文字列を同期的に返す。セッション履歴やノートブック書き込みは行わない軽量版。WindowStatusArea に経過時間を表示する。
モデルルーティング: Model -> Automatic かつ PrivacyLevel <= 0.5 → Claude Code CLI、PrivacyLevel > 0.5 → $ClaudePrivateModel を自動使用。
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic
例: ClaudeQuerySync[prompt, Model -> {"anthropic", "claude-sonnet-4-6"}]

### ClaudeQueryBg[prompt, opts] → String
FrontEnd 操作・ScheduledTask 生成なしで Claude に同期問い合わせし、応答文字列を返す。SocketListen ハンドラ・ScheduledTask コールバック等の非同期コンテキストから安全に呼び出せる (URLRead 相当の安全な代替手段)。
Options: Fallback -> False, Model -> Automatic, Timeout -> Automatic

### ClaudeQueryAsync[prompt, callback, nb, opts]
Claude に非同期で問い合わせ、完了時に callback[応答文字列] を呼ぶ。nb は出力先 NotebookObject。カーネルをブロックしない。WindowStatusArea に経過時間を表示。
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic

### ClaudeWriteResponse[nb, text, opts]
マークダウン形式のテキストをノートブックのセルとして展開する。見出し・リスト・コードブロック等を適切なセルスタイルに変換する。ClaudeQuerySync で取得した応答をノートブックに出力する際に使用する。
Options: AutoEvaluate -> False
例: ClaudeWriteResponse[EvaluationNotebook[], response, AutoEvaluate -> True]

### ClaudeMath[task] → String
Mathematica コード生成に特化したプロンプトで Claude を呼び出す。

### ClaudeExtractCode[response] → String
Claude の応答から最初の ```mathematica ブロックを抽出する。

### ClaudeExtractAllCode[response] → List
Claude の応答から全 ```mathematica ブロックをリストで返す。

### ClaudeEval[task, opts]
コードを非同期で生成・表示し、デフォルトセッションに履歴を保存する。
ClaudeEval[{text, data, ...}] でテキスト、Dataset、Image、一般式を混在できる。
ClaudeEval[session, task] で指定セッションに履歴を保存する。
Options: AutoEvaluate -> True (生成 Input セルの自動実行), StartTime -> Now (実行開始時刻), RepeatInterval -> None (繰り返し実行。例: RepeatInterval -> Quantity[2, "Hours"]、最大回数付き: RepeatInterval -> {Quantity[1,"Hours"], 5}), Timeout -> Automatic ($iFallbackTimeout=600秒), Fallback -> False, WebFetch -> Automatic
RepeatInterval 指定時は TaskObject を返す。TaskRemove[] で停止可能。

### ContinueEval[session, instruction, opts]
指定セッションで継続する。ContinueEval[instruction] はデフォルトセッションで継続。ContinueEval[] は "エラーを修正してください" でデフォルトセッションを継続。
Options: StartTime -> Now, Timeout -> Automatic, Fallback -> False

### ContinueUpdate[opts]
直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を継続する。
ContinueUpdate["instruction"] で追加指示を付けて継続。
ContinueUpdate[{"instruction", img}] でテキスト+画像で継続。
ContinueUpdate["pkgName", "instruction"] で指定パッケージの直前の更新を継続。
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now

### ClaudeSpec[task]
ノートブック内容からプログラムの仕様を生成する。ClaudeSpec[{task, image, ...}] で画像付きで仕様を生成。パレットからはセル選択で呼び出し可能。

### ClaudeDebug[codeOrFile, errorMsg]
デバッグ支援を非同期で求める（即座に返る）。

### ClaudeReview[codeOrFile]
コードのレビューを非同期で行う（30000文字超は自動チャンク分割）。

### ClaudeReviewChunked[codeOrFile]
ファイルをチャンク分割して非同期レビューする。

## パッケージ操作

### ClaudeCreatePackage[name, prompt]
prompt に従って name.wl を新規作成し $packageDirectory に保存する。

### ClaudeUpdatePackage[packageName, prompt, opts]
$packageDirectory にある packageName.wl を Claude の支援でアップデートし、バックアップを作成する。prompt には文字列またはリスト {文字列, Image, File[".../file.pdf"], ...} を指定可能。
Options: TargetFunctions -> Automatic, StartTime -> Now, Fallback -> False, "UpdateApiMd" -> Automatic
"UpdateApiMd" -> False で api.md の自動更新をスキップ。
例: ClaudeUpdatePackage["pkg", "修正指示", StartTime -> Now + Quantity[1, "Hours"]]

### ClaudeRestorePackage[packageName]
直前のバックアップを復元する。

### ClaudeConvertToPaclet[packageName]
$packageDirectory の packageName.wl を Paclet 形式に変換する。packageName/ フォルダを作成し、Kernel/, Documentation/, PacletInfo.wl 等を生成する。元の .wl ファイルはバックアップ後に削除される。

### ClaudeUpdatePackageHistory[] → List
全パッケージの ClaudeUpdatePackage 呼び出し履歴を表示しリストで返す。
ClaudeUpdatePackageHistory[packageName] で指定パッケージの更新履歴を表示しリストで返す。各エントリは <|"Package"->…, "Timestamp"->…, "Directory"->…|> の Association。

### ClaudeBackupDataset[packageName]
指定パッケージのバックアップ履歴を Review/Pull/Delete ボタン付き Grid で表示する。ClaudeBackupDataset[] で全パッケージのバックアップ履歴を表示する。

### ClaudeMigrateBackupHistory[packageName, opts]
既存の history 内の生 .wl バックアップを差分形式 (.wl.cz / .wl.cdiff) に変換して容量を削減する。ClaudeMigrateBackupHistory[] で全パッケージに対して実行する。
Options: DryRun -> False (True で削除せず容量削減見積もりを表示)

### ClaudeApproveProposal[]
ClaudeUpdatePackage 等が生成した変更提案を承認して適用する。

## ドキュメント生成

### ClaudeCreateDocumentation["packageName", opts]
パッケージの詳細なドキュメント一式を Claude で自動生成する。$packageDirectory 内の packageName.wl または packageName/ Paclet を対象とする。単一 .wl: $packageDirectory/packageName_info/docs/ に出力。Paclet: $packageDirectory/packageName/docs/ に出力。リミット到達時に自動停止し、再実行で未生成分のみ続行する。README.md は最後に生成される。
Options: References -> {}, Demos -> {}, Disclaimer -> {}, License -> "", Acknowledgments -> {}

### ClaudeUpdateDocumentation["packageName", opts]
ソース差分に基づき全ドキュメントを自動更新する。ClaudeUpdateDocumentation["packageName", "更新指示"] で指示に従ってドキュメントを更新する。ノートブックのコンテキストも参照可能（"上で議論されている内容を反映して" など）。
Options: TargetFiles -> Automatic ({"api.md"} 等でファイル指定可), Mode -> "Update" ("Create" で新規作成)
例: ClaudeUpdateDocumentation["claudecode", "api.mdのみ更新して", TargetFiles -> {"api.md"}]

### References
型: Option (ClaudeCreateDocumentation/ClaudeUpdateDocumentation)
URL や書籍名のリストを指定すると README.md に参考文献セクションを追加する。例: References -> {"https://...", "書籍名"}

### Demos
型: Option (ClaudeCreateDocumentation/ClaudeUpdateDocumentation)
デモ動画や使用例の URL リストを指定すると README.md に反映する。例: Demos -> {"https://youtu.be/...", "https://example.com/demo.nb"}

### Disclaimer
型: Option (ClaudeCreateDocumentation/ClaudeUpdateDocumentation)
免責事項セクションに追加する文言のリストを指定する。例: Disclaimer -> {"本ツールは研究目的専用です"}

### License
型: Option (ClaudeCreateDocumentation/ClaudeUpdateDocumentation)
空文字列（デフォルト）: GitHubREST`$GitHubLicenseHolder が非空なら MIT ライセンスを自動挿入。文字列指定: そのままライセンステキストとして挿入。例: License -> "MIT"

### Acknowledgments
型: Option (ClaudeCreateDocumentation/ClaudeUpdateDocumentation)
謝辞セクションに追加する文言のリストを指定する。指定時は README.md の免責事項の前に配置。例: Acknowledgments -> {"本研究は JSPS 科研費の助成を受けた"}

## ディレクティブ管理

### ClaudeAddDirective[target, description]
Claude で description を整形し、Claude Directives フォルダのファイルに追加して InstallClaudeDirectives[] を実行する。target は "CLAUDE.md" またはスキル名（例: "wolfram-general"）。元ファイルは自動バックアップされる。

### ClaudeRestoreDirective[target]
ClaudeAddDirective の直前のバックアップを復元し InstallClaudeDirectives[] を実行する。target は "CLAUDE.md" またはスキル名。

### ClaudeListDirectives[]
Claude Directives フォルダの CLAUDE.md と全スキルの一覧を表示する。

### ClaudeUpdateDirective[text]
ClaudeUpdateDirective[] はソースコードと Claude Directives の整合性をチェックし、不整合を自動修正する。ClaudeUpdateDirective[text] で text の内容を Claude で解釈し、CLAUDE.md / rules / skills の適切なファイルに反映する。ノートブックのコンテキストも参照可能。

### ClaudeDirectiveBackupDataset[]
Claude Directives の更新履歴を Review/Pull/Delete ボタン付き Grid で表示する。履歴は ClaudeUpdateDirective/ClaudeAddDirective の実行時に自動保存される。

### ClaudeSyncDirectives[dir]
指定ディレクトリ dir のファイルを Claude Directives フォルダと比較し、dir 側が新しいファイルで Claude Directives を更新する。dir にだけ存在するファイルもコピーする。Claude Directives 側にしかないファイルはそのまま。例: ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]

## セッション管理

### CreateClaudeSession["name"] → session
名前付きセッションを作成する（デフォルト履歴を継承）。
CreateClaudeSession[session] で既存セッションの履歴を継承した新セッションを作成。
CreateClaudeSession[] でデフォルト履歴を継承した新セッションを作成。
CreateClaudeSession[Inherit -> False] で独立したセッションを作成。

### ClaudeRestoreSession[]
デフォルトセッションをリストアする。ClaudeRestoreSession["name"] で指定名のセッションをリストアする。

### ClaudeListSessions[]
ノートブック内の全セッションを一覧表示する。

### ClaudeDeleteSession["name"]
指定名のセッションを削除する。ClaudeDeleteSession["name", "All"] でセッションとその全履歴を削除する。

### ClaudeShowHistory[]
デフォルトセッションの履歴を表示する。ClaudeShowHistory[session] で指定セッションの履歴を表示。ClaudeShowHistory["name"] で指定名のセッションの履歴を表示。

### ClaudeSessionStatus[]
デフォルトセッションの状態を表示する。ClaudeSessionStatus[name] で指定名のセッションの状態を表示。アクセス可能ディレクトリ、アタッチメント、作業ディレクトリのファイル等を確認可能。

### ClaudeCompactHistory[]
デフォルトセッションの履歴をコンパクション（圧縮）する。

### ClaudeHistorySize[] → Integer
デフォルトセッションの履歴サイズを返す。

## 添付ファイル

### ClaudeAttach[path, opts]
デフォルトセッションに参照資料をアタッチする。ClaudeAttach[url] で URL のページを PDF 化してキャッシュしアタッチする。ClaudeAttach[session, path] で指定セッションにアタッチする。アタッチされたファイルは ClaudeQuery/ClaudeEval 時に自動的に Read される。
Options: Keywords -> {}, Title -> None, Refetch -> False
Keywords で登録するとプロンプト中のキーワードに応じて自動注入される。

### ClaudeDetach[path]
デフォルトセッションからファイルをデタッチする。ClaudeDetach[session, path] で指定セッションからデタッチする。

### ClaudeAttachments[] → List
デフォルトセッションのアタッチメント一覧を返す。ClaudeAttachments[session] で指定セッションのアタッチメント一覧を返す。

### ClearAttachments[]
デフォルトセッションの全アタッチメントをクリアする。ClearAttachments[session] で指定セッションの全アタッチメントをクリアする。

## 機密データ

### MarkConfidential[]
現在のセルを機密マークする。MarkConfidential[cell] で指定セルを機密マークする。機密セルは ClaudeEval/ClaudeQuery のプロンプトから除外される。

### UnmarkConfidential[]
現在のセルの機密マークを解除する。UnmarkConfidential[cell] で指定セルの機密マークを解除する。

### IsConfidential[cell] → Boolean
セルが機密マークされているかを返す。IsConfidential[] で現在のセルが機密かを返す。

### Confidential[expr] → expr の評価結果
式を評価し、その Input/Output セルを自動的に機密マークする。例: Confidential[secretData = Import["secret.csv"]]

### NonConfidential[expr] → expr の評価結果
式を評価し、その Input/Output セルの機密マークを明示的に解除する。秘密変数や秘密依存変数の値に依存していても機密解除として扱う。例: result = NonConfidential[Mean[secretData]]

### ScanConfidentialCells[]
ノートブック全セルをスキャンし、機密変数を参照するセルを自動的に機密マークする。明示的に UnmarkConfidential されたセルはスキップされる。

## Web 検索・フェッチ

### ClaudeWebSearch[query] → String
Web 検索を実行し、結果をテキストで返す。Anthropic API の web_search ツールを使用する。

### ClaudeWebFetch[url] → String
指定 URL の内容を取得し、要約・抽出して返す。ClaudeWebFetch[url, prompt] で取得内容に対して prompt の指示を実行する。

### WebFetch
型: Option (ClaudeQuery/ClaudeEval)
True: 必ず Web フェッチを行う。False: Web フェッチを行わない。Automatic (ClaudeEval のデフォルト): Claude がタスクを分析し必要なら自動で Web フェッチする。ClaudeQuery のデフォルトは False。Anthropic API 経由で課金が発生するため Fallback -> True の場合のみ利用可能。

### WebSearch
型: Option (ClaudeQuery/ClaudeEval)
True (デフォルト,無料) / False。Claude Code CLI の Web 検索ツール許可フラグ。

## ステータス・制御

### ClaudeStatus[]
現在実行中の全 Claude タスクのリアルタイム状態を表示する。各タスクの経過時間、現在の状態（思考中/テキスト生成中/ツール実行中）、生成済みテキスト断片数、思考断片数、ツール使用数を表示する。実行中のタスクがない場合はその旨を表示する。

### ClaudeAbort[]
実行中の全 Claude タスクを停止する。Claude Code プロセスの強制終了、ScheduledTask の停止、フォールバックタスクのキャンセルを行う。パレットの「実行停止」ボタンからも呼び出し可能。

### ClaudeRateLimitStatus[] → Association | None
最後に検出された Claude CLI の rate-limit 情報を Association で返す。rate-limit になっていなければ None。
返り値のキー: "Detected" (DateObject), "Source", "RateLimitType", "ResetsAt" (DateObject), "ResetsAtUnix", "HttpStatus", "Message", "IsUsingOverage"
例: If[AssociationQ[info = ClaudeRateLimitStatus[]], If[info["ResetsAt"] > Now, Print["復旧まで待機: ", info["ResetsAt"]]]]

### ShowClaudePalette[]
Claude Code 操作用のパレットを表示する。

### ClaudeQueryShowContext[]
デバッグ用: 次の ClaudeQuery が送信するノートブックコンテキストを表示する。

### ClaudeShowAccessConfig[]
デバッグ用: Claude Code のファイルアクセス設定を表示する。$ClaudeAccessibleDirs, NBGetAccessibleDirs[], 生成される settings.json, CLI フラグを確認可能。

### ClaudeCommand["command"]
Claude Code CLI のスラッシュコマンドを実行する。例: ClaudeCommand["/help"]

### ClaudeCheckSeparation["packageName"]
NBAccess 分離原則の検証を実行する。結果は $iSeparationCheckCache にキャッシュされ ClaudeFixSeparation で再利用される。

### ClaudeFixSeparation["packageName"]
NBAccess 分離原則の違反を自動修正する。ClaudeCheckSeparation のキャッシュ結果を再利用する。

## コミット準備

### ClaudePrepareCommit[packageName, opts]
前回の GitHub コミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを生成して GitHubRefreshAndCommit 実行コマンドを Input セルとして出力する。ClaudePrepareCommit[packageName, subject] で1行目を指定し本文は自動収集する。
Options: Fallback -> False, DryRun -> False, Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, BaseBranch -> Automatic
DryRun -> True でコマンドを生成せずメッセージのみ返す。

## ファイル変換・処理

### NBFileTranslate[...]
ノートブックファイルの変換処理を行う。

### ClaudeProcessFile[...]
ファイルを Claude で処理する。

## LLMGraph (ノートブックベース)

### NotebookLLMGraph[...]
ノートブックベースの LLM グラフを操作する。

### NotebookLLMGraphPlot[...]
LLM グラフをプロットする。

### NotebookLLMGraphBuild[...]
LLM グラフを構築する。

### NotebookLLMGraphNodes[...] → List
LLM グラフのノード一覧を返す。

### NotebookLLMGraphValidate[...]
LLM グラフを検証する。

### NotebookLLMGraphFetchResponse[...]
LLM グラフのレスポンスを取得する。

### NotebookLLMGraphSubSteps[...]
LLM グラフのサブステップを処理する。

### NotebookLLMGraphFetchL2[...]
LLM グラフの L2 レスポンスを取得する。

### NotebookLLMGraphErrors[...] → List
LLM グラフのエラー一覧を返す。

### NotebookLLMGraphUpdateL2Status[...]
LLM グラフの L2 ステータスを更新する。

### NotebookLLMGraphPlotL2[...]
LLM グラフの L2 をプロットする。

### NotebookLLMGraphRerun[...]
LLM グラフを再実行する。

### NotebookLLMGraphInvalidateDownstream[...]
LLM グラフの下流ノードを無効化する。

### NotebookLLMGraphSummary[...] → Association
LLM グラフのサマリーを返す。

### NotebookLLMGraphExtractThread[...]
LLM グラフからスレッドを抽出する。

### NotebookLLMGraphApplyThread[...]
LLM グラフにスレッドを適用する。

## LLMGraph (DAG 実行エンジン)

### LLMGraphExecute[...]
LLM グラフを実行する。

### LLMGraphExecuteStatus[...] → Association
LLM グラフの実行ステータスを返す。

### LLMGraphExecuteCancel[...]
LLM グラフの実行をキャンセルする。

### LLMGraphDAGCreate[...] → dag
DAG を作成する。

### LLMGraphDAGStatus[dag] → Association
DAG の実行ステータスを返す。

### LLMGraphDAGCancel[dag]
DAG の実行をキャンセルする。

### LLMGraphDAGStop[dag]
DAG の実行を停止する。

### LLMGraphDAGRetry[dag]
DAG の失敗ノードをリトライする。

### LLMGraphDAGRebuild[dag]
DAG を再構築する。

### LLMGraphDAGFindByContext[...] → dag
コンテキストで DAG を検索する。

### LLMGraphDAGInspect[dag]
DAG の詳細を表示する。

### LLMGraphDAGMarkFailed[dag, nodeId]
DAG のノードを失敗としてマークする。

### LLMGraphDAGSnapshot[dag, name]
DAG のスナップショットを保存する。保存先は $ClaudeSnapshots。

### LLMGraphDAGRestore[name] → dag
スナップショットから DAG を復元する。

### LLMGraphDAGListSnapshots[] → List
DAG スナップショットの一覧を返す。

### LLMGraphDAGPlot[dag]
DAG をプロットする。

### LLMGraphDAGMergeHistory[...]
DAG の履歴をマージする。

## ClaudeRuntime

### ClaudeBuildRuntimeAdapter[...]
ClaudeRuntime アダプターを構築する。

### ClaudeStartRuntime[...]
ClaudeRuntime を起動する。

### ClaudeEvalViaRuntime[...]
ClaudeRuntime 経由で ClaudeEval を実行する。

### ClaudeBuildTransactionAdapter[...]
トランザクションアダプターを構築する。

### ClaudeUpdatePackageViaRuntime[...]
ClaudeRuntime 経由でパッケージを更新する。

### ClaudeRuntimeSnapshot[...]
ClaudeRuntime のスナップショットを保存する。

### ClaudeRuntimeRestore[...]
ClaudeRuntime のスナップショットを復元する。

### ClaudeRuntimeListSnapshots[] → List
ClaudeRuntime のスナップショット一覧を返す。

### ClaudeRegisterDAGRuntime[...]
DAG ランタイムを登録する。

## ユーティリティ

### cleanOutput[text] → String
出力テキストをクリーンアップする。

### stripANSI[text] → String
テキストから ANSI エスケープコードを除去する。

## オプションシンボル

### Fallback
型: Option (ClaudeQuery/ClaudeEval/ContinueEval/ClaudeUpdatePackage)
True: Claude Code 利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。False (デフォルト): エラーをそのまま返す。

### AutoPrivate
型: Option (ClaudeQuery/ClaudeEval/ContinueEval)
True: 秘密変数にアクセスするタスクの場合、生成コードに Model -> $ClaudePrivateModel, PrivacySpec -> Automatic を付与する。False (デフォルト): 通常動作。

### AutoEvaluate
型: Option (ClaudeEval/ClaudeWriteResponse)
True (ClaudeEval デフォルト): 生成された Input セルを自動実行。False: 自動実行しない。

### StartTime
型: Option (ClaudeEval/ContinueEval/ClaudeUpdatePackage/ContinueUpdate)
実行開始時刻を DateObject で指定。例: StartTime -> Now + Quantity[3, "Hours"]

### Timeout
型: Option (ClaudeQuery/ClaudeEval/ContinueEval/ClaudeQuerySync/ClaudeQueryBg)
API フォールバックのタイムアウト秒数。Automatic は $iFallbackTimeout (600秒)。

### TargetFiles
型: Option (ClaudeUpdateDocumentation)
更新対象ファイルの指定。Automatic で自動判定、{"api.md"} 等でファイル指定。

### TargetFunctions
型: Option (ClaudeUpdatePackage)
更新対象関数の指定。Automatic で自動判定。

### Mode
型: Option (ClaudeUpdateDocumentation)
"Update" (既存更新, デフォルト) または "Create" (新規作成)。

### DryRun
型: Option (ClaudePrepareCommit/ClaudeMigrateBackupHistory)
True でコマンドを生成せず見積もりやメッセージのみ返す。False (デフォルト)。

### RepeatInterval
型: Option (ClaudeEval)
繰り返し実行の間隔。None (デフォルト)。例: RepeatInterval -> Quantity[2, "Hours"]、最大回数付き: RepeatInterval -> {Quantity[1,"Hours"], 5}

### Keywords
型: Option (ClaudeAttach)
アタッチメントのキーワードリスト。{}(デフォルト)。プロンプト中のキーワードに応じて自動注入される。

### Title
型: Option (ClaudeAttach)
アタッチメントのタイトル。None (デフォルト) でファイル名を使用。

### Refetch
型: Option (ClaudeAttach)
True でキャッシュを無視して再取得する。False (デフォルト)。

### Owner
型: Option (ClaudePrepareCommit)
GitHub リポジトリのオーナー名。Automatic (デフォルト) で自動検出。

### Repository
型: Option (ClaudePrepareCommit)
GitHub リポジトリ名。Automatic (デフォルト) で自動検出。

### Branch
型: Option (ClaudePrepareCommit)
コミット先ブランチ名。Automatic (デフォルト) で自動検出。

### BaseBranch
型: Option (ClaudePrepareCommit)
ベースブランチ名。Automatic (デフォルト) で自動検出。

### Inherit
型: Option (CreateClaudeSession)
False で独立したセッションを作成。デフォルトは True (デフォルト履歴を継承)。

### PrivacySpec
型: Option (ClaudeQuerySync)
プライバシー仕様。Automatic で自動判定。