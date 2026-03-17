---
name: notebook-path-policy
description: Use when Mathematica code must save files by bare filename or relative path, or when deciding whether output should go to NotebookDirectory[InputNotebook[]] or $packageDirectory.
---

# ファイルパス解決パターン

制約は `rules/50-file-path.md` に従う。このスキルは実装パターンを定める。

## 推奨実装パターン

```mathematica
outputDir =
  Quiet @ Check[NotebookDirectory[InputNotebook[]], $Failed];

outputDir =
  If[StringQ[outputDir] && DirectoryQ[outputDir],
    outputDir,
    $packageDirectory
  ];

outputPath = FileNameJoin[{outputDir, "result.txt"}];
```

## 判断基準

- ユーザーが bare filename だけ指定 → このパターンを適用する。
- ユーザーが絶対パスを明示 → その絶対パスを優先する。
- ユーザーが別の基準ディレクトリを明示していない限り、`NotebookDirectory` と `$packageDirectory` 以外を暗黙の基準にしない。
