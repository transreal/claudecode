# 90 — API エラー・利用制限ハンドリング

## 対象

ClaudeCode パッケージ内で Anthropic API を呼び出すすべての処理。
ClaudeEval, ClaudeUpdatePackage, ClaudeCreateDocumentation, ClaudeUpdateDocumentation,
ClaudeBackupDataset の要約生成、iAutoUpdateApiMd 等。
GitHubREST パッケージ内で LLM を呼び出す処理（リポジトリ名翻訳等）も含む。

## 絶対順守要件: Fallback の明示的指定

**`Fallback -> True` を明示的に指定しない限り、Fallback は一切行わない。**

- Claude Code がレート制限等で利用不可の場合、`Fallback -> True` が明示されていなければ **エラーを返して処理を停止する**。
- エラーメッセージを黙って飲み込んで処理を継続してはならない。
- エラーメッセージをデータとして利用してはならない（リポジトリ名、ファイル名、ドキュメント内容等に変換しない）。
- `$currentUseFallback` は `ClaudeEval[..., Fallback -> True]` 等で明示的に True にされた場合にのみ True になる。この変数を直接操作して Fallback を有効化してはならない。

### Fallback 実装パターン

```mathematica
(* ✅ 正しいパターン: Fallback=False ならエラーで停止 *)
useFallback = TrueQ[ClaudeCode`Private`$currentUseFallback];
result = If[useFallback,
  iQueryWithFallback[prompt, True, None],  (* Fallback=True: 代替モデルを試行 *)
  iClaudeQueryRaw[prompt]];                 (* Fallback=False: メインのみ *)
If[!StringQ[result] || iIsLimitError[result],
  If[!useFallback,
    Return[Failure["LLMQueryFailed", <|"Message" -> "API利用不可"|>]];  (* 停止 *)
    (* Fallback=True でも全モデル失敗時の最終手段 *)
    ...]]
```

```mathematica
(* ❌ 禁止パターン: Fallback 指定なしで黙って代替処理 *)
result = iClaudeQueryRaw[prompt];
If[iIsLimitError[result],
  result = Transliterate[packageName]];  (* エラーを飲み込んで処理継続 *)
```

### `iQueryWithFallback` の使用

- `iQueryWithFallback[prompt, useFallback, nb]` は `$currentUseFallback` が True の場合にのみ使用する。
- この関数は `iClaudeQueryRaw` を呼び、エラーなら `$ClaudeFallbackModels` のモデルを順次試行する。
- `useFallback` 引数に `False` を渡すと Fallback なしで動作する（`iClaudeQueryRaw` と同等）。

### エラーレスポンスの検出と伝播

LLM 応答をデータとして利用する処理（リポジトリ名生成、ドキュメント生成等）では:

1. 応答に `"hit your limit"`, `"rate limit"`, `"Error:"`, `"resets"` 等のエラー文字列が含まれていないか検証する
2. エラーが検出された場合、`Fallback -> True` でなければ `Failure[...]` を返す
3. 呼び出し元は `FailureQ` で判定し、`Failure` を上位に伝播させる
4. **伝播チェーンの全レイヤーに `FailureQ` ガードを入れる** — 例: `iTranslateToEnglishRepoName` → `iAutoRepoName` → `iResolveRepository` → `GitHubCreateRepository` の全段

## 必須ルール

1. **`iIsAPIErrorResponse` で判定する**: API レスポンスの有効性を判定するときは、必ず既存の `iIsAPIErrorResponse[response]` を使用する。自前で limit 文字列を検出するコードを書かない。

2. **`iIsAPIErrorResponse` が検出するパターン**:
   - `"Error"` で始まるレスポンス
   - `"hit your limit"`, `"rate limit"`, `"overloaded"`, `"unavailable"` を含む
   - CenterDot (`·` / `\[CenterDot]`) を含むリミットメッセージ
   - 短い応答（100文字未満）で `"resets"`, `"limit"`, `"error"`, `"failed"` を含む
   - 非文字列（`$Failed`, `Null` 等）

3. **エラー時はファイルを書き込まない**: `iIsAPIErrorResponse` が `True` を返した場合、レスポンスをファイルに保存してはならない（ドキュメント、ソースコード、summary.txt 等すべて）。既存の `iSafeWriteDoc` がこの原則を実装している。

4. **早期打ち切り（fail-fast）**: 連続して API を呼ぶ処理（ドキュメント一括生成、バックアップ要約一括生成等）では、最初のエラーで以降の API 呼び出しをすべてスキップする。limit に達した場合、当面は回復しないため。

5. **フォールバック表示**: API エラーで生成できなかったデータは、ユーザーに既存の簡易表示（`iTruncatePrompt` 等）で代替する。エラーメッセージ自体を表示データとして使わない。

## 新機能追加時の適用パターン

API レスポンスを受け取ってファイルに書き込む処理を新たに実装する場合:

```mathematica
(* ✅ 正しいパターン *)
result = iClaudeQueryRaw[prompt];
If[iIsAPIErrorResponse[result],
  (* エラー処理: ファイル書き込みしない、フォールバック *)
  Print["API エラー: " <> StringTake[ToString[result], UpTo[100]]];
  Return[$Failed]];
(* 正常時のみファイル書き込み *)
Export[destFile, result, "Text"];
```

```mathematica
(* ❌ 禁止パターン *)
result = iClaudeQueryRaw[prompt];
Export[destFile, result, "Text"];  (* エラーレスポンスもそのまま保存してしまう *)
```

## 一括処理での適用パターン

```mathematica
(* ✅ 正しいパターン: 最初の失敗で打ち切り *)
hitLimit = False;
Do[
  If[hitLimit, Continue[]];
  result = iGenerateSomething[item];
  If[result === "" || FailureQ[result],
    hitLimit = True,
    count++],
  {item, items}]
```

## エラーレスポンスのノートブック表示（必須）

エラー・制限メッセージをノートブックに表示する場合は、**必ず `NBAccess`NBWritePrintNotice` を使用する**。通常の Text セルや Input セルとして出力してはならない。

```mathematica
(* ✅ 正しいパターン: 通知スタイルで小さめフォント表示 *)
NBAccess`NBWritePrintNotice[nb, "Error: 利用制限に達しています", RGBColor[0.8, 0, 0]];

(* ❌ 禁止: エラーを通常 Text セルとして表示 *)
NBAccess`NBWriteCell[nb, Cell["Error: 利用制限に達しています", "Text"]];
```

非同期コールバック（`ClaudeEval`/`ClaudeQuery`/`ContinueEval`）では、コールバック冒頭でエラーを早期検出し、通知スタイルで表示後にジョブを終了する:

```mathematica
If[iIsAPIErrorResponse[response] || StringStartsQ[response, "Error"],
  NBAccess`NBWritePrintNotice[nb, response, RGBColor[0.8, 0, 0]];
  NBAccess`NBEndJob[jid];
  Return[]];
```

## 空レスポンスの扱い

Claude Code が利用制限に達した場合、`stream-json` 出力の stdout には正常な JSON イベントが出力されず、stderr にのみ limit メッセージが出力されることがある。`iExtractResultFromStreamJson` は JSON パース不能な行を stderr 行として収集し、結果が空の場合にこれらを `"Error: ..."` として返す。空レスポンス（`result === ""`）は利用制限と同等に扱い、`Fallback -> True` の場合はフォールバックをトリガーする。
