---
name: wl-encoding-and-regex
description: Use when generating or editing .wl or .m files, dealing with Unicode escapes, Windows Mathematica encoding issues, Japanese identifiers, or RegularExpression patterns in Wolfram Language.
---

# .wl エスケープと正規表現の検証手順

制約は `rules/30-encoding-safety.md` に従う。このスキルは検証方法と修正手順を定める。

## A. Unicode エスケープの検証

| 形式 | Mathematica での扱い | 結果 |
|------|----------------------|------|
| `\:3082` | 正しい | 正常動作 |
| `\u3082` | 認識されない | 文字化け |
| `\x3082` | 認識されない | `Syntax::stresc` の原因 |

### 検証コマンド

```bash
grep -n '\u[0-9a-fA-F]\{4\}' file.wl
grep -n '\x[0-9a-fA-F]' file.wl | grep -v RegularExpression
```

### 修正例（Python）

```python
import re
content = re.sub(r'\\u([0-9a-fA-F]{4})', lambda m: chr(int(m.group(1), 16)), content)
```

## B. RegularExpression 二重エスケープの検証

| .wl ファイル内 | PCRE の意味 | 正否 |
|----------------|-------------|------|
| `\\s` | 空白クラス | 正しい |
| `\\\\s` | リテラル `\\` と `s` | 誤り |
| `\\[` | `[` のエスケープ | 正しい |
| `\\\\[` | 余計な `\\` | 誤り |

### 検証コマンド

```bash
grep -n '\\\\[sntwdDWb\[\]]' file.wl
```

## C. 日本語変数名の推奨パターン

```mathematica
(* 推奨: Unicode プロパティで境界判定 *)
RegularExpression["(?<![\\p{L}\\p{N}$])" <> varName <> "(?![\\p{L}\\p{N}$])"]
RegularExpression["[\\p{L}$][\\p{L}\\p{N}$]*"]
```

## D. Windows ShiftJIS 問題の回避

必要なら非 ASCII を `\:XXXX` に変換して ASCII ファイル化する。

```python
result = ''.join(
    f'\\:{ord(c):04x}' if ord(c) > 127 else c
    for c in text
)
```

## E. 総合検証スクリプト

```python
import re

with open('file.wl', 'r', encoding='utf-8') as f:
    lines = f.readlines()

errors = 0
for i, line in enumerate(lines, 1):
    if re.search(r'(?<!\\)\\u[0-9a-fA-F]{4}', line):
        print(f"L{i} [A:unicode] \\uXXXX detected")
        errors += 1
    if 'RegularExpression' not in line:
        for m in re.finditer(r'(\\+)x([0-9a-fA-F]{2})', line):
            if len(m.group(1)) % 2 == 1:
                print(f"L{i} [A:hex] \\x{m.group(2)} detected")
                errors += 1
    if 'RegularExpression' in line:
        for pat in [r'\\\\s', r'\\\\n', r'\\\\t', r'\\\\w', r'\\\\d', r'\\\\b']:
            if re.search(pat, line):
                print(f"L{i} [B:double-escape] {pat}")
                errors += 1
    if 'RegularExpression' in line and re.search(r'\\[A-Za-z', line):
        print(f"L{i} [C:ascii-class] [A-Za-z] detected")
        errors += 1

print(f"\n{'PASS' if errors == 0 else f'FAIL: {errors} issue(s)'}")
```


## HTTP API 通信のエンコーディング (Windows 環境対策)

Windows の Mathematica は文字列\[DoubleLeftRightArrow]バイト変換でシステムエンコーディング (ShiftJIS/CP932) を暗黙に使うため、HTTP 送受信の両方で非ASCII文字が化ける。以下を厳守する。

### 送信 (リクエストボディ)

- `ExportString[body, "RawJSON"]` は Windows で日本語を UTF-8 バイト値として文字列に埋め込む場合がある (各文字コード <= 255)。この文字列を直接 `HTTPRequest` の `Body` に渡してはならない。
- 安全な手順:
  1. `ExportString` \[RightArrow] `ToCharacterCode` でコード列取得
  2. 全コード <= 255 なら `ByteArrayToString[ByteArray[codes], "UTF-8"]` で正しい Unicode に復元
  3. 非ASCII文字を `\uXXXX` エスケープして純粋ASCII化
  4. `StringToByteArray[..., "UTF-8"]` で `ByteArray` として `Body` に渡す

### 受信 (レスポンスボディ)

- `resp["Body"]` は Windows でシステムエンコーディングによるデコードが入り、UTF-8 の日本語レスポンスが壊れて JSON パースが失敗しうる。
- `resp["Body"]` の代わりに `resp["BodyByteArray"]` で生バイト列を受け取り、`ImportByteArray[rawBody, "RawJSON"]` でパースする。

### 原則

- `HTTPRequest` の `Body` には文字列ではなく `ByteArray` を渡す。
- `URLRead` のレスポンスは `"BodyByteArray"` で取得する。
- 文字列経由の暗黙エンコーディング変換を一切介在させない。
