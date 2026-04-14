# claudecode / NBAccess と claw-code の比較レポート

比較してみると、**いちばん大きな差は「Notebook フロントエンド」はかなり作れているが、「自前の agent runtime」はまだ薄い**、という点です。

あなたの `claudecode.wl` / `NBAccess.wl` は、

- Mathematica Notebook のセル操作抽象化
- 機密セル・依存セルの追跡
- TaggingRules ベースのセッション履歴
- 履歴コンパクション
- 非同期ジョブと Notebook への書き戻し
- LLMGraph / DAG 的な上位構造

がかなり充実しています。ここはむしろ `claw-code` より強いです。

一方で、添付の `claw-code` は **CLI agent の実行基盤**として、  
`api / runtime / tools / commands / plugins / telemetry`  
に分かれた構造を持っていて、そこが今の `claudecode/NBAccess` に足りない部分です。

---

## まず結論

**足りないものを一言でいうと、Notebook 依存でない中核 runtime 層**です。

今の `claudecode.wl` は、かなりの部分で

- Claude CLI を外部プロセスとして起動し
- 文字列で prompt を渡し
- 最終出力テキストを受け取って
- Notebook 側の履歴に保存する

という構造です。実際、`RunProcess` / `StartProcess` で bat を起動する実装になっており、`node-pty` 補助も使っています。  
これに対して `claw-code` は、**自前の turn loop と tool-call loop を持つ runtime** です。`ConversationRuntime::run_turn` が、ユーザ入力 → モデル応答 → tool use → tool result → 再度モデル、という反復を回しています。

つまり、

- 今の実装は **Notebook から Claude/CLI を使う層**
- `claw-code` は **Claude 型 agent 自体を実装する層**

です。

---

## あなたの実装ですでにある強い部分

ここは先に明確にしておきます。

### 1. Notebook 抽象化

`NBAccess.wl` はセル・TaggingRules・機密タグ・依存関係・履歴 DB をかなり丁寧に抽象化しています。  
これは `claw-code` にはない、Mathematica 固有の強みです。

### 2. 履歴 DB とコンパクション

`claudecode.wl` ではセッション履歴アクセスを `NBAccess` の汎用履歴 API に委譲しており、さらにローカル要約ベースの履歴コンパクションも入っています。  
この「Notebook に埋め込まれたセッション DB」はかなりよくできています。

### 3. 機密性モデル

`NBAccess` には provider ごとの最大アクセスレベルや fallback モデル管理があります。  
これは `claw-code` の permission system とは別軸ですが、**Notebook 内の情報流出制御**として有意義です。

---

## `claw-code` と比べて足りないもの

### 1. 自前の turn loop / tool loop

これが最重要です。

`claw-code` では 1 ターンの中で、

- assistant message を構築し
- その中の `ToolUse` block を抽出し
- permission を判定し
- tool を実行し
- `tool_result` をセッションに戻し
- さらに次の iteration に進む

という構造になっています。

今の `claudecode.wl` には、**Mathematica 側でこの構造化された turn loop がありません**。  
現状は「最終テキスト結果を受け取る」設計で、tool use の中間状態を Mathematica 側で一級オブジェクトとして扱っていません。

#### 何が不足か

不足しているのは、例えばこういう型・関数です。

- `ClaudeTurn`
- `ClaudeMessage`
- `ClaudeContentBlock`
- `ClaudeToolUse`
- `ClaudeToolResult`
- `ClaudeRunTurn`
- `ClaudeContinueTurn`
- `ClaudeBuildAssistantMessage`
- `ClaudeUsageRecord`

#### 影響

この層がないので、

- 独自 tool を Mathematica 側で差し込めない
- tool 呼び出しを可視化しづらい
- tool ごとの許可・拒否・再試行を制御しにくい
- MCP / plugin / skills の接続点が作りにくい

です。

---

### 2. 汎用 permission policy

今の `claudecode` の権限は、主に**ディレクトリ読み取り許可**です。  
Notebook の TaggingRules に保存する形にはなっていますが、`claw-code` の permission system に比べるとかなり限定的です。

`claw-code` には

- `ReadOnly`
- `WorkspaceWrite`
- `DangerFullAccess`
- `Prompt`
- `Allow`

という permission mode があり、さらに

- tool ごとの required permission
- allow / deny / ask rule
- hook による override
- interactive approval

があります。

#### 今の実装で足りない点

- tool 単位の required permission
- allow / deny / ask ルール
- write と read を分けた一般化
- workspace 外書き込み判定
- hook による permission override
- permission request を構造化して保持する仕組み

#### どこに置くべきか

これは **NBAccess ではなく runtime 層**です。  
NBAccess に置くのは「Notebook ローカルに permission 設定を保存する API」までで、判定エンジン本体は別 package にすべきです。

---

### 3. Mathematica 側の tool registry

`claudecode.wl` は CLI へ `--allowedTools` を渡していますが、これは Mathematica 側での本格的 registry ではありません。

一方 `claw-code` には `ToolSpec` とそれに基づく組み込みツール登録があり、少なくとも

- `bash`
- `read_file`
- `write_file`
- `edit_file`
- `glob_search`
- `grep_search`
- `WebFetch`
- `WebSearch`
- `TodoWrite`
- `Skill`
- `Agent`
- `ToolSearch`
- `NotebookEdit`

などが明示的に登録されています。

#### 今の実装に足りないもの

- Mathematica 側の `ToolSpec` 相当
- 入力 schema
- required permission
- executor
- tool registry
- tool manifest / discovery
- tool result の標準形式

#### 重要な点

これは **Notebook 操作 API の不足ではなく、runtime / agent 層の不足**です。

---

### 4. MCP / plugin / hooks / skills の拡張基盤

ここはかなり差があります。

`claw-code` では

- `mcp`
- `plugin`
- `skills`
- `agents`
- `hooks`

が command surface に入っています。

今の `claudecode.wl` の slash command は比較的小さく、  
少なくとも添付コード内では **MCP / plugin / hooks の実装痕跡は見当たりませんでした**。

#### 足りないもの

- MCP server registry
- MCP transport / lifecycle
- plugin install / enable / disable / update
- hook runner
- skill discovery / install / invoke
- agent / subagent registry

#### どこに置くべきか

これも NBAccess ではなく、別 package がよいです。  
たとえば

- `ClaudeRuntime.wl`
- `ClaudeMCP.wl`
- `ClaudePlugins.wl`
- `ClaudeSkills.wl`
- `ClaudeHooks.wl`

のように分けた方が保守しやすいです。

---

### 5. config / auth / provider abstraction

今の `claudecode/NBAccess` は provider 周りがまったくないわけではありません。

- fallback model list
- provider ごとの max access level
- `anthropic` / `openai` / `lmstudio` への API fallback

はあります。

ただし `claw-code` と比べると、まだ **runtime としての provider abstraction** が薄いです。

`claw-code` には、

- Anthropic
- OpenAI-compatible
- Ollama
- OpenRouter
- DashScope (Qwen)
- OAuth login / logout
- proxy support
- model aliases
- config hierarchy

があります。

#### 今の実装で不足しているもの

- OAuth の永続化と refresh
- config file hierarchy の merge
- provider alias / model alias 解決
- proxy 設定
- provider 自動判定
- context window / max token の preflight
- provider ごとの streaming 差異吸収

#### ここで重要なこと

NBAccess に必要なのは、せいぜい

- API key 取得
- notebook-local provider 制約保存

までです。  
provider client 本体は NBAccess に入れるべきではありません。

---

### 6. Notebook 外でも使える session persistence

今の実装は session / history を Notebook の TaggingRules にかなりうまく載せています。  
ただ、`claw-code` の session は **Notebook 非依存**で、resume や export や workspace session directory を持っています。

今の `claudecode` は session の作成・継承・削除はありますが、基本的に Notebook 内セッションです。  
`claw-code` 的にはさらに次が欲しいです。

- JSONL などの外部 session file
- session ID ベース resume
- fork / branch metadata
- export / import
- Notebook を閉じても追跡しやすい session index

#### NBAccess に足すなら

Notebook ローカル永続化としては、次があるとよいです。

- `NBSessionExport[nb, tag, path]`
- `NBSessionImport[nb, path, tag]`
- `NBSessionFork[nb, srcTag, dstTag, meta]`
- `NBSessionRename[nb, oldTag, newTag]`
- `NBSessionList[nb]`

ただし global session manager 自体は NBAccess ではなく runtime / config 側が向いています。

---

### 7. usage / cost / stats / telemetry

`claw-code` には

- cost
- usage
- stats
- telemetry

があります。  
今の `claudecode` は session status や progress はありますが、**構造化された telemetry 層**はまだ薄いです。

#### 足りないもの

- token usage record
- provider / model 別 usage 集計
- session ごとの cumulative cost
- tool usage 統計
- failure class 集計
- machine-readable status export

#### NBAccess に足すなら

- `NBUsageAppend`
- `NBUsageRead`
- `NBToolTraceAppend`
- `NBToolTraceRead`

くらいまでは NBAccess に置けます。  
でも集計ロジックは runtime 側です。

---

### 8. doctor / parity harness / mock service

`claw-code` のかなり強い点です。

- deterministic mock Anthropic-compatible service
- mock parity harness
- scenario manifest

があります。

今の `claudecode/NBAccess` には、少なくとも添付コード内では、この種の**再現可能な自動テスト基盤**が見当たりません。

#### 足りないもの

- mock LLM service
- golden test
- session replay test
- tool roundtrip test
- permission approval test
- regression harness

これは NBAccess の仕事ではなく、完全に別テスト基盤です。

---

### 9. command registry の体系化

`claw-code` は slash command spec がデータ構造として定義されていて、help / render / validation がその上に乗っています。  
今の `claudecode` は slash command map が比較的手書きで小さいです。

#### 足りないもの

- command spec データ
- help renderer
- argument validator
- text / json 両出力
- notebook UI への接続点

これも runtime / UI 分離の題材です。

---

## では、何を NBAccess に足し、何を別 package に出すべきか

ここが重要です。

### NBAccess に足すべきもの

NBAccess は今の方針どおり、**Notebook アクセス境界**に限定した方がよいです。  
足すとしても次くらいです。

1. `NBToolTraceAppend / NBToolTraceRead`  
   1 turn 中の tool call / result を Notebook に保存する汎用 API

2. `NBUsageAppend / NBUsageRead`  
   usage / cost / provider / model の記録 API

3. `NBSessionExport / NBSessionImport`  
   Notebook 埋め込みセッションと外部ファイルの相互変換

4. `NBPermissionStoreGet / NBPermissionStoreSet`  
   notebook-local permission ルール保存 API

5. `NBCommandPaletteStateGet / Set`  
   slash command / session UI 状態の保存

#### NBAccess に入れない方がよいもの

- provider client
- MCP
- plugin
- hooks
- tool registry 本体
- permission policy engine
- config loader
- session manager 本体

これは全部、Notebook アクセス層ではありません。

---

### 新しく分けるべき package

一番自然なのは、`claw-code` の crate 分割にかなり近い分離です。

#### 1. `ClaudeRuntime.wl`

中核。最重要です。

入れるもの:

- turn loop
- message / content block 型
- tool use / result 型
- session manager
- permission policy
- usage tracker

#### 2. `ClaudeTools.wl`

- tool spec
- tool registry
- built-in executors
- notebook tool adapter

#### 3. `ClaudeConfig.wl`

- config hierarchy
- provider alias
- model alias
- auth config
- fallback config
- proxy config

#### 4. `ClaudeProviders.wl`

- anthropic / openai / lmstudio 等の client
- streaming parser
- max token / context window preflight

#### 5. `ClaudeExt.wl` あるいは分割

- `ClaudeMCP.wl`
- `ClaudePlugins.wl`
- `ClaudeSkills.wl`
- `ClaudeHooks.wl`

#### 6. `claudecode.wl`

- 最終ユーザ向け facade
- Notebook UI
- palette
- `ClaudeEval` / `ContinueEval` / `ClaudeCommand` などの公開 API

---

## 優先順位つきで言うと

### 最優先

1. **self-contained runtime turn loop**
2. **tool registry**
3. **general permission policy**

ここがないと、`claw-code` 型の拡張は載りません。

### 次点

4. **config / provider abstraction**
5. **structured session / usage export**
6. **command registry**

### その次

7. **MCP / plugin / hooks / skills**
8. **parity harness / test infrastructure**

---

## 一番本質的な比較結果

要するに、

- `NBAccess.wl` は **Notebook OS / notebook adapter**
- `claudecode.wl` は **Notebook 向け frontend / orchestration**
- でも `claw-code` に相当する **runtime kernel** がまだ独立していない

ということです。

いまの実装は「Claude Code を Mathematica から使う」にはかなり強いです。  
しかし「Claude Code 的 runtime を Mathematica 側で自前実装する」観点では、次が足りません。

- 構造化 turn loop
- 構造化 tool loop
- tool / permission / config / session の中核抽象
- extensibility 基盤

なので、**次の一手は NBAccess を増やすことより、`ClaudeRuntime.wl` を切り出すこと**だと思います。
