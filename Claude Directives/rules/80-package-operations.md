# 80 — パッケージ操作制約

## 対象

`$packageDirectory` に存在する `.wl` パッケージファイルおよび Paclet フォルダへの操作。

## 必須ルール

1. **パッケージ名の認識**: プロンプト中にパッケージ名（`Maildb`, `github`, `claudecode` 等）が含まれている場合、`$packageDirectory` 内の該当パッケージの存在を前提とする。File Access Context の `Packages in $packageDirectory` リストで確認できる。

2. **GitHub 操作は自分のリポジトリを優先**: 「GitHub から xxx をダウンロード/インストール/更新して」等の指示を受けた場合、**Web 検索をせず**、まず `$packageDirectory` に該当パッケージが存在するか確認し、GitHubREST パッケージの関数（`GitHubUpdatePackage`, `GitHubInstallPackage`）を使用する。claudecode.wl は github.wl と連携して動作する前提である。

3. **更新は ClaudeUpdatePackage を使う**: パッケージの修正・機能追加・バグ修正には必ず `ClaudeUpdatePackage["パッケージ名", "更新指示"]` を出力する。
   - ❌ `Import` でソースを読んで `StringReplace` で書き換えるコード
   - ❌ `Export`/`Put` でパッケージファイルを直接上書き
   - ✅ `ClaudeUpdatePackage["Maildb", "showMailsのデフォルト表示数を30に変更"]`

3. **新規作成は CreatePackage を使う**: 新しいパッケージの作成には `ClaudeCreatePackage["パッケージ名", "仕様"]` を使用する。

4. **api.md ファースト原則**: パッケージの関数を使うコードを生成するとき:
   - **まず `_info/docs/api.md` を参照する。** api.md にはすべての公開関数・定数・オプション・引数・戻り値・使用例が記載されている。
   - api.md だけで大多数の問題を解決できる。ソースコード全体を読む前に api.md で確認すること。
   - **api.md で不明な点がある場合のみ**ソースコードを参照する。
   - api.md に記載されていない関数やオプションを推測で生成してはならない。

5. **ドキュメント参照を優先する**: パッケージに関する質問への回答では:
   - まず `パッケージ名_info/docs/`（単一 .wl）または `パッケージ名/docs/`（Paclet）のドキュメントを参照する
   - ドキュメントがソースコードより新しい場合は全ドキュメントが有効
   - ソースコードがドキュメントより新しい場合でも **api.md のシグネチャ・オプション情報は有効**
   - ドキュメントで不足する場合にのみソースコードを読む

6. **ドキュメント生成・更新**:
   - `ClaudeCreateDocumentation["パッケージ名"]` — 包括的ドキュメント一式を生成
   - `ClaudeUpdateDocumentation["パッケージ名", "更新指示"]` — 既存ドキュメントを部分更新

6. **Paclet 変換**: `ClaudeConvertToPaclet["パッケージ名"]` を使用する。

## 禁止事項

- パッケージファイルの手動読み書き（`Import`/`Export`/`ReadString`/`Put`/`OpenWrite` 等）
- パッケージの存在を確認するための探索コード（`FileNames["*.wl", ...]` 等）の出力 — File Access Context に一覧が載っている
- パッケージソースコードの全体を出力に含めること
