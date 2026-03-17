---
paths:
  - "**/{NBAccess,claudecode,NotebookExtensions,PresentationListener}*.{wl,wls,m,nb}"
  - "**/*API*.{wl,wls,m,nb}"
  - "**/*Claude*.{wl,wls,m,nb}"
---

# API キーセキュリティ制約

## 必須
- API キーは必ず `NBAccess`NBGetAPIKey` を経由して取得する。

## 禁止
- `SystemCredential[...]` を直接呼び出してキーを読まない。
- API キーをソースコードへ埋め込まない。
- API キーをログ・メッセージ・例示出力に出さない。
- 鍵そのものを返す補助関数やデバッグ表示を新設しない。

## 判断
- 「テストのため一時的に直書き」は禁止。
- 「SystemCredential を直接呼ぶ方が簡単」は理由にならない。
