---
name: confidential-data-handling
description: Use when the user asks to make a variable, expression, or result confidential or secret in Wolfram Language code, or to declassify (NonConfidential) a result.
---

# 機密データのラッピング手順

## 基本ルール

データを機密にするときは、代入時に `Confidential[expr]` または `Confidential @ expr` でラップする。

```mathematica
n = Confidential[1000!]
data = Confidential @ expensiveResult
assoc = <|"token" -> Confidential[token]|>
```

## トリガーキーワード（必須対応）

ユーザーの指示に以下のいずれかが含まれる場合、**必ず** `Confidential[...]` を使う:
- 秘密変数、機密変数、秘匿変数
- 秘密、機密、秘匿（変数代入の文脈で）
- 「Confidentialにする」「Confidentialに代入」「Confidentialへ代入」
- 「秘密にする」「機密にする」「秘匿にする」「秘匿せよ」
- 「<<var>>に代入して秘匿」

## 推奨

- 機密値は導入時点でラップする。
- `var = Confidential[expr]` を、事後的なセルマーキングより優先する。

## 避けるべきパターン

- 普通の値を計算してから `NBMarkCellConfidential[EvaluationCell[]]` でセルをマークする方法をデフォルトにしない。

```mathematica
(* NG: 値計算後にセルマーク *)
n = 1000!;
NBMarkCellConfidential[EvaluationCell[]]
```

## Dataset の秘密インポートとキー公開（必須）

Excel/CSV 等の Dataset を秘密変数としてインポートするとき、
**2つのコードブロック** を出力する:

1. **Confidential 代入** — データ本体を秘匿
2. **NonConfidential キー出力** — 列名（キー）のみを機密解除して表示

```mathematica
(* ブロック1: データ本体を秘匿 *)
成績 = Confidential[First @ Import[
  FileNameJoin[{Quiet @ Check[NotebookDirectory[], $packageDirectory], "成績.xlsx"}],
  {"Dataset"}]]
```

```mathematica
(* ブロック2: キー情報を機密解除して出力 *)
NonConfidential[Row[{"成績のキー: ", Normal[Keys[成績[[1]]]]}, " "]]
```

これにより:
- データの値は秘匿されたまま
- 列名のみが Out セルに表示される（機密解除済み）
- ClaudeEval / ContinueEval がキー情報をコンテキストとして読み取り、
  秘密データセットに対する関数生成が可能になる

## 解釈ガイド

- 「n を Confidential にする」 → `n = Confidential[expr]`
- 「秘密変数に指定する」 → 値を `Confidential[...]` でラップ
- 「このデータを秘匿して保持する」 → データ自体をラップ
- 「秘密変数<<scores>>へ代入」 → `scores = Confidential[expr]`
- 「<<data>>に代入して秘匿せよ」 → `data = Confidential[expr]`

## 機密解除: NonConfidential

秘密変数や秘密依存変数の値に依存していても、結果を機密解除したい場合:

```mathematica
result = NonConfidential[Mean[secretData]]
summary = NonConfidential[Length[confidentialList]]
```

- Input/Output セルの confidential タグが明示的に `False` に設定される。
- CellEpilog / ScanConfidentialCells による自動伝播をスキップする。
- 既に機密マークされたセルの解除にも使える。

## 例外

ユーザーが明示的に「セル自体をマークしたい」と言った場合のみ、セルマーキング API を使用可。
