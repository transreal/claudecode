---
name: wl-runtime-byte-io
description: |
  Wolfram Language の実行時の文字列⇔バイト変換 (HTTP 送受信ボディ、JSON ファイル
  読み書き) で非ASCII (日本語) が文字化けしないための手順。Windows の Mathematica は
  暗黙にシステムエンコーディング (ShiftJIS/CP932) を使うため、HTTP / ファイル I/O の両方で
  化ける。ExportString["RawJSON"] と Developer`WriteRawJSONString の戻り値エンコードの違い、
  ISO8859-1 vs UTF-8 の使い分け、HTTPRequest の Body に ByteArray を渡す原則、
  resp["BodyByteArray"] 受信を扱う。Use when sending/receiving HTTP request bodies,
  writing/reading JSON files, or debugging garbled Japanese in API calls or JSON stores
  in Wolfram Language. 制約は rules/30-encoding-safety.md、ソース内のエスケープ/regex は
  skill wl-encoding-and-regex を参照。
---

# Wolfram 実行時のバイト I/O とエンコーディング

`.wl` ソース内のエスケープ (`\:XXXX`) や regex は `skills/wl-encoding-and-regex`。こちらは**実行時**に文字列をバイト化してファイル/ネットワークに出し入れするときの手順。Windows の Mathematica は文字列⇔バイト変換で暗黙にシステムエンコーディング (ShiftJIS/CP932) を使うため、明示的にバイト処理しないと非ASCIIが化ける。

## 最重要: JSON 文字列化 API の戻り値エンコードの違い (罠 #55、実証済み)

`ToCharacterCode` で確認 (result7.nb):

| API | 戻り値の中身 | `"今"` の例 | ファイル書き込み |
|-----|------------|-----------|----------------|
| `ExportString[expr, "RawJSON"]` | **UTF-8 byte の Latin-1 表現** (codepoint <= 255) | `228,187,138` | **`StringToByteArray[json, "ISO8859-1"]`** |
| `Developer`WriteRawJSONString[expr]` | **通常の Unicode 文字列** | `20170` (=0x4ECA) | **`StringToByteArray[json, "UTF-8"]`** |

- **`ExportString["RawJSON"]` の戻りを `"UTF-8"` で byte 化すると二重 encode** になり日本語が `ã` だらけに化ける。`ISO8859-1` (1 codepoint = 1 byte) で書けば内部の UTF-8 byte がそのままファイルに落ち、読み取りの `ByteArrayToString[..., "UTF-8"]` と整合する。
- **`Developer`WriteRawJSONString` は逆**で通常 Unicode を返すので `"UTF-8"` が正しい (`ISO8859-1` だとマルチバイトが落ちる)。
- 読み取りは両方とも `ReadByteArray` → `ByteArrayToString[..., "UTF-8"]` (または `ImportByteArray[..., "RawJSON"]`)。
- **ASCII のみのデータでは二重 encode でも値が変わらず顕在化しない**。日本語のパス・Memo・プロンプトが入って初めて化けるので、ASCII テストだけで通すと見逃す。
- **二次被害**: 化けたファイルを読み込むと JSON パースの Association 化が崩れ、後段で `Lookup::invrl` 等の別エラーを誘発する。文字化けを直すと連鎖エラーも消える。

### JSON ファイル書き込みテンプレ (ExportString 経路)

```mathematica
iWriteJSON[path_String, expr_] :=
  Module[{json, strm},
    json = Quiet @ ExportString[iSanitizeForJSON[expr], "RawJSON", "Compact" -> False];
    If[!StringQ[json], Return[$Failed]];
    strm = OpenWrite[path, BinaryFormat -> True];
    (* 罠 #55: ExportString["RawJSON"] は ISO8859-1 で byte 化 *)
    BinaryWrite[strm, StringToByteArray[json, "ISO8859-1"]];
    Close[strm];
  ];

iReadJSON[path_String] :=
  Module[{bytes},
    bytes = ReadByteArray[path];
    If[!ByteArrayQ[bytes], Return[Null]];
    ImportString[ByteArrayToString[bytes, "UTF-8"], "RawJSON"]];
```

### 検出コマンド

```bash
grep -n 'StringToByteArray\[[^,]*, *"UTF-8"\]' *.wl
# ヒットしたら書く文字列の出所を確認:
#   ExportString["RawJSON"] 由来 → ISO8859-1 に直す
#   WriteRawJSONString / 通常文字列 → UTF-8 のままで正しい
```

## HTTP API 通信のエンコーディング (Windows 環境対策)

### 送信 (リクエストボディ)

- `ExportString[body, "RawJSON"]` は Windows で日本語を UTF-8 バイト値として文字列に埋め込む (各文字コード <= 255)。この文字列を直接 `HTTPRequest` の `Body` に渡してはならない。
- 安全な手順:
  1. `ExportString` → `ToCharacterCode` でコード列取得
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

## 関連

- `rules/30-encoding-safety.md` — エンコーディング制約 (JSON / HTTP / ソースエスケープ)
- `skills/wl-encoding-and-regex` — `.wl` ソース内のエスケープ (`\:XXXX`) と RegularExpression
- `skills/wolfram-syntax-pitfalls` — 罠 #55 (JSON 二重 encode)、罠 #20 (Windows JSONL ReadList)、罠 #28 (RawJSON parse fallback)
- `skills/jsonl-store-pattern` — append-only JSONL ストアでの書き込みテンプレ
