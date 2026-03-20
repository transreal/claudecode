# claudecode 使用例集

このドキュメントでは、[claudecode](https://github.com/transreal/claudecode) パッケージの代表的な使用例を紹介します。
各関数の詳細な仕様については API リファレンスをご参照ください。

---

## 1. 基本的な問い合わせ（ClaudeQuery）

ノートブックのコンテキストを含めて Claude に質問します。

```mathematica
response = ClaudeQuery["この関数の計算量を教えてください"]
```

> `"この関数は O(n log n) の計算量です…"`

セッションを指定して履歴を引き継ぐこともできます。

```mathematica
session = CreateClaudeSession["分析用"];
ClaudeQuery[session, "前回の結果をもとに改善案を出してください"]
```

> `"前回の分析結果を踏まえると…"`

### リッチレスポンスモード

ClaudeQuery の応答にはコードブロックを含めることができます。安全なコード（プロット、計算など）は自動評価されます。

```mathematica
ClaudeQuery["sin(x) のグラフを描いて特徴を説明してください"]
```

> テキストの説明に加え、`Plot[Sin[x], ...]` のコードが自動挿入・実行されます。

### モデル・プライバシー指定

特定のモデルやプライバシーレベルを指定して問い合わせることもできます。

```mathematica
ClaudeQuery["秘密データの統計を教えて",
  Model -> {"lmstudio", "local-model", "http://127.0.0.1:1234"},
  PrivacySpec -> <|"AccessLevel" -> 1.0|>]
```

> 指定したモデルに直接ルーティングされ、Claude Code を経由しません。

### ClaudeQueryの実行例

実際の使用例とサンプルコードは以下のデモノートブックでご覧いただけます：

[ClaudeQuery デモノートブック](https://www.wolframcloud.com/obj/imai/Published/claudecode-examples.nb)

---

## 2. コード生成と自動実行（ClaudeEval）

タスクを指示すると、Mathematica コードを生成してノートブックに挿入・実行します。

```mathematica
ClaudeEval["東京の過去30日間の気温データを取得し折れ線グラフで表示して"]
```

> ノートブックに Input セルが挿入され、自動実行されます。

画像や Dataset を含むマルチモーダル入力も可能です。

```mathematica
img = Import["chart.png"];
ClaudeEval[{"このグラフのトレンドを分析して回帰直線を描いて", img}]
```

> 画像を解析したコードが生成・実行されます。

### Web 検索付き実行

```mathematica
ClaudeEval["最新の為替レートを調べて円ドルの推移グラフを作成して",
  WebFetch -> True]
```

> Web 検索で最新情報を取得し、コードを生成・実行します。`WebFetch -> Automatic`（デフォルト）では Claude が自動判定します。

### スケジュール実行

```mathematica
ClaudeEval["サーバーの状態を確認して",
  StartTime -> Now + Quantity[1, "Hours"]]
```

> 1時間後に実行されます。

```mathematica
ClaudeEval["メールを確認して新着を報告して",
  RepeatInterval -> Quantity[30, "Minutes"]]
```

> 30分ごとに繰り返し実行されます。`TaskRemove[]` で停止できます。

```mathematica
ClaudeEval["レポートを生成して",
  RepeatInterval -> {Quantity[1, "Hours"], 5}]
```

> 1時間ごとに最大5回実行されます。

### 再帰深度制限

ClaudeEval が生成するコード内でさらに ClaudeEval/ContinueEval を呼び出す連鎖の上限は `$ClaudeEvalMaxDepth`（デフォルト 5）で制御されます。

```mathematica
$ClaudeEvalMaxDepth = 3  (* 最大3段階までの連鎖を許可 *)
```

> 上限に達すると警告が表示され、それ以上の再帰は実行されません。

---

## 3. エラー修正の継続（ContinueEval）

ClaudeEval の実行でエラーが出た場合、セッション履歴を使って修正を依頼します。

```mathematica
ContinueEval["日本語のラベルが文字化けしています。フォント指定を追加して"]
```

> 直前のエラーと履歴を参照し、修正コードが生成されます。

引数なしで呼ぶと「エラーを修正してください」で自動継続します。

```mathematica
ContinueEval[]
```

> `"エラーを修正してください"` として実行されます。

### アクセスレベル対応フォールバック

ContinueEval は三段階のルーティングロジックでモデルを選択します。

```mathematica
(* Claude Code が利用可能で AccessLevel に対応 → Claude Code を使用 *)
ContinueEval["修正してください", Fallback -> True]

(* Claude Code が利用不可 → アクセスレベルに対応するフォールバックモデルへ *)
(* 秘密データを含む場合 → 高 AccessLevel のモデルのみに自動ルーティング *)
ContinueEval["秘密データの集計結果を修正して",
  Fallback -> True, PrivacySpec -> <|"AccessLevel" -> 1.0|>]
```

> アクセスレベルに応じて利用可能なモデルのみにフォールバックします。

---

## 4. 機密データの保護（Confidential / MarkConfidential）

API キーや個人情報を含むセルを Claude のプロンプトから除外します。

```mathematica
apiKey = Confidential[SystemCredential["MyAPIKey"]]
```

> 入出力セルが自動的に機密マークされ、以降の ClaudeEval に含まれません。

機密変数を使った結果を明示的に公開する場合は NonConfidential を使います。

```mathematica
summary = NonConfidential[Length[secretData]]
```

> 機密データに依存していても、このセルは公開扱いになります。

### 精密チェック（第2層）

ClaudeQuery/ClaudeEval/ContinueEval の送信直前に、全ノートブックを走査して完全な依存グラフを構築し、秘密依存変数の最終判定を行います。別ノートブック経由の秘密依存も自動検出されます。

### 機密変数の構造情報

`$NBSendDataSchema` が有効な場合（デフォルト）、機密依存の出力にはスキーマ情報が自動付与されます。

```mathematica
(* 出力例: (* [機密依存データ: Association, 3 keys: {name, age, salary}] *) *)
```

> これにより ClaudeEval は変数の構造を把握でき、プロービングなしでコードを生成できます。

---

## 5. プライバシー対応モデルルーティング

秘密データを処理するタスクをローカルモデルに自動ルーティングできます。

### $ClaudePrivateModel の設定

```mathematica
$ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}
```

> ローカルの LM Studio 等で稼働するモデルを秘密データ処理用に指定します。

### AutoPrivate オプション

```mathematica
ClaudeEval["秘密変数 成績 のデータを分析して平均点を計算して",
  AutoPrivate -> True]
```

> タスクが秘密変数にアクセスする場合、生成コードに `Model -> $ClaudePrivateModel, PrivacySpec -> Automatic` が自動付与されます。秘密変数に関係しないタスクでは通常のモデルが使われます。

### Model / PrivacySpec の直接指定

```mathematica
ClaudeQuery["秘密データの統計を教えて",
  Model -> {"lmstudio", "local-model", "http://127.0.0.1:1234"},
  PrivacySpec -> <|"AccessLevel" -> 1.0|>]
```

> 指定したモデルに直接ルーティングされ、Claude Code を経由しません。

---

## 6. フォールバックモデルの設定

Claude Code が利用制限に達した場合の代替モデルを設定します。

```mathematica
$ClaudeFallbackModels = {
  {"anthropic", "claude-opus-4-6"},
  {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}
}
```

> 設定は自動的に NBAccess に同期されます（`iSyncFallbackModelsToNBAccess`）。

```mathematica
ClaudeEval["複雑な計算をして", Fallback -> True]
```

> Claude Code が利用不可の場合、アクセスレベルに対応するモデルへ順次フォールバックします。

---

## 7. 参考資料のアタッチ（ClaudeAttach）

外部ファイルをセッションに添付し、Claude が自動的に参照できるようにします。

```mathematica
ClaudeAttach["spec.pdf"]
ClaudeAttach["utils.wl"]
ClaudeEval["添付した仕様書に従って utils.wl の関数を修正して"]
```

> `アタッチ: spec.pdf  (合計 2 ファイル)`

不要になったらデタッチします。

```mathematica
ClaudeDetach["spec.pdf"]
```

> `デタッチ: spec.pdf  (残り 1 ファイル)`

---

## 8. パッケージの更新と復元（ClaudeUpdatePackage）

既存の .wl パッケージを Claude の支援で更新します。バックアップは自動作成されます。

```mathematica
ClaudeUpdatePackage["myUtils", "exportData関数にCSV出力オプションを追加して"]
```

> `myUtils.wl` が更新され、バックアップが保存されます。排他ロックにより同一パッケージへの並列更新が防止されます。

問題があれば直前の状態に復元できます。

```mathematica
ClaudeRestorePackage["myUtils"]
```

> 直前のバックアップから復元されます。

### 更新の継続（ContinueUpdate）

直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を継続できます。

```mathematica
ContinueUpdate[]                          (* デフォルト指示で継続 *)
ContinueUpdate["境界線が欠けているので修正して"]  (* 追加指示付き *)
ContinueUpdate["myUtils", "エラー処理を追加して"]  (* パッケージ名指定 *)
```

### api.md の自動更新

ClaudeUpdatePackage / ClaudeCreatePackage の完了後、api.md が自動的に更新されます。`"UpdateApiMd" -> False` で無効化できます。

```mathematica
ClaudeUpdatePackage["myUtils", "修正指示", "UpdateApiMd" -> False]
```

---

## 9. バックアップ履歴の管理（ClaudeBackupDataset）

パッケージのバックアップ履歴を Review/Pull/Delete ボタン付きの Grid で表示します。

```mathematica
ClaudeBackupDataset["myUtils"]
```

> 起動時にローカル最新版のスナップショットが SHA-256 ハッシュ付きで保存されます。#0 行の「Pull」ボタンでいつでもローカル最新版に復元できます。Pull で過去バージョンに巻き戻した後にファイルを編集していた場合、ローカル最新版への復元時に変更ファイルの警告が表示されます。

全パッケージのバックアップ履歴を一括表示することもできます。

```mathematica
ClaudeBackupDataset[]
```

> 全パッケージの履歴を統合した Grid が表示されます。

### バックアップ履歴のマイグレーション（ClaudeMigrateBackupHistory）

既存の生 .wl バックアップを差分形式（.wl.cz / .wl.cdiff）に変換し、history フォルダの容量を大幅に削減します。

```mathematica
ClaudeMigrateBackupHistory["myUtils"]
```

> 差分ベースバックアップシステムにより、内容同一のファイルは `.unchanged`（参照のみ）、差分のあるファイルは `.cdiff`（SequenceAlignment ベースの差分）として保存されます。

DryRun モードで削減見積もりを確認できます。

```mathematica
ClaudeMigrateBackupHistory["myUtils", DryRun -> True]
```

> 実際の変換は行わず、容量削減の見積もりのみ表示します。

全パッケージに対して一括実行もできます。

```mathematica
ClaudeMigrateBackupHistory[]
```

---

## 10. セッション履歴の管理

### 履歴サイズ診断（ClaudeHistorySize）

現在のノートブックのセッション履歴サイズを診断します。

```mathematica
ClaudeHistorySize[]
```

> `<|"Entries" -> 25, "ByteCount" -> 85000, "KiloBytes" -> 83.0, "Status" -> "正常"|>`

200KB 超でコンパクション推奨、500KB 超で危険と判定されます。

### 手動コンパクション（ClaudeCompactHistory）

履歴が肥大化した場合に手動でコンパクションを実行できます（通常は自動実行されます）。

```mathematica
ClaudeCompactHistory[]
```

> エントリ数ベースとサイズベース（200KB 上限）の二重チェックにより、ノートブックの肥大化・フリーズを防ぎます。

---

## 11. デバッグとコードレビュー（ClaudeDebug / ClaudeReview）

エラーメッセージを添えてデバッグ支援を受けます。

```mathematica
ClaudeDebug["myModule.wl", "Part::partw: Part 3 of {a,b} does not exist."]
```

> 非同期でデバッグ分析が実行され、修正案がノートブックに出力されます。

コードレビューも同様に非同期で実行されます。

```mathematica
ClaudeReview["myModule.wl"]
```

> コードの問題点・改善提案がノートブックに出力されます。

---

## 12. Web 検索と URL 取得（ClaudeWebSearch / ClaudeWebFetch）

最新情報を Web から取得して活用します。

```mathematica
ClaudeWebSearch["Mathematica 14.2 新機能"]
```

> 検索結果がテキストで返されます。

特定の URL の内容を取得・要約することもできます。

```mathematica
ClaudeWebFetch["https://reference.wolfram.com/language/ref/Dataset.html",
  "主要なオプションを一覧にまとめて"]
```

> 指定 URL の内容を取得し、指示に従って加工した結果が返されます。

---

## 13. AI 画像生成（ClaudeImageGenerate）

OpenAI Images API を使って AI 画像を生成します。

```mathematica
ClaudeImageGenerate["Cherry blossoms in full bloom with a Japanese castle, photorealistic"]
```

> Image オブジェクトが返されます。

### モデルとオプションの指定

```mathematica
(* gpt-image-1 (デフォルト) *)
ClaudeImageGenerate["夕焼けの海辺", "Quality" -> "high"]

(* dall-e-3 を使用 *)
ClaudeImageGenerate["sunset over ocean",
  "Model" -> "dall-e-3", "Size" -> "1792x1024", "Quality" -> "hd"]
```

> `"Quality"` は gpt-image-1 では `"auto"` / `"high"` / `"medium"` / `"low"`、dall-e-3 では `"standard"` / `"hd"` が利用できます。dall-e-3 指定時は `"auto"` → `"standard"`、`"high"` → `"hd"` に自動変換されます。

### 利用可能なモデルの設定

```mathematica
$ClaudeImageModels = {{"openai", "gpt-image-1"}, {"openai", "dall-e-3"}}
```

> ClaudeQuery のリッチレスポンスや ClaudeEval 内でも `ClaudeImageGenerate` が自動的に使用されます。

---

## 14. AI 音声生成（ClaudeSpeech）

OpenAI TTS API を使ってテキストから音声を生成します。

```mathematica
ClaudeSpeech["こんにちは、世界"]
```

> Audio オブジェクトが返されます。

### 音声オプションの指定

```mathematica
ClaudeSpeech["Welcome to the presentation",
  "Model" -> "tts-1-hd",
  "Voice" -> "nova",
  "Speed" -> 1.2]
```

> `"Voice"` は `"alloy"` / `"echo"` / `"fable"` / `"onyx"` / `"nova"` / `"shimmer"` から選択できます。`"Speed"` は 0.25〜4.0 の範囲で指定します。

### 利用可能なモデルの設定

```mathematica
$ClaudeTTSModels = {{"openai", "tts-1-hd"}, {"openai", "tts-1"}}
```

---

## 15. 実行中タスクの監視（ClaudeStatus）

現在実行中の全 Claude タスクのリアルタイム状態を表示します。

```mathematica
ClaudeStatus[]
```

> 各タスクの経過時間、現在の状態（思考中/テキスト生成中/ツール実行中）、生成済みテキスト断片数、思考断片数、ツール使用数を表示します。

---

## 16. ディレクティブ管理

### プロジェクト固有ディレクティブの初期化（ClaudeInitProject）

現在のノートブックのディレクトリにプロジェクト固有の Claude Directives を初期化します。

```mathematica
ClaudeInitProject[]
```

> `.claude-project/CLAUDE.local.md` および `rules/`、`skills/` ディレクトリが作成されます。メインのディレクティブと自動マージされ、次回の ClaudeQuery/ClaudeEval から反映されます。

### ローカルディレクティブの追加（ClaudeAddDirective with Scope）

プロジェクト固有のディレクティブを追加できます。

```mathematica
(* グローバル（デフォルト） *)
ClaudeAddDirective["wolfram-general", "日本語変数名を使用しないこと"]

(* プロジェクトローカル *)
ClaudeAddDirective["CLAUDE.md",
  "このプロジェクトではデータベース名に 'test_' プレフィックスを付ける",
  Scope -> "Local"]
```

> `Scope -> "Local"` を指定すると、`.claude-project/` 内に書き込まれ、そのノートブックのプロジェクトでのみ反映されます。

### ローカルディレクティブのグローバル昇格（ClaudePromoteProjectDirectives）

プロジェクト固有のディレクティブをグローバルに昇格できます。

```mathematica
(* プレビュー *)
ClaudePromoteProjectDirectives[DryRun -> True]

(* 実行 *)
ClaudePromoteProjectDirectives[]
```

> `.claude-project/` 内の CLAUDE.local.md / rules / skills をメインの Claude Directives にコピーします。

### ディレクティブの自動整合性チェック（ClaudeUpdateDirective）

引数なしで呼ぶと、ソースコードと Claude Directives の整合性をチェックし、不整合を自動修正します。

```mathematica
ClaudeUpdateDirective[]
```

> 基盤パッケージ（claudecode, github, NBAccess）の公開関数・オプションを走査し、ディレクティブとの不整合を検出・修正します。

テキスト指示でディレクティブを更新することもできます。

```mathematica
ClaudeUpdateDirective["Excel インポート時にシートのリストを外すルールを追加して"]
```

> ノートブックコンテキストも参照でき、「上で議論されている内容を反映して」などの指示も可能です。

### ローカルスコープでのディレクティブ更新

```mathematica
ClaudeUpdateDirective["このプロジェクト用のルールを追加して", Scope -> "Local"]
```

> `.claude-project/` 内のディレクティブが更新され、メインには影響しません。

### ディレクティブ履歴の管理（ClaudeDirectiveBackupDataset）

Claude Directives の更新履歴を Review/Pull/Delete ボタン付き Grid で表示します。

```mathematica
ClaudeDirectiveBackupDataset[]
```

> 起動時にローカル最新版のスナップショットが保存されます。#0 行の「Pull」ボタンでローカル最新版に復元できます。Pull で過去バージョンに巻き戻した後に変更があれば警告が表示されます。

### 外部ディレクトリとの同期（ClaudeSyncDirectives）

外部の Claude Directives フォルダとの同期を行います。

```mathematica
ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]
```

> dir 側の方が新しいファイル、または dir にだけ存在するファイルをコピーします。内容が同一のファイルはスキップされます。

---

## 17. Think トリガー（日本語の励まし表現）

日本語の励まし表現を使うと、自動的に Claude の thinking budget が設定されます。

```mathematica
ClaudeEval["死ぬ気で考えてバグを直せ"]
(* → ultrathink が自動挿入される *)

ClaudeEval["よく考えてリファクタリングして"]
(* → think hard が自動挿入される *)

ClaudeEval["考えてみて最適なアルゴリズムを選んで"]
(* → think が自動挿入される *)
```

> ClaudeUpdatePackage 等のコード生成時にも、生成される指示文字列に think トリガーが自動注入されます。

---

## 18. NBAccess 分離検証（ClaudeCheckSeparation / ClaudeFixSeparation）

パッケージコードが NBAccess の分離原則に違反していないか検証します。

```mathematica
ClaudeCheckSeparation["claudecode"]
```

> 静的パターン走査と LLM 判定の二段階で違反を検出し、カテゴリ別にリストアップします。

検出対象のカテゴリ:
- a: SystemCredential 直接利用
- b: CellObject 直接操作（NotebookWrite/NotebookRead/CellGroupData 直接構築）
- c: CellEpilog/CellProlog/NotebookEventActions 直接操作
- d: NBAccess`Private` 関数呼び出し
- e: NBAccess 公開グローバル直接更新
- f: EvaluationCell[]/CellPrint[]/SetSelectedNotebook[] 直接使用
- g: CurrentValue/SetOptions による TaggingRules/CellTags/CellEpilog 属性直接アクセス
- h: CellObject の公開 API・戻り値・状態保持への漏洩
- i: SelectionEvaluate/FrontEndTokenExecute 等 FE 状態操作
- j: NBAccess 公開グローバルの破壊的更新（AppendTo/AssociateTo 等）

違反が見つかった場合は自動修正できます。

```mathematica
ClaudeFixSeparation["claudecode"]
```

> 直前の ClaudeCheckSeparation の結果を利用し、NBAccess の公開 API に置き換えます。パッケージ名の場合は ClaudeUpdatePackage が呼び出されます。

---

## 19. NotebookDirectory アクセス制御

`$ClaudeNBDirAccess` でノートブックディレクトリのアクセスレベルを制御します。

```mathematica
(* デフォルト: ファイル一覧のみ表示 *)
$ClaudeNBDirAccess = "list"

(* 読み取り許可 *)
$ClaudeNBDirAccess = "read"

(* 読み書き許可 *)
$ClaudeNBDirAccess = "readwrite"
```

> `"list"` モードでプロンプトが NotebookDirectory 内のファイルを参照している場合、権限付与ボタンが自動表示されます。

---

## 20. Claude Code CLI コマンド実行（ClaudeCommand）

Claude Code CLI のスラッシュコマンドやサブコマンドを Mathematica から実行できます。

```mathematica
ClaudeCommand["/help"]         (* ヘルプ表示 *)
ClaudeCommand["/permissions"]  (* ファイルアクセス権限 *)
ClaudeCommand["/model"]        (* モデル情報 *)
ClaudeCommand["--version"]     (* バージョン表示 *)
ClaudeCommand["config list"]   (* 設定一覧 *)
```

> スラッシュコマンド（`/` 始まり）は node-pty 経由で対話モードに送信され、CLI サブコマンドは直接実行されます。

---

## 21. ドキュメント生成と更新

### ドキュメント自動生成（ClaudeCreateDocumentation）

パッケージの包括的なドキュメント一式を自動生成します。

```mathematica
ClaudeCreateDocumentation["myUtils"]
```

> setup.md, user_manual.md, api.md, examples/example.md, README.md が順次生成されます。リミット到達時は自動停止し、再実行で未生成分のみ続行します。

### オプション付きドキュメント生成

```mathematica
ClaudeCreateDocumentation["myUtils",
  References -> {"https://reference.wolfram.com/...", "参考書籍名"},
  Demos -> {"https://youtu.be/demo_video"},
  Disclaimer -> {"本ツールは研究目的専用です"},
  License -> "MIT"]
```

> 参考文献、デモ動画、免責事項、ライセンスが README.md に自動挿入されます。これらのオプションは `_info/references/doc_options.json` に永続化され、次回の更新時にも引き継がれます。

### ドキュメント差分更新（ClaudeUpdateDocumentation）

ソースコードの変更を自動検出してドキュメントを更新します。

```mathematica
(* 自動差分検出 *)
ClaudeUpdateDocumentation["myUtils"]

(* 指示付き更新 *)
ClaudeUpdateDocumentation["myUtils", "api.md のみ更新して"]
```

> ノートブックのコンテキストも参照可能（「上で議論されている内容を反映して」などの指示も可能）。

---

## 22. シンボル参照（<<変数名>> 記法）

プロンプト中で `<<変数名>>` と書くと、ノートブックカーネル内のシンボル情報が自動展開されます。

```mathematica
ClaudeEval["<<data>> の最初の10行を表示して"]
```

> `data` の型、次元、キー、プレビュー値がプロンプト末尾に自動付加されます。機密変数の場合は構造情報のみ（値は除外）が付加されます。

---

## 23. パッケージ新規作成（ClaudeCreatePackage）

新しいパッケージを仕様指示から自動生成します。

```mathematica
ClaudeCreatePackage["MyCalculator",
  "四則演算と三角関数をサポートする関数電卓パッケージ。
   calculate[expr] で式を評価し、history[] で計算履歴を表示する。"]
```

> `$packageDirectory/MyCalculator.wl` が生成され、自動ロードされます。

---

## 24. Paclet 変換（ClaudeConvertToPaclet）

単一 .wl ファイルのパッケージを Paclet 形式に変換します。

```mathematica
ClaudeConvertToPaclet["myUtils"]
```

> `myUtils/` ディレクトリに PacletInfo.wl, Kernel/, Documentation/, Tests/ 等が生成されます。元の .wl ファイルはバックアップ後に削除されます。