# Claude Code ディレクトリアクセス制御: hooks 方式 vs プロンプト埋め込み方式の比較分析

## 背景

Claude Code の `--add-dir` フラグはディレクトリ単位でアクセスを追加するが、Read（ファイル内容読み取り）と Glob（ファイル一覧取得）を個別に制御する機能はない。NotebookDirectory のファイル一覧は提供しつつ、ファイル内容の Read は明示的な許可があるまで禁止したいという要件に対し、2つのアプローチを比較する。

---

## hooks 方式の概要

Claude Code の `PreToolUse` hooks を利用し、`Read` ツールの呼び出しをディレクトリ単位でブロックする。

### 実装イメージ

```json
// .claude/settings.json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [{
          "type": "command",
          "command": "powershell -NoProfile -Command \"$input = [Console]::In.ReadToEnd(); $path = ($input | ConvertFrom-Json).tool_input.file_path; $allowed = @('F:\\Dropbox\\...\\MyPackages'); $ok = $false; foreach($d in $allowed){ if($path.StartsWith($d)){ $ok=$true; break } }; if(-not $ok){ Write-Error 'Read blocked'; exit 2 } else { exit 0 }\""
        }]
      }
    ]
  }
}
```

### hooks で分離制御が可能な根拠

- `PreToolUse` の `matcher` は `Read` と `Glob` を別ツール名としてマッチできる
- exit code 2 でツール実行をブロックし、stderr のメッセージが Claude にフィードバックされる
- `--add-dir` でディレクトリを追加した上で、hook で Read のみ選択的にブロック可能

### hooks 方式の問題点

| 問題 | 内容 |
|---|---|
| **Windows 環境** | hooks は bash スクリプト前提の例が多い。Windows では PowerShell で書く必要があり、JSON エスケープが煩雑 |
| **`--print` モード** | claudecode.wl は `--print --output-format stream-json` で実行。hooks のブロック（exit 2）が stream-json フォーマットでどう表現されるか不明瞭 |
| **動的 settings.json** | `iPrepareClaudeProjectDirectory` が毎回一時ディレクトリに settings.json をコピー生成するため、hooks も毎回動的に書き換える必要がある |
| **許可リストの同期** | `$ClaudeAccessibleDirs` の変更をリアルタイムで hook に反映するには、許可リストをファイルに書き出し、hook が毎回そのファイルを読む仕組みが必要 |
| **フォールスルーリスク** | `--add-dir` で追加した時点で Read も技術的には可能。hook が正しく動作しなければセキュリティホールになる |
| **デバッグ困難** | hooks の失敗は stderr 経由で返る。`--print` モードでのデバッグが難しい |

---

## プロンプト埋め込み方式の概要（現在の実装）

NotebookDirectory のファイル一覧を Mathematica の `FileNames[]` で取得し、プロンプトに直接埋め込む。`--add-dir` には Read 許可済みディレクトリのみを含める。

### 実装構造

```
iFileAccessContext[userPrompt] :=
  ■ 常に含める部分:
    $packageDirectory のパッケージ一覧
    NotebookDirectory のパスと Read 状態表示

  ■ 条件付き部分（iNeedsFileList[userPrompt] = True の場合のみ）:
    Files in NotebookDirectory (62):
      - fallback検証.nb (709 KB, 2026/03/08)
      - claudecode バグ、修正点.nb (152 KB, ...)
      ...

  ■ 省略時:
    "(62 files — use "ファイル一覧" or similar keyword to see the list)"
```

### キーワード判定

```mathematica
iNeedsFileList[prompt_String] :=
  AnyTrue[
    {"ファイル", "一覧", "リスト", "file", "list",
     "デスクトップ", "Desktop", "フォルダ", "directory", ...},
    StringContainsQ[prompt, #, IgnoreCase -> True] &
  ] || StringContainsQ[prompt, RegularExpression["\\w+\\.(?:pdf|nb|csv|...)"]];
```

### Read 制御の仕組み

- `--add-dir` に NotebookDirectory を含めない → Claude Code は物理的に Read 不可
- `$ClaudeAccessibleDirs` に追加されたディレクトリのみ `--add-dir` に含まれる
- Read 不可の場合、プロンプトに RESTRICTION メッセージを付与:

```
RESTRICTION: NotebookDirectory file listing is for reference only.
Do NOT use the Read tool to read file contents from NotebookDirectory.
If the user asks you to read or process a file, tell them to run:
AppendTo[$ClaudeAccessibleDirs, "C:\Users\...\Desktop\"]
```

---

## 比較表

| 観点 | プロンプト埋め込み方式（現在） | hooks 方式 |
|---|---|---|
| **ファイル一覧の提供** | Mathematica の `FileNames[]` でプロンプトに埋め込み。**確実** | `--add-dir` + Glob ツール。Claude が Glob を使うかは **LLM 判断に依存** |
| **Read 制御** | `--add-dir` に含めなければ**物理的に不可能**。フェイルセーフ | `--add-dir` に含めた上で hook でブロック。**hook の正常動作に依存** |
| **セキュリティモデル** | 「許可しないディレクトリは存在しない」原理 | 「許可するがブロックする」原理。hook 故障時にフォールスルー |
| **実装複雑度** | Mathematica のみ。外部スクリプト不要 | PowerShell スクリプト + JSON 動的生成 + 許可リストファイル管理 |
| **トークン効率** | `iNeedsFileList` で必要時のみ一覧を含める。効率的 | Glob を毎回実行するとトークン消費。Claude が不要と判断すれば省略 |
| **応答速度** | ファイル一覧生成は Mathematica 側で高速（数ms）。追加プロセス起動なし | 毎回の Read/Glob で hook プロセスが起動。Windows の PowerShell 起動は遅い（数百ms/回） |
| **プラットフォーム** | Mathematica が動く全環境で動作 | Windows/macOS/Linux で hook スクリプトが異なる |
| **許可の動的変更** | `AppendTo[$ClaudeAccessibleDirs, dir]` で即座に反映 | 許可リストファイルの書き出し + 次回 hook 呼び出しで反映 |
| **デバッグ** | `ClaudeQueryShowContext[]` / `ClaudeShowAccessConfig[]` で確認可能 | hook の stderr 出力を stream-json から抽出する必要あり |

---

## 結論

**プロンプト埋め込み方式のほうが優れている。**

### 主な理由

1. **フェイルセーフ設計**: `--add-dir` に含めなければ物理的に Read 不可能。hooks 方式は「通すがブロックする」設計のため、hook 故障時にセキュリティホールになる

2. **ファイル一覧の確実性**: Mathematica の `FileNames[]` は常に正確な結果を返す。Glob は Claude が使うかどうかが LLM 判断に依存し、結果が不安定

3. **Windows 親和性**: PowerShell スクリプトの動的生成・JSON エスケープ・デバッグは claudecode.wl の既存アーキテクチャ（バッチファイル生成 + stream-json パース）と相性が悪い

4. **トークン効率**: `iNeedsFileList` のキーワード判定で必要時のみ埋め込む方式は、Glob を毎回使う hooks 方式より効率的

5. **アーキテクチャの一貫性**: claudecode.wl は既に「Mathematica 側でコンテキストを構築してプロンプトに注入する」パターンで設計されている。hooks は異なるパラダイムの導入になり、保守コストが増大する

### hooks が有利なケース

hooks 方式が有利になるのは「Claude Code が自律的にサブディレクトリを再帰探索する」「数千ファイルのディレクトリで動的にファイルを発見する」ような高度なファイル探索が必要な場合。claudecode.wl の用途（ノートブック内での質疑応答・コード生成）では、プロンプト埋め込みで十分対応できる。

### 補足: permission rules だけでの分離は不十分

Claude Code の `settings.json` の `permissions.deny` で `Read(...)` を拒否すると、file discovery と search results からも除外されるため、Glob 的な探索にも影響する。「Read を禁止しつつ Glob だけは自由にさせる」ことは permission rules 単体では実現困難であり、これも hooks 方式の採用を困難にする要因の一つ。
