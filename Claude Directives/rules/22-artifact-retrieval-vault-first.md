---
paths:
  - "**/*.{wl,wls,m,nb}"
---

# 生成済み成果物の照会は SourceVault ファースト

ClaudeEval 等で「〜を生成したはずだが出してほしい」「以前の採点/質問/要約を見たい」という**照会**に応えるコードを生成するときの探索順序の鉄則。

## 必須

- **正本は SourceVault**。採点結果・生成質問・要約など、このシステムが作った成果物は SourceVault の annotation/snapshot に格納されている。照会はまず生成元パッケージの照会 API で引く:
  - Cerezo の採点/質問: `CerezoGradeReport[url]` / `CerezoQuestionReport[url]`(collectiontop URL 直渡しで最新 annotation を自動解決)、一覧は `CerezoAnnotationRuns[url]`
  - 汎用: `sourcevault_search` / `SourceVaultSources` 系
- 照会 API が見つからないときは、まず対象パッケージの api.md を確認する(api.md ファースト原則)。

## 禁止

- **`$ClaudeAccessibleDirs` の変更やファイルシステム直読みを第一手にしない。** xlsx/CSV 等のエクスポートファイルは**派生物**であり、移動・削除・古い版の可能性がある。正本(annotation)から再生成する方が常に正しい。
- アクセススコープ拡大(`$ClaudeAccessibleDirs` への `AppendTo` 等)は、SourceVault/パッケージ API の経路を試し尽くしても取得できない場合の**最後の手段**とし、なぜ必要かを出力に明記する。

## 判断

- 「以前 xlsx に書き出したはず」→ それでもまず annotation から `Cerezo*Report[url]` で再生成する。ファイルパスの推測は不要になる。
- ユーザーが明示的にファイルパスを指定した場合のみ、そのファイルを直接読んでよい。
