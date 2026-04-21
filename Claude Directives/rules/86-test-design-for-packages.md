---
paths:
  - "**/*test*.{wl,wls,m,nb}"
  - "**/*_test.{wl,wls,m,nb}"
  - "**/test_*.{wl,wls,m,nb}"
  - "**/ClaudeTestKit*.{wl,wls,m,nb}"
---

# 86 — パッケージを扱うテスト設計の注意点

## 背景

Phase 33 Task 1 (NotebookLLMGraph × Snapshot merge) の E2E テスト構築で、
T28 → T34 までの 7 回の失敗/修正サイクルを経て確立した、**パッケージ Private 境界を
跨ぐテストを書く際の設計原則**。Rule 11 は production code の観点、この Rule は
test code の観点を扱う(補完関係)。

テストコードが壊れる原因の多くは **Private 変数への直接操作** と **cache 汚染** に
集約される。以下の原則に従わないと、production コードが正しく動作していても
テストが誤動作し、開発効率を著しく損なう。

## 原則 1: Private 変数の subscript 代入は禁止

### 禁止パターン

```mathematica
(* ❌ 禁止: package Private Association への subscript 代入 *)
ClaudeCode`Private`$iLLMGraphDAGJobs["job-id"] = <|"nodes" -> ..., ...|>;
```

### なぜ失敗するか

Mathematica のコンテキスト解決のタイミング上、外部コンテキストから
`pkg`Private`$var[key] = value` を評価しても、**package 内部の関数が参照する
`$var` とは異なる symbol identity にバインドされる場合がある**。

症状:
- 外部からは `KeyExistsQ[$var, "job-id"]` が True を返す
- 一方、package 内部関数は **`Missing["JobNotFound"]` を返し続ける**
- assertion が「登録確認」では通るが「使用時」で失敗するカスケード崩壊

### 代替パターン

#### パターン A: 公開 API を使う(最優先)

```mathematica
(* ✅ 正しい: 公開 API 経由で package 内部に仕事をさせる *)
jobId = ClaudeCode`LLMGraphDAGCreate[<|
  "nodes" -> {ClaudeCode`iLLMGraphNode["n1", "sync", "sync", {},
    Function[{n, j}, "ok"]]},
  "taskDescriptor" -> <|"name" -> "test"|>,
  "nb" -> EvaluationNotebook[],
  "onComplete" -> Function[j, Null],
  "context" -> <|"SessionTag" -> "test-tag"|>
|>];
```

非同期処理なら公開 status API で polling する:

```mathematica
(* ScheduledTask の完了待機 *)
$waitDone[jobId_, timeoutSec_:15] :=
  Module[{start = AbsoluteTime[], status, done = False},
    While[!done && (AbsoluteTime[] - start) < timeoutSec,
      status = ClaudeCode`LLMGraphDAGStatus[jobId];
      If[AssociationQ[status] &&
          Lookup[status, "Pending", 1] === 0 &&
          Lookup[status, "Running", 1] === 0,
        done = True, Pause[0.3]]]; done];
```

#### パターン B: Private 関数呼び出し

公開 API でカバーできない状態操作は、**Private の関数**を呼ぶ。関数呼び出しは
package 内部のコンテキストで評価されるので symbol identity 問題は起きない。

```mathematica
(* ✅ 正しい: Private の関数を呼んで package 内部に状態変化を任せる *)
ClaudeCode`Private`iSaveNotebookLLMGraph[nb, graphData];
ClaudeCode`Private`iLoadNotebookLLMGraph[nb];  (* cache を TaggingRules から更新 *)
```

前提: その Private 関数が `BeginPackage` 直後の `ClearAll` リストに登録されて
いること(Rule 11 参照)。

## 原則 2: cache を持つパッケージの更新は cache も必ず refresh

### 症状

`iSaveNotebookLLMGraph` のように TaggingRules を書き換える関数は、**in-memory
cache (`$iLLMGraphCache`) を更新しない**。次に `NotebookLLMGraph[nb]` を呼ぶと、
cache hit により **古い値が返る**。

### 必須手順

書き込み系関数を呼んだ直後は、**cache 再読込関数**を呼んで整合性を取る。

```mathematica
(* ✅ 正しい: 書き込み → cache refresh をペアで *)
ClaudeCode`Private`iSaveNotebookLLMGraph[nb, newGraph];
Quiet @ ClaudeCode`Private`iLoadNotebookLLMGraph[nb];  (* cache 更新 *)
```

`iLoadNotebookLLMGraph` は内部で `$iLLMGraphCache = ...` を実行するため、
symbol identity 問題の影響を受けない(package 内部で代入される)。

### 片付け時も同様

テスト終了時に元の状態に戻す際も:

```mathematica
(* cleanup *)
If[AssociationQ[$backupGraph],
  ClaudeCode`Private`iSaveNotebookLLMGraph[nb, $backupGraph];
  Quiet @ ClaudeCode`Private`iLoadNotebookLLMGraph[nb]];  (* ← これを忘れない *)
```

これを怠ると **次のテスト実行時に stale cache が残り**、apparently 無関係な
テストがカスケードで失敗する。

## 原則 3: シンボル存在チェックは `Length[Names["pkg`Symbol"]] > 0` を使う

### 落とし穴

```mathematica
(* ❌ 禁止: これは $ContextPath の状態で挙動が変わる *)
MemberQ[Names["ClaudeCode`*"], "ClaudeCode`LLMGraphDAGMergeHistory"]
```

`Names["pkg`*"]` は `$ContextPath` に `pkg\`` が含まれている場合、**コンテキスト
プレフィックスを省いた**文字列を返す:

```mathematica
Names["ClaudeCode`*"]
(* = {"LLMGraphDAGMergeHistory", "NotebookLLMGraph", ...} *)
(* ← "ClaudeCode`" prefix が付かない *)
```

そのためフル名との `MemberQ` は常に False を返す。

### 正しいパターン

```mathematica
(* ✅ 正しい: Names に完全修飾名を渡す。存在すれば長さ 1 のリスト、なければ空リスト *)
If[Length[Names["ClaudeCode`LLMGraphDAGMergeHistory"]] === 0,
  Print["T28 未満"]; Abort[]];
```

この形式は `$ContextPath` の状態に依存しない。

## 原則 4: テストファイル冒頭に version marker を Print する

### 動機

外部配布されたテストファイルは、**古いキャッシュ版が意図せずロードされる**ことが
ある(`FindFile` が複数の候補パスから古い版を選ぶ等)。冒頭で version を
Print することで、ユーザは目視で「今動いているのはどの版か」を即座に確認できる。

```mathematica
Print[Style["\n=== NotebookLLMGraph Merge E2E Test ===", Bold, Blue]];
Print[Style["  File version: 2026-04-17T34-force-cache-refresh",
  GrayLevel[0.4]]];
```

バージョン文字列は日付 + 連番 + 簡潔な説明で、**ファイル改訂ごとに必ず更新**。

## 原則 5: 失敗時の診断 Print を組み込む

### 症状

assertion がうまく条件式で「False」を返すだけだと、**なぜ False なのかが
分からない**。特に戻り値が `Missing[JobNotFound]` / `$Failed` / 未評価式のどれかで、
原因診断の戦略が変わる。

### 必須パターン

条件の手前で、予期と異なる値が来たら `Short[..., 3]` で内容を Print:

```mathematica
$result = Quiet @ ClaudeCode`LLMGraphDAGSnapshot[jobId];

If[!AssociationQ[$result],
  Print[Style["    [diag] LLMGraphDAGSnapshot returned: " <>
    ToString[Short[$result, 3]], Orange]];
  Print[Style["    [diag] LLMGraphDAGStatus: " <>
    ToString[Short[ClaudeCode`LLMGraphDAGStatus[jobId], 3]], Orange]]];

e2eCheck["LLMGraphDAGSnapshot returned Association",
  AssociationQ[$result]];
```

この 3 行で「戻り値が Missing なのか $Failed なのか未評価か」を 1 回の実行で切り分けできる。

## 原則 6: テストは side effect を完全に片付ける

### 副作用のある操作と対処

| 副作用 | 対処 |
|---|---|
| TaggingRules 改変 | backup → 書換 → cleanup で restore |
| `$iLLMGraphCache` 更新 | restore 後 `iLoadNotebookLLMGraph` で refresh |
| Private Assoc への job 追加 | 公開 API の job は自然消滅、手動なら `KeyDrop` |
| 新規 NotebookObject 生成 | `NotebookClose` |
| Snapshot directory 作成 | `DeleteDirectory[..., DeleteContents -> True]` |
| `$NBConfidentialSymbols` 書換 | backup/restore |
| Top-level `$testVar` 群 | 害は少ないが `ClearAll["Global`$test*"]` が望ましい |

### 推奨テンプレート

```mathematica
(* テスト冒頭: backup *)
$backupGraph = Quiet @ ClaudeCode`NotebookLLMGraph[$nb];
$backupConf = If[ValueQ[NBAccess`$NBConfidentialSymbols],
  NBAccess`$NBConfidentialSymbols, Null];

(* ... テスト本体 ... *)

(* テスト末尾: cleanup *)
If[AssociationQ[$backupGraph],
  ClaudeCode`Private`iSaveNotebookLLMGraph[$nb, $backupGraph];
  Quiet @ ClaudeCode`Private`iLoadNotebookLLMGraph[$nb]];  (* cache も *)
If[$backupConf =!= Null, NBAccess`$NBConfidentialSymbols = $backupConf];
If[MatchQ[$createdNB, _NotebookObject], Quiet @ NotebookClose[$createdNB]];
If[DirectoryQ[$tmpSnapDir],
  Quiet @ DeleteDirectory[$tmpSnapDir, DeleteContents -> True]];
```

副作用を残すと**次のテスト実行がランダムに失敗する**。Phase 33 Task 1 の
T28→T34 で 5 セッション分のデバッグを浪費した根本原因はこれ。

## 原則 7: 非同期処理の完了は `Pause` 即決めでなく polling

### 禁止

```mathematica
(* ❌ 禁止: 固定時間 Pause は flaky の温床 *)
ClaudeCode`LLMGraphDAGCreate[spec];
Pause[5];  (* たぶん終わってるはず ... *)
ClaudeCode`LLMGraphDAGSnapshot[jobId];
```

### 推奨

公開 status API で状態が settle するまで polling。timeout を必ず設定:

```mathematica
$waitDone[jobId_String, timeoutSec_:15] :=
  Module[{start = AbsoluteTime[], status, done = False},
    While[!done && (AbsoluteTime[] - start) < timeoutSec,
      status = Quiet @ ClaudeCode`LLMGraphDAGStatus[jobId];
      If[AssociationQ[status] &&
          Lookup[status, "Pending", 1] === 0 &&
          Lookup[status, "Running", 1] === 0,
        done = True,
        Pause[0.3]]];
    done];
```

戻り値 `True/False` を使って timeout 時に明確な診断ができる:

```mathematica
$done = $waitDone[jobId, 15];
If[!TrueQ[$done],
  Print[Style["[diag] timeout, status = " <>
    ToString[ClaudeCode`LLMGraphDAGStatus[jobId]], Orange]]];
e2eCheck["Job completed", TrueQ[$done]];
```

## 原則 8: `HoldAll` 属性で check を汎用化

```mathematica
e2eCheck[label_String, cond_] := (
  $step++;
  If[TrueQ[Quiet @ Check[cond, False]],
    $passed++;
    Print["  \[Checkmark] [", $step, "] ", label],
    $failed++;
    AppendTo[$fails, label];
    Print[Style["  \[Cross] [" <> ToString[$step] <> "] " <> label, Red]]]);
SetAttributes[e2eCheck, HoldAll];
```

`HoldAll` が無いと、条件式の評価時に発生した例外/警告が assertion の前に出力され、
どの行で何が起きたかが分からなくなる。`Quiet @ Check[cond, False]` で包むことで、
条件式が例外を投げても `False` として安全に処理される。

## 原則 9: 既存の mock test を壊さない

公開 API にオプションを追加する際は、**既定値は従来動作と一致**させる:

```mathematica
(* ✅ 正しい: 既定値が従来動作 *)
Options[LLMGraphDAGSnapshot] = {
  "AuxiliaryState"   -> <||>,
  "IncludeFullGraph" -> False,
  "IncludePrivate"   -> False   (* 新設。既定は従来通り *)
};
```

内部関数のシグネチャ拡張も必ず「追加引数はデフォルト値付き」:

```mathematica
(* ✅ 正しい: includePrivate の既定値を False にして従来呼び出しを壊さない *)
iLLMGraphDAGSaveSnapshotGraph[snapDir_String, job_Association,
    includeFullGraph_:False, includePrivate_:False] := ...
```

従来の mock test が全部通ることは、拡張実装後に**必ず再確認**する(regression の検出)。

## 原則 10: Option のデフォルト値を確認してからガード条件を書く

### 失敗例(T27 test で実際に起きた)

「`StartTime` が指定されていなければ dispatch する」ガードのつもりで:

```mathematica
(* ❌ 間違い: デフォルトを調べずに None と思い込んだ *)
stVal = OptionValue[ClaudeEval, optsList, StartTime];
If[stVal =!= None, Return[$iClaudeEvalNotDispatched]];
```

しかし実際の `Options[ClaudeEval]` は `StartTime -> Now`。デフォルトが `None` ではないので、**常に skip 条件に合致**し dispatch が一度も発火しない。

### 正しい手順

1. `Options[Fn]` を必ず調べて、各オプションのデフォルト値を確認する
2. 「未指定なら dispatch する」のような条件は **デフォルト値と区別できる形** で書く
3. 値の意味を検査する(例: StartTime なら「未来時刻か」)

```mathematica
(* ✅ 正しい: 「本当に未来時刻か」を検査 *)
stVal = OptionValue[ClaudeEval, optsList, StartTime];
stIsFuture = Quiet @ Check[
  AbsoluteTime[stVal] > AbsoluteTime[] + 5,
  False];
If[TrueQ[stIsFuture], Return[$iClaudeEvalNotDispatched]];
```

### 教訓

Option のデフォルト値は仕様書だけでなく**コードで確認する**。特に長年運用されてきたパッケージでは、`None` より `Automatic` や `Now` など意味のあるデフォルトが設定されていることが多い。

## 原則 11: 外部差し込み関数の呼び出しは `Catch[..., _, f]` で囲む

### 失敗例(T28 test で実際に起きた)

外部から差し込まれた hook を呼び出すとき:

```mathematica
(* ❌ 危険: Throw をキャッチしない *)
result = Quiet @ Check[hook[task, mode, optsList], $Failed];
```

`Check[]` は **Message だけ**をキャッチする。hook が `Throw[value, tag]` を発生させると、キャッチされずに呼び出し元まで伝播し、テストが途中で中断する。

### Mathematica の Throw/Catch 意味論(重要)

| パターン | 捕捉するもの |
|---|---|
| `Catch[expr]` (form なし) | **任意の Throw**(tagged / untagged 両方) |
| `Catch[expr, form]` | `Throw[v, tag]` で tag が form にマッチするもののみ |
| `Catch[expr, form, f]` | 上記 + `f[value, tag]` を適用 |
| `Throw[v]` (tag なし) | `Catch[expr]` のみで捕捉可、`Catch[expr, _]` では**捕捉されない** |
| `Throw[v, tag]` (tag あり) | `Catch[expr, pattern]` で tag がマッチすれば捕捉 |

つまり、`Catch[expr, _, f]` は **untagged Throw を捕捉しない**。信頼境界を越える関数呼び出しは両方を想定すべき。

### 正しいパターン

```mathematica
(* ✅ 正しい: Catch + Check の組み合わせで tagged Throw と Message を両方捕捉 *)
result = Quiet @ Check[
  Catch[hook[task, mode, optsList],
    _,  (* 任意タグにマッチ *)
    Function[{val, tag}, $Failed]],
  $Failed];
```

これは **tagged Throw と Message+$Failed** の両方に対処する。untagged `Throw[v]` は防げないため、**hook 側が untagged Throw を使わない**規約が必要。

### 呼び出し側への要件

信頼境界を越える hook を実装する側への規約:

- ❌ `Throw[v]` (untagged) を使わない — 捕捉できず呼び出し元が破綻する
- ✅ `Throw[v, tag]` (tagged) を使う — 呼び出し元が `Catch[..., _]` で捕捉可
- ✅ `Message[] + $Failed` を使う — 呼び出し元が `Check[]` で捕捉可
- ✅ 単に `$Failed` を返す — 戻り値パターンマッチで判定可

### 3 種の失敗シグナルまとめ

Mathematica には **3 種の失敗シグナル** がある:

| シグナル | 伝播経路 | キャッチ方法 |
|---|---|---|
| Message (`General::...`) | SystemMessageList | `Check[..., fallback]` |
| Tagged Throw (`Throw[v, tag]`) | コールスタックを遡る | `Catch[..., _, f]` |
| Untagged Throw (`Throw[v]`) | コールスタックを遡る | `Catch[expr]` のみ(form なし) |
| `$Failed` 戻り値 | 通常の戻り値 | 戻り値のパターンマッチで判定 |

**tagged Throw + Message + $Failed までを処理する defensive pattern**:

```mathematica
safeCall[fn_, args_, fallback_] :=
  Module[{result},
    result = Quiet @ Check[
      Catch[fn @@ args,
        _, Function[{val, tag}, fallback]],
      fallback];
    If[result === fallback, fallback, result]];
```

テストで hook の失敗を simulate するときは、**tagged Throw または Message+$Failed**
を使う。`Throw[v]` (untagged) は hook 実装の規約違反であり、テストの簡潔性のためにも
避ける。

## 原則 12: Private コンテキスト内で公開シンボルを参照するときはフルコンテキスト付きで書く

### 失敗例(T33 test で実際に起きた)

`Begin["`Private`"]` 内のコードで、公開シンボルを**無修飾名**で参照すると、
Mathematica がそれを **Private コンテキストの別シンボル**として解釈することがある。

```mathematica
BeginPackage["ClaudeCode`"];
Quiet[ClearAll[..., "$ClaudeEvalVerbose", ...]];  (* ClaudeCode`$ClaudeEvalVerbose を作成 *)

...

Begin["`Private`"];

(* \:274c \:5371\:967a: \:7121\:4fee\:98fe\:540d\:3067\:306e\:521d\:671f\:5316 *)
If[!ValueQ[$ClaudeEvalVerbose], $ClaudeEvalVerbose = False];
(* \:2192 ClaudeCode`Private`$ClaudeEvalVerbose \:306b\:88ab\:5bfe\:5fdc\:3055\:308c\:308b\:53ef\:80fd\:6027 *)

(* \:274c \:7121\:4fee\:98fe\:540d\:3067\:306e\:53c2\:7167 *)
If[TrueQ[$ClaudeEvalVerbose], Print["..."]];
```

### 症状

- ユーザが `ClaudeCode\`$ClaudeEvalVerbose = True` と設定する
- しかし Private 関数内で `$ClaudeEvalVerbose` が **False** のまま読まれる
- 外部 (他パッケージなど) からの参照は正しく動作するが、**package 内部の参照だけ壊れる**

### 正しいパターン

**公開シンボル参照は常に明示的なフルコンテキスト**:

```mathematica
(* \:2705 \:521d\:671f\:5316\:3082\:53c2\:7167\:3082 ClaudeCode` \:4ed8\:304d\:3067 *)
If[!ValueQ[ClaudeCode`$ClaudeEvalVerbose],
  ClaudeCode`$ClaudeEvalVerbose = False];

iSomeFunc[...] :=
  If[TrueQ[ClaudeCode`$ClaudeEvalVerbose],
    Print["verbose log"]];
```

### 教訓

`BeginPackage` 直後の `ClearAll` でシンボルを**作成済み**でも、Private 内で**無修飾名**を書くと Mathematica のシンボル解決ルール(`$ContextPath` が Private 優先)により別シンボルにバインドされることがある。特に`If[!ValueQ[...]]` で初期化を書くと、ValueQ が False だったときに**その場で Private シンボルを作成**してしまう。

**公開シンボルを package 内から参照するときは、必ず `pkg\`$var` と明示**。

## 原則 13: `If[cond, stmt1; stmt2]` は `If[cond, stmt1, stmt2]` に解釈される

### 失敗例(T35 test で実際に起きた)

hook 内で以下のように書いた:

```mathematica
(* \:274c \:30d0\:30b0: Return \:304c else \:5206\:5c90\:306b\:306a\:308b *)
If[cond,
  If[verbose, Print["..."]];     (* \:5f0f A *)
  Return[$Failed]];               (* \:5f0f B *)
```

Mathematica は `If[arg1, arg2, arg3]` の **3 引数版** として解釈:
- arg1 (cond): `cond`
- arg2 (then): `If[verbose, Print["..."]]`  \:2190 \:30bb\:30df\:30b3\:30ed\:30f3\:3067\:533a\:5207\:3089\:308c\:305f\:6700\:521d\:306e\:5f0f
- arg3 (else): `Return[$Failed]`              \:2190 \:30bb\:30df\:30b3\:30ed\:30f3\:3067\:533a\:5207\:3089\:308c\:305f 2 \:3064\:76ee\:306e\:5f0f

**結果: cond が True のとき Print だけ実行、Return は実行されない**。

### 症状

- hook が Print を出して「fallback します」と宣言するのに、**実際にはその後のコードを継続実行**
- `Return[$Failed]` が実行されないので、hook は最後に走った値を返す
- 呼び出し元は `$Failed` ではない値を受け取り、想定外の動作になる

### 正しいパターン

**複数文を then 側で実行するときは必ず `( ... )` で明示的にグループ化**:

```mathematica
(* \:2705 \:6b63\:3057\:3044 *)
If[cond,
  (
    If[verbose, Print["..."]];
    Return[$Failed]
  )];

(* \:307e\:305f\:306f CompoundExpression \:3092\:660e\:793a *)
If[cond,
  CompoundExpression[
    If[verbose, Print["..."]],
    Return[$Failed]]];
```

### 教訓

Mathematica の `If` は 2/3/4 引数版があり、セミコロン区切りの複数式は自動的に `CompoundExpression` になるとは限らない。**特に複数行の then 本体には `( ... )` を必須**とする。

## 原則 14: `Function` 内の `Return` は制御フローが予測不能

### 失敗例(T37 test で実際に起きた)

```mathematica
(* \:274c \:5371\:967a: Function + Module + Return *)
hook = Function[{task, mode, optsList},
  Module[{...},
    If[cond, Return[$Failed]];   (* \:2190 \:3069\:3053\:304b\:3089 return \:3059\:308b\:304b\:4e0d\:660e *)
    ...
  ]];

(* \:547c\:3073\:51fa\:3057\:5143 *)
myFunc[...] := Module[{result},
  result = hook[...];              (* Return[$Failed] \:304c\:3053\:3053\:306b\:5c4a\:304f\:304b\:3082 ... *)
  Print["hook returned: ", result]; (* \:2190 \:5b9f\:884c\:3055\:308c\:306a\:3044\:53ef\:80fd\:6027 *)
  ...
];
```

### 症状

hook 内の `Return[$Failed]` が:
- Function 内の Module から抜けるはず
- しかし **呼び出し元のユーザ関数 (`myFunc` 等) まで伝播**する場合がある
- 呼び出し元の `Print` や後続処理が **全て skip** される
- 最外ユーザ関数が **hook の戻り値でそのまま終了**する

Mathematica の `Return` は以下の動作が仕様:
- `f[x_] := Module[..., Return[v]]` では **`f` から抜ける**(Module ではない)
- `Function[{x}, Module[..., Return[v]]]` では **動作が曖昧** — Function または呼び出し元まで

### 正しいパターン: 戻り値代入パターン

`Function` 内では **`Return` を一切使わず**、戻り値を変数に代入する:

```mathematica
(* \:2705 \:6b63\:3057\:3044: \:30c7\:30d5\:30a9\:30eb\:30c8\:5024 + \:6761\:4ef6\:306b\:3088\:308a\:4e0a\:66f8\:304d + \:6700\:5f8c\:306b\:8fd4\:3059 *)
hook = Function[{task, mode, optsList},
  Module[{retval},
    retval = $Failed;  (* \:30c7\:30d5\:30a9\:30eb\:30c8 *)
    Which[
      mode === "Auto",
        (* ... \:51e6\:7406 ... *)
        Which[
          \:6761\:4ef6 A, retval = $Failed,  (* \:4ee3\:5165\:3067\:30d5\:30a9\:30fc\:30eb\:30d0\:30c3\:30af *)
          \:6761\:4ef6 B, retval = result
        ],
      True, retval = $Failed
    ];
    retval  (* Module \:306e\:6700\:5f8c\:306e\:5f0f\:304c\:623b\:308a\:5024 *)
  ]];
```

この書き方は **`Return` の曖昧さを完全に回避**し、制御フローが予測可能になる。

### 教訓

Mathematica の `Return` には**罠が 2 つ**ある:
1. 通常の関数定義 (`f[x_] := ...`) では Module ではなく**関数全体**から抜ける
2. `Function` と組み合わせると**制御フローが予測不能**

**hook や callback を `Function` で定義する場合、`Return` を使わず、`Module` の最後に戻り値を書く代入パターンを徹底する**。

## 確認チェックリスト

テストファイルを書き終えたら、以下をすべて確認:

- [ ] **Version marker** を冒頭で Print している
- [ ] `Length[Names["pkg`Symbol"]] > 0` で存在チェックしている
- [ ] Private の subscript 代入(`pkg`Private`$var[key] = ...`)を使っていない
- [ ] 書き込み系関数の直後に cache refresh を呼んでいる
- [ ] テスト冒頭で副作用対象を backup、末尾で restore している
- [ ] 非同期処理は timeout 付き polling で待機している
- [ ] assertion 条件は `HoldAll` 付き helper でラップされている
- [ ] 失敗時に **`Short[returnedValue, 3]` の診断 Print** を組み込んでいる
- [ ] 拡張時は既定値で従来動作を保ち、既存 mock test を再走して regression 無しを確認
- [ ] Option のデフォルト値を `Options[Fn]` で確認してガード条件を書いている
- [ ] 外部差し込み関数は `Catch[..., _, f]` と `Check[..., fallback]` の両方で保護している
- [ ] Private 内から公開シンボルを参照するときは `pkg\`$var` とフルコンテキスト付きで書く
- [ ] `If[cond, stmt1; stmt2]` の形を書かない(then 複数文は `( ... )` で囲む)
- [ ] `Function` 内で `Return` を使わず、戻り値代入パターンで最後の式を値とする

この 14 項目をすべて満たすことで、T28→T38 の一連の調査で経験した**「なぜ失敗するか分からない」タイプの失敗**を回避できる。
