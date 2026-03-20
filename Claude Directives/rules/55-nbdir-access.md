---
paths:
  - "**/*.{wl,wls,m,nb}"
---

# NotebookDirectory アクセス制御

## 基本原則

`$ClaudeNBDirAccess` は NotebookDirectory（ノートブックが保存されているディレクトリ）への Claude Code のアクセスレベルを制御する。

| 値 | ファイル一覧 | ファイル読み取り | ファイル書き込み |
|---|---|---|---|
| `"list"` (デフォルト) | ✓ | ✗ | ✗ |
| `"read"` | ✓ | ✓ | ✗ |
| `"readwrite"` | ✓ | ✓ | ✓ |

## 動作

### "list" モード（デフォルト）

- `iFileAccessContext[]` は NotebookDirectory 内のファイル一覧を表示する
- しかし Claude Code の Read tool にはファイル読み取り権限を付与しない
- プロンプト内のファイル名は `File[...]` として注入されない
- ユーザーがファイル読み取りを必要とするプロンプトを送信すると、権限付与ボタンが表示される

### "read" モード

- ファイル一覧 + 読み取り権限が付与される
- `iResolveNotebookFiles` がプロンプト内のファイル名を `File[...]` として注入する
- `iCollectAccessibleDirs` が NotebookDirectory を含む

### "readwrite" モード

- 全権限が付与される

## 権限付与フロー

1. `ClaudeQuery["成績.xlsx の一行目は？"]` を実行
2. `$ClaudeNBDirAccess === "list"` かつプロンプト内に NotebookDirectory 内のファイル名がある
3. 権限付与ボタンが表示される: [Read 許可] [Read/Write 許可] [拒否]
4. ユーザーが [Read 許可] を押すと `$ClaudeNBDirAccess = "read"` に変更され、クエリが自動再実行される

## 制約

- `$packageDirectory` と `$ClaudeWorkingDirectory` は常に Read/Write 可能（この制御の対象外）
- `$ClaudeAccessibleDirs` に明示的に追加されたディレクトリも対象外
- この制御は NotebookDirectory のみに適用される
- `$ClaudeNBDirAccess` はセッション変数であり、カーネル再起動で "list" にリセットされる
