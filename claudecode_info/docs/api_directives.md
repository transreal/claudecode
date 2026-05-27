# claudecode_directives API リファレンス

Claude Code 互換の directive リポジトリ (.claude/CLAUDE.md, rules/, skills/) を読み込み、task / role / model に応じた prompt 投影や Codex / Claude CLI harness 生成を行うパッケージ。pure Wolfram Language、依存なし。

## ロード
```
Block[{$CharacterEncoding = "UTF-8"}, Get["ClaudeDirectives.wl"]]
```

## 変数

### $ClaudeDirectivesVersion
型: String
パッケージバージョン文字列。

### $ClaudeModelCapabilities
型: Association
キー: `{provider, model}` tuple (Phase 28 で String から変更)。値: `<|"ContextWindow"->Integer, "Class"->"Heavy-Cloud"|"Heavy-Local"|"Mid-Local"|"Light-Cloud"|"Light-Local", "DefaultMode"->"Full"|"Summary"|"Index"|"Lazy", "Strengths"->{"Code","Reasoning","Search","ToolUse",...}, "PreserveThinking"->True|False, "Paid"->True|False|>`。provider 名: `"claudecode"` (CLI、無課金), `"anthropic"` (API、課金), `"openai"` (API、課金), `"lmstudio"` (ローカル、無課金)。

### $ClaudeRoleDefaultModels
型: Association
Role → `{provider, model}` tuple のマッピング。ClaudeOrchestrator が worker spawn 時に参照する想定。

### $ClaudeSkillRolePolicy
型: Association
Role → {prefer skill name 一覧} のマッピング。iScoreSkill が role 別の優先 skill に +6 加点。

### $ClaudeRoleDefaultMode
型: Association
Role → default Mode (`"Full"|"Summary"|"Index"|"Lazy"`)。ClaudeResolveDirectiveBundle で mode === Automatic のとき優先採用。

### $ClaudeRoleMaxSkills
型: Association
Role → default skill 上限 (Integer)。Options[ClaudeResolveDirectiveBundle] の MaxSkills が Automatic のとき採用。

### $ClaudeDirectiveRepository
型: Association
読み込み済みリポジトリのキャッシュ。`<|"Root"->path, "ClaudeMD"->str, "Rules"->{ruleAssoc...}, "Skills"->{skillAssoc...}, "LoadedAt"->AbsoluteTime|>`。

### $ClaudeAlwaysOnRules
型: List of String
タスク内容に関係なく常時注入される rule 名のリスト。セキュリティ・基本マナー系を登録。ClaudeSelectRulesForTask が参照。

### $CodexRuleLargeByteThreshold
型: Integer, 初期値: 8192
ClaudeDirectiveClassifyRule が rule を "large" 分類する byte 数の境界。

## モデル能力管理

### ClaudeRegisterModelCapability[name, spec]
$ClaudeModelCapabilities に追加・更新。name は `{provider, model}` tuple または String キー (互換)、spec は能力 Association。

### ClaudeResolveModelCapability[modelName] → Association
モデル名から能力 Association を返す。未登録時は保守的既定値 (ContextWindow 32000, DefaultMode "Summary")。

### ClaudeResolveModelMode[modelName] → String
既定 ProjectionMode (`"Full"|"Summary"|"Index"|"Lazy"`) を返す。

### ClaudeResolveModelContextWindow[modelName] → Integer
ContextWindow (token 数) を返す。

## Directive Repository 読み込み

### ClaudeFindDirectiveRoots[] → {String...}
.claude / Claude Directives ディレクトリの候補を探索し、実在ディレクトリのリストを返す。

### ClaudeLoadDirectiveRepository[] → Association
### ClaudeLoadDirectiveRepository[root] → Association
自動探索 (または指定 root) から読み込み。結果は $ClaudeDirectiveRepository にキャッシュされる。

### ClaudeInvalidateDirectiveCache[] → Null
$ClaudeDirectiveRepository を空にして再読込を強制。

### ClaudeDirectivesParseFrontmatter[text] → Association
SKILL.md 先頭の YAML frontmatter を解析。`<|"Frontmatter"->Association, "Body"->String|>`。

## Bundle / Projection

### ClaudeResolveDirectiveBundle[opts] → Association
task / role / model に応じた directive bundle を返す。
Options:
- `"Role"` -> None (`"Plan"|"Draft"|"Verify"|"Commit"|"Explore"|"Reduce"|None`)
- `"Model"` -> None (モデル名、capability テーブル参照キー)
- `"Mode"` -> Automatic (`"Full"|"Summary"|"Index"|"Lazy"|Automatic`)
- `"TaskHint"` -> "" (プロンプト文字列、skill 選別に使用)
- `"TokenBudget"` -> Automatic (Integer | Automatic)

戻り値キー: `"ClaudeMD"`, `"ActiveRules"`, `"ActiveSkills"`, `"ProjectionMode"`, `"TokenBudget"`, `"DirectiveMeta"`。

### ClaudeProjectDirectives[bundle] → String
### ClaudeProjectDirectives[bundle, mode] → String
bundle を prompt 用文字列に投影。第 2 引数で明示モード指定。

### ClaudeDirectiveTokenEstimate[text] → Integer
文字列のトークン数概算 (StringLength/3 で近似)。

### ClaudeSelectSkillsForTask[repo, taskHint, opts] → {Association...}
task hint に関連する skill をスコアリングして並べ替えて返す。
Options:
- `"Role"` -> None (Role 名)
- `"MaxSkills"` -> 5 (Integer)
- `"ModelStrengths"` -> {} ({String...}、skill フィルタに使用)

### ClaudeSelectRulesForRole[repo, role] → {Association...}
role ごとの always-on rules を選別。Phase 35 stage1 以降は後方互換のため `Lookup[repo, "Rules", {}]` を返す。

### ClaudeSelectRulesForTask[repo, taskHint, opts] → {Association...}
task hint に関連する rules を選別 (Phase 35 stage1)。$ClaudeAlwaysOnRules の rule は無条件で含み、それ以外は frontmatter の keywords / paths と TaskHint の交差度でスコア化して上位を採用。
Options:
- `"Role"` -> None (Role 名)
- `"MaxRules"` -> 8 (always-on を超える分の上限)
- `"MinScore"` -> 1 (Integer)

## 統合エントリ

### ClaudeBuildDirectivePromptForRole[role, modelName, taskHint] → String
1 行で directive 投影テキストを返す統合エントリ。ClaudeOrchestrator の worker BuildContext 想定。

### ClaudeBuildDirectivePromptForSingle[modelName, taskHint] → String
単一エージェント (claudecode の ClaudeEval / iAdapterBuildPrompt) 用。Role は None として扱う。

## Phase 1.0: Inventory / Manifest / Hash

### ClaudeResolveDirectiveRoot[Automatic] → String | Failure
### ClaudeResolveDirectiveRoot[root_String] → String | Failure
Automatic は ClaudeFindDirectiveRoots で正規 root 解決。存在しなければ `Failure["DirectiveRootNotFound"]`。文字列指定時はディレクトリ実在を検証。

### ClaudeDirectiveFileInventory[root, opts] → {Association...}
root のファイルインベントリ (RelativePath ソート済み) を返す。root はディレクトリ文字列または Automatic。各レコードのスキーマ: `Role, RelativePath, LogicalPath, AbsolutePath, ContentHash, ByteCount, LineCount, Name, Title, Description, FrontMatter, Paths, TokenEstimate, ModifiedTime`。Role は `"RootInstruction" | "Rule" | "Skill" | "Other"`。
Options:
- `"IncludeOther"` -> True (rule/skill 以外のリポジトリ trvel ファイルを含めるか)

### ClaudeDirectiveRepositoryInventory[root] → {Association...}
ClaudeDirectiveFileInventory のエイリアス。

### ClaudeDirectiveRepositoryManifest[root] → Association
DirectiveRepositoryManifest を返す。キー: `Kind, CanonicalFormat, Root, Files (inventory), FilesCount, RulesCount, SkillsCount, ManifestHash, CreatedAt, Generator`。ManifestHash はソート済み {RelativePath, ContentHash} ペアのみに依存し、ModifiedTime/TokenEstimate 変化に対し安定。

### ClaudeDirectiveRepositoryHash[root] → String
ManifestHash 文字列のみを返す。

## Phase 1.1a: rule 派生メタ / 分類

### ClaudeDirectiveRuleDerivedMetadata[ruleRecord, opts] → Association
rule inventory レコード (Role -> "Rule") から Codex harness 用メタを導出。canonical rule frontmatter には description/summary/trigger がないため、heading (Title) と paths frontmatter から決定的に導出。戻り値キー: `Title, Summary, Description, Trigger, DescriptionSource ("derived-from-paths-and-heading" | "override" | "fallback"), Paths`。
Options:
- `"RuleMetadataOverrides"` -> <||> (rule Name キーの override Association)

### ClaudeDirectiveClassifyRule[ruleRecord, opts] → Association
rule inventory レコードを harness materialization 用に分類。戻り値キー: `Scope ("always-on" | "task-specific"), SizeClass ("small" | "large"), CommandPolicy, InlineSummaryInAgentsMd (candidate; AGENTS.md byte budget で再評価), Reason`。
Options:
- `"AlwaysOnRules"` -> Automatic
- `"RuleLargeByteThreshold"` -> Automatic
- `"RuleMetadataOverrides"` -> <||>

## Phase 1.1b-1: harness plan (dry-run)

### ClaudeDirectiveHarnessPlan[bundle, target, opts] → Association | Failure
target は `"Codex"` または `"ClaudeCLI"`。ClaudeCLI plan は AGENTS.md/index 無しの verbatim copy plan。ファイル書き込みなし。戻り値キー: `Target, HarnessMaterializationMode, DirectiveRepositoryManifestHash, SourceVaultSnapshotId, AgentsMd (TargetRelativePath / EstimatedByteCount / InlineRuleNames / OmittedRuleNames / HardMaxBytes), Index (TargetRelativePath / Entries), GeneratedSkills, CommandPolicyRules, ProvenanceFiles, Warnings`。
Options:
- `"HarnessMaterializationMode"` -> Automatic
- `"AgentsMdTargetMaxBytes"` -> 20000
- `"AgentsMdHardMaxBytes"` -> 30000
- `"RuleLargeByteThreshold"` -> Automatic
- `"AlwaysOnRules"` -> Automatic
- `"RuleMetadataOverrides"` -> <||>
- `"SourceVaultSnapshotId"` -> Missing["NotRegistered"]

## Phase 1.1b-2: Codex harness materialization

### ClaudeDirectiveHarnessProvenanceHeader[meta] → String
生成 AGENTS.md 先頭の HTML コメント provenance ヘッダを返す。meta は `DirectiveRepositoryManifestHash, SourceVaultSnapshotId, HarnessMaterializationMode` を含む Association。

### ClaudeDirectiveMaterializeCodexHarness[bundle, targetDir, opts] → Association
targetDir 配下に Codex harness を生成。ClaudeDirectiveHarnessPlan を実行し、`.agents/skills/<name>/SKILL.md`, `.agents/directive-index.json`, `AGENTS.md`, provenance を固定順で書き出す。canonical リポジトリは never modified。DryRun -> True で書き込みなしで plan を返す。戻り値キー: `WrittenFiles, AgentsMd, Index, GeneratedSkills, ProvenanceFiles, Warnings, Plan`。
Options: ClaudeDirectiveHarnessPlan のオプション全部 +
- `"GenerateDirectiveIndex"` -> True
- `"GenerateProvenance"` -> True
- `"CommandPolicyMaterialization"` -> 既定実装値
- `"DryRun"` -> False
- `"FailOnAgentsMdOverflow"` -> 既定実装値

例:
```
ClaudeDirectiveMaterializeCodexHarness[bundle, "C:/tmp/codex-proj",
  "DryRun" -> True, "AgentsMdTargetMaxBytes" -> 15000]
```

## Phase 4: Claude CLI harness materialization

### ClaudeDirectiveMaterializeClaudeHarness[bundle, targetDir, opts] → Association
canonical リポジトリから `.claude/CLAUDE.md`, `.claude/rules/<name>.md`, `.claude/skills/<name>/SKILL.md` を verbatim copy で書き出す ($ClaudeCLIHarnessMode -> "Generated")。rule-to-skill 変換、AGENTS.md、directive index は無し。provenance は `.claude/sourcevault-provenance.json`。`.claude/settings.json` は書き出さない (claudecode.wl 側で注入)。canonical リポジトリは never modified。DryRun -> True で書き込みなしで plan を返す。戻り値キー: `WrittenFiles, RootInstruction, GeneratedFiles, ProvenanceFiles, Warnings, Plan`。
Options:
- `"HarnessMaterializationMode"` -> Automatic
- `"DirectiveRepositoryManifestHash"` -> Automatic
- `"SourceVaultSnapshotId"` -> Missing["NotRegistered"]
- `"GenerateProvenance"` -> True
- `"DryRun"` -> False

## Phase 2.5: migration gate

### ClaudeDirectiveCompareCanonicalAndClaudeHarness[directiveRoot, claudeDir] → Association | $Failed
canonical Claude Directives リポジトリと legacy `.claude/` harness を正規化 logical path (CLAUDE.md, rules/<name>.md, skills/<name>/SKILL.md) で比較。戻り値キー: `CanonicalEquivMap, LegacyEquivMap, FilesOnlyInCanonical, FilesOnlyInLegacy, FilesChanged, LegacyHarnessOnlyFiles (settings.json 等、equivalence からは除外), CanonicalDirExists, LegacyDirExists`。

### ClaudeDirectiveMigrationReport[directiveRoot, claudeDir] → Association | Failure
migration gate: legacy `.claude/` harness が canonical リポジトリと等価か報告。戻り値キー: `CanonicalRoot, LegacyClaudeDir, CanonicalHash, LegacyHarnessHash, Status, FilesOnlyInCanonical, FilesOnlyInLegacy, FilesChanged, LegacyHarnessOnlyFiles, RecommendedAction`。Status は `"Equivalent" | "Diverged" | "LegacyOnly" | "CanonicalOnly"`。Hash は normalised {LogicalPath, ContentHash} ペアのみで計算、harness-only ファイルは Status に影響しない。Claude CLI を Generated mode に切り替えるには Status `"Equivalent"` または手動承認が必要。

## 関連パッケージ

- [claudecode](https://github.com/transreal/claudecode) — 本パッケージを optional 依存として利用する上位パッケージ
- [ClaudeOrchestrator](https://github.com/transreal/ClaudeOrchestrator) — worker spawn 時に Role -> default model マッピングを参照
- [SourceVault](https://github.com/transreal/SourceVault) — SourceVaultSnapshotId 連携先