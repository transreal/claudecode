# 97-pdfindex.md — PDFIndex パッケージ連携ルール

## 概要

`PDFIndex.wl` は PDF 文書のインデクシングと多層検索を提供するパッケージ。
`maildb.wl` と同一のアーキテクチャ (embedding + keyword ハイブリッド検索、公開/秘密分離) を採用。

## ストレージルール

| PrivacyLevel | 保存先 | LLM処理 |
|---|---|---|
| ≤ 0.5 | `$packageDirectory/claude_attachments/pdfindex/<collection>/` | クラウドLLM OK |
| > 0.5 | `$dropbox/udb/pdfindex/<collection>/` | `$ClaudePrivateModel` のみ |

## ClaudeEval/ClaudeQuery からの利用

PDF 関連のプロンプト（「論文」「PDF」「文書検索」等）が含まれる場合、
以下の API を使用すること:

```mathematica
(* 検索して回答 *)
pdfAskLLM["reversible computing の基本ゲートは?"]

(* 検索結果をプロンプトに変換（公開/秘密分離済み） *)
sr = pdfSearchForLLM["query", MaxItems -> 20]
(* sr["public"]["prompt"] → クラウドLLM用 *)
(* sr["private"]["prompt"] → $ClaudePrivateModel用 *)

(* ハイブリッド検索のみ *)
results = pdfSearch["query", 20, Collection -> "papers"]
```

## Privacy ルール

- `pdfSearchForLLM` は `NBGetProviderMaxAccessLevel["claudecode"]` を参照して
  公開/秘密の閾値を決定する
- 秘密チャンクのプロンプトには本文テキストを含めない（サマリーのみ）
- クラウド LLM に秘密チャンクのテキストを送信してはならない

## インデクシング

```mathematica
(* 単一PDF: Privacy自動推定 *)
pdfIndex["path/to/file.pdf"]

(* 明示的Privacy指定 *)
pdfIndex["path.pdf", Privacy -> 0.8, Collection -> "internal"]

(* ディレクトリ一括 *)
pdfIndexDirectory["/path/to/pdfs", Collection -> "papers"]

(* URL から *)
pdfIndexURL["https://arxiv.org/pdf/xxxx.pdf", Keywords -> {"CA", "reversible"}]
```

## ScheduledTask 安全性

- `pdfSearch`, `pdfSearchForLLM` は `URLRead` ベースの同期HTTP処理のみ使用
- FrontEnd 通信なし → SocketListen ハンドラ内から安全に呼び出し可能
- `pdfAskLLM` は `NBAccess`NBWriteCell` を使用するため、
  SocketListen 内からは直接呼ばず、`ClaudeQueryBg` 経由で使用すること

## 非同期インデクシング: LLMGraph DAG

`pdfIndexAsync` は claudecode の LLMGraph DAG フレームワーク (`LLMGraphDAGCreate`) を使用:

- Phase 0（同期）: テキスト抽出・ページ分類・チャンキング（OCR はスキップ）
- Phase 1（非同期 DAG）: 文字化けOCR → rechunk → LLM要約 → Embedding保存
- `$iPdfTaskDescriptor` でカテゴリマッピングを定義:
  - `"render"` → `"process"`, `"ocr"` → `"cli-vision"`, `"summarize"` → `"cli"`
- 独自 ScheduledTask は使用しない（`rules/95-scheduled-task-safety.md` セクション C に準拠）

## WebServer 統合

パッケージロード時に WebServer が利用可能なら自動登録:
- `GET /pdfsearch?q=...&collection=default` → HTML検索フォーム + 結果
- `POST /pdfsearch/api` → JSON API
