# セットアップガイド

claudecode パッケージのインストールと初期設定の手順を説明します。

## システム要件

### 必須環境
- **Wolfram Language 12.0** 以上（Mathematica または Wolfram Engine）
- **Windows 10/11** （現在 Windows 専用実装）
- **Node.js 16.0** 以上
- **Claude Code CLI** （Anthropic 提供）

### オプション環境
- **ChatGPT Codex CLI** （OpenAI 提供）― provider に `chatgptcodex` を指定して Codex 経由でコード生成・クエリを実行する場合に必要です。Claude Code CLI のみを使う場合は不要です。

### ハードウェア要件
- **メモリ**: 最低 8GB RAM（推奨 16GB 以上）
- **ストレージ**: 空き容量 1GB 以上
- **ネットワーク**: インターネット接続（Claude API アクセス用）

## 事前準備

### 1. Claude Code CLI のインストール

Claude Code CLI を公式サイトからダウンロードしてインストールしてください：

```bash
# Claude Code CLI の確認
claude --version
```

### 1b. ChatGPT Codex CLI のインストール（オプション）

provider に `chatgptcodex` を指定して Codex 経由でコード生成・クエリを実行する場合は、ChatGPT Codex CLI をインストールしてください。Claude Code CLI のみを使う場合はこの手順は不要です。

Codex CLI は npm パッケージとして提供されています：

```bash
# ChatGPT Codex CLI のインストール
npm install -g @openai/codex

# ChatGPT Codex CLI の確認
codex --version
```

インストール後、Codex CLI に OpenAI アカウントでログインしてください：

```bash
codex login
```

`codex login` で作成される認証情報（`auth.json`）は既定の `CODEX_HOME`（`~/.codex`）に保存されます。claudecode は Codex 実行ごとに一時的な `CODEX_HOME` を作成しますが、この認証情報を自動的に引き継ぐため、`codex login` を一度実行しておけば claudecode 経由の Codex 実行でも認証が通ります。

利用可能なモデル一覧は次のコマンドで確認できます：

```bash
# Codex が認識しているモデルカタログ（JSON）
codex debug models
```

このモデルカタログは SourceVault が一元管理します（後述の「ChatGPT Codex のモデル管理」を参照）。

### 2. Node.js のインストール

[Node.js 公式サイト](https://nodejs.org/) から最新の LTS バージョンをダウンロードしてインストールしてください。

```bash
# Node.js の確認
node --version
npm --version
```

### 3. Anthropic API キーの設定

Claude Code CLI に API キーを設定してください：

```bash
claude auth login
```

ChatGPT Codex CLI を provider として使う場合は、別途 `codex login`（前述）でログインしておきます。Claude Code CLI も Codex CLI も、いずれもサブスクリプション契約に基づく CLI であり、メーター制 API（`anthropic` / `openai` / `zai` provider）とは課金体系が異なります。claudecode の課金 API ガード（`課金API: 禁止` 設定）は `claudecode` provider と `chatgptcodex` provider を無課金扱いとするため、課金 API を許可しなくても Codex 経由のコード生成が利用できます。

## パッケージのインストール

### 1. 依存パッケージの配置

claudecode パッケージは以下の依存関係があります：

- **[NBAccess](https://github.com/transreal/NBAccess)** パッケージ（ノートブック操作用）
- **[github](https://github.com/transreal/github)** パッケージ（GitHub 連携用）

また、以下はオプションの依存パッケージです：

- **[cuda](https://github.com/transreal/cuda)** パッケージ（CUDA 関連タスク用）― CUDA を必要とするプロンプトを送信すると自動的に検出・ロードが試みられます。`cuda.wl` が `$packageDirectory` に存在しない場合は警告が表示されます。
- **[ClaudeRuntime](https://github.com/transreal/ClaudeRuntime)** パッケージ（永続ランタイム機能用）― `$UseClaudeRuntime = True` に設定した場合にのみ使用されます。未インストールでも従来の ClaudeEval/ClaudeQuery ワークフローは影響を受けません。
- **[ClaudeOrchestrator](https://github.com/transreal/ClaudeOrchestrator)** パッケージ（複数 Claude セッションのオーケストレーション用）― レート制限の自動検出・復帰やリトライタイミングの制御など、claudecode の上位レイヤーとして複数エージェントの並列管理・調整を行います。claudecode 本体の動作には影響しませんが、大規模な自動化タスクで活用できます。
- **[ClaudeTestKit](https://github.com/transreal/ClaudeTestKit)** パッケージ（自動テスト・回帰テスト用）― ClaudeRuntime を使ったコード生成の品質検証に利用します。通常の使用には不要です。

これらのパッケージを `$packageDirectory` に配置してください。

### 2. claudecode パッケージの配置

`claudecode.wl` ファイルを `$packageDirectory` に配置します：

```mathematica
(* パッケージディレクトリの確認 *)
$packageDirectory

(* 配置後の確認 *)
FileExistsQ[FileNameJoin[{$packageDirectory, "claudecode.wl"}]]
```

### 3. パッケージの読み込み

```mathematica
(* パッケージの読み込み *)
Get["claudecode.wl"]
```

初回読み込み時に node-pty が自動的にインストールされます。パッケージリロード時には旧バージョンの内部タスク（孤児タスクを含む全共有ポーリングタスク）が自動的に停止・除去されるため、安全に再読み込みできます。

ClaudeRuntime を使用する場合は、別途ロードしてください：

```mathematica
(* ClaudeRuntime の読み込み（オプション） *)
<< ClaudeRuntime`
```

## 初期設定

### 1. 基本設定の確認

```mathematica
(* 設定確認 *)
ClaudeShowAccessConfig[]

(* モデル設定（必要に応じて変更） *)
$ClaudeModel = {"claudecode", "claude-opus-4-8"}

(* タイムアウト設定 *)
$ClaudeTimeout = 1200
```

### 2. 作業ディレクトリの設定

```mathematica
(* 作業ディレクトリの設定（デフォルト: ~/Claude Working） *)
$ClaudeWorkingDirectory = FileNameJoin[{$HomeDirectory, "Claude Working"}]

(* アクセス可能ディレクトリの設定 *)
$ClaudeAccessibleDirs = {$packageDirectory, "C:\\Users\\...\作業フォルダ"}
```

### 3. パッケージキーワードマップの設定

パッケージごとのキーワード自動登録システムにより、プロンプトにキーワードが含まれると対応パッケージの api.md がコンテキストに自動注入されます：

```mathematica
(* パッケージキーワードマップの設定例 *)
$ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "切"}
$ClaudePackageKeywordMap["github"] = {"GitHub", "git", "リポジトリ"}

(* 設定確認 *)
$ClaudePackageKeywordMap
```

各パッケージは自身のロード時にキーワードを自動登録します。claudecode.wl 側はパッケージ非依存です。

### 4. ClaudeRuntime の設定（オプション）

ClaudeRuntime は永続的なランタイムコンテキストを保持し、複数ターンにわたる会話状態を管理する機能拡張パッケージです。**既存の `ClaudeEval`/`ClaudeQuery` ワークフローとの後方互換性は完全に確保されています**。ClaudeRuntime を使用しない場合、従来どおりの動作になります。

```mathematica
(* ClaudeRuntime を有効化する場合 *)
$UseClaudeRuntime = True

(* 有効化後、ClaudeEval は自動的に Runtime 経由でルーティングされる *)
ClaudeEval["タスクの説明"]

(* 最後に使用したランタイムの ID を確認 *)
$ClaudeLastRuntimeId

(* ランタイムの状態一覧を表示 *)
Dataset[KeyValueMap[
  Function[{id, rt}, <|
    "RuntimeId" -> id,
    "Status"    -> rt["Status"],
    "TurnCount" -> rt["TurnCount"],
    "Profile"   -> rt["Profile"],
    "LastFailure" -> Lookup[rt, "LastFailure", None]
  |>],
  ClaudeRuntime`Private`$iClaudeRuntimes
]]
```

`$UseClaudeRuntime = False`（デフォルト）の場合、ClaudeRuntime パッケージが存在しない環境でも claudecode の全機能を利用できます。

### 5. フォールバックモデルの設定（オプション）

Claude Code が利用できない場合のバックアップとして、他の LLM を設定できます：

```mathematica
(* フォールバックモデルの設定例 *)
$ClaudeFallbackModels = {
  {"chatgptcodex", "gpt-5.5"},
  {"anthropic", "claude-opus-4-8"},
  {"openai", "gpt-5.5"},
  {"zai", "glm-5.2"}
}
```

`chatgptcodex` はサブスクリプション CLI のため課金 API 禁止設定でも使用できます。`anthropic` / `openai` / `zai` はメーター制 API のため、課金 API を明示的に許可したノートブックでのみ動作します。

**利用可能な provider 一覧：**

| provider | 説明 | 課金 |
|---------|------|------|
| `claudecode` | Claude Code CLI（Anthropic サブスクリプション） | なし |
| `chatgptcodex` | ChatGPT Codex CLI（OpenAI サブスクリプション） | なし |
| `anthropic` | Anthropic API 直接接続 | あり |
| `openai` | OpenAI API | あり |
| `zai` | z.ai（GLM シリーズ）API | あり |
| `lmstudio` | ローカル LLM（LM Studio 経由） | なし |

`zai` は z.ai が提供する GLM シリーズ（`glm-5.2`, `glm-5.1`, `glm-5`, `glm-5-turbo`, `glm-4.7` など）への API アクセスです。OpenAI 互換 API 形式で動作します。

パレットの `P:` ボタンをクリックすると provider が順に切り替わります。切り替え順は `$iPaletteProviderOrder` で定義されており、現在の順序は `claudecode → chatgptcodex → anthropic → openai → zai → lmstudio` です。`zai` は `openai` の次、`lmstudio` の前に位置します。

### 6. ドキュメント生成設定

claudecode はパッケージのドキュメント一式（README.md / api.md / setup.md / user_manual.md）を LLM で生成・更新する機能を備えています。生成・更新に使うモデルやリトライ動作は以下のグローバル変数で制御できます：

```mathematica
(* ドキュメント生成用モデル *)
$ClaudeDocModel = "claude-sonnet-4-6"

(* リトライ設定 *)
$ClaudeDocMaxRetries = 3
$ClaudeDocRetryDelay = 60

(* チャンク分割の最大文字数 *)
$ClaudeDocMaxChunkChars = 60000

(* ドキュメント更新チェーンのスタイル上限（秒）
   この秒数を超えたチェーンは異常終了とみなして自動解放される *)
$ClaudeDocUpdateStaleSeconds = 1800
```

`$ClaudeDocUpdateStaleSeconds`（既定 1800 秒）は、`ClaudeUpdateDocumentation` の非同期更新チェーンが異常終了した場合に多重起動ガードを自動解放するまでの待機時間です。通常は変更不要ですが、長時間かかるドキュメント更新が多い場合は大きな値に設定してください。

`ClaudeUpdateDocumentation` は同一サイクル内での**再開（resumption）**に対応しています。API エラーや利用制限などで更新が途中で中断した場合、再実行すると成功済みのファイルは自動的にスキップされ、未完了分のみ処理が再開されます。サイクルが完全に完了すると進捗ファイルは自動的にクリアされます（次回の実行ではソース変更に基づく新しいサイクルとして開始されます）。

20 ファイル以上のパッケージでは、README 以外のドキュメントファイルが `$LLMGraphMaxConcurrency["cli"]` で制御される並列度で同時更新されます（既定 2）。並列更新中はウィンドウステータスバーに「完了 N/M • K 並列実行中 • 経過 Ts」がライブ表示されます。API エラー・利用制限・プロバイダ内部エラー・空応答などのシステム的失敗が複数のファイルで発生した場合は、チェーン全体が中断され `⚠ Doc update aborted (N failed)` と表示されます（N は失敗ファイル数）。一方、切り詰め・サイズ退行・タイトル不整合などの品質失敗は当該ファイルのみをスキップして次のファイルへ進むため、チェーン全体は中断されません（2026-07-09 改訂。詳細は後述の「切り詰め検出（品質ゲート3）」を参照）。

ドキュメントの新規作成は `ClaudeCreateDocumentation`、既存ドキュメントの更新は `ClaudeUpdateDocumentation` で行います（後述の「高度な設定 > ドキュメントの自動生成・更新」を参照）。

### 7. LLMGraph DAG 並列度の設定

LLMGraph DAG 実行における各カテゴリの最大並列度をグローバルに設定できます：

```mathematica
(* カテゴリ別の最大並列度（グローバルデフォルト） *)
$LLMGraphMaxConcurrency["cli"]        = 2  (* CLI テキスト呼び出し *)
$LLMGraphMaxConcurrency["cli-vision"] = 1  (* CLI 画像付き呼び出し *)
```

並列度の解決優先順位は以下のとおりです：

1. `taskDescriptor["maxConcurrency"][abstractCat]`（ジョブ固有のオーバーライド）
2. `$LLMGraphMaxConcurrency[abstractCat]`（グローバルデフォルト）
3. `1`（フォールバック）

### 8. UI フォントの設定（オプション）

`$ClaudeStandardFont` は `ClaudeEval` が生成する出力コード（Grid / Column / Style / Button 等）で統一的に使用される標準フォント名です。プロンプトに埋め込まれ、生成コードの FontFamily 指定を強制します。デフォルトは `"Yu Gothic UI"` です。

```mathematica
(* UI フォントの確認・変更 *)
$ClaudeStandardFont          (* 現在の設定を確認 *)

$ClaudeStandardFont = "Meiryo UI"   (* 変更例 *)
```

日本語環境で生成コードのフォントが崩れる場合にこの変数を設定してください。パッケージロード後いつでも変更でき、次回以降の `ClaudeEval` 生成コードに反映されます。

## 動作確認

### 1. 基本動作の確認

```mathematica
(* シンプルなクエリテスト *)
ClaudeQuery["こんにちは。数学の問題を解いてもらえますか？"]

(* セッション状態の確認 *)
ClaudeSessionStatus[]
```

### 2. コード生成機能のテスト

```mathematica
(* 非同期コード生成のテスト *)
ClaudeEval["フィボナッチ数列の最初の10項を計算する関数を作成してください"]
```

### 3. パッケージ操作のテスト

```mathematica
(* テスト用パッケージの作成 *)
ClaudeCreatePackage["testpkg", "簡単な挨拶関数を含むパッケージを作成"]

(* パッケージ履歴の確認 *)
ClaudeUpdatePackageHistory[]
```

### 4. 新機能のテスト

```mathematica
(* パッケージ更新とapi.md自動更新のテスト *)
ClaudeUpdatePackage["testpkg", "新機能を追加", "UpdateApiMd" -> True]

(* 結果を踏まえてバグ修正を継続（履歴から自動取得） *)
ContinueUpdate["エラーを修正してください"]

(* キーワード連携のテスト（maildbキーワードを含むクエリ） *)
ClaudeQuery["メールを処理するプログラムを作りたい"]
```

`ContinueUpdate[]` は引数なしで呼び出すと、直前の `ClaudeUpdatePackage` の履歴を自動的に参照してバグ修正を継続します。直前の履歴が見つからない場合は、パッケージ名を明示的に指定してください：

```mathematica
(* パッケージ名を明示して継続 *)
ContinueUpdate["testpkg", "追加の修正指示"]
```

### 5. ドキュメント生成・更新のテスト

```mathematica
(* ドキュメント一式の新規作成 *)
ClaudeCreateDocumentation["testpkg"]

(* 直近の _documentupdate バックアップを基準にドキュメントを更新（既定） *)
ClaudeUpdateDocumentation["testpkg"]

(* GithubRepositories のコミット版を基準に更新 *)
ClaudeUpdateDocumentation["testpkg", Baseline -> "Github"]
```

`ClaudeUpdateDocumentation` の `Baseline` オプションについては後述の「高度な設定 > ドキュメントの自動生成・更新」を参照してください。

### 6. ClaudeRuntime の動作確認（オプション）

ClaudeRuntime をインストールした場合は、以下で動作を確認できます：

```mathematica
(* ClaudeRuntime を読み込んで有効化 *)
<< ClaudeRuntime`
$UseClaudeRuntime = True

(* 通常の ClaudeEval がランタイム経由で動作することを確認 *)
ClaudeEval["斜方投射のグラフを描いてください"]

(* ランタイム一覧を確認 *)
Keys[ClaudeRuntime`Private`$iClaudeRuntimes]

(* $UseClaudeRuntime を False に戻すと従来モードに復帰 *)
$UseClaudeRuntime = False
```

### 7. ChatGPT Codex provider の動作確認（オプション）

ChatGPT Codex CLI をインストールした場合は、provider を `chatgptcodex` に切り替えて動作を確認できます：

```mathematica
(* provider を Codex に切り替え（モデルは CLI 既定を使用） *)
$ClaudeModel = {"chatgptcodex", Automatic}

(* Codex 経由でコード生成 *)
ClaudeEval["1 から 100 までの和を求めてください"]

(* provider を Claude Code に戻す *)
$ClaudeModel = {"claudecode", "claude-opus-4-8"}
```

`$ClaudeModel` を `{"chatgptcodex", Automatic}` に設定すると、`ClaudeEval` / `ClaudeQuery` が Codex CLI 経由で実行されます。`Automatic` は Codex CLI の既定モデルを使用します。具体的なモデルを指定する場合は `$ChatgptCodexModel` を設定するか、パレットの `M:` ボタンで選択します（「ChatGPT Codex のモデル管理」を参照）。

Codex provider は専用の非同期 bridge（バックグラウンドでの CLI 起動と結果ポーリング）で動作するため、実行中にカーネルがブロックされることはありません。

### 8. 仕様実装ワークフローの動作確認（オプション）

`CreateImplementationWorkflow` を使うと、承認済み設計仕様を SourceVault 管理下の codified ワークフローパッケージとして自動実装できます：

```mathematica
(* 承認済み仕様テキストまたは sv:// URI から実装ワークフローを生成 *)
jobId = CreateImplementationWorkflow["myWorkflow",
  "ユーザー入力を受け取り、Wolfram Alpha で検索して結果を返す関数を実装する"]

(* 実行状態を確認（フェーズ・モデル・ラウンド数を Dataset で表示） *)
ClaudeImplStatus[]

(* ライブ監視パネルをノートブックセルに表示 *)
ClaudeImplMonitor[]

(* 生成されたワークフローを起動 *)
LaunchImplementationWorkflow["myWorkflow", {}]
```

`CreateImplementationWorkflow` は `$ClaudeModel`（実装担当）と `$ClaudeAdvisaryModel`（検証担当）が協調して仕様を実装し、実装完了後にワークフローの起動関数をセッションおよび promptrouter に自動登録します。進捗はウィンドウステータスバーにリアルタイム表示されます（実行モデル・フェーズ・ラウンド数）。

実装担当は、プロジェクト内 API や外部 API を実物のドキュメント／コードで検証できない場合、推測でコードを生成せずに実行を中断する fail-closed 方針で動作します。中断時は `ClaudeImplStatus[]` の結果が `FinalStatus -> "Blocked"` となり、ノートブックには次のような警告セルが書き込まれます：

```
⚠ Implementation STOPPED (fail-closed): a required API could not be verified against ground truth, so nothing was generated on a guessed API.
```

この場合は `BlockReason` に示された未検証の API を確認し、依存パッケージの api.md を用意する、または `Notes` オプションで API の詳細を補足したうえで再実行してください。

```mathematica
(* 仕様バージョン管理の確認 *)
ClaudeSpecStatus[]                        (* 現在のノートブックプロジェクトの仕様状況 *)
ClaudeSpecVersions[]                      (* 記録された仕様・レビューバージョン一覧 *)
ClaudeSpecText["sv://snapshot/..."]       (* 特定バージョンの仕様テキストを取得 *)
ClaudeOpenSourceVaultURI["sv://..."]      (* sv:// URI の内容を新しいノートブックで開く *)
```

## 後方互換性について

claudecode は ClaudeRuntime および ClaudeTestKit の導入にあたり、**既存のワークフローへの影響がゼロになるよう設計**されています。

| 機能 | 従来の動作 | ClaudeRuntime 有効時 |
|------|-----------|----------------------|
| `ClaudeEval["..."]` | CLI 経由で実行 | Runtime 経由で実行 |
| `ClaudeQuery["..."]` | CLI 経由で実行 | 変更なし（ClaudeQuery は常に CLI 経由） |
| `ClaudeUpdatePackage` | 従来どおり | `ClaudeUpdatePackageViaRuntime` にルーティング可 |
| セッション履歴 | ノートブック TaggingRules に保存 | 変更なし |

- `$UseClaudeRuntime` のデフォルト値は `False` であり、ClaudeRuntime パッケージが存在しない環境でも claudecode は正常に動作します。
- ClaudeTestKit は開発・テスト用の独立したパッケージであり、claudecode 本体の動作には一切影響しません。
- ClaudeOrchestrator は claudecode の上位レイヤーとして動作する独立したパッケージです。claudecode 本体の動作には影響しません。

また、`ClaudeUpdateDocumentation` の `Baseline` オプションの既定値は `"LastDocUpdate"` であり、従来どおり直近の `_documentupdate` バックアップを差分基準とします。`Baseline -> "Github"` を明示しない限り、既存のドキュメント更新ワークフローの挙動は変わりません。

## 設定のカスタマイズ

### プライバシー設定

機密データを扱う場合の設定：

```mathematica
(* プライベートモデルの設定 *)
$ClaudePrivateModel = {"lmstudio", "local-model", "http://127.0.0.1:1234"}

(* 自動プライベートモード *)
ClaudeEval["機密データの処理", AutoPrivate -> True]
```

### パフォーマンス設定

```mathematica
(* 履歴コンパクションの設定 *)
ClaudeHistorySize[]
ClaudeCompactHistory[]

(* 再帰実行の深度制限 *)
$ClaudeEvalMaxDepth = 5
```

### Web 検索設定

```mathematica
(* Web検索設定（Claude Code CLI組み込み、無料） *)
ClaudeEval["最新の技術情報を調べてください", WebSearch -> True]

(* WebFetch設定（API経由、課金あり、Fallback->True必須） *)
ClaudeEval["このURLの内容を要約して", WebFetch -> True, Fallback -> True]
```

### ChatGPT Codex のモデル管理

ChatGPT Codex のモデル名は SourceVault が一元管理します。具体的な LLM モデル ID を `claudecode.wl` 等のソースに直書きせず、SourceVault のモデルレジストリから解決する設計です。

SourceVault をインストールしている場合、まず一度モデルレジストリを更新します：

```mathematica
(* SourceVault の読み込み *)
Needs["SourceVault`"]

(* Codex のモデルカタログを取得してレジストリを更新 *)
SourceVaultRefreshModelRegistry["Providers" -> {"chatgptcodex"}]
```

`SourceVaultRefreshModelRegistry` は `codex debug models` を実行してモデルカタログを取得し、コンパイル済みレジストリに登録します。登録後は次のように確認できます：

```mathematica
(* Codex の選択可能なモデル一覧 *)
SourceVaultListModels["chatgptcodex"]

(* 用途（intent）に応じたモデル解決 *)
ClaudeResolveModel["chatgptcodex", "code-heavy"]
```

claudecode のパレットで provider を `ChatGPTCodex` に切り替えると、`M:` ボタンのモデル候補はこの SourceVault レジストリから取得されます。SourceVault をロードしていない場合や、レジストリ更新前は、最小限のフォールバック候補（`Automatic`）のみが表示されます。

`Automatic` を選ぶと Codex CLI の既定モデルが使われます（`config.toml` の `model` キーを省略）。具体的なモデルを選ぶと、そのモデル名が Codex 実行時の設定に反映されます。

パレットの `M:` ボタンで表示される Claude 系モデル（claudecode / anthropic provider）の候補バージョンは、SourceVault のモデルレジストリ（`ClaudeResolveModel`）から動的に解決されます。SourceVault がロードされている場合、パレットを開くたびに最新の登録モデルが候補として反映されます。

#### アドバイザリーモデルの設定（仕様レビュー・実装ワークフロー用）

`$ClaudeAdvisaryModel` は、仕様レビュー＆改訂オーケストレーターワークフローや `CreateImplementationWorkflow` における Codex（アドバイザリー）役のモデルを指定します。`$ClaudeModel` と同じ `{provider, model}` タプル形式で指定します。

```mathematica
(* 既定値: {"chatgptcodex", "Automatic"} （Automatic = Codex CLI 既定モデル） *)
$ClaudeAdvisaryModel = {"chatgptcodex", "Automatic"}

(* 具体的なモデルを指定する場合 *)
$ClaudeAdvisaryModel = {"chatgptcodex", "gpt-5.5"}
```

`$ClaudeAdvisaryModel` を明示的に設定しない場合、ワークフロー実行時に `{"chatgptcodex", "Automatic"}` が自動的に使用されます。なお、ベア文字列 `"chatgptcodex"` も後方互換のため引き続き受け付けます。

## トラブルシューティング

### よくある問題と解決方法

#### 1. node-pty のインストールエラー

```mathematica
(* 手動でのnode-ptyインストール *)
RunProcess[{"cmd", "/c", "npm install node-pty"}, 
  ProcessDirectory -> FileNameJoin[{$packageDirectory, "claudecode_runtime"}]]
```

#### 2. Claude Code CLI の接続エラー

- API キーの確認：`claude auth status`
- ネットワーク接続の確認
- ファイアウォール設定の確認

#### 3. パッケージ読み込みエラー

```mathematica
(* 依存パッケージの確認 *)
FileExistsQ[FileNameJoin[{$packageDirectory, "NBAccess.wl"}]]
FileExistsQ[FileNameJoin[{$packageDirectory, "github.wl"}]]

(* キャッシュのクリア *)
ClearAll["ClaudeCode`*"]
Get["claudecode.wl"]
```

#### 4. メモリ不足エラー

```mathematica
(* 履歴のコンパクション *)
ClaudeCompactHistory[]

(* 履歴サイズの確認 *)
ClaudeHistorySize[]
```

#### 5. パッケージキーワードマップの問題

```mathematica
(* キーワードマップの確認 *)
$ClaudePackageKeywordMap

(* キーワードマップのリセット *)
$ClaudePackageKeywordMap = <||>

(* パッケージの再読み込みでキーワード再登録 *)
Get["maildb.wl"]
Get["github.wl"]
```

#### 6. CUDA 拡張が読み込めない

CUDA 関連のタスクを実行する際に以下の警告が表示される場合：

```
⚠ CUDA extension (cuda.wl) is required but could not be loaded.
```

`cuda.wl` を `$packageDirectory` に配置してください。CUDA が不要なタスクであれば、この警告は無視して構いません。

```mathematica
(* CUDA パッケージの存在確認 *)
FileExistsQ[FileNameJoin[{$packageDirectory, "cuda.wl"}]]
```

#### 7. タスクが停止しない・フリーズする

内部タスクは共有ポーリングタスク機構により一元管理されています。パッケージリロード時には旧タスク（孤児タスクを含む全共有ポーリングタスク）が自動的に停止・除去されます。

タスクが応答しない場合は `ClaudeAbort[]` で強制停止できます。`ClaudeAbort[]` を実行すると確認ダイアログが表示され、停止対象（Claude CLI 非同期タスク・共有ポーリング・フォールバック API・Orchestrator の wolframscript ドライバ）が一覧表示されます。なお、並列カーネルは `ClaudeAbort[]` では停止されません。

```mathematica
(* 全タスクの強制停止（確認ダイアログが表示される） *)
ClaudeAbort[]

(* パッケージ再読み込みによるクリーンアップ（孤児タスクも含めて全停止） *)
Get["claudecode.wl"]
```

**API 過負荷（HTTP 529）とレート制限の区別について**

Claude API サーバが一時的な過負荷状態（HTTP 529）になった場合、以前は「利用制限」と誤表示されることがありましたが、現在は正しく「一時的なサーバ過負荷」として区別して表示されます。HTTP 529 は利用制限ではなく一時的な現象であり、しばらく待つと自動的に回復します。

#### 8. ClaudeRuntime が見つからない・ロードできない

`$UseClaudeRuntime = True` に設定した状態で ClaudeRuntime が見つからない場合、警告が表示されますが claudecode 本体は引き続き動作します：

```mathematica
(* ClaudeRuntime パッケージの存在確認 *)
FileExistsQ[FileNameJoin[{$packageDirectory, "ClaudeRuntime", "Kernel", "init.wl"}]]

(* ClaudeRuntime を使用しない場合は False に設定 *)
$UseClaudeRuntime = False
```

#### 9. ChatGPT Codex provider のエラー

provider を `chatgptcodex` に設定して `ClaudeEval` がカスケード失敗する場合、いくつかの原因が考えられます。

**Codex CLI が見つからない**：Codex CLI がインストールされ、PATH が通っているか確認してください。

```bash
codex --version
```

PATH に追加されていない場合は `$ChatgptCodexExe` に Codex CLI のフルパスを指定できます：

```mathematica
$ChatgptCodexExe = "C:\\Users\\<user>\\.local\\bin\\codex.exe"
```

**認証エラー（401 Unauthorized）**：Codex CLI にログインしていない場合、Codex 実行が認証失敗で終了します。一度ターミナルで `codex login` を実行してください。

```bash
codex login
```

**無効なモデル名での失敗**：存在しないモデル名を指定すると Codex CLI が起動時に失敗します。SourceVault のモデルレジストリを更新し、`SourceVaultListModels["chatgptcodex"]` で有効なモデル名を確認してください。モデル名が不確かな場合は `$ChatgptCodexModel = Automatic`（CLI 既定モデル）にすると確実に動作します。

```mathematica
(* 確実に動作する既定モデルに戻す *)
$ChatgptCodexModel = Automatic
```

**問題切り分け**：Codex 実行ごとの一時ディレクトリ（既定では `$TemporaryDirectory` 配下の `claudecode-chatgpt-codex`）に、`codex_stderr_*.log` というセッションログが残ります。Codex CLI が出力したエラー内容はこのログで確認できます。

#### 10. ドキュメント更新で「前回バックアップが見つからない」

`ClaudeUpdateDocumentation`（既定の `Baseline -> "LastDocUpdate"`）は、直近の `_documentupdate` バックアップとの差分を基準にドキュメントを更新します。過去の `_documentupdate` バックアップが存在しない場合は基準が取れず、エラーが表示されます。

```mathematica
(* まずドキュメント一式を新規作成してから更新する *)
ClaudeCreateDocumentation["pkg"]
```

GithubRepositories のコミット版を基準にしたい場合は、バックアップの有無に関係なく `Baseline -> "Github"` を指定できます（`GithubRepositories/<パッケージ名>` にコミット版ソースが配置されている必要があります）。

```mathematica
ClaudeUpdateDocumentation["pkg", Baseline -> "Github"]
```

`GithubRepositories` ディレクトリが存在しない場合は、`Baseline -> "LastDocUpdate"` を使用してください。

#### 11. ドキュメント更新チェーンが「進行中」と表示される

`ClaudeUpdateDocumentation` は同じパッケージへの多重起動を防ぐガードを備えています。既に更新チェーンが実行中の場合は以下のような警告が表示され、二重起動は行われません：

```
⚠ <パッケージ名> のドキュメント更新が既に進行中です。完了を待ってから再実行してください。
```

チェーンが異常終了してガードが解放されない場合は、`$ClaudeDocUpdateStaleSeconds`（既定 1800 秒）経過後に自動解放されます。すぐに解放したい場合は以下を実行してください：

```mathematica
(* ドキュメント更新チェーンのガードを手動解放 *)
$iDocUpdateActive = KeyDrop[$iDocUpdateActive, "pkg"]
```

待機時間を短縮する場合は `$ClaudeDocUpdateStaleSeconds` を小さな値に設定してください：

```mathematica
(* スタイル上限を短縮（例: 5分） *)
$ClaudeDocUpdateStaleSeconds = 300
```

**再開（resumption）について**：更新が API エラー等で途中中断した場合、再実行すると同一サイクル内であれば成功済みのファイルは自動的にスキップされます。「✅ All documents already updated in this cycle.」または「✅ Target documents already updated in this cycle.」と表示された場合は、当該サイクルの対象ファイルが既に全て処理済みであることを意味します。ソースコードを変更してから再実行すると新しいサイクルとして扱われます。

**複数ファイルの更新失敗によるチェーン中断**：並列更新中に API エラー・利用制限・プロバイダ内部エラー・空応答などのシステム的失敗が複数のファイルで発生した場合、チェーン全体が中断され以下のメッセージが表示されます：

```
⚠ Doc update aborted (N failed)
```

N は失敗したファイルの数を示します。この場合、`$ClaudeDocRetryDelay` 秒待ってから再実行すると、成功済みファイルはスキップされ、失敗分のみ再試行されます。切り詰め・サイズ退行・タイトル不整合などの品質失敗は個々のファイル単位でスキップされるのみでチェーン全体は中断されません（2026-07-09 改訂。詳細は「切り詰め検出（品質ゲート3）」を参照）。

#### 12. 仕様実装ワークフローが「fail-closed」で中断される

`CreateImplementationWorkflow` の実装ラウンドで、実装担当が必要な API（プロジェクト内 API・外部 API を問わず）を実物のドキュメント／コードで検証できなかった場合、推測でコードを生成せずに実行を中断します。この場合 `ClaudeImplStatus[]` の `FinalStatus` は `"Blocked"` となり、ノートブックには以下の警告セルが書き込まれます：

```
⚠ Implementation STOPPED (fail-closed): a required API could not be verified against ground truth, so nothing was generated on a guessed API.
```

`BlockReason` に未検証の API が示されます。依存パッケージの api.md を `$packageDirectory` に用意する、または `CreateImplementationWorkflow` の `Notes` オプションで API のシグネチャや使用例を補足したうえで再実行してください。

#### 13. LLM バックエンドが応答しない・利用不可と表示される

`ClaudeBackendAvailableQ` を使うと、LLM バックエンドの事前可用性チェック（preflight）を手動で実行できます。結果は 60 秒間キャッシュされます。

```mathematica
(* claudecode バックエンドの可用性確認 *)
ClaudeBackendAvailableQ[{"claudecode", Automatic}]

(* lmstudio バックエンドの可用性確認 *)
ClaudeBackendAvailableQ[{"lmstudio", "my-model", "http://localhost:1234"}]

(* キャッシュを無視して再取得 *)
ClaudeBackendAvailableQ[{"lmstudio", Automatic}, "Refresh" -> True]
```

返り値は `<|"Available" -> True|False, "Reason" -> "OK"|"NotRunning"|"ModelNotLoaded"|"RateLimited"|...|>` 形式の Association です。`"Reason"` が `"NotRunning"` の場合はサーバ未起動、`"ModelNotLoaded"` の場合はモデル未ロード、`"RateLimited"` の場合はレート制限中を示します。

`/api/v1` 系にしか対応していないサーバは state 情報が取得できないため、可用性チェックでブロックされません（既知の挙動）。

#### 14. docs/docs/ にネストした重複ドキュメントが検出される

`ClaudeUpdateDocumentation` / `ClaudeCreateDocumentation` は、`docsDir` 配下に `docs/docs/` のようにネストしたサブディレクトリ内の重複ドキュメントを自動検出し、更新対象から除外します。これは Dropbox 同期や git 操作の事故によって生じる root ドキュメントファイルの重複コピーであり、放置すると次回以降のドキュメント更新でも繰り返し検出され続けます。検出時は次のような警告が表示されます：

```
⚠️ docs/docs/ にネストした重複ドキュメントを検出した (N 件)。更新対象から除外します。削除を推奨: <path>
```

表示されたパスの重複ファイルを削除することを推奨します。この機能は設定不要で自動的に動作します（2026-07-08 修正：除外判定の比較対象はフィルタ前の全ファイル一覧から取得されるため、`docsDir` 自体が `docs` という名前であっても正しく判定されます）。

### デバッグ情報の取得

```mathematica
(* 詳細な状態情報 *)
ClaudeStatus[]
ClaudeSessionStatus[]

(* アクセス設定の確認 *)
ClaudeShowAccessConfig[]

(* パッケージ更新履歴の確認 *)
ClaudeUpdatePackageHistory[]

(* バックアップ履歴の確認 *)
ClaudeBackupDataset[]

(* SIEM 診断イベントの確認（直近 40 件） *)
ClaudeDiagEvents[]

(* 件数を指定して確認 *)
ClaudeDiagEvents[20]
```

`ClaudeDiagEvents[n]` は SIEM spool（diag-spool、マシンローカル）の直近 n 件を新しい順の Dataset で返します。SourceVault service による ingest 前でも、自マシンの運用イベント（SpawnFailed / ScheduleSubmitFailed 等）をリアルタイムで確認できます。

## 高度な設定

### ドキュメントの自動生成・更新

claudecode は、パッケージのドキュメント一式（README.md / api.md / setup.md / user_manual.md）を LLM で生成・更新する関数を備えています。

- **`ClaudeCreateDocumentation["pkg"]`** ― ドキュメント一式を新規作成します（既存内容を無視して新規生成）。
- **`ClaudeUpdateDocumentation["pkg"]`** ― 既存ドキュメントを、ソース差分に基づいて更新します。

```mathematica
(* ドキュメントの新規作成 *)
ClaudeCreateDocumentation["pkg"]

(* 既存ドキュメントの更新（差分ベース） *)
ClaudeUpdateDocumentation["pkg"]
```

`ClaudeUpdateDocumentation` は同じパッケージへの多重起動が禁止されています。既に更新チェーンが実行中の場合は警告が表示され、完了まで再実行は行われません。チェーンが異常終了して解放されなかった場合は `$ClaudeDocUpdateStaleSeconds`（既定 1800 秒）経過後に自動解放されます。

#### Baseline オプション（差分基準の切り替え）

`ClaudeUpdateDocumentation` の `Baseline` オプションで、ソース差分の基準を切り替えられます。

```mathematica
(* 既定: 直近の _documentupdate バックアップを基準にする *)
ClaudeUpdateDocumentation["pkg", Baseline -> "LastDocUpdate"]

(* GithubRepositories のコミット版を基準にする *)
ClaudeUpdateDocumentation["pkg", Baseline -> "Github"]
```

| `Baseline` の値 | 差分基準 | 用途 |
|------|---------|------|
| `"LastDocUpdate"`（既定） | 直近の `_documentupdate` バックアップ | 前回のドキュメント更新以降の変更を反映（従来動作） |
| `"Github"` | `GithubRepositories/<パッケージ名>` のコミット版ソース | リポジトリのコミット版を基準に、未コミットのソース変更をまとめて反映 |

`Baseline` には `"Github"` と `"LastDocUpdate"` 以外の値を渡しても、自動的に `"LastDocUpdate"` にフォールバックします。

#### `Baseline -> "Github"` での design 新規内容の加味

`Baseline -> "Github"` を指定すると、ドキュメント更新プロンプトには次の 2 つが渡されます：

1. **ソース差分** ― `GithubRepositories/<パッケージ名>` のコミット版ソースと現行ソースとの差分。
2. **design 新規内容** ― `_info` / design ファイルのうち、コミット版以降に追加された設計内容。

design 新規内容は **api.md 以外**（README.md / setup.md / user_manual.md を含む）に添付されます。これにより、ソース差分だけでは読み取れない設計意図や新機能の背景を補い、新しくなった部分の記述を充実させられます。ソース差分も design 新規内容も両方とも空の場合は、ドキュメントの更新は行われません。

`GithubRepositories` ディレクトリの場所は次のとおりです：

```mathematica
FileNameJoin[{$packageDirectory, "GithubRepositories", "pkg"}]
```

このディレクトリにコミット版のソースを配置しておくことで、`Baseline -> "Github"` による差分基準が利用可能になります。

#### ドキュメント更新の再開（resumption）機構

`ClaudeUpdateDocumentation` は同一サイクル内での**再開**をサポートしています。サイクルキーはソースコード内容・更新指示・対象ファイルセットから生成されます（ノートブックコンテキストは毎回変わるため除外されます）。

- 各ファイルの更新に成功すると進捗ファイルに記録されます。
- API エラーや利用制限などで中断した後に再実行すると、同一サイクル内なら成功済みファイルは自動的にスキップされ、失敗・未処理分のみ再試行されます。
- サイクルが全て完了すると進捗ファイルが自動的にクリアされます（次回はソース変更に基づく新しいサイクルとして開始されます）。

すでに全ファイルが更新済みの場合は以下のメッセージが表示されます：

```
✅ All documents already updated in this cycle.
```

特定のファイルのみが更新済みの場合は：

```
✅ Target documents already updated in this cycle.
```

#### 並列ドキュメント更新（20 ファイル以上）

20 ファイル以上のパッケージでは、README 以外のドキュメントを LLM へ並列投入します。並列度の上限は `$LLMGraphMaxConcurrency["cli"]` で制御されます（既定 2）。

並列更新の実行中はウィンドウステータスバーに「完了 N/M • K 並列実行中 • 経過 Ts」がライブ表示されます。更新が完了またはジョブが中断されると、ステータスバーの表示は自動的にクリアされます。

```mathematica
(* ドキュメント更新の並列度を変更する場合 *)
$LLMGraphMaxConcurrency["cli"] = 4
```

より高い並列度を設定するほど更新全体の所要時間が短縮されますが、API レート制限に達しやすくなります。環境に応じて適切な値を設定してください。

API エラー・利用制限・プロバイダ内部エラー・空応答などのシステム的失敗が複数のファイルで発生した場合、チェーン全体が以下のメッセージとともに中断されます：

```
⚠ Doc update aborted (N failed)
```

この場合は再実行すると成功済みファイルをスキップして失敗分のみ再試行されます。なお、切り詰め・サイズ退行・タイトル不整合などの品質失敗は個々のファイル単位でスキップされ、チェーン全体は中断されません（詳細は次項「切り詰め検出（品質ゲート3）」を参照）。

#### 切り詰め検出（品質ゲート3）

LLM レスポンスが切り詰められた（truncated）と判定された場合（例：未閉コードフェンス `` ``` `` が奇数個残っている、文章が途中の開き括弧で終わっているなど）、タイトル不整合やサイズ退行が検出された場合と同様に、そのファイルの更新は品質失敗として扱われます。

**失敗の分類（2026-07-09 改訂）**：

- **システム的失敗**（API エラー・利用制限・プロバイダ内部エラー・空応答）― 従来どおりチェーン全体を即中断します（fail-fast）。
- **品質失敗**（切り詰め・サイズ退行・タイトル不整合）― 当該ファイルのみをスキップして次のファイルの更新に進みます。チェーン全体は中断されません。

以前は品質失敗もチェーン全体を即中断していたため、持続的に品質失敗を起こす1ファイル（例：巨大化した setup.md）が残り全部の更新を永遠にブロックしてしまう事故がありました。この改訂により、そうした事故を根絶しています。

品質失敗で前回の再生成が未完了だった場合はまず同一ファイルの再生成が試行されます（このとき単一応答・ツール不使用・コードフェンスを正しく閉じることを強く指示するリトライ通知が付加されます）。再試行しても品質ゲートを通過しない場合は当該ファイルをスキップし、次のファイルへ進みます：

```
⚠ [i/N] <file> の生成が未完了です。再生成します。
⛔ [i/N] <file> をスキップします。ファイルは変更せず次のファイルへ進みます。
```

API エラーや利用制限によるチェーン中断：

```
⚠ <file> の更新を中断しました (API エラー/利用制限/内部エラー)。
```

いずれの場合も、同一サイクルの再実行で未処理・失敗分のファイルのみ再試行されます。

#### 更新提案の自動バージョン保存

`ClaudeUpdateDocumentation` による各ドキュメント更新提案を実行すると、新しい保存バージョンが自動的に作成され、続く更新ターン（auto-save turn）が開始されます。マルチステップのドキュメント更新ワークフローを実行した場合でも、各ステップの追記がまとめて 1 つのバージョンとして完全に保存されます。

#### 補助 api_*.md の鮮度判定（内容ハッシュ基準）

依存パッケージの補助ドキュメント（`api_<aux>.md` のような、モジュール単位の補助 api ファイル）を今回の更新対象に含めるかどうかの判定は、内容ハッシュを基準に行われます。

- 補助ソース（`<pkg>_<aux>.wl`）の内容ハッシュを、`docsDir` 内のサイドカーファイル（`.aux_source_hashes.json`）に記録・保持します。改行コード（CRLF/LF）だけの差異はハッシュ計算前に除去され、無視されます。
- 記録済みハッシュと現在のソース内容ハッシュが一致する場合、ファイルの更新日時（mtime）が変化していても再生成は行われません（内容が実際には変わっていないと判断されるため）。
- 記録済みハッシュが存在しない場合（初回など）は、従来どおり補助ソースと補助ドキュメントの mtime 比較にフォールバックします。この際、変更なしと判定されたタイミングで現在のハッシュを基準として記録し、以後の判定は内容ハッシュ基準に移行します。
- 補助ドキュメントファイルがまだ存在しない場合は新規作成が必要と判定され、対応する補助ソース（`<pkg>_<aux>.wl`）が見つからない場合は判定対象外として扱われます。

以前は補助ソースと補助ドキュメントの mtime を単純比較していましたが、mtime は Dropbox 同期・複数 PC 間での作業・git 操作などソースの内容変更とは無関係な理由でも変化するため、実際には変更されていない補助モジュールまで不要に再生成してしまうことがありました。この判定方式により、そうした無駄な再生成が抑制されます。設定は不要で、`ClaudeUpdateDocumentation` 実行時に自動的に動作します。

#### docs/docs/ 重複ドキュメントの自動除外

`docsDir` 配下に `docs/docs/` のようにネストしたサブディレクトリがあり、その中に root ドキュメント（README.md / api.md / setup.md / user_manual.md 等）と同名の重複ファイルが存在する場合、これらは Dropbox 同期や git 操作の事故で生じた重複コピーとみなされ、更新対象から自動的に除外されます。除外時には警告が表示され、削除が推奨されます（詳細は前述の「トラブルシューティング > 14. docs/docs/ にネストした重複ドキュメントが検出される」を参照）。この判定は設定不要で自動的に行われ、`docsDir` 自体が `docs` という名前のディレクトリである場合など、紛らわしいディレクトリ名のケースでも正しく重複と非重複を区別します（2026-07-08 修正）。

### CLI MCP サーバの登録（ClaudeRegisterCLIMCPServer）

`ClaudeRegisterCLIMCPServer` は、ヘッドレス claude CLI 実行（`ClaudeQueryBg` / `ClaudeQuery` の内部経路）に MCP サーバを接続登録する関数です。外部パッケージ（例: SourceVault MCP）が自身の MCP サーバを登録するために使用します。claudecode 本体はパッケージ非依存の設計を維持します。

```mathematica
(* MCP サーバを登録する *)
ClaudeRegisterCLIMCPServer["my-server", <|
  "ConfigFn"       -> Function[], (* サーバ稼働中: <|"Url"->..., "Headers"->...|>、停止中: None を返す *)
  "AllowedTools"   -> {"toolName1", "toolName2"},
  "PromptDirective" -> "MCP サーバ経由でデータを取得すること"
|>]

(* 登録済みサーバの一覧を確認 *)
$ClaudeCLIMCPServers
```

**`spec` キーの説明：**

| キー | 型 | 説明 |
|------|---|------|
| `"ConfigFn"` | `Function[]` | サーバ稼働時に `<|"Url"->url, ("Headers"-><|...|>)|>` を返し、停止時に `None` を返す関数。`/health` プローブ等を含み得る。 |
| `"AllowedTools"` | `{文字列...}` | `--allowedTools` フラグに `mcp__<id>__<tool>` 形式で追加するツール名リスト。`--print` モードでは対話的承認ができないため、事前に許可が必要。 |
| `"PromptDirective"` | `String` または `Function[]` | サーバ稼働中にクエリプロンプトへ注入する MCP 優先ポリシーテキスト。`Function[]` の場合は注入時に評価される。 |

同じ `id` で再登録すると既存のエントリが置き換えられます。登録済みの稼働中サーバの read-only ツールは claude CLI 実行時に自動的に許可されます。

```mathematica
(* サーバの登録解除は $ClaudeCLIMCPServers から直接削除 *)
$ClaudeCLIMCPServers = KeyDrop[$ClaudeCLIMCPServers, "my-server"]
```

`$ClaudeCLIMCPServers` は `<|id -> spec|>` 形式の Association で、登録済み MCP サーバのスナップショットを保持します。`ConfigFn` はサーバ稼働時のみ接続情報を返すため、停止中のサーバは自動的に CLI 実行から除外されます。

### LLM ティアルーティングとバックエンド管理

claudecode はタスクのクラスに応じて実行バックエンドを自動選択する LLM ティアルーティング機能を備えています。以下の関数でルーティング状態の確認や手動チェックが行えます。

#### ClaudeResolveLLMTier

`ClaudeResolveLLMTier[class]` はタスククラスに対応するバックエンドを `$ClaudeLLMTierTable` と `ClaudeBackendAvailableQ` による preflight の結果から決定します。

```mathematica
(* タスククラスに対応するバックエンドを解決 *)
ClaudeResolveLLMTier["code"]
(* 例: <|"Candidates" -> {{"claudecode", "opus"}, {"anthropic", "claude-opus-4-8"}}, "Rejected" -> {}|> *)

ClaudeResolveLLMTier["classify"]
(* ティア表の候補から preflight を通過したものが返る *)

ClaudeResolveLLMTier["general"]
(* "general" は Automatic（従来の provider fallback 連鎖）をそのまま使う *)
```

`"general"` クラスは従来の provider fallback 連鎖を使用します。未知のクラスは `"general"` に降格され、warn が emit されます。

#### ClaudeTaskClassAttributes

`ClaudeTaskClassAttributes[class]` はタスククラスの属性（エスカレーション許可・バリデーター要否など）を返します。

```mathematica
(* コード生成クラスの属性を確認 *)
ClaudeTaskClassAttributes["code"]
(* <|"AllowEscalation" -> False, "RequiresValidator" -> False, ...|> *)

(* 分類クラスの属性を確認 *)
ClaudeTaskClassAttributes["classify"]
(* <|"AllowEscalation" -> True, "RequiresValidator" -> True, ...|> *)

(* 未知クラスは "general" に降格 *)
ClaudeTaskClassAttributes["unknown-class"]
```

現在定義されているタスククラスは `"code"`、`"classify"`、`"general"` などです。`"code"` クラスはエスカレーション禁止・バリデーター不要、`"classify"` クラスはエスカレーション許可・バリデーター必須の設定になっています。

#### ClaudeBackendAvailableQ

`ClaudeBackendAvailableQ[{provider, model, url...}]` は LLM バックエンドの事前可用性チェック（preflight）を実行します。結果は 60 秒間キャッシュされます。

```mathematica
(* claudecode バックエンドの可用性確認 *)
ClaudeBackendAvailableQ[{"claudecode", Automatic}]

(* lmstudio バックエンドの可用性確認（URL 付き） *)
ClaudeBackendAvailableQ[{"lmstudio", "my-model", "http://localhost:1234"}]

(* キャッシュを無視して再取得 *)
ClaudeBackendAvailableQ[{"lmstudio", Automatic}, "Refresh" -> True]
```

返り値の形式：

| キー | 値の例 | 説明 |
|------|--------|------|
| `"Available"` | `True` / `False` | バックエンドが利用可能かどうか |
| `"Reason"` | `"OK"` / `"NotRunning"` / `"ModelNotLoaded"` / `"RateLimited"` / `"StateUnknown"` | 利用可否の理由 |
| `"BaseURL"` | `"http://localhost:1234"` | 接続先 URL（lmstudio 等） |

`"Reason"` が `"RateLimited"` の場合はレート制限中を示します。`"StateUnknown"` は `/api/v1` 系のみ対応するサーバ（state 情報が取得できないため）で返され、この場合はブロックされません。

### 仕様実装ワークフロー（CreateImplementationWorkflow）

`CreateImplementationWorkflow` は、承認済み設計仕様から SourceVault 管理下の codified ワークフローパッケージ（`SVWorkflow_<Name>`）を自動的に実装する機能です。実装担当（`$ClaudeModel`）と検証担当（`$ClaudeAdvisaryModel`）が協調してコードを生成・検証し、合意に達するまでラウンドを繰り返します。

```mathematica
(* 承認済み仕様から実装ワークフローを生成 *)
jobId = CreateImplementationWorkflow["workflowName", approvedSpec]

(* approvedSpec は sv:// URI、スナップショット ref、または仕様テキスト *)
jobId = CreateImplementationWorkflow["myProcessor",
  "sv://snapshot/Spec/abc123def456"]

(* Notes オプションで補足指示を渡す *)
jobId = CreateImplementationWorkflow["myProcessor",
  specText, "Notes" -> "既存の SourceVault API を活用すること"]

(* モデルをジョブ単位でオーバーライドする場合 *)
jobId = CreateImplementationWorkflow["myProcessor", specText,
  "ClaudeModel"    -> {"claudecode", "claude-opus-4-8"},
  "AdvisaryModel"  -> {"chatgptcodex", "gpt-5.5"},
  "MaxRounds"      -> 5]
```

実装が完了すると、生成されたワークフローの起動関数がセッションと promptrouter に自動登録されます。進捗はウィンドウステータスバーにリアルタイム表示されます（実行モデル・フェーズ・ラウンド数）。

実装担当は fail-closed 方針で動作します。実装に必要な API（プロジェクト内 API・外部 API を問わず）を実物のドキュメント／コードで検証できなかった場合、推測でコードを生成せず実行を中断します。この場合、生成される結果の `FinalStatus` は `"Blocked"` となり、ノートブックには以下のような警告セルが（強調表示で）書き込まれます：

```
⚠ Implementation STOPPED (fail-closed): a required API could not be verified against ground truth, so nothing was generated on a guessed API.
```

`BlockReason` には未検証の API が具体的に示されます。対処法は「トラブルシューティング > 12. 仕様実装ワークフローが「fail-closed」で中断される」を参照してください。

```mathematica
(* 生成されたワークフローを起動 *)
LaunchImplementationWorkflow["workflowName", args]
```

`LaunchImplementationWorkflow` は `SourceVault`SourceVaultLoadWorkflow[name]` でワークフローをロードし、`WorkflowInfo["Launch"]` エントリを `args` で呼び出します。起動コンテキスト・エントリ・結果を含む Association を返します。

#### 仕様実装ワークフローの状態確認

```mathematica
(* 現在のノートブックに関する実行状態を Dataset で表示 *)
ClaudeImplStatus[]

(* 特定ワークフローの状態を確認 *)
ClaudeImplStatus["workflowName"]

(* ライブ監視パネルをセルに表示（約 2 秒ごとに自動更新） *)
ClaudeImplMonitor[]
```

`ClaudeImplStatus[]` は現在のフェーズ・実行中モデル・ステージ・ラウンド・メッセージ、および SourceVault のアーティファクト/検証チェーン数と最新の合意結果（`FinalStatus`。fail-closed で中断した場合は `"Blocked"`）を表示します。ワークフローの実行中は同じ状態がウィンドウステータスバーにも自動表示されます。

#### 仕様バージョン管理

仕様・レビューの各バージョンは SourceVault に記録されます。次の関数でバージョンを参照・管理できます：

```mathematica
(* 現在のノートブックプロジェクトの仕様状況を確認 *)
ClaudeSpecStatus[]

(* 特定プロジェクトの仕様状況 *)
ClaudeSpecStatus["projectName"]

(* 記録された全バージョンの一覧（Dataset: Role/Round/Verdict/URI 等） *)
ClaudeSpecVersions[]
ClaudeSpecVersions["projectName"]

(* 仕様ロールでフィルタ *)
ClaudeSpecVersions["projectName", "spec"]     (* 仕様バージョンのみ *)
ClaudeSpecVersions["projectName", "review"]   (* レビューバージョンのみ *)

(* sv:// URI から仕様テキストを取得 *)
ClaudeSpecText["sv://snapshot/Spec/abc123"]

(* sv:// URI の内容を新しいノートブックで開く *)
ClaudeOpenSourceVaultURI["sv://snapshot/Spec/abc123"]
```

`ClaudeOpenSourceVaultURI` は sv:// スナップショット URI を解決し、メタデータグリッドと本文（レビューの場合は Findings も含む）を新規ノートブックウィンドウに表示します。仕様・コンセンサスフローがノートブックに書き込む sv:// リンクをクリックしたときのアクションとしても機能します。

### api.md 自動更新の設定

パッケージ更新時の api.md 自動更新を制御できます：

```mathematica
(* 自動更新を有効化（デフォルト） *)
ClaudeUpdatePackage["pkg", "修正指示", "UpdateApiMd" -> True]

(* 自動更新を無効化 *)
ClaudeUpdatePackage["pkg", "修正指示", "UpdateApiMd" -> False]
```

### 依存パッケージ API の自動注入

`ClaudeUpdatePackage` 実行時、プロンプト内に登場する依存パッケージ名を検出し、そのパッケージの `api.md` を自動的にコンテキストに注入します。これにより、パッケージ境界を越えた関数呼び出しの原因追跡が可能になります。この機能は設定不要で自動的に動作します。

### 検証テストの自動生成

`ClaudeUpdatePackage` 実行時、LLM が更新後のコードに対する検証テストを自動生成します。テストは `===BEGIN_TESTS===` / `===END_TESTS===` マーカーで囲まれた形式で返され、コメントラベル付きのブロックに分割されてマージ後に自動実行されます。各ブロックは `(* コメント *)` の直後に Boolean 式が来る形式を想定しており、テスト結果（合否件数）はノートブックに表示されます。

### ターゲット関数の自動推定

`ClaudeUpdatePackage` はプロンプト内の複合語から更新対象関数を2フェーズで自動推定します：

- **フェーズ 1（本体マッチ）**: 4文字以上の漢字・カタカナ連続列や5文字以上の英語キーワードをプロンプトから抽出し、関数本体にその複合語が含まれる関数を検出します。2文字以下の短い関数名や、3文字以下の汎用的すぎる語（ボタン、削除、展開 等）は誤マッチを防ぐため除外されます。
- **フェーズ 2（usage bi-gram フォールバック）**: フェーズ 1 で対象関数が見つからない場合、usage 文字列への bi-gram マッチにフォールバックします。

推定された関数数が40を超える場合は複合語が汎用的すぎると判断し、パッケージ全体を送信するフォールバックに切り替わります。

### セグメント単位の関数マージ

`ClaudeUpdatePackage` で LLM が部分的なレスポンスを返した場合（一部の関数のみ更新）、連続した行のかたまりを「セグメント」として抽出し、セグメント単位でマージが行われます。

- 各セグメントについて元コードとの照合を行い、一致したセグメントのみ置換されます。
- 照合に失敗したセグメントは置換されず、以下のような警告としてノートブックに表示されます：

```
⚠ マージ不一致: 以下の関数はセグメントが元コードと一致せず、置換できませんでした:
  functionName1, functionName2
```

- 完全修飾定義（`Pkg\`X` / `Pkg\`Private\`iX` 形式）も認識されます。

この機能は設定不要で自動的に動作します。警告が表示された場合は、LLM の生成コードと元コードの差異を確認してください。

### 非同期スケジューリング規約の自動注入

`ClaudeUpdatePackage` 実行時、LLM プロンプトに非同期タスクスケジューリング規約が自動的に注入されます。これにより、生成されたコードが claudecode/NBAccess の公開 API（`ClaudeEval`、`NBBeginJob` 等）を使って非同期処理を実装するよう誘導されます。純粋な計算タスク（数値・組み合わせ計算等、UI を操作しないもの）や `PresentationListener` のような独立した対話型プログラムは例外として個別の `ScheduledTask` の使用が許可されます。この機能は設定不要で自動的に動作します。

### ContinueUpdate の使い方

`ContinueUpdate` は直前の `ClaudeUpdatePackage` の結果を踏まえて修正を継続します：

```mathematica
(* 引数なし: 履歴から自動でパッケージ・前回応答を取得してバグ修正を継続 *)
ContinueUpdate[]

(* 追加指示を付けて継続 *)
ContinueUpdate["上半円の境界線が欠けているので修正して"]

(* テキスト + 画像で継続 *)
ContinueUpdate[{"スクリーンショットを確認して修正して", image}]

(* パッケージ名を明示して継続（履歴が見つからない場合など） *)
ContinueUpdate["pkgName", "追加の修正指示"]
```

### LLMGraph DAG の並列度制御

`$LLMGraphMaxConcurrency` を使用して、LLMGraph DAG 実行時の抽象カテゴリごとの最大並列度をグローバルに制御できます：

```mathematica
(* CLI テキスト呼び出しの最大並列度を設定 *)
$LLMGraphMaxConcurrency["cli"] = 2

(* CLI 画像付き呼び出しの最大並列度を設定 *)
$LLMGraphMaxConcurrency["cli-vision"] = 1
```

ジョブ実行時には以下の優先順位で並列度が解決されます：

1. `taskDescriptor["maxConcurrency"][abstractCat]`（ジョブ固有のオーバーライド）
2. `$LLMGraphMaxConcurrency[abstractCat]`（グローバルデフォルト）
3. `1`（フォールバック）

`LLMGraphDAGRebuild` を使うと、既存の DAG ジョブの特定ノードのハンドラを差し替えた新 DAG を構成・起動できます：

```mathematica
(* 指定ノードのハンドラを差し替えて DAG を再起動 *)
LLMGraphDAGRebuild[jobId, nodeId, newHandler]
```

### 遅延実行とスケジューリング

```mathematica
(* 指定時刻での実行 *)
ClaudeEval["タスク", StartTime -> Now + Quantity[3, "Hours"]]

(* 繰り返し実行 *)
ClaudeEval["定期タスク", 
  StartTime -> Now + Quantity[1, "Hours"],
  RepeatInterval -> Quantity[2, "Hours"]]

(* 最大実行回数付きの繰り返し *)
ClaudeEval["制限付きタスク", 
  RepeatInterval -> {Quantity[1, "Hours"], 5}]
```

### 分離原則の検証

NBAccess 分離原則の違反をチェックできます：

```mathematica
(* 分離原則チェック *)
ClaudeCheckSeparation["claudecode"]

(* 違反の自動修正 *)
ClaudeFixSeparation["claudecode"]

(* テストモデルの設定 *)
$ClaudeTestModel = "claude-sonnet-4-6"
```

## 次のステップ

セットアップが完了したら、以下のドキュメントを参照してください：

- **api.md** - 全関数の詳細なリファレンス
- **user_manual.md** - 実用的な使用方法とワークフロー（ClaudeRuntime・ClaudeTestKit の活用方法を含む）
- **README.md** - パッケージの概要と基本情報（ClaudeRuntime・ClaudeTestKit・ClaudeOrchestrator の位置付けを含む）

より詳細な使用方法については：

```mathematica
(* パレットの表示 *)
ShowClaudePalette[]

(* ヘルプ情報 *)
?ClaudeEval
?ClaudeUpdatePackage
?ContinueUpdate
?ClaudeCreateDocumentation
?ClaudeUpdateDocumentation
?$ClaudePackageKeywordMap
?$LLMGraphMaxConcurrency
?$UseClaudeRuntime
?$ClaudeLastRuntimeId
?$ClaudeDocUpdateStaleSeconds
?$ClaudeAdvisaryModel
?$ClaudeStandardFont
?CreateImplementationWorkflow
?LaunchImplementationWorkflow
?ClaudeImplStatus
?ClaudeImplMonitor
?ClaudeSpecStatus
?ClaudeSpecVersions
?ClaudeSpecText
?ClaudeOpenSourceVaultURI
?$ClaudeCLIMCPServers
?ClaudeRegisterCLIMCPServer
?ClaudeBackendAvailableQ
?ClaudeResolveLLMTier
?ClaudeTaskClassAttributes
?ClaudeDiagEvents