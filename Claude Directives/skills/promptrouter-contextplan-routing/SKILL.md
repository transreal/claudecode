---
name: promptrouter-contextplan-routing
description: |
  ClaudeEval のプロンプトが LM Studio 等の短コンテキストモデルでトークン超過する
  (n_keep >= n_ctx) 事故の診断と修正。X0a (context budget / bounded assembly)、
  X0b-1 (history 境界・planner hook 配線)、X1 (prompt-only 依存分類器 + planner) の
  as-built メモ。真因の特定法 (推測でなく実測)、単一チョークポイント戦略
  ($UseClaudeRuntime True/False の両経路をカバー)、planning フラグと各予算変数、
  pkgDocs キーワード過剰マッチの教訓。ClaudeEval が「保存済み候補」UI で堂々巡り
  する別件 (saved-prompt 提案) との切り分けも含む。決定的 FunctionRoute
  (「新規ノートブック」→ SourceVaultNewNotebook 等) が ClaudeOrchestrator 未ロード時に
  活性ゲートで遮断され LLM に流れる不具合の診断・修正 (deterministic 提案はゲート迂回) も収録。
---

# ClaudeEval ContextPlan / context budget (X0a as-built)

`ClaudeEval[prompt, Model -> {"lmstudio", ...}]` が
`The number of tokens to keep from the initial prompt is greater than the
context length (n_keep: NNNNN >= n_ctx: 40960)` で落ちるときの診断と、実装済みの
対策 (X0a)。設計の全体像は `ドキュメント/sourcevault_promptrouter_contextscope_routing_spec_v1.md`。

## 真因 (実測で確定。推測するな)

事故の主因は **`iPackageDocsContext` が api.md を青天井で注入していた**こと。
trivial なプロンプト `"あなたはどのモデルですか？"` の **「モデル」が SourceVault の
過剰に広いキーワード** (`$ClaudePackageKeywordMap["SourceVault"]` に登録された
"モデル"/"model"/"一覧"/"notebook" 等) に `StringContainsQ` 部分一致し、SourceVault の
api 群 (api.md + api_*.md) が **104,606 文字**注入されていた。

- tools (mcp/exa integrations) は **~600 トークンに過ぎなかった** (除去で 51350→50753)。
- notebook context / 会話履歴 / CLAUDE.md も主因ではなかった。
- LM Studio ログの `slot release: n_tokens = 20331` は **別リクエストのキャッシュ値**で、
  当該リクエストのサイズではない。これに釣られて誤診すると時間を浪費する。

**教訓: どのコンポーネントが大きいかは必ず実測する。** 各 context 生成関数の
`StringLength` を直接測れば一発で分かる:

```mathematica
nb = EvaluationNotebook[]; task = "...";
{StringLength @ ClaudeCode`Private`iClaudeSysPrompt[],
 StringLength @ Quiet@Check[ClaudeCode`Private`iNotebookDefinedSymbolsContext[nb], ""],
 StringLength @ Quiet@Check[ClaudeCode`Private`iPackageDocsContext[task], ""],
 StringLength @ Quiet@Check[ClaudeCode`Private`iFileAccessContext[task], ""]}
```

## 単一チョークポイント戦略 (最重要)

`ClaudeEval` の最終 LLM 送信は **`$UseClaudeRuntime` で経路が分岐**する:

- `False` (既定) → `iClaudeEvalImpl` (legacy)
- `True` → `iClaudeEvalViaRuntimeBridge` → `iAdapterBuildPrompt` (Runtime Bridge)

`iClaudeEvalImpl` に境界を入れても **True 経路では効かない** (skill
`claudeeval-security-guard-placement` と同じ落とし穴)。したがって context 境界は
**両経路が必ず通る関数 = 単一チョークポイント**に入れる:

| チョークポイント | 何を境界化 | 予算変数 (既定) |
|---|---|---|
| `iClaudeSysPrompt[]` | CLAUDE.md / 指針 (先頭keep) | `$ClaudeEvalContextSysPromptCharBudget` (6000) |
| `iResolveLMStudioIntegrations` | tools/integrations (ToolDefinitions gate) | — (planning時 既定 off) |
| `iPackageDocsContext` | api docs 総量 (関数出口で cap) | `$ClaudeEvalPackageDocsCharBudget` (24000) |
| `iAssembleContextForPlan` (新設 core) | notebook tail / history | `$ClaudeEvalContextNotebookCharBudget` (8000) |

`iResolveLMStudioIntegrations` は同期 (`iQueryLMStudioChat`/`iQueryViaAPI`) と
非同期/bridge (`iPrepareLMStudioMCPPS1`) の **全 LM Studio 送信が経由する**ので、
ここで `{}` を返せば `$UseClaudeRuntime` に関係なく tools を落とせる。

## planning フラグと挙動

`$ClaudeEvalContextPlanning`:
- `Automatic` (既定) / それ以外の非 LegacyFull → bounded plan で境界化 ON
- `"LegacyFull"` または `False` → 旧 full 挙動 (境界一切なし。完全可逆の退避弁)

hook `$ClaudeEvalContextPlanner` (既定 `None`) は X0b/X1 で SourceVault が planner
function を登録する package-neutral スロット (`$ClaudeCloudSendPreflightContextResolver`
と同型)。claudecode は SourceVault を参照しない (rule 11)。

調整つまみ:
```mathematica
ClaudeCode`$ClaudeEvalContextNotebookCharBudget = 12000;   (* notebook 上限 *)
ClaudeCode`$ClaudeEvalContextSysPromptCharBudget = 12000;  (* CLAUDE.md をもっと残す *)
ClaudeCode`$ClaudeEvalPackageDocsCharBudget = 30000;       (* api docs 上限 *)
ClaudeCode`$ClaudeEvalContextPlanning = "LegacyFull";      (* 全部旧挙動へ *)
```

## X0b-1 / X1 / X0b-2: history 境界・分類器・planner・Bridge 配線 (2026-06-15 実装済み)

X0a の後、planner パイプラインを段階配線した。**X0b-2 で Bridge 経路 (`iAdapterBuildPrompt`) にも届くので、`$UseClaudeRuntime` 両経路で効く。**

- **X0b-1 (claudecode.wl)**:
  - `iBoundedHistory[h, mode, n]` — `"None"` 破棄 / `"Recent" n` 直近 n turn / 他 (`"Full"`) 素通し。既定 plan の History は `Recent`/`MaxTurns` 12 (`$ClaudeEvalContextHistoryTurns`)。X0a では history 素通しだった。
  - `iResolveContextPlanForCall[plan, prompt, nb, afterIdx, access]` が `$ClaudeEvalContextPlanner` を fail-safe (`Quiet/Check/Catch`) に参照。**payload に `"Prompt"` を含める**(prompt-only 分類器が要るため)。未登録時は既定 plan。
- **X1 (SourceVault_promptrouter.wl)**:
  - `SourceVaultClassifyPromptContextDependency[prompt]` (public, **LLM 不要**): `%/Out/In`→`PreviousCellGroup`、deictic→`Tail`、選択→`SelectedCells`、「さっき/直前の会話」→History `Recent`、notebook 全体→`Full`。deictic 表は `iSVPRDeicticQ` と共有。**history phrase を deictic 判定の前に StringReplace で除去**し、notebook と history を混同しない (spec §7.1)。マーカー無し→`SelfContained`/Notebook `None`/Confidence `Low`。
  - planner `iSVPRContextPlanner` を `ClaudeCode`$ClaudeEvalContextPlanner` に登録 (登録パターンは `$ClaudeCloudSendPreflightContextResolver` と同型、load-order independent)。トグル `SourceVault`$SourceVaultContextPlannerEnabled` (既定 True、call 時参照なので reload 不要で OFF 可)。
  - **保守的ポリシー (重要)**: High 確信 + Notebook `None` (純粋な履歴質問) のときだけ notebook を落とす。High + notebook 必要→bounded `Tail` (assembler は `Full`/`PreviousCellGroup` を未実装なので Tail に丸める)。**Low/SelfContained は既定 scope を維持**(マーカー無しの notebook 依存 prompt を飢えさせない)。history/ToolDefinitions は既定のまま。
- **X0b-2 (claudecode.wl, Bridge 配線)**:
  - `iAdapterBuildPrompt` 冒頭で `iResolveContextPlanForCall` を呼び `nbCtxMode`/`histCtxMode` を解決。`None` の次元だけ落とす保守的 gate: `symCtx` / Notebook Context cells / Selected cells を `nbCtxMode =!= "None"`、Turn History / PreviousResult を `histCtxMode =!= "None"`。`Tail`/`Recent` は X0a の既存 bound 維持。planning フラグ OFF 時はスキップ。
  - **攻めの trim は opt-in フラグ** `SourceVault`$SourceVaultContextPlannerTrimSelfContained` (既定 False)。True で SelfContained/Low の Notebook を `"None"` に落とす (ライトモデルが prior cell を模倣するのを止める)。**history はこのフラグでも trim しない** (追問対策)。マーカー無しの notebook 依存 prompt を飢えさせる残存リスクのため既定 OFF。**緩和実装済み (2026-06-15)**: 分類器 `iSVPRNotebookNounQ`（`(この|その|あの|上の|先ほどの)+(結果|グラフ|データ|出力|コード|関数|…|セル)` の regex ＋ `上記`/`the above`）を deictic 判定に OR し、「このグラフを改善して」等を NotebookRecent→Tail に分類（replay-safety の deictic 表は不変。抽象的な「この方法」等は SelfContained のまま）。

検証パターン:
```mathematica
plan0 = ClaudeCode`$ClaudeEvalDefaultContextPlan;
(* planner 単体 (非 Runtime path) *)
ClaudeCode`Private`iResolveContextPlanForCall[plan0, "あなたはどのモデルですか？", None, 0, 0.5]  (* Notebook Tail 維持 *)
ClaudeCode`Private`iResolveContextPlanForCall[plan0, "さっきの会話で言ってたモデルは？", None, 0, 0.5]  (* Notebook None *)
SourceVault`$SourceVaultContextPlannerEnabled = False;  (* → planner no-op、== plan0 *)

(* Bridge prompt builder (X0b-2) *)
cp = <|"Input" -> "さっきの会話で言ってたモデルは？", "Notebook" -> None,
   "Cells" -> {<|"CellIndex"->1,"CellStyle"->"Input","InputText"->"PriorCell[1,2,3]"|>},
   "TotalCellCount" -> 1, "SelectedCells" -> {}|>;
cs = <|"Messages" -> {<|"Turn"->1,"ProposedCode"->"x=1","TextResponse"->"ok"|>}|>;
p1 = ClaudeCode`Private`iAdapterBuildPrompt[cp, cs];
{StringContainsQ[p1, "Notebook Context"], StringContainsQ[p1, "Turn History"]}  (* {False, True} *)
SourceVault`$SourceVaultContextPlannerTrimSelfContained = True;  (* 攻め: 自明質問も notebook を落とす *)
```

## キーワード過剰マッチの根治 (発生源)

`$ClaudePackageKeywordMap` / `$ClaudePackageAuxKeywordMap` のキーワードは
`iPackageDocsContext` 内で `StringContainsQ[task, keyword]` 部分一致される。
**汎用語 (モデル/model/一覧/リスト/notebook/検索/新規/タスク/ソース 等) を登録すると
無関係プロンプトに誤爆**し、api.md が丸ごと注入される。

- 登録は **特異的な語に限定**する: パッケージ名・公開関数名 (CamelCase API)・
  明確なドメイン語 (予定/締切/arxiv/横断検索/メール/IMAP 等)。
- 一般名詞は登録しない。SourceVault の登録は `SourceVault.wl` の
  `$ClaudePackageKeywordMap["SourceVault"]` (約 L13976)。
- 二重防御として `iPackageDocsContext` 出口に総量 cap (上表) を必ず残す
  (将来また広いキーワードが入っても 100K 暴発しないため)。

## .wl 編集上の注意 (基盤パッケージ)

- `claudecode.wl` / `NBAccess.wl` は基盤 (rule 11)。改修はユーザー承認を得て直接編集、
  新規 hook/設定は完全修飾 `ClaudeCode`$...` の `If[!ValueQ[...], ...]` で宣言。
- 内部関数の定義は冒頭 `ClearAll[...]` の **後**に置く (skill 罠 #56)。
- 新規文字列の日本語は `\:XXXX`、`\u` 不可。編集後 `grep '\u[0-9a-fA-F]{4}'` で 0 を確認。
- 早期 return は関数本体の `Module` レベルに置く (罠 #52)。

## 別件との切り分け: 「保存済み候補」で堂々巡り

トークン超過が直っても、再実行で `「…」の保存済み候補 N 件` UI が出てループする場合、
それは **context budget とは無関係**で、saved-prompt 提案
(`SourceVaultProposeSavedPromptRoute` / `SourceVaultPromptVersionsUI`、フラグ
`$SourceVaultPromptSavedProposalActive` / `$SourceVaultPromptAutoSave`) の挙動。
HeavyLLM one-shot を route 化・自動提案してしまうのが原因 (spec §10.3 違反)。
対症は `SourceVault`$SourceVaultPromptSavedProposalActive = False` ＋ 不良ルート削除。
根治 (2026-06-14 実装済み、`SourceVault_promptrouter.wl`):
(i) `SourceVaultAutoSaveLastPrompt` / `iSVPRCombineWorkflowExprs` が `iSVPRIsMetaDisplayExpr` で UI 表示式 (`SourceVaultPromptVersionsUI` 等) を `TargetExprString` に取り込まない、
(ii) `SourceVaultProposeSavedPromptRoute` が `iSVPRVersionProposableQ` で HeavyLLM/AutoCapture-only の保存版を提案しない (`NotDispatched`, Reason `OnlyAutoCaptureHeavyLLM`)、
(iii) `SourceVaultAutoSaveLastPrompt` が `iSVPRClassifyReplay[exprStr] === "HeavyLLM"` の素の LLM 一発回答を route 化しない (§10.3。PromptRun 履歴には残す)。

## 別件との切り分け: 決定的 FunctionRoute が LLM に流れる (活性ゲート)

「新規ノートブック」→ `SourceVaultNewNotebook` のような **deterministic seed FunctionRoute が
発火せず LLM が welcome メッセージを生成**する場合、context budget でも saved-prompt でもなく、
`iClaudeEvalTryPromptRouter` (`claudecode.wl`) の **活性ゲート**が原因。

`iClaudeEvalTryPromptRouter` の段構成:
1. **saved-prompt proposer** (`SourceVaultProposeSavedPromptRoute`) — 活性ゲートの**前**。ClaudeOrchestrator 不要。
2. **活性ゲート** `SourceVaultPromptRouterActiveQ["ClaudeEval"]` — **False (Orchestrator 未ロード) で `NotDispatched`**。
3. 通常 propose (`SourceVaultProposePromptRoute`) — ゲート通過後のみ到達。

旧版は deterministic route が 3 (ゲート後) でしか評価されず、ClaudeOrchestrator 未ロードだと
2 で遮断 → LLM フォールバックしていた。

**診断 (4 つ実測)**:
```mathematica
ClaudeCode`$ClaudeEvalPromptRouterDispatch                      (* Automatic で OK *)
SourceVault`SourceVaultPromptRouterActiveQ["ClaudeEval"]        (* False なら本件 *)
SourceVault`SourceVaultProposePromptRoute["新規ノートブック", "Caller"->"ClaudeEval"]
  (* Status "Proposed" / Method "DeterministicFunctionRoute" / SourceVaultNewNotebook[] を提案するなら route は健在 *)
SourceVaultNewNotebook[]                                        (* 関数単体は動くか *)
```
②が False かつ③が `Proposed` → 旧版は LLM 行き (本不具合)。

**修正 (2026-06-15 実装済み)**: `iClaudeEvalTryPromptRouter` で proposal を**ゲート前に取得**し、
`Decision.Method` が `"Deterministic*"` (`DeterministicFunctionRoute` / `DeterministicSchedule`) なら
**ゲートを迂回して即 submit**。非決定的提案 (将来の LLM 経路) は従来どおりゲートを通す。
- 安全根拠: `SourceVaultProposePromptRoute` は **完全に決定的** (LLM 呼び出し無し、コスト 0)。
  `iSVPRProposeFunctionRoute` が `ReadOnly`/`SafeCreate` allowlist + `UseAsFunctionRoute->True` に制限し、
  claudecode 側 `iClaudeRuntimeSubmitProposal` が `$iClaudeEvalProposalHeadAllowlist` で head 検証する二重ガード。
  saved-prompt proposer がゲートを跨ぐのと同じ思想 (Orchestrator 不要なものはゲート不要)。
- `$ClaudeEvalPromptRouterPreemptsNatural` の値とは独立 (block 1/3 どちらでも PromptRouter は走る)。

## 検証チェックリスト

- [ ] `$UseClaudeRuntime` の値を確認 (True なら Bridge 経路。iClaudeEvalImpl だけ直しても無駄)
- [ ] コンポーネント別 `StringLength` を実測して主因を特定 (推測しない)
- [ ] 修正後 `iPackageDocsContext[trivialTask]` が 0 (発生源で誤爆しないこと)
- [ ] LM Studio ログ `request (...tokens)` が n_ctx 未満
- [ ] `$ClaudeEvalContextPlanning = "LegacyFull"` で旧挙動に戻ること
