# 80 — パッケージ操作制約

## 対象

`$packageDirectory` に存在する `.wl` パッケージファイルおよび Paclet フォルダへの操作。

## 必須ルール

0. **「使う」と「更新する」の区別（最重要）**: パッケージ名がプロンプトに含まれていても、**パッケージの関数を呼び出して計算・処理を行う指示**には `ClaudeUpdatePackage` を生成してはならない。
   - 「倍数計算で3倍する計算を」→ ✅ パッケージの関数を呼ぶコード（例: `三倍計算[10]`）
   - 「倍数計算に3倍する関数を追加して」→ ✅ `ClaudeUpdatePackage["倍数計算", "3倍する関数を追加"]`
   - **判定基準**: 指示の動詞が「計算する」「表示する」「使う」「実行する」「取得する」「分析する」等の**利用系**であれば、既存関数を使うコードを生成する。「追加する」「修正する」「変更する」「修正して」「バグを直して」「機能を追加して」等の**変更系**であれば `ClaudeUpdatePackage` を使う。
   - **api.md を確認してから判断する**: パッケージの api.md に必要な関数が既に存在する場合、その関数を使うコードを生成する。api.md に該当する関数がない場合のみ、更新が必要か検討する。

1. **パッケージ名の認識**: プロンプト中にパッケージ名（`maildb`, `github`, `claudecode` 等）が含まれている場合、`$packageDirectory` 内の該当パッケージの存在を前提とする。File Access Context の `Packages in $packageDirectory` リストで確認できる。

2. **GitHub 操作は自分のリポジトリを優先**: 「GitHub から xxx をダウンロード/インストール/更新して」等の指示を受けた場合、**Web 検索をせず**、まず `$packageDirectory` に該当パッケージが存在するか確認し、GitHubREST パッケージの関数（`GitHubUpdatePackage`, `GitHubInstallPackage`）を使用する。claudecode.wl は github.wl と連携して動作する前提である。

3. **更新は ClaudeUpdatePackage を使う**: パッケージの修正・機能追加・バグ修正には必ず `ClaudeUpdatePackage["パッケージ名", "更新指示"]` を出力する。
   - ❌ `Import` でソースを読んで `StringReplace` で書き換えるコード
   - ❌ `Export`/`Put` でパッケージファイルを直接上書き
   - ✅ `ClaudeUpdatePackage["maildb", "showMailsのデフォルト表示数を30に変更"]`

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

7. **ClaudeEval による再帰的パッケージ操作（条件付き推奨）**: ClaudeEval がさらに ClaudeEval/ClaudeUpdatePackage/ClaudeCreatePackage を生成するパターンは、**パッケージの変更が明示的に要求されている場合のみ**利用すべきである。
   - ✅ 「maildbに検索機能を追加して」→ `ClaudeUpdatePackage["maildb", "検索機能を追加"]`
   - ❌ 「maildbでメールを検索して」→ パッケージの既存関数を使うコードを生成する。`ClaudeUpdatePackage` を生成してはならない。
   - 複合タスク（複数の独立した変更）は、個別の `ClaudeUpdatePackage` 呼び出しに分解して順次実行する
   - 各呼び出しは独自のバックアップを作成するため、安全にロールバック可能
   - 分解により各ステップの `iGuessTargetFunctions` が適切な関数のみを選択し、LLM の品質が向上する

8. **再帰深さの上限**: `$ClaudeEvalMaxDepth`（デフォルト 5）で制御。上限に達すると自動的にブロックされ警告が表示される。分解数がこの上限を超える場合は、関連する変更をグループ化して上限内に収める。

9. **thinking トリガーの自動挿入**: ユーザーの日本語の励まし表現（「死ぬ気で考えろ」「じっくり考えて」等）は、生成するコード内の instruction 文字列に適切な英語 think トリガー（`ultrathink`/`think hard`/`think`）として先頭挿入する。

## 禁止事項

- パッケージファイルの手動読み書き（`Import`/`Export`/`ReadString`/`Put`/`OpenWrite` 等）
- パッケージの存在を確認するための探索コード（`FileNames["*.wl", ...]` 等）の出力 — File Access Context に一覧が載っている
- パッケージソースコードの全体を出力に含めること
- LLM レスポンスを無条件に全コードとして採用すること（必ずマージを実行する。詳細は `rules/85-safe-merge.md` および `skills/package-merge-pattern` を参照）
- **基盤パッケージ（claudecode.wl, NBAccess.wl）に他パッケージへの依存を追加すること**（詳細は `rules/11-core-package-dependency.md`）

## 基盤パッケージ API 変更が必要な場合の動作

ClaudeUpdatePackage / ClaudeCreatePackage の実行中に、基盤パッケージ（claudecode.wl, NBAccess.wl）の API 変更が必要と判断した場合:

1. **コード生成を即座に中断する。**
2. 必要な変更の内容と理由を出力し、ユーザーの判断を仰ぐ。
3. 基盤パッケージの変更を含むコードを自動生成してはならない。