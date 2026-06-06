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

## ❗ 実行コンテキストの制約 (2026-06-03 実機確認)

**SystemOpen はメインカーネルのトップレベル評価機会でのみ効く。** `SessionSubmit` / `ScheduledTask` / 共有 polling tick の評価コンテキストで呼ぶと、**エラーも出さず何も起きない (silent no-op)**。

| コンテキスト | SystemOpen の効き |
|---|---|
| トップレベルセル評価 (直接) | ✅ 開く |
| `Button` 本体 (`Method -> "Queued"` = メイン評価) | ✅ 開く |
| `SessionSubmit[SystemOpen[...]]` | ❌ 開かない |
| `SessionSubmit[ScheduledTask[SystemOpen[...], ...]]` | ❌ 開かない |
| 共有 polling tick (`ClaudeRegisterPollingTick`) 経由 | ❌ 開かない |

承認ボタンや非同期処理の中から「開いて」を実行する設計では、**SystemOpen だけはメイン評価機会で呼ぶ**こと。重い処理を `SessionSubmit` で非同期化していても、desktop 操作はボタン本体 (メイン評価) に分離する。詳細は rule `95-scheduled-task-safety` 節 G。

```mathematica
(* ✅ 承認ボタン: パス検証は委譲、SystemOpen はボタン本体で直接 *)
Button["承認",
  If[!decided, decided = True;
    Module[{info},
      info = NBAccess`NBResolveDesktopActionPath[heldExpr, accessSpec];
      If[TrueQ[info["Validated"]], SystemOpen[info["Path"]]]]],
  Method -> "Queued"]

(* ❌ SystemOpen を非同期コンテキストで呼ぶと silent no-op *)
Button["承認",
  SessionSubmit[ScheduledTask[SystemOpen[path], {0.3, 1}]],
  Method -> "Queued"]
```

## 承認付き wrapper (NBOpenFolderWithApproval) の context 注意

LLM が生成する無修飾 `NBOpenFolderWithApproval[...]` は、`$ContextPath` に `NBAccess\`` が無いと `Global\`NBOpenFolderWithApproval` (未定義) に解決され、`ReleaseHold` しても**未評価式のまま**返り SystemOpen に到達しない。

対策として NBAccess は `NBResolveDesktopActionPath[held, accessSpec]` を提供する。これは head の **context に依存せず `SymbolName` で wrapper を検出**し、パス式を安全評価して検証だけ行う (SystemOpen は呼ばない)。呼び出し側 (承認ボタン本体 = メイン評価) が検証済みパスに対して raw `SystemOpen` を直接呼ぶ。これで `Global\`` shadow にも `$ContextPath` にも左右されない。
