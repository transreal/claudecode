# ClaudeCode API Reference

## 概要

Mathematica ノートブックから Claude Code CLI を呼び出すパッケージ。非同期コード生成・実行、パッケージ管理、ドキュメント生成、秘密データ管理を提供する。

## クエリ・評価

### ClaudeQuery[prompt] → String
Claude Code に prompt を送り、応答文字列を同期で返す。
Options: WebSearch -> True (CLI組み込み検索, 無料), WebFetch -> False (API経由取得, 課金あり・Fallback->True必須), Fallback -> False, Timeout -> Automatic
`ClaudeQuery[session, prompt]` はセッション履歴付きで実行。
`ClaudeQuery[{text, Image[...], File[path], ...}]` でマルチモーダル入力（画像・PDF・音声をAPIに直接送信）。

### ClaudeMath[task] → String
Mathematica コード生成に特化したプロンプトで Claude を呼び出す。

### ClaudeExtractCode[response] → String
Claude 応答から最初の ` ```mathematica ` ブロックを抽出する。

### ClaudeExtractAllCode[response] → List
Claude 応答から全 ` ```mathematica ` ブロックをリストで返す。

### ClaudeEval[task, opts]
コードを非同期で生成・表示し、デフォルトセッションに履歴を保存する。
`ClaudeEval[{text, data, ...}]` でテキスト・Dataset・Image・一般式を混在指定可。
`ClaudeEval[session, task]` で指定セッションに履歴を保存。
→ TaskObject (RepeatInterval 指定時) または Null
Options: AutoEvaluate -> True (生成 Input セルの自動実行), StartTime -> Now (DateObject で遅延実行), RepeatInterval -> None (繰り返し実行。例: Quantity[2,"Hours"] または {Quantity[1,"Hours"],5} で最大5回), Timeout -> Automatic, Fallback -> False, AutoPrivate -> False, WebSearch -> True, WebFetch -> False
例: `ClaudeEval["グラフを描いて", RepeatInterval -> Quantity[2, "Hours"]]`
例: `ClaudeEval["処理して", StartTime -> Now + Quantity[3, "Hours"]]`

### ContinueEval[instruction, opts]
デフォルトセッションで続きを実行。
`ContinueEval[session, instruction]` で指定セッションを続行。
`ContinueEval[]` は「エラーを修正してください」で続行。
Options: StartTime -> Now, Timeout -> Automatic, Fallback -> False

### ContinueUpdate[opts]
直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を続ける。
`ContinueUpdate["instruction"]` で追加指示付き続行。
`ContinueUpdate["pkgName", "instruction"]` で指定パッケージの直前の更新を続行。
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now

### ClaudeSpec[task] → Null
ノートブック内容からプログラムの仕様を生成する。`ClaudeSpec[{task, image, ...}]` で画像付き仕様生成。パレットからセル選択で呼び出し可。

### ClaudeDebug[codeOrFile, errorMsg] → Null
デバッグ支援を非同期で求める（即座に返る）。

### ClaudeReview[codeOrFile] → Null
コードのレビューを非同期で行う（30000文字超は自動チャンク分割）。

### ClaudeReviewChunked[codeOrFile] → Null
ファイルをチャンク分割して非同期レビューする。

## パッケージ管理

### ClaudeCreatePackage[name, prompt] → Null
prompt に従って name.wl を新規作成し $packageDirectory に保存する。

### ClaudeUpdatePackage[packageName, prompt, opts]
$packageDirectory の packageName.wl を Claude の支援でアップデートし、バックアップを作成する。
prompt には文字列または `{文字列, Image, File["...pdf"], ...}` を指定可。
→ Null
Options: TargetFunctions -> Automatic, StartTime -> Now, "UpdateApiMd" -> True ("UpdateApiMd"->False で api.md 自動更新をスキップ)
例: `ClaudeUpdatePackage["pkg", "修正指示", StartTime -> Now + Quantity[1, "Hours"]]`

### ClaudeRestorePackage[packageName] → Null
直前のバックアップを復元する。

### ClaudeUpdatePackageHistory[] → List
全パッケージの ClaudeUpdatePackage 呼び出し履歴を表示しリストで返す。各エントリは `<|"Package"->..., "Timestamp"->..., "Directory"->...|>`。
`ClaudeUpdatePackageHistory[packageName]` で指定パッケージのみ。

### ClaudeBackupDataset[packageName] → Notebook
指定パッケージのバックアップ履歴を Review/Pull/Delete ボタン付き Grid で表示する。Review でバックアップ内容確認、Pull で復元、Delete で履歴削除。
`ClaudeBackupDataset[]` で全パッケージのバックアップ履歴を表示。

### ClaudeMigrateBackupHistory[packageName, opts] → Null
既存の生 .wl バックアップを差分形式 (.wl.cz / .wl.cdiff) に変換して容量を削減する。
`ClaudeMigrateBackupHistory[]` で全パッケージに対して実行。
Options: DryRun -> False (True で削除せず見積もり表示)

### ClaudeConvertToPaclet[packageName] → Null
$packageDirectory の packageName.wl を Paclet 形式に変換する。packageName/ フォルダを作成し Kernel/, Documentation/, PacletInfo.wl 等を生成する。元の .wl ファイルはバックアップ後に削除される。

## ドキュメント生成

### ClaudeCreateDocumentation["packageName", opts] → Null
パッケージの詳細なドキュメント一式を Claude で自動生成する。
単一 .wl: `$packageDirectory/packageName_info/docs/` に出力。
Paclet: `$packageDirectory/packageName/docs/` に出力。
Options: References -> {} (URL や書籍名のリスト→README.md参考文献に追加), Demos -> {} (デモ動画URLリスト→README.mdに反映), Disclaimer -> {} (免責事項追加文言リスト), Acknowledgments -> {} (謝辞追加文言リスト), License -> "" (空文字で$GitHubLicenseHolder設定済みなら MIT 自動挿入、文字列指定でカスタムライセンス), Model -> $ClaudeDocModel

### ClaudeUpdateDocumentation["packageName", opts]
ソース差分に基づき全ドキュメントを自動更新する。
`ClaudeUpdateDocumentation["packageName", "更新指示"]` で指示に従って更新。
ノートブックのコンテキストも参照可能（「上で議論されている内容を反映して」など）。
→ Null
Options: TargetFiles -> Automatic (自動判定。例: {"api.md"} でファイル指定), Mode -> "Update" ("Create" で新規作成), References -> {}, Demos -> {}, Disclaimer -> {}, Acknowledgments -> {}, License -> ""
例: `ClaudeUpdateDocumentation["claudecode", "api.mdのみ更新して"]`
例: `ClaudeUpdateDocumentation["pkg", "...", TargetFiles -> {"api.md"}]`

## Directives 管理

### ClaudeAddDirective[target, description] → Null
description を Claude で整形し Claude Directives フォルダのファイルに追加して InstallClaudeDirectives[] を実行する。target は "CLAUDE.md" またはスキル名（例: "wolfram-general"）。元ファイルは自動バックアップされる。

### ClaudeRestoreDirective[target] → Null
ClaudeAddDirective の直前のバックアップを復元し InstallClaudeDirectives[] を実行する。target は "CLAUDE.md" またはスキル名。

### ClaudeListDirectives[] → Null
Claude Directives フォルダの CLAUDE.md と全スキルの一覧を表示する。

### ClaudeUpdateDirective[text, opts] → Null
ソースコードと Claude Directives の整合性をチェックし不整合を自動修正する。
`ClaudeUpdateDirective[text]` は text の内容を Claude で解釈し CLAUDE.md / rules / skills の適切なファイルに反映する。ノートブックのコンテキストも参照可能。

### ClaudeDirectiveBackupDataset[] → Notebook
Claude Directives の更新履歴を Review/Pull/Delete ボタン付き Grid で表示する。履歴は ClaudeUpdateDirective[text] や ClaudeAddDirective 実行時に自動保存される。

### ClaudeSyncDirectives[dir] → Null
指定ディレクトリ dir のファイルを Claude Directives フォルダと比較し、dir 側が新しいファイルで Claude Directives を更新する。dir にだけ存在するファイルもコピーする。Claude Directives 側にしかないファイルはそのまま。
例: `ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]`

## セッション管理

### CreateClaudeSession["name"] → Session
名前付きセッションを作成する（デフォルト履歴を継承）。
`CreateClaudeSession[session]` は既存セッションの履歴を継承した新セッションを作成。
`CreateClaudeSession[]` はデフォルト履歴を継承した新セッションを作成。
Options: Inherit -> True (False で独立したセッションを作成)

### ClaudeRestoreSession["name"] → Null
指定名のセッションをリストアする。`ClaudeRestoreSession[]` でデフォルトセッションをリストア。

### ClaudeListSessions[] → Null
ノートブック内の全セッションを一覧表示する。

### ClaudeDeleteSession["name"] → Null
指定名のセッションを削除する。`ClaudeDeleteSession["name", "All"]` でセッションと全履歴を削除。

### ClaudeShowHistory[session] → Null
指定セッションの履歴を表示する。`ClaudeShowHistory[]` でデフォルトセッション、`ClaudeShowHistory["name"]` で指定名のセッションの履歴を表示。

### ClaudeCompactHistory["name"] → Null
指定セッションの履歴を手動でコンパクションする。`ClaudeCompactHistory[]` でデフォルトセッション。通常は履歴が 2n+1+w エントリを超えたときに自動実行される。

### ClaudeHistorySize[] → Association
現在のノートブックのセッション履歴サイズを診断する。Entries・ByteCount・KiloBytes・Status を含む Association を返す。200KB 超でコンパクション推奨、500KB 超で危険。

## アタッチメント

### ClaudeAttach[path] → Null
デフォルトセッションに参照資料をアタッチする。アタッチされたファイルは ClaudeQuery/ClaudeEval 時に自動的に Read される。`ClaudeAttach[session, path]` で指定セッションにアタッチ。

### ClaudeDetach[path] → Null
デフォルトセッションからファイルをデタッチする。`ClaudeDetach[session, path]` で指定セッションから。

### ClaudeAttachments[] → List
デフォルトセッションのアタッチメント一覧を返す。`ClaudeAttachments[session]` で指定セッション。

### ClearAttachments[] → Null
デフォルトセッションの全アタッチメントをクリアする。`ClearAttachments[session]` で指定セッション。

## 秘密データ管理

### Confidential[expr] → expr の評価結果
式を評価し、その Input/Output セルを自動的に秘密マークする。
例: `Confidential[secretData = Import["secret.csv"]]`

### NonConfidential[expr] → expr の評価結果
式を評価し、その Input/Output セルの秘密マークを明示的に解除する。秘密変数や秘密依存変数の値に依存していても秘密解除として扱う。
例: `result = NonConfidential[Mean[secretData]]`

### MarkConfidential[] → Null
現在のセルを秘密マークする。`MarkConfidential[cell]` で指定セルを秘密マーク。秘密セルは ClaudeEval/ClaudeQuery のプロンプトから除外される。

### UnmarkConfidential[] → Null
現在のセルの秘密マークを解除する。`UnmarkConfidential[cell]` で指定セル。

### IsConfidential[cell] → True | False
セルが秘密マークされているかを返す。`IsConfidential[]` で現在のセル。

### ScanConfidentialCells[] → Null
ノートブック全セルをスキャンし、秘密変数を参照するセルを自動的に秘密マークする。明示的に UnmarkConfidential されたセルはスキップされる。

## 状態・デバッグ

### ShowClaudePalette[] → Null
Claude Code 操作用のパレットを表示する。

### ClaudeQueryShowContext[] → Null
デバッグ用: 次の ClaudeQuery が送信するノートブックコンテキストを表示する。

### ClaudeShowAccessConfig[] → Null
デバッグ用: Claude Code のファイルアクセス設定を表示する。$ClaudeAccessibleDirs, NBGetAccessibleDirs[], 生成される settings.json, CLI フラグを確認可能。

### ClaudeSessionStatus[] → Null
デフォルトセッションの状態を表示する。アクセス可能ディレクトリ・アタッチメント・作業ディレクトリのファイル等を確認可能。`ClaudeSessionStatus[name]` で指定名のセッション。

### ClaudeStatus[] → Null
実行中の全 Claude タスクのリアルタイム状態を表示する。各タスクの経過時間・現在の状態（思考中/テキスト生成中/ツール実行中）・生成済みテキスト断片数・思考断片数・ツール使用数を表示。実行中タスクがない場合はその旨を表示。

### ClaudeAbort[] → Null
実行中の全 Claude タスクを停止する。Claude Code プロセスの強制終了・ScheduledTask の停止・フォールバックタスクのキャンセルを行う。パレットの「実行停止」ボタンからも呼び出し可能。

### ClaudeCommand["/command"] → String
Claude Code CLI のスラッシュコマンドを実行し結果を返す。スラッシュコマンド (/始まり) は node-pty 経由で対話モードに送信される。CLI サブコマンド (例: config list) は直接実行される。
例: `ClaudeCommand["/help"]`, `ClaudeCommand["/permissions"]`, `ClaudeCommand["config list"]`, `ClaudeCommand["--version"]`

## Web アクセス

### ClaudeWebSearch[query] → String
Web 検索を実行し結果をテキストで返す。Anthropic API の web_search ツールを使用する。

### ClaudeWebFetch[url] → String
指定 URL の内容を取得し要約・抽出して返す。`ClaudeWebFetch[url, prompt]` は取得内容に対して prompt の指示を実行する。

## NBAccess 分離検証

### ClaudeCheckSeparation[target] → List
target のコードが NBAccess の分離原則に違反している箇所をリストアップする。target はファイルパス・$packageDirectory の .wl 名・パクレット名。$ClaudeTestModel のモデルで検査する。
検査対象: SystemCredential直接利用, CellObject直接操作, CellEpilog/CellProlog/NotebookEventActions直接操作, NBAccess`Private`関数呼び出し, NBAccess公開グローバル直接更新, EvaluationCell[]/CellPrint[]/SetSelectedNotebook[]直接使用, TaggingRules/CellTags/CellEpilog属性直接アクセス, CellObjectの公開API・戻り値・状態保持への漏洩, SelectionEvaluate/FrontEndTokenExecute等FE状態操作, NBAccess公開グローバルの破壊的更新
例: `ClaudeCheckSeparation["claudecode"]`

### ClaudeFixSeparation[target] → Null
分離違反を修正する。target がファイルパスの場合: バックアップを作成し元ファイルを修正。target がパッケージ名のみの場合: ClaudeUpdatePackage を呼び出す。事前に ClaudeCheckSeparation の結果があればそれを利用する。

## コミット準備

### ClaudePrepareCommit[packageName, opts]
前回の GitHub コミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを生成して GitHubRefreshAndCommit 実行コマンドを Input セルとして出力する。
`ClaudePrepareCommit[packageName, subject]` は1行目を指定し、本文は自動収集。
→ Null
Options: Fallback -> False, DryRun -> False (True でコマンドを生成せずメッセージのみ返す), Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, BaseBranch -> Automatic

## グローバル変数

### $ClaudeModel
型: String, 初期値: ""
Claude CLI に渡すモデル名。"" は省略時 Claude Code 自身のデフォルトモデルを使用。例: `$ClaudeModel = "claude-opus-4-6"`

### $ClaudePrivateModel
型: List, 初期値: Undefined
秘密データ処理用のローカルモデル指定。AutoPrivate -> True 時に秘密変数を含むタスクの生成コードに使用される。形式: `{"provider", "modelName"}` または `{"provider", "modelName", "url"}`
例: `$ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}`

### $ClaudeTimeout
型: Integer, 初期値: 1200
ClaudeQuery・ClaudeEval 等のタイムアウト秒数。

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
Claude Code に Read 許可する追加ディレクトリリスト。iPrepareClaudeProjectDirectory が一時的に settings.json に Read 許可を注入する。ノートブックの TaggingRules に NBSetAccessibleDirs で永続化可能。NotebookDirectory は初回使用時にダイアログで許可を確認する（$packageDirectory 配下を除く）。
例: `$ClaudeAccessibleDirs = {$packageDirectory, "F:\\Dropbox\\Mathematica-oneDrive"}`

### $ClaudeFallbackModels
型: List, 初期値: {{"anthropic", "claude-opus-4-6"}, {"openai", "gpt-5"}}
フォールバックモデル優先順位。各要素は `{"provider", "modelName"}` または `{"provider", "modelName", "url"}` の形式。内部的に NBAccess`NBSetFallbackModels に同期される。
例: `$ClaudeFallbackModels = {{"anthropic","claude-opus-4-6"},{"lmstudio","gpt-oss-20b","http://127.0.0.1:1234"}}`

### $ClaudeDocModel
型: String, 初期値: 最新 Sonnet モデル
ドキュメント生成・更新時に使用するモデル。"" で $ClaudeModel と同じモデルを使用。
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

### $ClaudeTestModel
型: String, 初期値: $ClaudeModel と同じ
分離検証などのテスト用モデル名。別モデルで客観的に検証するために変更可能。
例: `$ClaudeTestModel = "claude-sonnet-4-6"`

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval が再帰的に ClaudeEval を生成する際の最大深度。0 で再帰禁止。値を大きくすると多段階の自動タスク連鎖が可能。

### $ClaudePackageKeywordMap
型: Association, 初期値: `<||>`
外部パッケージがキーワードを登録するための Association。プロンプトにキーワードが含まれると対応パッケージの api.md がコンテキストに自動注入される。各パッケージが自身のロード時に登録する。claudecode.wl 側はパッケージ非依存。
例: `$ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒切"}`

## オプション

### Fallback -> False
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: Claude Code 利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。False (デフォルト): エラーをそのまま返す。

### AutoEvaluate -> True
ClaudeEval のオプション。生成された Input セルの自動実行を制御する。

### AutoPrivate -> False
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: 秘密変数にアクセスするタスクの場合、生成コードに Model -> $ClaudePrivateModel, PrivacySpec -> Automatic を付与する。

### StartTime -> Now
ClaudeEval/ContinueEval/ClaudeUpdatePackage 等のオプション。DateObject で実行開始時刻を指定。
例: `StartTime -> Now + Quantity[3, "Hours"]`

### RepeatInterval -> None
ClaudeEval のみのオプション。繰り返し実行間隔を Quantity で指定。`{Quantity[1,"Hours"], 5}` で最大5回。TaskObject が返るので TaskRemove[] で停止可能。

### Timeout -> Automatic
ClaudeQuery/ClaudeEval/ContinueEval 等のオプション。API フォールバックのタイムアウト秒数。Automatic は内部デフォルト (600秒)。

### WebSearch -> True
ClaudeQuery/ClaudeEval のオプション。True (デフォルト): Claude Code CLI の組み込み Web 検索ツールを許可する。False: 禁止する。これは Claude Code 自体の Web 検索機能であり API 経由の課金は発生しない。WebFetch (課金あり) とは異なる。

### WebFetch -> False
ClaudeQuery/ClaudeEval のオプション。True: 必ず Web 検索を行う。False: 行わない。Automatic (ClaudeEval デフォルト): Claude がタスクを分析し必要なら自動で Web 検索する。重要: WebFetch は Anthropic API 経由で課金が発生するため Fallback -> True の場合のみ有効。

### TargetFiles -> Automatic
ClaudeUpdateDocumentation のオプション。自動判定または `{"api.md"}` 等でファイルを指定。

### TargetFunctions -> Automatic
ClaudeUpdatePackage のオプション。更新対象の関数を指定。

### Mode -> "Update"
ClaudeUpdateDocumentation のオプション。"Update" (既存更新) または "Create" (新規作成)。

### DryRun -> False
ClaudeMigrateBackupHistory / ClaudePrepareCommit のオプション。True でコマンドを生成せず見積もり・メッセージのみ返す。

### Inherit -> True
CreateClaudeSession のオプション。False で独立したセッションを作成する。

### References -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。URL や書籍名のリストを指定すると README.md に参考文献セクションを追加する。

### Demos -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。デモ動画や使用例の URL リストを指定すると README.md に反映する。

### Disclaimer -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。免責事項セクションに追加する文言のリスト。

### Acknowledgments -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。謝辞セクションに追加する文言のリスト。指定時は README.md の免責事項の前に配置される。

### License -> ""
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。空文字列 (デフォルト): GitHubREST`$GitHubLicenseHolder が非空なら MIT ライセンスを自動挿入。文字列指定: そのままライセンステキストとして挿入。

### Owner -> Automatic / Repository -> Automatic / Branch -> Automatic / BaseBranch -> Automatic
ClaudePrepareCommit のオプション。GitHub リポジトリ情報を手動指定する場合に使用。