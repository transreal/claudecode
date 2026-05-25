---
name: nbaccess-semantic-api
description: |
  NBAccess.wl Stage 9 P1 で追加された高レベル semantic API 7 個 (読み取り 3 + 書き込み 4) の設計詳細。
  FrontEnd を起動せずに .nb ファイルを直接編集する atomic-write パイプライン、AccessLevel RBAC + DryRun 安全機構、
  CellPath (List of Integer) による CellGroupData ネスト対応の cell 位置記録、Header と Todo metadata を区別する
  iNBIsHeaderLikeAssoc フィルタ、NBReadHeader の 3 経路 fallback (Notebook TaggingRules → Cell TaggingRules → BoxData MakeExpression)、
  With[{c=v}, HoldComplete[c]] による DryRun の Before/After 値埋め込み (罠 #27 回避)、CellGroupData の再帰展開 (罠 #26 回避)、
  Public API 仕様、内部ヘルパー設計、SourceVaultMarkTodo がこれを薄くラップする経路、Stage 9 P0 の Approval Workflow 経路との
  使い分け、Stage 9 Phase 3 (P2) で予定されているバッチ Todo 操作・privacy profile route 分岐への伏線。
  result22.nb〜result34.nb で実装・動作実証完了 (2026-05-20)、handoff_2026-05-20-stage9-p1.md と対応。
---

# NBAccess Semantic API (Stage 9 P1)

`NBAccess.wl` の Stage 9 P1 で追加された **高レベル semantic API 7 個** の設計詳細。
notebook を **FrontEnd を起動せずに** 直接編集できる atomic-write パイプラインを提供する。

完成版: `2026-05-19-stage-9-p1-step8-nbreadheader-boxdata-filter` (2026-05-20、result22.nb〜result34.nb で実証)。

## 設計の核心 — 4 つの分離

### 1. ファイル直接編集経路 (FrontEnd 不要)

旧 P0 案では `NBAccess approval workflow + FrontEnd 起動` を検討したが、以下の制約があった:
- closed notebook (FrontEnd で開いていない `.nb`) を扱えない
- scheduled task / batch から呼び出せない
- approval UI の往復で遅い

Stage 9 P1 では `Import["Notebook"]` → 編集 → `Export[path, ..., "NB"]` の **ファイル直接編集**パイプラインを採用。FrontEnd は不要で、closed notebook も batch も扱える。

```
[読み取り経路]
  path → Import["Notebook"] → HoldComplete[Notebook[{...}, opts]]
       → iNBFlattenCells で leaf cells に展開
       → predicate / Header フィルタで対象 cell 特定
       → 結果 (Association、HoldComplete[Cell[...]] を含む)

[書き込み経路]
  path → Import["Notebook"] → 編集 → Export[tmp, nbExpr, "NB"]
       → DeleteFile[path] (Windows 対応) → RenameFile[tmp, path]   (atomic)
       → AutoReindex (SourceVault 連動)
```

旧 P0 の Approval Workflow 経路 (`NBOpenAuthorized` + `NBProcessFile`) は **FrontEnd ベースの interactive 編集** 用に残し、Stage 9 P1 の semantic API は **batch / scheduled task / SourceVault index 統合** 用と棲み分けている。

### 2. AccessLevel RBAC + DryRun

| アクセス区分 | 必要 AccessLevel | default DryRun |
|---|---|---|
| 読み取り系 (NBReadHeader / NBReadTodos / NBFindCellByPredicate) | >= 0.0 (default 0.5, Public) | (適用なし) |
| 書き込み系 (NBWriteHeader / NBWriteTodoStatus / NBSetCell*) | **>= 0.7 必須** (default 0.7) | **`True`** (安全側) |

書き込み系の `DryRun -> True` (default) は ファイルを変更せず、Before/After を Cell expression で返す。実行時は明示的に `"DryRun" -> False` を渡す必要がある。

```mathematica
(* デフォルトは DryRun -> True、ファイル変更なし *)
result = NBWriteTodoStatus[path, <|"Index" -> 1, "Text" -> "参加登録"|>, "Done"]
(* → <|"Status" -> "DryRunOK",
       "Before" -> HoldComplete[Cell["参加登録", "TodoItem_1", ..., 
                                      FontVariations -> {"StrikeThrough" -> False}, ...]],
       "After"  -> HoldComplete[Cell["参加登録", "TodoItem_1", ..., 
                                      FontVariations -> {"StrikeThrough" -> True}, ...]], ...|> *)

(* 実行 (atomic write 発生) *)
result = NBWriteTodoStatus[path, <|"Index" -> 1, "Text" -> "参加登録"|>, "Done",
  "DryRun" -> False]
```

`Before` / `After` フィールドの Cell expression は **罠 #27 対応** で `With[{c = cell, nc = newCell}, ...]` のように **Block-substitution** で値を埋め込んでいる。`Module[{cell = ...}, HoldComplete[cell]]` のような書き方では `HoldComplete[NBAccess\`Private\`cell$14228]` のローカル変数名残存問題が発生する。

### 3. CellPath (List of Integer)

Cell の位置を **flat な連番**ではなく `CellPath = {2, 1, 3}` のような **List of Integer** で記録する。

これは Notebook 内の `Cell[CellGroupData[{...}]]` ネスト (罠 #26) に対応するため。

```
Notebook[
  {Cell[CellGroupData[                    (* index 1 in top-level cells *)
    {Cell["Title", "Title"],              (* CellPath = {1, 1} *)
     Cell[CellGroupData[                  (* CellPath = {1, 2} の親 *)
       {Cell["Sec", "Section"],           (* CellPath = {1, 2, 1} *)
        Cell["Item", "Item"]}             (* CellPath = {1, 2, 2} *)
     ]]}, Open]]},
  ...
]
```

CellPath の利点:
- 書き戻し時に `cells[[1, 1, 2, 1]]` のように nested index で正確にアクセスできる (iNBReplaceCellInList)
- flat 連番だと CellGroupData の展開順に依存して脆い
- ユーザーが Notebook を編集して Cell を追加しても、path は構造に対する相対位置なので保たれる

### 4. Header と Todo metadata の区別

`NBReadHeader[path]` の 3 経路 fallback で、TodoItem cell の TaggingRules を **Header と誤認しない** ための仕組み。

旧 Stage 9 P1 暫定版では 2 経路目 (全 Cell の TaggingRules 走査) が Step 6 で書き込んだ TodoItem cell の `<|"SourceVault" -> <|"TodoStatus" -> "Done"|>|>` を Header と誤認し、`Source: "HeaderCell"`、`RawHeader: <|"TodoStatus" -> "Done"|>` という意味のない結果を返していた (result33-new.nb で発覚)。

**対策**: `iNBIsHeaderLikeAssoc` フィルタを導入し、Header らしいキー (`Keywords` / `Status` / `Deadline` / `NextReview` / `Owner` / `PathHint` / `Title`) のいずれかを含む Association のみ Header と認める。

```mathematica
iNBIsHeaderLikeAssoc[assoc_Association] :=
  AnyTrue[{"Keywords", "Status", "Deadline", "NextReview",
    "Owner", "PathHint", "Title"},
    KeyExistsQ[assoc, #] &] &&
  Length[assoc] > 0;
iNBIsHeaderLikeAssoc[_] := False;
```

これにより `<|"TodoStatus" -> "Done"|>` は Header らしいキーを含まないのでフィルタを通過せず、3 経路目 (BoxData → MakeExpression) に fallback して本物の Header を取得する。

## Public API 仕様

### 共通仕様

すべての API はオプション `"AccessSpec"` を受け取る:

```mathematica
"AccessSpec" -> <|
  "AccessLevel" -> _Real,                  (* 0.0〜1.0、必須 *)
  "Environment" -> _String,                (* "Notebook" / "ScheduledTask" / "REPL" 等 *)
  "AllowedSinks" -> {_String..}            (* "LocalOnly" / "Notebook" / "Network" 等 *)
|>
```

戻り値は必ず `<|"Status" -> "OK" | "Failed" | "DryRunOK", ...|>` の Association。

### 読み取り系 (3 API)

#### NBReadHeader[path, opts]

Notebook の SourceVault Header を抽出。**3 経路 fallback** で探索:

1. Notebook 全体 TaggingRules > SourceVault (Header フィルタ通過のみ)
2. 全 Cell の TaggingRules > SourceVault (Header フィルタ通過のみ)
3. Input cell の BoxData → MakeExpression で Association 化 (whitelist なし、生 Association)
4. None

```mathematica
NBReadHeader[path]
(* → <|"Status" -> "OK",
       "Keywords" -> {"みんなのケア情報学会", "オンライン語り交流会"},
       "Status" -> "Todo",
       "Deadline" -> DateObject[{2026, 5, 13}, "Day"],
       "NextReview" -> DateObject[{2026, 5, 13}, "Day"],
       "Owner" -> Missing["NotPresent"],
       "PathHint" -> Missing["NotPresent"],
       "RawHeader" -> <|...|>,
       "Source" -> "BoxData",   (* "TaggingRules" / "HeaderCell" / "BoxData" / "None" *)
       "Path" -> "...",
       "AccessSpec" -> <|...|>|> *)
```

経路 3 (BoxData) は **whitelist なし** で生 Association を返す。NBAccess は中立的なファイル I/O 層なので型検証は呼び出し側 (SourceVault の `iAllowedHeaderValueQ` 等) の責務。

#### NBReadTodos[path, opts]

全 Todo cell を列挙 (CellGroupData 再帰展開、罠 #26 対応)。

```mathematica
NBReadTodos[path]
(* → <|"Status" -> "OK",
       "Todos" -> {<|"Index" -> 1,
                     "Text" -> "参加登録",
                     "Status" -> "Open" | "Done" | "Pass",
                     "StatusSource" -> "TaggingRules" | "StyleHeuristic" | ...,
                     "CellPath" -> {2, 1},
                     "ExpressionUUID" -> "75f8...",
                     "Style" -> "TodoItem_1"|>},
       "Count" -> 1,
       "Path" -> "...",
       "AccessSpec" -> <|...|>|> *)
```

Status 判定優先順位:
1. `TaggingRules["SourceVault"]["TodoStatus"]` (Stage 9 P0 の標準形式) → `StatusSource: "TaggingRules"`
2. `FontVariations -> {"StrikeThrough" -> True}` + `FontColor` で Done/Pass 区別 → `StatusSource: "StyleHeuristic"`
3. Default `"Open"`

#### NBFindCellByPredicate[path, predicate, opts]

述語マッチの cell を列挙。

```mathematica
NBFindCellByPredicate[path,
  Function[c, MatchQ[c[[2]], "Title"]]]
(* → <|"Status" -> "OK",
       "Matches" -> {<|"CellIndex" -> 1,
                       "CellPath" -> {1, 1},
                       "Cell" -> HoldComplete[Cell["Title", "Title", ...]],
                       "Style" -> "Title",
                       "ExpressionUUID" -> "..."|>},
       "Path" -> "...", "AccessSpec" -> <|...|>|> *)
```

任意の述語関数 (Cell expression を受け取り Bool を返す) を渡せる。`MaxMatches` オプションで上限指定可能。

### 書き込み系 (4 API)

すべて AccessLevel >= 0.7 必須、default DryRun = True。

#### NBWriteHeader[path, key, value, opts]

Notebook 全体 TaggingRules > SourceVault に key を merge。既存値は保持。

```mathematica
NBWriteHeader[path, "Status", "Done"]
(* → <|"Status" -> "DryRunOK",
       "Key" -> "Status",
       "Before" -> Missing["NotPresent"],
       "After" -> "Done",
       "DryRun" -> True, ...|> *)
```

#### NBWriteTodoStatus[path, todoKey, newStatus, opts]

Todo cell の Status を変更。`todoKey = <|"Index" -> _, "Text" -> _|>` で **Index + Text 両方一致** の cell のみ編集 (安全側、誤爆防止)。

新 Status の値:
- `"Open"`: StrikeThrough → False、FontColor → Automatic、TaggingRules → "Open"
- `"Done"`: StrikeThrough → True、FontColor → `RGBColor[0., 0.5, 0.]` (緑)、TaggingRules → "Done"
- `"Pass"`: StrikeThrough → True、FontColor → `GrayLevel[0.5]`、TaggingRules → "Pass"

Cell options + TaggingRules を **同時 set** することで、Style heuristic と TaggingRules どちらから判定しても一貫した Status になる。

#### NBSetCellOptionsByPredicate[path, pred, optionRules, opts]

述語マッチ cell の options を merge。複数 cell 同時変更可能。

```mathematica
NBSetCellOptionsByPredicate[path,
  Function[c, MatchQ[c[[2]], "TodoItem_1"]],
  {FontVariations -> {"StrikeThrough" -> True}}]
```

#### NBSetCellTaggingRuleByPredicate[path, pred, taggingPath, value, opts]

述語マッチ cell の TaggingRules 内 **nested key path** に値を set。

```mathematica
NBSetCellTaggingRuleByPredicate[path,
  Function[c, MatchQ[c[[2]], "TodoItem_1"]],
  {"SourceVault", "Priority"},
  "High"]
(* → TaggingRules -> <|"SourceVault" -> <|"Priority" -> "High",
                                          (既存キー保持)|>|> に merge *)
```

## 内部ヘルパー

### CellGroupData 再帰展開: iNBFlattenCells

罠 #26 (`Import["Notebook"]` の CellGroupData ネスト) 対応。`{cell, path}` のペアを返すので書き戻しに使える。

```mathematica
iNBFlattenCells[cells_List, basePath_List] :=
  Module[{result = {}, cell, hName, innerCells, sub},
    Do[
      cell = cells[[i]];
      hName = SymbolName[Head[cell]];     (* 罠 #23 対応 *)
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

### CellPath で書き戻し: iNBReplaceCellInList

```mathematica
iNBReplaceCellInList[cells_List, {i_Integer}, newCell_] :=
  ReplacePart[cells, i -> newCell];

iNBReplaceCellInList[cells_List, {i_Integer, rest__Integer}, newCell_] :=
  Module[{cell, inner, newInner, newCellGroup, hName},
    cell = cells[[i]];
    hName = SymbolName[Head[cell]];
    If[hName === "Cell" && Length[cell] >= 1 &&
        SymbolName[Head[cell[[1]]]] === "CellGroupData",
      inner = cell[[1, 1]];
      newInner = iNBReplaceCellInList[inner, {rest}, newCell];
      newCellGroup = ReplacePart[cell[[1]], 1 -> newInner];
      ReplacePart[cells, i -> ReplacePart[cell, 1 -> newCellGroup]],
      cells]   (* path 不整合時は元のまま (no-op) *)
  ];
```

### atomic write: iNBFileSaveExpr

```mathematica
iNBFileSaveExpr[path_String, nbExpr_] :=
  Module[{abs, tmpPath},
    abs = ExpandFileName[path];
    tmpPath = abs <> ".tmp-" <> ToString[$ProcessID] <> "-" <>
      ToString[Hash[SessionTime[]]];
    Export[tmpPath, nbExpr, "NB"];
    If[FileExistsQ[abs], DeleteFile[abs]];   (* Windows 対応 *)
    RenameFile[tmpPath, abs]
  ];
```

### Header フィルタ: iNBIsHeaderLikeAssoc

```mathematica
iNBIsHeaderLikeAssoc[assoc_Association] :=
  AnyTrue[{"Keywords", "Status", "Deadline", "NextReview",
    "Owner", "PathHint", "Title"},
    KeyExistsQ[assoc, #] &] &&
  Length[assoc] > 0;
iNBIsHeaderLikeAssoc[_] := False;
```

### BoxData → Header: iNBExtractHeaderFromBoxData

```mathematica
iNBExtractHeaderFromBoxData[nbExpr_] :=
  Module[{cells, flat, found = Missing["NotPresent"]},
    cells = iNBNotebookCells[nbExpr];
    flat = iNBFlattenCells[cells, {}];
    Scan[Function[entry,
      If[MissingQ[found],
        Module[{cell, style, content, held, value},
          cell = entry[[1]];
          style = iNBCellStyle[cell];
          If[!(StringQ[style] && MemberQ[{"Input"}, style]),
            Return[Null, Module]];
          content = cell[[1]];
          If[!(MatchQ[content, _BoxData] || StringQ[content]),
            Return[Null, Module]];
          held = Quiet[MakeExpression[content, StandardForm]];
          If[!MatchQ[held, HoldComplete[_Association]],
            Return[Null, Module]];
          value = ReleaseHold[held];
          If[AssociationQ[value], found = value]]]], flat];
    found
  ];
```

## SourceVaultMarkTodo: 薄いラッパー

`SourceVault.wl` の `SourceVaultMarkTodo` は `NBWriteTodoStatus` への **薄いラッパー**:

1. target (Integer / String / Association) を `iSVResolveTodoTarget` で `<|"Index" -> _, "Text" -> _|>` に正規化
2. `NBWriteTodoStatus` を完全修飾名で呼び出す
3. `"AutoReindex" -> True` (default、`"DryRun" -> False` の時のみ) で `SourceVaultIndexNotebook` を自動呼び出し
4. 結果に `ReindexResult` フィールドを付与

```mathematica
SourceVaultMarkTodo[path, target, newStatus, opts___] :=
  Module[{todoKey, nbResult, reindexResult},
    todoKey = iSVResolveTodoTarget[path, target];
    If[!AssociationQ[todoKey],
      Return[<|"Status" -> "Failed",
        "Reason" -> "TodoTargetResolutionFailed", ...|>]];
    Quiet @ Needs["NBAccess`"];
    If[Length[Names["NBAccess`NBWriteTodoStatus"]] === 0,
      Return[<|"Status" -> "Failed",
        "Reason" -> "NBWriteTodoStatusNotAvailable"|>]];
    nbResult = NBAccess`NBWriteTodoStatus[path, todoKey, newStatus,
      NBAccess`AccessSpec -> spec,
      NBAccess`DryRun -> dryRun];
    reindexResult = If[autoReindex && !dryRun && Lookup[nbResult, "Status"] === "OK",
      SourceVaultIndexNotebook[path], Missing["NotRequested"]];
    Join[nbResult, <|"ReindexResult" -> reindexResult|>]
  ];
```

## 罠 #26-#28 との関係

| 罠 | NBAccess での対応 |
|---|---|
| **#26** (CellGroupData ネスト) | `iNBFlattenCells` で再帰展開、`CellPath` で位置記録 |
| **#27** (Module + HoldComplete ローカル変数残存) | DryRun の Before/After は `With[{c = cell, nc = newCell}, HoldComplete[...]]` |
| **#28** (ImportString RawJSON が Windows path で失敗) | NBAccess は JSON 永続化を直接行わないが、SourceVault 側で `iLoadJSONFromFile` の 3 段階 fallback |

## Stage 9 P0 の Approval Workflow 経路との使い分け

| 用途 | 経路 | 理由 |
|---|---|---|
| SourceVault index 統合 / batch / scheduled task | **Stage 9 P1 semantic API** | FrontEnd 不要、atomic write、closed notebook OK |
| Interactive 編集 (ユーザーが notebook 開いてる時) | Stage 9 P0 Approval Workflow (`NBOpenAuthorized` + `NBProcessFile`) | FrontEnd の事前承認 UI を使える |
| privacy profile による route 分岐 | **Stage 9 Phase 3 (P2) で実装予定** | NBProcessFile の PrivacyLevel ベース routing と統合 |

## テスト notebook (実証用)

```
C:\Users\imai_\Dropbox\On Work\20260516-第14回オンライン語り交流会\20260516-第14回オンライン語り交流会.nb
```

- nbRef: `"nb-src-5d9fd9f24923df19"`
- 構造: Title cell + Subsection cell + TodoItem_1 cell (3 leaf cell)
- 直近 SnapshotId: `"snap-sha256-13df6f0aabf70f48b9f2a8e59dc3e9f4351c2d426c5fce6239570f2a9355f1c9"`

result22.nb 〜 result34.nb の 13 ラウンドの往復で:
- NBReadTodos: Count: 1, CellPath: {2, 1}
- SourceVaultMarkTodo: Open ↔ Done のラウンドトリップ
- NBReadHeader: Source: "BoxData"、SourceVault と内容完全一致 (Out[10]: `{True, True, True}`)

を実証済み (handoff_2026-05-20-stage9-p1.md 参照)。

## Stage 9 Phase 3 (P2) への伏線

- **バッチ Todo 操作**: `SourceVaultMarkTodos[path, [{idx1, "Done"}, {idx2, "Pass"}]]`
- **Header migration**: 既存の BoxData 形式 Header を Notebook 全体 TaggingRules に移行 (将来は `Source: "TaggingRules"` がデフォルト)
- **privacy profile による route 分岐**: PrivacyLevel >= 0.5 のセルは local LLM、それ未満は cloud LLM で処理
- **ClaudeEval / ClaudeOrchestrator 統合**: agentic workflow から semantic API を呼ぶ
- **階層 Bundle**: Sections レベルの aggregation (Stage 6c Phase 2 と統合)

## 関連 skills / rules

- `rules/10-nbaccess.md` — NBAccess の使用必須ルール (Stage 9 P1 の semantic API セクション含む)
- `rules/101-sourcevault-stage-status.md` — Stage 9 P1 ステータスと設計ルール
- `skills/notebook-management-extraction` — Stage 9 P0/P1 全体の設計
- `skills/wolfram-syntax-pitfalls` — 罠 #26-#28 の詳細
- `skills/nbaccess-notebook-access` — NBAccess の低レベル API (FrontEnd 経由) の設計
- `skills/jsonl-store-pattern` — SourceVault の永続化レイヤー (Stage 9 P1 の mtime cache がこの上に乗る)

## 関連ドキュメント

- `handoff_2026-05-20-stage9-p1.md` — Stage 9 P1 完成の正式引継ぎ書類
- `example_stage9_p1.md` — Part Q 形式の使用例集 (15 例、12 サンプルコード)
