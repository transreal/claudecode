# claudecode_directives API リファレンス

LLM 向け API リファレンス。Claude Code 互換ディレクティブリポジトリ (.claude/CLAUDE.md, rules/, skills/) の読み込み・解決・投影と、Codex/Claude CLI ハーネス生成を提供する純粋 Wolfram Language パッケージ。

## ロード

```
Block[{$CharacterEncoding = "UTF-8"}, Get["ClaudeDirectives.wl"]]
```

依存なし (pure Wolfram Language)。

## バージョン変数

### $ClaudeDirectivesVersion
型: String
パッケージバージョン文字列。

## モデル能力テーブル

### $ClaudeModelCapabilities
型: Association ({provider, model} -> spec)
キーは `{provider, model}` tuple。値は `<|"ContextWindow"->Integer, "Class"->"Heavy-Cloud"|"Heavy-Local"|"Mid-Local"|"Light-Cloud"|"Light-Local", "DefaultMode"->"Full"|"Summary"|"Index"|"Lazy", "Strengths"->{"Code","Reasoning","Search","ToolUse",...}, "PreserveThinking"->True|False, "Paid"->True|False|>`。provider 名: `"claudecode"` (CLI, 無料), `"anthropic"` (API, 課金), `"openai"` (API, 課金), `"lmstudio"` (ローカル, 無料)。Phase 28 で tuple キー化。

### $ClaudeRoleDefaultModels
型: Association (Role -> {provider, model})
worker spawn 時に ClaudeOrchestrator が参照する Role 別既定モデル。

### $ClaudeSkillRolePolicy
型: Association (Role -> {skill name list})
iScoreSkill が role 別優先 skill に +6 加点する。

### $ClaudeRoleDefaultMode
型: Association (Role -> "Full"|"Summary"|"Index"|"Lazy")
ClaudeResolveDirectiveBundle で mode === Automatic のとき採用される既定。

### $ClaudeRoleMaxSkills
型: Association (Role -> Integer)
ClaudeResolveDirectiveBundle の MaxSkills が Automatic のとき採用される既定上限。

### $ClaudeAlwaysOnRules
型: List of String
タスク内容に関係なく常時注入される rule 名のリスト。ClaudeSelectRulesForTask が参照。

### $CodexRuleLargeByteThreshold
型: Integer, 初期値: 8192
ClaudeDirectiveClassifyRule が "large" 判定に使うバイト数境界。

## モデル能力 API

### ClaudeRegisterModelCapability[name, spec] → Association
`$ClaudeModelCapabilities` にモデル能力を追加・更新する。name は `{provider, model}` tuple または String (互換)。

### ClaudeResolveModelCapability[modelName] → Association
モデル名から能力 Association を返す。未登録時は保守的既定 (ContextWindow 32000, DefaultMode "Summary")。

### ClaudeResolveModelMode[modelName] → String
既定 ProjectionMode ("Full"|"Summary"|"Index"|"Lazy") を返す。

### ClaudeResolveModelContextWindow[modelName] → Integer
ContextWindow (token 数) を返す。

## Directive Repository

### $ClaudeDirectiveRepository
型: Association
読み込み済みリポジトリのキャッシュ。`<|"Root"->path, "ClaudeMD"->str, "Rules"->{ruleAssoc...}, "Skills"->{skillAssoc...}, "LoadedAt"->AbsoluteTime|>`。

### ClaudeFindDirectiveRoots[] → {String...}
.claude / Claude Directives ディレクトリ候補を探索し、実在するもののリストを返す。

### ClaudeLoadDirectiveRepository[] → Association
### ClaudeLoadDirectiveRepository[root] → Association
自動探索または指定ディレクトリから読み込む。結果は `$ClaudeDirectiveRepository` にキャッシュ。

### ClaudeInvalidateDirectiveCache[] → Null
`$ClaudeDirectiveRepository` を空にして再読込を強制。

## Bundle / Projection

### ClaudeResolveDirectiveBundle[opts]
task/role/model に応じた directive bundle を返す。
→ Association (`<|"ClaudeMD"->..., "ActiveRules"->..., "ActiveSkills"->..., "ProjectionMode"->..., "TokenBudget"->..., "DirectiveMeta"->...|>`)
Options: "Role" -> None ("Plan"|"Draft"|"Verify"|"Commit"|"Explore"|"Reduce"|None), "Model" -> None (capability テーブル参照キー), "Mode" -> Automatic ("Full"|"Summary"|"Index"|"Lazy"|Automatic), "TaskHint" -> "" (skill 選別に使用), "TokenBudget" -> Automatic (Integer | Automatic)

### ClaudeProjectDirectives[bundle] → String
### ClaudeProjectDirectives[bundle, mode] → String
bundle を prompt 用文字列に投影する。mode 指定で明示モード使用。

### ClaudeDirectiveTokenEstimate[text] → Integer
文字列のトークン数概算 (StringLength/3 近似、英日混在対応)。

### ClaudeSelectSkillsForTask[repo, taskHint, opts] → {skillAssoc...}
task hint に関連する skill をスコアリングし並べ替えて返す。
Options: "Role" -> None (Role 名), "MaxSkills" -> 5 (Integer), "ModelStrengths" -> {} ({String...}, skill フィルタに使用)

### ClaudeSelectRulesForRole[repo, role] → {ruleAssoc...}
role ごとの always-on rules を選別。Phase 35 stage1 以降は後方互換のため `Lookup[repo, "Rules", {}]` を返す。

### ClaudeSelectRulesForTask[repo, taskHint, opts] → {ruleAssoc...}
task hint に関連する rules を選別する。`$ClaudeAlwaysOnRules` に列挙された rule は無条件で含める。それ以外は frontmatter の keywords/paths と TaskHint の交差度でスコア化し上位を採用。
Options: "Role" -> None, "MaxRules" -> 8 (always-on を超える分の上限), "MinScore" -> 1

## 統合エントリ

### ClaudeBuildDirectivePromptForRole[role, modelName, taskHint] → String
1 行で directive 投影テキストを返す統合エントリ。ClaudeOrchestrator の worker BuildContext から呼び出される想定。

### ClaudeBuildDirectivePromptForSingle[modelName, taskHint] → String
単一エージェント (claudecode の ClaudeEval / iAdapterBuildPrompt) 用の directive 投影テキストを返す。Role は None として扱う。

## 内部公開 (テスト用)

### ClaudeDirectivesParseFrontmatter[text] → Association
SKILL.md 先頭の YAML frontmatter を解析。`<|"Frontmatter"->Association, "Body"->String|>`。

## Phase 1.0: Inventory / Manifest / Hash

### ClaudeResolveDirectiveRoot[Automatic] → String | Failure
### ClaudeResolveDirectiveRoot[root_String] → String | Failure
canonical Claude Directives root を解決。未発見時は `Failure["DirectiveRootNotFound"]`。

### ClaudeDirectiveFileInventory[root, opts] → {fileRecord...} | Failure
リポジトリの inventory をソート済み file record リストとして返す。root は directory string または Automatic。各 record スキーマ: Role, RelativePath, LogicalPath, AbsolutePath, ContentHash, ByteCount, LineCount, Name, Title, Description, FrontMatter, Paths, TokenEstimate, ModifiedTime。Role は `"RootInstruction"|"Rule"|"Skill"|"Other"`。
Options: "IncludeOther" -> True (rule/skill 以外のリポジトリファイルを含めるか)

### ClaudeDirectiveRepositoryInventory[root] → {fileRecord...}
`ClaudeDirectiveFileInventory[root]` のエイリアス。

### ClaudeDirectiveRepositoryManifest[root] → Association
DirectiveRepositoryManifest association を返す。キー: Kind, CanonicalFormat, Root, Files (inventory), FilesCount, RulesCount, SkillsCount, ManifestHash, CreatedAt, Generator。ManifestHash はソート済み {RelativePath, ContentHash} 対のみに依存し ModifiedTime/TokenEstimate 変動に対し安定。

### ClaudeDirectiveRepositoryHash[root] → String
リポジトリの ManifestHash 文字列のみを返す。

## Phase 1.1a: Rule 派生メタデータ / 分類

### ClaudeDirectiveRuleDerivedMetadata[ruleRecord, opts] → Association | $Failed
rule inventory record から Codex-harness メタデータを派生。canonical rule frontmatter は description/summary/trigger を持たない前提で、Title (見出し) と paths frontmatter から決定論的に派生。
→ `<|"Title", "Summary", "Description", "Trigger", "DescriptionSource"("derived-from-paths-and-heading"|"override"|"fallback"), "Paths"|>`
Options: "RuleMetadataOverrides" -> <||> (rule Name キーの opt-in 上書き Association)

### ClaudeDirectiveClassifyRule[ruleRecord, opts] → Association
rule inventory record を harness materialization 用に分類。
→ `<|"Scope"("always-on"|"task-specific"), "SizeClass"("small"|"large"), "CommandPolicy", "InlineSummaryInAgentsMd" (候補値、最終 inline 判定は AGENTS.md byte budget 再評価), "Reason"|>`
Options: "AlwaysOnRules" -> Automatic, "RuleLargeByteThreshold" -> Automatic, "RuleMetadataOverrides" -> <||>

## Phase 1.1b-1: Harness Plan (dry-run)

### ClaudeDirectiveHarnessPlan[bundle, target, opts] → Association | Failure
ファイル書き出しなしで harness materialization plan を返す。target は `"Codex"` または `"ClaudeCLI"`。"ClaudeCLI" plan は verbatim-copy plan (AGENTS.md/directive index なし)。
→ Association (Target, HarnessMaterializationMode, DirectiveRepositoryManifestHash, SourceVaultSnapshotId, AgentsMd <|TargetRelativePath, EstimatedByteCount, InlineRuleNames, OmittedRuleNames, HardMaxBytes|>, Index <|TargetRelativePath, Entries|>, GeneratedSkills, CommandPolicyRules, ProvenanceFiles, Warnings)
Options: "HarnessMaterializationMode" -> Automatic, "AgentsMdTargetMaxBytes" -> 20000, "AgentsMdHardMaxBytes" -> 30000, "RuleLargeByteThreshold" -> Automatic, "AlwaysOnRules" -> Automatic, "RuleMetadataOverrides" -> <||>, "SourceVaultSnapshotId" -> Missing["NotRegistered"]

例:
```
plan = ClaudeDirectiveHarnessPlan[bundle, "Codex",
  "AgentsMdTargetMaxBytes" -> 16000];
```

## Phase 1.1b-2: Codex Harness Materialization

### ClaudeDirectiveHarnessProvenanceHeader[meta] → String
生成 AGENTS.md 先頭に置く HTML-comment provenance header。meta は DirectiveRepositoryManifestHash, SourceVaultSnapshotId, HarnessMaterializationMode を持つ Association。

### ClaudeDirectiveMaterializeCodexHarness[bundle, targetDir, opts] → Association
`ClaudeDirectiveHarnessPlan` を実行し Codex harness を targetDir に materialize。書き出し順 (固定): `.agents/skills/<name>/SKILL.md`, `.agents/directive-index.json`, `AGENTS.md`, provenance files。canonical Claude Directives リポジトリは決して変更しない。
→ Association (WrittenFiles, AgentsMd, Index, GeneratedSkills, ProvenanceFiles, Warnings, Plan)
Options: "HarnessMaterializationMode" -> Automatic, "AgentsMdTargetMaxBytes" -> 20000, "AgentsMdHardMaxBytes" -> 30000, "RuleLargeByteThreshold" -> Automatic, "AlwaysOnRules" -> Automatic, "RuleMetadataOverrides" -> <||>, "SourceVaultSnapshotId" -> Missing["NotRegistered"], "GenerateDirectiveIndex" -> True, "GenerateProvenance" -> True, "CommandPolicyMaterialization" -> ..., "DryRun" -> False, "FailOnAgentsMdOverflow" -> ...

DryRun -> True で書き出しなし、plan のみ返す。

## Phase 4: Claude CLI Generated Harness

### ClaudeDirectiveMaterializeClaudeHarness[bundle, targetDir, opts] → Association
canonical Claude Directives から Claude CLI harness を targetDir に materialize (Phase 4, `$ClaudeCLIHarnessMode -> "Generated"`)。`.claude/CLAUDE.md`, `.claude/rules/<name>.md`, `.claude/skills/<name>/SKILL.md` を canonical ファイルの verbatim copy として書き出し (rule-to-skill 変換なし、AGENTS.md なし、directive index なし)、`.claude/sourcevault-provenance.json` も生成。canonical リポジトリは変更しない。`.claude/settings.json` は呼出側 (claudecode.wl) が read permission を注入する想定で本関数では書かない。
→ Association (WrittenFiles, RootInstruction, GeneratedFiles, ProvenanceFiles, Warnings, Plan)
Options: "HarnessMaterializationMode" -> Automatic, "SourceVaultSnapshotId" -> Missing["NotRegistered"], "DirectiveRepositoryManifestHash" -> Automatic, "GenerateProvenance" -> True, "DryRun" -> False

## Phase 2.5: Migration Gate

### ClaudeDirectiveCompareCanonicalAndClaudeHarness[directiveRoot, claudeDir] → Association | $Failed
canonical Claude Directives リポジトリと legacy `.claude/` harness を normalised logical path (CLAUDE.md, rules/<name>.md, skills/<name>/SKILL.md) で比較。
→ `<|"CanonicalEquivMap", "LegacyEquivMap", "FilesOnlyInCanonical", "FilesOnlyInLegacy", "FilesChanged", "LegacyHarnessOnlyFiles" (settings.json 等、equivalence 対象外), "CanonicalDirExists", "LegacyDirExists"|>`

### ClaudeDirectiveMigrationReport[directiveRoot, claudeDir] → Association | Failure
migration gate。legacy `.claude/` harness が canonical と等価か報告。
→ `<|"CanonicalRoot", "LegacyClaudeDir", "CanonicalHash", "LegacyHarnessHash", "Status", "FilesOnlyInCanonical", "FilesOnlyInLegacy", "FilesChanged", "LegacyHarnessOnlyFiles", "RecommendedAction"|>`
Status: `"Equivalent"|"Diverged"|"LegacyOnly"|"CanonicalOnly"`。Hash は CLAUDE.md / rules / skills のみの normalised {LogicalPath, ContentHash} 対で計算。harness-only files は Status に影響しない。Claude CLI を Generated mode に切替えるには Status `"Equivalent"` または手動承認が必要。

## 関連パッケージ

- [claudecode](https://github.com/transreal/claudecode) — directive 投影を optional に呼び出す側
- [ClaudeOrchestrator](https://github.com/transreal/ClaudeOrchestrator) — worker spawn 時に `ClaudeBuildDirectivePromptForRole` を利用
- [NBAccess](https://github.com/transreal/NBAccess) — notebook アクセス層 (本パッケージは依存しない)