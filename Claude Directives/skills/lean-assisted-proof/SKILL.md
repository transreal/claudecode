---
name: lean-assisted-proof
description: 定理・証明の依頼を LeanAssist で処理する手順。Mathematica で設定を表現 (初等幾何=GeometricScene、グラフ=Graph、論理式=WL の論理式・量化式、多項式の条件付き恒等式) し可視化してから Lean 4 (Mathlib) に渡し、Lean*Report の図・定理文・Status・公理で結果を示す。作例、Status/公理の読み方、失敗時の対処、tactic の早見表
when_to_use: 証明して、定理を証明、Lean で証明、形式証明、形式化、恒等式・不等式の証明、幾何の定理 (メネラウス、チェバ、九点円、シムソン線、オイラー線)、グラフの性質 (彩色、二部グラフ、ハミルトン閉路、完全マッチング、連結、同型)、論理式 (トートロジー、恒真式、充足可能、反例)
tags: lean, lean4, leanassist, mathlib, proof, theorem, 証明, 定理, 形式証明, 幾何, グラフ, 論理式
---

# Lean 支援証明 (LeanAssist) の手順

制約は `rules/111-lean-proof-workflow.md`。API の正確な引数・オプションは `LeanAssist_info/docs/api.md` (タートル証明書は `api_turtle.md`)。

## 0. 原則: Mathematica が表現・計算し、Lean が検査する

1. **表現**: 問題を Mathematica の対象 (GeometricScene / Graph / 論理式 / 多項式) にする。自然言語の主張を勝手に強めたり弱めたりしない。仮定が足りない (退化する) なら、その仮定を足したことを明記する。
2. **可視化**: その対象を図にする (`RandomInstance[scene]`、Graph の描画、真理値表、`Plot` / `RegionPlot`)。`Lean*Report` は図を含むので、通常はこれ 1 つでよい。
3. **Lean**: Mathematica が判定と証明書 (Groebner の係数、彩色、閉路、反例、証拠) を計算し、Lean はそれを検査する。Lean の結果 (`Status`、`Axioms`) をそのまま報告する。

ClaudeEval の出力コードは `Module` に閉じ、最後の式を `Lean*Report[...]` にする。``Needs["LeanAssist`"]`` は先頭に置いてよい (ロード済みなら何もしない)。

## 1. 初等幾何 (GeometricScene)

```mathematica
Needs["LeanAssist`"];
Module[{men, concl},
  men = GeometricScene[{a, b, c, d, e, f}, {Triangle[{a, b, c}],
     d \[Element] Line[{b, c}], e \[Element] Line[{c, a}], f \[Element] Line[{a, b}],
     GeometricAssertion[{d, e, f}, "Collinear"]}];
  concl = SignedRatio[b, d, c] SignedRatio[c, e, a] SignedRatio[a, f, b] == -1;
  LeanGeometryReport[men, concl]]
```

- 点は記号 (`a, b, …`)。仮定は GeometricScene の語彙: `Triangle`, `Polygon`, `Line`, `Circle`, `CircleThrough`, `Midpoint`, `TriangleCenter[{a,b,c}, "Centroid" | "Circumcenter" | "Orthocenter"]` (内心は未対応), `p \[Element] Line[…]`, `GeometricAssertion[…, "Perpendicular" | "Parallel" | …]`。
- 結論: `GeometricAssertion[pts, "Collinear" | "Concyclic"]`、`GeometricAssertion[{Line…, Line…}, "Parallel" | "Perpendicular"]`、`GeometricAssertion[{l1, l2, l3}, "Concurrent"]`、`GeometricAssertion[{Triangle[…], Triangle[…]}, "Congruent" | "Similar"]`、`GeometricAssertion[{a, b, c}, "Equilateral"]`、`EuclideanDistance[p, q] == EuclideanDistance[r, s]`、`SignedRatio[a, p, b] == r` とその積、`PlanarAngle[{a, b, c}] == PlanarAngle[{d, e, f}]` (full-angle 版が自動で試される)、`&&` で連言。
- 結論が分からないときは `LeanGeometryConjectures[scene]` (FindGeometricConjectures の予想を一括で Lean へ)。
- 作例: チェバ、ヴァリニョン、タレス、オイラー線 (`SignedRatio[h, g, o] == 2`)、九点円 (`GeometricAssertion[{ma, mb, mc, fa}, "Concyclic"]`)、シムソン線は `LeanAssist_info/docs/example.md` §4。
- 報告に添えること: `NonDegenerate` (退化しない条件、Lean の仮定 `nd_j : … ≠ 0`)、`Caveats` (角の条件は cos² 版 = 補角も含む、など)、座標化した主張の証明であること。
- 時間: 座標と証明書は数秒〜数十秒、Lean (Mathlib の `linear_combination`) は 10–60 s。

## 2. グラフ (Graph)

```mathematica
Needs["LeanAssist`"];
Module[{g = PetersenGraph[]},
  Column[{LeanGraphReport[g, "ChromaticNumber"], LeanGraphReport[g, "Hamiltonian"]}]]
```

| 性質 `prop` | 成り立つとき (証明書) | 成り立たないとき |
|---|---|---|
| `"Bipartite"`, `{"Colorable", k}` | 彩色 | k^n 通りの全彩色を網羅 |
| `"ChromaticNumber"` | χ 色の彩色 + (χ−1)^n 通りの網羅 | — |
| `"Hamiltonian"` | ハミルトン閉路 | (n−1)! 通りの巡回順を網羅 |
| `"PerfectMatching"`, `{"Clique", k}`, `"Eulerian"` | マッチング / クリーク / オイラー回路 | Lean の証明無し (`$Failed` とメッセージ) |
| `"Connected"` | 全域木 (親・深さ) | 辺が出ない頂点集合 |
| `{"Isomorphic", h}` | 頂点写像 | n! 通りの全単射を網羅 |
| `"Handshake"` | 次数和 = 辺数の 2 倍 | — |

- グラフは有限・単純・無向 (`UndirectedGraphQ`, `SimpleGraphQ`)。頂点名は何でもよい (0 … n−1 に番号付け、図は元の名前)。
- 網羅が `"MaxCandidates"` (既定 400000) を超えると `$Failed`。60000 以下は `decide +kernel`、超えると `native_decide` (公理 `…native_decide.ax…` が付く = コンパイル済みコードを信頼) — そう報告する。
- `Claim` が証明された文 (否定なら「網羅で無い」)。`Holds` が Mathematica の判定。

## 3. 論理式

```mathematica
Needs["LeanAssist`"];
LeanLogicReport[Equivalent[Not[p && q], Not[p] || Not[q]]]          (* tauto *)
LeanLogicReport[ForAll[{a, b}, a > 0 && b > 0, (a + b)/2 >= Sqrt[a b]]] (* nlinarith + 平方ヒント *)
LeanLogicReport[ForAll[x, x^2 > x]]                                  (* 偽: 反例 x = 0 で否定を証明 *)
```

- 命題論理 (記号と `And/Or/Not/Implies/Equivalent/Xor/Nand/Nor`): Mathematica が恒真・矛盾・どちらでもない を判定し、Lean は `Prop` 上で `tauto` (恒真・矛盾) または反例と充足例 (どちらでもない) を検査する。図は真理値表 (6 変数まで)。
- 量化式 (`ForAll[x, cond, body]` / `Exists[…]`、実数既定、`Element[x, Integers]` があれば整数): `Resolve` で真偽を判定し、真なら tactic 探索 (`positivity`, `nlinarith [sq_nonneg …, Real.sq_sqrt …]`, `linarith`, `ring`, `norm_num`, 整数は `omega`)、存在は `FindInstance` の証拠、偽は反例で否定を証明。図は 1 変数 `Plot`、2 変数 `RegionPlot`。
- 量化子が交互 (∀∃) のものは自動証明しない (`sorry` のまま = Status `"Sorry"`)。手で `LeanTheorem` を書くか、そう報告する。
- 初回は Mathlib の読み込みで 8–25 s。

## 4. 多項式の条件付き恒等式・その他

```mathematica
Needs["LeanAssist`"];
Module[{thm},
  thm = LeanPolynomialTheorem["sum_cubes", {x, y, z}, {x + y + z == 0}, x^3 + y^3 + z^3 == 3 x y z];
  Column[{ContourPlot3D[x + y + z == 0, {x, -1, 1}, {y, -1, 1}, {z, -1, 1}, ImageSize -> 200],
    LeanSource[thm], LeanProve[thm]}]]
```

LeanAssist に専用の関数が無い分野は、数値実験で主張を確かめて図にしたうえで `LeanTheorem` を手で組む:

```mathematica
Needs["LeanAssist`"];
Module[{thm},
  thm = LeanTheorem["even_consecutive", {n -> "Nat"}, {}, "Even (n * (n + 1))",
    "Proof" -> "exact Nat.even_mul_succ_self n", "Imports" -> {"Mathlib.Algebra.Group.Nat.Even"}];
  Column[{ListPlot[Table[Mod[k (k + 1), 2], {k, 0, 20}], PlotLabel -> "n(n+1) mod 2"], LeanProve[thm]}]]
```

- `LeanTheorem[name, vars, hyps, concl, opts]`: `vars` は記号 (既定 ℝ)、`x -> "Int"`、`{m, n} -> "Nat"`、生の `"x : ℝ"`。`hyps`/`concl` は WL の命題 (`LeanForm` で変換) か Lean の文字列。
- 型は ASCII の `"Nat"` / `"Int"` / `"Rat"` / `"Real"` で書く。Mathematica の `\[DoubleStruckCapitalR]` などは Unicode の ℝ ではなく私用領域の文字 (LeanAssist は C, N, Q, R, Z を ℂ ℕ ℚ ℝ ℤ に直すが、それ以外の文字は Lean で壊れる)。
- `"Imports"`: `Automatic` (tactic から推定) か `{Automatic, "Mathlib.…"}`。分からなければ `{"Mathlib"}` (全体の読み込み、遅い)。
- tactic の早見表: 等式 `ring` / `field_simp; ring` / `linear_combination e`、線形不等式 `linarith`、非線形 `nlinarith [sq_nonneg (x - y), …]` / `positivity`、整数・自然数 `omega` / `decide`、有限検査 `decide +kernel` / `native_decide`、論理 `tauto`、数値 `norm_num`、場合分け `rcases` / `interval_cases`。
- 補題名は推測しない。Status が `"Failed"` で「unknown identifier」なら、名前を変えて試すか、そう報告する。

## 5. 結果の読み方

| `Status` | 意味 | 報告 |
|---|---|---|
| `"Proved"` | エラー無し・`sorry` 無し | 「Lean で証明された」(公理も示す) |
| `"Sorry"` | `sorry` が残る | 「主張は書けたが証明は未完成」 |
| `"Failed"` | コンパイルエラー | 最初のエラー (`res["Errors"]`) を示して未証明と報告 |
| `"Timeout"` | 時間切れ (`"Timeout" -> 秒` で延長可) | 未証明 |
| `"Rejected"` | ソース検査 (`LeanSourceGuard`) が拒否 | 禁止構文を除いて書き直す |

- `Axioms`: `propext`, `Classical.choice`, `Quot.sound` は標準。`sorryAx` = 未完成。`…native_decide.ax…` / `Lean.ofReduceBool` = コンパイル済みコードを信頼。
- Report を使わないときは `LeanProve[thm]` の結果を `res["Status"]`, `res["Axioms"]`, `res["Errors"]` で読む。

## 6. つまずき

- `Needs` が失敗する → `$packageDirectory` に `LeanAssist.wl` があるか。Lean / Mathlib の状態は `LeanAssistStatus[]`。
- 幾何で「InstanceCheck が False」→ 結論が偽か、図の点の役割の取り違え。`RandomInstance[scene]` を見直す。
- 幾何の証明書が見つからない → `"MaxExponent" -> 4`、補助の非退化条件 `"NonDegenerate" -> {…}`。
- グラフの網羅が大きすぎる → 頂点数を減らすか、`"MaxCandidates"` を上げて `native_decide` を使う (そう報告する)。
- 論理式で `"Undecided"` → `Resolve` が判定できなかった。Lean の結果だけが根拠になる。
