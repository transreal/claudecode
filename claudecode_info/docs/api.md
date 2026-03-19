# claudecode API リファレンス

パッケージ: `ClaudeCode`` `  
リポジトリ: https://github.com/transreal/claudecode

## グローバル変数

| 変数 | 型 | デフォルト | 説明 |
|------|-----|-----------|------|
| `$ClaudeModel` | String | `""` | Claude CLI に渡すモデル名。空文字は CLI デフォルト |
| `$ClaudePrivateModel` | List | `{}` | 秘密データ処理用のローカルモデル指定。AutoPrivate -> True 時に使用 |
| `$ClaudeTimeout` | Integer | `1200` | ClaudeQuery/ClaudeEval 等のタイムアウト秒数 |
| `$ClaudeWorkingDirectory` | String | `FileNameJoin[{$HomeDirectory, "Claude Working"}]` | Claude Code の作業ディレクトリ。FileNameJoin で構築（Windows パス区切り直書き禁止） |
| `$ClaudeMDPath` | String | `""` | 読み込む CLAUDE.md のパス（自動検索または手動指定） |
| `$ClaudeMDContent` | String | `""` | 読み込まれた CLAUDE.md の内容 |
| `$ClaudeAccessibleDirs` | List | `{$packageDirectory}` | Claude Code に Read 許可する追加ディレクトリ |
| `$ClaudeFallbackModels` | List | `{{"anthropic","claude-opus-4-6"},{"openai","gpt-5"}}` | フォールバックモデル優先順位。各要素は `{"provider","model"}` または `{"provider","model","customURL"}` |
| `$ClaudeEvalMaxDepth` | Integer | `5` | ClaudeEval が再帰的に ClaudeEval を生成する際の最大深度。0 で再帰禁止 |
| `$ClaudeTestModel` | String | `$ClaudeModel` と同じ | 分離検証用モデル名 |
| `$ClaudeDocRetryDelay` | Integer | `60` | ドキュメント生成のリトライ待機秒数 |
| `$ClaudeDocMaxRetries` | Integer | `3` | ドキュメント生成の最大リトライ回数 |
| `$ClaudeDocMaxChunkChars` | Integer | `60000` | プロンプト中ソースの最大文字数 |

### $ClaudePrivateModel
型: List, 初期値: `{}`
秘密データ処理用のローカルモデル指定。`AutoPrivate -> True` 時に秘密変数を含むタスクの生成コードに `Model -> $ClaudePrivateModel` が付与される。
例: `$ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}`

### $ClaudeEvalMaxDepth
型: Integer, 初期値: `5`
ClaudeEval がコード内でさらに ClaudeEval/ContinueEval を生成する連鎖呼び出しの上限。0 で再帰禁止。値を大きくすると多段階の自動タスク連鎖が可能。

`$ClaudeFallbackModels` の各要素は以下の形式を取る:
- `{"provider", "model"}` — 標準プロバイダー（anthropic, openai）
- `{"provider", "model", "customURL"}` — カスタムエンドポイント（LM Studio 等のローカルモデル）
- provider が `"lmstudio"` の場合、API キー不要。デフォルト URL は `http://localhost:1234`。URL に `/v1/chat/completions` が含まれていなければ自動補完される。
- パッケージロード時に `NBAccess`NBSetFallbackModels` へ自動同期される。
例: `$ClaudeFallbackModels = {{"anthropic","claude-opus-4-6"},{"lmstudio","gpt-oss-20b","http://127.0.0.1:1234"}}`

## 内部動作: エラー出力と stream-json

Claude Code CLI は `--output-format stream-json --verbose --include-partial-messages` オプションで起動される。stdout に JSON Lines 形式のストリーミングイベントが出力され、stderr にはエラー・制限メッセージが出力される。`iExtractResultFromStreamJson` が JSON パース不能な行を stderr 行として収集し、結果が空の場合にこれらを `"Error: ..."` として返す。この仕組みにより、利用制限メッセージ等が確実に検出される。

ファイルパス操作はすべて `FileNameJoin` を使用し、Windows のバックスラッシュ (`\\`) やパス区切り文字のハードコーディングは禁止されている。

## 内部動作: アクセスレベル対応ルーティング

ClaudeQuery/ClaudeEval/ContinueEval は `PrivacySpec` と `Model` オプションからアクセスレベルを解決し、三段階のルーティングを行う:
1. Claude Code（claudecode プロバイダー）がアクセスレベルに対応可能 → Claude Code 経由で実行（フォールバック時は対応可能なモデルのみ使用）
2. Claude Code が対応不可だがフォールバックモデルに対応可能なものがある → フォールバックモデルへ直接ルーティング
3. どのモデルも対応不可 → エラー表示

`iResolveAccessLevel[privSpec, modelSpec]` がアクセスレベルを決定する:
- `PrivacySpec -> Automatic, Model -> Automatic` → "claudecode" プロバイダーの MaxAccessLevel
- `PrivacySpec -> Automatic, Model -> {"provider",...}` → そのプロバイダーの MaxAccessLevel
- `PrivacySpec -> <|"AccessLevel" -> n|>` → 明示値 n

## 内部動作: パッケージ更新排他ロック

`ClaudeUpdatePackage` は同一パッケージの並列更新を防止する排他ロック機構を持つ。`$iPackageUpdateLocks` で更新中のパッケージを追跡し、ロック中のパッケージに対する更新要求は警告を表示してスキップする。コールバック完了時にロックは自動解放される。

## 内部動作: フォールバックモデル同期

`$ClaudeFallbackModels` の値はパッケージロード時に `NBAccess`NBSetFallbackModels` へ自動同期される。これにより NBAccess 側のプロバイダー情報やアクセスレベル判定が最新の状態を反映する。

## クエリ・コード生成

| 関数 | 説明 |
|------|------|
| `ClaudeQuery[prompt]` | prompt を Claude Code に送信し応答文字列を返す（非同期） |
| `ClaudeQuery[session, prompt]` | セッション履歴を考慮して回答する |
| `ClaudeMath[task]` | Mathematica コード生成に特化したプロンプトで Claude を呼び出す |
| `ClaudeExtractCode[response]` | 応答から最初の `` ```mathematica `` ブロックを抽出する |
| `ClaudeExtractAllCode[response]` | 応答から全 `` ```mathematica `` ブロックをリストで返す |

### ClaudeQuery[prompt, opts]
prompt を Claude Code に送信し、応答をノートブックにマークダウン形式で出力する（非同期）。
Options: `Fallback -> False`, `WebFetch -> False`, `Model -> Automatic`, `PrivacySpec -> Automatic`, `AutoPrivate -> False`
`Model`: `Automatic` で Claude Code 経由。`{"provider","model"}` または `{"provider","model","url"}` で API 直接呼び出し。
`PrivacySpec`: `Automatic` でモデル/プロバイダーに応じたアクセスレベル自動解決。`<|"AccessLevel" -> n|>` で明示指定。
`AutoPrivate`: `True` で秘密変数を含むタスクの生成コードに `Model -> $ClaudePrivateModel` を自動付与。
例: `ClaudeQuery["質問", Model -> {"lmstudio", "openai/gpt-oss-20b", "http://192.168.2.106:1234"}]`
例: `ClaudeQuery["秘密データの分析", AutoPrivate -> True]`

### ClaudeEval

```
ClaudeEval[task]
ClaudeEval[{text, data, ...}]
ClaudeEval[session, task]
```

コードを非同期で生成・表示し、デフォルトセッションに履歴を保存する。
問い合わせ中は経過時間と現在の状態（思考中/テキスト生成中/ツール実行中）、各種カウンタをリアルタイム表示する。
再帰深度が `$ClaudeEvalMaxDepth` に達すると警告を表示して停止する。

| オプション | デフォルト | 説明 |
|-----------|-----------|------|
| `AutoEvaluate` | `True` | 生成された Input セルを自動実行するか |
| `StartTime` | `Now` | 実行開始時刻を DateObject で指定 |
| `Fallback` | `False` | `True` で Claude Code 利用不可時に `$ClaudeFallbackModels` へ自動切替。アクセスレベルに基づき利用可能なモデルのみにフォールバック |
| `WebFetch` | `Automatic` | `True`: 必ず Web 検索。`False`: しない。`Automatic`: Claude が自動判断 |
| `RepeatInterval` | `None` | 繰り返し実行の間隔。`Quantity[n, "Hours"]` で無限繰り返し、`{Quantity[n, "Hours"], maxCount}` で最大回数指定 |
| `Model` | `Automatic` | `Automatic` で Claude Code 経由。`{"provider","model"}` または `{"provider","model","url"}` で API 直接呼び出し |
| `PrivacySpec` | `Automatic` | アクセスレベル指定。`Automatic` でプロバイダーに応じた自動解決。`<|"AccessLevel" -> n|>` で明示指定 |
| `AutoPrivate` | `False` | `True` で秘密変数を含むタスクの生成コードに `Model -> $ClaudePrivateModel, PrivacySpec -> Automatic` を自動付与 |

`AutoEvaluate -> True` の場合でも、外部サービスへの不可逆な書き込み操作（`GitHubRefreshAndCommit`, `GitHubPushAll`, `GitHubCommit`, `GitHubCreatePullRequest`, `GitHubMergePullRequest`, `GitHubSubmitPullRequest`）を含む生成コードは自動実行をスキップし、手動の Shift+Enter を要求する。それ以外の関数（`ClaudeUpdatePackage`, `ClaudeCreateDocumentation` 等）の生成コードは `AutoEvaluate` に従って自動実行される。

`RepeatInterval` 指定時は `TaskObject` が返る。`TaskRemove[]` で停止可能。
例: `ClaudeEval["タスク", RepeatInterval -> Quantity[2, "Hours"]]`
例: `ClaudeEval["タスク", RepeatInterval -> {Quantity[1, "Hours"], 5}]`
例: `ClaudeEval["タスク", Model -> {"lmstudio", "openai/gpt-oss-20b", "http://192.168.2.106:1234"}]`
例: `ClaudeEval["タスク", StartTime -> Now + Quantity[3, "Hours"]]`
例: `ClaudeEval["タスク", Fallback -> True]` — Claude Code が利用制限に達した場合、アクセスレベルに対応可能な $ClaudeFallbackModels のモデルを順次試行
例: `ClaudeEval["秘密データを分析", AutoPrivate -> True]` — 秘密変数アクセス時に $ClaudePrivateModel へ自動ルーティング
例: `ClaudeEval["タスク", PrivacySpec -> <|"AccessLevel" -> 1.0|>]` — 高アクセスレベルを明示指定

### ContinueEval

```
ContinueEval[session, instruction]
ContinueEval[instruction]
ContinueEval[]
```

セッションを継続する。引数なしは「エラーを修正してください」で継続。
アクセスレベルに基づく三段階ルーティング: Claude Code 使用可能ならそちらを優先、不可なら対応可能なフォールバックモデルへ直接ルーティング、どちらも不可ならエラー。
Options: `Fallback -> False`, `AutoEvaluate -> True`, `StartTime -> Now`, `Model -> Automatic`, `PrivacySpec -> Automatic`, `AutoPrivate -> False`

### ContinueUpdate

```
ContinueUpdate[]
ContinueUpdate[instruction]
ContinueUpdate[packageName, instruction]
```

直前の `ClaudeUpdatePackage` の結果を踏まえてバグ修正を継続する。
引数なしはデフォルト指示で継続。パッケージ名省略時は直前の呼び出しから自動取得。
→ ClaudeUpdatePackage の結果
Options: `Fallback -> False`, `"UpdateApiMd" -> True`, `StartTime -> Now`
例: `ContinueUpdate["上半円の境界線が欠けているので修正して"]`
例: `ContinueUpdate["pkg", "修正指示"]`

## セッション管理

| 関数 | 説明 |
|------|------|
| `CreateClaudeSession["name"]` | 名前付きセッションを作成（デフォルト履歴を継承） |
| `CreateClaudeSession[session]` | 既存セッションの履歴を継承した新セッションを作成 |
| `CreateClaudeSession[Inherit->False]` | 独立したセッションを作成 |
| `ClaudeRestoreSession[]` | デフォルトセッションをリストア |
| `ClaudeRestoreSession["name"]` | 指定名のセッションをリストア |
| `ClaudeListSessions[]` | ノートブック内の全セッションを一覧表示 |
| `ClaudeDeleteSession["name"]` | 指定セッションを削除 |
| `ClaudeDeleteSession["name","All"]` | セッションと全履歴を削除 |
| `ClaudeShowHistory[]` | デフォルトセッションの履歴を表示 |
| `ClaudeShowHistory[session]` | 指定セッションの履歴を表示 |
| `ClaudeCompactHistory[]` | デフォルトセッションの履歴を手動コンパクションする |
| `ClaudeCompactHistory[name]` | 指定セッションをコンパクションする |
| `ClaudeSessionStatus[]` | デフォルトセッションの状態を表示 |
| `ClaudeSessionStatus[name]` | 指定セッションの状態を表示 |

## アタッチメント

| 関数 | 説明 |
|------|------|
| `ClaudeAttach[path]` | デフォルトセッションに参照資料をアタッチ |
| `ClaudeAttach[session, path]` | 指定セッションにアタッチ |
| `ClaudeDetach[path]` | デフォルトセッションからデタッチ |
| `ClaudeDetach[session, path]` | 指定セッションからデタッチ |
| `ClaudeAttachments[]` | デフォルトセッションのアタッチメント一覧を返す |
| `ClaudeAttachments[session]` | 指定セッションのアタッチメント一覧を返す |
| `ClearAttachments[]` | デフォルトセッションの全アタッチメントをクリア |
| `ClearAttachments[session]` | 指定セッションの全アタッチメントをクリア |

アタッチされたファイルは ClaudeQuery/ClaudeEval 時に自動的に Read される。

## 機密セル管理

| 関数 | 説明 |
|------|------|
| `MarkConfidential[]` | 現在のセルを機密マークする |
| `MarkConfidential[cell]` | 指定セルを機密マークする |
| `UnmarkConfidential[]` | 現在のセルの機密マークを解除 |
| `UnmarkConfidential[cell]` | 指定セルの機密マークを解除 |
| `IsConfidential[]` | 現在のセルが機密かを返す |
| `IsConfidential[cell]` | 指定セルが機密かを返す |
| `Confidential[expr]` | 式を評価し、Input/Output セルを自動機密マーク |
| `NonConfidential[expr]` | 式を評価し、機密マークを明示的に解除 |
| `ScanConfidentialCells[]` | 全セルをスキャンし、機密変数参照セルを自動マーク |

機密セルは ClaudeEval/ClaudeQuery のプロンプトから除外される。

### AutoPrivate によるプライバシー対応自動ルーティング
`AutoPrivate -> True` オプションを ClaudeQuery/ClaudeEval/ContinueEval に指定すると、秘密変数にアクセスするタスクの生成コードに `Model -> $ClaudePrivateModel, PrivacySpec -> Automatic` が自動付与される。これにより秘密データの処理がローカル/プライベートモデルにルーティングされる。

`$ClaudePrivateModel` が未設定（空リスト）の場合、警告メッセージが表示される。

高アクセスレベル（cloudcode の MaxAccessLevel を超える）でクエリが実行された場合、LLM が書き込んだ新規セルは `iAutoMarkNewCellsConfidential` により自動的に機密マークされる。これにより、ローカルモデルが `Confidential[]` を使い忘れても安全が保たれる。

## デバッグ・レビュー

| 関数 | 説明 |
|------|------|
| `ClaudeDebug[codeOrFile, errorMsg]` | デバッグ支援を非同期で求める（即座に返る） |
| `ClaudeReview[codeOrFile]` | コードレビューを非同期実行（30000 文字超は自動チャンク分割） |
| `ClaudeReviewChunked[codeOrFile]` | ファイルをチャンク分割して非同期レビュー |
| `ClaudeSpec["task"]` | ノートブック内容からプログラム仕様を生成 |
| `ClaudeSpec[{"task", image, ...}]` | 画像付きで仕様を生成 |

## パッケージ管理

| 関数 | 説明 |
|------|------|
| `ClaudeCreatePackage[name, prompt]` | prompt に従い name.wl を新規作成し `$packageDirectory` に保存 |
| `ClaudeUpdatePackage[name, prompt]` | `$packageDirectory` の name.wl を Claude で更新（バックアップ作成） |
| `ClaudeRestorePackage[name]` | 直前のバックアップを復元 |
| `ClaudeUpdatePackageHistory[]` | 全パッケージの更新履歴をリストで返す |
| `ClaudeUpdatePackageHistory[name]` | 指定パッケージの更新履歴を返す |
| `ClaudeBackupDataset[]` | 全パッケージのバックアップ履歴を Review/Pull/Delete ボタン付き Grid で表示 |
| `ClaudeBackupDataset[name]` | 指定パッケージのバックアップ履歴を表示 |
| `ClaudeConvertToPaclet[name]` | 単一 .wl を Paclet ディレクトリ構造に変換 |

### ClaudeCreatePackage[name, prompt, opts]
新規パッケージを生成する。
Options: `Fallback -> False`
例: `ClaudeCreatePackage["MyPkg", "仕様"]`

### ClaudeUpdatePackage[name, prompt, opts]
既存パッケージを更新する。実行前に事前バックアップ（`pre_TIMESTAMP` フォルダ）を自動作成する。
同一パッケージの並列更新は排他ロック（`$iPackageUpdateLocks`）により防止される。ロック中のパッケージに対する更新要求は警告を表示してスキップする。コールバック完了時にロックは自動解放される。
Options: `TargetFunctions -> Automatic`, `StartTime -> Now`, `Fallback -> False`, `"UpdateApiMd" -> True`
`TargetFunctions`: 更新対象の関数名リスト。`Automatic` でプロンプトから自動推定。
`"UpdateApiMd"`: `False` で api.md の自動更新をスキップ。
prompt にはリスト `{文字列, Image, File[".../file.pdf"], ...}` も指定可能。
例: `ClaudeUpdatePackage["pkg", "修正指示", StartTime -> Now + Quantity[1, "Hours"]]`

### ContinueUpdate[instruction, opts]
直前の ClaudeUpdatePackage の結果を踏まえてバグ修正を継続する。
Options: `Fallback -> False`, `"UpdateApiMd" -> True`, `StartTime -> Now`

## ドキュメント生成

| 関数 | 説明 |
|------|------|
| `ClaudeCreateDocumentation["name"]` | パッケージの包括的ドキュメント一式を自動生成 |
| `ClaudeUpdateDocumentation["name", "指示"]` | 既存ドキュメントを指示に従って更新する。ノートブックのコンテキストも参照可能（「上で議論されている内容を反映して」など）。 |

| オプション | デフォルト | 説明 |
|-----------|-----------|------|
| `Fallback` | `False` | フォールバックモデル使用 |
| `References` | `{}` | URL/書籍名リスト。参考文献セクションに追加 |
| `Demos` | `{}` | デモ動画や使用例の URL リスト |
| `Disclaimer` | `{}` | 免責事項の文言リスト |
| `License` | `""` | 空文字で MIT 自動挿入。文字列指定でそのまま挿入 |

## ディレクティブ管理

| 関数 | 説明 |
|------|------|
| `ClaudeAddDirective[target, description]` | Claude で description を整形し、target ファイルに追加 |
| `ClaudeRestoreDirective[target]` | 直前のバックアップから復元 |
| `ClaudeListDirectives[]` | CLAUDE.md と全スキルの一覧を表示 |
| `ClaudeUpdateDirective[]` | ソースコードと Claude Directives の整合性をチェックし、不整合を自動修正する |
| `ClaudeUpdateDirective[text]` | text を Claude で解釈し CLAUDE.md / rules / skills の適切なファイルに反映する。ノートブックのコンテキストも参照可能。 |
| `ClaudeDirectiveBackupDataset[]` | ディレクティブの更新履歴を Review/Pull/Delete 付き Grid で表示 |
| `ClaudeSyncDirectives[dir]` | 指定ディレクトリ dir のファイルを Claude Directives フォルダと比較し、dir 側の方が新しいファイルで Claude Directives を更新する。dir にだけ存在するファイルもコピーする。Claude Directives 側にしかないファイルはそのまま。 |

`ClaudeAddDirective` オプション: `DryRun -> False`（`True` でファイル変更なし）。  
target は `"CLAUDE.md"` またはスキル名（例: `"wolfram-general"`）。
例: `ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]`

## Web 検索・取得

| 関数 | 説明 |
|------|------|
| `ClaudeWebSearch[query]` | Anthropic API の web_search ツールで検索し結果をテキストで返す |
| `ClaudeWebFetch[url]` | URL の内容を取得・要約して返す |
| `ClaudeWebFetch[url, prompt]` | 取得内容に対して prompt の指示を実行 |

## 分離検証

| 関数 | 説明 |
|------|------|
| `ClaudeCheckSeparation[target]` | [NBAccess](https://github.com/transreal/NBAccess) の分離原則違反箇所をリストアップ |
| `ClaudeFixSeparation[target]` | 分離違反を修正（ファイルパスならバックアップ後修正、パッケージ名なら ClaudeUpdatePackage 経由） |

target: ファイルパス / `$packageDirectory` の .wl 名 / パクレット名。

検査対象（静的パターン走査 + LLM 判定）:
- a. SystemCredential 直接利用
- b. CellObject 直接操作 (NotebookWrite/NotebookRead/CellGroupData 直接構築)
- c. CellEpilog/CellProlog/NotebookEventActions 直接操作
- d. NBAccess`Private` 関数呼び出し
- e. NBAccess 公開グローバル直接更新
- f. EvaluationCell[]/CellPrint[]/SetSelectedNotebook[] 直接使用
- g. CurrentValue/SetOptions による TaggingRules/CellTags/CellEpilog 属性直接アクセス
- h. CellObject の公開 API・戻り値・状態保持への漏洩
- i. SelectionEvaluate/FrontEndTokenExecute 等 FE 状態操作
- j. NBAccess 公開グローバルの破壊的更新 (AppendTo/AssociateTo 等)

`$ClaudeTestModel` のモデルで検査する。

## タスク状態監視

### ClaudeStatus[] → List
現在実行中の全 Claude タスク（ClaudeEval/ClaudeQuery 等）のリアルタイム状態を表示する。
stream-json 形式の出力を差分解析し、各タスクについて以下を表示する:
- 経過時間（秒）
- プロセス状態
- 現在の状態: 初期化 / 思考中 / テキスト生成中 / ツール実行中（ツール名付き）/ 応答完了 / 完了
- 思考断片数、テキスト断片数、ツール使用数
- 出力ファイルサイズ（KB）と行数
- 最新テキスト断片のプレビュー（最大60文字）
- 呼び出し元（Job:jobId または Async）

実行中のタスクがない場合はその旨を表示する。
ClaudeEval/ClaudeQuery の問い合わせ中のプログレス表示にもこれらのステータス情報が反映される（「Claude に問い合わせ中... Xs | 思考中 (思考:N) (テキスト:N) (ツール:N)」形式）。

## オプションシンボル

### AutoPrivate
型: Boolean (オプション), デフォルト: False
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True 時に秘密変数にアクセスするタスクの場合、生成コードに `Model -> $ClaudePrivateModel, PrivacySpec -> Automatic` を付与する。$ClaudePrivateModel が未設定の場合は警告を表示する。

### Fallback
型: Boolean (オプション), デフォルト: False
ClaudeQuery/ClaudeEval/ContinueEval のオプション。True で Claude Code 利用不可時にフォールバックモデルに自動切替。アクセスレベルに応じて利用可能なモデルのみにフォールバックする（`NBAccess`NBGetAvailableFallbackModels[accessLevel]` で取得）。

## その他

| 関数 | 説明 |
|------|------|
| `ClaudeCommand["/command"]` | Claude Code CLI のスラッシュコマンドを実行し結果を返す |
| `ShowClaudePalette[]` | Claude Code 操作用パレットを表示 |
| `ClaudeQueryShowContext[]` | デバッグ用: 次の ClaudeQuery が送信するノートブックコンテキストを表示 |
| `ClaudeShowAccessConfig[]` | デバッグ用: ファイルアクセス設定を表示 |

## 依存パッケージ

- [NBAccess](https://github.com/transreal/NBAccess) — ノートブック読み書き・プライバシー管理
- [github](https://github.com/transreal/github) (`GitHubREST``) — GitHub API 連携・パッケージ URL 取得