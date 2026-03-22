# セットアップガイド

claudecode パッケージのインストールと初期設定の手順を説明します。

## システム要件

### 必須環境
- **Wolfram Language 12.0** 以上（Mathematica または Wolfram Engine）
- **Windows 10/11** （現在 Windows 専用実装）
- **Node.js 16.0** 以上
- **Claude Code CLI** （Anthropic 提供）

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

## パッケージのインストール

### 1. 依存パッケージの配置

claudecode パッケージは以下の依存関係があります：

- **[NBAccess](https://github.com/transreal/NBAccess)** パッケージ（ノートブック操作用）
- **[github](https://github.com/transreal/github)** パッケージ（GitHub 連携用）

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

初回読み込み時に node-pty が自動的にインストールされます。

## 初期設定

### 1. 基本設定の確認

```mathematica
(* 設定確認 *)
ClaudeShowAccessConfig[]

(* モデル設定（必要に応じて変更） *)
$ClaudeModel = "claude-opus-4-6"

(* タイムアウト設定 *)
$ClaudeTimeout = 1200
```

### 2. 作業ディレクトリの設定

```mathematica
(* 作業ディレクトリの設定（デフォルト: ~/Claude Working） *)
$ClaudeWorkingDirectory = FileNameJoin[{$HomeDirectory, "Claude Working"}]

(* アクセス可能ディレクトリの設定 *)
$ClaudeAccessibleDirs = {$packageDirectory}
```

### 3. パッケージキーワードマップの設定

新機能として、パッケージごとのキーワード自動登録システムが追加されました：

```mathematica
(* パッケージキーワードマップの設定例 *)
$ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "切"}
$ClaudePackageKeywordMap["github"] = {"GitHub", "git", "リポジトリ"}

(* 設定確認 *)
$ClaudePackageKeywordMap
```

プロンプトにキーワードが含まれると、対応パッケージの api.md がコンテキストに自動注入されます。

### 4. フォールバックモデルの設定（オプション）

Claude Code が利用できない場合のバックアップとして、他の LLM を設定できます：

```mathematica
(* フォールバックモデルの設定例 *)
$ClaudeFallbackModels = {
  {"anthropic", "claude-opus-4-6"},
  {"openai", "gpt-4"},
  {"lmstudio", "local-model", "http://127.0.0.1:1234"}
}
```

### 5. ドキュメント生成設定

```mathematica
(* ドキュメント生成用モデル *)
$ClaudeDocModel = "claude-sonnet-4-20250514"

(* リトライ設定 *)
$ClaudeDocMaxRetries = 3
$ClaudeDocRetryDelay = 60

(* チャンク分割の最大文字数 *)
$ClaudeDocMaxChunkChars = 60000
```

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

(* キーワード連携のテスト（maildbキーワードを含むクエリ） *)
ClaudeQuery["メールを処理するプログラムを作りたい"]
```

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

### デバッグ情報の取得

```mathematica
(* 詳細な状態情報 *)
ClaudeStatus[]
ClaudeSessionStatus[]

(* アクセス設定の確認 *)
ClaudeShowAccessConfig[]

(* 実行中のタスク情報 *)
ClaudeStatus[]

(* パッケージ更新履歴の確認 *)
ClaudeUpdatePackageHistory[]

(* バックアップ履歴の確認 *)
ClaudeBackupDataset[]
```

## 高度な設定

### api.md 自動更新の設定

パッケージ更新時の api.md 自動更新を制御できます：

```mathematica
(* 自動更新を有効化（デフォルト） *)
ClaudeUpdatePackage["pkg", "修正指示", "UpdateApiMd" -> True]

(* 自動更新を無効化 *)
ClaudeUpdatePackage["pkg", "修正指示", "UpdateApiMd" -> False]
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
$ClaudeTestModel = "claude-sonnet-4-20250514"
```

## 次のステップ

セットアップが完了したら、以下のドキュメントを参照してください：

- **api.md** - 全関数の詳細なリファレンス
- **user_manual.md** - 実用的な使用方法とワークフロー
- **README.md** - パッケージの概要と基本情報

より詳細な使用方法については：

```mathematica
(* パレットの表示 *)
ShowClaudePalette[]

(* ヘルプ情報 *)
?ClaudeEval
?ClaudeUpdatePackage
?$ClaudePackageKeywordMap