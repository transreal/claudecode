---
paths:
  - "**/*.{wl,wls,m,nb}"
---

# 秘密変数の構造推測禁止

## 必須
- ClaudeEval で秘密変数（Confidential でマークされた変数、または推移的依存変数）の構造が必要な場合、構造を推測してコードを書いてはならない。
- 必ず構造調査コードを先に出力し、ContinueEval で構造情報を確認してから本コードを生成すること。

## 禁止
- 秘密変数の型・次元・キー構造を推測してコードを生成すること。
- 秘密変数の値をプロンプトに含めるよう要求すること。

# 秘密変数への代入（必須）

## トリガーキーワード
以下のいずれかがユーザーの指示に含まれる場合、**必ず** `Confidential[...]` でラップして代入する:
- 「秘密変数」「機密変数」「秘匿変数」
- 「秘密」「機密」「秘匿」（変数代入の文脈で）
- 「Confidentialにする」「Confidentialに代入」「Confidentialへ代入」
- 「秘密にする」「機密にする」「秘匿にする」「秘匿せよ」
- 「<<var>>に代入して秘匿」

## 正しいパターン
```mathematica
(* 秘密変数 scores へ代入 *)
scores = Confidential[First @ Import[FileNameJoin[{NotebookDirectory[], "成績.xlsx"}], {"Dataset"}]]
```

## 禁止パターン
```mathematica
(* NG: 事後的にセルマーキング *)
scores = First @ Import[...];
NBMarkCellConfidential[EvaluationCell[]]
```

## Dataset のキー公開（必須）
Dataset を秘密変数としてインポートするとき、2つのコードブロックを出力する:
1. `Confidential[...]` でデータ本体を秘匿
2. `NonConfidential[Row[{"変数名のキー: ", Normal[Keys[変数名[[1]]]]}, " "]]` でキー情報を公開

これにより後続の ClaudeEval / ContinueEval がキー情報をコンテキストとして利用できる。

# 機密解除（NonConfidential）

## 概要
- `NonConfidential[expr]` は、秘密変数に依存する値であっても機密解除として扱う。
- Input/Output セルの confidential タグを明示的に `False` に設定する。
- CellEpilog / ScanConfidentialCells による自動伝播マーキングをスキップする。

## 正しいパターン
```mathematica
result = NonConfidential[Mean[secretData]]
summary = NonConfidential[Length[confidentialList]]
```
