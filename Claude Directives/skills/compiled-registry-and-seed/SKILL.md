---
name: compiled-registry-and-seed
description: |
  SourceVault.wl Stage 6b の Compiled Registry + Seed bootstrap 設計。
  SourceVaultLookup / SourceVaultResolve / ClaudeResolveModel 互換 wrapper、
  seeds/<topic>-seed.json と compiled/<channel>/<topic>.json の 2 階建てストレージ、
  channel 分離 (public / private)、Availability/Freshness/Class の優先順位 sort、
  AllowSeed -> False で厳格モード、Stage 1 旧定義 (in-memory) 削除の経緯、
  iModelSeedEntries による自動 bootstrap (claudecode/anthropic/openai/lmstudio 6 entries)、
  仕様書 §4.5 / §5.4 / §8.1 / §11 / §14.10 の最小実装。
---

# Compiled Registry + Seed 設計 (Stage 6b)

「LLM や workflow から model resolve したい。低遅延・非ネットワーク・非 LLM で動くべき。public
は team 共有、private は user override に分離したい」を最小実装で実現する設計。

これで **SourceVault Phase 1 のコア機能が完成** する。

## 2 階建てストレージ

```
<PrivateVault>/
  seeds/
    model-registry-seed.json    # bootstrap 用、パッケージロード時に自動生成
    <topic>-seed.json
  compiled/
    public/
      model-registry.json       # production data、team 共有
      mathematica-graph-options.json
      ...
    private/
      model-registry.json       # user routing override
      ...
```

**ロード時自動 bootstrap**: 初回 `<<SourceVault.wl` で `iBootstrapDefaultSeeds[]` が呼ばれ、
`seeds/model-registry-seed.json` が存在しなければ `iModelSeedEntries[]` の 6 entries で作る。

```
claudecode/extraction → claude-sonnet-4-6  (Heavy-Local)
claudecode/code-heavy → claude-opus-4-7    (Heavy-Local)
anthropic/heavy       → claude-opus-4-7    (Heavy-Cloud)
anthropic/extraction  → claude-sonnet-4-6  (Heavy-Cloud)
openai/heavy          → gpt-5              (Heavy-Cloud)
lmstudio/extraction   → qwen-local         (Light-Local)
```

## Lookup ロジック

```
1. compiled/<channel>/<topic>.json を最初に検索
2. 見つからなければ AllowSeed -> True なら seeds/<topic>-seed.json に fallback
3. 複数 match なら Availability/Freshness/Class で sort、先頭 1 件を返す
4. 0 件なら Missing["NotFound"]
```

**仕様書 §2.5** の通り「seed は production truth ではなく、bootstrap 時の最小値」。
production 環境では compiled registry を必ず作って、`AllowSeed -> False` で seed fallback を
禁止できる。

## Resolve 優先順位 (sort 順、仕様書 §4.5)

```
sortBy(entry) = {
  Availability:   Available(0) > Deprecated(1) > Unknown(2) > Other(3),
  Freshness:      Fresh(0) > Stale(1) > Expired(2) > Unusable(3),
  Class:          Heavy-Cloud(0) > Heavy-Local(1) > Light-Cloud(2) > Light-Local(3)
}
```

`Availability == "Unavailable"` は最初の段階で除外。

実装:

```mathematica
iRegistryResolveOrder[entry_Association] :=
  Module[{availOrder, freshOrder, classOrder},
    availOrder = Switch[Lookup[entry, "Availability", "Unknown"],
      "Available", 0, "Deprecated", 1, "Unknown", 2, _, 3];
    freshOrder = Switch[Lookup[entry, "Freshness", "Unknown"],
      "Fresh", 0, "Stale", 1, "Expired", 2, "Unusable", 3, _, 4];
    classOrder = Switch[Lookup[entry, "Class", "Unknown"],
      "Heavy-Cloud", 0, "Heavy-Local", 1,
      "Light-Cloud", 2, "Light-Local", 3, _, 4];
    {availOrder, freshOrder, classOrder}
  ];
```

`SortBy[candidates, iRegistryResolveOrder]` で適切な順序になる。

## Query Match Logic

`iRegistryEntryMatchesQuery` の 2 つのモード:

```mathematica
(* 文字列キー: ModelId / Key / Name のいずれかが一致 *)
SourceVaultLookup["model-registry", "claude-opus-4-7"]

(* Association: 全キーが entry と一致 (List なら MemberQ) *)
SourceVaultLookup["model-registry",
  <|"Provider" -> "anthropic", "Intent" -> "heavy"|>]
```

```mathematica
iRegistryEntryMatchesQuery[entry_Association, query_] :=
  Which[
    StringQ[query],
      Or[Lookup[entry, "Key"]    === query,
         Lookup[entry, "ModelId"] === query,
         Lookup[entry, "Name"]    === query],
    AssociationQ[query],
      AllTrue[Normal[query], Function[rule,
        Module[{ev = Lookup[entry, First[rule], Missing["NotPresent"]]},
          Which[
            ListQ[ev], MemberQ[ev, Last[rule]],
            True, ev === Last[rule]]]]],
    True, False
  ];
```

**ポイント**: query が List 値 (`"Capabilities" -> "Vision"` のように 1 要素チェック) のとき、
`MemberQ` で要素一致を見る。これで `entry["Capabilities"] = {"Reasoning", "Code", "Vision"}` を
含む entry を `<|"Capabilities" -> "Vision"|>` で探せる。

## channel 分離 (仕様書 §11 / §14.10)

```
public registry:
  - public / official source からのみ
  - team / project 全体で共有
  - cloud LLM に渡しても安全

private registry:
  - user local configuration, private notebook 由来
  - 名前空間を public と完全分離
  - cloud mirror に出さない (将来 Phase 2 で lint)
```

`SourceVaultCompileRegistry[topic, entries, "Channel" -> "private"]` で private 側に保存。
`SourceVaultResolve[..., "Channel" -> "private"]` で読み出す。

**Phase 2 で必要**: `private/<topic>.json` を作るときに、含まれる entry の Sources (claim id)
を辿って `Confidentiality != "Public"` なら警告する lint。

## ClaudeResolveModel — 互換 wrapper

仕様書 §5.4 で「旧 `WikiDBResolveModel` の置き換え」と明記:

```mathematica
ClaudeResolveModel[provider_String, intent_String] :=
  SourceVaultResolve["Model",
    <|"Provider" -> provider, "Intent" -> intent|>];
```

**戻り値の違い** (Stage 1 旧定義との互換性):

| API | 旧 Stage 1 | 新 Stage 6b |
|---|---|---|
| `ClaudeResolveModel` | `_String` (ModelId only) | `_Association` (entry 全体) |
| 戻り値 | `"claude-opus-4-7"` | `<|... "ModelId" -> "claude-opus-4-7" ... \|>` |

caller が `r["ModelId"]` で取り出すコードに統一されている前提。旧 Stage 1 の挙動が必要なら
`ClaudeResolveModel[...]["ModelId"]` と書く。

## Stage 1 旧定義削除の経緯

Stage 1 で in-memory 最小スケルトンを実装していた:

```mathematica
SourceVaultResolve["Model", query_Association, opts:OptionsPattern[]] := Module[...]
SourceVaultResolve[kind_String, query_, opts___] := <|"Status" -> "Failed", ...|>
SourceVaultLookup[topic_String, key_, opts___] := Which[...]
ClaudeResolveModel[provider_String, intent_String] := r["ModelId"]
```

これらは Stage 6b 新規定義と **パターンマッチ衝突**。Wolfram は `"Model"` のような定数パターンを
より specific として優先するため、Stage 6b 新版が呼ばれない問題があった。

**対処**: Stage 1 の本体定義を全て削除 (L1267-1323)、Stage 6b の新版に統一。helper
(`iCompiledLookupModel`, `iSeedLookupModel`, `$SourceVaultSeedModelRegistry`) は将来 deprecate
予定で当面残す (まだ他コードが参照していないかどうかは未確認)。

usage 文字列は重複 (L108-116 旧 + L353-401 新) しているが、Wolfram は後勝ちで上書きされるので
動作上の問題はなし。

## 罠カタログ対応 (Stage 6b 実装で踏んだもの)

| # | 罠 | 状況 |
|---|---|---|
| #11 | `\uXXXX` 文字列リテラル | **380 件混入** → 一括修正。累計 841 件 (Stage 6c 72 + 8 295 + 6d 94 + 6b 380)。**最大の継続的エラー源、依然 4 回目の reincidence** |
| #11 補足 | `\:` 後 4 桁 hex 未満 | 今回は 0 件 (Stage 6d で実害発生済み、対策有効) |
| 既存衝突 | Stage 1 旧定義との重複 | 削除して統一 |
| #15 | Map + Function + Return | 該当なし |
| #16 | Quiet@Check | 全箇所 `Quiet[expr]` 単独 |
| #20 | Windows `ReadList` | `iLoadRegistryEntries` も `ReadByteArray` 経路 |

## チェックリスト

- [ ] `iSanitizeForJSON` を save 前に必ず呼ぶ
- [ ] `iEnsureRoots[]` を全 Stage 6b public API の冒頭で呼ぶ
- [ ] `iBootstrapDefaultSeeds[]` も冒頭で呼ぶ (毎回呼んでも冪等)
- [ ] `\u` ではなく `\:` で Unicode 文字エスケープ (罠 #11、累計 841 件)
- [ ] `\:` の後は **必ず 4 桁** hex (罠 #11 補足、§ → `\:00a7`)
- [ ] Stage 1 旧定義と衝突しないことを確認 (今回確認済み)
- [ ] Lookup/Resolve の戻り値に `ResolvedFrom` ("compiled" | "seed") を含める
- [ ] channel パラメータを全 public API でサポート
- [ ] AllowSeed のデフォルトを True に
- [ ] sort 順は Availability > Freshness > Class

## Phase 2 / Phase 3 ロードマップ

**Phase 2**:

- `SourceVaultCompileFromClaims[topic, schema]` — ClaimStore から entries を集約して自動 compile
- channel lint (`Confidentiality != Public` の entry が public/ に混入していないか)
- cloud-safe projection の materialize (`CloudMirror/compiled/public/`)
- revision history (`@rev-...` semantics、仕様書 §24.5)

**Phase 3**:

- WorkflowRegistry / PromptRegistry (仕様書 §22.7)
- compiled vs seed の lint チェック (差分が大きいなら warning)
- registry の audit trail (event log との統合)

## 仕様書との対応

| 仕様書節 | Phase 1 実装状況 |
|---|---|
| §2.5 seed registry の原則 | ✓ seed は bootstrap 用最小値、production truth ではない |
| §4.5 Compiled Registry Entry | ✓ Availability/Class/Capabilities/Freshness/Sources/PolicySource |
| §5.4 Lookup / Resolve / ClaudeResolveModel | ✓ 仕様通り |
| §8.1 Registry lookup の性質 | ✓ 非 LLM、非ネットワーク、高速 |
| §11 物理配置 (public/private 分離) | ✓ channel オプション |
| §14.10 privacy rule | △ channel 分離は ✓、lint check は Phase 2 |
| §24.5 Lookup semantics (channel/revision) | △ channel は ✓、revision は Phase 2 |

---

# モデルレジストリ動的更新 (次フェーズ, 2026-05-22)

compiled model registry をネットの実エンドポイントから更新する仕組み。Stage 6b の `model-registry.wl` を、cloud / local の生きたエンドポイントから取得したモデル一覧で更新する。

## 公開シンボル

- `$SourceVaultModelEndpoints` — provider 名 → エンドポイント設定の Association。ユーザー上書き可能 (LM Studio のポート等は環境依存)。各値は `<|"ModelsURL" -> _, "Kind" -> "Cloud"|"Local", "AuthProvider" -> _|>`
- `SourceVaultModelEndpointStatus[]` — 各 provider エンドポイントの到達性 (オフライン検知)。短いタイムアウトで probe し、401/403 が返っても「サーバー到達 = Online」とみなす
- `SourceVaultDetectLocalModels[opts]` — ローカル LLM サーバー (LM Studio 等、OpenAI 互換 `/v1/models`) からモデル一覧を推測
- `SourceVaultRefreshModelRegistry[opts]` — cloud + local からモデル取得し compiled registry にマージ更新

## 設計の核心

- **API キーは NBAccess の管轄** — cloud は `NBAccess`NBGetAPIKey[provider]`、local は `NBAccess`NBGetLocalLLMAPIKey[provider, url]` 経由でのみ取得する。SourceVault は `SystemCredential` も生キー文字列も一切触らない (rule 20)。`NBGetLocalLLMAPIKey` は `AccessLevel >= 1.0` 必須なので `PrivacySpec -> <|"AccessLevel" -> 1.0|>` を明示して呼ぶ (`iSVResolveLocalKey` ヘルパ)
- **ローカル endpoint は `$ClaudePrivateModel` を優先** — `iSVResolveLocalEndpoint` が (1) 呼び出し側の明示 Endpoint → (2) `ClaudeCode`$ClaudePrivateModel` の url (provider が一致する場合) → (3) `$SourceVaultModelEndpoints` の設定、の順で解決。`$ClaudePrivateModel` は `{provider, model, url}` のタプル。LM Studio を別ホストに置いていても追従する。`$ClaudePrivateModel` は `Symbol["ClaudeCode`$ClaudePrivateModel"]` 経由で読む (claudecode.wl への hard dependency を作らない)
- **エンドポイント URL は構造化データ** — モデルの枝番 (具体的な model id) はハードコードしない (rule 02) が、エンドポイント URL は設定データなので `.wl` の `$SourceVaultModelEndpoints` に持つ。model id は live エンドポイントまたは seed registry 由来
- **auto-fetch エントリのマージ** — 取得したエントリは `Source -> "auto-fetch"` でマーク。`iSVMergeModelRegistry` が既存の seed / manual エントリは温存し、auto-fetch 同士は `{Provider, ModelId}` で置換
- **`URLRead` に `TimeConstraint` オプションは無い** (罠 #53) — `TimeConstrained[URLRead[req], 秒, $Failed]` で囲む。`URLRead` は format 指定なしで呼び `HTTPResponse` を受け、`["StatusCode"]` / `["Body"]` で取り出す。Body が文字列でなければ `BodyByteArray` + `ByteArrayToString` でフォールバック

## 残課題

- 取得モデルの `Class` (Heavy/Mid/Light) と `Intent` は API から判別できず `Unknown` / `Null`。Intent ベース lookup (`iCompiledLookupModel`) に乗せるには分類ステップが必要
