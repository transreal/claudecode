---
name: external-language-output
description: Use when generating R, Python, Julia, or other external language code that runs in Mathematica ExternalLanguage cells. Defines how to return values so they appear in Mathematica's Out[].
---

# 外部言語コードの出力パターン

制約は `rules/70-external-language-output.md` に従う。このスキルは各言語の出力パターンを定める。

## R コード

Mathematica の ExternalLanguage セルで R を実行する場合、`cat()` / `print()` の標準出力は Out[] に表示されない。最終行で値を返す必要がある。

### 正しいパターン

```r
# データ処理
data <- data.frame(x = 1:5, y = c(2,4,6,8,10))
model <- lm(y ~ x, data = data)

# 最終行: list() で結果を返す → Out[] に表示される
list(
  "coefficients" = coef(model),
  "r_squared" = summary(model)$r.squared,
  "residuals" = residuals(model)
)
```

### 避けるべきパターン

```r
# NG: print() は Out[] に出ない
print(summary(model))
cat("R-squared:", summary(model)$r.squared)
```

### 単一の値を返す場合

```r
# 最終行が式ならそのまま返る
mean(c(1, 2, 3, 4, 5))
```

### DataFrame を返す場合

```r
# data.frame は Mathematica の Dataset 互換形式で返る
data.frame(name = c("Alice", "Bob"), score = c(95, 87))
```

## Python コード

Python の ExternalLanguage セルでは、最終式の値が Out[] に返る。

```python
# 辞書を返す → Mathematica の Association に変換
{"mean": sum(data) / len(data), "count": len(data)}
```

## Julia コード

Julia も最終式の値が返る。

```julia
# タプルで複数値を返す
(mean_val = mean(data), std_val = std(data))
```
