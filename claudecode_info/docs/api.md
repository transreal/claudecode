# claudecode API リファレンス

ClaudeCode` パッケージ。Wolfram Language から Claude Code CLI / 各種 LLM プロバイダを呼び出し、ノートブック上でクエリ・コード生成・実行・ドキュメント生成・パッケージ管理を行う。BeginPackage["ClaudeCode`"]。依存: NBAccess (https://github.com/transreal/NBAccess), GitHubREST (https://github.com/transreal/github)。

プロバイダ概念: provider は "claudecode"(Anthropic CLI, Pro/Max サブスク内・課金なし), "chatgptcodex"(ChatGPT Codex CLI, 課金なし), "anthropic"(Anthropic API 直接・課金), "openai"(OpenAI API・課金), "lmstudio"(ローカル LLM・課金なし)。$ClaudeModel は {provider, model} の tuple。

## クエリ実行

### ClaudeQuery[prompt, opts]
Claude にプロンプトを送り応答を取得しノートブックに書き出す主関数。
→ String / NotebookObject 書き出し
Options: Fallback -> False, Model -> Automatic, AutoPrivate -> False, PrivacySpec -> Automatic, Timeout -> Automatic, Integrations -> Automatic, WebSearch, WebFetch

### ClaudeQuerySync[prompt, opts]
Claude に prompt を同期送信し応答文字列を返す。WindowStatusArea に経過時間表示。セッション履歴・ノートブック書き込みなしの軽量版。
→ String
Options: Fallback -> False (CLI 不可時フォールバック), Model -> Automatic ({"provider","model"} 指定可), PrivacyLevel -> Automatic (<0.5 で CLI, >0.5 で $ClaudePrivateModel 自動使用), Timeout -> Automatic
例: ClaudeQuerySync["Hello"]
例: ClaudeQuerySync[prompt, Model -> {"anthropic", "claude-sonnet-4-6"}]

### ClaudeQueryBg[prompt, opts]
FrontEnd 操作・ScheduledTask 生成なしで同期問い合わせ。SocketListen ハンドラや ScheduledTask コールバック等の非同期コンテキストから安全に呼べる（rule 95 準拠の URLRead 代替）。マルチモーダル入力 {prompt, img} 可。
→ String
Options: Fallback -> False, Model -> Automatic, Timeout -> Automatic, NonBlocking -> False
例: ClaudeQueryBg["Hello"]
例: ClaudeQueryBg[{prompt, img}, NonBlocking -> True, Timeout -> 120]

### ClaudeQueryAsync[prompt, opts]
非同期にクエリを発行し進捗表示しながらノートブックへ応答を書き込む。
Options: Fallback, Model, Integrations, Timeout

### ClaudeQueryAsyncSilent[prompt, opts]
進捗表示を抑制した非同期クエリ。

### ClaudeQueryShowContext[prompt] → 表示
クエリに付与されるコンテキスト（CLAUDE.md・アクセス可能ディレクトリ・ファイル一覧等）をプレビュー表示する。

### ClaudeEnsureSilentNotebook[] → NotebookObject
バックグラウンド出力用のサイレントノートブックを確保する。

### ClaudeWriteResponse[nb, text] → セル展開
マークダウン形式テキストをノートブックのセルとして展開する。見出し・リスト・コードブロック等を適切なセルスタイルに変換。

### ClaudeMath[prompt] → 結果
数式・数学タスク向けのクエリラッパー。

## コード抽出・評価

### ClaudeExtractCode[text] → String
LLM 応答から最初のコードブロックを抽出する。

### ClaudeExtractAllCode[text] → {String..}
応答中の全コードブロックを抽出する。

### ClaudeEval[prompt, opts]
自然言語タスクからコードを生成し評価する。$ClaudeModel/Model が課金プロバイダ {anthropic|openai,...} の場合は NBAccess の課金API許可をチェックし、未許可なら明示エラーで停止 (iClaudePaidModelGuard)。再帰生成は $ClaudeEvalMaxDepth まで。
→ 評価結果
Options: Fallback, Model, AutoPrivate, AutoEvaluate, PrivacySpec, Timeout

### ContinueEval[prompt, opts]
直前の ClaudeEval 結果・コンテキストを引き継いで継続的にコード生成・評価する。秘密変数の構造調査と連携可。

### ContinueUpdate[prompt, opts]
直前の生成結果を更新指示で改変する。

### ClaudeSpec[task]
ノートブック内容からプログラム仕様を生成する。ClaudeSpec[{task, image, ...}] で画像付き生成。パレットからセル選択で呼び出し可能。
→ 仕様テキスト

### ClaudeDebug[prompt, opts]
コードのデバッグ・エラー解析を行う。

### ClaudeReview[prompt, opts]
コードレビューを行う。

### ClaudeReviewChunked[prompt, opts]
大規模コードをチャンク分割してレビューする。

## セッション管理

### CreateClaudeSession[name, opts] → セッション
新規 Claude セッションを作成する。
Options: Inherit (親セッション継承)

### ClaudeRestoreSession[name] → セッション
保存済みセッションを復元する。

### ClaudeListSessions[] → {...}
セッション一覧を返す。

### ClaudeDeleteSession[name] → 削除
セッションを削除する。

### ClaudeShowHistory[] → 表示
セッション履歴を表示する。

### ClaudeSessionStatus[] → Association
現在のセッション状態を返す。

### ClaudeCompactHistory[] → 圧縮
セッション履歴をコンパクト化する。

### ClaudeHistorySize[] → Integer
履歴サイズを返す。

### Inherit
CreateClaudeSession のオプション。親セッションのコンテキストを継承する。

## 添付ファイル

### ClaudeAttach[spec, opts]
ファイル・URL を現在のクエリコンテキストに添付する。URL はキャッシュされる。
Options: Keywords, Title, Refetch

### ClaudeDetach[spec] → 解除
添付を解除する。

### ClaudeAttachments[] → {...}
現在の添付一覧を返す。

### ClearAttachments[] → クリア
全添付を解除する。

## 機密データ

### MarkConfidential[var] → マーク
変数を機密として登録する。

### UnmarkConfidential[var] → 解除
機密マークを解除する。

### IsConfidential[var] → Bool
機密判定を返す。

### Confidential[expr]
式を機密としてラップするヘッド。

### NonConfidential[expr]
機密解除（明示的に非機密化）するヘッド。

### ScanConfidentialCells[] → {...}
ノートブック内の機密セルを走査する。

## ディレクティブ管理

### ClaudeAddDirective[spec] → 追加
CLAUDE.md / rules / skills 等のディレクティブを追加する。

### ClaudeUpdateDirective[name, instruction] → 更新
既存ディレクティブを更新する。

### ClaudeRestoreDirective[name] → 復元
ディレクティブをバックアップから復元する。

### ClaudeListDirectives[] → {...}
ディレクティブ一覧を返す。

### ClaudeDirectiveBackupDataset[] → Dataset
ディレクティブのバックアップ履歴を Dataset で返す。

### ClaudeSyncDirectives[] → 同期
ディレクティブを同期する。

## ドキュメント生成

### ClaudeCreateDocumentation[package, opts]
パッケージの包括的ドキュメント一式を生成する。リミット到達で自動停止、再実行で未生成分のみ続行。README.md は最後に生成。
Options: References -> {} (URL/書籍名→README 参考文献), Demos -> {} (デモ URL), Disclaimer -> {} (免責文言), License -> "" (空で GitHub ライセンスホルダーから MIT 自動挿入), Acknowledgments -> {} (謝辞), Model -> $ClaudeDocModel

### ClaudeUpdateDocumentation[package, instruction, opts]
既存ドキュメントを部分更新する。
Options: References, Demos, Disclaimer, License, Acknowledgments, Model

## Web 検索・取得

### ClaudeWebSearch[query] / WebSearch[query] → 結果
Web 検索を行う。

### ClaudeWebFetch[url] / WebFetch[url] → 内容
URL を取得する（フォールバック付き解決）。

## パッケージ操作（ClaudePackageManager.wl へ移管、alias 経由で呼出可）

以下は ClaudePackageManager (https://github.com/transreal/ClaudePackageManager) へ完全移管済み。claudecode 経由でも互換的に呼び出せる。
### ClaudeCreatePackage[name, spec] — 新規パッケージ作成
### ClaudeUpdatePackage[name, instruction] — 差分更新・バックアップ・検証・再ロードを自動実行
### ClaudeRestorePackage[name] — バックアップ復元
### ClaudeUpdatePackageHistory[name] — 更新履歴
### ClaudeConvertToPaclet[name] — Paclet 変換
### ClaudeBackupDataset[] — バックアップ Dataset
### ClaudeMigrateBackupHistory[] — バックアップ履歴移行
### ClaudeBuildTransactionAdapter[...] — トランザクションアダプタ
### ClaudeUpdatePackageViaRuntime[...] — ランタイム経由更新

### ClaudeUpdatePackageWithMode[name, instruction, mode]
編集モード（追記/挿入/全置換）を指定してパッケージ更新する。

## 編集モード

### $ClaudeEditModesVersion
型: String。編集モード機能のバージョン。

### $ClaudeEditModeAppendTagOpen / $ClaudeEditModeAppendTagClose / $ClaudeEditModeInsertTagClose
型: String。編集モード応答のタグマーカー。

### ClaudeAppendBlockToPackage[name, block] → 追記
パッケージ末尾にブロックを追記する。

### ClaudeInsertBeforeAnchorInPackage[name, anchor, block] → 挿入
アンカー直前にブロックを挿入する。

### ClaudeParseEditModeResponse[text] → 構造
LLM の編集モード応答をパースする。

### ClaudeAutoDetectEditMode[text] → mode
応答内容から編集モードを自動判定する。

### ClaudeBuildEditModePromptInstructions[mode] → String
編集モード用のプロンプト指示文を生成する。

## NBAccess 分離原則検証

### ClaudeCheckSeparation[package] → 結果
NBAccess 分離原則違反を検査する。$NBSeparationIgnoreList 登録パッケージ(NBAccess, NotebookExtensions)は対象外。結果はキャッシュされ ClaudeFixSeparation で再利用。

### ClaudeFixSeparation[package] → 修正
検出された分離違反を修正する。

## ファイル処理

### NBFileTranslate[spec] → 変換
NBFile 仕様の変換を行う。

### ClaudeProcessFile[file, opts]
ファイルを Claude で処理する。

## ステータス・制御

### ClaudeStatus[] → 表示
現在の実行状態を表示する。

### ClaudeAbort[] → 中断
進行中のクエリを中断する。

### ClaudeShowAccessConfig[] → 表示
アクセス許可設定（アクセス可能ディレクトリ等）を表示する。

### ClaudeRateLimitStatus[] → Association
レート制限状況を返す。

### ClaudeRateLimitClear[] → クリア
レート制限カウンタをクリアする。

### ClaudeCommand["/command"] → 結果
Claude Code CLI のスラッシュコマンドを実行する。

### ShowClaudePalette[] → パレット
Claude Code 操作パレットを表示する。Provider ボタン (claudecode→chatgptcodex→anthropic→openai→lmstudio 循環) と Model ボタン (現プロバイダの候補循環) を持つ。

### ClaudePrepareCommit[opts] → コミットメッセージ
変更内容を集約し git コミットメッセージを整形生成する。

## ランタイム / タイムアウト制御

### ClaudeBuildRuntimeAdapter[opts] → adapter Association
コード実行ランタイムアダプタを構築する。
Options: "ExecutionTimeoutSeconds" -> 30 (adapter に "DefaultTimeoutSeconds" として保持)

### ClaudeStartRuntime[adapter, opts] → runtimeId
ランタイムを起動する。

### ClaudeEvalViaRuntime[prompt, opts] → 結果
ランタイム経由でコード生成・実行する。タイムアウト優先順: proposal["ExpectedSeconds"] > adapter["DefaultTimeoutSeconds"] > 30。

### ClaudeApproveProposal[id] → 承認
保留中の実行提案を承認する。

### ClaudeRuntimeSnapshot[] → snapshot
ランタイム状態のスナップショットを取る。

### ClaudeRuntimeRestore[snapshot] → 復元
スナップショットから復元する。

### ClaudeRuntimeListSnapshots[] → {...}
スナップショット一覧を返す。

### ClaudeRegisterDAGRuntime[...] → 登録
DAG 実行用ランタイムを登録する。

### ClaudeBeginParallelKernels[] → 起動
ParallelKernels を前置起動する。

### ClaudeBeginHighPriority[] / ClaudeEndHighPriority[]
高優先度モードの開始/終了。$ClaudePriorityModeUntil で期限管理。

### ClaudeRegisterPollingTick[key, fn] / ClaudeUnregisterPollingTick[key] / ClaudePollingTickKeys[]
共有ポーリングタスクへの tick 登録・解除・キー一覧。

## LLM グラフ (NotebookLLMGraph)

### NotebookLLMGraph[opts] → graph
ノートブックから LLM 依存グラフを構築する。

### NotebookLLMGraphBuild[opts] → graph
グラフを構築する。

### NotebookLLMGraphPlot[graph] → Graphics
グラフを可視化する。

### NotebookLLMGraphNodes[graph] → {...}
ノード一覧を返す。

### NotebookLLMGraphValidate[graph] → 検証
グラフを検証する。

### NotebookLLMGraphFetchResponse[node] → String
ノードの応答を取得する。

### NotebookLLMGraphSubSteps[node] → {...}
サブステップを返す。

### NotebookLLMGraphFetchL2[...] → 結果
L2 層の応答取得。

### NotebookLLMGraphErrors[graph] → {...}
エラー一覧を返す。

### NotebookLLMGraphUpdateL2Status[...] → 更新
L2 ステータスを更新する。

### NotebookLLMGraphPlotL2[graph] → Graphics
L2 グラフを可視化する。

### NotebookLLMGraphRerun[node] → 再実行
ノードを再実行する。

### NotebookLLMGraphInvalidateDownstream[node] → 無効化
下流ノードを無効化する。

### NotebookLLMGraphSummary[graph] → Association
グラフの要約を返す。

### NotebookLLMGraphExtractThread[...] → thread
スレッドを抽出する。

### NotebookLLMGraphApplyThread[...] → 適用
スレッドを適用する。

## LLM グラフ実行 / DAG

### LLMGraphExecute[graph, opts] → 実行
グラフを実行する。

### LLMGraphExecuteStatus[] → Association
実行状態を返す。

### LLMGraphExecuteCancel[] → キャンセル
実行をキャンセルする。

### LLMGraphDAGCreate[spec, opts] → dagId
LLM タスク DAG を作成する。

### LLMGraphDAGStatus[dagId] → Association
DAG 状態を返す。

### LLMGraphDAGCancel[dagId] / LLMGraphDAGStop[dagId] → 停止
DAG をキャンセル/停止する。

### LLMGraphDAGRetry[dagId] → 再試行
失敗ノードを再試行する。

### LLMGraphDAGRebuild[dagId] → 再構築
DAG を再構築する。

### LLMGraphDAGFindByContext[ctx] → dagId
コンテキストから DAG を検索する。

### LLMGraphDAGInspect[dagId] → 表示
DAG を詳細表示する。

### LLMGraphDAGMarkFailed[dagId, node] → マーク
ノードを失敗扱いにする。

### LLMGraphDAGSnapshot[dagId] → snapshot
DAG スナップショットを取る。$ClaudeSnapshots に保存。

### LLMGraphDAGRestore[snapshot] → 復元
スナップショットから復元する。

### LLMGraphDAGListSnapshots[] → {...}
スナップショット一覧を返す。

### LLMGraphDAGPlot[dagId] → Graphics
DAG を可視化する。

### LLMGraphDAGMergeHistory[...] → 統合
DAG 履歴を統合する。

公開化された内部 helper (ClaudeCode`X 形式で外部参照可): iLLMGraphGetCached, iSaveNotebookLLMGraph, iNewLLMNode, iNewNotebookLLMGraph, iLLMGraphMergeTwoGraphs, iLLMGraphFlush, iLLMGraphNode, iMakeBat。$iLLMGraphCache, $iLLMGraphCacheNB はキャッシュ変数。

## ユーティリティ

### cleanOutput[text] → String
CLI 出力を整形する。

### stripANSI[text] → String
ANSI エスケープシーケンスを除去する。

## 変数: モデル・プロバイダ

### $ClaudeModel
型: {provider, model} tuple (旧 String も互換), 初期値: {"claudecode","claude-opus-4-7"} 相当
Claude CLI / API に渡すプロバイダとモデル名。provider は claudecode/chatgptcodex/anthropic/openai/lmstudio。

### $ClaudeDocModel
型: tuple, 初期値: $iModelSonnet = {"claudecode","claude-sonnet-4-6"}
ドキュメント生成・更新時のモデル。安価かつ高品質な Sonnet 系。"" で $ClaudeModel と同じ。

### $ClaudePrivateModel
型: {provider, model[, url]}
秘密データ処理用のローカルモデル。AutoPrivate -> True 時に使用。
例: $ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}

### $ClaudeTestModel
型: tuple/String, 初期値: $ClaudeModel と同じ
分離検証用モデル。

### $ClaudeFallbackModels
型: List of {provider, model} or {provider, model, url}, 初期値: {{"chatgptcodex","gpt-5.5"},{"anthropic",{"claudecode","claude-opus-4-7"}},{"openai","gpt-5.5"}}
フォールバックモデル優先順位。NBAccess`NBSetFallbackModels に同期。

### $ClaudeRoutingProviders
型: List。ルーティング対象プロバイダ。

## 変数: タイムアウト・動作

### $ClaudeTimeout
型: Integer(秒), 初期値: 1200
ClaudeQuery・ClaudeEval 等のタイムアウト秒数。

### $ClaudeVerbose
型: Bool, 初期値: False
True で履歴コンパクション等の詳細ログを Messages に出力。

### $ClaudeStandardFont
型: String, 初期値: "Yu Gothic UI"
ClaudeEval 生成コード (Grid/Column/Style/Button 等) で強制使用する標準フォント名。

### $claudecodeVersion
型: String。パッケージバージョン。

## 変数: ディレクトリ・パス

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code 起動の作業ディレクトリ。配下の .claude/CLAUDE.md, rules/, skills/ を読ませる。

### $OpenaiWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "OpenAI Working"}]
OpenAI 用作業ディレクトリ。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリ。NotebookDirectory は初回使用時にダイアログ許可確認。NBSetAccessibleDirs で永続化可。

### $ClaudeSnapshots
型: String, 初期値: $ClaudeWorkingDirectory/snapshots
LLMGraphDAG スナップショット保存ディレクトリ。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス（自動検索または手動上書き）。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。空なら未発見。

### $ClaudePackageKeywordMap
型: Association
外部パッケージがキーワードを登録するための連想。プロンプトにキーワードが含まれると対応パッケージの api.md がコンテキストに自動注入される。各パッケージが自身のロード時に登録。
例: $ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〆切"};

## 変数: ドキュメント生成

### $ClaudeDocRetryDelay
型: Integer, 初期値: 60
ドキュメント生成のリトライ待機秒数。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
最大リトライ回数。

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースの最大文字数。

## 変数: 評価モード

### $ClaudeEvalMode
型。ClaudeEval の動作モード。

### $ClaudeEvalHook
評価時に呼ばれるフック。

### $ClaudeEvalAutoThreshold
自動評価のしきい値。

### $ClaudeEvalVerbose
型: Bool。評価の詳細ログ。

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval が再帰的に ClaudeEval/ContinueEval を生成する最大深度。0 で再帰禁止。

### $ClaudeEvalAutoLLMMinLength / $ClaudeEvalAutoLLMMinNewlines
自動 LLM ディスパッチの最小文字数・最小改行数しきい値。

### $ClaudeEvalNaturalDispatch
型: Bool。自然言語ディスパッチの有効化。

### $ClaudeEvalNaturalVerbose
型: Bool。自然言語ディスパッチの詳細ログ。

### $ClaudeEvalNotebookContext
ノートブックコンテキストの利用設定。

## 変数: ランタイム / 非同期

### $UseClaudeRuntime
型: Bool。ClaudeRuntime 経路を使用するか。

### $ClaudeLastRuntimeId
直近のランタイム ID。

### $ClaudeRuntimeAsyncExecution
型: Bool。コード実行の非同期化 (ParallelSubmit)。

### $ClaudeRuntimeAsyncForce
型: Bool。非同期実行を強制。

### $ClaudeRuntimeAsyncSuppressInputEval
型: Bool。非同期時の入力評価抑制。

## 変数: LLM グラフ

### $LLMGraphMaxConcurrency
型: Integer。同時実行ノード数上限。

### $LLMGraphAutoStopThreshold
型: Integer。自動停止しきい値。

### $iMediaMaxImageSize
型: Integer。マルチモーダル送信時の最大画像サイズ。

## 変数: ChatGPT Codex 連携

### $ChatgptCodexExe
型: String。ChatGPT Codex CLI 実行ファイルパス。

### $ChatgptWorkingDirectory / $ChatgptAccessibleDirs
Codex の作業ディレクトリ・アクセス可能ディレクトリ。

### $ChatgptCodexHomeDirectory
Codex のホームディレクトリ。

### $ChatgptCodexPermissionProfile
Codex の権限プロファイル。

### $ChatgptCodexApprovalPolicy
Codex の承認ポリシー。

### $ChatgptCodexModel
型: String/Automatic。Codex の実モデル ("Automatic" は Symbol Automatic = CLI 既定)。パレットの provider=chatgptcodex 選択時に同期。

### $ChatgptCodexHarnessMode
Codex のハーネスモード。

### $ChatgptCodexRetainTempProjects
型: Bool。一時プロジェクトを保持するか。

### $ChatgptCodexSourceExposureMode
ソース露出モード。

### $ClaudeCLIHarnessMode
Claude CLI のハーネスマテリアライズモード。

## オプションシンボル

主要オプション (各関数の Options で使用):
- Fallback -> False — CLI 不可時にアクセスレベルに応じた利用可能フォールバックモデルへ自動切替
- AutoPrivate -> False — 秘密変数アクセスタスクで Model -> $ClaudePrivateModel, PrivacySpec -> Automatic を自動付与
- AutoEvaluate — 生成コードの自動評価
- Model -> Automatic — {provider, model} 指定
- PrivacySpec -> Automatic — プライバシー仕様
- Timeout -> Automatic — $ClaudeTimeout を使用
- Integrations -> Automatic — lmstudio の MCP サーバ/plugin (例: {"mcp/exa"})
- WebFetch / WebSearch — Web ツール許可
- StartTime / RepeatInterval — スケジュール実行
- TargetFiles / TargetFunctions — 対象ファイル・関数の限定
- Mode — 編集/実行モード
- DryRun — 実行せず計画のみ
- Inherit — セッション継承
- Keywords / Title / Refetch — ClaudeAttach の添付メタ
- License / References / Demos / Disclaimer / Acknowledgments — ドキュメント生成オプション (README.md にのみ反映)
- Owner / Repository / Branch / BaseBranch — GitHub 連携オプション

注: api.md は LLM 用簡潔リファレンスのため、謝辞・免責事項・ライセンスのセクションは含めない（README.md にのみ存在する）。ソースが途中で切り詰められているため、usage 文字列の無い関数の引数・オプションは命名から推定した最小記述であり、正確な引数仕様は実ソースで確認が必要。