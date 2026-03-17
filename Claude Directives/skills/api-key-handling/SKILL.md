---
name: api-key-handling
description: Use when handling API keys, credentials, provider configuration, Anthropic or OpenAI calls, or any secret values in Wolfram Language code. Especially relevant for NBAccess.wl, claudecode.wl, PresentationListener.wl, and LLM-related files.
---

# API キー取得の正しい実装手順

制約は `rules/20-api-key-security.md` に従う。このスキルは正しい取得パターンを示す。

## 正しい取得例

```mathematica
Needs["NBAccess`", "NBAccess.wl"];
key = NBAccess`NBGetAPIKey["anthropic"];
openAIKey = NBAccess`NBGetAPIKey["openai", PrivacySpec -> ps];
```

## 禁止例

```mathematica
(* NG: 直接資格情報ストアへ触る *)
key = SystemCredential["ANTHROPIC_API_KEY"];

(* NG: ベタ書き *)
key = "sk-...";
```

## 実装チェックリスト

- API 呼び出しコードを書くときは `NBAccess.wl` の依存を確認したか。
- provider 名はコードベースで既に使っている表記に合わせたか。
- 失敗メッセージにキー断片を含めていないか。
- デバッグ時も値ではなく成功/失敗だけを出しているか。
- Notebook に結果を書き戻す場合にキー文字列を出力していないか。
