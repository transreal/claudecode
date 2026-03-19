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

---

## 9. デバッグとコードレビュー（ClaudeDebug / ClaudeReview）

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

## 10. Web 検索と URL 取得（ClaudeWebSearch / ClaudeWebFetch）

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

## 11. 実行中タスクの監視（ClaudeStatus）

現在実行中の全 Claude タスクのリアルタイム状態を表示します。

```mathematica
ClaudeStatus[]
```

> 各タスクの経過時間、現在の状態（思考中/テキスト生成中/ツール実行中）、生成済みテキスト断片数、思考断片数、ツール使用数を表示します。