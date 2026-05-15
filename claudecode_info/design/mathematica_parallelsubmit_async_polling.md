# Mathematicaで`ParallelSubmit`の結果を非同期に取得する方法

## 要点

`ParallelSubmit`で別カーネルに投げた評価の結果を、`WaitAll`や`WaitNext`で取得しようとすると、未完了の評価を待つためメインカーネルやフロントエンドがブロックされたように見えることがあります。

これを避けるには、主に次の二つの方法があります。

1. `ParallelSubmit`が返す`EvaluationObject`の状態をポーリングし、完了済みのものだけ回収する。
2. 長時間ジョブでは`LocalSubmit`を使い、`HandlerFunctions`で結果到着時に処理する。

---

## 1. `ParallelSubmit` + `EvaluationObject["State"]`によるポーリング

`ParallelSubmit`は`EvaluationObject`を返します。このオブジェクトには状態があり、例えば次のように確認できます。

```mathematica
evals = Table[
   ParallelSubmit[
     Pause[RandomInteger[{3, 10}]];
     i^2
   ],
   {i, 8}
];

#["State"] & /@ evals
```

状態には典型的に以下のようなものがあります。

```text
"ready"
"running"
"received"
"finished"
```

重要なのは、`"received"`になっているものだけを`WaitAll`で回収することです。  
未完了の`EvaluationObject`に対して`WaitAll`や`WaitNext`を呼ぶと、そこで待ちが発生します。

---

## 2. 非同期ポーリング用の`SessionSubmit`タスク

以下は、`pending`に入っている`EvaluationObject`群を定期的に調べ、結果が届いたものだけを回収する例です。

```mathematica
ClearAll[startParallelPoller];

startParallelPoller[pendingSymbol_Symbol, resultSymbol_Symbol, interval_: 0.5] :=
  SessionSubmit[
    ScheduledTask[
      Module[{ready, newResults},

        (* subkernel から master に結果が届いている EvaluationObject だけを選ぶ *)
        ready = Select[pendingSymbol, Quiet[#["State"] === "received"] &];

        If[ready =!= {},

          (* "received" になっているものだけ WaitAll するので、通常ここではブロックしない *)
          newResults = WaitAll /@ ready;

          resultSymbol = Join[resultSymbol, newResults];

          pendingSymbol =
            Select[pendingSymbol, ! MemberQ[ready, #] &];

          Print["received: ", newResults];
        ];

        If[pendingSymbol === {},
          TaskRemove[$CurrentTask]
        ];
      ],
      {interval, Infinity}
    ],
    Method -> "Idle"
  ];
```

使用例は次の通りです。

```mathematica
results = {};

pending = Table[
   ParallelSubmit[
     Pause[RandomInteger[{3, 10}]];
     i^2
   ],
   {i, 8}
];

poller = startParallelPoller[pending, results, 0.5];

Dynamic[
  <|
    "Pending" -> Length[pending],
    "Results" -> results
  |>,
  UpdateInterval -> 1
]
```

この方式では、メインカーネルで実行される処理は「状態確認」と「完了済み結果の回収」だけです。  
重い計算そのものはsubkernel側で行われるため、`WaitAll[pending]`を直接呼ぶよりもフロントエンドを固めにくくなります。

---

## 3. 注意点：回収済みの`EvaluationObject`は再利用しない

`EvaluationObject`は、一度結果を回収したら`pending`から外すべきです。

```mathematica
pendingSymbol =
  Select[pendingSymbol, ! MemberQ[ready, #] &];
```

これをしないと、すでに回収済みの評価を再度`WaitAll`や`WaitNext`の対象にしてしまい、管理が複雑になります。

---

## 4. 長時間ジョブでは`LocalSubmit`が自然

`ParallelSubmit`は、並列カーネルプールに細かい計算を投げる用途に向いています。  
一方で、少数の長時間ジョブを「メインカーネルを待たせずに」実行したい場合には、`LocalSubmit`の方が自然です。

`LocalSubmit`は別カーネルで評価を行い、`TaskObject`を返します。  
さらに`HandlerFunctions`を使えば、結果が届いたタイミングで処理できます。

```mathematica
ClearAll[$asyncResults, $asyncStatus];

$asyncResults = <||>;
$asyncStatus = <||>;

task = LocalSubmit[
   Pause[10];
   Total[Range[10^7]],

   HandlerFunctions -> <|
     "TaskStarted" -> Function[e,
       $asyncStatus[e["TaskUUID"]] = "Running"
     ],

     "ResultReceived" -> Function[e,
       $asyncResults[e["TaskUUID"]] = e["EvaluationResult"];
       $asyncStatus[e["TaskUUID"]] = "Finished";
       Print["finished: ", e["EvaluationResult"]];
     ],

     "FailureOccurred" -> Function[e,
       $asyncResults[e["TaskUUID"]] = e["Failure"];
       $asyncStatus[e["TaskUUID"]] = "Failed";
     ]
   |>,

   HandlerFunctionsKeys -> {
     "TaskUUID",
     "EvaluationResult",
     "Failure",
     "TaskStatus"
   }
];
```

状態確認：

```mathematica
task["TaskStatus"]
```

結果確認：

```mathematica
$asyncResults[task["TaskUUID"]]
```

ノートブック上で監視する例：

```mathematica
Dynamic[
  <|
    "Status" -> Lookup[$asyncStatus, task["TaskUUID"], task["TaskStatus"]],
    "Result" -> Lookup[$asyncResults, task["TaskUUID"], Missing["NotAvailable"]]
  |>,
  UpdateInterval -> 1
]
```

---

## 5. `SessionSubmit`をメインカーネル以外で使う案について

`SessionSubmit`は、基本的には「現在のセッション」にタスクを送る関数です。  
したがって、メインカーネルから呼べば、メインカーネル上のpreemptive taskになります。

このため、`SessionSubmit`の中に重い計算本体を入れるのは避けるべきです。  
重い処理は`ParallelSubmit`または`LocalSubmit`に投げ、`SessionSubmit`は軽量な監視・回収処理だけに使うのが安全です。

設計としては次のように分けるのがよいです。

```text
重い計算本体          -> ParallelSubmit または LocalSubmit
メインでの監視・回収  -> SessionSubmit[ScheduledTask[...]]
完全に別プロセス化    -> LocalSubmit + HandlerFunctions
```

---

## 6. ClaudeRuntime / ClaudeOrchestrator 的な設計案

ジョブ管理層を作る場合は、ジョブを次のようなAssociationで管理すると扱いやすくなります。

```mathematica
<|
  "JobID" -> uuid,
  "Backend" -> "ParallelSubmit" | "LocalSubmit",
  "Handle" -> evalObjectOrTaskObject,
  "Status" -> "Submitted" | "Running" | "Received" | "Finished" | "Failed",
  "Result" -> Missing["NotAvailable"],
  "SubmittedTime" -> Now,
  "FinishedTime" -> Missing["NotAvailable"]
|>
```

バックエンドごとの処理は次のように分けます。

```text
ParallelSubmit backend:
  EvaluationObject["State"] を poll
  "received" になったら WaitAll で一度だけ回収

LocalSubmit backend:
  HandlerFunctions の "ResultReceived" で結果を保存
  TaskObject["TaskStatus"] で状態確認
```

この分離により、上位のRuntime/Orchestrator層は、実行バックエンドの違いを意識せずにジョブ状態を扱えます。

---

## 7. 推奨方針

### 細かい並列計算が多数ある場合

`ParallelSubmit`を使い、`EvaluationObject["State"]`をポーリングします。

```text
ParallelSubmit
  -> EvaluationObject
  -> State polling
  -> received のものだけ WaitAll
```

### 少数の長時間ジョブの場合

`LocalSubmit`を使い、`HandlerFunctions`で結果を受け取ります。

```text
LocalSubmit
  -> TaskObject
  -> HandlerFunctions["ResultReceived"]
  -> 結果保存
```

### ノートブックUIをブロックしたくない場合

`WaitAll`や`WaitNext`を直接呼ぶのではなく、次のいずれかにします。

```text
EvaluationObject["State"] による非同期ポーリング
```

または

```text
LocalSubmit + HandlerFunctions
```

---

## 参考リンク

- Wolfram Language: `ParallelSubmit`  
  https://reference.wolfram.com/language/ref/ParallelSubmit.html

- Wolfram Language: `EvaluationObject`  
  https://reference.wolfram.com/language/ref/EvaluationObject.html

- Wolfram Language: `WaitAll`  
  https://reference.wolfram.com/language/ref/WaitAll.html

- Wolfram Language: `WaitNext`  
  https://reference.wolfram.com/language/ref/WaitNext.html

- Wolfram Language: `SessionSubmit`  
  https://reference.wolfram.com/language/ref/SessionSubmit.html

- Wolfram Language: `LocalSubmit`  
  https://reference.wolfram.com/language/ref/LocalSubmit.html

- Wolfram Language: `ScheduledTask`  
  https://reference.wolfram.com/language/ref/ScheduledTask.html

---

## まとめ

`ParallelSubmit`の結果回収でフロントエンドをブロックしたくない場合、`WaitAll`や`WaitNext`を直接使うのではなく、`EvaluationObject["State"]`をポーリングして、`"received"`になったものだけ回収するのが実用的です。

よりイベント駆動に近い構成にしたい場合は、`LocalSubmit`と`HandlerFunctions`を使うのが自然です。

特にClaudeRuntime / ClaudeOrchestratorのようなジョブ管理層では、`ParallelSubmit`バックエンドと`LocalSubmit`バックエンドを分離し、共通のジョブ状態Associationに正規化する設計が適しています。
