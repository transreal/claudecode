---
name: wolfram-general
description: Use for Wolfram Language / Mathematica coding, editing, notebook output style, package conventions, and overall implementation constraints in this environment. Especially relevant for .wl, .m, and .nb work.
---

# Wolfram Language 全般ルール

このスキルは Wolfram Language / Mathematica の作業全般で使う。

## コーディング方針

- 主言語は Wolfram Language とする。
- 新しい組み込み関数で自然に書ける場合は、古い回避策よりも最新の標準関数を優先する。
- Python 連携が必要なときは `ExternalFunction` / `ExternalEvaluate` を優先候補にする。
- Java 連携が必要なときは J/Link の利用を許容する。
- Notebook スタイルは `Subsection` / `Item` / `Subitem` / `Text` を優先し、`Section` は使わない。
- 文字コードは UTF-8 を前提に扱う。

## 数式・データ表現の方針

- 可能な限り、定義された数式をそのまま保持して関数を作る。
- 数値代入が本当に必要になるまでは、できるだけ記号式のまま処理する。
- ベクトル・行列を扱う場合は、可能な限りベクトル・行列表現を保ったまま計算する。

## 出力方針

- 説明は必要十分にとどめ、冗長にしない。
- 数式は省略せず明示する。
- 可能なら短い動作確認コードや最小例を添える。

## 全体禁止事項

- ffmpeg のパスをハードコードしない。
- ShiftJIS を前提にした実装を新たに入れない。
- `session` で始まる変数名を出力コードで使わない。
- サンプルコードで `Clear["Global`*"]` や `Remove["Global`*"]` のような全消去をしない。
- 物理 PDE を、自前の手書き差分式・有限差分・統計サンプリングで安易に置き換えない。

## 非同期タスクスケジューリング規約

- UI フィードバック（`WindowStatusArea`、`NotebookWrite`、`Dynamic` 等）を伴う非同期処理は、claudecode / NBAccess の公開 API を経由する。パッケージ側で個別に `CreateScheduledTask` を作成しない。
- 例外: FrontEnd 通信を一切行わない純粋計算タスク、またはリアルタイム対話が必要なインタラクティブプログラム（PresentationListener 等）では独自 ScheduledTask を許可する。ただしドキュメントに明記すること。
- 理由: 複数の ScheduledTask が同時に FrontEnd 操作を行うと「動的評価の放棄」ダイアログが発生しシステムがフリーズする。

## パッケージロード時のメッセージ

ロード完了メッセージは `CellPrint` ではなく `Print` を使う。タイトルは `Style[..., Bold]` で強調し、一覧は改行つき文字列で出す。

```mathematica
Print[Style["Mypackage パッケージがロードされました。", Bold]];
Print["
  func1[arg]   → 説明1
  func2[arg]   → 説明2
"];
```

## ファイルパス解決方針

- ファイル名だけが指定された場合（フルパスでない場合）は、`FileNameJoin[{NotebookDirectory[], ファイル名}]` でパスを構築する。
- `NotebookDirectory[]` が取得できない場合のフォールバックとして `Quiet @ Check[NotebookDirectory[], $packageDirectory]` を使う。
- `Import["ファイル名"]` のようにカレントディレクトリ依存のコードを生成しない。

## データ出力方針

- テーブル形式でデータを最終的に出力する場合は、可能な限り `Dataset` 形式で出力する。

## Excel インポート方針

- Excel ファイルを `Import` するとき、形式（`"XLSX"`, `"Dataset"` 等）によらず、シートが 1 枚だけの場合は結果に `First` または `[[1]]` を付けてリストを外す。
  - 例: `Import[file, "Dataset"] // First`
  - 例: `Import[file, {"XLSX", 1}]`
- シート数が不明な場合は `First @ Import[...]` をデフォルトとする。
