---
name: wolfram-syntax-pitfalls
description: |
  Wolfram Language で踏みやすい syntax / semantic / 評価モデルの罠とその
  確実な回避策をまとめた skill。Mathematica で大規模パッケージを書くときに
  繰り返し遭遇する未文書化挙動・優先順位ミス・スコープ問題などを記録する。
  特に Module / Return / Catch/Throw / Quiet/Check / 評価スタックの相互作用
  には未文書化の罠が多いため、最初から「何を使わない」と決めて純粋な
  if/else 評価で組むのが最も安全。
---

# Wolfram Language の罠集

このドキュメントは、ClaudePackageManager 開発で実際に踏んだ罠とその検証済み
回避策の累積記録。新規 Wolfram コードを書くときに参照することで、同じ罠を
再度踏むことを避けられる。

## A. Association / List 操作の罠

### 罠 #1: `ReplacePart` で新規 Association キーは追加できない

```mathematica
ReplacePart[<|"a" -> 1|>, "b" -> 2]   (* 静かに無視 → <|"a" -> 1|> *)
```

`ReplacePart` は **既存** の position / key に対する書き換え専用。新規キー追加には
`Append[assoc, key -> value]` を使う。

```mathematica
Append[<|"a" -> 1|>, "b" -> 2]   (* → <|"a" -> 1, "b" -> 2|> ✓ *)
```

## B. 文字列 / パターンの罠

### 罠 #2: `StringExpression` の `_` は任意 1 文字ではない

`_` は Pattern Blank (任意の式) で、`StringExpression` の文脈でも String の
任意 1 文字にはマッチしない。任意 1 文字には `LetterCharacter`, `DigitCharacter`,
`WordCharacter` などの専用パターンを使う。

```mathematica
StringMatchQ["abc", "a" ~~ _]         (* False ←期待外れ *)
StringMatchQ["abc", "a" ~~ LetterCharacter]  (* True ✓ *)
```

### 罠 #11: 文字列リテラル内の Unicode エスケープは `\:XXXX`

Mathematica は `\u3002` を **未知エスケープ** として error にする。Unicode 文字を
文字列リテラルに埋め込むには `\:XXXX` 形式 (4 桁 hex) を使う。

```mathematica
"\u3002"   (* ✗ Syntax error *)
"\:3002"   (* ✓ 「。」 (句点) *)
```

## C. 演算子優先順位の罠

### 罠 #9: `UnsameQ` 演算子は `=!=` (`!==` ではない)

JavaScript / Python と違い `!==` は構文エラー (Syntax::sntx)。

```mathematica
a !== b   (* ✗ Syntax error *)
a =!= b   (* ✓ UnsameQ *)
```

### 罠 #14: `&` の作用範囲が読みにくい場合は `Function[]` で明示

```mathematica
AnyTrue[list, AssociationQ[#] && Lookup[#, "Status", ""] =!= "OK" &]
```

`&` の終端と `&&` の優先順位が読み取られにくく、評価結果が想定と異なる
ケースが起こりうる。確実にしたければ `Function[]` で明示する。

```mathematica
AnyTrue[list,
  Function[entry,
    AssociationQ[entry] && Lookup[entry, "Status", ""] =!= "OK"]]
```

同様に、`_Association?(test)` も場合により `e_Association /; condition` の方が
明確:

```mathematica
Count[list, _Association?(Lookup[#, "Status", ""] === "OK" &)]
Count[list, e_Association /; Lookup[e, "Status", ""] === "OK"]   (* より明確 *)
```

## D. Module / スコープ / 評価制御の罠

### 罠 #12: ネストした Module 内の `Return[]` は内側 Module だけを抜ける

```mathematica
Module[{outer},                  (* 外側 Module *)
  Module[{inner},                (* 内側 Module *)
    Return[$Stop]                (* 内側 Module だけ抜ける ! *)
  ];
  (* ここから先は実行され続ける *)
  ...
]
```

関数全体を抜けるつもりで `Return[]` を書いても、`Module` がネストしていると
**最も内側の Module だけ** が抜けて、外側関数の処理は継続する。回避策:

1. **内側 Module を撤廃** して外側関数 Module 直下に書く
2. `Return[expr, Module]` で抜ける構造を明示する (ただし罠 #15 参照)

### 罠 #15: Map で `Function` を評価した後の `Return` は message を発する

```mathematica
fileExportResults = Map[Function[entry, Module[..., Quiet @ Check[...]]], list];
...
Return[<|"Status" -> "Committed", ...|>, Module]
```

Map 評価で `Function[entry, Module[...]]` が評価された **後** で、その後の
`Return[expr]` または `Return[expr, Module]` を呼ぶと、Mathematica が
**未文書化の message** を発生させる。

その結果、関数を `Quiet @ Check[fn[arg], $Failed]` でラップして呼ぶと、
**messages 0 件にもかかわらず Check が `$Failed` フォールバック** に飛ばす
(罠 #16 と複合)。

回避策: **そもそも `Return` を使わず、フラグ変数 + `If[earlyResult === None, ..., earlyResult]` で gate** する (罠 #15 のオフィシャル解、罠 #16 もまとめて回避できる)。

### 罠 #16 (最重要): `Quiet @ Check[expr, $Failed]` は messages 0 件でも `$Failed` を返すことがある (未文書化)

```mathematica
result = Quiet @ Check[fn[effectiveArg], $Failed];   (* iRetryableInvoke 内 *)
```

documentation 上は「expr 評価中に message が発生したら failexpr を返す」だが、
実際には:

- 直接呼び出し `direct1 = fn[arg]` → Association を返す。`$MessageList = {}` 確認済み
- ラップ呼び出し `direct2 = Quiet @ Check[fn[arg], $Failed]` → **`$Failed` (Symbol)** を返す。`$MessageList = {}` でも変わらず

つまり Mathematica は `Quiet @ Check` の文脈で **message 以外の何か** で fail を
判定している。Catch/Throw 撤去 (v14)・Return 撤去 (v14)・debug Print 撤去 でも
症状継続。

**回避策: `Quiet @ Check` を使わず、`fn[arg]` を直接呼ぶ retry loop に変える**:

```mathematica
(* 旧 (罠あり): *)
result = Quiet @ Check[fn[effectiveArg], $Failed];

(* 新 (確実): *)
result = fn[effectiveArg];
(* fail は戻り値で判定 *)
If[!AssociationQ[result] || Lookup[result, "Status", ""] === "Failed",
  classification = "Retryable", ...]
```

**教訓**: Mathematica の `Quiet @ Check[..., $Failed]` は signal handling として
fragile。production では戻り値ベースの fail 判定を選ぶこと。

## E. パッケージロード / 依存解決の罠

### 罠 #13: `Needs["Pkg`", "Pkg.wl"]` は `$Path` で `Pkg.wl` を探す

```mathematica
Needs["NBAccess`", "NBAccess.wl"]   (* `$Path` 内を探す *)
```

`<<` でロードしただけのカレントディレクトリは **`$Path` に含まれない**。
ClaudeOrchestrator.wl のような package を独立にロードする場合、依存パッケージが
同じディレクトリにあっても `$Path` に通っていなければ Needs が失敗する。

回避策: `$InputFileName` から自パッケージのディレクトリを取り、`Block[]` で
一時的に `$Path` に prepend する:

```mathematica
Block[{$CharacterEncoding = "UTF-8",
       iOrchPkgDir = Which[
         StringQ[$InputFileName] && $InputFileName =!= "",
           DirectoryName[$InputFileName],
         StringQ[Quiet @ Symbol["Global`$packageDirectory"]],
           Symbol["Global`$packageDirectory"],
         True, Directory[]]},
  Quiet @ Block[{$Path = Prepend[$Path, iOrchPkgDir]},
    Needs["NBAccess`", "NBAccess.wl"]]]
```

## F. テスト / 開発支援の罠

### 罠 #10: `MUnit TestResultObject` は indexed access `r[key]`

```mathematica
Lookup[r, "key"]   (* ✗ 動作しない *)
r["key"]            (* ✓ *)
```

## まとめ: 「使わない方が安全」リスト

経験的に以下は **production code で避けた方が安全**:

| 機能 | 理由 | 代替 |
|---|---|---|
| `Return[expr]` (form なし) | 罠 #12, #15 | フラグ変数 + If gate |
| `Catch/Throw` | 罠 #15 (Check と相性悪) | フラグ変数 + If gate |
| `Quiet @ Check[..., $Failed]` | 罠 #16 (未文書化) | direct call + 戻り値判定 |
| ネスト `Module[...]` | 罠 #12 | 外側 Module 直下に展開 |
| Module 内 関数定義 (DownValues) | 衝突可能性 | 関数定義はトップレベル / stack-based ループ |

## 適用タイミング

- 新規 Wolfram code を書くとき: 「使わない方が安全」リストを最初から守る
- 既存 code をデバッグするとき: $Failed が説明できないなら罠 #16 を疑う
- `Return` で抜けないなら罠 #12 / #15 を疑う
- `\u` エスケープでエラーが出たら罠 #11 を疑う
- `Needs` が見つからないと言ってきたら罠 #13 を疑う
