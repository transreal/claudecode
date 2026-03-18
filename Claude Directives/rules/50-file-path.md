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
