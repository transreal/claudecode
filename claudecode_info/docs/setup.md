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

- **NBAccess** パッケージ（ノートブック操作用）
- **GitHubREST** パッケージ（GitHub 連携用）

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

### 3. フォールバックモデルの設定（オプション）

Claude Code が利用できない場合のバックアップとして、他の LLM を設定できます：

```mathematica
(* フォールバックモデルの設定例 *)
$ClaudeFallbackModels = {
  {"anthropic", "claude-opus-4-6"},
  {"openai", "gpt-4"},
  {"lmstudio", "local-model", "http://127.0.0.1:1234"}
}
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

## 設定のカスタマイズ

### プライバシー設定

機密データを扱う場合の設定：

```mathematica
(* プライベートモデルの設定 *)
$ClaudePrivateModel = {"lmstudio", "local-model", "http://127.0.0.1:1234"}

(* 自動プライベートモード *)
ClaudeEval["機密データの処理", AutoPrivate -> True]
```

### ドキュメント生成設定

```mathematica
(* ドキュメント生成用モデル *)
$ClaudeDocModel = "claude-sonnet-4-20250514"

(* リトライ設定 *)
$ClaudeDocMaxRetries = 3
$ClaudeDocRetryDelay = 60
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

### デバッグ情報の取得

```mathematica
(* 詳細な状態情報 *)
ClaudeStatus[]
ClaudeSessionStatus[]

(* アクセス設定の確認 *)
ClaudeShowAccessConfig[]

(* 実行中のタスク情報 *)
ClaudeStatus[]
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