---
name: notebook-management-extraction
description: |
  SourceVault.wl Stage 9 Phase 1 (P0) の Notebook Management 拡張設計。
  Mathematica notebook を first-class source として扱い、先頭 Input セルから Header Association を
  HoldComplete + whitelist で safe parse、TodoItem cell を style 経由で列挙、TaggingRules や
  StrikeThrough を優先順位付きで Done 判定、7 種 lint (HeaderStatusTodoButNoOpenTodos、DeadlinePast、
  NextReviewPast 等) で Header/Todo 不整合検出、deterministic SourceVaultFindNotebooks クエリ
  (OpenTodos/NextReview/Deadline/Keywords/Status)、notebooks/{sources,snapshots,todos,review,lint}/ の
  index 配置、Phase 2/3 (TaggingRules 標準化、semantic hash、ClaudeEval 統合) への伏線。
  レビュー資料 sourcevault_notebook_review_todo_deadline.md と添付 notebook の実装。
---

# Notebook Management Extension (Stage 9 P0)

「Mathematica notebook を SourceVault に first-class source として登録し、先頭 Input セルの
Header Association、TodoItem cell の Done 状態、Deadline / NextReview を deterministic に
扱えるようにする」最小実装。LLM や Notebook を開かずに、ファイルパース + heuristic だけで動く。

## 設計の核心 — 3 つの分離

### (1) Header.Status と Todo cell 状態の独立保存

レビュー §1.3 の最重要 insight:

```
notebook 先頭 Header:        <|"Status" -> "Todo", ...|>
notebook 内 TodoItem cell:   FontVariations -> {"StrikeThrough" -> True}
                                                  ↓
                              cell 状態 = Done (取消線)
```

これらを **独立に保存** し、不整合を `HeaderStatusTodoButNoOpenTodos` lint として検出する。
「Header Status だけ見て notebook 状態を判定」は明確な anti-pattern。

実用上、Header Status は手動で書き換えるので忘れがち。Todo cell の状態は GUI 操作で変わる。
両者がズレることは自然に発生する。それを **deterministic な query で検出可能にする** のが
Stage 9 の主目的。

### (2) Deterministic index vs LLM 要約

```
Deterministic index (Stage 9 P0):
  - SourceVaultFindNotebooks["OpenTodos" -> True]
  - SourceVaultFindNotebooks["NextReview" -> "Overdue"]
  - SourceVaultFindNotebooks["Deadline" -> "ThisWeek"]
  - SourceVaultFindNotebooks["Keywords" -> {"オンライン語り交流会"}]
  → LLM 不要、低遅延、再現可能

LLM-backed summary (Stage 9 Phase 2 で実装予定):
  - SourceVaultNotebookSummary[nbRef]
  → body 要約、トピック抽出、関連 notebook 発見
```

P0 では deterministic 側だけ。これだけで「今週レビューすべき notebook」「Deadline 過ぎ未完了」
等の主要ユースケースを LLM 不要で処理できる。

### (3) Status 判定の優先順位 (StatusSource で追跡)

レビュー §3.4:

```
1. TaggingRules["TodoStatus"]       → StatusSource: "TaggingRules" (将来の標準)
2. FontVariations StrikeThrough     → StatusSource: "CellOption"   (現状の添付 notebook)
3. 何もなし                          → StatusSource: "Default"      (Open 扱い)
```

各 Todo record に `StatusSource` を保存することで、「TaggingRules への移行が必要な notebook」を
特定できる (`TodoCellStatusHeuristicOnly` lint で警告)。

## Safe Parse — Wolfram 標準関数優先で実装

**重要 (rule 102 と連動)**: ノートブック情報にアクセスする時は **必ず先に Wolfram 標準関数を探す**。パターンマッチは最終手段。Stage 9 P0 では試行錯誤の末、以下の組み合わせが正解と判明:

### Header 取得: `Import[path, "Initialization"]`

```mathematica
inits = Import[path, "Initialization"]
(* → {<|"Keywords" -> {...}, "Deadline" -> DateObject[{2026,5,13}, "Day"],
        "NextReview" -> ..., "Status" -> "Todo"|>} *)
assoc = First[inits];
(* whitelist 後付け検証 *)
If[!AllTrue[Values[assoc], iAllowedHeaderValueQ],
  parseStatus = "UnsafeExpression"];
```

**Safety トレードオフ**: `Import[path, "Initialization"]` は **InitializationCell の中身を評価** するため、副作用ある式が実行される可能性がある。しかし返り値の値レベルで whitelist 検証することで SourceVault 保存を防御。実用性優先の妥協。

### Todo 抽出: `NotebookImport[path, style -> "Cell"]`

```mathematica
cells = NotebookImport[path, "TodoItem_1" -> "Cell"]
(* → {Cell["参加登録", "TodoItem_1",
        FontVariations -> {"StrikeThrough" -> True},
        FontColor -> RGBColor[...], ...]} *)
```

これは **Wolfram の正規 API** で:
- パターンマッチ不要 (context 問題なし)
- `System`Cell[...]` が確実に返る
- ファイル全体を Get する必要なし
- 限定的なスタイルだけ取り出すので高速

`TodoItem_1`, `TodoItem_2`, `TodoItem_3` の 3 スタイルを順に試して結合。

### 第二フォールバック (Header): `MakeExpression`

`Import["Initialization"]` が失敗した場合、`Import[path, "Notebook"]` で Notebook 式取得 → cell 走査 → **`MakeExpression[boxData, StandardForm]`** で box → `HoldComplete[expr]` (評価せず):

```mathematica
boxData = First[headerCell];  (* BoxData[RowBox[{...}]] *)
held = MakeExpression[boxData, StandardForm];   (* HoldComplete[<|...|>] *)
```

**重要**: `ToString[box, StandardForm]` + `ToExpression[str, StandardForm, HoldComplete]` のラウンドトリップは box の意味を保てない (罠 #22)。`MakeExpression` が Wolfram の正規 box→expr 変換関数。

### 廃止: パターンマッチベースの実装

以下は **試行錯誤の過程で実装したが廃止** した経路:

```mathematica
(* NG #1: Get[path] でファイル全体を読む *)
nbExpr = Get[path];   (* FE 連携などの特殊挙動の可能性 (罠 #21) *)

(* NG #2: Import[path, "Text"] + ToExpression *)
expr = ToExpression[Import[path, "Text"], InputForm, HoldComplete];
(* コメント注釈 (*CacheID:...*) と Notebook[...] 式の混在で不安定 *)

(* NG #3: Cell[...] パターンマッチを package private context で書く *)
MatchQ[c, Cell[_, _String, ___]]
(* SourceVault`Private`Cell に解決されて System`Cell[...] と一致しない (罠 #23) *)
```

これらは全て試したが、Stage 9 P0 開発で順に動作不能が判明し、最終的に `NotebookImport` ベースに収束した。

## 7 種 Lint (添付 notebook で実演)

```text
1. MissingHeader                          - 先頭 cell が見つからない
2. UnsafeHeaderExpression                 - whitelist 違反
3. HeaderDeadlineMalformed                - Deadline が DateObject でない
4. HeaderNextReviewMalformed              - NextReview が DateObject でない
5. HeaderStatusTodoButNoOpenTodos         - Header Todo だが Todo cell 全部 Done (添付 notebook で発生)
6. HeaderStatusDoneButOpenTodosExist      - Header Done だが Todo cell 残あり
7. DeadlinePast                           - Deadline 過去 (添付 notebook で発生)
8. NextReviewPast                         - NextReview 過去 (添付 notebook で発生)
9. TodoCellStatusHeuristicOnly            - TaggingRules なし、StrikeThrough だけで判定 (添付で発生)
```

添付 `20260516-第14回オンライン語り交流会.nb` (2026-05-19 時点) では:

| Lint | 発生 |
|---|---|
| `HeaderStatusTodoButNoOpenTodos` | ✓ Header `"Status" -> "Todo"` だが Todo "参加登録" は StrikeThrough |
| `DeadlinePast` | ✓ Deadline 2026-05-13 < today 2026-05-19 |
| `NextReviewPast` | ✓ NextReview 2026-05-13 < today |
| `TodoCellStatusHeuristicOnly` | ✓ TaggingRules なし、StrikeThrough のみ |

これだけで「review dashboard 必須」と即判定可能。

## FindNotebooks クエリの仕様

```mathematica
SourceVaultFindNotebooks[
  "OpenTodos" -> True | False,
  "NextReview" -> "Overdue" | "ThisWeek" | "DueSoon" | <|"From" -> _, "To" -> _|>,
  "Deadline" -> "Overdue" | "ThisWeek" | "DueSoon" | <|"From" -> _, "To" -> _|>,
  "Keywords" -> {_String, ...},   (* いずれかに match *)
  "Status" -> _String              (* Header.Status と完全一致 *)
]
```

**重要な区別**:

```mathematica
SourceVaultFindNotebooks["OpenTodos" -> True]    (* 実作業残あり *)
SourceVaultFindNotebooks["Status" -> "Todo"]     (* Header メタデータ未更新 *)
```

添付 notebook は前者には含まれず、後者には含まれる。ダッシュボード設計では両者を別カラムに
表示すべき。

## 物理ストレージ

```
<PrivateVault>/notebooks/
  sources/
    nb-src-<hash16>.json         # NotebookSourceRecord (path-based stable ID)
  snapshots/
    snap-sha256-<hash>.json      # NotebookSnapshotRecord (content hash)
  todos/
    by-notebook/
      nb-src-<...>.jsonl         # 各 notebook の Todo 一覧
  review/
    overdue.jsonl                # Overdue review 状態の append-only log
  lint/
    notebook-lint.jsonl          # 全 lint event の append-only log
```

**NotebookRef 生成** (path-based, stable):

```mathematica
iNotebookRefFromPath[path_String] :=
  Module[{abs = ExpandFileName[path],
          h = Hash[ExpandFileName[path], "SHA256", "HexString"]},
    "nb-src-" <> StringTake[h, 16]
  ];
```

path が変わると別 NotebookRef になる。Phase 2 で recovery candidate (Title + FileMTime ベース)
を実装予定。

## 罠カタログ対応 (Stage 9 P0 実装で踏んだもの)

| # | 罠 | 状況 |
|---|---|---|
| #11 | `\uXXXX` 文字列リテラル | **累計 1107 件混入** → 一括修正。Stage 9 だけで 266 件 (Stage 6c 72 + 8 295 + 6d 94 + 6b 380 + 9 266)。最大の継続的エラー源、5 回目の reincidence |
| #11 補足 | `\:` 後 4 桁 hex 未満 | 1 件 (`\:a7 3.4` → `\:00a7 3.4`)。コメント内の仕様書参照で発生 |
| **#21 (新規)** | `.nb` を `Get[path]` / `Import[path, "Text"]` でパース | **Stage 9 で発見**。result6.nb で MissingHeader、result7.nb で部分的失敗。`Import[path, "Notebook"]` / `NotebookImport` に切替で解決 |
| **#22 (新規)** | `ToString[box, StandardForm]` + `ToExpression` ラウンドトリップ | result7.nb で Header parse 失敗の真因。`MakeExpression[box, StandardForm]` に切替 |
| **#23 (新規)** | Package private context で Cell/Notebook 生パターンマッチ | result8.nb で Header OK / Todo 失敗の context 解決問題。最終的に `NotebookImport[path, style -> "Cell"]` で根本回避 |
| #15 | Map + Function + Return | 該当なし |
| #16 | Quiet@Check | 全箇所 `Quiet[expr]` 単独 |
| #20 | Windows `ReadList` | `Import[..., "Text"]` 系を使うので影響なし |

## チェックリスト

- [ ] 新規コード追加直後に `grep '\\u[0-9a-fA-F]\{4\}' SourceVault.wl` (罠 #11、累計 1107 件)
- [ ] `\:` の後は **必ず 4 桁** hex を確認 (罠 #11 補足、特に `\:00a7` の先頭 0 忘れ)
- [ ] **Notebook 情報にアクセスする場合は必ず先に Wolfram 標準関数を探す** (rule 102 の原則)
- [ ] Header parse は `Import[path, "Initialization"]` を第一選択にし、whitelist で値検証
- [ ] Todo 抽出は `NotebookImport[path, style -> "Cell"]` を `TodoItem_1/2/3` で試す
- [ ] box → expr 変換は `MakeExpression[box, StandardForm]` (`ToString`+`ToExpression` ラウンドトリップ禁止、罠 #22)
- [ ] パッケージ private context で `Cell[...]` / `Notebook[...]` 生パターンマッチを書かない (罠 #23)。やむを得ない場合は `SymbolName[Head[c]]` 文字列比較で context 非依存に
- [ ] `Get[path]` / `Import[path, "Text"]` で `.nb` をパースしない (罠 #21)
- [ ] Todo Status 判定は (1) TaggingRules → (2) StrikeThrough → (3) Default の優先順位
- [ ] StatusSource フィールドで判定根拠を必ず保存
- [ ] NotebookRef は path-based (Hash[absolutePath, "SHA256"])
- [ ] SnapshotId は content-based (Hash[file content, "SHA256"])
- [ ] Header Status と Todo cell 状態を独立に保存 (合成判定は lint で)
- [ ] `iSanitizeForJSON` を全 JSON 保存で経由
- [ ] `iEnsureRoots[]` を全 public API 冒頭で呼ぶ

## Phase 2 (P1) / Phase 3 (P2) ロードマップ

**Phase 2 (P1)**:

- `TaggingRules` ベースの明示 TodoStatus 標準化 (style notebook 側も改修)
- `NotebookSemanticHash` (表示・cache・CellChangeTimes 除外、Stage 8 と統合)
- Summary artifact の stale 判定 → Stage 8 lifecycle event と統合
- Section / cell 単位の差分 summary 更新
- NBAccess privacy profile による route 分岐 (`NBNotebookPrivacyProfile`)
- `SourceVaultMarkTodo[todoId, "Done"]` (notebook commit、NBAccess approval 必須)
- file mtime ベースの index skip (`ForceReindex -> False` を活用)

**Phase 3 (P2)**:

- ClaudeEval から自然言語 → SourceVault notebook query 変換
  - 「先月作業した notebook のうち、まだ Todo が残っているもの」
  - 「今週レビューする notebook を出して」
- `NotebookReviewDashboard` workflow template (ClaudeOrchestrator)
- Todo 更新 workflow (commit approval は NBAccess 経由)
- Summary refresh workflow (Stage 6c Bundle と統合)
- workflow run / prompt trace を SourceVault artifact として保存

## Stage 6c / 8 / 6d / 6b との接続

| 既存 Stage | Stage 9 での活用 |
|---|---|
| Stage 6c (Evidence Bundle) | NotebookSummaryArtifact は Bundle の `Kind: "Notebook"` 特化形 |
| Stage 8 (vN diff) | Notebook 更新時の lifecycle event を再利用 |
| Stage 6d (NBAuthorize) | privacy 配慮を要する notebook で sendDecision/persistDecision を呼ぶ |
| Stage 6b (Registry) | Notebook query 結果を compiled registry 化 (Phase 2) |
| Stage 6a (Claim dedup) | Notebook 内容から claim 抽出する場合の dedup (Phase 3) |

特に Stage 6c Phase 2 (階層集約) と Stage 9 は強く結びつく:
**Notebook = 最も自然な階層 Bundle のユースケース** (Notebook → Sections → Cells)。

## 仕様書との対応

| レビュー §節 | Phase 1 実装状況 |
|---|---|
| §1 現在形式の読み取り | ✓ |
| §3.1 NotebookSourceRecord | ✓ path-based ID、Type/Path/Title/FileMTime/CurrentSnapshotId 保存 |
| §3.2 NotebookSnapshotRecord | △ RawContentHash + CellCount + LifecycleStatus。SemanticHash 等は Phase 2 |
| §3.3 NotebookHeaderRecord | ✓ Keywords/Deadline/NextReview/Status + ParseStatus |
| §3.4 NotebookTodoRecord | ✓ Text/Status/StatusSource/StrikeThrough。Depth/ParentTodoId は Phase 2 |
| §3.5 NotebookReviewRecord | ✓ overdue.jsonl に append-only。by-date pivot は Phase 2 |
| §3.6 NotebookSummaryArtifact | × Phase 2 で実装 (LLM 要約) |
| §4 保存レイアウト | ✓ sources/snapshots/todos/review/lint |
| §5.1 登録・index | ✓ Register/Index/IndexFolder |
| §5.2 抽出 | ✓ ExtractHeader/ExtractTodos。CellStyles 等は Phase 2 |
| §5.3 検索 | ✓ OpenTodos/NextReview/Deadline/Keywords/Status |
| §5.4 概要・更新 | × Phase 2 |
| §5.5 Todo 更新 | ✓ **Stage 9 P1 Step 6 で実装** (`SourceVaultMarkTodo` → `NBWriteTodoStatus`) |
| §6.1 ヘッダ安全 parse | ✓ HoldComplete + whitelist。**Stage 9 P1 Step 8 で MakeExpression 第一選択化** |
| §6.2 Todo cell 抽出 | ✓ StrikeThrough 判定、TaggingRules 優先 |
| §6.3 Lint | ✓ 7 種実装 |
| §6.4 Summary 取り込み | ✓ **Stage 9 P1 Step 5 で実装** (`SourceVaultNotebookSummary`) |
| §6.5 Index 更新 | ✓ atomic-ish (file 単位 write、**Stage 9 P1 Step 7 で mtime cache 追加**) |
| §7 NBAccess / privacy 接続 | ✓ **Stage 9 P1 で実装** (NBAccess に semantic API 7 個) |
| §8 ClaudeEval / Orchestrator | × Phase 3 (P2) |
| §11 P0 優先順位 | ✓ 全項目実装 |
| §10 テスト T-NB-1〜5 | ✓ 添付 notebook で実演可能 |

---

# Stage 9 P1 拡張 (2026-05-20 完成)

`handoff_2026-05-20-stage9-p1.md` を参照。完成版 `v2026-05-19-stage-9-p1-step8-nbreadheader-boxdata-filter`。

## Step 別の達成項目

| Step | 内容 | 主要 API |
|---|---|---|
| 1-4 | TaggingRules 標準化 / `NotebookSemanticHash` / Summary stale 判定 / UTF-8 ファイル正常化 | (内部) |
| 5 | LLM 要約 (Step 4 Register 内部呼び出し版) | `SourceVaultNotebookSummary[path, opts]` |
| **6** | **NBAccess 高レベル書き込み API + SourceVaultMarkTodo** | `SourceVaultMarkTodo`, `NBWriteHeader`, `NBWriteTodoStatus`, `NBSetCellOptionsByPredicate`, `NBSetCellTaggingRuleByPredicate` |
| **7** | **mtime ベース skip** (透過的キャッシュ) | `SourceVaultIndexNotebook[path]` の `"Cached"` / `"SourceMTime"` / `"ForceReindex"` |
| **8** | **MakeExpression 第一選択化** (副作用回避) | `iNotebookHeaderParse` 経路順序逆転、戻り値に `"Source"` フィールド |
| 別件 1 | CellCount = 0 バグ修正 (罠 #26 対応) | `iFlattenCells` に切替 |
| 別件 2 | `NBReadHeader` の Source: "None" 問題 | MakeExpression パス追加 + `iNBIsHeaderLikeAssoc` Header フィルタ |

## Stage 9 P1 の核心設計原則

### 1. ファイル直接編集 (FrontEnd 不要)

旧 P0 案では `NBAccess approval workflow + FrontEnd 開く` 方式を検討したが、closed notebook を扱えない、scheduled task で動かない、等の制約があった。P1 では `Import["Notebook"]` → 編集 → `Export[path, ..., "NB"]` のファイル直接編集パイプラインを採用。

```mathematica
(* atomic write パターン *)
iNBFileSaveExpr[path_, nbExpr_] :=
  Module[{tmpPath = path <> ".tmp-" <> ToString[$ProcessID]},
    Export[tmpPath, nbExpr, "NB"];
    If[FileExistsQ[path], DeleteFile[path]];   (* Windows 対応 *)
    RenameFile[tmpPath, path]
  ];
```

### 2. AccessLevel RBAC + DryRun

書き込み系は **`AccessLevel >= 0.7` 必須** (default 0.7)、読み取り系は default 0.5 (Public)。DryRun は書き込み系のデフォルトを `True` にして、Before/After を `With[{c = cell}, HoldComplete[c]]` で値を埋め込んで返す (罠 #27 対応)。

### 3. CellPath による正確な書き戻し

Todo cell の位置を `CellPath = {2, 1, 3}` のような **List of Integer** で記録 (CellGroupData ネスト対応、罠 #26)。書き戻し時は `cells[[2, 1, 1, 3]]` で正確にアクセスできる。

```mathematica
iNBReplaceCellInList[cells_List, {i_Integer, rest__}, newCell_] :=
  Module[{cell, inner, newInner, newCellGroup, hName},
    cell = cells[[i]];
    hName = SymbolName[Head[cell]];
    If[hName === "Cell" && Length[cell] >= 1 &&
        SymbolName[Head[cell[[1]]]] === "CellGroupData",
      inner = cell[[1, 1]];
      newInner = iNBReplaceCellInList[inner, {rest}, newCell];
      newCellGroup = ReplacePart[cell[[1]], 1 -> newInner];
      ReplacePart[cells, i -> ReplacePart[cell, 1 -> newCellGroup]],
      cells]   (* path 不整合時は元のまま *)
  ];
```

### 4. mtime ベース cache (Step 7)

`SourceVaultIndexNotebook[path]` は冒頭で `UnixTime[FileDate[path, "Modification"]]` と snapshot record の `"SourceMTime"` を比較し、一致なら **完全な Index 結果を再構築して返す** (Header/Todo は再抽出、`Import["Notebook"]` と `SemanticHash` 計算をスキップ)。透過的キャッシュなので呼び出し側コード変更不要。

```mathematica
SourceVaultIndexNotebook[path_, opts:OptionsPattern[]] :=
  Module[{currentMTime, cachedResult, ...},
    currentMTime = Quiet @ UnixTime[FileDate[abs, "Modification"]];
    If[!forceReindex && IntegerQ[currentMTime],
      cachedResult = iSVCheckMTimeCache[abs, nbRef, currentMTime];
      If[cachedResult["Cached"] === True, Return[cachedResult]]];
    (* ...通常の reindex フロー... *)
  ];
```

### 5. Header parser の MakeExpression 第一選択化 (Step 8)

旧 P0 案では `Import["Initialization"]` (Wolfram が InitializationCell の中身を **評価する** 副作用あり) を第一選択。P1 では順序逆転:

1. (B) `Import["Notebook"]` + `MakeExpression[box, StandardForm]` ← **第一選択 (副作用なし)**
2. (A) `Import["Initialization"]` ← fallback (副作用あり、最後の砦)

戻り値に `"Source"` フィールド (`"MakeExpression"` / `"Initialization"`) を追加して経路を明示。

### 6. NBReadHeader の 3 経路 fallback (別件 2)

NBAccess `NBReadHeader[path]` は以下の順序で Header を探す:

1. Notebook 全体 TaggingRules > SourceVault (Header フィルタ通過のみ)
2. Cell 単位 TaggingRules > SourceVault (Header フィルタ通過のみ、TodoStatus のような Todo metadata を除外)
3. Input cell の BoxData → `MakeExpression[boxData, StandardForm]` で Association 化
4. None

**Header フィルタ** (`iNBIsHeaderLikeAssoc`): Header らしいキー (`Keywords` / `Status` / `Deadline` / `NextReview` / `Owner` / `PathHint` / `Title`) のいずれかを含む Association のみ Header と認める。これにより、Step 6 で SourceVaultMarkTodo が書き込んだ TodoItem cell の `<|"TodoStatus" -> "Done"|>` のような Todo metadata を Header と誤認しない。

## Stage 9 P0 → P1 の API 互換性

P0 で確立した API は **完全に維持**。P1 は加えるだけ:

| 既存 API | P1 での変更 |
|---|---|
| `SourceVaultIndexNotebook[path, opts]` | 戻り値に `"Cached"` / `"SourceMTime"` 追加 (既存フィールド不変)、新オプション `"ForceReindex"` |
| `SourceVaultExtractNotebookHeader[path]` | 戻り値の Header に `"Source"` フィールド追加 |
| `SourceVaultExtractNotebookTodos[path]` | 不変 |

## 新規 API 一覧 (Stage 9 P1)

| API | パッケージ | レベル |
|---|---|---|
| `NBReadHeader[path, opts]` | NBAccess | 高 (3 経路 fallback) |
| `NBReadTodos[path, opts]` | NBAccess | 高 (CellGroupData 再帰展開) |
| `NBFindCellByPredicate[path, predicate, opts]` | NBAccess | 中 |
| `NBWriteHeader[path, key, value, opts]` | NBAccess | 高 (atomic write) |
| `NBWriteTodoStatus[path, todoKey, newStatus, opts]` | NBAccess | 高 (atomic write) |
| `NBSetCellOptionsByPredicate[path, pred, opts__, opts2]` | NBAccess | 中 (atomic write) |
| `NBSetCellTaggingRuleByPredicate[path, pred, taggingPath, value, opts]` | NBAccess | 中 (atomic write) |
| `SourceVaultMarkTodo[path, target, newStatus, opts]` | SourceVault | 高 (`NBWriteTodoStatus` への薄いラッパー) |
| `SourceVaultNotebookSummary[path, opts]` | SourceVault | 高 (P1 Step 5 で追加、LLM 要約) |

---

# 次フェーズ: Sync / Relink / UUID 埋め込み (2026-05-22 完成)

## SourceVaultSync — クローラー骨格

巡回して鮮度の落ちた notebook source を再 index する仕組み。公開 API 4 個。

- `SourceVaultSelectSources[opts]` — Scope 配下の .nb を走査し source descriptor 化
- `SourceVaultSyncPlan[opts]` — 各 source の鮮度を判定 (dry-run、副作用なし)。`Fresh` / `Stale` / `Missing` / `NeverIndexed` に分類
- `SourceVaultSync[opts]` — Stale な source を `SourceVaultIndexNotebook` で再 index
- `SourceVaultSyncStatus[]` — 直近 sync の状態 (`sync/last-sync.json`)

設計の核心:

- **鮮度トークン抽象** — `iSVFreshnessToken` がローカルファイルは mtime (`UnixTime`) を返す。web (ETag / Last-Modified / TTL) は `Kind -> "Web"` の枠だけ予約 (`NotImplemented`)。鮮度判定は「現トークン vs 記録済みトークン」の比較
- **PrivacyLevel は単調** — 再 index で snapshot の PrivacyLevel が下がったら、`SourceVaultSetSnapshotPrivacyLevel` で旧値に引き上げ、`PrivacyWarnings` に記録。プライバシーは「下げる方向」に自動変化させない
- **一括同期の安全側既定** — `FallbackToCloud -> "Deny"` が既定。多数ファイルの一括処理でクラウド送信を暗黙に許可しない
- ストア `notebooks/sync/` — `sync-history.jsonl` (append-only) + `last-sync.json`

## SourceVaultRelinkSources — ファイル移動追跡

`OriginalPath` が消えた notebook source の移動先を探して再リンク。`iSVRelinkSources` プレースホルダーを置換 (後方互換エイリアス保持)。

**3 段照合 (信頼度の高い順)**:

1. **埋め込み UUID** — TaggingRules `SourceVault > NotebookUUID`。最も信頼でき、ファイル名・内容が変わっても追跡可能
2. **内容ハッシュ** — `RawContentHash` の完全一致
3. **ファイル名一意一致** — Scope 内に同名ファイルが 1 つだけのとき

設計の核心 (rule 103 に直結):

- **移動判定はシンボリックパス解決ベース** — 「移動したか」は `OriginalPath` の生 `FileExistsQ` でなく、record の `SymbolicPath` を `iSVResolvePath` で現 PC 解決して実在判定する。別 PC のパス差 (`C:\Users\imai_\...` vs `F:\Dropbox\...`) を移動と誤検出しない
- **強い証拠と弱い証拠を分ける** — UUID / 内容ハッシュ一致は自動適用するが、ファイル名一致 (`NameOnly`) は弱い証拠なので `ApplyNameOnly -> True` のときのみ適用。既定はレポートのみ。連番ファイル群 (`計算と自然 01`〜`25`) の誤マッチ防止
- **StaleDuplicate 判定** — マッチ先が既に別の現役 record の指す実ファイルなら、それは「移動」でなく「旧 PC index の残骸」。Relink 開始時に「全現役 record の実ファイルパス集合」(`livePathSet`) を構築し、マッチ先がそこに含まれるかを**実パスで**判定 (NotebookRef のハッシュ衝突を避ける)。`DeleteStale -> True` で残骸 record を削除 (既定 False は非破壊マーク `RelinkStatus -> "StaleDuplicate"`)
- **非破壊** — `DryRun` 既定 `True`。`DryRun -> False` でも旧 record は削除せず `Superseded` マークのみ (`DeleteStale` を除く)
- 戻り値に `ByMethod` (UUID / ContentHash / NameOnly 別件数)、`StaleDuplicateCount`、`StaleDeletedCount`
- ストア `notebooks/relink/relink-log.jsonl`

開発中、`Linked` 判定の早期 return を内側 `Module` に閉じ込めたバグ (罠 #52) で全件が照合ループに流れ `Relinked` が膨張した。修正後は 366 ファイルで `Linked: 365 / Relinked: 0` に収束。

## Notebook UUID 埋め込み機構

Relink の最上位照合キーを供給する基盤。公開 API 3 個。

- `SourceVaultNotebookUUID[path]` — 埋め込み UUID を読む (読み取りのみ)
- `SourceVaultEnsureNotebookUUID[path, opts]` — UUID が無ければ生成して埋め込む。`Force` で再生成
- `SourceVaultEnsureNotebookUUIDFolder[dir, opts]` — folder 一括付与

設計の核心:

- UUID は notebook の **TaggingRules `SourceVault > NotebookUUID`** に保存 (`nbuuid-` + `CreateUUID`)。Step 1 の CloudPublishable と同じ名前空間。Header (Initialization セル) でなく TaggingRules を選ぶことで、ファイル本文を書き換えず非破壊、かつファイルと一緒に移動する
- 書き込みは `NBFileOpen` (`Visible -> False`) → `NBSetTaggingRule` → `NBFileSave` → `NBFileClose`
- `SourceVaultIndexNotebook` の sourceRecord に `SourceUUID` と `SymbolicPath` フィールドを追加 — index 時に埋め込み UUID とシンボリックパスを記録し、Relink の照合・移動判定の基盤データにする
- `EnsureNotebookUUIDFolder` の巨大ファイルは `Skipped` (`Failed` と別カウント) — TaggingRules 書き込みには巨大 notebook を開く必要があるため、サイズ閾値超えはスキップ

運用注意: UUID 付与は notebook の mtime を変えるため、「**UUID 一括付与 → 全件 index → 以降 Sync で安定運用**」の順序で行う。付与直後に Sync を走らせると全件 Stale 判定になる。

## モデルレジストリ動的更新

`skills/compiled-registry-and-seed` 参照。`$SourceVaultModelEndpoints` + `SourceVaultModelEndpointStatus` / `SourceVaultDetectLocalModels` / `SourceVaultRefreshModelRegistry`。

## Stage 9 Phase 3 (P2) への伏線

- バッチ Todo 操作 (`SourceVaultMarkTodos[path, [{idx1, "Done"}, {idx2, "Pass"}]]`)
- Notebook 全体の TaggingRules > SourceVault Header migration (BoxData → TaggingRules 形式)
- NBAccess privacy profile による route 分岐
- ClaudeEval / ClaudeOrchestrator 統合
- 階層 (Sections) Bundle (Stage 6c Phase 2 と統合)
- Sync の web source 実 fetch / Orchestrator 経由の非同期 Sync
- `SourceVaultIngest` 時の UUID 自動付与
- `iSVSymbolicPath` の旧 PC ルートエイリアス対応 (二重登録の未然防止)

## 関連 skills

- `skills/nbaccess-semantic-api` — NBAccess semantic API の設計詳細
- `skills/wolfram-syntax-pitfalls` — 罠 #26-#28 (CellGroupData ネスト / Module + HoldComplete / JSON RawJSON fallback) + 罠 #52-#54 (次フェーズ)
- `rules/103-sourcevault-datastore-safety.md` — データストア書き込み安全規約
