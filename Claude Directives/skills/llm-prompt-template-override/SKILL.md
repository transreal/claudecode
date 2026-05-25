---
name: llm-prompt-template-override
description: |
  既存パッケージ (ClaudeOrchestrator 等) の worker prompt template に、
  外部からドキュメントや指示を注入するときの prompt engineering パターン。

  単純な prepend / append では LLM が「これは参照情報であって依存ではない」
  と切り分けて応答を歪めることがある。

  XML タグの選び方、明示的指示コメントの書き方、template placeholder ラベル
  の StringReplace 置換戦略、fallback としての prepend、を SourceVault.wl
  A5 hook 実装 (2026-05-18) で検証済みのパターンとして記録する。
---

# LLM Prompt Template Override Patterns

既存パッケージが LLM 呼び出し用 prompt を組み立てている経路に対して、外部からドキュメントや指示文を注入したい場合の、LLM 応答が意図通りになるための prompt engineering パターン。

## 動機

ClaudeOrchestrator のように worker prompt が:

```
[ROLE / GOAL / OUTPUT_SCHEMA template]
{{DEPENDENCY_SECTION}}      ← 依存 artifact 一覧 (なければ "依存 artifact なし。")
```

という構造を持つ場合、SourceVault のように「note や PDF の本文」を渡したいとき、ナイーブに prompt の冒頭へ prepend すると LLM は:

- `<sources>抜粋本文</sources>` (prepend) → 「これは reference / 参考情報」
- `{{DEPENDENCY_SECTION}}` 部の「依存 artifact なし。」 → 「dependency = 空」

を **両方読んで切り分け** し、後者を優先して「依存 artifact が渡されていないため本文を参照できない」と回答する。実際に SourceVault.wl A5 hook の初期実装でこの現象を踏んだ。

## ナイーブな実装が失敗するパターン

```mathematica
(* ❌ 単純 prepend: LLM が "reference" と切り分ける *)
iInjectSourceContext[prompt_, ...] :=
  "<sources>\n" <> assembledText <> "\n</sources>\n\n---\n\n" <> prompt;
```

LLM が見る prompt:

```
<sources>
[note1 本文]
[note2 本文]
</sources>

---

GOAL: 3 つのメモを比較
{{DEPENDENCY_SECTION}}     ← "依存 artifact なし。"
```

→ LLM の応答: 「依存 artifact が渡されていないため、本文を参照できない。一般知識で答える」

## 推奨パターン: ラベル位置 StringReplace 置換 + prepend fallback

### 1. XML タグ命名を工夫

`<sources>` だと LLM が「reference / context」と認識する。**`<attached-documents>`** や **`<dependency-artifacts>`** にすると「これは task の dependency に近い」と認識しやすい。

Claude family は XML タグの命名を強い手がかりにする。汎用ワードよりも、宿主 prompt 内の語彙 ("dependency artifact" 等) と意図的に一致させる。

### 2. 明示的指示コメントを HTML コメント形式で含める

```
<attached-documents count="3">
<!-- 以下は worker タスクが参照すべき本文 (依存 artifact 相当)。
     Goal 達成にはこれらの内容を必ず参照し、
     詳細データが「実体」としてここに存在していると見なしてください。 -->
<document index="1">
[note1 本文]
</document>
...
</attached-documents>
```

ポイント:
- HTML コメント `<!-- ... -->` 形式で書くと LLM は「制作者の意図 / instruction」と認識する
- 「依存 artifact 相当として扱ってください」と **既存 template の語彙にフックさせる**
- count 属性で件数を明示すると LLM が dispatch しやすい
- `<document index="N">` で個別ドキュメントを囲むと、後段の応答内で「document 1 によれば〜」と引用しやすくなる

### 3. 既存 template の placeholder ラベル位置を StringReplace で置換

宿主 template の `{{DEPENDENCY_SECTION}}` が「依存 artifact なし。」というリテラル文字列を出している場合、その文字列を `<attached-documents>` セクションで **置換** する:

```mathematica
iA5InjectSourceVaultContext[prompt_, role_, task_] :=
  Module[{contextText, promptStr, replaced, newPrompt},
    contextText = iBuildSourceVaultContextSection[allSources];
    (* contextText は <attached-documents>...</attached-documents> *)
    
    If[!StringQ[contextText] || StringTrim[contextText] === "",
      Return[promptStr, Module]];
    
    promptStr = If[StringQ[prompt], prompt, ToString[prompt]];
    
    (* 「依存 artifact なし。」 を context で置換 *)
    replaced = False;
    Do[
      newPrompt = StringReplace[promptStr, pat -> contextText, 1];
      If[newPrompt =!= promptStr,
        promptStr = newPrompt;
        replaced = True;
        Break[]],
      {pat, {"\:4f9d\:5b58 artifact \:306a\:3057\:3002",
             "No dependency artifacts."}}];
    
    (* ラベルが見つからない経路は fallback で prepend *)
    If[replaced,
      promptStr,
      contextText <> "\n\n---\n\n" <> promptStr]
  ];
```

LLM が見る prompt (置換後):

```
GOAL: 3 つのメモを比較
依存 artifact (前段タスクの出力):
<attached-documents count="3">
<!-- 以下は worker タスクが参照すべき本文 (依存 artifact 相当)。... -->
<document index="1">...</document>
...
</attached-documents>
```

→ LLM の応答: 「モンテカルロ法、ライプニッツ級数、Wallis 積...」(本文を実体として参照した実質的な比較)

### 4. 2 段階フォールバック設計

| シーン | 動作 |
|---|---|
| 宿主 template から呼ばれた (placeholder ラベルあり) | (1) ラベル位置で置換 |
| API として直接呼ばれた (ラベルなし、空 task) | (2) prepend にフォールバック |
| 既に依存 artifact がある (placeholder が空ラベルでない) | (2) prepend にフォールバック |

```mathematica
(* 試行リスト: 言語 / 文言バリエーション *)
labels = {"\:4f9d\:5b58 artifact \:306a\:3057\:3002",
          "No dependency artifacts."};

replaced = False;
Do[..., {pat, labels}];

If[replaced, promptStr, contextText <> "\n\n---\n\n" <> promptStr]
```

ポイント:
- 主言語 + 英語の両方を試す ($Language の違いに対応)
- `StringReplace[..., pat -> contextText, 1]` で 1 回だけ置換 (誤って複数置換しない)
- 置換に失敗した経路でも **prepend で最低限の動作** を保証

## 設計上の指針

### 宿主 template の placeholder 文言が変わると壊れる

このパターンは「宿主が出すリテラル文言」に依存する。template 文言が変わると置換パターンも更新が必要。

→ **動作確認テスト** をユーザマニュアル / example に必ず含める:

```mathematica
testPrompt = "
GOAL: {test}

\:4f9d\:5b58 artifact \:306a\:3057\:3002

other";
ClaudeOrchestrator`A5InjectSourceVaultContext[testPrompt, "worker", <|"Goal" -> "test"|>]
(* 期待: "依存 artifact なし。" が <attached-documents>...</attached-documents> に置換される *)
```

これがユーザ環境で動くなら置換 OK。動かなければ宿主 template が更新されている → 置換パターンを更新する。

### 双方の宿主 template 言語に対応する

宿主 template が日英切替を持つ場合、`$Language === "Japanese"` での文言と英語環境での文言の両方をラベルセットに含める。

### Hook 経路全体としての安全性

このパターンは `package-hook-installation-patterns` と組み合わせて使う:

1. 宿主の hook 点 (e.g. `A5InjectSourceVaultContext`) に DownValues 経由で実装を提供 (`package-hook-installation-patterns`)
2. 実装内で本スキルのテンプレ (XML タグ + 指示コメント + ラベル置換 + prepend fallback) を使う
3. hook の auto-detect が scheduled task コンテキストで呼ばれる場合は memory registry fallback も併用 (`rules/95-scheduled-task-safety.md` §F)

## 適用タイミング

- 既存パッケージの LLM 呼び出し prompt にドキュメントや instruction を追加注入したくなったとき
- 既存 prompt の中に「依存 artifact なし」「No context provided」のような **LLM の解釈を歪める文言** がある場合
- LLM 応答が「情報が渡されていない」と訴えるのに、prepend / append で実装してしまっている場合

## 関連 skill / rules

- `skills/package-hook-installation-patterns` (hook 装着の基盤)
- `rules/03-llm-instructions-not-in-source.md` (LLM への指示文は skill / rules に置く方針)
- `skills/llm-instruction-separation` (LLM 向け prompt の構造化原則)
