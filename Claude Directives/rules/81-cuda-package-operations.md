# 81 — CUDA パッケージ操作制約

## 対象

`ClaudeCreatePackage` / `ClaudeUpdatePackage` で CUDA を使用するパッケージの作成・更新。

## CUDA 検出と cuda.wl 遅延ロード

- プロンプトに「CUDA」「GPU計算」「GPU並列」「CUDAを使用」「cuda kernel」「nvcc」等のキーワードが含まれると、自動的に CUDA モードが有効になる。
- 既存パッケージに `<パッケージ名>.cuda/` ディレクトリが存在する場合も自動検出する。
- CUDA モードでは `cuda.wl` が遅延ロードされる（`$packageDirectory` に配置が必要）。
- `cuda.wl` がロードできない場合、警告を表示し CUDA なしで続行する（純粋 Mathematica コードのみ生成）。

## ディレクトリ構造

CUDA コードおよびコンパイル済みバイナリは `<パッケージ名>.cuda/` に格納する:

```
$packageDirectory/
  MyPackage.wl           <- Mathematica ラッパーパッケージ
  MyPackage.cuda/
    src/                 <- .cu / .cuh ソースファイル
    bin/                 <- コンパイル済み共有ライブラリ (.dll/.so/.dylib)
  MyPackage_info/
    docs/                <- ドキュメント (通常と同じ)
    history/             <- バックアップ履歴 (通常と同じ)
```

## CUDA ソースの出力形式

LLM レスポンスで CUDA ソースファイルを出力する際は、パッケージコード（`===BEGIN_PACKAGE===`/`===END_PACKAGE===` または `===BEGIN_FUNCTIONS===`/`===END_FUNCTIONS===`）の**後に**、以下の形式で出力する:

```
===BEGIN_CUDA_FILE:kernels.cu===
#include <cuda_runtime.h>
#include "WolframLibrary.h"
...
===END_CUDA_FILE===
```

複数ファイルの場合は、各ファイルを個別のマーカーで囲む。

## Mathematica パッケージ (.wl) の要件

CUDA パッケージの .wl ファイルは以下を含むこと:

1. **CUDA ディレクトリパス変数**: `$<パッケージ名>CUDADir` を公開変数として定義。
2. **自動コンパイル**: パッケージロード時にバイナリが存在しない、またはソースより古い場合に自動コンパイル。
3. **nvcc 検索**: 一般的なパスおよび PATH から nvcc を検索。
4. **LibraryLink 連携**: `LibraryFunctionLoad` でコンパイル済みライブラリをロード。
5. **グレースフルフォールバック**: CUDA が利用できない場合の純粋 Mathematica 実装。

## コンパイル

- コンパイルは `nvcc --shared` で行う。
- WolframLibrary.h のインクルードパス: `$InstallationDirectory/SystemFiles/IncludeFiles/C`
- WolframRTL のライブラリパス: `$InstallationDirectory/SystemFiles/Libraries/$SystemID`
- Windows: `/utf-8` コンパイラオプションを追加。
- Linux/macOS: `-fPIC` オプションを追加。

## 必須ルール

1. CUDA ソースは必ず `.cuda/src/` に格納する。直接 `$packageDirectory` に置かない。
2. コンパイル済みバイナリは `.cuda/bin/` に格納する。
3. .cu ファイルの手動編集（Import/Export）は禁止。`ClaudeUpdatePackage` を使用する。
4. バックアップ時は `.cuda/src/` のソースファイルも含める。
5. パッケージは CUDA なしでも（制限付きで）動作するようフォールバックを実装する。

## cuda.wl の依存方向

`cuda.wl` は `ClaudeCode`` コンテキストを共有するが、claudecode.wl が cuda.wl に**静的に依存することはない**。cuda.wl は必要時にのみ遅延ロードされ、ロードできなくても claudecode.wl の既存機能は全て正常に動作する。
