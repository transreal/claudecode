---
paths:
  - "**/*.{wl,wls,m,nb}"
---

# ファイルパス制約

## 基本原則

Mathematica は Windows / macOS / Linux で動作するクロスプラットフォーム言語である。ファイルパスの操作には **必ず Mathematica の専用関数** を使い、文字列操作関数でパスを扱ってはならない。

参照: https://reference.wolfram.com/language/guide/OperationsOnFileNames.html

## 必須: パス操作に使う関数

| 用途 | 使う関数 |
|------|---------|
| パスの結合 | `FileNameJoin[{dir, subdir, file}]` |
| パスの分解 | `FileNameSplit[path]` |
| ファイル名取得 | `FileNameTake[path]` / `FileNameTake[path, -n]` |
| 先頭ディレクトリ除去 | `FileNameDrop[path, n]` |
| 親ディレクトリ | `DirectoryName[path]` |
| 拡張子取得 | `FileExtension[path]` |
| ベースネーム | `FileBaseName[path]` |
| 階層の深さ | `FileNameDepth[path]` |

## 禁止: パス操作に使ってはならないパターン

```mathematica
(* ❌ 禁止: 文字列操作でパスを結合・分解 *)
dir <> $PathnameSeparator <> file
dir <> "\\" <> file
dir <> "/" <> file
StringReplace[path, dir <> $PathnameSeparator -> ""]
StringDrop[path, StringLength[dir] + 1]
StringSplit[path, $PathnameSeparator]
StringReplace[path, "/" -> $PathnameSeparator]
StringReplace[path, $PathnameSeparator -> "/"]
StringTrimRight[dir, $PathnameSeparator]
RegularExpression["[\\\\/]+$"]  (* パス末尾除去 *)

(* ✅ 正しい代替 *)
FileNameJoin[{dir, file}]
iRelativePath[path, dir]  (* = FileNameJoin[Drop[FileNameSplit[path], Length[FileNameSplit[dir]]]] *)
FileNameSplit[path]
FileNameJoin[FileNameSplit[relPath]]  (* セパレータの正規化 *)
FileNameJoin[FileNameSplit[dir]]      (* 末尾セパレータの除去 *)
```

## 相対パスの計算

ベースディレクトリからの相対パスを得るには、`FileNameSplit` で分解して前方一致部分を除去する:

```mathematica
(* iRelativePath[fullPath, baseDir] — claudecode.wl に定義済み *)
Module[{baseParts = FileNameSplit[baseDir],
        fullParts = FileNameSplit[fullPath]},
  FileNameJoin[Drop[fullParts, Length[baseParts]]]
]
```

`FileNameSplit` は末尾セパレータの有無やセパレータの種類（`\` / `/`）に影響されないため、`StringReplace` による相対パス計算で起きていた不具合（末尾 `\` 付きパスでマッチしない等）を根本的に防ぐ。

## パス結合時の注意

スラッシュ区切りの相対パス（JSON 等から取得）をネイティブパスに変換するには:

```mathematica
(* ❌ 禁止 *)
FileNameJoin[{srcDir, StringReplace[path, "/" -> $PathnameSeparator]}]

(* ✅ 正しい *)
FileNameJoin[Flatten[{srcDir, FileNameSplit[path]}]]
```

`FileNameSplit` は `"/"` と `"\"` の両方をセパレータとして認識するため、明示的な変換は不要。

## bare filename の解決

- bare filename は `NotebookDirectory[InputNotebook[]]` を基準に解決する。
- Notebook が未保存なら `$ClaudeWorkingDirectory` にフォールバックする。

## 禁止

- `Import["ファイル名"]` のようにカレントディレクトリ依存のコードを生成しない。
- `NotebookDirectory` と `$packageDirectory` 以外を暗黙の基準ディレクトリにしない。

## 判断
- ユーザーが絶対パスを明示した場合はそれを優先する。

## 永続データへのパス保存

`Put` / `Export` 等で永続化するデータ（インデックス、メタデータ、設定ファイル等）には **絶対パスを埋め込まない**。`$packageDirectory` が変更された環境（Dropbox 同期先の別マシン、OneDrive 移行等）でデータが壊れるため。

### 保存時: 相対パスに変換

`$packageDirectory` 配下のパスは相対パスに変換して保存する。外部パスや URL はそのまま保持。

```mathematica
(* PDFIndex.wl の iMakeRelativePath を参照 *)
"sourcePath" -> iMakeRelativePath[absPath]
(* 結果例: "claude_attachments/file.pdf" *)
```

### 読み出し時: 現在の $packageDirectory で展開

```mathematica
(* PDFIndex.wl の iResolveSourcePath を参照 *)
resolvedPath = iResolveSourcePath[storedPath]
(* 相対パス → FileNameJoin[{$packageDirectory, storedPath}] *)
(* 絶対パス・URL → そのまま返す (後方互換) *)
```

### 禁止パターン

```mathematica
(* ❌ 禁止: フルパスをそのまま永続化 *)
docMeta = <|"sourcePath" -> absPath, ...|>;
Put[docMeta, indexFile];

(* ✅ 正しい: 相対パスで保存 *)
docMeta = <|"sourcePath" -> iMakeRelativePath[absPath], ...|>;
Put[docMeta, indexFile];
```

### 後方互換

既存データに絶対パスが残っている場合、読み出し関数はドライブレター (`C:` 等) や `/` 始まりのパスをそのまま返す。再インデックス等で相対パスに移行できる。

## 一時ファイルのディレクトリ制約

一時ファイル（バッチファイル、プロンプトファイル、出力ファイル、レンダリング画像等）は **`$TemporaryDirectory` を使用してはならない**。すべて `$ClaudeWorkingDirectory/tmp` に作成する。

`$ClaudeWorkingDirectory` と `$ClaudeAccessibleDirs` に登録されたディレクトリ以外は使用禁止。

### 実装パターン

```mathematica
(* claudecode.wl: iClaudeTempDir[] を使用 *)
outFile = FileNameJoin[{iClaudeTempDir[], "claude_out_" <> ts <> ".txt"}]

(* PDFIndex.wl: iPdfTempDir[] を使用 (同じロジック) *)
imgDir = FileNameJoin[{iPdfTempDir[], "pdfocr_" <> id}]
```

### 禁止パターン

```mathematica
(* ❌ 禁止: $TemporaryDirectory を直接使用 *)
outFile = FileNameJoin[{$TemporaryDirectory, "output.txt"}]

(* ✅ 正しい: $ClaudeWorkingDirectory 配下の tmp *)
outFile = FileNameJoin[{iClaudeTempDir[], "output.txt"}]
```

## 使用可能ディレクトリの制約

コード内でファイルの読み書き・一時ファイル作成・ディレクトリ操作を行う際、以下の **許可されたディレクトリのみ** を使用すること。

### 許可されたディレクトリ

| 変数 | 用途 |
|------|------|
| `$ClaudeWorkingDirectory` | Claude CLI 作業用。一時ファイルは `$ClaudeWorkingDirectory/tmp` |
| `$packageDirectory` | パッケージ本体・設定・インデックスデータ |
| `$ClaudeAccessibleDirs` | ユーザーが明示的に登録した追加ディレクトリ |

### 禁止

上記以外のディレクトリは **使用禁止**。特に以下は使ってはならない:

- `$TemporaryDirectory` (`%TEMP%`)
- `$HomeDirectory` 直下
- `$UserDocumentsDirectory`
- ハードコードされた絶対パス
- `NotebookDirectory[]`（ただし bare filename 解決時は除く — 「bare filename の解決」セクション参照）

### 新しいディレクトリが必要な場合

どうしても上記以外のディレクトリを使用する必要がある場合は、**コードを書く前に** 以下を提案すること:

1. `NBAccess.wl` に参照ディレクトリを格納する変数と、それを取得する関数を新設する
2. ユーザーの承認を得てから NBAccess に実装する
3. 実装後、新しい変数/関数を使ってコードを書く

```mathematica
(* ❌ 禁止: 許可外ディレクトリを直接使用 *)
outputDir = "D:\\SharedData\\results"
tmpFile = FileNameJoin[{$TemporaryDirectory, "work.txt"}]

(* ❌ 禁止: 提案なしに新しいディレクトリパスを導入 *)
$myNewDataDir = FileNameJoin[{$HomeDirectory, "MyData"}]

(* ✅ 正しい: まず NBAccess への変数追加を提案 *)
(*
  提案: NBAccess.wl に以下を追加
    $SharedDataDirectory — 共有データの保存先
    NBGetSharedDataDir[] — 現在の共有データディレクトリを返す
  承認後に実装します。
*)
```
