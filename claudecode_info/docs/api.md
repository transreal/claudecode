# claudecode API Reference

## 概要
`ClaudeCode`` パッケージは Wolfram Language / Mathematica から Claude Code CLI および Anthropic API を呼び出すインターフェースを提供する。主要機能: クエリ送信、コード生成・評価、パッケージ更新、ドキュメント生成、セッション管理、機密データ管理、LLMグラフ追跡。依存パッケージ: [NBAccess](https://github.com/transreal/NBAccess), [GitHubREST (github.wl)](https://github.com/transreal/github)。

## グローバル変数

### $ClaudeModel
型: String, 初期値: ""
Claude CLI に渡すモデル名。"" は Claude Code 自身のデフォルトモデルを使用する。
例: `$ClaudeModel = "claude-opus-4-6"`

### $ClaudePrivateModel
型: List, 初期値: なし
秘密データ処理用ローカルモデル指定。`AutoPrivate -> True` 時に秘密変数を含むタスクの生成コードに使用される。
例: `$ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}`

### $ClaudeTimeout
型: Number, 初期値: 1200
ClaudeQuery・ClaudeEval 等のタイムアウト秒数。

### $ClaudeVerbose
型: Boolean, 初期値: False
True: 履歴コンパクション等の詳細ログを Messages に出力する。False: 重大エラー以外の ClaudeCode ログを抑制する。

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code を起動する作業ディレクトリ。配下の .claude/CLAUDE.md, .claude/rules/, .claude/skills/ を Claude Code に読ませる。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索されるか、手動で上書きできる。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。空の場合、CLAUDE.md が見つからなかったか内容がない。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。NotebookDirectory は初回使用時にダイアログで許可を確認する（$packageDirectory 配下を除く）。ノートブックの TaggingRules にも NBSetAccessibleDirs で永続化可能。
例: `$ClaudeAccessibleDirs = {$packageDirectory, "F:\\Dropbox\\Mathematica-oneDrive"}`

### $ClaudeFallbackModels
型: List, 初期値: {{"anthropic", OpusModel}, {"openai", "gpt-5"}}
フォールバックモデル優先順位。各要素は `{"provider", "modelName"}` または `{"provider", "modelName", "url"}` の形式。内部的に `NBAccess`NBSetFallbackModels` に同期される。
例: `$ClaudeFallbackModels = {{"anthropic","claude-opus-4-6"},{"lmstudio","gpt-oss-20b","http://127.0.0.1:1234"}}`

### $ClaudeDocModel
型: String, 初期値: 最新 Sonnet モデル
ドキュメント生成・更新時に使用するモデル。"" で $ClaudeModel と同じモデルを使用する。

### $ClaudeDocRetryDelay
型: Number, 初期値: 60
ドキュメント生成のリトライ待機秒数。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
ドキュメント生成の最大リトライ回数。

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースの最大文字数。

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval が再帰的に ClaudeEval を生成する際の最大深度。0 で再帰禁止。大きくすると多段階の自動タスク連鎖が可能。

### $ClaudeTestModel
型: String, 初期値: $ClaudeModel と同じ
分離検証（ClaudeCheckSeparation）などのテスト用モデル名。別モデルで客観的に検証するために変更可能。

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
外部パッケージがキーワードを登録するための Association。プロンプトにキーワードが含まれると対応パッケージの api.md がコンテキストに自動注入される。各パッケージが自身のロード時に登録する。claudecode.wl 側はパッケージ非依存。
例: `$ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒切"}`

## クエリ・評価

### ClaudeQuery[prompt] / ClaudeQuery[session, prompt]
Claude Code にプロンプトを送り、応答文字列を返す（同期）。session を指定するとセッション履歴と直前の出力/エラーを考慮して回答する。
→ String
Options: WebSearch -> True（無料）, WebFetch -> False（課金あり, Fallback->True 必須）, Fallback -> False, Timeout -> Automatic（秒）
`ClaudeQuery[{text, Image[...], File[path], ...}]` でマルチモーダル入力。画像/PDF/音声を API に直接送信する。

### ClaudeQuerySync[prompt, opts]
Claude にプロンプトを送り、応答文字列を同期的に返す軽量版。セッション履歴やノートブック書き込みは行わない。WindowStatusArea に経過時間を表示する。
→ String
モデルルーティング: Model->Automatic かつ PrivacyLevel<=0.5 → Claude Code CLI; PrivacyLevel>0.5 → $ClaudePrivateModel を自動使用。
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic
例: `ClaudeQuerySync[prompt, Model -> {"anthropic", "claude-sonnet-4-6"}]`

### ClaudeQueryAsync[prompt, callback, nb, opts]
Claude に非同期で問い合わせ、完了時に `callback[応答文字列]` を呼ぶ。カーネルをブロックしない。WindowStatusArea に経過時間を表示する。
→ なし（副作用のみ）
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic

### ClaudeWriteResponse[nb, text, opts]
マークダウン形式のテキストをノートブックのセルとして展開する。見出し・リスト・コードブロック等を適切なセルスタイルに変換する。
→ なし（副作用のみ）
Options: AutoEvaluate -> False

### ClaudeMath[task] → String
Mathematica コード生成に特化したプロンプトで Claude を呼び出す。

### ClaudeExtractCode[response] → String
Claude の応答から最初の ```mathematica ブロックを抽出する。

### ClaudeExtractAllCode[response] → List
Claude の応答から全 ```mathematica ブロックをリストで返す。

### ClaudeEval[task, opts] / ClaudeEval[session, task, opts]
コードを非同期で生成・表示し、デフォルトまたは指定セッションに履歴を保存する。
→ TaskObject（RepeatInterval 指定時）/ なし
`ClaudeEval[{text, data, ...}]` でテキスト、Dataset、Image、一般式を混在できる。
Options: AutoEvaluate -> True, StartTime -> Now, RepeatInterval -> None, Timeout -> Automatic, Fallback -> False, AutoPrivate -> False, WebSearch -> True, WebFetch -> Automatic
例: `ClaudeEval["データを可視化して", StartTime -> Now + Quantity[3, "Hours"]]`
例: `ClaudeEval["毎時更新", RepeatInterval -> Quantity[2, "Hours"]]`（TaskRemove[] で停止）
例: `ClaudeEval["最大5回", RepeatInterval -> {Quantity[1,"Hours"], 5}]`

### ContinueEval[session, instruction] / ContinueEval[instruction] / ContinueEval[]
指定セッション（省略時はデフォルトセッション）で続行する。引数省略時は「エラーを修正してください」で続行する。
→ なし（副作用のみ）
Options: StartTime -> Now, Timeout -> Automatic, Fallback -> False, AutoPrivate -> False

### ContinueUpdate[opts] / ContinueUpdate["instruction", opts] / ContinueUpdate["pkgName", "instruction", opts]
直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を続行する。pkgName を指定すると指定パッケージの直前の更新を続行する。
→ なし（副作用のみ）
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now
例: `ContinueUpdate["上半円の境界線が欠けているので修正して"]`

### ClaudeSpec["task"] / ClaudeSpec[{task, image, ...}]
ノートブック内容からプログラムの仕様を生成する。画像付きで仕様を生成可能。パレットからセル選択で呼び出し可能。
→ なし（副作用のみ）

### ClaudeDebug[codeOrFile, errorMsg]
デバッグ支援を非同期で求める（即座に返る）。
→ なし（副作用のみ）

### ClaudeReview[codeOrFile]
コードのレビューを非同期で行う（30000文字超は自動チャンク分割）。
→ なし（副作用のみ）

### ClaudeReviewChunked[codeOrFile]
ファイルをチャンク分割して非同期レビューする。
→ なし（副作用のみ）

## セッション管理

### CreateClaudeSession["name"] / CreateClaudeSession[session] / CreateClaudeSession[]
名前付きセッションを作成する（デフォルト履歴を継承）。セッションオブジェクトや既存セッションを渡すと履歴を継承した新セッションを作成する。
→ セッションオブジェクト
Options: Inherit -> True（False で独立したセッションを作成）

### ClaudeRestoreSession[] / ClaudeRestoreSession["name"]
デフォルトまたは指定名のセッションをリストアする。
→ なし（副作用のみ）

### ClaudeListSessions[]
ノートブック内の全セッションを一覧表示する。
→ なし（副作用のみ）

### ClaudeDeleteSession["name"] / ClaudeDeleteSession["name", "All"]
指定名のセッションを削除する。"All" を指定するとセッションと全履歴を削除する。
→ なし（副作用のみ）

### ClaudeShowHistory[] / ClaudeShowHistory[session] / ClaudeShowHistory["name"]
デフォルトまたは指定セッションの履歴を表示する。
→ なし（副作用のみ）

### ClaudeCompactHistory[] / ClaudeCompactHistory[name]
デフォルトまたは指定セッションの履歴を手動でコンパクションする。通常は 2n+1+w エントリを超えたときに自動実行される。
→ なし（副作用のみ）

### ClaudeHistorySize[]
現在のノートブックのセッション履歴サイズを診断する。200KB超でコンパクション推奨、500KB超で危険。
→ Association（Entries, ByteCount, KiloBytes, Status を含む）

### ClaudeSessionStatus[] / ClaudeSessionStatus[name]
デフォルトまたは指定名のセッションの状態を表示する。アクセス可能ディレクトリ、アタッチメント、作業ディレクトリのファイル等を確認できる。
→ なし（副作用のみ）

## アタッチメント

### ClaudeAttach[path] / ClaudeAttach[url] / ClaudeAttach[session, path]
デフォルトまたは指定セッションに参照資料をアタッチする。URL の場合はページを PDF 化してキャッシュしアタッチする。アタッチされたファイルは ClaudeQuery/ClaudeEval 時に自動的に Read される。
→ なし（副作用のみ）
Options: Keywords -> {}（プロンプト中のキーワードに応じて自動注入）, Title -> None, Refetch -> False

### ClaudeDetach[path] / ClaudeDetach[session, path]
デフォルトまたは指定セッションからファイルをデタッチする。
→ なし（副作用のみ）

### ClaudeAttachments[] / ClaudeAttachments[session]
デフォルトまたは指定セッションのアタッチメント一覧を返す。
→ List

### ClearAttachments[] / ClearAttachments[session]
デフォルトまたは指定セッションの全アタッチメントをクリアする。
→ なし（副作用のみ）

## 機密データ管理

### MarkConfidential[] / MarkConfidential[cell]
現在または指定セルを機密マークする。機密セルは ClaudeEval/ClaudeQuery のプロンプトから除外される。
→ なし（副作用のみ）

### UnmarkConfidential[] / UnmarkConfidential[cell]
現在または指定セルの機密マークを解除する。
→ なし（副作用のみ）

### IsConfidential[] / IsConfidential[cell]
現在または指定セルが機密マークされているかを返す。
→ Boolean

### Confidential[expr]
式を評価し、その Input/Output セルを自動的に機密マークする。
→ expr の評価結果
例: `Confidential[secretData = Import["secret.csv"]]`

### NonConfidential[expr]
式を評価し、その Input/Output セルの機密マークを明示的に解除する。秘密変数や秘密依存変数の値に依存していても機密解除として扱う。
→ expr の評価結果
例: `result = NonConfidential[Mean[secretData]]`

### ScanConfidentialCells[]
ノートブック全セルをスキャンし、機密変数を参照するセルを自動的に機密マークする。明示的に UnmarkConfidential されたセルはスキップされる。
→ なし（副作用のみ）

## パッケージ操作

### ClaudeCreatePackage[name, prompt]
prompt に従って name.wl を新規作成し $packageDirectory に保存する。
→ なし（副作用のみ）

### ClaudeUpdatePackage[packageName, prompt, opts]
$packageDirectory にある packageName.wl を Claude の支援でアップデートし、バックアップを作成する。prompt には文字列またはリスト `{文字列, Image, File[".../file.pdf"], ...}` を指定可能。バックアップ・差分更新・検証・再ロードを自動で行う。
→ なし（副作用のみ）
Options: TargetFunctions -> Automatic, StartTime -> Now, Fallback -> False, "UpdateApiMd" -> Automatic（False で api.md の自動更新をスキップ）
例: `ClaudeUpdatePackage["pkg", "修正指示", StartTime -> Now + Quantity[1, "Hours"]]`

### ClaudeRestorePackage[packageName]
直前のバックアップを復元する。
→ なし（副作用のみ）

### ClaudeConvertToPaclet[packageName]
$packageDirectory の packageName.wl を Paclet 形式に変換する。packageName/ フォルダを作成し Kernel/, Documentation/, PacletInfo.wl 等を生成する。元の .wl ファイルはバックアップ後に削除される。
→ なし（副作用のみ）

### ClaudeUpdatePackageHistory[] / ClaudeUpdatePackageHistory[packageName]
全パッケージまたは指定パッケージの ClaudeUpdatePackage 呼び出し履歴を表示しリストで返す。各エントリは `<|"Package"->..., "Timestamp"->..., "Directory"->...|>` の Association。
→ List

### ClaudeBackupDataset[packageName] / ClaudeBackupDataset[]
指定または全パッケージのバックアップ履歴を Review/Pull/Delete ボタン付き Grid で表示する。Review でバックアップ内容を確認、Pull で復元、Delete でその履歴を削除する。
→ なし（副作用のみ）

### ClaudeMigrateBackupHistory[packageName, opts] / ClaudeMigrateBackupHistory[]
既存の history 内の生 .wl バックアップを差分形式（.wl.cz / .wl.cdiff）に変換して容量を削減する。引数なしで全パッケージに対して実行する。
→ なし（副作用のみ）
Options: DryRun -> False（True で削除せず容量削減の見積もりを表示）

## ドキュメント生成

### ClaudeCreateDocumentation["packageName", opts]
パッケージの詳細なドキュメント一式を Claude で自動生成する。$packageDirectory 内の packageName.wl または packageName/ Paclet を対象とする。単一 .wl: $packageDirectory/packageName_info/docs/ に出力。Paclet: $packageDirectory/packageName/docs/ に出力。リミット到達時に自動停止し、再実行で未生成分のみ続行する。README.md は最後に生成される。
→ なし（副作用のみ）
Options: References -> {}, Demos -> {}, Disclaimer -> {}, License -> "", Acknowledgments -> {}

### ClaudeUpdateDocumentation["packageName", opts] / ClaudeUpdateDocumentation["packageName", "instruction", opts]
ソース差分に基づき全ドキュメントを自動更新する。instruction を指定すると指示に従ってドキュメントを更新する。ノートブックのコンテキストも参照可能。
→ なし（副作用のみ）
Options: TargetFiles -> Automatic（{"api.md"} 等でファイル指定も可）, Mode -> "Update"（"Create" で新規作成）, References -> {}, Demos -> {}, Disclaimer -> {}, License -> "", Acknowledgments -> {}
例: `ClaudeUpdateDocumentation["claudecode", "api.mdのみ更新して", TargetFiles -> {"api.md"}]`

## ディレクティブ管理

### ClaudeAddDirective[target, description]
Claude で description を整形し、Claude Directives フォルダのファイルに追加して `InstallClaudeDirectives[]` を実行する。target は "CLAUDE.md" またはスキル名（例: "wolfram-general"）。元ファイルは自動バックアップされる。
→ なし（副作用のみ）

### ClaudeRestoreDirective[target]
ClaudeAddDirective の直前のバックアップを復元し `InstallClaudeDirectives[]` を実行する。target は "CLAUDE.md" またはスキル名。
→ なし（副作用のみ）

### ClaudeListDirectives[]
Claude Directives フォルダの CLAUDE.md と全スキルの一覧を表示する。
→ なし（副作用のみ）

### ClaudeUpdateDirective[] / ClaudeUpdateDirective[text]
ソースコードと Claude Directives の整合性をチェックし、不整合を自動修正する。text を指定すると内容を Claude で解釈し CLAUDE.md / rules / skills の適切なファイルに反映する。ノートブックのコンテキストも参照可能。
→ なし（副作用のみ）

### ClaudeDirectiveBackupDataset[]
Claude Directives の更新履歴を Review/Pull/Delete ボタン付き Grid で表示する。履歴は ClaudeUpdateDirective[text] や ClaudeAddDirective の実行時に自動保存される。
→ なし（副作用のみ）

### ClaudeSyncDirectives[dir]
指定ディレクトリ dir のファイルを Claude Directives フォルダと比較し、dir 側が新しいファイルで Claude Directives を更新する。dir にだけ存在するファイルもコピーする。Claude Directives 側にしかないファイルはそのまま。
→ なし（副作用のみ）
例: `ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]`

## Web ツール

### ClaudeWebSearch[query]
Web 検索を実行し、結果をテキストで返す。Anthropic API の web_search ツールを使用する。
→ String

### ClaudeWebFetch[url] / ClaudeWebFetch[url, prompt]
指定 URL の内容を取得し、要約・抽出して返す。prompt を指定すると取得内容に対して prompt の指示を実行する。
→ String

## Git・コミット

### ClaudePrepareCommit[packageName, opts] / ClaudePrepareCommit[packageName, subject, opts]
前回の GitHub コミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを生成して `GitHubRefreshAndCommit` 実行コマンドを Input セルとして出力する。subject を指定すると1行目を固定し本文は自動収集する。
→ なし（副作用のみ）
Options: Fallback -> False, DryRun -> False, Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, BaseBranch -> Automatic
例: `ClaudePrepareCommit["claudecode", DryRun -> True]`（コマンドを生成せずメッセージのみ返す）

## 診断・制御

### ShowClaudePalette[]
Claude Code 操作用のパレットを表示する。
→ なし（副作用のみ）

### ClaudeQueryShowContext[]
デバッグ用: 次の ClaudeQuery が送信するノートブックコンテキストを表示する。
→ なし（副作用のみ）

### ClaudeShowAccessConfig[]
デバッグ用: Claude Code のファイルアクセス設定を表示する。$ClaudeAccessibleDirs、NBGetAccessibleDirs[]、生成される settings.json、CLI フラグを確認できる。
→ なし（副作用のみ）

### ClaudeStatus[]
現在実行中の全 Claude タスクのリアルタイム状態を表示する。各タスクの経過時間、現在の状態（思考中/テキスト生成中/ツール実行中）、生成済みテキスト断片数、思考断片数、ツール使用数を表示する。実行中タスクがない場合はその旨を表示する。
→ なし（副作用のみ）

### ClaudeAbort[]
実行中の全 Claude タスクを停止する。Claude Code プロセスの強制終了、ScheduledTask の停止、フォールバックタスクのキャンセルを行う。パレットの「実行停止」ボタンからも呼び出し可能。
→ なし（副作用のみ）

### ClaudeCommand["/command"] / ClaudeCommand["subcommand"]
Claude Code CLI のスラッシュコマンドを実行し結果を返す。スラッシュコマンド（/ 始まり）は node-pty 経由で対話モードに送信される。CLI サブコマンド（例: config list）は直接実行される。
→ String
例: `ClaudeCommand["/help"]`, `ClaudeCommand["/permissions"]`, `ClaudeCommand["config list"]`, `ClaudeCommand["--version"]`

## 分離検証

### ClaudeCheckSeparation[target]
target のコードが NBAccess の分離原則に違反している箇所をリストアップする。target はファイルパス | $packageDirectory の .wl 名 | パクレット名。$ClaudeTestModel のモデルで検査する。
→ なし（副作用のみ）
検査項目: (a) SystemCredential 直接利用、(b) CellObject 直接操作、(c) CellEpilog/CellProlog/NotebookEventActions 直接操作、(d) NBAccess`Private` 関数呼び出し、(e) NBAccess 公開グローバル直接更新、(f) EvaluationCell[]/CellPrint[]/SetSelectedNotebook[] 直接使用、(g) CurrentValue/SetOptions による TaggingRules/CellTags/CellEpilog 直接アクセス、(h) CellObject の公開 API・戻り値・状態保持への漏洩、(i) SelectionEvaluate/FrontEndTokenExecute 等 FE 状態操作、(j) NBAccess 公開グローバルの破壊的更新 (AppendTo/AssociateTo 等)
例: `ClaudeCheckSeparation["claudecode"]`

### ClaudeFixSeparation[target]
分離違反を修正する。target がファイルパスの場合: バックアップを作成し元ファイルを修正。target がパッケージ名のみの場合: ClaudeUpdatePackage を呼び出す。事前に ClaudeCheckSeparation の結果があればそれを利用する。
→ なし（副作用のみ）
例: `ClaudeFixSeparation["claudecode"]`

## LLMグラフ（NotebookLLMGraph）

LLM 呼び出しを DAG として追跡し可視化・再実行するシステム。

### NotebookLLMGraph[nb]
ノートブック nb の LLMGraph を返す。存在しない場合は新規作成する。
→ Graph

### NotebookLLMGraphPlot[nb]
ノートブックの LLMGraph をトップレベルで可視化する。Orchestrator ノードのみを表示し、アクセスレベル別に色分けする。
→ Graphics

### NotebookLLMGraphBuild[nb]
既存のセッション履歴から LLMGraph を再構築する。現在のセッション履歴エントリをノードに変換しグラフを生成する。
→ Graph

### NotebookLLMGraphNodes[nb]
ノートブックの LLMGraph 全ノードを Association で返す。
→ Association

### NotebookLLMGraphValidate[nb]
ノートブックの LLMGraph の整合性を検証する。セッション履歴のエントリ数とノード数の一致、エッジの整合性等を確認する。
→ なし（副作用のみ）

### NotebookLLMGraphFetchResponse[nb, nodeID]
指定ノードの response 全文を外部キャッシュから取得する。キャッシュにない場合は Missing["CacheExpired"] を返す。
→ String | Missing

### NotebookLLMGraphSubSteps[nb, nodeID]
指定ノードの内部サブステップ履歴を表示する。ClaudeUpdatePackage の内部処理（read-source, llm-query, merge, validate, reload）が記録される。
→ なし（副作用のみ）

### NotebookLLMGraphFetchL2[nb, nodeID]
指定の L1 ノードが生成したコードブロックの L2 グラフを取得する。L2 グラフは各コードブロックの実行状態・エラー・依存関係を保持する。キャッシュにない場合は Missing["CacheExpired"] を返す。
→ Graph | Missing

### NotebookLLMGraphErrors[nb]
L2ErrorCount > 0 または Status = "Failed" のノード一覧を Dataset で返す。
→ Dataset

### NotebookLLMGraphUpdateL2Status[nb, nodeID, status]
指定ノードの L2 ステータスを更新する。
→ なし（副作用のみ）

### NotebookLLMGraphPlotL2[nb, nodeID]
指定ノードの L2 グラフを可視化する。
→ Graphics

### NotebookLLMGraphRerun[nb, nodeID]
指定ノードを再実行する。
→ なし（副作用のみ）

### NotebookLLMGraphInvalidateDownstream[nb, nodeID]
指定ノードとその下流ノードを無効化する。
→ なし（副作用のみ）

### NotebookLLMGraphSummary[nb]
ノートブックの LLMGraph のサマリーを表示する。
→ なし（副作用のみ）

### NotebookLLMGraphExtractThread[nb, nodeID]
指定ノードのスレッドを抽出する。
→ List

### NotebookLLMGraphApplyThread[nb, thread]
指定スレッドをノートブックに適用する。
→ なし（副作用のみ）

### LLMGraphExecute[graph]
LLMGraph を実行する。
→ なし（副作用のみ）

### LLMGraphExecuteStatus[id]
指定 ID の LLMGraph 実行状態を返す。
→ Association

### LLMGraphExecuteCancel[id]
指定 ID の LLMGraph 実行をキャンセルする。
→ なし（副作用のみ）

## ファイル処理

### NBFileTranslate[args]
ノートブックファイルの翻訳処理を行う。
→ なし（副作用のみ）

### ClaudeProcessFile[args]
ファイルを Claude で処理する。
→ なし（副作用のみ）

## オプションシンボル一覧

`Fallback` — ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: Claude Code 利用不可時にフォールバックモデルに自動切替。False（デフォルト）: エラーをそのまま返す。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。

`AutoEvaluate` — ClaudeEval/ClaudeWriteResponse のオプション。True（デフォルト）: 生成された Input セルを自動実行。False: 実行しない。

`AutoPrivate` — ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: 秘密変数にアクセスするタスクの場合、生成コードに `Model -> $ClaudePrivateModel, PrivacySpec -> Automatic` を付与する。False（デフォルト）: 通常動作。

`StartTime` — ClaudeEval/ContinueEval/ClaudeUpdatePackage/ContinueUpdate のオプション。実行開始時刻を DateObject で指定する。デフォルト Now。
例: `StartTime -> Now + Quantity[3, "Hours"]`

`Timeout` — ClaudeQuery/ClaudeEval/ContinueEval のオプション。API フォールバックのタイムアウト秒数。Automatic は内部デフォルト（600秒）。

`RepeatInterval` — ClaudeEval のオプション。None（デフォルト）または Quantity で繰り返し実行間隔を指定。`{Quantity[1,"Hours"], 5}` で最大5回実行。返値の TaskObject を TaskRemove[] で停止できる。

`WebSearch` — ClaudeQuery/ClaudeEval のオプション。True（デフォルト）: Claude Code CLI の組み込み Web 検索ツールを許可する。False: 禁止する。課金は発生しない。WebFetch（課金あり）とは異なる。

`WebFetch` — ClaudeQuery/ClaudeEval のオプション。True: 必ず Web 取得を行う。False（ClaudeQuery デフォルト）: 行わない。Automatic（ClaudeEval デフォルト）: Claude がタスクを分析し必要なら自動で Web 取得する。Anthropic API 経由で課金が発生するため Fallback -> True の場合のみ有効。

`TargetFunctions` — ClaudeUpdatePackage のオプション。Automatic: 全関数を対象。関数名リストで対象を限定する。デフォルト Automatic。

`TargetFiles` — ClaudeUpdateDocumentation のオプション。Automatic: 自動判定。`{"api.md"}` 等でファイルを指定する。デフォルト Automatic。

`Mode` — ClaudeUpdateDocumentation のオプション。"Update"（既存更新、デフォルト）または "Create"（新規作成）。

`DryRun` — ClaudeMigrateBackupHistory/ClaudePrepareCommit のオプション。True で実際の変更を行わず見積もり・プレビューのみ表示する。デフォルト False。

`Inherit` — CreateClaudeSession のオプション。True（デフォルト）: デフォルト履歴を継承。False: 独立したセッションを作成する。

`Keywords` — ClaudeAttach のオプション。キーワードリストを登録するとプロンプト中のキーワードに応じてアタッチメントが自動注入される。デフォルト {}。

`Title` — ClaudeAttach のオプション。アタッチメントのタイトルを指定する。デフォルト None。

`Refetch` — ClaudeAttach のオプション。True で URL を再取得してキャッシュを更新する。デフォルト False。

`Owner`, `Repository`, `Branch`, `BaseBranch` — ClaudePrepareCommit のオプション。Automatic でリポジトリ情報を自動検出する。

`References` — ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。URL や書籍名のリスト。README.md に参考文献セクションを追加する。デフォルト {}。

`Demos` — ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。デモ動画や使用例の URL リスト。README.md に反映される。デフォルト {}。

`Disclaimer` — ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。免責事項セクションに追加する文言のリスト。デフォルト {}。

`License` — ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。""（デフォルト）: GitHubREST`$GitHubLicenseHolder が非空なら MIT ライセンスを自動挿入。文字列指定: そのままライセンステキストとして挿入する。

`Acknowledgments` — ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。謝辞セクションに追加する文言のリスト。README.md の免責事項の前に配置される。デフォルト {}。