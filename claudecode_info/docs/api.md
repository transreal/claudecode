# claudecode API リファレンス

パッケージ: `ClaudeCode\`` — Wolfram Language から Claude Code CLI および Anthropic API を操作するためのインターフェース。

## グローバル変数

### $ClaudeModel
型: String, 初期値: ""
Claude CLI に渡すモデル名。"" はClaude Code自身のデフォルトモデルを使用。例: `$ClaudeModel = "claude-opus-4-6"`

### $ClaudePrivateModel
型: List, 初期値: {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}
秘密データ処理用のローカルモデル指定。`AutoPrivate -> True` 時に秘密変数を含むタスクの生成コードに使用される。形式: `{"provider", "modelName"}` または `{"provider", "modelName", "url"}`

### $ClaudeTestModel
型: String, 初期値: $ClaudeModel と同じ
分離検証などのテスト用モデル名。別モデルで客観的に検証するために変更可能。例: `$ClaudeTestModel = "claude-sonnet-4-6"`

### $ClaudeDocModel
型: String, 初期値: 最新Sonnetモデル
ドキュメント生成・更新時に使用するモデル。"" で $ClaudeModel と同じモデルを使用。例: `$ClaudeDocModel = "claude-sonnet-4-6"`

### $ClaudeTimeout
型: Integer, 初期値: 1200
ClaudeQuery・ClaudeEval 等のタイムアウト秒数。

### $ClaudeVerbose
型: Boolean, 初期値: False
True: 履歴コンパクション等の詳細ログをMessagesに出力。False: 重大エラー以外のClaudeCodeログを抑制。

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code を起動する作業ディレクトリ。配下の `.claude/CLAUDE.md`, `.claude/rules/`, `.claude/skills/` をClaude Codeに読ませる。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索されるか、手動で上書きできる。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。空の場合、CLAUDE.mdが見つからなかったか内容がない。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。NotebookDirectory は初回使用時にダイアログで許可を確認（$packageDirectory配下を除く）。例: `$ClaudeAccessibleDirs = {$packageDirectory, "F:\\Dropbox\\Mathematica-oneDrive"}`

### $ClaudeFallbackModels
型: List, 初期値: {{"anthropic", $iModelOpus}, {"openai", "gpt-5"}}
フォールバックモデル優先順位。各要素は `{"provider", "modelName"}` または `{"provider", "modelName", "url"}` の形式。内部的には `NBAccess\`NBSetFallbackModels` に同期される。

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
ClaudeEval が再帰的にClaudeEvalを生成する際の最大深度。0で再帰禁止。大きくすると多段階の自動タスク連鎖が可能。

### $ClaudePackageKeywordMap
型: Association
外部パッケージがキーワードを登録するためのAssociation。プロンプトにキーワードが含まれると、対応パッケージの api.md がコンテキストに自動注入される。各パッケージが自身のロード時に登録する。claudecode.wl 側はパッケージ非依存。例: `$ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒切"}`

## オプションシンボル

### Fallback
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: Claude Code利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。False（デフォルト）: エラーをそのまま返す。

### WebSearch
ClaudeQuery/ClaudeEval のオプション。True（デフォルト）: Claude Code CLIの組み込みWeb検索ツールを許可。False: Claude Code CLIのWeb検索を禁止。APIを介した課金は発生しない。WebFetch（課金あり）とは異なる。

### WebFetch
ClaudeQuery/ClaudeEval のオプション。True: 必ずWeb検索を行う。False: Web検索を行わない。Automatic（ClaudeEvalのデフォルト）: Claudeがタスクを分析し、必要なら自動でWeb検索する。重要: WebFetchはAnthropic API経由で課金が発生するため、`Fallback -> True` の場合のみ有効。ClaudeQueryのデフォルトはFalse。

### AutoEvaluate
ClaudeEval/ClaudeWriteResponse のオプション。True（ClaudeEvalデフォルト）: 生成されたInputセルを自動実行。False: 生成のみで実行しない。

### StartTime
ClaudeEval/ContinueEval/ClaudeUpdatePackage のオプション。DateObjectで実行開始時刻を指定。例: `StartTime -> Now + Quantity[3, "Hours"]`

### RepeatInterval
ClaudeEval のオプション。None（デフォルト）: 繰り返しなし。`Quantity[2, "Hours"]` で2時間ごとに実行。`{Quantity[1, "Hours"], 5}` で1時間ごとに最大5回実行。TaskObjectが返るので `TaskRemove[]` で停止可能。

### Timeout
ClaudeEval/ContinueEval のオプション。APIフォールバックのタイムアウト秒数を指定。Automatic は $iFallbackTimeout（600秒）。

### TargetFunctions
ClaudeUpdatePackage のオプション。Automatic（デフォルト）: 自動判定。関数名リストを指定すると対象関数のみ更新。

### TargetFiles
ClaudeUpdateDocumentation のオプション。Automatic（デフォルト）: 自動判定。`{"api.md"}` 等でファイル指定。

### Mode
ClaudeUpdateDocumentation のオプション。"Update"（既存更新）または "Create"（新規作成）。

### DryRun
ClaudeMigrateBackupHistory/ClaudePrepareCommit のオプション。True: 実際の変更を行わず見積もりや生成メッセージのみ返す。False（デフォルト）: 実際に実行する。

### Inherit
CreateClaudeSession のオプション。True（デフォルト）: デフォルト履歴を継承。False: 独立したセッションを作成。

### Model
ClaudeQuerySync/ClaudeQueryBg/ClaudeQueryAsync のオプション。Automatic: モデルルーティングに従う。`{"provider", "model"}` で指定モデルをAPI経由で使用。

### Keywords
ClaudeAttach のオプション。デフォルト: {}。登録するとプロンプト中のキーワードに応じてアタッチメントが自動注入される。

### Title
ClaudeAttach のオプション。デフォルト: None。アタッチメントのタイトルを指定。

### Refetch
ClaudeAttach のオプション。デフォルト: False。True: URLのキャッシュを無視して再取得する。

### References
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。URLや書籍名のリストを指定するとREADME.mdに参考文献セクションを追加。例: `References -> {"https://...", "書籍名"}`

### Demos
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。デモ動画や使用例のURLリストを指定するとREADME.mdに反映。例: `Demos -> {"https://youtu.be/...", "https://example.com/demo.nb"}`

### Owner
ClaudePrepareCommit のオプション。Automatic（デフォルト）: 自動判定。GitHubオーナー名を指定。

### Repository
ClaudePrepareCommit のオプション。Automatic（デフォルト）: 自動判定。GitHubリポジトリ名を指定。

### Branch
ClaudePrepareCommit のオプション。Automatic（デフォルト）: 自動判定。コミット先ブランチを指定。

### BaseBranch
ClaudePrepareCommit のオプション。Automatic（デフォルト）: 自動判定。差分比較のベースブランチを指定。

## クエリ関数

### ClaudeQuery[prompt] → String
Claude Code にpromptを送り、応答文字列を返す（同期）。`ClaudeQuery[session, prompt]` でセッション履歴と直前の出力/エラーを考慮して回答する。`ClaudeQuery[{text, Image[...], File[path], ...}]` でマルチモーダル入力。画像/PDF/音声をAPIに直接送信する。
Options: WebSearch -> True, WebFetch -> False, Fallback -> False, Timeout -> Automatic

### ClaudeQuerySync[prompt, opts] → String
Claudeに同期的に問い合わせ、応答文字列を返す。WindowStatusAreaに経過時間を表示する。セッション履歴やノートブック書き込みは行わない軽量版。モデルルーティング: `Model -> Automatic` かつ `PrivacyLevel <= 0.5` の場合Claude Code CLI、`PrivacyLevel > 0.5` の場合 $ClaudePrivateModel を自動使用。`Model -> {"provider","model"}` で指定モデルをAPI経由で使用する。
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic
例: `ClaudeQuerySync[prompt, PrivacyLevel -> 1.0]`
例: `ClaudeQuerySync[prompt, Model -> {"anthropic", "claude-sonnet-4-6"}]`

### ClaudeQueryBg[prompt, opts] → String
FrontEnd操作・ScheduledTask生成なしでClaudeに同期問い合わせし、応答文字列を返す。ClaudeQuerySyncと違いWindowStatusArea更新・進捗表示用ScheduledTaskを一切生成しない。SocketListenハンドラ・ScheduledTaskコールバック等の非同期コンテキストから安全に呼び出せる（rule 95: URLRead相当の安全な代替手段）。
Options: Fallback -> False, Model -> Automatic, Timeout -> Automatic
例: `ClaudeQueryBg["Hello"]  (* SocketListenハンドラ内から安全 *)`

### ClaudeQueryAsync[prompt, callback, nb, opts]
Claudeに非同期で問い合わせ、完了時に `callback[応答文字列]` を呼ぶ。nbは出力先NotebookObject。カーネルをブロックしない。WindowStatusAreaに経過時間を表示する。Jobシステム（NBBeginJobAtEvalCell）を使用し、iClaudeQueryImplと同じ非同期パスを通る。
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic

### ClaudeWriteResponse[nb, text, opts]
マークダウン形式のテキストをノートブックのセルとして展開する。見出し・リスト・コードブロック等を適切なセルスタイルに変換する。ClaudeQuerySyncで取得した応答をノートブックに出力する際に使用する。
Options: AutoEvaluate -> False

### ClaudeMath[task] → String
Mathematicaコード生成に特化したプロンプトでClaudeを呼び出す。

### ClaudeExtractCode[response] → String
Claudeの応答から最初の ` ```mathematica ` ブロックを抽出する。

### ClaudeExtractAllCode[response] → List
Claudeの応答から全 ` ```mathematica ` ブロックをリストで返す。

## セッション管理

### CreateClaudeSession["name"] → Session
名前付きセッションを作成する（デフォルト履歴を継承）。`CreateClaudeSession[session]` は既存セッションの履歴を継承した新セッションを作成。`CreateClaudeSession[]` はデフォルト履歴を継承した新セッションを作成。`CreateClaudeSession[Inherit -> False]` は独立したセッションを作成。

### ClaudeRestoreSession[] / ClaudeRestoreSession["name"]
デフォルトまたは指定名のセッションをリストアする。

### ClaudeListSessions[] → Grid
ノートブック内の全セッションを一覧表示する。

### ClaudeDeleteSession["name"] / ClaudeDeleteSession["name", "All"]
指定名のセッションを削除する。"All" を指定するとセッションとその全履歴を削除する。

### ClaudeShowHistory[] / ClaudeShowHistory[session] / ClaudeShowHistory["name"]
デフォルトセッション・指定セッション・指定名セッションの履歴を表示する。

### ClaudeSessionStatus[] / ClaudeSessionStatus[name]
デフォルトまたは指定名セッションの状態を表示する。アクセス可能ディレクトリ、アタッチメント、作業ディレクトリのファイル等を確認できる。

### ClaudeCompactHistory[] / ClaudeCompactHistory[name]
デフォルトまたは指定セッションの履歴を手動でコンパクションする。通常は 2n+1+w エントリを超えたときに自動実行される。

### ClaudeHistorySize[] → Association
現在のノートブックのセッション履歴サイズを診断する。Entries・ByteCount・KiloBytes・Status を含むAssociationを返す。200KB超でコンパクション推奨、500KB超で危険。

## コード生成・評価

### ClaudeEval[task, opts]
コードを非同期で生成・表示し、デフォルトセッションに履歴を保存する。`ClaudeEval[{text, data, ...}]` でテキスト・Dataset・Image・一般式を混在できる。`ClaudeEval[session, task]` で指定セッションに履歴を保存する。
Options: AutoEvaluate -> True, StartTime -> Now, RepeatInterval -> None, Timeout -> Automatic, Fallback -> False, WebSearch -> True, WebFetch -> Automatic, AutoPrivate -> False
例: `ClaudeEval[RepeatInterval -> {Quantity[1,"Hours"], 5}]`（1時間ごとに最大5回実行、TaskObjectが返る）

### ContinueEval[session, instruction, opts] / ContinueEval[instruction] / ContinueEval[]
指定セッション・デフォルトセッションで継続する。`ContinueEval[]` は "エラーを修正してください" でデフォルトセッションを継続。
Options: StartTime -> Now, Timeout -> Automatic

### ContinueUpdate[opts] / ContinueUpdate["instruction"] / ContinueUpdate[{text, img}] / ContinueUpdate["pkgName", "instruction"]
直前のClaudeUpdatePackageの結果を踏まえてバグ修正を継続する。テキスト+画像での継続も可能。指定パッケージの直前の更新を継続することもできる。
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now

### ClaudeSpec[task] / ClaudeSpec[{task, image, ...}]
ノートブック内容からプログラムの仕様を生成する。画像付きで仕様を生成することも可能。パレットからはセル選択で呼び出し可能。

### ClaudeDebug[codeOrFile, errorMsg]
デバッグ支援を非同期で求める（即座に返る）。

### ClaudeReview[codeOrFile]
コードのレビューを非同期で行う（30000文字超は自動チャンク分割）。

### ClaudeReviewChunked[codeOrFile]
ファイルをチャンク分割して非同期レビューする。

## パッケージ操作

### ClaudeCreatePackage[name, prompt]
promptに従って name.wl を新規作成し $packageDirectory に保存する。

### ClaudeUpdatePackage[packageName, prompt, opts]
$packageDirectory にある packageName.wl をClaudeの支援でアップデートし、バックアップを作成する。promptには文字列またはリスト `{文字列, Image, File[".../file.pdf"], ...}` を指定できる。
Options: TargetFunctions -> Automatic, StartTime -> Now, Fallback -> False, "UpdateApiMd" -> Automatic
"UpdateApiMd" -> False で api.md の自動更新をスキップ。
例: `ClaudeUpdatePackage["pkg", "修正指示", StartTime -> Now + Quantity[1, "Hours"]]`

### ClaudeRestorePackage[packageName]
直前のバックアップを復元する。

### ClaudeConvertToPaclet[packageName]
$packageDirectory の packageName.wl を Paclet 形式に変換する。packageName/ フォルダを作成し、Kernel/, Documentation/, PacletInfo.wl 等を生成する。元の .wl ファイルはバックアップ後に削除される。

### ClaudeUpdatePackageHistory[] / ClaudeUpdatePackageHistory[packageName] → List
全パッケージまたは指定パッケージのClaudeUpdatePackage呼び出し履歴を表示しリストで返す。各エントリは `<|"Package" -> ..., "Timestamp" -> ..., "Directory" -> ...|>` のAssociation。

### ClaudeBackupDataset[packageName] / ClaudeBackupDataset[] → Grid
指定パッケージまたは全パッケージのバックアップ履歴をReview/Pull/DeleteボタンGridで表示する。ReviewはバックアップI内容を確認、Pullは復元、Deleteはその履歴を削除。

### ClaudeMigrateBackupHistory[packageName, opts] / ClaudeMigrateBackupHistory[]
既存のhistory内の生 .wl バックアップを差分形式（.wl.cz / .wl.cdiff）に変換して容量を削減する。全パッケージに対して実行することも可能。
Options: DryRun -> False
例: `ClaudeMigrateBackupHistory[packageName, DryRun -> True]`（削減見積もりのみ表示）

## ドキュメント管理

### ClaudeCreateDocumentation["packageName", opts]
パッケージの詳細なドキュメント一式をClaudeで自動生成する。$packageDirectory 内の packageName.wl または packageName/ Paclet を対象とする。単一 .wl: `$packageDirectory/packageName_info/docs/` に出力。Paclet: `$packageDirectory/packageName/docs/` に出力。リミット到達時に自動停止し、再実行で未生成分のみ続行する。README.md は最後に生成される。
Options: References -> {}, Demos -> {}, Disclaimer -> {}, License -> "", Acknowledgments -> {}

### ClaudeUpdateDocumentation["packageName", opts] / ClaudeUpdateDocumentation["packageName", "更新指示", opts]
ソース差分に基づき全ドキュメントを自動更新する、または指示に従ってドキュメントを更新する。ノートブックのコンテキストも参照可能（"上で議論されている内容を反映して" など）。
Options: TargetFiles -> Automatic, Mode -> "Update"
例: `ClaudeUpdateDocumentation["claudecode", "api.mdのみ更新して"]`
例: `ClaudeUpdateDocumentation["pkg", "...", TargetFiles -> {"api.md"}]`

## ディレクティブ管理

### ClaudeAddDirective[target, description]
ClaudeでdescriptionをClaude Directivesフォルダのファイルに追加し、InstallClaudeDirectives[] を実行する。targetは "CLAUDE.md" またはスキル名（例: "wolfram-general"）。元ファイルは自動バックアップされる。

### ClaudeRestoreDirective[target]
ClaudeAddDirectiveの直前のバックアップを復元し InstallClaudeDirectives[] を実行する。targetは "CLAUDE.md" またはスキル名。

### ClaudeListDirectives[] → Grid
Claude Directives フォルダの CLAUDE.md と全スキルの一覧を表示する。

### ClaudeUpdateDirective[] / ClaudeUpdateDirective[text]
ソースコードとClaude Directivesの整合性をチェックし、不整合を自動修正する。textを渡すとClaudeで解釈し、CLAUDE.md / rules / skills の適切なファイルに反映する。ノートブックのコンテキストも参照可能。

### ClaudeDirectiveBackupDataset[] → Grid
Claude Directivesの更新履歴をReview/Pull/DeleteボタンGrid表示する。履歴はClaudeUpdateDirective[text]やClaudeAddDirective実行時に自動保存される。

### ClaudeSyncDirectives[dir]
指定ディレクトリdirのファイルをClaude Directivesフォルダと比較し、dir側の方が新しいファイルでClaude Directivesを更新する。dirにだけ存在するファイルもコピーする。Claude Directivesにしかないファイルはそのまま。例: `ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]`

## アタッチメント管理

### ClaudeAttach[path, opts] / ClaudeAttach[session, path, opts]
デフォルトセッションまたは指定セッションに参照資料をアタッチする。URLを指定するとページをPDF化してキャッシュし、アタッチする。アタッチされたファイルはClaudeQuery/ClaudeEval時に自動的にReadされる。
Options: Keywords -> {}, Title -> None, Refetch -> False
Keywordsで登録するとプロンプト中のキーワードに応じて自動注入される。

### ClaudeDetach[path] / ClaudeDetach[session, path]
デフォルトセッションまたは指定セッションからファイルをデタッチする。

### ClaudeAttachments[] / ClaudeAttachments[session] → List
デフォルトセッションまたは指定セッションのアタッチメント一覧を返す。

### ClearAttachments[] / ClearAttachments[session]
デフォルトセッションまたは指定セッションの全アタッチメントをクリアする。

## 機密管理

### MarkConfidential[] / MarkConfidential[cell]
現在のセルまたは指定セルを機密マークする。機密セルはClaudeEval/ClaudeQueryのプロンプトから除外される。

### UnmarkConfidential[] / UnmarkConfidential[cell]
現在のセルまたは指定セルの機密マークを解除する。

### IsConfidential[cell] / IsConfidential[] → Boolean
指定セルまたは現在のセルが機密マークされているかを返す。

### Confidential[expr]
式を評価し、そのInput/OutputセルをIK自動的に機密マークする。例: `Confidential[secretData = Import["secret.csv"]]`

### NonConfidential[expr]
式を評価し、そのInput/Outputセルの機密マークを明示的に解除する。秘密変数や秘密依存変数の値に依存していても、機密解除として扱う。例: `result = NonConfidential[Mean[secretData]]`

### ScanConfidentialCells[]
ノートブック全セルをスキャンし、機密変数を参照するセルを自動的に機密マークする。明示的にUnmarkConfidentialされたセルはスキップされる。

## Webアクセス

### ClaudeWebSearch[query] → String
Web検索を実行し、結果をテキストで返す。Anthropic APIのweb_searchツールを使用する。

### ClaudeWebFetch[url] / ClaudeWebFetch[url, prompt] → String
指定URLの内容を取得し、要約・抽出して返す。promptを指定すると取得内容に対してpromptの指示を実行する。

## パッケージ操作・整合性検証

### ClaudeCheckSeparation[target] → List
targetのコードがNBAccessの分離原則に違反している箇所をリストアップする。targetはファイルパス・$packageDirectoryの.wl名・パクレット名。$ClaudeTestModelのモデルで検査する。
検査対象 (静的走査+LLM判定):
a. SystemCredential直接利用
b. CellObject直接操作（NotebookWrite/NotebookRead/CellGroupData直接構築）
c. CellEpilog/CellProlog/NotebookEventActions直接操作
d. NBAccess\`Private\`関数呼び出し
e. NBAccess公開グローバル直接更新
f. EvaluationCell[]/CellPrint[]/SetSelectedNotebook[]直接使用
g. CurrentValue/SetOptionsによるTaggingRules/CellTags/CellEpilog属性直接アクセス
h. CellObjectの公開API・戻り値・状態保持への漏洩
i. SelectionEvaluate/FrontEndTokenExecute等FE状態操作
j. NBAccess公開グローバルの破壊的更新（AppendTo/AssociateTo等）
例: `ClaudeCheckSeparation["claudecode"]`

### ClaudeFixSeparation[target]
分離違反を修正する。targetがファイルパスの場合: バックアップを作成し元ファイルを修正。targetがパッケージ名のみの場合: ClaudeUpdatePackageを呼び出す。事前にClaudeCheckSeparationの結果があればそれを利用する。例: `ClaudeFixSeparation["claudecode"]`

## コミット準備

### ClaudePrepareCommit[packageName, opts] / ClaudePrepareCommit[packageName, subject, opts]
前回のGitHubコミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを生成してGitHubRefreshAndCommit実行コマンドをInputセルとして出力する。subjectを指定すると1行目を固定し、本文は自動収集する。
Options: Fallback -> False, DryRun -> False, Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, BaseBranch -> Automatic
DryRun -> True でコマンドを生成せずメッセージのみ返す。

## ノートブックUI

### ShowClaudePalette[]
Claude Code操作用のパレットを表示する。

### ClaudeQueryShowContext[]
デバッグ用: 次のClaudeQueryが送信するノートブックコンテキストを表示する。

### ClaudeShowAccessConfig[]
デバッグ用: Claude Codeのファイルアクセス設定を表示する。$ClaudeAccessibleDirs、NBGetAccessibleDirs[]、生成されるsettings.json、CLIフラグを確認できる。

### ClaudeStatus[] → Grid
現在実行中の全ClaudeタスクのリアルタイムI状態を表示する。各タスクの経過時間・現在の状態（思考中/テキスト生成中/ツール実行中）・生成済みテキスト断片数・思考断片数・ツール使用数を表示する。実行中のタスクがない場合はその旨を表示する。

### ClaudeAbort[]
実行中の全Claudeタスクを停止する。Claude Codeプロセスの強制終了、ScheduledTaskの停止、フォールバックタスクのキャンセルを行う。パレットの「実行停止」ボタンからも呼び出し可能。

## ユーティリティ

### ClaudeCommand["/command"] / ClaudeCommand["subcommand"] → String
Claude Code CLIのスラッシュコマンドを実行し結果を返す。スラッシュコマンド（/始まり）はnode-pty経由で対話モードに送信される。CLIサブコマンド（例: config list）は直接実行される。
例: `ClaudeCommand["/help"]`
例: `ClaudeCommand["/permissions"]`
例: `ClaudeCommand["config list"]`
例: `ClaudeCommand["--version"]`

## LLMGraph

### NotebookLLMGraph[nb] → LLMGraph
ノートブック nb のLLMGraphを返す。存在しない場合は新規作成する。

### NotebookLLMGraphPlot[nb] → Graphics
ノートブックのLLMGraphをトップレベルで可視化する。Orchestratorノードのみを表示し、アクセスレベル別に色分けする。

### NotebookLLMGraphBuild[nb] → LLMGraph
既存のセッション履歴からLLMGraphを再構築する。現在のセッション履歴エントリをノードに変換しグラフを生成する。

### NotebookLLMGraphNodes[nb] → Association
ノートブックのLLMGraph全ノードをAssociationで返す。

### NotebookLLMGraphValidate[nb] → Association
ノートブックのLLMGraphの整合性を検証する。セッション履歴のエントリ数とノード数の一致、エッジの整合性等を確認する。

### NotebookLLMGraphFetchResponse[nb, nodeID] → String | Missing
指定ノードのresponse全文を外部キャッシュから取得する。キャッシュにない場合は `Missing["CacheExpired"]` を返す。

### NotebookLLMGraphSubSteps[nb, nodeID] → List
指定Orchestratorノードのサブステップ（L2ノード）一覧を返す。

### NotebookLLMGraphFetchL2[nb, nodeID] → Association
指定L2ノードの詳細情報を外部キャッシュから取得する。

### NotebookLLMGraphErrors[nb] → List
LLMGraph内のエラーを持つノード一覧を返す。

### NotebookLLMGraphUpdateL2Status[nb, nodeID, status]
指定L2ノードのステータスを更新する。

### NotebookLLMGraphPlotL2[nb, nodeID] → Graphics
指定OrchestratorノードのL2サブグラフを可視化する。

### NotebookLLMGraphRerun[nb, nodeID, opts]
指定ノードを再実行する。

### NotebookLLMGraphInvalidateDownstream[nb, nodeID]
指定ノードの下流ノードを無効化する。

### NotebookLLMGraphSummary[nb] → String
LLMGraphのサマリーを生成して返す。

### NotebookLLMGraphExtractThread[nb, nodeID] → List
指定ノードから上流への会話スレッドを抽出する。

### NotebookLLMGraphApplyThread[nb, thread]
抽出したスレッドをノートブックに適用する。

### LLMGraphExecute[graph, opts] → TaskObject
LLMGraphを実行する。

### LLMGraphExecuteStatus[taskID] → Association
LLMGraphExecuteの実行状態を返す。

### LLMGraphExecuteCancel[taskID]
LLMGraphExecuteを中止する。

## ファイル処理

### NBFileTranslate[file, opts]
ノートブックファイルを翻訳・変換処理する。

### ClaudeProcessFile[file, prompt, opts]
指定ファイルに対してpromptの指示でClaude処理を実行する。