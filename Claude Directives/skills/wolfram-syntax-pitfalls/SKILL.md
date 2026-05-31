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

## G. コメント / 構文の罠

### 罠 #17: コメント `(* ... *)` 内に裸の `*)` が出現すると早期終了する

Mathematica のコメント `(* ... *)` はネスト可能だが、`*)` は **どの位置に現れても最も内側の終端として作用**する。コメント本文中に文字列リテラルではなく裸の `*)` を含むと、その時点でコメントが終了し、後続の `*)` が構文エラーになる。

```mathematica
(* phase 1 cleanup (scan-start / early-result-*) ... *)
                                              ^^
                                  ここでコメント終了
(* この行以降がコード扱いされて Syntax::sntx *)
```

具体的な失敗パターン:
- `(* ... (a / b-*) ... *)` で `early-result-*)` のように丸括弧と `*)` が隣接
- `[X-*]` ではない `(X-*)` を書くと中の `*)` で早期終了

回避策:

```mathematica
(* OK: 角括弧で () を回避 *)
(* phase 1 cleanup [scan-start / early-result-*] ... *)

(* OK: スペースで * と ) を分離 *)
(* phase 1 cleanup (scan-start / early-result-* ) ... *)
```

ClaudeOrchestrator Step 5 (file_contents handler) のフェーズ名 `early-result-*` を含むコメントで実際に踏んだ。コード生成時は **コメント内の `*)` の出現に注意**し、特に正規表現的な `*` を含むラベルを括弧でくくる場合は要警戒。

## H. スコープ / 評価モデルの罠

### 罠 #18: `Block[{X}, ...]` は X の **`Options` も含む全種類の値を退避** する

`Block[{X}, ...]` は X の `OwnValues` を一時的にクリアするが、それだけでなく:

- `DownValues[X]`
- `UpValues[X]`
- `SubValues[X]`
- **`Options[X]`** ← これがハマりやすい
- `Attributes[X]`
- `Messages[X]`

これらすべてを退避し、Block 内では X の値が「空」になる。X 内の **`OptionValue[opt]` が空 `Options` を参照** して `OptionValue::optnf` を出す。

```mathematica
(* X が Options を持つ公開関数 *)
Options[ClaudeAttach] = {"Mode" -> "Default"};
ClaudeAttach[path_, OptionsPattern[]] := 
  Module[{m = OptionValue["Mode"]}, ...];

(* ❌ Block で hook 装着 *)
Block[{ClaudeAttach},
  ClaudeAttach[path_, opts___] := iMyHook[path, opts];
  ClaudeAttach["foo.txt", "Mode" -> "X"]
  (* ↑ iMyHook が内部で original を呼んだ瞬間 OptionValue::optnf *)
]
```

回避策: **`Block` を使わず、`DownValues` を手動で swap + `CheckAbort` で安全復元**:

```mathematica
(* original を一時退避するヘルパ関数 *)
iClaudeAttachOriginalCall[args___] :=
  Module[{savedDV = DownValues[ClaudeAttach], result},
    DownValues[ClaudeAttach] = $IntegrationClaudeAttachOriginalDV;
    result = CheckAbort[
      ClaudeAttach[args],
      (DownValues[ClaudeAttach] = savedDV; Abort[])];
    DownValues[ClaudeAttach] = savedDV;
    result
  ];
```

ポイント:
1. `Block` を使わない (Options は退避されない)
2. `Options[X]` / `Attributes[X]` などは元のまま生きているので、original 実装内の `OptionValue` が機能する
3. `CheckAbort` で Abort 時にも DownValues を復元 (interactive Abort で hook 状態が壊れない)
4. `OptionsPattern[X]` ではなく `opts___` で受ける (hook 側で X の Options を継承する必要がない)

SourceVault.wl の P1/P2 hook で実際に踏んだ罠。skill `package-hook-installation-patterns` に完全テンプレ。

### 罠 #20: `ReadList[path, "String", CharacterEncoding -> "UTF-8"]` は Windows で空配列を返すことがある

Windows で **Mathematica が `BinaryWrite` で書き込んだ JSONL ファイル** を直後に `ReadList` で読み込むと、ファイルは確実に存在し中身もあるのに `{}` が返ることがある。原因は **`ReadList` の改行検出 + UTF-8 マルチバイト + Windows CRLF の組合せで内部状態が壊れる** (未文書化、Wolfram 14.x で確認)。

```mathematica
(* ❌ Windows で空配列を返すことがある *)
lines = ReadList[path, "String", CharacterEncoding -> "UTF-8"];
(* Length[lines] = 0 だが、ファイルには 38 行ある *)
```

回避策: **`ReadByteArray` でバイナリ読込 → `ByteArrayToString` で明示 UTF-8 デコード → `StringSplit` で CRLF/LF 両対応の行分割**:

```mathematica
(* ✓ 確実に動く *)
rawBytes = Quiet[ReadByteArray[path]];
If[!ByteArrayQ[rawBytes], Return[{}]];
content = Quiet[ByteArrayToString[rawBytes, "UTF-8"]];
If[!StringQ[content], Return[{}]];
lines = StringSplit[content, RegularExpression["\\r?\\n"]];
lines = Select[lines, StringTrim[#] =!= "" &];
```

これは claudecode.wl の `iParseAnthropicBgResponse` で使われている Windows 対策と同じパターン。HTTP レスポンスバイナリを文字列化する経路でも `ByteArrayToString` 経由が確実。

SourceVault.wl Stage 5 (result31 → result32) で実際に踏んだ罠。書込みは正常 (`claims.jsonl` 55,632 bytes, 38 行) なのに `SourceVaultClaimsForTopic` が `{}` を返した。`ReadByteArray` パターンに変えると `MasterClaims: 38` で正しく読み込み成功。

**症状**:

- `FileExistsQ[path]` は True
- ファイルサイズ > 0 byte (確実にデータあり)
- `ReadList` の戻り値は `{}` (空) または途中で切れる
- 別 process (Python, jq 等) で読むと正しく N 行

**判別**:

```mathematica
(* ReadByteArray で正しく読めるかチェック *)
bytes = ReadByteArray[path];
str = ByteArrayToString[bytes, "UTF-8"];
StringLength[str]   (* > 0 ならファイルは生きている *)
Length[StringSplit[str, RegularExpression["\\r?\\n"]]]   (* 正しい行数 *)
```

これと `Length[ReadList[path, "String", CharacterEncoding -> "UTF-8"]]` が乖離するなら罠 #20。

### 罠 #21: `.nb` ファイルを `Get[path]` や `Import[path, "Text"]` でパースしない

**現象**:
- `Get[path.nb]` で `Notebook[...]` 式が返るはずだが、FE 経由で `NotebookObject` 化される / 特殊評価が走る等で期待と違う形になることがある
- `Import[path, "Text"]` + `ToExpression[content, InputForm, HoldComplete]` でファイル全体をパースしようとすると、コメント注釈 (`(* CreatedBy=... *)`, `(*CacheID: ...*)` 等) と `Notebook[...]` 式の混在で `ToExpression` の挙動が不安定

**正解**:

| 用途 | 推奨関数 |
|---|---|
| Notebook 全体を式として読む | `Import[path, "Notebook"]` (documented に `Notebook[{Cell[...], ...}, opts]` 式を返す) |
| InitializationCell の中身を取得 | `Import[path, "Initialization"]` (List of evaluated expressions) |
| 特定 cell style を式付きで取得 | `NotebookImport[path, style -> "Cell"]` |
| 特定 cell style のテキストだけ取得 | `NotebookImport[path, style]` |
| Plain text 化 | `Import[path, "PlainText"]` |
| Markdown 化 | `Import[path, "Markdown"]` |

```mathematica
(* OK *)
nb = Import[path, "Notebook"]      (* Notebook[...] 式 *)
inits = Import[path, "Initialization"]   (* {<|...|>} *)
todoCells = NotebookImport[path, "TodoItem_1" -> "Cell"]   (* {Cell[...], ...} *)

(* NG *)
nb = Get[path]                      (* 特殊挙動可能性 *)
expr = ToExpression[Import[path, "Text"], InputForm, HoldComplete]   (* 不安定 *)
```

**根本原則**: ノートブックや Wolfram 式の構造にアクセスする時は、必ず先に Wolfram 標準関数を探す。パターンマッチや手書きパースは最終手段。詳細は `rules/102-wolfram-stdlib-first.md`。

### 罠 #22: `ToString[box, StandardForm]` + `ToExpression[str, StandardForm, HoldComplete]` のラウンドトリップは box 用途で破綻する

**現象**: `BoxData[RowBox[{...}]]` を式に変換しようとして、`ToString[boxData, StandardForm]` で文字列化 → `ToExpression[str, StandardForm, HoldComplete]` でパース、というラウンドトリップを書きたくなる。しかし `ToString[BoxForm, StandardForm]` の出力は box の表示形式の文字列であり、source code 形式ではないため、`ToExpression` で読み戻せない場合がある。結果として `HoldComplete[...]` の中身が期待と違うか、`$Failed` になる。

**正解**: `MakeExpression[boxData, StandardForm]` を使う。これは box → expr の正規変換関数で、`HoldComplete[expr]` を直接返す (評価しない)。

```mathematica
(* OK: MakeExpression で box → 評価しない式 *)
held = MakeExpression[BoxData[RowBox[{"<|", ..., "|>"}]], StandardForm]
(* → HoldComplete[<|...|>] *)

(* NG: ラウンドトリップは壊れる *)
held = ToExpression[
  ToString[BoxData[...], StandardForm],
  StandardForm, HoldComplete]
(* → 期待と違う形になることがある *)
```

### 罠 #23: パッケージ private context 内で `Cell` / `Notebook` 等の System シンボルを生のパターンマッチに使うと別シンボル化される

**現象**: `SourceVault.wl` のような package で `Begin["`Private`"]` 内に `Cell[_, _String, ___]` のようなパターンを書くと、`Cell` が `SourceVault`Private`Cell` という **新しいシンボル** として作られることがある。一方 `Import[path, "Notebook"]` の出力は `System`Cell[...]` を含むので、両者のコンテキストが違ってパターンマッチが効かない (結果として `Cases[...]` / `SelectFirst[...]` で何も見つからない)。

**症状の典型例** (SourceVault Stage 9 P0 実装で発生):
- `iExtractTodoCells` が常に `{}` を返す
- `MatchQ[c, Cell[_, _String, ___]]` が False になる
- Header 取得 (`Import[path, "Initialization"]` 経由) は成功するのに Todo 抽出だけ失敗する

**正解** — context 非依存の書き方:

```mathematica
(* OK: SymbolName で文字列名比較 (context に依存しない) *)
If[SymbolName[Head[c]] === "Cell" && Length[c] >= 2 && StringQ[c[[2]]],
  ...]

(* OK: Keys を SymbolName で検索 *)
fvKey = SelectFirst[Keys[opts],
  SymbolName[#] === "FontVariations" &, Null];

(* NG: 生のパターン (context 依存) *)
MatchQ[c, Cell[_, _String, ___]]       (* private context で hit しないリスク *)
Lookup[opts, FontVariations, {}]       (* private context で別シンボル *)
```

**より根本的な対策**: そもそも `Import[path, "Notebook"]` でファイル全体を読んでパターンマッチするより、`NotebookImport[path, style -> "Cell"]` のような **目的特化型関数** を使う方が安全 (罠 #21 と関連)。

### 罠 #26: `Import["Notebook"]` の戻り値は CellGroupData でネスト

```mathematica
nbExpr = Import[path, "Notebook"]
(* → Notebook[{Cell[CellGroupData[{Cell["Title", "Title"], 
                                   Cell[CellGroupData[{Cell["Sec", "Section"],
                                                       Cell["Item", "Item"]}]]}, 
                                  Open]]}, ...] *)
```

トップレベルの `cells = nbExpr[[1]]` だけ見ても、Title/Section/Item の Cell には到達できない (cells[[1]] は `Cell[CellGroupData[...]]` であって `Cell["Title", "Title"]` ではない)。

**症状**:
- `Length[cells]` が異常に小さい (1 や 2 のみ)
- パターンマッチで `Cases[cells, _Cell]` が **トップレベルの 1-2 個しかヒットしない**
- `CellCount` が 0 または notebook 全体のセル数と一致しない (Stage 9 P0 で実際踏んだ)

**対策**: `Cell[CellGroupData[{...}, Open|Closed|...]]` を **再帰展開** して leaf Cell のみを取り出す:

```mathematica
iFlattenCells[nbExpr_HoldComplete] :=
  Module[{nbAtom, cells},
    nbAtom = Replace[nbExpr, HoldComplete[x_] :> x, {0}];
    If[SymbolName[Head[nbAtom]] =!= "Notebook", Return[{}]];
    If[Length[nbAtom] < 1, Return[{}]];
    cells = First[nbAtom];
    If[!ListQ[cells], Return[{}]];
    Flatten[Map[iFlattenCellRec, cells]]
  ];

iFlattenCellRec[c_] :=
  Module[{args, firstArg, innerCells},
    If[SymbolName[Head[c]] =!= "Cell", Return[{}]];
    args = List @@ c;
    If[Length[args] === 0, Return[{}]];
    firstArg = First[args];
    If[SymbolName[Head[firstArg]] === "CellGroupData" && Length[firstArg] >= 1,
      innerCells = First[firstArg];
      If[ListQ[innerCells],
        Return[Flatten[Map[iFlattenCellRec, innerCells]]]];
      Return[{}]];
    {c}
  ];
```

**path 記録版** (書き戻し用): NBAccess の `iNBFlattenCells[cells, basePath]` のように `{{cell, path}, ...}` のペアを返すと、`cells[[2, 1, 1, 3]]` のような nested index で正確に編集 cell にアクセスできる (罠 #23 準拠で `SymbolName[Head[]]` 比較を使う):

```mathematica
iNBFlattenCells[cells_List, basePath_List] :=
  Module[{result = {}, cell, hName, innerCells, sub},
    Do[
      cell = cells[[i]];
      hName = SymbolName[Head[cell]];
      Which[
        hName === "Cell" && Length[cell] >= 1 &&
          SymbolName[Head[cell[[1]]]] === "CellGroupData" &&
          Length[cell[[1]]] >= 1 && ListQ[cell[[1, 1]]],
          innerCells = cell[[1, 1]];
          sub = iNBFlattenCells[innerCells, Append[basePath, i]];
          result = Join[result, sub],
        hName === "Cell",
          AppendTo[result, {cell, Append[basePath, i]}],
        True, Null],
      {i, Length[cells]}];
    result
  ];
```

**発見経緯**: Stage 9 P1 (2026-05-20) で `NBReadTodos` を実装した際、`Count: 0` が返ってきて発覚。Out[10] の `Part::partw` メッセージで Cell が CellGroupData でネストされているのが見えた。`SourceVault` の `iFlattenCells` 既存実装は対応していたが、私が NBAccess に新規実装するときに見落とした。

### 罠 #27: `Module` 内ローカル変数を `HoldComplete[var]` でラップすると、Module を抜けた後にローカル変数名が残る

```mathematica
Module[{cell = Cell["foo", "Input", ExpressionUUID -> "abc"]},
  result = HoldComplete[cell];
  (* result === HoldComplete[NBAccess`Private`cell$14228] *)
  (* ローカル変数のシンボル名 cell$NNNN がそのまま埋め込まれている! *)
]
```

**症状**: `DryRun` で `Before` / `After` フィールドに Cell expression を入れたつもりが、`HoldComplete[pkg\`Private\`var$NNNN]` というローカル変数のシンボル参照だけが残り、Module を抜けた後はそのシンボルが値を失う。ユーザーには意味のないシンボル名しか見えない。

**原因**: `HoldComplete` は Hold 系の一種で、引数の評価を抑制する。`Module` の変数置換 (`var$NNNN` 化) は引数式の **表面的なシンボル置換** で起こり、`HoldComplete` の中に **置換後のローカル変数名** が埋め込まれる。Module 終了後にそのローカル変数は破棄されるので、HoldComplete の中身は **存在しないシンボルへの参照** となる。

**対策**: `With[{c = var}, HoldComplete[c]]` の **Block-substitution** を使う。`With` は `HoldComplete` を **貫通** して `c` の値 (= `var` の現在値) を文字通り埋め込む:

```mathematica
Module[{cell = Cell["foo", "Input", ExpressionUUID -> "abc"]},
  result = With[{c = cell}, HoldComplete[c]];
  (* result === HoldComplete[Cell["foo", "Input", ExpressionUUID -> "abc"]] *)
  (* Cell expression の値そのものが Hold の中に入っている! *)
]
```

**理屈**: `With[{x = v}, expr]` は `expr` を「`x` を `v` で置換した式」として返す。この置換は **構文的に行われる** (lexical substitution) ので、`HoldComplete` のような Hold 系内部にも作用する。`Module` の置換とは違い、`With` は変数名を一切残さず **値そのもの** を埋め込む。

**発見経緯**: Stage 9 P1 Step 6 (2026-05-20) で `SourceVaultMarkTodo` の DryRun 戻り値が `HoldComplete[NBAccess\`Private\`cell$14228]` になり、Before/After の Cell expr が見えない問題で発覚。3 箇所 (NBSetCellOptionsByPredicate / NBSetCellTaggingRuleByPredicate / NBWriteTodoStatus) を `With[{c = cell, nc = newCell}, ...]` で修正して解決 (result26.nb で確認)。

## I. JSON 永続化の罠

### 罠 #28: `ImportString[str, "RawJSON"]` は Windows path のバックスラッシュを含む JSON で `$Failed` を返す

```mathematica
json = "{\"OriginalPath\":\"C:\\\\Users\\\\imai_\\\\Dropbox\\\\foo.nb\"}";
StringLength[json]   (* 正常な JSON 文字列 *)
ImportString[json, "RawJSON"]
(* → $Failed *)
```

正常な JSON 仕様では `"C:\\Users\\foo"` は **`C:\Users\foo`** という文字列値を表すはずで、`"RawJSON"` parser は parse できるべきだが、**Wolfram の RawJSON 実装で Windows path の `\\` をうまく処理できない** バグがある (2026-05 現在、Mathematica 14.x で確認)。

**症状**:
- Source record / snapshot record など Windows 環境下で `OriginalPath` フィールドを含む JSON を保存して読み戻すと `Null` が返る
- `iLoadJSONFromFile` の戻り値が `Null` (内部の `ImportString` が `$Failed`)
- 結果として cache miss、Index 重複実行、等の二次的問題

**対策**: 3 段階 fallback パターン。`Developer\`ReadRawJSONString` または `ImportString[..., "JSON"]` (旧 parser) を fallback として用意:

```mathematica
iLoadJSONFromFile[path_String] :=
  Module[{rawBytes, str, data, dataJSON},
    If[!FileExistsQ[path], Return[Null]];
    rawBytes = Quiet @ ReadByteArray[path];
    If[!ByteArrayQ[rawBytes], Return[Null]];
    str = Quiet @ ByteArrayToString[rawBytes, "UTF-8"];
    If[!StringQ[str], Return[Null]];
    (* 第一選択: ImportString RawJSON *)
    data = Quiet @ ImportString[str, "RawJSON"];
    If[AssociationQ[data] || ListQ[data], Return[data]];
    (* fallback 1: Developer`ReadRawJSONString (簡潔なパーサー) *)
    data = Quiet @ Developer`ReadRawJSONString[str];
    If[AssociationQ[data] || ListQ[data], Return[data]];
    (* fallback 2: ImportString JSON (旧パーサー、List of Rule の可能性) *)
    dataJSON = Quiet @ ImportString[str, "JSON"];
    Which[
      AssociationQ[dataJSON] || ListQ[dataJSON], dataJSON,
      MatchQ[dataJSON, {(_Rule | _RuleDelayed) ..}], Association @@ dataJSON,
      True, Null]
  ];
```

**発見経緯**: Stage 9 P1 Step 7 (2026-05-20) で mtime ベース cache が cache hit せず、4 ラウンドの診断 (result27-30) で `iLoadJSONFromFile` の `ImportString[str, "RawJSON"]` が `$Failed` を返していることを特定。Source record JSON 内の `"OriginalPath":"C:\\\\Users\\\\..."` がトリガーだった。result31 で 3 段階 fallback により完全動作確認。

**回避策 (書き込み側)**: 書き込み時に Windows path を **forward slash に正規化** (`StringReplace[path, "\\" -> "/"]`) すれば parse 問題を完全に回避できる。ただし path が「機械可読」用途であり、ユーザー表示用ではない場合に限る。

## まとめ: 「使わない方が安全」リスト

経験的に以下は **production code で避けた方が安全**:

| 機能 | 理由 | 代替 |
|---|---|---|
| `Return[expr]` (form なし) | 罠 #12, #15 | フラグ変数 + If gate |
| `Catch/Throw` | 罠 #15 (Check と相性悪) | フラグ変数 + If gate |
| `Quiet @ Check[..., $Failed]` | 罠 #16 (未文書化) | direct call + 戻り値判定 |
| ネスト `Module[...]` | 罠 #12 | 外側 Module 直下に展開 |
| Module 内 関数定義 (DownValues) | 衝突可能性 | 関数定義はトップレベル / stack-based ループ |
| `Block[{X}, ...]` で X の DownValues 差し替え | 罠 #18 (Options 退避) | DownValues swap helper + CheckAbort |
| コメント内の裸の `*)` (e.g. `(...X-*)`) | 罠 #17 (早期終了) | 角括弧 `[X-*]` または `* )` でスペース挿入 |
| `ReadList[path, "String", CharacterEncoding -> "UTF-8"]` (Windows) | 罠 #20 (空配列返却) | `ReadByteArray` + `ByteArrayToString` + `StringSplit` |
| `Get[path.nb]` / `Import[path, "Text"]` + `ToExpression` で notebook 解析 | 罠 #21 (FE 連携 / コメント問題) | `Import[path, "Notebook"]` / `NotebookImport` |
| `ToString[box, StandardForm]` + `ToExpression[..., StandardForm, HoldComplete]` ラウンドトリップ | 罠 #22 (box 意味喪失) | `MakeExpression[box, StandardForm]` |
| Package Private context 内で `Cell[...]` / `Notebook[...]` 生パターン | 罠 #23 (context 別シンボル化) | `SymbolName[Head[c]] === "Cell"` で文字列比較 |
| `Import["Notebook"]` の戻り値で `cells[[i]]` 直接アクセス | 罠 #26 (CellGroupData ネスト) | `iFlattenCells` / `iNBFlattenCells` で再帰展開 |
| `Module[{c = ...}, HoldComplete[c]]` のような Module ローカル変数 + Hold 系 | 罠 #27 (ローカル変数名残存) | `With[{c = var}, HoldComplete[c]]` で Block-substitution |
| `ImportString[str, "RawJSON"]` 単独で Windows path 含む JSON 読み込み | 罠 #28 (`$Failed`) | 3 段階 fallback (`RawJSON` → `Developer\`ReadRawJSONString` → `JSON`) |
| code 文字列リテラル内の `\uXXXX` | 罠 #35 (Wolfram は `\:XXXX`) | 文字列リテラル内も `\:XXXX` を使う (コメントと同じ) |
| `StringMatchQ[s, pat]` で部分一致を期待 | 罠 #37 (`StringMatchQ` は完全一致、`*`/`?` をワイルドカードと解釈) | 部分一致は `StringContainsQ` |
| `StringMatchQ[s, ___ ~~ pat ~~ ___]` で `pat` が `RegularExpression` | 罠 #43 (バックトラッキング爆発でハング) | `StringContainsQ` を使う |
| `RegularExpression` 内の `\x{XXXX}` Unicode 範囲 | 罠 #44 (不安定) | StringExpression の `Alternatives` / `DigitCharacter` で組む |
| `Quiet` 内の構文エラー式 | 罠 #38 (静かに `$Failed` 返却、`Select` の述語を壊す) | `Quiet` で包む式の構文を事前検証、述語の戻り値型を確認 |
| 日付フィールドを `DateObject` 固定で扱う | 罠 #36 (`Quantity` 相対値が来うる) | `Head` で分岐、`Quantity` は `DatePlus[mtime, qty]` |
| `DateObject`/`Quantity`/`Missing` を素の JSON へ | 罠 #48 (型が壊れる) | `Compress[expr]` で ASCII 文字列化して保存、`Uncompress` で復元 |
| 多重定義関数に後からオプション追加 | 罠 #47 (引数違いの定義間で不整合) | 全アリティに `opts:OptionsPattern[]`、短い版は長い版へ委譲、`Options[f]` は 1 回 |
| `ClearAll[...]` リストに載せた関数の定義をリストより前に書く | 罠 #56 (定義が即クリアされ未定義化) | 定義は `ClearAll` ブロックの後ろに置く |
| `Button`/`Tooltip`/`Grid` のラベルに関数呼び出しを直接書く | 罠 #57 (未評価のまま StyleBox に焼き込まれフォント等が効かない) | `With[{v = f[]}, ...]` で事前評価 + 最上位で `/. HoldPattern[f[]] -> 値` 保険 |
| `"Hyperlink"` を `BaseStyle` に入れてテキストのフォントを変えようとする | 罠 #58 (Hyperlink スタイルのフォントが勝つ) | `Style[text, "Hyperlink", FontFamily -> ff]` と同階層に並べる |

## 適用タイミング

- 新規 Wolfram code を書くとき: 「使わない方が安全」リストを最初から守る
- 既存 code をデバッグするとき: $Failed が説明できないなら罠 #16 を疑う
- `Return` で抜けないなら罠 #12 / #15 を疑う
- `\u` エスケープでエラーが出たら罠 #11 を疑う
- `Needs` が見つからないと言ってきたら罠 #13 を疑う
- `OptionValue::optnf` がパッケージ関数内で出たら罠 #18 を疑う (Block の中ではないか)
- 構文エラーが出たコメント直後の行を見たら罠 #17 を疑う
- ファイルが存在するのに `ReadList` が空配列を返したら罠 #20 を疑う (Windows JSONL/UTF-8 ファイル)
- **Notebook 関連 API が空 / Missing を返したら罠 #21/#23 を疑う** (Import/NotebookImport を使っているか、context 非依存になっているか)
- **Box → expr 変換が壊れたら罠 #22 を疑う** (`MakeExpression` 使っているか)
- **`Length[cells]` が異常に小さい / CellCount = 0 になったら罠 #26 を疑う** (`Cell[CellGroupData[{...}]]` 構造で再帰展開していないか)
- **`HoldComplete[...]` の中身が `pkg\`Private\`var$NNNN` のようなローカル変数名になっていたら罠 #27 を疑う** (`With` を使っているか)
- **JSON ファイル読み込みで `iLoadJSONFromFile` が Null を返したら罠 #28 を疑う** (Windows path のバックスラッシュ、`Developer\`ReadRawJSONString` fallback を入れているか)
- **`StringMatchQ` が想定外の結果になったら罠 #37 を疑う** (完全一致を要求し `*`/`?` をワイルドカード解釈する。部分一致は `StringContainsQ`)
- **`StringMatchQ`/`StringContainsQ` が固まったら罠 #43 を疑う** (`___ ~~ RegularExpression[...] ~~ ___` でバックトラッキング爆発)
- **`RegularExpression` が不安定なら罠 #44 を疑う** (`\x{XXXX}` Unicode 範囲。StringExpression で組み直す)
- **`Select`/`Cases` の述語が想定外に振る舞ったら罠 #38 を疑う** (`Quiet` 内の構文エラーが静かに `$Failed` を返している)
- **日付計算が `Quantity` で崩れたら罠 #36 を疑う** (Header の日付フィールドは `DateObject`/`Quantity`/`String` 混在。`Head` で分岐)
- **JSON 往復で `DateObject` が文字列化したら罠 #48 を疑う** (`Compress`/`Uncompress` で型保持)
- **多重定義関数のオプションが効かないなら罠 #47 を疑う** (全アリティに `opts:OptionsPattern[]` があるか)

## 設計レベルの罠 (Wolfram 構文ではなく、システム設計の落とし穴)

以下は構文ではなく **設計判断の罠**。Stage 9 P1 Steps 1-8 (2026-05-21) で確立。

### キャッシュ・パフォーマンス

- **罠 #41**: キャッシュを足す前に、ボトルネックが本当にそこにあるか計測で確認する。判定ロジック (cache hit するか) と、cache hit 時に返すデータの構築は別物。判定が「不要」でも、データ構築側が重い処理 (ファイル Import 等) をしていれば高速化にならない。**cache hit 時に返すデータも含めて永続化する。**
- **罠 #49**: 多数ファイルをループ処理して結果を Association/List に蓄積する設計は、1 件あたりの結果が大きいとメモリ枯渇 (最悪 OS ごとフリーズ)。(1) 後段で実際に使うフィールドだけの軽量レコードを保持、(2) 大きな中間結果は `expr =.` で即解放、(3) `NotebookImport` 等のキャッシュは `ClearSystemCache` で定期解放。「全件をメモリに集めてから処理」ではなく「1 件処理して軽量化して捨てる」。
- **罠 #50**: 進捗を in-memory にしか持たない長時間処理は、途中クラッシュで進捗が全消失し「最初からやり直し」になる。進捗はディスクに 1 ステップずつ永続化し、再開時はディスクを見て未処理分だけ処理する。
- **罠 #51**: ユーザーのファイル群には想定外に巨大なもの (シミュレーション結果埋め込みの `.nb` で数百 MB〜GB 等) が混じり得る。無条件に `Import` するとメモリ枯渇・ハング。ファイル走査処理には必ずサイズ閾値を設け、超過ファイルは中身を読まずメタ情報だけ記録する。閾値はオプション + グローバル変数で調整可能に。

### パス・環境

- **罠 #45**: クラウド同期フォルダ (Dropbox 等) は PC ごとにマウントされる絶対パスが異なる。ファイルの ID やキャッシュキーを絶対パスから作ると PC をまたいで一致しない。ルート相対のシンボリックパス (`{"$onWork", "folder", "file.nb"}` 等) から ID を導出する。

### LLM・プライバシー

- **罠 #46**: LLM 出力を「クラウド投入可能か判定する」代わりに「クラウド投入可能な形で出力させる」生成制約に変換すると、判定の不確実性が消える。プロンプトで個人情報排除を指示 (一次防御) + 生成後に正規表現で検証して違反時破棄 (二次防御)。判定問題を生成制約問題に変換する設計パターン。

### Notebook ファイル操作

- **罠 #29**: `\[CloudSymbol]` のような実在しない named character を使わない。クラウドの雲記号は `\:2601`。
- **罠 #30**: `NotebookSave` とファイル直接編集 (`Export[..., "NB"]`) は競合しうる。フロントエンドで開いているノートはどちらか一方の経路に統一する。
- **罠 #31**: Windows では `RenameFile` がフロントエンドで開いているファイルに対し静かに失敗する。`Export[..., "NB"]` を使う。
- **罠 #32**: フロントエンドで開いているノートの編集は `SetOptions[nb, ...]` + `NotebookSave[nb]` 経路で行う。
- **罠 #33**: `Export[..., "NB"]` はヘッダのバイト位置キャッシュを更新しない。
- **罠 #34**: `NotebookSave` はフロントエンドが dirty でなければ no-op になる。
- **罠 #39**: `Dataset` のセルは `Button[label, action]` をサポートする (リンクや操作ボタンを埋め込める)。
- **罠 #40**: `Dataset` の `Button` に文字列ラベルを渡すと引用符が表示される。`Style[s, ShowStringCharacters -> False]` で抑制。

### 次フェーズ (SourceVault Sync / Relink / モデルレジストリ, 2026-05-22) の罠

- **罠 #52 (重大、データ破壊源)**: `Return[expr, Module]` は **最も内側の同名 `Module`** から抜ける。ある条件で関数全体を抜けたい早期 return (`If[cond, ...; Return[Null, Module]]`) を、たまたま内側の `Module[{tmp}, ...]` の中に書くと、関数本体でなく**内側 `Module` だけを抜けて**処理が後続に流れる。SourceVault Relink で「移動していないファイル」の早期 return を内側 Module に閉じ込めた結果、全件が照合ループに流れて `Relinked` が 360 件に膨張した。早期 return を含む `If` は、その `If` がどの `Module` 直下にあるかを必ず確認する。内側 Module が必要なら判定結果だけを値で返し、早期 return は外側で行う。
- **罠 #53**: `URLRead[req, fmt, TimeConstraint -> n]` の `TimeConstraint` は `URLRead` のオプションではない。`URLRead::optx` メッセージとともに静かに `$Failed` を返す。`Quiet@Check` で囲んでいると気づけない。タイムアウトは `TimeConstrained[URLRead[req], 秒, $Failed]` で外側から囲む。
- **罠 #54**: `name::usage = "..."` の usage 文字列リテラル内に出てくる `"..."` (例の中のオプション名やデフォルト値) は必ず `\"...\"` にエスケープする。生の `"` を書くと usage 文字列がそこで終了し、続く文字列が裸のシンボル列として解釈され、`MessageName::messg` ("MessageName の右辺は文字列でなければならない" 系) でロード失敗する。パッケージ配布前に全 `::usage` の引用符バランスを機械検査するとよい (`::usage =` 以降で `\"` を除いた `"` の数が偶数か)。罠 #11 と並ぶ、Windows 非依存の継続的エラー源。
- **罠 #55** (最重要・JSON 書き込みの文字化け): JSON 文字列化の 2 API は戻り値のエンコードが異なり、ファイル書き込みのバイト化方法を取り違えると**二重エンコードで日本語が `ã` だらけに化ける**。`ToCharacterCode` で実証済み (result7.nb)。`ExportString[expr, "RawJSON"]` の戻りは**各 codepoint が UTF-8 byte の Latin-1 表現** (`"今"` → `228,187,138`) なので、書き込みは `StringToByteArray[json, "ISO8859-1"]` (1 codepoint = 1 byte) が正しい。`"UTF-8"` で書くと既に UTF-8 の byte を再度 UTF-8 encode して二重化する。一方 `Developer`WriteRawJSONString[expr]` の戻りは**通常の Unicode 文字列** (`"今"` → `20170`) なので、書き込みは逆に `"UTF-8"` が正しい。読み取りは両方とも `ReadByteArray` → `ByteArrayToString[..., "UTF-8"]`。ASCII のみのデータでは二重 encode でも値が変わらず**顕在化しない**ため、ASCII テストだけ通すと見逃す (日本語のパス・Memo・プロンプトが入って初めて化ける)。さらに**二次被害**として、化けたファイルを読み込むと JSON パースの Association 化が崩れ、後段で `Lookup::invrl` 等の別エラーを誘発する (SaveLastPrompt で発生)。文字化けを直すと連鎖エラーも消える。検出: `grep -n 'StringToByteArray\[[^,]*, *"UTF-8"\]' *.wl` でヒットしたら、書く文字列が `ExportString["RawJSON"]` 由来か (→ ISO8859-1 に直す) `WriteRawJSONString`/通常文字列か (→ UTF-8 のまま) を確認する。発見経緯: Stage 9 P1.5 で `prompt-route-registry.json` の日本語が化け、横断調査で promptrouter 2 箇所・DirRepo・cloud-send ログ・workflow メタの計 5 箇所が `UTF-8` のまま取り残されていた (model-registry 系は既に ISO8859-1 だった)。

## クイック診断 (次フェーズの罠)

- **`Return[Null, Module]` を書いたのに処理がスキップされず後続に流れたら罠 #52 を疑う** (その `If` の直上の `Module` は関数本体か、内側ブロックか)
- **`URLRead` が常に `$Failed` を返す / 到達可能なはずのサーバーが Offline になったら罠 #53 を疑う** (`TimeConstraint` オプションを渡していないか)
- **パッケージロードで `MessageName::messg` が出たら罠 #54 を疑う** (`::usage` 本文内の生ダブルクォート)
- **JSON ファイルの日本語が `ã` だらけに化けたら罠 #55 を疑う** (`ExportString["RawJSON"]` の戻りを `StringToByteArray[..., "UTF-8"]` で書いていないか。ISO8859-1 が正しい)。`Lookup::invrl` 等が JSON 読み込み後に出るのも、化けたファイルの二次被害として罠 #55 を疑う。

## 表示フォント / Style / ClearAll の罠 (UI 出力カスタマイズ, 2026-05-31)

`$ClaudeStandardFont` 対応 (ClaudeEval/SourceVault の表出力フォントをユーザー設定に追従させる) で、フォントが反映されない症状を 8 ラウンドかけて切り分けた際に踏んだ罠。表面症状は同じ「フォントが変わらない」でも原因が 3 層に分かれており、上位の罠を潰さないと下位の罠が顕在化しない。

### 罠 #56 (最重要・原因が見えにくい): `ClearAll` リストに載せた関数の定義を `ClearAll` より**前**に書くと、定義が即座に消去される

```mathematica
Begin["`Private`"];

iSVStandardFont[] := ...   (* (A) ここで定義 *)

ClearAll[
  iSVStandardFont,         (* (B) ロード時の旧定義クリア目的だが、(A) も消す！ *)
  iOtherFunc, ...
];
(* → この後 iSVStandardFont[] は未定義。呼んでも評価されず入力がそのまま返る。 *)
```

パッケージは**再ロード時に古い DownValues が残らないよう冒頭で `ClearAll`** するのが定石だが、その `ClearAll` リストに載せた関数の定義を **`ClearAll` の前に書いてしまう**と、ロードのたびに「定義 → 即クリア」となり関数が消える。`iSVStandardFont` が常にフォールバック値を返していた (ように見えた) 真因はこれで、実際には**関数自体が未定義**だった。

**症状の決定的な見分け方**: `pkg\`Private\`f[]` を直接評価して**入力がそのまま返ってくる** (例: `SourceVault\`Private\`iSVStandardFont[]` → `SourceVault\`Private\`iSVStandardFont[]`) なら、その関数は未定義。DownValues が無い。

**対策**: `ClearAll[...]` リストに載せる関数の**定義は必ず `ClearAll` ブロックの後ろに置く**。クリア → 定義の順序にする。新規ヘルパを既存の `ClearAll` リストに追記するときは、定義位置がリストより後ろにあるか必ず確認する。

**検出**: `ClearAll[` の中に出てくるシンボル名について、その `f[...] :=` 定義行が `ClearAll[...]` の閉じ括弧より後ろにあるかを機械チェックできる。

### 罠 #57: `Button` / `Tooltip` のラベルや `Grid` のボックス化文脈に渡した式の中の**関数呼び出しは未評価のまま StyleBox に焼き込まれる**

```mathematica
Button[Style[title, FontFamily -> iSVStandardFont[]], action]
(* 出力 .nb: FontFamily->SourceVault`Private`iSVStandardFont[]  ← 未評価のまま! *)
```

`Button` はラベルを Hold する。`Style[..., FontFamily -> f[]]` の `f[]` がボックス化される時点で評価されず、`FontFamily->f[]` という**関数呼び出しがそのまま box 値**になる。フロントエンドは `FontFamily` の値に文字列 (フォント名) を期待するため、関数式は値として解釈できず**無視され**、フォントが効かない。`.nb` を覗くと `FontFamily->pkg\`Private\`helper[]` が大量に残っているのが目印。

**対策 (2 段構え)**:
1. **`With[{ff = f[]}, Button[Style[..., FontFamily -> ff], ...]]`** で字句置換。`With` は本体内の `ff` を評価済みの値 (文字列) で構文置換するため、`Button` が Hold しても既にリテラルになっている。`Module` のローカル変数は評価時束縛なので Hold 文脈では危険 (罠 #27 と同根)。
2. **生成物の最上位で `expr /. HoldPattern[f[]] -> 確定文字列` で一括置換**してから返す (保険)。左辺は `HoldPattern` で包まないとルール構築時に `f[]` が評価されて無意味なルールになる。

**検出**: 出力 `.nb` に `FontFamily->...helper[]` のような未評価の関数呼び出しが残っていないか grep する。

### 罠 #58: 組み込み `"Hyperlink"` スタイルは独自の `FontFamily` を持ち、`BaseStyle` 経由ではテキストのフォントを上書きできない

```mathematica
(* NG: BaseStyle に Hyperlink を入れると、Hyperlink スタイルのフォントがテキストに勝つ *)
Button[Style[title, FontFamily -> ff], action, BaseStyle -> {"Hyperlink", FontFamily -> ff}]

(* OK: Style の引数列で "Hyperlink" の後に FontFamily を置く (同階層・後勝ち) *)
Button[Style[title, "Hyperlink", FontFamily -> ff], action]
```

`"Hyperlink"` は色・サイズ・下線に加え `FontFamily` をスタイルシートで定義している。`Button` の `BaseStyle -> {"Hyperlink"}` 経由だと、リンクテキストにはスタイルシート由来のフォントが適用され、内側 `Style` の `FontFamily` が負ける。一方 `Style[text, "Hyperlink", FontFamily -> ff]` のように **`Style` の同階層に並べる**と後勝ちで `ff` が効く (色・サイズ・下線は `"Hyperlink"` のまま維持)。`"Hyperlink"` を外して `RGBColor` 直指定にすると、今度はスタイルが持っていたフォントサイズ等も失われて「文字が小さくなる」二次症状が出る。

**対策**: リンク見た目を保ちつつフォントだけ変えたいときは、`"Hyperlink"` を `Style` の引数に入れ、その後に `FontFamily -> ...` を置く。`BaseStyle` には入れない。`Hyperlink[Style[text, FontFamily -> ff], url]` のように `Style` を `Hyperlink` の内側に入れる形でも効く。

## クイック診断 (フォント / Style / ClearAll の罠)

- **`pkg\`Private\`f[]` を直接評価して入力がそのまま返ってきたら罠 #56 を疑う** (その関数が `ClearAll[...]` リストに載っていて、定義が `ClearAll` より前にないか)。フォント・色・ヘルパ全般の「設定が効かない」症状の最有力。
- **出力 `.nb` に `FontFamily->...helper[]` のような未評価の関数呼び出しが焼き込まれていたら罠 #57 を疑う** (`Button`/`Tooltip`/`Grid` のラベルに関数呼び出しを直接書いていないか。`With` で事前評価しているか)。
- **リンク (Hyperlink) のテキストだけフォントが変わらない / Hyperlink を外したら文字が小さくなったら罠 #58 を疑う** (`"Hyperlink"` を `BaseStyle` でなく `Style` の引数列に置いているか)。
- **フォント反映を確認するときは、まず `pkg\`Private\`フォント取得関数[]` を単体評価し、期待値の文字列が返るかを最初に確認する** (関数が正しい値を返すか → 出力 `.nb` の `FontFamily` 値が文字列になっているか、の順で切り分ける)。
