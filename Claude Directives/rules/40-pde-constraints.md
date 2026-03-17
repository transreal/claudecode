---
paths:
  - "**/*PDE*.{wl,wls,m,nb}"
  - "**/*Model*.{wl,wls,m,nb}"
  - "**/*Simulator*.{wl,wls,m,nb}"
  - "**/*Wave*.{wl,wls,m,nb}"
  - "**/*Heat*.{wl,wls,m,nb}"
  - "**/*Quantum*.{wl,wls,m,nb}"
  - "**/*EM*.{wl,wls,m,nb}"
---

# PDE モデリング制約

## 必須
- PDE は Wolfram 組み込みの `PDETerm` / `PDEComponent` / `NDSolveValue` 系を最優先で使う。

## 禁止
- 手書きの差分式・有限差分・自前の Euler 法・Runge-Kutta を新規実装しない。
- 波動・熱・量子・電磁気・流体をモンテカルロや棄却サンプリングで代替しない。
- 干渉縞や拡散現象を「それらしく見える乱数モデル」で置き換えない。

## 判断
- 「自前差分の方がすぐ書ける」は許可理由にならない。
- PDEComponent で書けない場合にのみ従来のプログラミング手法を検討する。
