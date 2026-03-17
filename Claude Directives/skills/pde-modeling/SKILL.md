---
name: pde-modeling
description: Use when modeling physics or engineering systems with PDEs in Wolfram Language, including heat, wave, Schrodinger, electromagnetics, fluids, diffusion, reaction, or finite-element workflows.
---

# PDE 実装ステップ

制約は `rules/40-pde-constraints.md` に従う。このスキルは具体的な実装手順を定める。

## 優先する組み込み関数

| 用途 | 関数 |
|------|------|
| 拡散項 | `DiffusionPDETerm` |
| 対流項 | `ConvectionPDETerm` |
| 反応項 | `ReactionPDETerm` |
| ソース項 | `SourcePDETerm` |
| ラプラシアン | `LaplacianPDETerm` |
| 一般形 | `PDETerm` |
| ポアソン | `PoissonPDEComponent` |
| 熱伝導 | `HeatPDEComponent` |
| 波動 | `WavePDEComponent` |
| ヘルムホルツ | `HelmholtzPDEComponent` |
| シュレーディンガー | `SchrodingerPDEComponent` |
| ディリクレ条件 | `DirichletCondition` |
| ノイマン条件 | `NeumannValue` |
| 周期境界 | `PeriodicBoundaryCondition` |
| 数値解法 | `NDSolveValue` |
| 固有値 | `NDEigensystem` |

## 実装ステップ

### 1. 変数・パラメータ設定
- 依存変数と独立変数を明示する。
- 物理パラメータは `Association` でまとめる。

### 2. PDE の定義
- まず `HeatPDEComponent`, `WavePDEComponent`, `SchrodingerPDEComponent` 等の高レベル関数を検討する。
- 足りなければ `DiffusionPDETerm`, `ConvectionPDETerm`, `ReactionPDETerm`, `SourcePDETerm` を組み合わせる。

### 3. 領域の定義
- `Rectangle`, `Disk`, `RegionDifference`, `RegionUnion` 等で領域を作る。
- `RegionPlot` で形状を確認する。

### 4. 初期条件・境界条件
- `DirichletCondition`, `NeumannValue`, `PeriodicBoundaryCondition` を使う。
- 初期波束や初期分布は数式で定義し、`Plot` / `DensityPlot` で確認する。

### 5. 求解
- `NDSolveValue` に PDE を渡す。
- 必要なら `Method -> {"PDEDiscretization" -> {"FiniteElement"}}` を明示する。

### 6. 可視化
- `DensityPlot`, `Plot3D`, `VectorPlot` を使う。
- 時間発展は `ListAnimate[..., AnimationRunning -> False]` を基本にする。
