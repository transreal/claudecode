---
name: petri-and-xor-merge
description: petri_from_prompt 系で複数 transition の出力を結合 (merge) する際、用途に応じて AND-merge と XOR-merge を正しく選択するための設計指針。peer review (複数査読者の総合判断) は AND-merge、冗長系 (どれか一つ届けば良い) は XOR-merge。`AddProviderSupportToPetriPrompt[]` と同列の追記用 skill (`AddANDMergeGuideToPetriPrompt[]` 経由)。
---

<!--
このファイルは LLM 生成プロンプトの一部としてそのまま `$petriNetGuide` に
追記される。`AddANDMergeGuideToPetriPrompt[]` 経由で
`iReadSkillBody["petri-and-xor-merge"]` で読み込まれる。
-->

# AND-merge vs XOR-merge in Petri nets (CRITICAL)

When multiple transitions produce results that need to be combined, choose the
correct merge pattern. This is a fundamental Petri net design decision and the
wrong choice leads to silent semantic errors (e.g. peer review reporting Done
when only one reviewer succeeded).

## Two distribute patterns

**AND-distribute (Fork / Parallel split)**: One source token is split into
parallel work for ALL downstream workers. Every worker MUST run.

  "Distribute" -> WorkflowTransition["Distribute",
    "InputArcs"  -> {<|"Place" -> "Source", "Multiplicity" -> 1|>},
    "OutputArcs" -> {
      <|"Place" -> "PoolOpus",    "Multiplicity" -> 1, "TokenKind" -> "Task"|>,
      <|"Place" -> "PoolChatGPT", "Multiplicity" -> 1, "TokenKind" -> "Task"|>
    }, ...]

Use when: peer review, multi-perspective analysis, ensemble computation —
i.e. the user wants ALL outputs combined.

**XOR-distribute (Choice)**: Multiple downstream transitions share an input
Place; only one of them fires per token (selected by Guard). Use when: one of
several mutually exclusive paths is taken based on some condition.

  "Pool" -> WorkflowPlace["Pool"],
  "PathA" -> WorkflowTransition["PathA",
    "InputArcs" -> {<|"Place" -> "Pool", "Multiplicity" -> 1|>},
    "Guard" -> Function[b, b[["Pool", "Payload", "Kind"]] === "A"], ...],
  "PathB" -> WorkflowTransition["PathB",
    "InputArcs" -> {<|"Place" -> "Pool", "Multiplicity" -> 1|>},
    "Guard" -> Function[b, b[["Pool", "Payload", "Kind"]] === "B"], ...]

NOTE: For pure parallel fan-out (every worker does its own thing), use
AND-distribute with **DEDICATED Places per worker** (PoolOpus + PoolChatGPT,
not a shared Pool). A shared Pool with no Guards is a XOR-distribute and one
worker will monopolize all tokens (lexicographic priority). See the existing
"WRONG vs RIGHT example for parallel fan-out" section.

## Two merge patterns

**AND-merge (Join / Synchronization)** — combines outputs from ALL upstream
producers. The merge transition does NOT fire until **every** upstream input
Place has its required token. If any upstream worker fails, the merge is
**deadlocked at the merge Place** (which is the correct behavior: the
workflow correctly indicates "incomplete").

Two valid AND-merge encodings:

**Pattern A (RECOMMENDED for peer review): dedicated output Places per worker**

  "ResultOpus"    -> WorkflowPlace["ResultOpus"],
  "ResultChatGPT" -> WorkflowPlace["ResultChatGPT"],
  "WorkerOpus" -> WorkflowTransition["WorkerOpus",
    "InputArcs"  -> {<|"Place" -> "PoolOpus", "Multiplicity" -> 1|>},
    "OutputArcs" -> {<|"Place" -> "ResultOpus", "Multiplicity" -> 1, ...|>}, ...],
  "WorkerChatGPT" -> WorkflowTransition["WorkerChatGPT",
    "InputArcs"  -> {<|"Place" -> "PoolChatGPT", "Multiplicity" -> 1|>},
    "OutputArcs" -> {<|"Place" -> "ResultChatGPT", "Multiplicity" -> 1, ...|>}, ...],
  "Merge" -> WorkflowTransition["Merge",
    "InputArcs"  -> {
      <|"Place" -> "ResultOpus",    "Multiplicity" -> 1|>,
      <|"Place" -> "ResultChatGPT", "Multiplicity" -> 1|>
    },
    "OutputArcs" -> {<|"Place" -> "Merged", "Multiplicity" -> 1, ...|>}, ...]

The merge handler receives both tokens by Place name:

  mergeHandler[binding_] := Module[{p1, p2, mergedText},
    p1 = binding[["ResultOpus",    "Payload"]];   (* flat Payload, single token *)
    p2 = binding[["ResultChatGPT", "Payload"]];
    mergedText = Lookup[p1, "Text", Lookup[p2, "Text", ""]];
    <|"Payload" -> <|
       "Text"          -> mergedText,
       "ReviewOpus"    -> Lookup[p1, "ReviewOpus", ""],
       "ReviewChatGPT" -> Lookup[p2, "ReviewChatGPT", ""]
    |>|>];

Pros: each reviewer's output is identifiable by Place name; the workflow
deadlocks naturally if any reviewer fails (correct semantic for peer review).

**Pattern B: shared Place with Multiplicity = N**

  "ResultPool" -> WorkflowPlace["ResultPool"],
  "Merge" -> WorkflowTransition["Merge",
    "InputArcs"  -> {<|"Place" -> "ResultPool", "Multiplicity" -> 2|>},
    "OutputArcs" -> {<|"Place" -> "Merged", "Multiplicity" -> 1, ...|>}, ...]

The merge handler receives a LIST of N tokens via the binding:

  mergeHandler[binding_] := Module[{toks, payloads},
    toks = binding[["ResultPool"]];        (* a List of N tokens *)
    payloads = toks[[All, "Payload"]];      (* List of N Payloads *)
    ...]

Use Pattern B only when the producers are interchangeable (e.g. N identical
workers from a single Pool). For peer review with named reviewers, prefer
Pattern A.

**XOR-merge (Merge / Asymmetric choice)** — fires as soon as ANY ONE upstream
producer delivers a token. Used for redundancy / high-availability where you
just need one successful result.

  "Result" -> WorkflowPlace["Result"],     (* single shared output Place *)
  "WorkerOpus" -> WorkflowTransition["WorkerOpus",
    "OutputArcs" -> {<|"Place" -> "Result", "Multiplicity" -> 1, ...|>}, ...],
  "WorkerChatGPT" -> WorkflowTransition["WorkerChatGPT",
    "OutputArcs" -> {<|"Place" -> "Result", "Multiplicity" -> 1, ...|>}, ...],
  "Consume" -> WorkflowTransition["Consume",
    "InputArcs"  -> {<|"Place" -> "Result", "Multiplicity" -> 1|>}, ...]
        (* fires on whichever token arrives first / from whichever worker *)

Use when: redundant providers, take-the-first-result patterns, or
high-availability designs where partial failure is acceptable.

## Decision rule

Ask: **"If one of the parallel workers fails, what should happen?"**

- "Wait for all of them. The result must include every reviewer's input." →
  **AND-merge** (Pattern A or B). A failure should leave the workflow
  correctly stuck at the merge Place, signaling incomplete review.

- "Either result is fine. Whichever comes first is the answer." →
  **XOR-merge**. A failure of one provider is gracefully handled by the other.

For peer review, multi-perspective analysis, ensemble methods, and
"combine N reviews into a final report" the answer is **AND-merge** (almost
always Pattern A, with one Result Place per reviewer).

## Anti-pattern: false XOR-merge presented as Aggregate

A common mistake is writing:

  "Merge" -> WorkflowTransition["Merge",
    "InputArcs"  -> {<|"Place" -> "ResultPool", "Multiplicity" -> 1|>}, ...]
                                                  ^^^^^^^^^^^^^^^^^^^

with multiple Workers writing to a single ResultPool. This is a **XOR-merge**
even if the handler does `binding[["ResultPool", "Payload"]]` and tries to
"Aggregate". Reason: with Multiplicity=1, the transition fires as soon as
ONE token is in ResultPool, ignoring whether the other workers have completed.

Symptoms:
- One worker fails → its token never reaches ResultPool → but Merge still
  fires because the OTHER worker's token is already there.
- The handler's `SelectFirst[..., KeyExistsQ[#, "ReviewChatGPT"] &, <||>]`
  silently substitutes empty for the missing reviewer.
- Workflow reports "Done" when peer review is incomplete.

Fix: switch to AND-merge Pattern A (dedicated Places + multiple InputArcs of
Multiplicity=1) or Pattern B (Multiplicity=N on a shared Place).

## Quick verification

Before submitting your generated net, verify by tracing one source token:

1. If a goal mentions "両方のレビューを総合", "peer review", "全部の reviewer
   の意見をまとめて", "ensemble" → AND-merge.
2. Count the merge transition's InputArcs. AND-merge has either:
   - Multiple InputArc entries (Pattern A), or
   - One InputArc with Multiplicity > 1 (Pattern B).
   If it has exactly one InputArc with Multiplicity=1, it is XOR-merge.
3. Check: if I delete one of the parallel workers, does the merge still fire?
   - YES → XOR-merge. Acceptable only for redundancy.
   - NO  → AND-merge. Correct for peer review.

## Example: Claude Opus + ChatGPT peer review (AND-merge, Pattern A)

  WorkflowNet[
    "SourcePlace" -> "Source",
    "FinalPlaces" -> {"Done"},
    "Places" -> <|
      "Source"        -> WorkflowPlace["Source"],
      "PoolOpus"      -> WorkflowPlace["PoolOpus"],
      "PoolChatGPT"   -> WorkflowPlace["PoolChatGPT"],
      "ResultOpus"    -> WorkflowPlace["ResultOpus"],
      "ResultChatGPT" -> WorkflowPlace["ResultChatGPT"],
      "Merged"        -> WorkflowPlace["Merged"],
      "Done"          -> WorkflowPlace["Done"]|>,
    "Transitions" -> <|
      "Distribute" -> WorkflowTransition["Distribute",
        "InputArcs"  -> {<|"Place" -> "Source", "Multiplicity" -> 1|>},
        "OutputArcs" -> {
          <|"Place" -> "PoolOpus",    "Multiplicity" -> 1, "TokenKind" -> "Task"|>,
          <|"Place" -> "PoolChatGPT", "Multiplicity" -> 1, "TokenKind" -> "Task"|>},
        "Executor" -> "PureFunction",
        "RuntimeSpec" -> <|"Handler" -> distributeHandler|>],
      "WorkerOpus" -> WorkflowTransition["WorkerOpus",
        "InputArcs"  -> {<|"Place" -> "PoolOpus", "Multiplicity" -> 1|>},
        "OutputArcs" -> {<|"Place" -> "ResultOpus", "Multiplicity" -> 1, "TokenKind" -> "Result"|>},
        "Executor" -> "PureFunction",
        "RuntimeSpec" -> <|"Handler" -> opusReviewer|>],
      "WorkerChatGPT" -> WorkflowTransition["WorkerChatGPT",
        "InputArcs"  -> {<|"Place" -> "PoolChatGPT", "Multiplicity" -> 1|>},
        "OutputArcs" -> {<|"Place" -> "ResultChatGPT", "Multiplicity" -> 1, "TokenKind" -> "Result"|>},
        "Executor" -> "PureFunction",
        "RuntimeSpec" -> <|"Handler" -> chatgptReviewer|>],
      "Merge" -> WorkflowTransition["Merge",
        "InputArcs"  -> {
          <|"Place" -> "ResultOpus",    "Multiplicity" -> 1|>,    (* AND-merge: BOTH places *)
          <|"Place" -> "ResultChatGPT", "Multiplicity" -> 1|>},   (* must have a token *)
        "OutputArcs" -> {<|"Place" -> "Merged", "Multiplicity" -> 1, "TokenKind" -> "Result"|>},
        "Executor" -> "PureFunction",
        "RuntimeSpec" -> <|"Handler" -> mergeHandler|>],
      "Finalize" -> WorkflowTransition["Finalize",
        "InputArcs"  -> {<|"Place" -> "Merged", "Multiplicity" -> 1|>},
        "OutputArcs" -> {<|"Place" -> "Done", "Multiplicity" -> 1, "TokenKind" -> "Result"|>},
        "Executor" -> "PureFunction",
        "RuntimeSpec" -> <|"Handler" -> finalizeHandler|>]|>];

If WorkerChatGPT fails (returns $Failed), the ResultChatGPT Place stays empty.
Merge requires both ResultOpus and ResultChatGPT. The workflow correctly
deadlocks at Merge with only one input present, signaling incomplete peer
review. Inspect via plotPetriNet[wid] / traceTransitions[wid].
