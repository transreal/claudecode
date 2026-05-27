# claudecode API リファレンス

Claude Code CLI / Anthropic API / OpenAI API / LMStudio をラップし、ノートブック上で LLM 問い合わせ・コード生成・評価・ドキュメント生成・パッケージ管理を行う Wolfram Language パッケージ。

## グローバル変数

### $ClaudeModel
型: {provider_String, model_String} | String, 初期値: {"claudecode", "claude-opus-4-7"}
Claude CLI / API に渡すプロバイダとモデル名の tuple。provider は "claudecode" | "chatgptcodex" | "anthropic" | "openai" | "lmstudio"。

### $ClaudePrivateModel
型: {provider, model, url?}, 初期値: 未設定
AutoPrivate -> True 時に秘密変数を含むタスクで使用するローカルモデル指定。
例: `$ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}`

### $ClaudeTestModel
型: String | tuple, 初期値: $ClaudeModel
ClaudeCheckSeparation 用の検証モデル。

### $ClaudeTimeout
型: Integer, 初期値: 1200
ClaudeQuery/ClaudeEval のタイムアウト秒数。

### $ClaudeVerbose
型: True | False, 初期値: False
True で詳細ログを Messages に出力。

### $ClaudeMDPath
型: String, 初期値: ""
読み込み済み CLAUDE.md のパス。

### $ClaudeMDContent
型: String, 初期値: ""
読み込み済み CLAUDE.md の内容。

### $ClaudeWorkingDirectory
型: String, 初期値: `FileNameJoin[{$HomeDirectory, "Claude Working"}]`
Claude Code を起動する作業ディレクトリ。配下の .claude/CLAUDE.md, .claude/rules/, .claude/skills/ が CLI に読まれる。

### $ClaudeAccessibleDirs
型: List of String, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。

### $ClaudeSnapshots
型: String, 初期値: `FileNameJoin[{$ClaudeWorkingDirectory, "snapshots"}]`
LLMGraphDAG スナップショットの保存先。

### $ClaudeFallbackModels
型: List, 初期値: `{{"anthropic", $iModelOpus}, {"openai", "gpt-5.5"}}`
フォールバックモデル優先順位。要素は {provider, modelName} または {provider, modelName, url}。設定時に NBAccess`NBSetFallbackModels に同期される。

### $ClaudeDocRetryDelay
型: Numeric, 初期値: 60
ドキュメント生成のリトライ待機秒。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
ドキュメント生成の最大リトライ回数。

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースの最大文字数。

### $ClaudeDocModel
型: tuple, 初期値: $iModelSonnet
ドキュメント生成に使うモデル。

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval の再帰深度上限。0 で再帰禁止。

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
外部パッケージのキーワード登録。プロンプトに該当ワードが含まれると当該パッケージの api.md がコンテキスト注入される。
例: `$ClaudePackageKeywordMap["maildb"] = {"メール","mail"}`

### $ClaudeRoutingProviders
型: List
$ClaudeModel が Automatic のときルーティング候補となるプロバイダ。

### $UseClaudeRuntime
型: True | False
ClaudeRuntime 経由実行を有効化する。

### $ClaudeLastRuntimeId
型: String
直近で作成されたランタイム ID。

### $ClaudeRuntimeAsyncExecution
型: True | False
ランタイムのコード実行を ParallelSubmit で非同期化する。

### $ClaudeRuntimeAsyncForce
型: True | False
非同期実行を強制。

### $ClaudeRuntimeAsyncSuppressInputEval
型: True | False
非同期実行時に入力セル評価を抑制。

### $ClaudeEvalMode
ClaudeEval の評価モード。

### $ClaudeEvalHook
ClaudeEval 実行前後フック。

### $ClaudeEvalAutoThreshold
型: Numeric
ClaudeEval 自動切替の閾値。

### $ClaudeEvalVerbose
型: True | False
ClaudeEval の詳細ログ。

### $ClaudeEvalAutoLLMMinLength
型: Integer
自然言語ディスパッチで LLM 呼び出しに切替える最小文字数。

### $ClaudeEvalAutoLLMMinNewlines
型: Integer
自然言語ディスパッチで LLM 呼び出しに切替える最小改行数。

### $ClaudeEvalNaturalDispatch
型: True | False
自然言語ディスパッチの有効化。

### $ClaudeEvalNaturalVerbose
型: True | False
自然言語ディスパッチの詳細ログ。

### $claudecodeVersion
型: String
パッケージバージョン。

### $LLMGraphMaxConcurrency
型: Integer
LLMGraph 実行の最大並列数。

### $LLMGraphAutoStopThreshold
型: Numeric
LLMGraph 自動停止の閾値。

### $ClaudePriorityModeUntil
型: AbsoluteTime
ClaudeBeginHighPriority の有効期限。

### $iMediaMaxImageSize
型: Integer
マルチモーダル送信時の画像最大サイズ。

### $ClaudeEditModesVersion
編集モード機能のバージョン。

### $ClaudeEditModeAppendTagOpen / $ClaudeEditModeAppendTagClose / $ClaudeEditModeInsertTagClose
型: String
編集モードレスポンスのタグ。

### $ChatgptCodexExe
型: String
ChatGPT Codex CLI 実行ファイルパス。

### $ChatgptWorkingDirectory
型: String
Codex 作業ディレクトリ。

### $ChatgptAccessibleDirs
型: List
Codex に Read 許可するディレクトリ。

### $ChatgptCodexHomeDirectory
型: String
Codex ホーム。

### $ChatgptCodexPermissionProfile
Codex 権限プロファイル。

### $ChatgptCodexApprovalPolicy
Codex 承認ポリシー。

### $ChatgptCodexModel
型: String | Automatic
Codex 使用モデル。

### $ChatgptCodexHarnessMode
Codex harness モード。

### $ChatgptCodexRetainTempProjects
型: True | False
一時プロジェクトを保持。

### $ChatgptCodexSourceExposureMode
Codex へのソース露出モード。

### $ClaudeCLIHarnessMode
Claude CLI harness モード。

## クエリ系関数

### ClaudeQuery[prompt, opts]
Claude Code に prompt を送り、応答文字列を返す（同期）。`ClaudeQuery[session, prompt]` でセッション履歴を考慮。`ClaudeQuery[{text, Image[...], File[...], ...}]` でマルチモーダル入力。
→ String
Options: WebSearch -> True (無料), WebFetch -> False (課金, Fallback->True 必須), Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic, AutoPrivate -> False

### ClaudeQuerySync[prompt, opts]
同期問い合わせ。WindowStatusArea に経過秒を表示、履歴・ノート書き込みなし。
→ String
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic
例: `ClaudeQuerySync[prompt, Model -> {"anthropic","claude-sonnet-4-6"}]`

### ClaudeQueryBg[prompt, opts]
FrontEnd 操作・ScheduledTask 生成なしで同期問い合わせ。SocketListen ハンドラや ScheduledTask コールバックから安全に呼べる。
→ String
Options: Fallback -> False, Model -> Automatic, Timeout -> Automatic, NonBlocking -> False

### ClaudeQueryAsync[prompt, callback, nb, opts]
非同期に問い合わせ、完了時に `callback[応答文字列]` を呼ぶ。
→ JobId
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic
例: `ClaudeQueryAsync["Hello", Print, EvaluationNotebook[]]`

### ClaudeQueryAsyncSilent[prompt, callback, nb, opts]
進捗・ステータス表示を抑制した非同期問い合わせ。

### ClaudeEnsureSilentNotebook[nb] → Null
nb をサイレント実行用に設定。

### ClaudeWriteResponse[nb, text, opts] → Null
マークダウン応答をノートブックにスタイル別セルとして展開。
Options: AutoEvaluate -> False

### ClaudeMath[task, opts] → String
Mathematica コード生成特化プロンプトで Claude を呼ぶ。

### ClaudeExtractCode[response] → String
最初の ```mathematica ブロックを抽出。

### ClaudeExtractAllCode[response] → List of String
すべての ```mathematica ブロックを抽出。

### ClaudeSpec[task, opts] → String
`ClaudeSpec["task"]` / `ClaudeSpec[{"task", image, ...}]` でノートブック内容から仕様を生成。

### ClaudeDebug[expr, opts]
エラーを Claude にデバッグさせる。

### ClaudeReview[target, opts]
コードレビュー。

### ClaudeReviewChunked[target, opts]
分割してレビュー（大規模対応）。

## 評価・継続系関数

### ClaudeEval[task, opts]
コードを非同期で生成・表示し、セッションに履歴保存。`ClaudeEval[{text, data, ...}]` でテキスト＋データ。
→ Null (副作用)
Options: Fallback -> False, Model -> Automatic, AutoPrivate -> False, PrivacyLevel -> Automatic, AutoEvaluate -> False, Timeout -> Automatic
注意: 課金プロバイダ (anthropic/openai) 指定時はノートブックの「課金API許可」フラグが必要。

### ContinueEval[opts]
直前の ClaudeEval を継続。
→ Null

### ContinueUpdate[opts]
直前出力を更新。
→ Null

## セッション管理

### CreateClaudeSession[name_String, opts] → SessionId
新規セッション作成。
Options: Inherit -> None (継承元セッション), Model -> Automatic

### ClaudeRestoreSession[name] → Null
セッション復元。

### ClaudeListSessions[] → List
全セッション名を返す。

### ClaudeDeleteSession[name] → Null
セッション削除。

### ClaudeShowHistory[session] → Null
履歴をノートブックに表示。

### ClaudeSessionStatus[session] → Association
セッション状態。

### ClaudeCompactHistory[session] → Null
履歴を圧縮。

### ClaudeHistorySize[session] → Integer
履歴の文字数/件数。

## 添付ファイル

### ClaudeAttach[spec] → Null
ファイル・URL を添付。

### ClaudeDetach[spec] → Null
添付解除。

### ClaudeAttachments[] → List
現在の添付一覧。

### ClearAttachments[] → Null
全添付解除。

## 機密データ

### MarkConfidential[var] → Null
変数を機密マーク。

### UnmarkConfidential[var] → Null
機密解除。

### IsConfidential[var] → True | False
機密判定。

### Confidential[expr] → Confidential[expr]
値を機密ラップ。

### NonConfidential[expr] → expr
機密ラップ解除。

### ScanConfidentialCells[nb] → List
ノート内機密セル走査。

## レート制限

### ClaudeRateLimitStatus[] → Association
レート制限状況。

### ClaudeRateLimitClear[] → Null
制限状態クリア。

## Web ツール

### ClaudeWebSearch[query, opts] → String
Web 検索。

### ClaudeWebFetch[url, opts] → String
URL を取得して要約。

### WebFetch[url, opts] → String
ClaudeWebFetch エイリアス。

### WebSearch[query, opts] → String
ClaudeWebSearch エイリアス。

## ディレクティブ管理

### ClaudeAddDirective[type, name, body, opts] → Null
rules/ または skills/ にディレクティブ追加。

### ClaudeRestoreDirective[name] → Null
バックアップから復元。

### ClaudeListDirectives[] → List
ディレクティブ一覧。

### ClaudeUpdateDirective[name, opts] → Null
既存ディレクティブを更新。

### ClaudeDirectiveBackupDataset[] → Dataset
バックアップ履歴。

### ClaudeSyncDirectives[opts] → Null
ローカルとリモートを同期。

## ドキュメント生成

### ClaudeCreateDocumentation[packageName, opts]
README.md・api.md・spec.md を生成。
→ Null
Options: References -> {}, Demos -> {}, Disclaimer -> {}, Acknowledgments -> {}, License -> "", Model -> Automatic, Fallback -> False, DryRun -> False

### ClaudeUpdateDocumentation[packageName, opts]
既存ドキュメントを更新。
→ Null
Options: References, Demos, Disclaimer, Acknowledgments, License, Model, Fallback, DryRun, TargetFiles -> All

## パッケージ管理 (ClaudePackageManager 経由)

以下は ClaudePackageManager.wl へ完全移管済みで、claudecode 経由でも alias 呼び出し可能。

### ClaudeBackupDataset[] → Dataset
バックアップ一覧。

### ClaudeMigrateBackupHistory[] → Null
バックアップ履歴を移行。

### ClaudeRestorePackage[name, opts] → Null
パッケージを復元。

### ClaudeUpdatePackageHistory[name] → Dataset
更新履歴。

### ClaudeCreatePackage[name, opts] → Null
新規パッケージ作成。

### ClaudeUpdatePackage[packageName, instruction, opts] → Null
パッケージを LLM 指示で更新。

### ClaudeConvertToPaclet[name, opts] → Null
.wl パッケージを Paclet 形式に変換。

## NotebookLLMGraph

### NotebookLLMGraph[nb] → Graph
ノートブック内 LLM 呼び出しの依存グラフを構築。

### NotebookLLMGraphPlot[nb, opts] → Graphics
グラフ可視化。

### NotebookLLMGraphBuild[nb, opts] → Graph
グラフ再構築。

### NotebookLLMGraphNodes[nb] → List
ノード一覧。

### NotebookLLMGraphValidate[nb] → List
妥当性検証。

### NotebookLLMGraphFetchResponse[node] → String
ノードの応答取得。

### NotebookLLMGraphSubSteps[node] → List
サブステップ取得。

### NotebookLLMGraphFetchL2[node] → Association
L2 メタ取得。

### NotebookLLMGraphErrors[nb] → List
エラー一覧。

### NotebookLLMGraphUpdateL2Status[node, status] → Null
L2 ステータス更新。

### NotebookLLMGraphPlotL2[nb] → Graphics
L2 グラフ可視化。

### NotebookLLMGraphRerun[node, opts] → Null
ノード再実行。

### NotebookLLMGraphInvalidateDownstream[node] → Null
下流ノード無効化。

### NotebookLLMGraphSummary[nb] → Dataset
要約。

### NotebookLLMGraphExtractThread[nb] → List
スレッド抽出。

### NotebookLLMGraphApplyThread[nb, thread] → Null
スレッド適用。

## LLMGraph 実行

### LLMGraphExecute[graph, opts] → JobId
グラフ実行。

### LLMGraphExecuteStatus[jobId] → Association
実行状態。

### LLMGraphExecuteCancel[jobId] → Null
実行キャンセル。

### LLMGraphDAGCreate[spec, opts] → DAGId
DAG 作成。

### LLMGraphDAGStatus[id] → Association
DAG 状態。

### LLMGraphDAGCancel[id] → Null
キャンセル。

### LLMGraphDAGStop[id] → Null
停止。

### LLMGraphDAGRetry[id, nodeId, opts] → Null
リトライ。

### LLMGraphDAGRebuild[id] → Null
再構築。

### LLMGraphDAGFindByContext[ctx] → DAGId
コンテキストから DAG 検索。

### LLMGraphDAGInspect[id] → Association
詳細取得。

### LLMGraphDAGMarkFailed[id, nodeId] → Null
失敗マーク。

### LLMGraphDAGSnapshot[id, opts] → SnapshotId
スナップショット保存。

### LLMGraphDAGRestore[snapshotId] → DAGId
スナップショットから復元。

### LLMGraphDAGListSnapshots[] → List
スナップショット一覧。

### LLMGraphDAGPlot[id] → Graphics
DAG 可視化。

### LLMGraphDAGMergeHistory[id, otherId] → Null
履歴マージ。

## ランタイム

### ClaudeBuildRuntimeAdapter[opts] → Adapter
ランタイムアダプタ構築。
Options: ExecutionTimeoutSeconds -> 30 (DefaultTimeoutSeconds キーで保持される)

### ClaudeStartRuntime[opts] → RuntimeId
ランタイム起動。

### ClaudeEvalViaRuntime[runtimeId, task, opts] → Null
ランタイム経由で評価。

### ClaudeApproveProposal[proposalId] → Null
提案を承認。LLM 応答中の `expectedSeconds: N` 等は `proposal["ExpectedSeconds"]` に記録され、TimeConstraint として優先される。

### ClaudeRuntimeSnapshot[runtimeId] → SnapshotId
ランタイムスナップショット。

### ClaudeRuntimeRestore[snapshotId] → RuntimeId
スナップショット復元。

### ClaudeRuntimeListSnapshots[] → List
スナップショット一覧。

### ClaudeRegisterDAGRuntime[runtimeId, dagId] → Null
DAG にランタイムを紐付け。

### ClaudeBuildTransactionAdapter[opts] → Adapter
（ClaudePackageManager に移管）

### ClaudeUpdatePackageViaRuntime[runtimeId, name, instr, opts] → Null
（ClaudePackageManager に移管）

## ファイル・ノートブック処理

### NBFileTranslate[file, opts] → File
ノートブック・スクリプトを変換。

### ClaudeProcessFile[file, instruction, opts] → Null
ファイルを LLM 指示で処理。

## ポーリング・優先度

### ClaudeRegisterPollingTick[key, fn] → Null
共有ポーリングタスクに tick 関数登録。

### ClaudeUnregisterPollingTick[key] → Null
解除。

### ClaudePollingTickKeys[] → List
登録キー一覧。

### ClaudeBeginHighPriority[duration] → Null
$ClaudePriorityModeUntil を更新し優先モード開始。

### ClaudeEndHighPriority[] → Null
優先モード終了。

### ClaudeBeginParallelKernels[opts] → Null
ParallelKernels を事前起動。

## クラウド送信プリフライト

### ClaudeCloudSendPreflightDecision[context] → "allow" | "deny" | "warn"
送信可否判定。

### ClaudeCloudSendPreflightError[context] → Failure
失敗値を返す。

### ClaudeCloudSendPreflightFailure[context] → Failure
失敗構造。

### ClaudeCloudSendPreflightFailureCell[context] → Cell
失敗説明セル。

### ClaudeCloudSendPreflightGuardDryRun[context] → Association
ドライラン結果。

### ClaudeCloudSendPreflightAudit[context] → Association
監査結果。

### ClaudeCloudSendPreflightLog[] → List
ログ取得。

### ClaudeCloudSendPreflightLogClear[] → Null
ログクリア。

### ClaudeCloudSendPreflightLogSummary[] → Association
ログ要約。

### ClaudeCloudSendPreflightLogDataset[] → Dataset
ログを Dataset で取得。

### $ClaudeCloudSendPreflightLog
型: List, ログ実体。

### $ClaudeCloudSendPreflightLogMaxLength
型: Integer, 最大保持件数。

### $ClaudeCloudSendPreflightContextResolver
型: Function, コンテキスト解決関数。

### $ClaudeCloudSendPreflightLogFile
型: String, ログファイルパス。

### $ClaudeCloudSendRoutePolicy
型: Association, ルーティングポリシー。

## コミット支援

### ClaudePrepareCommit[opts] → Null
変更要約からコミットメッセージ案を生成。

## 編集モード

### ClaudeAppendBlockToPackage[packagePath, block, opts] → Null
パッケージ末尾にブロック追記。

### ClaudeInsertBeforeAnchorInPackage[packagePath, anchor, block, opts] → Null
アンカー直前に挿入。

### ClaudeParseEditModeResponse[response] → Association
LLM 応答から編集モード指示を抽出。タグは `$ClaudeEditModeAppendTagOpen`/`Close`、`$ClaudeEditModeInsertTagClose`。

### ClaudeAutoDetectEditMode[response] → String
編集モード自動判定。

### ClaudeBuildEditModePromptInstructions[mode] → String
編集モード用プロンプト断片を生成。

### ClaudeUpdatePackageWithMode[packageName, instruction, mode, opts] → Null
編集モード指定でパッケージ更新。

## コマンド・ステータス

### ClaudeCommand[cmd, opts] → String
任意 Claude Code CLI コマンド実行。

### ClaudeCheckSeparation[opts] → Association
パッケージ分離状態を検証。

### ClaudeFixSeparation[opts] → Null
分離問題を修正。

### ClaudeStatus[] → Association
全体状態取得。

### ClaudeAbort[] → Null
進行中ジョブを中断。

### ClaudeQueryShowContext[] → Null
次回送信されるコンテキストを表示。

### ClaudeShowAccessConfig[] → Null
アクセス権限設定を表示。

### ShowClaudePalette[] → Null
パレットウィンドウ表示。

## ユーティリティ

### cleanOutput[text] → String
出力を整形。

### stripANSI[text] → String
ANSI エスケープ除去。

## オプションシンボル

| シンボル | 用途 |
|---|---|
| Fallback | True で利用不可時にフォールバックモデルへ自動切替 |
| AutoPrivate | True で秘密変数アクセス時に $ClaudePrivateModel + PrivacySpec -> Automatic を付与 |
| AutoEvaluate | True で生成セルを自動評価 |
| StartTime | 開始時刻 |
| Timeout | 秒数。Automatic で $ClaudeTimeout |
| TargetFiles | 対象ファイル指定 |
| TargetFunctions | 対象関数指定 |
| Mode | 動作モード |
| DryRun | True で実行せず計画のみ |
| Inherit | 継承元 |
| License | ライセンス文字列。"" で自動 MIT |
| Model | プロバイダ/モデル指定 |
| WebFetch | True で Web 取得有効化（課金） |
| WebSearch | True で Web 検索有効化（無料、既定 True） |
| RepeatInterval | 反復間隔 |
| PrivacySpec | プライバシ仕様。Automatic で自動 |
| Keywords | キーワード |
| Title | タイトル |
| Refetch | True で再取得 |
| Owner | GitHub オーナー |
| Repository | リポジトリ名 |
| Branch | ブランチ |
| BaseBranch | ベースブランチ |
| References | 参考文献リスト |
| Demos | デモ URL リスト |
| Disclaimer | 免責文言 |
| Acknowledgments | 謝辞文言 |

## モデル指定パターン

```
Model -> Automatic                                  (* 既定: PrivacyLevel に応じて claudecode / private *)
Model -> {"claudecode", "claude-opus-4-7"}          (* Claude Code CLI (Pro/Max 内、課金なし) *)
Model -> {"anthropic", "claude-sonnet-4-6"}         (* Anthropic API 直接 (課金、要許可) *)
Model -> {"openai", "gpt-5.5"}                      (* OpenAI API (課金、要許可) *)
Model -> {"lmstudio", "gpt-oss-20b", "http://127.0.0.1:1234"}  (* ローカル *)
Model -> {"chatgptcodex", "Automatic"}              (* ChatGPT Codex CLI *)
```

## プロバイダ別 課金/許可

- claudecode / chatgptcodex: CLI 経由、サブスクリプション内で課金なし
- anthropic / openai: 課金、ノートブック TaggingRules の `paidAPIAllowed -> True` 必須（パレット「課金API許可」or `NBAccess`NBSetNotebookPaidAPIAllowed`）
- lmstudio: ローカル、課金なし

## マルチモーダル

`{text, Image[...], File[path], ...}` 形式の入力は `ClaudeQuery` / `ClaudeQueryBg[..., NonBlocking -> True]` で claudecode プロバイダでも処理可（画像は tmp PNG に書き出し、CLI にファイル参照として渡す）。

## 非同期動作の原則

- ScheduledTask / SocketListen ハンドラ等の非同期コンテキストからは `ClaudeQueryBg` を使用（FrontEnd 操作・ScheduledTask 生成を行わない）。
- `ClaudeQuery`/`ClaudeEval` は内部で非同期パスに振り分けるが、フロントエンドブロックを避けるよう実装される。