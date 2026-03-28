# claudecode パッケージ API リファレンス

パッケージ: `ClaudeCode``
ロード: `Needs["ClaudeCode`", "claudecode.wl"]`
依存: NBAccess, GitHubREST (github.wl)

## クエリ関数

### ClaudeQuery[prompt] → String
Claude Code CLI に同期クエリを送り応答文字列を返す。セッション履歴とノートブックコンテキストを考慮する。
`ClaudeQuery[session, prompt]` でセッション指定。
`ClaudeQuery[{text, Image[...], File[path], ...}]` でマルチモーダル入力。
Options: WebSearch -> True (Claude Code CLI の Web 検索許可), WebFetch -> False (API 経由有料), Fallback -> False, Timeout -> Automatic
例: `ClaudeQuery["Wolfram言語でフィボナッチ数列を実装して", WebSearch -> False]`

### ClaudeQuerySync[prompt] → String
セッション履歴・ノートブック書き込みなしの軽量同期クエリ。WindowStatusArea に経過時間を表示。
モデルルーティング: Model -> Automatic かつ PrivacyLevel <= 0.5 → Claude Code CLI、PrivacyLevel > 0.5 → $ClaudePrivateModel を自動使用。
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic
例: `ClaudeQuerySync[prompt, Model -> {"anthropic", "claude-sonnet-4-6"}]`

### ClaudeQueryAsync[prompt, callback, nb]
非同期クエリ。完了時に `callback[応答文字列]` を呼ぶ。カーネルをブロックしない。
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic

### ClaudeWriteResponse[nb, text]
マークダウン形式テキストをノートブックセルとして展開する。見出し・リスト・コードブロックを適切なセルスタイルに変換。
Options: AutoEvaluate -> False

### ClaudeMath[task] → String
Mathematica コード生成に特化したプロンプトで Claude を呼び出す。

### ClaudeExtractCode[response] → String
Claude 応答から最初の ` ```mathematica ` ブロックを抽出する。

### ClaudeExtractAllCode[response] → List
Claude 応答から全 ` ```mathematica ` ブロックをリストで返す。

## コード生成・評価

### ClaudeEval[task]
コードを非同期で生成・表示し、デフォルトセッションに履歴を保存する。
`ClaudeEval[{text, data, ...}]` でテキスト・Dataset・Image・一般式を混在可。
`ClaudeEval[session, task]` で指定セッションに履歴保存。
Options: AutoEvaluate -> True (生成 Input セルの自動実行), StartTime -> Now (DateObject で実行開始時刻指定), RepeatInterval -> None (繰り返し実行), Timeout -> Automatic, Fallback -> False, AutoPrivate -> False
例: `ClaudeEval["散布図を描いて", RepeatInterval -> Quantity[2, "Hours"]]`
例: `ClaudeEval["毎朝9時に実行", StartTime -> DateObject[{2026,4,1,9,0,0}]]`
TaskObject が返るので `TaskRemove[]` で停止可能。

### ContinueEval[session, instruction]
指定セッションで継続。`ContinueEval[instruction]` はデフォルトセッション。`ContinueEval[]` は「エラーを修正してください」でデフォルトセッション継続。
Options: StartTime -> Now, Timeout -> Automatic, Fallback -> False, AutoPrivate -> False

### ContinueUpdate[packageName, instruction]
直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を継続する。
`ContinueUpdate["instruction"]` で追加指示付き継続。`ContinueUpdate[]` でデフォルト継続。
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now

### ClaudeSpec[task] → (ノートブックに出力)
ノートブック内容からプログラムの仕様を生成する。`ClaudeSpec[{task, image, ...}]` で画像付き。パレットからセル選択で呼び出し可能。

### ClaudeDebug[codeOrFile, errorMsg]
デバッグ支援を非同期で求める（即座に返る）。

### ClaudeReview[codeOrFile]
コードレビューを非同期で行う。30000文字超は自動チャンク分割。

### ClaudeReviewChunked[codeOrFile]
ファイルをチャンク分割して非同期レビューする。

## セッション管理

### CreateClaudeSession["name"] → session
名前付きセッションを作成（デフォルト履歴を継承）。
`CreateClaudeSession[session]` で既存セッション履歴を継承した新セッション作成。
`CreateClaudeSession[]` でデフォルト履歴を継承した新セッション作成。
`CreateClaudeSession[Inherit -> False]` で独立セッション作成。

### ClaudeRestoreSession[] / ClaudeRestoreSession["name"]
デフォルトまたは指定名のセッションをリストアする。

### ClaudeListSessions[] → (表示)
ノートブック内の全セッションを一覧表示する。

### ClaudeDeleteSession["name"]
指定名のセッションを削除する。`ClaudeDeleteSession["name", "All"]` でセッションと全履歴を削除。

### ClaudeShowHistory[] / ClaudeShowHistory[session] / ClaudeShowHistory["name"]
セッションの履歴を表示する。

### ClaudeCompactHistory[] / ClaudeCompactHistory[name]
セッション履歴を手動でコンパクションする。通常は 2n+1+w エントリを超えたとき自動実行される。

### ClaudeHistorySize[] → Association
現在のノートブックのセッション履歴サイズを診断する。Entries・ByteCount・KiloBytes・Status を含む Association を返す。200KB超でコンパクション推奨、500KB超で危険。

### ClaudeSessionStatus[] / ClaudeSessionStatus[name] → (表示)
セッションの状態（アクセス可能ディレクトリ・アタッチメント・作業ディレクトリ等）を表示する。

## アタッチメント

### ClaudeAttach[path] / ClaudeAttach[session, path]
デフォルトまたは指定セッションに参照資料をアタッチする。アタッチされたファイルは ClaudeQuery/ClaudeEval 時に自動 Read される。

### ClaudeDetach[path] / ClaudeDetach[session, path]
セッションからファイルをデタッチする。

### ClaudeAttachments[] / ClaudeAttachments[session] → List
セッションのアタッチメント一覧を返す。

### ClearAttachments[] / ClearAttachments[session]
セッションの全アタッチメントをクリアする。

## パッケージ操作

### ClaudeCreatePackage[name, prompt]
prompt に従って `name.wl` を新規作成し `$packageDirectory` に保存する。

### ClaudeUpdatePackage[packageName, prompt]
`$packageDirectory` の `packageName.wl` を Claude の支援でアップデートし、バックアップを作成する。
prompt には文字列または `{文字列, Image, File[".../file.pdf"], ...}` を指定可能。
Options: TargetFunctions -> Automatic (更新対象関数を限定), StartTime -> Now, Fallback -> False, "UpdateApiMd" -> Automatic (api.md の自動更新)
例: `ClaudeUpdatePackage["pkg", "修正指示", StartTime -> Now + Quantity[1, "Hours"]]`
例: `ClaudeUpdatePackage["pkg", "修正指示", "UpdateApiMd" -> False]`

### ClaudeRestorePackage[packageName]
直前のバックアップを復元する。

### ClaudeUpdatePackageHistory[] / ClaudeUpdatePackageHistory[packageName] → List
全パッケージまたは指定パッケージの ClaudeUpdatePackage 呼び出し履歴を表示しリストで返す。各エントリは `<|"Package"->..., "Timestamp"->..., "Directory"->...|>` の Association。

### ClaudeBackupDataset[packageName] / ClaudeBackupDataset[]
指定パッケージまたは全パッケージのバックアップ履歴を Review/Pull/Delete ボタン付き Grid で表示する。Review でバックアップ内容確認、Pull で復元、Delete でその履歴を削除。

### ClaudeMigrateBackupHistory[packageName]
既存の history 内の生 .wl バックアップを差分形式 (.wl.cz / .wl.cdiff) に変換して容量削減する。
`ClaudeMigrateBackupHistory[packageName, DryRun -> True]` で容量削減の見積もりのみ表示。
`ClaudeMigrateBackupHistory[]` で全パッケージに実行。

### ClaudeConvertToPaclet[packageName]
`$packageDirectory` の `packageName.wl` を Paclet 形式に変換する。`packageName/` フォルダを作成し、Kernel/, Documentation/, PacletInfo.wl 等を生成する。元の .wl ファイルはバックアップ後削除される。

## ドキュメント生成

### ClaudeCreateDocumentation["packageName"]
パッケージの詳細なドキュメント一式を Claude で自動生成する。
単一 .wl: `$packageDirectory/packageName_info/docs/` に出力。
Paclet: `$packageDirectory/packageName/docs/` に出力。
Options: References -> {} (参考文献 URL/書籍名リスト), Demos -> {} (デモ動画/URL リスト), Disclaimer -> {} (免責事項文言リスト), License -> "" (ライセンステキスト), Acknowledgments -> {} (謝辞文言リスト)

### ClaudeUpdateDocumentation["packageName"] / ClaudeUpdateDocumentation["packageName", "更新指示"]
ソース差分に基づき全ドキュメントを自動更新する。更新指示付きで指示に従って更新。
Options: TargetFiles -> Automatic (自動判定) または `{"api.md"}` 等でファイル指定, Mode -> "Update" (既存更新) または "Create" (新規作成)
例: `ClaudeUpdateDocumentation["claudecode", "api.mdのみ更新して", TargetFiles -> {"api.md"}]`

## ディレクティブ管理

### ClaudeAddDirective[target, description]
Claude で description を整形し、Claude Directives フォルダのファイルに追加して `InstallClaudeDirectives[]` を実行する。target は `"CLAUDE.md"` またはスキル名（例: `"wolfram-general"`）。元ファイルは自動バックアップ。

### ClaudeRestoreDirective[target]
ClaudeAddDirective の直前のバックアップを復元し `InstallClaudeDirectives[]` を実行する。

### ClaudeListDirectives[]
Claude Directives フォルダの CLAUDE.md と全スキルの一覧を表示する。

### ClaudeUpdateDirective[] / ClaudeUpdateDirective[text]
引数なし: ソースコードと Claude Directives の整合性をチェックし不整合を自動修正。
text 指定: text の内容を Claude で解釈し CLAUDE.md / rules / skills の適切なファイルに反映する。ノートブックのコンテキストも参照可能。

### ClaudeDirectiveBackupDataset[]
Claude Directives の更新履歴を Review/Pull/Delete ボタン付き Grid で表示する。

### ClaudeSyncDirectives[dir]
指定ディレクトリ dir のファイルを Claude Directives フォルダと比較し、dir 側が新しいファイルで Claude Directives を更新する。dir にだけ存在するファイルもコピーする。
例: `ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]`

## 機密管理

### MarkConfidential[] / MarkConfidential[cell]
現在または指定セルを機密マークする。機密セルは ClaudeEval/ClaudeQuery のプロンプトから除外される。

### UnmarkConfidential[] / UnmarkConfidential[cell]
現在または指定セルの機密マークを解除する。

### IsConfidential[] / IsConfidential[cell] → True|False
セルが機密マークされているかを返す。

### Confidential[expr]
式を評価し、その Input/Output セルを自動的に機密マークする。
例: `Confidential[secretData = Import["secret.csv"]]`

### NonConfidential[expr]
式を評価し、その Input/Output セルの機密マークを明示的に解除する。秘密変数依存の値でも機密解除として扱う。
例: `result = NonConfidential[Mean[secretData]]`

### ScanConfidentialCells[]
ノートブック全セルをスキャンし、機密変数を参照するセルを自動的に機密マークする。明示的に UnmarkConfidential されたセルはスキップされる。

## Web ツール

### ClaudeWebSearch[query] → String
Web 検索を実行し結果をテキストで返す。Anthropic API の web_search ツールを使用する。

### ClaudeWebFetch[url] → String
指定 URL の内容を取得し要約・抽出して返す。`ClaudeWebFetch[url, prompt]` で取得内容に対して prompt の指示を実行する。

## 分離検証

### ClaudeCheckSeparation[target]
target のコードが NBAccess の分離原則に違反している箇所をリストアップする。
target: ファイルパス | `$packageDirectory` の .wl 名 | パクレット名。
$ClaudeTestModel のモデルで検査する。
検査対象: SystemCredential 直接利用, CellObject 直接操作, CellEpilog/CellProlog/NotebookEventActions 直接操作, NBAccess`Private` 関数呼び出し, NBAccess 公開グローバル直接更新, EvaluationCell[]/CellPrint[]/SetSelectedNotebook[] 直接使用, TaggingRules/CellTags/CellEpilog 属性直接アクセス, CellObject の公開 API・戻り値・状態保持への漏洩, SelectionEvaluate/FrontEndTokenExecute 等 FE 状態操作, NBAccess 公開グローバルの破壊的更新。
例: `ClaudeCheckSeparation["claudecode"]`

### ClaudeFixSeparation[target]
分離違反を修正する。ファイルパス指定時はバックアップ作成後元ファイルを修正。パッケージ名のみ指定時は ClaudeUpdatePackage を呼び出す。事前に ClaudeCheckSeparation の結果があればそれを利用する。

## ステータス・制御

### ClaudeStatus[]
実行中の全 Claude タスクのリアルタイム状態を表示する。各タスクの経過時間・現在の状態（思考中/テキスト生成中/ツール実行中）・生成済みテキスト断片数・思考断片数・ツール使用数を表示。実行中タスクがない場合はその旨を表示。

### ClaudeAbort[]
実行中の全 Claude タスクを停止する。Claude Code プロセスの強制終了、ScheduledTask の停止、フォールバックタスクのキャンセルを行う。パレットの「実行停止」ボタンからも呼び出し可能。

### ClaudeCommand["/command"] → String
Claude Code CLI のスラッシュコマンドを実行し結果を返す。スラッシュコマンド (/始まり) は node-pty 経由で対話モードに送信される。CLI サブコマンド（例: `config list`）は直接実行される。
例: `ClaudeCommand["/help"]`, `ClaudeCommand["/permissions"]`, `ClaudeCommand["config list"]`, `ClaudeCommand["--version"]`

### ShowClaudePalette[]
Claude Code 操作用のパレットを表示する。

### ClaudeQueryShowContext[]
デバッグ用: 次の ClaudeQuery が送信するノートブックコンテキストを表示する。

### ClaudeShowAccessConfig[]
デバッグ用: Claude Code のファイルアクセス設定を表示する。$ClaudeAccessibleDirs, NBGetAccessibleDirs[], 生成される settings.json, CLI フラグを確認可能。

### ClaudePrepareCommit[packageName]
前回の GitHub コミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを生成して GitHubRefreshAndCommit 実行コマンドを Input セルとして出力する。
`ClaudePrepareCommit[packageName, subject]` で1行目を指定し、本文は自動収集。
Options: Fallback -> False, DryRun -> False, Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, BaseBranch -> Automatic
`DryRun -> True` でコマンドを生成せずメッセージのみ返す。

## NotebookLLMGraph

### NotebookLLMGraph[nb] → graph
ノートブック nb の LLMGraph を返す。存在しない場合は新規作成する。

### NotebookLLMGraphPlot[nb]
ノートブックの LLMGraph をトップレベルで可視化する。Orchestrator ノードのみを表示し、アクセスレベル別に色分けする。

### NotebookLLMGraphBuild[nb]
既存のセッション履歴から LLMGraph を再構築する。現在のセッション履歴エントリをノードに変換しグラフを生成する。

### NotebookLLMGraphNodes[nb] → Association
ノートブックの LLMGraph 全ノードを Association で返す。

### NotebookLLMGraphValidate[nb]
ノートブックの LLMGraph の整合性を検証する。セッション履歴のエントリ数とノード数の一致、エッジの整合性等を確認する。

### NotebookLLMGraphFetchResponse[nb, nodeID] → String | Missing
指定ノードの response 全文を外部キャッシュから取得する。キャッシュにない場合は `Missing["CacheExpired"]` を返す。
例: `NotebookLLMGraphFetchResponse[EvaluationNotebook[], "history-3"]`

### NotebookLLMGraphSubSteps[nb, nodeID]
指定ノードの内部サブステップ履歴を表示する。ClaudeUpdatePackage の内部処理 (read-source, llm-query, merge, validate, reload) が記録される。

### NotebookLLMGraphFetchL2[nb, nodeID] → graph | Missing
指定の L1 ノードが生成したコードブロックの L2 グラフを取得する。L2 グラフは各コードブロックの実行状態・エラー・依存関係を保持する。キャッシュにない場合は `Missing["CacheExpired"]` を返す。

### NotebookLLMGraphErrors[nb] → Dataset
L2ErrorCount > 0 または Status = "Failed" のノード一覧を Dataset で返す。L2 グラフでエラーが起きた L1 ノードの特定とデバッグに使用する。

### NotebookLLMGraphUpdateL2Status[nb, l1NodeID, l2NodeID, status, msg]
L2 ノードのステータスを手動で更新する。status: `"Completed"` | `"Failed"` | `"Pending"`
例: `NotebookLLMGraphUpdateL2Status[nb, "history-5", "history-5_L2-2", "Failed", "Undefined symbol"]`

### NotebookLLMGraphPlotL2[nb, l1NodeID]
指定の L1 ノードが生成したコードブロックの L2 計算グラフを可視化する。

### NotebookLLMGraphRerun[nb, nodeID]
指定ノードの LLM クエリを再実行する。

### NotebookLLMGraphInvalidateDownstream[nb, nodeID]
指定ノードの下流ノードを無効化する。

### NotebookLLMGraphSummary[nb]
LLMGraph の概要サマリーを表示する。

### LLMGraphExecute[nb]
LLMGraph の実行を開始する。

### LLMGraphExecuteStatus[nb]
LLMGraph の実行状態を返す。

### LLMGraphExecuteCancel[nb]
LLMGraph の実行をキャンセルする。

### NotebookLLMGraphExtractThread[nb, nodeID]
指定ノードのスレッドを抽出する。

### NotebookLLMGraphApplyThread[nb, thread]
スレッドをノートブックに適用する。

## ファイル処理

### NBFileTranslate[...]
ファイル翻訳処理を行う。

### ClaudeProcessFile[...]
ファイルを処理する。

## グローバル変数

### $ClaudeModel
型: String, 初期値: ""
Claude CLI に渡すモデル名。`""` は省略時 Claude Code 自身のデフォルトモデルを使用。
例: `$ClaudeModel = "claude-opus-4-6"`

### $ClaudePrivateModel
型: List, 初期値: なし
秘密データ処理用のローカルモデル指定。AutoPrivate -> True 時に秘密変数を含むタスクの生成コードに使用される。
形式: `{"provider", "modelName"}` または `{"provider", "modelName", "url"}`
例: `$ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}`

### $ClaudePackageKeywordMap
型: Association, 初期値: `<||>`
外部パッケージがキーワードを登録するための Association。プロンプトにキーワードが含まれると、対応パッケージの api.md がコンテキストに自動注入される。各パッケージが自身のロード時に登録する。
例: `$ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒切"}`

### $ClaudeTimeout
型: Number, 初期値: 1200
ClaudeQuery・ClaudeEval 等のタイムアウト秒数。

### $ClaudeVerbose
型: True|False, 初期値: False
True: 履歴コンパクション等の詳細ログを Messages に出力。False: 重大エラー以外の ClaudeCode ログを抑制。

### $ClaudeWorkingDirectory
型: String, 初期値: `FileNameJoin[{$HomeDirectory, "Claude Working"}]`
Claude Code を起動する作業ディレクトリ。このディレクトリ配下の `.claude/CLAUDE.md`, `.claude/rules/`, `.claude/skills/` を Claude Code に読ませる。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索されるか手動で上書き可能。
例: `$ClaudeMDPath = "C:\\proj\\CLAUDE.md"`

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。内容が空の場合、CLAUDE.md が見つからなかったか内容がない。

### $ClaudeAccessibleDirs
型: List, 初期値: `{$packageDirectory}`
Claude Code に Read 許可する追加ディレクトリリスト。NotebookDirectory は初回使用時にダイアログで許可確認（$packageDirectory 配下を除く）。ノートブックの TaggingRules に NBSetAccessibleDirs で永続化可能。
例: `$ClaudeAccessibleDirs = {$packageDirectory, "F:\\Dropbox\\Mathematica-oneDrive"}`

### $ClaudeFallbackModels
型: List, 初期値: `{{"anthropic", <OpusModel>}, {"openai", "gpt-5"}}`
フォールバックモデル優先順位。各要素は `{"provider", "modelName"}` または `{"provider", "modelName", "url"}` の形式。内部的に NBAccess`NBSetFallbackModels に同期される。
例: `$ClaudeFallbackModels = {{"anthropic","claude-opus-4-6"},{"lmstudio","gpt-oss-20b","http://127.0.0.1:1234"}}`

### $ClaudeDocRetryDelay
型: Number, 初期値: 60
ドキュメント生成のリトライ待機秒数。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
ドキュメント生成の最大リトライ回数。

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースの最大文字数。

### $ClaudeDocModel
型: String, 初期値: 最新 Sonnet モデル
ドキュメント生成・更新時に使用するモデル。`""` で $ClaudeModel と同じモデルを使用。
例: `$ClaudeDocModel = "claude-sonnet-4-6"`

### $ClaudeTestModel
型: String, 初期値: $ClaudeModel と同じ
分離検証などのテスト用モデル名。別モデルで客観的に検証するために変更可能。
例: `$ClaudeTestModel = "claude-sonnet-4-6"`

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval が再帰的に ClaudeEval を生成する際の最大深度。0 で再帰禁止。値を大きくすると多段階の自動タスク連鎖が可能。

## オプションシンボル

### Fallback -> False
ClaudeQuery/ClaudeEval/ContinueEval/ClaudeUpdatePackage のオプション。True: Claude Code 利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。

### AutoPrivate -> False
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: 秘密変数にアクセスするタスクの場合、生成コードに `Model -> $ClaudePrivateModel`, `PrivacySpec -> Automatic` を付与する。

### AutoEvaluate -> True
ClaudeEval/ClaudeWriteResponse のオプション。True: 生成された Input セルを自動実行する。

### StartTime -> Now
ClaudeEval/ContinueEval/ClaudeUpdatePackage/ContinueUpdate のオプション。DateObject で実行開始時刻を指定する。
例: `StartTime -> Now + Quantity[3, "Hours"]`

### RepeatInterval -> None
ClaudeEval のオプション。繰り返し実行の間隔。`Quantity[2, "Hours"]` で2時間ごとに実行。`{Quantity[1,"Hours"], 5}` で1時間ごとに最大5回実行。TaskObject が返るので `TaskRemove[]` で停止可能。

### Timeout -> Automatic
ClaudeQuery/ClaudeEval/ContinueEval のオプション。API フォールバックのタイムアウト秒数。Automatic は $iFallbackTimeout (600秒)。

### TargetFunctions -> Automatic
ClaudeUpdatePackage のオプション。更新対象関数を限定する。Automatic で全関数を対象とする。

### TargetFiles -> Automatic
ClaudeUpdateDocumentation のオプション。更新対象ファイルを限定する。Automatic で自動判定、`{"api.md"}` 等でファイル指定。

### Mode -> "Update"
ClaudeUpdateDocumentation のオプション。`"Update"` (既存更新) または `"Create"` (新規作成)。

### DryRun -> False
ClaudeMigrateBackupHistory/ClaudePrepareCommit のオプション。True でコマンド生成・削除せず見積もりのみ表示。

### Inherit -> True
CreateClaudeSession のオプション。False で独立したセッションを作成する。

### WebFetch -> False
ClaudeQuery/ClaudeEval のオプション。True: 必ず Web フェッチを行う。Automatic (ClaudeEval デフォルト): Claude がタスクを分析し必要なら自動で Web 検索する。重要: WebFetch は Anthropic API 経由で課金が発生するため、Fallback -> True の場合のみ有効。

### WebSearch -> True
ClaudeQuery/ClaudeEval のオプション。True (デフォルト): Claude Code CLI の組み込み Web 検索ツールを許可する。False: Claude Code CLI の Web 検索を禁止する。API 経由の課金は発生しない。WebFetch (課金あり) とは異なる。

### References -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。URL や書籍名のリストを指定すると README.md に参考文献セクションを追加する。
例: `References -> {"https://...", "書籍名"}`

### Demos -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。デモ動画や使用例の URL リストを指定すると README.md に反映する。
例: `Demos -> {"https://youtu.be/...", "https://example.com/demo.nb"}`

### Disclaimer -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。免責事項セクションに追加する文言のリストを指定する。

### License -> ""
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。空文字列 (デフォルト): GitHubREST`$GitHubLicenseHolder が非空なら MIT ライセンスを自動挿入。文字列指定: そのままライセンステキストとして挿入。

### Acknowledgments -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。謝辞セクションに追加する文言のリストを指定する。指定時は README.md の免責事項の前に配置される。

### Owner -> Automatic
ClaudePrepareCommit のオプション。GitHub リポジトリのオーナー名を指定する。

### Repository -> Automatic
ClaudePrepareCommit のオプション。GitHub リポジトリ名を指定する。

### Branch -> Automatic
ClaudePrepareCommit のオプション。コミット先ブランチ名を指定する。

### BaseBranch -> Automatic
ClaudePrepareCommit のオプション。ベースブランチ名を指定する。

### PrivacySpec -> Automatic
ClaudeQuerySync のオプション。プライバシー仕様を指定する。

### Model -> Automatic
ClaudeQuerySync/ClaudeQueryAsync のオプション。使用モデルを指定する。`{"provider", "modelName"}` 形式で API 経由モデルを直接指定可能。