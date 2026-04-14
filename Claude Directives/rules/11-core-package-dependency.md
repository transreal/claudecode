---
paths:
  - "**/{NBAccess,claudecode,ClaudeCode}*.{wl,wls,m,nb}"
  - "**/*.{wl,wls,m}"
---

# 11 — 基盤パッケージの依存方向制約

## 基盤パッケージの定義

以下の2パッケージを **基盤パッケージ** と呼ぶ:

- `claudecode.wl` (ClaudeCode`)
- `NBAccess.wl` (NBAccess`)

## 必須ルール: 依存方向は一方向のみ

```
任意のパッケージ ──Needs/使用──→ claudecode.wl / NBAccess.wl
                                    ↑ 一方向のみ許可
```

1. **基盤パッケージは他のパッケージに依存してはならない。**
   - `claudecode.wl` と `NBAccess.wl` は、互いを除き、`Needs`/`Get`/`Import` で他のパッケージを読み込んではならない。
   - 他のパッケージの関数をシンボル参照（`Maildb`xxx` 等）してもならない。
   - 他のパッケージの存在を前提としたコード（`If[Length[Names["Maildb`*"]] > 0, ...]` 等）も禁止。

2. **他のパッケージが基盤パッケージに依存するのは正しい。**
   - `maildb.wl` が `ClaudeCode`ClaudeQuery` を呼ぶ → ✅ 正しい方向
   - `maildb.wl` が `NBAccess`NBGetProviderMaxAccessLevel` を呼ぶ → ✅ 正しい方向
   - `claudecode.wl` が `Maildb`mailAskLLM` を呼ぶ → ❌ **禁止**
   - `NBAccess.wl` が `Maildb`$maildbCache` を参照する → ❌ **禁止**

3. **基盤パッケージのシステムプロンプトに特定パッケージの情報を埋め込んではならない。**
   - `$claudeMathPromptPrefix` に「mailAskLLM を使え」等のパッケージ固有指示を書く → ❌ **禁止**
   - パッケージ固有の LLM 指示は、そのパッケージ自身の `api.md` または `CLAUDE.md` に記載し、`iPackageDocsContext` の自動注入機構を利用する。

## ClaudeUpdatePackage / ClaudeCreatePackage 実行時の動作

パッケージの更新・作成を行う際、以下の判断フローを守る:

1. **更新対象が基盤パッケージでない場合（通常ケース）:**
   - 基盤パッケージの API を自由に使用してコードを生成する。
   - 基盤パッケージ側の変更は不要。

2. **生成中に基盤パッケージの API 変更が必要と判断した場合:**
   - **コード生成を即座に中断する。**
   - 以下を出力して判断を仰ぐ:
     ```
     ⚠ 基盤パッケージ API 変更が必要です。

     対象: claudecode.wl（または NBAccess.wl）
     必要な変更: [具体的な変更内容]
     理由: [なぜ現在の API では不足か]

     基盤パッケージの変更は手動で行う必要があります。
     先に基盤パッケージを更新してから、このタスクを再実行してください。
     ```
   - 基盤パッケージの変更を含むコードを**絶対に**自動生成してはならない。

3. **更新対象が基盤パッケージ自体の場合:**
   - `ClaudeUpdatePackage["claudecode", ...]` や `ClaudeUpdatePackage["NBAccess", ...]` は許可される。
   - ただし、更新内容に他パッケージへの依存追加が含まれる場合は拒否する。

## 理由

基盤パッケージは GitHub で公開されており、あらゆるユーザー環境で動作する必要がある。
特定のパッケージ（maildb 等）の存在を前提とすると、そのパッケージがない環境で基盤パッケージが正常に動作しなくなる。

## 外部パッケージから基盤パッケージの API を利用する際の制約

### Private コンテキスト変数へのアクセス禁止

外部パッケージから `ClaudeCode`Private`$var` や `ClaudeCode`$privateVar` を直接参照してはならない。Private 変数は `BeginPackage`/`EndPackage` の外からは評価されず、シンボル名がそのまま返る。

```mathematica
(* ❌ 禁止: Private 変数を外部パッケージから参照 *)
If[ClaudeCode`$ClaudeExe === "", Print["CLI not found"]]
(* → $ClaudeExe が未評価のまま残り、常に条件不成立 *)

(* ❌ 禁止: Private 内部関数を直接テスト条件に使用 *)
If[ClaudeCode`iSomeCheck[], ...]
```

### 公開 API のみを使用する

外部パッケージが基盤パッケージの機能を利用するには、公開シンボル（`BeginPackage`〜`EndPackage` 間で宣言されたもの）のみを使用する。

```mathematica
(* ✅ 正しい: 公開 API を使用 *)
result = ClaudeCode`ClaudeQuery["prompt"]
status = ClaudeCode`LLMGraphDAGStatus[jobId]
```

### Private 内部関数を外部パッケージから呼ぶ場合: ClearAll 登録が必須

外部パッケージから `ClaudeCode`iMakeBat[...]` のように内部関数を呼ぶ場合、その関数が `BeginPackage` 直後の **`ClearAll` リストに登録されていなければならない**。

#### 背景: Mathematica のシンボル解決

```mathematica
BeginPackage["ClaudeCode`"];
Quiet[ClearAll[iLLMGraphNode, ...]];  (* ← ここで ClaudeCode`iLLMGraphNode を作成 *)
...
Begin["`Private`"];
(* 以下の定義は ClaudeCode`iLLMGraphNode に束縛される (ClearAll 済みのため) *)
iLLMGraphNode[id_, ...] := ...

(* iMakeBat は ClearAll にない → ClaudeCode`Private`iMakeBat に束縛される *)
iMakeBat[promptFile_, ...] := ...
```

`ClearAll` に含まれないシンボルは `ClaudeCode`Private`iMakeBat` として定義される。外部パッケージから `ClaudeCode`iMakeBat[...]` を呼ぶと、これは **別のシンボル**（`ClaudeCode`iMakeBat`、定義なし）であり、呼び出しが未評価のまま返る。

#### 症状

- 新規 Mathematica セッションで外部パッケージから呼び出すと**常に失敗**
- `ClaudeQuery` 等を先に実行すると動く場合がある（コンテキスト解決のキャッシュ副作用）
- エラーメッセージが出ず、未評価の式がそのまま後続に渡り、予測不能な失敗を引き起こす

#### 必須手順: 外部呼び出しが必要な内部関数を追加する場合

1. claudecode.wl 冒頭の `ClearAll[...]` リストにシンボルを追加する
2. 関連する補助関数も同時に追加する（例: `iMakeBat` を追加するなら `iClaudeTempDir`, `iCLIPermissionFlags` 等も）

```mathematica
(* claudecode.wl 冒頭 *)
Quiet[ClearAll[
  ...,
  iMakeBat, iMakeBatStreamJson, iMakeBatVerbose,  (* ← 追加 *)
  iClaudeTempDir, iCLIPermissionFlags,              (* ← 依存する関数も *)
  ...
]];
```

#### 禁止パターン

```mathematica
(* ❌ 禁止: ClearAll 未登録の Private 関数を外部から呼ぶ *)
(* ClearAll に iSomeFunc がない状態で: *)
result = ClaudeCode`iSomeFunc[args]
(* → ClaudeCode`iSomeFunc[args] が未評価のまま返る *)

(* ❌ 禁止: Private 変数の値取得 (ClearAll に入れても評価時の問題は残る) *)
exe = ClaudeCode`$ClaudeExe  (* → 未評価シンボル *)
```

#### 確認方法

外部パッケージに `ClaudeCode`iFunc[...]` を追加したら、**Mathematica を再起動**して直接呼び出しテストを行う。ClaudeQuery 等を先に実行してはならない。

### 公開シンボルの参照: `Global`` ではなくパッケージコンテキストを使う

外部パッケージから基盤パッケージの公開変数を参照する際、`Global`$Var` と書くとシャドウ衝突が発生する。必ず `ClaudeCode`$Var` と明示する。

```mathematica
(* ❌ 禁止: Global` で参照 → シンボルシャドウ衝突 *)
If[StringQ[Global`$ClaudeWorkingDirectory], ...]
(* → $ClaudeWorkingDirectory::shdw: シンボルが複数コンテキストで... *)

(* ✅ 正しい: パッケージコンテキストを明示 *)
If[StringQ[ClaudeCode`$ClaudeWorkingDirectory], ...]
```

### プリフライトチェックのパターン

外部パッケージで基盤パッケージの機能の可用性を確認する場合は、変数参照ではなく外部コマンドや公開 API で行う。

```mathematica
(* ✅ 正しい: OS コマンドで直接確認 *)
whereOut = RunProcess[{"cmd", "/c", "where claude"}, "StandardOutput"];
If[StringContainsQ[whereOut, "Could not find"], Print["CLI not found"]]

(* ✅ 正しい: 公開 API で動作確認 *)
check = Quiet @ Check[ClaudeCode`ClaudeQuery["test", MaxTokens -> 10], $Failed];

(* ❌ 禁止: Private 変数で確認 *)
If[ClaudeCode`$ClaudeExe === "", Print["not found"]]
```
