## 設計思想と実装の概要

ClaudeCode は以下の設計原則に基づいています。

- **ノートブック中心**: すべての操作はノートブック上で完結します。CLI を直接操作する必要はありません。
- **非同期実行**: LLM への問い合わせは非同期で実行され、ノートブックの操作を妨げません。リアルタイムのストリーミング進捗表示により、思考中・テキスト生成中・ツール実行中の状態を確認できます。
- **安全なパッケージ管理**: パッケージの更新はバックアップ・差分マージ・安全性検証・再ロードを自動で行います。排他ロック機構により、同一パッケージへの並列更新を防止します。
- **差分ベースバックアップ**: バックアップは SequenceAlignment ベースの差分形式（.cz / .cdiff / .unchanged）で保存され、ストレージ消費を大幅に削減します。既存の生バックアップは `ClaudeMigrateBackupHistory` で差分形式に変換できます。
- **機密データ保護**: `Confidential[]` による秘匿変数システムと、プライバシー考慮型モデルルーティングにより、機密データの安全な取り扱いを実現します。アクセスレベルに基づいて、クラウドモデルとローカルモデルを自動的に使い分けます。
- **多段フォールバック**: Claude Code CLI が利用不可の場合、アクセスレベルに応じたフォールバックモデルに自動切替します。Anthropic API、OpenAI API、LM Studio 等のローカルモデルを順次試行します。
- **セッション管理**: 会話履歴をノートブックの TaggingRules に永続化し、差分圧縮と自動コンパクションによりストレージを効率的に利用します。
- **多言語対応**: `$Language` 設定に基づいてプロンプトの言語指示を動的に生成します。`$Language` が `"Japanese"` の場合は日本語で応答するよう指示し、それ以外の場合は英語に切り替わります。
- **AI 生成機能**: OpenAI Images API による画像生成（`ClaudeImageGenerate`）と OpenAI TTS API による音声生成（`ClaudeSpeech`）を統合しています。
- **プロジェクト固有ディレクティブ**: ノートブックディレクトリごとに独立したルール・スキルを定義し、メインのディレクティブと自動マージできます。
- **スマートドキュメント管理**: ドキュメント生成・更新時のモード制御（新規作成・既存更新）、部分更新対象の指定、差分検出による効率的な更新処理を提供します。
- **分離原則検証**: NBAccess パッケージとの適切な分離を維持するため、コード内の分離原則違反を自動検出・修正する機能を備えています。
- **パッケージキーワード自動注入**: 各パッケージが独自のキーワードを登録し、プロンプト中にキーワードが含まれる場合に自動的にそのパッケージの API ドキュメントをコンテキストに注入します。

内部的には、[NBAccess](https://github.com/transreal/NBAccess) パッケージにノートブックのセル操作・プライバシー管理・履歴 DB を委譲し、[GitHubREST](https://github.com/transreal/github) パッケージと連携して GitHub 上のパッケージ管理を行います。

## 詳細説明

### 動作環境

- Wolfram Mathematica 13.x 以降
- Windows 11（macOS/Linux ではパス区切りやシェルコマンドを適宜読み替えてください）
- Claude Code CLI がインストール済みで、パスが通っていること
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

### 基本設定

```mathematica
(* 使用するモデルの指定（空文字列で Claude Code のデフォルトモデル） *)
$ClaudeModel = "claude-sonnet-4-20250514"

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
$ClaudeAccessibleDirs = {$packageDirectory}

(* 作業ディレクトリ *)
$ClaudeWorkingDirectory = FileNameJoin[{$HomeDirectory, "Claude Working"}]

(* パッケージキーワード自動注入マップ *)
$ClaudePackageKeywordMap = <||>
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
| | `ClaudeUpdateDocumentation` | 差分検出による自動更新・モード制御機能 |
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
| **AI 生成** | `ClaudeImageGenerate` | OpenAI Images API で画像生成 |
| | `ClaudeSpeech` | OpenAI TTS API で音声生成 |
| **Web** | `ClaudeWebSearch` | Web 検索（Claude Code 組み込み） |
| | `ClaudeWebFetch` | URL 内容取得・要約（Anthropic API） |
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

### 多言語対応（$Language ベースの言語切り替え）

ClaudeCode は Wolfram Language の `$Language` 変数を参照して、Claude への応答言語指示を自動生成します。

- **`$Language = "Japanese"`** の場合: Claude に対して日本語で応答するよう指示します。
- **`$Language` が `"Japanese"` 以外**（例: `"English"`、その他の言語）の場合: 英語で応答するよう指示します。

この切り替えはプロンプト生成時に自動で行われるため、ユーザーが明示的に設定する必要はありません。Mathematica の言語設定に合わせて適切な応答言語が選択されます。

### アクセス可能ディレクトリ制御

`$ClaudeAccessibleDirs` により、Claude Code がアクセスできるディレクトリを制御できます。NotebookDirectory が安全なデフォルトディレクトリ（`$packageDirectory` や `$ClaudeWorkingDirectory` 配下）でない場合、初回使用時にダイアログで許可を求めます。許可設定はノートブックの TaggingRules に永続化されます。

### パッケージ更新の排他ロック

同一パッケージに対する `ClaudeUpdatePackage` の並列実行を防ぐ排他ロック機構が組み込まれています。更新開始時にロックが取得され、完了時に自動解放されます。異なるパッケージへの同時更新は並列実行可能です。

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

(* オプション指定 *)
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

### Think トリガー自動挿入

日本語の励まし表現が自動的に Claude の思考トリガーに変換されます。

| 日本語表現 | 変換先 | 思考レベル |
|---|---|---|
| 死ぬ気で考えろ、本気出せ、全力で、徹底的に | `ultrathink` | 最大（32K トークン） |
| よく考えて、じっくり、慎重に、がんばれ、丁寧に | `think hard` | 中程度（10K トークン） |
| 考えてみて、少し考えて | `think` | 基本（4K トークン） |

ClaudeUpdatePackage 等の呼び出し時にも、指示文中の日本語表現が自動的にトリガーワードに変換されます。

### ドキュメント生成・更新の高度制御

`ClaudeUpdateDocumentation` は柔軟なモード制御と部分更新機能を提供します。

```mathematica
(* 基本的なドキュメント更新（既存ファイルを更新） *)
ClaudeUpdateDocumentation["MyPackage", "新機能の説明を追加"]

(* 新規作成モード（既存内容を無視して新規作成） *)
ClaudeUpdateDocumentation["MyPackage", "setup.mdを作成", 
  TargetFiles -> {"setup.md"}, Mode -> "Create"]

(* 特定ファイルのみ更新 *)
ClaudeUpdateDocumentation["MyPackage", "API仕様を更新", 
  TargetFiles -> {"api.md"}]

(* 複数ファイルを同時更新 *)
ClaudeUpdateDocumentation["MyPackage", "全体的な改善", 
  TargetFiles -> {"README.md", "user_manual.md"}]
```

| オプション | デフォルト | 説明 |
|---|---|---|
| `Mode` | `"Update"` | `"Update"`: 既存を更新、`"Create"`: 新規作成（既存内容無視） |
| `TargetFiles` | `Automatic` | 更新対象ファイルのリスト。`Automatic` で全ドキュメントを対象 |
| `References` | `{}` | 参考文献リスト（README.md に反映） |
| `Demos` | `{}` | デモ動画・使用例 URL（README.md に反映） |
| `Disclaimer` | `{}` | 免責事項（README.md に反映） |

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