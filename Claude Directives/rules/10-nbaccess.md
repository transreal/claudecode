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

## 禁止

### セル直接操作（従来ルール）
- `Cells[...]` / `NotebookRead[...]` / `NotebookWrite[...]` / `SelectionMove[...]` を組み合わせた独自実装を NBAccess を迂回して増やさない。
- 機密セルや依存セルの判定を ad hoc に書かない。

### 現在セル取得・FE 状態操作
- `EvaluationCell[]` / `SelectedCells[]` / `ParentNotebook[EvaluationCell[]]` の直接使用禁止 — `NBBeginJobAtEvalCell`, `NBParentNotebookOfCurrentCell`, `NBWriteAnchorAfterEvalCell` を使う。
- `CellPrint[...]` の直接使用禁止 — `NBWriteCell` / `NBWritePrintNotice` を使う。
- `SetSelectedNotebook[...]` / `SelectionEvaluate[...]` / `FrontEndTokenExecute[...]` の直接使用禁止 — `NBEvaluatePreviousCell`, `NBInsertAndEvaluateInput`, `NBWriteInputCellAndMaybeEvaluate` を使う。

### セル属性の直接アクセス
- `CurrentValue[..., TaggingRules]` / `SetOptions[..., TaggingRules -> ...]` の直接使用禁止 — `NBCellGetTaggingRule`, `NBCellSetOptions` を使う。
- `CurrentValue[..., CellTags]` / `SetOptions[..., CellTags -> ...]` の直接使用禁止 — `NBCellIndicesByTag`, `NBCellSetOptions` を使う。
- `CurrentValue[..., CellEpilog]` / `SetOptions[..., CellEpilog ...]` の直接使用禁止 — `NBInstallCellEpilog`, `NBInstallConfidentialEpilog` を使う。
- `CellProlog`, `NotebookEventActions`, `CellDynamicExpression`, `NotebookDynamicExpression` のフック系オプションも同様に NBAccess に集約する。

### CellObject の漏洩禁止
- 公開関数の引数パターンに `_CellObject` を使わない。
- 公開関数の戻り値として `CellObject` を返さない。
- `Association` やグローバル変数に `CellObject` を保存しない。

### NBAccess 公開グローバルの保護
- `NBAccess`$NBConfidentialSymbols` 等の公開グローバルに対して `AppendTo`, `AssociateTo`, `PrependTo`, `KeyDropFrom`, `Unset`, Part 代入 (`x[key] = ...`) を直接使用しない — setter API (`NBRegisterConfidentialVar`, `NBSetConfidentialVars` 等) を使う。

## ボタン再実行防止（必須）

Output セル内のインタラクティブボタン (`Button[..., Method -> "Queued"]`) は、CTRL-Z (Undo) でセル状態が巻き戻された際にボタンの評価式が再トリガーされ、API 呼び出しが二重実行される問題がある。

### 必須対策: `$iGitHubEvalGuard` パターン

API 呼び出しを伴うボタンには必ず再実行防止ガードを入れる:

```mathematica
(* ✅ 正しいパターン *)
Button["Review",
  Module[{gk = "btn-review:" <> pkg <> ":" <> sha},
    If[TrueQ[$iGitHubEvalGuard[gk]], Return[]];
    $iGitHubEvalGuard[gk] = True;
    WithCleanup[
      GitHubReviewCommit[pkg, sha],
      $iGitHubEvalGuard = KeyDrop[$iGitHubEvalGuard, gk]]],
  Method -> "Queued"]
```

```mathematica
(* ❌ 禁止パターン: ガードなしでボタンから直接 API 呼び出し *)
Button["Review",
  GitHubReviewCommit[pkg, sha],
  Method -> "Queued"]
```

### ガードの設計原則
- ガードキーは操作種別 + 対象を一意に特定する文字列（例: `"btn-review:pkg:sha"`）
- `WithCleanup` で正常終了・異常終了の両方でガードを解除する
- ボタンだけでなく、ボタンから呼ばれる関数本体にもガードを入れる（二重防御）

## 例外（この2ファイルのみ）
- **NBAccess.wl**: セルへの直接アクセス関数を自由に作成してよい。NBAccess 自体がセルアクセスの一元化層であるため、直接アクセスは当然必要。
- **NotebookExtensions.wl**: 基本的なセルアクセスユーティリティを多数含むため、直接セルアクセスを許容する。

上記2ファイル以外のパッケージでは、セルへの直接アクセスは一切認めない。

## 判断
- Notebook 関連の新機能は、まず NBAccess の既存 API で表現できないか確認する。
- 足りない場合は上位パッケージで回避策を書く前に NBAccess に責務を追加する。
