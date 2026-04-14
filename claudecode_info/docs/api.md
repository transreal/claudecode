# claudecode API Reference

claudecodeパッケージはWolfram Language（Mathematica）からClaude Code CLIおよびAnthropic APIを呼び出す統合インターフェースを提供する。

## クエリ・評価

### ClaudeQuery[prompt] / ClaudeQuery[session, prompt]
Claude Codeにpromptを送り、応答文字列を返す（同期）。
→ String
セッション指定時は履歴と直前の出力/エラーを考慮して回答する。マルチモーダル入力: `ClaudeQuery[{text, Image[...], File[path], ...}]`
Options: WebSearch -> True (CLI組み込み検索許可, 課金なし), WebFetch -> False (API経由Web取得, 課金あり, Fallback->True必須), Fallback -> False, Timeout -> Automatic (秒)

### ClaudeQuerySync[prompt]
Claudeにpromptを送り、応答文字列を同期的に返す（セッション履歴・ノートブック書き込みなし軽量版）。
→ String
WindowStatusAreaに経過時間を表示する。モデルルーティング: Model->Automatic かつ PrivacyLevel<=0.5 → Claude Code CLI使用; PrivacyLevel>0.5 → $ClaudePrivateModelを自動使用。
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic
例: ClaudeQuerySync[prompt, Model -> {"anthropic", "claude-sonnet-4-6"}]

### ClaudeQueryBg[prompt]
FrontEnd操作・ScheduledTask生成なしでClaudeに同期問い合わせし、応答文字列を返す。
→ String
SocketListenハンドラ・ScheduledTaskコールバック等の非同期コンテキストから安全に呼び出せる（rule 95: URLRead相当の安全な代替手段）。
Options: Fallback -> False, Model -> Automatic, Timeout -> Automatic

### ClaudeQueryAsync[prompt, callback, nb]
Claudeに非同期で問い合わせ、完了時にcallback[応答文字列]を呼ぶ。
→ Null (副作用)
nbは出力先NotebookObject。カーネルをブロックしない。WindowStatusAreaに経過時間を表示する。
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic

### ClaudeWriteResponse[nb, text]
マークダウン形式のtextをノートブックのセルとして展開する。
→ Null (副作用)
見出し・リスト・コードブロック等を適切なセルスタイルに変換する。ClaudeQuerySyncで取得した応答をノートブックに出力する際に使用する。
Options: AutoEvaluate -> False (Trueでコード生成セルを自動実行)

### ClaudeMath[task] → String
Mathematicaコード生成に特化したプロンプトでClaudeを呼び出す。

### ClaudeExtractCode[response] → String
Claudeの応答から最初の```mathematicaブロックを抽出する。

### ClaudeExtractAllCode[response] → List
Claudeの応答から全```mathematicaブロックをリストで返す。

### ClaudeSpec[task] / ClaudeSpec[{task, image, ...}]
ノートブック内容からプログラムの仕様を生成する。
→ String
画像付きで仕様を生成可能。パレットからはセル選択で呼び出し可能。

### ClaudeEval[task] / ClaudeEval[session, task]
コードを非同期で生成・表示し、セッションに履歴を保存する。
→ TaskObject
入力: テキスト、Dataset、Image、一般式を混在可能。`ClaudeEval[{text, data, ...}]`
Options: AutoEvaluate -> True (生成Inputセルの自動実行), StartTime -> Now, RepeatInterval -> None, Timeout -> Automatic, Fallback -> False
例: ClaudeEval["プロット生成", RepeatInterval -> Quantity[2,"Hours"]]
例: ClaudeEval["タスク", StartTime -> Now + Quantity[3,"Hours"]]
例: ClaudeEval["タスク", RepeatInterval -> {Quantity[1,"Hours"], 5}] (1時間ごと最大5回, TaskRemove[]で停止)

### ContinueEval[] / ContinueEval[instruction] / ContinueEval[session, instruction]
指定セッション（省略時はデフォルトセッション）で継続する。
→ TaskObject
ContinueEval[] は「エラーを修正してください」でデフォルトセッションを継続する。
Options: StartTime -> Now, Timeout -> Automatic, Fallback -> False

### ContinueUpdate[] / ContinueUpdate[instruction] / ContinueUpdate[pkgName, instruction]
直前のClaudeUpdatePackageの結果を踏まえてバグ修正を継続する。
→ TaskObject
ContinueUpdate[{instruction, img}] でテキスト+画像で継続。pkgName指定で特定パッケージの直前の更新を継続。
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now

### ClaudeDebug[codeOrFile, errorMsg]
デバッグ支援を非同期で求める（即座に返る）。
→ TaskObject

### ClaudeReview[codeOrFile]
コードのレビューを非同期で行う（30000文字超は自動チャンク分割）。
→ TaskObject

### ClaudeReviewChunked[codeOrFile]
ファイルをチャンク分割して非同期レビューする。
→ TaskObject

## セッション管理

### CreateClaudeSession["name"] / CreateClaudeSession[session] / CreateClaudeSession[]
名前付きセッションを作成する（デフォルト履歴を継承）。
→ SessionObject
Options: Inherit -> True (False で独立したセッションを作成)

### ClaudeRestoreSession[] / ClaudeRestoreSession["name"]
セッションをリストアする。
→ SessionObject

### ClaudeListSessions[] → Grid
ノートブック内の全セッションを一覧表示する。

### ClaudeDeleteSession["name"] / ClaudeDeleteSession["name", "All"]
指定名のセッションを削除する。"All"指定でセッションと全履歴を削除する。
→ Null

### ClaudeShowHistory[] / ClaudeShowHistory[session] / ClaudeShowHistory["name"]
セッションの履歴を表示する。
→ Grid

### ClaudeSessionStatus[] / ClaudeSessionStatus[name]
セッションの状態を表示する（アクセス可能ディレクトリ、アタッチメント、作業ディレクトリのファイル等）。
→ Grid

### ClaudeCompactHistory[] / ClaudeCompactHistory[name]
セッションの履歴を手動でコンパクションする。
→ Null
通常は2n+1+wエントリを超えたときに自動実行される。

### ClaudeHistorySize[] → Association
現在のノートブックのセッション履歴サイズを診断する。
戻り値: `<|"Entries"->n, "ByteCount"->b, "KiloBytes"->k, "Status"->s|>`
200KB超でコンパクション推奨、500KB超で危険。

## パッケージ操作

### ClaudeCreatePackage[name, prompt]
promptに従ってname.wlを新規作成し$packageDirectoryに保存する。
→ Null

### ClaudeUpdatePackage[packageName, prompt]
$packageDirectoryにあるpackageName.wlをClaudeの支援でアップデートし、バックアップを作成する。
→ TaskObject
prompt: 文字列またはリスト `{文字列, Image, File[".../file.pdf"], ...}`
Options: TargetFunctions -> Automatic, StartTime -> Now, Fallback -> False, "UpdateApiMd" -> Automatic ("UpdateApiMd"->False でapi.mdの自動更新をスキップ)
例: ClaudeUpdatePackage["pkg", "修正指示", StartTime -> Now + Quantity[1,"Hours"]]

### ClaudeRestorePackage[packageName]
直前のバックアップを復元する。
→ Null

### ClaudeUpdatePackageHistory[] / ClaudeUpdatePackageHistory[packageName]
パッケージのClaudeUpdatePackage呼び出し履歴を表示しリストで返す。
→ List (`<|"Package"->…, "Timestamp"->…, "Directory"->…|>`のリスト)

### ClaudeBackupDataset[packageName] / ClaudeBackupDataset[]
バックアップ履歴をReview/Pull/DeleteボタンつきGridで表示する。
→ Grid
Review: バックアップ内容を確認, Pull: 復元, Delete: その履歴を削除。

### ClaudeMigrateBackupHistory[packageName] / ClaudeMigrateBackupHistory[]
既存historyの生.wlバックアップを差分形式(.wl.cz/.wl.cdiff)に変換して容量を削減する。
→ Null
Options: DryRun -> False (Trueで削除せず容量削減の見積もりのみ表示)

### ClaudeConvertToPaclet[packageName]
$packageDirectoryのpackageName.wlをPaclet形式に変換する。
→ Null
packageName/フォルダを作成し、Kernel/, Documentation/, PacletInfo.wl等を生成する。元の.wlファイルはバックアップ後に削除される。

## ドキュメント生成

### ClaudeCreateDocumentation["packageName"]
パッケージの詳細なドキュメント一式をClaudeで自動生成する。
→ Null
単一.wl: `$packageDirectory/packageName_info/docs/` に出力。Paclet: `$packageDirectory/packageName/docs/` に出力。
リミット到達時に自動停止し、再実行で未生成分のみ続行する。README.mdは最後に生成される。
Options: References -> {}, Demos -> {}, Disclaimer -> {}, License -> "", Acknowledgments -> {}

### ClaudeUpdateDocumentation["packageName"] / ClaudeUpdateDocumentation["packageName", "更新指示"]
ソース差分に基づき全ドキュメントを自動更新する、または指示に従ってドキュメントを更新する。
→ Null
ノートブックのコンテキストも参照可能（「上で議論された内容を反映して」等）。
Options: TargetFiles -> Automatic (自動判定) | {"api.md"} 等でファイル指定, Mode -> "Update" (既存更新) | "Create" (新規作成)
例: ClaudeUpdateDocumentation["claudecode", "api.mdのみ更新して"]
例: ClaudeUpdateDocumentation["pkg", "指示", TargetFiles -> {"api.md"}]

## ディレクティブ管理

### ClaudeAddDirective[target, description]
Claudeでdescriptionを整形し、Claude DirectivesフォルダのファイルにInstallClaudeDirectives[]を実行して追加する。
→ Null
target: "CLAUDE.md" またはスキル名（例: "wolfram-general"）。元ファイルは自動バックアップされる。

### ClaudeRestoreDirective[target]
ClaudeAddDirectiveの直前バックアップを復元しInstallClaudeDirectives[]を実行する。
→ Null

### ClaudeListDirectives[] → Grid
Claude DirectivesフォルダのCLAUDE.mdと全スキルの一覧を表示する。

### ClaudeUpdateDirective[] / ClaudeUpdateDirective[text]
ソースコードとClaude Directivesの整合性をチェックし、不整合を自動修正する。
→ TaskObject
ClaudeUpdateDirective[text] はtextをClaudeで解釈しCLAUDE.md/rules/skillsの適切なファイルに反映する。ノートブックのコンテキストも参照可能。

### ClaudeDirectiveBackupDataset[] → Grid
Claude Directivesの更新履歴をReview/Pull/DeleteボタンつきGridで表示する。
履歴はClaudeUpdateDirective[text]やClaudeAddDirectiveの実行時に自動保存される。

### ClaudeSyncDirectives[dir]
指定ディレクトリdirのファイルをClaude Directivesフォルダと比較し、dir側が新しいファイルでClaude Directivesを更新する。
→ Null
dirにだけ存在するファイルもコピーする。Claude Directives側にしかないファイルはそのまま。
例: ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]

## アタッチメント

### ClaudeAttach[path] / ClaudeAttach[url] / ClaudeAttach[session, path]
デフォルトセッション（またはsession）に参照資料をアタッチする。
→ Null
URLの場合はPDF化してキャッシュし、アタッチする。アタッチされたファイルはClaudeQuery/ClaudeEval時に自動的にReadされる。
Options: Keywords -> {} (プロンプト中のキーワードに応じて自動注入), Title -> None, Refetch -> False

### ClaudeDetach[path] / ClaudeDetach[session, path]
セッションからファイルをデタッチする。
→ Null

### ClaudeAttachments[] / ClaudeAttachments[session] → List
セッションのアタッチメント一覧を返す。

### ClearAttachments[] / ClearAttachments[session]
セッションの全アタッチメントをクリアする。
→ Null

## 機密データ管理

### MarkConfidential[] / MarkConfidential[cell]
現在のセル（またはcell）を機密マークする。
→ Null
機密セルはClaudeEval/ClaudeQueryのプロンプトから除外される。

### UnmarkConfidential[] / UnmarkConfidential[cell]
機密マークを解除する。
→ Null

### IsConfidential[] / IsConfidential[cell] → True | False
セルが機密マークされているかを返す。

### Confidential[expr]
exprを評価し、そのInput/Outputセルを自動的に機密マークする。
→ exprの評価結果
例: Confidential[secretData = Import["secret.csv"]]

### NonConfidential[expr]
exprを評価し、そのInput/Outputセルの機密マークを明示的に解除する。
→ exprの評価結果
秘密変数や秘密依存変数の値に依存していても、機密解除として扱う。
例: result = NonConfidential[Mean[secretData]]

### ScanConfidentialCells[]
ノートブック全セルをスキャンし、機密変数を参照するセルを自動的に機密マークする。
→ Null
明示的にUnmarkConfidentialされたセルはスキップされる。

## Web検索・取得

### ClaudeWebSearch[query] → String
Web検索を実行し、結果をテキストで返す（Anthropic APIのweb_searchツールを使用）。

### ClaudeWebFetch[url] / ClaudeWebFetch[url, prompt]
指定URLの内容を取得し、要約・抽出して返す。
→ String
promptを指定すると取得内容に対してpromptの指示を実行する。

## ユーティリティ

### ShowClaudePalette[]
Claude Code操作用のパレットを表示する。
→ Null

### ClaudeQueryShowContext[]
デバッグ用: 次のClaudeQueryが送信するノートブックコンテキストを表示する。
→ String

### ClaudeShowAccessConfig[]
デバッグ用: Claude Codeのファイルアクセス設定を表示する。
→ Grid
$ClaudeAccessibleDirs, NBGetAccessibleDirs[], 生成されるsettings.json, CLIフラグを確認可能。

### ClaudeStatus[]
現在実行中の全ClaudeタスクのリアルタイムステータスをGridで表示する。
→ Grid
各タスクの経過時間、現在の状態（思考中/テキスト生成中/ツール実行中）、生成済みテキスト断片数、思考断片数、ツール使用数を表示する。実行中のタスクがない場合はその旨を表示する。

### ClaudeAbort[]
実行中の全ClaudeタスクをStopする。
→ Null
Claude CodeプロセスのKill、ScheduledTaskの停止、フォールバックタスクのキャンセルを行う。パレットの「実行停止」ボタンからも呼び出し可能。

### ClaudePrepareCommit[packageName] / ClaudePrepareCommit[packageName, subject]
前回のGitHubコミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを生成してGitHubRefreshAndCommit実行コマンドをInputセルとして出力する。
→ Null
subjectを指定すると1行目を固定し、本文は自動収集する。
Options: Fallback -> False, DryRun -> False, Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, BaseBranch -> Automatic

### ClaudeCommand["/command"] / ClaudeCommand["subcommand"]
Claude Code CLIのスラッシュコマンドまたはサブコマンドを実行し結果を返す。
→ String
スラッシュコマンド(/始まり)はnode-pty経由で対話モードに送信される。CLIサブコマンド(例: config list)は直接実行される。
例: ClaudeCommand["/help"], ClaudeCommand["/permissions"], ClaudeCommand["config list"], ClaudeCommand["--version"]

### ClaudeCheckSeparation[target]
targetのコードがNBAccessの分離原則に違反している箇所をリストアップする。
→ List
target: ファイルパス | $packageDirectoryの.wl名 | パクレット名
検査項目: SystemCredential直接利用, CellObject直接操作, CellEpilog/CellProlog直接操作, NBAccess`Private`呼び出し, NBAccess公開グローバル直接更新, EvaluationCell/CellPrint/SetSelectedNotebook直接使用, CurrentValue/SetOptionsによるTaggingRules等直接アクセス, SelectionEvaluate/FrontEndTokenExecute等FE状態操作, NBAccess公開グローバルの破壊的更新(AppendTo等)。
$ClaudeTestModelのモデルで検査する。
例: ClaudeCheckSeparation["claudecode"]
例: ClaudeCheckSeparation["C:\\path\\to\\file.wl"]

### ClaudeFixSeparation[target]
分離違反を修正する。
→ TaskObject
targetがファイルパスの場合: バックアップを作成し元ファイルを修正。targetがパッケージ名のみの場合: ClaudeUpdatePackageを呼び出す。事前にClaudeCheckSeparationの結果があればそれを利用する。

### cleanOutput[str] → String
出力テキストをクリーンアップするユーティリティ。

### stripANSI[str] → String
ANSIエスケープシーケンスを除去するユーティリティ。

## LLMGraph

### NotebookLLMGraph[nb]
ノートブックnbのLLMGraphを返す（存在しない場合は新規作成）。
→ LLMGraph
例: g = NotebookLLMGraph[EvaluationNotebook[]]

### NotebookLLMGraphPlot[nb]
ノートブックのLLMGraphをトップレベルで可視化する。
→ Graphics
Orchestratorノードのみを表示し、アクセスレベル別に色分けする。

### NotebookLLMGraphBuild[...]
LLMGraphを構築する。
→ LLMGraph

### NotebookLLMGraphNodes[...]
LLMGraphのノード一覧を返す。
→ List

### NotebookLLMGraphValidate[...]
LLMGraphを検証する。
→ List

### NotebookLLMGraphFetchResponse[...]
LLMGraphノードの応答を取得する。
→ String

### NotebookLLMGraphSubSteps[...]
LLMGraphのサブステップを返す。
→ List

### NotebookLLMGraphFetchL2[...]
LLMGraphのL2レスポンスを取得する。
→ String

### NotebookLLMGraphErrors[...]
LLMGraphのエラー一覧を返す。
→ List

### NotebookLLMGraphUpdateL2Status[...]
LLMGraphのL2ステータスを更新する。
→ Null

### NotebookLLMGraphPlotL2[...]
LLMGraphをL2レベルで可視化する。
→ Graphics

### NotebookLLMGraphRerun[...]
LLMGraphノードを再実行する。
→ TaskObject

### NotebookLLMGraphInvalidateDownstream[...]
LLMGraphの下流ノードを無効化する。
→ Null

### NotebookLLMGraphSummary[...]
LLMGraphのサマリーを返す。
→ String

### NotebookLLMGraphExtractThread[...]
LLMGraphからスレッドを抽出する。
→ List

### NotebookLLMGraphApplyThread[...]
LLMGraphにスレッドを適用する。
→ Null

### LLMGraphExecute[...]
LLMGraphを実行する。
→ TaskObject

### LLMGraphExecuteStatus[...]
LLMGraph実行の状態を返す。
→ Association

### LLMGraphExecuteCancel[...]
LLMGraph実行をキャンセルする。
→ Null

### LLMGraphDAGCreate[...]
DAG形式のLLMGraphを作成する。
→ LLMGraphDAG

### LLMGraphDAGStatus[...]
LLMGraphDAGの状態を返す。
→ Association

### LLMGraphDAGCancel[...]
LLMGraphDAGをキャンセルする。
→ Null

### LLMGraphDAGStop[...]
LLMGraphDAGを停止する。
→ Null

### LLMGraphDAGRetry[...]
LLMGraphDAGを再試行する。
→ TaskObject

### LLMGraphDAGRebuild[...]
LLMGraphDAGを再構築する。
→ LLMGraphDAG

### LLMGraphDAGFindByContext[...]
コンテキストでLLMGraphDAGを検索する。
→ LLMGraphDAG | None

### LLMGraphDAGInspect[...]
LLMGraphDAGを検査する。
→ Association

### LLMGraphDAGMarkFailed[...]
LLMGraphDAGノードを失敗としてマークする。
→ Null

### LLMGraphDAGSnapshot[...]
LLMGraphDAGのスナップショットを$ClaudeSnapshotsに保存する。
→ String (スナップショットパス)

### LLMGraphDAGRestore[...]
スナップショットからLLMGraphDAGを復元する。
→ LLMGraphDAG

### LLMGraphDAGListSnapshots[...]
利用可能なスナップショット一覧を返す。
→ List

### LLMGraphDAGPlot[...]
LLMGraphDAGを可視化する。
→ Graphics

## ランタイム

### ClaudeBuildRuntimeAdapter[...]
Claudeランタイムアダプターを構築する。
→ Association

### ClaudeStartRuntime[...]
Claudeランタイムを起動する。
→ String (ランタイムID)

### ClaudeEvalViaRuntime[...]
ランタイム経由でコードを評価する。
→ TaskObject

### ClaudeBuildTransactionAdapter[...]
トランザクションアダプターを構築する。
→ Association

### ClaudeUpdatePackageViaRuntime[...]
ランタイム経由でパッケージを更新する。
→ TaskObject

### ClaudeApproveProposal[...]
ランタイムからの提案を承認する。
→ Null

### ClaudeRuntimeSnapshot[...]
ランタイムのスナップショットを保存する。
→ String

### ClaudeRuntimeRestore[...]
ランタイムをスナップショットから復元する。
→ Null

### ClaudeRuntimeRetry[...]
ランタイムタスクを再試行する。
→ TaskObject

### ClaudeRuntimeListSnapshots[...]
ランタイムのスナップショット一覧を返す。
→ List

## ファイル処理

### NBFileTranslate[...]
ノートブックファイルを変換する。
→ String

### ClaudeProcessFile[...]
ファイルをClaudeで処理する。
→ String

## グローバル変数

### $ClaudeModel
型: String, 初期値: ""
Claude CLIに渡すモデル名。"" の場合はClaude Code自身のデフォルトモデルを使用する。
例: $ClaudeModel = "claude-opus-4-6"

### $ClaudePrivateModel
型: List, 初期値: {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}
秘密データ処理用のローカルモデル指定。AutoPrivate->True時に秘密変数を含むタスクの生成コードに使用される。形式: {"provider","modelName"} または {"provider","modelName","url"}

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
外部パッケージがキーワードを登録するためのAssociation。プロンプトにキーワードが含まれると対応パッケージのapi.mdがコンテキストに自動注入される。各パッケージが自身のロード時に登録する。claudecode.wl側はパッケージ非依存。
例: $ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒切"}

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
読み込まれるCLAUDE.mdのパス。自動検索されるか、手動で上書きできる。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれたCLAUDE.mdの内容。内容が空の場合、CLAUDE.mdが見つからなかったか内容がない。

### $ClaudeSnapshots
型: String, 初期値: FileNameJoin[{$ClaudeWorkingDirectory, "snapshots"}]
LLMGraphDAGスナップショットの保存ディレクトリ。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude CodeにRead許可する追加ディレクトリリスト。NotebookDirectoryは初回使用時にダイアログで許可を確認する（$packageDirectory配下を除く）。ノートブックのTaggingRulesにNBSetAccessibleDirsで永続化可能。
例: $ClaudeAccessibleDirs = {$packageDirectory, "C:\\Users\\...\\作業フォルダ"}

### $ClaudeFallbackModels
型: List, 初期値: {{"anthropic", $iModelOpus}, {"openai", "gpt-5"}}
フォールバックモデル優先順位。各要素は{"provider","modelName"}または{"provider","modelName","url"}の形式。内部的にはNBAccess`NBSetFallbackModelsに同期される。
例: $ClaudeFallbackModels = {{"anthropic","claude-opus-4-6"},{"lmstudio","gpt-oss-20b","http://127.0.0.1:1234"}}

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
型: String, 初期値: $iModelSonnet (最新Sonnet)
ドキュメント生成・更新時に使用するモデル。"" で$ClaudeModelと同じモデルを使用する。
例: $ClaudeDocModel = "claude-sonnet-4-6"

### $ClaudeTestModel
型: String, 初期値: $ClaudeModelと同じ
分離検証などのテスト用モデル名。別モデルで客観的に検証するために変更可能。
例: $ClaudeTestModel = "claude-sonnet-4-6"

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEvalが再帰的にClaudeEvalを生成する際の最大深度。0で再帰禁止。値を大きくすると多段階の自動タスク連鎖が可能。

### $LLMGraphMaxConcurrency
型: Integer
LLMGraphの最大並列実行数。

### $LLMGraphAutoStopThreshold
型: Integer
LLMGraphの自動停止閾値。

### $ClaudeRoutingProviders
型: List
ルーティングプロバイダーのリスト。

### $UseClaudeRuntime
型: Boolean
Claudeランタイムを使用するかどうかのフラグ。

### $ClaudeLastRuntimeId
型: String
最後に起動したランタイムのID。

## オプションシンボル

### Fallback
ClaudeQuery/ClaudeEval/ContinueEval/ClaudeUpdatePackage等のオプション。
True: Claude Code利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。False (デフォルト): エラーをそのまま返す。

### AutoPrivate
ClaudeQuery/ClaudeEval/ContinueEval のオプション。
True: 秘密変数にアクセスするタスクの場合、生成コードにModel->$ClaudePrivateModel, PrivacySpec->Automaticを付与する。False (デフォルト): 通常動作。

### AutoEvaluate
ClaudeWriteResponse/ClaudeEval のオプション。
True: 生成されたInputセルを自動実行する。ClaudeEvalのデフォルトはTrue。False: 生成のみで実行しない。

### StartTime
ClaudeEval/ContinueEval/ClaudeUpdatePackage のオプション。
DateObjectで実行開始時刻を指定する。例: StartTime -> Now + Quantity[3,"Hours"]

### RepeatInterval
ClaudeEval のオプション。繰り返し実行の間隔。Noneで繰り返しなし（デフォルト）。
例: RepeatInterval -> Quantity[2,"Hours"] (2時間ごとに実行)
例: RepeatInterval -> {Quantity[1,"Hours"], 5} (1時間ごとに最大5回, TaskRemove[]で停止)

### Timeout
ClaudeQuery/ClaudeEval/ContinueEval のオプション。APIフォールバックのタイムアウト秒数。Automaticは$iFallbackTimeout (600秒)。

### WebSearch
ClaudeQuery/ClaudeEval のオプション。
True (デフォルト): Claude Code CLIの組み込みWeb検索ツールを許可する（課金なし）。False: Claude Code CLIのWeb検索を禁止する。WebFetch（課金あり）とは異なる。

### WebFetch
ClaudeQuery/ClaudeEval のオプション。
True: 必ずWeb検索を行う。False: Web検索を行わない。Automatic (ClaudeEvalのデフォルト): Claudeがタスクを分析し、必要なら自動でWeb取得する。ClaudeQueryのデフォルトはFalse。重要: Anthropic API経由で課金が発生するため、Fallback->Trueの場合のみ有効。

### TargetFunctions
ClaudeUpdatePackage のオプション。Automatic (デフォルト): 全関数を対象とする。関数名リストで特定関数のみを更新対象にする。

### TargetFiles
ClaudeUpdateDocumentation のオプション。Automatic (デフォルト): 自動判定。{"api.md"} 等でファイルを指定する。

### Mode
ClaudeUpdateDocumentation のオプション。"Update" (デフォルト): 既存ドキュメントを更新する。"Create": 新規作成する。

### DryRun
ClaudeMigrateBackupHistory/ClaudePrepareCommit のオプション。True: 実際の変更を行わずシミュレーションのみ実行する。False (デフォルト): 実際に変更を適用する。

### Inherit
CreateClaudeSession のオプション。True (デフォルト): デフォルト履歴を継承する。False: 独立したセッションを作成する。

### Model
ClaudeQuerySync/ClaudeQueryAsync のオプション。Automatic (デフォルト): PrivacyLevelに応じて自動選択。{"provider","model"}: 指定モデルをAPI経由で使用する。

### PrivacySpec
ClaudeQuerySync/ClaudeQueryAsync のオプション。プライバシースペックを指定する。Automaticで自動判定。

### Keywords
ClaudeAttach のオプション。リスト形式でキーワードを登録すると、プロンプト中のキーワードに応じてアタッチメントが自動注入される。

### Title
ClaudeAttach のオプション。アタッチメントのタイトルを指定する。NoneのときはURL等から自動取得または省略。

### Refetch
ClaudeAttach のオプション。False (デフォルト): キャッシュがあれば再利用する。True: URLを再取得する。

### References
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。URLや書籍名のリストを指定するとREADME.mdに参考文献セクションを追加する。
例: References -> {"https://...", "書籍名"}

### Demos
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。デモ動画や使用例のURLリストを指定するとREADME.mdに反映する。
例: Demos -> {"https://youtu.be/...", "https://example.com/demo.nb"}

### Disclaimer
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。免責事項セクションに追加する文言のリストを指定する。

### License
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。空文字列(デフォルト): GitHubREST`$GitHubLicenseHolderが非空ならMITライセンスを自動挿入。文字列指定: そのままライセンステキストとして挿入。
例: License -> "MIT"

### Acknowledgments
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。謝辞セクションに追加する文言のリストを指定する。指定時はREADME.mdの免責事項の前に配置する。
例: Acknowledgments -> {"本研究はJSPS科研費の助成を受けた"}

### Owner
ClaudePrepareCommit のオプション。GitHubリポジトリのオーナー名。Automaticで自動判定。

### Repository
ClaudePrepareCommit のオプション。GitHubリポジトリ名。Automaticで自動判定。

### Branch
ClaudePrepareCommit のオプション。コミット先ブランチ名。Automaticで自動判定。

### BaseBranch
ClaudePrepareCommit のオプション。比較元ブランチ名。Automaticで自動判定。