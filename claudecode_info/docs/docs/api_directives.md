# claudecode_directives API Reference

パッケージ: `ClaudeDirectives``
依存: なし (pure Wolfram Language)
ロード: `Block[{$CharacterEncoding = "UTF-8"}, Get["ClaudeDirectives.wl"]]`
GitHub: https://github.com/transreal/claudecode_directives

## 変数

### $ClaudeDirectivesVersion
型: String
パッケージバージョン文字列。

### $ClaudeModelCapabilities
型: Association, キー: {provider, model} tuple
モデル能力テーブル。値は `<|"ContextWindow" -> Integer, "Class" -> "Heavy-Cloud"|"Heavy-Local"|"Mid-Local"|"Light-Cloud"|"Light-Local", "DefaultMode" -> "Full"|"Summary"|"Index"|"Lazy", "Strengths" -> {String...}, "PreserveThinking" -> True|False, "Paid" -> True|False|>`。
provider 名: `"claudecode"` (CLI・無課金), `"anthropic"` (API・課金), `"openai"` (API・課金), `"lmstudio"` (ローカル・無課金)。キーは Phase 28 で String から {provider, model} tuple に変更。`"Paid"` フィールドも Phase 28 で追加。Anthropic CLI Opus (`"claudecode"` provider, Paid=False) と Anthropic API Opus (`"anthropic"` provider, Paid=True) を別モデルとして両方登録。lm-studio は provider 名 `"lmstudio"` に正規化。

### $ClaudeRoleDefaultModels
型: Association, キー: Role 名
Role -> {provider, model} tuple のマッピング。ClaudeOrchestrator が worker spawn 時に参照する想定。値も Phase 28 で {provider, model} tuple に変更。

### $ClaudeSkillRolePolicy
型: Association, キー: Role 名
Role -> {優先 skill 名一覧} のマッピング。iScoreSkill が role 別優先 skill に +6 加点する。Stage 1 v0.1.9 で追加。

### $ClaudeRoleDefaultMode
型: Association, キー: Role 名
Role -> デフォルト Mode ("Full"|"Summary"|"Index"|"Lazy")。ClaudeResolveDirectiveBundle で mode === Automatic のとき優先採用。Stage 1 v0.1.9 で追加。

### $ClaudeRoleMaxSkills
型: Association, キー: Role 名
Role -> デフォルト skill 上限 (Integer)。Options[ClaudeResolveDirectiveBundle] の MaxSkills が Automatic のとき採用。Stage 1 v0.1.9 で追加。

### $ClaudeDirectiveRepository
型: Association
読み込み済みリポジトリのキャッシュ。`<|"Root" -> path, "ClaudeMD" -> str, "Rules" -> {ruleAssoc...}, "Skills" -> {skillAssoc...}, "LoadedAt" -> AbsoluteTime|>`

### $ClaudeAlwaysOnRules
型: List
タスク内容に関係なく常時注入される rule 名の List。セキュリティ・基本マナー系の rule を登録する。ClaudeSelectRulesForTask が参照する。

### $CodexRuleLargeByteThreshold
型: Integer, 初期値: 8192
ClaudeDirectiveClassifyRule が rule を "large" と分類するバイト数境界。既に値が設定済みの場合は上書きしない。

## モデル能力

### ClaudeRegisterModelCapability[name, spec] → Null
$ClaudeModelCapabilities にモデル能力を追加・更新する。name は {provider, model} tuple または String (後方互換)。tuple キー主・String キー互換の両方を accept する。

### ClaudeResolveModelCapability[modelName] → Association
モデル名から能力 Association を返す。未登録の場合は保守的な既定値 (ContextWindow 32000, DefaultMode "Summary") を返す。

### ClaudeResolveModelMode[modelName] → String
モデル名から既定 ProjectionMode を返す。

### ClaudeResolveModelContextWindow[modelName] → Integer
モデル名から ContextWindow (token 数) を返す。

## ディレクティブリポジトリ

### ClaudeFindDirectiveRoots[] → {String...}
.claude / Claude Directives ディレクトリの候補を探索し、実在するディレクトリのリストを返す。

### ClaudeLoadDirectiveRepository[] → Association
### ClaudeLoadDirectiveRepository[root] → Association
自動探索または指定ディレクトリからリポジトリを読み込む。結果は $ClaudeDirectiveRepository にキャッシュされる。

### ClaudeInvalidateDirectiveCache[] → Null
$ClaudeDirectiveRepository を空にして再読込を強制する。

### ClaudeResolveDirectiveRoot[Automatic] → String | Failure
ClaudeFindDirectiveRoots[] で正規 root を解決する。存在しない場合は Failure["DirectiveRootNotFound"] を返す。

### ClaudeResolveDirectiveRoot[root] → String | Failure
明示的な root ディレクトリ文字列を検証して返す。非ディレクトリは Failure["DirectiveRootNotFound"]、非文字列は Failure["DirectiveRootInvalid"]。

## インベントリ・マニフェスト

### ClaudeDirectiveFileInventory[root, opts] → {Association...} | Failure
Claude Directives リポジトリの Phase 1.0 インベントリをファイルレコードのソート済みリストとして返す。root はディレクトリ文字列または Automatic。各レコードのキー: Role, RelativePath, LogicalPath, AbsolutePath, ContentHash, ByteCount, LineCount, Name, Title, Description, FrontMatter, Paths, TokenEstimate, ModifiedTime。Role は "RootInstruction" | "Rule" | "Skill" | "Other"。ContentHash は "sha256-<lowerhex>" 形式。
Options: "IncludeOther" -> True (非 rule/skill トップレベル *.md ファイルを含めるか)

### ClaudeDirectiveRepositoryInventory[root] → {Association...} | Failure
ClaudeDirectiveFileInventory[root] のエイリアス。

### ClaudeDirectiveRepositoryManifest[root] → Association | Failure
DirectiveRepositoryManifest Association を返す。キー: Kind, CanonicalFormat, Root, Files, FilesCount, RulesCount, SkillsCount, ManifestHash, CreatedAt, Generator。ManifestHash は {RelativePath, ContentHash} ペアのみに依存し ModifiedTime・TokenEstimate の変化では変わらない。

### ClaudeDirectiveRepositoryHash[root] → String | Failure
リポジトリの ManifestHash 文字列のみを返す。

## rule 派生メタデータ・分類

### ClaudeDirectiveRuleDerivedMetadata[ruleRecord, opts] → Association
rule インベントリレコードから Codex ハーネス用メタデータを導出する。正規 rule frontmatter は description/summary/trigger を持たない前提で、rule の見出し (Title) と paths frontmatter から決定論的に導出する。返り値キー: Title, Summary, Description, Trigger, DescriptionSource ("derived-from-paths-and-heading" | "override" | "fallback"), Paths。引数不一致時は $Failed。
Options: "RuleMetadataOverrides" -> `<||>` (rule 名 (Name) をキーとする上書き Association)

### ClaudeDirectiveClassifyRule[ruleRecord, opts] → Association
rule インベントリレコードをハーネスマテリアライゼーション用に分類する。返り値キー: Scope ("always-on" | "task-specific"), SizeClass ("small" | "large"), CommandPolicy, InlineSummaryInAgentsMd (候補値。最終的な inline 判定は ClaudeDirectiveHarnessPlan で AGENTS.md バイト予算に対し再評価), Reason。
Options: "AlwaysOnRules" -> Automatic (Automatic 時は $ClaudeAlwaysOnRules を採用), "RuleLargeByteThreshold" -> Automatic (Automatic 時は $CodexRuleLargeByteThreshold を採用), "RuleMetadataOverrides" -> `<||>`

## バンドル・投影

### ClaudeResolveDirectiveBundle[opts] → Association
task / role / model に応じた directive bundle を返す。
→ `<|"ClaudeMD"->..., "ActiveRules"->..., "ActiveSkills"->..., "ProjectionMode"->..., "TokenBudget"->..., "DirectiveMeta"->...|>`
Options: "Role" -> None ("Plan"|"Draft"|"Verify"|"Commit"|"Explore"|"Reduce"|None), "Model" -> モデル名 (capability テーブル参照キー), "Mode" -> Automatic ("Full"|"Summary"|"Index"|"Lazy"|Automatic; Automatic 時は $ClaudeRoleDefaultMode を採用), "TaskHint" -> String, "TokenBudget" -> Automatic (Integer | Automatic), "MaxSkills" -> Automatic (Integer | Automatic; Automatic 時は $ClaudeRoleMaxSkills を採用)

### ClaudeProjectDirectives[bundle] → String
### ClaudeProjectDirectives[bundle, mode] → String
bundle を prompt 用文字列に投影する。mode を明示する場合は "Full"|"Summary"|"Index"|"Lazy" を指定。

### ClaudeDirectiveTokenEstimate[text] → Integer
文字列のトークン数概算を返す。英日混在を考慮し StringLength/3 で近似する。

### ClaudeSelectSkillsForTask[repo, taskHint, opts] → {Association...}
task hint に関連する skill をスコアリングして並べ替えて返す。
Options: "Role" -> Role 名, "MaxSkills" -> 5, "ModelStrengths" -> {} (skill フィルタに使用)

### ClaudeSelectRulesForRole[repo, role] → {Association...}
role ごとの always-on rules を選別する。Phase 35 stage1 以降、後方互換のため Lookup[repo, "Rules", {}] を返す。TaskHint ベースの絞り込みには ClaudeSelectRulesForTask を使う。

### ClaudeSelectRulesForTask[repo, taskHint, opts] → {Association...}
task hint に関連する rules を選別して返す (Phase 35 stage1 追加)。$ClaudeAlwaysOnRules に列挙された rule は無条件で含める。それ以外は frontmatter の keywords/paths と TaskHint の交差度でスコア化して上位を採用する。
Options: "Role" -> Role 名, "MaxRules" -> 8 (always-on を超える分の上限), "MinScore" -> 1

## 統合エントリ

### ClaudeBuildDirectivePromptForRole[role, modelName, taskHint] → String
1 行で directive 投影テキストを返す統合エントリ。ClaudeOrchestrator の worker BuildContext から呼び出される想定。

### ClaudeBuildDirectivePromptForSingle[modelName, taskHint] → String
単一エージェント (claudecode の ClaudeEval / iAdapterBuildPrompt) 用の directive 投影テキストを返す。Role は None として扱う。

## ユーティリティ

### ClaudeDirectivesParseFrontmatter[text] → Association
SKILL.md 先頭の YAML frontmatter を解析する。返り値: `<|"Frontmatter" -> Association, "Body" -> String|>`

## ハーネス計画・マテリアライゼーション

### ClaudeDirectiveHarnessPlan[bundle, target, opts] → Association | Failure
ファイルを書かずにハーネスの dry-run 計画を返す。target は "Codex" または "ClaudeCLI"。"ClaudeCLI" 計画は verbatim コピー計画 (AGENTS.md・directive index なし) で iClaudeCLIHarnessPlan に委譲される。target がそれ以外は Failure["UnsupportedHarnessTarget"]。
返り値キー (Codex): Target, HarnessMaterializationMode, DirectiveRepositoryManifestHash, SourceVaultSnapshotId, AgentsMd (TargetRelativePath / EstimatedByteCount / InlineRuleNames / OmittedRuleNames / HardMaxBytes), Index (TargetRelativePath / Entries), GeneratedSkills, CommandPolicyRules, ProvenanceFiles, Warnings。
返り値キー (ClaudeCLI): Target, HarnessMaterializationMode, DirectiveRepositoryManifestHash, SourceVaultSnapshotId, DirectiveRoot, RootInstruction, AgentsMd (Missing["NotApplicable"]), Index (Missing["NotApplicable"]), GeneratedSkills (rule/skill 両方を Kind ("rule"|"skill") 付きで保持), CommandPolicyRules ({}), ProvenanceFiles ({".claude/sourcevault-provenance.json"}), Warnings。
Options: "HarnessMaterializationMode" -> Automatic, "AgentsMdTargetMaxBytes" -> 20000, "AgentsMdHardMaxBytes" -> 30000, "RuleLargeByteThreshold" -> Automatic, "AlwaysOnRules" -> Automatic, "RuleMetadataOverrides" -> `<||>`, "SourceVaultSnapshotId" -> Missing["NotRegistered"]

### ClaudeDirectiveHarnessProvenanceHeader[meta] → String
生成された AGENTS.md の先頭に配置する HTML コメント形式のプロベナンスヘッダを返す。meta キー: DirectiveRepositoryManifestHash (または ManifestHash), SourceVaultSnapshotId, HarnessMaterializationMode。

### ClaudeDirectiveMaterializeCodexHarness[bundle, targetDir, opts] → Association | Failure
ClaudeDirectiveHarnessPlan を実行して Codex ハーネスを targetDir 以下にマテリアライズする。書き込み順: .agents/skills 以下の rule/skill SKILL.md → .agents/directive-index.json → AGENTS.md → プロベナンスファイル。正規 Claude Directives リポジトリは変更しない。DryRun -> True ならファイルを書かず計画を返す。
返り値キー: WrittenFiles, AgentsMd, Index, GeneratedSkills, ProvenanceFiles, Warnings, Plan。
Options: ClaudeDirectiveHarnessPlan と同じオプション + "GenerateDirectiveIndex" -> True, "GenerateProvenance" -> True, "CommandPolicyMaterialization" -> Automatic, "DryRun" -> False, "FailOnAgentsMdOverflow" -> False

### ClaudeDirectiveMaterializeClaudeHarness[bundle, targetDir, opts] → Association | Failure
正規 Claude Directives リポジトリから Claude CLI ハーネスを targetDir/.claude/ 以下に verbatim コピーでマテリアライズする (Phase 4, $ClaudeCLIHarnessMode -> "Generated")。書き込み対象: .claude/CLAUDE.md, .claude/rules/<name>.md, .claude/skills/<name>/SKILL.md, .claude/sourcevault-provenance.json。rule の skill 変換・AGENTS.md・directive index は生成しない。.claude/settings.json はこの関数では書かない (claudecode.wl が read 権限を注入)。DryRun -> True ならファイルを書かず計画を返す。
返り値キー: WrittenFiles, RootInstruction, GeneratedFiles, ProvenanceFiles, Warnings, Plan。
Options: "HarnessMaterializationMode" -> Automatic, "SourceVaultSnapshotId" -> Missing["NotRegistered"], "DirectiveRepositoryManifestHash" -> Automatic, "GenerateProvenance" -> True, "DryRun" -> False

## マイグレーションゲート

### ClaudeDirectiveCompareCanonicalAndClaudeHarness[directiveRoot, claudeDir] → Association | Failure
正規 Claude Directives リポジトリとレガシー .claude/ ハーネスを正規化論理パス (CLAUDE.md, rules/<name>.md, skills/<name>/SKILL.md) で比較する。両側とも ClaudeDirectiveFileInventory["IncludeOther" -> True] を使う。
返り値キー: CanonicalEquivMap, LegacyEquivMap, FilesOnlyInCanonical, FilesOnlyInLegacy, FilesChanged, LegacyHarnessOnlyFiles (settings.json 等。同等性判定から除外), CanonicalDirExists, LegacyDirExists。引数不一致時は $Failed。

### ClaudeDirectiveMigrationReport[directiveRoot, claudeDir] → Association | Failure
マイグレーションゲート: レガシー .claude/ ハーネスが正規リポジトリと同等かを報告する。
返り値キー: CanonicalRoot, LegacyClaudeDir, CanonicalHash, LegacyHarnessHash, Status, FilesOnlyInCanonical, FilesOnlyInLegacy, FilesChanged, LegacyHarnessOnlyFiles, RecommendedAction。
Status: "Equivalent" | "Diverged" | "LegacyOnly" | "CanonicalOnly"。RecommendedAction: "CanSwitchClaudeToGenerated" (Equivalent 時) | "ManualReview"。ハッシュは CLAUDE.md / rules / skills の正規化 {LogicalPath, ContentHash} ペアのみで計算され、ハーネス専用ファイル (settings.json 等) は Status に影響しない。Claude CLI を Generated モードに切り替えるには Status "Equivalent" またはマニュアル承認が必要。