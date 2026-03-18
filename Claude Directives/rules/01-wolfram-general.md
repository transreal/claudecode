---
paths:
  - "**/*.{wl,wls,m,nb}"
---

# Wolfram Language 基本制約

## 言語選択
- 実装言語は Wolfram Language を優先する。
- Python 連携が必要なら `ExternalFunction` / `ExternalEvaluate` 系を優先する。

## 禁止事項
- `ffmpeg` のパスをハードコードしない。
- 出力コードで `session` で始まる変数名を使わない。
- サンプルコードで `Clear["Global`*"]` や `Remove["Global`*"]` を使わない。
- ShiftJIS を前提にした実装を新たに入れない。
- Notebook スタイルで `Section` は使わない（`Subsection` / `Item` / `Text` を使う）。
- ファイルパスの操作に `StringReplace`/`StringDrop`/`StringSplit` 等の文字列関数を使わない。必ず `FileNameJoin`/`FileNameSplit`/`FileNameTake`/`FileNameDrop`/`DirectoryName` 等の専用関数を使う（詳細は `rules/50-file-path.md`）。

## 数式の保持
- 数値が本当に必要になるまで、式は記号的に保持する。
- ベクトル・行列はベクトル・行列の形のまま処理する。

## ノートブック出力のスタイル規約
- **システムからのエラー・警告・進捗メッセージ**は `NBAccess`NBWritePrintNotice[nb, text, color]` で表示する（Print セルスタイル・小さめフォント）。通常の Text セルや Input セルとしてユーザーの作業領域に出力しない。
- ユーザーへの最終的な回答（テキスト説明・コードブロック）のみを `NBWriteCell`/`NBWriteText`/`NBWriteSmartCode` で通常セルとして出力する。
- エラーレスポンスを検出した場合（`iIsAPIErrorResponse` や `"Error"` で始まるレスポンス）は、コールバックの冒頭で早期に通知スタイル表示してリターンし、通常のテキスト/コード処理をスキップする。
