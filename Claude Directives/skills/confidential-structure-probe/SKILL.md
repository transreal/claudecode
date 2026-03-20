---
name: confidential-structure-probe
description: Use when ClaudeEval needs to generate code that depends on confidential or confidential-dependent variables whose structure (type, dimensions, keys) is unknown. Generates structure-probing code first, then actual code after ContinueEval.
---

# 秘密変数の構造調査手順

制約は `rules/60-confidential-structure.md` に従う。このスキルは構造調査の具体パターンを定める。

## いつ使うか

- プロンプトの Output 一覧にスキーマ情報が含まれていない秘密変数を使う必要があるとき
- `$NBSendDataSchema = True` の場合、秘密依存 Output にはスキーマ情報（データ型・キー・サイズ等）が
  自動的に含まれるため、**まず Output 一覧を確認すること**
- スキーマ情報が `(* [機密依存データ: Dataset, columns: {学生, 中間成績, 期末成績}] *)` のように
  表示されている場合、構造調査は不要。そのスキーマ情報を使ってコードを書く
- Output 一覧にスキーマ情報がない場合（取得失敗、または変数が Output に現れていない場合）のみ、
  以下の構造調査手順を使う

## 構造調査コードのパターン

変数 `x` の構造が不明な場合に出力するコード:

```mathematica
(* 構造調査 — ContinueEval[] で続けてください *)
Column[{
  "Head"       -> Head[x],
  "Dimensions" -> Quiet[Dimensions[x]],
  "Keys"       -> Quiet[Keys[x]],
  "Length"     -> Quiet[Length[x]],
  "Type"       -> Quiet[TypeSystem`InferType[x]],
  "Short"      -> Short[x, 3]
}, Left]
```

## 出力時のテキスト

コードブロックの前に以下の説明テキストを付ける:

```
変数 `x` は秘密変数のため構造が不明です。まず構造を調査します。
上のセルを実行後、ContinueEval[] で本コードを生成します。
```

## ContinueEval 後の処理

ContinueEval が呼ばれると、セッション履歴に構造調査の結果（Head, Keys, Dimensions 等）が含まれる。その情報をもとに:

1. 構造情報から適切な型・キー・次元を読み取る
2. 本来のコードを生成する
3. Dataset なら Keys で列名を特定し、Association なら構造に沿ったアクセスを書く

## 複数の秘密変数がある場合

1つのコードブロックで複数変数の構造をまとめて調査する:

```mathematica
(* 構造調査 — ContinueEval[] で続けてください *)
Column[{
  Style["secretData:", Bold],
  "  Head" -> Head[secretData], "  Keys" -> Quiet[Keys[secretData]],
  "",
  Style["secretConfig:", Bold],
  "  Head" -> Head[secretConfig], "  Keys" -> Quiet[Keys[secretConfig]]
}, Left]
```
