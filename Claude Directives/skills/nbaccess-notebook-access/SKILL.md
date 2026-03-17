---
name: nbaccess-notebook-access
description: Use when reading or writing notebook cells, handling confidential or dependent cells, filtering notebook history, or integrating AI features with notebooks. Especially relevant for NBAccess.wl, claudecode.wl, PresentationListener.wl, and .nb files.
---

# NBAccess API リファレンスと推奨パターン

制約は `rules/10-nbaccess.md` に従う。このスキルは API 一覧と実装パターンを定める。

## 公開関数一覧

### プライバシー
- `NBCellPrivacyLevel[nb, cell]`
- `NBIsAccessible[nb, cell, PrivacySpec -> ps]`
- `NBFilterCells[nb, cells, PrivacySpec -> ps]`

### 読み出し
- `NBCellExprToText[cellExpr]`
- `NBCellToText[nb, cell]`
- `NBGetCells[nb, PrivacySpec -> ps]`
- `NBGetContext[nb, afterIdx, PrivacySpec -> ps]`

### 書き込み
- `NBWriteText[nb, text, style]`
- `NBWriteCode[nb, code]`
- `NBWriteSmartCode[nb, code]`

### マーク
- `NBGetConfidentialTag[cell]`
- `NBSetConfidentialTag[cell, val]`
- `NBMarkCellConfidential[cell]`
- `NBMarkCellDependent[cell]`
- `NBUnmarkCell[cell]`

### 依存グラフ
- `NBBuildVarDependencies[nb]`
- `NBTransitiveDependents[deps, confVars]`
- `NBScanDependentCells[nb, confVarNames]`
- `NBPlotDependencyGraph[nb, PrivacySpec -> ps]`

### 履歴
- `NBFilterHistoryEntry[entry, confVars]`

## 推奨実装パターン

### セル読み出し
- ノートブック全体 → `NBGetCells`
- LLM 用コンテキスト → `NBGetContext`
- Cell 式からテキスト化 → `NBCellExprToText`

### セル書き込み
- テキスト → `NBWriteText`
- Input セル → `NBWriteCode`
- 構文カラーリング付き → `NBWriteSmartCode`

### 機密・依存セル
- 機密セル → `NBMarkCellConfidential`
- 依存判定 → `NBBuildVarDependencies` + `NBTransitiveDependents`
- 依存マーク → `NBMarkCellDependent`
- 履歴秘匿 → `NBFilterHistoryEntry`
