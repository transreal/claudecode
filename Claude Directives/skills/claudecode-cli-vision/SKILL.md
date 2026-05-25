---
name: claudecode-cli-vision
description: |
  claudecode.wl の Claude Code CLI 経路 (provider == "claudecode") で multimodal /
  vision API (Image・PDF page 画像 OCR 等) を使うときの設計と動作パターン。
  Phase 35 で `iClaudeQueryBgAPIMultimodal` に CLI リダイレクトが追加され、
  $ClaudeModel = {"claudecode", "..."} のまま画像 OCR が無課金で動くようになった
  仕組み。SourceVault.wl Stage 4C OCR (ClaudeVision backend) で実証済み。
---

# claudecode CLI 経由の Vision / Multimodal

## 背景

claudecode.wl は次の 4 つの provider を `$ClaudeModel = {provider, model}` で区別する:

| provider | 経路 | 課金 |
|---|---|---|
| `claudecode` | Claude Code CLI (Pro/Max サブスクリプション内) | なし |
| `anthropic` | Anthropic API 直叩き | あり |
| `openai` | OpenAI API | あり |
| `lmstudio` | ローカル LLM | なし |

Phase 28 (2026-05-12) で provider tuple 化されたが、**vision/multimodal は anthropic API
経路のみ実装**されていた。Phase 35 (2026-05-18) で **claudecode CLI 経路にも vision
が回るよう**になった。

## Phase 35 修正の構造

`iClaudeQueryBgAPIMultimodal[items_List, modelSpec_, timeoutSpec_]` の provider 判定直後に
1 行追加するだけ:

```mathematica
provider = Which[
  ListQ[modelSpec] && Length[modelSpec] >= 2 && StringQ[modelSpec[[1]]], modelSpec[[1]],
  ListQ[$ClaudeModel] && Length[$ClaudeModel] >= 2 && StringQ[$ClaudeModel[[1]]], $ClaudeModel[[1]],
  True, "anthropic"
];
providerLower = ToLowerCase[provider];

(* Phase 35 fix (2026-05-18): provider == "claudecode" は CLI 経路へリダイレクト *)
If[providerLower === "claudecode",
  Return[iClaudeQueryRawNonBlocking[items, timeoutSpec]]];

(* multimodal は現時点 Anthropic のみ対応 (claudecode は上で処理済み) *)
If[providerLower =!= "anthropic",
  Return["Error: multimodal API は現在 Anthropic または Claude Code CLI (provider 'claudecode') のみ対応..."]];
```

## なぜこれで動くのか — `iNormalizePrompt` の既存実装

claudecode.wl の `iNormalizePrompt[items_List]` には **元々画像対応の実装が入っていた**:

1. `Image[...]` オブジェクトを tmp dir に PNG として書き出し
2. `mediaFiles` リスト構築
3. prompt text に「添付ファイル: <path>」として埋め込む
4. `imageDirs` を `iMakeBat` 経由で `--add-dir <path>` として Claude CLI に渡す
5. Claude Code CLI は prompt 内の画像ファイル参照を自動認識して vision 処理

つまり**インフラは完成していたが、`iClaudeQueryBgAPIMultimodal` が claudecode を弾いていた**だけ。1 行のリダイレクトで実装が活きた。

## 呼出側のコード例 (PDFIndex / SourceVault 流)

呼出側 (SourceVault Stage 4C `iOCRViaClaudeVision`) は何も変更不要:

```mathematica
result = Quiet[
  Block[{ClaudeCode`$iMediaMaxImageSize = 1568},
    ClaudeCode`ClaudeQueryBg[
      {prompt, img},
      NonBlocking -> True,
      Timeout -> 180]]];
```

- **`Block[{$iMediaMaxImageSize = 1568}]`**: API 制限 (Anthropic 1568px) と同じ値で CLI 経路も
  リサイズ。CLI 自身に上限はないが、無駄に大きな PNG を CLI に渡しても遅くなるだけ
- **`NonBlocking -> True`**: フロントエンドをブロックしない経路 (ScheduledTask 不要、CLI に直接 invoke)
- 戻り値は **String** (OCR 結果テキスト) または `"Error: ..."` 文字列

## 性能特性

実測 (SourceVault.wl, Stage 4C ClaudeVision backend, page 1 of arXiv 1992-WOOC):

- PyMuPDF rasterization (page → PNG 300 DPI): ~0.7 秒
- 上半分 OCR: ~15 秒
- 下半分 OCR (30px overlap): ~19 秒
- **合計 35 秒/page**

Anthropic API 直叩きより遅いが、**無課金**で動く実用範囲。複数 page を OCR する場合は
SourceVault の Phase 4B cache でその後の操作は瞬時。

## エラーパターン

### Pre-Phase 35: claudecode で multimodal を呼ぶと即エラー

```
Error: multimodal API は現在 Anthropic のみ対応しています。
詳細: provider 'claudecode' の multimodal API 形式 (例: OpenAI は image_url 方式) は
iClaudeQueryBgAPIMultimodal ではサポートされていません。
```

Phase 35 以降このエラーは出ない (`Return[iClaudeQueryRawNonBlocking[items, timeoutSpec]]` で先取り)。

### Post-Phase 35: 起こりうるエラー

CLI 経路は次のように失敗しうる:

- **Timeout**: 大きな画像 + 長い prompt で 180 秒超過 (`"Error: タイムアウト (180秒)"`)
- **CLI 自体の問題**: `claude` コマンドが PATH にない、サブスクリプション切れ
- **画像 PNG エクスポート失敗**: `iResizeImageObj` で Quiet[Export[..., "PNG"]] が失敗

呼出側 (SourceVault) は `iOCRViaClaudeVision` 内で `StringStartsQ[result, "Error:"]` で
判定し、`OCRFailReason` フィールドに記録する。

## 制約

- **stream-json モードでは vision 未検証** (Phase 30.1 で導入された CLI モード)
- **Anthropic API キーが必要なケース**は依然存在: `$ClaudeModel = {"anthropic", ...}` で
  指定すれば直接 API、CLI を経由しない (より高速、ただし課金)
- **モデル切替**: `claudecode` での model 指定 (e.g. `{"claudecode", "claude-opus-4-7"}`) は
  CLI の `--model` フラグに反映される

## 検証手順 (リグレッション防止)

```mathematica
ClaudeCode`$ClaudeModel = {"claudecode", "claude-sonnet-4-6"};

(* 画像 1 枚を vision に流す *)
img = Rasterize[Plot[Sin[x], {x, 0, 2 Pi}], ImageResolution -> 100];
result = ClaudeCode`ClaudeQueryBg[
  {"What does this image show? Reply in one sentence.", img},
  NonBlocking -> True, Timeout -> 60];

StringQ[result] && StringLength[result] > 10 && !StringStartsQ[result, "Error:"]
(* True なら Phase 35 が正しく機能している *)
```

## 関連

- skill `ocr-backend-design`: SourceVault Stage 4C の 3 backend 設計、ClaudeVision はこの skill の hook
- rules/97-pdfindex.md: PDFIndex の `cli-vision` task category、ScheduledTask 経由の OCR 呼出
- claudecode.wl Phase 35 ChangeLog (header 53-62 行)
