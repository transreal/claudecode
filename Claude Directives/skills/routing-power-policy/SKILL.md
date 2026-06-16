---
name: routing-power-policy
description: |
  実行環境の電源状態（AC / バッテリー）に応じて、プロンプト・ルーティングが使う
  light モデル階層を Local / Cloud / Off に自動・手動で切り替える機能の実装メモ。
  ノートPC のバッテリー運用時にローカル LLM 起動を避け、クラウド light（Haiku 相当）
  に回す、または停止する運用。Windows での AC/バッテリー検出方法、package-neutral
  hook（claudecode 所有・SourceVault 弱参照）、パレットのトグル UI、契約層
  `SourceVaultResolveModelForPromptRouter` への配線、rule 02/11 準拠、既知の
  モデル分類ギャップ（spec §12.1.1）を含む。
---

# Routing power policy（電源連動 light ルーティング）

ノートPC がバッテリー運用のときローカル LLM を起動したくない（GPU 負荷・発熱・
電力）等、**実行環境に応じて light ルーティングのモデル階層を切替**える機能。
設計判断（ユーザー確定）：**Auto＝AC→Local / バッテリー→Cloud、クラウドは
capability table 経由で Light×Cloud を解決、Off＝light 振り分けのみ停止（context
planner は維持）**。

## 状態と API（claudecode 所有・公開）

| シンボル | 役割 |
|---|---|
| `ClaudeCode`$ClaudeRoutingModelPolicy` | `Automatic`(既定) / `"Local"` / `"Cloud"` / `"Off"` |
| `ClaudeCode`ClaudeRoutingModelClass[]` | 実効 class（Automatic を電源で解決した `"Local"`/`"Cloud"`/`"Off"`） |
| `ClaudeCode`ClaudeRoutingPolicyStatus[]` | `<|"Policy", "Power", "Effective"|>` |
| `ClaudeCode`ClaudeSetRoutingPolicy[p]` | p を設定＋**永続化**（machine-local）。`$ClaudeRoutingModelPolicy` への直接代入はセッション限り |
| `ShowClaudePalette[]` の「ルート」トグル | `Automatic→Local→Cloud→Off` 循環＋色分け（保存あり）|

`Automatic` の電源連動：**AC / Unknown → Local、バッテリー → Cloud**。

**永続化**：`PersistentValue["ClaudeCode/RoutingModelPolicy", "Local"]` に machine-local 保存。
新カーネルの init が `!ValueQ` のとき復元（セッション内リロードは現在値を尊重するので
clobber しない）。保存するのは `iCycleRoutingPolicy`（パレット）と `ClaudeSetRoutingPolicy`。

## 電源検出（Windows）

`ClaudeCode`Private`iDetectACPower[]`（~30秒キャッシュ）→ `iDetectACPowerRaw[]` が
`RunProcess` で PowerShell を1行実行。**3方式すべて実機（ASUS ProArt PX13）で検証済**：

- `root\wmi BatteryStatus` の **`PowerOnline`**（True=AC / False=Battery）← 採用。AC連動の最も意味的に正しい指標。
- `Win32_Battery` の `BatteryStatus`（1=放電/バッテリー、2=AC、6-9=充電中=AC）。
- `System.Windows.Forms.SystemInformation.PowerStatus.PowerLineStatus`（Online/Offline/Unknown。デスクトップでも Online）。`Add-Type` が要る分やや重い。

```mathematica
(* 採用コマンド（root\wmi PowerOnline、バッテリー無しデスクトップは AC）*)
$w=@(Get-CimInstance -Namespace root\wmi -ClassName BatteryStatus -ErrorAction SilentlyContinue);
if($w.Count -eq 0){'AC'}elseif($w[0].PowerOnline){'AC'}else{'Battery'}
```

非Windows（`$OperatingSystem =!= "Windows"`）やデスクトップは `"AC"` 既定（ローカル許可）。
パレットの Dynamic 描画では **検出を走らせず cache 値のみ**読む（`iRoutingEffectiveFromCache`）。
RunProcess を Dynamic 内で同期実行すると UI を塞ぐため、検出はトグルクリック時
（`iCycleRoutingPolicy`）と eval 時（30秒 cache）に限定する。

## package-neutral 配線（rule 11）

claudecode が **状態・検出・パレット**を所有し、SourceVault は実効 class を**弱参照**
するだけ。依存方向は SourceVault → claudecode。

```mathematica
(* SourceVault 側（SourceVaultResolveModelForPromptRouter 内）*)
routingClass = Which[
  Lookup[nq, "WeightClass", Automatic] =!= "Light", None,        (* light routing のみ *)
  Names["ClaudeCode`ClaudeRoutingModelClass"] === {}, None,       (* 旧 claudecode *)
  True, Quiet @ Check[Symbol["ClaudeCode`ClaudeRoutingModelClass"][], None]];
```

- `"Off"` → `<|"Status"->"RoutingDisabled", "Reason"->"RoutingPolicyOff"|>`（呼び元は `$ClaudeModel` 経路へ）。
- `"Cloud"` → query の `AllowedTrustDomains` を `{"Cloud"}` に上書き（**rule 02**：Haiku を直書きせず Light×Cloud クラスで downstream 解決）。
- `"Local"` / `None` → 無変更（後方互換）。
- **PrivacyLevel≥0.5 は Cloud policy より優先**：cloud に確定すると既存の privacy floor が `NeedsPrivateModel` を返す。秘密プロンプトは電源に関係なくローカル限定が守られる。

## rule 02 準拠（モデル名を直書きしない）

「Haiku（claude-haiku-4-5）」を `.wl` の分岐に書かない。**Light×Cloud クラス**として
`AllowedTrustDomains -> {"Cloud"}` ＋ WeightClass で表現し、具体モデルは capability /
compiled registry のテーブル登録に閉じる。

## モデル分類ギャップ＝解消済み (2026-06-15、end-to-end 達成)

当初、契約層 query 形（`ModelIntent`/`WeightClass`）とレジストリ matcher 形
（`Provider`/`Intent`/`Class`、`iRegistryEntryMatchesQuery` は **query の全キーが
entry に存在＋一致**を要求）が未整合で、Light query は `NeedsModelClassification` だった。
以下で解消：

- **(1a)** Haiku（`claude-haiku-4-5`）を **Light×Cloud** として `iModelSeedEntries[]` に
  seed 登録（rule 02：テーブル登録、枝番をロジックに書かない）。seed は
  `iBootstrapDefaultSeeds[]` が {Provider,Intent,ModelId} 三つ組集合の変化で自動再生成。
- **(1b)** `SourceVaultResolveModelForPromptRouter` が `WeightClass`＋trust 選好を
  **`Class` ベースの query**（`<|"Class"->"Light-Local"|>` 等）に翻訳して委譲。
  `privLevel≥0.5` は常に Local（privacy 優先）。`Automatic` weight は翻訳せず従来の
  `NeedsModelClassification`（推測しない・order6b test 互換）。
- **(1c)** `iResolveRawTrustDomain` を **entry の `Class` から trust domain 導出**に拡張
  （`*-Local`→Local / `*-Cloud`→Cloud。precedence: `TrustDomain` 明示 > `Class` >
  Provider 分類）。これで lmstudio の確定ローカル（generic には未分類）も privacy floor が
  正しく許可し、秘密プロンプトでローカル light を使える。

検証（result11/12.nb）: Local→`qwen3-swallow-8b-rl-v0.2`（実登録）、Cloud→`claude-haiku-4-5`、
privLevel 0.75+Cloud→ローカル qwen（privacy 優先で Resolved）、Off→RoutingDisabled、
Automatic weight→NeedsModelClassification。

`SourceVaultResolve` の matcher は exact-match-all-keys なので、契約 query をそのまま
渡すと必ず 0 件になる点に注意（registry が理解する `Class`/`Provider`/`Intent` に翻訳する）。

## 検証

```mathematica
ClaudeCode`Private`iDetectACPowerRaw[]                 (* "AC" / "Battery" *)
ClaudeCode`ClaudeRoutingPolicyStatus[]                 (* <|Policy,Power,Effective|> *)
ClaudeCode`$ClaudeRoutingModelPolicy = "Off";
SourceVaultResolveModelForPromptRouter[<|"ModelIntent"->"router","WeightClass"->"Light"|>]
(* Status "RoutingDisabled" *)
ClaudeCode`$ClaudeRoutingModelPolicy = "Cloud";
SourceVaultResolveModelForPromptRouter[<|"ModelIntent"->"router","WeightClass"->"Light","PrivacyLevel"->0|>]
(* Requested.AllowedTrustDomains -> {"Cloud"} *)
ClaudeCode`$ClaudeRoutingModelPolicy = Automatic;     (* AC -> Local *)
```

## .wl 編集上の注意

- 新規シンボルは `$ClaudeEvalContextPlanner` と同様 **完全修飾 `ClaudeCode`$...` 宣言**で公開（export 文字列リストを触らずに済む・低リスク）。
- パレット Dynamic 内の公開変数参照は完全修飾（Private 文脈での shadow 回避）。`TrackedSymbols :> {ClaudeCode`$ClaudeRoutingModelPolicy, $iACPowerCache}`。
- 日本語は `\:XXXX`、`\u` 不可。`RunProcess` の `root\\wmi` は WL 文字列で `\\`。
