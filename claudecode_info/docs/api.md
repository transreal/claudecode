# claudecode API Reference

パッケージ `ClaudeCode`` の LLM 向け API リファレンス。Wolfram Language から Claude Code CLI および Anthropic API を呼び出すためのインターフェース。

## 読み込み

```mathematica
Block[{$CharacterEncoding = "UTF-8"}, Needs["ClaudeCode`", "claudecode.wl"]]
```

依存: [NBAccess](https://github.com/transreal/NBAccess) (NBAccess.wl), [GitHubREST](https://github.com/transreal/github) (github.wl)

## グローバル変数

### $ClaudeModel
型: String, 初期値: ""
Claude CLI に渡すモデル名。"" のとき Claude Code 自身のデフォルトモデルを使用。
例: `$ClaudeModel = "claude-opus-4-6"`

### $ClaudePrivateModel
型: List, 初期値: {"lmstudio", ...}
秘密データ処理用ローカルモデル指定。`AutoPrivate -> True` 時に機密変数を含むタスクの生成コードに使用される。
例: `$ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}`

### $ClaudeTimeout
型: Integer, 初期値: 1200
ClaudeQuery・ClaudeEval 等のタイムアウト秒数。

### $ClaudeVerbose
型: Boolean, 初期値: False
True: 履歴コンパクション等の詳細ログを Messages に出力。False: 重大エラー以外の ClaudeCode ログを抑制。

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code を起動する作業ディレクトリ。配下の `.claude/CLAUDE.md`, `.claude/rules/`, `.claude/skills/` を Claude Code に読ませる。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索されるか、手動で上書きできる。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。空の場合、CLAUDE.md が見つからなかったか内容がない。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。`iPrepareClaudeProjectDirectory` が一時的に settings.json に Read 許可を注入する。NotebookDirectory は初回使用時にダイアログで許可を確認する（$packageDirectory 配下を除く）。
例: `$ClaudeAccessibleDirs = {$packageDirectory, "C:\\Users\\...\\作業フォルダ"}`

### $ClaudeFallbackModels
型: List, 初期値: {{"anthropic", $iModelOpus}, {"openai", "gpt-5"}}
フォールバックモデル優先順位。各要素は `{"provider", "modelName"}` または `{"provider", "modelName", "url"}` の形式。内部的に `NBAccess`NBSetFallbackModels` に同期される。

### $ClaudeDocModel
型: String, 初期値: $iModelSonnet
ドキュメント生成・更新時に使用するモデル。"" で $ClaudeModel と同じモデルを使用。

### $ClaudeDocRetryDelay
型: Number, 初期値: 60
ドキュメント生成のリトライ待機秒数。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
ドキュメント生成の最大リトライ回数。

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースの最大文字数。

### $ClaudeTestModel
型: String, 初期値: $ClaudeModel
分離検証などのテスト用モデル名。別モデルで客観的に検証するために変更可能。

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval が再帰的に ClaudeEval を生成する際の最大深度。0 で再帰禁止。大きくすると多段階の自動タスク連鎖が可能。

### $ClaudeSnapshots
型: String, 初期値: FileNameJoin[{$ClaudeWorkingDirectory, "snapshots"}]
LLMGraphDAG スナップショットの保存ディレクトリ。

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
外部パッケージがキーワードを登録するための Association。プロンプトにキーワードが含まれると、対応パッケージの api.md がコンテキストに自動注入される。各パッケージが自身のロード時に登録する。claudecode.wl 側はパッケージ非依存。
例: `$ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒切"}`

### $LLMGraphMaxConcurrency
型: Integer
LLMGraph の最大並列実行数。

### $LLMGraphAutoStopThreshold
型: Integer
LLMGraph の自動停止しきい値。

### $UseClaudeRuntime
型: Boolean
True のとき ClaudeEval/ClaudeUpdatePackage が ClaudeRuntime 経由で実行される。

### $ClaudeLastRuntimeId
型: String
最後に起動した ClaudeRuntime のセッション ID。

### $ClaudeRoutingProviders
型: List
モデルルーティングに使用するプロバイダーリスト。

## クエリ関数

### ClaudeQuery[prompt] → String
Claude Code に prompt を送り、応答文字列を返す（同期）。セッション履歴とノートブック書き込みを行う標準インターフェース。
`ClaudeQuery[session, prompt]` はセッション履歴と直前の出力/エラーを考慮して回答する。
`ClaudeQuery[{text, Image[...], File[path], ...}]` でマルチモーダル入力。画像/PDF/音声を API に直接送信する。
Options: `WebSearch -> True` (デフォルト,無料), `WebFetch -> False` (課金あり,Fallback->True 必須), `Fallback -> False`, `Timeout -> Automatic`

### ClaudeQuerySync[prompt, opts] → String
Claude に prompt を送り、応答文字列を同期的に返す。WindowStatusArea に経過時間を表示する。セッション履歴やノートブック書き込みは行わない軽量版。
モデルルーティングのコア:
- `Model -> Automatic` かつ `PrivacyLevel <= 0.5`: Claude Code CLI
- `Model -> Automatic` かつ `PrivacyLevel > 0.5`: $ClaudePrivateModel を自動使用
- `Model -> {"provider","model"}`: 指定モデルを API 経由で使用

Options: `Fallback -> False`, `Model -> Automatic`, `PrivacyLevel -> Automatic`, `Timeout -> Automatic`
例: `ClaudeQuerySync[prompt, PrivacyLevel -> 1.0]`
例: `ClaudeQuerySync[prompt, Model -> {"anthropic", "claude-sonnet-4-6"}]`

### ClaudeQueryBg[prompt, opts] → String
FrontEnd 操作・ScheduledTask 生成なしで Claude に同期問い合わせし、応答文字列を返す。SocketListen ハンドラ・ScheduledTask コールバック等の非同期コンテキストから安全に呼び出せる（URLRead 相当の安全な代替手段）。
Options: `Fallback -> False`, `Model -> Automatic`, `Timeout -> Automatic`

### ClaudeQueryAsync[prompt, callback, nb, opts]
Claude に非同期で問い合わせ、完了時に `callback[応答文字列]` を呼ぶ。nb は出力先 NotebookObject。カーネルをブロックしない。WindowStatusArea に経過時間を表示する。Job システム (NBBeginJobAtEvalCell) を使用。
Options: `Fallback -> False`, `Model -> Automatic`, `PrivacyLevel -> Automatic`, `Timeout -> Automatic`

### ClaudeWriteResponse[nb, text, opts]
マークダウン形式のテキストをノートブックのセルとして展開する。見出し・リスト・コードブロック等を適切なセルスタイルに変換する。ClaudeQuerySync で取得した応答をノートブックに出力する際に使用する。
Options: `AutoEvaluate -> False`

### ClaudeMath[task] → String
Mathematica コード生成に特化したプロンプトで Claude を呼び出す。

### ClaudeExtractCode[response] → String
Claude の応答から最初の ` ```mathematica ` ブロックを抽出する。

### ClaudeExtractAllCode[response] → List
Claude の応答から全 ` ```mathematica ` ブロックをリストで返す。

## コード生成・評価

### ClaudeEval[task, opts]
コードを非同期で生成・表示し、デフォルトセッションに履歴を保存する。
`ClaudeEval[{text, data, ...}]` はテキスト、Dataset、Image、一般式を混在できる。
`ClaudeEval[session, task]` は指定セッションに履歴を保存する。
Options:
- `AutoEvaluate -> True` (生成された Input セルの自動実行を制御)
- `StartTime -> Now` (実行開始時刻を DateObject で指定。例: `StartTime -> Now + Quantity[3, "Hours"]`)
- `RepeatInterval -> None` (繰り返し実行。例: `RepeatInterval -> Quantity[2, "Hours"]` で 2 時間ごと)
- `RepeatInterval -> {Quantity[1,"Hours"], 5}` で 1 時間ごとに最大 5 回実行
- `Timeout -> Automatic` (API フォールバックのタイムアウト秒数。Automatic は $iFallbackTimeout (600秒))
- `Fallback -> False`
- `AutoPrivate -> False` (True: 機密変数にアクセスするタスクの場合、生成コードに `Model -> $ClaudePrivateModel`, `PrivacySpec -> Automatic` を付与)

TaskObject が返るので `TaskRemove[]` で停止可能。

### ContinueEval[session, instruction, opts]
指定セッションで継続。
`ContinueEval[instruction]` はデフォルトセッションで継続。
`ContinueEval[]` は "エラーを修正してください" でデフォルトセッションを継続。
Options: `StartTime -> Now`, `Timeout -> Automatic`

### ContinueUpdate[instruction, opts]
直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を継続する。
`ContinueUpdate["instruction"]` は追加指示を付けて継続。
`ContinueUpdate[{"instruction", img}]` はテキスト+画像で継続。
`ContinueUpdate["pkgName", "instruction"]` は指定パッケージの直前の更新を継続。
Options: `Fallback -> False`, `"UpdateApiMd" -> True`, `StartTime -> Now`

### ClaudeSpec[task]
ノートブック内容からプログラムの仕様を生成する。`ClaudeSpec[{"task", image, ...}]` は画像付きで仕様を生成。パレットからセル選択で呼び出し可能。

### ClaudeDebug[codeOrFile, errorMsg]
デバッグ支援を非同期で求める（即座に返る）。

### ClaudeReview[codeOrFile]
コードのレビューを非同期で行う（30000 文字超は自動チャンク分割）。

### ClaudeReviewChunked[codeOrFile]
ファイルをチャンク分割して非同期レビューする。

## セッション管理

### CreateClaudeSession["name"] → session
名前付きセッションを作成する（デフォルト履歴を継承）。
`CreateClaudeSession[session]` は既存セッションの履歴を継承した新セッションを作成。
`CreateClaudeSession[]` はデフォルト履歴を継承した新セッションを作成。
`CreateClaudeSession[Inherit -> False]` は独立したセッションを作成。

### ClaudeRestoreSession[] → session
デフォルトセッションをリストア。`ClaudeRestoreSession["name"]` は指定名のセッションをリストア。

### ClaudeListSessions[]
ノートブック内の全セッションを一覧表示する。

### ClaudeDeleteSession["name"]
指定名のセッションを削除する。`ClaudeDeleteSession["name", "All"]` はセッションとその全履歴を削除。

### ClaudeShowHistory[]
デフォルトセッションの履歴を表示する。`ClaudeShowHistory[session]` は指定セッションの履歴を表示。`ClaudeShowHistory["name"]` は指定名のセッションの履歴を表示。

### ClaudeSessionStatus[]
デフォルトセッションの状態を表示する。`ClaudeSessionStatus[name]` は指定名のセッションの状態を表示。アクセス可能ディレクトリ、アタッチメント、作業ディレクトリのファイル等を確認可能。

### ClaudeCompactHistory[]
デフォルトセッションの履歴を手動でコンパクションする。`ClaudeCompactHistory[name]` は指定セッションをコンパクションする。通常は 2n+1+w エントリを超えたときに自動実行される。

### ClaudeHistorySize[] → Association
現在のノートブックのセッション履歴サイズを診断する。Entries・ByteCount・KiloBytes・Status を含む Association を返す。200KB 超でコンパクション推奨、500KB 超で危険。

## アタッチメント

### ClaudeAttach[path, opts]
デフォルトセッションに参照資料をアタッチする。URL の場合は PDF 化してキャッシュしアタッチする。`ClaudeAttach[session, path]` は指定セッションにアタッチする。アタッチされたファイルは ClaudeQuery/ClaudeEval 時に自動的に Read される。
Options: `Keywords -> {}`, `Title -> None`, `Refetch -> False`
Keywords で登録するとプロンプト中のキーワードに応じて自動注入される。

### ClaudeDetach[path]
デフォルトセッションからファイルをデタッチする。`ClaudeDetach[session, path]` は指定セッションからデタッチする。

### ClaudeAttachments[] → List
デフォルトセッションのアタッチメント一覧を返す。`ClaudeAttachments[session]` は指定セッションのアタッチメント一覧を返す。

### ClearAttachments[]
デフォルトセッションの全アタッチメントをクリアする。`ClearAttachments[session]` は指定セッションの全アタッチメントをクリアする。

## 機密データ管理

### MarkConfidential[]
現在のセルを機密マークする。`MarkConfidential[cell]` は指定セルを機密マークする。機密セルは ClaudeEval/ClaudeQuery のプロンプトから除外される。

### UnmarkConfidential[]
現在のセルの機密マークを解除する。`UnmarkConfidential[cell]` は指定セルの機密マークを解除する。

### IsConfidential[cell] → Boolean
セルが機密マークされているかを返す。`IsConfidential[]` は現在のセルが機密かを返す。

### Confidential[expr]
式を評価し、その Input/Output セルを自動的に機密マークする。
例: `Confidential[secretData = Import["secret.csv"]]`

### NonConfidential[expr]
式を評価し、その Input/Output セルの機密マークを明示的に解除する。秘密変数や秘密依存変数の値に依存していても、機密解除として扱う。
例: `result = NonConfidential[Mean[secretData]]`

### ScanConfidentialCells[]
ノートブック全セルをスキャンし、機密変数を参照するセルを自動的に機密マークする。明示的に UnmarkConfidential されたセルはスキップされる。

## パッケージ管理

### ClaudeCreatePackage[name, prompt]
prompt に従って name.wl を新規作成し $packageDirectory に保存する。

### ClaudeUpdatePackage[packageName, prompt, opts]
$packageDirectory にある packageName.wl を Claude の支援でアップデートし、バックアップを作成する。prompt には文字列またはリスト `{文字列, Image, File[".../file.pdf"], ...}` を指定可能。
Options:
- `TargetFunctions -> Automatic` (更新対象関数を指定)
- `StartTime -> Now` (実行開始時刻。例: `StartTime -> Now + Quantity[1, "Hours"]`)
- `Fallback -> False`
- `"UpdateApiMd" -> Automatic` (False で api.md の自動更新をスキップ)

### ClaudeRestorePackage[packageName]
直前のバックアップを復元する。

### ClaudeUpdatePackageHistory[] → List
全パッケージの ClaudeUpdatePackage 呼び出し履歴を表示しリストで返す。`ClaudeUpdatePackageHistory[packageName]` は指定パッケージの更新履歴を表示しリストで返す。各エントリは `<|"Package"->…, "Timestamp"->…, "Directory"->…|>` の Association。

### ClaudeBackupDataset[packageName]
指定パッケージのバックアップ履歴を Review/Pull/Delete ボタン付き Grid で表示する。`ClaudeBackupDataset[]` は全パッケージのバックアップ履歴を表示する。Review はバックアップ内容を確認、Pull は復元、Delete はその履歴を削除。

### ClaudeMigrateBackupHistory[packageName, opts]
既存の history 内の生 .wl バックアップを差分形式 (.wl.cz / .wl.cdiff) に変換して容量を削減する。`ClaudeMigrateBackupHistory[]` は全パッケージに対して実行する。
Options: `DryRun -> False` (True で削除せず容量削減の見積もりのみ表示)

### ClaudeConvertToPaclet[packageName]
$packageDirectory の packageName.wl を Paclet 形式に変換する。packageName/ フォルダを作成し、Kernel/, Documentation/, PacletInfo.wl 等を生成する。元の .wl ファイルはバックアップ後に削除される。

## ドキュメント生成

### ClaudeCreateDocumentation["packageName", opts]
パッケージの詳細なドキュメント一式を Claude で自動生成する。$packageDirectory 内の packageName.wl または packageName/ Paclet を対象とする。単一 .wl: `$packageDirectory/packageName_info/docs/` に出力。Paclet: `$packageDirectory/packageName/docs/` に出力。
Options: `References -> {}`, `Demos -> {}`, `Disclaimer -> {}`, `License -> ""`, `Acknowledgments -> {}`

### ClaudeUpdateDocumentation["packageName", opts]
ソース差分に基づき全ドキュメントを自動更新する。`ClaudeUpdateDocumentation["packageName", "更新指示"]` は指示に従ってドキュメントを更新する。ノートブックのコンテキストも参照可能（"上で議論されている内容を反映して" など）。
Options:
- `TargetFiles -> Automatic` (自動判定。`{"api.md"}` 等でファイル指定)
- `Mode -> "Update"` ("Update": 既存更新, "Create": 新規作成)
- `References -> {}`, `Demos -> {}`, `Disclaimer -> {}`, `License -> ""`, `Acknowledgments -> {}`

例: `ClaudeUpdateDocumentation["claudecode", "api.md のみ更新して"]`
例: `ClaudeUpdateDocumentation["pkg", "...", TargetFiles -> {"api.md"}]`

## ドキュメント生成オプション

### References
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。URL や書籍名のリストを指定すると README.md に参考文献セクションを追加する。
例: `References -> {"https://...", "書籍名"}`

### Demos
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。デモ動画や使用例の URL リストを指定すると README.md に反映する。
例: `Demos -> {"https://youtu.be/...", "https://example.com/demo.nb"}`

### Disclaimer
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。免責事項セクションに追加する文言のリストを指定する。
例: `Disclaimer -> {"本ツールは研究目的専用です"}`

### License
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。空文字列 (デフォルト): GitHubREST`$GitHubLicenseHolder` が非空なら MIT ライセンスを自動挿入。文字列指定: そのままライセンステキストとして挿入。
例: `License -> "MIT"`, `License -> "Apache-2.0 License..."`

### Acknowledgments
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。謝辞セクションに追加する文言のリストを指定する。指定時は README.md の免責事項の前に配置する。
例: `Acknowledgments -> {"本研究は JSPS 科研費の助成を受けた"}`

## ディレクティブ管理

### ClaudeAddDirective[target, description]
Claude で description を整形し、Claude Directives フォルダのファイルに追加して `InstallClaudeDirectives[]` を実行する。target は "CLAUDE.md" またはスキル名（例: "wolfram-general"）。元ファイルは自動バックアップされる。

### ClaudeRestoreDirective[target]
ClaudeAddDirective の直前のバックアップを復元し `InstallClaudeDirectives[]` を実行する。target は "CLAUDE.md" またはスキル名。

### ClaudeListDirectives[]
Claude Directives フォルダの CLAUDE.md と全スキルの一覧を表示する。

### ClaudeUpdateDirective[]
ソースコードと Claude Directives の整合性をチェックし、不整合を自動修正する。`ClaudeUpdateDirective[text]` は text の内容を Claude で解釈し、CLAUDE.md / rules / skills の適切なファイルに反映する。ノートブックのコンテキストも参照可能。

### ClaudeDirectiveBackupDataset[]
Claude Directives の更新履歴を Review/Pull/Delete ボタン付き Grid で表示する。履歴は `ClaudeUpdateDirective[text]` や `ClaudeAddDirective` の実行時に自動保存される。

### ClaudeSyncDirectives[dir]
指定ディレクトリ dir のファイルを Claude Directives フォルダと比較し、dir 側の方が新しいファイルで Claude Directives を更新する。dir にだけ存在するファイルもコピーする。Claude Directives 側にしかないファイルはそのまま。
例: `ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]`

## Git・コミット

### ClaudePrepareCommit[packageName, opts]
前回の GitHub コミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを生成して `GitHubRefreshAndCommit` 実行コマンドを Input セルとして出力する。`ClaudePrepareCommit[packageName, subject]` は 1 行目を指定し、本文は自動収集する。
Options: `Fallback -> False`, `DryRun -> False`, `Owner -> Automatic`, `Repository -> Automatic`, `Branch -> Automatic`, `BaseBranch -> Automatic`
`DryRun -> True` でコマンドを生成せずメッセージのみ返す。

## Web 検索・取得

### ClaudeWebSearch[query] → String
Web 検索を実行し、結果をテキストで返す。Anthropic API の web_search ツールを使用する。

### ClaudeWebFetch[url] → String
指定 URL の内容を取得し、要約・抽出して返す。`ClaudeWebFetch[url, prompt]` は取得内容に対して prompt の指示を実行する。

### WebSearch
ClaudeQuery/ClaudeEval のオプション。True (デフォルト): Claude Code CLI の組み込み Web 検索ツールを許可する。False: Claude Code CLI の Web 検索を禁止する。Claude Code 自体の Web 検索機能であり、API 経由の課金は発生しない。WebFetch (課金あり) とは異なる。

### WebFetch
ClaudeQuery/ClaudeEval のオプション。True: 必ず Web 検索を行う。False: Web 検索を行わない。Automatic (ClaudeEval のデフォルト): Claude がタスクを分析し、必要なら自動で Web 検索する。ClaudeQuery のデフォルトは False。重要: WebFetch は Anthropic API 経由で課金が発生するため、`Fallback -> True` の場合のみ有効。

## 診断・ユーティリティ

### ClaudeStatus[]
現在実行中の全 Claude タスクのリアルタイム状態を表示する。各タスクの経過時間、現在の状態（思考中/テキスト生成中/ツール実行中）、生成済みテキスト断片数、思考断片数、ツール使用数を表示する。実行中のタスクがない場合はその旨を表示する。

### ClaudeAbort[]
実行中の全 Claude タスクを停止する。Claude Code プロセスの強制終了、ScheduledTask の停止、フォールバックタスクのキャンセルを行う。パレットの "実行停止" ボタンからも呼び出し可能。

### ClaudeCommand["/command"] → String
Claude Code CLI のスラッシュコマンドを実行し結果を返す。スラッシュコマンド (/始まり) は node-pty 経由で対話モードに送信される。CLI サブコマンド (例: `config list`) は直接実行される。
例: `ClaudeCommand["/help"]`, `ClaudeCommand["/permissions"]`, `ClaudeCommand["config list"]`, `ClaudeCommand["--version"]`

### ClaudeQueryShowContext[]
デバッグ用: 次の ClaudeQuery が送信するノートブックコンテキストを表示する。

### ClaudeShowAccessConfig[]
デバッグ用: Claude Code のファイルアクセス設定を表示する。$ClaudeAccessibleDirs, NBGetAccessibleDirs[], 生成される settings.json, CLI フラグを確認可能。

### ShowClaudePalette[]
Claude Code 操作用のパレットを表示する。

### ClaudeCheckSeparation[target]
target のコードが NBAccess の分離原則に違反している箇所をリストアップする。target はファイルパス | $packageDirectory の .wl 名 | パクレット名。$ClaudeTestModel のモデルで検査する。
検査対象 (静的走査 + LLM 判定):
- SystemCredential 直接利用
- CellObject 直接操作 (NotebookWrite/NotebookRead/CellGroupData 直接構築)
- CellEpilog/CellProlog/NotebookEventActions 直接操作
- NBAccess`Private` 関数呼び出し
- NBAccess 公開グローバル直接更新
- EvaluationCell[]/CellPrint[]/SetSelectedNotebook[] 直接使用
- CurrentValue/SetOptions による TaggingRules/CellTags/CellEpilog 属性直接アクセス
- CellObject の公開 API・戻り値・状態保持への漏洩
- SelectionEvaluate/FrontEndTokenExecute 等 FE 状態操作
- NBAccess 公開グローバルの破壊的更新 (AppendTo/AssociateTo 等)

例: `ClaudeCheckSeparation["claudecode"]`, `ClaudeCheckSeparation["C:\\path\\to\\file.wl"]`

### ClaudeFixSeparation[target]
分離違反を修正する。target がファイルパスの場合: バックアップを作成し元ファイルを修正。target がパッケージ名のみの場合: ClaudeUpdatePackage を呼び出す。事前に ClaudeCheckSeparation の結果があればそれを利用する。
例: `ClaudeFixSeparation["claudecode"]`

### cleanOutput[str] → String
出力文字列をクリーニングする。

### stripANSI[str] → String
ANSI エスケープコードを除去する。

### NBFileTranslate[...]
ノートブックファイルの変換を行う。

### ClaudeProcessFile[...]
ファイルを Claude で処理する。

## LLMGraph

### NotebookLLMGraph[nb] → graph
ノートブック nb の LLMGraph を返す。存在しない場合は新規作成する。
例: `g = NotebookLLMGraph[EvaluationNotebook[]]`

### NotebookLLMGraphPlot[nb]
ノートブックの LLMGraph をトップレベルで可視化する。Orchestrator ノードのみを表示し、アクセスレベル別に色分けする。

### NotebookLLMGraphBuild[nb, opts]
ノートブックの LLMGraph を構築する。

### NotebookLLMGraphNodes[nb] → List
ノートブックの LLMGraph ノード一覧を返す。

### NotebookLLMGraphValidate[nb] → List
LLMGraph の整合性を検証する。

### NotebookLLMGraphFetchResponse[nb, nodeId] → String
指定ノードの応答を取得する。

### NotebookLLMGraphSubSteps[nb, nodeId] → List
指定ノードのサブステップ一覧を返す。

### NotebookLLMGraphFetchL2[nb, nodeId]
L2 (サブステップ) レベルの応答を取得する。

### NotebookLLMGraphErrors[nb] → List
LLMGraph 内のエラーノード一覧を返す。

### NotebookLLMGraphUpdateL2Status[nb, nodeId, status]
L2 ノードのステータスを更新する。

### NotebookLLMGraphPlotL2[nb, nodeId]
L2 レベルの LLMGraph を可視化する。

### NotebookLLMGraphRerun[nb, nodeId]
指定ノードを再実行する。

### NotebookLLMGraphInvalidateDownstream[nb, nodeId]
指定ノードの下流ノードを無効化する。

### NotebookLLMGraphSummary[nb] → Association
LLMGraph のサマリーを返す。

### NotebookLLMGraphExtractThread[nb, nodeId] → List
指定ノードのスレッドを抽出する。

### NotebookLLMGraphApplyThread[nb, thread]
抽出したスレッドを適用する。

### LLMGraphExecute[graph, opts]
LLMGraph を実行する。

### LLMGraphExecuteStatus[graph] → Association
LLMGraph の実行状態を返す。

### LLMGraphExecuteCancel[graph]
LLMGraph の実行をキャンセルする。

### LLMGraphDAGCreate[nodes, edges, opts] → dag
LLMGraph DAG を作成する。

### LLMGraphDAGStatus[dag] → Association
DAG の実行状態を返す。

### LLMGraphDAGCancel[dag]
DAG の実行をキャンセルする。

### LLMGraphDAGStop[dag]
DAG の実行を停止する。

### LLMGraphDAGRetry[dag, nodeId]
失敗したノードをリトライする。

### LLMGraphDAGRebuild[dag, opts]
DAG を再構築する。

### LLMGraphDAGFindByContext[dag, context] → nodeId
コンテキストからノードを検索する。

### LLMGraphDAGInspect[dag, nodeId]
DAG ノードの詳細を表示する。

### LLMGraphDAGMarkFailed[dag, nodeId]
DAG ノードを失敗としてマークする。

### LLMGraphDAGSnapshot[dag, opts] → snapshotId
DAG のスナップショットを $ClaudeSnapshots ディレクトリに保存する。

### LLMGraphDAGRestore[snapshotId] → dag
スナップショットから DAG を復元する。

### LLMGraphDAGListSnapshots[] → List
保存済みスナップショットの一覧を返す。

### LLMGraphDAGPlot[dag]
DAG を可視化する。

## Runtime

### ClaudeBuildRuntimeAdapter[opts] → adapter
ClaudeRuntime 用のアダプターを構築する。

### ClaudeStartRuntime[adapter] → runtimeId
ClaudeRuntime を起動する。

### ClaudeEvalViaRuntime[task, runtimeId, opts]
ClaudeRuntime 経由でコードを評価する。

### ClaudeBuildTransactionAdapter[opts] → adapter
トランザクション型アダプターを構築する。

### ClaudeUpdatePackageViaRuntime[packageName, prompt, runtimeId, opts]
ClaudeRuntime 経由でパッケージを更新する。

### ClaudeApproveProposal[proposalId]
ClaudeRuntime からの提案を承認する。

### ClaudeRuntimeSnapshot[runtimeId] → snapshotId
Runtime のスナップショットを保存する。

### ClaudeRuntimeRestore[snapshotId] → runtimeId
スナップショットから Runtime を復元する。

### ClaudeRuntimeRetry[runtimeId]
Runtime の失敗したタスクをリトライする。

### ClaudeRuntimeListSnapshots[] → List
保存済み Runtime スナップショットの一覧を返す。

## オプションシンボル

### Fallback
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: Claude Code 利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。False (デフォルト): エラーをそのまま返す。

### AutoPrivate
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: 機密変数にアクセスするタスクの場合、生成コードに `Model -> $ClaudePrivateModel`, `PrivacySpec -> Automatic` を付与する。False (デフォルト): 通常動作。

### AutoEvaluate
ClaudeWriteResponse/ClaudeEval のオプション。True: 生成された Input セルを自動実行する（ClaudeEval デフォルト True）。False: 自動実行しない。

### StartTime
ClaudeEval/ContinueEval/ClaudeUpdatePackage のオプション。実行開始時刻を DateObject で指定する。デフォルト Now。
例: `StartTime -> Now + Quantity[3, "Hours"]`

### RepeatInterval
ClaudeEval のオプション。None (デフォルト): 1 回のみ実行。`Quantity[n, "Hours"]` で n 時間ごとに繰り返し実行。`{Quantity[1,"Hours"], 5}` で 1 時間ごとに最大 5 回実行。TaskObject が返るので `TaskRemove[]` で停止可能。

### TargetFunctions
ClaudeUpdatePackage のオプション。Automatic (デフォルト): 自動判定。関数名リストで更新対象を限定する。

### TargetFiles
ClaudeUpdateDocumentation のオプション。Automatic (デフォルト): 自動判定。`{"api.md"}` 等でファイルを指定する。

### Mode
ClaudeUpdateDocumentation のオプション。"Update" (デフォルト): 既存ドキュメントを更新。"Create": 新規作成。

### DryRun
ClaudeMigrateBackupHistory/ClaudePrepareCommit のオプション。True: 実際の変更を行わず見積もりのみ表示。False (デフォルト): 実行する。

### Inherit
CreateClaudeSession のオプション。True (デフォルト): デフォルト履歴を継承。False: 独立したセッションを作成。

### Keywords
ClaudeAttach のオプション。デフォルト {}。登録するとプロンプト中のキーワードに応じてアタッチメントが自動注入される。

### Title
ClaudeAttach のオプション。デフォルト None。アタッチメントのタイトルを指定する。

### Refetch
ClaudeAttach のオプション。デフォルト False。True のとき URL キャッシュを無視して再取得する。

### Owner
ClaudePrepareCommit のオプション。Automatic (デフォルト): GitHubREST から自動取得。GitHub リポジトリのオーナー名を指定する。

### Repository
ClaudePrepareCommit のオプション。Automatic (デフォルト): GitHubREST から自動取得。GitHub リポジトリ名を指定する。

### Branch
ClaudePrepareCommit のオプション。Automatic (デフォルト): 現在のブランチを使用。コミット先ブランチ名を指定する。

### BaseBranch
ClaudePrepareCommit のオプション。Automatic (デフォルト): メインブランチを自動検出。差分比較の基準ブランチを指定する。