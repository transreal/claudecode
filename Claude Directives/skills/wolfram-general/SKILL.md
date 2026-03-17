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

## Excel インポート方針（必須）

- Excel ファイルをインポートするときは、明示的に Table 等と指定されない限り **必ず `{"Dataset"}` 形式** で読み込む。
  1行目をキー（列名）として使用する。ただし、1行目からデータが始まっている場合（1行目と2行目以降が同じタイプの項目）であれば、キーを列番号で生成する。
- **シートが1枚の場合**（結果リストの長さが1）: `First @ Import[...]` でリストを外し、単一の Dataset を返す。
  - 例: `First @ Import[file, {"Dataset"}]`
- **シートが複数の場合**（結果リストの長さが2以上）: Dataset のリストとしてそのまま返す。
- 秘密変数として Excel を読み込むときは、`Confidential[...]` でラップした直後に、キー情報を `NonConfidential` で出力する。
