# ClaudeCode API Reference

ClaudeCode`パッケージ — Mathematica から Claude Code CLI および Anthropic API を呼び出すための統合インターフェース。依存パッケージ: NBAccess ([https://github.com/transreal/NBAccess](https://github.com/transreal/NBAccess)), GitHubREST ([https://github.com/transreal/github](https://github.com/transreal/github))。

## クエリ・応答

### ClaudeQuery[prompt] / ClaudeQuery[session, prompt]
Claudeにpromptを送り、応答文字列を返す（同期）。session指定時はそのセッション履歴と直前の出力/エラーを考慮して回答する。マルチモーダル入力: ClaudeQuery[{text, Image[...], File[path], ...}] で画像/PDF/音声をAPI直接送信。
→ String
Options: WebSearch -> True (Claude Code CLI組み込みWeb検索許可、課金なし), WebFetch -> False (Anthropic API経由のURL取得、課金あり、Fallback->True必須), Fallback -> False, Timeout -> Automatic (秒)
### ClaudeQuerySync[prompt]
Claudeにpromptを送り、応答文字列を同期的に返す。WindowStatusAreaに経過時間を表示。セッション履歴やノートブック書き込みは行わない軽量版。モデルルーティング: Model->Automatic かつ PrivacyLevel<=0.5 → Claude Code CLI、PrivacyLevel>0.5 → $ClaudePrivateModel自動使用。
→ String
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic
例: ClaudeQuerySync[prompt, Model -> {"anthropic", "claude-sonnet-4-6"}]
### ClaudeQueryAsync[prompt, callback, nb]
Claudeに非同期で問い合わせ、完了時にcallback[応答文字列]を呼ぶ。カーネルをブロックしない。nbは出力先NotebookObject。
→ Null
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic
例: ClaudeQueryAsync["Hello", Print, EvaluationNotebook[]]
### ClaudeWriteResponse[nb, text]
マークダウン形式のtextをノートブックnbのセルとして展開する。見出し・リスト・コードブロック等を適切なセルスタイルに変換する。ClaudeQuerySyncで取得した応答をノートブックに出力する際に使用する。
→ Null
Options: AutoEvaluate -> False
### ClaudeMath[task] → String
Mathematicaコード生成に特化したプロンプトでClaudeを呼び出す。
### ClaudeExtractCode[response] → String
Claudeの応答から最初の ```mathematica ブロックを抽出する。
### ClaudeExtractAllCode[response] → List
Claudeの応答から全 ```mathematica ブロックをリストで返す。
### ClaudeSpec["task"] / ClaudeSpec[{"task", image, ...}]
ノートブック内容からプログラムの仕様を生成する。画像付きで仕様生成も可能。パレットからはセル選択で呼び出し可能。

## 評価・コード生成

### ClaudeEval[task] / ClaudeEval[session, task]
コードを非同期で生成・表示し、デフォルト（またはsession）セッションに履歴を保存する。taskにはテキスト、Dataset、Image、一般式を混在できる。
→ TaskObject (RepeatInterval指定時)
Options: AutoEvaluate -> True (生成Inputセルの自動実行), StartTime -> Now, RepeatInterval -> None, Timeout -> Automatic, Fallback -> False
例: ClaudeEval["..."] — RepeatInterval -> {Quantity[1,"Hours"], 5} で1時間ごとに最大5回実行
### ContinueEval[] / ContinueEval[instruction] / ContinueEval[session, instruction]
前のClaudeEvalを継続する。ContinueEval[]は「エラーを修正してください」で継続。
→ Null
Options: StartTime -> Now, Timeout -> Automatic, Fallback -> False
### ContinueUpdate[] / ContinueUpdate["instruction"] / ContinueUpdate["pkgName", "instruction"]
直前のClaudeUpdatePackageの結果を踏まえてバグ修正を継続する。
→ Null
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now
例: ContinueUpdate["上半円の境界線が欠けているので修正して"]
### ClaudeDebug[codeOrFile, errorMsg]
デバッグ支援を非同期で求める（即座に返る）。
### ClaudeReview[codeOrFile]
コードのレビューを非同期で行う（30000文字超は自動チャンク分割）。
### ClaudeReviewChunked[codeOrFile]
ファイルをチャンク分割して非同期レビューする。

## セッション管理

### CreateClaudeSession["name"] / CreateClaudeSession[session] / CreateClaudeSession[]
名前付きセッションを作成する（デフォルト履歴を継承）。Inherit->Falseで独立したセッションを作成。
Options: Inherit -> True
### ClaudeRestoreSession[] / ClaudeRestoreSession["name"]
デフォルトまたは指定名のセッションをリストアする。
### ClaudeListSessions[] → Dataset
ノートブック内の全セッションを一覧表示する。
### ClaudeDeleteSession["name"] / ClaudeDeleteSession["name", "All"]
指定名のセッションを削除する。"All"指定でセッションと全履歴を削除。
### ClaudeShowHistory[] / ClaudeShowHistory[session] / ClaudeShowHistory["name"]
デフォルト・指定セッション・指定名のセッション履歴を表示する。
### ClaudeSessionStatus[] / ClaudeSessionStatus[name]
デフォルトまたは指定名のセッションの状態を表示する。アクセス可能ディレクトリ、アタッチメント、作業ディレクトリのファイル等を確認可能。
### ClaudeCompactHistory[] / ClaudeCompactHistory[name]
デフォルトまたは指定セッションの履歴を手動でコンパクションする。通常は2n+1+wエントリを超えたときに自動実行される。
### ClaudeHistorySize[] → Association
現在のノートブックのセッション履歴サイズを診断する。Entries・ByteCount・KiloBytes・Statusを含むAssociationを返す。200KB超でコンパクション推奨、500KB超で危険。

## アタッチメント

### ClaudeAttach[path] / ClaudeAttach[session, path]
デフォルトまたは指定セッションに参照資料をアタッチする。アタッチされたファイルはClaudeQuery/ClaudeEval時に自動的にReadされる。
### ClaudeDetach[path] / ClaudeDetach[session, path]
デフォルトまたは指定セッションからファイルをデタッチする。
### ClaudeAttachments[] / ClaudeAttachments[session] → List
デフォルトまたは指定セッションのアタッチメント一覧を返す。
### ClearAttachments[] / ClearAttachments[session]
デフォルトまたは指定セッションの全アタッチメントをクリアする。

## パッケージ操作

### ClaudeCreatePackage[name, prompt]
promptに従ってname.wlを新規作成し$packageDirectoryに保存する。
### ClaudeUpdatePackage[packageName, prompt]
$packageDirectoryにあるpackageName.wlをClaudeの支援でアップデートし、バックアップを作成する。promptには文字列またはリスト {文字列, Image, File[".../file.pdf"], ...} を指定可能。
→ Null
Options: TargetFunctions -> Automatic, StartTime -> Now, Fallback -> False, "UpdateApiMd" -> Automatic ("UpdateApiMd"->Falseでapi.mdの自動更新をスキップ)
例: ClaudeUpdatePackage["pkg", "修正指示", StartTime -> Now + Quantity[1, "Hours"]]
### ClaudeRestorePackage[packageName]
直前のバックアップを復元する。
### ClaudeConvertToPaclet[packageName]
$packageDirectoryのpackageName.wlをPaclet形式に変換する。packageName/フォルダを作成し、Kernel/, Documentation/, PacletInfo.wl等を生成する。元の.wlファイルはバックアップ後に削除される。
### ClaudeUpdatePackageHistory[] / ClaudeUpdatePackageHistory[packageName] → List
全パッケージまたは指定パッケージのClaudeUpdatePackage呼び出し履歴を表示しリストで返す。各エントリは <|"Package"->…, "Timestamp"->…, "Directory"->…|>。
### ClaudeBackupDataset[] / ClaudeBackupDataset[packageName]
全パッケージまたは指定パッケージのバックアップ履歴をReview/Pull/DeleteボタンつきGridで表示する。ReviewはバックアップNの内容を確認、Pullは復元、Deleteはその履歴を削除。
### ClaudeMigrateBackupHistory[packageName] / ClaudeMigrateBackupHistory[]
既存のhistory内の生.wlバックアップを差分形式(.wl.cz / .wl.cdiff)に変換して容量を削減する。
→ Null
Options: DryRun -> False (True: 削除せず容量削減の見積もりを表示)

## ドキュメント生成

### ClaudeCreateDocumentation["packageName"]
パッケージの詳細なドキュメント一式をClaudeで自動生成する。単一.wl: $packageDirectory/packageName_info/docs/ に出力。Paclet: $packageDirectory/packageName/docs/ に出力。
Options: References -> {} (URLや書籍名リスト→README.mdに参考文献追加), Demos -> {} (デモURLリスト→README.mdに反映), Disclaimer -> {} (免責事項文言リスト), License -> "" (空文字列: $GitHubLicenseHolder非空ならMIT自動挿入, 文字列指定: そのまま挿入), Acknowledgments -> {} (謝辞文言リスト、免責事項の前に配置)
### ClaudeUpdateDocumentation["packageName"] / ClaudeUpdateDocumentation["packageName", "更新指示"]
ソース差分に基づき全ドキュメントを自動更新する。更新指示を指定した場合はその指示に従って更新する。ノートブックのコンテキストも参照可能。
Options: TargetFiles -> Automatic (自動判定、{"api.md"}等でファイル指定可), Mode -> "Update" ("Create"で新規作成)
例: ClaudeUpdateDocumentation["claudecode", "api.mdのみ更新して", TargetFiles -> {"api.md"}]

## ディレクティブ管理

### ClaudeAddDirective[target, description]
Claudeでdescriptionを整形し、Claude Directivesフォルダのファイルに追加してInstallClaudeDirectives[]を実行する。targetは"CLAUDE.md"またはスキル名（例: "wolfram-general"）。元ファイルは自動バックアップされる。
### ClaudeRestoreDirective[target]
ClaudeAddDirectiveの直前のバックアップを復元しInstallClaudeDirectives[]を実行する。targetは"CLAUDE.md"またはスキル名。
### ClaudeListDirectives[]
Claude DirectivesフォルダのCLAUDE.mdと全スキルの一覧を表示する。
### ClaudeUpdateDirective[] / ClaudeUpdateDirective[text]
ClaudeUpdateDirective[]はソースコードとClaude Directivesの整合性をチェックし不整合を自動修正する。ClaudeUpdateDirective[text]はtextの内容をClaudeで解釈しCLAUDE.md / rules / skillsの適切なファイルに反映する。ノートブックのコンテキストも参照可能。
### ClaudeDirectiveBackupDataset[]
Claude Directivesの更新履歴をReview/Pull/DeleteボタンつきGridで表示する。履歴はClaudeUpdateDirective[text]やClaudeAddDirective実行時に自動保存される。
### ClaudeSyncDirectives[dir]
指定ディレクトリdirのファイルをClaude Directivesフォルダと比較し、dir側が新しいファイルでClaude Directivesを更新する。dirにだけ存在するファイルもコピーする。Claude Directives側にしかないファイルはそのまま。
例: ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]

## 機密データ

### MarkConfidential[] / MarkConfidential[cell]
現在または指定セルを機密マークする。機密セルはClaudeEval/ClaudeQueryのプロンプトから除外される。
### UnmarkConfidential[] / UnmarkConfidential[cell]
現在または指定セルの機密マークを解除する。
### IsConfidential[] / IsConfidential[cell] → Boolean
現在または指定セルが機密マークされているかを返す。
### Confidential[expr]
式を評価し、そのInput/OutputセルをAutoで機密マークする。
例: Confidential[secretData = Import["secret.csv"]]
### NonConfidential[expr]
式を評価し、そのInput/Outputセルの機密マークを明示的に解除する。秘密変数や秘密依存変数の値に依存していても機密解除として扱う。
例: result = NonConfidential[Mean[secretData]]
### ScanConfidentialCells[]
ノートブック全セルをスキャンし、機密変数を参照するセルを自動的に機密マークする。明示的にUnmarkConfidentialされたセルはスキップされる。

## Web検索・取得

### ClaudeWebSearch[query] → String
Web検索を実行し、結果をテキストで返す。Anthropic APIのweb_searchツールを使用する。
### ClaudeWebFetch[url] / ClaudeWebFetch[url, prompt] → String
指定URLの内容を取得し要約・抽出して返す。promptを指定した場合は取得内容に対してpromptの指示を実行する。
### WebFetch (オプションシンボル)
ClaudeQuery/ClaudeEvalのオプション。True: 必ずAPI経由でWeb取得（課金発生、Fallback->True必須）。False: Web取得しない。Automatic(ClaudeEvalのデフォルト): Claudeがタスクを分析し必要なら自動でWeb取得する。ClaudeQueryのデフォルトはFalse。
### WebSearch (オプションシンボル)
ClaudeQuery/ClaudeEvalのオプション。True(デフォルト): Claude Code CLI組み込みWebSearchツールを許可する（課金なし）。False: Claude Code CLIのWeb検索を禁止する。WebFetch(課金あり)とは異なる。

## 状態・制御

### ClaudeStatus[]
現在実行中の全ClaudeタスクのリアルタイムステータスをGrid表示する。各タスクの経過時間・状態（思考中/テキスト生成中/ツール実行中）・生成済みテキスト断片数・思考断片数・ツール使用数を表示する。実行中タスクがない場合はその旨を表示する。
### ClaudeAbort[]
実行中の全ClaudeタスクをAbortする。Claude Codeプロセスの強制終了、ScheduledTaskの停止、フォールバックタスクのキャンセルを行う。パレットの「実行停止」ボタンからも呼び出し可能。
### ShowClaudePalette[]
Claude Code操作用のパレットを表示する。
### ClaudeQueryShowContext[]
デバッグ用: 次のClaudeQueryが送信するノートブックコンテキストを表示する。
### ClaudeShowAccessConfig[]
デバッグ用: Claude Codeのファイルアクセス設定を表示する。$ClaudeAccessibleDirs、NBGetAccessibleDirs[]、生成されるsettings.json、CLIフラグを確認可能。
### ClaudeCommand["/command"] → String
Claude Code CLIのスラッシュコマンドを実行し結果を返す。スラッシュコマンド(/始まり)はnode-pty経由で対話モードに送信される。CLIサブコマンド(例: config list)は直接実行される。
例: ClaudeCommand["/help"], ClaudeCommand["/permissions"], ClaudeCommand["config list"], ClaudeCommand["--version"]

## コミット準備

### ClaudePrepareCommit[packageName] / ClaudePrepareCommit[packageName, subject]
前回のGitHubコミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを生成してGitHubRefreshAndCommit実行コマンドをInputセルとして出力する。subjectを指定した場合は1行目を固定し本文は自動収集。
→ Null
Options: Fallback -> False, DryRun -> False, Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, BaseBranch -> Automatic

## 分離検証

### ClaudeCheckSeparation[target]
targetのコードがNBAccessの分離原則に違反している箇所をリストアップする。targetはファイルパス | $packageDirectoryの.wl名 | パクレット名。$ClaudeTestModelのモデルで検査する。
検査対象: SystemCredential直接利用、CellObject直接操作、CellEpilog/CellProlog直接操作、NBAccess`Private`関数呼び出し、NBAccess公開グローバル直接更新、EvaluationCell/CellPrint/SetSelectedNotebook直接使用、TaggingRules/CellTags/CellEpilog属性直接アクセス、CellObjectの公開API・戻り値・状態保持への漏洩、SelectionEvaluate/FrontEndTokenExecute等FE状態操作、NBAccess公開グローバルの破壊的更新(AppendTo/AssociateTo等)。
例: ClaudeCheckSeparation["claudecode"], ClaudeCheckSeparation["C:\\path\\to\\file.wl"]
### ClaudeFixSeparation[target]
分離違反を修正する。targetがファイルパスの場合: バックアップを作成し元ファイルを修正。targetがパッケージ名のみの場合: ClaudeUpdatePackageを呼び出す。事前にClaudeCheckSeparationの結果があればそれを利用する。
例: ClaudeFixSeparation["claudecode"]

## NotebookLLMGraph

DAGベースのLLM呼び出し追跡システム。ノートブックのセッション履歴エントリをノード(L1)として管理し、生成されたコードブロックをL2ノードとして追跡する。

### NotebookLLMGraph[nb] → Graph
ノートブックnbのLLMGraphを返す。存在しない場合は新規作成する。
### NotebookLLMGraphPlot[nb]
ノートブックのLLMGraphをトップレベルで可視化する。Orchestratorノードのみを表示し、アクセスレベル別に色分けする。
### NotebookLLMGraphBuild[nb]
既存のセッション履歴からLLMGraphを再構築する。現在のセッション履歴エントリをノードに変換しグラフを生成する。
### NotebookLLMGraphNodes[nb] → Association
ノートブックのLLMGraph全ノードをAssociationで返す。
### NotebookLLMGraphValidate[nb]
ノートブックのLLMGraphの整合性を検証する。セッション履歴のエントリ数とノード数の一致、エッジの整合性等を確認する。
### NotebookLLMGraphFetchResponse[nb, nodeID] → String | Missing
指定ノードのresponse全文を外部キャッシュから取得する。キャッシュにない場合はMissing["CacheExpired"]を返す。
例: NotebookLLMGraphFetchResponse[EvaluationNotebook[], "history-3"]
### NotebookLLMGraphSubSteps[nb, nodeID]
指定ノードの内部サブステップ履歴を表示する。ClaudeUpdatePackageの内部処理(read-source, llm-query, merge, validate, reload)が記録される。
### NotebookLLMGraphFetchL2[nb, nodeID] → Graph | Missing
指定L1ノードが生成したコードブロックのL2グラフを取得する。L2グラフは各コードブロックの実行状態・エラー・依存関係を保持する。キャッシュにない場合はMissing["CacheExpired"]を返す。
### NotebookLLMGraphErrors[nb] → Dataset
L2ErrorCount > 0またはStatus = "Failed"のノード一覧をDatasetで返す。L2グラフでエラーが起きたL1ノードの特定とデバッグに使用する。
### NotebookLLMGraphUpdateL2Status[nb, l1NodeID, l2NodeID, status, msg]
L2ノードのステータスを手動で更新する。status: "Completed" | "Failed" | "Pending"。
### NotebookLLMGraphPlotL2[nb, l1NodeID]
指定L1ノードが生成したコードブロックのL2グラフを可視化する。
### NotebookLLMGraphRerun[...]
指定ノードを再実行する（ソース切り捨てにより詳細不明）。
### NotebookLLMGraphInvalidateDownstream[...]
指定ノードの下流ノードを無効化する（ソース切り捨てにより詳細不明）。
### NotebookLLMGraphSummary[...]
LLMGraphのサマリーを返す（ソース切り捨てにより詳細不明）。
### LLMGraphExecute[...]
LLMGraphを実行する（ソース切り捨てにより詳細不明）。
### LLMGraphExecuteStatus[...]
LLMGraph実行のステータスを返す（ソース切り捨てにより詳細不明）。
### LLMGraphExecuteCancel[...]
LLMGraph実行をキャンセルする（ソース切り捨てにより詳細不明）。
### NotebookLLMGraphExtractThread[...]
LLMGraphからスレッドを抽出する（ソース切り捨てにより詳細不明）。
### NotebookLLMGraphApplyThread[...]
スレッドをLLMGraphに適用する（ソース切り捨てにより詳細不明）。
### NBFileTranslate[...]
ファイルを翻訳・変換する（ソース切り捨てにより詳細不明）。
### ClaudeProcessFile[...]
ファイルを処理する（ソース切り捨てにより詳細不明）。

## グローバル変数

### $ClaudeModel
型: String, 初期値: ""
Claude CLIに渡すモデル名。""は省略時Claude Code自身のデフォルトモデル。
例: $ClaudeModel = "claude-opus-4-6"
### $ClaudePrivateModel
型: List | String, 初期値: None
秘密データ処理用のローカルモデル指定。AutoPrivate->True時に秘密変数を含むタスクの生成コードに使用される。
例: $ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}
### $ClaudeTestModel
型: String, 初期値: $ClaudeModelと同じ
分離検証などのテスト用モデル名。別モデルで客観的に検証するために変更可能。
### $ClaudeTimeout
型: Integer, 初期値: 1200
ClaudeQuery・ClaudeEval等のタイムアウト秒数。
### $ClaudeVerbose
型: Boolean, 初期値: False
True: 履歴コンパクション等の詳細ログをMessagesに出力する。False: 重大エラー以外のClaudeCodeログを抑制する。
### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Codeを起動する作業ディレクトリ。このディレクトリ配下の.claude/CLAUDE.md, .claude/rules/, .claude/skills/をClaude Codeに読ませる。
### $ClaudeMDPath
型: String, 初期値: ""
読み込まれるCLAUDE.mdのパス。自動検索されるか手動で上書きできる。
### $ClaudeMDContent
型: String, 初期値: ""
読み込まれたCLAUDE.mdの内容。空の場合はCLAUDE.mdが見つからなかったか内容がない。
### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude CodeにRead許可する追加ディレクトリリスト。iPrepareClaudeProjectDirectoryが一時settings.jsonにRead許可を注入する。ノートブックのTaggingRulesにもNBSetAccessibleDirsで永続化可能。NotebookDirectoryは初回使用時にダイアログで許可を確認する（$packageDirectory配下を除く）。
例: $ClaudeAccessibleDirs = {$packageDirectory, "F:\\Dropbox\\Mathematica-oneDrive"}
### $ClaudeFallbackModels
型: List, 初期値: {{"anthropic", $iModelOpus}, {"openai", "gpt-5"}}
フォールバックモデル優先順位。各要素は{"provider", "modelName"}または{"provider", "modelName", "url"}の形式。内部的にNBAccess`NBSetFallbackModelsに同期される。
例: $ClaudeFallbackModels = {{"anthropic","claude-opus-4-6"},{"lmstudio","gpt-oss-20b","http://127.0.0.1:1234"}}
### $ClaudeDocModel
型: String, 初期値: 最新Sonnetモデル
ドキュメント生成・更新時に使用するモデル。""で$ClaudeModelと同じモデルを使用。
例: $ClaudeDocModel = "claude-sonnet-4-6"
### $ClaudeDocRetryDelay
型: Integer, 初期値: 60
ドキュメント生成のリトライ待機秒数。
### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
ドキュメント生成の最大リトライ回数。
### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースの最大文字数。
### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEvalが再帰的にClaudeEval/ContinueEvalを生成する際の最大深度。0で再帰禁止。値を大きくすると多段階の自動タスク連鎖が可能。
### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
外部パッケージがキーワードを登録するためのAssociation。プロンプトにキーワードが含まれると、対応パッケージのapi.mdがコンテキストに自動注入される。各パッケージが自身のロード時に登録する。claudecode.wl側はパッケージ非依存。
例: $ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒切"}

## オプションシンボル

### Fallback -> False
ClaudeQuery/ClaudeEval/ContinueEvalのオプション。True: Claude Code利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。
### AutoEvaluate -> False
ClaudeEval/ClaudeWriteResponseのオプション。True: 生成されたInputセルを自動実行する。
### StartTime -> Now
ClaudeEval/ContinueEval/ClaudeUpdatePackageのオプション。DateObjectで実行開始時刻を遅延指定する。
例: StartTime -> Now + Quantity[3, "Hours"]
### Timeout -> Automatic
ClaudeEval/ContinueEvalのオプション。APIフォールバックのタイムアウト秒数を指定する。AutomaticはiiFallbackTimeout(600秒)。
### RepeatInterval -> None
ClaudeEvalのオプション。繰り返し実行間隔を指定する。{間隔, 最大回数}形式で上限付き繰り返しが可能。TaskObjectが返るのでTaskRemove[]で停止できる。
例: RepeatInterval -> Quantity[2, "Hours"], RepeatInterval -> {Quantity[1,"Hours"], 5}
### TargetFunctions -> Automatic
ClaudeUpdatePackageのオプション。更新対象の関数名リストを指定する。Automaticで自動判定。
### TargetFiles -> Automatic
ClaudeUpdateDocumentationのオプション。自動判定、{"api.md"}等でファイル指定可能。
### Mode -> "Update"
ClaudeUpdateDocumentationのオプション。"Update": 既存更新、"Create": 新規作成。
### DryRun -> False
ClaudeMigrateBackupHistory/ClaudePrepareCommitのオプション。True: 変更を実施せず見積もりのみ表示する。
### Inherit -> True
CreateClaudeSessionのオプション。False: デフォルト履歴を継承しない独立したセッションを作成する。
### Model -> Automatic
ClaudeQuerySync/ClaudeQueryAsyncのオプション。{"provider","model"}形式でモデルを直接指定する。Automaticでモデルルーティングに従う。
例: Model -> {"anthropic", "claude-sonnet-4-6"}
### PrivacySpec -> Automatic
ClaudeQuerySync等のオプション。機密データの扱いを指定する。
### Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, BaseBranch -> Automatic
ClaudePrepareCommitのオプション。GitHubリポジトリ情報を手動で指定する場合に使用する。Automaticで自動検出。
### References -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentationのオプション。URLや書籍名のリストを指定するとREADME.mdに参考文献セクションを追加する。
### Demos -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentationのオプション。デモ動画や使用例のURLリストを指定するとREADME.mdに反映する。
### Disclaimer -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentationのオプション。免責事項セクションに追加する文言のリストを指定する。
### License -> ""
ClaudeCreateDocumentation/ClaudeUpdateDocumentationのオプション。空文字列(デフォルト): GitHubREST`$GitHubLicenseHolderが非空ならMITライセンスを自動挿入。文字列指定: そのままライセンステキストとして挿入。
### Acknowledgments -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentationのオプション。謝辞セクションに追加する文言のリストを指定する。指定時はREADME.mdの免責事項の前に配置される。