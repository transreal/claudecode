---
paths:
  - "**/*.{wl,wls,m,nb}"
---

# ScheduledTask・非同期処理の安全制約

## 概要

claudecode は ScheduledTask ベースの非同期処理基盤を提供する。
パッケージ開発時には以下の **2 つの制約** を厳守すること:

- **A. ScheduledTask 内からの禁止操作**: ClaudeEval / ContinueEval のチェーン内から ClaudeQuery 等を呼ばない
- **B. 独自 ScheduledTask 作成の禁止**: UI ポーリング用の ScheduledTask を自前で作らず claudecode の共有基盤に委ねる

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
