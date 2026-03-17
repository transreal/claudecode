---
name: doc-generation
description: Use when generating or updating package documentation with ClaudeCreateDocumentation or ClaudeUpdateDocumentation. Covers resumption after limits, README structure, document queue ordering, and option usage.
---

# ドキュメント生成ルール

## api.md の役割（最重要）

**api.md はパッケージの「唯一の真実のソース」である。** LLM がこのファイルだけを読んで、パッケージの全公開関数を正しく使えるコードを書けなければならない。

### api.md のフォーマット原則（LLM 最適化）

api.md はヒトが読むドキュメントではなく、**LLM がコード生成に使う参照ファイル**である。
以下の原則でトークン消費を最小化しつつ情報密度を最大化する:

1. **空行を最小限にする**: セクション見出し前の1行のみ。関数エントリ間に空行を入れない
2. **セパレータ `---` を使わない**: `###` 見出しだけで区別する
3. **Bold/装飾を最小限にする**: `**引数:**` などの冗長なラベルは不要
4. **自明な使用例を省略する**: `NBCellCount[nb]` のような単純な関数に例は不要。オプションやパターンが複雑な関数にのみ例を付ける
5. **1関数 = 最小行数**: シグネチャ + 説明 + オプション（あれば）+ 戻り値を密に記述

### api.md の具体的フォーマット

#### 定数/変数
```
### $VarName
型: Association, 初期値: <|"key" -> value|>
説明文（1行）
```

#### 単純な関数（オプションなし）
```
### FuncName[arg1, arg2] → ReturnType
説明文（1行）
```

#### オプション付き関数
```
### FuncName[arg1, arg2, opts]
説明文（1行）
→ ReturnType（構造の説明が必要なら追記）
Options: Opt1 -> Default1 (説明), Opt2 -> Default2 (説明)
```

#### 複雑な関数（例が必要）
```
### FuncName[arg1, arg2, opts]
説明文
→ <|"Key1" -> ..., "Key2" -> ...|>
Options: Opt1 -> Default1 (説明), Opt2 -> Default2 (説明)
例: FuncName["pkg", "msg", Branch -> "dev", Force -> True]
```

#### 複数パターン
```
### FuncName[a] / FuncName[a, b] / FuncName[a, b, c]
パターン別の説明
```

### api.md に必須の内容:
- すべての公開関数: シグネチャ、全オプション（デフォルト値+説明）、戻り値の型
- すべての公開定数/変数: 型、初期値、説明
- 複雑な関数のみ: 使用例（1-2行）
- 関数はカテゴリ別にグループ化（`## カテゴリ名`）

### api.md の参照優先ルール:
- コード生成時: **api.md → ソースコード** の順で参照（api.md で解決できればソースは不要）
- 関数の説明を求められたとき: **api.md → user_manual.md → ソースコード** の順
- api.md に記載されていない関数やオプションを推測で生成してはならない

## ドキュメントキューの順序

`$iDocQueue` は以下の順序で処理される（README.md は最後）:

1. setup.md — インストール手順書
2. user_manual.md — ユーザーマニュアル
3. api.md — API リファレンス
4. examples/example.md — 使用例集
5. **README.md** （最後: 他ドキュメントを参照して概要を合成）

## オプション一覧

`ClaudeCreateDocumentation` / `ClaudeUpdateDocumentation` の共通オプション:

| オプション | デフォルト | 説明 |
|---|---|---|
| `Fallback` | `False` | Fallback モデル使用 |
| `References` | `{}` | 参考文献の URL / 書名リスト → README の「参考文献」セクションに追加 |
| `Demos` | `{}` | デモ動画・使用例の URL リスト → README の「使用例・デモ」セクションに追加 |
| `Disclaimer` | `{}` | 免責事項に追記する文言リスト |
| `License` | `""` | ライセンステキスト。空ならMIT自動生成。文字列指定でカスタムライセンス |

第二引数の指示文中に URL が含まれていれば、自動的に `Demos` に追加される。

## 文体ルール（必須）

| ドキュメント | 文体 | 理由 |
|---|---|---|
| **api.md** | **常体**（だ・である調） | 簡潔さを優先するリファレンス文書 |
| setup.md | 敬体（です・ます調） | ユーザー向け説明 |
| user_manual.md | 敬体（です・ます調） | ユーザー向け説明 |
| examples/example.md | 敬体（です・ます調） | ユーザー向け説明 |
| **README.md** | **敬体**（です・ます調） | ユーザー向け概要・紹介 |

## API エラー・利用制限の保護（必須）

- すべてのファイル書き込み前に `iIsAPIErrorResponse` でレスポンスをチェックする。
- エラー/制限メッセージの場合、**ファイルを一切更新せず**エラーを報告して停止する。
- これはドキュメント生成 (`iGenDocNext`, `iUpdateDocNext`, `iAutoUpdateApiMd`) だけでなく、パッケージ更新 (`ClaudeUpdatePackage`, `ClaudeCreatePackage`) にも適用される。
- **fail-fast 原則**: 連続 API 呼び出し（一括ドキュメント生成、バックアップ要約生成等）では、最初のエラーで以降の呼び出しをすべてスキップする。limit 到達後は当面回復しないため。
- 詳細な判定パターンとコード例は `rules/90-api-error-handling.md` を参照。

## ライセンスの自動挿入

- `License -> ""` (デフォルト) かつ `GitHubREST`$GitHubLicenseHolder` が非空文字列の場合:
  MIT ライセンスが README.md の最後（免責事項の後）に自動挿入される。
  年は現在年 (更新時は作成年-現在年) が自動計算される。
- `License -> "カスタムテキスト"`: 指定テキストがそのままライセンスセクションに挿入される。
- `$GitHubLicenseHolder` が空文字列の場合: ライセンスは挿入されず、警告が Print される。

## setup.md / README.md のインストール記述（必須）

### `$Path` のルール
- すべての `.wl` パッケージは `$packageDirectory` 直下に配置される（サブフォルダではない）
- `$Path` に追加するのは `$packageDirectory` 自体
- **正しい**: `AppendTo[$Path, $packageDirectory]`
- **誤り**: `AppendTo[$Path, "C:\\path\\to\\PackageName"]` — パッケージ固有のパスを指定してはならない
- claudecode を使用している場合は自動設定される

### パッケージロードパターン
```mathematica
Block[{$CharacterEncoding = "UTF-8"},
  Needs["PackageName`", "PackageName.wl"]];
```
ファイル名のみの形式 `"PackageName.wl"` は `$packageDirectory` が `$Path` に含まれている前提。

## README.md の構造

README.md は `SPECIAL_README_WITH_OVERVIEW` マーカーにより特別処理される:

### 前半: 設計思想と実装の概要
- 他ドキュメント + `_info/design/` フォルダのメモを読み込む
- 優先順位: docs > コード > design メモ
- パッケージの Why（なぜこう設計されているか）と How（高レベルの仕組み）を説明

### 後半: 詳細説明
- 動作環境
- インストール手順（UTF-8 ロードパターン必須、クイックスタート例必須）
- 主な機能の一覧と簡潔な説明
- ドキュメント一覧へのリンク
- 使用例・デモ (Demos 指定時)
- 参考文献 (References 指定時)
- 免責事項（必須）
- ライセンス（$GitHubLicenseHolder が設定済みの場合）

## リミット到達時の動作

- コールバック内で `iIsDocLimitError` を使い、レスポンスがリミットメッセージかを判定する。
- リミット検出時:
  1. 当該ファイルは保存せず、以降のファイル生成も停止する。
  2. ノートブックに未生成ファイル一覧を赤太字で表示する。

## 継続（リザンプション）の動作

呼び出し時に `iCheckDocResumption` で以下を判定:

- **ソースが documentupdate より新しい** → 全ファイル再生成
- **ソースが documentupdate 以前で、一部ファイルのみ存在** → 未生成分のみ生成
- **全ファイル存在** → 全ファイル再生成
