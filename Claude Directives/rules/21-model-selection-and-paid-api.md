---
paths:
  - "**/{claudecode,NBAccess,SourceVault,Cerezo}*.{wl,wls,m,nb}"
  - "**/*Claude*.{wl,wls,m,nb}"
  - "**/*Model*.{wl,wls,m,nb}"
  - "**/*LLM*.{wl,wls,m,nb}"
---

# モデル選択と課金 API の鉄則

LLM を呼ぶコード・シーム（`$CerezoGradeLLMFn` のような "prompt -> response" フック含む）を書く・直すときの、モデル選択の絶対制約。

## 必須

- **既定は privacy level に従って `$ClaudeModel` / `$ClaudePrivateModel` を使う。** 何の指示もない場合、モデルは実行時の PrivacyLevel から解決する:
  - `0 <= PrivacyLevel < 0.5` → **`$ClaudeModel`**（cloud-safe クラス。課金が禁止なら Claude Code CLI 経由、許可時のみ API）
  - `PrivacyLevel >= 0.5` → **`$ClaudePrivateModel`**（ローカル/private LLM）
  - 実装上は `ClaudeQuerySync[prompt, PrivacyLevel -> pl]`（`Model -> Automatic`）や `ClaudeResolveModel` 系の privacy 対応ルータに委ねる。自前でモデルを決め打ちしない。
- **既定以外のモデルを使うときは、コードと応答に明記して切り替える。** 特定 provider/model の直接指定、別チャネル（下記 `LLMSynthesize` 等）の使用は、「なぜ既定を外れるか」を書いたうえで明示的に指定する。黙って別モデルへ流さない。
- **課金 API 許可フラグは、あらゆるモデル選択の決定を支配する。** `NBAccess`NBGetNotebookPaidAPIAllowed[nb]`（既定 `False` = 禁止、新規ノートブックは常に禁止）が禁止なら、どんなモデル指定・どんな PrivacyLevel 経路であっても課金 API へは送らない。ローカル/CLI/private のみを使う。フラグは privacy level より上位の最終ゲートである。

## 禁止

- **`LLMSynthesize` / `LLMFunction` を「既定のモデル呼び出し」として使う。** これらは Wolfram の LLM 基盤（Wolfram AI Access 等）という **Claude Code とは別チャネル**で、パレットの「ルート」設定にも課金 API 許可フラグにも従わない。LLM シームは必ず `ClaudeQuerySync`（またはそれ相当の privacy/課金対応ルータ）に向ける。
- **モデル枝番（`claude-opus-4.8` / `gpt-5` 等の具体 version 名）を分岐条件やシームに直書きする。** rule 02 の通り、Provider（anthropic / openai / lm-studio …）と Class（Heavy/Mid/Light × Cloud/Local）で判定し、具体名は `$ClaudeModelCapabilities` のテーブル登録に閉じる。
- **課金 API 許可を PrivacyLevel から導出・上書きする。** `PrivacyLevel < 0.5` は「cloud-safe な内容」を意味するだけで、課金送信の許可ではない。許可は課金 API フラグだけが決める（rule: `Do not derive cloud send permission from PrivacyLevel < 0.5`）。

## 判断

- 「クラウドの方が賢い/速い」「`LLMSynthesize` の方が手軽」は、既定モデルを外れる理由にならない。明示指示があるときだけ切り替える。
- **`$ClaudePrivateModel` が指す先が localhost とは限らない。** `llamacpp` のように LAN 上の別ホストで動く provider を private スロットに入れている場合、PrivacyLevel >= 0.5 の内容がネットワークへ出る。その可否はネットワークの信頼判断であり rule 107 が支配する。
- どのチャネル・どのモデルに送られるか確信が持てないシームは、送信前に経路を確認する（現に `$CerezoGradeLLMFn` を `LLMSynthesize` にしたため、パレットで Claude Code CLI・課金 API 禁止を選んでいたのに Wolfram AI Access が呼ばれ、未サポートモデルで全件失敗した事故がある）。
