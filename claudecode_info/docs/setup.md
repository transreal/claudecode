# claudecode

**Mathematica ノートブックから Claude Code CLI を透過的に呼び出し、コード生成・レビュー・パッケージ管理・ドキュメント作成を非同期で行う統合パッケージです。**

[![GitHub](https://img.shields.io/badge/GitHub-transreal%2Fclaudecode-blue)](https://github.com/transreal/claudecode)

## 設計思想

claudecode は「ノートブックを離れずに AI コーディングを完結させる」ことを目的としています。以下の設計原則に基づいて実装されています。

### プライバシーファースト

ノートブック内の機密データ（個人情報、認証情報など）が外部 API に意図せず送信されることを防ぐため、**アクセスレベルに基づくモデルルーティング**を実装しています。機密セルはプロンプトから自動除外され、`AutoPrivate` オプションにより秘密データの処理をローカルモデルへ自動ルーティングできます。

### 非同期・ノンブロッキング

すべての LLM 呼び出しは非同期で実行されます。問い合わせ中はリアルタイムのプログレス表示（思考中・テキスト生成中・ツール実行中）を提供し、ノートブックの操作をブロックしません。`stream-json` 形式でストリーミング出力を差分解析し、各種カウンタを表示します。

### 安全なパッケージ更新

パッケージの更新は `ClaudeUpdatePackage` を通じて行われ、事前バックアップの自動作成、LLM レスポンスの安全なマージ検証、排他ロックによる並列更新の防止、更新後の再ロードまでを一貫して管理します。ディレクティブファイルの書き込みにも、サイズ退行・タイトル整合性・スキル名保持を検証するガード機構が組み込まれています。

### 差分ベースバックアップ

バックアップシステムは `SequenceAlignment` ベースの差分保存を採用しています。テキストファイル（`.wl` / `.md` 等）を `.cz`（Compress ベースライン）、`.cdiff`（差分）、`.unchanged`（前回参照）の3形式で保存し、バックアップ容量を大幅に削減します。既存の生バックアップは `ClaudeMigrateBackupHistory` で差分形式に一括変換できます。バックアップ削除時は依存チェーンを自動解決し、復元不能になることを防止します。

### 段階的フォールバック

Claude Code CLI が利用制限に達した場合でも、`Fallback -> True` により `$ClaudeFallbackModels` に登録されたモデルへ自動切替できます。フォールバック時もアクセスレベルに基づいて利用可能なモデルのみが選択されます。

### 多言語対応

`$Language` に基づいてプロンプト内の言語指定を動的に生成します。日本語環境では日本語でドキュメントや説明文を生成し、英語環境では英語で生成します。

## 実装概要

```
┌─────────────────────────────────────────────────────┐
│  Mathematica Notebook                                │
│  ┌───────────┐  ┌───────────┐  ┌────────────────┐  │
│  │ ClaudeEval│  │ClaudeQuery│  │ClaudeUpdatePkg │  │
│  └─────┬─────┘  └─────┬─────┘  └───────┬────────┘  │
│        └───────────────┼────────────────┘            │
│                   ┌────▼─────┐                       │
│                   │ アクセス  │                       │
│                   │レベル解決 │                       │
│                   └────┬─────┘                       │
│              ┌─────────┼──────────┐                  │
│         ┌────▼───┐ ┌───▼────┐ ┌──▼───┐              │
│         │Claude  │ │Fallback│ │Local │              │
│         │Code CLI│ │Models  │ │Model │              │
│         └────┬───┘ └───┬────┘ └──┬───┘              │
│              └─────────┼─────────┘                   │
│                   ┌────▼─────┐                       │
│                   │ NBAccess │ ← セル読み書き・       │
│                   │          │   プライバシー管理     │
│                   └──────────┘                       │
└─────────────────────────────────────────────────────┘
```

- **Claude Code CLI 連携**: `--output-format stream-json --verbose` で起動し、stdout の JSON Lines を差分解析します。`node-pty` による対話的 CLI コマンド実行もサポートしています。
- **NBAccess 連携**: ノートブックのセル読み書き、機密セル管理、プロバイダー別アクセスレベル判定を [NBAccess](https://github.com/transreal/NBAccess) に委譲しています。
- **GitHubREST 連携**: パッケージの GitHub へのアップロード・PR 管理を [github](https://github.com/transreal/github) パッケージと連携して行います。
- **セッション管理**: 会話履歴を NBAccess の履歴 DB に保存し、TaggingRules でノートブックに永続化します。コンパクション機能により長い履歴を要約圧縮でき、`ClaudeHistorySize` で履歴サイズを診断できます。

## 前回リリースからの主要変更点

### 差分ベースバックアップシステム

バックアップの保存形式を `SequenceAlignment` ベースの差分圧縮に刷新しました。テキストファイル（`.wl`・`.md` 等）を以下の3形式で保存します:
- `.cz` — `Compress[全文]` によるベースライン（一定間隔で自動作成）
- `.cdiff` — `Compress[{前回ディレクトリ名, SequenceAlignment結果}]` による差分
- `.unchanged` — 前回ディレクトリ名の参照（内容同一時、1ホップ解決保証）

`ClaudeMigrateBackupHistory` で既存の生バックアップを差分形式に一括変換できます。`DryRun -> True` で容量削減の見積もりを事前確認可能です。

### 安全なバックアップ削除

差分チェーンの中間ノードを削除する際、後続の `.cdiff` / `.unchanged` が参照先を失って復元不能になることを防止するため、`iSafeDeleteBackupDir` が依存ファイルを自動的に `.cz`（ベースライン）に変換してから削除を実行します。

### ディレクティブ書き込みガード

`iSafeWriteDirective` により、ディレクティブファイル（CLAUDE.md / SKILL.md / rules）の書き込み時に以下の検証を行います:
1. **サイズ退行**: 既存の 40% 未満に縮小 → 書き込み拒否
2. **タイトル保持**: CLAUDE.md の先頭 `#` タイトルが変更 → 書き込み拒否
3. **スキル名保持**: SKILL.md の `name:` 行が消滅 → 書き込み拒否

### 履歴サイズ診断とサイズベースコンパクション

`ClaudeHistorySize[]` でセッション履歴のサイズを診断できます。Entries・ByteCount・KiloBytes・Status を含む Association を返し、200KB超でコンパクション推奨、500KB超で危険と判定します。エントリ数ベースに加えてサイズベースの二重チェックにより、巨大な response を持つセッションでのノートブック肥大化・フリーズを防ぎます。

### バックアップスナップショット管理

`ClaudeBackupDataset` / `ClaudeDirectiveBackupDataset` の起動時に現在のファイルの SHA-256 ハッシュ付きスナップショットを自動保存します。Pull で過去のバックアップに巻き戻した後、#0行の「Pull」ボタンでローカル最新版に復元できます。ファイルが変更されている場合は警告を表示します。

### $Language ベース多言語対応

プロンプト内の言語指定を `$Language` に基づいて動的に生成するようになりました。`iLanguageName[]` で現在の言語名を取得し、`iLanguageInstruction[style]` でスタイル別（敬体・常体・一般）の言語指示文を生成します。

### プライバシー対応モデルルーティング

`$ClaudePrivateModel` と `AutoPrivate` オプションを追加しました。秘密変数にアクセスするタスクの生成コードに、ローカル/プライベートモデルへのルーティング指定が自動付与されます。高アクセスレベルでの実行時は、LLM が書き込んだ新規セルが `iAutoMarkNewCellsConfidential` により自動的に機密マークされます。

### アクセスレベル対応フォールバックルーティング

`iResolveAccessLevel` による三段階ルーティングを実装しました:
1. Claude Code（claudecode プロバイダー）が対応可能 → Claude Code 経由
2. Claude Code が対応不可だがフォールバックモデルに対応可能なものがある → フォールバックモデルへ直接ルーティング
3. どのモデルも対応不可 → エラー表示

フォールバック時も `NBAccess`NBGetAvailableFallbackModels` でアクセスレベルに基づくフィルタリングが行われます。

### パッケージ更新排他ロック

`$iPackageUpdateLocks` による排他ロック機構を追加しました。同一パッケージの並列更新を防止し、ロック中のパッケージに対する更新要求は警告を表示してスキップします。コールバック完了時にロックは自動解放されます。

### ClaudeEval 再帰深度制限

`$ClaudeEvalMaxDepth`（デフォルト: 5）を追加しました。ClaudeEval がコード内でさらに ClaudeEval/ContinueEval を生成する連鎖呼び出しの上限を制御します。0 で再帰禁止、値を大きくすると多段階の自動タスク連鎖が可能です。

### フォールバックモデル NBAccess 同期

`$ClaudeFallbackModels` の値がパッケージロード時に `NBAccess`NBSetFallbackModels` へ自動同期されるようになりました。これにより NBAccess 側のプロバイダー情報やアクセスレベル判定が常に最新の状態を反映します。

## 動作要件

| 項目 | バージョン |
|------|-----------|
| Mathematica | 13.0 以上（14.x 推奨） |
| Node.js | 18 以上 |
| Claude Code CLI | 最新版 |
| OS | Windows 11 |

## インストール

### 1. 外部ツールのインストール

[Node.js 公式サイト](https://nodejs.org/)から LTS 版をインストールした後、Claude Code CLI をインストールします。

```
npm install -g @anthropic-ai/claude-code
claude auth login
```

### 2. パッケージの配置

以下のファイルを `$packageDirectory` に配置してください。

| ファイル | 説明 |
|---------|------|
| `claudecode.wl` | 本体 |
| `NBAccess.wl` | ノートブック読み書き・プライバシー管理（[GitHub](https://github.com/transreal/NBAccess)） |
| `github.wl` | GitHub REST API 連携（[GitHub](https://github.com/transreal/github)） |

### 3. パッケージの読み込み

```mathematica
AppendTo[$Path, $packageDirectory];
Block[{$CharacterEncoding = "UTF-8"},
  Needs["ClaudeCode`", "claudecode.wl"]];
```

初回ロード時に `node-pty` が未インストールの場合、自動で `npm install` が実行されます。

### 4. API キーの設定

Claude Code CLI の認証が完了していれば、追加の設定は不要です。フォールバック機能で外部 API を直接使う場合は `SystemCredential` に登録してください。

```mathematica
SystemCredential["ANTHROPIC_API_KEY"] = "sk-ant-...";
SystemCredential["OPENAI_API_KEY"] = "sk-...";   (* OpenAI フォールバック用 *)
```

## クイックスタート

```mathematica
(* 質問する *)
ClaudeQuery["Wolfram Language で連立方程式を解く方法を教えてください"]

(* コード生成・自動実行 *)
ClaudeEval["フィボナッチ数列の最初の10項をリストで返す関数"]

(* セッションを分けて作業 *)
CreateClaudeSession["analysis"]
ClaudeEval["analysis", "データの基本統計量を計算"]

(* パッケージの新規作成 *)
ClaudeCreatePackage["MyUtils", "リスト操作ユーティリティ"]

(* パッケージの更新 *)
ClaudeUpdatePackage["MyUtils", "sortByFrequency関数を追加"]

(* ドキュメント一式を自動生成 *)
ClaudeCreateDocumentation["MyUtils"]

(* パレット表示 *)
ShowClaudePalette[]
```

## 主要機能

### クエリ・コード生成

| 関数 | 説明 |
|------|------|
| `ClaudeQuery[prompt]` | Claude に質問し、マークダウン形式で回答を表示します |
| `ClaudeEval[task]` | コードを生成・表示し、自動実行します |
| `ContinueEval[instruction]` | セッションを継続して追加指示を出します |
| `ClaudeMath[task]` | Mathematica コード生成に特化したプロンプトで呼び出します |

### セッション管理

| 関数 | 説明 |
|------|------|
| `CreateClaudeSession["name"]` | 名前付きセッションを作成します |
| `ClaudeRestoreSession["name"]` | セッションをリストアします |
| `ClaudeListSessions[]` | 全セッション一覧を表示します |
| `ClaudeShowHistory[]` | セッション履歴を表示します |
| `ClaudeCompactHistory[]` | 長い履歴を要約圧縮します |
| `ClaudeHistorySize[]` | セッション履歴のサイズを診断します |
| `ClaudeSessionStatus[]` | セッション状態を表示します |

### 機密データ管理

| 関数 | 説明 |
|------|------|
| `Confidential[expr]` | 式を評価し、セルを自動機密マークします |
| `NonConfidential[expr]` | 機密マークを明示的に解除して評価します |
| `MarkConfidential[]` | 現在のセルを機密マークします |
| `ScanConfidentialCells[]` | 機密変数参照セルを自動スキャンしてマークします |

### パッケージ管理

| 関数 | 説明 |
|------|------|
| `ClaudeCreatePackage[name, spec]` | 新しいパッケージを作成します |
| `ClaudeUpdatePackage[name, instruction]` | パッケージを安全に更新します（排他ロック・バックアップ付き） |
| `ContinueUpdate[instruction]` | 直前の更新結果を踏まえてバグ修正を継続します |
| `ClaudeRestorePackage[name]` | バックアップから復元します |
| `ClaudeBackupDataset[name]` | バックアップ履歴を Grid で表示します（スナップショット付き） |
| `ClaudeMigrateBackupHistory[name]` | 生バックアップを差分形式に変換して容量を削減します |

### ドキュメント生成

| 関数 | 説明 |
|------|------|
| `ClaudeCreateDocumentation["name"]` | 包括的ドキュメント一式を自動生成します |
| `ClaudeUpdateDocumentation["name", "指示"]` | 既存ドキュメントを部分更新します |

### デバッグ・レビュー

| 関数 | 説明 |
|------|------|
| `ClaudeDebug[code, error]` | デバッグ支援を非同期で求めます |
| `ClaudeReview[code]` | コードレビューを非同期実行します |
| `ClaudeSpec["task"]` | ノートブック内容からプログラム仕様を生成します |

### ディレクティブ管理

| 関数 | 説明 |
|------|------|
| `ClaudeAddDirective[target, desc]` | CLAUDE.md やスキルにディレクティブを追加します |
| `ClaudeUpdateDirective[text]` | テキストを解釈し適切なファイルに反映します |
| `ClaudeListDirectives[]` | 全ディレクティブの一覧を表示します |
| `ClaudeDirectiveBackupDataset[]` | ディレクティブ更新履歴を表示します（スナップショット付き） |

### Web 検索・分離検証・その他

| 関数 | 説明 |
|------|------|
| `ClaudeWebSearch[query]` | Web 検索を実行して結果をテキストで返します |
| `ClaudeWebFetch[url]` | URL の内容を取得・要約します |
| `ClaudeCheckSeparation[target]` | NBAccess 分離原則の違反をチェックします |
| `ClaudeFixSeparation[target]` | 分離違反を自動修正します |
| `ClaudeStatus[]` | 実行中タスクのリアルタイム状態を表示します |
| `ShowClaudePalette[]` | 操作パレットを表示します |

### 主要な設定変数

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `$ClaudeModel` | `""` | 使用モデル（空文字は CLI デフォルト） |
| `$ClaudePrivateModel` | `{}` | 秘密データ処理用ローカルモデル |
| `$ClaudeTimeout` | `1200` | タイムアウト秒数 |
| `$ClaudeWorkingDirectory` | `~/Claude Working` | 作業ディレクトリ |
| `$ClaudeFallbackModels` | `{{"anthropic","claude-opus-4-6"},{"openai","gpt-5"}}` | フォールバックモデル優先順位 |
| `$ClaudeEvalMaxDepth` | `5` | ClaudeEval 再帰深度上限 |
| `$ClaudeAccessibleDirs` | `{$packageDirectory}` | Read 許可追加ディレクトリ |

## ドキュメント

| ドキュメント | 内容 |
|-------------|------|
| [セットアップガイド](docs/setup.md) | インストール・初期設定の詳細 |
| [API リファレンス](docs/api.md) | 全関数・オプション・使用例 |

## 依存パッケージ

- [NBAccess](https://github.com/transreal/NBAccess) — ノートブックのセル読み書き・プライバシー管理
- [github](https://github.com/transreal/github) (`GitHubREST`) — GitHub REST API 連携・パッケージ管理

## 免責事項

- 本パッケージは Claude Code CLI を Mathematica から呼び出すためのインターフェースです。LLM の出力内容の正確性は保証されません。
- 生成されたコードは必ず内容を確認してから使用してください。
- API の利用には各プロバイダーの利用規約が適用されます。
- 機密データの取り扱いについては、`Confidential`/`AutoPrivate` 機能を活用し、適切なアクセスレベルを設定してください。ただし、完全な情報漏洩防止を保証するものではありません。

## ライセンス

MIT License

Copyright (c) 2025 transreal

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.