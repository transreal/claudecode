---
name: dynamic-panel-render-cost
description: |
  Manipulate/DynamicModule/Dynamic ベースの一覧パネル (SourceVault ワークフロー一覧・
  保存プロンプト一覧など) が「一瞬フリーズしてから $Aborted」になり中身が出ない事故の
  原因と直し方。真因は (1) DynamicModule の body や Dynamic[...] の中身の評価は FE の
  評価予算で外部 Abort される (通常セル評価と違い時間切れで $Aborted になる)、
  (2) Grid 描画 Dynamic の中で「行ごとに重い全走査関数」を呼ぶと row*N 倍のコストで
  予算超過する、の 2 点。重いデータは DynamicModule の外 (公開関数の通常評価) で先に
  算出して焼き込み、繰り返し読む registry はキャッシュし、行ごとの重い lookup は
  NextFire 等の不要フィールド計算を外す。headless で再現しないときは FE だけがロード
  する副パッケージ (SourceVault_autotrigger 等) の差分を疑う。
  Use when a Wolfram panel/palette shows $Aborted (especially after a brief FE freeze)
  instead of its list/grid, when a DynamicModule/Manipulate UI is slow to render or gets
  aborted, when adding per-row badges/status cells to a list Grid, or when a UI bug
  reproduces in the FrontEnd but not in headless wolframscript. 関連 rules: 95
  (ScheduledTask 安全)。関連 skill: ui-output-font-customization, wolfram-syntax-pitfalls。
---

# Dynamic パネルの描画コストと FE $Aborted

`DynamicModule` / `Manipulate` / `Dynamic[...]` ベースの一覧パネルが、**チラッとフリーズしてから `$Aborted`** になって中身 (一覧 Grid) が出ない、という事故の診断と修正手順。SourceVault の「ワークフロー一覧」「保存プロンプト一覧」で実際に起きた (2026-06-30 修正)。

## 中核原理: Dynamic の評価は FE に Abort される

- **通常のセル評価・ボタン評価 (`Method->"Queued"` 含む) は時間切れで自動 abort されない。** 遅ければフリーズするだけで、いずれ完了する。ユーザーが `Alt+.` しない限り中断されない。
- **`DynamicModule` の body 評価、および `Dynamic[expr]` / `DynamicBox[ToBoxes[...]]` の中身の評価は別。** FE が表示のために評価し、評価予算 (時間) を超えると FE が外部から `Abort[]` を送る → そのセル/領域が **`$Aborted`** を表示する。
- したがって「重い処理が `$Aborted` になる」なら、その処理は **Dynamic / DynamicModule-body 文脈で評価されている**。逆に重い処理が「フリーズするが完走する」なら通常評価文脈。**`$Aborted` か単なるフリーズか**で、どちらの文脈かをまず切り分ける。
- `CheckAbort` は外部 Abort も捕捉できるが、`Quiet@Check` は **Abort を捕捉しない** (Check はメッセージ/失敗のみ)。`$Aborted` を握り潰したいなら `CheckAbort`。ただし握り潰しは対症療法で、本筋は「Dynamic 文脈で重い評価をしない」こと。

## 鉄則 1: 重いデータは DynamicModule の外で先に算出して焼き込む

`DynamicModule[{rows}, rows = heavy[]; Panel[...]]` のように **body で重い算出**をすると、表示時評価で `$Aborted` になりうる。重い算出は **公開関数の通常評価 (パレットクリック=通常評価) の段階**で済ませ、リテラルとして焼き込む:

```mathematica
makePanel[arg_] := With[{initRows = heavyRows[arg]},   (* ← 通常評価で算出 *)
  DynamicModule[{rows = initRows, query = ""},
    Panel[Column[{ header, Row[buttons],
      Dynamic[
        Which[
          rows === Automatic, Row[{ProgressIndicator[], Spacer[8], Style["読み込み中…", Gray]}],
          ! ListQ[rows] || rows === {}, Style["(該当なし)", Gray],
          True, Grid[ renderRows[rows] ]],
        TrackedSymbols :> {rows}] }], ImageMargins -> 4],
    (* 保存ノート再オープン等で rows が未確定の時だけ通常キューで再取得 *)
    Initialization :> If[! ListQ[rows],
      SessionSubmit[rows = heavyRows[arg]]],
    SynchronousInitialization -> False]];
```

ポイント:

- **`ExpressionCell[expr, "Output"]` は構築時に `expr` を評価する** (実測済み)。パレットが `CreateDocument[ExpressionCell[makePanel[], "Output"]]` なら `makePanel[]` はボタンクリックの通常評価で走る → `With` の `initRows` も通常評価で算出される。だから焼き込みが効く。
- ボタンの再取得・初期化の再取得は `SessionSubmit[...]` で**通常評価キュー**に投げる。これは Dynamic 更新ではないので FE の予算 abort の対象外。
- `Initialization` は保存ノートを開き直すたびに再実行されるので、再オープン時の保険になる (`SynchronousInitialization -> False`)。
- 表示の分岐は `Which` で `Automatic`(読込中) / 非リスト・空 / 正常 を必ず網羅し、想定外値が `Grid` に流れ込まないようにする。

## 鉄則 2: Grid 描画 Dynamic の中で「行ごとの重い全走査」をしない (最重要・実際の真因)

一覧の各行に status バッジ等を出すとき、**行ごとに全件走査するヘルパを呼ぶ**と `row * (呼び出し回数)` 倍のコストになり、Grid 描画 Dynamic が予算超過 → `$Aborted`。

SourceVault の実例 (2026-06-30):

- 各行が `SourceVaultAutoTriggerStatusCell["Workflow", slug]` を呼ぶ。
- これが `SourceVaultAutoTriggerForTarget` を **(Workflow 型では) 2 回**呼び、各々が重い `SourceVaultAutoTriggerListData[]` を**全件**走らせる。
- その中の `SourceVaultAutoTriggerNextFire` が**スケジュール地平線スキャンで 1 トリガ ~3.5 秒**。
- 結果: 3 行 × 2 = 6 回フルロード ≈ **18 秒** → Grid 描画 Dynamic で `$Aborted`。StatusCell 1 回 5.9 秒。

対策の優先順位:

1. **不要フィールドを計算しない (本命)**: バッジが使うのは `AutoToggle` / `Priority` / error だけで `NextFire` は不要だった。per-row lookup (`SourceVaultAutoTriggerForTarget`) を、全件 `ListData` 経由をやめて**該当 spec から直接 light row 構築**・`NextFire -> Missing["NotComputed"]` にした → 5.9 秒 → **0.017 秒**。
2. **繰り返し読む registry/JSON は短 TTL でキャッシュ**: 同一描画内で N 回読む I/O を 1 回に畳む。書き込み時にキャッシュ無効化。
   ```mathematica
   If[! AssociationQ[$cache], $cache = <|"Time" -> -1, "Entries" -> {}|>];
   $cacheTTL = 3;
   loadCached[] := Module[{now = AbsoluteTime[]},
     If[AssociationQ[$cache] && now - Lookup[$cache, "Time", -1] < $cacheTTL,
       Return[Lookup[$cache, "Entries", {}]]];
     With[{e = realLoad[]}, $cache = <|"Time" -> now, "Entries" -> e|>; e]];
   invalidate[] := ($cache = <|"Time" -> -1, "Entries" -> {}|>);
   ```
3. **どうしても重い列は遅延化**: その列だけ per-row の小さな `Dynamic` にして `SessionSubmit` で後から埋める (メイン Grid は即描画)。

> 一般則: **Dynamic / Grid 描画の中で「リスト全件をスキャンする関数」を行ごとに呼ばない。** 必要なら描画前に 1 回だけ index を作って渡すか、lookup を軽量化する。

## 鉄則 3: headless で再現しないなら「FE だけがロードする差分」を疑う

今回 wolframscript headless では一貫して速く (`iSVWFPanelRows` 0.1〜0.35 秒)、`$Aborted` を再現できず長く迷走した。真因の `SourceVault_autotrigger` は **`SourceVault.wl` の自動ロード Scan リストに無く**、headless では未ロード → 「自動起動」列が `—` になり重い呼び出しが一切走らなかった。FE では autotrigger がロード済みなので per-row 呼び出しが発火していた。

- **FE でだけ出る UI バグは、FE セッションが追加で読んでいる副パッケージ/フック (autotrigger, mining hook 等) を疑う。** headless の auto-load リストと FE の実ロード状態 (`Names["対象シンボル"]` で在否確認) を突き合わせる。
- headless で再現させたいなら、その副パッケージを明示的に `Get` してから測る。

## 診断レシピ (問題のカーネルで実行)

```mathematica
<|
 "NewCodeLoaded" -> Names["対象`Private`新規シンボル"],         (* 再ロード済みか *)
 "RowsResult" -> TimeConstrained[CheckAbort[Length[行算出関数[...]], "ABORTED-INSIDE"], 20, "TIMEOUT"],
 "PanelHead" -> Head[パネル関数[]],                            (* DynamicModule なら構築は成功 *)
 "NumTasks" -> Length[Tasks[]],                                (* 背景タスク飽和の有無 *)
 "TaskStatuses" -> Quiet@Check[#["TaskStatus"] & /@ Tasks[], $Failed]
|>
```

読み方:

- `RowsResult` が数字 (例 3) なのに UI は `$Aborted` → **行算出は無実。abort は Grid/Dynamic 描画段**。per-row の重い呼び出し (鉄則 2) を疑う。各 per-row ヘルパを `TimeConstrained[CheckAbort[ヘルパ[...], "AB"], 20, "TO"]` で個別計測し、秒単位のものを特定する。
- `RowsResult` が `ABORTED-INSIDE`/`TIMEOUT` → 行算出自体が重い。鉄則 1 (キャッシュ/precompute)。
- `NumTasks` が大きく `Running` 多数 → 背景の暴走ポーリング/スケジュールタスクがカーネルを占有し、あらゆる Dynamic が abort される (別系統。`rules/95` と関連 skill 参照)。
- 保存済み `.nb` の出力セルを開いて `rows$$ = {...}` が焼き込まれているか確認すると、precompute が効いているか/古い出力かが分かる。

## 反映時の注意

- ソースを直しても、**動いているカーネルは古い定義のまま**。`Needs` は再ロードしないので `Get` かカーネル再起動。修正が副パッケージ (autotrigger 等) なら**それも再 Get**されること (`Get["SourceVault.wl"]` だけだと副ファイルが再ロードされない場合があるのでカーネル再起動が確実)。
- 既に開いている保存パネルの出力セルは古い本体を再評価する。**閉じてパレットから開き直す**。

## 関連

- `rules/95-scheduled-task-safety.md` — 背景タスク/ポーリングの制約 (NumTasks 飽和系の abort)
- `skills/ui-output-font-customization` — 同じパネル系の別罠 (Button ラベル内関数の未評価など)
- `skills/wolfram-syntax-pitfalls` — `Quiet@Check` のエラー隠蔽など
