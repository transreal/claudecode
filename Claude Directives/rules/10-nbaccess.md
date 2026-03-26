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

## 判断
- Notebook 関連の新機能は NBAccess の既存 API で表現できないか先に確認する。
- 足りない場合は上位パッケージで回避策を書く前に NBAccess に責務を追加する。
