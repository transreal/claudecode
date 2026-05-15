# Rule 02: LLM 指示文・スキル・慣習を `.wl` にハードコードしない

優先度: **最優先 (00 AutoEvaluate 禁止に次ぐ)**

## ルール本文

LLM にコード生成・分析・推論を指示するテキストや、システム外要因 (モデルのバージョンアップ、API 仕様変更、ベストプラクティス更新等) で変更されうる情報は、`.wl` ソースコードに直書きしてはならない。これらは `Claude Directives` の `skills/` または `rules/` に置く。

## なぜこのルールが必要か

`.wl` ファイルは「ロジック・データ構造・公開 API」のためのもので、`Claude Directives` は「LLM への指示・慣習・運用知識」のためのものである。両者を混在させると:

1. **保守性の低下**: モデル名 (`gpt-5`, `gpt-4.1` 等) が変わるたびに、複数の `.wl` ファイルの分岐コードを書き換える必要が出る。
2. **責務の漏洩**: 「LLM がコードを書くときの慣習」という運用知識が、ロジックを書く `.wl` に染み出して、コードレビューと運用ガイドの境界が曖昧になる。
3. **更新の追跡困難**: skill ファイルは Git で運用知識として独立に追跡できるが、`.wl` 内のコメントや文字列定数は埋もれる。
4. **再利用の阻害**: 同じ「LLM への指示」を複数のパッケージで使いたいとき、`.wl` に書いてあるとコピーが発散する。skill にあれば一箇所で完結する。

## 具体的なハードコード禁止対象

### (1) モデル枝番をコード分岐に書かない

❌ 悪い例 (コード分岐に枝番を書く):

```wolfram
iPrefixMatchCapability[modelName_String] :=
  Which[
    StringStartsQ[normalized, "gpt-5"],     $caps["gpt-5"],
    StringStartsQ[normalized, "gpt-4.1"],   $caps["gpt-4.1"],
    StringStartsQ[normalized, "gpt-4.5"],   $caps["gpt-4.1"],  (* fallback *)
    StringStartsQ[normalized, "gpt-4o"],    $caps["gpt-4o"],
    ...
  ];
```

これは半年後にはほぼ確実に古くなり、コード本体に手を入れて分岐を書き直す必要が出る。

✅ 良い例: 汎用判定 (Provider/Class) だけコードに書き、具体名はテーブルに閉じる:

```wolfram
(* コード側: Provider と Class 単位の汎用判定だけ *)
iResolveByProviderClass[provider_String, class_String] := ...

(* テーブル側: $ClaudeModelCapabilities に登録するだけ *)
$ClaudeModelCapabilities["gpt-5"]   = <|"Class"->"Heavy-Cloud", "Provider"->"openai", ...|>;
$ClaudeModelCapabilities["gpt-4.1"] = <|"Class"->"Heavy-Cloud", "Provider"->"openai", ...|>;
```

未登録モデルが来たら、`Provider` を文字列マッチで取り出して同じ `Class` の登録モデルにフォールバック、というロジックを汎用に書く。Provider 名 (`"openai"`, `"anthropic"`, `"lm-studio"`) はそう変わらないので、ここまでなら `.wl` に書いてよい。

### (2) LLM 生成プロンプトを `.wl` の文字列リテラルに書かない

❌ 悪い例:

```wolfram
$petriNetGuideExtras = "
# Provider selection for LLM calls
When the user goal involves multiple LLM providers...
Use ClaudeCode`ClaudeQueryBg with the Model option:
  review = ClaudeCode`ClaudeQueryBg[..., Model -> {\"openai\", \"gpt-5\"}, ...]
...
";
```

✅ 良い例:

- `skills/petri-multi-provider-generation/SKILL.md` に内容を書く。
- `.wl` 側はロード時に skill ディレクトリから読み込む:

```wolfram
$petriNetGuideExtras := iReadSkillBody["petri-multi-provider-generation"];
```

skill 本体の編集は `.wl` 改変なしに反映される。

### (3) 反パターン・ベストプラクティスを `.wl` のコメントだけに書かない

`Quiet@Check` を使うな、`gpt-5` を `gpt-4o` に書き換えるな、のような「LLM が読むべき指示」は `wolfram-syntax-pitfalls` のような skill に集約する。`.wl` のコメントだけで管理すると LLM のコンテキストに入らない。

### (4) 個別プロバイダの API 仕様

OpenAI / Anthropic / LM Studio それぞれのリクエスト形式・エラー応答パターン・レート制限の文言など、外部仕様に依存する細部は skill に。コード本体は汎用的なエラー判定 (`iIsAPIErrorResponse[response]`) を経由する。

## `.wl` に書いてよいもの

- 構造化データ (`$ClaudeModelCapabilities` のような Association、Schema 定義、enum)
- ロジック (関数本体、状態遷移、データ変換、制御フロー)
- 公開 API のシグネチャと `::usage` 文字列
- パッケージの依存関係 (`Needs`/`BeginPackage`)
- 静的な定数 (バージョン文字列、デフォルト値、無害な閾値)

## 判定の指針

迷ったときに自問する 2 つの問い:

1. **「これは半年後・1 年後にも有効か?」**
   - `Yes` (または「変わらない」) → `.wl` に書いてよい
   - `No` または `わからない` → skill / rules に書く

2. **「これは LLM が読んで真似る雛形か?」**
   - `Yes` → skill / rules に書く (LLM のコンテキストに自動注入される)
   - `No` (実行時にしか参照されないロジック・データ) → `.wl` に書いてよい

両方の問いで答えが分かれた場合は、より安全な方 (skill 側) に倒す。

## 既存違反の移行手順

`.wl` に既にハードコードされている違反を発見したら:

1. **対応する skill が既にあるか確認**
   - 例: モデル指定方法 → `petri-multi-provider-generation`
2. **無ければ skill を新設** (`skills/<name>/SKILL.md`)
3. `.wl` 側は skill の本文をロード時に読み込む形に変える
4. 関連する .wl の test を、skill 内容変更で壊れない構造に直す
5. CHANGELOG にこのルール (02) 適用記録を残す

破壊的変更の場合、`ClaudeUpdatePackage` でバックアップを取りつつ進める。

## 関連

- `skills/llm-instruction-separation` — 移行作業の具体手順とテンプレート集
- `skills/petri-multi-provider-generation` — 旧 `$petriNetGuideExtras` の置き場 (Petri net handler の Provider/Model 指定)
- `skills/wolfram-syntax-pitfalls` — `.wl` の生成時にコード生成 LLM が踏みやすい罠
- `rules/11-core-package-dependency.md` — 基盤パッケージの依存方向制約 (本ルールと相補的)

## 寿命

このルールは継続適用。`.wl` と skill の境界はパッケージのライフサイクル全体を通じて保持する。
