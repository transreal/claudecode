---
paths:
  - "**/SourceVault_webingest.wl"
  - "**/SourceVault_mcp.wl"
  - "**/SourceVault_servicemanager.wl"
  - "**/SourceVault_core.wl"
  - "**/sourcevault*searxng*.md"
  - "**/sourcevault*mcp*.md"
---

# 105 — SourceVault Web 検索 / SearXNG / MCP サブシステム規約

## 背景

SourceVault は LM Studio の web 検索を Exa から「ローカル SearXNG → SourceVault →
MCP」ゲートウェイに移行した。実装は次のファイルに分かれる。

```text
SourceVault_core.wl         root registry / 不変 snapshot / blob (content-addressed) 基盤
SourceVault_webingest.wl    SearXNG client / WebSearch / 本文取得 / clean-text /
                            job 二層 / 参照イベント / WebSearchRun / importance
SourceVault_mcp.wl          MCP tool schema / dispatch (initialize/tools-list/tools-call)
SourceVault_servicemanager.wl  detached service 起動 / Python proxy ($proxyPySource) /
                            file command queue / dispatch verb
```

設計は `ドキュメント/sourcevault_searxng_mcp_spec_v6.md` と各レビュー
(`sourcevault_searxng_mcp_spec_vN_review.md`) を正とする。このルールは
そのサブシステムを壊さないための必須規約である。

## 必須ルール

### 1. service-loadable ファイルは FrontEnd / NBAccess に依存しない

`SourceVault_webingest.wl` と `SourceVault_mcp.wl` は **detached な headless
WolframScript service kernel で読み込まれる**。FrontEnd / Notebook / NBAccess /
UI / ユーザ対話に依存するコードを入れてはならない。root 解決は core の
`SourceVaultRoot["..."]` / `SourceVaultStorageDir[...]` を使い、
`SourceVault.wl` 本体の private helper (`iRawDir` 等) を呼ばない。

### 2. 2つのローダを両方更新する

service-loadable な `SourceVault_*.wl` を追加・改名したら、**2箇所**を更新する。

1. **main kernel ローダ**: `SourceVault.wl` 末尾の明示 `Get[]` リスト。
2. **service kernel ローダ**: `SourceVault_servicemanager.wl` の `iGenRunWls` が
   生成する `run.wls` の package list (現状 core/searchindex/servicemanager/
   webingest/mcp を FileExistsQ ガード付きで `Get`)。

片方だけ更新すると、main では動くが service では未定義関数で落ちる
(逆も然り)。これは依存監査で最初に確認すべき点だった (review W1/X1)。

### 3. 可変メタは不変 snapshot に入れない

content-addressed の不変 snapshot (`SourceVaultSaveImmutableSnapshot`) は
digest で一意。`Priority` / `ReferenceEvents` / `CurrentImportance` のような
**更新される値を snapshot 本体に入れない** (更新のたびに別 snapshot が
増殖する)。不変事実 (url / hash / clean-text ref / provenance / 検索時刻) は
snapshot、可変メタは LocalState の sidecar / append-only log に置く。

- **要約等の派生成果物** (`SourceVaultSaveDerivedArtifact`, ObjectClass `DerivedArtifact`) は逆に
  **不変事実**側の例。「時刻 T にモデル M が source [...] から生成した」結果なので生成のたびに別
  snapshot で正しい (content-addressed)。SourceRefs 経由で source レコードに `Summarized` 参照イベントを
  emit し、要約された source の importance を底上げする (#1/#2 と連携)。`SourceVaultSummarizeText`/
  `SummarizeResults` の `"Persist" -> True` で保存し (Succeeded 時のみ; 空/失敗は保存しない)、
  逆引きは `SourceVaultDerivedArtifactsForSource[recordId]`。
- **WebDocument の構造 Priority** (`SourceVaultWebComputePriority`, mail の `Derived.Priority`
  に対応する provenance ベース初期推定) はこの規約の具体例。Priority は formula / ドメイン重みの
  変更で更新されるので **不変 snapshot には入れず** `<LocalState>/derived/web_priority/<recordId>.json`
  sidecar に置く (recordId = snapshot Ref)。`SourceVaultWebFetch` が取込時に書き、
  `SourceVaultWebRecomputePriorities[]` が既取込分を snapshot の `IngestProvenance` から一括再計算する
  (mail の `SourceVaultMailRecomputePriorities` と同型)。ソースドメイン重みは mail のグループ重みと
  同様に vault config (`PrivateVault/config/web_domain_weights.json`、`SourceVaultSetWebDomainWeight`)
  に永続化する。`SourceVaultWebImportance[recordId]` が構造 Priority と使用ベース
  `SourceVaultRecordImportance` を `CombinedScore` に合成する。
  per-result の rank/score/engine/domain は `iWebResultProvenance` が fetch 時の provenance に載せる。

### 4. hot data は LocalState (Dropbox 非同期) に置く

高頻度 append / update されるデータは `SourceVaultRoot["LocalState"]`
(既定 `%LOCALAPPDATA%/SourceVault`、Dropbox 非同期) に置く。

```text
<LocalState>/jobs/                       job state
<LocalState>/hotlog/reference_events/    参照イベント (YYYY-MM.jsonl, append-only)
<LocalState>/hotlog/reference_events/.rollup-watermark.json  rollup 済み行数 (per shard)
<LocalState>/derived/web_priority/       WebDocument 構造 Priority sidecar (<recordId>.json)
<LocalState>/secrets/                    MCP token 等
<PrivateVault>/config/web_domain_weights.json  ソースドメイン重み (vault config, 同期)
<CoreRoot>/rollup/reference_events/<host>/  参照イベント rollup (Dropbox 同期・クロスマシン)
```

不変 snapshot / blob は CoreRoot (`SourceVaultStorageDir`、PrivateVault 配下)。

- **参照イベントの rollup** (`SourceVaultRollupReferenceEvents`): 参照イベントは machine-local の
  LocalState に append されるため、別マシンの履歴が見えず backup されない。rollup は **低頻度バッチ**で
  未集約分を `<CoreRoot>/rollup/reference_events/<host>/` へ追記し、(1) クロスマシンで importance を合算、
  (2) 耐久化する。**per-event でなくバッチ追記**なので同期負荷は低い (バッテリーノート配慮)。
  追記のみ・非破壊。読み手 `iWebReadReferenceEvents` は local ∪ rollup(全 host) を **EventId で dedup**
  して読む (local と自 host rollup の同一イベントを二重計上しない; legacy イベントは内容ハッシュ fallback)。
  service heartbeat ループが `$SourceVaultRollupIntervalSeconds` (既定 6h) 間隔で自動実行する
  (反映には service 再起動が必要, §8)。local hot ログの肥大は `SourceVaultPruneRolledReferenceEvents`
  (破壊的なので DryRun 既定 True, rollup に同数以上在ることを確認した古い shard のみ削除) で抑える。
runtime (pid/heartbeat/commands) は既存どおり `<CoreRoot>/runtime/`。
**package directory (`$packageDirectory` / `SourceVault_info/`) に runtime /
hot / secret を置かない** (GitHub 配布・Dropbox churn に混入する)。

### 5. JSON 化するレコードは JSON 安全にする

job / snapshot / MCP result / 参照イベントは JSON 化されて
file command queue / proxy / core store を流れる。`None` / `DateObject` /
`Missing[...]` は RawJSON で壊れるか不正値になる。**保存前に `iWebJSONSafe`
(None/Missing → Null, DateObject → ISO) を通す**。タイムスタンプは最初から
ISO 文字列 (`iWebNowIso[]`) で持つ。`ImportByteArray` の HTML 抽出は
**2 引数リスト形** `ImportByteArray[bytes, {"HTML", "Plaintext"}]` を使う
(3 引数形は無効。headless で動く形)。

### 6. 非 2xx fetch を成功保存しない

URL 取得が 401/403/404/5xx を返したら、bot ブロックや paywall の
スタブ本文を `ExtractionStatus -> "Succeeded"` で保存してはならない。
`FetchFailed` (reason `HTTP <code>`) にし、`Ingested` 参照イベントは
抽出成功時のみ emit する。

### 7. MCP の protocol endpoint は Python proxy 側

`SourceVault_mcp.wl` は MCP の **tool schema 定義・dispatch・provenance
付与の WL 補助ライブラリ**であり、protocol endpoint ではない。実際の
HTTP / JSON-RPC は `SourceVault_servicemanager.wl` の `$proxyPySource`
(Python stdlib, SHA256 pin) の `POST /sv/mcp` が担い、`"MCP"` command verb
として file command queue 経由で `SourceVaultMCPDispatch` を呼ぶ。

- **`$proxyPySource` を編集したら**、Python は全シングルクォート・
  バックスラッシュ無し (WL `"..."` 内に収める) を維持し、`py_compile` で
  検証し、必要なら `SourceVaultPublishProxyCodeSnapshot[]` で再 publish する
  (materialize は SHA256 を fail-closed 検証する)。
- MCP token は LocalState/secrets に置き、LM Studio 側は `mcp.json` の
  `headers` (`X-SourceVault-Token`) で渡す。token を package dir / GitHub に
  置かない。
- **要約用 LM Studio token も同様**: main kernel では claudecode/NBAccess から live 解決
  (`iWebSummaryToken`)。service kernel は NBAccess 不在なので解決できない。
  `SourceVaultStoreSummaryToken[]` で **LocalState/secrets/sourcevault-summary-token.json**
  (非 Dropbox) に永続化すると、service kernel は注入済み LocalState root 経由でこのファイルを
  読んで解決する。**token を run.wls に直書きしない** (run.wls は CoreRoot=Dropbox 配下のため)。
  関数の戻り値・ログに token 文字列を出さない (rule 20)。

### 7b. exa ⇄ SourceVault backend 切替は SourceVaultModelIntegrations 経由 (claudecode 無変更)

claudecode の `iResolveLMStudioIntegrations` は `Names["SourceVault`SourceVaultModelIntegrations"]`
を soft probe する package-neutral hook を持つ (claudecode は SourceVault に依存しない)。
exa→SourceVault の切替は **claudecode を変更せず**、SourceVault 側の
`SourceVaultModelIntegrations[provider, modelId]` の返り値に
`SourceVaultSwapWebSearchBackend` (webingest) を適用して実現する。

- SearXNG 可用 (`SourceVaultSearXNGAvailableQ[]`, 60s キャッシュ) なら web 検索 backend を
  `$SourceVaultWebSearchIntegrationId` (既定 "mcp/sourcevault") に、不可なら
  `$SourceVaultExaFallbackIntegrationId` (既定 "mcp/exa") にそろえる。**SearXNG が無い環境では
  exa に後方互換フォールバック**する。
- claudecode の解決順は explicit 引数 > `$ClaudeLMStudioIntegrations` (global) > 上記 hook。
  global を None にすると hook (=自動切替) が効く。global path で切替したいなら
  `ClaudeCode`$ClaudeLMStudioIntegrations := SourceVault`SourceVaultWebSearchIntegration[]`。
- plugin ID はソースにハードコードせず settable global の既定値で持つ (rule 02)。

### 7c. MCP サーバの起動/停止とパレットトグル (claudecode 無変更)

MCP サーバは **WL service (カーネル) + HTTP/MCP proxy (Python)** の二段。便利ラッパー:

- `SourceVaultStartMCP[opts]` — WL service を確保し `/sv/mcp` を公開する proxy を起動。
  `SourceVaultStopMCP[]` / `SourceVaultMCPRunningQ[]` / `SourceVaultMCPStatus[]`。
- 既定は settable global: `$SourceVaultMCPServiceId` ("sv-main") / `$SourceVaultMCPPort` (8731) /
  `$SourceVaultMCPToken` (None=localhost 無認証)。**ポート等の環境依存値はソースに直書きせず global 既定で持つ** (rule 02/03)。
- **パレットトグル**: claudecode の `ShowClaudePalette` プライバシー直下に起動/停止トグルを出す。
  これは **claudecode 側の package-neutral レジストリ `$ClaudePaletteServiceControls`**
  (`ClaudeRegisterPaletteServiceControl`) に SourceVault が `SourceVault_servicemanager.wl` ロード時
  soft-probe (`Names[...]`) で登録する形 (rule 11: claudecode は SourceVault を一切参照しない;
  `$ClaudePackageKeywordMap` と同じ流儀)。ラベル文字列・起動/停止/状態判定コールバックは全て
  SourceVault 側が供給する。トグルのラベルは `SourceVaultMCPRunningQ[]` の実状態に追従する
  (TTL キャッシュ + UpdateInterval)。新規登録を既存パレットに反映するには `ShowClaudePalette[]` を再実行。

### 8. 稼働中サービスはコード変更で自動更新されない

detached service kernel は**起動時のコード**を保持する。`.wl` を編集しても
稼働中サービスには反映されない。反映には
`SourceVaultRestartService["<serviceId>"]` が必要。LM Studio 経由の挙動を
変えたら、必ずサービスを再起動してから確認する。

同様に root も**起動時の注入値** (`$SourceVaultInjectedRoots`, run.wls 焼き込み) を保持する。
`SourceVaultSetRoot` で main の root を変えても稼働中 service には反映されない。
`SourceVaultServiceRootHealth["<serviceId>"]` で **service と main の root hash 一致・
実行ユーザ一致・LocalState 書込み可否**を検査でき、不一致なら Warnings を返す
(service は pid.json に `User` / `InjectedRootHash` を self-report する)。
RootHashMismatch が出たら `SourceVaultRestartService` で再注入する。

### 9. upload_manifest.json 更新義務

新しい `SourceVault_*.wl` を追加したら `SourceVault_info/upload_manifest.json`
の `files[]` に含める (`github.wl` が `SourceVault_*.wl` を glob 自動追記
するが、static manifest としても正しく保つ)。`excludePatterns[]` に
runtime / cache / local / secrets を残す。実装上、service entry point は
実行時に `run.wls` を動的生成する方式のため、配布対象の `.wls` は無い
(spec §18 の `SourceVault_info/wolframscript/SourceVaultService.wls` は
本実装では生成しない)。

## チェックリスト (web/MCP サブシステムを触ったら)

- [ ] service-loadable ファイルが FrontEnd/NBAccess 非依存か
- [ ] 新 `SourceVault_*.wl` を main ローダと iGenRunWls の両方に追加したか
- [ ] 可変メタを不変 snapshot に入れていないか (sidecar/LocalState か)
- [ ] hot/secret/runtime を package dir 外 (LocalState/CoreRoot) に置いたか
- [ ] JSON 化レコードを iWebJSONSafe / ISO 時刻にしたか
- [ ] 非 2xx を FetchFailed にしているか
- [ ] proxy 編集後に py_compile + (必要なら) 再 publish したか
- [ ] コード変更後にサービスを再起動して確認したか
- [ ] upload_manifest.json に新ファイルを追加したか

## 関連

- `ドキュメント/sourcevault_searxng_mcp_spec_v6.md` — 確定仕様
- `ドキュメント/sourcevault_searxng_mcp_spec_v*_review.md` — レビュー (W1/X1/B1 等)
- `rules/101-sourcevault-stage-status.md` — ストアレイアウト・暗号化・identity
- `rules/103-sourcevault-datastore-safety.md` — データストア書き込み安全
- `rules/95-scheduled-task-safety.md` — detached service / schtasks
