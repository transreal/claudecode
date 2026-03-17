---
paths:
  - "**/*.{wl,wls,m,nb}"
---

# Wolfram Language 基本制約

## 言語選択
- 実装言語は Wolfram Language を優先する。
- Python 連携が必要なら `ExternalFunction` / `ExternalEvaluate` 系を優先する。

## 禁止事項
- `ffmpeg` のパスをハードコードしない。
- 出力コードで `session` で始まる変数名を使わない。
- サンプルコードで `Clear["Global`*"]` や `Remove["Global`*"]` を使わない。
- ShiftJIS を前提にした実装を新たに入れない。
- Notebook スタイルで `Section` は使わない（`Subsection` / `Item` / `Text` を使う）。

## 数式の保持
- 数値が本当に必要になるまで、式は記号的に保持する。
- ベクトル・行列はベクトル・行列の形のまま処理する。
