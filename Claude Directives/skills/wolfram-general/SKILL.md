---
name: wolfram-general
description: Use for Wolfram Language / Mathematica coding, editing, notebook output style, package conventions, and overall implementation constraints in this environment. Especially relevant for .wl, .m, and .nb work.
---

# Wolfram Language 全般ルール

このスキルは Wolfram Language / Mathematica の作業全般で使う。

## コーディング方針

- 主言語は Wolfram Language とする。
- 新しい組み込み関数で自然に書ける場合は、古い回避策よりも最新の標準関数を優先する。
- **組み込み関数を使う前に、引数形・オプション・戻り値の型/形状を必ず Mathematica のドキュメント (`ref/<Name>`) で確認する。推測で書かない。** 特に data / import / plot / 外部連携系は戻り値の Head が想定と異なることが多い (例: 罠 #20 の `FinancialData` → `TimeSeries`)。戻り値の実際の Head に合わせて処理を書く。
- Python 連携が必要なときは `ExternalFunction` / `ExternalEvaluate` を優先候補にする。
- Java 連携が必要なときは J/Link の利用を許容する。
- Notebook スタイルは `Subsection` / `Item` / `Subitem` / `Text` を優先し、`Section` は使わない。
- 文字コードは UTF-8 を前提に扱う。

## 数式・データ表現の方針

- 可能な限り、定義された数式をそのまま保持して関数を作る。
- 数値代入が本当に必要になるまでは、できるだけ記号式のまま処理する。
- ベクトル・行列を扱う場合は、可能な限りベクトル・行列表現を保ったまま計算する。

## 出力方針

- 説明は必要十分にとどめ、冗長にしない。
- 数式は省略せず明示する。
- 可能なら短い動作確認コードや最小例を添える。

## 全体禁止事項

- ffmpeg のパスをハードコードしない。
- ShiftJIS を前提にした実装を新たに入れない。
- `session` で始まる変数名を出力コードで使わない。
- サンプルコードで `Clear["Global`*"]` や `Remove["Global`*"]` のような全消去をしない。
- 物理 PDE を、自前の手書き差分式・有限差分・統計サンプリングで安易に置き換えない。

## パッケージロード時のメッセージ

ロード完了メッセージは `CellPrint` ではなく `Print` を使う。タイトルは `Style[..., Bold]` で強調し、一覧は改行つき文字列で出す。

```mathematica
Print[Style["Mypackage パッケージがロードされました。", Bold]];
Print["
  func1[arg]   → 説明1
  func2[arg]   → 説明2
"];
```

## ファイルパス解決方針

- ファイル名だけが指定された場合（フルパスでない場合）は、`FileNameJoin[{NotebookDirectory[], ファイル名}]` でパスを構築する。
- `NotebookDirectory[]` が取得できない場合のフォールバックとして `Quiet @ Check[NotebookDirectory[], $packageDirectory]` を使う。
- `Import["ファイル名"]` のようにカレントディレクトリ依存のコードを生成しない。

## データ出力方針

- テーブル形式でデータを最終的に出力する場合は、可能な限り `Dataset` 形式で出力する。

## Excel インポート方針

- Excel ファイルを `Import` するとき、形式（`"XLSX"`, `"Dataset"` 等）によらず、シートが 1 枚だけの場合は結果に `First` または `[[1]]` を付けてリストを外す。
  - 例: `Import[file, "Dataset"] // First`
  - 例: `Import[file, {"XLSX", 1}]`
- シート数が不明な場合は `First @ Import[...]` をデフォルトとする。

## Wolfram トラップ一覧

実機で何度も踏んだ落とし穴。新規コードを書くときに該当箇所がないか必ず確認する。

### #9: UnsameQ は `=!=`、`!==` ではない
```mathematica
(* NG: Wolfram に !== はない *)
If[a !== b, ...]
(* OK *)
If[a =!= b, ...]
```

### #10: TestResultObject は indexed access、Lookup は使わない
```mathematica
(* NG: TestResultObject に Lookup は通らない *)
Lookup[testResult, "Outcome"]
(* OK *)
testResult["Outcome"]
```

### #11: Unicode escape は `\:XXXX`、`\uXXXX` ではない
```mathematica
(* NG: \u は文字列解釈で通らない、Get 時にエラー *)
"テスト\u3001"
(* OK *)
"テスト\:3001"
```
`grep -E '\\u[0-9a-f]{4}' file.wl` でチェックする習慣をつける。

### #13: `Needs[..., "Pkg.wl"]` は `$Path` に依存する
ファイル名指定の `Needs[name_, file_]` はファイル探索に `$Path` を使う。フルパス指定または `Get` を使うほうが安全。

### #14: `&` の優先順位は低い
```mathematica
(* 期待と違う: f & は (f) & ではなく Function[Slot[1], f] *)
Map[g[f, #] &, list]    (* OK: Function 全体を囲む & *)
Map[g[f, #] & , list]   (* 同じ *)
```
複雑な `&` は `Function[...]` の明示形のほうがバグらない。

### #15: Map+Function+Return/Throw は不可
```mathematica
(* NG: Map の中の Function 内 Return は外側 Module まで届かない、$Failed が返る *)
result = Map[Function[x, If[bad[x], Return[$Failed]]; x], list]
(* OK: Scan + Throw/Catch、または If 分岐で明示処理 *)
```
これは #16 の `Quiet@Check` 偽陰性と組み合わさるとさらに分かりにくくなる。

### #16: `Quiet @ Check[expr, $Failed]` は偽陰性
`Quiet` は Message を抑制するが、`Check` は Message 出現を検知して `$Failed` を返す。Quiet で Message が隠されていると Check は何も検知せず `expr` の評価結果を返す。
```mathematica
(* NG: 期待: $Failed   実際: 評価続行 *)
Quiet @ Check[badExpr, $Failed]
(* OK: Quiet のみ (例外として Message 出るだけは無視する場合) *)
Quiet[expr]
```
両方の意図がある場合は順序を入れ替える: `Check[Quiet[expr, msg::tag], $Failed]`。

### #17: コメント内の bare `*)` がコメントを早期終端する
```mathematica
(* NG: pattern Blank の例 *)
(* 例: f[x_, y_]) のような書き方   *)
(*                ↑ ここで早期終端 *)
```
コメント内に `*)` を含む引用が必要な場合はスペースで分ける: `* )`。

### #18: `ValueQ` は OwnValues のみ判定
Mathematica 14.x の `ValueQ[sym]` は **OwnValues** (`sym = value` 形式の代入) のみ判定する。`f[args] := body` 形式の本体定義 (DownValues) は **無視される**。
```mathematica
f[x_] := x^2;
ValueQ[f]               (* False  ← 落とし穴 *)
Length[DownValues[f]]   (* 1      ← こちらで判定する *)
```
本体定義の有無を判定したい場合は `Length[DownValues[sym]] > 0` を使う。

### #19: `Function[var, Module[{...}, body]]` の close `]` を見落とす
```mathematica
(* NG: Function を閉じる ] が欠落、Module は閉じてるが Function が未閉鎖 *)
Scan[
  Function[entry,
    Module[{a, b},
      ...body...
    ]],         (* ← Module の ] と Scan の , の間に Function の ] が必要 *)
  list]
```
`Scan[Function[..., Module[...]], list]` の構造で `]],` のように `]` が 2 個並ぶときは、
- 1 つ目: Module の close
- 2 つ目: Function の close
となるのを忘れない。深いネストでは Python などで括弧バランスを静的検証するのが確実 (例えば `(`, `)`, `[`, `]`, `{`, `}`, `<|`, `|>` の各々の閉じ忘れ判定)。

### #20: FinancialData など data 系は TimeSeries を返す (list ではない)
`FinancialData[id, prop, {start, end}]` は **`TimeSeries`** を返す (`{{date, value}, ...}` の list ではない)。`AdjustedClose` も有効プロパティで TimeSeries を返す。
```mathematica
(* NG: ListQ ゲートで TimeSeries が弾かれ、全系列が落ちてプロットが空になる *)
goodSeriesQ[d_] := ListQ[d] && Length[d] > 0 && AnyTrue[d, MatchQ[#, {_, _}] &];
(* OK: TimeSeries も受ける。ts["Path"] で {date, value} 列を得る *)
goodSeriesQ[ts_TimeSeries] := goodSeriesQ[ts["Path"]];
```
`ts["Path"]` の値は `Quantity` のことがあるので `QuantityMagnitude` で数値化する。「Approved / 動くはずなのにグラフが出ない」ときの典型。**戻り値の型は推測せずドキュメントで確認する**（コーディング方針参照）。data / import / plot / 外部連携系の組み込みは特に Head を確認すること。

### その他: Association 関連
- `ReplacePart` は **既存のキー** に対する置換のみ。Association に **新しいキー** を追加するときは `Append[assoc, <|"new" -> val|>]` を使う。`ReplacePart[assoc, "new" -> val]` は silently に無視される。

### その他: StringExpression
- 文字列パターンの `_` は **Pattern Blank** (任意の文字列)。「任意の 1 文字」のつもりで使うとマッチが広すぎる。「任意の 1 文字」は `_String /; StringLength[#] == 1` か、`LetterCharacter`/`DigitCharacter` 等の文字クラスを使う。
