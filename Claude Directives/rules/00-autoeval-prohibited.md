---
paths:
  - "**/*.{wl,wls,m,nb}"
---

# 自動実行禁止操作 (AutoEvaluate 禁止リスト) — 最優先ルール

> **このルールはすべてのルール・スキルに優先する。例外は一切認めない。**

## 概要

ClaudeQuery / ClaudeEval / ContinueEval が `AutoEvaluate -> True` で自動実行するコードには、
**セキュリティ境界・アクセス範囲・認証情報・セキュリティ設定を変更する操作を含めてはならない。**
これらの操作はユーザーが手動でセルを評価する場合にのみ許可される。

## 絶対禁止操作

以下の操作は AutoEvaluate で実行されるコードに **いかなる理由・文脈でも含めてはならない**。
コードレベルのガードにより、`NBEvaluatePreviousCell` が自動実行前にセル内容を検査し、
禁止操作を検出した場合は評価をブロックする。

### 1. 保護対象定数の変更

以下の定数への代入 (`=`)、`AppendTo`、`PrependTo` は禁止。

**claudecode.wl の定数:**

| 定数 | 役割 |
|---|---|
| `$ClaudeModel` | 使用する Claude モデル |
| `$ClaudePrivateModel` | ローカル LLM モデル設定 |
| `$ClaudeTestModel` | テスト用モデル |
| `$ClaudeFallbackModels` | フォールバックモデルリスト |
| `$ClaudeAccessibleDirs` | Claude Code がアクセス可能なディレクトリ |
| `$ClaudeDocMaxRetries` | ドキュメント生成最大リトライ数 |
| `$ClaudeEvalMaxDepth` | ClaudeEval 再帰深さ上限 |

**NBAccess.wl の定数:**

| 定数 | 役割 |
|---|---|
| `$NBPrivacySpec` | デフォルトのプライバシーレベル |
| `$NBConfidentialSymbols` | 機密変数テーブル |
| `$NBSendDataSchema` | 機密依存データのスキーマ送信制御 |
| `$NBSeparationIgnoreList` | 分離検査の除外パッケージリスト |

```mathematica
(* ❌ 絶対禁止: AutoEvaluate コード内で保護対象定数を変更 *)
$ClaudeAccessibleDirs = {...}
AppendTo[$ClaudeAccessibleDirs, dir]
$ClaudeModel = "different-model"
$NBPrivacySpec = <|"AccessLevel" -> 1.0|>
$ClaudeEvalMaxDepth = 100
$NBConfidentialSymbols = <||>
```

### 2. `ClaudeAttach` の実行

```mathematica
(* ❌ 絶対禁止: AutoEvaluate コード内でセッションにファイルをアタッチ *)
ClaudeAttach["path/to/file"]
```

**理由**: `ClaudeAttach` はセッションのコンテキストにファイルを追加し、
以降のすべての LLM 呼び出しにそのファイル内容が送信される。

### 3. `SystemCredential` の使用

```mathematica
(* ❌ 絶対禁止: AutoEvaluate コード内で認証情報にアクセス *)
SystemCredential["ANTHROPIC_API_KEY"]
SystemCredential["GITHUB_TOKEN"] = "..."
```

**理由**: `SystemCredential` はシステムに保存された認証情報（API キー等）への
直接アクセスを提供する。LLM が自動生成したコードで認証情報を読み書きすると、
意図しない情報漏洩や認証情報の改竄が発生しうる。
API キーの取得は `NBAccess`NBGetAPIKey` 経由で行うこと（`rules/20-api-key-security.md` 参照）。

## 判断基準

### このルールが適用される場面

- `ClaudeEval["指示", AutoEvaluate -> True]` が生成するコード
- `ContinueEval[]` が自動評価するコード
- `ClaudeQuery` の応答としてノートブックに書き込まれ `AutoEvaluate -> True` で評価されるコード
- `RepeatInterval` による定期実行コード

### このルールが適用されない場面

- ユーザーが手動で Input セルに記述し、Shift+Enter で評価する場合
- `AutoEvaluate -> False`（デフォルト）で出力され、ユーザーが内容を確認してから手動評価する場合

## コード生成時の対応

禁止操作がタスクの達成に必要な場合、AutoEvaluate で実行せず、
**ユーザーに手動実行を促すコードとして出力** すること。

```mathematica
(* ✅ 正しい対応: AutoEvaluate = False で出力し、説明を添える *)
(* 以下のコードはセキュリティ設定を変更するため、内容を確認してから手動で実行してください *)
AppendTo[$ClaudeAccessibleDirs, "F:\\Data\\Project"]
```

## 実装

コードレベルのガードは2層で構成される:

1. **claudecode.wl**: `$iAutoEvalProhibitedPatterns` に禁止パターン (RegularExpression) を定義。
   パッケージロード時に `NBAccess`$NBAutoEvalProhibitedPatterns` に登録。
2. **NBAccess.wl**: `NBEvaluatePreviousCell` が実行前にセル内容を検査し、
   禁止パターンにマッチする場合は `SelectionEvaluate` を呼ばず警告を表示。

この2層構造により、claudecode.wl 内のどの実行パスを通っても
`NBEvaluatePreviousCell` がバイパス不可能な最終防衛線として機能する。

## 将来の拡張

このリストは必要に応じて拡張される。`$iAutoEvalProhibitedPatterns` に
RegularExpression を追加するだけで、すべての AutoEvaluate パスに自動的に適用される。
