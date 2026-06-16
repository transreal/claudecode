---
name: runtime-confidential-automark
description: |
  Runtime ClaudeEval ($UseClaudeRuntime = True) が「無関係な/既存の/承認ボタン直後の
  セル」を confidential (pink 背景・PrivacyLevel 1.0) に誤マークする事故の診断と修正。
  原因は 2 つ: (1) auto-mark が dispatch 時 cell 数 + 位置範囲ベースで、非同期中に
  増えたセルや末尾セルを巻き込む。(2) ローカルモデルが accessLevel 1.0 で無条件
  autoMark → echo した良性コードセルを機密化 → 変数が機密化 → iPrecisionConfidentialCheck
  の依存スキャンが連鎖して無関係セルをマーク。ローカル light モデル使用時に頻発。
  機密マークの誤爆・variable taint cascade・iAutoMarkNewCellsConfidential の話。
---

# Runtime confidential auto-mark の誤爆 (as-built 修正, 2026-06-15)

`$UseClaudeRuntime = True` の `ClaudeEval[..., Model -> {"lmstudio", ...}]` 等で、
**無関係/既存のセルが機密化 (pink 背景・`"confidential" -> True`・`"privacyLevel" -> 1.`)** される事故。
特にローカル light モデル使用時。`iRuntimeDisplayResult` の auto-mark 経路に 2 つの独立した原因があった。

## 原因 1: 位置範囲ベースの auto-mark

`iAutoMarkNewCellsConfidential[nb, cellCountBefore]` は `[cellCountBefore+1 .. NBCellCount[nb]]`
を機密化する。`cellCountBefore` は **dispatch 時**の `meta["CellCountBefore"]`。非同期 runtime は
処理に時間がかかり、その間に**ユーザーが別セルを評価**したり、結果がジョブアンカー位置 (中盤) に
挿入されると、位置範囲が**無関係/末尾のセル**を指す。

**修正**: identity 差分の `iAutoMarkCellsAddedSince[nb, beforeCells]`。
`iRuntimeDisplayResult` の queue 実行 (`Scan[..., queue]`) **直前**に `beforeCells = Cells[nb]` を
スナップショットし、書き込み後に `Cells[nb]` との差分 = **今ターンが実際に書いたセルだけ**を機密化。
NBAccess の cell index は `Cells[nb]` 順序準拠 (`NBCellCount = Length[iResolveCells] = Length[Cells[nb]]`)
なので、`allCells[[idx]]` の位置 idx をそのまま `NBCellStyle[nb, idx]` / `NBMarkCellConfidential[nb, idx]`
に使える。

## 原因 2: ローカルモデルの無条件 autoMark → 機密変数連鎖 (主因)

- `iResolveAccessLevel[Automatic, {"lmstudio",...}]` = `NBGetProviderMaxAccessLevel["lmstudio"]` = **1.0**
  (ローカルは全アクセス可)。これは「モデルのアクセス上限」であって、その eval が機密かどうかではない。
- `iShouldAutoMarkConfidential[1.0]` = `1.0 > claudecode max` = **True** → 結果セルを無条件機密化。
- light モデルが文脈を echo して `m = {...}; ...` を提案 → そのコードセルが機密化される。
- `m` が**機密セル内で代入された変数**として `$confidentialSymbols` に昇格 (`iRebuildConfidentialSymbols`)。
- 次の `iPrecisionConfidentialCheck` が Step 4-6 で `NBTransitiveDependents` + `NBScanDependentCells` により
  **`m` に依存する全セルを機密化** → `m` を使う無関係セルが巻き込まれる (= 承認ボタン直後のセル等)。

つまり「ローカル = 無条件マーク」が良性変数を汚染し、**依存連鎖で波及**する。

**修正**: meta の `"AutoMark"` を `iShouldAutoMarkConfidential[accessLevel]` から
**`iShouldBlanketMarkConfidential[accessLevel, privSpec]`** に置換 (eval/continue 両 bridge)。

```mathematica
iShouldBlanketMarkConfidential[accessLevel_, privSpec_] :=
  TrueQ[iShouldAutoMarkConfidential[accessLevel]] &&
  (iSessionHasConfidentialContent[]                       (* 既存の機密変数/セルがある *)
   || (AssociationQ[privSpec] && TrueQ[Lookup[privSpec, "AccessLevel", 0] > 0.5]));  (* 明示 high-privacy *)
```

→ **クリーンなノートブックでの light モデル eval (privacy 0.5) は結果をマークしない** ので連鎖が起きない。
`iResponseTaintedQ`(応答が既知の機密変数を参照)は **この gate と独立に常にマーク**するので、
実際に機密データが絡む場合の保護は維持。ユーザー方針: **「実際に機密データがあるときだけマーク」**。

## 診断時の手がかり (重要)

- **誤マークされたセルの `TaggingRules` に eval の `history` / `LLMGraph` が乗っている** → ジョブが
  そのセルにアンカーした証拠。`iBeginJobAtCapturedCell` は `$iCurrentEvalCell = EvaluationCell[]` を使う。
- **eval 完了前 (status bar が「問い合わせ中」) なのに機密化されている** → auto-mark (完了時) ではなく、
  `iPrecisionConfidentialCheck` の依存連鎖が原因。
- **CellDingbat ⚠️ 付き** = auto-eval-prohibited (global Set 等) の検出。連鎖の echo コードによく付く。
- `AwaitingApproval` 経路は `iRuntimeDisplayResult` 内で **early `Return[]`** するので、success 経路の
  auto-mark は走らない。AwaitingApproval で誤マークが出るなら原因 2 (連鎖) を疑う。
- 連鎖の確認: `Length[$confidentialSymbols]`, `Keys[$allConfidentialVars]` を実測。良性変数 (`m` 等) が
  入っていたら汚染。カーネル再起動で `$confidentialSymbols` はクリアされる (リロードでは残る)。

## 検証

```mathematica
<< claudecode.wl
ClaudeCode`Private`iSessionHasConfidentialContent[]                              (* クリーンなら False *)
ClaudeCode`Private`iShouldBlanketMarkConfidential[1.0, Automatic]                (* False (連鎖の起点を断つ) *)
ClaudeCode`Private`iShouldBlanketMarkConfidential[1.0, <|"AccessLevel"->0.75|>]  (* True (明示 high-privacy) *)

(* identity auto-mark: 新規セルだけマーク *)
nb = CreateDocument[{Cell["a", "Input"], Cell["b", "Input"]}];
before = Cells[nb]; NBAccess`NBWriteCell[nb, Cell["c", "Input"]];
ClaudeCode`Private`iAutoMarkCellsAddedSince[nb, before];
Count[Range[NBAccess`NBCellCount[nb]], _?(TrueQ[NBAccess`NBGetConfidentialTag[nb, #]] &)]  (* 1 *)
NotebookClose[nb];

(* 実再現: クリーンなノートブックで *)
m = {"lmstudio", "qwen3-swallow-8b-rl-v0.2", "http://127.0.0.1:1234"};
ClaudeEval["\:3042\:306a\:305f\:306f\:3069\:306e\:30e2\:30c7\:30eb\:3067\:3059\:304b\:ff1f", Model -> m]
(* → どのセルも機密化されない *)
```

## 後始末・関連

- 既に誤マークされたセル: 選択して `UnmarkConfidential` (パレット「⊗ 機密解除」)。汚染変数はカーネル再起動。
- 非 runtime 経路 (`iClaudeEvalImpl` 等、`autoMark = iShouldAutoMarkConfidential[accessLevel]` の 3 箇所) は
  まだ旧ロジック。runtime 経路のみ修正済み。必要なら同じ gate を展開する。
- 上流: light モデルが文脈を echo して global Set を提案する件は**バグでなくモデル挙動**。攻めトリム
  (`SourceVault`$SourceVaultContextPlannerTrimSelfContained = True`) で自明質問の文脈を落として軽減。
  関連 skill: `promptrouter-contextplan-routing`。
- 機密データのルーティング/privacy 設計は rule 101 と `confidential-data-handling` skill を参照。
