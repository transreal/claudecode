---
name: jsonl-store-pattern
description: |
  Append-only JSONL ストア + 多重インデックス (master + by-X) の設計テンプレ。
  各 record を 1 行 1 JSON で書き、別軸 (topic / source / etc.) の jsonl ファイルに
  並行で重複 append する。Wolfram Language で書く時の Windows CRLF + UTF-8
  対応 (罠 #20)、安全な OpenAppend、頑健な ReadByteArray 読み込みを含む。
  SourceVault.wl Stage 5 ClaimStore で実装・実証済み。
---

# Append-Only JSONL + 多重インデックス パターン

## なぜ JSONL なのか

| 形式 | 追記 | 並行書込 | 部分読込 | dedup |
|---|---|---|---|---|
| 単一 JSON ファイル | 全読込・書込が必要 (重い) | 排他制御必要 | 不可 | 容易 |
| **JSONL (1 行 1 record)** | O(record size) で末尾追加 | OS の append が原子的 | tail/head/grep が使える | line-level でできる |
| SQLite / DB | 強力だが依存追加 | OK | 容易 | 容易 |

「append が支配的、検索は軽量、依存最小」のとき **JSONL が最適**。SourceVault Stage 5 の
claim store, log file, event store などに適する。

## ディレクトリレイアウト (3 重インデックス)

```
<storage-root>/
  master.jsonl                       # master (全 record、append-only)
  by-topic/
    topic-A.jsonl                    # topic-A の record だけ重複保存
    topic-B.jsonl
    ...
  by-source/
    src-X.jsonl                      # source-X 由来の record だけ
    src-Y.jsonl
    ...
```

**設計判断**: 1 record を append するときに **3 ファイルすべてに書く**。読み出しはどの軸からでも O(file size)。

- `master`: 全件取得用 (debug / 統計)
- `by-topic`: 主要な検索軸 (e.g. claim の topic、ログの category)
- `by-source`: 逆引き (どの source から何が抽出されたか)

容量は **3 倍**になるが、テキストなので問題にならない (claim 38 件で 55KB × 3 ≒ 165KB 程度)。

## パス計算 (Wolfram Language)

```mathematica
iStoreDir[] :=
  Module[{d},
    d = FileNameJoin[{<$StorageRoot>, "claims"}];
    iEnsureDir[d];
    iEnsureDir[FileNameJoin[{d, "by-topic"}]];
    iEnsureDir[FileNameJoin[{d, "by-source"}]];
    d
  ];

iMasterPath[] :=
  FileNameJoin[{iStoreDir[], "claims.jsonl"}];

iByTopicPath[topic_String] :=
  Module[{safe},
    safe = StringReplace[topic,
      RegularExpression["[^A-Za-z0-9_\\-]"] -> "_"];   (* ファイル名安全化 *)
    FileNameJoin[{iStoreDir[], "by-topic", safe <> ".jsonl"}]
  ];

iBySourcePath[sourceId_String] :=
  FileNameJoin[{iStoreDir[], "by-source", sourceId <> ".jsonl"}];
```

**ファイル名 sanitize は必須**: スラッシュ・空白・引用符等が topic に入ると Path injection か OS エラー。

## Append (書込)

```mathematica
iAppendJSONL[path_String, record_Association] :=
  Module[{sanitized, line, strm},
    sanitized = iSanitizeForJSON[record];                       (* JSON 互換型に変換 *)
    line = Quiet @ ExportString[sanitized, "RawJSON", "Compact" -> True];
    If[!StringQ[line],
      Return[<|"Status" -> "Failed",
        "Reason" -> "JSONEncodeFailed", "Path" -> path|>]];
    iEnsureDir[DirectoryName[path]];
    strm = Quiet[OpenAppend[path, BinaryFormat -> True]];
    If[Head[strm] =!= OutputStream,
      Return[<|"Status" -> "Failed",
        "Reason" -> "OpenAppendFailed", "Path" -> path|>]];
    (* 罠 #55: ExportString["RawJSON"] の戻りは codepoint = UTF-8 byte の
       Latin-1 表現なので ISO8859-1 で byte 化する。"UTF-8" だと二重 encode で
       日本語が化ける。読み取りは ByteArrayToString[..., "UTF-8"] と整合。 *)
    BinaryWrite[strm, StringToByteArray[line <> "\n", "ISO8859-1"]];
    Close[strm];
    <|"Status" -> "OK", "Path" -> path|>
  ];
```

**ポイント**:

1. **`iSanitizeForJSON` を必ず通す** — Missing[]・DateObject・Symbol 等を Null/文字列に
   (詳細は skill `llm-extraction-pipeline`)
2. **`Compact -> True`** — 1 行に収めるために必須
3. **`StringToByteArray[line, "ISO8859-1"]` で書く (罠 #55)** —
   `ExportString["RawJSON"]` の戻りは UTF-8 byte の Latin-1 表現。`"UTF-8"` で byte 化すると
   二重 encode で日本語が化ける。`ExportString[line, "Text", CharacterEncoding -> "UTF-8"]`
   や `WriteString` も同じ二重 encode / OS encoding 依存の危険があるので使わない。
   (`Developer`WriteRawJSONString` を使う場合のみ戻りが通常 Unicode なので "UTF-8" が正しい)
4. 戻り値は Association `<|"Status" -> "OK"|"Failed"|>` 形式 — エラーパスを呼出側で識別可能に

## Load (読込) — 罠 #20 対応

**重要**: 単純な `ReadList[path, "String", CharacterEncoding -> "UTF-8"]` は **Windows で
ファイルを書いた直後に空配列を返すことがある**(罠 #20)。代わりに **ReadByteArray パターン**:

```mathematica
iLoadJSONL[path_String] :=
  Module[{rawBytes, content, lines, parsed},
    If[!FileExistsQ[path], Return[{}]];
    (* バイナリ読み込み → UTF-8 デコード → 行分割 (Windows CRLF + UTF-8 マルチバイト対応) *)
    rawBytes = Quiet[ReadByteArray[path]];
    If[!ByteArrayQ[rawBytes], Return[{}]];
    content = Quiet[ByteArrayToString[rawBytes, "UTF-8"]];
    If[!StringQ[content], Return[{}]];
    lines = StringSplit[content, RegularExpression["\\r?\\n"]];
    lines = Select[lines, StringTrim[#] =!= "" &];
    parsed = Map[Function[ln,
      Module[{r = Quiet[ImportString[ln, "RawJSON"]]},
        If[ListQ[r] && !AssociationQ[r], r = Association[r]];
        If[AssociationQ[r], r, Missing["ParseFailed"]]]],
      lines];
    Select[parsed, AssociationQ]
  ];
```

これは claudecode.wl `iParseAnthropicBgResponse` の Windows 対策パターンと同じ。

## 検索 API のテンプレ

```mathematica
StoreGetById[id_String] :=
  Module[{all, hit},
    iEnsureRoots[];                              (* 初期化保険 *)
    all = iLoadJSONL[iMasterPath[]];
    SelectFirst[all,
      Lookup[#, "ClaimId", ""] === id &, Missing["NotFound"]]
  ];

StoreForTopic[topic_String] :=
  (iEnsureRoots[];
   iLoadJSONL[iByTopicPath[topic]]);

StoreForSource[sourceId_String] :=
  Module[{key, meta},
    iEnsureRoots[];
    key = If[StringStartsQ[sourceId, "snap-"],
      meta = iSnapshotMetaLoad[sourceId];
      If[AssociationQ[meta],
        Lookup[meta, "SourceId", sourceId], sourceId],
      sourceId];                                 (* snap → source 逆引き *)
    iLoadJSONL[iBySourcePath[key]]
  ];
```

**注意**:

1. **`iEnsureRoots[]` を必ず呼ぶ** — 別 entry point から呼ばれたとき $Roots が未初期化の可能性
2. **`SelectFirst[..., default]`** で `Missing["NotFound"]` を返す (`[[1]]` で例外発生しない)
3. **snapshot → source 逆引き** はオプション、SourceVault では meta から SourceId を取得

## Debug ヘルパ

ファイル存在と件数を即確認:

```mathematica
StoreStatus[] :=
  Module[{masterPath, masterLines, byTopicDir, bySourceDir},
    iEnsureRoots[];
    masterPath = iMasterPath[];
    masterLines = If[FileExistsQ[masterPath],
      Length[iLoadJSONL[masterPath]], 0];
    byTopicDir = FileNameJoin[{iStoreDir[], "by-topic"}];
    bySourceDir = FileNameJoin[{iStoreDir[], "by-source"}];
    <|
      "ClaimsDir" -> iStoreDir[],
      "MasterPath" -> masterPath,
      "MasterExists" -> FileExistsQ[masterPath],
      "MasterClaims" -> masterLines,
      "TopicFiles" -> If[DirectoryQ[byTopicDir],
        Map[FileNameTake, FileNames["*.jsonl", byTopicDir]], {}],
      "SourceFiles" -> If[DirectoryQ[bySourceDir],
        Map[FileNameTake, FileNames["*.jsonl", bySourceDir]], {}]
    |>
  ];
```

これで:

```mathematica
StoreStatus[]
(* <|
  "ClaimsDir" -> "C:\\Users\\...\\sourcevault\\claims",
  "MasterPath" -> "...\\claims.jsonl",
  "MasterExists" -> True,
  "MasterClaims" -> 38,        ← 読み込み成功すれば数値が出る
  "TopicFiles" -> {"transformer-test.jsonl"},
  "SourceFiles" -> {"src-arxiv-1706.03762.jsonl"}
|> *)
```

ファイルがあるのに件数が 0 → 罠 #20 や JSON 文法エラーを疑う。

## 呼出側: master + by-X 3 経路の atomic 風 append

```mathematica
Scan[Function[record,
  Module[{r},
    r = iAppendJSONL[iMasterPath[], record];
    If[!AssociationQ[r] || Lookup[r, "Status", ""] =!= "OK",
      AppendTo[errors, "Failed to append to master: " <>
        ToString[Lookup[r, "Reason", "Unknown"]]]];
    r = iAppendJSONL[iByTopicPath[topic], record];
    If[!AssociationQ[r] || Lookup[r, "Status", ""] =!= "OK",
      AppendTo[errors, "Failed to append to topic index: " <>
        ToString[Lookup[r, "Reason", "Unknown"]]]];
    If[StringQ[sourceId] && sourceId =!= "unknown",
      r = iAppendJSONL[iBySourcePath[sourceId], record];
      If[!AssociationQ[r] || Lookup[r, "Status", ""] =!= "OK",
        AppendTo[errors, "Failed to append to source index: " <>
          ToString[Lookup[r, "Reason", "Unknown"]]]]]
  ]],
  records];
```

**設計判断**:

- **atomic ではない** (3 ファイル独立 append) — 1 つ失敗しても他は記録される、データ損失より整合性壊しを許容
- **ErrorReason を理由つきで集約** — どこで何が起きたか後追い可能
- **`sourceId == "unknown"` は by-source をスキップ** — source 不明な record (e.g. manually 入力) でも store できる

完全 atomic が必要なら master のみ書き込み、by-X は定期的に re-build する設計に。

## dedup (将来拡張)

各 record に `ContentHash` フィールド (subject/predicate/object/source の SHA-256)
を計算しておく:

```mathematica
iComputeContentHash[record_Association] :=
  Module[{key, sanitized, ser, hash},
    key = <|"Subject" -> Lookup[record, "Subject", ""],
            "Predicate" -> Lookup[record, "Predicate", ""],
            "Object" -> Lookup[record, "Object", Null],
            "SourceSpan" -> Lookup[record, "SourceSpan", <||>]|>;
    sanitized = iSanitizeForJSON[key];
    ser = Quiet @ ExportString[sanitized, "RawJSON", "Compact" -> True];
    If[!StringQ[ser], Return[""]];
    hash = iComputeSHA256[ser];
    If[StringQ[hash], "sha256-" <> hash, ""]
  ];
```

将来 dedup を入れる時:

1. master を全 load → 既存の ContentHash set を構築
2. 新規 record の ContentHash が既存に含まれていれば skip
3. or 定期的に **master を再書き出し** して重複を除去

現状 (Stage 5) は dedup なし、`ContentHash` だけ計算済み。

## 適用タイミング

- 大量追記が予想される構造化 record store: JSONL を最初の選択肢に
- 複数の検索軸が必要: 3 重インデックスを採用
- Windows 環境で書き込み → 読み込みする: ReadByteArray パターンが必須 (罠 #20)
- Wolfram で書き込み + 別ツール (jq, Python) で読み込みたい: BinaryFormat + UTF-8 で
  互換性確保 (BOM が入らない)

## 関連

- skill `llm-extraction-pipeline`: claim を生成して JSONL に保存
- skill `wolfram-syntax-pitfalls`: 罠 #20 (Windows JSONL ReadList → ReadByteArray)
- SourceVault.wl Stage 5 (v2026-05-19-stage-5-claim-retrieval-fix) で 38 claim × 3 ファイル = 165KB を実証
