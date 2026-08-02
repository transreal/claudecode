# claudecode — 設計思想と実装の概要

Mathematica ノートブックから Claude Code CLI を呼び出し、コード生成・デバッグ・パッケージ管理・ドキュメント生成を対話的に行うパッケージです。

claudecode は、Mathematica のノートブック環境と Claude Code CLI をシームレスに統合することを目的として設計されています。ユーザーは自然言語でタスクを記述するだけで、Mathematica コードの生成・実行・デバッグ・レビューを一貫したワークフローの中で完結できます。

本パッケージの中核となる設計思想は以下の点です。

**ノートブック中心のコンテキスト共有**: ClaudeEval や ClaudeQuery を呼び出す際、ノートブック内のセル履歴（入力・出力・エラーメッセージ）が自動的に収集され、Claude へのプロンプトに組み込まれます。これにより、ユーザーが手動でコードを貼り付ける必要がなく、Claude は現在の作業状態を正確に把握した上で応答を生成します。コンテキスト収集は [NBAccess](https://github.com/transreal/NBAccess) パッケージに委譲されており、セルの読み書き・プライバシー管理・変数追跡といった低レベル操作は分離されています。

**機密データの自動保護**: API キーや個人情報を扱うセルは `Confidential` ラッパーや `MarkConfidential` によって機密マークされ、以降の Claude プロンプトから自動的に除外されます。さらに CellEpilog を利用した伝播機構により、機密変数を参照する下流のセルも自動検出・マーキングされます。機密変数が存在する場合のみ高コストな依存グラフ構築・走査を実行するため、通常使用時のオーバーヘッドは最小限に抑えられます。`NonConfidential` で明示的に公開指定することも可能で、きめ細かなプライバシー制御を実現しています。LLM 送信直前には全ノートブックを走査して完全な依存グラフを構築し、秘密依存変数の最終判定を行う精密チェック（第2層）が実行されます。別ノートブック経由の秘密依存も自動検出されます。`$NBSendDataSchema` が有効な場合、機密依存の出力にはスキーマ情報（型・キー一覧等）が自動付与され、ClaudeEval がプロービングなしで変数の構造を把握できます。

**ファイルアクセスのファイアウォール**: Claude Code が参照できるディレクトリはグローバル変数 `$ClaudeAccessibleDirs` で規定されており、その初期値は `$packageDirectory` のみです。`$packageDirectory` 配下以外の新規ディレクトリを追加すると、初回使用時に許可確認ダイアログが表示される安全機構も備えています。Claude の行動原理は次の通りです。

> 問題の本質
> 「指令を書いても Read ツールを止められない」のは当然で、Claude Code はプロンプト中にファイルパスが見えている限り Read ツールを使います。「読むな」と書いても、パスが見えれば読みに行くのが Claude Code の自然な動作です。
> 解決策: パスを Claude Code に見せない

したがって、Read 可能なディレクトリを安易に追加すること自体が設計上の誤りです。ファイルを参照させる場合は、作業中のノートブックで `ClaudeAttach` 関数を陽に実行することで、当該ファイルを `$packageDirectory/claude_attachments` にコピーを作成し、そのコピーを参照させることでファイルアクセスのファイアウォールを護持します。もちろん、コードを作成または修正して `ClaudeEval` で自動実行させることは技術的に可能であるため、これは本質的な問題の解決ではありません。しかし、Mathematica 側の LLM に依存しないロジックによってコードの健全性を確認する機構を厳格化することで対処することができます。

**セッションによる会話の継続性**: セッション機構により、複数回のやり取りにわたって会話履歴を保持します。セッションはノートブックの TaggingRules に永続化されるため、ノートブックを閉じて再度開いた後でも会話を再開できます。履歴が長くなった場合はエントリ数ベースとサイズベースの二重チェックにより自動または手動でコンパクションが行われ、トークン消費を抑制します。名前付きセッションの作成・継承・復元・削除が可能で、複数の独立したタスクを並行して進められます。また、セッション単位の履歴削除機能により、不要な履歴を個別に削除してストレージを効率的に管理できます。

実装面では、Claude Code CLI をバックエンドとして利用し、`--output-format stream-json` モードでリアルタイムにストリーミング出力を解析します。問い合わせ中は経過時間に加え、現在の状態（思考中・テキスト生成中・ツール実行中）やフラグメント数をリアルタイムで表示します。エラー出力は stderr 経由で分離処理され、stdout の JSON ストリームと干渉しない設計になっています。ファイルパス操作には `FileNameJoin` を一貫して使用し、OS 非依存のパス構築を徹底しています。

作業ディレクトリ (`$ClaudeWorkingDirectory`) 配下の CLAUDE.md やディレクティブ (rules/skills) が Claude Code に自動的に読み込まれ、プロジェクト固有のガイドラインを反映した応答が得られます。プロジェクトディレクティブ機構により、NotebookDirectory ごとに独立したルール・スキルを定義し、メインのディレクティブと自動マージできます。Claude Code CLI が利用できない場合のフォールバック機構として、Anthropic API・OpenAI API・z.ai（GLM シリーズ）API・Kimi（Moonshot AI）API への直接呼び出しに加え、LM Studio 等のローカル LLM サーバーへの接続もサポートしています。フォールバックモデルは `$ClaudeFallbackModels` で優先順位付きで設定でき、`{provider, model, url}` の3要素形式でカスタム URL を指定できます。アクセスレベルに基づいて利用可能なモデルのみが選択されるプライバシー対応ルーティングにより、機密データの処理をローカルモデルへ自動転送できます。

**LM Studio の主モデル利用と MCP ツール連携**: `$ClaudeModel` に LM Studio のエンドポイントを直接指定することで、すべての ClaudeEval/ClaudeQuery を LM Studio 経由で実行できます。さらに `$ClaudeLMStudioIntegrations` に MCP サーバー ID を指定すると、LM Studio がサーバー側で tool-call を自動実行し、Web 検索等の MCP ツールをローカル LLM から呼び出せます。これにより、プライバシーを優先しながら外部ツール統合を実現できます。2026-07-29 より LM Studio プロバイダに対してもマルチモーダル入力（テキスト + 画像）が可能になり、OpenAI 互換の chat/completions エンドポイント経由で画像を含むクエリを送信できます。

**ChatGPT Codex CLI の provider 利用**: Claude Code CLI に加えて、OpenAI の ChatGPT Codex CLI を provider として利用できます。`$ClaudeModel` を `{"chatgptcodex", Automatic}` に設定すると、ClaudeEval/ClaudeQuery が Codex CLI 経由で実行されます。Codex provider は Claude CLI と同じ非同期実行経路で動作し、Codex 実行ごとに一時的な作業ディレクトリと CODEX_HOME を作成して `codex login` の認証情報を引き継ぎます。Codex のモデル名は SourceVault のモデルレジストリが一元管理し、具体的な LLM モデル ID をパッケージソースに直書きしない設計を採っています。**仕様レビュー合意ワークフロー**では `$ClaudeAdvisaryModel`（既定: `{"chatgptcodex", "Automatic"}`）が Codex アドバイザリーロールのモデルとして使用されます。

パッケージ管理機能 (`ClaudeUpdatePackage`, `ClaudeRestorePackage`) では、既存の .wl パッケージを Claude の支援で更新し、差分ベースの自動バックアップにより安全なイテレーションを実現します。バックアップシステムは `SequenceAlignment` ベースの差分保存を採用し、`.cz`（ベースライン）・`.cdiff`（差分）・`.unchanged`（参照）の3形式でストレージ消費を大幅に削減します。差分チェーンの中間ノードを削除する際も依存関係を自動解決し、復元不能になることを防止します。既存の生バックアップは `ClaudeMigrateBackupHistory` で差分形式に一括変換できます。コード生成・マージ後には検証テストが自動生成・実行され（`===BEGIN_TESTS===` ～ `===END_TESTS===` ブロック）、意図した変更が正しく反映されているか確認します。LLM レスポンスは「連続した行のかたまり（セグメント）」単位でマージされるため、マージ精度が大幅に向上しています。`パッケージ名\`関数名` / `パッケージ名\`Private\`内部関数名` のような完全修飾定義も正しく認識されます。

パッケージキーワード自動注入システムにより、各外部パッケージが `$ClaudePackageKeywordMap` を通じて独自のキーワードを登録し、プロンプト中にキーワードが含まれる場合に自動的にそのパッケージの API ドキュメントをコンテキストに注入します。これにより claudecode.wl はパッケージ非依存を保ちつつ、必要な API ドキュメントを自動的に提供できます。さらに `$ClaudePackageAuxKeywordMap` により、パッケージ本体とは別に提供される補助 API ドキュメント（`api_<aux>.md` 形式）ごとに注入条件となるキーワードを個別指定することも可能です。複数パッケージのキーワードが同一タスクに同時一致した場合は、各パッケージの api.md がタスク文中でそのパッケージ名・キーワードが最初に言及された位置（mention 順）でコンテキストに注入され、その際キーワード一致した補助ドキュメントが対応する本体 api.md より先に優先注入されます（この順序制御は自動で、追加設定は不要です）。

ドキュメント生成機能 (`ClaudeCreateDocumentation`, `ClaudeUpdateDocumentation`) では、ソースコードから API リファレンス・使用例・セットアップガイドなどの文書一式を自動生成します。ドキュメント更新時はノートブックの現在のコンテキストも参照でき、「上で議論された内容を反映して」といった自然な指示が可能です。`TargetFiles` オプションでは `api`・`setup`・`user_manual`・`example`・`README` の5種類の .md ファイルのみが許可リストとして設定されており、拡張子 `.md` は省略可能（自動補完）です。`Baseline` オプションにより差分検出の基準を選択でき、`"LastDocUpdate"`（直近のドキュメント更新バックアップ）と `"Github"`（GitHub コミット版）のいずれかを指定できます。`"Github"` を指定すると、コミット版以降のソースコード変更に加えて `_info/design` 配下の新規設計ドキュメントも加味した更新が行われます。ドキュメント更新チェーンの多重起動防止ガードにより、同一パッケージに対して複数の更新チェーンが同時起動することを防ぎます。チェーンが異常終了した場合も `$ClaudeDocUpdateStaleSeconds` 秒後に自動解放されます。更新失敗は「システム的失敗（fail-fast でチェーンを即中断）」と「品質ゲート失敗（切り詰め・サイズ退行・タイトル不整合。当該ファイルのみスキップして次へ進む）」に明確に分類されるため、1 ファイルの持続的な品質失敗が残り全ファイルの更新を巻き添えにすることがなくなりました。品質ゲート失敗時はまず 1 回だけ自動リトライが行われ（単一応答での出力・ツール不使用・コードフェンスの正しい閉じを明示する RETRY NOTICE をプロンプトに追加注入）、それでも同じ理由で失敗した場合にのみ当該ファイルをスキップします。品質ゲート失敗時のリトライ・スキップ経路においても、共有ポーリングタスクの再発火や派生クエリの二重起動によってドキュメント更新チェーンが分岐（fork）してしまう不具合を防ぐため、各ステップに一意のシリアルトークンを発行し最初のコールバックのみを有効化する二重発火ガードが導入されています。既存ファイルへの上書き時には、新しい内容が既存内容の 40% 未満に縮小した場合は書き込み自体を拒否するサイズ退行ガードも機能します。また `docs/` 配下に同期事故等で生じた `docs/docs/` ネスト重複ドキュメントを自動検出し、更新対象から除外した上で削除を推奨する警告を表示します。さらに `docs/examples/` 配下の使用例ドキュメント（`*.md`）は、既定（Automatic）モードでの自動更新対象から除外されます。使用例ドキュメントの多くは手作業で作成された内容であり、毎回自動再生成すると数が多い場合に更新が終わらなくなるための設計で、更新する場合は `TargetFiles` オプションで明示的に指定する必要があります。`Disclaimer`・`License`・`Acknowledgments` 等のオプションで免責事項・ライセンス情報・謝辞を指定でき、`References` オプションで参考文献リストを、`Demos` オプションでデモ動画や使用例のリンクを README に追加できます。これらは `doc_options.json` に永続化されて以降の更新でも保持され、README 本文の書き込み後にこれらの法的節がコード側で決定的（verbatim）に追記されるため、LLM 出力の切り詰めの影響を受けません。補助 API ドキュメント（`api_<aux>.md`）の再生成要否判定は、更新日時（mtime）比較からコンテンツハッシュ比較へ段階的に移行しており、Dropbox 同期や複数 PC 環境による mtime のずれだけでは不要な再生成が発生しないようになっています。ドキュメント生成にはトークン節約のためソースコードのチャンク化が行われ、ドキュメント種別ごとに関連セクションのみを選択的に送信します。ドキュメント生成専用モデル (`$ClaudeDocModel`) を指定でき、Sonnet クラスの安価なモデルでコスト効率よく生成できます。リミット到達時は自動停止し、再実行で未生成分のみ続行します。20 ファイル以上の一括更新時は、README を除くドキュメントを LLM へ並列投入し、ウィンドウステータスバーにリアルタイム進捗（完了数・並列実行数・経過時間）を表示します。API エラー等で中断した場合も、サイクル再開（resumption）機能により同一サイクル内の更新済みファイルをスキップして効率的に継続できます。条件を満たす場合はドキュメント更新パイプライン全体を外部 wolframscript ワーカープロセスへ退避して実行する仕組み（`$ClaudeDocUpdateExternal`）も備えており、複数のドキュメント更新を並走させた際のメインカーネル飽和によるフリーズを防止します。ディレクティブファイルの書き込みには、サイズ退行・タイトル整合性・スキル名保持を検証するガード機構 (`iSafeWriteDirective`) が組み込まれています。

AI 生成機能として、OpenAI Images API による画像生成（`ClaudeImageGenerate`）と OpenAI TTS API による音声合成（`ClaudeSpeech`）を統合しています。ClaudeQuery のリッチレスポンスモードでは、ユーザーの要求に応じて自動的にこれらの API を呼び出すコードや、安全な可視化コード（Plot、Graphics 等）を自動評価します。

**自動実行安全ガード**: `ClaudeEval` の `AutoEvaluate -> True` で生成コードを自動実行する際、`NBAutoEvalProhibitedPatterns` に定義された禁止パターン（ファイル削除・危険なシステム操作等）に該当するコードの自動実行をブロックします。意図しない破壊的操作を防止する安全機構です。

**共有ポーリングタスク**: 複数の非同期ジョブが実行中の場合、すべてのジョブが単一の共有ポーリングタスクを利用します。ジョブごとに個別の `ScheduledTask` を作成しないため、多数のジョブを並列実行した際のオーバーヘッドが大幅に削減されます。FE 応答性プローブと handler 個別タイムアウトの二段構えの防御により、メインカーネルを長時間ブロックするフリーズを根絶しています。実行中のタスクが応答しない場合は `ClaudeAbort[]` で全タスクを強制停止できます。パッケージの再読み込み時には旧タスクが自動的に停止されるため、安全に再読み込みできます。

**非同期スケジューリング規約の自動注入**: `ClaudeUpdatePackage` のプロンプトに、非同期タスクのスケジューリング規約（claudecode/NBAccess 公開 API の使用義務・例外条件・根拠）を自動注入します。LLM が生成するパッケージコードが正しい非同期パターンに従うよう誘導します。

**Windows エンコーディング安全な API 通信（マルチモーダル対応）**: Anthropic API 経由のフォールバック通信において、リクエストボディは `ExportByteArray["JSON"]` で UTF-8 ByteArray として送信し、非 ASCII 文字は `\uXXXX` JSON エスケープに変換します。レスポンスは `ImportByteArray["RawJSON"]` で ByteArray のまま直接 JSON パースするため、Windows 固有の暗黙的エンコーディング変換（ShiftJIS 等）による日本語文字化けが発生しません。`ClaudeQueryBg` はテキスト・`Image`・`File` オブジェクトを混在したリスト形式の入力（マルチモーダル入力）に対応しており、CLI パスでは画像を PNG に変換して送信し、API フォールバックパスでは Anthropic API のマルチモーダル `content` 配列を構築して送信します。LM Studio プロバイダに対してもマルチモーダル入力が可能（2026-07-29）で、OpenAI 互換の chat/completions エンドポイント経由で画像を含むクエリを送信します。

**自然言語ディスパッチ**: `$ClaudeEvalNaturalDispatch`（既定 `True`）が有効なとき、`ClaudeEval["..."]` のタスク文字列が「今日からの予定」「概要を更新」等の定型パターンにマッチすると、LLM を経由せず SourceVault の高レベル API を直接呼び出します。頻出の定型指示を低コスト・決定論的に処理でき、マッチしないタスクは従来どおり LLM 経路に流れます。マッチ結果や実行サマリを確認したい場合は `$ClaudeEvalNaturalVerbose -> True` で詳細ログを表示できます。さらに「Auto」実行モードでは、タスク文字列が `$ClaudeEvalAutoLLMMinLength`（既定 500）文字未満かつ改行数が `$ClaudeEvalAutoLLMMinNewlines`（既定 3）未満の場合、LLM planner の起動自体を省略して即座に Single 実行に切り替えることで、短い定型タスクの応答をさらに軽量化します。

**claudecode_directives 連携とディレクティブ投影レイヤー**: オプションの独立パッケージ [claudecode_directives](https://github.com/transreal/claudecode_directives) をロードすることで、`rules/` および `skills/` ディレクトリのデフォルトセットが自動的にインストールされます。ロード後は Claude Code CLI のコンテキストに `rules/` の制約と `skills/` の手順が自動的に注入され、Claude がスキルを呼び出せるようになります。これらのディレクティブは Claude Code の振る舞いを規定するルールとスキルを体系的に提供し、claudecode.wl 本体はディレクティブの内容に非依存のまま、claudecode_directives がその管理・配布を担います。NotebookDirectory ごとに独立したプロジェクト固有のルール・スキルを定義してメインのディレクティブと自動マージすることも可能です。

このパッケージは、単なる rules/skills の配布にとどまらず、**ディレクティブ投影レイヤー（ClaudeDirectives）** を備えています。正規ディレクティブ・リポジトリ（`.claude/CLAUDE.md` / `rules/` / `skills/`）を読み込み、モデルの能力（コンテキスト長・課金有無・クラス）・ロール・タスク内容に応じて、投影モード（**Full / Summary / Index / Lazy**）と適用するスキル・ルールを in-memory で動的に選択します。モデル能力は `$ClaudeModelCapabilities` テーブルで管理され、`"claudecode"`（CLI・課金なし）/`"anthropic"`（API・課金）/`"openai"`（API・課金）/`"lmstudio"`（ローカル・課金なし）の provider 別に登録されます。タスク内容に応じたルール選別は、常時注入対象（`$ClaudeAlwaysOnRules`）を除き、rule の frontmatter に記載されたキーワード・パスとタスクヒントとの一致度によってスコアリングされます。さらに、単一の正規リポジトリから Claude CLI 用（`.claude/`）と Codex CLI 用（`AGENTS.md` / `.agents/`）のハーネスを生成・実体化する機能を備え、ファイル形式は Claude Code 互換を維持します。Claude CLI ハーネスの生成方式は `$ClaudeCLIHarnessMode` で制御でき、`"Direct"`（既定・作業中の `.claude/` をそのままコピー）と `"Generated"`（正規ディレクティブリポジトリから `.claude/` を生成するオプトインモード）を選択できます。投影レイヤーは claudecode.wl / NBAccess.wl に依存しない純 Wolfram Language 実装で、claudecode.wl 側から optional に統合されます。リポジトリのインベントリ・Manifest・ContentHash 算出による整合性管理も備えています。

**ClaudeRuntime 統合**: オプションの独立パッケージ [ClaudeRuntime](https://github.com/transreal/ClaudeRuntime) をロードすることで、`ClaudeEval` のバックエンドとしてランタイムセッション管理機能が有効になります。ランタイムはターン数・プロファイル・失敗履歴を追跡し、内部状態を保持した複数ターンにわたる対話を可能にします。危険な操作(内部変数の直接書き換え等)に対しては自動的に承認フロー(`NeedsApproval`)を介挿し、意図しない破壊的操作を防止します。ClaudeRuntime をロードすると `$UseClaudeRuntime = True` が自動的に設定され、以降の `ClaudeEval` 呼び出しは ClaudeRuntime 経由でルーティングされます(claudecode を単独でロードした場合はデフォルトの `$UseClaudeRuntime = False` のまま従来動作を維持)。

**ClaudeOrchestrator 連携**: オプションの独立パッケージ [ClaudeOrchestrator](https://github.com/transreal/ClaudeOrchestrator) をロードすることで、`ClaudeEval` がオーケストレーター管理下の非同期実行モードに切り替わります。呼び出しはジョブキューに追加されて即座に返り、カーネルをブロックしません。複数タスクのジョブキュー管理・レート制限の自動検出と待機・リトライスケジューリングが透過的に処理され、長時間・大規模なタスクを安定して継続実行できます。`ClaudeRateLimitStatus[]` が返す復旧予定時刻を参照して待機タイミングを自動判断するため、高頻度タスクでの利用に適しています。`ClaudeRateLimitClear[]` でレート制限情報を手動クリアできます。claudecode 本体の動作には影響せず、インストールされていない環境でも全機能をそのまま利用できます。

**ClaudeTestKit 統合**: オプションの独立パッケージ [ClaudeTestKit](https://github.com/transreal/ClaudeTestKit) は、ClaudeRuntime を利用したコード生成の品質を自動テスト・回帰テストで検証するためのフレームワークです。通常の ClaudeEval/ClaudeQuery 使用には不要であり、ClaudeTestKit がインストールされていない環境でも claudecode の全機能は影響を受けません。

**SourceVault 連携（PromptRouter ブリッジ）**: オプションの独立パッケージ [SourceVault](https://github.com/transreal/SourceVault) をロードすることで、`ClaudeEval` の **Order 2 ディスパッチ**として PromptRouter による提案ベースの実行経路が有効になります。SourceVault がタスク文字列から `PromptRouteProposal` を構築し、claudecode 側は提案された `ProposedExpression`（`HoldComplete`）の頭部を ReadOnly 許可リストと照合した上でのみ評価します。適合する場合は LLM 呼び出しを経由せず、許可リスト上の式を直接評価して結果を返すため、頻出する定型タスク（特定の集計・整形・テンプレートコード挿入等）を高速・低コスト・決定論的に実行でき、生成内容の再現性・監査可能性が向上します。claudecode 本体は SourceVault に対してハードな依存を持たず（rule 11）、SourceVault がアクティブでない・許可リスト外の頭部を提案した・エラー・拒否を返した場合は `NotDispatched` となり、従来の自然言語ルーターにフォールバックします。既存ワークフローへの影響はありません。SourceVault をロードすると、仕様書の審査から実装ワークフロー化までを支援する API 群（`ClaudeSpecStatus`・`CreateImplementationWorkflow`・`ClaudeImplMonitor` 等）も利用可能になり、生成されたワークフローはスラッグ名で PromptRouter に自動登録されるため、以降は `ClaudeEval` から直接呼び出せます。また、`ShowClaudePalette[]` の provider/model 選択においても、SourceVault ロード時には `claudecode`・`anthropic`・`chatgptcodex` 各 provider の既定モデル候補がレジストリ経由で動的に解決され、パレット操作から選んだ結果が `$ClaudeModel` に直接反映されます。

**[実験的] LLM 適用グラフ (LLMGraph)**: LLM の適用を記録・可視化するためのグラフ構造を導入しています。Mathematica 14.2 で導入された `LLMGraph` と類似の DAG（有向非巡回グラフ）構造を採用しており（将来的には `LLMGraph` そのものとの統合を目指しますが、現状では独自実装）、`ClaudeEval` / `ClaudeQuery` などを実行すると、自動的にノートブック固有の LLMGraph が生成されます。各ノードは LLM 呼び出しの命令・応答サマリー・アクセスレベル・ステータスなどを保持し、ノード間の関係（コンテキスト継承・データフロー）がエッジとして記録されます。`$LLMGraphMaxConcurrency` によりカテゴリ別（`"cli"`・`"cli-vision"` 等）の並列実行数を制御でき、`LLMGraphDAGCreate` / `LLMGraphExecute` / `LLMGraphDAGRebuild` 系 API によって DAG ジョブの作成・実行・キャンセル・再構築を行えます。DAG のスナップショットは `$ClaudeSnapshots`（既定 `$ClaudeWorkingDirectory` 配下の `snapshots`）に保存されます。`NotebookLLMGraphPlot[]` による DAG 可視化、`NotebookLLMGraphSummary[]` による統計表示、`NotebookLLMGraphExtractThread[]` による実行スレッドの抽出と再適用など、豊富な分析 API を備えています。この実装は、`claudecode_info/design/` にある 1992-WOOC'92.pdf および 1993-WOOC'93「信号処理に向いたオブジェクトモデルの提案と応用」で議論されている、データの構造を保ったまま定義域ごとに適応的に処理を適用するモデルを下敷きにしています。

**[実験的] プライバシー分割ファイル処理 (ClaudeProcessFile)**: LLMGraph の応用として、ノートブックファイル（.nb）のセルをプライバシーレベルに基づいて自動分割し、公開セルはクラウド LLM（Claude Code CLI）、秘匿セルはプライベート LLM（LM Studio 等）で並列処理してマージする `ClaudeProcessFile` を搭載しています。`ClaudeEval` でノートブックファイルパスを含む指示を与えると自動的に検出・起動され、Splitter → 並列 LLM 処理 → Merger の一連のフローが非同期で実行されます。処理過程は LLMGraph 上に Fork/Join トポロジとして記録されます。

外部ファイルのアタッチメント機構や Web 検索・取得機能により、ノートブック外の情報源も活用できます。ディレクティブ管理機能を通じて、Claude Code の振る舞いを制御する CLAUDE.md やルール・スキルファイルの追加・更新・整合性チェックをノートブック内から行えます。`ClaudeUpdateDirective[]` はソースコードの公開 API とディレクティブファイルの整合性を自動検査・修正することで、ドキュメントとコードの乖離を防ぎます。`ClaudeUpdateDirective[text]` ではテキストの内容を Claude で解釈し、CLAUDE.md / rules / skills の適切なファイルに反映できます。ディレクティブの変更履歴は自動バックアップされ、`ClaudeDirectiveBackupDataset[]` で閲覧・復元が可能です。

多言語対応として、`$Language` に基づいてプロンプト内の言語指定を動的に生成します。`$Language` が `"Japanese"` の場合は日本語で応答するよう指示し、それ以外（英語環境など）の場合は英語に切り替わります。日本語の励まし表現（「死ぬ気で考えろ」「よく考えて」等）を自動検出し、Claude の thinking budget を適切に設定する Think トリガー自動挿入機能も搭載しています。

操作パレット (`ShowClaudePalette[]`) を使うことで、よく使う操作をボタンひとつで実行できます。ClaudeEval の実行・ContinueEval による継続・セッション管理・パッケージ更新など主要な操作がパレット上に集約されており、コードを入力せずにノートブックから直接 Claude を操作できます。

## 詳細説明

### 動作環境

| 項目 | バージョン |
|------|-----------|
| Mathematica | 13.0 以上（14.x 推奨） |
| Node.js | 18 以上 |
| Claude Code CLI | 最新版 |
| ChatGPT Codex CLI | 最新版（オプション・`chatgptcodex` provider 利用時） |
| OS | Windows 11（macOS/Linux ではパス区切りやシェルコマンドを適宜読み替えてください） |

### インストール

#### 1. 外部ツールのインストール

Claude Code CLI を[公式サイト](https://claude.ai/download)からダウンロードしてインストールしてください。

```bash
# Claude Code CLI の確認
claude --version
```

[Node.js 公式サイト](https://nodejs.org/) から最新の LTS バージョンをダウンロードしてインストールしてください。

```bash
# Node.js の確認
node --version
npm --version
```

claude コマンドを実行すると、対話形式でログイン手順が表示されるため、画面の案内に従って認証を完了してください。

provider に `chatgptcodex` を指定して Codex 経由でコード生成・クエリを実行する場合は、ChatGPT Codex CLI もインストールしてください（オプション）。Claude Code CLI のみを使う場合は不要です。

```bash
# ChatGPT Codex CLI のインストール
npm install -g @openai/codex

# ChatGPT Codex CLI の確認
codex --version

# OpenAI アカウントでログイン
codex login
```

`codex login` の認証情報は claudecode の Codex 実行に自動的に引き継がれます。Claude Code CLI も Codex CLI もサブスクリプション契約に基づく CLI であり、メーター制 API とは課金体系が異なります。

#### 2. パッケージファイルの配置

以下のファイルをすべて `$packageDirectory` に配置してください。

| ファイル | 説明 |
|---------|------|
| `claudecode.wl` | 本体 |
| `NBAccess.wl` | ノートブック読み書き・プライバシー管理（[GitHub](https://github.com/transreal/NBAccess)） |
| `github.wl` | GitHub REST API 連携（[GitHub](https://github.com/transreal/github)） |
| `cuda.wl` | CUDA 拡張（オプション・[GitHub](https://github.com/transreal/cuda)）。CUDA 関連プロンプト時に自動ロード |
| `claudecode_directives.wl` | rules/skills ディレクティブ管理・投影レイヤー（オプション・[GitHub](https://github.com/transreal/claudecode_directives)）。ロードすると `rules/` および `skills/` のデフォルトセットが自動インストールされ、Claude Code CLI のコンテキストに rules/ の制約と skills/ の手順が自動注入される。モデル能力に応じた投影モード選択と Claude CLI / Codex CLI 双方のハーネス生成を担う |
| `ClaudeRuntime` | 永続ランタイム機能（オプション・[GitHub](https://github.com/transreal/ClaudeRuntime)）。`$UseClaudeRuntime = True` 時に有効化 |
| `ClaudeOrchestrator` | 複数 Claude セッションのオーケストレーション（オプション・[GitHub](https://github.com/transreal/ClaudeOrchestrator)）。ロードすると ClaudeEval が非同期実行モードに切り替わり、呼び出しはジョブキューに追加されて即座に返りカーネルをブロックしない。レート制限の自動検出・復旧・リトライスケジューリングを担う上位レイヤーとして機能する |
| `ClaudeTestKit` | 自動テスト・回帰テストフレームワーク（オプション・[GitHub](https://github.com/transreal/ClaudeTestKit)）。ClaudeRuntime と組み合わせて使用 |
| `SourceVault` | プロンプトルーティング機能（オプション・[GitHub](https://github.com/transreal/SourceVault)）。ロードすると `ClaudeEval` の Order 2 ディスパッチに PromptRouter ブリッジが組み込まれ、登録済みルートに適合するプロンプトは LLM 呼び出しなしで直接評価される |

#### 3. パッケージの読み込み

`$Path` には `$packageDirectory` 自体を追加します。claudecode を使用する場合、`$Path` は自動的に設定されます。

```mathematica
AppendTo[$Path, $packageDirectory];

Block[{$CharacterEncoding = "UTF-8"},
  Needs["ClaudeCode`", "claudecode.wl"]];
```

ファイル名のみの形式 `"claudecode.wl"` は、`$packageDirectory` が `$Path` に含まれているため動作します。

初回ロード時に `node-pty` が未インストールの場合、自動で `npm install` が実行されます。パッケージリロード時には旧バージョンの内部タスク（孤児タスクを含む全共有ポーリングタスク）が自動的に停止されます。

ディレクティブ管理機能（rules/skills）を使用する場合は、claudecode のロード後に別途ロードしてください。

```mathematica
(* claudecode_directives の読み込み（オプション） *)
Block[{$CharacterEncoding = "UTF-8"},
  Needs["ClaudeCodeDirectives`", "claudecode_directives.wl"]];
```

ClaudeRuntime を使用する場合も、claudecode のロード後に別途ロードしてください。ロード時に `$UseClaudeRuntime = True` が自動的に設定されます。

```mathematica
(* ClaudeRuntime の読み込み(オプション) — $UseClaudeRuntime = True が自動設定される *)
<< ClaudeRuntime`
```

SourceVault を使用する場合も、claudecode のロード後に別途ロードしてください。ロード後は ClaudeEval の Order 2 ディスパッチで PromptRouter ブリッジが自動的に有効化されます。

```mathematica
(* SourceVault の読み込み(オプション) — PromptRouter ブリッジが有効化される *)
<< SourceVault`
```

#### 4. API キーの設定

Claude Code CLI の認証が完了していれば、追加の設定は不要です。フォールバック機能で API を直接使う場合は `SystemCredential` に登録してください。

```mathematica
SystemCredential["ANTHROPIC_API_KEY"] = "sk-ant-...";
(* OpenAI フォールバック・画像生成・音声生成を使う場合 *)
SystemCredential["OPENAI_API_KEY"] = "sk-...";
```

LM Studio 等のローカル LLM を使用する場合は、API キーは不要です（`$ClaudePrivateModel` や `$ClaudeFallbackModels` にエンドポイント URL を指定します）。

### クイックスタート

```mathematica
(* パッケージの読み込み *)
AppendTo[$Path, $packageDirectory];
Block[{$CharacterEncoding = "UTF-8"},
  Needs["ClaudeCode`", "claudecode.wl"]];

(* 基本的な問い合わせ（リッチレスポンス: テキスト + コード自動評価） *)
ClaudeQuery["Mathematica で行列の固有値を求める方法を説明してください"]

(* マルチモーダル問い合わせ（テキスト＋画像） *)
ClaudeQuery[{"このグラフの特徴を説明してください", Import["chart.png"]}]

(* 軽量同期クエリ（セッション履歴なし） *)
ClaudeQuerySync["フィボナッチ数列の漸化式を教えてください"]

(* 非同期コンテキストから安全に呼び出せるマルチモーダル背景クエリ *)
ClaudeQueryBg[{"この画像を解析してください", Image[...]}]

(* コード生成・自動実行 *)
ClaudeEval["フィボナッチ数列の最初の10項をリストで返す関数"]

(* エラー修正の継続 *)
ContinueEval["日本語ラベルが文字化けしています。フォント指定を追加して"]

(* 機密データの保護 *)
apiKey = Confidential[SystemCredential["MyAPIKey"]]

(* 秘密データをローカルモデルで自動処理 *)
ClaudeEval["秘密変数 成績 のデータを分析して", AutoPrivate -> True]

(* 参考資料のアタッチ（ファイアウォールを護持しつつ参照させる） *)
ClaudeAttach["spec.pdf"]
ClaudeEval["添付した仕様書に従ってコードを書いて"]

(* AI 画像生成 *)
ClaudeImageGenerate["桜の満開の写真、フォトリアル"]

(* AI 音声生成 *)
ClaudeSpeech["こんにちは、世界"]

(* セッション状態の確認 *)
ClaudeSessionStatus[]

(* 実行中タスクのリアルタイム状態表示 *)
ClaudeStatus[]

(* 実行中の全タスクを強制停止 *)
ClaudeAbort[]

(* 履歴サイズ診断 *)
ClaudeHistorySize[]

(* セッションと全履歴を削除 *)
ClaudeDeleteSession["セッション名", "All"]

(* LM Studio のローカルモデルを使用（Model オプションで直接指定） *)
ClaudeEval["階乗を計算して",
  Model -> {"lmstudio", "openai/gpt-oss-20b", "http://192.168.2.106:1234"}]

(* $ClaudeModel を LM Studio に直接設定（すべての呼び出しを LM Studio で実行） *)
$ClaudePrivateModel = {"lmstudio", "qwen/qwen3.6-27b", "http://127.0.0.1:1234"}
$ClaudeModel = $ClaudePrivateModel

(* LM Studio 経由で MCP ツールを有効化（mcp.json に登録済みのサーバー ID を指定） *)
$ClaudeLMStudioIntegrations = {"mcp/exa"}

(* LLMGraph のカテゴリ別並列度を設定 *)
$LLMGraphMaxConcurrency["cli"] = 4
$LLMGraphMaxConcurrency["cli-vision"] = 1

(* claudecode_directives で rules/skills を有効化（オプション） *)
Block[{$CharacterEncoding = "UTF-8"},
  Needs["ClaudeCodeDirectives`", "claudecode_directives.wl"]];

(* ClaudeRuntime を有効化して使用する(オプション) — ロード時に $UseClaudeRuntime = True が自動設定される *)
<< ClaudeRuntime`
ClaudeEval["斜方投射のグラフを描いてください"]

(* SourceVault を有効化して PromptRouter ブリッジを使う(オプション) *)
<< SourceVault`
ClaudeEval["登録済みルートに該当する定型タスク"]
(* → SourceVault に適合ルートがあれば LLM 呼び出しなしで直接評価される *)

(* ランタイム一覧の確認 *)
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

(* ドキュメントを特定ファイルだけ更新（拡張子省略可） *)
ClaudeUpdateDocumentation["claudecode", "新機能を追記して",
  TargetFiles -> {"api", "user_manual", "README"}]

(* GitHub コミット版を基準に、design の新規内容も加味して更新 *)
ClaudeUpdateDocumentation["claudecode", "最新版に追従して",
  Baseline -> "Github"]

(* GitHub コミット準備 *)
ClaudePrepareCommit["claudecode"]

(* パレット表示 *)
ShowClaudePalette[]
```

#### 主要な設定変数

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `$ClaudeModel` | `""`（未設定） | Claude CLI に渡すプロバイダーとモデル名のペア。タプル `{provider, model}` 形式が標準。パッケージロード直後は `""`（未設定）で、この場合は Claude Code CLI 自身の既定モデルが使用される。`{"lmstudio", "モデル名", "http://host:port"}` 形式で LM Studio を主モデルとして直接指定することも可能。`{"chatgptcodex", Automatic}` 形式で ChatGPT Codex CLI を provider として指定することも可能。provider には `zai`（z.ai の GLM シリーズ API）や `kimi`（Moonshot AI）も指定できる。`ShowClaudePalette[]` でのプロバイダー/モデル選択操作を行うと `$ClaudeModel` にタプル値が反映され、claudecode/anthropic の既定モデル候補は SourceVault 経由で動的に解決される（未解決時は `claude-opus-5` にフォールバック） |
| `$ClaudeAdvisaryModel` | `{"chatgptcodex", "Automatic"}` | 仕様レビュー合意ワークフローにおける Codex アドバイザリーロールのモデル指定。`$ClaudeModel` と同形式（bare provider 文字列 `"chatgptcodex"` も指定可能） |
| `$ClaudeUltraEnabled` | `True` | `True` のとき、仕様生成/仕様実装ワークフローが `$ClaudeModel` ロールを ultra モデルクラス（SourceVault モデルレジストリの `"code-ultra"`/`"ultra"` インテント、例: claude-fable-5）にアップグレードする（利用可能な場合）。`False` で常に `$ClaudeModel` をそのまま使用。アドバイザリーロール（`$ClaudeAdvisaryModel`）には影響しない |
| `$ClaudeStandardFont` | `"Yu Gothic UI"` | ClaudeEval が生成する出力コード（Grid/Column/Style/Button 等）で統一使用されるフォント名。ロード後に任意のフォント名を代入して変更可能 |
| `$ClaudeTimeout` | `1200` | タイムアウト秒数 |
| `$ClaudeVerbose` | `False` | `True` で履歴コンパクション等の詳細ログを出力 |
| `$ClaudeWorkingDirectory` | `FileNameJoin[{$HomeDirectory, "Claude Working"}]` | 作業ディレクトリ |
| `$OpenaiWorkingDirectory` | `FileNameJoin[{$HomeDirectory, "OpenAI Working"}]` | OpenAI / ChatGPT Codex CLI の作業ディレクトリ |
| `$ClaudeSnapshots` | `FileNameJoin[{$ClaudeWorkingDirectory, "snapshots"}]` | LLMGraphDAG スナップショットの保存ディレクトリ |
| `$ClaudeMDPath` | `""` | 読み込まれる CLAUDE.md のパス（自動検索または手動上書き） |
| `$ClaudeMDContent` | `""` | 読み込まれた CLAUDE.md の内容。空の場合は未検出または内容なし |
| `$ClaudeAccessibleDirs` | `{$packageDirectory}` | Claude Code に Read 許可する追加ディレクトリ。パスを見せないことがファイアウォールの本質であり、安易な追加は避けること。`$packageDirectory` 配下以外の新規ディレクトリを追加すると、初回使用時に許可確認ダイアログが表示される |
| `$ClaudeNBDirAccess` | `"list"` | NotebookDirectory のアクセスレベル（`"list"` / `"read"` / `"readwrite"`） |
| `$ClaudeFallbackModels` | `{{"chatgptcodex","gpt-5.6-sol"},{"anthropic","claude-opus-5"},{"openai","gpt-5.5"}}` | フォールバックモデル優先順位。各要素は `{provider, model}` または `{provider, model, url}`。`"lmstudio"` プロバイダーでローカル LLM も、`"zai"` プロバイダーで z.ai（GLM シリーズ）の課金 API も、`"kimi"` プロバイダーで Kimi（Moonshot AI）の課金 API も指定可能 |
| `$ClaudePrivateModel` | `{}` | 秘密データ処理用のローカルモデル指定 |
| `$ClaudeLMStudioIntegrations` | `{}` | LM Studio 使用時に有効にする MCP サーバー ID のリスト（例: `{"mcp/exa"}`）。mcp.json に登録済みのサーバーを指定すると、LM Studio がサーバー側で tool-call を自動実行する |
| `$ClaudeTestModel` | `$ClaudeModel と同じ` | `ClaudeCheckSeparation` 等のテスト用モデル名。未設定の場合はロード時に `$ClaudeModel` と同じ値に初期化される |
| `$ClaudeImageModels` | `{{"openai","gpt-image-1"},{"openai","dall-e-3"}}` | 画像生成モデルのリスト |
| `$ClaudeTTSModels` | `{{"openai","tts-1-hd"},{"openai","tts-1"}}` | 音声生成モデルのリスト |
| `$ClaudeDocModel` | `{"claudecode", "claude-sonnet-4-6"}` | ドキュメント生成・更新時に使用するモデル。`""` で `$ClaudeModel` と同じモデルを使用。未カスタマイズ時は最新 Sonnet に自動更新される |
| `$ClaudeDocRetryDelay` | `60` | ドキュメント生成のリトライ待機秒数 |
| `$ClaudeDocMaxRetries` | `3` | ドキュメント生成の最大リトライ回数 |
| `$ClaudeDocMaxChunkChars` | `60000` | プロンプト中ソースの最大文字数 |
| `$ClaudeDocUpdateStaleSeconds` | `1800` | ドキュメント更新チェーンの多重起動ガード解放待機秒数。異常終了したチェーンがこの秒数後に自動解放される |
| `$ClaudeDocUpdateExternal` | 条件付き有効 | 条件を満たす場合にドキュメント更新パイプライン全体を外部 wolframscript ワーカープロセスへ退避して実行させる制御変数。複数のドキュメント更新を並走させた際のメインカーネル飽和によるフリーズを防止する |
| `$ClaudeEvalMaxDepth` | `5` | ClaudeEval が再帰的に ClaudeEval/ContinueEval を生成する際の最大深度。0 で再帰禁止 |
| `$ClaudeEvalAutoLLMMinLength` | `500` | `"Auto"` モードで LLM planner を起動する最小文字数。タスク文字列がこの文字数未満かつ改行数が `$ClaudeEvalAutoLLMMinNewlines` 未満の場合、LLM planner をスキップして即座に Single 実行される |
| `$ClaudeEvalAutoLLMMinNewlines` | `3` | `"Auto"` モードで LLM planner を起動する最小改行数。改行数がこれ以上か、文字数が `$ClaudeEvalAutoLLMMinLength` 以上のとき LLM planner が起動する |
| `$ClaudeEvalNaturalDispatch` | `True` | 自然言語ディスパッチの有効フラグ。タスク文字列が定型パターンにマッチしたら LLM を経由せず SourceVault の高レベル API を直接呼ぶ。`False` で全タスクを従来の LLM 経路に流す |
| `$ClaudeEvalNaturalVerbose` | `False` | `True` で自然言語ディスパッチのマッチ・実行サマリを表示する |
| `$ClaudeCLIHarnessMode` | `"Direct"` | Claude CLI ハーネス（`.claude/`）の生成方式。`"Direct"` は作業中の `.claude/` をそのままコピー、`"Generated"` は正規ディレクティブリポジトリから `.claude/` を生成するオプトインモード |
| `$ClaudePackageKeywordMap` | `<\|\|>` | パッケージ API 自動注入用のキーワードマップ |
| `$ClaudePackageAuxKeywordMap` | `<\|\|>` | 補助ドキュメント（`api_<aux>.md`）単位の注入条件を登録する Association。形式: `<|pkg -> <|aux -> {キーワード...}|>|>`。未登録の補助ドキュメントは常に注入される |
| `$ClaudePaletteServiceControls` | `{}` | パレットのプライバシー直下に表示する起動/停止トグルの登録レジストリ（package-neutral。外部パッケージが `ClaudeRegisterPaletteServiceControl` で登録） |
| `$ClaudeCLIMCPServers` | `<\|\|>` | ヘッドレス Claude CLI 実行（`ClaudeQueryBg` 等）に組み込む MCP サーバーのレジストリ（package-neutral。外部パッケージが `ClaudeRegisterCLIMCPServer` で登録） |
| `$LLMGraphMaxConcurrency` | カテゴリ別設定 | LLMGraph のカテゴリ別並列実行数（`"cli"`・`"cli-vision"` 等） |
| `$UseClaudeRuntime` | `False` | `True` で ClaudeRuntime パッケージ経由の実行を有効化。claudecode 単独ロード時はデフォルトの `False`(従来動作)。ClaudeRuntime をロードすると自動的に `True` が設定される |
| `$ChatgptCodexExe` | `Automatic` | ChatGPT Codex CLI 実行ファイルのパス。`Automatic` は PATH から解決 |
| `$ChatgptCodexModel` | `Automatic` | Codex のモデル名。`Automatic` は config.toml の model キーを省略し Codex CLI 既定モデルを使用。具体的なモデル名は SourceVault のモデルレジストリから選択する。パレットで "Automatic" を選択すると自動的に `Automatic` に変換される |
| `$ChatgptWorkingDirectory` | `Automatic` | Codex 実行のベース作業ディレクトリ。`Automatic` は `$TemporaryDirectory` 配下の `claudecode-chatgpt-codex` を使用 |
| `$ChatgptCodexApprovalPolicy` | `"never"` | Codex の承認ポリシー。`"never"` は非対話で実行 |
| `$ClaudeEvalPromptRouterDispatch` | `Automatic` | PromptRouter ブリッジの制御。`Automatic`: PromptRouter を試行し `NotDispatched` なら自然言語ルーターへ、`False`: 常に自然言語ルーターのみ（SourceVault ロード時のみ有効） |
| `$ClaudeEvalPromptRouterPreemptsNatural` | `True` | `True`: PromptRouter が自然言語ルーターより先に走る、`False`: 自然言語ルーターを先に試し未マッチのときのみ PromptRouter を試す |

### 主な機能

**クエリ・コード生成**
- `ClaudeQuery[prompt]` — Claude に問い合わせ、テキスト応答を返す(同期)。`ClaudeQuery[{text, Image[...], File[path], ...}]` でマルチモーダル入力も可能。リッチレスポンスモードにより、安全なコード(プロット・計算等)は自動評価される
- `ClaudeQuerySync[prompt]` — Claude に問い合わせ、応答文字列を同期的に返す軽量版。セッション履歴やノートブック書き込みは行わない
- `ClaudeQueryBg[prompt]` — FrontEnd 操作・ScheduledTask 生成なしで同期問い合わせする軽量版。`{text, Image[...], File[path], ...}` のリスト形式によるマルチモーダル入力に対応。SocketListen ハンドラや ScheduledTask コールバック等の非同期コンテキストから安全に呼び出せる。LM Studio プロバイダでもマルチモーダル入力が可能（2026-07-29）
- `ClaudeMath[task]` — Mathematica コード生成に特化したクエリ
- `ClaudeEval[task]` — コードを非同期生成し、ノートブックに挿入・自動実行。`Fallback`・`WebFetch`・`Model`・`AutoPrivate`・`RepeatInterval` オプションで柔軟に制御。「Auto」実行モードでは `$ClaudeEvalAutoLLMMinLength`/`$ClaudeEvalAutoLLMMinNewlines` のしきい値により LLM planner の起動要否が自動判定される。`$ClaudeEvalNaturalDispatch` が有効な場合、定型パターンにマッチするタスクは LLM を経由せず SourceVault の高レベル API に直接ディスパッチされる（`$ClaudeEvalNaturalVerbose` でマッチ・実行サマリを表示可能）。SourceVault ロード時は Order 2 ディスパッチの PromptRouter ブリッジで登録済みルートに照合され、適合する場合は LLM 呼び出しなしに直接評価される。ClaudeOrchestrator ロード時は呼び出しがジョブキューに追加されて即座に返り、カーネルをブロックしない非同期実行モードに切り替わる。禁止パターン（`NBAutoEvalProhibitedPatterns`）に該当するコードの自動実行を自動ブロック
- `ContinueEval[instruction]` — 直前の ClaudeEval の続きを実行。エラー修正に便利
- `ClaudeSpec[task]` — ノートブック内容からプログラムの仕様書を生成
- `ClaudeExtractCode[response]` / `ClaudeExtractAllCode[response]` — 応答からコードブロックを抽出

**AI 画像・音声生成**
- `ClaudeImageGenerate[prompt]` — OpenAI Images API で画像を生成し Image オブジェクトで返す。`gpt-image-1` / `dall-e-3` 対応
- `ClaudeSpeech[text]` — OpenAI TTS API で音声を生成し Audio オブジェクトで返す。`tts-1` / `tts-1-hd` 対応

**タスク状態監視**
- `ClaudeStatus[]` — 実行中の全 Claude タスクのリアルタイム状態を表示。各タスクの経過時間、現在の状態（思考中/テキスト生成中/ツール実行中）、生成済みテキスト断片数、思考断片数、ツール使用数を表示
- `ClaudeAbort[]` — 実行中の全タスクを強制停止

**セッション管理**
- `CreateClaudeSession["name"]` — 名前付きセッションの作成（履歴の継承・独立が選択可能）
- `ClaudeRestoreSession["name"]` — 保存済みセッションの復元
- `ClaudeListSessions[]` — 全セッション一覧
- `ClaudeDeleteSession["name"]` — セッション削除
- `ClaudeDeleteSession["name", "All"]` — セッションとその全履歴を削除（不要な履歴を完全に除去してストレージを解放）
- `ClaudeShowHistory[]` — 会話履歴の表示
- `ClaudeCompactHistory[]` — 履歴の手動コンパクション
- `ClaudeHistorySize[]` — 履歴サイズ診断（Entries・ByteCount・KiloBytes・Status を返す。200KB超でコンパクション推奨、500KB超で危険）
- `ClaudeSessionStatus[]` — セッション状態の確認

**アタッチメント**
- `ClaudeAttach[path]` — セッションに参考資料を添付（PDF、.wl 等）。ファイルを `$packageDirectory/claude_attachments` にコピーし、パスを直接 Claude に見せないファイアウォール機構を実現。`Keywords` オプションでキーワード連動注入、`Title` でタイトル指定、`Refetch -> True` でキャッシュを無視して再取得
- `ClaudeDetach[path]` — 添付を解除
- `ClaudeAttachments[]` — アタッチメント一覧

**機密データ管理**
- `Confidential[expr]` — 式を評価し、そのセルを機密マーク（プロンプトから自動除外）
- `NonConfidential[expr]` — 機密依存でも明示的に公開扱い
- `MarkConfidential[]` / `UnmarkConfidential[]` — セルの機密マーク操作
- `ScanConfidentialCells[]` — 機密変数参照セルの自動検出・マーキング

**プライバシー対応モデルルーティング**
- `AutoPrivate -> True` — 秘密変数を含むタスクを `$ClaudePrivateModel` で指定したローカルモデルへ自動ルーティング
- `PrivacySpec -> <|"AccessLevel" -> n|>` — アクセスレベルの明示指定
- `Model -> {"provider", "model", "url"}` — 特定モデルへの直接ルーティング

**デバッグ・レビュー**
- `ClaudeDebug[codeOrFile, errorMsg]` — デバッグ支援（非同期）
- `ClaudeReview[codeOrFile]` — コードレビュー（非同期、長大ファイルは自動チャンク分割）

**パッケージ管理**
- `ClaudeUpdatePackage[name, prompt]` — .wl パッケージを Claude 支援で更新（差分ベースバックアップ付き・排他ロック・検証テスト自動生成・実行）。LLM レスポンスを「連続した行のかたまり（セグメント）」単位でマージするため、マージ精度が大幅に向上しています。完全修飾定義（`パッケージ名\`関数名`・`パッケージ名\`Private\`内部関数名` 形式）も正しく認識されます。`TargetFunctions` オプションで更新対象関数を限定可能。`UpdateApiMd -> True` で api.md の自動更新も実行
- `ContinueUpdate[]` / `ContinueUpdate[instruction]` — 直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を継続。引数なしで呼び出すと「エラーを修正してください」で自動継続。`ContinueUpdate["pkgName", "instruction"]` でパッケージ名を明示して継続することも可能
- `ClaudeRestorePackage[name]` — 直前のバックアップから復元
- `ClaudeBackupDataset[name]` — バックアップ履歴の表示・復元・削除（ローカル最新版スナップショット付き）
- `ClaudeUpdatePackageHistory[]` — パッケージ更新履歴の確認
- `ClaudeMigrateBackupHistory[name]` — 生バックアップを差分形式に一括変換（`DryRun -> True` で見積もり可能）
- `ClaudeConvertToPaclet[name]` — .wl パッケージを Paclet 形式に変換
- `ClaudeCreatePackage[name, prompt]` — 新規パッケージの作成
- `ClaudePrepareCommit[name]` — パッケージの GitHub コミット準備。`Owner`・`Repository`・`Branch`・`BaseBranch` オプションでリポジトリ情報を指定。`DryRun -> True` で実行計画のみ確認

**ドキュメント生成**
- `ClaudeCreateDocumentation["name"]` — パッケージの文書一式を自動生成。`Disclaimer`・`License`・`Acknowledgments` 等のオプションで README に免責事項・ライセンス情報・謝辞を付加可能。`References -> {URL, ...}` で参考文献リスト、`Demos -> {URL, ...}` でデモリンクを追加可能。リミット到達時は自動停止し、再実行で未生成分のみ続行。`$ClaudeDocModel` で生成専用モデルを指定可能
- `ClaudeUpdateDocumentation["name", "指示"]` — 既存ドキュメントの更新。ノートブックのコンテキストも参照可能。オプション設定は `doc_options.json` に永続化。`TargetFiles` オプションで更新対象を `api`・`setup`・`user_manual`・`example`・`README` の5種類に限定でき（拡張子 `.md` は省略可能）。`Baseline` オプションで差分の基準を `"LastDocUpdate"`（直近の更新バックアップ）または `"Github"`（GitHub コミット版）から選択可能。多重起動防止ガードにより同一パッケージへの同時更新を防止。更新失敗は「システム的失敗（fail-fast）」と「品質ゲート失敗（当該ファイルのみスキップ）」に分類され、1 ファイルの失敗が全体を巻き添えにしない。品質ゲート失敗時はまず自動リトライが1回行われ（RETRY NOTICE 付きプロンプトで再送）、失敗が続く場合のみ当該ファイルをスキップ。品質ゲート失敗のリトライ・スキップ経路でチェーンが分岐（fork）しないよう、各ステップに一意のシリアルトークンを発行する二重発火ガードも機能。既存ファイル上書き時のサイズ退行ガード（新内容が既存の40%未満に縮小した場合は書き込み拒否）も機能。`docs/docs/` ネスト重複ドキュメントを自動検出し更新対象から除外。`docs/examples/` 配下の使用例ドキュメントは既定（Automatic）モードでの自動更新対象から除外(`TargetFiles` で明示指定すれば更新可能)。20 ファイル以上の一括更新時は並列投入とリアルタイム進捗表示が行われ、中断後もサイクル再開（resumption）機能により効率的に継続可能。チェーンが異常終了した場合は `$ClaudeDocUpdateStaleSeconds` 秒後に自動解放。条件を満たす場合はパイプライン全体を外部 wolframscript ワーカープロセスへ退避して実行（`$ClaudeDocUpdateExternal`）し、複数更新の並走によるメインカーネル飽和フリーズを防止。補助 API ドキュメント（`api_<aux>.md`）の再生成要否はコンテンツハッシュ比較で判定され、mtime のずれのみによる不要な再生成を防止

**ディレクティブ管理**
- `ClaudeAddDirective[target, description]` — CLAUDE.md やスキルファイルにディレクティブを追加。`Scope -> "Local"` でプロジェクト固有のディレクティブも追加可能
- `ClaudeRestoreDirective[target]` — 直前のバックアップを復元
- `ClaudeUpdateDirective[]` — ソースコードと Claude Directives の整合性をチェックし、不整合を自動修正する
- `ClaudeUpdateDirective[text]` — テキストの内容を Claude で解釈し、CLAUDE.md / rules / skills の適切なファイルに反映する。ノートブックのコンテキストも参照可能
- `ClaudeListDirectives[]` — 全ディレクティブ一覧
- `ClaudeDirectiveBackupDataset[]` — ディレクティブ更新履歴を Review/Pull/Delete ボタン付き Grid で表示（ローカル最新版スナップショット付き）
- `ClaudeSyncDirectives[dir]` — 外部ディレクトリから Claude Directives へファイルを同期
- `ClaudeInitProject[]` — NotebookDirectory 内に `.claude-project/` を作成してプロジェクト固有のディレクティブを初期化（CLAUDE.local.md / rules/ / skills/ が生成され、メインのディレクティブと自動マージされる）
- `ClaudePromoteProjectDirectives[]` — プロジェクト固有ディレクティブをグローバルに昇格（`DryRun -> True` でプレビュー可能）

**ディレクティブ投影レイヤー（ClaudeDirectives・claudecode_directives ロード時）**
- 正規ディレクティブ・リポジトリ（`.claude/CLAUDE.md` / `rules/` / `skills/`）を読み込み、モデル能力・ロール・タスクに応じて投影モード（Full / Summary / Index / Lazy）と適用スキル・ルールを動的選択
- `$ClaudeModelCapabilities` によるモデル能力テーブル管理（provider 別の課金有無・コンテキスト長・クラス）
- タスクヒントに基づく rule/skill 選別（frontmatter のキーワード・パスとの一致度でスコアリング）と、常時注入対象を定義する `$ClaudeAlwaysOnRules`
- 単一の正規リポジトリから Claude CLI 用（`.claude/`）と Codex CLI 用（`AGENTS.md` / `.agents/`）のハーネスを生成・実体化（生成方式は `$ClaudeCLIHarnessMode` で `"Direct"` / `"Generated"` を選択）
- リポジトリのインベントリ・Manifest・ContentHash 算出による整合性管理

**Web 検索・取得**
- `ClaudeWebSearch[query]` — Web 検索を実行し結果をテキストで返す
- `ClaudeWebFetch[url]` — URL の内容を取得・要約

**[実験的] LLMGraph — LLM 適用グラフ**
- `NotebookLLMGraph[nb]` — ノートブックの LLMGraph 全体を取得（キャッシュ優先）
- `NotebookLLMGraphBuild[nb]` — セッション履歴からグラフを強制再構築
- `NotebookLLMGraphNodes[nb]` — 全ノードの Association を取得
- `NotebookLLMGraphPlot[nb]` — DAG 可視化（`"LayeredDigraphEmbedding"` レイアウト、L2 情報付きラベル・エラーノード赤縁）
- `NotebookLLMGraphValidate[nb]` — 5 項目の整合性検証（ノード数一致・エッジ整合・DAG 性・ID 一意・サイズ）
- `NotebookLLMGraphFetchResponse[nb, nodeID]` — 外部キャッシュからフルレスポンス・コードを取得
- `NotebookLLMGraphSubSteps[nb, nodeID]` — ClaudeUpdatePackage 内部ステップ履歴を Dataset で取得
- `NotebookLLMGraphSummary[nb]` — 全ノードの Status / L2 統計を Dataset で表示
- `NotebookLLMGraphErrors[nb]` — L2 エラーのある L1 ノード一覧
- `NotebookLLMGraphFetchL2[nb, nodeID]` — L2 グラフ（コードブロック単位）の取得
- `NotebookLLMGraphPlotL2[nb, nodeID]` — L2 グラフの可視化
- `NotebookLLMGraphUpdateL2Status[nb, l1ID, l2ID, status, msg]` — L2 ステータスの手動更新
- `NotebookLLMGraphInvalidateDownstream[nb, nodeID]` — 下流ノードのみを無効化（ノード自体は再実行しない）
- `NotebookLLMGraphRerun[nb, nodeID]` — L1 ノードの再実行（下流自動無効化）
- `NotebookLLMGraphExtractThread[nb, nodeID]` — 祖先チェーンを Thread オブジェクトとして抽出
- `NotebookLLMGraphApplyThread[thread, newTarget]` — Thread を別ファイルに適用（`DryRun -> True` で実行計画確認）
- `LLMGraphDAGCreate` / `LLMGraphExecute` / `LLMGraphExecuteStatus` / `LLMGraphExecuteCancel` / `LLMGraphDAGRebuild` 系 — DAG ジョブの作成・実行・ステータス取得・キャンセル・再構築を行う低レベル API

**[実験的] ClaudeProcessFile — プライバシー分割ファイル処理**
- `ClaudeProcessFile[prompt, srcPath, dstPath]` — .nb ファイルのセルをプライバシーレベルで分割し、クラウド LLM とプライベート LLM で並列処理してマージ。非同期実行（stateKey を返す）

**分離検証**
- `ClaudeCheckSeparation[target]` — NBAccess の分離原則への違反箇所を検出（静的パターン走査 + LLM 判定の二段階検査）
- `ClaudeFixSeparation[target]` — 分離違反を修正

**パレット**
- `ShowClaudePalette[]` — 操作用パレットの表示。ClaudeEval・ContinueEval・セッション管理・パッケージ更新など主要な操作をボタンひとつで実行できる。コードを入力せずにノートブックから直接 Claude を操作可能
- `ClaudeRegisterPaletteServiceControl[spec]` / `ClaudeUnregisterPaletteServiceControl[id]` — パレットのプライバシー直下に**外部パッケージがサービスの起動/停止トグルを登録**するための package-neutral な窓口（`$ClaudePackageKeywordMap` と同じ流儀で claudecode は登録側に非依存）。ラベル・色・状態判定・起動/停止コールバックは登録側が供給し、ラベルは稼働状態に追従する。例: SourceVault が MCP サーバの起動/停止トグルを登録

**ユーティリティ**
- `ClaudeCommand["/command"]` — Claude Code CLI コマンドの直接実行
- `ClaudeQueryShowContext[]` — 次回送信されるノートブックコンテキストの確認（デバッグ用）
- `ClaudeShowAccessConfig[]` — ファイルアクセス設定の確認（デバッグ用）
- `ClaudeRegisterCLIMCPServer[spec]` — ヘッドレス Claude CLI 実行（`ClaudeQueryBg` 等）に組み込む MCP サーバーを登録する package-neutral な窓口（`$ClaudeCLIMCPServers` で管理。例: SourceVault の MCP サーバー連携が利用）

### 後方互換性について

claudecode は [ClaudeRuntime](https://github.com/transreal/ClaudeRuntime)、[ClaudeOrchestrator](https://github.com/transreal/ClaudeOrchestrator)、[ClaudeTestKit](https://github.com/transreal/ClaudeTestKit)、および [SourceVault](https://github.com/transreal/SourceVault) の導入にあたり、**既存のワークフローへの影響がゼロになるよう設計**されています。

| 機能 | 従来の動作(各パッケージ未ロード) | SourceVault ロード時 | ClaudeOrchestrator ロード時 | ClaudeRuntime ロード時(`$UseClaudeRuntime = True` 自動設定) |
|------|----------------------------------|---------------------|----------------------------|---------------------------------------------------|
| `ClaudeEval["..."]` | CLI 経由で直接実行 | Order 2 ディスパッチに PromptRouter ブリッジが介挿され、登録済みルートに適合するプロンプトは LLM 呼び出しなしで直接評価。マッチしない場合（`NotDispatched`）は従来パスにフォールスルー | 非同期実行モードに切替(呼び出しがジョブキューに追加されて即座に返り、カーネルをブロックしない。ジョブキュー・レート制限管理が透過的に処理される) | Runtime 経由でルーティングして実行 |
| `ClaudeQuery["..."]` | CLI 経由で直接実行 | 変更なし | 変更なし | 変更なし(ClaudeQuery は常に CLI 経由) |
| `ContinueEval[...]` | セッション履歴を参照して継続 | 変更なし | 変更なし | 変更なし |
| `ClaudeUpdatePackage[...]` | 直接パッケージ更新 | 変更なし | 変更なし | 変更なし |
| 危険な操作の自動実行 | 禁止パターンでブロック | 変更なし | 変更なし | さらに `NeedsApproval` フローを介挿 |

claudecode を単独でロードした場合は `$UseClaudeRuntime = False`(デフォルト)のままで、ClaudeRuntime パッケージがインストールされていなくても claudecode の全機能をそのまま利用できます。SourceVault・ClaudeOrchestrator・ClaudeTestKit についても同様に、インストールされていない環境での動作に一切影響しません（claudecode 本体は SourceVault に対するハードな依存を持ちません）。

```mathematica
(* デフォルト: 各パッケージなしで従来どおり動作 *)
ClaudeEval["タスクの説明"]   (* 従来どおり CLI 経由 *)

(* SourceVault をロードすると ClaudeEval の Order 2 ディスパッチに PromptRouter ブリッジが介挿される *)
<< SourceVault`
ClaudeEval["登録済みルートに該当する定型タスク"]
(* → 適合ルートがあれば LLM 呼び出しなしで直接評価 *)
ClaudeEval["未登録の自由形式タスク"]
(* → NotDispatched となり従来どおり CLI 経由で LLM を呼び出す *)

(* ClaudeOrchestrator をロードすると ClaudeEval が非同期モードに切り替わる *)
<< ClaudeOrchestrator`
ClaudeEval["タスクの説明"]   (* ジョブキューに追加されて即座に返る。カーネルをブロックしない *)

(* ClaudeRuntime をロードすると $UseClaudeRuntime = True が自動設定される *)
<< ClaudeRuntime`
ClaudeEval["タスクの説明"]   (* Runtime 経由でルーティング *)

(* どうしても従来モードに戻したい場合は明示的に False を設定 *)
$UseClaudeRuntime = False
ClaudeEval["タスクの説明"]   (* 再び CLI 経由 *)
```

### パレットの使い方

`ShowClaudePalette[]` を実行すると、以下のような操作パレットが表示されます。

![パレット画面](img_20260323_185321_1.png)

パレットは複数のセクションに分かれています。

#### 機密セル セクション

| ボタン | 機能 |
|--------|------|
| **△ 機密マーク** | 選択中のセルを機密セルとしてマーク（プロンプトから自動除外） |
| **⊗ 機密解除** | 機密マークを解除 |
| **▷ スキャン** | ノートブック全体をスキャンして機密変数参照セルを自動マーク（`ScanConfidentialCells[]`） |

#### サービス起動/停止トグル（拡張ポイント）

機密セルセクションの直下に、**外部パッケージが登録したサービスの起動/停止トグル**が表示されます（例: SourceVault が MCP サーバーのトグルを登録）。登録が 1 つもなければ何も表示されません。登録 API: `ClaudeRegisterPaletteServiceControl[spec]` / `ClaudeUnregisterPaletteServiceControl[id]`（`$ClaudePaletteServiceControls` で管理）。

#### Claude セクション

| ボタン | 機能 |
|--------|------|
| **▷ ClaudeQuery** | コンテキストをもとに `ClaudeQuery` を実行（同期テキスト応答） |
| **► ClaudeEval** | コンテキストをもとに `ClaudeEval` を実行（非同期コード生成・実行） |
| **▷ 選択→Query** | 選択中のセル内容で `ClaudeQuery` を実行 |
| **▷ 選択→Eval** | 選択中のセル内容で `ClaudeEval` を実行 |
| **◆ 仕様生成** | ノートブックコンテキストから `ClaudeSpec` を実行して仕様書を生成 |
| **■ 実行停止** | 実行中の全タスクを停止（`ClaudeAbort[]`） |

#### 設定セクション

パレット下部でモデル・エフォート・課金 API の設定をノートブックごとに保存できます（TaggingRules に永続化）。

| 設定項目 | 選択肢 | 説明 |
|----------|--------|------|
| **モデル** | Opus / Sonnet / Default | 使用モデルを切り替え |
| **エフォート** | Low / Medium / High / Max | Think トリガー強度（Low: 思考なし、Max: ultrathink） |
| **課金API** | 禁止 / 許可 | `Fallback -> True/False` を制御 |
| **P:** | provider 循環切替 | クリックのたびに登録済み provider（claudecode / chatgptcodex / anthropic / openai / zai / kimi / lmstudio 等）の順序で切り替え |
| **M:** | モデル候補リスト | provider 別のモデルを選択。ChatGPTCodex 選択時は SourceVault のモデルレジストリから取得され、claudecode/anthropic 選択時も既定候補が SourceVault 経由で動的解決される（解決できない場合は `claude-opus-5` にフォールバック） |

#### セッション セクション

| ボタン | 機能 |
|--------|------|
| **■ 履歴表示** | `ClaudeShowHistory[]` で会話履歴を表示 |
| **□ セッション一覧** | `ClaudeListSessions[]` で全セッション一覧を表示 |

パレット最下部には機密セル数と機密依存セル数がリアルタイムで表示されます（例: `機密: 0, 依存: 0`）。パレットの表示言語は `$Language` 設定に連動します。

### LM Studio 対応

ローカルで動作する LLM サーバー（LM Studio 等）を、フォールバックモデルとして使用するだけでなく、`$ClaudeModel` に直接指定して主モデルとして使用できます。API キーは不要で、OpenAI 互換の Chat Completions API エンドポイントに接続します。2026-07-29 よりマルチモーダル入力（テキスト + 画像の混在）にも対応しており、`ClaudeQueryBg` 等から画像を含むクエリを直接 LM Studio へ送信できます。

```mathematica
(* フォールバックモデルにローカルモデルを追加 *)
$ClaudeFallbackModels = {
  {"anthropic", "claude-opus-5"},
  {"openai", "gpt-5.5"},
  {"lmstudio", "openai/gpt-oss-20b", "http://192.168.2.106:1234"}
};

(* Fallback で自動的に使われる *)
ClaudeEval["階乗を計算して", Fallback -> True]

(* Model オプションで直接指定 *)
ClaudeEval["1から10までのフィボナッチ数を計算して",
  Model -> {"lmstudio", "openai/gpt-oss-20b", "http://192.168.2.106:1234"}]

(* $ClaudeModel に直接設定してすべての呼び出しを LM Studio で実行 *)
$ClaudePrivateModel = {"lmstudio", "qwen/qwen3.6-27b", "http://127.0.0.1:1234"}
$ClaudeModel = $ClaudePrivateModel
```

`$ClaudeFallbackModels` の各エントリは `{provider, modelName}` または `{provider, modelName, url}` の形式です。`"lmstudio"` プロバイダーを指定すると、指定 URL（デフォルト `http://localhost:1234`）の `/v1/chat/completions` エンドポイントに接続します。

#### MCP ツールの有効化

`$ClaudeLMStudioIntegrations` を設定すると、LM Studio が `mcp.json` に登録済みの MCP サーバーと連携し、Web 検索等の MCP ツールを LM Studio 経由で呼び出せます。LM Studio がサーバー側で tool-call を自動実行するため、クラウド LLM を使用せずにツール統合を実現できます。

```mathematica
(* LM Studio 経由で MCP ツールを有効化 *)
$ClaudeLMStudioIntegrations = {"mcp/exa"}

(* 設定後は通常どおり ClaudeEval/ClaudeQuery を呼び出すだけ *)
ClaudeQuery["最新の Mathematica のリリースノートを調べて"]
```

MCP サーバー ID は `mcp.json` に登録済みの ID を文字列リストで指定します。`$ClaudeModel` を LM Studio に設定した状態で `$ClaudeLMStudioIntegrations` を有効にすることで、プライバシーを重視しながら外部ツール呼び出し機能を統合した運用が可能です。

#### LM Studio 認証設定（Require Authentication）

LM Studio の **Server Settings** で **Require Authentication** を有効にした場合は、API キーを `SystemCredential` に登録します。キー名は `"lmstudio-<URL>"` の形式です。

```mathematica
(* LM Studio の API キーを登録（キー名は接続先 URL を含む形式） *)
SystemCredential["lmstudio-http://127.0.0.1:1234"] = "your-lm-studio-api-key";
```

登録後は `ClaudeEval` 等の呼び出し時に自動取得されます。Require Authentication が Off の場合は登録不要です（ダミーキーにフォールバック）。

### ChatGPT Codex 対応

Claude Code CLI に加えて、OpenAI の **ChatGPT Codex CLI** を provider として使用できます。`$ClaudeModel` を `{"chatgptcodex", Automatic}` に設定すると、`ClaudeEval` / `ClaudeQuery` が Codex CLI 経由で実行されます。

```bash
# ChatGPT Codex CLI のインストール（事前準備）
npm install -g @openai/codex
codex --version
codex login
```

```mathematica
(* provider を ChatGPT Codex に切り替え（モデルは CLI 既定） *)
$ClaudeModel = {"chatgptcodex", Automatic}

(* Codex 経由でコード生成 *)
ClaudeEval["1 から 100 までの和を求めてください"]

(* provider を Claude Code に戻す *)
$ClaudeModel = {"claudecode", "claude-opus-5"}
```

Codex provider は Claude CLI と同じ非同期実行経路で動作します。Codex 実行ごとに一時的な作業ディレクトリと `CODEX_HOME` を作成し、`codex login` の認証情報（`auth.json`）を自動的に引き継いだうえで、`codex exec` をバックグラウンドで起動して結果をポーリングします。実行中にカーネルがブロックされることはありません。

Claude Code CLI も Codex CLI もサブスクリプション契約に基づく CLI であり、メーター制 API（`anthropic` / `openai` provider）とは課金体系が異なります。claudecode の課金 API ガードは `chatgptcodex` provider を無課金扱いとするため、課金 API を許可しない設定でも Codex 経由のコード生成が利用できます。

#### ChatGPT Codex のモデル管理

ChatGPT Codex のモデル名は **SourceVault** が一元管理します。具体的な LLM モデル ID をパッケージソースに直書きせず、SourceVault のモデルレジストリから解決する設計です。

```mathematica
(* SourceVault のモデルレジストリを更新（codex debug models を実行） *)
<< SourceVault`
SourceVaultRefreshModelRegistry["Providers" -> {"chatgptcodex"}]

(* Codex の選択可能なモデル一覧 *)
SourceVaultListModels["chatgptcodex"]

(* 用途に応じたモデル解決 *)
ClaudeResolveModel["chatgptcodex", "code-heavy"]
```

`SourceVaultRefreshModelRegistry` は `codex debug models` を実行してモデルカタログを取得し、コンパイル済みレジストリに登録します。パレットで provider を `ChatGPTCodex` に切り替えると、`M:` ボタンのモデル候補はこの SourceVault レジストリから取得されます。`$ChatgptCodexModel` に具体的なモデル名を設定することでも指定できます。

### SourceVault による PromptRouter ブリッジ

オプションの独立パッケージ [SourceVault](https://github.com/transreal/SourceVault) をロードすると、`ClaudeEval` の **Order 2 ディスパッチ**として **PromptRouter** による提案ベースの実行経路が組み込まれます。SourceVault がユーザーの自然言語タスクから `PromptRouteProposal` を構築し、claudecode 側は提案された `ProposedExpression`（`HoldComplete`）の頭部を ReadOnly 許可リストと照合した上でのみ評価します。適合するルートが存在する場合には LLM 呼び出しを経由せず、許可リスト上の式を直接評価して結果を返します。

```mathematica
(* SourceVault をロードして PromptRouter ブリッジを有効化 *)
<< SourceVault`

(* 登録済みルートに合致するプロンプト → LLM 呼び出しなしで直接評価 *)
ClaudeEval["今日の日付を表示して"]

(* 未登録の自由形式プロンプト → NotDispatched となり従来通り Claude Code CLI 経由で処理 *)
ClaudeEval["この複雑なデータを分析して傾向を可視化して"]
```

**PromptRouter ブリッジの特徴**:

- **高速・低コスト**: 適合ルートが見つかれば LLM トークン消費ゼロで結果を返せます。頻出の定型タスクに特に有効です。
- **再現性・監査可能性**: ルートは事前に定義された評価式（`ProposedExpression`）を実行するため、出力が決定論的になります。
- **安全性**: 評価される式は `HoldComplete` で保持され、その頭部が ReadOnly 許可リストに含まれる場合のみ評価されます。副作用のある式は弾かれます。
- **フォールスルー**: SourceVault がアクティブでない・許可リスト外の頭部を提案した・エラー/拒否を返した場合は `NotDispatched` となり、従来の自然言語ルーターに何の影響もなくフォールバックします。
- **疎結合**: claudecode 本体は SourceVault に対するハードな依存を持ちません（rule 11）。SourceVault が未インストールの環境では PromptRouter ブリッジ自体が存在せず、従来の自然言語ディスパッチのみが動作します。

SourceVault をロードすると、仕様書の審査から実装ワークフロー化までを支援する API 群（`ClaudeSpecStatus`・`ClaudeSpecVersions`・`ClaudeSpecText`・`ClaudeOpenSourceVaultURI`・`CreateImplementationWorkflow`・`LaunchImplementationWorkflow`・`ClaudeImplStatus`・`ClaudeImplMonitor`）も利用可能になります。`CreateImplementationWorkflow` が完了すると、生成されたワークフローの起動関数がスラッグ・表示名をキーワードとして PromptRouter に自動登録されるため、以降は `ClaudeEval` でスラッグ名を呼び出すだけでワークフローを起動できます。

### 多言語対応

`$Language` の値に基づいてプロンプト内の言語指定が動的に生成されます。`$Language` が `"Japanese"` に設定されている場合は日本語で応答するよう Claude に指示し、それ以外の値（`"English"` 等）の場合は英語に切り替わります。

```mathematica
(* 日本語モード（デフォルト） *)
$Language = "Japanese"
ClaudeQuery["フィボナッチ数列の実装方法を教えてください"]
(* → 日本語で説明が返る *)

(* 英語モードに切り替え *)
$Language = "English"
ClaudeQuery["Explain how to implement Fibonacci sequence"]
(* → English explanation is returned *)
```

### TargetFiles オプションの許可リスト

`ClaudeUpdateDocumentation` の `TargetFiles` オプションには、更新対象として指定できるファイルに許可リストが設けられています。

| 指定値（拡張子省略可） | 実際のファイル |
|----------------------|--------------|
| `"api"` または `"api.md"` | `api.md` |
| `"setup"` または `"setup.md"` | `setup.md` |
| `"user_manual"` または `"user_manual.md"` | `user_manual.md` |
| `"example"` または `"example.md"` | `examples/example.md` |
| `"README"` または `"README.md"` | `README.md` |

拡張子 `.md` は省略可能で自動補完されます。許可リスト外の値を指定するとエラーになります。

既定（`Automatic`）モードでの一括更新では、`docs/examples/` 配下の使用例ドキュメント（`*.md`）は自動更新対象から除外されます。使用例ドキュメントの多くは手作業で作成された内容であり、毎回自動再生成すると数が多い場合に更新が終わらなくなるための設計です。これらを更新したい場合は、`TargetFiles` オプションで明示的に指定してください。

```mathematica
(* 拡張子なしで指定可能 *)
ClaudeUpdateDocumentation["claudecode", "新機能を追記して",
  TargetFiles -> {"api", "user_manual", "README"}]

(* 拡張子ありでも同様に動作 *)
ClaudeUpdateDocumentation["claudecode", "セットアップ手順を更新して",
  TargetFiles -> {"setup.md"}]

(* docs/examples 配下の使用例ドキュメントを明示的に更新 *)
ClaudeUpdateDocumentation["claudecode", "使用例を追加して",
  TargetFiles -> {"example"}]
```

### Baseline オプション — 差分検出の基準

`ClaudeUpdateDocumentation` の `Baseline` オプションでは、ソースコードの差分を検出する基準を選択できます。

| 指定値 | 基準 | 加味される内容 |
|--------|------|----------------|
| `"LastDocUpdate"`（デフォルト） | 直近のドキュメント更新バックアップ | 前回ドキュメント生成時からのコード差分 |
| `"Github"` | GitHub コミット版 | コミット版以降のコード差分に加えて `_info/design` 配下の新規設計ドキュメント |

```mathematica
(* GitHub コミット版を基準に、design の新規内容も加味して更新 *)
ClaudeUpdateDocumentation["claudecode", "最新版に追従して",
  Baseline -> "Github"]
```

`"Github"` を指定すると、コミット版から現在までに加えられたコード変更だけでなく、`_info/design` フォルダに追加された設計ドキュメントの内容も読み込んで、新しくなった部分の記述を充実させた更新が行われます。

### ドキュメント一覧

| ファイル | 内容 |
|---------|------|
| `api.md` | API リファレンス（全関数・変数・オプションの詳細仕様） |
| `setup.md` | セットアップガイド（インストール手順・トラブルシューティング） |
| `user_manual.md` | ユーザーマニュアル（機能別の詳細な使い方） |
| `example.md` | 使用例集（代表的なユースケースとコード例） |

各ドキュメントの詳細はリンク先を参照してください。README は概要のみを提供しており、すべての機能・オプションの網羅的な解説は `user_manual.md` および `api.md` に記載されています。

## 使用例・デモ

### 動画

- [claudecode デモ動画 — Mathematica ノートブックから Claude Code を操作する様子を紹介（YouTube）](https://www.youtube.com/watch?v=_Lc-XtBPkl8)

### ノートブック

- [ClaudeQuery デモノートブック — 実際の使用例とサンプルコード（Wolfram Cloud）](https://www.wolframcloud.com/obj/imai/Published/claudecode-examples.nb)

---

## 謝辞

本ソフトウェアの一部は、サタケ技術振興財団、2025年度研究課題「認知能力低下を支援するプレゼンテーションツールの開発」の助成を受けて作成された。

---

## 免責事項

本ソフトウェアは "as is"（現状有姿）で提供されており、明示・黙示を問わずいかなる保証もありません。
本ソフトウェアの使用または使用不能から生じるいかなる損害についても責任を負いません。
今後の動作保証のための更新が行われるとは限りません。
本ソフトウェアとドキュメントはほぼすべてが生成AIによって生成されたものです。
Windows 11上での実行を想定しており、MacOS, LinuxのMathematicaでの動作検証は一切していません(生成AIの処理で対応可能と想定されます)。

---

## ライセンス

```
MIT License

Copyright (c) 2026 Katsunobu Imai

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

----------------------------------------------------------------

Additional Notices

AI-Generated Code Notice

This software includes code generated with the assistance of AI tools (e.g., Claude Code).

The author has not fully verified the originality of all generated code.Some parts of the implementation may be derived from patterns learned by the AI model.

Intellectual Property Disclaimer

No warranty is provided that this software does not include code or patterns that may be subject to third-party intellectual property rights.

Users are responsible for verifying legal compliance when using, modifying, or redistributing this software.

Liability Disclaimer

In addition to the MIT License, the author assumes no responsibility for any legal issues arising from the use of this software, including but not limited to intellectual property claims.

Research Funding

This work was partially supported by the Satake Technology Promotion Foundation (2025).
```
