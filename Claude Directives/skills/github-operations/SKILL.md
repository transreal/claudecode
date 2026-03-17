---
name: github-operations
description: Use when the user mentions GitHub operations, package installation/update from GitHub, pull requests, repository creation/management, or uploading packages to GitHub. Covers GitHubREST` package functions.
---

# GitHub Operations Skill

このスキルは GitHubREST パッケージを使った GitHub 操作に使う。

## 最重要: GitHub 操作の優先順位

**「GitHub」「リポジトリ」「最新版」「ダウンロード」「Pull」等のキーワードを含む指示を受けた場合:**

1. **まず自分の GitHub リポジトリに該当パッケージがあるかを確認する。** `$packageDirectory` 内のパッケージ一覧 (File Access Context) を参照し、該当パッケージが存在すれば `GitHubUpdatePackage` や `GitHubInstallPackage` を使う。
2. **Web 検索をしてはならない。** GitHubREST パッケージが GitHub API を直接呼び出すので、Web ブラウザや検索エンジンは不要。
3. 外部の公開リポジトリ（自分のものでない）を明示的に URL やオーナー名で指定された場合のみ、`Owner` オプション付きで `GitHubInstallPackage` を使う。

## 最重要: 関数名の信頼ソースと禁止事項

**コード生成時には `$packageDirectory/github_info/docs/api.md` に記載された関数名・オプション名のみを使用すること。**

存在しない関数（例: `GitHubCreateBranch`, `GitHubPushFile`, `GitHubPushCommit` 等）を推測で生成することは**絶対に禁止**。

関数名・シグネチャの優先順位:
1. `$packageDirectory/github_info/docs/api.md` (存在し、github.wl より新しい場合)
2. `github.wl` ソースコード自体 (api.md が古い場合)
3. このスキルファイル (概要参照のみ)

## 正確な関数シグネチャ一覧

### リポジトリ管理
```
GitHubCreateRepository["pkg", Public->False, Description->"..."]
GitHubEnsureLocalRepo["pkg", LocalRepoPath->Automatic]
GitHubPackageURL["pkg", Owner->Automatic, Repository->Automatic]
GitHubPackageURLs[]
```

### コミット・アップロード
```
GitHubCommit["pkg", "message",
  Branch->Automatic, BaseBranch->Automatic, CreateBranch->Automatic,
  Owner->Automatic, Repository->Automatic, LocalRepoPath->Automatic,
  IncludePackageFile->True, DeleteMissing->False, Force->False]

GitHubRefreshAndCommit["pkg", "message",
  Branch->Automatic, BaseBranch->Automatic, CreateBranch->Automatic,
  Owner->Automatic, Repository->Automatic, LocalRepoPath->Automatic,
  DeleteMissing->False, Force->False]
```

### PR 作成（最重要）
```
(* 推奨: 一発で refresh → ブランチ作成 → commit → PR 作成 *)
GitHubSubmitPullRequest["pkg", "PRタイトル", "コミットメッセージ",
  Branch->Automatic, BaseBranch->Automatic,
  Body->"", Draft->False, MaintainerCanModify->True,
  Owner->Automatic, Repository->Automatic, LocalRepoPath->Automatic]

(* 個別: 既存ブランチから PR のみ作成 *)
GitHubCreatePullRequest["pkg", "PRタイトル",
  Branch->Automatic, Head->Automatic, BaseBranch->Automatic,
  Body->"", Draft->False, MaintainerCanModify->True,
  Owner->Automatic, Repository->Automatic]
```

### PR 管理
```
GitHubPullRequestDataset["pkg"]        (* ボタン付き Dataset *)
GitHubListPullRequests["pkg"]          (* 生データ *)
GitHubMergePullRequest["pkg", 42, "理由"]
GitHubClosePullRequest["pkg", 42, "理由"]
GitHubReviewPullRequest["pkg", 42]     (* 差分表示 + テスト用コード *)
```

### インストール・更新
```
GitHubInstallPackage["pkg", Owner->"user"]
GitHubUpdatePackage["pkg"]
```

### コミット履歴・レビュー
```
GitHubCommitDataset["pkg"]             (* ボタン付き Grid + ローカル最新版 *)
GitHubListCommits["pkg"]              (* 生データ *)
GitHubReviewCommit["pkg", "sha"]       (* コミット詳細・差分表示 *)
GitHubRevertCommit["pkg", "sha", "理由"]  (* コミットをリバート *)
```

### リポジトリ名 DB
```
GitHubRepoDBSet["日本語名", "english-name"]
GitHubRepoDBLookup["日本語名"]
GitHubRepoDB[]
```

### ローカル作業フォルダ・マニフェスト
```
GitHubRepoPath["pkg"]                 (* ローカル作業フォルダのパス *)
GitHubEnsureLocalRepo["pkg"]          (* ローカル作業フォルダ作成 *)
GitHubReadManifest["pkg"]             (* upload_manifest.json を読み取り *)
```

### ファイル読み込み
```
GitHubReadFile["pkg", "path/to/file",
  Branch->Automatic, BaseBranch->Automatic, ReturnType->"Text"]
GitHubPull["pkg"]
```

### ExtraDirectories オプション

`GitHubCreateRepository` と `GitHubRefreshAndCommit` は `ExtraDirectories` オプションで
upload_manifest.json に追加ディレクトリを永続的に登録できる。
```mathematica
GitHubCreateRepository["claudecode", ExtraDirectories -> {"Claude Directives"}]
(* 以後は ExtraDirectories 指定不要（manifest に記録済み） *)
GitHubRefreshAndCommit["claudecode", "Update"]
```

## PR 作成ワークフロー例

### パターン1: 一発で完結（推奨）
```mathematica
(* パッケージを更新してから PR *)
ClaudeUpdatePackage["fib", "FibTable と FibFrom を追加"];
GitHubSubmitPullRequest["fib",
  "feat: FibTable と FibFrom の追加",
  "Add FibTable and FibFrom functions",
  Body -> "## 変更内容\n- FibTable[n]: 表形式出力\n- FibFrom[n,k]: n以上をk個"]
```

### パターン2: 手動ステップ
```mathematica
(* 別ブランチにコミット *)
GitHubRefreshAndCommit["fib", "Add FibTable and FibFrom",
  Branch -> "feature/fib-enhancements", CreateBranch -> True]
(* PR 作成 *)
GitHubCreatePullRequest["fib", "feat: FibTable と FibFrom の追加",
  Branch -> "feature/fib-enhancements",
  Body -> "..."]
```

## 自然言語からの操作マッピング

| ユーザーの指示 | 実行する関数 |
|---|---|
| 「PRを出して」「プルリクエスト」 | `GitHubSubmitPullRequest` |
| 「xxx をインストールして」 | `GitHubInstallPackage["xxx"]` |
| 「xxx を最新にして」「xxx を更新して」 | `GitHubUpdatePackage["xxx"]` |
| 「GitHub から xxx をダウンロードして」 | `GitHubUpdatePackage["xxx"]` (既存) / `GitHubInstallPackage["xxx"]` (新規) |
| 「xxx の最新版を取得して」 | `GitHubUpdatePackage["xxx"]` |
| 「xxx の PR を見せて」 | `GitHubPullRequestDataset["xxx"]` |
| 「xxx の PR #N をマージして」 | `GitHubMergePullRequest["xxx", N, "理由"]` |
| 「xxx を GitHub にアップして」 | `GitHubRefreshAndCommit["xxx", "Update"]` |
| 「xxx のリポジトリを作って」 | `GitHubCreateRepository["xxx"]` |
| 「xxx のコミット履歴を見せて」 | `GitHubCommitDataset["xxx"]` |
| 「xxx のコミットを戻して」 | `GitHubRevertCommit["xxx", "sha", "理由"]` |
| 「xxx のバックアップ履歴を見せて」 | `ClaudeBackupDataset["xxx"]` |
| 「ディレクティブの履歴を見せて」 | `ClaudeDirectiveBackupDataset[]` |

**注意:** 「GitHub から xxx を…」という指示は Web 検索ではなく、上記の GitHubREST 関数で処理すること。

## ローカルフォルダ構成

```
$packageDirectory/
  GithubRepositories/          ← ローカル作業フォルダ
    repo_database.json         ← パッケージ名 → リポジトリ名の対応 DB
    packageName/               ← 各パッケージのステージング
    _local_snapshot/           ← Pull 前のローカル最新版スナップショット
  packageName.wl               ← パッケージ本体
  packageName_info/            ← ドキュメント・設計メモ等
    docs/
    design/
    history/                   ← バックアップ履歴（GitHubには除外・削除禁止）
    references/                ← 参考ファイル（GitHubには除外・削除禁止）
    upload_manifest.json
  Claude Directives/           ← ExtraDirectories で GitHub に含める場合
```

## Fallback ルール（絶対順守）

**`Fallback -> True` を明示的に指定しない限り、GitHubREST 内の LLM 呼び出し（リポジトリ名翻訳等）で Fallback は一切行わない。**

- 日本語パッケージ名の英語リポジトリ名翻訳 (`iTranslateToEnglishRepoName`) は LLM を使用する。
- Claude Code がレート制限中の場合、`Fallback -> True` がなければ `Failure["LLMQueryFailed", ...]` を返して処理を停止する。
- エラーメッセージをリポジトリ名に変換してはならない（例: "you-ve-hit-your-limit-resets-5pm-asia-tokyo" のような名前が生成される事故を防ぐ）。
- `Failure` は `iAutoRepoName` → `iResolveRepository` → `GitHubCreateRepository` の全レイヤーで `FailureQ` チェックにより伝播する。
- 詳細は `rules/90-api-error-handling.md` を参照。

## ボタン再実行防止（必須）

`GitHubCommitDataset` / `GitHubPullRequestDataset` の Output セル内のボタン（Review, Pull, Revert, Merge, Close）は、CTRL-Z (Undo) でセル状態が巻き戻された際にボタンの評価式が再トリガーされる問題がある。

### 対策: `$iGitHubEvalGuard` パターン

全ボタンに再実行防止ガードを入れる。ガードは `WithCleanup` で正常終了・異常終了の両方で解除する。

```mathematica
(* ボタン側 *)
Button["Review",
  Module[{gk = "btn-review:" <> pkg <> ":" <> sha},
    If[TrueQ[$iGitHubEvalGuard[gk]], Return[]];
    $iGitHubEvalGuard[gk] = True;
    WithCleanup[
      GitHubReviewCommit[pkg, sha],
      $iGitHubEvalGuard = KeyDrop[$iGitHubEvalGuard, gk]]],
  Method -> "Queued"]

(* 関数本体側も二重防御 *)
GitHubReviewCommit[packageName_String, commitSHA_String, ...] :=
  Module[{..., guardKey},
    guardKey = "review:" <> packageName <> ":" <> commitSHA;
    If[TrueQ[$iGitHubEvalGuard[guardKey]], Return[$Failed]];
    $iGitHubEvalGuard[guardKey] = True;
    WithCleanup[Null,
      (* 本体処理 *) ...,
      $iGitHubEvalGuard = KeyDrop[$iGitHubEvalGuard, guardKey]]
  ];
```

新たにボタンを追加する場合は必ずこのパターンに従うこと。
