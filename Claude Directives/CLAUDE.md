# CLAUDE.md

## ⛔ 最優先ルール: AutoEvaluate 禁止操作 (`rules/00-autoeval-prohibited.md`)

**以下の操作は `AutoEvaluate -> True` で自動実行されるコードに絶対に含めてはならない。このルールは他のすべてのルール・スキルに優先する。**

- **保護対象定数の変更** (`=`, `AppendTo`, `PrependTo`) — `$ClaudeModel`, `$ClaudePrivateModel`, `$ClaudeTestModel`, `$ClaudeFallbackModels`, `$ClaudeAccessibleDirs`, `$ClaudeDocMaxRetries`, `$ClaudeEvalMaxDepth`, `$NBPrivacySpec`, `$NBConfidentialSymbols`, `$NBSendDataSchema`, `$NBSeparationIgnoreList`
- **`ClaudeAttach` の実行** — セッションへのファイルアタッチは手動実行のみ許可
- **`SystemCredential` の使用** — 認証情報へのアクセスは手動実行のみ許可

これらの操作が必要な場合は `AutoEvaluate -> False` で出力し、ユーザーに手動実行を促すこと。詳細は `rules/00-autoeval-prohibited.md` を参照。

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
- `maildb-operations` — maildb パッケージの API 使用パターン（showMails/searchFromMails は MailDBObject 必須）
- `system-open` — SystemOpen によるファイル・フォルダ・ノートブックの開き方

## ファイル読み込みルール

- ファイル名だけが指定された場合（フルパスでない場合）は、
  `FileNameJoin[{Quiet @ Check[NotebookDirectory[], $packageDirectory], ファイル名}]`
  でパスを構築する。`Import["ファイル名"]` のようにカレントディレクトリ依存のコードを生成しない。

## Excel インポート方針（必須）

- Excel ファイルをインポートするときは、明示的に Table 等と指定されない限り **必ず `{"Dataset"}` 形式** で読み込む。
  1行目をキー（列名）として使用する。ただし、1行目からデータが始まっている場合（1行目と2行目以降が同じタイプの項目）であれば、キーを列番号で生成する。
- **シートが1枚の場合**（結果リストの長さが1）: `First @ Import[...]` でリストを外し、単一の Dataset を返す。
- **シートが複数の場合**（結果リストの長さが2以上）: Dataset のリストとしてそのまま返す。

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
- ドキュメント生成 `ClaudeCreateDocumentation` はリミット到達時に自動リトライし、再実行で未生成分のみ続行する。
- `_info/design/` フォルダが存在すれば、README の「設計思想」セクション生成時に参考にする（優先度: docs > コード > design メモ）。

### ClaudeAttach のファイル/URL アタッチとキーワード自動注入

`ClaudeAttach` はファイルだけでなく URL もアタッチできる。URL は WeasyPrint で PDF に変換し `claude_attachments/` にキャッシュされる。

```mathematica
(* ファイルアタッチ *)
ClaudeAttach["report.pdf", Keywords -> {"売上", "revenue"}, Title -> "Q3売上レポート"]

(* URL アタッチ: HTML を PDF 化してキャッシュ *)
ClaudeAttach["https://example.com/docs/api-guide", 
  Keywords -> {"API", "ガイド"}, Title -> "外部APIガイド"]

(* Refetch -> True で再取得・上書き *)
ClaudeAttach["https://example.com/docs/api-guide", Refetch -> True]
```

**キーワード/タイトルによる自動注入**: プロンプト中に登録済みキーワードまたはタイトルが含まれると、該当するアタッチメントが自動的にプロンプトに注入される（セッションに明示的にアタッチされていなくても）。メタデータは `claude_attachments/_meta.json` に永続化される。

**Refetch の動作**:
- `Refetch -> False`（デフォルト）: キャッシュ済みならファイルコピー/URL取得をスキップし、Keywords/Title の変更のみメタデータに記録。
- `Refetch -> True`: ファイルを再コピーまたは URL を再取得して上書きし、メタデータも更新。

### ClaudeEval の再帰呼び出しと複合タスクの分解

- **「使う」と「更新する」の区別（最重要）**: パッケージ名がプロンプトに含まれていても、パッケージの関数を呼び出して**計算・処理・分析・表示**を行う指示には `ClaudeUpdatePackage` を生成してはならない。api.md を確認し、既存の関数で実現できるなら、その関数を呼ぶコードを生成する。
  - ✅ `ClaudeEval["倍数計算で3倍する計算を"]` → 既存の3倍関数を呼ぶコード
  - ✅ `ClaudeEval["maildbでメールを検索して"]` → `searchFromMails[...]` を呼ぶコード
  - ❌ 上記のような利用指示に対して `ClaudeUpdatePackage` を生成する → **禁止**
- **ClaudeEval が ClaudeUpdatePackage を生成してよいのは、パッケージの変更が明示的に要求されている場合のみ。** 「追加して」「修正して」「変更して」「バグを直して」等の変更系動詞がある場合に限る。
- **再帰深さの上限**: `$ClaudeEvalMaxDepth`（デフォルト 5）で制御される。この上限を超える再帰呼び出しは自動的にブロックされる。
- **複合タスクの分解**: 1つのプロンプトに複数の独立した変更指示が含まれる場合、ClaudeEval は複数の `ClaudeUpdatePackage` 呼び出しに分解して生成すべきである。
  - 例: 「markSize を動的にし、配色を改善し、exportSVG を追加して」→ 3回の `ClaudeUpdatePackage` に分解
  - 各呼び出しが独自のバックアップを作成するため、途中で問題が起きてもロールバック可能
  - 変更が相互依存する場合（「X を追加し、Y から X を呼ぶ」）は分解しない
- **分解数の上限**: `$ClaudeEvalMaxDepth` を超えない範囲で分解する。超える場合は関連変更をグループ化する。
- **thinking トリガーの伝播**: ユーザーが「死ぬ気で」「じっくり考えて」等と書いた場合、生成する `ClaudeUpdatePackage` の instruction に適切な think トリガー（`ultrathink`/`think hard`/`think`）を先頭に挿入する。
- **⛔ AutoEvaluate 禁止操作**: `AutoEvaluate -> True` で実行されるコードには保護対象定数の変更、`ClaudeAttach`、`SystemCredential` を**絶対に含めてはならない**。詳細は `rules/00-autoeval-prohibited.md` を参照。

## CUDA パッケージサポート

- プロンプトに「CUDA」「GPU計算」等のキーワードが含まれると、`cuda.wl` 拡張が自動ロードされ CUDA モードになる。
- `cuda.wl` は `$packageDirectory` に配置する。ロードできない場合は警告を表示し、純粋 Mathematica コードで続行する。
- CUDA ソース (.cu) とバイナリは `<パッケージ名>.cuda/` に格納される。
- 既存パッケージに `.cuda/` ディレクトリがあれば、更新時も自動的に CUDA モードが有効になる。
- 詳細は `rules/81-cuda-package-operations.md` を参照。

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

**その他のパッケージ（Maildb 等）にも `_info/docs/api.md` が存在する場合がある。** メール関連の操作では `maildb_info/docs/api.md` を参照し、存在しない場合は `skills/maildb-operations` スキルに従うこと。

api.md とこのファイルや skills の記載が矛盾する場合は **常に api.md を信頼** する。api.md よりソースコードが新しい場合はソースコードを直接確認する。

### 基盤パッケージの依存方向制約（必須）

**claudecode.wl と NBAccess.wl は他のパッケージ（maildb, GitHubREST 等）に一切依存してはならない。** 依存方向は常に一方向:

```
任意のパッケージ ──uses──→ claudecode.wl / NBAccess.wl
```

- 基盤パッケージに `Needs`/`Get`/シンボル参照で他パッケージへの依存を追加する → ❌ 禁止
- 基盤パッケージのシステムプロンプト (`$claudeMathPromptPrefix` 等) に特定パッケージ固有の情報を埋め込む → ❌ 禁止
- 他パッケージが基盤パッケージの API を使用する → ✅ 正しい方向

**ClaudeUpdatePackage / ClaudeCreatePackage でコード生成中に基盤パッケージの API 変更が必要と判断した場合:**
- コード生成を即座に中断し、必要な変更内容と理由を出力してユーザーの判断を仰ぐ。
- 基盤パッケージの変更を含むコードを自動生成してはならない。

詳細は `rules/11-core-package-dependency.md` を参照。

### パッケージキーワード自動注入機構

`$ClaudePackageKeywordMap` は外部パッケージがキーワードを登録するための Association である。ClaudeEval/ClaudeQuery のプロンプトにキーワードが含まれると、対応パッケージの `api.md` が自動注入される。

```mathematica
(* 外部パッケージが自身のロード時に登録する例 *)
If[AssociationQ[ClaudeCode`$ClaudePackageKeywordMap],
  ClaudeCode`$ClaudePackageKeywordMap["maildb"] =
    {"メール", "mail", "〆切", "showMails", ...}
];
```

- 基盤パッケージ側はキーワード→パッケージ名のマッピングのみ保持し、パッケージ固有ロジックを一切持たない。
- 各パッケージは `_info/docs/api.md` に自身の完全な API リファレンスを記載しておくこと。

### メール操作のセキュリティルーティング原則

maildb のメールデータには `privacy` フィールド（セキュリティレベル）がある。**privacy > 0.5 のメールは `$ClaudeModel`（クラウド LLM）に投入してはならない。** `$ClaudePrivateModel`（ローカル LLM）で処理すること。

- `MaxPrivacy -> 0.5` を指定すれば公開メールのみに絞り込める。
- `mailAskLLM` は内部でセキュリティレベルに基づきモデルを自動分配する。
- 詳細は `skills/maildb-operations` スキルを参照。

## Wolfram Language 関数名検証ルール（必須）

**Mathematica に存在しない関数名・定数名・オプション名を推測で生成してはならない。** 

- `FileQ[path]` → ❌（正しくは `FileExistsQ[path]`）
- `DirectoryExists[path]` → ❌（正しくは `DirectoryQ[path]`）
- `StringEmpty[str]` → ❌（正しくは `str === ""`）
- api.md に記載されていないパッケージ関数やオプション → ❌

不確実な場合は `Names["*File*"]` での検索や `?FunctionName` でのドキュメント確認を行い、存在を確認してから使用すること。詳細は `rules/12-function-name-verification.md` を参照。

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

### ScheduledTask・非同期処理の制約（必須）

claudecode は ScheduledTask ベースの非同期基盤を提供する。パッケージ開発では以下の2つの制約を厳守すること:

**A. ScheduledTask 内からの禁止操作**（ClaudeEval 経由で呼ばれる場合）:
- ❌ `ClaudeQuery` を ScheduledTask 内から呼ぶ → デッドロック
- ❌ 同一評価ブロック内で `ClaudeQuery` を2回以上呼ぶ → フリーズ
- ❌ `ExternalEvaluate["Python", ...]` → サブプロセスがブロック
- ✅ `LLMSynthesize[prompt]` / `URLRead[HTTPRequest[...]]` → 同期 HTTP で安全

**B. 独自 ScheduledTask 作成の禁止**:
- ❌ パッケージ内で `CreateScheduledTask` を使い UI ポーリングや FrontEnd 更新ループを構築する
- ✅ `iClaudeQueryAsyncWithProgress[]` で claudecode の共有ポーリング基盤に委譲する
- ✅ FrontEnd 通信を行わない純粋計算タスクは例外（ドキュメントに明記）
- ✅ PresentationListener のようにリアルタイム性が必要な場合も例外（ドキュメントに明記）

詳細は `rules/95-scheduled-task-safety.md` を参照。

### 複数 LLM 呼び出しの非同期処理: LLMGraph DAG（必須）

複数の LLM 呼び出しを依存関係を持たせて実行する場合（OCR→要約→保存 等）、
claudecode の **LLMGraph DAG フレームワーク** を使用すること:

- `LLMGraphDAGCreate[<|"nodes"->..., "taskDescriptor"->..., "onComplete"->...|>]` でジョブを作成・起動
- ノードは `iLLMGraphNode[id, type, category, deps, handler]` で定義
- `type`: `"sync"`（即時実行）/ `"claude-cli"`・`"python"`（StartProcess + 自動ポーリング）
- `taskDescriptor["categoryMap"]` でノードカテゴリを抽象カテゴリ（`"cli"`, `"cli-vision"`, `"process"`, `"sync"`）にマッピング
- 並列度は `$LLMGraphMaxConcurrency` がデフォルト。ジョブ固有オーバーライドは `taskDescriptor["maxConcurrency"]`
- ❌ 独自 ScheduledTask で LLM プロセスをポーリングする実装は禁止

詳細は `rules/95-scheduled-task-safety.md` セクション C を参照。

## バックアップ・履歴管理

- `ClaudeBackupDataset["pkg"]` — パッケージのバックアップ履歴を Grid 表示。#0行でローカル最新版に復元可能。
- `ClaudeBackupDataset[]` — 全パッケージのバックアップ履歴を一括表示。
- `ClaudeDirectiveBackupDataset[]` — Claude Directives の更新履歴を Grid 表示。#0行で復元可能。
- `GitHubCommitDataset["pkg"]` — GitHub コミット履歴を Grid 表示。Pull で過去コミットに巻き戻し可能。#0行でローカル最新版に復元。
- いずれも起動時にローカル最新版のスナップショットを SHA-256 ハッシュ付きで保存する。
- Pull で巻き戻した後にファイルを編集していた場合、ローカル最新版への復元時に警告を表示する。