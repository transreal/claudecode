---
name: maildb-operations
description: Use when the user asks about email, mail, メール, 〆切, deadline, 受信, inbox, 返信, reply, IMAP, or references a mail database (univ, hu2022, apple, etc.). Covers all maildb.wl API usage patterns. Critical: showMails/searchFromMails require a MailDBObject, NOT a string mbox name. Always use mailEnsureLoaded for cached loading. Security routing: メールの privacy > 0.5 は $ClaudePrivateModel に分配。
---

# maildb パッケージ操作ガイド

## セキュリティルーティング（最重要）

**メールの privacy フィールド（セキュリティレベル）の値に基づき、処理を分配する。**

- `privacy <= 0.5` → `$ClaudeModel`（クラウド LLM）で処理可能
- `privacy > 0.5` → **$ClaudePrivateModel（ローカル LLM）で処理必須**。`$ClaudeModel` に投入してはならない。

### ClaudeEval/ClaudeQuery からメール処理コードを生成するとき

**privacy > 0.5 のメールを含む可能性がある操作（デフォルト）:**

```mathematica
(* ✅ MinPrivacy/MaxPrivacy を指定しない一般的なメール操作は
   privacy > 0.5 のメールを含む可能性がある。
   AutoPrivate -> True の場合: Model/PrivacySpec は自動付与される。
   AutoPrivate なしの場合: 明示的に Model/PrivacySpec を付与する。 *)
mdb = mailEnsureLoaded["univ"];
showMails[mdb, MaxPriority -> 1.0]
```

**privacy <= 0.5 のメールのみに限定する場合:**

```mathematica
(* ✅ MaxPrivacy -> 0.5 で公開メールのみに絞り込む → $ClaudeModel で安全 *)
mdb = mailEnsureLoaded["univ"];
showMails[mdb, MaxPrivacy -> 0.5]
```

**mailAskLLM でセキュリティを考慮:**

```mathematica
(* ✅ mailAskLLM は内部でセキュリティレベルに基づきモデルを自動分配する *)
mailAskLLM["univ", "今週の〆切を教えて", Period -> Quantity[1, "Week"]]

(* ✅ 公開メールのみの分析: MaxPrivacy -> 0.5 を指定 *)
mailAskLLM["univ", "会議の予定", MaxPrivacy -> 0.5]
```

**ScheduledTask 内での注意（rules/95-scheduled-task-safety 参照）:**

```mathematica
(* ❌ ScheduledTask 内で ClaudeQuery を呼んではならない *)
(* ✅ LLMSynthesize（公開メール）または URLRead（秘密メール→ローカルLLM）を使う *)
```

## 最重要原則: ロードは一度だけ、絞り込みは Select/Period で

メールDBは `mailEnsureLoaded` で**一度だけキャッシュ付きロード**し、日付・条件の絞り込みは `showMails` のオプション（`Period` 含む）や `Select` で行う。`loadMailFiles` を異なる Period で繰り返し呼んではならない。

```mathematica
(* ✅ 正しいパターン: キャッシュ付きロード → Period オプションで絞り込み *)
mdb = mailEnsureLoaded["univ"];
showMails[mdb, Period -> Quantity[1, "Week"]]

(* ✅ 正しいパターン: キャッシュ付きロード → Select で絞り込み *)
mdb = mailEnsureLoaded["univ"];
showMails[mdb["dataset"][Select[#date >= today &]]]

(* ❌ 間違い: Period を変えて何度もロードし直す *)
mdb = loadMailFiles["univ", Period -> Quantity[1, "Day"]];
```

## 重要: MailDBObject が必要な関数

**`showMails` と `searchFromMails` は MailDBObject を第一引数に取る。mbox 名の文字列を直接渡してはならない。**

```mathematica
(* ❌ 間違い — showMails は文字列を受け取らない *)
showMails["univ", MaxItems -> 20]

(* ✅ 正しい — 先に mailEnsureLoaded でロードする *)
mdb = mailEnsureLoaded["univ"];
showMails[mdb, MaxItems -> 20]
```

## API クイックリファレンス

### メール読み込み（キャッシュ付き — 推奨）

```mathematica
mdb = mailEnsureLoaded["univ"]                    (* デフォルト3ヶ月 *)
mdb = mailEnsureLoaded["univ", Quantity[6, "Month"]]  (* より長期間 *)
```

`mailEnsureLoaded` はキャッシュ済みならキャッシュを返す。何度呼んでも高速。

### メール読み込み（キャッシュなし — バッチ処理向け）

```mathematica
mdb = loadMailFiles["univ"]                              (* 全ファイル *)
mdb = loadMailFiles["univ", Period -> Quantity[3, "Month"]]
mdb = loadMailFiles["univ", Period -> 2026]              (* 年指定 *)
```

### メール表示 — showMails[mdb, opts] / showMails[dataset, opts]

```mathematica
showMails[mdb]                                           (* 一覧表示 *)
showMails[mdb, MaxItems -> 20]                           (* 件数制限 *)
showMails[mdb, Period -> Quantity[1, "Week"]]            (* 直近1週間 *)
showMails[mdb, Period -> Quantity[3, "Days"]]            (* 直近3日 *)
showMails[mdb, Period -> {2026, 3}]                      (* 年月指定 *)
showMails[mdb, Period -> {2026, 3, 16}]                  (* 日付以降 *)
showMails[mdb, MinPriority -> 0.7, HasDeadline -> True]  (* 重要+〆切 *)
showMails[mdb, Include -> <|"subject" -> "会議"|>]       (* フィルタ *)
showMails[mdb, MaxPrivacy -> 0.5]                        (* 公開メールのみ *)
showMails[mdb["dataset"][Select[...]], MaxItems -> 30]   (* Select で絞り込み *)
```

Options: MaxItems, Include, MinPriority, MaxPriority, MinPrivacy, MaxPrivacy, HasDeadline, **Period**

**Period オプション:**
- `Quantity[n, "Week"]`, `Quantity[n, "Day"]`, `Quantity[n, "Month"]` — 直近 n 期間
- `{year, month}` — 指定年月のメールのみ
- `{year, month, day}` — 指定日以降のメールのみ

### セマンティック検索 — searchFromMails[mdb, phrase, n, opts]

```mathematica
searchFromMails[mdb, "研究費", 30]
searchFromMails[mdb, "会議の日程", 20, HasDeadline -> True]
searchFromMails[mdb, "出張", 10, Period -> Quantity[1, "Month"]]
```

Options: HasDeadline, **Period**

### LLM による分析 — mailAskLLM[mbox, question, opts]

**mailAskLLM は mbox 文字列を直接受け取る（内部で mailEnsureLoaded を呼ぶ）。**
**内部でセキュリティレベルに基づきモデルを自動分配する。**

```mathematica
mailAskLLM["univ", "〆切作業の一覧を日付順にまとめて",
  Period -> Quantity[1, "Week"], HasDeadline -> True, IncludeBody -> True]
```

Options: Period, MaxItems, MinPriority, HasDeadline, IncludeBody, MaxPrivacy

### メール更新

```mathematica
updateMonthlyMaildb["univ"]                          (* 今月の差分更新 *)
batchUpdateMaildb["univ", {2026, 3}]                 (* LLM/embedding 再生成 *)
checkNewMail["univ", Period -> Quantity[2, "Hours"]]  (* 定期チェック *)
```

### 返信

```mathematica
sendReply["tagname"]                    (* 日本語で返信 *)
sendReplyTr["tagname"]                  (* 翻訳して返信（確認後送信） *)
confirmSendReplyTr["tagname"]           (* 翻訳返信を確定送信 *)
```

## 日付・条件で絞り込むパターン（Period オプションがないバージョン向けフォールバック）

MailDBObject の `"dataset"` フィールドは Dataset であり、Select で自由に絞り込める。showMails は Dataset も受け取れる。

```mathematica
(* 今日のメールだけ表示 *)
mdb = mailEnsureLoaded["univ"];
today = DateObject[DateList[][[1 ;; 3]]];
showMails[mdb["dataset"][Select[#date >= today &]]]

(* 今週のメール *)
weekStart = DatePlus[Now, -Quantity[1, "Week"]];
showMails[mdb["dataset"][Select[#date >= weekStart &]]]

(* 特定の差出人からの今週のメール *)
showMails[mdb["dataset"][Select[
  #date >= weekStart && StringContainsQ[#from, "kaneko"] &]]]
```

## 典型的なユーザー要求 → 生成コードのパターン

| ユーザーの要求 | 正しいコード |
|---|---|
| 「今日のunivメールを表示」 | `mdb = mailEnsureLoaded["univ"]; showMails[mdb, Period -> Quantity[1, "Day"]]` |
| 「今週のメール」 | `mdb = mailEnsureLoaded["univ"]; showMails[mdb, Period -> Quantity[1, "Week"]]` |
| 「今月のメール」 | `mdb = mailEnsureLoaded["univ"]; showMails[mdb, Period -> Quantity[1, "Month"]]` |
| 「3月16日から21日のメール」 | `mdb = mailEnsureLoaded["univ"]; showMails[mdb["dataset"][Select[DateObject[{2026,3,16}] <= #date <= DateObject[{2026,3,21}] &]]]` |
| 「2026年3月のメール」 | `mdb = mailEnsureLoaded["univ"]; showMails[mdb, Period -> {2026, 3}]` |
| 「今週のメールで〆切のあるもの」 | `mdb = mailEnsureLoaded["univ"]; showMails[mdb, Period -> Quantity[1, "Week"], HasDeadline -> True]` |
| 「研究費に関するメールを検索」 | `mdb = mailEnsureLoaded["univ"]; searchFromMails[mdb, "研究費", 20]` |
| 「今月のメールを更新して」 | `updateMonthlyMaildb["univ"]` |
| 「univの重要メール一覧」 | `mdb = mailEnsureLoaded["univ"]; showMails[mdb, MinPriority -> 0.7]` |
| 「金子先生からの今週のメール」 | `mdb = mailEnsureLoaded["univ"]; showMails[mdb["dataset"][Select[#date >= DatePlus[Now, -Quantity[1,"Week"]] && StringContainsQ[#from, "kaneko"] &]]]` |
| 「〆切のある重要メールをまとめて」 | `mailAskLLM["univ", "〆切作業の一覧を日付順にまとめて", Period -> Quantity[1, "Week"], HasDeadline -> True, IncludeBody -> True]` |
| 「公開メールのみ表示」 | `mdb = mailEnsureLoaded["univ"]; showMails[mdb, MaxPrivacy -> 0.5]` |

## $ClaudePackageKeywordMap への登録

maildb パッケージは初期化時に以下を実行して、ClaudeEval/ClaudeQuery のプロンプトに自動的に api.md が注入されるようにする:

```mathematica
(* maildb.wl の初期化セクション *)
If[AssociationQ[ClaudeCode`$ClaudePackageKeywordMap],
  ClaudeCode`$ClaudePackageKeywordMap["maildb"] =
    {"メール", "mail", "Mail", "univ", "〆切", "deadline",
     "受信", "inbox", "IMAP", "返信", "reply",
     "showMails", "searchFromMails", "mailAskLLM",
     "mailEnsureLoaded", "loadMailFiles", "updateMonthlyMaildb",
     "sendReply", "checkNewMail"}
];
```

## mbox 名

利用可能な mbox 名は `$maildbDescriptions` で確認できる。一般的には `"univ"`, `"hu2022"`, `"apple"` など。

## 注意事項

- `showMails` / `searchFromMails` に文字列 mbox 名を渡すと何も起きず未評価で返る。必ず `mailEnsureLoaded` で MailDBObject を取得してから渡すこと。
- `mailAskLLM` は例外的に mbox 文字列を直接受け取る（内部でロードを行う）。
- `Period` オプションが使えない古いバージョンでは `mdb["dataset"][Select[...]]` で日付絞り込みを行う。
- api.md が存在する場合はそちらも参照すること。
- **privacy > 0.5 のメールは絶対に $ClaudeModel（クラウド LLM）に送信しない。** $ClaudePrivateModel または mailAskLLM（自動ルーティング）を使用する。
