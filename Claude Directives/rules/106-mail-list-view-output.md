---
description: メール検索・一覧の最終出力は必ずメール専用 View (SourceVaultMailSearchIndexView / SourceVaultMailView) を使う。素の Dataset/Grid/Column で件名一覧を手組みしない
---

# 106 — メール一覧は SourceVaultMailSearchIndexView で出力する (手組み禁止)

**必須**: メール一覧の最終出力は `SourceVaultMailSearchIndexView[query, opts]` (✉本文/☰スレッド付き) か `SourceVaultMailView`。素の `Dataset`/`Grid`/`Column` で件名一覧を手組みしない (本文を開けない)。複数キーワード OR は query をリストに: `SourceVaultMailSearchIndexView[{"科研","KAKENHI"}, "MBox"->"univ", ...]`。自前 `Select` した行リストも `SourceVaultMailSearchIndexView[rows]` で表示する。

## 詳細

### 1. 一覧の最終出力は View 関数

- **索引 (sidecar) 検索** — `SourceVaultMailSearchIndexView[query, opts]`。
  シャード非ロードで高速。各行に ✉(本文表示・必要シャードのみ遅延ロード) /
  ☰(スレッドのアウトライン窓) ボタンが付く。
- **ロード済み snapshot** — `SourceVaultMailView[query, opts]`
  (`"Latest" -> 期間` で自動ロード、行アクション ✉/📎/↩ 付き)。

件数ヘッダ等の補足を View の上に `Column` で添えるのは可
(一覧本体だけ View にする)。件数の集計だけなら
`Length[SourceVaultMailSearchIndex[...]]` (core) で良い。

### 2. 複数キーワード (OR) はクエリのリスト形で

query は**文字列リスト**を受け付ける (件名/要約のいずれかに部分一致 = OR):

```mathematica
SourceVaultMailSearchIndexView[{"科研", "科研費", "KAKENHI", "学振"},
  "MBox" -> "univ", "DateFrom" -> DatePlus[Today, {-2, "Month"}],
  "Limit" -> Infinity]
```

キーワードごとに検索を繰り返したり、全件取得して自前 `Select` フィルタを
書く必要はない。

### 3. 自前フィルタした行リストも View に渡す

リスト query で表現できない絞り込みを `Select` 等で行った場合も、
最終表示は行リストをそのまま View へ渡す:

```mathematica
rows = SourceVaultMailSearchIndex["", "MBox" -> "univ", "Limit" -> Infinity];
hit  = Select[rows, (* 独自条件 *)];

SourceVaultMailSearchIndexView[hit]        (* ✅ 行リスト直渡し *)
Dataset[KeyTake[#, {"Date", "Subject"}] & /@ hit]  (* ❌ 手組み Dataset 禁止 *)
```

## 背景

result3/result6 (2026-08-11):「univの直近2か月間の科研に関するメール」で LLM が
自前 `Select` + 素の `Dataset` を生成し、✉/☰ の無い一覧になって
ユーザーが本文を参照できなかった。core/View 分離原則 (検索は連想リストを返す
core と Dataset+UI の View のペア) に従い、一覧の最終出力は View に統一する。
このインシデントを受けて query のリスト (OR) 対応と
`SourceVaultMailSearchIndexView[rows]` の行リスト直渡し形を追加済み。
本ルールは $ClaudeAlwaysOnRules 登録 (常時注入・Summary 投影は冒頭 400 字) の
ため、冒頭の**必須**段落だけで完結するよう書いてある。

## 関連

- `skills/maildb-operations` — メール操作の正準 API
- `rules/13-prefer-existing-functions.md` — 既存の定義関数を優先する
