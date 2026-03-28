# claudecode API リファレンス

ClaudeCode パッケージは Mathematica ノートブックから Claude Code CLI および Anthropic API を呼び出すためのインターフェースを提供する。

## グローバル変数

### $ClaudeModel
型: String, 初期値: ""
Claude CLI に渡すモデル名。"" の場合 Claude Code 自身のデフォルトモデルを使用。
例: `$ClaudeModel = "claude-opus-4-6"`

### $ClaudePrivateModel
型: List, 初期値: なし
秘密データ処理用のローカルモデル指定。`AutoPrivate -> True` 時に秘密変数を含むタスクの生成コードに使用。
形式: `{"provider", "modelName"}` または `{"provider", "modelName", "url"}`
例: `$ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}`

### $ClaudePackageKeywordMap
型: Association, 初期値: `<||>`
外部パッケージがキーワードを登録するための Association。プロンプトにキーワードが含まれると対応パッケージの api.md がコンテキストに自動注入される。各パッケージが自身のロード時に登録する。
例: `$ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〆切"}`

### $ClaudeTimeout
型: Integer, 初期値: 1200
ClaudeQuery・ClaudeEval 等のタイムアウト秒数。

### $ClaudeVerbose
型: Boolean, 初期値: False
True で履歴コンパクション等の詳細ログを Messages に出力する。

### $ClaudeWorkingDirectory
型: String, 初期値: `FileNameJoin[{$HomeDirectory, "Claude Working"}]`
Claude Code を起動する作業ディレクトリ。このディレクトリ配下の `.claude/CLAUDE.md`、`.claude/rules/`、`.claude/skills/` を Claude Code に読ませる。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索されるか、手動で上書き可能。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。空の場合 CLAUDE.md が見つからなかったか内容がない。

### $ClaudeAccessibleDirs
型: List, 初期値: `{$packageDirectory}`
Claude Code に Read 許可する追加ディレクトリリスト。NotebookDirectory は初回使用時にダイアログで許可を確認する（$packageDirectory 配下を除く）。ノートブックの TaggingRules に `NBSetAccessibleDirs` で永続化可能。

### $ClaudeFallbackModels
型: List, 初期値: `{{"anthropic", <opusModel>}, {"openai", "gpt-5"}}`
フォールバックモデル優先順位。各要素は `{"provider", "modelName"}` または `{"provider", "modelName", "url"}` の形式。内部的に `NBAccess`NBSetFallbackModels` に同期される。

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
型: String, 初期値: 最新 Sonnet モデル
ドキュメント生成・更新時に使用するモデル。"" で `$ClaudeModel` と同じモデルを使用。

### $ClaudeTestModel
型: String, 初期値: `$ClaudeModel` と同じ
分離検証などのテスト用モデル名。別モデルで客観的に検証するために変更可能。

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval が再帰的に ClaudeEval を生成する際の最大深度。0 で再帰禁止。

## クエリ関数

### ClaudeQuery[prompt] / ClaudeQuery[session, prompt]
Claude Code にプロンプトを送り、応答文字列を返す（同期）。
`session` を指定するとセッション履歴と直前の出力/エラーを考慮して回答する。
`{text, Image[...], File[path], ...}` でマルチモーダル入力（画像/PDF/音声を API に直接送信）。
→ String
Options: `WebSearch -> True`（Claude Code CLI 組み込み Web 検索を許可、無料）, `WebFetch -> False`（API 経由 Web 取得、課金あり、`Fallback -> True` 必須）, `Fallback -> False`, `Timeout -> Automatic`（秒）

### ClaudeQuerySync[prompt, opts]
Claude にプロンプトを送り、応答文字列を同期的に返す。WindowStatusArea に経過時間を表示する。セッション履歴やノートブック書き込みは行わない軽量版。モデルルーティング: `Model -> Automatic` かつ `PrivacyLevel <= 0.5` で Claude Code CLI、`PrivacyLevel > 0.5` で `$ClaudePrivateModel` を自動使用。
→ String
Options: `Fallback -> False`, `Model -> Automatic`（`Automatic` または `{"provider","model"}`）, `PrivacyLevel -> Automatic`, `Timeout -> Automatic`
例: `ClaudeQuerySync[prompt, Model -> {"anthropic", "claude-sonnet-4-6"}]`

### ClaudeQueryAsync[prompt, callback, nb, opts]
Claude に非同期で問い合わせ、完了時に `callback[応答文字列]` を呼ぶ。カーネルをブロックしない。`nb` は出力先 NotebookObject。WindowStatusArea に経過時間を表示する。
→ なし（非同期）
Options: `Fallback -> False`, `Model -> Automatic`, `PrivacyLevel -> Automatic`, `Timeout -> Automatic`

### ClaudeWriteResponse[nb, text, opts]
マークダウン形式のテキストをノートブックのセルとして展開する。見出し・リスト・コードブロック等を適切なセルスタイルに変換する。ClaudeQuerySync で取得した応答をノートブックに出力する際に使用する。
→ なし
Options: `AutoEvaluate -> False`

### ClaudeMath[task] → String
Mathematica コード生成に特化したプロンプトで Claude を呼び出す。

### ClaudeExtractCode[response] → String
Claude の応答から最初の ` ```mathematica ` ブロックを抽出する。

### ClaudeExtractAllCode[response] → List
Claude の応答から全 ` ```mathematica ` ブロックをリストで返す。

### ClaudeSpec["task"] / ClaudeSpec[{"task", image, ...}]
ノートブック内容からプログラムの仕様を生成する。画像付きで仕様を生成可能。パレットからセル選択で呼び出し可能。

## セッション管理

### CreateClaudeSession["name"]
名前付きセッションを作成する（デフォルト履歴を継承）。
`CreateClaudeSession[session]` は既存セッションの履歴を継承した新セッションを作成。
`CreateClaudeSession[]` はデフォルト履歴を継承した新セッションを作成。
`CreateClaudeSession[Inherit -> False]` は独立したセッションを作成。

### ClaudeRestoreSession[] / ClaudeRestoreSession["name"]
デフォルトセッション、または指定名のセッションをリストアする。

### ClaudeListSessions[] → Grid
ノートブック内の全セッションを一覧表示する。

### ClaudeDeleteSession["name"] / ClaudeDeleteSession["name", "All"]
指定名のセッションを削除する。`"All"` 指定でセッションとその全履歴を削除する。

### ClaudeShowHistory[] / ClaudeShowHistory[session] / ClaudeShowHistory["name"]
デフォルトセッション、指定セッションオブジェクト、または指定名セッションの履歴を表示する。

### ClaudeCompactHistory[] / ClaudeCompactHistory[name]
デフォルトセッション、または指定セッションの履歴を手動でコンパクションする。通常は 2n+1+w エントリを超えたときに自動実行される。

### ClaudeHistorySize[] → Association
現在のノートブックのセッション履歴サイズを診断する。Entries・ByteCount・KiloBytes・Status を含む Association を返す。200KB 超でコンパクション推奨、500KB 超で危険。

### ClaudeSessionStatus[] / ClaudeSessionStatus[name]
デフォルトセッション、または指定名セッションの状態を表示する。アクセス可能ディレクトリ、アタッチメント、作業ディレクトリのファイル等を確認可能。

## アタッチメント

### ClaudeAttach[path] / ClaudeAttach[session, path]
デフォルトセッション、または指定セッションに参照資料をアタッチする。アタッチされたファイルは ClaudeQuery/ClaudeEval 時に自動的に Read される。

### ClaudeDetach[path] / ClaudeDetach[session, path]
デフォルトセッション、または指定セッションからファイルをデタッチする。

### ClaudeAttachments[] / ClaudeAttachments[session] → List
デフォルトセッション、または指定セッションのアタッチメント一覧を返す。

### ClearAttachments[] / ClearAttachments[session]
デフォルトセッション、または指定セッションの全アタッチメントをクリアする。

## コード生成・評価

### ClaudeEval[task] / ClaudeEval[{text, data, ...}] / ClaudeEval[session, task]
コードを非同期で生成・表示し、デフォルトまたは指定セッションに履歴を保存する。テキスト・Dataset・Image・一般式を混在可能。生成された Input セルの自動実行を制御可能。
→ TaskObject（RepeatInterval 指定時）
Options:
- `AutoEvaluate -> True`（生成 Input セルを自動実行）
- `StartTime -> Now`（実行開始時刻を DateObject で指定。例: `StartTime -> Now + Quantity[3, "Hours"]`）
- `RepeatInterval -> None`（繰り返し実行。例: `RepeatInterval -> Quantity[2, "Hours"]` で 2 時間ごと。`{Quantity[1,"Hours"], 5}` で 1 時間ごと最大 5 回。`TaskRemove[]` で停止）
- `Timeout -> Automatic`（API フォールバックのタイムアウト秒数。Automatic は 600 秒）
- `Fallback -> False`
- `AutoPrivate -> False`（True: 秘密変数にアクセスするタスクの場合、生成コードに `Model -> $ClaudePrivateModel, PrivacySpec -> Automatic` を付与）

### ContinueEval[session, instruction] / ContinueEval[instruction] / ContinueEval[]
指定セッション、デフォルトセッションで継続する。引数なしは "エラーを修正してください" でデフォルトセッションを継続する。
Options: `StartTime -> Now`, `Timeout -> Automatic`

### ContinueUpdate[] / ContinueUpdate["instruction"] / ContinueUpdate["pkgName", "instruction"]
直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を継続する。追加指示付きで継続可能。指定パッケージの直前の更新を継続可能。
Options: `Fallback -> False`, `"UpdateApiMd" -> True`, `StartTime -> Now`
例: `ContinueUpdate["上半円の境界線が欠けているので修正して"]`

## デバッグ・レビュー

### ClaudeDebug[codeOrFile, errorMsg]
デバッグ支援を非同期で求める（即座に返る）。

### ClaudeReview[codeOrFile]
コードのレビューを非同期で行う。30000 文字超は自動チャンク分割する。

### ClaudeReviewChunked[codeOrFile]
ファイルをチャンク分割して非同期レビューする。

## パッケージ操作

**重要**: パッケージの更新・修正には必ず `ClaudeUpdatePackage` を使用する。`Import`/`Export` 等でパッケージファイルを直接読み書きしてはならない。

### ClaudeCreatePackage[name, prompt]
prompt に従って name.wl を新規作成し `$packageDirectory` に保存する。

### ClaudeUpdatePackage[packageName, prompt, opts]
`$packageDirectory` にある packageName.wl を Claude の支援でアップデートし、バックアップを作成する。prompt には文字列または `{文字列, Image, File[".../file.pdf"], ...}` を指定可能。バックアップ・差分更新・検証・リロードを自動で行う。
Options:
- `TargetFunctions -> Automatic`（更新対象関数を限定。Automatic で自動判定）
- `StartTime -> Now`（実行開始時刻）
- `Fallback -> False`
- `"UpdateApiMd" -> Automatic`（api.md の自動更新。Automatic は True と同等。False でスキップ）
例: `ClaudeUpdatePackage["pkg", "修正指示", StartTime -> Now + Quantity[1, "Hours"]]`

### ClaudeRestorePackage[packageName]
直前のバックアップを復元する。

### ClaudeConvertToPaclet[packageName]
`$packageDirectory` の packageName.wl を Paclet 形式に変換する。packageName/ フォルダを作成し、Kernel/、Documentation/、PacletInfo.wl 等を生成する。元の .wl ファイルはバックアップ後に削除される。

### ClaudeUpdatePackageHistory[] / ClaudeUpdatePackageHistory[packageName] → List
全パッケージ、または指定パッケージの ClaudeUpdatePackage 呼び出し履歴を表示しリストで返す。各エントリは `<|"Package"->…, "Timestamp"->…, "Directory"->…|>` の Association。

### ClaudeBackupDataset[] / ClaudeBackupDataset[packageName]
全パッケージ、または指定パッケージのバックアップ履歴を Review/Pull/Delete ボタン付き Grid で表示する。Review でバックアップ内容を確認、Pull で復元、Delete でその履歴を削除する。

### ClaudeMigrateBackupHistory[packageName] / ClaudeMigrateBackupHistory[]
既存の history 内の生 .wl バックアップを差分形式（.wl.cz / .wl.cdiff）に変換して容量を削減する。全パッケージに対して実行可能。
Options: `DryRun -> False`（True で削除せず容量削減の見積もりを表示）

## ドキュメント生成

### ClaudeCreateDocumentation["packageName"]
パッケージの詳細なドキュメント一式を Claude で自動生成する。`$packageDirectory` 内の packageName.wl または packageName/ Paclet を対象とする。単一 .wl: `$packageDirectory/packageName_info/docs/` に出力。Paclet: `$packageDirectory/packageName/docs/` に出力。リミット到達時に自動停止し、再実行で未生成分のみ続行する。README.md は最後に生成される。
Options: `References -> {}`, `Demos -> {}`, `Disclaimer -> {}`, `License -> ""`, `Acknowledgments -> {}`

### ClaudeUpdateDocumentation["packageName"] / ClaudeUpdateDocumentation["packageName", "更新指示"]
ソース差分に基づき全ドキュメントを自動更新する、または指示に従ってドキュメントを更新する。ノートブックのコンテキストも参照可能（「上で議論されている内容を反映して」など）。
Options:
- `TargetFiles -> Automatic`（自動判定。`{"api.md"}` 等でファイル指定）
- `Mode -> "Update"`（既存更新）または `"Create"`（新規作成）
例: `ClaudeUpdateDocumentation["claudecode", "api.md のみ更新して"]`
例: `ClaudeUpdateDocumentation["pkg", "...", TargetFiles -> {"api.md"}]`

## Directive 管理

### ClaudeAddDirective[target, description]
Claude で description を整形し、Claude Directives フォルダのファイルに追加して `InstallClaudeDirectives[]` を実行する。target は `"CLAUDE.md"` またはスキル名（例: `"wolfram-general"`）。元ファイルは自動バックアップされる。

### ClaudeRestoreDirective[target]
ClaudeAddDirective の直前のバックアップを復元し `InstallClaudeDirectives[]` を実行する。target は `"CLAUDE.md"` またはスキル名。

### ClaudeListDirectives[]
Claude Directives フォルダの CLAUDE.md と全スキルの一覧を表示する。

### ClaudeUpdateDirective[] / ClaudeUpdateDirective[text]
引数なしでソースコードと Claude Directives の整合性をチェックし、不整合を自動修正する。text を指定すると内容を Claude で解釈し CLAUDE.md / rules / skills の適切なファイルに反映する。ノートブックのコンテキストも参照可能。

### ClaudeDirectiveBackupDataset[]
Claude Directives の更新履歴を Review/Pull/Delete ボタン付き Grid で表示する。履歴は `ClaudeUpdateDirective[text]` や `ClaudeAddDirective` 実行時に自動保存される。

### ClaudeSyncDirectives[dir]
指定ディレクトリ dir のファイルを Claude Directives フォルダと比較し、dir 側が新しいファイルで Claude Directives を更新する。dir にだけ存在するファイルもコピーする。Claude Directives 側にしかないファイルはそのまま。
例: `ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]`

## 機密データ管理

### MarkConfidential[] / MarkConfidential[cell]
現在のセル、または指定セルを機密マークする。機密セルは ClaudeEval/ClaudeQuery のプロンプトから除外される。

### UnmarkConfidential[] / UnmarkConfidential[cell]
現在のセル、または指定セルの機密マークを解除する。

### IsConfidential[] / IsConfidential[cell] → Boolean
現在のセル、または指定セルが機密マークされているかを返す。

### Confidential[expr]
式を評価し、その Input/Output セルを自動的に機密マークする。
例: `Confidential[secretData = Import["secret.csv"]]`

### NonConfidential[expr]
式を評価し、その Input/Output セルの機密マークを明示的に解除する。秘密変数や秘密依存変数の値に依存していても、機密解除として扱う。
例: `result = NonConfidential[Mean[secretData]]`

### ScanConfidentialCells[]
ノートブック全セルをスキャンし、機密変数を参照するセルを自動的に機密マークする。明示的に `UnmarkConfidential` されたセルはスキップされる。

## Web 検索・取得

### ClaudeWebSearch[query] → String
Web 検索を実行し、結果をテキストで返す。Anthropic API の web_search ツールを使用する。

### ClaudeWebFetch[url] / ClaudeWebFetch[url, prompt] → String
指定 URL の内容を取得し、要約・抽出して返す。prompt を指定すると取得内容に対して prompt の指示を実行する。

## 状態確認・制御

### ClaudeQueryShowContext[]
デバッグ用: 次の ClaudeQuery が送信するノートブックコンテキストを表示する。

### ClaudeShowAccessConfig[]
デバッグ用: Claude Code のファイルアクセス設定を表示する。`$ClaudeAccessibleDirs`、`NBGetAccessibleDirs[]`、生成される settings.json、CLI フラグを確認可能。

### ClaudeStatus[]
現在実行中の全 Claude タスクのリアルタイム状態を表示する。各タスクの経過時間、現在の状態（思考中/テキスト生成中/ツール実行中）、生成済みテキスト断片数、思考断片数、ツール使用数を表示する。実行中タスクがない場合はその旨を表示する。

### ClaudeAbort[]
実行中の全 Claude タスクを停止する。Claude Code プロセスの強制終了、ScheduledTask の停止、フォールバックタスクのキャンセルを行う。パレットの「実行停止」ボタンからも呼び出し可能。

### ShowClaudePalette[]
Claude Code 操作用のパレットを表示する。

### ClaudeCommand["/command"] / ClaudeCommand["subcommand"] → String
Claude Code CLI のスラッシュコマンドを実行し結果を返す。スラッシュコマンド（`/` 始まり）は node-pty 経由で対話モードに送信される。CLI サブコマンド（例: `config list`）は直接実行される。
例: `ClaudeCommand["/help"]`
例: `ClaudeCommand["/permissions"]`
例: `ClaudeCommand["config list"]`
例: `ClaudeCommand["--version"]`

## NBAccess 分離原則検証

### ClaudeCheckSeparation[target]
target のコードが NBAccess の分離原則に違反している箇所をリストアップする。target はファイルパス、`$packageDirectory` の .wl 名、またはパクレット名。`$ClaudeTestModel` のモデルで検査する。
検査対象: SystemCredential 直接利用、CellObject 直接操作、CellEpilog/CellProlog/NotebookEventActions 直接操作、`NBAccess`Private`` 関数呼び出し、NBAccess 公開グローバル直接更新、EvaluationCell[]/CellPrint[]/SetSelectedNotebook[] 直接使用、CurrentValue/SetOptions による TaggingRules/CellTags/CellEpilog 属性直接アクセス、CellObject の公開 API・戻り値・状態保持への漏洩、SelectionEvaluate/FrontEndTokenExecute 等 FE 状態操作、NBAccess 公開グローバルの破壊的更新（AppendTo/AssociateTo 等）。
例: `ClaudeCheckSeparation["claudecode"]`

### ClaudeFixSeparation[target]
分離違反を修正する。target がファイルパスの場合: バックアップを作成し元ファイルを修正。target がパッケージ名のみの場合: `ClaudeUpdatePackage` を呼び出す。事前に `ClaudeCheckSeparation` の結果があればそれを利用する。

## Git コミット支援

### ClaudePrepareCommit[packageName] / ClaudePrepareCommit[packageName, subject]
前回の GitHub コミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを生成して `GitHubRefreshAndCommit` 実行コマンドを Input セルとして出力する。subject を指定すると 1 行目を固定し、本文は自動収集する。
→ なし（Input セルを出力）
Options: `Fallback -> False`, `DryRun -> False`（True でコマンドを生成せずメッセージのみ返す）, `Owner -> Automatic`, `Repository -> Automatic`, `Branch -> Automatic`, `BaseBranch -> Automatic`

## NotebookLLMGraph

ノートブック内の LLM 呼び出しを DAG（有向非巡回グラフ）として追跡・可視化するシステム。

### NotebookLLMGraph[nb] → Graph
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
指定ノードの内部サブステップ履歴を表示する。ClaudeUpdatePackage の内部処理（read-source, llm-query, merge, validate, reload）が記録される。

### NotebookLLMGraphFetchL2[nb, nodeID] → Graph | Missing
指定の L1 ノードが生成したコードブロックの L2 グラフを取得する。L2 グラフは各コードブロックの実行状態・エラー・依存関係を保持する。キャッシュにない場合は `Missing["CacheExpired"]` を返す。

### NotebookLLMGraphErrors[nb] → Dataset
L2ErrorCount > 0 または Status = "Failed" のノード一覧を Dataset で返す。L2 グラフでエラーが起きた L1 ノードの特定とデバッグに使用する。

### NotebookLLMGraphUpdateL2Status[nb, l1NodeID, l2NodeID, status, msg]
L2 ノードのステータスを手動で更新する。status: `"Completed"` | `"Failed"` | `"Pending"`
例: `NotebookLLMGraphUpdateL2Status[nb, "history-5", "history-5_L2-2", "Failed", "Undefined symbol"]`

### NotebookLLMGraphPlotL2[nb, l1NodeID]
指定の L1 ノードが生成したコードブロックの L2 計算グラフを可視化する。

### NotebookLLMGraphRerun[nb, nodeID]
指定ノードを再実行する。

### NotebookLLMGraphInvalidateDownstream[nb, nodeID]
指定ノードの下流ノードを無効化する。

### NotebookLLMGraphSummary[nb] → Association
LLMGraph のサマリー情報を返す。

### NotebookLLMGraphExtractThread[nb, nodeID] → List
指定ノードを含む会話スレッドを抽出する。

### NotebookLLMGraphApplyThread[nb, thread]
抽出したスレッドをノートブックに適用する。

### LLMGraphExecute[nb, nodeIDs]
指定ノードを実行する。

### LLMGraphExecuteStatus[nb] → Association
LLMGraph の実行状態を返す。

### LLMGraphExecuteCancel[nb]
LLMGraph の実行をキャンセルする。

## ファイル処理

### NBFileTranslate[...]
ノートブックファイルの翻訳・変換処理を行う。

### ClaudeProcessFile[...]
ファイルを Claude で処理する。

## オプション記号

### Fallback
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: Claude Code 利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。False（デフォルト）: エラーをそのまま返す。

### AutoPrivate
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: 秘密変数にアクセスするタスクの場合、生成コードに `Model -> $ClaudePrivateModel, PrivacySpec -> Automatic` を付与する。False（デフォルト）: 通常動作。

### AutoEvaluate
ClaudeEval/ClaudeWriteResponse のオプション。True（ClaudeEval デフォルト）: 生成 Input セルを自動実行。False: 手動実行。

### StartTime
ClaudeEval/ContinueEval/ClaudeUpdatePackage のオプション。実行開始時刻を DateObject で指定。
例: `StartTime -> Now + Quantity[3, "Hours"]`

### Timeout
ClaudeEval/ContinueEval/ClaudeQuerySync/ClaudeQueryAsync のオプション。API フォールバックのタイムアウト秒数。Automatic は 600 秒。

### RepeatInterval
ClaudeEval のオプション。繰り返し実行間隔。`None`（デフォルト）で繰り返しなし。
例: `RepeatInterval -> Quantity[2, "Hours"]`（2 時間ごと）
例: `RepeatInterval -> {Quantity[1,"Hours"], 5}`（1 時間ごと最大 5 回）。戻り値 TaskObject を `TaskRemove[]` で停止する。

### TargetFunctions
ClaudeUpdatePackage のオプション。更新対象関数を限定する。`Automatic` で自動判定。

### TargetFiles
ClaudeUpdateDocumentation のオプション。更新対象ファイルを指定する。`Automatic` で自動判定。
例: `TargetFiles -> {"api.md"}`

### Mode
ClaudeUpdateDocumentation のオプション。`"Update"`（既存更新、デフォルト）または `"Create"`（新規作成）。

### DryRun
ClaudeMigrateBackupHistory/ClaudePrepareCommit のオプション。True で実際の変更を行わず結果のみ表示する。

### Inherit
CreateClaudeSession のオプション。False で独立したセッションを作成する。

### Model
ClaudeQuerySync/ClaudeQueryAsync のオプション。`Automatic` または `{"provider", "model"}` の形式。
例: `Model -> {"anthropic", "claude-sonnet-4-6"}`

### WebSearch
ClaudeQuery/ClaudeEval のオプション。True（デフォルト）: Claude Code CLI 組み込み Web 検索ツールを許可する。False: 禁止する。API 経由ではないため課金は発生しない。WebFetch（課金あり）とは異なる。

### WebFetch
ClaudeQuery/ClaudeEval のオプション。True: Anthropic API 経由の Web 取得を行う（課金あり）。False（ClaudeQuery デフォルト）: 行わない。Automatic（ClaudeEval デフォルト）: Claude がタスクを分析し必要なら自動で Web 取得する。重要: `Fallback -> True` の場合のみ有効。

### References
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。URL や書籍名のリストを指定すると README.md に参考文献セクションを追加する。

### Demos
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。デモ動画や使用例の URL リストを指定すると README.md に反映する。

### Disclaimer
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。免責事項セクションに追加する文言のリストを指定する。

### License
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。空文字列（デフォルト）: `GitHubREST`$GitHubLicenseHolder` が非空なら MIT ライセンスを自動挿入。文字列指定: そのままライセンステキストとして挿入。

### Acknowledgments
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。謝辞セクションに追加する文言のリストを指定する。指定時は README.md の免責事項の前に配置される。

### Owner / Repository / Branch / BaseBranch
ClaudePrepareCommit のオプション。GitHub リポジトリ情報。すべて `Automatic` でデフォルト設定を使用する。