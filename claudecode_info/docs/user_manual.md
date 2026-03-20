## 設計思想と実装の概要

ClaudeCode は以下の設計原則に基づいています。

- **ノートブック中心**: すべての操作はノートブック上で完結します。CLI を直接操作する必要はありません。
- **非同期実行**: LLM への問い合わせは非同期で実行され、ノートブックの操作を妨げません。リアルタイムのストリーミング進捗表示により、思考中・テキスト生成中・ツール実行中の状態を確認できます。
- **安全なパッケージ管理**: パッケージの更新はバックアップ・差分マージ・安全性検証・再ロードを自動で行います。排他ロック機構により、同一パッケージへの並列更新を防止します。
- **差分ベースバックアップ**: バックアップは SequenceAlignment ベースの差分形式（.cz / .cdiff / .unchanged）で保存され、ストレージ消費を大幅に削減します。既存の生バックアップは `ClaudeMigrateBackupHistory` で差分形式に変換できます。
- **機密データ保護**: `Confidential[]` による秘匿変数システムと、プライバシー考慮型モデルルーティングにより、機密データの安全な取り扱いを実現します。アクセスレベルに基づいて、クラウドモデルとローカルモデルを自動的に使い分けます。
- **多段フォールバック**: Claude Code CLI が利用不可の場合、アクセスレベルに応じたフォールバックモデルに自動切替します。Anthropic API、OpenAI API、LM Studio 等のローカルモデルを順次試行します。
- **セッション管理**: 会話履歴をノートブックの TaggingRules に永続化し、差分圧縮と自動コンパクションによりストレージを効率的に利用します。
- **多言語対応**: `$Language` 設定に基づいてプロンプトの言語指示を動的に生成します。日本語・英語等の環境で適切な応答言語が自動選択されます。
- **AI 生成機能**: OpenAI Images API による画像生成（`ClaudeImageGenerate`）と OpenAI TTS API による音声生成（`ClaudeSpeech`）を統合しています。
- **プロジェクト固有ディレクティブ**: ノートブックディレクトリごとに独立したルール・スキルを定義し、メインのディレクティブと自動マージできます。
- **スマートドキュメント管理**: ドキュメント生成・更新時のモード制御（新規作成・既存更新）、部分更新対象の指定、差分検出による効率的な更新処理を提供します。

内部的には、[NBAccess](https://github.com/transreal/NBAccess) パッケージにノートブックのセル操作・プライバシー管理・履歴 DB を委譲し、[GitHubREST](https://github.com/transreal/github) パッケージと連携して GitHub 上のパッケージ管理を行います。

## 詳細説明

### 動作環境

- Wolfram Mathematica 13.x 以降
- Windows 11（macOS/Linux ではパス区切りやシェルコマンドを適宜読み替えてください）
- Claude Code CLI がインストール済みで、パスが通っていること
- Node.js（node-pty によるインタラクティブ CLI 実行に使用）
- NBAccess パッケージ（`NBAccess.wl`）
- GitHubREST パッケージ（`github.wl`）— オプション、GitHub 連携時に必要

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

(* 画像生成モデル *)
$ClaudeImageModels = {{"openai", "gpt-image-1"}, {"openai", "dall-e-3"}}

(* 音声生成モデル *)
$ClaudeTTSModels = {{"openai", "tts-1-hd"}, {"openai", "tts-1"}}

(* NotebookDirectory のアクセスレベル *)
$ClaudeNBDirAccess = "list"  (* "list" | "read" | "readwrite" *)
```

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
| **Web** | `ClaudeWebSearch` | Web 検索（Anthropic API） |
| | `ClaudeWebFetch` | URL 内容取得・要約 |
| **分離検証** | `ClaudeCheckSeparation` | NBAccess 分離原則の違反検査 |
| | `ClaudeFixSeparation` | 違反の自動修正 |
| **ユーティリティ** | `ShowClaudePalette` | 操作パレット表示 |
| | `ClaudeStatus` | 実行中タスクの状態表示 |
| | `ClaudeCommand` | CLI スラッシュコマンド実行 |

### プライバシー考慮型モデルルーティング

ClaudeCode は機密データを含むタスクに対して、自動的にローカルモデルへルーティングする機能を備えています。

- **`$ClaudePrivateModel`**: ローカル LLM（LM Studio 等）のモデル仕様を設定します
- **`AutoPrivate -> True`**: 機密変数にアクセスするタスクで自動的にローカルモデルを使用します
- **`PrivacySpec`**: アクセスレベルを明示的に制御します
- **3段階フォールバック**: Claude Code CLI → アクセスレベル対応フォールバックモデル → エラーの順で試行します

### NotebookDirectory アクセス制御

`$ClaudeNBDirAccess` により、Claude Code がノートブックディレクトリ内のファイルにアクセスするレベルを制御できます。

| レベル | 説明 |
|---|---|
| `"list"` | ファイル一覧のみ表示。読み書き不可（デフォルト） |
| `"read"` | 読み取り許可 |
| `"readwrite"` | 読み書き許可 |

`"list"` モードでプロンプトが NotebookDirectory 内のファイルを参照している場合、権限付与ボタンが自動的に表示されます。ユーザーが「Read 許可」または「Read/Write 許可」をクリックすると、`$ClaudeNBDirAccess` が変更されてタスクが再実行されます。

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