# claudecode API Reference

ClaudeCode パッケージは Wolfram Language / Mathematica から Claude Code CLI を呼び出し、ノートブック上でAI支援コーディング・パッケージ管理・ドキュメント生成を行うためのインターフェースを提供する。

## クエリ・評価

### ClaudeQuery[prompt] → String
Claude Code に prompt を送り、応答文字列を同期で返す。
`ClaudeQuery[session, prompt]` はセッション履歴と直前の出力/エラーを考慮して回答する。
`ClaudeQuery[{text, Image[...], File[path], ...}]` でマルチモーダル入力（画像・PDF・音声）を API に直接送信する。
Options: WebSearch -> True (Claude Code CLI 組み込み Web 検索を許可。無料), WebFetch -> False (Anthropic API 経由 Web 取得。課金あり、Fallback -> True 必須), Fallback -> False, Timeout -> Automatic (秒)
例: `ClaudeQuery["リストを逆順にするコードを書いて"]`
例: `ClaudeQuery[{" このグラフを解析して", myPlot}, WebSearch -> True]`

### ClaudeMath[task] → String
Mathematica コード生成に特化したプロンプトで Claude を呼び出す。

### ClaudeExtractCode[response] → String
Claude の応答から最初の ` ```mathematica ` ブロックを抽出する。

### ClaudeExtractAllCode[response] → List
Claude の応答から全 ` ```mathematica ` ブロックをリストで返す。

### ClaudeEval[task, opts]
コードを非同期で生成・表示し、デフォルトセッションに履歴を保存する。
`ClaudeEval[{text, data, Image[...], ...}]` でテキスト・Dataset・画像・一般式を混在できる。
`ClaudeEval[session, task]` で指定セッションに履歴を保存する。
→ TaskObject (RepeatInterval 指定時) または Null
Options: AutoEvaluate -> True (生成された Input セルを自動実行), StartTime -> Now (開始時刻。DateObject 指定。例: `Now + Quantity[3, "Hours"]`), RepeatInterval -> None (繰り返し間隔。例: `Quantity[2, "Hours"]`。`{Quantity[1,"Hours"], 5}` で最大5回), Timeout -> Automatic (フォールバックのタイムアウト秒数), Fallback -> False, WebSearch -> True, WebFetch -> False, AutoPrivate -> False
例: `ClaudeEval["現在のノートブックのデータを集計して", RepeatInterval -> Quantity[1, "Hours"]]`
例: `ClaudeEval[{"成績データを分析して", 成績Dataset}]`

### ContinueEval[session, instruction, opts]
指定セッションで継続する。
`ContinueEval[instruction]` はデフォルトセッションで継続。
`ContinueEval[]` は「エラーを修正してください」でデフォルトセッションを継続。
Options: StartTime -> Now, Timeout -> Automatic, Fallback -> False

### ContinueUpdate[opts]
直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を継続する。
`ContinueUpdate["instruction"]` で追加指示付きで継続。
`ContinueUpdate["pkgName", "instruction"]` で指定パッケージの直前更新を継続。
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now

### ClaudeSpec[task] → String
ノートブック内容からプログラムの仕様を生成する。
`ClaudeSpec[{" task", image, ...}]` で画像付き仕様生成。パレットからセル選択で呼び出し可能。

### ClaudeDebug[codeOrFile, errorMsg]
デバッグ支援を非同期で求める（即座に返る）。

### ClaudeReview[codeOrFile]
コードのレビューを非同期で行う（30000文字超は自動チャンク分割）。

### ClaudeReviewChunked[codeOrFile]
ファイルをチャンク分割して非同期レビューする。

## パッケージ管理

### ClaudeCreatePackage[name, prompt]
prompt に従って name.wl を新規作成し `$packageDirectory` に保存する。

### ClaudeUpdatePackage[packageName, prompt, opts]
`$packageDirectory` にある packageName.wl を Claude の支援でアップデートし、バックアップを作成する。
prompt には文字列または `{文字列, Image[...], File["...pdf"], ...}` を指定できる。
Options: TargetFunctions -> Automatic (更新対象関数を絞り込む), StartTime -> Now, "UpdateApiMd" -> True (api.md の自動更新。False でスキップ)
例: `ClaudeUpdatePackage["myPkg", "showItems のデフォルト表示数を30に変更"]`
例: `ClaudeUpdatePackage["myPkg", "仕様を修正して", StartTime -> Now + Quantity[1, "Hours"]]`

### ClaudeRestorePackage[packageName]
直前のバックアップを復元する。

### ClaudeConvertToPaclet[packageName]
`$packageDirectory` の packageName.wl を Paclet 形式に変換する。packageName/ フォルダを作成し Kernel/, Documentation/, PacletInfo.wl 等を生成する。元の .wl ファイルはバックアップ後に削除される。

### ClaudeUpdatePackageHistory[] → List
全パッケージの ClaudeUpdatePackage 呼び出し履歴を表示しリストで返す。
`ClaudeUpdatePackageHistory[packageName]` で指定パッケージの履歴を表示。
各エントリは `<|"Package"->..., "Timestamp"->..., "Directory"->...|>` の Association。

### ClaudeBackupDataset[packageName]
指定パッケージのバックアップ履歴を Review/Pull/Delete ボタン付き Grid で表示する。
`ClaudeBackupDataset[]` で全パッケージのバックアップ履歴を表示。
Review はバックアップ内容を確認、Pull は復元、Delete はその履歴を削除する。

### ClaudeMigrateBackupHistory[packageName, opts]
既存の history 内の生 .wl バックアップを差分形式 (.wl.cz / .wl.cdiff) に変換して容量を削減する。
`ClaudeMigrateBackupHistory[]` で全パッケージに対して実行。
Options: DryRun -> False (True で削除せず容量削減の見積もりのみ表示)

## ドキュメント生成

### ClaudeCreateDocumentation["packageName", opts]
パッケージの詳細なドキュメント一式を Claude で自動生成する。
単一 .wl: `$packageDirectory/packageName_info/docs/` に出力。
Paclet: `$packageDirectory/packageName/docs/` に出力。
Options: References -> {} (README.md に追加する参考文献 URL・書籍名リスト), Demos -> {} (デモ動画・使用例 URL リスト), Disclaimer -> {} (免責事項セクションへの追記文リスト), Acknowledgments -> {} (謝辞セクションへの追記文リスト), License -> "" (空文字列で MIT 自動挿入、文字列指定でカスタムライセンス)
例: `ClaudeCreateDocumentation["myPkg", References -> {"https://example.com"}, License -> ""]`

### ClaudeUpdateDocumentation["packageName", opts]
ソース差分に基づき全ドキュメントを自動更新する。
`ClaudeUpdateDocumentation["packageName", "更新指示"]` で指示に従ってドキュメントを更新する。ノートブックのコンテキストも参照可能（「上で議論されている内容を反映して」など）。
Options: TargetFiles -> Automatic (自動判定。`{"api.md"}` 等でファイル指定), Mode -> "Update" ("Create" で新規作成), References -> {}, Demos -> {}, Disclaimer -> {}, Acknowledgments -> {}, License -> ""
例: `ClaudeUpdateDocumentation["myPkg", "api.md のみ更新して", TargetFiles -> {"api.md"}]`

## Claude Directives 管理

### ClaudeAddDirective[target, description]
Claude で description を整形し、Claude Directives フォルダのファイルに追加して `InstallClaudeDirectives[]` を実行する。target は `"CLAUDE.md"` またはスキル名（例: `"wolfram-general"`）。元ファイルは自動バックアップされる。

### ClaudeRestoreDirective[target]
ClaudeAddDirective の直前のバックアップを復元し `InstallClaudeDirectives[]` を実行する。target は `"CLAUDE.md"` またはスキル名。

### ClaudeListDirectives[]
Claude Directives フォルダの CLAUDE.md と全スキルの一覧を表示する。

### ClaudeUpdateDirective[text]
ソースコードと Claude Directives の整合性をチェックし、不整合を自動修正する。
`ClaudeUpdateDirective[text]` で text の内容を Claude で解釈し、CLAUDE.md / rules / skills の適切なファイルに反映する。ノートブックのコンテキストも参照可能。

### ClaudeDirectiveBackupDataset[]
Claude Directives の更新履歴を Review/Pull/Delete ボタン付き Grid で表示する。履歴は ClaudeUpdateDirective[text] や ClaudeAddDirective の実行時に自動保存される。

### ClaudeSyncDirectives[dir]
指定ディレクトリ dir のファイルを Claude Directives フォルダと比較し、dir 側が新しいファイルで Claude Directives を更新する。dir にのみ存在するファイルもコピーする。Claude Directives 側にのみあるファイルはそのまま。
例: `ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]`

## セッション管理

### CreateClaudeSession["name"] → session
名前付きセッションを作成する（デフォルト履歴を継承）。
`CreateClaudeSession[session]` は既存セッションの履歴を継承した新セッションを作成。
`CreateClaudeSession[]` はデフォルト履歴を継承した新セッションを作成。
`CreateClaudeSession[Inherit -> False]` は独立したセッションを作成。

### ClaudeRestoreSession[] → session
デフォルトセッションをリストアする。
`ClaudeRestoreSession["name"]` で指定名のセッションをリストア。

### ClaudeListSessions[]
ノートブック内の全セッションを一覧表示する。

### ClaudeDeleteSession["name"]
指定名のセッションを削除する。
`ClaudeDeleteSession["name", "All"]` でセッションとその全履歴を削除。

### ClaudeShowHistory[]
デフォルトセッションの履歴を表示する。
`ClaudeShowHistory[session]` で指定セッションの履歴を表示。
`ClaudeShowHistory["name"]` で指定名のセッションの履歴を表示。

### ClaudeSessionStatus[]
デフォルトセッションの状態（アクセス可能ディレクトリ・アタッチメント・作業ディレクトリのファイル等）を表示する。
`ClaudeSessionStatus[name]` で指定名のセッションの状態を表示。

### ClaudeCompactHistory[]
デフォルトセッションの履歴を手動でコンパクションする（通常は 2n+1+w エントリ超過時に自動実行）。
`ClaudeCompactHistory[name]` で指定セッションをコンパクション。

### ClaudeHistorySize[] → Association
現在のノートブックのセッション履歴サイズを診断する。Entries・ByteCount・KiloBytes・Status を含む Association を返す。200KB 超でコンパクション推奨、500KB 超で危険。

## アタッチメント

### ClaudeAttach[path]
デフォルトセッションに参照資料をアタッチする。アタッチされたファイルは ClaudeQuery/ClaudeEval 時に自動的に Read される。
`ClaudeAttach[session, path]` で指定セッションにアタッチ。

### ClaudeDetach[path]
デフォルトセッションからファイルをデタッチする。
`ClaudeDetach[session, path]` で指定セッションからデタッチ。

### ClaudeAttachments[] → List
デフォルトセッションのアタッチメント一覧を返す。
`ClaudeAttachments[session]` で指定セッションのアタッチメント一覧を返す。

### ClearAttachments[]
デフォルトセッションの全アタッチメントをクリアする。
`ClearAttachments[session]` で指定セッションの全アタッチメントをクリア。

## 秘密セル管理

### Confidential[expr] → expr の評価結果
式を評価し、その Input/Output セルを自動的に秘密マークする。
例: `secretData = Confidential[Import["secret.xlsx", {"Dataset"}]]`

### NonConfidential[expr] → expr の評価結果
式を評価し、その Input/Output セルの秘密マークを明示的に解除する。秘密変数や秘密依存変数の値に依存していても秘密解除として扱う。
例: `result = NonConfidential[Mean[secretData]]`

### MarkConfidential[]
現在のセルを秘密マークする。`MarkConfidential[cell]` で指定セルを秘密マーク。秘密セルは ClaudeEval/ClaudeQuery のプロンプトから除外される。

### UnmarkConfidential[]
現在のセルの秘密マークを解除する。`UnmarkConfidential[cell]` で指定セルの秘密マークを解除。

### IsConfidential[] → True | False
現在のセルが秘密マークされているかを返す。`IsConfidential[cell]` で指定セルを判定。

### ScanConfidentialCells[]
ノートブック全セルをスキャンし、秘密変数を参照するセルを自動的に秘密マークする。明示的に UnmarkConfidential されたセルはスキップされる。

## Web 検索・取得

### ClaudeWebSearch[query] → String
Web 検索を実行し、結果をテキストで返す。Anthropic API の web_search ツールを使用する。

### ClaudeWebFetch[url] → String
指定 URL の内容を取得し、要約・抽出して返す。
`ClaudeWebFetch[url, prompt]` で取得内容に対して prompt の指示を実行する。

## ユーティリティ

### ShowClaudePalette[]
Claude Code 操作用のパレットを表示する。

### ClaudeQueryShowContext[]
デバッグ用: 次の ClaudeQuery が送信するノートブックコンテキストを表示する。

### ClaudeShowAccessConfig[]
デバッグ用: Claude Code のファイルアクセス設定（$ClaudeAccessibleDirs・NBGetAccessibleDirs[]・生成される settings.json・CLI フラグ）を表示する。

### ClaudeStatus[]
実行中の全 Claude タスクのリアルタイム状態を表示する。各タスクの経過時間・現在の状態（思考中/テキスト生成中/ツール実行中）・生成済みテキスト断片数・思考断片数・ツール使用数を表示する。実行中のタスクがない場合はその旨を表示する。

### ClaudeAbort[]
実行中の全 Claude タスクを停止する。Claude Code プロセスの強制終了・ScheduledTask の停止・フォールバックタスクのキャンセルを行う。パレットの「実行停止」ボタンからも呼び出し可能。

### ClaudeCommand["/command"] → String
Claude Code CLI のスラッシュコマンドを実行し結果を返す。スラッシュコマンド (/始まり) は node-pty 経由で対話モードに送信される。CLI サブコマンド（例: `config list`）は直接実行される。
例: `ClaudeCommand["/help"]`
例: `ClaudeCommand["/permissions"]`
例: `ClaudeCommand["config list"]`
例: `ClaudeCommand["--version"]`

### ClaudeCheckSeparation[target]
target のコードが NBAccess の分離原則に違反している箇所をリストアップする。target はファイルパス・`$packageDirectory` の .wl 名・パクレット名。`$ClaudeTestModel` のモデルで検査する。
検査対象: SystemCredential 直接利用・CellObject 直接操作・CellEpilog/CellProlog/NotebookEventActions 直接操作・NBAccess`Private` 関数呼び出し・NBAccess 公開グローバル直接更新・EvaluationCell[]/CellPrint[]/SetSelectedNotebook[] 直接使用・TaggingRules/CellTags/CellEpilog 属性直接アクセス・CellObject の公開 API への漏洩・SelectionEvaluate/FrontEndTokenExecute 等 FE 状態操作・NBAccess 公開グローバルの破壊的更新 (AppendTo/AssociateTo 等)
例: `ClaudeCheckSeparation["claudecode"]`
例: `ClaudeCheckSeparation["C:\\path\\to\\file.wl"]`

### ClaudeFixSeparation[target]
分離違反を修正する。target がファイルパスの場合はバックアップを作成して元ファイルを修正。target がパッケージ名のみの場合は ClaudeUpdatePackage を呼び出す。事前に ClaudeCheckSeparation の結果があればそれを利用する。
例: `ClaudeFixSeparation["claudecode"]`

### ClaudePrepareCommit[packageName, opts]
前回の GitHub コミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを生成して `GitHubRefreshAndCommit` 実行コマンドを Input セルとして出力する。
`ClaudePrepareCommit[packageName, subject]` で1行目を指定し、本文は自動収集。
Options: Fallback -> False, DryRun -> False (True でコマンドを生成せずメッセージのみ返す), Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, BaseBranch -> Automatic

## グローバル変数

### $ClaudeModel
型: String, 初期値: ""
Claude CLI に渡すモデル名。空文字列は Claude Code 自身のデフォルトモデルを使用。
例: `$ClaudeModel = "claude-opus-4-6"`

### $ClaudePrivateModel
型: List, 初期値: Undefined
秘密データ処理用のローカルモデル指定。`AutoPrivate -> True` 時に秘密変数を含むタスクの生成コードに使用される。形式: `{"provider", "modelName"}` または `{"provider", "modelName", "url"}`
例: `$ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}`

### $ClaudeTestModel
型: String, 初期値: $ClaudeModel と同じ
分離検証などのテスト用モデル名。別モデルで客観的に検証するために変更可能。
例: `$ClaudeTestModel = "claude-sonnet-4-6"`

### $ClaudeTimeout
型: Integer, 初期値: 1200
ClaudeQuery・ClaudeEval 等のタイムアウト秒数。
例: `$ClaudeTimeout = 900`

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code を起動する作業ディレクトリ。このディレクトリ配下の .claude/CLAUDE.md, .claude/rules/, .claude/skills/ を Claude Code に読ませる。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索されるか、手動で上書きできる。
例: `$ClaudeMDPath = "C:\\proj\\CLAUDE.md"`

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。内容が空の場合、CLAUDE.md が見つからなかったか内容がない。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。iPrepareClaudeProjectDirectory が一時的に settings.json に Read 許可を注入する。ノートブックの TaggingRules にも NBSetAccessibleDirs で永続化可能。NotebookDirectory は初回使用時にダイアログで許可を確認（$packageDirectory 配下を除く）。
例: `$ClaudeAccessibleDirs = {$packageDirectory, "F:\\Dropbox\\Mathematica-oneDrive"}`

### $ClaudeFallbackModels
型: List, 初期値: {{"anthropic", $iModelOpus}, {"openai", "gpt-5"}}
フォールバックモデル優先順位。各要素は `{"provider", "modelName"}` または `{"provider", "modelName", "url"}` の形式。内部的に NBAccess`NBSetFallbackModels に同期される。
例: `$ClaudeFallbackModels = {{"anthropic","claude-opus-4-6"},{"lmstudio","gpt-oss-20b","http://127.0.0.1:1234"}}`

### $ClaudeDocModel
型: String, 初期値: 最新 Sonnet モデル
ドキュメント生成・更新時に使用するモデル。空文字列で $ClaudeModel と同じモデルを使用。
例: `$ClaudeDocModel = "claude-sonnet-4-6"`

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
ClaudeEval が再帰的に ClaudeEval を生成する際の最大深度。0 で再帰禁止。値を大きくすると多段階の自動タスク連鎖が可能。

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
外部パッケージがキーワードを登録するための Association。プロンプトにキーワードが含まれると、対応パッケージの api.md がコンテキストに自動注入される。各パッケージが自身のロード時に登録する。claudecode.wl 側はパッケージ非依存。
例: `$ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒切"}`

## オプション

### Fallback -> False
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: Claude Code 利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。False (デフォルト): エラーをそのまま返す。

### AutoPrivate -> False
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: 秘密変数にアクセスするタスクの場合、生成コードに `Model -> $ClaudePrivateModel, PrivacySpec -> Automatic` を付与する。

### AutoEvaluate -> True
ClaudeEval のオプション。生成された Input セルの自動実行を制御する。

### StartTime -> Now
ClaudeEval/ContinueEval/ClaudeUpdatePackage 等のオプション。実行開始時刻を DateObject で指定する。
例: `StartTime -> Now + Quantity[3, "Hours"]`

### RepeatInterval -> None
ClaudeEval のオプション（ClaudeEval 専用。ClaudeUpdatePackage 等には使用不可）。繰り返し実行の間隔。
例: `RepeatInterval -> Quantity[2, "Hours"]`（2時間ごとに実行）
例: `RepeatInterval -> {Quantity[1, "Hours"], 5}`（1時間ごとに最大5回実行）

### Timeout -> Automatic
ClaudeEval/ContinueEval のオプション。API フォールバックのタイムアウト秒数。Automatic は $iFallbackTimeout (600秒)。

### TargetFunctions -> Automatic
ClaudeUpdatePackage のオプション。更新対象関数を絞り込む。

### TargetFiles -> Automatic
ClaudeUpdateDocumentation のオプション。更新対象ファイルを指定。例: `TargetFiles -> {"api.md"}`

### Mode -> "Update"
ClaudeUpdateDocumentation のオプション。"Update" (既存更新) または "Create" (新規作成)。

### DryRun -> False
ClaudeMigrateBackupHistory/ClaudePrepareCommit のオプション。True で実際の変更を行わず結果のプレビューのみ表示する。

### Inherit -> True
CreateClaudeSession のオプション。False で独立したセッションを作成する。

### WebFetch -> False
ClaudeQuery/ClaudeEval のオプション。True: Anthropic API 経由で Web 取得を行う（課金あり、Fallback -> True 必須）。False: Web 取得を行わない。

### WebSearch -> True
ClaudeQuery/ClaudeEval のオプション。True (デフォルト): Claude Code CLI 組み込みの Web 検索ツールを許可（無料）。False: Claude Code CLI の Web 検索を禁止。WebFetch (課金あり) とは異なる。

### References -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。README.md に追加する参考文献 URL・書籍名のリスト。
例: `References -> {"https://example.com", "書籍名"}`

### Demos -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。デモ動画・使用例の URL リスト。README.md に反映される。
例: `Demos -> {"https://youtu.be/...", "https://example.com/demo.nb"}`

### Disclaimer -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。免責事項セクションに追記する文言のリスト。
例: `Disclaimer -> {"本ツールは研究目的専用です"}`

### Acknowledgments -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。謝辞セクションに追記する文言のリスト。指定時は README.md の免責事項の前に配置される。
例: `Acknowledgments -> {"本研究は JSPS 科研費の助成を受けた"}`

### License -> ""
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。空文字列 (デフォルト): `GitHubREST`$GitHubLicenseHolder` が非空なら MIT ライセンスを自動挿入。文字列指定: そのままライセンステキストとして挿入。
例: `License -> ""` (MIT 自動挿入), `License -> "Apache-2.0 License..."`

### Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, BaseBranch -> Automatic
ClaudePrepareCommit のオプション。GitHub リポジトリ情報を手動指定する場合に使用する。