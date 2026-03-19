---
name: maildb-operations
description: Use when the user asks about email, mail, メール, 〆切, or references a mail database (univ, hu2022, apple, etc.). Covers all maildb.wl API usage patterns. Critical: showMails/searchFromMails require a MailDBObject, NOT a string mbox name. Always use mailEnsureLoaded for cached loading.
---

# maildb パッケージ操作ガイド

## 最重要原則: ロードは一度だけ、絞り込みは Select で

メールDBは `mailEnsureLoaded` で**一度だけキャッシュ付きロード**し、日付・条件の絞り込みは `showMails` のオプションや `Select` で行う。`loadMailFiles` を異なる Period で繰り返し呼んではならない。

```mathematica
(* ✅ 正しいパターン: キャッシュ付きロード → 条件で絞り込み *)
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

## 日付・条件で絞り込むパターン

MailDBObject の `"dataset"` フィールドは Dataset であり、Select で自由に絞り込める。showMails は Dataset も受け取れる。

```mathematica
(* 今日のメールだけ表示 *)
mdb = mailEnsureLoaded["univ"];
today = DateObject[DateList[][[1 ;; 3]]];
showMails[mdb["dataset"][Select[#date >= today &]]]

(* 今週のメール *)
weekStart = DatePlus[Now, -Quantity[1, "Week"]];
showMails[mdb["dataset"][Select[#date >= weekStart &]]]

(* k.imai が To か Cc に含まれ、かつ〆切のあるメール *)
showMails[mdb["dataset"][Select[
  (StringContainsQ[#to, "k.imai", IgnoreCase -> True] ||
   StringContainsQ[#cc, "k.imai", IgnoreCase -> True]) &&
  StringContainsQ[#summary, "〆切"] &]]]

(* 特定の差出人からの今週のメール *)
showMails[mdb["dataset"][Select[
  #date >= weekStart && StringContainsQ[#from, "kaneko"] &]]]
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
showMails[mdb]                                        (* 一覧表示 *)
showMails[mdb, MaxItems -> 20]                        (* 件数制限 *)
showMails[mdb, MinPriority -> 0.7, HasDeadline -> True]  (* 重要+〆切 *)
showMails[mdb, Include -> <|"subject" -> "会議"|>]     (* フィルタ *)
showMails[mdb["dataset"][Select[...]], MaxItems -> 30]  (* Select で絞り込み *)
```

Options: MaxItems, Include, MinPriority, MaxPriority, MinPrivacy, MaxPrivacy, HasDeadline

### セマンティック検索 — searchFromMails[mdb, phrase, n, opts]

```mathematica
searchFromMails[mdb, "研究費", 30]
searchFromMails[mdb, "会議の日程", 20, HasDeadline -> True]
```

### LLM による分析 — mailAskLLM[mbox, question, opts]

**mailAskLLM は mbox 文字列を直接受け取る（内部で mailEnsureLoaded を呼ぶ）。**

```mathematica
mailAskLLM["univ", "〆切作業の一覧を日付順にまとめて",
  Period -> Quantity[1, "Week"], HasDeadline -> True, IncludeBody -> True]
```

Options: Period, MaxItems, MinPriority, HasDeadline, IncludeBody

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

## 典型的なユーザー要求 → 生成コードのパターン

| ユーザーの要求 | 正しいコード |
|---|---|
| 「今日のunivメールを表示」 | `mdb = mailEnsureLoaded["univ"]; today = DateObject[DateList[][[1;;3]]]; showMails[mdb["dataset"][Select[#date >= today &]]]` |
| 「今週のメールで〆切のあるもの」 | `mailAskLLM["univ", "〆切作業の一覧", Period -> Quantity[1, "Week"], HasDeadline -> True]` |
| 「研究費に関するメールを検索」 | `mdb = mailEnsureLoaded["univ"]; searchFromMails[mdb, "研究費", 20]` |
| 「今月のメールを更新して」 | `updateMonthlyMaildb["univ"]` |
| 「univの重要メール一覧」 | `mdb = mailEnsureLoaded["univ"]; showMails[mdb, MinPriority -> 0.7]` |
| 「金子先生からの今週のメール」 | `mdb = mailEnsureLoaded["univ"]; showMails[mdb["dataset"][Select[#date >= DatePlus[Now, -Quantity[1,"Week"]] && StringContainsQ[#from, "kaneko"] &]]]` |
| 「k.imaiがTo/Ccの〆切メール」 | `mdb = mailEnsureLoaded["univ"]; showMails[mdb["dataset"][Select[(StringContainsQ[#to,"k.imai",IgnoreCase->True] \|\| StringContainsQ[#cc,"k.imai",IgnoreCase->True]) && StringContainsQ[#summary,"〆切"] &]]]` |

## mbox 名

利用可能な mbox 名は `$maildbDescriptions` で確認できる。一般的には `"univ"`, `"hu2022"`, `"apple"` など。

## 注意事項

- `showMails` / `searchFromMails` に文字列 mbox 名を渡すと何も起きず未評価で返る。必ず `mailEnsureLoaded` で MailDBObject を取得してから渡すこと。
- `mailAskLLM` は例外的に mbox 文字列を直接受け取る（内部でロードを行う）。
- 日付・条件の絞り込みは `mdb["dataset"][Select[...]]` で行い、loadMailFiles を Period を変えて何度も呼ばない。
- api.md が存在する場合はそちらも参照すること。
