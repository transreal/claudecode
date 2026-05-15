---
paths:
  - "**/*.{wl,wls,m,nb}"
---

# ScheduledTask・非同期処理の安全制約

## 概要

claudecode は ScheduledTask ベースの非同期処理基盤を提供する。
パッケージ開発時には以下の **5 つの制約・パターン** を厳守すること:

- **A. ScheduledTask 内からの禁止操作**: ClaudeEval / ContinueEval のチェーン内から ClaudeQuery 等を呼ばない
- **B. 独自 ScheduledTask 作成の禁止**: UI ポーリング用の ScheduledTask を自前で作らず claudecode の共有基盤に委ねる
- **C. LLMGraph DAG フレームワーク**: 複数 LLM 呼び出しは `LLMGraphDAGCreate` で組み立てる
- **D. deferred sync runState 仕様**: async ノード handler の戻り値仕様。`RunProcess[..., "Process"]` は無効、`StartProcess` を使う。sync API と async API を混在させない。
- **E. ローカル LLM の async 化**: LMStudio 等は `iStartFallbackAsync` + 「ダミー proc」パターンで deferred sync に変換する

新規パッケージで非同期 LLM 処理を書く前に、最低限 **節 D, E** に目を通すこと。
RunProcess の罠や Pause ループのフロントエンドブロックなど、
動作実証なしには気づきにくい落とし穴がまとめてある。

---

## A. ScheduledTask 内からの禁止操作

ClaudeEval / ContinueEval は内部で ScheduledTask チェーンを使用する。
パッケージ関数がこのチェーン内から呼ばれる可能性がある場合、以下を厳守すること。

### 禁止事項

#### 1. ClaudeQuery の呼び出し

```mathematica
(* ❌ ClaudeEval が生成したコード内で ClaudeQuery を呼ぶ → デッドロック *)
mailAskLLM[...] の内部で ClaudeQuery[prompt, Fallback -> True]

(* ❌ 同一の自動評価ブロック内で ClaudeQuery を2回呼ぶ → 確実にフリーズ *)
result1 = ClaudeQuery[prompt1];
result2 = ClaudeQuery[prompt2];
```

**原因**: ClaudeQuery は `StartProcess` で Claude CLI プロセスを起動し、
共有ポーリングタスク (`$iSharedPollingTask`) 経由で結果を監視する。
ClaudeEval の ScheduledTask 内から呼ぶと、ネストした非同期処理が作られ
カーネルの評価キューがブロックされる。

#### 2. SessionSubmit + SelectionEvaluate

```mathematica
(* ❌ ScheduledTask 内で SessionSubmit → ClaudeEval の ScheduledTask と競合 *)
SessionSubmit[SelectionEvaluate[nb, ...]]
```

#### 3. ExternalEvaluate (Python)

```mathematica
(* ❌ ScheduledTask 内から ExternalEvaluate → サブプロセスがブロック *)
ExternalEvaluate["Python", code]
```

### 安全な代替手段

| 方式 | ScheduledTask 内 | 用途 |
|---|---|---|
| `LLMSynthesize[prompt]` | ✅ 安全 | クラウド LLM (同期 HTTP) |
| `URLRead[HTTPRequest[...]]` | ✅ 安全 | ローカル LLM / 任意の HTTP API |
| `ClaudeQuery[prompt, Fallback->True]` | ❌ 危険 | トップレベルのみ |
| `ExternalEvaluate["Python", ...]` | ❌ 危険 | URLRead に置き換え |

### パッケージ関数からの LLM 呼び出しパターン

```mathematica
(* ✅ 安全: LLMSynthesize を優先、ClaudeQuery はトップレベル判定後のみ *)
iQueryCloudLLM[prompt_String] := Module[{result},
  result = Quiet @ Check[LLMSynthesize[prompt], $Failed];
  If[StringQ[result] && result =!= "", Return[result]];
  (* ScheduledTask 内でないことを確認してから ClaudeQuery *)
  If[Quiet[Check[$CurrentTask, None]] === None &&
     Quiet[Check[$ScheduledTask, None]] === None,
    result = Quiet @ Check[ClaudeQuery[prompt, Fallback -> True], $Failed];
    If[StringQ[result] && result =!= "", Return[result]]];
  ""]

(* ✅ 安全: ローカル LLM は URLRead で直接呼ぶ *)
iQueryLocalLLM[prompt_String] := iQueryLMStudioDirect[prompt, url, model]
```

### 秘密/公開データの並列処理パターン

```mathematica
(* ✅ 正しいパターン: 逐次処理、両方とも同期 HTTP *)
privResult = iQueryLocalLLM[privPrompt];   (* 秘密: ローカル LLM *)
pubResult = iQueryCloudLLM[pubPrompt];     (* 公開: クラウド LLM *)

(* ❌ 危険: 両方で ClaudeQuery → デッドロック *)
privResult = ClaudeQuery[privPrompt, Model -> $ClaudePrivateModel];
pubResult = ClaudeQuery[pubPrompt, Fallback -> True];
```

**原則**: 秘密データは `URLRead` でローカル LLM、公開データは `LLMSynthesize` でクラウド LLM。逐次処理し、`ClaudeQuery` は使わない。

---

## B. 独自 ScheduledTask 作成の禁止

claudecode は単一の共有ポーリングタスク (`$iSharedPollingTask`) で全非同期クエリを一括管理する。
パッケージが独自に `CreateScheduledTask` で UI ポーリング・進捗表示を行うと、
複数の ScheduledTask が同時に FrontEnd 操作を行い「動的評価の放棄」ダイアログでフリーズする。

### 必須

- UI フィードバック（`WindowStatusArea` 更新、`NotebookWrite`、`Dynamic` 表示等）を伴う非同期タスクは、claudecode の `iClaudeQueryAsyncWithProgress[]` および NBAccess の公開関数を通じて実行する。
- パッケージ側で `CreateScheduledTask` / `RunScheduledTask` を使ってポーリングや進捗表示のループを作成してはならない。

### 禁止例

```mathematica
(* ❌ パッケージ内で独自に進捗ポーリングタスクを作る *)
myTask = CreateScheduledTask[
  CurrentValue[nb, WindowStatusArea] = "処理中..." <> ToString[elapsed] <> "s";
  If[ProcessStatus[proc] === "Finished", ...],
  1];

(* ❌ RunScheduledTask で FrontEnd 更新ループを構築する *)
RunScheduledTask[
  NotebookWrite[nb, Cell[progressText, "Print"]]; ...,
  {1}]
```

### 安全な代替手段

```mathematica
(* ✅ claudecode の共有ポーリング基盤を利用する *)
iClaudeQueryAsyncWithProgress[prompt, callback, nb]

(* ✅ 純粋計算を ParallelSubmit で並列化（FrontEnd 通信なし） *)
ParallelSubmit[heavyComputation[data]]
```

### 例外（独自 ScheduledTask の使用を許可）

以下のいずれかを満たす場合に限り許可する:

1. **純粋計算タスク**: 数値計算・組み合わせ問題・シミュレーション等、FrontEnd との通信を一切行わない処理。
2. **インタラクティブプログラム**: `PresentationListener` のように、リアルタイム性が必要で共有ポーリングの間隔では要件を満たせないプログラム。

#### 例外使用時の義務

ドキュメント（`api.md` / `user_manual.md` / `README.md`）に独自 ScheduledTask を使用している旨と理由を**明記**すること。

---

## C. 複数 LLM 呼び出しの非同期処理: LLMGraph DAG フレームワーク

複数の LLM 呼び出しを組み合わせてデータを処理するパッケージでは、
claudecode の **LLMGraph DAG フレームワーク** (`LLMGraphDAGCreate`) を使用すること。

### 背景

PDF インデクシング・文書翻訳・マルチステップ要約等では、
複数の LLM 呼び出し（OCR、要約、分類等）を依存関係を持たせて実行する必要がある。
これを手動で `StartProcess` + 独自 `ScheduledTask` で管理すると、
セクション B の禁止事項に抵触し、フロントエンドフリーズの原因となる。

### 必須: LLMGraphDAGCreate の使用

```mathematica
(* ✅ 正しいパターン: LLMGraphDAGCreate で DAG を定義・実行 *)
jobId = LLMGraphDAGCreate[<|
  "nodes" -> <|
    "ocr-1" -> iLLMGraphNode["ocr-1", "claude-cli", "ocr", {},
      Function[{job}, (* handler: <|"proc"->...|> を返す *)]],
    "sum-1" -> iLLMGraphNode["sum-1", "claude-cli", "summarize", {"ocr-1"},
      Function[{job}, (* handler *)]],
    "finalize" -> iLLMGraphNode["finalize", "sync", "save", {"sum-1"},
      Function[{job}, (* sync handler: 結果を直接返す *)]]
  |>,
  "taskDescriptor" -> <|
    "name" -> "MyPackage Processing",
    "categoryMap" -> <|
      "ocr"       -> "cli-vision",
      "summarize" -> "cli",
      "save"      -> "sync"
    |>
  |>,
  "context" -> <|"myData" -> data|>,
  "onComplete" -> Function[{job}, (* 全ノード完了時の処理 *)]
|>];
```

```mathematica
(* ❌ 禁止: 独自 ScheduledTask で LLM プロセスをポーリング *)
myTask = RunScheduledTask[
  If[ProcessStatus[proc] === "Finished",
    result = Import[outFile]; ...],
  1];
```

### ノード型とカテゴリ

#### ノード型 (`type`)

| 型 | 実行方法 | 用途 |
|---|---|---|
| `"sync"` | `handler[job]` を即時実行、戻り値が結果 | データ変換、マージ、保存 |
| `"claude-cli"` | `StartProcess` → ポーリング | Claude CLI 呼び出し |
| `"python"` | `StartProcess` → ポーリング | Python スクリプト実行 |

async ノード（`"sync"` 以外）の handler は `<|"proc" -> ProcessObject[...], "outFile" -> "..."|>` を返すこと。
スケジューラが `iICollectChunkResult` で自動ポーリングする。

#### 抽象カテゴリと並列度制御

`$LLMGraphMaxConcurrency` がグローバルデフォルト値を定義:

| 抽象カテゴリ | デフォルト並列度 | 用途 |
|---|---|---|
| `"cli"` | 4 | Claude CLI テキスト単体（要約等） |
| `"cli-vision"` | 1 | Claude CLI 画像付き（OCR 等） |
| `"process"` | 1 | 外部プロセス（Python 等） |
| `"sync"` | 99 | 同期ハンドラ（実質無制限） |

パッケージは `taskDescriptor["categoryMap"]` でノード固有カテゴリ（`"ocr"`, `"summarize"` 等）を
抽象カテゴリにマッピングする。

#### 並列度のオーバーライド

ジョブ固有の並列度制限が必要な場合、`taskDescriptor["maxConcurrency"]` で指定:

```mathematica
"taskDescriptor" -> <|
  "name" -> "...",
  "categoryMap" -> <|...|>,
  "maxConcurrency" -> <|"cli" -> 2|>  (* このジョブだけ CLI 2並列に制限 *)
|>
```

解決優先順位: ジョブ固有 → `$LLMGraphMaxConcurrency` → 1（フォールバック）

### handler 内のデータアクセス

handler 関数は `Function[{job}, ...]` で、`job` は以下のキーを持つ:

| キー | 内容 |
|---|---|
| `job["nodes"]` | 全ノードの Association（他ノードの結果参照用） |
| `job["context"]` | `LLMGraphDAGCreate` 時に指定したジョブ固有データ |
| `job["nb"]` | NotebookObject（ステータスバー更新用） |

```mathematica
(* 例: 前のノードの結果を参照 *)
Function[{job},
  Module[{prevResult = Lookup[
      Lookup[job["nodes"], "ocr-1", <||>], "result", ""]},
    (* prevResult を使って処理 *)
  ]]
```

### 完了コールバック

`"onComplete" -> Function[{job}, ...]` で全ノード完了時（成功・失敗問わず）の処理を定義:

```mathematica
"onComplete" -> Function[{completedJob},
  Module[{failCount = Count[Values[completedJob["nodes"]],
      _?(Lookup[#, "status", ""] === "failed" &)]},
    If[failCount > 0, Print["失敗ノードあり: " <> ToString[failCount]]]]]
```

### ステータス・キャンセル

```mathematica
LLMGraphDAGStatus[jobId]   (* ノード状態集計 *)
LLMGraphDAGCancel[jobId]   (* 実行中プロセスを KillProcess + クリーンアップ *)
```

---

## D. deferred sync runState による async ノード handler の実装

LLMGraphDAGCreate のノード handler は以下のいずれかの戻り値を返さなければならない:

| handler 戻り値 | ノード type | 動作 |
|---|---|---|
| 任意の値 (Association や文字列、$Failed以外) | `"sync"` | 即時完了、戻り値が `result` |
| `<\|"proc" -> ProcessObject[...], "outFile" -> ..., ...\|>` | `"sync"` | **deferred sync** に遷移、tick がポーリング |
| `<\|"proc" -> ..., "outFile" -> ..., ...\|>` | `"claude-cli"` 等 | 通常の async、tick がポーリング |
| `$Failed` または `None` | `"sync"` | 即時 failed |

deferred sync runState は **sync ノードでも async 実行できる**仕組みで、Orchestrator の Plan / Worker / Reduce / Commit フェーズの非同期化に使われている。

**AsyncToolExec (Phase 32k Step 3) もこのパターンの応用**: `web_search` 等の tool 実行を `StartProcess` で別 OS プロセスとして起動し、`ClaudeRegisterPollingTick` (LLMGraphDAG の `iICollectChunkResult` と同等の機構) で結果をポーリングする。詳細は skill `async-tool-execution` と rule `100-async-tool-execution`。

### deferred sync runState の正確な仕様

handler が以下の形の Association を返すと、DAG tick が `iICollectChunkResult` で自動的に完了監視する:

```mathematica
<|
  "proc"       -> ProcessObject[...],   (* 必須: StartProcess の戻り値 *)
  "outFile"    -> "/path/to/output.txt", (* 必須: プロセス完了後に読み込む結果ファイル *)
  "startTime"  -> AbsoluteTime[],        (* 必須: timeout 計測用 *)
  "timeout"    -> 1200,                  (* 任意: 秒、デフォルト $ClaudeTimeout *)
  "parseFn"    -> Function[{raw}, ...],  (* 任意: 結果文字列を構造化 *)
  "batFile"    -> "...",                 (* 任意: 後始末用 *)
  "promptFile" -> "...",                 (* 任意: 後始末用 *)
  "errFile"    -> "..."                  (* 任意: エラーログ *)
|>
```

完了判定は `ProcessStatus[proc] === "Finished"`。完了後、`outFile` を `Import[..., "Text"]` で読み、`parseFn` がある場合はそれを通して構造化した結果がノードの `result` にセットされる。

### ❗ 重要: `RunProcess[..., "Process"]` は無効引数

過去のコード (Orchestrator の `iLaunchPlanPhase` / `iLaunchSingleWorker`) で次の書き方が見られるが、**Wolfram の `RunProcess` の仕様上これは無効**:

```mathematica
(* ❌ 無効: RunProcess の第 2 引数で許可されているのは
   "ExitCode", "StandardOutput", "StandardError", "All" のみ。
   "Process" は受け付けられず、optvp エラー → $Failed が返る。 *)
proc = RunProcess[{"cmd", "/c", batFile},
  ProcessDirectory -> workDir,
  "Process"]
```

このコードは常に `$Failed` を返し、`Quiet @ Check` で吸収されて `$Failed` 判定後に sync fallback 経路に落ちていた。**結果として deferred sync が実質機能していなかった**。

正しくは `StartProcess`(同期しない、即返却で `ProcessObject` を返す)を使う:

```mathematica
(* ✅ 正しい: StartProcess は ProcessObject を即返却する非同期 API *)
proc = StartProcess[{"cmd", "/c", batFile},
  ProcessDirectory -> workDir]
```

`RunProcess` は **同期 API** で、外部プロセスの完了まで Wolfram カーネルをブロックする。deferred sync runState には使えない。

### sync API と async API の責任分離

パッケージ関数を設計する際、**同期 API と非同期 API を混在させない**:

```mathematica
(* ❌ 危険: 同期 API のはずが内部で非同期処理を試みる *)
ClaudePlanTasks[input, "Planner" -> "LLM"] :=
  Module[{...},
    (* ノートブックトップレベルから呼ばれることを想定した sync API なのに、
       内部で async ScheduledTask を起動 + Pause ループで待つと、Pause の間
       カーネルが評価専有 → フロントエンドブロック *)
    ClaudeQueryAsync[prompt, callback, nb];
    While[!done, Pause[0.2]];   (* ❌ フロントエンドはブロックする *)
    result]
```

**理由**: Wolfram の `Pause` はカーネル評価をスリープさせるだけで、フロントエンドメッセージループを回さない。`While + Pause` で同期 wait を作ってもフロントエンドは応答しない(進行表示の Dynamic は ScheduledTask 経由で更新されるが、新規セルの評価はブロックされる)。

正しい設計:

| API 種類 | フロントエンド非ブロック | 用途 |
|---|---|---|
| `xxxAsync[input, opts]` → JobId 文字列 | ✅ | LLMGraphDAGCreate 経由で async chain |
| `xxx[input, opts]` → 結果 | ❌ (sync が正常) | トップレベル sync 呼び出し |

`ClaudeRunOrchestrationAsync` は async API なので JobId を返し、ユーザーは `ClaudeOrchestrationStatus[orchId]` で完了を確認、`ClaudeOrchestrationResult[orchId]` で結果取得。

```mathematica
(* ✅ 正しいパターン: async API は JobId を返す *)
orchId = ClaudeRunOrchestrationAsync[input, "Planner" -> "LLM"]
(* ノートブックは即座に応答可能、別セルで Plot などが評価できる *)

(* 完了確認 *)
ClaudeOrchestrationStatus[orchId]   (* Status -> "Done" になるまでポーリング *)
ClaudeOrchestrationResult[orchId]   (* 完了後に結果取得 *)
```

---

## E. ローカル LLM (LMStudio 等) の async 化パターン

ローカル LLM (LMStudio, Ollama 等) は HTTP API で動くため、`URLRead` で同期的に呼ぶことができる。しかし `URLRead` 自体は **同期** API で、HTTP レスポンスが返るまで Wolfram カーネルをブロックする。フロントエンド非ブロックで実行するには **claudecode の `iStartFallbackAsync`** を使う。

### `iStartFallbackAsync` の役割

claudecode は LMStudio 等のローカル LLM を **PowerShell スクリプト経由**で非同期起動する基盤を持つ:

```mathematica
ClaudeCode`Private`iStartFallbackAsync[
  prompt,                       (* プロンプト *)
  nb_NotebookObject,            (* 進捗表示用ノートブック *)
  callback_,                    (* 完了 callback: Function[response, ...] *)
  models_List                   (* {{provider, model, url}, ...} *)
]
```

内部で `iPrepareLMStudioMCPPS1` が PowerShell スクリプトを生成 → `StartProcess` で起動 → 独自 ScheduledTask で監視(節 B の例外ケース、claudecode の特権基盤)→ 完了時に callback を呼ぶ。

`iClaudeQueryAsyncWithProgress` (Claude CLI 用) と並んで claudecode の標準 async 基盤。

### ❗ deferred sync runState への変換: 「ダミー proc + outFile 書込」パターン

`iStartFallbackAsync` は callback 型で `proc` を露出しないため、そのままでは LLMGraphDAG の deferred sync runState に組み込めない。これを橋渡しするため、**ダミーの長時間プロセスを `proc` キーに入れ、callback 内でそのプロセスを Kill する**パターンを使う:

```mathematica
(* ✅ ローカル LLM async ノード handler の正規パターン *)
Module[{dummyProc, outFile, errFile},
  outFile = FileNameJoin[{workDir, "task_out_" <> uniqueTag <> ".txt"}];
  errFile = FileNameJoin[{workDir, "task_err_" <> uniqueTag <> ".txt"}];
  
  (* 1. ダミーの長時間プロセスを起動 (proc キー用、何もしない sleep) *)
  dummyProc = StartProcess[{"cmd", "/c",
    "timeout /t 1200 /nobreak >nul"}];
  
  (* 2. iStartFallbackAsync で本命 LLM 呼び出しを起動 *)
  With[{ofile = outFile, dproc = dummyProc, mdl = modelSpec, evalNb = nb},
    ClaudeCode`Private`iStartFallbackAsync[
      prompt, evalNb,
      Function[rawResp,
        (* 3. callback で outFile に応答を書く *)
        Quiet @ Check[
          Export[ofile,
            If[StringQ[rawResp], rawResp, ""],
            "Text", CharacterEncoding -> "UTF-8"],
          Null];
        (* 4. ダミー proc を Kill して "Finished" 状態にする *)
        Quiet @ KillProcess[dproc]
      ],
      {mdl}]
  ];
  
  (* 5. deferred sync runState を返す *)
  <|"proc"      -> dummyProc,
    "outFile"   -> outFile,
    "errFile"   -> errFile,
    "startTime" -> AbsoluteTime[],
    "timeout"   -> 1200,
    "parseFn"   -> Function[{raw}, parseStructure[raw]]|>
]
```

このパターンの動作:

1. ハンドラ呼び出し直後にダミー proc(`timeout` コマンドで何もしないプロセス)を起動 → `ProcessStatus === "Running"`
2. `iStartFallbackAsync` で本命の LLM 呼び出しが PowerShell 経由で別途進行(フロントエンド非ブロック)
3. ハンドラは即返却 → DAG tick がノードを `"running"` に遷移
4. tick の各回(共有ポーリング 3 秒間隔)で `ProcessStatus[dummyProc]` をチェック → `"Running"` のまま → 何もしない(フロントエンド応答維持)
5. LLM 完了 → callback 実行 → `outFile` 書込 + `KillProcess[dummyProc]` → `ProcessStatus === "Finished"`
6. 次の tick で完了検出 → `Import[outFile]` → `parseFn` で構造化 → ノード `result` セット
7. 全ノード完了 → `onComplete` 駆動 → 次フェーズへ

### モデル振り分けパターン

LLM 呼び出しを行うパッケージは、`$ClaudeModel` の値で経路を振り分ける:

```mathematica
(* ✅ モデル振り分け: LMStudio (リスト形式) なら iStartFallbackAsync、
   それ以外 (Automatic / 文字列) は Claude CLI *)
Module[{modelSpec, useLMStudio},
  modelSpec = $ClaudeModel;
  useLMStudio = ListQ[modelSpec] && Length[modelSpec] >= 2 &&
                StringQ[modelSpec[[1]]] &&
                ToLowerCase[modelSpec[[1]]] === "lmstudio";
  
  If[useLMStudio,
    (* ローカル LLM 経路: iStartFallbackAsync + ダミー proc *)
    ...,
    (* Claude CLI 経路: iMakeBat + StartProcess *)
    batFile = ClaudeCode`iMakeBat[promptFile, outFile, {}, False, {}];
    proc = StartProcess[{"cmd", "/c", batFile},
      ProcessDirectory -> workDir];
    <|"proc" -> proc, "outFile" -> outFile, ...|>
  ]
]
```

### 失敗時のフォールバック

handler 内で deferred sync runState を返せない場合(`StartProcess` 失敗、ファイル作成失敗等)は **同期版関数** に fallback する:

```mathematica
(* ❌ ここで $Failed を返すと DAG ノードが failed になる *)
If[!MatchQ[proc, _ProcessObject],
  Return[$Failed]];

(* ✅ 同期版にフォールバック: chain は止めずに sync で進行 *)
If[!MatchQ[proc, _ProcessObject],
  Return[iRunSingleWorkerSync[task, ...]]];
```

ただし sync fallback は **そのフェーズ全体がフロントエンドをブロック**する点に注意。LMStudio worker が並列に複数 sync で動くと、各 worker の同期 HTTP 呼び出しの間カーネルが専有される。

---

## デバッグのチェックリスト

非同期処理が「最初は応答するがすぐフリーズする」「動的評価の放棄ダイアログが出る」場合:

1. **`RunProcess[..., "Process"]` を使っていないか** → 常に `$Failed` を返すので sync fallback されている。`StartProcess` に置き換える。
2. **`Pause` ループでの完了待機をしていないか** → `Pause` はフロントエンド非応答を起こす。`xxxAsync` API + JobId ベースに変える。
3. **handler が deferred sync runState を返しているか** → `<|"proc", "outFile", ...|>` 形式必須。`Null` や `Module[..., callback起動]` だけだと DAG が混乱する。
4. **独自 ScheduledTask を作っていないか** → 節 B 違反。`LLMGraphDAGCreate` か `iStartFallbackAsync` 経由に変える。
5. **sync API を非同期化していないか** → 節 D。sync API は sync のまま、非同期は別 API として `xxxAsync` を提供する。
6. **`$ClaudeModel` がリスト形式 (LMStudio) のとき、CLI 経路の bat に流していないか** → 節 E のモデル振り分けパターンを実装する。
