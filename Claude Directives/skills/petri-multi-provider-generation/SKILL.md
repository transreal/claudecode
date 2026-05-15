---
name: petri-multi-provider-generation
description: petri_from_prompt 系で複数 LLM プロバイダ (Claude / ChatGPT / 各種ローカル LLM 等) を並列に使う Petri net を生成するときの handler I/O 規約と Provider/Model 指定ルール。`AddProviderSupportToPetriPrompt[]` 経由で `$petriNetGuide` に注入される。LLM が petri net コードを書く際に参照する仕様書。
---

<!--
このファイルは LLM 生成プロンプトの一部としてそのまま `$petriNetGuide` に
連結される。`.wl` から `iReadSkillBody["petri-multi-provider-generation"]`
で frontmatter を除いた本文 (この HTML コメント以降) が読み込まれる。

コードブロック内の Mathematica 例も生成プロンプトの一部。改変時は
petri_from_prompt_chatgpt.wl の `parsePetriCode` がパース可能な形を保つこと。
-->

# Source token Payload convention (CRITICAL)

The user submits a token to the SourcePlace via ClaudeSubmitToken. The
submitted token's Payload contains application-specific keys that the
FIRST worker(s) must read. UNLESS the goal explicitly specifies otherwise,
ASSUME the Payload has a single key named EXACTLY "Text" with the input
text:

  ClaudeSubmitToken[wid,
    WorkflowToken["Kind" -> "Task", "Payload" -> <|"Text" -> "..."|>],
    "Source"]

So the FIRST worker / Distribute handler should read:
  inputText = Lookup[binding[["Source", "Payload"]], "Text", ""]

DO NOT invent unrelated key names like "Plan" or "Input" or "Data" for
the Source token's Payload. The convention is "Text".

If the goal explicitly mentions different input keys (e.g. "the token has
keys X, Y, Z"), use those. Otherwise: "Text".

# Provider selection for LLM calls

When the user goal involves multiple LLM providers (e.g. "Claude Opus と
ChatGPT で並列レビュー", "Claude Sonnet と Claude Opus で多視点レビュー")
each worker handler MUST specify the Model option to ClaudeQueryBg.

Use ClaudeCode`ClaudeQueryBg with the Model option to route a particular
worker to a particular provider/model.

**Paid-API permission is governed by NBAccess (absolute truth).** The
notebook stores its paid-API permission state via NBAccess
(`NBGetNotebookPaidAPIAllowed[nb]`). The claudecode palette shows this state
as "Paid API: On/Off". If forbidden, the `ClaudeQueryBg[..., Model -> {...}]`
call returns a string starting with `"Error: このノートブックでは課金 API ..."`,
which the worker's `$Failed` guard (see P5 below) treats as a handler
failure. **Do NOT add `Fallback -> True` to bypass this** — it cannot bypass
NBAccess, and adding it gives the false impression that the worker handles
its own paid-API authorization.

**IMPORTANT: The model names below use placeholders like `<claudecode-heavy>`,
`<anthropic-heavy>`, `<openai-heavy>`, `<lmstudio-default>`. At prompt-build
time, the .wl side substitutes them with the canonical model names that are
CURRENTLY registered in `$ClaudeModelCapabilities`. You will see the resolved
names in the actual prompt you receive. Treat the resolved names as
authoritative and copy them verbatim into your generated code.**

**Phase 28 (2026-05-12): provider names are now distinguished as follows:**

- `claudecode` — Anthropic Claude via Claude Code CLI (covered by Pro/Max
  subscription, **no per-call billing**). Use for default Anthropic usage.
- `anthropic`  — Anthropic API direct call (**billed per token**). Only use
  if the user has explicitly enabled paid API for this notebook.
- `openai`     — OpenAI API direct call (**billed per token**). Same as above.
- `lmstudio`   — LM Studio local LLM (**no billing**, runs on the user's machine).

  (* Claude Opus 経由 (Anthropic CLI, 課金なし) *)
  review = ClaudeCode`ClaudeQueryBg[
    "Review for correctness: " <> text,
    Model -> {"claudecode", "<claudecode-heavy>"}];

  (* Claude Opus 経由 (Anthropic API 直接, 課金あり) *)
  review = ClaudeCode`ClaudeQueryBg[
    "Review for correctness: " <> text,
    Model -> {"anthropic", "<anthropic-heavy>"}];

  (* OpenAI ChatGPT 経由 (課金 API) *)
  review = ClaudeCode`ClaudeQueryBg[
    "Review for correctness: " <> text,
    Model -> {"openai", "<openai-heavy>"}];

  (* LM Studio (ローカル LLM、課金なし) *)
  review = ClaudeCode`ClaudeQueryBg[
    "Review for correctness: " <> text,
    Model -> {"lmstudio", "<lmstudio-default>", "http://127.0.0.1:1234"}];

**Default recommendation for multi-provider review tasks:** Use
`{"claudecode", "<claudecode-heavy>"}` for Claude-side review (no billing)
and `{"openai", "<openai-heavy>"}` for ChatGPT-side review (requires user's
explicit paid-API permission). This gives 2-system comparison without
double-billing on the Anthropic side.

# CRITICAL rules for multi-provider Petri Nets

(P0) DO NOT MODIFY THE MODEL STRINGS YOU RECEIVE in the actual prompt.
     The names you see (after placeholder substitution) come from the
     canonical capability table ($ClaudeModelCapabilities) at runtime
     and are guaranteed valid for this environment.

     DO NOT replace them with other model names based on your training-time
     knowledge. Your priors about which model names are "actually
     available" are NOT authoritative for this environment. The
     canonical table is the source of truth, not your priors.

     If a model is unavailable at runtime, the runtime layer will resolve
     a fallback by Class. Your job is to specify the user's *intent*
     (Claude vs ChatGPT vs local), NOT to second-guess version numbers.

     Concrete examples of FORBIDDEN rewrites:
       BAD : substituting your own version number guess (e.g.
             rewriting whatever model name you received into
             "gpt-4.5-preview", "gpt-4o", "claude-3-opus", etc.)
     GOOD : copy the model name verbatim from this prompt to your code.

(P1) Use ONLY ClaudeCode`ClaudeQueryBg with Model option, NOT separate
     functions like OpenAI`Query, ChatGPT`Query, etc. Those are NOT defined.

(P2) Each parallel worker handler should pin its Model option so that
     "opusWorker" actually uses Claude Opus and "chatgptWorker" actually
     uses ChatGPT, even if the global default differs.

(P3) Provider name is lowercase string. Common values:
     "anthropic" (Claude), "openai" (ChatGPT), "lmstudio" (local),
     "claudecode" (CLI default).

(P4) DO NOT specify `Fallback -> True` in your generated code. The paid-API
     permission is governed by the notebook's NBAccess setting (which is
     `absolute truth`, see palette "Paid API: On/Off"). If the user has
     allowed paid API for this notebook, `ClaudeQueryBg` with `Model -> {...}`
     will route to the chosen provider; if forbidden, the call returns an
     `"Error: ..."` string and your `$Failed` guard (P5) will handle it
     cleanly. Adding `Fallback -> True` does NOT bypass NBAccess.

(P5) **MANDATORY: Treat LLM error responses as handler failures.** API
     errors come back as plain strings starting with "Error:" (e.g.
     "Error: model: gpt-5"). If you store such a string in the output
     Payload (e.g. "ReviewChatGPT" -> "Error: model: gpt-5"), the
     workflow will report Success even though the LLM call failed.

     Every worker handler MUST check the LLM response and return $Failed
     if it is an error string. Use this idiom:

       review = ClaudeCode`ClaudeQueryBg[..., Model -> {...}, ...];
       If[StringQ[review] && StringStartsQ[review, "Error:"],
         Return[$Failed, Module]];   (* let the workflow handle failure *)

     Or better, use the helper provided by petri_from_prompt_chatgpt.wl:

       review = checkLLMResponse[ClaudeCode`ClaudeQueryBg[..., Model -> {...}, ...]];
       (* checkLLMResponse returns the response if OK, $Failed if it is an error *)

# Worker handler I/O convention (MANDATORY for multi-provider review nets)

# Choosing AND-merge vs XOR-merge

When combining the outputs of multiple parallel workers (peer review,
ensemble, multi-perspective analysis), the merge transition MUST use
**AND-merge** (synchronization) so that ALL reviewers' outputs are required
before the workflow proceeds. A XOR-merge — where the merge fires as soon as
ONE worker delivers a token — is incorrect for peer review and silently
hides reviewer failures.

The detailed AND/XOR design guide is in skill `petri-and-xor-merge`. Its
key points:

- **AND-merge Pattern A (recommended)**: each worker writes to its own
  dedicated output Place, and the merge transition has multiple InputArcs
  (one per Place, each Multiplicity 1).
- **AND-merge Pattern B**: workers share one Place; the merge transition has
  ONE InputArc with Multiplicity = N.
- **XOR-merge** (one shared output Place + InputArc Multiplicity 1): only for
  redundancy / take-the-first patterns. Do NOT use for peer review.

If the user's goal mentions "両方のレビューを総合", "peer review",
"ensemble", "全部の reviewer の意見をまとめて", choose AND-merge.

# Choosing retry pattern

When the user requests "失敗したら N 回繰り返す" or "retry on failure" for
parallel reviewers, use **per-worker retry** (each Worker transition has
its own RetryPolicy or Trial counter). DO NOT route the retry trigger
downstream of the AND-merge (Verdict -> Retry -> {PoolOpus, PoolChatGPT})
because:

- AND-merge cannot fire if any worker failed → Verdict never receives a
  token → the downstream Retry transition is never enabled (the workflow
  is permanently stuck at Merge with no retry).
- The downstream pattern reruns successful workers too, doubling LLM cost.

The detailed retry design guide is in skill `petri-retry-patterns`. Its
recommended pattern (Pattern A): set `"RetryPolicy" -> <|"MaxRetries" -> N|>`
on each Worker transition. The engine will auto-retry that worker up to N+1
times via atomic firing rollback. Use Pattern B (explicit per-worker Retry
+ GiveUp transitions with Trial counters) only for fine control.

Reserve the downstream Verdict -> Retry pattern for **semantic** retry
("the merged review needs improvement, redo with different prompts"),
which is a different kind of failure from individual worker failure.

# THE GOLDEN RULE: NEVER NEST INPUT TOKENS INTO THE OUTPUT PAYLOAD

Every handler returns <|"Payload" -> outPayload|>. The outPayload MUST be a
FLAT Association of meaningful application keys (Text, ReviewOpus, Trial,
FinalResult, etc.).

NEVER do:
  <|"Payload" -> <|"PoolOpus" -> binding[["PoolOpus"]]|>|>      (* WRONG: nests the entire input token *)
  <|"Payload" -> <|"Source"   -> binding[["Source"]]|>|>        (* WRONG: nests Source *)
  <|"Payload" -> <|"ResultPool" -> binding[["ResultPool"]]|>|>   (* WRONG: nests Multiplicity-N input list *)

ALWAYS do:
  <|"Payload" -> Append[oldPayload, "NewKey" -> newValue]|>     (* RIGHT: flat, named keys *)

The reason: handler binding Place names ("PoolOpus", "Source", "ResultPool")
are INTERNAL transition wiring. The token Payload that flows through the net
must contain the application's domain data, not metadata about which Place
the token came from.

# Specific handler patterns

(W1) Read the input text from the Pool's Payload using Lookup with the
     "Text" key (or whatever input key the Source carries). Do NOT use
     "Plan" or other keys unless the upstream transition writes them.

(W2) Call ClaudeQueryBg with Model option pinning the provider/model.

(W3) Append a NEW key named exactly "Review" + ProviderTag to the output
     Payload. ProviderTag is the provider's short label:
       opusWorker      -> key "ReviewOpus"
       chatgptWorker   -> key "ReviewChatGPT"
       sonnetWorker    -> key "ReviewSonnet"
     Use Append[oldPayload, "ReviewXxx" -> review], NEVER nest the binding.

  CORRECT opusWorker:
    opusWorker[binding_] := Module[{p, text, review},
      p = binding[["PoolOpus", "Payload"]];   (* the FLAT incoming Payload *)
      text = Lookup[p, "Text", ""];
      review = checkLLMResponse @ ClaudeCode`ClaudeQueryBg[
        "Review correctness as Claude Opus (concise): " <> text,
        Model -> {"claudecode", "<claudecode-heavy>"}];
      If[review === $Failed, Return[$Failed, Module]];
      <|"Payload" -> Append[p, "ReviewOpus" -> review]|>];   (* FLAT output *)

  WRONG opusWorker (do NOT do this):
    opusWorker[binding_] := Module[{},
      <|"Payload" -> <|"PoolOpus" -> binding[["PoolOpus"]]|>|>]   (* nested, ChatGPT not called *)

# Distribute handler pattern (preserve the input flat, do NOT nest)

  distribute[binding_] := Module[{p},
    p = binding[["Source", "Payload"]];   (* flat Source Payload, e.g. <|"Text" -> ...|> *)
    <|"Payload" -> p|>];                  (* simply forward; outputs go to all OutputArc Places *)

  WRONG (do NOT do this):
    distribute[binding_] := Module[{},
      <|"Payload" -> <|"Source" -> binding[["Source"]]|>|>]    (* nests Source token *)

# Merge / Aggregate handler convention (MANDATORY)

The transition that joins parallel reviewer outputs is an AND-merge — see
the AND/XOR section above. Use Pattern A (dedicated output Places per
reviewer + multiple InputArcs) by default. The merge handler then receives
each reviewer's token by Place name, NOT a list.

  mergeHandler[binding_] := Module[{p1, p2, mergedText},
    p1 = binding[["ResultOpus",    "Payload"]];   (* flat Payload, single token *)
    p2 = binding[["ResultChatGPT", "Payload"]];   (* flat Payload, single token *)
    mergedText = Lookup[p1, "Text", Lookup[p2, "Text", ""]];
    <|"Payload" -> <|
       "Text"          -> mergedText,
       "ReviewOpus"    -> Lookup[p1, "ReviewOpus", ""],
       "ReviewChatGPT" -> Lookup[p2, "ReviewChatGPT", ""]
    |>|>];

If the workflow uses Pattern B (shared Place with Multiplicity = N), the
merge handler instead receives a list:

  mergeHandlerPatternB[binding_] := Module[{toks, payloads,
                                            opusReview, chatgptReview, mergedText},
    toks = binding[["ResultPool"]];           (* a List of N tokens *)
    payloads = toks[[All, "Payload"]];         (* List of N flat Payloads *)
    opusReview = SelectFirst[payloads,
                             KeyExistsQ[#, "ReviewOpus"] &, <||>];
    chatgptReview = SelectFirst[payloads,
                                KeyExistsQ[#, "ReviewChatGPT"] &, <||>];
    mergedText = Lookup[First[payloads], "Text", ""];
    <|"Payload" -> <|
       "Text"          -> mergedText,
       "ReviewOpus"    -> Lookup[opusReview, "ReviewOpus", ""],
       "ReviewChatGPT" -> Lookup[chatgptReview, "ReviewChatGPT", ""]
    |>|>];

NOTE: Pattern B with `SelectFirst[..., KeyExistsQ[#, "ReviewChatGPT"] &, <||>]`
silently substitutes empty if a reviewer is missing. With Pattern A and
proper AND-merge InputArcs, a missing reviewer makes the merge NOT fire
(deadlock at the merge Place), which is the correct semantic for peer
review.

  WRONG mergeHandler (any pattern):
    mergeHandler[binding_] := Module[{toks},
      toks = binding[["ResultPool"]];
      <|"Payload" -> <|"ResultPool" -> toks|>|>]   (* nests entire token list *)

# Finalize convention (MANDATORY: produce "FinalResult" key)

The Finalize transition adds the FinalResult key. Its value is itself an
Association whose keys are the named reviews:

  finalizeHandler[binding_] := Module[{p, finalReport},
    p = binding[["Merged", "Payload"]];
    finalReport = <|
      "ReviewOpus"    -> Lookup[p, "ReviewOpus", ""],
      "ReviewChatGPT" -> Lookup[p, "ReviewChatGPT", ""]
    |>;
    <|"Payload" -> Append[p, "FinalResult" -> finalReport]|>];

This way the user can retrieve results via:
  state = ClaudeWorkflowState[wid];
  doneTok = First[Select[Values[state[["Tokens"]]],
              KeyExistsQ[#[["Payload"]], "FinalResult"] &]];
  doneTok[["Payload", "FinalResult", "ReviewOpus"]]
  doneTok[["Payload", "FinalResult", "ReviewChatGPT"]]

# Self-check before finalizing your reply (CRITICAL)

Before emitting the closing ``` for the code block, mentally trace ONE token
through your net:

  1. Submit <|"Text" -> "hello"|> to Source.
  2. After Distribute: PoolOpus and PoolChatGPT each get a token whose
     Payload is <|"Text" -> "hello"|> (a flat Association, NOT
     <|"Source" -> ...|>).
  3. After WorkerOpus: ResultPool gets a token whose Payload is
     <|"Text" -> "hello", "ReviewOpus" -> "...llm response..."|>
     (flat, with ONE new key added).
  4. After WorkerChatGPT: ResultPool gets another token whose Payload is
     <|"Text" -> "hello", "ReviewChatGPT" -> "..."|>.
  5. After Merge: Merged gets ONE token whose Payload is
     <|"Text" -> "hello", "ReviewOpus" -> "...", "ReviewChatGPT" -> "..."|>.
  6. After Finalize: Done gets ONE token whose Payload contains
     "FinalResult" -> <|"ReviewOpus" -> "...", "ReviewChatGPT" -> "..."|>.

If at any step a Payload contains a key whose name matches a Place name
("PoolOpus", "Source", "ResultPool", "Merged"), the handler is BUGGY and
nesting input metadata. Fix it before emitting the code.

Also verify each worker has a $Failed guard around the LLM call (P5). Without
this guard, an API error like "Error: model: gpt-5" silently becomes the
review text and the workflow reports Success.

# Example: Claude Opus + ChatGPT parallel review

  opusReviewer[binding_] := Module[{p, text, review},
    p = binding[["PoolOpus", "Payload"]];
    text = Lookup[p, "Text", ""];
    review = checkLLMResponse @ ClaudeCode`ClaudeQueryBg[
      "Review correctness as Claude Opus (concise): " <> text,
      Model -> {"claudecode", "<claudecode-heavy>"}];
    If[review === $Failed, Return[$Failed, Module]];
    <|"Payload" -> Append[p, "ReviewOpus" -> review]|>];

  chatgptReviewer[binding_] := Module[{p, text, review},
    p = binding[["PoolChatGPT", "Payload"]];
    text = Lookup[p, "Text", ""];
    review = checkLLMResponse @ ClaudeCode`ClaudeQueryBg[
      "Review correctness as ChatGPT (concise): " <> text,
      Model -> {"openai", "<openai-heavy>"}];
    If[review === $Failed, Return[$Failed, Module]];
    <|"Payload" -> Append[p, "ReviewChatGPT" -> review]|>];
