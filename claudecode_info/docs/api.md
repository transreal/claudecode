# claudecode API Reference

ClaudeCode パッケージは Wolfram Language から Claude AI を操作するためのインターフェースを提供する。

## クエリ関数

### ClaudeQuery[prompt] / ClaudeQuery[session, prompt]
Claude Code に prompt を送り、応答文字列を同期的に返す。セッション履歴と直前の出力/エラーを考慮して回答する。
→ String
Options: WebSearch -> True (無料), WebFetch -> False (課金あり,Fallback->True 必須), Fallback -> False, Timeout -> Automatic (秒)
マルチモーダル: ClaudeQuery[{text, Image[...], File[path], ...}] で画像/PDF/音声を直接送信。

### ClaudeQuerySync[prompt, opts]
Claude に prompt を送り、応答文字列を同期的に返す。WindowStatusArea に経過時間を表示する。セッション履歴・ノートブック書き込みなし。
→ String
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic
モデルルーティング: Model -> Automatic かつ PrivacyLevel <= 0.5 → Claude Code CLI、> 0.5 → $ClaudePrivateModel 自動使用。
例: ClaudeQuerySync[prompt, Model -> {"anthropic", "claude-sonnet-4-6"}]

### ClaudeQueryBg[prompt, opts]
FrontEnd 操作・ScheduledTask 生成なしで Claude に同期問い合わせし、応答文字列を返す。SocketListen ハンドラ等の非同期コンテキストから安全に呼び出せる。
→ String
Options: Fallback -> False, Model -> Automatic, Timeout -> Automatic

### ClaudeQueryAsync[prompt, callback, nb, opts]
Claude に非同期で問い合わせ、完了時に callback[応答文字列] を呼ぶ。nb は出力先 NotebookObject。カーネルをブロックしない。
→ Null
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic

### ClaudeWriteResponse[nb, text, opts]
マークダウン形式のテキストをノートブックのセルとして展開する。見出し・リスト・コードブロック等を適切なセルスタイルに変換する。
→ Null
Options: AutoEvaluate -> False

### ClaudeMath[task]
Mathematica コード生成に特化したプロンプトで Claude を呼び出す。
→ String

### ClaudeExtractCode[response]
Claude の応答から最初の ```mathematica ブロックを抽出する。
→ String

### ClaudeExtractAllCode[response]
Claude の応答から全 ```mathematica ブロックをリストで返す。
→ {String, ...}

## 評価・実行関数

### ClaudeEval[task, opts] / ClaudeEval[session, task, opts]
コードを非同期で生成・表示し、デフォルトまたは指定セッションに履歴を保存する。task には文字列・Dataset・Image・一般式の混在リストを指定可能。
→ TaskObject
Options: AutoEvaluate -> True, StartTime -> Now, RepeatInterval -> None, Timeout -> Automatic, Fallback -> False, AutoPrivate -> False
例: ClaudeEval["グラフを描いて", StartTime -> Now + Quantity[3, "Hours"]]
例: ClaudeEval["毎時実行", RepeatInterval -> {Quantity[1,"Hours"], 5}]  (* 最大5回 *)

### ContinueEval[session, instruction] / ContinueEval[instruction] / ContinueEval[]
指定またはデフォルトセッションで継続実行する。引数なしは「エラーを修正してください」でデフォルトセッションを継続。
Options: StartTime -> Now, Timeout -> Automatic

### ContinueUpdate["instruction"] / ContinueUpdate[] / ContinueUpdate["pkgName", "instruction"]
直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を継続する。テキスト+画像: ContinueUpdate[{"instruction", img}]
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now

### ClaudeSpec["task"] / ClaudeSpec[{"task", image, ...}]
ノートブック内容からプログラムの仕様を生成する。画像付き指定可能。パレットからセル選択で呼び出し可能。

## セッション管理

### CreateClaudeSession["name"] / CreateClaudeSession[session] / CreateClaudeSession[]
名前付きセッションを作成する（デフォルト履歴を継承）。
Options: Inherit -> True
Inherit -> False で独立したセッションを作成。

### ClaudeRestoreSession[] / ClaudeRestoreSession["name"]
デフォルトまたは指定名のセッションをリストアする。

### ClaudeListSessions[]
ノートブック内の全セッションを一覧表示する。
→ Grid

### ClaudeDeleteSession["name"] / ClaudeDeleteSession["name", "All"]
指定名のセッションを削除する。"All" 指定でセッションと全履歴を削除。

### ClaudeShowHistory[] / ClaudeShowHistory[session] / ClaudeShowHistory["name"]
デフォルト・指定セッション・指定名のセッション履歴を表示する。

### ClaudeSessionStatus[] / ClaudeSessionStatus[name]
セッションの状態（アクセス可能ディレクトリ・アタッチメント・作業ディレクトリ等）を表示する。

### ClaudeCompactHistory[]
セッション履歴を圧縮する。

### ClaudeHistorySize[]
セッション履歴のサイズを返す。

## アタッチメント管理

### ClaudeAttach[path] / ClaudeAttach[url] / ClaudeAttach[session, path]
デフォルトまたは指定セッションに参照資料をアタッチする。URL 指定時はページを PDF 化してキャッシュしアタッチする。アタッチされたファイルは ClaudeQuery/ClaudeEval 時に自動的に Read される。
Options: Keywords -> {}, Title -> None, Refetch -> False
Keywords 登録でプロンプト中のキーワードに応じて自動注入される。

### ClaudeDetach[path] / ClaudeDetach[session, path]
デフォルトまたは指定セッションからファイルをデタッチする。

### ClaudeAttachments[] / ClaudeAttachments[session]
セッションのアタッチメント一覧を返す。

### ClearAttachments[] / ClearAttachments[session]
セッションの全アタッチメントをクリアする。

## パッケージ操作

### ClaudeCreatePackage[name, prompt]
prompt に従って name.wl を新規作成し $packageDirectory に保存する。

### ClaudeUpdatePackage[packageName, prompt, opts]
$packageDirectory にある packageName.wl を Claude の支援でアップデートし、バックアップを作成する。prompt には文字列またはリスト {文字列, Image, File[".../file.pdf"], ...} を指定可能。
→ TaskObject
Options: TargetFunctions -> Automatic, StartTime -> Now, Fallback -> False, "UpdateApiMd" -> Automatic
"UpdateApiMd" -> False で api.md の自動更新をスキップ。
例: ClaudeUpdatePackage["pkg", "修正指示", StartTime -> Now + Quantity[1, "Hours"]]

### ClaudeRestorePackage[packageName]
直前のバックアップを復元する。

### ClaudeConvertToPaclet[packageName]
$packageDirectory の packageName.wl を Paclet 形式に変換する。packageName/ フォルダを作成し Kernel/, Documentation/, PacletInfo.wl 等を生成する。元の .wl ファイルはバックアップ後に削除される。

### ClaudeUpdatePackageHistory[] / ClaudeUpdatePackageHistory[packageName]
全パッケージまたは指定パッケージの ClaudeUpdatePackage 呼び出し履歴を表示しリストで返す。各エントリは <|"Package"->..., "Timestamp"->..., "Directory"->...|> の Association。

### ClaudeBackupDataset[packageName] / ClaudeBackupDataset[]
指定または全パッケージのバックアップ履歴を Review/Pull/Delete ボタン付き Grid で表示する。

### ClaudeMigrateBackupHistory[packageName, opts] / ClaudeMigrateBackupHistory[]
既存 history 内の生 .wl バックアップを差分形式 (.wl.cz / .wl.cdiff) に変換して容量を削減する。
Options: DryRun -> False
DryRun -> True で削除せず容量削減の見積もりを表示。

## ドキュメント生成

### ClaudeCreateDocumentation["packageName", opts]
パッケージの詳細なドキュメント一式を Claude で自動生成する。単一 .wl: $packageDirectory/packageName_info/docs/ に出力。Paclet: $packageDirectory/packageName/docs/ に出力。
Options: References -> {}, Demos -> {}, Disclaimer -> {}, License -> "", Acknowledgments -> {}

### ClaudeUpdateDocumentation["packageName", opts] / ClaudeUpdateDocumentation["packageName", "instruction", opts]
ソース差分に基づき全ドキュメントを自動更新する。または指示に従ってドキュメントを更新する。ノートブックのコンテキストも参照可能。
Options: TargetFiles -> Automatic, Mode -> "Update"
TargetFiles -> {"api.md"} 等でファイル指定可能。Mode -> "Create" で新規作成。
例: ClaudeUpdateDocumentation["claudecode", "api.mdのみ更新して", TargetFiles -> {"api.md"}]

## ディレクティブ管理

### ClaudeAddDirective[target, description]
Claude で description を整形し、Claude Directives フォルダのファイルに追加して InstallClaudeDirectives[] を実行する。target は "CLAUDE.md" またはスキル名（例: "wolfram-general"）。元ファイルは自動バックアップされる。

### ClaudeRestoreDirective[target]
ClaudeAddDirective の直前のバックアップを復元し InstallClaudeDirectives[] を実行する。target は "CLAUDE.md" またはスキル名。

### ClaudeListDirectives[]
Claude Directives フォルダの CLAUDE.md と全スキルの一覧を表示する。

### ClaudeUpdateDirective[] / ClaudeUpdateDirective[text]
ソースコードと Claude Directives の整合性をチェックし、不整合を自動修正する。text 指定時は内容を Claude で解釈し CLAUDE.md / rules / skills の適切なファイルに反映する。ノートブックのコンテキストも参照可能。

### ClaudeDirectiveBackupDataset[]
Claude Directives の更新履歴を Review/Pull/Delete ボタン付き Grid で表示する。

### ClaudeSyncDirectives[dir]
指定ディレクトリ dir のファイルを Claude Directives フォルダと比較し、dir 側が新しいファイルで更新する。dir にだけ存在するファイルもコピーする。Claude Directives 側にしかないファイルはそのまま。
例: ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]

## 機密データ管理

### MarkConfidential[] / MarkConfidential[cell]
現在または指定セルを機密マークする。機密セルは ClaudeEval/ClaudeQuery のプロンプトから除外される。

### UnmarkConfidential[] / UnmarkConfidential[cell]
現在または指定セルの機密マークを解除する。

### IsConfidential[] / IsConfidential[cell]
現在または指定セルが機密マークされているかを返す。
→ True | False

### Confidential[expr]
式を評価し、その Input/Output セルを自動的に機密マークする。
例: Confidential[secretData = Import["secret.csv"]]

### NonConfidential[expr]
式を評価し、その Input/Output セルの機密マークを明示的に解除する。秘密変数や秘密依存変数の値に依存していても機密解除として扱う。
例: result = NonConfidential[Mean[secretData]]

### ScanConfidentialCells[]
ノートブック全セルをスキャンし、機密変数を参照するセルを自動的に機密マークする。明示的に UnmarkConfidential されたセルはスキップされる。

## デバッグ・レビュー

### ClaudeDebug[codeOrFile, errorMsg]
デバッグ支援を非同期で求める（即座に返る）。

### ClaudeReview[codeOrFile]
コードのレビューを非同期で行う（30000文字超は自動チャンク分割）。

### ClaudeReviewChunked[codeOrFile]
ファイルをチャンク分割して非同期レビューする。

## ステータス・制御

### ClaudeStatus[]
実行中の全 Claude タスクのリアルタイム状態を表示する。経過時間・状態（思考中/テキスト生成中/ツール実行中）・生成済みテキスト断片数・思考断片数・ツール使用数を表示する。

### ClaudeAbort[]
実行中の全 Claude タスクを停止する。Claude Code プロセスの強制終了、ScheduledTask の停止、フォールバックタスクのキャンセルを行う。パレットの「実行停止」ボタンからも呼び出し可能。

### ClaudeRateLimitStatus[]
最後に検出された Claude CLI の rate-limit 情報を Association で返す。rate-limit でなければ None。
→ Association | None
キー: "Detected" (DateObject), "Source", "RateLimitType", "ResetsAt" (DateObject), "ResetsAtUnix", "HttpStatus", "Message", "IsUsingOverage"
例: info = ClaudeRateLimitStatus[]; If[AssociationQ[info], Print["復旧まで待機: ", info["ResetsAt"]]]

### ClaudeRateLimitClear[]
内部に保持された rate-limit 情報を手動でクリアする。誤検出や status=allowed の進捗通知によりブロックがかかった際に使用する。

### ShowClaudePalette[]
Claude Code 操作用のパレットを表示する。

### ClaudeQueryShowContext[]
デバッグ用: 次の ClaudeQuery が送信するノートブックコンテキストを表示する。

### ClaudeShowAccessConfig[]
デバッグ用: Claude Code のファイルアクセス設定を表示する。$ClaudeAccessibleDirs, NBGetAccessibleDirs[], 生成される settings.json, CLI フラグを確認可能。

### ClaudeCommand["command"]
Claude Code CLI のスラッシュコマンドを実行する。
例: ClaudeCommand["/compact"]

### ClaudeCheckSeparation["packageName"]
パッケージの NBAccess 分離原則を検証する。

### ClaudeFixSeparation["packageName"]
パッケージの NBAccess 分離原則違反を修正する。

## Web 検索・取得

### ClaudeWebSearch[query]
Web 検索を実行し、結果をテキストで返す。Anthropic API の web_search ツールを使用する。
→ String

### ClaudeWebFetch[url]
指定 URL のページ内容を取得して返す。
→ String

## Git コミット

### ClaudePrepareCommit[packageName, opts] / ClaudePrepareCommit[packageName, subject, opts]
前回の GitHub コミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを生成して GitHubRefreshAndCommit 実行コマンドを Input セルとして出力する。subject 指定時は1行目を固定し本文は自動収集。
→ Null (副作用: Input セルを出力)
Options: Fallback -> False, DryRun -> False, Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, BaseBranch -> Automatic
DryRun -> True でコマンドを生成せずメッセージのみ返す。

## ノートブック LLM グラフ

### NotebookLLMGraph[...]
ノートブックベースの LLM グラフを定義する。

### NotebookLLMGraphPlot[...]
LLM グラフを可視化する。

### NotebookLLMGraphBuild[...]
LLM グラフを構築する。

### NotebookLLMGraphNodes[...]
LLM グラフのノードを返す。

### NotebookLLMGraphValidate[...]
LLM グラフを検証する。

### NotebookLLMGraphFetchResponse[...]
LLM グラフの応答を取得する。

### NotebookLLMGraphSubSteps[...]
LLM グラフのサブステップを返す。

### NotebookLLMGraphFetchL2[...]
LLM グラフの L2 応答を取得する。

### NotebookLLMGraphErrors[...]
LLM グラフのエラーを返す。

### NotebookLLMGraphUpdateL2Status[...]
LLM グラフの L2 ステータスを更新する。

### NotebookLLMGraphPlotL2[...]
LLM グラフの L2 を可視化する。

### NotebookLLMGraphRerun[...]
LLM グラフを再実行する。

### NotebookLLMGraphInvalidateDownstream[...]
LLM グラフの下流ノードを無効化する。

### NotebookLLMGraphSummary[...]
LLM グラフのサマリーを返す。

### NotebookLLMGraphExtractThread[...]
LLM グラフからスレッドを抽出する。

### NotebookLLMGraphApplyThread[...]
LLM グラフにスレッドを適用する。

## LLM グラフ DAG

### LLMGraphExecute[...]
LLM グラフを実行する。

### LLMGraphExecuteStatus[...]
LLM グラフの実行ステータスを返す。

### LLMGraphExecuteCancel[...]
LLM グラフの実行をキャンセルする。

### LLMGraphDAGCreate[...]
LLM グラフ DAG を作成する。

### LLMGraphDAGStatus[...]
DAG の実行ステータスを返す。

### LLMGraphDAGCancel[...]
DAG の実行をキャンセルする。

### LLMGraphDAGStop[...]
DAG の実行を停止する。

### LLMGraphDAGRetry[...]
DAG の失敗ノードをリトライする。

### LLMGraphDAGRebuild[...]
DAG を再構築する。

### LLMGraphDAGFindByContext[...]
コンテキストで DAG を検索する。

### LLMGraphDAGInspect[...]
DAG の詳細を検査する。

### LLMGraphDAGMarkFailed[...]
DAG ノードを失敗としてマークする。

### LLMGraphDAGSnapshot[...]
DAG のスナップショットを作成する。

### LLMGraphDAGRestore[...]
DAG のスナップショットを復元する。

### LLMGraphDAGListSnapshots[...]
DAG のスナップショット一覧を返す。

### LLMGraphDAGPlot[...]
DAG を可視化する。

### LLMGraphDAGMergeHistory[...]
DAG の履歴をマージする。

## ランタイム関数

### ClaudeBuildRuntimeAdapter[...]
Claude ランタイムアダプターを構築する。

### ClaudeStartRuntime[...]
Claude ランタイムを起動する。

### ClaudeEvalViaRuntime[...]
Claude ランタイム経由で評価する。

### ClaudeBuildTransactionAdapter[...]
トランザクションアダプターを構築する。

### ClaudeUpdatePackageViaRuntime[...]
ランタイム経由でパッケージを更新する。

### ClaudeApproveProposal[...]
Claude のプロポーザルを承認する。

### ClaudeRuntimeSnapshot[...]
ランタイムのスナップショットを作成する。

### ClaudeRuntimeRestore[...]
ランタイムのスナップショットを復元する。

### ClaudeRuntimeListSnapshots[...]
ランタイムのスナップショット一覧を返す。

### ClaudeRegisterDAGRuntime[...]
DAG ランタイムを登録する。

## ユーティリティ

### cleanOutput[...]
出力をクリーンアップする。

### stripANSI[...]
ANSI エスケープシーケンスを除去する。

### NBFileTranslate[...]
ノートブックファイルを翻訳する。

### ClaudeProcessFile[...]
ファイルを Claude で処理する。

## 編集モード関数

### ClaudeAppendBlockToPackage[...]
パッケージにブロックを追記する。

### ClaudeInsertBeforeAnchorInPackage[...]
パッケージのアンカー前に挿入する。

### ClaudeParseEditModeResponse[...]
編集モード応答を解析する。

### ClaudeAutoDetectEditMode[...]
編集モードを自動検出する。

### ClaudeBuildEditModePromptInstructions[...]
編集モードのプロンプト指示を構築する。

### ClaudeUpdatePackageWithMode[...]
指定編集モードでパッケージを更新する。

## グローバル変数

### $ClaudeModel
型: String, 初期値: ""
Claude CLI に渡すモデル名。"" は Claude Code 自身のデフォルトモデルを使用する。
例: $ClaudeModel = "claude-opus-4-6"

### $ClaudePrivateModel
型: {String, String} | {String, String, String}, 初期値: なし
機密データ処理用のローカルモデル指定。AutoPrivate -> True 時に機密変数を含むタスクの生成コードに使用される。
例: $ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
外部パッケージがキーワードを登録するための Association。プロンプトにキーワードが含まれると対応パッケージの api.md がコンテキストに自動注入される。各パッケージが自身のロード時に登録する。claudecode.wl 側はパッケージ非依存。
例: $ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〆切"}

### $ClaudeTimeout
型: Number, 初期値: 1200
ClaudeQuery・ClaudeEval 等のタイムアウト秒数。

### $ClaudeVerbose
型: True | False, 初期値: False
True で履歴コンパクション等の詳細ログを Messages に出力する。False は重大エラー以外の ClaudeCode ログを抑制する。

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code を起動する作業ディレクトリ。このディレクトリ配下の .claude/CLAUDE.md, .claude/rules/, .claude/skills/ を Claude Code に読ませる。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索されるか手動で上書き可能。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。空の場合、CLAUDE.md が見つからなかったか内容がない。

### $ClaudeSnapshots
型: String, 初期値: FileNameJoin[{$ClaudeWorkingDirectory, "snapshots"}]
LLMGraphDAG スナップショットの保存ディレクトリ。

### $ClaudeAccessibleDirs
型: {String, ...}, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。iPrepareClaudeProjectDirectory が一時的に settings.json に Read 許可を注入する。NotebookDirectory は初回使用時にダイアログで許可を確認する（$packageDirectory 配下を除く）。
例: $ClaudeAccessibleDirs = {$packageDirectory, "C:\\Users\\...\\作業フォルダ"}

### $ClaudeFallbackModels
型: {{String, String}, ...}, 初期値: {{"anthropic", $iModelOpus}, {"openai", "gpt-5"}}
フォールバックモデル優先順位。各要素は {"provider", "modelName"} または {"provider", "modelName", "url"} の形式。内部的には NBAccess`NBSetFallbackModels に同期される。

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
ドキュメント生成・更新時に使用するモデル。"" で $ClaudeModel と同じモデルを使用する。ユーザーが未カスタマイズなら最新 Sonnet に自動更新される。
例: $ClaudeDocModel = "claude-sonnet-4-6"

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval が再帰的に ClaudeEval を生成する際の最大深度。0 で再帰禁止。値を大きくすると多段階の自動タスク連鎖が可能。

### $ClaudeEvalMode
型: Automatic | "Sync" | "Async"
ClaudeEval の実行モード。

### $ClaudeEvalHook
型: Function | None
ClaudeEval 実行時のフック関数。

### $ClaudeEvalAutoThreshold
型: Number
ClaudeEval の自動実行しきい値。

### $ClaudeEvalVerbose
型: True | False
ClaudeEval の詳細ログ出力フラグ。

### $ClaudeEvalAutoLLMMinLength
型: Integer
自動 LLM 呼び出しの最小テキスト長。

### $ClaudeEvalAutoLLMMinNewlines
型: Integer
自動 LLM 呼び出しの最小改行数。

### $claudecodeVersion
型: String
claudecode パッケージのバージョン文字列。

### $LLMGraphMaxConcurrency
型: Integer
LLM グラフの最大同時実行数。

### $LLMGraphAutoStopThreshold
型: Integer | Infinity
LLM グラフの自動停止しきい値。

### $ClaudeRoutingProviders
型: {String, ...}
使用するルーティングプロバイダーのリスト。

### $UseClaudeRuntime
型: True | False, 初期値: False
True で Claude ランタイム経由で操作を実行する。

### $ClaudeLastRuntimeId
型: String | None
最後に使用した Claude ランタイムの ID。

### $ClaudeTestModel
型: String, 初期値: $ClaudeModel
分離検証用モデル。デフォルトは $ClaudeModel と同じ。

## オプションシンボル

### Fallback -> False
ClaudeQuery/ClaudeEval/ContinueEval/ClaudeUpdatePackage のオプション。True: Claude Code 利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。

### AutoPrivate -> False
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: 機密変数にアクセスするタスクの場合、生成コードに Model -> $ClaudePrivateModel, PrivacySpec -> Automatic を付与する。

### AutoEvaluate -> True
ClaudeEval/ClaudeWriteResponse のオプション。生成された Input セルの自動実行を制御する。

### StartTime -> Now
ClaudeEval/ContinueEval/ClaudeUpdatePackage/ContinueUpdate のオプション。実行開始時刻を DateObject で指定する。
例: StartTime -> Now + Quantity[3, "Hours"]

### Timeout -> Automatic
各クエリ関数のオプション。API フォールバックのタイムアウト秒数。Automatic は $iFallbackTimeout (600秒)。

### TargetFiles -> Automatic
ClaudeUpdateDocumentation のオプション。更新対象ファイルを指定する。
例: TargetFiles -> {"api.md"}

### TargetFunctions -> Automatic
ClaudeUpdatePackage のオプション。更新対象関数を指定する。

### Mode -> "Update"
ClaudeUpdateDocumentation のオプション。"Update" (既存更新) または "Create" (新規作成)。

### DryRun -> False
ClaudeMigrateBackupHistory/ClaudePrepareCommit のオプション。True で実際の変更を行わずプレビューのみ表示する。

### Inherit -> True
CreateClaudeSession のオプション。False で独立したセッションを作成する。

### RepeatInterval -> None
ClaudeEval のオプション。繰り返し実行の間隔を Quantity で指定する。{interval, maxCount} 形式で最大回数を制限可能。TaskObject が返るので TaskRemove[] で停止可能。
例: RepeatInterval -> {Quantity[1,"Hours"], 5}

### PrivacySpec -> Automatic
ClaudeQuerySync/ClaudeQueryAsync のオプション。プライバシーレベル指定。

### Keywords -> {}
ClaudeAttach のオプション。登録するとプロンプト中のキーワードに応じて自動注入される。

### Title -> None
ClaudeAttach のオプション。アタッチメントのタイトルを指定する。

### Refetch -> False
ClaudeAttach のオプション。True で URL キャッシュを再取得する。

### Owner -> Automatic
ClaudePrepareCommit のオプション。GitHub リポジトリのオーナーを指定する。

### Repository -> Automatic
ClaudePrepareCommit のオプション。GitHub リポジトリ名を指定する。

### Branch -> Automatic
ClaudePrepareCommit のオプション。コミット先ブランチを指定する。

### BaseBranch -> Automatic
ClaudePrepareCommit のオプション。ベースブランチを指定する。

### References -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。URL や書籍名のリストを指定すると README.md に参考文献セクションを追加する。

### Demos -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。デモ動画や使用例の URL リストを指定すると README.md に反映する。

### Disclaimer -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。免責事項セクションに追加する文言のリストを指定する。

### License -> ""
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。空文字列 (デフォルト): GitHubREST`$GitHubLicenseHolder が非空なら MIT ライセンスを自動挿入。文字列指定: そのままライセンステキストとして挿入。

### Acknowledgments -> {}
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。謝辞セクションに追加する文言のリストを指定する。指定時は README.md の免責事項の前に配置する。