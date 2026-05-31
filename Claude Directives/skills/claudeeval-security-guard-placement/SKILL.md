---
name: claudeeval-security-guard-placement
description: |
  ClaudeEval / ClaudeQuery にセキュリティ・プライバシーのガード (クラウド送信拒否、
  Private ノートブック保護、機密チェック等) を追加するときの正しい配置位置。
  $UseClaudeRuntime=True で Runtime Bridge 経由になるとガードを通らない落とし穴、
  dispatch (PromptRouter/Orchestrator hook) より前に置く必要性を扱う。
  Stage 9 P1.5 の Private ノートブック保護で実装・実証済み。
---

# ClaudeEval セキュリティガードの配置

## 問題: 経路が複数あり、内側に置くとバイパスされる

`ClaudeEval[task]` は単一の実装に直行しない。少なくとも次の分岐がある:

1. `$UseClaudeRuntime = True` → **Runtime Bridge** (`iClaudeEvalViaRuntimeBridge`) 経由になり、`iClaudeEvalImpl` を通らない。
2. PromptRouter / Orchestrator hook (`iClaudeEvalTryDispatch`) が前段で task を横取りする。
3. 上記に当てはまらない通常パス。

ガードを `iClaudeEvalImpl` の中など**内側**に置くと、(1)(2) の経路では実行されず**バイパスされる**。「テストでは効いたのに本番 ($UseClaudeRuntime=True) で漏れる」典型パターン。

## 鉄則: Deny は最前段、Substitute は共通入口

- **拒否 (Deny) 系チェックは `ClaudeEval[task_String]` の最冒頭** (paidGuard の直後・dispatch より前) に置く。全経路をカバーする唯一の位置。
  - 例: Private ノートブック + クラウドモデル指定 → `iClaudeEvalPrivacyGuard[nb, modelSpec]` が `<|Action -> "Deny", ...|>` を返したら、`nbPrint` で理由を出して `Return[$Failed]`。
- **差し替え (Substitute) 系** (Model 無指定 → `$ClaudePrivateModel` に置換するなど) は、全経路が必ず通る共通入口 (`With` で実効モデル `effMdl` を決める箇所) で処理する。

```mathematica
ClaudeEval[task_String, opts:OptionsPattern[]] :=
  Module[{...},
    (* 1. paidGuard *)
    ...
    (* 2. ★ ここに Deny ガード (dispatch より前) *)
    With[{nb = iUserNotebook[], mdl = OptionValue[Model]},
      Module[{g = iClaudeEvalPrivacyGuard[nb, mdl]},
        If[Lookup[g, "Action"] === "Deny",
          nbPrint[nb, "⛔ " <> Lookup[g, "Reason"]];
          Return[$Failed]]]];
    (* 3. dispatch (PromptRouter / Orchestrator) *)
    (* 4. Runtime Bridge or 通常パス *)
    ...
  ];
```

## 検証

新しいガードを足したら、必ず次の 2 条件で発火を確認する:
- `$UseClaudeRuntime = True` (Runtime Bridge 経由)
- `$UseClaudeRuntime = False` (通常パス)

両方で Deny が効けば配置は正しい。片方だけだと内側に置いている疑い。

## 関連

- `rules/10-nbaccess.md`: PrivacyLevel と Private ノートブック宣言、provider AccessLevel。
- 過去セッション要約のトラップ: 「$UseClaudeRuntime=True で ClaudeEval は Runtime Bridge 経由になり iClaudeEvalImpl のガードを通らない。dispatch も前段。セキュリティガードは ClaudeEval[task] 最冒頭に置く」。
