# claudecode ユーザーマニュアル

Mathematica ノートブックから [Claude Code](https://github.com/transreal/claudecode) CLI を呼び出し、コード生成・デバッグ・パッケージ管理・ドキュメント生成を行うパッケージです。

セットアップ手順は別途 `setup.md` をご参照ください。

---

## 目次

1. [基本クエリ](#基本クエリ)
2. [コード生成・実行](#コード生成実行)
3. [セッション管理](#セッション管理)
4. [アタッチメント](#アタッチメント)
5. [デバッグ・レビュー](#デバッグレビュー)
6. [パッケージ管理](#パッケージ管理)
7. [ドキュメント生成](#ドキュメント生成)
8. [ディレクティブ管理](#ディレクティブ管理)
9. [機密データ管理](#機密データ管理)
10. [Web 検索・取得](#web-検索取得)
11. [ユーティリティ](#ユーティリティ)
12. [設定変数](#設定変数)

---

## 基本クエリ

### ClaudeQuery

テキスト応答を返す同期クエリです。コードブロックは含まれません。

```mathematica
ClaudeQuery["Mathematica で行列の固有値を求める方法を説明してください"]
ClaudeQuery[session, "前回の結果をもう少し詳しく説明してください"]
```

### ClaudeMath

Mathematica コード生成に特化したクエリです。応答は `` ```mathematica `` ブロックで返ります。

```mathematica
response = ClaudeMath["フィボナッチ数列の最初の20項を計算するコード"]
```

### ClaudeExtractCode / ClaudeExtractAllCode

応答文字列からコードブロックを抽出します。

```mathematica
code = ClaudeExtractCode[response]     (* 最初の1ブロック *)
codes = ClaudeExtractAllCode[response]  (* 全ブロックのリスト *)
```

---

## コード生成・実行

### ClaudeEval

コードを非同期で生成し、ノートブックに Input セルとして挿入・実行します。

```mathematica
ClaudeEval["素数を100個リストアップするコード"]
ClaudeEval[{"この Dataset を可視化して", myDataset}]
ClaudeEval[session, "前回のコードにエラーハンドリングを追加"]
```

**主なオプション:**

| オプション | デフォルト | 説明 |
|---|---|---|
| `AutoEvaluate` | `True` | 生成セルを自動実行するか |
| `StartTime` | `Now` | 実行開始時刻（遅延実行用） |
| `Fallback` | `False` | Claude Code 不可時に API 直接呼び出し |
| `WebFetch` | `Automatic` | Web 検索の利用（`True`/`False`/`Automatic`） |

```mathematica
ClaudeEval["レポート生成", StartTime -> Now + Quantity[1, "Hours"]]
ClaudeEval["最新の為替レートを取得", WebFetch -> True]
```

### ContinueEval

直前の ClaudeEval の続きを実行します。エラー発生時の修正に便利です。

```mathematica
ContinueEval[]                          (* "エラーを修正してください" で継続 *)
ContinueEval["グラフの色を変更して"]      (* 追加指示で継続 *)
ContinueEval[session, "次のステップへ"]   (* セッション指定 *)
```

### ClaudeSpec

ノートブック内容からプログラムの仕様書を生成します。パレットからセル選択で呼び出すことも可能です。

```mathematica
ClaudeSpec["データ分析パイプラインの仕様を生成"]
ClaudeSpec[{"画像認識タスクの仕様", inputImage}]
```

---

## セッション管理

セッションは会話履歴を保持する単位です。ノートブックの TaggingRules に永続化されます。

### CreateClaudeSession

```mathematica
session = CreateClaudeSession["分析タスク"]       (* 名前付きセッション *)
session = CreateClaudeSession[]                   (* デフォルト履歴を継承 *)
session = CreateClaudeSession[Inherit -> False]   (* 独立セッション *)
session = CreateClaudeSession[oldSession]         (* 既存セッションの履歴を継承 *)
```

### ClaudeRestoreSession

保存済みセッションを復元します。

```mathematica
session = ClaudeRestoreSession["分析タスク"]
session = ClaudeRestoreSession[]   (* デフォルトセッション *)
```

### ClaudeListSessions / ClaudeDeleteSession / ClaudeShowHistory

```mathematica
ClaudeListSessions[]                        (* 全セッション一覧 *)
ClaudeDeleteSession["分析タスク"]             (* セッション削除 *)
ClaudeDeleteSession["分析タスク", "All"]      (* 全履歴も削除 *)
ClaudeShowHistory[]                          (* デフォルトセッションの履歴 *)
ClaudeShowHistory[session]                   (* 指定セッションの履歴 *)
```

### ClaudeCompactHistory

履歴が長くなった場合に手動で圧縮します（通常は自動実行されます）。

```mathematica
ClaudeCompactHistory[]
ClaudeCompactHistory["分析タスク"]
```

---

## アタッチメント

セッションに参考資料ファイルをアタッチすると、ClaudeQuery/ClaudeEval 時に自動で読み込まれます。

```mathematica
ClaudeAttach["reference.pdf"]              (* デフォルトセッションにアタッチ *)
ClaudeAttach[session, "data_spec.md"]      (* 指定セッションにアタッチ *)
ClaudeDetach["reference.pdf"]              (* デタッチ *)
ClaudeAttachments[]                        (* 一覧表示 *)
ClearAttachments[]                         (* 全アタッチメントをクリア *)
```

---

## デバッグ・レビュー

### ClaudeDebug

コードまたはファイルのデバッグ支援を非同期で行います。

```mathematica
ClaudeDebug["Sort[{3,1,2}]", "期待した結果と異なる"]
ClaudeDebug["mypackage.wl", "関数 foo がエラーを返す"]
```

### ClaudeReview / ClaudeReviewChunked

コードレビューを非同期で実行します。30000 文字超のコードは自動でチャンク分割されます。

```mathematica
ClaudeReview["mypackage.wl"]
ClaudeReviewChunked["large_package.wl"]   (* 明示的にチャンク分割 *)
```

---

## パッケージ管理

### ClaudeUpdatePackage

`$packageDirectory` 内のパッケージを Claude の支援でアップデートします。自動バックアップ付きです。

```mathematica
ClaudeUpdatePackage["mypackage", "新しいエクスポート関数を追加"]
ClaudeUpdatePackage["mypackage", {"画像を参考に修正して", refImage}]
ClaudeUpdatePackage["mypackage", "修正指示", StartTime -> Now + Quantity[1, "Hours"]]
```

### ClaudeRestorePackage

直前のバックアップからパッケージを復元します。

```mathematica
ClaudeRestorePackage["mypackage"]
```

### ClaudeCreatePackage

新規パッケージを作成して `$packageDirectory` に保存します。

```mathematica
ClaudeCreatePackage["utils", "リスト操作のユーティリティ関数を作成"]
```

### ClaudeUpdatePackageHistory / ClaudeBackupDataset

更新履歴の確認とバックアップの管理を行います。

```mathematica
ClaudeUpdatePackageHistory[]               (* 全パッケージの更新履歴 *)
ClaudeUpdatePackageHistory["mypackage"]    (* 指定パッケージの履歴 *)
ClaudeBackupDataset["mypackage"]           (* Review/Pull/Delete ボタン付き一覧 *)
ClaudeBackupDataset[]                      (* 全パッケージのバックアップ一覧 *)
```

### ClaudeConvertToPaclet

単一 .wl ファイルを Paclet ディレクトリ構造に変換します。

```mathematica
ClaudeConvertToPaclet["mypackage"]
```

---

## ドキュメント生成

### ClaudeCreateDocumentation

パッケージのドキュメント一式（setup.md, user_manual.md, api.md, README.md 等）を自動生成します。

```mathematica
ClaudeCreateDocumentation["mypackage"]
ClaudeCreateDocumentation["mypackage", References -> {"https://example.com"}]
ClaudeCreateDocumentation["mypackage", Demos -> {"https://youtu.be/xxx"}]
ClaudeCreateDocumentation["mypackage", Disclaimer -> {"研究目的専用です"}]
```

### ClaudeUpdateDocumentation

既存ドキュメントを指示に従って更新します。ノートブックのコンテキストも参照可能です（「上で議論されている内容を反映して」など）。

```mathematica
ClaudeUpdateDocumentation["mypackage", "インストール手順に Windows 11 対応を追記"]
ClaudeUpdateDocumentation["mypackage", "api.md のみ更新して"]
```

引数なしで呼び出すと、前回のドキュメント更新以降のソースコード変更を自動検出して全ドキュメントを更新します。

```mathematica
ClaudeUpdateDocumentation["mypackage"]
```

---

## ディレクティブ管理

Claude Code の動作を制御する CLAUDE.md・rules・skills を管理します。

### ClaudeAddDirective / ClaudeRestoreDirective

```mathematica
ClaudeAddDirective["CLAUDE.md", "常に日本語で回答すること"]
ClaudeAddDirective["wolfram-general", "Module の代わりに With を優先する"]
ClaudeRestoreDirective["CLAUDE.md"]   (* 直前のバックアップに復元 *)
```

### ClaudeUpdateDirective

引数なしで呼び出すと、基盤パッケージ（claudecode.wl, github.wl, NBAccess.wl）のソースコードと CLAUDE.md・rules・skills の整合性をチェックし、不整合（存在しない関数名の参照、新しい関数・オプションの未記載など）を Claude が自動修正します。

```mathematica
ClaudeUpdateDirective[]
```

テキストを指定して呼び出すと、指示内容を Claude で解釈し、CLAUDE.md / rules / skills の適切なファイルに反映します。ノートブックのコンテキストも参照可能です（「上で議論されている内容を反映して」など）。

```mathematica
ClaudeUpdateDirective["エラーハンドリングのルールを追加"]
ClaudeUpdateDirective["上で議論したAPIの制約をskillsに追加して"]
```

### ClaudeListDirectives / ClaudeDirectiveBackupDataset

```mathematica
ClaudeListDirectives[]              (* CLAUDE.md と全スキルの一覧 *)
ClaudeDirectiveBackupDataset[]      (* 更新履歴を Review/Pull/Delete 付きで表示 *)
```

`ClaudeDirectiveBackupDataset[]` はディレクティブの更新履歴を表示します。履歴は `ClaudeUpdateDirective[text]` や `ClaudeAddDirective` の実行時に自動保存されます。ノートブックのコンテキストも参照可能です。

---

## 機密データ管理

機密マークされたセルは ClaudeEval/ClaudeQuery のプロンプトから自動除外されます。

```mathematica
MarkConfidential[]           (* 現在のセルを機密マーク *)
UnmarkConfidential[]         (* 機密マークを解除 *)
IsConfidential[]             (* 現在のセルが機密か確認 *)
```

### Confidential / NonConfidential

式レベルで機密制御を行います。

```mathematica
secretData = Confidential[Import["secret.xlsx", {"Dataset"}] // First]
summary = NonConfidential[Mean[secretData[All, "Score"]]]
```

### ScanConfidentialCells

ノートブック全体をスキャンし、機密変数を参照するセルを自動的に機密マークします。

```mathematica
ScanConfidentialCells[]
```

---

## Web 検索・取得

### ClaudeWebSearch

Anthropic API の web_search ツールを使用して Web 検索を実行します。

```mathematica
ClaudeWebSearch["Mathematica 14 新機能"]
```

### ClaudeWebFetch

指定 URL の内容を取得・要約します。

```mathematica
ClaudeWebFetch["https://example.com/docs"]
ClaudeWebFetch["https://example.com/data", "表形式のデータを抽出して"]
```

---

## ユーティリティ

### ClaudeCommand

Claude Code CLI のコマンドを直接実行します。

```mathematica
ClaudeCommand["/help"]
ClaudeCommand["/permissions"]
ClaudeCommand["config list"]
ClaudeCommand["--version"]
```

### ClaudeCheckSeparation / ClaudeFixSeparation

[NBAccess](https://github.com/transreal/NBAccess) パッケージとの分離原則の違反を検査・修正します。静的パターン走査（正規表現ベース）と LLM 判定の2段階で検出します。

```mathematica
ClaudeCheckSeparation["claudecode"]              (* 違反箇所をリストアップ *)
ClaudeFixSeparation["claudecode"]                (* 違反を修正 *)
ClaudeCheckSeparation["C:\\path\\to\\file.wl"]    (* ファイル指定も可能 *)
```

**検査対象の違反カテゴリ:**

| カテゴリ | 内容 |
|---|---|
| a | SystemCredential 直接利用 |
| b | CellObject 直接操作（NotebookWrite/NotebookRead/CellGroupData 直接構築） |
| c | CellEpilog/CellProlog/NotebookEventActions 直接操作 |
| d | NBAccess\`Private\` 関数呼び出し |
| e | NBAccess 公開グローバル直接更新 |
| f | EvaluationCell[]/CellPrint[]/SetSelectedNotebook[] 直接使用 |
| g | CurrentValue/SetOptions による属性直接アクセス |
| h | CellObject の公開 API・戻り値・状態保持への漏洩 |
| i | SelectionEvaluate/FrontEndTokenExecute 等 FE 状態操作 |
| j | NBAccess 公開グローバルの破壊的更新（AppendTo/AssociateTo 等） |

### ShowClaudePalette

Claude Code 操作用の GUI パレットを表示します。

```mathematica
ShowClaudePalette[]
```

### デバッグ用

```mathematica
ClaudeQueryShowContext[]     (* 次回送信されるノートブックコンテキストを確認 *)
ClaudeShowAccessConfig[]     (* ファイルアクセス設定を確認 *)
ClaudeSessionStatus[]        (* セッション状態の詳細表示 *)
```

---

## 設定変数

| 変数 | デフォルト | 説明 |
|---|---|---|
| `$ClaudeModel` | `""` (CLI デフォルト) | 使用する Claude モデル名 |
| `$ClaudeTimeout` | `1200` | タイムアウト秒数 |
| `$ClaudeWorkingDirectory` | `~/Claude Working` | Claude Code の作業ディレクトリ |
| `$ClaudeAccessibleDirs` | `{$packageDirectory}` | Read 許可する追加ディレクトリ |
| `$ClaudeFallbackModels` | `{{"anthropic","claude-opus-4-6"},{"openai","gpt-5"}}` | フォールバックモデルの優先順位 |
| `$ClaudeTestModel` | `$ClaudeModel` と同じ | 分離検証用モデル |
| `$ClaudeDocRetryDelay` | `60` | ドキュメント生成のリトライ待機秒数 |
| `$ClaudeDocMaxRetries` | `3` | ドキュメント生成の最大リトライ回数 |
| `$ClaudeDocMaxChunkChars` | `60000` | プロンプト中ソースの最大文字数 |

```mathematica
$ClaudeModel = "claude-sonnet-4-20250514";
$ClaudeTimeout = 900;
$ClaudeAccessibleDirs = {$packageDirectory, "F:\\Dropbox\\Mathematica"};
```

---

## 依存パッケージ

- [NBAccess](https://github.com/transreal/NBAccess) — ノートブック読み書き・プライバシー管理
- [github](https://github.com/transreal/github) — GitHub REST API 連携