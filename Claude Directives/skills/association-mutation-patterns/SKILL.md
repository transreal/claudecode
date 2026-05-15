---
name: association-mutation-patterns
description: Mathematica で Association を更新するときの安全パターン。ReplacePart は新規キー追加に使えない、Append / Join / AssociateTo / MapAt の使い分け、ネスト Association の更新方法を扱う。Use when writing or reviewing Wolfram Language code that mutates Association data structures (token registries, configuration maps, state objects), especially when adding new keys to nested structures.
---

# Association mutation パターン

## 主要な罠

> **`ReplacePart` で Association に新規キーを追加することはできない**

`ReplacePart` は元来 List 用の関数で、Association に対しては **既存キーパスへの置換のみ動作** する。新規キー追加は**静かに無視される** (エラーも warning も出ない)。Stage B Day 2 (ClaudeOrchestrator`Workflow` 実装中) で実際に踏んだ罠で、テストの一部が失敗するまで気づかなかった。

```mathematica
(* これは動かない (新規キー "b" は追加されない) *)
ReplacePart[<|"a" -> 1|>, {"b"} -> 2]
(* 結果: <|"a" -> 1|> *)

(* ネストの場合も同じ *)
ReplacePart[<|"x" -> <||>|>, {"x", "newKey"} -> "value"]
(* 結果: <|"x" -> <||>|>  ← newKey が追加されない *)
```

## 判定表

| 操作 | 推奨関数 | 例 |
|---|---|---|
| 既存キーの値を置換 | `ReplacePart` | `ReplacePart[a, "k" -> v]` |
| 新規キーを追加 | `Append` | `Append[a, "newKey" -> v]` |
| 既存 + 新規を一括混在 | `Append` (新規も既存も両方処理) | `Append[a, key -> v]` |
| 複数 Association をマージ | `Join` または `Append` | `Join[a, b]` |
| 既存ネストパスの値を置換 | `ReplacePart` | `ReplacePart[a, {"k1", "k2"} -> v]` |
| ネストパスの一部キーが新規 | **NG**: ReplacePart 不可 | (下記パターン参照) |
| キーの削除 | `KeyDrop` | `KeyDrop[a, "k"]` または `KeyDrop[a, {"k1", "k2"}]` |
| 値を関数で変換 | `MapAt` または `<\| ... -> f[a[k]] \|>` | |

## 推奨パターン

### パターン 1: 単一キーの追加または置換

```mathematica
(* 既存キーでも新規キーでも安全 *)
newAssoc = Append[oldAssoc, "key" -> value]
```

`Append` は Association に対して既存キーは置換、新規キーは追加と正しく動作する。

### パターン 2: 複数キーの一括更新

```mathematica
(* 既存キーは置換、新規キーは追加、両方を一括処理 *)
newAssoc = Join[oldAssoc, <|"k1" -> v1, "k2" -> v2, "k3" -> v3|>]
```

### パターン 3: ネストパスへの新規キー追加

`ReplacePart[a, {"x", "newKey"} -> v]` が動かないので、二段階で書く。

```mathematica
(* "x" は既存、"newKey" は "x" の中で新規 *)
newAssoc = ReplacePart[oldAssoc,
  "x" -> Append[oldAssoc[["x"]], "newKey" -> value]]
```

または `MapAt` を使う:

```mathematica
newAssoc = MapAt[Append[#, "newKey" -> value]&, oldAssoc, "x"]
```

### パターン 4: グローバル registry の Association への新規キー追加

これはまさに Stage B Day 2 で踏んだケース。

```mathematica
(* NG (ReplacePart は新規キー追加できない) *)
AssociateTo[$registry,
  wid -> ReplacePart[wf, {"Tokens", tid} -> tokenAssoc]]

(* OK *)
AssociateTo[$registry,
  wid -> ReplacePart[wf,
    "Tokens" -> Append[wf[["Tokens"]], tid -> tokenAssoc]]]
```

## デバッグの目印

`ReplacePart` で新規キー追加が失敗すると、後続の `Lookup` や `[[key]]` で **`Missing["KeyAbsent", "..."]`** が返る。これが他の場所で `Part::pspec1` メッセージを引き起こす。

```text
Part::pspec1: Part specification "TokenId" is neither an integer nor a list of integers.
```

このメッセージが出たら、まず ReplacePart で新規キー追加を試みていないか確認する。**特に直前の VerificationTest が値は合っているのに `MessagesFailure` を返した場合**、これが原因の可能性が高い。

## テストでの検証

新規キー追加を行うコードには、必ず「キーが実際に追加されたか」を確認するテストを書く:

```mathematica
VerificationTest[
  Module[{a},
    a = SomeFunctionThatAddsKey[<|"existing" -> 1|>, "newKey", "newValue"];
    KeyExistsQ[a, "newKey"]
  ],
  True
]
```

存在確認だけでなく、**値の確認** も重要:

```mathematica
VerificationTest[
  Module[{a},
    a = SomeFunctionThatAddsKey[<|"existing" -> 1|>, "newKey", "newValue"];
    a[["newKey"]]
  ],
  "newValue"
]
```

## 関連する罠 (近い性質のもの)

- `wolfram-syntax-pitfalls`: `Module[{vars}, body]` の閉じ位置誤りなど syntax レベルの罠 (本 skill は意味レベルの罠)
- `package-merge-pattern`: 部分応答 merge / new-function insertion / safety validation
- `package-namespace-migration`: BeginPackage 依存リストなしによる shadowing

## 違反例 (Stage B Day 2 で実際に起きた)

```mathematica
(* ClaudeSubmitToken の旧実装 *)
AssociateTo[$iWorkflowNets,
  wid -> ReplacePart[wf,
    {{"Tokens", tid}                 -> tokenAssoc,    (* ← 新規キー、無視される *)
     {"Places", source, "TokenIds"}  -> Append[..., tid]}]]
```

症状: `Tokens` registry に token が登録されないため、後続の `ClaudeFireTransition` が binding を解決する際に `Missing["KeyAbsent", "tok-..."]` を取り出して `Part::pspec1` を出して落ちる。

修正:

```mathematica
(* 新規キーを Append で *)
newWf = ReplacePart[wf,
  "Tokens" -> Append[wf[["Tokens"]], tid -> tokenAssoc]];
(* existing path は ReplacePart で *)
newWf = ReplacePart[newWf,
  {"Places", source, "TokenIds"} -> Append[..., tid]];
```
