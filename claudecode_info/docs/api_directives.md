# claudecode_directives API リファレンス

Directive Repository / Projection Layer。`.claude/CLAUDE.md`、`.claude/rules/`、`.claude/skills/` の読み込みと、task / role / model に応じた directive bundle の解決・投影を行う。

## 変数

### $ClaudeDirectivesVersion
型: String
パッケージバージョン文字列。

### $ClaudeModelCapabilities
型: Association ({provider, model} -> Association)
モデル能力テーブル。キーは `{provider, model}` tuple。値は以下のフィールドを持つ Association:
- `"ContextWindow"` -> Integer
- `"Class"` -> `"Heavy-Cloud"`|`"Heavy-Local"`|`"Mid-Local"`|`"Light-Cloud"`|`"Light-Local"`
- `"DefaultMode"` -> `"Full"`|`"Summary"`|`"Index"`|`"Lazy"`
- `"Strengths"` -> {`"Code"`,`"Reasoning"`,`"Search"`,`"ToolUse"`,...}
- `"PreserveThinking"` -> True|False
- `"Paid"` -> True|False (課金 API か否か、Phase 28 で追加)

provider 名: `"claudecode"` (CLI、課金なし), `"anthropic"` (API、課金), `"openai"` (API、課金), `"lmstudio"` (ローカル、課金なし)。Anthropic CLI Opus と Anthropic API Opus は別モデルとして両方登録される。

### $ClaudeRoleDefaultModels
型: Association (Role -> {provider, model} tuple)
Role ごとの既定モデルマッピング。ClaudeOrchestrator が worker spawn 時に参照する。

### $ClaudeSkillRolePolicy
型: Association (Role -> {String...})
Role ごとの優先 skill 名リスト。`iScoreSkill` が role 別の優先 skill に +6 加点する。Stage 1 v0.1.9 で追加。

### $ClaudeRoleDefaultMode
型: Association (Role -> String)
Role ごとの default Mode (`"Full"`|`"Summary"`|`"Index"`|`"Lazy"`)。`ClaudeResolveDirectiveBundle` で `Mode` が `Automatic` のとき優先採用。Stage 1 v0.1.9 で追加。

### $ClaudeRoleMaxSkills
型: Association (Role -> Integer)
Role ごとの default skill 上限。`Options[ClaudeResolveDirectiveBundle]` の `MaxSkills` が `Automatic` のとき採用。Stage 1 v0.1.9 で追加。

### $ClaudeDirectiveRepository
型: Association
読み込み済みリポジトリのキャッシュ。
`<|"Root" -> path, "ClaudeMD" -> str, "Rules" -> {ruleAssoc...}, "Skills" -> {skillAssoc...}, "LoadedAt" -> AbsoluteTime|>`

### $ClaudeAlwaysOnRules
型: List (String)
タスク内容に関係なく常時注入される rule 名のリスト。セキュリティ・基本マナー系の rule を登録する。`ClaudeSelectRulesForTask` が参照する。

## モデル能力テーブル

### ClaudeRegisterModelCapability[name, spec] → Association
`$ClaudeModelCapabilities` にモデル能力を追加・更新する。`name` は `{provider, model}` tuple または String (互換) を受け付ける。

### ClaudeResolveModelCapability[modelName] → Association
モデル名から能力 Association を返す。未登録の場合は保守的な既定値 (ContextWindow 32000, DefaultMode `"Summary"`) を返す。

### ClaudeResolveModelMode[modelName] → String
モデル名から既定 ProjectionMode (`"Full"`|`"Summary"`|`"Index"`|`"Lazy"`) を返す。

### ClaudeResolveModelContextWindow[modelName] → Integer
モデル名から ContextWindow (token 数) を返す。

## Directive Repository

### ClaudeFindDirectiveRoots[] → {String...}
`.claude` / Claude Directives ディレクトリの候補を探索し、実在するディレクトリのリストを返す。

### ClaudeLoadDirectiveRepository[] → Association
### ClaudeLoadDirectiveRepository[root] → Association
自動探索したディレクトリ、または指定ディレクトリから `CLAUDE.md` / `rules/` / `skills/` を読み込む。結果は `$ClaudeDirectiveRepository` にキャッシュされる。

### ClaudeInvalidateDirectiveCache[] → Null
`$ClaudeDirectiveRepository` を空にして再読込を強制する。

## Bundle / Projection

### ClaudeResolveDirectiveBundle[opts]
task / role / model に応じた directive bundle を返す。
→ Association (`<|"ClaudeMD"->...,"ActiveRules"->...,"ActiveSkills"->...,"ProjectionMode"->...,"TokenBudget"->...,"DirectiveMeta"->...|>`)
Options:
- `"Role"` -> None (`"Plan"`|`"Draft"`|`"Verify"`|`"Commit"`|`"Explore"`|`"Reduce"`|None)
- `"Model"` -> Automatic (モデル名、capability テーブル参照キー)
- `"Mode"` -> Automatic (`"Full"`|`"Summary"`|`"Index"`|`"Lazy"`|Automatic、Automatic は role / model から決定)
- `"TaskHint"` -> "" (プロンプト文字列、skill 選別に使用)
- `"TokenBudget"` -> Automatic (Integer | Automatic)
- `"MaxSkills"` -> Automatic (Integer | Automatic、Automatic は `$ClaudeRoleMaxSkills` 参照)

### ClaudeProjectDirectives[bundle] → String
### ClaudeProjectDirectives[bundle, mode] → String
bundle を prompt 用文字列に投影する。`mode` 指定で明示モード投影。

### ClaudeDirectiveTokenEstimate[text] → Integer
文字列のトークン数概算を返す。英日混在を考慮し `StringLength/3` で近似。

### ClaudeSelectSkillsForTask[repo, taskHint, opts] → {skillAssoc...}
task hint に関連する skill をスコアリングして並べ替えて返す。
Options:
- `"Role"` -> None (Role 名、`$ClaudeSkillRolePolicy` に基づき優先 skill に加点)
- `"MaxSkills"` -> 5 (Integer)
- `"ModelStrengths"` -> {} ({String...}、skill フィルタに使用)

### ClaudeSelectRulesForRole[repo, role] → {ruleAssoc...}
role ごとの always-on rules を選別する。Phase 35 stage1 以降は後方互換のため `Lookup[repo, "Rules", {}]` を返す。TaskHint ベースの絞り込みには `ClaudeSelectRulesForTask` を使う。

### ClaudeSelectRulesForTask[repo, taskHint, opts] → {ruleAssoc...}
task hint に関連する rules を選別して返す (Phase 35 stage1 で追加)。`$ClaudeAlwaysOnRules` に列挙された rule は無条件で含める。それ以外は frontmatter の keywords / paths と TaskHint の交差度でスコア化し、上位を採用する。
Options:
- `"Role"` -> None (Role 名)
- `"MaxRules"` -> 8 (Integer、always-on を超える分の上限)
- `"MinScore"` -> 1 (Integer)

## 統合エントリ

### ClaudeBuildDirectivePromptForRole[role, modelName, taskHint] → String
1 行で directive 投影テキストを返す統合エントリ。ClaudeOrchestrator の worker BuildContext から呼び出される想定。

例:
```
ClaudeBuildDirectivePromptForRole["Draft", {"anthropic", "claude-opus-4-7"}, "Wolfram package update"]
```

### ClaudeBuildDirectivePromptForSingle[modelName, taskHint] → String
単一エージェント (claudecode の `ClaudeEval` / `iAdapterBuildPrompt`) 用の directive 投影テキストを返す。Role は `None` として扱う。

## 内部用 (テスト時のみ公開)

### ClaudeDirectivesParseFrontmatter[text] → Association
SKILL.md 先頭の YAML frontmatter を解析する。
→ `<|"Frontmatter" -> Association, "Body" -> String|>`