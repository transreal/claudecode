---
name: ocr-backend-design
description: |
  SourceVault.wl Stage 4C で実装した 3 backend OCR 設計 (ClaudeVision / TextRecognize /
  Custom) と、その診断機構 (OCRAttempted / OCRFailReasons / $SourceVaultOCRVerbose)
  の skill。PDF page を Image 化して LLM や native OCR に流すパッケージを書くときの
  テンプレ。PDFIndex.wl の OCR パターン (上下分割 + 30px overlap) を踏襲。
---

# OCR Backend 設計 (Stage 4C パターン)

## 設計原則

ユーザが OCR backend を選択できる構造にする:

| Backend | 用途 | 依存 |
|---|---|---|
| **`"ClaudeVision"`** | 高品質 OCR (日本語論文・数式に強い) | claudecode.wl (CLI または API)、API キー (anthropic provider のみ) |
| **`"TextRecognize"`** | オフライン fallback、Python・ネット不要 | Mathematica のみ |
| **`"Custom"`** | ユーザが任意の OCR/Vision API を hook で差し込み | (任意) |

固定 backend (Tesseract 等) を直書きしない。Tesseract がインストールされていない環境で
パッケージが動かなくなる、Tesseract の lang pack 管理が煩雑、等のリスクを避ける。
**`Custom` backend の存在が柔軟性を保証**する: OpenAI GPT-4V、Gemini Vision、Anthropic SDK
直叩きなど、ユーザが自前で hook を実装すれば任意 OCR が使える。

## API 構造

```mathematica
SourceVaultOCREnable[backend_String:"ClaudeVision", opts:OptionsPattern[]] :=
  Module[{params, normalizedMode},
    params = Association[FilterRules[{opts}, Options[SourceVaultOCREnable]]];
    normalizedMode = ...;  (* "Auto" | "Force" *)
    Switch[backend,
      "ClaudeVision", (* claudecode 存在チェック → hook 関数生成 *) ...,
      "TextRecognize", (* hook 関数生成 *) ...,
      "Custom", (* ユーザ Function を hook に注入 *) ...,
      _, <|"Status" -> "Failed", "Reason" -> "UnknownBackend"|>]];

SourceVaultOCRDisable[] := (
  $SourceVaultOCRHook = None;
  $SourceVaultOCRBackend = "Disabled";
  $SourceVaultOCRMode = "Auto");

SourceVaultOCRStatus[] := <|
  "Backend" -> ..., "Mode" -> ..., "Verbose" -> ...,
  "HookSet" -> (Head[$SourceVaultOCRHook] === Function),
  "ClaudeQueryBgAvailable" -> (Length[Names["ClaudeCode`ClaudeQueryBg"]] > 0),
  ...|>;
```

`$SourceVaultOCRHook` は **`Function[req_Association, _String]`** 型で:

- 入力: `<|"RawPath" -> _String, "Page" -> _Integer, "SnapshotId" -> _|>`
- 出力: OCR 結果テキスト (空文字なら失敗扱い)、`"Error: ..."` で始まる文字列はエラー扱い

## 発火条件 (Mode + ForceOCR)

```mathematica
shouldCallOCR = (ocrHook =!= None && Head[ocrHook] === Function) && (
  TrueQ[forceOCR] ||                  (* 単発 ForceOCR フラグ *)
  mode === "Force" ||                 (* 永続 Mode=Force *)
  iIsPDFLikelyScanned[text]           (* Plaintext < 5 文字 *)
);
```

- **`"Auto"` (デフォルト)**: Plaintext 抽出が 5 文字未満 (= スキャン PDF 判定) でのみ OCR
- **`"Force"`**: 全 page で OCR (低品質テキスト層 PDF 用)、`SourceVaultOCREnable[..., "Mode" -> "Force"]` で永続化
- **`"ForceOCR" -> True`** (`SourceVaultExtractPages` の option): 単発で OCR 強制、cache も bypass

## Page rasterization (2 段階 fallback)

```mathematica
iRasterizePagePDF[rawPath, page, dpi] :=
  Module[{img},
    img = iRasterizePagePDF$PyMuPDF[rawPath, page, dpi];   (* 優先 *)
    If[ImageQ[img], Return[img]];
    iRasterizePagePDF$Native[rawPath, page, dpi]            (* fallback *)
  ];
```

- **PyMuPDF (Python + fitz)**: 300 DPI レンダリング、画質安定、Windows での Wolfram `Import` の癖を回避
- **Wolfram native**: `Import[rawPath, {"PageGraphics", page}]` → `Rasterize[..., ImageResolution -> dpi]`
  または `Import[rawPath, {"ImageList", page}]`

```python
# PyMuPDF 経路 (ExternalEvaluate["Python", ...] で呼ぶ)
import fitz
doc = fitz.open(r'<path>')
pix = doc[<page-1>].get_pixmap(dpi=<dpi>)
pix.save(r'<imgFile>')
doc.close()
```

## ClaudeVision backend: 上下分割パターン (PDFIndex 踏襲)

大きな page は 1 枚で送ると Claude のサイズ制限 (~1568px) に当たる。PDFIndex.wl の
`iOCRPageWithClaudeVision` パターンを踏襲して **上下 2 分割 + 30px overlap** で OCR:

```mathematica
dims = ImageDimensions[img];
halfH = Round[dims[[2]] / 2];
topImg = ImageTake[img, {1, halfH + 30}];     (* 上半分 + 30px *)
botImg = ImageTake[img, {halfH - 30, dims[[2]]}];  (* 下半分 + 30px *)

topText = Quiet[
  Block[{ClaudeCode`$iMediaMaxImageSize = 1568},
    ClaudeCode`ClaudeQueryBg[{prompt, topImg},
      NonBlocking -> True, Timeout -> timeout]]];
(* 同じく botText *)

merged = StringTrim[topText] <> "\n" <> StringTrim[botText];
```

`SplitHalves -> False` オプションで分割を無効化可能 (小さい page では分割不要)。

## 診断機構: OCRAttempted / OCRFailReasons / Verbose

OCR が「呼ばれていないように見える」「沈黙で失敗」を防ぐため、戻り値で **試行と成功を区別**:

```mathematica
res = SourceVaultExtractPages[snapId, {1}, "ForceOCR" -> True];

res["OCRCalled"]         (* OCR 成功? Boolean *)
res["OCRUsed"]           (* 成功 page 数 Integer *)
res["OCRAttempted"]      (* 試行したか Boolean *)
res["OCRFailReasons"]    (* 失敗理由のリスト *)
res["CacheStats"]["OCRAttempted"]  (* 試行 page 数 *)
```

**判別表**:

| OCRAttempted | OCRCalled | 意味 |
|---|---|---|
| False | False | hook 不発火 (Auto モードかつ text 充足) — 期待通り or Mode/ForceOCR 指定漏れ |
| True | False | hook 呼ばれたが失敗 — `OCRFailReasons` を見る |
| True | True | OCR 成功、cache に保存 |

`OCRFailReason` の値:

- `"EmptyOrWhitespaceResponse"` — API が空文字
- `"HookReturned$Failed"` — `$Failed` を返した
- `"HookReturnedFailure"` — `Failure[...]` を返した
- `"HookReturnedNonString:Symbol"` — 想定外の Head
- `"Error: ..."` — API/CLI からの実エラーメッセージ (Phase 4C-diagnostics でそのまま伝播)

## Verbose モード

```mathematica
SourceVaultOCREnable["ClaudeVision", "Verbose" -> True]
(* または *)
SourceVault`$SourceVaultOCRVerbose = True;
```

Print 出力で:

```
[SourceVault OCR] page 1: plaintext extracted (1787 chars)
[SourceVault OCR] page 1: shouldCallOCR=True (mode=Force, forceOCR=False, isScanned=False)
[SourceVault OCR] page 1: calling hook...
[ClaudeVision] rasterizing page 1 at 300 DPI...
[ClaudeVision] rasterized: {2092, 3000}
[ClaudeVision] OCRing top half...
[ClaudeVision] top returned: 753 chars
[ClaudeVision] OCRing bottom half...
[ClaudeVision] bottom returned: 1088 chars
[SourceVault OCR] page 1: hook returned String(1842 chars)
```

各段階の所要時間と戻り値が見えるので、デバッグが容易:

- `rasterized: {...}` 出れば画像化成功
- `top returned: 0 chars` や `$Failed` → API 呼出問題
- `rasterization FAILED` → PDF 解析問題

## サニタイズ: trap #16 の踏みかえ

PDFIndex の OCR コードは `Quiet @ Check[expr, $Failed]` パターンを多用するが、これは **罠 #16** (Quiet@Check の false-negative)。SourceVault Stage 4C で移植したときは:

```mathematica
(* ❌ trap #16: $Failed false-negative *)
img = Quiet @ Check[Import[rawPath, {"PageGraphics", page}], $Failed];
If[img =!= $Failed && Head[img] === Graphics, ...]

(* ✓ Quiet 単独 + 型チェック *)
img = Quiet[Import[rawPath, {"PageGraphics", page}]];
If[Head[img] === Graphics, ...]
```

ClaudeQueryBg の戻り値も同様: `$Failed` 判定でなく **型チェック (`StringQ`) + 内容判定 (`StringStartsQ[..., "Error:"]`)** で判定する。

## テンプレ: 新規 OCR backend を作る場合

```mathematica
(* 1. backend 関数定義 *)
iOCRViaMyBackend[req_Association, params_Association] :=
  Module[{rawPath, page, img, result},
    rawPath = Lookup[req, "RawPath", ""];
    page = Lookup[req, "Page", 1];
    img = iRasterizePagePDF[rawPath, page, Lookup[params, "DPI", 300]];
    If[!ImageQ[img], Return["Error: rasterization failed"]];
    
    (* ここで自分の API / OCR エンジンを呼ぶ *)
    result = MyOCRCall[img];
    
    Which[
      !StringQ[result], Return["Error: non-string response"],
      StringTrim[result] === "", Return[""],
      True, Return[StringTrim[result]]
    ]
  ];

(* 2. SourceVaultOCREnable から呼べるようにする *)
(* Switch の case を追加するか、"Custom" backend で hook 注入 *)
SourceVaultOCREnable["Custom", "Hook" -> iOCRViaMyBackend[#, <||>] &]
```

## 適用タイミング

- PDF/Image OCR を持つ新パッケージ: この skill のテンプレで設計を始める
- 既存 OCR コードで「呼ばれていない」と思える時: 診断機構 (OCRAttempted/Verbose) を必ず先に入れる
- 沈黙の失敗 (Quiet 内): "Error:" 文字列の伝播 + Verbose Print の二重化が必須
- PDFIndex 由来コードを移植する時: `Quiet@Check` を全部 `Quiet[expr]` + 型チェックに書き換え

## 関連

- skill `claudecode-cli-vision`: ClaudeVision backend が依存する Phase 35 修正
- skill `wolfram-syntax-pitfalls`: 罠 #16 (Quiet@Check)
- rules/97-pdfindex.md: PDFIndex の OCR/cli-vision task descriptor
- SourceVault.wl `SourceVaultExtractPages` / `SourceVaultOCREnable` 実装
