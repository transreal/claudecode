# claudecode API Reference

ClaudeCode` パッケージは Mathematica ノートブックから Claude Code CLI を呼び出し、AI支援コーディング・パッケージ管理・ドキュメント生成を行うためのインターフェースを提供する。

## グローバル変数

### $ClaudeModel
型: String, 初期値: ""
Claude CLI に渡すモデル名。"" の場合は Claude Code 自身のデフォルトモデルを使用する。
例: `$ClaudeModel = "claude-opus-4-6"`

### $ClaudePrivateModel
型: List, 初期値: なし
秘密データ処理用のローカルモデル指定。AutoPrivate -> True 時に秘密変数を含むタスクの生成コードに使用される。
例: `$ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}`

### $ClaudeTimeout
型: Numeric, 初期値: 1200
ClaudeQuery・ClaudeEval 等のタイムアウト秒数。

### $ClaudeVerbose
型: Boolean, 初期値: False
True の場合、履歴コンパクション等の詳細ログを Messages に出力する。

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code を起動する作業ディレクトリ。配下の .claude/CLAUDE.md, .claude/rules/, .claude/skills/ を Claude Code に読ませる。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索されるか手動で上書きできる。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。空の場合は CLAUDE.md が見つからなかったか内容がないことを意味する。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。NotebookDirectory は初回使用時にダイアログで許可を確認する（$packageDirectory 配下を除く）。
例: `$ClaudeAccessibleDirs = {$packageDirectory, "F:\\Dropbox\\Mathematica-oneDrive"}`

### $ClaudeFallbackModels
型: List, 初期値: {{"anthropic", $iModelOpus}, {"openai", "gpt-5"}}
フォールバックモデル優先順位。各要素は `{"provider", "modelName"}` または `{"provider", "modelName", "url"}` の形式。内部的に NBAccess`NBSetFallbackModels に同期される。
例: `$ClaudeFallbackModels = {{"anthropic","claude-opus-4-6"},{"lmstudio","gpt-oss-20b","http://127.0.0.1:1234"}}`

### $ClaudeDocModel
型: String, 初期値: 最新 Sonnet モデル
ドキュメント生成・更新時に使用するモデル。"" で $ClaudeModel と同じモデルを使用。
例: `$ClaudeDocModel = "claude-sonnet-4-6"`

### $ClaudeDocRetryDelay
型: Numeric, 初期値: 60
ドキュメント生成のリトライ待機秒数。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
ドキュメント生成の最大リトライ回数。

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースの最大文字数。

### $ClaudeTestModel
型: String, 初期値: $ClaudeModel の値
分離検証など外部テスト用モデル名。別モデルで客観的に検証するために変更可能。
例: `$ClaudeTestModel = "claude-sonnet-4-6"`

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval が再帰的に ClaudeEval/ContinueEval を生成する際の最大深度。0 で再帰禁止。

### $ClaudePackageKeywordMap
型: Association, 初期値: なし
外部パッケージがキーワードを登録するための Association。プロンプトにキーワードが含まれると対応パッケージの api.md がコンテキストに自動注入される。各パッケージが自身のロード時に登録する。
例: `$ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒切"}`

## コアクエリ関数

### ClaudeQuery[prompt] → String
Claude Code に prompt を送り、応答文字列を返す（同期）。セッション履歴とノートブック書き込みを行う標準関数。
ClaudeQuery[session, prompt] でセッション履歴と直前の出力/エラーを考慮して回答する。
ClaudeQuery[{text, Image[...], File[path], ...}] でマルチモーダル入力（画像/PDF/音声を API に直接送信）。
Options: WebSearch -> True (Claude Code CLI 組み込み Web 検索許可、無料), WebFetch -> False (API 経由 Web 取得、課金あり・Fallback->True 必須), Fallback -> False, Timeout -> Automatic

### ClaudeQuerySync[prompt, opts] → String
セッション履歴やノートブック書き込みを行わない軽量同期版。WindowStatusArea に経過時間を表示する。
モデルルーティング: Model -> Automatic かつ PrivacyLevel <= 0.5 → Claude Code CLI、PrivacyLevel > 0.5 → $ClaudePrivateModel を自動使用。
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic
例: `ClaudeQuerySync[prompt, PrivacyLevel -> 1.0]`
例: `ClaudeQuerySync[prompt, Model -> {"anthropic", "claude-sonnet-4-6"}]`

### ClaudeQueryAsync[prompt, callback, nb, opts]
Claude に非同期で問い合わせ、完了時に callback[応答文字列] を呼ぶ。カーネルをブロックしない。nb は出力先 NotebookObject。
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic

### ClaudeWriteResponse[nb, text, opts]
マークダウン形式のテキストをノートブックのセルとして展開する。見出し・リスト・コードブロック等を適切なセルスタイルに変換する。ClaudeQuerySync で取得した応答をノートブックに出力する際に使用。
Options: AutoEvaluate -> False

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
Options: AutoEvaluate -> True (生成された Input セルの自動実行制御), StartTime -> Now (実行開始時刻を DateObject で指定), RepeatInterval -> None (繰り返し実行・例: Quantity[2,"Hours"]), Timeout -> Automatic (API フォールバックのタイムアウト秒数、Automatic は 600秒), Fallback -> False, AutoPrivate -> False (True: 秘密変数にアクセスするタスクの場合 Model -> $ClaudePrivateModel, PrivacySpec -> Automatic を付与)
例: `ClaudeEval["グラフを描いて", RepeatInterval -> {Quantity[1,"Hours"], 5}]` (1時間ごとに最大5回実行)
返値: RepeatInterval 指定時は TaskObject（TaskRemove[] で停止可能）

### ContinueEval[session, instruction]
指定セッションで継続する。
ContinueEval[instruction] はデフォルトセッションで継続。
ContinueEval[] は「エラーを修正してください」でデフォルトセッションを継続。
Options: StartTime -> Now, Timeout -> Automatic, Fallback -> False, AutoPrivate -> False

### ContinueUpdate[opts]
直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を継続する。
ContinueUpdate["instruction"] で追加指示を付けて継続。
ContinueUpdate["pkgName", "instruction"] で指定パッケージの直前の更新を継続。
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now

## セッション管理

### CreateClaudeSession["name"] → Session
名前付きセッションを作成する（デフォルト履歴を継承）。
CreateClaudeSession[session] で既存セッションの履歴を継承した新セッションを作成。
CreateClaudeSession[] でデフォルト履歴を継承した新セッションを作成。
CreateClaudeSession[Inherit -> False] で独立したセッションを作成。

### ClaudeRestoreSession[] → Session
デフォルトセッションをリストアする。
ClaudeRestoreSession["name"] で指定名のセッションをリストアする。

### ClaudeListSessions[] → Grid
ノートブック内の全セッションを一覧表示する。

### ClaudeDeleteSession["name"]
指定名のセッションを削除する。
ClaudeDeleteSession["name", "All"] でセッションと全履歴を削除する。

### ClaudeShowHistory[] → Grid
デフォルトセッションの履歴を表示する。
ClaudeShowHistory[session] または ClaudeShowHistory["name"] で指定セッションの履歴を表示。

### ClaudeSessionStatus[] → Grid
デフォルトセッションの状態（アクセス可能ディレクトリ、アタッチメント、作業ディレクトリのファイル等）を表示する。
ClaudeSessionStatus[name] で指定名のセッションの状態を表示。

### ClaudeCompactHistory[] 
デフォルトセッションの履歴を手動でコンパクションする。通常は 2n+1+w エントリを超えたときに自動実行される。
ClaudeCompactHistory[name] で指定セッションをコンパクション。

### ClaudeHistorySize[] → Association
現在のノートブックのセッション履歴サイズを診断する。Entries・ByteCount・KiloBytes・Status を含む Association を返す。200KB 超でコンパクション推奨、500KB 超で危険。

## アタッチメント

### ClaudeAttach[path]
デフォルトセッションに参照資料をアタッチする。アタッチされたファイルは ClaudeQuery/ClaudeEval 時に自動的に Read される。
ClaudeAttach[session, path] で指定セッションにアタッチ。

### ClaudeDetach[path]
デフォルトセッションからファイルをデタッチする。
ClaudeDetach[session, path] で指定セッションからデタッチ。

### ClaudeAttachments[] → List
デフォルトセッションのアタッチメント一覧を返す。
ClaudeAttachments[session] で指定セッションの一覧を返す。

### ClearAttachments[]
デフォルトセッションの全アタッチメントをクリアする。
ClearAttachments[session] で指定セッションの全アタッチメントをクリア。

## パッケージ操作

### ClaudeCreatePackage[name, prompt]
prompt に従って name.wl を新規作成し $packageDirectory に保存する。

### ClaudeUpdatePackage[packageName, prompt, opts]
$packageDirectory にある packageName.wl を Claude の支援でアップデートし、バックアップを作成する。prompt は文字列またはリスト `{文字列, Image, File[".../file.pdf"], ...}` を指定可能。
Options: TargetFunctions -> Automatic (更新対象関数を限定), StartTime -> Now, Fallback -> False, "UpdateApiMd" -> Automatic (False で api.md の自動更新をスキップ)
例: `ClaudeUpdatePackage["pkg", "修正指示", StartTime -> Now + Quantity[1, "Hours"]]`

### ClaudeRestorePackage[packageName]
直前のバックアップを復元する。

### ClaudeConvertToPaclet[packageName]
$packageDirectory の packageName.wl を Paclet 形式に変換する。packageName/ フォルダを作成し、Kernel/, Documentation/, PacletInfo.wl 等を生成する。元の .wl ファイルはバックアップ後に削除される。

### ClaudeUpdatePackageHistory[] → List
全パッケージの ClaudeUpdatePackage 呼び出し履歴を表示しリストで返す。
ClaudeUpdatePackageHistory[packageName] で指定パッケージの更新履歴を表示しリストで返す。各エントリは `<|"Package"->..., "Timestamp"->..., "Directory"->...|>` の Association。

### ClaudeBackupDataset[packageName] → Grid
指定パッケージのバックアップ履歴を Review/Pull/Delete ボタン付き Grid で表示する。
ClaudeBackupDataset[] で全パッケージのバックアップ履歴を表示する。Review はバックアップ内容確認、Pull は復元、Delete はその履歴を削除。

### ClaudeMigrateBackupHistory[packageName, opts]
既存の history 内の生 .wl バックアップを差分形式 (.wl.cz / .wl.cdiff) に変換して容量を削減する。
ClaudeMigrateBackupHistory[] で全パッケージに対して実行する。
Options: DryRun -> False (True で削除せず容量削減の見積もりを表示)

## ドキュメント生成

### ClaudeCreateDocumentation["packageName", opts]
パッケージの詳細なドキュメント一式を Claude で自動生成する。$packageDirectory 内の packageName.wl または packageName/ Paclet を対象とする。単一 .wl: $packageDirectory/packageName_info/docs/ に出力。Paclet: $packageDirectory/packageName/docs/ に出力。リミット到達時に自動停止し、再実行で未生成分のみ続行する。README.md は最後に生成される。
Options: References -> {} (README.md に参考文献セクションを追加する URL や書籍名のリスト), Demos -> {} (README.md に反映するデモ動画や使用例の URL リスト), Disclaimer -> {} (免責事項セクションに追加する文言のリスト), License -> "" (空文字列: GitHubREST`$GitHubLicenseHolder が非空なら MIT ライセンスを自動挿入、文字列指定: そのままライセンステキストとして挿入), Acknowledgments -> {} (謝辞セクションに追加する文言のリスト・免責事項の前に配置)

### ClaudeUpdateDocumentation["packageName", opts]
ソース差分に基づき全ドキュメントを自動更新する。
ClaudeUpdateDocumentation["packageName", "更新指示"] で指示に従ってドキュメントを更新する。ノートブックのコンテキストも参照可能（「上で議論されている内容を反映して」など）。
Options: TargetFiles -> Automatic (自動判定、または {"api.md"} 等でファイル指定), Mode -> "Update" (既存更新) または "Create" (新規作成)
例: `ClaudeUpdateDocumentation["claudecode", "api.mdのみ更新して"]`
例: `ClaudeUpdateDocumentation["pkg", "...", TargetFiles -> {"api.md"}]`

## ディレクティブ管理

### ClaudeAddDirective[target, description]
Claude で description を整形し、Claude Directives フォルダのファイルに追加して InstallClaudeDirectives[] を実行する。target は "CLAUDE.md" またはスキル名（例: "wolfram-general"）。元ファイルは自動バックアップされる。

### ClaudeRestoreDirective[target]
ClaudeAddDirective の直前のバックアップを復元し InstallClaudeDirectives[] を実行する。target は "CLAUDE.md" またはスキル名。

### ClaudeListDirectives[] → Grid
Claude Directives フォルダの CLAUDE.md と全スキルの一覧を表示する。

### ClaudeUpdateDirective[]
ソースコードと Claude Directives の整合性をチェックし、不整合を自動修正する。
ClaudeUpdateDirective[text] で text の内容を Claude で解釈し、CLAUDE.md / rules / skills の適切なファイルに反映する。ノートブックのコンテキストも参照可能。

### ClaudeDirectiveBackupDataset[] → Grid
Claude Directives の更新履歴を Review/Pull/Delete ボタン付き Grid で表示する。履歴は ClaudeUpdateDirective[text] や ClaudeAddDirective の実行時に自動保存される。

### ClaudeSyncDirectives[dir]
指定ディレクトリ dir のファイルを Claude Directives フォルダと比較し、dir 側が新しいファイルで Claude Directives を更新する。dir にのみ存在するファイルもコピーする。Claude Directives 側にしかないファイルはそのまま。
例: `ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]`

## 機密データ管理

### MarkConfidential[]
現在のセルを機密マークする。
MarkConfidential[cell] で指定セルを機密マークする。機密セルは ClaudeEval/ClaudeQuery のプロンプトから除外される。

### UnmarkConfidential[]
現在のセルの機密マークを解除する。
UnmarkConfidential[cell] で指定セルの機密マークを解除する。

### IsConfidential[cell] → Boolean
セルが機密マークされているかを返す。
IsConfidential[] で現在のセルが機密かを返す。

### Confidential[expr] → expr の評価結果
式を評価し、その Input/Output セルを自動的に機密マークする。
例: `Confidential[secretData = Import["secret.csv"]]`

### NonConfidential[expr] → expr の評価結果
式を評価し、その Input/Output セルの機密マークを明示的に解除する。秘密変数や秘密依存変数の値に依存していても、機密解除として扱う。
例: `result = NonConfidential[Mean[secretData]]`

### ScanConfidentialCells[]
ノートブック全セルをスキャンし、機密変数を参照するセルを自動的に機密マークする。明示的に UnmarkConfidential されたセルはスキップされる。

## コード分析・レビュー

### ClaudeSpec["task"] → Cells
ノートブック内容からプログラムの仕様を生成する。
ClaudeSpec[{"task", image, ...}] で画像付きで仕様を生成する。パレットからセル選択で呼び出し可能。

### ClaudeDebug[codeOrFile, errorMsg]
デバッグ支援を非同期で求める（即座に返る）。

### ClaudeReview[codeOrFile]
コードのレビューを非同期で行う（30000文字超は自動チャンク分割）。

### ClaudeReviewChunked[codeOrFile]
ファイルをチャンク分割して非同期レビューする。

### ClaudeCheckSeparation[target]
target のコードが NBAccess の分離原則に違反している箇所をリストアップする。target はファイルパス | $packageDirectory の .wl 名 | パクレット名。$ClaudeTestModel のモデルで検査する。
検査対象: SystemCredential 直接利用、CellObject 直接操作、CellEpilog/CellProlog/NotebookEventActions 直接操作、NBAccess`Private` 関数呼び出し、NBAccess 公開グローバル直接更新、EvaluationCell[]/CellPrint[]/SetSelectedNotebook[] 直接使用、CurrentValue/SetOptions による TaggingRules/CellTags/CellEpilog 属性直接アクセス、CellObject の公開API・戻り値・状態保持への漏洩、SelectionEvaluate/FrontEndTokenExecute 等 FE 状態操作、NBAccess 公開グローバルの破壊的更新 (AppendTo/AssociateTo 等)
例: `ClaudeCheckSeparation["claudecode"]`

### ClaudeFixSeparation[target]
分離違反を修正する。target がファイルパスの場合はバックアップを作成し元ファイルを修正。target がパッケージ名のみの場合は ClaudeUpdatePackage を呼び出す。事前に ClaudeCheckSeparation の結果があればそれを利用する。
例: `ClaudeFixSeparation["claudecode"]`

## Web 機能

### ClaudeWebSearch[query] → String
Web 検索を実行し、結果をテキストで返す。Anthropic API の web_search ツールを使用する。

### ClaudeWebFetch[url] → String
指定 URL の内容を取得し、要約・抽出して返す。
ClaudeWebFetch[url, prompt] で取得内容に対して prompt の指示を実行する。

## LLM グラフ

### NotebookLLMGraph[nb] → Graph
ノートブック nb の LLMGraph を返す。存在しない場合は新規作成する。

### NotebookLLMGraphPlot[nb] → Graphics
ノートブックの LLMGraph をトップレベルで可視化する。Orchestrator ノードのみを表示し、アクセスレベル別に色分けする。

### NotebookLLMGraphBuild[nb] → Graph
既存のセッション履歴から LLMGraph を再構築する。現在のセッション履歴エントリをノードに変換しグラフを生成する。

### NotebookLLMGraphNodes[nb] → Association
ノートブックの LLMGraph 全ノードを Association で返す。

### NotebookLLMGraphValidate[nb] → Association
ノートブックの LLMGraph の整合性を検証する。セッション履歴のエントリ数とノード数の一致、エッジの整合性等を確認する。

### NotebookLLMGraphFetchResponse[nb, nodeID] → String | Missing
指定ノードの response 全文を外部キャッシュから取得する。キャッシュにない場合は Missing["CacheExpired"] を返す。
例: `NotebookLLMGraphFetchResponse[EvaluationNotebook[], "history-3"]`

### NotebookLLMGraphSubSteps[nb, nodeID] → Grid
指定ノードの内部サブステップ履歴を表示する。ClaudeUpdatePackage の内部処理 (read-source, llm-query, merge, validate, reload) が記録される。
例: `NotebookLLMGraphSubSteps[EvaluationNotebook[], "history-5"]`

### NotebookLLMGraphFetchL2[nb, nodeID] → Graph | Missing
指定の L1 ノードが生成したコードブロックの L2 グラフを取得する。L2 グラフは各コードブロックの実行状態・エラー・依存関係を保持する。キャッシュにない場合は Missing["CacheExpired"] を返す。

### NotebookLLMGraphErrors[nb] → Dataset
L2ErrorCount > 0 または Status = "Failed" のノード一覧を Dataset で返す。L2 グラフでエラーが起きた L1 ノードの特定とデバッグに使用する。

### NotebookLLMGraphUpdateL2Status[nb, l1NodeID, l2NodeID, status, msg]
L2 ノードのステータスを手動で更新する。status: "Completed" | "Failed" | "Pending"
例: `NotebookLLMGraphUpdateL2Status[nb, "history-5", "history-5_L2-2", "Failed", "Undefined symbol"]`

### NotebookLLMGraphPlotL2[nb, l1NodeID] → Graphics
指定の L1 ノードが生成したコードブロックの L2 計算グラフを可視化する。

### NotebookLLMGraphRerun[nb, nodeID, opts]
指定ノードの LLM 呼び出しを再実行する。

### NotebookLLMGraphInvalidateDownstream[nb, nodeID]
指定ノードの下流ノードを無効化する。

### NotebookLLMGraphSummary[nb] → Association
LLMGraph の統計サマリーを返す。

### NotebookLLMGraphExtractThread[nb, nodeID] → List
指定ノードから上流をたどったスレッド（会話の連鎖）を抽出する。

### NotebookLLMGraphApplyThread[nb, thread]
抽出されたスレッドをノートブックに適用する。

### LLMGraphExecute[nb, nodeIDs, opts] → TaskObject
LLMGraph の指定ノード群を実行する。

### LLMGraphExecuteStatus[nb] → Association
LLMGraph 実行の現在のステータスを返す。

### LLMGraphExecuteCancel[nb]
LLMGraph 実行をキャンセルする。

## ファイル処理

### NBFileTranslate[...]
ノートブックファイルの翻訳処理を行う。

### ClaudeProcessFile[...]
ファイルに対して Claude による処理を実行する。

## ユーティリティ

### ShowClaudePalette[]
Claude Code 操作用のパレットを表示する。

### ClaudeQueryShowContext[]
デバッグ用: 次の ClaudeQuery が送信するノートブックコンテキストを表示する。

### ClaudeShowAccessConfig[]
デバッグ用: Claude Code のファイルアクセス設定を表示する。$ClaudeAccessibleDirs, NBGetAccessibleDirs[], 生成される settings.json, CLI フラグを確認可能。

### ClaudeStatus[] → Grid
現在実行中の全 Claude タスクのリアルタイム状態を表示する。各タスクの経過時間、現在の状態（思考中/テキスト生成中/ツール実行中）、生成済みテキスト断片数、思考断片数、ツール使用数を表示する。実行中のタスクがない場合はその旨を表示する。

### ClaudeAbort[]
実行中の全 Claude タスクを停止する。Claude Code プロセスの強制終了、ScheduledTask の停止、フォールバックタスクのキャンセルを行う。パレットの「実行停止」ボタンからも呼び出し可能。

### ClaudeCommand["/command"] → String
Claude Code CLI のスラッシュコマンドを実行し結果を返す。スラッシュコマンド (/始まり) は node-pty 経由で対話モードに送信される。CLI サブコマンド（例: config list）は直接実行される。
例: `ClaudeCommand["/help"]`
例: `ClaudeCommand["/permissions"]`
例: `ClaudeCommand["config list"]`
例: `ClaudeCommand["--version"]`

### ClaudePrepareCommit[packageName, opts]
前回の GitHub コミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを生成して GitHubRefreshAndCommit 実行コマンドを Input セルとして出力する。
ClaudePrepareCommit[packageName, subject] で1行目を指定し、本文は自動収集する。
Options: Fallback -> False, DryRun -> False (True でコマンドを生成せずメッセージのみ返す), Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, BaseBranch -> Automatic

## オプションシンボル

### Fallback
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: Claude Code 利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。False (デフォルト): エラーをそのまま返す。

### AutoPrivate
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: 秘密変数にアクセスするタスクの場合、生成コードに Model -> $ClaudePrivateModel, PrivacySpec -> Automatic を付与する。False (デフォルト): 通常動作。

### WebSearch
ClaudeQuery/ClaudeEval のオプション。True (デフォルト): Claude Code CLI 組み込みの Web 検索ツールを許可する。False: Claude Code CLI の Web 検索を禁止する。Claude Code 自体の Web 検索機能であり、API 経由の課金は発生しない。WebFetch (課金あり) とは異なる。

### WebFetch
ClaudeQuery/ClaudeEval のオプション。True: 必ず Web 検索を行う。False: Web 検索を行わない。Automatic (ClaudeEval のデフォルト): Claude がタスクを分析し、必要なら自動で Web 検索する。ClaudeQuery のデフォルトは False。重要: WebFetch は Anthropic API 経由で課金が発生するため、Fallback -> True の場合のみ有効。

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
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。空文字列 (デフォルト): GitHubREST`$GitHubLicenseHolder が非空なら MIT ライセンスを自動挿入。文字列指定: そのままライセンステキストとして挿入。
例: `License -> "MIT"`, `License -> "Apache-2.0 License..."`

### Acknowledgments
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。謝辞セクションに追加する文言のリストを指定する。指定時は README.md の免責事項の前に配置する。
例: `Acknowledgments -> {"本研究は JSPS 科研費の助成を受けた"}`