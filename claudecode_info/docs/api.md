# ClaudeCode API リファレンス

ClaudeCode パッケージは Wolfram Language から Claude Code CLI および Anthropic API を操作するための統合インターフェースだ。

## グローバル変数

### $ClaudeModel
型: String, 初期値: ""
Claude CLI に渡すモデル名。空文字列は Claude Code 自身のデフォルトモデルを使用する。例: `$ClaudeModel = "claude-opus-4-6"`

### $ClaudePrivateModel
型: List, 初期値: {{"anthropic", $iModelOpus}, {"openai", "gpt-5"}}
秘密データ処理用のローカルモデル指定。`AutoPrivate -> True` 時に機密変数を含むタスクの生成コードに使用される。形式: `{"provider", "modelName"}` または `{"provider", "modelName", "url"}`。例: `$ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}`

### $ClaudeTimeout
型: Number, 初期値: 1200
ClaudeQuery・ClaudeEval 等のタイムアウト秒数。

### $ClaudeVerbose
型: Boolean, 初期値: False
True: 履歴コンパクション等の詳細ログを Messages に出力する。False: 重大エラー以外の ClaudeCode ログを抑制する。

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code を起動する作業ディレクトリ。配下の `.claude/CLAUDE.md`, `.claude/rules/`, `.claude/skills/` を Claude Code に読ませる。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索されるか手動で上書きできる。例: `$ClaudeMDPath = "C:\\proj\\CLAUDE.md"`

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。内容が空の場合、CLAUDE.md が見つからなかったか内容がない。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。NotebookDirectory は初回使用時にダイアログで許可を確認する（$packageDirectory 配下を除く）。ノートブックの TaggingRules にも NBSetAccessibleDirs で永続化可能。例: `$ClaudeAccessibleDirs = {$packageDirectory, "C:\\Users\\...\\作業フォルダ"}`

### $ClaudeFallbackModels
型: List, 初期値: {{"anthropic", $iModelOpus}, {"openai", "gpt-5"}}
フォールバックモデル優先順位。各要素は `{"provider", "modelName"}` または `{"provider", "modelName", "url"}` の形式。内部的に `NBAccess`NBSetFallbackModels` に同期される。例: `$ClaudeFallbackModels = {{"anthropic","claude-opus-4-6"},{"lmstudio","gpt-oss-20b","http://127.0.0.1:1234"}}`

### $ClaudeDocModel
型: String, 初期値: $iModelSonnet
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

### $ClaudeTestModel
型: String, 初期値: $ClaudeModel と同じ
分離検証などのテスト用モデル名。別モデルで客観的に検証するために変更可能。例: `$ClaudeTestModel = "claude-sonnet-4-6"`

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
外部パッケージがキーワードを登録するための Association。プロンプトにキーワードが含まれると対応パッケージの api.md がコンテキストに自動注入される。各パッケージが自身のロード時に登録する。claudecode.wl 側はパッケージ非依存。例: `$ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒切"}`

### $LLMGraphMaxConcurrency
型: Integer
LLMGraph の最大並列実行数。

## コアクエリ

### ClaudeQuery[prompt] → String
ClaudeQuery[session, prompt] → String
Claude Code に prompt を送り、応答文字列を返す（同期）。`ClaudeQuery[session, prompt]` はセッション履歴と直前の出力/エラーを考慮して回答する。`ClaudeQuery[{text, Image[...], File[path], ...}]` でマルチモーダル入力（画像/PDF/音声を API に直接送信）。
Options: WebSearch -> True (Claude Code CLI の組み込み Web 検索許可、無料), WebFetch -> False (API 経由 Web 取得、課金あり・Fallback -> True 必須), Fallback -> False, Timeout -> Automatic (秒)

### ClaudeQuerySync[prompt]
Options を含む ClaudeQuery 同期版。WindowStatusArea に経過時間を表示する。セッション履歴やノートブック書き込みは行わない軽量版。モデルルーティング: Model -> Automatic かつ PrivacyLevel <= 0.5 → Claude Code CLI、PrivacyLevel > 0.5 → $ClaudePrivateModel を自動使用。Model -> {"provider","model"} で指定モデルを API 経由で使用。
→ String
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic
例: `ClaudeQuerySync[prompt, PrivacyLevel -> 1.0]`
例: `ClaudeQuerySync[prompt, Model -> {"anthropic", "claude-sonnet-4-6"}]`

### ClaudeQueryBg[prompt]
FrontEnd 操作・ScheduledTask 生成なしで Claude に同期問い合わせし、応答文字列を返す。SocketListen ハンドラ・ScheduledTask コールバック等の非同期コンテキストから安全に呼び出せる（URLRead 相当の安全な代替手段）。
→ String
Options: Fallback -> False, Model -> Automatic, Timeout -> Automatic

### ClaudeQueryAsync[prompt, callback, nb]
Claude に非同期で問い合わせ、完了時に `callback[応答文字列]` を呼ぶ。nb は出力先 NotebookObject。カーネルをブロックしない。WindowStatusArea に経過時間を表示する。Job システム (NBBeginJobAtEvalCell) を使用する。
→ Null（即座に返る）
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic

### ClaudeWriteResponse[nb, text]
マークダウン形式のテキストをノートブックのセルとして展開する。見出し・リスト・コードブロック等を適切なセルスタイルに変換する。ClaudeQuerySync で取得した応答をノートブックに出力する際に使用する。
→ Null
Options: AutoEvaluate -> False
例: `ClaudeWriteResponse[EvaluationNotebook[], response, AutoEvaluate -> True]`

## コード生成・評価

### ClaudeEval[task]
ClaudeEval[{text, data, ...}]
ClaudeEval[session, task]
コードを非同期で生成・表示し、デフォルトセッションに履歴を保存する。テキスト、Dataset、Image、一般式を混在できる。指定セッションに履歴を保存する形式もある。
→ TaskObject
Options: AutoEvaluate -> True (生成された Input セルの自動実行を制御), StartTime -> Now (実行開始時刻を DateObject で指定), RepeatInterval -> None (繰り返し実行。例: `Quantity[2,"Hours"]` で 2 時間ごと、`{Quantity[1,"Hours"], 5}` で 1 時間ごとに最大 5 回), Timeout -> Automatic (API フォールバックのタイムアウト秒数、Automatic は $iFallbackTimeout=600 秒), Fallback -> False, WebSearch -> True, WebFetch -> Automatic, AutoPrivate -> False
例: `ClaudeEval[{"この Dataset を分析して", myDataset}]`
例: `task = ClaudeEval["毎時レポート生成", RepeatInterval -> Quantity[1,"Hours"]]; TaskRemove[task]`

### ContinueEval[session, instruction]
ContinueEval[instruction]
ContinueEval[]
指定セッションで継続する。引数なしは "エラーを修正してください" でデフォルトセッションを継続する。
→ TaskObject
Options: StartTime -> Now, Timeout -> Automatic, Fallback -> False, AutoPrivate -> False

### ContinueUpdate[]
ContinueUpdate["instruction"]
ContinueUpdate[{" instruction", img}]
ContinueUpdate["pkgName", "instruction"]
直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を継続する。テキスト+画像での継続も可能。指定パッケージの直前の更新を継続する形式もある。
→ TaskObject
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now

### ClaudeMath[task] → String
Mathematica コード生成に特化したプロンプトで Claude を呼び出す。

### ClaudeExtractCode[response] → String
Claude の応答から最初の \`\`\`mathematica ブロックを抽出する。

### ClaudeExtractAllCode[response] → List
Claude の応答から全 \`\`\`mathematica ブロックをリストで返す。

### ClaudeSpec["task"]
ClaudeSpec[{"task", image, ...}]
ノートブック内容からプログラムの仕様を生成する。画像付きで仕様を生成する形式もある。パレットからはセル選択で呼び出し可能。

## セッション管理

### CreateClaudeSession["name"] → session
CreateClaudeSession[session] → session
CreateClaudeSession[] → session
名前付きセッションを作成する（デフォルト履歴を継承）。既存セッションの履歴を継承した新セッションを作成する形式もある。`Inherit -> False` で独立したセッションを作成する。
Options: Inherit -> True

### ClaudeRestoreSession[] → session
ClaudeRestoreSession["name"] → session
デフォルトセッション、または指定名のセッションをリストアする。

### ClaudeListSessions[] → Grid
ノートブック内の全セッションを一覧表示する。

### ClaudeDeleteSession["name"]
ClaudeDeleteSession["name", "All"]
指定名のセッションを削除する。"All" を指定するとセッションとその全履歴を削除する。

### ClaudeShowHistory[]
ClaudeShowHistory[session]
ClaudeShowHistory["name"]
デフォルトセッション、指定セッション、または指定名のセッションの履歴を表示する。

### ClaudeCompactHistory[]
ClaudeCompactHistory[name]
デフォルトセッション、または指定セッションの履歴を手動でコンパクションする。通常は 2n+1+w エントリを超えたときに自動実行される。

### ClaudeHistorySize[] → Association
現在のノートブックのセッション履歴サイズを診断する。Entries・ByteCount・KiloBytes・Status を含む Association を返す。200KB 超でコンパクション推奨、500KB 超で危険。

### ClaudeSessionStatus[]
ClaudeSessionStatus[name]
デフォルトセッション、または指定名のセッションの状態を表示する。アクセス可能ディレクトリ、アタッチメント、作業ディレクトリのファイル等を確認できる。

## 添付ファイル

### ClaudeAttach[path]
ClaudeAttach[url]
ClaudeAttach[session, path]
デフォルトセッションに参照資料をアタッチする。URL の場合はページを PDF 化してキャッシュしアタッチする。アタッチされたファイルは ClaudeQuery/ClaudeEval 時に自動的に Read される。
Options: Keywords -> {} (登録するとプロンプト中のキーワードに応じて自動注入される), Title -> None, Refetch -> False

### ClaudeDetach[path]
ClaudeDetach[session, path]
デフォルトセッション、または指定セッションからファイルをデタッチする。

### ClaudeAttachments[] → List
ClaudeAttachments[session] → List
デフォルトセッション、または指定セッションのアタッチメント一覧を返す。

### ClearAttachments[]
ClearAttachments[session]
デフォルトセッション、または指定セッションの全アタッチメントをクリアする。

## 機密データ

### MarkConfidential[]
MarkConfidential[cell]
現在のセル、または指定セルを機密マークする。機密セルは ClaudeEval/ClaudeQuery のプロンプトから除外される。

### UnmarkConfidential[]
UnmarkConfidential[cell]
現在のセル、または指定セルの機密マークを解除する。

### IsConfidential[cell] → Boolean
IsConfidential[] → Boolean
セルが機密マークされているかを返す。

### Confidential[expr]
式を評価し、その Input/Output セルを自動的に機密マークする。
例: `Confidential[secretData = Import["secret.csv"]]`

### NonConfidential[expr]
式を評価し、その Input/Output セルの機密マークを明示的に解除する。秘密変数や秘密依存変数の値に依存していても、機密解除として扱う。
例: `result = NonConfidential[Mean[secretData]]`

### ScanConfidentialCells[] → Null
ノートブック全セルをスキャンし、機密変数を参照するセルを自動的に機密マークする。明示的に UnmarkConfidential されたセルはスキップされる。

## パッケージ管理

### ClaudeUpdatePackage[packageName, prompt]
$packageDirectory にある packageName.wl を Claude の支援でアップデートし、バックアップを作成する。prompt には文字列またはリスト `{文字列, Image, File[".../file.pdf"], ...}` を指定可能。
→ TaskObject
Options: TargetFunctions -> Automatic, StartTime -> Now, Fallback -> False, "UpdateApiMd" -> Automatic ("UpdateApiMd" -> False で api.md の自動更新をスキップ)
例: `ClaudeUpdatePackage["pkg", "修正指示", StartTime -> Now + Quantity[1, "Hours"]]`

### ClaudeRestorePackage[packageName] → Null
直前のバックアップを復元する。

### ClaudeCreatePackage[name, prompt] → Null
prompt に従って name.wl を新規作成し $packageDirectory に保存する。

### ClaudeConvertToPaclet[packageName] → Null
$packageDirectory の packageName.wl を Paclet 形式に変換する。packageName/ フォルダを作成し、Kernel/, Documentation/, PacletInfo.wl 等を生成する。元の .wl ファイルはバックアップ後に削除される。

### ClaudeUpdatePackageHistory[] → List
ClaudeUpdatePackageHistory[packageName] → List
全パッケージ、または指定パッケージの ClaudeUpdatePackage 呼び出し履歴を表示しリストで返す。各エントリは `<|"Package"->…, "Timestamp"->…, "Directory"->…|>` の Association。

### ClaudeBackupDataset[] → Grid
ClaudeBackupDataset[packageName] → Grid
全パッケージ、または指定パッケージのバックアップ履歴を Review/Pull/Delete ボタン付き Grid で表示する。Review はバックアップ内容を確認、Pull は復元、Delete はその履歴を削除する。

### ClaudeMigrateBackupHistory[packageName]
ClaudeMigrateBackupHistory[packageName, DryRun -> True]
ClaudeMigrateBackupHistory[]
既存の history 内の生 .wl バックアップを差分形式 (.wl.cz / .wl.cdiff) に変換して容量を削減する。DryRun -> True で削除せず容量削減の見積もりを表示する。引数なしで全パッケージに対して実行する。
Options: DryRun -> False

## ドキュメント生成

### ClaudeCreateDocumentation["packageName"] → Null
パッケージの詳細なドキュメント一式を Claude で自動生成する。$packageDirectory 内の packageName.wl または packageName/ Paclet を対象とする。単一 .wl: `$packageDirectory/packageName_info/docs/` に出力。Paclet: `$packageDirectory/packageName/docs/` に出力。

### ClaudeUpdateDocumentation["packageName"]
ClaudeUpdateDocumentation["packageName", "更新指示"]
ソース差分に基づき全ドキュメントを自動更新する。更新指示付きで指示に従ってドキュメントを更新する形式もある。ノートブックのコンテキストも参照可能（「上で議論されている内容を反映して」など）。
Options: TargetFiles -> Automatic (自動判定、または `{"api.md"}` 等でファイル指定), Mode -> "Update" (既存更新) または "Create" (新規作成), References -> {}, Demos -> {}, Disclaimer -> {}, License -> "", Acknowledgments -> {}
例: `ClaudeUpdateDocumentation["claudecode", "api.md のみ更新して"]`
例: `ClaudeUpdateDocumentation["pkg", "...", TargetFiles -> {"api.md"}]`

## ディレクティブ管理

### ClaudeAddDirective[target, description] → Null
Claude で description を整形し、Claude Directives フォルダのファイルに追加して `InstallClaudeDirectives[]` を実行する。target は "CLAUDE.md" またはスキル名（例: "wolfram-general"）。元ファイルは自動バックアップされる。

### ClaudeRestoreDirective[target] → Null
ClaudeAddDirective の直前のバックアップを復元し `InstallClaudeDirectives[]` を実行する。target は "CLAUDE.md" またはスキル名。

### ClaudeListDirectives[] → Null
Claude Directives フォルダの CLAUDE.md と全スキルの一覧を表示する。

### ClaudeUpdateDirective[]
ClaudeUpdateDirective[text]
ソースコードと Claude Directives の整合性をチェックし、不整合を自動修正する。text の内容を Claude で解釈し CLAUDE.md / rules / skills の適切なファイルに反映する形式もある。ノートブックのコンテキストも参照可能。

### ClaudeDirectiveBackupDataset[] → Grid
Claude Directives の更新履歴を Review/Pull/Delete ボタン付き Grid で表示する。履歴は ClaudeUpdateDirective[text] や ClaudeAddDirective の実行時に自動保存される。

### ClaudeSyncDirectives[dir] → Null
指定ディレクトリ dir のファイルを Claude Directives フォルダと比較し、dir 側が新しいファイルで Claude Directives を更新する。dir にだけ存在するファイルもコピーする。Claude Directives 側にしかないファイルはそのまま。
例: `ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]`

## Web 検索・取得

### ClaudeWebSearch[query] → String
Web 検索を実行し、結果をテキストで返す。Anthropic API の web_search ツールを使用する。

### ClaudeWebFetch[url] → String
ClaudeWebFetch[url, prompt] → String
指定 URL の内容を取得し、要約・抽出して返す。prompt を指定すると取得内容に対して prompt の指示を実行する。

## デバッグ・レビュー

### ClaudeDebug[codeOrFile, errorMsg] → Null
デバッグ支援を非同期で求める（即座に返る）。

### ClaudeReview[codeOrFile] → Null
コードのレビューを非同期で行う（30000 文字超は自動チャンク分割）。

### ClaudeReviewChunked[codeOrFile] → Null
ファイルをチャンク分割して非同期レビューする。

## 分離検証

### ClaudeCheckSeparation[target] → List
target のコードが NBAccess の分離原則に違反している箇所をリストアップする。target はファイルパス | $packageDirectory の .wl 名 | パクレット名。$ClaudeTestModel のモデルで検査する。
検査対象 (静的走査 + LLM 判定):
a. SystemCredential 直接利用
b. CellObject 直接操作 (NotebookWrite/NotebookRead/CellGroupData 直接構築)
c. CellEpilog/CellProlog/NotebookEventActions 直接操作
d. NBAccess`Private` 関数呼び出し
e. NBAccess 公開グローバル直接更新
f. EvaluationCell[]/CellPrint[]/SetSelectedNotebook[] 直接使用
g. CurrentValue/SetOptions による TaggingRules/CellTags/CellEpilog 属性直接アクセス
h. CellObject の公開 API・戻り値・状態保持への漏洩
i. SelectionEvaluate/FrontEndTokenExecute 等 FE 状態操作
j. NBAccess 公開グローバルの破壊的更新 (AppendTo/AssociateTo 等)
例: `ClaudeCheckSeparation["claudecode"]`

### ClaudeFixSeparation[target] → Null
分離違反を修正する。target がファイルパスの場合: バックアップを作成し元ファイルを修正。target がパッケージ名のみの場合: ClaudeUpdatePackage を呼び出す。事前に ClaudeCheckSeparation の結果があればそれを利用する。

## LLMGraph

### NotebookLLMGraph[nb] → graph
ノートブック nb の LLMGraph を返す。存在しない場合は新規作成する。

### NotebookLLMGraphPlot[nb] → Graphics
ノートブックの LLMGraph をトップレベルで可視化する。Orchestrator ノードのみを表示し、アクセスレベル別に色分けする。

### NotebookLLMGraphBuild[nb] → graph
既存のセッション履歴から LLMGraph を再構築する。現在のセッション履歴エントリをノードに変換しグラフを生成する。

### NotebookLLMGraphNodes[nb] → Association
ノートブックの LLMGraph 全ノードを Association で返す。

### NotebookLLMGraphValidate[nb] → result
ノートブックの LLMGraph の整合性を検証する。セッション履歴のエントリ数とノード数の一致、エッジの整合性等を確認する。

### NotebookLLMGraphFetchResponse[nb, nodeID] → String
指定ノードの response 全文を外部キャッシュから取得する。

### NotebookLLMGraphSubSteps[nb, nodeID] → List
指定ノードのサブステップ（L2 ノード）一覧を返す。

### NotebookLLMGraphFetchL2[nb, nodeID] → Association
指定ノードの L2 詳細情報を取得する。

### NotebookLLMGraphErrors[nb] → List
LLMGraph 内のエラーノード一覧を返す。

### NotebookLLMGraphUpdateL2Status[nb, nodeID, status] → Null
指定ノードの L2 ステータスを更新する。

### NotebookLLMGraphPlotL2[nb, nodeID] → Graphics
指定ノードの L2 グラフを可視化する。

### NotebookLLMGraphRerun[nb, nodeID] → Null
指定ノードを再実行する。

### NotebookLLMGraphInvalidateDownstream[nb, nodeID] → Null
指定ノードの下流ノードを無効化する。

### NotebookLLMGraphSummary[nb] → String
LLMGraph のサマリーを生成する。

### NotebookLLMGraphExtractThread[nb, nodeID] → List
指定ノードのスレッドを抽出する。

### NotebookLLMGraphApplyThread[nb, thread] → Null
抽出したスレッドをノートブックに適用する。

### LLMGraphExecute[graph] → TaskObject
LLMGraphExecuteStatus[task] → Association
LLMGraphExecuteCancel[task] → Null
LLMGraph を実行・ステータス取得・キャンセルする。

### LLMGraphDAGCreate[nodes, edges] → dag
LLMGraphDAGStatus[dag] → Association
LLMGraphDAGCancel[dag] → Null
DAG ベースの LLM 呼び出しグラフを作成・ステータス取得・キャンセルする。

## ファイル処理

### NBFileTranslate[...] → result
ノートブックファイルの翻訳・変換処理を行う。

### ClaudeProcessFile[...] → result
ファイルを Claude で処理する。

## UI・ユーティリティ

### ShowClaudePalette[] → Null
Claude Code 操作用のパレットを表示する。

### ClaudeQueryShowContext[] → Null
デバッグ用: 次の ClaudeQuery が送信するノートブックコンテキストを表示する。

### ClaudeShowAccessConfig[] → Null
デバッグ用: Claude Code のファイルアクセス設定を表示する。$ClaudeAccessibleDirs、NBGetAccessibleDirs[]、生成される settings.json、CLI フラグを確認できる。

### ClaudeStatus[] → Grid
現在実行中の全 Claude タスクのリアルタイム状態を表示する。各タスクの経過時間、現在の状態（思考中/テキスト生成中/ツール実行中）、生成済みテキスト断片数、思考断片数、ツール使用数を表示する。実行中のタスクがない場合はその旨を表示する。

### ClaudeAbort[] → Null
実行中の全 Claude タスクを停止する。Claude Code プロセスの強制終了、ScheduledTask の停止、フォールバックタスクのキャンセルを行う。パレットの「実行停止」ボタンからも呼び出し可能。

### ClaudeCommand["/command"] → String
ClaudeCommand["config list"] → String
Claude Code CLI のスラッシュコマンドを実行し結果を返す。スラッシュコマンド (/始まり) は node-pty 経由で対話モードに送信される。CLI サブコマンド (例: `config list`) は直接実行される。
例: `ClaudeCommand["/help"]`, `ClaudeCommand["/permissions"]`, `ClaudeCommand["config list"]`, `ClaudeCommand["--version"]`

### ClaudePrepareCommit[packageName]
ClaudePrepareCommit[packageName, subject]
前回の GitHub コミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを生成して GitHubRefreshAndCommit 実行コマンドを Input セルとして出力する。subject を指定すると 1 行目を固定し、本文は自動収集する。
Options: Fallback -> False, DryRun -> False (True でコマンドを生成せずメッセージのみ返す), Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, BaseBranch -> Automatic

## オプションシンボル

### Fallback
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: Claude Code 利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。False (デフォルト): エラーをそのまま返す。

### AutoPrivate
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: 機密変数にアクセスするタスクの場合、生成コードに `Model -> $ClaudePrivateModel, PrivacySpec -> Automatic` を付与する。False (デフォルト): 通常動作。

### AutoEvaluate
ClaudeEval/ClaudeWriteResponse のオプション。True (ClaudeEval デフォルト): 生成された Input セルを自動実行する。False: 自動実行しない。

### StartTime
ClaudeEval/ContinueEval/ClaudeUpdatePackage のオプション。実行開始時刻を DateObject で指定する。例: `StartTime -> Now + Quantity[3, "Hours"]`

### RepeatInterval
ClaudeEval のオプション。繰り返し実行間隔。`Quantity[2,"Hours"]` で 2 時間ごと。`{Quantity[1,"Hours"], 5}` で 1 時間ごとに最大 5 回。TaskObject が返るので `TaskRemove[]` で停止可能。

### Timeout
ClaudeEval/ContinueEval/ClaudeQuerySync/ClaudeQueryBg/ClaudeQueryAsync のオプション。API フォールバックのタイムアウト秒数。Automatic は $iFallbackTimeout (600 秒)。

### TargetFunctions
ClaudeUpdatePackage のオプション。Automatic: 自動判定。関数名リストで対象関数を限定。

### TargetFiles
ClaudeUpdateDocumentation のオプション。Automatic: 自動判定。`{"api.md"}` 等でファイルを指定。

### Mode
ClaudeUpdateDocumentation のオプション。"Update" (既存更新、デフォルト) または "Create" (新規作成)。

### DryRun
ClaudeMigrateBackupHistory/ClaudePrepareCommit のオプション。True: 実際の変更を行わず結果の見積もりのみを表示・返す。False (デフォルト): 実際に実行する。

### Inherit
CreateClaudeSession のオプション。True (デフォルト): デフォルト履歴を継承。False: 独立したセッションを作成。

### WebSearch
ClaudeQuery/ClaudeEval のオプション。True (デフォルト): Claude Code CLI の組み込み Web 検索ツールを許可する。False: Claude Code CLI の Web 検索を禁止する。API 経由の課金は発生しない。WebFetch (課金あり) とは異なる。

### WebFetch
ClaudeQuery/ClaudeEval のオプション。True: 必ず Web 検索を行う。False: Web 検索を行わない。Automatic (ClaudeEval のデフォルト): Claude がタスクを分析し、必要なら自動で Web 検索する。ClaudeQuery のデフォルトは False。重要: WebFetch は Anthropic API 経由で課金が発生するため、Fallback -> True の場合のみ有効。

### PrivacySpec
ClaudeQuerySync のオプション。Automatic: 自動判定。機密データのプライバシー仕様を指定する。

### Keywords
ClaudeAttach のオプション。登録するとプロンプト中のキーワードに応じてアタッチメントが自動注入される。例: `Keywords -> {"API", "認証"}`

### Title
ClaudeAttach のオプション。アタッチメントのタイトルを指定する。None (デフォルト): 自動判定。

### Refetch
ClaudeAttach のオプション。True: URL アタッチメントを強制的に再取得する。False (デフォルト): キャッシュを使用する。

### References
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。URL や書籍名のリストを指定すると README.md に参考文献セクションを追加する。例: `References -> {"https://...", "書籍名"}`

### Demos
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。デモ動画や使用例の URL リストを指定すると README.md に反映する。例: `Demos -> {"https://youtu.be/...", "https://example.com/demo.nb"}`

### License
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。空文字列 (デフォルト): GitHubREST`$GitHubLicenseHolder が非空なら MIT ライセンスを自動挿入。文字列指定: そのままライセンステキストとして挿入。例: `License -> "MIT"`, `License -> "Apache-2.0 License..."`

### Owner
ClaudePrepareCommit のオプション。GitHub リポジトリオーナー名。Automatic: 自動判定。

### Repository
ClaudePrepareCommit のオプション。GitHub リポジトリ名。Automatic: 自動判定。

### Branch
ClaudePrepareCommit のオプション。対象ブランチ名。Automatic: 自動判定。

### BaseBranch
ClaudePrepareCommit のオプション。ベースブランチ名。Automatic: 自動判定。