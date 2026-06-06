---
name: maildb-operations
description: Use when the user asks about email, mail, メール, 〆切, deadline, 受信, inbox, 返信, reply, IMAP, or references a mail database (univ, hu2022, apple, etc.). 正準システムは SourceVault mail サブシステム (SourceVault_maildb.wl, context SourceVault`): SourceVaultMailEnsureLoaded / SourceVaultMailView / SourceVaultSearchMailSnapshots / SourceVaultInferMailDerivedBatch / SourceVaultMailFetchNew / SourceVaultRegisterMailAccount。旧 maildb.wl は maildb_legacy.wl に改名され参照専用 (mailEnsureLoaded/showMails/searchFromMails/mailAskLLM は新規コードで使わない)。Security routing: privacy > 0.5 は $ClaudePrivateModel (ローカル LLM)。
---

# メール操作ガイド (正準: SourceVault mail サブシステム)

## ⛔ 最重要: メールは SourceVault mail サブシステムを使う

**メール操作のコードは `SourceVault\`` context の関数で生成する。**

- ❌ `Needs["Maildb\`"]` / `mailEnsureLoaded` / `showMails` / `searchFromMails` / `mailAskLLM` は**使わない**。`maildb.wl` は廃止され `maildb_legacy.wl` (参照専用) に改名済み。`Maildb\`` パッケージはロードできない。
- ✅ `SourceVaultMailEnsureLoaded` → `SourceVaultMailView` / `SourceVaultSearchMailSnapshots` を使う。

関数名が不確実なら **`Get`/`Import` でファイルを読まず**、`Names["SourceVaultMail*"]` で検索し、`SourceVault_info/docs/api_maildb.md` を参照する (rule 13)。

## 基本ワークフロー (2 段)

1. **ロード** (月シャード単位の増分・キャッシュ付き): `SourceVaultMailEnsureLoaded[mbox, period]`
2. **表示 / 検索** (ロード済み snapshot を絞り込み): `SourceVaultMailView[query, opts]` / `SourceVaultSearchMailSnapshots[query, opts]`

```mathematica
(* univ の 2026年6月分シャードをロードしてから 6/5〜6/6 を一覧 *)
SourceVaultMailEnsureLoaded["univ", "202606"];
SourceVaultMailView["", MBox -> "univ",
  DateFrom -> DateObject[{2026, 6, 5}], DateTo -> DateObject[{2026, 6, 6}],
  Newest -> True]
```

## 主要関数

### `SourceVaultMailEnsureLoaded[mbox, period]`
メモリへ増分ロード。何度呼んでも高速。`<|Status, MBox, Period, Shards, NewlyLoaded, InMemory|>` を返す。
**period 受理形式**:
- `"Latest"` または `Automatic` — 直近 (最新) の月シャード
- `"YYYYMM"` — その月のシャード (例 `"202606"`)
- `{"YYYYMM", "YYYYMM"}` — 月の範囲
- `n` (正整数) — 直近 n か月分
- `All` — 全シャード

(注: `{年,月}` の整数リストや `DateObject` は EnsureLoaded の period には**使わない**。月は `"YYYYMM"` 文字列で渡す。)

### `SourceVaultMailView[query, opts]` / `SourceVaultMailDataset[query, opts]`
ロード済み snapshot を**対話表 Dataset** (✉本文 / 📎添付 / ↩返信 ボタン付き) で表示。`SourceVaultMailDataset` はプレーン Dataset。`query` は件名/要約の部分文字列 (空文字 `""` で全件)。
opts (= `SourceVaultSearchMailSnapshots` と同一):
- `MBox -> "univ"` — メールボックス
- `DateFrom` / `DateTo` — `DateObject` / 文字列 / `{y,m,d}`。**日単位の包含比較** (`DateFrom=DateTo=同日` で当日が一致)
- `Newest -> True` — 新着 (日付降順)
- `Limit -> n` — 件数上限
- `From`, `FromContact`, `HasAttachment`, `MinPriority`/`MaxPriority`, `MinPrivacy`/`MaxPrivacy`, `SortBy`, `SortOrder`

### `SourceVaultSearchMailSnapshots[query, opts]`
件名/要約の部分一致 + 各種フィルタで snapshot リストを返す (表示用の生データ)。opts は上記と同じ。

### `SourceVaultInferMailDerivedBatch[opts]`
未処理メールの派生 (WorkRequest / PrivacyLevel / Summary) をローカル LLM で増分生成・in-place 更新 (中断耐性)。opts: `Limit` (既定50、範囲全部なら `Infinity`), `DateFrom`/`DateTo` (日付範囲で対象を限定), `CheckpointEvery`, `Persist`。

### `SourceVaultMailFetchNew[mbox, opts]`
IMAP から新着取得。opts: `Period` (`{年,月}` / `"YYYYMM"` / `"YYYY"` / n日 / `{from,to}`), `Overwrite`, `Process -> False` (LLM 派生を分離)。

### 返信 (自動送信しない)
`SourceVaultMailComposeReply[recordId, opts]` (返信ドラフト生成) / `SourceVaultMailOpenReplyNotebook[recordId]` (返信ノートブックを開く)。

### アカウント登録
`SourceVaultRegisterMailAccount[<|"MBox","User","CredKey","Server","Port"|>]` → vault config。ログイン情報をソースにハードコードしない (rule 03)。

## 典型的なユーザー要求 → 生成コード

| 要求 | コード |
|---|---|
| 「今日の univ メール」 | `SourceVaultMailEnsureLoaded["univ", "Latest"]; SourceVaultMailView["", MBox->"univ", DateFrom->DateObject[Take[DateList[],3]], Newest->True]` |
| 「2026/6/5〜6/6 の univ メール」 | `SourceVaultMailEnsureLoaded["univ", "202606"]; SourceVaultMailView["", MBox->"univ", DateFrom->DateObject[{2026,6,5}], DateTo->DateObject[{2026,6,6}], Newest->True]` |
| 「2026年3月のメール」 | `SourceVaultMailEnsureLoaded["univ", "202603"]; SourceVaultMailView["", MBox->"univ", DateFrom->DateObject[{2026,3,1}], DateTo->DateObject[{2026,3,31}], Newest->True]` |
| 「直近3か月のメール」 | `SourceVaultMailEnsureLoaded["univ", 3]; SourceVaultMailView["", MBox->"univ", Newest->True]` |
| 「研究費に関するメールを検索」 | `SourceVaultMailEnsureLoaded["univ", "Latest"]; SourceVaultMailView["研究費", MBox->"univ", Newest->True]` |
| 「重要メール一覧」 | `SourceVaultMailView["", MBox->"univ", MinPriority->0.7, Newest->True]` |
| 「公開メールのみ」 | `SourceVaultMailView["", MBox->"univ", MaxPrivacy->0.5, Newest->True]` |
| 「添付のあるメール」 | `SourceVaultMailView["", MBox->"univ", HasAttachment->True, Newest->True]` |
| 「新着を取得」 | `SourceVaultMailFetchNew["univ", Period->"202606"]` |
| 「範囲のメールの派生を生成」 | `SourceVaultInferMailDerivedBatch["DateFrom"->DateObject[{2026,6,5}], "DateTo"->DateObject[{2026,6,6}], "Limit"->Infinity]` |

## セキュリティルーティング (最重要)

snapshot の `Derived.PrivacyLevel` > 0.5 のメールは **`$ClaudeModel` (クラウド LLM) に送信しない**。`$ClaudePrivateModel` (ローカル LLM) で処理する。`SourceVaultSearchMailSnapshots[..., MaxPrivacy -> 0.5]` で公開メールのみに絞れる。

- 本文は暗号化・ヘッダ (件名/From/To/日付) は平文+token (件名は設計上暗号化しない)。
- 永続データの復号には `NBAccess\`$NBCredentialBackend = "SystemCredential"` が必須 (Memory backend だと別鍵で復号不可 = データ消失)。
- ScheduledTask 内で `ClaudeQuery` を呼ばない (rules/95)。

## 不変条件

- **重要度は構造計算**: LLM は依頼度 (WorkRequest) のみ判定。優先度は送信者グループ重み (`SourceVaultSetPriorityGroupWeight`) + To/Cc 位置 + ML 判定で `SourceVaultMailComputePriority` が決定的に計算する。
- **2層アドレス帳 (識別子/実体)**: 取込で From/To/Cc が自動識別子化。実体は後でマージ (`SourceVaultIdentityLinkUI` / `EntityEditUI`)。所有者 = ユーザDB #1 (`SourceVaultOwnerEntity`)。受信者プロフィールは所有者の `LLMProfile` から (ハードコードしない、rule 03)。

---

## (参照のみ) 旧 maildb_legacy 対応表

旧 `maildb.wl` は `maildb_legacy.wl` に改名済み。以下の旧 API は **`maildb_legacy.wl` を明示ロードした場合のみ有効**で、**新規コードでは使わない**。

| 旧 (maildb_legacy) | 新 (SourceVault) |
|---|---|
| `mailEnsureLoaded["univ"]` | `SourceVaultMailEnsureLoaded["univ", period]` |
| `showMails[mdb, opts]` | `SourceVaultMailView[query, opts]` / `SourceVaultMailDataset` |
| `searchFromMails[mdb, phrase, n]` | `SourceVaultSearchMailSnapshots[query, opts]` / `SourceVaultMailView` |
| `mailAskLLM[...]` | `SourceVaultInferMailDerivedBatch` + `SourceVaultMailComputePriority` |
| `updateMonthlyMaildb` / `checkNewMail` | `SourceVaultMailFetchNew[mbox, opts]` |
| `sendReply` / `sendReplyTr` | `SourceVaultMailComposeReply` / `SourceVaultMailOpenReplyNotebook` |
| `$maildbDescriptions` (ソース直書き) | `SourceVaultRegisterMailAccount[...]` → vault config |
