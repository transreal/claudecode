---
paths:
  - "**/ClaudeOrchestrator*.{wl,wls,m,nb}"
  - "**/ClaudeTestKit*.{wl,wls,m,nb}"
  - "**/*slide*.{wl,wls,m,nb,md}"
  - "**/*presentation*.{wl,wls,m,nb,md}"
keywords:
  - "スライド"
  - "プレゼン"
  - "発表資料"
  - "slide"
  - "slides"
  - "presentation"
  - "deck"
---

# 98 — スライド作成スキル (ClaudeOrchestrator 経由)

このスキルは `ClaudeOrchestrator.wl` の slide 生成機構 (Phase 33 の T04-T08 で確立) を使う際のルール集約である。スライド作成を依頼された場合、このドキュメントに記載の **原則 24-31** を遵守する。

## 使いどころ

ユーザが次のような依頼をしてきたとき、このスキルが発動する:

- 「○○ の発表資料を作って」
- 「30 ページのスライドを作成して」
- 「スライドにして」「slides にまとめて」「deck を作って」
- OutputSchema に `SlideDraft`, `Slides`, `Pages`, `SlideOutline` 等のキーを要求

## 基本動作 (T07/T07b/T08 後)

1. `ClaudeOrchestrator.wl` が `iDetectSlideIntent` で **入力文から slide 意図を自動検出** する (原則 24)
2. 検出時は `ClaudeEvalHook` が `iResolveTargetNotebook` を呼び、**新規 notebook に書き込む** (原則 28 = T07b)
3. 新規 notebook は `$ClaudeSlidesTemplatePath` または `$packageDirectory/Templates/slides-template.nb` の **スタイル定義を継承** (原則 29 = T08)
4. worker は slide-aware hint を受け、**図/画像/Grid 2 段組**を Kind フィールドで指示可能 (原則 30 = T08)
5. caller が `"ReferenceText" -> samples` を渡せば、**サンプルスライドの言い回しを真似る** (原則 31 = T08)

## 原則一覧 (スライド関連)

### 原則 24 — 入力意図の内容ベース検出

スライド生成タスクかどうかは、**入力文字列の中身** から検出する。 キーワード (スライド/slide/プレゼン/deck/発表資料/powerpoint/keynote) と **ページ数** (半角・全角数字 + "ページ"/page/pages/slide/slides) を組み合わせ、 `iDetectSlideIntent` が `{IsSlide, PageCount, Keywords}` を返す。

→ この結果に応じて planner, worker, committer すべてが挙動を変える (intent-aware)。

### 原則 25 — enum/style/kind は allowlist で sanitize + 意味救出

LLM は `"Subsection (title slide)"` のようなプローズを Style フィールドに返すことがある。`iSanitizeCellStyle` が `$iValidCellStyles` と照合し、 括弧/記号で split、 単語境界でマッチ、 最後に `"Text"` に fallback する。

→ 「LLM が自由に書ける欄」には必ず白いリスト+意味救出レイヤを置く。

### 原則 26 — LLM が対象言語向けに書くコードでは、対象言語のエスケープ規則を守る

LLM は Python/JS の `\u4e00` のような Unicode エスケープを書き出すことがあるが、Mathematica のそれは `\:4e00` である。 package ロード時に `Syntax::stresc` warning が大量に出て、 最悪無効バイトが混入する。 → package 生成時は必ず対象言語仕様に従ったエスケープに変換する。

### 原則 27 — 基本構文は単体で throw しないことを確認してから統合

`16^^FF10` (正) と `16rFF10` (無効) のような、 他言語の慣習と衝突する基本構文は、 LLM が書いたコードを load するだけでは発覚しない (parse は通るが evaluate 時に throw)。 → 新設関数は単体で 1 回呼んで throw しないことを確認してから統合テストへ。

### 原則 28 — 破壊的書込みはユーザ作業領域に入れず、新規コンテナにルーティング

LLM 指揮の大量書込み (30 ページスライド = 数百 cells) を `EvaluationNotebook[]` = ユーザの編集中 notebook に書くと事故の温床。 slide intent 検出時は `iResolveTargetNotebook` が `CreateDocument[{}]` で新規 notebook を作る。 `CreateNotebook` 禁止の committer 不変条件は保持 (nb を作るのは committer ではなく **オーケストレーション層**)。

### 原則 29 — 出力スタイル継承は caller 可変 symbol で

`Normal use.nb` / `slides-template.nb` のような style file は環境依存なので、package 内に埋め込まない。 `$ClaudeSlidesTemplatePath` を公開し、 ユーザが明示設定するか、 `$packageDirectory/Templates/slides-template.nb` を自動検出 (fallback)。 `CreateDocument[..., StyleDefinitions -> path]` で継承させる。

### 原則 30 — SlideDraft の cell 形式は Kind フィールドで拡張

Style + Content だけだとテキストセルしか作れず、スライドは箇条書きの羅列になる。 `"Kind"` フィールドで次を dispatch:

| Kind | 入力フィールド | 生成される Cell | 用途 |
|------|---------------|----------------|------|
| 無し (legacy) | `Style`, `Content` | `Cell[content, style]` | 見出し/本文/箇条書き |
| `"Input"` / `"Code"` | `Content` | `Cell[_, "Input"]` | Mathematica コード (ユーザ評価) |
| `"Graphics"` | `HeldExpression` | `Cell[BoxData[ToBoxes[ToExpression[expr]]], "Output"]` | 事前評価の図 |
| `"ImagePath"` | `Path` | `Cell[BoxData[ToBoxes[Import[path]]], "Output"]` | ファイル画像 |
| `"Grid2Col"` | `Left`, `Right` | `Cell[BoxData[GridBox[{{l, r}}]], "Output"]` | 2 列レイアウト (Mathematica に段組無し代替) |

再帰的: `Grid2Col` の中身も `Kind` を指定できる。 全て評価/Import 失敗時は安全な text fallback (原則 25 継承)。

### 原則 31 — LLM の語調を真似させるにはサンプル本文注入が最強

「柔らかい言い方で」「です・ます調で」のようなメタ指示は弱い。 **過去のスライド本文 4000 文字程度** を worker prompt に注入して「これに寄せろ」と言う方が遥かに強い。 `"ReferenceText" -> text` オプションを `ClaudeRunOrchestration` に渡すと、 `iBuildSlideWorkerHint` が prompt に明示的な参考セクションを挿入する。

## 図・画像を入れるべき場面 (worker 向けガイド)

`iBuildSlideWorkerHint` が LLM に与えるガイドの要約:

**入れる**:
- データの視覚化が本質的に重要なトピック (グラフ、対表、ダイアグラム、アーキテクチャ図)
- 概念間の関係 (状態機械、変換関係、シーケンス図)
- Mathematica の計算サンプルを示すとき (Plot/Plot3D/Manipulate/Graphics)
- ニュアンス程度の図像 (パスが確実なときのみ ImagePath)

**入れない**:
- 単純な箇条書きだけで足りるページに意味もなく図を添える (逆効果)

## 2 段組レイアウト

Mathematica notebook には段組機能がないため、疑似的に `Grid` を使う。 日本語レイアウトが崩れやすいので、次のパターンが現実的:

```json
{ "Kind": "Grid2Col",
  "Left":  { "Kind": "Input", "Content": "Plot[...]" },
  "Right": { "Style": "Text", "Content": "この図の解説" } }
```

あるいは、スライド全体を 1 枚の画像として生成して `ImagePath` で貼り付ける戦略も有効 (`20260309-SIGNAC_SOMA研究会.nb` の複数ページで採用)。

## 使用例

### ユーザが直接 ClaudeRunOrchestration を呼ぶ場合

```wolfram
Needs["ClaudeOrchestrator`"];
ClaudeOrchestrator`$ClaudeSlidesTemplatePath =
  "/path/to/my-template.nb";   (* 任意 *)

refSamples = Import["~/past_slides_excerpt.md"];

ClaudeRunOrchestration[
  "30 ページのスライドを作成。テーマ: X/Y/Z について",
  "Planner"              -> "LLM",
  "WorkerAdapterBuilder" -> "LLM",
  "ReferenceText"        -> refSamples]
```

### ClaudeEval 経由 ($ClaudeEvalMode = "Auto")

```wolfram
$ClaudeEvalMode = "Auto";
ClaudeEval["30 ページのスライドを作成..."   (* \[Rule] 新規 nb に書き込む *),
  "ReferenceText" -> refSamples]
```

## テスト

- `RunT07SlideIntentTests[]` (6 tests) — 原則 24/25/28 の単体検証
- `RunT08SlideTemplateTests[]` (3 tests) — 原則 29/30/31 の単体検証 
- `RunT06SlideContentTests[]` / `RunT05CommitFallbackTests[]` — 回帰

新規 Kind を足すときは `AssertT08KindDispatch` にケース追加。

## 注意事項

1. 箇条書きテキストで十分なページに、 わざと図を入れない (LLM の暴走を抑える)
2. `Kind: ImagePath` は絶対パスが確実に存在する場合のみ使わせる (存在しない場合は text fallback するが、 ユーザから見ると空セルが並ぶ)
3. `$ClaudeSlidesTemplatePath` に無効パスを入れると `CreateDocument` が失敗し、 `EvaluationNotebook` に fallback する (→ ユーザ作業 nb が汚れる)。 パス設定時は `FileExistsQ` で確認するのが望ましい
4. `ReferenceText` は 4000 文字で切り詰められる。 長い場合は最も語調を表すセクションを抽出しておく
