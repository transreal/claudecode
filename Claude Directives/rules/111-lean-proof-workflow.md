---
tier: guardrail
description: 定理・証明・恒等式/不等式・グラフの性質・論理式の判定を頼まれたら LeanAssist で。まず Mathematica で設定を表現 (幾何=GeometricScene、グラフ=Graph、論理=WL の論理式) して可視化し、Lean*Report で Lean に渡して Status/Axioms をそのまま報告する
keywords:
  - "lean"
  - "lean4"
  - "leanassist"
  - "mathlib"
  - "形式証明"
  - "形式化"
  - "定理証明"
  - "証明"
  - "定理"
  - "補題"
  - "命題"
  - "初等幾何"
  - "幾何"
  - "グラフ"
  - "グラフ理論"
  - "彩色"
  - "彩色数"
  - "ハミルトン"
  - "閉路"
  - "同型"
  - "マッチング"
  - "論理式"
  - "命題論理"
  - "恒真式"
  - "トートロジー"
  - "恒等式"
  - "不等式"
  - "メネラウス"
  - "チェバ"
  - "シムソン"
  - "九点円"
  - "合同"
  - "錯角"
  - "同位角"
  - "対頂角"
  - "二等辺三角形"
  - "平行線"
  - "線分上"
  - "半直線"
  - "同じ側"
  - "反対側"
  - "theorem"
  - "proof"
  - "prove"
  - "geometricscene"
---

# 111 — 証明の依頼は「Mathematica で表現・可視化 → Lean で検証」(LeanAssist)

**必須**: 定理・命題の証明、恒等式・不等式、グラフの性質、論理式の判定を頼まれたら、LLM が証明を文章や手書きの Lean で書いて済ませず、`LeanAssist` パッケージで **(1) Mathematica で設定を表現 → (2) 可視化 → (3) Lean へ渡して検査** する。最終出力は `Lean*Report` (図・定理文・Lean の結果をまとめた Grid)。手順の詳細と作例はスキル `lean-assisted-proof`。

## 1. 設定の表現 (分野ごとに決まった形)

| 問題 | Mathematica での表現 | Lean へ渡す関数 (可視化込み) |
|---|---|---|
| 初等幾何 | `GeometricScene[{点…}, {仮定…}]` (角の辺の上の点は `p ∈ HalfLine[{o, x}]`、線分上の点は `p ∈ Line[{a, b}]`、直線上なら `InfiniteLine`; 図の枝を決める順序条件 `GeometricAssertion[{p, q}, {"SameSide" / "OppositeSides", line}]`、`p ∈ Triangle[…]`、`"Counterclockwise"` も書く — 非退化 d ≠ 0 の証明に使われる) + 結論 (`GeometricAssertion[…, "Collinear" / "Concyclic" / "Parallel" / "Perpendicular" / "Concurrent"]`、`EuclideanDistance[…] == …`、`SignedRatio[a, p, b]` の式、`PlanarAngle` の等式) | `LeanGeometryReport[scene, concl]` (RandomInstance の図)。予想探しは `LeanGeometryConjectures[scene]` |
| グラフ | `Graph[{1 <-> 2, …}]` や `PetersenGraph[]` 等 + 性質 `"Bipartite"`, `{"Colorable", k}`, `"ChromaticNumber"`, `"Hamiltonian"`, `"PerfectMatching"`, `"Connected"`, `"Eulerian"`, `{"Isomorphic", h}`, `{"Clique", k}`, `"Handshake"` | `LeanGraphReport[g, prop]` (証明書を図に重ねる) |
| 論理式 | 命題論理 `Implies[p && q, p]` 等 (`And/Or/Not/Implies/Equivalent/Xor/Nand/Nor`)、量化 `ForAll[x, cond, ineq]` / `Exists[…]` (実数・整数上の多項式の等式・不等式) | `LeanLogicReport[expr]` (真理値表 / プロット) |
| 多項式の条件付き恒等式 | 変数・仮定 `h == 0` のリスト・結論 | `LeanProve[LeanPolynomialTheorem[name, vars, hyps, goal]]` (可視化は `ContourPlot` / `Plot` 等を添える) |
| その他 (数論・集合など) | 数値実験 (`Table` / `ListPlot` / `FindInstance`) で主張を確かめてから | `LeanProve[LeanTheorem[name, vars, hyps, concl, "Proof" -> tactic, "Imports" -> {…}]]` |

- **証明の過程**を見せるよう頼まれたら (「どう証明したか」「過程を可視化」「各ステップ」)、`Lean*Report[…, "ProofView" -> True]` または `LeanProofView[thm]` (図の上の手順・証明書の導出グラフ・単項式の打ち消し・変形・Lean のゴール木と各 tactic 前後のゴール)。Lean のゴールだけなら `LeanProofTrace[thm]` (`"GoalGraph"`, `"ProofDataset"`)。詳細は LeanAssist の `api_proofview.md`。
- パッケージは ``Needs["LeanAssist`"]`` (ロード済みなら不要)。`Get` / `<<` は使わない (承認が要る)。
- 変数は `Module` に閉じる (大域代入は承認が要る)。設定 (scene / graph / formula) を先に変数に入れ、`Lean*Report` に渡す。

## 2. 結果の報告 (正直に)

- 「証明できた」と言ってよいのは結果の `Status` が `"Proved"` のときだけ。`"Sorry"` / `"Failed"` / `"Timeout"` / `"Rejected"` はそう書く。
- `Claim` が実際に証明された内容 (否定の証明・反例・網羅検査の件数を含む)。性質が成り立たないときは否定を証明している。
- `Axioms` に `sorryAx` があれば未完成。`…native_decide.ax…` / `Lean.ofReduceBool` があればコンパイル済みコードを信頼した検査 (kernel 検査ではない) と書き添える。
- 幾何は座標化した主張の証明で、非退化条件 (`NonDegenerate`) と `Caveats` (角の cos² 条件など) が付く。これも書き添える。順序条件で証明した非退化は仮定に残らず、使った条件が `hord_k` (`thm["OrderHypotheses"]`) として仮定に入る。
- Lean の出力・Status を推測で書かない。評価結果に出たものだけを報告する。

## 3. 禁止

- Lean ソースに `#eval` / `run_cmd` / `elab` / `macro` / `syntax` / `unsafe` / `IO` / `System.` / 許可外の `import` を書かない (`LeanSourceGuard` が拒否し Status `"Rejected"`)。
- `LeanSaveSource` / `LeanCheckFile` / `LeanLinkImport` とタートル証明書の関数 (`LeanTurtle*`、数分・数十 GB) は、ユーザーの明示の指示なしに呼ばない。
- 生成ファイルの置き場を `$TemporaryDirectory` の外にしない (`"Directory"` オプションで外を指すと作業フォルダに戻される)。
