---
name: sourcevault-service-mcp-lifecycle
description: Use when the user reports the SourceVault MCP server (or any SourceVault detached service) is stuck "停止中"/Stopped and clicking the palette toggle does not bring it back, when SourceVaultMCPRunningQ stays False, or when diagnosing detached WL service kernel + Python proxy lifecycle (start/stop/restart/heartbeat/scheduled-task/per-machine runtime) issues in SourceVault_servicemanager.wl. Covers the stale status.json "Running" after a kernel crash trap, the PidAlive gate, runtime file inspection, and immediate recovery.
---

# SourceVault Service / MCP ライフサイクル診断スキル

SourceVault の detached service（WL カーネル）と HTTP/MCP proxy（Python）の
起動・停止・復帰まわりの障害を診断する手順。`SourceVault_servicemanager.wl` が対象。
パレットの「MCP 停止中」がクリックしても戻らない事故から抽出した（2026-06-24）。

## アーキテクチャ（前提）

MCP は **2 段構成**で、`SourceVaultStartMCP` がまとめて制御する:

```
パレット「MCP 停止中/実行中」ボタン
  → ClaudeCode`ClaudeRegisterPaletteServiceControl 経由のトグル
  → RunningQ が False なら Start = SourceVaultStartMCP[]
       ├ WL service kernel  (SourceVaultStartService)  ← heartbeat を打ち続ける本体
       └ Python HTTP proxy  (SourceVaultStartHTTPProxy) ← /sv/mcp /sv/health を公開
```

- **detachment 境界は Windows Task Scheduler**。`StartProcess` の子はメインカーネルの
  job object で道連れ kill されるため、`schtasks /Create` + `/Run` で切り離し、
  wscript hidden launcher 経由で窓を出さずに起動する（service / proxy 共通）。
- **runtime はマシン別に namespacing**: `<PrivateVault>/runtime/<MachineTag>/services/<id>/`
  と `.../proxies/<id>/`。`<MachineTag>` = `$MachineName`（英数字以外を `-` 化）。
  Dropbox 共有 vault を複数 PC で使っても競合しないための分離（locks のみ
  `runtime/locks` で共有）。**症状は各マシンで独立に再発する**（同じ shared code バグでも
  状態ファイルがマシン別なので、1 台直しても別の台で再発する）。詳細 `sourcevault-runtime-per-machine` メモ。
- `<PrivateVault>` は `SourceVault`$SourceVaultRoots["PrivateVault"]` で解決（Imai 環境では
  Dropbox 配下の `udb/sourcevault`）。ハードコードせず常にこの式で取得する。

## 症状カタログ

| 症状 | 疑う場所 |
|---|---|
| **パレットが「MCP 停止中」のまま、クリックしても戻らない（無限に停止中）** | service kernel が crash したが `status.json` が `State:"Running"` のまま残り、`SourceVaultStartMCP` が **State 文字列だけ**で AlreadyRunning と誤認して再起動をスキップ（後述の本丸） |
| `SourceVaultMCPRunningQ[]` が False だが proxy の pid は生きている | proxy だけ生存・背後の service kernel 死亡。`/health` の `healthState` が `Stale`（heartbeat 失効）→ RunningQ False。pid 生存 ≠ 健全 |
| 「実行中」表示なのに検索/MCP 応答が来ない | proxy listen はしているが service kernel が wedge。`SourceVaultServiceStatus` の `HeartbeatAgeSeconds` を確認 |
| Start すると毎回新 proxy が上がるが数十秒後また停止中 | service kernel が起動直後に死ぬ。`run.wls`/`manifest.resolved.wl`/root hash 不整合（`SourceVaultServiceRootHealth`）、または commands に stale "Stop" が残留 |
| クリックで端末窓が一瞬出る/15 秒おきに窓 | RunningQ が `RunProcess[tasklist]` を使っている版。現行は HTTP GET のみ（`mcp-palette-poll-terminal-window` メモ） |
| 別 PC から持ち込んだ vault で proxy が別マシンの port を握る | proxy.config.json はマシン別なので原則衝突しないが、`runtime/` 直下に旧レイアウトの `services`/`proxies`（per-machine 化前の残骸）が残っていることがある。現行コードは参照しない |

## 本丸: crash 後の stale `status.json` で復帰不能

**最頻出にして「クリックしても停止中のまま」の真因。**

カーネルが crash すると、自分で `status.json` を `Crashed` に書き直せないため
**`State:"Running"` のまま残る**（heartbeat.json だけが古い時刻で止まる）。

`SourceVaultStartMCP` の service 確保ロジックが、この `State` 文字列だけを信じていると:

```mathematica
(* ❌ 誤: State だけ見る → 死カーネルを AlreadyRunning と誤認 *)
svcRunning = ... Lookup[s, "State", ""] === "Running";
svc = Which[
  svcRunning, <|"Status" -> "AlreadyRunning"|>,   (* ← ここで止まり再起動しない *)
  True, SourceVaultStartService[sid]];            (* ← 来ない *)
```

結果: service は死んだまま、proxy だけ再起動 → `/health` は `Stale` →
`SourceVaultMCPRunningQ` False → パレット「停止中」。何度クリックしても同じ → **復帰不能**。

**正**: `State` に加えて **実 pid 生存 `PidAlive`** を AND 条件にする。

```mathematica
(* ✅ 正: PidAlive も要求 → 偽 Running を弾き SourceVaultStartService が走る *)
svcRunning = With[{s = Quiet @ Check[SourceVaultServiceStatus[sid], $Failed]},
  AssociationQ[s] && Lookup[s, "State", ""] === "Running" &&
    TrueQ[Lookup[s, "PidAlive", False]]];
```

`SourceVaultStartService` 自体は元から `State == "Running" && PidAlive` の両方を見て
二重起動を防いでいる（正しい）。**ラッパー側（StartMCP）だけが State だけ見ていた**のが穴。
新しい lifecycle ラッパーを足すときは必ず「pid 生存 / heartbeat 鮮度」で真の生存を判定し、
status.json の State 文字列を単独で信用しないこと。

## 診断手順

### 1. ランタイムの状態ファイルを直接読む（WL ロード不要・最速）

```bash
# <PrivateVault> = SourceVault`$SourceVaultRoots["PrivateVault"]  例: F:\Dropbox\udb\sourcevault
# <MachineTag>   = $MachineName を英数字以外 - 化したもの（Windows は大小無視）
M="<PrivateVault>/runtime/<MachineTag>"
cat "$M/services/sourcevault/status.json"      # State / PID
cat "$M/services/sourcevault/heartbeat.json"   # UpdatedAtUTC / Counter
cat "$M/services/sourcevault/pid.json"         # PID / Host / User / InjectedRootHash
cat "$M/proxies/sourcevault/proxy.config.json" # port / svcDir / mcpToken
tail -n 40 "$M/services/sourcevault/stdout.log"        # service kernel の起動失敗
tail -n 40 "$M/proxies/sourcevault/stdout.log"         # proxy の traceback
tail -n 20 "$M/services/sourcevault/service.log.jsonl"
```

**判定のキモ**:
- `status.json: State == "Running"` **かつ** `heartbeat.json: UpdatedAtUTC` が数十秒〜数日前
  → カーネル死亡なのに status が古いまま = 本丸の状態。
- `pid.json` の PID を生存確認: `tasklist /FI "PID eq <pid>" /NH`（不在 = 死亡）。
- proxy が port を握っているか: `netstat -ano | grep <port> | grep LISTENING`。
  **proxy pid が生きていても service kernel が死んでいれば「停止中」が正しい**（health は service を見る）。
- proxy stdout の `ConnectionResetError [WinError 10054]` は単にクライアント切断（MCP client の timeout）で
  致命ではない。致命は service kernel 側の停止。

### 2. WL がロード済みなら status API で見る

```mathematica
SourceVaultMCPStatus[]
(* "Running"        … 実到達性 + /health healthState=="OK"（真の状態）
   "ServiceState"   … status.json の State 文字列（crash 後も "Running" が残る）
   "ProxyPidAlive"  … proxy pid 生存（pid ベース）
   両者が食い違う（ProxyPidAlive True だが Running False）= service 死亡 or stale *)

SourceVaultServiceStatus["sourcevault"]
(* "State"(文字列) と "PidAlive"(実生存) と "HeartbeatAgeSeconds" を必ず突き合わせる。
   State=="Running" かつ PidAlive==False → 本丸。Health は "Failing" になっているはず *)

SourceVaultMCPRunningQ[]   (* パレットが見る真偽。/health の HTTP GET のみ（窓を出さない） *)
```

### 3. 復帰させる（即時）

SourceVault ロード済みカーネルで、いずれか:

```mathematica
(* A. 修正前のコードでも一発復帰: RestartService 分岐を強制的に通す *)
SourceVaultStartMCP["RestartService" -> True]
(* → SourceVaultRestartService が（死んでいても）stop+start し直す *)

(* B. service だけ作り直す *)
SourceVaultRestartService["sourcevault"]

(* C. 孤児 service を一括で Crashed 反映してから start *)
SourceVaultRecoverServices["Kill" -> True]
SourceVaultStartMCP[]
```

修正（PidAlive 条件）を入れて **再ロード後は、パレットのボタンを 1 回押すだけで復帰**する。

### 4. 恒久対策: watchdog 常駐

本丸の状態は「カーネルが死んでも誰も再起動しない」と長期化する（実例で 2 日放置）。

```mathematica
SourceVaultInstallWatchdog["sourcevault"]   (* heartbeat 失効(既定90s)/crash で自動再起動 *)
SourceVaultWatchdogStatus["sourcevault"]    (* 登録・常駐 PowerShell 生存・再起動履歴 *)
```

- watchdog は WL カーネルを spawn せず（ライセンス/電力配慮）、heartbeat 失効か crash を検知すると
  既存サービスタスクを再実行する。**意図停止（status.State=Stopped）は復活させない**。
- 多重常駐は named mutex で 1 本に抑止。常駐 PowerShell は while ループ自前 sleep で、
  周期 scheduled task ではない（窓フリッカ回避）。

## 切り分けフロー

```
「MCP が停止中のまま戻らない」
   ↓
status.json の State は？
   ├ "Running" → heartbeat.json の UpdatedAtUTC は新しい？
   │     ├ 古い(数十秒以上前) → 本丸。pid.json の PID を tasklist で死亡確認
   │     │      → SourceVaultStartMCP["RestartService"->True] で即復帰
   │     │      → 恒久対策: StartMCP の svcRunning に PidAlive 条件（修正済か確認）+ watchdog 常駐
   │     └ 新しい(<15s) → service は健全。proxy 側を疑う（port 衝突 / proxy.py traceback）
   ├ "Crashed"/"Stopped" → 普通に SourceVaultStartMCP[]（または watchdog が意図停止は復活しない点に注意）
   └ "Unknown"/ファイル無し → 初回。SourceVaultStartMCP[] で素直に起動
   ↓
それでも上がらない → service stdout.log と SourceVaultServiceRootHealth（root hash / user 不整合）を確認
```

## 参照

- 実装: `SourceVault_servicemanager.wl`
  - `SourceVaultStartMCP` / `SourceVaultStopMCP` / `SourceVaultMCPRunningQ` / `SourceVaultMCPStatus`
  - `SourceVaultStartService`（`State && PidAlive` の二重起動防止が正しい基準）/ `SourceVaultRestartService`
  - `SourceVaultServiceStatus`（`State` vs `PidAlive` vs `HeartbeatAgeSeconds`）/ `SourceVaultServiceHealth`
  - `SourceVaultStartHTTPProxy`（proxy.config.json 生成・旧 pid kill・schtasks）/ `iResolvePython`
  - `SourceVaultRecoverServices` / `SourceVaultServiceDoctor` / `SourceVaultServiceRootHealth`
  - `SourceVaultInstallWatchdog` / `SourceVaultWatchdogStatus` / `SourceVaultUninstallWatchdog`
  - runtime 解決: `iRuntimeMachineTag` / `iRuntimeMachineRoot` / `iServiceRuntimeDir` / `iProxyRuntimeDir`
- パレット側トグル: `claudecode.wl` の `iPaletteServiceToggleAction` / `iPaletteServiceRunningQ`
  （RunningQ が False のときクリックで Start を呼ぶ。4 秒 TTL キャッシュ）
- 関連メモ: `sourcevault-runtime-per-machine`（マシン別 runtime）、
  `mcp-palette-poll-terminal-window`（RunningQ の窓フリッカ対策）、
  `claudeprocesslist-manual-refresh`（UpdateInterval 定期更新が FE フリーズ元の教訓）
