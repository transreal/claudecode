---
paths:
  - "**/SourceVault*.wl"
  - "**/NBAccess*.wl"
  - "**/sourcevault*.md"
---

# 103 — SourceVault データストア書き込み安全規約

## 背景

SourceVault の運用が始まると、`<PrivateVault>/notebooks/` 配下の
ストア (`sources` / `snapshots` / `summaries` / `todos` / `review` /
`lint` / `sync` / `relink`) は **日々の作業記録そのもの**になる。
開発初期のように `SourceVaultResetStore["Confirm" -> True]` で
気軽に全削除して作り直す、ということは**できなくなる**。

Stage 9 P1 拡張〜次フェーズの開発で、Relink のバグにより
`sources/` ストアが実際に破損し、全件再 index でしか復旧できない
事態が複数回発生した。原因は以下の 3 つだった:

1. `Return[expr, Module]` が「最も内側の同名 Module」から抜ける
   仕様を取り違え、`Linked` 判定後の早期 return が内側 Module
   だけを抜け、処理が照合ループに流れて全件を誤って「移動」扱い
   した (罠系)。
2. レコードの「移動した」判定を `OriginalPath` の生
   `FileExistsQ` で行い、別 PC のパスを移動と誤検出した。
3. 未検証の `DryRun -> False` を実行し、誤判定の結果を
   そのままストアに書き込んだ。

このルールは、データストアを破壊するバグを二度と作り込まない
ための必須規約である。**SourceVault のストア書き込みコードを
書く・直すときは、このルールを最優先で守る。**

## 必須ルール

### 1. 破壊的操作は DryRun を既定にする

ストアの内容を変更・削除・上書きする公開 API は、**`DryRun`
オプションを持ち、既定を `True`** にする。`DryRun -> True` の
ときは一切の書き込み・削除を行わず、「何をするか」のレポート
だけを返す。実際の変更は呼び出し側が明示的に `DryRun -> False`
を渡したときのみ行う。

該当する操作の例: `SourceVaultRelinkSources` (record の
Superseded マーク / 削除)、`SourceVaultSync` (再 index)、
`SourceVaultResetStore` (全削除)。

### 2. 削除と「マーク」を別オプションに分ける

レコードを「もう使わない」状態にするとき、既定は**非破壊の
マーク**にする。`RelinkStatus -> "Superseded"` /
`"StaleDuplicate"` のように、レコードファイル自体は残し、
フィールドを足すだけにする。

ファイルの物理削除は、**マークとは別の明示オプション**
(`DeleteStale -> True` 等) でのみ行う。削除オプションの既定は
必ず `False`。

### 3. 全削除には二重の明示確認

`SourceVaultResetStore` のような全削除 API は、`"Confirm" -> True`
が無ければ DryRun 扱いとし、削除対象の一覧だけを返す。
`"Confirm" -> True` があって初めて実削除する。この二段構えを
省略しない。

### 4. 早期 return のスコープを必ず確認する

`Return[expr, Module]` は **最も内側の同名 `Module`** から抜ける。
関数全体を抜けたい早期 return は、**関数本体の `Module`** に
書く。`Module[{tmp}, ...]` のような内側ブロックの中に
`Return[..., Module]` を書くと、内側 Module だけを抜けて処理が
後続に流れる。ストア書き込みコードでこれをやると、スキップ
すべきレコードが書き込み対象に流れ込む。

早期 return を含む `If` を書くときは、その `If` が
どの `Module` の直下にあるかを必ず確認する。内側 Module が
必要なら、判定結果だけを内側 Module から値として返し、
早期 return は外側で行う。

### 5. 判定は派生 ID でなく実体で行う

レコードの同一性・実在性を判定するとき、`NotebookRef`
(パスのハッシュ) のような派生 ID の一致だけに頼らない。
ハッシュは衝突しうるし、パス正規化の差で同じファイルが
別 ID になることもある。**実ファイルパス**を解決して
`FileExistsQ` で確かめる、**内容ハッシュ**で照合する、
といった実体ベースの判定を併用する。

ファイルが「移動したか」の判定は、記録された絶対パスの
生 `FileExistsQ` ではなく、**シンボリックパス
(`{"$onWork", ...}`) を現 PC で解決した結果**で行う
(rule 101 / Step 5、罠 #45)。別 PC のパスを移動と
誤検出してはならない。

### 6. 多段照合は信頼度で「自動適用」と「レポートのみ」を分ける

複数の照合手段 (UUID / 内容ハッシュ / ファイル名) を持つとき、
**強い証拠 (UUID / 内容ハッシュ) は自動適用してよいが、
弱い証拠 (ファイル名一致) は自動適用しない**。弱い証拠での
マッチは既定でレポートするだけにとどめ、明示オプション
(`ApplyNameOnly -> True` 等) を渡したときのみ適用する。
連番ファイル群 (`計算と自然 01`〜`25` 等) でファイル名一致は
容易に誤マッチする。

### 7. 書き込み前に DryRun 結果を人間が検証する

破壊的操作を `DryRun -> False` で実行する前に、必ず
`DryRun -> True` の結果を出し、件数・内訳が妥当かを
**人間 (Imai 先生) が確認**してから実行する。テストでも
この順序を守る。`DryRun -> True` の結果が直感に反する
件数 (例: 全ファイルが「移動」扱い) を示したら、それは
バグのサインであり、`DryRun -> False` を実行してはならない。

### 8. atomic write を徹底する

レコードファイルの書き込みは `path.tmp` → 検証 →
`RenameFile` の atomic write パターンを使う (rule 101 /
Stage 10.4)。書き込み途中で失敗しても、壊れた中途半端な
ファイルを残さない。

### 9. 戻り値に十分な集計を含める

破壊的操作の戻り値には、何をどれだけ変更したかの集計
(`Linked` / `RelinkedCount` / `ByMethod` / `StaleDeletedCount`
等) を必ず含める。呼び出し側が結果の妥当性を即座に
判断できるようにする。「成功」だけ返して件数を返さない
設計にしない。

## チェックリスト (ストア書き込みコードを書いたら)

- [ ] 破壊的操作に `DryRun` オプションがあり、既定が `True` か
- [ ] 削除と非破壊マークが別オプションに分かれているか
- [ ] 削除系オプションの既定が `False` か
- [ ] 早期 return (`Return[..., Module]`) が意図した `Module`
      を抜けているか (内側 Module に閉じ込められていないか)
- [ ] 同一性判定が派生 ID だけに頼らず実体を見ているか
- [ ] 弱い照合 (ファイル名等) を自動適用していないか
- [ ] 戻り値に変更件数の集計が含まれているか
- [ ] atomic write (tmp + Rename) を使っているか

## 関連

- `rules/101-sourcevault-stage-status.md` — ストアレイアウト、
  iSanitizeForJSON / ReadByteArray 経路、Step 5 シンボリックパス
- `rules/85-safe-merge.md` — パッケージソースの破壊防止
  (こちらはコードファイル、103 はデータストア)
- `skills/wolfram-syntax-pitfalls` — 罠 #52
  (`Return[expr, Module]` のスコープ)
- `skills/notebook-management-extraction` — Relink / Sync /
  UUID 機構の詳細設計
