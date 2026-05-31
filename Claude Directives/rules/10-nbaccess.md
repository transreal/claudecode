---
paths:
  - "**/{NBAccess,claudecode,NotebookExtensions,PresentationListener}*.{wl,wls,m,nb}"
  - "**/*Notebook*.{wl,wls,m,nb}"
  - "**/*Palette*.{wl,wls,m,nb}"
---

# NBAccess アクセス制約

## 必須
- Notebook セルの読み書き・マーキング・フィルタリングは NBAccess の公開関数を使う。
- `claudecode.wl` 等の上位層は、Notebook セルや履歴に直接触れず NBAccess 経由で扱う。
- **.nb ファイル**を操作する場合は `NBProcessFile` または NBAccess API のみを使う。

---

## .nb ファイルの処理アーキテクチャ（必読）

### PrivacyLevel による自動ルーティング

`.nb` ファイルのセルには `PrivacyLevel` (0.0〜1.0) が付いている:
- `PrivacyLevel <= 0.5` — 公開セル。クラウド LLM でアクセス可能。
- `PrivacyLevel > 0.5` — 秘匿セル。ローカル LLM (`$ClaudePrivateModel`) でのみ処理可能。

### Private ノートブック宣言 (Stage 9 P1.5)

ノートブック全体を Private 宣言すると、**そのノートブックの全セルを PrivacyLevel 1.0 とみなす**。判定・書き換えは NBAccess が管轄する。
- 実体は frontend memory の TaggingRules `{"SourceVault", "CloudPublishable"}`。`False` = Private, `True` = Public, 未設定 = Unspecified。`NBGetCloudPublishable[path]` で取得。
- セル単位の `NBCellPrivacyLevel` の冒頭で「ノートブックが Private 宣言なら 1.0 を返す」オーバーライドを必ず効かせる。ファイルレベル判定 (`iNBFilePrivacyLevel`) だけ Private→1.0 にしてもセル単位経路が漏れる (実際の漏洩原因だった)。
- Private 宣言判定はセル毎にファイル I/O すると重いので、frontend memory から軽量判定する helper (`iNBNotebookDeclaredPrivateQ`) を使う。
- モデル検証も NBAccess 管轄: `NBModelCanHandleAccessLevel[modelSpec, level]` / `NBNotebookRequiredAccessLevel[nb]` (Private→1.0) / `NBModelProviderName[modelSpec]`。provider 別 max access level は lmstudio=1.0、claudecode/anthropic/openai=0.5。

```
nbcells = {機密セル(1.0), セル(0.0), 機密セル(1.0), セル(0.0)}

ClaudeCode (AccessLevel=0.5):
  NBFileReadCellsInRange[nb, 0.0, 0.5]  → {[2, セル], [4, セル]}

$ClaudePrivateModel (AccessLevel=1.0):
  NBFileReadCellsInRange[nb, 0.5, 1.0]  → {[1, 機密セル], [3, 機密セル]}

マージ → {[1,処理済], [2,処理済], [3,処理済], [4,処理済]}
         (元のセル順に再構成)
```

### NBProcessFile — 汎用ファイル処理（最優先で使う）

**セルごとの任意タスクには必ず `NBProcessFile` を使え。**
ルーティング・LLMGraph ノード登録・マージ・保存を全て自動で行う。

```mathematica
(* 翻訳 *)
NBProcessFile[
  "Translate each cell text to English.",
  "C:\\path\\input.nb",
  "C:\\path\\output.nb"
]

(* 要約 *)
NBProcessFile[
  "Summarize each cell in one sentence.",
  "C:\\path\\input.nb",
  "C:\\path\\output.nb"
]

(* 校正 *)
NBProcessFile[
  "Fix grammar and typos in each cell.",
  "C:\\path\\input.nb",
  "C:\\path\\output.nb"
]
```

NBProcessFile の動作:
1. `NBFileReadAllCells` で全セルを取得（PrivacyLevel 付き）
2. `PrivacyLevel <= 0.5` → `iClaudeQueryRaw` (ClaudeCode) で処理 **→ LLMGraph ノードB**
3. `PrivacyLevel > 0.5`  → `$ClaudePrivateModel` で処理 **→ LLMGraph ノードA**
4. 両ノードの結果を元のセル順にマージ（Merge[{resultA, resultB}, First]）
5. `NBFileWriteAllCells` + `NBFileSave` で保存

### 手動テンプレート（NBProcessFile で不足の場合のみ）

```mathematica
Module[{nb2, publicCells, confCells, replacements, outputPath},
  nb2         = NBAccess`NBFileOpen["C:\\path\\input.nb"];
  publicCells = NBAccess`NBFileReadCellsInRange[nb2, 0.0, 0.5];  (* 公開のみ *)
  confCells   = NBAccess`NBFileReadCellsInRange[nb2, 0.5, 1.0];  (* 秘匿のみ *)
  (* ... 各セルを処理 ... *)
  replacements = <|idx1 -> "result1", idx2 -> "result2", ...|>;
  NBAccess`NBFileWriteAllCells[nb2, replacements];
  outputPath = FileNameJoin[{DirectoryName["C:\\path\\input.nb"], "output.nb"}];
  NBAccess`NBFileSave[nb2, outputPath];
  NBAccess`NBFileClose[nb2]
]
```

### .nb ファイル操作の絶対禁止事項

- `Import["*.nb"]` / `Get["*.nb"]` / `NotebookGet[]` — PrivacyLevel を無視する
- `NotebookOpen[]` 直接使用 — `NBFileOpen` を使う
- `Cells[nb]` / `NotebookRead[]` 直接使用 — `NBFileReadCellsInRange` を使う
- `NotebookWrite[]` 直接使用 — `NBFileWriteAllCells` を使う
- `Export[path, Notebook[...], "NB"]` — 秘匿属性が消える
- `URLRead[HTTPRequest[...]]` / `TextTranslation[]` — LLM 呼び出しは claudecode.wl に委ねる
- `Import[src]` + `Cases[..., _Cell, ...]` などの自前セル解析

---

## NBAccess 公開 API 一覧（.nb ファイル系）

| 関数 | 説明 |
|------|------|
| `NBFileOpen[path]` | 非表示でファイルを開く |
| `NBFileClose[nb]` | 閉じる |
| `NBFileSave[nb, path]` | 保存（path=None で上書き） |
| `NBFileReadCells[nb, PrivacySpec->ps]` | PrivacySpec でフィルタ |
| `NBFileReadAllCells[nb]` | 全セル（PrivacyLevel フィールド付き） |
| `NBFileReadCellsInRange[nb, lo, hi]` | lo <= PrivacyLevel <= hi のセルのみ |
| `NBFileWriteCell[nb, idx, newText]` | テキストのみ置換（属性保持） |
| `NBFileWriteAllCells[nb, replacements]` | 複数セル一括置換 |
| `NBFileSpec[path]` | ファイルの ObjectSpec（PrivacyLevel・セル数等） |
| `NBPrivacyLevelToRoutes[level]` | ルート判定 |

---

## 従来のセル操作ルール（変更なし）

### 禁止
- `Cells[...]` / `NotebookRead[...]` / `NotebookWrite[...]` / `SelectionMove[...]` の独自実装
- `EvaluationCell[]` 等の直接使用 — `NBBeginJobAtEvalCell` 等を使う
- `CellPrint[...]` の直接使用 — `NBWriteCell` / `NBWritePrintNotice` を使う
- `CurrentValue[..., TaggingRules]` の直接使用 — `NBCellGetTaggingRule` を使う
- `CellObject` の漏洩（引数・戻り値・グローバル変数）

### ボタン再実行防止（必須）
```mathematica
Button["Action",
  Module[{gk = "btn-action:key"},
    If[TrueQ[$iGitHubEvalGuard[gk]], Return[]];
    $iGitHubEvalGuard[gk] = True;
    WithCleanup[doAction[], $iGitHubEvalGuard = KeyDrop[$iGitHubEvalGuard, gk]]],
  Method -> "Queued"]
```

## 例外（この2ファイルのみ）
- **NBAccess.wl**: セルへの直接アクセス可（NBAccess 自体がアクセス一元化層）
- **NotebookExtensions.wl**: 基本的なセルアクセスユーティリティを許容

上記2ファイル以外のパッケージでは、セルへの直接アクセスは一切認めない。

## 判断
- Notebook 関連の新機能は NBAccess の既存 API で表現できないか先に確認する。
- 足りない場合は上位パッケージで回避策を書く前に NBAccess に責務を追加する。

---

## NBAccess Semantic API (Stage 9 P1 で追加、7 API)

**ファイル直接編集経路**: FrontEnd なしで `.nb` ファイルを操作できる semantic 層。`Import["Notebook"]` → 編集 → `Export[..., "NB"]` (atomic write) のパイプライン。

### 共通仕様

- **AccessSpec**: `<|"AccessLevel" -> _Real, "Environment" -> _String, "AllowedSinks" -> {_String..}|>`
- **読み取り系**: AccessLevel >= 0 で動作 (default 0.5, Public)
- **書き込み系**: **AccessLevel >= 0.7 必須** (default 0.7)
- **DryRun**: 書き込み系のデフォルトは `True` (安全側、Before/After を `HoldComplete[Cell[...]]` で返す)
- **atomic write**: tmp ファイル + `RenameFile` (Windows 対応で既存 path は事前 `DeleteFile`)
- **戻り値**: `<|"Status" -> "OK"|"Failed"|"DryRunOK", ...|>`

### 読み取り系 (3 API)

| API | 機能 |
|---|---|
| `NBReadHeader[path, opts]` | Notebook の SourceVault Header を抽出。3 経路 fallback: (1) Notebook 全体 TaggingRules → (2) Cell 単位 TaggingRules (Header フィルタ適用) → (3) Input cell の BoxData → MakeExpression。Source フィールド値: `"TaggingRules"` / `"HeaderCell"` / `"BoxData"` / `"None"` |
| `NBReadTodos[path, opts]` | 全 Todo cell を抽出 (CellGroupData 再帰展開、罠 #26 対応)。Status は TaggingRules > StyleHeuristic で判定。戻り値に `CellPath` (List of Integer) を含み、書き戻し系で使用可能 |
| `NBFindCellByPredicate[path, predicate, opts]` | 述語マッチの cell を列挙。`CellPath` + `CellIndex` (flat 連番) + `Cell` (HoldComplete) + `Style` + `ExpressionUUID` を返す |

### 書き込み系 (4 API)

| API | 機能 |
|---|---|
| `NBWriteHeader[path, key, value, opts]` | Notebook 全体 TaggingRules > SourceVault に key を merge。既存値は保持 |
| `NBWriteTodoStatus[path, todoKey, newStatus, opts]` | Todo cell の Status を変更 (FontVariations StrikeThrough + FontColor + TaggingRules `SourceVault > TodoStatus` を同時 set)。`todoKey = <\|"Index" -> _, "Text" -> _\|>` で **Index + Text 両方一致** の cell のみ編集 (安全側) |
| `NBSetCellOptionsByPredicate[path, pred, optionRules, opts]` | 述語マッチ cell の options を merge |
| `NBSetCellTaggingRuleByPredicate[path, pred, taggingPath, value, opts]` | 述語マッチ cell の TaggingRules 内 nested key path を set (例: `{"SourceVault", "Priority"}` → `TaggingRules -> <\|"SourceVault" -> <\|"Priority" -> value\|>\|>`) |

### 使用例

```mathematica
(* 読み取り: AccessSpec はデフォルト (Public 0.5) で OK *)
h = NBReadHeader[path]
(* → <|"Status" -> "OK", "Keywords" -> {...}, "Source" -> "BoxData", ...|> *)

(* 書き込み (DryRun = True で先にプレビュー) *)
NBWriteTodoStatus[path, <|"Index" -> 1, "Text" -> "参加登録"|>, "Done"]
(* → <|"Status" -> "DryRunOK",
       "Before" -> HoldComplete[Cell[..., FontVariations -> {"StrikeThrough" -> False}, ...]],
       "After" -> HoldComplete[Cell[..., FontVariations -> {"StrikeThrough" -> True}, ...]]|> *)

(* 実行 *)
NBWriteTodoStatus[path, <|"Index" -> 1, "Text" -> "参加登録"|>, "Done",
  "DryRun" -> False]
(* → <|"Status" -> "OK", ...|> ファイル書き換え発生 *)
```

### 設計原則

- **CellPath は List of Integer** (例: `{2, 1, 3}`): Notebook 内の cell に正確に辿り着くための path (CellGroupData ネストに対応)。flat な連番ではなく path にしたのは、書き戻し時に `cells[[2, 1, ..., 3]]` で安全にアクセスできるため
- **Header と Todo metadata の区別**: NBReadHeader の 2 経路目 (cell 単位 TaggingRules 走査) では `iNBIsHeaderLikeAssoc` フィルタを使い、TodoItem cell の `<|"TodoStatus" -> "Done"|>` のような Todo metadata を Header と誤認しない (Header らしいキー: Keywords/Status/Deadline/NextReview/Owner/PathHint/Title のいずれかを含むもののみ)
- **whitelist なし** (NBReadHeader BoxData 経路): NBAccess は中立的なファイル I/O 層なので、`MakeExpression[boxData, StandardForm]` の結果が `HoldComplete[_Association]` ならそのまま返す。型検証は呼び出し側 (SourceVault の `iAllowedHeaderValueQ` 等) の責務
- **罠 #27 対応**: `Before` / `After` フィールドの Cell expr は `With[{c = cell}, HoldComplete[c]]` で値を埋め込む (Module を抜けた後にローカル変数名が残らないように)

詳細は `skills/nbaccess-semantic-api` 参照。
