---
paths:
  - "**/{NBAccess,claudecode,ClaudeCode}*.{wl,wls,m,nb}"
  - "**/*.{wl,wls,m}"
---

# 11 — 基盤パッケージの依存方向制約

## 基盤パッケージの定義

以下の2パッケージを **基盤パッケージ** と呼ぶ:

- `claudecode.wl` (ClaudeCode`)
- `NBAccess.wl` (NBAccess`)

## 必須ルール: 依存方向は一方向のみ

```
任意のパッケージ ──Needs/使用──→ claudecode.wl / NBAccess.wl
                                    ↑ 一方向のみ許可
```

1. **基盤パッケージは他のパッケージに依存してはならない。**
   - `claudecode.wl` と `NBAccess.wl` は、互いを除き、`Needs`/`Get`/`Import` で他のパッケージを読み込んではならない。
   - 他のパッケージの関数をシンボル参照（`Maildb`xxx` 等）してもならない。
   - 他のパッケージの存在を前提としたコード（`If[Length[Names["Maildb`*"]] > 0, ...]` 等）も禁止。

2. **他のパッケージが基盤パッケージに依存するのは正しい。**
   - `maildb.wl` が `ClaudeCode`ClaudeQuery` を呼ぶ → ✅ 正しい方向
   - `maildb.wl` が `NBAccess`NBGetProviderMaxAccessLevel` を呼ぶ → ✅ 正しい方向
   - `claudecode.wl` が `Maildb`mailAskLLM` を呼ぶ → ❌ **禁止**
   - `NBAccess.wl` が `Maildb`$maildbCache` を参照する → ❌ **禁止**

3. **基盤パッケージのシステムプロンプトに特定パッケージの情報を埋め込んではならない。**
   - `$claudeMathPromptPrefix` に「mailAskLLM を使え」等のパッケージ固有指示を書く → ❌ **禁止**
   - パッケージ固有の LLM 指示は、そのパッケージ自身の `api.md` または `CLAUDE.md` に記載し、`iPackageDocsContext` の自動注入機構を利用する。

## ClaudeUpdatePackage / ClaudeCreatePackage 実行時の動作

パッケージの更新・作成を行う際、以下の判断フローを守る:

1. **更新対象が基盤パッケージでない場合（通常ケース）:**
   - 基盤パッケージの API を自由に使用してコードを生成する。
   - 基盤パッケージ側の変更は不要。

2. **生成中に基盤パッケージの API 変更が必要と判断した場合:**
   - **コード生成を即座に中断する。**
   - 以下を出力して判断を仰ぐ:
     ```
     ⚠ 基盤パッケージ API 変更が必要です。

     対象: claudecode.wl（または NBAccess.wl）
     必要な変更: [具体的な変更内容]
     理由: [なぜ現在の API では不足か]

     基盤パッケージの変更は手動で行う必要があります。
     先に基盤パッケージを更新してから、このタスクを再実行してください。
     ```
   - 基盤パッケージの変更を含むコードを**絶対に**自動生成してはならない。

3. **更新対象が基盤パッケージ自体の場合:**
   - `ClaudeUpdatePackage["claudecode", ...]` や `ClaudeUpdatePackage["NBAccess", ...]` は許可される。
   - ただし、更新内容に他パッケージへの依存追加が含まれる場合は拒否する。

## 理由

基盤パッケージは GitHub で公開されており、あらゆるユーザー環境で動作する必要がある。
特定のパッケージ（maildb 等）の存在を前提とすると、そのパッケージがない環境で基盤パッケージが正常に動作しなくなる。
