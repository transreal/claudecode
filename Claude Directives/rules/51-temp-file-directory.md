---
paths:
  - "**/*.{wl,wls,m,nb}"
---

# テンポラリファイルのディレクトリ制約

## 基本原則

テンポラリファイル（一時ファイル）を生成する際は、**`$TemporaryDirectory` を使わず、`$ClaudeWorkingDirectory` を使う**。

`$TemporaryDirectory` は廃止済みとして扱う。Claude Code CLI のプロンプトファイル、出力ファイル、バッチファイルなど、すべての一時ファイルは `$ClaudeWorkingDirectory` 配下に置くこと。

## 理由

- `$TemporaryDirectory` は OS のシステムテンポラリであり、Claude Code CLI の `--add-dir` によるアクセス権制御の対象外になる場合がある。
- `$ClaudeWorkingDirectory`（デフォルト: `FileNameJoin[{$HomeDirectory, "Claude Working"}]`）は Claude Code 用に設計された作業ディレクトリであり、CLI からのアクセスが保証されている。
- テンポラリファイルを `$ClaudeWorkingDirectory` に集約することで、クリーンアップと管理が容易になる。

## 正しいパターン

```mathematica
(* ✅ 正しい: $ClaudeWorkingDirectory を使用 *)
outFile = FileNameJoin[{$ClaudeWorkingDirectory, "claude_rt_" <> ts <> ".txt"}];
promptFile = FileNameJoin[{$ClaudeWorkingDirectory, "claude_rtp_" <> ts <> ".txt"}];
batFile = FileNameJoin[{$ClaudeWorkingDirectory, "claude_run_" <> ts <> ".bat"}];
```

## 禁止パターン

```mathematica
(* ❌ 禁止: $TemporaryDirectory は使わない *)
outFile = FileNameJoin[{$TemporaryDirectory, "claude_rt_" <> ts <> ".txt"}];

(* ❌ 禁止: 未定義の独自関数を使わない *)
outFile = FileNameJoin[{iClaudeTempDir[], "claude_rt_" <> ts <> ".txt"}];
```

## 既存コードの移行

既存の `$TemporaryDirectory` 使用箇所は段階的に `$ClaudeWorkingDirectory` に移行する。新規コードでは必ず `$ClaudeWorkingDirectory` を使用すること。
