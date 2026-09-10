# claudecode_directives API リファレンス

ディレクティブリポジトリ (.claude/CLAUDE.md, rules/, skills/) の読み込み・モデル能力管理・DirectiveBundle 解決・PromptProjection 生成・Codex/ClaudeCLI ハーネス生成を行う純 Wolfram Language パッケージ。claudecode.wl / NBAccess.wl に依存しない。[claudecode](https://github.com/transreal/claudecode) 側から optional に呼ばれる想定。

ロード:
```
Block[{$CharacterEncoding = "UTF-8"}, Get["ClaudeDirectives.wl"]]
```

## バージョン・変数
### $ClaudeDirectivesVersion
型: String
パッケージバージョン文字列。

### $ClaudeModelCapabilities
型: Association, キー: {provider, model} tuple
モデル能力テーブル。値は `<|"ContextWindow"->Integer, "Class"->"Heavy-Cloud"|"Heavy-Local"|"Mid-Local"|"Light-Cloud"|"Light-Local", "DefaultMode"->"Full"|"Summary"|"Index"|"Lazy", "Strengths"->{"Code","Reasoning","Search","ToolUse",...}, "PreserveThinking"->True|False, "Paid"->True|False, "DirectiveLevel"->"Minimal"|"Standard"|"Full", "Generation"->String|>`。provider 名: `"claudecode"` (CLI、課金なし), `"anthropic"` (API、課金), `"openai"` (API、課金), `"lmstudio"` (ローカル、課金なし)。Anthropic CLI Opus と Anthropic API Opus は別モデルとして両方登録される。

### $ClaudeRoleDefaultModels
型: Association, Role -> {provider, model} tuple
Role 別の既定モデル。ClaudeOrchestrator が worker spawn 時に参照する想定。

### $ClaudeSkillRolePolicy
型: Association, Role -> {prefer skill name...}
role 別の優先 skill 一覧。iScoreSkill が該当 skill に +6 加点する。

### $ClaudeRoleDefaultMode
型: Association, Role -> Mode ("Full"|"Summary"|"Index"|"Lazy")
Role 別の既定 Mode。ClaudeResolveDirectiveBundle で mode===Automatic のとき優先採用。

### $ClaudeRoleMaxSkills
型: Association, Role -> Integer
Role 別の既定 skill 上限。MaxSkills が Automatic のとき採用。

### $ClaudeAlwaysOnRules
型: List of String
タスク内容に関係なく常時注入される rule 名のリスト。ClaudeSelectRulesForTask が参照。

### $ClaudeDirectiveRepository
型: Association
読み込み済みリポジトリのキャッシュ。`<|"Root"->path, "ClaudeMD"->str, "Rules"->{ruleAssoc...}, "Skills"->{skillAssoc...}, "LoadedAt"->AbsoluteTime|>`。

### $CodexRuleLargeByteThreshold
型: Integer, 初期値: 8192
ClaudeDirectiveClassifyRule が rule を "large" と分類するバイト境界。

## モデル能力
### ClaudeRegisterModelCapability[name, spec] → Association
$ClaudeModelCapabilities にモデル能力を追加・更新。name は {provider, model} tuple・String キーの両方を accept。

### ClaudeResolveModelCapability[modelSpec] → Association
モデル指定から能力 Association を返す。modelSpec は `{provider, model}` / `{provider, model, url}` タプル、`"provider/model"`、文字列化タプル `"{provider, model}"`、素のモデル名のいずれも可 (2026-09-08: 旧版は String で tuple キーを引いていたため常に不一致で、ローカルモデルが全て 32K/Unknown に落ちていた)。順序: 完全一致タプル → 同名モデルの別 provider → provider 推定の最強モデル (未登録ローカルモデルは DirectiveLevel "Full" に保守化、`ResolvedFrom -> "provider-fallback"`)。未登録時は保守的既定値 (ContextWindow 32000, DefaultMode "Summary")。

### ClaudeNormalizeModelSpec[spec] → {provider | None, model}
上記すべての spec 形を正規化する純関数。provider 綴りの別名 (`lm-studio`→`lmstudio`, `claude`→`claudecode`, `codex`→`chatgptcodex` 等) も吸収。

### ClaudeResolveModelMode[modelSpec] → String
既定 ProjectionMode を返す。

### ClaudeResolveModelContextWindow[modelSpec] → Integer
ContextWindow (token 数) を返す。

## DirectiveLevel (モデル世代別の指示水準, 2026-09-08)
ProjectionMode (Full/Summary/Index/Lazy = **どれだけ入るか**、文脈長) と直交する第 2 軸 **DirectiveLevel = どれだけ必要か** (モデル世代)。Anthropic 2026-07-24 の知見 (Claude 5 世代では system prompt の 8 割超を削っても評価が落ちない: 禁止事項列挙・冗長なツール例・矛盾指示が不要になり、残るのは不可逆操作のガード・文脈から推測できない落とし穴・チーム固有の意見) を、rule の `tier:` frontmatter とモデル別レベルで実装する。

- `$ClaudeDirectiveLevels` = `{"Minimal", "Standard", "Full"}`。
- rule frontmatter `tier:` = `safety` (不可逆・秘密・privacy・課金: 常に全文) / `guardrail` (文脈から推測できない落とし穴: Minimal では名前+説明の 1 行索引) / `procedure` (明示手順: Minimal で除外) / `style` (書式・言い回し: Standard で除外) / `evolved` (TurnWiki 昇格スキル: 常に全文)。無指定は `$ClaudeDefaultRuleTier` (`guardrail`)。
- `$ClaudeRuleTierPolicy` = level → `<|tier -> "Full" | "Index" | None|>`。
- rule frontmatter `models:` / `exclude_models:` (`provider:model`, `provider:*`, `*:model`, `model`) で適用モデルを限定できる (TurnWiki の昇格スキルは検証したプロファイルにのみ配られる)。
- 能力表に `"DirectiveLevel"` と `"Generation"` を追加 (Claude 5 世代 = Minimal、他の Heavy = Standard、Mid/Light/旧世代 = Full)。

### $ClaudeDirectiveLevelOverrides / $ClaudeDirectiveLevelResolver / $ClaudeDirectiveDefaultLevel
$ClaudeDirectiveLevelOverrides: Association, `{provider,model} | provider | model -> level`。ClaudeResolveDirectiveLevel で最優先に解決され、ClaudeSetDirectiveLevelOverride で書き込む。$ClaudeDirectiveLevelResolver: None | `f[{provider,model}] -> level | None`。適応層のフック (ClaudeOrchestrator`TurnWiki` が directive-levels.json を読む関数をここに登録)。$ClaudeDirectiveDefaultLevel: "Standard"。override/resolver/能力表/Class いずれも決められない場合の既定値。

### ClaudeResolveDirectiveLevel[modelSpec] → `<|"Level", "Source", "Provider", "Model"|>`
解決順: `$ClaudeDirectiveLevelOverrides` (tuple > "prov/model" > model > provider) → `$ClaudeDirectiveLevelResolver` (適応層のフック。TurnWiki が `directive-levels.json` を読む関数を登録) → 能力表 `DirectiveLevel` → Class 由来 (Ultra→Minimal, Heavy→Standard, 他→Full) → `$ClaudeDirectiveDefaultLevel`。

### ClaudeSetDirectiveLevelOverride[modelSpec, level | None] → key
override の登録/解除。

### ClaudeDirectiveRuleTier[ruleAssoc] / ClaudeDirectiveRuleAppliesToModelQ[ruleAssoc, modelSpec] / ClaudeApplyDirectiveLevel[rules, level]
純関数。ApplyDirectiveLevel は policy に従って rule を落とすか `"Projection" -> "Full" | "Index"` を付ける。

### ClaudeDirectiveBundleDiagnostics[modelSpec, taskHint, opts] → Association
bundle の DirectiveMeta (DirectiveLevel, LevelSource, ProjectionMode, RuleProjections, RuleTiers, DroppedByLevel, DroppedByModel, EstimatedTokens, ProjectedChars) を投影せずに返す診断。

### ClaudeResolveDirectiveBundle の追加オプション
`"DirectiveLevel" -> Automatic | level` (明示指定は Source "option")、`"ToolAccess" -> False | True` (呼び出し側がディレクティブ取得ツール `sourcevault_directives` / `sourcevault_directive_body` を持つツールループを回すとき True: 投影末尾に「名前だけ列挙した rule/skill はツールで取れ」の案内を付ける)。bundle は `"DirectiveLevel"`, `"ToolAccess"` を持ち、DirectiveMeta に `ModelSpec`, `ModelGeneration`, `LevelSource`, `RuleProjections`, `RuleTiers`, `DroppedByLevel`, `DroppedByModel` が加わる。`ClaudeBuildDirectivePromptForSingle[modelSpec, taskHint, opts]` はタプルと同オプションを受ける。

## Directive Repository
### ClaudeFindDirectiveRoots[] → {String...}
.claude / Claude Directives ディレクトリ候補を探索し、実在ディレクトリのリストを返す。

### ClaudeLoadDirectiveRepository[] → Association
### ClaudeLoadDirectiveRepository[root] → Association
自動探索 (引数なし) または指定 root からリポジトリを読み込む。結果は $ClaudeDirectiveRepository にキャッシュされる。

### ClaudeInvalidateDirectiveCache[] → Null
$ClaudeDirectiveRepository を空にして再読込を強制。

### ClaudeDirectivesParseFrontmatter[text] → Association
SKILL.md 先頭の YAML frontmatter を解析。`<|"Frontmatter"->Association, "Body"->String|>`。

## Bundle / Projection
### ClaudeResolveDirectiveBundle[opts]
task / role / model に応じた directive bundle を返す。
→ Association `<|"ClaudeMD"->..., "ActiveRules"->..., "ActiveSkills"->..., "ProjectionMode"->..., "TokenBudget"->..., "DirectiveMeta"->...|>`
Options: "Role" -> "Plan"|"Draft"|"Verify"|"Commit"|"Explore"|"Reduce"|None, "Model" -> モデル名 (capability テーブル参照キー), "Mode" -> "Full"|"Summary"|"Index"|"Lazy"|Automatic, "TaskHint" -> String (skill 選別に使用), "TokenBudget" -> Integer|Automatic

### ClaudeProjectDirectives[bundle] → String
### ClaudeProjectDirectives[bundle, mode] → String
bundle を prompt 用文字列に投影。第2引数で明示モード指定。

### ClaudeDirectiveTokenEstimate[text] → Integer
文字列のトークン数概算。英日混在を考慮し StringLength/3 で近似。

### ClaudeSelectSkillsForTask[repo, taskHint, opts] → {skillAssoc...}
task hint に関連する skill をスコアリングして並べ替えて返す。
Options: "Role" -> Role 名, "MaxSkills" -> Integer (既定 5), "ModelStrengths" -> {String...} (skill フィルタに使用)

### ClaudeSelectRulesForRole[repo, role] → {ruleAssoc...}
role ごとの always-on rules を選別。Phase 35 stage1 以降、後方互換のため `Lookup[repo, "Rules", {}]` を返す。TaskHint ベースの絞り込みは ClaudeSelectRulesForTask を使う。

### ClaudeSelectRulesForTask[repo, taskHint, opts] → {ruleAssoc...}
task hint に関連する rules を選別して返す。$ClaudeAlwaysOnRules 列挙の rule は無条件で含む。それ以外は frontmatter の keywords/paths と TaskHint の交差度でスコア化し上位を採用。
Options: "Role" -> Role 名, "MaxRules" -> Integer (既定 8、always-on を超える分の上限), "MinScore" -> Integer (既定 1)

## 統合エントリ
### ClaudeBuildDirectivePromptForRole[role, modelName, taskHint] → String
1 行で directive 投影テキストを返す統合エントリ。ClaudeOrchestrator の worker BuildContext から呼ばれる想定。

### ClaudeBuildDirectivePromptForSingle[modelName, taskHint] → String
単一エージェント (claudecode の ClaudeEval / iAdapterBuildPrompt) 用の directive 投影テキストを返す。Role は None として扱う。

## Inventory / Manifest / Hash (Phase 1.0)
### ClaudeResolveDirectiveRoot[Automatic] → String | Failure
### ClaudeResolveDirectiveRoot[root_String] → String | Failure
Automatic は ClaudeFindDirectiveRoots で正準 root を解決、無ければ Failure["DirectiveRootNotFound"]。String は実在ディレクトリを検証。

### ClaudeDirectiveFileInventory[root, opts] → {record...} | Failure
root (ディレクトリ String または Automatic) のファイルインベントリをソート済リストで返す。各 record スキーマ: Role ("RootInstruction"|"Rule"|"Skill"|"Other"), RelativePath, LogicalPath, AbsolutePath, ContentHash ("sha256-<hex>"), ByteCount, LineCount, Name, Title, Description, FrontMatter, Paths, TokenEstimate, ModifiedTime。
Options: "IncludeOther" -> True (rule/skill 以外の top-level *.md を含めるか)

### ClaudeDirectiveRepositoryInventory[root] → {record...}
ClaudeDirectiveFileInventory[root] のエイリアス。

### ClaudeDirectiveRepositoryManifest[root] → Association
DirectiveRepositoryManifest を返す。キー: Kind, CanonicalFormat, Root, Files (インベントリ), FilesCount, RulesCount, SkillsCount, ManifestHash, CreatedAt, Generator。ManifestHash はソート済 {RelativePath, ContentHash} 対のみに依存し、ModifiedTime/TokenEstimate 変化に対して安定。

### ClaudeDirectiveRepositoryHash[root] → String
リポジトリの ManifestHash 文字列のみを返す。

## Rule 派生メタデータ・分類 (Phase 1.1a)
### ClaudeDirectiveRuleDerivedMetadata[ruleRecord, opts] → Association
rule インベントリ record (Role->"Rule") から Codex ハーネス用メタデータを導出。正準 rule frontmatter は description/summary/trigger を持たない前提で、Title (見出し) と paths frontmatter から決定的に導出する。
→ `<|"Title", "Summary", "Description", "Trigger", "DescriptionSource" ("derived-from-paths-and-heading"|"override"|"fallback"), "Paths"|>`
Options: "RuleMetadataOverrides" -> <||> (rule Name キーの per-rule オーバーライド Association)

### ClaudeDirectiveClassifyRule[ruleRecord, opts] → Association
rule record をハーネス具現化向けに分類。
→ `<|"Scope" ("always-on"|"task-specific"), "SizeClass" ("small"|"large"), "CommandPolicy", "InlineSummaryInAgentsMd" (候補値、最終判断は ClaudeDirectiveHarnessPlan で AGENTS.md バイト予算と再評価), "Reason"|>`
Options: "AlwaysOnRules" -> Automatic ($ClaudeAlwaysOnRules), "RuleLargeByteThreshold" -> Automatic ($CodexRuleLargeByteThreshold), "RuleMetadataOverrides" -> <||>

## ハーネスプラン・具現化 (Phase 1.1b)
### ClaudeDirectiveHarnessPlan[bundle, target, opts] → Association | Failure
ファイルを書かずにハーネスレイアウトの dry-run プランを返す。target は "Codex" または "ClaudeCLI"。"ClaudeCLI" は verbatim-copy プラン (AGENTS.md・directive index なし) で iClaudeCLIHarnessPlan に委譲。Codex プランのキー: Target, HarnessMaterializationMode, DirectiveRepositoryManifestHash, SourceVaultSnapshotId, AgentsMd (TargetRelativePath/EstimatedByteCount/InlineRuleNames/OmittedRuleNames/HardMaxBytes), Index (TargetRelativePath/Entries), GeneratedSkills, CommandPolicyRules, ProvenanceFiles, Warnings。
Options: "HarnessMaterializationMode" -> Automatic, "AgentsMdTargetMaxBytes" -> 20000, "AgentsMdHardMaxBytes" -> 30000, "RuleLargeByteThreshold" -> Automatic, "AlwaysOnRules" -> Automatic, "RuleMetadataOverrides" -> <||>, "SourceVaultSnapshotId" -> Missing["NotRegistered"]
例: ClaudeDirectiveHarnessPlan[<|"DirectiveRoot"->root|>, "Codex"]

### ClaudeDirectiveHarnessProvenanceHeader[meta] → String
生成 AGENTS.md 先頭の HTML コメント provenance ヘッダを返す。meta は DirectiveRepositoryManifestHash, SourceVaultSnapshotId, HarnessMaterializationMode を持ちうる Association。

### ClaudeDirectiveMaterializeCodexHarness[bundle, targetDir, opts] → Association
ClaudeDirectiveHarnessPlan を実行し Codex ハーネスを具現化。`.agents/skills` 下の rule/skill SKILL.md、`.agents/directive-index.json`、AGENTS.md、provenance ファイルを固定順で書く。正準リポジトリは変更しない。
→ 具現化レポート (WrittenFiles, AgentsMd, Index, GeneratedSkills, ProvenanceFiles, Warnings, Plan)。DryRun->True ではファイルを書かずプランを返す。
Options: ClaudeDirectiveHarnessPlan の全 Options に加え "GenerateDirectiveIndex", "GenerateProvenance", "CommandPolicyMaterialization", "DryRun" -> False, "FailOnAgentsMdOverflow"

### ClaudeDirectiveMaterializeClaudeHarness[bundle, targetDir, opts] → Association
正準リポジトリから Claude CLI ハーネス (Phase 4, Generated mode) を具現化。`.claude/CLAUDE.md`, `.claude/rules/<name>.md`, `.claude/skills/<name>/SKILL.md` を verbatim コピー (rule→skill 変換・AGENTS.md・directive index なし)、加えて `.claude/sourcevault-provenance.json` を書く。正準リポジトリは変更せず、`.claude/settings.json` は呼び出し側に委ねる (claudecode.wl が read permission を注入)。内部プラン計算 (iClaudeCLIHarnessPlan) は RootInstruction (CLAUDE.md→.claude/CLAUDE.md) と GeneratedSkills (Kind->"rule"|"skill" を含む rule/skill 一覧) を返し、AgentsMd/Index は Missing["NotApplicable"]。
→ 具現化レポート (WrittenFiles, RootInstruction, GeneratedFiles, ProvenanceFiles, Warnings, Plan)。DryRun->True ではプランを返す。
Options: "HarnessMaterializationMode" -> Automatic, "SourceVaultSnapshotId" -> Missing["NotRegistered"], "DirectiveRepositoryManifestHash" -> Automatic, "GenerateProvenance" -> True, "DryRun" -> False

## マイグレーションゲート (Phase 2.5)
### ClaudeDirectiveCompareCanonicalAndClaudeHarness[directiveRoot, claudeDir] → Association
正準 Claude Directives リポジトリと legacy .claude/ ハーネスを正規化論理パス (CLAUDE.md, rules/<name>.md, skills/<name>/SKILL.md) で比較。
→ `<|"CanonicalEquivMap", "LegacyEquivMap", "FilesOnlyInCanonical", "FilesOnlyInLegacy", "FilesChanged", "LegacyHarnessOnlyFiles" (settings.json 等、等価性から除外), "CanonicalDirExists", "LegacyDirExists"|>`

### ClaudeDirectiveMigrationReport[directiveRoot, claudeDir] → Association | Failure
マイグレーションゲート。legacy .claude/ ハーネスが正準リポジトリと等価かを報告。
→ `<|"CanonicalRoot", "LegacyClaudeDir", "CanonicalHash", "LegacyHarnessHash", "Status", "FilesOnlyInCanonical", "FilesOnlyInLegacy", "FilesChanged", "LegacyHarnessOnlyFiles", "RecommendedAction"|>`。Status は "Equivalent"|"Diverged"|"LegacyOnly"|"CanonicalOnly"。ハッシュは CLAUDE.md/rules/skills の正規化 {LogicalPath, ContentHash} 対のみで計算し、harness-only ファイルは Status に影響しない。Claude CLI を Generated mode へ切替えるには Status "Equivalent" または手動承認が必要。