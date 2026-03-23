# 96 — Web 検索推奨ルール

## 概要

ClaudeEval / ClaudeQuery の応答において、モデル単体の知識では正確な回答が困難な場合に
WebSearch オプションの利用をユーザーに促すルール。

## 推奨条件

以下のいずれかに該当する場合、応答末尾に WebSearch 推奨メッセージを追加する:

1. **最新情報が必要**: 現在の日時、最新バージョン、最新ニュース、リアルタイムデータ
2. **API 仕様の確認**: 外部ライブラリ・サービスの最新 API、非推奨関数の代替
3. **具体的な数値データ**: 統計データ、為替レート、株価、物理定数の最新精度値
4. **URL・リンク**: 正確な URL が必要な場合（推測でリンクを生成してはならない）
5. **訓練データの限界**: 知識カットオフ以降のイベント・リリース・変更

## メッセージ形式

応答のコードブロック外（テキスト部分）に以下を追加:

```
最新の情報が必要な場合は WebSearch オプション付きで再実行してください:
  ClaudeEval["...", WebSearch -> True]
```

## 非推奨条件（メッセージを追加しない）

- 標準的な Mathematica プログラミング（組み込み関数の使い方等）
- 数学・物理学の基本理論
- パッケージ操作（ClaudeUpdatePackage 等）
- ノートブック内のデータ処理
- 既に `WebSearch -> True` で呼び出されている場合

## ContinueEval のオプション引き継ぎ

ClaudeEval 完了時に表示される ContinueEval リンクは、元の ClaudeEval 呼び出しで
指定されたオプション（デフォルトと異なるもののみ）を自動的に引き継ぐ。

例: `ClaudeEval["...", WebSearch -> False, Model -> "claude-sonnet-4-20250514"]`
→ ContinueEval リンク: `ContinueEval["", WebSearch -> False, Model -> "claude-sonnet-4-20250514"]`

デフォルト値と同じオプションは省略される（例: `WebSearch -> True` はデフォルトなので省略）。
