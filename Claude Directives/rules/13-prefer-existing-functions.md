---
description: データ・ファイルの読み込みに Get/Import 等を使わず、まず既存の定義済み関数(パッケージ API)を探して使う
---

# 13 — 読み込みは Get でなく既存の定義関数を優先する

## 対象

ClaudeEval / ClaudeQuery が「データを読み込む」「ファイルをロードする」
「○○を一覧 / 検索 / 表示する」等のためにコードを生成するとき。

## 必須ルール

### 1. Get / Import / `<<` 等でデータやファイルを直接ロードしない

`Get`, `Import`, `Export`, `Put`, `<<`, `ReadString`, `OpenRead`, `BinaryRead`,
`Run`, `RunProcess`, `SystemOpen` 等のファイル / 外部 I/O 関数は
**安全検証で拒否される (ForbiddenHead → Deny)**。Deny は承認ボタンも出ない。
これらでデータファイルやパッケージを直接読み書きするコードを生成してはならない。

```mathematica
(* ❌ 禁止: シャード / データファイルを直接 Get / Import で読む *)
Get["/.../mail/snapshots/univ/202601.svmail"]
data = Import["202601.svmail"]

(* ✅ 正しい: そのデータを扱う既存のパッケージ関数を使う *)
SourceVaultMailEnsureLoaded["univ", "202601"];
SourceVaultMailView["", MBox -> "univ", DateFrom -> DateObject[{2026, 1, 10}]]
```

### 2. まず「既存の定義関数」を探してから書く

目的の操作に対し、低レベルなファイル I/O を書く前に、それを安全に行う
**既存の定義済み関数 (パッケージ API)** が無いか必ず探す。

1. プロンプト中のパッケージ名 / ドメイン (メール・ノートブック・GitHub 等) から、
   対応パッケージの `_info/docs/api.md` を参照する。
2. `Names["*キーワード*"]` で関連関数を検索する
   (例: `Names["SourceVaultMail*"]`, `Names["*Mail*"]`, `Names["*Load*"]`)。
3. 見つかった公開関数を使う。`Get` / `Import` で代替しない。

### 3. ドメイン別の正準 API (例)

| やりたいこと | ❌ 使わない | ✅ 使う (既存関数) |
|---|---|---|
| メールのロード / 検索 / 表示 | `Get` / `Import` で `.svmail` を読む | `SourceVaultMailEnsureLoaded` → `SourceVaultMailView` / `SourceVaultSearchMailSnapshots` |
| ノートブックのセル読み書き | 生 `NotebookRead` / `Get` | NBAccess の公開関数 (`NBGetCells`, `NBWriteCode` 等) |
| パッケージの更新 | `Import` + 書換 + `Export` / `Put` | `ClaudeUpdatePackage` |

### 4. 該当 API が見つからないとき

`Names[...]` でも api.md でも該当する既存関数が見つからない場合は、
`Get` / `Import` を使うコードを生成して拒否されるのではなく、
**「適切な API が見つからない」旨をテキストで報告**し、ユーザーに確認を求める。

## 背景

LLM が曖昧な指示 (例:「○○のメールを」) に対し、`Get` でシャードファイルを
直接読もうとして ForbiddenHead で拒否される事例があった。`Get` / `Import` 等は
任意ファイル読込・外部実行で危険なため拒否対象であり、承認しても実行されない。
データは必ず安全な既存 API 経由で扱う。
