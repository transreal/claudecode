# claudecode API Reference

ClaudeCode パッケージ（claudecode.wl）は Mathematica ノートブックから Claude Code CLI を呼び出し、LLM 支援コード生成・パッケージ管理・ドキュメント生成を行う。NBAccess および GitHubREST パッケージと連携して動作する。

## クエリ・評価

### ClaudeQuery[prompt] → String
Claude Code に prompt を送り、応答文字列を同期的に返す。
### ClaudeQuery[session, prompt] → String
セッション履歴と直前の出力/エラーを考慮して回答する。
### ClaudeQuery[{text, Image[...], File[path], ...}] → String
テキスト・画像・PDF・音声を混在させたマルチモーダル入力。
Options: WebSearch -> True (Claude Code 組み込み Web 検索を許可。無料), WebFetch -> False (API 経由 Web 取得。課金あり。Fallback->True 必須), Fallback -> False, Timeout -> Automatic (秒数。Automatic は $ClaudeTimeout)

### ClaudeMath[task] → String
Mathematica コード生成に特化したプロンプトで Claude を呼び出す。

### ClaudeExtractCode[response] → String
Claude の応答から最初の ```mathematica ブロックを抽出する。

### ClaudeExtractAllCode[response] → List
Claude の応答から全 ```mathematica ブロックをリストで返す。

### ClaudeEval[task]
コードを非同期で生成・表示し、デフォルトセッションに履歴を保存する。
### ClaudeEval[{text, data, ...}]
テキスト・Dataset・Image・一般式を混在させて渡せる。
### ClaudeEval[session, task]
指定セッションに履歴を保存する。
Options: AutoEvaluate -> True (生成 Input セルを自動実行), StartTime -> Now (実行開始 DateObject。例: Now + Quantity[3, "Hours"]), RepeatInterval -> None (繰り返し実行間隔。例: Quantity[2, "Hours"] または {Quantity[1, "Hours"], 5} で最大5回), Timeout -> Automatic, Fallback -> False, WebSearch -> True, WebFetch -> False, AutoPrivate -> False
RepeatInterval 使用時は TaskObject が返り TaskRemove[] で停止できる。

### ContinueEval[session, instruction]
指定セッションで続行する。
### ContinueEval[instruction]
デフォルトセッションで続行する。
### ContinueEval[]
「エラーを修正してください」でデフォルトセッションを続行する。
Options: StartTime -> Now, Timeout -> Automatic, Fallback -> False

### ContinueUpdate[]
直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を続行する。
### ContinueUpdate["instruction"]
追加指示を付けて続行する。
### ContinueUpdate["pkgName", "instruction"]
指定パッケージの直前の更新を続行する。
Options: Fallback -> False, "UpdateApiMd" -> True, StartTime -> Now

### ClaudeSpec["task"] → 仕様テキスト
ノートブック内容からプログラムの仕様を生成する。
### ClaudeSpec[{"task", image, ...}]
画像付きで仕様を生成する。パレットからセル選択で呼び出せる。

### ClaudeDebug[codeOrFile, errorMsg]
デバッグ支援を非同期で求める（即座に返る）。

### ClaudeReview[codeOrFile]
コードのレビューを非同期で行う（30000文字超は自動チャンク分割）。

### ClaudeReviewChunked[codeOrFile]
ファイルをチャンク分割して非同期レビューする。

## セッション管理

### CreateClaudeSession["name"] → session
名前付きセッションを作成する（デフォルト履歴を継承）。
### CreateClaudeSession[session] → session
既存セッションの履歴を継承した新セッションを作成する。
### CreateClaudeSession[] → session
デフォルト履歴を継承した新セッションを作成する。
### CreateClaudeSession[Inherit -> False] → session
独立したセッションを作成する。

### ClaudeRestoreSession[] 
デフォルトセッションをリストアする。
### ClaudeRestoreSession["name"]
指定名のセッションをリストアする。

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

### ClaudeCompactHistory[]
デフォルトセッションの履歴を手動でコンパクションする。
### ClaudeCompactHistory[name]
指定セッションをコンパクションする。通常は 2n+1+w エントリを超えたとき自動実行される。

### ClaudeHistorySize[] → Association
現在のノートブックのセッション履歴サイズを診断する。Entries・ByteCount・KiloBytes・Status を含む Association を返す。200KB超でコンパクション推奨、500KB超で危険。

### ClaudeSessionStatus[]
デフォルトセッションの状態を表示する。
### ClaudeSessionStatus[name]
指定名のセッションの状態を表示する。アクセス可能ディレクトリ・アタッチメント・作業ディレクトリのファイル等を確認できる。

## アタッチメント

### ClaudeAttach[path]
デフォルトセッションに参照資料をアタッチする。アタッチされたファイルは ClaudeQuery/ClaudeEval 時に自動的に Read される。
### ClaudeAttach[session, path]
指定セッションにアタッチする。

### ClaudeDetach[path]
デフォルトセッションからファイルをデタッチする。
### ClaudeDetach[session, path]
指定セッションからデタッチする。

### ClaudeAttachments[] → List
デフォルトセッションのアタッチメント一覧を返す。
### ClaudeAttachments[session] → List
指定セッションのアタッチメント一覧を返す。

### ClearAttachments[]
デフォルトセッションの全アタッチメントをクリアする。
### ClearAttachments[session]
指定セッションの全アタッチメントをクリアする。

## パッケージ操作

### ClaudeCreatePackage[name, prompt]
prompt に従って name.wl を新規作成し $packageDirectory に保存する。

### ClaudeUpdatePackage[packageName, prompt]
$packageDirectory にある packageName.wl を Claude の支援でアップデートし、バックアップを作成する。prompt には文字列またはリスト {文字列, Image, File[".../file.pdf"], ...} を指定できる。
Options: TargetFunctions -> Automatic (更新対象関数を限定), StartTime -> Now, Fallback -> False, "UpdateApiMd" -> Automatic (Automatic は True と同等。False で api.md 自動更新をスキップ)
例: ClaudeUpdatePackage["pkg", "修正指示", StartTime -> Now + Quantity[1, "Hours"]]

### ClaudeRestorePackage[packageName]
直前のバックアップを復元する。

### ClaudeConvertToPaclet[packageName]
$packageDirectory の packageName.wl を Paclet 形式に変換する。packageName/ フォルダを作成し Kernel/, Documentation/, PacletInfo.wl 等を生成する。元の .wl ファイルはバックアップ後に削除される。

### ClaudeUpdatePackageHistory[] → List
全パッケージの ClaudeUpdatePackage 呼び出し履歴を表示してリストで返す。各エントリは `<|"Package"->…, "Timestamp"->…, "Directory"->…|>`。
### ClaudeUpdatePackageHistory[packageName] → List
指定パッケージの更新履歴を表示してリストで返す。

### ClaudeBackupDataset[packageName]
指定パッケージのバックアップ履歴を Review/Pull/Delete ボタン付き Grid で表示する。Review はバックアップ内容を確認、Pull は復元、Delete はその履歴を削除する。
### ClaudeBackupDataset[]
全パッケージのバックアップ履歴を表示する。

### ClaudeMigrateBackupHistory[packageName]
既存の history 内の生 .wl バックアップを差分形式（.wl.cz / .wl.cdiff）に変換して容量を削減する。
### ClaudeMigrateBackupHistory[packageName, DryRun -> True]
削除せず容量削減の見積もりを表示する。
### ClaudeMigrateBackupHistory[]
全パッケージに対して実行する。

## ドキュメント生成

### ClaudeCreateDocumentation["packageName"]
パッケージの詳細なドキュメント一式を Claude で自動生成する。単一 .wl は `$packageDirectory/packageName_info/docs/` に、Paclet は `$packageDirectory/packageName/docs/` に出力する。
Options: References -> {} (URL や書籍名のリスト。README.md の参考文献セクションに追加), Demos -> {} (デモ動画 URL リスト。README.md に反映), Disclaimer -> {} (免責事項に追記する文言のリスト), Acknowledgments -> {} (謝辞セクションに追加する文言のリスト), License -> "" (空文字列で $GitHubLicenseHolder が非空なら MIT ライセンスを自動挿入。文字列指定でカスタムライセンス), Model -> $ClaudeDocModel
例: ClaudeCreateDocumentation["pkg", References -> {"https://...", "書籍名"}, License -> ""]

### ClaudeUpdateDocumentation["packageName"]
ソース差分に基づき全ドキュメントを自動更新する。
### ClaudeUpdateDocumentation["packageName", "更新指示"]
指示に従ってドキュメントを更新する。ノートブックのコンテキストも参照可能。
Options: TargetFiles -> Automatic (Automatic で自動判定。{"api.md"} 等でファイル指定), Mode -> "Update" ("Update" は既存更新、"Create" は新規作成), References, Demos, Disclaimer, Acknowledgments, License
例: ClaudeUpdateDocumentation["claudecode", "api.mdのみ更新して", TargetFiles -> {"api.md"}]

## ディレクティブ管理

### ClaudeAddDirective[target, description]
Claude で description を整形し、Claude Directives フォルダのファイルに追加して InstallClaudeDirectives[] を実行する。target は "CLAUDE.md" またはスキル名（例: "wolfram-general"）。元ファイルは自動バックアップされる。

### ClaudeRestoreDirective[target]
ClaudeAddDirective の直前のバックアップを復元し InstallClaudeDirectives[] を実行する。target は "CLAUDE.md" またはスキル名。

### ClaudeListDirectives[]
Claude Directives フォルダの CLAUDE.md と全スキルの一覧を表示する。

### ClaudeUpdateDirective[]
ソースコードと Claude Directives の整合性をチェックし、不整合を自動修正する。
### ClaudeUpdateDirective[text]
text の内容を Claude で解釈し、CLAUDE.md / rules / skills の適切なファイルに反映する。ノートブックのコンテキストも参照可能。

### ClaudeDirectiveBackupDataset[]
Claude Directives の更新履歴を Review/Pull/Delete ボタン付き Grid で表示する。履歴は ClaudeUpdateDirective[text] や ClaudeAddDirective の実行時に自動保存される。

### ClaudeSyncDirectives[dir]
指定ディレクトリ dir のファイルを Claude Directives フォルダと比較し、dir 側が新しいファイルで Claude Directives を更新する。dir にのみ存在するファイルもコピーする。Claude Directives 側にしかないファイルはそのまま保持する。

## 機密データ管理

### MarkConfidential[]
現在のセルを機密マークする。
### MarkConfidential[cell]
指定セルを機密マークする。機密セルは ClaudeEval/ClaudeQuery のプロンプトから除外される。

### UnmarkConfidential[]
現在のセルの機密マークを解除する。
### UnmarkConfidential[cell]
指定セルの機密マークを解除する。

### IsConfidential[cell] → True|False
セルが機密マークされているかを返す。
### IsConfidential[] → True|False
現在のセルが機密かを返す。

### Confidential[expr] → expr の評価結果
式を評価し、その Input/Output セルを自動的に機密マークする。
例: Confidential[secretData = Import["secret.csv"]]

### NonConfidential[expr] → expr の評価結果
式を評価し、その Input/Output セルの機密マークを明示的に解除する。秘密変数や秘密依存変数の値に依存していても機密解除として扱う。
例: result = NonConfidential[Mean[secretData]]

### ScanConfidentialCells[]
ノートブック全セルをスキャンし、機密変数を参照するセルを自動的に機密マークする。明示的に UnmarkConfidential されたセルはスキップされる。

## Web 検索・取得

### ClaudeWebSearch[query] → String
Web 検索を実行し、結果をテキストで返す。Anthropic API の web_search ツールを使用する。

### ClaudeWebFetch[url] → String
指定 URL の内容を取得し、要約・抽出して返す。
### ClaudeWebFetch[url, prompt] → String
取得内容に対して prompt の指示を実行する。

## 状態確認・制御

### ShowClaudePalette[]
Claude Code 操作用のパレットを表示する。

### ClaudeQueryShowContext[]
デバッグ用: 次の ClaudeQuery が送信するノートブックコンテキストを表示する。

### ClaudeShowAccessConfig[]
デバッグ用: Claude Code のファイルアクセス設定を表示する。$ClaudeAccessibleDirs、NBGetAccessibleDirs[]、生成される settings.json、CLI フラグを確認できる。

### ClaudeStatus[]
現在実行中の全 Claude タスクのリアルタイム状態を表示する。各タスクの経過時間、現在の状態（思考中/テキスト生成中/ツール実行中）、生成済みテキスト断片数、思考断片数、ツール使用数を表示する。実行中のタスクがない場合はその旨を表示する。

### ClaudeAbort[]
実行中の全 Claude タスクを停止する。Claude Code プロセスの強制終了、ScheduledTask の停止、フォールバックタスクのキャンセルを行う。パレットの「実行停止」ボタンからも呼び出せる。

### ClaudeCommand["/command"] → String
Claude Code CLI のスラッシュコマンドを実行して結果を返す。スラッシュコマンド (/始まり) は node-pty 経由で対話モードに送信される。CLI サブコマンド（例: config list）は直接実行される。
例: ClaudeCommand["/help"], ClaudeCommand["/permissions"], ClaudeCommand["config list"], ClaudeCommand["--version"]

### ClaudeCheckSeparation[target]
target のコードが NBAccess の分離原則に違反している箇所をリストアップする。target はファイルパス、$packageDirectory の .wl 名、またはパクレット名。$ClaudeTestModel のモデルで検査する。
検査対象: SystemCredential 直接利用、CellObject 直接操作、CellEpilog/CellProlog/NotebookEventActions 直接操作、NBAccess`Private` 関数呼び出し、NBAccess 公開グローバル直接更新、EvaluationCell[]/CellPrint[]/SetSelectedNotebook[] 直接使用、TaggingRules/CellTags/CellEpilog 属性直接アクセス、CellObject の公開 API・戻り値・状態保持への漏洩、SelectionEvaluate/FrontEndTokenExecute 等 FE 状態操作、NBAccess 公開グローバルの破壊的更新 (AppendTo/AssociateTo 等)
例: ClaudeCheckSeparation["claudecode"], ClaudeCheckSeparation["C:\\path\\to\\file.wl"]

### ClaudeFixSeparation[target]
分離違反を修正する。target がファイルパスの場合はバックアップを作成して元ファイルを修正する。target がパッケージ名のみの場合は ClaudeUpdatePackage を呼び出す。事前に ClaudeCheckSeparation の結果があればそれを利用する。
例: ClaudeFixSeparation["claudecode"]

### ClaudePrepareCommit[packageName]
前回の GitHub コミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを生成して GitHubRefreshAndCommit 実行コマンドを Input セルとして出力する。
### ClaudePrepareCommit[packageName, subject]
1行目を指定し、本文は自動収集する。
Options: Fallback -> False, DryRun -> False (True でコマンド生成せずメッセージのみ返す), Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, BaseBranch -> Automatic

## NotebookLLMGraph

### NotebookLLMGraph[nb] → Graph
ノートブック nb の LLMGraph を返す。存在しない場合は新規作成する。

### NotebookLLMGraphPlot[nb]
ノートブックの LLMGraph をトップレベルで可視化する。Orchestrator ノードのみを表示し、アクセスレベル別に色分けする。

### NotebookLLMGraphBuild[nb]
既存のセッション履歴から LLMGraph を再構築する。現在のセッション履歴エントリをノードに変換してグラフを生成する。

### NotebookLLMGraphNodes[nb] → Association
ノートブックの LLMGraph 全ノードを Association で返す。

### NotebookLLMGraphValidate[nb]
ノートブックの LLMGraph の整合性を検証する。セッション履歴のエントリ数とノード数の一致、エッジの整合性等を確認する。

### NotebookLLMGraphFetchResponse[nb, nodeID] → String | Missing
指定ノードの response 全文を外部キャッシュから取得する。キャッシュにない場合は Missing["CacheExpired"] を返す。

### NotebookLLMGraphSubSteps[nb, nodeID]
指定ノードの内部サブステップ履歴を表示する。ClaudeUpdatePackage の内部処理（read-source, llm-query, merge, validate, reload）が記録される。

### NotebookLLMGraphFetchL2[nb, nodeID] → Graph | Missing
指定の L1 ノードが生成したコードブロックの L2 グラフを取得する。L2 グラフは各コードブロックの実行状態・エラー・依存関係を保持する。キャッシュにない場合は Missing["CacheExpired"] を返す。

### NotebookLLMGraphErrors[nb] → Dataset
L2ErrorCount > 0 または Status = "Failed" のノード一覧を Dataset で返す。L2 グラフでエラーが起きた L1 ノードの特定とデバッグに使用する。

### NotebookLLMGraphUpdateL2Status[nb, l1NodeID, l2NodeID, status, msg]
L2 ノードのステータスを手動で更新する。status: "Completed" | "Failed" | "Pending"

### NotebookLLMGraphPlotL2[nb, l1NodeID]
指定の L1 ノードが生成したコードブロックの L2 計算グラフを可視化する。各ノードは Status に応じて色分けされる。

### NotebookLLMGraphRerun[nb, nodeID]
指定の L1 ノードを再実行し、下流のノードに Invalidated フラグを設定する。
Options: Model -> Automatic, CascadeInvalidate -> True, DryRun -> False

### NotebookLLMGraphInvalidateDownstream[nb, nodeID]
指定ノードの全子孫ノードに "Invalidated" フラグを設定する。再実行前の下流を一括無効化するのに使用する。

### NotebookLLMGraphSummary[nb] → Dataset
ノード層の詳細サマリを Dataset で返す。Status 別ノード数、L2 ノード数、エラー数を一覧表示する。

### LLMGraphExecute[job, opts]
スケジュールジョブの全チャンクを LLM に投入し、結果を統合する。
Options: PromptTemplate (テンプレート文字列), Model, "Timeout", "Verbose", "WriteToNotebook", "OnJobDone"
例: LLMGraphExecute[job, PromptTemplate -> "次のテキストを要約: `content`"]

### LLMGraphExecuteStatus[jobID] → Association
実行中ジョブのリアルタイム状態を返す。

### LLMGraphExecuteCancel[jobID]
実行中ジョブをキャンセルする。

### NotebookLLMGraphExtractThread[nb, nodeID] → Thread
指定ノードに至る祖先ノードチェーンを Thread オブジェクトとして抽出する。Thread には実行指示・コード・アクセスレベルが含まれ、別ファイルへの復元適用ができる。

### NotebookLLMGraphApplyThread[thread, newTarget, nb, opts]
抽出した Thread を別の対象ファイルに適用する。newTarget はファイルパスまたは任意テキスト。DryRun -> True で実行計画のみ返す。

## グローバル変数

### $ClaudeModel
型: String, 初期値: ""
Claude CLI に渡すモデル名。"" は省略時 Claude Code 自身のデフォルトモデルを使用する。例: $ClaudeModel = "claude-opus-4-6"

### $ClaudePrivateModel
型: List, 初期値: なし
秘密データ処理用のローカルモデル指定。AutoPrivate -> True 時に秘密変数を含むタスクの生成コードに使用される。形式: {"provider", "modelName"} または {"provider", "modelName", "url"}
例: $ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}

### $ClaudeTimeout
型: Integer, 初期値: 1200
ClaudeQuery・ClaudeEval 等のタイムアウト秒数。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索されるか手動で上書きできる。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。内容が空の場合、CLAUDE.md が見つからなかったか内容がない。

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code を起動する作業ディレクトリ。このディレクトリ配下の .claude/CLAUDE.md, .claude/rules/, .claude/skills/ を Claude Code に読ませる。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。iPrepareClaudeProjectDirectory が一時的に settings.json に Read 許可を注入する。ノートブックの TaggingRules にも NBSetAccessibleDirs で永続化可能。NotebookDirectory は初回使用時にダイアログで許可を確認する（$packageDirectory 配下を除く）。

### $ClaudeFallbackModels
型: List, 初期値: {{"anthropic", $iModelOpus}, {"openai", "gpt-5"}}
フォールバックモデル優先順位。各要素は {"provider", "modelName"} または {"provider", "modelName", "url"} の形式。内部的に NBAccess`NBSetFallbackModels に同期される。

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
ドキュメント生成・更新時に使用するモデル。"" で $ClaudeModel と同じモデルを使用する。

### $ClaudeTestModel
型: String, 初期値: $ClaudeModel と同じ
分離検証などのテスト用モデル名。別モデルで客観的に検証するために変更可能。

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval が再帰的に ClaudeEval を生成する際の最大深度。0 で再帰禁止。値を大きくすると多段階の自動タスク連鎖が可能。

### $ClaudePackageKeywordMap
型: Association, 初期値: `<||>`
外部パッケージがキーワードを登録するための Association。プロンプトにキーワードが含まれると、対応パッケージの api.md がコンテキストに自動注入される。各パッケージが自身のロード時に登録する。claudecode.wl 側はパッケージ非依存。
例: $ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒切"}

## オプションシンボル

### Fallback
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: Claude Code 利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする。False（デフォルト）: エラーをそのまま返す。

### AutoPrivate
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True: 秘密変数にアクセスするタスクの場合、生成コードに Model -> $ClaudePrivateModel, PrivacySpec -> Automatic を付与する。False（デフォルト）: 通常動作。

### AutoEvaluate
ClaudeEval のオプション。True（デフォルト）: 生成された Input セルを自動実行する。False: 自動実行しない。

### StartTime
ClaudeEval/ContinueEval/ClaudeUpdatePackage のオプション。実行開始時刻を DateObject で指定する。デフォルト: Now。例: StartTime -> Now + Quantity[3, "Hours"]

### RepeatInterval
ClaudeEval のオプション（ClaudeEval 専用、他関数には使用不可）。繰り返し実行間隔を指定する。None（デフォルト）: 繰り返しなし。Quantity: その間隔で無限に繰り返す。{Quantity, n}: n 回まで繰り返す。TaskObject が返り TaskRemove[] で停止できる。

### Timeout
ClaudeEval/ContinueEval のオプション。API フォールバックのタイムアウト秒数。Automatic は $iFallbackTimeout（600秒）。

### TargetFunctions
ClaudeUpdatePackage のオプション。更新対象関数を限定する。Automatic（デフォルト）で全体を対象とする。

### TargetFiles
ClaudeUpdateDocumentation のオプション。更新対象ファイルを指定する。Automatic（デフォルト）で自動判定。例: {"api.md"}

### Mode
ClaudeUpdateDocumentation のオプション。"Update"（デフォルト）: 既存ファイルを更新する。"Create": 新規作成する。

### DryRun
ClaudeMigrateBackupHistory/ClaudePrepareCommit のオプション。True: 実際の変更を行わず見積もりや計画のみ返す。False（デフォルト）: 実際に実行する。

### Inherit
CreateClaudeSession のオプション。True（デフォルト）: デフォルト履歴を継承する。False: 独立したセッションを作成する。

### WebFetch
ClaudeQuery/ClaudeEval のオプション。True: 必ず Web 取得を行う。False（ClaudeQuery デフォルト）: Web 取得を行わない。Automatic（ClaudeEval デフォルト）: Claude がタスクを分析し必要なら自動で Web 取得する。重要: WebFetch は Anthropic API 経由で課金が発生するため Fallback -> True の場合のみ有効。

### WebSearch
ClaudeQuery/ClaudeEval のオプション。True（デフォルト）: Claude Code CLI の組み込み Web 検索ツールを許可する。False: Claude Code CLI の Web 検索を禁止する。API 経由の課金は発生しない。WebFetch（課金あり）とは異なる。

### References
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。URL や書籍名のリストを指定すると README.md に参考文献セクションを追加する。

### Demos
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。デモ動画や使用例の URL リストを指定すると README.md に反映する。

### Disclaimer
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。免責事項セクションに追記する文言のリストを指定する。

### Acknowledgments
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。謝辞セクションに追加する文言のリストを指定する。指定時は README.md の免責事項の前に配置される。

### License
ClaudeCreateDocumentation/ClaudeUpdateDocumentation のオプション。""（デフォルト）: GitHubREST`$GitHubLicenseHolder が非空なら MIT ライセンスを自動挿入する。文字列指定: そのままライセンステキストとして挿入する。

### Owner
ClaudePrepareCommit のオプション。GitHub リポジトリのオーナー名。Automatic（デフォルト）で自動判定。

### Repository
ClaudePrepareCommit のオプション。GitHub リポジトリ名。Automatic（デフォルト）で自動判定。

### Branch
ClaudePrepareCommit のオプション。コミット先ブランチ名。Automatic（デフォルト）で自動判定。

### BaseBranch
ClaudePrepareCommit のオプション。PR のベースブランチ名。Automatic（デフォルト）で自動判定。