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

また、以下はオプションの依存パッケージです：

- **[cuda](https://github.com/transreal/cuda)** パッケージ（CUDA 関連タスク用）― CUDA を必要とするプロンプトを送信すると自動的に検出・ロードが試みられます。`cuda.wl` が `$packageDirectory` に存在しない場合は警告が表示されます。
- **[ClaudeRuntime](https://github.com/transreal/ClaudeRuntime)** パッケージ（永続ランタイム機能用）― `$UseClaudeRuntime = True` に設定した場合にのみ使用されます。未インストールでも従来の ClaudeEval/ClaudeQuery ワークフローは影響を受けません。
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

初回読み込み時に node-pty が自動的にインストールされます。パッケージリロード時には旧バージョンの内部タスクが自動的に停止されるため、安全に再読み込みできます。

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
$ClaudeModel = "claude-opus-4-6"

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

`$UseClaudeRuntime = False`（デフォルト）の場合、ClaudeRuntime パッケージがインストールされていなくても claudecode の全機能を利用できます。

### 5. フォールバックモデルの設定（オプション）

Claude Code が利用できない場合のバックアップとして、他の LLM を設定できます：

```mathematica
(* フォールバックモデルの設定例 *)
$ClaudeFallbackModels = {
  {"anthropic", "claude-opus-4-6"},
  {"openai", "gpt-4"},
  {"lmstudio", "local-model", "http://127.0.0.1:1234"}
}
```

### 6. ドキュメント生成設定

```mathematica
(* ドキュメント生成用モデル *)
$ClaudeDocModel = "claude-sonnet-4-20250514"

(* リトライ設定 *)
$ClaudeDocMaxRetries = 3
$ClaudeDocRetryDelay = 60

(* チャンク分割の最大文字数 *)
$ClaudeDocMaxChunkChars = 60000
```

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

### 5. ClaudeRuntime の動作確認（オプション）

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

共有ポーリングタスク機構を使用して内部タスクが一元管理されています。タスクが応答しない場合は `ClaudeAbort[]` で強制停止できます。パッケージを再読み込みすると旧タスクは自動的に停止します：

```mathematica
(* 全タスクの強制停止 *)
ClaudeAbort[]

(* パッケージ再読み込みによるクリーンアップ *)
Get["claudecode.wl"]
```

#### 8. ClaudeRuntime が見つからない・ロードできない

`$UseClaudeRuntime = True` に設定した状態で ClaudeRuntime が見つからない場合、警告が表示されますが claudecode 本体は引き続き動作します：

```mathematica
(* ClaudeRuntime パッケージの存在確認 *)
FileExistsQ[FileNameJoin[{$packageDirectory, "ClaudeRuntime", "Kernel", "init.wl"}]]

(* ClaudeRuntime を使用しない場合は False に設定 *)
$UseClaudeRuntime = False
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

### 依存パッケージ API の自動注入

`ClaudeUpdatePackage` 実行時、プロンプト内に登場する依存パッケージ名を検出し、そのパッケージの `api.md` を自動的にコンテキストに注入します。これにより、パッケージ境界を越えた関数呼び出しの原因追跡が可能になります。この機能は設定不要で自動的に動作します。

### 検証テストの自動生成

`ClaudeUpdatePackage` 実行時、LLM が更新後のコードに対する検証テストを自動生成します。テストは `===BEGIN_TESTS===` / `===END_TESTS===` マーカーで囲まれた形式で返され、コメントラベル付きのブロックに分割されてマージ後に自動実行されます。各ブロックは `(* コメント *)` の直後に Boolean 式が来る形式を想定しており、テスト結果（合否件数）はノートブックに表示されます。

### ターゲット関数の自動推定

`ClaudeUpdatePackage` はプロンプト内の複合語から更新対象関数を2フェーズで自動推定します：

- **フェーズ 1（本体マッチ）**: 4文字以上の漢字・カタカナ連続列や5文字以上の英語キーワードをプロンプトから抽出し、関数本体にその複合語が含まれる関数を検出します。2文字以下の短い関数名や、3文字以下の汎用的すぎる語（ボタン、削除、展開 等）は誤マッチを防ぐため除外されます。
- **フェーズ 2（usage bi-gram フォールバック）**: フェーズ 1 で対象関数が見つからない場合、usage 文字列への bi-gram マッチにフォールバックします。

推定された関数数が40を超える場合は複合語が汎用的すぎると判断し、パッケージ全体を送信するフォールバックに切り替わります。

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
$ClaudeTestModel = "claude-sonnet-4-20250514"
```

## 次のステップ

セットアップが完了したら、以下のドキュメントを参照してください：

- **api.md** - 全関数の詳細なリファレンス
- **user_manual.md** - 実用的な使用方法とワークフロー（ClaudeRuntime・ClaudeTestKit の活用方法を含む）
- **README.md** - パッケージの概要と基本情報（ClaudeRuntime・ClaudeTestKit の位置付けを含む）

より詳細な使用方法については：

```mathematica
(* パレットの表示 *)
ShowClaudePalette[]

(* ヘルプ情報 *)
?ClaudeEval
?ClaudeUpdatePackage
?ContinueUpdate
?$ClaudePackageKeywordMap
?$LLMGraphMaxConcurrency
?$UseClaudeRuntime
?$ClaudeLastRuntimeId