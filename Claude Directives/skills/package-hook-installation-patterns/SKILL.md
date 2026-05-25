---
name: package-hook-installation-patterns
description: |
  既存パッケージの公開シンボル (e.g. ClaudeAttach, ClaudeAttachments) に対して
  「元の動作を保ちつつ追加処理を挟む」hook を装着するときに踏みやすい罠と
  検証済みの実装パターン集。

  Block / OptionsPattern / Catch / DownValues / Memory registry の各層で
  正しく組まないと、OptionValue::optnf、scheduled task からの不可視、Abort
  時の hook 永続破損、冪等性違反などの不具合が出る。

  SourceVault.wl P1〜P4 hook 統合 (2026-05-18) で実装・テスト完了したテンプレを
  永続記録する。
---

# Package Hook Installation Patterns

別パッケージが提供する公開シンボル `X` に対して「`X[args]` が呼ばれたら追加処理 `f` を実行してから元の `X[args]` の動作に委譲する」hook を装着するときの、安全な実装テンプレ。

## 想定シナリオ

- `ClaudeCode\`ClaudeAttach[path]` のような公開関数を、ユーザのコードを書き換えずに「呼び出されたタイミングで横で別 ingest を走らせる」
- `ClaudeOrchestrator\`A5InjectSourceVaultContext[prompt, role, task]` のように、宿主パッケージが「hook 点」として定義したシンボルへ別パッケージから実装を提供する
- パッケージを enable/disable できるよう、原状回復可能であること

## 罠 5 連発: ナイーブな Block ベース hook が失敗する理由

```mathematica
(* ❌ こうしたくなる *)
SourceVaultClaudeAttachIntegrationEnable[] :=
  Block[{ClaudeCode`ClaudeAttach},   (* X を一時的にクリア *)
    ClaudeCode`ClaudeAttach[path_, opts:OptionsPattern[ClaudeCode`ClaudeAttach]] :=
      Module[{result},
        iMySideEffect[path];          (* 追加処理 *)
        result = ClaudeCode`ClaudeAttach[path, opts];   (* original を呼ぶ *)
        result]
  ];
```

これは少なくとも以下 5 つの罠を踏む:

### 罠 1: `Block[{X}, ...]` は X の **Options も退避**する (罠 #18)

`Block[{X}, ...]` は X の `OwnValues` / `DownValues` / `UpValues` / **`Options`** / `Attributes` / `Messages` を全部退避する。Block 内で original 実装に委譲しようとした瞬間、original 内の `OptionValue[Mode]` が **空 Options を見て** `OptionValue::optnf` を出す。詳細は `skills/wolfram-syntax-pitfalls` の罠 #18。

### 罠 2: `OptionsPattern[X]` は context が解決されないと展開できない

```mathematica
opts:OptionsPattern[ClaudeCode`ClaudeAttach]
```

これは Enable 時点で `ClaudeCode\`ClaudeAttach` の Options を参照するが、その時点で Options が空 (Block 退避中) または `ClaudeCode\`` context がまだロードされていない場合、`OptionsPattern` が `{}` を生成して **どんな keyword でもマッチしない** hook ができる。

### 罠 3: `Block` ブロックの中では DownValues を _上書き_ できない

```mathematica
Block[{X}, X[args__] := ...]
```

これは Block の局所スコープ内でだけ X に DownValue を付ける。Block を抜けると消える。

→ Block を使うこと自体が誤り。enable 時に DownValues を **永続的に置き換え**、disable 時に **元の DownValues に戻す** のが正しい姿。

### 罠 4: hook 内 `Catch/Throw/Return` は罠 #15-#16 を再発させる

Map + Function + Return / Throw を hook 実装内で使うと、`Quiet@Check` と組み合わさって false-`$Failed` が出る。詳細は `skills/wolfram-syntax-pitfalls` 罠 #15 / #16。

### 罠 5: Abort 時に hook が永久破損する

hook 内で何らかの処理が中断 (`Abort[]`) されると、DownValues が hook 状態のまま残り、次回以降ユーザの `X[args]` がすべて hook 経由で呼ばれる。Enable/Disable のサイクルが壊れる。

## 推奨テンプレ: 「DownValues swap helper + CheckAbort」パターン

5 つの罠を全部回避する構造:

```mathematica
Begin["SourceVault`Private`"];

(* ─────────────────────────────────────────────────────────
   State Variables (パッケージロード時 1 回だけ初期化)
   ───────────────────────────────────────────────────────── *)
If[!ValueQ[$IntegrationClaudeAttachEnabled],
  $IntegrationClaudeAttachEnabled = False];
If[!ValueQ[$IntegrationClaudeAttachOriginalDV],
  $IntegrationClaudeAttachOriginalDV = Null];

(* ─────────────────────────────────────────────────────────
   Original を一時呼び出すヘルパ。Block を使わない。
   ───────────────────────────────────────────────────────── *)
iClaudeAttachOriginalCall[args___] :=
  Module[{savedDV = DownValues[ClaudeCode`ClaudeAttach], result},
    (* 元の DownValues に一時的に戻す *)
    DownValues[ClaudeCode`ClaudeAttach] = $IntegrationClaudeAttachOriginalDV;
    
    (* CheckAbort: Abort 時にも hook DownValues を復元 *)
    result = CheckAbort[
      ClaudeCode`ClaudeAttach[args],
      (DownValues[ClaudeCode`ClaudeAttach] = savedDV; Abort[])];
    
    (* 正常終了時も hook DownValues に戻す *)
    DownValues[ClaudeCode`ClaudeAttach] = savedDV;
    result
  ];

(* ─────────────────────────────────────────────────────────
   side-channel 追加処理 (hook 本体)
   ───────────────────────────────────────────────────────── *)
iClaudeAttachSideChannelIngest[path_String] :=
  Module[{...},
    (* 追加処理: SourceVault に ingest して履歴を保存 etc *)
    ...
  ];

End[]; (* SourceVault`Private` *)

(* ─────────────────────────────────────────────────────────
   Enable / Disable (Public API)
   ───────────────────────────────────────────────────────── *)
SourceVaultClaudeAttachIntegrationEnable[] :=
  Module[{},
    (* 罠 5 対策: 冪等性 *)
    If[TrueQ[$IntegrationClaudeAttachEnabled],
      Print["[SourceVault] ClaudeAttach hook \:306f\:65e2\:306b\:6709\:52b9\:5316\:6e08\:307f (noop)\:3002"];
      Return[<|"Status" -> "AlreadyEnabled"|>]];
    
    (* 依存チェック *)
    If[Length[Names["ClaudeCode`ClaudeAttach"]] === 0,
      Return[<|"Status" -> "MissingDependency",
               "Detail" -> "ClaudeCode`ClaudeAttach not loaded"|>]];
    
    (* 元の DownValues を保存 *)
    $IntegrationClaudeAttachOriginalDV = DownValues[ClaudeCode`ClaudeAttach];
    
    (* hook DownValues を全置換。OptionsPattern を使わず opts___ で受ける *)
    DownValues[ClaudeCode`ClaudeAttach] = {
      HoldPattern[ClaudeCode`ClaudeAttach[path_String, opts___]] :>
        Module[{result},
          (* 追加処理を先に実行 *)
          SourceVault`Private`iClaudeAttachSideChannelIngest[path];
          (* original DownValues 経由で本来の動作 *)
          result = SourceVault`Private`iClaudeAttachOriginalCall[path, opts];
          result]
    };
    
    $IntegrationClaudeAttachEnabled = True;
    <|"Status" -> "Enabled"|>
  ];

SourceVaultClaudeAttachIntegrationDisable[] :=
  Module[{},
    If[!TrueQ[$IntegrationClaudeAttachEnabled],
      Return[<|"Status" -> "AlreadyDisabled"|>]];
    
    DownValues[ClaudeCode`ClaudeAttach] = $IntegrationClaudeAttachOriginalDV;
    $IntegrationClaudeAttachOriginalDV = Null;
    $IntegrationClaudeAttachEnabled = False;
    <|"Status" -> "Disabled"|>
  ];
```

### このテンプレが守っていること

| 罠 | 対策 |
|---|---|
| #18 (Block + Options) | Block を使わず、DownValues を手動 swap |
| OptionsPattern context 問題 | `opts___` で受け、original 側の OptionsPattern に丸投げ |
| Block の局所性問題 | Enable で **永続的に** DownValues 置換、Disable で復元 |
| Abort 時の永久破損 | `CheckAbort` で hook DownValues 復元 |
| 冪等性違反 | Enable/Disable 双方で「既に enabled/disabled」を return |

## scheduled task コンテキスト対応: Memory Registry Fallback

hook が「追加処理」中で **TaggingRule / SelectionMove / EvaluationNotebook[]** など Front End API を使う場合、その処理は `LLMGraphDAGCreate` の worker 経由でも呼ばれる可能性がある。

→ rules/95-scheduled-task-safety §F の罠 #19 に該当。

対策: side-channel 処理で記録した情報を **Private 変数のメモリレジストリにも並行で書く**。worker 経路の auto-detect は notebook → memory の 2 段階 fallback で読む。

```mathematica
(* state 初期化 *)
If[!ValueQ[$LastAttachedRefs], $LastAttachedRefs = {}];

iClaudeAttachSideChannelIngest[path_String] :=
  Module[{snapshotRef, nb},
    snapshotRef = ...;   (* ingest 結果 *)
    
    (* (A) Notebook TaggingRule (Front End 経路で見える) *)
    nb = EvaluationNotebook[];
    NBAccess`NBSetTaggingRule[nb, {...}, ...];
    
    (* (B) Memory Registry (scheduled task 経路で見える) *)
    $LastAttachedRefs = DeleteDuplicatesBy[
      Append[$LastAttachedRefs, snapshotRef],
      Lookup[#, "SnapshotId", ""] &];
  ];

(* 双方を fallback で読む auto-detect *)
iAutoDetect[] :=
  Module[{nb, fromNB, fromMemory},
    nb = Quiet[EvaluationNotebook[]];
    fromNB = If[nb =!= Null && nb =!= $Failed && Head[nb] =!= EvaluationNotebook,
      Quiet[NBAccess`NBGetTaggingRule[nb, {...}]], {}];
    If[!ListQ[fromNB], fromNB = {}];
    
    fromMemory = If[ListQ[$LastAttachedRefs], $LastAttachedRefs, {}];
    
    DeleteDuplicatesBy[Join[fromNB, fromMemory],
      Lookup[#, "SnapshotId", ""] &]
  ];
```

詳細は `rules/95-scheduled-task-safety.md` §F。

## 設計上の指針

### Hook 対象シンボルの選び方

- **公開シンボル**: 別パッケージの `Public` API ならどれにも hook を装着できる。ただし、その API の signature や Options が変わると hook を直す必要がある。
- **Hook 点**: 宿主パッケージが意図的に「ここに hook を入れて良い」と明示したシンボル (例: `ClaudeOrchestrator\`A5InjectSourceVaultContext`)。これが理想。インタフェース契約がはっきりしているので壊れにくい。

### 1 つの hook が複数 hook 点を持つときの依存管理

SourceVault.wl P1〜P4 のような大型 hook は複数の独立した hook 点 (`ClaudeAttach`, `ClaudeAttachments`, `A5InjectSourceVaultContext`, `A6ExtractSourceVaultRefs`) を持つ。各 hook 点ごとに:

- 独立した `$Integration*Enabled` フラグ
- 独立した `$Integration*OriginalDV` (該当する場合)
- 独立した Enable/Disable API

を分けて持つこと。1 つの hook 点で失敗した時に他に巻き込まれないため。

### Status / Inspect API

ユーザ向けに、現在 hook が有効かどうかを答える `Status` API を必ず提供する:

```mathematica
SourceVaultClaudeAttachIntegrationStatus[] :=
  <|"Enabled" -> TrueQ[$IntegrationClaudeAttachEnabled],
    "HookTarget" -> "ClaudeCode`ClaudeAttach",
    "OriginalDVCount" -> If[ListQ[$IntegrationClaudeAttachOriginalDV],
      Length[$IntegrationClaudeAttachOriginalDV], 0]|>;
```

これでユーザは `Status[]["Enabled"]` を see してから例を実行できる。

## 適用タイミング

- 別パッケージの公開関数に追加処理を挟みたくなったとき: このスキルのテンプレで実装する
- `OptionValue::optnf` が hook 内で出るようになったとき: Block を使っていないか確認 (罠 #18)
- hook が enable されているはずなのに動かない時: scheduled task コンテキストで呼ばれていないか確認 (rules/95 §F)
- Abort 後 hook が壊れたとき: `CheckAbort` の DownValues 復元が入っているか確認

## 関連スキル / rules

- `skills/wolfram-syntax-pitfalls` 罠 #18 (Block + Options)
- `rules/95-scheduled-task-safety.md` §F (scheduled task で `EvaluationNotebook[]` 不可視)
- `skills/llm-prompt-template-override` (hook 経由で LLM prompt を override する時の補助)
