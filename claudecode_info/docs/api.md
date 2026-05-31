# claudecode API リファレンス

ClaudeCode` パッケージは Mathematica から Claude Code CLI / 各種 LLM プロバイダを呼び出し、クエリ・コード生成実行・ドキュメント生成・セッション管理・ノートブック LLM グラフ・ランタイム制御を行う。NBAccess`（ノートブック読み書き・プライバシー管理）と GitHubREST` に依存する。

プロバイダモデルは tuple `{provider, model}` で指定する。provider 種別:
- `"claudecode"` — Anthropic Claude Code CLI（Pro/Max サブスク内、課金なし）
- `"chatgptcodex"` — ChatGPT Codex CLI（サブスク内、課金なし）
- `"anthropic"` — Anthropic API 直接（課金）
- `"openai"` — OpenAI API（課金）
- `"lmstudio"` — ローカル LLM（課金なし）

## グローバル変数

### $ClaudeModel
型: tuple {provider, model} または String, 初期値: {"claudecode","claude-opus-4-7"}（パレット同期）
Claude CLI/プロバイダに渡すモデル指定。tuple `{provider,model}` 形式。String 指定時は claudecode 扱い。`""` は CLI 既定モデル。

### $ClaudeStandardFont
型: String, 初期値: "Yu Gothic UI"
ClaudeEval が生成する出力コード（Grid/Column/Style/Button 等）の FontFamily を統一する標準フォント名。ロード後に代入で変更可。

### $ClaudePrivateModel
型: tuple, 初期値: 未設定
秘密データ処理用ローカルモデル。AutoPrivate -> True 時に秘密変数を含むタスクの生成コードに使用。例: `{"lmstudio","openai/gpt-oss-20b","http://127.0.0.1:1234"}`

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
外部パッケージがキーワードを登録する。プロンプトにキーワードが含まれると対応パッケージの api.md がコンテキストに自動注入される。例: `$ClaudePackageKeywordMap["maildb"] = {"メール","mail","〆切"};`

### $ClaudeTimeout
型: Integer, 初期値: 1200
ClaudeQuery・ClaudeEval 等のタイムアウト秒数。

### $ClaudeVerbose
型: Boolean, 初期値: False
True で履歴コンパクション等の詳細ログを Messages に出力。False で重大エラー以外を抑制。

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory,"Claude Working"}]
Claude Code の作業ディレクトリ。配下の .claude/CLAUDE.md, .claude/rules/, .claude/skills/ を読ませる。

### $OpenaiWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory,"OpenAI Working"}]
OpenAI/Codex 系の作業ディレクトリ。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索または手動上書き。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。空なら未検出。

### $ClaudeSnapshots
型: String, 初期値: $ClaudeWorkingDirectory/snapshots
LLMGraphDAG スナップショット保存ディレクトリ。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。一時 settings.json に注入。NotebookDirectory は初回使用時にダイアログで許可確認。

### $ClaudeFallbackModels
型: List, 初期値: {{"anthropic",<opus>},{"openai","gpt-5.5"}}
フォールバックモデル優先順位。各要素 `{provider,model}` または `{provider,model,url}`。NBAccess`NBSetFallbackModels に同期される。

### $ClaudeDocRetryDelay
型: Integer, 初期値: 60
ドキュメント生成のリトライ待機秒数。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
ドキュメント生成の最大リトライ回数。

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースの最大文字数（チャンク分割閾値）。

### $ClaudeDocModel
型: tuple/String, 初期値: Sonnet 系最新
ドキュメント生成・更新に使用するモデル。`""` で $ClaudeModel と同じ。

### $ClaudeTestModel
型: tuple/String, 初期値: $ClaudeModel
分離検証用モデル。

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval が再帰的に ClaudeEval/ContinueEval を生成する最大深度。0 で再帰禁止。

### $ClaudeEvalMode
型: 設定値
ClaudeEval の動作モード。

### $ClaudeEvalHook
ClaudeEval 実行時に呼ばれるフック。

### $ClaudeEvalAutoThreshold
ClaudeEval が自動 LLM 呼び出しに切替える閾値。

### $ClaudeEvalVerbose
型: Boolean
ClaudeEval の詳細ログ出力フラグ。

### $ClaudeEvalAutoLLMMinLength
自動 LLM ディスパッチの最小文字数閾値。

### $ClaudeEvalAutoLLMMinNewlines
自動 LLM ディスパッチの最小改行数閾値。

### $ClaudeEvalNaturalDispatch
型: Boolean
自然言語入力の自動ディスパッチ有効化フラグ。

### $ClaudeEvalNaturalVerbose
型: Boolean
自然言語ディスパッチの詳細ログフラグ。

### $claudecodeVersion
型: String
パッケージバージョン文字列。

### $ClaudeRoutingProviders
型: List
ルーティング対象プロバイダリスト。

### $UseClaudeRuntime
型: Boolean
ランタイム経路を使うかのフラグ。

### $ClaudeLastRuntimeId
型: String
直近起動したランタイム ID。

### $ClaudeRuntimeAsyncExecution
型: Boolean
ランタイムのコード実行を ParallelSubmit で非同期化するフラグ。

### $ClaudeRuntimeAsyncForce
型: Boolean
非同期実行を強制するフラグ。

### $ClaudeRuntimeAsyncSuppressInputEval
型: Boolean
非同期実行時の入力セル評価抑制フラグ。

### $LLMGraphMaxConcurrency
型: Integer
LLMGraph の最大並列数。

### $LLMGraphAutoStopThreshold
型: Integer
LLMGraph 自動停止閾値。

### $iMediaMaxImageSize
型: Integer
マルチモーダル送信時の画像最大サイズ。

### $ClaudeEditModesVersion
型: String
編集モード機能のバージョン。

### $ClaudeEditModeAppendTagOpen / $ClaudeEditModeAppendTagClose / $ClaudeEditModeInsertTagClose
型: String
編集モード応答パース用のタグ文字列（追記開始/追記終了/挿入終了）。

### $ClaudeCLIHarnessMode
型: 設定値
Claude CLI ハーネスのマテリアライズモード。

### $ChatgptCodexExe
型: String
ChatGPT Codex CLI 実行ファイルパス。

### $ChatgptWorkingDirectory / $ChatgptAccessibleDirs
型: String / List
Codex の作業ディレクトリとアクセス可能ディレクトリ。

### $ChatgptCodexHomeDirectory
型: String
Codex ホームディレクトリ。

### $ChatgptCodexPermissionProfile
型: String
Codex 権限プロファイル。

### $ChatgptCodexApprovalPolicy
型: String
Codex 承認ポリシー。

### $ChatgptCodexModel
型: String/Automatic
Codex 実モデル。パレットの "Automatic" は Symbol Automatic（CLI 既定）。

### $ChatgptCodexHarnessMode
型: 設定値
Codex ハーネスモード。

### $ChatgptCodexRetainTempProjects
型: Boolean
Codex 一時プロジェクト保持フラグ。

### $ChatgptCodexSourceExposureMode
型: 設定値
Codex へのソース露出モード。

## クエリ

### ClaudeQuery[prompt, opts]
Claude に prompt を送り応答を得る基本関数。
→ String
Options: Fallback -> False, Model -> Automatic, AutoPrivate -> False, Timeout -> Automatic, PrivacySpec, WebSearch, WebFetch

### ClaudeQuerySync[prompt, opts]
prompt を同期送信し応答文字列を返す。WindowStatusArea に経過時間表示。履歴・ノートブック書き込みなしの軽量版。
→ String
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic
モデルルーティング: Model -> Automatic かつ PrivacyLevel < 0.5 で claudecode CLI、> 0.5 で $ClaudePrivateModel 自動使用。Model -> {provider,model} で API 経由。
例: ClaudeQuerySync[prompt, Model -> {"anthropic","claude-sonnet-4-6"}]

### ClaudeQueryBg[prompt, opts]
FrontEnd 操作・ScheduledTask 生成なしで同期問い合わせ。SocketListen ハンドラや ScheduledTask コールバック等の非同期コンテキストから安全に呼べる（URLRead 相当の安全代替）。
→ String
Options: Fallback -> False, Model -> Automatic, Timeout -> Automatic, NonBlocking
例: ClaudeQueryBg[{prompt, img}, NonBlocking -> True, Timeout -> 120]（マルチモーダル可、claudecode で OCR/vision 対応）

### ClaudeQueryAsync[prompt, callback, nb, opts]
非同期問い合わせ。完了時に callback[応答文字列] を呼ぶ。nb は出力先 NotebookObject。

### ClaudeQueryAsyncSilent[prompt, callback, opts]
ノートブック出力なしの非同期問い合わせ。

### ClaudeEnsureSilentNotebook[] → NotebookObject
非表示の作業用ノートブックを確保する。

### ClaudeWriteResponse[nb, text, opts]
マークダウン形式テキストをノートブックのセルとして展開（見出し・リスト・コードブロックを適切なセルスタイルに変換）。
→ Null
Options: AutoEvaluate -> False
例: ClaudeWriteResponse[nb, response, AutoEvaluate -> True]

### ClaudeMath[prompt, opts]
数式・数学問題向けクエリ。LaTeX/TraditionalForm 出力を扱う。

### ClaudeExtractCode[text] → String
応答テキストから最初の WL コードブロックを抽出する。

### ClaudeExtractAllCode[text] → List
応答テキストから全コードブロックを抽出する。

### cleanOutput[text] → String
CLI 出力を整形（制御文字除去等）。

### stripANSI[text] → String
ANSI エスケープシーケンスを除去する。

## コード生成・評価

### ClaudeEval[task, opts]
タスク記述から WL コードを生成し評価する。秘密変数アクセス時は AutoPrivate でローカルモデル使用。再帰深度は $ClaudeEvalMaxDepth で制御。Paid プロバイダ指定時は NBAccess 許可をチェックし禁止なら停止。
→ 評価結果
Options: Fallback -> False, Model -> Automatic, AutoPrivate -> False, PrivacySpec -> Automatic, AutoEvaluate, Timeout

### ContinueEval[task, opts]
直前の ClaudeEval の文脈を引き継いで継続生成・評価する。

### ContinueUpdate[task, opts]
継続的にコードを更新する。

### ClaudeSpec[task] / ClaudeSpec[{task, image, ...}]
ノートブック内容（または画像付き）からプログラムの仕様を生成する。パレットからセル選択で呼出可。
→ String

### ClaudeDebug[opts]
コード・エラーのデバッグ支援。

### ClaudeReview[opts]
コードレビューを行う。

### ClaudeReviewChunked[opts]
大規模対象をチャンク分割してレビューする。

### ClaudePrepareCommit[opts]
変更内容からコミットメッセージを生成・整形する。

## ドキュメント生成

### ClaudeCreateDocumentation[packageName, opts]
パッケージの包括的ドキュメント一式を生成する。
→ 生成結果
Options: References, Demos, Disclaimer, License, Acknowledgments, Model, Title, Keywords

### ClaudeUpdateDocumentation[packageName, instruction, opts]
既存ドキュメントを部分更新する。
Options: References, Demos, Disclaimer, License, Acknowledgments, Model

## ディレクティブ管理

### ClaudeAddDirective[...] 
rules/skills ディレクティブを追加する。

### ClaudeRestoreDirective[...]
ディレクティブを復元する。

### ClaudeListDirectives[] → List
登録済みディレクティブ一覧を返す。

### ClaudeUpdateDirective[...]
ディレクティブを更新する。

### ClaudeDirectiveBackupDataset[] → Dataset
ディレクティブのバックアップ履歴を Dataset で返す。

### ClaudeSyncDirectives[opts]
ディレクティブを同期する。

## セッション管理

### CreateClaudeSession[opts] → セッション
新規 Claude セッションを作成する。
Options: Inherit

### ClaudeRestoreSession[...]
セッションを復元する。

### ClaudeListSessions[] → List
セッション一覧を返す。

### ClaudeDeleteSession[id]
セッションを削除する。

### ClaudeShowHistory[opts]
セッション履歴を表示する。

### ClaudeSessionStatus[] → Association
現在のセッション状態を返す。

### ClaudeCompactHistory[opts]
履歴をコンパクション（圧縮）する。

### ClaudeHistorySize[] → Integer
履歴サイズを返す。

## 添付ファイル

### ClaudeAttach[fileOrURL, opts]
ファイル/URL を添付する。URL はキャッシュされる。
Options: Keywords, Title, Refetch

### ClaudeDetach[...]
添付を解除する。

### ClaudeAttachments[] → List
現在の添付一覧を返す。

### ClearAttachments[]
全添付を解除する。

## 機密データ

### MarkConfidential[var] 
変数を機密としてマークする。

### UnmarkConfidential[var]
機密マークを解除する。

### IsConfidential[var] → Boolean
変数が機密かを判定する。

### Confidential[expr] / NonConfidential[expr]
式を機密/非機密としてラップする。

### ScanConfidentialCells[opts]
ノートブック内の機密セルを走査する。

## レート制限

### ClaudeRateLimitStatus[] → Association
レート制限状態を返す。

### ClaudeRateLimitClear[]
レート制限カウンタをクリアする。

## パレット・情報表示

### ShowClaudePalette[]
Claude 操作パレットを表示する。Provider ボタン（claudecode→chatgptcodex→anthropic→openai→lmstudio 循環）と Model ボタン（現プロバイダの候補列循環）を持つ。

### ClaudeQueryShowContext[opts]
クエリに付与されるコンテキストを表示する。

### ClaudeShowAccessConfig[]
アクセス許可設定を表示する。

### ClaudeStatus[] → Association
パッケージ全体の状態を返す。

### ClaudeAbort[]
進行中の処理を中断する。

## Web

### ClaudeWebSearch[query, opts] → 結果
Web 検索を実行する。

### ClaudeWebFetch[url, opts] → 結果
URL を取得する。

### WebSearch[query] / WebFetch[url]
Web 検索/取得（短縮形）。

## CLI・コマンド・分離検証

### ClaudeCommand["/command"] → 結果
Claude Code CLI のスラッシュコマンドを実行する。

### ClaudeCheckSeparation[packageName] → 結果
NBAccess 分離原則違反を検証する（結果は ClaudeFixSeparation 用にキャッシュ）。$NBSeparationIgnoreList 登録パッケージは対象外。

### ClaudeFixSeparation[packageName]
分離原則違反を修正する。

## ファイル処理

### NBFileTranslate[...] 
ノートブックファイル仕様を変換/解決する。

### ClaudeProcessFile[file, opts]
ファイルを処理する。

## NotebookLLMGraph

### NotebookLLMGraph[opts] → グラフ
ノートブックの LLM クエリ依存グラフを構築・取得する。

### NotebookLLMGraphBuild[opts]
グラフを構築する。

### NotebookLLMGraphPlot[opts] → Graphics
グラフを可視化する。

### NotebookLLMGraphPlotL2[opts] → Graphics
L2（サブステップ）グラフを可視化する。

### NotebookLLMGraphNodes[] → List
グラフノード一覧を返す。

### NotebookLLMGraphValidate[opts]
グラフを検証する。

### NotebookLLMGraphFetchResponse[node]
ノードの応答を取得する。

### NotebookLLMGraphFetchL2[node]
L2 応答を取得する。

### NotebookLLMGraphSubSteps[node] → List
ノードのサブステップを返す。

### NotebookLLMGraphErrors[] → List
グラフ内のエラーを返す。

### NotebookLLMGraphUpdateL2Status[...]
L2 ステータスを更新する。

### NotebookLLMGraphRerun[node]
ノードを再実行する。

### NotebookLLMGraphInvalidateDownstream[node]
下流ノードを無効化する。

### NotebookLLMGraphSummary[] → Association
グラフのサマリーを返す。

### NotebookLLMGraphExtractThread[...] / NotebookLLMGraphApplyThread[...]
会話スレッドの抽出/適用。

## LLMGraph 実行

### LLMGraphExecute[opts]
LLM グラフを実行する。

### LLMGraphExecuteStatus[] → Association
実行状態を返す。

### LLMGraphExecuteCancel[]
実行をキャンセルする。

## LLMGraphDAG

### LLMGraphDAGCreate[opts] → dagId
DAG ジョブを作成する。

### LLMGraphDAGStatus[dagId] → Association
DAG 状態を返す。

### LLMGraphDAGCancel[dagId] / LLMGraphDAGStop[dagId]
DAG をキャンセル/停止する。

### LLMGraphDAGRetry[dagId, opts]
失敗ノードをリトライする。

### LLMGraphDAGRebuild[dagId]
DAG を再構築する。

### LLMGraphDAGFindByContext[ctx] → dagId
コンテキストから DAG を検索する。

### LLMGraphDAGInspect[dagId] → 詳細
DAG を詳細表示する。

### LLMGraphDAGMarkFailed[dagId, node]
ノードを失敗としてマークする。

### LLMGraphDAGSnapshot[dagId]
DAG をスナップショット保存する（$ClaudeSnapshots へ）。

### LLMGraphDAGRestore[snapshot]
スナップショットから復元する。

### LLMGraphDAGListSnapshots[] → List
スナップショット一覧を返す。

### LLMGraphDAGPlot[dagId] → Graphics
DAG を可視化する。

### LLMGraphDAGMergeHistory[...]
DAG 履歴をマージする。

### iLLMGraphNode[...] / iMakeBat[...]
内部ヘルパー（外部パッケージから ClaudeCode` 経由参照可、Public 化済）。

## ランタイム

### ClaudeBuildRuntimeAdapter[opts] → Association
ランタイムアダプタを構築する。adapter Association に "DefaultTimeoutSeconds" を保持。
Options: ExecutionTimeoutSeconds -> 30

### ClaudeStartRuntime[adapter, opts] → runtimeId
ランタイムを起動する。$ClaudeLastRuntimeId に記録。

### ClaudeEvalViaRuntime[task, opts]
ランタイム経由でコード生成・評価する。実行時 TimeConstraint は proposal["ExpectedSeconds"] > adapter DefaultTimeoutSeconds > 30 の優先順。

### ClaudeApproveProposal[proposalId]
ランタイムが生成した提案を承認・実行する。

### ClaudeRuntimeSnapshot[runtimeId]
ランタイム状態をスナップショット保存する。

### ClaudeRuntimeRestore[snapshot]
ランタイムを復元する。

### ClaudeRuntimeListSnapshots[] → List
ランタイムスナップショット一覧を返す。

### ClaudeRegisterDAGRuntime[...]
DAG ランタイムを登録する。

## 並列・優先度

### ClaudeBeginParallelKernels[opts]
ParallelKernels を前置起動する。

## 編集モード

### ClaudeAppendBlockToPackage[packageName, block, opts]
パッケージ末尾にコードブロックを追記する。

### ClaudeInsertBeforeAnchorInPackage[packageName, anchor, block, opts]
アンカーの直前にコードブロックを挿入する。

### ClaudeParseEditModeResponse[response] → Association
LLM の編集モード応答（追記/挿入タグ）をパースする。

### ClaudeAutoDetectEditMode[response] → mode
応答から編集モードを自動判定する。

### ClaudeBuildEditModePromptInstructions[mode] → String
編集モード用のプロンプト指示文を生成する。

### ClaudeUpdatePackageWithMode[packageName, instruction, mode, opts]
編集モードを指定してパッケージを更新する。

## オプションシンボル

### Fallback
True で claudecode 利用不可時にアクセスレベルに応じたフォールバックモデルへ自動切替。False（既定）でエラーをそのまま返す。

### AutoPrivate
True で秘密変数アクセスタスクの生成コードに Model -> $ClaudePrivateModel, PrivacySpec -> Automatic を付与。False（既定）で通常動作。

### AutoEvaluate
ClaudeWriteResponse 等で生成セルを自動評価するか。既定 False。

### Model
プロバイダモデル指定。Automatic または {provider, model}（任意で url）。

### PrivacySpec
秘密データ構造の仕様指定。Automatic で自動。

### Timeout
タイムアウト秒数。Automatic で $ClaudeTimeout。

### Inherit
セッション/ドキュメントで親設定を継承する指定。

### References
README に参照文献セクションを追加。URL/書名リスト。

### Demos
README にデモ動画/使用例 URL リストを反映。

### Disclaimer
免責事項セクション文言リスト（README のみ）。

### License
ライセンス。`""`（既定）で GitHubREST`$GitHubLicenseHolder が非空なら MIT 自動挿入。文字列指定でそのまま挿入。

### Acknowledgments
謝辞セクション文言リスト（README のみ）。

### Owner / Repository / Branch / BaseBranch
GitHub 連携時のリポジトリ指定。

### TargetFiles / TargetFunctions
処理対象のファイル/関数を限定する。

### Mode
動作モード指定。

### DryRun
True で実行せず計画のみ。

### StartTime / RepeatInterval
スケジュール実行の開始時刻・繰返間隔。

### Keywords / Title / Refetch
添付・ドキュメントのキーワード/タイトル/再取得指定。

### WebSearch / WebFetch
クエリで Web 検索/取得ツール使用を許可するオプション。