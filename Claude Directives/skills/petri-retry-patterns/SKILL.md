---
name: petri-retry-patterns
description: petri_from_prompt 系で fan-out 並列 worker の失敗を retry する Petri net を生成するときの正しい配線指針。retry トリガを Merge の下流 (Verdict) に置くアンチパターンを避け、失敗した individual worker のみを retry する per-worker retry を採用する。AddRetryGuideToPetriPrompt[] 経由で $petriNetGuide に追記される。
---

<!--
このファイルは LLM 生成プロンプトの一部としてそのまま `$petriNetGuide` に
追記される。`AddRetryGuideToPetriPrompt[]` 経由で
`iReadSkillBody["petri-retry-patterns"]` で読み込まれる。
-->

# Retry pattern selection in fan-out parallel review nets (CRITICAL)

When the user requests "個別レビューが失敗したら N 回リトライ" or "retry on
failure" in a fan-out parallel review workflow, the retry pattern MUST be
**per-worker retry** (the failing worker alone retries), NOT a downstream
**rerun-all retry** (everyone retries because Verdict triggered it).

## The downstream-rerun antipattern (DO NOT generate)

A common but incorrect pattern places the retry transition AFTER the merge:

  WorkerOpus    \
                  -> ResultPool -> Merge -> Merged -> Assess -> Verdict
  WorkerChatGPT /                                                |
                                                       +---------+
                                                       v
                                              Retry (Guard: "needs retry")
                                              -> { PoolOpus, PoolChatGPT }    (* AND-fork: both rerun *)

Why this is broken:

(B1) **Merge cannot fire if any worker failed.** With AND-merge, if even
     one Result Place is empty (because that worker failed), Merge will
     never enable, so Verdict never gets a token, so Retry never gets a
     token. **The retry trigger is downstream of the failure point.**
     The whole net is permanently stuck at Merge with no recovery.

(B2) **If the retry does fire (because Merge succeeded but Assess judged
     "needs repair"), it reruns the SUCCESSFUL workers too**, doubling the
     LLM API cost. The success of WorkerOpus must not depend on whether
     WorkerChatGPT also needs to retry.

(B3) **The retry trigger conflates two different signals**:
     - "An individual worker failed" (transient API error, model unavailable)
     - "The aggregated result is not good enough" (semantic judgment)
     These need different responses and different counters.

## The per-worker retry pattern (USE THIS)

Each worker has its own retry mechanism via Petri net's natural transition
RetryPolicy facility, supplemented by a Trial counter on the input token if
finer control is needed.

### Pattern A: rely on transition RetryPolicy (simplest)

The Workflow engine has a built-in MaxRetries field per transition. Set it
on each Worker transition. atomic firing rollback (handler $Failed leaves
input token in place, increments TransitionFailureCounts) means the engine
auto-retries up to MaxRetries+1 times before giving up.

  "WorkerOpus" -> WorkflowTransition["WorkerOpus",
    "InputArcs"  -> {<|"Place" -> "PoolOpus", "Multiplicity" -> 1|>},
    "OutputArcs" -> {<|"Place" -> "ResultOpus", "Multiplicity" -> 1, "TokenKind" -> "Result"|>},
    "Executor"   -> "PureFunction",
    "RuntimeSpec" -> <|"Handler" -> opusReviewer|>,
    "RetryPolicy" -> <|"MaxRetries" -> 2, "Backoff" -> "None"|>],

  "WorkerChatGPT" -> WorkflowTransition["WorkerChatGPT",
    ...
    "RetryPolicy" -> <|"MaxRetries" -> 2, "Backoff" -> "None"|>],

If WorkerChatGPT fails 3 times (MaxRetries=2 means initial+2 retries=3 total):
- the engine auto-removes WorkerChatGPT from enabled
- PoolChatGPT keeps its token (atomic rollback)
- the workflow becomes Stuck (correct: incomplete peer review)

WorkerOpus is unaffected. **No manual Retry transition is needed for the
"individual reviewer failure" case.** This is the canonical retry pattern
for fan-out Worker fails.

### Pattern B: explicit per-worker Retry transition with Trial counter

Use this when the user wants visibility / observability of retries, or when
each retry needs different parameters (e.g. higher temperature on retry).

  "PoolOpus" -> WorkflowPlace["PoolOpus"],
  "WorkerOpus" -> WorkflowTransition["WorkerOpus",
    "InputArcs"  -> {<|"Place" -> "PoolOpus", "Multiplicity" -> 1|>},
    "OutputArcs" -> {
      <|"Place" -> "ResultOpus",   "Multiplicity" -> 1, "TokenKind" -> "Result"|>,
      <|"Place" -> "OpusOK",       "Multiplicity" -> 1, "TokenKind" -> "Marker"|>},
    "Guard" -> Function[b,
      Module[{review},
        review = ...handler call...;
        !iIsLLMErrorResponse[review]]],   (* only fire if review succeeds *)
    "RuntimeSpec" -> <|"Handler" -> opusReviewer|>],

  "RetryOpus" -> WorkflowTransition["RetryOpus",
    "InputArcs"  -> {<|"Place" -> "PoolOpus", "Multiplicity" -> 1|>},
    "OutputArcs" -> {<|"Place" -> "PoolOpus", "Multiplicity" -> 1, "TokenKind" -> "Task"|>},
    "Guard" -> Function[b,
      And[opusReviewFailed[b],
          b[["PoolOpus", "Payload", "Trial"]] < 3]],
    "RuntimeSpec" -> <|"Handler" -> Function[b,
      Module[{p = b[["PoolOpus", "Payload"]]},
        <|"Payload" -> Append[p, "Trial" -> Lookup[p, "Trial", 1] + 1]|>]]|>],

  "GiveUpOpus" -> WorkflowTransition["GiveUpOpus",
    "InputArcs"  -> {<|"Place" -> "PoolOpus", "Multiplicity" -> 1|>},
    "OutputArcs" -> {<|"Place" -> "OpusFailed", "Multiplicity" -> 1, "TokenKind" -> "Failure"|>},
    "Guard" -> Function[b,
      b[["PoolOpus", "Payload", "Trial"]] >= 3]],

(Repeat the same triple — Worker / Retry / GiveUp — for each reviewer.)

The Merge transition then takes ResultOpus and ResultChatGPT (success path)
or alternative aggregation rules depending on the failure markers. This is
more verbose but gives full control.

## When Pattern A vs Pattern B?

- The user says "失敗したら N 回繰り返す" with no further detail → Pattern A
  (simplest, matches the implicit "engine handles transient failures" model).
- The user wants to observe retry counts, change parameters per attempt, or
  branch on failure type → Pattern B.
- The user wants partial-result aggregation ("if ChatGPT keeps failing,
  finalize with Opus's review only") → Pattern B with explicit failure
  markers fed to Merge.

## What about "the aggregated result is not good enough" semantic retry?

This is a DIFFERENT case from individual worker failure. If the user wants
"if Assess judges the merged review needs repair, redo the whole pass",
THAT is when a downstream Verdict -> Retry -> {PoolOpus, PoolChatGPT}
loop is appropriate. Make this distinction in your generated net:

- Individual worker fails (transient, API error) → per-worker RetryPolicy.
- Aggregated semantic judgment fails (Assess says "Repair") → downstream
  Retry that reruns workers (after deciding if all or some need redo).

If the user's prompt mixes both ("retry on failure" without specifying
which kind), default to **per-worker RetryPolicy only** (Pattern A) and
ask the user to clarify if they also want semantic retry. The per-worker
pattern is strictly safer (no API cost amplification, no infinite loop
risk from missing Trial counters).

## Concrete checklist before generating

Before emitting WorkflowNet, verify:

1. Each Worker transition that calls an LLM has either a
   `"RetryPolicy" -> <|"MaxRetries" -> N|>` OR an explicit
   per-worker Retry transition with a Trial counter Guard.
2. If there is a downstream Verdict -> Retry loop, the Retry transition's
   Guard explicitly checks `Trial < MaxTrials` AND there is a corresponding
   GiveUp transition for `Trial >= MaxTrials`.
3. The Merge transition is AND-merge (multiple InputArcs OR
   Multiplicity > 1). Verify by tracing: if WorkerChatGPT alone fails,
   does Merge still need ResultChatGPT? It should.
4. If you choose Pattern A (engine RetryPolicy), there is **no manual
   Retry transition that branches off from the Merge downstream**.
   That pattern is the broken antipattern (B1, B2, B3 above).
5. Trial counters, if used, are incremented exactly once per retry and
   never reset (otherwise the GiveUp guard never fires).

## Why this skill matters

Even with AND-merge skill (`petri-and-xor-merge`) and Provider skill
(`petri-multi-provider-generation`), the LLM tends to generate the
downstream-rerun antipattern because that pattern appears in many
workflow tutorials online (it is the simplest "retry once" example).
The pattern is locally plausible but globally broken when combined
with AND-merge. This skill explicitly warns against it.
