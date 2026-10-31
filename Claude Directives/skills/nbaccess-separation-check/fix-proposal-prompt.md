You are fixing NBAccess separation-principle violations in ONE top-level definition block of a Wolfram Language package.
The block below was cut out of the file {{FILE}} (lines {{START_LINE}}-{{END_LINE}}). Only this block will be replaced by your answer.

RULES
- Replace direct notebook / cell / front-end operations with the NBAccess public API (call it as NBAccess`NBxxx[...]).
- Keep every definition that is in the block: the same function names, the same argument patterns, the same options and the same return values. Do not add or remove definitions. Do not rename anything.
- Do NOT change any "AccessLevel" or "PrivacyLevel" value, and do not add new ones. Access and privacy levels are a security decision made by a human.
- Do not touch code that is not related to the listed violations. Keep comments, indentation and \:XXXX escapes as they are.
- If a violation is a false positive (the text is inside a string or a comment, or it already calls an NBAccess`NB... function), leave that line unchanged.
- If you cannot fix the block safely with the existing NBAccess API, answer with the single line NO_SAFE_FIX followed by one short paragraph explaining what API is missing.

REPLACEMENT GUIDE
- NotebookWrite[nb, ...] -> NBAccess`NBWriteCell[nb, ...]
- NotebookRead[...] -> NBAccess`NBCellRead[nb, idx]
- CellPrint[...] -> NBAccess`NBWriteCell[nb, ...] or NBAccess`NBWritePrintNotice[nb, ...]
- EvaluationCell[] -> NBAccess`NBBeginJobAtEvalCell or NBAccess`NBWriteAnchorAfterEvalCell
- ParentNotebook[EvaluationCell[]] -> NBAccess`NBParentNotebookOfCurrentCell[]
- SelectionMove[...] -> NBAccess`NBMoveAfterCell[nb, idx]
- SelectionEvaluate[nb] -> NBAccess`NBEvaluatePreviousCell[nb] or NBAccess`NBInsertAndEvaluateInput[nb, ...]
- Cells[nb, CellTags -> tag] -> NBAccess`NBCellIndicesByTag[nb, tag]
- Cells[nb, CellStyle -> style] -> NBAccess`NBCellIndicesByStyle[nb, style]
- CurrentValue[cell, {TaggingRules, ...}] -> NBAccess`NBCellGetTaggingRule[nb, idx, path]
- SetOptions[cell, TaggingRules -> ...] -> NBAccess`NBCellSetOptions[nb, idx, opts]
- CellEpilog / CellProlog / NotebookEventActions manipulation -> NBAccess`NBInstallCellEpilog / NBAccess`NBInstallConfidentialEpilog
- AppendTo / AssociateTo / Unset on NBAccess` globals -> setter APIs such as NBAccess`NBRegisterConfidentialVar, NBAccess`NBSetConfidentialVars
- SystemCredential[...] -> NBAccess`NBGetAPIKey[provider] (or NBAccess`NBGetCredential)
- Import[path, "Notebook"] / NotebookImport / NotebookGet / NotebookOpen on a user notebook (PRIV-NB-READ) ->
  NBAccess`NBFileOpen + NBAccess`NBFileReadAllCells / NBAccess`NBFileReadCellsInRange (+ NBAccess`NBFileClose),
  or NBAccess`NBReadHeader / NBAccess`NBReadTodos for header and todo data
- Export[path, Notebook[...]] or Export[path, nb, "NB"] (PRIV-NB-WRITE) -> NBAccess`NBFileWriteAllCells + NBAccess`NBFileSave
- LLMSynthesize[prompt] / LLMFunction (PRIV-LLM-CHANNEL) -> ClaudeCode`ClaudeQuerySync[prompt]
  (keep the router's automatic model and privacy choice; do not add a PrivacyLevel or Model option yourself)

VIOLATIONS FOUND IN THIS BLOCK (line numbers are file line numbers)
{{VIOLATIONS}}

NBACCESS DOCUMENTATION (excerpt, for reference)
{{NBACCESS_DOCS}}

OUTPUT FORMAT
Return the complete corrected block in ONE code fence that starts with ```wl and nothing else, or the NO_SAFE_FIX line described above.

=== BLOCK ===
{{BLOCK}}
