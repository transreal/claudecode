---
description: Claude Directives は公開リポジトリと cloud LLM に出るので PrivacyLevel 0.0 だけを書く。PL > 0 は私的ノートへ移し sv://directive で引用する
tier: guardrail
---

# 112 — Directive は PL 0.0 だけ (私的な内容は sv://directive で引用)

`Claude Directives/` (CLAUDE.md・rules・skills) は GitHub の公開リポジトリへ反映され、cloud LLM のシステムプロンプトと MCP の `sourcevault_directive_body` にも PL 0.0 として渡る。ここに書いてよいのは PrivacyLevel 0.0 の内容だけ。

- **書かない**: 実 OS ユーザー名入りのパス (`C:\Users\<user>\...` と書く)、マシン名・機種名、実ノート・実イベント・実講義の名前と日付、SourceVault の実 ID (`nb-src-…`, `snap-sha256-…`)、実メールの検索語・mbox の一覧、所有者や第三者の氏名、私的 vault の実パス、未修正の抜け道の具体名、秘密の値。例は架空の値・プレースホルダにする。
- **必要な私的情報**は私的ノート `<root>_private/notes/<name>.md` (frontmatter に `privacyLevel:`、無ければ 1.0) に置き、本文からは `sv://directive/<id>` で引用する。URI は `ClaudeDirectives`ClaudeDirectivePrivateURI["<name>"]`。PL < 0.5 は release gate を通る cloud principal が `sourcevault_get` で読め、PL >= 0.5 はローカル principal が grant 付きでだけ読める。
- 公開 directive に `privacyLevel:` (> 0) やスタンプ `<!-- :CodePrivacyLevel: x -->` を付けない。付いていれば GitHub 反映が止まる。
- 書いたら `ClaudeDirectives`ClaudeDirectivesPrivacyLint[]` で確かめる (Clean であること)。所有者固有の検出語は `<root>_private/privacy_terms.json` に足す。GitHub 反映 (`GitHubRefreshAndCommit`) は違反・lint 不能・`*_private` パスがあると fail-closed で止まる。
- lint は正規表現の網で、意味の判断 (実際の検索語か、未修正の弱点か) はしない。迷ったら私的ノートへ倒す。
