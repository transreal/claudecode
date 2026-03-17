# claudecode セットアップガイド

Mathematica から Claude Code CLI を呼び出し、コード生成・レビュー・ドキュメント作成などを行うパッケージです。

> macOS/Linux ではパス区切りやシェルコマンドを適宜読み替えてください。

## 動作要件

| 項目 | バージョン |
|------|-----------|
| Mathematica | 13.0 以上（14.x 推奨） |
| Node.js | 18 以上 |
| Claude Code CLI | 最新版 |
| OS | Windows 11 |

## 1. 外部ツールのインストール

### Node.js

[公式サイト](https://nodejs.org/)から LTS 版をダウンロードしてインストールしてください。

```
node --version
```

### Claude Code CLI

```
npm install -g @anthropic-ai/claude-code
```

インストール後、以下で認証を済ませてください。

```
claude auth login
```

## 2. パッケージの配置

`claudecode.wl` と依存パッケージを `$packageDirectory` に配置します。

必要なファイル:

| ファイル | 説明 |
|---------|------|
| `claudecode.wl` | 本体 |
| `NBAccess.wl` | ノートブック読み書き・プライバシー管理（[GitHub](https://github.com/transreal/NBAccess)） |
| `github.wl` | GitHub REST API 連携（[GitHub](https://github.com/transreal/github)） |

すべて同一ディレクトリ（`$packageDirectory`）に配置してください。

## 3. パッケージの読み込み

```mathematica
(* $packageDirectory が $Path に含まれていることを確認 *)
AppendTo[$Path, $packageDirectory];

(* UTF-8 で読み込み *)
Block[{$CharacterEncoding = "UTF-8"},
  Needs["ClaudeCode`", "claudecode.wl"]];
```

初回ロード時に `node-pty` が未インストールの場合、自動で `npm install` が実行されます。

## 4. API キーの設定

Claude Code CLI の認証が完了していれば、追加の API キー設定は不要です。

フォールバック機能で Anthropic API や OpenAI API を直接使う場合は、`SystemCredential` に登録してください。

```mathematica
SystemCredential["ANTHROPIC_API_KEY"] = "sk-ant-...";
(* OpenAI フォールバックを使う場合 *)
SystemCredential["OPENAI_API_KEY"] = "sk-...";
```

## 5. 主要な設定変数

```mathematica
(* 使用モデル（空文字列 = Claude Code デフォルト） *)
$ClaudeModel = "";

(* タイムアウト秒数 *)
$ClaudeTimeout = 1200;

(* 作業ディレクトリ（.claude/CLAUDE.md 等の配置先） *)
$ClaudeWorkingDirectory = FileNameJoin[{$HomeDirectory, "Claude Working"}];

(* Claude Code に Read 許可する追加ディレクトリ *)
$ClaudeAccessibleDirs = {$packageDirectory};

(* フォールバックモデル優先順位 *)
$ClaudeFallbackModels = {
  {"anthropic", "claude-opus-4-6"},
  {"openai", "gpt-5"}
};
```

## 6. 動作確認

```mathematica
(* 基本的な問い合わせ *)
ClaudeQuery["1+1 を計算してください"]

(* コード生成・自動実行 *)
ClaudeEval["フィボナッチ数列の最初の10項をリストで返す関数"]

(* パレット表示 *)
ShowClaudePalette[]

(* セッション状態の確認 *)
ClaudeSessionStatus[]
```

## 7. トラブルシューティング

| 症状 | 対処 |
|------|------|
| `node-pty` のビルドエラー | `npm install -g windows-build-tools` を実行後に再ロード |
| Claude Code CLI が見つからない | `claude --version` で CLI の存在を確認 |
| 文字化け | `$CharacterEncoding` が `"UTF-8"` であることを確認 |
| タイムアウト | `$ClaudeTimeout` の値を増やす |

## 関連パッケージ

- [NBAccess](https://github.com/transreal/NBAccess) — ノートブックのセル読み書き・プライバシー管理
- [github](https://github.com/transreal/github) — GitHub REST API 連携