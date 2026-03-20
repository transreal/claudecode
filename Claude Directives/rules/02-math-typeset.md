---
paths:
  - "**/*.{wl,wls,m,nb}"
---

# 数式タイプセットルール

## 概要
NBAccess の NBWriteCode / NBWriteSmartCode は、**安全な数式のみ** `MakeBoxes[StandardForm]` で
タイプセットして Inputセルに挿入する。これにより `Integrate` → ∫, `Sum` → Σ,
`Subscript[q, m]` → 下付き文字, `Sqrt` → √ 等の美しい数式表示が得られる。

**注意**: `Module`, `Block`, `With`, `Show`, `Plot`, `Graphics`, `Manipulate`, `CompoundExpression`
等の手続き的コードは FEParser でレンダリングされ、MakeBoxes タイプセットされない。
これは変数スコーピングや Graphics 構造を保護するための設計。

## テキスト説明での LaTeX 数式（推奨）
説明テキスト中の数式は **LaTeX `$...$` 表記を積極的に使う**。
`iTeXMathToCell` が `ToExpression[TeXForm]` で Mathematica タイプセット式に自動変換する。

### 推奨例
- `$\nabla^2 \varphi = 0$` → ∇²φ = 0（タイプセット表示）
- `$\pm q_m$` → ±qₘ
- `$\mathbf{B} = -\mu_0 \nabla \varphi$` → **B** = -μ₀∇φ
- `$\int \sin x \, dx$` → ∫ sin x dx

### 注意
- `$$...$$`（ディスプレイ数式）は使わない。`$...$`（インライン）のみ。
- 変換に失敗した場合は元の `$...$` テキストがそのまま表示される。

## コメント禁止（コードブロック内）
- `MakeBoxes` は `ToExpression[InputForm, HoldComplete]` を経由するため、
  `(* ... *)` コメントはパース時に除去される。
- **```mathematica コードブロック内にコメントを書いてはいけない。**
- 説明はコードブロック外のテキストとして記述する。

## Box構文・表示文字の文字列内使用禁止
- `\!\(\*SuperscriptBox[...]\)` 等のインラインBox構文を文字列内で使ってはいけない。
- `\[Superscript]`, `\[Subscript]` 等の表示用名前付き文字を文字列内で使ってはいけない。
- ラベルやタイトルで数式を表示する場合は、`Row`, `Superscript`, `Subscript` 等の
  **式（Expression）**として組み立てる。

## 推奨パターン
- 数学関数は標準の Mathematica 関数呼び出し形式を使う:
  `Integrate[f, x]`, `Sum[expr, {i, 1, n}]`, `Product[...]`, `D[f, x]`
- 下付き・上付き: `Subscript[q, m]`, `Superscript[x, n]`
- 行列表示: `MatrixForm[...]`
- ギリシャ文字: `\[CurlyPhi]`, `\[Mu]`, `\[Pi]` 等

## 複数ブロックへの分割
- 独立した計算ステップは別々のコードブロックに分ける
- 各ブロックの前に簡潔な説明テキストを置く
