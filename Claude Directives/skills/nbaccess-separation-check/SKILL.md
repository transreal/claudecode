---
name: nbaccess-separation-check
description: Use when checking or fixing package-source policy violations in Wolfram Language packages — NBAccess separation (direct cell/FE access), credentials, privacy level (.nb direct read/write, LLM channels that bypass the router, direct LLM API calls, hard-coded PrivacyLevel, model overrides) and access level. Covers NBAccess`NBAuditPackageSource, ClaudeCheckSeparation, ClaudeSeparationView and its fix UI, waivers, ClaudeFixSeparation and $NBSeparationIgnoreList.
---

# パッケージソースのポリシー検査 (NBAccess 分離・認証情報・プライバシー・アクセス)

設計と経緯: `ドキュメント/NBAccess_policy_lint_redesign_proposal_v0_1.md` (2026-10-31、Phase 0〜4 実施済み)。

## どの関数を使うか

| 目的 | 関数 |
|---|---|
| ユーザーに結果を見せる・直す | **`ClaudeSeparationView[target]`** (表 + [前後] [修正案] [問題なし])。target はパッケージ名・`.wl` パス・そのリスト・`All` |
| 結果をデータで受け取る | `ClaudeSeparationFindings[target]` (1 件 1 連想、View と同じ行) |
| コンソールに一覧を出す | `ClaudeCheckSeparation[target]` |
| 検査エンジン本体 | `NBAccess`NBAuditPackageSource[files]` / `NBAccess`NBAuditPackageSourceText[code, name]` / `NBAccess`NBAuditPackageSourceRules[]` |
| 1 件について LLM の意見を聞く (任意) | View の詳細欄の [LLM に判定を聞く] / `ClaudeSeparationTriage[row]` |
| コミット時の警告 | `PackageCommit` / `PackageCommitPlan` / `GitHubRefreshAndCommit` が自動で行う (戻り値の `"PolicyLint"`) |

検出は LLM を使わない (修正案と任意の LLM 仕分けだけが LLM を使う)。検出は構文木 (CodeParser) で行うので、文字列やコメントの中は拾わない。

### キャッシュ

`"Cache" -> True` (既定) は、単位ごとの結果をカーネル内と `$UserBaseDirectory/ApplicationData/NBAccess/policylint_cache.wxf` (マシンごと、Dropbox の外) に保存する。中身は規則 ID・位置・定義名だけで、コード片や鍵の文字列は入らない。規則の版が変わると使われない。`"Memory"` はカーネル内だけ、`False` は使わない。結果の `Coverage["CacheHits"]` でキャッシュから取った単位の数が分かる。全 147 ファイルの初回は約 4 分、キャッシュが効けば約 10 秒。ディスクに残るので、カーネルを起動し直しても速い (claudecode.wl・github.wl・ClaudePackageManager.wl で 21 秒 → 0.6 秒)。

```mathematica
ClaudeSeparationView["SourceVault"]        (* 主ソース + 補助モジュール <pkg>_*.wl *)
ClaudeSeparationView[All]                  (* $packageDirectory 直下の全 .wl (名前に空白を含むバックアップ・競合コピーは除く) *)
r = NBAccess`NBAuditPackageSource[{FileNameJoin[{$packageDirectory, "SourceVault.wl"}]}];
r["Status"]     (* "OK" | "Violations" | "Failed" (解析できない範囲が残った = fail-closed) *)
r["Findings"]   (* <|RuleID, Severity, File, Line, Column, EndLine, Definition, Head, Code, Message, Remedy, Basis, AutoFix, Waived|> *)
r["Inventory"]  (* <|AccessSites, DeclassifySites, EgressSites|> 棚卸し *)
```

## 規則

| RuleID | 検出 | 重大度 | AutoFix |
|---|---|---|---|
| SEP-CELL | `Cells` `NotebookRead` `NotebookWrite` `SelectionMove` `CellPrint` `EvaluationCell` `SelectedCells` `SetSelectedNotebook` `SelectionEvaluate*` `FrontEndTokenExecute` の呼び出し | Error | ○ |
| SEP-ATTR | `CurrentValue` / `AbsoluteCurrentValue` / `SetOptions` で TaggingRules・CellTags・CellEpilog・CellProlog・NotebookEventActions 等 | Error | ○ |
| SEP-PRIVATE | `NBAccess`Private`*` シンボルの参照 | Error | ○ |
| SEP-GLOBAL | NBAccess の `$NB*` への代入・AppendTo・Part 代入・Clear 等 (`Block` での一時上書きは Review) | Error | ○ |
| SEP-CELLOBJ | `::usage` を持つ公開関数の引数に `_CellObject` | Review | × |
| CRED-SYSCRED | `SystemCredential` の呼び出し (NBAccess 以外。NotebookExtensions も対象) | Error | ○ |
| CRED-LITERAL | 文字列リテラル中の API キー・トークン形式 (Code 欄は `[REDACTED]`) | Error | × |
| PRIV-NB-READ | PrivacyLevel を見ずに `.nb` を読む: `Import[_, "Notebook"\|"NB"]`・`.nb` の `Import`/`Get`・`NotebookImport`/`NotebookGet`/`NotebookOpen` | Error (2026-10-31 に Review から格上げ) | ○ |
| PRIV-NB-WRITE | `Export` で Notebook / `.nb` / `"NB"` を書く | Error | ○ |
| PRIV-LLM-CHANNEL | `LLMSynthesize` / `LLMFunction` / `ChatEvaluate` など、ルータと課金フラグを通らない LLM (rule 21) | Error | ○ |
| PRIV-EGRESS-LLM | 同じ定義に LLM API のホストが書かれ、`URLRead` 等や `RunProcess` で送信している | Review | × |
| PRIV-LEVEL-LITERAL | `"PrivacyLevel" -> 0.5 未満の定数` (rule 61) | Review | × |
| PRIV-MODEL-OVERRIDE | `$ClaudeModel` / `$ClaudePrivateModel` / `$ClaudeTestModel` / `$ClaudeFallbackModels` の書き換え | Review | × |
| ACC-ELEVATED | `"AccessLevel" -> 0.7 以上の定数` | Review | × |
| ACC-UNTRUSTED | `"AccessLevel"` が関数の引数や `OptionValue` から決まる | Review | × |

- ゲートウェイ (規則を当てないファイル): SEP- と PRIV-NB- は `NBAccess*` / `NotebookExtensions*` と `$NBSeparationIgnoreList`、CRED-SYSCRED・PRIV-LEVEL-LITERAL・ACC- は `NBAccess*`、PRIV-EGRESS-LLM は `claudecode*` / `NBAccess*`、PRIV-MODEL-OVERRIDE は `claudecode*` / `NBAccess*` / `localInit*`。
- 「AccessLevel に変数を使うな」という旧 k 規則は廃止した。計算値の AccessLevel は違反ではなく、棚卸し (AccessSites) で出所 (Literal / NBAccessAPI / Option / Parameter / Other) を見る。
- AutoFix × の規則はセキュリティ判断を含むので、修正案を作らない (View のボタンも押せない)。人が直すか waiver を書く。

### PRIV-NB-READ の直し方 (2026-10-31 の仕分けで決めた型)

| 用途 | 扱い | 例 |
|---|---|---|
| `.nb` のメタデータ (NotebookStatus セル・TaggingRules) だけを読む | NBAccess API に置き換える: `NBFindCellByPredicate[path, pred]` (セルを `HoldComplete` で返す)、`NBFileLoadSlim[path]` (式全体)、`NBReadHeader` / `NBReadTodos` | SourceVault_issues・SourceVault_mailagenda の逆引き、SourceVault の TodoItem TaggingRules |
| 利用者の操作でノートを画面に開くだけ (中身をカーネルに読まない) | waiver「表示するだけで、中身はカーネルに読まない」 | 保存済みサマリーノートを開く、元ノートを開く |
| ツールが処理対象として渡されたノート自身を読む | waiver。送信先 (LLM・cloud の音声・YouTube・VR ワールド) の側で PrivacyLevel と Private 宣言を判定していることを確かめてから | SlideWorkflow のデッキ (`iSWDeckPrivacy` = 指示の PrivacyLevel と Private 宣言の最大を、LLM の `iSWRefinePrivacy` と cloud の声の `iSWCloudVoiceRefusal` が使う) |
| 中身を外に出す (VR・共有画面など) | 読む前に `NBFileSpec[path]["PrivacyLevel"]` の最大で判定し、超えたら読まずに断る。そのうえで waiver。`.nb` 以外のファイルをパスで受ける入口も同じ判定にする (パスを 0.0 扱いしない) | ResoniteRealtime_tablet の `itFilePL` / `itPageSpecFailure` |

送信する側の入口も同じ考え方で揃えた (2026-10-31): `SourceVaultRealtimeStart` / `SourceVaultRealtimeRender` は `"Notebook"` が Private 宣言なら始めない。新しく外へ送る経路を作るときは、送る直前に「ノートの宣言 (`NBNotebookRequiredAccessLevel`)」と「データの PrivacyLevel」の両方を見る。

## 正当な箇所の扱い (waiver と確認済み記録)

- **ソースに書く waiver** (コードと一緒に残る。推奨): 該当行か直前行に
  `(* :PolicyWaiver: PRIV-LEVEL-LITERAL 公開 arXiv のメタデータなので 0.0 *)`。
  ファイル全体なら先頭 40 行に `(* :PolicyLintIgnore: PRIV-NB-READ 理由 *)`。規則 ID はカンマ区切りで複数、`*` は全規則。**理由が空なら無効**。waiver の付いた検出は `Waived` に記録され、Status と Counts から外れる。
- **ローカルの確認済み記録** (View の [問題なし]): `<pkg>_info/separation_review.json` に理由つきで保存し、ソースは変えない。照合キーは ファイル名・規則 ID・定義名・コード内容 (行番号を含まないので行がずれても効く)。旧方式の分類 (a〜j) で付けた記録は、規則 ID が変わったので新しい行には対応しない。

## 修正案 (View の [修正案] / `ClaudeSeparationFixProposal`)

1. 違反行を含むトップレベル定義の範囲を CodeParser で決める (最大 `"MaxBlockLines"` 300 行)。
2. 指示文は `fix-proposal-prompt.md` (このフォルダ) を実行時に読む。**指示を変えるときは .wl でなくこの md を直す** (rule 03)。
3. `ClaudeQuerySync[prompt, "PrivacyLevel" -> pl]` (pl はファイルの `:CodePrivacyLevel:`、無ければ 0) に定義ブロックだけを送る。
4. 修正案を検証し、構文エラー・定義名の集合の変化・AccessLevel / PrivacyLevel / PrivacySpec の変化があれば `"Rejected"`。違反の数え直しは `NBAuditPackageSourceText`。
5. 適用 (`ClaudeSeparationApplyFix[p, "DryRun" -> False]`) は、ハッシュでファイルが変わっていないことを確かめ、`<pkg>_info/history/pre_<時刻>/<file>.cz` に元の本文をそのまま保存してから該当範囲だけを置き換える (CRLF・BOM を保つ)。読み込み済みのパッケージは読み込み直すまで変わらない。

## LLM 仕分け (任意、`ClaudeSeparationTriage`)

- View の詳細欄の [LLM に判定を聞く] を押したときだけ動く (既定では何もしない)。
- 定義ブロックだけを `ClaudeQuerySync` (PrivacyLevel はファイルの `:CodePrivacyLevel:`) で送り、`Verdict` (Legitimate / Violation / Unsure) と理由を受け取る。
- Legitimate のときは waiver の理由案を [問題なし] の欄に入れ、ソースに書く場合の `:PolicyWaiver:` コメントも示す。**記録・判定・ソースは自動では変わらない** (押すのは人)。Error を LLM の判断で消す経路は無い。
- 指示文は `triage-prompt.md` (このフォルダ)。JSON は `ImportByteArray` で読む (rule 30)。読めない応答は Unsure。

## コミット時の警告 (github.wl、止めない)

- `PackageCommitPlan` が追加・変更された `.wl` を検査し、ミラー (`GithubRepositories/<pkg>` = 前回コミット) の同じファイルの検査結果と比べて、**このコミットで増えた検出**を `"PolicyLint" -> <|Status, New, NewErrors, NewReview, Resolved, Counts, Unchecked, Files|>` で返す。照合は ファイル・規則 ID・定義名・コード で、行番号は使わない (前に行を足しただけで「増えた」とは数えない)。
- `PackageCommit` は DryRun でも実コミットでも `PackageCommit::policylint` (増えた検出) / `::policylintunchecked` (時間上限 `"PolicyLintTimeBudget"` 60 秒を超えた・解析できなかったファイル) を警告する。**コミットは止めない**。未検査を「問題なし」とは扱わない。
- `GitHubRefreshAndCommit` を直接呼んだときも同じ検査と警告をする (`"PolicyLint" -> False` で省略。`PackageCommit` からは二重にならないよう False で呼ぶ)。

## ClaudeCheckSeparation / ClaudeFixSeparation

- `ClaudeCheckSeparation[target]` は `NBAuditPackageSource` の結果をコンソールに表示し、`{<|"file", "violations" -> {<|"line", "code", "violation" (規則 ID), "description", "severity"|>..}|>..}` を返す。waiver の付いた検出は含めない。文字列の target なら `$iSeparationCheckCache` に保存する。
- `ClaudeFixSeparation[target]` は旧来の「LLM にファイル全文を書き直させる」修正。大きなファイルでは失敗しやすい。**通常は View の [修正案] を使う**。
- `ClaudeUpdatePackage["pkg"]` (引数 1 つ) は検査して結果を返すだけで、修正はしない。

## $NBSeparationIgnoreList

NBAccess.wl で定義。既定 `{"NBAccess", "NotebookExtensions"}`。ここに入ったパッケージは SEP- と PRIV-NB- の規則の対象外 (CRED- などは対象)。

## テスト

- `test codes/NBAccess_policylint_test.wl` — エンジンの規則・waiver・棚卸し・解析省略・fail-closed
- `test codes/ClaudePackageManager_separationview_test.wl` — View・修正案と LLM 仕分け (LLM はスタブ)・適用・確認済み記録・ClaudeCheckSeparation
- `test codes/github_policylint_commit_test.wl` — コミット時の警告 (前回との比較・未検査の警告) と、実パッケージでの `PackageCommit` DryRun (読み取りのみ)
- `test codes/NBAccess_policylint_phase4_test.wl` — PRIV-NB-READ が Error であること、仕分けた 18 か所に理由付き waiver があること、置き換えた読み取り (Todo TaggingRules は旧 NotebookImport 版と同じ結果)、SlideWorkflow の Private 宣言、Resonite の `.nb` 判定

どれも `wolframscript -file` で実行し、一時フォルダの fixture とテスト用のキャッシュファイルだけに書き込む。
