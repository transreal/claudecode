# Claude Directives

Wolfram Language / Mathematica 開発環境における Claude Code 用ディレクティブ一式。
claudecode.wl・NBAccess.wl・github.wl の3つの基盤パッケージと連携し、
ノートブック操作・パッケージ管理・GitHub 連携・機密データ保護の設計原則とベストプラクティスを定義する。

## 構成

```
Claude Directives/
  CLAUDE.md                  ← メインディレクティブ（セッション方針・操作ルール・参照先の集約）
  README.md                  ← このファイル
  rules/                     ← 絶対に破ってはいけない設計・安全・アクセス制約
    01-wolfram-general.md       Wolfram Language コーディング一般制約
    10-nbaccess.md              NBAccess 分離原則・セル直接操作禁止・ボタン再実行防止
    20-api-key-security.md      API キー管理・SystemCredential 直接使用禁止
    30-encoding-safety.md       UTF-8 エンコーディング・正規表現の安全ルール
    40-pde-constraints.md       PDE モデリング制約
    50-file-path.md             ファイルパス解決ルール
    60-confidential-structure.md 機密データ構造・Confidential ラッピング制約
    70-external-language-output.md R/Python 等の外部言語出力制約
    80-package-operations.md    パッケージ操作制約（ClaudeUpdatePackage 必須等）
    90-api-error-handling.md    API エラー・Fallback 絶対順守要件
  skills/                    ← 特定タスクの具体手順とパターン集
    wolfram-general/            Wolfram Language コーディング手順・出力方針
    notebook-path-policy/       ファイルパス解決パターン
    nbaccess-notebook-access/   NBAccess API リファレンスと推奨パターン
    nbaccess-separation-check/  NBAccess 分離原則の検証・修正手順（静的走査+LLM判定）
    api-key-handling/           API キー取得の正しい実装手順
    wl-encoding-and-regex/      エスケープ・正規表現の検証手順
    pde-modeling/               PDE 実装ステップ
    confidential-data-handling/ 機密データのラッピング手順
    confidential-structure-probe/ 秘密変数の構造調査と ContinueEval 連携手順
    external-language-output/   R/Python 等の外部言語コード出力パターン
    doc-generation/             ドキュメント生成の継続・README 構造ルール
    github-operations/          GitHub パッケージ管理・PR管理・Fallback・ボタン再実行防止
```

## 主要な設計原則

### NBAccess 分離原則 (`rules/10-nbaccess.md`)
ノートブックのセルへの直接アクセスを禁止し、すべて NBAccess の公開 API 経由で操作する。
`NotebookWrite`, `CellPrint`, `EvaluationCell[]`, `SelectionMove`, `CurrentValue[..., TaggingRules]` 等の直接使用は、NBAccess.wl と NotebookExtensions.wl を除き一切認めない。
ボタンからの API 呼び出しには `$iGitHubEvalGuard` + `WithCleanup` による再実行防止ガードが必須。

### Fallback 絶対順守要件 (`rules/90-api-error-handling.md`)
`Fallback -> True` を明示的に指定しない限り、LLM のレート制限エラー時に代替処理を行ってはならない。エラーは `Failure[...]` として上位に伝播させ、処理を確実に停止する。エラーメッセージをデータとして利用する（リポジトリ名やファイル内容に変換する等）ことは禁止。

### パッケージ操作制約 (`rules/80-package-operations.md`)
パッケージの更新は `ClaudeUpdatePackage` 経由で行い、`Import`/`Export` による手動読み書きは禁止。関数名は `_info/docs/api.md` に記載されたもののみ使用し、推測で生成しない。

## 配置先

このフォルダの内容を `~/.claude/` にコピーして使用する。

```
~/.claude/
  CLAUDE.md
  rules/
    01-wolfram-general.md
    10-nbaccess.md
    ...
  skills/
    wolfram-general/SKILL.md
    nbaccess-notebook-access/SKILL.md
    ...
```

## インストール

`install-claude-directives.wl` を Mathematica で読み込み、以下を実行する:

```mathematica
InstallClaudeDirectives[]
```

デフォルトでは `FileNameJoin[{$packageDirectory, "Claude Directives"}]` から `FileNameJoin[{$HomeDirectory, ".claude"}]` へ再帰コピーする。

GitHub 連携で `Claude Directives` フォルダをリポジトリに含める場合:

```mathematica
GitHubCreateRepository["claudecode", ExtraDirectories -> {"Claude Directives"}]
```

## 基盤パッケージとの関係

| パッケージ | 役割 | 主な関連ルール |
|---|---|---|
| `NBAccess.wl` | ノートブックセルアクセスの一元化層 | `rules/10-nbaccess.md` |
| `claudecode.wl` | Claude Code CLI 連携・パッケージ管理・分離検査 | `rules/80-package-operations.md`, `rules/90-api-error-handling.md` |
| `github.wl` | GitHub REST API 連携・リポジトリ管理 | `skills/github-operations/SKILL.md`, `rules/90-api-error-handling.md` |
