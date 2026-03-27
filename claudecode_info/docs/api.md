# claudecode — API Reference

Package: `ClaudeCode``
Requires: NBAccess, GitHubREST (github.wl)
Load: `Needs["ClaudeCode`", "claudecode.wl"]`

## Global Variables

### $ClaudeModel
型: String, 初期値: ""
Model name passed to Claude CLI. "" uses Claude Code's default. Example: `$ClaudeModel = "claude-opus-4-6"`

### $ClaudePrivateModel
型: List, 初期値: {provider, modelName, url}
Local model for private data tasks. Used when AutoPrivate->True and task accesses confidential variables.
Example: `$ClaudePrivateModel = {"lmstudio", "openai/gpt-oss-20b", "http://127.0.0.1:1234"}`

### $ClaudeTestModel
型: String, 初期値: $ClaudeModel
Model for separation checks and objective testing. Can differ from $ClaudeModel.

### $ClaudeTimeout
型: Numeric, 初期値: 1200
Timeout seconds for ClaudeQuery/ClaudeEval.

### $ClaudeWorkingDirectory
型: String, 初期値: FileNameJoin[{$HomeDirectory, "Claude Working"}]
Working directory for Claude Code CLI. .claude/CLAUDE.md, .claude/rules/, .claude/skills/ under this dir are loaded.

### $ClaudeMDPath
型: String, 初期値: ""
Path to CLAUDE.md. Auto-detected or set manually.

### $ClaudeMDContent
型: String, 初期値: ""
Loaded CLAUDE.md content. Empty if not found.

### $ClaudeAccessibleDirs
型: List, 初期値: {$packageDirectory}
Directories granted Read permission to Claude Code. iPrepareClaudeProjectDirectory injects these into settings.json. First use of NotebookDirectory outside $packageDirectory triggers a dialog.
Example: `$ClaudeAccessibleDirs = {$packageDirectory, "F:\\Dropbox\\Mathematica-oneDrive"}`

### $ClaudeFallbackModels
型: List, 初期値: {{"anthropic", opus}, {"openai", "gpt-5"}}
Fallback model priority list. Each element: `{"provider", "modelName"}` or `{"provider", "modelName", "url"}`. Synced to NBAccess`NBSetFallbackModels.
Example: `$ClaudeFallbackModels = {{"anthropic","claude-opus-4-6"},{"lmstudio","gpt-oss-20b","http://127.0.0.1:1234"}}`

### $ClaudeDocModel
型: String, 初期値: latest Sonnet
Model for documentation generation. "" uses $ClaudeModel.
Example: `$ClaudeDocModel = "claude-sonnet-4-6"`

### $ClaudeDocRetryDelay
型: Numeric, 初期値: 60
Retry wait seconds for documentation generation.

### $ClaudeDocMaxRetries
型: Integer, 初期値: 3
Max retries for documentation generation.

### $ClaudeDocMaxChunkChars
型: Integer, 初期値: 60000
Max characters of source per prompt chunk.

### $ClaudeEvalMaxDepth
型: Integer, 初期値: 5
Max recursion depth for ClaudeEval generating nested ClaudeEval/ContinueEval calls. 0 disables recursion.

### $ClaudePackageKeywordMap
型: Association, 初期値: <||>
Packages register keywords here. When a prompt contains a keyword, the package's api.md is auto-injected as context. Each package registers on load; claudecode.wl itself is package-independent.
Example: `$ClaudePackageKeywordMap["maildb"] = {"メール", "mail", "〒切"}`

## Core Query Functions

### ClaudeQuery[prompt] → String
Send prompt to Claude Code CLI synchronously, return response string.
Options: `WebSearch->True` (free, default), `WebFetch->False` (paid, requires Fallback->True), `Fallback->False`, `Timeout->Automatic`
Multimodal: `ClaudeQuery[{text, Image[...], File[path], ...}]` — images/PDFs/audio sent directly to API.
`ClaudeQuery[session, prompt]` — uses session history and prior output/error as context.

### ClaudeQuerySync[prompt] → String
Lightweight synchronous query. No session history, no notebook writes. Shows elapsed time in WindowStatusArea.
Options: `Fallback->False`, `Model->Automatic`, `PrivacyLevel->Automatic`, `Timeout->Automatic`
Model routing: Model->Automatic + PrivacyLevel≤0.5 → Claude Code CLI; PrivacyLevel>0.5 → $ClaudePrivateModel.
`Model->{"provider","model"}` — use specified model via API.
例: `ClaudeQuerySync[prompt, PrivacyLevel->1.0]`
例: `ClaudeQuerySync[prompt, Model->{"anthropic","claude-sonnet-4-6"}]`

### ClaudeQueryAsync[prompt, callback, nb] → (async)
Send prompt asynchronously via Job system (NBBeginJobAtEvalCell). Calls `callback[responseString]` on completion. Does not block kernel.
Options: `Fallback->False`, `Model->Automatic`, `PrivacyLevel->Automatic`, `Timeout->Automatic`
例: `ClaudeQueryAsync["Hello", Print, EvaluationNotebook[]]`

### ClaudeWriteResponse[nb, text]
Expand markdown-formatted text as notebook cells. Converts headings, lists, code blocks to appropriate cell styles.
Options: `AutoEvaluate->False`
例: `ClaudeWriteResponse[EvaluationNotebook[], response, AutoEvaluate->True]`

### ClaudeMath[task] → String
Call Claude with Mathematica code generation-specialized prompt.

### ClaudeExtractCode[response] → String
Extract first ```mathematica block from Claude response.

### ClaudeExtractAllCode[response] → List
Extract all ```mathematica blocks from Claude response as list.

## Evaluation Functions

### ClaudeEval[task]
Generate and display code asynchronously, save history to default session.
`ClaudeEval[{text, data, ...}]` — mixed text, Dataset, Image, expressions.
`ClaudeEval[session, task]` — save to specified session.
Options:
- `AutoEvaluate->True` — auto-execute generated Input cells (default True)
- `StartTime->Now` — schedule execution; `StartTime->Now+Quantity[3,"Hours"]`
- `RepeatInterval->None` — repeat; `RepeatInterval->Quantity[2,"Hours"]` repeats every 2h; `{Quantity[1,"Hours"],5}` repeats up to 5 times hourly
- `Timeout->Automatic` — fallback API timeout seconds (Automatic = $iFallbackTimeout = 600)
- `Fallback->False`
Returns TaskObject; stop with `TaskRemove[]`.

### ContinueEval[session, instruction]
Continue in specified session. `ContinueEval[instruction]` uses default session. `ContinueEval[]` sends "エラーを修正してください" to default session.
Options: `StartTime->Now`, `Timeout->Automatic`, `Fallback->False`

### ContinueUpdate[]
Continue a ClaudeUpdatePackage task, applying bug fixes based on prior results.
`ContinueUpdate["instruction"]` — with additional instructions.
`ContinueUpdate["pkgName", "instruction"]` — for specified package's last update.
Options: `Fallback->False`, `"UpdateApiMd"->True`, `StartTime->Now`
例: `ContinueUpdate["上半円の境界線が欠けているので修正して"]`

## Session Management

### CreateClaudeSession["name"] → session
Create named session (inherits default history). `CreateClaudeSession[session]` inherits from existing session. `CreateClaudeSession[]` inherits default. `CreateClaudeSession[Inherit->False]` creates independent session.

### ClaudeRestoreSession[]
Restore default session. `ClaudeRestoreSession["name"]` restores named session.

### ClaudeListSessions[]
Display all sessions in current notebook.

### ClaudeDeleteSession["name"]
Delete named session. `ClaudeDeleteSession["name", "All"]` deletes session and all its history.

### ClaudeShowHistory[] / ClaudeShowHistory[session] / ClaudeShowHistory["name"]
Display session history.

### ClaudeCompactHistory[] / ClaudeCompactHistory[name]
Manually compact session history. Auto-triggered when entries exceed 2n+1+w.

### ClaudeHistorySize[] → Association
Diagnose session history size. Returns `<|"Entries"->n, "ByteCount"->n, "KiloBytes"->n, "Status"->...|>`. >200KB recommends compaction; >500KB is critical.

## Attachments

### ClaudeAttach[path] / ClaudeAttach[session, path]
Attach reference file to default or specified session. Attached files are auto-Read during ClaudeQuery/ClaudeEval.

### ClaudeDetach[path] / ClaudeDetach[session, path]
Remove attachment from session.

### ClaudeAttachments[] / ClaudeAttachments[session] → List
Return attachment list for default or specified session.

### ClearAttachments[] / ClearAttachments[session]
Clear all attachments from default or specified session.

## Package Operations

### ClaudeCreatePackage[name, prompt]
Create new `name.wl` in $packageDirectory per prompt spec.

### ClaudeUpdatePackage[packageName, prompt]
Update `packageName.wl` in $packageDirectory with Claude assistance. Auto-creates backup, diff-updates, validates, reloads.
`prompt`: String or `{String, Image, File["path.pdf"], ...}`
Options:
- `TargetFunctions->Automatic` — limit scope to specific functions
- `StartTime->Now` — scheduled start
- `Fallback->False`
- `"UpdateApiMd"->Automatic` — auto-update api.md after change (Automatic = True); False to skip
例: `ClaudeUpdatePackage["pkg", "修正指示", StartTime->Now+Quantity[1,"Hours"]]`

### ClaudeRestorePackage[packageName]
Restore previous backup of packageName.

### ClaudeConvertToPaclet[packageName]
Convert $packageDirectory/packageName.wl to Paclet format. Creates packageName/ folder with Kernel/, Documentation/, PacletInfo.wl. Original .wl is deleted after backup.

### ClaudeUpdatePackageHistory[] → List
Show/return all packages' ClaudeUpdatePackage call history. `ClaudeUpdatePackageHistory[packageName]` — specified package only. Each entry: `<|"Package"->..., "Timestamp"->..., "Directory"->...|>`

### ClaudeBackupDataset[packageName] / ClaudeBackupDataset[]
Show backup history as Grid with Review/Pull/Delete buttons. Review inspects backup content, Pull restores, Delete removes that history entry.

### ClaudeMigrateBackupHistory[packageName]
Convert raw .wl backups in history to compressed diff format (.wl.cz/.wl.cdiff) to reduce storage.
`ClaudeMigrateBackupHistory[packageName, DryRun->True]` — preview savings without deleting.
`ClaudeMigrateBackupHistory[]` — apply to all packages.

## Documentation Generation

### ClaudeCreateDocumentation["packageName"]
Auto-generate full documentation set for packageName.wl or packageName/ Paclet using Claude.
Single .wl → output to `$packageDirectory/packageName_info/docs/`
Paclet → output to `$packageDirectory/packageName/docs/`
Stops automatically at limit; re-run to continue with ungenerated files only.

### ClaudeUpdateDocumentation["packageName"] / ClaudeUpdateDocumentation["packageName", "instruction"]
Auto-update all docs based on source diff, or apply instruction. Can reference notebook context.
Options:
- `TargetFiles->Automatic` — auto-detect; `{"api.md"}` to restrict to specific files
- `Mode->"Update"` — update existing (default); `"Create"` — create new
例: `ClaudeUpdateDocumentation["claudecode", "api.mdのみ更新して"]`
例: `ClaudeUpdateDocumentation["pkg", "...", TargetFiles->{"api.md"}]`

## Directives Management

### ClaudeAddDirective[target, description]
Format description with Claude and append to Claude Directives folder file, then run InstallClaudeDirectives[]. Source file is auto-backed up.
`target`: "CLAUDE.md" or skill name (e.g., "wolfram-general")

### ClaudeRestoreDirective[target]
Restore previous backup of target directive and run InstallClaudeDirectives[].

### ClaudeListDirectives[]
Display CLAUDE.md and all skills in Claude Directives folder.

### ClaudeUpdateDirective[] / ClaudeUpdateDirective[text]
Check source code/directives consistency and auto-fix inconsistencies. With text: interpret and reflect in CLAUDE.md/rules/skills. Can reference notebook context.

### ClaudeDirectiveBackupDataset[]
Show directives update history as Grid with Review/Pull/Delete buttons.

### ClaudeSyncDirectives[dir]
Compare dir against Claude Directives folder; overwrite with newer files from dir. Files only in dir are copied; files only in Claude Directives remain untouched.
例: `ClaudeSyncDirectives["C:\\Users\\user\\Claude Directives"]`

## Confidential Data Handling

### MarkConfidential[] / MarkConfidential[cell]
Mark current or specified cell as confidential. Marked cells are excluded from ClaudeEval/ClaudeQuery prompts.

### UnmarkConfidential[] / UnmarkConfidential[cell]
Remove confidential mark from current or specified cell.

### IsConfidential[] / IsConfidential[cell] → True|False
Return whether current or specified cell is marked confidential.

### Confidential[expr]
Evaluate expr, then auto-mark its Input/Output cells as confidential.
例: `Confidential[secretData = Import["secret.csv"]]`

### NonConfidential[expr]
Evaluate expr and explicitly unmark its Input/Output cells. Works even for expressions dependent on confidential variables.
例: `result = NonConfidential[Mean[secretData]]`

### ScanConfidentialCells[]
Scan all notebook cells and auto-mark cells referencing confidential variables. Cells explicitly UnmarkConfidential'd are skipped.

## Specification and Review

### ClaudeSpec["task"] / ClaudeSpec[{text, image, ...}]
Generate program specification from notebook contents. Supports image attachments. Callable from palette via cell selection.

### ClaudeDebug[codeOrFile, errorMsg]
Request debug assistance asynchronously (returns immediately).

### ClaudeReview[codeOrFile]
Async code review. Auto-chunks if >30000 chars.

### ClaudeReviewChunked[codeOrFile]
Async code review with explicit chunked file processing.

## Web Tools

### ClaudeWebSearch[query] → String
Execute web search via Anthropic API web_search tool; return text results.

### ClaudeWebFetch[url] → String
Fetch URL content, summarize/extract, return as text.
`ClaudeWebFetch[url, prompt]` — apply prompt instruction to fetched content.

## Status and Control

### ClaudeStatus[]
Show real-time status of all running Claude tasks: elapsed time, current state (thinking/generating/tool), text chunk count, thought count, tool use count.

### ClaudeAbort[]
Stop all running Claude tasks: force-terminate Claude Code processes, stop ScheduledTasks, cancel fallback tasks. Also callable from palette "実行停止" button.

### ClaudeSessionStatus[] / ClaudeSessionStatus[name]
Display session state including accessible directories, attachments, working directory files.

### ClaudeQueryShowContext[]
Debug: display the notebook context that the next ClaudeQuery will send.

### ClaudeShowAccessConfig[]
Debug: display Claude Code file access config — $ClaudeAccessibleDirs, NBGetAccessibleDirs[], generated settings.json, CLI flags.

### ShowClaudePalette[]
Display Claude Code operation palette.

### ClaudeCommand["/command"] → String
Execute Claude Code CLI slash command or subcommand. Slash commands (/…) sent via node-pty in interactive mode; CLI subcommands (e.g., `config list`) executed directly.
例: `ClaudeCommand["/help"]`, `ClaudeCommand["/permissions"]`, `ClaudeCommand["config list"]`, `ClaudeCommand["--version"]`

## Separation Validation

### ClaudeCheckSeparation[target] → List
List violations of NBAccess separation principle in target code. Uses $ClaudeTestModel. Static scan + LLM judgment.
`target`: file path | .wl name in $packageDirectory | Paclet name
Checks: (a) SystemCredential direct use, (b) CellObject direct manipulation, (c) CellEpilog/CellProlog/NotebookEventActions direct ops, (d) NBAccess`Private` calls, (e) NBAccess public global direct updates, (f) EvaluationCell[]/CellPrint[]/SetSelectedNotebook[] direct use, (g) TaggingRules/CellTags/CellEpilog direct access via CurrentValue/SetOptions, (h) CellObject API/return-value/state leaks, (i) SelectionEvaluate/FrontEndTokenExecute FE state ops, (j) destructive NBAccess global updates (AppendTo/AssociateTo etc.)
例: `ClaudeCheckSeparation["claudecode"]`

### ClaudeFixSeparation[target]
Fix separation violations. File path target: backup + fix in-place. Package name target: call ClaudeUpdatePackage. Reuses prior ClaudeCheckSeparation results if available.

## Commit Preparation

### ClaudePrepareCommit[packageName]
Collect changes since last GitHub commit from backup history, generate commit message, output GitHubRefreshAndCommit command as Input cell.
`ClaudePrepareCommit[packageName, subject]` — specify first line; body auto-collected.
Options: `Fallback->False`, `DryRun->False`, `Owner->Automatic`, `Repository->Automatic`, `Branch->Automatic`, `BaseBranch->Automatic`
`DryRun->True` — return message only, no command output.

## LLMGraph — DAG-Based Call Tracking

### NotebookLLMGraph[nb] → Graph
Return LLMGraph for notebook nb. Creates new if not exists.

### NotebookLLMGraphPlot[nb]
Visualize LLMGraph at top level (Orchestrator nodes only), color-coded by access level.

### NotebookLLMGraphBuild[nb]
Reconstruct LLMGraph from existing session history entries.

### NotebookLLMGraphNodes[nb] → Association
Return all LLMGraph nodes as Association.

### NotebookLLMGraphValidate[nb]
Validate LLMGraph integrity: check entry/node count consistency, edge integrity.

### NotebookLLMGraphFetchResponse[nb, nodeID] → String|Missing
Fetch full response text for nodeID from external cache. Returns `Missing["CacheExpired"]` if not cached.

### NotebookLLMGraphSubSteps[nb, nodeID]
Display internal sub-step history for nodeID. Records ClaudeUpdatePackage internal phases: read-source, llm-query, merge, validate, reload.

### NotebookLLMGraphFetchL2[nb, nodeID] → Graph|Missing
Fetch L2 computation graph generated by L1 node nodeID (code block execution states, errors, dependencies). Returns `Missing["CacheExpired"]` if not cached.

### NotebookLLMGraphErrors[nb] → Dataset
Return nodes where L2ErrorCount>0 or Status="Failed" as Dataset. Used for identifying/debugging failed L1 nodes.

### NotebookLLMGraphUpdateL2Status[nb, l1NodeID, l2NodeID, status, msg]
Manually update L2 node status. `status`: "Completed"|"Failed"|"Pending"

### NotebookLLMGraphPlotL2[nb, l1NodeID]
Visualize L2 computation graph for code blocks generated by l1NodeID. Nodes color-coded by Status.

### NotebookLLMGraphRerun[nb, nodeID]
Re-execute specified L1 node and set Invalidated flag on downstream nodes.
Options: `Model`, `CascadeInvalidate`(True), `DryRun`(False)

### NotebookLLMGraphInvalidateDownstream[nb, nodeID]
Mark all nodes downstream of nodeID as Invalidated.

### NotebookLLMGraphSummary[nb]
Display summary statistics of LLMGraph (node counts, status distribution, error counts).

### NotebookLLMGraphExtractThread[nb, nodeID] → List
Extract conversation thread leading to nodeID as ordered list of history entries.

### NotebookLLMGraphApplyThread[nb, thread]
Apply extracted thread to rebuild session history for replay or analysis.

## LLM Graph Execution

### LLMGraphExecute[nb, graph] → TaskObject
Execute LLMGraph respecting DAG dependencies. Returns TaskObject.

### LLMGraphExecuteStatus[nb] → Association
Return current execution status of running LLMGraphExecute.

### LLMGraphExecuteCancel[nb]
Cancel running LLMGraphExecute task.

## File Processing

### NBFileTranslate[file, opts]
Translate/process file content with Claude assistance.

### ClaudeProcessFile[file, opts]
Process file with Claude using configurable instructions.

## Option Symbols

### Fallback
Option for ClaudeQuery/ClaudeEval/ContinueEval/ClaudeUpdatePackage/ClaudePrepareCommit.
`True`: auto-switch to fallback model ($ClaudeFallbackModels) when Claude Code CLI unavailable, filtered by access level.
`False` (default): return error as-is.

### WebSearch
Option for ClaudeQuery/ClaudeEval. `True` (default): permit Claude Code CLI's built-in web search (free). `False`: disable. Different from WebFetch (paid).

### WebFetch
Option for ClaudeQuery/ClaudeEval. `True`: force web fetch. `False` (ClaudeQuery default): no web fetch. `Automatic` (ClaudeEval default): Claude decides. Requires `Fallback->True`. Paid via Anthropic API.

### AutoEvaluate
Option for ClaudeEval/ClaudeWriteResponse. `True` (default for ClaudeEval): auto-execute generated Input cells.

### StartTime
Option for ClaudeEval/ContinueEval/ClaudeUpdatePackage/ContinueUpdate. Schedule execution start as DateObject.
例: `StartTime->Now+Quantity[3,"Hours"]`

### RepeatInterval
Option for ClaudeEval. `None` (default): no repeat. `Quantity[n, unit]`: repeat every interval. `{Quantity[n, unit], maxCount}`: repeat with limit.

### Timeout
Option for ClaudeQuerySync/ClaudeQueryAsync/ClaudeEval/ContinueEval. `Automatic` uses $iFallbackTimeout (600s for fallback path).

### TargetFunctions
Option for ClaudeUpdatePackage. `Automatic`: update entire package. List of function names: limit scope.

### TargetFiles
Option for ClaudeUpdateDocumentation. `Automatic`: auto-detect changed files. List of filenames: restrict to those files.

### Mode
Option for ClaudeUpdateDocumentation. `"Update"` (default): update existing docs. `"Create"`: create new docs.

### DryRun
Option for ClaudeMigrateBackupHistory/ClaudePrepareCommit. `True`: preview only, no changes.

### Inherit
Option for CreateClaudeSession. `True` (default): inherit history from current/default session. `False`: independent session.

### References
Option for ClaudeCreateDocumentation/ClaudeUpdateDocumentation. List of URLs or book titles to add as References section in README.md.

### Demos
Option for ClaudeCreateDocumentation/ClaudeUpdateDocumentation. List of demo video/notebook URLs to include in README.md.

### Disclaimer
Option for ClaudeCreateDocumentation/ClaudeUpdateDocumentation. List of disclaimer strings to add to README.md disclaimer section.

### Acknowledgments
Option for ClaudeCreateDocumentation/ClaudeUpdateDocumentation. List of acknowledgment strings; placed before disclaimer in README.md.

### License
Option for ClaudeCreateDocumentation/ClaudeUpdateDocumentation. `""` (default): auto-insert MIT if GitHubREST`$GitHubLicenseHolder is non-empty. String: use as license text verbatim.

### Owner / Repository / Branch / BaseBranch
Options for ClaudePrepareCommit. `Automatic`: infer from GitHubREST config. Override with explicit strings.

### PrivacySpec
Option for ClaudeQuerySync/ClaudeQueryAsync. `Automatic`: auto-determine privacy handling.