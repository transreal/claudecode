---
name: system-open
description: Use when the user asks to "open" a file, folder, notebook, or design document. Generates SystemOpen[] calls that launch files/folders in the OS default application. Does NOT read/write file contents.
---

# SystemOpen によるファイル・フォルダ表示

## いつ使うか

ユーザーが以下のような表現を使ったとき:
- 「init.m を開いて」「デザインファイルを開いて」「フォルダを見せて」
- 「〜のディレクトリを開いて」「〜.nb を開いて」
- 「history フォルダを開いて」

## 重要な区別

| ユーザーの意図 | 使う関数 | 例 |
|---|---|---|
| ファイルをOSで開いて表示 | `SystemOpen[path]` | 「init.m を開いて」 |
| ファイルの中身を読んで処理 | `Import[path]` / ClaudeEval | 「init.m に〜を追加して」 |
| ファイルの中身を教えて | `Import[path, "Text"]` | 「init.m の内容は？」 |

**「開いて」だけの場合は SystemOpen を使う。** 内容の変更・読み取りが目的の場合は SystemOpen を使わない。

## パス解決パターン

```mathematica
(* パッケージファイル *)
SystemOpen[FileNameJoin[{$packageDirectory, "init.m"}]]

(* パッケージの _info/design フォルダ *)
SystemOpen[FileNameJoin[{$packageDirectory, "claudecode_info", "design"}]]

(* NotebookDirectory 内のファイル *)
SystemOpen[FileNameJoin[{Quiet @ Check[NotebookDirectory[], $packageDirectory], "file.xlsx"}]]

(* _info/history フォルダ *)
SystemOpen[FileNameJoin[{$packageDirectory, "PackageName_info", "history"}]]
```

## よく使われるパス

- `$packageDirectory` — パッケージルート
- `FileNameJoin[{$packageDirectory, "init.m"}]` — 初期化ファイル
- `FileNameJoin[{$packageDirectory, name <> "_info", "design"}]` — デザインノート
- `FileNameJoin[{$packageDirectory, name <> "_info", "docs"}]` — ドキュメント
- `FileNameJoin[{$packageDirectory, name <> "_info", "history"}]` — バックアップ履歴
- `FileNameJoin[{$packageDirectory, "Claude Directives"}]` — ディレクティブ

## 安全性

- SystemOpen はファイルの読み書きを行わない（OSに委譲するだけ）
- ClaudeQuery のリッチレスポンスで自動評価される（$iQuerySafePatterns に登録済み）
- ファイルが存在しない場合は `If[FileExistsQ[...], SystemOpen[...], "ファイルが見つかりません"]` で安全に処理する
