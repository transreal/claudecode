---
name: doc-generation
description: Use when generating or updating package documentation with ClaudeCreateDocumentation or ClaudeUpdateDocumentation. Covers resumption after limits, README structure, document queue ordering, and option usage.
---

# ドキュメント生成ルール

## api.md の役割（最重要）

**api.md はパッケージの「唯一の真実のソース」である。** LLM がこのファイルだけを読んで、パッケージの全公開関数を正しく使えるコードを書けなければならない。

### api.md のフォーマット原則（LLM 最適化）

api.md はヒトが読むドキュメントではなく、**LLM がコード生成に使う参照ファイル**である。
以下の原則でトークン消費を最小化しつつ情報密度を最大化する:

1. **空行を最小限にする**: セクション見出し前の1行のみ。関数エントリ間に空行を入れない
2. **セパレータ `---` を使わない**: `###` 見出しだけで区別する
3. **Bold/装飾を最小限にする**: `**引数:**` などの冗長なラベルは不要
4. **自明な使用例を省略する**: `NBCellCount[nb]` のような単純な関数に例は不要。オプションやパターンが複雑な関数にのみ例を付ける
5. **1関数 = 最小行数**: シグネチャ + 説明 + オプション（あれば）+ 戻り値を密に記述

### api.md の具体的フォーマット

#### 定数/変数
```
### $VarName
型: Association, 初期値: <|"key" -> value|>
説明文（1行）
```

#### 単純な関数（オプションなし）
```
### FuncName[arg1, arg2] → ReturnType
説明文（1行）
```

#### オプション付き関数
```
### FuncName[arg1, arg2, opts]
説明文（1行）
→ ReturnType（構造の説明が必要なら追記）
Options: Opt1 -> Default1 (説明), Opt2 -> Default2 (説明)
```

#### 複雑な関数（例が必要）
```
### FuncName[arg1, arg2, opts]
説明文
→ <|"Key1" -> ..., "Key2" -> ...|>
Options: Opt1 -> Default1 (説明), Opt2 -> Default2 (説明)
例: FuncName["pkg", "msg", Branch -> "dev", Force -> True]
```

#### 複数パターン
```
### FuncName[a] / FuncName[a, b] / FuncName[a, b, c]
パターン別の説明
```

### api.md に必須の内容:
- すべての公開関数: シグネチャ、全オプション（デフォルト値+説明）、戻り値の型
- すべての公開定数/変数: 型、初期値、説明
- 複雑な関数のみ: 使用例（1-2行）
- 関数はカテゴリ別にグループ化（`## カテゴリ名`）

### api.md の参照優先ルール:
- コード生成時: **api.md → ソースコード** の順で参照（api.md で解決できればソースは不要）
- 関数の説明を求められたとき: **api.md → user_manual.md → ソースコード** の順
- api.md に記載されていない関数やオプションを推測で生成してはならない

## ドキュメントキューの順序（厳守）

**README.md は必ず最後に生成/更新する。これは絶対的なルールである。**

`$iDocQueue` および `ClaudeUpdateDocumentation` の処理順序:

1. setup.md — インストール手順書
2. user_manual.md — ユーザーマニュアル
3. api.md — API リファレンス
4. examples/example.md — 使用例集
5. **README.md** （**必ず最後**: 上記1-4の最新内容を参照して概要を合成）

### README.md を最後にする理由

README.md はパッケージの概要文書であり、setup.md / user_manual.md / api.md / examples の**重要な点のまとめ**として機能する。先に生成すると:
- 他ドキュメントにまだ書かれていない情報を参照できず、記述が不完全になる
- ソースコード変更の反映が他ドキュメント経由で間接的にしか行われず、重要な変更点が抜ける

コード内では `iEnsureReadmeLast` ヘルパーが自動的に README.md をリストの末尾に移動する。`iGuessTargetDocs` の結果にも適用される。

### ClaudeUpdateDocumentation での更新順序

`ClaudeUpdateDocumentation` 実行時も**同じ順序を厳守する**:
- 1引数版（自動差分検出）: `allDocs` は `iEnsureReadmeLast` で README.md を末尾に移動
- 2引数版（指示付き）: `iGuessTargetDocs` の結果に `iEnsureReadmeLast` を適用
- README.md の更新プロンプトには、直前に更新された他ドキュメントの最新内容が参照コンテキストとして含まれる

## README.md の必須構造（厳守）

README.md は以下の構造を**この順序で**持たなければならない:

### 1. `# パッケージ名` — 設計思想と実装の概要
- パッケージの一行説明
- なぜこう設計されているか（Why）
- 高レベルの仕組み（How）
- 他ドキュメントと design/ フォルダのメモを参照して構成

### 2. `## 詳細説明`
以下のサブセクションを含む:
- **動作環境** (OS, Mathematica version, external tools)
- **インストール** (UTF-8 ロードパターン必須)
- **クイックスタート** (最小限の動作確認コード)
- **主な機能** (機能一覧と簡潔な説明)
- **ドキュメント一覧** (setup.md, user_manual.md, api.md, examples/ へのリンク)

### 3. `## 謝辞`（Acknowledgments オプション指定時のみ）

### 4. `## 免責事項`（必須）

### 5. `## ライセンス`（設定済みの場合、**必ず最後**）

## 謝辞・免責事項・ライセンスの配置ルール（最重要・厳守）

**謝辞（Acknowledgments）、免責事項（Disclaimer）、ライセンス（License）は README.md の末尾にのみ存在しなければならない。**

### README.md 末尾の順序（厳守）:
1. `## 謝辞`（Acknowledgments オプションが非空の場合のみ）
2. `## 免責事項`（必須）
3. `## ライセンス`（必須、最後）

### 絶対禁止事項:
- setup.md, user_manual.md, api.md, examples/example.md に謝辞・免責事項・ライセンスのセクションを**絶対に追加してはならない**
- これらのファイルに既にこれらのセクションが存在する場合は、**削除しなければならない**
- ライセンス条項のコピーが複数ファイルに分散すると整合性が崩壊するため、**README.md 以外にライセンスを記載することは重大なバグである**

### 理由:
- ライセンス条項は法的文書であり、複数箇所に存在すると版管理・修正時に不整合が生じる
- 免責事項・謝辞も同様に、一箇所で管理されなければ矛盾が発生する

### コード実装:
- `iDocBuildAcknowledgmentsPrompt[]`, `iDocBuildDisclaimerPrompt[]`, `iDocBuildLicensePrompt[]` は README.md 生成時にのみプロンプトに挿入される
- 非 README.md ファイルのプロンプトには「謝辞・免責事項・ライセンスを追加するな」という明示的禁止指示が含まれる
- `$iDocKeywords` の README.md エントリには謝辞・ライセンス・免責関連キーワードが含まれ、`iGuessTargetDocs` がこれらの更新指示を README.md のみにルーティングする

### README.md の境界ルール（必須）
- README.md は「謝辞」→「免責事項」→「ライセンス」で終了する。それ以降にコンテンツを追加してはならない。
- 指示文やノートブックコンテキストの内容をそのまま転記してはならない。
- README.md に反映してよいのは、パッケージの概要・機能一覧・構造に影響する変更のみ。

## ClaudeUpdateDocumentation の更新動作（必須）

### 差分ベースの更新原則
- 直前の `_documentupdate` バックアップからソースコード差分を自動検出する
- 各ドキュメントは**既存の内容を踏襲**し、差分に対応する変更のみ挿入する
- 既存の構造・記述を大幅に書き換えてはならない（差分に関連する部分のみ修正）

### README.md 更新時の特別処理
- README.md 更新時、プロンプトには他ドキュメント（setup.md, user_manual.md, api.md 等）の**最新内容**が参照コンテキストとして含まれる
- これらは「参照コンテキスト」であり、README.md にコピーするものではない
- README.md には概要レベルの変更のみを反映する（新機能名の追加は可、詳細な使い方の転記は不可）

## 更新指示のスコープルール（必須）

`ClaudeUpdateDocumentation` で複数ドキュメントが更新対象になる場合、各ドキュメントの更新時には指示文の**該当部分のみ**を反映すること:
- 指示文が特定ドキュメント名を明示している場合（例:「user_manual に追記」「api.md のみ更新」）、他のドキュメントにはその詳細を転記しない
- README.md は常に概要レベルの変更のみ反映する（新機能名の一覧追加は可、詳細な使い方の転記は不可）
- 指示文やノートブックコンテキストがそのままドキュメント末尾に追記される事態は、明確なバグである

## オプション一覧

`ClaudeCreateDocumentation` / `ClaudeUpdateDocumentation` の共通オプション:

| オプション | デフォルト | 説明 |
|---|---|---|
| `Fallback` | `False` | Fallback モデル使用 |
| `References` | `{}` | 参考文献の URL / 書名リスト → README の「参考文献」セクションに追加 |
| `Demos` | `{}` | デモ動画・使用例の URL リスト → README の「使用例・デモ」セクションに追加 |
| `Disclaimer` | `{}` | 免責事項に追記する文言リスト |
| `Acknowledgments` | `{}` | 謝辞セクションに追加する文言リスト。非空なら README.md の免責事項の前に配置 |
| `License` | `""` | ライセンステキスト。空ならMIT自動生成。文字列指定でカスタムライセンス |
| `TargetFiles` | `Automatic` | 更新対象ファイルを明示指定。`Automatic` なら指示文から自動判定。`{"api.md", "install.md"}` 等でファイル限定 |
| `Mode` | `"Update"` | `"Update"` = 既存を差分更新、`"Create"` = 新規作成（既存内容を無視） |

第二引数の指示文中に URL が含まれていれば、自動的に `Demos` に追加される。

## トークン消費の最適化

### $ClaudeDocModel（ドキュメント専用モデル）
- デフォルト: `"claude-sonnet-4-20250514"` — ドキュメント生成は Sonnet クラスで十分
- `$ClaudeDocModel = ""` で `$ClaudeModel` と同じモデルを使用
- Create/Update/AutoApiUpdate の全フローで自動適用される

### ソースコードのチャンク化
- Update 流でも `iBuildChunkedSource` によるチャンク化を適用（以前はソース全文を毎回送信していた）
- 公開部分 + ドキュメント種別に関連するセクションのみを送信
- 550KB のソースが 60KB 以下に圧縮される

### 狭いスコープの更新指示
- `iIsNarrowScopeInstruction` がライセンス・免責・謝辞のみの更新を検出
- 該当する場合、README.md 更新時に兄弟ドキュメントの参照を省略（さらに 16KB 節約）

### iGuessTargetDocs のフォールバック
- キーワードにマッチしない場合、全ファイルではなく README.md のみを対象にする
- 全ファイル更新が必要な場合は 1引数版 `ClaudeUpdateDocumentation["pkg"]` を使用する

## 文体ルール（必須）

| ドキュメント | 文体 | 理由 |
|---|---|---|
| **api.md** | **常体**（だ・である調） | 簡潔さを優先するリファレンス文書 |
| setup.md | 敬体（です・ます調） | ユーザー向け説明 |
| user_manual.md | 敬体（です・ます調） | ユーザー向け説明 |
| examples/example.md | 敬体（です・ます調） | ユーザー向け説明 |
| **README.md** | **敬体**（です・ます調） | ユーザー向け概要・紹介 |

注意: `$Language` の設定に基づいて言語が決定される。日本語以外が設定されている場合はその言語で出力される。

## ドキュメント書き込みの安全機構

`iSafeWriteDoc` による保護:
- **サイズ退行ガード**: 既存ドキュメントの 40% 未満に縮小する場合は書き込みを拒否
- **タイトル整合性チェック**: README.md の先頭 `# タイトル` がパッケージ名と一致しない場合は拒否（LLM が別のドキュメント内容を返した場合の防護）

## API エラー・利用制限の保護（必須）

- すべてのファイル書き込み前に `iIsAPIErrorResponse` でレスポンスをチェックする。
- エラー/制限メッセージの場合、**ファイルを一切更新せず**エラーを報告して停止する。
- **fail-fast 原則**: 連続 API 呼び出しでは、最初のエラーで以降の呼び出しをすべてスキップする。
- 詳細な判定パターンとコード例は `rules/90-api-error-handling.md` を参照。

## ライセンスの自動挿入

- `License -> ""` (デフォルト) かつ `GitHubREST`$GitHubLicenseHolder` が非空文字列の場合:
  MIT ライセンスが README.md の最後（免責事項の後）に自動挿入される。
- `License -> "カスタムテキスト"`: 指定テキストがそのままライセンスセクションに挿入される。
- `$GitHubLicenseHolder` が空文字列の場合: ライセンスは挿入されず、警告が Print される。

## setup.md / README.md のインストール記述（必須）

### `$Path` のルール
- すべての `.wl` パッケージは `$packageDirectory` 直下に配置される
- `$Path` に追加するのは `$packageDirectory` 自体
- **正しい**: `AppendTo[$Path, $packageDirectory]`
- **誤り**: `AppendTo[$Path, "C:\\path\\to\\PackageName"]`
- claudecode を使用している場合は自動設定される

### パッケージロードパターン
```mathematica
Block[{$CharacterEncoding = "UTF-8"},
  Needs["PackageName`", "PackageName.wl"]];
```

## リミット到達時の動作

- `iIsDocLimitError` でリミットメッセージを判定
- リミット検出時: 当該ファイルは保存せず、以降のファイル生成も停止
- ノートブックに未生成ファイル一覧を赤太字で表示

## 継続（リザンプション）の動作

呼び出し時に `iCheckDocResumption` で以下を判定:
- **ソースが documentupdate より新しい** → 全ファイル再生成
- **ソースが documentupdate 以前で、一部ファイルのみ存在** → 未生成分のみ生成
- **全ファイル存在** → 全ファイル再生成
