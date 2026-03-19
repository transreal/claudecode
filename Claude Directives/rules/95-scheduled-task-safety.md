# ScheduledTask・非同期処理の安全制約

## 概要

ClaudeEval / ContinueEval は内部で `ScheduledTask` チェーンを使用する。
パッケージ関数がこのチェーン内から呼ばれる可能性がある場合、以下の制約を厳守すること。

## 禁止事項

### 1. ScheduledTask 内からの ClaudeQuery 呼び出し

```mathematica
(* ❌ ClaudeEval が生成したコード内で ClaudeQuery を呼ぶ → デッドロック *)
mailAskLLM[...] の内部で ClaudeQuery[prompt, Fallback -> True]

(* ❌ 同一の自動評価ブロック内で ClaudeQuery を2回呼ぶ → 確実にフリーズ *)
result1 = ClaudeQuery[prompt1];
result2 = ClaudeQuery[prompt2];
```

**原因**: ClaudeQuery は `StartProcess` + `CreateScheduledTask` で Claude CLI プロセスを管理する。
ClaudeEval の ScheduledTask 内から呼ぶと、ネストした ScheduledTask が作られ、
カーネルの評価キューがブロックされる。

### 2. ScheduledTask 内からの SessionSubmit + SelectionEvaluate

```mathematica
(* ❌ ScheduledTask 内で SessionSubmit → ClaudeEval の ScheduledTask と競合 *)
SessionSubmit[SelectionEvaluate[nb, ...]]
```

### 3. ExternalEvaluate (Python) のサブプロセス問題

```mathematica
(* ❌ ScheduledTask 内から ExternalEvaluate → サブプロセスがブロック *)
ExternalEvaluate["Python", code]
```

## 安全な代替手段

### LLM 呼び出し

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

### ClaudeEval / ContinueEval のチェーン

```mathematica
(* ✅ 安全: ContinueEval は ClaudeEval と同じチェーンで動作するため安全 *)
ClaudeEval["タスクを実行して"]
(* → 出力: ContinueEval[] で継続できます *)
ContinueEval[]

(* ✅ 安全: ClaudeEval が生成するコードが同期関数のみを呼ぶ *)
ClaudeEval["univの今日のメールを表示して"]
(* → 生成: mdb = mailEnsureLoaded["univ"]; showMails[...] *)
```

## 秘密/公開メールの並列処理パターン

メール処理で秘密（Confidential）データと公開（NonConfidential）データを分離して処理する場合:

```mathematica
(* ✅ 正しいパターン: 逐次処理、両方とも同期 HTTP *)
(* 秘密分: ローカル LLM (URLRead → LM Studio) *)
privResult = iQueryLocalLLM[privPrompt];
(* 公開分: クラウド LLM (LLMSynthesize) *)
pubResult = iQueryCloudLLM[pubPrompt];

(* ❌ 危険なパターン: 両方で ClaudeQuery を使う *)
privResult = ClaudeQuery[privPrompt, Model -> $ClaudePrivateModel];
pubResult = ClaudeQuery[pubPrompt, Fallback -> True];
(* → 2回の ClaudeQuery が ScheduledTask 内でデッドロック *)
```

**原則**:
- 秘密データ → `URLRead` でローカル LLM (LM Studio 等) に送信。HTTP 通信なので安全。
- 公開データ → `LLMSynthesize` でクラウド LLM に送信。同期 HTTP なので安全。
- いずれも `ClaudeQuery` や `ExternalEvaluate` は使わない。
- 処理は逐次（Sequential）で行い、並列化しない。
