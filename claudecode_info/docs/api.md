# claudecode API リファレンス

パッケージ: `ClaudeCode`` `
リポジトリ: https://github.com/transreal/claudecode

## グローバル変数
### $ClaudeModel
型: String, 初期値: `""`
Claude CLI に渡すモデル名。空文字は CLI デフォルト。
### $ClaudePrivateModel
型: List, 初期値: `{}`
秘密データ処理用のローカルモデル指定。`AutoPrivate -> True` 時に秘密変数を含むタスクの生成コードに `Model -> $ClaudePrivateModel` が付与される。
例: `$ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}`
### $ClaudeTimeout
型: Integer, 初期値: `1200`
ClaudeQuery/ClaudeEval 等のタイムアウト秒数。
### $ClaudeWorkingDirectory
型: String, 初期値: `FileNameJoin[{$HomeDirectory, "Claude Working"}]`
Claude Code を起動する作業ディレクトリ。このディレクトリ配下の .claude/CLAUDE.md, .claude/rules/, .claude/skills/ を Claude Code に読ませる。
### $ClaudeMDPath
型: String, 初期値: `""`
読み込む CLAUDE.md のパス（自動検索または手動指定）。
### $ClaudeMDContent
型: String, 初期値: `""`
読み込まれた CLAUDE.md の内容。
### $ClaudeAccessibleDirs
型: List, 初期値: `{$packageDirectory}`
Claude Code に Read 許可する追加ディレクトリ。ノートブックの TaggingRules にも NBSetAccessibleDirs で永続化可能。
### $ClaudeNBDirAccess
型: String, 初期値: `"list"`
NotebookDirectory のアクセスレベルを制御する。
`"list"` — ファイル一覧のみ表示、読み書き不可（デフォルト）。`"read"` — 読み取り許可。`"readwrite"` — 読み書き許可。
ClaudeQuery/ClaudeEval でファイル読み取りが必要な場合、`"list"` モードでは権限付与ボタンが表示される。
### $ClaudeFallbackModels
型: List, 初期値: `{{"anthropic","claude-opus-4-6"},{"openai","gpt-5"}}`
フォールバックモデル優先順位。各要素は `{"provider","model"}` または `{"provider","model","customURL"}`。
provider が `"lmstudio"` の場合、API キー不要。デフォルト URL は `http://localhost:1234`。URL に `/v1/chat/completions` が含まれていなければ自動補完される。パッケージロード時に `NBAccess`NBSetFallbackModels` へ自動同期される。
例: `$ClaudeFallbackModels = {{"anthropic","claude-opus-4-6"},{"lmstudio","gpt-oss-20b","http://127.0.0.1:1234"}}`
### $ClaudeEvalMaxDepth
型: Integer, 初期値: `5`
ClaudeEval がコード内でさらに ClaudeEval/ContinueEval を生成する連鎖呼び出しの上限。0 で再帰禁止。
### $ClaudeTestModel
型: String, 初期値: `$ClaudeModel` と同じ
分離検証用モデル名。別モデルで客観的に検証するために変更可能。
### $ClaudeDocRetryDelay
型: Integer, 初期値: `60`
ドキュメント生成のリトライ待機秒数。
### $ClaudeDocMaxRetries
型: Integer, 初期値: `3`
ドキュメント生成の最大リトライ回数。
### $ClaudeDocMaxChunkChars
型: Integer, 初期値: `60000`
プロンプト中ソースの最大文字数。
### $ClaudeImageModels
型: List, 初期値: `{{"openai","gpt-image-1"},{"openai","dall-e-3"}}`
画像生成モデルのリスト。`{{"provider","model"}, ...}` の形式。
### $ClaudeTTSModels
型: List, 初期値: `{{"openai","tts-1-hd"},{"openai","tts-1"}}`
音声生成モデルのリスト。`{{"provider","model"}, ...}` の形式。

## クエリ・コード生成
### ClaudeQuery[prompt, opts]
prompt を Claude Code に送信し、応答をノートブックにマークダウン形式で出力する（非同期）。
Options: `Fallback -> False`, `WebFetch -> False`, `Model -> Automatic`, `PrivacySpec -> Automatic`, `AutoPrivate -> False`
### ClaudeQuery[session, prompt, opts]
セッション履歴と直前の出力/エラーを考慮して回答する。
Options: ClaudeQuery と同じ
### ClaudeMath[task] → String
Mathematica コード生成に特化したプロンプトで Claude を呼び出す（同期）。
### ClaudeExtractCode[response] → String
応答から最初の `` ```mathematica `` ブロックを抽出する。
### ClaudeExtractAllCode[response] → List
応答から全 `` ```mathematica `` ブロックをリストで返す。
### ClaudeEval[task, opts]
コードを非同期で生成・表示し、デフォルトセッションに履歴を保存する。問い合わせ中は経過時間と状態をリアルタイム表示する。
→ RepeatInterval 指定時は TaskObject
Options: `AutoEvaluate -> True`, `StartTime -> Now`, `Fallback -> False`, `WebFetch -> Automatic`, `RepeatInterval -> None`, `Model -> Automatic`, `PrivacySpec -> Automatic`, `AutoPrivate -> False`
`Model`: `Automatic` で Claude Code 経由。`{"provider","model"}` または `{"provider","model","url"}` で API 直接呼び出し。
`PrivacySpec`: `Automatic` でモデル/プロバイダーに応じたアクセスレベル自動解決。`<|"AccessLevel" -> n|>` で明示指定。
`AutoPrivate`: `True` で秘密変数を含むタスクの生成コードに `Model -> $ClaudePrivateModel, PrivacySpec -> Automatic` を自動付与。
`AutoEvaluate -> True` でも外部サービスへの不可逆な書き込み操作（`GitHubRefreshAndCommit`, `GitHubPushAll`, `GitHubCommit`, `GitHubCreatePullRequest`, `GitHubMergePullRequest`, `GitHubSubmitPullRequest`）を含む生成コードは自動実行をスキップし手動実行を要求する。
`RepeatInterval`: `Quantity[n, "Hours"]` で無限繰り返し、`{Quantity[n, "Hours"], maxCount}` で最大回数指定。
例: `ClaudeEval["タスク", RepeatInterval -> Quantity[2, "Hours"]]`
例: `ClaudeEval["タスク", RepeatInterval -> {Quantity[1, "Hours"], 5}]`
例: `ClaudeEval["タスク", Model -> {"lmstudio", "openai/gpt-oss-20b", "http://192.168.2.106:1234"}]`
例: `ClaudeEval["タスク", StartTime -> Now + Quantity[3, "Hours"]]`
例: `ClaudeEval["タスク", Fallback -> True]`
例: `ClaudeEval["秘密データを分析", AutoPrivate -> True]`
例: `ClaudeEval["タスク", PrivacySpec -> <|"AccessLevel" -> 1.0|>]`
### ClaudeEval[{text, data, ...}, opts]
テキスト、Dataset、Image、一般式を混在できるリスト入力版。Options は ClaudeEval と同じ。
### ClaudeEval[session, task, opts]
指定セッションに履歴を保存する版。Options は ClaudeEval と同じ。
### ContinueEval[session, instruction, opts]
セッションを継続する。アクセスレベルに基づく三段階ルーティング対応。
Options: `Fallback -> False`, `AutoEvaluate -> True`, `StartTime -> Now`, `Model -> Automatic`, `PrivacySpec -> Automatic`, `AutoPrivate -> False`
### ContinueEval[instruction, opts]
デフォルトセッションで継続。Options は ContinueEval と同じ。
### ContinueEval[]
「エラーを修正してください」でデフォルトセッションを継続。
### ContinueUpdate[opts]
直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を継続する。引数なしはデフォルト指示で継続。
→ ClaudeUpdatePackage の結果
Options: `Fallback -> False`, `"UpdateApiMd" -> True`, `StartTime -> Now`
### ContinueUpdate[instruction, opts]
追加指示付きで継続。パッケージ名は直前の呼び出しから自動取得。Options は ContinueUpdate と同じ。
例: `ContinueUpdate["上半円の境界線が欠けているので修正して"]`
### ContinueUpdate[packageName, instruction, opts]
指定パッケージの直前の更新を継続。Options は ContinueUpdate と同じ。
例: `ContinueUpdate["pkg", "修正指示"]`

## セッション管理
### CreateClaudeSession["name"] → Association
名前付きセッションを作成（デフォルト履歴を継承）。
### CreateClaudeSession[session] → Association
既存セッションの履歴を継承した新セッションを作成。
### CreateClaudeSession[opts] → Association
Options: `Inherit -> True`
`Inherit -> False` で独立したセッションを作成。
### ClaudeRestoreSession[] → Association
デフォルトセッションをリストア。
### ClaudeRestoreSession["name"] → Association
指定名のセッションをリストア。
### ClaudeListSessions[] → Dataset
ノートブック内の全セッションを一覧表示。
### ClaudeDeleteSession["name"]
指定セッションを削除。
### ClaudeShowHistory[]
デフォルトセッションの履歴を表示。
### ClaudeShowHistory[session]
指定セッション（Association または名前 String）の履歴を表示。
### ClaudeCompactHistory[]
デフォルトセッションの履歴を手動コンパクションする。通常は 2n+1+w エントリを超えたときに自動実行される。
### ClaudeCompactHistory[name]
指定セッションをコンパクションする。
### ClaudeHistorySize[] → Association
デフォルトセッションの履歴サイズを診断する。Entries・ByteCount・KiloBytes・Status を含む Association を返す。
200KB超でコンパクション推奨、500KB超で危険。
### ClaudeHistorySize[nb] → Association
指定ノートブックのデフォルトセッション履歴サイズを診断する。
### ClaudeSessionStatus[] → Association
デフォルトセッションの状態（アクセス可能ディレクトリ、アタッチメント、作業ディレクトリのファイル等）を表示する。
### ClaudeSessionStatus[name] → Association
指定名のセッションの状態を表示する。

## アタッチメント
### ClaudeAttach[path] → List
デフォルトセッションに参照資料をアタッチ。アタッチされたファイルは ClaudeQuery/ClaudeEval 時に自動的に Read される。
### ClaudeAttach[session, path] → List
指定セッションにアタッチ。
### ClaudeDetach[path] → List
デフォルトセッションからデタッチ。
### ClaudeDetach[session, path] → List
指定セッションからデタッチ。
### ClaudeAttachments[] → List
デフォルトセッションのアタッチメント一覧を返す。
### ClaudeAttachments[session] → List
指定セッションのアタッチメント一覧を返す。
### ClearAttachments[]
デフォルトセッションの全アタッチメントをクリア。
### ClearAttachments[session]
指定セッションの全アタッチメントをクリア。

## 機密セル管理
### MarkConfidential[]
現在のセルを機密マークする。
### MarkConfidential[nb, cellIdx]
指定セルを機密マークする。
### UnmarkConfidential[]
現在のセルの機密マークを解除。
### UnmarkConfidential[nb, cellIdx]
指定セルの機密マークを解除。
### IsConfidential[] → Boolean
現在のセルが機密かを返す。
### IsConfidential[nb, cellIdx] → Boolean
指定セルが機密かを返す。
### Confidential[expr]
式を評価し、Input/Output セルを自動機密マーク。代入先変数名を $confidentialSymbols に登録する。
例: `成績 = Confidential[First @ Import[..., {"Dataset"}]]`
### NonConfidential[expr]
式を評価し、機密マークを明示的に解除。秘密変数や秘密依存変数の値に依存していても機密解除として扱う。
例: `NonConfidential[Normal[Keys[成績[[1]]]]]`
### ScanConfidentialCells[] → Integer
全セルをスキャンし、機密変数参照セルを自動マーク。マークしたセル数を返す。

## デバッグ・レビュー
### ClaudeDebug[codeOrFile, errorMsg]
デバッグ支援を非同期で求める（即座に返る）。codeOrFile はコード文字列またはファイルパス。
### ClaudeReview[codeOrFile]
コードレビューを非同期実行（30000 文字超は自動チャンク分割）。
### ClaudeReviewChunked[codeOrFile]
ファイルをチャンク分割して非同期レビュー。
### ClaudeSpec[task]
ノートブック内容からプログラム仕様を生成する。
### ClaudeSpec[{task, image, ...}]
画像付きで仕様を生成。パレットからはセル選択で呼び出し可能。

## パッケージ管理
### ClaudeCreatePackage[name, prompt, opts]
prompt に従い name.wl を新規作成し `$packageDirectory` に保存。
Options: `Fallback -> False`
### ClaudeUpdatePackage[name, prompt, opts]
`$packageDirectory` の name.wl を Claude で更新する。実行前に事前バックアップ（`pre_TIMESTAMP` フォルダ）を自動作成。同一パッケージの並列更新は排他ロックにより防止される。
Options: `TargetFunctions -> Automatic`, `StartTime -> Now`, `Fallback -> False`, `"UpdateApiMd" -> True`
`TargetFunctions`: 更新対象の関数名リスト。`Automatic` でプロンプトから自動推定。
`"UpdateApiMd"`: `False` で api.md の自動更新をスキップ。
prompt にはリスト `{文字列, Image, File[".../file.pdf"], ...}` も指定可能。
例: `ClaudeUpdatePackage["pkg", "修正指示", StartTime -> Now + Quantity[1, "Hours"]]`
### ClaudeRestorePackage[name]
直前のバックアップを復元し再ロード。
### ClaudeUpdatePackageHistory[] → List
全パッケージの更新履歴をリストで返す。
### ClaudeUpdatePackageHistory[name] → List
指定パッケージの更新履歴を返す。各エントリは `<|"Package"->..., "Timestamp"->..., "Directory"->...|>`。
### ClaudeBackupDataset[]
全パッケージのバックアップ履歴を Review/Pull/Delete ボタン付き Grid で表示。起動時にローカル最新版のスナップショットを SHA-256 ハッシュ付きで保存する。#0行でローカル最新版に復元可能。Pull で巻き戻した後にファイルを編集していた場合、ローカル最新版への復元時に警告を表示する。
### ClaudeBackupDataset[name]
指定パッケージのバックアップ履歴を表示。
### ClaudeMigrateBackupHistory[name, opts]
既存の history 内の生 .wl/.md バックアップを差分形式 (.wl.cz / .wl.cdiff / .wl.unchanged) に変換して容量を削減する。各ファイルの履歴を個別に追跡し、未変更ファイルは .unchanged で参照する。
Options: `DryRun -> False`
`DryRun -> True` で削除せず容量削減の見積もりを表示する。
→ `<|"Package" -> ..., "Converted" -> ..., "OldBytes" -> ..., "NewBytes" -> ..., "Reduction" -> "XX%", "Details" -> ...|>`
例: `ClaudeMigrateBackupHistory["pkg"]`
例: `ClaudeMigrateBackupHistory["pkg", DryRun -> True]`
### ClaudeMigrateBackupHistory[]
全パッケージに対して実行する。Options は同上。
### ClaudeConvertToPaclet[name]
単一 .wl を Paclet ディレクトリ構造に変換。元の .wl はバックアップ後に削除。

## ドキュメント生成
### ClaudeCreateDocumentation[name, opts]
パッケージの包括的ドキュメント一式（setup.md, user_manual.md, api.md, examples/example.md, README.md）を自動生成。リミット到達時に自動リトライし、再実行で未生成分のみ続行する。
Options: `Fallback -> False`, `References -> {}`, `Demos -> {}`, `Disclaimer -> {}`, `License -> ""`
### ClaudeCreateDocumentation[name, instruction, opts]
大域的指示付きでドキュメント生成。指示文中の URL も自動検出して Demos に追加。Options は同上。
例: `ClaudeCreateDocumentation["pkg", "日本語で簡潔に", References -> {"URL", "書名"}, Demos -> {"URL"}, License -> ""]`
### ClaudeUpdateDocumentation[name, opts]
前回の _documentupdate 以降のソースコード変更を自動検出し全ドキュメントを更新する。
Options: `Fallback -> False`, `References -> {}`, `Demos -> {}`, `Disclaimer -> {}`, `License -> ""`
### ClaudeUpdateDocumentation[name, instruction, opts]
指示に従ってドキュメントを更新する。ノートブックのコンテキストも参照可能（「上で議論されている内容を反映して」など）。Options は同上。
例: `ClaudeUpdateDocumentation["claudecode", "api.mdのみ更新して"]`

## 画像・音声生成
### ClaudeImageGenerate[prompt, opts] → Image
OpenAI Images API で画像を生成し Image オブジェクトで返す。
Options: `"Model" -> Automatic`, `"Size" -> "1024x1024"`, `"Quality" -> "auto"`, `"N" -> 1`
`"Model"`: `Automatic` で `$ClaudeImageModels` の先頭（デフォルト `"gpt-image-1"`）。`"dall-e-3"` も指定可能。
`"Quality"`: gpt-image-1 では `"auto"` | `"high"` | `"medium"` | `"low"`。dall-e-3 では `"standard"` | `"hd"`（`"auto"` → `"standard"`, `"high"` → `"hd"` に自動変換）。
例: `ClaudeImageGenerate["桜の満開の写真"]`
例: `ClaudeImageGenerate["sunset", "Model" -> "dall-e-3", "Quality" -> "hd"]`
### ClaudeSpeech[text, opts] → Audio
OpenAI TTS API で音声を生成し Audio オブジェクトで返す。
Options: `"Model" -> Automatic`, `"Voice" -> "alloy"`, `"Speed" -> 1.0`
`"Model"`: `Automatic` で `$ClaudeTTSModels` の先頭（デフォルト `"tts-1-hd"`）。`"tts-1"` も指定可能。
`"Voice"`: `"alloy"` | `"echo"` | `"fable"` | `"onyx"` | `"nova"` | `"shimmer"`
`"Speed"`: 0.25〜4.0
例: `ClaudeSpeech["こんにちは、世界"]`
例: `ClaudeSpeech["Hello", "Model" -> "tts-1", "Voice" -> "nova"]`

## ディレクティブ管理
### ClaudeAddDirective[target, description, opts]
Claude で description を整形し、target ファイルに追加する。元ファイルは自動バックアップ。
Options: `DryRun -> False`, `Scope -> "Global"`
target は `"CLAUDE.md"` またはスキル名（例: `"wolfram-general"`）。
`Scope -> "Local"` でプロジェクトローカルディレクティブ（.claude-project/）に書き込む。`Scope -> "Global"` でメインの Claude Directives フォルダに書き込む。
### ClaudeRestoreDirective[target]
直前のバックアップから復元。
### ClaudeListDirectives[] → Dataset
CLAUDE.md と全スキルの一覧を表示する。
### ClaudeUpdateDirective[]
ソースコードと Claude Directives の整合性をチェックし、不整合を自動修正する。
### ClaudeUpdateDirective[text, opts]
text を Claude で解釈し CLAUDE.md / rules / skills の適切なファイルに反映する。ノートブックのコンテキストも参照可能。
Options: `Scope -> "Global"`
`Scope -> "Local"` でプロジェクトローカルディレクティブに書き込む。
### ClaudeDirectiveBackupDataset[]
ディレクティブの更新履歴を Review/Pull/Delete 付き Grid で表示。起動時にローカル最新版のスナップショットを保存。#0行でローカル最新版に復元可能。Pull で巻き戻した後にファイルを編集していた場合、復元時に警告を表示する。
### ClaudeSyncDirectives[dir]
指定ディレクトリ dir のファイルを Claude Directives フォルダと比較し、内容が異なるファイルで Claude Directives を更新する。dir にだけ存在するファイルもコピーする。Claude Directives 側にしかないファイルはそのまま。
例: `ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]`
### ClaudeInitProject[] → String
現在のノートブックのディレクトリにプロジェクト固有の Claude Directives 雛形を作成する。
`.claude-project/CLAUDE.local.md` および `rules/`, `skills/` ディレクトリが作成される。
メインのディレクティブと自動マージされ、次回の ClaudeQuery/ClaudeEval から反映される。
### ClaudePromoteProjectDirectives[opts]
プロジェクト固有のディレクティブをグローバルに昇格する。
`.claude-project/` 内の `CLAUDE.local.md` / `rules` / `skills` をメインの Claude Directives にコピーする。
Options: `DryRun -> False`
`DryRun -> True` でプレビューのみ。

## Web 検索・取得
### ClaudeWebSearch[query] → String
Anthropic API の web_search ツールで検索し結果をテキストで返す。
### ClaudeWebFetch[url] → String
URL の内容を取得・要約して返す。
### ClaudeWebFetch[url, prompt] → String
取得内容に対して prompt の指示を実行する。

## 分離検証
### ClaudeCheckSeparation[target, opts] → List
NBAccess の分離原則違反箇所をリストアップする。静的パターン走査 + LLM 判定で検査。`$ClaudeTestModel` のモデルで検査する。
Options: `Fallback -> False`
target: ファイルパス / `$packageDirectory` の .wl 名 / パクレット名。
検査対象: a.SystemCredential直接利用, b.CellObject直接操作, c.CellEpilog/CellProlog/NotebookEventActions直接操作, d.NBAccess`Private`関数呼び出し, e.NBAccess公開グローバル直接更新, f.EvaluationCell[]/CellPrint[]/SetSelectedNotebook[]直接使用, g.CurrentValue/SetOptionsによる属性直接アクセス, h.CellObjectの漏洩, i.FE状態操作, j.NBAccess公開グローバルの破壊的更新
例: `ClaudeCheckSeparation["claudecode"]`
### ClaudeFixSeparation[target, opts]
分離違反を修正する。target がファイルパスの場合はバックアップ後修正、パッケージ名のみの場合は ClaudeUpdatePackage を呼び出す。事前に ClaudeCheckSeparation の結果があればそれを利用する。
Options: `Fallback -> False`

## タスク状態監視
### ClaudeStatus[] → List
現在実行中の全 Claude タスク（ClaudeEval/ClaudeQuery 等）のリアルタイム状態を表示する。各タスクの経過時間、現在の状態（初期化/思考中/テキスト生成中/ツール実行中/応答完了/完了）、思考断片数、テキスト断片数、ツール使用数、出力ファイルサイズ、最新テキスト断片プレビュー、呼び出し元を表示する。

## オプションシンボル
### AutoPrivate
型: Boolean (オプション), デフォルト: False
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True 時に秘密変数にアクセスするタスクの生成コードに `Model -> $ClaudePrivateModel, PrivacySpec -> Automatic` を付与する。$ClaudePrivateModel が未設定の場合は警告を表示する。
### Fallback
型: Boolean (オプション), デフォルト: False
ClaudeQuery/ClaudeEval/ContinueEval/ClaudeCreatePackage/ClaudeUpdatePackage/ClaudeCreateDocumentation/ClaudeUpdateDocumentation/ClaudeCheckSeparation/ClaudeFixSeparation のオプション。True で Claude Code 利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。
### WebFetch
型: True | False | Automatic (オプション)
ClaudeQuery/ClaudeEval のオプション。True: 必ず Web 検索。False: しない。Automatic: Claude がタスクを分析し必要なら自動で Web 検索。ClaudeQuery のデフォルトは False、ClaudeEval のデフォルトは Automatic。
### Inherit
型: Boolean (オプション), デフォルト: True
CreateClaudeSession のオプション。False で独立したセッションを作成。
### References
型: List (オプション), デフォルト: {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。URL や書籍名のリスト。README.md に参考文献セクションを追加する。
### Demos
型: List (オプション), デフォルト: {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。デモ動画や使用例の URL リスト。
### Disclaimer
型: List (オプション), デフォルト: {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。免責事項セクションに追記する文言のリスト。
### License
型: String (オプション), デフォルト: ""
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。空文字で `$GitHubLicenseHolder` が非空なら MIT ライセンスを自動挿入。文字列指定でそのままライセンステキストとして挿入。

## その他
### ClaudeCommand["/command"] → String
Claude Code CLI のスラッシュコマンドを実行し結果を返す。スラッシュコマンド (/始まり) は node-pty 経由で対話モードに送信される。CLI サブコマンド (例: config list) は直接実行される。
例: `ClaudeCommand["/help"]`, `ClaudeCommand["/permissions"]`, `ClaudeCommand["config list"]`, `ClaudeCommand["--version"]`
### ShowClaudePalette[]
Claude Code 操作用パレットを表示する。機密マーク/解除/スキャン、ClaudeQuery/ClaudeEval/ContinueEval のテンプレート挿入、選択セルからの実行、仕様生成、セッション履歴表示等の機能を提供する。
### ClaudeQueryShowContext[]
デバッグ用: 次の ClaudeQuery が送信するノートブックコンテキストを表示する。
### ClaudeShowAccessConfig[]
デバッグ用: $ClaudeAccessibleDirs, NBGetAccessibleDirs[], 生成される settings.json, CLI フラグを確認可能。

## 内部動作: アクセスレベル対応ルーティング

ClaudeQuery/ClaudeEval/ContinueEval は `PrivacySpec` と `Model` オプションからアクセスレベルを解決し、三段階のルーティングを行う:
1. Claude Code（claudecode プロバイダー）がアクセスレベルに対応可能 → Claude Code 経由で実行（フォールバック時は対応可能なモデルのみ使用）
2. Claude Code が対応不可だがフォールバックモデルに対応可能なものがある → フォールバックモデルへ直接ルーティング
3. どのモデルも対応不可 → エラー表示

`iResolveAccessLevel[privSpec, modelSpec]` がアクセスレベルを決定する:
- `PrivacySpec -> Automatic, Model -> Automatic` → "claudecode" プロバイダーの MaxAccessLevel
- `PrivacySpec -> Automatic, Model -> {"provider",...}` → そのプロバイダーの MaxAccessLevel
- `PrivacySpec -> <|"AccessLevel" -> n|>` → 明示値 n

## 内部動作: エラー出力と stream-json

Claude Code CLI は `--output-format stream-json --verbose --include-partial-messages` オプションで起動される。stdout に JSON Lines 形式のストリーミングイベントが出力され、stderr にはエラー・制限メッセージが出力される。`iExtractResultFromStreamJson` が JSON パース不能な行を stderr 行として収集し、結果が空の場合にこれらを `"Error: ..."` として返す。

## 内部動作: パッケージ更新排他ロック

`ClaudeUpdatePackage` は同一パッケージの並列更新を防止する排他ロック機構を持つ。`$iPackageUpdateLocks` で更新中のパッケージを追跡し、ロック中のパッケージに対する更新要求は警告を表示してスキップする。コールバック完了時にロックは自動解放される。

## 内部動作: AutoPrivate によるプライバシー対応自動ルーティング

`AutoPrivate -> True` 指定時、秘密変数にアクセスするタスクの生成コードに `Model -> $ClaudePrivateModel, PrivacySpec -> Automatic` が自動付与される。高アクセスレベル（cloudcode の MaxAccessLevel を超える）でクエリが実行された場合、LLM が書き込んだ新規セルは自動的に機密マークされる。

## 内部動作: 差分ベースバックアップシステム

バックアップは SequenceAlignment ベースの差分形式で保存され、容量を大幅に削減する。保存形式は以下の通り:
- `.cz` — `Compress[全文]` ベースライン（`$iBackupBaselineInterval`（デフォルト10）回ごとに作成）
- `.cdiff` — `Compress[{前回Dir名, SequenceAlignment結果}]` 差分
- `.unchanged` — 前回Dir名（内容同一、1ホップ解決保証で参照チェーンを辿らない）
- レガシー生ファイル — 後方互換読み取り対応

`ClaudeMigrateBackupHistory` で既存の生バックアップを差分形式に一括変換できる。バックアップ削除時は `iSafeDeleteBackupDir` が後続の `.cdiff`/`.unchanged` の参照先を自動的に `.cz` ベースラインに変換し、復元不能になることを防ぐ。

## 内部動作: ディレクティブ書き込みガード

`iSafeWriteDirective` はディレクティブファイルの破損を防止する三重ガードを備える:
1. サイズ退行: 既存の 40% 未満に縮小 → 拒否
2. タイトル保持: CLAUDE.md の先頭 # タイトルが変わっていたら → 拒否
3. SKILL.md のスキル名保持: name: 行が消滅 → 拒否

## 内部動作: プロジェクト固有ディレクティブとマージ

`ClaudeInitProject[]` で `NotebookDirectory/.claude-project/` にプロジェクトローカルのディレクティブ雛形を作成する。メインの Claude Directives と自動マージされ、`NotebookDirectory/.claude/` に出力される。マージはタイムスタンプ比較により必要時のみ実行される。`ClaudePromoteProjectDirectives[]` でローカルディレクティブをグローバルに昇格できる。

## 内部動作: NotebookDirectory アクセス制御

`$ClaudeNBDirAccess` が `"list"` のとき、プロンプトが NotebookDirectory 内のファイルを参照していれば権限付与ボタンを表示して一時停止する。ユーザーが `"read"` または `"readwrite"` を選択すると `$ClaudeNBDirAccess` を更新し、元のクエリを再実行する。

## 内部動作: $Language ベースの言語指示

プロンプト内の言語指定は `$Language` に基づいて動的生成される。`iLanguageName[]` が現在の言語名（英語表記）を返し、`iLanguageInstruction[style]` がスタイル別の言語指示文を生成する（"polite" で敬体、"plain" で常体、"general" で汎用指示）。

## 内部動作: Think トリガー自動挿入

日本語の励まし表現（「死ぬ気で考えろ」「じっくり考えて」「考えてみて」等）を検出し、対応する think トリガーワード（ultrathink / think hard / think）をプロンプト先頭に自動挿入する。既に英語の think トリガーが含まれている場合はスキップする。

## 内部動作: 履歴コンパクション閾値

エントリ数ベース（2n+1+w、n=10, w=2）とサイズベース（`$iHistoryMaxBytes` = 200KB）の二重チェックにより、エントリ数が少なくても巨大な response を持つセッションでのノートブック肥大化・フリーズを防ぐ。

## 内部動作: ドキュメント書き込みガード

`iSafeWriteDoc` はドキュメントファイルの破損を防止するガードを備える:
1. ポジティブ検証: Markdown ヘッダーを含む有効なドキュメント内容か
2. サイズ退行: 既存の 40% 未満に縮小 → 拒否
3. タイトル整合性: README.md の先頭 # タイトルがパッケージ名と不一致 → 拒否

## 依存パッケージ

- [NBAccess](https://github.com/transreal/NBAccess) — ノートブック読み書き・プライバシー管理
- [github](https://github.com/transreal/github) (`GitHubREST``) — GitHub API 連携・パッケージ URL 取得