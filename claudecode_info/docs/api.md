# claudecode API Reference

Wolfram Language Claude Code ハーネス API 完全リファレンス。

## グローバル変数

### $ClaudeModel
型: String, 初期値: ""
Claude CLI に渡すモデル名。デフォルトは Claude Code 自身のデフォルトモデル。

### $ClaudePrivateModel
型: List, 初期値: 自動設定
秘密データ処理用のローカルモデル指定。AutoPrivate -> True 時に秘密変数を含むタスクの生成コードに使用される。

### $ClaudePackageKeywordMap
型: Association
外部パッケージがキーワードを登録するための Association。プロンプトにキーワードが含まれると、対応パッケージの api.md がコンテキストに自動注入される。

### $ClaudeTimeout
型: Integer, 初期値: 1200
ClaudeQuery・ClaudeEval 等のタイムアウト秒数。

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code を起動する作業ディレクトリ。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。

### $ClaudeFallbackModels
型: List, 初期値: 自動設定
フォールバックモデル優先順位。各要素は {"provider", "modelName"} または {"provider", "modelName", "url"} の形式。

### $ClaudeDocRetryDelay
型: Integer, 初期値: 60
ドキュメント生成のリトライ待機秒数。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
ドキュメント生成の最大リトライ回数。

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースの最大文字数。

### $ClaudeDocModel
型: String, 初期値: "claude-sonnet-4-20250514"
ドキュメント生成・更新時に使用するモデル。

### $ClaudeTestModel
型: String, 初期値: $ClaudeModel
分離検証などのテスト用モデル名。

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval が再帰的に ClaudeEval を生成する際の最大深度。

## クエリ・評価

### ClaudeQuery[prompt]
Claude Code に prompt を送り、応答文字列を返す（同期）。
Options: WebSearch -> True, WebFetch -> False, Fallback -> False

### ClaudeQuery[session, prompt]
セッション履歴と直前の出力/エラーを考慮して回答する。

### ClaudeMath[task]
Mathematica コード生成に特化したプロンプトで Claude を呼び出す。

### ClaudeExtractCode[response]
Claude の応答から最初の ```mathematica ブロックを抽出する。

### ClaudeExtractAllCode[response]
Claude の応答から全 ```mathematica ブロックをリストで返す。

### ClaudeEval[task]
コードを非同期で生成・表示し、デフォルトセッションに履歴を保存する。
→ TaskObject
Options: AutoEvaluate -> True, StartTime -> Now, RepeatInterval -> None, Fallback -> False, WebSearch -> True, WebFetch -> Automatic, AutoPrivate -> False

### ClaudeEval[{text, data, ...}]
テキスト、Dataset、Image、一般式を混在できる。

### ClaudeEval[session, task]
指定セッションに履歴を保存する。

### ContinueEval[]
"エラーを修正してください" でデフォルトセッションを継続。

### ContinueEval[instruction]
デフォルトセッションで継続。

### ContinueEval[session, instruction]
指定セッションで継続。
Options: StartTime -> Now, Fallback -> False, AutoPrivate -> False

### ContinueUpdate[]
直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を継続する。

### ContinueUpdate["instruction"]
追加指示を付けて継続。

### ContinueUpdate["pkgName", "instruction"]
指定パッケージの直前の更新を継続。
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now

### ClaudeSpec["task"]
ノートブック内容からプログラムの仕様を生成する。

### ClaudeSpec[{text, image, ...}]
画像付きで仕様を生成。

## パッケージ管理

### ClaudeCreatePackage[name, prompt]
prompt に従って name.wl を新規作成し $packageDirectory に保存する。

### ClaudeUpdatePackage[packageName, prompt]
$packageDirectory にある packageName.wl を Claude の支援でアップデートし、バックアップを作成する。
Options: TargetFunctions -> Automatic, StartTime -> Now, "UpdateApiMd" -> True, Fallback -> False, AutoPrivate -> False

### ClaudeRestorePackage[packageName]
直前のバックアップを復元する。

### ClaudeUpdatePackageHistory[]
全パッケージの ClaudeUpdatePackage 呼び出し履歴を表示しリストで返す。

### ClaudeUpdatePackageHistory[packageName]
指定パッケージの更新履歴を表示しリストで返す。

### ClaudeBackupDataset[]
全パッケージのバックアップ履歴を Review/Pull/Delete ボタン付き Grid で表示する。

### ClaudeBackupDataset[packageName]
指定パッケージのバックアップ履歴を表示する。

### ClaudeConvertToPaclet[packageName]
$packageDirectory の packageName.wl を Paclet 形式に変換する。

### ClaudeMigrateBackupHistory[]
全パッケージのバックアップ履歴を差分形式に変換して容量を削減する。

### ClaudeMigrateBackupHistory[packageName]
指定パッケージのバックアップ履歴を差分形式に変換する。
Options: DryRun -> False

## ドキュメント

### ClaudeCreateDocumentation["packageName"]
パッケージの詳細なドキュメント一式を Claude で自動生成する。
Options: References -> {}, Demos -> {}, Disclaimer -> {}, License -> "", Acknowledgments -> {}, Model -> Automatic

### ClaudeUpdateDocumentation["packageName"]
ソース差分に基づき全ドキュメントを自動更新する。

### ClaudeUpdateDocumentation["packageName", "更新指示"]
指示に従ってドキュメントを更新する。
Options: TargetFiles -> Automatic, Mode -> "Update", References -> Automatic, Demos -> Automatic, Disclaimer -> Automatic, License -> Automatic, Acknowledgments -> Automatic

## セッション管理

### CreateClaudeSession[]
デフォルト履歴を継承した新セッションを作成。

### CreateClaudeSession["name"]
名前付きセッションを作成（デフォルト履歴を継承）。

### CreateClaudeSession[session]
既存セッションの履歴を継承した新セッションを作成。
Options: Inherit -> True

### ClaudeRestoreSession[]
デフォルトセッションをリストア。

### ClaudeRestoreSession["name"]
指定名のセッションをリストア。

### ClaudeListSessions[]
ノートブック内の全セッションを一覧表示する。

### ClaudeDeleteSession["name"]
指定名のセッションを削除する。

### ClaudeDeleteSession["name", "All"]
セッションとその全履歴を削除する。

### ClaudeShowHistory[]
デフォルトセッションの履歴を表示する。

### ClaudeShowHistory[session]
指定セッションの履歴を表示する。

### ClaudeShowHistory["name"]
指定名のセッションの履歴を表示する。

## アタッチメント

### ClaudeAttach[path]
デフォルトセッションに参考資料をアタッチする。

### ClaudeAttach[session, path]
指定セッションにアタッチする。

### ClaudeDetach[path]
デフォルトセッションからファイルをデタッチする。

### ClaudeDetach[session, path]
指定セッションからデタッチする。

### ClaudeAttachments[]
デフォルトセッションのアタッチメント一覧を返す。

### ClaudeAttachments[session]
指定セッションのアタッチメント一覧を返す。

### ClearAttachments[]
デフォルトセッションの全アタッチメントをクリアする。

### ClearAttachments[session]
指定セッションの全アタッチメントをクリアする。

## 秘密データ管理

### MarkConfidential[]
現在のセルを機密マークする。

### MarkConfidential[cell]
指定セルを機密マークする。

### UnmarkConfidential[]
現在のセルの機密マークを解除する。

### UnmarkConfidential[cell]
指定セルの機密マークを解除する。

### IsConfidential[]
現在のセルが機密かを返す。

### IsConfidential[cell]
セルが機密マークされているかを返す。

### Confidential[expr]
式を評価し、その Input/Output セルを自動的に機密マークする。

### NonConfidential[expr]
式を評価し、その Input/Output セルの機密マークを明示的に解除する。

### ScanConfidentialCells[]
ノートブック全セルをスキャンし、機密変数を参照するセルを自動的に機密マークする。

## デバッグ・レビュー

### ClaudeDebug[codeOrFile, errorMsg]
デバッグ支援を非同期で求める（即座に返る）。

### ClaudeReview[codeOrFile]
コードのレビューを非同期で行う（30000文字超は自動チャンク分割）。

### ClaudeReviewChunked[codeOrFile]
ファイルをチャンク分割して非同期レビューする。

## ディレクティブ管理

### ClaudeAddDirective[target, description]
Claude で description を整形し、Claude Directives フォルダのファイルに追加して InstallClaudeDirectives[] を実行する。

### ClaudeRestoreDirective[target]
ClaudeAddDirective の直前のバックアップを復元し InstallClaudeDirectives[] を実行する。

### ClaudeListDirectives[]
Claude Directives フォルダの CLAUDE.md と全スキルの一覧を表示する。

### ClaudeUpdateDirective[]
ソースコードと Claude Directives の整合性をチェックし、不整合を自動修正する。

### ClaudeUpdateDirective[text]
text の内容を Claude で解釈し、CLAUDE.md / rules / skills の適切なファイルに反映する。

### ClaudeDirectiveBackupDataset[]
Claude Directives の更新履歴を Review/Pull/Delete ボタン付き Grid で表示する。

### ClaudeSyncDirectives[dir]
指定ディレクトリ dir のファイルを Claude Directives フォルダと比較し、dir 側の方が新しいファイルで Claude Directives を更新する。

## Web機能

### ClaudeWebSearch[query]
Web 検索を実行し、結果をテキストで返す。

### ClaudeWebFetch[url]
指定 URL の内容を取得し、要約・抽出して返す。

### ClaudeWebFetch[url, prompt]
取得内容に対して prompt の指示を実行する。

## 状態・設定

### ShowClaudePalette[]
Claude Code 操作用のパレットを表示する。

### ClaudeQueryShowContext[]
デバッグ用：次の ClaudeQuery が送信するノートブックコンテキストを表示する。

### ClaudeShowAccessConfig[]
デバッグ用：Claude Code のファイルアクセス設定を表示する。

### ClaudeSessionStatus[]
デフォルトセッションの状態を表示する。

### ClaudeSessionStatus[name]
指定名のセッションの状態を表示する。

### ClaudeCompactHistory[]
デフォルトセッションの履歴を手動でコンパクションする。

### ClaudeCompactHistory[name]
指定セッションをコンパクションする。

### ClaudeHistorySize[]
現在のノートブックのセッション履歴サイズを診断する。

### ClaudeStatus[]
現在実行中の全 Claude タスクのリアルタイム状態を表示する。

### ClaudeCommand["/command"]
Claude Code CLI のスラッシュコマンドを実行し結果を返す。

## NBAccess分離検証

### ClaudeCheckSeparation[target]
target のコードが NBAccess の分離原則に違反している箇所をリストアップする。

### ClaudeFixSeparation[target]
分離違反を修正する。

## コミット準備

### ClaudePrepareCommit[packageName]
前回の GitHub コミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを生成して GitHubRefreshAndCommit 実行コマンドを Input セルとして出力する。

### ClaudePrepareCommit[packageName, subject]
1行目を指定し、本文は自動収集。
Options: Fallback -> False, DryRun -> False, Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, BaseBranch -> Automatic

## オプションシンボル

### AutoPrivate
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True で秘密変数にアクセスするタスクの場合、生成コードに Model -> $ClaudePrivateModel, PrivacySpec -> Automatic を付与する。

### AutoEvaluate
ClaudeEval のオプション。True で生成された Input セルの自動実行を制御する（デフォルト True）。

### Fallback
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True で Claude Code 利用不可時にフォールバックモデルに自動切替。

### StartTime
ClaudeEval/ContinueEval/ClaudeUpdatePackage のオプション。実行開始時刻を DateObject で指定。

### RepeatInterval
ClaudeEval のオプション。繰り返し実行。例: RepeatInterval -> Quantity[2, "Hours"] で 2 時間ごとに実行。

### TargetFiles
ClaudeUpdateDocumentation のオプション。Automatic で自動判定、{"api.md"} 等でファイル指定。

### TargetFunctions
ClaudeUpdatePackage のオプション。Automatic で自動判定、関数名リストで指定。

### Mode
ClaudeUpdateDocumentation のオプション。"Update" （既存更新）または "Create" （新規作成）。

### DryRun
ClaudePrepareCommit/ClaudeMigrateBackupHistory のオプション。True でコマンドを生成せずメッセージのみ返す。

### Inherit
CreateClaudeSession のオプション。False で独立したセッションを作成。

### References
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。URL や書籍名のリストを指定すると README.md に参考文献セクションを追加。

### Demos
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。デモ動画や使用例の URL リストを指定すると README.md に反映。

### Disclaimer
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。免責事項セクションに追加する文言のリストを指定。

### License
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。ライセンステキストを指定。

### Acknowledgments
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。謝辞セクションに追加する文言のリストを指定。

### Owner
ClaudePrepareCommit のオプション。GitHub オーナー名を指定。

### Repository
ClaudePrepareCommit のオプション。GitHub リポジトリ名を指定。

### Branch
ClaudePrepareCommit のオプション。コミット対象ブランチを指定。

### BaseBranch
ClaudePrepareCommit のオプション。差分比較のベースブランチを指定。

### Model
各種関数のオプション。使用モデルを指定。

### WebFetch
ClaudeQuery/ClaudeEval のオプション。True で必ず Web 検索を行う。False で Web 検索を行わない。Automatic で Claude がタスクを分析し、必要なら自動で Web 検索する。

### WebSearch
ClaudeQuery/ClaudeEval のオプション。True（デフォルト）で Claude Code CLI の組み込み Web 検索ツールを許可する。False で禁止。