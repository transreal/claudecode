---
name: wolfram-general
description: Use for Wolfram Language / Mathematica coding, editing, notebook output style, package conventions, and overall implementation constraints in this environment. Especially relevant for .wl, .m, and .nb work.
---

# Wolfram Language 全般ルール

このスキルは Wolfram Language / Mathematica の作業全般で使う。

## コーディング方針

- 主言語は Wolfram Language とする。
- 新しい組み込み関数で自然に書ける場合は、古い回避策よりも最新の標準関数を優先する。
- Python 連携が必要なときは `ExternalFunction` / `ExternalEvaluate` を優先候補にする。
- Java 連携が必要なときは J/Link の利用を許容する。
- Notebook スタイルは `Subsection` / `Item` / `Subitem` / `Text` を優先し、`Section` は使わない。
- 文字コードは UTF-8 を前提に扱う。

## 数式・データ表現の方針

- 可能な限り、定義された数式をそのまま保持して関数を作る。
- 数値代入が本当に必要になるまでは、できるだけ記号式のまま処理する。
- ベクトル・行列を扱う場合は、可能な限りベクトル・行列表現を保ったまま計算する。

## 数式タイプセット（ClaudeEval / ClaudeQuery 生成コード）

NBAccess が生成コードを `MakeBoxes[StandardForm]` でタイプセットするため、
`Integrate` → ∫, `Sum` → Σ, `Subscript` → 下付き, `Sqrt` → √ 等の美しい表示が自動的に得られる。
ただし `Module`, `Block`, `Show`, `Plot` 等の手続き的コードは FEParser を使用（変数スコーピング保護のため）。

### コメント禁止（コードブロック内）
`(* ... *)` コメントは `ToExpression` で除去される。
**コードブロック内にコメントを書かず、説明はブロック外のテキストに記述する。**

### テキスト内の LaTeX 数式（推奨）
説明テキスト中の数式は `$...$` LaTeX 表記を使う。自動的に Mathematica タイプセットに変換される。
例: `$\nabla^2 \varphi = 0$`, `$\pm q_m$`, `$\mathbf{B} = -\mu_0 \nabla \varphi$`

### 推奨
- 数学関数は標準の関数呼び出し形式: `Integrate[f, x]`, `Sum[...]`, `D[f, x]`
- 下付き/上付き: `Subscript[q, m]`, `Superscript[x, n]`
- 行列: `MatrixForm[...]`
- ギリシャ文字: `\[CurlyPhi]`, `\[Mu]` 等

## 出力方針

- 説明は必要十分にとどめ、冗長にしない。
- 数式は省略せず明示する。
- 可能なら短い動作確認コードや最小例を添える。

## ノートブック出力のスタイル規約（必須）

システムからのエラー・警告・進捗メッセージは、ユーザーの作業セルとは区別して **通知スタイル（Print セル・小さめフォント）** で表示する。

### 使い分け

| 出力の種類 | 使う関数 | セルスタイル |
|-----------|---------|------------|
| ユーザーへの回答テキスト | `NBAccess`NBWriteCell[nb, Cell[text, "Text"]]` | 通常 Text |
| 生成コード | `NBAccess`NBWriteSmartCode[nb, code]` | Input |
| エラー・警告・制限通知 | `NBAccess`NBWritePrintNotice[nb, text, color]` | Print (小さめ) |
| 進捗表示 | `NBAccess`NBWriteDynamicCell[nb, ...]` | Print (小さめ) |

### エラーレスポンスの早期検出パターン

コールバック関数の冒頭で `iIsAPIErrorResponse` を使ってエラーを検出し、通知スタイルで表示して早期リターンする:

```mathematica
(* ✅ 正しいパターン: エラーは通知スタイルで表示 *)
Function[response,
  Module[{...},
    NBAccess`NBJobMoveToAnchor[jid];
    If[iIsAPIErrorResponse[response] || StringStartsQ[response, "Error"],
      NBAccess`NBWritePrintNotice[nb, response, RGBColor[0.8, 0, 0]];
      NBAccess`NBEndJob[jid];
      Return[]];
    (* 以下: 正常レスポンスの処理 *)
    ...
  ]]

(* ❌ 禁止: エラーメッセージを通常 Text セルで表示 *)
Function[response,
  Module[{...},
    textOnly = cleanMarkdown[response];
    NBAccess`NBWriteCell[nb, Cell[textOnly, "Text"]];  (* ← エラーもここに来る *)
    ...
  ]]
```

### 色の使い分け

- エラー（赤）: `RGBColor[0.8, 0, 0]`
- 警告・進捗（オレンジ）: `RGBColor[0.8, 0.4, 0]`
- 成功（緑）: `RGBColor[0, 0.5, 0.2]`

## 全体禁止事項

- ffmpeg のパスをハードコードしない。
- ShiftJIS を前提にした実装を新たに入れない。
- `session` で始まる変数名を出力コードで使わない。
- サンプルコードで `Clear["Global`*"]` や `Remove["Global`*"]` のような全消去をしない。
- 物理 PDE を、自前の手書き差分式・有限差分・統計サンプリングで安易に置き換えない。

## パッケージロード時のメッセージ

ロード完了メッセージは `CellPrint` ではなく `Print` を使う。タイトルは `Style[..., Bold]` で強調し、一覧は改行つき文字列で出す。

```mathematica
Print[Style["Mypackage パッケージがロードされました。", Bold]];
Print["
  func1[arg]   → 説明1
  func2[arg]   → 説明2
"];
```

## ファイルパス操作方針（必須）

Mathematica は Windows / macOS / Linux で動作する。ファイルパスの操作には **文字列操作関数を使わず、必ず専用関数を使う**。

### パス結合・分解

```mathematica
(* ✅ 正しい *)
FileNameJoin[{dir, "subdir", "file.wl"}]
FileNameSplit["C:\\Users\\foo\\bar.wl"]  (* → {"C:", "Users", "foo", "bar.wl"} *)
FileNameTake[path]            (* ファイル名のみ *)
FileNameDrop[path, n]         (* 先頭 n 階層を除去 *)
DirectoryName[path]           (* 親ディレクトリ *)
FileExtension[path]           (* 拡張子 *)

(* ❌ 禁止 *)
dir <> $PathnameSeparator <> file
StringReplace[path, dir <> $PathnameSeparator -> ""]
StringDrop[path, StringLength[dir] + 1]
```

### 相対パスの計算

```mathematica
(* ✅ iRelativePath[fullPath, baseDir] — claudecode.wl に定義済み *)
Module[{baseParts = FileNameSplit[baseDir],
        fullParts = FileNameSplit[fullPath]},
  FileNameJoin[Drop[fullParts, Length[baseParts]]]
]

(* ❌ 禁止 *)
StringReplace[fullPath, baseDir <> $PathnameSeparator -> ""]
```

### パスの正規化（末尾セパレータ除去）

```mathematica
(* ✅ 正しい *)
dir = FileNameJoin[FileNameSplit[dir]]

(* ❌ 禁止 *)
StringTrimRight[dir, "\\"]
StringReplace[dir, RegularExpression["[\\\\/]+$"] -> ""]
```

### JSON 等から取得したスラッシュ区切りパスの変換

```mathematica
(* ✅ 正しい — FileNameSplit は "/" も "\" も認識する *)
FileNameJoin[Flatten[{srcDir, FileNameSplit[path]}]]

(* ❌ 禁止 *)
FileNameJoin[{srcDir, StringReplace[path, "/" -> $PathnameSeparator]}]
```

### bare filename の解決

- ファイル名だけが指定された場合は `FileNameJoin[{NotebookDirectory[], ファイル名}]` でパスを構築する。
- `NotebookDirectory[]` が取得できない場合のフォールバックとして `Quiet @ Check[NotebookDirectory[], $packageDirectory]` を使う。
- `Import["ファイル名"]` のようにカレントディレクトリ依存のコードを生成しない。

## データ出力方針

- テーブル形式でデータを最終的に出力する場合は、可能な限り `Dataset` 形式で出力する。

## Excel インポート方針（必須）

- Excel ファイルをインポートするときは、明示的に Table 等と指定されない限り **必ず `{"Dataset"}` 形式** で読み込む。
  1行目をキー（列名）として使用する。ただし、1行目からデータが始まっている場合（1行目と2行目以降が同じタイプの項目）であれば、キーを列番号で生成する。
- **シートが1枚の場合**（結果リストの長さが1）: `First @ Import[...]` でリストを外し、単一の Dataset を返す。
  - 例: `First @ Import[file, {"Dataset"}]`
- **シートが複数の場合**（結果リストの長さが2以上）: Dataset のリストとしてそのまま返す。
- 秘密変数として Excel を読み込むときは、`Confidential[...]` でラップした直後に、キー情報を `NonConfidential` で出力する。
