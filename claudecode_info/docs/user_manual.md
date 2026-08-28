# 設計思想と実装の概要

ClaudeCode は以下の設計原則に基づいています。

- **ノートブック中心**: すべての操作はノートブック上で完結します。CLI を直接操作する必要はありません。
- **非同期実行**: LLM への問い合わせは非同期で実行され、ノートブックの操作を妨げません。リアルタイムのストリーミング進捗表示により、思考中・テキスト生成中・ツール実行中の状態を確認できます。
- **安全なパッケージ管理**: パッケージの更新はバックアップ・差分マージ・安全性検証・再ロードを自動で行います。排他ロック機構により、同一パッケージへの並列更新を防止します。更新後は自動生成された検証テストが実行され、意図した変更が正しくコードに反映されているか確認します。2026-06-10 の改善により、LLM レスポンスを「連続した行のかたまり(セグメント)」単位でマージするようになり、マージ精度が大幅に向上しました。`Pkg\`X` / `Pkg\`Private\`iX` のような完全修飾定義も正しく認識されます。
- **差分ベースバックアップ**: バックアップは SequenceAlignment ベースの差分形式(.cz / .cdiff / .unchanged)で保存され、ストレージ消費を大幅に削減します。既存の生バックアップは `ClaudeMigrateBackupHistory` で差分形式に変換できます。
- **機密データ保護**: `Confidential[]` による秘匿変数システムと、プライバシー考慮型モデルルーティングにより、機密データの安全な取り扱いを実現します。アクセスレベルに基づいて、クラウドモデルとローカルモデルを自動的に使い分けます。
- **多段フォールバック**: Claude Code CLI が利用不可の場合、アクセスレベルに応じたフォールバックモデルに自動切替します。Anthropic API、OpenAI API、z.ai(GLM シリーズ)、Kimi(Moonshot AI)、LM Studio・freetoken 等のローカルモデルを順次試行します。フォールバック候補を順に試す際は、429(レート制限)やサーバー過負荷エラーが連続して発生する事態を避けるため、次候補の起動を指数バックオフ(1秒→2秒→4秒を上限とする遅延)で行います。2026-08-28 の改訂では、Claude Code CLI の OAuth 認証切れ(401 authentication_failed)もレート制限と同格の検出対象に追加され、`ClaudeAuthStatus` / `ClaudeAuthClear` で状態の確認・手動リセットができるようになりました(詳細は「認証切れ検出(ClaudeAuthStatus / ClaudeAuthClear)」を参照)。
- **セッション管理**: 会話履歴をノートブックの TaggingRules に永続化し、差分圧縮と自動コンパクションによりストレージを効率的に利用します。
- **多言語対応**: `$Language` 設定に基づいてプロンプトの言語指示を動的に生成します。`$Language` が `"Japanese"` の場合は日本語で応答するよう指示し、それ以外の場合は英語に切り替わります。
- **AI 生成機能**: OpenAI Images API による画像生成(`ClaudeImageGenerate`)と OpenAI TTS API による音声生成(`ClaudeSpeech`)を統合しています。
- **プロジェクト固有ディレクティブ**: ノートブックディレクトリごとに独立したルール・スキルを定義し、メインのディレクティブと自動マージできます。
- **claudecode_directives 連携**: オプションの独立パッケージ [claudecode_directives](https://github.com/transreal/claudecode_directives) をロードすることで、`rules/` および `skills/` ディレクトリのデフォルトセットが自動的にインストールされます。ロード後は Claude Code CLI のコンテキストに rules/ の制約と skills/ の手順が自動的に注入され、Claude がスキルを呼び出せるようになります。claudecode.wl 本体はディレクティブの内容に非依存であり、claudecode_directives がその管理を担います。
- **ディレクティブ投影レイヤー (ClaudeDirectives)**: rules/skills を含む正規ディレクティブ・リポジトリを読み込み、モデルの能力(コンテキスト長・課金有無)・ロール・タスクに応じて、投影モード(Full / Summary / Index / Lazy)と適用するスキル・ルールを in-memory で動的に選択します。さらに、単一の正規リポジトリから Claude CLI 用(`.claude/`)と Codex CLI 用(`AGENTS.md` / `.agents/`)のハーネスを生成・実体化する機能を備えます。ファイル形式は Claude Code 互換を維持し、claudecode.wl / NBAccess.wl への依存を持たない純 Wolfram Language 実装(Rule 11)として、claudecode.wl 側から optional に統合されます。
- **スマートドキュメント管理**: ドキュメント生成・更新時のモード制御(新規作成・既存更新)、部分更新対象の指定、差分検出による効率的な更新処理を提供します。`ClaudeUpdateDocumentation` の `Baseline` オプションにより、差分の基準を「直近の更新バックアップ(`"LastDocUpdate"`)」と「GitHub コミット版(`"Github"`)」から選択でき、後者では `_info/design` の新規設計内容も加味した更新が行えます。20 ファイル以上の一括更新時は、README を除くドキュメントを LLM へ並列投入し、ウィンドウステータスバーにリアルタイム進捗(「完了 N/M • K 並列実行中 • 経過 Ts」)を表示します。サイクル再開(resumption)機能により、API エラーで中断後に再実行しても同一サイクル内の更新済みファイルをスキップして効率的に継続できます。2026-07-09 の改訂により、更新失敗は「システム的失敗(fail-fast でチェーン即中断)」と「品質ゲート失敗(切り詰め・サイズ退行・タイトル不整合。当該ファイルをスキップして次に進む)」に明確に分類され、1 ファイルの持続的な品質失敗が残り全部の更新を巻き添えにしなくなりました。品質ゲート失敗が発生した場合はまず 1 回だけ自動リトライが行われ、その際は「単一応答で出力すること・ツールを使用しないこと・コードフェンスを正しく閉じること」を明示する RETRY NOTICE がプロンプトに追加注入されます。リトライ後も同じ理由で失敗した場合は当該ファイルをスキップして次のファイルに進み、進捗表示には切り詰め文字数・サイズ退行前後の文字数と割合・タイトル不一致内容などの具体的な失敗理由が付記されます。既存ファイルへの上書き時には、新しい内容の文字数が既存内容の 40% 未満に縮小した場合は書き込み自体を拒否するサイズ退行ガードも機能します(閾値 40%)。リトライ実行時はこの比率ガードが緩和され、stub(空同然の応答)防止のための絶対値床(600 文字未満のみ拒否)に切り替わります。これは RETRY NOTICE により意図的に簡潔な応答が返ってくることを想定した調整です。また、サイクル再開(resumption)機能についても、前回実行の残存カウンタにより初回試行が誤ってスキップされてしまう不具合が修正され、より正確に継続できるようになりました。品質ゲート失敗時のリトライ・スキップ経路で、共有ポーリングタスクの再発火や派生クエリの二重起動によりドキュメント更新チェーンが分岐(fork)してしまう不具合を防ぐため、各ステップに一意のシリアルトークンを発行し最初のコールバックのみを有効化する二重発火ガードも導入されています。また `docs/` 配下に同期事故等で生じた `docs/docs/` ネスト重複ドキュメントを自動検出し、更新対象から除外した上で削除を推奨する警告を表示します。2026-07-09 の改訂では、`docs/examples/` 配下の `*.md`(使用例ドキュメント)も `Automatic`(既定)モードでの自動更新対象から除外されるようになりました。これは、examples は手作業内容が主であり毎回再生成すると多数作成した場合に更新が終わらなくなるためで、更新するには `TargetFiles` オプションで明示的に指定する必要があります(詳細は「ドキュメント更新対象ファイルの指定(TargetFiles)」を参照)。ドキュメント更新チェーンの多重起動防止ガードにより、同一パッケージに対して複数の更新チェーンが同時起動することを防ぎます。チェーンが異常終了した場合も `$ClaudeDocUpdateStaleSeconds` 秒後に自動解放されます。補助 API ドキュメント(`api_<aux>.md`)の再生成要否判定は、更新日時(mtime)比較からコンテンツハッシュ比較へ段階的に移行しており、Dropbox 同期や複数 PC 環境による mtime の揺れだけでは不要な再生成が発生しないようになっています。2026-07-10 の改訂では、条件を満たす場合にドキュメント更新パイプライン全体を外部 wolframscript ワーカープロセスへ退避して実行する仕組み(`$ClaudeDocUpdateExternal`)が導入され、複数のドキュメント更新を並走させた際のメインカーネル飽和によるフリーズが根絶されました(詳細は「ドキュメント更新の外部プロセス実行」を参照)。2026-07-13 の改訂では、README.md の「## 謝辞」「## 免責事項」「## ライセンス」節を LLM には書かせず、`Acknowledgments` / `Disclaimer` / `License` オプションと `doc_options.json` の既定値から書き込み直前にコード側で決定的に(verbatim で)追記する方式へ変更されました。これにより法的節の文言が LLM の出力切り詰めの影響を受けなくなります。追記前には本文が必須の「## 使用例」節まで到達しているか、および本文自体が途中で切れていないかを検証する専用ガードが働き、いずれかに該当する場合は書き込みが拒否されます。同じく 2026-07-13 の改訂で、複数パッケージが同時に言及されるタスクにおける API ドキュメントの注入順序とコンテキスト予算の割り当ても再設計されています(詳細は「複数パッケージ言及時の注入順序とコンテキスト予算」を参照)。2026-08-28 の改訂では、Claude Code CLI の OAuth 認証切れ(401 authentication_failed)を検出した場合、レート制限と同格の投入前ゲートとして扱われ、新規ドキュメントを 1 件も投入せずに中断して再ログインを促すようになりました(詳細は「認証切れ検出とドキュメント更新の投入前ゲート」を参照)。
- **分離原則検証**: NBAccess パッケージとの適切な分離を維持するため、コード内の分離原則違反を自動検出・修正する機能を備えています。
- **パッケージキーワード自動注入**: 各パッケージが独自のキーワードを登録し、プロンプト中にキーワードが含まれる場合に自動的にそのパッケージの API ドキュメントをコンテキストに注入します。パッケージ単位(`$ClaudePackageKeywordMap`)に加え、補助ドキュメント単位(`$ClaudePackageAuxKeywordMap`)でも注入条件を制御できます。
- **自動実行安全ガード**: `ClaudeEval` の `AutoEvaluate -> True` で生成コードを自動実行する際、`NBAutoEvalProhibitedPatterns` に定義された禁止パターンに該当するコードの自動実行をブロックします。これにより、ファイル削除や危険なシステム操作などを含むコードが意図せず実行されることを防止します。
- **共有ポーリングタスク**: 複数の非同期ジョブが実行中の場合、すべてのジョブが単一の共有ポーリングタスクを利用します。旧実装のようにジョブごとに個別の `ScheduledTask` を作成しないため、多数のジョブを並列実行した際のオーバーヘッドが大幅に削減されます。`iEnsureSharedPollingTask` により共有タスクのライフサイクルが管理され、パッケージリロード時には旧タスクが自動的に停止されます。フリーズ(数十秒単位でメインカーネルをブロックする不具合)を根絶するため、FE 応答性プローブと handler 個別タイムアウトの二段構えの防御も導入されています(詳細は「高度な非同期処理システム」を参照)。
- **非同期スケジューリング規約の自動注入**: `ClaudeUpdatePackage` のプロンプトに、非同期タスクのスケジューリング規約(claudecode/NBAccess 公開 API の使用義務・例外条件・根拠)を自動注入します。LLM が生成するパッケージコードが正しい非同期パターンに従うよう誘導します。
- **Windows エンコーディング安全な API 通信(マルチモーダル対応)**: `ClaudeQueryBg` はテキスト・`Image`・`File` オブジェクトを混在したリスト形式の入力に対応しています。CLI パスでは `iNormalizePrompt` 経由で画像を PNG に変換して送信し、API フォールバックパス(`Fallback -> True`)では Anthropic API のマルチモーダル `content` 配列を構築して送信します。LM Studio プロバイダに対してもマルチモーダル入力が可能になり(2026-07-29)、OpenAI 互換の chat/completions エンドポイント経由で画像を含むクエリを送信します。リクエストボディは `ExportByteArray["JSON"]` で UTF-8 ByteArray として送信し、非 ASCII 文字は `\uXXXX` JSON エスケープに変換します。レスポンスは `ImportByteArray["RawJSON"]` で ByteArray のまま直接 JSON パースするため、Windows 固有の暗黙的エンコーディング変換(ShiftJIS 等)による日本語文字化けが発生しません。2026-08-04 の改訂では、OpenAI 互換 chat/completions API(openai / zai / kimi プロバイダ)のリクエスト本文生成にも同様の対策が適用され、文字列連結による手組み JSON ではなく Association から `ExportByteArray["RawJSON"]` で直接 UTF-8 ByteArray を生成する方式に統一されました(詳細は「OpenAI 互換 API 通信の Windows エンコーディング対応」を参照)。
- **ClaudeRuntime 統合**: オプションの独立パッケージ [ClaudeRuntime](https://github.com/transreal/ClaudeRuntime) をロードすると、`ClaudeEval` のバックエンドとしてランタイムセッション管理機能が有効になります。ランタイムはターン数・プロファイル・失敗履歴を追跡し、危険な操作に対して承認フロー(`NeedsApproval`)を提供します。ClaudeRuntime をロードすると `$UseClaudeRuntime = True` が自動的に設定され、`ClaudeEval` 呼び出しは ClaudeRuntime 経由でルーティングされます(claudecode 単独ロード時はデフォルトの `$UseClaudeRuntime = False` のまま従来動作を維持)。
- **ClaudeOrchestrator 連携**: オプションの独立パッケージ [ClaudeOrchestrator](https://github.com/transreal/ClaudeOrchestrator) をロードすると、`ClaudeEval` がオーケストレーター管理下の非同期実行モードに切り替わります。呼び出しはジョブキューに追加されて即座に返り、カーネルをブロックしません。rate-limit 検出・自動待機・リトライスケジューリングが透過的に処理され、長時間・大規模なタスクを安定して継続実行できます。`ClaudeRateLimitStatus[]` が返す復旧予定時刻を参照して待機タイミングを自動判断します。
- **SourceVault 連携(PromptRouter ブリッジ)**: オプションの独立パッケージ [SourceVault](https://github.com/transreal/SourceVault) をロードすると、`ClaudeEval` の Order 2 ディスパッチとして PromptRouter による提案ベースの実行経路が有効になります。SourceVault がタスク文字列から `PromptRouteProposal` を構築し、claudecode 側は提案の `ProposedExpression`(`HoldComplete`)の頭部を ReadOnly 許可リストと照合した上でのみ評価します。claudecode.wl は SourceVault に対して hard dependency を持たず(rule 11)、SourceVault がアクティブでない・許可リスト外の頭部を提案した・エラー・拒否を返した場合は `NotDispatched` となり、従来の自然言語ルーター(spec 5.3 / 24.3)にフォールバックします。SourceVault をロードすると、仕様書の審査・実装ワークフロー化 API(`ClaudeSpecStatus`・`ClaudeSpecVersions`・`ClaudeSpecText`・`ClaudeOpenSourceVaultURI`・`CreateImplementationWorkflow`・`LaunchImplementationWorkflow`・`ClaudeImplStatus`・`ClaudeImplMonitor`)も利用可能になります。`CreateImplementationWorkflow` が完了すると、生成されたワークフローの起動関数がスラッグ・表示名をキーワードとして PromptRouter に自動登録されるため、以降は `ClaudeEval` でスラッグ名を呼び出すだけでワークフローを起動できます。`CreateImplementationWorkflow` の実装者ロールは、`$ClaudeUltraEnabled`(デフォルト `False`)を `True` に設定した場合に限り ultra モデルクラス(`ClaudeUltraModelSpec` で解決; CLI 優先・paid-API ゲート付き)を優先し、利用できない場合は `$ClaudeModel` にフォールバックします。既定(`$ClaudeUltraEnabled = False`)では `$ClaudeModel` / `$ClaudeAdvisaryModel` の指定がそのまま尊重され、ultra への暗黙アップグレードは行われません(2026-08-03: 暗黙アップグレードが共有 fable セッション使用枠を消費してしまう事故が発生したための方針変更)。検証者ロールには `$ClaudeAdvisaryModel` が使われます。承認にはパッケージのテストが新規カーネルで合格すること(proven-code ゲート)も条件となります(サマリーキー: `TestGate` / `Proven`)。`MaxRounds` オプションは既定で 3 に設定されています。実装(implement)と検証(verify)を 1 ラウンドとすると実測で概ね 13〜15 分を要するため、既定値 3 で妥当な運用時間に収まるよう調整されています。また実行全体には約 90 分の全体デッドラインが設けられており、超過した場合は残りのラウンドを打ち切って失敗として扱います。また、claudecode/anthropic プロバイダのパレット既定モデル(いわゆる「ヒープモデル」)や lmstudio プロバイダのモデル候補一覧も、SourceVault のモデルレジストリからの動的解決を優先します(詳細は「操作パレット」を参照)。
- **[実験的] LLM 適用グラフ (LLMGraph)**: LLM の適用を DAG(有向非巡回グラフ)として自動記録・可視化します。Mathematica 14.2 の `LLMGraph` と類似の構造を採用した独自実装で、`ClaudeEval` / `ClaudeQuery` 実行時にノートブック固有のグラフが自動生成されます。この実装は `claudecode_info/design/` にある WOOC'92 / WOOC'93 論文で議論されている、データの構造を保ったまま定義域ごとに適応的に処理を適用するモデルを下敷きにしています。`$LLMGraphMaxConcurrency` によりカテゴリ別の並列度を制御でき、DAG ジョブの作成・実行・キャンセル・再構築を行う `LLMGraphDAGCreate` / `LLMGraphDAGRebuild` 系の API も提供されます。なお `$LLMGraphMaxConcurrency["cli"]` は並列ドキュメント更新(20+ ファイル時)の並列度制御にも使用されます。
- **[実験的] プライバシー分割ファイル処理 (ClaudeProcessFile)**: LLMGraph の応用として、ノートブックファイルのセルをプライバシーレベルで分割し、クラウド LLM とプライベート LLM で並列処理してマージする機能を提供します。

内部的には、[NBAccess](https://github.com/transreal/NBAccess) パッケージにノートブックのセル操作・プライバシー管理・履歴 DB を委譲し、[GitHubREST](https://github.com/transreal/github) パッケージと連携して GitHub 上のパッケージ管理を行います。

## 詳細説明

### 動作環境

- Wolfram Mathematica 13.x 以降
- Windows 11(macOS/Linux ではパス区切りやシェルコマンドを適宜読み替えてください)
- Claude Code CLI がインストール済みで、パスが通っていること
- ChatGPT Codex CLI(オプション、`chatgptcodex` provider 利用時。`npm install -g @openai/codex` でインストール)
- Node.js(node-pty によるインタラクティブ CLI 実行に使用)
- [NBAccess](https://github.com/transreal/NBAccess) パッケージ(`NBAccess.wl`)
- [GitHubREST](https://github.com/transreal/github) パッケージ(`github.wl`)— オプション、GitHub 連携時に必要

### インストール

基盤パッケージ(`claudecode.wl`, `NBAccess.wl`, `github.wl`)は `$packageDirectory` に直接配置します。

```mathematica
(* $Path に $packageDirectory を追加 *)
AppendTo[$Path, $packageDirectory]

(* パッケージの読み込み (UTF-8 環境で) *)
Block[{$CharacterEncoding = "UTF-8"},
  Needs["ClaudeCode`", "claudecode.wl"]];
```

claudecode を使用している場合、`$Path` は自動的に設定されます。

ディレクティブ管理機能を使用する場合は、[claudecode_directives](https://github.com/transreal/claudecode_directives) パッケージ(`claudecode_directives.wl`)をオプションでロードします。

```mathematica
(* ディレクティブ管理機能を使用する場合(オプション) *)
Block[{$CharacterEncoding = "UTF-8"},
  Needs["ClaudeCodeDirectives`", "claudecode_directives.wl"]];
```

### 基本設定

```mathematica
(* 使用するモデルの指定(空文字列で Claude Code のデフォルトモデル) *)
$ClaudeModel = "claude-sonnet-5"

(* $ClaudeModel を LM Studio に直接設定する例(Web 検索等を LM Studio で実行したい場合) *)
$ClaudePrivateModel = {"lmstudio", "qwen3.6-27b", "http://127.0.0.1:1234"}
$ClaudeModel = $ClaudePrivateModel

(* LM Studio 使用時に有効にする MCP インテグレーション *)
(* mcp.json に登録済みの MCP サーバー ID を指定する。LM Studio がサーバー側で tool-call を自動実行する。 *)
$ClaudeLMStudioIntegrations = {"mcp/exa"}

(* フォールバックモデルの設定 *)
$ClaudeFallbackModels = {
  {"chatgptcodex", "gpt-5.6-sol"},
  {"anthropic", "claude-opus-5"},
  {"openai", "gpt-5.5"}
}

(* 機密データ処理用ローカルモデル *)
$ClaudePrivateModel = {"lmstudio", "qwen3.6-27b", "http://127.0.0.1:1234"}

(* タイムアウト(秒) *)
$ClaudeTimeout = 1200

(* ClaudeEval 再帰深度上限 *)
$ClaudeEvalMaxDepth = 5

(* ドキュメント生成用モデル *)
$ClaudeDocModel = "claude-sonnet-5"

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

(* LLMGraph カテゴリ別並列度 (デフォルト値を変更する場合)
   ※ ClaudeUpdateDocumentation の並列ドキュメント更新(20+ ファイル時)の並列度制御にも使用される *)
$LLMGraphMaxConcurrency["cli"] = 4        (* CLI テキスト呼び出し・並列ドキュメント更新 *)
$LLMGraphMaxConcurrency["cli-vision"] = 1 (* CLI 画像付き呼び出し *)

(* ドキュメント更新チェーンの stale 上限(秒)。
   この秒数を超えたら異常終了とみなして再スケジュールを許可する。
   デフォルト: 1800 秒(30 分) *)
$ClaudeDocUpdateStaleSeconds = 1800

(* ドキュメント更新パイプライン全体を外部 wolframscript ワーカーで実行するかどうか
   (デフォルト True)。False にすると従来のカーネル内非同期経路に戻る。
   詳細は「ドキュメント更新の外部プロセス実行」を参照 *)
ClaudeCode`$ClaudeDocUpdateExternal = True

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
   実装者ロール: $ClaudeModel (ultra 利用可能かつ $ClaudeUltraEnabled = True の場合のみ ClaudeUltraModelSpec で解決)
   審査者(アドバイザリー)ロール: $ClaudeAdvisaryModel
   $ClaudeModel と同じ {provider, model} タプル形式で指定する
   デフォルト: {"chatgptcodex", Automatic}(Codex CLI の既定モデルを使用)
   後方互換として "chatgptcodex" のようなベア文字列も受け入れる
   例: $ClaudeAdvisaryModel = {"chatgptcodex", "gpt-5.6-sol"} *)
$ClaudeAdvisaryModel = {"chatgptcodex", Automatic}

(* ultra モデルクラスへのアップグレード制御 (デフォルト False)
   True:  仕様生成・実装ワークフローで $ClaudeModel を ultra モデルクラス
          (SourceVault モデルレジストリの "code-ultra"/"ultra" インテント、例: claude-fable-5)
          に自動アップグレードする。
   False (デフォルト): 常に $ClaudeModel をそのまま使用し、ultra へのアップグレードを行わない。
          2026-08-03: 暗黙のアップグレードが共有 fable セッションの使用枠を意図せず消費してしまう
          事故が発生したため、既定を無効化する方針に変更された(オーナー指示)。
   アドバイザリーロール ($ClaudeAdvisaryModel) は常に影響を受けない。 *)
$ClaudeUltraEnabled = False

(* パレットのプロバイダ循環順序 *)
(* "claudecode" | "chatgptcodex" | "anthropic" | "openai" | "zai" | "kimi" | "lmstudio" | "freetoken" *)
$iPaletteProviderOrder = {"claudecode", "chatgptcodex", "anthropic", "openai", "zai", "kimi", "lmstudio", "freetoken"}

(* パレットの lmstudio モデル一覧を「現在ロード済みのモデルのみ」に絞るか「LM Studio が
   把握している全モデル」まで含めるかを制御する。LM Studio サーバーに到達できない場合は
   SourceVault のカタログ、それも取得できない場合は静的リストに自動フォールバックする。 *)
$ClaudeLMStudioPaletteLoadedOnly = True
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

#### 補助 API ドキュメントのキーワード制御(\$ClaudePackageAuxKeywordMap)

パッケージによっては `api.md` 本体とは別に、機能単位の補助 API ドキュメント(`api_<aux>.md`、例: `api_eagle.md`)を持つ場合があります。`$ClaudePackageAuxKeywordMap` は、これら補助ドキュメントの注入条件をパッケージ単位よりも細かい粒度(補助ドキュメント単位)で登録するための Association です。

```mathematica
(* 形式: $ClaudePackageAuxKeywordMap[パッケージ名] = <|補助名 -> {キーワード...}|> *)
(* 補助名は api_<補助名>.md のファイル名部分に対応する *)
$ClaudePackageAuxKeywordMap["SourceVault"] = <|"eagle" -> {"Eagle", "Exif"}|>
```

- 補助名(`api_eagle.md` なら `"eagle"`)が登録されている場合、**その補助名またはキーワードがタスク文に含まれるときのみ** `api_eagle.md` がコンテキストに注入されます。
- 未登録の補助 API は従来どおり常に注入されます(後方互換)。
- 登録済みだがキーワードが一致しない補助 API は注入対象から除外されます。これにより、パッケージが多数の補助ドキュメントを持つ場合でも、無関係なタスクでコンテキストが不必要に肥大化することを防ぎます。

`$ClaudePackageKeywordMap` がパッケージ単位の注入条件を制御するのに対し、`$ClaudePackageAuxKeywordMap` は同一パッケージ内の個々の補助ドキュメントごとに注入条件を制御します。両者は補完的に併用できます。

#### 複数パッケージ言及時の注入順序とコンテキスト予算(2026-07-13)

タスク文が複数のパッケージ名やキーワードに一致する場合、各パッケージの `api.md` / 補助 API ドキュメントは以下の方針でプロンプトに注入されます。

1. **言及順序を優先**: パッケージは、タスク文中で最初に名前または登録キーワードが一致した文字位置の早い順に注入されます。これにより、ドキュメント量の多いパッケージ(数万文字規模の `api.md` を持つパッケージ等)が先に注入されて後続パッケージの `api.md` が丸ごと予算から外れてしまう、という 2026-07-13 以前の不具合(ディレクトリスキャン順に近いアルファベット順で全パッケージ分を連結し、コンテキスト予算を単純な先頭切り詰めで適用していたために発生していた)が解消されます。
2. **2 パス注入**: まず全パッケージについて「キーワード一致した補助 API + `api.md` 本体」を予算内に注入し、その後に「未登録(既定で常時注入される)補助 API」をまとめて注入します。これにより、1 つのパッケージが持つ大量の補助ドキュメントが、他パッケージの `api.md` 本体を予算から追い出してしまう事態を防ぎます。
3. **ファイル単位の予算管理**: コンテキスト予算(既定 24,000 文字、`ClaudeCode\`$ClaudeEvalPackageDocsCharBudget` で変更可能)はファイル単位で消費されます。予算に収まらないファイルは(まだ何も注入されていない最初の 1 件を除き)ファイルの途中で切り詰めるのではなく丸ごと除外され、除外されたファイル名がプロンプト末尾に一覧表示されます(LLM は必要であればツール経由でそのファイルを読むことができます)。
4. `ClaudeCode\`$ClaudeEvalContextPlanning -> "LegacyFull"`(または `False`)を設定すると、このファイル単位の予算制御を無効化し、従来の無制限連結・先頭切り詰め方式に戻せます。

### クイックスタート

```mathematica
(* 同期的に Claude に問い合わせ(テキスト応答) *)
ClaudeQuery["Mathematicaでフィボナッチ数列を生成する方法を教えてください"]

(* 非同期でコードを生成・実行 *)
ClaudeEval["素数判定関数を書いてください"]

(* 会話を継続 *)
ContinueEval["もう少し効率的な方法はありますか?"]

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
| | `ClaudeUpdateDocumentation` | 差分検出による自動更新・モード制御・Baseline 切替(直近更新／GitHub コミット版)・`TargetFiles` による部分更新対象の指定(`"api.md"`/`"examples/*"` 等のマーカー展開含む)・並列更新・サイクル再開(resumption)・失敗分類(システム的失敗/品質ゲート失敗)・RETRY NOTICE 付き自動リトライ・サイズ退行ガード・docs/docs 重複検出・外部プロセス実行(docext)・認証切れ投入前ゲート |
| **バックアップ** | `ClaudeBackupDataset` | バックアップ履歴の管理・復元 |
| | `ClaudeMigrateBackupHistory` | 生バックアップを差分形式に変換 |
| **機密データ** | `Confidential` / `NonConfidential` | 変数の秘匿・解除 |
| | `MarkConfidential` / `UnmarkConfidential` | セルの秘匿マーク |
| | `ScanConfidentialCells` | 依存セルの自動検出・マーク |
| **プライバシー** | `$ClaudePrivateModel` | ローカルモデル設定 |
| | `AutoPrivate -> True` | 機密データ自動ルーティング |
| | `PrivacySpec` オプション | アクセスレベル明示指定 |
| **セッション** | `CreateClaudeSession` | 名前付きセッション作成 |
| | `ClaudeShowHistory` | 履歴表示 |
| | `ClaudeCompactHistory` | 履歴コンパクション |
| | `ClaudeHistorySize` | 履歴サイズ診断 |
| | `ClaudeAttach` / `ClaudeDetach` | 参考資料のアタッチ |
| **認証・利用制限** | `ClaudeRateLimitStatus` | レート制限状態の確認 |
| | `ClaudeRateLimitClear` | レート制限記録のクリア |
| | `ClaudeAuthStatus` | claude CLI の OAuth 認証状態確認 |
| | `ClaudeAuthClear` | 認証エラー記録の手動クリア |
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
| | `ClaudeDirectiveMigrationReport` | 正規/従来ハーネスの移行ゲート(他 API は専用セクション参照) |
| **AI 生成** | `ClaudeImageGenerate` | OpenAI Images API で画像生成 |
| | `ClaudeSpeech` | OpenAI TTS API で音声生成 |
| **Web** | `ClaudeWebSearch` | Web 検索(Claude Code 組み込み) |
| | `ClaudeWebFetch` | URL 内容取得・要約(Anthropic API) |
| **パレット統合** | `ClaudeRegisterPaletteServiceControl` | パレットのサービストグルを登録 |
| | `ClaudeUnregisterPaletteServiceControl` | パレットのサービストグルを登録解除 |
| | `$ClaudePaletteServiceControls` | 登録済みサービストグルのリスト |
| **CLI MCP 統合** | `ClaudeRegisterCLIMCPServer` | ヘッドレス CLI 実行用 MCP サーバーを登録 |
| | `$ClaudeCLIMCPServers` | 登録済み CLI MCP サーバーのレジストリ |
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
| | `$ClaudeUltraEnabled` | ultra モデルクラスへの自動アップグレード制御フラグ(デフォルト False) |
| | `ClaudeUltraModelSpec` | ultra クラスモデルの {provider, modelId} 解決 |
| | `ClaudeSpecStatus` | spec/consensus 状態の確認 |
| | `ClaudeSpecVersions` | spec/review バージョン一覧 |
| | `ClaudeSpecText` | sv:// URI から spec/review 本文を取得 |
| | `ClaudeOpenSourceVaultURI` | sv:// URI を新規ノートブックで開く |
| | `CreateImplementationWorkflow` | 承認済み仕様からワークフローを実装(proven-code ゲート付き) |
| | `LaunchImplementationWorkflow` | 生成ワークフローの起動 |
| | `ClaudeImplStatus` | spec-impl ワークフロー実行状況の確認 |
| | `ClaudeImplMonitor` | 実行状況の自動更新パネル |
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
| | `$LLMGraphMaxConcurrency` | カテゴリ別並列度の制御(並列ドキュメント更新にも適用) |
| **[実験的] ファイル処理** | `ClaudeProcessFile` | プライバシー分割並列処理 |
| **分離検証** | `ClaudeCheckSeparation` | NBAccess 分離原則の違反検査 |
| | `ClaudeFixSeparation` | 違反の自動修正 |
| **Git 連携** | `ClaudePrepareCommit` | 変更履歴収集・コミット準備 |
| **ユーティリティ** | `ShowClaudePalette` | 操作パレット表示 |
| | `ClaudeStatus` | 実行中タスクの状態表示 |
| | `ClaudeProcessList` | 実行中タスクのインタラクティブ一覧(一時停止/再開・停止操作付き) |
| | `ClaudeCommand` | CLI スラッシュコマンド実行 |

### 操作パレット

`ShowClaudePalette[]` を実行すると、Claude Code の主要操作をワンクリックで呼び出せるパレットが表示されます。

```mathematica
ShowClaudePalette[]
```

![ソースコードの現在の状態に合わせて更新。そのとき、$Languageが日本語ではないときは英語に切り替わることを追加。また、添付しているパレットの図を挿入してパレットの使い方も説明も追加。](img_20260323_185321_1.png)

パレットは上から以下のセクションに分かれています。

#### 機密セル セクション

| ボタン | 説明 |
|---|---|
| **△ 機密マーク** | 選択中のセルを機密セルとしてマークします。マークされたセルの内容は ClaudeQuery/ClaudeEval のプロンプトから除外されます。 |
| **⊗ 機密解除** | 選択中のセルの機密マークを解除します。 |
| **▷ スキャン** | ノートブック全体をスキャンし、機密変数を参照するセルを自動的に機密マークします(`ScanConfidentialCells[]` に相当)。 |

#### サービス・トグル(拡張ポイント、プライバシーの下)

プライバシー(Save NB)セクションの直下に、**外部パッケージが登録したサービスの起動/停止トグル**が表示されます。claudecode 自身はどのパッケージにも依存せず、`$ClaudePackageKeywordMap` と同様に**汎用の登録窓口だけ**を提供します(パッケージ側が自分でトグルを登録する)。

- ラベル・ボタン色は登録側が供給し、**現在の稼働状態に追従**します(稼働中は色が変わり「停止」系ラベル、停止中は「起動」系ラベル)。状態は一定間隔で再確認されます。
- 登録が 1 つも無ければ、この領域には何も表示されません。

例として **SourceVault** をロードすると、MCP サーバの起動/停止トグルがここに出ます(押すと WL service + MCP proxy を起動/停止し、ラベルは実状態に追従)。

登録 API(外部パッケージ向け):

| 関数 / 変数 | 説明 |
|---|---|
| `ClaudeRegisterPaletteServiceControl[spec]` | トグルを登録(`spec["Id"]` で一意。同じ Id の再登録は置換)。`spec` は `<\|"Id", "RunningQ" -> (Function[] が True/False/Missing を返す), "Start" -> Function[], "Stop" -> Function[], "RunningLabel", "StoppedLabel", "UnknownLabel", (任意) "RunningColor"/"StoppedColor"\|>`。 |
| `ClaudeUnregisterPaletteServiceControl[id]` | Id を指定して登録解除。 |
| `$ClaudePaletteServiceControls` | 登録済みトグルのリスト(レジストリ本体、既定 `{}`)。 |

> 各パッケージは自身のロード時に `Names` で `ClaudeRegisterPaletteServiceControl`(`ClaudeCode` コンテキスト)の存在を soft-probe してから登録します(claudecode は外部パッケージに依存しません)。ラベル文字列・起動/停止・状態判定のコールバックはすべて登録側が供給するため、claudecode 側に特定パッケージ固有のロジックは入りません。新規登録を既に開いているパレットへ反映するには `ShowClaudePalette[]` を再実行してください。

#### Claude セクション

| ボタン | 説明 |
|---|---|
| **▷ ClaudeQuery** | 選択中のセル内容またはノートブックコンテキストをもとに `ClaudeQuery` を実行します。同期的にテキスト応答を返します。 |
| **▷ 選択→Query** | 現在選択中のセルの内容を取得して `ClaudeQuery` に渡します。 |
| **■ 実行停止** | 実行中の全 Claude タスクを停止します(`ClaudeAbort[]` に相当)。 |

#### 設定セクション

パレット下部の設定エリアでは、以下のパラメータをノートブックごとに保存・変更できます。設定はノートブックの TaggingRules に永続化されます。

| 設定項目 | 説明 |
|---|---|
| **P:** | プロバイダを切り替えます。クリックするたびに `claudecode → chatgptcodex → anthropic → openai → zai → kimi → lmstudio → freetoken` の順で循環します。選択中のプロバイダ名がボタンラベルに表示されます。各プロバイダの特性は下表を参照してください。 |
| **M:** | 選択中のプロバイダ内でモデルを切り替えます。クリックするたびに対応するモデル一覧を循環します。短縮名(例: Opus 5、Fable 5)で表示されます。`Automatic` は Codex CLI の既定モデルを使用します(chatgptcodex プロバイダの場合)。SourceVault のモデルレジストリがロードされている場合は、そこからモデル一覧が取得されます。特に `claudecode` / `anthropic` プロバイダの既定モデル(候補一覧の先頭に来るモデル)は、SourceVault がロードされていれば `ClaudeResolveModel` 経由で動的に解決されるため、SourceVault 側でモデルの世代が更新されてもパレット側のコード変更なしに追従します(SourceVault 未ロード時は静的な既定値 `claude-opus-5` にフォールバック)。`lmstudio` プロバイダでは LM Studio サーバーへの実問い合わせによる候補一覧が優先され、取得できない場合は SourceVault のカタログ、それも無ければ静的リストへ順にフォールバックします(`$ClaudeLMStudioPaletteLoadedOnly` 参照)。`freetoken` プロバイダでもモデル候補・エフォート設定はキャッシュされ、LM Studio と同様の仕組みで管理されます。 |
| **エフォート** | 標準モデル (**M:** の直下) の思考量です。`claudecode` では Low / Medium / High / Max で Think トリガーの強度を設定します(Low は思考なし、Medium は `think hard`、High は `think harder`、Max は `ultrathink`)。`lmstudio` を選んでいるときは **Off** が加わって Off / Low / Medium / High / Max の 5 段になり、LM Studio の `reasoning` パラメータに写ります。**Off = thinking 無効**です。Off のまま `claudecode` に戻した場合、CLI には `--effort` を渡さず Medium 相当で動きます。`freetoken`(2026-08-24 追加)でも同様に Off / Low / Medium / High / Max の 5 段になり、モデル別の推奨 Effort 表を lmstudio と共有した上で `reasoning_effort` パラメータとして送信されます(値が文字列型のときのみ送信され、Automatic 等は従来どおり送られません)。 |
| **E:**(秘密モデル枠内) | 秘密モデル `$ClaudePrivateModel` の思考量です。標準モデルのエフォートとは独立に保持され、Off / Low / Medium / High / Max を循環します。既定は Medium(thinking 有効)。 |
| **課金API** | 禁止 / 許可 — `Fallback -> True/False` を制御します。「禁止」では Claude Code CLI または Codex CLI(課金なし扱い)のみ使用し、「許可」では CLI 利用不可時に Anthropic API・z.ai API 等へフォールバックします。 |

**プロバイダ一覧**

| プロバイダ | 説明 | 課金 |
|---|---|---|
| `claudecode` | Claude Code CLI(Anthropic、Pro/Max サブスクリプション) | なし |
| `chatgptcodex` | ChatGPT Codex CLI(OpenAI、サブスクリプション) | なし |
| `anthropic` | Anthropic API(直接) | あり |
| `openai` | OpenAI API(直接) | あり |
| `zai` | z.ai API(GLM シリーズ) | あり |
| `kimi` | Kimi API(Moonshot AI、OpenAI 互換) | あり |
| `lmstudio` | LM Studio(ローカル LLM) | なし |
| `freetoken` | freetoken(ローカルの無料エンドポイント、既定 `http://localhost:1919` / `gpt-oss-120b`) | なし |

**z.ai プロバイダ**

`zai` は z.ai が提供する GLM シリーズモデルへのアクセスを提供します。OpenAI 互換 API 形式を採用しており、内部的には既存の OpenAI API 経路(base URL のみ z.ai エンドポイントに差し替え)を利用します。利用可能なモデルは glm-5.2、glm-5.1、glm-5、glm-5-turbo、glm-4.7、glm-4.6、glm-4.5-air、glm-4.5 等です。API キーは NBAccess の SystemCredential 管理機能で登録します。課金 API のため、パレットの「課金API: 許可」設定が必要です。

**Kimi プロバイダ**

`kimi` は Moonshot AI が提供する Kimi シリーズモデルへのアクセスを提供します。z.ai と同様に OpenAI 互換 API 形式を採用しており、内部的に既存の OpenAI API 経路(base URL を Kimi エンドポイントに差し替え)を利用します。利用可能なモデルは kimi-k3、kimi-k2.7-code、kimi-k2.7-code-highspeed、kimi-k2.6 等です。API キーは NBAccess の SystemCredential 管理機能で登録します。課金 API のため、パレットの「課金API: 許可」設定が必要です。

**freetoken プロバイダ(2026-08-24 追加)**

`freetoken` は、ローカルネットワーク上で動作する無料の OpenAI 互換 chat/completions エンドポイント(既定 `http://localhost:1919`、既定モデル `gpt-oss-120b`)へのアクセスを提供する軽量プロバイダです。LM Studio と同じく課金は発生しません。

- パレットの `M:` ボタンで循環するモデル候補と、`エフォート` で選択した Effort 値は、いずれも接続先(base URL)ごとにキャッシュされます。パッケージリロード時や設定変更時にはこのキャッシュも同時に破棄されます。
- Effort(Off / Low / Medium / High / Max)は、モデル別の推奨値表を LM Studio 経路と共有した上で `reasoning_effort` パラメータとして送信されます。値が文字列型の場合のみ `reasoning_effort` キーが付与され、`Automatic` 等の場合は付与されません。
- `$ClaudeModel` に `{"freetoken", "gpt-oss-120b"}` のように明示的に指定することもできます(カスタム URL を第 3 要素として指定可能)。

**LM Studio プロバイダのモデル一覧**

`lmstudio` プロバイダでは、パレットの `M:` ボタンで循環するモデル候補として、静的な既定リストの代わりに LM Studio サーバーへの実問い合わせ結果(実際に利用可能なモデルのカタログ)が優先的に使用されます。`$ClaudeLMStudioPaletteLoadedOnly` により、以下のいずれかを選択できます。

- `True`(デフォルト): LM Studio に現在ロード済みのモデルのみを候補とします。すぐに応答可能なモデルだけを一覧したい場合に適しています。
- `False`: LM Studio が把握している全モデル(未ロードのものを含む)を候補とします。切り替え時に自動ロードされるモデルまで含めて選びたい場合に使用します。

LM Studio サーバーに到達できない環境では、SourceVault のモデルカタログ、さらにそれも取得できない場合は `$iPaletteModelsByProvider` の静的リスト(`{"qwen3.6-27b", "qwen3.5-27b", "qwen3-coder-30b", "gpt-oss-120b"}`)へ自動的にフォールバックするため、LM Studio が起動していなくてもパレット自体は問題なく動作します。

#### ステータス表示

パレット最下部には現在のノートブックにおける機密セル数と機密依存セル数がリアルタイムで表示されます(例: `機密: 0, 依存: 0`)。

#### 言語切り替え

パレットの表示言語は `$Language` 設定に連動します。`$Language` が `"Japanese"` の場合は日本語で表示され、それ以外の場合(英語環境など)は英語に切り替わります。たとえば英語環境では「機密マーク」は "Mark Confidential"、「実行停止」は "Abort" のように表示されます。

### CLI MCP サーバー登録システム

`ClaudeRegisterCLIMCPServer` は、ヘッドレスの claude CLI 実行(`ClaudeQueryBg` / `queryProvider`)に MCP サーバーを組み込むための登録 API です。パレットのサービストグル(`ClaudeRegisterPaletteServiceControl`)が UI 側の登録窓口であるのに対し、こちらは **CLI ヘッドレス実行側**の登録窓口です。claudecode.wl はいずれのパッケージにも依存せず、汎用の登録窓口のみを提供します。

#### 動作の概要

登録された MCP サーバーが稼働中の場合、`ClaudeQueryBg` 等のヘッドレス CLI 実行時に以下が自動的に行われます。

1. `ConfigFn` を呼び出してサーバーの URL と認証ヘッダーを取得します(サーバー停止時は `None` を返すため自動的にスキップ)。
2. `AllowedTools` に列挙されたツールを `--allowedTools mcp__<id>__<tool>` 形式で claude CLI に渡します(`--print` モードの非対話実行では事前許可が必要)。
3. `PromptDirective` に設定された MCP 優先ポリシーテキストをクエリプロンプトに自動注入します。

#### 登録 API

```mathematica
(* MCP サーバーを登録する *)
ClaudeRegisterCLIMCPServer["my-mcp", <|
  "ConfigFn"       -> Function[
    (* サーバー稼働中のみ Association を返し、停止時は None を返す *)
    If[iServerRunning[],
      <|"Url" -> "http://localhost:8080/mcp",
        "Headers" -> <|"Authorization" -> "Bearer " <> iGetToken[]|>|>,
      None]],
  "AllowedTools"   -> {"search", "read_file", "write_file"},
  "PromptDirective" -> "利用可能な MCP ツールを優先的に使用してください。"
|>]

(* 登録解除 *)
(* ClaudeRegisterCLIMCPServer に同じ id で再登録すると置換される *)
```

#### spec キー一覧

| キー | 説明 |
|---|---|
| `"ConfigFn"` | 引数なし Function。サーバー稼働中は `<\|"Url" -> ..., ("Headers" -> <\|...\|>)\|>` を返し、停止中は `None` を返す。`/health` プローブ等を含むことができる。 |
| `"AllowedTools"` | ツール名のリスト。`--allowedTools mcp__<id>__<tool>` として CLI に渡される。`--print` モードはインタラクティブに承認できないため、使用するツールをすべて列挙すること。 |
| `"PromptDirective"` | `String` または引数なし Function。サーバー稼働中にクエリプロンプトへ自動注入される MCP 優先ポリシーテキスト。 |

#### レジストリ変数

| 変数 | 説明 |
|---|---|
| `$ClaudeCLIMCPServers` | 登録済み CLI MCP サーバーのレジストリ(`<\|id -> spec\|>` 形式)。外部パッケージ(SourceVault MCP 等)が自身のロード時に登録する。claudecode はパッケージ非依存を保つ。 |

> SourceVault をロードすると、SourceVault MCP サーバーがパレットトグル(`ClaudeRegisterPaletteServiceControl`)と CLI MCP 登録(`ClaudeRegisterCLIMCPServer`)の両方を自動的に行います。これにより、SourceVault MCP はパレットから起動/停止でき、かつ `ClaudeQueryBg` 等のヘッドレス CLI 実行でも MCP ツールが利用できるようになります。

### プライバシー考慮型モデルルーティング

ClaudeCode は機密データを含むタスクに対して、自動的にローカルモデルへルーティングする機能を備えています。

- **`$ClaudePrivateModel`**: ローカル LLM(LM Studio 等)のモデル仕様を設定します
- **`AutoPrivate -> True`**: 機密変数にアクセスするタスクで自動的にローカルモデルを使用します
- **`PrivacySpec`**: アクセスレベルを明示的に制御します
- **3段階フォールバック**: Claude Code CLI → アクセスレベル対応フォールバックモデル → エラーの順で試行します。次のフォールバック候補への切替は、429(レート制限)や過負荷エラーが連続発生する事態を避けるため、指数バックオフ(1秒→2秒→4秒を上限とする遅延)で行われます。

### LM Studio の直接使用

`$ClaudeModel` に LM Studio のモデル仕様(リスト形式)を設定することで、Claude Code CLI を使わずに LM Studio をメインの推論エンジンとして直接使用できます。これにより、ローカル LLM を用いた Web 検索や MCP ツール連携が可能になります。

#### 基本設定例

```mathematica
(* LM Studio をメインモデルとして設定 *)
$ClaudePrivateModel = {"lmstudio", "qwen3.6-27b", "http://127.0.0.1:1234"};
$ClaudeModel = $ClaudePrivateModel;

(* MCP インテグレーションを設定(mcp.json に登録済みの ID を指定) *)
$ClaudeLMStudioIntegrations = {"mcp/exa"};

(* Web 検索を伴う質問を実行 — LM Studio が exa で検索して回答 *)
ClaudeEval["Claude Code について最新の情報を調べてほしい。"]
```

`$ClaudeLMStudioIntegrations` に MCP サーバー ID を指定すると、LM Studio がサーバー側で tool-call ループを自動実行します。フロントエンドをブロックせずに MCP ツール(exa による Web 検索等)を利用できます。MCP 使用時はコンテキスト長として 16000 以上を推奨します。

`ClaudeQuery` / `ClaudeQueryAsync` には `Integrations` オプションもあり、`$ClaudeLMStudioIntegrations`(既定は `Automatic`、SourceVault の順に解決)の代わりにその呼び出しだけ MCP サーバー・plugin リストを明示的に指定できます(lmstudio モデル使用時のみ有効)。

```mathematica
(* この呼び出しだけ MCP サーバーを明示指定する例 *)
ClaudeQueryAsync["最新ニュースを調べて", Integrations -> {"mcp/exa"}]
```

#### $ClaudeLMStudioIntegrations の指定形式

| 形式 | 例 | 説明 |
|---|---|---|
| 文字列リスト | `{"mcp/exa"}` | `mcp.json` に登録済みの MCP サーバー ID を指定 |
| Plugin 形式 | `{<|"type"->"plugin","id"->"mcp/exa",...|>}` | 詳細オプション付きで指定 |
| Ephemeral MCP 形式 | `{<|"type"->"ephemeral_mcp",...|>}` | 一時的な MCP サーバーをインライン定義 |

#### 認証設定(Require Authentication)

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

登録後は `ClaudeEval` 等の呼び出し時に API キーが自動取得されます。未登録の場合は認証なしのダミーキー(`"lm-studio"`)にフォールバックするため、Require Authentication が Off の通常利用では登録不要です。

**注意**: キー名に含まれる URL は `$ClaudeModel` の第3要素(カスタム URL)と一致させてください。リモートの LM Studio サーバーを使用する場合はそのサーバーの URL に合わせてキー名を変更してください。

#### モデル別推奨 temperature(2026-08-16)

LM Studio 経由のリクエストでは、送信するモデルごとにあらかじめ用意された推奨 temperature が自動的に付与されるようになりました。値が数値のときのみリクエスト本文に `"temperature"` キーとして含まれ、`Automatic` / `None` の場合は従来どおり temperature パラメータ自体を送信しません。この推奨値は Claude Code CLI 以外の従来経路(zai / kimi / openai 等の OpenAI 互換経路)でも尊重されます。

### ChatGPT Codex の直接使用

`$ClaudeModel` を `{"chatgptcodex", Automatic}` に設定することで、Claude Code CLI の代わりに OpenAI の ChatGPT Codex CLI を provider として使用できます。

#### 事前準備

ChatGPT Codex CLI を npm でインストールし、OpenAI アカウントでログインします。

```bash
npm install -g @openai/codex
codex --version
codex login
```

`codex login` で作成される認証情報(`auth.json`)は既定の `CODEX_HOME`(`~/.codex`)に保存されます。ClaudeCode は Codex 実行ごとに一時的な `CODEX_HOME` を作成しますが、この認証情報を自動的に引き継ぐため、一度 `codex login` を実行しておけば ClaudeCode 経由の Codex 実行でも認証が通ります。

#### 基本使用例

```mathematica
(* provider を ChatGPT Codex に切り替え(モデルは CLI 既定) *)
$ClaudeModel = {"chatgptcodex", Automatic}

(* Codex 経由でコード生成 *)
ClaudeEval["1 から 100 までの和を求めてください"]

(* provider を Claude Code に戻す *)
$ClaudeModel = {"claudecode", "claude-opus-5"}
```

Codex provider は Claude CLI と同じ非同期実行経路で動作します。内部的には専用の非同期ブリッジ(`iLaunchCodexExecAsync`)を経由しており、Codex 実行ごとに一時的な作業ディレクトリと`CODEX_HOME` を作成し、`codex exec` をバックグラウンドで起動して `--output-last-message` で指定した出力ファイルをポーリングするため、実行中にカーネルがブロックされることはありません。起動失敗・タイムアウト時はコールバックに `"Error: ..."` 文字列が渡され、エラーセルが書き出されます。

Claude Code CLI も Codex CLI もサブスクリプション契約に基づく CLI であり、メーター制 API(`anthropic` / `openai` provider)とは課金体系が異なります。claudecode の課金 API ガードは `chatgptcodex` provider を無課金扱いとするため、課金 API を許可しない設定でも Codex 経由のコード生成が利用できます。

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

### 多言語対応($Language ベースの言語切り替え)

ClaudeCode は Wolfram Language の `$Language` 変数を参照して、Claude への応答言語指示を自動生成します。

- **`$Language = "Japanese"`** の場合: Claude に対して日本語で応答するよう指示します。
- **`$Language` が `"Japanese"` 以外**(例: `"English"`、その他の言語)の場合: 英語で応答するよう指示します。

この切り替えはプロンプト生成時に自動で行われるため、ユーザーが明示的に設定する必要はありません。Mathematica の言語設定に合わせて適切な応答言語が選択されます。

### 自動実行安全ガード(NBAutoEvalProhibitedPatterns)

`ClaudeEval` の `AutoEvaluate -> True`(デフォルト)では、LLM が生成したコードが自動的に実行されます。安全性を確保するため、`NBAutoEvalProhibitedPatterns` に定義された禁止パターンに該当するコードの自動実行はブロックされます。

禁止パターンに該当するコードが生成された場合、そのコードブロックは Input セルとしてノートブックに書き込まれますが、自動実行はスキップされます。ユーザーがコードの内容を確認した上で、手動で実行するかどうかを判断できます。

この機構により、ファイル削除やシステム操作など、意図しない副作用を持つ可能性のあるコードが自動実行されるリスクを軽減します。内部的には `iAutoEvalProhibitedPatterns` によって禁止パターンの照合が行われます。

### アクセス可能ディレクトリ制御

`$ClaudeAccessibleDirs` により、Claude Code がアクセスできるディレクトリを制御できます。NotebookDirectory が安全なデフォルトディレクトリ(`$packageDirectory` や `$ClaudeWorkingDirectory` 配下)でない場合、初回使用時にダイアログで許可を求めます。許可設定はノートブックの TaggingRules に永続化されます。

### パッケージ更新の排他ロック

同一パッケージに対する `ClaudeUpdatePackage` の並列実行を防ぐ排他ロック機構が組み込まれています。更新開始時にロックが取得され、完了時に自動解放されます。異なるパッケージへの同時更新は並列実行可能です。

ドキュメント更新チェーン(`ClaudeUpdateDocumentation` / `ClaudeCreateDocumentation`)にも専用の多重起動防止ガードが実装されています。非同期コールバック連鎖で進行するドキュメント更新は複数の連鎖が同じ docs/ と履歴を同時更新するとデータ破損が生じるため、タイムスタンプ方式のガードで保護されています。チェーンが異常終了してガードが解放されなかった場合も、`$ClaudeDocUpdateStaleSeconds`(デフォルト 1800 秒)を超えると自動的に解放され自己復旧します。

```mathematica
(* stale 上限を変更する例(デフォルト: 1800 秒) *)
$ClaudeDocUpdateStaleSeconds = 3600  (* 1 時間に延長 *)
```

さらに 2026-07-09 の改訂では、品質ゲート失敗時のリトライ・スキップ経路で更新チェーンが分岐(fork)してしまう不具合への対策として、ステップ単位の一意なシリアルトークンによるガードが追加されました。共有ポーリングタスクの再発火や派生クエリの二重起動により同一ステップのコールバックが複数回実行されようとした場合でも、最初のコールバックのみが有効化され、以降の重複実行は無視されます。これによりチェーンが枝分かれして同じファイルの更新が競合するリスクが防止されます。

### ドキュメント更新対象ファイルの指定(TargetFiles)

`ClaudeUpdateDocumentation` の `TargetFiles` オプション(デフォルト `Automatic`)により、更新対象のドキュメントファイルを明示的に絞り込むことができます。`Automatic` の場合は差分検出により自動判定されますが、`TargetFiles -> {...}` で明示指定すると、指定したファイルのみが更新対象になります。

```mathematica
(* api.md のみを更新 *)
ClaudeUpdateDocumentation["MyPackage", TargetFiles -> {"api.md"}]

(* 拡張子なしでも自動的に .md が付与される *)
ClaudeUpdateDocumentation["MyPackage", TargetFiles -> {"user_manual"}]

(* examples/ 配下の特定ファイルのみを更新 *)
ClaudeUpdateDocumentation["MyPackage", TargetFiles -> {"examples/my_demo.md"}]

(* examples/ 配下の全ファイルをまとめて更新 *)
ClaudeUpdateDocumentation["MyPackage", TargetFiles -> {"examples/*"}]
```

#### 許可されるファイル名と正規化

`TargetFiles` に指定できるのは以下のいずれかです。不正なファイル名を含む場合は `ClaudeUpdateDocumentation::badtarget` メッセージとともに `$Failed` が返ります。

| 指定形式 | 正規化後 | 説明 |
|---|---|---|
| `"api"` / `"README"` / `"setup"` / `"user_manual"` / `"example"` | 各 `.md` が自動付与される | 拡張子省略形。ベース名指定のみで対応するトップレベル doc を指す |
| `"api.md"` / `"README.md"` / `"setup.md"` / `"user_manual.md"` | そのまま | トップレベルドキュメントファイル名 |
| `"api_<aux>.md"` / `"api_<aux>"` | 補助 API ドキュメント名として許可 | パッケージの補助 API ドキュメント |
| `"example"` / `"example.md"` | `"examples/example.md"` | canonical な examples フォルダ内のファイルに正規化 |
| `"examples/<name>.md"` | そのまま | examples フォルダ内の特定ファイルを個別指定 |
| `"examples"` / `"examples/"` / `"examples/*"` / `"examples/*.md"` | `"examples/*"` | examples フォルダ内の全 `.md` を対象とする一括マーカー |

#### マーカー展開の詳細

- **`"api.md"` マーカー**: `TargetFiles` に `"api.md"` が含まれる場合、パッケージの補助 API ドキュメント(`api_<aux>.md`)のうち、対応するソースコードが `api.md` 本体より新しい(コンテンツハッシュが未記録、または記録済みハッシュと不一致な)ものが自動的に追加対象へ加えられます。ソースに変更が無い補助 API ドキュメントは対象に含まれません。
- **`"examples/*"` マーカー**: `TargetFiles` に `"examples/*"` が含まれる場合、`docsDir/examples` フォルダ内に実在する `*.md` 全件が個別のターゲットファイルへ展開されます。フォルダが存在しない場合は展開結果は空になります。

#### examples/*.md の自動更新対象からの除外(2026-07-09〜)

`TargetFiles -> Automatic`(差分検出による自動判定)を使用する通常のドキュメント更新では、`docs/examples/` 配下の `*.md`(使用例ドキュメント)は**自動更新の対象から除外**されるようになりました。examples ドキュメントは手作業で作成した内容が中心であり、ソース差分のたびに毎回再生成してしまうと、使用例を多数作成しているパッケージほど更新が終わらなくなる問題があったためです。

除外された場合、ノートブックには件数を示す情報メッセージ(`ℹ examples/*.md (N 件) は自動更新から除外。更新するには TargetFiles で明示指定 (個別 "examples/<name>.md" または一括 "examples/*")。`)が表示されます。examples ドキュメントを更新したい場合は、上記のとおり `TargetFiles` で個別または一括のマーカーを明示的に指定してください。

なお、`docsDir/docs/` のようにネストして作成されてしまった重複ドキュメント(Dropbox 同期事故等で発生)についても、従来どおり自動検出されて更新対象から除外され、削除を推奨する警告が表示されます。

### ドキュメント更新の外部プロセス実行(\$ClaudeDocUpdateExternal)

`ClaudeUpdateDocumentation` / `ClaudeCreateDocumentation` は 2026-07-10 の改訂により、条件を満たす場合はパイプライン全体(プロンプト構築 → claude CLI 呼び出し → 品質ゲート → ファイル書き込み → 進捗マーカー更新 → バックアップ)を子プロセスの `wolframscript` ワーカーへ退避して実行するようになりました。従来はこれらすべてがメインカーネル内の非同期タスクとして実行されていたため、複数の `ClaudeUpdateDocumentation` を並走させるとメインカーネルが飽和し FrontEnd がフリーズすることがありましたが、外部プロセス化によりメインカーネル側には「ジョブの投入」と「`status.json` を読むだけの軽量な poll tick」しか残らなくなり、この種のフリーズが根本的に解消されます。

```mathematica
(* 外部プロセス実行の有効/無効(デフォルト True) *)
ClaudeCode`$ClaudeDocUpdateExternal = True

(* False にすると従来のカーネル内非同期経路に戻る *)
ClaudeCode`$ClaudeDocUpdateExternal = False
```

#### 動作の概要

- ワーカープロセスは同期的なポンプループ(`Pause` によるポーリング)で claude CLI 呼び出しを最大並列数まで投入します。子プロセス内では `ScheduledTask` 等の非同期スケジューリング機構は一切使用しません(非同期は絶対に子プロセスへ持ち込まない、という原則に基づきます)。
- 進捗マーカー(`.docupdate_progress.json`)とサイクルキーはメインカーネル経路と共有されるため、ワーカーが中断した場合の再実行でも、通常の「サイクル再開(resumption)」機能がそのまま働き、同一サイクル内の更新済みファイルはスキップされます。
- ハートビート付きの claim ファイル(`.docupdate_worker.json`)により、FrontEnd 再起動後に外部ワーカーが生存しているかどうかを検知し、二重ワーカー起動を防止します(claim が一定時間更新されない場合は stale とみなして自動失効)。加えて、メインカーネル自身が把握している進行中ジョブによる二重起動防止も併用され、二重の安全策になっています。
- パイプライン全体には超過時に残りのファイルを失敗として扱い抜ける全体デッドラインが設定されており、ワーカーが応答を返さないまま無期限に居座ることを防ぎます。ワーカーが完了マーカーを残さず終了した場合(Claude Code CLI のライセンス席枯渇などが疑われるケース)も、メインカーネル側は自動的に失敗として扱い次に進みます。

#### 自動フォールバック

外部プロセス実行が不適格な場合は自動的に従来のカーネル内非同期経路にフォールバックします。以下のいずれかに該当すると外部実行はスキップされます。

| 条件 | 説明 |
|---|---|
| `$ClaudeDocUpdateExternal -> False` | 明示的に無効化されている |
| 画像添付あり | マルチモーダル入力は外部ワーカーでは扱えないため従来経路を使用 |
| ドキュメント生成モデルが Claude Code CLI 以外 | `$ClaudeDocModel` / `Model` オプションの解決結果が `{"claudecode", ...}` 以外の provider の場合 |
| `$packageDirectory` に `claudecode.wl` / `NBAccess.wl` が見つからない | ヘッドレスロードに必要な基盤パッケージが揃っていない環境 |
| 実行席(seat)の枯渇・子プロセス spawn 失敗 | ライセンス席や OS リソースが確保できない場合 |

いずれの場合も、ユーザーが意識することなく品質ゲート・進捗表示・サイクル再開などの挙動は従来どおり保たれます。

### 認証切れ検出とドキュメント更新の投入前ゲート(ClaudeAuthStatus / ClaudeAuthClear、2026-08-28)

Claude Code CLI の OAuth セッションが期限切れになると、`claude` CLI は 401 `authentication_failed` を返すようになります。従来はこれが単に「内部エラー」としてしか表示されず、特にドキュメント一括更新のような多数ファイルの並列投入中にセッションが切れた場合、原因が認証切れであると判別できないまま更新が失敗し続けるという問題がありました(2026-08-28、SourceVault のドキュメント更新中断時に実際に発生)。

この問題に対応するため、認証切れを `ClaudeRateLimitStatus` / `ClaudeRateLimitClear` によるレート制限検出と同格の一級市民として扱う仕組みが追加されました。

#### `ClaudeAuthStatus[]` / `ClaudeAuthClear[]`

- **`ClaudeAuthStatus[]`**: claude CLI の認証(OAuth)状態を返します。認証が切れている場合は Association、問題なければ `None` を返します(`ClaudeRateLimitStatus` と同じ規約)。判定は API を一切呼び出さず、次の 2 系統の情報のみで行われます。
  1. 直近の応答から検出した 401 `authentication_failed` の記録
  2. `~/.claude/.credentials.json` のアクセストークンの有無(資格情報を追跡できない環境向けの保険であり、検出から 30 分で自動失効します)
  記録は、資格情報ファイルが記録時刻より後に更新されていれば「再ログイン済み」とみなして自動的にクリアされます。
- **`ClaudeAuthClear[]`**: 内部に保持された認証エラー記録を手動でクリアします。再ログイン後は自動でクリアされますが、誤検出でガードがかかってしまった場合の手動リセット手段として使用できます。

```mathematica
(* 認証状態を確認する *)
ClaudeAuthStatus[]
(* 認証切れなら Association、問題なければ None *)

(* 誤検出時などに手動でクリア *)
ClaudeAuthClear[]
```

#### ドキュメント更新への統合(投入前ゲート)

`ClaudeUpdateDocumentation` / `ClaudeCreateDocumentation` の並列投入パイプラインは、認証切れをレート制限と同格の「システム的失敗」として扱います。

- CLI 経由(claudecode provider)のドキュメント更新実行時、応答から 401 認証切れを検出すると記録され、(間引き付きで)警告が表示されます。この記録は外部プロセス実行(docext)・カーネル内非同期実行のどちらの経路でも共有されます。
- **投入前ゲート**: 新しいドキュメントを投入する前に認証切れが記録されているかどうかを確認し、切れていれば 1 件も投入せずに中断して再ログインを促します。Claude Code CLI の OAuth 認証切れは全ドキュメントが確実に失敗する状況であるため(レート制限の投入前ガードと同じ設計を踏襲)、無駄な投入を避けます。
- 中断・失敗メッセージには再ログイン案内(ターミナルで `claude` を起動して再ログインするよう促す文言)が自動的に埋め込まれるため、どの機能から呼ばれても認証切れであることが必ず一度は明示されます。

なお、この機能は claudecode provider(Claude Code CLI 経由)のドキュメント更新にのみ適用され、lmstudio / codex 等の他プロバイダは対象外です。

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
| `⚠️ Verification tests failed (N)` | N テストが失敗(意図した変更が欠落している可能性) |

テストが失敗した場合は `ContinueUpdate[]` で追加修正を依頼することを推奨します。

#### 未変更関数の保全検証

マージ後、LLM が変更を主張していない関数が意図せず変更されていないかを自動チェックします。変更が検出された場合は警告が表示されます(ブロック境界シフトによる可能性を含む)。実際に破損している場合は事前バックアップから復元してください。

### CUDA 拡張サポート

`ClaudeUpdatePackage` の指示内容に CUDA 関連のキーワードが含まれている場合(`CUDA`, `cuda`, `cuda.wl` 等)、自動的に `cuda.wl` 拡張を読み込もうとします。`cuda.wl` が `$packageDirectory` に存在しない場合は警告が表示され、CUDA拡張なしで処理が継続されます。

### 依存関数の自動検出(スマートターゲティング)

`ClaudeUpdatePackage` の `TargetFunctions -> Automatic`(デフォルト)では、更新指示文の内容から更新対象関数を自動推定します。

推定アルゴリズムは以下の 2 フェーズで動作します。

1. **フェーズ 1(本体マッチ)**: 指示文から 4 文字以上の漢字・カタカナ連続列と 5 文字以上の英語キーワードを複合語として抽出し、関数本体にそれらが含まれる関数を検出します。短い関数名(2 文字以下)や汎用すぎる複合語(3 文字以下)による誤マッチは除外されます。
2. **フェーズ 2(bi-gram フォールバック)**: フェーズ 1 で本体マッチが 0 件の場合、usage 文字列への bi-gram マッチにフォールバックします。

検出結果が 40 関数を超える場合(指示文の複合語が汎用すぎる場合)は、全体送信にフォールバックします。

また、検出した対象関数が呼び出す依存ヘルパー関数(3 文字以上の関数名のみ)も自動的に展開してプロンプトに含めます。依存パッケージの `api.md` も自動収集され、パッケージ境界を越えた原因追跡が可能になります。

2026-06-10 の改善により、`Pkg\`X` や `Pkg\`Private\`iX` のような完全修飾名での関数定義も正しく認識・索引化されます。これにより、名前空間付きで定義された関数も対象関数推定の対象に含まれるようになりました。

### セグメント単位の関数マージ(2026-06-10)

`ClaudeUpdatePackage` の応答マージが「セグメント単位」に改善されました。

#### セグメントとは

LLM レスポンス内の「連続した行のかたまり」をセグメントと呼びます。列 0 の構造行(関数定義の開始・終了に相当する行)でセグメント境界が決まります。インデントされた文字列連結行などは構造行とみなされず、セグメントには含まれません。また、どのセグメントにも属さない構造行自体はマージ対象外として保全されます。

#### 旧実装からの改善点

従来の実装では、部分的なレスポンス(LLM のストリーミング途中で受信した断片)に対するマージ・対象関数推定が機能していませんでした。新実装ではセグメント単位で元コードと照合し、変更された関数のみを差し替えます。

#### マージ不一致警告

マージ後、LLM が変更したと主張しているにもかかわらず元コードとセグメントが一致しなかった場合、以下の警告が表示されます。

```
⚠ マージ不一致: 以下の関数はセグメントが元コードと一致せず、置換できませんでした:
  functionName1, functionName2, ...
```

この警告が出た場合、その関数は更新されていません。`ContinueUpdate[]` で追加修正を依頼するか、手動で差分を確認してください。

#### LLM コンテキスト供給の改善(2026-06-10)

`ClaudeUpdatePackage` が LLM に送信するプロンプトに、パッケージ内の全トップレベル定義名の索引が追加されました。これにより:

- **捏造防止**: LLM が存在しない関数名を生成することを防ぎます。索引を見ることで LLM は実際に定義されている関数名を参照できます。
- **完全修飾定義の認識**: `Pkg\`X` や `Pkg\`Private\`iX` のような完全修飾形式の定義も索引に含まれます。

これらの改善は巨大ファイルでのコンテキスト溢れ・コスト増・応答品質低下を防ぐ観点でも最適化されており、索引は簡潔な形式で提供されます。

### 非同期タスクスケジューリング規約の自動注入

`ClaudeUpdatePackage` が LLM に送信するプロンプトには、非同期タスクのスケジューリング規約が自動的に注入されます。これにより、LLM が生成するパッケージコードが正しいパターンに従うよう誘導します。

注入される規約の要点は以下の通りです。

1. **必須**: 非同期タスクのスケジューリングには claudecode / NBAccess の公開 API を使用すること
2. **例外(個別 `ScheduledTask` が許容される場合)**:
   - ノートブックと無関係な純粋計算タスク(数値計算・組み合わせ計算等)
   - `PresentationListener` のように独立した FrontEnd ループを必要とするインタラクティブプログラム
3. **根拠**: 複数の `ScheduledTask` が `WindowStatusArea` を同時更新すると競合が発生し、他タスクが巻き添えで停止するリスクがある

この自動注入により、ユーザーが明示的に規約を指示しなくても、生成コードが共有ポーリングタスクの仕組みと適切に協調するようになります。

### 差分ベースバックアップシステム

バックアップは以下の差分形式で保存され、ストレージ消費を大幅に削減します。

| 拡張子 | 形式 | 説明 |
|---|---|---|
| `.cz` | Compress[全文] | ベースライン(完全な内容) |
| `.cdiff` | Compress[{参照先, SequenceAlignment結果}] | 前回との差分 |
| `.unchanged` | 参照先ディレクトリ名 | 内容変更なし(1ホップ解決保証) |

ベースラインは一定間隔(デフォルト10回ごと)で自動作成され、差分チェーンが長くなりすぎることを防ぎます。

```mathematica
(* 既存の生バックアップを差分形式に変換(容量削減) *)
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

起動時にローカル最新版のスナップショットが SHA-256 ハッシュ付きで自動保存されます。Grid の #0 行(ローカル最新版)の Pull ボタンを押すと、Pull で巻き戻した後でもスナップショットから復元できます。Pull 後にファイルが変更されていた場合は警告が表示されます。

バックアップの安全な削除機能も備えています。差分チェーンの中間ノードを削除する際、後続の `.cdiff` / `.unchanged` が参照先を失わないよう、依存ファイルを自動的にベースライン(`.cz`)に変換します。

### 履歴サイズ診断

```mathematica
(* 現在のセッション履歴のサイズを診断 *)
ClaudeHistorySize[]
(* → <|"Entries" -> 45, "ByteCount" -> 182400, "KiloBytes" -> 178.1, "Status" -> ...| *)
```

200KB 超でコンパクション推奨、500KB 超で危険と判定されます。履歴コンパクションはエントリ数ベースとサイズベースの二重チェックで自動実行されます。サイズベースチェックにより、エントリ数が少なくても巨大な response を持つセッションでのノートブック肥大化を防ぎます。

### 高度な非同期処理システム

ClaudeCode は書き込みキュー方式を採用し、各セル書き込みを個別のサンク(引数なし関数)としてキューに積み、ティック間でカウンタが更新される仕組みで、数十秒ブロックする可能性がある処理を軽量な直接書き込みに変換します。これにより、大量の出力生成時でもユーザーインターフェースの応答性を保ちます。

複数のジョブが同時実行中の場合、すべてのジョブが **共有ポーリングタスク** を利用します。旧実装ではジョブごとに個別の `ScheduledTask` を作成していましたが、現在は `iEnsureSharedPollingTask` によって管理される単一の共有タスクがすべてのジョブのキューを一括処理します。これにより、多数の並列ジョブ実行時のスケジューラーへの負荷を大幅に削減しています。パッケージリロード時には旧タスクが自動的に停止されます。

#### フリーズ対策(2026-07-08〜09、2026-07-29 強化、2026-08-04 追加対策)

数十秒単位でメインカーネルをブロックしてしまうフリーズループの再発防止として、以下の二段構えの防御が組み込まれています。

1. **FE 応答性プローブ**: 重い `runInline` 処理を実行する前に、軽量な FrontEnd 往復チェックを行い、FrontEnd が応答可能な状態かどうかを確認します。応答が無い場合(例: ノートブックが `-file` オプションなどヘッドレスに近い状態で起動していて FrontEnd と正しく連携できていない場合)は、重い処理に入る前に異常を検出できます。2026-07-29 の改善では、共有ポーリングタスクの tick handler 自体にも FE 応答性ゲートが追加されました。FE がビジーな状態(例: `CurrentValue` の書き込みが塞がっている)で tick handler が走り続けると相互待ちで永久ハングしてしまうことが判明したためです。このゲートにより、FE 非応答時は tick 処理への進入を抑止します。
2. **handler 個別 TimeConstrained**: 各コールバック handler の処理に個別の `TimeConstrained` を適用し、1 つの handler が hang してもメインカーネル全体を巻き込まないようにします。

これらはいずれも内部的な信頼性強化であり、ユーザーが意識して呼び出す新しい公開 API はありません。通常の `ClaudeEval` / `ClaudeQuery` / `ClaudeUpdateDocumentation` の利用フローの中で自動的に適用されます。フリーズが発生していた間もジョブの実体(子プロセスや出力ファイル)はディスク側で処理が進行しているため、フリーズはあくまで UI 応答性の一時停止であり、実行中のタスクの結果が失われるものではありません。ドキュメント更新については、この対策に加えて 2026-07-10 の外部プロセス化(`$ClaudeDocUpdateExternal`、詳細は「ドキュメント更新の外部プロセス実行」を参照)により、複数の並列更新でメインカーネルが飽和すること自体を防ぐ、より根本的な対策が導入されています。

**Wolfram プロセス一覧取得の既定無効化(2026-08-04)**: seat-exhaustion(Claude Code CLI のライセンス席枯渇)を診断するための残留 `WolframKernel.exe` プロセス一覧取得(`tasklist` コマンドまたは `SystemProcesses` 経由)は、共有ポーリング tick の書き戻し経路から呼ばれ得る内部処理でしたが、実測により共有カーネル環境では `tasklist` 呼び出しと `SystemProcesses` 呼び出しの双方が tick 内で戻ってこないことが確認されました。`RunProcess` / `SystemProcesses` はこの状況で `TimeConstrained` によっても強制的に打ち切ることができず、FrontEnd がブロックされ続けてしまいます。この対策として、プロセス一覧取得は内部フラグ(既定 `False`)により既定で無効化され、共有ポーリング tick からの自動実行は行われなくなりました。残留する `WolframKernel.exe` プロセスを確認したい場合(seat-exhaustion のレポートでどのプロセスを終了すべきか確認したい場合など)は、端末で以下を直接実行してください。

```
tasklist /FI "IMAGENAME eq WolframKernel.exe"
```

一覧取得を明示的に再度有効化したい場合は内部フラグを `True` に設定できますが、上記のブロッキングリスクがあるため、通常は端末での確認を推奨します。この変更は内部的な信頼性強化であり、新しい公開 API の追加はありません。

なお、フォールバックモデルへの切替(多段フォールバック)についても、429(レート制限)やサーバー過負荷エラーが短時間に連続した際にモデル切替そのものが負荷を増大させないよう、次候補の起動を指数バックオフ(1秒→2秒→4秒を上限とする遅延)で行うよう改善されています。

#### ClaudeQueryBg のマルチモーダル対応

`ClaudeQueryBg` は FrontEnd 操作・ScheduledTask 生成なしで Claude Code CLI を `RunProcess`(同期呼び出し)経由で実行する関数です。テキスト文字列だけでなく、`Image` オブジェクトや `File[path]` を含むリスト形式の入力を受け付けます。これにより、SocketListen ハンドラや ScheduledTask コールバックなどの非同期コンテキストから、画像付きの問い合わせを安全に実行できます。デフォルト(`Fallback -> False`)では課金 API を使用せず、Claude Code のサブスクリプション範囲内で動作します。

```mathematica
(* テキストのみ(従来どおり) *)
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
| メディアなし(文字列のみ) | CLI または API(テキスト) | 従来どおりテキストを結合して送信 |
| メディアあり + provider = `claudecode`、`Fallback -> False`(デフォルト) | CLI パス | `iNormalizePrompt` で `Image` を PNG ファイルに保存し、`--image` フラグ経由で CLI に渡す |
| メディアあり + provider = `lmstudio` | OpenAI 互換 chat/completions パス | OpenAI 互換のマルチモーダル形式 (`content` 配列) で LM Studio へ直接送信。2026-07-29 以前は `/api/v1/chat` がテキスト専用のため画像が破棄されていた。 |
| メディアあり + `Fallback -> True`、provider = `anthropic` 等 | Anthropic API マルチモーダルパス | `content` 配列にテキストブロックと画像ブロックを組み立てて API に直接送信 |

CLI パスでは画像ファイルが一時ディレクトリに保存され(最大 1024 px にリサイズ)、Claude Code CLI が `--image` フラグでそれを参照します。API パスでは PNG バイト列を Base64 エンコードした `image` コンテンツブロックを `content` 配列に追加して送信します。LM Studio パスでは OpenAI 互換の chat/completions エンドポイントにマルチモーダルリクエストを送信します。

#### Anthropic API 通信の Windows エンコーディング対応

Anthropic API 経由のフォールバック通信(`ClaudeQueryBg`)では、Windows 固有の暗黙的エンコーディング変換による日本語文字化けを防ぐため、以下の方針で実装されています。

- **リクエストボディ**: `ExportByteArray["JSON"]` を使用して UTF-8 ByteArray として送信します。`ExportString["JSON"]` を String で `Body` に渡すと Windows 環境で ShiftJIS への暗黙変換が発生するため、これを回避しています。また、非 ASCII 文字はすべて `\uXXXX` 形式の JSON エスケープに変換してから送信します。
- **レスポンス受信**: `URLRead` で `"BodyByteArray"` として受信し、`ImportByteArray["RawJSON"]` で ByteArray のまま直接 JSON パースします。`ByteArrayToString` を経由しないため、Windows の暗黙的エンコーディング変換が入りません。
- **フォールバック**: `ImportByteArray` が失敗した場合は、明示的に UTF-8 指定した `ByteArrayToString[rb, "UTF-8"]` でデコードしてから文字列版のパーサーを試みます。

この実装により、Windows 11 の `$CharacterEncoding` が ShiftJIS 等に設定されている環境でも、Anthropic API との通信で日本語テキストが正しく送受信されます。

#### OpenAI 互換 API 通信の Windows エンコーディング対応(2026-08-04)

`openai` / `zai` / `kimi` プロバイダが使用する OpenAI 互換 chat/completions リクエストの本文構築についても、Anthropic API 経路と同様の Windows エンコーディング対策が適用されました。

従来はリクエスト本文を `"{\"model\":\"" <> model <> "\",\"messages\":[{\"role\":\"user\",\"content\":" <> ExportString[prompt, "RawJSON"] <> "}]}"` のような文字列連結で手組みし、String として `Body` に渡していました。この方式には次の 2 つの問題がありました。

- `model` 変数がそのまま JSON 文字列に埋め込まれるため、モデル名に JSON エスケープが必要な文字が含まれていた場合に不正な JSON が生成され得る。
- 手組みした JSON 文字列を String として `Body` に渡すため、送信層で再度エンコード処理が行われ、Windows 環境で ShiftJIS 等への暗黙変換(送信層での再符号化 = 二重エンコード)が発生し得る。

現在は内部関数 `iOpenAIChatBodyBytes[model, prompt, temperature]` が、文字列連結ではなく Association(`<|"model" -> model, "messages" -> {<|"role" -> "user", "content" -> prompt|>}|>`、`temperature` が数値のときのみ `"temperature"` キーを追加)から直接 `ExportByteArray["RawJSON", "Compact" -> True]` で UTF-8 ByteArray を生成し、それを `Body` に渡すよう変更されました。これにより、`model` 側の JSON エスケープも正しく行われ、送信層での再符号化(二重エンコード)も発生しなくなりました。JSON の直列化自体が失敗した場合は `"Error: OpenAI API リクエスト JSON の直列化に失敗しました"` が返されます。2026-08-16 の改訂で LM Studio 経路にモデル別推奨 temperature が導入された際も、`Automatic` / `None` 指定時は温度パラメータを送信しないという従来の挙動がそのまま維持されています。

この変更は内部的な信頼性強化であり、新しい公開 API の追加はありません。

#### CLI 警告行の自動除去(プレーンテキスト応答、2026-07-16〜)

Claude Code CLI は、未 trust のワークスペースで実行された場合や `.claude/settings.json` の一部 `permissions.allow` エントリが無視された場合などに、stderr へ以下のような警告・通知行を出力することがあります。

- `"...has not been trusted. Run Claude Code interactively here once ..."`(trust dialog 未承認の警告)
- `"Ignoring N permissions.allow entries from .claude/settings.json: this workspace ..."`(許可エントリ無視の警告)

CLI をプレーンテキスト経路(`iMakeBat`)で呼び出す実行方式では、`2>&1` によって stderr がプレーン応答の先頭に混入することがあります。ストリーミング JSON 経路(`iStreamJsonLikeQ` を用いる経路)はこの種の混入に以前から対策済みでしたが、プレーン経路は未対策のままでした。実際に 2026-07-16 に、未 trust のワークスペースで実行した際の警告文がそのまま「正常な応答」として採用されてしまう事故が発生しています。

この対策として、内部関数 `iStripLeadingCLIWarnings` が導入されました。応答テキストの先頭から連続する CLI 警告行(および空行)のみを、厳格な signature 一致(`"has not been trusted"` + `"permissions."` + `"settings.json"` の組み合わせ、または `"Ignoring"` で始まる行など)で判定して除去します。本文中に警告文言に似た引用が含まれる場合でも、先頭以外は判定対象外のため誤って削除されることはありません。応答全体が警告行のみで構成されていた場合は空文字列 `""` を返すため、下流の空応答判定(fail-fast 分類等)が正しく機能します。この処理はプレーンテキスト応答を返すすべての経路に自動的に適用される内部的な信頼性強化であり、ユーザーが意識して呼び出す新しい公開 API はありません。

### SourceVault 連携

SourceVault パッケージをロードすると、以下の追加 API が利用可能になります。

#### ultra モデルクラスの制御

`CreateImplementationWorkflow` の実装者ロールは、`$ClaudeUltraEnabled` を `True` に設定した場合に限り ultra モデルクラス(`ClaudeUltraModelSpec` で解決)を優先的に使用します。このクラスは SourceVault モデルレジストリの `"code-ultra"` / `"ultra"` インテントで管理され、`claude-fable-5` などが該当します。

**`$ClaudeUltraEnabled`**

```mathematica
(* False (デフォルト): 常に $ClaudeModel をそのまま使用し ultra へのアップグレードを行わない *)
$ClaudeUltraEnabled = False

(* True: 仕様生成・実装ワークフローで ultra モデルへ自動アップグレード *)
$ClaudeUltraEnabled = True
```

デフォルトが `False` になっているのは、以前の既定 `True` では実装者ロールが暗黙のうちに ultra モデルへアップグレードされ、共有 fable セッションの使用枠を意図せず消費してしまう事故が 2026-08-03 に発生したためです(オーナー指示による方針変更)。ultra モデルを積極的に使いたい場合は明示的に `True` を設定してください。アドバイザリーロール(`$ClaudeAdvisaryModel`)はこの設定の影響を受けません。

**`ClaudeUltraModelSpec[]` / `ClaudeUltraModelSpec[nb]`**

ultra クラスモデルを `{provider, modelId}` 形式で解決します。以下のいずれかに該当する場合は `$Failed` を返し、呼び出し元は `$ClaudeModel` にフォールバックします。

- SourceVault のモデルレジストリにエントリが存在しない
- CLI が利用不可
- アクティブなレート制限がある
- `$ClaudeUltraEnabled = False`(デフォルト)

プロバイダ優先順位は CLI 優先です。`{"claudecode", <id>}` 経由の Claude Code CLI が最優先され(サブスクリプション内; ノートブックの paid-API 禁止設定下でも許可)、`{"anthropic", <id>}` のメーター制 API は当該ノートブックが paid-API 許可(`NBGetNotebookPaidAPIAllowed`)の場合のみ候補になります。

```mathematica
(* ultra モデルを解決する例(事前に $ClaudeUltraEnabled = True が必要) *)
$ClaudeUltraEnabled = True;
spec = ClaudeUltraModelSpec[]
(* → {"claudecode", "claude-fable-5"} または $Failed *)

(* 特定のノートブックのコンテキストで解決する *)
spec = ClaudeUltraModelSpec[EvaluationNotebook[]]
```

#### CreateImplementationWorkflow の proven-code ゲート

`CreateImplementationWorkflow` は 2026-07 の改訂により、承認条件として**実装コードのテストが新規カーネルで合格すること**が追加されました(proven-code ゲート)。

```mathematica
(* 仕様を実装ワークフローとして構築(既定では $ClaudeModel で実装される) *)
CreateImplementationWorkflow["my-feature", "sv://snapshot/Spec/abc123"]

(* ultra モデルを明示的に有効化して実装する場合 *)
$ClaudeUltraEnabled = True
CreateImplementationWorkflow["my-feature", specText,
  "Notes" -> "performance is critical",
  "MaxRounds" -> 5]
```

実装フローの概要:

1. **計画フェーズ**: 実装者(`$ClaudeUltraEnabled = True` の場合は ultra クラス)が仕様を読み込み、複雑な場合は実装を段階(stages)に分割するための補助仕様を作成します。ultra クラス実装者は実装スタイル(native / dag / petri)も計画フェーズで選択します。
2. **実装フェーズ**: 実装者がパッケージ本体とテストファイルを生成します。
3. **proven-code ゲート**: 生成されたテストが新規カーネルで実行され、合格するかどうかを確認します(サマリーキー: `TestGate` / `Proven`)。
4. **検証フェーズ**: アドバイザリーロール(`$ClaudeAdvisaryModel`)が仕様との照合を行い、フィードバックを返します。
5. **ラウンド繰り返し**: 最大 `MaxRounds`(デフォルト 3)回まで実装→検証を繰り返します。全体デッドライン(約 90 分)を超えた場合は残りのラウンドを打ち切ります。

完了すると、生成されたワークフローの起動関数がスラッグ・表示名をキーワードとして PromptRouter に自動登録されます。

#### SourceVault 連携の主要 API

| 関数 / 変数 | 説明 |
|---|---|
| `$ClaudeEvalPromptRouterDispatch` | PromptRouter ブリッジの有効/無効。`Automatic`(デフォルト)で PromptRouter を試行し `NotDispatched` なら自然言語ルーターへ。`False` で常に自然言語ルーター。 |
| `$ClaudeEvalPromptRouterPreemptsNatural` | `True`(デフォルト): PromptRouter が先に走る。`False`: 自然言語ルーターを先に試す。 |
| `$ClaudeAdvisaryModel` | アドバイザリーロールのモデル指定。`{"chatgptcodex", Automatic}` がデフォルト。 |
| `$ClaudeUltraEnabled` | ultra モデルへの自動アップグレード制御(デフォルト `False`)。 |
| `ClaudeUltraModelSpec[]` | ultra クラスモデルの `{provider, modelId}` 解決。解決不可時は `$Failed`。 |
| `ClaudeSpecStatus[]` | spec/consensus 状態の確認。 |
| `ClaudeSpecVersions[]` | spec/review バージョン一覧(Dataset)。 |
| `ClaudeSpecText[uri]` | sv:// URI から spec/review 本文を取得。 |
| `ClaudeOpenSourceVaultURI[uri]` | sv:// URI を新規ノートブックで開く。 |
| `CreateImplementationWorkflow[name, spec]` | 承認済み仕様からワークフローを実装(proven-code ゲート; `$ClaudeUltraEnabled = True` の場合は ultra モデル)。 |
| `LaunchImplementationWorkflow[name, args]` | 生成ワークフローの起動。 |
| `ClaudeImplStatus[]` | spec-impl ワークフロー実行状況の確認。 |
| `ClaudeImplMonitor[]` | 実行状況の自動更新パネル。 |

### セッション管理の改善

セッション履歴の管理において、`iSessionAppend` と `iSessionUpdateLast` による効率的な差分更新機能が実装されています。プロンプトに含まれるキーワードが 600 文字を超える場合は各 300 文字に切り詰める制御により、過度に長い履歴エントリによるパフォーマンス低下を防ぎます。

### スケジューリング

```mathematica
(* 3時間後に実行 *)
ClaudeEval["レポート生成", StartTime -> Now + Quantity[3, "Hours"]]

(* 2時間ごとに繰り返し(TaskObject を返す) *)
ClaudeEval["監視タスク", RepeatInterval -> Quantity[2, "Hours"]]

(* 最大5回まで1時間ごとに実行 *)
ClaudeEval["チェック", RepeatInterval -> {Quantity[1, "Hours"], 5}]
```