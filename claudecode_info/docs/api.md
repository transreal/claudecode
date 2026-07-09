# claudecode API Reference

claudecode パッケージは Wolfram Language / Mathematica から Claude Code CLI および各種 LLM プロバイダーを呼び出すための統合インターフェースを提供する。依存: [NBAccess](https://github.com/transreal/NBAccess), [github](https://github.com/transreal/github) (GitHubREST`)。

## 基本設定変数

### $ClaudeModel
型: {String, String} (tuple), 初期値: {"claudecode", "claude-sonnet-4-6"}
Claude CLI に渡すプロバイダーとモデル名のペア。形式: {provider, modelName}。provider は "claudecode" | "chatgptcodex" | "anthropic" | "openai" | "zai" | "lmstudio"。
例: $ClaudeModel = {"claudecode", "claude-opus-4-8"}; $ClaudeModel = {"anthropic", "claude-sonnet-4-6"}

### $ClaudeAdvisaryModel
型: {String, String} | String, 初期値: {"chatgptcodex", "Automatic"}
仕様レビュー・合意形成ワークフローでのアドバイザリー役 (Codex) のモデル指定。$ClaudeModel と同形式。bare provider string "chatgptcodex" も受け付ける。例: {"chatgptcodex", "gpt-5.5"}

### $ClaudeTimeout
型: Integer, 初期値: 1200
ClaudeQuery / ClaudeEval 等のタイムアウト秒数。

### $ClaudeVerbose
型: Boolean, 初期値: False
True で履歴コンパクション等の詳細ログを Messages に出力する。

### $ClaudeTestModel
型: {String, String} | String, 初期値: $ClaudeModel
ClaudeCheckSeparation / ClaudeFixSeparation などの分離検証で使用するモデル。未設定なら $ClaudeModel と同じ値に初期化される。

### $ClaudeStandardFont
型: String, 初期値: "Yu Gothic UI"
ClaudeEval が生成する出力コード (Grid/Column/Style/Button 等) で統一的に使用するフォント名。プロンプトに埋め込まれ FontFamily 指定を強制する。

### $ClaudePrivateModel
型: {String, String} | {String, String, String}, 初期値: なし
秘密データ処理用ローカルモデル指定。AutoPrivate -> True 時に機密変数を含むタスクに使用される。
例: $ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-120b", "http://127.0.0.1:1234"}

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Claude Code を起動する作業ディレクトリ。配下の .claude/CLAUDE.md, .claude/rules/, .claude/skills/ を Claude Code に読ませる。

### $OpenaiWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "OpenAI Working"}]
OpenAI / ChatGPT Codex CLI の作業ディレクトリ。$ChatgptWorkingDirectory が Automatic の場合、実行ごとの Codex プロジェクト・CODEX_HOME はこの配下に作られる。

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Claude Code に Read 許可する追加ディレクトリリスト。iPrepareClaudeProjectDirectory が一時 settings.json に Read 許可を注入する。ノートブックの TaggingRules に NBSetAccessibleDirs で永続化可能。$packageDirectory 配下以外の新規ディレクトリは初回使用時にダイアログで許可を確認する。

### $ClaudeFallbackModels
型: List, 初期値: {{"chatgptcodex","gpt-5.5"},{"anthropic","claude-opus-4-8"},{"openai","gpt-5.5"}}
フォールバックモデル優先順位。各要素は {"provider", "modelName"} または {"provider", "modelName", "url"}。NBAccess`NBSetFallbackModels に自動同期される。

### $ClaudeMDPath
型: String, 初期値: ""
読み込まれる CLAUDE.md のパス。自動検索されるか手動で上書きできる。

### $ClaudeMDContent
型: String, 初期値: ""
読み込まれた CLAUDE.md の内容。内容が空の場合、CLAUDE.md が見つからなかったか内容がない。

### $ClaudeSnapshots
型: String, 初期値: FileNameJoin[{$ClaudeWorkingDirectory, "snapshots"}]
LLMGraphDAG スナップショットの保存ディレクトリ。

### $ClaudeDocModel
型: {String, String} | String, 初期値: {"claudecode", "claude-sonnet-4-6"}
ドキュメント生成・更新時に使用するモデル。"" で $ClaudeModel と同じモデルを使用。StringMatchQ[$ClaudeDocModel, "claude-sonnet-*"] なら自動的にタプル形式の最新 Sonnet に更新される。

### $ClaudeDocRetryDelay
型: Number, 初期値: 60
ドキュメント生成のリトライ待機秒数。

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
ドキュメント生成の最大リトライ回数。

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
プロンプト中ソースの最大文字数。

### $ClaudeDocUpdateStaleSeconds
型: Number, 初期値: 1800
ClaudeUpdateDocumentation の非同期ドキュメント更新チェーンのストール検出秒数。このタイムアウトを超えたロックは自動解放される。

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
ClaudeEval が再帰的に ClaudeEval を生成する際の最大深度。0 で再帰禁止。値を大きくすると多段階の自動タスク連鎖が可能。

### $ClaudeEvalMode
型: String | Automatic
ClaudeEval の動作モード。

### $ClaudeEvalHook
型: Function | None
ClaudeEval の実行前後フック関数。

### $ClaudeEvalAutoThreshold
型: Integer
自動評価の文字数閾値。

### $ClaudeEvalVerbose
型: Boolean
ClaudeEval の詳細ログ。

### $ClaudeEvalAutoLLMMinLength
型: Integer, 初期値: 500
"Auto" モードで LLM planner を起動する最小文字数。文字数未満かつ改行数未満なら LLM planner をスキップして即 Single 実行する。

### $ClaudeEvalAutoLLMMinNewlines
型: Integer, 初期値: 3
"Auto" モードで LLM planner を起動する最小改行数。改行数がこれ以上か、文字数が $ClaudeEvalAutoLLMMinLength 以上のとき LLM planner が起動する。

### $ClaudeEvalNaturalDispatch
型: Boolean, 初期値: True
自然言語ディスパッチの有効フラグ。True のとき、ClaudeEval["..."] のタスク文字列が「今日からの予定」「概要を更新」等の定型パターンにマッチしたら、LLM を経由せず SourceVault の高レベル API を直接呼ぶ。False で完全スキップし全タスクを従来の LLM 経路に流す。

### $ClaudeEvalNaturalVerbose
型: Boolean, 初期値: False
True で自然言語ディスパッチのマッチ・実行サマリを表示する。

### $ClaudeEvalNotebookContext
型: Boolean | Automatic
ノートブックコンテキストをプロンプトに含めるか。

### $ClaudeEvalLastProposedExprString
型: String
最後に ClaudeEval が提案した式の文字列。ute の TargetExprString に保存され Replayable 判定・ToInput に使う。実行されていない場合は Missing["NotCaptured"]。デバッグ用。

### $claudecodeVersion
型: String
パッケージバージョン文字列 (例: "2026-06-10-update-segment-merge-context-supply")。

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
外部パッケージがキーワードを登録する Association。プロンプトにキーワードが含まれると対応パッケージの api.md がコンテキストに自動注入される。各パッケージが自身のロード時に登録する。
例: $ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〆切"};

### $ClaudePackageAuxKeywordMap
型: Association, 初期値: <||>
補助 api_<aux>.md の注入条件を登録する Association。形式: <|pkg -> <|aux -> {キーワード...}|>|>。未登録の補助 api は常に注入される (後方互換)。
例: $ClaudePackageAuxKeywordMap["SourceVault"] = <|"eagle" -> {"Eagle", "Exif"}|>;

### $ClaudePaletteServiceControls
型: List, 初期値: {}
ShowClaudePalette の Privacy セクション下に表示するサービストグルのレジストリ。外部パッケージが登録する。各エントリは <|"Id"->id, "RunningQ"->(Function[]->True|False|Missing[]), "Start"->Function[], "Stop"->Function[], "RunningLabel"->label, "StoppedLabel"->label, "UnknownLabel"->label, (opt)"RunningColor"->color, "StoppedColor"->color|>。各 *Label は String または 0 引数 Function。

### $ClaudeCLIMCPServers
型: Association, 初期値: <||>
ヘッドレス claude CLI 実行 (ClaudeQueryBg 等) に組み込む MCP サーバーのレジストリ。形式: <|id -> spec|>。外部パッケージ (SourceVault MCP 等) が ClaudeRegisterCLIMCPServer 経由で登録する。claudecode 本体はパッケージ中立を保つ。

### $ClaudeCLIHarnessMode
型: String, 初期値: "Direct"
Claude CLI ハーネス (.claude/) の生成方式。"Direct" (既定) は従来どおり作業中の .claude/ をそのままコピーする。"Generated" は正規の Claude Directives リポジトリから .claude/ を生成するオプトインモード。

### $ClaudeMailFetchAsync
型: Boolean, 初期値: True
新着メール取得 (SourceVaultMailFetchNew) を別プロセス (wolframscript) で非同期実行し FrontEnd を塞がないかどうか。決定論的な「新着メール」ルートで使用し、現在の一覧を即返ししてバックグラウンドで取得・完了時に通知する。False で従来の同期 fetch に戻す (ライセンス席が逼迫して別プロセス起動が不安定な環境向け)。

### $ClaudePriorityModeUntil
型: AbsoluteTime
高優先度モードの終了絶対時刻。ClaudeBeginHighPriority が設定する。現在時刻がこれより前なら、共有 polling tick のうち "Suppressible"->True 登録の tick はスキップされる。

### $ClaudeEditModesVersion
型: String
編集モードシステムのバージョン。

### $ClaudeEditModeAppendTagOpen
型: String, 値: "<<<APPEND_AT_END>>>"
LLM 応答中の末尾追加開始タグ。

### $ClaudeEditModeAppendTagClose
型: String, 値: "<<<END_APPEND>>>"
末尾追加終了タグ。

### $ClaudeEditModeInsertTagClose
型: String, 値: "<<<END_INSERT>>>"
位置指定挿入終了タグ。

### $ChatgptCodexExe
型: String | Automatic
ChatGPT Codex CLI の実行ファイルパス。Automatic で PATH から解決。

### $ChatgptWorkingDirectory
型: String | Automatic
Codex 実行のベース作業ディレクトリ。Automatic は $OpenaiWorkingDirectory を使用。

### $ChatgptAccessibleDirs
型: List
Codex CLI に読み取り専用で公開する追加ディレクトリリスト。

### $ChatgptCodexHomeDirectory
型: String | Automatic
Codex 実行の CODEX_HOME ディレクトリ。Automatic は実行ごとの一時ディレクトリを作業ディレクトリ配下に作成する。

### $ChatgptCodexPermissionProfile
型: String
config.toml に書き込む Codex 権限プロファイル名。

### $ChatgptCodexApprovalPolicy
型: String, 初期値: "never"
Codex の承認ポリシー。既定 "never" は非対話的に実行する。

### $ChatgptCodexModel
型: String | Symbol, 初期値: Automatic
Codex のモデル。Automatic は config.toml にモデルキーを書かず CLI 既定モデルを使用する。

### $ChatgptCodexHarnessMode
型: String, 初期値: "Generated"
ディレクティブハーネスを Codex 用にどう構成するかの選択。

### $ChatgptCodexRetainTempProjects
型: Boolean
Codex 実行ごとの一時プロジェクトディレクトリを実行後も保持するか。

### $ChatgptCodexSourceExposureMode
型: String, 初期値: "PackageReadOnly"
Codex へのパッケージソース公開方式。

### $ClaudeCloudSendPreflightLog
型: List, 初期値: {}
クラウド送信プリフライト監査ログのインメモリバッファ。ClaudeCloudSendPreflightLogClear でクリア。

### $ClaudeCloudSendPreflightLogMaxLength
型: Integer
$ClaudeCloudSendPreflightLog の最大エントリ数。超過時は古いエントリを削除。

### $ClaudeCloudSendPreflightContextResolver
型: Function | None
プリフライト判定時のコンテキスト解決フック。外部パッケージ (SourceVault 等) がロード時に登録する。claudecode.wl 自体は SourceVault に依存しない。resolver が失敗しても送信可否には影響せず、フィールドが Missing["ResolverFailed"] になるだけ。

### $ClaudeCloudSendRoutePolicy
型: Association | String
ルートラベル ("CloudLLM", "LocalLLM", "ExternalAPI", "LocalOpenAICompatible", "ClaudeCodeCLI") をルートポリシー "External" | "Local" にマップする。プリフライト判定の分類・表示用の "RoutePolicy" として付与されるのみで、Permit/Deny 判定そのものは変えない。

### $ClaudeCloudSendPreflightLogFile
型: String | None, 初期値: None
プリフライト監査ログの永続化ファイルパス。設定するとタイムスタンプ・provider・decision・route・reason・正規化パス+SHA-256ハッシュ・privacy level・拒否パス等の固定フィールドのみを JSON Lines で追記する (payload 本文は記録しない)。

## LM Studio 統合設定

lmstudio プロバイダー (/api/v1/chat) 呼び出し時の詳細設定群。

### $ClaudeLMStudioIntegrations
型: List | None
/api/v1/chat 呼び出し時に integrations パラメータとして送る MCP サーバー / プラグインの指定。None/{} なら従来の /v1/chat/completions 経由 (MCP 無効)。解決優先順: 呼び出し側 Integrations オプション > この変数 > SourceVault model-registry。
例: $ClaudeLMStudioIntegrations = {"mcp/exa"};

### $ClaudeLMStudioAPIToken
型: String | None
LM Studio への Authorization Bearer トークン。None なら "lm-studio" を使用 (ローカル接続では通常不要)。

### $ClaudeLMStudioBaseURL
型: String, 初期値: "http://127.0.0.1:1234"
LM Studio の既定 base URL。model tuple に URL が無い場合の fallback。

### $ClaudeLMStudioContextLength
型: Integer | None | Automatic
/api/v1/chat の context_length パラメータ。None/Automatic (既定) では送らず LM Studio 側モデル設定を使用。MCP 使用時は 16000+ 推奨。

### $ClaudeLMStudioTemperature
型: Number | Automatic
/api/v1/chat の temperature。Automatic はモデル既定値。tool 利用時は 0〜0.1 推奨。

### $ClaudeLMStudioIncludeToolTrace
型: Boolean, 初期値: False
True で iQueryLMStudioChat の戻り値先頭に tool_call のトレース (ツール名・引数・結果先頭) を付加する。デバッグ用。

### $ClaudeLMStudioSamplingParams
型: Association | None
/api/v1/chat に送るサンプリング設定。既定は Qwen3 系推奨値 (temperature=0.6, top_p=0.95, top_k=20, min_p=0)。キー: "temperature", "top_p", "top_k", "min_p", "repeat_penalty"。None で送らない。

### $ClaudeLMStudioMaxOutputTokens
型: Integer | None | Automatic
/api/v1/chat の max_output_tokens。reasoning 暴走時の安全弁。None/Automatic なら送らない。

### $ClaudeLMStudioReasoning
型: String | None | Automatic
/api/v1/chat の reasoning 設定。Automatic (既定) は /api/v1/models の capabilities から MCP 前提の最強値 (high>medium>low>on) を自動選択。"off"|"on"|"low"|"medium"|"high" で明示指定 (allowed_options に含まれる場合のみ送信)。None で送らない。

### $ClaudeLMStudioToolNudge
型: String | None
LM Studio MCP (integrations) 有効時にプロンプト先頭に前置するツール使用促進文。LM Studio には tool_choice 強制が無いため、web 検索ツールの積極利用を促す既定文が入る。None/"" で前置しない。

### $ClaudeLMStudioPaletteLoadedOnly
型: Boolean, 初期値: True
パレットの LM Studio モデル選択の情報源。True: メモリにロード済み (state=="loaded") のモデルのみ提示。False: ダウンロード済みの chat 対応モデル全体 (llm/vlm、embeddings 除く) を提示。LM Studio に到達不可の場合は SourceVault カタログ/静的リストにフォールバック。

## LLM ルーティング・使用量管理

TaskClass ベースのバックエンド自動選択、日次課金上限、使用量集計を扱うサブシステム (hardening 04)。

### $ClaudeLLMTierTable
型: Association
TaskClass (例: "extract", "classify", "summarize", "securityjudge", "mailtriage", "code", "design", "general") -> backend 候補列 (優先順のモデル tuple リスト) の宣言表。候補は model tuple ({"lmstudio", Automatic} はロード済みモデルから解決)。"general" は Automatic (従来の provider fallback 連鎖) を指す。

### $ClaudeTaskClassTable
型: Association
TaskClass の属性表。各エントリのキー: "AllowEscalation" (Boolean), "RequiresValidator" (Boolean), "MaxCostClass" ("local-only"<"cheap"<"premium"), "DefaultTimeout"。新しい class はこの表に追記してから実装する。

### ClaudeTaskClassAttributes[class] → Association
TaskClass の属性を返す。未知の class は "general" に降格し warn を emit する。

### $ClaudeSpendLimit
型: Association | None, 初期値: None
課金 API の日次上限。<|"DailyUSD" -> 5.0|> の形式。当日の LLMCall CostUSD 合計が上限以上のとき、ティア解決から metered provider (anthropic/openai) を除外する。claudecode CLI (定額) と lmstudio (無料) は対象外。全候補除外時は Failure["SpendLimitExceeded"] を返す。kill-switch であって精密会計ではない (CostUSD は CLI 由来の実測のみ)。

### $ClaudeAutoCompactThresholdTokens
型: Integer, 初期値: 60000
会話履歴の自動コンパクション発火トークン概算上限。履歴のトークン概算 (ByteCount/4) がこれを超えるとターン完了時に自動コンパクションする。既存のバイト閾値とのOR条件。0/None で token 条件のみ無効化。

### ClaudeUsageReport[opts]
LLMCall イベント (spool + 正準 diagnostics-log) を集計する。EventId で重複排除。CostUSD は CLI の total_cost_usd 由来 (API/local は Null=0 扱い)。
→ Dataset (Provider/Model 別の Calls, InTokens, OutTokens, CacheRead, CostUSD)
Options: "Days" -> 1

### ClaudeResolveLLMTier[class] → Association
ティア表と preflight からタスクの実行 backend を決める。戻り値: <|"TaskClass"->実効class, "Selected"->tuple|Automatic|None, "Candidates"->..., "Rejected"->{<|"Backend","Reason"|>..}|>。Selected===Automatic は従来経路へ委譲、None は全候補 preflight 不通。

### ClaudeBackendAvailableQ[{provider, model, url...}, opts___Rule] → Association
LLM backend の事前可用性チェック (preflight)。lmstudio は /api/v0/models のロード状態、claudecode はレート制限状態を確認する。60秒キャッシュ、"Refresh"->True で再取得。
→ <|"Available"->True|False, "Reason"->"OK"|"NotRunning"|"ModelNotLoaded"|..., ...|>

### $ClaudeRoutingModelPolicy
型: Automatic | "Local" | "Cloud" | "Off"
プロンプトルーターが軽量 LLM 作業に使うモデル層を制御する。Automatic (既定) は電源状態に従う (AC→ローカル軽量モデル、バッテリー→クラウド軽量モデル)。"Local"/"Cloud" で固定、"Off" は軽量層ディスパッチを止める (リクエストは $ClaudeModel にフォールスルー、LLM 不使用のコンテキストプランナーは動作継続)。ShowClaudePalette から切替可能。

### ClaudeRoutingModelClass[] → "Local" | "Cloud" | "Off"
$ClaudeRoutingModelPolicy の Automatic を現在の電源状態に対して解決した実効クラスを返す。

### ClaudeRoutingPolicyStatus[] → Association
現在のルーティングポリシー状態を返す。キー: "Policy" (生の $ClaudeRoutingModelPolicy), "Power" ("AC"|"Battery"|"Unknown"), "Effective" (解決済みクラス)。

### ClaudeSetRoutingPolicy[p]
$ClaudeRoutingModelPolicy を p (Automatic | "Local" | "Cloud" | "Off") に設定し、カーネル再起動後も残るようマシンにも永続化する。
→ p | $Failed (不正な値の場合)

## LLMクエリ関数

### ClaudeQuery[task, opts]
LLM に問い合わせてテキスト応答をノートブックセルに出力する。task は String または {String, Image, ...} (マルチモーダル、画像/PDF/音声を API に直接送信)。$UseClaudeRuntime が True ならランタイムブリッジ経由になる。
→ String | $Failed
Options: Fallback -> False, WebFetch -> False, WebSearch -> True, Model -> Automatic, PrivacySpec -> Automatic, AutoPrivate -> False, AutoEvaluate -> False, Timeout -> Automatic, Integrations -> Automatic

### ClaudeQuerySync[task, opts]
ClaudeQuery の同期バージョン。セルへの出力なしに文字列を返す。TaskClass 経由のティア解決・Validator による応答検証と自動エスカレーションに対応。
→ String | $Failed
Options: Fallback -> False, Model -> Automatic, PrivacySpec -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic, "TaskClass" -> Automatic (バックエンド選択に $ClaudeLLMTierTable を使用), "Validator" -> None (validator[response_String] -> True | Failure[tag,...]; 失敗時 AllowEscalation な class は 1 回だけティアエスカレーションする)

### ClaudeQueryBg[task, opts]
バックグラウンドで LLM に問い合わせる。マルチモーダル ({task, Image[...]}) 対応。claudecode プロバイダーでも vision 利用可能 (iClaudeQueryRawNonBlocking 経由で CLI にリダイレクト)。
→ String | $Failed
Options: Fallback -> False, Model -> Automatic, Timeout -> Automatic, NonBlocking -> False (True でノンブロッキング), "TaskClass" -> Automatic

### ClaudeQueryAsync[task, callback, nb, opts]
非同期クエリ。Job システム経由で実行し完了時に callback[応答文字列] を呼ぶ。
→ Null
Options: Fallback -> False, Model -> Automatic, PrivacyLevel -> Automatic, Timeout -> Automatic, Integrations -> Automatic, AutoCellize -> True, "TaskClass" -> Automatic

### ClaudeQueryAsyncSilent[prompt, callback, opts]
notebook 引数なしで非同期に問い合わせる (hidden な評価用ノートブックを内部で確保し ClaudeQueryAsync に委譲)。Workflow handler 内から呼ぶ「Z 案」パターンの主要 API。ScheduledTask 内で直接 CreateNotebook すると不安定なため、メインスレッドで一度 ClaudeEnsureSilentNotebook[] を呼んでおくことを推奨。
→ Null
Options: ClaudeQueryAsync と同じ
例: ClaudeQueryAsyncSilent[prompt, callback]; ClaudeQueryAsyncSilent[prompt, callback, Model -> {"anthropic", "claude-opus-4-8"}]

### ClaudeWriteResponse[nb, text, opts]
テキストをノートブック nb のセルに書き込む。
→ Null
Options: AutoEvaluate -> False (True で書き込んだコードセルを自動評価)

### ClaudeMath[task]
数学的問い合わせ。```mathematica``` フェンス付きコードブロック・説明文のみを要求し、Markdown の表/太字/見出しを禁止するプロンプトで Claude を呼び出す。
→ String | $Failed

### ClaudeExtractCode[response]
LLM 応答テキストから最初の ```mathematica コードブロックを抽出する (見つからない場合は応答全体)。
→ String | Missing["NotFound"]

### ClaudeExtractAllCode[response]
LLM 応答テキストからすべての ```mathematica コードブロックをリストで返す。
→ List[String]

### ClaudeEnsureSilentNotebook[]
ClaudeQueryAsyncSilent が使う hidden (非表示) ノートブックオブジェクトを確保して返す。メインスレッドで一回呼んでおくと scheduled task 内での CreateNotebook を避けられる。既に存在するならそのまま返す。
→ NotebookObject

### ClaudeDebug[codeOrFile, errorMsg]
指定したコード (または コードファイルパス) とエラーメッセージからデバッグ支援を Claude に非同期で求める。応答は現在のノートブックに書き込まれる。呼び出しは即座に返る。
→ Null

### ClaudeReview[codeOrFile]
コード (またはファイルパス) のレビューを非同期で行う。コードが 30000 文字を超える場合は自動的に 25000 文字単位でチャンク分割してレビューする。
→ Null

### ClaudeReviewChunked[codeOrFile]
サイズによらず強制的にチャンク分割レビューを行う。
→ Null

## ClaudeEval / コード生成

### ClaudeEval[task, opts]
LLM に WL コードを生成させてノートブックに評価セルとして出力する。ContinueEval / ContinueUpdate のチェーンを生成可能。$ClaudeEvalMaxDepth で再帰深度を制限する。PromptRouter / 自然言語ディスパッチによる LLM 非経由の短絡実行、課金モデルガード、レート制限ガード、プライバシーガード (Private ノートブックでのクラウドモデル拒否/代替) を経る。$UseClaudeRuntime が True ならランタイムブリッジに分岐する。
→ Null
Options: Fallback -> False, AutoEvaluate -> True, StartTime -> Now, WebFetch -> Automatic (Claude がタスクを分析し必要なら自動 Web 検索), WebSearch -> True, RepeatInterval -> None, Model -> Automatic, PrivacySpec -> Automatic, AutoPrivate -> False, Timeout -> Automatic, ReferenceText -> None, OutputMode -> Automatic

### ContinueEval[task, opts]
直前の ClaudeEval のコンテキストを引き継いで評価を継続する。ClaudeEval が生成したコード内で使用する。既定の instruction は「エラーを修正してください」。
→ Null
Options: Fallback -> False, AutoEvaluate -> True, StartTime -> Now, WebFetch -> Automatic, WebSearch -> True, Model -> Automatic, PrivacySpec -> Automatic, AutoPrivate -> False, Timeout -> Automatic

### ContinueUpdate[task, opts]
直前の ClaudeUpdatePackage の実行を継続する (ClaudeEval が生成したコード内で使用)。packageName を省略すると $iLastUpdateInfo から自動復元する。最終的に ClaudeUpdatePackage を再度呼び出す。
→ Null
Options: Fallback -> False, StartTime -> Now, "UpdateApiMd" -> False
例: ContinueUpdate["上半円の境界線が欠けているので修正して"]

## 仕様・設計ワークフロー

### ClaudeSpec[task]
ノートブック内容からプログラムの仕様を生成する。パレットからセル選択で呼び出し可能。
→ Null (セルに出力)

### ClaudeSpec[{task, image, ...}]
画像付きで仕様を生成する。
→ Null (セルに出力)

### ClaudeSpecStatus[]
現在のノートブックのプロジェクト (TaggingRule SourceVaultSpecProjectId) の仕様/合意形成ドラフティングステータスを表示する。ノートブックプロジェクトがない場合は実行中のバックグラウンド合意形成ジョブを一覧表示する。SourceVault のみで完結し、ワークフローエンジンは不要。
→ Dataset | Null

### ClaudeSpecStatus["project"]
指定プロジェクトのステータスを報告する (spec/review バージョン数、最新 verdict、最新 sv:// URI、最終更新時刻、バックグラウンドジョブ実行中かどうか)。
→ Dataset

### ClaudeSpecVersions[]
現在のノートブックのプロジェクトの全 spec/review バージョンを Dataset として一覧表示する。列: Role, Round, Verdict, Seq, CreatedAtUTC, URI。SourceVault のポインタチェーン orch/<project>/spec, orch/<project>/review から取得する (合意形成フロー・単一モデル仕様フロー両方が書き込む)。表示は sv:// URI のみ (内部 ref は非表示)。
→ Dataset

### ClaudeSpecVersions["project"]
指定プロジェクトの全バージョンを Dataset として返す。
→ Dataset

### ClaudeSpecVersions["project", role]
role を "spec" | "review" | "requirements" に限定して一覧表示する。
→ Dataset

### ClaudeSpecText[uri]
sv:// URI (ClaudeSpecVersions の URI 列) から spec/review/requirements バージョンのテキストを返す。sv://snapshot/Class/hex・sv://snapshot/Class:hex・生の snapshot:Class:hex ref を受け付ける (手動 ref 変換不要)。
→ String

### ClaudeOpenSourceVaultURI[uri]
sv:// スナップショット URI (spec/review/requirements) を解決し内容を新規ノートブックウィンドウで開く (メタデータグリッド + Text 本体。review は Findings も含む)。sv:// リンクのクリックアクション。スナップショットが読み込めない場合は $Failed。
→ NotebookObject | $Failed

### CreateImplementationWorkflow[name, approvedSpec, opts]
承認済み設計仕様を SVWorkflow_<Name> パッケージとして SourceVault_workflows/<name>/ 配下に実装する (SourceVault の spec-impl ワークフローをバックグラウンドドライバーで実行)。approvedSpec は sv:// URI、スナップショット ref、または生テキスト。$ClaudeModel が実装担当、$ClaudeAdvisaryModel が検証担当で、仕様との整合性を確認しフィードバックを合意まで繰り返す。複雑な作業はステージ分割して補助仕様をレビューしてから実装する。進捗 (実行中モデル + フェーズ) は WindowStatusArea に表示。完了時に生成ワークフローの起動関数を登録 (session + promptrouter) してサマリーをノートブックに書き込む。
→ String (バックグラウンドジョブ id)
Options: "Notes" -> "" (追加指示), "ClaudeModel" -> Automatic ($ClaudeModel に解決), "AdvisaryModel" -> Automatic ($ClaudeAdvisaryModel に解決), "MaxRounds" -> Automatic, "Nb" -> Automatic (ターゲットノートブック), "Launch" -> True (完了後自動起動), "Project" -> "", "SpecURI" -> "", "SourceNotebookURI" -> ""

### LaunchImplementationWorkflow[name, args]
CreateImplementationWorkflow で生成したコード化ワークフロー name をロードして起動する。SourceVault`SourceVaultLoadWorkflow[name] でロードし WorkflowInfo["Launch"] を args で呼び出す。
→ Association (<|"context"->..., "entry"->..., "result"->...|>)

### ClaudeImplStatus[]
現在のノートブックの spec-impl ワークフロー実行状況を表示する: 現在フェーズ、実行中モデル、ステージ、ラウンド、メッセージ、SourceVault 成果物/検証チェーン数、最新 verdict。実行中は WindowStatusArea にも自動表示される。
→ Dataset

### ClaudeImplStatus["workflow"]
指定ワークフロー (実行中または完了済み) のステータスを報告する。
→ Dataset

### ClaudeImplMonitor[]
ClaudeImplStatus[] を約 2 秒ごとに自動更新するライブ Dynamic パネルを返す。ノートブックセルに配置して監視する。
→ Dynamic

## セッション管理

### CreateClaudeSession[name]
指定名のセッションを現在のノートブックに作成する。
→ String (セッション id)

### CreateClaudeSession[parent]
parent セッション (Association) からフォークしたセッションを作成する (名前は自動生成 "fork_...")。
→ String (セッション id)

### CreateClaudeSession[opts]
オプション形式で新しいセッションを作成する。
→ String (セッション id)
Options: Inherit -> True (True で現在のノートブックセッションを継承、False で独立したセッション)

### ClaudeRestoreSession[]
現在のノートブックの最新セッションを復元する。
→ True | $Failed

### ClaudeRestoreSession[name]
指定名のセッションを復元する。
→ True | $Failed

### ClaudeListSessions[]
現在のノートブック内の全セッションを一覧表示する。
→ Dataset

### ClaudeDeleteSession[name]
指定名のセッションとその全履歴を削除する。
→ True | $Failed

### ClaudeShowHistory[]
現在のセッション履歴を表示する。
→ Dataset

### ClaudeShowHistory[sessionOrName]
指定セッション (Association または名前文字列) の履歴を表示する。
→ Dataset

### ClaudeSessionStatus[]
現在のセッションのステータス (モデル、履歴サイズ、レート制限等) を表示する。
→ Dataset

### ClaudeCompactHistory[]
現在のセッション履歴を圧縮する (古い会話を要約に置換)。
→ Null

### ClaudeCompactHistory[name]
指定名のセッション履歴を圧縮する。
→ Null

### ClaudeHistorySize[]
現在のセッション履歴のサイズ情報を返す。
→ Association (<|"Entries"->..., "ByteCount"->..., "KiloBytes"->..., "Status"->...|>)

### ClaudeHistorySize[nb]
指定ノートブックのセッション履歴サイズを返す。
→ Association

### ClaudeRateLimitStatus[]
現在プロバイダーのレート制限ステータスを表示する。
→ Dataset

### ClaudeRateLimitStatus[provider]
指定プロバイダーのレート制限ステータスを表示する。
→ Dataset

### ClaudeRateLimitStatus[All]
全プロバイダーのレート制限ステータスを表示する。
→ Dataset

### ClaudeRateLimitClear[]
現在プロバイダーのレート制限カウンターをクリアする。
→ Null

### ClaudeRateLimitClear[provider]
指定プロバイダーのレート制限カウンターをクリアする。
→ Null

### ClaudeStatus[opts]
Claude Code プロセスの全体ステータスを種別ごとにまとめて表示する。
→ Dataset
Options: TaskTypes -> All

### ClaudeAbort[]
実行中の全 Claude タスク (プロセス・ポーラー・オーケストレータージョブ) を停止する。$claudeProgress 等の進捗状態もクリアする。
→ Null

### ClaudeProcessList[]
実行中プロセス/タスクの一時停止・停止操作付きインタラクティブパネルを表示する。
→ Dynamic

## 添付・Web

### ClaudeAttach[path, opts]
URL またはファイルパスを現在のセッションに添付する。URL の場合はコンテンツをキャッシュしてコンテキストに含める。
→ String (添付 id) | $Failed
Options: Keywords -> {}, Title -> None, Refetch -> False

### ClaudeAttach[session, path, opts]
指定セッションに添付する。
→ String (添付 id) | $Failed
Options: ClaudeAttach と同じ

### ClaudeDetach[path]
現在のセッションから添付を解除する。
→ True | $Failed

### ClaudeDetach[session, path]
指定セッションから添付を解除する。
→ True | $Failed

### ClaudeAttachments[]
現在のセッションの添付一覧を表示する。
→ Dataset

### ClaudeAttachments[session]
指定セッションの添付一覧を表示する。
→ Dataset

### ClearAttachments[]
現在のセッションの全添付をクリアする。
→ Null

### ClearAttachments[session]
指定セッションの全添付をクリアする。
→ Null

### ClaudeWebSearch[query] → String | $Failed
Web 検索を実行し結果をテキストで返す。Anthropic API の web_search ツールを使用する (課金あり)。オプション引数はない。

### ClaudeWebFetch[url] → String | $Failed
指定 URL の内容を取得し要約・抽出して返す。

### ClaudeWebFetch[url, prompt] → String | $Failed
取得内容に対して prompt の指示を実行する。

### ClaudeQueryShowContext[]
現在のクエリコンテキスト (ファイルアクセス設定、履歴、添付等) を表示する。
→ Null

補足: `WebFetch` と `WebSearch` は関数ではなく ClaudeQuery / ClaudeEval のオプションキー・シンボルである (下記オプション一覧を参照)。ClaudeWebFetch / ClaudeWebSearch とは別物。

## ドキュメント生成

### ClaudeCreateDocumentation[packageName, opts]
パッケージの包括的ドキュメント一式 (api.md, overview.md, README.md 等) を生成する。リミット到達時に自動停止し再実行で未生成分のみ続行する。README.md は最後に生成される。
→ True | $Failed
Options: Fallback -> False, References -> {} (URL/書籍リスト。README.md 参照文献セクションに追加), Demos -> {} (デモ URL リスト。README.md に反映), Disclaimer -> {} (免責事項テキストリスト。README.md のみ), License -> "" (ライセンス文字列。空で GitHubREST`$GitHubLicenseHolder 非空なら MIT 自動挿入), Acknowledgments -> {} (謝辞テキストリスト。README.md のみ), IncludeAuxiliaryAPIs -> Automatic

### ClaudeUpdateDocumentation[packageName, instruction, opts]
既存ドキュメントを instruction に従って部分更新する。非同期連鎖で進行するため $ClaudeDocUpdateStaleSeconds 超のロックは自動解放される。
→ True | $Failed
Options: Fallback -> False, References -> {}, Demos -> {}, Disclaimer -> {}, Acknowledgments -> {}, License -> "", TargetFiles -> Automatic, Mode -> "Update", Baseline -> "LastDocUpdate"

## ディレクティブ管理 (CLAUDE.md)

### ClaudeAddDirective[target, description, opts]
CLAUDE.md または指定スキルファイルに、description の内容を LLM に生成させて追加する。元ファイルは自動バックアップされる。
→ True | $Failed
Options: DryRun -> False

### ClaudeRestoreDirective[target]
target ("CLAUDE.md" またはスキル名) をバックアップから復元する。
→ True | $Failed

### ClaudeListDirectives[]
現在のディレクティブ一覧を表示する。
→ Dataset

### ClaudeUpdateDirective[]
ノートブックのコンテキスト (直前の議論内容等) を参照してディレクティブを更新する。
→ True | $Failed

### ClaudeUpdateDirective[text]
text の指示に従ってディレクティブを更新する (「上で議論されている内容を反映して」等の参照指示も可)。
→ True | $Failed

### ClaudeDirectiveBackupDataset[]
ディレクティブのバックアップ履歴を Dataset として返す。ClaudeUpdateDirective / ClaudeAddDirective 実行時に自動保存される。
→ Dataset

### ClaudeSyncDirectives[dir]
Claude Directives ソースフォルダの内容を dir (CLAUDE.md / rules / skills を含む対象ディレクトリ) に同期する。
→ True | $Failed
例: ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]

### ClaudeShowAccessConfig[]
現在のアクセス設定 ($ClaudeAccessibleDirs、権限、生成される settings.json 等) を表示する。
→ Null

## クラウド送信プリフライト

LLM へのクラウド送信前に何が送られるかを監査・制御するシステム。外部パッケージ (SourceVault 等) が $ClaudeCloudSendPreflightContextResolver にフックを登録して使用する。

### ClaudeCloudSendPreflightDecision[provider, payload, opts]
コンテキスト context に対するクラウド送信プリフライト判定を返す。ペイロード中のノートブックパスを NBAccess`NBFileSpec[..., "IncludeProjections"->True]["CloudSendAllowed"] と照合する。送信は行わない。
→ Association (decision, route, reason)
Options: "URL" -> Automatic

### ClaudeCloudSendPreflightError[decision]
プリフライト Deny 判定を、クラウド API 呼び出しガードと同じ形式のエラーテキストに整形する。
→ String

### ClaudeCloudSendPreflightFailure[decision]
プリフライト Deny 判定を Failure[...] オブジェクトに変換する (送信は行わない)。
→ Failure

### ClaudeCloudSendPreflightGuardDryRun[provider, payload, opts]
実際のクラウド API 呼び出しガードと同じ判定ロジックをドライラン実行する。ブロックされる場合は Failure[...]、許可される場合は <|"Decision"->"Permit", "WouldSend"->True|> を含む Association を返す。
→ Association | Failure
Options: "URL" -> Automatic

### ClaudeCloudSendPreflightAudit[payload, opts]
ペイロード中のノートブックパスについて、NBAccess プロジェクションフィールドごとの詳細と集計プリフライト判定を含む監査レポートを返す (送信は行わない)。
→ Association
Options: "Provider" -> "anthropic", "URL" -> Automatic

### ClaudeCloudSendPreflightLog[]
$ClaudeCloudSendPreflightLog の直近エントリを返す。プロンプト・ペイロード本文は記録されない。
→ List[Association]

### ClaudeCloudSendPreflightLogClear[]
$ClaudeCloudSendPreflightLog をクリアする。
→ Null

### ClaudeCloudSendPreflightLogSummary[opts]
$ClaudeCloudSendPreflightLog のサマリー (件数、ルート分布、失敗数) を返す。
→ Association
Options: "IncludeEntries" -> False

### ClaudeCloudSendPreflightFailureCell[failure]
プリフライト Deny の Failure (タグ NBCloudSendNotAllowed) を、provider・拒否/許可パス・privacy level・理由クラスを示す枠付きボックスとしてノートブックに表示する (payload 本文は表示しない)。
→ Null

### ClaudeCloudSendPreflightLogDataset[opts]
永続化ログファイル ($ClaudeCloudSendPreflightLogFile) または In-memory ログから全エントリを Dataset として返す。
→ Dataset
Options: "Columns" -> Automatic ("Columns"->All で全フィールド表示)

## パッケージ操作補助

### ClaudeCheckSeparation[target, opts]
パッケージの NBAccess 分離原則 (ノートブック依存コードが Private にあるか) を検証する。結果は $iSeparationCheckCache にキャッシュされ ClaudeFixSeparation で再利用される。$NBSeparationIgnoreList 登録パッケージ (NBAccess, NotebookExtensions) は対象外。
→ Association (violations, summary)
Options: Fallback -> False

### ClaudeFixSeparation[target, opts]
ClaudeCheckSeparation で検出された分離原則違反を修正する。$iSeparationCheckCache のキャッシュを使用する。
→ True | $Failed
Options: Fallback -> False

### ClaudeCommand["/command"]
Claude Code CLI のスラッシュコマンド (/help, /permissions, /model, /config, /version, /doctor, /login, /logout, /status 等) を実行する。未知のコマンドは CLI にそのまま渡す。
→ String | $Failed
例: ClaudeCommand["/compact"], ClaudeCommand["/status"]

### ClaudePrepareCommit[opts]
Git コミット用のメッセージを自動生成して表示する。変更サマリーを収集してフォーマットする。
→ String (コミットメッセージ)
Options: Fallback -> False, Owner -> Automatic, Repository -> Automatic, Branch -> Automatic, BaseBranch -> Automatic, DryRun -> False

補足: ClaudeUpdatePackage / ClaudeCreatePackage / ClaudeConvertToPaclet / ClaudeBackupDataset / ClaudeRestorePackage 等のパッケージ編集系関数は ClaudePackageManager.wl へ移管済み (エイリアス経由で claudecode からも引き続き呼び出し可能)。それらの詳細は ClaudePackageManager 側の api.md を参照する。

## NBFileTranslate / ClaudeProcessFile

### NBFileTranslate[inputPath, outputPath, opts]
ノートブックファイル inputPath を LLM で翻訳し outputPath に保存する。公開セルは $ClaudeModel (iClaudeQueryRaw)、機密セルは $ClaudePrivateModel で処理する confidential-aware な実装。
→ True | $Failed
Options: "TargetLang" -> "English", "SkipConfidential" -> False, "Verbose" -> True

### ClaudeProcessFile[prompt, inputPath, outputPath, opts]
ノートブックファイル inputPath の各セルを prompt の指示で LLM 処理し outputPath に保存する。内部で LLMGraphDAGCreate ベースの並列処理エンジンを使用する (公開セルは CLI 経由、機密セルは private モデル経由、最後に merge)。
→ String (バックグラウンドジョブ id)
Options: "Threshold" -> 0.5

## LLMGraph

### NotebookLLMGraph[nb]
ノートブック nb の LLMGraph (セル間依存グラフ) オブジェクトを取得または作成する。
→ Association

### NotebookLLMGraphBuild[nb, opts]
ノートブックの LLMGraph を構築または再構築する。
→ Association

### NotebookLLMGraphPlot[nb, opts]
LLMGraph を視覚化する。
→ Graphics
Options: "Detail" -> False, "SplitHistoryChain" -> True, "OrderByTime" -> False, "HiddenEdgeTypes" -> Automatic

### NotebookLLMGraphNodes[nb]
LLMGraph のノード一覧を返す。
→ List

### NotebookLLMGraphValidate[nb]
LLMGraph の整合性を検証する。
→ Association

### NotebookLLMGraphFetchResponse[nb, nodeId]
指定ノードの LLM 応答を取得する。
→ String | Missing

### NotebookLLMGraphSubSteps[nb, nodeId]
指定ノードのサブステップを返す。
→ List

### NotebookLLMGraphFetchL2[nb, nodeId]
L2 (詳細化レイヤー) の応答を取得する。
→ String | Missing

### NotebookLLMGraphErrors[nb]
LLMGraph のエラーノード一覧を返す。
→ List

### NotebookLLMGraphUpdateL2Status[nb, nodeId, status]
L2 ステータスを更新する。
→ True | $Failed

### NotebookLLMGraphPlotL2[nb, opts]
L2 グラフを視覚化する。
→ Graphics

### NotebookLLMGraphRerun[nb, nodeId, opts]
指定ノードを再実行する。
→ Null
Options: Model -> Automatic, "CascadeInvalidate" -> True, "DryRun" -> False, "Verbose" -> True

### NotebookLLMGraphInvalidateDownstream[nb, nodeId]
指定ノードの下流ノードを無効化する。
→ Null

### NotebookLLMGraphSummary[nb]
LLMGraph のサマリー情報を返す。
→ Association

### NotebookLLMGraphExtractThread[nb, nodeId]
ノードからスレッド (会話履歴チェーン) を抽出する。
→ Association

### NotebookLLMGraphApplyThread[thread, newTarget, nb, opts]
抽出したスレッドを newTarget ノードに適用する (dry-run/step-by-step 対応)。
→ Null
Options: "DryRun" -> False, "StepByStep" -> False, "SessionTag" -> Automatic, "Verbose" -> True

以下は Phase R-6 で外部パッケージ (ClaudeStateGraph 等) からの参照用に Public 化された LLMGraph 内部ヘルパー:

### iLLMGraphGetCached[nb]
LLMGraph キャッシュから nb のグラフを取得する。
→ Association | Missing

### iSaveNotebookLLMGraph[nb, graph]
LLMGraph を $iLLMGraphCache に保存する。
→ Null

### iNewLLMNode[opts]
新規 LLMGraph ノード Association を生成する。
→ Association

### iNewNotebookLLMGraph[nb]
新規 LLMGraph Association を生成して nb に関連付ける。
→ Association

### iLLMGraphMergeTwoGraphs[g1, g2]
2 つの LLMGraph をマージする。
→ Association

### iLLMGraphFlush[nb]
nb の LLMGraph キャッシュをフラッシュする。
→ Null

### iLLMGraphNode[opts]
LLMGraph ノードを解決・生成する内部ヘルパー。外部パッケージ参照用に Public 化されている (BeginPackage の公開シンボルリストに登録済み)。
→ Association

### $iLLMGraphCache
型: Association
LLMGraph のインメモリキャッシュ。ノートブックオブジェクトをキーとして LLMGraph Association を保持する。外部パッケージ (ClaudeStateGraph 等) から直接参照する場合は iLLMGraphGetCached / iSaveNotebookLLMGraph 経由を推奨。

### $iLLMGraphCacheNB
型: Association
LLMGraph キャッシュのノートブック参照インデックス。

## LLMGraphDAG

タスクの有向非循環グラフを共有スケジューラ (共有 polling tick) 上で非同期実行する低レベルフレームワーク。ClaudeProcessFile / NBFileTranslate 等が内部でこの上に構築されている。

### $LLMGraphMaxConcurrency
型: Integer
LLMGraphDAG / LLMGraphExecute の同時実行ノード数上限。

### $LLMGraphAutoStopThreshold
型: Integer
LLMGraphDAG が連続失敗等を検知して自動停止するまでの閾値。

### $LLMGraphDAGStallSeconds
型: Number
LLMGraphDAG ノードが「停滞」と判定されるまでの無進捗秒数。

### $LLMGraphDAGMaxJobSeconds
型: Number
LLMGraphDAG ジョブ全体の最大実行秒数上限。超過したジョブは失敗扱いになる。

### LLMGraphDAGCreate[spec] → String (jobId)
DAG ベースの非同期ジョブを作成し起動する。spec (Association) のキー: "nodes" (Association, nodeId -> ノード仕様 <|"status","dependsOn",...|>)、"taskDescriptor" (ノード種別ごとの実行ハンドラ定義)、"nb" (省略時は EvaluationNotebook[])、"onComplete" (完了時コールバック、省略可)、"context" (ノード共有コンテキスト、省略可)。より簡便な入口としては LLMGraphExecute を推奨。

### LLMGraphDAGStatus[jobId]
DAG の実行ステータスを表示する。
→ Dataset

### LLMGraphDAGCancel[jobId]
DAG の実行をキャンセルする (running ノードを kill しジョブを削除)。
→ jobId | $Failed

### LLMGraphDAGStop[jobId]
DAG の実行を停止する (running ノードを kill して failed マーク。done ノードの結果とジョブ自体は保持され、LLMGraphDAGRetry で failed ノードのみ再実行可能)。
→ Association | Missing["JobNotFound", jobId]

### LLMGraphDAGRetry[jobId]
失敗した DAG ノードを再試行する。
→ True | $Failed

### LLMGraphDAGRebuild[jobId, replacements]
DAG を replacements で置き換えて再構築し実行を再開する。
→ String (新 jobId)

### LLMGraphDAGFindByContext[key, value]
コンテキストの key/value から DAG を検索する。
→ String (DAG id) | Missing

### LLMGraphDAGFindByContext[key, value, "Cancel"]
該当する DAG を検索してキャンセルする。
→ String | Missing

### LLMGraphDAGInspect[jobId]
DAG の詳細情報を表示する。
→ Association

### LLMGraphDAGInspect[jobId, "Summary"]
DAG のサマリー情報のみを表示する。
→ Association

### LLMGraphDAGMarkFailed[jobId, nodeIds, reason]
DAG の指定ノード群を失敗マークする。reason の既定は "Manual"。
→ True | $Failed

### LLMGraphDAGSnapshot[jobId, opts]
DAG のスナップショットを $ClaudeSnapshots 配下に保存する。
→ String (スナップショットディレクトリ)
Options: "AuxiliaryState" -> <||>, "IncludeFullGraph" -> False, "IncludePrivate" -> False

### LLMGraphDAGRestore[snapDir, opts]
スナップショットから DAG を復元する。
→ String (DAG id)
Options: "MergeGraphTo" -> None

### LLMGraphDAGRestore[snapDir, "Resume"]
スナップショットから DAG を復元し実行を再開する。
→ String (DAG id)

### LLMGraphDAGListSnapshots[]
保存済みスナップショット一覧を返す。
→ Dataset

### LLMGraphDAGPlot[jobId]
DAG を視覚化する。jobId の代わりに raw job Association (キー "nodes" を持つ) を渡すことも可能 (一時ジョブとして登録して描画後クリーンアップ)。
→ Graphics

### LLMGraphDAGMergeHistory[snapDir, nb]
スナップショットの履歴を NotebookLLMGraph にマージする。
→ Null

### LLMGraphExecute[job, opts]
LLMGraph ジョブ (Association) を非同期実行する。ジョブIDを即座に返す (1秒間隔ポーリング)。
→ String (jobID)
Options: PromptTemplate -> "`content`", Model -> Automatic, "Timeout" -> Automatic, "Verbose" -> True, "WriteToNotebook" -> False, "OnChunkDone" -> (Nothing&), "OnJobDone" -> (Nothing&)

### LLMGraphExecute[input, typeName, opts]
input と typeName からジョブを構築して実行する (簡易入口)。
→ String (jobID)
Options: LLMGraphExecute[job, opts] と同じ

### LLMGraphExecuteStatus[jobID] → Association
LLMGraphExecute のステータスを返す。キー: JobID, WaveIdx, TotalWaves, TotalChunks, Pending, Running, Done, Failed, ElapsedSecs。

### LLMGraphExecuteCancel[jobID]
LLMGraphExecute のジョブをキャンセルする。
→ True | $Failed

## ランタイム

ClaudeRuntime` (別パッケージ) 上に構築された、承認ゲート付きマルチターン実行ブリッジ。

### $UseClaudeRuntime
型: Boolean
True で ClaudeQuery / ClaudeEval 等がランタイムブリッジ (ClaudeStartRuntime 等) 経由の実行に切り替わる。False (既定) では従来の直接クエリ経路を使う。

### $ClaudeLastRuntimeId
型: String
最後に開始/登録されたランタイムの id。ClaudeStartRuntime / ClaudeRegisterDAGRuntime 等が設定する。

### $ClaudeRoutingProviders
型: List
$UseClaudeRuntime 経由のランタイムルーティング対象となるプロバイダー名のリスト。

### $ClaudeRuntimeAsyncExecution
型: Boolean
True でランタイムのコード実行 (NBExecuteHeldExpr 等) を ParallelSubmit 経由で非同期化する (Phase 32)。

### $ClaudeRuntimeAsyncForce
型: Boolean
$ClaudeRuntimeAsyncExecution の判定に関わらず非同期実行を強制するフラグ。

### $ClaudeRuntimeAsyncSuppressInputEval
型: Boolean
非同期コード実行時に入力セルの自動 InputEval を抑制するフラグ。

### ClaudeBuildRuntimeAdapter[nb, opts]
ノートブック nb 用のランタイムアダプター Association を構築する。ClaudeStartRuntime / ClaudeEvalViaRuntime で内部使用する。
→ Association
Options: "AccessLevel" -> 0.5, "Secrets" -> {}, "MaxContinuations" -> 3, "SyncProvider" -> True, "Provider" -> Automatic, "Fallback" -> False, "Model" -> Automatic, "Timeout" -> Automatic ($ClaudeTimeout に解決), "ExecutionTimeoutSeconds" -> 30 (NBExecuteHeldExpr の TimeConstraint 既定値。LLM proposal に expectedSeconds があればそちらを優先)

### ClaudeStartRuntime[nb, input, opts]
ノートブック nb 上でランタイムを起動し input で最初のターンを実行する。
→ Association (<|"RuntimeId"->..., "JobId"->...|>)、失敗時は両方 $Failed
Options: "Profile" -> "Eval", "AccessLevel" -> 0.5, "Secrets" -> {}, "MaxContinuations" -> 3, "SyncProvider" -> True, "Provider" -> Automatic, "Fallback" -> False, "Model" -> Automatic, "Timeout" -> Automatic, "Metadata" -> <||>

### ClaudeEvalViaRuntime[task, opts]
ClaudeStartRuntime を呼び出し、Status が "Done"/"Failed"/"AwaitingApproval" になるまで (最大 300 秒) ポーリングする同期風ラッパー。LLM が提案した式を承認ゲート付きの安全な環境で実行する際に使用する。
→ Association (<|"RuntimeId"->..., "Status"->..., "TurnCount"->..., "LastResult"->..., "Trace"->...|>) | $Failed
Options: "Profile" -> "Eval", "Fallback" -> False, "Notebook" -> Automatic (Automatic は EvaluationNotebook[]), "AccessLevel" -> 0.5, "Secrets" -> {}, "MaxContinuations" -> 3, "SyncProvider" -> True, "Provider" -> Automatic, "Model" -> Automatic, "Timeout" -> Automatic

### ClaudeApproveProposal[runtimeId]
Status が "AwaitingApproval" のランタイムに対して承認/拒否ダイアログを表示し、承認後 ClaudeRuntime`ClaudeResumeAfterApproval でランタイムを再開する。proposal の ExpectedSeconds が設定されていればタイムアウトが自動延長される。AwaitingApproval でない場合は "NotAwaiting" を返す。
→ 実行結果 | "NotAwaiting"

### ClaudeRuntimeSnapshot[runtimeId]
ランタイム状態のスナップショットを保存する。
→ String (スナップショット id)

### ClaudeRuntimeRestore[snapDir]
スナップショットからランタイムを復元する。
→ String (ランタイム id)

### ClaudeRuntimeRestore[snapDir, "Resume"]
スナップショットからランタイムを復元し実行を再開する。
→ String (ランタイム id)

### ClaudeRuntimeListSnapshots[]
ランタイムスナップショット一覧を返す。
→ Dataset

### ClaudeRegisterDAGRuntime[jobId, spec]
独立した LLMGraphDAG ジョブを軽量な ClaudeRuntime エントリ (Profile "DAGJob") でラップして登録し、Snapshot/Restore/Retry/ListSnapshots の対象にする。$ClaudeLastRuntimeId を設定する。
→ String (runtimeId、形式 "rt-dag-<timestamp>-<random>")
spec (Association, 既定 <||>) は Metadata / AuxiliaryState として登録される。

### ClaudeBeginParallelKernels[n]
並列カーネル n 個を事前起動する。LLMGraphDAG の実行前に呼び出すと起動コストを節約できる。$ClaudeParallelKernelCount を設定する。
→ Null

### ClaudeBeginHighPriority[seconds]
high priority モードを seconds 秒間有効にする。$ClaudePriorityModeUntil を現在時刻 + seconds に設定する。既定 30 秒。その間 "Suppressible"->True 登録の polling tick はスキップされる。
→ Null

### ClaudeEndHighPriority[]
high priority モードを即時終了する。
→ Null

### $ClaudeCellInputProvider
型: None (既定) | Function
NB 初段 hook (function_contract_wiring spec v0.3 §7.3、rule 11 の弱結合)。SourceVault ロード時に `SourceVaultCellInput` (選択セル/直前セル → typed PortBindingRef 列。cell UUID + content hash + privacy 付き) が自動登録される。未登録なら従来経路。

### $ClaudeCellOutputProvider
型: None (既定) | Function
NB 最終段 hook。SourceVault ロード時に `SourceVaultCellOutput` (URI envelope / wiring 実行結果 → MediaKind 別セル書き出し) が自動登録される。

## ClaudeEval コンテキストプランニング

ClaudeEval の LLM 送信パスにおける、有界/遅延コンテキスト組み立てを制御するサブシステム。

### $ClaudeEvalContextPlanning
型: Automatic | "LegacyFull" | False, 初期値: Automatic
Automatic (既定): 登録済みプランナー $ClaudeEvalContextPlanner があればそれを使用、なければ $ClaudeEvalDefaultContextPlan (有界プラン) を使用する。"LegacyFull" または False: 旧来の全ノートブックを常に送る挙動 (無制限) に戻す。

### $ClaudeEvalContextPlanner
型: Function | None, 初期値: None
package-neutral なオプションフック。SourceVault がロード時に設定することを想定。claudecode.wl 自体は SourceVault に依存しない。将来のプランナー駆動コンテキストプラン用に予約。

### $ClaudeEvalUnknownContextSoftLimit
型: Integer, 初期値: 4096
モデルの最大コンテキスト長が不明な場合に使うトークンソフトリミット。特定モデルのコンテキスト長を前提とした値ではない。

### $ClaudeEvalContextNotebookCharBudget
型: Integer, 初期値: 8000
$ClaudeEvalContextPlanning が有効なとき、ClaudeEval 送信パスでノートブックコンテキスト文字列を制限する上限 (直近セルを末尾優先で保持)。

### $ClaudeEvalContextHistoryTurns
型: Integer, 初期値: 12
$ClaudeEvalContextPlanning が有効かつプランの History Mode が "Recent" のとき、送信するセッション履歴の直近ターン数上限。

### $ClaudeEvalDefaultContextPlan
型: Association
プランナー未登録時に iAssembleContextForPlan が使うパッケージ既定のコンテキストプラン。"Notebook" と "History" のサブプランを持つ Association。

### $ClaudeEvalPromptRouterDispatch
型: Automatic | True | False, 初期値: Automatic
ClaudeEval の文字列タスクを、旧来の自然言語ディスパッチより前に SourceVault PromptRouter に通すかどうかを制御する。Automatic (既定): SourceVaultPromptRouterActiveQ["ClaudeEval"] に従う (ClaudeOrchestrator ロード後に True になる)。True: Order 2 では Automatic と同じ (活性ゲートは依然適用)。False: PromptRouter を完全にスキップし旧来の自然言語ディスパッチのみを使う。

### $ClaudeEvalPromptRouterPreemptsNatural
型: Boolean, 初期値: True
順序制御。True (既定): PromptRouter が旧来の自然言語ディスパッチより先に実行され、PromptRouter のパラメータ抽出がバイパスされない。旧来のディスパッチは PromptRouter が NotDispatched を返した場合のみ発火する。False: 旧来のディスパッチが先に実行される (移行期間の安全弁)。

## ポーリング・スケジューリング

### ClaudeRegisterPollingTick[key, tickFn, opts]
$iSharedPollingTask の各 tick で呼ばれる tickFn を key で登録する。共有ポーリングタスクが未起動なら自動起動する。
→ Association (<|"Status"->"Registered", "Key"->key|>)
Options: "Phase" -> "external" (デバッグラベル), "Caller" -> "External" (呼び出し元識別子), "Priority" -> 0, "Suppressible" -> False (True で ClaudeBeginHighPriority 中はスキップされる), "RunInline" -> False

### ClaudeUnregisterPollingTick[key]
登録済みの polling tick entry を解除する。全 entry が消えると次の tick で task が自動停止する。
→ Association (<|"Status"->"Unregistered"|"NotFound", "Key"->key|>)

### ClaudePollingTickKeys[]
現在登録されている polling tick の key 一覧を返す。registry 未初期化なら {}。
→ List

### ClaudeEnqueueFinalAction[action, accessSpec, opts]
承認済み final action を NBAccess の PendingFinalActionQueue に積み、共有 polling tick に NBFinalActionTick を登録する。queue が空になると tick は自己解除する。承認 UI の Approve から呼ぶ。
→ Null
Options: NBAccess`NBEnqueueFinalAction のオプションを継承

## パレット・UI

### ShowClaudePalette[]
Claude Code コントロールパレットを表示する。Provider 選択 (claudecode/chatgptcodex/anthropic/openai/zai/lmstudio を循環)、Model 選択 (現プロバイダーの候補列を循環)、Effort、Fallback、有料 API 許可、$ClaudePaletteServiceControls 登録サービスコントロール等を含む。Provider サイクル順: claudecode → chatgptcodex → anthropic → openai → zai → lmstudio。zai は z.ai GLM シリーズ (glm-5.2/glm-5.1/glm-5/glm-5-turbo/glm-4.7/glm-4.6/glm-4.5-air/glm-4.5)。claudecode/anthropic の既定モデルは SourceVault の ClaudeResolveModel 経由で動的解決され (SourceVault 未ロード時は静的候補 claude-opus-4-8/claude-sonnet-4-6/claude-haiku-4-5 にフォールバック)、マイナーバージョンの手動変更不要。openai 候補: gpt-5.5/gpt-5.5-pro/gpt-5-mini/gpt-5-nano。lmstudio 候補: qwen3.6-27b/qwen3.5-27b/qwen3-coder-30b/gpt-oss-120b (SourceVault カタログが優先)。chatgptcodex は Automatic を既定とし SourceVault の候補列を優先使用する。
→ NotebookObject

### ClaudeRegisterPaletteServiceControl[spec]
パレットサービスコントロールを $ClaudePaletteServiceControls に登録する。同じ Id を再登録すると置換される。ShowClaudePalette[] を再実行すると反映される。
→ String (Id)

### ClaudeUnregisterPaletteServiceControl[id]
パレットサービスコントロールを id で削除する。
→ Null

## CLI MCP サーバー

### ClaudeRegisterCLIMCPServer[id, spec]
ヘッドレス claude CLI 実行 (ClaudeQueryBg 等) に組み込む MCP サーバーを $ClaudeCLIMCPServers に登録する。同じ id を再登録すると置換される。
→ id (String)
spec キー: "ConfigFn" -> Function[] (サーバー到達可能時は <|"Url"->..., ("Headers"-><|...|>)|>、停止時は None を返す)、"AllowedTools" -> {ツール名...} (--allowedTools に mcp__\<id\>__\<tool\> 形式で追加。--print モードは対話承認できないため事前許可が必須)、"PromptDirective" -> String | Function[] (サーバー起動中にクエリプロンプトへ注入するポリシーテキスト)。

## 機密管理

### MarkConfidential[expr]
式を機密としてマークする。Confidential[expr] でラップされる。
→ Confidential[expr]

### MarkConfidential[]
現在のセルを機密としてマークする (パレット/セル操作用)。
→ Null

### MarkConfidential[nb, cellIdx]
指定ノートブックの指定セルを機密としてマークする。
→ Null

### UnmarkConfidential[confidential]
機密マーク (Confidential ラッパー) を解除して内部値を返す。
→ expr

### UnmarkConfidential[]
現在のセルの機密マークを解除する。
→ Null

### UnmarkConfidential[nb, cellIdx]
指定セルの機密マークを解除する。
→ Null

### IsConfidential[expr]
式が機密かどうかを返す。
→ True | False

### IsConfidential[]
現在のセルが機密かを返す。
→ True | False

### Confidential[expr]
機密データのラッパーヘッド (HoldFirst)。AutoPrivate -> True 時に $ClaudePrivateModel へのルーティングをトリガーする。
例: Confidential[secretData = Import["secret.csv"]]

### NonConfidential[expr]
非機密として明示的にマークするラッパーヘッド (HoldFirst)。機密ノートブック内でも該当式の結果を公開扱いにする。
例: result = NonConfidential[Mean[secretData]]

### ScanConfidentialCells[]
現在のノートブックの機密セルをスキャンして一覧表示する。
→ Dataset

### ScanConfidentialCells[nb]
指定ノートブック nb の機密セルをスキャンして一覧表示する。明示的に UnmarkConfidential されたセルはスキップされる。
→ Dataset

## 編集モード (Edit Modes)

### ClaudeAppendBlockToPackage[packageName, content, opts]
$packageDirectory/packageName.wl の末尾に content (文字列) を追加する。
→ Association (<|"Status"->"OK"|"Failed", "Path", "BackupPath", "AppendedChars"|>)
Options: "Backup" -> True, "BackupSuffix" -> "append-block", "EnsureLeadingNewline" -> True (ファイル末尾の改行を保証)

### ClaudeInsertBeforeAnchorInPackage[packageName, anchor, content, opts]
packageName.wl 中に唯一存在するアンカー文字列の直前に content を挿入する。アンカーが見つからない/複数ヒット時は失敗 ("AnchorNotFound"|"AnchorAmbiguous")。
→ Association (<|"Status"->"OK"|"Failed", "Reason" (失敗時), "Path", "BackupPath", "Position", "InsertedChars"|>)
Options: "Backup" -> True, "BackupSuffix" -> "insert-before"

### ClaudeParseEditModeResponse[response]
LLM の edit mode 応答 (append/insert タグ付き) をパースする。応答中のタグを優先判定し、タグが無い場合は ReplaceFunction にフォールバックする。
→ Association (<|"Mode"->"AppendBlock"|"InsertBefore"|"ReplaceFunction", "Content"->文字列, "Anchor"->文字列|None|>)

### ClaudeAutoDetectEditMode[response]
応答からモード名のみを返す軽量版。
→ String ("AppendBlock" | "InsertBefore" | "ReplaceFunction")

### ClaudeBuildEditModePromptInstructions[mode]
指定編集モード用のプロンプト指示文字列を生成する。mode: "AppendBlock" | "InsertBefore" | "ReplaceFunction" | Automatic (既定、3 形式すべてを LLM に提示しユーザー指示文から選ばせる)。
→ String

### ClaudeUpdatePackageWithMode[packageName, prompt, mode, opts]
明示的な編集モードで LLM に問い合わせ、応答を解析して該当経路 (Append/Insert/Replace) に振り分ける。mode の既定は Automatic。ClaudeUpdatePackage の内部実装。
→ True | $Failed
Options: "Backup" -> True, "DryRun" -> False, "QueryFunction" -> Automatic (既定 ClaudeCode`ClaudeQuerySync), "AdditionalInstructions" -> ""

## 診断

### ClaudeFreezeReport[n]
フリーズ診断ログ (claude_freeze_log.txt) の末尾 n 行 (既定 60) を返す。"-start" のみで対応する "-end" が無い行が直近のハング箇所を示す。$ClaudeFreezeLogEnabled = False で記録を停止できる。
→ String

### ClaudeDiagEvents[n]
SIEM spool (diag-spool, machine-local) の直近 n 件 (既定 40) を新しい順の Dataset で返す。SourceVault service の ingest 前でも自マシンの運用イベント (SpawnFailed / ScheduleSubmitFailed 等) を確認できる。
→ Dataset

## メール連携補助

### ClaudeGenerateMailSummaries[mbox, n, period]
mbox の新着メール n 件 (既定 10、period 既定 "Latest"、n に Infinity で新着全件) に派生サマリー (概要/カテゴリ/優先度/〆切) を別プロセス (子 wolframscript) で生成する。FrontEnd は塞がず、完了時に notebook へ通知が出る。内部で SourceVaultMailAddSummaries を実行し done.json を poll する決定的トリガーであり、LLM/プロンプトルーターは経由しない。SourceVault (maildb) 前提の補助関数。
→ Null

## ユーティリティ

### cleanOutput[text]
LLM 出力テキストから不要なヘッダー・末尾空白等を除去する。
→ String

### stripANSI[text]
テキストから ANSI エスケープシーケンスを除去する。CLI 出力のクリーンアップに使用する。
→ String

### iMakeBat[...]
Claude CLI 呼び出し用のバッチ起動コマンド文字列を構築する内部ヘルパー。iMakeBatStreamJson (ストリーミング JSON 出力版) / iMakeBatVerbose (詳細ログ版) と対になる。外部パッケージ参照用に Public 化されている (BeginPackage の公開シンボルリストに登録済み)。
→ String

### $iMediaMaxImageSize
型: Integer | {Integer, Integer}
画像処理時の最大サイズ上限。外部パッケージからの参照用に Public 化されている。

## オプション一覧

以下のシンボルが ClaudeQuery / ClaudeEval / ClaudeQueryBg 等のオプションキーとして使用される:

- `Fallback` → False: True で Claude Code 利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする
- `AutoPrivate` → False: True で機密変数を含むタスク時に Model -> $ClaudePrivateModel, PrivacySpec -> Automatic を付与する
- `AutoEvaluate` → ClaudeEval/ContinueEval では True、ClaudeQuery/ClaudeWriteResponse では False: コード生成後 (または書き込み後) に自動評価するか
- `AutoCellize` → True (ClaudeQueryAsync): 応答を自動でノートブックセルに変換する
- `Model` → Automatic ($ClaudeModel に解決): 使用モデルの {provider, modelName} tuple または String
- `Timeout` → Automatic ($ClaudeTimeout に解決): タイムアウト秒数
- `WebFetch` → ClaudeQuery は False、ClaudeEval は Automatic: True で必ず Web 検索 (URL フェッチ) を行う。Anthropic API 経由で課金が発生するため Fallback->True の場合のみ有効。Automatic は ClaudeEval のみで Claude がタスクを分析し必要なら自動実行。単なる「URLを自動フェッチする」フラグではない
- `WebSearch` → True (既定で有効): Claude Code CLI 組み込みの Web 検索ツールを許可する (API 経由の課金は発生しない)。False で無効化。WebFetch (課金あり) とは別機能
- `PrivacySpec` → Automatic: プライバシー設定 (Automatic で AutoPrivate に従う)
- `PrivacyLevel` → Automatic: ClaudeQuerySync/ClaudeQueryAsync のプライバシーレベル指定
- `Integrations` → Automatic: lmstudio モデル時の MCP サーバー / plugin リスト。明示リストが最優先。Automatic は $ClaudeLMStudioIntegrations → SourceVault の順で解決する
- `OutputMode` → Automatic: 出力形式 ("text" | "cell" | Automatic)
- `NonBlocking` → False: ClaudeQueryBg で True にするとノンブロッキング
- `RepeatInterval` → None: 繰り返し実行の間隔 (秒)
- `StartTime` → Now: ClaudeQueryAsync / ContinueEval / ContinueUpdate の実行開始時刻
- `ReferenceText` → None: ClaudeEval に追加参照テキストを渡す
- `"TaskClass"` → Automatic: $ClaudeLLMTierTable / $ClaudeTaskClassTable に基づくバックエンド自動選択クラス (ClaudeQuerySync/ClaudeQueryBg/ClaudeQueryAsync)
- `"Validator"` → None: ClaudeQuerySync の応答検証関数 validator[response] -> True | Failure[tag,...]
- `References` → {}: ClaudeCreateDocumentation/ClaudeUpdateDocumentation の参照 URL / 書籍リスト
- `Demos` → {}: デモ URL リスト
- `Disclaimer` → {}: 免責事項テキストリスト (README.md のみ)
- `License` → "": ライセンス文字列 (README.md のみ)
- `Acknowledgments` → {}: 謝辞テキストリスト (README.md のみ)
- `IncludeAuxiliaryAPIs` → Automatic: 補助 api_<aux>.md を生成に含めるか
- `TargetFiles` → Automatic: ClaudeUpdateDocumentation の対象ファイルリスト
- `TargetFunctions` → {}: レビュー / DAG 対象関数リスト
- `Mode` → "Update" (ClaudeUpdateDocumentation) | Automatic (編集モード系): 動作モード
- `Baseline` → "LastDocUpdate": ClaudeUpdateDocumentation の比較ベースライン
- `DryRun` → False: 変更をシミュレートするがファイルに書き込まない
- `"UpdateApiMd"` → False: ContinueUpdate 実行時に api.md も併せて更新するか
- `BaseBranch` → Automatic: ベースブランチ (ClaudePrepareCommit)
- `Branch` → Automatic: 対象ブランチ
- `Owner` → Automatic: GitHub リポジトリオーナー
- `Repository` → Automatic: GitHub リポジトリ名
- `Keywords` → {} | Automatic: キーワードリスト
- `Title` → None | Automatic: タイトル文字列
- `Refetch` → False: キャッシュを無視して再フェッチする
- `TaskTypes` → All (ClaudeStatus): 対象タスク種別
- `Inherit` → True (CreateClaudeSession): True で現在のセッションを継承、False で独立セッション

PACKAGE SOURCE CODE (chunked for token efficiency) の全域を実ソース (claudecode.wl, 38,314 行) と突き合わせて同期済み。ClaudeDebug / ClaudeReview / ClaudeWebSearch / ClaudeWebFetch / NBFileTranslate / ClaudeProcessFile / ClaudeStartRuntime / ClaudeEvalViaRuntime / ClaudeApproveProposal / CreateClaudeSession / ClaudeAddDirective / ClaudeSyncDirectives / ClaudeUpdateDirective / LLMGraphDAGCreate 等、旧版ドキュメントの usage 文字列と実装が食い違っていた関数は実装 (Private セクションの実際の定義) を正としてシグネチャ・オプションを更新した。今回のパスでは BeginPackage の公開シンボルリストと突き合わせ、`## ランタイム` に $UseClaudeRuntime / $ClaudeLastRuntimeId / $ClaudeRoutingProviders / $ClaudeRuntimeAsyncExecution / $ClaudeRuntimeAsyncForce / $ClaudeRuntimeAsyncSuppressInputEval を、`## LLMGraphDAG` に $LLMGraphMaxConcurrency / $LLMGraphAutoStopThreshold / $LLMGraphDAGStallSeconds / $LLMGraphDAGMaxJobSeconds を追加した (usage 文字列がソースの提供範囲外のため、変数名と Phase コメントの文脈から用途を記述)。