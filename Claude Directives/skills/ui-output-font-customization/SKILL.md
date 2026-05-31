---
name: ui-output-font-customization
description: Use when adding or changing display fonts in ClaudeEval / SourceVault / NBAccess UI output (Grid, Column, Style, Button, Tooltip, Hyperlink cells), or when a font / style / color setting "does not apply" to rendered notebook output. Especially relevant for $ClaudeStandardFont, iSVStandardFont, schedule/notebook list tables, and any helper that injects FontFamily into boxed output. Covers traps #56–#58.
---

# UI 出力フォントのカスタマイズ

ClaudeEval / SourceVault の表・リスト出力で使うフォントを、ユーザー設定 (`$ClaudeStandardFont`) に追従させるための実装パターンと、フォントが反映されないときの切り分け手順。詳細な罠は `skills/wolfram-syntax-pitfalls` の罠 #56–#58 を参照。

## 標準フォント定数 `$ClaudeStandardFont`

- `ClaudeCode`$ClaudeStandardFont` は claudecode.wl が公開する文字列定数。ロード時に `If[!ValueQ[$ClaudeStandardFont], $ClaudeStandardFont = "Yu Gothic UI"]` でデフォルト代入 (再ロード時にユーザー設定を上書きしない ValueQ ガード)。
- ユーザーはロード後に `$ClaudeStandardFont = "Hiragino Kaku Gothic ProN"` 等で変更できる。
- `$claudeMathPromptPrefix` にこの値を埋め込み、ClaudeEval が**生成する**コードにも `FontFamily` 指定を促す (ただし LLM 追従は確率的)。
- **SetDelayed (`:=`) なプロンプトに値を埋め込む**ことで、ユーザーが定数を変えれば次回生成から反映される。

## SourceVault 側で定数を参照するヘルパ `iSVStandardFont[]`

別パッケージ (SourceVault) から claudecode の公開定数を参照するときの安全な書き方:

```mathematica
(* 重要: この定義は ClearAll[...] ブロックの「後ろ」に置く (罠 #56) *)
iSVStandardFont[] :=
  Module[{val},
    val = Quiet[ToExpression["ClaudeCode`$ClaudeStandardFont"]];
    If[StringQ[val] && StringLength[val] > 0, val, "Yu Gothic UI"]
  ];
iSVStandardFont[___] := "Yu Gothic UI";
```

- **`ToExpression["ClaudeCode`$ClaudeStandardFont"]` を使う**。`Symbol[名前]` や `ValueQ[Symbol[名前]]` は評価タイミングが不安定で値を取り損ね、常にフォールバックする (罠の経緯)。`ToExpression` は文字列を式として評価し、定数の値を確実に取得する。
- claudecode 未ロード・未定義・非文字列なら評価結果が文字列にならないので、`StringQ` 判定で安全に既定フォントへフォールバック。
- 二番目の定義 `iSVStandardFont[___] := "Yu Gothic UI"` は引数付き誤用時の保険。

## 出力 UI へのフォント注入パターン

### 普通の Style (即時評価される) — そのまま関数呼び出しで可

```mathematica
Style[label, FontFamily -> iSVStandardFont[], color]
Grid[rows, BaseStyle -> {FontFamily -> iSVStandardFont[]}]
```

`Style`/`Grid` は即時評価されるので `iSVStandardFont[]` も評価され、フォント名 (文字列) になる。

### Button / Tooltip / Hyperlink のラベル — 必ず事前評価 (罠 #57)

`Button` 等はラベルを Hold するため、ラベル内の `iSVStandardFont[]` は未評価のまま StyleBox に焼き込まれ、フォントが効かない。`With` で字句置換する:

```mathematica
iSVTitleButton[title_, path_] :=
  With[{ff = iSVStandardFont[]},
    If[StringQ[path] && FileExistsQ[path],
      Button[Style[title, "Hyperlink", FontFamily -> ff,
          ShowStringCharacters -> False],
        SystemOpen[path],
        Appearance -> "Frameless"],
      Style[title, FontFamily -> ff, ShowStringCharacters -> False]]];
```

`Module` ローカル変数は評価時束縛なので Hold 文脈では不可。`With` の構文置換 (Block-substitution) を使う (罠 #27 と同根)。

### Hyperlink の見た目 + フォント変更 (罠 #58)

`"Hyperlink"` 組み込みスタイルは独自の `FontFamily` を持つ。`BaseStyle -> {"Hyperlink"}` 経由ではテキストのフォントを上書きできない。**`Style` の引数列に `"Hyperlink"` を入れ、その後に `FontFamily` を置く** (同階層・後勝ち):

```mathematica
(* OK *)  Style[text, "Hyperlink", FontFamily -> ff, ShowStringCharacters -> False]
(* OK *)  Hyperlink[Style[text, FontFamily -> ff], url]
(* NG *)  Button[Style[text, FontFamily -> ff], act, BaseStyle -> {"Hyperlink", FontFamily -> ff}]
```

`"Hyperlink"` を外して `RGBColor` 直指定にすると、スタイルが持っていたサイズ等も失われ「文字が小さくなる」二次症状が出るので避ける。

### 生成物の最上位での保険置換

各セル関数で取りこぼした未評価呼び出しを一掃するため、Grid 構築後に確定文字列へ一括置換してから返す:

```mathematica
iSVFormatScheduleDataset[...] :=
  Module[{..., fontName, gridExpr},
    fontName = iSVStandardFont[];
    If[!StringQ[fontName] || StringLength[fontName] == 0, fontName = "Yu Gothic UI"];
    ...
    gridExpr = Grid[...];
    gridExpr /. HoldPattern[iSVStandardFont[]] -> fontName   (* 左辺は HoldPattern 必須 *)
  ];
```

`/.` の左辺を `HoldPattern` で包まないと、ルール構築時に `iSVStandardFont[]` が評価されて無意味なルールになる。

## フォントが反映されないときの切り分け (順番に確認)

1. **ヘルパが正しい値を返すか**: `pkg`Private`iSVStandardFont[]` を単体評価する。
   - **入力がそのまま返る** (`SourceVault`Private`iSVStandardFont[]` がそのまま) → 関数が未定義。**罠 #56** (`ClearAll` の前に定義していないか)。
   - フォールバック値 (`"Yu Gothic UI"`) が返る → 定数取得ロジックの問題。`ToExpression["ClaudeCode`$ClaudeStandardFont"]` 単体も評価して比較。
   - 期待値が返る → 2 へ。
2. **出力 `.nb` の `FontFamily` 値が文字列か**: `.nb` を grep し、`FontFamily->...helper[]` のような未評価呼び出しが残っていたら **罠 #57** (`With` 事前評価 + `/. HoldPattern` 保険を入れる)。
3. **特定の列 (リンク) だけ変わらない**: **罠 #58** (`"Hyperlink"` を `Style` の引数列に置いているか、`BaseStyle` に入れていないか)。
4. **フォント名が環境に存在するか**: macOS 専用フォント (Hiragino 系) を Windows 環境で指定していないか。`Row[{Style["あ", FontFamily -> "目的のフォント"], Style["あ", FontFamily -> "Yu Gothic UI"]}]` で見た目が違えば存在、同じなら不在 (フォールバック描画)。

## 適用タイミング

- ClaudeEval / SourceVault の表・リスト出力にフォント・色・スタイルを足すとき
- ユーザーが「フォント (色・スタイル) が変わらない」と報告したとき → まず手順 1 から切り分ける
- 別パッケージから claudecode の公開定数を参照するヘルパを書くとき → `ToExpression[フルコンテキスト名文字列]` パターン + `ClearAll` 後に定義
