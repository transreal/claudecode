# claudecode パッケージ API リファレンス

Wolfram Language から Claude Code CLI を操作し、AI支援コーディング・パッケージ管理・LLMグラフ実行を提供するパッケージ。

## グローバル変数

### $ClaudeModel
型: String, 初期値: ""
Claude CLI に渡すモデル名。"" は Claude Code 自身のデフォルトモデルを使用。
例: `$ClaudeModel = "claude-opus-4-6"`

### $ClaudePrivateModel
型: List, 初期値: {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}
機密データ処理用ローカルモデル指定。`AutoPrivate -> True` 時に機密変数を含むタスクの生成コードに使用。
形式: `{"provider", "modelName"}` または `{"provider", "modelName", "url"}`

### $ClaudeTimeout
型: Integer, 初期値: 1200
ClaudeQuery・ClaudeEval 等のタイムアウト秒数。

### $ClaudeVerbose
型: Boolean, 初期値: False
True で履歴コンパクション等の詳細ログを Messages に出力。False は重大エラー以外抑制。

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code を起動する作業ディレクトリ。配下の .claude/CLAUDE.md, .claude/rules/, .claude/skills/ を Claude Code に読ませる。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索または手動上書き可能。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。空の場合は CLAUDE.md が見つからなかったか内容がない。

### $ClaudeSnapshots
型: String, 初期値: FileNameJoin[{$ClaudeWorkingDirectory, "snapshots"}]
LLMGraphDAG スナップショットの保存ディレクトリ。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。NotebookDirectory は初回使用時にダイアログで許可確認（$packageDirectory 配下を除く）。
例: `$ClaudeAccessibleDirs = {$packageDirectory, "C:\\Users\\...\\作業フォルダ"}`

### $ClaudeFallbackModels
型: List, 初期値: {{"anthropic", $iModelOpus}, {"openai", "gpt-5"}}
フォールバックモデル優先順位。各要素は `{"provider", "modelName"}` または `{"provider", "modelName", "url"}` 形式。内部的に NBAccess`NBSetFallbackModels に同期される。

### $ClaudeDocModel
型: String, 初期値: 最新 Sonnet モデル
ドキュメント生成・更新時に使用するモデル。"" で $ClaudeModel と同じモデルを使用。

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
ClaudeEval が再帰的に ClaudeEval/ContinueEval を生成する際の最大深度。0 で再帰禁止。

### $ClaudeTestModel
型: String, 初期値: $ClaudeModel と同じ
分離検証用モデル（ClaudeCheckSeparation で使用）。

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
外部パッケージがキーワードを登録するための Association。プロンプトにキーワードが含まれると対応パッケージの api.md がコンテキストに自動注入される。各パッケージが自身のロード時に登録する。
例: `$ClaudePackageKeywordMap["maildb"] = {"\:30e1\:30fc\:30eb", "mail"}`

### $LLMGraphMaxConcurrency
型: Integer
LLMGraphDAG の最大並列実行数。

### $LLMGraphAutoStopThreshold
型: Integer
LLMGraphDAG の自動停止閾値。

### $UseClaudeRuntime
型: Boolean
True で ClaudeRuntime 経由の実行を有効化。

### $ClaudeLastRuntimeId
型: String
最後に使用した Runtime の ID。

### $ClaudeRoutingProviders
型: List
ルーティング対象プロバイダリスト。

## クエリ・評価

### ClaudeQuery[prompt] → String
Claude Code に prompt を送り、応答文字列を返す（同期）。セッション履歴とノートブック書き込みを行う。
`ClaudeQuery[session, prompt]` はセッション履歴と直前の出力/エラーを考慮して回答。
`ClaudeQuery[{text, Image[...], File[path], ...}]` でマルチモーダル入力（画像/PDF/音声を API に直接送信）。
Options: WebSearch -> True（デフォルト, 無料）, WebFetch -> False（課金あり, Fallback -> True 必須）, Fallback -> False, Timeout -> Automatic

### ClaudeQuerySync[prompt, opts] → String
Claude に prompt を送り、応答文字列を同期的に返す。WindowStatusArea に経過時間を表示。セッション履歴・ノートブック書き込みなしの軽量版。
モデルルーティング: Model -> Automatic かつ PrivacyLevel <= 0.5 → Claude Code CLI / PrivacyLevel > 0.5 → $ClaudePrivateModel を自動使用 / Model -> {"provider","model"} → API 経由。
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic

### ClaudeQueryBg[prompt, opts] → String
FrontEnd 操作・ScheduledTask 生成なしで Claude に同期問い合わせ。SocketListen ハンドラ・ScheduledTask コールバック等の非同期コンテキストから安全に呼び出せる。
Options: Fallback -> False, Model -> Automatic, Timeout -> Automatic

### ClaudeQueryAsync[prompt, callback, nb, opts]
Claude に非同期で問い合わせ、完了時に `callback[応答文字列]` を呼ぶ。カーネルをブロックしない。WindowStatusArea に経過時間を表示。NBBeginJobAtEvalCell を使用。
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic

### ClaudeWriteResponse[nb, text, opts]
マークダウン形式のテキストをノートブックのセルとして展開する。見出し・リスト・コードブロック等を適切なセルスタイルに変換。ClaudeQuerySync で取得した応答をノートブックに出力する際に使用。
Options: AutoEvaluate -> False

### ClaudeMath[task] → String
Mathematica コード生成に特化したプロンプトで Claude を呼び出す。

### ClaudeExtractCode[response] → String
Claude の応答から最初の ```mathematica ブロックを抽出する。

### ClaudeExtractAllCode[response] → List
Claude の応答から全 ```mathematica ブロックをリストで返す。

### ClaudeEval[task, opts]
コードを非同期で生成・表示し、デフォルトセッションに履歴を保存する。
`ClaudeEval[{text, data, ...}]` でテキスト・Dataset・Image・一般式を混在できる。
`ClaudeEval[session, task]` は指定セッションに履歴を保存。
Options: AutoEvaluate -> True（生成 Input セルの自動実行）, StartTime -> Now, RepeatInterval -> None, Timeout -> Automatic, Fallback -> False
例:
```
ClaudeEval["プロット作成", RepeatInterval -> Quantity[2,"Hours"]]
ClaudeEval["タスク", RepeatInterval -> {Quantity[1,"Hours"], 5}]
ClaudeEval["タスク", StartTime -> Now + Quantity[3,"Hours"]]
```
RepeatInterval 指定時は TaskObject を返す。TaskRemove[] で停止可能。

### ContinueEval[session, instruction, opts]
指定セッションで継続。`ContinueEval[instruction]` はデフォルトセッションで継続。`ContinueEval[]` は「エラーを修正してください」でデフォルトセッションを継続。
Options: StartTime -> Now, Timeout -> Automatic, Fallback -> False

### ContinueUpdate[instruction, opts]
直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を継続する。
`ContinueUpdate["pkgName", "instruction"]` は指定パッケージの直前の更新を継続。
`ContinueUpdate[{text, img}]` でテキスト+画像で継続。
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now

### ClaudeSpec[task] → (ノートブック出力)
ノートブック内容からプログラムの仕様を生成する。`ClaudeSpec[{task, image, ...}]` で画像付き仕様生成。パレットからセル選択で呼び出し可能。

## セッション管理

### CreateClaudeSession["name"] → Session
名前付きセッションを作成する（デフォルト履歴を継承）。
`CreateClaudeSession[session]` は既存セッションの履歴を継承した新セッションを作成。
`CreateClaudeSession[]` はデフォルト履歴を継承した新セッションを作成。
`CreateClaudeSession[Inherit -> False]` は独立したセッションを作成。

### ClaudeRestoreSession[] → (セッション復元)
デフォルトセッションをリストア。`ClaudeRestoreSession["name"]` は指定名のセッションをリストア。

### ClaudeListSessions[] → (表示)
ノートブック内の全セッションを一覧表示する。

### ClaudeDeleteSession["name"]
指定名のセッションを削除する。`ClaudeDeleteSession["name", "All"]` はセッションと全履歴を削除。

### ClaudeShowHistory[] → (表示)
デフォルトセッションの履歴を表示する。`ClaudeShowHistory[session]` または `ClaudeShowHistory["name"]` で指定セッションの履歴を表示。

### ClaudeSessionStatus[] → (表示)
デフォルトセッションの状態を表示する。`ClaudeSessionStatus[name]` は指定名のセッション状態を表示。アクセス可能ディレクトリ・アタッチメント・作業ディレクトリのファイル等を確認可能。

### ClaudeCompactHistory[]
デフォルトセッションの履歴をコンパクト化する。

### ClaudeHistorySize[] → Integer
デフォルトセッションの現在の履歴サイズを返す。

## アタッチメント

### ClaudeAttach[path, opts]
デフォルトセッションに参照資料をアタッチする。`ClaudeAttach[url]` は URL のページを PDF 化してキャッシュしアタッチ。`ClaudeAttach[session, path]` は指定セッションにアタッチ。アタッチされたファイルは ClaudeQuery/ClaudeEval 時に自動的に Read される。
Options: Keywords -> {}, Title -> None, Refetch -> False
Keywords で登録するとプロンプト中のキーワードに応じて自動注入される。

### ClaudeDetach[path]
デフォルトセッションからファイルをデタッチする。`ClaudeDetach[session, path]` は指定セッションからデタッチ。

### ClaudeAttachments[] → List
デフォルトセッションのアタッチメント一覧を返す。`ClaudeAttachments[session]` は指定セッションの一覧を返す。

### ClearAttachments[]
デフォルトセッションの全アタッチメントをクリアする。`ClearAttachments[session]` は指定セッションをクリア。

## パッケージ操作

### ClaudeCreatePackage[name, prompt]
prompt に従って name.wl を新規作成し $packageDirectory に保存する。

### ClaudeUpdatePackage[packageName, prompt, opts]
$packageDirectory にある packageName.wl を Claude の支援でアップデートし、バックアップを作成する。prompt は文字列またはリスト `{文字列, Image, File[".../file.pdf"], ...}` を指定可能。
Options: TargetFunctions -> Automatic, StartTime -> Now, Fallback -> False, "UpdateApiMd" -> Automatic
"UpdateApiMd" -> False で api.md の自動更新をスキップ。
例: `ClaudeUpdatePackage["pkg", "修正指示", StartTime -> Now + Quantity[1,"Hours"]]`

### ClaudeRestorePackage[packageName]
直前のバックアップを復元する。

### ClaudeUpdatePackageHistory[] → List
全パッケージの ClaudeUpdatePackage 呼び出し履歴を表示しリストで返す。`ClaudeUpdatePackageHistory[packageName]` は指定パッケージの更新履歴を表示しリストで返す。各エントリは `<|"Package"->..., "Timestamp"->..., "Directory"->...|>` の Association。

### ClaudeBackupDataset[packageName] → (Grid 表示)
指定パッケージのバックアップ履歴を Review/Pull/Delete ボタン付き Grid で表示する。`ClaudeBackupDataset[]` は全パッケージのバックアップ履歴を表示。

### ClaudeMigrateBackupHistory[packageName, opts]
既存の history 内の生 .wl バックアップを差分形式（.wl.cz / .wl.cdiff）に変換して容量削減する。`ClaudeMigrateBackupHistory[]` は全パッケージに対して実行。
Options: DryRun -> False（True で削除せず見積もりのみ表示）

### ClaudeConvertToPaclet[packageName]
$packageDirectory の packageName.wl を Paclet 形式に変換する。packageName/ フォルダを作成し Kernel/, Documentation/, PacletInfo.wl 等を生成する。元の .wl ファイルはバックアップ後に削除される。

## ドキュメント生成

### ClaudeCreateDocumentation["packageName", opts]
パッケージの詳細なドキュメント一式を Claude で自動生成する。$packageDirectory 内の packageName.wl または packageName/ Paclet を対象とする。単一 .wl: $packageDirectory/packageName_info/docs/ に出力。Paclet: $packageDirectory/packageName/docs/ に出力。リミット到達時に自動停止し、再実行で未生成分のみ続行。README.md は最後に生成される。
Options: References -> {}, Demos -> {}, License -> "", Acknowledgments -> {}, Disclaimer -> {}

### ClaudeUpdateDocumentation["packageName", opts]
ソース差分に基づき全ドキュメントを自動更新する。`ClaudeUpdateDocumentation["packageName", "更新指示"]` は指示に従ってドキュメントを更新。ノートブックのコンテキストも参照可能。
Options: TargetFiles -> Automatic（{"api.md"} 等でファイル指定）, Mode -> "Update"（既存更新）または "Create"（新規作成）, References -> {}, Demos -> {}, License -> "", Acknowledgments -> {}, Disclaimer -> {}
例: `ClaudeUpdateDocumentation["claudecode", "api.md のみ更新して", TargetFiles -> {"api.md"}]`

## ドキュメント生成オプションキー

### References
型: List, デフォルト: {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。URL や書籍名のリストを指定すると README.md に参考文献セクションを追加。

### Demos
型: List, デフォルト: {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。デモ動画や使用例の URL リストを指定すると README.md に反映。

### Disclaimer
型: List, デフォルト: {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。免責事項セクションに追加する文言のリスト。

### License
型: String, デフォルト: ""
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。空文字列（デフォルト）: GitHubREST`$GitHubLicenseHolder が非空なら MIT ライセンスを自動挿入。文字列指定: そのままライセンステキストとして挿入。

### Acknowledgments
型: List, デフォルト: {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。謝辞セクションに追加する文言のリスト。指定時は README.md の免責事項の前に配置。

## ディレクティブ管理

### ClaudeAddDirective[target, description]
Claude で description を整形し、Claude Directives フォルダのファイルに追加して InstallClaudeDirectives[] を実行する。target は "CLAUDE.md" またはスキル名（例: "wolfram-general"）。元ファイルは自動バックアップされる。

### ClaudeRestoreDirective[target]
ClaudeAddDirective の直前のバックアップを復元し InstallClaudeDirectives[] を実行する。target は "CLAUDE.md" またはスキル名。

### ClaudeListDirectives[] → (表示)
Claude Directives フォルダの CLAUDE.md と全スキルの一覧を表示する。

### ClaudeUpdateDirective[text]
text の内容を Claude で解釈し、CLAUDE.md / rules / skills の適切なファイルに反映する。`ClaudeUpdateDirective[]` はソースコードと Claude Directives の整合性をチェックし不整合を自動修正する。ノートブックのコンテキストも参照可能。

### ClaudeDirectiveBackupDataset[] → (Grid 表示)
Claude Directives の更新履歴を Review/Pull/Delete ボタン付き Grid で表示する。履歴は ClaudeUpdateDirective[text] や ClaudeAddDirective 実行時に自動保存される。

### ClaudeSyncDirectives[dir]
指定ディレクトリ dir のファイルを Claude Directives フォルダと比較し、dir 側が新しいファイルで Claude Directives を更新する。dir にだけ存在するファイルもコピーする。Claude Directives 側にしかないファイルはそのまま。
例: `ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]`

## 機密データ管理

### MarkConfidential[]
現在のセルを機密マークする。`MarkConfidential[cell]` は指定セルを機密マーク。機密セルは ClaudeEval/ClaudeQuery のプロンプトから除外される。

### UnmarkConfidential[]
現在のセルの機密マークを解除する。`UnmarkConfidential[cell]` は指定セルの機密マークを解除。

### IsConfidential[cell] → Boolean
セルが機密マークされているかを返す。`IsConfidential[]` は現在のセルが機密かを返す。

### Confidential[expr] → expr の評価結果
式を評価し、その Input/Output セルを自動的に機密マークする。
例: `Confidential[secretData = Import["secret.csv"]]`

### NonConfidential[expr] → expr の評価結果
式を評価し、その Input/Output セルの機密マークを明示的に解除する。秘密変数や秘密依存変数の値に依存していても機密解除として扱う。
例: `result = NonConfidential[Mean[secretData]]`

### ScanConfidentialCells[]
ノートブック全セルをスキャンし、機密変数を参照するセルを自動的に機密マークする。明示的に UnmarkConfidential されたセルはスキップされる。

## Web アクセス

### ClaudeWebSearch[query] → String
Web 検索を実行し、結果をテキストで返す。Anthropic API の web_search ツールを使用する。

### ClaudeWebFetch[url] → String
指定 URL の内容を取得し、要約・抽出して返す。`ClaudeWebFetch[url, prompt]` は取得内容に対して prompt の指示を実行する。

### WebFetch
ClaudeQuery/ClaudeEval のオプションキー。True: 必ず Web 検索（課金あり, Fallback -> True 必須）。

### WebSearch
ClaudeQuery/ClaudeEval のオプションキー。True（デフォルト）: Web 検索を許可（無料）。

## ステータス・制御

### ClaudeStatus[] → (表示)
現在実行中の全 Claude タスクのリアルタイム状態を表示する。各タスクの経過時間・現在の状態（思考中/テキスト生成中/ツール実行中）・生成済みテキスト断片数・思考断片数・ツール使用数を表示。実行中のタスクがない場合はその旨を表示。

### ClaudeAbort[]
実行中の全 Claude タスクを停止する。Claude Code プロセスの強制終了・ScheduledTask の停止・フォールバックタスクのキャンセルを行う。パレットの「実行停止」ボタンからも呼び出し可能。

### ClaudeRateLimitStatus[] → Association | None
最後に検出された Claude CLI の rate-limit 情報を Association で返す。rate-limit になっていなければ None。
返り値のキー: "Detected" (DateObject), "Source" ("rate_limit_event"|"result"|"legacy"), "RateLimitType" ("five_hour"|...), "ResetsAt" (DateObject), "ResetsAtUnix" (Integer), "HttpStatus" (429), "Message" (String), "IsUsingOverage" (Boolean)
例:
```
info = ClaudeRateLimitStatus[];
If[AssociationQ[info],
  If[info["ResetsAt"] > Now, Print["復旧まで待機: ", info["ResetsAt"]]],
  Print["rate-limit ではない"]]
```

### ClaudeRateLimitClear[]
内部に保持された rate-limit 情報を手動でクリアする。誤検出や status=allowed の進捗通知によりブロックがかかってしまった際に使用。呼び出し後に ClaudeRateLimitStatus[] は None を返す。

### ClaudeQueryShowContext[] → (表示)
デバッグ用: 次の ClaudeQuery が送信するノートブックコンテキストを表示する。

### ClaudeShowAccessConfig[] → (表示)
デバッグ用: Claude Code のファイルアクセス設定を表示する。$ClaudeAccessibleDirs, NBGetAccessibleDirs[], 生成される settings.json, CLI フラグを確認可能。

## コミット支援

### ClaudePrepareCommit[packageName, opts]
前回の GitHub コミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを生成して GitHubRefreshAndCommit 実行コマンドを Input セルとして出力する。`ClaudePrepareCommit[packageName, subject]` は1行目を指定し、本文は自動収集。
Options: Fallback -> False, DryRun -> False, Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, BaseBranch -> Automatic
DryRun -> True でコマンドを生成せずメッセージのみ返す。

## NBAccess 分離検証

### ClaudeCheckSeparation["packageName"] → (表示)
パッケージの NBAccess 分離原則違反をチェックする。結果はキャッシュされ ClaudeFixSeparation で再利用される。

### ClaudeFixSeparation["packageName"]
ClaudeCheckSeparation の結果に基づき分離原則違反を自動修正する。

## コマンド実行

### ClaudeCommand["/command"] → (実行)
Claude Code CLI のスラッシュコマンドを実行する。
例: `ClaudeCommand["/compact"]`

## パレット

### ShowClaudePalette[]
Claude Code 操作用のパレットを表示する。

## ファイル処理

### NBFileTranslate[...]
ノートブックファイルの翻訳・変換を行う。

### ClaudeProcessFile[...]
ファイルを Claude で処理する。

### cleanOutput[...]
出力のクリーニングを行う。

### stripANSI[...]
ANSI エスケープシーケンスを除去する。

## LLM グラフ（NotebookLLMGraph）

### NotebookLLMGraph[...] → Graph
ノートブックセルから LLM グラフを構築する。

### NotebookLLMGraphPlot[...]  → (表示)
LLM グラフを可視化する。

### NotebookLLMGraphBuild[...]
LLM グラフをビルドする。

### NotebookLLMGraphNodes[...] → List
LLM グラフのノードリストを返す。

### NotebookLLMGraphValidate[...] → Boolean
LLM グラフの妥当性を検証する。

### NotebookLLMGraphFetchResponse[...]
LLM グラフのレスポンスを取得する。

### NotebookLLMGraphSubSteps[...]
LLM グラフのサブステップを返す。

### NotebookLLMGraphFetchL2[...]
LLM グラフの L2 レスポンスを取得する。

### NotebookLLMGraphErrors[...] → List
LLM グラフのエラーリストを返す。

### NotebookLLMGraphUpdateL2Status[...]
LLM グラフの L2 ステータスを更新する。

### NotebookLLMGraphPlotL2[...] → (表示)
LLM グラフの L2 を可視化する。

### NotebookLLMGraphRerun[...]
LLM グラフを再実行する。

### NotebookLLMGraphInvalidateDownstream[...]
LLM グラフの下流ノードを無効化する。

### NotebookLLMGraphSummary[...] → (表示)
LLM グラフのサマリーを表示する。

### NotebookLLMGraphExtractThread[...]
LLM グラフからスレッドを抽出する。

### NotebookLLMGraphApplyThread[...]
LLM グラフにスレッドを適用する。

## LLM グラフ実行（LLMGraphExecute / LLMGraphDAG）

### LLMGraphExecute[...] → TaskObject
LLM グラフを実行する。

### LLMGraphExecuteStatus[...] → Association
LLM グラフ実行のステータスを返す。

### LLMGraphExecuteCancel[...]
LLM グラフ実行をキャンセルする。

### LLMGraphDAGCreate[...] → dagId
DAG を作成する。

### LLMGraphDAGStatus[dagId] → Association
DAG のステータスを返す。

### LLMGraphDAGCancel[dagId]
DAG をキャンセルする。

### LLMGraphDAGStop[dagId]
DAG を停止する。

### LLMGraphDAGRetry[dagId]
DAG を再試行する。

### LLMGraphDAGRebuild[dagId]
DAG を再構築する。

### LLMGraphDAGFindByContext[...] → dagId
コンテキストから DAG を検索する。

### LLMGraphDAGInspect[dagId] → (表示)
DAG の詳細を検査する。

### LLMGraphDAGMarkFailed[dagId]
DAG を失敗状態にマークする。

### LLMGraphDAGSnapshot[dagId] → snapshotId
DAG のスナップショットを保存する。

### LLMGraphDAGRestore[snapshotId]
スナップショットから DAG を復元する。

### LLMGraphDAGListSnapshots[dagId] → List
DAG のスナップショット一覧を返す。

### LLMGraphDAGPlot[dagId] → (表示)
DAG を可視化する。

### LLMGraphDAGMergeHistory[...]
DAG の履歴をマージする。

## Runtime

### ClaudeBuildRuntimeAdapter[...] → adapter
Runtime アダプタを構築する。

### ClaudeStartRuntime[...] → runtimeId
Runtime を起動する。

### ClaudeEvalViaRuntime[runtimeId, task, opts]
Runtime 経由でタスクを評価する。

### ClaudeBuildTransactionAdapter[...] → adapter
トランザクション用アダプタを構築する。

### ClaudeUpdatePackageViaRuntime[runtimeId, packageName, prompt, opts]
Runtime 経由でパッケージを更新する。

### ClaudeApproveProposal[...]
Runtime からのプロポーザルを承認する。

### ClaudeRuntimeSnapshot[runtimeId] → snapshotId
Runtime のスナップショットを保存する。

### ClaudeRuntimeRestore[snapshotId]
スナップショットから Runtime を復元する。

### ClaudeRuntimeListSnapshots[runtimeId] → List
Runtime のスナップショット一覧を返す。

### ClaudeRegisterDAGRuntime[dagId, runtimeId]
DAG に Runtime を登録する。

## 共通オプションキー

### Fallback
ClaudeQuery/ClaudeEval/ContinueEval 等のオプション。True: Claude Code 利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。False（デフォルト）: エラーをそのまま返す。

### AutoPrivate
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: 機密変数にアクセスするタスクの場合、生成コードに Model -> $ClaudePrivateModel, PrivacySpec -> Automatic を付与する。False（デフォルト）: 通常動作。

### AutoEvaluate
ClaudeEval/ClaudeWriteResponse のオプション。True（ClaudeEval デフォルト）: 生成された Input セルを自動実行。False: 手動実行。

### StartTime
ClaudeEval/ContinueEval/ClaudeUpdatePackage 等のオプション。実行開始時刻を DateObject で指定。
例: `StartTime -> Now + Quantity[3, "Hours"]`

### RepeatInterval
ClaudeEval のオプション。繰り返し実行間隔を指定。None（デフォルト）: 1回のみ。Quantity 指定: 一定間隔で繰り返し。`{Quantity[1,"Hours"], 5}` で1時間ごとに最大5回実行。

### Timeout
ClaudeQuery/ClaudeEval/ContinueEval 等のオプション。API フォールバックのタイムアウト秒数。Automatic は $iFallbackTimeout（600秒）を使用。

### TargetFunctions
ClaudeUpdatePackage のオプション。Automatic（デフォルト）: 全関数を対象。関数名リストで対象関数を限定。

### TargetFiles
ClaudeUpdateDocumentation のオプション。Automatic（デフォルト）: 自動判定。{"api.md"} 等でファイルを指定。

### Mode
ClaudeUpdateDocumentation のオプション。"Update"（デフォルト）: 既存更新。"Create": 新規作成。

### DryRun
ClaudePrepareCommit/ClaudeMigrateBackupHistory のオプション。True: 実際の変更を行わず結果のみ表示。False（デフォルト）: 実際に実行。

### Inherit
CreateClaudeSession のオプション。True（デフォルト）: デフォルト履歴を継承。False: 独立したセッションを作成。

### Model
ClaudeQuerySync/ClaudeQueryBg/ClaudeQueryAsync のオプション。Automatic: ルーティングルールに従う。`{"provider", "model"}` 形式で API 経由で使用するモデルを直接指定。

### PrivacyLevel
ClaudeQuerySync/ClaudeQueryAsync のオプション。0.0〜1.0 の数値。Automatic: 自動判定。0.5 超で $ClaudePrivateModel を使用。

### PrivacySpec
機密データ処理の仕様を指定するオプション。Automatic: 自動検出。

### Keywords
ClaudeAttach のオプション。キーワードリストを登録するとプロンプト中のキーワードに応じてアタッチメントが自動注入される。デフォルト: {}。

### Title
ClaudeAttach のオプション。アタッチメントのタイトルを指定。None（デフォルト）: 自動取得。

### Refetch
ClaudeAttach のオプション。True: キャッシュを無視して再取得。False（デフォルト）: キャッシュを使用。

### Owner
ClaudePrepareCommit のオプション。GitHub リポジトリのオーナー名。Automatic: 自動判定。

### Repository
ClaudePrepareCommit のオプション。GitHub リポジトリ名。Automatic: 自動判定。

### Branch
ClaudePrepareCommit のオプション。対象ブランチ名。Automatic: 自動判定。

### BaseBranch
ClaudePrepareCommit のオプション。ベースブランチ名。Automatic: 自動判定。