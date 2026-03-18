# CLAUDE.md

## セッション開始時の基本方針

- まず対象ファイルとその周辺依存を読んでから編集する。
- 公開シンボル・ノートブック UX・既存ワークフローを壊さない最小差分を優先する。

## ディレクティブ構造

- `rules/` — 絶対に破ってはいけない設計・安全・アクセス制約。
- `skills/` — 特定の解析・修正・レビューの具体手順とパターン集。
- タスクに最も近いスキルを参照し、常に rules の制約を遵守する。

## インストール済みスキル

- `wolfram-general` — Wolfram Language コーディング手順・出力方針
- `notebook-path-policy` — ファイルパス解決パターン
- `nbaccess-notebook-access` — NBAccess API リファレンスと推奨パターン
- `nbaccess-separation-check` — NBAccess 分離原則の検証・修正手順
- `api-key-handling` — API キー取得の正しい実装手順
- `wl-encoding-and-regex` — エスケープ・正規表現の検証手順
- `pde-modeling` — PDE 実装ステップ
- `confidential-data-handling` — 機密データのラッピング手順
- `confidential-structure-probe` — 秘密変数の構造調査と ContinueEval 連携手順
- `external-language-output` — R/Python 等の外部言語コードの出力パターン
- `doc-generation` — ドキュメント生成の継続・README 構造ルール
- `github-operations` — GitHub パッケージ管理・PR 管理・インストール手順
- `package-merge-pattern` — LLM レスポンスによるパッケージ部分更新のマージ・安全検証パターン

## ファイル読み込みルール

- ファイル名だけが指定された場合（フルパスでない場合）は、
  `FileNameJoin[{Quiet @ Check[NotebookDirectory[], $packageDirectory], ファイル名}]`
  でパスを構築する。`Import["ファイル名"]` のようにカレントディレクトリ依存のコードを生成しない。

## Excel インポート方針（必須）

- Excel ファイルをインポートするときは、明示的に Table 等と指定されない限り **必ず `{"Dataset"}` 形式** で読み込む。
  1行目をキー（列名）として使用する。ただし、1行目からデータが始まっている場合（1行目と2行目以降が同じタイプの項目）であれば、キーを列番号で生成する。
- **シートが1枚の場合**（結果リストの長さが1）: `First @ Import[...]` でリストを外し、単一の Dataset を返す。
- **シートが複数の場合**（結果リストの長さが2以上）: Dataset のリストとしてそのまま返す。
- 秘密変数として Excel を読み込むときは、`Confidential[...]` でラップした直後に、キー情報を `NonConfidential` で出力する:
  ```mathematica
  成績 = Confidential[First @ Import[..., {"Dataset"}]]
  NonConfidential[Normal[Keys[成績[[1]]]]]
  ```
  これにより、秘匿されたデータセットの構造が ClaudeEval / ContinueEval で利用可能になる。

## パッケージドキュメント参照ルール

- `$packageDirectory` 内のパッケージ（`.wl` または Paclet）について質問・指示を処理するとき、まずそのパッケージのドキュメントが存在するか確認する。
  - 単一 `.wl` の場合: `$packageDirectory/<パッケージ名>_info/docs/`
  - Paclet の場合: `$packageDirectory/<パッケージ名>/docs/`
- **api.md ファースト原則**: パッケージの関数を使うコードを生成するとき、またはパッケージの関数について質問されたとき:
  1. **まず api.md を参照する。** api.md にはすべての公開関数・定数・オプション・引数・戻り値・使用例が記載されており、api.md だけで大多数の問題を解決できる。
  2. **api.md で不明な点がある場合のみ**、ソースコード（`.wl`）を直接読む。
  3. api.md に記載されていない関数やオプションを推測で生成してはならない。
- ドキュメントが存在し、かつソースコード（`.wl`）の最終更新日時よりドキュメントの方が新しい場合は、全ドキュメントを参考情報として活用できる。
- ソースコードがドキュメントより新しい場合でも、**api.md のシグネチャ・オプション情報は有効**（API は頻繁に変わらないため）。
- ドキュメントは `ClaudeCreateDocumentation["パッケージ名"]` で生成、`ClaudeUpdateDocumentation["パッケージ名", "更新指示"]` で更新できる。
  - 第二引数で大域的な指示を与えられる: `ClaudeCreateDocumentation["pkg", "日本語で簡潔に"]`
  - `References -> {"URL", "書名"}` で参考文献、`Demos -> {"URL"}` でデモ動画を README に追加。
  - `Disclaimer -> {"追加免責事項"}` で免責事項に追記。指示文中の URL も自動検出。
  - `License -> ""` で MIT ライセンス自動挿入（`$GitHubLicenseHolder` が設定済みの場合）。文字列指定でカスタムライセンス。

## パッケージ操作ルール（必須）

- プロンプトにパッケージ名やファイル名が含まれている場合、`$packageDirectory` 内に該当するパッケージ（`.wl` ファイルまたは Paclet フォルダ）が存在する可能性を**第一に**考えること。
- パッケージの更新・修正タスクには、必ず `ClaudeUpdatePackage["パッケージ名", "更新指示"]` を使用する。
  - `Import`/`ReadString` でソースコードを読み込んで手動で書き換えるコードを生成してはならない。
  - `Export`/`Put` でパッケージファイルを直接上書きするコードを生成してはならない。
  - `ClaudeUpdatePackage` はバックアップ・差分更新・検証・再ロードを自動で行う。
- パッケージの新規作成には `ClaudeCreatePackage["パッケージ名", "仕様"]` を使用する。
- パッケージに関する質問（変更でなく情報提供）には、ドキュメント参照ルールに従い、docs があればそれを先に参照する。
- パッケージの Paclet 変換には `ClaudeConvertToPaclet["パッケージ名"]` を使用する。
- Claude Code CLI のスラッシュコマンドは `ClaudeCommand["/command"]` で実行できる。
- NBAccess 分離原則の検証には `ClaudeCheckSeparation["パッケージ名"]` を使用する。
  - 違反の修正には `ClaudeFixSeparation["パッケージ名"]` を使用する。
  - `$NBSeparationIgnoreList` に登録されたパッケージ（NBAccess, NotebookExtensions）は検査対象外。
- ドキュメント生成 `ClaudeCreateDocumentation` はリミット到達時に自動リトライし、再実行で未生成分のみ続行する。README.md は最後に生成される。
- `_info/design/` フォルダが存在すれば、README の「設計思想」セクション生成時に参考にする（優先度: docs > コード > design メモ）。

## GitHub パッケージ管理ルール

- **GitHub 関連の指示を受けたとき、Web 検索に頼らず、まず自分の GitHub リポジトリ（GitHubREST パッケージ）で操作すること。**
  - 「GitHub から xxx をダウンロード/インストール/更新して」→ まず `$packageDirectory` に xxx が存在するか確認し、`GitHubUpdatePackage["xxx"]` または `GitHubInstallPackage["xxx"]` を使う。
  - Web 検索を行うのは、自分のリポジトリに該当パッケージが存在せず、かつ外部の公開リポジトリを明示的に指定された場合のみ。
- 基盤パッケージ (claudecode.wl, NBAccess.wl, github.wl) は手動で `$packageDirectory` に配置する。
- それ以外のパッケージのインストールは `GitHubInstallPackage["パッケージ名"]` を使用する。
  - 「xxx をインストールして」→ `GitHubInstallPackage["xxx"]`
  - 「xxx を更新して」「xxx の最新版をダウンロードして」→ `GitHubUpdatePackage["xxx"]`
- GitHub へのアップロードには `GitHubRefreshAndCommit` を使用する。
- PR 管理には `GitHubPullRequestDataset` (Dataset 表示) または個別関数を使用する。
- 日本語パッケージ名は `GitHubRepoDBSet` でリポジトリ名を登録する。
- ローカル作業フォルダは `$packageDirectory/GithubRepositories/` に統一。

### 基盤パッケージ API 参照ルール（必須）

**コードを生成する際に基盤パッケージ (github.wl, claudecode.wl, NBAccess.wl) の関数を使う場合、必ずそのパッケージの `_info/docs/api.md` に記載された関数名・オプション名のみを使用すること。** 存在しない関数名を推測で生成してはならない。

- `github_info/docs/api.md` — GitHubREST の全関数と正確なオプション
- `claudecode_info/docs/api.md` — ClaudeCode の全関数と正確なオプション
- `NBAccess_info/docs/api.md` — NBAccess の全関数と正確なオプション

api.md とこのファイルや skills の記載が矛盾する場合は **常に api.md を信頼** する。api.md よりソースコードが新しい場合はソースコードを直接確認する。

### PR ワークフローの正しいパターン

PR を作成する場合、以下の **いずれか** を使う。存在しない `GitHubCreateBranch`, `GitHubPushFile` 等を生成してはならない。

```mathematica
(* 推奨: 一発で refresh → ブランチ作成 → commit → PR *)
GitHubSubmitPullRequest["pkg", "PRタイトル", "コミットメッセージ",
  Body -> "PR本文"]

(* 手動: まず別ブランチにコミット、次に PR 作成 *)
GitHubRefreshAndCommit["pkg", "commit msg",
  Branch -> "feature/xxx", CreateBranch -> True]
GitHubCreatePullRequest["pkg", "PRタイトル",
  Branch -> "feature/xxx", Body -> "PR本文"]
```

### API エラー・利用制限ハンドリング（必須）

- API レスポンスの有効性判定には必ず `iIsAPIErrorResponse[response]` を使用する。
- エラー時はファイルに書き込まない（ドキュメント、ソースコード、要約等すべて）。
- 連続 API 呼び出しでは最初のエラーで以降をすべてスキップする（fail-fast）。
- エラー時はフォールバック表示で代替し、エラーメッセージ自体をデータとして保存しない。
- 詳細は `rules/90-api-error-handling.md` を参照。

## ClaudeEval のスケジューリング

- `StartTime -> Now + Quantity[3, "Hours"]` で遅延実行。
- `RepeatInterval -> Quantity[2, "Hours"]` で周期的に繰り返し実行。
  - `RepeatInterval -> {Quantity[1, "Hours"], 5}` で最大5回。
  - `TaskObject` が返るので `TaskRemove[]` で停止可能。
  - `RepeatInterval` は `ClaudeEval` のみの機能。`ClaudeUpdatePackage` 等には `StartTime` のみ。

## バックアップ・履歴管理

- `ClaudeBackupDataset["pkg"]` — パッケージのバックアップ履歴を Grid 表示。#0行でローカル最新版に復元可能。
- `ClaudeBackupDataset[]` — 全パッケージのバックアップ履歴を一括表示。
- `ClaudeDirectiveBackupDataset[]` — Claude Directives の更新履歴を Grid 表示。#0行で復元可能。
- `GitHubCommitDataset["pkg"]` — GitHub コミット履歴を Grid 表示。Pull で過去コミットに巻き戻し可能。#0行でローカル最新版に復元。
- いずれも起動時にローカル最新版のスナップショットを SHA-256 ハッシュ付きで保存する。
- Pull で巻き戻した後にファイルを編集していた場合、ローカル最新版への復元時に警告を表示する。
