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

### CUDA 拡張の自動検出

プロンプトに CUDA 関連のキーワードが含まれる場合、`cuda.wl` 拡張を自動的にロードして CUDA 対応コードを生成します。

```mathematica
ClaudeEval["CUDA を使って行列積を高速化して"]
```

> `cuda.wl` が存在する場合は自動ロードされます。存在しない場合は警告が表示されます。

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
  {"chatgptcodex", "gpt-5.5"},
  {"anthropic", "claude-opus-4-8"},
  {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}
}
```

> 設定は自動的に NBAccess に同期されます（`iSyncFallbackModelsToNBAccess`）。先頭の `chatgptcodex` は ChatGPT Codex CLI 経由のサブスクリプション利用（追加課金なし）、次に Anthropic API、最後にローカル LM Studio の順でフォールバックします。

フォールバック要素の `"provider"` には次のプロバイダを指定できます。

- `chatgptcodex`: ChatGPT Codex CLI 経由（サブスクリプション、追加課金なし）
- `anthropic`: Anthropic API 直接（課金）
- `openai`: OpenAI API（課金）
- `zai`: z.ai の GLM シリーズ（課金 API）。例: `{"zai", "glm-5.2"}`
- `lmstudio`: ローカル LLM（課金なし）。例: `{"lmstudio", "gpt-oss-20b", "http://127.0.0.1:1234"}`

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

### 検証テストの自動生成・実行

ClaudeUpdatePackage はコードの生成・マージ後に検証テストを自動的に生成・実行します。

```mathematica
ClaudeUpdatePackage["myUtils", "平均計算関数を追加して"]
```

> マージ完了後、`===BEGIN_TESTS===` ～ `===END_TESTS===` ブロックに生成された検証テストが自動実行されます。全テスト通過時は ✅、失敗時は ⚠️ が表示されます。マージによって意図せず変更された関数がある場合も警告が出力されます。

### セグメント単位マージと完全修飾定義の認識

LLM からの部分的なレスポンス（コンテキスト制限等で途中まで返された場合）は、「連続した行のかたまり」をセグメントとして単位でマージします。セグメントが元のソースコードと一致しない場合は、⚠ マージ不一致警告が表示されます。

```mathematica
ClaudeUpdatePackage["myUtils", "複数の関数を一括修正して"]
(* セグメントが一致しなかった場合の出力例:
   ⚠ マージ不一致: 以下の関数はセグメントが元コードと一致せず、置換できませんでした:
     myFunction1, myFunction2 *)
```

> 不一致のセグメントはスキップされ、一致したセグメントのみ更新されます。`Pkg\`X` / `Pkg\`Private\`iX` のような完全修飾定義形式も認識されるため、プライベートコンテキストで定義された関数も正しく対象として扱われます。

### LLM コンテキスト供給の改善

ClaudeUpdatePackage では LLM に対して全トップレベル定義名の索引を提示します。これにより、存在しない関数名の捏造（ハルシネーション）を防ぎ、実際のコードベースに即した正確な更新が行われます。

### 依存パッケージ API の自動注入

プロンプトに依存パッケージ名が含まれる場合、そのパッケージの `api.md` が自動的にコンテキストに付加されます。これによりパッケージ境界を越えた正確なコード生成が可能になります。

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

## 16. パッケージキーワードマッピングシステム（$ClaudePackageKeywordMap）

外部パッケージが特定のキーワードを登録し、プロンプトにそのキーワードが含まれる場合に自動的に関連する API ドキュメントをコンテキストに注入するシステムです。

### キーワード登録の仕組み

各パッケージは自身のロード時に `$ClaudePackageKeywordMap` にキーワードを登録します。

```mathematica
(* maildb パッケージの例 *)
$ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "検切"};
```

### 自動コンテキスト注入

プロンプトに登録されたキーワードが含まれると、対応するパッケージの `api.md` が自動的にコンテキストに注入されます。

```mathematica
ClaudeEval["メールの送信履歴を分析して"]
```

> `"メール"` キーワードにより maildb パッケージの api.md がコンテキストに自動注入されます。

### 補助 API ドキュメントの条件付き注入（$ClaudePackageAuxKeywordMap）

パッケージが補助的な `api_<aux>.md` を持つ場合、その注入条件を `$ClaudePackageAuxKeywordMap` で登録できます。形式は `<|pkg -> <|aux -> {キーワード...}|>|>` です。

```mathematica
(* SourceVault の eagle 補助 API を Eagle/Exif キーワード時のみ注入 *)
$ClaudePackageAuxKeywordMap["SourceVault"] = <|"eagle" -> {"Eagle", "Exif"}|>;
```

> 登録された補助 API は、aux 名またはそのキーワードが task に一致する場合のみ注入されます。未登録の補助 API は従来どおり常に注入され、後方互換性が保たれます。これにより、大量の補助ドキュメントを持つパッケージでも、関連するもののみを選択的にコンテキストへ載せられます。

### パッケージ独立性

`claudecode.wl` 側はパッケージ非依存であり、各パッケージが独立してキーワードを管理します。これにより、新しいパッケージも既存の claudecode システムを変更せずにキーワードマッピングを利用できます。

---

## 17. ディレクティブ管理

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

## 18. Think トリガー（日本語の励まし表現）

日本語の励まし表現を使うと、自動的に Claude の thinking budget が設定されます。

### 自動 Think 注入システム

特定の日本語表現が検出されると、Claude の thinking budget が自動的に設定されます：

```mathematica
ClaudeEval["死ぬ気で考えてバグを直せ"]
(* → ultrathink が自動挿入される *)

ClaudeEval["よく考えてリファクタリングして"]
(* → think hard が自動挿入される *)

ClaudeEval["考えてみて最適なアルゴリズムを選んで"]
(* → think が自動挿入される *)
```

### パッケージ操作時の自動注入

ClaudeUpdatePackage 等のコード生成時にも、生成される指示文字列に think トリガーが自動注入されます。これにより、パッケージの更新や修正において、Claude がより深く思考して質の高いコードを生成します。

### 段階的思考レベル

思考の強度に応じて適切な thinking budget が自動選択されます：
- **ultrathink**: 最高レベルの思考（「死ぬ気で」「必死に」等）
- **think hard**: 集中的思考（「よく考えて」「しっかり考えて」等）  
- **think**: 基本的思考（「考えてみて」「考えて」等）

---

## 19. NBAccess 分離検証（ClaudeCheckSeparation / ClaudeFixSeparation）

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

## 20. NotebookDirectory アクセス制御

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

## 21. Claude Code CLI コマンド実行（ClaudeCommand）

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

## 22. ドキュメント生成と更新

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

### 差分基準の切り替え（Baseline オプション）

差分の基準点を `Baseline` オプションで切り替えられます。指定できる値は `"LastDocUpdate"`（デフォルト）と `"Github"` の 2 つです。

```mathematica
(* 既定: 直近の _documentupdate バックアップを基準にする（従来の挙動） *)
ClaudeUpdateDocumentation["myUtils", Baseline -> "LastDocUpdate"]

(* GitHub コミット版を基準にする *)
ClaudeUpdateDocumentation["myUtils", Baseline -> "Github"]
```

> - `Baseline -> "LastDocUpdate"`（デフォルト）: 直近の `_documentupdate` バックアップとの差分を基準にします。これは従来どおりの動作で、前回のドキュメント更新以降に加わったソースコードの変更を反映します。
> - `Baseline -> "Github"`: `GithubRepositories` 内のコミット版（`$packageDirectory/GithubRepositories/<パッケージ名>`）を基準にソース差分を取得します。前回のドキュメント更新バックアップが存在しなくても、コミット版を起点として差分を計算できます。

`Baseline -> "Github"` では、ソースコードの差分に加えて `_info`/`design`（設計意図）の新規内容も自動的に取り込みます。コードの変更点だけでは読み取れない設計上の意図を補い、api.md 以外のドキュメント（README を含む）に反映して、新しくなった部分の記述を充実させます。

```mathematica
ClaudeUpdateDocumentation["myUtils", Baseline -> "Github"]
```

> コミット版からのソース差分と `_info`/`design` の新規内容の両方を加味し、追加された関数・オプションの説明を追加し、削除されたものの説明を削除したうえで、設計意図に沿った記述に改善します。前回コミット以降の累積変更をまとめてドキュメントに反映したい場合に有効です。

### 補助 API ドキュメントの鮮度判定（内容ハッシュ基準）

補助 API ドキュメント（`api_<aux>.md`）を更新対象に含めるかどうかは、対応する補助ソース（`<pkg>_<aux>.wl`）の**内容ハッシュ**を基準に判定されます。ファイルの更新日時（mtime）は Dropbox 同期・複数 PC・git 操作などによって内容と無関係に変動するため、mtime 比較だけでは未変更の補助ドキュメントまで再生成してしまう問題がありました。内容ハッシュ基準の判定はこの揺れを吸収します。

```mathematica
ClaudeUpdateDocumentation["myUtils"]
```

> - 補助ソースの内容ハッシュは、doc 生成成功時に docsDir 内のサイドカーファイル `.aux_source_hashes.json` に記録されます。
> - 次回以降は、記録済みハッシュと現ソースの内容ハッシュを比較し、**内容が実際に変わったときだけ**その補助 API ドキュメントを再生成します。
> - 改行コードの差（CRLF / LF）だけの揺れは `\r` を除去して無視されます。
> - ハッシュが未記録の場合（移行措置）は従来どおり mtime 比較で判定しつつ、未変更（doc の方が新しい）であれば現ハッシュを基準として記録し、以後は内容ハッシュ基準に寄せていきます。内容ハッシュが読めない場合のみ mtime にフォールバックします。

これにより、多数の補助ドキュメントを持つパッケージでも、Dropbox 上での mtime のブレによる不要な再生成を避け、実際に変更された補助 API のみが更新されます。

### 並列ドキュメント更新

更新対象が多数（目安として 20 ファイル以上）になる場合、README 以外のドキュメントを LLM へ並列投入し、更新全体の所要時間を短縮します。

```mathematica
ClaudeUpdateDocumentation["myUtils"]
```

> 多数のドキュメントを同時更新する際は、ウィンドウステータスバーに「完了 N/M • K 並列実行中 • 経過 Ts」がライブ表示されます。並列度の上限は `$LLMGraphMaxConcurrency["cli"]` の値で決まります。README はソース全体の整合性を要するため並列対象から除外され、他のドキュメントの更新後に処理されます。並列度の上限以下のファイル数であれば、投入分は必ず即起動されます。

### ドキュメント更新の再開（resumption）

API エラーや利用制限などで更新チェーンが途中で中断しても、成功済みのドキュメントは記録され、再実行時にはスキップされます。

```mathematica
(* 1回目: 途中で API エラーにより中断 *)
ClaudeUpdateDocumentation["myUtils"]

(* 2回目: 同じソース・指示・対象なら、未更新のドキュメントだけを続行 *)
ClaudeUpdateDocumentation["myUtils"]
```

> ソース内容・指示・対象ファイル集合から「サイクル鍵」を生成し、成功したファイルを記録します。同一サイクル内で再実行すると、すでに更新済みのドキュメントはスキップされ、残りのドキュメントだけが処理されます。すべて更新済みの場合は `✅ All documents already updated in this cycle.`、指定された対象がすべて更新済みの場合は `✅ Target documents already updated in this cycle.` が表示されます。なお、サイクル鍵は安定した指示（raw instruction）を用いて算出されるため、毎回変化するノートブック文脈は鍵の対象から除外されます。

### 品質ガードと切り詰め検出

更新チェーンは、システム的失敗（API エラー／利用制限／内部エラー／空応答）に加え、品質失敗（応答の切り詰め＝truncation／サイズ退行／タイトル不整合）を検出すると、その時点でチェーンを即中断します。

```mathematica
ClaudeUpdateDocumentation["myUtils"]
(* 中断時の出力例: *)
(* ⛔ [3/7] api.md の更新を中断 (無効/切り詰め/サイズ退行/タイトル不整合)。 *)
(* ⛔ Doc update aborted (1 failed) *)
```

> 不完全なドキュメントで既存ファイルを上書きするのを防ぐため、切り詰めなどの品質失敗を検出した場合はバックアップを行わず、進捗（成功済みドキュメント）を保持したまま中断します。原因（利用制限の解除など）を解消してから再実行すると、中断したドキュメントから再開されます。

### 多重起動ガード

同一パッケージのドキュメント更新チェーンが既に進行中の場合、二重起動を防ぐメッセージが表示されます。

```mathematica
ClaudeUpdateDocumentation["myUtils"]
(* 別の更新チェーンが進行中の場合: *)
(* "myUtils のドキュメント更新が既に進行中です。完了を待ってから再実行してください。" *)
```

> 2 本の更新チェーンが同じ `docs/` と履歴を同時更新すると、ドキュメントの破損やバックアップの競合が発生する可能性があります。先行する更新の完了を待ってから再実行してください。なお更新チェーンが異常終了して解放されなかった場合も、一定時間（`$ClaudeDocUpdateStaleSeconds`、デフォルト 1800 秒）を超えると自動的にロックが解放され、再実行できるようになります。

---

## 23. シンボル参照（<<変数名>> 記法）

プロンプト中で `<<変数名>>` と書くと、ノートブックカーネル内のシンボル情報が自動展開されます。

```mathematica
ClaudeEval["<<data>> の最初の10行を表示して"]
```

> `data` の型、次元、キー、プレビュー値がプロンプト末尾に自動付加されます。機密変数の場合は構造情報のみ（値は除外）が付加されます。

---

## 24. パッケージ新規作成（ClaudeCreatePackage）

新しいパッケージを仕様指示から自動生成します。

```mathematica
ClaudeCreatePackage["MyCalculator",
  "四則演算と三角関数をサポートする関数電卓パッケージ。
   calculate[expr] で式を評価し、history[] で計算履歴を表示する。"]
```

> `$packageDirectory/MyCalculator.wl` が生成され、自動ロードされます。

---

## 25. Paclet 変換（ClaudeConvertToPaclet）

単一 .wl ファイルのパッケージを Paclet 形式に変換します。

```mathematica
ClaudeConvertToPaclet["myUtils"]
```

> `myUtils/` ディレクトリに PacletInfo.wl, Kernel/, Documentation/, Tests/ 等が生成されます。元の .wl ファイルはバックアップ後に削除されます。

---

## 26. コミット準備（ClaudePrepareCommit）

前回の GitHub コミット以降の変更点をバックアップ履歴から収集し、コミットメッセージを生成して GitHub への反映コマンドを準備します。

### 基本的な使用法

```mathematica
ClaudePrepareCommit["myUtils"]
```

> 前回コミット以降の変更をバックアップ履歴から自動収集し、適切なコミットメッセージを生成して `GitHubRefreshAndCommit` 実行コマンドを Input セルとして出力します。

### 件名指定でのコミット準備

```mathematica
ClaudePrepareCommit["myUtils", "新機能追加: CSV出力サポート"]
```

> 1行目（件名）は指定されたテキストを使用し、本文は変更サマリーから自動構築されます。

### オプション指定

```mathematica
ClaudePrepareCommit["myUtils", 
  DryRun -> True,
  Branch -> "feature/csv-export",
  BaseBranch -> "develop"]
```

> `DryRun -> True` でコマンドを生成せずメッセージのみ表示、ブランチ指定で特定のブランチへの反映が可能です。

### 変更サマリーの自動整形

バックアップ履歴から収集された変更点は、適切な日本語で 72 文字での折り返しを含む箇条書き形式に自動整形されます。各変更点には変更の種類（追加/修正/削除）も自動判定されて含まれます。

---

## 27. 仕様生成と実装ワークフロー（ClaudeSpec / SourceVault 統合）

SourceVault と連携して、ノートブック内容から仕様を策定し、コンセンサス（Claude ↔ Codex）レビューを経て承認済み仕様をコードとして実装するワークフローを提供します。

### 仕様のステータス確認（ClaudeSpecStatus）

現在のノートブックプロジェクトの仕様策定状況を確認します。

```mathematica
(* 現在のノートブックのプロジェクトのステータスを表示 *)
ClaudeSpecStatus[]
```

> ノートブックの TaggingRule `SourceVaultSpecProjectId` に紐付くプロジェクトの仕様・レビューバージョン数、最新の Verdict、最新の仕様 sv:// URI、最終更新時刻、バックグラウンドコンセンサスジョブの進行状況が表示されます。SourceVault のみを使用し、ワークフローエンジンは不要です。

```mathematica
(* 特定プロジェクトのステータスを表示 *)
ClaudeSpecStatus["my-feature-spec"]
```

> Dataset 形式でプロジェクトの詳細ステータスが返されます。

### 仕様バージョン一覧（ClaudeSpecVersions）

プロジェクトに記録された全仕様・レビューバージョンをリスト表示します。

```mathematica
(* 現在のノートブックのプロジェクト全バージョンを取得 *)
ClaudeSpecVersions[]

(* 特定プロジェクトを指定 *)
ClaudeSpecVersions["my-feature-spec"]

(* ロールを絞り込み: "spec" | "review" | "requirements" *)
ClaudeSpecVersions["my-feature-spec", "spec"]
ClaudeSpecVersions["my-feature-spec", "review"]
```

> Dataset 形式で返されます（列: Role, Round, Verdict, Seq, CreatedAtUTC, URI）。URI 列の値を `ClaudeSpecText` に渡すと、その版の本文を取得できます。

### 仕様テキストの取得（ClaudeSpecText）

sv:// URI から仕様・レビューのテキスト本文を取得します。

```mathematica
(* ClaudeSpecVersions の URI 列から取得した URI を渡す *)
ClaudeSpecText["sv://snapshot/spec/abc123def456"]
```

> sv:// 形式（`sv://snapshot/Class/hex` または `sv://snapshot/Class:hex`）と生の `snapshot:Class:hex` 参照の両方に対応しています。手動での参照変換は不要です。

### sv:// URI をノートブックで開く（ClaudeOpenSourceVaultURI）

仕様策定フローがノートブックに書き込む sv:// クリッカブルリンクの実体です。URI の内容を新しいノートブックウィンドウで開きます。

```mathematica
ClaudeOpenSourceVaultURI["sv://snapshot/spec/abc123def456"]
```

> メタデータグリッドと本文（Text セル）を含む新しいノートブックウィンドウが開きます。レビュースナップショットの場合は Findings セクションも表示されます。スナップショットが読み込めない場合は `$Failed` を返します。

### アドバイザリモデルの設定（$ClaudeAdvisaryModel）

仕様レビュー＆改訂オーケストレータワークフローのアドバイザリ（Codex）役モデルを指定します。`$ClaudeModel` と同じ `{provider, model}` タプル形式です。

```mathematica
(* デフォルト: ChatGPT Codex CLI の既定モデルを使用 *)
$ClaudeAdvisaryModel = {"chatgptcodex", "Automatic"}

(* 特定のモデルを指定 *)
$ClaudeAdvisaryModel = {"chatgptcodex", "gpt-5.5"}

(* ベアプロバイダ文字列も受け付ける *)
$ClaudeAdvisaryModel = "chatgptcodex"
```

> Claude Code 役は `$ClaudeModel`、Codex（アドバイザリ）役は `$ClaudeAdvisaryModel` を使用します。

### 実装ワークフローの作成（CreateImplementationWorkflow）

承認済み設計仕様を `SourceVault_workflows/<name>/` 配下のコード化された SVWorkflow パッケージとして実装します。

```mathematica
(* 承認済み仕様の sv:// URI から実装ワークフローを作成 *)
jobId = CreateImplementationWorkflow["MyFeature",
  "sv://snapshot/spec/abc123def456"]
```

> バックグラウンドドライバが起動し、実装者（`$ClaudeModel`）がパッケージを作成、検証者（`$ClaudeAdvisaryModel`）が仕様に照らして確認するコンセンサスループが実行されます。複雑な作業はステージに分割され、補助仕様が先にレビューされます。進行状況（実行中モデル＋フェーズ）は `WindowStatusArea` に表示されます。完了後、生成されたワークフローの起動関数がセッションと promptrouter に登録され、サマリーがノートブックに書き込まれます。

オプションで詳細を制御できます。

```mathematica
CreateImplementationWorkflow["MyFeature",
  "sv://snapshot/spec/abc123def456",
  "Notes" -> "日本語コメントを使用すること",
  "ClaudeModel" -> {"claudecode", "claude-opus-4-8"},
  "AdvisaryModel" -> {"chatgptcodex", "Automatic"},
  "MaxRounds" -> 5]
```

> バックグラウンドで実行され、ジョブ ID が返されます。`approvedSpec` には sv:// URI のほかスナップショット参照や生の仕様テキストも渡せます。

### 実装ワークフローの進行監視（ClaudeImplStatus / ClaudeImplMonitor）

`CreateImplementationWorkflow` で起動した仕様実装（仕様実装）ワークフローの進行状況を確認します。

```mathematica
(* 現在のノートブックの実装ワークフロー状態を表示 *)
ClaudeImplStatus[]

(* 特定のワークフローを指定 *)
ClaudeImplStatus["MyFeature"]
```

> 現在のフェーズ、実行中モデル、ステージ、ラウンド、メッセージ、および SourceVault の成果物（artifact）／検証（verify）チェーン数と最新の Verdict が Dataset 形式で返されます。ワークフロー実行中は、同じ状態がノートブックのウィンドウステータスエリアにも自動表示されます。

```mathematica
(* 自動更新される監視パネル *)
ClaudeImplMonitor[]
```

> `ClaudeImplStatus[]` を約2秒ごとに自動更新する Dynamic パネルを返します。ノートブックのセルに配置することで、実行中の仕様実装ワークフローをリアルタイムに監視できます。

### 実装ワークフローの起動（LaunchImplementationWorkflow）

`CreateImplementationWorkflow` で生成されたワークフローを（再）起動します。

```mathematica
LaunchImplementationWorkflow["MyFeature", <|"param1" -> "value1"|>]
```

> ワークフロー（`SourceVaultLoadWorkflow["MyFeature"]`）をロードし、その起動エントリ（`WorkflowInfo["Launch"]`）を指定の引数で呼び出します。起動コンテキスト、エントリ、結果を含む Association が返されます。

---

## 28. Claude CLI 用 MCP サーバの登録（ClaudeRegisterCLIMCPServer / $ClaudeCLIMCPServers）

外部パッケージ（例: SourceVault MCP）が、ヘッドレスな claude CLI 実行（`queryProvider` / `ClaudeQueryBg`）に MCP サーバを配線するための仕組みです。`claudecode.wl` 側は特定のパッケージに依存せず（パレットのサービストグルと同方針）、各パッケージが自身のロード時に自分自身を登録します。

### MCP サーバの登録

```mathematica
ClaudeRegisterCLIMCPServer["sourcevault", <|
  "ConfigFn" -> Function[<|"Url" -> "http://127.0.0.1:8787/mcp"|>],
  "AllowedTools" -> {"search", "fetch"},
  "PromptDirective" -> "利用可能なときは SourceVault MCP を優先的に使うこと"
|>]
```

`spec` の各キーの意味:

- **`"ConfigFn"`**: サーバが到達可能なときは `<|"Url" -> ..., ("Headers" -> <|...|>)|>` を、停止中は `None` を返す 0 引数関数。稼働時のみ設定を返すことで、サーバの起動状態をライブに反映します。
- **`"AllowedTools"`**: 事前許可するツール名のリスト。`--allowedTools` に `mcp__<id>__<tool>` の形で追加されます。`--print` モードは対話的にツールを承認できないため、使用するツールは必ず事前許可しておく必要があります。
- **`"PromptDirective"`**: サーバ稼働中にクエリプロンプトへ注入される「MCP 優先」ポリシー文（`String` または 0 引数 `Function`）。

> 同じ id で再登録すると上書きされます。登録済みサーバは `$ClaudeCLIMCPServers`（`<|id -> spec|>`）に保持され、稼働中（`ConfigFn` が `Url` を返す）のもののみ read-only ツールが許可されます。

### 登録の解除

登録は id をキーとして管理されるため、パッケージ側で必要に応じて上書き・更新できます。

```mathematica
(* 現在登録されている CLI MCP サーバの一覧を確認 *)
Keys[$ClaudeCLIMCPServers]
```

> `claudecode` はどのパッケージも直接参照しないため、新しいパッケージも既存の claudecode システムを変更せずに MCP サーバを配線できます。

Section 22 に「補助 API ドキュメントの鮮度判定（内容ハッシュ基準）」の小節を追加しました。今回のソース差分は内部関数（`iAuxSourceHash` / `.aux_source_hashes.json` サイドカー / mtime フォールバックなど）だけで、公開シンボルやオプションの増減はなかったため、その挙動改善（Dropbox の mtime 揺れ対策）のみをユーザー視点で反映し、他の節は変更していません。