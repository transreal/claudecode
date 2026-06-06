---
name: mathematica-style-slides
description: Use when creating slide images (16:9 PNG) that must visually match the user's Mathematica notebook presentation deck — white background, orange heavy title, maroon square nested bullets (3 levels + gray sub-sub), Hiragino Japanese fonts, no-bullet paragraph items. Covers the HTML+headless-browser pipeline (reliable for Japanese, easy multi-column), the exact style spec / color / Hiragino font palette, the two-column layout the Mathematica deck cannot do natively, and the render command. Worked examples: Templates/Slides/mathematica-style-twocolumn-slide.html and mathematica-style-bullets-levels.html.
---

# Mathematica スタイルのスライド作成

ユーザーの Mathematica ノートブック・プレゼンテーション (slideshow) の一枚と**連続表示しても違和感がない**スライド画像 (16:9 PNG) を作る手順とスタイル仕様。

## なぜ HTML + ヘッドレスブラウザで作るか

- **段組が容易**: Mathematica のスライドは多段組 (左に箇条書き・右に図) のレイアウトが難しく、実際のデッキは図を**仕方なく下に**置いていることが多い。HTML/CSS なら `grid`/`flex` で左右段組を自然に組める。**図はできるだけ右カラムに置く** (下置きはデッキ側の制約の回避であって理想ではない)。
- **日本語が確実**: `wolframscript` は `.wls` 内の日本語リテラルを UTF-8 で読み損ねることがある (文字化け)。HTML を UTF-8 で書き、ブラウザでレンダリングすれば日本語は確実に正しく出る。Wolfram `Graphics` でテキストを組むより本文の組版もきれい。
- **再現性**: ヘッドレス Edge/Chrome の `--screenshot` で 1920×1080 を一発出力。

`wolframscript` で `Graphics` を `Rasterize`/`Export` する手もあるが、日本語リテラル誤読・組版の手間から **既定は HTML 経由**。

## スタイル仕様 (Mathematica デッキの見た目)

実例の参考スライド (放射状移動) を基準にした書式:

- **背景**: 白 `#ffffff`
- **タイトル**: オレンジ・左上、**Hiragino Kaku Gothic ProN W6**（本文 ProN とそろえた太ウエイト）約 60px、色 `#e07c14`
- **箇条書きビュレット**（**塗りつぶし四角**・階層インデント）:
  - **第1階層**: マルーン `#9d1c1c`・四角 19px・本文 36px
  - **第2階層**: マルーン `#9d1c1c`・四角 16px・本文 30px・左インデント
  - **第3階層（サブサブ）**: **グレー** `#8a8a8a`・四角 14px・本文 26px・さらにインデント
- **アイテムパラグラフ（ノーブレット）**: 常にビュレットを付ける必要はない。ある項目の付加説明は、四角を付けず**親アイテムの本文位置に揃えた段落**（`.p1`/`.p2`）で続けてよい（**推奨**）。デッキでも多行の補足はビュレットなしで折り返している。
- **本文**: ほぼ黒 `#1c1c1c`〜`#232323`、**Hiragino Kaku Gothic ProN W3**（ウエイト3）。フォントは下記「## フォント」のパレットから選ぶ。
- **区切り記号**: lead 語と説明の間に `―` (色 `#b06a16`)
- **数字は半角・前後にスペースを入れない**: 「4つ」「2段階」「5フェーズ」「1ターン」のように、日本語に隣接する半角数字の前後は詰める（`4 つ` ではなく `4つ`）。全角数字は使わず半角で統一。ラテン語と数字の語間スペース（`AES-256`, `PrivacyLevel 0–1`, `2段階 authorization` の段階↔authorization 間）は通常どおり残す。
- **左寄せ・余白広め**: `padding: 66px 110px 56px` 程度。余白は埋めすぎない (デッキ自体が余白多め) が、空きが大きければ補足キャプションでなく**中身 (サブ箇条書き・サブサブ・段落説明等) を充実**させる
- **図版・補助図**: 右カラムに縦型フロー等。淡いカード `#faf6f0` + オレンジ左罫 `#e07c14` + マルーン番号バッジ `#9d1c1c` で暖色系に統一 (青緑など寒色は使わずデッキの暖色に合わせる)

色のまとめ:

| 用途 | 色 |
|---|---|
| タイトル (オレンジ) | `#e07c14` |
| ビュレット・番号・小見出し (マルーン) | `#9d1c1c` |
| サブサブ四角 (グレー) | `#8a8a8a` |
| 本文 | `#1c1c1c` / `#232323` |
| 補助テキスト (dim) | `#5a5a5a` |
| カード地 / 罫 | `#faf6f0` / `#e6d8c4`、左罫 `#e07c14` |
| リンク青 (出典等) | `#3a4cc0` |

## フォント (Hiragino パレット)

デッキは Hiragino 系で組まれている。**このフォントは本ホスト (Windows) にインストール済み**で、GDI 登録名はウエイト接尾辞付き (`... W3` / `W8` など)。**headless Edge でもこの名前で実フォントがレンダリングされる** (フォールバックにならない)。指定できるのは次の 5 系統:

| 役割 | CSS family（Windows 実名） | 用途 |
|---|---|---|
| 本文 (W3) | `"Hiragino Kaku Gothic ProN W3"` | 既定の本文・箇条書き |
| 見出し (W6) | `"Hiragino Kaku Gothic ProN W6"` | **タイトル・見出し（既定）** |
| 強調・lead (W4) | `"Hiragino Kaku Gothic Std W4"` | lead ラベル・`<b>`・図中見出し |
| 極太見出し (W8) | `"Hiragino Kaku Gothic StdN W8"` | より黒い見出しが欲しいとき（後述の注意） |
| 丸ゴシック | `"Hiragino Maru Gothic ProN W4"` | やわらかい印象にしたいとき |
| 明朝 | `"Hiragino Mincho ProN W3"` (W6 もあり) | セリフ調にしたいとき |

**⚠ ProN と Std/StdN は「かな字形」が違う**: `ProN`（Pro New）は現代的なかな、`Std`/`StdN` は古い字形のかな。**本文を ProN にしたら見出しも ProN にそろえる**。本文 ProN W3 ＋ 見出し StdN W8 のように混ぜると、かなが別デザインになり「タイトルだけ別フォント／Hiragino でない」ように見える（実際にこの指摘を受けた）。ProN の太いウエイトは **W6** なので、見出しの既定は **ProN W6**。どうしても W8 の黒さが要るときだけ StdN W8 を使い、その場合は本文も Std 系にそろえるか割り切る。

**太字はファミリ切替で出す（`font-weight` ではない）**: Hiragino の各ウエイトは別ファイルの**別ファミリ**。本文ファミリ (W3) に `font-weight:700` を当てるとブラウザが合成 (faux bold) して汚い。強調は **family を W4 / W6 に切り替え `font-weight:normal`** にする。CSS 変数で役割を定義しておくとよい:

```css
:root {
  --f-body:"Hiragino Kaku Gothic ProN W3","Hiragino Kaku Gothic ProN","Yu Gothic UI","Meiryo",sans-serif;
  --f-medium:"Hiragino Kaku Gothic Std W4","Hiragino Kaku Gothic StdN W4","Yu Gothic UI",sans-serif;
  --f-head:"Hiragino Kaku Gothic ProN W6","Hiragino Kaku Gothic StdN W8","Hiragino Kaku Gothic ProN","Yu Gothic UI",sans-serif;  /* 本文 ProN とそろえて W6 */
  --f-maru:"Hiragino Maru Gothic ProN W4","Hiragino Maru Gothic Pro W4",sans-serif;
  --f-mincho:"Hiragino Mincho ProN W3","Hiragino Mincho ProN","Yu Mincho",serif;
}
body { font-family:var(--f-body); font-weight:normal; }
b, strong, .ld { font-family:var(--f-medium); font-weight:normal; }   /* faux-bold を避ける */
.title { font-family:var(--f-head); }
```

末尾に `"Yu Gothic UI"` 等の Windows 標準を足しておくと、Hiragino の無い別環境でも崩れない。**確認のコツ**: 丸ゴシック (Maru) が丸く・明朝 (Mincho) がセリフで出れば Hiragino は効いている。見出しが本文とかな字形が違って見えたら ProN/Std の取り違えを疑う。フォント追従の一般論は `ui-output-font-customization` を参照。

## CSS スケルトン (段組 + 3 階層ビュレット + パラグラフ)

`:root` のフォント変数は前節のものを使う。

```css
html, body { width:1920px; height:1080px; background:#fff;
  font-family:var(--f-body); font-weight:normal; color:#1c1c1c; }
.slide { position:relative; width:1920px; height:1080px; padding:66px 110px 56px; }
.title { font-family:var(--f-head); font-size:60px; color:#e07c14; }
.body  { display:grid; grid-template-columns:1fr 560px; gap:70px; }   /* 箇条書き左 / 図右 */

/* 第1階層: マルーン四角(大) */
.b1 { position:relative; padding-left:46px; font-family:var(--f-medium); font-size:36px; }
.b1::before { content:""; position:absolute; left:4px; top:15px; width:19px; height:19px; background:#9d1c1c; }
/* 第2階層: マルーン四角(小) */
.b2 { position:relative; padding-left:46px; margin-left:50px; font-size:30px; color:#232323; }
.b2::before { content:""; position:absolute; left:6px; top:12px; width:16px; height:16px; background:#9d1c1c; }
/* 第3階層(サブサブ): グレー四角 */
.b3 { position:relative; padding-left:42px; margin-left:100px; font-size:26px; color:#3a3a3a; }
.b3::before { content:""; position:absolute; left:5px; top:11px; width:14px; height:14px; background:#8a8a8a; }
/* ノーブレットの段落説明 (親アイテムの本文位置に揃える) */
.p1 { margin-left:46px;  font-size:30px; color:#4a4a4a; }   /* b1 の下 */
.p2 { margin-left:96px;  font-size:27px; color:#4a4a4a; }   /* b2 の下 */
```

- 四角ビュレットは `list-style` でなく `::before` の塗り疑似要素で出すと、サイズ・色・縦位置を階層ごとに正確に制御できる。
- `margin-left` は「親の本文開始位置」に合わせる。`.p1`=`.b1` の本文位置、`.p2`=`.b2` の本文位置。これで段落説明がビュレット文に綺麗に揃う。
- 階層は深くしすぎない。**第3階層まで**を目安にし、それ以上は段落説明か別スライドに逃がす。

## レンダリング (1920×1080 PNG)

ヘッドレス Edge (Windows に標準。Chrome でも可) で file:// を撮る:

```powershell
$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$html = "<絶対パス>.html"
$out  = "<絶対パス>.png"
& $edge --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 `
        --window-size=1920,1080 --screenshot="$out" "file:///$($html -replace '\\','/')"
```

- `--force-device-scale-factor=1` + `--window-size=1920,1080` で 16:9・等倍を保証 (`body` も同サイズ・`overflow:hidden` にしておく)
- 出力 PNG を Read ツールで開いて**実際の見た目を必ず確認**し、はみ出し・改行・余白を見て調整 → 再レンダリング、を繰り返す
- 保存先はパスポリシー (`notebook-path-policy`) に従い、ユーザー指定がなければ作業ディレクトリ/`NotebookDirectory[]`

### タイトルを除いた本体画像（タイトルはデッキ側で付ける）

実 Mathematica スライドでは**タイトルはスライドの見出しとして別に付ける**ことが多い。その場合、HTML 由来の画像は**タイトル帯（eyebrow＋title）を切り落とし、本体だけ**にして渡す（`<slide>_body.png`）。本体の位置・幅・下の余白はそのまま保つ（タイトルだけ上から削る）。

実装はフルスライド PNG の**タイトル直下の白いギャップ行**を検出して上を切るだけ。`LockBits`＋`Marshal.Copy` で一括読みし、`y=135`（タイトルのインク内）から下へ走査して最初の白行 `g1`、続く最初のインク行 `g2`（本体の先頭）を見つけ、その**中点で水平カット**する（位置のハードコード不要・3 枚共通）。

```powershell
Add-Type -AssemblyName System.Drawing
function Crop-Top($inPath,$outPath){
  $bmp=New-Object System.Drawing.Bitmap($inPath); $w=$bmp.Width; $h=$bmp.Height
  $d=$bmp.LockBits((New-Object System.Drawing.Rectangle 0,0,$w,$h),[System.Drawing.Imaging.ImageLockMode]::ReadOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $by=New-Object byte[] ($d.Stride*$h); [System.Runtime.InteropServices.Marshal]::Copy($d.Scan0,$by,0,$by.Length); $s=$d.Stride; $bmp.UnlockBits($d)
  function Ink($y){ $r=$y*$s; for($x=0;$x -lt $w;$x+=3){ $i=$r+$x*4; if($by[$i]-lt245 -or $by[$i+1]-lt245 -or $by[$i+2]-lt245){return $true} } return $false }
  $g1=135; for($y=135;$y -lt 260;$y++){ if(-not (Ink $y)){$g1=$y;break} }      # タイトル下端の白行
  $g2=$g1; for($y=$g1;$y -lt 360;$y++){ if(Ink $y){$g2=$y;break} }              # 本体の先頭行
  $cut=[int](($g1+$g2)/2); $ch=$h-$cut
  $c=New-Object System.Drawing.Bitmap $w,$ch; $g=[System.Drawing.Graphics]::FromImage($c)
  $g.DrawImage($bmp,(New-Object System.Drawing.Rectangle 0,0,$w,$ch),(New-Object System.Drawing.Rectangle 0,$cut,$w,$ch),[System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose();$c.Save($outPath,[System.Drawing.Imaging.ImageFormat]::Png);$c.Dispose();$bmp.Dispose() }
```

`Crop-Top "<slide>.png" "<slide>_body.png"` で `1920x892` 程度（タイトル帯ぶん低い・全幅・下余白は元のまま）になる。前提: `y=135` がタイトルのインク内に入る本文レイアウト（このスキルの padding/見出しサイズ）。eyebrow を残したい等の例外時は `g1` 開始 y を調整する。**タイトル単独の画像が要るのではなく、本体からタイトルを除く**点に注意（過去にここを取り違えた）。

## レイアウトの指針

- **図は右カラム**が既定。左に箇条書き、右に縦型フロー図・図版。下置きはデッキ制約の回避にすぎない。
- **箇条書きは詰め込みすぎない**。一行に説明を連結するより、第2階層のサブ箇条書き・第3階層のサブサブ・**ノーブレットの段落説明 (`.p1`/`.p2`)** に展開した方が読みやすく余白も埋まる。常にビュレットを付ける必要はない。
- 余白が余ったら、ページ番号や実装メタ等の**補足キャプションでなく内容 (サブ項目・サブサブ・段落説明・補足図) を増やす**。
- 配色は**暖色 (オレンジ＋マルーン) に統一**。同じデッキの一枚として馴染ませる。

## 実例 (worked examples)

`Templates/Slides/` の 2 つを複製して中身を差し替えるのが速い（各 `.html` の隣に同名 `.png` のレンダリング結果あり）:

- **`mathematica-style-twocolumn-slide.html`** — 左に箇条書き（b1 / b2 / **b3 サブサブ** / **p1 段落説明**を含む）、右に縦型フロー図 + 設計原則の**2段組**。Hiragino パレットの CSS 変数定義もここが基準。
- **`mathematica-style-bullets-levels.html`** — 参考デッキと同じ**単一カラム**で、b1 / b2 / **b3（グレー■のサブサブ）** / **段落説明（ノーブレット）** を一通り実演。階層と段落の使い分けの見本。

## 適用タイミング

- 「Mathematica スライドと連続表示して違和感がないスライド (画像) を作って」と言われたとき
- 既存の Mathematica プレゼンに差し込む 16:9 のスライド画像が要るとき
- 関連: フォント追従は `ui-output-font-customization`、保存先は `notebook-path-policy`
