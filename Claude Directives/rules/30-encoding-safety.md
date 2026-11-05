---
tier: guardrail
paths:
  - "**/*.{wl,wls,m}"
---

# .wl エンコーディング安全制約

## ノートブック出力コードの日本語 (最重要)
- ClaudeQuery / ClaudeEval が生成するコード（```mathematica ブロック内）では、**日本語文字を必ずリテラル UTF-8 でそのまま書く**。
- `\xNN` エスケープは**絶対禁止**。例: `"\x4e00\x81f4"` → `"一致"` と書く。
- `\uXXXX` エスケープも禁止。例: `"\u30d1\u30c3\u30b1\u30fc\u30b8"` → `"パッケージ"` と書く。
- `\:XXXX` はノートブックコードでは使わない（.wl パッケージファイル内でのみ許可）。
- この規則は Style テキスト、Grid ヘッダー、エラーメッセージ、Print 文など全ての文字列に適用。

## .wl パッケージファイルの Unicode エスケープ
- .wl ファイルでは日本語を `\:XXXX` 形式で書くことが許容される（Windows ShiftJIS 対策）。
- `\uXXXX` と `\xNN` を .wl に書かない。Mathematica が認識するのは `\:XXXX` のみ。
- 既存の `\:XXXX` は壊さない。
- コメント `(* ... *)` 内でも `\x` は混入させない。

## RegularExpression の二重エスケープ
- `\\\\s`, `\\\\n`, `\\\\t`, `\\\\w`, `\\\\d`, `\\[` 等の過剰エスケープを入れない。
- .wl 上で `\\s` が PCRE の `\s` になることを意識する。

## 日本語変数名
- `\b` のワード境界に依存しない。
- `[A-Za-z]`, `[A-Za-z0-9]` 等の ASCII 前提パターンを使わない。
- 日本語変数名の識別子境界には `[\\p{L}\\p{N}$]` の lookaround を使う。

## JSON 文字列をファイルに書き込むときのエンコード (最重要・実証済み)

JSON を文字列化する 2 つの API は**戻り値のエンコードが異なる**。これを取り違えると二重エンコードで日本語が文字化けする。`ToCharacterCode` で実証済み (result7.nb)。

| API | 戻り値の中身 | ファイル書き込みエンコード |
|-----|------------|------------------------|
| `ExportString[expr, "RawJSON"]` | 各 codepoint が **UTF-8 byte の Latin-1 表現** (`"今"` → `228,187,138`) | **`StringToByteArray[json, "ISO8859-1"]`** |
| `Developer`WriteRawJSONString[expr]` | **通常の Unicode 文字列** (`"今"` → `20170`) | **`StringToByteArray[json, "UTF-8"]`** |

- **`ExportString["RawJSON"]` の戻りを `StringToByteArray[json, "UTF-8"]` で書くと二重 encode** になり、`ã` だらけに化ける。`ISO8859-1` (1 codepoint = 1 byte) で書けば、String 内部の UTF-8 byte がそのままファイルに落ち、読み取りの `ByteArrayToString[..., "UTF-8"]` と整合する。
- **`Developer`WriteRawJSONString` の戻りは逆**で、通常 Unicode なので `UTF-8` で書くのが正しい (`ISO8859-1` だとマルチバイトが落ちる)。
- 読み取りは両方とも `ReadByteArray` → `ByteArrayToString[..., "UTF-8"]` (または `ImportByteArray[..., "RawJSON"]`)。

### 鉄則

- `ExportString[..., "RawJSON"]` を使ったら**書き込みは必ず `ISO8859-1`**。
- ASCII のみのデータでは二重 encode でも値が変わらず**バグが顕在化しない**。日本語 (パス・Memo・プロンプト等) が入って初めて化けるので、ASCII テストだけで通すと見逃す。新規 JSON 書き込みを足すときは最初から正しいエンコードにする。
- このバグは**文字化けだけでなく二次被害**を生む: 化けたファイルを読み込むと JSON パース時の Association 化が崩れ、後段で `Lookup::invrl` 等の別エラーになる (SaveLastPrompt で発生・実証)。文字化けを直すと連鎖エラーも消える。

### 実際にあった取り残し (Stage 9 P1.5、JSON utf8fix 横断修正)

model-registry 系は既に `ISO8859-1` だったが、以下が `UTF-8` のまま取り残され文字化けしていた。全て `ISO8859-1` に統一して解消:
- `SourceVault_promptrouter.wl`: `prompt-route-registry.json` 書き込み / `prompt-runs.jsonl` 書き込み
- `SourceVault.wl`: `iDirRepoWriteJSON` (DirRepo JSON)
- `claudecode.wl`: cloud-send preflight ログ JSONL
- `ClaudeOrchestrator_promptworkflow.wl`: workflow code メタ JSON (`iCPWAtomicWriteString` にエンコード引数を追加し、ExportString 由来のみ `ISO8859-1`、通常文字列は `UTF-8` に分離)

問題なし (正しい使い方) と確認できたもの:
- `claudecode_directives.wl` `iWriteJSONFile`: `Developer`WriteRawJSONString` + `UTF-8` (通常 Unicode なので正しい)
- Codex プロンプト / TOML / バッチコマンド / SKILL.md 等の通常文字列 + `UTF-8`

### 検出コマンド

```bash
# ExportString["RawJSON"] の近くで UTF-8 書き込みしている疑わしい箇所
grep -n 'StringToByteArray\[[^,]*, *"UTF-8"\]' *.wl
# ヒットしたら、書く文字列が ExportString["RawJSON"] 由来か WriteRawJSONString 由来か確認:
#   ExportString["RawJSON"] 由来 → ISO8859-1 に直す
#   WriteRawJSONString 由来 / 通常文字列 → UTF-8 のままで正しい
```

## CellEvaluationFunction が受け取る Text セル本文のエスケープ (最重要・2026-11-05 の実測で訂正)

FE は Text 系スタイルの evaluatable セル (例: スタイルシートの ClaudeInput) を評価するとき、`CellEvaluationFunction` の第 1 引数を**文字列で**渡す。書式付きセルもインライン数式入りのセルも文字列で、非 ASCII は実文字でなく**エスケープ表記**で届く: あ は `\:3042`、↓ は `\[DownArrow]`、× は `\[Times]`、絵文字は `\|01f600`、制御文字は `\.07`。

- **バックスラッシュは倍化されない。** `C:\temp` も `\\srv` もそのまま届く (NotebookPut のセル・カーソル位置への挿入・保存して開き直したセルで確認)。
- **この文字列は曖昧。** セルの `C:\` + あ と、文字どおりの `C:\\:3042` が同じ綴りで届く。`\\` を `\` に縮める復号は `\\srv` を `\srv` に、`C:\日本語` を `C:\:65e5...` に壊す。
- これを無変換で `ClaudeEval[task]` 等に渡すと、保存プロンプト (prompt-route-registry.json の Matcher.Examples)・PromptHash・LLM プロンプトの全てにエスケープ表記が伝播する（2026-06-12 に実害、registry 9 件を修復済み）。
- 対策: 評価関数の中で **`NotebookRead[EvaluationCell[]]` でセルを直接読む** (実文字が返り、曖昧さがない)。インライン数式など直接読めないセルだけ、文字列の全エスケープを復号して使う。実装は `claudecode.wl` の `iChatCellText`。スタイルシートの評価関数は読み取りを持たず、これを呼んでから `ClaudeEval` に渡す。
- `ExportPacket` の `"PlainText"` と `"InputText"` も文字を書き換える (↓ → `\[DownArrow]`、全角空白 → `\:3000`、× → `*`、≥ → `>=`)。セルの文字は式から直接読み、組版ボックスの部分だけ書き出させる。ノートブックの文章を取るときは `NBAccess`NBCellGetText` を使う (文字列の部分は実文字のまま)。`NBCellReadInputText` はコード解析用で InputText 形式を返す。
- スタイルシートの `.nb` はテキストエディタで書き換えない (バイト位置のキャッシュがずれる)。FE で開いて `NotebookWrite` し `NotebookSave` する。`Visible -> False` で開いたまま保存すると、その指定がファイルに残るので、保存の前に `SetOptions[nb, Visible -> Inherited]` する。

- 検証ハーネスの罠 (#28 関連): `ImportString[unicode文字列, "RawJSON"]` は文字コード > 255 で "Out of range Unicode code point" を出して失敗する。JSON 読み取りの検証・実装は `Developer`ReadRawJSONString[content]` を第一選択にする（SourceVault.wl `iLoadRegistryEntries` と同じ 3 段フォールバック）。
