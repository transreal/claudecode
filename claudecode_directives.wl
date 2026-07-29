(* ::Package:: *)

(* ClaudeDirectives.wl -- Directive Repository / Projection Layer
   
   Phase 33 (2026-04-25)
   Phase 28 (2026-05-12): $ClaudeModelCapabilities \:30b9\:30ad\:30fc\:30de\:5909\:66f4
     - \:30ad\:30fc\:3092 String \:304b\:3089 {provider, model} tuple \:306b\:5909\:66f4\:3002
     - \\\"Paid\\\" -> True|False \:30d5\:30a3\:30fc\:30eb\:30c9\:3092\:8ffd\:52a0\:3002
     - Anthropic CLI Opus (\\\"claudecode\\\" provider\\, Paid=False) \:3068
       Anthropic API Opus (\\\"anthropic\\\" provider\\, Paid=True) \:3092\:5225\:30e2\:30c7\:30eb\:3068\:3057\:3066\:4e21\:65b9\:767b\:9332\:3002
     - lm-studio -> lmstudio \:306b provider \:540d\:3092\:6b63\:898f\:5316\:3002
     - $ClaudeRoleDefaultModels \:306e\:5024\:3082 {provider, model} tuple \:306b\:5909\:66f4\:3002
     - ClaudeRegisterModelCapability \:306f tuple \:30ad\:30fc\:4e3b\:30fb String \:30ad\:30fc\:4e92\:63db\:306e\:4e21\:65b9\:3092 accept\:3002
   
   \:8cac\:52d9:
     1. .claude/CLAUDE.md, .claude/rules/, .claude/skills/ \:306e\:8aad\:307f\:8fbc\:307f\:30fb\:30d1\:30fc\:30b9\:30fb\:30ad\:30e3\:30c3\:30b7\:30e5
     2. \:30e2\:30c7\:30eb\:80fd\:529b\:30c6\:30fc\:30d6\:30eb ($ClaudeModelCapabilities) \:3068
        Role -> Default Model \:30de\:30c3\:30d4\:30f3\:30b0 ($ClaudeRoleDefaultModels) \:306e\:7ba1\:7406
     3. DirectiveBundle (\:4eca\:56de\:306e task / role / model \:306b\:4f7f\:3046 directive \:96c6\:5408) \:306e\:89e3\:6c7a
     4. PromptProjection (Full / Summary / Index / Lazy) \:306e\:751f\:6210
     5. Skill \:9078\:5225 (\:30ad\:30fc\:30ef\:30fc\:30c9 scoring)
   
   \:8a2d\:8a08\:4e0a\:306e\:4e0d\:5909\:6761\:4ef6:
     - \:30d5\:30a1\:30a4\:30eb\:5f62\:5f0f\:306f Claude Code \:4e92\:63db (.claude/CLAUDE.md/rules/skills) \:3092\:7dad\:6301
     - in-memory \:3067\:306e\:6295\:5f71\:3060\:3051\:3092 model size / role / task \:306b\:5fdc\:3058\:3066\:53ef\:5909\:306b\:3059\:308b
     - claudecode.wl / NBAccess.wl \:3078\:306e\:4e00\:5207\:306e\:4f9d\:5b58\:3092\:6301\:305f\:306a\:3044 (Rule 11 \[Section]3)
     - claudecode.wl \:5074\:304b\:3089\:3053\:306e\:30d1\:30c3\:30b1\:30fc\:30b8\:3092 optional \:306b\:547c\:3073\:51fa\:3059\:5f62\:3067\:7d71\:5408\:3059\:308b
   
   \:4f9d\:5b58:
     \:306a\:3057 (pure Wolfram Language)
   
   Load:
     Block[{$CharacterEncoding = "UTF-8"}, Get["ClaudeDirectives.wl"]]
   
   \:95a2\:9023\:4ed5\:69d8\:66f8:
     - claude_directives_spec_and_tasklist.md  (\:672c\:30d1\:30c3\:30b1\:30fc\:30b8\:306e\:57fa\:672c\:4ed5\:69d8)
     - claude_multi_agent_orchestration_spec.md (role \:6982\:5ff5\:306e\:51fa\:5178)
*)

BeginPackage["ClaudeDirectives`"];

(* \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550
   Public API
   \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550 *)

$ClaudeDirectivesVersion::usage =
  "$ClaudeDirectivesVersion \:306f\:30d1\:30c3\:30b1\:30fc\:30b8\:30d0\:30fc\:30b8\:30e7\:30f3\:6587\:5b57\:5217\:3002";

(* \[HorizontalLine] \:30e2\:30c7\:30eb\:80fd\:529b\:30c6\:30fc\:30d6\:30eb \[HorizontalLine] *)

$ClaudeModelCapabilities::usage =
  "$ClaudeModelCapabilities \:306f Association: {provider, model} -> <|\"ContextWindow\" -> Integer,\n" <>
  "  \"Class\" -> \"Heavy-Cloud\"|\"Heavy-Local\"|\"Mid-Local\"|\"Light-Cloud\"|\"Light-Local\",\n" <>
  "  \"DefaultMode\" -> \"Full\"|\"Summary\"|\"Index\"|\"Lazy\",\n" <>
  "  \"Strengths\" -> {\"Code\",\"Reasoning\",\"Search\",\"ToolUse\",...},\n" <>
  "  \"PreserveThinking\" -> True|False,\n" <>
  "  \"Paid\" -> True|False (\:8ab2\:91d1 API \:304b\:5426\:304b\:3001Phase 28 \:3067\:8ffd\:52a0)|>\n" <>
  "Phase 28 (2026-05-12): \:30ad\:30fc\:3092 String \:304b\:3089 {provider, model} tuple \:306b\:5909\:66f4\:3002\n" <>
  "Anthropic CLI Opus \:3068 Anthropic API Opus \:3092\:5225\:30e2\:30c7\:30eb\:3068\:3057\:3066\:4e21\:65b9\:767b\:9332\:3059\:308b\:305f\:3081\:3002\n" <>
  "provider \:540d: \\\"claudecode\\\" (CLI\:3001\:8ab2\:91d1\:306a\:3057), \\\"anthropic\\\" (API\:3001\:8ab2\:91d1), \n" <>
  "  \\\"openai\\\" (API\:3001\:8ab2\:91d1), \\\"lmstudio\\\" (\:30ed\:30fc\:30ab\:30eb\:3001\:8ab2\:91d1\:306a\:3057)\:3002";

$ClaudeRoleDefaultModels::usage =
  "$ClaudeRoleDefaultModels \:306f Role -> \:30e2\:30c7\:30eb\:540d \:306e\:30de\:30c3\:30d4\:30f3\:30b0\:3002\n" <>
  "ClaudeOrchestrator \:304c worker spawn \:6642\:306b\:53c2\:7167\:3059\:308b\:60f3\:5b9a\:3002";

(* \[HorizontalLine] v0.1.9: role-aware skill / mode \[HorizontalLine] *)

$ClaudeSkillRolePolicy::usage =
  "$ClaudeSkillRolePolicy \:306f Role -> {prefer skill name \:4e00\:89a7} \:306e\:30de\:30c3\:30d4\:30f3\:30b0\:3002\n" <>
  "iScoreSkill \:304c role \:5225\:306e\:512a\:5148 skill \:306b +6 \:52a0\:70b9\:3059\:308b\:3002Stage 1 v0.1.9 \:3067\:8ffd\:52a0\:3002";

$ClaudeRoleDefaultMode::usage =
  "$ClaudeRoleDefaultMode \:306f Role -> default Mode (\"Full\"|\"Summary\"|\"Index\"|\"Lazy\")\:3002\n" <>
  "ClaudeResolveDirectiveBundle \:3067 mode === Automatic \:306e\:3068\:304d\:512a\:5148\:63a1\:7528\:3002Stage 1 v0.1.9 \:3067\:8ffd\:52a0\:3002";

$ClaudeRoleMaxSkills::usage =
  "$ClaudeRoleMaxSkills \:306f Role -> default skill \:4e0a\:9650 (Integer)\:3002\n" <>
  "Options[ClaudeResolveDirectiveBundle] \:306e MaxSkills \:304c Automatic \:306e\:3068\:304d\:63a1\:7528\:3002Stage 1 v0.1.9 \:3067\:8ffd\:52a0\:3002";

ClaudeRegisterModelCapability::usage =
  "ClaudeRegisterModelCapability[name, spec] \:306f $ClaudeModelCapabilities \:306b\:30e2\:30c7\:30eb\:80fd\:529b\:3092\:8ffd\:52a0\:30fb\:66f4\:65b0\:3059\:308b\:3002";

ClaudeResolveModelCapability::usage =
  "ClaudeResolveModelCapability[modelName] \:306f\:30e2\:30c7\:30eb\:540d\:304b\:3089\:80fd\:529b Association \:3092\:8fd4\:3059\:3002\n" <>
  "\:672a\:767b\:9332\:306e\:5834\:5408\:306f\:4fdd\:5b88\:7684\:306a\:65e2\:5b9a\:5024 (ContextWindow 32000, DefaultMode \"Summary\") \:3092\:8fd4\:3059\:3002";

ClaudeResolveModelMode::usage =
  "ClaudeResolveModelMode[modelName] \:306f\:30e2\:30c7\:30eb\:540d\:304b\:3089\:65e2\:5b9a ProjectionMode \:3092\:8fd4\:3059\:3002";

ClaudeResolveModelContextWindow::usage =
  "ClaudeResolveModelContextWindow[modelName] \:306f\:30e2\:30c7\:30eb\:540d\:304b\:3089 ContextWindow (token \:6570) \:3092\:8fd4\:3059\:3002";

(* \[HorizontalLine] Directive Repository \[HorizontalLine] *)

$ClaudeDirectiveRepository::usage =
  "$ClaudeDirectiveRepository \:306f\:8aad\:307f\:8fbc\:307f\:6e08\:307f\:30ea\:30dd\:30b8\:30c8\:30ea\:306e\:30ad\:30e3\:30c3\:30b7\:30e5 Association\:3002\n" <>
  "<|\"Root\" -> path, \"ClaudeMD\" -> str, \"Rules\" -> {ruleAssoc...},\n" <>
  "  \"Skills\" -> {skillAssoc...}, \"LoadedAt\" -> AbsoluteTime|>";

ClaudeFindDirectiveRoots::usage =
  "ClaudeFindDirectiveRoots[] \:306f .claude / Claude Directives \:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:306e\:5019\:88dc\:3092\:63a2\:7d22\:3057\:3001\n" <>
  "\:5b9f\:5728\:3059\:308b\:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:306e\:30ea\:30b9\:30c8\:3092\:8fd4\:3059\:3002";

ClaudeLoadDirectiveRepository::usage =
  "ClaudeLoadDirectiveRepository[] \:306f\:81ea\:52d5\:63a2\:7d22\:3057\:305f\:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:304b\:3089\:8aad\:307f\:8fbc\:3080\:3002\n" <>
  "ClaudeLoadDirectiveRepository[root] \:306f\:6307\:5b9a\:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:304b\:3089\:8aad\:307f\:8fbc\:3080\:3002\n" <>
  "\:7d50\:679c\:306f $ClaudeDirectiveRepository \:306b\:30ad\:30e3\:30c3\:30b7\:30e5\:3055\:308c\:308b\:3002";

ClaudeInvalidateDirectiveCache::usage =
  "ClaudeInvalidateDirectiveCache[] \:306f $ClaudeDirectiveRepository \:3092\:7a7a\:306b\:3057\:3066\:518d\:8aad\:8fbc\:3092\:5f37\:5236\:3059\:308b\:3002";

(* \[HorizontalLine] Bundle / Projection \[HorizontalLine] *)

ClaudeResolveDirectiveBundle::usage =
  "ClaudeResolveDirectiveBundle[opts] \:306f task / role / model \:306b\:5fdc\:3058\:305f\n" <>
  "directive bundle \:3092\:8fd4\:3059\:3002opts:\n" <>
  "  \"Role\" -> \"Plan\"|\"Draft\"|\"Verify\"|\"Commit\"|\"Explore\"|\"Reduce\"|None\n" <>
  "  \"Model\" -> \:30e2\:30c7\:30eb\:540d (capability \:30c6\:30fc\:30d6\:30eb\:53c2\:7167\:30ad\:30fc)\n" <>
  "  \"Mode\"  -> \"Full\"|\"Summary\"|\"Index\"|\"Lazy\"|Automatic\n" <>
  "  \"TaskHint\" -> \:30d7\:30ed\:30f3\:30d7\:30c8\:6587\:5b57\:5217 (skill \:9078\:5225\:306b\:4f7f\:7528)\n" <>
  "  \"TokenBudget\" -> Integer | Automatic\n" <>
  "\:623b\:308a\:5024: <|\"ClaudeMD\"->...,\"ActiveRules\"->...,\"ActiveSkills\"->...,\n" <>
  "          \"ProjectionMode\"->...,\"TokenBudget\"->...,\"DirectiveMeta\"->...|>";

ClaudeProjectDirectives::usage =
  "ClaudeProjectDirectives[bundle] \:306f bundle \:3092 prompt \:7528\:6587\:5b57\:5217\:306b\:6295\:5f71\:3059\:308b\:3002\n" <>
  "ClaudeProjectDirectives[bundle, mode] \:306f\:660e\:793a\:30e2\:30fc\:30c9\:3067\:6295\:5f71\:3059\:308b\:3002";

ClaudeDirectiveTokenEstimate::usage =
  "ClaudeDirectiveTokenEstimate[text] \:306f\:6587\:5b57\:5217\:306e\:30c8\:30fc\:30af\:30f3\:6570\:6982\:7b97 (\:6574\:6570) \:3092\:8fd4\:3059\:3002\n" <>
  "\:82f1\:65e5\:6df7\:5728\:3092\:8003\:616e\:3057 StringLength/3 \:3067\:8fd1\:4f3c\:3059\:308b\:3002";

ClaudeSelectSkillsForTask::usage =
  "ClaudeSelectSkillsForTask[repo, taskHint, opts] \:306f task hint \:306b\:95a2\:9023\:3059\:308b skill \:3092\n" <>
  "\:30b9\:30b3\:30a2\:30ea\:30f3\:30b0\:3057\:3066\:4e26\:3079\:66ff\:3048\:3066\:8fd4\:3059\:3002opts:\n" <>
  "  \"Role\" -> Role \:540d\n" <>
  "  \"MaxSkills\" -> Integer (\:65e2\:5b9a 5)\n" <>
  "  \"ModelStrengths\" -> {String...} (skill \:30d5\:30a3\:30eb\:30bf\:306b\:4f7f\:7528)";

ClaudeSelectRulesForRole::usage =
  "ClaudeSelectRulesForRole[repo, role] \:306f role \:3054\:3068\:306e always-on rules \:3092\:9078\:5225\:3059\:308b\:3002\n" <>
  "Phase 35 stage1 \:4ee5\:964d\:3001\:5f8c\:65b9\:4e92\:63db\:306e\:305f\:3081 Lookup[repo, \"Rules\", {}] \:3092\:8fd4\:3059\:3002\n" <>
  "TaskHint \:30d9\:30fc\:30b9\:306e\:7d5e\:308a\:8fbc\:307f\:306b\:306f ClaudeSelectRulesForTask \:3092\:4f7f\:3046\:3002";

ClaudeSelectRulesForTask::usage =
  "ClaudeSelectRulesForTask[repo, taskHint, opts] \:306f task hint \:306b\:95a2\:9023\:3059\:308b rules \:3092\n" <>
  "\:9078\:5225\:3057\:3066\:8fd4\:3059 (Phase 35 stage1 \:3067\:8ffd\:52a0)\:3002opts:\n" <>
  "  \"Role\"     -> Role \:540d\n" <>
  "  \"MaxRules\" -> Integer (\:65e2\:5b9a 8) \[LongDash] always-on \:3092\:8d85\:3048\:308b\:5206\:306e\:4e0a\:9650\n" <>
  "  \"MinScore\" -> Integer (\:65e2\:5b9a 1)\n" <>
  "$ClaudeAlwaysOnRules \:306b\:5217\:6319\:3055\:308c\:305f rule \:306f\:7121\:6761\:4ef6\:3067\:542b\:3081\:308b\:3002\n" <>
  "\:305d\:308c\:4ee5\:5916\:306e rule \:306f frontmatter \:306e keywords / paths \:3068 TaskHint \:306e\:4ea4\:5dee\:5ea6\:3067\n" <>
  "\:30b9\:30b3\:30a2\:5316\:3057\:3001\:4e0a\:4f4d\:3092\:63a1\:7528\:3059\:308b\:3002";

$ClaudeAlwaysOnRules::usage =
  "$ClaudeAlwaysOnRules \:306f\:30bf\:30b9\:30af\:5185\:5bb9\:306b\:95a2\:4fc2\:306a\:304f\:5e38\:6642\:6ce8\:5165\:3055\:308c\:308b rule \:540d\:306e List\:3002\n" <>
  "\:30bb\:30ad\:30e5\:30ea\:30c6\:30a3\:30fb\:57fa\:672c\:30de\:30ca\:30fc\:7cfb\:306e rule \:3092\:3053\:3053\:306b\:767b\:9332\:3059\:308b\:3002\n" <>
  "ClaudeSelectRulesForTask \:304c\:53c2\:7167\:3059\:308b\:3002";

(* \[HorizontalLine] \:7d71\:5408\:30a8\:30f3\:30c8\:30ea \[HorizontalLine] *)

ClaudeBuildDirectivePromptForRole::usage =
  "ClaudeBuildDirectivePromptForRole[role, modelName, taskHint] \:306f\n" <>
  "1 \:884c\:3067 directive \:6295\:5f71\:30c6\:30ad\:30b9\:30c8\:3092\:8fd4\:3059\:7d71\:5408\:30a8\:30f3\:30c8\:30ea\:3002\n" <>
  "ClaudeOrchestrator \:306e worker BuildContext \:304b\:3089\:547c\:3073\:51fa\:3055\:308c\:308b\:60f3\:5b9a\:3002";

ClaudeBuildDirectivePromptForSingle::usage =
  "ClaudeBuildDirectivePromptForSingle[modelName, taskHint] \:306f\n" <>
  "\:5358\:4e00\:30a8\:30fc\:30b8\:30a7\:30f3\:30c8 (claudecode \:306e ClaudeEval / iAdapterBuildPrompt) \:7528\:306e\n" <>
  "directive \:6295\:5f71\:30c6\:30ad\:30b9\:30c8\:3092\:8fd4\:3059\:3002Role \:306f None \:3068\:3057\:3066\:6271\:3046\:3002";

(* \[HorizontalLine] \:5185\:90e8\:7528 (\:30c6\:30b9\:30c8\:6642\:306e\:307f\:516c\:958b) \[HorizontalLine] *)

ClaudeDirectivesParseFrontmatter::usage =
  "ClaudeDirectivesParseFrontmatter[text] \:306f SKILL.md \:5148\:982d\:306e YAML frontmatter \:3092\:89e3\:6790\:3059\:308b\:3002\n" <>
  "\:623b\:308a\:5024: <|\"Frontmatter\"->Association,\"Body\"->String|>";



(* ===================================================================
   Phase 1.0: Directive Repository Inventory / Manifest / Hash
   (Codex integration spec 5th review, sections 4.1 / 5.2 / 11.2 / 15.1)
   SourceVault-independent pure functions.
   =================================================================== *)

ClaudeResolveDirectiveRoot::usage =
  "ClaudeResolveDirectiveRoot[Automatic] resolves the canonical Claude Directives root via ClaudeFindDirectiveRoots, returning Failure[\"DirectiveRootNotFound\"] when none exists. ClaudeResolveDirectiveRoot[root] validates an explicit root directory string.";

ClaudeDirectiveFileInventory::usage =
  "ClaudeDirectiveFileInventory[root] returns the Phase 1.0 inventory of a Claude Directives repository as a sorted list of file records. root is a directory string or Automatic. Each record fixes the schema: Role, RelativePath, LogicalPath, AbsolutePath, ContentHash, ByteCount, LineCount, Name, Title, Description, FrontMatter, Paths, TokenEstimate, ModifiedTime. Role is one of RootInstruction | Rule | Skill | Other. Option \"IncludeOther\" controls whether non rule/skill repository files are included.";

ClaudeDirectiveRepositoryInventory::usage =
  "ClaudeDirectiveRepositoryInventory[root] is an alias of ClaudeDirectiveFileInventory[root].";

ClaudeDirectiveRepositoryManifest::usage =
  "ClaudeDirectiveRepositoryManifest[root] returns a DirectiveRepositoryManifest association: Kind, CanonicalFormat, Root, Files (the inventory), FilesCount, RulesCount, SkillsCount, ManifestHash, CreatedAt, Generator. The ManifestHash depends only on the sorted RelativePath/ContentHash pairs and is stable under ModifiedTime or TokenEstimate changes.";

ClaudeDirectiveRepositoryHash::usage =
  "ClaudeDirectiveRepositoryHash[root] returns only the ManifestHash string of the directive repository at root.";


(* ===================================================================
   Phase 1.1a: rule derived metadata & classification
   (Codex integration spec 5th review, sections 6.5.2 / 6.5.3)
   SourceVault-independent pure functions over inventory records.
   =================================================================== *)

$CodexRuleLargeByteThreshold::usage =
  "$CodexRuleLargeByteThreshold is the byte-count boundary above which a rule is classified as \"large\" by ClaudeDirectiveClassifyRule. Default 8192.";

ClaudeDirectiveRuleDerivedMetadata::usage =
  "ClaudeDirectiveRuleDerivedMetadata[ruleRecord] derives Codex-harness metadata for a rule inventory record (a Role -> \"Rule\" record from ClaudeDirectiveFileInventory). The canonical rule frontmatter is assumed to carry no description/summary/trigger; these are derived deterministically from the rule heading (Title) and the paths frontmatter. Returns an association with Title, Summary, Description, Trigger, DescriptionSource (\"derived-from-paths-and-heading\" | \"override\" | \"fallback\") and Paths. Option \"RuleMetadataOverrides\" supplies an opt-in per-rule override association keyed by rule Name.";

ClaudeDirectiveClassifyRule::usage =
  "ClaudeDirectiveClassifyRule[ruleRecord] classifies a rule inventory record for harness materialization. Returns an association with Scope (\"always-on\" | \"task-specific\"), SizeClass (\"small\" | \"large\"), CommandPolicy, InlineSummaryInAgentsMd (a candidate value; the final inline decision is re-evaluated against the AGENTS.md byte budget in ClaudeDirectiveHarnessPlan) and Reason. Options: \"AlwaysOnRules\", \"RuleLargeByteThreshold\", \"RuleMetadataOverrides\".";


(* ===================================================================
   Phase 1.1b-1: harness plan (dry-run)
   (Codex integration spec 5th review, sections 5.2 / 5.4 / 6.3-6.6)
   ClaudeDirectiveHarnessPlan computes, without writing any file,
   the full Codex harness layout: AGENTS.md budget, directive index
   entries, generated rule/skill skills, command-policy rules.
   =================================================================== *)

ClaudeDirectiveHarnessPlan::usage =
  "ClaudeDirectiveHarnessPlan[bundle, target] returns a dry-run materialization plan for a harness without writing any file. target is \"Codex\" or \"ClaudeCLI\"; the \"ClaudeCLI\" plan is a verbatim-copy plan (no AGENTS.md, no directive index). The plan association contains Target, HarnessMaterializationMode, DirectiveRepositoryManifestHash, SourceVaultSnapshotId, AgentsMd (TargetRelativePath / EstimatedByteCount / InlineRuleNames / OmittedRuleNames / HardMaxBytes), Index (TargetRelativePath / Entries), GeneratedSkills, CommandPolicyRules, ProvenanceFiles and Warnings. Options: \"HarnessMaterializationMode\", \"AgentsMdTargetMaxBytes\", \"AgentsMdHardMaxBytes\", \"RuleLargeByteThreshold\", \"AlwaysOnRules\", \"RuleMetadataOverrides\", \"SourceVaultSnapshotId\".";


(* ===================================================================
   Phase 1.1b-2: Codex harness materialization
   (Codex integration spec 5th review, sections 5.2 / 6.6-6.8)
   ClaudeDirectiveMaterializeCodexHarness executes a harness plan and
   writes AGENTS.md, .agents/skills/<name>/SKILL.md,
   .agents/directive-index.json and provenance files.
   =================================================================== *)

ClaudeDirectiveHarnessProvenanceHeader::usage =
  "ClaudeDirectiveHarnessProvenanceHeader[meta] returns the HTML-comment provenance header placed at the top of a generated AGENTS.md. meta is an association that may carry DirectiveRepositoryManifestHash, SourceVaultSnapshotId and HarnessMaterializationMode.";

ClaudeDirectiveMaterializeCodexHarness::usage =
  "ClaudeDirectiveMaterializeCodexHarness[bundle, targetDir] materializes a Codex harness under targetDir by executing ClaudeDirectiveHarnessPlan. It writes generated rule/skill SKILL.md files under .agents/skills, .agents/directive-index.json, AGENTS.md and provenance files, in that fixed order. The canonical Claude Directives repository is never modified. Returns a materialization report (WrittenFiles, AgentsMd, Index, GeneratedSkills, ProvenanceFiles, Warnings, Plan). With DryRun -> True no file is written and the plan is returned. Options mirror ClaudeDirectiveHarnessPlan plus GenerateDirectiveIndex, GenerateProvenance, CommandPolicyMaterialization, DryRun and FailOnAgentsMdOverflow.";

ClaudeDirectiveMaterializeClaudeHarness::usage =
  "ClaudeDirectiveMaterializeClaudeHarness[bundle, targetDir] materializes a Claude CLI harness under targetDir from the canonical Claude Directives repository (Phase 4, $ClaudeCLIHarnessMode -> \"Generated\"). It writes .claude/CLAUDE.md, .claude/rules/<name>.md and .claude/skills/<name>/SKILL.md as verbatim copies of the canonical files (no rule-to-skill conversion, no AGENTS.md, no directive index), plus .claude/sourcevault-provenance.json. The canonical repository is never modified, and .claude/settings.json is left to the caller (claudecode.wl injects read permissions). Returns a materialization report (WrittenFiles, RootInstruction, GeneratedFiles, ProvenanceFiles, Warnings, Plan). With DryRun -> True no file is written and the plan is returned. Options: HarnessMaterializationMode, DirectiveRepositoryManifestHash, SourceVaultSnapshotId, GenerateProvenance, DryRun.";


(* ===================================================================
   Phase 2.5: migration gate (Codex integration spec, section 4)
   Diagnoses the difference between the canonical Claude Directives
   repository and a legacy $ClaudeWorkingDirectory/.claude/ harness,
   compared on normalised logical paths. Codex-independent; gates the
   Phase 4 switch of Claude CLI from Direct to Generated.
   =================================================================== *)

ClaudeDirectiveCompareCanonicalAndClaudeHarness::usage =
  "ClaudeDirectiveCompareCanonicalAndClaudeHarness[directiveRoot, claudeDir] compares a canonical Claude Directives repository against a legacy .claude/ harness on normalised logical paths (CLAUDE.md, rules/<name>.md, skills/<name>/SKILL.md). Returns the raw comparison: CanonicalEquivMap, LegacyEquivMap, FilesOnlyInCanonical, FilesOnlyInLegacy, FilesChanged, LegacyHarnessOnlyFiles (settings.json etc., excluded from equivalence), CanonicalDirExists, LegacyDirExists.";

ClaudeDirectiveMigrationReport::usage =
  "ClaudeDirectiveMigrationReport[directiveRoot, claudeDir] is the migration gate: it reports whether the legacy .claude/ harness is equivalent to the canonical Claude Directives repository. Returns <|\"CanonicalRoot\", \"LegacyClaudeDir\", \"CanonicalHash\", \"LegacyHarnessHash\", \"Status\", \"FilesOnlyInCanonical\", \"FilesOnlyInLegacy\", \"FilesChanged\", \"LegacyHarnessOnlyFiles\", \"RecommendedAction\"|>. Status is \"Equivalent\" | \"Diverged\" | \"LegacyOnly\" | \"CanonicalOnly\". Hashes are computed over normalised {LogicalPath, ContentHash} pairs of CLAUDE.md / rules / skills only; harness-only files do not affect Status. Switching Claude CLI to Generated mode requires Status \"Equivalent\" or manual approval.";

Begin["`Private`"];

$ClaudeDirectivesVersion = "0.1.12-phase35-stage1-provider-generic-resolve";

(* v0.1.12: iPrefixMatchCapability \:3092\:30e2\:30c7\:30eb\:679d\:756a\:30cf\:30fc\:30c9\:30b3\:30fc\:30c9\:304b\:3089
   Provider \:5358\:4f4d\:306e\:6c4e\:7528\:5224\:5b9a\:306b\:30ea\:30d5\:30a1\:30af\:30bf (rules/02-llm-instructions-not-in-source.md \:6e96\:62e0)\:3002
   - \:65e7: StringStartsQ[name, "gpt-5"], StringStartsQ[name, "gpt-4.1"], ... 
         \:306e\:3088\:3046\:306b\:5177\:4f53\:30e2\:30c7\:30eb\:540d\:3092 Which \:5206\:5c90\:306b\:66f8\:3044\:3066\:3044\:305f \[RightArrow] \:30cf\:30fc\:30c9\:30b3\:30fc\:30c9
   - \:65b0: iGuessProvider \:3067 Provider \:306e\:307f\:5224\:5b9a \[RightArrow] iSelectFallbackForProvider \:3067
         \:540c Provider \:306e\:6700\:5f37\:767b\:9332\:30e2\:30c7\:30eb\:3092 Class \:30e9\:30f3\:30af\:3067\:9078\:629e\:3002
   - \:7d50\:679c: \:65b0\:3057\:3044\:30e2\:30c7\:30eb\:679d\:756a\:304c\:51fa\:3066\:304d\:3066\:3082 $ClaudeModelCapabilities \:306b\:767b\:9332\:3059\:308b
     \:3060\:3051\:3067\:6e08\:307f\:3001\:95a2\:6570\:672c\:4f53\:306b\:624b\:3092\:5165\:308c\:308b\:5fc5\:8981\:304c\:306a\:3044\:3002
   - rules/02 \:3067\:7981\:6b62\:3055\:308c\:305f\:30d1\:30bf\:30fc\:30f3\:306e\:9664\:53bb\:3002

   v0.1.11: OpenAI Cloud \:30e2\:30c7\:30eb (gpt-5, gpt-4.1, gpt-4o, gpt-4o-mini) \:3092
   $ClaudeModelCapabilities \:306b\:8ffd\:52a0 (2026-05-10, result3.nb \:3067 gpt-4.5-preview
   \:30a8\:30e9\:30fc\:3092\:539f\:56e0\:8ffd\:8de1)\:3002

   v0.1.10: Phase 35 Stage 1 rule selection scoring \:8ffd\:52a0\:3002 *)

(* v0.1.9-fix2: iEstimateBundleTokens \:306e Summary mode \:8a08\:7b97\:4fee\:6b63
   (Phase 34 result49.nb \:3067\:767a\:898b)\:3002
   Summary mode \:3067\:300crules \:3092\:30d5\:30eb\:30b5\:30a4\:30ba\:3067\:52a0\:7b97\:300d\:3057\:3066\:3044\:305f\:305f\:3081\:3001
   \:5b9f iProjectSummary \:51fa\:529b (\:5404 rule \:3092 400 chars \:306b\:5727\:7e2e) \:3068\:4e56\:96e2\:3057\:3066
   \:898b\:7a4d\:3082\:308a\:304c\:7d04 5 \:500d\:904e\:5927\:306b\:306a\:3063\:3066\:3044\:305f\:3002\:4f8b: result49 \:3067 Plan \:306e Tokens
   \:8868\:793a\:5024 30026 (\:898b\:7a4d\:3082\:308a) vs \:5b9f prefix 17888 chars \[TildeTilde] 5963 tokens\:3002
   \:4fee\:6b63\:3067 Summary \:898b\:7a4d\:3082\:308a\:304c ~5K-7K tokens \:306b\:53ce\:307e\:308a\:5b9f\:614b\:3068\:6574\:5408\:3059\:308b\:3002
   - rules \:3092 Min[Tokens, 133] (= 400 chars / 3) \:3067\:4e0a\:9650\:4ed8\:304d\:52a0\:7b97
   - claudeMD \:3092 Min[cmTok/3, 1000] \:3067\:4e0a\:9650\:4ed8\:304d\:52a0\:7b97 (iProjectSummary \:306f
     iSummarizeBody[..., 3000] \:3067\:7d04 1000 tokens \:306b\:5727\:7e2e\:3059\:308b\:305f\:3081\:6574\:5408)
   \:5b9f prefix \:306f\:5909\:308f\:3089\:305a (iProjectSummary \:306f\:5909\:66f4\:306a\:3057)\:3001\:898b\:7a4d\:3082\:308a\:3060\:3051\:4fee\:6b63\:3002 *)

(* v0.1.9-fix1: \:65b0\:5b9a\:6570 3 \:3064\:306e Public \:5316\:6f0f\:308c\:4fee\:6b63 (result47.nb \:3067\:767a\:898b)\:3002
   $ClaudeSkillRolePolicy / $ClaudeRoleDefaultMode / $ClaudeRoleMaxSkills \:3092
   Begin["`Private`"] \:5185\:3067\:5024\:4ee3\:5165\:3057\:3066\:3044\:305f\:304c\:3001BeginPackage \:76f4\:5f8c\:306e Public \:5ba3\:8a00\:30d6\:30ed\:30c3\:30af\:306b
   ::usage \:3092\:66f8\:304d\:5fd8\:308c\:3066\:3044\:305f\:305f\:3081\:3001Public namespace \:306b\:51fa\:3066\:3044\:306a\:304b\:3063\:305f
   (= ClaudeDirectives`$ClaudeSkillRolePolicy \:304c undefined)\:3002
   - L51-65 (Public \:5ba3\:8a00\:30d6\:30ed\:30c3\:30af) \:306b 3 \:3064\:306e ::usage \:3092\:8ffd\:52a0\:3002
   - Private \:5185\:306e\:91cd\:8907 ::usage \:3092\:524a\:9664 (Public \:304c\:512a\:5148\:3055\:308c\:308b)\:3002
   role-aware smoke test \:306e Block A/B/C \:304c PASS \:3059\:308b\:3088\:3046\:306b\:306a\:308b\:3002 *)

(* v0.1.9: Stage 1 role-aware skill / mode \:6539\:5584 (Phase 34 result45 \:89b3\:6e2c\:30d5\:30a3\:30fc\:30c9\:30d0\:30c3\:30af)\:3002
   result45.nb \:3067\:5168 role \:304c\:540c\:3058 skill \:96c6\:5408\:30fbMode=Full\:30fbTokens=34722 \:306b\:306a\:308b\:554f\:984c\:3092\:89b3\:6e2c\:3002
   - $ClaudeSkillRolePolicy \:65b0\:8a2d: role \:5225\:306b prefer \:3059\:308b skill \:4e00\:89a7\:3002
     iScoreSkill \:3067 policy match \:306b +6 \:52a0\:70b9 (\:5927\:304d\:3081) \:3057\:3066 role \:5225\:306b skill \:96c6\:5408\:3092\:5206\:5316\:3002
   - $ClaudeRoleDefaultMode \:65b0\:8a2d: role \:5225 default Mode (Plan/Draft/Reduce/Commit=Summary\:3001
     Verify/Explore/ConfidentialDraft=Index)\:3002Token \:91cf\:3092 30K \[RightArrow] 6K (Summary) \:307e\:305f\:306f 1K (Index) \:306b\:524a\:6e1b\:3002
   - $ClaudeRoleMaxSkills \:65b0\:8a2d: role \:5225 default skill \:4e0a\:9650\:3002Verify/Explore=3\:3001
     ConfidentialDraft=2 \:3067 context \:5727\:8feb\:3092\:7de9\:548c\:3002
   - Options[ClaudeResolveDirectiveBundle] \:306e MaxSkills default \:3092 5 \[RightArrow] Automatic \:306b\:3002
     Automatic \:3067 $ClaudeRoleMaxSkills \:3092\:5f15\:304f (\:4e92\:63db\:6027\:4fdd\:6301: \:660e\:793a\:7684\:306b 5 \:3092\:6e21\:3057\:305f\:30b3\:30fc\:30c9\:306f\:7121\:5f71\:97ff)\:3002
   - ClaudeResolveDirectiveBundle \:306e Mode \:89e3\:6c7a\:3092 role \:512a\:5148\:306b\:5909\:66f4:
     mode === Automatic && role \:304c $ClaudeRoleDefaultMode \:306b\:767b\:9332 \[RightArrow] role default \:3092\:63a1\:7528\:3002
     \:672a\:767b\:9332\:306a\:3089\:5f93\:6765\:901a\:308a capability \:306e DefaultMode\:3002 *)

(* v0.1.8: \:6f14\:7b97\:5b50\:512a\:5148\:5ea6\:30d0\:30b0\:4fee\:6b63 (Phase 34 Stage 2 smoke test result42 \:3067\:767a\:898b)\:3002
   Association \:30ea\:30c6\:30e9\:30eb <| ..., "key" -> Lookup[#, "Name", ""] & /@ list, ... |>
   \:3067 `&` (precedence 90) \:304c `->` (precedence 120) \:3088\:308a\:5f31\:3044\:7d50\:5408\:529b\:306e\:305f\:3081\:3001
   `&` \:304c "key" -> ... \:5168\:4f53\:3092 Function \:5316\:3057\:3066\:304b\:3089 /@ list \:3067 Map \:3057\:3066\:3044\:305f\:3002
   \:7d50\:679c\:306f `{"key" -> name1, "key" -> name2, ...}` \:3068\:3044\:3046 List of Rules \:3067\:3001
   Association \:30ea\:30c6\:30e9\:30eb\:5185\:3067 flatten \:3055\:308c\:3066\:540c\:3058\:30ad\:30fc\:304c\:8907\:6570\:56de\:767b\:9332\:3055\:308c\:3001
   \:6700\:5f8c\:306e rule \:306e\:307f\:304c\:6b8b\:308b (= \:6700\:5f8c\:306e skill \:540d 1 \:500b\:3060\:3051\:304c\:6b8b\:308b) \:30d0\:30b0\:3060\:3063\:305f\:3002
   - L836-837: (Lookup[#, "Name", ""] &) /@ skills \:3068\:660e\:793a\:7684\:62ec\:5f27\:3067 & \:306e\:30b9\:30b3\:30fc\:30d7\:3092\:9650\:5b9a\:3002
   ClaudeOrchestratorDirectives`SelectedDirectives \:3067 Skills/Rules \:304c\:5358\:4e00 String \:306b
   \:306a\:308b\:554f\:984c\:304c\:89e3\:6d88\:3055\:308c\:308b\:3002 *)

(* v0.1.7: skill \:9078\:5225\:7cbe\:5ea6\:306e\:8ffd\:52a0\:4fee\:6b63 (Phase 33 Stage 2 Phase A1)\:3002
   Phase A1.3 \:30c7\:30d0\:30c3\:30b0 (result13.nb) \:3067\:767a\:898b\:3057\:305f 2 \:3064\:306e\:6839\:672c\:554f\:984c\:3092\:4fee\:6b63:
   - \:9577\:97f3\:7b26 \:30fc (U+30FC) \:304c \p{Katakana} \:306b\:30de\:30c3\:30c1\:3057\:306a\:3044\:554f\:984c
     "\:30e1\:30fc\:30eb" \:304c "\:30e1" + "\:30fc" + "\:30eb" \:306b\:5206\:65ad\:3055\:308c\:5404\:3005\:9577\:3055 1 \:3067\:9664\:5916\:3055\:308c\:3066\:3044\:305f\:3002
     \:6587\:5b57\:30af\:30e9\:30b9\:3092 [\p{Katakana}\:30fc] \:3068\:66f8\:3044\:3066\:9577\:97f3\:7b26\:3092\:76f4\:63a5\:542b\:3081\:308b\:3002
     "\:30e1\:30fc\:30eb\:3092\:691c\:7d22" \[Rule] {"\:30e1\:30fc\:30eb", "\:691c\:7d22"} \:3068\:6b63\:3057\:304f\:5206\:89e3\:3055\:308c\:308b\:3088\:3046\:306b\:306a\:308b\:3002
   - role = "" \:306e\:3068\:304d\:306e\:52a0\:70b9\:30d0\:30b0
     StringContainsQ[anything, ""] \:304c\:5e38\:306b True \:3092\:8fd4\:3059\:305f\:3081\:3001\:5168 skill \:306b +4 \:304c
     \:52a0\:7b97\:3055\:308c\:3066 maildb \:7b49\:306e\:7d20\:306e\:30b9\:30b3\:30a2\:304c 4 \:306b\:306a\:3063\:3066\:3044\:305f\:3002
     \:7a7a\:6587\:5b57\:5217\:306e role \:3067\:306f\:52a0\:70b9\:3057\:306a\:3044\:3088\:3046\:306b\:6761\:4ef6\:3092\:8ffd\:52a0\:3002 *)

(* v0.1.6: skill \:9078\:5225\:7cbe\:5ea6\:306e\:6539\:5584 (Phase 33 Stage 2 Phase A1)\:3002
   Phase A1.1 \:89b3\:6e2c (result11.nb) \:3067\:300c\:30e1\:30fc\:30eb\:3092\:691c\:7d22\:300d\:306e\:3088\:3046\:306a\:65e5\:672c\:8a9e\:30d2\:30f3\:30c8\:3067
   maildb-operations \:304c\:9996\:4f4d\:306b\:51fa\:306a\:3044\:554f\:984c\:3092\:767a\:898b\:3002\:539f\:56e0 2 \:3064\:3092\:4fee\:6b63:
   - iTokenizeForMatch: \:3072\:3089\:304c\:306a\:30fb\:30ab\:30bf\:30ab\:30ca\:30fb\:6f22\:5b57\:3092\:6587\:5b57\:7a2e\:5883\:754c\:3067\:5225\:3005\:306b\:62bd\:51fa\:3002
     "\:30e1\:30fc\:30eb\:3092\:691c\:7d22" \[Rule] {"\:30e1\:30fc\:30eb", "\:691c\:7d22"} \:3068\:5206\:89e3\:3055\:308c\:3001skill description \:306e
     "\:30e1\:30fc\:30eb" "\:30e1\:30fc\:30eb\:30c7\:30fc\:30bf\:30d9\:30fc\:30b9" \:3068 Intersection \:304c\:6210\:7acb\:3059\:308b\:3088\:3046\:306b\:306a\:308b\:3002
   - iScoreSkill: model strengths \:3068\:306e\:4ea4\:5dee\:3067 generic \:306a\:8a9e
     (Code / Reasoning / ToolUse / LongContext) \:3092\:9664\:5916\:3057\:3001specific \:306a\:80fd\:529b
     (Search / Multimodal / Multilingual \:7b49) \:306e\:307f\:304c skill \:9078\:5225\:306b\:52b9\:304f\:3088\:3046\:306b\:3002
     \:3053\:308c\:306b\:3088\:3063\:3066 api-key-handling \:7b49\:304c generic \:52a0\:70b9\:3067\:5e38\:6642\:4e0a\:4f4d\:306b\:6765\:308b\:554f\:984c\:3092\:89e3\:6d88\:3002 *)

(* v0.1.5: $ClaudeModel = "" (Anthropic Claude \:306e\:30c7\:30d5\:30a9\:30eb\:30c8\:30e2\:30c7\:30eb\:6307\:5b9a\:306e\:6163\:7fd2) \:3067
   \:4fdd\:5b88\:7684\:30d5\:30a9\:30fc\:30eb\:30d0\:30c3\:30af\:306b\:843d\:3061\:3066 Index mode \:306b\:964d\:683c\:3059\:308b\:554f\:984c\:3092\:4fee\:6b63\:3002
   - iPrefixMatchCapability \:306e\:5148\:982d\:3067\:7a7a\:6587\:5b57\:5217 / \:7a7a\:767d\:306e\:307f\:306e normalized \:3092
     claude-opus-4-7 (Heavy-Cloud) \:3068\:3057\:3066\:6271\:3046\:30d5\:30a9\:30fc\:30eb\:30d0\:30c3\:30af\:3092\:8ffd\:52a0\:3002
   - \:6ce8: $ClaudeModel \:304c List \:5f62\:5f0f ({\"lmstudio\", \"qwen/qwen3.6-27b\", ...}) \:306e
     ToString \:7d50\:679c \"{...}\" \:306f\:4f9d\:7136\:3068\:3057\:3066 Unknown \:6271\:3044\:306b\:306a\:308b\:3002
     \:3053\:308c\:306f claudecode.wl \:5074\:306e P1.5 (iClaudeSysPrompt[] \:3067\:306e
     $ClaudeModel \:6b63\:898f\:5316) \:3067\:5bfe\:5fdc\:3059\:3079\:304d\:3002
   v0.1.4: ClaudeResolveModelCapability \:306b\:30d7\:30ec\:30d5\:30a3\:30c3\:30af\:30b9\:30d5\:30a9\:30fc\:30eb\:30d0\:30c3\:30af\:8ffd\:52a0\:3002
   v0.1.3: iParseFrontmatter \:306e\:8b66\:544a\:3092\:89e3\:6d88\:3002
   v0.1.2: Import \:69cb\:6587\:4fee\:6b63 + tokenizer \:6539\:5584\:3002
   v0.1.1: Import \:69cb\:6587\:4fee\:6b63\:306e\:521d\:7248\:3002
   v0.1.0: Phase 33 Stage 1 \:521d\:7248\:3002 *)

(* \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550
   1. iL \:30d0\:30a4\:30ea\:30f3\:30ac\:30eb
   \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550 *)

iL[ja_String, en_String] := If[$Language === "Japanese", ja, en];

(* \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550
   2. \:30e2\:30c7\:30eb\:80fd\:529b\:30c6\:30fc\:30d6\:30eb
   
   ContextWindow \:306f\:5b9f\:7528\:4e0a\:306e\:73fe\:5b9f\:5024 (LM Studio + RTX 4090 \:60f3\:5b9a\:3067\:306f
   KV cache \:3092\:542b\:3081\:305f\:5b9f\:52b9\:5024) \:3092\:5165\:308c\:308b\:3002spec \:4e0a\:306e\:6700\:5927\:5024\:3067\:306f\:306a\:3044\:70b9\:306b\:6ce8\:610f\:3002
   
   qwen3.6-27b: native 256K \:3060\:304c RTX 4090 (24GB) \:3067 FP8/Q5 \:91cf\:5b50\:5316 +
   \:30d5\:30eb\:30ed\:30fc\:30c9\:6642\:3001KV cache \:542b\:3081\:3066\:5b9f\:7528 128K \:7a0b\:5ea6\:3002
   \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550 *)

$ClaudeModelCapabilities = <|

  (* \[HorizontalLine] Anthropic CLI (claudecode \:30b3\:30de\:30f3\:30c9\:7d4c\:7531\:3001\:8ab2\:91d1\:306a\:3057 = Pro/Max \:30b5\:30d6\:30b9\:30af\:30ea\:30d7\:30b7\:30e7\:30f3\:5185) \[HorizontalLine] *)
  {"claudecode", "claude-opus-5"} -> <|
    "ContextWindow"    -> 200000,
    "Class"            -> "Heavy-Cloud",
    "DefaultMode"      -> "Summary",
    "Strengths"        -> {"Code", "Reasoning", "JSON", "LongContext", "ToolUse"},
    "PreserveThinking" -> True,
    "Provider"         -> "claudecode",
    "Paid"             -> False
  |>,

  {"claudecode", "claude-opus-4-7"} -> <|
    "ContextWindow"    -> 200000,
    "Class"            -> "Heavy-Cloud",
    "DefaultMode"      -> "Summary",
    "Strengths"        -> {"Code", "Reasoning", "JSON", "LongContext", "ToolUse"},
    "PreserveThinking" -> True,
    "Provider"         -> "claudecode",
    "Paid"             -> False
  |>,

  {"claudecode", "claude-opus-4-6"} -> <|
    "ContextWindow"    -> 200000,
    "Class"            -> "Heavy-Cloud",
    "DefaultMode"      -> "Summary",
    "Strengths"        -> {"Code", "Reasoning", "JSON", "LongContext"},
    "PreserveThinking" -> True,
    "Provider"         -> "claudecode",
    "Paid"             -> False
  |>,

  {"claudecode", "claude-sonnet-4-6"} -> <|
    "ContextWindow"    -> 200000,
    "Class"            -> "Mid-Cloud",
    "DefaultMode"      -> "Summary",
    "Strengths"        -> {"Code", "Reasoning", "JSON"},
    "PreserveThinking" -> True,
    "Provider"         -> "claudecode",
    "Paid"             -> False
  |>,

  {"claudecode", "claude-haiku-4-5"} -> <|
    "ContextWindow"    -> 200000,
    "Class"            -> "Light-Cloud",
    "DefaultMode"      -> "Summary",
    "Strengths"        -> {"Search", "Triage", "Summarize"},
    "PreserveThinking" -> False,
    "Provider"         -> "claudecode",
    "Paid"             -> False
  |>,

  (* \[HorizontalLine] Anthropic API \:76f4\:63a5 (anthropic \:30d7\:30ed\:30d0\:30a4\:30c0\:3001\:8ab2\:91d1\:3042\:308a) \[HorizontalLine] *)
  {"anthropic", "claude-opus-5"} -> <|
    "ContextWindow"    -> 200000,
    "Class"            -> "Heavy-Cloud",
    "DefaultMode"      -> "Summary",
    "Strengths"        -> {"Code", "Reasoning", "JSON", "LongContext", "ToolUse"},
    "PreserveThinking" -> True,
    "Provider"         -> "anthropic",
    "Paid"             -> True
  |>,

  {"anthropic", "claude-opus-4-7"} -> <|
    "ContextWindow"    -> 200000,
    "Class"            -> "Heavy-Cloud",
    "DefaultMode"      -> "Summary",
    "Strengths"        -> {"Code", "Reasoning", "JSON", "LongContext", "ToolUse"},
    "PreserveThinking" -> True,
    "Provider"         -> "anthropic",
    "Paid"             -> True
  |>,

  {"anthropic", "claude-opus-4-6"} -> <|
    "ContextWindow"    -> 200000,
    "Class"            -> "Heavy-Cloud",
    "DefaultMode"      -> "Summary",
    "Strengths"        -> {"Code", "Reasoning", "JSON", "LongContext"},
    "PreserveThinking" -> True,
    "Provider"         -> "anthropic",
    "Paid"             -> True
  |>,

  {"anthropic", "claude-sonnet-4-6"} -> <|
    "ContextWindow"    -> 200000,
    "Class"            -> "Mid-Cloud",
    "DefaultMode"      -> "Summary",
    "Strengths"        -> {"Code", "Reasoning", "JSON"},
    "PreserveThinking" -> True,
    "Provider"         -> "anthropic",
    "Paid"             -> True
  |>,

  {"anthropic", "claude-haiku-4-5"} -> <|
    "ContextWindow"    -> 200000,
    "Class"            -> "Light-Cloud",
    "DefaultMode"      -> "Summary",
    "Strengths"        -> {"Search", "Triage", "Summarize"},
    "PreserveThinking" -> False,
    "Provider"         -> "anthropic",
    "Paid"             -> True
  |>,

  (* \[HorizontalLine] LM Studio / \:30ed\:30fc\:30ab\:30eb LLM (\:8ab2\:91d1\:306a\:3057) \[HorizontalLine] *)
  {"lmstudio", "qwen3.6-27b"} -> <|
    "ContextWindow"    -> 131072,                (* RTX 4090 \:5b9f\:7528\:5024 *)
    "Class"            -> "Heavy-Local",
    "DefaultMode"      -> "Summary",
    "Strengths"        -> {"Code", "ToolUse", "Reasoning",
                           "Multimodal", "Multilingual"},
    "PreserveThinking" -> True,
    "ThinkingMode"     -> "Hybrid",              (* Qwen3.6 hybrid-thinking *)
    "ToolCallParser"   -> "qwen3_coder",
    "Provider"         -> "lmstudio",
    "Paid"             -> False
  |>,

  {"lmstudio", "qwen3.5-27b"} -> <|
    "ContextWindow"    -> 131072,
    "Class"            -> "Mid-Local",
    "DefaultMode"      -> "Summary",
    "Strengths"        -> {"Code", "Reasoning"},
    "PreserveThinking" -> False,
    "Provider"         -> "lmstudio",
    "Paid"             -> False
  |>,

  {"lmstudio", "qwen3-coder-30b"} -> <|
    "ContextWindow"    -> 128000,
    "Class"            -> "Mid-Local",
    "DefaultMode"      -> "Summary",
    "Strengths"        -> {"Code"},
    "PreserveThinking" -> False,
    "Provider"         -> "lmstudio",
    "Paid"             -> False
  |>,

  {"lmstudio", "gpt-oss-120b"} -> <|
    "ContextWindow"    -> 32768,
    "Class"            -> "Light-Local",
    "DefaultMode"      -> "Index",
    "Strengths"        -> {"Search", "Summarize"},
    "PreserveThinking" -> False,
    "Provider"         -> "lmstudio",
    "Paid"             -> False
  |>,

  (* \[HorizontalLine] OpenAI API \:76f4\:63a5 (\:8ab2\:91d1\:3042\:308a\:3001\:5c06\:6765\:7121\:6599\:30d7\:30e9\:30f3\:5bfe\:5fdc\:6642\:306b Paid -> False \:306e entry \:8ffd\:52a0\:3082\:53ef\:80fd) \[HorizontalLine] *)
  {"openai", "gpt-5.5"} -> <|
    "ContextWindow"    -> 128000,
    "Class"            -> "Heavy-Cloud",
    "DefaultMode"      -> "Summary",
    "Strengths"        -> {"Code", "Reasoning", "JSON", "ToolUse"},
    "PreserveThinking" -> True,
    "Provider"         -> "openai",
    "Paid"             -> True
  |>,

  {"openai", "gpt-5.5-pro"} -> <|
    "ContextWindow"    -> 128000,
    "Class"            -> "Heavy-Cloud",
    "DefaultMode"      -> "Summary",
    "Strengths"        -> {"Code", "Reasoning", "JSON"},
    "PreserveThinking" -> False,
    "Provider"         -> "openai",
    "Paid"             -> True
  |>,

  {"openai", "gpt-5-mini"} -> <|
    "ContextWindow"    -> 128000,
    "Class"            -> "Mid-Cloud",
    "DefaultMode"      -> "Summary",
    "Strengths"        -> {"Code", "Reasoning", "JSON", "Multimodal"},
    "PreserveThinking" -> False,
    "Provider"         -> "openai",
    "Paid"             -> True
  |>,

  {"openai", "gpt-5-nano"} -> <|
    "ContextWindow"    -> 128000,
    "Class"            -> "Light-Cloud",
    "DefaultMode"      -> "Summary",
    "Strengths"        -> {"Search", "Triage"},
    "PreserveThinking" -> False,
    "Provider"         -> "openai",
    "Paid"             -> True
  |>
|>;

(* role -> \:65e2\:5b9a\:30e2\:30c7\:30eb\:3002
   Stage 2 (Orchestrator role \:5225 projection) \:3067\:53c2\:7167\:3055\:308c\:308b\:60f3\:5b9a\:3002
   \:6a5f\:5bc6\:51e6\:7406 (privacy > 0.5 \:30e1\:30fc\:30eb\:306a\:3069) \:306e\:5f79\:5272\:306f ConfidentialDraft \:3068\:3057\:3066
   \:5206\:96e2\:3057\:3001\:5fc5\:305a\:30ed\:30fc\:30ab\:30eb\:3078\:632f\:308b\:3002 *)

$ClaudeRoleDefaultModels = <|
  (* Phase 28: \:5024\:3092 {provider, model} tuple \:306b\:5909\:66f4\:3002
     \:30c7\:30d5\:30a9\:30eb\:30c8\:306f Anthropic CLI (\:8ab2\:91d1\:306a\:3057) \:3092\:6307\:3059\:3002 *)
  "Plan"              -> {"claudecode", "claude-opus-5"},
  "Draft"             -> {"claudecode", "claude-opus-5"},
  "Reduce"            -> {"claudecode", "claude-opus-5"},
  "Commit"            -> {"claudecode", "claude-opus-5"},
  "Explore"           -> {"lmstudio", "qwen3.6-27b"},
  "Verify"            -> {"lmstudio", "qwen3.6-27b"},
  "ConfidentialDraft" -> {"lmstudio", "qwen3.6-27b"}
|>;

(* \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550
   Stage 1 v0.1.9: role-aware skill policy / mode / maxSkills

   v0.1.9 \:3067\:5c0e\:5165\:3002result45.nb \:3067\:5168 role \:304c\:540c\:3058 skill \:96c6\:5408\:30fbMode=Full \:306b
   \:306a\:308b\:554f\:984c\:3092\:89e3\:6d88\:3059\:308b\:305f\:3081\:3001role \:5225\:306b\:300c\:597d\:3080 skill \:540d\:300d\:300cdefault Mode\:300d
   \:300cdefault \:4e0a\:9650\:300d\:3092\:8868\:3067\:6301\:3064\:3002
   \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550 *)

(* role \:5225 prefer skill \:4e00\:89a7\:3002iScoreSkill \:304c policy match \:3067 +6 \:52a0\:70b9\:3059\:308b\:3002
   skill \:540d\:306f CLAUDE.md \:30a4\:30f3\:30b9\:30c8\:30fc\:30eb\:6e08\:307f\:30ea\:30b9\:30c8\:304b\:3089\:63a1\:7528 (\:5927\:6587\:5b57\:5c0f\:6587\:5b57\:306f
   normalize \:3059\:308b)\:3002\:30bf\:30b9\:30af\:3068\:7121\:95a2\:4fc2\:3067\:3082\:8a72\:5f53 role \:306a\:3089 priority \:5165\:308a\:3059\:308b\:3002 *)
$ClaudeSkillRolePolicy = <|
  "Plan"    -> {"doc-generation", "package-merge-pattern",
                "github-operations", "wolfram-general"},
  "Draft"   -> {"wolfram-general", "external-language-output",
                "system-open", "package-merge-pattern"},
  "Reduce"  -> {"doc-generation", "package-merge-pattern",
                "wolfram-general"},
  "Commit"  -> {"nbaccess-notebook-access", "nbaccess-separation-check",
                "github-operations", "doc-generation"},
  "Verify"  -> {"wl-encoding-and-regex", "nbaccess-separation-check",
                "wolfram-general"},
  "Explore" -> {"maildb-operations", "nbaccess-notebook-access",
                "system-open", "github-operations"},
  "ConfidentialDraft" -> {"confidential-data-handling",
                          "confidential-structure-probe",
                          "api-key-handling"}
|>;

(* role \:5225 default Mode\:3002result45 \:3067\:5168 role \:304c Full mode \:306b\:306a\:3063\:3066\:3044\:305f
   \:554f\:984c\:3078\:306e\:5bfe\:51e6\:3002Mode \:8a08\:7b97\:3067 mode === Automatic && role \:304c\:3053\:3053\:306b
   \:767b\:9332 \[RightArrow] \:5f79\:5272\:5225 default \:3092\:63a1\:7528\:3002\:672a\:767b\:9332\:306a\:3089 capability \:306e DefaultMode\:3002
   
   \:8a2d\:8a08\:610f\:56f3:
   - Plan/Draft/Reduce/Commit (\:5b9f\:88c5\:7cfb\:3067\:5e83\:3044\:77e5\:8b58\:304c\:8981\:308b) \[RightArrow] Summary
   - Verify/Explore (\:691c\:8a3c/\:63a2\:7d22: \:8efd\:91cf) \[RightArrow] Index
   - ConfidentialDraft (\:6a5f\:5bc6\:6271\:3044\:3001\:6700\:5c0f\:5316\:3057\:305f\:3044) \[RightArrow] Index *)
$ClaudeRoleDefaultMode = <|
  "Plan"    -> "Summary",
  "Draft"   -> "Summary",
  "Reduce"  -> "Summary",
  "Commit"  -> "Summary",
  "Verify"  -> "Index",
  "Explore" -> "Index",
  "ConfidentialDraft" -> "Index"
|>;

(* role \:5225 default MaxSkills\:3002result45 \:3067\:5168 role \:304c\:540c\:3058 5 skill \:3060\:3063\:305f\:554f\:984c\:306b
   \:4ed8\:968f\:3059\:308b\:91cf\:7684\:8abf\:6574\:3002Verify/Explore \:306f 3 skill \:306b\:7d5e\:308a\:3001ConfidentialDraft \:306f 2 \:306b\:3002 *)
$ClaudeRoleMaxSkills = <|
  "Plan"              -> 5,
  "Draft"             -> 5,
  "Reduce"            -> 4,
  "Commit"            -> 4,
  "Verify"            -> 3,
  "Explore"           -> 3,
  "ConfidentialDraft" -> 2
|>;

(* Phase 28: tuple \:30ad\:30fc {provider, model} \:5bfe\:5fdc\:3002
   \:65e7 String \:30ad\:30fc\:7248\:3082\:4e92\:63db\:6027\:306e\:305f\:3081\:6b8b\:3057\:3001
   \:305d\:306e\:5834\:5408\:306f spec \:306e Provider \:30d5\:30a3\:30fc\:30eb\:30c9\:304b\:3089 tuple \:3092\:69cb\:7bc9\:3057\:3066\:767b\:9332\:3059\:308b\:3002 *)
ClaudeRegisterModelCapability[{provider_String, model_String}, spec_Association] :=
  ($ClaudeModelCapabilities[{provider, model}] = spec);

ClaudeRegisterModelCapability[name_String, spec_Association] :=
  Module[{prov},
    prov = Lookup[spec, "Provider", "anthropic"];
    $ClaudeModelCapabilities[{prov, name}] = spec
  ];

(* iNormalizeModelName: provider/model \:5f62\:5f0f\:304b\:3089 model \:90e8\:5206\:3060\:3051\:53d6\:308a\:51fa\:3059 *)
iNormalizeModelName[name_String] :=
  If[StringContainsQ[name, "/"],
    Last[StringSplit[name, "/"]],
    name];
iNormalizeModelName[_] := "";

(* iGuessProvider: \:6b63\:898f\:5316\:6e08\:307f\:30e2\:30c7\:30eb\:540d\:304b\:3089 Provider \:540d\:3092\:63a8\:5b9a\:3059\:308b\:3002
   provider \:540d\:306f\:534a\:5e74\:301c\:6570\:5e74\:5358\:4f4d\:3067\:5b89\:5b9a (anthropic/openai/lm-studio) \:306a\:306e\:3067
   \:30b3\:30fc\:30c9\:306b\:66f8\:3044\:3066\:3088\:3044\:3002\:30e2\:30c7\:30eb\:679d\:756a\:306f\:66f8\:304b\:306a\:3044 (rules/02 \:6e96\:62e0)\:3002 *)
iGuessProvider[name_String] :=
  Which[
    StringTrim[name] === "",          "anthropic",
    StringStartsQ[name, "claude-"] ||
      StringStartsQ[name, "claude/"], "anthropic",
    StringStartsQ[name, "qwen"],      "lm-studio",
    StringStartsQ[name, "gpt-oss"],   "lm-studio",     (* OSS \:7cfb: OpenAI \:3088\:308a\:512a\:5148 *)
    StringStartsQ[name, "gpt-"] ||
      StringStartsQ[name, "gpt"],     "openai",
    StringStartsQ[name, "o1-"] ||
      StringStartsQ[name, "o3-"],     "openai",        (* OpenAI \:63a8\:8ad6\:30e2\:30c7\:30eb\:7cfb *)
    True,                             "unknown"
  ];
iGuessProvider[_] := "unknown";

(* iClassRank: Class \:6587\:5b57\:5217\:304b\:3089\:512a\:5148\:5ea6\:3092\:8fd4\:3059\:3002Heavy > Mid > Light\:3002
   \:540c\:4e00 Provider \:5185\:3067\:300c\:6700\:5f37\:306e\:767b\:9332\:30e2\:30c7\:30eb\:300d\:3092\:30d5\:30a9\:30fc\:30eb\:30d0\:30c3\:30af\:5148\:3068\:3057\:3066\:9078\:3076\:306e\:306b\:4f7f\:3046\:3002 *)
iClassRank[class_String] :=
  Which[
    StringContainsQ[class, "Heavy"], 3,
    StringContainsQ[class, "Mid"],   2,
    StringContainsQ[class, "Light"], 1,
    True,                            0
  ];
iClassRank[_] := 0;

(* iSelectFallbackForProvider: \:6307\:5b9a Provider \:306e\:767b\:9332\:6e08\:307f\:30e2\:30c7\:30eb\:304b\:3089
   Class \:304c\:6700\:3082\:5f37\:3044\:3082\:306e\:3092 1 \:3064\:9078\:3093\:3067\:8fd4\:3059\:3002\:540c Provider \:306b\:767b\:9332\:30e2\:30c7\:30eb\:304c
   \:7121\:3051\:308c\:3070 None\:3002 *)
iSelectFallbackForProvider[provider_String] :=
  Module[{candidates, sorted},
    candidates = Select[
      Normal[$ClaudeModelCapabilities],
      Lookup[Last[#], "Provider", ""] === provider &];
    If[candidates === {}, Return[None]];
    sorted = SortBy[candidates,
      -iClassRank[Lookup[Last[#], "Class", ""]] &];
    Last[First[sorted]]
  ];
iSelectFallbackForProvider[_] := None;

(* iPrefixMatchCapability: \:5b8c\:5168\:4e00\:81f4\:3057\:306a\:3044\:30e2\:30c7\:30eb\:540d\:3092 Capability \:306b\:89e3\:6c7a\:3059\:308b\:3002
   \:30e2\:30c7\:30eb\:679d\:756a\:3092\:30b3\:30fc\:30c9\:5206\:5c90\:306b\:66f8\:304b\:305a\:3001Provider \:5358\:4f4d\:306e\:6c4e\:7528\:5224\:5b9a\:3060\:3051\:3067\:51e6\:7406\:3059\:308b
   (rules/02-llm-instructions-not-in-source.md \:6e96\:62e0)\:3002

   \:65b9\:91dd:
     1. \:540d\:524d\:304b\:3089 Provider \:3092\:63a8\:5b9a
     2. \:540c Provider \:306b\:767b\:9332\:3055\:308c\:305f\:6700\:5f37\:30e2\:30c7\:30eb (Heavy > Mid > Light) \:3092\:8fd4\:3059
     3. Provider \:304c unknown \:306a\:3089 conservative default

   \:7d50\:679c: \:65b0\:3057\:3044\:30e2\:30c7\:30eb\:679d\:756a\:304c\:51fa\:3066\:304d\:3066\:3082\:3001Capability \:30c6\:30fc\:30d6\:30eb\:306b\:767b\:9332\:3059\:308b\:3060\:3051\:3067
   \:3053\:306e\:30b3\:30fc\:30c9\:306b\:624b\:3092\:5165\:308c\:308b\:5fc5\:8981\:304c\:306a\:3044\:3002 *)
iPrefixMatchCapability[modelName_String] :=
  Module[{normalized, provider, fallback},
    normalized = iNormalizeModelName[modelName];

    (* \:7a7a\:6587\:5b57\:5217 / \:7a7a\:767d\:306e\:307f: claudecode.wl \:306e\:6163\:7fd2\:3068\:3057\:3066
       Anthropic Claude \:30c7\:30d5\:30a9\:30eb\:30c8\:30e2\:30c7\:30eb\:60f3\:5b9a *)
    If[!StringQ[normalized] || StringTrim[normalized] === "",
      provider = "anthropic",
      provider = iGuessProvider[normalized]
    ];

    fallback = iSelectFallbackForProvider[provider];
    If[AssociationQ[fallback], Return[fallback]];

    (* \:5305\:62ec Provider \:5224\:5b9a\:306f\:3067\:304d\:305f\:304c\:305d\:306e Provider \:306e\:30e2\:30c7\:30eb\:304c
       \:4e00\:3064\:3082\:767b\:9332\:3055\:308c\:3066\:3044\:306a\:3044 / \:307e\:305f\:306f provider="unknown"\:306e\:5834\:5408\:3001
       conservative default \:3092\:8fd4\:3059 *)
    <|"ContextWindow"    -> 32000,
      "Class"            -> "Unknown",
      "DefaultMode"      -> "Summary",
      "Strengths"        -> {},
      "PreserveThinking" -> False,
      "Provider"         -> provider|>
  ];

ClaudeResolveModelCapability[modelName_String] :=
  Module[{normalized, exact},
    normalized = iNormalizeModelName[modelName];
    (* 1. \:5b8c\:5168\:4e00\:81f4\:3092\:512a\:5148 *)
    exact = Lookup[$ClaudeModelCapabilities, normalized, None];
    If[AssociationQ[exact], Return[exact]];
    (* 2. \:5143\:306e\:6587\:5b57\:5217\:3067\:3082\:5b8c\:5168\:4e00\:81f4\:3092\:8a66\:3059 (provider/ \:4ed8\:304d\:3067\:767b\:9332\:3055\:308c\:305f\:5834\:5408) *)
    exact = Lookup[$ClaudeModelCapabilities, modelName, None];
    If[AssociationQ[exact], Return[exact]];
    (* 3. \:30d7\:30ec\:30d5\:30a3\:30c3\:30af\:30b9\:30d5\:30a9\:30fc\:30eb\:30d0\:30c3\:30af *)
    iPrefixMatchCapability[modelName]
  ];

ClaudeResolveModelCapability[___] := ClaudeResolveModelCapability[""];

ClaudeResolveModelMode[modelName_String] :=
  Lookup[ClaudeResolveModelCapability[modelName], "DefaultMode", "Summary"];

ClaudeResolveModelContextWindow[modelName_String] :=
  Lookup[ClaudeResolveModelCapability[modelName], "ContextWindow", 32000];


(* \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550
   3. Token estimate
   
   \:82f1\:65e5\:6df7\:5728\:3092\:8003\:616e\:3057\:3001\:6587\:5b57\:6570 / 3 \:3067\:8fd1\:4f3c\:3059\:308b\:3002
   - \:7d14\:82f1\:6587: \:7d04 4 \:6587\:5b57/token
   - \:7d14\:65e5\:6587: \:7d04 1.5\:301c2 \:6587\:5b57/token (UTF-8 multi-byte \:8003\:616e)
   - \:5e73\:5747: \:7d04 3 \:6587\:5b57/token \:3068\:3057\:3066\:4fdd\:5b88\:7684\:306b\:8fd1\:4f3c
   \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550 *)

ClaudeDirectiveTokenEstimate[text_String] :=
  Max[1, Ceiling[StringLength[text] / 3]];

ClaudeDirectiveTokenEstimate[item_Association] :=
  ClaudeDirectiveTokenEstimate[
    Lookup[item, "Body", Lookup[item, "Content", ""]]];

ClaudeDirectiveTokenEstimate[items_List] :=
  Total[ClaudeDirectiveTokenEstimate /@ items];

ClaudeDirectiveTokenEstimate[_] := 0;


(* \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550
   4. Frontmatter \:30d1\:30fc\:30b5
   
   SKILL.md / rules/*.md \:306f\:5148\:982d\:306b YAML \:98a8 frontmatter \:3092\:6301\:3064:
     ---
     name: skill-name
     description: usage description
     ---
     
     # \:672c\:6587...
   
   \:5b8c\:5168\:306a YAML \:30d1\:30fc\:30b5\:306f\:4e0d\:8981\:3002key: value \:306e\:5358\:7d14\:884c\:3060\:3051\:3092\:6271\:3046\:3002
   \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550 *)

(* v0.1.10 (Phase 35 stage1): YAML list \:5f62\:5f0f\:306e frontmatter \:306b\:5bfe\:5fdc\:3002
   \:5f93\:6765\:306f key: value \:306e\:5358\:4e00\:884c\:306e\:307f\:6271\:3063\:3066\:3044\:305f\:304c\:3001\:4ee5\:4e0b\:306e list \:5f62\:5f0f\:3082\:89e3\:91c8\:3059\:308b:
     keywords:
       - "\:30b9\:30e9\:30a4\:30c9"
       - "\:30d7\:30ec\:30bc\:30f3"
   value \:306b\:7a7a\:6587\:5b57\:5217\:306e key \:306f\:6b21\:884c\:4ee5\:964d\:306e "  - item" \:3092\:96c6\:3081\:3066 List \:5024\:306b\:3059\:308b\:3002 *)
iParseFrontmatter[text_String] :=
  Module[{lines, restLines, sepIdx, fmText, body, fmLines, kvs = <||>,
          curKey = None, curList = {}, n, line, m,
          blockKey = None, blockLines = {}, blockIndent = 0,
          curIndentOf},
    (* leading-whitespace width of a line *)
    curIndentOf = Function[ln,
      If[StringQ[ln],
        StringLength[ln] - StringLength[
          StringReplace[ln, RegularExpression["^\\s+"] -> ""]],
        0]];
    lines = Select[StringSplit[text, "\n"], StringQ];
    If[Length[lines] < 2 || StringTrim[First[lines]] =!= "---",
      Return[<|"Frontmatter" -> <||>, "Body" -> text|>]];
    restLines = Select[Rest[lines], StringQ];
    sepIdx = FirstPosition[restLines,
      _?(StringQ[#] && StringMatchQ[StringTrim[#], "---"] &), {0}, 1];
    sepIdx = If[ListQ[sepIdx] && Length[sepIdx] >= 1, First[sepIdx], 0];
    If[sepIdx === 0,
      Return[<|"Frontmatter" -> <||>, "Body" -> text|>]];
    fmText = StringRiffle[Take[restLines, sepIdx - 1], "\n"];
    body   = StringRiffle[Drop[restLines, sepIdx], "\n"];

    fmLines = StringSplit[fmText, "\n"];
    n = Length[fmLines];
    Do[
      line = fmLines[[i]];
      Which[
        (* \:30d6\:30ed\:30c3\:30af\:30b9\:30ab\:30e9\:30fc (| \:307e\:305f\:306f >) \:53ce\:96c6\:4e2d:
           blockIndent \:3088\:308a\:6df1\:3044\:30a4\:30f3\:30c7\:30f3\:30c8\:884c\:307e\:305f\:306f\:7a7a\:884c\:306f
           \:305d\:306e key \:306e\:5024\:306b\:8ffd\:52a0\:3059\:308b\:3002\:6d45\:3044\:30a4\:30f3\:30c7\:30f3\:30c8\:884c\:304c
           \:6765\:305f\:3089 block \:3092\:78ba\:5b9a\:3057\:3066\:901a\:5e38\:51e6\:7406\:306b\:623b\:308b\:3002 *)
        StringQ[blockKey] &&
          (StringTrim[line] === "" ||
           curIndentOf[line] >= blockIndent),
          blockLines = Append[blockLines, StringTrim[line]],

        (* \:7a7a\:884c\:30fb\:30b3\:30e1\:30f3\:30c8\:884c\:306f\:30b9\:30ad\:30c3\:30d7 *)
        !StringQ[line] || StringTrim[line] === "" ||
          StringMatchQ[StringTrim[line], "#" ~~ ___],
          Null,

        (* \:30a4\:30f3\:30c7\:30f3\:30c8\:3055\:308c\:305f "- item" \:884c: \:76f4\:524d\:306e curKey \:306e List \:306b\:8ffd\:52a0 *)
        StringQ[curKey] && StringMatchQ[line,
          RegularExpression["^\\s+-\\s+.*$"]],
          m = StringCases[StringTrim[line],
            RegularExpression["^-\\s+\"?([^\"]*?)\"?\\s*$"] :> "$1"];
          If[Length[m] >= 1,
            curList = Append[curList, StringTrim[First[m]]]],

        (* "key: value" \:884c *)
        StringContainsQ[line, ":"],
          (* \:76f4\:524d\:306e list \:3092\:78ba\:5b9a *)
          If[StringQ[curKey] && Length[curList] > 0,
            kvs[curKey] = curList];
          (* \:76f4\:524d\:306e block scalar \:3092\:78ba\:5b9a *)
          If[StringQ[blockKey],
            kvs[blockKey] = StringRiffle[blockLines, "\n"];
            blockKey = None; blockLines = {}];
          curKey = None; curList = {};
          Module[{kv = StringSplit[line, ":", 2], k, v},
            If[Length[kv] === 2 && StringQ[kv[[1]]] && StringQ[kv[[2]]],
              k = StringTrim[kv[[1]]];
              v = StringTrim[kv[[2]]];
              Which[
                (* YAML block scalar: "key: |" / "key: >" / "key: |-" etc.
                   \:6b21\:884c\:4ee5\:964d\:306e\:30a4\:30f3\:30c7\:30f3\:30c8\:884c\:3092\:96c6\:3081\:3066 value \:306b\:3059\:308b\:3002 *)
                StringMatchQ[v, RegularExpression["^[|>][+-]?\\d*$"]],
                  blockKey = k; blockLines = {};
                  blockIndent = curIndentOf[line] + 1,
                (* value \:304c\:7a7a: \:6b21\:884c\:304b\:3089 list \:304c\:59cb\:307e\:308b\:53ef\:80fd\:6027 *)
                v === "",
                  curKey = k; curList = {},
                (* \:901a\:5e38\:306e scalar (\:524d\:5f8c\:306e \" \:3092\:5265\:304c\:3059) *)
                True,
                  kvs[k] = StringReplace[v,
                    {RegularExpression["^\""] -> "",
                     RegularExpression["\"$"] -> ""}]]]],
        True, Null
      ],
      {i, n}];
    (* \:30eb\:30fc\:30d7\:7d42\:4e86\:6642\:306b list \:304c\:6b8b\:3063\:3066\:3044\:308c\:3070\:78ba\:5b9a *)
    If[StringQ[curKey] && Length[curList] > 0,
      kvs[curKey] = curList];
    (* \:30eb\:30fc\:30d7\:7d42\:4e86\:6642\:306b block scalar \:304c\:6b8b\:3063\:3066\:3044\:308c\:3070\:78ba\:5b9a *)
    If[StringQ[blockKey],
      kvs[blockKey] = StringRiffle[blockLines, "\n"]];

    <|"Frontmatter" -> kvs, "Body" -> body|>
  ];

iParseFrontmatter[_] := <|"Frontmatter" -> <||>, "Body" -> ""|>;

(* \:30c6\:30b9\:30c8\:7528\:306b\:516c\:958b *)
ClaudeDirectivesParseFrontmatter[text_] := iParseFrontmatter[text];


(* \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550
   5. Directive Repository \:63a2\:7d22\:30fb\:8aad\:8fbc
   \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550 *)

iDirectiveRootCandidates[] :=
  DeleteDuplicates @ Select[
    {
      Quiet @ Check[
        If[StringQ[Global`$packageDirectory],
          FileNameJoin[{Global`$packageDirectory, "Claude Directives"}], Null],
        Null],
      Quiet @ Check[
        If[StringQ[Global`$packageDirectory],
          FileNameJoin[{Global`$packageDirectory, ".claude"}], Null],
        Null],
      Quiet @ Check[
        If[StringQ[Global`$packageDirectory],
          FileNameJoin[{Global`$packageDirectory,
            "GithubRepositories", "Claude Directives"}], Null],
        Null],
      Quiet @ Check[
        FileNameJoin[{NotebookDirectory[], "Claude Directives"}],
        Null],
      Quiet @ Check[
        FileNameJoin[{NotebookDirectory[], ".claude"}], Null],
      FileNameJoin[{Directory[], "Claude Directives"}],
      FileNameJoin[{Directory[], ".claude"}]
    },
    StringQ];

ClaudeFindDirectiveRoots[] := Select[iDirectiveRootCandidates[], DirectoryQ];

(* \:5358\:4e00\:306e rules/*.md \:3092\:8aad\:307f\:8fbc\:3093\:3067 Association \:5316 *)

iLoadRuleFile[path_String] :=
  Module[{raw, parsed, fm, body, name, desc},
    raw = Quiet @ Check[
      Block[{$CharacterEncoding = "UTF-8"},
        Import[path, "Text"]], ""];
    If[!StringQ[raw] || raw === "",
      Return[<|"Path" -> path, "Name" -> FileBaseName[path],
               "Description" -> "", "Body" -> "",
               "Tokens" -> 0, "Source" -> "rules"|>]];
    parsed = iParseFrontmatter[raw];
    fm     = parsed["Frontmatter"];
    body   = parsed["Body"];
    name   = Lookup[fm, "name", FileBaseName[path]];
    desc   = Lookup[fm, "description", ""];
    <|
      "Path"        -> path,
      "Name"        -> name,
      "Description" -> desc,
      "Body"        -> body,
      "Frontmatter" -> fm,
      "Tokens"      -> ClaudeDirectiveTokenEstimate[raw],
      "Source"      -> "rules"
    |>
  ];

(* \:5358\:4e00\:306e skills/<name>/SKILL.md \:3092\:8aad\:307f\:8fbc\:3093\:3067 Association \:5316 *)

iLoadSkillFile[skillDir_String] :=
  Module[{path, raw, parsed, fm, body, name, desc, tags, when},
    path = FileNameJoin[{skillDir, "SKILL.md"}];
    If[!FileExistsQ[path], Return[Missing["NoSkillMD"]]];
    raw = Quiet @ Check[
      Block[{$CharacterEncoding = "UTF-8"},
        Import[path, "Text"]], ""];
    If[!StringQ[raw] || raw === "",
      Return[<|"Path" -> path, "Name" -> FileBaseName[skillDir],
               "Description" -> "", "Body" -> "",
               "Tokens" -> 0, "Source" -> "skills"|>]];
    parsed = iParseFrontmatter[raw];
    fm     = parsed["Frontmatter"];
    body   = parsed["Body"];
    name   = Lookup[fm, "name", FileBaseName[skillDir]];
    desc   = Lookup[fm, "description", ""];
    tags   = StringSplit[Lookup[fm, "tags", ""], "," | ", "];
    when   = Lookup[fm, "when_to_use", ""];
    <|
      "Path"        -> path,
      "Name"        -> name,
      "Description" -> desc,
      "Body"        -> body,
      "Frontmatter" -> fm,
      "Tags"        -> tags,
      "WhenToUse"   -> when,
      "Tokens"      -> ClaudeDirectiveTokenEstimate[raw],
      "Source"      -> "skills"
    |>
  ];

ClaudeLoadDirectiveRepository[] :=
  Module[{roots = ClaudeFindDirectiveRoots[]},
    If[roots === {},
      $ClaudeDirectiveRepository = <|"Root" -> None,
        "ClaudeMD" -> "", "Rules" -> {}, "Skills" -> {},
        "LoadedAt" -> AbsoluteTime[]|>;
      Return[$ClaudeDirectiveRepository]];
    ClaudeLoadDirectiveRepository[First[roots]]];

ClaudeLoadDirectiveRepository[root_String] :=
  Module[{claudeMDPath, claudeMD, rulesDir, ruleFiles, rules,
          skillsDir, skillDirs, skills},
    
    claudeMDPath = FileNameJoin[{root, "CLAUDE.md"}];
    claudeMD = If[FileExistsQ[claudeMDPath],
      Quiet @ Check[
        Block[{$CharacterEncoding = "UTF-8"},
          Import[claudeMDPath, "Text"]], ""],
      ""];
    If[!StringQ[claudeMD], claudeMD = ""];
    
    rulesDir = FileNameJoin[{root, "rules"}];
    ruleFiles = If[DirectoryQ[rulesDir],
      Sort @ FileNames["*.md", rulesDir], {}];
    rules = iLoadRuleFile /@ ruleFiles;
    rules = Select[rules, AssociationQ];
    
    skillsDir = FileNameJoin[{root, "skills"}];
    skillDirs = If[DirectoryQ[skillsDir],
      Select[FileNames["*", skillsDir], DirectoryQ], {}];
    skills = iLoadSkillFile /@ skillDirs;
    skills = Select[skills, AssociationQ];
    
    $ClaudeDirectiveRepository = <|
      "Root"       -> root,
      "ClaudeMD"   -> claudeMD,
      "ClaudeMDTokens" -> ClaudeDirectiveTokenEstimate[claudeMD],
      "Rules"      -> rules,
      "RulesCount" -> Length[rules],
      "Skills"     -> skills,
      "SkillsCount" -> Length[skills],
      "TotalTokens" ->
        ClaudeDirectiveTokenEstimate[claudeMD] +
        Total[Lookup[#, "Tokens", 0] & /@ rules] +
        Total[Lookup[#, "Tokens", 0] & /@ skills],
      "LoadedAt"   -> AbsoluteTime[]
    |>;
    $ClaudeDirectiveRepository
  ];

ClaudeInvalidateDirectiveCache[] :=
  ($ClaudeDirectiveRepository = None);

$ClaudeDirectiveRepository = None;


(* \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550
   6. Skill \:9078\:5225 (\:30ad\:30fc\:30ef\:30fc\:30c9 scoring)
   
   \:975e\:5e38\:306b\:30b7\:30f3\:30d7\:30eb\:306a token-overlap \:30b9\:30b3\:30a2\:30ea\:30f3\:30b0\:3002
   \:5c06\:6765\:7684\:306b\:306f embedding \:30d9\:30fc\:30b9\:306b\:5dee\:3057\:66ff\:3048\:308b\:524d\:63d0\:3060\:304c\:3001
   Phase 33 \:3067\:306f\:300c\:8efd\:91cf\:30e2\:30c7\:30eb\:3067 context \:3092\:7d5e\:308a\:8fbc\:3081\:308b\:304b\:300d\:3092
   \:5148\:306b\:691c\:8a3c\:3059\:308b\:76ee\:7684\:3067\:6700\:4f4e\:9650\:306e\:5b9f\:88c5\:306b\:7559\:3081\:308b\:3002
   \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550 *)

iTokenizeForMatch[text_String] :=
  Module[{englishTokens, japaneseTokens, allTokens},
    (* \:82f1\:6570\:5b57+_: \:5358\:8a9e\:5883\:754c\:3067\:62bd\:51fa *)
    englishTokens = ToLowerCase /@ Select[
      Quiet @ Check[
        StringCases[text, RegularExpression["[a-zA-Z0-9_]+"]], {}],
      StringLength[#] > 1 &];
    
    (* \:65e5\:672c\:8a9e: \:3072\:3089\:304c\:306a\:30fb\:30ab\:30bf\:30ab\:30ca\:30fb\:6f22\:5b57\:3092\:300c\:5225\:3005\:300d\:306b\:62bd\:51fa
       v0.1.6 \:6539\:826f: \:6587\:5b57\:7a2e\:5883\:754c\:3067\:5206\:5272\:3059\:308b\:3053\:3068\:3067\:8907\:5408\:8868\:73fe\:3092\:5206\:89e3\:3059\:308b\:3002
       \:4f8b: "\:30e1\:30fc\:30eb\:3092\:691c\:7d22" \[Rule] {"\:30e1\:30fc\:30eb", "\:691c\:7d22"} (\:30ab\:30ca + \:6f22\:5b57)
           "GitHub\:3067\:30d1\:30c3\:30b1\:30fc\:30b8\:3092\:66f4\:65b0" \[Rule] (\:82f1\:8a9e\:5225\:9014) + {"\:30d1\:30c3\:30b1\:30fc\:30b8", "\:66f4\:65b0"}
       \:3053\:308c\:306b\:3088\:3063\:3066\:65e5\:672c\:8a9e\:30ad\:30fc\:30ef\:30fc\:30c9\:30de\:30c3\:30c1\:306e\:7cbe\:5ea6\:304c\:5411\:4e0a\:3059\:308b\:3002
       v0.1.7 \:4fee\:6b63: \:9577\:97f3\:7b26 \:30fc (U+30FC) \:306f Unicode \:4e0a Common script \:3067
       \p{Katakana} \:306b\:30de\:30c3\:30c1\:3057\:306a\:3044\:305f\:3081 "\:30e1\:30fc\:30eb" \:304c\:5206\:65ad\:3055\:308c\:308b\:554f\:984c\:3092\:89e3\:6d88\:3002
       Katakana \:306e\:6587\:5b57\:30af\:30e9\:30b9\:306b \:30fc \:3092\:76f4\:63a5\:542b\:3081\:308b\:3002 *)
    japaneseTokens = Select[
      Quiet @ Check[
        StringCases[text,
          RegularExpression[
            "[\\p{Hiragana}]{2,}|[\\p{Katakana}\:30fc]{2,}|[\\p{Han}]{2,}"]],
        {}],
      StringLength[#] >= 2 &];
    
    (* \:82f1\:8a9e\:30c8\:30fc\:30af\:30f3\:306b `-` \:304c\:542b\:307e\:308c\:3066\:3044\:308c\:3070\:3001\:5206\:89e3\:7248\:3082\:8ffd\:52a0\:3059\:308b\:3002
       \:4f8b: "github-operations" \[Rule] {"github-operations", "github", "operations"} *)
    allTokens = Flatten[
      If[StringContainsQ[#, "-"],
        Join[{#}, Select[StringSplit[#, "-"], StringLength[#] > 1 &]],
        {#}
      ] & /@ englishTokens];
    
    DeleteDuplicates @ Join[allTokens, japaneseTokens]
  ];

iTokenizeForMatch[_] := {};

iScoreSkill[skill_Association, taskTokens_List, role_String,
            modelStrengths_List] :=
  Module[{score = 0, name, desc, when, body, tags, nameTokens,
          descTokens, whenTokens, bodyTokens},
    name       = ToLowerCase[Lookup[skill, "Name", ""]];
    desc       = ToLowerCase[Lookup[skill, "Description", ""]];
    when       = ToLowerCase[Lookup[skill, "WhenToUse", ""]];
    body       = ToLowerCase[StringTake[
      Lookup[skill, "Body", ""], UpTo[2000]]];
    tags       = ToLowerCase /@ Lookup[skill, "Tags", {}];
    
    nameTokens = iTokenizeForMatch[name];
    descTokens = iTokenizeForMatch[desc];
    whenTokens = iTokenizeForMatch[when];
    bodyTokens = iTokenizeForMatch[body];
    
    (* skill name \:304c task \:3068\:4e00\:81f4 +5 *)
    score += 5 * Length[Intersection[taskTokens, nameTokens]];
    (* description \:4e00\:81f4 +3 *)
    score += 3 * Length[Intersection[taskTokens, descTokens]];
    (* when_to_use \:4e00\:81f4 +4 *)
    score += 4 * Length[Intersection[taskTokens, whenTokens]];
    (* body \:5148\:982d\:4e00\:81f4 +1 *)
    score += 1 * Length[Intersection[taskTokens, bodyTokens]];
    
    (* role \:95a2\:9023\:30ef\:30fc\:30c9\:304c\:30e1\:30bf\:30c7\:30fc\:30bf\:306b\:3042\:308c\:3070 +4
       v0.1.7 \:4fee\:6b63: role = "" \:306e\:3068\:304d StringContainsQ[anything, ""] \:304c\:5e38\:306b True \:3092
       \:8fd4\:3059\:305f\:3081\:3001\:5168 skill \:306b +4 \:304c\:52a0\:7b97\:3055\:308c\:3066 maildb \:306e\:7d20\:306e\:30b9\:30b3\:30a2\:304c 4 \:306b\:306a\:308b
       \:30d0\:30b0\:3092\:89e3\:6d88\:3002\:7a7a\:6587\:5b57\:5217\:306e role \:3067\:306f\:52a0\:70b9\:3057\:306a\:3044\:3002 *)
    Module[{roleLC = ToLowerCase[role]},
      If[roleLC =!= "" &&
           StringContainsQ[name <> " " <> desc <> " " <> when, roleLC],
        score += 4]];
    
    (* role policy bonus +6 (v0.1.9 \:3067\:8ffd\:52a0)
       result45.nb \:3067\:5168 role \:304c\:540c\:3058 skill \:96c6\:5408\:306b\:306a\:308b\:554f\:984c\:306e\:6839\:672c\:5bfe\:51e6\:3002
       skill name \:304c $ClaudeSkillRolePolicy[role] \:306b\:542b\:307e\:308c\:308c\:3070 +6 \:52a0\:70b9\:3057\:3066
       role \:5225\:306b skill \:96c6\:5408\:304c\:5206\:5316\:3059\:308b\:3088\:3046\:306b\:3059\:308b\:3002
       \:4e00\:81f4\:6bd4\:8f03\:306f ToLowerCase \:3067\:6b63\:898f\:5316\:3002 *)
    If[StringQ[role] && role =!= "" &&
       AssociationQ[$ClaudeSkillRolePolicy] &&
       KeyExistsQ[$ClaudeSkillRolePolicy, role],
      Module[{policyLC, skillName},
        skillName = ToLowerCase[Lookup[skill, "Name", ""]];
        policyLC = ToLowerCase /@ Lookup[$ClaudeSkillRolePolicy, role, {}];
        If[MemberQ[policyLC, skillName],
          score += 6]]];
    
    (* model strengths \:3068\:306e\:4ea4\:5dee
       v0.1.6 \:6539\:826f: generic \:3059\:304e\:308b strengths \:306f\:9664\:5916\:3057\:3066 specific \:306a\:80fd\:529b\:306e\:307f\:52a0\:70b9\:3059\:308b\:3002
       Code / Reasoning / ToolUse / LongContext \:306f\:591a\:304f\:306e skill description \:306b\:542b\:307e\:308c\:3001
       \:5168 skill \:306e\:30b9\:30b3\:30a2\:3092\:5e95\:4e0a\:3052\:3057\:3066\:9078\:5225\:7cbe\:5ea6\:3092\:4e0b\:3052\:3066\:3057\:307e\:3046\:305f\:3081\:9664\:5916\:3059\:308b\:3002
       \:6b8b\:308b specific \:306a strengths (\:4f8b: Search, Multimodal, Multilingual, Math \:7b49)
       \:306f skill \:3068\:306e\:95a2\:9023\:6027\:304c\:9ad8\:3044\:306e\:3067 +2 \:3092\:7dad\:6301\:3059\:308b\:3002 *)
    Module[{strengthsLC, excludeGeneric, skillTokens},
      excludeGeneric = {"code", "reasoning", "tooluse", "longcontext"};
      strengthsLC = Complement[ToLowerCase /@ modelStrengths, excludeGeneric];
      skillTokens = Join[nameTokens, descTokens, tags];
      score += 2 * Length[Intersection[strengthsLC, skillTokens]]];
    
    score
  ];

Options[ClaudeSelectSkillsForTask] = {
  "Role"           -> None,
  "MaxSkills"      -> 5,
  "ModelStrengths" -> {},
  "MinScore"       -> 1
};

ClaudeSelectSkillsForTask[repo_Association, taskHint_String,
                           opts:OptionsPattern[]] :=
  Module[{skills, taskTokens, role, maxSkills, strengths, minScore,
          scored, sorted},
    skills      = Lookup[repo, "Skills", {}];
    taskTokens  = iTokenizeForMatch[taskHint];
    role        = OptionValue["Role"];
    maxSkills   = OptionValue["MaxSkills"];
    strengths   = OptionValue["ModelStrengths"];
    minScore    = OptionValue["MinScore"];
    
    If[!StringQ[role], role = ""];
    
    scored = (
      <|"Skill" -> #,
        "Score" -> iScoreSkill[#, taskTokens, role, strengths]|>
      ) & /@ skills;
    
    sorted = SortBy[Select[scored, #["Score"] >= minScore &],
      -#["Score"] &];
    
    Take[#["Skill"] & /@ sorted, UpTo[maxSkills]]
  ];

ClaudeSelectSkillsForTask[___] := {};


(* \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550
   7. Rules \:9078\:5225 (Phase 35 stage1: TaskHint \:30d9\:30fc\:30b9\:306e\:52d5\:7684\:9078\:5225)

   Phase 33-34 \:3067\:306f rules \:306f always-on \:3067\:5168\:4ef6\:8fd4\:3057\:3066\:3044\:305f\:304c\:3001
   Claude Directives \:306e rules \:5408\:8a08\:304c ~33K tokens \:306b\:9054\:3057\:3066
   ClaudeEval 1 \:56de\:3067 input prompt \:306e\:5927\:534a\:3092\:5360\:3081\:308b\:539f\:56e0\:306b\:306a\:3063\:3066\:3044\:305f\:3002

   Phase 35 \:3067 3 \:6bb5\:968e\:306e\:30ed\:30fc\:30c9\:65b9\:5f0f\:306b\:5909\:66f4:

     a) Always-on (\:5e38\:6642\:5fc5\:9808): \:30bb\:30ad\:30e5\:30ea\:30c6\:30a3\:30fb\:57fa\:672c\:30de\:30ca\:30fc\:7cfb\:3002
        $ClaudeAlwaysOnRules \:306b\:660e\:793a\:3002
        \:4f8b: 00-autoeval-prohibited, 01-wolfram-general,
            12-function-name-verification, 20-api-key-security,
            30-encoding-safety, 60-confidential-structure

     b) Keyword-triggered: frontmatter \:306e keywords / paths \:3084
        \:30d5\:30a1\:30a4\:30eb\:540d\:306e\:30d2\:30f3\:30c8\:8a9e\:304c TaskHint \:3068\:4ea4\:5dee\:3057\:305f\:3089\:30ed\:30fc\:30c9\:3002
        \:4f8b: 80-package-operations \:306f task \:306b "package", "\:66f4\:65b0", "\:8ffd\:52a0"
            \:7b49\:306e\:30c8\:30fc\:30af\:30f3\:304c\:542b\:307e\:308c\:308b\:3068\:304d\:306b\:63a1\:7528\:3002

     c) Score 0 \:306e\:30eb\:30fc\:30eb\:306f\:30ed\:30fc\:30c9\:3057\:306a\:3044\:3002

   \:65e2\:5b58\:306e ClaudeSelectRulesForRole \:306f\:5f8c\:65b9\:4e92\:63db\:306e\:305f\:3081\:6b8b\:3059\:3002
   \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550 *)

(* \:30bb\:30ad\:30e5\:30ea\:30c6\:30a3\:30fb\:57fa\:672c\:30de\:30ca\:30fc\:7cfb\:306e rule \:540d\:4e00\:89a7\:3002
   FileBaseName \:30d9\:30fc\:30b9\:306e\:540d\:524d\:3067\:8a18\:8ff0\:3059\:308b (frontmatter \:306b name \:304c\:7121\:3044\:3068\:304d
   FileBaseName \:304c iLoadRuleFile \:3067 Name \:306b\:4f7f\:308f\:308c\:308b\:524d\:63d0)\:3002
   \:5c06\:6765 frontmatter \:306e category: always-on \:3092\:898b\:308b\:3088\:3046\:306b\:767a\:5c55\:53ef\:80fd\:3002 *)
$ClaudeAlwaysOnRules := {
  "00-autoeval-prohibited",
  "01-wolfram-general",
  "12-function-name-verification",
  "13-prefer-existing-functions",
  "20-api-key-security",
  "30-encoding-safety",
  "50-file-path",
  "60-confidential-structure"
};

(* \:30bf\:30b9\:30af\:7279\:5b9a\:6027\:306e\:4f4e\:3044\:6c4e\:7528\:8a9e\:3002frontmatter keywords \:3068\:30bf\:30b9\:30af\:306e
   \:4ea4\:5dee\:3092\:53d6\:308b\:524d\:306b\:3053\:3053\:306b\:767b\:9332\:3055\:308c\:305f\:8a9e\:3092\:9664\:5916\:3059\:308b\:3053\:3068\:3067\:3001
   "\:5b9f\:884c" "\:30b3\:30fc\:30c9" "package" \:7b49\:306e\:983b\:51fa\:8a9e\:306b\:3088\:308b\:5168 rule \:3078\:306e
   \:8584\:3044\:30de\:30c3\:30c1\:3092\:9632\:3050\:3002
   \:30e6\:30fc\:30b6\:30fc\:5074\:3067 AppendTo[$ClaudeRuleSelectionStopWords, "..."] \:306b\:3088\:308a\:62e1\:5f35\:53ef\:80fd\:3002 *)
$ClaudeRuleSelectionStopWords := {
  (* \:82f1\:8a9e\:6c4e\:7528 *)
  "code", "data", "file", "files", "function", "functions",
  "name", "names", "value", "values", "result", "results",
  "error", "errors", "check", "note", "example", "examples",
  "case", "cases", "input", "output", "string", "list", "number",
  "use", "using", "used", "write", "writing", "running", "run", "make",
  "create", "creating", "update", "updating", "load", "read",
  "set", "get", "item", "items", "line", "lines", "level", "section",
  "step", "steps", "time", "format", "tag", "none", "true", "false",
  "claude", "claudecode", "mathematica", "wolfram",
  "package", "packages",
  (* \:65e5\:672c\:8a9e\:6c4e\:7528 *)
  "\:5b9f\:884c", "\:51e6\:7406", "\:95a2\:6570", "\:5834\:5408", "\:4ee5\:4e0b", "\:53c2\:7167", "\:5909\:6570", "\:8a2d\:5b9a", "\:5229\:7528",
  "\:78ba\:8a8d", "\:5fc5\:8981", "\:8ffd\:52a0", "\:524a\:9664", "\:5909\:66f4", "\:5bfe\:5fdc", "\:7d50\:679c", "\:5185\:5bb9",
  "\:53ef\:80fd", "\:5b9f\:88c5", "\:5bfe\:8c61", "\:5f15\:6570", "\:5b9a\:7fa9", "\:8868\:793a", "\:8a18\:8ff0", "\:64cd\:4f5c",
  "\:30b3\:30fc\:30c9", "\:30d5\:30a1\:30a4\:30eb", "\:307e\:3067\:306e", "\:305f\:3081", "\:3053\:3068", "\:3082\:306e",
  "\:3088\:3046\:306b", "\:3059\:308b", "\:3057\:3066", "\:3053\:308c", "\:305d\:308c", "\:3042\:308b", "\:306a\:3044", "\:304b\:3089"
};

(* iFilterStopWords: \:30c8\:30fc\:30af\:30f3\:5217\:304b\:3089 stop word \:3092\:9664\:5916\:3059\:308b *)
iFilterStopWords[tokens_List] :=
  Module[{stops},
    stops = If[ListQ[$ClaudeRuleSelectionStopWords],
      ToLowerCase /@ $ClaudeRuleSelectionStopWords, {}];
    Select[tokens, !MemberQ[stops, ToLowerCase[#]] &]];

iFilterStopWords[___] := {};

(* iRuleKeywords: rule \:304b\:3089 keyword \:5019\:88dc\:3092\:96c6\:3081\:308b\:3002
   \:512a\:5148\:5ea6: frontmatter \:306e keywords > \:30d5\:30a1\:30a4\:30eb\:540d\:306e\:30d2\:30f3\:30c8\:8a9e > \:672c\:6587 H1/H2 *)
iRuleKeywords[rule_Association] :=
  Module[{fm, kw = {}, name, body, headings},
    fm = Lookup[rule, "Frontmatter", <||>];

    (* 1. frontmatter \:306e keywords (List \:5f62\:5f0f\:307e\:305f\:306f ", " \:533a\:5207\:308a\:6587\:5b57\:5217) *)
    Module[{raw = Lookup[fm, "keywords", Lookup[fm, "Keywords", None]]},
      Which[
        ListQ[raw], kw = Join[kw, raw],
        StringQ[raw] && raw =!= "",
          kw = Join[kw, StringTrim /@ StringSplit[raw, "," | ", "]]]];

    (* 2. \:30d5\:30a1\:30a4\:30eb\:540d\:304b\:3089\:6570\:5b57 prefix \:3092\:9664\:3044\:3066 keyword \:5316
       "80-package-operations" -> {"package", "operations"} *)
    name = ToLowerCase[Lookup[rule, "Name", ""]];
    Module[{stripped, parts},
      stripped = StringReplace[name,
        RegularExpression["^[0-9]+\\-"] -> ""];
      parts = StringSplit[stripped, "-"];
      kw = Join[kw, Select[parts, StringLength[#] > 2 &]]];

    (* 3. \:672c\:6587 H1/H2 (# / ##) \:306e\:30c6\:30ad\:30b9\:30c8\:3092\:62bd\:51fa *)
    body = Lookup[rule, "Body", ""];
    headings = StringCases[body,
      RegularExpression["(?m)^#{1,2}\\s+(.+)$"] :> "$1"];
    kw = Join[kw, headings];

    DeleteDuplicates[
      Select[ToLowerCase /@ kw, StringQ[#] && StringLength[#] >= 2 &]]
  ];

iRuleKeywords[___] := {};

(* iRulePaths: rule \:306e frontmatter \:304b\:3089 paths \:3092\:53d6\:308a\:51fa\:3059\:3002
   List \:5f62\:5f0f\:307e\:305f\:306f ", " \:533a\:5207\:308a\:6587\:5b57\:5217\:3092 List<String> \:306b\:6b63\:898f\:5316\:3002 *)
iRulePaths[rule_Association] :=
  Module[{fm, raw},
    fm = Lookup[rule, "Frontmatter", <||>];
    raw = Lookup[fm, "paths", Lookup[fm, "Paths", None]];
    Which[
      ListQ[raw], Select[raw, StringQ],
      StringQ[raw] && raw =!= "",
        Select[StringTrim /@ StringSplit[raw, "," | ", "], # =!= "" &],
      True, {}]];

iRulePaths[___] := {};

(* iScoreRule: \:5358\:4e00 rule \:306b\:5bfe\:3057\:3066 TaskHint \:3068\:306e\:95a2\:9023\:30b9\:30b3\:30a2\:3092\:8fd4\:3059\:3002
   Always-on \:306f\:547c\:3073\:51fa\:3057\:5074\:3067\:5225\:7d4c\:8def\:306b\:3059\:308b\:305f\:3081\:3001\:3053\:3053\:3067\:306f\:30b9\:30b3\:30a2\:30ea\:30f3\:30b0\:306e\:307f\:3002
   \:30bf\:30b9\:30af\:7121\:3057 (taskTokens = {}) \:306e\:5834\:5408\:306f 0 \:3092\:8fd4\:3059\:3002

   Phase 35 stage1 \:306e\:8abf\:6574 (2026-04-29):
   - \:5168 token \:306b stop word filter \:3092\:9069\:7528\:3059\:308b (\:983b\:51fa\:6c4e\:7528\:8a9e\:3092\:9664\:5916)
   - body 1500 chars \:3068\:306e overlap \:52a0\:70b9 (+1) \:306f\:5ec3\:6b62
     \[RightArrow] \:300c\:5b9f\:884c\:300d\:300c\:30b3\:30fc\:30c9\:300d\:306e\:3088\:3046\:306a\:6c4e\:7528\:8a9e\:304c 1 \:70b9\:3092\:7a3c\:3044\:3067\:3057\:307e\:3044
        \:5168 rule \:306b\:30b9\:30b3\:30a2 1 \:304c\:4ed8\:3044\:3066 min_score=1 \:3067\:306f\:9664\:5916\:3057\:304d\:308c\:306a\:3044
        \:554f\:984c\:304c\:3042\:3063\:305f\:3002frontmatter / \:540d\:524d / \:898b\:51fa\:3057\:30d9\:30fc\:30b9\:306e\:5f37\:3044
        \:30b7\:30b0\:30ca\:30eb\:3060\:3051\:3067\:5224\:65ad\:3059\:308b\:3002 *)
iScoreRule[rule_Association, taskTokens_List, role_String] :=
  Module[{score = 0, taskFiltered, fmKw, headingTok, nameTok, name},
    name = ToLowerCase[Lookup[rule, "Name", ""]];

    (* \:30bf\:30b9\:30af\:30c8\:30fc\:30af\:30f3\:5074\:306b\:3082 stop word filter *)
    taskFiltered = iFilterStopWords[taskTokens];

    (* 1. frontmatter \:306e keywords (List \:5f62\:5f0f) \:3068\:306e\:76f4\:63a5\:4e00\:81f4 +6
       \:3053\:308c\:304c\:6700\:3082\:5f37\:3044\:30b7\:30b0\:30ca\:30eb\:3002frontmatter \:8a2d\:8a08\:3067\:610f\:56f3\:7684\:306b\:66f8\:304b\:308c\:305f\:8a9e\:3002 *)
    fmKw = Module[{fm = Lookup[rule, "Frontmatter", <||>], raw, tok = {}},
      raw = Lookup[fm, "keywords", Lookup[fm, "Keywords", None]];
      Which[
        ListQ[raw],
          Do[tok = Join[tok, iTokenizeForMatch[ToLowerCase[k]]],
            {k, Select[raw, StringQ]}],
        StringQ[raw] && raw =!= "",
          Do[tok = Join[tok, iTokenizeForMatch[ToLowerCase[k]]],
            {k, StringTrim /@ StringSplit[raw, "," | ", "]}]];
      DeleteDuplicates[iFilterStopWords[tok]]];
    score += 6 * Length[Intersection[taskFiltered, fmKw]];

    (* 2. \:30d5\:30a1\:30a4\:30eb\:540d\:30c8\:30fc\:30af\:30f3\:3068\:306e\:4e00\:81f4 +3
       \:4f8b: task \:306b "package" -> 80-package-operations \:306b\:30d2\:30c3\:30c8 *)
    nameTok = iFilterStopWords[
      iTokenizeForMatch[
        StringReplace[name, RegularExpression["^[0-9]+\\-"] -> ""]]];
    score += 3 * Length[Intersection[taskFiltered, nameTok]];

    (* 3. \:672c\:6587 H1/H2 \:898b\:51fa\:3057 +2
       \:898b\:51fa\:3057\:306f\:30bf\:30b9\:30af\:7279\:5b9a\:7684\:306a\:8a9e\:304c\:591a\:304f\:3001\:672c\:6587\:30d9\:30bf\:30de\:30c3\:30c1\:3088\:308a\:7cbe\:5ea6\:304c\:9ad8\:3044\:3002 *)
    headingTok = Module[{body = Lookup[rule, "Body", ""], hs, tok = {}},
      hs = Quiet @ Check[
        StringCases[body,
          RegularExpression["(?m)^#{1,2}\\s+(.+)$"] :> "$1"], {}];
      Do[tok = Join[tok, iTokenizeForMatch[ToLowerCase[h]]], {h, hs}];
      DeleteDuplicates[iFilterStopWords[tok]]];
    score += 2 * Length[Intersection[taskFiltered, headingTok]];

    score
  ];

iScoreRule[___] := 0;

(* iIsAlwaysOnRule: rule \:304c always-on \:304b\:3092\:5224\:5b9a\:3002
   $ClaudeAlwaysOnRules \:30ea\:30b9\:30c8\:3078\:306e membership \:3067\:6c7a\:5b9a\:3002 *)
iIsAlwaysOnRule[rule_Association] :=
  MemberQ[$ClaudeAlwaysOnRules, ToLowerCase[Lookup[rule, "Name", ""]]];

iIsAlwaysOnRule[___] := False;

(* TaskHint \:30d9\:30fc\:30b9\:306e rule \:9078\:5225\:3002
   - Always-on \:306f\:7121\:6761\:4ef6\:3067\:542b\:3081\:308b
   - \:6b8b\:308a\:306f iScoreRule \:306b\:3088\:308b\:30b9\:30b3\:30a2\:3067\:4e0a\:4f4d\:3092\:63a1\:7528 *)
Options[ClaudeSelectRulesForTask] = {
  "Role"     -> None,
  "MaxRules" -> 8,
  "MinScore" -> 2
};

ClaudeSelectRulesForTask[repo_Association, taskHint_String,
                          opts:OptionsPattern[]] :=
  Module[{rules, taskTokens, alwaysOn, candidates,
          role, maxRules, minScore, scored, sorted, picked},
    rules      = Lookup[repo, "Rules", {}];
    taskTokens = iTokenizeForMatch[taskHint];
    role       = OptionValue["Role"];
    maxRules   = OptionValue["MaxRules"];
    minScore   = OptionValue["MinScore"];

    If[!StringQ[role], role = ""];

    alwaysOn   = Select[rules, iIsAlwaysOnRule];
    candidates = Select[rules, !iIsAlwaysOnRule[#] &];

    scored = (
      <|"Rule"  -> #,
        "Score" -> iScoreRule[#, taskTokens, role]|>
      ) & /@ candidates;

    sorted = SortBy[Select[scored, #["Score"] >= minScore &],
      -#["Score"] &];
    picked = Take[#["Rule"] & /@ sorted, UpTo[maxRules]];

    Join[alwaysOn, picked]
  ];

ClaudeSelectRulesForTask[___] := {};

(* \:5f8c\:65b9\:4e92\:63db: \:5f79\:5272\:30d9\:30fc\:30b9\:306e rules \:9078\:5225\:3002
   \:73fe\:6642\:70b9\:3067\:306f always-on \:3068\:540c\:3058\:52d5\:4f5c\:3002Phase 36+ \:3067
   role \:5225\:306b notebook-mutation rule \:306e include/exclude \:3092\:5b9f\:88c5\:3059\:308b\:3002 *)
ClaudeSelectRulesForRole[repo_Association, role_:None] :=
  Lookup[repo, "Rules", {}];

ClaudeSelectRulesForRole[___] := {};


(* \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550
   8. Bundle \:89e3\:6c7a
   
   \:5165\:529b (role, model, mode, taskHint, budget) \:304b\:3089
   \:5b9f\:969b\:306b\:6ce8\:5165\:3059\:308b directive \:96c6\:5408\:3092\:6c7a\:3081\:308b\:3002
   
   mode = Automatic \:306e\:5834\:5408:
     1. model.DefaultMode \:3092\:63a1\:7528
     2. \:305f\:3060\:3057 bundle \:63a8\:5b9a token > budget \:306a\:3089\:6bb5\:968e\:7684\:306b\:964d\:683c
        Full -> Summary -> Index -> Lazy
   \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550 *)

iDowngradeMode[mode_String] :=
  Switch[mode,
    "Full",    "Summary",
    "Summary", "Index",
    "Index",   "Lazy",
    "Lazy",    "Lazy",
    _,         "Index"];

Options[ClaudeResolveDirectiveBundle] = {
  "Role"        -> None,
  "Model"       -> Automatic,
  "Mode"        -> Automatic,
  "TaskHint"    -> "",
  "TokenBudget" -> Automatic,
  "MaxSkills"   -> Automatic,  (* v0.1.9: 5 -> Automatic ($ClaudeRoleMaxSkills) *)
  (* Phase 1.1b (Codex spec 5.4): harness-target options.
     Target -> "Prompt" keeps the legacy behaviour unchanged. *)
  "Provider"                   -> Automatic,
  "Target"                     -> "Prompt",
  "HarnessMaterializationMode" -> Automatic
};

ClaudeResolveDirectiveBundle[opts:OptionsPattern[]] :=
  Module[{role, modelName, mode, taskHint, budget, maxSkills,
          repo, capability, strengths, claudeMD, rules, skills,
          tokens, finalMode, downgradeCount = 0},
    
    role       = OptionValue["Role"];
    modelName  = OptionValue["Model"];
    mode       = OptionValue["Mode"];
    taskHint   = OptionValue["TaskHint"];
    budget     = OptionValue["TokenBudget"];
    maxSkills  = OptionValue["MaxSkills"];
    
    (* 1. Repository \:53d6\:5f97 (\:30ad\:30e3\:30c3\:30b7\:30e5\:306a\:3051\:308c\:3070\:81ea\:52d5\:30ed\:30fc\:30c9) *)
    If[!AssociationQ[$ClaudeDirectiveRepository],
      ClaudeLoadDirectiveRepository[]];
    repo = $ClaudeDirectiveRepository;
    
    (* 2. Model -> Capability *)
    If[modelName === Automatic,
      modelName = If[StringQ[role] && KeyExistsQ[$ClaudeRoleDefaultModels, role],
        $ClaudeRoleDefaultModels[role],
        "claude-opus-5"]];
    
    capability = ClaudeResolveModelCapability[modelName];
    strengths  = Lookup[capability, "Strengths", {}];
    
    (* 3. Mode \:89e3\:6c7a
       v0.1.9: role \:304c $ClaudeRoleDefaultMode \:306b\:767b\:9332\:3055\:308c\:3066\:3044\:308c\:3070 role \:5225 default \:3092
       \:512a\:5148\:63a1\:7528\:3002\:672a\:767b\:9332\:306a\:3089 capability \:306e DefaultMode (\:5f93\:6765\:901a\:308a)\:3002 *)
    If[mode === Automatic,
      mode = Which[
        StringQ[role] && AssociationQ[$ClaudeRoleDefaultMode] &&
          KeyExistsQ[$ClaudeRoleDefaultMode, role],
          $ClaudeRoleDefaultMode[role],
        True,
          Lookup[capability, "DefaultMode", "Summary"]]];
    
    (* 4. TokenBudget \:89e3\:6c7a *)
    If[budget === Automatic,
      budget = Floor[
        Lookup[capability, "ContextWindow", 32000] * 0.3]];
    
    (* 4b. MaxSkills \:89e3\:6c7a
       v0.1.9: Automatic \:306e\:3068\:304d role \:5225 default \:3092\:63a1\:7528 (\:767b\:9332\:306a\:3051\:308c\:3070 5)\:3002 *)
    If[maxSkills === Automatic,
      maxSkills = Which[
        StringQ[role] && AssociationQ[$ClaudeRoleMaxSkills] &&
          KeyExistsQ[$ClaudeRoleMaxSkills, role],
          $ClaudeRoleMaxSkills[role],
        True, 5]];
    
    (* 5. directive \:9078\:5225
       Phase 35 stage1 (2026-04-29): rules \:3082 TaskHint \:3067\:9078\:5225\:3059\:308b\:3002
       TaskHint \:304c\:3042\:308c\:3070 ClaudeSelectRulesForTask\:3001\:7121\:3051\:308c\:3070
       always-on \:306e\:307f\:304c\:63a1\:7528\:3055\:308c\:308b (= \:65e7 ClaudeSelectRulesForRole \:3088\:308a\:3082
       \:8efd\:3044\:7d50\:679c\:306b\:306a\:308b\:70b9\:304c Phase 34 \:3068\:306e\:6319\:52d5\:5dee)\:3002 *)
    claudeMD = Lookup[repo, "ClaudeMD", ""];
    rules    = If[StringQ[taskHint] && taskHint =!= "",
      ClaudeSelectRulesForTask[repo, taskHint,
        "Role" -> If[StringQ[role], role, ""]],
      (* TaskHint \:4e0d\:660e\:6642: always-on \:306e\:307f\:8f09\:305b\:308b (\:5b89\:5168\:5074) *)
      Select[Lookup[repo, "Rules", {}], iIsAlwaysOnRule]];
    skills   = If[StringQ[taskHint] && taskHint =!= "",
      ClaudeSelectSkillsForTask[repo, taskHint,
        "Role" -> If[StringQ[role], role, ""],
        "MaxSkills" -> maxSkills,
        "ModelStrengths" -> strengths],
      Take[Lookup[repo, "Skills", {}], UpTo[maxSkills]]];
    
    (* 6. Mode \:964d\:683c\:5224\:5b9a: \:63a8\:5b9a token \:304c budget \:3092\:8d85\:3048\:308b\:306a\:3089
          \:4e0b\:4f4d\:30e2\:30fc\:30c9\:306b\:81ea\:52d5\:964d\:683c *)
    finalMode = mode;
    Module[{currentTokens},
      currentTokens = iEstimateBundleTokens[claudeMD, rules, skills, finalMode];
      While[currentTokens > budget && finalMode =!= "Lazy" &&
            downgradeCount < 3,
        finalMode = iDowngradeMode[finalMode];
        downgradeCount++;
        currentTokens = iEstimateBundleTokens[claudeMD, rules, skills, finalMode]]];
    
    <|
      "ClaudeMD"       -> claudeMD,
      "ActiveRules"    -> rules,
      "ActiveSkills"   -> skills,
      "ProjectionMode" -> finalMode,
      "TokenBudget"    -> budget,
      "DirectiveMeta"  -> <|
        "Role"             -> role,
        "Model"            -> modelName,
        "ModelClass"       -> Lookup[capability, "Class", "Unknown"],
        "ModelStrengths"   -> strengths,
        "RequestedMode"    -> mode,
        "DowngradeCount"   -> downgradeCount,
        "EstimatedTokens"  ->
          iEstimateBundleTokens[claudeMD, rules, skills, finalMode],
        "SelectedSkillNames" -> (Lookup[#, "Name", ""] &) /@ skills,
        "SelectedRuleNames"  -> (Lookup[#, "Name", ""] &) /@ rules
      |>
    |> ~Join~ iHarnessBundleMeta[OptionValue["Target"], OptionValue["Provider"], OptionValue["HarnessMaterializationMode"], repo]
  ];

(* mode \:306b\:5fdc\:3058\:305f token \:63a8\:5b9a *)

iEstimateBundleTokens[claudeMD_String, rules_List, skills_List,
                       mode_String] :=
  Module[{cmTok, rulesTok, skillsTok},
    cmTok = ClaudeDirectiveTokenEstimate[claudeMD];
    rulesTok = Total[Lookup[#, "Tokens", 0] & /@ rules];
    skillsTok = Total[Lookup[#, "Tokens", 0] & /@ skills];
    
    Switch[mode,
      "Full",
        cmTok + rulesTok + skillsTok,
      "Summary",
        (* v0.1.9-fix2: rules \:3082\:4e0a\:9650\:4ed8\:304d\:77ed\:7e2e\:3067\:5b9f\:614b\:3068\:6574\:5408\:3055\:305b\:308b\:3002
           iProjectSummary \:306f\:5404 rule \:3092 iSummarizeBody[..., 400] (400 chars
           \[TildeTilde] 133 tokens) \:306b\:5727\:7e2e\:3059\:308b\:305f\:3081\:3001\:898b\:7a4d\:3082\:308a\:3082 133 tokens \:4e0a\:9650\:3068\:3059\:308b\:3002
           skills \:306f iSummarizeBody[..., 600] = 200 tokens \:4e0a\:9650 (\:5f93\:6765\:901a\:308a)\:3002
           claudeMD \:306f iSummarizeBody[..., 3000] \[TildeTilde] 1000 tokens \:4e0a\:9650\:3002 *)
        Min[Floor[cmTok / 3], 1000] +
          Total[Min[Lookup[#, "Tokens", 0], 133] & /@ rules] +
          Total[Min[Lookup[#, "Tokens", 0], 200] & /@ skills],
      "Index",
        Floor[cmTok / 4] +
          Total[Min[Lookup[#, "Tokens", 0], 50] & /@ rules] +
          Total[ClaudeDirectiveTokenEstimate[
            Lookup[#, "Description", ""]] & /@ skills],
      "Lazy",
        Floor[cmTok / 4] +
          Length[skills] * 30,
      _,
        cmTok + rulesTok + skillsTok
    ]
  ];


(* \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550
   9. Projection (bundle -> prompt \:6587\:5b57\:5217)
   
   \:5404 mode \:306e\:51fa\:529b\:30b5\:30a4\:30ba\:76ee\:5b89 (\:5178\:578b\:7684\:306a\:73fe\:5728\:306e Claude Directives):
     Full:    \:7d04 30K tokens (\:5168\:6587)
     Summary: \:7d04 6K  tokens (\:672c\:6587\:306e\:5148\:982d\:30bb\:30af\:30b7\:30e7\:30f3\:3060\:3051)
     Index:   \:7d04 1K  tokens (name + description \:306e\:307f)
     Lazy:    \:7d04 0.5K tokens (skill \:540d\:4e00\:89a7 + on-demand \:6848\:5185)
   \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550 *)

iSummarizeBody[body_String, maxChars_Integer] :=
  Module[{trimmed},
    trimmed = StringTrim[body];
    If[StringLength[trimmed] <= maxChars,
      trimmed,
      StringTake[trimmed, maxChars] <> "\n... [truncated]"]];

iSummarizeBody[_, _] := "";

iProjectFull[bundle_Association] :=
  Module[{parts = {}, claudeMD, rules, skills},
    claudeMD = Lookup[bundle, "ClaudeMD", ""];
    rules    = Lookup[bundle, "ActiveRules", {}];
    skills   = Lookup[bundle, "ActiveSkills", {}];
    
    If[claudeMD =!= "",
      AppendTo[parts, "## Project guidelines (CLAUDE.md)\n\n" <> claudeMD]];
    
    If[Length[rules] > 0,
      AppendTo[parts, "## Rules (always-on)\n"];
      Do[
        AppendTo[parts,
          "### Rule: " <> Lookup[r, "Name", ""] <> "\n\n" <>
          Lookup[r, "Body", ""]],
        {r, rules}]];
    
    If[Length[skills] > 0,
      AppendTo[parts, "## Skills (selected)\n"];
      Do[
        AppendTo[parts,
          "### Skill: " <> Lookup[s, "Name", ""] <> "\n\n" <>
          Lookup[s, "Body", ""]],
        {s, skills}]];
    
    StringRiffle[parts, "\n\n---\n\n"]
  ];

iProjectSummary[bundle_Association] :=
  Module[{parts = {}, claudeMD, rules, skills},
    claudeMD = Lookup[bundle, "ClaudeMD", ""];
    rules    = Lookup[bundle, "ActiveRules", {}];
    skills   = Lookup[bundle, "ActiveSkills", {}];
    
    If[claudeMD =!= "",
      AppendTo[parts, "## Project guidelines (CLAUDE.md)\n\n" <>
        iSummarizeBody[claudeMD, 3000]]];
    
    If[Length[rules] > 0,
      AppendTo[parts, "## Rules (always-on)\n"];
      Do[
        AppendTo[parts,
          "- **" <> Lookup[r, "Name", ""] <> "**: " <>
          iSummarizeBody[Lookup[r, "Body", ""], 400]],
        {r, rules}]];
    
    If[Length[skills] > 0,
      AppendTo[parts, "## Skills (selected, summarized)\n"];
      Do[
        AppendTo[parts,
          "### " <> Lookup[s, "Name", ""] <> "\n" <>
          "_" <> Lookup[s, "Description", ""] <> "_\n\n" <>
          iSummarizeBody[Lookup[s, "Body", ""], 600]],
        {s, skills}]];
    
    StringRiffle[parts, "\n\n---\n\n"]
  ];

iProjectIndex[bundle_Association] :=
  Module[{parts = {}, claudeMD, rules, skills},
    claudeMD = Lookup[bundle, "ClaudeMD", ""];
    rules    = Lookup[bundle, "ActiveRules", {}];
    skills   = Lookup[bundle, "ActiveSkills", {}];
    
    If[claudeMD =!= "",
      AppendTo[parts, "## Project (CLAUDE.md, abridged)\n\n" <>
        iSummarizeBody[claudeMD, 800]]];
    
    If[Length[rules] > 0,
      AppendTo[parts, "## Rules\n" <>
        StringRiffle[
          ("- " <> Lookup[#, "Name", ""] <> ": " <>
            iSummarizeBody[Lookup[#, "Description", ""], 120]) & /@ rules,
          "\n"]]];
    
    If[Length[skills] > 0,
      AppendTo[parts, "## Available skills (request body if needed)\n" <>
        StringRiffle[
          ("- **" <> Lookup[#, "Name", ""] <> "**: " <>
            iSummarizeBody[Lookup[#, "Description", ""], 200]) & /@ skills,
          "\n"]]];
    
    StringRiffle[parts, "\n\n"]
  ];

iProjectLazy[bundle_Association] :=
  Module[{skills = Lookup[bundle, "ActiveSkills", {}], names},
    names = Lookup[#, "Name", ""] & /@ skills;
    "## Available skills (lazy mode)\n" <>
    "Request the body of any skill via follow-up turn:\n" <>
    StringRiffle["- " <> # & /@ names, "\n"] <>
    "\n\nUse: \"Please show skill: <name>\" to expand a skill on demand."
  ];

ClaudeProjectDirectives[bundle_Association] :=
  ClaudeProjectDirectives[bundle,
    Lookup[bundle, "ProjectionMode", "Summary"]];

ClaudeProjectDirectives[bundle_Association, mode_String] :=
  Switch[mode,
    "Full",    iProjectFull[bundle],
    "Summary", iProjectSummary[bundle],
    "Index",   iProjectIndex[bundle],
    "Lazy",    iProjectLazy[bundle],
    _,         iProjectSummary[bundle]];

ClaudeProjectDirectives[___] := "";


(* \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550
   10. \:7d71\:5408\:30a8\:30f3\:30c8\:30ea (claudecode / Orchestrator \:304b\:3089\:547c\:3076)
   \:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550\:2550 *)

ClaudeBuildDirectivePromptForRole[role_String, modelName_String,
                                    taskHint_String] :=
  Module[{bundle},
    bundle = ClaudeResolveDirectiveBundle[
      "Role" -> role,
      "Model" -> modelName,
      "TaskHint" -> taskHint];
    ClaudeProjectDirectives[bundle]];

ClaudeBuildDirectivePromptForRole[role_, model_, ___] :=
  ClaudeBuildDirectivePromptForRole[
    If[StringQ[role], role, ""],
    If[StringQ[model], model, "claude-opus-5"], ""];

ClaudeBuildDirectivePromptForSingle[modelName_String, taskHint_String] :=
  Module[{bundle},
    bundle = ClaudeResolveDirectiveBundle[
      "Role" -> None,
      "Model" -> modelName,
      "TaskHint" -> taskHint];
    ClaudeProjectDirectives[bundle]];

ClaudeBuildDirectivePromptForSingle[___] := "";



(* ===================================================================
   Phase 1.0: Directive Repository Inventory / Manifest / Hash
   Spec 5th review: sections 4.1, 5.2, 11.2, 15.1.
   These functions are SourceVault-independent and side-effect free
   (no global state mutation, no file writes).
   =================================================================== *)

(* ---- root argument resolution (spec 5.3) ---- *)

ClaudeResolveDirectiveRoot[Automatic] :=
  Module[{roots = ClaudeFindDirectiveRoots[]},
    If[roots === {},
      Failure["DirectiveRootNotFound",
        <|"Message" ->
            "No Claude Directives repository was found."|>],
      First[roots]]];

ClaudeResolveDirectiveRoot[root_String] :=
  If[DirectoryQ[root],
    root,
    Failure["DirectiveRootNotFound", <|"Root" -> root|>]];

ClaudeResolveDirectiveRoot[other_] :=
  Failure["DirectiveRootInvalid", <|"Given" -> other|>];

(* internal: normalise a root argument to an absolute, existing directory *)

iDirectiveResolveRootArg[Automatic] :=
  Module[{r = ClaudeResolveDirectiveRoot[Automatic]},
    If[FailureQ[r], r, ExpandFileName[r]]];

iDirectiveResolveRootArg[root_String] :=
  If[DirectoryQ[root],
    ExpandFileName[root],
    Failure["DirectiveRootNotFound", <|"Root" -> root|>]];

iDirectiveResolveRootArg[other_] :=
  Failure["DirectiveRootInvalid", <|"Given" -> other|>];

(* ---- per-file helpers ---- *)

(* SHA-256 of the raw file bytes, formatted as "sha256-<lowerhex>" *)
iDirectiveContentHash[path_String] :=
  Module[{h},
    h = Quiet @ Check[FileHash[path, "SHA256", "HexString"], $Failed];
    If[StringQ[h],
      "sha256-" <> ToLowerCase[h],
      Missing["HashFailed"]]];

iDirectiveContentHash[_] := Missing["HashFailed"];

(* relative path of absPath under root, normalised with "/" separators *)
iDirectiveRelativePath[root_String, absPath_String] :=
  Module[{rs, as},
    rs = FileNameSplit[ExpandFileName[root]];
    as = FileNameSplit[ExpandFileName[absPath]];
    If[Length[as] > Length[rs] && Take[as, Length[rs]] === rs,
      StringRiffle[Drop[as, Length[rs]], "/"],
      StringRiffle[as, "/"]]];

(* first Markdown heading in the body, used as Title *)
iDirectiveExtractTitle[body_String] :=
  Module[{m},
    m = StringCases[body,
      RegularExpression["(?m)^#+[ \\t]+(.+?)[ \\t]*$"] :> "$1", 1];
    If[Length[m] >= 1 && StringQ[First[m]] &&
       StringTrim[First[m]] =!= "",
      StringTrim[First[m]],
      Missing["NotAvailable"]]];

iDirectiveExtractTitle[_] := Missing["NotAvailable"];

(* normalise the frontmatter "paths" entry to a list of strings *)
iDirectiveNormalizePaths[fm_Association] :=
  Module[{p = Lookup[fm, "paths", Lookup[fm, "Paths", {}]]},
    Which[
      ListQ[p], Select[p, StringQ],
      StringQ[p] && StringTrim[p] =!= "", {StringTrim[p]},
      True, {}]];

iDirectiveNormalizePaths[_] := {};

(* build one inventory record.
   role   : "RootInstruction" | "Rule" | "Skill" | "Other"
   root   : repository root (absolute)
   absPath: absolute path of the file *)
iDirectiveFileRecord[role_String, root_String, absPath_String] :=
  Module[{relPath, raw, parsed, fm, body, title, name, desc,
          paths, bytes, lineCount, mtime, chash},
    relPath = iDirectiveRelativePath[root, absPath];
    chash   = iDirectiveContentHash[absPath];
    bytes   = Quiet @ Check[FileByteCount[absPath],
                Missing["NotAvailable"]];
    mtime   = Quiet @ Check[FileDate[absPath],
                Missing["NotAvailable"]];
    raw = Quiet @ Check[
      Block[{$CharacterEncoding = "UTF-8"},
        Import[absPath, "Text"]], ""];
    If[!StringQ[raw], raw = ""];
    lineCount = If[raw === "", 0, StringCount[raw, "\n"] + 1];
    parsed = iParseFrontmatter[raw];
    fm     = Lookup[parsed, "Frontmatter", <||>];
    body   = Lookup[parsed, "Body", raw];
    If[!AssociationQ[fm], fm = <||>];
    If[!StringQ[body], body = raw];
    title  = iDirectiveExtractTitle[body];
    paths  = iDirectiveNormalizePaths[fm];
    name   = Switch[role,
      "Rule",            FileBaseName[absPath],
      "Skill",           Lookup[fm, "name",
                           FileBaseName[DirectoryName[absPath]]],
      "RootInstruction", Missing["NotApplicable"],
      _,                 FileBaseName[absPath]];
    desc   = Lookup[fm, "description", Missing["NotAvailable"]];
    <|
      "Role"          -> role,
      "RelativePath"  -> relPath,
      "LogicalPath"   -> relPath,
      "AbsolutePath"  -> ExpandFileName[absPath],
      "ContentHash"   -> chash,
      "ByteCount"     -> bytes,
      "LineCount"     -> lineCount,
      "Name"          -> name,
      "Title"         -> title,
      "Description"   -> desc,
      "FrontMatter"   -> fm,
      "Paths"         -> paths,
      "TokenEstimate" -> ClaudeDirectiveTokenEstimate[raw],
      "ModifiedTime"  -> mtime
    |>];

(* ---- ClaudeDirectiveFileInventory ---- *)

Options[ClaudeDirectiveFileInventory] = {"IncludeOther" -> True};

ClaudeDirectiveFileInventory[rootArg_, opts:OptionsPattern[]] :=
  Module[{root, includeOther, records = {}, claudeMD,
          rulesDir, ruleFiles, skillsDir, skillDirs,
          rootMdFiles},
    root = iDirectiveResolveRootArg[rootArg];
    If[FailureQ[root], Return[root]];
    includeOther = TrueQ[OptionValue[
      ClaudeDirectiveFileInventory, {opts}, "IncludeOther"]];

    (* CLAUDE.md at the repository root *)
    claudeMD = FileNameJoin[{root, "CLAUDE.md"}];
    If[FileExistsQ[claudeMD],
      AppendTo[records,
        iDirectiveFileRecord["RootInstruction", root, claudeMD]]];

    (* rules/*.md *)
    rulesDir = FileNameJoin[{root, "rules"}];
    ruleFiles = If[DirectoryQ[rulesDir],
      Sort @ FileNames["*.md", rulesDir], {}];
    records = Join[records,
      Map[iDirectiveFileRecord["Rule", root, #] &, ruleFiles]];

    (* skills/<name>/SKILL.md *)
    skillsDir = FileNameJoin[{root, "skills"}];
    skillDirs = If[DirectoryQ[skillsDir],
      Sort @ Select[FileNames["*", skillsDir], DirectoryQ], {}];
    records = Join[records,
      Map[
        iDirectiveFileRecord["Skill", root,
          FileNameJoin[{#, "SKILL.md"}]] &,
        Select[skillDirs,
          FileExistsQ[FileNameJoin[{#, "SKILL.md"}]] &]]];

    (* other top-level *.md files (README.md etc.) *)
    If[includeOther,
      rootMdFiles = Select[
        Sort @ FileNames["*.md", root],
        FileBaseName[#] =!= "CLAUDE" &];
      records = Join[records,
        Map[iDirectiveFileRecord["Other", root, #] &, rootMdFiles]]];

    SortBy[records, Lookup[#, "RelativePath", ""] &]];

(* alias *)
Options[ClaudeDirectiveRepositoryInventory] =
  Options[ClaudeDirectiveFileInventory];

ClaudeDirectiveRepositoryInventory[rootArg_, opts:OptionsPattern[]] :=
  ClaudeDirectiveFileInventory[rootArg, opts];

(* ---- ManifestHash (spec 11.2) ----
   Computed ONLY from the sorted {RelativePath, ContentHash} pairs.
   ModifiedTime, TokenEstimate, ByteCount, LineCount, Role and
   AbsolutePath are intentionally excluded. *)

iDirectiveManifestHash[inv_List] :=
  Module[{pairs, canon},
    pairs = SortBy[
      Map[
        {ToString[Lookup[#, "RelativePath", ""]],
         ToString[Lookup[#, "ContentHash", ""]]} &,
        inv],
      First];
    canon = StringRiffle[
      Map[First[#] <> "\t" <> Last[#] &, pairs], "\n"];
    "sha256-" <>
      ToLowerCase[Hash[canon, "SHA256", "HexString"]]];

iDirectiveManifestHash[_] := Missing["NotAvailable"];

(* ---- ClaudeDirectiveRepositoryManifest ---- *)

Options[ClaudeDirectiveRepositoryManifest] =
  Options[ClaudeDirectiveFileInventory];

ClaudeDirectiveRepositoryManifest[rootArg_, opts:OptionsPattern[]] :=
  Module[{root, inv},
    root = iDirectiveResolveRootArg[rootArg];
    If[FailureQ[root], Return[root]];
    inv = ClaudeDirectiveFileInventory[root, opts];
    If[FailureQ[inv], Return[inv]];
    <|
      "Kind"            -> "DirectiveRepositoryManifest",
      "CanonicalFormat" -> "ClaudeDirectives",
      "Root"            -> root,
      "Files"           -> inv,
      "FilesCount"      -> Length[inv],
      "RulesCount"      ->
        Count[inv, KeyValuePattern["Role" -> "Rule"]],
      "SkillsCount"     ->
        Count[inv, KeyValuePattern["Role" -> "Skill"]],
      "ManifestHash"    -> iDirectiveManifestHash[inv],
      "CreatedAt"       -> Now,
      "Generator"       -> <|
        "Package" -> "claudecode_directives.wl",
        "Version" -> $ClaudeDirectivesVersion
      |>
    |>];

(* ---- ClaudeDirectiveRepositoryHash ---- *)

Options[ClaudeDirectiveRepositoryHash] =
  Options[ClaudeDirectiveFileInventory];

ClaudeDirectiveRepositoryHash[rootArg_, opts:OptionsPattern[]] :=
  Module[{m = ClaudeDirectiveRepositoryManifest[rootArg, opts]},
    If[FailureQ[m],
      m,
      Lookup[m, "ManifestHash", Missing["NotAvailable"]]]];


(* ===================================================================
   Phase 1.1a: rule derived metadata & classification
   Spec 5th review: sections 6.5.2 (derived metadata) and
   6.5.3 (rule classification). Pure functions over inventory records.
   =================================================================== *)

(* large-rule threshold; respect a value the user already set *)
If[!ValueQ[$CodexRuleLargeByteThreshold],
  $CodexRuleLargeByteThreshold = 8192];

(* file extensions that, inside a brace group, are NOT identifiers *)
$iCodexKnownExtensions = {
  "wl", "wls", "m", "nb", "cdf", "mx", "wxf",
  "md", "txt", "json", "csv", "tsv"};

(* humanise a rule file stem, e.g. "10-nbaccess" -> "Nbaccess" *)
iHumanizeStem[stem_String] :=
  Module[{s},
    s = StringReplace[stem,
      RegularExpression["^[0-9]+[-_]"] -> ""];
    s = StringReplace[s, "-" | "_" -> " "];
    s = StringTrim[s];
    If[s === "", stem, Capitalize[s, "AllWords"]]];

iHumanizeStem[_] := "";

(* shorten a string to roughly n characters *)
iShortenText[s_String, n_Integer] :=
  If[StringLength[s] <= n, s, StringTake[s, n] <> "..."];

iShortenText[_, _] := "";

(* identifier tokens found inside glob brace-groups
   (extension-only groups such as {wl,wls,m,nb} are not identifiers) *)
iRuleGlobIdentifiers[paths_List] :=
  Module[{groups, ids},
    groups = Flatten[
      Map[
        StringCases[#, "{" ~~ Shortest[g___] ~~ "}" :> g] &,
        Select[paths, StringQ]]];
    ids = Flatten[
      Map[
        Function[grp, StringTrim /@ StringSplit[grp, ","]],
        groups]];
    ids = Select[ids,
      StringQ[#] && # =!= "" &&
        !MemberQ[$iCodexKnownExtensions, ToLowerCase[#]] &];
    DeleteDuplicates[ids]];

iRuleGlobIdentifiers[_] := {};

(* a glob is "broad" when it targets essentially the whole repository:
   "*", "**/*", "**/*.<ext-group>" with no literal identifier *)
iGlobIsBroad[glob_String] :=
  iRuleGlobIdentifiers[{glob}] === {} &&
  StringMatchQ[glob,
    ("**/" | "*/" | "") ~~ "*" ~~ ("." ~~ ___ | "")];

iGlobIsBroad[_] := False;

(* derive a trigger sentence from the paths frontmatter (spec 6.5.2 #3) *)
iDeriveTriggerFromPaths[paths_List] :=
  Module[{ids},
    If[AnyTrue[paths, iGlobIsBroad],
      Return[
        "Use for general Wolfram Language, package, and notebook " <>
        "work matched by this rule."]];
    ids = iRuleGlobIdentifiers[paths];
    If[ids =!= {},
      Return[
        "Use when editing " <> StringRiffle[ids, " or "] <>
        " related files matched by this rule."]];
    "Use when editing paths matching " <>
      StringRiffle[Select[paths, StringQ], ", "] <> "."];

iDeriveTriggerFromPaths[_] :=
  "Use when editing paths matched by this rule.";

(* ---- ClaudeDirectiveRuleDerivedMetadata (spec 6.5.2) ---- *)

Options[ClaudeDirectiveRuleDerivedMetadata] = {
  "RuleMetadataOverrides" -> <||>};

ClaudeDirectiveRuleDerivedMetadata[
    ruleRecord_Association, opts:OptionsPattern[]] :=
  Module[{name, title0, paths, overrides, ov, title, summary,
          trigger, descSource, description},
    name   = ToString[Lookup[ruleRecord, "Name", ""]];
    title0 = Lookup[ruleRecord, "Title", Missing["NotAvailable"]];
    paths  = Lookup[ruleRecord, "Paths", {}];
    If[!ListQ[paths], paths = {}];

    overrides = OptionValue[ClaudeDirectiveRuleDerivedMetadata,
      {opts}, "RuleMetadataOverrides"];
    If[!AssociationQ[overrides], overrides = <||>];
    ov = Lookup[overrides, name, <||>];
    If[!AssociationQ[ov], ov = <||>];

    title = If[StringQ[title0] && StringTrim[title0] =!= "",
      title0, iHumanizeStem[name]];
    summary = iShortenText[title, 120];

    Which[
      KeyExistsQ[ov, "Trigger"] || KeyExistsQ[ov, "Description"],
        trigger = ToString[Lookup[ov, "Trigger",
          Lookup[ov, "Description", ""]]];
        descSource = "override",

      paths === {},
        trigger =
          "Use when the task appears related to " <>
          If[StringQ[title] && title =!= "", title, name] <>
          "; no path trigger was declared in the canonical rule.";
        descSource = "fallback",

      True,
        trigger = iDeriveTriggerFromPaths[paths];
        descSource = "derived-from-paths-and-heading"];

    description = ToString[Lookup[ov, "Description", trigger]];

    <|
      "Title"             -> title,
      "Summary"           -> summary,
      "Description"       -> description,
      "Trigger"           -> trigger,
      "DescriptionSource" -> descSource,
      "Paths"             -> paths
    |>];

ClaudeDirectiveRuleDerivedMetadata[___] := $Failed;

(* ---- ClaudeDirectiveClassifyRule (spec 6.5.3) ---- *)

Options[ClaudeDirectiveClassifyRule] = {
  "AlwaysOnRules"          -> Automatic,
  "RuleLargeByteThreshold" -> Automatic,
  "RuleMetadataOverrides"  -> <||>};

ClaudeDirectiveClassifyRule[
    ruleRecord_Association, opts:OptionsPattern[]] :=
  Module[{name, bytes, paths, threshold, alwaysOnList, alwaysOnLC,
          overrides, ov, sizeClass, explicitAlwaysOn, broadPaths,
          scope, commandPolicy, inlineSummary, reason},
    name  = ToString[Lookup[ruleRecord, "Name", ""]];
    bytes = Lookup[ruleRecord, "ByteCount", 0];
    paths = Lookup[ruleRecord, "Paths", {}];
    If[!ListQ[paths], paths = {}];

    threshold = OptionValue[ClaudeDirectiveClassifyRule,
      {opts}, "RuleLargeByteThreshold"];
    If[threshold === Automatic,
      threshold = $CodexRuleLargeByteThreshold];
    If[!IntegerQ[threshold], threshold = 8192];

    alwaysOnList = OptionValue[ClaudeDirectiveClassifyRule,
      {opts}, "AlwaysOnRules"];
    If[alwaysOnList === Automatic,
      alwaysOnList = $ClaudeAlwaysOnRules];
    If[!ListQ[alwaysOnList], alwaysOnList = {}];
    alwaysOnList = Select[alwaysOnList, StringQ];
    alwaysOnLC = ToLowerCase /@ alwaysOnList;

    overrides = OptionValue[ClaudeDirectiveClassifyRule,
      {opts}, "RuleMetadataOverrides"];
    If[!AssociationQ[overrides], overrides = <||>];
    ov = Lookup[overrides, name, <||>];
    If[!AssociationQ[ov], ov = <||>];

    sizeClass = If[IntegerQ[bytes] && bytes > threshold,
      "large", "small"];

    explicitAlwaysOn = MemberQ[alwaysOnLC, ToLowerCase[name]];
    broadPaths = AnyTrue[paths, iGlobIsBroad];

    scope = Which[
      KeyExistsQ[ov, "Scope"] &&
        MemberQ[{"always-on", "task-specific"},
          Lookup[ov, "Scope"]],
        Lookup[ov, "Scope"],
      explicitAlwaysOn, "always-on",
      alwaysOnList === {} && broadPaths, "always-on",
      True, "task-specific"];

    commandPolicy = TrueQ[Lookup[ov, "CommandPolicy", False]];

    (* candidate value; budget is applied later in HarnessPlan *)
    inlineSummary = (scope === "always-on" && sizeClass === "small");

    reason = {
      "size " <> ToString[bytes] <> " bytes vs threshold " <>
        ToString[threshold] <> " -> " <> sizeClass,
      Which[
        KeyExistsQ[ov, "Scope"],
          "scope from RuleMetadataOverrides",
        explicitAlwaysOn,
          "scope always-on: listed in AlwaysOnRules",
        scope === "always-on",
          "scope always-on: broad paths with empty AlwaysOnRules",
        True,
          "scope task-specific: not in AlwaysOnRules"],
      If[commandPolicy,
        "commandPolicy True from RuleMetadataOverrides",
        "commandPolicy False (default; .rules conversion is opt-in)"],
      "InlineSummaryInAgentsMd is a candidate; the final inline " <>
        "decision is re-evaluated against the AGENTS.md byte budget " <>
        "in ClaudeDirectiveHarnessPlan"};

    <|
      "Scope"                   -> scope,
      "SizeClass"               -> sizeClass,
      "CommandPolicy"           -> commandPolicy,
      "InlineSummaryInAgentsMd" -> inlineSummary,
      "Reason"                  -> reason
    |>];

ClaudeDirectiveClassifyRule[___] := $Failed;


(* ===================================================================
   Phase 1.1b-1: harness plan (dry-run)
   Spec 5th review: sections 5.2 / 5.4 / 6.3-6.6.
   ClaudeDirectiveHarnessPlan writes no files; it returns the plan.
   iHarnessBundleMeta is joined into the ClaudeResolveDirectiveBundle
   result so that Target -> "Prompt" stays behaviour-compatible.
   =================================================================== *)

(* ---- bundle harness metadata (spec 5.4 / 5.5) ---- *)

iHarnessBundleMeta[target_, provider_, hmm_, repo_] :=
  Module[{root, isHarness, mode, hash},
    isHarness = MemberQ[{"CodexHarness", "ClaudeHarness"}, target];
    root = Lookup[
      If[AssociationQ[repo], repo, <||>], "Root", None];
    mode = Which[
      !isHarness,             Missing["NotApplicable"],
      StringQ[hmm],           hmm,
      target === "ClaudeHarness", "DirectLegacy",
      True,                   "BootstrapIndexSkills"];
    hash = If[isHarness && StringQ[root] && DirectoryQ[root],
      ClaudeDirectiveRepositoryHash[root],
      Missing["NotComputed"]];
    <|
      "HarnessTarget" -> Switch[target,
        "CodexHarness",  "Codex",
        "ClaudeHarness", "ClaudeCLI",
        _,               None],
      "HarnessProvider"                 -> provider,
      "HarnessMaterializationMode"      -> mode,
      "DirectiveRoot"                   -> root,
      "DirectiveRepositoryManifestHash" -> hash
    |>];

iHarnessBundleMeta[___] := <||>;

(* ---- UTF-8 byte count ---- *)

iUTF8ByteCount[s_String] := Length[ToCharacterCode[s, "UTF-8"]];
iUTF8ByteCount[_] := 0;

(* ---- AGENTS.md fixed safety template (spec 6.3 / 6.5.4) ---- *)

iCodexAgentsMdSafetyTemplate[] :=
  StringRiffle[{
    "## Critical boundaries",
    "",
    "- Never bypass NBAccess for notebook cells, session history, "
      <> "or credentials.",
    "- Treat ChatGPT Codex as a cloud-backed CLI provider, not a "
      <> "private or local model.",
    "- Write only inside the generated temp project. Treat package "
      <> "and accessible directories as read-only unless the harness "
      <> "explicitly instructs otherwise.",
    "- Do not read secret-looking files even if the sandbox would "
      <> "allow it.",
    "- Do not edit AGENTS.md or .agents/ ; they are generated harness "
      <> "artifacts, not canonical sources."
  }, "\n"];

(* provenance comment placed at the top of AGENTS.md *)

iCodexAgentsMdProvenance[manifestHash_, svSnap_, hmm_] :=
  StringRiffle[{
    "<!--",
    "Generated harness file. DO NOT EDIT.",
    "Canonical source: Claude Directives/ (the only editable source).",
    "DirectiveRepositoryManifestHash: " <> ToString[manifestHash],
    "SourceVaultSnapshotId: " <> ToString[svSnap],
    "HarnessMaterializationMode: " <> ToString[hmm],
    "Generator: claudecode_directives.wl " <>
      ToString[$ClaudeDirectivesVersion],
    "-->"
  }, "\n"];

(* assemble the AGENTS.md body for a given set of inline rule lines *)

iBuildCodexAgentsMd[manifestHash_, svSnap_, hmm_,
    inlineRuleLines_List] :=
  StringRiffle[
    Join[
      {
        iCodexAgentsMdProvenance[manifestHash, svSnap, hmm],
        "",
        "# Codex Harness Instructions",
        "",
        "This file is generated from the canonical Claude Directives "
          <> "repository. Do not edit AGENTS.md or .agents/skills "
          <> "directly.",
        "",
        iCodexAgentsMdSafetyTemplate[],
        ""
      },
      If[inlineRuleLines === {},
        {},
        Join[{"## Always-on rule summaries", ""}, inlineRuleLines, {""}]],
      {
        "## Directive index",
        "",
        "Detailed rules and skills are materialized under "
          <> ".agents/skills and indexed in "
          <> ".agents/directive-index.json."
      }],
    "\n"];

(* one inline summary line for a rule *)

iCodexInlineRuleLine[ruleName_String, summary_String] :=
  "- Rule: " <> ruleName <> " \[LongDash] " <> summary;

(* ---- ClaudeDirectiveHarnessPlan (spec 5.2) ---- *)

Options[ClaudeDirectiveHarnessPlan] = {
  "HarnessMaterializationMode" -> Automatic,
  "AgentsMdTargetMaxBytes"     -> 20000,
  "AgentsMdHardMaxBytes"       -> 30000,
  "RuleLargeByteThreshold"     -> Automatic,
  "AlwaysOnRules"              -> Automatic,
  "RuleMetadataOverrides"      -> <||>,
  "SourceVaultSnapshotId"      -> Missing["NotRegistered"]
};

(* Phase 4 (spec 5.2 / 5.5): the "ClaudeCLI" target dispatches to
   iClaudeCLIHarnessPlan, a verbatim-copy plan. This specific
   definition is matched before the generic target_String definition
   below. iClaudeCLIHarnessPlan is defined further down, alongside
   ClaudeDirectiveMaterializeClaudeHarness. *)
ClaudeDirectiveHarnessPlan[
    bundle_Association, "ClaudeCLI", opts:OptionsPattern[]] :=
  iClaudeCLIHarnessPlan[bundle, opts];

ClaudeDirectiveHarnessPlan[
    bundle_Association, target_String, opts:OptionsPattern[]] :=
  Module[
    {root, manifestHash, hmm, targetMax, hardMax, threshold,
     alwaysOn, overrides, svSnap, inv, ruleRecs, skillRecs,
     classifyOf, deriveOf, genSkills = {}, cmdPolicyRules = {},
     indexEntries = {}, inlineCandidates, inlineLines, agentsBody,
     agentsBytes, inlineNames, omittedNames, provFiles, warnings = {},
     ruleData},

    If[target =!= "Codex",
      Return[Failure["UnsupportedHarnessTarget",
        <|"Target" -> target,
          "Message" ->
            "ClaudeDirectiveHarnessPlan supports \"Codex\" and \"ClaudeCLI\"."|>]]];

    (* resolve repository root *)
    root = Lookup[bundle, "DirectiveRoot",
      Lookup[bundle, "Root", None]];
    If[!StringQ[root] || !DirectoryQ[root],
      root = ClaudeResolveDirectiveRoot[Automatic]];
    If[FailureQ[root], Return[root]];

    manifestHash = Lookup[bundle, "DirectiveRepositoryManifestHash",
      Missing["NotComputed"]];
    If[!StringQ[manifestHash],
      manifestHash = ClaudeDirectiveRepositoryHash[root]];

    hmm = OptionValue[ClaudeDirectiveHarnessPlan, {opts},
      "HarnessMaterializationMode"];
    If[hmm === Automatic,
      hmm = Lookup[bundle, "HarnessMaterializationMode",
        "BootstrapIndexSkills"]];
    If[!StringQ[hmm], hmm = "BootstrapIndexSkills"];

    targetMax = OptionValue[ClaudeDirectiveHarnessPlan, {opts},
      "AgentsMdTargetMaxBytes"];
    hardMax = OptionValue[ClaudeDirectiveHarnessPlan, {opts},
      "AgentsMdHardMaxBytes"];
    threshold = OptionValue[ClaudeDirectiveHarnessPlan, {opts},
      "RuleLargeByteThreshold"];
    alwaysOn = OptionValue[ClaudeDirectiveHarnessPlan, {opts},
      "AlwaysOnRules"];
    overrides = OptionValue[ClaudeDirectiveHarnessPlan, {opts},
      "RuleMetadataOverrides"];
    svSnap = OptionValue[ClaudeDirectiveHarnessPlan, {opts},
      "SourceVaultSnapshotId"];
    If[!IntegerQ[hardMax], hardMax = 30000];
    If[!IntegerQ[targetMax], targetMax = 20000];

    inv = ClaudeDirectiveFileInventory[root];
    If[FailureQ[inv], Return[inv]];
    ruleRecs  = Select[inv, Lookup[#, "Role"] === "Rule" &];
    skillRecs = Select[inv, Lookup[#, "Role"] === "Skill" &];

    classifyOf = ClaudeDirectiveClassifyRule[#,
      "RuleLargeByteThreshold" -> threshold,
      "AlwaysOnRules" -> alwaysOn,
      "RuleMetadataOverrides" -> overrides] &;
    deriveOf = ClaudeDirectiveRuleDerivedMetadata[#,
      "RuleMetadataOverrides" -> overrides] &;

    (* per-rule classification + derived metadata *)
    ruleData = Map[
      Function[rec,
        <|"Record" -> rec,
          "Classification" -> classifyOf[rec],
          "DerivedMetadata" -> deriveOf[rec]|>],
      ruleRecs];

    (* rules: command-policy ones go to .rules; the rest become skills *)
    Do[
      Module[{rec, cls, der, ruleName, skillName, srcRel, tgtRel,
              srcHash},
        rec = entry["Record"];
        cls = entry["Classification"];
        der = entry["DerivedMetadata"];
        ruleName = ToString[Lookup[rec, "Name", ""]];
        srcRel = Lookup[rec, "RelativePath", ""];
        srcHash = Lookup[rec, "ContentHash", Missing["NotAvailable"]];
        If[TrueQ[Lookup[cls, "CommandPolicy", False]],
          AppendTo[cmdPolicyRules,
            <|"Name" -> ruleName,
              "SourceRelativePath" -> srcRel,
              "SourceHash" -> srcHash,
              "Classification" -> cls|>],
          (* else: generated rule skill *)
          skillName = "rule-" <> ruleName;
          tgtRel = ".agents/skills/" <> skillName <> "/SKILL.md";
          AppendTo[genSkills,
            <|"Kind" -> "rule",
              "Name" -> skillName,
              "SourceRelativePath" -> srcRel,
              "TargetRelativePath" -> tgtRel,
              "Classification" -> cls,
              "DerivedMetadata" -> der|>];
          AppendTo[indexEntries,
            <|"kind" -> "rule",
              "name" -> ruleName,
              "title" -> Lookup[der, "Title", ""],
              "description" -> Lookup[der, "Description", ""],
              "trigger" -> Lookup[der, "Trigger", ""],
              "description_source" ->
                Lookup[der, "DescriptionSource", ""],
              "paths" -> Lookup[der, "Paths", {}],
              "classification" -> <|
                "scope" -> Lookup[cls, "Scope", ""],
                "size_class" -> Lookup[cls, "SizeClass", ""],
                "inline_summary_in_agents_md" ->
                  TrueQ[Lookup[cls, "InlineSummaryInAgentsMd", False]],
                "command_policy" ->
                  TrueQ[Lookup[cls, "CommandPolicy", False]]
              |>,
              "source_relative_path" -> srcRel,
              "source_hash" -> srcHash,
              "materialized_path" -> tgtRel,
              "materialized_hash" ->
                Missing["PendingMaterialization"]|>]]],
      {entry, ruleData}];

    (* existing skills: copied verbatim into .agents/skills *)
    Do[
      Module[{skillName, srcRel, tgtRel, srcHash, desc},
        skillName = ToString[Lookup[rec, "Name", ""]];
        srcRel = Lookup[rec, "RelativePath", ""];
        srcHash = Lookup[rec, "ContentHash", Missing["NotAvailable"]];
        desc = Lookup[rec, "Description", Missing["NotAvailable"]];
        If[!StringQ[desc], desc = ""];
        tgtRel = ".agents/skills/" <> skillName <> "/SKILL.md";
        AppendTo[genSkills,
          <|"Kind" -> "skill",
            "Name" -> skillName,
            "SourceRelativePath" -> srcRel,
            "TargetRelativePath" -> tgtRel,
            "Classification" -> Missing["NotApplicable"],
            "DerivedMetadata" -> Missing["NotApplicable"]|>];
        AppendTo[indexEntries,
          <|"kind" -> "skill",
            "name" -> skillName,
            "description" -> desc,
            "description_source" -> "skill-frontmatter",
            "trigger" ->
              "Implicit matching via Codex skill description; "
                <> "explicit reference allowed by skill name.",
            "source_relative_path" -> srcRel,
            "source_hash" -> srcHash,
            "materialized_path" -> tgtRel,
            "materialized_hash" -> Missing["PendingMaterialization"]|>]],
      {rec, skillRecs}];

    (* AGENTS.md inline candidates: always-on small rules *)
    inlineCandidates = Select[ruleData,
      TrueQ[Lookup[#["Classification"],
        "InlineSummaryInAgentsMd", False]] &];
    (* deterministic order: by rule name *)
    inlineCandidates = SortBy[inlineCandidates,
      ToString[Lookup[#["Record"], "Name", ""]] &];

    (* budget shrink loop (spec 6.5.4): drop summaries from the end
       until the AGENTS.md body fits the hard maximum *)
    Module[{active = inlineCandidates},
      inlineLines = Map[
        iCodexInlineRuleLine[
          ToString[Lookup[#["Record"], "Name", ""]],
          ToString[Lookup[#["DerivedMetadata"], "Summary", ""]]] &,
        active];
      agentsBody = iBuildCodexAgentsMd[manifestHash, svSnap, hmm,
        inlineLines];
      agentsBytes = iUTF8ByteCount[agentsBody];
      While[agentsBytes > hardMax && active =!= {},
        active = Most[active];
        inlineLines = Map[
          iCodexInlineRuleLine[
            ToString[Lookup[#["Record"], "Name", ""]],
            ToString[Lookup[#["DerivedMetadata"], "Summary", ""]]] &,
          active];
        agentsBody = iBuildCodexAgentsMd[manifestHash, svSnap, hmm,
          inlineLines];
        agentsBytes = iUTF8ByteCount[agentsBody]];
      inlineNames = Map[
        ToString[Lookup[#["Record"], "Name", ""]] &, active];
      omittedNames = Complement[
        Map[ToString[Lookup[#["Record"], "Name", ""]] &,
          inlineCandidates],
        inlineNames]];

    If[omittedNames =!= {},
      AppendTo[warnings,
        "AGENTS.md budget: " <> ToString[Length[omittedNames]] <>
        " always-on rule summary line(s) were omitted to fit "
          <> "the byte budget; full text remains in .agents/skills."]];
    If[agentsBytes > hardMax,
      AppendTo[warnings,
        "AGENTS.md still exceeds AgentsMdHardMaxBytes (" <>
        ToString[agentsBytes] <> " > " <> ToString[hardMax] <>
        ") after shrinking; ClaudeDirectiveMaterializeCodexHarness "
          <> "will apply FailOnAgentsMdOverflow."]];
    If[agentsBytes > targetMax && agentsBytes <= hardMax,
      AppendTo[warnings,
        "AGENTS.md exceeds AgentsMdTargetMaxBytes but is within "
          <> "the hard maximum."]];

    (* provenance files (spec 6.8) *)
    provFiles = Join[
      {".agents/sourcevault-provenance.json"},
      Map[
        StringReplace[Lookup[#, "TargetRelativePath", ""],
          "SKILL.md" -> ".sourcevault.json"] &,
        genSkills]];

    <|
      "Target"                          -> "Codex",
      "HarnessMaterializationMode"      -> hmm,
      "DirectiveRepositoryManifestHash" -> manifestHash,
      "SourceVaultSnapshotId"           -> svSnap,
      "DirectiveRoot"                   -> root,
      "AgentsMd" -> <|
        "TargetRelativePath" -> "AGENTS.md",
        "EstimatedByteCount" -> agentsBytes,
        "InlineRuleNames"    -> inlineNames,
        "OmittedRuleNames"   -> omittedNames,
        "HardMaxBytes"       -> hardMax,
        "TargetMaxBytes"     -> targetMax
      |>,
      "Index" -> <|
        "TargetRelativePath" -> ".agents/directive-index.json",
        "Entries"            -> indexEntries
      |>,
      "GeneratedSkills"    -> genSkills,
      "CommandPolicyRules" -> cmdPolicyRules,
      "ProvenanceFiles"    -> provFiles,
      "Warnings"           -> warnings
    |>];

ClaudeDirectiveHarnessPlan[___] := $Failed;


(* ===================================================================
   Phase 1.1b-2: Codex harness materialization
   Spec 5th review: sections 5.2 / 6.6-6.8.
   ClaudeDirectiveMaterializeCodexHarness is a thin wrapper that
   executes ClaudeDirectiveHarnessPlan and writes the harness files.
   =================================================================== *)

(* ---- UTF-8 file I/O (Windows-safe; see encoding traps) ---- *)

iReadUTF8File[path_String] :=
  Module[{bytes},
    bytes = Quiet @ Check[ReadByteArray[path], $Failed];
    Which[
      bytes === EndOfFile,  "",
      ByteArrayQ[bytes],    ByteArrayToString[bytes, "UTF-8"],
      True,                 ""]];

iReadUTF8File[_] := "";

iWriteUTF8File[path_String, text_String] :=
  Module[{stream},
    stream = OpenWrite[path, BinaryFormat -> True];
    BinaryWrite[stream, StringToByteArray[text, "UTF-8"]];
    Close[stream];
    path];

iWriteJSONFile[path_String, expr_] :=
  iWriteUTF8File[path,
    Developer`WriteRawJSONString[
      expr /. {_Missing -> Null, None -> Null},
      "Compact" -> 4]];

(* ---- YAML helpers for generated rule skill frontmatter ---- *)

iYamlScalar[s_String] :=
  "\"" <> StringReplace[s,
    {"\\" -> "\\\\", "\"" -> "\\\""}] <> "\"";

iYamlScalar[x_] := iYamlScalar[ToString[x]];

iYamlPathsBlock[{}] := "paths: []";

iYamlPathsBlock[paths_List] :=
  StringRiffle[
    Prepend[
      Map["  - " <> iYamlScalar[ToString[#]] &,
        Select[paths, StringQ]],
      "paths:"],
    "\n"];

iYamlPathsBlock[_] := "paths: []";

(* remove a leading YAML frontmatter block, if present *)

iStripFrontmatter[text_String] :=
  StringReplace[text,
    RegularExpression[
      "(?s)\\A\\s*---\\r?\\n.*?\\r?\\n---[ \\t]*\\r?\\n?"] -> "",
    1];

iStripFrontmatter[_] := "";

(* generated rule skill SKILL.md (spec 6.6) *)

iBuildRuleSkillMd[gen_Association, srcHash_, body_String] :=
  Module[{der, name, ruleName, src, fm},
    der = Lookup[gen, "DerivedMetadata", <||>];
    If[!AssociationQ[der], der = <||>];
    name = ToString[Lookup[gen, "Name", ""]];
    ruleName = StringReplace[name,
      StartOfString ~~ "rule-" -> ""];
    src = ToString[Lookup[gen, "SourceRelativePath", ""]];
    fm = StringRiffle[{
      "---",
      "name: " <> name,
      "description: " <> iYamlScalar[
        ToString[Lookup[der, "Description", ""]]],
      "summary: " <> iYamlScalar[
        ToString[Lookup[der, "Summary", ""]]],
      "source: " <> src,
      "source_hash: " <> ToString[srcHash],
      iYamlPathsBlock[Lookup[der, "Paths", {}]],
      "description_source: " <>
        ToString[Lookup[der, "DescriptionSource", ""]],
      "---"
    }, "\n"];
    fm <> "\n\n# Rule: " <> ruleName <> "\n\n" <> body];

(* ------------------------------------------------------------------
   Phase 5 (2026-05-26): normalize an existing skill's SKILL.md for
   the Codex skill loader.

   The Codex CLI skill loader requires a `name` and a `description`
   field, and (being a strict YAML parser) rejects an unquoted scalar
   that contains a colon-space (it reads it as a nested mapping). The
   canonical Claude Directives skills were authored for Claude's
   loader, so some carry only `paths:` (no description) and others
   have a long unquoted `description:` value full of `: ` sequences.
   Copying them verbatim makes `codex exec` log
   "invalid YAML" / "missing field description".

   iBuildSkillSkillMd rebuilds the frontmatter with a quoted name and
   description (iYamlScalar handles the escaping) and leaves the body
   untouched. A missing description is derived from the first level-1
   heading of the body, falling back to the skill name.
   ------------------------------------------------------------------ *)
iSkillDescriptionFromBody[body_String] :=
  Module[{m},
    m = StringCases[body,
      RegularExpression["(?m)^#[ \\t]+(.+?)[ \\t]*$"] :>
        "$1", 1];
    If[ListQ[m] && Length[m] >= 1 && StringQ[First[m]] &&
        StringLength[StringTrim[First[m]]] > 0,
      StringTrim[First[m]],
      ""]];
iSkillDescriptionFromBody[_] := "";

iBuildSkillSkillMd[skillName_String, srcHash_, rawText_String] :=
  Module[{parsed, fm, body, desc, fmLines},
    parsed = iParseFrontmatter[rawText];
    fm   = Lookup[parsed, "Frontmatter", <||>];
    body = Lookup[parsed, "Body", rawText];
    If[!AssociationQ[fm], fm = <||>];
    If[!StringQ[body], body = rawText];
    desc = Lookup[fm, "description",
      Lookup[fm, "Description", Missing["NotAvailable"]]];
    If[!StringQ[desc] || StringLength[StringTrim[desc]] === 0,
      desc = iSkillDescriptionFromBody[body]];
    If[!StringQ[desc] || StringLength[StringTrim[desc]] === 0,
      desc = "Skill: " <> skillName];
    (* collapse any internal newlines / runs of whitespace so the
       description is emitted as a single quoted YAML scalar *)
    desc = StringReplace[StringTrim[desc],
      RegularExpression["\\s+"] -> " "];
    fmLines = {
      "---",
      "name: " <> iYamlScalar[skillName],
      "description: " <> iYamlScalar[StringTrim[desc]]};
    (* preserve a paths: block when the source had one, so Codex
       path-scoped matching still works *)
    If[KeyExistsQ[fm, "paths"] || KeyExistsQ[fm, "Paths"],
      Module[{p = Lookup[fm, "paths", Lookup[fm, "Paths", {}]]},
        If[ListQ[p] && p =!= {},
          AppendTo[fmLines, iYamlPathsBlock[p]]]]];
    AppendTo[fmLines, "source_hash: " <> ToString[srcHash]];
    AppendTo[fmLines, "---"];
    StringRiffle[fmLines, "\n"] <> "\n\n" <> body];
iBuildSkillSkillMd[___] := $Failed;


(* UTC ISO-8601 timestamp *)

iISOTimestamp[] :=
  DateString[Now, "ISODateTime", TimeZone -> 0] <> "Z";

(* resolve a materialized hash for an index entry *)

iMatHashForEntry[entry_Association, plan_Association,
    matHashByName_Association] :=
  Module[{mp, gen},
    mp = Lookup[entry, "materialized_path", ""];
    gen = SelectFirst[Lookup[plan, "GeneratedSkills", {}],
      Lookup[#, "TargetRelativePath", ""] === mp &, <||>];
    Lookup[matHashByName, Lookup[gen, "Name", ""],
      Missing["NotMaterialized"]]];

iMatHashForEntry[___] := Missing["NotMaterialized"];

(* ---- ClaudeDirectiveHarnessProvenanceHeader ---- *)

ClaudeDirectiveHarnessProvenanceHeader[meta_Association] :=
  iCodexAgentsMdProvenance[
    Lookup[meta, "DirectiveRepositoryManifestHash",
      Lookup[meta, "ManifestHash", Missing["NotAvailable"]]],
    Lookup[meta, "SourceVaultSnapshotId",
      Lookup[meta, "SnapshotId", Missing["NotRegistered"]]],
    Lookup[meta, "HarnessMaterializationMode",
      Lookup[meta, "Mode", "BootstrapIndexSkills"]]];

ClaudeDirectiveHarnessProvenanceHeader[___] := $Failed;

(* ---- ClaudeDirectiveMaterializeCodexHarness (spec 5.2) ---- *)

Options[ClaudeDirectiveMaterializeCodexHarness] = {
  "HarnessMaterializationMode"      -> Automatic,
  "SourceVaultSnapshotId"           -> Missing["NotRegistered"],
  "DirectiveRepositoryManifestHash" -> Automatic,
  "GenerateDirectiveIndex"          -> True,
  "GenerateProvenance"              -> True,
  "AgentsMdTargetMaxBytes"          -> 20000,
  "AgentsMdHardMaxBytes"            -> 30000,
  "RuleLargeByteThreshold"          -> Automatic,
  "AlwaysOnRules"                   -> Automatic,
  "RuleMetadataOverrides"           -> <||>,
  "CommandPolicyMaterialization"    -> "Disabled",
  "DryRun"                          -> False,
  "FailOnAgentsMdOverflow"          -> True
};

ClaudeDirectiveMaterializeCodexHarness[
    bundle_Association, targetDir_String, opts:OptionsPattern[]] :=
  Module[
    {ov, plan, root, inv, invByRel, manifestHash, hmm, svSnap,
     genIndex, genProv, dryRun, failOverflow, agentsBytes, agentsHard,
     warnings, writtenFiles = {}, genReports = {}, matHashByName = <||>,
     agentsPath = "AGENTS.md", agentsAbs, agentsHashV, agentsByteV = 0,
     indexRel = None, idxEntryCount = 0, provFiles = {}},

    ov[k_] := OptionValue[ClaudeDirectiveMaterializeCodexHarness,
      {opts}, k];

    (* 1. compute the plan *)
    plan = ClaudeDirectiveHarnessPlan[bundle, "Codex",
      "HarnessMaterializationMode" -> ov["HarnessMaterializationMode"],
      "AgentsMdTargetMaxBytes"     -> ov["AgentsMdTargetMaxBytes"],
      "AgentsMdHardMaxBytes"       -> ov["AgentsMdHardMaxBytes"],
      "RuleLargeByteThreshold"     -> ov["RuleLargeByteThreshold"],
      "AlwaysOnRules"              -> ov["AlwaysOnRules"],
      "RuleMetadataOverrides"      -> ov["RuleMetadataOverrides"],
      "SourceVaultSnapshotId"      -> ov["SourceVaultSnapshotId"]];
    If[FailureQ[plan], Return[plan]];

    warnings    = Lookup[plan, "Warnings", {}];
    agentsBytes = Lookup[Lookup[plan, "AgentsMd", <||>],
      "EstimatedByteCount", 0];
    agentsHard  = Lookup[Lookup[plan, "AgentsMd", <||>],
      "HardMaxBytes", 30000];

    (* 2. AGENTS.md overflow gate *)
    failOverflow = TrueQ[ov["FailOnAgentsMdOverflow"]];
    If[failOverflow && agentsBytes > agentsHard,
      Return[Failure["AgentsMdOverflow", <|
        "EstimatedByteCount" -> agentsBytes,
        "HardMaxBytes"       -> agentsHard,
        "Message" ->
          "AGENTS.md exceeds the hard byte budget. Raise "
            <> "AgentsMdHardMaxBytes, supply RuleMetadataOverrides, "
            <> "or set FailOnAgentsMdOverflow -> False."|>]]];

    (* 3. dry-run: return the plan, write nothing *)
    dryRun = TrueQ[ov["DryRun"]];
    If[dryRun,
      Return[<|
        "DryRun"    -> True,
        "Target"    -> "Codex",
        "TargetDir" -> targetDir,
        "Plan"      -> plan|>]];

    (* 4. resolve repository root + inventory *)
    root = Lookup[plan, "DirectiveRoot",
      Lookup[bundle, "DirectiveRoot", None]];
    If[!StringQ[root] || !DirectoryQ[root],
      root = ClaudeResolveDirectiveRoot[Automatic]];
    If[FailureQ[root], Return[root]];
    inv = ClaudeDirectiveFileInventory[root];
    If[FailureQ[inv], Return[inv]];
    invByRel = Association[
      (Lookup[#, "RelativePath", ""] -> #) & /@ inv];

    manifestHash = Lookup[plan, "DirectiveRepositoryManifestHash",
      Missing["NotComputed"]];
    hmm = Lookup[plan, "HarnessMaterializationMode",
      "BootstrapIndexSkills"];
    svSnap   = Lookup[plan, "SourceVaultSnapshotId",
      Missing["NotRegistered"]];
    genIndex = TrueQ[ov["GenerateDirectiveIndex"]];
    genProv  = TrueQ[ov["GenerateProvenance"]];

    If[!DirectoryQ[targetDir],
      CreateDirectory[targetDir,
        CreateIntermediateDirectories -> True]];

    (* 5a. generated skills (rules become skills; skills are copied) *)
    Do[
      Module[{gen, srcRel, srcRec, srcAbs, srcHash, tgtRel, tgtAbs,
              rawText, skillMd, matHash},
        gen    = g;
        srcRel = ToString[Lookup[gen, "SourceRelativePath", ""]];
        tgtRel = ToString[Lookup[gen, "TargetRelativePath", ""]];
        srcRec = Lookup[invByRel, srcRel, <||>];
        srcAbs = ToString[Lookup[srcRec, "AbsolutePath", ""]];
        srcHash = Lookup[srcRec, "ContentHash",
          Missing["NotAvailable"]];
        tgtAbs = FileNameJoin[
          Prepend[FileNameSplit[tgtRel], targetDir]];
        If[!DirectoryQ[DirectoryName[tgtAbs]],
          CreateDirectory[DirectoryName[tgtAbs],
            CreateIntermediateDirectories -> True]];
        rawText = If[StringQ[srcAbs] && FileExistsQ[srcAbs],
          iReadUTF8File[srcAbs], ""];
        skillMd = Which[
          Lookup[gen, "Kind"] === "rule",
            iBuildRuleSkillMd[gen, srcHash,
              iStripFrontmatter[rawText]],
          (* Phase 5 (2026-05-26): existing skills are no longer
             copied verbatim. Their frontmatter is normalized for the
             Codex skill loader (quoted name + description, derived
             description when missing); the body is left intact. *)
          Lookup[gen, "Kind"] === "skill",
            Module[{built},
              built = iBuildSkillSkillMd[
                ToString[Lookup[gen, "Name", ""]], srcHash, rawText];
              If[StringQ[built], built, rawText]],
          True,
            rawText];
        iWriteUTF8File[tgtAbs, skillMd];
        matHash = iDirectiveContentHash[tgtAbs];
        matHashByName = Append[matHashByName,
          ToString[Lookup[gen, "Name", ""]] -> matHash];
        AppendTo[writtenFiles, tgtRel];
        AppendTo[genReports, <|
          "Kind"               -> Lookup[gen, "Kind"],
          "Name"               -> Lookup[gen, "Name"],
          "SourceRelativePath" -> srcRel,
          "TargetRelativePath" -> tgtRel,
          "SourceHash"         -> srcHash,
          "MaterializedHash"   -> matHash|>]],
      {g, Lookup[plan, "GeneratedSkills", {}]}];

    (* 5c. directive index (materialized hashes now known) *)
    If[genIndex,
      Module[{entries, idxDoc, idxAbs},
        indexRel = Lookup[Lookup[plan, "Index", <||>],
          "TargetRelativePath", ".agents/directive-index.json"];
        entries = Lookup[Lookup[plan, "Index", <||>], "Entries", {}];
        idxEntryCount = Length[entries];
        entries = Map[
          Function[e,
            Append[e, "materialized_hash" ->
              iMatHashForEntry[e, plan, matHashByName]]],
          entries];
        idxDoc = <|
          "schema_version"   -> 1,
          "canonical_format" -> "ClaudeDirectives",
          "directive_repository" -> <|
            "root_label"             -> "Claude Directives",
            "manifest_hash"          -> manifestHash,
            "sourcevault_snapshot_id" -> svSnap|>,
          "materialization" -> <|
            "target"       -> "Codex",
            "mode"         -> hmm,
            "generated_at" -> iISOTimestamp[]|>,
          "entries" -> entries|>;
        idxAbs = FileNameJoin[
          Prepend[FileNameSplit[indexRel], targetDir]];
        If[!DirectoryQ[DirectoryName[idxAbs]],
          CreateDirectory[DirectoryName[idxAbs],
            CreateIntermediateDirectories -> True]];
        iWriteJSONFile[idxAbs, idxDoc];
        AppendTo[writtenFiles, indexRel]]];

    (* 5d. AGENTS.md *)
    Module[{inlineNames, inlineLines, agentsBody},
      inlineNames = Lookup[Lookup[plan, "AgentsMd", <||>],
        "InlineRuleNames", {}];
      inlineLines = Map[
        Function[rn,
          Module[{rec, der},
            rec = SelectFirst[inv,
              ToString[Lookup[#, "Name", ""]] === rn &, <||>];
            der = ClaudeDirectiveRuleDerivedMetadata[rec,
              "RuleMetadataOverrides" -> ov["RuleMetadataOverrides"]];
            iCodexInlineRuleLine[rn,
              ToString[Lookup[
                If[AssociationQ[der], der, <||>],
                "Summary", ""]]]]],
        inlineNames];
      agentsBody = iBuildCodexAgentsMd[manifestHash, svSnap, hmm,
        inlineLines];
      agentsAbs = FileNameJoin[{targetDir, "AGENTS.md"}];
      iWriteUTF8File[agentsAbs, agentsBody];
      agentsHashV = iDirectiveContentHash[agentsAbs];
      agentsByteV = iUTF8ByteCount[agentsBody];
      AppendTo[writtenFiles, "AGENTS.md"]];

    (* 5e. provenance *)
    If[genProv,
      Do[
        Module[{gr, skillDir, provRel, provAbs, provDoc},
          gr = r;
          skillDir = DirectoryName[
            ToString[Lookup[gr, "TargetRelativePath", ""]]];
          provRel = skillDir <> "/.sourcevault.json";
          provAbs = FileNameJoin[
            Prepend[FileNameSplit[provRel], targetDir]];
          provDoc = <|
            "kind"               -> Lookup[gr, "Kind"],
            "name"               -> Lookup[gr, "Name"],
            "source_relative_path" ->
              Lookup[gr, "SourceRelativePath"],
            "source_hash"        -> Lookup[gr, "SourceHash"],
            "materialized_path"  -> Lookup[gr, "TargetRelativePath"],
            "materialized_hash"  -> Lookup[gr, "MaterializedHash"],
            "directive_repository_manifest_hash" -> manifestHash|>;
          iWriteJSONFile[provAbs, provDoc];
          AppendTo[provFiles, provRel];
          AppendTo[writtenFiles, provRel]],
        {r, genReports}];
      Module[{provDoc, provAbs, provRel},
        provRel = ".agents/sourcevault-provenance.json";
        provAbs = FileNameJoin[
          Prepend[FileNameSplit[provRel], targetDir]];
        provDoc = <|
          "kind"   -> "HarnessMaterialization",
          "target" -> "Codex",
          "harness_materialization_mode"      -> hmm,
          "directive_repository_manifest_hash" -> manifestHash,
          "sourcevault_snapshot_id"           -> svSnap,
          "generator" -> "claudecode_directives.wl "
            <> ToString[$ClaudeDirectivesVersion],
          "generated_at" -> iISOTimestamp[],
          "agents_md" -> <|
            "materialized_path" -> "AGENTS.md",
            "materialized_hash" -> agentsHashV,
            "byte_count"        -> agentsByteV|>,
          "skills"   -> genReports,
          "warnings" -> warnings|>;
        If[!DirectoryQ[DirectoryName[provAbs]],
          CreateDirectory[DirectoryName[provAbs],
            CreateIntermediateDirectories -> True]];
        iWriteJSONFile[provAbs, provDoc];
        AppendTo[provFiles, provRel];
        AppendTo[writtenFiles, provRel]]];

    (* 6. materialization report *)
    <|
      "Target"                          -> "Codex",
      "TargetDir"                       -> targetDir,
      "HarnessMaterializationMode"      -> hmm,
      "DirectiveRepositoryManifestHash" -> manifestHash,
      "DryRun"                          -> False,
      "WrittenFiles"                    -> writtenFiles,
      "AgentsMd" -> <|
        "TargetRelativePath" -> agentsPath,
        "ByteCount"          -> agentsByteV,
        "MaterializedHash"   -> agentsHashV|>,
      "Index" -> <|
        "TargetRelativePath" -> indexRel,
        "EntryCount"         -> idxEntryCount|>,
      "GeneratedSkills"  -> genReports,
      "ProvenanceFiles"  -> provFiles,
      "Warnings"         -> warnings,
      "Plan"             -> plan
    |>];

ClaudeDirectiveMaterializeCodexHarness[___] := $Failed;


(* ===================================================================
   Phase 4: Claude CLI Generated harness
   (Codex integration spec 5th review, sections 5.2 / 5.5 / 7.1-7.3)
   The Claude CLI Generated harness is much simpler than the Codex
   harness: there is no AGENTS.md byte budgeting, no directive index
   and no rule-to-skill conversion. The canonical CLAUDE.md / rules /
   skills are copied verbatim into a .claude/ tree. settings.json is
   NOT produced here -- claudecode.wl injects the read permissions
   (claudecode_directives.wl stays free of claudecode/SourceVault
   dependencies, spec 5.1).
   =================================================================== *)

(* target-relative path of a copied rule inside a generated .claude/
   harness. Unlike the Codex harness, Claude CLI rules are NOT
   converted into skills; they are copied verbatim under
   .claude/rules/. *)
iClaudeCLIRuleTargetRel[ruleName_String] :=
  ".claude/rules/" <> ruleName <> ".md";
iClaudeCLIRuleTargetRel[_] := "";

(* target-relative path of a copied skill inside a generated .claude/
   harness. Mirrors the canonical skills/<name>/SKILL.md layout. *)
iClaudeCLISkillTargetRel[skillName_String] :=
  ".claude/skills/" <> skillName <> "/SKILL.md";
iClaudeCLISkillTargetRel[_] := "";

(* iClaudeCLIHarnessPlan (spec 5.2 / 7.2): the Claude CLI harness
   plan. It keeps the same top-level keys as the Codex plan (Target,
   HarnessMaterializationMode, DirectiveRepositoryManifestHash,
   GeneratedSkills, ProvenanceFiles, Warnings) so downstream code can
   treat both uniformly. AgentsMd and Index are Missing because the
   Claude CLI harness has neither. GeneratedSkills carries BOTH rules
   and skills (Kind -> "rule" | "skill"); the CLAUDE.md root
   instruction is reported separately under RootInstruction. *)
iClaudeCLIHarnessPlan[bundle_Association, opts:OptionsPattern[]] :=
  Module[
    {root, manifestHash, hmm, svSnap, inv, rootRec, ruleRecs,
     skillRecs, genFiles = {}, rootInstruction, warnings = {}},

    (* resolve repository root *)
    root = Lookup[bundle, "DirectiveRoot",
      Lookup[bundle, "Root", None]];
    If[!StringQ[root] || !DirectoryQ[root],
      root = ClaudeResolveDirectiveRoot[Automatic]];
    If[FailureQ[root], Return[root]];

    manifestHash = Lookup[bundle, "DirectiveRepositoryManifestHash",
      Missing["NotComputed"]];
    If[!StringQ[manifestHash],
      manifestHash = ClaudeDirectiveRepositoryHash[root]];

    hmm = OptionValue[ClaudeDirectiveHarnessPlan, {opts},
      "HarnessMaterializationMode"];
    If[hmm === Automatic,
      hmm = Lookup[bundle, "HarnessMaterializationMode",
        "FullGenerated"]];
    If[!StringQ[hmm], hmm = "FullGenerated"];

    svSnap = OptionValue[ClaudeDirectiveHarnessPlan, {opts},
      "SourceVaultSnapshotId"];

    inv = ClaudeDirectiveFileInventory[root];
    If[FailureQ[inv], Return[inv]];
    rootRec   = SelectFirst[inv,
      Lookup[#, "Role"] === "RootInstruction" &, <||>];
    ruleRecs  = Select[inv, Lookup[#, "Role"] === "Rule" &];
    skillRecs = Select[inv, Lookup[#, "Role"] === "Skill" &];

    (* CLAUDE.md -> .claude/CLAUDE.md *)
    rootInstruction = If[AssociationQ[rootRec] && rootRec =!= <||>,
      <|"SourceRelativePath" ->
          Lookup[rootRec, "RelativePath", "CLAUDE.md"],
        "TargetRelativePath" -> ".claude/CLAUDE.md",
        "SourceHash" ->
          Lookup[rootRec, "ContentHash", Missing["NotAvailable"]]|>,
      (AppendTo[warnings,
         "No CLAUDE.md (RootInstruction) was found in the canonical "
           <> "repository; .claude/CLAUDE.md will not be generated."];
       Missing["NotAvailable"])];

    (* rules -> .claude/rules/<name>.md (verbatim) *)
    Do[
      Module[{ruleName, srcRel, tgtRel, srcHash},
        ruleName = ToString[Lookup[rec, "Name", ""]];
        srcRel   = Lookup[rec, "RelativePath", ""];
        srcHash  = Lookup[rec, "ContentHash", Missing["NotAvailable"]];
        tgtRel   = iClaudeCLIRuleTargetRel[ruleName];
        AppendTo[genFiles,
          <|"Kind" -> "rule",
            "Name" -> ruleName,
            "SourceRelativePath" -> srcRel,
            "TargetRelativePath" -> tgtRel,
            "SourceHash" -> srcHash|>]],
      {rec, ruleRecs}];

    (* skills -> .claude/skills/<name>/SKILL.md (verbatim) *)
    Do[
      Module[{skillName, srcRel, tgtRel, srcHash},
        skillName = ToString[Lookup[rec, "Name", ""]];
        srcRel    = Lookup[rec, "RelativePath", ""];
        srcHash   = Lookup[rec, "ContentHash", Missing["NotAvailable"]];
        tgtRel    = iClaudeCLISkillTargetRel[skillName];
        AppendTo[genFiles,
          <|"Kind" -> "skill",
            "Name" -> skillName,
            "SourceRelativePath" -> srcRel,
            "TargetRelativePath" -> tgtRel,
            "SourceHash" -> srcHash|>]],
      {rec, skillRecs}];

    <|
      "Target"                          -> "ClaudeCLI",
      "HarnessMaterializationMode"      -> hmm,
      "DirectiveRepositoryManifestHash" -> manifestHash,
      "SourceVaultSnapshotId"           -> svSnap,
      "DirectiveRoot"                   -> root,
      "RootInstruction"                 -> rootInstruction,
      "AgentsMd"                        -> Missing["NotApplicable"],
      "Index"                           -> Missing["NotApplicable"],
      "GeneratedSkills"                 -> genFiles,
      "CommandPolicyRules"              -> {},
      "ProvenanceFiles" ->
        {".claude/sourcevault-provenance.json"},
      "Warnings"                        -> warnings
    |>];

iClaudeCLIHarnessPlan[___] := $Failed;


(* ---- ClaudeDirectiveMaterializeClaudeHarness (spec 5.2 / 7.2) ----
   A thin wrapper that executes iClaudeCLIHarnessPlan and writes the
   .claude/ harness files. The canonical Claude Directives repository
   is never modified. .claude/settings.json is intentionally NOT
   written here. *)

Options[ClaudeDirectiveMaterializeClaudeHarness] = {
  "HarnessMaterializationMode"      -> Automatic,
  "SourceVaultSnapshotId"           -> Missing["NotRegistered"],
  "DirectiveRepositoryManifestHash" -> Automatic,
  "GenerateProvenance"              -> True,
  "DryRun"                          -> False
};

ClaudeDirectiveMaterializeClaudeHarness[
    bundle_Association, targetDir_String, opts:OptionsPattern[]] :=
  Module[
    {ov, plan, root, inv, invByRel, manifestHash, hmm, svSnap,
     genProv, dryRun, warnings, writtenFiles = {}, genReports = {},
     rootInstruction, rootReport = Missing["NotApplicable"],
     provFiles = {}},

    ov[k_] := OptionValue[ClaudeDirectiveMaterializeClaudeHarness,
      {opts}, k];

    (* 1. compute the plan *)
    plan = ClaudeDirectiveHarnessPlan[bundle, "ClaudeCLI",
      "HarnessMaterializationMode" -> ov["HarnessMaterializationMode"],
      "SourceVaultSnapshotId"      -> ov["SourceVaultSnapshotId"]];
    If[FailureQ[plan], Return[plan]];

    warnings = Lookup[plan, "Warnings", {}];

    (* 2. dry-run: return the plan, write nothing *)
    dryRun = TrueQ[ov["DryRun"]];
    If[dryRun,
      Return[<|
        "DryRun"    -> True,
        "Target"    -> "ClaudeCLI",
        "TargetDir" -> targetDir,
        "Plan"      -> plan|>]];

    (* 3. resolve repository root + inventory *)
    root = Lookup[plan, "DirectiveRoot",
      Lookup[bundle, "DirectiveRoot", None]];
    If[!StringQ[root] || !DirectoryQ[root],
      root = ClaudeResolveDirectiveRoot[Automatic]];
    If[FailureQ[root], Return[root]];
    inv = ClaudeDirectiveFileInventory[root];
    If[FailureQ[inv], Return[inv]];
    invByRel = Association[
      (Lookup[#, "RelativePath", ""] -> #) & /@ inv];

    manifestHash = Lookup[plan, "DirectiveRepositoryManifestHash",
      Missing["NotComputed"]];
    hmm     = Lookup[plan, "HarnessMaterializationMode",
      "FullGenerated"];
    svSnap  = Lookup[plan, "SourceVaultSnapshotId",
      Missing["NotRegistered"]];
    genProv = TrueQ[ov["GenerateProvenance"]];

    If[!DirectoryQ[targetDir],
      CreateDirectory[targetDir,
        CreateIntermediateDirectories -> True]];

    (* 4. CLAUDE.md -> .claude/CLAUDE.md (verbatim copy) *)
    rootInstruction = Lookup[plan, "RootInstruction",
      Missing["NotApplicable"]];
    If[AssociationQ[rootInstruction],
      Module[{srcRel, srcRec, srcAbs, tgtRel, tgtAbs, rawText,
              matHash},
        srcRel = ToString[
          Lookup[rootInstruction, "SourceRelativePath", "CLAUDE.md"]];
        tgtRel = ToString[
          Lookup[rootInstruction, "TargetRelativePath",
            ".claude/CLAUDE.md"]];
        srcRec = Lookup[invByRel, srcRel, <||>];
        srcAbs = ToString[Lookup[srcRec, "AbsolutePath", ""]];
        tgtAbs = FileNameJoin[
          Prepend[FileNameSplit[tgtRel], targetDir]];
        If[!DirectoryQ[DirectoryName[tgtAbs]],
          CreateDirectory[DirectoryName[tgtAbs],
            CreateIntermediateDirectories -> True]];
        rawText = If[StringQ[srcAbs] && FileExistsQ[srcAbs],
          iReadUTF8File[srcAbs], ""];
        iWriteUTF8File[tgtAbs, rawText];
        matHash = iDirectiveContentHash[tgtAbs];
        AppendTo[writtenFiles, tgtRel];
        rootReport = <|
          "SourceRelativePath" -> srcRel,
          "TargetRelativePath" -> tgtRel,
          "SourceHash" ->
            Lookup[rootInstruction, "SourceHash",
              Missing["NotAvailable"]],
          "MaterializedHash" -> matHash|>]];

    (* 5. rules + skills -> .claude/ (verbatim copies) *)
    Do[
      Module[{gen, srcRel, srcRec, srcAbs, srcHash, tgtRel, tgtAbs,
              rawText, matHash},
        gen    = g;
        srcRel = ToString[Lookup[gen, "SourceRelativePath", ""]];
        tgtRel = ToString[Lookup[gen, "TargetRelativePath", ""]];
        srcRec = Lookup[invByRel, srcRel, <||>];
        srcAbs = ToString[Lookup[srcRec, "AbsolutePath", ""]];
        srcHash = Lookup[srcRec, "ContentHash",
          Missing["NotAvailable"]];
        tgtAbs = FileNameJoin[
          Prepend[FileNameSplit[tgtRel], targetDir]];
        If[!DirectoryQ[DirectoryName[tgtAbs]],
          CreateDirectory[DirectoryName[tgtAbs],
            CreateIntermediateDirectories -> True]];
        rawText = If[StringQ[srcAbs] && FileExistsQ[srcAbs],
          iReadUTF8File[srcAbs], ""];
        iWriteUTF8File[tgtAbs, rawText];
        matHash = iDirectiveContentHash[tgtAbs];
        AppendTo[writtenFiles, tgtRel];
        AppendTo[genReports, <|
          "Kind"               -> Lookup[gen, "Kind"],
          "Name"               -> Lookup[gen, "Name"],
          "SourceRelativePath" -> srcRel,
          "TargetRelativePath" -> tgtRel,
          "SourceHash"         -> srcHash,
          "MaterializedHash"   -> matHash|>]],
      {g, Lookup[plan, "GeneratedSkills", {}]}];

    (* 6. provenance *)
    If[genProv,
      Module[{provDoc, provAbs, provRel},
        provRel = ".claude/sourcevault-provenance.json";
        provAbs = FileNameJoin[
          Prepend[FileNameSplit[provRel], targetDir]];
        provDoc = <|
          "kind"   -> "HarnessMaterialization",
          "target" -> "ClaudeCLI",
          "harness_materialization_mode"      -> hmm,
          "directive_repository_manifest_hash" -> manifestHash,
          "sourcevault_snapshot_id"           -> svSnap,
          "generator" -> "claudecode_directives.wl "
            <> ToString[$ClaudeDirectivesVersion],
          "generated_at"     -> iISOTimestamp[],
          "root_instruction" -> rootReport,
          "files"            -> genReports,
          "warnings"         -> warnings|>;
        If[!DirectoryQ[DirectoryName[provAbs]],
          CreateDirectory[DirectoryName[provAbs],
            CreateIntermediateDirectories -> True]];
        iWriteJSONFile[provAbs, provDoc];
        AppendTo[provFiles, provRel];
        AppendTo[writtenFiles, provRel]]];

    (* 7. materialization report *)
    <|
      "Target"                          -> "ClaudeCLI",
      "TargetDir"                       -> targetDir,
      "HarnessMaterializationMode"      -> hmm,
      "DirectiveRepositoryManifestHash" -> manifestHash,
      "DryRun"                          -> False,
      "WrittenFiles"                    -> writtenFiles,
      "RootInstruction"                 -> rootReport,
      "GeneratedFiles"                  -> genReports,
      "ProvenanceFiles"                 -> provFiles,
      "Warnings"                        -> warnings,
      "Plan"                            -> plan
    |>];

ClaudeDirectiveMaterializeClaudeHarness[___] := $Failed;


(* ===================================================================
   Phase 2.5: migration gate (spec section 4)
   Compares canonical Claude Directives vs a legacy .claude/ harness
   on normalised logical paths. Reuses ClaudeDirectiveFileInventory
   for both sides, so each side's RelativePath/LogicalPath are the
   directory-relative paths that line up across the two roots.
   =================================================================== *)

(* split an inventory into a logical equivalence map (CLAUDE.md /
   rules / skills) and the list of harness-only logical paths *)
iMigrationLogicalMap[inv_List] :=
  Module[{equiv, harnessOnly},
    equiv = Select[inv,
      MemberQ[{"RootInstruction", "Rule", "Skill"},
        Lookup[#, "Role"]] &];
    harnessOnly = Select[inv,
      !MemberQ[{"RootInstruction", "Rule", "Skill"},
        Lookup[#, "Role"]] &];
    <|
      "EquivMap" -> Association[
        (Lookup[#, "LogicalPath", ""] ->
          Lookup[#, "ContentHash", ""]) & /@ equiv],
      "HarnessOnly" -> Sort[
        Lookup[#, "LogicalPath", ""] & /@ harnessOnly]
    |>];

iMigrationLogicalMap[_] := <|"EquivMap" -> <||>, "HarnessOnly" -> {}|>;

(* logical (directory-relative, forward-slash) path of a file *)
iDirectiveRelLogical[base_String, path_String] :=
  Module[{bs, ps},
    bs = FileNameSplit[ExpandFileName[base]];
    ps = FileNameSplit[ExpandFileName[path]];
    If[Length[ps] > Length[bs] && Take[ps, Length[bs]] === bs,
      StringRiffle[Drop[ps, Length[bs]], "/"],
      StringRiffle[ps, "/"]]];

iDirectiveRelLogical[___] := "";

(* every file under claudeDir that is NOT a canonical-equivalent
   file (CLAUDE.md / rules / skills): the legacy harness-only set.
   Walks the real directory because settings.json and commands/*
   are not picked up by the *.md-only inventory. *)
iLegacyHarnessOnlyFiles[claudeDir_String, equivKeys_List] :=
  Module[{allFiles, allLogical},
    If[!DirectoryQ[claudeDir], Return[{}]];
    allFiles = Select[
      FileNames["*", claudeDir, Infinity], !DirectoryQ[#] &];
    allLogical = DeleteCases[
      iDirectiveRelLogical[claudeDir, #] & /@ allFiles, ""];
    Sort @ Complement[allLogical, equivKeys]];

iLegacyHarnessOnlyFiles[___] := {};

(* hash of a normalised {LogicalPath, ContentHash} equivalence map *)
iMigrationEquivHash[equivMap_Association] :=
  Module[{pairs},
    pairs = SortBy[
      {#, Lookup[equivMap, #, ""]} & /@ Keys[equivMap], First];
    "sha256-" <> ToLowerCase[Hash[
      ToString[pairs, InputForm], "SHA256", "HexString"]]];

iMigrationEquivHash[_] :=
  "sha256-" <> ToLowerCase[Hash["{}", "SHA256", "HexString"]];

(* ---- ClaudeDirectiveCompareCanonicalAndClaudeHarness ---- *)

ClaudeDirectiveCompareCanonicalAndClaudeHarness[
    directiveRoot_String, claudeDir_String] :=
  Module[{canonInv, legacyInv, canonMap, legacyMap,
          canonEquiv, legacyEquiv, ck, lk,
          onlyCanon, onlyLegacy, changed},
    canonInv = If[DirectoryQ[directiveRoot],
      ClaudeDirectiveFileInventory[directiveRoot,
        "IncludeOther" -> True], {}];
    legacyInv = If[DirectoryQ[claudeDir],
      ClaudeDirectiveFileInventory[claudeDir,
        "IncludeOther" -> True], {}];
    If[FailureQ[canonInv] || !ListQ[canonInv], canonInv = {}];
    If[FailureQ[legacyInv] || !ListQ[legacyInv], legacyInv = {}];

    canonMap  = iMigrationLogicalMap[canonInv];
    legacyMap = iMigrationLogicalMap[legacyInv];
    canonEquiv  = canonMap["EquivMap"];
    legacyEquiv = legacyMap["EquivMap"];
    ck = Keys[canonEquiv];
    lk = Keys[legacyEquiv];

    onlyCanon  = Sort[Complement[ck, lk]];
    onlyLegacy = Sort[Complement[lk, ck]];
    changed = Sort[Select[Intersection[ck, lk],
      Lookup[canonEquiv, #, ""] =!=
        Lookup[legacyEquiv, #, ""] &]];

    <|
      "CanonicalEquivMap"      -> canonEquiv,
      "LegacyEquivMap"         -> legacyEquiv,
      "FilesOnlyInCanonical"   -> onlyCanon,
      "FilesOnlyInLegacy"      -> onlyLegacy,
      "FilesChanged"           -> changed,
      "LegacyHarnessOnlyFiles" -> iLegacyHarnessOnlyFiles[claudeDir, lk],
      "CanonicalDirExists"     -> DirectoryQ[directiveRoot],
      "LegacyDirExists"        -> DirectoryQ[claudeDir]
    |>];

ClaudeDirectiveCompareCanonicalAndClaudeHarness[___] := $Failed;

(* ---- ClaudeDirectiveMigrationReport (spec 4.2) ---- *)

ClaudeDirectiveMigrationReport[
    directiveRoot_String, claudeDir_String, opts:OptionsPattern[]] :=
  Module[{cmp, canonEquiv, legacyEquiv, ck, lk,
          status, recommended, canonHash, legacyHash},
    cmp = ClaudeDirectiveCompareCanonicalAndClaudeHarness[
      directiveRoot, claudeDir];
    If[FailureQ[cmp],
      Return[Failure["ClaudeDirectiveMigrationReport", <|
        "MessageTemplate" ->
          "Could not compare the canonical and legacy directories.",
        "MessageParameters" -> <||>|>]]];

    canonEquiv  = cmp["CanonicalEquivMap"];
    legacyEquiv = cmp["LegacyEquivMap"];
    ck = Keys[canonEquiv];
    lk = Keys[legacyEquiv];

    canonHash  = iMigrationEquivHash[canonEquiv];
    legacyHash = iMigrationEquivHash[legacyEquiv];

    {status, recommended} = Which[
      ck =!= {} && lk =!= {},
        If[cmp["FilesOnlyInCanonical"] === {} &&
           cmp["FilesOnlyInLegacy"] === {} &&
           cmp["FilesChanged"] === {},
          {"Equivalent", "CanSwitchClaudeToGenerated"},
          {"Diverged", "ManualReview"}],
      ck === {} && lk =!= {},
        {"LegacyOnly", "ManualReview"},
      ck =!= {} && lk === {},
        (* canonical present, legacy absent: first migration when
           the legacy directory does not even exist *)
        If[TrueQ[cmp["LegacyDirExists"]],
          {"CanonicalOnly", "CanSwitchClaudeToGenerated"},
          {"CanonicalOnly", "ManualReview"}],
      True,
        {"Equivalent", "CanSwitchClaudeToGenerated"}];

    <|
      "CanonicalRoot"          -> directiveRoot,
      "LegacyClaudeDir"        -> claudeDir,
      "CanonicalHash"          -> canonHash,
      "LegacyHarnessHash"      -> legacyHash,
      "Status"                 -> status,
      "FilesOnlyInCanonical"   -> cmp["FilesOnlyInCanonical"],
      "FilesOnlyInLegacy"      -> cmp["FilesOnlyInLegacy"],
      "FilesChanged"           -> cmp["FilesChanged"],
      "LegacyHarnessOnlyFiles" -> cmp["LegacyHarnessOnlyFiles"],
      "RecommendedAction"      -> recommended
    |>];

ClaudeDirectiveMigrationReport[___] := $Failed;

End[]; (* `Private` *)
EndPackage[];

(* \:30ed\:30fc\:30c9\:6642\:30e1\:30c3\:30bb\:30fc\:30b8\:306f\:5ec3\:6b62 (2026-04-29).
   \:30d0\:30fc\:30b8\:30e7\:30f3\:60c5\:5831\:306f ClaudeDirectives`$ClaudeDirectivesVersion \:5909\:6570\:3067\:53c2\:7167\:53ef\:80fd\:3002 *)
