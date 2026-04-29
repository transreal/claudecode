# claudecode_directives API Reference

パッケージ: `ClaudeDirectives``
GitHub: https://github.com/transreal/claudecode_directives
ロード: `Block[{$CharacterEncoding = "UTF-8"}, Get["ClaudeDirectives.wl"]]`
依存: なし (pure Wolfram Language)

## バージョン

### $ClaudeDirectivesVersion
型: String
パッケージバージョン文字列。

## モデル能力テーブル

### $ClaudeModelCapabilities
型: Association (モデル名 -> Association)
モデル名をキーとする能力テーブル。各値の構造:
`<|"ContextWindow" -> Integer, "Class" -> "Heavy-Cloud"|"Heavy-Local"|"Mid-Local"|"Light-Cloud"|"Light-Local", "DefaultMode" -> "Full"|"Summary"|"Index"|"Lazy", "Strengths" -> {String...}, "PreserveThinking" -> True|False, "Provider" -> String|>`
Phase 33 で qwen3.6-27b を含む登録済みモデルを保持する。

### $ClaudeRoleDefaultModels
型: Association (Role名 -> モデル名文字列)
ClaudeOrchestrator が worker spawn 時に参照するロール別デフォルトモデルのマッピング。

### $ClaudeSkillRolePolicy
型: Association (Role名 -> {優先スキル名...})
iScoreSkill がロール別優先スキルに +6 加点する際に参照する。Stage 1 v0.1.9 で追加。

### $ClaudeRoleDefaultMode
型: Association (Role名 -> "Full"|"Summary"|"Index"|"Lazy")
ClaudeResolveDirectiveBundle で mode === Automatic のとき優先採用するロール別デフォルトモード。Stage 1 v0.1.9 で追加。

### $ClaudeRoleMaxSkills
型: Association (Role名 -> Integer)
Options[ClaudeResolveDirectiveBundle] の MaxSkills が Automatic のとき採用するロール別スキル上限。Stage 1 v0.1.9 で追加。

### ClaudeRegisterModelCapability[name, spec] → Null
`$ClaudeModelCapabilities` にモデル能力 Association を追加または更新する。

### ClaudeResolveModelCapability[modelName] → Association
モデル名から能力 Association を返す。未登録の場合は保守的な既定値 `(ContextWindow 32000, DefaultMode "Summary")` を返す。

### ClaudeResolveModelMode[modelName] → String
モデル名から既定 ProjectionMode ("Full"|"Summary"|"Index"|"Lazy") を返す。

### ClaudeResolveModelContextWindow[modelName] → Integer
モデル名から ContextWindow (トークン数) を返す。

## ディレクティブリポジトリ

### $ClaudeDirectiveRepository
型: Association
読み込み済みリポジトリのキャッシュ。構造:
`<|"Root" -> path, "ClaudeMD" -> String, "Rules" -> {ruleAssoc...}, "Skills" -> {skillAssoc...}, "LoadedAt" -> AbsoluteTime|>`

### ClaudeFindDirectiveRoots[] → {String...}
`.claude` / `Claude Directives` ディレクトリの候補を探索し、実在するディレクトリのリストを返す。

### ClaudeLoadDirectiveRepository[] → Association
自動探索したディレクトリから読み込む。
ClaudeLoadDirectiveRepository[root] → Association
指定ディレクトリから読み込む。結果は `$ClaudeDirectiveRepository` にキャッシュされる。

### ClaudeInvalidateDirectiveCache[] → Null
`$ClaudeDirectiveRepository` を空にして再読込を強制する。

## バンドル解決・投影

### ClaudeResolveDirectiveBundle[opts]
task / role / model に応じた directive bundle を返す。
→ Association `<|"ClaudeMD"->String, "ActiveRules"->{...}, "ActiveSkills"->{...}, "ProjectionMode"->String, "TokenBudget"->Integer, "DirectiveMeta"->Association|>`
Options:
`"Role" -> None` ("Plan"|"Draft"|"Verify"|"Commit"|"Explore"|"Reduce"|None),
`"Model" -> Automatic` (能力テーブル参照キー),
`"Mode" -> Automatic` ("Full"|"Summary"|"Index"|"Lazy"|Automatic),
`"TaskHint" -> ""` (スキル選別に使用するプロンプト文字列),
`"TokenBudget" -> Automatic` (整数またはAutomatic),
`"MaxSkills" -> Automatic` (整数または Automatic → $ClaudeRoleMaxSkills 参照)
例: `ClaudeResolveDirectiveBundle["Role"->"Plan","Model"->"claude-opus-4-7","TaskHint"->"PDEを実装する"]`

### ClaudeProjectDirectives[bundle] → String
bundle を prompt 用文字列に投影する。ProjectionMode は bundle 内の値を使用。
ClaudeProjectDirectives[bundle, mode] → String
明示モード ("Full"|"Summary"|"Index"|"Lazy") で投影する。

### ClaudeDirectiveTokenEstimate[text] → Integer
文字列のトークン数概算を返す。英日混在を考慮し `StringLength/3` で近似する。

## スキル・ルール選別

### ClaudeSelectSkillsForTask[repo, taskHint, opts]
taskHint に関連するスキルをスコアリングして並べ替えて返す。
→ {skillAssoc...}
Options:
`"Role" -> None` (ロール名、$ClaudeSkillRolePolicy で +6 加点),
`"MaxSkills" -> 5` (返却スキル上限),
`"ModelStrengths" -> {}` (スキルフィルタに使用する能力リスト)

### ClaudeSelectRulesForRole[repo, role] → {ruleAssoc...}
ロール向け always-on rules を選別する。Phase 35 stage1 以降は後方互換のため `Lookup[repo, "Rules", {}]` を返す。TaskHint ベースの絞り込みには `ClaudeSelectRulesForTask` を使う。

### ClaudeSelectRulesForTask[repo, taskHint, opts]
taskHint に関連する rules を選別して返す (Phase 35 stage1 で追加)。
→ {ruleAssoc...}
Options:
`"Role" -> None` (ロール名),
`"MaxRules" -> 8` (always-on を超える分の上限),
`"MinScore" -> 1` (採用最低スコア)
`$ClaudeAlwaysOnRules` に列挙された rule は無条件で含める。それ以外は frontmatter の keywords / paths と taskHint の交差度でスコア化し上位を採用する。

### $ClaudeAlwaysOnRules
型: List (String...)
タスク内容に関係なく常時注入される rule 名のリスト。セキュリティ・基本マナー系の rule を登録する。`ClaudeSelectRulesForTask` が参照する。

## 統合エントリポイント

### ClaudeBuildDirectivePromptForRole[role, modelName, taskHint] → String
role / modelName / taskHint から directive 投影テキストを 1 呼び出しで返す統合エントリ。ClaudeOrchestrator の worker BuildContext から呼び出される想定。

### ClaudeBuildDirectivePromptForSingle[modelName, taskHint] → String
単一エージェント (claudecode の ClaudeEval / iAdapterBuildPrompt) 用の directive 投影テキストを返す。Role は None として扱う。

## ユーティリティ

### ClaudeDirectivesParseFrontmatter[text] → Association
SKILL.md 先頭の YAML frontmatter を解析する。
戻り値: `<|"Frontmatter" -> Association, "Body" -> String|>`