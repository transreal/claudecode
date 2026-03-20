# ClaudeCode

Wolfram Language / Mathematica ノートブック環境と Claude Code CLI を統合するパッケージです。ノートブック上から Claude への問い合わせ、コード生成、パッケージ管理、ドキュメント生成を非同期で実行できます。

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
- **AI 生成 API 統合**: OpenAI Images API による画像生成（`ClaudeImageGenerate`）と OpenAI TTS API による音声生成（`ClaudeSpeech`）をノートブックから直接利用できます。ClaudeQuery のリッチレスポンスモードでは、ユーザーの依頼に応じてこれらの API を自動的に呼び出します。
- **プロジェクト固有ディレクティブ**: ノートブックのディレクトリごとにプロジェクト固有のルール・スキルを定義し、メインのディレクティブと自動マージできます。

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

(* 画像生成モデルリスト *)
$ClaudeImageModels = {{"openai", "gpt-image-1"}, {"openai", "dall-e-3"}}

(* 音声生成モデルリスト *)
$ClaudeTTSModels = {{"openai", "tts-1-hd"}, {"openai", "tts-1"}}
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

(* AI 画像生成 *)
ClaudeImageGenerate["桜の満開の写真、フォトリアル"]

(* AI 音声生成 *)
ClaudeSpeech["こんにちは、世界"]

(* パッケージの更新 *)
ClaudeUpdatePackage["MyPackage", "エラーハンドリングを改善"]

(* ドキュメント生成 *)
ClaudeCreateDocumentation["MyPackage"]
```

### 主な機能

| カテゴリ | 機能 | 説明 |
|---|---|---|
| **問い合わせ** | `ClaudeQuery` | 同期的にテキスト応答を取得 |
| | `ClaudeEval` | 非同期でコード生成・実行 |
| | `ContinueEval` | 会話の継続・エラー修正 |
| | `ClaudeSpec` | 仕様書の生成 |
| **AI 生成** | `ClaudeImageGenerate` | OpenAI Images API で画像を生成 |
| | `ClaudeSpeech` | OpenAI TTS API で音声を生成 |
| **パッケージ管理** | `ClaudeCreatePackage` | 新規パッケージ作成 |
| | `ClaudeUpdatePackage` | バックアップ付きパッケージ更新 |
| | `ContinueUpdate` | 直前の更新を継続・バグ修正 |
| | `ClaudeRestorePackage` | バックアップからの復元 |
| | `ClaudeConvertToPaclet` | Paclet 形式への変換 |
| **ドキュメント** | `ClaudeCreateDocumentation` | ドキュメント一式の自動生成 |
| | `ClaudeUpdateDocumentation` | 差分検出による自動更新 |
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
| | `ClaudeUpdateDirective` | ディレクティブの更新・自動整合 |
| | `ClaudeSyncDirectives` | 外部フォルダからの同期 |
| | `ClaudeDirectiveBackupDataset` | ディレクティブ更新履歴の管理 |
| | `ClaudeInitProject` | プロジェクト固有ディレクティブの初期化 |
| | `ClaudePromoteProjectDirectives` | ローカルディレクティブをグローバルに昇格 |
| **Web** | `ClaudeWebSearch` | Web 検索（Anthropic API） |
| | `ClaudeWebFetch` | URL 内容取得・要約 |
| **分離検証** | `ClaudeCheckSeparation` | NBAccess 分離原則の違反検査 |
| | `ClaudeFixSeparation` | 違反の自動修正 |
| **ユーティリティ** | `ShowClaudePalette` | 操作パレット表示 |
| | `ClaudeStatus` | 実行中タスクの状態表示 |
| | `ClaudeCommand` | CLI スラッシュコマンド実行 |

### AI 画像・音声生成

ClaudeCode は OpenAI の API を利用して、ノートブック上から直接 AI 画像生成・音声生成を行えます。

#### ClaudeImageGenerate

OpenAI Images API を使用して画像を生成し、Image オブジェクトとして返します。

```mathematica
(* 基本的な画像生成 *)
ClaudeImageGenerate["桜の満開と日本の城、フォトリアル"]

(* モデルとオプション指定 *)
ClaudeImageGenerate["sunset over the ocean",
  "Model" -> "dall-e-3",
  "Size" -> "1792x1024",
  "Quality" -> "hd"]
```

主なオプション:

| オプション | 値 | 説明 |
|---|---|---|
| `"Model"` | `"gpt-image-1"` (デフォルト), `"dall-e-3"` | 使用するモデル |
| `"Size"` | `"1024x1024"` (デフォルト), `"1792x1024"`, `"1024x1792"` | 画像サイズ |
| `"Quality"` | gpt-image-1: `"auto"` (デフォルト), `"high"`, `"medium"`, `"low"` / dall-e-3: `"standard"` (デフォルト), `"hd"` | 画像品質 |
| `"N"` | `1` (デフォルト) | 生成枚数 |

dall-e-3 指定時は `"auto"` → `"standard"`、`"high"` → `"hd"` に自動変換されます。

#### ClaudeSpeech

OpenAI TTS API を使用して音声を生成し、Audio オブジェクトとして返します。

```mathematica
(* 基本的な音声生成 *)
ClaudeSpeech["こんにちは、世界"]

(* モデルと音声オプション指定 *)
ClaudeSpeech["Hello, world!",
  "Model" -> "tts-1-hd",
  "Voice" -> "nova",
  "Speed" -> 1.2]
```

主なオプション:

| オプション | 値 | 説明 |
|---|---|---|
| `"Model"` | `"tts-1"` (デフォルト), `"tts-1-hd"` | 使用するモデル |
| `"Voice"` | `"alloy"` (デフォルト), `"echo"`, `"fable"`, `"onyx"`, `"nova"`, `"shimmer"` | 音声の種類 |
| `"Speed"` | `1.0` (デフォルト), 0.25〜4.0 | 再生速度 |

#### ClaudeQuery からの自動呼び出し

ClaudeQuery のリッチレスポンスモードでは、ユーザーの依頼に応じて `ClaudeImageGenerate` や `ClaudeSpeech` を含むコードブロックが自動生成されます。

- 「AI で桜の写真を生成して」→ `ClaudeImageGenerate[...]` を含むコードが生成・実行されます
- 「この文章を読み上げて」→ `ClaudeSpeech[...]` を含むコードが生成・実行されます
- 「sin(x) をプロットして」→ `Plot[Sin[x], ...]` が生成されます（AI 生成ではなく Mathematica ネイティブ）

これらの API を使用するには `SystemCredential["OPENAI_API_KEY"]` の設定が必要です。

### プライバシー考慮型モデルルーティング

ClaudeCode は機密データを含むタスクに対して、自動的にローカルモデルへルーティングする機能を備えています。

- **`$ClaudePrivateModel`**: ローカル LLM（LM Studio 等）のモデル仕様を設定します
- **`AutoPrivate -> True`**: 機密変数にアクセスするタスクで自動的にローカルモデルを使用します
- **`PrivacySpec`**: アクセスレベルを明示的に制御します
- **3段階フォールバック**: Claude Code CLI → アクセスレベル対応フォールバックモデル → エラーの順で試行します

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

### プロジェクト固有ディレクティブ

ノートブックのディレクトリごとにプロジェクト固有のルール・スキルを定義できます。メインのディレクティブとの自動マージにより、プロジェクトごとに異なる Claude の振る舞いを設定できます。

```mathematica
(* プロジェクトディレクティブの初期化 *)
ClaudeInitProject[]
(* → NotebookDirectory/.claude-project/ に CLAUDE.local.md, rules/, skills/ が作成されます *)

(* プロジェクト固有のルールを追加（ローカルスコープ） *)
ClaudeAddDirective["CLAUDE.md", "このプロジェクトでは必ずテストを書くこと", Scope -> "Local"]

(* ローカルディレクティブをグローバルに昇格 *)
ClaudePromoteProjectDirectives[]

(* DryRun で昇格内容を確認 *)
ClaudePromoteProjectDirectives[DryRun -> True]
```

プロジェクトディレクティブは以下のディレクトリ構造を持ちます:

- `NotebookDirectory/.claude-project/CLAUDE.local.md` — プロジェクト固有の CLAUDE.md 追記
- `NotebookDirectory/.claude-project/rules/` — プロジェクト固有のルール
- `NotebookDirectory/.claude-project/skills/` — プロジェクト固有のスキル

マージ結果は `NotebookDirectory/.claude/` に出力され、次回の ClaudeQuery/ClaudeEval から自動的に反映されます。タイムスタンプ比較により、メインまたはローカルのディレクティブが変更された場合のみ再マージが実行されます。

### ディレクティブ管理

#### ClaudeAddDirective

ルールやスキルを Claude のディレクティブに追加します。Claude が記述を整形してからファイルに書き込みます。

```mathematica
(* グローバルディレクティブに追加（デフォルト） *)
ClaudeAddDirective["CLAUDE.md", "テスト駆動開発を推奨する"]

(* スキルに追加 *)
ClaudeAddDirective["wolfram-general", "パターンマッチングの優先順位ルール"]

(* プロジェクトローカルに追加 *)
ClaudeAddDirective["CLAUDE.md", "このプロジェクトでは日本語コメントを使う", Scope -> "Local"]

(* DryRun で変更内容を確認 *)
ClaudeAddDirective["CLAUDE.md", "ルール内容", DryRun -> True]
```

#### ClaudeUpdateDirective

ディレクティブの更新・整合性チェックを行います。

```mathematica
(* ソースコードとの整合性を自動チェック・修正 *)
ClaudeUpdateDirective[]

(* テキスト指示でディレクティブを更新 *)
ClaudeUpdateDirective["新しい機密データ処理ルールを追加して"]

(* ノートブックのコンテキストも参照して更新 *)
ClaudeUpdateDirective["上で議論されている内容を反映して"]

(* プロジェクトローカルに更新 *)
ClaudeUpdateDirective["ルール内容", Scope -> "Local"]
```

テキスト指示版は、ノートブックのコンテキスト（直近のセル内容）も参照できるため、「上で議論されている内容を反映して」のような指示が可能です。

### ディレクティブ書き込みガード

ディレクティブ（CLAUDE.md / rules / skills）の書き込み時には、以下の安全検証が自動的に行われます。

1. **サイズ退行チェック**: 既存ファイルの 40% 未満に縮小する書き込みは拒否されます
2. **タイトル整合性**: CLAUDE.md の先頭 `#` タイトルが変更される書き込みは拒否されます
3. **スキル名保持**: SKILL.md の `name:` 行が消滅する書き込みは拒否されます

ドキュメント書き込み時にも同様のガードが適用され、README.md のタイトルがパッケージ名と一致しない場合やサイズが大幅に縮小する場合は拒否されます。

### Think トリガー自動挿入

日本語の励まし表現を検出して、Claude の thinking budget を自動調整します。

| 日本語表現 | Think レベル | Budget |
|---|---|---|
| 死ぬ気で考えろ、本気出せ、全力で、徹底的に | ultrathink | 32K トークン |
| よく考えて、じっくり考えて、慎重に、がんばれ、丁寧に | think hard | 10K トークン |
| 考えてみて、少し考えて | think | 4K トークン |

```mathematica
(* 自動的に ultrathink が挿入される *)
ClaudeEval["死ぬ気で考えてこのバグを直して"]

(* ClaudeUpdatePackage の指示文字列にも適用可能 *)
ClaudeUpdatePackage["MyPkg", "じっくり考えてリファクタリングして"]
```

### 精密機密チェック（第2層）

ClaudeQuery / ClaudeEval / ContinueEval の送信直前に、全ノートブックを走査して完全な依存グラフを構築し、秘密依存変数の最終判定を行います。

- 第1層（CellEpilog による橙マーキング）は日常の注意喚起として常時動作します
- 第2層（iPrecisionConfidentialCheck）は LLM 送信直前にのみ実行され、別ノートブック経由の秘密依存も検出します
- 新たに発見された秘密依存変数は警告メッセージとともにコンテキスト送信から除外されます

### ドキュメント一覧

| ファイル | 内容 |
|---|---|
| `README.md` | パッケージ概要・セットアップ手順（本ファイル） |
| `api.md` | 全公開関数の API リファレンス |
| `user_manual.md` | 使い方・設定・具体例 |
| `architecture.md` | 内部アーキテクチャの解説 |
| `setup.md` | インストール手順書 |
| `examples/example.md` | 使用例集 |

### 使用例・デモ

- [ClaudeCode デモ](https://www.youtube.com/watch?v=_Lc-XtBPkl8&t=919s)

### 関連パッケージ

- [NBAccess](https://github.com/transreal/NBAccess) — ノートブック読み書き・プライバシー管理
- [GitHubREST](https://github.com/transreal/github) — GitHub パッケージ管理・PR 管理

## 免責事項

本ソフトウェアは "as is"（現状有姿）で提供されており、明示・黙示を問わずいかなる保証もありません。
本ソフトウェアの使用または使用不能から生じるいかなる損害についても責任を負いません。
今後の動作保証のための更新が行われるとは限りません。
本ソフトウェアとドキュメントはほぼすべてが生成AIによって生成されたものです。
Windows 11上での実行を想定しており、MacOS, LinuxのMathematicaでの動作検証は一切していません(生成AIの処理で対応可能と想定されます)。