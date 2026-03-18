---
paths:
  - "**/*.{wl,wls,m}"
---

# 85 — パッケージ更新マージ安全性制約

## 対象

`ClaudeUpdatePackage`、`ClaudeFixSeparation`、およびパッケージソースコードを LLM レスポンスで部分的に更新するすべての処理。

## 背景

LLM にパッケージソースの一部（または全体）を渡して修正を指示すると、LLM は指示された関数のみを返すことが多い。このレスポンスをそのまま新コードとして採用すると、未返却の関数がすべて消失しパッケージが破損する。

## 必須ルール

### 1. 常にマージを試みる

LLM レスポンスがパッケージの一部であろうと全体であろうと、**レスポンスを無条件に全コードとして採用してはならない**。常に以下のマージ手順を実行する:

1. `iExtractFunctions` でレスポンスから関数ブロックを抽出する
2. 元コード内の対応する関数ブロックのみを差し替える
3. レスポンスに含まれない関数はすべて元コードのまま保持する

### 2. 全ファイル返却の判定

LLM が完全なファイルを返した場合にのみ、そのまま採用してよい。判定条件:

- `BeginPackage[` を含む **かつ** `EndPackage[` を含む
- サイズが元コードの 70% 以上

上記をすべて満たさない場合は「部分レスポンス」として扱い、マージを実行する。

### 3. プロンプトの明示性

LLM に送るプロンプトでは、修正した関数のみを返すよう明示的に指示する:

- ✅ 「Return ONLY the modified function definitions (not the entire file). All unchanged functions will be preserved automatically by the merge system.」
- ❌ 「Return ONLY the modified functions.」（マージシステムの存在を伝えないと、LLM が全体を返そうとして中途半端になるリスクがある）

### 4. 新規関数の安全な挿入

レスポンスに元コードに存在しない新規関数が含まれる場合:

- `End[]` / `EndPackage[]` の直前に挿入する
- 挿入した関数名をユーザーに通知する

### 5. マージ失敗の検知と報告

マージが 0 件の場合（レスポンスの関数が元コードのどの関数にも対応しない場合）:

- 警告メッセージを表示する
- レスポンスをそのまま全コードとして採用しない
- response.txt は保存済みなので、ユーザーが手動で確認・適用できる

### 6. 安全検証は最終防衛線

マージ後の newCode に対して以下の検証を行う（既存の安全検証）:

- サイズが元コードの 50% 未満なら拒否
- 関数数が元コードの 50% 未満なら拒否
- `BeginPackage[]` / `EndPackage[]` の欠落を検出

これらはマージロジックが正常に動作している場合は発火しない。発火した場合はマージロジック自体のバグを示唆する。

## 禁止パターン

```mathematica
(* ❌ 禁止: LLM レスポンスを無条件に全コードとして採用 *)
newCode = If[Length[targets] === 0,
  newFuncs,         (* ← 全関数消失のリスク *)
  mergeLogic[...]];

(* ❌ 禁止: レスポンスサイズだけで全ファイル判定 *)
If[StringLength[newFuncs] > 1000, newCode = newFuncs]
```

## 正しいパターン

```mathematica
(* ✅ 常にマージを試みる *)
newCode = Module[{code = origCode, updBlks},
  updBlks = iExtractFunctions[newFuncs];
  Scan[Function[fn,
    Module[{oldDef, newDef},
      oldDef = Lookup[origBlocks, fn, ""];
      newDef = Lookup[updBlks, fn, ""];
      If[oldDef =!= "" && newDef =!= "",
        code = StringReplace[code, oldDef -> newDef, 1]]
    ]
  ], Keys[updBlks]];
  code
];
```

## `ClaudeFixSeparation` への適用

ファイルパスを直接修正する `ClaudeFixSeparation` のパスでも同じ原則を適用する。「Output the COMPLETE corrected source file」と指示しても LLM が部分的にしか返さないことがあるため、全ファイル判定 + マージフォールバックを必ず組み込む。
