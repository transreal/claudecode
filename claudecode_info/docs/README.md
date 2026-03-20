# claudecode

Mathematica ノートブックから Claude Code CLI を呼び出し、コード生成・デバッグ・パッケージ管理・ドキュメント生成・AI画像/音声生成を対話的に行うパッケージです。

## 設計思想と実装の概要

claudecode は、Mathematica のノートブック環境と Claude Code CLI をシームレスに統合することを目的として設計されています。ユーザーは自然言語でタスクを記述するだけで、Mathematica コードの生成・実行・デバッグ・レビューを一貫したワークフローの中で完結できます。

本パッケージの中核となる設計思想は以下の点です。

**ノートブック中心のコンテキスト共有**: ClaudeEval や ClaudeQuery を呼び出す際、ノートブック内のセル履歴（入力・出力・エラーメッセージ）が自動的に収集され、Claude へのプロンプトに組み込まれます。これにより、ユーザーが手動でコードを貼り付ける必要がなく、Claude は現在の作業状態を正確に把握した上で応答を生成します。コンテキスト収集は [NBAccess](https://github.com/transreal/NBAccess) パッケージに委譲されており、セルの読み書き・プライバシー管理・変数追跡といった低レベル操作は分離されています。

**プライバシーファースト設計**: API キーや個人情報を扱うセルは `Confidential` ラッパーや `MarkConfidential` によって機密マークされ、以降の Claude プロンプトから自動的に除外されます。CellEpilog を利用した第1層の伝播機構により、機密変数を参照する下流のセルも自動検出・マーキングされます。さらに LLM 送信直前には全ノートブックを走査する精密チェック（第2層）を実行し、別ノートブック経由の秘密依存変数も検出します。`AutoPrivate` オプションにより、秘密データの処理をローカルモデルへ自動ルーティングすることも可能です。`NonConfidential` で明示的に公開指定することもでき、きめ細かなプライバシー制御を実現しています。

**セッションによる会話の継続性**: セッション機構により、複数回のやり取りにわたって会話履歴を保持します。セッションはノートブックの TaggingRules に永続化されるため、ノートブックを閉じて再度開いた後でも会話を再開できます。履歴が長くなった場合はエントリ数ベースとサイズベースの二重チェックにより自動または手動でコンパクションが行われ、トークン消費を抑制します。名前付きセッションの作成・継承・復元・削除が可能で、複数の独立したタスクを並行して進められます。

**安全なパッケージ更新と差分ベースバックアップ**: パッケージの更新は `ClaudeUpdatePackage` を通じて行われ、事前バックアップの自動作成、LLM レスポンスの安全なマージ検証、排他ロックによる並列更新の防止、更新後の再ロードまでを一貫して管理します。バックアップシステムは `SequenceAlignment` ベースの差分保存を採用し、`.cz`（ベースライン）・`.cdiff`（差分）・`.unchanged`（参照）の3形式でストレージ消費を大幅に削減します。差分チェーンの中間ノードを削除する際も依存関係を自動解決し、復元不能になることを防止します。ディレクティブファイルの書き込みには、サイズ退行・タイトル整合性・スキル名保持を検証するガード機構 (`iSafeWriteDirective`) が組み込まれています。

実装面では、Claude Code CLI をバックエンドとして利用し、`--output-format stream-json` モードでリアルタイムにストリーミング出力を解析します。問い合わせ中は経過時間に加え、現在の状態（思考中・テキスト生成中・ツール実行中）やフラグメント数をリアルタイムで表示します。エラー出力は stderr 経由で分離処理され、stdout の JSON ストリームと干渉しない設計になっています。ファイルパス操作には `FileNameJoin` を一貫して使用し、OS 非依存のパス構築を徹底しています。

作業ディレクトリ (`$ClaudeWorkingDirectory`) 配下の CLAUDE.md やディレクティブ (rules/skills) が Claude Code に自動的に読み込まれ、プロジェクト固有のガイドラインを反映した応答が得られます。ノートブックディレクトリごとに `.claude-project/` フォルダを作成してプロジェクト固有のルール・スキルを定義でき、メインのディレクティブと自動マージされます。Claude Code CLI が利用できない場合のフォールバック機構として、Anthropic API や OpenAI API への直接呼び出しに加え、LM Studio 等のローカル LLM サーバーへの接続もサポートしています。フォールバックモデルは `$ClaudeFallbackModels` で優先順位付きで設定でき、`{provider, model, url}` の3要素形式でカスタム URL を指定できます。

AI 生成 API として、OpenAI Images API による画像生成（`ClaudeImageGenerate`）と OpenAI TTS API による音声生成（`ClaudeSpeech`）をノートブックから直接利用できます。ClaudeQuery のリッチレスポンスモードでは、ユーザーの依頼に応じてこれらの API を自動的に呼び出します。

パッケージ管理機能 (`ClaudeUpdatePackage`, `ClaudeRestorePackage`) では、既存の .wl パッケージを Claude の支援で更新し、差分ベースの自動バックアップにより安全なイテレーションを実現します。既存の生バックアップは `ClaudeMigrateBackupHistory` で差分形式に一括変換できます。ドキュメント生成機能 (`ClaudeCreateDocumentation`, `ClaudeUpdateDocumentation`) では、ソースコードから API リファレンス・使用例・セットアップガイドなどの文書一式を自動生成します。ドキュメント更新時はノートブックの現在のコンテキストも参照でき、「上で議論された内容を反映して」といった自然な指示が可能です。

外部ファイルのアタッチメント機構や Web 検索・取得機能により、ノートブック外の情報源も活用できます。日本語の励まし表現（「死ぬ気で考えろ」「じっくり考えて」等）は自動的に think トリガーワード（ultrathink/think hard/think）に変換され、Claude の思考予算を適切に設定します。多言語対応として、`$Language` に基づいてプロンプト内の言語指定を動的に生成します。

## 詳細説明

### 動作環境

| 項目 | バージョン |
|------|-----------|
| Mathematica | 13.0 以上（14.x 推奨） |
| Node.js | 18 以上 |
| Claude Code CLI | 最新版 |
| OS | Windows 11（macOS/Linux ではパス区切りやシェルコマンドを適宜読み替えてください） |

### インストール

#### 1. 外部ツールのインストール

Node.js の LTS 版を [公式サイト](https://nodejs.org/) からインストールしてください。

```
node --version
```

Claude Code CLI をインストールし、認証を行います。

```
npm install -g @anthropic-ai/claude-code
claude auth login
```

#### 2. パッケージファイルの配置

以下のファイルをすべて `$packageDirectory` に配置してください。

| ファイル | 説明 |
|---------|------|
| `claudecode.wl` | 本体 |
| `NBAccess.wl` | ノートブック読み書き・プライバシー管理（[GitHub](https://github.com/transreal/NBAccess)） |
| `github.wl` | GitHub REST API 連携（[GitHub](https://github.com/transreal/github)） |

#### 3. パッケージの読み込み

`$Path` には `$packageDirectory` 自体を追加します。claudecode を使用する場合、`$Path` は自動的に設定されます。

```mathematica
AppendTo[$Path, $packageDirectory];

Block[{$CharacterEncoding = "UTF-8"},
  Needs["ClaudeCode`", "claudecode.wl"]];
```

ファイル名のみの形式 `"claudecode.wl"` は、`$packageDirectory` が `$Path` に含まれているため動作します。

初回ロード時に `node-pty` が未インストールの場合、自動で `npm install` が実行されます。

#### 4. API キーの設定

Claude Code CLI の認証が完了していれば、追加の設定は不要です。フォールバック機能で API を直接使う場合は `SystemCredential` に登録してください。

```mathematica
SystemCredential["ANTHROPIC_API_KEY"] = "sk-ant-...";
(* OpenAI フォールバック / 画像生成 / 音声生成を使う場合 *)
SystemCredential["OPENAI_API_KEY"] = "sk-...";
```

LM Studio 等のローカル LLM を使用する場合は、API キーは不要です（`$ClaudeFallbackModels` にエンドポイント URL を指定します）。

### クイックスタート

```mathematica
(* パッケージの読み込み *)
AppendTo[$Path, $packageDirectory];
Block[{$CharacterEncoding = "UTF-8"},
  Needs["ClaudeCode`", "claudecode.wl"]];

(* 基本的な問い合わせ *)
ClaudeQuery["Mathematica で行列の固有値を求める方法を説明してください"]

(* コード生成・自動実行 *)
ClaudeEval["フィボナッチ数列の最初の10項をリストで返す関数"]

(* エラー修正の継続 *)
ContinueEval["日本語ラベルが文字化けしています。フォント指定を追加して"]

(* 機密データの保護 *)
apiKey = Confidential[SystemCredential["MyAPIKey"]]

(* AI 画像生成 *)
ClaudeImageGenerate["桜の満開の写真、フォトリアル"]

(* AI 音声生成 *)
ClaudeSpeech["こんにちは、世界"]

(* 参考資料のアタッチ *)
ClaudeAttach["spec.pdf"]
ClaudeEval["添付した仕様書に従ってコードを書いて"]

(* セッション状態の確認 *)
ClaudeSessionStatus[]

(* 実行中タスクのリアルタイム状態表示 *)
ClaudeStatus[]

(* 履歴サイズ診断 *)
ClaudeHistorySize[]

(* LM Studio のローカルモデルを使用 *)
ClaudeEval["階乗を計算して",
  Model -> {"lmstudio", "openai/gpt-oss-20b", "http://192.168.2.106:1234"}]

(* プロジェクト固有ディレクティブの初期化 *)
ClaudeInitProject[]

(* パレット表示 *)
ShowClaudePalette[]
```

#### 主要な設定変数

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `$ClaudeModel` | `""` | Claude CLI に渡すモデル名。空文字は CLI デフォルト |
| `$ClaudeTimeout` | `1200` | タイムアウト秒数 |
| `$ClaudeWorkingDirectory` | `FileNameJoin[{$HomeDirectory, "Claude Working"}]` | 作業ディレクトリ |
| `$ClaudeAccessibleDirs` | `{$packageDirectory}` | Claude Code に Read 許可する追加ディレクトリ |
| `$ClaudeFallbackModels` | `{{"anthropic","claude-opus-4-6"},{"openai","gpt-5"}}` | フォールバックモデル優先順位。`{"lmstudio","modelName","http://host:port"}` 形式でローカル LLM も指定可能 |
| `$ClaudePrivateModel` | `{}` | 秘密データ処理用のローカルモデル指定 |
| `$ClaudeImageModels` | `{{"openai","gpt-image-1"},{"openai","dall-e-3"}}` | 画像生成モデルのリスト |
| `$ClaudeTTSModels` | `{{"openai","tts-1-hd"},{"openai","tts-1"}}` | 音声生成モデルのリスト |

### 主な機能

**クエリ・コード生成**
- `ClaudeQuery[prompt]` — Claude に問い合わせ、テキスト応答を返す（非同期）。リッチレスポンスモードでは安全なコードブロック（プロット・計算等）を自動評価
- `ClaudeMath[task]` — Mathematica コード生成に特化したクエリ
- `ClaudeEval[task]` — コードを非同期生成し、ノートブックに挿入・自動実行。`Fallback`・`WebFetch`・`Model`・`AutoPrivate` オプション対応
- `ContinueEval[instruction]` — 直前の ClaudeEval の続きを実行。エラー修正に便利
- `ClaudeSpec[task]` — ノートブック内容からプログラムの仕様書を生成
- `ClaudeExtractCode[response]` / `ClaudeExtractAllCode[response]` — 応答からコードブロックを抽出

**AI 画像・音声生成**
- `ClaudeImageGenerate[prompt]` — OpenAI Images API で画像を生成し Image オブジェクトで返す。`"Model"` オプションで `"gpt-image-1"`（デフォルト）または `"dall-e-3"` を選択可能
- `ClaudeSpeech[text]` — OpenAI TTS API で音声を生成し Audio オブジェクトで返す。`"Voice"` オプションで声質を選択可能

**タスク状態監視**
- `ClaudeStatus[]` — 実行中の全 Claude タスクのリアルタイム状態を表示

**セッション管理**
- `CreateClaudeSession["name"]` — 名前付きセッションの作成（履歴の継承・独立が選択可能）
- `ClaudeRestoreSession["name"]` — 保存済みセッションの復元
- `ClaudeListSessions[]` — 全セッション一覧
- `ClaudeDeleteSession["name"]` — セッション削除
- `ClaudeShowHistory[]` — 会話履歴の表示
- `ClaudeCompactHistory[]` — 履歴の手動コンパクション
- `ClaudeHistorySize[]` — 履歴サイズ診断
- `ClaudeSessionStatus[]` — セッション状態の確認

**アタッチメント**
- `ClaudeAttach[path]` — セッションに参考資料を添付（PDF、.wl 等）
- `ClaudeDetach[path]` — 添付を解除
- `ClaudeAttachments[]` — アタッチメント一覧

**機密データ管理**
- `Confidential[expr]` — 式を評価し、そのセルを機密マーク（プロンプトから自動除外）
- `NonConfidential[expr]` — 機密依存でも明示的に公開扱い
- `MarkConfidential[]` / `UnmarkConfidential[]` — セルの機密マーク操作
- `ScanConfidentialCells[]` — 機密変数参照セルの自動検出・マーキング

**デバッグ・レビュー**
- `ClaudeDebug[codeOrFile, errorMsg]` — デバッグ支援（非同期）
- `ClaudeReview[codeOrFile]` — コードレビュー（非同期、長大ファイルは自動チャンク分割）

**パッケージ管理**
- `ClaudeUpdatePackage[name, prompt]` — .wl パッケージを Claude 支援で更新（差分ベースバックアップ付き・排他ロック）
- `ContinueUpdate[instruction]` — 直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を継続
- `ClaudeRestorePackage[name]` — 直前のバックアップから復元
- `ClaudeBackupDataset[name]` — バックアップ履歴の表示・復元・削除（ローカル最新版スナップショット付き）
- `ClaudeMigrateBackupHistory[name]` — 生バックアップを差分形式に一括変換（`DryRun -> True` で見積もり可能）
- `ClaudeConvertToPaclet[name]` — .wl パッケージを Paclet 形式に変換
- `ClaudeCreatePackage[name, prompt]` — 新規パッケージの作成

**ドキュメント生成**
- `ClaudeCreateDocumentation["name"]` — パッケージの文書一式を自動生成
- `ClaudeUpdateDocumentation["name", "指示"]` — 既存ドキュメントの更新。ノートブックのコンテキストも参照可能

**ディレクティブ管理**
- `ClaudeAddDirective[target, description]` — CLAUDE.md やスキルファイルにディレクティブを追加。`Scope -> "Local"` でプロジェクト固有ディレクティブにも対応
- `ClaudeRestoreDirective[target]` — 直前のバックアップを復元
- `ClaudeUpdateDirective[]` — ソースコードと Claude Directives の整合性をチェックし、不整合を自動修正する
- `ClaudeUpdateDirective[text]` — テキストの内容を Claude で解釈し、CLAUDE.md / rules / skills の適切なファイルに反映する
- `ClaudeListDirectives[]` — 全ディレクティブ一覧
- `ClaudeDirectiveBackupDataset[]` — ディレクティブ更新履歴を Review/Pull/Delete ボタン付き Grid で表示
- `ClaudeSyncDirectives[dir]` — 外部ディレクトリから Claude Directives へファイルを同期
- `ClaudeInitProject[]` — ノートブックディレクトリにプロジェクト固有ディレクティブの雛形を作成
- `ClaudePromoteProjectDirectives[]` — ローカルディレクティブをグローバルに昇格

**Web 検索・取得**
- `ClaudeWebSearch[query]` — Web 検索を実行し結果をテキストで返す
- `ClaudeWebFetch[url]` — URL の内容を取得・要約

**分離検証**
- `ClaudeCheckSeparation[target]` — NBAccess の分離原則への違反箇所を検出（静的パターン走査 + LLM 判定の二段階検査）
- `ClaudeFixSeparation[target]` — 分離違反を修正

**ユーティリティ**
- `ShowClaudePalette[]` — 操作用パレットの表示
- `ClaudeCommand["/command"]` — Claude Code CLI コマンドの直接実行
- `ClaudeQueryShowContext[]` — 次回送信されるノートブックコンテキストの確認（デバッグ用）
- `ClaudeShowAccessConfig[]` — ファイルアクセス設定の確認（デバッグ用）

### LM Studio 対応

ローカルで動作する LLM サーバー（LM Studio 等）をフォールバックモデルとして使用できます。API キーは不要で、OpenAI 互換の Chat Completions API エンドポイントに接続します。

```mathematica
(* フォールバックモデルにローカルモデルを追加 *)
$ClaudeFallbackModels = {
  {"anthropic", "claude-opus-4-6"},
  {"openai", "gpt-5"},
  {"lmstudio", "openai/gpt-oss-20b", "http://192.168.2.106:1234"}
};

(* Fallback で自動的に使われる *)
ClaudeEval["階乗を計算して", Fallback -> True]

(* Model オプションで直接指定 *)
ClaudeEval["1から10までのフィボナッチ数を計算して",
  Model -> {"lmstudio", "openai/gpt-oss-20b", "http://192.168.2.106:1234"}]
```

`$ClaudeFallbackModels` の各エントリは `{provider, modelName}` または `{provider, modelName, url}` の形式です。`"lmstudio"` プロバイダーを指定すると、指定 URL（デフォルト `http://localhost:1234`）の `/v1/chat/completions` エンドポイントに接続します。

### ドキュメント一覧

| ファイル | 内容 |
|---------|------|
| `api.md` | API リファレンス（全関数・変数・オプションの詳細仕様） |
| `setup.md` | セットアップガイド（インストール手順・トラブルシューティング） |
| `user_manual.md` | ユーザーマニュアル（機能別の詳細な使い方） |
| `examples/example.md` | 使用例集（代表的なユースケースとコード例） |

## 使用例・デモ

### 動画

- [claudecode デモ動画 — Mathematica ノートブックから Claude Code を操作する様子を紹介（YouTube）](https://www.youtube.com/watch?v=_Lc-XtBPkl8&t=919s)

## 免責事項

本ソフトウェアは "as is"（現状有姿）で提供されており、明示・黙示を問わずいかなる保証もありません。
本ソフトウェアの使用または使用不能から生じるいかなる損害についても責任を負いません。
今後の動作保証のための更新が行われるとは限りません。
本ソフトウェアとドキュメントはほぼすべてが生成AIによって生成されたものです。
Windows 11上での実行を想定しており、MacOS, LinuxのMathematicaでの動作検証は一切していません(生成AIの処理で対応可能と想定されます)。

## ライセンス

```
MIT License

Copyright (c) 2026 Katsunobu Imai

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.