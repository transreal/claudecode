# claudecode API リファレンス

パッケージ名: `ClaudeCode`
依存: [NBAccess](https://github.com/transreal/NBAccess), [GitHubREST](https://github.com/transreal/github)
リポジトリ: https://github.com/transreal/claudecode

Claude Code CLI / Anthropic API / OpenAI API / ChatGPT Codex CLI / LM Studio を Wolfram Language から統一インターフェースで呼び出すパッケージ。プロバイダ体系: `"claudecode"`（Claude Code CLI、Pro/Max サブスク、課金なし）/ `"anthropic"`（Anthropic API 直接、課金）/ `"openai"`（OpenAI API、課金）/ `"chatgptcodex"`（ChatGPT Codex CLI、サブスク内）/ `"lmstudio"`（ローカル LLM、課金なし）。

## グローバル変数

### $ClaudeModel
型: {String, String} | String, 初期値: {"claudecode", "claude-opus-4-8"}
Claude CLI に渡すプロバイダとモデルのタプル。Phase 28 以降は `{provider, modelName}` 形式が標準。文字列単体も後方互換で受け入れる（claudecode 扱い）。`""` で Claude Code 自身のデフォルトモデルを使用。
例: `$ClaudeModel = {"anthropic", "claude-opus-4-8"}`

### $ClaudeStandardFont
型: String, 初期値: "Yu Gothic UI"
ClaudeEval が生成する出力コード (Grid / Column / Style / Button 等) で統一的に使用される標準フォント名。プロンプトに埋め込まれ FontFamily 指定を強制する。ロード後に任意のフォント名を代入して変更可能。

### $ClaudeTimeout
型: Number, 初期値: 1200
ClaudeQuery・ClaudeEval 等のタイムアウト秒数。

### $ClaudeVerbose
型: Boolean, 初期値: False
True: 履歴コンパクション等の詳細ログを Messages に出力する。False: 重大エラー以外の ClaudeCode ログを抑制する。

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code を起動する作業ディレクトリ。配下の `.claude/CLAUDE.md` / `.claude/rules/` / `.claude/skills/` を Claude Code に読ませる。

### $OpenaiWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "OpenAI Working"}]
OpenAI 系 CLI を起動する作業ディレクトリ。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索されるか手動で上書き設定できる。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。空の場合は CLAUDE.md が見つからないか内容がない。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。`iPrepareClaudeProjectDirectory` が一時的に settings.json に注入する。ノートブックの TaggingRules に `NBSetAccessibleDirs` で永続化も可能。NotebookDirectory は初回使用時にダイアログで許可確認する（$packageDirectory 配下を除く）。

### $ClaudeFallbackModels
型: List, 初期値: {{"chatgptcodex","gpt-5.5"},{"anthropic",$iModelOpus},{"openai","gpt-5.5"}}
フォールバックモデル優先順位リスト。各要素は `{"provider", "modelName"}` または `{"provider", "modelName", "url"}` の形式。内部的に `NBAccess\`NBSetFallbackModels` に同期される。

### $ClaudePrivateModel
型: List
秘密データ処理用のローカルモデル指定。`AutoPrivate -> True` 時に秘密変数を含むタスクの生成コードに使用される。形式: `{"lmstudio", "modelName", "http://127.0.0.1:1234"}`

### $ClaudeSnapshots
型: String, 初期値: FileNameJoin[{$ClaudeWorkingDirectory, "snapshots"}]
LLMGraphDAG スナップショットの保存ディレクトリ。

### $ClaudeTestModel
型: String | List, 初期値: $ClaudeModel
分離検証 (ClaudeCheckSeparation) 用モデル。

### $ClaudeDocModel
型: String | List, 初期値: $iModelSonnet (最新 Sonnet)
ドキュメント生成・更新時に使用するモデル。`""` で $ClaudeModel と同じモデルを使用。旧来のモデル ID が残っている場合も自動更新される。

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

### $ClaudePackageKeywordMap
型: Association
外部パッケージがキーワードを登録するための Association。プロンプトにキーワードが含まれると対応パッケージの api.md がコンテキストに自動注入される。各パッケージが自身のロード時に登録する。claudecode.wl 側はパッケージ非依存。
例: `$ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒切"};`

### $ClaudePackageAuxKeywordMap
型: Association
補助 `api_<aux>.md` の注入条件を登録する Association。形式: `<|pkg -> <|aux -> {キーワード...}|>|>`。キーワードが task に含まれると登録済み aux の `api_<aux>.md` が注入される。未登録の補助 api は従来どおり常に注入される（後方互換）。
例: `$ClaudePackageAuxKeywordMap["SourceVault"] = <|"eagle" -> {"Eagle", "Exif"}|>;`

### $ClaudePaletteServiceControls
型: List (Association のリスト), 初期値: {}
ShowClaudePalette のプライバシーセクション直下に表示される開始/停止サービストグルのレジストリ。外部パッケージが登録する。各エントリ形式: `<|"Id"->..., "RunningQ"->(Function[]->True|False|Missing), "Start"->Function[], "Stop"->Function[], "RunningLabel"->..., "StoppedLabel"->..., "UnknownLabel"->..., "RunningColor"->...(opt), "StoppedColor"->...(opt)|>`。ラベルは RunningQ の状態に追従する。

### $LLMGraphMaxConcurrency
型: Integer
LLMGraph の最大並列実行数。

### $LLMGraphAutoStopThreshold
型: Integer
LLMGraph の自動停止閾値（エラーノード数）。

### $ClaudeRoutingProviders
型: List
ルーティングプロバイダリスト。

### $UseClaudeRuntime
型: Boolean
ClaudeRuntime を使用するかどうかのフラグ。

### $ClaudeLastRuntimeId
型: String
最後に起動した ClaudeRuntime の ID。

### $ClaudeRuntimeAsyncExecution
型: Boolean
Phase 32: コード実行を非同期化 (ParallelSubmit) するフラグ。

### $ClaudeRuntimeAsyncForce
型: Boolean
非同期実行を強制するフラグ。

### $ClaudeRuntimeAsyncSuppressInputEval
型: Boolean
非同期実行時に入力セル評価を抑制するフラグ。

### $ClaudePriorityModeUntil
型: Number
高優先モードの終了時刻 (AbsoluteTime 値)。

### $ChatgptCodexExe
型: String
ChatGPT Codex CLI の実行ファイルパス。

### $ChatgptWorkingDirectory
型: String
ChatGPT Codex を起動する作業ディレクトリ。

### $ChatgptAccessibleDirs
型: List
ChatGPT Codex に Read 許可する追加ディレクトリリスト。

### $ChatgptCodexHomeDirectory
型: String
ChatGPT Codex のホームディレクトリ。

### $ChatgptCodexPermissionProfile
型: String
ChatGPT Codex のパーミッションプロファイル。

### $ChatgptCodexApprovalPolicy
型: String
ChatGPT Codex の承認ポリシー。

### $ChatgptCodexModel
型: String | Automatic
ChatGPT Codex に渡すモデル名。Automatic でデフォルトモデルを使用。

### $ChatgptCodexHarnessMode
型: String
ChatGPT Codex のハーネスモード。

### $ChatgptCodexRetainTempProjects
型: Boolean
一時プロジェクトを保持するかどうかのフラグ。

### $ChatgptCodexSourceExposureMode
型: String
ソースコード露出モード。

### $ClaudeCLIHarnessMode
型: String
Claude CLI のハーネスモード（Phase 4: CLI ハーネスマテリアライゼーション）。

### $ClaudeEditModesVersion
型: String
ClaudeEditModes のバージョン文字列。

### $ClaudeEditModeAppendTagOpen
型: String
追記ブロックモードの開始タグ。

### $ClaudeEditModeAppendTagClose
型: String
追記ブロックモードの終了タグ。

### $ClaudeEditModeInsertTagClose
型: String
挿入モードの終了タグ。

## クエリ関数

### ClaudeQuery[task, opts]
LLM にタスクを投げて文字列応答を返す（同期、進捗表示あり）。
→ String
Options: Model -> $ClaudeModel (使用モデル), Timeout -> $ClaudeTimeout, Fallback -> False, AutoPrivate -> False, WebSearch -> False, WebFetch -> False, Integrations -> Automatic, PrivacySpec -> Automatic, NonBlocking -> False

### ClaudeQuerySync[task, opts]
フロントエンドをブロックして応答を待つ同期クエリ。
→ String
Options: ClaudeQuery と同じ

### ClaudeQueryBg[task, opts]
バックグラウンドで LLM クエリを実行し、完了時にノートブックセルに書き込む。multimodal 対応: `{prompt, image}` リスト形式で Image オブジェクトを渡せる（claudecode プロバイダでは tmp PNG 経由で CLI にリダイレクト）。
→ TaskObject | Null
Options: Model -> $ClaudeModel, Timeout -> $ClaudeTimeout, NonBlocking -> False, Fallback -> False, AutoPrivate -> False, WebSearch -> False, WebFetch -> False

### ClaudeQueryAsync[task, opts]
非同期でクエリを実行し、進捗をリアルタイム表示する。
→ Null

### ClaudeQueryAsyncSilent[task, opts]
非同期クエリ（進捗表示なし）。
→ Null

### ClaudeEval[task, opts]
LLM にコードを生成させてノートブック上で評価・実行する主力関数。`$ClaudeEvalMaxDepth` で再帰深度を制御する。`$iClaudeEvalCurrentDepth` で現在の再帰深度を追跡。
→ Null
Options: Model -> $ClaudeModel, Timeout -> $ClaudeTimeout, Fallback -> False, AutoPrivate -> False, AutoEvaluate -> True, AutoCellize -> True, WebSearch -> False, WebFetch -> False, PrivacySpec -> Automatic, OutputMode -> Automatic

### ContinueEval[opts]
直前の ClaudeEval の続きを実行する。
→ Null
Options: ClaudeEval と同じ

### ContinueUpdate[opts]
直前のタスクに対して更新指示を行う。
→ Null

### ClaudeMath[expr, opts]
数式・計算タスクに特化したクエリ。
→ String | Expression

### ClaudeExtractCode[response]
LLM 応答文字列からコードブロックを抽出する。
→ String

### ClaudeExtractAllCode[response]
LLM 応答文字列から全コードブロックをリストで返す。
→ List

### ClaudeSpec[task]
ノートブック内容からプログラムの仕様を生成する。`{task, image, ...}` リスト形式で画像付き仕様生成も可能。パレットからはセル選択で呼び出し可能。
→ Null

### ClaudeDebug[task, opts]
エラー情報・変数状態をコンテキストに含めてデバッグ支援クエリを送る。
→ Null

### ClaudeReview[task, opts]
コードレビュー専用クエリ。
→ Null
Options: TargetFiles -> Automatic, TargetFunctions -> Automatic, Baseline -> None, Model -> $ClaudeModel

### ClaudeReviewChunked[task, opts]
大きなファイルをチャンク分割してレビューする。
→ Null

### ClaudeWriteResponse[text, nb]
LLM 応答テキストをノートブックの出力セルに書き込む。
→ Null

### ClaudeEnsureSilentNotebook[]
サイレント出力用ノートブックを確保して返す。
→ NotebookObject

### cleanOutput[str]
LLM 出力の不要文字を除去して整形する。
→ String

### stripANSI[str]
ANSI エスケープシーケンスを除去する。
→ String

## セッション管理

### CreateClaudeSession[name, opts]
名前付きセッションを新規作成する。
→ Association
Options: Inherit -> None (継承元セッション名)

### ClaudeRestoreSession[name]
保存済みセッションを復元する。
→ Association | $Failed

### ClaudeListSessions[]
保存済みセッションの一覧を返す。
→ List

### ClaudeDeleteSession[name]
セッションを削除する。
→ Null

### ClaudeShowHistory[opts]
現在のセッション履歴をノートブックに表示する。
→ Null

### ClaudeHistorySize[]
現在の履歴サイズ（トークン数概算）を返す。
→ Integer

### ClaudeCompactHistory[opts]
履歴を要約してコンパクト化する。
→ Null

### ClaudeSessionStatus[]
現在のセッション状態をノートブックに表示する。
→ Null

### ClaudeQueryShowContext[]
次のクエリで送信されるコンテキスト全体を表示する。
→ String

### ClaudeShowAccessConfig[]
アクセス設定（許可ディレクトリ・プライバシー設定等）を表示する。
→ Null

## 添付ファイル管理

### ClaudeAttach[files]
ファイルまたは URL をセッションに添付する。
→ List

### ClaudeDetach[spec]
添付ファイルをセッションから取り外す。
→ Null

### ClaudeAttachments[]
現在の添付ファイル一覧を返す。
→ List

### ClearAttachments[]
全添付ファイルをクリアする。
→ Null

## レートリミット管理

### ClaudeRateLimitStatus[]
レートリミット状態を返す。
→ Association

### ClaudeRateLimitClear[]
レートリミットカウンタをリセットする。
→ Null

## プライバシー管理

### MarkConfidential[expr]
式を機密情報としてマークする。
→ Confidential[expr]

### UnmarkConfidential[expr]
機密マークを解除する。
→ expr

### IsConfidential[expr]
式が機密マークされているか判定する。
→ True | False

### ScanConfidentialCells[nb]
ノートブック内の機密セルをスキャンしてリストを返す。
→ List

## Web 操作

### ClaudeWebSearch[query, opts]
Claude Code CLI 経由で Web 検索を実行する。
→ String

### ClaudeWebFetch[url, opts]
Claude Code CLI 経由で URL の内容を取得する。
→ String

### WebSearch[query, opts]
汎用 Web 検索ラッパー。
→ String

### WebFetch[url, opts]
汎用 Web フェッチラッパー。
→ String

## コマンド・ユーティリティ

### ClaudeCommand[cmd, opts]
Claude Code CLI に任意のコマンドを送信する。
→ String

### ClaudeStatus[]
現在の Claude Code 接続状態を表示する。
→ Null

### ClaudeAbort[]
実行中のクエリを中断する。
→ Null

### ClaudeCheckSeparation[opts]
パッケージの Public/Private シンボル分離状態を検証する。結果は `$iSeparationCheckCache` にキャッシュされ ClaudeFixSeparation で再利用される。
→ Association
Options: Model -> $ClaudeTestModel

### ClaudeFixSeparation[opts]
ClaudeCheckSeparation の結果を基にパッケージの分離問題を修正する。
→ Null

## コミット支援

### ClaudePrepareCommit[opts]
変更差分から Git コミットメッセージを生成する。
→ String
Options: Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, DryRun -> False

## ドキュメント生成

### ClaudeCreateDocumentation[packageName, opts]
パッケージの README.md・api.md 等のドキュメントを新規生成する。
→ Null
Options: Model -> $ClaudeDocModel, Title -> Automatic, Keywords -> {}, References -> {} (参考文献 URL/書籍名リスト), Demos -> {} (デモ URL リスト), Disclaimer -> {} (免責文言リスト), Acknowledgments -> {} (謝辞文言リスト), License -> "" (ライセンス), Owner -> Automatic, Repository -> Automatic, Branch -> "main", BaseBranch -> "main", Refetch -> False

### ClaudeUpdateDocumentation[packageName, opts]
既存ドキュメントを更新する。多重起動をタイムスタンプ方式で防止（`$ClaudeDocUpdateStaleSeconds` 秒超で自動解放）。
→ Null
Options: ClaudeCreateDocumentation と同じ

## ディレクティブ管理

### ClaudeAddDirective[name, content]
CLAUDE.md に新規ディレクティブを追加する。
→ Null

### ClaudeRestoreDirective[name]
バックアップからディレクティブを復元する。
→ Null

### ClaudeListDirectives[]
登録済みディレクティブの一覧を返す。
→ List

### ClaudeUpdateDirective[name, content]
既存ディレクティブを更新する。
→ Null

### ClaudeDirectiveBackupDataset[]
ディレクティブのバックアップデータセットを返す。
→ Dataset

### ClaudeSyncDirectives[]
ディレクティブを同期する。
→ Null

## ファイル処理

### NBFileTranslate[file, opts]
ノートブックファイルの翻訳・変換を行う。
→ Null

### ClaudeProcessFile[file, task, opts]
指定ファイルに対してタスクを実行する。
→ Null

## パレット

### ShowClaudePalette[]
Claude Code 操作パレットを表示する。Provider ボタン（claudecode → chatgptcodex → anthropic → openai → lmstudio の順に循環）と Model ボタン（現プロバイダの候補列を循環）の 2 ボタン構成。$iPaletteProvider / $iPaletteModelName がリアルタイムで $ClaudeModel に同期される。
→ Null

### ClaudeRegisterPaletteServiceControl[spec]
ShowClaudePalette のプライバシーセクション直下に表示される開始/停止トグルを登録する。同じ Id を再登録すると置換される。登録後は `ShowClaudePalette[]` を再実行して反映する。
→ String (Id)

### ClaudeUnregisterPaletteServiceControl[id]
パレットサービストグルを Id で削除する。
→ Null

## LLMGraph (ノートブックグラフ)

### NotebookLLMGraph[nb, opts]
ノートブックの LLM グラフを取得または生成する。
→ Association

### NotebookLLMGraphPlot[nb, opts]
LLM グラフを可視化する。
→ Graphics

### NotebookLLMGraphBuild[nb, opts]
LLM グラフを構築する。
→ Association

### NotebookLLMGraphNodes[nb]
グラフのノード一覧を返す。
→ List

### NotebookLLMGraphValidate[nb]
グラフの整合性を検証する。
→ Association

### NotebookLLMGraphFetchResponse[node, opts]
指定ノードの LLM 応答を取得する。
→ String

### NotebookLLMGraphSubSteps[node]
ノードのサブステップを返す。
→ List

### NotebookLLMGraphFetchL2[node, opts]
L2 レベルの応答を取得する。
→ String

### NotebookLLMGraphErrors[nb]
グラフのエラー一覧を返す。
→ List

### NotebookLLMGraphUpdateL2Status[nb]
L2 ノードのステータスを更新する。
→ Null

### NotebookLLMGraphPlotL2[nb, opts]
L2 グラフを可視化する。
→ Graphics

### NotebookLLMGraphRerun[node, opts]
指定ノードを再実行する。
→ Null

### NotebookLLMGraphInvalidateDownstream[node]
指定ノードの下流を無効化する。
→ Null

### NotebookLLMGraphSummary[nb]
グラフの要約を返す。
→ Association

### NotebookLLMGraphExtractThread[nb, opts]
スレッドを抽出する。
→ List

### NotebookLLMGraphApplyThread[nb, thread, opts]
スレッドをグラフに適用する。
→ Null

## LLMGraph 実行

### LLMGraphExecute[graph, opts]
LLM グラフを実行する。
→ Association

### LLMGraphExecuteStatus[execId]
実行ステータスを返す。
→ Association

### LLMGraphExecuteCancel[execId]
実行をキャンセルする。
→ Null

## LLMGraph DAG

### LLMGraphDAGCreate[spec, opts]
DAG（有向非巡回グラフ）を作成する。
→ Association

### LLMGraphDAGStatus[dagId]
DAG の実行ステータスを返す。
→ Association

### LLMGraphDAGCancel[dagId]
DAG の実行をキャンセルする。
→ Null

### LLMGraphDAGStop[dagId]
DAG の実行を停止する。
→ Null

### LLMGraphDAGRetry[dagId, opts]
失敗ノードを再試行する。
→ Null

### LLMGraphDAGRebuild[dagId, opts]
DAG を再構築する。
→ Association

### LLMGraphDAGFindByContext[context]
コンテキストから DAG を検索する。
→ Association | $Failed

### LLMGraphDAGInspect[dagId]
DAG の詳細情報を表示する。
→ Null

### LLMGraphDAGMarkFailed[dagId, nodeId]
指定ノードを失敗マークする。
→ Null

### LLMGraphDAGSnapshot[dagId, opts]
DAG のスナップショットを `$ClaudeSnapshots` に保存する。
→ String (スナップショット名)

### LLMGraphDAGRestore[snapshotName]
スナップショットから DAG を復元する。
→ Association

### LLMGraphDAGListSnapshots[]
スナップショット一覧を返す。
→ List

### LLMGraphDAGPlot[dagId, opts]
DAG を可視化する。
→ Graphics

### LLMGraphDAGMergeHistory[dagId1, dagId2]
2 つの DAG の履歴をマージする。
→ Association

## ClaudeRuntime

### ClaudeBuildRuntimeAdapter[opts]
ランタイムアダプタを構築する。返り値の Association に `"DefaultTimeoutSeconds"` キーとして保持される。タイムアウト優先順: `proposal["ExpectedSeconds"]` > `adapter["DefaultTimeoutSeconds"]` > 30 (旧デフォルト)。
→ Association
Options: ExecutionTimeoutSeconds -> 30 (デフォルトタイムアウト秒数)

### ClaudeStartRuntime[adapter, opts]
ランタイムを起動する。
→ String (ランタイム ID)

### ClaudeEvalViaRuntime[expr, adapter, opts]
ランタイム経由でコードを実行する。タイムアウト発生時は showLLMCallLog / ClaudeTurnTrace ボタンをセルに追加する。
→ Expression | $Failed

### ClaudeApproveProposal[proposal]
LLM が生成した実行提案を承認して実行する。`proposal["ExpectedSeconds"]` が指定されている場合にタイムアウトを動的設定する。
→ Expression | $Failed

### ClaudeRuntimeSnapshot[runtimeId]
ランタイム状態のスナップショットを保存する。
→ String

### ClaudeRuntimeRestore[snapshotName]
スナップショットからランタイムを復元する。
→ Association

### ClaudeRuntimeListSnapshots[]
ランタイムスナップショット一覧を返す。
→ List

### ClaudeRegisterDAGRuntime[dagId, runtimeId]
DAG にランタイムを登録する。
→ Null

## 並列・優先制御

### ClaudeBeginParallelKernels[opts]
パラレルカーネルを前置起動する（Phase 32k）。
→ Null

### ClaudeBeginHighPriority[duration]
指定秒数の間、高優先モードに入る。`$ClaudePriorityModeUntil` を更新する。
→ Null

### ClaudeEndHighPriority[]
高優先モードを終了する。
→ Null

### ClaudeRegisterPollingTick[key, func, interval]
ポーリングティックを登録する。
→ Null

### ClaudeUnregisterPollingTick[key]
ポーリングティックを解除する。
→ Null

### ClaudePollingTickKeys[]
登録済みポーリングティックキーの一覧を返す。
→ List

### ClaudeEnqueueFinalAction[func]
セッション終了時に実行するアクションをキューに追加する。
→ Null

## エディットモード (claudecode_editmodes)

### ClaudeAppendBlockToPackage[packageFile, block, tag]
パッケージファイルに指定ブロックを追記モードで追加する。$ClaudeEditModeAppendTagOpen / Close を使用する。
→ Null

### ClaudeInsertBeforeAnchorInPackage[packageFile, block, anchor]
パッケージファイルのアンカー位置の前にブロックを挿入する。$ClaudeEditModeInsertTagClose を使用する。
→ Null

### ClaudeParseEditModeResponse[response]
LLM のエディットモード応答をパースして編集操作リストを返す。
→ List

### ClaudeAutoDetectEditMode[task, opts]
タスク内容からエディットモードを自動検出する。
→ String

### ClaudeBuildEditModePromptInstructions[mode]
指定エディットモード用のプロンプト指示文字列を構築する。
→ String

### ClaudeUpdatePackageWithMode[packageFile, task, opts]
エディットモードを使ってパッケージファイルを LLM で更新する。
→ Null
Options: Mode -> Automatic, DryRun -> False, TargetFiles -> Automatic, TargetFunctions -> Automatic, Model -> $ClaudeModel

## オプションキー

### Fallback
ClaudeQuery / ClaudeEval / ContinueEval のオプション。True: Claude Code 利用不可時にフォールバックモデルに自動切替（アクセスレベルに応じた利用可能モデルのみ）。False (デフォルト): エラーをそのまま返す。

### AutoPrivate
ClaudeQuery / ClaudeEval / ContinueEval のオプション。True: 秘密変数にアクセスするタスクの場合、生成コードに `Model -> $ClaudePrivateModel, PrivacySpec -> Automatic` を付与する。False (デフォルト): 通常動作。

### Integrations
ClaudeQuery / ClaudeQueryAsync のオプション。LM Studio /api/v1/chat の MCP サーバー/プラグインリストを指定する。lmstudio モデル時のみ有効。Automatic (デフォルト): `$ClaudeLMStudioIntegrations` → SourceVault の順で解決。明示リストを渡すとそれが最優先される。
例: `Integrations -> {"mcp/exa"}`

### References
ClaudeCreateDocumentation / ClaudeUpdateDocumentation のオプション。URL や書籍名のリストを指定すると README.md に参考文献セクションを追加する。デフォルト: `{}`

### Demos
ClaudeCreateDocumentation / ClaudeUpdateDocumentation のオプション。デモ動画や使用例の URL リストを指定すると README.md に反映される。デフォルト: `{}`

### Disclaimer
ClaudeCreateDocumentation / ClaudeUpdateDocumentation のオプション。免責事項セクションに追加する文言リストを指定する。デフォルト: `{}`

### Acknowledgments
ClaudeCreateDocumentation / ClaudeUpdateDocumentation のオプション。謝辞セクションに追加する文言リストを指定する。指定時は README.md の免責事項の前に配置される。デフォルト: `{}`

### License
ClaudeCreateDocumentation / ClaudeUpdateDocumentation のオプション。`""` (デフォルト): `GitHubREST\`$GitHubLicenseHolder` が非空なら MIT ライセンスを自動挿入。文字列指定: そのままライセンステキストとして挿入。
例: `License -> "MIT"`, `License -> "Apache-2.0 License..."`

### Model
各クエリ・ドキュメント関数のオプション。使用モデルを指定する。String または `{provider, modelName}` タプル。デフォルト: `$ClaudeModel`

### Timeout
各クエリ関数のオプション。タイムアウト秒数を指定する。デフォルト: `$ClaudeTimeout` (1200)

### NonBlocking
ClaudeQueryBg のオプション。True: 非ブロッキングモードで実行する。デフォルト: False

### DryRun
ClaudeUpdatePackageWithMode / ClaudePrepareCommit のオプション。True: 実際の変更を加えずに実行結果をプレビューする。デフォルト: False

### Mode
ClaudeUpdatePackageWithMode のオプション。エディットモードを指定する。デフォルト: Automatic

### TargetFiles
ClaudeReview / ClaudeUpdatePackageWithMode のオプション。対象ファイルリストを指定する。デフォルト: Automatic

### TargetFunctions
ClaudeReview / ClaudeUpdatePackageWithMode のオプション。対象関数リストを指定する。デフォルト: Automatic

### AutoEvaluate
ClaudeEval のオプション。True (デフォルト): 生成コードを自動実行する。

### AutoCellize
ClaudeEval のオプション。True (デフォルト): 結果をセル化する。

### WebSearch
クエリ関数のオプション。True: Claude Code CLI の Web 検索ツールを許可する。デフォルト: False

### WebFetch
クエリ関数のオプション。True: Claude Code CLI の WebFetch ツールを許可する。デフォルト: False

### PrivacySpec
クエリ関数のオプション。プライバシー仕様を指定する。デフォルト: Automatic

### OutputMode
ClaudeEval のオプション。出力モードを指定する。デフォルト: Automatic

### Keywords
ClaudeCreateDocumentation のオプション。キーワードリストを指定する。デフォルト: `{}`

### Title
ClaudeCreateDocumentation のオプション。ドキュメントタイトルを指定する。デフォルト: Automatic

### Refetch
ドキュメント更新時のオプション。True: 強制再取得する。デフォルト: False

### Owner
GitHub オーナー名を指定するオプション。デフォルト: Automatic

### Repository
GitHub リポジトリ名を指定するオプション。デフォルト: Automatic

### Branch
GitHub ブランチ名を指定するオプション。デフォルト: Automatic

### BaseBranch
GitHub ベースブランチ名を指定するオプション。デフォルト: "main"

### Baseline
ClaudeReview のオプション。比較ベースラインを指定する。デフォルト: None

### RepeatInterval
繰り返し実行間隔を指定するオプション（秒）。

### StartTime
開始時刻を指定するオプション。

### Inherit
CreateClaudeSession のオプション。継承元セッション名を指定する。デフォルト: None