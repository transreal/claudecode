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
    00-autoeval-prohibited.md   自動実行禁止操作（AutoEvaluate 禁止リスト）— 最優先ルール
    01-wolfram-general.md       Wolfram Language 基本制約
    02-math-typeset.md          数式タイプセットルール
    10-nbaccess.md              NBAccess 分離原則・セル直接操作禁止・ボタン再実行防止
    11-core-package-dependency.md 基盤パッケージの依存方向制約
    12-function-name-verification.md Mathematica 関数名・定数名の検証制約
    20-api-key-security.md      API キー管理・SystemCredential 直接使用禁止
    30-encoding-safety.md       UTF-8 エンコーディング・正規表現の安全ルール
    40-pde-constraints.md       PDE モデリング制約
    50-file-path.md             ファイルパス解決ルール
    55-nbdir-access.md          NotebookDirectory アクセス制御
    60-confidential-structure.md 機密データ構造・Confidential ラッピング制約
    70-external-language-output.md R/Python 等の外部言語出力制約
    80-package-operations.md    パッケージ操作制約（ClaudeUpdatePackage 必須等）
    81-cuda-package-operations.md CUDA パッケージ操作制約
    85-safe-merge.md            パッケージ更新マージ安全性制約
    90-api-error-handling.md    API エラー・利用制限ハンドリング
    95-scheduled-task-safety.md ScheduledTask・非同期処理の安全制約（デッドロック防止＋独自タスク作成禁止）
    96-web-search-recommendation.md Web 検索推奨ルール
    99-adapter-tool-flow.md     adapter 経由 tool-based ClaudeEval の実装ルール（R1〜R7）
    100-async-tool-execution.md AsyncToolExec(Phase 32k Step 3 Phase A〜D2)の必須ルール

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
    package-merge-pattern/      LLM レスポンスによるパッケージ部分更新のマージ・安全検証パターン
    maildb-operations/          maildb パッケージの API 使用パターン
    system-open/                SystemOpen によるファイル・フォルダ・ノートブックの開き方
    adapter-tool-flow-debugging/ adapter 経路 ClaudeEval の異常診断手順
    async-tool-execution/       AsyncToolExec(Phase 32k Step 3)の設計・運用・デバッグ
    runtime-orchestrator-boundary/ ClaudeRuntime と ClaudeOrchestrator の責務境界
```

## 主要な設計原則

### NBAccess 分離原則 (`rules/10-nbaccess.md`)
ノートブックのセルへの直接アクセスを禁止し、すべて NBAccess の公開 API 経由で操作する。
`NotebookWrite`, `CellPrint`, `EvaluationCell[]`, `SelectionMove`, `CurrentValue[..., TaggingRules]` 等の直接使用は、NBAccess.wl と NotebookExtensions.wl を除き一切認めない。

### 基盤パッケージの依存方向制約 (`rules/11-core-package-dependency.md`)
claudecode.wl と NBAccess.wl は他のパッケージ（maildb, GitHubREST 等）に一切依存してはならない。依存方向は常に一方向: 任意のパッケージ → 基盤パッケージ。

### ScheduledTask・非同期処理の安全制約 (`rules/95-scheduled-task-safety.md`)
ScheduledTask に関する2つの制約を統合: (A) ClaudeEval の ScheduledTask チェーン内から ClaudeQuery / ExternalEvaluate を呼ぶことの禁止（デッドロック防止）、(B) パッケージが UI ポーリング用に独自の CreateScheduledTask を作成することの禁止（動的評価オーバーフロー防止）。FrontEnd 通信を行わない純粋計算タスクや、リアルタイム性が必要なインタラクティブプログラムは例外だが、ドキュメントに明記が必要。

### AsyncToolExec 経路の必須ルール (`rules/100-async-tool-execution.md`)
`$UseClaudeRuntime = True` 経路で 1 turn 内に複数 tool (web_search 等) を別 OS プロセスで並列実行する Phase 32k Step 3 (Phase A〜D2) の規範。`ParallelSubmit` / `SessionSubmit` / 独自 `ScheduledTask` を禁止し `StartProcess` + 既存 polling tick 基盤を使うこと、`AsyncToolExecScheduled` 返却時の callback 早期 return、`Index` キーによる tool 順序保持、API key の file 経由など 11 ルール。詳細手順は `skills/async-tool-execution`。

### Fallback 絶対順守要件 (`rules/90-api-error-handling.md`)
`Fallback -> True` を明示的に指定しない限り、LLM のレート制限エラー時に代替処理を行ってはならない。エラーは `Failure[...]` として上位に伝播させ、処理を確実に停止する。エラーメッセージをデータとして利用する（リポジトリ名やファイル内容に変換する等）ことは禁止。

### パッケージ操作制約 (`rules/80-package-operations.md`)
パッケージの更新は `ClaudeUpdatePackage` 経由で行い、`Import`/`Export` による手動読み書きは禁止。関数名は `_info/docs/api.md` に記載されたもののみ使用し、推測で生成しない。

## インストール

このディレクトリを `$packageDirectory` に配置します。claudecode.wl 関数が自動的にディレクティブを検出・活用します。

```
$packageDirectory/
  Claude Directives/
    CLAUDE.md
    rules/
      00-autoeval-prohibited.md
      01-wolfram-general.md
      ...
    skills/
      wolfram-general/SKILL.md
      nbaccess-notebook-access/SKILL.md
      ...
```

GitHub 連携で `Claude Directives` フォルダをリポジトリに含める場合:

```mathematica
GitHubCreateRepository["claudecode", ExtraDirectories -> {"Claude Directives"}]
```

## 基盤パッケージとの関係

| パッケージ | 役割 | 主な関連ルール |
|---|---|---|
| `NBAccess.wl` | ノートブックセルアクセスの一元化層 | `rules/10-nbaccess.md` |
| `claudecode.wl` | Claude Code CLI 連携・パッケージ管理・非同期タスク管理 | `rules/80-package-operations.md`, `rules/90-api-error-handling.md`, `rules/95-scheduled-task-safety.md` |
| `github.wl` | GitHub REST API 連携・リポジトリ管理 | `skills/github-operations/SKILL.md`, `rules/90-api-error-handling.md` |
