# ClaudeCode API Reference

ClaudeCode は Mathematica ノートブックから Claude Code CLI を呼び出し、コード生成・パッケージ管理・ドキュメント生成を行うパッケージだ。

## クエリ・評価

### ClaudeQuery[prompt] → String
Claude Code に prompt を送り、応答文字列を同期で返す。
`ClaudeQuery[session, prompt]` はセッション履歴を引き継いで回答する。
`ClaudeQuery[{text, Image[...], File[path], ...}]` でマルチモーダル入力（画像・PDF・音声）を API に直接送信する。
Options: WebSearch -> True (Claude Code 組み込み検索許可), WebFetch -> False (API 経由有料。Fallback->True 時のみ有効), Fallback -> False, Timeout -> Automatic (秒)

### ClaudeMath[task] → String
Mathematica コード生成に特化したプロンプトで Claude を呼び出す。

### ClaudeExtractCode[response] → String
Claude 応答から最初の ```mathematica ブロックを抽出する。

### ClaudeExtractAllCode[response] → List
Claude 応答から全 ```mathematica ブロックをリストで返す。

### ClaudeSpec[task] → (ノートブックに出力)
ノートブック内容からプログラムの仕様を生成する。`ClaudeSpec[{task, image, ...}]` で画像付き仕様を生成。パレットからセル選択で呼び出し可能。

### ClaudeEval[task]
コードを非同期で生成・表示し、デフォルトセッションに履歴を保存する。
`ClaudeEval[{text, data, ...}]` でテキスト・Dataset・Image・一般式を混在できる。
`ClaudeEval[session, task]` で指定セッションに履歴を保存する。
→ TaskObject (RepeatInterval 指定時) または Null
Options: AutoEvaluate -> True (生成 Input セルを自動実行), StartTime -> Now (DateObject で遅延実行), RepeatInterval -> None (例: Quantity[2,"Hours"] で繰り返し。{Quantity[1,"Hours"],5} で最大5回), Timeout -> Automatic, Fallback -> False, WebSearch -> True, WebFetch -> False

例: `ClaudeEval["解析して", StartTime -> Now + Quantity[3,"Hours"]]`
例: `ClaudeEval["繰り返し", RepeatInterval -> {Quantity[1,"Hours"], 5}]`

### ContinueEval[session, instruction]
指定セッションで続行する。`ContinueEval[instruction]` はデフォルトセッションで続行。`ContinueEval[]` は「エラーを修正してください」でデフォルトセッションを続行する。
Options: StartTime -> Now, Timeout -> Automatic, Fallback -> False

### ContinueUpdate[]
直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を続行する。
`ContinueUpdate["instruction"]` で追加指示付きで続行。
`ContinueUpdate["pkgName", "instruction"]` で指定パッケージの直前の更新を続行。
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now

### ClaudeDebug[codeOrFile, errorMsg]
デバッグ支援を非同期で求める（即座に返る）。

### ClaudeReview[codeOrFile]
コードのレビューを非同期で行う（30000文字超は自動チャンク分割）。

### ClaudeReviewChunked[codeOrFile]
ファイルをチャンク分割して非同期レビューする。

## パッケージ管理

### ClaudeCreatePackage[name, prompt]
prompt に従って name.wl を新規作成し $packageDirectory に保存する。

### ClaudeUpdatePackage[packageName, prompt, opts]
$packageDirectory の packageName.wl を Claude の支援でアップデートし、バックアップを作成する。prompt は文字列またはリスト {文字列, Image, File[".../file.pdf"], ...} を指定可能。
→ (非同期、ノートブックに結果出力)
Options: TargetFunctions -> Automatic (対象関数を限定), StartTime -> Now, Fallback -> False, "UpdateApiMd" -> Automatic (False で api.md 自動更新をスキップ)

例: `ClaudeUpdatePackage["pkg", "修正指示", StartTime -> Now + Quantity[1,"Hours"]]`

### ClaudeRestorePackage[packageName]
直前のバックアップを復元する。

### ClaudeUpdatePackageHistory[] → List
全パッケージの ClaudeUpdatePackage 呼び出し履歴を表示してリストで返す。
`ClaudeUpdatePackageHistory[packageName]` で指定パッケージの更新履歴を表示。各エントリは `<|"Package"->…, "Timestamp"->…, "Directory"->…|>` の Association。

### ClaudeBackupDataset[packageName]
指定パッケージのバックアップ履歴を Review/Pull/Delete ボタン付き Grid で表示する。
`ClaudeBackupDataset[]` で全パッケージのバックアップ履歴を表示。

### ClaudeMigrateBackupHistory[packageName]
既存 history 内の生 .wl バックアップを差分形式 (.wl.cz / .wl.cdiff) に変換して容量を削減する。
`ClaudeMigrateBackupHistory[packageName, DryRun -> True]` で削除せず容量削減見積もりを表示。
`ClaudeMigrateBackupHistory[]` で全パッケージに対して実行。

### ClaudeConvertToPaclet[packageName]
$packageDirectory の packageName.wl を Paclet 形式に変換する。packageName/ フォルダを作成し Kernel/, Documentation/, PacletInfo.wl 等を生成する。元の .wl ファイルはバックアップ後に削除される。

## ドキュメント生成

### ClaudeCreateDocumentation["packageName", opts]
パッケージの詳細なドキュメント一式を Claude で自動生成する。単一 .wl の場合は $packageDirectory/packageName_info/docs/ に出力、Paclet は $packageDirectory/packageName/docs/ に出力。
Options: References -> {} (URL や書籍名リスト→README に参考文献セクション追加), Demos -> {} (デモ動画 URL リスト→README に反映), Disclaimer -> {} (免責事項追加文言リスト), Acknowledgments -> {} (謝辞セクション追加文言リスト), License -> "" (空文字列で MIT 自動挿入、文字列指定でカスタムライセンス)

### ClaudeUpdateDocumentation["packageName", opts]
### ClaudeUpdateDocumentation["packageName", "更新指示", opts]
ソース差分に基づき全ドキュメントを自動更新する。ノートブックのコンテキストも参照可能（「上で議論されている内容を反映して」など）。
Options: TargetFiles -> Automatic (自動判定) または {"api.md"} 等でファイル指定, Mode -> "Update" (既存更新) または "Create" (新規作成), References -> {}, Demos -> {}, Disclaimer -> {}, Acknowledgments -> {}, License -> ""

例: `ClaudeUpdateDocumentation["claudecode", "api.mdのみ更新して"]`
例: `ClaudeUpdateDocumentation["pkg", "...", TargetFiles -> {"api.md"}]`

## セッション管理

### CreateClaudeSession["name"] → session
名前付きセッションを作成する（デフォルト履歴を継承）。
`CreateClaudeSession[session]` は既存セッションの履歴を継承した新セッションを作成。
`CreateClaudeSession[]` はデフォルト履歴を継承した新セッションを作成。
`CreateClaudeSession[Inherit -> False]` は独立したセッションを作成。

### ClaudeRestoreSession[]
デフォルトセッションをリストアする。`ClaudeRestoreSession["name"]` で指定名のセッションをリストア。

### ClaudeListSessions[]
ノートブック内の全セッションを一覧表示する。

### ClaudeDeleteSession["name"]
指定名のセッションを削除する。`ClaudeDeleteSession["name", "All"]` でセッションと全履歴を削除。

### ClaudeShowHistory[]
デフォルトセッションの履歴を表示する。`ClaudeShowHistory[session]` または `ClaudeShowHistory["name"]` で指定セッションの履歴を表示。

### ClaudeCompactHistory[]
デフォルトセッションの履歴を手動でコンパクションする。`ClaudeCompactHistory[name]` で指定セッションをコンパクション。通常は 2n+1+w エントリを超えたときに自動実行される。

### ClaudeHistorySize[] → Association
現在のノートブックのセッション履歴サイズを診断する。Entries・ByteCount・KiloBytes・Status を含む Association を返す。200KB 超でコンパクション推奨、500KB 超で危険。

## セッションアタッチメント

### ClaudeAttach[path]
デフォルトセッションに参考資料をアタッチする。`ClaudeAttach[session, path]` で指定セッションにアタッチ。アタッチされたファイルは ClaudeQuery/ClaudeEval 時に自動的に Read される。

### ClaudeDetach[path]
デフォルトセッションからファイルをデタッチする。`ClaudeDetach[session, path]` で指定セッションからデタッチ。

### ClaudeAttachments[] → List
デフォルトセッションのアタッチメント一覧を返す。`ClaudeAttachments[session]` で指定セッションの一覧を返す。

### ClearAttachments[]
デフォルトセッションの全アタッチメントをクリアする。`ClearAttachments[session]` で指定セッションをクリア。

## 機密管理

### Confidential[expr]
式を評価し、その Input/Output セルを自動的に機密マークする。
例: `Confidential[secretData = Import["secret.csv"]]`

### NonConfidential[expr]
式を評価し、その Input/Output セルの機密マークを明示的に解除する。秘密変数や秘密依存変数の値に依存していても、機密解除として扱う。
例: `result = NonConfidential[Mean[secretData]]`

### MarkConfidential[]
現在のセルを機密マークする。`MarkConfidential[cell]` で指定セルを機密マーク。機密セルは ClaudeEval/ClaudeQuery のプロンプトから除外される。

### UnmarkConfidential[]
現在のセルの機密マークを解除する。`UnmarkConfidential[cell]` で指定セルのマークを解除。

### IsConfidential[cell] → True|False
セルが機密マークされているかを返す。`IsConfidential[]` で現在のセルが機密かを返す。

### ScanConfidentialCells[]
ノートブック全セルをスキャンし、機密変数を参照するセルを自動的に機密マークする。明示的に UnmarkConfidential されたセルはスキップされる。

## Claude Directives 管理

### ClaudeAddDirective[target, description]
Claude で description を整形し、Claude Directives フォルダのファイルに追加して InstallClaudeDirectives[] を実行する。target は "CLAUDE.md" またはスキル名（例: "wolfram-general"）。元ファイルは自動バックアップされる。

### ClaudeRestoreDirective[target]
ClaudeAddDirective の直前のバックアップを復元し InstallClaudeDirectives[] を実行する。target は "CLAUDE.md" またはスキル名。

### ClaudeListDirectives[]
Claude Directives フォルダの CLAUDE.md と全スキルの一覧を表示する。

### ClaudeUpdateDirective[]
ソースコードと Claude Directives の整合性をチェックし、不整合を自動修正する。
`ClaudeUpdateDirective[text]` は text の内容を Claude で解釈し、CLAUDE.md / rules / skills の適切なファイルに反映する。ノートブックのコンテキストも参照可能。

### ClaudeDirectiveBackupDataset[]
Claude Directives の更新履歴を Review/Pull/Delete ボタン付き Grid で表示する。履歴は ClaudeUpdateDirective[text] や ClaudeAddDirective の実行時に自動保存される。

### ClaudeSyncDirectives[dir]
指定ディレクトリ dir のファイルを Claude Directives フォルダと比較し、dir 側が新しいファイルで Claude Directives を更新する。dir にだけ存在するファイルもコピーする。Claude Directives 側にしかないファイルはそのまま。
例: `ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]`

## Web 検索・取得

### ClaudeWebSearch[query] → String
Web 検索を実行し、結果をテキストで返す。Anthropic API の web_search ツールを使用する。

### ClaudeWebFetch[url] → String
指定 URL の内容を取得し、要約・抽出して返す。`ClaudeWebFetch[url, prompt]` は取得内容に対して prompt の指示を実行する。

## 状態確認・制御

### ClaudeStatus[]
実行中の全 Claude タスクのリアルタイム状態を表示する。各タスクの経過時間、現在の状態（思考中/テキスト生成中/ツール実行中）、生成済みテキスト断片数、思考断片数、ツール使用数を表示する。実行中タスクがない場合はその旨を表示する。

### ClaudeAbort[]
実行中の全 Claude タスクを停止する。Claude Code プロセスの強制終了、ScheduledTask の停止、フォールバックタスクのキャンセルを行う。パレットの「実行停止」ボタンからも呼び出し可能。

### ClaudeSessionStatus[]
デフォルトセッションの状態を表示する。`ClaudeSessionStatus[name]` で指定名のセッションの状態を表示。アクセス可能ディレクトリ・アタッチメント・作業ディレクトリのファイル等を確認できる。

### ClaudeQueryShowContext[]
デバッグ用: 次の ClaudeQuery が送信するノートブックコンテキストを表示する。

### ClaudeShowAccessConfig[]
デバッグ用: Claude Code のファイルアクセス設定を表示する。$ClaudeAccessibleDirs・NBGetAccessibleDirs[]・生成される settings.json・CLI フラグを確認できる。

### ShowClaudePalette[]
Claude Code 操作用のパレットを表示する。

## NBAccess 分離検証

### ClaudeCheckSeparation[target]
target のコードが NBAccess の分離原則に違反している箇所をリストアップする。target はファイルパス、$packageDirectory の .wl 名、またはパクレット名。$ClaudeTestModel のモデルで検査する。
検査対象: SystemCredential 直接利用、CellObject 直接操作、CellEpilog/CellProlog/NotebookEventActions 直接操作、NBAccess`Private`関数呼び出し、NBAccess 公開グローバル直接更新、EvaluationCell[]/CellPrint[]/SetSelectedNotebook[] 直接使用、CurrentValue/SetOptions による TaggingRules/CellTags/CellEpilog 属性直接アクセス、CellObject の公開 API・戻り値・状態保持への漏洩、SelectionEvaluate/FrontEndTokenExecute 等 FE 状態操作、NBAccess 公開グローバルの破壊的更新 (AppendTo/AssociateTo 等)。
例: `ClaudeCheckSeparation["claudecode"]`

### ClaudeFixSeparation[target]
分離違反を修正する。target がファイルパスの場合はバックアップを作成して元ファイルを修正。target がパッケージ名のみの場合は ClaudeUpdatePackage を呼び出す。事前に ClaudeCheckSeparation の結果があればそれを利用する。

## コミット準備

### ClaudePrepareCommit[packageName, opts]
前回の GitHub コミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを生成して GitHubRefreshAndCommit 実行コマンドを Input セルとして出力する。
`ClaudePrepareCommit[packageName, subject]` は1行目を指定し、本文は自動収集する。
Options: Fallback -> False, DryRun -> False (True でコマンドを生成せずメッセージのみ返す), Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, BaseBranch -> Automatic

## CLI コマンド

### ClaudeCommand["/command"] → String
Claude Code CLI のスラッシュコマンドを実行して結果を返す。スラッシュコマンド (/始まり) は node-pty 経由で対話モードに送信される。CLI サブコマンド (例: config list) は直接実行される。
例: `ClaudeCommand["/help"]`, `ClaudeCommand["/permissions"]`, `ClaudeCommand["config list"]`, `ClaudeCommand["--version"]`

## グローバル変数

### $ClaudeModel
型: String, 初期値: ""
Claude CLI に渡すモデル名。"" は省略時 Claude Code 自身のデフォルトモデルを使用。例: `$ClaudeModel = "claude-opus-4-6"`

### $ClaudePrivateModel
型: List, 初期値: なし
秘密データ処理用のローカルモデル指定。AutoPrivate -> True 時に秘密変数を含むタスクの生成コードに使用される。形式: {"provider", "modelName"} または {"provider", "modelName", "url"}。例: `$ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}`

### $ClaudeTestModel
型: String, 初期値: $ClaudeModel と同じ
分離検証などのテスト用モデル名。別モデルで客観的に検証するために変更可能。例: `$ClaudeTestModel = "claude-sonnet-4-6"`

### $ClaudeFallbackModels
型: List, 初期値: {{"anthropic", $iModelOpus}, {"openai", "gpt-5"}}
フォールバックモデル優先順位。各要素は {"provider", "modelName"} または {"provider", "modelName", "url"} の形式。内部的には NBAccess`NBSetFallbackModels に同期される。例: `$ClaudeFallbackModels = {{"anthropic","claude-opus-4-6"},{"lmstudio","gpt-oss-20b","http://127.0.0.1:1234"}}`

### $ClaudeTimeout
型: Number, 初期値: 1200
ClaudeQuery・ClaudeEval 等のタイムアウト秒数。例: `$ClaudeTimeout = 900`

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code を起動する作業ディレクトリ。このディレクトリ配下の .claude/CLAUDE.md, .claude/rules/, .claude/skills/ を Claude Code に読ませる。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索されるか手動で上書きできる。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。内容が空の場合、CLAUDE.md が見つからなかったか内容がない。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。iPrepareClaudeProjectDirectory が一時的に settings.json に Read 許可を注入する。ノートブックの TaggingRules にも NBSetAccessibleDirs で永続化可能。NotebookDirectory は初回使用時にダイアログで許可を確認（$packageDirectory 配下を除く）。例: `$ClaudeAccessibleDirs = {$packageDirectory, "F:\\Dropbox\\Mathematica-oneDrive"}`

### $ClaudeDocModel
型: String, 初期値: Sonnet 系最新モデル
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
ClaudeEval が再帰的に ClaudeEval を生成する際の最大深度。0 で再帰禁止。値を大きくすると多段階の自動タスク連鎖が可能。

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
外部パッケージがキーワードを登録するための Association。プロンプトにキーワードが含まれると、対応パッケージの api.md がコンテキストに自動注入される。各パッケージが自身のロード時に登録する。claudecode.wl 側はパッケージ非依存。例: `$ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒切"}`

## オプション

### Fallback -> False
ClaudeQuery/ClaudeEval/ContinueEval/ClaudeUpdatePackage のオプション。True: Claude Code 利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。False (デフォルト): エラーをそのまま返す。

### AutoPrivate -> False
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: 秘密変数にアクセスするタスクの場合、生成コードに Model -> $ClaudePrivateModel, PrivacySpec -> Automatic を付与する。

### AutoEvaluate -> True
ClaudeEval のオプション。False で生成された Input セルの自動実行を抑制する。

### StartTime -> Now
ClaudeEval/ContinueEval/ClaudeUpdatePackage のオプション。DateObject で実行開始時刻を指定。例: `StartTime -> Now + Quantity[3,"Hours"]`

### RepeatInterval -> None
ClaudeEval 専用オプション。Quantity で繰り返し実行間隔を指定。例: `RepeatInterval -> Quantity[2,"Hours"]`、`RepeatInterval -> {Quantity[1,"Hours"], 5}` で最大5回。TaskObject が返るので TaskRemove[] で停止可能。

### Timeout -> Automatic
ClaudeEval/ContinueEval のオプション。API フォールバックのタイムアウト秒数を指定。Automatic は $iFallbackTimeout (600秒)。

### TargetFunctions -> Automatic
ClaudeUpdatePackage のオプション。対象関数を限定する。

### TargetFiles -> Automatic
ClaudeUpdateDocumentation のオプション。自動判定または {"api.md"} 等でファイルを指定。

### Mode -> "Update"
ClaudeUpdateDocumentation のオプション。"Update" (既存更新) または "Create" (新規作成)。

### DryRun -> False
ClaudeMigrateBackupHistory/ClaudePrepareCommit のオプション。True でコマンドを生成せず結果のみ返す。

### WebSearch -> True
ClaudeQuery/ClaudeEval のオプション。True (デフォルト): Claude Code CLI の組み込み Web 検索ツールを許可する。False: Web 検索を禁止する。API 経由の課金は発生しない（WebFetch とは異なる）。

### WebFetch -> False
ClaudeQuery/ClaudeEval のオプション。True: API 経由で Web 取得を行う（課金あり）。Fallback -> True の場合のみ有効。Automatic (ClaudeEval のデフォルト): Claude がタスクを分析し必要なら自動で Web 検索する。ClaudeQuery のデフォルトは False。

### References -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。URL や書籍名のリストを指定すると README.md に参考文献セクションを追加する。例: `References -> {"https://...", "書籍名"}`

### Demos -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。デモ動画や使用例の URL リストを指定すると README.md に反映する。例: `Demos -> {"https://youtu.be/...", "https://example.com/demo.nb"}`

### Disclaimer -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。免責事項セクションに追加する文言のリストを指定する。例: `Disclaimer -> {"本ツールは研究目的専用です"}`

### Acknowledgments -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。謝辞セクションに追加する文言のリストを指定する。指定時は README.md の免責事項の前に配置。例: `Acknowledgments -> {"本研究は JSPS 科研費の助成を受けた"}`

### License -> ""
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。空文字列 (デフォルト): GitHubREST`$GitHubLicenseHolder が非空なら MIT ライセンスを自動挿入。文字列指定: そのままライセンステキストとして挿入。例: `License -> "MIT"`, `License -> "Apache-2.0 License..."`

### Owner -> Automatic
ClaudePrepareCommit のオプション。GitHub リポジトリのオーナーを指定。

### Repository -> Automatic
ClaudePrepareCommit のオプション。GitHub リポジトリ名を指定。

### Branch -> Automatic
ClaudePrepareCommit のオプション。コミット先ブランチを指定。

### BaseBranch -> Automatic
ClaudePrepareCommit のオプション。PR のベースブランチを指定。

### Inherit -> True
CreateClaudeSession のオプション。False で独立したセッションを作成する（デフォルト履歴を継承しない）。