## 設計思想と実装の概要

ClaudeCode は以下の設計原則に基づいています。

- **ノートブック中心**: すべての操作はノートブック上で完結します。CLI を直接操作する必要はありません。
- **非同期実行**: LLM への問い合わせは非同期で実行され、ノートブックの操作を妨げません。リアルタイムのストリーミング進捗表示により、思考中・テキスト生成中・ツール実行中の状態を確認できます。
- **安全なパッケージ管理**: パッケージの更新はバックアップ・差分マージ・安全性検証・再ロードを自動で行います。排他ロック機構により、同一パッケージへの並列更新を防止します。更新後は自動生成された検証テストが実行され、意図した変更が正しくコードに反映されているか確認します。2026-06-10 の改善により、LLM レスポンスを「連続した行のかたまり（セグメント）」単位でマージするようになり、マージ精度が大幅に向上しました。`Pkg\`X` / `Pkg\`Private\`iX` のような完全修飾定義も正しく認識されます。
- **差分ベースバックアップ**: バックアップは SequenceAlignment ベースの差分形式（.cz / .cdiff / .unchanged）で保存され、ストレージ消費を大幅に削減します。既存の生バックアップは `ClaudeMigrateBackupHistory` で差分形式に変換できます。
- **機密データ保護**: `Confidential[]` による秘匿変数システムと、プライバシー考慮型モデルルーティングにより、機密データの安全な取り扱いを実現します。アクセスレベルに基づいて、クラウドモデルとローカルモデルを自動的に使い分けます。
- **多段フォールバック**: Claude Code CLI が利用不可の場合、アクセスレベルに応じたフォールバックモデルに自動切替します。Anthropic API、OpenAI API、LM Studio 等のローカルモデルを順次試行します。
- **セッション管理**: 会話履歴をノートブックの TaggingRules に永続化し、差分圧縮と自動コンパクションによりストレージを効率的に利用します。
- **多言語対応**: `$Language` 設定に基づいてプロンプトの言語指示を動的に生成します。`$Language` が `"Japanese"` の場合は日本語で応答するよう指示し、それ以外の場合は英語に切り替わります。
- **AI 生成機能**: OpenAI Images API による画像生成（`ClaudeImageGenerate`）と OpenAI TTS API による音声生成（`ClaudeSpeech`）を統合しています。
- **プロジェクト固有ディレクティブ**: ノートブックディレクトリごとに独立したルール・スキルを定義し、メインのディレクティブと自動マージできます。
- **claudecode_directives 連携**: オプションの独立パッケージ [claudecode_directives](https://github.com/transreal/claudecode_directives) をロードすることで、`rules/` および `skills/` ディレクトリのデフォルトセットが自動的にインストールされます。ロード後は Claude Code CLI のコンテキストに rules/ の制約と skills/ の手順が自動的に注入され、Claude がスキルを呼び出せるようになります。claudecode.wl 本体はディレクティブの内容に非依存であり、claudecode_directives がその管理を担います。
- **ディレクティブ投影レイヤー (ClaudeDirectives)**: rules/skills を含む正規ディレクティブ・リポジトリを読み込み、モデルの能力（コンテキスト長・課金有無）・ロール・タスクに応じて、投影モード（Full / Summary / Index / Lazy）と適用するスキル・ルールを in-memory で動的に選択します。さらに、単一の正規リポジトリから Claude CLI 用（`.claude/`）と Codex CLI 用（`AGENTS.md` / `.agents/`）のハーネスを生成・実体化する機能を備えます。ファイル形式は Claude Code 互換を維持し、claudecode.wl / NBAccess.wl への依存を持たない純 Wolfram Language 実装（Rule 11）として、claudecode.wl 側から optional に統合されます。
- **スマートドキュメント管理**: ドキュメント生成・更新時のモード制御（新規作成・既存更新）、部分更新対象の指定、差分検出による効率的な更新処理を提供します。`ClaudeUpdateDocumentation` の `Baseline` オプションにより、差分の基準を「直近の更新バックアップ（`"LastDocUpdate"`）」と「GitHub コミット版（`"Github"`）」から選択でき、後者では `_info/design` の新規設計内容も加味した更新が行えます。ドキュメント更新チェーンの多重起動防止ガードにより、同一パッケージに対して複数の更新チェーンが同時起動することを防ぎます。チェーンが異常終了した場合も `$ClaudeDocUpdateStaleSeconds` 秒後に自動解放されます。
- **分離原則検証**: NBAccess パッケージとの適切な分離を維持するため、コード内の分離原則違反を自動検出・修正する機能を備えています。
- **パッケージキーワード自動注入**: 各パッケージが独自のキーワードを登録し、プロンプト中にキーワードが含まれる場合に自動的にそのパッケージの API ドキュメントをコンテキストに注入します。
- **自動実行安全ガード**: `ClaudeEval` の `AutoEvaluate -> True` で生成コードを自動実行する際、`NBAutoEvalProhibitedPatterns` に定義された禁止パターンに該当するコードの自動実行をブロックします。これにより、ファイル削除や危険なシステム操作などを含むコードが意図せず実行されることを防止します。
- **共有ポーリングタスク**: 複数の非同期ジョブが実行中の場合、すべてのジョブが単一の共有ポーリングタスクを利用します。旧実装のようにジョブごとに個別の `ScheduledTask` を作成しないため、多数のジョブを並列実行した際のオーバーヘッドが大幅に削減されます。`iEnsureSharedPollingTask` により共有タスクのライフサイクルが管理され、パッケージリロード時には旧タスクが自動的に停止されます。
- **非同期スケジューリング規約の自動注入**: `ClaudeUpdatePackage` のプロンプトに、非同期タスクのスケジューリング規約（claudecode/NBAccess 公開 API の使用義務・例外条件・根拠）を自動注入します。LLM が生成するパッケージコードが正しい非同期パターンに従うよう誘導します。
- **Windows エンコーディング安全な API 通信（マルチモーダル対応）**: `ClaudeQueryBg` はテキスト・`Image`・`File` オブジェクトを混在したリスト形式の入力に対応しています。CLI パスでは `iNormalizePrompt` 経由で画像を PNG に変換して送信し、API フォールバックパス（`Fallback -> True`）では Anthropic API のマルチモーダル `content` 配列を構築して送信します。リクエストボディは `ExportByteArray["JSON"]` で UTF-8 ByteArray として送信し、非 ASCII 文字は `\uXXXX` JSON エスケープに変換します。レスポンスは `ImportByteArray["RawJSON"]` で ByteArray のまま直接 JSON パースするため、Windows 固有の暗黙的エンコーディング変換（ShiftJIS 等）による日本語文字化けが発生しません。
- **ClaudeRuntime 統合**: オプションの独立パッケージ [ClaudeRuntime](https://github.com/transreal/ClaudeRuntime) をロードすると、`ClaudeEval` のバックエンドとしてランタイムセッション管理機能が有効になります。ランタイムはターン数・プロファイル・失敗履歴を追跡し、危険な操作に対して承認フロー(`NeedsApproval`)を提供します。ClaudeRuntime をロードすると `$UseClaudeRuntime = True` が自動的に設定され、`ClaudeEval` 呼び出しは ClaudeRuntime 経由でルーティングされます(claudecode 単独ロード時はデフォルトの `$UseClaudeRuntime = False` のまま従来動作を維持)。
- **ClaudeOrchestrator 連携**: オプションの独立パッケージ [ClaudeOrchestrator](https://github.com/transreal/ClaudeOrchestrator) をロードすると、`ClaudeEval` がオーケストレーター管理下の非同期実行モードに切り替わります。呼び出しはジョブキューに追加されて即座に返り、カーネルをブロックしません。rate-limit 検出・自動待機・リトライスケジューリングが透過的に処理され、長時間・大規模なタスクを安定して継続実行できます。`ClaudeRateLimitStatus[]` が返す復旧予定時刻を参照して待機タイミングを自動判断します。
- **SourceVault 連携（PromptRouter ブリッジ）**: オプションの独立パッケージ [SourceVault](https://github.com/transreal/SourceVault) をロードすると、`ClaudeEval` の Order 2 ディスパッチとして PromptRouter による提案ベースの実行経路が有効になります。SourceVault がタスク文字列から `PromptRouteProposal` を構築し、claudecode 側は提案の `ProposedExpression`（`HoldComplete`）の頭部を ReadOnly 許可リストと照合した上でのみ評価します。claudecode.wl は SourceVault に対して hard dependency を持たず（rule 11）、SourceVault がアクティブでない・許可リスト外の頭部を提案した・エラー・拒否を返した場合は `NotDispatched` となり、従来の自然言語ルーター（spec 5.3 / 24.3）にフォールバックします。SourceVault をロードすると、仕様書の審査・実装ワークフロー化 API（`ClaudeSpecStatus`・`ClaudeSpecVersions`・`ClaudeSpecText`・`ClaudeOpenSourceVaultURI`・`CreateImplementationWorkflow`・`LaunchImplementationWorkflow`）も利用可能になります。
- **[実験的] LLM 適用グラフ (LLMGraph)**: LLM の適用を DAG（有向非巡回グラフ）として自動記録・可視化します。Mathematica 14.2 の `LLMGraph` と類似の構造を採用した独自実装で、`ClaudeEval` / `ClaudeQuery` 実行時にノートブック固有のグラフが自動生成されます。この実装は `claudecode_info/design/` にある WOOC'92 / WOOC'93 論文で議論されている、データの構造を保ったまま定義域ごとに適応的に処理を適用するモデルを下敷きにしています。`$LLMGraphMaxConcurrency` によりカテゴリ別の並列度を制御でき、DAG ジョブの作成・実行・キャンセル・再構築を行う `LLMGraphDAGCreate` / `LLMGraphDAGRebuild` 系の API も提供されます。
- **[実験的] プライバシー分割ファイル処理 (ClaudeProcessFile)**: LLMGraph の応用として、ノートブックファイルのセルをプライバシーレベルで分割し、クラウド LLM とプライベート LLM で並列処理してマージする機能を提供します。

内部的には、[NBAccess](https://github.com/transreal/NBAccess) パッケージにノートブックのセル操作・プライバシー管理・履歴 DB を委譲し、[GitHubREST](https://github.com/transreal/github) パッケージと連携して GitHub 上のパッケージ管理を行います。

## 詳細説明

### 動作環境

- Wolfram Mathematica 13.x 以降
- Windows 11（macOS/Linux ではパス区切りやシェルコマンドを適宜読み替えてください）
- Claude Code CLI がインストール済みで、パスが通っていること
- ChatGPT Codex CLI（オプション、`chatgptcodex` provider 利用時。`npm install -g @openai/codex` でインストール）
- Node.js（node-pty によるインタラクティブ CLI 実行に使用）
- [NBAccess](https://github.com/transreal/NBAccess) パッケージ（`NBAccess.wl`）
- [GitHubREST](https://github.com/transreal/github) パッケージ（`github.wl`）— オプション、GitHub 連携時に必要

### インストール

基盤パッケージ（`claudecode.wl`, `NBAccess.wl`, `github.wl`）は `$packageDirectory` に直接配置します。

```mathematica
(* $Path に $packageDirectory を追加 *)
AppendTo[$Path, $packageDirectory]

(* パッケージの読み込み (UTF-8 環境で) *)
Block[{$CharacterEncoding = "UTF-8"},
  Needs["ClaudeCode`", "claudecode.wl"]];
```

claudecode を使用している場合、`$Path` は自動的に設定されます。

ディレクティブ管理機能を使用する場合は、[claudecode_directives](https://github.com/transreal/claudecode_directives) パッケージ（`claudecode_directives.wl`）をオプションでロードします。

```mathematica
(* ディレクティブ管理機能を使用する場合（オプション） *)
Block[{$CharacterEncoding = "UTF-8"},
  Needs["ClaudeCodeDirectives`", "claudecode_directives.wl"]];
```

### 基本設定

```mathematica
(* 使用するモデルの指定（空文字列で Claude Code のデフォルトモデル） *)
$ClaudeModel = "claude-sonnet-4-20250514"

(* $ClaudeModel を LM Studio に直接設定する例（Web 検索等を LM Studio で実行したい場合） *)
$ClaudePrivateModel = {"lmstudio", "qwen/qwen3.6-27b", "http://127.0.0.1:1234"}
$ClaudeModel = $ClaudePrivateModel

(* LM Studio 使用時に有効にする MCP インテグレーション *)
(* mcp.json に登録済みの MCP サーバー ID を指定する。LM Studio がサーバー側で tool-call を自動実行する。 *)
$ClaudeLMStudioIntegrations = {"mcp/exa"}

(* フォールバックモデルの設定 *)
$ClaudeFallbackModels = {
  {"anthropic", "claude-opus-4-6"},
  {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}
}

(* 機密データ処理用ローカルモデル *)
$ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}

(* タイムアウト（秒） *)
$ClaudeTimeout = 1200

(* ClaudeEval 再帰深度上限 *)
$ClaudeEvalMaxDepth = 5

(* ドキュメント生成用モデル *)
$ClaudeDocModel = "claude-sonnet-4-20250514"

(* 分離検証用モデル *)
$ClaudeTestModel = $ClaudeModel

(* 画像生成モデル優先順位 *)
$ClaudeImageModels = {{"openai", "gpt-image-1"}, {"openai", "dall-e-3"}}

(* 音声生成モデル優先順位 *)
$ClaudeTTSModels = {{"openai", "tts-1-hd"}, {"openai", "tts-1"}}

(* アクセス可能ディレクトリ *)
$ClaudeAccessibleDirs = {$packageDirectory, "C:\\Users\\...\\作業フォルダ"}

(* 作業ディレクトリ *)
$ClaudeWorkingDirectory = FileNameJoin[{$HomeDirectory, "Claude Working"}]

(* パッケージキーワード自動注入マップ *)
$ClaudePackageKeywordMap = <||>

(* LLMGraph カテゴリ別並列度 (デフォルト値を変更する場合) *)
$LLMGraphMaxConcurrency["cli"] = 4        (* CLI テキスト呼び出し *)
$LLMGraphMaxConcurrency["cli-vision"] = 1 (* CLI 画像付き呼び出し *)

(* ドキュメント更新チェーンの stale 上限（秒）。
   この秒数を超えたら異常終了とみなして再スケジュールを許可する。
   デフォルト: 1800 秒（30 分） *)
$ClaudeDocUpdateStaleSeconds = 1800

(* ClaudeRuntime の有効/無効 (ClaudeRuntime ロード時に True が自動設定される。
   従来モードに戻したい場合のみ手動で False を設定) *)
$UseClaudeRuntime = True

(* SourceVault PromptRouter ブリッジの制御フラグ *)
(* Automatic (デフォルト): PromptRouter を試行し NotDispatched なら自然言語ルーターへ
   False: PromptRouter を一切使わず常に自然言語ルーターで処理 *)
$ClaudeEvalPromptRouterDispatch = Automatic

(* True (デフォルト): PromptRouter が自然言語ルーターより先に走る
   False: 自然言語ルーターを先に試し、未マッチのときのみ PromptRouter を試す *)
$ClaudeEvalPromptRouterPreemptsNatural = True

(* 仕様審査ワークフローのアドバイザリーロール用モデル
   実装者ロール: $ClaudeModel、審査者（アドバイザリー）ロール: $ClaudeAdvisaryModel
   $ClaudeModel と同じ {provider, model} タプル形式で指定する
   デフォルト: {"chatgptcodex", Automatic}（Codex CLI の既定モデルを使用）
   後方互換として "chatgptcodex" のようなベア文字列も受け入れる
   例: $ClaudeAdvisaryModel = {"chatgptcodex", "gpt-5.5"} *)
$ClaudeAdvisaryModel = {"chatgptcodex", Automatic}
```

### パッケージキーワード自動注入システム

ClaudeCode は `$ClaudePackageKeywordMap` を通じて、各外部パッケージが独自のキーワードを登録し、プロンプト中にそれらのキーワードが含まれる場合に自動的にそのパッケージの API ドキュメントをコンテキストに注入する機能を提供します。

```mathematica
(* パッケージキーワードの登録例 *)
$ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "切"}
$ClaudePackageKeywordMap["github"] = {"GitHub", "プルリク", "コミット"}

(* 登録後、プロンプトに "メール" が含まれると maildb の api.md が自動注入される *)
ClaudeQuery["メールデータベースの操作方法を教えて"]
```

このシステムにより、各パッケージが自身のロード時にキーワードを登録することで、claudecode.wl はパッケージ非依存を保ちつつ、必要な API ドキュメントを自動的に提供できます。

### クイックスタート

```mathematica
(* 同期的に Claude に問い合わせ（テキスト応答） *)
ClaudeQuery["Mathematicaでフィボナッチ数列を生成する方法を教えてください"]

(* 非同期でコードを生成・実行 *)
ClaudeEval["素数判定関数を書いてください"]

(* 会話を継続 *)
ContinueEval["もう少し効率的な方法はありますか？"]

(* フォールバック付きで実行 *)
ClaudeEval["データ分析コードを書いて", Fallback -> True]

(* 機密データの自動ルーティング *)
成績 = Confidential[First @ Import[FileNameJoin[{Quiet @ Check[NotebookDirectory[], $packageDirectory], "成績.xlsx"}], {"Dataset"}]]
ClaudeEval["この成績データを分析してください", AutoPrivate -> True]

(* パッケージの更新 *)
ClaudeUpdatePackage["MyPackage", "エラーハンドリングを改善"]

(* ドキュメント生成 *)
ClaudeCreateDocumentation["MyPackage"]

(* AI 画像生成 *)
ClaudeImageGenerate["桜の満開の写真、フォトリアル"]

(* AI 音声生成 *)
ClaudeSpeech["こんにちは、世界"]

(* GitHub コミット準備 *)
ClaudePrepareCommit["MyPackage"]
```

### 主な機能

| カテゴリ | 機能 | 説明 |
|---|---|---|
| **問い合わせ** | `ClaudeQuery` | 同期的にテキスト応答を取得 |
| | `ClaudeEval` | 非同期でコード生成・実行 |
| | `ContinueEval` | 会話の継続・エラー修正 |
| | `ClaudeSpec` | 仕様書の生成 |
| **パッケージ管理** | `ClaudeCreatePackage` | 新規パッケージ作成 |
| | `ClaudeUpdatePackage` | バックアップ付きパッケージ更新 |
| | `ContinueUpdate` | 直前の更新を継続・バグ修正 |
| | `ClaudeRestorePackage` | バックアップからの復元 |
| | `ClaudeConvertToPaclet` | Paclet 形式への変換 |
| **ドキュメント** | `ClaudeCreateDocumentation` | ドキュメント一式の自動生成 |
| | `ClaudeUpdateDocumentation` | 差分検出による自動更新・モード制御・Baseline 切替（直近更新／GitHub コミット版） |
| **バックアップ** | `ClaudeBackupDataset` | バックアップ履歴の管理・復元 |
| | `ClaudeMigrateBackupHistory` | 生バックアップを差分形式に変換 |
| **機密データ** | `Confidential` / `NonConfidential` | 変数の秘匿・解除 |
| | `MarkConfidential` / `UnmarkConfidential` | セルの秘匿マーク |
| | `ScanConfidentialCells` | 依存セルの自動検出・マーク |
| **プライバシー** | `$ClaudePrivateModel` | ローカルモデル設定 |
| | `AutoPrivate` オプション | 機密データ自動ルーティング |
| | `PrivacySpec` オプション | アクセスレベル明示指定 |
| **セッション** | `CreateClaudeSession` | 名前付きセッション作成 |
| | `ClaudeShowHistory` | 履歴表示 |
| | `ClaudeCompactHistory` | 履歴コンパクション |
| | `ClaudeHistorySize` | 履歴サイズ診断 |
| | `ClaudeAttach` / `ClaudeDetach` | 参考資料のアタッチ |
| **ディレクティブ** | `ClaudeAddDirective` | ルール・スキルの追加 |
| | `ClaudeUpdateDirective` | ディレクティブの自動整合・テキスト指示更新 |
| | `ClaudeSyncDirectives` | 外部フォルダからの同期 |
| | `ClaudeDirectiveBackupDataset` | ディレクティブ更新履歴の管理 |
| | `ClaudeInitProject` | プロジェクト固有ディレクティブの初期化 |
| | `ClaudePromoteProjectDirectives` | ローカルディレクティブをグローバルに昇格 |
| **ディレクティブ投影** | `ClaudeResolveDirectiveBundle` | task/role/model 別の directive bundle 解決 |
| | `ClaudeBuildDirectivePromptForSingle` | 単一エージェント用 directive 投影 |
| | `ClaudeDirectiveMaterializeCodexHarness` | Codex 用ハーネスの生成 |
| | `ClaudeDirectiveMaterializeClaudeHarness` | Claude CLI 用ハーネスの生成 |
| | `ClaudeDirectiveMigrationReport` | 正規/従来ハーネスの移行ゲート（他 API は専用セクション参照） |
| **AI 生成** | `ClaudeImageGenerate` | OpenAI Images API で画像生成 |
| | `ClaudeSpeech` | OpenAI TTS API で音声生成 |
| **Web** | `ClaudeWebSearch` | Web 検索（Claude Code 組み込み） |
| | `ClaudeWebFetch` | URL 内容取得・要約（Anthropic API） |
| **ClaudeRuntime** | `ClaudeStartRuntime` | ランタイムの起動 |
| | `ClaudeEvalViaRuntime` | ランタイム経由での評価 |
| | `ClaudeUpdatePackageViaRuntime` | ランタイム経由でのパッケージ更新 |
| | `ClaudeApproveProposal` | 承認待ち提案の承認 |
| | `ClaudeRuntimeSnapshot` | ランタイムのスナップショット保存 |
| | `ClaudeRuntimeRestore` | スナップショットからの復元 |
| | `ClaudeRuntimeRetry` | 失敗ターンの再試行 |
| | `ClaudeRuntimeListSnapshots` | スナップショット一覧 |
| | `ClaudeBuildRuntimeAdapter` | ランタイムアダプタの構築 |
| | `ClaudeBuildTransactionAdapter` | トランザクションアダプタの構築 |
| | `$UseClaudeRuntime` | ランタイム有効/無効の切り替え |
| | `$ClaudeLastRuntimeId` | 最後に使用したランタイム ID |
| **SourceVault 連携** | `$ClaudeEvalPromptRouterDispatch` | PromptRouter ブリッジの有効/無効 |
| | `$ClaudeEvalPromptRouterPreemptsNatural` | 自然言語ルーターとの実行順序制御 |
| | `$ClaudeAdvisaryModel` | 仕様審査アドバイザリーロールのモデル指定 |
| | `ClaudeSpecStatus` | spec/consensus 状態の確認 |
| | `ClaudeSpecVersions` | spec/review バージョン一覧 |
| | `ClaudeSpecText` | sv:// URI から spec/review 本文を取得 |
| | `ClaudeOpenSourceVaultURI` | sv:// URI を新規ノートブックで開く |
| | `CreateImplementationWorkflow` | 承認済み仕様からワークフローを実装 |
| | `LaunchImplementationWorkflow` | 生成ワークフローの起動 |
| **[実験的] LLMGraph** | `NotebookLLMGraphPlot` | DAG 可視化 |
| | `NotebookLLMGraphNodes` | 全ノード取得 |
| | `NotebookLLMGraphSummary` | Status/L2 統計 Dataset |
| | `NotebookLLMGraphValidate` | 整合性検証 |
| | `NotebookLLMGraphExtractThread` | 実行スレッド抽出 |
| | `NotebookLLMGraphApplyThread` | Thread を別対象に再適用 |
| | `NotebookLLMGraphRerun` | ノード再実行 |
| | `LLMGraphDAGCreate` | DAG ジョブの作成 |
| | `LLMGraphDAGStatus` | DAG ジョブのステータス取得 |
| | `LLMGraphDAGCancel` | DAG ジョブのキャンセル |
| | `LLMGraphDAGStop` | DAG ジョブの停止 |
| | `LLMGraphDAGRetry` | DAG ジョブの再試行 |
| | `LLMGraphDAGRebuild` | 指定ノードを差し替えた新 DAG の構成・起動 |
| | `LLMGraphExecute` | LLMGraph ジョブの実行 |
| | `LLMGraphExecuteStatus` | LLMGraph ジョブのステータス取得 |
| | `LLMGraphExecuteCancel` | LLMGraph ジョブのキャンセル |
| | `$LLMGraphMaxConcurrency` | カテゴリ別並列度の制御 |
| **[実験的] ファイル処理** | `ClaudeProcessFile` | プライバシー分割並列処理 |
| **分離検証** | `ClaudeCheckSeparation` | NBAccess 分離原則の違反検査 |
| | `ClaudeFixSeparation` | 違反の自動修正 |
| **Git 連携** | `ClaudePrepareCommit` | 変更履歴収集・コミット準備 |
| **ユーティリティ** | `ShowClaudePalette` | 操作パレット表示 |
| | `ClaudeStatus` | 実行中タスクの状態表示 |
| | `ClaudeCommand` | CLI スラッシュコマンド実行 |

### 操作パレット

`ShowClaudePalette[]` を実行すると、Claude Code の主要操作をワンクリックで呼び出せるパレットが表示されます。

```mathematica
ShowClaudePalette[]
```

![ClaudeCode パレット](img_20260323_185321_1.png)

パレットは上から以下のセクションに分かれています。

#### 機密セル セクション

| ボタン | 説明 |
|---|---|
| **△ 機密マーク** | 選択中のセルを機密セルとしてマークします。マークされたセルの内容は ClaudeQuery/ClaudeEval のプロンプトから除外されます。 |
| **⊗ 機密解除** | 選択中のセルの機密マークを解除します。 |
| **▷ スキャン** | ノートブック全体をスキャンし、機密変数を参照するセルを自動的に機密マークします（`ScanConfidentialCells[]` に相当）。 |

#### サービス・トグル（拡張ポイント、プライバシーの下）

プライバシー（Save NB）セクションの直下に、**外部パッケージが登録したサービスの起動/停止トグル**が表示されます。claudecode 自身はどのパッケージにも依存せず、`$ClaudePackageKeywordMap` と同様に**汎用の登録窓口だけ**を提供します（パッケージ側が自分でトグルを登録する）。

- ラベル・ボタン色は登録側が供給し、**現在の稼働状態に追従**します（稼働中は色が変わり「停止」系ラベル、停止中は「起動」系ラベル）。状態は一定間隔で再確認されます。
- 登録が 1 つも無ければ、この領域には何も表示されません。

例として **SourceVault** をロードすると、MCP サーバの起動/停止トグルがここに出ます（押すと WL service + MCP proxy を起動/停止し、ラベルは実状態に追従）。

登録 API（外部パッケージ向け）:

| 関数 / 変数 | 説明 |
|---|---|
| `ClaudeRegisterPaletteServiceControl[spec]` | トグルを登録（`spec["Id"]` で一意。同じ Id の再登録は置換）。`spec` は `<\|"Id", "RunningQ" -> (Function[] が True/False/Missing を返す), "Start" -> Function[], "Stop" -> Function[], "RunningLabel", "StoppedLabel", "UnknownLabel", (任意) "RunningColor"/"StoppedColor"\|>`。 |
| `ClaudeUnregisterPaletteServiceControl[id]` | Id を指定して登録解除。 |
| `$ClaudePaletteServiceControls` | 登録済みトグルのリスト（レジストリ本体、既定 `{}`）。 |

> 各パッケージは自身のロード時に `Names` で `ClaudeRegisterPaletteServiceControl`（`ClaudeCode` コンテキスト）の存在を soft-probe してから登録します（claudecode は外部パッケージに依存しません）。ラベル文字列・起動/停止・状態判定のコールバックはすべて登録側が供給するため、claudecode 側に特定パッケージ固有のロジックは入りません。新規登録を既に開いているパレットへ反映するには `ShowClaudePalette[]` を再実行してください。

#### Claude セクション

| ボタン | 説明 |
|---|---|
| **▷ ClaudeQuery** | 選択中のセル内容またはノートブックコンテキストをもとに `ClaudeQuery` を実行します。同期的にテキスト応答を返します。 |
| **► ClaudeEval** | 選択中のセル内容またはノートブックコンテキストをもとに `ClaudeEval` を実行します。コードを非同期で生成・実行します。 |
| **▷ 選択→Query** | 現在選択中のセルの内容を取得して `ClaudeQuery` に渡します。 |
| **▷ 選択→Eval** | 現在選択中のセルの内容を取得して `ClaudeEval` に渡します。 |
| **◆ 仕様生成** | 選択中のセル内容またはノートブックコンテキストから `ClaudeSpec` を実行し、仕様書を生成します。 |
| **■ 実行停止** | 実行中の全 Claude タスクを停止します（`ClaudeAbort[]` に相当）。 |

#### 設定セクション

パレット下部の設定エリアでは、以下のパラメータをノートブックごとに保存・変更できます。設定はノートブックの TaggingRules に永続化されます。

| 設定項目 | 選択肢 | 説明 |
|---|---|---|
| **モデル** | Opus / Sonnet / Default | 使用するモデルを切り替えます。Opus は `$iModelOpus`、Sonnet は `$iModelSonnet`、Default は `$ClaudeModel` のデフォルト（空文字列）に対応します。 |
| **エフォート** | Low / Medium / High / Max | Think トリガーの強度を設定します。Low は思考なし、Medium は `think hard`、High は `think harder`、Max は `ultrathink` に対応します。 |
| **課金API** | 禁止 / 許可 | `Fallback -> True/False` を制御します。「禁止」では Claude Code CLI のみ使用し、「許可」では CLI 利用不可時に Anthropic API 等へフォールバックします。 |

#### セッション セクション

| ボタン | 説明 |
|---|---|
| **■ 履歴表示** | デフォルトセッションの会話履歴を表示します（`ClaudeShowHistory[]` に相当）。 |
| **□ セッション一覧** | ノートブック内の全セッション一覧を表示します（`ClaudeListSessions[]` に相当）。 |

#### ステータス表示

パレット最下部には現在のノートブックにおける機密セル数と機密依存セル数がリアルタイムで表示されます（例: `機密: 0, 依存: 0`）。

#### 言語切り替え

パレットの表示言語は `$Language` 設定に連動します。`$Language` が `"Japanese"` の場合は日本語で表示され、それ以外の場合（英語環境など）は英語に切り替わります。たとえば英語環境では「機密マーク」は "Mark Confidential"、「実行停止」は "Abort" のように表示されます。

### プライバシー考慮型モデルルーティング

ClaudeCode は機密データを含むタスクに対して、自動的にローカルモデルへルーティングする機能を備えています。

- **`$ClaudePrivateModel`**: ローカル LLM（LM Studio 等）のモデル仕様を設定します
- **`AutoPrivate -> True`**: 機密変数にアクセスするタスクで自動的にローカルモデルを使用します
- **`PrivacySpec`**: アクセスレベルを明示的に制御します
- **3段階フォールバック**: Claude Code CLI → アクセスレベル対応フォールバックモデル → エラーの順で試行します

### LM Studio の直接使用

`$ClaudeModel` に LM Studio のモデル仕様（リスト形式）を設定することで、Claude Code CLI を使わずに LM Studio をメインの推論エンジンとして直接使用できます。これにより、ローカル LLM を用いた Web 検索や MCP ツール連携が可能になります。

#### 基本設定例

```mathematica
(* LM Studio をメインモデルとして設定 *)
$ClaudePrivateModel = {"lmstudio", "qwen/qwen3.6-27b", "http://127.0.0.1:1234"};
$ClaudeModel = $ClaudePrivateModel;

(* MCP インテグレーションを設定（mcp.json に登録済みの ID を指定） *)
$ClaudeLMStudioIntegrations = {"mcp/exa"};

(* Web 検索を伴う質問を実行 — LM Studio が exa で検索して回答 *)
ClaudeEval["Claude Code について最新の情報を調べてほしい。"]
```

`$ClaudeLMStudioIntegrations` に MCP サーバー ID を指定すると、LM Studio がサーバー側で tool-call ループを自動実行します。フロントエンドをブロックせずに MCP ツール（exa による Web 検索等）を利用できます。MCP 使用時はコンテキスト長として 16000 以上を推奨します。

#### $ClaudeLMStudioIntegrations の指定形式

| 形式 | 例 | 説明 |
|---|---|---|
| 文字列リスト | `{"mcp/exa"}` | `mcp.json` に登録済みの MCP サーバー ID を指定 |
| Plugin 形式 | `{<|"type"->"plugin","id"->"mcp/exa",...|>}` | 詳細オプション付きで指定 |
| Ephemeral MCP 形式 | `{<|"type"->"ephemeral_mcp",...|>}` | 一時的な MCP サーバーをインライン定義 |

#### 認証設定（Require Authentication）

LM Studio の **Server Settings** で **Require Authentication** を有効にすると、API キーが要求されます。このキーは NBAccess が管理する `SystemCredential` に登録することで、ClaudeCode が自動的に取得して使用します。

**設定手順:**

1. LM Studio を起動し、**Server Settings** を開く
2. **Require Authentication** を **On** に切り替える
3. 表示された API キーをコピーする
4. Mathematica で以下を実行して登録する:

```mathematica
(* LM Studio の API キーを SystemCredential に登録 *)
(* キー名は接続先 URL を含む形式: "lmstudio-<URL>" *)
SystemCredential["lmstudio-http://127.0.0.1:1234"] = "your-lm-studio-api-key";
```

登録後は `ClaudeEval` 等の呼び出し時に API キーが自動取得されます。未登録の場合は認証なしのダミーキー（`"lm-studio"`）にフォールバックするため、Require Authentication が Off の通常利用では登録不要です。

**注意**: キー名に含まれる URL は `$ClaudeModel` の第3要素（カスタム URL）と一致させてください。リモートの LM Studio サーバーを使用する場合はそのサーバーの URL に合わせてキー名を変更してください。

### ChatGPT Codex の直接使用

`$ClaudeModel` を `{"chatgptcodex", Automatic}` に設定することで、Claude Code CLI の代わりに OpenAI の ChatGPT Codex CLI を provider として使用できます。

#### 事前準備

ChatGPT Codex CLI を npm でインストールし、OpenAI アカウントでログインします。

```bash
npm install -g @openai/codex
codex --version
codex login
```

`codex login` で作成される認証情報（`auth.json`）は既定の `CODEX_HOME`（`~/.codex`）に保存されます。ClaudeCode は Codex 実行ごとに一時的な `CODEX_HOME` を作成しますが、この認証情報を自動的に引き継ぐため、一度 `codex login` を実行しておけば ClaudeCode 経由の Codex 実行でも認証が通ります。

#### 基本使用例

```mathematica
(* provider を ChatGPT Codex に切り替え（モデルは CLI 既定） *)
$ClaudeModel = {"chatgptcodex", Automatic}

(* Codex 経由でコード生成 *)
ClaudeEval["1 から 100 までの和を求めてください"]

(* provider を Claude Code に戻す *)
$ClaudeModel = {"claudecode", "claude-opus-4-7"}
```

Codex provider は Claude CLI と同じ非同期実行経路で動作します。Codex 実行ごとに一時的な作業ディレクトリと `CODEX_HOME` を作成し、`codex exec` をバックグラウンドで起動して結果をポーリングするため、実行中にカーネルがブロックされることはありません。

Claude Code CLI も Codex CLI もサブスクリプション契約に基づく CLI であり、メーター制 API（`anthropic` / `openai` provider）とは課金体系が異なります。claudecode の課金 API ガードは `chatgptcodex` provider を無課金扱いとするため、課金 API を許可しない設定でも Codex 経由のコード生成が利用できます。

#### モデルの選択

ChatGPT Codex のモデル名は SourceVault が一元管理します。具体的な LLM モデル ID をパッケージソースに直書きせず、SourceVault のモデルレジストリから解決する設計です。詳細は「SourceVault 連携」の「ChatGPT Codex モデルレジストリ」を参照してください。

`$ChatgptCodexModel` に具体的なモデル名を設定するか、操作パレットの `M:` ボタンで選択できます。`Automatic` を選ぶと Codex CLI の既定モデルが使われます。

#### 主な設定変数

| 変数 | 既定値 | 説明 |
|---|---|---|
| `$ChatgptCodexExe` | `Automatic` | Codex CLI 実行ファイルのパス。`Automatic` は PATH から解決 |
| `$ChatgptCodexModel` | `Automatic` | Codex のモデル名。`Automatic` は config.toml の model キーを省略し CLI 既定モデルを使用 |
| `$ChatgptWorkingDirectory` | `Automatic` | Codex 実行のベース作業ディレクトリ。`Automatic` は `$TemporaryDirectory` 配下の `claudecode-chatgpt-codex` |
| `$ChatgptCodexApprovalPolicy` | `"never"` | Codex の承認ポリシー。`"never"` は非対話で実行 |

### 多言語対応（$Language ベースの言語切り替え）

ClaudeCode は Wolfram Language の `$Language` 変数を参照して、Claude への応答言語指示を自動生成します。

- **`$Language = "Japanese"`** の場合: Claude に対して日本語で応答するよう指示します。
- **`$Language` が `"Japanese"` 以外**（例: `"English"`、その他の言語）の場合: 英語で応答するよう指示します。

この切り替えはプロンプト生成時に自動で行われるため、ユーザーが明示的に設定する必要はありません。Mathematica の言語設定に合わせて適切な応答言語が選択されます。

### 自動実行安全ガード（NBAutoEvalProhibitedPatterns）

`ClaudeEval` の `AutoEvaluate -> True`（デフォルト）では、LLM が生成したコードが自動的に実行されます。安全性を確保するため、`NBAutoEvalProhibitedPatterns` に定義された禁止パターンに該当するコードの自動実行はブロックされます。

禁止パターンに該当するコードが生成された場合、そのコードブロックは Input セルとしてノートブックに書き込まれますが、自動実行はスキップされます。ユーザーがコードの内容を確認した上で、手動で実行するかどうかを判断できます。

この機構により、ファイル削除やシステム操作など、意図しない副作用を持つ可能性のあるコードが自動実行されるリスクを軽減します。内部的には `iAutoEvalProhibitedPatterns` によって禁止パターンの照合が行われます。

### アクセス可能ディレクトリ制御

`$ClaudeAccessibleDirs` により、Claude Code がアクセスできるディレクトリを制御できます。NotebookDirectory が安全なデフォルトディレクトリ（`$packageDirectory` や `$ClaudeWorkingDirectory` 配下）でない場合、初回使用時にダイアログで許可を求めます。許可設定はノートブックの TaggingRules に永続化されます。

### パッケージ更新の排他ロック

同一パッケージに対する `ClaudeUpdatePackage` の並列実行を防ぐ排他ロック機構が組み込まれています。更新開始時にロックが取得され、完了時に自動解放されます。異なるパッケージへの同時更新は並列実行可能です。

ドキュメント更新チェーン（`ClaudeUpdateDocumentation` / `ClaudeCreateDocumentation`）にも専用の多重起動防止ガードが実装されています。非同期コールバック連鎖で進行するドキュメント更新は複数の連鎖が同じ docs/ と履歴を同時更新するとデータ破損が生じるため、タイムスタンプ方式のガードで保護されています。チェーンが異常終了してガードが解放されなかった場合も、`$ClaudeDocUpdateStaleSeconds`（デフォルト 1800 秒）を超えると自動的に解放され自己復旧します。

```mathematica
(* stale 上限を変更する例（デフォルト: 1800 秒） *)
$ClaudeDocUpdateStaleSeconds = 3600  (* 1 時間に延長 *)
```

### パッケージ更新の検証テスト

`ClaudeUpdatePackage` はコードのマージ完了後、LLM が自動生成した検証テストを実行して変更が正しく反映されているかを確認します。

#### 検証テストの仕組み

LLM はコード変更と並行して `===BEGIN_TESTS===` ～ `===END_TESTS===` マーカー間に検証テストコードを生成します。各テストは `(* テスト説明 *)` コメントの直後に Boolean 式が続く形式です。テストコードはコメント区切りでブロック分割されて順次評価されます。

```mathematica
(* 例: LLM が生成する検証テストの形式 *)
===BEGIN_TESTS===
(* showMailsのデフォルト表示数が30になっているか *)
TrueQ[Options[showMails, "MaxCount"] === {"MaxCount" -> 30}]

(* 関数 newFeature が定義されているか *)
MatchQ[Definition[newFeature], _]
===END_TESTS===
```

テスト実行後、結果がノートブックに表示されます。

| 表示 | 意味 |
|---|---|
| `✅ All verification tests passed (N)` | 全 N テストが合格 |
| `⚠️ Verification tests failed (N)` | N テストが失敗（意図した変更が欠落している可能性） |

テストが失敗した場合は `ContinueUpdate[]` で追加修正を依頼することを推奨します。

#### 未変更関数の保全検証

マージ後、LLM が変更を主張していない関数が意図せず変更されていないかを自動チェックします。変更が検出された場合は警告が表示されます（ブロック境界シフトによる可能性を含む）。実際に破損している場合は事前バックアップから復元してください。

### CUDA 拡張サポート

`ClaudeUpdatePackage` の指示内容に CUDA 関連のキーワードが含まれている場合（`CUDA`, `cuda`, `cuda.wl` 等）、自動的に `cuda.wl` 拡張を読み込もうとします。`cuda.wl` が `$packageDirectory` に存在しない場合は警告が表示され、CUDA 拡張なしで処理が継続されます。

### 依存関数の自動検出（スマートターゲティング）

`ClaudeUpdatePackage` の `TargetFunctions -> Automatic`（デフォルト）では、更新指示文の内容から更新対象関数を自動推定します。

推定アルゴリズムは以下の 2 フェーズで動作します。

1. **フェーズ 1（本体マッチ）**: 指示文から 4 文字以上の漢字・カタカナ連続列と 5 文字以上の英語キーワードを複合語として抽出し、関数本体にそれらが含まれる関数を検出します。短い関数名（2 文字以下）や汎用すぎる複合語（3 文字以下）による誤マッチは除外されます。
2. **フェーズ 2（bi-gram フォールバック）**: フェーズ 1 で本体マッチが 0 件の場合、usage 文字列への bi-gram マッチにフォールバックします。

検出結果が 40 関数を超える場合（指示文の複合語が汎用すぎる場合）は、全体送信にフォールバックします。

また、検出した対象関数が呼び出す依存ヘルパー関数（3 文字以上の関数名のみ）も自動的に展開してプロンプトに含めます。依存パッケージの `api.md` も自動収集され、パッケージ境界を越えた原因追跡が可能になります。

2026-06-10 の改善により、`Pkg\`X` や `Pkg\`Private\`iX` のような完全修飾名での関数定義も正しく認識・索引化されます。これにより、名前空間付きで定義された関数も対象関数推定の対象に含まれるようになりました。

### セグメント単位の関数マージ（2026-06-10）

`ClaudeUpdatePackage` の応答マージが「セグメント単位」に改善されました。

#### セグメントとは

LLM レスポンス内の「連続した行のかたまり」をセグメントと呼びます。列 0 の構造行（関数定義の開始・終了に相当する行）でセグメント境界が決まります。インデントされた文字列連結行などは構造行とみなされず、セグメントには含まれません。また、どのセグメントにも属さない構造行自体はマージ対象外として保全されます。

#### 旧実装からの改善点

従来の実装では、部分的なレスポンス（LLM のストリーミング途中で受信した断片）に対するマージ・対象関数推定が機能していませんでした。新実装ではセグメント単位で元コードと照合し、変更された関数のみを差し替えます。

#### マージ不一致警告

マージ後、LLM が変更したと主張しているにもかかわらず元コードとセグメントが一致しなかった場合、以下の警告が表示されます。

```
⚠ マージ不一致: 以下の関数はセグメントが元コードと一致せず、置換できませんでした:
  functionName1, functionName2, ...
```

この警告が出た場合、その関数は更新されていません。`ContinueUpdate[]` で追加修正を依頼するか、手動で差分を確認してください。

#### LLM コンテキスト供給の改善（2026-06-10）

`ClaudeUpdatePackage` が LLM に送信するプロンプトに、パッケージ内の全トップレベル定義名の索引が追加されました。これにより：

- **捏造防止**: LLM が存在しない関数名を生成することを防ぎます。索引を見ることで LLM は実際に定義されている関数名を参照できます。
- **完全修飾定義の認識**: `Pkg\`X` や `Pkg\`Private\`iX` のような完全修飾形式の定義も索引に含まれます。

これらの改善は巨大ファイルでのコンテキスト溢れ・コスト増・応答品質低下を防ぐ観点でも最適化されており、索引は簡潔な形式で提供されます。

### 非同期タスクスケジューリング規約の自動注入

`ClaudeUpdatePackage` が LLM に送信するプロンプトには、非同期タスクのスケジューリング規約が自動的に注入されます。これにより、LLM が生成するパッケージコードが正しいパターンに従うよう誘導します。

注入される規約の要点は以下の通りです。

1. **必須**: 非同期タスクのスケジューリングには claudecode / NBAccess の公開 API を使用すること
2. **例外（個別 `ScheduledTask` が許容される場合）**:
   - ノートブックと無関係な純粋計算タスク（数値計算・組み合わせ計算等）
   - `PresentationListener` のように独立した FrontEnd ループを必要とするインタラクティブプログラム
3. **根拠**: 複数の `ScheduledTask` が `WindowStatusArea` を同時更新すると競合が発生し、他タスクが巻き添えで停止するリスクがある

この自動注入により、ユーザーが明示的に規約を指示しなくても、生成コードが共有ポーリングタスクの仕組みと適切に協調するようになります。

### 差分ベースバックアップシステム

バックアップは以下の差分形式で保存され、ストレージ消費を大幅に削減します。

| 拡張子 | 形式 | 説明 |
|---|---|---|
| `.cz` | Compress[全文] | ベースライン（完全な内容） |
| `.cdiff` | Compress[{参照先, SequenceAlignment結果}] | 前回との差分 |
| `.unchanged` | 参照先ディレクトリ名 | 内容変更なし（1ホップ解決保証） |

ベースラインは一定間隔（デフォルト10回ごと）で自動作成され、差分チェーンが長くなりすぎることを防ぎます。

```mathematica
(* 既存の生バックアップを差分形式に変換（容量削減） *)
ClaudeMigrateBackupHistory["MyPackage"]

(* DryRun で削減見積もりだけ確認 *)
ClaudeMigrateBackupHistory["MyPackage", DryRun -> True]

(* 全パッケージに対して一括実行 *)
ClaudeMigrateBackupHistory[]
```

### バックアップ履歴の管理

`ClaudeBackupDataset` は Review / Pull / Delete ボタン付きの Grid でバックアップ履歴を表示します。

```mathematica
(* 指定パッケージのバックアップ履歴を表示 *)
ClaudeBackupDataset["MyPackage"]

(* 全パッケージのバックアップ履歴を表示 *)
ClaudeBackupDataset[]
```

起動時にローカル最新版のスナップショットが SHA-256 ハッシュ付きで自動保存されます。Grid の #0 行（ローカル最新版）の Pull ボタンを押すと、Pull で巻き戻した後でもスナップショットから復元できます。Pull 後にファイルが変更されていた場合は警告が表示されます。

バックアップの安全な削除機能も備えています。差分チェーンの中間ノードを削除する際、後続の `.cdiff` / `.unchanged` が参照先を失わないよう、依存ファイルを自動的にベースライン（`.cz`）に変換します。

### 履歴サイズ診断

```mathematica
(* 現在のセッション履歴のサイズを診断 *)
ClaudeHistorySize[]
(* → <|"Entries" -> 45, "ByteCount" -> 182400, "KiloBytes" -> 178.1, "Status" -> ...| *)
```

200KB 超でコンパクション推奨、500KB 超で危険と判定されます。履歴コンパクションはエントリ数ベースとサイズベースの二重チェックで自動実行されます。サイズベースチェックにより、エントリ数が少なくても巨大な response を持つセッションでのノートブック肥大化を防ぎます。

### 高度な非同期処理システム

ClaudeCode は書き込みキュー方式を採用し、各セル書き込みを個別のサンク（引数なし関数）としてキューに積み、ティック間でカウンタが更新される仕組みで、数十秒ブロックする可能性がある処理を軽量な直接書き込みに変換します。これにより、大量の出力生成時でもユーザーインターフェースの応答性を保ちます。

複数のジョブが同時実行中の場合、すべてのジョブが **共有ポーリングタスク** を利用します。旧実装ではジョブごとに個別の `ScheduledTask` を作成していましたが、現在は `iEnsureSharedPollingTask` によって管理される単一の共有タスクがすべてのジョブのキューを一括処理します。これにより、多数の並列ジョブ実行時のスケジューラーへの負荷を大幅に削減しています。パッケージリロード時には旧タスクが自動的に停止されます。

#### ClaudeQueryBg のマルチモーダル対応

`ClaudeQueryBg` は FrontEnd 操作・ScheduledTask 生成なしで Claude Code CLI を `RunProcess`（同期呼び出し）経由で実行する関数です。テキスト文字列だけでなく、`Image` オブジェクトや `File[path]` を含むリスト形式の入力を受け付けます。これにより、SocketListen ハンドラや ScheduledTask コールバックなどの非同期コンテキストから、画像付きの問い合わせを安全に実行できます。デフォルト（`Fallback -> False`）では課金 API を使用せず、Claude Code のサブスクリプション範囲内で動作します。

```mathematica
(* テキストのみ（従来どおり） *)
ClaudeQueryBg["こんにちは"]

(* テキスト + 画像のリスト形式 *)
img = Import["C:\\...\\screenshot.png"]
result = ClaudeQueryBg[{"この画像を説明してください", img}]

(* テキスト + PDF ファイル *)
result = ClaudeQueryBg[{"この PDF の要点を教えて", File["C:\\...\\doc.pdf"]},
  Fallback -> True]
```

入力がリストの場合、内部で以下のように振り分けられます。

| 条件 | 使用パス | 説明 |
|---|---|---|
| メディアなし（文字列のみ） | CLI または API（テキスト） | 従来どおりテキストを結合して送信 |
| メディアあり + `Fallback -> False`（デフォルト） | CLI パス | `iNormalizePrompt` で `Image` を PNG ファイルに保存し、`--image` フラグ経由で CLI に渡す |
| メディアあり + `Fallback -> True` | Anthropic API マルチモーダルパス | `content` 配列にテキストブロックと画像ブロックを組み立てて API に直接送信 |

CLI パスでは画像ファイルが一時ディレクトリに保存され（最大 1024 px にリサイズ）、Claude Code CLI が `--image` フラグでそれを参照します。API パスでは PNG バイト列を Base64 エンコードした `image` コンテンツブロックを `content` 配列に追加して送信します。

#### Anthropic API 通信の Windows エンコーディング対応

Anthropic API 経由のフォールバック通信（`ClaudeQueryBg`）では、Windows 固有の暗黙的エンコーディング変換による日本語文字化けを防ぐため、以下の方針で実装されています。

- **リクエストボディ**: `ExportByteArray["JSON"]` を使用して UTF-8 ByteArray として送信します。`ExportString["JSON"]` を String で `Body` に渡すと Windows 環境で ShiftJIS への暗黙変換が発生するため、これを回避しています。また、非 ASCII 文字はすべて `\uXXXX` 形式の JSON エスケープに変換してから送信します。
- **レスポンス受信**: `URLRead` で `"BodyByteArray"` として受信し、`ImportByteArray["RawJSON"]` で ByteArray のまま直接 JSON パースします。`ByteArrayToString` を経由しないため、Windows の暗黙的エンコーディング変換が入りません。
- **フォールバック**: `ImportByteArray` が失敗した場合は、明示的に UTF-8 指定した `ByteArrayToString[rb, "UTF-8"]` でデコードしてから文字列版のパーサーを試みます。

この実装により、Windows 11 の `$CharacterEncoding` が ShiftJIS 等に設定されている環境でも、Anthropic API との通信で日本語テキストが正しく送受信されます。

### セッション管理の改善

セッション履歴の管理において、`iSessionAppend` と `iSessionUpdateLast` による効率的な差分更新機能が実装されています。プロンプトに含まれるキーワードが 600 文字を超える場合は各 300 文字に切り詰める制御により、過度に長い履歴エントリによるパフォーマンス低下を防ぎます。

### スケジューリング

```mathematica
(* 3時間後に実行 *)
ClaudeEval["レポート生成", StartTime -> Now + Quantity[3, "Hours"]]

(* 2時間ごとに繰り返し（TaskObject を返す） *)
ClaudeEval["監視タスク", RepeatInterval -> Quantity[2, "Hours"]]

(* 最大5回まで1時間ごとに実行 *)
ClaudeEval["チェック", RepeatInterval -> {Quantity[1, "Hours"], 5}]
```

### AI 画像生成

`ClaudeImageGenerate` は OpenAI Images API を使用して AI 画像を生成し、`Image` オブジェクトとして返します。

```mathematica
(* 基本的な画像生成 *)
ClaudeImageGenerate["桜の満開の写真、フォトリアル"]

(* モデルとオプション指定 *)
ClaudeImageGenerate["sunset over ocean",
  "Model" -> "dall-e-3",
  "Size" -> "1792x1024",
  "Quality" -> "hd"]
```

| オプション | デフォルト | 説明 |
|---|---|---|
| `"Model"` | `Automatic` | `"gpt-image-1"` または `"dall-e-3"` |
| `"Size"` | `"1024x1024"` | 画像サイズ（`"1792x1024"`, `"1024x1792"` も可） |
| `"Quality"` | `"auto"` | gpt-image-1: `"auto"`/`"high"`/`"medium"`/`"low"`、dall-e-3: `"standard"`/`"hd"` |
| `"N"` | `1` | 生成枚数 |

dall-e-3 指定時は `"auto"` → `"standard"`、`"high"` → `"hd"` に自動変換されます。`$ClaudeImageModels` でモデルリストをカスタマイズできます。

ClaudeQuery の応答中でも、「AI で画像を生成して」「フォトリアルな写真」などのリクエストに対して自動的に `ClaudeImageGenerate` を含むコードブロックが生成されます。

### AI 音声生成

`ClaudeSpeech` は OpenAI TTS API を使用して音声を生成し、`Audio` オブジェクトとして返します。

```mathematica
(* 基本的な音声生成 *)
ClaudeSpeech["こんにちは、世界"]

(* オプション指定 *)```mathematica
ClaudeSpeech["Hello, world!",
  "Model" -> "tts-1-hd",
  "Voice" -> "nova",
  "Speed" -> 1.2]
```

| オプション | デフォルト | 説明 |
|---|---|---|
| `"Model"` | `Automatic` | `"tts-1"` または `"tts-1-hd"` |
| `"Voice"` | `"alloy"` | `"alloy"`, `"echo"`, `"fable"`, `"onyx"`, `"nova"`, `"shimmer"` |
| `"Speed"` | `1.0` | 読み上げ速度（0.25〜4.0） |

`$ClaudeTTSModels` でモデルリストをカスタマイズできます。ClaudeQuery の応答中でも、「読み上げて」「ナレーション」などのリクエストに対して自動的に `ClaudeSpeech` を含むコードブロックが生成されます。

### プロジェクト固有ディレクティブ

ノートブックごとにプロジェクト固有の Claude Directives を設定できます。メインのグローバルディレクティブと自動マージされ、次回の ClaudeQuery/ClaudeEval から反映されます。

```mathematica
(* プロジェクト固有ディレクティブを初期化 *)
ClaudeInitProject[]
```

`ClaudeInitProject[]` は NotebookDirectory 内に `.claude-project/` ディレクトリを作成し、以下の構造を生成します。

- `.claude-project/CLAUDE.local.md` — プロジェクト固有のルール
- `.claude-project/rules/` — プロジェクト固有の制約
- `.claude-project/skills/` — プロジェクト固有のスキル

これらはメインの Claude Directives と自動マージされ、`.claude/` ディレクトリに出力されます。マージはタイムスタンプベースで、ソースが更新された場合のみ再マージされます。

```mathematica
(* ローカルディレクティブをグローバルに昇格 *)
ClaudePromoteProjectDirectives[]

(* DryRun でプレビュー *)
ClaudePromoteProjectDirectives[DryRun -> True]
```

`ClaudePromoteProjectDirectives[]` は `.claude-project/` 内のディレクティブをメインの Claude Directives フォルダにコピーします。

### claudecode_directives 連携（オプション）

[claudecode_directives](https://github.com/transreal/claudecode_directives) は claudecode とは独立したオプションパッケージで、`rules/` および `skills/` ディレクトリのデフォルトコンテンツを管理します。このパッケージをロードすることで、claudecode が参照する標準的なルールセット・スキルセットが自動的にインストールされます。

claudecode.wl 本体はディレクティブの内容に依存せず、claudecode_directives がその管理を担う分離設計になっています。

#### ロードと基本的な使い方

```mathematica
(* claudecode_directives をロード（claudecode ロード後に実行） *)
Block[{$CharacterEncoding = "UTF-8"},
  Needs["ClaudeCodeDirectives`", "claudecode_directives.wl"]];
```

ロード後は、`ClaudeUpdateDirective`・`ClaudeAddDirective`・`ClaudeSyncDirectives` などのディレクティブ操作関数が `claudecode_directives.wl` が提供する rules/skills の定義を参照します。

#### 提供されるディレクティブ構造

`claudecode_directives.wl` が管理するディレクトリ構造は以下の通りです。

```
$ClaudeWorkingDirectory/.claude/
  CLAUDE.md          — メインのグローバルディレクティブ
  rules/             — 絶対に破ってはいけない設計・安全・アクセス制約
  skills/            — 特定の解析・修正・レビューの具体手順とパターン集
```

#### rules/ ディレクトリの利用

`claudecode_directives.wl` がロードされると、claudecode の標準的な制約定義が `rules/` に自動配置されます。各ルールファイルは Markdown 形式で、Claude Code CLI が起動するたびに CLAUDE.md コンテキストの一部として自動的に読み込まれます。

- **自動インストール**: ロード時に標準ルールセットが `rules/` に書き込まれます。既存ファイルよりロード済みバージョンが新しい場合のみ上書きされます。
- **パッケージ操作制約**: `rules/80-package-operations.md` に代表されるルールが `ClaudeUpdatePackage` 等の操作時に Claude の判断を制約します。
- **プロジェクト固有ルール**: `ClaudeInitProject[]` や `ClaudeAddDirective` で追加したプロジェクト固有のルールは `rules/` の既存ファイルを上書きせず、別ファイルとして共存します。

```mathematica
(* 現在インストール済みのルール一覧を確認 *)
ClaudeListDirectives[]

(* 新しいルールを追加 *)
ClaudeAddDirective["rules/my-rule.md", "Import時は必ずUTF-8を指定すること"]
```

#### skills/ ディレクトリの利用

`skills/` には特定の作業手順・パターン集がスキルファイルとして格納されます。各スキルファイルは先頭に `name:` フィールドを持つ Markdown ファイルで、Claude Code の Skill ツールから名前で呼び出せます。

`claudecode_directives.wl` がロードされると、以下の標準スキルが `skills/` に自動配置されます。

| スキル名 | 内容 |
|---|---|
| `wolfram-general` | Wolfram Language コーディング手順・出力方針 |
| `notebook-path-policy` | ファイルパス解決パターン |
| `nbaccess-notebook-access` | NBAccess API リファレンスと推奨パターン |
| `nbaccess-separation-check` | NBAccess 分離原則の検証・修正手順 |
| `api-key-handling` | API キー取得の正しい実装手順 |
| `wl-encoding-and-regex` | エスケープ・正規表現の検証手順 |
| `pde-modeling` | PDE 実装ステップ |
| `confidential-data-handling` | 機密データのラッピング手順 |
| `confidential-structure-probe` | 秘密変数の構造調査と ContinueEval 連携手順 |
| `external-language-output` | R/Python 等の外部言語コードの出力パターン |
| `doc-generation` | ドキュメント生成の継続・README 構造ルール |

スキルは Claude Code CLI のセッション中に `/skill-name` 形式で呼び出されるか、タスクの内容に応じて Claude が自動的に参照します。たとえば Wolfram Language コードの生成タスクでは `wolfram-general` スキルが自動的に適用され、出力方針や推奨パターンに従ったコードが生成されます。

```mathematica
(* カスタムスキルを追加 *)
ClaudeAddDirective["skills/my-skill.md",
  "name: my-analysis\n\n## 分析手順\n1. データを読み込む\n2. 統計量を計算する"]

(* スキルの更新（テキスト指示で自動解釈） *)
ClaudeUpdateDirective["データ分析スキルにクラスタリング手順を追加して"]
```

#### claudecode_directives を使わない場合

`claudecode_directives.wl` をロードしない場合、rules/skills の管理はユーザーが手動で行います。`ClaudeAddDirective`・`ClaudeUpdateDirective`・`ClaudeSyncDirectives` は引き続き使用できますが、デフォルトのルール・スキルセットは提供されません。

### ディレクティブのテキスト指示更新

`ClaudeUpdateDirective[text]` は自然言語のテキスト指示を Claude が解釈し、CLAUDE.md / rules / skills の適切なファイルに反映します。

```mathematica
(* テキスト指示でディレクティブを更新 *)
ClaudeUpdateDirective["エクセルファイルの読み込み時は必ず UTF-8 でインポートするルールを追加して"]

(* ノートブックのコンテキストも自動参照 *)
ClaudeUpdateDirective["上で議論されている内容をスキルに反映して"]

(* 引数なし: ソースコードとの整合性チェック *)
ClaudeUpdateDirective[]

(* プロジェクトローカルに反映 *)
ClaudeUpdateDirective["このプロジェクト固有のルールを追加", Scope -> "Local"]
```

### ディレクティブ書き込みガード

ディレクティブ（CLAUDE.md / rules / skills）の書き込み時には、以下の安全検証が自動的に行われます。

1. **サイズ退行チェック**: 既存ファイルの 40% 未満に縮小する書き込みは拒否されます
2. **タイトル整合性**: CLAUDE.md の先頭 `#` タイトルが変更される書き込みは拒否されます
3. **スキル名保持**: SKILL.md の `name:` 行が消滅する書き込みは拒否されます

ドキュメント書き込み時にも同様のガードが適用され、README.md のタイトルがパッケージ名と一致しない場合やサイズが大幅に縮小する場合は拒否されます。

### ディレクティブ・リポジトリと投影レイヤー（ClaudeDirectives）

`ClaudeDirectives` は、ディレクティブ（CLAUDE.md / rules / skills）を読み込み、**モデルの能力・ロール・タスクに応じて in-memory で動的に投影**する独立レイヤーです。ファイル形式は Claude Code 互換（`.claude/CLAUDE.md`, `rules/`, `skills/`）を維持しつつ、プロンプトに注入する内容（適用スキル・ルール・詳細度）を最適化します。claudecode.wl / NBAccess.wl への依存を持たない純 Wolfram Language 実装（Rule 11）であり、claudecode.wl 側から optional に呼び出される形で統合されます。

> **claudecode_directives との違い**: `claudecode_directives` は標準 rules/skills の**コンテンツ（中身）**を提供するパッケージです。一方 `ClaudeDirectives` はそれらの**読み込み・分類・投影・ハーネス生成を担う処理レイヤー**です。両者は補完的に機能します。

#### 設計上の不変条件

- ファイル形式は Claude Code 互換（`.claude/CLAUDE.md` / `rules` / `skills`）を維持します。
- in-memory の投影だけをモデルサイズ・ロール・タスクに応じて可変にします。
- claudecode.wl / NBAccess.wl へ一切の依存を持ちません（Rule 11）。
- claudecode.wl 側からこのパッケージを optional に呼び出す形で統合します。

#### モデル能力テーブル

`$ClaudeModelCapabilities` は `{provider, model}` の tuple をキーに、各モデルの能力を保持する Association です。

| フィールド | 説明 |
|---|---|
| `"ContextWindow"` | トークン数で表したコンテキスト長 |
| `"Class"` | `"Heavy-Cloud"` / `"Heavy-Local"` / `"Mid-Local"` / `"Light-Cloud"` / `"Light-Local"` |
| `"DefaultMode"` | 既定の投影モード（`"Full"` / `"Summary"` / `"Index"` / `"Lazy"`） |
| `"Strengths"` | 得意分野（`"Code"`, `"Reasoning"`, `"Search"`, `"ToolUse"` 等） |
| `"PreserveThinking"` | 思考ブロックを保持するか（`True`/`False`） |
| `"Paid"` | 課金 API か否か（`True`/`False`） |

provider 名は以下のように分類されます。

| provider | 種別 | 課金 |
|---|---|---|
| `"claudecode"` | Claude Code CLI（Opus 等） | なし（サブスクリプション） |
| `"anthropic"` | Anthropic API | あり |
| `"openai"` | OpenAI API | あり |
| `"lmstudio"` | ローカル LLM（LM Studio 等） | なし |

これにより、同じ Opus でも CLI 版（`"claudecode"`, 課金なし）と API 版（`"anthropic"`, 課金あり）を**別モデルとして両方登録**できます（`lm-studio` は `lmstudio` に provider 名が正規化されます）。

```mathematica
(* モデル能力を追加・更新（tuple キー・String キー両対応） *)
ClaudeRegisterModelCapability[{"anthropic", "claude-opus-4-6"},
  <|"ContextWindow" -> 200000, "Class" -> "Heavy-Cloud",
    "DefaultMode" -> "Full", "PreserveThinking" -> True, "Paid" -> True|>]

(* モデル名から能力 Association を取得（未登録は保守的既定値を返す） *)
ClaudeResolveModelCapability["claude-opus-4-6"]
(* 未登録: ContextWindow 32000, DefaultMode "Summary" を返す *)

(* 既定の投影モードのみ取得 *)
ClaudeResolveModelMode["claude-opus-4-6"]

(* ContextWindow（トークン数）のみ取得 *)
ClaudeResolveModelContextWindow["claude-opus-4-6"]
```

`$ClaudeRoleDefaultModels` は `Role -> モデル名` のマッピングで、ClaudeOrchestrator が worker を spawn する際に参照することを想定しています。

#### 投影モード（Full / Summary / Index / Lazy）

ディレクティブの投影は 4 段階の詳細度で行われます。

| モード | 説明 |
|---|---|
| `"Full"` | ディレクティブ全文を投影（大きいコンテキストのモデル向け） |
| `"Summary"` | 要約を投影 |
| `"Index"` | 索引（見出し・概要）のみ投影 |
| `"Lazy"` | 必要時のみ参照する遅延投影 |

モデルのコンテキスト長（`ContextWindow`）や `DefaultMode` に基づいて適切なモードが選択され、`ClaudeResolveDirectiveBundle` の `Mode -> Automatic` 指定時に自動決定されます。

#### ロール対応のスキル・ルール選択

ロール（Role）は `"Plan"` / `"Draft"` / `"Verify"` / `"Commit"` / `"Explore"` / `"Reduce"` / `None` のいずれかで、マルチエージェント・オーケストレーションにおける役割を表します。ロールに応じて優先スキル・既定モード・スキル上限が変化します。

| 設定変数 | 説明 |
|---|---|
| `$ClaudeSkillRolePolicy` | `Role -> {優先スキル名}` のマッピング。`iScoreSkill` が該当スキルに +6 加点します |
| `$ClaudeRoleDefaultMode` | `Role -> 既定 Mode`。`ClaudeResolveDirectiveBundle` で `Mode === Automatic` のとき優先採用されます |
| `$ClaudeRoleMaxSkills` | `Role -> 既定スキル上限`。`MaxSkills -> Automatic` のとき採用されます |
| `$ClaudeAlwaysOnRules` | タスク内容に関係なく常時注入される rule 名のリスト（セキュリティ・基本マナー系） |

```mathematica
(* task hint に関連するスキルをスコアリングして並べ替えて返す *)
ClaudeSelectSkillsForTask[repo, "PDE で熱伝導を解きたい",
  "Role" -> "Draft", "MaxSkills" -> 5,
  "ModelStrengths" -> {"Code", "Reasoning"}]

(* role ごとの always-on rules を選別 *)
ClaudeSelectRulesForRole[repo, "Verify"]

(* task hint に関連する rules を選別（always-on は無条件で含む） *)
ClaudeSelectRulesForTask[repo, "Excel を UTF-8 で読み込む",
  "Role" -> "Draft", "MaxRules" -> 8, "MinScore" -> 1]
```

- `ClaudeSelectSkillsForTask[repo, taskHint, opts]` — task hint に関連するスキルをスコアリングして上位を返します。`opts`: `"Role"`, `"MaxSkills"`（既定 5）, `"ModelStrengths"`。
- `ClaudeSelectRulesForRole[repo, role]` — role ごとの always-on rules を返します（後方互換のため `Lookup[repo, "Rules", {}]` を返します）。
- `ClaudeSelectRulesForTask[repo, taskHint, opts]` — `$ClaudeAlwaysOnRules` の rule は無条件で含めつつ、その他は frontmatter の keywords / paths と TaskHint の交差度でスコア化して上位を採用します。`opts`: `"Role"`, `"MaxRules"`（既定 8）, `"MinScore"`（既定 1）。

#### Directive Bundle と投影テキストの生成

```mathematica
(* task / role / model に応じた directive bundle を解決 *)
bundle = ClaudeResolveDirectiveBundle[
  "Role" -> "Draft",
  "Model" -> "claude-opus-4-6",
  "Mode" -> Automatic,
  "TaskHint" -> "成績データを分析するコードを書いて",
  "TokenBudget" -> Automatic]

(* bundle を prompt 用文字列に投影 *)
promptText = ClaudeProjectDirectives[bundle]

(* 明示モードで投影 *)
ClaudeProjectDirectives[bundle, "Summary"]
```

`ClaudeResolveDirectiveBundle[opts]` の返り値は以下のフィールドを持つ Association です。

| フィールド | 説明 |
|---|---|
| `"ClaudeMD"` | CLAUDE.md 本文（または投影版） |
| `"ActiveRules"` | 採用された rule のリスト |
| `"ActiveSkills"` | 採用された skill のリスト |
| `"ProjectionMode"` | 決定された投影モード |
| `"TokenBudget"` | トークン予算 |
| `"DirectiveMeta"` | メタ情報 |

関連ユーティリティ:

- `ClaudeDirectiveTokenEstimate[text]` — 文字列のトークン数概算（英日混在を考慮し `StringLength/3` で近似）。
- `ClaudeBuildDirectivePromptForRole[role, modelName, taskHint]` — 1 行で directive 投影テキストを返す統合エントリ（ClaudeOrchestrator の worker BuildContext から呼ばれる想定）。
- `ClaudeBuildDirectivePromptForSingle[modelName, taskHint]` — 単一エージェント（claudecode の `ClaudeEval` / `iAdapterBuildPrompt`）用の投影テキストを返す（Role は `None` 扱い）。

#### リポジトリの読み込みとキャッシュ

| 関数 / 変数 | 説明 |
|---|---|
| `$ClaudeDirectiveRepository` | 読み込み済みリポジトリのキャッシュ Association（`Root`, `ClaudeMD`, `Rules`, `Skills`, `LoadedAt`） |
| `ClaudeFindDirectiveRoots[]` | `.claude` / Claude Directives ディレクトリの候補を探索し、実在するもののリストを返す |
| `ClaudeLoadDirectiveRepository[]` / `[root]` | 自動探索またはディレクトリ指定で読み込み（結果は `$ClaudeDirectiveRepository` にキャッシュ） |
| `ClaudeInvalidateDirectiveCache[]` | キャッシュを空にして再読込を強制 |
| `ClaudeDirectivesParseFrontmatter[text]` | SKILL.md 先頭の YAML frontmatter を解析（`<|"Frontmatter"->..., "Body"->...|>` を返す） |

#### リポジトリ・インベントリとマニフェスト

正規ディレクティブ・リポジトリの内容を機械可読な形で列挙・要約する関数群です（Phase 1.0）。

```mathematica
(* 正規ディレクティブ root を解決（Automatic は自動探索） *)
root = ClaudeResolveDirectiveRoot[Automatic]

(* ファイル単位のインベントリ（ソート済みリスト） *)
inv = ClaudeDirectiveFileInventory[root]

(* リポジトリ・マニフェスト（ハッシュ付き） *)
manifest = ClaudeDirectiveRepositoryManifest[root]

(* マニフェストハッシュ文字列のみ *)
hash = ClaudeDirectiveRepositoryHash[root]
```

- `ClaudeResolveDirectiveRoot[Automatic]` — `ClaudeFindDirectiveRoots` 経由で正規 root を解決します。存在しなければ `Failure["DirectiveRootNotFound"]` を返します。`ClaudeResolveDirectiveRoot[root]` は明示 root の検証を行います。
- `ClaudeDirectiveFileInventory[root]` — 各ファイル記録のソート済みリストを返します。各記録は固定スキーマ（`Role`, `RelativePath`, `LogicalPath`, `AbsolutePath`, `ContentHash`, `ByteCount`, `LineCount`, `Name`, `Title`, `Description`, `FrontMatter`, `Paths`, `TokenEstimate`, `ModifiedTime`）を持ち、`Role` は `RootInstruction` / `Rule` / `Skill` / `Other` のいずれかです。オプション `"IncludeOther"` で rule/skill 以外のファイルを含めるか制御します。
- `ClaudeDirectiveRepositoryInventory[root]` — `ClaudeDirectiveFileInventory[root]` の別名です。
- `ClaudeDirectiveRepositoryManifest[root]` — `Kind`, `CanonicalFormat`, `Root`, `Files`（インベントリ）, `FilesCount`, `RulesCount`, `SkillsCount`, `ManifestHash`, `CreatedAt`, `Generator` を持つ Association を返します。`ManifestHash` はソート済みの `RelativePath` / `ContentHash` ペアのみに依存し、`ModifiedTime` や `TokenEstimate` の変化に対して安定です。
- `ClaudeDirectiveRepositoryHash[root]` — `ManifestHash` 文字列のみを返します。

#### ルールの派生メタデータと分類

正規ルールの frontmatter は説明文・トリガーを持たない設計のため、見出し（Title）と paths から決定論的に派生させます（Phase 1.1a）。

```mathematica
(* rule 記録から Codex ハーネス用の派生メタデータを導出 *)
ClaudeDirectiveRuleDerivedMetadata[ruleRecord]

(* rule をハーネス実体化向けに分類 *)
ClaudeDirectiveClassifyRule[ruleRecord]
```

- `$CodexRuleLargeByteThreshold` — rule を `"large"` と分類するバイト境界（既定 8192）。
- `ClaudeDirectiveRuleDerivedMetadata[ruleRecord]` — `Title`, `Summary`, `Description`, `Trigger`, `DescriptionSource`（`"derived-from-paths-and-heading"` / `"override"` / `"fallback"`）, `Paths` を返します。オプション `"RuleMetadataOverrides"` で rule Name をキーとした個別オーバーライドを供給できます。
- `ClaudeDirectiveClassifyRule[ruleRecord]` — `Scope`（`"always-on"` / `"task-specific"`）, `SizeClass`（`"small"` / `"large"`）, `CommandPolicy`, `InlineSummaryInAgentsMd`, `Reason` を返します。オプション: `"AlwaysOnRules"`, `"RuleLargeByteThreshold"`, `"RuleMetadataOverrides"`。

#### ハーネス実体化（Codex / Claude CLI）

単一の正規ディレクティブ・リポジトリから、複数の CLI 用ハーネスを生成・実体化できます（Phase 1.1b）。**正規リポジトリ自体は決して変更されません。**

```mathematica
(* ドライラン: ファイルを書かずに実体化計画を計算 *)
plan = ClaudeDirectiveHarnessPlan[bundle, "Codex"]   (* "Codex" | "ClaudeCLI" *)

(* Codex ハーネスを実体化 *)
ClaudeDirectiveMaterializeCodexHarness[bundle, targetDir]

(* ドライランで計画のみ取得 *)
ClaudeDirectiveMaterializeCodexHarness[bundle, targetDir, DryRun -> True]

(* Claude CLI ハーネスを実体化（正規ファイルの逐語コピー） *)
ClaudeDirectiveMaterializeClaudeHarness[bundle, targetDir]
```

- `ClaudeDirectiveHarnessPlan[bundle, target]` — ファイルを書かずに実体化計画を返します。`target` は `"Codex"` または `"ClaudeCLI"`。計画には `Target`, `HarnessMaterializationMode`, `DirectiveRepositoryManifestHash`, `SourceVaultSnapshotId`, `AgentsMd`, `Index`, `GeneratedSkills`, `CommandPolicyRules`, `ProvenanceFiles`, `Warnings` が含まれます。
- `ClaudeDirectiveHarnessProvenanceHeader[meta]` — 生成 AGENTS.md 先頭に置く HTML コメント形式の provenance ヘッダを返します。
- `ClaudeDirectiveMaterializeCodexHarness[bundle, targetDir]` — `ClaudeDirectiveHarnessPlan` を実行し、`.agents/skills/<name>/SKILL.md`、`.agents/directive-index.json`、`AGENTS.md`、provenance ファイルをこの固定順で書き込みます。返り値は実体化レポート（`WrittenFiles`, `AgentsMd`, `Index`, `GeneratedSkills`, `ProvenanceFiles`, `Warnings`, `Plan`）。`DryRun -> True` では何も書かず計画を返します。
- `ClaudeDirectiveMaterializeClaudeHarness[bundle, targetDir]` — 正規リポジトリから Claude CLI ハーネス（`$ClaudeCLIHarnessMode -> "Generated"`）を実体化します。`.claude/CLAUDE.md`、`.claude/rules/<name>.md`、`.claude/skills/<name>/SKILL.md` を正規ファイルの逐語コピーとして書き込みます。加えて `.claude/sourcevault-provenance.json` を書きます。`DryRun -> True` で計画のみ返します。

#### マイグレーション・ゲート

正規ディレクティブ・リポジトリと、従来の `$ClaudeWorkingDirectory/.claude/` ハーネスとの差分を、正規化した論理パスで比較・診断します（Phase 2.5）。

```mathematica
(* 正規リポジトリと従来 .claude/ ハーネスの生比較 *)
ClaudeDirectiveCompareCanonicalAndClaudeHarness[directiveRoot, claudeDir]

(* 移行ゲートのレポート *)
report = ClaudeDirectiveMigrationReport[directiveRoot, claudeDir]
```

- `ClaudeDirectiveCompareCanonicalAndClaudeHarness[directiveRoot, claudeDir]` — `CLAUDE.md` / `rules/<name>.md` / `skills/<name>/SKILL.md` を正規化論理パスで比較し、`CanonicalEquivMap`, `LegacyEquivMap`, `FilesOnlyInCanonical`, `FilesOnlyInLegacy`, `FilesChanged`, `LegacyHarnessOnlyFiles`, `CanonicalDirExists`, `LegacyDirExists` を返します。
- `ClaudeDirectiveMigrationReport[directiveRoot, claudeDir]` — 従来 `.claude/` ハーネスが正規リポジトリと等価かを判定します。返り値の `Status` は `"Equivalent"` / `"Diverged"` / `"LegacyOnly"` / `"CanonicalOnly"`。Claude CLI を Generated モードに切り替えるには Status が `"Equivalent"` であるか、手動承認が必要です。

#### 公開 API 一覧（ClaudeDirectives）

| 関数 / 変数 | 説明 |
|---|---|
| `$ClaudeDirectivesVersion` | パッケージバージョン文字列 |
| `$ClaudeModelCapabilities` | `{provider, model}` → 能力 Association |
| `$ClaudeRoleDefaultModels` | Role → 既定モデル |
| `$ClaudeSkillRolePolicy` | Role → 優先スキル名一覧 |
| `$ClaudeRoleDefaultMode` | Role → 既定投影モード |
| `$ClaudeRoleMaxSkills` | Role → 既定スキル上限 |
| `$ClaudeAlwaysOnRules` | 常時注入される rule 名リスト |
| `$CodexRuleLargeByteThreshold` | large 判定バイト境界（既定 8192） |
| `$ClaudeDirectiveRepository` | 読み込み済みリポジトリのキャッシュ |
| `ClaudeRegisterModelCapability` | モデル能力の追加・更新 |
| `ClaudeResolveModelCapability` | モデル名 → 能力 Association |
| `ClaudeResolveModelMode` | モデル名 → 既定投影モード |
| `ClaudeResolveModelContextWindow` | モデル名 → ContextWindow |
| `ClaudeFindDirectiveRoots` | ディレクティブ root 候補の探索 |
| `ClaudeLoadDirectiveRepository` | リポジトリの読み込み |
| `ClaudeInvalidateDirectiveCache` | キャッシュ無効化 |
| `ClaudeDirectivesParseFrontmatter` | SKILL.md frontmatter 解析 |
| `ClaudeResolveDirectiveBundle` | task/role/model 別の bundle 解決 |
| `ClaudeProjectDirectives` | bundle を prompt 文字列に投影 |
| `ClaudeDirectiveTokenEstimate` | トークン数概算 |
| `ClaudeSelectSkillsForTask` | task hint 別のスキル選別 |
| `ClaudeSelectRulesForRole` | role 別の always-on rules |
| `ClaudeSelectRulesForTask` | task hint 別の rules 選別 |
| `ClaudeBuildDirectivePromptForRole` | ロール付き投影テキスト（統合エントリ） |
| `ClaudeBuildDirectivePromptForSingle` | 単一エージェント用投影テキスト |
| `ClaudeResolveDirectiveRoot` | 正規 root の解決 |
| `ClaudeDirectiveFileInventory` / `ClaudeDirectiveRepositoryInventory` | ファイル単位インベントリ |
| `ClaudeDirectiveRepositoryManifest` | リポジトリ・マニフェスト |
| `ClaudeDirectiveRepositoryHash` | ManifestHash 文字列 |
| `ClaudeDirectiveRuleDerivedMetadata` | rule 派生メタデータ |
| `ClaudeDirectiveClassifyRule` | rule の分類 |
| `ClaudeDirectiveHarnessPlan` | ハーネス実体化計画（dry-run） |
| `ClaudeDirectiveHarnessProvenanceHeader` | AGENTS.md provenance ヘッダ |
| `ClaudeDirectiveMaterializeCodexHarness` | Codex ハーネスの実体化 |
| `ClaudeDirectiveMaterializeClaudeHarness` | Claude CLI ハーネスの実体化 |
| `ClaudeDirectiveCompareCanonicalAndClaudeHarness` | 正規/従来ハーネスの生比較 |
| `ClaudeDirectiveMigrationReport` | 移行ゲートのレポート |

### Think トリガー自動挿入

日本語の励まし表現が自動的に Claude の思考トリガーに変換されます。

| 日本語表現 | 変換先 | 思考レベル |
|---|---|---|
| 死ぬ気で考えろ、本気出せ、全力で、徹底的に | `ultrathink` | 最大（32K トークン） |
| よく考えて、じっくり、慎重に、がんばれ、丁寧に | `think hard` | 中程度（10K トークン） |
| 考えてみて、少し考えて | `think` | 基本（4K トークン） |

ClaudeUpdatePackage 等の呼び出し時にも、指示文中の日本語表現が自動的にトリガーワードに変換されます。

### ドキュメント生成・更新の高度制御

`ClaudeUpdateDocumentation` は柔軟なモード制御、部分更新機能、そして差分の基準を切り替える `Baseline` オプションを提供します。

```mathematica
(* 基本的なドキュメント更新（既存ファイルを更新） *)
ClaudeUpdateDocumentation["MyPackage", "新機能の説明を追加"]

(* 新規作成モード（既存内容を無視して新規作成） *)
ClaudeUpdateDocumentation["MyPackage", "setup.mdを作成",
  TargetFiles -> {"setup.md"}, Mode -> "Create"]

(* 特定ファイルのみ更新（.md 拡張子あり） *)
ClaudeUpdateDocumentation["MyPackage", "API仕様を更新",
  TargetFiles -> {"api.md"}]

(* 拡張子なしでも自動補完されます（"api" → "api.md"） *)
ClaudeUpdateDocumentation["MyPackage", "API仕様を更新",
  TargetFiles -> {"api"}]

(* 複数ファイルを同時更新（拡張子あり・なし混在も可） *)
ClaudeUpdateDocumentation["MyPackage", "全体的な改善",
  TargetFiles -> {"api", "user_manual", "README"}]
```

| オプション | デフォルト | 説明 |
|---|---|---|
| `Mode` | `"Update"` | `"Update"`: 既存を更新、`"Create"`: 新規作成（既存内容無視） |
| `Baseline` | `"LastDocUpdate"` | 差分の基準。`"LastDocUpdate"`: 直近の `_documentupdate` バックアップ（従来動作）、`"Github"`: GitHub コミット版ソース＋`_info/design` 新規内容 |
| `TargetFiles` | `Automatic` | 更新対象ファイルのリスト。`Automatic` で全ドキュメントを対象。許可されるファイル名は下記参照。 |
| `References` | `{}` | 参考文献リスト（README.md に反映） |
| `Demos` | `{}` | デモ動画・使用例 URL（README.md に反映） |
| `Disclaimer` | `{}` | 免責事項（README.md に反映） |

#### ドキュメント更新チェーンの多重起動防止

`ClaudeUpdateDocumentation` / `ClaudeCreateDocumentation` は非同期コールバック連鎖で進行します。同一パッケージに対して 2 本の連鎖が同時起動すると、同じ docs/ と履歴を同時更新してデータが破損する危険があります。これを防ぐため、タイムスタンプ方式の多重起動ガードが実装されています。

二重起動を試みた場合は以下のメッセージが表示されます。

```
"MyPackage" のドキュメント更新が既に進行中です。完了を待ってから再実行してください。
```

チェーンが異常終了してガードが解放されなかった場合（フリーズ・カーネル再起動等）でも、`$ClaudeDocUpdateStaleSeconds`（デフォルト 1800 秒）を超えると自動的に解放されます。

```mathematica
(* stale 上限の変更例 *)
$ClaudeDocUpdateStaleSeconds = 3600  (* 1 時間に延長 *)
```

| 変数 | デフォルト | 説明 |
|---|---|---|
| `$ClaudeDocUpdateStaleSeconds` | `1800` | ドキュメント更新チェーンのガードの stale 上限（秒）。この秒数を超えたら異常終了とみなして再スケジュールを許可する。 |

#### Baseline オプション（差分基準の切り替え）

`Baseline` オプションは、ドキュメント更新時に「何を基準にソース差分を取るか」を制御します。指定できる値は `"LastDocUpdate"`（既定）と `"Github"` の 2 種類で、これら以外の値を指定した場合は自動的に `"LastDocUpdate"` にフォールバックします。

**`Baseline -> "LastDocUpdate"`（デフォルト・従来動作）**

直近の `_documentupdate` バックアップを基準にソース差分を計算します。前回のドキュメント更新以降に変更されたコードだけを抽出してプロンプトに添付するため、効率的かつ焦点を絞った更新が行えます。前回バックアップが見つからない場合はエラーになり、`Baseline -> "Github"` の使用、または先に `ClaudeCreateDocumentation` を実行することが促されます。

```mathematica
(* 明示的に従来動作を指定 *)
ClaudeUpdateDocumentation["MyPackage", "更新指示",
  Baseline -> "LastDocUpdate"]
```

**`Baseline -> "Github"`（GitHub コミット版基準）**

`$packageDirectory/GithubRepositories/<packageName>` に置かれた GitHub コミット版ソースを基準にソース差分を計算します。これにより、「最後にコミットした状態」から現在のローカルソースまでの全変更がドキュメントへ反映されます。`_documentupdate` バックアップが存在しない場合でも利用できる点が大きな利点です。

さらにこのモードでは、ソース差分だけでは読み取りにくい設計意図を補うため、`_info/design` 配下の**新規設計内容**（`iComputeNewDesignContent` が抽出）が、`api.md` 以外のドキュメント（README を含む）のプロンプトに自動添付されます。コードの差分に加えて設計ノートの新しい記述も加味され、新しくなった部分の説明をより充実させることができます。

```mathematica
(* GitHub コミット版を基準に、design 新規内容も加味して更新 *)
ClaudeUpdateDocumentation["MyPackage", Baseline -> "Github"]

(* 指示文と併用 *)
ClaudeUpdateDocumentation["MyPackage", "コミット以降の変更を反映",
  Baseline -> "Github"]
```

このとき自動的に付与される指示は概ね「前回のドキュメント更新以降のソースコード変更を反映してドキュメントを更新し、追加された関数・オプションの説明を追加し、削除されたものの説明を削除し、コードの差分だけでなく添付された design の新規内容も加味して新しくなった部分の記述を充実させる」という内容です。

#### TargetFiles の許可リストと拡張子自動補完

`TargetFiles` に指定できるファイルは以下の 5 種類に限定されています。

| ファイル名 | 拡張子省略形 | 説明 |
|---|---|---|
| `"api.md"` | `"api"` | API リファレンス |
| `"README.md"` | `"README"` | パッケージ概要・セットアップ手順 |
| `"setup.md"` | `"setup"` | インストール手順書 |
| `"user_manual.md"` | `"user_manual"` | ユーザーマニュアル |
| `"example.md"` | `"example"` | 使用例集 |

拡張子（`.md`）を省略した形式（例: `"api"`, `"user_manual"`）を指定すると、自動的に `.md` が補完されます。許可リスト外のファイル名を指定した場合は `ClaudeUpdateDocumentation::badtarget` メッセージが表示され、処理は中断されます。

```mathematica
(* 不正なファイル名を指定した場合のエラー例 *)
ClaudeUpdateDocumentation["MyPackage", "更新指示",
  TargetFiles -> {"invalid_file.md"}]
(* → ClaudeUpdateDocumentation::badtarget:
       TargetFiles に不正なファイル名 invalid_file.md が含まれています。
       許可されるファイル: api.md, README.md, setup.md, user_manual.md, example.md *)
```

### [実験的] LLM 適用グラフ (LLMGraph)

`ClaudeEval` や `ClaudeQuery` などの LLM 呼び出しを実行すると、各呼び出しがノードとしてノートブック固有の DAG（有向非巡回グラフ）に自動記録されます。このグラフ構造は Mathematica 14.2 で導入された `LLMGraph` と類似の設計を採用しています（将来的には `LLMGraph` そのものとの統合を目指しますが、現状では独自実装）。

この実装は、`claudecode_info/design/` にある 1992-WOOC'92.pdf および 1993-WOOC'93「信号処理に向いたオブジェクトモデルの提案と応用」で議論されている、データの構造を保ったまま定義域ごとに適応的に処理を適用するモデルを下敷きにしています。

#### アーキテクチャ

グラフデータはノートブックの TaggingRules に圧縮保存され、フルレスポンスやコードは外部キャッシュ（`$UserBaseDirectory/ClaudeCode/llmgraph_cache/`）に WXF 形式で保存されます。インメモリキャッシュにより、頻繁なアクセスでも Compress/Uncompress のオーバーヘッドを回避します。

各ノード（L1）は命令テキスト（先頭 500 文字）、応答サマリー（先頭 300 文字）、アクセスレベル（ClaudeCode / ClaudeAPI / LMStudio / WolframLLM / Local）、ステータス（Processing / Completed / Failed / Invalidated）などを保持します。ノード間の関係はエッジタイプ（ContextInheritance: セッション内連続、DataFlow: 出力→入力依存、Sequential: L2 コードブロック間）として記録されます。

L2 グラフはコードブロック単位の追跡を提供し、L1 ノードに紐づいた詳細な実行状態を記録します。

#### 基本的な使い方

```mathematica
(* LLMGraph の DAG 可視化 *)
NotebookLLMGraphPlot[]

(* 全ノードの統計表示 *)
NotebookLLMGraphSummary[]

(* グラフの整合性検証 *)
NotebookLLMGraphValidate[]

(* 特定ノードのフルレスポンス取得 *)
NotebookLLMGraphFetchResponse["history-3"]

(* L2 グラフ（コードブロック単位）の取得・可視化 *)
NotebookLLMGraphFetchL2[EvaluationNotebook[], "history-3"]
NotebookLLMGraphPlotL2[EvaluationNotebook[], "history-3"]

(* エラーのある L1 ノード一覧 *)
NotebookLLMGraphErrors[]
```

`NotebookLLMGraphPlot` はノードをアクセスレベルに応じて色分けして表示します。DAG ノードのカテゴリと色の対応は以下の通りです。

| カテゴリ | アクセスレベル | 色 |
|---|---|---|
| `"cli"` / `"cli-vision"` | Public | 青 |
| `"CloudLLM"` | Cloud | 緑系 |
| `"VisionLLM"` | Vision | 紫系 |
| その他 | Compute | グレー系 |

#### 再実行・無効化

```mathematica
(* 特定ノードの再実行（下流ノードが自動的に Invalidated にマークされる） *)
NotebookLLMGraphRerun[EvaluationNotebook[], "history-3"]

(* 下流ノードのみ無効化 *)
NotebookLLMGraphInvalidateDownstream[EvaluationNotebook[], "history-3"]
```

#### スレッド抽出・再適用

特定のノードに至る実行パス（祖先チェーン）を Thread オブジェクトとして抽出し、別のファイルに対して同じ処理を再適用できます。

```mathematica
(* 実行スレッドを抽出 *)
thread = NotebookLLMGraphExtractThread["history-5"]

(* 別のファイルに同じ処理を適用 *)
NotebookLLMGraphApplyThread[thread, "C:\\...\\another_notebook.nb"]

(* DryRun で実行計画を確認 *)
NotebookLLMGraphApplyThread[thread, "another.nb", "DryRun" -> True]
```

Thread オブジェクトには各ノードの PrivacySpec が保持されており、`PrivacySpec >= 0.9` のノードは自動的に `$ClaudePrivateModel`（LM Studio 等）で実行されます。

#### DAG ジョブ実行 API

LLMGraph の実行をプログラマティックに制御するための低レベル API も提供されています。

```mathematica
(* DAG ジョブの作成 *)
job = LLMGraphDAGCreate[nodes, taskDescriptor]

(* ジョブのステータス取得 *)
LLMGraphDAGStatus[job]

(* ジョブのキャンセル *)
LLMGraphDAGCancel[job]

(* ジョブの停止（処理中ノードを安全に停止） *)
LLMGraphDAGStop[job]

(* ジョブの再試行（失敗ノードを再スケジュール） *)
LLMGraphDAGRetry[job]

(* 指定ノードの handler を差し替えた新 DAG を構成・起動 *)
LLMGraphDAGRebuild[job]
LLMGraphDAGRebuild[job, nodeIds]

(* LLMGraph ジョブの実行（高レベル） *)
LLMGraphExecute[graphSpec]

(* 実行中ジョブのステータス取得 *)
LLMGraphExecuteStatus[jobId]

(* 実行中ジョブのキャンセル *)
LLMGraphExecuteCancel[jobId]
```

#### LLMGraph 並列度の制御（$LLMGraphMaxConcurrency）

`$LLMGraphMaxConcurrency` はカテゴリ別の最大並列実行数をグローバルに制御します。DAG の各ノードは抽象カテゴリに分類され、同一カテゴリのノードが同時に実行できる数を制限します。

```mathematica
(* カテゴリ別デフォルト値 *)
$LLMGraphMaxConcurrency["cli"]        (* = 4 : Claude CLI テキスト単体呼び出し *)
$LLMGraphMaxConcurrency["cli-vision"] (* = 1 : Claude CLI 画像付き呼び出し *)

(* グローバルデフォルトを変更する例 *)
$LLMGraphMaxConcurrency["cli"] = 2     (* CLI 呼び出しを同時2本に制限 *)
```

並列度の解決は以下の優先順位で行われます。

1. `taskDescriptor["maxConcurrency"][abstractCat]` — ジョブ固有のオーバーライド（最優先）
2. `$LLMGraphMaxConcurrency[abstractCat]` — グローバルデフォルト
3. `1` — フォールバック（設定なし）

ジョブ作成時に `taskDescriptor` にカテゴリマップと並列度オーバーライドを指定することで、ジョブ単位での細かな制御も可能です。`taskDescriptor["categoryMap"]` には具体カテゴリ（例: `"cli"`）から抽象カテゴリへのマッピングを指定でき、複数の具体カテゴリを同一の抽象カテゴリとして扱って並列度を共有させることができます。

```mathematica
(* taskDescriptor の例: カテゴリマッピングと並列度オーバーライドを指定 *)
taskDesc = <|
  "categoryMap" -> <|"cli" -> "Public", "cli-vision" -> "Public"|>,
  "maxConcurrency" -> <|"Public" -> 2|>
|>;
job = LLMGraphDAGCreate[nodes, taskDesc]
```

#### 公開 API 一覧

| 関数 | 説明 |
|------|------|
| `NotebookLLMGraph[nb]` | グラフ全体を取得（キャッシュ優先） |
| `NotebookLLMGraphBuild[nb]` | セッション履歴から強制再構築 |
| `NotebookLLMGraphNodes[nb]` | 全ノードの Association |
| `NotebookLLMGraphPlot[nb]` | DAG 可視化（カテゴリ別色分け） |
| `NotebookLLMGraphValidate[nb]` | 整合性検証 |
| `NotebookLLMGraphFetchResponse[nb, nodeID]` | フルレスポンス取得 |
| `NotebookLLMGraphSubSteps[nb, nodeID]` | 内部ステップ履歴 |
| `NotebookLLMGraphSummary[nb]` | Status / L2 統計 Dataset |
| `NotebookLLMGraphFetchL2[nb, nodeID]` | L2 グラフ取得 |
| `NotebookLLMGraphPlotL2[nb, nodeID]` | L2 グラフ可視化 |
| `NotebookLLMGraphErrors[nb]` | L2 エラーノード一覧 |
| `NotebookLLMGraphUpdateL2Status[nb, l1ID, l2ID, status, msg]` | L2 ステータス手動更新 |
| `NotebookLLMGraphRerun[nb, nodeID]` | ノード再実行 |
| `NotebookLLMGraphInvalidateDownstream[nb, nodeID]` | 下流無効化 |
| `NotebookLLMGraphExtractThread[nb, nodeID]` | スレッド抽出 |
| `NotebookLLMGraphApplyThread[thread, target]` | スレッド再適用 |
| `LLMGraphDAGCreate[nodes, taskDesc]` | DAG ジョブの作成 |
| `LLMGraphDAGStatus[job]` | DAG ジョブのステータス取得 |
| `LLMGraphDAGCancel[job]` | DAG ジョブのキャンセル |
| `LLMGraphDAGStop[job]` | DAG ジョブの停止 |
| `LLMGraphDAGRetry[job]` | DAG ジョブの再試行 |
| `LLMGraphDAGRebuild[job]` / `LLMGraphDAGRebuild[job, nodeIds]` | 指定ノードの handler を差し替えた新 DAG を構成・起動 |
| `LLMGraphExecute[graphSpec]` | LLMGraph ジョブの実行 |
| `LLMGraphExecuteStatus[jobId]` | LLMGraph ジョブのステータス取得 |
| `LLMGraphExecuteCancel[jobId]` | LLMGraph ジョブのキャンセル |
| `$LLMGraphMaxConcurrency` | カテゴリ別最大並列度の制御 |

### [実験的] プライバシー分割ファイル処理 (ClaudeProcessFile)

`ClaudeProcessFile` は LLMGraph の応用として、ノートブックファイル（.nb）のセルをプライバシーレベルに基づいて自動分割し、公開セルはクラウド LLM（Claude Code CLI）、秘匿セルはプライベート LLM（`$ClaudePrivateModel` で指定した LM Studio 等）で並列処理してマージします。

#### 動作フロー

`ClaudeEval` でノートブックファイルパスを含む指示を与えると自動検出（auto-dispatch）され、以下のフローが非同期で実行されます。

1. **auto-dispatch**: `.nb` パスを検出し、`ClaudeProcessFile` を自動起動
2. **Splitter**: Claude Code CLI（`--print` モード）で生プロンプトからファイルパス・保存指示を除去し、セル単位の変換指示を抽出
3. **NodeB** (公開セル): Claude Code CLI でクラウド LLM に公開セルを送信
4. **NodeA** (秘匿セル): `$ClaudePrivateModel` のローカル LLM に秘匿セルを送信（NodeB と並列実行）
5. **Merger**: 両ノードの結果を回収し、`NBMergeNotebookCells` で元のセル構造にマージして出力ファイルを保存

処理過程は LLMGraph 上に Fork/Join トポロジ（ContextInheritance + DataFlow エッジ）として記録されます。

#### 使い方

```mathematica
(* $ClaudePrivateModel の設定 *)
$ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://192.168.2.103:1234"};

(* ノートブックファイルの翻訳（auto-dispatch 経由） *)
ClaudeEval["C:\\...\\sample.nb
このファイルを英語に翻訳して、sample-translated.nb として保存してほしい。"]

(* 常体文変換 *)
ClaudeEval["C:\\...\\sample.nb
このファイルをである調の常体文に変換して、sample-dearu.nb として保存してほしい。"]

(* 処理完了後、LLMGraph で確認 *)
NotebookLLMGraphPlot[]
NotebookLLMGraphSummary[]
```

処理は非同期で実行され、`WindowStatusArea` にリアルタイム進捗が表示されます。カーネルはロックされないため、処理中もノートブックの操作が可能です。

#### LLMGraph 上のトポロジ

```
history-N: auto-dispatch (ContextInheritance)
  └──CI──→ history-N+1: Splitter (ClaudeCode)
                ├──DataFlow──→ history-N+2: NodeB (ClaudeCode, 公開セル)
                └──DataFlow──→ history-N+3: NodeA (LMStudio, 秘匿セル)
                                    │                    │
                                    └──DataFlow──→ history-N+4: Merger
                                                 ←──DataFlow──┘
```

#### 前提条件

- `$ClaudePrivateModel` が設定されていること（秘匿セルの処理先）
- 処理対象の .nb ファイルに NBAccess の Confidential タグ付きセルが含まれていること
- セルのプライバシーレベルは NBAccess の `iNBFileCellPrivacyLevel` により 3 段階（0.0: 公開、0.75: 依存、1.0: 秘匿）で判定されます

### NBAccess 分離原則検証

ClaudeCode は NBAccess パッケージとの適切な分離を維持するため、分離原則違反の自動検証・修正機能を提供します。

```mathematica
(* 分離原則違反の検査 *)
ClaudeCheckSeparation["MyPackage"]

(* 違反の自動修正 *)
ClaudeFixSeparation["MyPackage"]
```

検査対象は以下の10項目です：

1. **SystemCredential 直接利用**: `SystemCredential` の直接呼び出し
2. **CellObject 直接操作**: `NotebookWrite`/`NotebookRead`/`CellGroupData` 等の直接構築
3. **CellEpilog/CellProlog 直接操作**: セルイベントハンドラの直接設定
4. **NBAccess`Private` 関数呼び出し**: 内部関数への不正アクセス
5. **NBAccess 公開グローバル直接更新**: グローバル変数への直接代入
6. **EvaluationCell[]/CellPrint[] 直接使用**: フロントエンド関数の直接使用
7. **TaggingRules/CellTags 属性直接アクセス**: `CurrentValue`/`SetOptions` による属性操作
8. **CellObject の公開 API・戻り値・状態保持への漏洩**: CellObject の不適切な露出
9. **FrontEnd 状態操作**: `SelectionEvaluate`/`FrontEndTokenExecute` 等の直接使用
10. **NBAccess 公開グローバルの破壊的更新**: `AppendTo`/`AssociateTo` 等による直接更新

### ClaudeRuntime 統合（オプション）

[ClaudeRuntime](https://github.com/transreal/ClaudeRuntime) は claudecode とは独立したオプションパッケージです。ロードすると `ClaudeEval` のバックエンドとしてランタイムセッション管理機能が有効になり、ターン追跡・スナップショット管理・承認フローなどの高度な制御が可能になります。

#### ロードと基本的な使い方

```mathematica
(* ClaudeRuntime をロード（claudecode ロード後に実行） *)
<< ClaudeRuntime`

(* ロード後は ClaudeEval が自動的にランタイム経由で動作します *)
ClaudeEval["放物線運動のグラフを描いて"]

(* ランタイム一覧とステータス確認 *)
Dataset[KeyValueMap[
  Function[{id, rt}, <|
    "RuntimeId"   -> id,
    "Status"      -> rt["Status"],
    "TurnCount"   -> rt["TurnCount"],
    "Profile"     -> rt["Profile"],
    "LastFailure" -> Lookup[rt, "LastFailure", None]
  |>],
  ClaudeRuntime`Private`$iClaudeRuntimes
]]
```

#### ランタイムの状態フィールド

各 ClaudeRuntime インスタンスは以下の状態を保持します。

| フィールド | 説明 |
|---|---|
| `"RuntimeId"` | ランタイムの一意 ID |
| `"Status"` | 現在の状態（`"Idle"`, `"Running"`, `"Failed"` 等） |
| `"TurnCount"` | 実行したターン数 |
| `"Profile"` | ランタイムのプロファイル設定 |
| `"LastFailure"` | 最後の失敗情報（`None` または詳細 Association） |

#### NeedsApproval（承認フロー）

ClaudeRuntime が有効な場合、危険な操作（例: 内部変数の直接変更など、`NBAutoEvalProhibitedPatterns` に相当する操作）は `NeedsApproval` として検出され、自動実行がブロックされます。ノートブックには確認ダイアログまたは承認ボタンが表示され、ユーザーが明示的に承認した場合のみ実行されます。

```mathematica
(* 例: 内部変数の直接変更を試みると NeedsApproval が返る *)
ClaudeEval["Assign {} to ClaudeRuntime`Private`$iClaudeRuntimes"]
(* → NeedsApproval として処理がブロックされる *)

(* 承認して実行を続ける場合 *)
ClaudeApproveProposal[]
```

#### 主な API

```mathematica
(* ランタイムの起動 *)
ClaudeStartRuntime[]

(* ランタイム経由でコードを生成・実行 *)
ClaudeEvalViaRuntime["タスク"]

(* ランタイム経由でパッケージを更新 *)
ClaudeUpdatePackageViaRuntime["MyPackage", "更新指示"]

(* 承認待ち提案の承認 *)
ClaudeApproveProposal[]

(* スナップショット管理 *)
ClaudeRuntimeSnapshot[]            (* 現在の状態をスナップショット保存 *)
ClaudeRuntimeRestore["snapshotId"] (* スナップショットから復元 *)
ClaudeRuntimeListSnapshots[]       (* スナップショット一覧を表示 *)
ClaudeRuntimeRetry[]               (* 失敗したターンを再試行 *)

(* アダプタの構築（カスタム統合用） *)
ClaudeBuildRuntimeAdapter[opts]      (* ランタイムアダプタを構築 *)
ClaudeBuildTransactionAdapter[opts]  (* トランザクションアダプタを構築 *)

(* グローバル変数 *)
$UseClaudeRuntime      (* True でランタイム有効、False で従来モード *)
$ClaudeLastRuntimeId   (* 直前に使用したランタイムの ID *)
```

#### 後方互換性

`ClaudeRuntime` をロードしない場合、`claudecode` は従来どおりの動作を完全に維持します。また、`ClaudeRuntime` をロード済みでも `$UseClaudeRuntime = False` を設定することで、ランタイムを介さない従来モードに随時切り替えられます。

```mathematica
(* ClaudeRuntime をロード済みでも従来モードに切り替え *)
$UseClaudeRuntime = False
ClaudeEval["タスク"]  (* 従来どおり ClaudeCode CLI を直接使用 *)

(* ランタイムモードに戻す *)
$UseClaudeRuntime = True
```

| 状態 | 動作 |
|---|---|
| `ClaudeRuntime` 未ロード | 従来の `ClaudeEval` 動作（CLI 直接呼び出し） |
| `ClaudeRuntime` ロード済み + `$UseClaudeRuntime = True`（デフォルト） | ランタイム経由で実行、承認フロー有効 |
| `$UseClaudeRuntime = False` | 従来モード（`ClaudeRuntime` ロード済みでも無効化） |

### ClaudeOrchestrator 統合（オプション）

[ClaudeOrchestrator](https://github.com/transreal/ClaudeOrchestrator) は claudecode とは独立したオプションパッケージです。ロードすると `ClaudeEval` がオーケストレーター管理下の非同期実行モードに切り替わり、複数タスクのジョブキュー管理・rate-limit 自動待機・リトライスケジューリングが透過的に行われます。

#### ロードと基本的な使い方

```mathematica
(* ClaudeOrchestrator をロード（claudecode ロード後に実行） *)
<< ClaudeOrchestrator`

(* ロード後は ClaudeEval がオーケストレーター管理下で非同期実行されます *)
ClaudeEval["長時間かかる分析タスクを実行"]

(* rate-limit 状態の確認 *)
info = ClaudeRateLimitStatus[];
If[AssociationQ[info],
  Print["復旧予定: ", info["ResetsAt"]],
  Print["rate-limit なし"]]
```

#### ClaudeEval の非同期化

ClaudeOrchestrator をロードすると、`ClaudeEval` の動作が根本的に変わります。呼び出しはオーケストレーターのジョブキューに追加されて**即座に返り**、カーネルをブロックしません。以下の機能が自動的に有効になります。

- **ノンブロッキング実行**: `ClaudeEval` が呼び出されるとジョブキューへの登録のみ行い、すぐに制御を返します。
- **rate-limit 検出と自動待機**: `ClaudeRateLimitStatus[]` の `"ResetsAt"` フィールドが示す復旧予定時刻まで自動的に待機し、復旧後にタスクを再開します。
- **ジョブキュー管理**: 複数の `ClaudeEval` 呼び出しをオーケストレーターが順次・並列に管理します。
- **自動リトライスケジューリング**: 一時的な失敗（rate-limit・ネットワークエラー等）に対して自動リトライを行います。

```mathematica
(* 複数タスクを連続して投入 — オーケストレーターがキュー管理 *)
ClaudeEval["タスク1: データ前処理"]
ClaudeEval["タスク2: モデル学習"]
ClaudeEval["タスク3: 結果のグラフ化"]
(* 3つとも即座に返り、ノートブックは操作可能な状態を保つ *)
```

#### rate-limit 情報の活用

```mathematica
info = ClaudeRateLimitStatus[];
(* → <|
     "Detected"      -> DateObject[...],
     "ResetsAt"      -> DateObject[...],
     "RateLimitType" -> "five_hour",
     "HttpStatus"    -> 429,
     "Message"       -> "You've hit your limit..."
   |> *)

(* rate-limit でない場合は None が返る *)
ClaudeRateLimitStatus[]
(* → None *)

(* 手動でクリアする場合 *)
ClaudeRateLimitClear[]
```

#### 後方互換性

| 状態 | 動作 |
|---|---|
| ClaudeOrchestrator 未ロード | 従来の `ClaudeEval` 動作（CLI 直接呼び出し・ブロッキング） |
| ClaudeOrchestrator ロード済み | オーケストレーター管理下の非同期実行モード（ノンブロッキング・rate-limit 自動待機・リトライ有効） |

### SourceVault 連携（オプション）

[SourceVault](https://github.com/transreal/SourceVault) は claudecode とは独立したオプションパッケージで、`ClaudeEval` のディスパッチ経路に **PromptRouter ブリッジ**（Order 2 ディスパッチ）を追加します。SourceVault が提供するソース管理機能と組み合わせて、タスク文字列を ReadOnly な許可済み呼び出しに変換し、安全な実行経路を確立します。また、`ClaudeSpec` と連携した仕様書・審査・実装ワークフローの API も提供します。

#### 設計原則: hard dependency を持たない

claudecode.wl 本体は SourceVault に対して **hard dependency を持ちません**（rule 11）。SourceVault がロードされていない・無効化されている・提案を返さない・許可リスト外の頭部を提案した、いずれのケースでも `ClaudeEval` は従来どおりの自然言語ルーター（spec 5.3 / 24.3）で処理を継続します。

#### ロードと基本的な使い方

```mathematica
(* SourceVault をロード（claudecode ロード後、任意のタイミング） *)
<< SourceVault`

(* ロード後は ClaudeEval が PromptRouter 経由でディスパッチを試行します *)
ClaudeEval["パッケージ MyPackage のエクスポート一覧を取得"]
```

#### Order 2 ディスパッチの動作フロー

1. **アクティブ判定**: `SourceVaultPromptRouterActiveQ[]` を確認。`False` なら即座にフォールバック。
2. **提案取得**: `SourceVaultProposePromptRoute[task, optsList]` を呼び出し、`PromptRouteProposal` を受け取る。
3. **形式検証**: `"Status"` が `"Proposed"` であり、`"ProposedExpression"` が単一要素の `HoldComplete[expr]` であることを確認。
4. **頭部の許可リスト照合**: 頭部シンボルを `$iClaudeEvalProposalHeadAllowlist` と照合。
5. **評価と返却**: 許可リストに含まれる場合のみ `ReleaseHold` で評価。許可リスト外なら `NotDispatched`。

#### 制御フラグ

```mathematica
(* PromptRouter 経路全体の有効/無効 *)
$ClaudeEvalPromptRouterDispatch = Automatic

(* 自然言語ルーターとの実行順序 *)
$ClaudeEvalPromptRouterPreemptsNatural = True
```

| `$ClaudeEvalPromptRouterDispatch` | `$ClaudeEvalPromptRouterPreemptsNatural` | 動作 |
|---|---|---|
| `Automatic`（デフォルト） | `True`（デフォルト） | PromptRouter 先行 → 未提案なら自然言語ルーター |
| `Automatic` | `False` | 自然言語ルーター先行 → 未マッチなら PromptRouter |
| `False` | （無視） | PromptRouter を一切使わず、常に自然言語ルーターのみ |

#### 後方互換性

| 状態 | 動作 |
|---|---|
| SourceVault 未ロード | 従来の `ClaudeEval` 動作（自然言語ルーターのみ） |
| SourceVault ロード済み + `$ClaudeEvalPromptRouterDispatch = Automatic`（デフォルト） | PromptRouter 経由のディスパッチを試行、未提案時は自然言語ルーターへ |
| `$ClaudeEvalPromptRouterDispatch = False` | PromptRouter を完全に無効化 |

#### ChatGPT Codex モデルレジストリ

SourceVault は PromptRouter ブリッジに加えて、LLM provider のモデルレジストリを一元管理します。ChatGPT Codex provider のモデル名もこの仕組みで管理されます。

```mathematica
(* SourceVault をロード *)
Needs["SourceVault`"]

(* Codex のモデルカタログを取得してレジストリを更新 *)
SourceVaultRefreshModelRegistry["Providers" -> {"chatgptcodex"}]

(* Codex の選択可能なモデル一覧 *)
SourceVaultListModels["chatgptcodex"]

(* 用途（intent）に応じたモデル解決 *)
ClaudeResolveModel["chatgptcodex", "code-heavy"]
```

`SourceVaultRefreshModelRegistry` は Codex CLI の `codex debug models` コマンドを実行してモデルカタログ（JSON）を取得し、compiled モデルレジストリに登録します。

- `SourceVaultListModels[provider]` — 指定 provider の選択可能な全モデル ID を列挙します。
- `ClaudeResolveModel[provider, intent]` — 用途に応じた最適モデル 1 件を解決します。

#### 仕様・審査ワークフロー（ClaudeSpec + SourceVault）

SourceVault をロードすると、`ClaudeSpec` で生成した仕様書のバージョン管理・コンセンサス審査・実装ワークフロー化を行う API が追加で利用できます。仕様書の sv:// URI はノートブックにクリッカブルリンクとして書き込まれ、`ClaudeOpenSourceVaultURI` でワンクリック閲覧できます。

##### ClaudeSpecStatus — spec/consensus 状態の確認

```mathematica
(* カレントノートブックのプロジェクトの状態を表示 *)
ClaudeSpecStatus[]

(* 特定プロジェクトを指定 *)
ClaudeSpecStatus["my-project"]
```

カレントノートブックのプロジェクト ID（TaggingRule `SourceVaultSpecProjectId`）に紐づく spec/review のバージョン数・最新 Verdict・最新 spec の sv:// URI・最終更新時刻・バックグラウンドの consensus ジョブ稼働状況を Dataset として返します。プロジェクト ID が未設定の場合は実行中の consensus ジョブ一覧を表示します。ワークフローエンジン（ClaudeOrchestrator 等）は不要で、SourceVault のみで動作します。

##### ClaudeSpecVersions — spec/review バージョン一覧

```mathematica
(* 全バージョンを Dataset で取得 *)
ClaudeSpecVersions[]
ClaudeSpecVersions["my-project"]

(* ロールで絞り込む *)
ClaudeSpecVersions["my-project", "spec"]
ClaudeSpecVersions["my-project", "review"]
ClaudeSpecVersions["my-project", "requirements"]
```

各行に `Role`・`Round`・`Verdict`・`Seq`・`CreatedAtUTC`・`URI` が含まれます。バージョンは SourceVault のポインタチェーン（`orch/<project>/spec` および `orch/<project>/review`）から取得されます。URI 列の sv:// リンクを `ClaudeSpecText` に渡すとそのバージョンの本文を取得できます。

##### ClaudeSpecText — spec/review 本文の取得

```mathematica
(* sv:// URI から仕様書・審査内容の本文を取得 *)
text = ClaudeSpecText["sv://snapshot/Spec/abcdef1234567890"]
```

`ClaudeSpecVersions` の URI 列の値をそのまま渡します。`sv://snapshot/Class/hex` 形式と `sv://snapshot/Class:hex` 形式、および生の `snapshot:Class:hex` ref の 3 形式すべてに対応しています。

##### ClaudeOpenSourceVaultURI — sv:// URI を新規ノートブックで開く

```mathematica
(* 仕様書・審査結果を新規ノートブックウィンドウで表示 *)
nb = ClaudeOpenSourceVaultURI["sv://snapshot/Spec/abcdef1234567890"]
```

spec/review/requirements の sv:// URI を受け取り、メタデータグリッドと本文（Text セル）を含む新規ノートブックウィンドウを開きます。審査（review）の場合は Findings セクションも表示されます。

これは spec/consensus ワークフローがノートブックに書き込んだクリッカブルな sv:// リンクをクリックしたときの動作です。`NotebookObject` を返します。URI が解決できない場合は `$Failed` を返します。

##### CreateImplementationWorkflow — 承認済み仕様からワークフローを実装

`CreateImplementationWorkflow` は承認済み仕様（sv:// URI・スナップショット ref・生テキストのいずれか）を受け取り、`SourceVault_workflows/<name>/` 配下に `SVWorkflow_<Name>` パッケージとして実装します。実装は `$ClaudeModel`（実装者ロール）と `$ClaudeAdvisaryModel`（審査者ロール）の 2 モデルが協働する review-and-revise ループで進み、合意が得られるまでフィードバックを繰り返します。複雑な作業はサブ仕様（補助スペック）に分割して先に審査します。

```mathematica
(* 承認済み仕様 URI からワークフローをバックグラウンド実装 *)
jobId = CreateImplementationWorkflow["MyWorkflowName",
  "sv://snapshot/Spec/abcdef1234567890"]

(* オプション指定 *)
jobId = CreateImplementationWorkflow["MyWorkflowName", approvedSpecText,
  "Notes"          -> "追加の実装ノート",
  "ClaudeModel"    -> {"claudecode", "claude-opus-4-8"},
  "AdvisaryModel"  -> {"chatgptcodex", "Automatic"},
  "MaxRounds"      -> 5,
  "Launch"         -> True]
```

| オプション | デフォルト | 説明 |
|---|---|---|
| `"Notes"` | `""` | 実装時の追加指示 |
| `"ClaudeModel"` | `$ClaudeModel` | 実装者ロールのモデル（`{provider, model}` タプル） |
| `"AdvisaryModel"` | `$ClaudeAdvisaryModel` | 審査者（アドバイザリー）ロールのモデル |
| `"MaxRounds"` | `$iOrchConsensusMaxRounds` | 最大レビュー回数 |
| `"Nb"` | （カレントノートブック） | 結果を書き込むノートブック |
| `"Launch"` | `True` | 完了後にワークフローを起動するか |

進捗は `WindowStatusArea` にリアルタイム表示（実行中モデル・フェーズ）されます。完了するとワークフローの起動関数がセッションと PromptRouter に登録され、ノートブックにサマリーが書き込まれます。バックグラウンドジョブ ID を返します。

**`$ClaudeAdvisaryModel` の設定**

`CreateImplementationWorkflow` の審査者ロールに使用するモデルは `$ClaudeAdvisaryModel` で制御します。`$ClaudeModel` と同じ `{provider, model}` タプル形式で指定します。デフォルトは `{"chatgptcodex", Automatic}`（Codex CLI の既定モデルを使用）です。

```mathematica
(* 審査者を特定の Codex モデルに固定する場合 *)
$ClaudeAdvisaryModel = {"chatgptcodex", "gpt-5.5"}

(* 審査者も Claude Code にする場合 *)
$ClaudeAdvisaryModel = {"claudecode", "claude-opus-4-8"}
```

##### LaunchImplementationWorkflow — 生成ワークフローの起動

```mathematica
(* CreateImplementationWorkflow で生成したワークフローを（再）起動 *)
result = LaunchImplementationWorkflow["MyWorkflowName", args]
```

`SourceVaultLoadWorkflow[name]` でワークフローをロードし、`WorkflowInfo["Launch"]` の起動エントリを `args` で呼び出します。起動コンテキスト・エントリ・結果を含む Association を返します。`CreateImplementationWorkflow` 完了後に自動起動されない場合（`"Launch" -> False` 指定時）や、後から手動で再起動したい場合に使用します。

### ClaudeTestKit（テストフレームワーク）

[ClaudeTestKit](https://github.com/transreal/ClaudeTestKit) は claudecode および ClaudeRuntime の動作を自動テストするための独立パッケージです。claudecode のパッケージ更新・検証フローを自動化されたテストスイートで検証する用途に使用します。

```mathematica
(* ClaudeTestKit をロード *)
<< ClaudeTestKit`
```

ClaudeTestKit は claudecode の内部 API と ClaudeRuntime の承認フロー・スナップショット機構と連携し、再現性のあるテストシナリオを構築できます。詳細は [ClaudeTestKit リポジトリ](https://github.com/transreal/ClaudeTestKit) を参照してください。

### Git 連携機能

`ClaudePrepareCommit` は前回の GitHub コミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを自動生成して `GitHubRefreshAndCommit` 実行コマンドを出力します。

```mathematica
(* 1引数版: コミットメッセージも自動生成 *)
ClaudePrepareCommit["MyPackage"]

(* 2引数版: subject を直接指定。本文は自動収集した変更点から構築。 *)
ClaudePrepareCommit["MyPackage", "機能追加: 新しいAPI実装"]

(* フォールバック付き *)
ClaudePrepareCommit["MyPackage", Fallback -> True]
```

Git連携では変更サマリーリストを "- " 付き72文字折り返しで整形し、複数のステップがある場合は簡潔な連結で機能的に十分な形式でコミットメッセージを構築します。

### Web 機能

```mathematica
(* Web 検索（無料、Claude Code CLI 組み込み） *)
ClaudeWebSearch["Wolfram Language 新機能"]

(* Web ページ取得・要約（課金あり、Anthropic API 経由） *)
ClaudeWebFetch["https://example.com/article"]

(* 取得内容に対する指示 *)
ClaudeWebFetch["https://example.com", "重要なポイントを3つ抽出して"]
```

`WebSearch -> True/False` オプションで Claude Code CLI の Web 検索を制御し、`WebFetch -> True/False` オプションで Anthropic API 経由の URL 取得を制御できます。WebFetch は課金が発生するため、`Fallback -> True` の場合のみ有効です。

### CLI コマンド実行

```mathematica
(* Claude Code CLI スラッシュコマンドを実行 *)
ClaudeCommand["/help"]
ClaudeCommand["/permissions"]

(* CLI サブコマンドを実行 *)
ClaudeCommand["config list"]
ClaudeCommand["--version"]
```

### 実行中タスクの状態監視

```mathematica
(* 全実行中タスクのリアルタイム状態表示 *)
ClaudeStatus[]
```

各タスクの経過時間、現在の状態（思考中/テキスト生成中/ツール実行中）、生成済みテキスト断片数、思考断片数、ツール使用数をリアルタイムで表示します。

### ドキュメント一覧

| ファイル | 内容 |
|---|---|
| `README.md` | パッケージ概要・セットアップ手順 |
| `api.md` | 全公開関数の API リファレンス |
| `user_manual.md` | 使い方・設定・具体例（本ファイル） |
| `architecture.md` | 内部アーキテクチャの解説 |
| `setup.md` | インストール手順書 |
| `examples/example.md` | 使用例集 |

### 使用例・デモ

- [ClaudeCode デモ](https://www.youtube.com/watch?v=_Lc-XtBPkl8&t=919s)

### 関連パッケージ

- [NBAccess](https://github.com/transreal/NBAccess) — ノートブック読み書き・プライバシー管理
- [GitHubREST](https://github.com/transreal/github) — GitHub パッケージ管理・PR 管理
- [claudecode_directives](https://github.com/transreal/claudecode_directives) — rules/skills ディレクトリのデフォルトコンテンツ管理（オプション）
- [ClaudeRuntime](https://github.com/transreal/ClaudeRuntime) — ランタイムセッション管理・承認フロー・スナップショット機構（オプション）
- [ClaudeOrchestrator](https://github.com/transreal/ClaudeOrchestrator) — rate-limit 検出・自動復旧・リトライスケジューリング・ClaudeEval 非同期化（オプション）
- [SourceVault](https://github.com/transreal/SourceVault) — PromptRouter ブリッジ経由のタスクディスパッチ・ReadOnly 許可リストによる安全実行・仕様審査ワークフロー API（オプション）
- [ClaudeTestKit](https://github.com/transreal/ClaudeTestKit) — claudecode / ClaudeRuntime の自動テストフレームワーク（オプション）