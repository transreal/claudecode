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

## 秘密変数の構造情報の自動送信

`$NBSendDataSchema = True`（デフォルト）の場合、秘密依存の Output セルについて
データ型・サイズ・キー等のスキーマ情報が LLM コンテキストに自動的に含まれる:

```
Out[20]= (* [機密依存データ: Dataset, columns: {学生, 中間成績, 期末成績}] *)
Out[5]= (* [機密依存データ: Association, 3 keys: {name, age, salary}] *)
Out[8]= (* [機密依存データ: List, ~100 elements] *)
```

このため、NonConfidential[] でキーを手動出力する必要はない。
構造調査コードは、スキーマ情報が得られない場合のフォールバックとして使用する

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
