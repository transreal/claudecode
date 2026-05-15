---
name: llm-instruction-separation
description: LLM への生成指示文・モデル枝番・運用慣習を `.wl` に書かないための分離原則と移行手順。新規パッケージ設計時、および既存 `.wl` でハードコード違反を見つけたときに参照。`rules/02-llm-instructions-not-in-source.md` と対をなす実装ガイド。
---

# LLM 指示分離 skill

## いつ使うか

- 新しい `.wl` パッケージを設計するとき
- 既存 `.wl` から `Print` / 文字列定数 / `Which` / `Switch` でモデル名・プロバイダ名・LLM 用テンプレートが書かれているのを見つけたとき
- skill ファイルを増やすか `.wl` に直書きするか迷ったとき

## 分離の原則 (4 つ)

1. **「枝番」は `.wl` に書かない**: `gpt-5`, `claude-opus-4.7` のような具体モデル名は `$ClaudeModelCapabilities` テーブルの key としてのみ存在させる。コード分岐 (`Which[StringStartsQ[..., "gpt-5"], ...]`) には書かない。
2. **「LLM への指示文」は skill に書く**: `$petriNetGuideExtras` 等のテンプレート文字列は skill の Markdown に置き、`.wl` はロード時に読み込む。
3. **「運用慣習」は rules に書く**: 「`Quiet@Check` を使うな」「保存先は `$ClaudeWorkingDirectory`」のような全パッケージ横断の規約は rules。
4. **「特定パッケージ固有のテクニック」は専用 skill に書く**: 当該パッケージの `.wl` には skill への参照だけ残す。

## 移行パターン: 文字列定数を skill に切り出す

### Before (`.wl` 側)

```wolfram
(* petri_from_prompt_chatgpt.wl 内 *)
$petriNetGuideExtras = "
# Provider selection for LLM calls

When the user goal involves multiple LLM providers...
  review = ClaudeCode`ClaudeQueryBg[
    \"Review for correctness: \" <> text,
    Model -> {\"openai\", \"gpt-5\"},
    ClaudeCode`Fallback -> True];
...
";

AddProviderSupportToPetriPrompt[] :=
  ($petriNetGuide = $petriNetGuide <> "\n" <> $petriNetGuideExtras);
```

### After (`.wl` 側)

```wolfram
(* petri_from_prompt_chatgpt.wl 内 *)
$petriNetGuideExtras := iReadSkillBody["petri-multi-provider-generation"];

AddProviderSupportToPetriPrompt[] :=
  ($petriNetGuide = $petriNetGuide <> "\n\n" <> $petriNetGuideExtras);
```

`iReadSkillBody` は `.wl` パッケージが必ず備えるべきユーティリティ:

```wolfram
iReadSkillBody[skillName_String] :=
  Module[{roots, candidates, path, body},
    (* ClaudeDirectives`ClaudeFindDirectiveRoots[] に完全委譲する。
       Global コンテキストのシンボルを直接参照しない (shadowing 回避)。 *)
    roots = If[
        StringQ[Quiet[Context[ClaudeDirectives`ClaudeFindDirectiveRoots]]] &&
        Context[ClaudeDirectives`ClaudeFindDirectiveRoots] === "ClaudeDirectives`",
      Quiet[ClaudeDirectives`ClaudeFindDirectiveRoots[]],
      {}];
    If[!ListQ[roots], roots = {}];
    candidates =
      Map[FileNameJoin[{#, "skills", skillName, "SKILL.md"}] &, roots];
    path = SelectFirst[candidates, FileExistsQ, None];
    If[path === None,
      Return["[skill " <> skillName <> " not found]"]];
    body = Quiet[Import[path, "String"]];
    If[!StringQ[body],
      Return["[skill " <> skillName <> " load failed]"]];
    (* frontmatter の --- ブロックを除去 *)
    StringReplace[body,
      RegularExpression["(?s)\\A---.*?---\\s*"] -> "", 1]
  ];
```

skill の本体 (`SKILL.md`) は frontmatter の後に Markdown を書く形式。frontmatter は LLM の routing 用なのでロード時に削るのが無難。

**重要**: Directives のディレクトリ解決は **`ClaudeDirectives`ClaudeFindDirectiveRoots[]` に完全委譲する**。`Global``$packageDirectory` 等を `iReadSkillBody` から直接参照すると、`ClaudeDirectives``` パッケージがロードされた後で `General::shdw` 警告 (シンボルが複数コンテキストに存在) が出る。`ClaudeFindDirectiveRoots[]` は内部で安全な順序で複数候補を探索するので、この一段経由するだけで足りる。

### Before (`.wl` 側、モデル枝番分岐)

```wolfram
iPrefixMatchCapability[modelName_String] :=
  Which[
    StringStartsQ[normalized, "gpt-5"],     $caps["gpt-5"],
    StringStartsQ[normalized, "gpt-4.1"],   $caps["gpt-4.1"],
    StringStartsQ[normalized, "gpt-4.5"],   $caps["gpt-4.1"],
    StringStartsQ[normalized, "gpt-4o"],    $caps["gpt-4o"],
    StringStartsQ[normalized, "gpt-3"],     $caps["gpt-4o-mini"],
    ...
  ];
```

### After (`.wl` 側、汎用判定のみ)

```wolfram
iPrefixMatchCapability[modelName_String] :=
  Module[{normalized, provider, sameClassCandidate},
    normalized = iNormalizeModelName[modelName];
    (* 1. 完全一致 (テーブル登録済み) を最優先 *)
    If[KeyExistsQ[$ClaudeModelCapabilities, normalized],
      Return[$ClaudeModelCapabilities[normalized]]];
    (* 2. Provider を抽出して同 Provider の登録済みモデルから推定 *)
    provider = iGuessProvider[normalized];
    sameClassCandidate = iFindCandidateInProvider[provider];
    If[AssociationQ[sameClassCandidate], Return[sameClassCandidate]];
    (* 3. 完全な未知 *)
    iUnknownDefault[]
  ];

iGuessProvider[name_] :=
  Which[
    StringStartsQ[name, "claude-"],   "anthropic",
    StringStartsQ[name, "qwen"],      "lm-studio",
    StringStartsQ[name, "gpt-oss"],   "lm-studio",
    StringStartsQ[name, "gpt"],       "openai",
    True,                             "unknown"
  ];
```

ここでも prefix マッチが残るが、これは **Provider 単位 (5 種類程度しかなく、半年で増減しない)** なので OK。**枝番 (gpt-5 / gpt-4.1 / gpt-4o ...) を書かない** ことが要点。

## チェックリスト

新規 `.wl` または既存 `.wl` の編集時に確認:

- [ ] モデル名の文字列が `$ClaudeModelCapabilities` のテーブル登録以外に出てくるか? → 出てきたらそれは違反。
- [ ] `.wl` に LLM 向けの長い指示テキスト (50 文字以上) があるか? → あれば skill に切り出す。
- [ ] `.wl` の文字列定数の中に `Model -> {"openai", "gpt-5"}` のようなコード例があるか? → skill に切り出す。
- [ ] `Print[Style["...", Bold]]` の中身は単なるバージョン情報 / ロード完了メッセージか? → これは OK (LLM の生成指示ではなく実行時通知)
- [ ] コメント内に「LLM はこう書くべき」という指示があるか? → skill に切り出す。

## アンチパターン

- `.wl` の中に Markdown を埋め込んで「これを skill 代わりに」する → ❌。skill ディレクトリを使う。
- skill ファイルの中で `<|"Class" -> "Heavy-Cloud", ...|>` のような Mathematica 式を書く → ❌。skill は Markdown のみ。データは `.wl` のテーブルに登録。
- `.wl` から skill の path を Hard-code (`"C:/.../SKILL.md"`) する → ❌。`ClaudeDirectives`ClaudeFindDirectiveRoots[]` を使う。
- `Global``$packageDirectory` 等の Global コンテキストシンボルを `.wl` 内から直接参照する → ❌。`General::shdw` 警告の原因。`ClaudeDirectives`ClaudeFindDirectiveRoots[]` のような公開 API のみ通す。

## 関連

- `rules/02-llm-instructions-not-in-source.md` — このルールの宣言と背景
- `skills/petri-multi-provider-generation` — 切り出された Petri 用指示文 (旧 `$petriNetGuideExtras`)
- `skills/wolfram-general` — `.wl` 編集の基本ルール
- `skills/wolfram-syntax-pitfalls` — `.wl` の syntax 罠
