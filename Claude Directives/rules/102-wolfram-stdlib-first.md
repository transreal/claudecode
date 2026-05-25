---
paths:
  - "**/*.wl"
  - "**/*.m"
  - "**/*.nb"
---

# Wolfram 開発の原則 — 標準関数優先

Mathematica / Wolfram Language の機能を扱う時、Claude が陥りがちな罠:

**間違い**: notebook ファイルや式の構造を扱う必要があると、すぐに **パターンマッチで生 expression を解析しようとする**。`Cell[_, _String, ___]` のような pattern を書く、`HoldComplete[Notebook[c_List, ___]]` で展開する、box 構造を `RowBox[...]` パターンで掘る、等。

**問題点**:

1. **Context 解決問題** — パッケージ内で `Cell` / `Notebook` / `CellGroupData` / `FontVariations` / `InitializationCell` 等の System シンボルをパターンマッチで使うと、`SourceVault\`Private\`Cell` のような別シンボルとして作られることがあり、`Import` が返す `System\`Cell[...]` の式にマッチしない (罠 #20)
2. **構造変更に脆い** — Wolfram のバージョン更新で notebook の box 構造が変わると壊れる
3. **再発明** — Wolfram には既に専用の標準関数があることが多い
4. **危険性** — 評価せず読むつもりが、意図せず副作用を起こす経路を作ってしまう

## 原則

**ノートブックや Wolfram 式の構造にアクセスする時は、必ず先に Wolfram 標準関数を探す。**

パターンマッチや手書きパースは **最終手段**。

### 必ず先に確認する標準関数 (notebook 関連)

| 用途 | 推奨関数 |
|---|---|
| Notebook 全体を読む | `Import[path, "Notebook"]` (documented に `Notebook[...]` 式を返す) |
| InitializationCell の中身を取得 | `Import[path, "Initialization"]` (List of evaluated expressions) |
| 特定の cell style を取り出す (式付き) | `NotebookImport[path, style -> "Cell"]` |
| 特定の cell style のテキストだけ取る | `NotebookImport[path, style]` |
| Plain text / Markdown 化 | `Import[path, "PlainText"]`, `Import[path, "Markdown"]` |
| Cell metadata / TaggingRules | `NotebookImport[path, _ -> "TaggingRules"]` |
| Notebook を開かずに編集 | `NotebookOpen[path, Visible -> False]` + `NotebookPut/Get` |

### 必ず先に確認する標準関数 (expression 解析)

| 用途 | 推奨関数 |
|---|---|
| Box → expr (評価せず) | `MakeExpression[box, StandardForm]` (`HoldComplete[expr]` を返す) |
| Expr → box | `MakeBoxes[expr, StandardForm]` |
| `.wl` / `.m` のロード | `Get[path]` / `Needs[...]`、ただし `.nb` には使わない |
| Notebook の structure inspection | `NotebookGet[nb]`, `Cells[nb]` |

## やってはいけないこと

- **`.nb` ファイルを `Import[path, "Text"]` + `ToExpression[..., InputForm, HoldComplete]` でパース** — コメント注釈と Notebook 式の混在で不安定 (Trap #18)
- **`Get[path]` で `.nb` を読む** — FE 経由で NotebookObject 化される等の特殊挙動の可能性
- **`ToString[boxData, StandardForm]` + `ToExpression[str, StandardForm, HoldComplete]` のラウンドトリップ** — box の意味を保てない (Trap #19)。`MakeExpression[boxData, StandardForm]` が正規
- **パッケージ private context 内で `Cell[...]` / `Notebook[...]` のパターンを生で書く** — `SourceVault\`Private\`Cell` 化される問題 (Trap #20)。やむを得ない場合は `SymbolName[Head[c]] === "Cell"` のような **文字列名比較** に書き換える

## 探す順番 (チェックリスト)

新しい Wolfram 機能の実装を始める前:

1. [ ] Wolfram Documentation Center で機能名を検索する (`NotebookImport`, `Import` の format オプション等)
2. [ ] 似た用途の既存組み込み関数があるか確認
3. [ ] `tutorial/...` でその領域の概要を読む
4. [ ] それでも見つからない場合に限り、生 expression をパースする実装に進む
5. [ ] パース実装をする場合も、**context 非依存** (`SymbolName[Head[]]`) または `MakeExpression` 経由で書く

## 関連 trap (`skills/wolfram-syntax-pitfalls`)

- Trap #18: `.nb` を `Get[path]` で読まない
- Trap #19: `ToString`+`ToExpression` ラウンドトリップは box 用途には不適切、`MakeExpression` を使う
- Trap #20: パッケージ private context での Cell/Notebook シンボル参照と System シンボルの混同

## 関連 skill

- `skills/notebook-management-extraction` — Stage 9 P0 の実装での教訓 (Header は `Import["Initialization"]`、Todo は `NotebookImport[path, style -> "Cell"]`)
