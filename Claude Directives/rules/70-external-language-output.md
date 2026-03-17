---
paths:
  - "**/*.{wl,wls,m,nb}"
---

# 外部言語出力の制約

## R コード
- Mathematica の ExternalLanguage セルで R コードを実行する場合、R の `cat()` / `print()` による標準出力は Mathematica の Out[] に表示されない。
- R コードの最終行は必ず値を返す式にすること。
- 複数の結果を返す場合は `list("名前" = 値, ...)` 形式で返し、Mathematica の Out[] にリストとして表示されるようにすること。
