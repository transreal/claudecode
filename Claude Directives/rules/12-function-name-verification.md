---
paths:
  - "**/*.{wl,wls,m,nb}"
---

# 12 — Mathematica 関数名・定数名の検証制約

## 対象

LLM によるコード生成時の Wolfram Language 関数名・定数名・オプション名の使用。

## 必須ルール

### 1. 未定義関数の使用禁止

**Mathematica に存在しない関数名を推測で生成してはならない。**

```mathematica
(* ❌ 禁止: 存在しない関数 *)
FileQ[path]              (* 正しくは FileExistsQ *)
DirectoryExists[path]    (* 正しくは DirectoryQ *)
StringEmpty[str]         (* 正しくは StringQ[str] && str === "" *)
ListLength[list]         (* 正しくは Length *)
SetDirectory[path]       (* 正しくは SetDirectory は存在するが、意味が異なる *)
```

### 2. 正しい関数名の確認方法

コード生成時に関数名が不確実な場合は、以下の手順で検証する:

1. **ドキュメンテーションセンター**: Wolfram Language の公式ガイドページで確認
2. **`Names` での検索**: `Names["*File*"]` で類似関数を探す
3. **`Information` での確認**: `?FunctionName` でシンタックス確認
4. **推測禁止**: 上記で見つからない場合は、存在しない可能性が高いため使用しない

### 3. よくある誤用パターン

| 誤った推測 | 正しい関数/方法 |
|----------|----------------|
| `FileQ[path]` | `FileExistsQ[path]` |
| `DirectoryExists[path]` | `DirectoryQ[path]` |
| `StringEmpty[str]` | `str === ""` または `StringLength[str] === 0` |
| `ListQ[expr]` | `ListQ[expr]` は存在するが、`AtomQ` の逆ではない |
| `NumberQ[expr] && expr > 0` | `NumericQ[expr] && Positive[expr]` |
| `SetWorkingDirectory[path]` | `SetDirectory[path]` |
| `ReadJSON[file]` | `Import[file, "RawJSON"]` |
| `WriteJSON[file, data]` | `Export[file, data, "JSON"]` |
| `StringStartsWith[str, pattern]` | `StringStartsQ[str, pattern]` |
| `StringEndsWith[str, pattern]` | `StringEndsQ[str, pattern]` |
| `ArrayDimensions[arr]` | `Dimensions[arr]` |
| `RandomChoice[list, n]` | `RandomSample[list, n]` または `RandomChoice[list, n]`（復元あり） |

### 4. オプション名の検証

関数のオプション名も同様に推測で生成してはならない。

```mathematica
(* ❌ 禁止: 推測のオプション *)
Import[file, Format -> "JSON"]        (* 正しくは "JSON" を第2引数として指定 *)
Export[file, data, Encoding -> "UTF8"] (* 正しくは CharacterEncoding -> "UTF8" *)
Plot[Sin[x], {x, 0, 2Pi}, LineColor -> Red]  (* 正しくは PlotStyle -> Red *)
```

**正しいオプションの確認方法**:
- `Options[FunctionName]` でオプション一覧を取得
- `?FunctionName` でドキュメントを参照
- api.md に記載されたオプションのみを使用（パッケージ関数の場合）

### 5. 定数名の検証

Mathematica の組み込み定数についても推測禁止。

```mathematica
(* ❌ 禁止: 推測の定数 *)
Math.Pi          (* 正しくは Pi *)
Math.E           (* 正しくは E *)
Infinity         (* 正しくは Infinity は存在するが、∞ の表現は Infinity *)
NaN              (* 正しくは Indeterminate *)
```

### 6. System` コンテキストの前提

標準的な Mathematica 関数は `System` コンテキストに属するため、コンテキストの明示は通常不要。

```mathematica
(* ✅ 正しい *)
FileExistsQ[path]

(* ❌ 不要な明示化 *)
System`FileExistsQ[path]
```

ただし、パッケージ関数については該当パッケージのコンテキストを明示する必要がある場合がある。

### 7. エラー時の対応

存在しない関数を使用したコードが生成された場合:

1. **即座に修正**: 正しい関数名に置き換える
2. **代替手段の提示**: 類似機能を持つ正しい関数または手法を提案
3. **検証方法の明示**: なぜその関数が正しいかを `Names` や `Information` で確認

### 8. 特に注意が必要な領域

以下の領域では関数名の推測が起こりやすいため特に注意:

- **ファイル・ディレクトリ操作**: `FileExistsQ`, `DirectoryQ`, `CreateDirectory`, `CopyFile` 等
- **文字列操作**: `StringStartsQ`, `StringEndsQ`, `StringContainsQ` 等の述語関数
- **データ構造**: `AssociationQ`, `DatasetQ` 等の判定関数
- **数値・数学**: `NumericQ`, `RealQ`, `IntegerQ` 等の数値判定
- **リスト操作**: `MemberQ`, `SubsetQ`, `FreeQ` 等

### 9. パッケージ関数への適用

この制約は Mathematica 組み込み関数だけでなく、パッケージ関数にも適用される:

- api.md に記載されていない関数やオプションを推測で生成してはならない
- 基盤パッケージ (claudecode.wl, NBAccess.wl, github.wl) の関数は必ず対応する api.md で確認する
- サードパーティパッケージの場合も、利用可能なドキュメントで関数の存在を確認する

## 背景

ユーザーが「FileQなど、Mathematica未定義の関数を使おうとしてしまうことがある」と報告したため、このルールを制定。LLM は自然言語的に合理的な関数名を推測する傾向があるが、Wolfram Language の実際の関数名は必ずしも直感的ではない場合がある。