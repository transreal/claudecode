---
name: nbaccess-separation-check
description: Use when checking or fixing NBAccess separation principle violations in Wolfram Language packages. Covers ClaudeCheckSeparation, ClaudeFixSeparation, and the $NBSeparationIgnoreList.
---

# NBAccess 分離原則の検証・修正

## 概要

`ClaudeCheckSeparation` と `ClaudeFixSeparation` は、`rules/10-nbaccess.md` で定義された
NBAccess アクセス制約に従っているかを検証・修正するための機能。

## 検査対象の違反

### 静的パターン走査 + LLM 判定（Phase 1 + Phase 2）

| ID | 違反内容 | 推奨代替 |
|----|----------|----------|
| a | `SystemCredential` の直接利用 | `NBGetAPIKey[provider]` |
| b | `CellObject` を直接保持・操作 (`Cells[]`, `NotebookRead[]`, `NotebookWrite[]`, `SelectionMove[]`, `Cell[CellGroupData[...]]` の直接構築等) | NBAccess の公開セルユーティリティ API |
| c | `CellEpilog`/`CellProlog`/`NotebookEventActions` の直接操作 | `NBInstallCellEpilog`, `NBInstallConfidentialEpilog` 等 |
| d | `NBAccess`Private`*` 関数の呼び出し | NBAccess の公開 API |
| e | NBAccess の公開グローバル (`$NBConfidentialSymbols`, `$NBPrivacySpec` 等) を直接更新 | setter 関数 (`NBSetConfidentialVars`, `NBRegisterConfidentialVar` 等) |
| f | `EvaluationCell[]`/`CellPrint[]`/`SetSelectedNotebook[]`/`SelectedCells[]`/`ParentNotebook[EvaluationCell[]]` の直接使用 | `NBBeginJobAtEvalCell`, `NBWriteCell`, `NBWritePrintNotice`, `NBParentNotebookOfCurrentCell` 等 |
| g | `CurrentValue`/`AbsoluteCurrentValue`/`SetOptions` による `TaggingRules`, `CellTags`, `CellEpilog`, `CellProlog`, `NotebookEventActions`, `CellDynamicExpression`, `NotebookDynamicExpression` の直接アクセス | `NBCellGetTaggingRule`, `NBCellSetOptions`, `NBInstallCellEpilog` 等 |
| h | `CellObject` の漏洩: 公開関数引数の `_CellObject` パターン、戻り値としての `CellObject` 返却、`Association`/グローバルへの `CellObject` 保存 | セルインデックスベースの NBAccess API |
| i | FE 状態操作: `SelectionEvaluate[]`, `SelectionEvaluateCreateCell[]`, `SetSelectedNotebook[]`, `FrontEndTokenExecute[]`, `SelectionMove[]` | `NBEvaluatePreviousCell`, `NBInsertAndEvaluateInput`, `NBMoveAfterCell` 等 |
| j | NBAccess 公開グローバルの破壊的更新: `AppendTo`, `AssociateTo`, `PrependTo`, `KeyDropFrom`, `Unset`, Part 代入 (`x[key]=...`) | `NBRegisterConfidentialVar`, `NBSetConfidentialVars` 等の setter API |

## 使用フロー

### 1. 検査のみ
```mathematica
result = ClaudeCheckSeparation["claudecode"]
(* → 違反一覧を表示し、$iSeparationCheckCache に保存 *)
```

### 2. 検査 → 修正
```mathematica
ClaudeCheckSeparation["claudecode"]    (* 検査 *)
ClaudeFixSeparation["claudecode"]      (* キャッシュされた検査結果を使って修正 *)
```

### 3. 修正のみ（検査結果がなければ自動実行）
```mathematica
ClaudeFixSeparation["claudecode"]
(* → キャッシュがなければ先に ClaudeCheckSeparation を実行してから修正 *)
```

### 4. ファイルパス指定
```mathematica
ClaudeCheckSeparation["C:\\path\\to\\file.wl"]
ClaudeFixSeparation["C:\\path\\to\\file.wl"]
(* → バックアップ file_origYYYYMMDDHHMMSS.wl を作成し、元ファイルを修正 *)
```

### 5. パッケージ名のみで更新
```mathematica
ClaudeUpdatePackage["claudecode"]
(* → ClaudeFixSeparation を呼び出す *)
```

## $ClaudeTestModel

検証に使うモデルを `$ClaudeTestModel` で制御可能:
```mathematica
$ClaudeTestModel = "claude-sonnet-4-20250514"  (* 別モデルで客観的に検証 *)
```
デフォルトは `$ClaudeModel` と同じ。

## $NBSeparationIgnoreList

NBAccess.wl で定義。デフォルト: `{"NBAccess", "NotebookExtensions"}`。
これらのパッケージはセルへの直接アクセスが許容されるため検査対象外。

```mathematica
AppendTo[$NBSeparationIgnoreList, "MySpecialPackage"]
```

## キャッシュ機構

- `$iSeparationCheckCache` (claudecode.wl 内部変数) に検査結果を保持。
- `ClaudeFixSeparation` はキャッシュがあればそれを利用し、なければ先に検査を実行。
- 修正完了後にキャッシュはクリアされる。

## プロンプト構成

検査は2フェーズで実行される:

### Phase 1: 静的パターン走査 (`iStaticSeparationScan`)
- 正規表現ベースで約30パターンの禁止シンボルを機械的に検出
- LLM に依存しないため、確実に検出できる（偽陰性の削減）
- コメント行はスキップ、`NBAccess`NB` で始まる公開 API 呼び出しは許可

### Phase 2: LLM による文脈判定
検査プロンプトには以下を含める:
1. 違反ルールの定義（a〜j の全カテゴリ）
2. NBAccess の公開 API の例外説明（`NBAccess`NBxxx[...]` は許可）
3. Phase 1 の静的走査結果（LLM に文脈検証させる）
4. NBAccess_info/docs の関連ドキュメント（api.md, design.md, specification.md の先頭 4000 文字）
5. 検査対象のソースコード全文
6. JSON 形式での応答指示

### Phase 3: 結果マージ
- 静的走査結果と LLM 結果を行番号 + カテゴリで重複排除してマージ
- 表示時にカテゴリ名ラベルを付与（例: `[f:EvalCell/CellPrint/SetSelectedNB]`）
