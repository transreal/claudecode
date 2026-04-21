# claudecode API Reference

## グローバル変数

### $ClaudeModel
型: String, 初期値: ""
Claude CLI に渡すモデル名。空文字列は Claude Code 自身のデフォルトモデルを使用。
例: `$ClaudeModel = "claude-opus-4-6"`

### $ClaudePrivateModel
型: List, 初期値: {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}
秘密データ処理用のローカルモデル指定。AutoPrivate -> True 時に秘密変数を含むタスクの生成コードに使用される。
例: `$ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}`

### $ClaudeTimeout
型: Integer, 初期値: 1200
ClaudeQuery・ClaudeEval 等のタイムアウト秒数。

### $ClaudeVerbose
型: Boolean, 初期値: False
True: 履歴コンパクション等の詳細ログを Messages に出力。False: 重大エラー以外の ClaudeCode ログを抑制。

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code を起動する作業ディレクトリ。配下の .claude/CLAUDE.md, .claude/rules/, .claude/skills/ を Claude Code に読ませる。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索されるか手動で上書き可能。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。空の場合は CLAUDE.md が見つからなかったか内容がない。

### $ClaudeSnapshots
型: String, 初期値: FileNameJoin[{$ClaudeWorkingDirectory, "snapshots"}]
LLMGraphDAG スナップショットの保存ディレクトリ。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。NotebookDirectory は初回使用時にダイアログで許可を確認。
例: `$ClaudeAccessibleDirs = {$packageDirectory, "C:\\Users\\...\\作業フォルダ"}`

### $ClaudeFallbackModels
型: List, 初期値: {{"anthropic", $iModelOpus}, {"openai", "gpt-5"}}
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
型: String, 初期値: Sonnet 系最新モデル
ドキュメント生成・更新時に使用するモデル。"" で $ClaudeModel と同じモデルを使用。
例: `$ClaudeDocModel = "claude-sonnet-4-6"`

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval が再帰的に ClaudeEval を生成する際の最大深度。0 で再帰禁止。

### $ClaudeTestModel
型: String, 初期値: $ClaudeModel の値
分離検証用モデル。デフォルトは $ClaudeModel と同じ。

### $ClaudeEvalMode
型: Symbol
ClaudeEval の動作モードを制御するグローバルフラグ。

### $ClaudeEvalHook
型: Any
ClaudeEval 実行時に呼び出されるフック関数。

### $ClaudeEvalAutoThreshold
型: Number
ClaudeEval の自動 LLM 呼び出しを行うしきい値。

### $ClaudeEvalVerbose
型: Boolean
ClaudeEval の詳細ログ出力フラグ。

### $ClaudeEvalAutoLLMMinLength
型: Integer
自動 LLM 呼び出しを行う最小テキスト長。

### $ClaudeEvalAutoLLMMinNewlines
型: Integer
自動 LLM 呼び出しを行う最小改行数。

### $claudecodeVersion
型: String
パッケージのバージョン文字列。

### $LLMGraphMaxConcurrency
型: Integer
LLMGraph ノードの最大並列実行数。

### $LLMGraphAutoStopThreshold
型: Number
LLMGraph の自動停止しきい値。

### $ClaudeRoutingProviders
型: List
ルーティング対象のプロバイダーリスト。

### $UseClaudeRuntime
型: Boolean
ClaudeRuntime を使用するかどうかのフラグ。

### $ClaudeLastRuntimeId
型: String
最後に使用した ClaudeRuntime のID。

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
外部パッケージがキーワードを登録するための Association。プロンプト中のキーワードに応じて対応パッケージの api.md がコンテキストに自動注入される。各パッケージが自身のロード時に登録する。claudecode.wl 側はパッケージ非依存。
例: `$ClaudePackageKeywordMap["maildb"] = {"\:30e1\:30fc\:30eb", "mail", "\:30a2\:30fc\:30ab\:30a4\:30d6"}`

## クエリ・評価

### ClaudeQuery[prompt] → String
Claude Code に prompt を送り、応答文字列を返す（同期）。
`ClaudeQuery[session, prompt]` はセッション履歴と直前の出力/エラーを考慮して回答する。
`ClaudeQuery[{text, Image[...], File[path], ...}]` でマルチモーダル入力（画像/PDF/音声を API に直接送信）。
Options: WebSearch -> True (無料), WebFetch -> False (課金あり、Fallback -> True 必須), Fallback -> False, Timeout -> Automatic (秒)

### ClaudeQuerySync[prompt, opts] → String
Claude に prompt を送り、応答文字列を同期的に返す。WindowStatusArea に経過時間を表示。セッション履歴やノートブック書き込みは行わない軽量版。
モデルルーティングのコア：
- Model -> Automatic かつ PrivacyLevel <= 0.5: Claude Code CLI
- Model -> Automatic かつ PrivacyLevel > 0.5: $ClaudePrivateModel を自動使用
- Model -> {"provider","model"}: 指定モデルを API 経由で使用
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic
例: `ClaudeQuerySync[prompt, PrivacyLevel -> 1.0]`
例: `ClaudeQuerySync[prompt, Model -> {"anthropic", "claude-sonnet-4-6"}]`

### ClaudeQueryBg[prompt, opts] → String
FrontEnd 操作・ScheduledTask 生成なしで Claude に同期問い合わせし、応答文字列を返す。SocketListen ハンドラ・ScheduledTask コールバック等の非同期コンテキストから安全に呼び出せる。
Options: Fallback -> False, Model -> Automatic, Timeout -> Automatic
例: `ClaudeQueryBg["Hello"]`（SocketListen ハンドラ内から安全）

### ClaudeQueryAsync[prompt, callback, nb, opts]
Claude に非同期で問い合わせ、完了時に callback[応答文字列] を呼ぶ。nb は出力先 NotebookObject。カーネルをブロックしない。WindowStatusArea に経過時間を表示。
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic

### ClaudeWriteResponse[nb, text, opts]
マークダウン形式のテキストをノートブックのセルとして展開する。見出し・リスト・コードブロック等を適切なセルスタイルに変換する。ClaudeQuerySync で取得した応答をノートブックに出力する際に使用する。
Options: AutoEvaluate -> False

### ClaudeMath[task] → String
Mathematica コード生成に特化したプロンプトで Claude を呼び出す。

### ClaudeExtractCode[response] → String
Claude の応答から最初の ```mathematica ブロックを抽出する。

### ClaudeExtractAllCode[response] → List
Claude の応答から全 ```mathematica ブロックをリストで返す。

### ClaudeEval[task, opts]
コードを非同期で生成・表示し、デフォルトセッションに履歴を保存する。
`ClaudeEval[{text, data, ...}]` はテキスト、Dataset、Image、一般式を混在できる。
`ClaudeEval[session, task]` は指定セッションに履歴を保存する。
Options:
- AutoEvaluate -> True (生成された Input セルの自動実行を制御)
- StartTime -> Now (実行開始時刻を DateObject で指定)
- RepeatInterval -> None (繰り返し実行。例: Quantity[2,"Hours"] で2時間ごと)
- RepeatInterval -> {Quantity[1,"Hours"], 5} で1時間ごとに最大5回
- Timeout -> Automatic ($iFallbackTimeout=600秒)
- Fallback -> False
- AutoPrivate -> False
TaskObject が返るので TaskRemove[] で停止可能。
例: `ClaudeEval["グラフを描いて", StartTime -> Now + Quantity[3,"Hours"]]`
例: `ClaudeEval["毎時レポート", RepeatInterval -> Quantity[1,"Hours"]]`

### ContinueEval[session, instruction, opts]
指定セッションで継続。
`ContinueEval[instruction]` はデフォルトセッションで継続。
`ContinueEval[]` は "エラーを修正してください" でデフォルトセッションを継続。
Options: StartTime -> Now, Timeout -> Automatic, Fallback -> False, AutoPrivate -> False

### ContinueUpdate[instruction, opts]
直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を継続する。
`ContinueUpdate[]` は直前の更新を継続。
`ContinueUpdate["instruction"]` は追加指示を付けて継続。
`ContinueUpdate[{" instruction", img}]` はテキスト+画像で継続。
`ContinueUpdate["pkgName", "instruction"]` は指定パッケージの直前の更新を継続。
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now

### ClaudeSpec[task] → String
ノートブック内容からプログラムの仕様を生成する。`ClaudeSpec[{" task", image, ...}]` は画像付きで仕様を生成。パレットからはセル選択で呼び出し可能。

### ClaudeDebug[codeOrFile, errorMsg]
デバッグ支援を非同期で求める（即座に返る）。

### ClaudeReview[codeOrFile]
コードのレビューを非同期で行う（30000文字超は自動チャンク分割）。

### ClaudeReviewChunked[codeOrFile]
ファイルをチャンク分割して非同期レビューする。

### ClaudeStatus[] → Grid
現在実行中の全 Claude タスクのリアルタイム状態を表示する。各タスクの経過時間、現在の状態（思考中/テキスト生成中/ツール実行中）、生成済みテキスト断片数、思考断片数、ツール使用数を表示する。実行中のタスクがない場合はその旨を表示する。

### ClaudeAbort[]
実行中の全 Claude タスクを停止する。Claude Code プロセスの強制終了、ScheduledTask の停止、フォールバックタスクのキャンセルを行う。パレットの「実行停止」ボタンからも呼び出し可能。

### ClaudeCommand[cmd]
Claude Code CLI コマンドを直接実行する。

### ClaudeCheckSeparation[packageName]
パッケージの分離検証を実行する。

### ClaudeFixSeparation[packageName]
分離検証で見つかった問題を自動修正する。

### ClaudeWebSearch[query] → String
Web 検索を実行し、結果をテキストで返す。Anthropic API の web_search ツールを使用する。

### ClaudeWebFetch[url] → String
指定 URL の内容を取得し、要約・抽出して返す。
`ClaudeWebFetch[url, prompt]` は取得内容に対して prompt の指示を実行する。

### ClaudeQueryShowContext[]
デバッグ用: 次の ClaudeQuery が送信するノートブックコンテキストを表示する。

### ClaudeShowAccessConfig[]
デバッグ用: Claude Code のファイルアクセス設定を表示する。$ClaudeAccessibleDirs, NBGetAccessibleDirs[], 生成される settings.json, CLI フラグを確認可能。

### ClaudeRateLimitStatus[] → Association | None
最後に検出された Claude CLI の rate-limit 情報を Association で返す。rate-limit になっていなければ None。
返り値のキー: "Detected"->DateObject, "Source"->String, "RateLimitType"->String, "ResetsAt"->DateObject, "ResetsAtUnix"->Integer, "HttpStatus"->Integer, "Message"->String, "IsUsingOverage"->Boolean
例:
```
info = ClaudeRateLimitStatus[];
If[AssociationQ[info], If[info["ResetsAt"] > Now, Print["復旧まで待機: ", info["ResetsAt"]]], Print["rate-limit ではない"]]
```

## セッション管理

### CreateClaudeSession["name"] → Session
名前付きセッションを作成する（デフォルト履歴を継承）。
`CreateClaudeSession[session]` は既存セッションの履歴を継承した新セッションを作成。
`CreateClaudeSession[]` はデフォルト履歴を継承した新セッションを作成。
`CreateClaudeSession[Inherit -> False]` は独立したセッションを作成。

### ClaudeRestoreSession[] | ClaudeRestoreSession["name"]
デフォルトまたは指定名のセッションをリストアする。

### ClaudeListSessions[]
ノートブック内の全セッションを一覧表示する。

### ClaudeDeleteSession["name"]
指定名のセッションを削除する。
`ClaudeDeleteSession["name", "All"]` はセッションとその全履歴を削除する。

### ClaudeShowHistory[] | ClaudeShowHistory[session] | ClaudeShowHistory["name"]
デフォルト・指定セッション・指定名セッションの履歴を表示する。

### ClaudeSessionStatus[] | ClaudeSessionStatus[name]
デフォルトまたは指定名セッションの状態を表示する。アクセス可能ディレクトリ、アタッチメント、作業ディレクトリのファイル等を確認可能。

### ClaudeCompactHistory[]
セッション履歴をコンパクト化する。

### ClaudeHistorySize[] → Integer
現在のセッション履歴サイズを返す。

## アタッチメント管理

### ClaudeAttach[path, opts]
デフォルトセッションに参照資料をアタッチする。
`ClaudeAttach[url]` は URL のページを PDF 化してキャッシュしアタッチする。
`ClaudeAttach[session, path]` は指定セッションにアタッチする。
アタッチされたファイルは ClaudeQuery/ClaudeEval 時に自動的に Read される。
Options: Keywords -> {} (プロンプト中のキーワードに応じて自動注入), Title -> None, Refetch -> False

### ClaudeDetach[path] | ClaudeDetach[session, path]
デフォルトまたは指定セッションからファイルをデタッチする。

### ClaudeAttachments[] | ClaudeAttachments[session] → List
デフォルトまたは指定セッションのアタッチメント一覧を返す。

### ClearAttachments[] | ClearAttachments[session]
デフォルトまたは指定セッションの全アタッチメントをクリアする。

## パッケージ管理

### ClaudeCreatePackage[name, prompt]
prompt に従って name.wl を新規作成し $packageDirectory に保存する。

### ClaudeUpdatePackage[packageName, prompt, opts]
$packageDirectory にある packageName.wl を Claude の支援でアップデートし、バックアップを作成する。prompt には文字列またはリスト {文字列, Image, File[".../file.pdf"], ...} を指定可能。
Options: TargetFunctions -> Automatic, StartTime -> Now, Fallback -> False, "UpdateApiMd" -> Automatic
"UpdateApiMd" -> False で api.md の自動更新をスキップ。
例: `ClaudeUpdatePackage["pkg", "修正指示", StartTime -> Now + Quantity[1,"Hours"]]`

### ClaudeRestorePackage[packageName]
直前のバックアップを復元する。

### ClaudeUpdatePackageHistory[] | ClaudeUpdatePackageHistory[packageName] → List
全パッケージまたは指定パッケージの ClaudeUpdatePackage 呼び出し履歴を表示しリストで返す。各エントリは `<|"Package"->..., "Timestamp"->..., "Directory"->...|>` の Association。

### ClaudeBackupDataset[packageName] | ClaudeBackupDataset[] → Grid
指定または全パッケージのバックアップ履歴を Review/Pull/Delete ボタン付き Grid で表示する。Review はバックアップ内容を確認、Pull は復元、Delete はその履歴を削除。

### ClaudeMigrateBackupHistory[packageName, opts]
既存の history 内の生 .wl バックアップを差分形式 (.wl.cz / .wl.cdiff) に変換して容量を削減する。
`ClaudeMigrateBackupHistory[packageName, DryRun -> True]` は削除せず容量削減の見積もりを表示する。
`ClaudeMigrateBackupHistory[]` は全パッケージに対して実行する。

### ClaudeConvertToPaclet[packageName]
$packageDirectory の packageName.wl を Paclet 形式に変換する。packageName/ フォルダを作成し、Kernel/, Documentation/, PacletInfo.wl 等を生成する。元の .wl ファイルはバックアップ後に削除される。

## ドキュメント生成

### ClaudeCreateDocumentation["packageName"]
パッケージの詳細なドキュメント一式を Claude で自動生成する。$packageDirectory 内の packageName.wl または packageName/ Paclet を対象とする。
単一 .wl: `$packageDirectory/packageName_info/docs/` に出力。
Paclet: `$packageDirectory/packageName/docs/` に出力。

### ClaudeUpdateDocumentation["packageName", opts]
ソース差分に基づき全ドキュメントを自動更新する。
`ClaudeUpdateDocumentation["packageName", "更新指示"]` は指示に従ってドキュメントを更新する。ノートブックのコンテキストも参照可能（「上で議論されている内容を反映して」など）。
Options: TargetFiles -> Automatic (自動判定) | {"api.md"} 等でファイル指定, Mode -> "Update" (既存更新) | "Create" (新規作成)
例: `ClaudeUpdateDocumentation["claudecode", "api.md のみ更新して"]`
例: `ClaudeUpdateDocumentation["pkg", "...", TargetFiles -> {"api.md"}]`

## ディレクティブ管理

### ClaudeAddDirective[target, description]
Claude で description を整形し、Claude Directives フォルダのファイルに追加して InstallClaudeDirectives[] を実行する。target は "CLAUDE.md" またはスキル名（例: "wolfram-general"）。元ファイルは自動バックアップされる。

### ClaudeRestoreDirective[target]
ClaudeAddDirective の直前のバックアップを復元し InstallClaudeDirectives[] を実行する。target は "CLAUDE.md" またはスキル名。

### ClaudeListDirectives[]
Claude Directives フォルダの CLAUDE.md と全スキルの一覧を表示する。

### ClaudeUpdateDirective[text]
ソースコードと Claude Directives の整合性をチェックし、不整合を自動修正する。
`ClaudeUpdateDirective[text]` は text の内容を Claude で解釈し、CLAUDE.md / rules / skills の適切なファイルに反映する。ノートブックのコンテキストも参照可能。

### ClaudeDirectiveBackupDataset[] → Grid
Claude Directives の更新履歴を Review/Pull/Delete ボタン付き Grid で表示する。履歴は ClaudeUpdateDirective[text] や ClaudeAddDirective の実行時に自動保存される。

### ClaudeSyncDirectives[dir]
指定ディレクトリ dir のファイルを Claude Directives フォルダと比較し、dir 側の方が新しいファイルで Claude Directives を更新する。dir にだけ存在するファイルもコピーする。Claude Directives 側にしかないファイルはそのまま。
例: `ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]`

## 機密データ管理

### MarkConfidential[] | MarkConfidential[cell]
現在または指定セルを機密マークする。機密セルは ClaudeEval/ClaudeQuery のプロンプトから除外される。

### UnmarkConfidential[] | UnmarkConfidential[cell]
現在または指定セルの機密マークを解除する。

### IsConfidential[] | IsConfidential[cell] → Boolean
現在または指定セルが機密マークされているかを返す。

### Confidential[expr]
式を評価し、その Input/Output セルを自動的に機密マークする。
例: `Confidential[secretData = Import["secret.csv"]]`

### NonConfidential[expr]
式を評価し、その Input/Output セルの機密マークを明示的に解除する。秘密変数や秘密依存変数の値に依存していても、機密解除として扱う。
例: `result = NonConfidential[Mean[secretData]]`

### ScanConfidentialCells[]
ノートブック全セルをスキャンし、機密変数を参照するセルを自動的に機密マークする。明示的に UnmarkConfidential されたセルはスキップされる。

## LLMグラフ

### NotebookLLMGraph[...] → Graph
ノートブックセルから LLM グラフを構築する。

### NotebookLLMGraphPlot[graph] → Graphics
LLM グラフを可視化する。

### NotebookLLMGraphBuild[...]
LLM グラフをビルドする。

### NotebookLLMGraphNodes[graph] → List
LLM グラフのノード一覧を返す。

### NotebookLLMGraphValidate[graph] → List
LLM グラフの検証を行い、エラーリストを返す。

### NotebookLLMGraphFetchResponse[graph, node]
指定ノードの LLM 応答を取得する。

### NotebookLLMGraphSubSteps[graph, node] → List
指定ノードのサブステップを返す。

### NotebookLLMGraphFetchL2[graph] → Graph
L2（レイヤー2）グラフを取得する。

### NotebookLLMGraphErrors[graph] → List
グラフ内のエラーを返す。

### NotebookLLMGraphUpdateL2Status[graph]
L2 ステータスを更新する。

### NotebookLLMGraphPlotL2[graph] → Graphics
L2 グラフを可視化する。

### NotebookLLMGraphRerun[graph, node]
指定ノードを再実行する。

### NotebookLLMGraphInvalidateDownstream[graph, node]
指定ノードの下流ノードを無効化する。

### NotebookLLMGraphSummary[graph] → String
グラフのサマリーを返す。

### NotebookLLMGraphExtractThread[graph, node] → List
指定ノードのスレッドを抽出する。

### NotebookLLMGraphApplyThread[graph, thread]
スレッドをグラフに適用する。

### LLMGraphExecute[graph, opts]
LLM グラフを実行する。

### LLMGraphExecuteStatus[graph] → Association
LLM グラフの実行状態を返す。

### LLMGraphExecuteCancel[graph]
LLM グラフの実行をキャンセルする。

### LLMGraphDAGCreate[nodes, opts] → DAG
DAG（有向非巡回グラフ）を作成する。

### LLMGraphDAGStatus[dag] → Association
DAG の実行状態を返す。

### LLMGraphDAGCancel[dag]
DAG の実行をキャンセルする。

### LLMGraphDAGStop[dag]
DAG の実行を停止する。

### LLMGraphDAGRetry[dag, node]
DAG の指定ノードを再試行する。

### LLMGraphDAGRebuild[dag]
DAG を再ビルドする。

### LLMGraphDAGFindByContext[context] → DAG
コンテキストから DAG を検索する。

### LLMGraphDAGInspect[dag] → Association
DAG の詳細情報を返す。

### LLMGraphDAGMarkFailed[dag, node]
DAG の指定ノードを失敗マークする。

### LLMGraphDAGSnapshot[dag, opts]
DAG のスナップショットを保存する。

### LLMGraphDAGRestore[dag, snapshot]
DAG をスナップショットから復元する。

### LLMGraphDAGListSnapshots[dag] → List
DAG のスナップショット一覧を返す。

### LLMGraphDAGPlot[dag] → Graphics
DAG を可視化する。

### LLMGraphDAGMergeHistory[dag1, dag2] → DAG
2つの DAG の履歴をマージする。

## ランタイム

### ClaudeBuildRuntimeAdapter[opts] → Adapter
Claude ランタイムアダプターを構築する。

### ClaudeStartRuntime[adapter]
Claude ランタイムを起動する。

### ClaudeEvalViaRuntime[session, task, runtime, opts]
ランタイム経由で ClaudeEval を実行する。

### ClaudeBuildTransactionAdapter[opts] → Adapter
トランザクションアダプターを構築する。

### ClaudeUpdatePackageViaRuntime[packageName, prompt, runtime, opts]
ランタイム経由で ClaudeUpdatePackage を実行する。

### ClaudeApproveProposal[proposal]
提案内容を承認し適用する。

### ClaudeRuntimeSnapshot[runtime, opts]
ランタイムのスナップショットを保存する。

### ClaudeRuntimeRestore[runtime, snapshot]
ランタイムをスナップショットから復元する。

### ClaudeRuntimeListSnapshots[runtime] → List
ランタイムのスナップショット一覧を返す。

### ClaudeRegisterDAGRuntime[dag, runtime]
DAG にランタイムを登録する。

## ファイル・ノートブック操作

### NBFileTranslate[file, opts]
ノートブックファイルを変換する。

### ClaudeProcessFile[file, prompt, opts]
ファイルを処理し Claude で変換・分析する。

## コミット・GitHub 連携

### ClaudePrepareCommit[packageName, opts]
前回の GitHub コミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを生成して GitHubRefreshAndCommit 実行コマンドを Input セルとして出力する。
`ClaudePrepareCommit[packageName, subject]` は1行目を指定し、本文は自動収集。
Options: Fallback -> False, DryRun -> False, Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, BaseBranch -> Automatic
DryRun -> True でコマンドを生成せずメッセージのみ返す。

## パレット・UI

### ShowClaudePalette[]
Claude Code 操作用のパレットを表示する。

## ユーティリティ

### cleanOutput[str] → String
出力文字列をクリーンアップする。

### stripANSI[str] → String
ANSI エスケープコードを除去する。

## オプションシンボル

### Fallback
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: Claude Code 利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。False (デフォルト): エラーをそのまま返す。

### AutoPrivate
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: 秘密変数にアクセスするタスクの場合、生成コードに Model -> $ClaudePrivateModel, PrivacySpec -> Automatic を付与する。False (デフォルト): 通常動作。

### AutoEvaluate
ClaudeEval/ClaudeWriteResponse のオプション。生成された Input セルの自動実行を制御する。デフォルト: ClaudeEval では True、ClaudeWriteResponse では False。

### StartTime
ClaudeEval/ContinueEval/ClaudeUpdatePackage のオプション。実行開始時刻を DateObject で指定。デフォルト: Now。
例: `StartTime -> Now + Quantity[3, "Hours"]`

### RepeatInterval
ClaudeEval のオプション。繰り返し実行間隔を Quantity で指定。None (デフォルト): 繰り返しなし。
例: `RepeatInterval -> Quantity[2,"Hours"]`（2時間ごと）
例: `RepeatInterval -> {Quantity[1,"Hours"], 5}`（1時間ごとに最大5回）

### Timeout
ClaudeQuery/ClaudeQuerySync/ClaudeQueryBg/ClaudeQueryAsync/ClaudeEval/ContinueEval のオプション。API フォールバックのタイムアウト秒数を指定。Automatic は $iFallbackTimeout (600秒)。

### TargetFunctions
ClaudeUpdatePackage のオプション。更新対象関数を指定。Automatic で自動判定。

### TargetFiles
ClaudeUpdateDocumentation のオプション。更新対象ファイルを指定。Automatic で自動判定。例: `{"api.md"}`

### Mode
ClaudeUpdateDocumentation のオプション。"Update" (既存更新、デフォルト) または "Create" (新規作成)。

### DryRun
ClaudeMigrateBackupHistory/ClaudePrepareCommit のオプション。True でコマンドを生成せず見積もり・プレビューのみ表示。

### Inherit
CreateClaudeSession のオプション。False で独立したセッションを作成。デフォルト: True (デフォルト履歴を継承)。

### WebSearch
ClaudeQuery のオプション。True (デフォルト、無料): Web 検索を行う。False: Web 検索を行わない。

### WebFetch
ClaudeQuery/ClaudeEval のオプション。True: 必ず Web 検索を行う（Fallback -> True 必須、課金あり）。False: Web 検索を行わない。Automatic (ClaudeEval のデフォルト): Claude がタスクを分析し、必要なら自動で Web 検索する。ClaudeQuery のデフォルトは False。

### Keywords
ClaudeAttach のオプション。登録すると、プロンプト中のキーワードに応じてアタッチメントが自動注入される。デフォルト: {}。

### Title
ClaudeAttach のオプション。アタッチメントのタイトルを指定。デフォルト: None。

### Refetch
ClaudeAttach のオプション。True で URL キャッシュを無視して再取得する。デフォルト: False。

### PrivacySpec
ClaudeQuerySync のオプション。プライバシー仕様を指定。Automatic で自動判定。

### References
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。URL や書籍名のリストを指定すると README.md に参考文献セクションを追加。
例: `References -> {"https://...", "書籍名"}`

### Demos
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。デモ動画や使用例の URL リストを指定すると README.md に反映。
例: `Demos -> {"https://youtu.be/...", "https://example.com/demo.nb"}`

### Disclaimer
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。免責事項セクションに追加する文言のリストを指定。
例: `Disclaimer -> {"本ツールは研究目的専用です"}`

### License
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。空文字列 (デフォルト): GitHubREST`$GitHubLicenseHolder が非空なら MIT ライセンスを自動挿入。文字列指定: そのままライセンステキストとして挿入。
例: `License -> "MIT"`, `License -> "Apache-2.0 License..."`

### Acknowledgments
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。謝辞セクションに追加する文言のリストを指定。指定時は README.md の免責事項の前に配置。
例: `Acknowledgments -> {"本研究は JSPS 科研費の助成を受けた"}`

### Owner
ClaudePrepareCommit のオプション。GitHub リポジトリのオーナー名。デフォルト: Automatic。

### Repository
ClaudePrepareCommit のオプション。GitHub リポジトリ名。デフォルト: Automatic。

### Branch
ClaudePrepareCommit のオプション。対象ブランチ名。デフォルト: Automatic。

### BaseBranch
ClaudePrepareCommit のオプション。ベースブランチ名。デフォルト: Automatic。