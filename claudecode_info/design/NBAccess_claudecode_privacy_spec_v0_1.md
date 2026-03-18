# NBAccess.wl / claudecode.wl 向け プライバシー・アクセス制御仕様案 v0.1

あくまでもChatGPTが生成した参考資料ということで。

## 1. 目的

本仕様の目的は、Mathematica ノートブック上で扱う値・関数・ノートブック資源に対して、以下を実現することである。

1. **うっかりミス由来の漏えい**を検出する
2. **明示的に許可された要約出力**だけを公開する
3. **秘密関数の反復実行による推定漏えい**をある程度抑止する
4. `claudecode.wl` が **NBAccess の API 経由でのみ** 機密資源へ触れるようにする

本仕様は、**悪意ある完全回避**ではなく、**通常実装・通常利用での誤用防止**を主対象とする。`ToExpression` や文字列合成によるシンボル名生成など、Mathematica の動的機能を使った敵対的回避は、v0.1 では完全には防がない。

---

## 2. 設計原則

### 2.1 二層モデル

各データは、少なくとも次の 2 つを持つ。

- **BasePrivacyScore** : `[0,1]` の実数  
  データ単体の内在的な秘匿度・漏えいリスクのヒューリスティック値
- **PolicyLabel** : 半順序ラベル  
  誰が読めるか、どのモジュールがどう使えるかを表す、**authoritative** なポリシー値

ここで `[0,1]` スコアは**補助的**であり、最終的な access 可否は **PolicyLabel + AccessRequest + Environment** で決める。

### 2.2 関数は「値」と「オラクル」を分ける

関数には少なくとも 2 種類の秘匿性がある。

- **Definition confidentiality**  
  関数本体・アルゴリズムを読めるか
- **Execution confidentiality**  
  関数を実行できるか

秘密関数であっても、出力の一部だけは公開可能なことがある。ただし、その場合でも**反復実行**により内部規則が推定されうるため、`Apply` は unrestricted ではなく、**GuardedApply** を通す。

### 2.3 暗黙依存も追跡する

`if secret then public=1` のようなケースは、**制御依存**として秘密依存に数える。

---

## 3. 用語

### 3.1 Principal

アクセス主体。以下を含む。

- 人間ユーザ
- モジュール
- ロール
- グループ
- システム主体

### 3.2 ActsFor

`p actsfor q` は、principal `p` が `q` の権限を代行できることを表す。グループやロールはこの関係で表現する。

### 3.3 ReaderPolicy

`owner -> readers` 形式の reader policy。owner が、その情報を誰に読ませてよいかを指定する。

### 3.4 AccessRequest

アクセス要求。subject, module, operation, sink, environment, accessLevel などを含む。

---

## 4. データモデル

内部表現は次を基本とする。

```wl
SecuredValue[heldExpr_, meta_Association]
```

`meta` の必須キー:

```wl
<|
  "BasePrivacyScore" -> 0.0, (* 0..1 *)
  "PolicyLabel" -> label,
  "ContainerLabel" -> labelOrNone,
  "ContainerRisk" -> 0.0,
  "Tags" -> {"grade", "pii", ...},
  "Provenance" -> {...},
  "Dependencies" -> <|
      "Explicit" -> {...},
      "CapturedGlobals" -> {...},
      "Control" -> {...}
  |>,
  "CreatedBy" -> principal,
  "CreatedAt" -> date,
  "Kind" -> "Value" | "Function" | "NotebookCell" | "Credential" | "History",
  "DefinitionLabel" -> labelOrNone,
  "ExecPolicy" -> execPolicyOrNone,
  "ReleasePolicy" -> releasePolicyOrNone,
  "AuditGroup" -> auditKeyOrNone
|>
```

`heldExpr` は `HoldComplete` で保持してよい。

---

## 5. ラベル仕様

### 5.1 Label 形式

v0.1 では confidentiality 中心にし、次の簡易 DLM 風表現を採用する。

```wl
Label[<|
  "ReaderPolicies" -> <|
     owner1 -> {readerA, readerB, ...},
     owner2 -> {readerC, ...}
  |>,
  "Categories" -> {"Grades", "MethodIP", ...}
|>]
```

### 5.2 読取り判定

`CanReadPrincipalQ[p_, label_]` は、各 reader policy について

- `p actsfor owner`
- または `p actsfor oneOf(readers)`

が成り立つかで判定する。

### 5.3 ラベル合成

複数入力に依存する出力のラベルは、基本的に **Join** で求める。

```wl
LabelJoin[l1_, l2_]
```

意味的には「両方の制約を同時に満たす」方向、つまり**より restrictive** 側へ寄せる。

### 5.4 EffectiveLabel

実際の判定にはデータ単体のラベルではなく、次を使う。

```wl
EffectiveLabel[obj_, req_] :=
  LabelJoin[
    obj["PolicyLabel"],
    obj["ContainerLabel"],
    SinkLabel[req["Sink"]],
    EnvironmentLabel[req["Environment"]]
  ]
```

---

## 6. リスクスコア仕様

### 6.1 BasePrivacyScore

`[0,1]` の値で、**データ単体**の秘匿度を表す。

目安:

- `0.0` 公開前提
- `0.2` 公開してよい要約
- `0.5` 限定共有
- `0.8` 個人関連・業務機密
- `1.0` 厳格秘匿

### 6.2 EffectiveRiskScore

実アクセス時のスコアは次で計算する。

```wl
EffectiveRiskScore[obj_, req_] :=
  Max[
    obj["BasePrivacyScore"],
    obj["ContainerRisk"],
    SinkRisk[req["Sink"]],
    EnvironmentRisk[req["Environment"]],
    AuditRisk[obj, req]
  ]
```

v0.1 では `Max` でよい。将来は weighted sum や learned model に差し替え可能。

### 6.3 AccessLevel

`AccessRequest` は数値 `AccessLevel ∈ [0,1]` を持つ。

```wl
ScoreGateQ[obj_, req_] := EffectiveRiskScore[obj, req] <= req["AccessLevel"]
```

ただし **ScoreGate は最終境界ではない**。最終許可は **PolicyGate AND ScoreGate** とする。

---

## 7. アクセス要求仕様

```wl
AccessRequest[<|
  "Subject" -> principal,
  "Module" -> modulePrincipal,
  "Operation" -> "ReadValue" | "ReadDefinition" | "Execute" |
                 "WriteCell" | "WriteLog" | "SendExternal" | "Declassify",
  "Sink" -> "NotebookView" | "NotebookCell" | "KernelValue" |
            "SessionDB" | "ExternalAPI" | "LogFile",
  "Environment" -> <|
      "NotebookID" -> ...,
      "SessionID" -> ...,
      "Interactive" -> True|False,
      "Networked" -> True|False,
      "Purpose" -> "...",
      "Time" -> ...
  |>,
  "AccessLevel" -> 0.0 (* 0..1 *)
|>]
```

---

## 8. 判定アルゴリズム

### 8.1 基本判定

```wl
AuthorizeQ[obj_, req_] := Module[
  {
    label = EffectiveLabel[obj, req],
    policyOK,
    scoreOK
  },
  policyOK =
    CanReadPrincipalQ[req["Subject"], label] &&
    ModuleAllowedQ[req["Module"], req["Operation"], obj, req] &&
    EnvironmentAllowedQ[req["Environment"], obj, req];

  scoreOK = ScoreGateQ[obj, req];

  Which[
    !policyOK, Deny["PolicyViolation"],
    policyOK && scoreOK, Permit[],
    policyOK && !scoreOK, ScreenOrDeny[obj, req]
  ]
]
```

### 8.2 UCON 風の ongoing 判定

`Operation == "Execute"` の場合は、開始前だけでなく**実行中・実行後**にも再判定する。

```wl
AuthorizeExecuteQ[obj_, req_] :=
  PreCheck && OngoingCheck && PostUpdate
```

---

## 9. 依存追跡仕様

### 9.1 依存の種類

`Dependencies` は 3 種類に分ける。

- `"Explicit"` : RHS に明示参照されたシンボル
- `"CapturedGlobals"` : 関数閉包が捕捉した大域変数
- `"Control"` : `If`, `Which`, `Condition`, `Piecewise` などの分岐条件依存

### 9.2 既定規則

新しい値 `y` を生成したとき、

```wl
OutputLabel[y] = Join @@ InputLabels
OutputScore[y] = Max @@ InputScores
```

とする。

### 9.3 pc label 相当

分岐条件に秘密値が使われた場合、その分岐下で生成される値・定義には `"Control"` 依存を追加する。

---

## 10. 関数オブジェクト仕様

関数は次の 3 つの秘匿情報を持つ。

```wl
<|
  "DefinitionLabel" -> label,
  "ExecPolicy" -> <| ... |>,
  "ReleasePolicy" -> releasePolicyOrNone
|>
```

### 10.1 DefinitionLabel

関数本体を読む権限に必要なラベル。関数定義時の explicit / captured / control dependencies から計算する。

### 10.2 ExecPolicy

関数を実行できる主体・モジュール・条件・予算。

```wl
<|
  "AllowedPrincipals" -> {...},
  "AllowedModules" -> {...},
  "AllowedSinks" -> {...},
  "MaxCallsPerSession" -> 20,
  "MaxDistinctInputsPerSession" -> 10,
  "RateLimitSeconds" -> 1.0,
  "DetectBoundarySearch" -> True,
  "DetectEnumeration" -> True,
  "BudgetCost" -> 1.0
|>
```

### 10.3 ReleasePolicy

実行結果のどこまで公開してよいか。

```wl
<|
  "Kind" -> "None" | "PassFail" | "Mean" | "Count" | "Custom",
  "PublicResultQ" -> True|False,
  "OutputScoreRule" -> f,
  "OutputLabelRule" -> g,
  "RedactIntermediates" -> True
|>
```

---

## 11. Declassify 仕様

**通常関数はラベルを下げてはいけない。** ラベル低下は `Declassify` または `ReleasePolicy` 付き `GuardedApply` のみ許可する。

```wl
Declassify[obj_, req_, releaseSpec_]
```

規則:

1. `req["Operation"] == "Declassify"` であること
2. `req["Module"]` が declassification 権限を持つこと
3. `releaseSpec` が登録済みであること
4. 監査ログを必ず残すこと

---

## 12. GuardedApply 仕様

秘密関数の実行は必ず `GuardedApply` を通す。

```wl
GuardedApply[req_, f_SecuredValue, args___]
```

処理手順:

```wl
GuardedApply[req_, f_, args___] := Module[
  {
    pre, rawResult, resMeta, released, post
  },

  pre = AuthorizeExecutePre[f, req, {args}];
  If[DeniedQ[pre], Return[pre]];

  UpdateAuditState["Pre", f, req, {args}];

  rawResult = InternalEvaluateFunction[f, args];

  resMeta = PropagateSecurity[f, {args}, rawResult, req];

  released =
    If[HasReleasePolicyQ[f],
      ApplyReleasePolicy[f, rawResult, resMeta, req],
      SecuredValue[HoldComplete[rawResult], resMeta]
    ];

  UpdateAuditState["Post", f, req, {args}, released];

  AuthorizeSink[released, req]
]
```

### 重要規則

- `Apply`, `Map`, `Through` などで秘密関数を直接実行してはならない
- `claudecode.wl` は `GuardedApply` のみを呼べる
- 生の `Function` 本体は claudecode 側へ返してはならない
- `SendExternal` sink では中間値を常に赤字扱いにする

---

## 13. 監査仕様

### 13.1 AuditState

`AuditState` は `{AuditGroup, Subject, Module, Session}` ごとに保持する。

```wl
<|
  "CallCount" -> 0,
  "DistinctInputHashes" -> {},
  "RecentCalls" -> {...},
  "SpentBudget" -> 0.0,
  "SuspicionScore" -> 0.0
|>
```

### 13.2 既定ルール

v0.1 では以下を実装する。

1. **総呼出し回数制限**
2. **distinct input 数制限**
3. **短時間連続呼出し制限**
4. **数値境界探索の検出**
   - 単調入力に対する連続 narrowing
5. **小領域全列挙の検出**
6. **同一 AuditGroup を跨いだモジュール共有**
   - `ClaudeCode`, `ClaudeEval` などが状態を共有

### 13.3 超過時の動作

超過時は `ExecPolicy["OnExhaust"]` に従う。

- `"Deny"`
- `"CoarsenOutput"`
- `"RequireHumanApproval"`
- `"Delay"`

v0.1 既定は `"Deny"`。

---

## 14. ノートブック資源の扱い

以下の資源は **NBAccess 専管** とする。

- Notebook cell 参照
- Session history
- TaggingRules 内の機密メタデータ
- SystemCredential
- 外部 API キー
- AuditState 永続化
- Release / declassify ログ

`claudecode.wl` はこれらへ直接アクセスしてはならず、必ず NBAccess の公開 API を使う。

---

## 15. 公開 API 仕様案

### 15.1 principal / policy

```wl
NBRegisterPrincipal[name_String, opts___]
NBGrantActsFor[p_, q_]
NBMakeLabel[readerPolicies_Association, opts___]
NBCanReadPrincipalQ[p_, label_]
NBJoinLabel[l1_, l2_]
```

### 15.2 secured value

```wl
Confidential[expr_, meta_:<||>]
Public[expr_]
NBGetMeta[obj_]
NBSetMeta[obj_, patch_Association]
NBEffectiveLabel[obj_, req_]
NBEffectiveRiskScore[obj_, req_]
```

### 15.3 function security

```wl
NBRegisterFunctionSecurity[sym_Symbol, spec_Association]
NBFunctionDefinitionLabel[f_]
NBFunctionExecPolicy[f_]
NBFunctionReleasePolicy[f_]
GuardedApply[req_, f_, args___]
Declassify[obj_, req_, releaseSpec_]
```

### 15.4 access decision

```wl
NBMakeAccessRequest[assoc_Association]
NBAuthorize[obj_, req_]
NBScreen[obj_, req_]
```

### 15.5 audit

```wl
NBGetAuditState[key_]
NBUpdateAuditState[phase_, f_, req_, args_, result_:None]
NBResetAuditState[key_]
```

---

## 16. 既定の伝播規則

### 16.1 値代入

```wl
x = rhs
```

- `x` の label は `rhs` 依存の join
- `x` の score は `rhs` 依存 score の max

### 16.2 関数定義

```wl
f = Function[args, body]
```

- `DefinitionLabel[f]` は `body` の explicit + captured + control 依存から作る
- `ExecPolicy[f]` が無ければ既定 deny
- `ReleasePolicy[f]` が無ければ出力は通常の IFC 伝播

### 16.3 関数適用

```wl
GuardedApply[req, f, args]
```

- 実行前に `ExecPolicy` 判定
- 結果 label は `DefinitionLabel[f]` と `args` の join を基準
- `ReleasePolicy` があればその後で declassify 可能

---

## 17. screening 仕様

`ScreenOrDeny` は次の順で試す。

1. `ReleasePolicy` がなければ deny
2. `ReleasePolicy` があれば coarse result 生成
3. coarse result について再度 `AuthorizeQ`
4. 通れば coarse result を返す
5. 通らなければ deny

例:

- 秘密配列 → 平均だけ返す
- 秘密関数 → `"Pass"` / `"Fail"` だけ返す
- 秘密関数の中間スコア・閾値・説明文は返さない

---

## 18. 具体例: `scoreingMethod`

```wl
scores =
  Confidential[
    rawScores,
    <|
      "BasePrivacyScore" -> 0.95,
      "PolicyLabel" -> NBMakeLabel[<|"Registrar" -> {"Registrar","Teacher"}|>],
      "Kind" -> "Value",
      "Tags" -> {"Grades", "PII"}
    |>
  ];

scoreingMethod =
  Confidential[
    Function[n, If[n < 60, "Fail", "Pass"]],
    <|
      "BasePrivacyScore" -> 0.90,
      "PolicyLabel" -> NBMakeLabel[<|"Teacher" -> {"Teacher"}|>],
      "Kind" -> "Function",
      "DefinitionLabel" -> NBMakeLabel[<|"Teacher" -> {"Teacher"}|>],
      "ExecPolicy" -> <|
        "AllowedPrincipals" -> {"Teacher"},
        "AllowedModules" -> {"NBAccess"},
        "AllowedSinks" -> {"KernelValue", "NotebookView"},
        "MaxCallsPerSession" -> 20,
        "MaxDistinctInputsPerSession" -> 8,
        "DetectBoundarySearch" -> True,
        "DetectEnumeration" -> True,
        "BudgetCost" -> 1.0,
        "OnExhaust" -> "Deny"
      |>,
      "ReleasePolicy" -> <|
        "Kind" -> "PassFail",
        "PublicResultQ" -> True,
        "OutputScoreRule" -> (0.10 &),
        "OutputLabelRule" -> (NBMakeLabel[<|"Public" -> {"Public"}|>] &),
        "RedactIntermediates" -> True
      |>,
      "AuditGroup" -> "scoreingMethod:default"
    |>
  ];
```

実行は必ず:

```wl
req = NBMakeAccessRequest[<|
  "Subject" -> "Teacher",
  "Module" -> "NBAccess",
  "Operation" -> "Execute",
  "Sink" -> "NotebookView",
  "Environment" -> <|"SessionID" -> "abc", "Interactive" -> True|>,
  "AccessLevel" -> 0.30
|>];

GuardedApply[req, scoreingMethod, 55]
```

このとき:

- `scoreingMethod` 本体の表示は deny
- 実行自体は ExecPolicy 次第
- 結果 `"Fail"` は ReleasePolicy により public 扱い可
- ただし反復探索で budget 超過なら deny

---

## 19. v0.1 の非目標

次は v0.1 では完全には扱わない。

- `ToExpression` / 文字列合成ベースの敵対的回避
- Mathematica の全評価器・全構文への完全静的解析
- 任意プログラムの完全な非干渉性証明
- 厳密な情報量漏えい計算

---

## 20. 推奨実装順

1. **SecuredValue + Label + ActsFor**
2. **AuthorizeQ / AccessRequest**
3. **依存追跡: Explicit + CapturedGlobals + Control**
4. **GuardedApply**
5. **Declassify / ReleasePolicy**
6. **AuditState**
7. **Notebook / Session / Credential を NBAccess 専管化**

---

## 参考理論・参考資料

この仕様案は、主に次の考え方を土台としている。

- Jif / Decentralized Label Model: reader policy, acts-for, lattice 的なラベル合成, pc label, declassification
- NIST ABAC: subject / object / operation / environment に基づく access decision
- UCONABC: 継続的 authorization と mutable attributes
- Statistical DB query auditing / inference control: 反復問い合わせによる秘密推定への対策

参考 URL:

- Jif Reference Manual  
  https://www.cs.cornell.edu/jif/doc/jif-3.3.0/manual.html
- Jif DLM  
  https://www.cs.cornell.edu/jif/doc/jif-3.3.0/dlm.html
- Jif Programming / pc label / declassify  
  https://www.cs.cornell.edu/jif/doc/jif-2.0.0/jif_programming.html
- NIST SP 800-162 Guide to Attribute Based Access Control (ABAC)  
  https://nvlpubs.nist.gov/nistpubs/specialpublications/nist.sp.800-162.pdf
- The UCONABC Usage Control Model  
  https://profsandhu.com/journals/tissec/ucon-abc.pdf
- Auditing User Queries in Dynamic Statistical Databases  
  https://dsns.cs.nycu.edu.tw/ssp/paper/34.Auditing%20User%20Queries%20in%20Dynamic%20Statistical%20Databases.pdf

