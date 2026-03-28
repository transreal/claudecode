# claudecode パッケージ — api.wl ドキュメント

## 概要

`api.wl` は `claudecode` パッケージの中核ファイルです。パッケージの初期化、公開シンボルの宣言、グローバル変数の定義、セッション管理、ディレクトリアクセス許可システム、および各種内部ユーティリティ関数を含んでいます。

パッケージロード時に `NBAccess.wl`（ノートブック読み書き・プライバシー管理）および `github.wl`（GitHub REST API）を自動的に読み込みます。

---

## グローバル変数

### モデル設定

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `$ClaudeModel` | Claude CLI に渡すモデル名。`""` で Claude Code 自身のデフォルトモデルを使用します。 | `""` |
| `$ClaudePrivateModel` | 秘密データ処理用のローカルモデル指定。`AutoPrivate -> True` 時に使用されます。形式: `{"provider", "modelName", "url"}` | — |
| `$ClaudeDocModel` | ドキュメント生成・更新時に使用するモデル。未設定またはパターン `claude-sonnet-*` の場合は最新 Sonnet に自動更新されます。 | 最新 Sonnet |
| `$ClaudeTestModel` | 分離検証などのテスト用モデル名。初期値は `$ClaudeModel` と同じです。 | `$ClaudeModel` |
| `$ClaudeFallbackModels` | フォールバックモデルの優先順位リスト。各要素は `{"provider", "modelName"}` または `{"provider", "modelName", "url"}` の形式です。 | `{{"anthropic", opus}, {"openai", "gpt-5"}}` |

### 実行制御

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `$ClaudeTimeout` | `ClaudeQuery`・`ClaudeEval` 等のタイムアウト秒数です。 | `1200` |
| `$ClaudeVerbose` | `True` の場合、履歴コンパクション等の詳細ログを `Messages` に出力します。 | `False` |
| `$ClaudeEvalMaxDepth` | `ClaudeEval` が再帰的に `ClaudeEval` を生成する際の最大深度です。`0` で再帰禁止。 | `5` |
| `$ClaudeWorkingDirectory` | Claude Code を起動する作業ディレクトリです。配下の `.claude/CLAUDE.md`、`.claude/rules/`、`.claude/skills/` が読み込まれます。 | `FileNameJoin[{$HomeDirectory, "Claude Working"}]` |

### ファイルアクセス

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `$ClaudeAccessibleDirs` | Claude Code に Read 許可する追加ディレクトリのリストです。`NotebookDirectory` は初回使用時にダイアログで確認します（`$packageDirectory` 配下を除く）。 | `{$packageDirectory}` |
| `$ClaudeMDPath` | 読み込まれる `CLAUDE.md` のパスです。自動検索されるか手動で上書きできます。 | `""` |
| `$ClaudeMDContent` | 読み込まれた `CLAUDE.md` の内容です。空の場合、ファイルが見つからなかったか内容がありません。 | `""` |

### ドキュメント生成

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `$ClaudeDocRetryDelay` | ドキュメント生成のリトライ待機秒数です。 | `60` |
| `$ClaudeDocMaxRetries` | ドキュメント生成の最大リトライ回数です。 | `3` |
| `$ClaudeDocMaxChunkChars` | プロンプト中ソースの最大文字数です。 | `60000` |
| `$ClaudePackageKeywordMap` | 外部パッケージがキーワードを登録するための `Association` です。プロンプトにキーワードが含まれると、対応パッケージの `api.md` がコンテキストに自動注入されます。 | `<||>` |

---

## ディレクトリアクセス許可システム

`NotebookDirectory` が `$packageDirectory` や `$ClaudeWorkingDirectory` と異なる場合、ユーザーへの許可確認ダイアログを表示します。許可結果はノートブックの `TaggingRules` に永続化されます。

### 内部関数

#### `iIsSafeDefaultDir[dir]`

指定ディレクトリが安全なデフォルトディレクトリ（`$packageDirectory` またはその親、`$ClaudeWorkingDirectory` またはその親）に含まれるかを判定します。

#### `iGetDirPermission[nb, dir]`

`TaggingRules` からディレクトリ許可設定を取得します。戻り値: `"read"` | `"denied"` | `None`。後方互換として旧バージョンの `"readwrite"` も `"read"` と同等に扱います。

#### `iSetDirPermission[nb, dir, perm]`

`TaggingRules` にディレクトリ許可設定を保存します。

#### `iAskDirPermission[nb, dir]`

ユーザーに許可を求めるダイアログを表示します。Read 許可と拒否の2択を提示します。戻り値: `"read"` | `"denied"`。

#### `iEnsureDirPermission[nb, dir]`

ディレクトリアクセスの許可を確認し、必要ならダイアログを表示します。許可された場合は `$ClaudeAccessibleDirs` に追加し、`TaggingRules` に保存します。セッション内キャッシュ（`$iDirPermissionCache`）により、同じディレクトリへの二重ダイアログを防ぎます。戻り値: `True`（許可）/ `False`（拒否）。

---

## パッケージロック機構

同一パッケージへの並列更新を防止するための排他ロックシステムです。

#### `iAcquirePackageLock[packageName, nb]`

パッケージのロックを取得します。既にロック中の場合は警告を表示し `False` を返します。

#### `iReleasePackageLock[packageName]`

パッケージのロックを解放します。

---

## パレット設定

パレット UI の設定をノートブックの `TaggingRules` に永続化します。

### 内部変数

| 変数 | 説明 | デフォルト |
|------|------|-----------|
| `$iPaletteModel` | パレットで選択中のモデル。`"opus"` / `"sonnet"` / `"default"` のいずれか。 | `"opus"` |
| `$iPaletteEffort` | パレットで選択中の Effort レベル。`"low"` / `"medium"` / `"high"` / `"max"` のいずれか。 | `"medium"` |
| `$iPaletteFallback` | パレットの Fallback 設定です。 | `False` |

### 内部関数

#### `iLoadPaletteSettings[nb]`

ノートブックから設定を読み込み、グローバル変数（`$iPaletteModel`、`$iPaletteEffort`、`$iPaletteFallback`、`$ClaudeModel`）を同期します。設定がないノートブック（新規等）ではメモリ上の値を保持します。

#### `iSavePaletteSettings[nb]`

現在のパレット設定をノートブックの `TaggingRules` に保存します。

#### `iPaletteOptionsString[]`

現在のパレット設定からオプション文字列（例: `", Fallback -> True"`）を生成します。

---

## 履歴管理内部関数

### `iClearAllClaudeHistory[nb]`

**更新（2026-03）**

ノートブック `nb` の以下のデータを完全に削除します。

1. **全セッション履歴**（デフォルト・名前付きを含む全て）
2. **LLMGraph データ**（`TaggingRules` の `"LLMGraph"` キーおよびセッション内キャッシュ `$iLLMGraphCacheNB`）
3. **ディレクトリアクセス設定**（`claudeAccessibleDirs` および `claudeDirPermissions`）

他者にノートブックを渡す際に、会話履歴やローカルパス等の不要な情報を削除するために使用します。この操作は取り消せません。実行前にユーザーへの確認ダイアログを表示します。

**保持されるもの**: 機密マーク・パレット設定は削除されません。

- `AccessLevel` が不足している場合は警告を表示し失敗します。
- 成功時は削除したセッション数とともに「`✔ All history cleared (N sessions + LLMGraph + directory settings)`」を表示します。

---

## AccessLevel 強制リテラル化システム

### 設計方針

`PrivacySpec` の `AccessLevel` 値には変数ではなく数値定数（`0.5`、`0.75`、`1.0` 等）のみを使用しなければなりません。これにより、コード検索で機密アクセス箇所を静的に特定できます。

### `iForceAccessLevelLiterals[code]`

**新機能（2026-03 追加）**

Wolfram Language コード文字列中の `"AccessLevel" -> 変数名` を `"AccessLevel" -> 0.5` に強制置換します。

LLM が変数による `AccessLevel` 指定を生成した場合に備え、`ClaudeUpdatePackage` 完了後の最終出力にも適用されます。

**置換ルール**:
- `accessLevel >= 1.0` の場合 → `"AccessLevel" -> 1.0`
- `accessLevel >= 0.75` の場合 → `"AccessLevel" -> 0.75`
- それ以外 → `"AccessLevel" -> 0.5`

**適用タイミング**:
1. `ClaudeUpdatePackage` 完了後の最終コード出力
2. `ClaudeFixSeparation` での LLM 修正の前後

**なぜ変数禁止か**: コードベース全体で `"AccessLevel" -> 数値` を grep することで、機密データアクセス箇所を網羅的に特定できます。変数を使うと静的解析が不可能になります。

---

## フォールバックモデル同期

#### `iSyncFallbackModelsToNBAccess[]`

`$ClaudeFallbackModels` の内容を `NBAccess`（`NBAccess`\`NBSetFallbackModels`）に同期します。パッケージロード時に自動実行されます。

---

## オプションシンボル

以下のシンボルは各種関数のオプションキーとして使用されます。

| シンボル | 用途 |
|---------|------|
| `Fallback` | `ClaudeQuery`/`ClaudeEval`/`ContinueEval` — 利用不可時にフォールバックモデルへ自動切替えます。 |
| `AutoPrivate` | `ClaudeQuery`/`ClaudeEval`/`ContinueEval` — 秘密変数アクセス時に自動でプライベートモデルを使用します。 |
| `AutoEvaluate` | `ClaudeEval`/`ClaudeWriteResponse` — 生成された Input セルを自動実行するかを制御します（デフォルト `True`）。 |
| `StartTime` | `ClaudeEval`/`ContinueEval`/`ClaudeUpdatePackage` — 実行開始時刻を `DateObject` で指定します。 |
| `Timeout` | `ClaudeQuery`/`ClaudeEval`/`ContinueEval` — タイムアウト秒数を指定します。 |
| `TargetFiles` | `ClaudeUpdateDocumentation` — 更新対象ファイルを指定します。 |
| `TargetFunctions` | `ClaudeUpdatePackage` — 更新対象関数を指定します。 |
| `Mode` | `ClaudeUpdateDocumentation` — `"Update"`（既存更新）または `"Create"`（新規作成）。 |
| `DryRun` | `ClaudeMigrateBackupHistory`/`ClaudePrepareCommit` — 実際の変更を行わずに結果を確認します。 |
| `RepeatInterval` | `ClaudeEval` — 繰り返し実行の間隔を指定します。 |
| `PrivacySpec` | 各種関数 — プライバシーレベルを指定します。 |
| `WebFetch` | `ClaudeQuery`/`ClaudeEval` — Web フェッチ（有料、`Fallback -> True` 必須）の使用を制御します。 |
| `WebSearch` | `ClaudeQuery`/`ClaudeEval` — Claude Code CLI の Web 検索（無料）の使用を制御します。 |
| `References` | `ClaudeCreateDocumentation`/`ClaudeUpdateDocumentation` — README.md に追加する参考文献リストです。 |
| `Demos` | `ClaudeCreateDocumentation`/`ClaudeUpdateDocumentation` — README.md に追加するデモ動画・使用例 URL リストです。 |
| `Disclaimer` | `ClaudeCreateDocumentation`/`ClaudeUpdateDocumentation` — README.md の免責事項セクションに追加する文言リストです。 |
| `License` | `ClaudeCreateDocumentation`/`ClaudeUpdateDocumentation` — ライセンス文字列を指定します。 |
| `Acknowledgments` | `ClaudeCreateDocumentation`/`ClaudeUpdateDocumentation` — README.md の謝辞セクションに追加する文言リストです。 |
| `Owner` | `ClaudePrepareCommit` — GitHub リポジトリオーナーを指定します。 |
| `Repository` | `ClaudePrepareCommit` — GitHub リポジトリ名を指定します。 |
| `Branch` | `ClaudePrepareCommit` — コミット先ブランチを指定します。 |
| `BaseBranch` | `ClaudePrepareCommit` — 差分比較のベースブランチを指定します。 |
| `Inherit` | `CreateClaudeSession` — 既存セッション履歴を継承するかを制御します。 |

---

## 内部状態変数（参考）

| 変数 | 説明 |
|------|------|
| `$iDirPermissionCache` | ディレクトリアクセス許可のセッション内キャッシュです。 |
| `$iDocState` | パッケージ別ドキュメントオプション状態（非同期生成中のリセット防止用）です。 |
| `$iDocMediaFiles` | ドキュメント生成で使用するメディアファイルリストです。 |
| `$iPackageUpdateLocks` | パッケージ更新排他ロックの状態管理です。 |
| `$iSeparationCheckCache` | `ClaudeCheckSeparation` の結果キャッシュです（`ClaudeFixSeparation` で再利用）。 |
| `$currentUseFallback` | 非同期パスのフォールバック制御用グローバルフラグです。 |
| `$iAllowWebSearch` | Claude Code CLI の Web 検索ツール許可フラグです。 |
| `$iClaudeEvalCurrentDepth` | `ClaudeEval` の現在の再帰深度を追跡します。 |
| `$iLLMGraphCacheNB` | LLMGraph データのセッション内キャッシュです。`iClearAllClaudeHistory` 実行時に `None` にリセットされます。 |

---

## 関連ファイル

- `NBAccess.wl` — ノートブック読み書き・プライバシー管理（依存パッケージ）
- `github.wl` — GitHub REST API（依存パッケージ）
- `claudecode.wl` — パッケージエントリーポイント

## 関連リポジトリ

- [claudecode](https://github.com/transreal/claudecode) — 本パッケージのリポジトリ
- [NBAccess](https://github.com/transreal/NBAccess) — NBAccess パッケージ
- [github](https://github.com/transreal/github) — GitHubREST パッケージ