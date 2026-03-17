---
paths:
  - "**/*.{wl,wls,m,nb}"
---

# ファイルパス制約

## 必須
- bare filename は `NotebookDirectory[InputNotebook[]]` を基準に解決する。
- Notebook が未保存なら `$ClaudeWorkingDirectory` にフォールバックする。

## 禁止
- `Import["ファイル名"]` のようにカレントディレクトリ依存のコードを生成しない。
- `NotebookDirectory` と `$packageDirectory` 以外を暗黙の基準ディレクトリにしない。

## 判断
- ユーザーが絶対パスを明示した場合はそれを優先する。
