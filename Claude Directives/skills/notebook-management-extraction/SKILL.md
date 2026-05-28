---
name: notebook-management-extraction
description: |
  SourceVault.wl の Notebook Management / Prompt Router 拡張。Mathematica notebook を first-class
  source として扱い、先頭 Input セルから Header Association を HoldComplete + whitelist で safe parse、
  TodoItem cell を style 経由で列挙、TaggingRules や StrikeThrough を優先順位付きで Done 判定、
  7 種 lint で Header/Todo 不整合検出。
  **ノートブックの検索・一覧表示を扱う場合は必ずこのスキルを参照すること。** 具体的には:
  SourceVaultFindNotebooks による deterministic クエリ (OpenTodos / NextReview / Deadline /
  Keywords / Title / Status / Scope="Today")、キーワード/タイトルの部分一致と類義語展開
  (「会議」→「委員会」「教授会」等)、日付範囲での絞り込み (今日/今週/今月/N月)、
  SourceVaultFormatNotebookList によるスケジュール表と同形式の一覧表示 (Title/Dir に開くボタン)。
  **ClaudeEval が「ノートブックの一覧/リスト」「キーワード〜のノート」「今日の予定」「会議のノート」
  などを表示する式を生成するときの既定フォーマットと禁止パターンを規定。** 生 Association や
  自作 Dataset/Column ではなく SourceVaultFormatNotebookList で包む。
  さらに PromptRouter のプロンプト保存・検索・表示 (SaveLastPrompt / SourceVaultSearchPromptRoutes /
  SourceVaultFormatPromptRouteList) と Summary の言語・文体ルール、Publishable 等の表示文字列の
  言語非依存化 (Public/Private/Unspecified)、iSVResolvePath の名前空間の罠も扱う。
  notebooks/{sources,snapshots,todos,review,lint}/ の index 配置。
---

# Notebook Management Extension (Stage 9 P0)

「Mathematica notebook を SourceVault に first-class source として登録し、先頭 Input セルの
Header Association、TodoItem cell の Done 状態、Deadline / NextReview を deterministic に
扱えるようにする」最小実装。LLM や Notebook を開かずに、ファイルパース + heuristic だけで動く。

## 設計思想 — 探索 (LLM のブレ) と 活用 (保存された当たり) の分離

ClaudeEval の式生成にはブレ (非決定性) がある。これは**欠陥ではなく LLM の強み**であり、矯正の
対象ではない。多様な言い回しや未知のタスクに柔軟に対応できるのはこのブレのおかげである。

したがって「ノートブック一覧表示で ClaudeEval が毎回 `SourceVaultFormatNotebookList` を使うことを
機構側で強制する」ような介入は**しない**。代わりに次の二段構えで運用する:

- **探索 (exploration)**: ClaudeEval が自然言語からその場で式を生成する。下記 MUST ルール・
  類義語展開・`"Format" -> True` などは「当たりを出しやすくする」ための補助であって、強制ではない。
- **活用 (exploitation)**: うまく生成できたプロンプトと式は `SaveLastPrompt[memo]` で PromptRoute
  として保存し、以降は `SourceVaultSearchPromptRoutes` → `SourceVaultFormatPromptRouteList` の
  Run / ToInput で**確実に再利用**する。LLM の確率的生成に毎回賭けず、良い結果を資産化する。

これは強化学習の exploration / exploitation と同じ構図であり、**プロンプト保存機構 (SaveLastPrompt 等)
の存在意義はまさにここにある**。LLM のブレを潰すのではなく、ブレから生まれた良い結果を固定する。
将来ブレを見て「機構で強制すべきでは」と考えたくなっても、この方針 (探索は自由・活用は保存経由) を
崩さないこと。

なお、ClaudeEval が正しい式 (例: `SourceVaultFindNotebooks[..., "Format" -> True]`) を生成する
確率は、**ホストパッケージの api.md が最新であること**に強く依存する。api.md が古いと API シグネチャを
誤り、自作 Grid 等にフォールバックしやすい。新しい public API を足したら api.md を必ず更新する
(下記 MUST ルールや本スキルの記述だけでなく、ホスト側 api.md の整備が探索成功率を左右する)。

## ⚠️ 最重要 — ノートブック一覧を表示する式を生成するときの MUST ルール

ClaudeEval で「ノートブックの一覧/リスト」「キーワード〜のノート」「今日の予定」「会議のノート」
などを要求されたとき、**生成する Wolfram 式は以下を強く推奨する (探索の補助。強制ではない)。**

1. **表示は `SourceVaultFindNotebooks[..., "Format" -> True]` を使う。**
   `"Format" -> True` を付けると、結果がスケジュール表と同じ Grid (Title/Dir に開くボタン、
   Summary/Publishable 列) で返る。**自作 `Dataset` / `Column` / `Grid` / `TableForm` を組んではならない。**

   ```mathematica
   (* ✅ 正しい: 1 関数で完結 *)
   SourceVaultFindNotebooks["Keywords" -> {...}, "Format" -> True]

   (* ❌ 禁止: 自作 Dataset *)
   Dataset[Map[<|"Title" -> ..., "Path" -> ...|> &, hits]]
   ```

   Select で絞り込んでから表示したい場合は `SourceVaultFormatNotebookList` で包む
   (こちらは Format オプションと等価な表示関数):

   ```mathematica
   SourceVaultFormatNotebookList[
     Select[SourceVaultFindNotebooks["Keywords" -> {...}], 条件 &]]
   ```

2. **`Title` フィールドは戻り値に存在しない。`Lookup[#, "Title", ...]` を使うな。**
   record に `Title` キーは無い。使うと**全行が空欄**になる (これが「テーブルがおかしい」の
   典型原因)。表示は Format に任せるので、そもそも Title を手で取り出す必要はない。
   どうしても要るなら `FileBaseName[Lookup[#, "Path"]]`。

3. **キーワードは類義語展開する。**
   「会議」は部分一致では「学科会議」しか拾えず「委員会」「教授会」を取りこぼす。
   `"Keywords" -> {"会議", "委員会", "教授会", "ミーティング", "MTG", "打ち合わせ"}` のように OR 展開する。

4. **日付範囲は `"Deadline"` / `"NextReview"` の Association 指定を使う。**
   `<|"From" -> _, "To" -> _|>` を渡すと、**Header の Deadline/NextReview** または
   **ファイル名 `yyyymmdd-title.nb` の先頭日付**のいずれかが範囲内なら該当 (Stage 9 P1.5)。
   `FileDate["Modification"]` (ファイル更新日) は使わない。

   ```mathematica
   (* ✅ 今月 (2026-05) の会議系ノート、表形式表示 *)
   SourceVaultFindNotebooks[
     "Keywords" -> {"会議", "委員会", "教授会", "ミーティング", "MTG", "打ち合わせ"},
     "Deadline" -> <|"From" -> "2026-05-01", "To" -> "2026-05-31"|>,
     "Format" -> True]
   ```

   日付絞り込みが不要なら、もっと単純に:

   ```mathematica
   SourceVaultFindNotebooks[
     "Keywords" -> {"会議", "委員会", "教授会", "ミーティング", "MTG", "打ち合わせ"},
     "Format" -> True]
   ```

これらの詳細・例外・期間表現の解釈は本スキル後半の該当セクションに記載。**まず上の 4 つを守ること。**

## 設計の核心 — 3 つの分離

### (1) Header.Status と Todo cell 状態の独立保存

レビュー §1.3 の最重要 insight:

```
notebook 先頭 Header:        <|"Status" -> "Todo", ...|>
notebook 内 TodoItem cell:   FontVariations -> {"StrikeThrough" -> True}
                                                  ↓
                              cell 状態 = Done (取消線)
```

これらを **独立に保存** し、不整合を `HeaderStatusTodoButNoOpenTodos` lint として検出する。
「Header Status だけ見て notebook 状態を判定」は明確な anti-pattern。

実用上、Header Status は手動で書き換えるので忘れがち。Todo cell の状態は GUI 操作で変わる。
両者がズレることは自然に発生する。それを **deterministic な query で検出可能にする** のが
Stage 9 の主目的。

### (2) Deterministic index vs LLM 要約

```
Deterministic index (Stage 9 P0):
  - SourceVaultFindNotebooks["OpenTodos" -> True]
  - SourceVaultFindNotebooks["NextReview" -> "Overdue"]
  - SourceVaultFindNotebooks["Deadline" -> "ThisWeek"]
  - SourceVaultFindNotebooks["Keywords" -> {"オンライン語り交流会"}]
  → LLM 不要、低遅延、再現可能

LLM-backed summary (Stage 9 Phase 2 で実装予定):
  - SourceVaultNotebookSummary[nbRef]
  → body 要約、トピック抽出、関連 notebook 発見
```

P0 では deterministic 側だけ。これだけで「今週レビューすべき notebook」「Deadline 過ぎ未完了」
等の主要ユースケースを LLM 不要で処理できる。

### (3) Status 判定の優先順位 (StatusSource で追跡)

レビュー §3.4:

```
1. TaggingRules["TodoStatus"]       → StatusSource: "TaggingRules" (将来の標準)
2. FontVariations StrikeThrough     → StatusSource: "CellOption"   (現状の添付 notebook)
3. 何もなし                          → StatusSource: "Default"      (Open 扱い)
```

各 Todo record に `StatusSource` を保存することで、「TaggingRules への移行が必要な notebook」を
特定できる (`TodoCellStatusHeuristicOnly` lint で警告)。

## Safe Parse — Wolfram 標準関数優先で実装

**重要 (rule 102 と連動)**: ノートブック情報にアクセスする時は **必ず先に Wolfram 標準関数を探す**。パターンマッチは最終手段。Stage 9 P0 では試行錯誤の末、以下の組み合わせが正解と判明:

### Header 取得: `Import[path, "Initialization"]`

```mathematica
inits = Import[path, "Initialization"]
(* → {<|"Keywords" -> {...}, "Deadline" -> DateObject[{2026,5,13}, "Day"],
        "NextReview" -> ..., "Status" -> "Todo"|>} *)
assoc = First[inits];
(* whitelist 後付け検証 *)
If[!AllTrue[Values[assoc], iAllowedHeaderValueQ],
  parseStatus = "UnsafeExpression"];
```

**Safety トレードオフ**: `Import[path, "Initialization"]` は **InitializationCell の中身を評価** するため、副作用ある式が実行される可能性がある。しかし返り値の値レベルで whitelist 検証することで SourceVault 保存を防御。実用性優先の妥協。

### Todo 抽出: `NotebookImport[path, style -> "Cell"]`

```mathematica
cells = NotebookImport[path, "TodoItem_1" -> "Cell"]
(* → {Cell["参加登録", "TodoItem_1",
        FontVariations -> {"StrikeThrough" -> True},
        FontColor -> RGBColor[...], ...]} *)
```

これは **Wolfram の正規 API** で:
- パターンマッチ不要 (context 問題なし)
- `System`Cell[...]` が確実に返る
- ファイル全体を Get する必要なし
- 限定的なスタイルだけ取り出すので高速

`TodoItem_1`, `TodoItem_2`, `TodoItem_3` の 3 スタイルを順に試して結合。

### 第二フォールバック (Header): `MakeExpression`

`Import["Initialization"]` が失敗した場合、`Import[path, "Notebook"]` で Notebook 式取得 → cell 走査 → **`MakeExpression[boxData, StandardForm]`** で box → `HoldComplete[expr]` (評価せず):

```mathematica
boxData = First[headerCell];  (* BoxData[RowBox[{...}]] *)
held = MakeExpression[boxData, StandardForm];   (* HoldComplete[<|...|>] *)
```

**重要**: `ToString[box, StandardForm]` + `ToExpression[str, StandardForm, HoldComplete]` のラウンドトリップは box の意味を保てない (罠 #22)。`MakeExpression` が Wolfram の正規 box→expr 変換関数。

### 廃止: パターンマッチベースの実装

以下は **試行錯誤の過程で実装したが廃止** した経路:

```mathematica
(* NG #1: Get[path] でファイル全体を読む *)
nbExpr = Get[path];   (* FE 連携などの特殊挙動の可能性 (罠 #21) *)

(* NG #2: Import[path, "Text"] + ToExpression *)
expr = ToExpression[Import[path, "Text"], InputForm, HoldComplete];
(* コメント注釈 (*CacheID:...*) と Notebook[...] 式の混在で不安定 *)

(* NG #3: Cell[...] パターンマッチを package private context で書く *)
MatchQ[c, Cell[_, _String, ___]]
(* SourceVault`Private`Cell に解決されて System`Cell[...] と一致しない (罠 #23) *)
```

これらは全て試したが、Stage 9 P0 開発で順に動作不能が判明し、最終的に `NotebookImport` ベースに収束した。

## 7 種 Lint (添付 notebook で実演)

```text
1. MissingHeader                          - 先頭 cell が見つからない
2. UnsafeHeaderExpression                 - whitelist 違反
3. HeaderDeadlineMalformed                - Deadline が DateObject でない
4. HeaderNextReviewMalformed              - NextReview が DateObject でない
5. HeaderStatusTodoButNoOpenTodos         - Header Todo だが Todo cell 全部 Done (添付 notebook で発生)
6. HeaderStatusDoneButOpenTodosExist      - Header Done だが Todo cell 残あり
7. DeadlinePast                           - Deadline 過去 (添付 notebook で発生)
8. NextReviewPast                         - NextReview 過去 (添付 notebook で発生)
9. TodoCellStatusHeuristicOnly            - TaggingRules なし、StrikeThrough だけで判定 (添付で発生)
```

添付 `20260516-第14回オンライン語り交流会.nb` (2026-05-19 時点) では:

| Lint | 発生 |
|---|---|
| `HeaderStatusTodoButNoOpenTodos` | ✓ Header `"Status" -> "Todo"` だが Todo "参加登録" は StrikeThrough |
| `DeadlinePast` | ✓ Deadline 2026-05-13 < today 2026-05-19 |
| `NextReviewPast` | ✓ NextReview 2026-05-13 < today |
| `TodoCellStatusHeuristicOnly` | ✓ TaggingRules なし、StrikeThrough のみ |

これだけで「review dashboard 必須」と即判定可能。

## FindNotebooks クエリの仕様

```mathematica
SourceVaultFindNotebooks[
  "OpenTodos" -> True | False,
  "NextReview" -> "Today" | "Overdue" | "ThisWeek" | "DueSoon" | <|"From" -> _, "To" -> _|>,
  "Deadline"   -> "Today" | "Overdue" | "ThisWeek" | "DueSoon" | <|"From" -> _, "To" -> _|>,
  "Keywords" -> {_String, ...} | _String,  (* 部分一致、複数フィールド OR、Title と等価 *)
  "Title" -> {_String, ...} | _String,     (* Keywords のエイリアス、同じ検索プールを見る *)
  "Status" -> _String,             (* Header.Status と完全一致 *)
  "Scope" -> "Today"               (* 複合フィルタ。下記参照 *)
]
```

**NextReview / Deadline の値の意味** (`iComputeReviewState` / `iComputeDeadlineState` ベース):

| 値 | マッチする ReviewState / DeadlineState |
|---|---|
| `"Today"` | `"DueToday"` のみ (today と完全一致) |
| `"Overdue"` | `"Overdue"` のみ (today より前) |
| `"ThisWeek"` / `"DueSoon"` | `{"DueToday", "DueThisWeek" / "DueSoon", "Overdue"}` (今日+未来7日以内+期限切れ) |

`"Today"` は厳密に今日のみ。`"ThisWeek"` は今日+1週間+期限切れを含む広い範囲なので混同しない。

**`"Keywords"` / `"Title"` の検索仕様** (Stage 9 P1.5):

| 性質 | 動作 |
|---|---|
| 一致方式 | **`StringContainsQ` による部分一致** (`"会議"` → `"学科会議"` も拾う) |
| 検索プール | Header.Keywords の各文字列 + Header.Title + `FileBaseName[Path]` + 親フォルダ名 (`FileNameTake[DirectoryName[path], -1]`) |
| 複数指定 | List で渡すと OR (どれかにマッチすれば該当) |
| 両オプション同時指定 | `Keywords` と `Title` は `Join` されて同じプールに対して検索される (実質エイリアス) |

検索プールから **Path 全体は除外**している。`F:\Dropbox\On Work\...` の共通部分(`Work`、`Dropbox` など)で誤マッチするのを防ぐため。ファイル名と直近の親フォルダ名だけが対象。

例:

```mathematica
(* どちらも同じ結果。「会議」が Keywords/Title/ファイル名/親フォルダ名のどれかに
   部分一致するノートを返す *)
SourceVaultFindNotebooks["Keywords" -> {"会議"}]
SourceVaultFindNotebooks["Title" -> "会議"]

(* OR: 「会議」または「研究会」のどちらかにマッチ *)
SourceVaultFindNotebooks["Keywords" -> {"会議", "研究会"}]

(* AND が欲しい場合は Select で重ねがけ *)
Select[SourceVaultFindNotebooks["Keywords" -> {"会議"}],
  StringContainsQ[Lookup[#, "Path", ""], "教務"] &]
```

**`"Scope" -> "Today"` の意味** (Stage 9 P1.5):

次の OR を満たす record を抽出する複合フィルタ:

1. `ReviewState == "DueToday"` (NextReview が今日)
2. `DeadlineState == "DueToday"` (Deadline が今日)
3. Path 文字列が今日の日付 (YYYYMMDD 形式、例 `"20260528"`) を含む — フォルダ名やファイル名で「今日のもの」と表現された notebook を救う

**`NoReviewDate` / `NoDeadline` は「レビュー不要」とみなし含めない**。NextReview/Deadline 未設定のノートを「今日の予定」に勝手に紛れ込ませないための明示的なルール。フォルダ名/ファイル名に今日の日付を含むもの(3.)だけは例外として救う。

`OpenTodos` 等の他オプションと AND で組み合わせ可能:

```mathematica
SourceVaultFindNotebooks["OpenTodos" -> True, "Scope" -> "Today"]
(* 今日見るべき or 今日のフォルダにある、未完了 Todo つきの notebook *)
```

## ⚠ 戻り値に `Title` フィールドは含まれない

`SourceVaultFindNotebooks` の戻り値 record のキーは:

```
{Status, Cached, NotebookRef, SnapshotId, Path, Header, TodoCount,
 OpenTodoCount, DoneTodoCount, PassTodoCount, ReviewState, DeadlineState,
 Lint, IndexedAt, SourceMTime}
```

**`Title` は含まれない**(これは過去の usage 記載と実装の食い違い)。タイトル相当を取得する場合:

```mathematica
FileBaseName[Lookup[record, "Path"]]
```

を使う。`Lookup[record, "Title", ""]` で部分一致検索すると、常に空文字列にマッチして false negative になる(よくある事故)。

**重要な区別**:

```mathematica
SourceVaultFindNotebooks["OpenTodos" -> True]    (* 実作業残あり *)
SourceVaultFindNotebooks["Status" -> "Todo"]     (* Header メタデータ未更新 *)
```

添付 notebook は前者には含まれず、後者には含まれる。ダッシュボード設計では両者を別カラムに
表示すべき。

## 自然言語クエリ → 具体オプションのマッピング (ClaudeEval 経由の解釈)

ClaudeEval で日本語フリーテキストから `SourceVaultFindNotebooks` を呼ぶときの **既定マッピング**。
LLM が範囲を独自に拡大解釈すると Select 範囲が広がりすぎる事故が起きるので、以下の対応を厳密に守る:

| ユーザ表現 | 渡すオプション |
|---|---|
| 「今日の予定」「今日見るべきもの」「今日やること」 | `"OpenTodos" -> True, "Scope" -> "Today"` |
| 「今日が期限/締切」 | `"OpenTodos" -> True, "Deadline" -> "Today"` |
| 「今日 review すべきもの」(厳密) | `"NextReview" -> "Today"` |
| 「今週の予定」「今週レビュー」「7日以内」 | `"OpenTodos" -> True, "NextReview" -> "ThisWeek"` |
| 「今週の締切」「期限が近い」「もうすぐ deadline」 | `"OpenTodos" -> True, "Deadline" -> "ThisWeek"` |
| 「レビュー切れ」「レビューが過ぎている」「Overdue review」 | `"NextReview" -> "Overdue"` |
| 「締切切れ」「期限切れ」「Overdue deadline」 | `"Deadline" -> "Overdue"` |
| 「未完了 Todo がある notebook」「作業残あり」 | `"OpenTodos" -> True` |
| 「<キーワード> 関連の notebook」「<キーワード> を含むノート」 | `"Keywords" -> {<キーワード>}` |
| 「タイトルに <文字列> を含むノート」「<文字列> のノート」 | `"Keywords" -> {<文字列>}` (Title もこのプールに含まれる) |
| 「Header が Todo の notebook」(Open Todos の有無を問わず) | `"Status" -> "Todo"` |

**禁止事項**:

- 「今日の予定」を `"NextReview" -> "ThisWeek"` や `"OpenTodos" -> True` 単独で解釈しない (範囲が広すぎる)
- 「今日の予定」をオプション無し (= 全件取得) で解釈しない
- 複数条件を AND で組むときは、ユーザが明示的に求めた条件のみ。LLM 側で「ついでに OpenTodos も絞ろう」のような勝手な絞り込みをしない (false negative の原因)
- **`NoReviewDate` のノートに NextReview として「今日」や任意の日付を表示しない**。`NoReviewDate` は「レビュー不要」「特に今日見る必要なし」を意味する。表示用テンプレートで NextReview 列を埋める際は、`NoReviewDate` の場合は**空欄または「なし」と表示する**(`Missing` から `Today()` への自動変換は絶対にしない)。

複合表現の例:

- 「今日見るべき、Todo 残ありの notebook」 → `"NextReview" -> "Today", "OpenTodos" -> True`
- 「今日締切で兵站関連」 → `"Deadline" -> "Today", "Keywords" -> {"兵站"}`
- 「今日のフォルダ含めて今日のもの」 → `"OpenTodos" -> True, "Scope" -> "Today"` (デフォルトの「今日の予定」)

## キーワードの類義語展開 (Stage 9 P1.5)

`Keywords` の照合は **`StringContainsQ` による部分一致**だが、漢字熟語の場合は同じ概念でも文字列が一致しないことがある。例えば「会議」(2 文字)は「学科**会議**」には含まれるが、「教務委員**会**」「全学教授**会**」には含まれない (「委員会」「教授会」は別の漢字)。

LLM が自然言語のキーワード語を `Keywords` オプションに落とすときは、**意味的に等価な語を OR 展開して複数渡す**こと。展開しないと、ユーザーが期待する「会議」関連のノートを取りこぼす。

### 既定の類義語展開表

| ユーザー表現 | 展開後の Keywords List |
|---|---|
| 「会議」「ミーティング」「打ち合わせ」「打合せ」「集会」 | `{"会議", "委員会", "教授会", "ミーティング", "MTG", "打ち合わせ", "打合"}` |
| 「研究会」「セミナー」「ワークショップ」 | `{"研究会", "セミナー", "ワークショップ", "workshop", "seminar"}` |
| 「授業」「講義」「コース」 | `{"授業", "講義", "コース", "lecture", "演習"}` |
| 「論文」「ペーパー」「paper」 | `{"論文", "ペーパー", "paper", "manuscript", "draft"}` |
| 「申請」「申込」「願」 | `{"申請", "申込", "願", "application", "申し込み"}` |
| 「メール」「mail」「連絡」 | `{"メール", "mail", "Mail", "email", "連絡"}` |
| 「学会」「conference」 | `{"学会", "conference", "シンポジウム", "symposium"}` |

未収録の語は LLM が文脈から類推した類義語を最大 5-7 語で OR 展開する。**展開しすぎても誤マッチが増えるだけ**なので、明確に意味が近い語に限定する(「会議」→「議論」のような連想は入れない)。

### 展開例

```mathematica
(* ユーザー: 「会議のノート」 *)
SourceVaultFormatNotebookList[
  SourceVaultFindNotebooks[
    "Keywords" -> {"会議", "委員会", "教授会", "ミーティング", "MTG", "打ち合わせ"}]]

(* ユーザー: 「研究会と学会のノート」 *)
SourceVaultFormatNotebookList[
  SourceVaultFindNotebooks[
    "Keywords" -> {"研究会", "学会", "セミナー", "ワークショップ",
                   "conference", "symposium"}]]
```

### LLM への指示

- ユーザーが**1 語だけ**指定しても、LLM は類義語展開してから API を呼ぶ
- 展開は明示的に提示せず、自然に結果に含める(「会議で展開し『委員会』も拾いました」のような注釈は冗長)
- ユーザーが「会議だけ。委員会は除く」のように**明示的に絞った**ら、その指示を優先(展開しない)

## 日付範囲指定: Select でラップする (Stage 9 P1.5)

ユーザーが「**今月の**」「**先週の**」「**4月以降の**」のように**期間を明示**したら、`SourceVaultFindNotebooks` の結果を `Select` でラップして時期を絞る。スケジュール (`SourceVaultUpcomingSchedule`) と同じ感覚でユーザーが扱えるようにする。

### 絞り込み方針

**最も簡単 — `Deadline` / `NextReview` の Association 範囲指定を使う** (Stage 9 P1.5 で挙動拡張):

```mathematica
SourceVaultFindNotebooks[
  "Keywords" -> {...},
  "Deadline" -> <|"From" -> "2026-05-01", "To" -> "2026-05-31"|>,
  "Format" -> True]
```

**重要な仕様** (Stage 9 P1.5): `Deadline` / `NextReview` の Association 範囲指定は、

- **Header.Deadline / Header.NextReview** が範囲内 (Header に明示的に日付が書かれているノート)、または
- **ファイル名 `yyyymmdd-title.nb` の先頭 8 桁** が範囲内 (Imai 先生のファイル名規約)

の**いずれかが満たされれば該当**とする寛容な OR である。Header に Deadline が無くてもファイル名で日付がわかるノートは拾われる。多くのノートは Header.Deadline が未設定なので、ファイル名 OR が無いと厳密フィルタで全件落ちる事故が起きる。

文字列指定 (`"Today"` / `"Overdue"` / `"ThisWeek"` / `"DueSoon"`) は従来通り `ReviewState`/`DeadlineState` (Header 由来) で判定するので、ファイル名 OR は適用されない。

### 手動 Select でも OK (より細かい制御が必要なとき)

```mathematica
SourceVaultFormatNotebookList[
  Select[
    SourceVaultFindNotebooks["Keywords" -> {...}],
    With[{base = FileBaseName[Lookup[#, "Path", ""]]},
      StringMatchQ[base, RegularExpression["^\\d{8}-.*"]] &&
      With[{d = Quiet[DateObject[StringTake[base, 8]]]},
        Head[d] === DateObject &&
        DateObject[{2026, 5, 1}, "Day"] <= d <= DateObject[{2026, 5, 31}, "Day"]]] &]]
```

`Deadline` / `NextReview` Association を使う方が短く確実。手動 Select は「ファイル名日付**だけ**で絞る(Header Deadline を無視)」のような特殊用途のみ。

### 期間表現の解釈

`DateObject[Now, "Day"]` を today として:

| ユーザー表現 | 範囲 |
|---|---|
| 「今日」 | today, today |
| 「昨日」 | today - 1日, today - 1日 |
| 「今週」 | today から月曜開始の週 (例: 月〜日) |
| 「先週」 | 前週の月〜日 |
| 「今月」 | 当月 1 日 〜 月末日 |
| 「先月」 | 前月 1 日 〜 月末日 |
| 「今年」 | 1/1 〜 12/31 |
| 「4月以降」「4 月から」 | 当年 4/1 〜 当日(今日が 4 月より前なら前年扱いも検討) |
| 「○月の」 | ○月 1 日 〜 月末日 |
| 「○月○日 〜 ○月○日」 | 明示範囲そのまま |

`DateValue` / `DatePlus` / `DateRange` を使えば計算しやすい。LLM が範囲を確定したら、`"Deadline"` または `"NextReview"` の Association 範囲指定で渡す (上記の Header OR ファイル名日付の OR 仕様で寛容に拾われる)。

### どちらを使うか (Deadline vs NextReview)

- 「予定」「締切」「期限」 → `"Deadline"`
- 「レビュー」「見直し」「次回見るべき」 → `"NextReview"`
- 「今月の」「先月の」など**汎用の期間** → `"Deadline"` が無難 (ファイル名日付 OR が効くので Header Deadline 無しでも拾える)
- 「今月の会議関連すべて」のようなケースも `"Deadline" -> <|"From"->..., "To"->...|>` 単独で十分

旧 skill では「方針 1/2/3 のうち 2 (ファイル名 Select) を既定」と書いていたが、Stage 9 P1.5 で `Deadline` Association が自動的に Header OR ファイル名日付の OR になったので、**`"Deadline" -> <|...|>` 単独が既定**で良い。

### 表示は必ず `SourceVaultFormatNotebookList`

期間絞り込みをしても、最終出力は `SourceVaultFormatNotebookList[...]` で包む。`Dataset` や `Column` でカスタム表示しない(これも「禁止事項」の対象)。

## 物理ストレージ

```
<PrivateVault>/notebooks/
  sources/
    nb-src-<hash16>.json         # NotebookSourceRecord (path-based stable ID)
  snapshots/
    snap-sha256-<hash>.json      # NotebookSnapshotRecord (content hash)
  todos/
    by-notebook/
      nb-src-<...>.jsonl         # 各 notebook の Todo 一覧
  review/
    overdue.jsonl                # Overdue review 状態の append-only log
  lint/
    notebook-lint.jsonl          # 全 lint event の append-only log
```

**NotebookRef 生成** (path-based, stable):

```mathematica
iNotebookRefFromPath[path_String] :=
  Module[{abs = ExpandFileName[path],
          h = Hash[ExpandFileName[path], "SHA256", "HexString"]},
    "nb-src-" <> StringTake[h, 16]
  ];
```

path が変わると別 NotebookRef になる。Phase 2 で recovery candidate (Title + FileMTime ベース)
を実装予定。

## 罠カタログ対応 (Stage 9 P0 実装で踏んだもの)

| # | 罠 | 状況 |
|---|---|---|
| #11 | `\uXXXX` 文字列リテラル | **累計 1107 件混入** → 一括修正。Stage 9 だけで 266 件 (Stage 6c 72 + 8 295 + 6d 94 + 6b 380 + 9 266)。最大の継続的エラー源、5 回目の reincidence |
| #11 補足 | `\:` 後 4 桁 hex 未満 | 1 件 (`\:a7 3.4` → `\:00a7 3.4`)。コメント内の仕様書参照で発生 |
| **#21 (新規)** | `.nb` を `Get[path]` / `Import[path, "Text"]` でパース | **Stage 9 で発見**。result6.nb で MissingHeader、result7.nb で部分的失敗。`Import[path, "Notebook"]` / `NotebookImport` に切替で解決 |
| **#22 (新規)** | `ToString[box, StandardForm]` + `ToExpression` ラウンドトリップ | result7.nb で Header parse 失敗の真因。`MakeExpression[box, StandardForm]` に切替 |
| **#23 (新規)** | Package private context で Cell/Notebook 生パターンマッチ | result8.nb で Header OK / Todo 失敗の context 解決問題。最終的に `NotebookImport[path, style -> "Cell"]` で根本回避 |
| #15 | Map + Function + Return | 該当なし |
| #16 | Quiet@Check | 全箇所 `Quiet[expr]` 単独 |
| #20 | Windows `ReadList` | `Import[..., "Text"]` 系を使うので影響なし |

## チェックリスト

- [ ] 新規コード追加直後に `grep '\\u[0-9a-fA-F]\{4\}' SourceVault.wl` (罠 #11、累計 1107 件)
- [ ] `\:` の後は **必ず 4 桁** hex を確認 (罠 #11 補足、特に `\:00a7` の先頭 0 忘れ)
- [ ] **Notebook 情報にアクセスする場合は必ず先に Wolfram 標準関数を探す** (rule 102 の原則)
- [ ] Header parse は `Import[path, "Initialization"]` を第一選択にし、whitelist で値検証
- [ ] Todo 抽出は `NotebookImport[path, style -> "Cell"]` を `TodoItem_1/2/3` で試す
- [ ] box → expr 変換は `MakeExpression[box, StandardForm]` (`ToString`+`ToExpression` ラウンドトリップ禁止、罠 #22)
- [ ] パッケージ private context で `Cell[...]` / `Notebook[...]` 生パターンマッチを書かない (罠 #23)。やむを得ない場合は `SymbolName[Head[c]]` 文字列比較で context 非依存に
- [ ] `Get[path]` / `Import[path, "Text"]` で `.nb` をパースしない (罠 #21)
- [ ] Todo Status 判定は (1) TaggingRules → (2) StrikeThrough → (3) Default の優先順位
- [ ] StatusSource フィールドで判定根拠を必ず保存
- [ ] NotebookRef は path-based (Hash[absolutePath, "SHA256"])
- [ ] SnapshotId は content-based (Hash[file content, "SHA256"])
- [ ] Header Status と Todo cell 状態を独立に保存 (合成判定は lint で)
- [ ] `iSanitizeForJSON` を全 JSON 保存で経由
- [ ] `iEnsureRoots[]` を全 public API 冒頭で呼ぶ

## Phase 2 (P1) / Phase 3 (P2) ロードマップ

**Phase 2 (P1)**:

- `TaggingRules` ベースの明示 TodoStatus 標準化 (style notebook 側も改修)
- `NotebookSemanticHash` (表示・cache・CellChangeTimes 除外、Stage 8 と統合)
- Summary artifact の stale 判定 → Stage 8 lifecycle event と統合
- Section / cell 単位の差分 summary 更新
- NBAccess privacy profile による route 分岐 (`NBNotebookPrivacyProfile`)
- `SourceVaultMarkTodo[todoId, "Done"]` (notebook commit、NBAccess approval 必須)
- file mtime ベースの index skip (`ForceReindex -> False` を活用)

**Phase 3 (P2)**:

- ClaudeEval から自然言語 → SourceVault notebook query 変換
  - 「先月作業した notebook のうち、まだ Todo が残っているもの」
  - 「今週レビューする notebook を出して」
- `NotebookReviewDashboard` workflow template (ClaudeOrchestrator)
- Todo 更新 workflow (commit approval は NBAccess 経由)
- Summary refresh workflow (Stage 6c Bundle と統合)
- workflow run / prompt trace を SourceVault artifact として保存

## Stage 6c / 8 / 6d / 6b との接続

| 既存 Stage | Stage 9 での活用 |
|---|---|
| Stage 6c (Evidence Bundle) | NotebookSummaryArtifact は Bundle の `Kind: "Notebook"` 特化形 |
| Stage 8 (vN diff) | Notebook 更新時の lifecycle event を再利用 |
| Stage 6d (NBAuthorize) | privacy 配慮を要する notebook で sendDecision/persistDecision を呼ぶ |
| Stage 6b (Registry) | Notebook query 結果を compiled registry 化 (Phase 2) |
| Stage 6a (Claim dedup) | Notebook 内容から claim 抽出する場合の dedup (Phase 3) |

特に Stage 6c Phase 2 (階層集約) と Stage 9 は強く結びつく:
**Notebook = 最も自然な階層 Bundle のユースケース** (Notebook → Sections → Cells)。

## 仕様書との対応

| レビュー §節 | Phase 1 実装状況 |
|---|---|
| §1 現在形式の読み取り | ✓ |
| §3.1 NotebookSourceRecord | ✓ path-based ID、Type/Path/Title/FileMTime/CurrentSnapshotId 保存 |
| §3.2 NotebookSnapshotRecord | △ RawContentHash + CellCount + LifecycleStatus。SemanticHash 等は Phase 2 |
| §3.3 NotebookHeaderRecord | ✓ Keywords/Deadline/NextReview/Status + ParseStatus |
| §3.4 NotebookTodoRecord | ✓ Text/Status/StatusSource/StrikeThrough。Depth/ParentTodoId は Phase 2 |
| §3.5 NotebookReviewRecord | ✓ overdue.jsonl に append-only。by-date pivot は Phase 2 |
| §3.6 NotebookSummaryArtifact | × Phase 2 で実装 (LLM 要約) |
| §4 保存レイアウト | ✓ sources/snapshots/todos/review/lint |
| §5.1 登録・index | ✓ Register/Index/IndexFolder |
| §5.2 抽出 | ✓ ExtractHeader/ExtractTodos。CellStyles 等は Phase 2 |
| §5.3 検索 | ✓ OpenTodos/NextReview/Deadline/Keywords/Status |
| §5.4 概要・更新 | × Phase 2 |
| §5.5 Todo 更新 | ✓ **Stage 9 P1 Step 6 で実装** (`SourceVaultMarkTodo` → `NBWriteTodoStatus`) |
| §6.1 ヘッダ安全 parse | ✓ HoldComplete + whitelist。**Stage 9 P1 Step 8 で MakeExpression 第一選択化** |
| §6.2 Todo cell 抽出 | ✓ StrikeThrough 判定、TaggingRules 優先 |
| §6.3 Lint | ✓ 7 種実装 |
| §6.4 Summary 取り込み | ✓ **Stage 9 P1 Step 5 で実装** (`SourceVaultNotebookSummary`) |
| §6.5 Index 更新 | ✓ atomic-ish (file 単位 write、**Stage 9 P1 Step 7 で mtime cache 追加**) |
| §7 NBAccess / privacy 接続 | ✓ **Stage 9 P1 で実装** (NBAccess に semantic API 7 個) |
| §8 ClaudeEval / Orchestrator | × Phase 3 (P2) |
| §11 P0 優先順位 | ✓ 全項目実装 |
| §10 テスト T-NB-1〜5 | ✓ 添付 notebook で実演可能 |

---

# Stage 9 P1 拡張 (2026-05-20 完成)

`handoff_2026-05-20-stage9-p1.md` を参照。完成版 `v2026-05-19-stage-9-p1-step8-nbreadheader-boxdata-filter`。

## Step 別の達成項目

| Step | 内容 | 主要 API |
|---|---|---|
| 1-4 | TaggingRules 標準化 / `NotebookSemanticHash` / Summary stale 判定 / UTF-8 ファイル正常化 | (内部) |
| 5 | LLM 要約 (Step 4 Register 内部呼び出し版) | `SourceVaultNotebookSummary[path, opts]` |
| **6** | **NBAccess 高レベル書き込み API + SourceVaultMarkTodo** | `SourceVaultMarkTodo`, `NBWriteHeader`, `NBWriteTodoStatus`, `NBSetCellOptionsByPredicate`, `NBSetCellTaggingRuleByPredicate` |
| **7** | **mtime ベース skip** (透過的キャッシュ) | `SourceVaultIndexNotebook[path]` の `"Cached"` / `"SourceMTime"` / `"ForceReindex"` |
| **8** | **MakeExpression 第一選択化** (副作用回避) | `iNotebookHeaderParse` 経路順序逆転、戻り値に `"Source"` フィールド |
| 別件 1 | CellCount = 0 バグ修正 (罠 #26 対応) | `iFlattenCells` に切替 |
| 別件 2 | `NBReadHeader` の Source: "None" 問題 | MakeExpression パス追加 + `iNBIsHeaderLikeAssoc` Header フィルタ |

## Stage 9 P1 の核心設計原則

### 1. ファイル直接編集 (FrontEnd 不要)

旧 P0 案では `NBAccess approval workflow + FrontEnd 開く` 方式を検討したが、closed notebook を扱えない、scheduled task で動かない、等の制約があった。P1 では `Import["Notebook"]` → 編集 → `Export[path, ..., "NB"]` のファイル直接編集パイプラインを採用。

```mathematica
(* atomic write パターン *)
iNBFileSaveExpr[path_, nbExpr_] :=
  Module[{tmpPath = path <> ".tmp-" <> ToString[$ProcessID]},
    Export[tmpPath, nbExpr, "NB"];
    If[FileExistsQ[path], DeleteFile[path]];   (* Windows 対応 *)
    RenameFile[tmpPath, path]
  ];
```

### 2. AccessLevel RBAC + DryRun

書き込み系は **`AccessLevel >= 0.7` 必須** (default 0.7)、読み取り系は default 0.5 (Public)。DryRun は書き込み系のデフォルトを `True` にして、Before/After を `With[{c = cell}, HoldComplete[c]]` で値を埋め込んで返す (罠 #27 対応)。

### 3. CellPath による正確な書き戻し

Todo cell の位置を `CellPath = {2, 1, 3}` のような **List of Integer** で記録 (CellGroupData ネスト対応、罠 #26)。書き戻し時は `cells[[2, 1, 1, 3]]` で正確にアクセスできる。

```mathematica
iNBReplaceCellInList[cells_List, {i_Integer, rest__}, newCell_] :=
  Module[{cell, inner, newInner, newCellGroup, hName},
    cell = cells[[i]];
    hName = SymbolName[Head[cell]];
    If[hName === "Cell" && Length[cell] >= 1 &&
        SymbolName[Head[cell[[1]]]] === "CellGroupData",
      inner = cell[[1, 1]];
      newInner = iNBReplaceCellInList[inner, {rest}, newCell];
      newCellGroup = ReplacePart[cell[[1]], 1 -> newInner];
      ReplacePart[cells, i -> ReplacePart[cell, 1 -> newCellGroup]],
      cells]   (* path 不整合時は元のまま *)
  ];
```

### 4. mtime ベース cache (Step 7)

`SourceVaultIndexNotebook[path]` は冒頭で `UnixTime[FileDate[path, "Modification"]]` と snapshot record の `"SourceMTime"` を比較し、一致なら **完全な Index 結果を再構築して返す** (Header/Todo は再抽出、`Import["Notebook"]` と `SemanticHash` 計算をスキップ)。透過的キャッシュなので呼び出し側コード変更不要。

```mathematica
SourceVaultIndexNotebook[path_, opts:OptionsPattern[]] :=
  Module[{currentMTime, cachedResult, ...},
    currentMTime = Quiet @ UnixTime[FileDate[abs, "Modification"]];
    If[!forceReindex && IntegerQ[currentMTime],
      cachedResult = iSVCheckMTimeCache[abs, nbRef, currentMTime];
      If[cachedResult["Cached"] === True, Return[cachedResult]]];
    (* ...通常の reindex フロー... *)
  ];
```

### 5. Header parser の MakeExpression 第一選択化 (Step 8)

旧 P0 案では `Import["Initialization"]` (Wolfram が InitializationCell の中身を **評価する** 副作用あり) を第一選択。P1 では順序逆転:

1. (B) `Import["Notebook"]` + `MakeExpression[box, StandardForm]` ← **第一選択 (副作用なし)**
2. (A) `Import["Initialization"]` ← fallback (副作用あり、最後の砦)

戻り値に `"Source"` フィールド (`"MakeExpression"` / `"Initialization"`) を追加して経路を明示。

### 6. NBReadHeader の 3 経路 fallback (別件 2)

NBAccess `NBReadHeader[path]` は以下の順序で Header を探す:

1. Notebook 全体 TaggingRules > SourceVault (Header フィルタ通過のみ)
2. Cell 単位 TaggingRules > SourceVault (Header フィルタ通過のみ、TodoStatus のような Todo metadata を除外)
3. Input cell の BoxData → `MakeExpression[boxData, StandardForm]` で Association 化
4. None

**Header フィルタ** (`iNBIsHeaderLikeAssoc`): Header らしいキー (`Keywords` / `Status` / `Deadline` / `NextReview` / `Owner` / `PathHint` / `Title`) のいずれかを含む Association のみ Header と認める。これにより、Step 6 で SourceVaultMarkTodo が書き込んだ TodoItem cell の `<|"TodoStatus" -> "Done"|>` のような Todo metadata を Header と誤認しない。

## Stage 9 P0 → P1 の API 互換性

P0 で確立した API は **完全に維持**。P1 は加えるだけ:

| 既存 API | P1 での変更 |
|---|---|
| `SourceVaultIndexNotebook[path, opts]` | 戻り値に `"Cached"` / `"SourceMTime"` 追加 (既存フィールド不変)、新オプション `"ForceReindex"` |
| `SourceVaultExtractNotebookHeader[path]` | 戻り値の Header に `"Source"` フィールド追加 |
| `SourceVaultExtractNotebookTodos[path]` | 不変 |

## 新規 API 一覧 (Stage 9 P1)

| API | パッケージ | レベル |
|---|---|---|
| `NBReadHeader[path, opts]` | NBAccess | 高 (3 経路 fallback) |
| `NBReadTodos[path, opts]` | NBAccess | 高 (CellGroupData 再帰展開) |
| `NBFindCellByPredicate[path, predicate, opts]` | NBAccess | 中 |
| `NBWriteHeader[path, key, value, opts]` | NBAccess | 高 (atomic write) |
| `NBWriteTodoStatus[path, todoKey, newStatus, opts]` | NBAccess | 高 (atomic write) |
| `NBSetCellOptionsByPredicate[path, pred, opts__, opts2]` | NBAccess | 中 (atomic write) |
| `NBSetCellTaggingRuleByPredicate[path, pred, taggingPath, value, opts]` | NBAccess | 中 (atomic write) |
| `SourceVaultMarkTodo[path, target, newStatus, opts]` | SourceVault | 高 (`NBWriteTodoStatus` への薄いラッパー) |
| `SourceVaultNotebookSummary[path, opts]` | SourceVault | 高 (P1 Step 5 で追加、LLM 要約) |

---

# 次フェーズ: Sync / Relink / UUID 埋め込み (2026-05-22 完成)

## SourceVaultSync — クローラー骨格

巡回して鮮度の落ちた notebook source を再 index する仕組み。公開 API 4 個。

- `SourceVaultSelectSources[opts]` — Scope 配下の .nb を走査し source descriptor 化
- `SourceVaultSyncPlan[opts]` — 各 source の鮮度を判定 (dry-run、副作用なし)。`Fresh` / `Stale` / `Missing` / `NeverIndexed` に分類
- `SourceVaultSync[opts]` — Stale な source を `SourceVaultIndexNotebook` で再 index
- `SourceVaultSyncStatus[]` — 直近 sync の状態 (`sync/last-sync.json`)

設計の核心:

- **鮮度トークン抽象** — `iSVFreshnessToken` がローカルファイルは mtime (`UnixTime`) を返す。web (ETag / Last-Modified / TTL) は `Kind -> "Web"` の枠だけ予約 (`NotImplemented`)。鮮度判定は「現トークン vs 記録済みトークン」の比較
- **PrivacyLevel は単調** — 再 index で snapshot の PrivacyLevel が下がったら、`SourceVaultSetSnapshotPrivacyLevel` で旧値に引き上げ、`PrivacyWarnings` に記録。プライバシーは「下げる方向」に自動変化させない
- **一括同期の安全側既定** — `FallbackToCloud -> "Deny"` が既定。多数ファイルの一括処理でクラウド送信を暗黙に許可しない
- ストア `notebooks/sync/` — `sync-history.jsonl` (append-only) + `last-sync.json`

## SourceVaultRelinkSources — ファイル移動追跡

`OriginalPath` が消えた notebook source の移動先を探して再リンク。`iSVRelinkSources` プレースホルダーを置換 (後方互換エイリアス保持)。

**3 段照合 (信頼度の高い順)**:

1. **埋め込み UUID** — TaggingRules `SourceVault > NotebookUUID`。最も信頼でき、ファイル名・内容が変わっても追跡可能
2. **内容ハッシュ** — `RawContentHash` の完全一致
3. **ファイル名一意一致** — Scope 内に同名ファイルが 1 つだけのとき

設計の核心 (rule 103 に直結):

- **移動判定はシンボリックパス解決ベース** — 「移動したか」は `OriginalPath` の生 `FileExistsQ` でなく、record の `SymbolicPath` を `iSVResolvePath` で現 PC 解決して実在判定する。別 PC のパス差 (`C:\Users\imai_\...` vs `F:\Dropbox\...`) を移動と誤検出しない
- **強い証拠と弱い証拠を分ける** — UUID / 内容ハッシュ一致は自動適用するが、ファイル名一致 (`NameOnly`) は弱い証拠なので `ApplyNameOnly -> True` のときのみ適用。既定はレポートのみ。連番ファイル群 (`計算と自然 01`〜`25`) の誤マッチ防止
- **StaleDuplicate 判定** — マッチ先が既に別の現役 record の指す実ファイルなら、それは「移動」でなく「旧 PC index の残骸」。Relink 開始時に「全現役 record の実ファイルパス集合」(`livePathSet`) を構築し、マッチ先がそこに含まれるかを**実パスで**判定 (NotebookRef のハッシュ衝突を避ける)。`DeleteStale -> True` で残骸 record を削除 (既定 False は非破壊マーク `RelinkStatus -> "StaleDuplicate"`)
- **非破壊** — `DryRun` 既定 `True`。`DryRun -> False` でも旧 record は削除せず `Superseded` マークのみ (`DeleteStale` を除く)
- 戻り値に `ByMethod` (UUID / ContentHash / NameOnly 別件数)、`StaleDuplicateCount`、`StaleDeletedCount`
- ストア `notebooks/relink/relink-log.jsonl`

開発中、`Linked` 判定の早期 return を内側 `Module` に閉じ込めたバグ (罠 #52) で全件が照合ループに流れ `Relinked` が膨張した。修正後は 366 ファイルで `Linked: 365 / Relinked: 0` に収束。

## Notebook UUID 埋め込み機構

Relink の最上位照合キーを供給する基盤。公開 API 3 個。

- `SourceVaultNotebookUUID[path]` — 埋め込み UUID を読む (読み取りのみ)
- `SourceVaultEnsureNotebookUUID[path, opts]` — UUID が無ければ生成して埋め込む。`Force` で再生成
- `SourceVaultEnsureNotebookUUIDFolder[dir, opts]` — folder 一括付与

設計の核心:

- UUID は notebook の **TaggingRules `SourceVault > NotebookUUID`** に保存 (`nbuuid-` + `CreateUUID`)。Step 1 の CloudPublishable と同じ名前空間。Header (Initialization セル) でなく TaggingRules を選ぶことで、ファイル本文を書き換えず非破壊、かつファイルと一緒に移動する
- 書き込みは `NBFileOpen` (`Visible -> False`) → `NBSetTaggingRule` → `NBFileSave` → `NBFileClose`
- `SourceVaultIndexNotebook` の sourceRecord に `SourceUUID` と `SymbolicPath` フィールドを追加 — index 時に埋め込み UUID とシンボリックパスを記録し、Relink の照合・移動判定の基盤データにする
- `EnsureNotebookUUIDFolder` の巨大ファイルは `Skipped` (`Failed` と別カウント) — TaggingRules 書き込みには巨大 notebook を開く必要があるため、サイズ閾値超えはスキップ

運用注意: UUID 付与は notebook の mtime を変えるため、「**UUID 一括付与 → 全件 index → 以降 Sync で安定運用**」の順序で行う。付与直後に Sync を走らせると全件 Stale 判定になる。

## モデルレジストリ動的更新

`skills/compiled-registry-and-seed` 参照。`$SourceVaultModelEndpoints` + `SourceVaultModelEndpointStatus` / `SourceVaultDetectLocalModels` / `SourceVaultRefreshModelRegistry`。

## Stage 9 Phase 3 (P2) への伏線

- バッチ Todo 操作 (`SourceVaultMarkTodos[path, [{idx1, "Done"}, {idx2, "Pass"}]]`)
- Notebook 全体の TaggingRules > SourceVault Header migration (BoxData → TaggingRules 形式)
- NBAccess privacy profile による route 分岐
- ClaudeEval / ClaudeOrchestrator 統合
- 階層 (Sections) Bundle (Stage 6c Phase 2 と統合)
- Sync の web source 実 fetch / Orchestrator 経由の非同期 Sync
- `SourceVaultIngest` 時の UUID 自動付与
- `iSVSymbolicPath` の旧 PC ルートエイリアス対応 (二重登録の未然防止)

## Summary の言語と文体ルール (Stage 9 P1.5)

`SourceVaultNotebookSummary` が生成する Summary テキストは、表示用テンプレートではなく LLM が一度だけ生成して `summaries/*.json` に保存される artifact。つまり**生成時の言語と文体が後から固定的に表示される**ため、揺らぎを生むと「日本語常体・敬体・英文が混在した一覧」になり読みにくい。

ルール:

- **`$Language` が `"Japanese"` を含む環境** → **日本語常体** (`...である` / `...だ` / `...する`)
- **それ以外** → **英文**
- **敬体 (`...です` / `...ます` / `...でしょう`) は使わない**

これは `iBuildNotebookSummaryPrompt` の `langInstruction` で実装されている。`Options[SourceVaultNotebookSummary]` の `"Language"` が `Automatic`(既定)のときに `$Language` を参照して `effectiveLang` を決め、明示指定された言語(`"Japanese"` / `"English"`)は尊重する。

```mathematica
effectiveLang = Which[
  language === "Japanese", "Japanese",
  language === "English", "English",
  language === Automatic && MemberQ[Flatten[{$Language}], "Japanese"],
    "Japanese",
  language === Automatic, "English",
  True, "English"];
```

### 既存 Summary の再生成

ルール変更前に生成済みの Summary は文体・言語が古いまま `summaries/*.json` に残る。新ルールを既存ノートに適用するには `"ForceRefresh" -> True` で再生成する:

```mathematica
SourceVaultNotebookSummary[path, "ForceRefresh" -> True]
```

または一括再生成 API(`SourceVaultRebuildAllSummaries[]` 等が存在すればそれ)を使う。

### LLM 経由で「今日の予定」等を表示する場合の追記ルール

ダッシュボード生成のような LLM 直接出力(Summary artifact を経由しない)についても、上記の言語・文体ルールを適用する。LLM プロンプトに以下を含めること:

- 「Japanese 環境なら常体で書け。敬体は絶対に使わない」
- 「Japanese 以外の環境なら英文で書け」
- 「言語を勝手に切り替えない (同一表内で混在させない)」

## Notebook 内の表示文字列は言語非依存に保つ (Stage 9 P1.5)

ダッシュボードやレビュー一覧などのセルをノートブックに保存する際、**表示文字列を日本語ハードコードしない**。理由は、ノートブックを `$Language` の異なる環境(英語環境の同僚、CI、cloud kernel など)に送付・共有したとき、日本語表示が浮く・読めない・整合性が崩れるため。

同じ方針は **パレット表示**(Dynamic ボタンのラベル)にも適用する。パレット自体はノートに保存されないが、Cloud/Privacy/Paid API のような並列的な状態表示は環境間で見た目を揃える価値がある。

| 概念 | 内部値 | 表示文字列(英単語固定) | 関数 |
|---|---|---|---|
| CloudPublishable | `True` | `Public` | `iCloudPaletteLabel` (claudecode.wl) / `iSVPublishableCell` (SourceVault.wl) |
| CloudPublishable | `False` | `Private` | 同上 |
| CloudPublishable | `Missing["NotDeclared"]` | `Unspecified` | 同上 |
| Cloud (sub-state) | `Missing["NotSaved"]` | `Save NB` | `iCloudPaletteLabel` (claudecode.wl) — 環境非依存に統一 |
| Cloud (sub-state) | `Missing["NoNotebook"]` | `No NB` | 同上 |
| Cloud (sub-state) | `Missing["NotLoaded"]` | `Load` | 同上 |
| Cloud (fallback) | その他 | `?` | 同上 |
| Paid API (`$iPaletteFallback`) | `True` | `Allowed` | パレットボタン (claudecode.wl L18575) |
| Paid API | それ以外(False/Missing) | `Denied` | 同上 |

**変更履歴 (Stage 9 P1.5)**: Cloud のサブ状態 (`Missing["NotSaved"]` / `Missing["NoNotebook"]` / `Missing["NotLoaded"]`) は元々 `iL["要保存", "Save NB"]` のように `iL[日本語, 英語]` で $Language 切り替えしていたが、**パレット表示は環境間で見た目を揃える方針に従い英単語固定に変更**。`iL` への再導入は不可。エラー的状態でもパレット文字列はノート保存と同様に環境非依存に保つ。

**重要**: 内部データ表現 (`True` / `False` / `Missing`) は Wolfram 標準値のままで、**変更しない**。ノートブック Header の値表現も `True` / `False` のまま。変えるのは**表示文字列のみ**。

### 二値選択ボタンの命名規約

新規にパレットボタンやダッシュボード状態セルを追加する場合の命名規約:

- **状態(モード)系**: `Public` / `Private` / `Unspecified`(公開可否のように「対象」を表す)
- **権限系**: `Allowed` / `Denied`(操作許可のように「行為」を表す)
- **オンオフ系**: `On` / `Off`(機能 toggle のように単純な切替)

迷ったら `Allowed` / `Denied` か `On` / `Off` で十分。日本語の「許可」「禁止」をハードコードするのは避ける。

### 対象外: 対話ダイアログ

`iAskDirPermission` のようなユーザーがその場で選択する**一時的な確認ダイアログ**は対象外で、`iL[日本語, 英語]` による $Language 切り替えのままが UX 上自然(ユーザーは自分の母語で読みたい)。

判断基準:
- **ノートに保存される** (DockedCell, ダッシュボードセル) → 英単語固定
- **パレット表示** (環境間で見た目を揃える) → 英単語固定
- **その場の対話ダイアログ** (ユーザーが選択して消える) → `iL` で母語切り替え
- **エラーメッセージ・ログ** → 英文を既定とするが、デバッグ用なら `iL` でも可

### 同種の表示文字列がある場合の方針

新しくダッシュボードや一覧テーブルを作る際、列ラベル・状態文字列は英単語で書く:

```mathematica
(* 例: 状態を英単語で揃える *)
{label, color} = Which[
  state === True,  {"Public",      RGBColor[...]},
  state === False, {"Private",     RGBColor[...]},
  True,            {"Unspecified", GrayLevel[...]}];

(* Paid API のような二値の場合 *)
Style["Paid API: " <> If[TrueQ[$flag], "Allowed", "Denied"], ...]
```

「Status」列は既に `"Todo"` / `"Done"` / `"Pass"` の英単語ベースなのでそのまま。「ReviewState」「DeadlineState」も `"DueToday"` / `"DueThisWeek"` / `"Overdue"` / `"NoReviewDate"` の英単語。

エラーメッセージ等の Detail 系も同様に英文を既定とし、$Language で切り替えたい場合は別途関数化する(現状未実装、英文固定)。

## ノートブックリスト表示のデフォルトフォーマット (Stage 9 P1.5)

ユーザーが「notebook の一覧/リストを表示」「該当する notebook を列挙」「キーワード〜のノートを探す」「今日の予定」など、**任意のノートブックの集まりを見せる出力**を要求した場合、ClaudeEval が最終的に評価する Wolfram 式は **`SourceVaultFormatNotebookList[records]`** を適用した形にする。

これは `SourceVaultUpcomingSchedule` のスケジュール表と同一フォーマット (Title・Dir に「開く」ボタン付き、日付の赤/青着色、Summary 列、Publishable 列) を再利用するための public API。生 Association や Path 文字列を `Print` で並べるとボタンが効かず、ユーザーが notebook を直接開けず使い物にならない。

### LLM が生成すべき出力式の型

```mathematica
SourceVaultFormatNotebookList[
  SourceVaultFindNotebooks["Keywords" -> {"会議"}]
]
```

```mathematica
(* 複数条件を組み合わせるときも、最終出力は必ず Format で包む *)
SourceVaultFormatNotebookList[
  SourceVaultFindNotebooks["OpenTodos" -> True, "Scope" -> "Today"]
]
```

```mathematica
(* 手動でフィルタした記録も渡せる *)
SourceVaultFormatNotebookList[
  Select[SourceVaultFindNotebooks["OpenTodos" -> True],
    StringContainsQ[Lookup[#, "Path", ""], "教務"] &]
]
```

### 禁止パターン

以下は ClaudeEval が出力してはならない:

- **生 Association List をそのまま返す** — `SourceVaultFindNotebooks["Keywords" -> {"会議"}]` だけで終わる
- **Path 文字列の List を返す** — `Lookup[#, "Path"] & /@ records` でテキスト列挙
- **`Print` や `TableForm` で代用する** — Title/Dir のボタンが消えて開けなくなる
- **自作の Grid を組む** — フォーマットが揺れ、Summary や Publishable 列が欠落する
- **個別 record の `Path`/`Title` などをサマリしたカスタム Association を返す** (`<|"MatchedPaths" -> ..., "Count" -> ...|>` のような形式) — これは表として見えない

### 例外: ユーザが明示的に別形式を要求した場合のみ

- 「Path だけ欲しい」「件数だけ知りたい」「タイトルの一覧だけ」のような明示的要求 → 要求通りに返す
- それ以外の「リスト」「一覧」「該当するもの」は表形式 (`SourceVaultFormatNotebookList`) が既定

### 空結果の扱い

`SourceVaultFormatNotebookList[{}]` は「該当する notebook はありません。」というメッセージを返す。LLM は空結果を見つけたら、表示式は同じく `SourceVaultFormatNotebookList[{}]` で良く、テキスト解説を別途付ける(「キーワード〜に該当する notebook はありませんでした」など)。

### `SourceVaultFindNotebooks` の戻り値との互換性

`SourceVaultFormatNotebookList` は `Path` と `Header` を持つ Association List を受け付ける。`SourceVaultFindNotebooks` の戻り値はそのままこの形なので変換不要。`SourceVaultIndexNotebook` の OK record も直接渡せる(単一 record の場合は `{record}` でくるむ)。

---

## プロンプト保存・検索・表示 (Stage 9 P1.5, PromptRouter)

ClaudeEval で実行したプロンプトと生成した関数を SourceVault に保存し、後で検索・再実行できる。`SourceVault_promptrouter.wl` で実装。

### 保存: `SaveLastPrompt[memo]`

直前の成功した ClaudeEval / ContinueEval 実行を PromptRoute として保存する。

```mathematica
SaveLastPrompt["この関数は LLM が使える環境のみ"]
```

- `memo` は備忘録の自由文字列。プロンプトテーブルの Memo 列に表示される。
- privacy は `SourceVaultResolvePromptPrivacy` で追跡。PrivacyLevel >= 0.5 (秘密セル由来等) なら channel を `"private"` に自動振り分け、CloudFallback も route に記録。
- 既定は**平文保存**。関数・メモは秘匿が必要なことがめったにないため。
- options: `"Channel"` (Automatic/public/private/local)、`"Encrypt"` (既定 False)、`"DryRun"`、`"RouteId"`。
- **`"Encrypt" -> True` は未実装**。暗号化保存 (master-key 基盤) は将来機能で、現状 `Status -> "NotImplemented"` を返す。引き継ぎ文書 `handoff_2026-05-28-promptrouter-save-ui.md` 参照。

ユーザーが「今のプロンプトを保存して」「さっきの ClaudeEval を再利用可能にして」等と言ったら、`SaveLastPrompt[memo]` を提案する (memo はユーザーの説明文か、無ければ空文字)。

### 検索: `SourceVaultSearchPromptRoutes[query, opts]`

保存済みプロンプトを検索する。**ノートブック検索と同じ方式**:

- `query` は prompt 例文 + memo に対する**部分一致** (`StringContainsQ`)。`""` で全件。
- `"CreatedAt"` / `"UpdatedAt"` に `<|"From" -> "2026-05-01", "To" -> "2026-05-31"|>` で**定義日・最終更新日**の範囲フィルタ (ノートブック検索の日付範囲と同形式)。
- `"Channel"` (All/public/private/local)、`"IncludeSeed"`。
- 実行はしない (候補 route の List を返す)。

```mathematica
(* memo か prompt に「会議」を含み、今月定義されたもの *)
SourceVaultSearchPromptRoutes["会議",
  "CreatedAt" -> <|"From" -> "2026-05-01", "To" -> "2026-05-31"|>]
```

### 表示: `SourceVaultFormatPromptRouteList[routes]`

検索結果を表形式で表示する。`SourceVaultFormatNotebookList` と同じ発想。

```mathematica
SourceVaultFormatPromptRouteList[
  SourceVaultSearchPromptRoutes["会議"]]
```

- 列: Prompt / Memo / Target(関数) / CreatedAt / UpdatedAt / Privacy / Actions。
- 各行に3ボタン:
  - **Preview**: dry-run。実行せず「何が実行されるか」を表示。
  - **Run**: その場で route を実行。
  - **ToInput**: 保存された関数呼び出し式を Input セルに出力 (評価しない)。
- Privacy ラベルは英単語 (Public / Restricted / Private / Secret)、環境非依存。

### LLM への指示

- 「保存したプロンプトを検索」「過去のプロンプト一覧」等を要求されたら、最終出力は **`SourceVaultFormatPromptRouteList[SourceVaultSearchPromptRoutes[query, ...]]`** の形にする。生 Association や Dataset で返さない (ノートブックリストと同じ方針)。
- 日付範囲指定 (「今月保存した」「先週定義した」) があれば `"CreatedAt"` / `"UpdatedAt"` オプションでラップする。ノートブック検索の日付範囲解釈表をそのまま流用する。
- 「保存して」は `SaveLastPrompt[memo]`、「検索して」は Search+Format。混同しない。

---

## api.md と $ClaudePackageKeywordMap (探索成功率の要)

ClaudeEval が正しい SourceVault API を生成する確率は、**ホスト側 `SourceVault_info/docs/api.md`
が最新であること**に大きく依存する (rule 12, doc-generation skill 参照)。api.md が古いと
LLM が API シグネチャを誤り、自作 Grid 等にフォールバックしやすい。実測で、api.md を最新化したら
ClaudeEval が `SourceVaultFindNotebooks[..., "Format" -> True]` を高確率で正しく生成するようになった。

**新しい public API を足したら api.md を必ず更新する** (`"Format"` オプション、
`SourceVaultFormatNotebookList`、`SaveLastPrompt`、`SourceVaultSearchPromptRoutes`、
`SourceVaultFormatPromptRouteList` など)。本スキルの記述だけでは不十分で、api.md の整備が探索成功率を
左右する。

### 自動注入 ($ClaudePackageKeywordMap)

SourceVault.wl はロード末尾で `ClaudeCode`$ClaudePackageKeywordMap["SourceVault"]` に
キーワード ("ノートブック", "予定", "会議", "キーワード", "一覧", "SourceVaultFindNotebooks" 等) を
登録する (maildb と同じ仕組み)。プロンプトにこれらが含まれると、SourceVault の api.md が
ClaudeEval/ClaudeQuery のコンテキストに自動注入される。新 API のキーワードが増えたら、この登録リスト
(SourceVault.wl の EndPackage 後セクション) にも追加する。

## Summary 生成は表示時から切り離す (Stage 9 P1.5)

### 問題

`SourceVaultFormatNotebookList` / `SourceVaultUpcomingSchedule` / `"Format" -> True` は本来
スケジュール表示用だが、初期実装は表示時に各 notebook の Summary を on-the-fly で LLM 生成していた
(`iSVEnsureSummaryInline` の既定 `"Refresh" -> "IfStale"`)。これは強力 LLM 環境では問題ないが、
**処理能力の小さいローカル LLM 環境では一覧表示の度に数分かかる**実害があった。

### 方針

**表示と生成を分離する**:

- **表示時は LLM を呼ばない (既定 `"Refresh" -> "Never"`)** — `SourceVaultGetNotebookSummary` で
  保存済み Summary だけを読む。無いノートは `iSVTitleTipBody` の fallback で Header.Keywords を
  Title 列のツールチップに出す (元々の設計通り)。表示が常に高速で確定的になる。
- **生成は明示的なバッチで** — `SourceVaultRefreshAllSummaries[opts]` を強力 LLM 環境
  (強力ローカル LLM がロードされた PC、夜間ジョブ、または別 PC) で走らせる。`summaries/` 配下の
  JSON が Dropbox 経由で他 PC にも同期される。
- **これは LLM 能力の自動判定ではない** — 「いつ生成されるか予測できない」状況を避けるため、
  生成は常に明示的なコマンドで行う。

### バッチ生成 API

```mathematica
(* 既定: 全件再生成。OpenTodos > 0 のものだけに限定したいときは多い *)
SourceVaultRefreshAllSummaries[
  "OpenTodosOnly" -> True,           (* 実用的なサブセット *)
  "Progress" -> True,                (* 10 件ごとに進捗 Print *)
  "Model" -> "qwen-large",           (* 強力 LLM を明示指定 (任意) *)
  "FallbackToCloud" -> "Deny",       (* クラウド送信したくないとき *)
  "Limit" -> 50]                     (* 段階実行・テスト用 *)
```

`"Progress" -> True` を付けると `[10/200] refreshed=8 cached=2 failed=0 elapsed=42s` のような
進捗が出る。長時間ジョブでハングしているのか進んでいるのか分かる。

### 表示で LLM を呼びたい場合 (例外)

強力 LLM 環境で「常に最新の Summary を表示時に作りたい」場合、明示指定で従来動作になる:

```mathematica
SourceVaultFormatNotebookList[records, "Refresh" -> "IfStale"]
SourceVaultUpcomingSchedule["Refresh" -> "IfStale"]
SourceVaultFindNotebooks["Keywords" -> {...}, "Format" -> True]
  (* Format ラッパー経由でも "Refresh" は FormatNotebookList の既定 Never を引く *)
```

ただし**既定は Never が推奨**。「会議のノート一覧」のような頻出操作で毎回 LLM を待たされる
UX を避ける。

### 別 PC でのバッチ実行

SourceVault root は通常 `$dropbox/udb/sourcevault` の下にあり、`sources/` / `summaries/` /
`snapshots/` が Dropbox 同期される。強力 LLM が動く別 PC で `SourceVaultRefreshAllSummaries[]`
を走らせれば、結果が全 PC に反映される。`SymbolicPath` 解決 (`$onWork` 等) が機能していれば
`OriginalPath` が別 PC のパスでも問題ない。

## 関連 skills

- `skills/nbaccess-semantic-api` — NBAccess semantic API の設計詳細
- `skills/wolfram-syntax-pitfalls` — 罠 #26-#28 (CellGroupData ネスト / Module + HoldComplete / JSON RawJSON fallback) + 罠 #52-#54 (次フェーズ)
- `rules/103-sourcevault-datastore-safety.md` — データストア書き込み安全規約

---

## 重要 — `iSVResolvePath` の名前空間と呼び出し方

`iSVResolvePath` は SymbolicPath (`{"$onWork", "20260528-教務委員会.nb"}` のような形式) を現 PC の絶対パスに解決する関数だが、**名前空間が `SourceVault`` 直下 (Private 無し)** にあり、これは他の Stage 9 P1 ヘルパ関数の慣行 (`SourceVault`Private`...`) と異なる例外。間違って `SourceVault`Private`iSVResolvePath` を呼ぶと `DownValues` が空で**未評価のままシンボル名がそのまま返る**(例: `SourceVault`Private`iSVResolvePath[{"$onWork", "..."}]` という未評価式が返り、`StringQ[result]` は False)。この罠は SourceVaultFindNotebooks の Path 解決バグ調査で実際に2回踏まれた。

### 正しい呼び出し方

```mathematica
(* 正解 *)
SourceVault`iSVResolvePath[{"$onWork", "20260528-\:6559\:52d9\:59d4\:54e1\:4f1a", "20260528-\:6559\:52d9\:59d4\:54e1\:4f1a.nb"}]
(* → "F:\Dropbox\On Work\20260528-教務委員会\20260528-教務委員会.nb" (現 PC が F: の場合) *)

(* 誤り (DownValues=0 で未評価のまま返る) *)
SourceVault`Private`iSVResolvePath[...]
```

### 名前空間確認の決め手

`DownValues` 長さを比較すれば一発で判別できる:

```mathematica
{Length[DownValues[SourceVault`iSVResolvePath]],          (* 2 *)
 Length[DownValues[SourceVault`Private`iSVResolvePath]]}  (* 0 *)
```

### 仕様

| 引数 | 戻り値 |
|---|---|
| `{"$onWork", ...}` のような List | `iSVCloudRootValue` で `$onWork` 等を現 PC 絶対パス化し、`FileNameJoin[Prepend[Rest, rootAbs]]` で結合 |
| `{"<ABS>", abs}` | `abs`(既に絶対パスのもの)をそのまま |
| `{}` (空 List) | `Missing[]` |
| クラウドルートが現 PC で未定義 | `Missing[]` |
| 他 (Non-List) | `Missing[]` |

呼ぶ前に `ListQ[sym]` で gate するのが定石(SourceVaultFindNotebooks 内でもそうしている)。戻り値は `StringQ[resolved] && FileExistsQ[resolved]` で実在判定する。

### 内部呼び出しは context 経由不要

`SourceVault.wl` パッケージ内部のコードからは context prefix なしで `iSVResolvePath[sym]` と書けば良い(`Begin["`Private`"]` の中でも `SourceVault`` 直下シンボルは自動解決される)。コンテキストの問題は**外部から呼ぶとき**にだけ顕在化する。

### 他の同種シンボル

`SourceVault`` 直下にあるその他のヘルパ(全てパッケージ外から呼ぶ可能性のあるもの)を把握しておくと類似罠を回避できる。確認は `Names["SourceVault`*"]` で一覧できる。基本的に SourceVault パッケージから外部 API として呼ばれるシンボルは `Private`` でなく直下に置かれる慣行。
