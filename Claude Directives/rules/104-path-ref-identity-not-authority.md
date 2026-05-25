---
paths:
  - "**/NBAccess*.wl"
  - "**/SourceVault*.wl"
  - "**/claudecode*.wl"
  - "**/sourcevault*.md"
  - "**/nbaccess*.md"
---

# 104 — PathRef は同一性であって権限ではない

## 原則

> **PathRef is identity, not authority.**
>
> `{"$onWork", ...}` のような rooted symbolic path は、複数 PC 間の同一性、
> 重複排除、再リンク、snapshot lookup、UI 表示に使ってよい。しかし、それだけで
> read / write / cloud-send 権限を与えてはならない。NBAccess の authorization は、
> 必ず現 PC の root registry で PathRef を解決し、明示された access mode と privacy
> policy を確認してから判断する。Alias は別 PC 由来 record の正規化専用であり、
> alias-only match を Claude Code settings.json に materialize してはならない。

## 背景

Dropbox / OneDrive 上の同一ファイルは、PC ごとに絶対パスが異なる
(`F:\Dropbox\On Work\...` と `C:\Users\imai_\Dropbox\On Work\...` など)。
SourceVault はこの差を吸収するため、絶対パスを `{"$onWork", "sub", "file.nb"}`
のようなシンボリックパスへ正規化し、`$SourceVaultCloudRootAliases` で旧 PC ルートも
同じシンボル名へ寄せる。これは同一性 (identity) の問題に対する正しい解である。

危険なのは、この「シンボリックパスへ正規化できた」という事実を、そのまま
アクセス権限の根拠に流用することである。シンボリックパスが付くこと、エイリアスに
match すること自体は、現 PC でそのファイルを読んでよい・クラウド LLM に送ってよい・
書き換えてよいことを **一切意味しない**。エイリアスのパスは現 PC に実在しなくてよい
設計なので、特に「alias match = 読取り可」としてしまうと、存在しないパスや別環境の
パスに対して権限を与える穴になる。

## 三層の区別

混同してはならない 3 つの層がある。

| 層 | 目的 | 例 | 権限判定に使うか |
|---|---|---|---|
| PhysicalPath | 現 PC で実際に開く実体パス | `F:\Dropbox\On Work\a.nb` | 使う。ただし現 PC で解決・実在確認済みの場合のみ |
| SymbolicPath / PathRef | 複数 PC 間で同じ論理ファイルを指す | `{"$onWork", "a.nb"}` | 単独では使わない (identity 専用) |
| SourceIdentity | ファイル内容・notebook 自体の同一性 | `SourceUUID` / `ContentHash` | アクセス可否ではなく同一性・再リンクに使う |

SourceVault は主に SymbolicPath と SourceIdentity を扱う。NBAccess は PhysicalPath を
必ず確認した上で、他の 2 層を補助情報として使う。claudecode / Claude Code settings は
PhysicalPath しか受け取れないので、実行直前にシンボリックパスから materialize する。

## 必須ルール

### 1. シンボリックパスを privacy 緩和の根拠にしない

`{"$onWork", ...}` に正規化できたことを `PrivacyLevel -> 0.5` の根拠にしてはならない。
ファイルアクセスの可否判定は必ず次の順で行う。

1. PathRef を現 PC の root registry で解決する。
2. 解決できなければ `PathResolutionStatus -> "RootMissing"`、アクセスは Deny または
   NeedsRelink とする。
3. 解決できても `FileExistsQ` / `DirectoryQ` で実在を確認する。
4. 実在する場合のみ access mode (`List` / `Read` / `ReadWrite`) と root policy を見る。
5. 内容をクラウド LLM に送る場合は、さらに `CloudSend` または notebook / cell の
   privacy 宣言を確認する。

### 2. alias は同一性照合のためだけに使う

`$SourceVaultCloudRootAliases` および root registry の `Aliases` は、別 PC 由来の
record を `{"$onWork", ...}` に正規化するためだけのものである。

- alias match は `IdentityMatch` / `RelinkCandidate` として扱う。
- authorization では現 PC の実体ルートへ解決できた path のみを使う。
- alias-only な path (`PathResolutionStatus -> "AliasOnly"`) は `settings.json` や
  `--add-dir` に **絶対に出力しない**。
- `RootMissing` の path も `settings.json` に出力しない。

### 3. read 権限と cloud-send 権限を分離する

「ローカルツール / Claude Code が読んでよい」と「内容をクラウド LLM に送ってよい」は
別の権限である。両者を同一視しない。

- `ReadableByAgent` — ローカル tool / Claude Code が read してよいか。
- `PrivacyLevel` / `CloudSendAllowed` — クラウド LLM に送ってよいか。

`$ClaudeAccessibleDirs` 配下であることは `ReadableByAgent -> True` の根拠にはなるが、
`PrivacyLevel -> 0.5` (クラウド送信可) の根拠にはしない。

### 4. NotebookRef 生成式は凍結する

Notebook store は `nb-src-*` ID をディレクトリ名・JSONL 名・review/lint record の
参照キーとして広く使う。`PathRef` (Association) の文字列化を ID 生成に混ぜると、
キー順序・`StringRiffle` 対象・fallback 表現の一文字差で全 ID が変わり、運用中の
ストアが全滅する。

- 既存 `iNotebookRefFromPath` / `iSVSymbolicPathString` の出力規則・順序・fallback を
  変えない。
- `PathRef` / `SymbolicPath` / `SourceUUID` / `ContentHash` は record の補助フィールド
  として追加するに留め、ID 生成式には入れない。
- ID 生成を本当に変える必要が出た場合は通常実装ではなく **store migration project**
  として扱い、旧 ID → 新 ID 対応表・dry-run・rollback・全参照書換え検証を必須にする。

## 関連

- 詳細設計は `nbaccess_sourcevault_cross_pc_path_policy` 文書を参照。
- ストア書き込みの非破壊原則は rule 103 を参照。
- パス操作は Wolfram 標準関数優先 (rule 50)。ただし cross-PC matching key 生成
  (大文字小文字無視・`/` `\` 統一・alias prefix 照合) は専用関数
  (`iSVPathMatchKey` / `NBPathMatchKey`) に閉じ込め、単体テストを必ず付ける。
