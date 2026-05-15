---
paths:
  - "**/*.{wl,m}"
---

# パッケージ名前空間移管時の shadowing 罠と回避パターン

## 概要

既存パッケージ (例: `claudecode.wl`) の関数を新パッケージ (例: `ClaudePackageManager.wl`) に分離・移管する際、Mathematica の context resolution と `BeginPackage` の挙動により **意図しない shadowing** が発生し、**既存パッケージの関数が連鎖的に破損** する。

このスキルは、その罠の原因と、Phase ごとの安全な実装パターンをまとめる。失敗事例 (ClaudePackageManager v0.1〜v0.3) を経て確立した知見。

## 罠の本質: `BeginPackage["P`"]` (依存リストなし) の context path リセット

### 起きること

```mathematica
(* 既存: ClaudeCode\` がロード済み *)
$ContextPath
(* {"ClaudeCode`", "System`"} など *)

(* 新パッケージで BeginPackage を依存リストなしで開始 *)
BeginPackage["NewPkg`"];
(* この瞬間、$ContextPath は {"System`"} にリセットされる
   ClaudeCode\` は context path から一時的に消える *)

(* 既存パッケージと同名のシンボルに対して usage 宣言 *)
ClaudeUpdatePackage::usage = "...";

(* この時点での挙動:
   - context path に ClaudeCode\` がない
   - ClaudeUpdatePackage を context path で探す → 見つからない
   - $Context (= "NewPkg`") に新規シンボル NewPkg`ClaudeUpdatePackage を作成
   - usage 文字列がそこに設定される
   - 元の ClaudeCode`ClaudeUpdatePackage は別シンボルとして残る (両立) *)

End[];
EndPackage[];

(* EndPackage 後、$ContextPath には "NewPkg`" が先頭に追加される *)
$ContextPath
(* {"NewPkg`", "ClaudeCode`", "System`", ...} *)
```

### 結果

その後、コード内で `ClaudeUpdatePackage` というシンボル参照を書くと:

- `$ContextPath` を順に検索
- 先頭の `NewPkg\`` で `NewPkg\`ClaudeUpdatePackage` (空シンボル) が見つかる
- これが優先される (shadowing)
- `ClaudeCode\`ClaudeUpdatePackage` (本体定義あり) は **隠される**

**致命的影響**: claudecode.wl 内部のコードも `ClaudeUpdatePackage` を context path 経由で参照している箇所がある。それらの参照が全て shadow されたシンボル (空) に解決され、既存機能が連鎖的に破損する。

特に `LLMGraphDAGCreate` のような DAG 機構は、handler や周辺 helper が様々な公開シンボルを参照するため、関連シンボルの 1 つが shadow されると DAG 全体が動かなくなる。

### 警告メッセージ抑制が罠を深める

```mathematica
Off[General::shdw];   (* shadowing 警告を抑制 *)
BeginPackage["NewPkg`"];
ClaudeUpdatePackage::usage = "...";   (* 静かに新シンボル作成 *)
...
On[General::shdw];
```

`Off[General::shdw]` で shadowing 警告を抑制すると、**問題に気づかないまま** ClaudeCode\` 側の機能が破損する。テスト実行時に初めて `n2 result: $Failed` のような不可解な失敗が出て調査に時間を取られる。

## 失敗パターン集 (ClaudePackageManager 事例)

### 失敗 1 (v0.1): `BeginPackage` 依存に既存パッケージを含めた上で delegation を書く

```mathematica
BeginPackage["ClaudePackageManager`", {"ClaudeCode`"}];

ClaudeUpdatePackage::usage = "...";   (* これは ClaudeCode`ClaudeUpdatePackage::usage を上書き *)

Begin["`Private`"];
ClaudeUpdatePackage[args___] := ClaudeCode`ClaudeUpdatePackage[args];   (* ❌ 自己再帰 *)
End[];
EndPackage[];
```

**何が起きるか**: `ClaudeUpdatePackage[args___] := ClaudeCode\`ClaudeUpdatePackage[args]` の左辺の `ClaudeUpdatePackage` は context path 経由で `ClaudeCode\`ClaudeUpdatePackage` に解決される。すると実質:

```mathematica
ClaudeCode`ClaudeUpdatePackage[args___] := ClaudeCode`ClaudeUpdatePackage[args]
```

という **自己再帰定義** になり、`ClaudeUpdatePackage` を呼ぶたびに recursion limit まで再帰する。さらに DownValues に追加されることで claudecode.wl の元定義の一部が破壊される。

### 失敗 2 (v0.2): 依存削除して usage 宣言のみ

```mathematica
Off[General::shdw];
BeginPackage["ClaudePackageManager`"];   (* 依存なし *)

ClaudeUpdatePackage::usage = "...";   (* これは新シンボル NewPkg`ClaudeUpdatePackage を作成! *)
ClaudeBuildTransactionAdapter::usage = "...";
... (9 シンボル)

Begin["`Private`"];
(* delegation は書かない *)
End[];
EndPackage[];
On[General::shdw];
```

**何が起きるか**: 上記「罠の本質」の通り、9 個の新シンボル `ClaudePackageManager\`X` (本体なし、usage のみ) が作られ、context path 先頭で claudecode.wl 内部の参照を全て shadow。LLMGraphDAGCreate を含む DAG 機構や、その他の関連機能が連鎖的に動作しなくなる。

`Off[General::shdw]` のため警告は出ず、テスト実行時の `n2 result: $Failed` 等で初めて気付く。

## 安全な実装パターン

実装フェーズに応じて以下の 3 パターンを使い分ける。

### パターン A: 名前空間確保のみ (Phase Q-2a 相当)

新パッケージを作成するが、まだ既存パッケージから関数を移管しない段階。**既存パッケージと同名のシンボルは一切宣言しない**。

```mathematica
BeginPackage["NewPkg`"];   (* 依存なしでも安全 *)

(* 既存パッケージにないシンボルのみ宣言 *)
$NewPkgVersion::usage = "...";
NewFutureFunction::usage = "...";   (* ClaudeCode 等にない名前 *)

Begin["`Private`"];

(* 値の代入は完全 namespace 修飾で行う *)
NewPkg`$NewPkgVersion = "v0.1-...";

NewPkg`NewFutureFunction[___] := ...;   (* 完全修飾、context resolution の罠を回避 *)

End[];
EndPackage[];
```

**ポイント**:
- 既存パッケージの公開シンボル名 (`ClaudeUpdatePackage` 等) は **宣言しない**
- 自パッケージ独自の新規シンボルのみ宣言
- 値の代入や関数定義は **完全 namespace 修飾** (例: `NewPkg\`X[___] := ...`) で書く
- Begin["`Private`"] 内でも完全修飾が安全

**Phase Q-2a 期間中の利用方法**: ユーザーは既存関数を `ClaudeCode\`ClaudeUpdatePackage[...]` で呼ぶ (context path 経由でも自動解決される)。新パッケージ独自シンボルは `NewPkg\`NewFutureFunction[...]` で呼ぶ。

### パターン B: 完全移管 (Phase Q-2b 相当)

既存パッケージから関数を新パッケージへ完全に移管する段階。**両者を同時に変更する**。

#### 手順

```
1. 既存パッケージ側で対象関数の Remove
   Remove["ClaudeCode`ClaudeUpdatePackage"]
   (これにより ClaudeCode 側のシンボルが消える)

2. 新パッケージ側で usage 宣言と本体定義
   BeginPackage["NewPkg`"];
   ClaudeUpdatePackage::usage = "...";   (* この時点で ClaudeCode 側にないので新規作成 *)
   ...
   Begin["`Private`"];
   NewPkg`ClaudeUpdatePackage[args___] := (* 完全実装 *) ...;
   End[];
   EndPackage[];

3. (任意) 後方互換のため deprecation alias
   ClaudeCode`ClaudeUpdatePackage = NewPkg`ClaudeUpdatePackage
   (シンボルそのものを別名として参照、再帰なし)
```

**重要**: ステップ 1 と 2 は **同一セッションで連続して** 実行する。ステップ 2 を先にすると失敗パターン 2 と同じ事態になる。

#### 検証

```mathematica
(* 既存パッケージ側のシンボルが消えている *)
Quiet @ Names["ClaudeCode`ClaudeUpdatePackage"]   (* {} を期待 *)

(* 新パッケージ側に DownValues がある *)
DownValues[NewPkg`ClaudeUpdatePackage]   (* 空でないリストを期待 *)

(* shadowing 警告が出ない *)
Get["NewPkg.wl"]   (* General::shdw 警告なしで完了 *)
```

### パターン C: 既存パッケージへ wrapper を追加 (deprecation 期間)

新パッケージに完全移管した後、既存パッケージ側に旧 API を一時的に残す場合。

```mathematica
(* claudecode.wl 内の旧定義を Remove した後 *)

(* 単純な alias (シンボル参照そのもの) *)
ClaudeCode`ClaudeUpdatePackage = NewPkg`ClaudeUpdatePackage;

(* または、deprecation 警告付き *)
ClaudeCode`ClaudeUpdatePackage[args___] := (
  Message[ClaudeCode`ClaudeUpdatePackage::deprecated,
    "Use NewPkg`ClaudeUpdatePackage instead."];
  NewPkg`ClaudeUpdatePackage[args]);
```

**重要**: ここで `:= ClaudeCode\`ClaudeUpdatePackage[args]` のような自己再帰を書かない。`NewPkg\`ClaudeUpdatePackage[args]` で完全 namespace 修飾。

## 判定フローチャート

新パッケージで宣言しようとしているシンボル名 X について:

```
X は既存パッケージ (claudecode.wl 等) で公開されているか?
│
├─ いいえ
│   └─ 通常通り usage 宣言・実装して OK (パターン A の追加分)
│
└─ はい
    │
    新パッケージへ完全に移管するか?
    │
    ├─ いいえ (現フェーズでは移管しない)
    │   └─ パターン A: usage 宣言を書かない、自パッケージ独自シンボルのみ
    │
    └─ はい
        │
        既存パッケージ側の定義を Remove できるか?
        │
        ├─ はい (理想)
        │   └─ パターン B: Remove + 新パッケージで宣言・実装
        │
        └─ いいえ (互換性で残す必要)
            └─ パターン C: 既存側を alias 化、新パッケージ側に実装
```

## チェックリスト

新パッケージのロード後に必ず確認:

```mathematica
(* 1. 既存パッケージの基本機能が動作するか *)
ClaudeCode`LLMGraphDAGCreate[<|
  "nodes" -> <|"n" -> ClaudeCode`iLLMGraphNode["n", "sync", "test", {},
    Function[{job}, <|"v" -> 42|>]]|>,
  "taskDescriptor" -> <|"name" -> "shadow-check",
    "categoryMap" -> <|"test" -> "sync"|>|>,
  "context" -> <||>|>]
(* JobId が返ること、3 秒後に node の result が <|"v" -> 42|> になること *)

(* 2. shadowing が起きていないか
   General::shdw を On にして、新パッケージを (再) ロード *)
On[General::shdw];
Get["NewPkg.wl"]
(* shdw 警告が一切出ないことを確認 *)

(* 3. 自パッケージのシンボルが想定通り存在するか *)
Names["NewPkg`*"]   (* 自パッケージ独自シンボルのみが見える *)

(* 4. 既存パッケージのシンボル数が変化していないか *)
Length[Names["ClaudeCode`*"]]   (* 移管前と同数 *)
```

## トラブルシューティング

### 症状: テストで `n2 result: $Failed` のような不可解な失敗

DAG handler 等が `$Failed` を返す。エラーメッセージは出ない。

**原因候補**:
- 新パッケージが claudecode.wl の公開シンボルを shadow している
- handler 内で参照される関数が空シンボルになっている

**診断**:
```mathematica
On[General::shdw];
Quit[]
(* 全パッケージを再ロード *)
Get["claudecode.wl"]
Get["NewPkg.wl"]
(* shdw 警告が出るかをチェック *)
```

警告が大量に出る場合、新パッケージで `ClaudeXxx::usage = "..."` を書いている箇所を全て確認。既存と同名のシンボルなら宣言を削除。

### 症状: 自己再帰でフリーズ・recursion limit

`ClaudeXxx[args]` を呼ぶとカーネルがフリーズ、または `RecursionLimit::reclim` 警告が大量に出る。

**原因**: パターン B の代わりにパターン A の delegation を書いた。または BeginPackage の依存に既存パッケージを含めた状態で:

```mathematica
ClaudeXxx[args___] := ClaudeCode`ClaudeXxx[args]   (* ❌ 自己再帰 *)
```

**修正**: delegation 関数を削除する (パターン A)、または完全移管する (パターン B)。

### 症状: `?Function` で usage 文字列が消えている

既存パッケージの関数の usage を新パッケージで上書きしてしまった。

```mathematica
(* 新パッケージ内 *)
BeginPackage["NewPkg`", {"ClaudeCode`"}];
ClaudeUpdatePackage::usage = "新しい説明";   (* ClaudeCode`ClaudeUpdatePackage::usage を上書き *)
```

**修正**: 新パッケージ側で `usage` 宣言を削除。本体機能には影響しないが、ドキュメント表示が壊れる。

## 関連ルール・スキル

- `rules/11-core-package-dependency.md` — 基盤パッケージ依存方向制約
- `rules/12-function-name-verification.md` — 関数名検証
- `rules/01-wolfram-general.md` — Wolfram Language 一般

## 参考: 失敗事例の歴史

| 版 | アプローチ | 結果 |
|---|---|---|
| v0.1 | BeginPackage 依存 ClaudeCode + delegation | 自己再帰で claudecode.wl の元定義を破壊 |
| v0.2 | 依存削除 + usage 宣言 + Off[shdw] | 新シンボル作成 → context path 先頭 → shadowing で claudecode.wl 内部関数を破壊 |
| v0.3 | 同名シンボルの usage 宣言を完全削除 | 安全 (パターン A 確立) |

このスキルは v0.3 で確立した知見をもとに作成。
