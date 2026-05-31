---
name: wl-encoding-and-regex
description: Use when generating or editing .wl or .m files, dealing with Unicode escapes, Windows Mathematica encoding issues, Japanese identifiers, or RegularExpression patterns in Wolfram Language.
---

# .wl エスケープと正規表現の検証手順

制約は `rules/30-encoding-safety.md` に従う。このスキルは検証方法と修正手順を定める。

## 最重要: ノートブック出力コードの日本語

ClaudeQuery / ClaudeEval が生成する `\`\`\`mathematica` コードブロック内の文字列では、**日本語を必ずリテラル UTF-8 でそのまま書く**。

| 書き方 | 判定 | 例 |
|--------|------|-----|
| リテラル日本語 | ✅ 正しい | `"一致 ✓"` |
| `\xNN` エスケープ | ❌ 絶対禁止 | `"\x4e00\x81f4"` |
| `\uXXXX` エスケープ | ❌ 禁止 | `"\u4e00\u81f4"` |
| `\:XXXX` (.wl以外) | ❌ 禁止 | `"\:4e00\:81f4"` |

- Style テキスト、Grid ヘッダー、エラーメッセージ、Print 文など **全ての文字列** に適用。
- `.wl` パッケージファイルの編集時のみ `\:XXXX` が許可される (Windows ShiftJIS 対策)。


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

### 修正例 (Python、.wl ファイル向け `\u` → `\:`)

`.wl` パッケージファイル内では `\:XXXX` 形式を維持する必要がある (Windows ShiftJIS 対策)。リテラル日本語に置換すると新たな encoding 問題を引き起こすため、`\u` を `\:` に置換するだけに留める:

```python
import re
# \uXXXX (4桁hex) を \:XXXX に置換
new_content = re.sub(r'\\u([0-9a-fA-F]{4})', r'\\:\1', content)
```

### 実際にあった例 (Stage B Week 2c-4 prelude、罠 #11)

`ClaudeOrchestrator_workflow_diff_harness.wl` の末尾 Print 文と `ClaudeRuntime_stategraph.wl` の usage 出力で、Python/JS の感覚で `\u3001` (、) や `\u3002` (。) を書いてしまい、ロード時に「未知のエスケープ文字列\u」エラー。`.wl` ファイル全体に対する一括置換で復旧した。

検出時は次のコマンドで全 `.wl` を一括チェックすると安全:

```bash
for f in *.wl; do
  grep -l '\\u[0-9a-fA-F]\{4\}' "$f"
done
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


## 実行時のバイト I/O (HTTP / JSON ファイル)

HTTP 送受信ボディや JSON ファイルの読み書きでの文字列⇔バイト変換 (Windows のシステムエンコーディング対策、`ExportString["RawJSON"]` vs `Developer`WriteRawJSONString` のエンコード差、ISO8859-1 / UTF-8 の使い分け) は、独立 skill **`skills/wl-runtime-byte-io`** に分離した。API 通信や JSON ストアで日本語が化けるときはそちらを参照。
