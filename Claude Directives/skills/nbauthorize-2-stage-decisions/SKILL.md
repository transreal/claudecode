---
name: nbauthorize-2-stage-decisions
description: |
  SourceVault.wl Stage 6d の NBAuthorize 2 段階統合設計。
  SourceVaultExtract に sendDecision (LLM 送出前) + persistDecision (claim 保存前) を組み込み、
  SourceVaultContext は RequireApproval も block する形に拡張。
  4 種 Decision (Permit/Screen/RequireApproval/Deny) の扱い、iSpecFromClaim による NBClaimSpec 生成、
  AccessLabel の元 source 継承、batch 判定 (代表 claim 1 件) の理由、
  "AuthorizationCheck" -> False の opt-out スイッチ (regression 回避)、
  レスポンス形式の AccessDecisions: <|"Send" -> _, "Persist" -> _|>、Phase 2 への伏線。
  仕様書 §14.4.1 / §14.4.2 の最小実装。
---

# NBAuthorize 2 段階統合設計 (Stage 6d)

「機密性の高い source から claim を抽出するときに、LLM に送る前と保存する前で
それぞれ NBAccess の判定を必ず通す」仕組みを最小コストで導入する設計。

## 2 段階 authorization のコアフロー

仕様書 §14.4.2 の通り `SourceVaultExtract` は次の 2 ポイントで NBAuthorize を呼ぶ:

```
   sourceSpan
       ↓
   [iSpecFromSnapshotMeta → iCallNBAuthorize] sendDecision
       ↓ (Permit/Screen のみ通す)
   SourceVaultContext で context 取得
       ↓
   LLM で claim 抽出
       ↓
   [iSpecFromClaim(First[claims]) → iCallNBAuthorize] persistDecision
       ↓ (Permit/Screen のみ通す)
   ClaimStore に保存
```

`SourceVaultContext` 内でも独自に NBAuthorize を呼ぶので、実質的には **3 段階** (Context 内 + send + persist) だが、send は schema/topic 込みの細かい判定で、Context 内は generic な ReadContext 判定。役割が違うので併存させる。

## 4 種 Decision の扱い

仕様書 §14.4.1 で定義:

| Decision | SourceVaultExtract | SourceVaultContext |
|---|---|---|
| `"Permit"` | 続行 | 続行 |
| `"Screen"` | 続行 (Phase 1 では Permit と同等。Phase 2 で redaction 実装) | 同上 |
| `"RequireApproval"` | `Status: "RequiresApproval"` で早期 return | `Status: "RequiresApproval"` で早期 return |
| `"Deny"` (or その他) | `Status: "DeniedByNBAccess"` で早期 return | `Status: "DeniedByNBAccess"` で早期 return |

実装は `Switch` の `_,` で Deny を catch-all にする:

```mathematica
Switch[Lookup[sendDecision, "Decision", "Deny"],
  "Permit" | "Screen", Null,       (* 続行 *)
  "RequireApproval",
    Return[<|"Status" -> "RequiresApproval", ...|>],
  _,
    Return[<|"Status" -> "DeniedByNBAccess", ...|>]
];
```

unknown decision を Deny 扱いにすることで、NBAccess の将来拡張で未知の値が返っても fail-safe。

## iSpecFromClaim — NBClaimSpec 生成

仕様書 §14.2.3 の Claim object spec を `Association` で構築:

```mathematica
iSpecFromClaim[claim_Association] :=
  Module[{sourceSpan, sourceId, snapshotId, snapshotMeta, label},
    sourceSpan = Lookup[claim, "SourceSpan", <||>];
    sourceId = Lookup[sourceSpan, "SourceId", ""];
    snapshotId = Lookup[sourceSpan, "SnapshotId", ""];
    (* AccessLabel は元 source の meta から派生 *)
    label = If[StringQ[snapshotId] && snapshotId =!= "",
      Module[{m = iSnapshotMetaLoad[snapshotId]},
        If[AssociationQ[m],
          iAccessLabelForSource[m],
          iAccessLabelForSource[<|"SourceType" -> "Unknown"|>]]],
      iAccessLabelForSource[<|"SourceType" -> "Unknown"|>]];
    <|
      "ObjectClass" -> "Claim",
      "ClaimId" -> Lookup[claim, "ClaimId", ""],
      "Topic" -> Lookup[claim, "Topic", ""],
      "Schema" -> Lookup[claim, "Schema", ""],
      "SourceId" -> sourceId,
      "SnapshotId" -> snapshotId,
      "ContentHash" -> Lookup[claim, "ContentHash", ""],
      "AccessLabel" -> label,
      ...
    |>
  ];
```

**ポイント**: claim 自体は AccessLabel を持たないが、**元 snapshot meta から `iAccessLabelForSource` 経由で派生** する。これにより:

- arXiv 由来の claim → `Confidentiality: "Public"`, `Origin: "ArXiv"`
- ローカル PDF 由来の claim → `Confidentiality: "Private"`, `Origin: "LocalFile"`
- maildb 由来 → `Confidentiality: "Private"`, `Origin: "UserMailbox"`

NBAccess は AccessLabel を見て persistDecision を返す。

## batch 判定の理由 (per-claim ではなく代表 1 件)

仕様書 §14.4.2 は「`extraction` の `claimObj` で NBAuthorize」と書かれており、各 claim に対して個別 authorize か batch かは明示なし。Phase 1 では **`First[claims]` を代表として 1 回だけ呼ぶ**:

```mathematica
If[authCheck && storeClaims && Length[claims] > 0,
  Module[{claimObj = iSpecFromClaim[First[claims]]},
    persistDecision = iCallNBAuthorize[claimObj, <|"Action" -> "PersistClaim", ...|>];
    ...
  ]];
```

**理由**:

- 同じ source から抽出された claim はすべて同じ AccessLabel を持つはず (元 snapshot が同じ → `iAccessLabelForSource` の結果が同じ)
- typical N = 30-50 件の claim に対して個別 authorize は冗長
- per-claim 判定が必要な場合は caller が SourceVaultExtract を skip して直接組める

Phase 2 で「claim ごとに異なる AccessLabel」が必要になったら per-claim 判定に拡張。

## "AuthorizationCheck" -> False の opt-out

Stage 6d ではデフォルト ON だが、regression 回避用に skip 可能:

```mathematica
SourceVaultExtract[span, "FreeText",
  "AuthorizationCheck" -> False]
```

このとき:

- sendDecision も persistDecision も呼ばれない
- `AccessDecisions: <||>` (空 Association)
- Stage 5/6a と完全に同じ挙動

**いつ False にすべきか**:

- 既存テストの regression を取りたいとき
- NBAccess が一時的に load されていない環境でのデバッグ
- バッチ処理で Stage 5 時代のスクリプトをそのまま動かしたいとき

**いつ True を維持すべきか**:

- 本番運用 (デフォルト)
- 機密 source を含む可能性がある任意の処理

## レスポンス形式

成功時 (Stage 5 のレスポンスに `AccessDecisions` フィールドを追加):

```mathematica
<|
  "Status" -> "OK",
  "SchemaName" -> _,
  "Topic" -> _,
  "Claims" -> {...},
  "Count" -> _Integer,
  "ExtractedCount" -> _Integer,
  "DedupSkipped" -> _Integer,
  "ValidationStatus" -> _,
  "ExtractedAt" -> _,
  "Errors" -> {...},
  "AccessDecisions" -> <|
    "Send"    -> <|"Decision" -> "Permit", "ReasonClass" -> _, ...|>,
    "Persist" -> <|"Decision" -> "Permit", "ReasonClass" -> _, ...|>
  |>,
  "BundleId" -> Missing["NotCreated"]
|>
```

`AuthorizationCheck -> False` のとき `AccessDecisions -> <||>` (空)。

Deny 時:

```mathematica
<|"Status" -> "DeniedByNBAccess",
  "Reason" -> "sendDecision: Deny",
  "ReasonClass" -> "...",
  "AccessDecisions" -> <|"Send" -> <|"Decision" -> "Deny", ...|>|>|>
```

RequireApproval 時 (persistDecision でブロックされた場合):

```mathematica
<|"Status" -> "RequiresApproval",
  "Reason" -> "persistDecision: RequireApproval",
  "Claims" -> {...},       (* 抽出は成功しているので claim は返す *)
  "Count" -> 0,            (* ただし store 0 件 *)
  "ExtractedCount" -> _,
  "AccessDecisions" -> <|"Send" -> _, "Persist" -> _|>|>
```

Claims を返すのは、approval 後に caller が手動で store するためのワークフローを想定。

## SourceVaultContext の RequireApproval 拡張

Stage 5 以前は Deny のみブロック。Stage 6d で RequireApproval も追加:

```mathematica
If[decision["Decision"] === "Deny",
  Return[<|"Status" -> "DeniedByNBAccess", ...|>]];

(* Stage 6d 追加 *)
If[decision["Decision"] === "RequireApproval",
  Return[<|"Status" -> "RequiresApproval",
    "AccessDecision" -> decision,
    "Reason" -> "Context retrieval requires approval"|>]];

(* Permit / Screen / unknown は続行 *)
```

`Screen` を unknown と一緒に「続行」扱いにしているのは Phase 1 の妥協。Phase 2 で `NBRedactExecutionResult` 呼出を入れる。

## SourceVaultBundleCreate の authorize は Phase 2

仕様書 §14.4 の表では `SourceVaultBundleCreate` も `CreateBundle` action で authorize すべきと書かれているが、Phase 1 では未実装。Phase 2 で:

```mathematica
SourceVaultBundleCreate[name, deps, opts] :=
  Module[{bundleObj, decision},
    bundleObj = iSpecFromBundleDeps[deps];  (* 新規 helper *)
    decision = iCallNBAuthorize[bundleObj,
      <|"Action" -> "CreateBundle", ...|>];
    If[decision["Decision"] =!= "Permit",
      Return[<|"Status" -> "DeniedByNBAccess", ...|>]];
    ...
  ];
```

理由: bundle が複数 source の集約物で、source ごとの AccessLabel が異なる場合に「最も制限の強い label を継承」するロジックが必要。これは Phase 2 の label propagation 設計と一緒にやる。

## 罠カタログ対応 (Stage 6d 実装で踏んだもの)

| # | 罠 | 状況 |
|---|---|---|
| #11 | `\uXXXX` 文字列リテラル | **94 件混入** → Python re.sub で一括修正。Stage 6c (72) + 8 (295) + 6d (94) = **累計 461 件**。最大の継続的エラー源 |
| #12 | nested Module Return scope | sendDecision/persistDecision の Switch 内 Return は外側 Module から抜ける ([SourceVaultExtract 全体]) — OK |
| #15 | Map + Function + Return | 該当なし |
| #16 | Quiet@Check | 全箇所 `Quiet[expr]` 単独 |

## チェックリスト

- [ ] 新規コード追加直後に `grep '\\u[0-9a-fA-F]\{4\}' SourceVault.wl` (罠 #11、最大の継続的エラー源)
- [ ] sendDecision で Schema/Topic/Purpose/Sink を渡す
- [ ] persistDecision で代表 claim を `First[claims]` で取る
- [ ] `Switch` の catch-all (`_,`) で unknown decision を Deny 扱い
- [ ] レスポンスの `AccessDecisions` を全 return path で含める
- [ ] `"AuthorizationCheck" -> False` で skip できることを確認
- [ ] Stage 5/6a/6c/8 のレスポンス形式と互換性を維持 (`AccessDecisions` 追加は追加のみ)

## Phase 1 (今) の制約

- `Screen` decision は Permit と同等扱い (redaction 未実装)
- `SourceVaultBundleCreate` / `BundleStatus` の authorize は未統合
- principal/sink の細かい指定は固定値
- per-claim authorize ではなく batch (First 1 件で代表)
- `SourceVaultIngest` / `SourceVaultAttach` の authorize は Stage 1.5/2 で実装済み (新規変更なし)

## Phase 2 / Phase 3 ロードマップ

**Phase 2**:

- `Screen` → redaction 実装 (`NBRedactExecutionResult` 呼出)
- `SourceVaultBundleCreate` / `BundleStatus` に authorize 追加 (label propagation と一緒)
- per-claim 判定オプション (`"AuthorizationGranularity" -> "Batch" | "PerClaim"`)
- principal/sink を caller から指定可能に (`"ExtractorSink" -> ...`)
- `SourceVaultResolve` / `SourceVaultLookup` の compiled registry entry に label 付与

**Phase 3**:

- declassification / release decision フロー
- approval place への自動投函 (Petri net 連携)
- audit trail (event log と統合)

## 仕様書との対応

| 仕様書節 | Phase 1 実装状況 |
|---|---|
| §14.4.1 SourceVaultContext authorization | ✓ Deny + RequireApproval block、Screen は Permit 扱い |
| §14.4.2 SourceVaultExtract 2 段階 | ✓ sendDecision + persistDecision (batch 判定) |
| §14.4.3 Resolve/Lookup | × Phase 2 (Stage 6b と一緒) |
| §14.4 表の他 action (CreateBundle, ResolveRegistry, ReleaseArtifact, Lint) | △ 未統合 (Phase 2) |
| §14.2.3 NBClaimSpec | ✓ `iSpecFromClaim` で生成 |
| §14.13 Migration plan | △ Phase 1 完了。Phase 2/3 は将来 |
