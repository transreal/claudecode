If[StringQ[$InputFileName] && $InputFileName =!= "",
  $packageDirectory = DirectoryName[$InputFileName],
  If[!ValueQ[$packageDirectory] || $packageDirectory === "",
    $packageDirectory = Directory[] <> $PathnameSeparator
  ]
];
BeginPackage["ClaudeCode`"];

(* パッケージリロード時に古い内部関数定義が残らないよう、
   変更された主要内部関数をクリアする *)
Quiet[ClearAll[
  iEnsureDefaultSession, iResolveNotebookFiles, iCollectAccessibleDirs,
  iCLIPermissionFlags, iFileAccessContext, iNeedsFileList, iSafeReadStreamFile,
  iUpdateStreamProgress, iExtractResultFromStreamJson,
  iAskDirPermission, iEnsureDirPermission, iIsSafeDefaultDir,
  iGetDirPermission, iSetDirPermission,
  iResolveWebFetch, iResolveWebFetchWithFallback,
  iWriteQueryResponse, iFlushQueryTextBuf, iSaveDocOptions, iLoadAndMergeDocOptions,
  iDocGet, iDocInitState, iDocBuildRefSection, iDocGlobalInstructionPrompt,
  iDocBuildAcknowledgmentsPrompt, iDocBuildDisclaimerPrompt, iDocBuildLicensePrompt,
  ClaudePrepareCommit, iCollectChangeSummaries, iFormatCommitMessage, iWrapCommitBodyLines
]];

(* NBAccess \:30d1\:30c3\:30b1\:30fc\:30b8\:3092\:30ed\:30fc\:30c9 (\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:8aad\:307f\:66f8\:304d\:30fb\:30d7\:30e9\:30a4\:30d0\:30b7\:30fc\:7ba1\:7406) *)
(* NBAccess パッケージをロード (ShiftJIS 環境でも UTF-8 で読み込む) *)
Block[{$CharacterEncoding = "UTF-8"},
  Needs["NBAccess`","NBAccess.wl"]];

(* GitHubREST パッケージをロード (GitHubPackageURL 等を利用) *)
Block[{$CharacterEncoding = "UTF-8"},
  Quiet @ Needs["GitHubREST`", "github.wl"]];

Scan[
  Function[name,
    If[MemberQ[Names["Global`" <> name], "Global`" <> name],
      Remove["Global`" <> name]]],
  {"ClaudeQuery","ClaudeMath","ClaudeExtractCode","ClaudeExtractAllCode",
   "ClaudeEval","ContinueEval","ContinueUpdate","ClaudeSpec","ClaudeDebug","ClaudeReview","ClaudeReviewChunked",
   "ClaudeUpdatePackage","ClaudeRestorePackage","ClaudeUpdatePackageHistory","ClaudeBackupDataset",
   "ClaudeConvertToPaclet","ClaudeCreateDocumentation","ClaudeUpdateDocumentation",
   "ClaudeMigrateBackupHistory",
   "ClaudeAddDirective","ClaudeRestoreDirective","ClaudeListDirectives",
   "ClaudeUpdateDirective","ClaudeDirectiveBackupDataset","ClaudeSyncDirectives",
   "CreateClaudeSession","ClaudeRestoreSession","Inherit",
   "ClaudeListSessions","ClaudeDeleteSession","ClaudeShowHistory",
   "ClaudeAttach","ClaudeDetach","ClaudeAttachments","ClearAttachments",
   "MarkConfidential","UnmarkConfidential","IsConfidential","Confidential","NonConfidential",
   "ScanConfidentialCells","ShowClaudePalette","ClaudeQueryShowContext",
   "ClaudeShowAccessConfig","ClaudeSessionStatus","ClaudeCompactHistory","ClaudeHistorySize",
   "ClaudeWebSearch","ClaudeWebFetch","WebFetch","WebSearch",
   "ClaudeCommand","ClaudeCheckSeparation","ClaudeFixSeparation","ClaudeStatus",
   "ClaudePrepareCommit",
   "$ClaudeTimeout", "$ClaudeMDPath", "$ClaudeMDContent", "$ClaudeModel",
   "$ClaudeTestModel",
   "$ClaudeFallbackModels", "$ClaudeWorkingDirectory", "$ClaudeAccessibleDirs",
   "$ClaudeDocRetryDelay", "$ClaudeDocMaxRetries", "$ClaudeDocMaxChunkChars",
   "$ClaudeDocModel",
   "$ClaudePrivateModel",
   "$ClaudePackageKeywordMap",
   "Fallback", "AutoPrivate", "References", "Demos", "Disclaimer", "Acknowledgments"}
];

ClaudeSpec::usage =
  "ClaudeSpec[\"task\"] \:306f\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:5185\:5bb9\:304b\:3089\:30d7\:30ed\:30b0\:30e9\:30e0\:306e\:4ed5\:69d8\:3092\:751f\:6210\:3059\:308b\:3002\n" <>
  "ClaudeSpec[{\"task\", image, ...}] \:306f\:753b\:50cf\:4ed8\:304d\:3067\:4ed5\:69d8\:3092\:751f\:6210\:3002\n" <>
  "\:30d1\:30ec\:30c3\:30c8\:304b\:3089\:306f\:30bb\:30eb\:9078\:629e\:3067\:547c\:3073\:51fa\:3057\:53ef\:80fd\:3002";

$ClaudeModel::usage =
  "$ClaudeModel \:306f Claude CLI \:306b\:6e21\:3059\:30e2\:30c7\:30eb\:540d\:3002\n"
  "\:4f8b: $ClaudeModel = \"claude-opus-4-6\"; (* \:30c7\:30d5\:30a9\:30eb\:30c8: \"\" \:306f\:7701\:7565\:6642 Claude Code \:81ea\:8eab\:306e\:30c7\:30d5\:30a9\:30eb\:30c8\:30e2\:30c7\:30eb *)";

$ClaudePrivateModel::usage =
  "$ClaudePrivateModel \:306f\:79d8\:5bc6\:30c7\:30fc\:30bf\:51e6\:7406\:7528\:306e\:30ed\:30fc\:30ab\:30eb\:30e2\:30c7\:30eb\:6307\:5b9a\:3002\n" <>
  "AutoPrivate -> True \:6642\:306b\:79d8\:5bc6\:5909\:6570\:3092\:542b\:3080\:30bf\:30b9\:30af\:306e\:751f\:6210\:30b3\:30fc\:30c9\:306b\:4f7f\:7528\:3055\:308c\:308b\:3002\n" <>
  "\:4f8b: $ClaudePrivateModel = {\"lmstudio\", \"openai/gpt-oss-20b\", \"http://127.0.0.1:1234\"}";

$ClaudePackageKeywordMap::usage =
  "$ClaudePackageKeywordMap \:306f\:5916\:90e8\:30d1\:30c3\:30b1\:30fc\:30b8\:304c\:30ad\:30fc\:30ef\:30fc\:30c9\:3092\:767b\:9332\:3059\:308b\:305f\:3081\:306e Association\:3002\n" <>
  "\:30d7\:30ed\:30f3\:30d7\:30c8\:306b\:30ad\:30fc\:30ef\:30fc\:30c9\:304c\:542b\:307e\:308c\:308b\:3068\:3001\:5bfe\:5fdc\:30d1\:30c3\:30b1\:30fc\:30b8\:306e api.md \:304c\:30b3\:30f3\:30c6\:30ad\:30b9\:30c8\:306b\:81ea\:52d5\:6ce8\:5165\:3055\:308c\:308b\:3002\n" <>
  "\:5404\:30d1\:30c3\:30b1\:30fc\:30b8\:304c\:81ea\:8eab\:306e\:30ed\:30fc\:30c9\:6642\:306b\:767b\:9332\:3059\:308b\:3002claudecode.wl \:5074\:306f\:30d1\:30c3\:30b1\:30fc\:30b8\:975e\:4f9d\:5b58\:3002\n" <>
  "\:4f8b: $ClaudePackageKeywordMap[\"maildb\"] = {\"\\:30e1\\:30fc\\:30eb\", \"mail\", \"\\:3012\\:5207\"};";
  "AutoPrivate \:306f ClaudeQuery/ClaudeEval/ContinueEval \:306e\:30aa\:30d7\:30b7\:30e7\:30f3\:3002\n" <>
  "True: \:79d8\:5bc6\:5909\:6570\:306b\:30a2\:30af\:30bb\:30b9\:3059\:308b\:30bf\:30b9\:30af\:306e\:5834\:5408\:3001\:751f\:6210\:30b3\:30fc\:30c9\:306b\n" <>
  "  Model -> $ClaudePrivateModel, PrivacySpec -> Automatic \:3092\:4ed8\:4e0e\:3059\:308b\:3002\n" <>
  "False (\:30c7\:30d5\:30a9\:30eb\:30c8): \:901a\:5e38\:52d5\:4f5c\:3002";
$ClaudeTimeout::usage =
  "$ClaudeTimeout \:306f ClaudeQuery\:30fbClaudeEval \:7b49\:306e\:30bf\:30a4\:30e0\:30a2\:30a6\:30c8\:79d2\:6570\:3002\:30c7\:30d5\:30a9\:30eb\:30c8 1200\:3002\n" <>
  "\:4f8b: $ClaudeTimeout = 900";
$ClaudeWorkingDirectory::usage =
  "$ClaudeWorkingDirectory は Claude Code を起動する作業ディレクトリ。デフォルトは FileNameJoin[{$HomeDirectory, \"Claude Working\"}]。\n" <>
  "このディレクトリ配下の .claude/CLAUDE.md, .claude/rules/, .claude/skills/ を Claude Code に読ませる。";

$ClaudeMDPath::usage =
  "$ClaudeMDPath \\:306f\\:8aad\\:307f\\:8fbc\:307e\:308c\\:308b CLAUDE.md \\:306e\\:30d1\\:30b9\\:3002\n" <>
  "\\:81ea\\:52d5\\:691c\\:7d22\:3055\:308c\\:308b\\:304b\\:3001\\:624b\\:52d5\:3067\\:4e0a\\:66f8\\:304d\:3067\\:304d\\:308b\\:3002\n" <>
  "\\:4f8b: $ClaudeMDPath = \"C:\\\\proj\\\\CLAUDE.md\"";
$ClaudeMDContent::usage =
  "$ClaudeMDContent \\:306f\\:8aad\\:307f\\:8fbc\:307e\:308c\:305f CLAUDE.md \\:306e\\:5185\\:5bb9\\:3002\n" <>
  "\\:5185\\:5bb9\:304c\\:7a7a\\:306e\\:5834\:5408\\:3001CLAUDE.md \:304c\\:898b\\:3064\\:304b\\:3089\\:306a\\:304b\\:3063\:305f\\:304b\\:5185\\:5bb9\:304c\\:306a\:3044\\:3002";

$ClaudeMDPath    = "";
$ClaudeMDContent = "";
$ClaudeWorkingDirectory = FileNameJoin[{$HomeDirectory, "Claude Working"}];

$ClaudeAccessibleDirs::usage =
  "$ClaudeAccessibleDirs \:306f Claude Code \:306b Read \:8a31\:53ef\:3059\:308b\:8ffd\:52a0\:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:30ea\:30b9\:30c8\:3002\n" <>
  "iPrepareClaudeProjectDirectory \:304c\:4e00\:6642 settings.json \:306b Read \:8a31\:53ef\:3092\:6ce8\:5165\:3059\:308b\:3002\n" <>
  "\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:306e TaggingRules \:306b\:3082 NBSetAccessibleDirs \:3067\:6c38\:7d9a\:5316\:53ef\:80fd\:3002\n" <>
  "\:30c7\:30d5\:30a9\:30eb\:30c8: {$packageDirectory}\:3002\n" <>
  "NotebookDirectory \:306f\:521d\:56de\:4f7f\:7528\:6642\:306b\:30c0\:30a4\:30a2\:30ed\:30b0\:3067\:8a31\:53ef\:3092\:78ba\:8a8d ($packageDirectory \:914d\:4e0b\:3092\:9664\:304f)\:3002\n" <>
  "\:4f8b: $ClaudeAccessibleDirs = {$packageDirectory, \"F:\\\\Dropbox\\\\Mathematica-oneDrive\"}";

If[!ListQ[$ClaudeAccessibleDirs],
  $ClaudeAccessibleDirs = Select[{Global`$packageDirectory},
    StringQ[#] && StringLength[#] > 0 &],
  (* 既にリストの場合でも $packageDirectory がロード後に設定されていれば追加 *)
  If[StringQ[Global`$packageDirectory] && StringLength[Global`$packageDirectory] > 0 &&
     !MemberQ[$ClaudeAccessibleDirs, Global`$packageDirectory],
    AppendTo[$ClaudeAccessibleDirs, Global`$packageDirectory]]];

(* ============================================================
   ディレクトリアクセス許可システム
   NotebookDirectory が $packageDirectory や $ClaudeWorkingDirectory と
   異なる場合、ユーザーに許可を求めるダイアログを表示する。
   許可結果はノートブックの TaggingRules に永続化される。
   ============================================================ *)

(* セッション内キャッシュ: 同じディレクトリについて再度ダイアログを出さない *)
$iDirPermissionCache = <||>;

(* パッケージ別ドキュメントオプション状態。
   キー: packageName, 値: <|"References"->..., "Demos"->..., ...|
   非同期ドキュメント生成中にグローバル変数がリセットされる問題を防ぐ。 *)
$iDocState = <||>;

(* 安全なデフォルトディレクトリか判定。
   $packageDirectory またはその親、
   $ClaudeWorkingDirectory またはその親に含まれるなら安全。 *)
iIsSafeDefaultDir[dir_String] := Module[{normDir, safeDirs},
  normDir = StringReplace[dir, "\\" -> "/"];
  safeDirs = Select[{
    Global`$packageDirectory,
    $ClaudeWorkingDirectory,
    iClaudeWorkingDirectory[]
  }, StringQ[#] && StringLength[#] > 0 &];
  safeDirs = StringReplace[#, "\\" -> "/"] & /@ safeDirs;
  AnyTrue[safeDirs,
    StringStartsQ[normDir, #] || StringStartsQ[#, normDir] &]
];

(* TaggingRules からディレクトリ許可設定を取得。
   戻り値: "read" | "denied" | None
   後方互換: 旧バージョンで保存された "readwrite" も "read" と同等に扱う *)
iGetDirPermission[nb_NotebookObject, dir_String] :=
  Module[{perms},
    perms = Quiet @ NBAccess`NBGetTaggingRule[nb, "claudeDirPermissions"];
    If[AssociationQ[perms], Lookup[perms, dir, None], None]
  ];

(* TaggingRules にディレクトリ許可設定を保存 *)
iSetDirPermission[nb_NotebookObject, dir_String, perm_String] :=
  Module[{perms},
    perms = Quiet @ NBAccess`NBGetTaggingRule[nb, "claudeDirPermissions"];
    If[!AssociationQ[perms], perms = <||>];
    perms[dir] = perm;
    Quiet @ NBAccess`NBSetTaggingRule[nb, "claudeDirPermissions", perms]
  ];

(* ユーザーに許可を求めるダイアログ。
   戻り値: "read" | "denied"
   注: Claude Code CLI の --print モードでは Write ツールは使用不可のため、
   Read 許可と不許可の2択のみ提示する。 *)
iAskDirPermission[nb_NotebookObject, dir_String] :=
  Module[{shortDir, dialog},
    shortDir = If[StringLength[dir] > 50,
      "\:2026" <> StringTake[dir, -45], dir];
    dialog = DialogInput[
      Pane[
        Column[{
          Style["\:30d5\:30a1\:30a4\:30eb\:306e\:8aad\:307f\:53d6\:308a\:3092\:8a31\:53ef\:3057\:307e\:3059\:304b\:ff1f", Bold, 11],
          Style[shortDir, FontSize -> 9, FontColor -> GrayLevel[0.4]],
          Spacer[1],
          Row[{
            Button["\:8a31\:53ef", DialogReturn["read"],
              ImageSize -> {60, 25}],
            Spacer[6],
            Button["\:62d2\:5426", DialogReturn["denied"],
              ImageSize -> {60, 25}]
          }]
        }, Spacings -> 0.2],
        ImageSize -> {260, Automatic},
        ImageSizeAction -> "ShrinkToFit"
      ],
      WindowTitle -> "Claude Code",
      WindowMargins -> Automatic
    ];
    If[StringQ[dialog], dialog, "denied"]
  ];

(* ディレクトリの許可を確認し、必要ならダイアログを表示。
   戻り値: True（アクセス許可）/ False（不許可）
   副作用: 許可された場合 $ClaudeAccessibleDirs に追加し TaggingRules に保存 *)
iEnsureDirPermission[nb_NotebookObject, dir_String] :=
  Module[{perm},
    (* 安全なデフォルトディレクトリならダイアログ不要 *)
    If[iIsSafeDefaultDir[dir], Return[True]];
    (* セッション内キャッシュをチェック *)
    If[KeyExistsQ[$iDirPermissionCache, dir],
      Return[$iDirPermissionCache[dir] =!= "denied"]];
    (* TaggingRules に保存済みの許可を確認 *)
    perm = iGetDirPermission[nb, dir];
    If[StringQ[perm],
      $iDirPermissionCache[dir] = perm;
      If[perm =!= "denied",
        $ClaudeAccessibleDirs = DeleteDuplicates[
          Append[If[ListQ[$ClaudeAccessibleDirs], $ClaudeAccessibleDirs, {}], dir]]];
      Return[perm =!= "denied"]];
    (* ダイアログを表示して許可を求める *)
    perm = iAskDirPermission[nb, dir];
    $iDirPermissionCache[dir] = perm;
    iSetDirPermission[nb, dir, perm];
    If[perm =!= "denied",
      $ClaudeAccessibleDirs = DeleteDuplicates[
        Append[If[ListQ[$ClaudeAccessibleDirs], $ClaudeAccessibleDirs, {}], dir]];
      (* TaggingRules のアクセス可能ディレクトリにも追加 *)
      Module[{currentDirs = Quiet @ NBAccess`NBGetAccessibleDirs[nb]},
        If[!ListQ[currentDirs], currentDirs = {}];
        Quiet @ NBAccess`NBSetAccessibleDirs[nb,
          DeleteDuplicates[Append[currentDirs, dir]]]]];
    perm =!= "denied"
  ];

$ClaudeFallbackModels::usage =
  "$ClaudeFallbackModels \:306f\:30d5\:30a9\:30fc\:30eb\:30d0\:30c3\:30af\:30e2\:30c7\:30eb\:512a\:5148\:9806\:4f4d\:3002\n" <>
  "\:5404\:8981\:7d20\:306f {\"provider\", \"modelName\"} \:307e\:305f\:306f {\"provider\", \"modelName\", \"url\"} \:306e\:5f62\:5f0f\:3002\n" <>
  "\:5185\:90e8\:7684\:306b\:306f NBAccess`NBSetFallbackModels \:306b\:540c\:671f\:3055\:308c\:308b\:3002\n" <>
  "\:4f8b: $ClaudeFallbackModels = {{\"anthropic\",\"claude-opus-4-6\"},{\"lmstudio\",\"gpt-oss-20b\",\"http://127.0.0.1:1234\"}}";

Fallback::usage =
  "Fallback \:306f ClaudeQuery/ClaudeEval/ContinueEval \:306e\:30aa\:30d7\:30b7\:30e7\:30f3\:3002\n" <>
  "True: Claude Code \:5229\:7528\:4e0d\:53ef\:6642\:306b\:30d5\:30a9\:30fc\:30eb\:30d0\:30c3\:30af\:30e2\:30c7\:30eb\:306b\:81ea\:52d5\:5207\:66ff\:3002\n" <>
  "\:30a2\:30af\:30bb\:30b9\:30ec\:30d9\:30eb\:306b\:5fdc\:3058\:3066\:5229\:7528\:53ef\:80fd\:306a\:30e2\:30c7\:30eb\:306e\:307f\:306b\:30d5\:30a9\:30fc\:30eb\:30d0\:30c3\:30af\:3059\:308b\:3002\n" <>
  "False (\:30c7\:30d5\:30a9\:30eb\:30c8): \:30a8\:30e9\:30fc\:3092\:305d\:306e\:307e\:307e\:8fd4\:3059\:3002";

$ClaudeDocRetryDelay::usage =
  "$ClaudeDocRetryDelay \:306f\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:751f\:6210\:306e\:30ea\:30c8\:30e9\:30a4\:5f85\:6a5f\:79d2\:6570\:3002\:30c7\:30d5\:30a9\:30eb\:30c8 60\:3002";
$ClaudeDocMaxRetries::usage =
  "$ClaudeDocMaxRetries \:306f\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:751f\:6210\:306e\:6700\:5927\:30ea\:30c8\:30e9\:30a4\:56de\:6570\:3002\:30c7\:30d5\:30a9\:30eb\:30c8 3\:3002";
$ClaudeDocMaxChunkChars::usage =
  "$ClaudeDocMaxChunkChars \:306f\:30d7\:30ed\:30f3\:30d7\:30c8\:4e2d\:30bd\:30fc\:30b9\:306e\:6700\:5927\:6587\:5b57\:6570\:3002\:30c7\:30d5\:30a9\:30eb\:30c8 60000\:3002";

References::usage =
  "References \:306f ClaudeCreateDocumentation/ClaudeUpdateDocumentation \:306e\:30aa\:30d7\:30b7\:30e7\:30f3\:3002\n" <>
  "URL \:3084\:66f8\:7c4d\:540d\:306e\:30ea\:30b9\:30c8\:3092\:6307\:5b9a\:3059\:308b\:3068 README.md \:306b\:53c2\:8003\:6587\:732e\:30bb\:30af\:30b7\:30e7\:30f3\:3092\:8ffd\:52a0\:3002\n" <>
  "\:4f8b: References -> {\"https://...\", \"\:66f8\:7c4d\:540d\"}";
Demos::usage =
  "Demos \:306f ClaudeCreateDocumentation/ClaudeUpdateDocumentation \:306e\:30aa\:30d7\:30b7\:30e7\:30f3\:3002\n" <>
  "\:30c7\:30e2\:52d5\:753b\:3084\:4f7f\:7528\:4f8b\:306e URL \:30ea\:30b9\:30c8\:3092\:6307\:5b9a\:3059\:308b\:3068 README.md \:306b\:53cd\:6620\:3002\n" <>
  "\:4f8b: Demos -> {\"https://youtu.be/...\", \"https://example.com/demo.nb\"}";
Disclaimer::usage =
  "Disclaimer \:306f ClaudeCreateDocumentation/ClaudeUpdateDocumentation \:306e\:30aa\:30d7\:30b7\:30e7\:30f3\:3002\n" <>
  "\:514d\:8cac\:4e8b\:9805\:30bb\:30af\:30b7\:30e7\:30f3\:306b\:8ffd\:52a0\:3059\:308b\:6587\:8a00\:306e\:30ea\:30b9\:30c8\:3092\:6307\:5b9a\:3002\n" <>
  "\:4f8b: Disclaimer -> {\"\:672c\:30c4\:30fc\:30eb\:306f\:7814\:7a76\:76ee\:7684\:5c02\:7528\:3067\:3059\"}";
License::usage =
  "License \:306f ClaudeCreateDocumentation/ClaudeUpdateDocumentation \:306e\:30aa\:30d7\:30b7\:30e7\:30f3\:3002\n" <>
  "\:7a7a\:6587\:5b57\:5217(\\:30c7\\:30d5\\:30a9\\:30eb\\:30c8): GitHubREST`$GitHubLicenseHolder \\:304c\\:975e\\:7a7a\\:306a\\:3089 MIT \\:30e9\\:30a4\\:30bb\\:30f3\\:30b9\\:3092\\:81ea\\:52d5\\:633f\\:5165\\:3002\n" <>
  "\:6587\:5b57\:5217\:6307\:5b9a: \:305d\:306e\:307e\:307e\:30e9\:30a4\:30bb\:30f3\:30b9\:30c6\:30ad\:30b9\:30c8\:3068\:3057\:3066\:633f\:5165\:3002\n" <>
  "\:4f8b: License -> \"MIT\", License -> \"Apache-2.0 License...\"";
Acknowledgments::usage =
  "Acknowledgments \:306f ClaudeCreateDocumentation/ClaudeUpdateDocumentation \:306e\:30aa\:30d7\:30b7\:30e7\:30f3\:3002\n" <>
  "\:8b1d\:8f9e\:30bb\:30af\:30b7\:30e7\:30f3\:306b\:8ffd\:52a0\:3059\:308b\:6587\:8a00\:306e\:30ea\:30b9\:30c8\:3092\:6307\:5b9a\:3002\:6307\:5b9a\:6642\:306f README.md \:306e\:514d\:8cac\:4e8b\:9805\:306e\:524d\:306b\:914d\:7f6e\:3002\n" <>
  "\:4f8b: Acknowledgments -> {\"\:672c\:7814\:7a76\:306f JSPS \:79d1\:7814\:8cbb\:306e\:52a9\:6210\:3092\:53d7\:3051\:305f\"}";


If[!ListQ[$ClaudeFallbackModels],
  $ClaudeFallbackModels = {{"anthropic", "claude-opus-4-6"}, {"openai", "gpt-5"}}];

(* $ClaudeFallbackModels を NBAccess に同期 *)
iSyncFallbackModelsToNBAccess[] :=
  If[ListQ[$ClaudeFallbackModels],
    NBAccess`NBSetFallbackModels[$ClaudeFallbackModels]];

(* パッケージロード時に同期 *)
iSyncFallbackModelsToNBAccess[];

If[!NumericQ[$ClaudeDocRetryDelay], $ClaudeDocRetryDelay = 60];
If[!IntegerQ[$ClaudeDocMaxRetries], $ClaudeDocMaxRetries = 3];
If[!IntegerQ[$ClaudeDocMaxChunkChars], $ClaudeDocMaxChunkChars = 60000];

$ClaudeDocModel::usage =
  "$ClaudeDocModel \:306f\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:751f\:6210\:30fb\:66f4\:65b0\:6642\:306b\:4f7f\:7528\:3059\:308b\:30e2\:30c7\:30eb\:3002\n" <>
  "\:30c7\:30d5\:30a9\:30eb\:30c8: \"claude-sonnet-4-20250514\" (Sonnet \:30af\:30e9\:30b9\:3067\:5341\:5206\:304b\:3064\:5b89\:4fa1)\:3002\n" <>
  "\"\" \:3067 $ClaudeModel \:3068\:540c\:3058\:30e2\:30c7\:30eb\:3092\:4f7f\:7528\:3002\n" <>
  "\:4f8b: $ClaudeDocModel = \"claude-sonnet-4-20250514\"";
If[!StringQ[$ClaudeDocModel], $ClaudeDocModel = "claude-sonnet-4-20250514"];

$ClaudeEvalMaxDepth::usage =
  "$ClaudeEvalMaxDepth \:306f ClaudeEval \:304c\:518d\:5e30\:7684\:306b ClaudeEval \:3092\:751f\:6210\:3059\:308b\:969b\:306e\:6700\:5927\:6df1\:5ea6\:3002\:30c7\:30d5\:30a9\:30eb\:30c8 5\:3002\n" <>
  "ClaudeEval \:304c\:30b3\:30fc\:30c9\:5185\:3067\:3055\:3089\:306b ClaudeEval/ContinueEval \:3092\:751f\:6210\:3059\:308b\:9023\:9396\:547c\:3073\:51fa\:3057\:306e\:4e0a\:9650\:3002\n" <>
  "0 \:3067\:518d\:5e30\:7981\:6b62\:3002\:5024\:3092\:5927\:304d\:304f\:3059\:308b\:3068\:591a\:6bb5\:968e\:306e\:81ea\:52d5\:30bf\:30b9\:30af\:9023\:9396\:304c\:53ef\:80fd\:3002";
If[!IntegerQ[$ClaudeEvalMaxDepth], $ClaudeEvalMaxDepth = 5];
$iClaudeEvalCurrentDepth = 0;

(* パッケージ操作の排他ロック: 同一パッケージへの並列更新を防止
   <|"packageName" -> True, ...|> の形式で更新中のパッケージを追跡 *)
$iPackageUpdateLocks = <||>;

iAcquirePackageLock[packageName_String, nb_NotebookObject] :=
  If[TrueQ[$iPackageUpdateLocks[packageName]],
    nbPrint[nb, "\:26a0\:fe0f " <> packageName <>
      " \:306f\:73fe\:5728\:66f4\:65b0\:4e2d\:3067\:3059\:3002\:524d\:306e\:66f4\:65b0\:304c\:5b8c\:4e86\:3057\:3066\:304b\:3089\:518d\:5b9f\:884c\:3057\:3066\:304f\:3060\:3055\:3044\:3002"];
    False,
    $iPackageUpdateLocks[packageName] = True;
    True
  ];

iReleasePackageLock[packageName_String] :=
  ($iPackageUpdateLocks = KeyDrop[$iPackageUpdateLocks, packageName]);

(* 分離検証用モデル: デフォルトは $ClaudeModel と同じ *)
If[!StringQ[$ClaudeTestModel],
  $ClaudeTestModel = $ClaudeModel];

(* 分離検証キャッシュ: ClaudeCheckSeparation の結果を保持し ClaudeFixSeparation で再利用 *)
$iSeparationCheckCache = <||>;

(* \:975e\:540c\:671f\:30d1\:30b9\:306e\:30d5\:30a9\:30fc\:30eb\:30d0\:30c3\:30af\:5236\:5fa1\:7528\:30b0\:30ed\:30fc\:30d0\:30eb\:30d5\:30e9\:30b0 *)
$currentUseFallback = False;

(* Claude Code CLI \:306e Web \:691c\:7d22\:30c4\:30fc\:30eb\:8a31\:53ef\:30d5\:30e9\:30b0 *)
$iAllowWebSearch = True;

(* \:5b9f\:884c\:30bb\:30eb\:306e\:76f4\:5f8c\:306b\:30a2\:30f3\:30ab\:30fc\:3092\:914d\:7f6e\:3059\:308b\:305f\:3081\:306e\:30b0\:30ed\:30fc\:30d0\:30eb\:5909\:6570 *)


ClaudeQuery::usage =
  "ClaudeQuery[prompt] \:306f Claude Code \:306b prompt \:3092\:9001\:308a\:3001\:5fdc\:7b54\:6587\:5b57\:5217\:3092\:8fd4\:3059\:ff08\:540c\:671f\:ff09\:3002\n" <>
  "ClaudeQuery[session, prompt] \:306f\:30bb\:30c3\:30b7\:30e7\:30f3\:5c65\:6b74\:3068\:76f4\:524d\:306e\:51fa\:529b/\:30a8\:30e9\:30fc\:3092\:8003\:616e\:3057\:3066\:56de\:7b54\:3059\:308b\:3002\n" <>
  "Options: WebSearch->True(\:30c7\:30d5\:30a9\:30eb\:30c8,\:7121\:6599), WebFetch->False(\:8ab2\:91d1\:3042\:308a,Fallback->True\:5fc5\:9808), Fallback";ClaudeMath::usage =
  "ClaudeMath[task] \:306f Mathematica \:30b3\:30fc\:30c9\:751f\:6210\:306b\:7279\:5316\:3057\:305f\:30d7\:30ed\:30f3\:30d7\:30c8\:3067 Claude \:3092\:547c\:3073\:51fa\:3059\:3002";ClaudeExtractCode::usage =
  "ClaudeExtractCode[response] \:306f Claude \:306e\:5fdc\:7b54\:304b\:3089\:6700\:521d\:306e ```mathematica \:30d6\:30ed\:30c3\:30af\:3092\:62bd\:51fa\:3059\:308b\:3002";ClaudeExtractAllCode::usage =
  "ClaudeExtractAllCode[response] \:306f Claude \:306e\:5fdc\:7b54\:304b\:3089\:5168 ```mathematica \:30d6\:30ed\:30c3\:30af\:3092\:30ea\:30b9\:30c8\:3067\:8fd4\:3059\:3002";ClaudeEval::usage =
  "ClaudeEval[task] \:306f\:30b3\:30fc\:30c9\:3092\:975e\:540c\:671f\:3067\:751f\:6210\:30fb\:8868\:793a\:3057\:3001\:30c7\:30d5\:30a9\:30eb\:30c8\:30bb\:30c3\:30b7\:30e7\:30f3\:306b\:5c65\:6b74\:3092\:4fdd\:5b58\:3059\:308b\:3002\n" <>
  "ClaudeEval[{text, data, ...}] \:306f\:30c6\:30ad\:30b9\:30c8\:3001Dataset\:3001Image\:3001\:4e00\:822c\:5f0f\:3092\:6df7\:5728\:3067\:304d\:308b\:3002\n" <>
  "ClaudeEval[session, task] \:306f\:6307\:5b9a\:30bb\:30c3\:30b7\:30e7\:30f3\:306b\:5c65\:6b74\:3092\:4fdd\:5b58\:3059\:308b\:3002
" <>
  "Option AutoEvaluate -> True|False \:3067\:751f\:6210\:3055\:308c\:305f Input \:30bb\:30eb\:306e\:81ea\:52d5\:5b9f\:884c\:3092\:5236\:5fa1\:3059\:308b\:ff08\:30c7\:30d5\:30a9\:30eb\:30c8 True\:ff09\:3002\n" <>
  "Option StartTime -> Now \:3067\:5b9f\:884c\:958b\:59cb\:6642\:523b\:3092 DateObject \:3067\:6307\:5b9a\:3002\:4f8b: StartTime -> Now + Quantity[3, \"Hours\"]\:3002\n" <>
  "Option RepeatInterval -> None \:3067\:7e70\:308a\:8fd4\:3057\:5b9f\:884c\:3002\:4f8b: RepeatInterval -> Quantity[2, \"Hours\"] \:3067 2 \:6642\:9593\:3054\:3068\:306b\:5b9f\:884c\:3002\n" <>
  "RepeatInterval -> {Quantity[1,\"Hours\"], 5} \:3067 1 \:6642\:9593\:3054\:3068\:306b\:6700\:5927 5 \:56de\:5b9f\:884c\:3002\n" <>
  "TaskObject \:304c\:8fd4\:308b\:306e\:3067 TaskRemove[] \:3067\:505c\:6b62\:53ef\:80fd\:3002";ContinueEval::usage =
  "ContinueEval[session, instruction] \:306f\:6307\:5b9a\:30bb\:30c3\:30b7\:30e7\:30f3\:3067\:7d99\:7d9a\:3002\n" <>
  "ContinueEval[instruction] \:306f\:30c7\:30d5\:30a9\:30eb\:30c8\:30bb\:30c3\:30b7\:30e7\:30f3\:3067\:7d99\:7d9a\:3002\n" <>
  "ContinueEval[] \:306f \"\:30a8\:30e9\:30fc\:3092\:4fee\:6b63\:3057\:3066\:304f\:3060\:3055\:3044\" \:3067\:30c7\:30d5\:30a9\:30eb\:30c8\:30bb\:30c3\:30b7\:30e7\:30f3\:3092\:7d99\:7d9a\:3002\n" <>
  "Option StartTime -> Now \:3067\:5b9f\:884c\:958b\:59cb\:6642\:523b\:3092 DateObject \:3067\:6307\:5b9a\:3002";ContinueUpdate::usage =
  "ContinueUpdate[] \:306f\:76f4\:524d\:306e ClaudeUpdatePackage \:306e\:7d50\:679c\:3092\:8e0f\:307e\:3048\:3066\:30d0\:30b0\:4fee\:6b63\:3092\:7d99\:7d9a\:3059\:308b\:3002\n" <>
  "ContinueUpdate[\"instruction\"] \:306f\:8ffd\:52a0\:6307\:793a\:3092\:4ed8\:3051\:3066\:7d99\:7d9a\:3002\n" <>
  "ContinueUpdate[\"pkgName\", \"instruction\"] \:306f\:6307\:5b9a\:30d1\:30c3\:30b1\:30fc\:30b8\:306e\:76f4\:524d\:306e\:66f4\:65b0\:3092\:7d99\:7d9a\:3002\n" <>
  "Options: Fallback -> False, \"UpdateApiMd\" -> True, StartTime -> Now\:3002\n" <>
  "\:4f8b: ContinueUpdate[]\n" <>
  "\:4f8b: ContinueUpdate[\"\:4e0a\:534a\:5186\:306e\:5883\:754c\:7dda\:304c\:6b20\:3051\:3066\:3044\:308b\:306e\:3067\:4fee\:6b63\:3057\:3066\"]";CreateClaudeSession::usage =
  "CreateClaudeSession[\"name\"] \:306f\:540d\:524d\:4ed8\:304d\:30bb\:30c3\:30b7\:30e7\:30f3\:3092\:4f5c\:6210\:3059\:308b\:ff08\:30c7\:30d5\:30a9\:30eb\:30c8\:5c65\:6b74\:3092\:7d99\:627f\:ff09\:3002\n" <>
  "CreateClaudeSession[session] \:306f\:65e2\:5b58\:30bb\:30c3\:30b7\:30e7\:30f3\:306e\:5c65\:6b74\:3092\:7d99\:627f\:3057\:305f\:65b0\:30bb\:30c3\:30b7\:30e7\:30f3\:3092\:4f5c\:6210\:3002\n" <>
  "CreateClaudeSession[] \:306f\:30c7\:30d5\:30a9\:30eb\:30c8\:5c65\:6b74\:3092\:7d99\:627f\:3057\:305f\:65b0\:30bb\:30c3\:30b7\:30e7\:30f3\:3092\:4f5c\:6210\:3002\n" <>
  "CreateClaudeSession[Inherit->False] \:306f\:72ec\:7acb\:3057\:305f\:30bb\:30c3\:30b7\:30e7\:30f3\:3092\:4f5c\:6210\:3002";ClaudeRestoreSession::usage =
  "ClaudeRestoreSession[] \:306f\:30c7\:30d5\:30a9\:30eb\:30c8\:30bb\:30c3\:30b7\:30e7\:30f3\:3092\:30ea\:30b9\:30c8\:30a2\:3002\n" <>
  "ClaudeRestoreSession[\"name\"] \:306f\:6307\:5b9a\:540d\:306e\:30bb\:30c3\:30b7\:30e7\:30f3\:3092\:30ea\:30b9\:30c8\:30a2\:3002";ClaudeListSessions::usage =
  "ClaudeListSessions[] \:306f\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:5185\:306e\:5168\:30bb\:30c3\:30b7\:30e7\:30f3\:3092\:4e00\:89a7\:8868\:793a\:3059\:308b\:3002";ClaudeDeleteSession::usage =
  "ClaudeDeleteSession[\"name\"] \:306f\:6307\:5b9a\:540d\:306e\:30bb\:30c3\:30b7\:30e7\:30f3\:3092\:524a\:9664\:3059\:308b\:3002\n" <>
  "ClaudeDeleteSession[\"name\", \"All\"] \:306f\:30bb\:30c3\:30b7\:30e7\:30f3\:3068\:305d\:306e\:5168\:5c65\:6b74\:3092\:524a\:9664\:3059\:308b\:3002";ClaudeShowHistory::usage =
  "ClaudeShowHistory[] \:306f\:30c7\:30d5\:30a9\:30eb\:30c8\:30bb\:30c3\:30b7\:30e7\:30f3\:306e\:5c65\:6b74\:3092\:8868\:793a\:3059\:308b\:3002\n" <>
  "ClaudeShowHistory[session] \:306f\:6307\:5b9a\:30bb\:30c3\:30b7\:30e7\:30f3\:306e\:5c65\:6b74\:3092\:8868\:793a\:3059\:308b\:3002\n" <>
  "ClaudeShowHistory[\"name\"] \:306f\:6307\:5b9a\:540d\:306e\:30bb\:30c3\:30b7\:30e7\:30f3\:306e\:5c65\:6b74\:3092\:8868\:793a\:3059\:308b\:3002";
ClaudeAttach::usage =
  "ClaudeAttach[path] \:306f\:30c7\:30d5\:30a9\:30eb\:30c8\:30bb\:30c3\:30b7\:30e7\:30f3\:306b\:53c2\:8003\:8cc7\:6599\:3092\:30a2\:30bf\:30c3\:30c1\:3059\:308b\:3002\n" <>
  "ClaudeAttach[session, path] \:306f\:6307\:5b9a\:30bb\:30c3\:30b7\:30e7\:30f3\:306b\:30a2\:30bf\:30c3\:30c1\:3059\:308b\:3002\n" <>
  "\:30a2\:30bf\:30c3\:30c1\:3055\:308c\:305f\:30d5\:30a1\:30a4\:30eb\:306f ClaudeQuery/ClaudeEval \:6642\:306b\:81ea\:52d5\:7684\:306b Read \:3055\:308c\:308b\:3002";
ClaudeDetach::usage =
  "ClaudeDetach[path] \:306f\:30c7\:30d5\:30a9\:30eb\:30c8\:30bb\:30c3\:30b7\:30e7\:30f3\:304b\:3089\:30d5\:30a1\:30a4\:30eb\:3092\:30c7\:30bf\:30c3\:30c1\:3059\:308b\:3002\n" <>
  "ClaudeDetach[session, path] \:306f\:6307\:5b9a\:30bb\:30c3\:30b7\:30e7\:30f3\:304b\:3089\:30c7\:30bf\:30c3\:30c1\:3059\:308b\:3002";
ClaudeAttachments::usage =
  "ClaudeAttachments[] \:306f\:30c7\:30d5\:30a9\:30eb\:30c8\:30bb\:30c3\:30b7\:30e7\:30f3\:306e\:30a2\:30bf\:30c3\:30c1\:30e1\:30f3\:30c8\:4e00\:89a7\:3092\:8fd4\:3059\:3002\n" <>
  "ClaudeAttachments[session] \:306f\:6307\:5b9a\:30bb\:30c3\:30b7\:30e7\:30f3\:306e\:30a2\:30bf\:30c3\:30c1\:30e1\:30f3\:30c8\:4e00\:89a7\:3092\:8fd4\:3059\:3002";
ClearAttachments::usage =
  "ClearAttachments[] \:306f\:30c7\:30d5\:30a9\:30eb\:30c8\:30bb\:30c3\:30b7\:30e7\:30f3\:306e\:5168\:30a2\:30bf\:30c3\:30c1\:30e1\:30f3\:30c8\:3092\:30af\:30ea\:30a2\:3059\:308b\:3002\n" <>
  "ClearAttachments[session] \:306f\:6307\:5b9a\:30bb\:30c3\:30b7\:30e7\:30f3\:306e\:5168\:30a2\:30bf\:30c3\:30c1\:30e1\:30f3\:30c8\:3092\:30af\:30ea\:30a2\:3059\:308b\:3002";
ClaudeDebug::usage =
  "ClaudeDebug[codeOrFile, errorMsg] \:306f\:30c7\:30d0\:30c3\:30b0\:652f\:63f4\:3092\:975e\:540c\:671f\:3067\:6c42\:3081\:308b\:ff08\:5373\:5ea7\:306b\:8fd4\:308b\:ff09\:3002";ClaudeReview::usage =
  "ClaudeReview[codeOrFile] \:306f\:30b3\:30fc\:30c9\:306e\:30ec\:30d3\:30e5\:30fc\:3092\:975e\:540c\:671f\:3067\:884c\:3046\:ff0830000\:6587\:5b57\:8d85\:306f\:81ea\:52d5\:30c1\:30e3\:30f3\:30af\:5206\:5272\:ff09\:3002";ClaudeReviewChunked::usage =
  "ClaudeReviewChunked[codeOrFile] \:306f\:30d5\:30a1\:30a4\:30eb\:3092\:30c1\:30e3\:30f3\:30af\:5206\:5272\:3057\:3066\:975e\:540c\:671f\:30ec\:30d3\:30e5\:30fc\:3059\:308b\:3002";ClaudeCreatePackage::usage =
  "ClaudeCreatePackage[name, prompt] \:306f prompt \:306b\:5f93\:3063\:3066 name.wl \:3092\:65b0\:898f\:4f5c\:6210\:3057 $packageDirectory \:306b\:4fdd\:5b58\:3059\:308b\:3002";ClaudeUpdatePackage::usage =
  "ClaudeUpdatePackage[packageName, prompt] \:306f $packageDirectory \:306b\:3042\:308b packageName.wl \:3092\
Claude \:306e\:652f\:63f4\:3067\:30a2\:30c3\:30d7\:30c7\:30fc\:30c8\:3057\:3001\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:3092\:4f5c\:6210\:3059\:308b\:3002\n\
prompt \:306b\:306f\:6587\:5b57\:5217\:307e\:305f\:306f\:30ea\:30b9\:30c8 {\:6587\:5b57\:5217, Image, File[\".../file.pdf\"], ...} \:3092\:6307\:5b9a\:53ef\:80fd\:3002\n\
Options: TargetFunctions -> Automatic, StartTime -> Now, \"UpdateApiMd\" -> True\:3002\n\
\"UpdateApiMd\" -> False \:3067 api.md \:306e\:81ea\:52d5\:66f4\:65b0\:3092\:30b9\:30ad\:30c3\:30d7\:3002\n\
\:4f8b: ClaudeUpdatePackage[\"pkg\", \"\:4fee\:6b63\:6307\:793a\", StartTime -> Now + Quantity[1, \"Hours\"]]";ClaudeRestorePackage::usage =
  "ClaudeRestorePackage[packageName] \:306f\:76f4\:524d\:306e\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:3092\:5fa9\:5143\:3059\:308b\:3002";ClaudeConvertToPaclet::usage =
  "ClaudeConvertToPaclet[packageName] \:306f $packageDirectory \:306e packageName.wl \:3092 Paclet \:5f62\:5f0f\:306b\:5909\:63db\:3059\:308b\:3002\n" <>
  "packageName/ \:30d5\:30a9\:30eb\:30c0\:3092\:4f5c\:6210\:3057\:3001Kernel/, Documentation/, PacletInfo.wl \:7b49\:3092\:751f\:6210\:3059\:308b\:3002\n" <>
  "\:5143\:306e .wl \:30d5\:30a1\:30a4\:30eb\:306f\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:5f8c\:306b\:524a\:9664\:3055\:308c\:308b\:3002";ClaudeCreateDocumentation::usage =
  "ClaudeCreateDocumentation[\"packageName\"] \:306f\:30d1\:30c3\:30b1\:30fc\:30b8\:306e\:8a73\:7d30\:306a\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:4e00\:5f0f\:3092 Claude \:3067\:81ea\:52d5\:751f\:6210\:3059\:308b\:3002\n" <>
  "$packageDirectory \:5185\:306e packageName.wl \:307e\:305f\:306f packageName/ Paclet \:3092\:5bfe\:8c61\:3068\:3059\:308b\:3002\n" <>
  "\:5358\:4e00 .wl: $packageDirectory/packageName_info/docs/ \:306b\:51fa\:529b\:3002\n" <>
  "Paclet: $packageDirectory/packageName/docs/ \:306b\:51fa\:529b\:3002\n" <>
  "\:4f8b: ClaudeCreateDocumentation[\"claudecode\"]";ClaudeUpdateDocumentation::usage =
  "ClaudeUpdateDocumentation[\"packageName\"] \:306f\:30bd\:30fc\:30b9\:5dee\:5206\:306b\:57fa\:3065\:304d\:5168\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:3092\:81ea\:52d5\:66f4\:65b0\:3059\:308b\:3002\n" <>
  "ClaudeUpdateDocumentation[\"packageName\", \"\:66f4\:65b0\:6307\:793a\"] \:306f\:6307\:793a\:306b\:5f93\:3063\:3066\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:3092\:66f4\:65b0\:3059\:308b\:3002\n" <>
  "\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:306e\:30b3\:30f3\:30c6\:30ad\:30b9\:30c8\:3082\:53c2\:7167\:53ef\:80fd\:ff08\:300c\:4e0a\:3067\:8b70\:8ad6\:3055\:308c\:3066\:3044\:308b\:5185\:5bb9\:3092\:53cd\:6620\:3057\:3066\:300d\:306a\:3069\:ff09\:3002\n" <>
  "\:4f8b: ClaudeUpdateDocumentation[\"claudecode\", \"api.md\:306e\:307f\:66f4\:65b0\:3057\:3066\"]";ClaudeUpdatePackageHistory::usage =
  "ClaudeUpdatePackageHistory[] \:306f\:5168\:30d1\:30c3\:30b1\:30fc\:30b8\:306e ClaudeUpdatePackage \:547c\:3073\:51fa\:3057\:5c65\:6b74\:3092\:8868\:793a\:3057\:30ea\:30b9\:30c8\:3067\:8fd4\:3059\:3002\n\
ClaudeUpdatePackageHistory[packageName] \:306f\:6307\:5b9a\:30d1\:30c3\:30b1\:30fc\:30b8\:306e\:66f4\:65b0\:5c65\:6b74\:3092\:8868\:793a\:3057\:30ea\:30b9\:30c8\:3067\:8fd4\:3059\:3002\n\
\:5404\:30a8\:30f3\:30c8\:30ea\:306f <|\"Package\"->\[Ellipsis], \"Timestamp\"->\[Ellipsis], \"Directory\"->\[Ellipsis]|> \:306e Association\:3002";ClaudeBackupDataset::usage =
  "ClaudeBackupDataset[packageName] \:306f\:6307\:5b9a\:30d1\:30c3\:30b1\:30fc\:30b8\:306e\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:5c65\:6b74\:3092 Review/Pull/Delete \:30dc\:30bf\:30f3\:4ed8\:304d Grid \:3067\:8868\:793a\:3059\:308b\:3002\n" <>
  "ClaudeBackupDataset[] \:306f\:5168\:30d1\:30c3\:30b1\:30fc\:30b8\:306e\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:5c65\:6b74\:3092\:8868\:793a\:3059\:308b\:3002\n" <>
  "Review \:306f\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:5185\:5bb9\:3092\:78ba\:8a8d\:3001Pull \:306f\:5fa9\:5143\:3001Delete \:306f\:305d\:306e\:5c65\:6b74\:3092\:524a\:9664\:3002";ClaudeMigrateBackupHistory::usage =
  "ClaudeMigrateBackupHistory[packageName] \:306f\:65e2\:5b58\:306e history \:5185\:306e\:751f .wl \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:3092\n" <>
  "\:5dee\:5206\:5f62\:5f0f (.wl.cz / .wl.cdiff) \:306b\:5909\:63db\:3057\:3066\:5bb9\:91cf\:3092\:524a\:6e1b\:3059\:308b\:3002\n" <>
  "ClaudeMigrateBackupHistory[packageName, DryRun -> True] \:306f\:524a\:9664\:305b\:305a\:5bb9\:91cf\:524a\:6e1b\:306e\:898b\:7a4d\:3082\:308a\:3092\:8868\:793a\:3059\:308b\:3002\n" <>
  "ClaudeMigrateBackupHistory[] \:306f\:5168\:30d1\:30c3\:30b1\:30fc\:30b8\:306b\:5bfe\:3057\:3066\:5b9f\:884c\:3059\:308b\:3002";ClaudeAddDirective::usage =
  "ClaudeAddDirective[target, description] \:306f Claude \:3067 description \:3092\:6574\:5f62\:3057\:3001\n" <>
  "Claude Directives \:30d5\:30a9\:30eb\:30c0\:306e\:30d5\:30a1\:30a4\:30eb\:306b\:8ffd\:52a0\:3057\:3066 InstallClaudeDirectives[] \:3092\:5b9f\:884c\:3059\:308b\:3002\n" <>
  "target \:306f \"CLAUDE.md\" \:307e\:305f\:306f\:30b9\:30ad\:30eb\:540d\:ff08\:4f8b: \"wolfram-general\"\:ff09\:3002\n" <>
  "\:5143\:30d5\:30a1\:30a4\:30eb\:306f\:81ea\:52d5\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:3055\:308c\:308b\:3002";ClaudeRestoreDirective::usage =
  "ClaudeRestoreDirective[target] \:306f ClaudeAddDirective \:306e\:76f4\:524d\:306e\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:3092\:5fa9\:5143\:3057 InstallClaudeDirectives[] \:3092\:5b9f\:884c\:3059\:308b\:3002\n" <>
  "target \:306f \"CLAUDE.md\" \:307e\:305f\:306f\:30b9\:30ad\:30eb\:540d\:3002";ClaudeListDirectives::usage =
  "ClaudeListDirectives[] \:306f Claude Directives \:30d5\:30a9\:30eb\:30c0\:306e CLAUDE.md \:3068\:5168\:30b9\:30ad\:30eb\:306e\:4e00\:89a7\:3092\:8868\:793a\:3059\:308b\:3002";
ClaudeUpdateDirective::usage =
  "ClaudeUpdateDirective[] \:306f\:30bd\:30fc\:30b9\:30b3\:30fc\:30c9\:3068 Claude Directives \:306e\:6574\:5408\:6027\:3092\:30c1\:30a7\:30c3\:30af\:3057\:3001\:4e0d\:6574\:5408\:3092\:81ea\:52d5\:4fee\:6b63\:3059\:308b\:3002\n" <>
  "ClaudeUpdateDirective[text] \:306f text \:306e\:5185\:5bb9\:3092 Claude \:3067\:89e3\:91c8\:3057\:3001\n" <>
  "CLAUDE.md / rules / skills \:306e\:9069\:5207\:306a\:30d5\:30a1\:30a4\:30eb\:306b\:53cd\:6620\:3059\:308b\:3002\n" <>
  "\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:306e\:30b3\:30f3\:30c6\:30ad\:30b9\:30c8\:3082\:53c2\:7167\:53ef\:80fd\:ff08\:300c\:4e0a\:3067\:8b70\:8ad6\:3055\:308c\:3066\:3044\:308b\:5185\:5bb9\:3092\:53cd\:6620\:3057\:3066\:300d\:306a\:3069\:ff09\:3002";ClaudeDirectiveBackupDataset::usage =
  "ClaudeDirectiveBackupDataset[] \:306f Claude Directives \:306e\:66f4\:65b0\:5c65\:6b74\:3092 Review/Pull/Delete \:30dc\:30bf\:30f3\:4ed8\:304d Grid \:3067\:8868\:793a\:3059\:308b\:3002\n" <>
  "\:5c65\:6b74\:306f ClaudeUpdateDirective[text] \:3084 ClaudeAddDirective \:306e\:5b9f\:884c\:6642\:306b\:81ea\:52d5\:4fdd\:5b58\:3055\:308c\:308b\:3002";ClaudeSyncDirectives::usage =
  "ClaudeSyncDirectives[dir] \:306f\:6307\:5b9a\:30c7\:30a3\:30ec\:30af\:30c8\:30ea dir \:306e\:30d5\:30a1\:30a4\:30eb\:3092 Claude Directives \:30d5\:30a9\:30eb\:30c0\:3068\:6bd4\:8f03\:3057\:3001\n" <>
  "dir \:5074\:306e\:65b9\:304c\:65b0\:3057\:3044\:30d5\:30a1\:30a4\:30eb\:3067 Claude Directives \:3092\:66f4\:65b0\:3059\:308b\:3002\n" <>
  "dir \:306b\:3060\:3051\:5b58\:5728\:3059\:308b\:30d5\:30a1\:30a4\:30eb\:3082\:30b3\:30d4\:30fc\:3059\:308b\:3002Claude Directives \:5074\:306b\:3057\:304b\:306a\:3044\:30d5\:30a1\:30a4\:30eb\:306f\:305d\:306e\:307e\:307e\:3002\n" <>
  "\:4f8b: ClaudeSyncDirectives[\"C:\\\\Users\\\\user\\\\Claude Directives\"]";MarkConfidential::usage =
  "MarkConfidential[] \:306f\:73fe\:5728\:306e\:30bb\:30eb\:3092\:6a5f\:5bc6\:30de\:30fc\:30af\:3059\:308b\:3002\n" <>
  "MarkConfidential[cell] \:306f\:6307\:5b9a\:30bb\:30eb\:3092\:6a5f\:5bc6\:30de\:30fc\:30af\:3059\:308b\:3002\n" <>
  "\:6a5f\:5bc6\:30bb\:30eb\:306f ClaudeEval/ClaudeQuery \:306e\:30d7\:30ed\:30f3\:30d7\:30c8\:304b\:3089\:9664\:5916\:3055\:308c\:308b\:3002";UnmarkConfidential::usage =
  "UnmarkConfidential[] \:306f\:73fe\:5728\:306e\:30bb\:30eb\:306e\:6a5f\:5bc6\:30de\:30fc\:30af\:3092\:89e3\:9664\:3059\:308b\:3002\n" <>
  "UnmarkConfidential[cell] \:306f\:6307\:5b9a\:30bb\:30eb\:306e\:6a5f\:5bc6\:30de\:30fc\:30af\:3092\:89e3\:9664\:3059\:308b\:3002";IsConfidential::usage =
  "IsConfidential[cell] \:306f\:30bb\:30eb\:304c\:6a5f\:5bc6\:30de\:30fc\:30af\:3055\:308c\:3066\:3044\:308b\:304b\:3092\:8fd4\:3059\:3002\n" <>
  "IsConfidential[] \:306f\:73fe\:5728\:306e\:30bb\:30eb\:304c\:6a5f\:5bc6\:304b\:3092\:8fd4\:3059\:3002";Confidential::usage =
  "Confidential[expr] \:306f\:5f0f\:3092\:8a55\:4fa1\:3057\:3001\:305d\:306e Input/Output \:30bb\:30eb\:3092\:81ea\:52d5\:7684\:306b\:6a5f\:5bc6\:30de\:30fc\:30af\:3059\:308b\:3002\n" <>
  "\:4f8b: Confidential[secretData = Import[\"secret.csv\"]]";NonConfidential::usage =
  "NonConfidential[expr] \:306f\:5f0f\:3092\:8a55\:4fa1\:3057\:3001\:305d\:306e Input/Output \:30bb\:30eb\:306e\:6a5f\:5bc6\:30de\:30fc\:30af\:3092\:660e\:793a\:7684\:306b\:89e3\:9664\:3059\:308b\:3002\n" <>
  "\:79d8\:5bc6\:5909\:6570\:3084\:79d8\:5bc6\:4f9d\:5b58\:5909\:6570\:306e\:5024\:306b\:4f9d\:5b58\:3057\:3066\:3044\:3066\:3082\:3001\:6a5f\:5bc6\:89e3\:9664\:3068\:3057\:3066\:6271\:3046\:3002\n" <>
  "\:4f8b: result = NonConfidential[Mean[secretData]]";ScanConfidentialCells::usage =
  "ScanConfidentialCells[] \:306f\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:5168\:30bb\:30eb\:3092\:30b9\:30ad\:30e3\:30f3\:3057\:3001\:6a5f\:5bc6\:5909\:6570\:3092\:53c2\:7167\:3059\:308b\:30bb\:30eb\:3092\:81ea\:52d5\:7684\:306b\:6a5f\:5bc6\:30de\:30fc\:30af\:3059\:308b\:3002\n" <>
  "\:660e\:793a\:7684\:306b UnmarkConfidential \:3055\:308c\:305f\:30bb\:30eb\:306f\:30b9\:30ad\:30c3\:30d7\:3055\:308c\:308b\:3002";ShowClaudePalette::usage =
  "ShowClaudePalette[] \:306f Claude Code \:64cd\:4f5c\:7528\:306e\:30d1\:30ec\:30c3\:30c8\:3092\:8868\:793a\:3059\:308b\:3002";
ClaudeQueryShowContext::usage =
  "ClaudeQueryShowContext[] \:306f\:30c7\:30d0\:30c3\:30b0\:7528: \:6b21\:306e ClaudeQuery \:304c\:9001\:4fe1\:3059\:308b\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:30b3\:30f3\:30c6\:30ad\:30b9\:30c8\:3092\:8868\:793a\:3059\:308b\:3002";
ClaudeShowAccessConfig::usage =
  "ClaudeShowAccessConfig[] \:306f\:30c7\:30d0\:30c3\:30b0\:7528: Claude Code \:306e\:30d5\:30a1\:30a4\:30eb\:30a2\:30af\:30bb\:30b9\:8a2d\:5b9a\:3092\:8868\:793a\:3059\:308b\:3002\n" <>
  "$ClaudeAccessibleDirs, NBGetAccessibleDirs[], \:751f\:6210\:3055\:308c\:308b settings.json, CLI \:30d5\:30e9\:30b0\:3092\:78ba\:8a8d\:53ef\:80fd\:3002";
ClaudeSessionStatus::usage =
  "ClaudeSessionStatus[] \:306f\:30c7\:30d5\:30a9\:30eb\:30c8\:30bb\:30c3\:30b7\:30e7\:30f3\:306e\:72b6\:614b\:3092\:8868\:793a\:3059\:308b\:3002\n" <>
  "ClaudeSessionStatus[name] \:306f\:6307\:5b9a\:540d\:306e\:30bb\:30c3\:30b7\:30e7\:30f3\:306e\:72b6\:614b\:3092\:8868\:793a\:3059\:308b\:3002\n" <>
  "\:30a2\:30af\:30bb\:30b9\:53ef\:80fd\:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:3001\:30a2\:30bf\:30c3\:30c1\:30e1\:30f3\:30c8\:3001\:4f5c\:696d\:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:306e\:30d5\:30a1\:30a4\:30eb\:7b49\:3092\:78ba\:8a8d\:53ef\:80fd\:3002";
ClaudeStatus::usage =
  "ClaudeStatus[] \:306f\:73fe\:5728\:5b9f\:884c\:4e2d\:306e\:5168 Claude \:30bf\:30b9\:30af\:306e\:30ea\:30a2\:30eb\:30bf\:30a4\:30e0\:72b6\:614b\:3092\:8868\:793a\:3059\:308b\:3002\n" <>
  "\:5404\:30bf\:30b9\:30af\:306e\:7d4c\:904e\:6642\:9593\:3001\:73fe\:5728\:306e\:72b6\:614b\:ff08\:601d\:8003\:4e2d/\:30c6\:30ad\:30b9\:30c8\:751f\:6210\:4e2d/\:30c4\:30fc\:30eb\:5b9f\:884c\:4e2d\:ff09\:3001\n" <>
  "\:751f\:6210\:6e08\:307f\:30c6\:30ad\:30b9\:30c8\:65ad\:7247\:6570\:3001\:601d\:8003\:65ad\:7247\:6570\:3001\:30c4\:30fc\:30eb\:4f7f\:7528\:6570\:3092\:8868\:793a\:3059\:308b\:3002\n" <>
  "\:5b9f\:884c\:4e2d\:306e\:30bf\:30b9\:30af\:304c\:306a\:3044\:5834\:5408\:306f\:305d\:306e\:65e8\:3092\:8868\:793a\:3059\:308b\:3002";
ClaudePrepareCommit::usage =
  "ClaudePrepareCommit[packageName] \:306f\:524d\:56de\:306e GitHub \:30b3\:30df\:30c3\:30c8\:4ee5\:964d\:306e\:5909\:66f4\:70b9\:3092\n" <>
  "\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:5c65\:6b74\:304b\:3089\:53ce\:96c6\:3057\:3001\:30b3\:30df\:30c3\:30c8\:30e1\:30c3\:30bb\:30fc\:30b8\:3092\:751f\:6210\:3057\:3066\n" <>
  "GitHubRefreshAndCommit \:5b9f\:884c\:30b3\:30de\:30f3\:30c9\:3092 Input \:30bb\:30eb\:3068\:3057\:3066\:51fa\:529b\:3059\:308b\:3002\n" <>
  "ClaudePrepareCommit[packageName, subject] \:306f 1\:884c\:76ee\:3092\:6307\:5b9a\:3057\:3001\:672c\:6587\:306f\:81ea\:52d5\:53ce\:96c6\:3002\n" <>
  "Options: Fallback -> False, DryRun -> False, " <>
  "Owner -> Automatic, Repository -> Automatic, " <>
  "Branch -> Automatic, BaseBranch -> Automatic\:3002\n" <>
  "DryRun -> True \:3067\:30b3\:30de\:30f3\:30c9\:3092\:751f\:6210\:305b\:305a\:30e1\:30c3\:30bb\:30fc\:30b8\:306e\:307f\:8fd4\:3059\:3002";
ClaudeWebSearch::usage =
  "ClaudeWebSearch[query] \:306f Web \:691c\:7d22\:3092\:5b9f\:884c\:3057\:3001\:7d50\:679c\:3092\:30c6\:30ad\:30b9\:30c8\:3067\:8fd4\:3059\:3002\n" <>
  "Anthropic API \:306e web_search \:30c4\:30fc\:30eb\:3092\:4f7f\:7528\:3059\:308b\:3002";
ClaudeWebFetch::usage =
  "ClaudeWebFetch[url] \:306f\:6307\:5b9a URL \:306e\:5185\:5bb9\:3092\:53d6\:5f97\:3057\:3001\:8981\:7d04\:30fb\:62bd\:51fa\:3057\:3066\:8fd4\:3059\:3002\n" <>
  "ClaudeWebFetch[url, prompt] \:306f\:53d6\:5f97\:5185\:5bb9\:306b\:5bfe\:3057\:3066 prompt \:306e\:6307\:793a\:3092\:5b9f\:884c\:3059\:308b\:3002";
WebFetch::usage =
  "WebFetch \:306f ClaudeQuery/ClaudeEval \:306e\:30aa\:30d7\:30b7\:30e7\:30f3\:3002\n" <>
  "True: \:5fc5\:305a Web \:691c\:7d22\:3092\:884c\:3046\:3002\n" <>
  "False: Web \:691c\:7d22\:3092\:884c\:308f\:306a\:3044\:3002\n" <>
  "Automatic (ClaudeEval \:306e\:30c7\:30d5\:30a9\:30eb\:30c8): Claude \:304c\:30bf\:30b9\:30af\:3092\:5206\:6790\:3057\:3001\:5fc5\:8981\:306a\:3089\:81ea\:52d5\:3067 Web \:691c\:7d22\:3059\:308b\:3002\n" <>
  "ClaudeQuery \:306e\:30c7\:30d5\:30a9\:30eb\:30c8\:306f False\:3002\n" <>
  "\:91cd\:8981: WebFetch \:306f Anthropic API \:7d4c\:7531\:3067\:8ab2\:91d1\:304c\:767a\:751f\:3059\:308b\:305f\:3081\:3001Fallback -> True \:306e\:5834\:5408\:306e\:307f\:6709\:52b9\:3002";
WebSearch::usage =
  "WebSearch \:306f ClaudeQuery/ClaudeEval \:306e\:30aa\:30d7\:30b7\:30e7\:30f3\:3002\n" <>
  "True (\:30c7\:30d5\:30a9\:30eb\:30c8): Claude Code CLI \:306e\:7d44\:307f\:8fbc\:307f Web \:691c\:7d22\:30c4\:30fc\:30eb\:3092\:8a31\:53ef\:3059\:308b\:3002\n" <>
  "False: Claude Code CLI \:306e Web \:691c\:7d22\:3092\:7981\:6b62\:3059\:308b\:3002\n" <>
  "\:3053\:308c\:306f Claude Code \:81ea\:4f53\:306e Web \:691c\:7d22\:6a5f\:80fd\:3067\:3042\:308a\:3001API \:7d4c\:7531\:306e\:8ab2\:91d1\:306f\:767a\:751f\:3057\:306a\:3044\:3002\n" <>
  "WebFetch (\:8ab2\:91d1\:3042\:308a) \:3068\:306f\:7570\:306a\:308b\:3002";
ClaudeCompactHistory::usage =
  "ClaudeCompactHistory[] \:306f\:30c7\:30d5\:30a9\:30eb\:30c8\:30bb\:30c3\:30b7\:30e7\:30f3\:306e\:5c65\:6b74\:3092\:624b\:52d5\:3067\:30b3\:30f3\:30d1\:30af\:30b7\:30e7\:30f3\:3059\:308b\:3002\n" <>
  "ClaudeCompactHistory[name] \:306f\:6307\:5b9a\:30bb\:30c3\:30b7\:30e7\:30f3\:3092\:30b3\:30f3\:30d1\:30af\:30b7\:30e7\:30f3\:3059\:308b\:3002\n" <>
  "\:901a\:5e38\:306f 2n+1+w \:30a8\:30f3\:30c8\:30ea\:3092\:8d85\:3048\:305f\:3068\:304d\:306b\:81ea\:52d5\:5b9f\:884c\:3055\:308c\:308b\:3002";
ClaudeHistorySize::usage =
  "ClaudeHistorySize[] \:306f\:73fe\:5728\:306e\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:306e\:30bb\:30c3\:30b7\:30e7\:30f3\:5c65\:6b74\:30b5\:30a4\:30ba\:3092\:8a3a\:65ad\:3059\:308b\:3002\n" <>
  "Entries\:30fbByteCount\:30fbKiloBytes\:30fbStatus \:3092\:542b\:3080 Association \:3092\:8fd4\:3059\:3002\n" <>
  "200KB\:8d85\:3067\:30b3\:30f3\:30d1\:30af\:30b7\:30e7\:30f3\:63a8\:5968\:3001500KB\:8d85\:3067\:5371\:967a\:3002";
ClaudeCommand::usage =
  "ClaudeCommand[\"/command\"] \:306f Claude Code CLI \:306e\:30b9\:30e9\:30c3\:30b7\:30e5\:30b3\:30de\:30f3\:30c9\:3092\:5b9f\:884c\:3057\:7d50\:679c\:3092\:8fd4\:3059\:3002\n" <>
  "\:30b9\:30e9\:30c3\:30b7\:30e5\:30b3\:30de\:30f3\:30c9 (/\:59cb\:307e\:308a) \:306f node-pty \:7d4c\:7531\:3067\:5bfe\:8a71\:30e2\:30fc\:30c9\:306b\:9001\:4fe1\:3055\:308c\:308b\:3002\n" <>
  "CLI \:30b5\:30d6\:30b3\:30de\:30f3\:30c9 (\:4f8b: config list) \:306f\:76f4\:63a5\:5b9f\:884c\:3055\:308c\:308b\:3002\n" <>
  "\:4f8b: ClaudeCommand[\"/help\"]\n" <>
  "\:4f8b: ClaudeCommand[\"/permissions\"]\n" <>
  "\:4f8b: ClaudeCommand[\"config list\"]\n" <>
  "\:4f8b: ClaudeCommand[\"--version\"]";
$ClaudeTestModel::usage =
  "$ClaudeTestModel \:306f\:5206\:96e2\:691c\:8a3c\:306a\:3069\:306e\:30c6\:30b9\:30c8\:7528\:30e2\:30c7\:30eb\:540d\:3002\n" <>
  "\:521d\:671f\:5024\:306f $ClaudeModel \:3068\:540c\:3058\:3002\n" <>
  "\:5225\:30e2\:30c7\:30eb\:3067\:5ba2\:89b3\:7684\:306b\:691c\:8a3c\:3059\:308b\:305f\:3081\:306b\:5909\:66f4\:53ef\:80fd\:3002\n" <>
  "\:4f8b: $ClaudeTestModel = \"claude-sonnet-4-20250514\"";
ClaudeCheckSeparation::usage =
  "ClaudeCheckSeparation[target] \:306f target \:306e\:30b3\:30fc\:30c9\:304c NBAccess \:306e\:5206\:96e2\:539f\:5247\:306b\n" <>
  "\:9055\:53cd\:3057\:3066\:3044\:308b\:7b87\:6240\:3092\:30ea\:30b9\:30c8\:30a2\:30c3\:30d7\:3059\:308b\:3002\n" <>
  "target: \:30d5\:30a1\:30a4\:30eb\:30d1\:30b9 | $packageDirectory \:306e .wl \:540d | \:30d1\:30af\:30ec\:30c3\:30c8\:540d\:3002\n" <>
  "\:691c\:67fb\:5bfe\:8c61 (\:9759\:7684\:8d70\:67fb + LLM\:5224\:5b9a):\n" <>
  "  a. SystemCredential\:76f4\:63a5\:5229\:7528\n" <>
  "  b. CellObject\:76f4\:63a5\:64cd\:4f5c (NotebookWrite/NotebookRead/CellGroupData\:76f4\:63a5\:69cb\:7bc9)\n" <>
  "  c. CellEpilog/CellProlog/NotebookEventActions\:76f4\:63a5\:64cd\:4f5c\n" <>
  "  d. NBAccess`Private`\:95a2\:6570\:547c\:3073\:51fa\:3057\n" <>
  "  e. NBAccess\:516c\:958b\:30b0\:30ed\:30fc\:30d0\:30eb\:76f4\:63a5\:66f4\:65b0\n" <>
  "  f. EvaluationCell[]/CellPrint[]/SetSelectedNotebook[]\:76f4\:63a5\:4f7f\:7528\n" <>
  "  g. CurrentValue/SetOptions\:306b\:3088\:308bTaggingRules/CellTags/CellEpilog\:5c5e\:6027\:76f4\:63a5\:30a2\:30af\:30bb\:30b9\n" <>
  "  h. CellObject\:306e\:516c\:958bAPI\:30fb\:623b\:308a\:5024\:30fb\:72b6\:614b\:4fdd\:6301\:3078\:306e\:6f0f\:6d29\n" <>
  "  i. SelectionEvaluate/FrontEndTokenExecute\:7b49FE\:72b6\:614b\:64cd\:4f5c\n" <>
  "  j. NBAccess\:516c\:958b\:30b0\:30ed\:30fc\:30d0\:30eb\:306e\:7834\:58ca\:7684\:66f4\:65b0 (AppendTo/AssociateTo\:7b49)\n" <>
  "$ClaudeTestModel \:306e\:30e2\:30c7\:30eb\:3067\:691c\:67fb\:3059\:308b\:3002\n" <>
  "\:4f8b: ClaudeCheckSeparation[\"claudecode\"]\n" <>
  "\:4f8b: ClaudeCheckSeparation[\"C:\\\\path\\\\to\\\\file.wl\"]";
ClaudeFixSeparation::usage =
  "ClaudeFixSeparation[target] \:306f\:5206\:96e2\:9055\:53cd\:3092\:4fee\:6b63\:3059\:308b\:3002\n" <>
  "target \:304c\:30d5\:30a1\:30a4\:30eb\:30d1\:30b9\:306e\:5834\:5408: \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:3092\:4f5c\:6210\:3057\:5143\:30d5\:30a1\:30a4\:30eb\:3092\:4fee\:6b63\:3002\n" <>
  "target \:304c\:30d1\:30c3\:30b1\:30fc\:30b8\:540d\:306e\:307f\:306e\:5834\:5408: ClaudeUpdatePackage \:3092\:547c\:3073\:51fa\:3059\:3002\n" <>
  "\:4e8b\:524d\:306b ClaudeCheckSeparation \:306e\:7d50\:679c\:304c\:3042\:308c\:3070\:305d\:308c\:3092\:5229\:7528\:3059\:308b\:3002\n" <>
  "\:4f8b: ClaudeFixSeparation[\"claudecode\"]";
    Begin["`Private`"];(* ============================================================
   \:8a2d\:5b9a\:ff1a\:5fc5\:8981\:306b\:5fdc\:3058\:3066\:624b\:52d5\:3067\:4e0a\:66f8\:304d\:53ef\:80fd
   ============================================================ *)

If[!ValueQ[$ClaudeModel], $ClaudeModel = ""];
If[!ValueQ[$ClaudeTimeout], $ClaudeTimeout = 1200];
If[!ValueQ[$ClaudePrivateModel], $ClaudePrivateModel = {}];
If[!AssociationQ[$ClaudePackageKeywordMap], $ClaudePackageKeywordMap = <||>];
iClaudeWorkingDirectory[] := Module[{dir = $ClaudeWorkingDirectory},
  If[!StringQ[dir] || dir === "",
    dir = FileNameJoin[{$HomeDirectory, "Claude Working"}]
  ];
  dir
];

iEnsureClaudeWorkingDirectory[] := Module[{dir = iClaudeWorkingDirectory[]},
  If[!DirectoryQ[dir],
    CreateDirectory[dir, CreateIntermediateDirectories -> True]
  ];
  dir
];

iClaudeAPIEnvVars[] := {
  "ANTHROPIC_API_KEY",
  "ANTHROPIC_AUTH_TOKEN",
  "ANTHROPIC_CUSTOM_HEADERS",
  "ANTHROPIC_BASE_URL",
  "ANTHROPIC_MODEL",
  "ANTHROPIC_DEFAULT_MODEL",
  "ANTHROPIC_SMALL_FAST_MODEL",
  "ANTHROPIC_FOUNDRY_API_KEY",
  "ANTHROPIC_FOUNDRY_URL",
  "CLAUDE_CODE_USE_BEDROCK",
  "CLAUDE_CODE_USE_VERTEX",
  "CLAUDE_CODE_USE_FOUNDRY",
  "OPENAI_API_KEY"
};

iClaudeEnvResetBatchLines[] := StringJoin[
  ("set \"" <> # <> "=\"\r\n") & /@ iClaudeAPIEnvVars[]
];

iCopyDirectoryRecursive[src_String, dst_String] := Module[{entries},
  If[!DirectoryQ[src], Return[dst]];
  If[!DirectoryQ[dst],
    CreateDirectory[dst, CreateIntermediateDirectories -> True]
  ];
  entries = Join[FileNames["*", src], FileNames[".*", src]];
  Scan[
    Function[path,
      If[DirectoryQ[path],
        iCopyDirectoryRecursive[path, FileNameJoin[{dst, FileNameTake[path]}]],
        Quiet @ CopyFile[
          path,
          FileNameJoin[{dst, FileNameTake[path]}],
          OverwriteTarget -> True
        ]
      ]
    ],
    entries
  ];
  dst
];

(* ノートブック TaggingRules + グローバル変数からアクセス可能ディレクトリを収集。
   $packageDirectory と $ClaudeWorkingDirectory は常にベースとして含める。
   注: NotebookDirectory はここに含めない。--add-dir に含めると Read も可能になるため。
   ファイルカタログ表示は iFileAccessContext が Mathematica 側の FileNames[] で
   プロンプトに埋め込むので、Claude Code の --add-dir や Glob は不要。 *)
iCollectAccessibleDirs[] := Module[{nbDirs = {}, attDirs = {}, baseDirs},
  (* $packageDirectory と作業ディレクトリは常に保証 *)
  baseDirs = Select[{Global`$packageDirectory, iClaudeWorkingDirectory[]},
    StringQ[#] && StringLength[#] > 0 && DirectoryQ[#] &];
  Quiet[nbDirs = NBAccess`NBGetAccessibleDirs[EvaluationNotebook[]]];
  attDirs = DeleteDuplicates[DirectoryName /@ Select[
    If[ListQ[$iCurrentSessionAttachments], $iCurrentSessionAttachments, {}],
    StringQ[#] && FileExistsQ[#] &]];
  DeleteDuplicates @ Select[
    Join[baseDirs,
         If[ListQ[$ClaudeAccessibleDirs], $ClaudeAccessibleDirs, {}],
         If[ListQ[nbDirs], nbDirs, {}],
         attDirs],
    StringQ[#] && StringLength[#] > 0 &]
];

(* セッションアタッチメントを一時的に保持するグローバル
   ClaudeQuery/ClaudeEval が呼ばれるたびにセッションヘッダーから読み込む *)
$iCurrentSessionAttachments = {};

(* プロンプト中のファイル名を NotebookDirectory 内で解決する。
   NotebookDirectory が Read 許可されていない場合は解決しない。
   注: この関数は fullPrompt（ファイル一覧コンテキスト含む）に対して呼ばれるため、
   ここでダイアログを出すと常にトリガーされてしまう。
   Read 許可は iEnsureDefaultSession での保存済み許可復元、
   または $ClaudeAccessibleDirs への手動追加で設定する。 *)
iResolveNotebookFiles[prompt_String] :=
  Module[{nbDir, filePattern, candidates, found},
    nbDir = Quiet @ Check[NotebookDirectory[InputNotebook[]], None];
    If[!StringQ[nbDir] || !DirectoryQ[nbDir], Return[prompt]];
    (* Read 許可済みかチェック（未許可なら何もしない） *)
    If[!(iIsSafeDefaultDir[nbDir] ||
         MemberQ[If[ListQ[$ClaudeAccessibleDirs], $ClaudeAccessibleDirs, {}], nbDir]),
      Return[prompt]];
    filePattern = RegularExpression[
      "(?<![/\\\\\\w])([\\w][\\w\\s\\-\\.]*\\." <>
      "(?:pdf|txt|csv|tsv|wl|wls|m|nb|json|xml|html|md|py|r|jl|rb|js|tex|" <>
      "xlsx|xls|png|jpg|jpeg|gif|bmp|svg|dat))" <>
      "(?![/\\\\\\w])"];
    candidates = DeleteDuplicates @ StringCases[prompt, filePattern :> "$1"];
    found = Select[candidates, FileExistsQ[FileNameJoin[{nbDir, #}]] &];
    If[Length[found] === 0, prompt,
      Join[File[FileNameJoin[{nbDir, #}]] & /@ found, {prompt}]]
  ];
iResolveNotebookFiles[prompt_List] := prompt;
iResolveNotebookFiles[prompt_] := prompt;

(* プロンプトにセッションアタッチメント + NotebookDirectory ファイルを注入する *)
iInjectAttachments[prompt_] :=
  Module[{result},
    result = iResolveNotebookFiles[prompt];
    If[Length[$iCurrentSessionAttachments] === 0,
      result,
      Join[File /@ Select[$iCurrentSessionAttachments, FileExistsQ],
           If[ListQ[result], result, {result}]]
    ]
  ];

(* ユーザープロンプトがファイル一覧を必要としているかを判定する。
   ファイル一覧は NotebookDirectory のファイルリストをプロンプトに含めるかどうかの判定に使う。 *)
iNeedsFileList[prompt_String] :=
  AnyTrue[
    {"\:30d5\:30a1\:30a4\:30eb", "\:4e00\:89a7", "\:30ea\:30b9\:30c8", "file", "list",
     "NotebookDirectory", "\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:30d5\:30a9\:30eb\:30c0", "\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:30c7\:30a3\:30ec\:30af\:30c8\:30ea",
     "\:30c7\:30b9\:30af\:30c8\:30c3\:30d7", "Desktop", "\:30d5\:30a9\:30eb\:30c0", "directory", "dir",
     "folder", "ls", "\:691c\:7d22", "search", "\:63a2"},
    StringContainsQ[prompt, #, IgnoreCase -> True] &
  ] ||
  (* 明示的なファイル名参照: xxx.pdf 等 *)
  StringContainsQ[prompt,
    RegularExpression["[\\w\\x{3000}-\\x{9fff}]+\\.(pdf|nb|csv|xlsx?|txt|wl|wls|py|md|json|html|tex|dat|svg|png|jpg)"]];
iNeedsFileList[""] := False;
iNeedsFileList[_] := False;

(* プロンプトに注入するファイルアクセス情報を生成する。
   userPrompt: ユーザーが入力した質問/タスク文字列。
   NotebookDirectory のファイル一覧は以下の条件で含める:
     - Read 許可済み → 常に含める
     - Read 未許可 → iNeedsFileList[userPrompt] が True のときだけ含める
   $packageDirectory のパッケージ一覧は常に含める。 *)
iFileAccessContext[userPrompt_String:""] := Module[
  {nbDir, workDir, lines = {}, attachments, nbFiles, pkgDir, wlFiles, pacletDirs, pkgNames,
   nbDirReadable = False, includeFileList = False, fileCount = 0},
  nbDir = Quiet @ Check[NotebookDirectory[InputNotebook[]], None];
  workDir = iClaudeWorkingDirectory[];
  pkgDir = Global`$packageDirectory;

  AppendTo[lines, "=== File Access Context ==="];

  (* $packageDirectory \:306e\:30d1\:30c3\:30b1\:30fc\:30b8\:4e00\:89a7: \:5e38\:306b\:542b\:3081\:308b *)
  If[StringQ[pkgDir] && DirectoryQ[pkgDir],
    AppendTo[lines, "$packageDirectory: " <> pkgDir];
    wlFiles = Quiet @ FileNames["*.wl", pkgDir];
    pacletDirs = Select[Quiet @ FileNames["*", pkgDir],
      DirectoryQ[#] && FileExistsQ[FileNameJoin[{#, "PacletInfo.wl"}]] &];
    pkgNames = Join[
      ("  - " <> FileBaseName[#] <> ".wl (" <>
        ToString[FileByteCount[#]] <> " bytes, " <>
        DateString[FileDate[#], {"Year","/","Month","/","Day"," ","Hour",":","Minute"}] <>
        ")") & /@ wlFiles,
      ("  - " <> FileNameTake[#] <> "/ [Paclet]") & /@ pacletDirs];
    If[Length[pkgNames] > 0,
      AppendTo[lines, "Packages in $packageDirectory (" <> ToString[Length[pkgNames]] <> "):"];
      Scan[AppendTo[lines, #] &, Take[pkgNames, UpTo[30]]]]];

  (* NotebookDirectory のアクセス状態を判定 *)
  If[StringQ[nbDir] && DirectoryQ[nbDir],
    nbDirReadable = iIsSafeDefaultDir[nbDir] ||
      MemberQ[If[ListQ[$ClaudeAccessibleDirs], $ClaudeAccessibleDirs, {}], nbDir];
    nbFiles = Quiet @ FileNames["*", nbDir];
    nbFiles = Select[nbFiles, !DirectoryQ[#] &];
    fileCount = Length[nbFiles];
    (* ファイル一覧を含めるかの判定 *)
    includeFileList = nbDirReadable || iNeedsFileList[userPrompt];
    AppendTo[lines, "NotebookDirectory: " <> nbDir <>
      If[nbDirReadable, " [Read \:8a31\:53ef]", " [Read \:4e0d\:53ef]"]];
    If[includeFileList,
      (* ファイル一覧を含める *)
      If[fileCount > 0,
        AppendTo[lines, "Files in NotebookDirectory (" <>
          ToString[fileCount] <> "):"];
        Do[AppendTo[lines, "  - " <> FileNameTake[f] <>
          " (" <> ToString[Quiet @ Check[FileByteCount[f], 0]] <> " bytes, " <>
          DateString[Quiet @ Check[FileDate[f], {2000}],
            {"Year","/","Month","/","Day"," ","Hour",":","Minute"}] <>
          ")"],
          {f, Take[nbFiles, UpTo[20]]}];
        If[fileCount > 20,
          AppendTo[lines, "  ... and " <> ToString[fileCount - 20] <> " more"]],
      (* ファイルなし *)
      AppendTo[lines, "(NotebookDirectory is empty)"]],
      (* ファイル一覧を省略 *)
      AppendTo[lines, "(" <> ToString[fileCount] <>
        " files \:2014 use \"\:30d5\:30a1\:30a4\:30eb\:4e00\:89a7\" or similar keyword to see the list)"]]];

  attachments = If[ListQ[$iCurrentSessionAttachments],
    Select[$iCurrentSessionAttachments, StringQ[#] && FileExistsQ[#] &], {}];
  If[Length[attachments] > 0,
    AppendTo[lines, "Session Attachments:"];
    Do[AppendTo[lines, "  - " <> a], {a, attachments}]];

  If[nbDirReadable,
    AppendTo[lines, "IMPORTANT: When files from NotebookDirectory or attachments " <>
      "are referenced in a prompt, Claude Code reads their actual content via the Read tool. " <>
      "The data in the generated code comes from these real files, not from fabrication. " <>
      "Always acknowledge file sources accurately."],
    If[StringQ[nbDir] && DirectoryQ[nbDir],
      AppendTo[lines, "RESTRICTION: NotebookDirectory file listing is for reference only. " <>
        "Do NOT use the Read tool to read file contents from NotebookDirectory. " <>
        "The user has not granted Read permission for this directory. " <>
        "If the user asks you to read or process a file from NotebookDirectory, " <>
        "tell them to run: AppendTo[$ClaudeAccessibleDirs, \"" <> nbDir <> "\"] " <>
        "to grant Read permission."]]];

  StringJoin[Riffle[lines, "\n"]] <> "\n\n"
];

(* ディレクトリパスから Read 許可文字列を生成 *)
iMakeReadPermission[dir_String] :=
  "Read(" <> StringReplace[StringReplace[dir, "\\" -> "/"],
    RegularExpression["/+$"] -> ""] <> "/*" <> "*)";

(* settings.json に Read 許可を注入する *)
iInjectSettingsPermissions[settingsFile_String, dirs_List] :=
  Module[{json, perms, allow, newAllow, newEntries, strm},
    json = If[FileExistsQ[settingsFile],
      Quiet @ Check[ImportString[Import[settingsFile, "Text"], "RawJSON"], <||>],
      <||>];
    If[!AssociationQ[json], json = <||>];

    perms = Lookup[json, "permissions", <||>];
    If[!AssociationQ[perms], perms = <||>];
    allow = Lookup[perms, "allow", {}];
    If[!ListQ[allow], allow = {}];

    newEntries = iMakeReadPermission /@ dirs;
    newAllow = DeleteDuplicates[Join[allow, newEntries]];
    perms = <|perms, "allow" -> newAllow|>;
    json  = <|json,  "permissions" -> perms|>;

    If[!DirectoryQ[DirectoryName[settingsFile]],
      CreateDirectory[DirectoryName[settingsFile],
        CreateIntermediateDirectories -> True]];
    strm = OpenWrite[settingsFile, BinaryFormat -> True];
    BinaryWrite[strm, ExportString[
      ExportString[json, "RawJSON"], "Text", CharacterEncoding -> "UTF-8"]];
    Close[strm];
  ];

iPrepareClaudeProjectDirectory[] := Module[
  {srcDir, tempDir, src, dst, rulesSrc, rulesDst, skillsSrc, skillsDst, accessDirs},
  srcDir = iEnsureClaudeWorkingDirectory[];
  tempDir = FileNameJoin[{
    $TemporaryDirectory,
    "claude_project_" <> ToString[UnixTime[]] <> "_" <> ToString[RandomInteger[99999]]
  }];
  CreateDirectory[tempDir, CreateIntermediateDirectories -> True];

  src = FileNameJoin[{srcDir, "CLAUDE.md"}];
  If[FileExistsQ[src],
    Quiet @ CopyFile[
      src,
      FileNameJoin[{tempDir, "CLAUDE.md"}],
      OverwriteTarget -> True
    ]
  ];

  src = FileNameJoin[{srcDir, ".claude", "CLAUDE.md"}];
  dst = FileNameJoin[{tempDir, ".claude", "CLAUDE.md"}];
  If[FileExistsQ[src],
    If[!DirectoryQ[DirectoryName[dst]],
      CreateDirectory[DirectoryName[dst], CreateIntermediateDirectories -> True]
    ];
    Quiet @ CopyFile[src, dst, OverwriteTarget -> True]
  ];

  rulesSrc = FileNameJoin[{srcDir, ".claude", "rules"}];
  rulesDst = FileNameJoin[{tempDir, ".claude", "rules"}];
  If[DirectoryQ[rulesSrc],
    iCopyDirectoryRecursive[rulesSrc, rulesDst]
  ];

  (* skills/ をコピー *)
  skillsSrc = FileNameJoin[{srcDir, ".claude", "skills"}];
  skillsDst = FileNameJoin[{tempDir, ".claude", "skills"}];
  If[DirectoryQ[skillsSrc],
    iCopyDirectoryRecursive[skillsSrc, skillsDst]
  ];

  (* settings.json をコピー *)
  src = FileNameJoin[{srcDir, ".claude", "settings.json"}];
  dst = FileNameJoin[{tempDir, ".claude", "settings.json"}];
  If[FileExistsQ[src],
    If[!DirectoryQ[DirectoryName[dst]],
      CreateDirectory[DirectoryName[dst], CreateIntermediateDirectories -> True]
    ];
    Quiet @ CopyFile[src, dst, OverwriteTarget -> True]
  ];

  (* アクセス可能ディレクトリ + 一時ディレクトリ自体の Read 許可を settings.json に注入 *)
  accessDirs = DeleteDuplicates[Append[iCollectAccessibleDirs[], tempDir]];
  iInjectSettingsPermissions[dst, accessDirs];

  tempDir
];

iLoadClaudeMD[] := Module[{candidates, found, nbf, workDir},
  workDir = iClaudeWorkingDirectory[];
  nbf = Quiet @ Check[NotebookFileName[EvaluationNotebook[]], $Failed];
  candidates = DeleteDuplicates @ DeleteCases[
    {
      If[StringQ[$ClaudeMDPath] && $ClaudeMDPath =!= "", $ClaudeMDPath, Nothing],
      If[StringQ[nbf] && nbf =!= "",
        FileNameJoin[{DirectoryName[nbf], ".claude", "CLAUDE.md"}], Nothing],
      If[StringQ[nbf] && nbf =!= "",
        FileNameJoin[{DirectoryName[nbf], "CLAUDE.md"}], Nothing],
      If[StringQ[workDir] && workDir =!= "",
        FileNameJoin[{workDir, ".claude", "CLAUDE.md"}], Nothing],
      If[StringQ[workDir] && workDir =!= "",
        FileNameJoin[{workDir, "CLAUDE.md"}], Nothing],
      Quiet @ If[StringQ[$InputFileName] && $InputFileName =!= "",
        FileNameJoin[{DirectoryName[$InputFileName], ".claude", "CLAUDE.md"}], Nothing],
      Quiet @ If[StringQ[$InputFileName] && $InputFileName =!= "",
        FileNameJoin[{DirectoryName[$InputFileName], "CLAUDE.md"}], Nothing],
      Quiet @ If[StringQ[Global`$packageDirectory] && Global`$packageDirectory =!= "",
        FileNameJoin[{Global`$packageDirectory, ".claude", "CLAUDE.md"}], Nothing],
      Quiet @ If[StringQ[Global`$packageDirectory] && Global`$packageDirectory =!= "",
        FileNameJoin[{Global`$packageDirectory, "CLAUDE.md"}], Nothing],
      FileNameJoin[{Directory[], ".claude", "CLAUDE.md"}],
      FileNameJoin[{Directory[], "CLAUDE.md"}]
    },
    _?(Function[x, !StringQ[x] || StringTrim[x] === ""])
  ];

  found = SelectFirst[candidates, FileExistsQ, ""];
  $ClaudeMDPath = found;
  $ClaudeMDContent = If[found === "", "", Quiet @ Import[found, "Text"]];
  $ClaudeMDContent
];

iLoadClaudeMD[];

(* \\:30d7\\:30ed\\:30f3\\:30d7\:30c8\\:5148\\:982d\:306b CLAUDE.md \\:3092\\:7d44\\:307f\\:8fbc\\:3080\\:30d8\:30eb\\:30d1\\:30fc *)
iClaudeSysPrompt[] :=
  If[$ClaudeMDContent =!= "",
    "## Project guidelines (CLAUDE.md)\n\n" <> $ClaudeMDContent <> "\n\n---\n\n",
    ""
  ] <> $claudeMathPromptPrefix;


(* \:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500
   \:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:51fa\:529b\:30d8\:30eb\:30d1\:30fc
   \:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500 *)
(* \:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:51fa\:529b\:30d8\:30eb\:30d1\:30fc (\:5185\:90e8\:4e92\:63db\:5c64) \:2192 NBAccess\:306b\:59d4\:8b72
   非同期コールバック中にユーザーが別のセルを編集していても、
   常にノートブック末尾に追記することでセル破損を防止する。 *)
nbPrint[nb_, text_String, style_String:"Text"] :=
  NBAccess`NBWriteText[nb, text, style];

(* Style 付きテキストのオーバーロード *)
nbPrint[nb_, text_Style, ___] :=
  NotebookWrite[nb,
    Cell[BoxData[ToBoxes[text]], "Text"], After];

(* 2つ以上のアンダースコアを含む変数名を修正
   tiling3_12_12 → tiling3X12X12 (Mathematica でパターン解釈されるのを防ぐ)
   tiling_12 は Subscript[tiling, 12] として正当なので変換しない
   x_, x_Integer, x__ 等のパターン構文も変換しない *)
iSanitizeUnderscoreVarNames[code_String] :=
  Module[{matches, result = code},
    (* _が2回以上出現する識別子を検出 *)
    matches = Union @ StringCases[code,
      RegularExpression["[a-zA-Z][a-zA-Z0-9]*(?:_[a-zA-Z0-9]+){2,}"]];
    (* 各マッチの _ を X に置換 *)
    Do[result = StringReplace[result,
        m -> StringReplace[m, "_" -> "X"]],
      {m, matches}];
    result
  ];

(* コード文字列を構文カラーリング付き Input セルとして書き込む → NBAccessに委譲 *)
iWriteCodeCell[nb_NotebookObject, code_String] := (
  NBAccess`NBWriteCode[nb, iSanitizeUnderscoreVarNames[code]]);

(* CellPrintパターンを自動検出してスマートにセルを書き込む → NBAccessに委譲 *)
iWriteSmartCell[nb_, code_String, autoEvaluate_:False] :=
  Module[{sanitized},
    sanitized = iSanitizeUnderscoreVarNames[code];
    NBAccess`NBWriteSmartCode[nb, sanitized];
    If[TrueQ[autoEvaluate],
      NBAccess`NBEvaluatePreviousCell[nb]]
  ];

(* cellToText は NBAccess`NBCellExprToText に統合済み。後方互換エイリアス *)
cellToText[cellExpr_] := NBAccess`NBCellExprToText[cellExpr];

(* セクションヘッダーを EvaluationCell の直前に挿入する。
   これにより入力セル自体も新しいセルグループに含まれる。
   EvaluationCell が取得できない場合はフォールバックとして通常の After 挿入。 *)
iWriteSectionHeaderBeforeEvalCell[nb_NotebookObject, title_String] :=
  Module[{evalCell, headerCell},
    evalCell = Quiet[EvaluationCell[]];
    headerCell = Cell[title, "Subsubsection",
      CellGroupingRules -> {"SectionGrouping", 68}];
    If[Head[evalCell] === CellObject,
      (* EvaluationCell の前にヘッダーを挿入し、EvalCell の後に移動 *)
      Quiet[SelectionMove[evalCell, Before, Cell]];
      NotebookWrite[nb, headerCell, After];
      Quiet[SelectionMove[evalCell, After, Cell]],
      (* フォールバック: 末尾に追記 *)
      Quiet[SelectionMove[nb, After, Notebook]];
      NBAccess`NBWriteCell[nb, headerCell]
    ]
  ];

(* ============================================================
   \:79d8\:5bc6\:30bb\:30eb\:7ba1\:7406
   \:8a2d\:8a08:
     \:30fbTaggingRules {"claudecode" -> {"confidential" -> True|False}}
       True  = \:6a5f\:5bc6\:ff08\:30d7\:30ed\:30f3\:30d7\:30c8\:9664\:5916\:ff09
       False = \:660e\:793a\:7684\:306b\:975e\:6a5f\:5bc6\:ff08Unmark\:6e08\:307f\:3001\:81ea\:52d5\:30b9\:30ad\:30e3\:30f3\:3067\:518d\:30de\:30fc\:30af\:3057\:306a\:3044\:ff09
       \:30ad\:30fc\:306a\:3057 = \:672a\:5224\:5b9a\:ff08\:81ea\:52d5\:30b9\:30ad\:30e3\:30f3\:306e\:5bfe\:8c61\:ff09
     \:30fb$confidentialSymbols \:3067\:6a5f\:5bc6\:5909\:6570\:540d\:3092\:8ffd\:8de1
     \:30fb$NBConfidentialSymbols (NBAccess) \:306b\:30d7\:30e9\:30a4\:30d0\:30b7\:30fc\:30ec\:30d9\:30eb\:4ed8\:304d\:3067\:540c\:671f
     \:30fbScanConfidentialCells[] \:3067\:4f1d\:64ad\:30de\:30fc\:30ad\:30f3\:30b0
     \:30fbiCaptureNotebookContext \:3067\:30d7\:30ed\:30f3\:30d7\:30c8\:69cb\:7bc9\:6642\:306b\:81ea\:52d5\:9664\:5916
   ============================================================ *)

(* \:6a5f\:5bc6\:5909\:6570\:540d\:306e\:8ffd\:8de1\:30c6\:30fc\:30d6\:30eb: <|\"\:5909\:6570\:540d\" -> True, ...|> *)
If[!AssociationQ[$confidentialSymbols], $confidentialSymbols = <||>];
If[!AssociationQ[$confVarTimes], $confVarTimes = <||>];
If[!AssociationQ[$allConfidentialVars], $allConfidentialVars = <||>];

(* インクリメンタル依存グラフキャッシュ:
   iPrecisionConfidentialCheck が全NB統合依存グラフを構築した際に、
   グラフと最終 $Line を記録する。次回呼び出し時は新しいセルのみ追加走査。 *)
If[!AssociationQ[$iGlobalDepsCache], $iGlobalDepsCache = <||>];
If[!IntegerQ[$iGlobalDepsCacheLastLine], $iGlobalDepsCacheLastLine = 0];

(* \:79d8\:5bc6\:5909\:6570\:3092\:767b\:9332\:3059\:308b\:30d8\:30eb\:30d1\:30fc:
   ClaudeCode\:5185\:90e8\:306e $confidentialSymbols \:3068
   NBAccess\:516c\:958b\:306e $NBConfidentialSymbols \:306e\:4e21\:65b9\:3092\:540c\:671f\:3059\:308b\:3002
   \:5c06\:6765\:306f\:30bb\:30eb\:3054\:3068\:306e PrivacyLevel \:3092\:5c0e\:5165\:3059\:308b\:4e88\:5b9a\:3060\:304c\:3001
   \:73fe\:6642\:70b9\:3067\:306f\:79d8\:5bc6\:5909\:6570\:306f\:4e00\:5f8b 1.0 \:3068\:3059\:308b\:3002 *)
iRegisterConfidentialVar[name_String] := (
  $confidentialSymbols[name] = True;
  NBAccess`NBRegisterConfidentialVar[name, 1.0];
  (* \:6a5f\:5bc6\:5316\:6642\:523b\:3092\:8a18\:9332\:3057\:3066\:5c65\:6b74\:30d5\:30a3\:30eb\:30bf\:306b\:4f7f\:7528 *)
  $confVarTimes[name] = AbsoluteTime[]
);
iRegisterConfidentialVars[names_List] :=
  Scan[iRegisterConfidentialVar, names];

(* \:5909\:6570\:540d\:3092\:6a5f\:5bc6\:30c6\:30fc\:30d6\:30eb\:304b\:3089\:524a\:9664 *)
iUnregisterConfidentialVar[name_String] := (
  $confidentialSymbols = KeyDrop[$confidentialSymbols, name];
  NBAccess`NBUnregisterConfidentialVar[name]
);
iUnregisterConfidentialVars[names_List] :=
  Scan[iUnregisterConfidentialVar, names];

(* \:6a5f\:5bc6\:30bb\:30eb\:306e\:8996\:899a\:30b9\:30bf\:30a4\:30eb: NBAccess \:306b\:5b9a\:7fa9\:3092\:59d4\:8b72 *)
$confidentialCellOpts := NBAccess`$NBConfidentialCellOpts;

(* \:2500\:2500\:2500 TaggingRules \:64cd\:4f5c \:2500\:2500\:2500 *)

(* TaggingRules \:64cd\:4f5c: NBAccess \:306b\:59d4\:8b72 *)
iSetConfidentialTagValue[nb_NotebookObject, cellIdx_Integer, val_] :=
  NBAccess`NBSetConfidentialTag[nb, cellIdx, val];

(* \:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:5185\:306e\:6a5f\:5bc6\:30bb\:30eb\:304b\:3089\:5909\:6570\:540d\:3092\:518d\:69cb\:7bc9 *)
iSetConfidentialTag[nb_NotebookObject, cellIdx_Integer] := iSetConfidentialTagValue[nb, cellIdx, True];

(* TaggingRules \:8aad\:307f\:53d6\:308a: NBAccess \:306b\:59d4\:8b72 *)
iGetConfidentialTag[nb_NotebookObject, cellIdx_Integer] :=
  NBAccess`NBGetConfidentialTag[nb, cellIdx];

(* \:660e\:793a\:7684\:306b\:6a5f\:5bc6\:30bf\:30b0\:4ed8\:304d? *)
iIsConfidentialCell[nb_NotebookObject, cellIdx_Integer] := TrueQ[iGetConfidentialTag[nb, cellIdx]];

(* \:660e\:793a\:7684\:306b\:975e\:6a5f\:5bc6\:ff08Unmark\:6e08\:307f\:ff09? *)
iIsExplicitlyUnmarked[nb_NotebookObject, cellIdx_Integer] := (iGetConfidentialTag[nb, cellIdx] === False);

(* \:2500\:2500\:2500 \:5909\:6570\:540d\:8ffd\:8de1 \:2500\:2500\:2500 *)

(* Held \:5f0f\:304b\:3089\:4ee3\:5165\:5148\:30b7\:30f3\:30dc\:30eb\:540d\:3092\:62bd\:51fa *)
SetAttributes[iExtractAssigned, HoldAll];
iExtractAssigned[expr_] :=
  DeleteDuplicates @ Cases[
    HoldComplete[expr],
    HoldPattern[Set[s_, _]] /; Head[Unevaluated[s]] === Symbol :>
      SymbolName[Unevaluated[s]],
    {0, Infinity}
  ];

(* \:30bb\:30eb\:5185\:5bb9\:304c\:6a5f\:5bc6\:5909\:6570\:3092\:53c2\:7167\:3057\:3066\:3044\:308b\:304b *)
(* \:79d8\:5bc6\:5909\:6570\:3092\:53c2\:7167\:3057\:3066\:3044\:308b\:304b\:5224\:5b9a (\:5185\:90e8\:7528: ScanConfidentialCells, CellEpilog) *)
(* iCellUsesConfidentialSymbol は NBAccess`NBCellUsesConfidentialSymbol に移設 *)

(* \:30d7\:30ed\:30f3\:30d7\:30c8\:304b\:3089\:9664\:5916\:3059\:3079\:304d\:304b\:ff1f\:ff08\:5185\:90e8\:5224\:5b9a\:ff09
   NBGetContext \:304c NBAccess`NBIsAccessible \:3092\:4f7f\:7528\:3059\:308b\:306e\:3067\:3001
   \:3053\:306e\:95a2\:6570\:306f\:30d1\:30ec\:30c3\:30c8\:306a\:3069\:5185\:90e8\:51e6\:7406\:5411\:3051\:306b\:6b8b\:3059 *)
(* iShouldExcludeFromPrompt は NBAccess`NBShouldExcludeFromPrompt に移設 *)

(* \:30bb\:30eb\:5185\:5bb9\:304b\:3089 Set/SetDelayed \:306e LHS \:5909\:6570\:540d\:3092\:62bd\:51fa\:ff08\:6c4e\:7528\:ff09 *)
(* iExtractCellVarNames は NBAccess`NBCellExtractVarNames に移設 *)

(* \:2500\:2500\:2500 \:516c\:958b API \:2500\:2500\:2500 *)

MarkConfidential[nb_NotebookObject, cellIdx_Integer] := (
  iSetConfidentialTag[nb, cellIdx];
  NBAccess`NBCellSetOptions[nb, cellIdx, Sequence @@ $confidentialCellOpts];
  iRegisterConfidentialVars[NBAccess`NBCellExtractVarNames[nb, cellIdx]];
  iEnsureCellEpilog[nb];
  ScanConfidentialCells[nb];
  cellIdx
);

MarkConfidential[] :=
  Module[{nb = Quiet[EvaluationNotebook[]], idx},
    If[Head[nb] =!= NotebookObject, Return[$Failed]];
    idx = NBAccess`NBCurrentCellIndex[nb];
    If[idx === 0, Return[$Failed]];
    MarkConfidential[nb, idx]
  ];

(* \:660e\:793a\:7684 Unmark: NBAccess`NBUnmarkCell \:306b\:59d4\:8b72 *)
UnmarkConfidential[nb_NotebookObject, cellIdx_Integer] := (
  iUnregisterConfidentialVars[NBAccess`NBCellExtractVarNames[nb, cellIdx]];
  NBAccess`NBUnmarkCell[nb, cellIdx];
  cellIdx
);

UnmarkConfidential[] :=
  Module[{nb = Quiet[EvaluationNotebook[]], idx},
    If[Head[nb] =!= NotebookObject, Return[$Failed]];
    idx = NBAccess`NBCurrentCellIndex[nb];
    If[idx === 0, Return[$Failed]];
    UnmarkConfidential[nb, idx]
  ];
IsConfidential[nb_NotebookObject, cellIdx_Integer] := iIsConfidentialCell[nb, cellIdx];
IsConfidential[] :=
  Module[{nb = Quiet[EvaluationNotebook[]], idx},
    If[Head[nb] =!= NotebookObject, Return[False]];
    idx = NBAccess`NBCurrentCellIndex[nb];
    If[idx === 0, Return[False]];
    iIsConfidentialCell[nb, idx]
  ];

(* \:2500\:2500\:2500 Confidential \:30e9\:30c3\:30d1\:30fc \:2500\:2500\:2500 *)

(* \:30bb\:30eb\:5185\:5bb9\:30c6\:30ad\:30b9\:30c8\:304b\:3089\:4ee3\:5165\:5148\:5909\:6570\:540d\:3092\:62bd\:51fa\:ff08var = Confidential[...] \:5f62\:5f0f\:5bfe\:5fdc\:ff09 *)
(* iExtractCellAssignedNames は NBAccess`NBCellExtractAssignedNames に移設 *)

SetAttributes[Confidential, HoldFirst];
Confidential[expr_] :=
  Module[{nb, cellIdx, result, assignedNames, cellNames},
    nb = Quiet[EvaluationNotebook[]];
    cellIdx = If[Head[nb] === NotebookObject,
      NBAccess`NBCurrentCellIndex[nb], 0];
    assignedNames = iExtractAssigned[expr];
    cellNames = If[cellIdx > 0,
      NBAccess`NBCellExtractAssignedNames[nb, cellIdx], {}];
    assignedNames = DeleteDuplicates[Join[assignedNames, cellNames]];
    result = expr;
    iRegisterConfidentialVars[assignedNames];
    If[cellIdx > 0,
      iSetConfidentialTag[nb, cellIdx];
      NBAccess`NBCellSetOptions[nb, cellIdx, Sequence @@ $confidentialCellOpts]
    ];
    $pendingConfidentialMark = True;
    iEnsureCellEpilog[];
    If[cellIdx > 0, iDeferOutputMark[nb, cellIdx]];
    result
  ];

(* ─── NonConfidential ラッパー ─── *)
(* 秘密変数や秘密依存変数の値に依存していても、機密解除として扱う。
   セルの confidential タグを明示的に False に設定し、
   CellEpilog による自動伝播マーキングをスキップさせる。 *)

SetAttributes[NonConfidential, HoldFirst];
NonConfidential[expr_] :=
  Module[{nb, cellIdx, result, nCells},
    nb = Quiet[EvaluationNotebook[]];
    cellIdx = If[Head[nb] === NotebookObject,
      NBAccess`NBCurrentCellIndex[nb], 0];
    result = expr;
    (* Input セルを明示的に非機密マーク（False） *)
    If[cellIdx > 0,
      iSetConfidentialTagValue[nb, cellIdx, False];
      (* 視覚スタイルを通常に戻す *)
      NBAccess`NBCellSetOptions[nb, cellIdx,
        Background -> None, CellFrame -> None,
        CellDingbat -> None]
    ];
    (* Output セルも明示的に非機密マーク *)
    If[cellIdx > 0, iDeferOutputUnmark[nb, cellIdx]];
    result
  ];

(* Output セルを非同期で明示的に非機密マーク *)
iDeferOutputUnmark[nb_NotebookObject, cellIdx_Integer] :=
  With[{pNb = nb, icIdx = cellIdx},
    SessionSubmit[
      Module[{nCells, attempts = 0, ocStyle},
        While[attempts < 15,
          Pause[0.3];
          attempts++;
          nCells = NBAccess`NBCellCount[pNb];
          If[nCells > 0 && icIdx > 0 && icIdx < nCells,
            ocStyle = NBAccess`NBCellStyle[pNb, icIdx + 1];
            If[MemberQ[{"Output", "Print"}, ocStyle],
              ClaudeCode`Private`iSetConfidentialTagValue[pNb, icIdx + 1, False];
              NBAccess`NBCellSetOptions[pNb, icIdx + 1,
                Background -> None, CellFrame -> None,
                CellDingbat -> None];
              Break[]
            ]
          ]
        ]
      ]
    ]
  ];

(* Output \:30bb\:30eb\:3092\:30dd\:30fc\:30ea\:30f3\:30b0\:3067\:30de\:30fc\:30af\:ff08SessionSubmit \:3067\:975e\:540c\:671f\:5b9f\:884c\:ff09 *)
(* CellEpilog \:306e\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:3068\:3057\:3066\:6a5f\:80fd *)
iDeferOutputMark[nb_NotebookObject, cellIdx_Integer] :=
  With[{pNb = nb, icIdx = cellIdx},
    SessionSubmit[
      Module[{nCells, attempts = 0, ocStyle},
        While[attempts < 15,
          Pause[0.3];
          attempts++;
          nCells = NBAccess`NBCellCount[pNb];
          If[nCells > 0 && icIdx > 0 && icIdx < nCells,
            ocStyle = NBAccess`NBCellStyle[pNb, icIdx + 1];
            If[MemberQ[{"Output", "Print"}, ocStyle],
              If[!TrueQ[ClaudeCode`Private`iIsConfidentialCell[pNb, icIdx + 1]],
                ClaudeCode`Private`iSetConfidentialTag[pNb, icIdx + 1];
                NBAccess`NBCellSetOptions[pNb, icIdx + 1,
                  Sequence @@ ClaudeCode`Private`$confidentialCellOpts]
              ];
              Break[]
            ]
          ]
        ]
      ]
    ]
  ];

(* \:2500\:2500\:2500 CellEpilog \:30d9\:30fc\:30b9\:306e\:81ea\:52d5\:30de\:30fc\:30ad\:30f3\:30b0 \:2500\:2500\:2500 *)
(* \:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:30ec\:30d9\:30eb\:306e CellEpilog \:3067\:3001\:5404\:30bb\:30eb\:8a55\:4fa1\:5f8c\:306b\:6a5f\:5bc6\:5909\:6570\:53c2\:7167\:3092\:81ea\:52d5\:691c\:51fa *)

$pendingConfidentialMark = False;

iConfidentialCellEpilog[] := Quiet @ Module[
  {nb, idx, nCells, inputText, ocStyle},
  nb = NBAccess`NBParentNotebookOfCurrentCell[];
  If[Head[nb] =!= NotebookObject, Return[]];
  idx = NBAccess`NBCurrentCellIndex[nb];
  If[idx < 1, Return[]];
  nCells = NBAccess`NBCellCount[nb];

  (* Case 1: Confidential[] \:76f4\:5f8c \:2192 Input \:76f4\:5f8c\:306e Output \:3092\:30de\:30fc\:30af *)
  If[TrueQ[$pendingConfidentialMark],
    $pendingConfidentialMark = False;
    If[idx < nCells,
      ocStyle = NBAccess`NBCellStyle[nb, idx + 1];
      If[MemberQ[{"Output", "Print"}, ocStyle],
        iSetConfidentialTag[nb, idx + 1];
        NBAccess`NBCellSetOptions[nb, idx + 1, Sequence @@ $confidentialCellOpts]
      ]
    ];
    Return[]
  ];

  (* Case 2: Input セル自体が秘密マーク済み → 直後の Output も秘密マーク
     iAutoMarkNewCellsConfidential 等でマークされたセルの評価結果を保護 *)
  If[MemberQ[{"Input", "Code"}, NBAccess`NBCellStyle[nb, idx]] &&
     iIsConfidentialCell[nb, idx] &&
     idx < nCells,
    ocStyle = NBAccess`NBCellStyle[nb, idx + 1];
    If[MemberQ[{"Output", "Print"}, ocStyle] &&
       !TrueQ[NBAccess`NBGetConfidentialTag[nb, idx + 1]],
      iSetConfidentialTag[nb, idx + 1];
      NBAccess`NBCellSetOptions[nb, idx + 1, Sequence @@ $confidentialCellOpts]
    ];
    Return[]
  ];

  (* Case 3: 機密変数に依存する Input → 直後の Output セルのみ依存秘密マーク（橙）
     Input セル自体は式（変数名）を含むだけで公開情報なのでマークしない。
     InputText 形式を使用して 2D 表示を正しく解析。 *)
  If[Length[$confidentialSymbols] > 0 &&
     MemberQ[{"Input", "Code"}, NBAccess`NBCellStyle[nb, idx]] &&
     !iIsConfidentialCell[nb, idx] &&
     !iIsExplicitlyUnmarked[nb, idx],
    inputText = NBAccess`NBCellReadInputText[nb, idx];
    If[!StringQ[inputText] || inputText === "", Return[]];
    If[StringContainsQ[inputText,
         RegularExpression["[\\p{L}$][\\p{L}\\p{N}$]*\\s*\\[[^\\]]*_[^\\]]*\\]\\s*:?="]],
      Return[]];
    If[AnyTrue[{"ClaudeQuery","ClaudeEval","ContinueEval","ClaudeMath",
                 "ClaudeSpec","ClaudeExtractCode","ClaudeExtractAllCode"},
          StringContainsQ[inputText, RegularExpression["\\b" <> # <> "\\s*\\["]] &],
      Return[]];
    Module[{assigns, rhsVars, confKeys, isDependent = False},
      confKeys = Keys[$confidentialSymbols];
      assigns = Quiet[NBAccess`NBExtractAssignments[inputText]];
      If[ListQ[assigns] && Length[assigns] > 0,
        rhsVars = DeleteDuplicates[Flatten[Last /@ assigns]];
        isDependent = Length[Intersection[rhsVars, confKeys]] > 0,
        isDependent = AnyTrue[confKeys,
          StringContainsQ[inputText,
            RegularExpression["(?<![\\p{L}\\p{N}$])" <> # <>
              "(?![\\p{L}\\p{N}$])"]] &]
      ];
      (* Input はマークしない。Output のみ橙マーク。
         ただし NonConfidential で明示解除済みなら上書きしない *)
      If[isDependent,
        (* === チェーン伝播: LHS 変数を $confidentialSymbols に登録 ===
           これにより a→b→d→y のような推移的依存が
           CellEpilog レベルで正しく検出される。
           例: b=2a で b が登録 → d=2c+b で d も登録 → y=2c+d で y も登録 *)
        If[ListQ[assigns] && Length[assigns] > 0,
          Do[With[{lhs = First[a]},
            If[!KeyExistsQ[$confidentialSymbols, lhs],
              $confidentialSymbols[lhs] = AbsoluteTime[]]],
            {a, assigns}]];
        If[idx < nCells,
          ocStyle = NBAccess`NBCellStyle[nb, idx + 1];
          If[MemberQ[{"Output", "Print"}, ocStyle] &&
             !iIsExplicitlyUnmarked[nb, idx + 1],
            NBAccess`NBMarkCellDependent[nb, idx + 1]]]]]
  ]
];

(* CellEpilog \:3092\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:306b\:30a4\:30f3\:30b9\:30c8\:30fc\:30eb *)
iInstallCellEpilog[] := iInstallCellEpilog[Quiet[EvaluationNotebook[]]];
iInstallCellEpilog[nb_NotebookObject] :=
  NBAccess`NBInstallConfidentialEpilog[nb,
    ClaudeCode`Private`iConfidentialCellEpilog[],
    ClaudeCode`Private`iConfidentialCellEpilog];

(* \:30ab\:30fc\:30cd\:30eb\:518d\:8d77\:52d5\:5f8c\:306a\:3069\:3001\:65e2\:5b58\:306e\:6a5f\:5bc6\:30bb\:30eb\:304b\:3089 $confidentialSymbols \:3068
   $NBConfidentialSymbols \:3092\:5fa9\:5143\:3059\:308b *)
iRebuildConfidentialSymbols[nb_NotebookObject] :=
  Module[{nCells},
    nCells = NBAccess`NBCellCount[nb];
    If[nCells === 0, Return[]];
    Do[
      With[{depTag = NBAccess`NBCellGetTaggingRule[nb, i, {"claudecode", "dependent"}]},
        If[iIsConfidentialCell[nb, i] && !TrueQ[depTag],
          iRegisterConfidentialVars[NBAccess`NBCellExtractVarNames[nb, i]]]],
      {i, nCells}]
  ];

(* \:5168\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:304b\:3089\:6a5f\:5bc6\:5909\:6570\:3092\:518d\:69cb\:7bc9 *)
iRebuildConfidentialSymbolsAll[] :=
  Module[{allNBs, nCells},
    allNBs = NBAccess`NBUserNotebooks[];
    If[!ListQ[allNBs], Return[]];
    Do[
      nCells = NBAccess`NBCellCount[nbx];
      If[nCells === 0, Continue[]];
      Do[
        With[{depTag = NBAccess`NBCellGetTaggingRule[nbx, i, {"claudecode", "dependent"}]},
          If[iIsConfidentialCell[nbx, i] && !TrueQ[depTag],
            iRegisterConfidentialVars[NBAccess`NBCellExtractVarNames[nbx, i]]]],
        {i, nCells}],
      {nbx, allNBs}]
  ];

(* インクリメンタル版: 前回結果をベースに、
   新しく評価されたセル (CellLabel In[x] で x > afterLine) のみ走査。
   既存の $confidentialSymbols は保持したまま差分追加する。 *)
iRebuildConfidentialSymbolsIncremental[afterLine_Integer] :=
  Module[{allNBs, cells, lineNum},
    allNBs = NBAccess`NBUserNotebooks[];
    If[!ListQ[allNBs], Return[]];
    Do[
      cells = Quiet[Cells[nbx]];
      If[!ListQ[cells], Continue[]];
      Do[Module[{lbl, num, tag, depTag},
        (* CellLabel から In[x] の x を取得 *)
        lbl = Quiet[CurrentValue[c, CellLabel]];
        If[!StringQ[lbl], Continue[]];
        num = First[StringCases[lbl,
          RegularExpression["In\\[(\\d+)\\]"] -> "$1"], None];
        If[num === None, Continue[]];
        lineNum = Quiet @ Check[ToExpression[num], 0];
        If[!IntegerQ[lineNum] || lineNum <= afterLine, Continue[]];
        (* このセルは前回チェック以降に評価された → 秘密チェック *)
        tag = Quiet[CurrentValue[c,
          {TaggingRules, "claudecode", "confidential"}]];
        depTag = Quiet[CurrentValue[c,
          {TaggingRules, "claudecode", "dependent"}]];
        If[TrueQ[tag] && !TrueQ[depTag],
          Module[{text, assigns},
            text = Quiet[NBAccess`iCellToInputText[c]];
            If[StringQ[text],
              assigns = NBAccess`NBExtractAssignments[text];
              Do[iRegisterConfidentialVar[First[a]], {a, assigns}]]]]],
      {c, cells}],
    {nbx, allNBs}]
  ];

(* CellEpilog \:304c\:30a4\:30f3\:30b9\:30c8\:30fc\:30eb\:6e08\:307f\:304b\:78ba\:8a8d\:3057\:3001\:672a\:8a2d\:5b9a\:306a\:3089\:30a4\:30f3\:30b9\:30c8\:30fc\:30eb *)
iEnsureCellEpilog[] := iEnsureCellEpilog[Quiet[EvaluationNotebook[]]];
iEnsureCellEpilog[nb_NotebookObject] :=
  Module[{},
    If[!NBAccess`NBConfidentialEpilogInstalledQ[nb, ClaudeCode`Private`iConfidentialCellEpilog],
      iInstallCellEpilog[nb];
      (* \:30ab\:30fc\:30cd\:30eb\:518d\:8d77\:52d5\:5f8c: \:65e2\:5b58\:306e\:6a5f\:5bc6\:30bb\:30eb\:304b\:3089\:5909\:6570\:540d\:3092\:5fa9\:5143 *)
      iRebuildConfidentialSymbols[nb]]
  ];

(* \:2500\:2500\:2500 \:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:5168\:4f53\:306e\:30b9\:30ad\:30e3\:30f3 \:2500\:2500\:2500 *)

ScanConfidentialCells[] := ScanConfidentialCells[Quiet[EvaluationNotebook[]]];
ScanConfidentialCells[nb_NotebookObject] :=
  Module[{nCells, directConfVars, n, deps, allDepVars},
    nCells = NBAccess`NBCellCount[nb];
    If[nCells === 0, Return[0]];
    (* シンボルテーブルを完全にクリアしてから再構築。
       前回の ClaudeQuery で設定された推移的依存変数を除去する *)
    $confidentialSymbols = <||>;
    $confVarTimes = <||>;
    $allConfidentialVars = <||>;
    NBAccess`NBClearConfidentialVars[];
    iRebuildConfidentialSymbolsAll[];
    Do[
      With[{tag = NBAccess`NBGetConfidentialTag[nb, i],
            depTag = NBAccess`NBCellGetTaggingRule[nb, i, {"claudecode", "dependent"}]},
        If[TrueQ[tag] && !TrueQ[depTag],
          iRegisterConfidentialVars[NBAccess`NBCellExtractVarNames[nb, i]]]],
      {i, nCells}];
    directConfVars = Keys[$confidentialSymbols];
    (* 依存セルを走査・マーキング *)
    n = NBAccess`NBScanDependentCells[nb, directConfVars];
    (* 推移的依存変数を $confidentialSymbols に反映
       （CellEpilog のチェーン伝播が後続セル評価で正しく動作するため） *)
    If[Length[directConfVars] > 0,
      deps = Quiet[NBAccess`NBBuildVarDependencies[nb]];
      If[AssociationQ[deps],
        allDepVars = Quiet[NBAccess`NBTransitiveDependents[deps, directConfVars]];
        If[ListQ[allDepVars],
          Do[If[!KeyExistsQ[$confidentialSymbols, v],
              $confidentialSymbols[v] = AbsoluteTime[]],
            {v, allDepVars}];
          $allConfidentialVars = Association[# -> True & /@ allDepVars];
          NBAccess`NBSetConfidentialVars[$allConfidentialVars]]]];
    n
  ];

(* ============================================================
   精密秘密依存チェック (第2層: LLM送信直前)
   全ノートブックを走査して完全な依存グラフを構築し、
   秘密依存変数の最終判定を行う。
   第1層 (CellEpilog) は現在NBのみの軽量チェック。
   第2層は全NB統合の精密チェックで、別NB経由の依存も検出する。
   ============================================================ *)

iPrecisionConfidentialCheck[nb_NotebookObject] :=
  Module[{directConfVars, globalDeps, allDepVars, localDeps,
          localDepVars, newlyFound, updateResult, currentLine,
          prevAllDepVars},

    currentLine = If[IntegerQ[$Line], $Line, 0];

    (* === 高速パス: 前回チェックから変化なし ===
       $Line が前回チェック時から 1 以下の増加（= ClaudeQuery 自身のみ）の場合、
       キャッシュが有効なので全NB走査をスキップ。
       FrontEnd round-trip を完全に回避し、0.01秒で完了する。 *)
    If[IntegerQ[$iGlobalDepsCacheLastLine] && $iGlobalDepsCacheLastLine > 0 &&
       currentLine <= $iGlobalDepsCacheLastLine + 1,
      $iGlobalDepsCacheLastLine = currentLine;
      Return[Length[$allConfidentialVars]]];

    (* === フルパス（新しいセルが評価された場合） ===
       ただし前回の結果を起点にインクリメンタルに更新する。 *)

    (* Cells[] キャッシュのスマートリフレッシュ:
       ModifiedInMemory=False のNBは FE call なしでスキップ。
       Cells[] リスト不変のNBもキャッシュ保持。
       返り値: 変化があったNBのリスト *)
    Module[{changedNBs = NBAccess`NBRefreshCellsCache[]},

    (* Step 1: 秘密変数の再構築
       前回の結果をベースに、新しく評価されたセル (In[x] > lastLine) のみ追加走査。 *)
    If[Length[$confidentialSymbols] > 0 && $iGlobalDepsCacheLastLine > 0,
      iRebuildConfidentialSymbolsIncremental[$iGlobalDepsCacheLastLine],
      $confidentialSymbols = <||>;
      $confVarTimes = <||>;
      NBAccess`NBClearConfidentialVars[];
      iRebuildConfidentialSymbolsAll[]];
    directConfVars = Keys[$confidentialSymbols];

    If[Length[directConfVars] === 0,
      $allConfidentialVars = <||>;
      NBAccess`NBSetConfidentialVars[<||>];
      $iGlobalDepsCacheLastLine = currentLine;
      Return[0]];

    (* Step 2: 現在NBの軽量版依存グラフ（Step 7 の通知比較用） *)
    localDeps = Quiet[NBAccess`NBBuildVarDependencies[nb]];
    If[!AssociationQ[localDeps], localDeps = <||>];
    localDepVars = Quiet[NBAccess`NBTransitiveDependents[localDeps, directConfVars]];
    If[!ListQ[localDepVars], localDepVars = directConfVars];

    (* Step 3: 全NB統合依存グラフ（インクリメンタル更新） *)
    If[AssociationQ[$iGlobalDepsCache] && Length[$iGlobalDepsCache] > 0 &&
       IntegerQ[$iGlobalDepsCacheLastLine] && $iGlobalDepsCacheLastLine > 0,
      updateResult = Quiet[
        NBAccess`NBUpdateGlobalVarDependencies[
          $iGlobalDepsCache, $iGlobalDepsCacheLastLine]];
      If[ListQ[updateResult] && Length[updateResult] === 2,
        globalDeps = updateResult[[1]],
        globalDeps = Quiet[NBAccess`NBBuildGlobalVarDependencies[]]],
      globalDeps = Quiet[NBAccess`NBBuildGlobalVarDependencies[]]];
    If[!AssociationQ[globalDeps], globalDeps = localDeps];
    $iGlobalDepsCache = globalDeps;

    (* Step 4: 推移的依存を計算 *)
    allDepVars = Quiet[NBAccess`NBTransitiveDependents[globalDeps, directConfVars]];
    If[!ListQ[allDepVars], allDepVars = directConfVars];

    (* Step 5: $allConfidentialVars を更新 *)
    prevAllDepVars = Keys[$allConfidentialVars];
    $allConfidentialVars = Association[# -> True & /@ allDepVars];
    NBAccess`NBSetConfidentialVars[$allConfidentialVars];

    (* Step 5b: $confidentialSymbols に推移的依存変数を反映 *)
    Do[If[!KeyExistsQ[$confidentialSymbols, v],
        $confidentialSymbols[v] = AbsoluteTime[]],
      {v, allDepVars}];

    (* Step 6: 依存セルの橙マーク更新
       allDepVars が変化した場合: 変化があったNBのみ走査。
       変化なし: CellEpilog インストールチェックのみ。 *)
    If[Sort[allDepVars] =!= Sort[prevAllDepVars],
      Module[{allNBs = NBAccess`NBUserNotebooks[], targetNBs},
        If[ListQ[allNBs],
          (* allDepVars が変化 + NB構造が変化したNBのみ走査。
             ただし初回 (prevAllDepVars が空) は全NB走査。 *)
          targetNBs = If[Length[prevAllDepVars] === 0,
            allNBs,
            If[Length[changedNBs] > 0, changedNBs, allNBs]];
          Do[
            Quiet @ Module[{},
              If[!NBAccess`NBConfidentialEpilogInstalledQ[nbx,
                   ClaudeCode`Private`iConfidentialCellEpilog],
                iInstallCellEpilog[nbx]];
              Quiet[NBAccess`NBScanDependentCells[nbx, allDepVars, globalDeps]]],
            {nbx, targetNBs}]]],
      Module[{allNBs = NBAccess`NBUserNotebooks[]},
        If[ListQ[allNBs],
          Do[If[!NBAccess`NBConfidentialEpilogInstalledQ[nbx,
                   ClaudeCode`Private`iConfidentialCellEpilog],
                iInstallCellEpilog[nbx]],
            {nbx, allNBs}]]]];

    (* Step 7: 新たに検出された秘密依存を通知 *)
    If[Sort[allDepVars] =!= Sort[prevAllDepVars],
      newlyFound = Complement[allDepVars, localDepVars];
      If[Length[newlyFound] > 0,
        Module[{msg},
          msg = "\[WarningSign] 精密チェック: 別ノートブック経由の秘密依存を " <>
                ToString[Length[newlyFound]] <> " 個検出しました (" <>
                StringRiffle[Take[newlyFound, UpTo[5]], ", "] <>
                If[Length[newlyFound] > 5, ", ...", ""] <>
                ")。これらはコンテキスト送信から除外されます。";
          NBAccess`NBWritePrintNotice[None, msg, RGBColor[0.85, 0.5, 0.1]]]]];

    ]; (* Module changedNBs end *)
    $iGlobalDepsCacheLastLine = currentLine;
    Length[allDepVars]
  ];

(* ============================================================
   アクセスレベル解決ヘルパー
   PrivacySpec と Model の両方から実効アクセスレベルを決定する。
   PrivacySpec が Automatic の場合:
     Model 指定あり {"provider",...} → そのプロバイダーの MaxAccessLevel
     Model 指定なし (Automatic)     → "claudecode" の MaxAccessLevel
   PrivacySpec が明示的 <|"AccessLevel"->n|> の場合: n を使用
   ============================================================ *)

(* modelSpec 付き: PrivacySpec が Automatic ならプロバイダーに応じて解決 *)
iResolveAccessLevel[Automatic, Automatic] :=
  NBAccess`NBGetProviderMaxAccessLevel["claudecode"];
iResolveAccessLevel[Automatic, modelSpec_List] :=
  If[Length[modelSpec] >= 1 && StringQ[modelSpec[[1]]],
    NBAccess`NBGetProviderMaxAccessLevel[modelSpec[[1]]],
    NBAccess`NBGetProviderMaxAccessLevel["claudecode"]];
iResolveAccessLevel[ps_Association, _] :=
  Lookup[ps, "AccessLevel", 0.5];
iResolveAccessLevel[_, _] :=
  NBAccess`NBGetProviderMaxAccessLevel["claudecode"];

(* 後方互換: modelSpec なし — "claudecode" プロバイダーとして解決 *)
iResolveAccessLevel[Automatic] :=
  NBAccess`NBGetProviderMaxAccessLevel["claudecode"];
iResolveAccessLevel[ps_Association] :=
  Lookup[ps, "AccessLevel", 0.5];
iResolveAccessLevel[_] :=
  NBAccess`NBGetProviderMaxAccessLevel["claudecode"];

(* ============================================================
   \:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:30b3\:30f3\:30c6\:30ad\:30b9\:30c8\:53ce\:96c6\:ff08\:6a5f\:5bc6\:9664\:5916\:4ed8\:304d\:ff09
   \:2192 NBAccess\:306e NBGetContext \:306b\:59d4\:8b72\:3002
   PrivacySpec \:306e\:30c7\:30a3\:30d5\:30a9\:30eb\:30c8 AccessLevel=0.5 \:3067
   \:79d8\:5bc6\:30bb\:30eb (1.0) \:3092\:9664\:5916\:3057\:305f\:30b3\:30f3\:30c6\:30ad\:30b9\:30c8\:6587\:5b57\:5217\:3092\:8fd4\:3059\:3002
   \:30ed\:30fc\:30ab\:30ebLLM\:74b0\:5883\:304b\:3089\:306f PrivacySpec \:3092\:660e\:793a\:6307\:5b9a\:3057\:3066\:547c\:3073\:51fa\:3059\:3053\:3068\:3002
   ============================================================ *)

iCaptureNotebookContext[nb_NotebookObject, afterIdx_Integer] :=
  NBAccess`NBGetContext[nb, afterIdx];

iCaptureNotebookContext[nb_NotebookObject, afterIdx_Integer, accessLevel_?NumericQ] :=
  NBAccess`NBGetContext[nb, afterIdx,
    PrivacySpec -> <|"AccessLevel" -> accessLevel|>];


(* response \:304b\:3089 ```mathematica...``` \:30d6\:30ed\:30c3\:30af\:3092\:9664\:53bb\:3057\:30c6\:30ad\:30b9\:30c8\:306e\:307f\:3092\:53d6\:308a\:51fa\:3059
   \:30b3\:30fc\:30c9\:306f code \:30d5\:30a3\:30fc\:30eb\:30c9\:3067\:5225\:9014\:9001\:4fe1\:3059\:308b\:305f\:3081\:3001\:4e8c\:91cd\:9001\:4fe1\:3092\:9632\:3052\:308b *)
iStripCodeBlocks[s_String] := StringTrim @ StringReplace[s,
  RegularExpression["```[a-z]*\\n[\\s\\S]*?```"] -> ""
];

iSessionToContext[history_List] :=
  iSessionToContext[history, Keys[$confidentialSymbols]];

iSessionToContext[history_List, confVars_List] :=
  StringJoin @ Map[
    Function[rawE,
      Module[{e, resp, textOnly, summary},
        (* \:73fe\:6642\:70b9\:306e\:6a5f\:5bc6\:5909\:6570\:30ea\:30b9\:30c8\:3067\:5c65\:6b74\:30a8\:30f3\:30c8\:30ea\:3092\:30d5\:30a3\:30eb\:30bf *)
        e        = NBAccess`NBFilterHistoryEntry[rawE, confVars, $confVarTimes];
        summary  = Lookup[e, "summary", ""];
        resp     = Lookup[e, "response", None];
        (* response が無い = コンパクション済み: サマリーのみ出力 *)
        If[resp === None || (!StringQ[resp] && summary =!= ""),
          "=== \:30b9\:30c6\:30c3\:30d7 " <> ToString[Lookup[e, "step", "?"]] <>
          " (\:8981\:7d04) ===\n" <> summary <> "\n\n",
          (* 通常エントリ: 詳細出力 *)
          resp     = If[StringQ[resp], resp, "\:ff08\:306a\:3057\:ff09"];
          textOnly = If[StringQ[resp], StringTrim[iStripCodeBlocks[resp]], ""];
          "=== \:30b9\:30c6\:30c3\:30d7 " <> ToString[Lookup[e, "step", "?"]] <> " ===\n" <>
          "\:3010\:6307\:793a\:3011\n" <> ToString[Lookup[e, "instruction",
            Lookup[e, "task", ""]]] <> "\n\n" <>
          If[textOnly =!= "",
            "\:3010Claude \:306e\:8aac\:660e\:3011\n" <> textOnly <> "\n\n", ""] <>
          If[KeyExistsQ[e, "code"] && StringQ[e["code"]] && e["code"] =!= "",
            "\:3010\:751f\:6210\:3055\:308c\:305f\:30b3\:30fc\:30c9\:3011\n```mathematica\n" <>
            e["code"] <> "\n```\n\n", ""]
        ]
      ]
    ],
    history
  ];

(* \:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500
   \:30bb\:30c3\:30b7\:30e7\:30f3\:7ba1\:7406
   \:8a2d\:8a08\:ff1a
     \:30fbTaggingRules \:306b\:30bb\:30c3\:30b7\:30e7\:30f3\:5c65\:6b74\:3092\:683c\:7d0d\:ff08\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:4fdd\:5b58\:6642\:306b\:6c38\:7d9a\:5316\:ff09
     \:30fb\:30c7\:30d5\:30a9\:30eb\:30c8\:30bb\:30c3\:30b7\:30e7\:30f3\:30bf\:30b0: "history"
     \:30fb\:540d\:524d\:4ed8\:304d\:30bb\:30c3\:30b7\:30e7\:30f3\:30bf\:30b0: "history_\:540d\:524d"
     \:30fb\:5404\:30bf\:30b0\:306b <|"header" -> ..., "entries" -> {...}|> \:3092\:683c\:7d0d
     \:30fb\:5404\:30a8\:30f3\:30c8\:30ea\:306f "step"\:30fb"time"->AbsoluteTime[] \:3092\:5fc5\:305a\:6301\:3064
   \:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500 *)

(* セッションタグを決定 *)
iSessionTag[] := "history";
iNamedSessionTag[name_String] := "history_" <> name;

(* ---- セッション履歴アクセスは全て NBAccess の汎用履歴 DB API に委譲 ---- *)

(* セッションデータ読み取り (復元済み) *)
iSessionData[nb_NotebookObject, tag_String] :=
  NBAccess`NBHistoryData[nb, tag];

(* セッションデータ書き込み (初期化用: 圧縮付き) *)
iSessionSetData[nb_NotebookObject, tag_String, data_Association] :=
  NBAccess`NBHistorySetData[nb, tag, data];

(* セッションヘッダーを書き込む *)
iWriteSessionHeader[nb_NotebookObject, tag_String, header_Association] :=
  NBAccess`NBHistoryWriteHeader[nb, tag, header];

(* セッションヘッダーを読み取る *)
iReadSessionHeader[nb_NotebookObject, tag_String] :=
  NBAccess`NBHistoryReadHeader[nb, tag];

(* 1エントリを追記 (差分圧縮 + privacylevel 付与)
   コンパクションは iSessionUpdateLast に移動済み（レスポンス受信後に実行） *)
iSessionAppend[nb_NotebookObject, tag_String, entry_Association] :=
  NBAccess`NBHistoryAppend[nb, tag, entry];

(* 全エントリを返す (復元済み) *)
iSessionHistory[nb_NotebookObject, tag_String] :=
  NBAccess`NBHistoryEntries[nb, tag];

(* 最後のエントリを更新 + レスポンス受信後にコンパクションチェック *)
iSessionUpdateLast[nb_NotebookObject, tag_String, updates_Association] := (
  NBAccess`NBHistoryUpdateLast[nb, tag, updates];
  Quiet @ iCheckHistoryCompaction[nb, tag]);

(* 継承を含む全履歴を取得（親セッションの履歴 + 自分の履歴） *)
iSessionHistoryWithInherit[nb_NotebookObject, tag_String] :=
  NBAccess`NBHistoryEntriesWithInherit[nb, tag];

(* fullPrompt の圧縮/復元: TaggingRules の肥大化を防ぐ *)
(* fullPrompt の圧縮・復元は NBAccess の diffFields 機構に委譲済み。
   NBHistoryCreate の diffFields に "fullPrompt" を含めることで、
   NBAccess 側の差分圧縮が自動的に適用される。 *)

(* ============================================================
   履歴コンパクション
   設計:
     ・各エントリに "summary" フィールドを追加
     ・閾値 2n+1+w を超えたら p ステップおきに詳細を残し、
       間引きエントリはサマリーのみにする
     ・p は毎回 p*2 で増加
   ============================================================ *)

$iHistoryCompactN = 10;   (* 基本間引き幅パラメータ（旧: 25） *)
$iHistoryCompactW = 2;    (* 直近 w ステップは常に平文保持 *)
$iHistoryCompactP = 2;    (* 初期間引き間隔 — セッションヘッダーに保存 *)
$iHistoryMaxBytes = 200000; (* TaggingRules 推定サイズ上限（約200KB）—
                               超過時はエントリ数に関わらずコンパクション発動 *)

(* 1エントリの概要テキスト (API 不要) *)
iMakeLocalSummary[entry_Association] :=
  Module[{inst, resp, code},
    inst = StringTake[Lookup[entry, "instruction",
             Lookup[entry, "task", ""]], UpTo[200]];
    resp = Lookup[entry, "response", ""];
    If[StringQ[resp], resp = StringTake[resp, UpTo[300]]];
    code = Lookup[entry, "code", ""];
    If[StringQ[code], code = StringTake[code, UpTo[200]]];
    "\:6307\:793a: " <> inst <>
    If[StringQ[resp] && resp =!= "",
      "\n\:5fdc\:7b54: " <> resp, ""] <>
    If[StringQ[code] && code =!= "",
      "\n\:30b3\:30fc\:30c9: " <> code, ""]
  ];

(* サマリーペアをローカルで結合
   旧実装では API (Haiku) を呼び出していたが、
   コンパクション毎に数秒〜十数秒のブロックが発生するため廃止。
   簡潔な連結で十分機能する。 *)
iMergeSummaries[sum1_String, sum2_String] :=
  Module[{s1 = StringTrim[sum1], s2 = StringTrim[sum2]},
    (* 合計が600文字を超える場合は各300文字に切り詰め *)
    If[StringLength[s1] + StringLength[s2] > 600,
      s1 = StringTake[s1, UpTo[300]];
      s2 = StringTake[s2, UpTo[300]]];
    s1 <> "\n" <> s2
  ];

(* 履歴コンパクション実行 *)
iCompactHistory[nb_NotebookObject, tag_String] :=
  Module[{entries, n, w, p, total, keepDetailIndices, i, entry,
          summary, prevSummary, merged},
    entries = NBAccess`NBHistoryEntries[nb, tag];
    total = Length[entries];
    If[total === 0, Return[]];

    (* セッションヘッダーから p を取得 *)
    Module[{hdr = NBAccess`NBHistoryReadHeader[nb, tag]},
      p = If[AssociationQ[hdr], Lookup[hdr, "compactP", $iHistoryCompactP], $iHistoryCompactP];
      n = If[AssociationQ[hdr], Lookup[hdr, "compactN", $iHistoryCompactN], $iHistoryCompactN];
      w = If[AssociationQ[hdr], Lookup[hdr, "compactW", $iHistoryCompactW], $iHistoryCompactW]];

    NBAccess`NBWritePrintNotice[None,
      "[History] \:5c65\:6b74\:30b3\:30f3\:30d1\:30af\:30b7\:30e7\:30f3\:5b9f\:884c\:4e2d (p=" <> ToString[p] <>
      ", \:30a8\:30f3\:30c8\:30ea\:6570=" <> ToString[total] <> ")\:2026",
      RGBColor[0.5, 0.3, 0.6]];

    (* 直近 w エントリは常に保持 *)
    keepDetailIndices = Range[Max[1, total - w + 1], total];
    (* p ステップおきに保持 *)
    Do[If[Mod[i, p] === 1, AppendTo[keepDetailIndices, i]],
      {i, 1, total - w}];
    keepDetailIndices = Sort[DeleteDuplicates[keepDetailIndices]];

    (* 間引き対象エントリ: サマリー生成 + 詳細削除 *)
    Do[
      If[!MemberQ[keepDetailIndices, i],
        entry = entries[[i]];
        (* まだサマリーがなければ生成 *)
        If[!KeyExistsQ[entry, "summary"] || entry["summary"] === "",
          summary = iMakeLocalSummary[entry];
          (* 前のエントリとマージ *)
          If[i > 1 && KeyExistsQ[entries[[i - 1]], "summary"] &&
             entries[[i - 1]]["summary"] =!= "",
            prevSummary = entries[[i - 1]]["summary"];
            merged = iMergeSummaries[prevSummary, summary];
            entry = Append[entry, "summary" -> merged],
            entry = Append[entry, "summary" -> summary]],
          (* 既存サマリーがある場合はそのまま *)
          summary = entry["summary"]];
        (* 詳細データを削除 *)
        entry = KeyDrop[entry, {"fullPrompt", "response", "code"}];
        entries[[i]] = entry],
      {i, total}];

    (* 書き戻し *)
    NBAccess`NBHistoryReplaceEntries[nb, tag, entries];

    (* p を更新 (次回は p*2) *)
    NBAccess`NBHistoryUpdateHeader[nb, tag,
      <|"compactP" -> p * 2,
        "compactN" -> n, "compactW" -> w,
        "lastCompactTime" -> AbsoluteTime[],
        "lastCompactTotal" -> total|>];

    NBAccess`NBWritePrintNotice[None,
      "[History] \:30b3\:30f3\:30d1\:30af\:30b7\:30e7\:30f3\:5b8c\:4e86: " <>
      ToString[total - Length[keepDetailIndices]] <> " \:30a8\:30f3\:30c8\:30ea\:3092\:30b5\:30de\:30ea\:30fc\:5316 (p=" <>
      ToString[p * 2] <> ")",
      RGBColor[0.3, 0.5, 0.3]];
  ];

(* 閾値チェック + 自動コンパクション
   エントリ数ベース + サイズベースの二重チェック。
   サイズベースにより、エントリ数が少なくても巨大な response を持つ
   セッションでのノートブック肥大化・フリーズを防ぐ。 *)
iCheckHistoryCompaction[nb_NotebookObject, tag_String] :=
  Module[{entries, total, hdr, n, w, rawData, estimatedBytes, needCompact = False},
    entries = NBAccess`NBHistoryEntries[nb, tag];
    total = Length[entries];
    hdr = Quiet[NBAccess`NBHistoryReadHeader[nb, tag]];
    n = If[AssociationQ[hdr], Lookup[hdr, "compactN", $iHistoryCompactN], $iHistoryCompactN];
    w = If[AssociationQ[hdr], Lookup[hdr, "compactW", $iHistoryCompactW], $iHistoryCompactW];
    (* 条件1: エントリ数ベース *)
    If[total > 2 n + 1 + w, needCompact = True];
    (* 条件2: サイズベース（エントリ数が少なくても巨大な場合） *)
    If[!needCompact && total > w + 1,
      rawData = Quiet[NBAccess`NBHistoryRawData[nb, tag]];
      estimatedBytes = Quiet @ Check[ByteCount[rawData], 0];
      If[estimatedBytes > $iHistoryMaxBytes, needCompact = True]];
    If[needCompact, iCompactHistory[nb, tag]]
  ];

(* セッションオブジェクトから継承付き履歴を取得 *)
iFullHistory[session_Association] :=
  NBAccess`NBHistoryEntriesWithInherit[session["Notebook"], session["SessionTag"]];

(* デフォルトセッションの取得/初期化 — NBHistoryCreate は冪等 *)
iEnsureDefaultSession[nb_NotebookObject] := Module[{tag, nbDirs, nbDir},
  tag = iSessionTag[];
  NBAccess`NBHistoryCreate[nb, tag, {"fullPrompt", "response", "code"},
    <|"name" -> "$default"|>];
  (* $packageDirectory がロード時に未定義だった場合に備え、ここで再保証 *)
  If[StringQ[Global`$packageDirectory] && StringLength[Global`$packageDirectory] > 0 &&
     !MemberQ[If[ListQ[$ClaudeAccessibleDirs], $ClaudeAccessibleDirs, {}], Global`$packageDirectory],
    $ClaudeAccessibleDirs = DeleteDuplicates[
      Prepend[If[ListQ[$ClaudeAccessibleDirs], $ClaudeAccessibleDirs, {}], Global`$packageDirectory]]];
  (* TaggingRules に保存済みのディレクトリを復元（ユーザーが以前承認済み） *)
  nbDirs = NBAccess`NBGetAccessibleDirs[nb];
  If[ListQ[nbDirs] && Length[nbDirs] > 0,
    $ClaudeAccessibleDirs = DeleteDuplicates[
      Join[If[ListQ[$ClaudeAccessibleDirs], $ClaudeAccessibleDirs, {}], nbDirs]]];
  (* TaggingRules に保存済みの Read 許可も復元（ダイアログは出さない） *)
  nbDir = Quiet @ Check[NotebookDirectory[nb], None];
  If[StringQ[nbDir] && DirectoryQ[nbDir] && !iIsSafeDefaultDir[nbDir],
    Module[{savedPerm = iGetDirPermission[nb, nbDir]},
      If[StringQ[savedPerm] && savedPerm =!= "denied",
        $iDirPermissionCache[nbDir] = savedPerm;
        $ClaudeAccessibleDirs = DeleteDuplicates[
          Append[If[ListQ[$ClaudeAccessibleDirs], $ClaudeAccessibleDirs, {}], nbDir]],
      (* 未許可でもキャッシュに記録しない — 後で必要時にダイアログ表示 *)
      Null]]];
  (* セッションアタッチメントを読み込み *)
  $iCurrentSessionAttachments = NBAccess`NBHistoryGetAttachments[nb, tag];
  <|"SessionTag" -> tag, "Notebook" -> nb, "Name" -> "default",
    "InheritFrom" -> {}|>
];

$ClaudeExe = Module[{whereResult, lines, cmdLine, exeLine},
  whereResult = Quiet[
    StringTrim @ RunProcess[{"cmd", "/c", "where claude"}, "StandardOutput"]
  ];
  If[StringQ[whereResult] && whereResult =!= "" &&
     !StringContainsQ[whereResult, "Could not find"],
    lines   = StringTrim /@ Select[StringSplit[whereResult, "\n"], StringLength[#] > 0 &];
    cmdLine = SelectFirst[lines, StringEndsQ[#, ".cmd", IgnoreCase -> True] &, None];
    exeLine = SelectFirst[lines, StringEndsQ[#, ".exe", IgnoreCase -> True] &, None];
    Which[cmdLine =!= None, cmdLine, exeLine =!= None, exeLine, True, First[lines, "claude"]],
    SelectFirst[{
      FileNameJoin[{$HomeDirectory, "AppData", "Roaming", "npm", "claude.cmd"}],
      FileNameJoin[{$HomeDirectory, ".local", "bin", "claude.exe"}]
    }, FileExistsQ, "claude"]
  ]
];

(* .cmd \:30d5\:30a1\:30a4\:30eb\:306f\:30d0\:30c3\:30c1\:5185\:3067 call \:304c\:5fc5\:8981 *)
iClaudeCallPrefix[] :=
  If[StringEndsQ[$ClaudeExe, ".cmd", IgnoreCase -> True], "call ", ""];

(* \:540c\:671f\:30fb\:975e\:540c\:671f\:5171\:901a\:306e\:30d0\:30c3\:30c1\:30d5\:30a1\:30a4\:30eb\:751f\:6210 *)
$claudeProgress = <||>;

(* --print モードではツール使用許可プロンプトに応答できないため
   Read ツールと Glob（ファイルリスト）を常に許可する。
   $iAllowReadTool が True の場合は Grep も追加し、内容検索を許可する。
   $iAllowWebSearch が True の場合は WebSearch も追加し、Claude Code の Web 検索を許可する。
   Glob はファイルカタログ取得のみで低リスクなため常に有効とする。 *)
iCLIPermissionFlags[] := Module[{tools = {"Read", "Glob"}},
  If[TrueQ[$iAllowReadTool], AppendTo[tools, "Grep"]];
  If[TrueQ[$iAllowWebSearch], AppendTo[tools, "WebSearch"]];
  " --allowedTools \"" <> StringRiffle[tools, ","] <> "\""];

iMakeBat[promptFile_String, outFile_String, imageDirs_List:{}] :=
  Module[{batFile, bc, strm, addDirFlags, permFlags, workDir, allDirs},
    batFile = FileNameJoin[{$TemporaryDirectory,
      "claude_run_" <> ToString[UnixTime[]] <> "_" <>
      ToString[RandomInteger[99999]] <> ".bat"}];
    workDir = iPrepareClaudeProjectDirectory[];
    allDirs = DeleteDuplicates[Join[imageDirs, iCollectAccessibleDirs[]]];
    addDirFlags = StringJoin[Map[
      Function[d, " --add-dir \"" <> d <> "\""],
      allDirs]];
    permFlags = iCLIPermissionFlags[];
    bc = "@echo off\r\n" <>
         "chcp 65001 > nul\r\n" <>
         iClaudeEnvResetBatchLines[] <>
         "cd /d \"" <> workDir <> "\"\r\n" <>
         iClaudeCallPrefix[] <>
         "\"" <> $ClaudeExe <> "\" --print" <>
         If[$ClaudeModel =!= "", " --model \"" <> $ClaudeModel <> "\"", ""] <>
         permFlags <>
         addDirFlags <>
         " < \"" <> promptFile <> "\" > \"" <> outFile <> "\" 2>&1\r\n";
    strm = OpenWrite[batFile, BinaryFormat -> True];
    BinaryWrite[strm, ExportString[bc, "Text", CharacterEncoding -> "ASCII"]];
    Close[strm];
    batFile
  ];
iMakeBatStreamJson[promptFile_String, outFile_String, imageDirs_List:{}] :=
  Module[{batFile, bc, strm, addDirFlags, permFlags, workDir, allDirs},
    batFile = FileNameJoin[{$TemporaryDirectory,
      "claude_run_" <> ToString[UnixTime[]] <> "_" <>
      ToString[RandomInteger[99999]] <> ".bat"}];
    workDir = iPrepareClaudeProjectDirectory[];
    allDirs = DeleteDuplicates[Join[imageDirs, iCollectAccessibleDirs[]]];
    addDirFlags = StringJoin[Map[
      Function[d, " --add-dir \"" <> d <> "\""],
      allDirs]];
    permFlags = iCLIPermissionFlags[];
    bc = "@echo off\r\n" <>
         "chcp 65001 > nul\r\n" <>
         iClaudeEnvResetBatchLines[] <>
         "cd /d \"" <> workDir <> "\"\r\n" <>
         iClaudeCallPrefix[] <>
         "\"" <> $ClaudeExe <> "\" --print" <>
         " --output-format stream-json" <>
         " --verbose" <>
         " --include-partial-messages" <>
         If[$ClaudeModel =!= "", " --model \"" <> $ClaudeModel <> "\"", ""] <>
         permFlags <>
         addDirFlags <>
         " < \"" <> promptFile <> "\" > \"" <> outFile <> "\" 2>&1\r\n";
    strm = OpenWrite[batFile, BinaryFormat -> True];
    BinaryWrite[strm, ExportString[bc, "Text", CharacterEncoding -> "ASCII"]];
    Close[strm];
    batFile
  ];

(* --- stream-json パースヘルパー --- *)

(* Windows でのファイルロック競合を回避する安全なファイル読み取り。
   Import["...","Text"] は書き込み中のファイルをブロックする可能性があるため、
   ReadByteArray を使用して非ブロッキングで読み取る。 *)
iSafeReadStreamFile[file_String] :=
  Quiet @ Check[
    Module[{bytes},
      bytes = ReadByteArray[File[file]];
      If[ByteArrayQ[bytes] && Length[bytes] > 0,
        ByteArrayToString[bytes, "UTF-8"],
        ""]
    ],
    ""
  ];

(* 1行のJSONLをパースしてイベント情報を返す *)
iParseStreamJsonLine[line_String] :=
  Quiet @ Check[Developer`ReadRawJSONString[line], $Failed];

(* stream-json 出力ファイルから最終テキスト結果を抽出する。
   text_delta を結合してテキストを復元する。 *)
iExtractResultFromStreamJson[outFile_String] :=
  Module[{raw, lines, textDeltas = {}, resultText = None, j, evt, delta,
          stderrLines = {}},
    If[!FileExistsQ[outFile] || FileByteCount[outFile] === 0, Return[""]];
    raw = iSafeReadStreamFile[outFile];
    If[!StringQ[raw] || raw === "", Return[""]];
    lines = Select[StringSplit[raw, "\n"], StringLength[#] > 0 &];
    Do[
      j = iParseStreamJsonLine[line];
      If[!AssociationQ[j],
        (* JSON パース失敗: stderr 由来のプレーンテキスト行を収集 *)
        If[StringLength[line] > 0 && !StringStartsQ[line, "{"],
          AppendTo[stderrLines, line]];
        Continue[]];
      Which[
        (* result イベントからテキストを抽出（最優先） *)
        j["type"] === "result" && AssociationQ[Lookup[j, "result", None]],
          Module[{res = j["result"], content},
            content = Lookup[res, "content", {}];
            If[ListQ[content],
              resultText = StringJoin[
                Lookup[#, "text", ""] & /@
                  Select[content, AssociationQ[#] && Lookup[#, "type", ""] === "text" &]]]],
        (* text_delta: テキスト断片を蓄積 *)
        j["type"] === "stream_event" && AssociationQ[Lookup[j, "event", None]],
          evt = j["event"];
          delta = Lookup[evt, "delta", None];
          If[AssociationQ[delta] && Lookup[delta, "type", ""] === "text_delta",
            AppendTo[textDeltas, Lookup[delta, "text", ""]]]
      ],
      {line, lines}];
    (* result があればそれを優先、なければ text_delta を結合 *)
    Which[
      StringQ[resultText] && resultText =!= "", resultText,
      Length[textDeltas] > 0, StringJoin[textDeltas],
      (* JSON結果もtext_deltaも無い場合: stderr行をエラーメッセージとして返す *)
      Length[stderrLines] > 0,
        "Error: " <> StringJoin[Riffle[stderrLines, "\n"]],
      True, ""
    ]
  ];

(* stream-json 出力ファイルの新規行を読み取り $claudeProgress を更新する。
   注意: ScheduledTask 内で毎秒呼ばれるため、Import ではなく iSafeReadStreamFile を使い
   Windows のファイルロック競合によるカーネルフリーズを防止する。 *)
iUpdateStreamProgress[key_String, outFile_String] :=
  Module[{raw, allLines, prevCount, newLines, j, evt, delta, info, prevSize},
    If[!AssociationQ[$claudeProgress[key]], Return[]];
    info = $claudeProgress[key];
    prevCount = Lookup[info, "lineCount", 0];
    If[!FileExistsQ[outFile], Return[]];
    prevSize = Lookup[info, "lastByteCount", 0];
    With[{curSize = Quiet @ Check[FileByteCount[outFile], 0]},
      If[curSize === 0 || curSize === prevSize, Return[]];
      info["lastByteCount"] = curSize];
    raw = iSafeReadStreamFile[outFile];
    If[!StringQ[raw] || raw === "", Return[]];
    allLines = Select[StringSplit[raw, "\n"], StringLength[#] > 0 &];
    If[Length[allLines] <= prevCount, Return[]];
    newLines = Drop[allLines, prevCount];
    Do[
      j = iParseStreamJsonLine[line];
      If[!AssociationQ[j], Continue[]];
      Which[
        j["type"] === "stream_event" && AssociationQ[Lookup[j, "event", None]],
          evt = j["event"];
          delta = Lookup[evt, "delta", None];
          Which[
            (* テキスト生成中 *)
            AssociationQ[delta] && delta["type"] === "text_delta",
              info["status"] = "\:30c6\:30ad\:30b9\:30c8\:751f\:6210\:4e2d";
              info["textFragments"] = Lookup[info, "textFragments", 0] + 1;
              info["lastText"] = Lookup[delta, "text", ""],
            (* thinking 中 *)
            AssociationQ[delta] && delta["type"] === "thinking_delta",
              info["status"] = "\:601d\:8003\:4e2d";
              info["thinkingFragments"] = Lookup[info, "thinkingFragments", 0] + 1,
            (* ツール使用開始 *)
            evt["type"] === "content_block_start" &&
              AssociationQ[Lookup[evt, "content_block", None]] &&
              Lookup[evt["content_block"], "type", ""] === "tool_use",
              info["status"] = "\:30c4\:30fc\:30eb\:5b9f\:884c\:4e2d: " <> Lookup[evt["content_block"], "name", "?"];
              info["toolUses"] = Lookup[info, "toolUses", 0] + 1,
            (* メッセージ終了 *)
            evt["type"] === "message_stop",
              info["status"] = "\:5fdc\:7b54\:5b8c\:4e86",
            True, Null],
        (* result *)
        j["type"] === "result",
          info["status"] = "\:5b8c\:4e86",
        (* system *)
        j["type"] === "system",
          info["status"] = "\:521d\:671f\:5316",
        True, Null
      ],
      {line, newLines}];
    info["lineCount"] = Length[allLines];
    $claudeProgress[key] = info;
  ];

(* verbose 版: stderr を logFile に分離してストリーミング辺を取得 *)
iMakeBatVerbose[promptFile_String, outFile_String, logFile_String] :=
  Module[{batFile, bc, strm, addDirFlags, permFlags, workDir, allDirs},
    batFile = FileNameJoin[{$TemporaryDirectory,
      "claude_run_" <> ToString[UnixTime[]] <> "_" <>
      ToString[RandomInteger[99999]] <> ".bat"}];
    workDir = iPrepareClaudeProjectDirectory[];
    allDirs = iCollectAccessibleDirs[];
    addDirFlags = StringJoin[Map[
      Function[d, " --add-dir \"" <> d <> "\""],
      allDirs]];
    permFlags = iCLIPermissionFlags[];
    bc = "@echo off\r\n" <>
         "chcp 65001 > nul\r\n" <>
         iClaudeEnvResetBatchLines[] <>
         "cd /d \"" <> workDir <> "\"\r\n" <>
         iClaudeCallPrefix[] <>
         "\"" <> $ClaudeExe <> "\" --print --verbose" <>
         If[$ClaudeModel =!= "", " --model \"" <> $ClaudeModel <> "\"", ""] <>
         permFlags <>
         addDirFlags <>
         " < \"" <> promptFile <>
         "\" > \"" <> outFile <> "\" 2> \"" <> logFile <> "\"\r\n";
    strm = OpenWrite[batFile, BinaryFormat -> True];
    BinaryWrite[strm, ExportString[bc, "Text", CharacterEncoding -> "ASCII"]];
    Close[strm];
    batFile
  ];

(* verbose \:30ed\:30b0\:304b\:3089\:30c6\:30ad\:30b9\:30c8\:30c7\:30eb\:30bf\:3092\:62bd\:51fa\:3059\:308b\:30d8\:30eb\:30d1\:30fc *)
iParseVerboseLog[logFile_String, prevSize_Integer] :=
  Module[{raw, newPart, lines, texts},
    If[!FileExistsQ[logFile], Return[{"", prevSize}]];
    raw = Quiet[Import[logFile, "Text"]];
    If[!StringQ[raw] || StringLength[raw] <= prevSize, Return[{"", prevSize}]];
    newPart = StringTake[raw, {prevSize + 1, -1}];
    lines = StringSplit[newPart, "\n"];
    texts = Flatten @ StringCases[lines,
      "\"type\":\"text_delta\"" ~~ __, "\"text\":\"" ~~
      t : Shortest[__] ~~ "\"" :> t];
    {StringJoin[texts], StringLength[raw]}
  ];

(* \:30d7\:30ed\:30b0\:30ec\:30b9\:8868\:793a\:4ed8\:304d\:975e\:540c\:671f\:5b9f\:884c (Job \:30b7\:30b9\:30c6\:30e0\:5bfe\:5fdc) — stream-json \:7248 *)
iClaudeQueryAsyncWithProgress[prompt_, callback_, nb_NotebookObject,
    extraImageDirs_List:{}, jobId_String:"", fallbackModels_List:{}] :=
  Module[{ts, outFile, promptFile, batFile, proc, startTime, progTag, norm,
          useFallback = TrueQ[$currentUseFallback], useJob},
    useJob = (jobId =!= "");
    norm       = iNormalizePrompt[iInjectAttachments[prompt]];
    ts         = ToString[UnixTime[]] <> "x" <> ToString[RandomInteger[99999]];
    outFile    = FileNameJoin[{$TemporaryDirectory, "claude_out_"    <> ts <> ".jsonl"}];
    promptFile = FileNameJoin[{$TemporaryDirectory, "claude_prompt_" <> ts <> ".txt"}];
    progTag    = "claude-prog-" <> ts;

    Quiet[DeleteFile /@ Select[{outFile, promptFile}, FileExistsQ]];
    Block[{strm, finalText},
      finalText = iHoistThinkPrefix[norm["text"]];
      strm = OpenWrite[promptFile, BinaryFormat -> True];
      BinaryWrite[strm, ExportString[finalText, "Text", CharacterEncoding -> "UTF-8"]];
      Close[strm]
    ];

    batFile   = iMakeBatStreamJson[promptFile, outFile, Join[norm["imageDirs"], extraImageDirs]];
    proc      = StartProcess[{"cmd", "/c", batFile}];
    startTime = AbsoluteTime[];

    (* $claudeProgress にリッチ情報を格納 *)
    $claudeProgress[ts] = <|
      "disp" -> "Claude \:306b\:554f\:3044\:5408\:308f\:305b\:4e2d... 0s",
      "status" -> "\:521d\:671f\:5316",
      "phase" -> "polling",
      "startTime" -> startTime,
      "outFile" -> outFile,
      "process" -> proc,
      "lineCount" -> 0,
      "textFragments" -> 0,
      "thinkingFragments" -> 0,
      "toolUses" -> 0,
      "lastText" -> "",
      "caller" -> If[useJob, "Job:" <> jobId, "Async"]
    |>;

    With[{k = ts, jid = jobId, uj = useJob},
      (* 進捗表示: Dynamic を使わず、ScheduledTask から直接スロット/セルを更新。
         Dynamic は kernel がブロック中に評価要求が累積し FrontEnd をフリーズさせるため廃止。 *)
      $claudeProgress[k]["disp"] = "Claude に問い合わせ中...";
      If[uj,
        NBAccess`NBWriteSlot[jid, 1,
          Cell["Claude に問い合わせ中...",
            "Print", FontWeight -> Bold, FontColor -> RGBColor[0.8, 0.4, 0], FontSize -> 11]],
        (* 非 Job パス: CellPrint で静的セルを配置、ScheduledTask が更新 *)
        Quiet[SelectionMove[nb, After, Notebook]];
        CellPrint[Cell["Claude に問い合わせ中...",
          "Print", FontWeight -> Bold, FontColor -> RGBColor[0.8, 0.4, 0], FontSize -> 11,
          CellTags -> {progTag}]]
      ]
    ];

    With[{gSym = Symbol["ClaudeCode`Private`$task" <> ts]},
    gSym = CreateScheduledTask[
      With[{p = proc, t0 = startTime, cb = callback, k = ts,
            oFile = outFile, bFile = batFile, pFile = promptFile,
            pNb = nb, ptag = progTag, useFb = useFallback, sym = gSym,
            jid = jobId, uj = useJob, fbMdls = fallbackModels},
        Module[{elapsed, info, statusStr, phase, status, iUpdateDisp},
          If[!KeyExistsQ[$claudeProgress, k], Return[]];
          elapsed = Round[AbsoluteTime[] - t0, 1];
          phase = Lookup[$claudeProgress[k], "phase", "polling"];

          (* === 進捗テキスト更新ヘルパー === *)
          iUpdateDisp[text_String, color_:RGBColor[0.8, 0.4, 0]] :=
            Quiet @ If[uj,
              NBAccess`NBWriteSlot[jid, 1,
                Cell[text, "Print", FontWeight -> Bold, FontColor -> color, FontSize -> 11]],
              Module[{progCells = Quiet[Cells[pNb, CellTags -> ptag]]},
                If[ListQ[progCells] && Length[progCells] > 0,
                  Quiet[SelectionMove[First[progCells], All, Cell]];
                  NotebookWrite[pNb,
                    Cell[text, "Print", FontWeight -> Bold, FontColor -> color, FontSize -> 11,
                      CellTags -> {ptag}], All]]]];

          Which[
            (* === Phase: polling — プロセス実行中 === *)
            phase === "polling",
              iUpdateStreamProgress[k, oFile];
              info = $claudeProgress[k];
              statusStr = Lookup[info, "status", "?"];
              $claudeProgress[k]["disp"] =
                "Claude \:306b\:554f\:3044\:5408\:308f\:305b\:4e2d... " <> ToString[elapsed] <> "s | " <>
                statusStr <>
                If[Lookup[info, "thinkingFragments", 0] > 0,
                  " (\:601d\:8003:" <> ToString[info["thinkingFragments"]] <> ")", ""] <>
                If[Lookup[info, "textFragments", 0] > 0,
                  " (\:30c6\:30ad\:30b9\:30c8:" <> ToString[info["textFragments"]] <> ")", ""] <>
                If[Lookup[info, "toolUses", 0] > 0,
                  " (\:30c4\:30fc\:30eb:" <> ToString[info["toolUses"]] <> ")", ""];
              iUpdateDisp[$claudeProgress[k]["disp"]];
              status = ProcessStatus[p];
              If[status === "Finished" || elapsed > $ClaudeTimeout,
                (* プロセス完了: 結果を保存し次のティックで処理 *)
                Quiet @ DeleteFile /@ Select[{bFile, pFile}, FileExistsQ];
                If[status =!= "Finished",
                  KillProcess[p];
                  $claudeProgress[k]["phase"] = "done";
                  If[uj,
                    NBAccess`NBAbortJob[jid,
                      "Error: \:30bf\:30a4\:30e0\:30a2\:30a6\:30c8\:ff08" <> ToString[$ClaudeTimeout] <> "\:79d2\:ff09"],
                    cb["Error: \:30bf\:30a4\:30e0\:30a2\:30a6\:30c8\:ff08" <> ToString[$ClaudeTimeout] <> "\:79d2\:ff09\:3057\:307e\:3057\:305f\:3002"]],
                  (* 正常完了: 結果ファイルを読み取り *)
                  Module[{retries2 = 0, result2, isEmpty2},
                    While[!FileExistsQ[oFile] && retries2 < 3, Pause[0.5]; retries2++];
                    If[FileExistsQ[oFile] && FileByteCount[oFile] > 0,
                      result2 = iExtractResultFromStreamJson[oFile];
                      Quiet[DeleteFile[oFile]];
                      isEmpty2 = (result2 === "");
                      If[isEmpty2,
                        result2 = "Error: Claude Code \:304c\:7a7a\:306e\:30ec\:30b9\:30dd\:30f3\:30b9\:3092\:8fd4\:3057\:307e\:3057\:305f\:3002\:5229\:7528\:5236\:9650\:306b\:9054\:3057\:3066\:3044\:308b\:53ef\:80fd\:6027\:304c\:3042\:308a\:307e\:3059\:3002"];
                      If[TrueQ[useFb] && (isEmpty2 || iIsLimitError[result2]),
                        (* フォールバック: 直接起動して完了 *)
                        $claudeProgress[k]["phase"] = "done";
                        Module[{fbModels2 = fbMdls},
                          iStartFallbackAsync[norm["text"], pNb,
                            Function[fbResult,
                              If[StringQ[fbResult] && fbResult =!= $Failed,
                                cb[fbResult],
                                If[uj,
                                  NBAccess`NBAbortJob[jid, result2],
                                  iFlushFallbackLog[pNb];
                                  Quiet[SelectionMove[pNb, After, Notebook]];
                                  NBAccess`NBWriteCell[pNb, Cell[result2, "Text"]]]]],
                            fbModels2, 1, jid]],
                        (* 正常結果: 次のティックで callback 実行 *)
                        $claudeProgress[k]["result"] = result2;
                        $claudeProgress[k]["phase"] = "received"],
                      (* エラーなし・フォールバック不要: ファイルなし *)
                      $claudeProgress[k]["phase"] = "done";
                      If[uj,
                        NBAccess`NBAbortJob[jid, "Error: \:51fa\:529b\:30d5\:30a1\:30a4\:30eb\:304c\:751f\:6210\:3055\:308c\:307e\:305b\:3093\:3067\:3057\:305f"],
                        cb["Error: \:51fa\:529b\:30d5\:30a1\:30a4\:30eb\:304c\:751f\:6210\:3055\:308c\:307e\:305b\:3093\:3067\:3057\:305f"]]
                    ]]]],

            (* === Phase: received — 結果取得済み → 表示更新のみ、cb は次ティックで === *)
            phase === "received",
              iUpdateDisp[
                "\:2713 Claude \:304b\:3089\:306e\:5fdc\:7b54\:3092\:53d6\:5f97 (" <> ToString[elapsed] <> "s)\:3002\:51fa\:529b\:3092\:66f8\:304d\:8fbc\:307f\:4e2d...",
                RGBColor[0.3, 0.6, 0.3]];
              $claudeProgress[k]["phase"] = "writing",

            (* === Phase: writing — 進捗更新 → callback 実行 → done === *)
            phase === "writing",
              iUpdateDisp[
                "\:2713 \:51fa\:529b\:3092\:66f8\:304d\:8fbc\:307f\:4e2d... (" <> ToString[elapsed] <> "s)",
                RGBColor[0.3, 0.6, 0.3]];
              (* callback をこのティック内で実行。
                 iUpdateDisp が先に FrontEnd に送信されるため、
                 「書き込み中 (Ns)」表示が反映されてから cb がブロック開始する。 *)
              cb[$claudeProgress[k]["result"]];
              $claudeProgress[k]["phase"] = "done",

            (* === Phase: done — クリーンアップ === *)
            phase === "done",
              $claudeProgress = KeyDrop[$claudeProgress, k];
              Quiet[StopScheduledTask[sym]];
              Quiet[RemoveScheduledTask[sym]];
              (* 進捗セルを削除: Job パスは written=False で NBEndJob に任せる *)
              If[uj,
                $NBJobTable[jid, "written"] =
                  ReplacePart[$NBJobTable[jid]["written"], 1 -> False],
                NBAccess`NBDeleteCellsByTag[pNb, ptag]]
          ]
        ]
      ],
      1
    ];
    StartScheduledTask[gSym];
    ]   (* With end *)
  ];   (* Module end *)

$BaseDir = FileNameJoin[{$UserBaseDirectory, "pty_runner"}];

(* ============================================================
   \:521d\:671f\:5316\:ff1a\:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:30fbJS\:30fbnode-pty \:306e\:30bb\:30c3\:30c8\:30a2\:30c3\:30d7
   ============================================================ *)

$JSPath = FileNameJoin[{$BaseDir, "pty_run.js"}];

$JSSource =
  "const fs = require('fs');\n" <>
  "const { spawnSync } = require('child_process');\n" <>
  "let pty;\n" <>
  "try { pty = require('node-pty'); } catch (e) {\n" <>
  "  process.stderr.write('require(node-pty) failed: ' + e + '\\n');\n" <>
  "  process.exit(1);\n" <>
  "}\n" <>
  "const outFile    = process.argv[2];\n" <>
  "let   file       = process.argv[3];\n" <>
  "const rawArgs    = process.argv.slice(4);\n" <>
  "function write(s){ try{ fs.writeFileSync(outFile, s, 'utf8'); }catch(_){} }\n" <>
  "if (!file.includes('\\\\') && !file.includes('/')) {\n" <>
  "  const r = spawnSync('cmd.exe', ['/c','where',file], {encoding:'utf8'});\n" <>
  "  if (r.status === 0 && r.stdout) file = r.stdout.split(/\\r?\\n/).filter(Boolean)[0];\n" <>
  "}\n" <>
  "if (!file || !fs.existsSync(file)) { write('FILE_NOT_FOUND: '+file+'\\n'); process.exit(1); }\n" <>
  (* @filepath \:5f15\:6570\:3092\:63a2\:3057\:3066\:30b7\:30a7\:30eb\:30ea\:30c0\:30a4\:30ec\:30af\:30c8\:7d4c\:7531\:3067\:8d77\:52d5\:3059\:308b\:304b\:5224\:65ad *)
  "const promptFileArg = rawArgs.find(a => typeof a === 'string' && a.startsWith('@'));\n" <>
  "if (promptFileArg) {\n" <>
  "  const promptPath = promptFileArg.slice(1);\n" <>
  "  const otherArgs  = rawArgs.filter(a => a !== promptFileArg);\n" <>
  "  const shellCmd   = '\"' + file + '\" ' + otherArgs.join(' ') + ' < \"' + promptPath + '\"';\n" <>
  "  const term = pty.spawn('cmd.exe', ['/c', shellCmd], {\n" <>
  "    name:'xterm-color', cols:220, rows:50,\n" <>
  "    cwd:process.cwd(), env:process.env\n" <>
  "  });\n" <>
  "  let buf='';\n" <>
  "  term.onData(d => { buf += d; });\n" <>
  "  term.onExit(e => { write(buf); process.exit((e && e.exitCode) || 0); });\n" <>
  "} else {\n" <>
  "  const term = pty.spawn(file, rawArgs, {\n" <>
  "    name:'xterm-color', cols:220, rows:50,\n" <>
  "    cwd:process.cwd(), env:process.env\n" <>
  "  });\n" <>
  "  let buf='';\n" <>
  "  term.onData(d => { buf += d; });\n" <>
  "  term.onExit(e => { write(buf); process.exit((e && e.exitCode) || 0); });\n" <>
  "}\n";

(* \:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:4f5c\:6210\:ff08\:65e2\:5b58\:306e\:5834\:5408\:306f\:30b9\:30ad\:30c3\:30d7\:ff09 *)
If[!DirectoryQ[$BaseDir],
  CreateDirectory[$BaseDir, CreateIntermediateDirectories -> True]];

(* JS \:30d5\:30a1\:30a4\:30eb\:3092\:66f8\:304d\:51fa\:3059\:ff08\:5e38\:306b\:6700\:65b0\:3092\:5c55\:958b\:ff09 *)
Export[$JSPath, $JSSource, "String"];

(* node-pty \:304c\:672a\:30a4\:30f3\:30b9\:30c8\:30fc\:30eb\:306a\:3089 npm install *)
If[!DirectoryQ[FileNameJoin[{$BaseDir, "node_modules", "node-pty"}]],
  Print["node-pty \:3092\:30a4\:30f3\:30b9\:30c8\:30fc\:30eb\:4e2d..."];
  RunProcess[{"cmd", "/c", "npm install node-pty"},
    ProcessDirectory -> $BaseDir];
  Print["node-pty \:30a4\:30f3\:30b9\:30c8\:30fc\:30eb\:5b8c\:4e86"]
];

(* \:30ed\:30fc\:30c9\:6642\:30d8\:30eb\:30d7\:8868\:793a *)
Print[Style["ClaudeCode \:30d1\:30c3\:30b1\:30fc\:30b8 \[LongDash] \:4f7f\:3044\:65b9", Bold]];
Print[
  "  \:4f9d\:5b58: NBAccess \:30d1\:30c3\:30b1\:30fc\:30b8 (PrivacySpec \:30d9\:30fc\:30b9\:306e\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:8aad\:307f\:66f8\:304d)\n" <>
  "  $NBPrivacySpec \:3067\:30c7\:30a3\:30d5\:30a9\:30eb\:30c8\:30a2\:30af\:30bb\:30b9\:30ec\:30d9\:30eb\:3092\:8a2d\:5b9a\:53ef\:80fd\n" <>
  "  ClaudeQuery[prompt]              \[RightArrow] Claude \:306b\:81ea\:7531\:306b\:554f\:3044\:5408\:308f\:305b\:308b\:ff08\:540c\:671f\:30fb\:5c65\:6b74\:4fdd\:5b58\:ff09\n" <>
  "  ClaudeQuery[session, prompt]       \[RightArrow] \:30bb\:30c3\:30b7\:30e7\:30f3\:5c65\:6b74\:30fb\:76f4\:524d\:51fa\:529b\:3092\:8003\:616e\:3057\:305f\:554f\:3044\:5408\:308f\:305b\n" <>
  "  ClaudeEval[task]                 \[RightArrow] \:975e\:540c\:671f\:30b3\:30fc\:30c9\:751f\:6210\:ff08\:30c7\:30d5\:30a9\:30eb\:30c8\:30bb\:30c3\:30b7\:30e7\:30f3\:ff09\n" <>
  "  ClaudeEval[{text, data, ...}]   \[RightArrow] Dataset/Image/\:5f0f\:3092\:542b\:3080\:30b3\:30fc\:30c9\:751f\:6210\n" <>
  "  ClaudeEval[session, task]        \[RightArrow] \:975e\:540c\:671f\:30b3\:30fc\:30c9\:751f\:6210\:ff08\:6307\:5b9a\:30bb\:30c3\:30b7\:30e7\:30f3\:ff09\n" <>
  "    Options: Fallback, AutoEvaluate, StartTime\:ff08\:4f8b: StartTime -> Now + Quantity[3,\"Hours\"]\:ff09\n" <>
  "    WebSearch->True(\:30c7\:30d5\:30a9\:30eb\:30c8): Claude Code \:306e Web \:691c\:7d22\:30c4\:30fc\:30eb\:3092\:8a31\:53ef(\:7121\:6599)\n" <>
  "    WebFetch->False/True/Automatic: API \:7d4c\:7531 Web \:691c\:7d22(\:8ab2\:91d1\:3042\:308a\:3001Fallback->True \:6642\:306e\:307f\:6709\:52b9)\n" <>
  "  ContinueEval[\"\:6307\:793a\"]              \[RightArrow] \:30c7\:30d5\:30a9\:30eb\:30c8\:30bb\:30c3\:30b7\:30e7\:30f3\:3067\:7d99\:7d9a\n" <>
  "  ContinueEval[session, \"\:6307\:793a\"]    \[RightArrow] \:30bb\:30c3\:30b7\:30e7\:30f3\:7d99\:7d9a\:30fb\:30a8\:30e9\:30fc\:4fee\:6b63\:30fb\:6539\:826f\n" <>
  "  ContinueEval[]                   \[RightArrow] \"\:30a8\:30e9\:30fc\:3092\:4fee\:6b63\:3057\:3066\:304f\:3060\:3055\:3044\" \:3067\:7d99\:7d9a\n" <>
  "    Options: Fallback, AutoEvaluate, StartTime\n" <>
  "  CreateClaudeSession[\"name\"]      \[RightArrow] \:540d\:524d\:4ed8\:304d\:30bb\:30c3\:30b7\:30e7\:30f3\:3092\:4f5c\:6210\n" <>
  "  ClaudeRestoreSession[\"name\"]    \[RightArrow] \:30bb\:30c3\:30b7\:30e7\:30f3\:3092\:30ea\:30b9\:30c8\:30a2\n" <>
  "  ClaudeListSessions[]             \[RightArrow] \:5168\:30bb\:30c3\:30b7\:30e7\:30f3\:4e00\:89a7\n" <>
  "  ClaudeDeleteSession[\"name\"]     \[RightArrow] \:30bb\:30c3\:30b7\:30e7\:30f3\:524a\:9664\n" <>
  "  ClaudeShowHistory[]              \[RightArrow] \:30c7\:30d5\:30a9\:30eb\:30c8\:5c65\:6b74\:8868\:793a\n" <>
  "  ClaudeShowHistory[session]       \[RightArrow] \:6307\:5b9a\:30bb\:30c3\:30b7\:30e7\:30f3\:306e\:5c65\:6b74\:8868\:793a\n" <>
  "  ClaudeDebug[code, errMsg]        \[RightArrow] \:30c7\:30d0\:30c3\:30b0\:4f9d\:983c\:ff08\:975e\:540c\:671f\:ff09\n" <>
  "  ClaudeReview[code]               \[RightArrow] \:30b3\:30fc\:30c9\:30ec\:30d3\:30e5\:30fc\:ff08\:975e\:540c\:671f\:ff09\n" <>
  "  ClaudeCreatePackage[name, prompt]  \[RightArrow] \:65b0\:898f\:30d1\:30c3\:30b1\:30fc\:30b8\:3092\:751f\:6210 (Fallback)\n" <>
  "  ClaudeUpdatePackage[name, prompt]  \[RightArrow] \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:4ed8\:304d\:66f4\:65b0 (Fallback, TargetFunctions, StartTime)\n" <>
  "  ContinueUpdate[]                 \[RightArrow] \:76f4\:524d\:306e ClaudeUpdatePackage \:3092\:30d0\:30b0\:4fee\:6b63\:3067\:7d99\:7d9a\n" <>
  "  ContinueUpdate[\"\:6307\:793a\"]             \[RightArrow] \:8ffd\:52a0\:6307\:793a\:4ed8\:304d\:3067\:7d99\:7d9a\n" <>
  "  ContinueUpdate[\"pkg\", \"\:6307\:793a\"]    \[RightArrow] \:6307\:5b9a\:30d1\:30c3\:30b1\:30fc\:30b8\:306e\:66f4\:65b0\:3092\:7d99\:7d9a\n" <>
  "  ClaudeRestorePackage[name]       \[RightArrow] \:76f4\:524d\:306e\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:306b\:623b\:3059\n" <>
  "  ClaudeUpdatePackageHistory[]     \[RightArrow] \:5168\:30d1\:30c3\:30b1\:30fc\:30b8\:306e\:66f4\:65b0\:5c65\:6b74\:3092\:8868\:793a\n" <>
  "  ClaudeBackupDataset[name]        \[RightArrow] \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:5c65\:6b74\:3092 Review/Pull/Delete \:30dc\:30bf\:30f3\:4ed8\:304d Grid \:3067\:8868\:793a\n" <>
  "  ClaudeMigrateBackupHistory[name] \[RightArrow] \:751f .wl \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:3092\:5dee\:5206\:5f62\:5f0f\:306b\:5909\:63db\:3057\:5bb9\:91cf\:524a\:6e1b\n" <>
  "  ClaudeConvertToPaclet[name]     \[RightArrow] .wl \:3092 Paclet \:5f62\:5f0f\:306b\:5909\:63db\n" <>
  "  ClaudeCreateDocumentation[name] \[RightArrow] \:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:81ea\:52d5\:751f\:6210 (Fallback)\n" <>
  "  ClaudeUpdateDocumentation[name]       \[RightArrow] \:524d\:56de\:4ee5\:964d\:306e\:5909\:66f4\:3092\:81ea\:52d5\:691c\:51fa\:3057\:5168\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:66f4\:65b0\n" <>
  "  ClaudeUpdateDocumentation[name, spec] \[RightArrow] \:6307\:793a\:4ed8\:304d\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:66f4\:65b0 (Fallback)\n" <>
  "  ClaudeAddDirective[target, desc] \[RightArrow] \:30c7\:30a3\:30ec\:30af\:30c6\:30a3\:30d6\:3092\:6574\:5f62\:30fb\:8ffd\:52a0\:30fb\:30a4\:30f3\:30b9\:30c8\:30fc\:30eb\n" <>
  "  ClaudeRestoreDirective[target]   \[RightArrow] \:30c7\:30a3\:30ec\:30af\:30c6\:30a3\:30d6\:3092\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:304b\:3089\:5fa9\:5143\n" <>
  "  ClaudeListDirectives[]           \[RightArrow] \:5168\:30c7\:30a3\:30ec\:30af\:30c6\:30a3\:30d6\:4e00\:89a7\n" <>
  "  ClaudeUpdateDirective[]          \[RightArrow] \:30c7\:30a3\:30ec\:30af\:30c6\:30a3\:30d6\:5168\:30b3\:30d4\:30fc\n" <>
  "  ClaudeUpdateDirective[text]      \[RightArrow] \:6307\:793a\:3067\:30c7\:30a3\:30ec\:30af\:30c6\:30a3\:30d6\:3092\:66f4\:65b0\:30fb\:30b3\:30d4\:30fc\n" <>
  "  ClaudeDirectiveBackupDataset[]   \[RightArrow] \:30c7\:30a3\:30ec\:30af\:30c6\:30a3\:30d6\:66f4\:65b0\:5c65\:6b74\:3092 Review/Pull/Delete \:4ed8\:304d Grid \:3067\:8868\:793a\n" <>
  "  ClaudeSyncDirectives[dir]        \[RightArrow] dir \:304b\:3089 Claude Directives \:3078\:66f4\:65b0\:30d5\:30a1\:30a4\:30eb\:3092\:540c\:671f\n" <>
  "  ClaudeSessionStatus[]            \[RightArrow] \:30bb\:30c3\:30b7\:30e7\:30f3\:72b6\:614b\:30fb\:30a2\:30af\:30bb\:30b9\:53ef\:80fd\:30d5\:30a1\:30a4\:30eb\:4e00\:89a7\n" <>
  "  ClaudeStatus[]                   \[RightArrow] \:5b9f\:884c\:4e2d\:30bf\:30b9\:30af\:306e\:30ea\:30a2\:30eb\:30bf\:30a4\:30e0\:72b6\:614b\:8868\:793a\n" <>
  "  ClaudeCompactHistory[]           \[RightArrow] \:5c65\:6b74\:30b3\:30f3\:30d1\:30af\:30b7\:30e7\:30f3 (\:901a\:5e38\:81ea\:52d5)\n" <>
  "  ClaudeWebSearch[query]           \[RightArrow] Web \:691c\:7d22 (Anthropic API, \:8ab2\:91d1\:3042\:308a)\n" <>
  "  ClaudeWebFetch[url]              \[RightArrow] URL \:5185\:5bb9\:53d6\:5f97\:30fb\:8981\:7d04 (Anthropic API, \:8ab2\:91d1\:3042\:308a)\n" <>
  "  \:2192 WebSearch->True(\:30c7\:30d5\:30a9\:30eb\:30c8): Claude Code \:306e\:7d44\:307f\:8fbc\:307f Web \:691c\:7d22(\:7121\:6599)\n" <>
  "  \:2192 WebFetch->True/False/Automatic: API \:7d4c\:7531 Web \:691c\:7d22(\:8ab2\:91d1\:3042\:308a\:3001Fallback->True \:5fc5\:9808)\n" <>
  "  ClaudeCommand[\"/cmd\"]           \[RightArrow] Claude Code CLI \:30b9\:30e9\:30c3\:30b7\:30e5\:30b3\:30de\:30f3\:30c9\:5b9f\:884c\n" <>
  "  ClaudeCheckSeparation[target]   \[RightArrow] NBAccess \:5206\:96e2\:539f\:5247\:306e\:9055\:53cd\:691c\:67fb\n" <>
  "  ClaudeFixSeparation[target]     \[RightArrow] \:5206\:96e2\:9055\:53cd\:306e\:81ea\:52d5\:4fee\:6b63\n" <>
  "\n$ClaudeModel : " <> If[$ClaudeModel === "", "(Claude Code \:30c7\:30d5\:30a9\:30eb\:30c8)", $ClaudeModel] <> "\n" <>
  "$NBPrivacySpec (AccessLevel) : " <>
    ToString[Lookup[NBAccess`NBGetPrivacySpec[], "AccessLevel", 0.5]] <> "\n" <>
  "$packageDirectory : ./" <> FileNameTake[StringTrim[Global`$packageDirectory, "\\" | "/"]] <> "/\n" <>
  "$ClaudeAccessibleDirs : " <> ToString[Length[$ClaudeAccessibleDirs]] <> " dir(s)\n" <>
  "\:5c65\:6b74\:4fdd\:5b58: NBAccess \:6c4e\:7528\:5c65\:6b74DB \:2192 TaggingRules (Diff\:5dee\:5206\:5727\:7e2e)"
];

(* $packageDirectory \\:786e\\:5b9a\\:5f8c\:306b CLAUDE.md \\:3092\\:518d\\:691c\\:7d22 *)
If[$ClaudeMDContent === "", iLoadClaudeMD[]];

(* ============================================================
   \:5185\:90e8\:30e6\:30fc\:30c6\:30a3\:30ea\:30c6\:30a3
   ============================================================ *)

stripANSI[s_String] := StringReplace[s, {
  RegularExpression["\\x1B\\[[\\x30-\\x3F]*[\\x20-\\x2F]*[\\x40-\\x7E]"] -> "",
  RegularExpression["\\x1B\\][^\\x07]*\\x07"] -> "",
  RegularExpression["\\x1B[^\\[\\]]"] -> ""
}];

(* Markdown \:30b3\:30fc\:30c9\:30d5\:30a7\:30f3\:30b9\:3092\:9664\:53bb *)
iStripCodeFences[s_String] :=
  Module[{result = StringTrim[s]},
    (* ```mathematica ... ``` \:307e\:305f\:306f ``` ... ``` \:3092\:9664\:53bb *)
    result = StringReplace[result,
      StartOfString ~~ ("```mathematica" | "```wolfram" | "```wl" | "```") ~~ 
      Whitespace ~~ content__ ~~ Whitespace ~~ "```" ~~ EndOfString :> StringTrim[content]];
    result
  ];

(* ============================================================
   \:30d7\:30ed\:30f3\:30d7\:30c8\:306e\:30de\:30eb\:30c1\:30e2\:30fc\:30c0\:30eb\:6b63\:898f\:5316
   \:5165\:529b: String | {String|Image|File|expr, ...}
   \:51fa\:529b: <|"text" -> "...", "imageDirs" -> {...}|>
   ============================================================ *)

(* Mathematica \:5f0f\:3092 Claude \:304c\:7406\:89e3\:3067\:304d\:308b\:30c6\:30ad\:30b9\:30c8\:306b\:5909\:63db *)

(* GUI \:8981\:7d20\:3092\:30b9\:30c8\:30ea\:30c3\:30d7\:3057\:3066\:4e2d\:8eab\:3060\:3051\:62bd\:51fa *)
iStripGUI[Button[label_, ___]] := ToString[label];
iStripGUI[Item[content_, ___]] := iStripGUI[content];
iStripGUI[Pane[content_, ___]] := iStripGUI[content];
iStripGUI[Style[content_, ___]] := iStripGUI[content];
iStripGUI[Tooltip[content_, ___]] := iStripGUI[content];
iStripGUI[Row[items_List, ___]] := StringJoin[iStripGUI /@ items];
iStripGUI[Column[items_List, ___]] := StringJoin[Riffle[iStripGUI /@ items, "\n"]];
iStripGUI[s_String] := s;
iStripGUI[n_ /; NumericQ[n]] := ToString[n];
iStripGUI[x_] := ToString[x, InputForm];

(* Association \:5185\:306e GUI \:8981\:7d20\:3092\:518d\:5e30\:7684\:306b\:30b9\:30c8\:30ea\:30c3\:30d7 *)
iStripGUIAssoc[assoc_Association] :=
  Association[KeyValueMap[Function[{k, v}, k -> iStripGUI[v]], assoc]];

iExprToPromptText[expr_Dataset] := Module[{data, keys, nRows, cleaned, sample, txt},
  data = Normal[expr];
  nRows = Length[data];
  Which[
    MatchQ[data, {__Association}],
      keys = Keys[First[data]];
      cleaned = iStripGUIAssoc /@ data;
      sample = Take[cleaned, UpTo[10]];
      txt = "Dataset (" <> ToString[nRows] <> " \:884c, \:5217: " <>
        StringJoin[Riffle[ToString /@ keys, ", "]] <> ")\n" <>
        "\:30b5\:30f3\:30d7\:30eb\:30c7\:30fc\:30bf (\:6700\:5927 10 \:884c):\n" <>
        StringJoin[Riffle[
          MapIndexed[Function[{row, idx},
            "Row " <> ToString[First[idx]] <> ": " <>
            StringJoin[Riffle[
              KeyValueMap[Function[{k,v}, ToString[k] <> "=" <> ToString[v]], row],
              ", "]]
          ], sample],
          "\n"]],
    True,
      txt = "Dataset:\n" <> StringTake[ToString[data, InputForm], UpTo[3000]]
  ];
  txt
];

iExprToPromptText[expr_Association] :=
  "Association:\n" <> StringTake[ToString[expr, InputForm], UpTo[3000]];

iExprToPromptText[expr_List] :=
  Module[{txt},
    txt = ToString[expr, InputForm];
    "Mathematica \:30ea\:30b9\:30c8 (Length=" <> ToString[Length[expr]] <> "):\n" <>
    StringTake[txt, UpTo[3000]] <>
    If[StringLength[txt] > 3000, "\n... (\:4ee5\:4e0b\:7701\:7565)", ""]
  ];

iExprToPromptText[expr_] :=
  Module[{txt},
    txt = ToString[expr, InputForm];
    "Mathematica \:5f0f:\n" <>
    StringTake[txt, UpTo[3000]] <>
    If[StringLength[txt] > 3000, "\n... (\:4ee5\:4e0b\:7701\:7565)", ""]
  ];

(* ============================================================
   Think トリガー自動挿入システム
   
   1. 日本語の励まし表現 → 適切な think トリガーワードに変換
   2. /think 系スラッシュコマンド → プロンプト先頭に移動
   
   Claude Code CLI は think/megathink/ultrathink をプロンプト内の
   どこにあっても検出し thinking budget を設定する。
   部分的長考（プロンプト内の特定箇所だけ長考）機能は存在しない。
   キーワードは全体の budget 設定に影響する。
   ============================================================ *)

(* 日本語表現 → think レベルのマッピング
   レベル: 1=think (4K), 2=think hard (10K), 3=ultrathink (32K) *)
$iJapaneseThinkPatterns = {
  (* レベル3: ultrathink — 最大限の長考 *)
  RegularExpression["\:6b7b\:306c\:6c17\:3067\:8003\:3048"] -> 3,
  RegularExpression["\:672c\:6c17\:51fa\:305b|\:672c\:6c17\:3092\:51fa\:305b|\:672c\:6c17\:3060\:305b|\:672c\:6c17\:3067"] -> 3,
  RegularExpression["\:5168\:529b\:3067\:8003\:3048|\:5168\:529b\:3092\:51fa\:305b|\:5168\:529b\:3067\:3084"] -> 3,
  RegularExpression["\:5f7b\:5e95\:7684\:306b\:8003\:3048|\:5f7b\:5e95\:7684\:306b\:691c\:8a0e|\:5f7b\:5e95\:7684\:306b\:5206\:6790"] -> 3,
  RegularExpression["\:6b7b\:529b\:3092\:5c3d\:304f|\:3042\:3089\:3086\:308b\:53ef\:80fd\:6027|\:3042\:3089\:3086\:308b\:30b1\:30fc\:30b9"] -> 3,
  RegularExpression["\:8d85\:672c\:6c17|\:8d85\:771f\:5263"] -> 3,
  RegularExpression["\:7d76\:5bfe\:306b\:9593\:9055\:3048\:308b\:306a|\:7d76\:5bfe\:306b\:5931\:6557\:3059\:308b\:306a"] -> 3,
  (* レベル2: think hard — 中程度の長考 *)
  RegularExpression["\:3088\:304f\:8003\:3048\:3066|\:3088\:304f\:8003\:3048\:308d"] -> 2,
  RegularExpression["\:3058\:3063\:304f\:308a\:8003\:3048\:3066|\:3058\:3063\:304f\:308a\:691c\:8a0e"] -> 2,
  RegularExpression["\:3082\:3063\:3068\:8003\:3048\:3066|\:3082\:3063\:3068\:6df1\:304f"] -> 2,
  RegularExpression["\:6148\:91cd\:306b\:8003\:3048|\:6148\:91cd\:306b\:691c\:8a0e|\:6148\:91cd\:306b\:5224\:65ad"] -> 2,
  RegularExpression["\:304c\:3093\:3070\:308c|\:304c\:3093\:3070\:3063\:3066|\:8ca0\:3051\:308b\:306a|\:6c17\:5408\:3044\:5165\:308c\:3066|\:6c17\:5408\:5165\:308c\:3066"] -> 2,
  RegularExpression["\:4e01\:5be7\:306b\:8003\:3048|\:4e01\:5be7\:306b\:691c\:8a0e|\:4e01\:5be7\:306b\:5206\:6790"] -> 2,
  RegularExpression["\:6df1\:304f\:8003\:3048|\:6df1\:304f\:691c\:8a0e|\:6df1\:304f\:5206\:6790"] -> 2,
  RegularExpression["\:771f\:5263\:306b\:8003\:3048|\:771f\:5263\:306b\:691c\:8a0e"] -> 2,
  (* レベル1: think — 基本の長考 *)
  RegularExpression["\:8003\:3048\:3066\:307f\:3066|\:8003\:3048\:3066\:307f\:308d|\:8003\:3048\:3066\:304f\:308c"] -> 1,
  RegularExpression["\:5c11\:3057\:8003\:3048\:3066|\:3061\:3087\:3063\:3068\:8003\:3048\:3066"] -> 1
};

(* 日本語表現から最大の think レベルを検出 *)
iDetectJapaneseThinkLevel[text_String] :=
  Module[{maxLevel = 0},
    Scan[
      Function[rule,
        If[StringContainsQ[text, rule[[1]]],
          maxLevel = Max[maxLevel, rule[[2]]]]],
      $iJapaneseThinkPatterns];
    maxLevel
  ];

(* think レベル → トリガーワード *)
iThinkLevelToTrigger[1] := "think";
iThinkLevelToTrigger[2] := "think hard";
iThinkLevelToTrigger[3] := "ultrathink";
iThinkLevelToTrigger[_] := None;

(* 既に英語の think トリガーが含まれているかチェック *)
$iExistingThinkPattern = RegularExpression[
  "(?i)\\b(ultrathink|megathink|think\\s+(?:hard(?:er)?|really\\s+hard|very\\s+hard|deeply|more))\\b|\\bthink\\b"];

iHasExistingThinkTrigger[text_String] :=
  StringContainsQ[text, $iExistingThinkPattern];

(* メインの前処理関数: 日本語検出 + /コマンド先頭移動 *)
iHoistThinkPrefix[text_String] :=
  Module[{result = text, level, trigger, slashMatches},
    (* 1. 既に英語の think トリガーがあればそのまま返す *)
    If[iHasExistingThinkTrigger[result], Return[result]];
    (* 2. 日本語の励まし表現を検出して think トリガーを挿入 *)
    level = iDetectJapaneseThinkLevel[result];
    trigger = iThinkLevelToTrigger[level];
    If[StringQ[trigger],
      result = trigger <> "\n" <> result];
    (* 3. /think 系スラッシュコマンドがあれば先頭に移動 *)
    slashMatches = StringCases[result,
      RegularExpression["(?m)^\\s*(/think(?:\\s+(?:hard(?:er)?|really\\s+hard|very\\s+hard|deeply|more))?|/megathink|/ultrathink)\\s*$"]
      :> "$1", 1];
    If[Length[slashMatches] > 0,
      result = StringTrim[StringReplace[result,
        RegularExpression["(?m)^\\s*(/think(?:\\s+(?:hard(?:er)?|really\\s+hard|very\\s+hard|deeply|more))?|/megathink|/ultrathink)\\s*$"]
        -> "", 1]];
      result = First[slashMatches] <> "\n" <> result];
    result
  ];

iNormalizePrompt[prompt_String] := <|"text" -> prompt, "userText" -> prompt, "imageDirs" -> {}, "filePaths" -> {}|>;
iNormalizePrompt[items_List] :=
  Module[{texts = {}, imageDirs = {}, tmpDir, imgIdx = 0, fileTag = "\:6dfb\:4ed8\:30d5\:30a1\:30a4\:30eb: "},
    tmpDir = FileNameJoin[{$TemporaryDirectory,
      "claude_imgs_" <> ToString[UnixTime[]] <> "_" <> ToString[RandomInteger[99999]]}];
    Scan[Function[item,
      Which[
        (* \:6587\:5b57\:5217: \:30d5\:30a1\:30a4\:30eb\:30d1\:30b9\:3068\:30c6\:30ad\:30b9\:30c8\:3092\:5224\:5225 *)
        StringQ[item] && FileExistsQ[item] &&
          StringMatchQ[FileExtension[item], "png"|"jpg"|"jpeg"|"gif"|"bmp"|"pdf"|"txt"|"csv"|"wl"|"nb", IgnoreCase -> True],
          AppendTo[texts, fileTag <> item];
          AppendTo[imageDirs, DirectoryName[item]],
        StringQ[item],
          AppendTo[texts, item],
        (* Mathematica Image\:30aa\:30d6\:30b8\:30a7\:30af\:30c8 *)
        ImageQ[item],
          If[!DirectoryQ[tmpDir], CreateDirectory[tmpDir, CreateIntermediateDirectories -> True]];
          imgIdx++;
          With[{f = FileNameJoin[{tmpDir, "image_" <> ToString[imgIdx] <> ".png"}]},
            Export[f, item, "PNG"];
            AppendTo[texts, fileTag <> f];
            AppendTo[imageDirs, tmpDir]],
        (* File["path"] *)
        MatchQ[item, File[_String]],
          With[{f = item[[1]]},
            If[FileExistsQ[f],
              AppendTo[texts, fileTag <> f];
              AppendTo[imageDirs, DirectoryName[f]],
              AppendTo[texts, fileTag <> f <> " (\:30d5\:30a1\:30a4\:30eb\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093)"]
            ]],
        (* Dataset *)
        MatchQ[item, _Dataset],
          AppendTo[texts, iExprToPromptText[item]],
        (* Association *)
        AssociationQ[item],
          AppendTo[texts, iExprToPromptText[item]],
        (* \:305d\:306e\:4ed6\:306e\:4e00\:822c Mathematica \:5f0f *)
        True,
          AppendTo[texts, iExprToPromptText[item]]
      ]
    ], items];
    (* \:6dfb\:4ed8\:30d5\:30a1\:30a4\:30eb\:304c\:3042\:308c\:3070\:8aad\:307f\:53d6\:308a\:6307\:793a\:3092\:30c6\:30ad\:30b9\:30c8\:5148\:982d\:306b\:633f\:5165 *)
    With[{filePaths = Cases[texts, s_String /; StringStartsQ[s, fileTag]]},
      If[Length[filePaths] > 0,
        PrependTo[texts,
          "The following files are attached. " <>
          "Please use the Read tool to view each file before answering:\n" <>
          StringJoin[MapIndexed[
            Function[{p, idx}, ToString[First[idx]] <> ". " <>
              StringDrop[p, StringLength[fileTag]] <> "\n"],
            filePaths]]]]
    ];
    Module[{userTexts, fPaths},
      userTexts = Select[texts, !StringStartsQ[#, fileTag] &&
        !StringStartsQ[#, "The following files are attached"] &];
      fPaths = Cases[texts, s_String /; StringStartsQ[s, fileTag] :>
        StringDrop[s, StringLength[fileTag]]];
      <|"text" -> StringJoin[Riffle[texts, "\n\n"]],
        "userText" -> StringJoin[Riffle[userTexts, "\n\n"]],
        "imageDirs" -> DeleteDuplicates[imageDirs],
        "filePaths" -> fPaths|>
    ]
  ];

(* \:30d5\:30a9\:30fc\:30eb\:30d0\:30c3\:30af: \:3069\:3061\:3089\:306b\:3082\:30de\:30c3\:30c1\:3057\:306a\:3044\:5834\:5408 *)
iNormalizePrompt[x_] := <|"text" -> iExprToPromptText[x], "userText" -> iExprToPromptText[x], "imageDirs" -> {}, "filePaths" -> {}|>;

(* ============================================================
   <<name>> \:30b7\:30f3\:30dc\:30eb\:53c2\:7167\:5c55\:958b
   \:30fb\:30d7\:30ed\:30f3\:30d7\:30c8\:4e2d\:306e <<varName>> \:3092\:691c\:51fa\:3057\:3001\:5909\:6570/\:95a2\:6570\:306e\:30e1\:30bf\:60c5\:5831\:3092\:4ed8\:52a0
   \:30fb\:6a5f\:5bc6\:5909\:6570\:306f\:69cb\:9020\:60c5\:5831\:306e\:307f\:3001\:5024\:306f\:30d7\:30ed\:30f3\:30d7\:30c8\:304b\:3089\:9664\:5916
   \:30fb\:901a\:5e38\:5909\:6570\:306f Short \:30d7\:30ec\:30d3\:30e5\:30fc\:4ed8\:304d
   \:8a18\:6cd5\:9078\:5b9a\:7406\:7531:
     <<>> \:306f Mathematica \:6587\:5b57\:5217\:5185\:3067\:7279\:6b8a\:610f\:5473\:306a\:3057
     Markdown \:3068\:885d\:7a81\:306a\:3057\:ff08HTML \:30bf\:30b0\:306f <tag> \:3067 <<>> \:3068\:306f\:7570\:306a\:308b\:ff09
     \:5165\:529b\:304c\:5bb9\:6613\:ff08Shift \:4e0d\:8981\:30672\:30ad\:30fc\:9023\:6253\:ff09
   ============================================================ *)

(* \:5358\:4e00\:30b7\:30f3\:30dc\:30eb\:306e\:60c5\:5831\:3092\:8a18\:8ff0 *)
(* \:30d7\:30ed\:30f3\:30d7\:30c8\:4e2d\:306e <<\:5909\:6570\:540d>> \:3092\:691c\:51fa\:3057\:3001\:5909\:6570\:60c5\:5831\:30d6\:30ed\:30c3\:30af\:3092\:672b\:5c3e\:306b\:4ed8\:52a0 *)
iExpandSymbolRefs[text_String] :=
  Module[{refs, infos, infoBlock},
    refs = DeleteDuplicates[StringCases[text,
      RegularExpression["<<((?:[a-zA-Z$]|[\\p{L}])[^>]*)>>"] :> "$1"]];
    If[Length[refs] === 0, Return[text]];
    infos = iDescribeSymbol /@ refs;
    infos = Map[If[StringQ[#], #, ToString[#]] &, infos];
    infoBlock = "\n\n=== \:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:5909\:6570\:30fb\:95a2\:6570\:60c5\:5831 ===\n" <>
      "\:ff08<<n>> \:306f\:3053\:306e\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:306e\:30ab\:30fc\:30cd\:30eb\:306b\:5b58\:5728\:3059\:308b\:30b7\:30f3\:30dc\:30eb\:3078\:306e\:53c2\:7167\:3067\:3059\:3002" <>
      "\:30b3\:30f3\:30c6\:30ad\:30b9\:30c8\:304b\:3089\:30a2\:30af\:30bb\:30b9\:53ef\:80fd\:306a\:5024\:306e\:307f\:8868\:793a\:3055\:308c\:307e\:3059\:3002\:ff09\n" <>
      StringJoin[Riffle[infos, "\n"]];
    text <> infoBlock
  ];

(* \:5358\:4e00\:30b7\:30f3\:30dc\:30eb\:306e\:60c5\:5831\:3092\:8a18\:8ff0 *)
iDescribeSymbol[name_String] :=
  Module[{defined, val, head, desc, isConf, dimStr, lenStr, previewStr},
    (* \\:76f4\\:63a5\\:6a5f\\:5bc6 or \\:63a8\\:79fb\\:4f9d\\:5b58\\:6a5f\\:5bc6\\:306e\\:4e21\\:65b9\\:3092\\:30c1\\:30a7\\:30c3\\:30af *)
    isConf  = TrueQ[$confidentialSymbols[name]] || TrueQ[$allConfidentialVars[name]];
    defined = Quiet[ToExpression["ValueQ[Global`" <> name <> "]"]];

    (* \:95a2\:6570\:5b9a\:7fa9\:ff08DownValues\:ff09\:306e\:6709\:7121\:3092\:78ba\:8a8d *)
    If[!TrueQ[defined],
      With[{dv = Quiet[ToExpression["DownValues[Global`" <> name <> "]"]]},
        If[ListQ[dv] && Length[dv] > 0,
          Return["<<" <> name <> ">> : " <>
            If[isConf, "[\:6a5f\:5bc6] ", ""] <>
            "\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:5b9a\:7fa9\:306e\:95a2\:6570 (" <> ToString[Length[dv]] <> " \:898f\:5247)"]
        ]
      ];
      Return["<<" <> name <> ">> : \:672a\:5b9a\:7fa9\:306e\:30b7\:30f3\:30dc\:30eb"]
    ];

    val  = Quiet[ToExpression["Global`" <> name]];
    head = Head[val];
    desc = "<<" <> name <> ">> : ";

    If[isConf,
      (* \:6a5f\:5bc6\:5909\:6570: \:69cb\:9020\:60c5\:5831\:306e\:307f *)
      desc = desc <> "[\:6a5f\:5bc6] Head=" <> ToString[head];
      If[ListQ[val],
        desc = desc <> ", Dimensions=" <> ToString[Dimensions[val]]];
      If[MatchQ[val, _Association],
        desc = desc <> ", Keys=" <> ToString[Keys[val]]];
      If[MatchQ[val, _Dataset],
        desc = desc <> ", Dimensions=" <>
          ToString[Quiet[Dimensions[val]]]];
      desc = desc <> " (\:5024\:306f\:6a5f\:5bc6\:306e\:305f\:3081\:30d7\:30ed\:30f3\:30d7\:30c8\:304b\:3089\:9664\:5916)",
      (* \:901a\:5e38\:5909\:6570: \:30d7\:30ec\:30d3\:30e5\:30fc\:4ed8\:304d *)
      previewStr = Quiet[ToString[Short[val, 3]]];
      If[StringLength[previewStr] > 500,
        previewStr = StringTake[previewStr, 500] <> "..."];
      desc = desc <> "Head=" <> ToString[head];
      If[ListQ[val],
        desc = desc <> ", Dimensions=" <> ToString[Dimensions[val]]];
      If[MatchQ[val, _Association],
        desc = desc <> ", Keys=" <> ToString[Keys[val]]];
      desc = desc <> "\n  \:5024(\:30d7\:30ec\:30d3\:30e5\:30fc): " <> previewStr
    ];
    desc
  ];



(* \:30c7\:30ea\:30df\:30bf\:9593\:306e\:30c6\:30ad\:30b9\:30c8\:3092\:62bd\:51fa\:ff08StringSplit\:30d9\:30fc\:30b9\:3067\:78ba\:5b9f\:ff09 *)
iExtractBetweenMarkers[text_String, beginMark_String, endMark_String] :=
  Module[{parts, inner},
    (* beginMark \:3067\:5206\:5272 *)
    parts = StringSplit[text, beginMark, 2];
    If[Length[parts] < 2, Return[""]];
    inner = parts[[2]];
    (* endMark \:3067\:5206\:5272 *)
    parts = StringSplit[inner, endMark, 2];
    If[Length[parts] < 1, Return[""]];
    StringTrim[parts[[1]]]
  ];

iSaveSessionMedia[sessionDir_String, promptText_String, imageDirs_List] :=
  Module[{imgDest},
    Export[FileNameJoin[{sessionDir, "prompt.txt"}], promptText, "Text"];
    Scan[Function[dir,
      Scan[Function[f,
        imgDest = FileNameJoin[{sessionDir, FileNameTake[f]}];
        Quiet[CopyFile[f, imgDest]]
      ], FileNames["*.png", dir]]
    ], imageDirs]
  ];

iLoadPackageHistory[bdir_String, packageName_String, maxSessions_Integer:3] :=
  Module[{dirs, sessions, ctx},
    If[!DirectoryQ[bdir], Return[""]];
    dirs = Sort[Select[FileNames["*", bdir], DirectoryQ]];
    dirs = Select[dirs, !StringStartsQ[FileNameTake[#], "pre_"] &];
    If[Length[dirs] === 0, Return[""]];
    sessions = Take[Reverse[dirs], UpTo[maxSessions]];
    sessions = Reverse[sessions];
    (* Function\:5185\:3067 Return\:304c\:52b9\:304b\:306a\:3044\:306e\:3067 If\:3067\:5206\:5c90 *)
    ctx = StringJoin[MapIndexed[
      Function[{dir, idx},
        With[{pFile = FileNameJoin[{dir, "prompt.txt"}],
              rFile = FileNameJoin[{dir, "response.txt"}]},
          If[!FileExistsQ[pFile] || !FileExistsQ[rFile],
            "",
            Module[{pText, rText, instr, endMark, afterEnd, step},
              pText = Import[pFile, "Text"];
              rText = Import[rFile, "Text"];
              instr = StringTrim[Last[StringSplit[pText, "INSTRUCTION: ", 2], ""]];
              If[instr === "", instr = StringTake[pText, UpTo[300]]];
              endMark = If[StringContainsQ[rText, "===END_FUNCTIONS==="],
                "===END_FUNCTIONS===", "===END_PACKAGE==="];
              afterEnd = StringTrim[Last[StringSplit[rText, endMark, 2], ""]];
              step = First[idx];
              "=== \:5c65\:6b74 " <> ToString[step] <> " (" <> FileNameTake[dir] <> ") ===\n" <>
              "[\:6307\:793a] " <> StringTake[instr, UpTo[500]] <> "\n" <>
              If[afterEnd =!= "",
                "[\:7d50\:679c\:306e\:8981\:70b9] " <> StringTake[afterEnd, UpTo[600]] <> "\n",
                ""] <>
              "\n"
            ]
          ]
        ]
      ],
      sessions
    ]];
    If[StringTrim[ctx] === "", "",
      "=== \:904e\:53bb\:306e\:5909\:66f4\:5c65\:6b74 (\:5c65\:6b74\:304c\:3042\:308c\:3070\:53c2\:8003\:306b) ===\n" <> ctx]
  ];

cleanOutput[s_String] := StringTrim[
  StringReplace[s,
    RegularExpression["[\\x00-\\x08\\x0B-\\x0C\\x0E-\\x1F\\x7F]"] -> ""]
];

cleanMarkdown[s_String] := StringTrim @ StringReplace[s, {
  RegularExpression["(?m)^#{1,6}\\s*"] -> "",
  RegularExpression["\\*\\*(.+?)\\*\\*"] -> "$1",
  RegularExpression["__(.+?)__"] -> "$1",
  RegularExpression["(?m)^[-*]{3,}\\s*$"] -> "",
  RegularExpression["`([^`]+)`"] -> "$1",
  RegularExpression["(?m)^\\|.*\\|\\s*$"] -> "",
  RegularExpression["(?m)^[|:\\-\\s]+$"] -> "",
  RegularExpression["\\n{3,}"] -> "\n\n"
}];

(* テキスト中の $...$ / $$...$$ LaTeX 数式を Mathematica インライン数式に変換して Cell を作る *)

(* TeX前処理: Mathematica の TeXForm パーサーが扱えないコマンドを正規化 *)
iTeXPreprocess[tex_String] :=
  StringReplace[tex, {
    (* \mathbf{X} → X, \mathrm{X} → X, \text{X} → X *)
    RegularExpression["\\\\math(?:bf|rm|cal|it|sf|tt)\\{([^}]*)\\}"] -> "$1",
    RegularExpression["\\\\text(?:rm|bf|it|sf)?\\{([^}]*)\\}"] -> "$1",
    RegularExpression["\\\\boldsymbol\\{([^}]*)\\}"] -> "$1",
    (* \hat{X} → X, \tilde{X} → X, \bar{X} → X, \vec{X} → X *)
    RegularExpression["\\\\(?:hat|tilde|bar|vec|dot|ddot|overline|underline|widehat|widetilde)\\{([^}]*)\\}"] -> "$1",
    (* Mathematica 角括弧混在を丸括弧に変換: \Psi[x,t] → \Psi(x,t) *)
    RegularExpression["\\\\([A-Za-z]+)\\[([^\\]]*?)\\]"] -> "\\$1($2)",
    (* 残りの [...] → (...) （TeXにない角括弧記法） *)
    RegularExpression["([A-Za-z])\\[([^\\]]{1,30})\\]"] -> "$1($2)",
    (* \, \; \! \quad 等のスペースコマンドを除去 *)
    RegularExpression["\\\\[,;!]"] -> " ",
    RegularExpression["\\\\(?:quad|qquad|hspace\\{[^}]*\\})"] -> " ",
    (* \left \right を除去 *)
    "\\left" -> "", "\\right" -> "",
    (* \cdot → * *)
    "\\cdot" -> " "
  }];

(* 単一の TeX 式を Mathematica Box に変換。失敗時は $Failed *)
(* MakeBoxes[HoldAllComplete] を使い、等式(==)等が評価されるのを防ぐ *)
iTeXToBoxes[tex_String] :=
  Module[{cleaned, expr, boxes},
    cleaned = iTeXPreprocess[tex];
    expr = Quiet @ Check[ToExpression[cleaned, TeXForm, HoldComplete], $Failed];
    If[expr === $Failed, Return[$Failed]];
    boxes = Quiet @ Check[
      expr /. HoldComplete[e_] :> MakeBoxes[e, StandardForm],
      $Failed];
    boxes
  ];

(* 等式を含む TeX 式を分割して変換: "lhs = rhs" → Row[{lhs, "=", rhs}] *)
iTeXEquationToBoxes[tex_String] :=
  Module[{eqParts, lhsBoxes, rhsBoxes, sep},
    (* まず全体を試す *)
    Module[{direct = iTeXToBoxes[tex]},
      If[direct =!= $Failed, Return[direct]]];
    (* "=" で分割して左辺・右辺を個別に変換 *)
    eqParts = StringSplit[tex, RegularExpression["\\s*=\\s*"], 2];
    If[Length[eqParts] === 2,
      lhsBoxes = iTeXToBoxes[StringTrim[eqParts[[1]]]];
      rhsBoxes = iTeXToBoxes[StringTrim[eqParts[[2]]]];
      sep = "=";
      If[lhsBoxes =!= $Failed && rhsBoxes =!= $Failed,
        Return[RowBox[{lhsBoxes, sep, rhsBoxes}]]];
      (* 片方だけ成功した場合 *)
      If[lhsBoxes =!= $Failed,
        Return[RowBox[{lhsBoxes, "=", StringTrim[eqParts[[2]]]}]]];
      If[rhsBoxes =!= $Failed,
        Return[RowBox[{StringTrim[eqParts[[1]]], "=", rhsBoxes}]]]
    ];
    $Failed
  ];

iTeXMathToCell[text_String, style_String] :=
  Module[{preprocessed, parts, result = {}, tex, boxes},
    (* $$...$$ → $...$ に正規化（改行を含むケースにも対応） *)
    preprocessed = StringReplace[text,
      RegularExpression["(?s)\\$\\$(.+?)\\$\\$"] :> "$" <> "$1" <> "$"];
    (* $...$ を区切りとして分割（改行を含むケースにも対応） *)
    parts = StringSplit[preprocessed,
      RegularExpression["(?s)\\$([^$]+?)\\$"] :> "$TEXMATH$" <> "$1"];
    If[Length[parts] === 1 && !StringContainsQ[preprocessed, "$"],
      (* LaTeX 数式なし → 通常のテキストセル *)
      Return[Cell[text, style]]];
    Do[
      If[StringStartsQ[p, "$TEXMATH$"],
        tex = StringDrop[p, StringLength["$TEXMATH$"]];
        boxes = iTeXEquationToBoxes[tex];
        If[boxes =!= $Failed,
          AppendTo[result,
            Cell[BoxData[boxes], "InlineFormula"]];
          Continue[]
        ];
        (* 変換失敗 → $tex$ 形式のままイタリックで表示 *)
        AppendTo[result,
          Cell[BoxData[StyleBox["$" <> tex <> "$",
            FontSlant -> "Italic", FontColor -> GrayLevel[0.4]]],
            "InlineFormula"]],
        (* 通常テキスト部分 *)
        If[p =!= "", AppendTo[result, p]]
      ],
      {p, parts}];
    If[Length[result] === 1 && StringQ[First[result]],
      Cell[First[result], style],
      Cell[TextData[result], style]]
  ];

(* ClaudeQuery 応答をマークダウン解析して適切なスタイルのセルで出力 *)
iFlushQueryTextBuf[nb_NotebookObject, buf_List] :=
  If[Length[buf] > 0,
    (* Job システムがカーソルをアンカー位置に配置済み。
       NotebookWrite[..., After] で順次チェインする。 *)
    NBAccess`NBWriteCell[nb,
      iTeXMathToCell[StringJoin[Riffle[buf, "\n"]], "Text"]]];

iWriteQueryResponse[nb_NotebookObject, text_String, autoEvaluate_:False] :=
  Module[{lines, i, line, trimmed, textBuf = {}, content,
          inCodeBlock = False, codeLang = "", codeBuf = {}},
    (* Job システムがカーソルをアンカー位置に配置済み。
       ここから After 書き込みが順次チェインする。 *)
    lines = StringSplit[text, "\n"];
    Do[
      line = lines[[i]];
      trimmed = StringTrim[line];
      Which[
        (* コードブロック開始: ```lang *)
        !inCodeBlock && StringMatchQ[trimmed, "```" ~~ ___],
          iFlushQueryTextBuf[nb, textBuf]; textBuf = {};
          codeLang = StringTrim[StringReplace[trimmed,
            RegularExpression["^```\\s*"] -> ""]];
          inCodeBlock = True;
          codeBuf = {},

        (* コードブロック終了: ``` *)
        inCodeBlock && StringMatchQ[trimmed, "```"],
          inCodeBlock = False;
          If[Length[codeBuf] > 0,
            Module[{codeText = StringJoin[Riffle[codeBuf, "\n"]]},
              If[MemberQ[{"mathematica", "wolfram", "wl", "mma"}, ToLowerCase[codeLang]],
                (* Mathematica コード → Input セル（AutoEvaluate に従う） *)
                iWriteSmartCell[nb, codeText, autoEvaluate],
                (* 他の言語やコードブロック → Program セル *)
                NBAccess`NBWriteCell[nb, Cell[codeText, "Program"]]]]];
          codeBuf = {};
          codeLang = "",

        (* コードブロック内: そのまま蓄積（Item等の解釈をしない） *)
        inCodeBlock,
          AppendTo[codeBuf, line],

        (* --- 以下はコードブロック外の通常処理 --- *)

        (* 空行: バッファフラッシュ *)
        trimmed === "",
          iFlushQueryTextBuf[nb, textBuf]; textBuf = {},

        (* ### 見出し → Subsubsection *)
        StringContainsQ[trimmed, RegularExpression["^#{3,}\\s"]],
          iFlushQueryTextBuf[nb, textBuf]; textBuf = {};
          content = StringTrim[StringReplace[trimmed,
            RegularExpression["^#{3,}\\s*"] -> ""]];
          content = StringReplace[content, "**" -> ""];
          NBAccess`NBWriteCell[nb, iTeXMathToCell[content, "Subsubsection"]],

        (* ## 見出し → Subsection *)
        StringContainsQ[trimmed, RegularExpression["^#{2}\\s"]],
          iFlushQueryTextBuf[nb, textBuf]; textBuf = {};
          content = StringTrim[StringReplace[trimmed,
            RegularExpression["^#{2}\\s*"] -> ""]];
          content = StringReplace[content, "**" -> ""];
          NBAccess`NBWriteCell[nb, iTeXMathToCell[content, "Subsection"]],

        (* # 見出し → Subsection *)
        StringContainsQ[trimmed, RegularExpression["^#\\s"]],
          iFlushQueryTextBuf[nb, textBuf]; textBuf = {};
          content = StringTrim[StringReplace[trimmed,
            RegularExpression["^#\\s*"] -> ""]];
          content = StringReplace[content, "**" -> ""];
          NBAccess`NBWriteCell[nb, iTeXMathToCell[content, "Subsection"]],

        (* 深いインデントリスト → Subsubitem *)
        StringContainsQ[line, RegularExpression["^(\\s{4,}|\\t\\t)[-*\:2022]\\s"]],
          iFlushQueryTextBuf[nb, textBuf]; textBuf = {};
          content = StringTrim[StringReplace[trimmed,
            RegularExpression["^[-*\:2022]\\s*"] -> ""]];
          content = StringReplace[content, "**" -> ""];
          NBAccess`NBWriteCell[nb, iTeXMathToCell[content, "Subsubitem"]],

        (* 浅いインデントリスト → Subitem *)
        StringContainsQ[line, RegularExpression["^(\\s{2,3}|\\t)[-*\:2022]\\s"]],
          iFlushQueryTextBuf[nb, textBuf]; textBuf = {};
          content = StringTrim[StringReplace[trimmed,
            RegularExpression["^[-*\:2022]\\s*"] -> ""]];
          content = StringReplace[content, "**" -> ""];
          NBAccess`NBWriteCell[nb, iTeXMathToCell[content, "Subitem"]],

        (* リスト項目 (箇条書き) → Item *)
        StringContainsQ[trimmed, RegularExpression["^[-*\:2022]\\s"]],
          iFlushQueryTextBuf[nb, textBuf]; textBuf = {};
          content = StringTrim[StringReplace[trimmed,
            RegularExpression["^[-*\:2022]\\s*"] -> ""]];
          content = StringReplace[content, "**" -> ""];
          NBAccess`NBWriteCell[nb, iTeXMathToCell[content, "Item"]],

        (* 番号付きリスト → Item *)
        StringContainsQ[trimmed, RegularExpression["^\\d+\\.\\s"]],
          iFlushQueryTextBuf[nb, textBuf]; textBuf = {};
          content = StringTrim[StringReplace[trimmed,
            RegularExpression["^\\d+\\.\\s*"] -> ""]];
          content = StringReplace[content, "**" -> ""];
          NBAccess`NBWriteCell[nb, iTeXMathToCell[content, "Item"]],

        (* 水平線 → 無視 *)
        StringMatchQ[trimmed, RegularExpression["^[-*_]{3,}$"]],
          iFlushQueryTextBuf[nb, textBuf]; textBuf = {},

        (* 通常テキスト → バッファに追加 *)
        True,
          content = StringReplace[trimmed, {"**" -> "", "__" -> ""}];
          AppendTo[textBuf, content]
      ],
      {i, Length[lines]}];

    (* コードブロックが閉じられなかった場合もフラッシュ *)
    If[inCodeBlock && Length[codeBuf] > 0,
      Module[{codeText = StringJoin[Riffle[codeBuf, "\n"]]},
        If[MemberQ[{"mathematica", "wolfram", "wl", "mma"}, ToLowerCase[codeLang]],
          iWriteSmartCell[nb, codeText, autoEvaluate],
          NBAccess`NBWriteCell[nb, Cell[codeText, "Program"]]]]];
    (* 残りをフラッシュ *)
    iFlushQueryTextBuf[nb, textBuf];
  ];

(* ============================================================
   \:30b3\:30a2\:547c\:3073\:51fa\:3057\:95a2\:6570
   ============================================================ *)

(* \:4f4e\:30ec\:30d9\:30eb\:540c\:671f\:547c\:3073\:51fa\:3057\:ff08\:5c65\:6b74\:4fdd\:5b58\:306a\:3057\:ff09 *)
iClaudeQueryRaw[prompt_] := Module[
  {outFile, promptFile, batFile, res, raw, norm},

  norm       = iNormalizePrompt[iInjectAttachments[prompt]];
  outFile    = FileNameJoin[{$TemporaryDirectory,
    "claude_out_"    <> ToString[UnixTime[]] <> ".txt"}];
  promptFile = FileNameJoin[{$TemporaryDirectory,
    "claude_prompt_" <> ToString[UnixTime[]] <> ".txt"}];

  If[FileExistsQ[outFile],    DeleteFile[outFile]];
  If[FileExistsQ[promptFile], DeleteFile[promptFile]];

  Block[{strm},
    strm = OpenWrite[promptFile, BinaryFormat -> True];
    BinaryWrite[strm, ExportString[norm["text"], "Text", CharacterEncoding -> "UTF-8"]];
    Close[strm]
  ];

  batFile = iMakeBat[promptFile, outFile, norm["imageDirs"]];
  res = TimeConstrained[RunProcess[{"cmd", "/c", batFile}, All], $ClaudeTimeout, "TIMEOUT"];
  Quiet[DeleteFile[batFile]];
  Quiet[DeleteFile[promptFile]];

  If[res === "TIMEOUT", Return["Error: \:30bf\:30a4\:30e0\:30a2\:30a6\:30c8\:ff08" <> ToString[$ClaudeTimeout] <> "\:79d2\:ff09\:3057\:307e\:3057\:305f\:3002"]];
  If[res === $Failed,   Return["Error: RunProcess \:304c $Failed \:3092\:8fd4\:3057\:307e\:3057\:305f"]];
  If[!FileExistsQ[outFile],
    Return["Error (ExitCode=" <> ToString[res["ExitCode"]] <>
           "): \:51fa\:529b\:30d5\:30a1\:30a4\:30eb\:304c\:751f\:6210\:3055\:308c\:307e\:305b\:3093\:3067\:3057\:305f\n" <> res["StandardError"]]
  ];

  raw = Import[outFile, "Text"];
  Quiet[DeleteFile[outFile]];
  cleanOutput[stripANSI[raw]]
];

(* ============================================================
   Fallback: Claude Code \:5229\:7528\:4e0d\:53ef\:6642\:306e API \:76f4\:63a5\:547c\:3073\:51fa\:3057
   ============================================================ *)

(* \:30a8\:30e9\:30fc\:5fdc\:7b54\:304b\:3089\:5229\:7528\:5236\:9650\:30fb\:63a5\:7d9a\:4e0d\:53ef\:3092\:691c\:51fa *)
iIsLimitError[response_String] :=
  StringContainsQ[response,
    "hit your limit" | "rate limit" | "overloaded" |
    "TIMEOUT" | "RunProcess" | "ExitCode=",
    IgnoreCase -> True] ||
  (* "resets" は単独では誤判定しやすいので "limit" との共起を要求 *)
  (StringContainsQ[response, "resets", IgnoreCase -> True] &&
   StringContainsQ[response, "limit" | "hit your", IgnoreCase -> True]);

(* API レスポンスがエラー/制限メッセージかを判定する統一関数。
   ファイル書き込み前に必ずチェックし、ファイル破損を防止する。 *)
iIsAPIErrorResponse[response_String] :=
  StringStartsQ[response, "Error"] ||
  StringContainsQ[response,
    "hit your limit" | "rate limit" | "overloaded" | "unavailable",
    IgnoreCase -> True] ||
  (* CenterDot (·) 付きリミットメッセージ: "You've hit your limit · resets..." *)
  StringContainsQ[response, "\[CenterDot]"] ||
  StringContainsQ[response, "\:00b7"] ||  (* UTF-8 middle dot *)
  (* 短すぎる応答 (正常なドキュメントやコードにはならない) *)
  (StringLength[response] < 100 &&
   StringContainsQ[response, "resets" | "limit" | "error" | "failed",
     IgnoreCase -> True]);

iIsAPIErrorResponse[_] := True;  (* 非文字列は常にエラー扱い *)

iHTTPResponseBodyUTF8[resp_HTTPResponse] := Module[{bytes, body},
  bytes = Quiet @ Check[resp["BodyByteArray"], $Failed];
  If[Head[bytes] === ByteArray,
    Return[
      Quiet @ Check[
        FromCharacterCode[Normal[bytes], "UTF-8"],
        $Failed
      ]
    ]
  ];
  body = Quiet @ Check[resp["Body"], $Failed];
  If[StringQ[body], body, ToString[body]]
];


iFindJSONStringValueStartForKey[bytes_List, key_String] := Module[
  {keyBytes, keyLen, n, i, j},
  keyBytes = ToCharacterCode["\"" <> key <> "\"", "ASCII"];
  keyLen = Length[keyBytes];
  n = Length[bytes];
  For[i = 1, i <= n - keyLen + 1, i++,
    If[bytes[[i ;; i + keyLen - 1]] === keyBytes,
      j = i + keyLen;
      While[j <= n && MemberQ[{9, 10, 13, 32}, bytes[[j]]], j++];
      If[j > n || bytes[[j]] =!= 58, Continue[]];
      j++;
      While[j <= n && MemberQ[{9, 10, 13, 32}, bytes[[j]]], j++];
      If[j <= n && bytes[[j]] === 34,
        Return[j + 1]
      ]
    ]
  ];
  Missing["NotFound"]
];

iJSONStringFromBytes[bytes_List, start_Integer] := Module[
  {n, i, rawBytes, pieces, flushRaw, b, esc, hexStr, code, low},
  n = Length[bytes];
  i = start;
  rawBytes = {};
  pieces = {};
  flushRaw := (
    If[rawBytes =!= {},
      AppendTo[pieces, Quiet @ Check[FromCharacterCode[rawBytes, "UTF-8"], FromCharacterCode[rawBytes]]];
      rawBytes = {}
    ]
  );
  While[i <= n,
    b = bytes[[i]];
    If[b === 34,
      flushRaw;
      Return[StringJoin[pieces]]
    ];
    If[b === 92,
      flushRaw;
      i++;
      If[i > n, Break[]];
      esc = bytes[[i]];
      Switch[esc,
        34, AppendTo[pieces, "\""] ,
        92, AppendTo[pieces, "\\"],
        47, AppendTo[pieces, "/"],
        98, AppendTo[pieces, FromCharacterCode[{8}]],
        102, AppendTo[pieces, FromCharacterCode[{12}]],
        110, AppendTo[pieces, "\n"],
        114, AppendTo[pieces, "\r"],
        116, AppendTo[pieces, "\t"],
        117,
          If[i + 4 <= n,
            hexStr = FromCharacterCode[bytes[[i + 1 ;; i + 4]], "ASCII"];
            code = Quiet @ Check[FromDigits[hexStr, 16], $Failed];
            If[IntegerQ[code],
              i += 4;
              If[55296 <= code <= 56319 && i + 6 <= n && bytes[[i + 1]] === 92 && bytes[[i + 2]] === 117,
                hexStr = FromCharacterCode[bytes[[i + 3 ;; i + 6]], "ASCII"];
                low = Quiet @ Check[FromDigits[hexStr, 16], $Failed];
                If[IntegerQ[low] && 56320 <= low <= 57343,
                  code = 65536 + 1024 (code - 55296) + (low - 56320);
                  i += 6
                ]
              ];
              AppendTo[pieces, FromCharacterCode[{code}, "Unicode"]],
              AppendTo[pieces, "\\u" <> hexStr]
            ],
            AppendTo[pieces, "\\u"]
          ],
        _, AppendTo[pieces, FromCharacterCode[{esc}]]
      ],
      AppendTo[rawBytes, b]
    ];
    i++
  ];
  flushRaw;
  StringJoin[pieces]
];

iExtractJSONStringValueByKeyFromByteArray[ba_ByteArray, key_String] := Module[
  {bytes, start},
  bytes = Normal[ba];
  start = iFindJSONStringValueStartForKey[bytes, key];
  If[MissingQ[start], Return[$Failed]];
  iJSONStringFromBytes[bytes, start]
];

iReadFileByteArray[file_String] := Module[{strm, data},
  If[!FileExistsQ[file], Return[$Failed]];
  strm = Quiet @ Check[OpenRead[file, BinaryFormat -> True], $Failed];
  If[strm === $Failed, Return[$Failed]];
  data = Quiet @ Check[BinaryReadList[strm, "Byte"], $Failed];
  Quiet @ Check[Close[strm], Null];
  If[ListQ[data], ByteArray[data], $Failed]
];

iByteArrayToUTF8String[ba_ByteArray] :=
  Quiet @ Check[FromCharacterCode[Normal[ba], "UTF-8"], $Failed];

iMakeTempDir[prefix_String:"claudecode-anthropic-"] := Module[{dir},
  dir = FileNameJoin[{
    $TemporaryDirectory,
    prefix <> IntegerString[Round[AbsoluteTime[]*1000]] <> "-" <>
      IntegerString[RandomInteger[10^9]]
  }];
  CreateDirectory[dir, CreateIntermediateDirectories -> True]
];


iWhereCommandPaths[name_String] := Module[{res, out, lines},
  res = Quiet @ Check[
    RunProcess[{"cmd", "/c", "where " <> name}, All],
    $Failed
  ];
  If[AssociationQ[res] && Lookup[res, "ExitCode", 1] === 0,
    out = Lookup[res, "StandardOutput", ""];
    If[StringQ[out] && StringTrim[out] =!= "",
      lines = StringTrim /@ StringSplit[StringReplace[out, "\r\n" -> "\n"], "\n"];
      Return[Select[lines, StringLength[#] > 0 &]]
    ]
  ];
  {}
];

iResolvePowerShellExe[] := Module[{sysRoot, candidates},
  sysRoot = Quiet @ Check[Environment["SystemRoot"], $Failed];
  candidates = DeleteDuplicates @ Join[
    iWhereCommandPaths["powershell.exe"],
    iWhereCommandPaths["powershell"],
    iWhereCommandPaths["pwsh.exe"],
    iWhereCommandPaths["pwsh"],
    Select[{
      If[StringQ[sysRoot] && sysRoot =!= "",
        FileNameJoin[{sysRoot, "System32", "WindowsPowerShell", "v1.0", "powershell.exe"}],
        Nothing
      ],
      If[StringQ[sysRoot] && sysRoot =!= "",
        FileNameJoin[{sysRoot, "Sysnative", "WindowsPowerShell", "v1.0", "powershell.exe"}],
        Nothing
      ],
      "powershell.exe",
      "powershell",
      "pwsh.exe",
      "pwsh"
    }, StringQ]
  ];
  FirstCase[
    candidates,
    c_ /; (
      (StringContainsQ[c, "\\" | "/"] && FileExistsQ[c]) ||
      !StringContainsQ[c, "\\" | "/"]
    ) :> c,
    $Failed
  ]
];

(* Anthropic Messages API \:7d4c\:7531\:3067\:30af\:30a8\:30ea
   URLRead \:7d4c\:7531\:3060\:3068 Windows/ShiftJIS \:74b0\:5883\:3067
   Body \:304c ISO-8859-1 \:98a8\:306b\:8aa4\:89e3\:91c8\:3055\:308c\:3001
   ã... \:578b\:306e\:6587\:5b57\:5316\:3051\:304c\:767a\:751f\:3059\:308b\:3053\:3068\:304c\:3042\:308b。
   そのため Anthropi c だけは curl で生の JSON \:3092\:30d5\:30a1\:30a4\:30eb\:306b\:4fdd\:5b58\:3057、
   その UTF-8 \:30d0\:30a4\:30c8\:5217\:304b\:3089\:76f4\:63a5\:30d1\:30fc\:30b9\:3059\:308b。 *)
iQueryAnthropicAPI[apiKey_String, model_String, prompt_String] :=
  Module[{url, psExe, tmpDir = None, promptFile, outFile, errFile, ps1File,
          script, res, ba, errText, text, strm},
    url = "https://api.anthropic.com/v1/messages";

    psExe = iResolvePowerShellExe[];

    If[!StringQ[psExe] || StringTrim[psExe] === "",
      Return[
        "Error: PowerShell の実行ファイルを解決できません。Anthropic fallback には powershell.exe または pwsh が必要です。"
      ]
    ];

    Internal`WithLocalSettings[
      tmpDir = iMakeTempDir[];
      promptFile = FileNameJoin[{tmpDir, "prompt.txt"}];
      outFile    = FileNameJoin[{tmpDir, "response.txt"}];
      errFile    = FileNameJoin[{tmpDir, "error.txt"}];
      ps1File    = FileNameJoin[{tmpDir, "anthropic_fallback.ps1"}];

      strm = OpenWrite[promptFile, BinaryFormat -> True];
      BinaryWrite[strm, ToCharacterCode[iHoistThinkPrefix[prompt], "UTF-8"], "Byte"];
      Close[strm];

      script =
        "param([string]$PromptFile,[string]$OutFile,[string]$ErrFile,[string]$ApiKey,[string]$Url,[string]$Model)
" <>
        "$ErrorActionPreference = 'Stop'
" <>
        "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
" <>
        "$utf8 = New-Object System.Text.UTF8Encoding($false)
" <>
        "try {
" <>
        "  Add-Type -AssemblyName System.Net.Http
" <>
        "  $promptBytes = [System.IO.File]::ReadAllBytes($PromptFile)
" <>
        "  $promptText = $utf8.GetString($promptBytes)
" <>
        "  $payloadObj = @{
" <>
        "    model = $Model
" <>
        "    max_tokens = 16384
" <>
        "    messages = @(@{ role = 'user'; content = $promptText })
" <>
        "  }
" <>
        "  $payloadText = $payloadObj | ConvertTo-Json -Depth 10 -Compress
" <>
        "  $payloadBytes = $utf8.GetBytes($payloadText)
" <>
        "  $handler = New-Object System.Net.Http.HttpClientHandler
" <>
        "  $client = New-Object System.Net.Http.HttpClient($handler)
" <>
        "  $client.Timeout = [System.TimeSpan]::FromSeconds(300)
" <>
        "  $client.DefaultRequestHeaders.Add('x-api-key', $ApiKey)
" <>
        "  $client.DefaultRequestHeaders.Add('anthropic-version', '2023-06-01')
" <>
        "  $content = New-Object System.Net.Http.ByteArrayContent -ArgumentList (,$payloadBytes)
" <>
        "  $content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('application/json; charset=utf-8')
" <>
        "  $response = $client.PostAsync($Url, $content).GetAwaiter().GetResult()
" <>
        "  $respBytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
" <>
        "  $respText = $utf8.GetString($respBytes)
" <>
        "  if (-not $response.IsSuccessStatusCode) {
" <>
        "    [System.IO.File]::WriteAllText($ErrFile, $respText, $utf8)
" <>
        "    exit 1
" <>
        "  }
" <>
        "  $obj = $respText | ConvertFrom-Json
" <>
        "  $text = ''
" <>
        "  if ($null -ne $obj.content) {
" <>
        "    foreach ($item in $obj.content) {
" <>
        "      if ($null -ne $item -and $item.type -eq 'text') {
" <>
        "        $text = [string]$item.text
" <>
        "        break
" <>
        "      }
" <>
        "    }
" <>
        "  }
" <>
        "  try {
" <>
        "    $trimmed = $text.Trim()
" <>
        "    if ($trimmed.StartsWith('{') -or $trimmed.StartsWith('[')) {
" <>
        "      $innerObj = $trimmed | ConvertFrom-Json
" <>
        "      $text = $innerObj | ConvertTo-Json -Depth 20 -Compress
" <>
        "    }
" <>
        "  } catch {}
" <>
        "  [System.IO.File]::WriteAllText($OutFile, $text, $utf8)
" <>
        "  $content.Dispose()
" <>
        "  $client.Dispose()
" <>
        "  $handler.Dispose()
" <>
        "  exit 0
" <>
        "} catch {
" <>
        "  $msg = ($_ | Out-String)
" <>
        "  try { if ($null -ne $content) { $content.Dispose() } } catch {}
" <>
        "  try { if ($null -ne $client) { $client.Dispose() } } catch {}
" <>
        "  try { if ($null -ne $handler) { $handler.Dispose() } } catch {}
" <>
        "  [System.IO.File]::WriteAllText($ErrFile, $msg, $utf8)
" <>
        "  exit 1
" <>
        "}
";

      Export[ps1File, script, "Text", CharacterEncoding -> "UTF-8"],

      res = Quiet @ Check[
        RunProcess[{
          psExe,
          "-NoProfile",
          "-ExecutionPolicy", "Bypass",
          "-File", ps1File,
          promptFile,
          outFile,
          errFile,
          apiKey,
          url,
          model
        }],
        $Failed
      ];

      If[res === $Failed,
        Return["Error: PowerShell 実行に失敗しました。"]
      ];

      If[Lookup[res, "ExitCode", 1] =!= 0,
        errText = "";
        If[FileExistsQ[errFile],
          ba = iReadFileByteArray[errFile];
          If[Head[ba] === ByteArray,
            errText = iByteArrayToUTF8String[ba]
          ]
        ];
        If[!StringQ[errText] || StringTrim[errText] === "",
          errText = Lookup[res, "StandardError", ""]
        ];
        If[!StringQ[errText] || StringTrim[errText] === "",
          errText = Lookup[res, "StandardOutput", ""]
        ];
        Return[
          "Error: Anthropic fallback PowerShell 実行失敗" <>
          If[StringQ[errText] && StringTrim[errText] =!= "",
            "
" <> StringTake[errText, UpTo[800]],
            ""
          ]
        ]
      ];

      ba = iReadFileByteArray[outFile];
      If[Head[ba] =!= ByteArray,
        Return["Error: Anthropic fallback の応答ファイルを読み取れません。"]
      ];

      text = iByteArrayToUTF8String[ba];
      If[StringQ[text],
        text,
        "Error: Anthropic fallback 応答の UTF-8 復号に失敗しました。"
      ],

      If[StringQ[tmpDir] && DirectoryQ[tmpDir],
        Quiet @ DeleteDirectory[tmpDir, DeleteContents -> True]
      ]
    ]
  ];

(* OpenAI Chat Completions API \:7d4c\:7531\:3067\:30af\:30a8\:30ea *)

(* Anthropic API + web_search tool 付きクエリ *)
iQueryAnthropicAPIWithWebSearch[apiKey_String, model_String, prompt_String] :=
  Module[{url, psExe, tmpDir = None, promptFile, outFile, errFile, ps1File,
          script, res, ba, errText, text, strm},
    url = "https://api.anthropic.com/v1/messages";
    psExe = iResolvePowerShellExe[];
    If[!StringQ[psExe] || StringTrim[psExe] === "",
      Return["Error: PowerShell not available for web search."]];

    Internal`WithLocalSettings[
      tmpDir = iMakeTempDir[];
      promptFile = FileNameJoin[{tmpDir, "prompt.txt"}];
      outFile    = FileNameJoin[{tmpDir, "response.txt"}];
      errFile    = FileNameJoin[{tmpDir, "error.txt"}];
      ps1File    = FileNameJoin[{tmpDir, "websearch.ps1"}];

      strm = OpenWrite[promptFile, BinaryFormat -> True];
      BinaryWrite[strm, ToCharacterCode[iHoistThinkPrefix[prompt], "UTF-8"], "Byte"];
      Close[strm];

      script =
        "param([string]$PromptFile,[string]$OutFile,[string]$ErrFile,[string]$ApiKey,[string]$Url,[string]$Model)
" <>
        "$ErrorActionPreference = 'Stop'
" <>
        "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
" <>
        "$utf8 = New-Object System.Text.UTF8Encoding($false)
" <>
        "try {
" <>
        "  Add-Type -AssemblyName System.Net.Http
" <>
        "  $promptBytes = [System.IO.File]::ReadAllBytes($PromptFile)
" <>
        "  $promptText = $utf8.GetString($promptBytes)
" <>
        "  $payloadObj = @{
" <>
        "    model = $Model
" <>
        "    max_tokens = 16384
" <>
        "    tools = @(@{ type = 'web_search_20250305'; name = 'web_search'; max_uses = 5 })
" <>
        "    messages = @(@{ role = 'user'; content = $promptText })
" <>
        "  }
" <>
        "  $payloadText = $payloadObj | ConvertTo-Json -Depth 10 -Compress
" <>
        "  $payloadBytes = $utf8.GetBytes($payloadText)
" <>
        "  $handler = New-Object System.Net.Http.HttpClientHandler
" <>
        "  $client = New-Object System.Net.Http.HttpClient($handler)
" <>
        "  $client.Timeout = [System.TimeSpan]::FromSeconds(300)
" <>
        "  $client.DefaultRequestHeaders.Add('x-api-key', $ApiKey)
" <>
        "  $client.DefaultRequestHeaders.Add('anthropic-version', '2023-06-01')
" <>
        "  $content = New-Object System.Net.Http.ByteArrayContent -ArgumentList (,$payloadBytes)
" <>
        "  $content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('application/json; charset=utf-8')
" <>
        "  $response = $client.PostAsync($Url, $content).GetAwaiter().GetResult()
" <>
        "  $respBytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
" <>
        "  $respText = $utf8.GetString($respBytes)
" <>
        "  if (-not $response.IsSuccessStatusCode) {
" <>
        "    [System.IO.File]::WriteAllText($ErrFile, $respText, $utf8)
" <>
        "    exit 1
" <>
        "  }
" <>
        "  $obj = $respText | ConvertFrom-Json
" <>
        "  $allText = [System.Collections.Generic.List[string]]::new()
" <>
        "  if ($null -ne $obj.content) {
" <>
        "    foreach ($item in $obj.content) {
" <>
        "      if ($null -ne $item -and $item.type -eq 'text') {
" <>
        "        $allText.Add([string]$item.text)
" <>
        "      }
" <>
        "    }
" <>
        "  }
" <>
        "  $text = $allText -join \"`n\"
" <>
        "  [System.IO.File]::WriteAllText($OutFile, $text, $utf8)
" <>
        "  $content.Dispose()
" <>
        "  $client.Dispose()
" <>
        "  $handler.Dispose()
" <>
        "  exit 0
" <>
        "} catch {
" <>
        "  $msg = ($_ | Out-String)
" <>
        "  try { if ($null -ne $content) { $content.Dispose() } } catch {}
" <>
        "  try { if ($null -ne $client) { $client.Dispose() } } catch {}
" <>
        "  try { if ($null -ne $handler) { $handler.Dispose() } } catch {}
" <>
        "  [System.IO.File]::WriteAllText($ErrFile, $msg, $utf8)
" <>
        "  exit 1
" <>
        "}
";
      Export[ps1File, script, "Text", CharacterEncoding -> "UTF-8"],

      res = Quiet @ Check[
        RunProcess[{psExe, "-NoProfile", "-ExecutionPolicy", "Bypass",
          "-File", ps1File, promptFile, outFile, errFile, apiKey, url, model}],
        $Failed];
      If[res === $Failed, Return["Error: WebSearch PowerShell failed."]];
      If[Lookup[res, "ExitCode", 1] =!= 0,
        errText = "";
        If[FileExistsQ[errFile],
          ba = iReadFileByteArray[errFile];
          If[Head[ba] === ByteArray, errText = iByteArrayToUTF8String[ba]]];
        If[!StringQ[errText] || StringTrim[errText] === "",
          errText = Lookup[res, "StandardError", ""]];
        Return["Error: WebSearch API failed" <>
          If[StringQ[errText] && StringTrim[errText] =!= "",
            "\n" <> StringTake[errText, UpTo[500]], ""]]];
      ba = iReadFileByteArray[outFile];
      If[Head[ba] =!= ByteArray,
        Return["Error: WebSearch response file unreadable."]];
      text = iByteArrayToUTF8String[ba];
      If[StringQ[text], text, "Error: WebSearch UTF-8 decode failed."],

      If[StringQ[tmpDir] && DirectoryQ[tmpDir],
        Quiet @ DeleteDirectory[tmpDir, DeleteContents -> True]]
    ]
  ];

(* Web 検索の内部共通関数 *)
iDoWebSearch[prompt_String] :=
  Module[{apiKey, model = "claude-sonnet-4-20250514"},
    apiKey = Quiet[NBAccess`NBGetAPIKey["anthropic",
      PrivacySpec -> <|"AccessLevel" -> 1.0|>]];
    If[!StringQ[apiKey],
      Return["Error: Anthropic API \:30ad\:30fc\:304c\:53d6\:5f97\:3067\:304d\:307e\:305b\:3093\:3002"]];
    iQueryAnthropicAPIWithWebSearch[apiKey, model, prompt]
  ];

(* 公開関数: Web 検索 *)
ClaudeWebSearch[query_String] :=
  iDoWebSearch["Web\:3067\:4ee5\:4e0b\:306e\:30af\:30a8\:30ea\:3092\:691c\:7d22\:3057\:3001\:7d50\:679c\:3092\:65e5\:672c\:8a9e\:3067\:307e\:3068\:3081\:3066\:304f\:3060\:3055\:3044\:3002\n\n" <> query];

(* 公開関数: Web ページ取得 *)
ClaudeWebFetch[url_String] :=
  ClaudeWebFetch[url, "\:3053\:306e\:30da\:30fc\:30b8\:306e\:4e3b\:8981\:306a\:5185\:5bb9\:3092\:65e5\:672c\:8a9e\:3067\:8981\:7d04\:3057\:3066\:304f\:3060\:3055\:3044\:3002"];

ClaudeWebFetch[url_String, instruction_String] :=
  Module[{htmlText, prompt},
    htmlText = Quiet @ Check[
      URLRead[HTTPRequest[url], "Body"],
      $Failed];
    If[!StringQ[htmlText],
      Return["Error: URL \:306e\:53d6\:5f97\:306b\:5931\:6557\:3057\:307e\:3057\:305f: " <> url]];
    (* HTML が大きすぎる場合は切り詰め *)
    If[StringLength[htmlText] > 50000,
      htmlText = StringTake[htmlText, 50000] <> "\n...(truncated)"];
    prompt = instruction <> "\n\nURL: " <> url <>
      "\n\n=== Page Content ===\n" <> htmlText;
    iDoWebSearch[prompt]
  ];

iQueryOpenAIAPI[apiKey_String, model_String, prompt_String,
    customURL_String:"https://api.openai.com/v1/chat/completions"] :=
  Module[{url, body, resp, bodyStr, json, choices, msg},
    url = customURL;
    body = "{\"model\":\"" <> model <>
      "\",\"messages\":[{\"role\":\"user\",\"content\":" <>
      ExportString[prompt, "RawJSON"] <> "}]}";
    resp = Quiet[URLRead[
      HTTPRequest[url, <|
        "Method"  -> "POST",
        "Headers" -> {
          "Authorization" -> "Bearer " <> apiKey,
          "Content-Type"  -> "application/json"},
        "Body" -> body|>]]];
    If[!MatchQ[resp, _HTTPResponse],
      Return["Error: OpenAI API \:63a5\:7d9a\:5931\:6557"]];
    bodyStr = iHTTPResponseBodyUTF8[resp];
    If[!StringQ[bodyStr],
      bodyStr = resp["Body"];
      If[!StringQ[bodyStr], bodyStr = ToString[bodyStr]]];
    If[resp["StatusCode"] =!= 200,
      Return["Error: OpenAI API StatusCode=" <>
        ToString[resp["StatusCode"]] <> " " <>
        StringTake[bodyStr, UpTo[300]]]];
    json = Quiet[Developer`ReadRawJSONString[bodyStr]];
    If[!AssociationQ[json],
      json = Quiet[ImportString[bodyStr, "RawJSON"]]];
    If[!AssociationQ[json],
      Return["Error: OpenAI API \:5fdc\:7b54\:30d1\:30fc\:30b9\:5931\:6557: " <>
        StringTake[bodyStr, UpTo[200]]]];
    choices = json["choices"];
    If[ListQ[choices] && Length[choices] > 0,
      msg = First[choices]["message"];
      If[AssociationQ[msg], msg["content"], ""],
      ""]
  ];

(* \:30d7\:30ed\:30d0\:30a4\:30c0\:306b\:5fdc\:3058\:305f API \:547c\:3073\:51fa\:3057\:30c7\:30a3\:30b9\:30d1\:30c3\:30c1 *)
(* provider に応じた API 呼び出しディスパッチ。
   customURL が指定されている場合はそれを使用する（LM Studio 等のローカルモデル）。 *)
iEnsureChatCompletionsPath[url_String] :=
  If[StringEndsQ[url, "/v1/chat/completions"],
    url,
    If[StringEndsQ[url, "/"],
      url <> "v1/chat/completions",
      url <> "/v1/chat/completions"]];

iQueryViaAPI[provider_String, model_String, prompt_String, customURL_String:""] :=
  Module[{apiKey, url, prov = ToLowerCase[provider]},
    (* LM Studio 等ローカルモデル: API キー不要 *)
    If[prov === "lmstudio",
      url = iEnsureChatCompletionsPath[
        If[customURL =!= "", customURL, "http://localhost:1234"]];
      Return[iQueryOpenAIAPI["lm-studio", model, prompt, url]]];
    (* 通常プロバイダー *)
    apiKey = Quiet[NBAccess`NBGetAPIKey[provider,
      PrivacySpec -> <|"AccessLevel" -> 1.0|>]];
    If[apiKey === $Failed || !StringQ[apiKey],
      Return["Error: " <> provider <> " \:306e API \:30ad\:30fc\:304c\:53d6\:5f97\:3067\:304d\:307e\:305b\:3093"]];
    Switch[prov,
      "anthropic",
        iQueryAnthropicAPI[apiKey, model, prompt],
      "openai",
        If[customURL =!= "",
          iQueryOpenAIAPI[apiKey, model, prompt, customURL],
          iQueryOpenAIAPI[apiKey, model, prompt]],
      _,
        "Error: \:672a\:5bfe\:5fdc\:30d7\:30ed\:30d0\:30a4\:30c0: " <> provider]
  ];

(* フォールバック通知: nb===None なら CellPrint (In/Out 間), NotebookObject なら NotebookWrite *)
iFallbackNotify[None, text_String, color_] :=
  NBAccess`NBWritePrintNotice[None, text, color];
iFallbackNotify[nb_NotebookObject, text_String, color_] :=
  NBAccess`NBWritePrintNotice[nb, text, color];

(* Claude Code → フォールバック付きラッパー
   nb=None: 同期用 (CellPrint で In/Out 間に通知)
   nb=NotebookObject: 非同期用 (NotebookWrite で通知) *)
iQueryWithFallback[prompt_String, useFallback_, nb_:None] :=
  Module[{response, models, provider, model, customURL, fbResponse, result},
    response = iClaudeQueryRaw[prompt];
    If[!TrueQ[useFallback] || !iIsLimitError[response],
      Return[response]];
    models = NBAccess`NBGetAvailableFallbackModels[
      iResolveAccessLevel[Automatic]];
    result = Catch[
      Do[
        provider  = fm[[1]];
        model     = fm[[2]];
        customURL = If[Length[fm] >= 3, fm[[3]], ""];
        iFallbackNotify[nb,
          "\[RightArrow] Claude Code \:5229\:7528\:4e0d\:53ef\:3002" <> provider <> "/" <> model <>
          " \:306b\:5207\:66ff\:3048\:307e\:3059\:2026",
          RGBColor[0.8, 0.4, 0]];
        fbResponse = iQueryViaAPI[provider, model, prompt, customURL];
        If[StringQ[fbResponse] && !StringStartsQ[fbResponse, "Error:"],
          iFallbackNotify[nb,
            "\[Checkmark] " <> provider <> "/" <> model <> " \:3067\:5fdc\:7b54\:3092\:53d6\:5f97\:3057\:307e\:3057\:305f\:3002",
            RGBColor[0, 0.5, 0.2]];
          Throw[fbResponse, "fallback"]],
      {fm, models}];
      iFallbackNotify[nb,
        "\[WarningSign] \:5168\:30e2\:30c7\:30eb\:304c\:5229\:7528\:4e0d\:53ef\:3067\:3059\:3002", Red];
      response,
    "fallback"];
    result
  ];

(* 非同期パス用: Claude Code をスキップして API フォールバックのみ実行
   メッセージは $iFallbackLog に蓄積し、呼び出し側がアンカー位置で書き出す *)
$iFallbackLog = {};

iQueryFallbackOnly[prompt_String, nb_NotebookObject] :=
  Module[{models, provider, model, customURL, fbResponse, result},
    $iFallbackLog = {};
    models = NBAccess`NBGetAvailableFallbackModels[
      iResolveAccessLevel[Automatic]];
    result = Catch[
      Do[
        provider  = fm[[1]];
        model     = fm[[2]];
        customURL = If[Length[fm] >= 3, fm[[3]], ""];
        AppendTo[$iFallbackLog,
          {"\[RightArrow] Claude Code \:5229\:7528\:4e0d\:53ef\:3002" <> provider <> "/" <> model <>
           " \:306b\:5207\:66ff\:3048\:307e\:3059\:2026", RGBColor[0.8, 0.4, 0]}];
        fbResponse = iQueryViaAPI[provider, model, prompt, customURL];
        If[StringQ[fbResponse] && !StringStartsQ[fbResponse, "Error:"],
          AppendTo[$iFallbackLog,
            {"\[Checkmark] " <> provider <> "/" <> model <> " \:3067\:5fdc\:7b54\:3092\:53d6\:5f97\:3057\:307e\:3057\:305f\:3002",
             RGBColor[0, 0.5, 0.2]}];
          Throw[fbResponse, "fallback"]],
      {fm, models}];
      AppendTo[$iFallbackLog,
        {"\[WarningSign] \:5168\:30e2\:30c7\:30eb\:304c\:5229\:7528\:4e0d\:53ef\:3067\:3059\:3002", Red}];
      $Failed,
    "fallback"];
    result
  ];

(* 蓄積されたフォールバックメッセージをノートブックに書き出す *)
iFlushFallbackLog[nb_NotebookObject] :=
  (* \:30e1\:30c3\:30bb\:30fc\:30b8\:306f iFallbackNotifyAndLog \:3067\:5373\:5ea7\:306b\:66f8\:304d\:51fa\:3057\:6e08\:307f\:3002\:30ed\:30b0\:3092\:30af\:30ea\:30a2\:306e\:307f *)
  ($iFallbackLog = {});

(* 非同期フォールバック: StartProcess + ScheduledTask で API 呼び出し
   カーネルをブロックせずにフォールバックモデルを順次試行する *)
iPrepareAnthropicPS1[apiKey_String, model_String, prompt_String,
    url_String:"https://api.anthropic.com/v1/messages",
    provider_String:"anthropic"] :=
  Module[{psExe, tmpDir, promptFile, outFile, errFile, ps1File, script, strm,
          isAnthropic = ToLowerCase[provider] === "anthropic"},
    psExe = iResolvePowerShellExe[];
    If[!StringQ[psExe], Return[$Failed]];
    tmpDir = iMakeTempDir[];
    promptFile = FileNameJoin[{tmpDir, "prompt.txt"}];
    outFile    = FileNameJoin[{tmpDir, "response.txt"}];
    errFile    = FileNameJoin[{tmpDir, "error.txt"}];
    ps1File    = FileNameJoin[{tmpDir, "fb_api.ps1"}];
    strm = OpenWrite[promptFile, BinaryFormat -> True];
    BinaryWrite[strm, ToCharacterCode[iHoistThinkPrefix[prompt], "UTF-8"], "Byte"];
    Close[strm];
    script =
      "param([string]$PromptFile,[string]$OutFile,[string]$ErrFile,[string]$ApiKey,[string]$Url,[string]$Model)
" <>
      "$ErrorActionPreference = 'Stop'
" <>
      "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
" <>
      "$utf8 = New-Object System.Text.UTF8Encoding($false)
" <>
      "try {
" <>
      "  Add-Type -AssemblyName System.Net.Http
" <>
      "  $promptBytes = [System.IO.File]::ReadAllBytes($PromptFile)
" <>
      "  $promptText = $utf8.GetString($promptBytes)
" <>
      If[isAnthropic,
        "  $payloadObj = @{ model = $Model; max_tokens = 16384; messages = @(@{ role = 'user'; content = $promptText }) }
",
        "  $payloadObj = @{ model = $Model; messages = @(@{ role = 'user'; content = $promptText }) }
"
      ] <>
      "  $payloadText = $payloadObj | ConvertTo-Json -Depth 10 -Compress
" <>
      "  $payloadBytes = $utf8.GetBytes($payloadText)
" <>
      "  $handler = New-Object System.Net.Http.HttpClientHandler
" <>
      "  $client = New-Object System.Net.Http.HttpClient($handler)
" <>
      "  $client.Timeout = [System.TimeSpan]::FromSeconds(300)
" <>
      If[isAnthropic,
        "  $client.DefaultRequestHeaders.Add('x-api-key', $ApiKey)
" <>
        "  $client.DefaultRequestHeaders.Add('anthropic-version', '2023-06-01')
",
        "  $client.DefaultRequestHeaders.Add('Authorization', 'Bearer ' + $ApiKey)
"
      ] <>
      "  $content = New-Object System.Net.Http.ByteArrayContent -ArgumentList (,$payloadBytes)
" <>
      "  $content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('application/json; charset=utf-8')
" <>
      "  $response = $client.PostAsync($Url, $content).GetAwaiter().GetResult()
" <>
      "  $respBytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
" <>
      "  $respText = $utf8.GetString($respBytes)
" <>
      "  if (-not $response.IsSuccessStatusCode) { [System.IO.File]::WriteAllText($ErrFile, $respText, $utf8); exit 1 }
" <>
      "  $obj = $respText | ConvertFrom-Json
" <>
      "  $text = ''
" <>
      If[isAnthropic,
        "  if ($null -ne $obj.content) { foreach ($item in $obj.content) { if ($null -ne $item -and $item.type -eq 'text') { $text = [string]$item.text; break } } }
",
        "  if ($null -ne $obj.choices -and $obj.choices.Count -gt 0) { $text = [string]$obj.choices[0].message.content }
"
      ] <>
      "  [System.IO.File]::WriteAllText($OutFile, $text, $utf8)
" <>
      "  $content.Dispose(); $client.Dispose(); $handler.Dispose(); exit 0
" <>
      "} catch {
" <>
      "  $msg = ($_ | Out-String)
" <>
      "  try { if ($null -ne $content) { $content.Dispose() } } catch {}
" <>
      "  try { if ($null -ne $client) { $client.Dispose() } } catch {}
" <>
      "  try { if ($null -ne $handler) { $handler.Dispose() } } catch {}
" <>
      "  [System.IO.File]::WriteAllText($ErrFile, $msg, $utf8); exit 1
" <>
      "}
";
    Export[ps1File, script, "Text", CharacterEncoding -> "UTF-8"];
    <|"psExe" -> psExe, "tmpDir" -> tmpDir, "ps1File" -> ps1File,
      "promptFile" -> promptFile, "outFile" -> outFile, "errFile" -> errFile,
      "apiKey" -> apiKey, "url" -> url, "model" -> model|>
  ];

iReadAnthropicResult[outFile_String, errFile_String] :=
  Module[{ba, text},
    If[FileExistsQ[outFile],
      ba = iReadFileByteArray[outFile];
      If[Head[ba] === ByteArray,
        text = iByteArrayToUTF8String[ba];
        If[StringQ[text], Return[text]]]];
    If[FileExistsQ[errFile],
      ba = iReadFileByteArray[errFile];
      If[Head[ba] === ByteArray,
        text = iByteArrayToUTF8String[ba];
        If[StringQ[text], Return["Error: " <> StringTake[text, UpTo[500]]]]]];
    "Error: API response unreadable."
  ];

(* 非同期フォールバック: モデルリストを順次試行 (カーネル非ブロック)
   modelIdx から開始し、成功したら callback を呼ぶ
   全モデル失敗時は callback[$Failed] を呼ぶ (呼び出し側が処理) *)
$iFallbackDone = False;
$iFallbackActiveTasks = {};
$iFallbackTimeout = 90; (* \:79d2 *)
$iFallbackProgress = <||>;

(* \:524d\:56de\:306e\:30d5\:30a9\:30fc\:30eb\:30d0\:30c3\:30af\:30c1\:30a7\:30fc\:30f3\:3092\:5168\:3066\:505c\:6b62 *)
iCancelActiveFallbacks[] := (
  Do[
    Quiet[StopScheduledTask[t]];
    Quiet[RemoveScheduledTask[t]],
    {t, $iFallbackActiveTasks}];
  $iFallbackActiveTasks = {};
  $iFallbackProgress = <||>);

(* \:30d5\:30a9\:30fc\:30eb\:30d0\:30c3\:30af\:901a\:77e5\:3092\:5373\:5ea7\:306b\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:306b\:66f8\:304d\:51fa\:3057\:3001\:30ed\:30b0\:306b\:3082\:84c4\:7a4d *)
iFallbackNotifyAndLog[nb_NotebookObject, text_String, color_] := (
  AppendTo[$iFallbackLog, {text, color}];
  NBAccess`NBWritePrintNotice[nb, text, color]);

(* \:30d5\:30a9\:30fc\:30eb\:30d0\:30c3\:30af\:7528\:30d7\:30ed\:30b0\:30ec\:30b9\:30bb\:30eb\:3092\:633f\:5165 *)
iFallbackInsertProgress[nb_NotebookObject, key_String, provider_String, model_String] := (
  $iFallbackProgress[key] = <|"disp" ->
    "Fallback: " <> provider <> "/" <> model <> " \:306b\:554f\:3044\:5408\:308f\:305b\:4e2d... 0s"|>;
  With[{tag = "claude-fb-prog-" <> key},
    NotebookWrite[nb,
      Cell["Fallback: " <> provider <> "/" <> model <> " \:306b\:554f\:3044\:5408\:308f\:305b\:4e2d... 0s",
        "Print", CellTags -> {tag},
        FontWeight -> Bold, FontColor -> RGBColor[0.8, 0.4, 0], FontSize -> 11], After]]);

(* \:30d5\:30a9\:30fc\:30eb\:30d0\:30c3\:30af\:7528\:30d7\:30ed\:30b0\:30ec\:30b9\:30bb\:30eb\:3092\:524a\:9664 *)
iFallbackDeleteProgress[nb_NotebookObject, key_String] := (
  $iFallbackProgress = KeyDrop[$iFallbackProgress, key];
  NBAccess`NBDeleteCellsByTag[nb, "claude-fb-prog-" <> key]);

iStartFallbackAsync[prompt_String, nb_NotebookObject, callback_, models_List,
    modelIdx_Integer:1, jobId_String:""] :=
  Module[{provider, model, customURL, apiKey, prepared, proc, ts, startTime, progKey, useJob},
    useJob = (jobId =!= "");
    (* \:6700\:521d\:306e\:547c\:3073\:51fa\:3057\:6642\:306b\:30b0\:30ed\:30fc\:30d0\:30eb\:72b6\:614b\:3092\:521d\:671f\:5316 *)
    If[modelIdx === 1,
      $iFallbackLog = {};
      $iFallbackDone = False;
      iCancelActiveFallbacks[]];
    (* \:65e2\:306b\:5b8c\:4e86\:6e08\:307f\:306a\:3089\:4f55\:3082\:3057\:306a\:3044 *)
    If[TrueQ[$iFallbackDone], Return[]];
    If[modelIdx > Length[models],
      If[useJob,
        NBAccess`NBWriteSlot[jobId, 1,
          Cell["\[WarningSign] \:5168\:30e2\:30c7\:30eb\:304c\:5229\:7528\:4e0d\:53ef\:3067\:3059\:3002", "Print",
            FontWeight -> Bold, FontColor -> Red, FontSize -> 11]],
        iFallbackNotifyAndLog[nb,
          "\[WarningSign] \:5168\:30e2\:30c7\:30eb\:304c\:5229\:7528\:4e0d\:53ef\:3067\:3059\:3002", Red]];
      If[!TrueQ[$iFallbackDone], $iFallbackDone = True; callback[$Failed]];
      Return[]];
    (* モデル指定を展開: {provider, model} または {provider, model, url} *)
    Module[{entry = models[[modelIdx]]},
      provider = entry[[1]];
      model    = entry[[2]];
      customURL = If[Length[entry] >= 3, entry[[3]], ""]];
    (* API キー取得: lmstudio はキー不要 *)
    If[ToLowerCase[provider] === "lmstudio",
      apiKey = "lm-studio",
      apiKey = Quiet[NBAccess`NBGetAPIKey[provider,
        PrivacySpec -> <|"AccessLevel" -> 1.0|>]];
      If[!StringQ[apiKey],
        iStartFallbackAsync[prompt, nb, callback, models, modelIdx + 1, jobId];
        Return[]]];
    (* 切替え通知: Job ならスロット1、従来なら NotifyAndLog *)
    Module[{noticeText = "\[RightArrow] " <> provider <> "/" <> model <> " \:306b\:554f\:3044\:5408\:308f\:305b\:4e2d\:2026"},
    If[useJob,
      NBAccess`NBWriteSlot[jobId, 1,
        Cell[noticeText, "Print",
          FontWeight -> Bold, FontColor -> RGBColor[0.8, 0.4, 0], FontSize -> 11]],
      iFallbackNotifyAndLog[nb, noticeText, RGBColor[0.8, 0.4, 0]]]];
    prepared = iPrepareAnthropicPS1[apiKey, model, prompt,
      Which[
        ToLowerCase[provider] === "anthropic" && customURL === "",
          "https://api.anthropic.com/v1/messages",
        ToLowerCase[provider] === "lmstudio",
          iEnsureChatCompletionsPath[If[customURL =!= "", customURL, "http://localhost:1234"]],
        customURL =!= "", customURL,
        True, "https://api.openai.com/v1/chat/completions"],
      If[ToLowerCase[provider] === "lmstudio", "openai", provider]];
    If[prepared === $Failed,
      iStartFallbackAsync[prompt, nb, callback, models, modelIdx + 1, jobId];
      Return[]];
    proc = StartProcess[{
      prepared["psExe"], "-NoProfile", "-ExecutionPolicy", "Bypass",
      "-File", prepared["ps1File"],
      prepared["promptFile"], prepared["outFile"], prepared["errFile"],
      prepared["apiKey"], prepared["url"], prepared["model"]}];
    startTime = AbsoluteTime[];
    ts = ToString[UnixTime[]] <> "fb" <> ToString[RandomInteger[99999]];
    progKey = ts;
    (* \:30d7\:30ed\:30b0\:30ec\:30b9\:8868\:793a: Job \:306a\:3089\:30b9\:30ed\:30c3\:30c81\:3092\:66f4\:65b0\:3001\:5f93\:6765\:306a\:3089\:5225\:30bb\:30eb *)
    If[useJob,
      $iFallbackProgress[progKey] = <|"disp" ->
        "Fallback: " <> provider <> "/" <> model <> " \:306b\:554f\:3044\:5408\:308f\:305b\:4e2d... 0s"|>;
      NBAccess`NBWriteSlot[jobId, 1,
        Cell["Fallback: " <> provider <> "/" <> model <> " \:306b\:554f\:3044\:5408\:308f\:305b\:4e2d... 0s",
          "Print", FontWeight -> Bold, FontColor -> RGBColor[0.8, 0.4, 0], FontSize -> 11]],
      iFallbackInsertProgress[nb, progKey, provider, model]];
    With[{gSym = Symbol["ClaudeCode`Private`$fbTask" <> ts]},
    gSym = CreateScheduledTask[
      With[{p = proc, oFile = prepared["outFile"], eFile = prepared["errFile"],
            td = prepared["tmpDir"], cb = callback, pmt = prompt, pNb = nb,
            mods = models, mIdx = modelIdx, sym = gSym, t0 = startTime,
            pk = progKey, prov = provider, mdl = model,
            jid = jobId, uj = useJob},
        Module[{status, text, elapsed},
          (* \:65e2\:306b\:4ed6\:306e\:30e2\:30c7\:30eb\:3067\:6210\:529f\:6e08\:307f\:306a\:3089\:505c\:6b62 *)
          If[TrueQ[$iFallbackDone],
            Quiet[StopScheduledTask[sym]];
            Quiet[RemoveScheduledTask[sym]];
            $iFallbackActiveTasks = DeleteCases[$iFallbackActiveTasks, sym];
            If[!uj, iFallbackDeleteProgress[pNb, pk]];
            Return[]];
          elapsed = Round[AbsoluteTime[] - t0, 1];
          (* \:30d7\:30ed\:30b0\:30ec\:30b9\:66f4\:65b0 *)
          If[KeyExistsQ[$iFallbackProgress, pk],
            $iFallbackProgress[pk] = <|"disp" ->
              "Fallback: " <> prov <> "/" <> mdl <>
              " \:306b\:554f\:3044\:5408\:308f\:305b\:4e2d... " <> ToString[elapsed] <> "s"|>;
            (* 進捗テキストをスロットに直接書き込み *)
            Quiet @ If[uj,
              NBAccess`NBWriteSlot[jid, 1,
                Cell[$iFallbackProgress[pk]["disp"],
                  "Print", FontWeight -> Bold, FontColor -> RGBColor[0.8, 0.4, 0], FontSize -> 11]]]];
          status = ProcessStatus[p];
          If[status === "Finished" || elapsed > $iFallbackTimeout,
            Quiet[StopScheduledTask[sym]];
            Quiet[RemoveScheduledTask[sym]];
            $iFallbackActiveTasks = DeleteCases[$iFallbackActiveTasks, sym];
            If[!uj,
              iFallbackDeleteProgress[pNb, pk],
              (* Job パス: 進捗テキストを更新し written=False で NBEndJob に任せる *)
              $iFallbackProgress = KeyDrop[$iFallbackProgress, pk];
              Quiet @ NBAccess`NBWriteSlot[jid, 1,
                Cell["\:2713 Fallback: " <> prov <> "/" <> mdl <> " \:304b\:3089\:306e\:5fdc\:7b54\:3092\:53d6\:5f97\:3002\:51fa\:529b\:3092\:66f8\:304d\:8fbc\:307f\:4e2d...",
                  "Print", FontWeight -> Bold, FontColor -> RGBColor[0.3, 0.6, 0.3], FontSize -> 11]];
              $NBJobTable[jid, "written"] =
                ReplacePart[$NBJobTable[jid]["written"], 1 -> False]];
            If[status =!= "Finished",
              Quiet[KillProcess[p]];
              Quiet @ DeleteDirectory[td, DeleteContents -> True];
              iStartFallbackAsync[pmt, pNb, cb, mods, mIdx + 1, jid],
              text = iReadAnthropicResult[oFile, eFile];
              Quiet @ DeleteDirectory[td, DeleteContents -> True];
              If[StringQ[text] && !StringStartsQ[text, "Error:"],
                If[!TrueQ[$iFallbackDone],
                  $iFallbackDone = True;
                  (* \:5b8c\:4e86\:901a\:77e5: Job \:306a\:3089\:30b9\:30ed\:30c3\:30c82\:3001\:5f93\:6765\:306a\:3089 NotifyAndLog *)
                  If[uj,
                    NBAccess`NBWriteSlot[jid, 2,
                      Cell["\[Checkmark] " <> mods[[mIdx, 1]] <> "/" <> mods[[mIdx, 2]] <>
                        " \:3067\:5fdc\:7b54\:3092\:53d6\:5f97\:3057\:307e\:3057\:305f\:3002", "Print",
                        FontWeight -> Bold, FontColor -> RGBColor[0, 0.5, 0.2], FontSize -> 11]],
                    iFallbackNotifyAndLog[pNb,
                      "\[Checkmark] " <> mods[[mIdx, 1]] <> "/" <> mods[[mIdx, 2]] <>
                      " \:3067\:5fdc\:7b54\:3092\:53d6\:5f97\:3057\:307e\:3057\:305f\:3002", RGBColor[0, 0.5, 0.2]]];
                  cb[text]],
                iStartFallbackAsync[pmt, pNb, cb, mods, mIdx + 1, jid]
              ]
            ]
          ]
        ]
      ],
      1
    ];
    AppendTo[$iFallbackActiveTasks, gSym];
    StartScheduledTask[gSym];
    ]
  ];

(* \:30c7\:30d0\:30c3\:30b0\:7528: ClaudeQuery \:304c\:9001\:4fe1\:3059\:308b\:30b3\:30f3\:30c6\:30ad\:30b9\:30c8\:3092\:8868\:793a *)
ClaudeQueryShowContext[] :=
  Module[{nb, session, tag, history, lastEntry, cellCountAfter, ctx},
    nb      = Quiet[EvaluationNotebook[]];
    session = iEnsureDefaultSession[nb];
    tag     = session["SessionTag"];
    history = iSessionHistory[nb, tag];
    lastEntry      = If[Length[history] > 0, Last[history], <||>];
    cellCountAfter = Replace[Lookup[lastEntry, "cellCountAfter",
                       Lookup[lastEntry, "cellCount", 0]], Except[_Integer] -> 0];
    ctx = With[{r = Quiet[iCaptureNotebookContext[nb, cellCountAfter]]},
            If[StringQ[r], r, ""]];
    Print["=== cellCountAfter: ", cellCountAfter,
          " / \:7dcf\:30bb\:30eb\:6570: ", NBAccess`NBCellCount[nb], " ==="];
    If[ctx === "",
      Print["NBGetContext \:306e\:7d50\:679c: \:ff08\:7a7a\:6587\:5b57\:5217\:ff09"],
      Print["NBGetContext \:306e\:7d50\:679c:\n", ctx]]
  ];

(* デバッグ用: アクセス設定の確認 *)
ClaudeShowAccessConfig[] := Module[
  {dirs, nbDirs, tempDir, settingsPath, settingsContent},
  dirs = If[ListQ[$ClaudeAccessibleDirs], $ClaudeAccessibleDirs, {}];
  nbDirs = Quiet @ NBAccess`NBGetAccessibleDirs[EvaluationNotebook[]];
  Print[Style["=== Claude Code Access Config ===", Bold, 14]];
  Print[Style["$ClaudeAccessibleDirs:", Bold], " ", dirs];
  Print[Style["NBGetAccessibleDirs[]:", Bold], " ", If[ListQ[nbDirs], nbDirs, {}]];
  Print[Style["iCollectAccessibleDirs[]:", Bold], " ", iCollectAccessibleDirs[]];
  Print[""];

  Print[Style["--- Read Permission Entries ---", Bold]];
  Do[Print["  ", iMakeReadPermission[d]], {d, iCollectAccessibleDirs[]}];
  Print[""];

  Print[Style["--- CLI Flags ---", Bold]];
  Print["  permFlags: ", iCLIPermissionFlags[]];
  Print["  addDirFlags: ",
    StringJoin[Map[Function[d, " --add-dir \"" <> d <> "\""],
      iCollectAccessibleDirs[]]]];
  Print[""];

  Print[Style["--- Test: settings.json generation ---", Bold]];
  tempDir = iPrepareClaudeProjectDirectory[];
  settingsPath = FileNameJoin[{tempDir, ".claude", "settings.json"}];
  If[FileExistsQ[settingsPath],
    settingsContent = Import[settingsPath, "Text"];
    Print["  Path: ", settingsPath];
    Print["  Content:\n", settingsContent],
    Print["  settings.json not generated"]
  ];
  Print["\n  tempDir: ", tempDir];
];

(* セッション状態の確認 *)
ClaudeSessionStatus[] := iClaudeSessionStatusImpl[EvaluationNotebook[], iSessionTag[], "default"];

ClaudeSessionStatus[name_String] :=
  iClaudeSessionStatusImpl[EvaluationNotebook[], iNamedSessionTag[name], name];

ClaudeSessionStatus[session_Association] :=
  iClaudeSessionStatusImpl[session["Notebook"], session["SessionTag"], session["Name"]];

(* ============================================================
   ClaudeStatus: 実行中タスクのリアルタイム状態表示
   ============================================================ *)

ClaudeStatus[] :=
  Module[{keys, nb},
    nb = Quiet[EvaluationNotebook[]];
    keys = If[AssociationQ[$claudeProgress], Keys[$claudeProgress], {}];
    If[Length[keys] === 0,
      Print[Style["\:2705 \:5b9f\:884c\:4e2d\:306e Claude \:30bf\:30b9\:30af\:306f\:3042\:308a\:307e\:305b\:3093\:3002", Bold]];
      Return[{}]];
    Print[Style["=== Claude \:30bf\:30b9\:30af\:72b6\:614b (" <> ToString[Length[keys]] <> " \:4ef6\:5b9f\:884c\:4e2d) ===",
      Bold, 14]];
    Print[""];
    Map[Function[key,
      Module[{info = $claudeProgress[key], elapsed, status, proc,
              textF, thinkF, toolU, fileSize, lastTxt},
        If[!AssociationQ[info], Return[Nothing]];
        elapsed  = Round[AbsoluteTime[] - Lookup[info, "startTime", AbsoluteTime[]], 1];
        status   = Lookup[info, "status", "?"];
        proc     = Lookup[info, "process", None];
        textF    = Lookup[info, "textFragments", 0];
        thinkF   = Lookup[info, "thinkingFragments", 0];
        toolU    = Lookup[info, "toolUses", 0];
        lastTxt  = Lookup[info, "lastText", ""];
        fileSize = If[StringQ[Lookup[info, "outFile", None]] &&
                      FileExistsQ[info["outFile"]],
                    FileByteCount[info["outFile"]], 0];

        Print[Style["\:25b6 \:30bf\:30b9\:30af: " <> key, Bold, 12]];
        Print["  \:7d4c\:904e\:6642\:9593: ", elapsed, " \:79d2"];
        Print["  \:30d7\:30ed\:30bb\:30b9: ",
          If[proc =!= None, ToString[ProcessStatus[proc]], "?"]];
        Print["  \:73fe\:5728\:306e\:72b6\:614b: ",
          Style[status, Bold,
            Switch[status,
              "\:601d\:8003\:4e2d", RGBColor[0.8, 0.5, 0],
              "\:30c6\:30ad\:30b9\:30c8\:751f\:6210\:4e2d", RGBColor[0, 0.6, 0],
              "\:5b8c\:4e86", RGBColor[0, 0.5, 0],
              _, RGBColor[0.4, 0.4, 0.4]]]];
        Print["  \:601d\:8003\:65ad\:7247: ", thinkF, " | \:30c6\:30ad\:30b9\:30c8\:65ad\:7247: ", textF,
          " | \:30c4\:30fc\:30eb\:4f7f\:7528: ", toolU];
        Print["  \:51fa\:529b\:30d5\:30a1\:30a4\:30eb: ", Round[fileSize / 1024., 1], " KB (",
          Lookup[info, "lineCount", 0], " \:884c)"];
        If[lastTxt =!= "" && textF > 0,
          Print["  \:6700\:65b0\:30c6\:30ad\:30b9\:30c8: \:300c",
            StringTake[lastTxt, UpTo[60]], "\:300d"]];
        Print["  \:547c\:3073\:51fa\:3057\:5143: ", Lookup[info, "caller", "?"]];
        Print[""];
        <|"key" -> key, "elapsed" -> elapsed, "status" -> status,
          "textFragments" -> textF, "thinkingFragments" -> thinkF,
          "toolUses" -> toolU, "fileSize" -> fileSize|>
      ]],
      keys]
  ];

iClaudeSessionStatusImpl[nb_NotebookObject, tag_String, name_String] :=
  Module[{hdr, history, attachments, nbDir, workDir, accessDirs, nbFiles, result},
    hdr = Quiet[NBAccess`NBHistoryReadHeader[nb, tag]];
    history = Quiet[NBAccess`NBHistoryEntries[nb, tag]];

    Print[Style["=== Claude Session Status ===", Bold, 14]];
    Print[""];

    (* Session info *)
    Print[Style["\:30bb\:30c3\:30b7\:30e7\:30f3\:60c5\:5831", Bold, 12]];
    Print["  \:540d\:524d: ", name];
    Print["  \:30bf\:30b0: ", tag];
    Print["  \:30a8\:30f3\:30c8\:30ea\:6570: ", If[ListQ[history], Length[history], 0]];
    If[AssociationQ[hdr],
      If[KeyExistsQ[hdr, "parent"],
        Print["  \:89aa\:30bf\:30b0: ", hdr["parent"]]];
      If[TrueQ[hdr["inherit"]],
        Print["  \:7d99\:627f: True"]]];
    Print[""];

    (* Attachments *)
    attachments = If[AssociationQ[hdr], Lookup[hdr, "attachments", {}], {}];
    Print[Style["\:30a2\:30bf\:30c3\:30c1\:30e1\:30f3\:30c8", Bold, 12]];
    If[ListQ[attachments] && Length[attachments] > 0,
      Do[Print["  \:30fb ", a,
        If[FileExistsQ[a], "  (" <> ToString[FileByteCount[a]] <> " bytes)", "  (\:5b58\:5728\:3057\:306a\:3044)"]],
        {a, attachments}],
      Print["  (\:306a\:3057)"]];
    Print[""];

    (* Directories *)
    workDir = iClaudeWorkingDirectory[];
    nbDir = Quiet @ Check[NotebookDirectory[nb], None];
    accessDirs = iCollectAccessibleDirs[];
    Print[Style["\:30c7\:30a3\:30ec\:30af\:30c8\:30ea", Bold, 12]];
    Print["  $ClaudeWorkingDirectory: ", workDir];
    If[StringQ[nbDir],
      Print["  NotebookDirectory: ", nbDir],
      Print["  NotebookDirectory: (\:672a\:4fdd\:5b58)"]];
    Print["  $ClaudeAccessibleDirs: "];
    If[ListQ[$ClaudeAccessibleDirs],
      Do[Print["    \:30fb ", d, If[DirectoryQ[d], "", "  (\:5b58\:5728\:3057\:306a\:3044)"]],
        {d, $ClaudeAccessibleDirs}],
      Print["    (\:7a7a)"]];
    If[Length[accessDirs] > Length[If[ListQ[$ClaudeAccessibleDirs], $ClaudeAccessibleDirs, {}]],
      Print["  (\:52a0\:3048\:3066 NB/Attach \:7531\:6765: ",
        Length[accessDirs] - Length[If[ListQ[$ClaudeAccessibleDirs], $ClaudeAccessibleDirs, {}]],
        " dir)"]];
    Print[""];

    (* NotebookDirectory files *)
    If[StringQ[nbDir] && DirectoryQ[nbDir],
      nbFiles = Quiet @ Select[FileNames["*", nbDir], !DirectoryQ[#] &];
      Print[Style["NotebookDirectory \:306e\:30d5\:30a1\:30a4\:30eb (" <> ToString[Length[nbFiles]] <> ")", Bold, 12]];
      Do[Print["  \:30fb ", FileNameTake[f], "  (",
        ToString[FileByteCount[f]], " bytes, ",
        DateString[FileDate[f], {"Year","/","Month","/","Day"," ","Hour",":","Minute"}], ")"],
        {f, Take[nbFiles, UpTo[30]]}];
      If[Length[nbFiles] > 30,
        Print["  ... \:4ed6 ", Length[nbFiles] - 30, " \:30d5\:30a1\:30a4\:30eb"]];
      Print[""]];

    (* Settings *)
    Print[Style["\:305d\:306e\:4ed6", Bold, 12]];
    Print["  $ClaudeModel: ", If[$ClaudeModel === "", "(Claude Code \:30c7\:30d5\:30a9\:30eb\:30c8)", $ClaudeModel]];
    Print["  FallbackModels: ",
      Module[{fbModels = NBAccess`NBGetFallbackModels[]},
        If[ListQ[fbModels] && Length[fbModels] > 0,
          StringRiffle[Map[#[[1]] <> "/" <> #[[2]] <>
            " (max:" <> ToString[NBAccess`NBGetProviderMaxAccessLevel[#[[1]]]] <> ")" &,
            fbModels], ", "],
          "(\:672a\:8a2d\:5b9a)"]]];
    Print["  $ClaudeTimeout: ", $ClaudeTimeout, " sec"];
    Print["  PrivacySpec (AccessLevel): ",
      ToString[Lookup[NBAccess`NBGetPrivacySpec[], "AccessLevel", 0.5]]];
    Print["  Provider MaxAccessLevel: ",
      ToString[Normal[NBAccess`Private`$iProviderMaxAccessLevel]]];
    If[AssociationQ[$ClaudePackageKeywordMap] && Length[$ClaudePackageKeywordMap] > 0,
      Print["  PackageKeywordMap: ",
        StringRiffle[Keys[$ClaudePackageKeywordMap], ", "]]];

    result = <|
      "Session" -> name,
      "Tag" -> tag,
      "Entries" -> If[ListQ[history], Length[history], 0],
      "Attachments" -> If[ListQ[attachments], attachments, {}],
      "WorkingDirectory" -> workDir,
      "NotebookDirectory" -> If[StringQ[nbDir], nbDir, None],
      "AccessibleDirs" -> accessDirs,
      "Model" -> $ClaudeModel,
      "FallbackModels" -> NBAccess`NBGetFallbackModels[],
      "Timeout" -> $ClaudeTimeout
    |>;
    result
  ];

(* \:30c7\:30d5\:30a9\:30eb\:30c8\:30bb\:30c3\:30b7\:30e7\:30f3\:5bfe\:5fdc\:7248 ClaudeQuery\:ff08\:540c\:671f\:30fb\:30c7\:30d5\:30a9\:30eb\:30c8\:5c65\:6b74\:4fdd\:5b58\:4ed8\:304d\:ff09 *)
(* 手動コンパクション *)
ClaudeCompactHistory[] :=
  iCompactHistory[EvaluationNotebook[], iSessionTag[]];

ClaudeCompactHistory[name_String] :=
  iCompactHistory[EvaluationNotebook[], iNamedSessionTag[name]];

(* 履歴サイズ診断 *)
ClaudeHistorySize[] := ClaudeHistorySize[EvaluationNotebook[]];
ClaudeHistorySize[nb_NotebookObject] :=
  Module[{tag = iSessionTag[], raw, entries, byteSize, entryCount},
    raw = NBAccess`NBHistoryRawData[nb, tag];
    entries = Lookup[raw, "entries", {}];
    entryCount = Length[entries];
    byteSize = ByteCount[raw];
    <|"Entries" -> entryCount,
      "ByteCount" -> byteSize,
      "KiloBytes" -> Round[byteSize / 1024.0, 0.1],
      "Status" -> Which[
        byteSize > 500000, Style["危険: ノートブック動作に深刻な影響", Red, Bold],
        byteSize > 200000, Style["警告: コンパクション推奨", Orange, Bold],
        byteSize > 100000, Style["注意: やや大きい", RGBColor[0.6, 0.5, 0]],
        True, Style["正常", Darker[Green]]]|>
  ];

(* iMoveAfterEvalCell removed: use NBAccess`NBWriteAnchorAfterEvalCell *)

(* ============================================================
   AutoPrivate プロンプト注入
   AutoPrivate -> True の場合、秘密変数にアクセスするタスクで
   生成コードに Model -> $ClaudePrivateModel, PrivacySpec -> Automatic を
   付与するようシステムプロンプトに指示を追加する。
   ============================================================ *)

iAutoPrivatePrompt[True] :=
  If[ListQ[$ClaudePrivateModel] && Length[$ClaudePrivateModel] >= 2,
    "\n\n=== AutoPrivate Mode ===\n" <>
    "IMPORTANT: When the task accesses or processes confidential/secret variables " <>
    "(variables marked as confidential in this notebook), you MUST add the following " <>
    "options to any generated ClaudeEval, ClaudeQuery, or ContinueEval calls:\n" <>
    "  Model -> $ClaudePrivateModel, PrivacySpec -> Automatic\n" <>
    "This routes confidential data processing to a local/private model.\n" <>
    "$ClaudePrivateModel is currently set to: " <>
    ToString[$ClaudePrivateModel, InputForm] <> "\n" <>
    "Provider MaxAccessLevel: " <>
    ToString[NBAccess`NBGetProviderMaxAccessLevel[$ClaudePrivateModel[[1]]]] <> "\n" <>
    "The current confidential variables are: " <>
    ToString[Keys[NBAccess`NBGetConfidentialVars[]]] <> "\n" <>
    "If the user's task does NOT involve these confidential variables, " <>
    "you do NOT need to add Model/PrivacySpec options.\n" <>
    "=== End AutoPrivate ===\n",
    (* $ClaudePrivateModel が未設定の場合 *)
    "\n\n[AutoPrivate] Warning: $ClaudePrivateModel is not configured. " <>
    "Set it to a local model spec, e.g.:\n" <>
    "  $ClaudePrivateModel = {\"lmstudio\", \"openai/gpt-oss-20b\", \"http://127.0.0.1:1234\"}\n"
  ];
iAutoPrivatePrompt[_] := "";

(* ============================================================
   自動秘密マーク: AccessLevel が cloudcode の MaxAccessLevel を超える
   場合、LLM が書き込んだセルを自動的に秘密マークする。
   ローカルモデルが Confidential[] を使い忘れても安全。
   cellCountBefore: 書き込み前のセル数
   nb: ノートブック
   ============================================================ *)

iAutoMarkNewCellsConfidential[nb_NotebookObject, cellCountBefore_Integer] :=
  Module[{nAfter, newIndices, style},
    nAfter = NBAccess`NBCellCount[nb];
    If[nAfter <= cellCountBefore, Return[]];
    newIndices = Range[cellCountBefore + 1, nAfter];
    Do[
      style = NBAccess`NBCellStyle[nb, idx];
      (* Input/Output/Code セルのみマーク。Text/Print/Subsection 等はスキップ *)
      If[MemberQ[{"Input", "Output", "Code", "ExternalLanguage"}, style] &&
         !TrueQ[NBAccess`NBGetConfidentialTag[nb, idx]],
        NBAccess`NBMarkCellConfidential[nb, idx]],
      {idx, newIndices}]
  ];

(* accessLevel が cloudcode の上限を超えるかの判定 *)
iShouldAutoMarkConfidential[accessLevel_?NumericQ] :=
  accessLevel > NBAccess`NBGetProviderMaxAccessLevel["claudecode"];

Options[ClaudeQuery] = {Fallback -> False, WebFetch -> False, WebSearch -> True, Model -> Automatic, PrivacySpec -> Automatic, AutoPrivate -> False, AutoEvaluate -> False};

(* ClaudeQuery \:5185\:90e8\:5b9f\:88c5\:ff08\:975e\:540c\:671f\:ff09 *)
iClaudeQueryImpl[nb_NotebookObject, tag_String, prompt_, useFallback_, useWebFetch_,
    modelSpec_:Automatic, privSpec_:Automatic, autoPrivate_:False,
    autoEvaluate_:False] :=
  Module[{history, lastEntry, cellCountAfter, notebookCtx,
          fullPrompt, step, entry, jobId, queryCallback,
          accessLevel, availModels, useClaudeCode},
    (* アクセスレベルの解決: PrivacySpec と Model の両方を考慮 *)
    accessLevel = iResolveAccessLevel[privSpec, modelSpec];
    $iCurrentSessionAttachments = NBAccess`NBHistoryGetAttachments[nb, tag];
    history = iSessionHistoryWithInherit[nb, tag];
    lastEntry      = If[Length[history] > 0, Last[history], <||>];
    cellCountAfter = Replace[Lookup[lastEntry, "cellCountAfter",
                       Lookup[lastEntry, "cellCount", 0]], Except[_Integer] -> 0];
    (* アクセスレベルに基づいてノートブックコンテキストを構築 *)
    notebookCtx    = With[{r = Quiet[iCaptureNotebookContext[nb, cellCountAfter, accessLevel]]}, If[StringQ[r], r, ""]];
    step           = Length[iSessionHistory[nb, tag]];

    fullPrompt =
      $claudeQueryPrefix <>
      If[Length[history] > 0,
        "\:4ee5\:4e0b\:306f Mathematica \:3067\:306e\:4f5c\:696d\:5c65\:6b74\:3067\:3059\:3002\n\n" <>
        iSessionToContext[history],
        ""] <>
      If[StringQ[notebookCtx] && notebookCtx =!= "",
        "=== \:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:306e\:73fe\:5728\:306e\:72b6\:614b ===\n" <> notebookCtx, ""] <>
      iFileAccessContext[If[StringQ[prompt], prompt, ""]] <>
      iPackageDocsContext[If[StringQ[prompt], prompt, ""]] <>
      iAutoPrivatePrompt[autoPrivate] <>
      "=== \:8cea\:554f ===\n" <> iExpandSymbolRefs[prompt];

    entry = <|
      "step"        -> step,
      "time"        -> AbsoluteTime[],
      "type"        -> "query",
      "instruction" -> prompt,
      "fullPrompt"  -> Compress[fullPrompt],
      "cellCount"   -> NBAccess`NBCellCount[nb],
      "response"    -> "(\:51e6\:7406\:4e2d)",
      "code"        -> ""
    |>;
    iSessionAppend[nb, tag, entry];

    (* Job \:30b7\:30b9\:30c6\:30e0\:3067\:8a55\:4fa1\:30bb\:30eb\:76f4\:5f8c\:306b\:30b9\:30ed\:30c3\:30c8\:3092\:4e88\:7d04 *)
    jobId = NBAccess`NBBeginJobAtEvalCell[nb];

    (* アクセスレベルに基づいてフォールバック可能モデルを取得 *)
    availModels = If[TrueQ[useFallback],
      NBAccess`NBGetAvailableFallbackModels[accessLevel],
      {}];
    (* Claude Code 自体がアクセスレベルに対応可能か判定 *)
    useClaudeCode = NBAccess`NBProviderCanAccess["claudecode", accessLevel];

    If[TrueQ[useWebFetch] && TrueQ[useFallback],
      (* WebFetch \:306f\:540c\:671f\:3067\:5b9f\:884c\:3002\:8ab2\:91d1\:304c\:767a\:751f\:3059\:308b API \:7d4c\:7531\:306e\:305f\:3081 Fallback->True \:304c\:5fc5\:9808 *)
      Module[{response = iDoWebSearch[fullPrompt]},
        NBAccess`NBJobMoveToAnchor[jobId];
        If[StringQ[response],
          iWriteQueryResponse[nb, response, autoEvaluate]];
        NBAccess`NBEndJob[jobId];
        iSessionUpdateLast[nb, tag, <|
          "response"       -> response,
          "cellCountAfter" -> NBAccess`NBCellCount[nb]
        |>]],
      (* \:901a\:5e38\:30d1\:30b9: \:975e\:540c\:671f *)
      queryCallback = With[{nb2 = nb, stag2 = tag, jid = jobId,
            autoMark = iShouldAutoMarkConfidential[accessLevel],
            ccBefore = NBAccess`NBCellCount[nb],
            ae = autoEvaluate},
        Function[response,
          Module[{},
            (* \:30a2\:30f3\:30ab\:30fc\:306e\:76f4\:5f8c\:306b\:51fa\:529b\:3092\:914d\:7f6e *)
            NBAccess`NBJobMoveToAnchor[jid];
            (* \:30a8\:30e9\:30fc/\:5236\:9650\:30ec\:30b9\:30dd\:30f3\:30b9\:306f\:901a\:77e5\:30b9\:30bf\:30a4\:30eb\:3067\:8868\:793a\:3057\:3066\:7d42\:4e86 *)
            If[StringQ[response] && (iIsAPIErrorResponse[response] || StringStartsQ[response, "Error"]),
              NBAccess`NBWritePrintNotice[nb2, response, RGBColor[0.8, 0, 0]];
              NBAccess`NBEndJob[jid];
              iSessionUpdateLast[nb2, stag2, <|
                "response" -> response,
                "cellCountAfter" -> NBAccess`NBCellCount[nb2]|>];
              Return[]];
            If[StringQ[response],
              iWriteQueryResponse[nb2, response, ae],
              NBAccess`NBWriteCell[nb2,
                Cell["Error: \:5fdc\:7b54\:3092\:53d6\:5f97\:3067\:304d\:307e\:305b\:3093\:3067\:3057\:305f\:3002", "Text"]]];
            (* 高 AccessLevel の場合、新規セルを自動秘密マーク *)
            If[TrueQ[autoMark],
              iAutoMarkNewCellsConfidential[nb2, ccBefore]];
            (* \:30b8\:30e7\:30d6\:7d42\:4e86: \:672a\:4f7f\:7528\:30b9\:30ed\:30c3\:30c8\:3068\:30a2\:30f3\:30ab\:30fc\:3092\:524a\:9664 *)
            NBAccess`NBEndJob[jid];
            iSessionUpdateLast[nb2, stag2, <|
              "response"       -> response,
              "cellCountAfter" -> NBAccess`NBCellCount[nb2]
            |>]
          ]
        ]
      ];
      If[modelSpec =!= Automatic && ListQ[modelSpec] && Length[modelSpec] >= 2,
        (* Model \:6307\:5b9a\:3042\:308a: API \:7d4c\:7531\:3067\:6307\:5b9a\:30e2\:30c7\:30eb\:3092\:76f4\:63a5\:547c\:3073\:51fa\:3057 *)
        iStartFallbackAsync[fullPrompt, nb, queryCallback,
          {modelSpec}, 1, jobId],
        (* アクセスレベルに基づくルーティング *)
        If[useClaudeCode,
          (* Claude Code 使用可能: 通常パス (フォールバック時は availModels を使用) *)
          iClaudeQueryAsyncWithProgress[
            fullPrompt, queryCallback, nb, {}, jobId, availModels],
          (* Claude Code 使用不可: フォールバックモデルへ直接 *)
          If[Length[availModels] > 0,
            iStartFallbackAsync[fullPrompt, nb, queryCallback,
              availModels, 1, jobId],
            (* どのモデルもアクセスレベルに対応不可 *)
            NBAccess`NBWriteSlot[jobId, 1,
              Cell["\[WarningSign] AccessLevel " <> ToString[accessLevel] <>
                " \:306b\:5bfe\:5fdc\:3059\:308b\:30e2\:30c7\:30eb\:304c\:3042\:308a\:307e\:305b\:3093\:3002", "Print",
                FontWeight -> Bold, FontColor -> Red, FontSize -> 11]];
            NBAccess`NBEndJob[jobId];
            iSessionUpdateLast[nb, tag, <|
              "response" -> "Error: AccessLevel " <> ToString[accessLevel] <>
                " \:306b\:5bfe\:5fdc\:3059\:308b\:30e2\:30c7\:30eb\:304c\:3042\:308a\:307e\:305b\:3093",
              "cellCountAfter" -> NBAccess`NBCellCount[nb]|>]
          ]
        ]
      ]
    ];
  ];

ClaudeQuery[prompt_, opts:OptionsPattern[]] := (
    $currentUseFallback = TrueQ[OptionValue[Fallback]];
    $iAllowReadTool = True;
    $iAllowWebSearch = TrueQ[OptionValue[WebSearch]];
  With[{nb = Quiet[EvaluationNotebook[]]},
  Module[{session, tag},
  (* LLM 送信直前の精密チェック (第2層):
     全ノートブックを走査して完全な依存グラフを構築し、
     秘密依存変数の最終判定を行う *)
  iPrecisionConfidentialCheck[nb];
  session = iEnsureDefaultSession[nb];
  tag     = session["SessionTag"];
  iClaudeQueryImpl[nb, tag, prompt,
    TrueQ[OptionValue[Fallback]], TrueQ[OptionValue[WebFetch]],
    OptionValue[Model], OptionValue[PrivacySpec], TrueQ[OptionValue[AutoPrivate]],
    TrueQ[OptionValue[AutoEvaluate]]]
  ]]);

(* セッション対応版 ClaudeQuery（非同期・履歴保存付き） *)
ClaudeQuery[session_Association, prompt_, opts:OptionsPattern[]] := (
    $currentUseFallback = TrueQ[OptionValue[ClaudeQuery, {opts}, Fallback]];
    $iAllowReadTool = True;
    $iAllowWebSearch = TrueQ[OptionValue[ClaudeQuery, {opts}, WebSearch]];
  With[{nb = session["Notebook"]},
  Module[{tag},
    tag = session["SessionTag"];
    (* LLM 送信直前の精密チェック (第2層) *)
    iPrecisionConfidentialCheck[nb];
    $iCurrentSessionAttachments = NBAccess`NBHistoryGetAttachments[nb, tag];
    iClaudeQueryImpl[nb, tag, prompt,
      TrueQ[OptionValue[ClaudeQuery, {opts}, Fallback]],
      TrueQ[OptionValue[ClaudeQuery, {opts}, WebFetch]],
      OptionValue[ClaudeQuery, {opts}, Model],
      OptionValue[ClaudeQuery, {opts}, PrivacySpec],
      TrueQ[OptionValue[ClaudeQuery, {opts}, AutoPrivate]],
      TrueQ[OptionValue[ClaudeQuery, {opts}, AutoEvaluate]]]
  ]]);

(* ============================================================
   $Language ベースの言語指示ヘルパー
   プロンプト内の言語指定を $Language に基づいて動的生成する。
   ============================================================ *)

(* 現在の言語名を返す（英語表記） *)
iLanguageName[] := If[StringQ[$Language], $Language, "English"];

(* プロンプト用の言語指示文を生成。
   style:
     "polite"  → 敬体 (日本語) / polite style (他言語)
     "plain"   → 常体 (日本語) / concise style (他言語)
     "general" → "All text must be written in ..." *)
iLanguageInstruction["polite"] :=
  If[$Language === "Japanese",
    "Write in Japanese using \:656c\:4f53 (\:3067\:3059\:30fb\:307e\:3059\:8abf) style.\n",
    "Write in " <> iLanguageName[] <> ".\n"];

iLanguageInstruction["plain"] :=
  If[$Language === "Japanese",
    "Write in Japanese using \:5e38\:4f53 (\:3060\:30fb\:3067\:3042\:308b\:8abf) style for brevity.\n",
    "Write in " <> iLanguageName[] <> " using concise style.\n"];

iLanguageInstruction["general"] :=
  "All text must be written in " <> iLanguageName[] <> ".\n";

iLanguageInstruction["summary"] :=
  "Summarize the following Mathematica package update instruction in ONE short " <>
  iLanguageName[] <> " sentence (max 40 chars). ";

iLanguageInstruction["explanation"] :=
  "All explanatory text must be written in " <> iLanguageName[] <> ".";

ClaudeMath[task_String] := iClaudeQueryRaw[
  "You are an expert Wolfram Language / Mathematica programmer. \
Provide clean, working Mathematica code. \
Wrap all code in ```mathematica ... ``` blocks. \
Use idiomatic Wolfram Language style. \
For explanatory text outside code blocks: \
do NOT use markdown tables (no |---|); \
instead describe comparisons as numbered lists or plain sentences. \
Do not use markdown bold (**text**) or heading syntax (# ##). \
All explanatory text must be written in " <> iLanguageName[] <> ". \
Task: " <> task
];

ClaudeExtractCode[response_String] := Module[{matches},
  matches = StringCases[response,
    "```mathematica" ~~ Shortest[code__] ~~ "```" :> StringTrim[code]];
  If[Length[matches] > 0, First[matches], response]
];

ClaudeExtractAllCode[response_String] :=
  StringCases[response,
    "```mathematica" ~~ Shortest[code__] ~~ "```" :> StringTrim[code]];

(* 言語タグ付きコードブロック抽出: {<|"lang"->..., "code"->...|>, ...} *)
$iExternalLangMap = <|
  "python" -> "Python", "py" -> "Python",
  "r" -> "R",
  "julia" -> "Julia",
  "ruby" -> "Ruby",
  "javascript" -> "NodeJS", "js" -> "NodeJS",
  "shell" -> "Shell", "bash" -> "Shell", "sh" -> "Shell",
  "sql" -> "SQL"
|>;

iExtractAllCodeBlocks[response_String] := Module[{raw},
  raw = StringCases[response,
    RegularExpression["```(\\w+)\\n([\\s\\S]*?)```"] :> {"$1", "$2"}];
  Map[Function[pair,
    Module[{tag = ToLowerCase[First[pair]], code = StringTrim[Last[pair]]},
      <|"lang" -> If[tag === "mathematica", "mathematica",
                    Lookup[$iExternalLangMap, tag, "mathematica"]],
        "fenceTag" -> First[pair],
        "code" -> iFixUnicodeEscapes[code]|>
    ]], raw]
];

(* \uXXXX 形式の JavaScript/Python 式 Unicode エスケープを実文字に変換 *)
(* Mathematica は \:XXXX 形式なので \uXXXX はリテラルとして残ってしまう *)
iFixUnicodeEscapes[code_String] :=
  StringReplace[code,
    "\\u" ~~ hex : Repeated[HexadecimalCharacter, {4}] :>
      FromCharacterCode[FromDigits[hex, 16]]];

(* ExternalLanguage セルを書き込む *)
iWriteExternalLanguageCell[nb_NotebookObject, code_String,
    lang_String, autoEvaluate_:False] :=
  NBAccess`NBWriteExternalLanguageCell[nb, code, lang, autoEvaluate];

(* レスポンスからコードブロックを書き込む共通処理 *)
(* 長時間ブロッキングする可能性のある関数パターン *)
(* 外部サービスへの不可逆な書き込み操作: 自動実行をスキップして確認を求める *)
$iLongRunningPatterns = {
  "GitHubRefreshAndCommit", "GitHubPushAll", "GitHubCommit",
  "GitHubCreatePullRequest", "GitHubMergePullRequest",
  "GitHubSubmitPullRequest"
};

iIsLongRunningCode[code_String] :=
  AnyTrue[$iLongRunningPatterns, StringContainsQ[code, #] &];

iWriteResponseBlocks[nb_NotebookObject, response_String, autoEvaluate_:True] :=
  Module[{allBlocks, mathBlocks, extBlocks, blocks = {}, ae},
    allBlocks = iExtractAllCodeBlocks[response];
    mathBlocks = Select[allBlocks, #["lang"] === "mathematica" &];
    extBlocks  = Select[allBlocks, #["lang"] =!= "mathematica" &];
    (* Mathematica ブロックの構文チェック: 不正なコードは警告付きで挿入 *)
    mathBlocks = Map[
      Function[b,
        If[!TrueQ[Quiet[SyntaxQ[b["code"]]]],
          nbPrint[nb, "\:26a0\:fe0f \:69cb\:6587\:30a8\:30e9\:30fc\:3092\:691c\:51fa: \:751f\:6210\:30b3\:30fc\:30c9\:306e\:6587\:6cd5\:304c\:4e0d\:6b63\:3067\:3059\:3002\:624b\:52d5\:3067\:4fee\:6b63\:3057\:3066\:304f\:3060\:3055\:3044\:3002"];
          <|b, "syntaxError" -> True|>,
          b
        ]
      ], mathBlocks];
    Which[
      (* Mathematica ブロックがある場合 *)
      Length[mathBlocks] > 0,
        Do[
          (* 長時間ブロッキング関数を含むセルは autoEvaluate を抑制 *)
          (* 構文エラーのブロックも autoEvaluate を抑制 *)
          ae = autoEvaluate && !iIsLongRunningCode[b["code"]] && !TrueQ[b["syntaxError"]];
          iWriteSmartCell[nb, b["code"], ae];
          If[!ae && autoEvaluate,
            If[TrueQ[b["syntaxError"]],
              nbPrint[nb, "\:26a1 \:4e0a\:306e\:30bb\:30eb\:306f\:69cb\:6587\:30a8\:30e9\:30fc\:306e\:305f\:3081\:81ea\:52d5\:5b9f\:884c\:3092\:30b9\:30ad\:30c3\:30d7\:3057\:307e\:3057\:305f\:3002\:4fee\:6b63\:5f8c\:306b Shift+Enter \:3067\:5b9f\:884c\:3057\:3066\:304f\:3060\:3055\:3044\:3002"],
              nbPrint[nb, "\:26a1 \:4e0a\:306e\:30bb\:30eb\:306f\:5916\:90e8\:30b5\:30fc\:30d3\:30b9\:3078\:306e\:66f8\:304d\:8fbc\:307f\:64cd\:4f5c\:3092\:542b\:3080\:305f\:3081\:81ea\:52d5\:5b9f\:884c\:3092\:30b9\:30ad\:30c3\:30d7\:3057\:307e\:3057\:305f\:3002Shift+Enter \:3067\:5b9f\:884c\:3057\:3066\:304f\:3060\:3055\:3044\:3002"]]],
          {b, mathBlocks}];
        iWriteContinueEvalButton[nb, autoEvaluate];
        blocks = #["code"] & /@ mathBlocks,
      (* 外部言語ブロックのみの場合: ExternalLanguage セルとして書き込む *)
      Length[extBlocks] > 0,
        Do[iWriteExternalLanguageCell[nb, b["code"], b["lang"], autoEvaluate],
          {b, extBlocks}];
        blocks = #["code"] & /@ extBlocks
    ];
    blocks
  ];

(* ClaudeQuery \:7528\:30d5\:30a9\:30fc\:30de\:30c3\:30c8\:6307\:793a\:ff08\:30d7\:30ed\:30dd\:30fc\:30b7\:30e7\:30ca\:30eb\:30d5\:30a9\:30f3\:30c8\:5411\:3051\:ff09 *)
$claudeQueryPrefix :=
  "You are a knowledgeable assistant. Your response will be rendered as styled cells in Mathematica's notebook.\n\
RESPONSE STYLE:\n\
ClaudeQuery produces a rich notebook output with text explanations and optional code blocks.\n\
- Text explanations are rendered as styled cells (headings, items, text).\n\
- ```mathematica code blocks are inserted as executable Input cells and auto-evaluated.\n\
When the user asks for graphs, plots, visualizations, or demonstrations, \
include ```mathematica code blocks that generate them using Plot, ListPlot, Manipulate, etc.\n\
Mix text explanations with code blocks freely to create a well-structured notebook document.\n\
VARIABLE NAMING: In ```mathematica code blocks, a single underscore creates a Subscript \
(e.g. tiling_12 = Subscript[tiling, 12]) which is fine. \
However, NEVER use TWO OR MORE underscores in a name \
(e.g. tiling3_12_12, my_var_name). These cause pattern-matching errors. \
Use camelCase for multi-part names: tiling3Type12x12, myVarName.\n\
FORMATTING RULES:\n\
- Use markdown headings (# ## ###) to organize sections.\n\
- Use bullet lists (- item) or numbered lists (1. item) for structured information.\n\
  Use indented lists (  - subitem) for nested items.\n\
- Do NOT use markdown tables (no |---|). Tables are not rendered properly.\n\
- **Bold** is allowed but will be stripped in display.\n\
- All text must be written in " <> iLanguageName[] <> ".\n\
- For mathematical expressions, use LaTeX $...$ notation (e.g. $\\nabla^2 \\varphi = 0$, $\\pm q_m$). \
The notebook converts these into Mathematica typeset display automatically.\n\
CRITICAL: ALL math notation MUST be wrapped in $...$ delimiters. \
NEVER write raw LaTeX commands (\\nabla, \\frac, \\partial) outside of $...$. \
NEVER use $$...$$ (double dollar). Only use single $...$ for inline math.\n\
Examples:\n\
  WRONG: The Laplace equation is \\nabla^2 \\varphi = 0\n\
  CORRECT: The Laplace equation is $\\nabla^2 \\varphi = 0$\n\
  WRONG: $$\\frac{\\partial^2 u}{\\partial t^2} = c^2 \\nabla^2 u$$\n\
  CORRECT: $\\frac{\\partial^2 u}{\\partial t^2} = c^2 \\nabla^2 u$\n\
INSIDE $...$ use PURE LaTeX syntax only (not Mathematica). \
Use parentheses for function arguments, not square brackets:\n\
  WRONG: $\\Psi[x,t]$  CORRECT: $\\Psi(x,t)$\n\
  WRONG: $V[x]$  CORRECT: $V(x)$\n\
Avoid \\hat{}, \\vec{} if possible; use simple letters. \
Keep formulas concise — very complex multi-line TeX may not convert.\n\
SYMBOL REFERENCE CONVENTION: <<n>> in the prompt refers to a specific symbol (variable or function) \
in the user's Mathematica notebook kernel. Metadata about referenced symbols is appended at the end of the prompt. \
In your answer, refer to the symbol by name.\n\
NOTE: Some cells in the notebook are marked as confidential and have been excluded from \
the context sent to you. Do NOT ask the user to share confidential data. If you need to \
reference excluded data, describe it by variable name or structure only.\n\
PACKAGE AWARENESS:\n\
When the question mentions a package name from the 'Packages in $packageDirectory' list in File Access Context,\n\
answer based on the package documentation (shown in the prompt if available and fresh).\n\
If the user wants to MODIFY a package, suggest using ClaudeEval with ClaudeUpdatePackage.\n\
Do NOT attempt to read or write package files directly.\n\
WEB SEARCH:\n\
You have access to the WebSearch tool. When the user's question would benefit from current information \
(recent events, latest documentation, API references, etc.), use the WebSearch tool proactively.\n\
Web search via Claude Code's built-in tool does not incur additional costs and is encouraged.\n\n";


$claudeMathPromptPrefix :=
  "You are an expert Wolfram Language / Mathematica programmer. \
Your response will be parsed by a program that extracts ```mathematica ... ``` blocks \
and inserts them as executable Input cells in the user's notebook.\n\n\
CRITICAL RULE: You MUST ALWAYS include at least one ```mathematica ... ``` code block in your response. \
Responses without any code block are USELESS to the user because only code blocks are inserted into the notebook. \
Plain text without code blocks will be discarded.\n\n\
- If the task requires computation, data processing, or file output: write the Mathematica code that does it.\n\
- If the task asks for information, a summary, or a list (e.g. 'list what we did', 'explain X'): \
wrap the answer as a Mathematica expression using Column[{...}], Print[...], \
or assign it to a variable like result = {...}. \
Do NOT use CellPrint, TextCell, or Cell[...] to create text cells \:2014 text is placed automatically. \
Example: Instead of writing a plain text list, write:\n\
```mathematica\n\
Column[{\n\
  Style[\"\\:4f5c\\:696d\\:5c65\\:6b74\", Bold, 16],\n\
  \"1. \\:968e\\:4e57\\:306e\\:5b9f\\:88c5\",\n\
  \"2. \\:30d5\\:30a3\\:30dc\\:30ca\\:30c3\\:30c1\\:6570\\:5217\"\n\
}, Spacings -> 1]\n\
```\n\n\
Use idiomatic Wolfram Language style. \
VARIABLE NAMING: A single underscore creates a Subscript \
(e.g. q_m = Subscript[q, m]) which is fine and encouraged for mathematical notation. \
However, NEVER use TWO OR MORE underscores in a name \
(e.g. tiling3_12_12, my_var_name). These cause pattern-matching errors.\n\
Use camelCase for multi-part names: tiling3Type12x12, myVarName.\n\
For brief explanatory text OUTSIDE code blocks (a few sentences only): \
do NOT use markdown tables (no |---|); \
do not use markdown bold (**text**) or heading syntax (# ##). \
All explanatory text must be written in " <> iLanguageName[] <> ".\n\
For mathematical expressions in explanatory text, use LaTeX notation with $...$ delimiters.\n\
Examples: $\\nabla^2 \\varphi = 0$, $\\pm q_m$, $\\mathbf{B} = -\\mu_0 \\nabla \\varphi$\n\
The notebook automatically converts $...$ LaTeX math into Mathematica typeset display.\n\n\
MATHEMATICAL EXPRESSION STYLE (IMPORTANT):\n\
The notebook automatically typesets code into beautiful mathematical notation using StandardForm.\n\
- Integrate -> \[Integral], Sum -> \[CapitalSigma], Product -> \[CapitalPi], D -> partial derivative\n\
- Subscript[q, m] -> subscript display, Sqrt -> radical sign, MatrixForm -> matrix layout\n\
- Greek letters (\[CurlyPhi], \[Mu], \[Pi] etc.) display as proper symbols\n\
Use standard Mathematica function-call form for all mathematical expressions.\n\
NOTE: MakeBoxes typesetting is applied ONLY to simple math expressions (Integrate, Sum, \
Subscript, Solve, etc.). Complex procedural code (Module, Block, Show, Plot, Manipulate, \
CompoundExpression) is rendered via FEParser and will NOT be typeset. \
This is by design to preserve variable scoping and Graphics structures.\n\n\
CRITICAL: Do NOT put (* comments *) inside ```mathematica code blocks. \
Comments are stripped by the typesetter. \
Instead, write explanatory text OUTSIDE code blocks as plain text.\n\
LATEX MATH IN EXPLANATORY TEXT:\n\
Use $...$ delimited LaTeX math notation for mathematical expressions in explanatory text.\n\
The notebook automatically converts these into Mathematica typeset display.\n\
Examples: $\\nabla^2 \\varphi = 0$, $\\pm q_m$, $\\mathbf{B} = -\\mu_0 \\nabla \\varphi$, $\\int \\sin x \\, dx$\n\
Do NOT use $$...$$ (display math). Only use single $...$ (inline math).\n\
INSIDE $...$ use PURE LaTeX syntax (not Mathematica bracket notation):\n\
  WRONG: $\\Psi[x,t]$  CORRECT: $\\Psi(x,t)$\n\
  WRONG: $V[x]$  CORRECT: $V(x)$\n\n\
CRITICAL: NEVER use low-level box constructs or display characters in string literals:\n\
- NEVER use \\!\\(\\*SuperscriptBox[...]\\) or any \\!\\(\\*...Box[...]\\) inline box syntax in strings.\n\
- NEVER use \\[Superscript], \\[Subscript], \\[Conjugate] etc. as characters inside strings.\n\
- For labels/titles needing math, use Row/Superscript/Subscript EXPRESSIONS, not string hacks.\n\
Example - WRONG:\n\
  Style[\"\\:30e9\\:30d7\\:30e9\\:30b9\\:65b9\\:7a0b\\:5f0f: \\!\\(\\*SuperscriptBox[\\(\\[Del]\\), \\(2\\)]\\)\\[CurlyPhi] = 0\", Bold]\n\
  Row[{\"\\[Del]\\[Superscript]2\\[CurlyPhi] = \", expr}]\n\
Example - CORRECT:\n\
  Style[Row[{\"\\:30e9\\:30d7\\:30e9\\:30b9\\:65b9\\:7a0b\\:5f0f: \", Superscript[\"\\[Del]\", 2], \"\\[CurlyPhi] = 0\"}], Bold]\n\
  Row[{Superscript[\"\\[Del]\", 2], \"\\[CurlyPhi] = \", expr}]\n\n\
UNICODE IN STRINGS (CRITICAL):\n\
When writing Mathematica string literals, ALWAYS use literal Unicode characters directly. \
NEVER use \\uXXXX escape sequences (e.g. \\uff08, \\u30fb). \
Mathematica does not interpret \\uXXXX; it uses \\:XXXX syntax. \
Simply write the actual characters: \:ff08 not \\uff08, \:30fb not \\u30fb.\n\n\
When data (Dataset, Association, List, etc.) is provided in the prompt, \
treat it as Mathematica data available in the current session. \
If the user refers to 'this dataset' or similar, the data shown in the prompt is the target.\n\n\
NOTEBOOK CONTEXT RESOLUTION (CRITICAL):\n\
When the user mentions 'error', 'output', 'result', 'this code', or similar ambiguous references \
WITHOUT specifying a package name or file name, ALWAYS assume they refer to the \
RECENT NOTEBOOK OUTPUT shown in the '=== \\:30ce\\:30fc\\:30c8\\:30d6\\:30c3\\:30af\\:306e\\:73fe\\:5728\\:306e\\:72b6\\:614b ===' section of this prompt. \
Examine that section for error messages, warnings, or unexpected outputs, \
and generate code that fixes or addresses the issues found there. \
Do NOT ask the user which package or code has errors when the notebook context already contains error messages.\n\n\
IMPORTANT: When asked to produce PDF, image, or any file output, \
always generate Mathematica CODE that creates the output, \
rather than attempting to return the binary data directly. \
For example, use Export[\"output.pdf\", ...] to create a PDF file. \
The user will execute the generated code in their Mathematica notebook.\n\n\
NOTE: Some cells in the notebook are marked as confidential and excluded from this prompt. \
Do NOT ask the user to share confidential data. Reference excluded data by variable name only.\n\
SYMBOL REFERENCE: <<n>> in the prompt refers to a specific symbol in the user's kernel. \
Metadata is appended at the end. Use the symbol name directly in your code.\n\
Do NOT add any final guidance like 'ContinueEval', 'ContinueEval[]', '継続できます', '下のボタン', or 'コードを実行して確認'.\nThe notebook front end adds the continuation UI automatically, so your response must NOT mention it.\n\n" <>
"EXTERNAL LANGUAGE CODE:\n" <>
"When the user asks for code entirely in Python, R, Julia, Ruby, or JavaScript (NodeJS):\n" <>
"- Use the appropriate fenced code block: ```python, ```r, ```julia, ```ruby, or ```javascript\n" <>
"- Do NOT wrap it in ExternalEvaluate[]. The notebook has native cells for these languages.\n" <>
"When the user asks for Mathematica code that CALLS an external language for part of the task:\n" <>
"- Use ```mathematica blocks with ExternalEvaluate[] as needed.\n\n" <>
"EXCEL IMPORT CONVENTION (CRITICAL):\n" <>
"When importing Excel (.xlsx/.xls) files:\n" <>
"- ALWAYS use {\"Dataset\"} format unless the user explicitly requests Table, List, etc.\n" <>
"  The first row is used as column keys by default.\n" <>
"  If the first row contains data (same type as subsequent rows), generate column keys from column numbers.\n" <>
"- Single sheet (result length=1): use First @ Import[...] to unwrap and return a single Dataset.\n" <>
"- Multiple sheets (result length>=2): return the list of Datasets as-is.\n" <>
"- Example:\n" <>
"    data = First @ Import[FileNameJoin[{Quiet @ Check[NotebookDirectory[], $packageDirectory], \"file.xlsx\"}], {\"Dataset\"}]\n\n" <>
"CONFIDENTIAL VARIABLE ASSIGNMENT (CRITICAL):\n" <>
"When the user's instruction contains ANY of these patterns:\n" <>
"  \:79d8\:5bc6\:5909\:6570, \:6a5f\:5bc6\:5909\:6570, \:79d8\:533f\:5909\:6570, \:79d8\:5bc6, \:6a5f\:5bc6, \:79d8\:533f,\n" <>
"  Confidential\:306b\:3059\:308b, Confidential\:306b\:4ee3\:5165, Confidential\:3078\:4ee3\:5165,\n" <>
"  \:79d8\:5bc6\:306b\:3059\:308b, \:6a5f\:5bc6\:306b\:3059\:308b, \:79d8\:533f\:306b\:3059\:308b, \:79d8\:533f\:305b\:3088, \:79d8\:5bc6\:3078\:4ee3\:5165, \:6a5f\:5bc6\:3078\:4ee3\:5165\n" <>
"You MUST wrap the assigned value with Confidential[...].\n" <>
"Examples:\n" <>
"  '\:6210\:7e3e.xlsx \:3092\:79d8\:5bc6\:5909\:6570 \:6210\:7e3e \:3078\:4ee3\:5165' ->\n" <>
"    \:6210\:7e3e = Confidential[First @ Import[FileNameJoin[{Quiet @ Check[NotebookDirectory[], $packageDirectory], \"\:6210\:7e3e.xlsx\"}], {\"Dataset\"}]]\n" <>
"  '\:30c7\:30fc\:30bf\:3092<<data>>\:306b\:4ee3\:5165\:3057\:3066\:79d8\:533f\:305b\:3088' ->\n" <>
"    data = Confidential[expr]\n" <>
"  '<<x>>\:3092Confidential\:306b\:3059\:308b' -> x = Confidential[x]\n" <>
"The Confidential[] wrapper automatically marks cells and registers the variable as confidential.\n" <>
"Do NOT assign the value first and mark it later. Always wrap at assignment time.\n" <>
"IMPORTANT: NonConfidential[] USAGE RESTRICTION:\n" <>
"  NonConfidential[] removes the confidential mark and exposes the value in Output.\n" <>
"  You MUST NOT generate NonConfidential[] in code unless the user EXPLICITLY requests\n" <>
"  declassification (e.g., '\:516c\:958b\:3057\:3066', '\:79d8\:5bc6\:89e3\:9664', 'declassify', 'reveal', '\:8868\:793a\:3057\:3066\:3088\:3044').\n" <>
"  Confidential data MUST remain confidential throughout computation.\n" <>
"  If computation results depend on confidential variables, keep them wrapped:\n" <>
"    result = Confidential[Mean[secretData]]\n" <>
"  The user can manually call NonConfidential[] if they choose to declassify.\n" <>
"  EXCEPTION: When importing a Dataset as confidential, you SHOULD output the column KEYS\n" <>
"  (not values) using NonConfidential[] in a SEPARATE code block AFTER the Confidential assignment.\n" <>
"  Column keys are structural metadata, not secret data:\n" <>
"    Block 1: \:6210\:7e3e = Confidential[First @ Import[..., {\"Dataset\"}]]\n" <>
"    Block 2: NonConfidential[Row[{\"\:6210\:7e3e\:306e\:30ad\:30fc: \", Normal[Keys[\:6210\:7e3e[[1]]]]}, \" \"]]\n\n" <>
"CONFIDENTIAL VARIABLE STRUCTURE PROBE:\n" <>
"When the task requires using a confidential variable whose structure is unknown " <>
"(marked as excluded/confidential in the prompt, with no type info available):\n" <>
"1. Do NOT guess or fabricate the variable's structure.\n" <>
"2. Output a structure-probing code block ONLY:\n" <>
"3. Add brief text: '上の構造調査結果を確認後、ContinueEval[] で本コードを生成します。'\n" <>
"4. When ContinueEval is called with the structure results in history, " <>
"generate the actual code using the revealed structure.\n\n" <>
"R CODE OUTPUT CONVENTION:\n" <>
"When generating R code for Mathematica ExternalLanguage cells, " <>
"Mathematica does not display R's stdout in Out[]. " <>
"Always end R code with an expression that returns a value, " <>
"typically using list() to collect named results:\n" <>
"  list(\"varname\" = value, \"result\" = computed_value)\n" <>
"This ensures the result appears in Mathematica's Out[] as a List.\n\n" <>

"PACKAGE OPERATION RULES (CRITICAL):\n" <>
"When the task mentions a package name that appears in the '$packageDirectory packages' list " <>
"(shown in File Access Context), you MUST use ClaudeCode package management functions instead of writing raw code.\n" <>
"- To UPDATE an existing package: ClaudeUpdatePackage[\"PackageName\", \"update instruction\"]\n" <>
"- To CREATE a new package: ClaudeCreatePackage[\"PackageName\", \"specification\"]\n" <>
"- To generate documentation: ClaudeCreateDocumentation[\"PackageName\"]\n" <>
"- To update documentation: ClaudeUpdateDocumentation[\"PackageName\", \"update instruction\"]\n" <>
"- To continue after update: ContinueUpdate[] or ContinueUpdate[\"instruction\"]\n" <>
"NEVER read package source files manually with Import/ReadString.\n" <>
"NEVER attempt to rewrite package files with Export/Put.\n" <>
"These functions handle backup, validation, reload, and history automatically.\n" <>
"If the task is a QUESTION about a package (not modification), answer using the docs context " <>
"or suggest ClaudeQuery with the package name.\n" <>
"STRING SAFETY IN GENERATED CODE (CRITICAL):\n" <>
"When generating ClaudeUpdatePackage, ClaudeUpdateDocumentation, or similar calls:\n" <>
"- The instruction string argument MUST be a concise summary of what to do, NOT a verbatim copy of the user's input.\n" <>
"- NEVER paste the user's long text (especially content containing quotes, parentheses, " <>
"or code block markers) directly into a Mathematica string literal.\n" <>
"- Summarize the intent in 1-3 short sentences. Example:\n" <>
"  BAD:  ClaudeUpdateDocumentation[\"pkg\", \"READMEの末尾（ライセンスの後）に誤って...（長い引用）...\"]\n" <>
"  GOOD: ClaudeUpdateDocumentation[\"pkg\", \"README.mdのライセンスセクション以降に誤挿入されたテキストを削除する\"]\n" <>
"- Ensure all generated string literals are properly closed with matching quotes.\n" <>
"- Verify the generated code has balanced brackets: [...], (...), \"...\".\n" <>
"Example: User says 'Maildb\:306eshowMails\:306e\:30c7\:30d5\:30a9\:30eb\:30c8\:8868\:793a\:6570\:309230\:306b\:5909\:66f4' -> Output:\n" <>
"```mathematica\nClaudeUpdatePackage[\"Maildb\", \"showMails\:306a\:3069\:306e\:30e1\:30fc\:30eb\:8868\:793a\:306e\:30c7\:30d5\:30a9\:30eb\:30c8\:8868\:793a\:6570\:309230\:306b\:5909\:66f4\:3059\:308b\"]\n```\n\n" <>
"OPTION ARGUMENTS (CRITICAL):\n" <>
"When generating calls to ClaudeCode/ClaudeCreatePackage/ClaudeUpdatePackage/ClaudeEval/ContinueEval/ContinueUpdate " <>
"or any infrastructure function, you MUST check the api.md in this prompt for the full list of supported options.\n" <>
"- If the user's instruction contains information matching a known option " <>
"(e.g., 'Reference: path', 'Fallback', 'StartTime', 'TargetFunctions', 'UpdateApiMd', " <>
"'References', 'Demos', 'Disclaimer', etc.), " <>
"pass it as a proper Mathematica option argument in the function call.\n" <>
"- Example: User says 'ClaudeCreatePackage with Reference file C:\\path\\file.lisp' -> Output:\n" <>
"```mathematica\nClaudeCreatePackage[\"PkgName\", \"spec...\", References -> {\"C:\\\\path\\\\file.lisp\"}]\n```\n" <>
"- Do NOT embed option-like information only in the prompt string. " <>
"If it maps to a documented option, use the option argument syntax.\n\n" <>
"INFRASTRUCTURE API RULES (CRITICAL):\n" <>
"When generating code that uses GitHubREST, ClaudeCode, or NBAccess functions:\n" <>
"- ONLY use function names documented in the API reference section (api.md) shown in this prompt.\n" <>
"- NEVER invent or guess function names like GitHubCreateBranch, GitHubPushFile, GitHubPushCommit.\n" <>
"- For pull requests, use GitHubSubmitPullRequest (one-shot: branch+commit+PR) or " <>
"GitHubRefreshAndCommit + GitHubCreatePullRequest (manual steps).\n" <>
"- If no API reference is shown and you need infrastructure functions, " <>
"ask the user to check with ?GitHubREST`* or similar.\n\n" <>
"THINKING TRIGGER INJECTION (IMPORTANT):\n" <>
"When generating ClaudeUpdatePackage, ClaudeCreatePackage, ClaudeEval, or ContinueEval calls,\n" <>
"if the user's instruction implies deep thinking is needed, insert a thinking trigger word\n" <>
"at the BEGINNING of the instruction/prompt string argument.\n" <>
"Mapping (Japanese encouragement -> English trigger, prepend to instruction string):\n" <>
"- \:6b7b\:306c\:6c17\:3067\:8003\:3048\:308d/\:672c\:6c17\:51fa\:305b/\:5168\:529b\:3067/\:5f7b\:5e95\:7684\:306b/\:3042\:3089\:3086\:308b\:53ef\:80fd\:6027 -> prepend 'ultrathink\\n' to the instruction\n" <>
"- \:3058\:3063\:304f\:308a\:8003\:3048\:3066/\:3088\:304f\:8003\:3048\:3066/\:6148\:91cd\:306b/\:304c\:3093\:3070\:308c/\:8ca0\:3051\:308b\:306a/\:4e01\:5be7\:306b/\:6df1\:304f\:8003\:3048 -> prepend 'think hard\\n'\n" <>
"- \:8003\:3048\:3066\:307f\:3066/\:5c11\:3057\:8003\:3048\:3066 -> prepend 'think\\n'\n" <>
"- If the user already wrote ultrathink/think hard/think etc. in English, do NOT add another.\n" <>
"Example: User says '\:6b7b\:306c\:6c17\:3067\:30d0\:30b0\:3092\:76f4\:305b' -> Output:\n" <>
"```mathematica\nClaudeUpdatePackage[\"PkgName\", \"ultrathink\\n\:30d0\:30b0\:3092\:4fee\:6b63\:3059\:308b\"]\n```\n" <>
"Example: User says '\:3058\:3063\:304f\:308a\:8003\:3048\:3066\:30ea\:30d5\:30a1\:30af\:30bf\:3057\:3066' -> Output:\n" <>
"```mathematica\nClaudeUpdatePackage[\"PkgName\", \"think hard\\n\:30ea\:30d5\:30a1\:30af\:30bf\:30ea\:30f3\:30b0\:3092\:5b9f\:65bd\:3059\:308b\"]\n```\n\n" <>
"TASK DECOMPOSITION FOR PACKAGE OPERATIONS (IMPORTANT):\n" <>
"When the user's instruction involves MULTIPLE INDEPENDENT changes to a package\n" <>
"(e.g., 'add function X, fix bug in Y, and refactor Z'), you SHOULD decompose it\n" <>
"into separate ClaudeUpdatePackage calls executed sequentially.\n" <>
"Each call focuses on ONE logical change, improving reliability and code quality.\n" <>
"Rules:\n" <>
"- Decompose when there are 2+ independent changes to different functions/areas.\n" <>
"- Do NOT decompose if changes are interdependent (e.g., 'add X and update Y to use X').\n" <>
"- The total number of sequential calls MUST NOT exceed $ClaudeEvalMaxDepth (" <>
ToString[$ClaudeEvalMaxDepth] <> ").\n" <>
"- If more steps are needed than the limit, group related changes together.\n" <>
"- Each ClaudeUpdatePackage call generates its own backup automatically.\n" <>
"Example: User says 'HyperbolicCA\:306emarkSize\:3092\:52d5\:7684\:306b\:3057\:3001drawTiling\:306e\:914d\:8272\:3092\:6539\:5584\:3057\:3001\:65b0\:3057\:3044exportSVG\:95a2\:6570\:3092\:8ffd\:52a0\:3057\:3066' -> Output:\n" <>
"```mathematica\n" <>
"ClaudeUpdatePackage[\"HyperbolicCA\", \"markSize \:3092\:30bb\:30eb\:30b5\:30a4\:30ba\:306b\:6bd4\:4f8b\:3059\:308b\:3088\:3046\:52d5\:7684\:306b\:5909\:66f4\:3059\:308b\"]\n" <>
"```\n" <>
"(after the first call completes and ContinueEval is pressed:)\n" <>
"```mathematica\n" <>
"ClaudeUpdatePackage[\"HyperbolicCA\", \"drawTiling \:306e\:914d\:8272\:30ed\:30b8\:30c3\:30af\:3092\:6539\:5584\:3059\:308b\"]\n" <>
"```\n" <>
"```mathematica\n" <>
"ClaudeUpdatePackage[\"HyperbolicCA\", \"\:65b0\:3057\:3044 exportSVG \:95a2\:6570\:3092\:8ffd\:52a0\:3059\:308b\"]\n" <>
"```\n\n";

(* \:30bb\:30c3\:30b7\:30e7\:30f3\:6307\:5b9a\:7248 ClaudeEval \:5185\:90e8\:5b9f\:88c5 *)
iClaudeEvalImpl[nb_NotebookObject, tag_String, task_String, imageDirs_List:{},
    autoEvaluate_:True, modelSpec_:Automatic, privSpec_:Automatic, autoPrivate_:False] :=
  Module[{step, entry, jobId, history, contextPrompt, evalCallback,
          accessLevel, availModels, useClaudeCode,
          lastEntry, cellCountAfter, notebookCtx},
    (* アクセスレベルの解決: PrivacySpec と Model の両方を考慮 *)
    accessLevel = iResolveAccessLevel[privSpec, modelSpec];
    (* 再帰深さチェック *)
    If[$iClaudeEvalCurrentDepth >= $ClaudeEvalMaxDepth,
      nbPrint[nb, "\:26a0\:fe0f ClaudeEval \:306e\:518d\:5e30\:6df1\:5ea6\:4e0a\:9650 (" <> ToString[$ClaudeEvalMaxDepth] <>
        ") \:306b\:9054\:3057\:307e\:3057\:305f\:3002\:5fc5\:8981\:306a\:3089 $ClaudeEvalMaxDepth \:3092\:5897\:3084\:3057\:3066\:304f\:3060\:3055\:3044\:3002"];
      Return[$Failed]];
    $iClaudeEvalCurrentDepth++;
    (* LLM 送信直前の精密チェック (第2層):
       再帰呼び出しでは親が既にチェック済みなので、トップレベルのみ実行 *)
    If[$iClaudeEvalCurrentDepth === 1,
      iPrecisionConfidentialCheck[nb]];
    $iCurrentSessionAttachments = NBAccess`NBHistoryGetAttachments[nb, tag];
    history = iSessionHistoryWithInherit[nb, tag];
    step    = Length[iSessionHistory[nb, tag]];

    (* ノートブックコンテキスト収集: 直近のセル出力（エラー含む）を取得 *)
    lastEntry      = If[Length[history] > 0, Last[history], <||>];
    cellCountAfter = Replace[Lookup[lastEntry, "cellCountAfter",
                       Lookup[lastEntry, "cellCount", 0]], Except[_Integer] -> 0];
    notebookCtx    = With[{r = Quiet[iCaptureNotebookContext[nb, cellCountAfter, accessLevel]]},
                       If[StringQ[r], r, ""]];

    contextPrompt = If[Length[history] > 0,
      iClaudeSysPrompt[] <>
      "\:4ee5\:4e0b\:306f Mathematica \:3067\:306e\:4f5c\:696d\:5c65\:6b74\:3067\:3059\:3002\n\n" <>
      iSessionToContext[history] <>
      If[StringQ[notebookCtx] && notebookCtx =!= "",
        "=== \:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:306e\:73fe\:5728\:306e\:72b6\:614b ===\n" <> notebookCtx, ""] <>
      iFileAccessContext[task] <>
      iPackageDocsContext[task] <>
      If[$iClaudeEvalCurrentDepth > 1,
        "=== ClaudeEval Recursion Depth: " <> ToString[$iClaudeEvalCurrentDepth] <>
        "/" <> ToString[$ClaudeEvalMaxDepth] <>
        " (remaining: " <> ToString[$ClaudeEvalMaxDepth - $iClaudeEvalCurrentDepth] <>
        "). Do NOT generate further ClaudeEval calls if remaining is 0. ===\n", ""] <>
      iAutoPrivatePrompt[autoPrivate] <>
      "=== \:65b0\:3057\:3044\:6307\:793a ===\nTask: " <> iExpandSymbolRefs[task],
      iClaudeSysPrompt[] <>
      If[StringQ[notebookCtx] && notebookCtx =!= "",
        "=== \:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:306e\:73fe\:5728\:306e\:72b6\:614b ===\n" <> notebookCtx, ""] <>
      iFileAccessContext[task] <>
      iPackageDocsContext[task] <>
      If[$iClaudeEvalCurrentDepth > 1,
        "=== ClaudeEval Recursion Depth: " <> ToString[$iClaudeEvalCurrentDepth] <>
        "/" <> ToString[$ClaudeEvalMaxDepth] <>
        " (remaining: " <> ToString[$ClaudeEvalMaxDepth - $iClaudeEvalCurrentDepth] <>
        "). Do NOT generate further ClaudeEval calls if remaining is 0. ===\n", ""] <>
      iAutoPrivatePrompt[autoPrivate] <>
      "Task: " <> iExpandSymbolRefs[task]
    ];

    entry   = <|
      "step"        -> step,
      "time"        -> AbsoluteTime[],
      "instruction" -> task,
      "fullPrompt"  -> Compress[contextPrompt],
      "cellCount"   -> NBAccess`NBCellCount[nb],
      "response"    -> "\:ff08\:51e6\:7406\:4e2d\:ff09",
      "code"        -> ""
    |>;
    iSessionAppend[nb, tag, entry];

    (* Job \:30b7\:30b9\:30c6\:30e0\:3067\:8a55\:4fa1\:30bb\:30eb\:76f4\:5f8c\:306b\:30b9\:30ed\:30c3\:30c8\:3092\:4e88\:7d04 *)
    jobId = NBAccess`NBBeginJobAtEvalCell[nb];

    (* アクセスレベルに基づいてフォールバック可能モデルを取得 *)
    availModels = If[TrueQ[$currentUseFallback],
      NBAccess`NBGetAvailableFallbackModels[accessLevel],
      {}];
    useClaudeCode = NBAccess`NBProviderCanAccess["claudecode", accessLevel];

    (* \:30b3\:30fc\:30eb\:30d0\:30c3\:30af\:3092\:5171\:901a\:5316 *)
    evalCallback = With[{nb2 = nb, stag2 = tag, st = step, jid = jobId,
          autoMark = iShouldAutoMarkConfidential[accessLevel],
          ccBefore = NBAccess`NBCellCount[nb]},
      Function[response,
        Module[{textOnly, blocks},
          (* \:30a2\:30f3\:30ab\:30fc\:306e\:76f4\:5f8c\:306b\:51fa\:529b\:3092\:914d\:7f6e *)
          NBAccess`NBJobMoveToAnchor[jid];
          (* \:30a8\:30e9\:30fc/\:5236\:9650\:30ec\:30b9\:30dd\:30f3\:30b9\:306f\:901a\:77e5\:30b9\:30bf\:30a4\:30eb\:3067\:8868\:793a\:3057\:3066\:7d42\:4e86 *)
          If[iIsAPIErrorResponse[response] || StringStartsQ[response, "Error"],
            NBAccess`NBWritePrintNotice[nb2, response, RGBColor[0.8, 0, 0]];
            NBAccess`NBEndJob[jid];
            $iClaudeEvalCurrentDepth = Max[0, $iClaudeEvalCurrentDepth - 1];
            iSessionUpdateLast[nb2, stag2, <|
              "response" -> response, "code" -> "",
              "cellCountAfter" -> NBAccess`NBCellCount[nb2]|>];
            Return[]];
          textOnly = iStripContinueEvalGuidance @ cleanMarkdown @ StringTrim @ iStripCodeBlocks[response];
          If[textOnly =!= "",
            NBAccess`NBWriteCell[nb2, iTeXMathToCell[textOnly, "Text"]]];
          blocks = iWriteResponseBlocks[nb2, response, autoEvaluate];
          If[Length[blocks] === 0,
            Module[{fallbackCode, lines},
              lines = Select[StringSplit[textOnly, "\n"], StringTrim[#] =!= "" &];
              If[Length[lines] > 0,
                fallbackCode = "Column[{\n" <>
                  StringJoin[Riffle[
                    ("  " <> ToString[#, InputForm]) & /@ lines,
                    ",\n"]] <>
                  "\n}, Spacings -> 0.5]";
                iWriteSmartCell[nb2, fallbackCode, autoEvaluate];
                blocks = {fallbackCode}
              ]
            ]];
          (* 高 AccessLevel の場合、新規セルを自動秘密マーク *)
          If[TrueQ[autoMark],
            iAutoMarkNewCellsConfidential[nb2, ccBefore]];
          (* \:30b8\:30e7\:30d6\:7d42\:4e86: \:672a\:4f7f\:7528\:30b9\:30ed\:30c3\:30c8\:3068\:30a2\:30f3\:30ab\:30fc\:3092\:524a\:9664 *)
          NBAccess`NBEndJob[jid];
          $iClaudeEvalCurrentDepth = Max[0, $iClaudeEvalCurrentDepth - 1];
          iSessionUpdateLast[nb2, stag2, <|
            "response"       -> response,
            "code"           -> StringJoin[Riffle[blocks, "\n\n"]],
            "cellCountAfter" -> NBAccess`NBCellCount[nb2]
          |>]
        ]
      ]
    ];

    If[modelSpec =!= Automatic && ListQ[modelSpec] && Length[modelSpec] >= 2,
      (* Model \:6307\:5b9a\:3042\:308a: API \:7d4c\:7531\:3067\:6307\:5b9a\:30e2\:30c7\:30eb\:3092\:76f4\:63a5\:547c\:3073\:51fa\:3057 *)
      iStartFallbackAsync[contextPrompt, nb, evalCallback,
        {modelSpec}, 1, jobId],
      (* アクセスレベルに基づくルーティング *)
      If[useClaudeCode,
        iClaudeQueryAsyncWithProgress[
          contextPrompt, evalCallback, nb, imageDirs, jobId, availModels],
        If[Length[availModels] > 0,
          iStartFallbackAsync[contextPrompt, nb, evalCallback,
            availModels, 1, jobId],
          (* どのモデルもアクセスレベルに対応不可 *)
          NBAccess`NBWriteSlot[jobId, 1,
            Cell["\[WarningSign] AccessLevel " <> ToString[accessLevel] <>
              " \:306b\:5bfe\:5fdc\:3059\:308b\:30e2\:30c7\:30eb\:304c\:3042\:308a\:307e\:305b\:3093\:3002", "Print",
              FontWeight -> Bold, FontColor -> Red, FontSize -> 11]];
          NBAccess`NBEndJob[jobId];
          $iClaudeEvalCurrentDepth = Max[0, $iClaudeEvalCurrentDepth - 1];
          iSessionUpdateLast[nb, tag, <|
            "response" -> "Error: AccessLevel " <> ToString[accessLevel] <>
              " \:306b\:5bfe\:5fdc\:3059\:308b\:30e2\:30c7\:30eb\:304c\:3042\:308a\:307e\:305b\:3093",
            "code" -> "",
            "cellCountAfter" -> NBAccess`NBCellCount[nb]|>]
        ]
      ]
    ]
  ];

(* \:30c7\:30d5\:30a9\:30eb\:30c8\:30bb\:30c3\:30b7\:30e7\:30f3\:7248 ClaudeEval\:ff08\:30bb\:30c3\:30b7\:30e7\:30f3\:3092\:8fd4\:3055\:306a\:3044\:ff09 *)
Options[ClaudeEval] = {Fallback -> False, AutoEvaluate -> True, StartTime -> Now, WebFetch -> Automatic, WebSearch -> True, RepeatInterval -> None, Model -> Automatic, PrivacySpec -> Automatic, AutoPrivate -> False};

(* StartTime \:30b9\:30b1\:30b8\:30e5\:30fc\:30ea\:30f3\:30b0\:30d8\:30eb\:30d1\:30fc:
   \:958b\:59cb\:6642\:523b\:304c\:672a\:6765\:306a\:3089 SessionSubmit + ScheduledTask \:3067\:9045\:5ef6\:5b9f\:884c\:3001
   \:904e\:53bb\:307e\:305f\:306f Now \:306a\:3089\:5373\:6642\:5b9f\:884c *)
SetAttributes[iScheduleAt, HoldFirst];
iScheduleAt[body_, startSpec_] :=
  Module[{dateObj, delaySec},
    dateObj  = Replace[startSpec, Now :> DateObject[]];
    delaySec = Quiet @ Check[
      QuantityMagnitude[DateDifference[DateObject[], dateObj, "Seconds"]],
      0];
    If[!NumericQ[delaySec] || delaySec <= 0.5,
      (* \:5373\:6642\:5b9f\:884c *)
      body,
      (* \:9045\:5ef6\:5b9f\:884c: SessionSubmit + ScheduledTask \:3067\:4e00\:56de\:3060\:3051\:5b9f\:884c *)
      Module[{intDelay = Ceiling[delaySec]},
        Print["[Schedule] ClaudeEval \:3092 " <> DateString[dateObj, {"Year","/","Month","/","Day"," ","Hour",":","Minute",":","Second"}] <>
              " \:306b\:30b9\:30b1\:30b8\:30e5\:30fc\:30eb\:3057\:307e\:3057\:305f (" <> ToString[intDelay] <> " \:79d2\:5f8c)"];
        SessionSubmit[ScheduledTask[body, {intDelay}]];
      ]
    ]
  ];

(* RepeatInterval スケジューリングヘルパー:
   指定間隔で繰り返し実行する。TaskObject を返す。
   repeatSpec:
     Quantity[n, "Hours"] など  → 無限繰り返し
     {Quantity[n, "Hours"], maxCount} → 最大 maxCount 回 *)
SetAttributes[iScheduleRepeating, HoldFirst];
iScheduleRepeating[body_, startSpec_, repeatSpec_] :=
  Module[{dateObj, delaySec, intervalSec, maxCount, intervalQ,
          counter = 0},
    dateObj = Replace[startSpec, Now :> DateObject[]];
    delaySec = Quiet @ Check[
      QuantityMagnitude[DateDifference[DateObject[], dateObj, "Seconds"]],
      0];
    If[!NumericQ[delaySec] || delaySec < 0, delaySec = 0];
    (* RepeatInterval の解析 *)
    {intervalQ, maxCount} = Replace[repeatSpec, {
      {q_, n_Integer} :> {q, n},
      q_ :> {q, Infinity}
    }];
    intervalSec = Quiet @ Check[
      Ceiling[QuantityMagnitude[UnitConvert[intervalQ, "Seconds"]]],
      $Failed];
    If[!IntegerQ[intervalSec] || intervalSec <= 0,
      Print["[Schedule] RepeatInterval の値が不正です。"];
      Return[$Failed]];
    Print["[Schedule] ClaudeEval を " <>
      If[delaySec > 0.5,
        DateString[dateObj, {"Year","/","Month","/","Day"," ","Hour",":","Minute",":","Second"}] <>
        " から",
        "今から"] <>
      " " <> ToString[intervalSec] <> " 秒ごとに" <>
      If[maxCount === Infinity, "繰り返し",
        "最大 " <> ToString[maxCount] <> " 回"] <>
      "実行します。TaskRemove[] で停止できます。"];
    If[delaySec > 0.5,
      (* 初回を遅延してから繰り返し開始 *)
      SessionSubmit[ScheduledTask[
        If[maxCount =!= Infinity,
          counter++;
          If[counter > maxCount,
            Print["[Schedule] 指定回数 (" <> ToString[maxCount] <> " 回) に達しました。"];
            TaskRemove[$CurrentTask],
            body],
          body],
        {Ceiling[delaySec], intervalSec}]],
      (* 即時開始で繰り返し *)
      SessionSubmit[ScheduledTask[
        If[maxCount =!= Infinity,
          counter++;
          If[counter > maxCount,
            Print["[Schedule] 指定回数 (" <> ToString[maxCount] <> " 回) に達しました。"];
            TaskRemove[$CurrentTask],
            body],
          body],
        intervalSec]]
    ]
  ];

(* Web 検索結果でタスクを補強 *)
iEnrichWithWebSearch[task_String] :=
  Module[{searchResult, nb = Quiet[InputNotebook[]]},
    NBAccess`NBWritePrintNotice[None,
      "[WebFetch] Web \:691c\:7d22\:4e2d\:2026", RGBColor[0.2, 0.4, 0.7]];
    searchResult = iDoWebSearch[
      "\:4ee5\:4e0b\:306e\:30bf\:30b9\:30af\:306b\:95a2\:9023\:3059\:308b\:60c5\:5831\:3092 Web \:3067\:691c\:7d22\:3057\:3066\:3001\:5177\:4f53\:7684\:306a\:30c7\:30fc\:30bf\:3092\:307e\:3068\:3081\:3066\:304f\:3060\:3055\:3044\:3002\n\n" <> task];
    If[!StringQ[searchResult] || StringStartsQ[searchResult, "Error:"],
      task,
      "=== Web \:691c\:7d22\:7d50\:679c ===\n" <> searchResult <> "\n\n=== \:30bf\:30b9\:30af ===\n" <> task]
  ];

(* 軽量プレフライト: タスクに Web 検索が有益かを Claude に判断させる *)
iNeedsWebSearch[task_String] :=
  Module[{apiKey, prompt, response},
    (* $packageDirectory 内のパッケージ名に言及するタスクは Web 検索不要 *)
    If[AnyTrue[
        Quiet @ Check[
          FileBaseName /@ FileNames["*.wl", Global`$packageDirectory],
          {}],
        StringContainsQ[task, #, IgnoreCase -> True] &],
      Return[False]];
    apiKey = Quiet[NBAccess`NBGetAPIKey["anthropic",
      PrivacySpec -> <|"AccessLevel" -> 1.0|>]];
    If[!StringQ[apiKey], Return[False]];
    prompt =
      "You are a triage assistant. Given the following Mathematica coding task, " <>
      "decide whether a web search would provide useful information that the LLM " <>
      "likely does not already know (e.g. specific API docs, recent software updates, " <>
      "niche library details, current data, product-specific shortcuts).\n" <>
      "If the task mentions updating/creating documentation for a local package, " <>
      "or mentions ClaudeUpdatePackage/ClaudeCreateDocumentation/ClaudeUpdateDocumentation, " <>
      "answer NO — these are local operations.\n" <>
      "Answer ONLY 'YES' or 'NO'. No explanation.\n\n" <>
      "Task: " <> StringTake[task, UpTo[500]];
    response = Quiet @ Check[
      iQueryAnthropicAPI[apiKey, "claude-haiku-4-5-20251001", prompt],
      "NO"];
    StringMatchQ[StringTrim[response], "YES" ~~ ___, IgnoreCase -> True]
  ];

(* WebFetch オプションの解決:
   True     -> 必ず検索
   False    -> 検索しない
   Automatic -> Claude に判断させる
   重要: WebFetch は Anthropic API 経由で課金が発生するため、
   Fallback -> True の場合のみ有効。Fallback が False なら強制的に False。 *)
iResolveWebFetchWithFallback[task_String, wfOpt_, fallbackQ_] :=
  If[!TrueQ[fallbackQ], task, iResolveWebFetch[task, wfOpt]];

iResolveWebFetch[task_String, True] := iEnrichWithWebSearch[task];
iResolveWebFetch[task_String, False] := task;
iResolveWebFetch[task_String, Automatic] :=
  Module[{},
    If[iNeedsWebSearch[task],
      NBAccess`NBWritePrintNotice[None,
        "[WebFetch] \:81ea\:52d5\:5224\:5b9a: Web \:691c\:7d22\:304c\:6709\:76ca\:3068\:5224\:65ad\:3057\:307e\:3057\:305f",
        RGBColor[0.4, 0.4, 0.6]];
      iEnrichWithWebSearch[task],
      task]
  ];

ClaudeEval[task_String, opts:OptionsPattern[]] := (
    $currentUseFallback = TrueQ[OptionValue[Fallback]];
    $iAllowReadTool = False;
    $iAllowWebSearch = TrueQ[OptionValue[WebSearch]];
  With[{nb = EvaluationNotebook[], st = OptionValue[StartTime], ae = OptionValue[AutoEvaluate],
        actualTask = iResolveWebFetchWithFallback[task, OptionValue[WebFetch], $currentUseFallback],
        ri = OptionValue[RepeatInterval],
        mdl = Replace[OptionValue[Model], Except[_List] -> Automatic],
        ps = OptionValue[PrivacySpec], ap = TrueQ[OptionValue[AutoPrivate]]},
    If[ri === None,
      iScheduleAt[
        iClaudeEvalImpl[nb, iSessionTag[], actualTask, {}, ae, mdl, ps, ap],
        st],
      iScheduleRepeating[
        iClaudeEvalImpl[nb, iSessionTag[], actualTask, {}, ae, mdl, ps, ap],
        st, ri]
    ]
  ]);

(* リスト入力版: {"指示", data, Image, ...} *)
ClaudeEval[items_List, opts:OptionsPattern[]] := (
    $currentUseFallback = TrueQ[OptionValue[Fallback]];
    $iAllowReadTool = False;
    $iAllowWebSearch = TrueQ[OptionValue[WebSearch]];
  With[{nb = EvaluationNotebook[], st = OptionValue[StartTime], ae = OptionValue[AutoEvaluate],
        wf = OptionValue[WebFetch], ri = OptionValue[RepeatInterval], mdl = OptionValue[Model],
        ps = OptionValue[PrivacySpec], ap = TrueQ[OptionValue[AutoPrivate]],
        fb = $currentUseFallback},
  Module[{norm},
    norm = iNormalizePrompt[items];
    If[ri === None,
      iScheduleAt[
        iClaudeEvalImpl[nb, iSessionTag[],
          iResolveWebFetchWithFallback[norm["text"], wf, fb],
          norm["imageDirs"], ae, mdl, ps, ap],
        st],
      iScheduleRepeating[
        iClaudeEvalImpl[nb, iSessionTag[],
          iResolveWebFetchWithFallback[norm["text"], wf, fb],
          norm["imageDirs"], ae, mdl, ps, ap],
        st, ri]
    ]
  ]]);

(* セッション指定版 ClaudeEval *)
ClaudeEval[session_Association, task_String, opts:OptionsPattern[]] := (
    $currentUseFallback = TrueQ[OptionValue[ClaudeEval, {opts}, Fallback]];
    $iAllowReadTool = False;
    $iAllowWebSearch = TrueQ[OptionValue[ClaudeEval, {opts}, WebSearch]];
  With[{st = OptionValue[ClaudeEval, {opts}, StartTime], ae = OptionValue[ClaudeEval, {opts}, AutoEvaluate],
        actualTask = iResolveWebFetchWithFallback[task, OptionValue[ClaudeEval, {opts}, WebFetch], $currentUseFallback],
        ri = OptionValue[ClaudeEval, {opts}, RepeatInterval], mdl = OptionValue[ClaudeEval, {opts}, Model],
        ps = OptionValue[ClaudeEval, {opts}, PrivacySpec], ap = TrueQ[OptionValue[ClaudeEval, {opts}, AutoPrivate]]},
    If[ri === None,
      iScheduleAt[
        iClaudeEvalImpl[session["Notebook"], session["SessionTag"], actualTask, {}, ae, mdl, ps, ap],
        st],
      iScheduleRepeating[
        iClaudeEvalImpl[session["Notebook"], session["SessionTag"], actualTask, {}, ae, mdl, ps, ap],
        st, ri]
    ]
  ]);

ClaudeEval[session_Association, items_List, opts:OptionsPattern[]] := (
    $currentUseFallback = TrueQ[OptionValue[ClaudeEval, {opts}, Fallback]];
    $iAllowReadTool = False;
    $iAllowWebSearch = TrueQ[OptionValue[ClaudeEval, {opts}, WebSearch]];
  Module[{norm = iNormalizePrompt[items], st = OptionValue[ClaudeEval, {opts}, StartTime],
          ae = OptionValue[ClaudeEval, {opts}, AutoEvaluate],
          wf = OptionValue[ClaudeEval, {opts}, WebFetch],
          ri = OptionValue[ClaudeEval, {opts}, RepeatInterval],
          mdl = OptionValue[ClaudeEval, {opts}, Model],
          ps = OptionValue[ClaudeEval, {opts}, PrivacySpec],
          ap = TrueQ[OptionValue[ClaudeEval, {opts}, AutoPrivate]],
          fb = $currentUseFallback},
    If[ri === None,
      iScheduleAt[
        iClaudeEvalImpl[session["Notebook"], session["SessionTag"],
          iResolveWebFetchWithFallback[norm["text"], wf, fb],
          norm["imageDirs"], ae, mdl, ps, ap],
        st],
      iScheduleRepeating[
        iClaudeEvalImpl[session["Notebook"], session["SessionTag"],
          iResolveWebFetchWithFallback[norm["text"], wf, fb],
          norm["imageDirs"], ae, mdl, ps, ap],
        st, ri]
    ]
  ]);

iClaudeSpecImpl[nb_NotebookObject, tag_String, task_String, imageDirs_List:{}] :=
  Module[{step, entry, jobId, history, contextPrompt},
    $iCurrentSessionAttachments = NBAccess`NBHistoryGetAttachments[nb, tag];
    history = iSessionHistoryWithInherit[nb, tag];
    step    = Length[iSessionHistory[nb, tag]];

    contextPrompt = If[Length[history] > 0,
      If[$ClaudeMDContent =!= "",
        "## Project guidelines (CLAUDE.md)\n\n" <> $ClaudeMDContent <> "\n\n---\n\n",
        ""] <>
      $claudeSpecPrefix <>
      "\:4ee5\:4e0b\:306f Mathematica \:3067\:306e\:4f5c\:696d\:5c65\:6b74\:3067\:3059\:3002\n\n" <>
      iSessionToContext[history] <>
      iFileAccessContext[task] <>
      "=== \:65b0\:3057\:3044\:6307\:793a ===\nTask: " <> iExpandSymbolRefs[task],
      If[$ClaudeMDContent =!= "",
        "## Project guidelines (CLAUDE.md)\n\n" <> $ClaudeMDContent <> "\n\n---\n\n",
        ""] <>
      $claudeSpecPrefix <> iFileAccessContext[task] <>
      "Task: " <> iExpandSymbolRefs[task]
    ];

    entry   = <|
      "step"        -> step,
      "time"        -> AbsoluteTime[],
      "instruction" -> "[Spec] " <> task,
      "fullPrompt"  -> Compress[contextPrompt],
      "cellCount"   -> NBAccess`NBCellCount[nb],
      "response"    -> "(\:51e6\:7406\:4e2d)",
      "code"        -> ""
    |>;
    iSessionAppend[nb, tag, entry];

    (* Job \:30b7\:30b9\:30c6\:30e0\:3067\:30b9\:30ed\:30c3\:30c8\:3092\:4e88\:7d04 *)
    jobId = NBAccess`NBBeginJobAtEvalCell[nb];

    iClaudeQueryAsyncWithProgress[
      contextPrompt,
      With[{nb2 = nb, stag2 = tag, jid = jobId},
        Function[response,
          Module[{specText},
            (* \:30a2\:30f3\:30ab\:30fc\:306e\:76f4\:5f8c\:306b\:4ed5\:69d8\:30bb\:30eb\:3092\:914d\:7f6e *)
            NBAccess`NBJobMoveToAnchor[jid];
            specText = cleanMarkdown @ StringTrim[response];
            NBAccess`NBWriteCell[nb2,
              Cell[specText, "Text",
                Sequence @@ $specCellOpts,
                CellTags -> {"claude-spec-output"}]];
            (* \:30b8\:30e7\:30d6\:7d42\:4e86 *)
            NBAccess`NBEndJob[jid];
            iSessionUpdateLast[nb2, stag2, <|
              "response" -> response,
              "code"     -> ""
            |>]
          ]
        ]
      ],
      nb, imageDirs, jobId
    ]
  ];

ClaudeSpec[task_String] := (
    $currentUseFallback = True;
  With[{nb = EvaluationNotebook[]},
    iPrecisionConfidentialCheck[nb];
    iClaudeSpecImpl[nb, iSessionTag[], task]
  ]);

ClaudeSpec[items_List] := (
    $currentUseFallback = True;
  With[{nb = EvaluationNotebook[]},
  Module[{norm},
    iPrecisionConfidentialCheck[nb];
    norm = iNormalizePrompt[items];
    iClaudeSpecImpl[nb, iSessionTag[], norm["text"], norm["imageDirs"]]
  ]]);

(* \:30bb\:30c3\:30b7\:30e7\:30f3\:6307\:5b9a\:7248 ContinueEval \:5185\:90e8\:5b9f\:88c5 *)
iContinueEvalImpl[nb_NotebookObject, tag_String, instruction_String,
    autoEvaluate_:True, modelSpec_:Automatic, privSpec_:Automatic, autoPrivate_:False] :=
  Module[{history, lastEntry, cellCountAfter, notebookCtx,
          contextPrompt, step, entry, anchorTag, continueCallback,
          accessLevel, availModels, useClaudeCode},
    accessLevel = iResolveAccessLevel[privSpec, modelSpec];
    (* LLM 送信直前の精密チェック (第2層) *)
    iPrecisionConfidentialCheck[nb];
    history = iSessionHistoryWithInherit[nb, tag];
    If[Length[history] === 0,
      nbPrint[nb, "\:30bb\:30c3\:30b7\:30e7\:30f3\:5c65\:6b74\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093: " <> tag];
      Return[$Failed]
    ];
    lastEntry      = Last[history];
    cellCountAfter = Replace[Lookup[lastEntry, "cellCountAfter",
                       Lookup[lastEntry, "cellCount", 0]], Except[_Integer] -> 0];
    step           = Length[iSessionHistory[nb, tag]];
    notebookCtx    = With[{r = Quiet[iCaptureNotebookContext[nb, cellCountAfter, accessLevel]]}, If[StringQ[r], r, ""]];

    (* アクセスレベルに基づいてフォールバック可能モデルを取得 *)
    availModels = If[TrueQ[$currentUseFallback],
      NBAccess`NBGetAvailableFallbackModels[accessLevel],
      {}];
    useClaudeCode = NBAccess`NBProviderCanAccess["claudecode", accessLevel];

    contextPrompt =
      iClaudeSysPrompt[] <>
      "\:4ee5\:4e0b\:306f Mathematica \:30b3\:30fc\:30c9\:958b\:767a\:306e\:4f5c\:696d\:5c65\:6b74\:3067\:3059\:3002\n\n" <>
      iSessionToContext[history] <>
      If[StringQ[notebookCtx] && notebookCtx =!= "",
        "=== \:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:306e\:73fe\:5728\:306e\:72b6\:614b ===\n" <> notebookCtx, ""] <>
      iFileAccessContext[instruction] <>
      iAutoPrivatePrompt[autoPrivate] <>
      "=== \:65b0\:3057\:3044\:6307\:793a ===\n" <> iExpandSymbolRefs[instruction] <> "\n\n" <>
      "\:76f4\:524d\:306e\:30b3\:30fc\:30c9\:3068\:5c65\:6b74\:3092\:8e0f\:307e\:3048\:3066\:3001\:4fee\:6b63\:30fb\:6539\:826f\:3057\:305f\:30b3\:30fc\:30c9\:3092\:63d0\:793a\:3057\:3066\:304f\:3060\:3055\:3044\:3002";

    entry = <|
      "step"        -> step,
      "time"        -> AbsoluteTime[],
      "instruction" -> instruction,
      "fullPrompt"  -> Compress[contextPrompt],
      "cellCount"   -> NBAccess`NBCellCount[nb],
      "response"    -> "\:ff08\:51e6\:7406\:4e2d\:ff09",
      "code"        -> ""
    |>;
    iSessionAppend[nb, tag, entry];

    anchorTag = "claude-anchor-" <> ToString[UnixTime[]] <> "-" <>
                ToString[RandomInteger[99999]];
    (* \:5b9f\:884c\:30bb\:30eb\:306e\:76f4\:5f8c\:306b\:30ab\:30fc\:30bd\:30eb\:3092\:914d\:7f6e *)
    (* NBAccess経由: EvaluationCell直後にアンカーセル挿入 *)
    NBAccess`NBWriteAnchorAfterEvalCell[nb, anchorTag];

    continueCallback = With[{nb2 = nb, stag2 = tag, tag2 = anchorTag,
          autoMark = iShouldAutoMarkConfidential[accessLevel],
          ccBefore = NBAccess`NBCellCount[nb]},
      Function[response,
        Module[{textOnly, blocks, anchors},
          Module[{anchorIdxs = NBAccess`NBCellIndicesByTag[nb2, tag2]},
            If[Length[anchorIdxs] > 0,
              NBAccess`NBMoveAfterCell[nb2, Last[anchorIdxs]]]];
          iFlushFallbackLog[nb2];
          (* \:30a8\:30e9\:30fc/\:5236\:9650\:30ec\:30b9\:30dd\:30f3\:30b9\:306f\:901a\:77e5\:30b9\:30bf\:30a4\:30eb\:3067\:8868\:793a\:3057\:3066\:7d42\:4e86 *)
          If[iIsAPIErrorResponse[response] || StringStartsQ[response, "Error"],
            NBAccess`NBWritePrintNotice[nb2, response, RGBColor[0.8, 0, 0]];
            (* \:30a2\:30f3\:30ab\:30fc\:3092\:524a\:9664 *)
            anchors = NBAccess`NBCellIndicesByTag[nb2, tag2];
            If[Length[anchors] > 0,
              NBAccess`NBDeleteCell[nb2, Last[anchors]]];
            iSessionUpdateLast[nb2, stag2, <|
              "response" -> response, "code" -> "",
              "cellCountAfter" -> NBAccess`NBCellCount[nb2]|>];
            Return[]];
          textOnly = iStripContinueEvalGuidance @ cleanMarkdown @ StringTrim @ iStripCodeBlocks[response];
          If[textOnly =!= "",
            NBAccess`NBWriteCell[nb2, iTeXMathToCell[textOnly, "Text"]]];
          blocks = iWriteResponseBlocks[nb2, response, autoEvaluate];
          If[Length[blocks] === 0,
            Module[{fallbackCode, lines},
              lines = Select[StringSplit[textOnly, "\n"], StringTrim[#] =!= "" &];
              If[Length[lines] > 0,
                fallbackCode = "Column[{\n" <>
                  StringJoin[Riffle[
                    ("  " <> ToString[#, InputForm]) & /@ lines,
                    ",\n"]] <>
                  "\n}, Spacings -> 0.5]";
                iWriteSmartCell[nb2, fallbackCode, autoEvaluate];
                blocks = {fallbackCode}
              ]
            ]];
          (* 高 AccessLevel の場合、新規セルを自動秘密マーク *)
          If[TrueQ[autoMark],
            iAutoMarkNewCellsConfidential[nb2, ccBefore]];
          NBAccess`NBDeleteCellsByTag[nb2, tag2];
          iSessionUpdateLast[nb2, stag2, <|
            "response"       -> response,
            "code"           -> StringJoin[Riffle[blocks, "\n\n"]],
            "cellCountAfter" -> NBAccess`NBCellCount[nb2]
          |>]
        ]
      ]
    ];

    If[modelSpec =!= Automatic && ListQ[modelSpec] && Length[modelSpec] >= 2,
      (* Model \:6307\:5b9a\:3042\:308a: API \:7d4c\:7531\:3067\:6307\:5b9a\:30e2\:30c7\:30eb\:3092\:76f4\:63a5\:547c\:3073\:51fa\:3057 *)
      iStartFallbackAsync[contextPrompt, nb, continueCallback, {modelSpec}, 1, ""],
      (* アクセスレベルに基づくルーティング *)
      If[useClaudeCode,
        iClaudeQueryAsyncWithProgress[contextPrompt, continueCallback, nb, {}, "", availModels],
        If[Length[availModels] > 0,
          iStartFallbackAsync[contextPrompt, nb, continueCallback, availModels, 1, ""],
          NBAccess`NBWritePrintNotice[nb,
            "\[WarningSign] AccessLevel " <> ToString[accessLevel] <>
            " \:306b\:5bfe\:5fdc\:3059\:308b\:30e2\:30c7\:30eb\:304c\:3042\:308a\:307e\:305b\:3093\:3002", Red];
          NBAccess`NBDeleteCellsByTag[nb, anchorTag]
        ]
      ]
    ]
  ];

(* \:30bb\:30c3\:30b7\:30e7\:30f3\:6307\:5b9a\:7248 *)
Options[ContinueEval] = {Fallback -> False, AutoEvaluate -> True, StartTime -> Now, WebSearch -> True, Model -> Automatic, PrivacySpec -> Automatic, AutoPrivate -> False};

ContinueEval[session_Association, instruction_String:"\:30a8\:30e9\:30fc\:3092\:4fee\:6b63\:3057\:3066\:304f\:3060\:3055\:3044",
    opts:OptionsPattern[]] := (
    $currentUseFallback = TrueQ[OptionValue[Fallback]];
    $iAllowWebSearch = TrueQ[OptionValue[WebSearch]];
  With[{st = OptionValue[StartTime], ae = OptionValue[AutoEvaluate], mdl = OptionValue[Model],
        ps = OptionValue[PrivacySpec], ap = TrueQ[OptionValue[AutoPrivate]]},
    iScheduleAt[
      iContinueEvalImpl[session["Notebook"], session["SessionTag"], instruction, ae, mdl, ps, ap],
      st
    ]
  ]);

ContinueEval[instruction_String, opts:OptionsPattern[]] := (
    $currentUseFallback = TrueQ[OptionValue[ContinueEval, {opts}, Fallback]];
    $iAllowReadTool = False;
    $iAllowWebSearch = TrueQ[OptionValue[ContinueEval, {opts}, WebSearch]];
  With[{nb = EvaluationNotebook[], st = OptionValue[ContinueEval, {opts}, StartTime],
        ae = OptionValue[ContinueEval, {opts}, AutoEvaluate],
        mdl = OptionValue[ContinueEval, {opts}, Model],
        ps = OptionValue[ContinueEval, {opts}, PrivacySpec],
        ap = TrueQ[OptionValue[ContinueEval, {opts}, AutoPrivate]]},
    iScheduleAt[
      iContinueEvalImpl[nb, iSessionTag[], instruction, ae, mdl, ps, ap],
      st
    ]
  ]);

ContinueEval[session_Association, instruction_String:"\:30a8\:30e9\:30fc\:3092\:4fee\:6b63\:3057\:3066\:304f\:3060\:3055\:3044",
    opts:OptionsPattern[]] := (
    $currentUseFallback = TrueQ[OptionValue[Fallback]];
    $iAllowReadTool = False;
    $iAllowWebSearch = TrueQ[OptionValue[WebSearch]];
  With[{st = OptionValue[StartTime], ae = OptionValue[AutoEvaluate], mdl = OptionValue[Model],
        ps = OptionValue[PrivacySpec], ap = TrueQ[OptionValue[AutoPrivate]]},
    iScheduleAt[
      iContinueEvalImpl[session["Notebook"], session["SessionTag"], instruction, ae, mdl, ps, ap],
      st
    ]
  ]);

iCaptureRecentOutput[nb_NotebookObject, afterCellCount_Integer] :=
  Module[{ctx},
    ctx = Quiet @ Check[iCaptureNotebookContext[nb, afterCellCount], ""];
    If[StringQ[ctx], StringTake[ctx, UpTo[3000]], ""]
  ];

(* --- 内部ヘルパー: 直前の更新セッション情報をバックアップから復元 --- *)
iRecoverLastUpdateFromBackup[packageName_String] :=
  Module[{bdir, dirs, lastDir, promptFile, responseFile, promptText, responseText, instr},
    bdir = backupDir[packageName];
    If[!DirectoryQ[bdir], Return[None]];
    dirs = Sort[Select[FileNames["*", bdir], DirectoryQ]];
    dirs = Select[dirs, !StringStartsQ[FileNameTake[#], "pre_"] &];
    If[Length[dirs] === 0, Return[None]];
    lastDir = Last[dirs];
    promptFile = FileNameJoin[{lastDir, "prompt.txt"}];
    responseFile = FileNameJoin[{lastDir, "response.txt"}];
    If[!FileExistsQ[promptFile], Return[None]];
    promptText = Import[promptFile, "Text"];
    responseText = If[FileExistsQ[responseFile], Import[responseFile, "Text"], ""];
    (* INSTRUCTION: 以降を元のプロンプトとして抽出 *)
    instr = StringTrim[Last[StringSplit[promptText, "INSTRUCTION: ", 2], ""]];
    (* CURRENT FUNCTIONS: 以降は除去 *)
    instr = First[StringSplit[instr, "\n\nCURRENT FUNCTIONS:", 2], instr];
    instr = First[StringSplit[instr, "\n\nATTACHMENTS", 2], instr];
    If[instr === "", instr = StringTake[promptText, UpTo[500]]];
    <|
      "packageName" -> packageName,
      "prompt" -> StringTrim[instr],
      "response" -> responseText,
      "sessionDir" -> lastDir
    |>
  ];

(* --- 継続プロンプトの構築 --- *)
iBuildContinueUpdatePrompt[originalPrompt_, instruction_String, response_String,
    notebookOutput_String] :=
  Module[{origText, resultSummary, nbOut},
    origText = If[StringQ[originalPrompt], originalPrompt,
      If[ListQ[originalPrompt],
        StringJoin[Select[originalPrompt, StringQ]],
        ToString[originalPrompt]]];
    (* response の末尾説明部分（===END_FUNCTIONS=== 以降）を要約として使用 *)
    resultSummary = Module[{afterEnd},
      afterEnd = Last[StringSplit[response, "===END_FUNCTIONS===", 2], ""];
      If[afterEnd === "",
        afterEnd = Last[StringSplit[response, "===END_PACKAGE===", 2], ""]];
      afterEnd = StringTrim[afterEnd];
      If[afterEnd =!= "",
        StringTake[afterEnd, UpTo[1500]],
        StringTake[StringTrim[response], UpTo[800]]
      ]
    ];
    nbOut = StringTrim[notebookOutput];

    "前回のアップデート指示とその結果を踏まえて、パッケージを修正してください。\n\n" <>
    "=== 前回の指示 ===\n" <> StringTake[origText, UpTo[2000]] <> "\n\n" <>
    "=== 前回の結果 (Claude の応答要約) ===\n" <> resultSummary <> "\n\n" <>
    If[nbOut =!= "",
      "=== 前回の実行後のノートブック出力 (エラーメッセージ等) ===\n" <> nbOut <> "\n\n",
      ""] <>
    "=== 今回の指示 ===\n" <> instruction <> "\n\n" <>
    "上記の前回の変更内容と実行結果を把握した上で、今回の指示に従って修正してください。\n" <>
    "前回正しく変更できた部分はそのまま維持し、問題のある部分のみ修正してください。"
  ];

(* --- ContinueUpdate 本体 --- *)

Options[ContinueUpdate] = {Fallback -> False, StartTime -> Now, "UpdateApiMd" -> False};

(* ContinueUpdate["pkg", "instruction", opts] *)
ContinueUpdate[packageName_String, instruction_String, opts:OptionsPattern[]] :=
  Module[{info, nb, origPrompt, response, nbOutput, newPrompt},
    $currentUseFallback = TrueQ[OptionValue[Fallback]];
    nb = EvaluationNotebook[];
    (* $iLastUpdateInfo が同じパッケージを指していればそこから取得 *)
    info = If[AssociationQ[$iLastUpdateInfo] &&
              Lookup[$iLastUpdateInfo, "packageName", ""] === packageName &&
              KeyExistsQ[$iLastUpdateInfo, "response"],
      $iLastUpdateInfo,
      iRecoverLastUpdateFromBackup[packageName]
    ];
    If[info === None || !AssociationQ[info],
      nbPrint[nb, "\:30a8\:30e9\:30fc: " <> packageName <> " \:306e\:76f4\:524d\:306e ClaudeUpdatePackage \:5c65\:6b74\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093\:3002"];
      Return[$Failed]];
    origPrompt = Lookup[info, "prompt", ""];
    response   = Lookup[info, "response", ""];
    nbOutput   = iCaptureRecentOutput[nb,
      Replace[Lookup[info, "cellCountAfter", 0], Except[_Integer] -> 0]];
    newPrompt  = iBuildContinueUpdatePrompt[origPrompt, instruction, response, nbOutput];
    $iContinueUpdateFlag = True;
    ClaudeUpdatePackage[packageName, newPrompt,
      Fallback -> TrueQ[OptionValue[Fallback]],
      "UpdateApiMd" -> TrueQ[OptionValue["UpdateApiMd"]],
      StartTime -> OptionValue[StartTime]]
  ];

(* ContinueUpdate["instruction", opts] — パッケージ名は直前の呼び出しから自動取得 *)
ContinueUpdate[instruction_String, opts:OptionsPattern[]] :=
  Module[{pkgName},
    pkgName = If[AssociationQ[$iLastUpdateInfo],
      Lookup[$iLastUpdateInfo, "packageName", ""], ""];
    If[pkgName === "",
      With[{nb = EvaluationNotebook[]},
        nbPrint[nb, "\:30a8\:30e9\:30fc: \:76f4\:524d\:306e ClaudeUpdatePackage \:306e\:60c5\:5831\:304c\:3042\:308a\:307e\:305b\:3093\:3002\n" <>
          "ContinueUpdate[\"packageName\", \"instruction\"] \:3067\:30d1\:30c3\:30b1\:30fc\:30b8\:540d\:3092\:6307\:5b9a\:3057\:3066\:304f\:3060\:3055\:3044\:3002"];
        Return[$Failed]]];
    ContinueUpdate[pkgName, instruction, opts]
  ];

(* ContinueUpdate[] — 引数なし: デフォルト指示で継続 *)
ContinueUpdate[opts:OptionsPattern[]] :=
  ContinueUpdate[
    "\:524d\:56de\:306e\:5909\:66f4\:3067\:767a\:751f\:3057\:305f\:30d0\:30b0\:3084\:554f\:984c\:3092\:4fee\:6b63\:3057\:3066\:304f\:3060\:3055\:3044\:3002\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:306e\:51fa\:529b\:7d50\:679c\:3092\:78ba\:8a8d\:3057\:3001\:30a8\:30e9\:30fc\:3084\:4e0d\:5177\:5408\:304c\:3042\:308c\:3070\:4fee\:6b63\:3057\:3066\:304f\:3060\:3055\:3044\:3002",
    opts];

(* ============================================================
   \:30c7\:30d0\:30c3\:30b0\:30fb\:30ec\:30d3\:30e5\:30fc\:652f\:63f4
   ============================================================ *)

(* \:30d5\:30a1\:30a4\:30eb\:30d1\:30b9\:307e\:305f\:306f\:30b3\:30fc\:30c9\:6587\:5b57\:5217\:3092\:53d7\:3051\:53d6\:308a\:30b3\:30fc\:30c9\:6587\:5b57\:5217\:3092\:8fd4\:3059\:5185\:90e8\:95a2\:6570 *)
(* \:512a\:5148\:9806\:4f4d: 1.\:7d76\:5bfe\:30d1\:30b9, 2.$packageDirectory\:76f8\:5bfe, 3.\:6587\:5b57\:5217\:305d\:306e\:307e\:307e *)
resolveCode[s_String] := Module[{resolved},
  Which[
    FileExistsQ[s],
      Import[s, "Text"],
    FileExistsQ[FileNameJoin[{Global`$packageDirectory, s}]],
      Import[FileNameJoin[{Global`$packageDirectory, s}], "Text"],
    True,
      s
  ]
];

ClaudeDebug[codeOrFile_String, errorMsg_String] := With[{nb = EvaluationNotebook[]},
  Module[{code},
    nbPrint[nb, "Claude \:306b\:30c7\:30d0\:30c3\:30b0\:3092\:4f9d\:983c\:4e2d..."];
    code = resolveCode[codeOrFile];
    iClaudeQueryAsyncWithProgress[
      "\:4ee5\:4e0b\:306e Mathematica \:30b3\:30fc\:30c9\:3092\:30c7\:30d0\:30c3\:30b0\:3057\:3066\:304f\:3060\:3055\:3044\:3002\n\n" <>
      "\:30b3\:30fc\:30c9:\n```mathematica\n" <> code <> "\n```\n\n" <>
      "\:30a8\:30e9\:30fc\:30e1\:30c3\:30bb\:30fc\:30b8:\n" <> errorMsg <>
      "\n\n\:30a8\:30e9\:30fc\:306e\:539f\:56e0\:3092\:8aac\:660e\:3057\:3001\:4fee\:6b63\:6e08\:307f\:306e\:30b3\:30fc\:30c9\:3092\:63d0\:793a\:3057\:3066\:304f\:3060\:3055\:3044\:3002\n" <>
      "\:56de\:7b54\:306f\:5fc5\:305a\:65e5\:672c\:8a9e\:3067\:8a18\:8ff0\:3057\:3066\:304f\:3060\:3055\:3044\:3002",
      Function[response, nbPrint[nb, response]], nb]
  ]
];

ClaudeReview[codeOrFile_String] := With[{nb = EvaluationNotebook[]},
  Module[{code},
    code = resolveCode[codeOrFile];
    If[StringLength[code] > 30000,
      nbPrint[nb, "\:30d5\:30a1\:30a4\:30eb\:304c\:5927\:304d\:3044\:305f\:3081 (" <> ToString[StringLength[code]] <>
        " \:6587\:5b57)\:3001\:30c1\:30e3\:30f3\:30af\:5206\:5272\:30ec\:30d3\:30e5\:30fc\:3092\:884c\:3044\:307e\:3059\:3002"];
      iClaudeReviewChunkedAsync[nb, StringPartition[code, UpTo[25000]], codeOrFile, 1, {}],
      nbPrint[nb, "Claude \:306b\:30ec\:30d3\:30e5\:30fc\:3092\:4f9d\:983c\:4e2d..."];
      iClaudeQueryAsyncWithProgress[
        "\:4ee5\:4e0b\:306e Mathematica \:30b3\:30fc\:30c9\:3092\:30ec\:30d3\:30e5\:30fc\:3057\:3066\:304f\:3060\:3055\:3044\:3002\n" <>
        "\:30d0\:30b0\:3001\:975e\:52b9\:7387\:306a\:7b87\:6240\:3092\:6307\:6458\:3057\:3001Wolfram Language \:3089\:3057\:3044\:3088\:308a\:826f\:3044\:66f8\:304d\:65b9\:3092\:63d0\:6848\:3057\:3066\:304f\:3060\:3055\:3044\:3002\n" <>
        "\:56de\:7b54\:306f\:5fc5\:305a\:65e5\:672c\:8a9e\:3067\:8a18\:8ff0\:3057\:3066\:304f\:3060\:3055\:3044\:3002\n\n" <>
        "```mathematica\n" <> code <> "\n```",
        Function[response, nbPrint[nb, response]], nb]
    ]
  ]
];

ClaudeReviewChunked[codeOrFile_String] := With[{nb = EvaluationNotebook[]},
  Module[{code, chunks},
    code   = resolveCode[codeOrFile];
    chunks = StringPartition[code, UpTo[25000]];
    nbPrint[nb, ToString[Length[chunks]] <> " \:30c1\:30e3\:30f3\:30af\:306b\:5206\:5272\:3057\:3066\:30ec\:30d3\:30e5\:30fc\:3057\:307e\:3059\:3002"];
    iClaudeReviewChunkedAsync[nb, chunks, codeOrFile, 1, {}]
  ]
];

iClaudeReviewChunkedAsync[nb_, chunks_, label_, i_, results_] :=
  If[i > Length[chunks],
    nbPrint[nb, "\:5168\:4f53\:30b5\:30de\:30ea\:30fc\:3092\:751f\:6210\:4e2d..."];
    iClaudeQueryAsyncWithProgress[
      "\:4ee5\:4e0b\:306f Mathematica \:30d1\:30c3\:30b1\:30fc\:30b8\:300c" <> label <> "\:300d\:306e\:5404\:30c1\:30e3\:30f3\:30af\:306e\:30ec\:30d3\:30e5\:30fc\:7d50\:679c\:3067\:3059\:3002\n" <>
      "\:5168\:4f53\:3092\:901a\:3058\:305f\:4e3b\:8981\:306a\:554f\:984c\:70b9\:3068\:6539\:5584\:63d0\:6848\:3092\:65e5\:672c\:8a9e\:3067\:7c21\:6f54\:306b\:307e\:3068\:3081\:3066\:304f\:3060\:3055\:3044\:3002\n\n" <>
      StringJoin[MapIndexed[
        "\:3010\:30c1\:30e3\:30f3\:30af " <> ToString[First[#2]] <> "\:3011\n" <> #1 <> "\n\n" &, results]],
      Function[response, nbPrint[nb, "=== \:5168\:4f53\:30b5\:30de\:30ea\:30fc ===\n\n" <> response]],
      nb],
    nbPrint[nb, "\:30c1\:30e3\:30f3\:30af " <> ToString[i] <> "/" <> ToString[Length[chunks]] <> " \:3092\:30ec\:30d3\:30e5\:30fc\:4e2d..."];
    iClaudeQueryAsyncWithProgress[
      "\:4ee5\:4e0b\:306f Mathematica \:30d1\:30c3\:30b1\:30fc\:30b8\:300c" <> label <> "\:300d\:306e\:7b2c " <>
      ToString[i] <> "/" <> ToString[Length[chunks]] <> " \:90e8\:5206\:3067\:3059\:3002\n" <>
      "\:30d0\:30b0\:3001\:975e\:52b9\:7387\:306a\:7b87\:6240\:3092\:6307\:6458\:3057\:3001Wolfram Language \:3089\:3057\:3044\:3088\:308a\:826f\:3044\:66f8\:304d\:65b9\:3092\:63d0\:6848\:3057\:3066\:304f\:3060\:3055\:3044\:3002\n" <>
      "\:56de\:7b54\:306f\:5fc5\:305a\:65e5\:672c\:8a9e\:3067\:8a18\:8ff0\:3057\:3066\:304f\:3060\:3055\:3044\:3002\n\n" <>
      "```mathematica\n" <> chunks[[i]] <> "\n```",
      With[{nb2=nb, ch=chunks, lb=label, ni=i, nr=results},
        Function[response,
          nbPrint[nb2, "=== \:30c1\:30e3\:30f3\:30af " <> ToString[ni] <> "/" <>
            ToString[Length[ch]] <> " \:306e\:7d50\:679c ===\n\n" <> response];
          iClaudeReviewChunkedAsync[nb2, ch, lb, ni+1, Append[nr, response]]
        ]
      ],
      nb];
    $ClaudeModel = savedModel;
  ];

(* ============================================================
   \:30d1\:30c3\:30b1\:30fc\:30b8\:7ba1\:7406\:ff1a\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:30fb\:66f4\:65b0\:30fb\:30ea\:30b9\:30c8\:30a2\:30fb\:5c65\:6b74
   ============================================================ *)

(* FileQ 互換ヘルパー: FileQ は Mathematica 14.1+ のため、
   古いバージョンでは未定義。全バージョンで動作する代替を定義。 *)
iFileQ[path_String] := FileExistsQ[path] && !DirectoryQ[path];
iFileQ[_] := False;

(* \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:306e\:30d1\:30b9\:3092\:8fd4\:3059 *)
backupDir[packageName_String] :=
  FileNameJoin[{Global`$packageDirectory, packageName <> "_info", "history"}];

(* ============================================================
   差分ベースバックアップシステム（汎用）
   .wl / .md 等のテキストファイルを SequenceAlignment ベースの
   差分で保存し、バックアップ容量を削減する。
   
   保存形式:
   - filename.cz        Compress[全文] ベースライン
   - filename.cdiff      Compress[{前回Dir名, SequenceAlignment結果}] 差分
   - filename.unchanged  前回Dir名（内容同一、1ホップ解決保証）
   - filename            レガシー生ファイル（後方互換読み取り対応）
   ============================================================ *)

$iBackupBaselineInterval = 10;

(* --- 汎用保存: ファイルパス指定 --- *)
(* srcFilePath のテキストを読み込み、差分形式で histDir に保存する。 *)
iSaveBackupFile[histDir_String, srcFilePath_String, packageName_String,
    fullBaseline:(True|False):False] :=
  Module[{content},
    content = Quiet @ Check[Import[srcFilePath, "Text"], ""];
    If[!StringQ[content] || content === "", Return[$Failed]];
    iSaveBackupFileContent[histDir, FileNameTake[srcFilePath], content, packageName, fullBaseline]
  ];

(* --- 汎用保存: コンテンツ直接指定 --- *)
(* テキスト content を fileName として histDir に保存。
   前回バックアップと比較し baseline / diff / unchanged を自動選択。 *)
iSaveBackupFileContent[histDir_String, fileName_String, content_String,
    packageName_String, fullBaseline:(True|False):False] :=
  Module[{czPath, cdiffPath, unchangedPath, prevDir, prevContent,
          alignment, diffData, backupCount},
    czPath = FileNameJoin[{histDir, fileName <> ".cz"}];
    cdiffPath = FileNameJoin[{histDir, fileName <> ".cdiff"}];
    unchangedPath = FileNameJoin[{histDir, fileName <> ".unchanged"}];
    (* 強制ベースライン *)
    If[fullBaseline,
      Export[czPath, Compress[content], "String"];
      Return[czPath]];
    (* 前回バックアップを検索 *)
    prevDir = iFindPreviousBackupWithFile[histDir, fileName, packageName];
    If[!StringQ[prevDir],
      Export[czPath, Compress[content], "String"];
      Return[czPath]];
    prevContent = iLoadBackupFile[prevDir, fileName, packageName];
    If[!StringQ[prevContent],
      Export[czPath, Compress[content], "String"];
      Return[czPath]];
    (* 内容同一 → .unchanged (1ホップ解決: .unchanged チェーンを辿らない) *)
    If[content === prevContent,
      Module[{prevUnchangedPath, targetDirName},
        prevUnchangedPath = FileNameJoin[{prevDir, fileName <> ".unchanged"}];
        targetDirName = If[FileExistsQ[prevUnchangedPath],
          StringTrim[Quiet @ Check[Import[prevUnchangedPath, "String"], ""]],
          ""];
        If[targetDirName === "", targetDirName = FileNameTake[prevDir, -1]];
        Export[unchangedPath, targetDirName, "String"]];
      Return[unchangedPath]];
    (* ベースライン間隔チェック *)
    backupCount = Length[FileNames["*_documentupdate", backupDir[packageName]]] +
                  Length[FileNames["pre_*", backupDir[packageName]]];
    If[Mod[backupCount, $iBackupBaselineInterval] === 0,
      Export[czPath, Compress[content], "String"];
      Return[czPath]];
    (* 差分計算 *)
    alignment = Quiet @ Check[
      SequenceAlignment[
        StringSplit[prevContent, "\n"],
        StringSplit[content, "\n"]],
      $Failed];
    If[alignment === $Failed,
      Export[czPath, Compress[content], "String"];
      Return[czPath]];
    diffData = {FileNameTake[prevDir, -1], alignment};
    Export[cdiffPath, Compress[diffData], "String"];
    cdiffPath
  ];

(* --- 汎用読み込み --- *)
(* バックアップディレクトリから任意のファイルを復元する。
   生ファイル / .cz / .cdiff / .unchanged すべてに対応。 *)
iLoadBackupFile[dir_String, fileName_String, packageName_String] :=
  Module[{rawPath, czPath, cdiffPath, unchangedPath},
    rawPath = FileNameJoin[{dir, fileName}];
    czPath = FileNameJoin[{dir, fileName <> ".cz"}];
    cdiffPath = FileNameJoin[{dir, fileName <> ".cdiff"}];
    unchangedPath = FileNameJoin[{dir, fileName <> ".unchanged"}];
    Which[
      FileExistsQ[rawPath],
        Quiet @ Check[Import[rawPath, "Text"], $Failed],
      FileExistsQ[czPath],
        Quiet @ Check[Uncompress[Import[czPath, "String"]], $Failed],
      FileExistsQ[unchangedPath],
        Module[{targetDirName, targetDir},
          targetDirName = StringTrim[Quiet @ Check[Import[unchangedPath, "String"], ""]];
          targetDir = FileNameJoin[{backupDir[packageName], targetDirName}];
          If[DirectoryQ[targetDir],
            iLoadBackupFile[targetDir, fileName, packageName],
            $Failed]],
      FileExistsQ[cdiffPath],
        iReconstructFileFromChain[dir, fileName, packageName, 0],
      True, $Failed
    ]
  ];

(* --- 前回バックアップ検索 --- *)
(* histDir より前のバックアップで fileName を持つ最新ディレクトリを返す。 *)
iFindPreviousBackupWithFile[histDir_String, fileName_String, packageName_String] :=
  Module[{bdir, allDirs, histName, preceding},
    bdir = backupDir[packageName];
    If[!DirectoryQ[bdir], Return[$Failed]];
    histName = FileNameTake[histDir, -1];
    allDirs = SortBy[Select[FileNames["*", bdir, {1}], DirectoryQ],
      FileNameTake[#, -1] &];
    preceding = Select[allDirs, FileNameTake[#, -1] < histName &];
    If[Length[preceding] === 0, Return[$Failed]];
    Do[
      If[FileExistsQ[FileNameJoin[{d, fileName}]] ||
         FileExistsQ[FileNameJoin[{d, fileName <> ".cz"}]] ||
         FileExistsQ[FileNameJoin[{d, fileName <> ".cdiff"}]] ||
         FileExistsQ[FileNameJoin[{d, fileName <> ".unchanged"}]],
        Return[d, Do]],
      {d, Reverse[preceding]}];
    $Failed
  ];

(* --- 差分チェーン復元 --- *)
iReconstructFileFromChain[targetDir_String, fileName_String,
    packageName_String, depth_Integer] :=
  Module[{cdiffPath, compressed, diffData, prevDirName, alignment,
          bdir, prevDir, prevContent, newLines},
    If[depth > 50, Return[$Failed]];
    cdiffPath = FileNameJoin[{targetDir, fileName <> ".cdiff"}];
    If[!FileExistsQ[cdiffPath], Return[$Failed]];
    compressed = Quiet @ Check[Import[cdiffPath, "String"], ""];
    If[!StringQ[compressed] || compressed === "", Return[$Failed]];
    diffData = Quiet @ Check[Uncompress[compressed], $Failed];
    If[!MatchQ[diffData, {_String, _List}], Return[$Failed]];
    {prevDirName, alignment} = diffData;
    bdir = backupDir[packageName];
    prevDir = FileNameJoin[{bdir, prevDirName}];
    If[!DirectoryQ[prevDir], Return[$Failed]];
    (* 前回コンテンツ取得: .unchanged は1ホップで解決するため深度を消費しない *)
    prevContent = Which[
      FileExistsQ[FileNameJoin[{prevDir, fileName}]],
        Quiet @ Check[Import[FileNameJoin[{prevDir, fileName}], "Text"], $Failed],
      FileExistsQ[FileNameJoin[{prevDir, fileName <> ".cz"}]],
        Quiet @ Check[Uncompress[Import[FileNameJoin[{prevDir, fileName <> ".cz"}], "String"]], $Failed],
      FileExistsQ[FileNameJoin[{prevDir, fileName <> ".unchanged"}]],
        Module[{uTarget, uDir},
          uTarget = StringTrim[Quiet @ Check[
            Import[FileNameJoin[{prevDir, fileName <> ".unchanged"}], "String"], ""]];
          uDir = FileNameJoin[{bdir, uTarget}];
          If[DirectoryQ[uDir], iLoadBackupFile[uDir, fileName, packageName], $Failed]],
      FileExistsQ[FileNameJoin[{prevDir, fileName <> ".cdiff"}]],
        iReconstructFileFromChain[prevDir, fileName, packageName, depth + 1],
      True, $Failed
    ];
    If[!StringQ[prevContent], Return[$Failed]];
    newLines = iApplyAlignment[alignment];
    If[newLines === $Failed, Return[$Failed]];
    StringRiffle[newLines, "\n"]
  ];

(* SequenceAlignment → ターゲット側テキスト復元 *)
iApplyAlignment[alignment_List] :=
  Quiet @ Check[
    Flatten[
      Map[
        If[MatchQ[#, {_List, _List}], #[[2]], #] &,
        alignment]],
    $Failed];

(* --- バックアップディレクトリから復元可能なファイル名一覧 --- *)
(* 指定拡張子パターンのファイルを生/.cz/.cdiff/.unchanged から検出 *)
iListRestorableFiles[dir_String, extPattern_String] :=
  Module[{allFiles, stripSuffix},
    allFiles = FileNameTake /@ Select[FileNames["*", dir], iFileQ];
    stripSuffix[s_] := StringReplace[s,
      (".cz" | ".cdiff" | ".unchanged") ~~ EndOfString -> ""];
    DeleteDuplicates @ Select[
      stripSuffix /@ allFiles,
      StringMatchQ[#, __ ~~ extPattern] &]
  ];

(* --- .wl 専用ラッパー（後方互換） --- *)
iSaveBackupWl[histDir_String, srcFile_String, packageName_String,
    fullBaseline:(True|False):False] :=
  iSaveBackupFile[histDir, srcFile, packageName, fullBaseline];

iLoadBackupWl[dir_String, packageName_String] :=
  iLoadBackupFile[dir, packageName <> ".wl", packageName];

iFindPreviousBackupWithWl[histDir_String, packageName_String] :=
  iFindPreviousBackupWithFile[histDir, packageName <> ".wl", packageName];

(* _info サブディレクトリ *)
iInfoDir[packageName_String] :=
  FileNameJoin[{Global`$packageDirectory, packageName <> "_info"}];
iDesignDir[packageName_String] :=
  FileNameJoin[{iInfoDir[packageName], "design"}];
iReferencesDir[packageName_String] :=
  FileNameJoin[{iInfoDir[packageName], "references"}];

(* パッケージの references ディレクトリを $ClaudeAccessibleDirs に追加 *)
iEnsureReferencesAccessible[packageName_String] :=
  Module[{refDir},
    refDir = iReferencesDir[packageName];
    If[DirectoryQ[refDir],
      $ClaudeAccessibleDirs = DeleteDuplicates[
        Append[If[ListQ[$ClaudeAccessibleDirs], $ClaudeAccessibleDirs, {}],
          refDir]]]];

(* ============================================================
   ドキュメントオプション永続化: Demos/References/Disclaimer/Acknowledgments/License を
   _info/references/doc_options.json に保存し、次回の
   ClaudeCreateDocumentation / ClaudeUpdateDocumentation で自動復元する。
   ============================================================ *)

(* パッケージ別 Doc 状態の読み出しヘルパー *)
iDocGet[packageName_String, key_String] :=
  Module[{state},
    state = Lookup[$iDocState, packageName, <||>];
    If[!AssociationQ[state], state = <||>];
    Lookup[state, key, If[key === "License" || key === "GlobalInstruction", "", {}]]
  ];

(* パッケージ別 Doc 状態の初期化。
   エントリポイント (ClaudeCreate/UpdateDocumentation) で呼ぶ。 *)
iDocInitState[packageName_String, refs_List, demos_List,
    disclaimer_List, acks_List, license_String, instruction_String:"",
    explicitDemosOrRefs_:False] :=
  ($iDocState[packageName] = <|
    "References" -> refs, "Demos" -> demos,
    "Disclaimer" -> disclaimer, "Acknowledgments" -> acks,
    "License" -> license, "GlobalInstruction" -> instruction,
    "ExplicitDemosOrRefs" -> explicitDemosOrRefs
  |>);

iDocOptionsPath[packageName_String] :=
  FileNameJoin[{iReferencesDir[packageName], "doc_options.json"}];

(* 現在の $iDoc* 変数を JSON に保存。
   既存ファイルが存在する場合、空でない値のみ上書きする（read-modify-write）。
   これにより、非同期コールバック中に $iDoc* がリセットされても
   既存の保存値が破壊されない。 *)
iSaveDocOptions[packageName_String] :=
  Module[{path, existing, data, refDir, merged},
    refDir = iReferencesDir[packageName];
    If[!DirectoryQ[refDir],
      Quiet @ CreateDirectory[refDir, CreateIntermediateDirectories -> True]];
    path = iDocOptionsPath[packageName];
    (* 既存ファイルを読み込む *)
    existing = If[FileExistsQ[path],
      Quiet @ Check[Import[path, "RawJSON"], <||>], <||>];
    If[!AssociationQ[existing], existing = <||>];
    (* $iDocState[packageName] から値を取得 *)
    data = <|
      "References" -> Replace[iDocGet[packageName, "References"], Except[_List] -> {}],
      "Demos" -> Replace[iDocGet[packageName, "Demos"], Except[_List] -> {}],
      "Disclaimer" -> Replace[iDocGet[packageName, "Disclaimer"], Except[_List] -> {}],
      "Acknowledgments" -> Replace[iDocGet[packageName, "Acknowledgments"], Except[_List] -> {}],
      "License" -> Replace[iDocGet[packageName, "License"], Except[_String] -> ""]
    |>;
    (* マージ: 新しい値が空でなければ採用、空なら既存値を保持 *)
    merged = <|
      "References" -> If[Length[data["References"]] > 0,
        data["References"],
        Replace[Lookup[existing, "References", {}], Except[_List] -> {}]],
      "Demos" -> If[Length[data["Demos"]] > 0,
        data["Demos"],
        Replace[Lookup[existing, "Demos", {}], Except[_List] -> {}]],
      "Disclaimer" -> If[Length[data["Disclaimer"]] > 0,
        data["Disclaimer"],
        Replace[Lookup[existing, "Disclaimer", {}], Except[_List] -> {}]],
      "Acknowledgments" -> If[Length[data["Acknowledgments"]] > 0,
        data["Acknowledgments"],
        Replace[Lookup[existing, "Acknowledgments", {}], Except[_List] -> {}]],
      "License" -> If[StringQ[data["License"]] && data["License"] =!= "",
        data["License"],
        Replace[Lookup[existing, "License", ""], Except[_String] -> ""]]
    |>;
    Quiet @ Export[path, merged, "RawJSON"];
  ];

(* JSON から読み込み、現在のオプション値とマージ。
   オプションで明示的に指定された値を優先し、永続化された値は追加のみ。 *)
iLoadAndMergeDocOptions[packageName_String] :=
  Module[{path, saved, state, key},
    path = iDocOptionsPath[packageName];
    If[!FileExistsQ[path], Return[]];
    saved = Quiet @ Check[Import[path, "RawJSON"], $Failed];
    If[!AssociationQ[saved], Return[]];
    state = Lookup[$iDocState, packageName, <||>];
    If[!AssociationQ[state], state = <||>];
    (* マージ: 現在値が空なら永続値を採用、非空なら重複排除で結合 *)
    Do[
      state[key] = DeleteDuplicates @ Join[
        Replace[Lookup[state, key, {}], Except[_List] -> {}],
        Replace[Lookup[saved, key, {}], Except[_List] -> {}]],
      {key, {"References", "Demos", "Disclaimer", "Acknowledgments"}}];
    (* License: 明示指定があればそちらを優先、なければ永続値 *)
    If[!StringQ[Lookup[state, "License", ""]] || Lookup[state, "License", ""] === "",
      state["License"] = Replace[Lookup[saved, "License", ""], Except[_String] -> ""]];
    $iDocState[packageName] = state;
  ];

(* Paclet 形式か単一ファイルかを判定 *)
iPacletQ[packageName_String] :=
  FileExistsQ[FileNameJoin[{Global`$packageDirectory, packageName, "PacletInfo.wl"}]];

(* \:30d1\:30c3\:30b1\:30fc\:30b8\:306e\:30bd\:30fc\:30b9\:30d5\:30a1\:30a4\:30eb\:30d1\:30b9\:3092\:8fd4\:3059 (Paclet/\:5358\:4e00\:30d5\:30a1\:30a4\:30eb\:4e21\:5bfe\:5fdc) *)
iPackageSourceFile[packageName_String] :=
  If[iPacletQ[packageName],
    FileNameJoin[{Global`$packageDirectory, packageName, "Kernel", packageName <> ".wl"}],
    FileNameJoin[{Global`$packageDirectory, packageName <> ".wl"}]
  ];

(* \:30bf\:30a4\:30e0\:30b9\:30bf\:30f3\:30d7\:6587\:5b57\:5217 "YYYYMMDD_HHMMSS" \:307e\:305f\:306f "YYYYMMDDHHMM" \:3092\:8aad\:307f\:3084\:3059\:3044\:5f62\:5f0f\:306b\:5909\:63db *)
formatTimestamp[ts_String] := Module[{m, m2},
  (* YYYYMMDD_HHMMSS \:5f62\:5f0f (ClaudeUpdatePackage) → 秒は省略 *)
  m = StringCases[ts,
    RegularExpression["(\\d{4})(\\d{2})(\\d{2})_(\\d{2})(\\d{2})(\\d{2})"] :>
      {"$1", "$2", "$3", "$4", "$5"}];
  If[Length[m] > 0,
    With[{p = First[m]},
      p[[1]] <> "-" <> p[[2]] <> "-" <> p[[3]] <>
      " " <> p[[4]] <> ":" <> p[[5]]],
    (* YYYYMMDDHHMM \:5f62\:5f0f (ClaudeUpdateDocumentation) *)
    m2 = StringCases[ts,
      RegularExpression["^(\\d{4})(\\d{2})(\\d{2})(\\d{2})(\\d{2})$"] :>
        {"$1", "$2", "$3", "$4", "$5"}];
    If[Length[m2] > 0,
      With[{p = First[m2]},
        p[[1]] <> "-" <> p[[2]] <> "-" <> p[[3]] <>
        " " <> p[[4]] <> ":" <> p[[5]]],
      ts]
  ]
];

(* \:6307\:5b9a\:30d1\:30c3\:30b1\:30fc\:30b8\:306e\:66f4\:65b0\:5c65\:6b74\:30a8\:30f3\:30c8\:30ea\:30ea\:30b9\:30c8\:3092\:8fd4\:3059\:ff08\:5185\:90e8\:7528\:ff09 *)
packageHistoryEntries[packageName_String] := Module[
  {bdir, sessionDirs},
  bdir = backupDir[packageName];
  If[!DirectoryQ[bdir], Return[{}]];
  sessionDirs = Sort[Select[FileNames["*", bdir], DirectoryQ]];
  MapIndexed[Function[{dir, idx},
    <|
      "Index"     -> First[idx],
      "Package"   -> packageName,
      "Timestamp" -> FileNameTake[dir, -1],
      "Directory" -> dir,
      "HasWL"     -> FileExistsQ[FileNameJoin[{dir, packageName <> ".wl"}]],
      "HasPrompt" -> FileExistsQ[FileNameJoin[{dir, "prompt.txt"}]]
    |>
  ], sessionDirs]
];

(* \:5c65\:6b74\:30a8\:30f3\:30c8\:30ea\:3092\:6574\:5f62\:3057\:3066\:8868\:793a\:7528\:6587\:5b57\:5217\:3092\:4f5c\:308b *)
formatHistoryEntry[entry_Association] :=
  "  " <> ToString[entry["Index"]] <> ". " <>
  formatTimestamp[entry["Timestamp"]] <>
  If[entry["HasPrompt"], "  [prompt]", ""] <>
  If[entry["HasWL"], "  [.wl]", ""];

(* \:6307\:5b9a\:30d1\:30c3\:30b1\:30fc\:30b8\:306e\:66f4\:65b0\:5c65\:6b74\:3092\:8868\:793a\:3057\:3001Association\:306e\:30ea\:30b9\:30c8\:3092\:8fd4\:3059 *)
ClaudeUpdatePackageHistory[packageName_String] :=
  With[{nb = EvaluationNotebook[]},
  Module[{entries},
    entries = packageHistoryEntries[packageName];
    If[Length[entries] === 0,
      nbPrint[nb, "\:66f4\:65b0\:5c65\:6b74\:306a\:3057: " <> packageName]; Return[{}]];
    nbPrint[nb, packageName <> " \:306e\:66f4\:65b0\:5c65\:6b74 (" <> ToString[Length[entries]] <> " \:4ef6):\n" <>
      StringJoin[Riffle[formatHistoryEntry /@ entries, "\n"]]];
    entries
  ]];

ClaudeUpdatePackageHistory[] :=
  With[{nb = EvaluationNotebook[]},
  Module[{allInfoDirs, pkgNamesFound, allEntries, grouped, pkgNames, lines},
    allInfoDirs = Select[FileNames["*_info", Global`$packageDirectory], DirectoryQ];
    pkgNamesFound = StringReplace[FileNameTake[#, -1], RegularExpression["_info$"] -> ""] & /@ allInfoDirs;
    allEntries = Flatten[
      Select[packageHistoryEntries /@ pkgNamesFound,
        Length[#] > 0 &], 1];
    If[Length[allEntries] === 0,
      nbPrint[nb, "\:66f4\:65b0\:5c65\:6b74\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093\:3002"]; Return[{}]];
    grouped  = GroupBy[allEntries, #["Package"] &];
    pkgNames = Keys[grouped];
    lines = StringJoin @ Riffle[
      Map[Function[pkg,
        pkg <> " (" <> ToString[Length[grouped[pkg]]] <> " \:4ef6):\n" <>
        StringJoin[Riffle[formatHistoryEntry /@ grouped[pkg], "\n"]]
      ], pkgNames], "\n\n"];
    nbPrint[nb, "\:5168\:30d1\:30c3\:30b1\:30fc\:30b8\:306e\:66f4\:65b0\:5c65\:6b74 (\:5408\:8a08 " <>
      ToString[Length[allEntries]] <> " \:4ef6):\n\n" <> lines];
    allEntries
  ]];

(* ==============================================================
   \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:5c65\:6b74\:306e\:30a4\:30f3\:30bf\:30e9\:30af\:30c6\:30a3\:30d6\:8868\:793a: Review/Pull/Delete \:30dc\:30bf\:30f3\:4ed8\:304d Grid
   ============================================================== *)

(* \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:7a2e\:5225\:3092\:5224\:5b9a *)
iBackupType[dirName_String] := Which[
  StringMatchQ[dirName, "pre_" ~~ __], "pre",
  StringEndsQ[dirName, "_documentupdate"], "doc",
  True, "update"
];

(* \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:7a2e\:5225\:306e\:8868\:793a\:30e9\:30d9\:30eb *)
iBackupTypeLabel[type_String] := Switch[type,
  "pre",    Style["\:4e8b\:524d", FontColor -> GrayLevel[0.4]],
  "doc",    Style["\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8", FontColor -> RGBColor[0, 0.4, 0.7]],
  "update", Style["\:66f4\:65b0\:5f8c", FontColor -> RGBColor[0, 0.5, 0]],
  _,        type
];

(* \:30d7\:30ed\:30f3\:30d7\:30c8\:6587\:5b57\:5217\:3092\:8868\:793a\:7528\:306b\:77ed\:7e2e *)
iTruncatePrompt[prompt_String, maxLen_Integer:35] :=
  Module[{s},
    If[prompt === "", Return[Style["(\:306a\:3057)", GrayLevel[0.5]]]];
    (* INSTRUCTION: 以降だけ抽出（Claude向けプロンプトの場合） *)
    s = First[StringCases[prompt,
      "INSTRUCTION: " ~~ rest__ :> rest], prompt];
    (* 先頭の定型句を除去 *)
    s = StringReplace[s, {
      StartOfString ~~ WhitespaceCharacter.. -> "",
      StartOfString ~~ "\:524d\:56de\:306e\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:66f4\:65b0\:4ee5\:964d\:306e\:30bd\:30fc\:30b9\:30b3\:30fc\:30c9\:5909\:66f4\:3092\:53cd\:6620\:3057\:3066\:3001\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:3092\:66f4\:65b0\:3057\:3066\:304f\:3060\:3055\:3044\:3002" -> "(\:81ea\:52d5\:5dee\:5206\:66f4\:65b0)"}];
    s = StringTrim[s];
    If[StringLength[s] > maxLen,
      StringTake[s, maxLen] <> "\:2026",
      s]
  ];

(* \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:306e\:30bf\:30a4\:30e0\:30b9\:30bf\:30f3\:30d7\:90e8\:5206\:3092\:62bd\:51fa *)
iBackupTimestampPart[dirName_String] := Which[
  StringMatchQ[dirName, "pre_" ~~ __],
    StringDrop[dirName, 4],
  StringEndsQ[dirName, "_documentupdate"],
    StringTrim[dirName, "_documentupdate"],
  True,
    dirName
];

(* \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:5185\:306e\:30d5\:30a1\:30a4\:30eb\:4e00\:89a7\:3092\:53d6\:5f97 *)
iBackupFileList[dir_String] :=
  FileNameTake /@ Select[FileNames["*", dir], iFileQ];

(* プロンプトの要約を生成して summary.txt に保存する。
   API 制限中は生成せず空文字を返す（summary.txt も作成しない）。
   既存の iIsAPIErrorResponse を使ってエラー判定する。 *)
iGenerateBackupSummary[dir_String] :=
  Module[{promptFile, summaryFile, prompt, queryFn, result, summary},
    summaryFile = FileNameJoin[{dir, "summary.txt"}];
    If[FileExistsQ[summaryFile], Return[Quiet @ Import[summaryFile, "Text"]]];
    promptFile = FileNameJoin[{dir, "prompt.txt"}];
    If[!FileExistsQ[promptFile], Return[""]];
    prompt = Quiet @ Import[promptFile, "Text"];
    If[!StringQ[prompt] || prompt === "", Return[""]];
    (* Claude API で要約生成 *)
    queryFn = Quiet @ Check[ClaudeCode`Private`iClaudeQueryRaw, $Failed];
    If[queryFn === $Failed || !MatchQ[queryFn, _Symbol],
      Return[""]];  (* API 利用不可: summary.txt を作らず従来表示に任せる *)
    result = Quiet @ Check[queryFn[
      iLanguageInstruction["summary"] <>
      "Output ONLY the summary, nothing else. No quotes.\n\n" <>
      StringTake[prompt, UpTo[1000]]], $Failed];
    (* iIsAPIErrorResponse でエラー・制限レスポンスをチェック *)
    If[iIsAPIErrorResponse[result],
      Return[""]];  (* 制限中: summary.txt を作らない *)
    summary = StringTrim[result];
    If[StringLength[summary] > 200, Return[""]];  (* 異常に長い応答も除外 *)
    Quiet @ Export[summaryFile, summary, "Text"];
    summary
  ];

(* ClaudeBackupDataset 起動時に要約ファイルを検査・一括生成。
   壊れた summary.txt（limit エラーが保存されたもの）も削除する。
   最初の API 呼び出しで limit に達したら以降の生成をすべてスキップする。 *)
iEnsureBackupSummaries[entries_List] :=
  Module[{dir, summaryFile, content, count = 0, hitLimit = False},
    Do[
      dir = entry["Directory"];
      summaryFile = FileNameJoin[{dir, "summary.txt"}];
      (* 既存 summary.txt が壊れていたら削除 (iIsAPIErrorResponse で判定) *)
      If[FileExistsQ[summaryFile],
        content = Quiet @ Import[summaryFile, "Text"];
        If[iIsAPIErrorResponse[content],
          Quiet @ DeleteFile[summaryFile]]];
      (* limit に達していたら以降の生成をスキップ *)
      If[hitLimit, Continue[]];
      (* summary.txt がなく prompt.txt がある場合に生成を試みる *)
      If[!FileExistsQ[summaryFile] && entry["HasPrompt"],
        Module[{result},
          result = iGenerateBackupSummary[dir];
          If[result === "",
            (* 空文字が返った = API 失敗/制限 → 以降すべてスキップ *)
            hitLimit = True,
            count++]]],
      {entry, entries}];
    count
  ];

(* 全バックアップエントリを取得（指定パッケージ） *)
iAllBackupEntries[packageName_String] :=
  Module[{bdir, sessionDirs, dirName, btype},
    bdir = backupDir[packageName];
    If[!DirectoryQ[bdir], Return[{}]];
    sessionDirs = Sort[Select[FileNames["*", bdir], DirectoryQ]];
    MapIndexed[Function[{dir, idx},
      dirName = FileNameTake[dir, -1];
      btype = iBackupType[dirName];
      <|
        "Index"     -> First[idx],
        "Package"   -> packageName,
        "DirName"   -> dirName,
        "Timestamp" -> formatTimestamp[iBackupTimestampPart[dirName]],
        "Type"      -> btype,
        "Directory" -> dir,
        "Files"     -> iBackupFileList[dir],
        "Prompt"    -> Module[{sf, pf, pt},
          (* summary.txt を優先、なければ prompt.txt *)
          sf = FileNameJoin[{dir, "summary.txt"}];
          If[FileExistsQ[sf],
            pt = Quiet @ Import[sf, "Text"];
            If[StringQ[pt], pt, ""],
            pf = FileNameJoin[{dir, "prompt.txt"}];
            pt = If[FileExistsQ[pf], Quiet @ Import[pf, "Text"], ""];
            If[StringQ[pt], pt, ""]]],
        "HasWL"     -> FileExistsQ[FileNameJoin[{dir, packageName <> ".wl"}]],
        "HasMD"     -> Length[FileNames["*.md", dir]] > 0,
        "HasPrompt" -> FileExistsQ[FileNameJoin[{dir, "prompt.txt"}]]
      |>
    ], sessionDirs]
  ];

(* \:5168\:30d1\:30c3\:30b1\:30fc\:30b8\:306e\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:30a8\:30f3\:30c8\:30ea\:3092\:53d6\:5f97 *)
iAllBackupEntriesAll[] :=
  Module[{allInfoDirs, pkgNames, allEntries},
    allInfoDirs = Select[FileNames["*_info", Global`$packageDirectory], DirectoryQ];
    pkgNames = StringReplace[FileNameTake[#, -1], RegularExpression["_info$"] -> ""] & /@ allInfoDirs;
    allEntries = Flatten[iAllBackupEntries /@ pkgNames, 1];
    (* \:30b0\:30ed\:30fc\:30d0\:30eb\:30a4\:30f3\:30c7\:30c3\:30af\:30b9\:3092\:4ed8\:3051\:76f4\:3059 *)
    MapIndexed[Function[{entry, idx}, Append[entry, "Index" -> First[idx]]], allEntries]
  ];

(* ============================================================
   安全なバックアップ削除:
   差分チェーンの中間ノードを削除するとき、後続の .cdiff / .unchanged が
   参照先を失って復元不能になることを防ぐ。
   削除前に後続の依存を .cz (ベースライン) に変換し自己完結させる。
   ============================================================ *)

(* パッケージバックアップの安全削除。
   packageName が "" の場合はチェーン解決をスキップ（生ファイルのみの場合）。 *)
iSafeDeleteBackupDir[dir_String, packageName_String:""] :=
  Module[{parentDir, dirName, allDirs, laterDirs, resolved = 0},
    If[!DirectoryQ[dir], Return[$Failed]];
    parentDir = DirectoryName[dir];
    dirName = FileNameTake[dir, -1];
    (* 同じ history 内の全ディレクトリを取得 *)
    allDirs = SortBy[Select[FileNames["*", parentDir, {1}], DirectoryQ],
      FileNameTake[#, -1] &];
    (* 削除対象より後のディレクトリ *)
    laterDirs = Select[allDirs, FileNameTake[#, -1] > dirName &];
    (* 後続ディレクトリで dirName を参照する .cdiff / .unchanged を検索・解決 *)
    Scan[Function[laterDir,
      Module[{allFiles},
        allFiles = Select[FileNames["*", laterDir],
          iFileQ[#] && (StringEndsQ[FileNameTake[#], ".cdiff"] ||
                        StringEndsQ[FileNameTake[#], ".unchanged"]) &];
        Scan[Function[refFile,
          Module[{refContent, refDirName, baseName, fullContent, czPath},
            refContent = Quiet @ Check[Import[refFile, "String"], ""];
            If[!StringQ[refContent] || refContent === "", Return[]];
            (* 参照先ディレクトリ名を抽出 *)
            refDirName = If[StringEndsQ[FileNameTake[refFile], ".unchanged"],
              StringTrim[refContent],
              (* .cdiff の場合: Uncompress して {prevDirName, alignment} の第1要素 *)
              Module[{data},
                data = Quiet @ Check[Uncompress[refContent], $Failed];
                If[MatchQ[data, {_String, _List}], data[[1]], ""]]];
            (* このファイルが削除対象ディレクトリを参照しているか *)
            If[refDirName === dirName,
              (* ファイル名を復元 (.cdiff/.unchanged を除去) *)
              baseName = StringReplace[FileNameTake[refFile],
                {".cdiff" -> "", ".unchanged" -> ""}];
              (* フルコンテンツを復元して .cz に変換 *)
              If[packageName =!= "",
                fullContent = iLoadBackupFile[laterDir, baseName, packageName],
                (* packageName なし: 直接復元を試みる *)
                fullContent = If[StringEndsQ[FileNameTake[refFile], ".unchanged"],
                  (* unchanged: 元のディレクトリから直接読む *)
                  Module[{origPath = FileNameJoin[{parentDir, dirName, baseName}]},
                    If[FileExistsQ[origPath], Import[origPath, "Text"], $Failed]],
                  $Failed]];
              If[StringQ[fullContent],
                czPath = FileNameJoin[{laterDir, baseName <> ".cz"}];
                Export[czPath, Compress[fullContent], "String"];
                DeleteFile[refFile];
                resolved++,
                Print["  \:26a0 " <> baseName <> " in " <> FileNameTake[laterDir, -1] <>
                  " \:306e\:89e3\:6c7a\:306b\:5931\:6557\:3002\:524a\:9664\:3092\:4e2d\:6b62\:3057\:307e\:3059\:3002"];
                Return[$Failed, Module]
              ]]
          ]], allFiles]
      ]], laterDirs];
    If[resolved > 0,
      Print["  \:2713 " <> ToString[resolved] <> " \:500b\:306e\:4f9d\:5b58\:30d5\:30a1\:30a4\:30eb\:3092\:30d9\:30fc\:30b9\:30e9\:30a4\:30f3\:306b\:5909\:63db\:3057\:307e\:3057\:305f\:3002"]];
    DeleteDirectory[dir, DeleteContents -> True];
    dir
  ];

(* Review \:30a2\:30af\:30b7\:30e7\:30f3: \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:306e\:5185\:5bb9\:3092\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:306b\:8868\:793a *)
iBackupReview[packageName_String, dir_String, btype_String] :=
  Module[{nb, cells, files, dirName, currentFile, currentCode, backupCode},
    nb = EvaluationNotebook[];
    dirName = FileNameTake[dir, -1];
    files = iBackupFileList[dir];
    cells = {Cell["\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:30ec\:30d3\:30e5\:30fc: " <> packageName <> " / " <> dirName, "Subsection"]};
    AppendTo[cells, Cell[
      "\:30d1\:30c3\:30b1\:30fc\:30b8: " <> packageName <>
      "\n\:7a2e\:5225: " <> btype <>
      "\n\:30c7\:30a3\:30ec\:30af\:30c8\:30ea: " <> dir <>
      "\n\:30d5\:30a1\:30a4\:30eb\:6570: " <> ToString[Length[files]] <>
      "\n\:30d5\:30a1\:30a4\:30eb: " <> StringRiffle[files, ", "],
      "Text"]];
    (* .wl データがあれば現在との差分を表示 (.wl / .cz / .cdiff 対応) *)
    currentFile = iPackageSourceFile[packageName];
    backupCode = iLoadBackupWl[dir, packageName];
    If[StringQ[backupCode] && FileExistsQ[currentFile],
      currentCode = Import[currentFile, "Text"];
      If[StringQ[currentCode],
        Module[{currentLen, backupLen, diffLines},
          currentLen = StringLength[currentCode];
          backupLen = StringLength[backupCode];
          diffLines = If[currentCode === backupCode,
            "(\:73fe\:5728\:3068\:540c\:4e00\:5185\:5bb9)",
            "\:73fe\:5728: " <> ToString[currentLen] <> " chars, \:30d0\:30c3\:30af\:30a2\:30c3\:30d7: " <> ToString[backupLen] <> " chars\n" <>
            iComputeSourceDiff[FileNameJoin[{dir, packageName <> ".wl"}], currentFile]
          ];
          AppendTo[cells, Cell[
            "\n--- .wl \:5dee\:5206 ---\n" <> StringTake[diffLines, UpTo[3000]],
            "Program"]]
        ]]];
    (* prompt.txt \:304c\:3042\:308c\:3070\:8868\:793a *)
    Module[{promptFile, promptText},
      promptFile = FileNameJoin[{dir, "prompt.txt"}];
      If[FileExistsQ[promptFile],
        promptText = Import[promptFile, "Text"];
        If[StringQ[promptText],
          AppendTo[cells, Cell[
            "\n--- prompt.txt ---\n" <> StringTake[promptText, UpTo[2000]],
            "Program"]]]]];
    (* .md ファイルがあれば一覧表示 (.md / .cz / .cdiff / .unchanged 対応) *)
    Module[{mdNames, mdInfo},
      mdNames = iListRestorableFiles[dir, ".md"];
      If[Length[mdNames] > 0,
        mdInfo = Map[Function[fn,
          Module[{fmt},
            fmt = Which[
              FileExistsQ[FileNameJoin[{dir, fn}]], "raw",
              FileExistsQ[FileNameJoin[{dir, fn <> ".unchanged"}]], "=",
              FileExistsQ[FileNameJoin[{dir, fn <> ".cdiff"}]], "\:0394",
              FileExistsQ[FileNameJoin[{dir, fn <> ".cz"}]], "cz",
              True, "?"];
            fn <> " [" <> fmt <> "]"
          ]], mdNames];
        AppendTo[cells, Cell[
          "\n--- \:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:30d5\:30a1\:30a4\:30eb ---\n" <>
          StringRiffle[mdInfo, "\n"],
          "Program"]]]];
    (* \:30a2\:30af\:30b7\:30e7\:30f3\:30dc\:30bf\:30f3 *)
    With[{pn = packageName, d = dir},
      AppendTo[cells, Cell[BoxData[ToBoxes[
        Row[{
          Button["Pull (\:5fa9\:5143)",
            Module[{res},
              res = iBackupPull[pn, d];
              Print[res]],
            Method -> "Queued"],
          Spacer[20],
          Button["Delete (\:524a\:9664)",
            Module[{},
              If[ChoiceDialog["\:672c\:5f53\:306b\:524a\:9664\:3057\:307e\:3059\:304b\:ff1f\n" <> d],
                If[iSafeDeleteBackupDir[d, pn] =!= $Failed,
                  Print["\:524a\:9664\:3057\:307e\:3057\:305f: " <> d],
                  Print["\:524a\:9664\:306b\:5931\:6557\:3057\:307e\:3057\:305f\:3002"]],
                Print["\:30ad\:30e3\:30f3\:30bb\:30eb\:3057\:307e\:3057\:305f\:3002"]]],
            Method -> "Queued"]
        }]
      ]], "Output"]]];
    NotebookWrite[nb, Cell[CellGroupData[cells, Open]]];
    <|"Action" -> "Review", "Package" -> packageName, "Directory" -> dir|>
  ];

(* Pull \:30a2\:30af\:30b7\:30e7\:30f3: \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:3092\:5fa9\:5143 *)
iBackupPull[packageName_String, dir_String] :=
  Module[{nb, destFile, result = <||>, restoredSource, newSz, oldSz},
    nb = EvaluationNotebook[];
    (* .wl ファイルの復元 (レガシー .wl / .cz / .cdiff すべて対応) *)
    destFile = iPackageSourceFile[packageName];
    restoredSource = iLoadBackupWl[dir, packageName];
    If[StringQ[restoredSource],
      newSz = StringLength[restoredSource];
      oldSz = If[FileExistsQ[destFile], FileByteCount[destFile], 0];
      If[oldSz > 0 && newSz < oldSz * 0.5,
        nbPrint[nb, "\:26a0 \:30ef\:30fc\:30cb\:30f3\:30b0: \:5fa9\:5143\:30c7\:30fc\:30bf(" <> ToString[newSz] <>
          " chars)\:304c\:73fe\:5728(" <> ToString[oldSz] <>
          " bytes)\:306e50%\:672a\:6e80!"]];
      (* 書き込み先ディレクトリを確保 *)
      Module[{destDir = DirectoryName[destFile]},
        If[!DirectoryQ[destDir],
          Quiet @ CreateDirectory[destDir, CreateIntermediateDirectories -> True]]];
      (* 書き込み: BinaryWrite → Export フォールバック *)
      If[Quiet @ Check[
            Module[{strm},
              strm = OpenWrite[destFile, BinaryFormat -> True];
              If[Head[strm] =!= OutputStream,
                (* OpenWrite 失敗 → Export でフォールバック *)
                Export[destFile, restoredSource, "Text", CharacterEncoding -> "UTF-8"];
                True,
                BinaryWrite[strm, ToCharacterCode[restoredSource, "UTF-8"]];
                Close[strm]; True]], False],
        nbPrint[nb, "\:5fa9\:5143\:3057\:307e\:3057\:305f: " <> dir <> "\n\:2192 " <> destFile];
        Quiet @ Block[{$CharacterEncoding = "UTF-8"}, Get[destFile]];
        nbPrint[nb, "\:30d1\:30c3\:30b1\:30fc\:30b8\:3092\:518d\:30ed\:30fc\:30c9\:3057\:307e\:3057\:305f\:3002"];
        AssociateTo[result, "WL" -> destFile],
        nbPrint[nb, "\:8b66\:544a: .wl \:306e\:66f8\:304d\:8fbc\:307f\:5931\:6557\:3002\:5bfe\:8c61: " <> destFile]],
      nbPrint[nb, "\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:306b .wl \:30c7\:30fc\:30bf\:304c\:3042\:308a\:307e\:305b\:3093\:3002"]];
    (* .md ファイルの復元（.md / .cz / .cdiff / .unchanged すべて対応） *)
    Module[{mdNames, docsDir2, restoredCount = 0},
      mdNames = iListRestorableFiles[dir, ".md"];
      If[Length[mdNames] > 0,
        docsDir2 = FileNameJoin[{iInfoDir[packageName], "docs"}];
        If[DirectoryQ[docsDir2],
          Scan[Function[mdName,
            Module[{content, dest, strm2},
              content = iLoadBackupFile[dir, mdName, packageName];
              If[StringQ[content],
                dest = FileNameJoin[{docsDir2, mdName}];
                Quiet @ Check[
                  strm2 = OpenWrite[dest, BinaryFormat -> True];
                  BinaryWrite[strm2, ToCharacterCode[content, "UTF-8"]];
                  Close[strm2], Null];
                nbPrint[nb, "\:5fa9\:5143: " <> mdName <> " \:2192 " <> dest];
                restoredCount++,
                nbPrint[nb, "\:8b66\:544a: " <> mdName <> " \:306e\:5fa9\:5143\:306b\:5931\:6557"]]]],
            mdNames];
          If[restoredCount > 0, AssociateTo[result, "MD" -> restoredCount]],
          nbPrint[nb, "\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:304c\:5b58\:5728\:3057\:307e\:305b\:3093: " <> docsDir2]]]];
    (* doc_options.json の復元 *)
    Module[{docOptsContent, docOptsDest, refDir, strm3},
      docOptsContent = iLoadBackupFile[dir, "doc_options.json", packageName];
      If[StringQ[docOptsContent],
        refDir = iReferencesDir[packageName];
        If[!DirectoryQ[refDir],
          Quiet @ CreateDirectory[refDir, CreateIntermediateDirectories -> True]];
        docOptsDest = FileNameJoin[{refDir, "doc_options.json"}];
        Quiet @ Check[
          strm3 = OpenWrite[docOptsDest, BinaryFormat -> True];
          BinaryWrite[strm3, ToCharacterCode[docOptsContent, "UTF-8"]];
          Close[strm3], Null];
        nbPrint[nb, "\:5fa9\:5143: doc_options.json \:2192 " <> docOptsDest];
        AssociateTo[result, "DocOptions" -> docOptsDest]]];
    Join[result, <|"Action" -> "Pull", "Package" -> packageName, "Directory" -> dir|>]
  ];

(* ============================================================
   バックアップ用ローカルスナップショット管理
   ClaudeBackupDataset / ClaudeDirectiveBackupDataset の起動時に
   現在の作業ファイルを保存し、Pull で巻き戻した後に復元可能にする。
   ============================================================ *)

iBackupSnapshotDir[packageName_String] :=
  FileNameJoin[{Global`$packageDirectory, "GithubRepositories",
    "_local_snapshot", "_backup_" <> packageName}];

iBackupSnapshotHashPath[packageName_String] :=
  FileNameJoin[{iBackupSnapshotDir[packageName], "_snapshot_hashes.json"}];

(* パッケージのバックアップ対象ファイルを収集してスナップショットに保存 *)
iSaveBackupSnapshot[packageName_String] :=
  Module[{snapDir, pkgDir, srcFile, docsDir, hashes = <||>, dst},
    snapDir = iBackupSnapshotDir[packageName];
    If[DirectoryQ[snapDir],
      Quiet @ DeleteDirectory[snapDir, DeleteContents -> True]];
    Quiet @ CreateDirectory[snapDir, CreateIntermediateDirectories -> True];
    pkgDir = Global`$packageDirectory;
    (* .wl ファイル *)
    srcFile = iPackageSourceFile[packageName];
    If[FileExistsQ[srcFile],
      dst = FileNameJoin[{snapDir, FileNameTake[srcFile]}];
      Quiet @ CopyFile[srcFile, dst, OverwriteTarget -> True];
      hashes[FileNameTake[srcFile]] = Quiet @ Check[FileHash[srcFile, "SHA256", "HexString"], ""]];
    (* _info/docs/ 内のファイル *)
    docsDir = FileNameJoin[{iInfoDir[packageName], "docs"}];
    If[DirectoryQ[docsDir],
      Module[{allFiles, relPath, dstF},
        allFiles = Select[FileNames["*", docsDir, Infinity],
          FileExistsQ[#] && !DirectoryQ[#] &];
        Do[
          relPath = "docs/" <> FileNameJoin[FileNameDrop[f, FileNameDepth[docsDir]]];
          dstF = FileNameJoin[Flatten[{snapDir, FileNameSplit[relPath]}]];
          Quiet @ CreateDirectory[DirectoryName[dstF], CreateIntermediateDirectories -> True];
          Quiet @ CopyFile[f, dstF, OverwriteTarget -> True];
          hashes[relPath] = Quiet @ Check[FileHash[f, "SHA256", "HexString"], ""],
          {f, allFiles}]]];
    (* doc_options.json のスナップショット *)
    Module[{docOptsFile = iDocOptionsPath[packageName], dstOpts},
      If[FileExistsQ[docOptsFile],
        dstOpts = FileNameJoin[{snapDir, "doc_options.json"}];
        Quiet @ CopyFile[docOptsFile, dstOpts, OverwriteTarget -> True];
        hashes["doc_options.json"] = Quiet @ Check[FileHash[docOptsFile, "SHA256", "HexString"], ""]]];
    Export[iBackupSnapshotHashPath[packageName], hashes, "RawJSON"];
    <|"Action" -> "SaveBackupSnapshot", "Package" -> packageName,
      "SnapshotDir" -> snapDir, "HashedFiles" -> Length[hashes]|>
  ];

(* スナップショットからパッケージファイルを復元 *)
iRestoreBackupSnapshot[packageName_String] :=
  Module[{snapDir, pkgDir, srcFile, docsDir, allFiles, relPath, dst,
          restored = 0, nb},
    snapDir = iBackupSnapshotDir[packageName];
    If[!DirectoryQ[snapDir],
      Return[Failure["NoSnapshot", <|"Message" -> "スナップショットなし"|>]]];
    nb = Quiet[EvaluationNotebook[]];
    pkgDir = Global`$packageDirectory;
    (* .wl ファイルの復元 *)
    srcFile = FileNameJoin[{snapDir, packageName <> ".wl"}];
    If[FileExistsQ[srcFile],
      dst = iPackageSourceFile[packageName];
      Quiet @ CopyFile[srcFile, dst, OverwriteTarget -> True];
      Quiet @ Block[{$CharacterEncoding = "UTF-8"}, Get[dst]];
      nbPrint[nb, "復元: " <> FileNameTake[dst]];
      restored++];
    (* Paclet 形式の場合もチェック *)
    If[iPacletQ[packageName],
      Module[{kernelFile},
        kernelFile = FileNameJoin[{snapDir, packageName <> ".wl"}];
        If[FileExistsQ[kernelFile],
          dst = iPackageSourceFile[packageName];
          Quiet @ CopyFile[kernelFile, dst, OverwriteTarget -> True];
          Quiet @ Block[{$CharacterEncoding = "UTF-8"}, Get[dst]]]]];
    (* docs ファイルの復元 *)
    docsDir = FileNameJoin[{iInfoDir[packageName], "docs"}];
    Module[{snapDocs},
      snapDocs = FileNameJoin[{snapDir, "docs"}];
      If[DirectoryQ[snapDocs],
        allFiles = Select[FileNames["*", snapDocs, Infinity],
          FileExistsQ[#] && !DirectoryQ[#] &];
        Do[
          relPath = FileNameJoin[FileNameDrop[f, FileNameDepth[snapDocs]]];
          dst = FileNameJoin[{docsDir, relPath}];
          Quiet @ CreateDirectory[DirectoryName[dst], CreateIntermediateDirectories -> True];
          Quiet @ CopyFile[f, dst, OverwriteTarget -> True];
          nbPrint[nb, "復元: docs/" <> relPath];
          restored++,
          {f, allFiles}]]];
    (* doc_options.json の復元 *)
    Module[{snapDocOpts = FileNameJoin[{snapDir, "doc_options.json"}], refDir},
      If[FileExistsQ[snapDocOpts],
        refDir = iReferencesDir[packageName];
        If[!DirectoryQ[refDir],
          Quiet @ CreateDirectory[refDir, CreateIntermediateDirectories -> True]];
        dst = FileNameJoin[{refDir, "doc_options.json"}];
        Quiet @ CopyFile[snapDocOpts, dst, OverwriteTarget -> True];
        nbPrint[nb, "\:5fa9\:5143: doc_options.json"];
        restored++]];
    <|"Action" -> "RestoreBackupSnapshot", "Package" -> packageName,
      "FilesRestored" -> restored|>
  ];

(* スナップショットと現在のファイルのハッシュを比較して変更ファイルを検出 *)
iDetectBackupChanges[packageName_String] :=
  Module[{snapDir, hashPath, savedHashes, changedFiles = {},
          srcFile, currentHash, savedHash, docsDir},
    snapDir = iBackupSnapshotDir[packageName];
    If[!DirectoryQ[snapDir], Return[{}]];
    hashPath = iBackupSnapshotHashPath[packageName];
    savedHashes = Quiet @ Check[Import[hashPath, "RawJSON"], <||>];
    If[!AssociationQ[savedHashes], savedHashes = <||>];
    (* .wl ファイル *)
    srcFile = iPackageSourceFile[packageName];
    If[FileExistsQ[srcFile],
      currentHash = Quiet @ Check[FileHash[srcFile, "SHA256", "HexString"], ""];
      savedHash = Lookup[savedHashes, FileNameTake[srcFile], None];
      If[savedHash === None || currentHash =!= savedHash,
        AppendTo[changedFiles, FileNameTake[srcFile]]]];
    (* docs ファイル *)
    docsDir = FileNameJoin[{iInfoDir[packageName], "docs"}];
    If[DirectoryQ[docsDir],
      Module[{allFiles, relPath},
        allFiles = Select[FileNames["*", docsDir, Infinity],
          FileExistsQ[#] && !DirectoryQ[#] &];
        Do[
          relPath = "docs/" <> FileNameJoin[FileNameDrop[f, FileNameDepth[docsDir]]];
          currentHash = Quiet @ Check[FileHash[f, "SHA256", "HexString"], ""];
          savedHash = Lookup[savedHashes, relPath, None];
          If[savedHash === None || currentHash =!= savedHash,
            AppendTo[changedFiles, relPath]],
          {f, allFiles}]]];
    changedFiles
  ];

(* 指定パッケージのバックアップ履歴を Grid で表示 *)
ClaudeBackupDataset[packageName_String] :=
  Module[{entries, gridRows, header, localRow, pn = packageName,
          outputTag, warningTag, gridResult, snapDir},
    (* 起動時: スナップショット保存 *)
    snapDir = iBackupSnapshotDir[packageName];
    If[DirectoryQ[snapDir],
      Quiet @ DeleteDirectory[snapDir, DeleteContents -> True]];
    iSaveBackupSnapshot[packageName];
    entries = Reverse[iAllBackupEntries[packageName]];
    If[Length[entries] === 0,
      Print["\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:5c65\:6b74\:306a\:3057: " <> packageName]; Return[{}]];
    (* 要約ファイルがないエントリの要約を一括生成 *)
    iEnsureBackupSummaries[entries];
    (* 要約生成後にエントリを再読み込み *)
    entries = Reverse[iAllBackupEntries[packageName]];
    outputTag = "ClaudeBackupDataset$" <> packageName <> "$output";
    warningTag = "ClaudeBackupDataset$" <> packageName <> "$warning";
    header = {Style["#", Bold], Style["Timestamp", Bold],
      Style["Type", Bold], Style["\:6307\:793a", Bold], Style["Actions", Bold]};
    (* #0 行: ローカル最新版 *)
    localRow = {
      Style[0, Bold, RGBColor[0, 0.5, 0]],
      Style["local", FontFamily -> "Courier", FontColor -> RGBColor[0, 0.5, 0]],
      "ローカル最新版",
      "(スナップショット保存済み)",
      With[{pkg = pn, oTag = outputTag, wTag = warningTag},
        Row[{
          Button["Pull",
            Module[{newerFiles, msg, nb, outputIndices, outputIdx, cells},
              nb = Quiet[EvaluationNotebook[]];
              If[!DirectoryQ[iBackupSnapshotDir[pkg]],
                Print["スナップショットが存在しません。"],
                newerFiles = iDetectBackupChanges[pkg];
                If[Length[newerFiles] > 0,
                  msg = "以下の " <> ToString[Length[newerFiles]] <>
                    " ファイルがスナップショットから変更されています:\n\n" <>
                    StringRiffle[Take[newerFiles, UpTo[10]], "\n"] <>
                    If[Length[newerFiles] > 10,
                      "\n... 他 " <> ToString[Length[newerFiles] - 10] <> " ファイル", ""] <>
                    "\n\nローカル最新版で上書きすると、これらの変更は失われます。";
                  NBAccess`NBDeleteCellsByTag[nb, wTag];
                  outputIndices = NBAccess`NBCellIndicesByTag[nb, oTag];
                  If[Length[outputIndices] > 0,
                    NBAccess`NBMoveAfterCell[nb, Last[outputIndices]],
                    Quiet[SelectionMove[EvaluationCell[], After, Cell]]];
                  cells = Cell[CellGroupData[{
                    Cell["\:26a0 ローカル最新版への復元", "Subsubsection",
                      CellTags -> {wTag}],
                    Cell[msg, "Text"],
                    Cell[BoxData[ToBoxes[Row[{
                      Button["すべてローカル最新版に置き換える",
                        Module[{res, nb2},
                          nb2 = Quiet[EvaluationNotebook[]];
                          res = iRestoreBackupSnapshot[pkg];
                          If[!FailureQ[res],
                            Print["ローカル最新版に復元: " <>
                              ToString[res["FilesRestored"]] <> " ファイル"],
                            Print[res]];
                          NBAccess`NBDeleteCellsByTag[nb2, wTag]],
                        Method -> "Queued"],
                      Spacer[20],
                      Button["キャンセル",
                        Module[{nb2},
                          nb2 = Quiet[EvaluationNotebook[]];
                          NBAccess`NBDeleteCellsByTag[nb2, wTag]],
                        Method -> "Queued"]
                    }]]], "Output"]
                  }, Open]];
                  NotebookWrite[nb, cells],
                  (* 変更なし *)
                  If[ChoiceDialog["ローカル最新版に復元しますか？"],
                    Module[{res},
                      res = iRestoreBackupSnapshot[pkg];
                      If[!FailureQ[res],
                        Print["ローカル最新版に復元: " <>
                          ToString[res["FilesRestored"]] <> " ファイル"],
                        Print[res]]],
                    Print["キャンセルしました。"]]
                ]]],
            Method -> "Queued", ImageSize -> {52, 22}]
        }, Spacer[3]]]
    };
    gridRows = Map[
      Function[entry,
        Module[{num, ts, btype, prompt, dir},
          num = entry["Index"];
          ts = entry["Timestamp"];
          btype = entry["Type"];
          prompt = entry["Prompt"];
          dir = entry["Directory"];
          {num,
           ts,
           iBackupTypeLabel[btype],
           iTruncatePrompt[prompt],
           Row[{
             With[{pkg = pn, d = dir, bt = btype},
               Button["Review",
                 iBackupReview[pkg, d, bt],
                 Method -> "Queued", ImageSize -> {52, 22}]],
             With[{pkg = pn, d = dir},
               Button["Pull",
                 Module[{},
                   If[ChoiceDialog["\:5fa9\:5143\:3057\:307e\:3059\:304b\:ff1f\n" <> d],
                     Print[iBackupPull[pkg, d]],
                     Print["\:30ad\:30e3\:30f3\:30bb\:30eb\:3057\:307e\:3057\:305f\:3002"]]],
                 Method -> "Queued", ImageSize -> {52, 22}]],
             With[{d = dir, pkg2 = pn},
               Button["Delete",
                 Module[{},
                   If[ChoiceDialog["\:672c\:5f53\:306b\:524a\:9664\:3057\:307e\:3059\:304b\:ff1f\n" <> d],
                     If[iSafeDeleteBackupDir[d, pkg2] =!= $Failed,
                       Print["\:524a\:9664\:3057\:307e\:3057\:305f: " <> d],
                       Print["\:524a\:9664\:306b\:5931\:6557\:3057\:307e\:3057\:305f\:3002"]],
                     Print["\:30ad\:30e3\:30f3\:30bb\:30eb\:3057\:307e\:3057\:305f\:3002"]]],
                 Method -> "Queued", ImageSize -> {52, 22}]]
           }, Spacer[3]]}
        ]],
      entries];
    gridResult = Grid[Prepend[Prepend[gridRows, localRow], header],
      Alignment -> {Left, Center},
      Dividers -> {None, {2 -> GrayLevel[0.7]}},
      Spacings -> {1.5, 0.8},
      Background -> {None, {GrayLevel[0.95], None}},
      ItemSize -> {{3, 14, 8, 22, Automatic}, Automatic}];
    Module[{nb = Quiet[EvaluationNotebook[]]},
      NBAccess`NBDeleteCellsByTag[nb, warningTag];
      NBAccess`NBDeleteCellsByTag[nb, outputTag]];
    CellPrint[Cell[BoxData[ToBoxes[gridResult]], "Output",
      CellTags -> {outputTag}]];
  ];

(* 全パッケージのバックアップ履歴を Grid で表示 *)
ClaudeBackupDataset[] :=
  Module[{entries, gridRows, header, outputTag, gridResult},
    entries = Reverse[iAllBackupEntriesAll[]];
    If[Length[entries] === 0,
      Print["\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:5c65\:6b74\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093\:3002"]; Return[{}]];
    outputTag = "ClaudeBackupDatasetAll$output";
    header = {Style["#", Bold], Style["Package", Bold], Style["Timestamp", Bold],
      Style["Type", Bold], Style["\:6307\:793a", Bold], Style["Actions", Bold]};
    gridRows = Map[
      Function[entry,
        Module[{num, pkg, ts, btype, prompt, dir},
          num = entry["Index"];
          pkg = entry["Package"];
          ts = entry["Timestamp"];
          btype = entry["Type"];
          prompt = entry["Prompt"];
          dir = entry["Directory"];
          {num,
           StringTake[pkg, UpTo[20]],
           ts,
           iBackupTypeLabel[btype],
           iTruncatePrompt[prompt, 25],
           Row[{
             With[{p = pkg, d = dir, bt = btype},
               Button["Review",
                 iBackupReview[p, d, bt],
                 Method -> "Queued", ImageSize -> {52, 22}]],
             With[{p = pkg, d = dir},
               Button["Pull",
                 Module[{},
                   If[ChoiceDialog["\:5fa9\:5143\:3057\:307e\:3059\:304b\:ff1f\n" <> d],
                     Print[iBackupPull[p, d]],
                     Print["\:30ad\:30e3\:30f3\:30bb\:30eb\:3057\:307e\:3057\:305f\:3002"]]],
                 Method -> "Queued", ImageSize -> {52, 22}]],
             With[{p2 = pkg, d = dir},
               Button["Delete",
                 Module[{},
                   If[ChoiceDialog["\:672c\:5f53\:306b\:524a\:9664\:3057\:307e\:3059\:304b\:ff1f\n" <> d],
                     If[iSafeDeleteBackupDir[d, p2] =!= $Failed,
                       Print["\:524a\:9664\:3057\:307e\:3057\:305f: " <> d],
                       Print["\:524a\:9664\:306b\:5931\:6557\:3057\:307e\:3057\:305f\:3002"]],
                     Print["\:30ad\:30e3\:30f3\:30bb\:30eb\:3057\:307e\:3057\:305f\:3002"]]],
                 Method -> "Queued", ImageSize -> {52, 22}]]
           }, Spacer[3]]}
        ]],
      entries];
    gridResult = Grid[Prepend[gridRows, header],
      Alignment -> {Left, Center},
      Dividers -> {None, {2 -> GrayLevel[0.7]}},
      Spacings -> {1.5, 0.8},
      Background -> {None, {GrayLevel[0.95], None}},
      ItemSize -> {{3, 14, 14, 8, 20, Automatic}, Automatic}];
    Module[{nb = Quiet[EvaluationNotebook[]]},
      NBAccess`NBDeleteCellsByTag[nb, outputTag]];
    CellPrint[Cell[BoxData[ToBoxes[gridResult]], "Output",
      CellTags -> {outputTag}]];
  ];

(* ============================================================
   バックアップ履歴マイグレーション:
   既存の生 .wl バックアップを差分形式 (.wl.cz / .wl.cdiff) に変換し、
   history フォルダの容量を大幅に削減する。
   ============================================================ *)

(* 変換済みバックアップファイルか判定 (拡張子ベース) *)
iIsConvertedBackupFile[fn_String] :=
  StringEndsQ[fn, ".cz"] || StringEndsQ[fn, ".cdiff"] || StringEndsQ[fn, ".unchanged"];

Options[ClaudeMigrateBackupHistory] = {DryRun -> False};

(* 既存バックアップ内の全テキストファイル (.wl / .md 等) を
   差分形式 (.cz / .cdiff / .unchanged) に変換し容量を削減する。
   各ファイルの履歴を個別に追跡し、未変更ファイルは .unchanged で参照。 *)
ClaudeMigrateBackupHistory[packageName_String, opts:OptionsPattern[]] :=
  Module[{bdir, allDirs, dryRun, results = {},
          totalOldBytes = 0, totalNewBytes = 0,
          prevContents = <||>, prevDirNames = <||>,
          baselineCount = 0, metaFiles},
    dryRun = TrueQ[OptionValue[DryRun]];
    bdir = backupDir[packageName];
    If[!DirectoryQ[bdir],
      Print["\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:304c\:5b58\:5728\:3057\:307e\:305b\:3093: " <> bdir];
      Return[<||>]];
    metaFiles = {"prompt.txt", "summary.txt"};
    (* 全バックアップディレクトリを時系列順 *)
    allDirs = SortBy[
      Select[FileNames["*", bdir, {1}], DirectoryQ],
      FileNameTake[#, -1] &];
    (* 生テキストファイルを含むディレクトリのみ *)
    allDirs = Select[allDirs, Function[dir,
      AnyTrue[Select[FileNames["*", dir], iFileQ], Function[f,
        Module[{fn = FileNameTake[f]},
          !MemberQ[metaFiles, fn] &&
          !iIsConvertedBackupFile[fn]]]]]];
    If[Length[allDirs] === 0,
      Print["\:5909\:63db\:5bfe\:8c61\:306e\:751f\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:304c\:3042\:308a\:307e\:305b\:3093\:3002"];
      Return[<||>]];
    Print[Style["\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:5c65\:6b74\:30de\:30a4\:30b0\:30ec\:30fc\:30b7\:30e7\:30f3" <>
      If[dryRun, " (DryRun)", ""] <> ": " <> packageName, Bold]];
    Print["\:5bfe\:8c61: " <> ToString[Length[allDirs]] <> " \:30c7\:30a3\:30ec\:30af\:30c8\:30ea\n"];
    Do[
      Module[{dirName, rawFiles, dirOldBytes = 0, dirNewBytes = 0, fileResults = {}},
        dirName = FileNameTake[dir, -1];
        (* 生テキストファイルを収集 (メタファイル・既変換済みを除外) *)
        rawFiles = Select[FileNames["*", dir],
          Function[f, iFileQ[f] &&
            !MemberQ[metaFiles, FileNameTake[f]] &&
            !iIsConvertedBackupFile[FileNameTake[f]]]];
        If[Length[rawFiles] === 0, Continue[]];
        Do[
          Module[{fn, filePath, content, oldBytes, newBytes, action,
                  czPath, cdiffPath, unchangedPath,
                  prevContent, prevDN, alignment, diffData, targetDN},
            fn = FileNameTake[rf];
            filePath = rf;
            oldBytes = FileByteCount[filePath];
            dirOldBytes += oldBytes;
            content = Quiet @ Check[Import[filePath, "Text"], ""];
            If[!StringQ[content] || content === "",
              Print["    \:2717 " <> fn <> ": \:8aad\:307f\:8fbc\:307f\:5931\:6557"];
              AppendTo[fileResults, fn -> "skip"];
              Continue[]];
            czPath = FileNameJoin[{dir, fn <> ".cz"}];
            cdiffPath = FileNameJoin[{dir, fn <> ".cdiff"}];
            unchangedPath = FileNameJoin[{dir, fn <> ".unchanged"}];
            prevContent = Lookup[prevContents, fn, None];
            prevDN = Lookup[prevDirNames, fn, None];
            Which[
              (* 初回 or pre_ or ベースライン間隔 → ベースライン *)
              prevContent === None ||
                StringStartsQ[dirName, "pre_"] ||
                Mod[baselineCount, $iBackupBaselineInterval] === 0,
                action = "baseline";
                If[!dryRun,
                  Export[czPath, Compress[content], "String"];
                  newBytes = FileByteCount[czPath],
                  newBytes = StringLength[Compress[content]]],
              (* 内容同一 → .unchanged *)
              content === prevContent,
                action = "unchanged";
                (* 1ホップ解決: 前回が .unchanged なら前回の参照先を引き継ぐ *)
                targetDN = prevDN;
                If[!dryRun,
                  Export[unchangedPath, targetDN, "String"];
                  newBytes = FileByteCount[unchangedPath],
                  newBytes = StringLength[targetDN]],
              (* 差分 *)
              True,
                alignment = Quiet @ Check[
                  SequenceAlignment[
                    StringSplit[prevContent, "\n"],
                    StringSplit[content, "\n"]],
                  $Failed];
                If[alignment === $Failed,
                  action = "baseline(fallback)";
                  If[!dryRun,
                    Export[czPath, Compress[content], "String"];
                    newBytes = FileByteCount[czPath],
                    newBytes = StringLength[Compress[content]]],
                  action = "diff";
                  diffData = {prevDN, alignment};
                  If[!dryRun,
                    Export[cdiffPath, Compress[diffData], "String"];
                    newBytes = FileByteCount[cdiffPath],
                    newBytes = StringLength[Compress[diffData]]]]
            ];
            dirNewBytes += newBytes;
            AppendTo[fileResults, fn -> action];
            (* 検証後に元ファイル削除 *)
            If[!dryRun,
              Module[{verify},
                verify = iLoadBackupFile[dir, fn, packageName];
                If[StringQ[verify] && StringLength[verify] > 0,
                  DeleteFile[filePath],
                  (* 検証失敗 → 新ファイル削除 *)
                  Quiet @ If[FileExistsQ[czPath], DeleteFile[czPath]];
                  Quiet @ If[FileExistsQ[cdiffPath], DeleteFile[cdiffPath]];
                  Quiet @ If[FileExistsQ[unchangedPath], DeleteFile[unchangedPath]];
                  Print["    \:26a0 " <> fn <> ": \:691c\:8a3c\:5931\:6557\:3001\:5143\:30d5\:30a1\:30a4\:30eb\:4fdd\:6301"];
                  action = "verify-failed"]]];
            (* 追跡を更新: unchanged の場合は prevDirNames を変えない *)
            prevContents[fn] = content;
            If[action =!= "unchanged", prevDirNames[fn] = dirName]
          ],
          {rf, rawFiles}];
        baselineCount++;
        totalOldBytes += dirOldBytes;
        totalNewBytes += dirNewBytes;
        (* ディレクトリ単位の表示 *)
        Module[{summary},
          summary = Tally[Values[fileResults]];
          Print["  " <> dirName <> ": " <>
            ToString[dirOldBytes] <> " \:2192 " <> ToString[dirNewBytes] <>
            " bytes (" <> ToString[Round[100. dirNewBytes / Max[dirOldBytes, 1]]] <>
            "%)  " <> StringRiffle[
              (ToString[#[[2]]] <> #[[1]]) & /@ summary, " "]]];
        AppendTo[results, <|"Dir" -> dirName,
          "OldBytes" -> dirOldBytes, "NewBytes" -> dirNewBytes,
          "Files" -> fileResults|>]
      ],
      {dir, allDirs}];
    Print["\n", Style["\:5b8c\:4e86", Bold]];
    Print["\:5408\:8a08: " <> ToString[totalOldBytes] <> " \:2192 " <> ToString[totalNewBytes] <>
      " bytes (" <> ToString[Round[100. totalNewBytes / Max[totalOldBytes, 1]]] <> "%)"];
    Print["\:524a\:6e1b: " <> ToString[totalOldBytes - totalNewBytes] <> " bytes (" <>
      ToString[Round[100. (totalOldBytes - totalNewBytes) / Max[totalOldBytes, 1]]] <> "%)"];
    If[dryRun, Print["\n\:203b DryRun \:30e2\:30fc\:30c9: \:5b9f\:969b\:306e\:5909\:63db\:306f\:884c\:308f\:308c\:3066\:3044\:307e\:305b\:3093\:3002"]];
    <|"Package" -> packageName, "Converted" -> Length[results],
      "OldBytes" -> totalOldBytes, "NewBytes" -> totalNewBytes,
      "Reduction" -> ToString[Round[100. (totalOldBytes - totalNewBytes) / Max[totalOldBytes, 1]]] <> "%",
      "Details" -> results|>
  ];

(* 全パッケージ版 *)
ClaudeMigrateBackupHistory[opts:OptionsPattern[]] :=
  Module[{pkgDir, allPkgs, results = <||>},
    pkgDir = Global`$packageDirectory;
    If[!StringQ[pkgDir] || !DirectoryQ[pkgDir],
      Print["\:30a8\:30e9\:30fc: $packageDirectory \:304c\:8a2d\:5b9a\:3055\:308c\:3066\:3044\:307e\:305b\:3093\:3002"];
      Return[<||>]];
    allPkgs = Select[
      FileNameTake /@ FileNames["*_info", pkgDir],
      StringEndsQ[#, "_info"] &];
    allPkgs = StringReplace[#, "_info" -> ""] & /@ allPkgs;
    allPkgs = Select[allPkgs, DirectoryQ[backupDir[#]] &];
    If[Length[allPkgs] === 0,
      Print["\:30de\:30a4\:30b0\:30ec\:30fc\:30b7\:30e7\:30f3\:5bfe\:8c61\:306e\:30d1\:30c3\:30b1\:30fc\:30b8\:304c\:3042\:308a\:307e\:305b\:3093\:3002"];
      Return[<||>]];
    Do[
      results[pkg] = ClaudeMigrateBackupHistory[pkg, opts],
      {pkg, allPkgs}];
    results
  ];

(* ==============================================================
   関数単位抽出: ファイル内の各関数定義を Association に分解
   ============================================================== *)
iExtractFunctions[code_String] :=
  Module[{lines, blocks, current, funcName, nameRe},
    lines = StringSplit[code, "\n"];
    nameRe = RegularExpression["^([a-zA-Z\\$][a-zA-Z0-9\\$]*)\\s*[\\[\\(]"];
    blocks = <||>;
    current = None;
    Scan[Function[line,
      Module[{m},
        m = StringCases[line, nameRe :> "$1"];
        If[Length[m] > 0 && !StringStartsQ[line, " "] && !StringStartsQ[line, "\t"] &&
           (StringContainsQ[line, ":="] || StringContainsQ[line, "= ("]),
          current = First[m];
          If[!KeyExistsQ[blocks, current], blocks[current] = ""];
          blocks[current] = blocks[current] <> line <> "\n",
          If[current =!= None,
            blocks[current] = blocks[current] <> line <> "\n"]
        ]
      ]
    ], lines];
    blocks
  ];

(* \:30d7\:30ed\:30f3\:30d7\:30c8\:306b\:542b\:307e\:308c\:308b\:95a2\:6570\:540d\:3092\:30d1\:30c3\:30b1\:30fc\:30b8\:306e\:30a8\:30af\:30b9\:30dd\:30fc\:30c8\:540d\:4e00\:89a7\:3068\:7167\:5c04\:3057\:3066\:63a8\:5b9a *)
(* \:65e5\:672c\:8a9e\:30ad\:30fc\:30ef\:30fc\:30c9 \:2192 \:95a2\:9023\:95a2\:6570\:30b0\:30eb\:30fc\:30d7\:306e\:30de\:30c3\:30d4\:30f3\:30b0\:3082\:4f7f\:7528 *)
iGuessTargetFunctions[prompt_String, allFuncNames_List] :=
  Module[{words, hits, kwMap, kwHits},
    (* \:82f1\:8a9e\:95a2\:6570\:540d\:306e\:76f4\:63a5\:30de\:30c3\:30c1 *)
    words = StringCases[prompt, RegularExpression["[a-zA-Z\\$][a-zA-Z0-9\\$]+"]];
    hits  = Select[allFuncNames, MemberQ[words, #] &];

    (* \:65e5\:672c\:8a9e\:30ad\:30fc\:30ef\:30fc\:30c9 \:2192 \:95a2\:9023\:95a2\:6570\:30b0\:30eb\:30fc\:30d7 *)
    kwMap = {
      {"\:6a5f\:5bc6", "Confidential", "confidential", "NonConfidential", "\:89e3\:9664"} ->
        {"Confidential", "NonConfidential", "MarkConfidential", "UnmarkConfidential",
         "IsConfidential", "ScanConfidentialCells",
         "iConfidentialCellEpilog", "iEnsureCellEpilog", "iInstallCellEpilog",
         "iCellUsesConfidentialSymbol", "iExtractCellVarNames",
         "iExtractCellAssignedNames", "iMarkSelectedConfidential",
         "iUnmarkSelectedConfidential", "iScanAndReport",
         "iShowConfidentialVars", "iIsConfidentialCell",
         "$confidentialSymbols"},
      {"\:30d1\:30ec\:30c3\:30c8", "Palette", "palette"} ->
        {"ShowClaudePalette", "iClaudePaletteButton",
         "iInsertClaudeQueryTemplate", "iInsertClaudeEvalTemplate",
         "iInsertContinueEvalTemplate"},
      {"\:30bb\:30c3\:30b7\:30e7\:30f3", "Session", "session", "\:5c65\:6b74"} ->
        {"CreateClaudeSession", "ClaudeShowHistory", "ClaudeListSessions",
         "iSessionTag", "iSessionAppend", "iSessionHistory",
         "iSessionToContext", "iSessionHistoryWithInherit"},
      {"\:30af\:30a8\:30ea", "Query", "query", "\:8cea\:554f"} ->
        {"ClaudeQuery", "iClaudeQueryRaw",
         "iClaudeQueryAsyncWithProgress"},
      {"Eval", "\:8a55\:4fa1", "\:5b9f\:884c", "\:30bf\:30b9\:30af"} ->
        {"ClaudeEval", "ContinueEval", "iClaudeEvalImpl", "iContinueEvalImpl", "iScheduleAt"},
      {"\:30d0\:30c3\:30af\:30a2\:30c3\:30d7", "\:30ea\:30b9\:30c8\:30a2", "\:66f4\:65b0", "Update", "Restore"} ->
        {"ClaudeUpdatePackage", "ClaudeRestorePackage",
         "ClaudeUpdatePackageHistory", "ClaudeBackupDataset", "ClaudeConvertToPaclet", "ClaudeCreateDocumentation", "ClaudeUpdateDocumentation", "ClaudeCreatePackage",
         "iExtractFunctions", "iGuessTargetFunctions", "iExpandWithDeps"},
      {"\:30ce\:30fc\:30c8\:30d6\:30c3\:30af", "\:30b3\:30f3\:30c6\:30ad\:30b9\:30c8", "Notebook", "context"} ->
        {"iCaptureNotebookContext", "nbPrint", "cellToText"},
      {"\:30d7\:30ed\:30f3\:30d7\:30c8", "prompt", "Prompt"} ->
        {"iNormalizePrompt", "iExpandSymbolRefs", "iDescribeSymbol",
         "$claudeQueryPrefix", "$claudeMathPromptPrefix"},
      {"\:4ed5\:69d8", "Spec", "spec", "\:30b9\:30da\:30c3\:30af"} ->
        {"ClaudeSpec", "iClaudeSpecImpl", "$claudeSpecPrefix", "$specCellOpts",
         "iCollectCellContent", "iRunClaudeEvalFromCells", "iRunClaudeQueryFromCells", "iRunClaudeSpecFromCells"},
      {"\:30c7\:30d0\:30c3\:30b0", "\:30ec\:30d3\:30e5\:30fc", "Debug", "Review"} ->
        {"ClaudeDebug", "ClaudeReview"},
      {"Directive", "\:30c7\:30a3\:30ec\:30af\:30c6\:30a3\:30d6", "CLAUDE.md", "SKILL", "\:30b9\:30ad\:30eb"} ->
        {"ClaudeAddDirective", "ClaudeRestoreDirective", "ClaudeListDirectives",
         "ClaudeDirectiveBackupDataset",
         "iDirectivesSourceDir", "iDirectiveFilePath", "iBackupDirectiveFile",
         "iLatestDirectiveBackup", "iRunInstallClaudeDirectives"}
    };

    kwHits = Flatten[
      Cases[kwMap,
        Rule[kws_List, funcs_List] /;
          AnyTrue[kws, StringContainsQ[prompt, #] &] :> funcs
      ]
    ];

    (* \:82f1\:8a9e\:30de\:30c3\:30c1 + \:30ad\:30fc\:30ef\:30fc\:30c9\:30de\:30c3\:30c1\:3092\:7d71\:5408\:3057\:3001\:5b9f\:5728\:3059\:308b\:95a2\:6570\:540d\:306e\:307f *)
    hits = Union[hits, Select[kwHits, MemberQ[allFuncNames, #] &]];
    hits
  ];


(* \:4e3b\:95a2\:6570\:304c\:547c\:3073\:51fa\:3059\:30d8\:30eb\:30d1\:30fc\:3082\:542b\:3081\:308b *)
iExpandWithDeps[targets_List, blocks_Association] :=
  Module[{allNames = Keys[blocks], result = targets, scan},
    scan = targets;
    Scan[Function[fn,
      Module[{body, called},
        body  = Lookup[blocks, fn, ""];
        called = Select[allNames, fn =!= # && StringContainsQ[body, #] &];
        result = Union[result, called]
      ]
    ], scan];
    result
  ];

Options[ClaudeCreatePackage] = {Fallback -> False};

ClaudeCreatePackage[packageName_String, packagePrompt_, opts:OptionsPattern[]] := (
    $currentUseFallback = TrueQ[OptionValue[Fallback]];
  With[{nb = EvaluationNotebook[]},
  Module[{destFile, prompt, beginMark, endMark, sessionDir, bdir, timestamp,
          packagePromptNorm, imgDirs, jobId},
  iPrecisionConfidentialCheck[nb];

  destFile = FileNameJoin[{Global`$packageDirectory, packageName <> ".wl"}];
  If[FileExistsQ[destFile] || iPacletQ[packageName],
    nbPrint[nb, "\:30a8\:30e9\:30fc: \:30d1\:30c3\:30b1\:30fc\:30b8\:304c\:65e2\:306b\:5b58\:5728\:3057\:307e\:3059: " <> packageName <>
      "\n\:4e0a\:66f8\:304d\:3057\:305f\:3044\:5834\:5408\:306f ClaudeUpdatePackage \:3092\:4f7f\:3063\:3066\:304f\:3060\:3055\:3044\:3002"]; Return[$Failed]];

  packagePromptNorm = iNormalizePrompt[packagePrompt];
  imgDirs = packagePromptNorm["imageDirs"];
  timestamp = DateString[Now, {"Year","Month","Day","_","Hour24","Minute","Second"}];

  (* セクションヘッダーを入力セルの直前に挿入 *)
  iWriteSectionHeaderBeforeEvalCell[nb,
    "\:25b6 ClaudeCreatePackage: " <> packageName <>
    " (" <> DateString[Now, {"Year", "/", "Month", "/", "Day", " ", "Hour24", ":", "Minute"}] <> ")"];

  bdir      = backupDir[packageName];
  sessionDir = FileNameJoin[{bdir, timestamp}];
  CreateDirectory[sessionDir, CreateIntermediateDirectories -> True];

  (* design / references フォルダ作成 *)
  Quiet @ CreateDirectory[iDesignDir[packageName], CreateIntermediateDirectories -> True];
  Quiet @ CreateDirectory[iReferencesDir[packageName], CreateIntermediateDirectories -> True];
  (* デザインテンプレートをコピーして name/prompt を挿入 *)
  Module[{tmpl, designNb},
    tmpl = FileNameJoin[{Global`$packageDirectory, "Templates", "design_template.nb"}];
    designNb = FileNameJoin[{iDesignDir[packageName], packageName <> "_design.nb"}];
    If[FileExistsQ[tmpl] && !FileExistsQ[designNb],
      CopyFile[tmpl, designNb];
      NBAccess`NBInsertTextCells[designNb, packageName, packagePromptNorm["text"]]]];

  beginMark = "===BEGIN_PACKAGE==="; endMark = "===END_PACKAGE===";
  prompt =
    "You are an expert Wolfram Language / Mathematica programmer.\n" <>
    "CRITICAL INSTRUCTION: Do NOT write any files. Do NOT use any file-writing tools.\n" <>
    "You MUST output the complete package source code to stdout, wrapped in markers.\n" <>
    "Your response MUST start with " <> beginMark <> " on the very first line.\n" <>
    "Do NOT write any text before " <> beginMark <> ".\n" <>
    "After " <> endMark <> " you may add a brief explanation.\n\n" <>
    "Create a Mathematica package named `" <> packageName <> ".wl`.\n" <>
    "Requirements:\n" <>
    "- Use BeginPackage[\"" <> packageName <> "`\"] / EndPackage[]\n" <>
    "- Export all public functions and variables with ::usage definitions\n" <>
    "- Implement all logic inside Begin[\"" <> packageName <> "`Private`\"] / End[]\n" <>
    "- At the end, after End[] and EndPackage[], add a load message:\n" <>
    "    Print[Style[\"" <> packageName <> " \\:30d1\\:30c3\\:30b1\\:30fc\\:30b8 \\[LongDash] \\:4f7f\\:3044\\:65b9\", Bold]];\n" <>
    "    Print[\"  FuncA[args] \\[RightArrow] \\:8aac\\:660e\\n\" <> ...]\n" <>
    "  (list each exported function with a one-line description, same style as ClaudeCode package)\n" <>
    "- Use UTF-8. All Japanese strings must use \\:XXXX Unicode escapes.\n" <>
    "- Do NOT use Clear[\"Global`*\"] or session-prefixed variable names.\n\n" <>
    "Output format (MANDATORY):\n" <>
    beginMark <> "\n<complete package source code here>\n" <> endMark <> "\n" <>
    "(optional brief explanation after the end marker)\n\n" <>
    "SPECIFICATION:\n" <> packagePromptNorm["text"];

  iSaveSessionMedia[sessionDir, prompt, imgDirs];

  jobId = NBAccess`NBBeginJobAtEvalCell[nb];
  iClaudeQueryAsyncWithProgress[prompt,
    With[{nb2 = nb, bm = beginMark, em = endMark,
          sf = destFile, sd = sessionDir, pn = packageName, jid = jobId},
      Function[response,
        Module[{newCode, newWlFile, codeBlocks, strm2},
          Export[FileNameJoin[{sd, "response.txt"}], response, "Text"];
          If[StringStartsQ[response, "Error (ExitCode="] || StringStartsQ[response, "Error:"],
            NBAccess`NBAbortJob[jid, "Claude \:547c\:3073\:51fa\:3057\:30a8\:30e9\:30fc"];
            Return[]];
          (* API エラー/制限メッセージの早期検出 — ファイル破損防止 *)
          If[iIsAPIErrorResponse[response],
            NBAccess`NBAbortJob[jid,
              "\:26d4 API \:30a8\:30e9\:30fc\:307e\:305f\:306f\:5229\:7528\:5236\:9650\:3092\:691c\:51fa\:3002\:30d1\:30c3\:30b1\:30fc\:30b8\:306f\:4f5c\:6210\:3055\:308c\:307e\:305b\:3093\:3002\n" <>
              StringTake[response, UpTo[200]]];
            Return[$Failed]];
          (* \:30de\:30fc\:30ab\:30fc\:62bd\:51fa\:3092\:8a66\:884c *)
          newCode = iStripCodeFences[iExtractBetweenMarkers[response, bm, em]];
          (* \:30d5\:30a9\:30fc\:30eb\:30d0\:30c3\:30af: \:30de\:30fc\:30ab\:30fc\:306a\:3057\:306a\:3089 ```mathematica \:30d6\:30ed\:30c3\:30af\:304b\:3089\:62bd\:51fa *)
          If[newCode === "" || !StringContainsQ[newCode, "BeginPackage"],
            codeBlocks = StringCases[response,
              RegularExpression["```(?:mathematica|wolfram)?\\n([\\s\\S]*?)```"] :> "$1"];
            If[Length[codeBlocks] > 0,
              newCode = StringJoin[Riffle[codeBlocks, "\n\n"]]]];
          (* \:691c\:8a3c: BeginPackage \:304c\:542b\:307e\:308c\:3066\:3044\:308b\:304b *)
          If[newCode === "" || !StringContainsQ[newCode, "BeginPackage"],
            NBAccess`NBAbortJob[jid,
              "\:30a8\:30e9\:30fc: \:6709\:52b9\:306a\:30d1\:30c3\:30b1\:30fc\:30b8\:30b3\:30fc\:30c9\:3092\:62bd\:51fa\:3067\:304d\:307e\:305b\:3093\:3067\:3057\:305f\:3002\nresponse.txt: " <>
              FileNameJoin[{sd, "response.txt"}]];
            Return[]];
          newWlFile = FileNameJoin[{sd, pn <> ".wl"}];
          (* UTF-8 \:30d0\:30a4\:30ca\:30ea\:66f8\:304d\:8fbc\:307f\:ff08ShiftJIS \:74b0\:5883\:5bfe\:7b56\:ff09 *)
          strm2 = OpenWrite[newWlFile, BinaryFormat -> True];
          BinaryWrite[strm2, ToCharacterCode[newCode, "UTF-8"]];
          Close[strm2];
          (* \:30d5\:30a1\:30a4\:30eb\:30b5\:30a4\:30ba\:30c1\:30a7\:30c3\:30af *)
          With[{newSz = FileByteCount[newWlFile],
                oldSz = If[FileExistsQ[sf], FileByteCount[sf], 0]},
            If[oldSz > 0 && newSz < oldSz * 0.5,
              nbPrint[nb2, "\:26a0 \:30ef\:30fc\:30cb\:30f3\:30b0: \:65b0\:30d5\:30a1\:30a4\:30eb\:306e\:30b5\:30a4\:30ba(" <> ToString[newSz] <>
                " bytes)\:304c\:65e7\:30d5\:30a1\:30a4\:30eb(" <> ToString[oldSz] <>
                " bytes)\:306e50%\:672a\:6e80!"]
            ]
          ];
          NBAccess`NBJobMoveToAnchor[jid];
          If[Quiet @ Check[(CopyFile[newWlFile, sf, OverwriteTarget -> False]; True),
                False] && FileExistsQ[sf],
            nbPrint[nb2, "\:30d1\:30c3\:30b1\:30fc\:30b8\:3092\:4f5c\:6210\:3057\:307e\:3057\:305f: " <> sf];
            Block[{Print = Function[{args}, nbPrint[nb2, args]]},
              Quiet @ Get[sf]];
            nbPrint[nb2, "\:30ed\:30fc\:30c9\:3057\:307e\:3057\:305f\:3002"];
            (* api.md を自動生成 *)
            iAutoUpdateApiMd[nb2, pn],
            nbPrint[nb2, "\:8b66\:544a: \:66f8\:304d\:8fbc\:307f\:5931\:6557\:3002\:624b\:52d5\:3067\:30b3\:30d4\:30fc\:3057\:3066\:304f\:3060\:3055\:3044:\n" <>
              "  " <> newWlFile]];
          NBAccess`NBEndJob[jid]
        ]
      ]
    ],
    nb, imgDirs, jobId]
  ]]);

Options[ClaudeUpdatePackage] = {TargetFunctions -> Automatic, StartTime -> Now, Fallback -> False, "UpdateApiMd" -> False};

(* ContinueUpdate 用: 直前の ClaudeUpdatePackage 呼び出し情報を保持 *)
If[!AssociationQ[$iLastUpdateInfo], $iLastUpdateInfo = <||>];
$iContinueUpdateFlag = False;  (* ContinueUpdate から呼ばれた場合に True *)

ClaudeUpdatePackage[packageName_String, updatePrompt_, opts:OptionsPattern[]] := (
  $currentUseFallback = TrueQ[OptionValue[Fallback]];
  (* ContinueUpdate 用に呼び出し情報を記録 *)
  $iLastUpdateInfo = <|
    "packageName" -> packageName,
    "prompt" -> updatePrompt,
    "options" -> {opts},
    "time" -> Now
  |>;
  With[{st = OptionValue[StartTime], updateApi = TrueQ[OptionValue["UpdateApiMd"]]},
  iScheduleAt[
  iClaudeUpdatePackageImpl[packageName, updatePrompt,
    OptionValue[TargetFunctions], updateApi],
  st]]);

iClaudeUpdatePackageImpl[packageName_String, updatePrompt_, targetFuncsOpt_, updateApiMd_:True] :=
  With[{nb = EvaluationNotebook[]},
  Module[{srcFile, currentCode, prompt,
          beginMark, endMark, timestamp, sessionDir, bdir,
          allBlocks, allNames, targets, targetCode,
          jsPlaceholder, jsBlock, updatePromptNorm, imgDirs, jobId},

  iPrecisionConfidentialCheck[nb];
  srcFile = iPackageSourceFile[packageName];
  If[!FileExistsQ[srcFile],
    nbPrint[nb, "\:30d5\:30a1\:30a4\:30eb\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093: " <> srcFile]; Return[$Failed]];

  (* 排他ロック: 同一パッケージの並列更新を防止 *)
  If[!iAcquirePackageLock[packageName, nb], Return[$Failed]];

  (* references フォルダを参照可能にする *)
  iEnsureReferencesAccessible[packageName];

  (* セクションヘッダーを入力セルの直前に挿入 *)
  iWriteSectionHeaderBeforeEvalCell[nb,
    If[TrueQ[$iContinueUpdateFlag],
      "\:25b6 ContinueUpdate: ",
      "\:25b6 ClaudeUpdatePackage: "] <> packageName <>
    " (" <> DateString[Now, {"Year", "/", "Month", "/", "Day", " ", "Hour24", ":", "Minute"}] <> ")"];

  (* Job システム: 出力をEvalCell直後に配置 *)
  jobId = NBAccess`NBBeginJobAtEvalCell[nb];

  updatePromptNorm = iNormalizePrompt[updatePrompt];
  imgDirs = updatePromptNorm["imageDirs"];
  currentCode = Import[srcFile, "Text"];
  timestamp   = DateString[Now, {"Year","Month","Day","_","Hour24","Minute","Second"}] <>
    If[TrueQ[$iContinueUpdateFlag], "_continue", ""];
  bdir        = backupDir[packageName];

  (* \:2500\:2500 \:6bce\:56de\:306e\:4e8b\:524d\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:ff08\:5fc5\:305a\:5b9f\:884c\:ff09\:2500\:2500 *)
  Module[{preDir},
    preDir = FileNameJoin[{bdir, "pre_" <> timestamp}];
    CreateDirectory[preDir, CreateIntermediateDirectories -> True];
    iSaveBackupWl[preDir, srcFile, packageName, True];
    nbPrint[nb, "\:4e8b\:524d\:30d0\:30c3\:30af\:30a2\:30c3\:30d7: " <> preDir]
  ];

  sessionDir = FileNameJoin[{bdir, timestamp}];
  CreateDirectory[sessionDir, CreateIntermediateDirectories -> True];

  (* JS\:30d7\:30ec\:30fc\:30b9\:30db\:30eb\:30c0\:30fc\:51e6\:7406 *)
  jsPlaceholder = "(* %%JS_SOURCE_DO_NOT_MODIFY%% *)";
  jsBlock = First[StringCases[currentCode,
    RegularExpression["(?s)(\\$JSSource\\s*=\\s*\".*?\"\\s*;)"] :> "$1"], ""];
  If[jsBlock =!= "",
    currentCode = StringReplace[currentCode, jsBlock -> jsPlaceholder, 1]];

  (* \:95a2\:6570\:5358\:4f4d\:306b\:5206\:89e3 *)
  allBlocks = iExtractFunctions[currentCode];
  allNames  = Keys[allBlocks];

  (* \:5bfe\:8c61\:95a2\:6570\:3092\:6c7a\:5b9a *)
  targets = targetFuncsOpt;
  If[targets === Automatic,
    targets = iGuessTargetFunctions[updatePromptNorm["userText"], allNames]];
  (* \:4f9d\:5b58\:95a2\:6570\:3082\:5c55\:958b *)
  If[Length[targets] > 0,
    targets = iExpandWithDeps[targets, allBlocks]];

  If[Length[targets] === 0,
    nbPrint[nb, "\:5bfe\:8c61\:95a2\:6570\:3092\:81ea\:52d5\:5224\:5b9a\:3067\:304d\:307e\:305b\:3093\:3067\:3057\:305f\:3002\:30d5\:30a1\:30a4\:30eb\:5168\:4f53\:3092\:9001\:4fe1\:3057\:307e\:3059\:3002"];
    targetCode = currentCode,
    nbPrint[nb, "\:5bfe\:8c61\:95a2\:6570: " <> StringRiffle[targets, ", "]];
    targetCode = ToString[StringJoin[Lookup[allBlocks, #, ""] & /@ targets]]
  ];

  beginMark = "===BEGIN_FUNCTIONS==="; endMark = "===END_FUNCTIONS===";
  prompt =
    "You are an expert Wolfram Language / Mathematica programmer.\n" <>
    "CRITICAL: Do NOT write any files. Do NOT use file-writing tools. Output to stdout ONLY.\n" <>
    iLoadPackageHistory[bdir, packageName] <>
    If[iLoadPackageHistory[bdir, packageName] =!= "", "\n", ""] <>
    If[Length[targets] === 0,
      (* targets未判定: ファイル全体を送信する場合 *)
      "Below is the COMPLETE source of the Mathematica package `" <> packageName <> ".wl`.\n" <>
      "Modify ONLY the functions that need to change according to the instruction.\n" <>
      "Return ONLY the modified function definitions (not the entire file).\n" <>
      "IMPORTANT: Do NOT return the entire file. Return ONLY the functions you actually changed.\n" <>
      "All unchanged functions will be preserved automatically by the merge system.\n",
      (* targets判定済み: 選択した関数のみ送信 *)
      "Below are selected function definitions from the Mathematica package `" <> packageName <> ".wl`.\n" <>
      "Modify them according to the instruction. Return ONLY the modified functions.\n"
    ] <>
    "Your response MUST start with " <> beginMark <> " on the very first line.\n" <>
    "Do NOT write any explanation or text before " <> beginMark <> ".\n" <>
    "After " <> endMark <> " you may add optional explanation.\n\n" <>
    "INSTRUCTION: " <> iExpandSymbolRefs[updatePromptNorm["userText"]] <> "\n\n" <>
    (* \:6dfb\:4ed8\:30d5\:30a1\:30a4\:30eb\:304c\:3042\:308c\:3070\:5225\:30bb\:30af\:30b7\:30e7\:30f3\:3067\:53c2\:7167\:6307\:793a *)
    If[Length[updatePromptNorm["filePaths"]] > 0,
      "ATTACHMENTS (use the Read tool to view each file):\n" <>
      StringJoin[MapIndexed[
        Function[{fp, idx}, "  " <> ToString[First[idx]] <> ". " <> fp <> "\n"],
        updatePromptNorm["filePaths"]]] <> "\n",
      ""] <>
    If[Length[targets] === 0,
      "COMPLETE SOURCE (modify only what is needed):\n",
      "CURRENT FUNCTIONS:\n"
    ] <>
    beginMark <> "\n" <> ToString[targetCode] <> "\n" <> endMark;

  iSaveSessionMedia[sessionDir, prompt, imgDirs];

  iClaudeQueryAsyncWithProgress[prompt,
    With[{nb2=nb, sd=sessionDir, pn=packageName, sf=srcFile,
          blks=allBlocks, tgts=targets, jp=jsPlaceholder, jb=jsBlock,
          bm=beginMark, em=endMark, origCode=Import[srcFile, "Text"],
          doUpdateApi=updateApiMd, jid=jobId},
      Function[response,
        Module[{newFuncs, newCode, newWlFile, validationErrors = {}},
          (* アンカーの直後に出力を配置 *)
          NBAccess`NBJobMoveToAnchor[jid];
          (* コールバック完了時に必ずロック解放するラッパー *)
          Internal`WithLocalSettings[Null,

          Export[FileNameJoin[{sd, "response.txt"}], response, "Text"];
          (* ContinueUpdate 用: レスポンスとセッションDirを記録 *)
          If[AssociationQ[$iLastUpdateInfo] && Lookup[$iLastUpdateInfo, "packageName", ""] === pn,
            AssociateTo[$iLastUpdateInfo, {
              "response" -> response,
              "sessionDir" -> sd,
              "cellCountAfter" -> NBAccess`NBCellCount[nb2]
            }]];
          If[StringStartsQ[response, "Error (ExitCode="] || StringStartsQ[response, "Error:"],
            nbPrint[nb2, "Claude \:547c\:3073\:51fa\:3057\:30a8\:30e9\:30fc:\n" <> response]; Return[]];
          (* API エラー/制限メッセージの早期検出 — ファイル破損防止 *)
          If[iIsAPIErrorResponse[response],
            nbPrint[nb2, Style["\:26d4 API \:30a8\:30e9\:30fc\:307e\:305f\:306f\:5229\:7528\:5236\:9650\:3092\:691c\:51fa\:3002\:30d1\:30c3\:30b1\:30fc\:30b8\:306f\:66f4\:65b0\:3055\:308c\:307e\:305b\:3093\:3002\n" <>
              StringTake[response, UpTo[200]], Bold, FontColor -> RGBColor[0.8, 0, 0]]];
            Return[$Failed]];
          (* \:30c7\:30ea\:30df\:30bf\:62bd\:51fa\:3092\:8a66\:884c *)
          newFuncs = {iExtractBetweenMarkers[response, bm, em]};
          newFuncs = Select[newFuncs, # =!= "" &];
          (* \:30d5\:30a9\:30fc\:30eb\:30d0\:30c3\:30af: \:30c7\:30ea\:30df\:30bf\:306a\:3057\:306a\:3089 ```mathematica \:30d6\:30ed\:30c3\:30af\:304b\:3089\:62bd\:51fa *)
          If[Length[newFuncs] === 0,
            Module[{codeBlocks},
              codeBlocks = StringCases[response,
                RegularExpression["```(?:mathematica|wolfram)?\n([\\s\\S]*?)```"] :> "$1"];
              If[Length[codeBlocks] > 0,
                nbPrint[nb2, "\:30c7\:30ea\:30df\:30bf\:306a\:3057 \:2192 \:30b3\:30fc\:30c9\:30d6\:30ed\:30c3\:30af\:304b\:3089\:62bd\:51fa (" <>
                  ToString[Length[codeBlocks]] <> " \:30d6\:30ed\:30c3\:30af)"];
                newFuncs = {StringJoin[Riffle[codeBlocks, "\n\n"]]},
                nbPrint[nb2, "\:30a8\:30e9\:30fc: \:30c7\:30ea\:30df\:30bf\:3082\:30b3\:30fc\:30c9\:30d6\:30ed\:30c3\:30af\:3082\:898b\:3064\:304b\:308a\:307e\:305b\:3093\:3002response.txt: " <>
                  FileNameJoin[{sd, "response.txt"}]]; Return[]
              ]
            ]
          ];
          newFuncs = First[newFuncs];

          (* --- マージロジック (targets の有無にかかわらず常にマージを試みる) --- *)
          newCode = Module[{code = origCode, updBlks, mergedCount = 0,
                            newOnlyFuncs = {}, respIsFullFile},
            If[jb =!= "", code = StringReplace[code, jb -> jp, 1]];
            updBlks = iExtractFunctions[newFuncs];

            (* レスポンスが全ファイルか部分か判定: BeginPackage を含むなら全ファイル *)
            respIsFullFile = StringContainsQ[newFuncs, "BeginPackage["] &&
                             StringContainsQ[newFuncs, "EndPackage["] &&
                             StringLength[newFuncs] > StringLength[origCode] * 0.7;

            If[respIsFullFile && Length[tgts] === 0,
              (* Claude が全ファイルを返した場合: そのまま採用 *)
              nbPrint[nb2, "\:30ec\:30b9\:30dd\:30f3\:30b9\:306f\:5b8c\:5168\:306a\:30d5\:30a1\:30a4\:30eb\:3067\:3059\:3002\:305d\:306e\:307e\:307e\:63a1\:7528\:3057\:307e\:3059\:3002"];
              code = If[jb =!= "", StringReplace[newFuncs, jp -> jb, 1], newFuncs],
              (* 部分的なレスポンス: 関数単位でマージ *)
              Scan[Function[fn,
                Module[{oldDef, newDef},
                  oldDef = Lookup[blks, fn, ""];
                  newDef = Lookup[updBlks, fn, ""];
                  If[oldDef =!= "" && newDef =!= "",
                    code = StringReplace[code, oldDef -> newDef, 1];
                    mergedCount++,
                    (* 元コードに無い新関数 *)
                    If[oldDef === "" && newDef =!= "",
                      AppendTo[newOnlyFuncs, fn]]
                  ]
                ]
              ], Keys[updBlks]];
              (* 新規関数があれば EndPackage[] の直前に挿入 *)
              If[Length[newOnlyFuncs] > 0,
                Module[{insertCode},
                  insertCode = StringJoin[
                    Lookup[updBlks, #, ""] & /@ newOnlyFuncs];
                  code = StringReplace[code,
                    RegularExpression["(\\n\\s*End\\[\\]\\s*;?\\s*\\n\\s*EndPackage\\[\\])"] :>
                    "\n" <> insertCode <> "$1", 1];
                  nbPrint[nb2, "\:65b0\:898f\:95a2\:6570\:3092\:8ffd\:52a0: " <>
                    StringRiffle[newOnlyFuncs, ", "]]
                ]
              ];
              If[mergedCount > 0,
                nbPrint[nb2, "\:30de\:30fc\:30b8\:5b8c\:4e86: " <> ToString[mergedCount] <>
                  " \:500b\:306e\:95a2\:6570\:3092\:66f4\:65b0"],
                (* マージできなかった場合の警告 *)
                If[Length[Keys[updBlks]] > 0 && mergedCount === 0,
                  nbPrint[nb2, Style[
                    "\:26a0 \:30de\:30fc\:30b8\:5931\:6557: \:30ec\:30b9\:30dd\:30f3\:30b9\:306e\:95a2\:6570\:304c\:5143\:30b3\:30fc\:30c9\:306b\:5bfe\:5fdc\:3057\:307e\:305b\:3093\:3067\:3057\:305f\:3002\n" <>
                    "\:30ec\:30b9\:30dd\:30f3\:30b9\:95a2\:6570: " <> StringRiffle[Keys[updBlks], ", "],
                    FontColor -> RGBColor[0.8, 0.4, 0]]]]
              ];
              If[jb =!= "", code = StringReplace[code, jp -> jb, 1]];
            ];
            code
          ];

          (* \:5b89\:5168\:6027\:691c\:8a3c *)
          Module[{newSz, oldSz, origFuncCount, newFuncCount,
                  hasBegin, hasEnd, origHasBegin},
            newSz = StringLength[newCode];
            oldSz = StringLength[origCode];
            origFuncCount = Length[iExtractFunctions[origCode]];
            newFuncCount  = Length[iExtractFunctions[newCode]];
            origHasBegin  = StringContainsQ[origCode, "BeginPackage["];
            hasBegin      = StringContainsQ[newCode, "BeginPackage["];
            hasEnd        = StringContainsQ[newCode, "EndPackage["];

            If[oldSz > 0 && newSz < oldSz * 0.5,
              AppendTo[validationErrors,
                "\:30b5\:30a4\:30ba\:6025\:6e1b: " <> ToString[oldSz] <> " \[RightArrow] " <>
                ToString[newSz] <> " chars (" <>
                ToString[Round[100. newSz / oldSz]] <> "%)"]];
            If[origFuncCount > 3 && newFuncCount < origFuncCount * 0.5,
              AppendTo[validationErrors,
                "\:95a2\:6570\:6570\:6025\:6e1b: " <> ToString[origFuncCount] <> " \[RightArrow] " <>
                ToString[newFuncCount]]];
            If[origHasBegin && !hasBegin,
              AppendTo[validationErrors, "BeginPackage[] \:304c\:6b20\:843d"]];
            If[origHasBegin && !hasEnd,
              AppendTo[validationErrors, "EndPackage[] \:304c\:6b20\:843d"]];
          ];

          newWlFile = FileNameJoin[{sd, pn <> ".wl"}];
          (* UTF-8 \:30d0\:30a4\:30ca\:30ea\:66f8\:304d\:8fbc\:307f\:ff08ShiftJIS \:74b0\:5883\:5bfe\:7b56\:ff09 *)
          Module[{strm3},
            strm3 = OpenWrite[newWlFile, BinaryFormat -> True];
            BinaryWrite[strm3, ToCharacterCode[newCode, "UTF-8"]];
            Close[strm3]];
          nbPrint[nb2, "\:65b0\:30d0\:30fc\:30b8\:30e7\:30f3\:3092\:4fdd\:5b58: " <> newWlFile];

          If[Length[validationErrors] > 0,
            nbPrint[nb2,
              "\:26d4 \:5b89\:5168\:691c\:8a3c\:5931\:6557 \:2014 \:30d1\:30c3\:30b1\:30fc\:30b8\:3078\:306e\:4e0a\:66f8\:304d\:3092\:30d6\:30ed\:30c3\:30af\:3057\:307e\:3057\:305f\:3002\n" <>
              StringJoin[("  \:274c " <> # <> "\n") & /@ validationErrors] <>
              "\n\:65b0\:30d0\:30fc\:30b8\:30e7\:30f3: " <> newWlFile <>
              "\n\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:304b\:3089\:5fa9\:5143\:53ef\:80fd\:3067\:3059\:3002" <>
              "\n\n\:5185\:5bb9\:3092\:78ba\:8a8d\:3057\:3066\:554f\:984c\:306a\:3051\:308c\:3070\:3001\:624b\:52d5\:3067\:30b3\:30d4\:30fc\:3057\:3066\:304f\:3060\:3055\:3044\:3002"];
            Return[$Failed]
          ];

          If[Quiet @ Check[(CopyFile[newWlFile, sf, OverwriteTarget -> True]; True),
                False] && FileExistsQ[sf],
            nbPrint[nb2, "\:30d1\:30c3\:30b1\:30fc\:30b8\:3092\:66f4\:65b0\:3057\:307e\:3057\:305f: " <> sf];
            Block[{Print = Function[{args}, nbPrint[nb2, args]]},
              Quiet @ Get[sf]];
            nbPrint[nb2, "\:518d\:30ed\:30fc\:30c9\:3057\:307e\:3057\:305f\:3002"];
            With[{afterEnd2 = StringTrim[Last[StringSplit[response, em, 2], ""]]},
              If[afterEnd2 =!= "", nbPrint[nb2, afterEnd2]]];
            (* api.md を自動更新: オンなら自動実行 *)
            If[doUpdateApi, iAutoUpdateApiMd[nb2, pn]];
            (* ContinueUpdate フラグをリセット *)
            $iContinueUpdateFlag = False;
            (* 完了メッセージ: クリック可能なアクション付き *)
            iWriteUpdateCompletionMessage[nb2, pn, doUpdateApi],
            nbPrint[nb2, "\:8b66\:544a: \:66f8\:304d\:8fbc\:307f\:5931\:6557\:3002\:624b\:52d5\:3067\:30b3\:30d4\:30fc\:3057\:3066\:304f\:3060\:3055\:3044:\n" <>
              "  \:5143: " <> newWlFile <> "\n  \:5148: " <> sf]]

          , (* Internal`WithLocalSettings cleanup *)
          $iContinueUpdateFlag = False;
          NBAccess`NBEndJob[jid];
          iReleasePackageLock[pn]]
        ]
      ]
    ],
    nb, imgDirs, jobId]
  ]];

ClaudeRestorePackage[packageName_String] :=
  With[{nb = EvaluationNotebook[]},
  Module[{bdir, sessionDirs, latestDir, latestFile, destFile, currentMD5},
    bdir = backupDir[packageName];
    If[!DirectoryQ[bdir],
      nbPrint[nb, "\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:30d5\:30a9\:30eb\:30c0\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093: " <> bdir]; Return[$Failed]];
    sessionDirs = Sort[Select[FileNames["*", bdir], DirectoryQ]];
    If[Length[sessionDirs] === 0,
      nbPrint[nb, "\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093: " <> bdir]; Return[$Failed]];
    (* \:73fe\:5728\:306e .wl \:3068\:540c\:3058\:5185\:5bb9\:306e\:30d5\:30a9\:30eb\:30c0\:3092\:9664\:3044\:3066\:3001\:305d\:306e\:4e00\:3064\:524d\:3092\:9078\:3076 *)
    destFile = iPackageSourceFile[packageName];
    latestDir = Module[{currentMD5, dirs, wl, md5},
      currentMD5 = If[FileExistsQ[destFile], Hash[Import[destFile,"Text"],"MD5"], None];
      dirs = Reverse[sessionDirs];
      First[Select[dirs, Function[d,
        wl = FileNameJoin[{d, packageName <> ".wl"}];
        FileExistsQ[wl] && Hash[Import[wl,"Text"],"MD5"] =!= currentMD5
      ]], None]
    ];
    If[latestDir === None,
      nbPrint[nb, "\:73fe\:5728\:306e\:30d5\:30a1\:30a4\:30eb\:3068\:7570\:306a\:308b\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093\:3002"]; Return[$Failed]];
    latestFile = FileNameJoin[{latestDir, packageName <> ".wl"}];
    If[!FileExistsQ[latestFile],
      nbPrint[nb, "\:30d0\:30c3\:30af\:30a2\:30c3\:30d7 .wl \:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093: " <> latestFile]; Return[$Failed]];
    With[{newSz = FileByteCount[latestFile],
          oldSz = If[FileExistsQ[destFile], FileByteCount[destFile], 0]},
      If[oldSz > 0 && newSz < oldSz * 0.5,
        nbPrint[nb, "\:26a0 \:30ef\:30fc\:30cb\:30f3\:30b0: \:5fa9\:5143\:30d5\:30a1\:30a4\:30eb(" <> ToString[newSz] <>
          " bytes)\:304c\:73fe\:5728(" <> ToString[oldSz] <>
          " bytes)\:306e50%\:672a\:6e80! \:6b63\:3057\:3044\:30d5\:30a1\:30a4\:30eb\:304b\:78ba\:8a8d\:3057\:3066\:304f\:3060\:3055\:3044!"]
      ]
    ];
    If[Quiet @ Check[(CopyFile[latestFile, destFile, OverwriteTarget -> True]; True),
          False] && FileExistsQ[destFile],
      nbPrint[nb, "\:5fa9\:5143\:3057\:307e\:3057\:305f: " <> latestFile <> "\n\:2192 " <> destFile];
      Quiet @ Get[destFile]; nbPrint[nb, "\:30d1\:30c3\:30b1\:30fc\:30b8\:3092\:518d\:30ed\:30fc\:30c9\:3057\:307e\:3057\:305f\:3002"],
      nbPrint[nb, "\:8b66\:544a: \:66f8\:304d\:8fbc\:307f\:5931\:6557\:3002\:624b\:52d5\:3067\:30b3\:30d4\:30fc\:3057\:3066\:304f\:3060\:3055\:3044:\n" <>
        "  \:5143: " <> latestFile <> "\n  \:5148: " <> destFile]]
  ]];

(* ============================================================
   \:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:81ea\:52d5\:751f\:6210: .wl \:30d1\:30c3\:30b1\:30fc\:30b8\:304b\:3089\:5305\:62ec\:7684\:306a\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:4e00\:5f0f\:3092\:751f\:6210
   ============================================================ *)

(* \:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:30ad\:30e5\:30fc\:306e\:5b9a\:7fa9: {outFileName, docTitle, promptTemplate} *)
(* README.md \:306f\:4ed6\:306e\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:3092\:53c2\:7167\:3057\:3066\:6982\:8981\:3092\:751f\:6210\:3059\:308b\:305f\:3081\:6700\:5f8c\:306b\:914d\:7f6e *)
$iDocQueue := {
  {"setup.md", "\:30a4\:30f3\:30b9\:30c8\:30fc\:30eb\:624b\:9806\:66f8",
    "Create a CONCISE setup guide (setup.md) for this package.\n" <>
    iLanguageInstruction["polite"] <>
    "Target: 80-120 lines of Markdown.\n" <>
    "IMPORTANT: Assumes Windows 11 (no WSL2). For macOS/Linux, add ONE line: " <>
    "'macOS/Linux \:3067\:306f\:30d1\:30b9\:533a\:5207\:308a\:3084\:30b7\:30a7\:30eb\:30b3\:30de\:30f3\:30c9\:3092\:9069\:5b9c\:8aad\:307f\:66ff\:3048\:3066\:304f\:3060\:3055\:3044'.\n" <>
    "Include ONLY: Mathematica version, external tools, installation steps, " <>
    "API key setup, verification. No lengthy explanations.\n" <>
    "IMPORTANT $Path and package loading rules:\n" <>
    "- All .wl packages are stored DIRECTLY in $packageDirectory (not in subdirectories).\n" <>
    "- $Path must include $packageDirectory itself, NOT package-specific subdirectories.\n" <>
    "- CORRECT: AppendTo[$Path, $packageDirectory]\n" <>
    "- WRONG: AppendTo[$Path, \"C:\\\\path\\\\to\\\\PackageName\"] — this is INCORRECT.\n" <>
    "- The development environment assumes UTF-8. Show this loading pattern:\n" <>
    "  Block[{$CharacterEncoding = \"UTF-8\"},\n" <>
    "    Needs[\"PackageName`\", \"PackageName.wl\"]];\n" <>
    "  (The filename-only form 'PackageName.wl' works because $packageDirectory is on $Path.)\n" <>
    "- If using claudecode, $Path is set up automatically.\n" <>
    "- For packages with many config variables (like claudecode/NBAccess),\n" <>
    "  list the essential config variables and a minimal working example.\n" <>
    "Format: Markdown."},
  {"user_manual.md", "\:30e6\:30fc\:30b6\:30fc\:30de\:30cb\:30e5\:30a2\:30eb",
    "Create a CONCISE user manual (user_manual.md) for this package.\n" <>
    iLanguageInstruction["polite"] <>
    "Target: 150-250 lines of Markdown.\n" <>
    "Cover each public function with: 1-line description, signature, " <>
    "1 concrete example. Group by category.\n" <>
    "Do NOT repeat information already in setup.md.\n" <>
    "Do NOT explain internal implementation details.\n" <>
    "Format: Markdown with short code examples."},
  {"api.md", "API \:30ea\:30d5\:30a1\:30ec\:30f3\:30b9",
    "Create an LLM-optimized API reference (api.md) for this package.\n" <>
    "This file is read by LLMs for code generation, NOT by humans.\n" <>
    "An LLM reading ONLY this file must write correct code using the package.\n\n" <>
    "CRITICAL FORMAT RULES (token-efficient, high density):\n" <>
    "- Minimize blank lines: only 1 before ## section headings. No blank lines between function entries.\n" <>
    "- Do NOT use --- separators between entries.\n" <>
    "- Do NOT use bold labels like **引数:** or **戻り値:**.\n" <>
    "- Do NOT add usage examples for trivial functions (e.g. getters with obvious signatures).\n" <>
    "- Only add examples for functions with complex options or non-obvious usage patterns.\n\n" <>
    iLanguageInstruction["plain"] <> "\n" <>
    "FORMAT for constants/variables:\n" <>
    "### $VarName\n" <>
    "\:578b: Type, \:521d\:671f\:5024: value\n" <>
    "\:8aac\:660e\:6587 (1\:884c)\n\n" <>
    "FORMAT for simple functions (no options):\n" <>
    "### FuncName[arg1, arg2] \:2192 ReturnType\n" <>
    "\:8aac\:660e\:6587 (1\:884c)\n\n" <>
    "FORMAT for functions with options:\n" <>
    "### FuncName[arg1, arg2, opts]\n" <>
    "\:8aac\:660e\:6587 (1\:884c)\n" <>
    "\:2192 ReturnType (\:69cb\:9020\:306e\:8aac\:660e\:304c\:5fc5\:8981\:306a\:3089\:8ffd\:8a18)\n" <>
    "Options: Opt1 -> Default1 (\:8aac\:660e), Opt2 -> Default2 (\:8aac\:660e)\n\n" <>
    "FORMAT for complex functions (example needed):\n" <>
    "### FuncName[arg1, opts]\n" <>
    "\:8aac\:660e\:6587\n" <>
    "\:2192 <|\"Key1\" -> ..., \"Key2\" -> ...|>\n" <>
    "Options: Opt1 -> Default1 (\:8aac\:660e), Opt2 -> Default2 (\:8aac\:660e)\n" <>
    "\:4f8b: FuncName[\"pkg\", \"msg\", Branch -> \"dev\"]\n\n" <>
    "STRUCTURE:\n" <>
    "- Group by category with ## headings\n" <>
    "- Use ### for each function heading\n" <>
    "- List ALL public functions and ALL options. Completeness is critical.\n" <>
    "- Do NOT omit any public function or option.\n" <>
    "Format: Markdown."},
  {"examples/example.md", "\:4f7f\:7528\:4f8b\:96c6",
    "Create a CONCISE examples document (examples/example.md).\n" <>
    iLanguageInstruction["polite"] <>
    "Target: 80-150 lines of Markdown.\n" <>
    "Include 5-8 practical examples covering the main use cases.\n" <>
    "Each example: title, 2-5 lines of code, 1-line expected output.\n" <>
    "Do NOT explain what each function does (that is in the manual).\n" <>
    "Format: Markdown with ```mathematica code blocks."},
  (* README.md \:306f\:6700\:5f8c: \:4ed6\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:306e\:5185\:5bb9\:3092\:53c2\:7167\:3057\:3066\:6982\:8981\:3092\:751f\:6210\:3059\:308b *)
  {"README.md", "README",
    "SPECIAL_README_WITH_OVERVIEW"}
};

(* ドキュメント応答のクリーンアップ:
   1. コードフェンスを除去
   2. LLM が付ける前置きテキスト（「以下が setup.md の内容です」等）を除去 *)
iCleanDocResponse[response_String] :=
  Module[{s = response, pos},
    (* コードフェンスの除去 *)
    s = StringReplace[s, RegularExpression["^```(?:markdown|md)?\\s*\n"] -> ""];
    s = StringReplace[s, RegularExpression["\n```\\s*$"] -> ""];
    (* 前置き除去: 最初の # または --- の前のテキストを削除 *)
    If[!StringStartsQ[StringTrim[s], "#" | "---"],
      pos = StringPosition[s, RegularExpression["(?m)^(#|---)"], 1];
      If[Length[pos] > 0,
        s = StringDrop[s, pos[[1, 1]] - 1]]];
    s
  ];

(* ============================================================
   ドキュメント応答の正当性検証 (ポジティブ検証方式)
   エラーメッセージのパターンマッチではなく、
   「正しいドキュメント内容か」をポジティブに検証する。
   ============================================================ *)

(* ドキュメントとして有効な応答かを検証する。
   True を返す場合のみファイル書き込みを許可する。 *)
iIsValidDocContent[response_String] :=
  Module[{cleaned, trimmed},
    (* 非文字列または空 → 無効 *)
    If[!StringQ[response] || StringTrim[response] === "", Return[False]];
    (* 明示的なエラーメッセージ → 無効 *)
    If[StringStartsQ[response, "Error"], Return[False]];
    (* クリーンアップ後に検証 *)
    cleaned = iCleanDocResponse[response];
    trimmed = StringTrim[cleaned];
    (* 最低限のサイズ要件: 正常なドキュメントは少なくとも 100 文字 *)
    If[StringLength[trimmed] < 100, Return[False]];
    (* Markdown ヘッダーまたはフロントマター(---) で始まる *)
    If[StringStartsQ[trimmed, "#" | "---"], Return[True]];
    (* Markdown ヘッダーを含む (先頭以外にある場合) *)
    If[StringContainsQ[cleaned, RegularExpression["(?m)^#{1,3} "]], Return[True]];
    (* いずれにも該当しない → 無効 (エラーメッセージの可能性大) *)
    False
  ];

iIsValidDocContent[_] := False;

(* 安全なドキュメント書き込み: 検証 → クリーンアップ → 書き込み。
   無効な応答の場合はファイルを一切変更せず $Failed を返す。 *)
iSafeWriteDoc[destPath_String, response_String] :=
  Module[{cleaned},
    If[!iIsValidDocContent[response],
      Return[$Failed]];
    cleaned = iCleanDocResponse[response];
    Export[destPath, cleaned, "Text", CharacterEncoding -> "UTF-8"];
    destPath
  ];

(* 3引数版: 更新時のファイル破損防止ガード付き。
   packageName を使って (1) サイズ退行 (2) タイトル整合性 を検証する。 *)
iSafeWriteDoc[destPath_String, response_String, packageName_String] :=
  Module[{cleaned, existingContent, existingLen, newLen, docFileName,
          existingTitle, newTitle},
    (* 基本的なコンテンツ検証 *)
    If[!iIsValidDocContent[response],
      Return[$Failed]];
    cleaned = iCleanDocResponse[response];
    docFileName = FileNameTake[destPath];
    (* === ガード1: サイズ退行チェック === *)
    (* 既存ファイルが存在する場合、新しい内容が既存の 40% 未満なら拒否 *)
    If[FileExistsQ[destPath],
      existingContent = Quiet @ Check[Import[destPath, "Text"], ""];
      If[StringQ[existingContent] && StringLength[existingContent] > 200,
        existingLen = StringLength[existingContent];
        newLen = StringLength[StringTrim[cleaned]];
        If[newLen < existingLen * 0.4,
          Print["⚠ iSafeWriteDoc: サイズ退行を検出 (" <> docFileName <> "): " <>
            ToString[existingLen] <> " → " <> ToString[newLen] <>
            " 文字 (" <> ToString[Round[100. newLen / existingLen]] <> "%)。書き込みを拒否しました。"];
          Return[$Failed]
        ]
      ]
    ];
    (* === ガード2: タイトル整合性チェック (README.md のみ) === *)
    (* README.md の先頭 # タイトルがパッケージ名と完全に異なる場合は拒否 *)
    If[docFileName === "README.md",
      newTitle = iExtractDocTitle[cleaned];
      If[StringQ[newTitle] && StringLength[newTitle] > 0,
        If[!StringContainsQ[ToLowerCase[newTitle], ToLowerCase[packageName]],
          Print["⚠ iSafeWriteDoc: タイトル不整合を検出 (README.md): " <>
            "期待=\"" <> packageName <> "\", 実際=\"" <> newTitle <>
            "\"。書き込みを拒否しました。"];
          Return[$Failed]
        ]
      ]
    ];
    Export[destPath, cleaned, "Text", CharacterEncoding -> "UTF-8"];
    destPath
  ];

(* ドキュメントの先頭 # タイトル行を抽出する補助関数 *)
iExtractDocTitle[content_String] :=
  Module[{match},
    match = StringCases[content,
      RegularExpression["(?m)^# +(.+)$"] :> "$1", 1];
    If[Length[match] > 0,
      StringTrim[First[match]],
      ""
    ]
  ];

(* 後方互換エイリアス *)
iIsDocLimitError[response_String] := !iIsValidDocContent[response];

(* README.md 用の特別プロンプトを構築: 他ドキュメントの内容を読み込んで概要生成 *)

(* 参考文献・デモ動画情報をプロンプト用テキストに変換 *)
iDocBuildRefSection[packageName_String] :=
  Module[{refs, demos, result = ""},
    refs = Replace[iDocGet[packageName, "References"], Except[_List] -> {}];
    demos = Replace[iDocGet[packageName, "Demos"], Except[_List] -> {}];
    If[Length[refs] > 0,
      result = result <>
        "\n=== REFERENCES (add to README under '## \:53c2\:8003\:6587\:732e' section) ===\n" <>
        "Look up each URL/title below and add with proper title and description.\n" <>
        "For URLs: fetch the page title and write a 1-line description.\n" <>
        "For book titles: add author and publisher if inferable.\n" <>
        StringRiffle["- " <> ToString[#] & /@ refs, "\n"] <> "\n"
    ];
    If[Length[demos] > 0,
      result = result <>
        "\n=== DEMOS / USAGE EXAMPLES (add to README under '## \:4f7f\:7528\:4f8b\:30fb\:30c7\:30e2' section) ===\n" <>
        "For each URL: infer the content type (video, article, notebook, etc.),\n" <>
        "write a 1-line description, and format as a clickable Markdown link.\n" <>
        "Group by type if multiple items exist.\n" <>
        StringRiffle["- " <> ToString[#] & /@ demos, "\n"] <> "\n"
    ];
    result
  ];

(* 指示文テキストを生成用プロンプトに変換 *)
iDocGlobalInstructionPrompt[packageName_String] :=
  Module[{instr = iDocGet[packageName, "GlobalInstruction"]},
    If[StringQ[instr] && StringTrim[instr] =!= "",
      "\n=== GLOBAL INSTRUCTION FROM USER ===\n" <>
      "Follow this instruction when generating ALL documentation files:\n" <>
      instr <> "\n\n",
      ""
    ]
  ];

(* $packageDirectory 内の全パッケージの GitHub URL 一覧をプロンプト用に構築 *)
iBuildGitHubLinksContext[] :=
  Module[{urls, lines},
    urls = Quiet @ Check[GitHubREST`GitHubPackageURLs[], <||>];
    If[!AssociationQ[urls] || Length[urls] === 0, Return[""]];
    lines = KeyValueMap[
      Function[{name, url},
        If[StringQ[url] && StringStartsQ[url, "http"],
          "- " <> name <> ": " <> url,
          Nothing]],
      urls];
    If[Length[lines] === 0, Return[""]];
    "\n=== GITHUB REPOSITORY URLs (CRITICAL — use ONLY these URLs) ===\n" <>
    "CRITICAL RULE: When the documentation mentions ANY package by name as a dependency\n" <>
    "or related package, you MUST use the exact URL from the list below.\n" <>
    "NEVER fabricate, guess, or invent GitHub URLs. URLs like github.com/imai-laboratory/...\n" <>
    "or github.com/username/PackageName are WRONG unless listed below.\n" <>
    "If a package is NOT in this list, do NOT create a link — just mention the name as plain text.\n\n" <>
    StringRiffle[lines, "\n"] <> "\n\n"
  ];


(* _info/design/ フォルダの設計メモを読み込む (README の設計思想セクション用) *)
iReadDesignMemos[packageName_String] :=
  Module[{pkgDir, designDir, files, content},
    pkgDir = Global`$packageDirectory;
    designDir = FileNameJoin[{pkgDir, packageName <> "_info", "design"}];
    If[!DirectoryQ[designDir],
      (* Paclet 形式も試す *)
      designDir = FileNameJoin[{pkgDir, packageName, "design"}]];
    If[!DirectoryQ[designDir], Return[""]];
    files = FileNames[{"*.md", "*.txt", "*.wl"}, designDir];
    If[Length[files] === 0, Return[""]];
    content = StringJoin[
      ("--- design/" <> FileNameTake[#] <> " ---\n" <>
       StringTake[Quiet @ Check[Import[#, "Text"], ""], UpTo[2000]] <>
       "\n\n") & /@ Take[files, UpTo[5]]];
    "\n=== DESIGN MEMOS (low priority reference for '設計思想' section) ===\n" <>
    "These are informal design notes. Use them ONLY to supplement the\n" <>
    "documentation and source code. Priority: docs > code > these memos.\n" <>
    content
  ];

(* ドキュメント生成用モデルオーバーライド: $ClaudeDocModel が設定されていればそちらを使用 *)
iDocModelOverride[] :=
  If[StringQ[$ClaudeDocModel] && $ClaudeDocModel =!= "",
    $ClaudeDocModel, $ClaudeModel];

(* 更新指示が狭いスコープ（ライセンス・免責・謝辞のみ）かを判定 *)
iIsNarrowScopeInstruction[instruction_String] :=
  AnyTrue[{"\:30e9\:30a4\:30bb\:30f3\:30b9", "License", "\:514d\:8cac", "Disclaimer", "\:8b1d\:8f9e", "Acknowledgment"},
    StringContainsQ[instruction, #, IgnoreCase -> True] &] &&
  !AnyTrue[{"\:95a2\:6570", "API", "\:6a5f\:80fd", "\:30a4\:30f3\:30b9\:30c8\:30fc\:30eb", "\:4f7f\:3044\:65b9", "\:4f8b"},
    StringContainsQ[instruction, #, IgnoreCase -> True] &];

(* 差分が小さい場合のコンパクトなソースコンテキスト生成 *)
iCompactSourceForUpdate[sourceCode_String, split_Association, docFile_String,
    diffText_String] :=
  Module[{diffLineCount, added, removed},
    (* 差分行数を推定 *)
    added = StringCount[diffText, "\n", Overlaps -> False];
    (* 差分が小さい（< 200行）場合はチャンク化ソースで十分 *)
    If[added < 200 && docFile =!= "api.md",
      iBuildChunkedSource[split, docFile],
      (* api.md または大きな差分: フルソースだがチャンク化 *)
      iBuildChunkedSource[split, docFile]
    ]
  ];

(* 謝辞セクションのプロンプト *)
iDocBuildAcknowledgmentsPrompt[packageName_String] :=
  Module[{items},
    items = Replace[iDocGet[packageName, "Acknowledgments"], Except[_List] -> {}];
    If[Length[items] === 0, Return[""]];
    "\n=== ACKNOWLEDGMENTS SECTION (add BEFORE 免責事項 in README.md) ===\n" <>
    "Add a '## 謝辞' section in README.md, placed BEFORE 免責事項.\n" <>
    "Include the following acknowledgments:\n" <>
    StringRiffle["- " <> ToString[#] & /@ items, "\n"] <> "\n" <>
    "Write each item as a clear, natural sentence.\n"
  ];

(* 免責事項セクションのプロンプト *)
iDocBuildDisclaimerPrompt[packageName_String] :=
  Module[{extras, base},
    base = "本ソフトウェアは \"as is\"（現状有姿）で提供されており、明示・黙示を問わずいかなる保証もありません。\n" <>
      "本ソフトウェアの使用または使用不能から生じるいかなる損害についても責任を負いません。\n" <>
      "今後の動作保証のための更新が行われるとは限りません。\n" <>
      "本ソフトウェアとドキュメントはほぼすべてが生成AIによって生成されたものです。\n" <>
      "Windows 11上での実行を想定しており、MacOS, LinuxのMathematicaでの動作検証は一切していません(生成AIの処理で対応可能と想定されます)。";
    extras = Replace[iDocGet[packageName, "Disclaimer"], Except[_List] -> {}];
    "\n=== DISCLAIMER SECTION (add AFTER 謝辞 if present, BEFORE ライセンス in README.md) ===\n" <>
    "Add a '## 免責事項' section in README.md with this text:\n" <>
    base <> "\n" <>
    If[Length[extras] > 0,
      "Additionally, rephrase and add these items:\n" <>
      StringRiffle["- " <> ToString[#] & /@ extras, "\n"] <> "\n",
      ""
    ]
  ];

(* ライセンスセクションのプロンプト *)
iDocBuildLicensePrompt[packageName_String] :=
  Module[{holder, licText, yearStr, createdYear, currentYear, docLicense},
    docLicense = iDocGet[packageName, "License"];
    (* License オプションに文字列が指定されていればそれを使用 *)
    If[StringQ[docLicense] && StringTrim[docLicense] =!= "",
      Return[
        "\n=== LICENSE SECTION (MUST add at the very end of README.md, after 免責事項) ===\n" <>
        "Add a '## \:30e9\:30a4\:30bb\:30f3\:30b9' section.\n" <>
        "CRITICAL: The license text below is a LEGAL document. Copy it VERBATIM.\n" <>
        "Do NOT translate, paraphrase, or modify any wording.\n" <>
        "Insert the following text exactly as-is:\n\n" <>
        "```\n" <> docLicense <> "\n```\n"]];
    (* $GitHubLicenseHolder を取得 *)
    holder = Quiet @ Check[GitHubREST`$GitHubLicenseHolder, ""];
    If[!StringQ[holder] || StringTrim[holder] === "",
      (* 名前が空 → 警告を出してライセンスは挿入しない *)
      Print[Style["\:8b66\:544a: $GitHubLicenseHolder \:304c\:8a2d\:5b9a\:3055\:308c\:3066\:3044\:306a\:3044\:305f\:3081\:3001\:30e9\:30a4\:30bb\:30f3\:30b9\:30bb\:30af\:30b7\:30e7\:30f3\:306f\:633f\:5165\:3055\:308c\:307e\:305b\:3093\:3002\n" <>
        "$GitHubLicenseHolder = \"Your Name\" \:3092\:8a2d\:5b9a\:3057\:3066\:304f\:3060\:3055\:3044\:3002",
        FontColor -> RGBColor[0.8, 0.4, 0]]];
      Return[""]];
    (* 年の範囲を計算 *)
    currentYear = DateString[Now, "Year"];
    (* リポジトリ作成年を推定: ドキュメントフォルダの作成日 or 現在年 *)
    createdYear = currentYear;  (* デフォルト *)
    yearStr = If[createdYear === currentYear,
      currentYear,
      createdYear <> "-" <> currentYear];
    licText = "MIT License\n\n" <>
      "Copyright (c) " <> yearStr <> " " <> holder <> "\n\n" <>
      "Permission is hereby granted, free of charge, to any person obtaining a copy " <>
      "of this software and associated documentation files (the \"Software\"), to deal " <>
      "in the Software without restriction, including without limitation the rights " <>
      "to use, copy, modify, merge, publish, distribute, sublicense, and/or sell " <>
      "copies of the Software, and to permit persons to whom the Software is " <>
      "furnished to do so, subject to the following conditions:\n\n" <>
      "The above copyright notice and this permission notice shall be included in all " <>
      "copies or substantial portions of the Software.\n\n" <>
      "THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR " <>
      "IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, " <>
      "FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE " <>
      "AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER " <>
      "LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, " <>
      "OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.";
    "\n=== LICENSE SECTION (MUST add at the very end of README.md, after \:514d\:8cac\:4e8b\:9805) ===\n" <>
    "Add a '## \:30e9\:30a4\:30bb\:30f3\:30b9' section.\n" <>
    "CRITICAL: The license text below is a LEGAL document. You MUST copy it VERBATIM in English.\n" <>
    "Do NOT translate it into other languages. Do NOT paraphrase. Do NOT modify any wording.\n" <>
    "Insert the following text exactly as-is:\n\n" <>
    "```\n" <> licText <> "\n```\n\n" <>
    "IMPORTANT: When updating an existing README, if a license section already exists,\n" <>
    "update the year range to end with " <> currentYear <> " (e.g. 2025-" <> currentYear <> ").\n" <>
    "Do NOT change the holder name or license text.\n"
  ];

iBuildReadmePrompt[sourceCode_String, packageName_String, outDir_String] :=
  Module[{docFiles, docsContent, docSummaries},
    docFiles = Select[FileNames["*.md", {outDir, FileNameJoin[{outDir, "examples"}]}],
      FileNameTake[#] =!= "README.md" &];
    docsContent = StringJoin[
      ("--- " <> FileNameTake[#] <> " ---\n" <>
       StringTake[Import[#, "Text"], UpTo[3000]] <> "\n\n") & /@ docFiles];
    "You are an expert Wolfram Language / Mathematica documentation writer.\n" <>
    "CRITICAL: Do NOT write any files. Do NOT use file-writing tools. Output to stdout ONLY.\n" <>
    "You are creating a comprehensive README.md for the package \"" <> packageName <> "\".\n\n" <>
    iLanguageInstruction["polite"] <> "\n" <>
    "The README should have the following structure:\n\n" <>
    "1. FIRST HALF - \"\:8a2d\:8a08\:601d\:60f3\:3068\:5b9f\:88c5\:306e\:6982\:8981\" (Design Philosophy and Implementation Overview):\n" <>
    "   Based on the documentation files listed below, summarize the design philosophy\n" <>
    "   and implementation overview of this package. This should be a coherent narrative\n" <>
    "   explaining WHY the package is designed this way and HOW it works at a high level.\n" <>
    "   Include: package name and one-line description, then the design/implementation overview.\n\n" <>
    "2. SECOND HALF - \"\:8a73\:7d30\:8aac\:660e\" (Detailed Description):\n" <>
    "   - Requirements (Mathematica version, OS, external tools)\n" <>
    "   - Installation instructions:\n" <>
    "     CRITICAL $Path rule: All .wl packages reside DIRECTLY in $packageDirectory.\n" <>
    "     $Path must include $packageDirectory itself. CORRECT: AppendTo[$Path, $packageDirectory]\n" <>
    "     WRONG: AppendTo[$Path, \"C:\\\\path\\\\to\\\\PackageName\"] — NEVER use package-specific paths.\n" <>
    "     If using claudecode, $Path is set automatically.\n" <>
    "     MUST include this UTF-8 loading pattern:\n" <>
    "     Block[{$CharacterEncoding = \"UTF-8\"},\n" <>
    "       Needs[\"PackageName`\", \"PackageName.wl\"]];\n" <>
    "     The filename-only form 'PackageName.wl' works because $packageDirectory is on $Path.\n" <>
    "   - Quick start example (MUST be self-contained: a reader should be able\n" <>
    "     to use the package by reading ONLY the README. For packages with many\n" <>
    "     config variables, list the essential ones with defaults.)\n" <>
    "   - Main features list with brief descriptions\n" <>
    "   - Links to other documentation files\n\n" <>
    "Use proper Markdown heading hierarchy:\n" <>
    "# <package name>\n" <>
    "## \:8a2d\:8a08\:601d\:60f3\:3068\:5b9f\:88c5\:306e\:6982\:8981\n" <>
    "...\n" <>
    "## \:8a73\:7d30\:8aac\:660e\n" <>
    "### \:52d5\:4f5c\:74b0\:5883\n" <>
    "### \:30a4\:30f3\:30b9\:30c8\:30fc\:30eb\n" <>
    "### \:30af\:30a4\:30c3\:30af\:30b9\:30bf\:30fc\:30c8\n" <>
    "### \:4e3b\:306a\:6a5f\:80fd\n" <>
    "### \:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:4e00\:89a7\n" <>
    "## \:4f7f\:7528\:4f8b\:30fb\:30c7\:30e2 (MUST use this exact section name; " <>
    "place Demo URLs and usage examples here)\n" <>
    If[Length[Replace[iDocGet[packageName, "References"], Except[_List] -> {}]] > 0,
      "## \:53c2\:8003\:6587\:732e\n", ""] <>
    If[Length[Replace[iDocGet[packageName, "Acknowledgments"], Except[_List] -> {}]] > 0,
      "## \:8b1d\:8f9e\n", ""] <>
    "## \:514d\:8cac\:4e8b\:9805\n" <>
    "## \:30e9\:30a4\:30bb\:30f3\:30b9\n" <>
    "\n" <>
    "CRITICAL: NEVER fabricate or guess GitHub URLs for dependencies.\n" <>
    "Use ONLY the exact URLs provided in the 'GITHUB REPOSITORY URLs' section below.\n" <>
    "If a package URL is not listed there, mention the package name as plain text without a link.\n\n" <>
    "Output ONLY the Markdown content directly as your response text.\n" <>
    "Do NOT wrap in code fences. Do NOT ask for file permissions.\n\n" <>
    "=== EXISTING DOCUMENTATION (for overview synthesis) ===\n" <>
    docsContent <> "\n" <>
    iDocBuildRefSection[packageName] <>
    iBuildGitHubLinksContext[] <>
    iReadDesignMemos[packageName] <>
    iDocBuildAcknowledgmentsPrompt[packageName] <>
    iDocBuildDisclaimerPrompt[packageName] <>
    iDocBuildLicensePrompt[packageName] <>
    "=== PACKAGE SOURCE CODE (summary) ===\n" <>
    StringTake[sourceCode, UpTo[$ClaudeDocMaxChunkChars]]
  ];


(* ============================================================
   \:30bd\:30fc\:30b9\:30b3\:30fc\:30c9\:5206\:5272: \:5927\:304d\:306a\:30bd\:30fc\:30b9\:3092\:30c1\:30e3\:30f3\:30af\:306b\:5206\:5272\:3057\:30c8\:30fc\:30af\:30f3\:6d88\:8cbb\:3092\:6291\:5236
   ============================================================ *)

(* \:30bd\:30fc\:30b9\:30b3\:30fc\:30c9\:3092\:516c\:958b\:90e8\:3068 Private \:30bb\:30af\:30b7\:30e7\:30f3\:7fa4\:306b\:5206\:5272 *)
iSplitSource[sourceCode_String] :=
  Module[{lines, publicEnd, publicCode, privateCode, sections, sectionStarts,
          sectionTitles, i, title},
    lines = StringSplit[sourceCode, "\n"];
    publicEnd = FirstPosition[lines,
      _String?(StringContainsQ[#, "Begin[\"`Private`\"]"] &),
      {Length[lines]}, {1}][[1]];
    publicCode = StringRiffle[lines[[;; Min[publicEnd, Length[lines]]]], "\n"];
    If[publicEnd >= Length[lines],
      Return[<|"public" -> publicCode, "sections" -> {},
               "toc" -> "(\:30bb\:30af\:30b7\:30e7\:30f3\:306a\:3057)"|>]];
    privateCode = lines[[publicEnd + 1 ;;]];
    sectionStarts = {};
    sectionTitles = {};
    Do[
      If[StringContainsQ[privateCode[[j]], "============"],
        title = If[j + 1 <= Length[privateCode],
          StringTrim[StringReplace[privateCode[[j + 1]],
            {"(*" -> "", "*)" -> "", "=" -> ""}]],
          ""];
        If[StringLength[title] > 2,
          AppendTo[sectionStarts, j];
          AppendTo[sectionTitles, title]]],
    {j, Length[privateCode]}];
    sections = {};
    Do[
      Module[{startLine, endLine, sCode},
        startLine = sectionStarts[[k]];
        endLine = If[k < Length[sectionStarts],
          sectionStarts[[k + 1]] - 1, Length[privateCode]];
        sCode = StringRiffle[privateCode[[startLine ;; endLine]], "\n"];
        AppendTo[sections, <|"title" -> sectionTitles[[k]],
          "code" -> sCode, "chars" -> StringLength[sCode]|>]],
    {k, Length[sectionStarts]}];
    <|"public" -> publicCode, "sections" -> sections,
      "toc" -> StringRiffle[
        MapIndexed["[" <> ToString[#2[[1]]] <> "] " <> #1["title"] <>
          " (" <> ToString[#1["chars"]] <> " chars)" &, sections], "\n"]|>
  ];

(* \:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:7a2e\:5225\:3054\:3068\:306e\:95a2\:9023\:30bb\:30af\:30b7\:30e7\:30f3\:30ad\:30fc\:30ef\:30fc\:30c9 *)
$iDocSectionKW = <|
  "setup.md" -> {"\:521d\:671f\:5316", "\:30c7\:30a3\:30ec\:30af\:30c8\:30ea", "node-pty"},
  "user_manual.md" -> {"\:30b3\:30a2\:547c\:3073\:51fa\:3057", "\:975e\:540c\:671f", "\:30d1\:30ec\:30c3\:30c8", "\:30bb\:30c3\:30b7\:30e7\:30f3",
                        "\:30c7\:30a3\:30ec\:30af\:30c6\:30a3\:30d6", "Web", "Mathematica"},
  "api.md" -> {"\:30b3\:30a2\:547c\:3073\:51fa\:3057", "\:30bb\:30c3\:30b7\:30e7\:30f3", "\:30c7\:30a3\:30ec\:30af\:30c6\:30a3\:30d6", "Web"},
  "examples/example.md" -> {"\:30b3\:30a2\:547c\:3073\:51fa\:3057", "\:30bb\:30c3\:30b7\:30e7\:30f3", "Web"},
  "README.md" -> {}
|>;

(* \:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:7528\:30c1\:30e3\:30f3\:30af\:5316\:30d7\:30ed\:30f3\:30d7\:30c8\:3092\:69cb\:7bc9 *)
iBuildChunkedSource[split_Association, docFile_String] :=
  Module[{pub, secs, kws, selIdx, sel, total, maxC, perS, result},
    pub = split["public"];
    secs = split["sections"];
    maxC = $ClaudeDocMaxChunkChars;
    kws = Lookup[$iDocSectionKW, docFile, {}];
    selIdx = If[kws === {}, {},
      Select[Range[Length[secs]],
        Function[si, AnyTrue[kws,
          Function[kw, StringContainsQ[secs[[si]]["title"], kw, IgnoreCase -> True]]]]]];
    sel = secs[[selIdx]];
    total = StringLength[pub] + Total[#["chars"] & /@ sel];
    If[total > maxC && Length[sel] > 0,
      perS = Max[2000, Floor[(maxC - StringLength[pub]) / Length[sel]]];
      sel = (<|#, "code" -> StringTake[#["code"], UpTo[perS]] <>
        "\n(* ... \:4ee5\:964d\:7701\:7565 *)" |>) & /@ sel];
    result = "=== Public symbols ===\n" <> pub <> "\n\n" <>
      "=== Section index ===\n" <> split["toc"] <> "\n\n";
    If[Length[sel] > 0,
      result = result <> StringRiffle[
        ("--- " <> #["title"] <> " ---\n" <> #["code"]) & /@ sel, "\n\n"],
      result = result <> "(Generate from public symbols and section index only)\n"];
    If[StringLength[result] > maxC,
      result = StringTake[result, maxC] <> "\n(* ... truncated *)"];
    result
  ];

(* \:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:3092\:9806\:6b21\:751f\:6210\:3059\:308b\:518d\:5e30\:95a2\:6570 (retryCount \:4ed8\:304d) *)
iGenDocNext[sourceCode_String, packageName_String, nb_NotebookObject,
    outDir_String, queue_List, idx_Integer, retryCount_Integer:0,
    splitCache_Association:<||>] :=
  Module[{spec, outFile, docTitle, promptTemplate, fullPrompt, subDir,
          split, chunked},
    If[idx > Length[queue],
      (* ドキュメントオプションを永続化 *)
      iSaveDocOptions[packageName];
      nbPrint[nb, "\:2705 \:5168\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:306e\:751f\:6210\:304c\:5b8c\:4e86\:3057\:307e\:3057\:305f\:3002\n\:51fa\:529b\:5148: " <> outDir];
      Return[]];
    spec = queue[[idx]];
    {outFile, docTitle, promptTemplate} = spec;
    subDir = DirectoryName[FileNameJoin[{outDir, outFile}]];
    If[!DirectoryQ[subDir],
      CreateDirectory[subDir, CreateIntermediateDirectories -> True]];
    If[retryCount > 0,
      nbPrint[nb, "\:2500 [" <> ToString[idx] <> "/" <> ToString[Length[queue]] <>
        "] " <> docTitle <> " \:30ea\:30c8\:30e9\:30a4 " <> ToString[retryCount] <> "/" <>
        ToString[$ClaudeDocMaxRetries]],
      nbPrint[nb, "\:2500 [" <> ToString[idx] <> "/" <> ToString[Length[queue]] <>
        "] " <> docTitle <> " (" <> outFile <> ") \:3092\:751f\:6210\:4e2d..."]];
    (* \:30bd\:30fc\:30b9\:5206\:5272 (\:30ad\:30e3\:30c3\:30b7\:30e5\:518d\:5229\:7528) *)
    split = If[splitCache =!= <||>, splitCache, iSplitSource[sourceCode]];
    chunked = iBuildChunkedSource[split, outFile];
    nbPrint[nb, "  (\:30bd\:30fc\:30b9 " <> ToString[StringLength[sourceCode]] <>
      " \:2192 \:30c1\:30e3\:30f3\:30af " <> ToString[StringLength[chunked]] <> " chars)"];
    fullPrompt = If[promptTemplate === "SPECIAL_README_WITH_OVERVIEW",
      iBuildReadmePrompt[sourceCode, packageName, outDir],
      "You are an expert Wolfram Language / Mathematica documentation writer.\n" <>
      "CRITICAL: Do NOT write any files. Do NOT use file-writing tools. Output to stdout ONLY.\n" <>
      "You are documenting the package \"" <> packageName <> "\".\n\n" <>
      "CRITICAL RULE: \:8b1d\:8f9e (Acknowledgments), \:514d\:8cac\:4e8b\:9805 (Disclaimer) and \:30e9\:30a4\:30bb\:30f3\:30b9 (License) sections MUST ONLY exist in README.md.\n" <>
      "Do NOT add any \:8b1d\:8f9e, \:514d\:8cac\:4e8b\:9805 or \:30e9\:30a4\:30bb\:30f3\:30b9 section to this file.\n\n" <>
      iDocGlobalInstructionPrompt[packageName] <>
      iBuildGitHubLinksContext[] <>
      promptTemplate <> "\n\n" <>
      "Output ONLY the Markdown content directly as your response text.\n" <>
      "Do NOT wrap in code fences. Do NOT ask for file permissions.\n" <>
      "Do NOT include ===BEGIN=== / ===END=== markers.\n\n" <>
      "=== PACKAGE SOURCE CODE (chunked) ===\n" <> chunked
    ];
    (* ドキュメント生成用モデルでクエリ実行。
       $ClaudeModel はバッチファイル生成時にのみ参照されるため、
       iClaudeQueryAsyncWithProgress から戻った直後に復元する。
       コールバック内での復元は不要（非同期中に他の操作と干渉するため）。 *)
    Module[{savedModel = $ClaudeModel},
    $ClaudeModel = iDocModelOverride[];
    iClaudeQueryAsyncWithProgress[fullPrompt,
      With[{nb2 = nb, od = outDir, q = queue, i = idx,
            of = outFile, dt = docTitle, sc = sourceCode, pn = packageName,
            rc = retryCount, sp = split},
        Function[response,
          Module[{destPath, writeResult},
            destPath = FileNameJoin[{od, of}];
            writeResult = iSafeWriteDoc[destPath, response];
            If[writeResult =!= $Failed,
              nbPrint[nb2, "  \:2713 " <> dt <> " \:2192 " <> of];
              iGenDocNext[sc, pn, nb2, od, q, i + 1, 0, sp],
              (* 無効な応答: リトライまたは中断 *)
              nbPrint[nb2, "  \:2717 " <> dt <> " \:306e\:751f\:6210\:306b\:5931\:6557 (\:7121\:52b9\:306a\:5fdc\:7b54): " <>
                StringTake[ToString[response], UpTo[200]]];
              If[rc < $ClaudeDocMaxRetries,
                Module[{delaySec = $ClaudeDocRetryDelay, taskObj},
                  nbPrint[nb2, Style[
                    "\:23f3 " <> ToString[delaySec] <> " \:79d2\:5f8c\:306b\:30ea\:30c8\:30e9\:30a4 (" <>
                    ToString[rc + 1] <> "/" <> ToString[$ClaudeDocMaxRetries] <> ")\n" <>
                    "\:672a\:751f\:6210: " <> StringRiffle[q[[i ;; ]][[All, 1]], ", "],
                    Bold, FontColor -> RGBColor[0.6, 0.4, 0]]];
                  taskObj = RunScheduledTask[
                    (iGenDocNext[sc, pn, nb2, od, q, i, rc + 1, sp];
                     Quiet[RemoveScheduledTask[taskObj]]),
                    delaySec]],
                nbPrint[nb2, Style[
                  "\:26a0\:fe0f " <> ToString[$ClaudeDocMaxRetries] <>
                  " \:56de\:30ea\:30c8\:30e9\:30a4\:5931\:6557\:3002\n\:672a\:751f\:6210: " <>
                  StringRiffle[q[[i ;; ]][[All, 1]], ", "] <> "\n" <>
                  "ClaudeCreateDocumentation[\"" <> pn <>
                  "\"] \:3067\:672a\:751f\:6210\:5206\:306e\:307f\:7d9a\:884c\:53ef\:80fd\:3002",
                  Bold, FontColor -> RGBColor[0.8, 0, 0]]]
              ]
            ]
          ]
        ]
      ],
      nb];
    $ClaudeModel = savedModel;
    ] (* end Module savedModel *)
  ];

(* ============================================================
   ドキュメント生成の継続判定: 既存ファイルの整合性チェック
   ============================================================ *)

(* docs 内の既存ファイルが有効かどうかを判定:
   - docs 内ファイルの日時
   - 最新 history/*_documentupdate の日時
   - ソースファイルの更新日時
   を比較し、作りかけ (= ソースより古い docs, または documentupdate より新しいソースがある) を検出 *)
iCheckDocResumption[packageName_String, outDir_String, srcFile_String] :=
  Module[{existingDocs, srcTime, latestBackup, backupTime,
          allQueueFiles, missingFiles, validFiles},
    (* ソースの最終更新時刻 *)
    srcTime = Quiet @ Check[AbsoluteTime[FileDate[srcFile]], 0];
    (* 最新の _documentupdate バックアップ *)
    latestBackup = iFindLatestDocBackup[packageName];
    backupTime = If[StringQ[latestBackup] && DirectoryQ[latestBackup],
      Max[Quiet @ Check[AbsoluteTime[FileDate[#]], 0] & /@
        FileNames["*", latestBackup]],
      0];
    (* キュー内の全ファイル名 *)
    allQueueFiles = $iDocQueue[[All, 1]];
    (* 既存の docs ファイル *)
    existingDocs = Select[allQueueFiles,
      FileExistsQ[FileNameJoin[{outDir, #}]] &];
    missingFiles = Complement[allQueueFiles, existingDocs];
    (* 既存ファイルが backupTime 以降に作成され、かつソースより新しくない場合は
       ソース変更後の新規生成とみなす *)
    validFiles = If[backupTime > 0 && srcTime > backupTime,
      (* ソースが documentupdate より新しい → 全ファイル再生成必要 *)
      {},
      (* ソースが documentupdate 以前 → 既存ファイルはそのまま使える *)
      existingDocs
    ];
    <|"valid" -> validFiles,
      "missing" -> Complement[allQueueFiles, validFiles],
      "isResumption" -> (Length[validFiles] > 0 && Length[Complement[allQueueFiles, validFiles]] > 0),
      "sourceModified" -> (backupTime > 0 && srcTime > backupTime)|>
  ];

Options[ClaudeCreateDocumentation] = {Fallback -> False, References -> {}, Demos -> {}, Disclaimer -> {}, Acknowledgments -> {}, License -> ""};

(* 1\:5f15\:6570\:7248: \:6307\:793a\:306a\:3057 *)
ClaudeCreateDocumentation[packageName_String, opts:OptionsPattern[]] :=
  ClaudeCreateDocumentation[packageName, "", opts];

(* 2\:5f15\:6570\:7248: \:5927\:57df\:7684\:6307\:793a\:4ed8\:304d *)
ClaudeCreateDocumentation[packageName_String, instruction_String, opts:OptionsPattern[]] := (
  $currentUseFallback = TrueQ[OptionValue[Fallback]];
  Module[{urlsInInstr, initDemos},
    initDemos = Replace[OptionValue[Demos], Except[_List] -> {}];
    urlsInInstr = StringCases[instruction,
      RegularExpression["https?://[^\\s\\)\\]\\>\"]+"] :> "$0"];
    initDemos = DeleteDuplicates[Join[initDemos, urlsInInstr]];
    iDocInitState[packageName,
      Replace[OptionValue[References], Except[_List] -> {}],
      initDemos,
      Replace[OptionValue[Disclaimer], Except[_List] -> {}],
      Replace[OptionValue[Acknowledgments], Except[_List] -> {}],
      Replace[OptionValue[License], Except[_String] -> ""],
      instruction];
  ];
  (* 永続化されたオプションをマージ *)
  iLoadAndMergeDocOptions[packageName];
  With[{nb = EvaluationNotebook[]},
  Module[{srcFile, sourceCode, outDir, pkgDir, bdir, histDir, timestamp,
          resumeInfo, filteredQueue},
    iPrecisionConfidentialCheck[nb];
    pkgDir = Global`$packageDirectory;
    If[!StringQ[pkgDir] || pkgDir === "",
      nbPrint[nb, "\:30a8\:30e9\:30fc: $packageDirectory \:304c\:8a2d\:5b9a\:3055\:308c\:3066\:3044\:307e\:305b\:3093\:3002"];
      Return[$Failed]];
    srcFile = Which[
      FileExistsQ[FileNameJoin[{pkgDir, packageName, "Kernel", packageName <> ".wl"}]],
        FileNameJoin[{pkgDir, packageName, "Kernel", packageName <> ".wl"}],
      FileExistsQ[FileNameJoin[{pkgDir, packageName <> ".wl"}]],
        FileNameJoin[{pkgDir, packageName <> ".wl"}],
      True,
        nbPrint[nb, "\:30a8\:30e9\:30fc: \:30d1\:30c3\:30b1\:30fc\:30b8\:30d5\:30a1\:30a4\:30eb\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093\:3002\n" <>
          "  \:691c\:7d22\:30d1\:30b9 1: " <> FileNameJoin[{pkgDir, packageName, "Kernel", packageName <> ".wl"}] <> "\n" <>
          "  \:691c\:7d22\:30d1\:30b9 2: " <> FileNameJoin[{pkgDir, packageName <> ".wl"}] <> "\n" <>
          "  $packageDirectory: " <> pkgDir];
        Return[$Failed]
    ];
    sourceCode = Import[srcFile, "Text"];
    If[!StringQ[sourceCode] || StringTrim[sourceCode] === "",
      nbPrint[nb, "\:30a8\:30e9\:30fc: \:30d5\:30a1\:30a4\:30eb\:3092\:8aad\:307f\:8fbc\:3081\:307e\:305b\:3093: " <> srcFile];
      Return[$Failed]];
    (* references フォルダを参照可能にする *)
    iEnsureReferencesAccessible[packageName];
    (* \:51fa\:529b\:30c7\:30a3\:30ec\:30af\:30c8\:30ea *)
    If[FileExistsQ[FileNameJoin[{pkgDir, packageName, "PacletInfo.wl"}]],
      outDir = FileNameJoin[{pkgDir, packageName, "docs"}],
      outDir = FileNameJoin[{pkgDir, packageName <> "_info", "docs"}]
    ];
    If[!DirectoryQ[outDir],
      CreateDirectory[outDir, CreateIntermediateDirectories -> True]];
    If[!DirectoryQ[FileNameJoin[{outDir, "examples"}]],
      CreateDirectory[FileNameJoin[{outDir, "examples"}],
        CreateIntermediateDirectories -> True]];

    (* ===== 継続判定: 作りかけのドキュメントがあるか ===== *)
    resumeInfo = iCheckDocResumption[packageName, outDir, srcFile];

    (* セクションヘッダーを入力セルの直前に挿入 *)
    iWriteSectionHeaderBeforeEvalCell[nb,
      "\:25b6 ClaudeCreateDocumentation: " <> packageName <>
      " (" <> DateString[Now, {"Year", "/", "Month", "/", "Day", " ", "Hour24", ":", "Minute"}] <> ")"];

    If[resumeInfo["isResumption"] && !resumeInfo["sourceModified"],
      (* 作りかけ → 既存ファイルを保持し、未生成分のみ生成 *)
      filteredQueue = Select[$iDocQueue,
        !MemberQ[resumeInfo["valid"], #[[1]]] &];
      nbPrint[nb, Style["\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:751f\:6210\:7d9a\:884c: " <> packageName, Bold]];
      nbPrint[nb, "\:65e2\:5b58\:30d5\:30a1\:30a4\:30eb (\:518d\:5229\:7528): " <>
        StringRiffle[resumeInfo["valid"], ", "]];
      nbPrint[nb, "\:672a\:751f\:6210 (\:4eca\:56de\:751f\:6210): " <>
        StringRiffle[filteredQueue[[All, 1]], ", "]];
      nbPrint[nb, "\:30bd\:30fc\:30b9: " <> srcFile <>
        " (" <> ToString[StringLength[sourceCode]] <> " chars)\n"],
      (* 新規 or ソース変更後 → 全ファイル生成 *)
      filteredQueue = $iDocQueue;
      (* \:5c65\:6b74\:30d0\:30c3\:30af\:30a2\:30c3\:30d7: _documentupdate \:4ed8\:304d\:30d5\:30a9\:30eb\:30c0\:306b .wl \:3068 docs \:3092\:4fdd\:5b58 *)
      bdir = backupDir[packageName];
      timestamp = DateString[Now, {"Year","Month","Day","Hour24","Minute"}];
      histDir = FileNameJoin[{bdir, timestamp <> "_documentupdate"}];
      CreateDirectory[histDir, CreateIntermediateDirectories -> True];
      Quiet[iSaveBackupWl[histDir, srcFile, packageName]];
      If[DirectoryQ[outDir],
        Scan[Function[f,
          Quiet[iSaveBackupFile[histDir, f, packageName]]],
          Select[FileNames["*", outDir], iFileQ]]];
      (* doc_options.json もバックアップ *)
      Module[{docOptsFile = iDocOptionsPath[packageName]},
        If[FileExistsQ[docOptsFile],
          Quiet[iSaveBackupFile[histDir, docOptsFile, packageName]]]];

      nbPrint[nb, Style["\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:751f\:6210\:958b\:59cb: " <> packageName, Bold]];
      nbPrint[nb, "\:30bd\:30fc\:30b9: " <> srcFile <>
        " (" <> ToString[StringLength[sourceCode]] <> " chars)"];
      nbPrint[nb, "\:51fa\:529b\:5148: " <> outDir];
      nbPrint[nb, "\:30d0\:30c3\:30af\:30a2\:30c3\:30d7: " <> histDir]
    ];
    nbPrint[nb, "\:751f\:6210\:5bfe\:8c61: " <> ToString[Length[filteredQueue]] <> " \:30d5\:30a1\:30a4\:30eb\n"];

    iGenDocNext[sourceCode, packageName, nb, outDir, filteredQueue, 1, 0, <||>]
  ]]);

(* \:30d1\:30c3\:30b1\:30fc\:30b8\:306e\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:3092\:89e3\:6c7a *)
iPackageDocsDir[packageName_String] :=
  Module[{pkgDir = Global`$packageDirectory},
    If[!StringQ[pkgDir] || pkgDir === "", Return[$Failed]];
    If[FileExistsQ[FileNameJoin[{pkgDir, packageName, "PacletInfo.wl"}]],
      FileNameJoin[{pkgDir, packageName, "docs"}],
      FileNameJoin[{pkgDir, packageName <> "_info", "docs"}]
    ]
  ];

(* \:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:304c\:5b58\:5728\:3057\:3001\:304b\:3064\:30bd\:30fc\:30b9\:3088\:308a\:65b0\:3057\:3044\:304b\:3092\:5224\:5b9a *)
iDocsAvailableAndFresh[packageName_String] :=
  Module[{docsDir, srcFile, pkgDir, docFiles, srcTime, docsTime},
    pkgDir  = Global`$packageDirectory;
    docsDir = iPackageDocsDir[packageName];
    If[!StringQ[docsDir] || !DirectoryQ[docsDir], Return[False]];
    docFiles = FileNames["*.md", docsDir];
    If[Length[docFiles] === 0, Return[False]];
    (* \:30bd\:30fc\:30b9\:306e\:6700\:7d42\:66f4\:65b0\:65e5\:6642 *)
    srcFile = Which[
      FileExistsQ[FileNameJoin[{pkgDir, packageName, "Kernel", packageName <> ".wl"}]],
        FileNameJoin[{pkgDir, packageName, "Kernel", packageName <> ".wl"}],
      FileExistsQ[FileNameJoin[{pkgDir, packageName <> ".wl"}]],
        FileNameJoin[{pkgDir, packageName <> ".wl"}],
      True, Return[True]  (* \:30bd\:30fc\:30b9\:4e0d\:660e\:306a\:3089\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:304c\:3042\:308c\:3070\:4f7f\:3046 *)
    ];
    srcTime  = Quiet @ Check[AbsoluteTime[FileDate[srcFile]], 0];
    docsTime = Max[Quiet @ Check[AbsoluteTime[FileDate[#]], 0] & /@ docFiles];
    (* \:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:304c\:30bd\:30fc\:30b9\:3088\:308a\:65b0\:3057\:3044\:5834\:5408\:306e\:307f True *)
    docsTime >= srcTime
  ];

(* \:30bf\:30b9\:30af\:6587\:304b\:3089\:30d1\:30c3\:30b1\:30fc\:30b8\:540d\:3092\:691c\:51fa\:3057\:3001\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:3092\:30b3\:30f3\:30c6\:30ad\:30b9\:30c8\:3068\:3057\:3066\:8fd4\:3059 *)
iPackageDocsContext[task_String] :=
  Module[{pkgDir, wlFiles, pacletDirs, allNames, mentioned, ctx = ""},
    pkgDir = Global`$packageDirectory;
    If[!StringQ[pkgDir] || !DirectoryQ[pkgDir], Return[""]];
    (* $packageDirectory \:5185\:306e\:5168\:30d1\:30c3\:30b1\:30fc\:30b8\:540d\:3092\:53ce\:96c6 *)
    wlFiles = FileNames["*.wl", pkgDir];
    allNames = FileBaseName /@ wlFiles;
    pacletDirs = Select[FileNames["*", pkgDir],
      DirectoryQ[#] && FileExistsQ[FileNameJoin[{#, "PacletInfo.wl"}]] &];
    allNames = DeleteDuplicates[Join[allNames, FileNameTake /@ pacletDirs]];
    (* \:30bf\:30b9\:30af\:6587\:306b\:542b\:307e\:308c\:308b\:30d1\:30c3\:30b1\:30fc\:30b8\:540d\:3092\:691c\:51fa *)
    mentioned = Select[allNames,
      StringContainsQ[task, #, IgnoreCase -> True] &];
    (* \:57fa\:76e4\:30d1\:30c3\:30b1\:30fc\:30b8\:306e\:30ad\:30fc\:30ef\:30fc\:30c9\:691c\:51fa: \:30bf\:30b9\:30af\:6587\:306b\:30d1\:30c3\:30b1\:30fc\:30b8\:540d\:304c\:306a\:304f\:3066\:3082
       \:95a2\:9023\:30ad\:30fc\:30ef\:30fc\:30c9\:304c\:3042\:308c\:3070 api.md \:3092\:30b3\:30f3\:30c6\:30ad\:30b9\:30c8\:306b\:542b\:3081\:308b *)
    Module[{kwMap, pkg, kws, extMap},
      kwMap = {
        "github" -> {"GitHub", "PR", "\:30d7\:30eb\:30ea\:30af\:30a8\:30b9\:30c8", "\:30ea\:30dd\:30b8\:30c8\:30ea",
          "\:30b3\:30df\:30c3\:30c8", "\:30d6\:30e9\:30f3\:30c1", "commit", "push", "pull request",
          "repository", "branch", "merge", "\:30de\:30fc\:30b8"},
        "NBAccess" -> {"NBAccess", "\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:30bb\:30eb", "\:6a5f\:5bc6\:30bb\:30eb",
          "Confidential", "TaggingRules", "CellEpilog"}
      };
      (* 外部パッケージが $ClaudePackageKeywordMap に登録したキーワードをマージ *)
      extMap = If[AssociationQ[$ClaudePackageKeywordMap],
        Normal[$ClaudePackageKeywordMap], {}];
      kwMap = Join[kwMap, extMap];
      Do[
        pkg = kv[[1]]; kws = kv[[2]];
        If[!MemberQ[mentioned, pkg] &&
           AnyTrue[kws, StringContainsQ[task, #, IgnoreCase -> True] &],
          AppendTo[mentioned, pkg]],
        {kv, kwMap}]];
    If[Length[mentioned] === 0, Return[""]];
    (* \:5404\:30d1\:30c3\:30b1\:30fc\:30b8\:306e\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:3092\:30b3\:30f3\:30c6\:30ad\:30b9\:30c8\:306b\:542b\:3081\:308b
       api.md \:3092\:6700\:512a\:5148\:3067\:5b8c\:5168\:306b\:8aad\:307f\:8fbc\:3080\:ff08\:30c8\:30fc\:30af\:30f3\:7bc0\:7d04\:306e\:305f\:3081\:4ed6\:306e\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:306f\:6982\:8981\:306e\:307f\:ff09 *)
    Do[
      With[{docsDir = iPackageDocsDir[pkg]},
      If[StringQ[docsDir] && DirectoryQ[docsDir],
        Module[{docFiles, apiFile, apiContent, summary, isFresh},
          isFresh = iDocsAvailableAndFresh[pkg];
          apiFile = FileNameJoin[{docsDir, "api.md"}];
          Which[
            (* api.md \:304c\:5b58\:5728: api.md \:3092\:30d5\:30eb\:8aad\:307f\:8fbc\:307f\:ff08\:6700\:512a\:5148\:ff09 *)
            FileExistsQ[apiFile],
              apiContent = Quiet @ Check[Import[apiFile, "Text"], ""];
              ctx = ctx <>
                "=== \:30d1\:30c3\:30b1\:30fc\:30b8 API \:30ea\:30d5\:30a1\:30ec\:30f3\:30b9: " <> pkg <> " ===\n" <>
                If[isFresh,
                  "(\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:306f\:30bd\:30fc\:30b9\:30b3\:30fc\:30c9\:3088\:308a\:65b0\:3057\:3044\:305f\:3081\:53c2\:8003\:60c5\:5831\:3068\:3057\:3066\:6709\:52b9)\n",
                  "(\:30bd\:30fc\:30b9\:304c\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:3088\:308a\:65b0\:3057\:3044\:304c\:3001API \:30b7\:30b0\:30cd\:30c1\:30e3\:30fb\:30aa\:30d7\:30b7\:30e7\:30f3\:306f\:6709\:52b9)\n"] <>
                "IMPORTANT: \:30b3\:30fc\:30c9\:3092\:751f\:6210\:3059\:308b\:969b\:306f\:3001\:3053\:306e api.md \:306b\:8a18\:8f09\:3055\:308c\:305f\:95a2\:6570\:540d\:30fb\:30aa\:30d7\:30b7\:30e7\:30f3\:30fb\:5f15\:6570\:306e\:307f\:3092\:4f7f\:7528\:3059\:308b\:3053\:3068\:3002" <>
                "\:5b58\:5728\:3057\:306a\:3044\:95a2\:6570\:3092\:751f\:6210\:3057\:306a\:3044\:3053\:3068\:3002api.md \:3067\:4e0d\:660e\:306a\:70b9\:304c\:3042\:308b\:5834\:5408\:306e\:307f\:30bd\:30fc\:30b9\:30b3\:30fc\:30c9\:3092\:53c2\:7167\:3059\:308b\:3053\:3068\:3002\n\n" <>
                apiContent <> "\n\n",
            (* api.md \:304c\:306a\:3044\:304c\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:304c\:65b0\:9bae: \:5168\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:306e\:6982\:8981 *)
            isFresh,
              docFiles = FileNames["*.md", docsDir];
              summary = StringJoin[
                ("--- " <> FileNameTake[#] <> " ---\n" <>
                 StringTake[Quiet @ Check[Import[#, "Text"], ""], UpTo[2000]] <> "\n\n") & /@
                Take[docFiles, UpTo[5]]];
              ctx = ctx <>
                "=== \:30d1\:30c3\:30b1\:30fc\:30b8\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8: " <> pkg <> " ===\n" <>
                "(\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:306f\:30bd\:30fc\:30b9\:30b3\:30fc\:30c9\:3088\:308a\:65b0\:3057\:3044\:305f\:3081\:53c2\:8003\:60c5\:5831\:3068\:3057\:3066\:6709\:52b9\:3067\:3059)\n" <>
                summary <> "\n"
          ]
        ]]],
    {pkg, mentioned}];
    ctx
  ];

(* ============================================================
   \:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:66f4\:65b0: \:6307\:793a\:306b\:5f93\:3063\:3066\:65e2\:5b58\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:3092\:66f4\:65b0
   ============================================================ *)

(* \:66f4\:65b0\:6307\:793a\:304b\:3089\:8a72\:5f53\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:30d5\:30a1\:30a4\:30eb\:3092\:81ea\:52d5\:5224\:5b9a *)
(* README.md を常にリストの最後に移動する。
   README.md は他のドキュメントの内容を参照して概要を構成するため、
   必ず全ドキュメント生成/更新後に最後に処理する必要がある。 *)
iEnsureReadmeLast[docs_List] :=
  Module[{withoutReadme, hasReadme},
    hasReadme = MemberQ[docs, "README.md"];
    If[!hasReadme, Return[docs]];
    withoutReadme = DeleteCases[docs, "README.md"];
    Append[withoutReadme, "README.md"]
  ];

$iDocKeywords = <|
  "README.md"       -> {"README", "readme", "\:6982\:8981", "\:306f\:3058\:3081",
                         "\:30e9\:30a4\:30bb\:30f3\:30b9", "License", "\:514d\:8cac", "Disclaimer",
                         "\:8b1d\:8f9e", "Acknowledgment",
                         "\:30c7\:30e2", "\:52d5\:753b", "Demo", "demo", "Demos", "video"},
  "setup.md"        -> {"\:30a4\:30f3\:30b9\:30c8\:30fc\:30eb", "\:30bb\:30c3\:30c8\:30a2\:30c3\:30d7", "setup", "install", "\:74b0\:5883\:69cb\:7bc9", "\:5c0e\:5165"},
  "user_manual.md"  -> {"\:30de\:30cb\:30e5\:30a2\:30eb", "\:4f7f\:3044\:65b9", "\:53d6\:6271\:8aac\:660e", "manual", "usage", "\:64cd\:4f5c"},
  "api.md"          -> {"API", "api", "\:95a2\:6570", "\:5b9a\:7fa9", "\:30ea\:30d5\:30a1\:30ec\:30f3\:30b9"},
  "examples/example.md" -> {"\:4f8b", "example", "\:30b5\:30f3\:30d7\:30eb", "\:4f7f\:7528\:4f8b"}
|>;

iGuessTargetDocs[instruction_String, docsDir_String, skipExistCheck_:False] :=
  Module[{hits = {}},
    Do[
      If[(TrueQ[skipExistCheck] || FileExistsQ[FileNameJoin[{docsDir, docFile}]]) &&
         AnyTrue[keywords, StringContainsQ[instruction, #, IgnoreCase -> True] &],
        AppendTo[hits, docFile]],
    {docFile, Keys[$iDocKeywords]}, {keywords, {$iDocKeywords[docFile]}}];
    (* 該当なしなら警告して README.md のみを対象にする（全ファイル更新を防止） *)
    If[Length[hits] === 0,
      Print[Style["\:8b66\:544a: \:66f4\:65b0\:5bfe\:8c61\:3092\:81ea\:52d5\:5224\:5b9a\:3067\:304d\:307e\:305b\:3093\:3067\:3057\:305f\:3002README.md \:306e\:307f\:66f4\:65b0\:3057\:307e\:3059\:3002\n" <>
        "\:5168\:30d5\:30a1\:30a4\:30eb\:3092\:66f4\:65b0\:3059\:308b\:306b\:306f 1\:5f15\:6570\:7248 ClaudeUpdateDocumentation[\"pkg\"] \:3092\:4f7f\:7528\:3057\:3066\:304f\:3060\:3055\:3044\:3002",
        FontColor -> RGBColor[0.8, 0.4, 0]]];
      hits = Select[{"README.md"},
        FileExistsQ[FileNameJoin[{docsDir, #}]] &]];
    iEnsureReadmeLast[DeleteDuplicates[hits]]
  ];

(* \:76f4\:8fd1\:306e _documentupdate \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:30d5\:30a9\:30eb\:30c0\:3092\:691c\:7d22 *)
iFindLatestDocBackup[packageName_String] :=
  Module[{bdir, dirs, docDirs},
    bdir = backupDir[packageName];
    If[!DirectoryQ[bdir], Return[$Failed]];
    dirs = FileNames["*_documentupdate", bdir];
    If[Length[dirs] === 0, Return[$Failed]];
    Last[SortBy[dirs, FileDate]]
  ];

(* .wl \:30d5\:30a1\:30a4\:30eb\:306e\:5dee\:5206\:3092\:53d6\:5f97 *)
iComputeSourceDiff[oldFile_String, newFile_String] :=
  Module[{oldLines, newLines, added = {}, removed = {}, oldText},
    If[!FileExistsQ[newFile], Return["(\:65b0\:30d5\:30a1\:30a4\:30eb\:306a\:3057)"]];
    (* 旧ファイル: .wl → .wl.cz → .wl.cdiff の順で試行 *)
    oldText = iLoadBackupWlFromPath[oldFile];
    If[!StringQ[oldText], Return["(\:65e7\:30d5\:30a1\:30a4\:30eb\:306a\:3057 \:2014 \:5168\:4f53\:304c\:65b0\:898f)"]];
    oldLines = StringSplit[oldText, "\n"];
    newLines = StringSplit[Import[newFile, "Text"], "\n"];
    added = Complement[newLines, oldLines];
    removed = Complement[oldLines, newLines];
    If[Length[added] === 0 && Length[removed] === 0,
      "(\:5909\:66f4\:306a\:3057)",
      "=== ADDED LINES (" <> ToString[Length[added]] <> ") ===\n" <>
      StringTake[StringJoin[Riffle[Take[added, UpTo[100]], "\n"]], UpTo[5000]] <>
      "\n\n=== REMOVED LINES (" <> ToString[Length[removed]] <> ") ===\n" <>
      StringTake[StringJoin[Riffle[Take[removed, UpTo[100]], "\n"]], UpTo[5000]]
    ]
  ];

(* パスベースで生ファイル / .cz / .unchanged / .cdiff のいずれかからテキストを読み込む。
   oldFile は従来の生ファイルパスとして渡される前提。
   パス内のディレクトリ構造からパッケージ名を推定し iLoadBackupFile に委譲する。 *)
iLoadBackupWlFromPath[filePath_String] :=
  Module[{dir, fileName, bdir, packageName, histParts},
    If[FileExistsQ[filePath], Return[Quiet @ Check[Import[filePath, "Text"], $Failed]]];
    If[FileExistsQ[filePath <> ".cz"],
      Return[Quiet @ Check[Uncompress[Import[filePath <> ".cz", "String"]], $Failed]]];
    (* .unchanged / .cdiff は iLoadBackupFile 経由で復元 *)
    If[FileExistsQ[filePath <> ".unchanged"] || FileExistsQ[filePath <> ".cdiff"],
      dir = DirectoryName[filePath];
      fileName = FileNameTake[filePath];
      (* dir が backupDir[pkg] のサブディレクトリならパッケージ名を推定 *)
      histParts = FileNameSplit[dir];
      packageName = If[Length[histParts] >= 2 &&
          histParts[[-2]] === "history",
        StringReplace[histParts[[-3]], "_info" -> ""],
        StringReplace[fileName, ".wl" -> ""]];
      Return[iLoadBackupFile[dir, fileName, packageName]]];
    $Failed
  ];

(* \:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:66f4\:65b0\:5f8c\:306e\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:3092\:4f5c\:6210 *)
iCreateDocUpdateBackup[packageName_String, srcFile_String, docsDir_String,
    instruction_String:""] :=
  Module[{bdir, timestamp, histDir},
    bdir = backupDir[packageName];
    timestamp = DateString[Now, {"Year","Month","Day","Hour24","Minute"}];
    histDir = FileNameJoin[{bdir, timestamp <> "_documentupdate"}];
    CreateDirectory[histDir, CreateIntermediateDirectories -> True];
    Quiet[iSaveBackupWl[histDir, srcFile, packageName]];
    If[DirectoryQ[docsDir],
      Scan[Function[f,
        Quiet[iSaveBackupFile[histDir, f, packageName]]],
        Select[FileNames["*", docsDir], iFileQ]]];
    (* doc_options.json もバックアップ *)
    Module[{docOptsFile = iDocOptionsPath[packageName]},
      If[FileExistsQ[docOptsFile],
        Quiet[iSaveBackupFile[histDir, docOptsFile, packageName]]]];
    (* prompt.txt \:306b\:6307\:793a\:3092\:4fdd\:5b58 *)
    If[StringQ[instruction] && instruction =!= "",
      Module[{strm},
        strm = OpenWrite[FileNameJoin[{histDir, "prompt.txt"}], BinaryFormat -> True];
        BinaryWrite[strm, ToCharacterCode[instruction, "UTF-8"]];
        Close[strm]]];
    histDir
  ];

Options[ClaudeUpdateDocumentation] = {
  Fallback -> False, References -> {}, Demos -> {}, Disclaimer -> {},
  Acknowledgments -> {}, License -> "",
  TargetFiles -> Automatic,  (* Automatic=自動判定, {"api.md"} 等でファイル指定 *)
  Mode -> "Update"           (* "Update"=既存を更新, "Create"=新規作成（既存内容を無視） *)
};

(* 1\:5f15\:6570\:7248: \:524d\:56de _documentupdate \:4ee5\:964d\:306e\:5909\:66f4\:3092\:81ea\:52d5\:691c\:51fa\:3057\:5168\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:3092\:66f4\:65b0 *)
ClaudeUpdateDocumentation[packageName_String, opts:OptionsPattern[]] := (
  $currentUseFallback = TrueQ[OptionValue[Fallback]];
  iDocInitState[packageName,
    Replace[OptionValue[References], Except[_List] -> {}],
    Replace[OptionValue[Demos], Except[_List] -> {}],
    Replace[OptionValue[Disclaimer], Except[_List] -> {}],
    Replace[OptionValue[Acknowledgments], Except[_List] -> {}],
    Replace[OptionValue[License], Except[_String] -> ""]];
  (* 永続化されたオプションをマージ *)
  iLoadAndMergeDocOptions[packageName];
  With[{nb = EvaluationNotebook[]},
  Module[{srcFile, sourceCode, docsDir, pkgDir, allDocs,
          prevBackup, prevSrcFile, diffText, autoInstruction},
    iPrecisionConfidentialCheck[nb];
    pkgDir = Global`$packageDirectory;
    If[!StringQ[pkgDir] || pkgDir === "",
      nbPrint[nb, "\:30a8\:30e9\:30fc: $packageDirectory \:304c\:8a2d\:5b9a\:3055\:308c\:3066\:3044\:307e\:305b\:3093\:3002"];
      Return[$Failed]];
    srcFile = Which[
      FileExistsQ[FileNameJoin[{pkgDir, packageName, "Kernel", packageName <> ".wl"}]],
        FileNameJoin[{pkgDir, packageName, "Kernel", packageName <> ".wl"}],
      FileExistsQ[FileNameJoin[{pkgDir, packageName <> ".wl"}]],
        FileNameJoin[{pkgDir, packageName <> ".wl"}],
      True,
        nbPrint[nb, "\:30a8\:30e9\:30fc: \:30d1\:30c3\:30b1\:30fc\:30b8\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093: " <> packageName];
        Return[$Failed]
    ];
    sourceCode = Import[srcFile, "Text"];
    If[!StringQ[sourceCode],
      nbPrint[nb, "\:30a8\:30e9\:30fc: \:30bd\:30fc\:30b9\:3092\:8aad\:307f\:8fbc\:3081\:307e\:305b\:3093: " <> srcFile];
      Return[$Failed]];
    (* references フォルダを参照可能にする *)
    iEnsureReferencesAccessible[packageName];
    docsDir = iPackageDocsDir[packageName];
    If[!DirectoryQ[docsDir],
      nbPrint[nb, "\:30a8\:30e9\:30fc: \:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:304c\:5b58\:5728\:3057\:307e\:305b\:3093\:3002\:5148\:306b ClaudeCreateDocumentation[\"" <>
        packageName <> "\"] \:3092\:5b9f\:884c\:3057\:3066\:304f\:3060\:3055\:3044\:3002"];
      Return[$Failed]];
    (* \:524d\:56de _documentupdate \:3068\:306e\:5dee\:5206\:3092\:53d6\:5f97 *)
    prevBackup = iFindLatestDocBackup[packageName];
    If[!StringQ[prevBackup] || !DirectoryQ[prevBackup],
      nbPrint[nb, "\:30a8\:30e9\:30fc: \:524d\:56de\:306e _documentupdate \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093\:3002\n" <>
        "\:5148\:306b ClaudeCreateDocumentation[\"" <> packageName <>
        "\"] \:3092\:5b9f\:884c\:3057\:3066\:304f\:3060\:3055\:3044\:3002"];
      Return[$Failed]];
    prevSrcFile = FileNameJoin[{prevBackup, FileNameTake[srcFile]}];
    diffText = iComputeSourceDiff[prevSrcFile, srcFile];
    If[diffText === "(\:5909\:66f4\:306a\:3057)",
      nbPrint[nb, "\:30bd\:30fc\:30b9\:30b3\:30fc\:30c9\:306b\:5909\:66f4\:304c\:3042\:308a\:307e\:305b\:3093\:3002\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:306f\:6700\:65b0\:3067\:3059\:3002"];
      Return[]];
    (* \:5168\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:30d5\:30a1\:30a4\:30eb\:3092\:5bfe\:8c61\:306b\:3059\:308b *)
    (* 全ドキュメントファイルを対象にする (サブディレクトリ含む) *)
    allDocs = Join[
      FileNameTake /@ FileNames["*.md", docsDir],
      (* examples/ などのサブディレクトリ内の .md *)
      Module[{subFiles},
        subFiles = FileNames["*.md", docsDir, 2];
        subFiles = Select[subFiles, DirectoryName[#] =!= docsDir &];
        (FileNameTake[DirectoryName[#], -1] <> "/" <> FileNameTake[#]) & /@ subFiles]
    ] // DeleteDuplicates;
    (* README.md は他のドキュメント参照のため必ず最後 *)
    allDocs = iEnsureReadmeLast[allDocs];
    If[Length[allDocs] === 0,
      nbPrint[nb, "\:30a8\:30e9\:30fc: \:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:30d5\:30a1\:30a4\:30eb\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093\:3002"];
      Return[$Failed]];
    autoInstruction = "\:524d\:56de\:306e\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:66f4\:65b0\:4ee5\:964d\:306e\:30bd\:30fc\:30b9\:30b3\:30fc\:30c9\:5909\:66f4\:3092\:53cd\:6620\:3057\:3066\:3001\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:3092\:66f4\:65b0\:3057\:3066\:304f\:3060\:3055\:3044\:3002" <>
      "\:8ffd\:52a0\:3055\:308c\:305f\:95a2\:6570\:30fb\:30aa\:30d7\:30b7\:30e7\:30f3\:306e\:8aac\:660e\:3092\:8ffd\:52a0\:3057\:3001\:524a\:9664\:3055\:308c\:305f\:3082\:306e\:306e\:8aac\:660e\:3092\:524a\:9664\:3059\:308b\:3053\:3068\:3002";
    (* セクションヘッダーを入力セルの直前に挿入 *)
    iWriteSectionHeaderBeforeEvalCell[nb,
      "\:25b6 ClaudeUpdateDocumentation: " <> packageName <>
      " (" <> DateString[Now, {"Year", "/", "Month", "/", "Day", " ", "Hour24", ":", "Minute"}] <> ")"];
    nbPrint[nb, Style["\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:81ea\:52d5\:66f4\:65b0\:958b\:59cb: " <> packageName, Bold]];
    nbPrint[nb, "\:524d\:56de\:30d0\:30c3\:30af\:30a2\:30c3\:30d7: " <> prevBackup];
    nbPrint[nb, "\:66f4\:65b0\:5bfe\:8c61: " <> StringRiffle[allDocs, ", "]];
    nbPrint[nb, "\:30bd\:30fc\:30b9\:5dee\:5206: " <> StringTake[diffText, UpTo[200]] <> "\n"];
    iUpdateDocNext[sourceCode, packageName, nb, docsDir, autoInstruction, allDocs, 1,
      diffText, srcFile]
  ]]);

(* 2\:5f15\:6570\:7248: \:6307\:793a\:4ed8\:304d\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:66f4\:65b0 *)
ClaudeUpdateDocumentation[packageName_String, instruction_String, opts:OptionsPattern[]] := (
  $currentUseFallback = TrueQ[OptionValue[Fallback]];
  Module[{urlsInInstr, initDemos, initRefs, explicitDemos, explicitRefs},
    initRefs = Replace[OptionValue[References], Except[_List] -> {}];
    initDemos = Replace[OptionValue[Demos], Except[_List] -> {}];
    explicitDemos = Length[initDemos] > 0;
    explicitRefs = Length[initRefs] > 0;
    urlsInInstr = StringCases[instruction,
      RegularExpression["https?://[^\\s\\)\\]\\>\"]+"] :> "$0"];
    If[Length[urlsInInstr] > 0, explicitDemos = True];
    initDemos = DeleteDuplicates[Join[initDemos, urlsInInstr]];
    iDocInitState[packageName, initRefs, initDemos,
      Replace[OptionValue[Disclaimer], Except[_List] -> {}],
      Replace[OptionValue[Acknowledgments], Except[_List] -> {}],
      Replace[OptionValue[License], Except[_String] -> ""],
      instruction,
      explicitDemos || explicitRefs];
  ];
  (* 永続化されたオプションをマージ *)
  iLoadAndMergeDocOptions[packageName];
  With[{nb = EvaluationNotebook[]},
  Module[{srcFile, sourceCode, docsDir, pkgDir, targetDocs,
          prevBackup, prevSrcFile, diffText, enrichedInstruction, nbCtx},
    iPrecisionConfidentialCheck[nb];
    pkgDir = Global`$packageDirectory;
    If[!StringQ[pkgDir] || pkgDir === "",
      nbPrint[nb, "\:30a8\:30e9\:30fc: $packageDirectory \:304c\:8a2d\:5b9a\:3055\:308c\:3066\:3044\:307e\:305b\:3093\:3002"];
      Return[$Failed]];
    (* ノートブックコンテキストを取得してinstructionに付加（ドキュメント更新では控えめに） *)
    nbCtx = Quiet @ Check[iCaptureNotebookContext[nb, 0], ""];
    enrichedInstruction = If[StringQ[nbCtx] && StringLength[nbCtx] > 0,
      instruction <> "\n\n=== ノートブックコンテキスト（上での議論）===\n" <>
      StringTake[nbCtx, UpTo[2000]] <> "\n",
      instruction];
    pkgDir = Global`$packageDirectory;
    If[!StringQ[pkgDir] || pkgDir === "",
      nbPrint[nb, "\:30a8\:30e9\:30fc: $packageDirectory \:304c\:8a2d\:5b9a\:3055\:308c\:3066\:3044\:307e\:305b\:3093\:3002"];
      Return[$Failed]];
    srcFile = Which[
      FileExistsQ[FileNameJoin[{pkgDir, packageName, "Kernel", packageName <> ".wl"}]],
        FileNameJoin[{pkgDir, packageName, "Kernel", packageName <> ".wl"}],
      FileExistsQ[FileNameJoin[{pkgDir, packageName <> ".wl"}]],
        FileNameJoin[{pkgDir, packageName <> ".wl"}],
      True,
        nbPrint[nb, "\:30a8\:30e9\:30fc: \:30d1\:30c3\:30b1\:30fc\:30b8\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093: " <> packageName];
        Return[$Failed]
    ];
    sourceCode = Import[srcFile, "Text"];
    If[!StringQ[sourceCode],
      nbPrint[nb, "\:30a8\:30e9\:30fc: \:30bd\:30fc\:30b9\:3092\:8aad\:307f\:8fbc\:3081\:307e\:305b\:3093: " <> srcFile];
      Return[$Failed]];
    (* references フォルダを参照可能にする *)
    iEnsureReferencesAccessible[packageName];
    docsDir = iPackageDocsDir[packageName];
    If[!DirectoryQ[docsDir],
      nbPrint[nb, "\:30a8\:30e9\:30fc: \:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:304c\:5b58\:5728\:3057\:307e\:305b\:3093\:3002\:5148\:306b ClaudeCreateDocumentation[\"" <>
        packageName <> "\"] \:3092\:5b9f\:884c\:3057\:3066\:304f\:3060\:3055\:3044\:3002"];
      Return[$Failed]];
    (* \:524d\:56de\:306e _documentupdate \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:3068\:306e\:5dee\:5206\:3092\:53d6\:5f97 *)
    prevBackup = iFindLatestDocBackup[packageName];
    diffText = If[StringQ[prevBackup] && DirectoryQ[prevBackup],
      prevSrcFile = FileNameJoin[{prevBackup, FileNameTake[srcFile]}];
      nbPrint[nb, "\:524d\:56de\:30d0\:30c3\:30af\:30a2\:30c3\:30d7: " <> prevBackup];
      iComputeSourceDiff[prevSrcFile, srcFile],
      "(\:524d\:56de\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:306a\:3057 \:2014 \:5168\:30bd\:30fc\:30b9\:3092\:53c2\:7167)"];
    (* Mode を先に解決 *)
    Module[{mode = Replace[OptionValue[ClaudeUpdateDocumentation, {opts}, Mode],
              Except["Create" | "Update"] -> "Update"],
            tf = OptionValue[ClaudeUpdateDocumentation, {opts}, TargetFiles]},
    (* TargetFiles が明示的に指定されていればそれを使用 *)
    targetDocs = If[ListQ[tf] && Length[tf] > 0,
      nbPrint[nb, "TargetFiles \:6307\:5b9a: " <> StringRiffle[tf, ", "]];
      iEnsureReadmeLast[tf],
      If[StringQ[tf] && tf =!= "",
        nbPrint[nb, "TargetFiles \:6307\:5b9a: " <> tf];
        {tf},
        (* 自動判定: Create モードならファイル存在チェックをスキップ *)
        iGuessTargetDocs[instruction, docsDir, mode === "Create"]]];
    (* 今回の呼び出しで Demos/References が明示的に渡された場合のみ README.md を強制追加 *)
    If[TrueQ[iDocGet[packageName, "ExplicitDemosOrRefs"]] &&
       !MemberQ[targetDocs, "README.md"] &&
       FileExistsQ[FileNameJoin[{docsDir, "README.md"}]],
      targetDocs = iEnsureReadmeLast[DeleteDuplicates[Append[targetDocs, "README.md"]]]];
    If[Length[targetDocs] === 0,
      nbPrint[nb, "\:30a8\:30e9\:30fc: \:66f4\:65b0\:5bfe\:8c61\:306e\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093\:3002"];
      Return[$Failed]];
    (* セクションヘッダーを入力セルの直前に挿入 *)
    iWriteSectionHeaderBeforeEvalCell[nb,
      "\:25b6 ClaudeUpdateDocumentation: " <> packageName <>
      " (" <> DateString[Now, {"Year", "/", "Month", "/", "Day", " ", "Hour24", ":", "Minute"}] <> ")"];
    nbPrint[nb, Style["\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:66f4\:65b0\:958b\:59cb: " <> packageName <>
      If[mode === "Create", " [\:65b0\:898f\:4f5c\:6210\:30e2\:30fc\:30c9]", ""], Bold]];
    nbPrint[nb, "\:66f4\:65b0\:5bfe\:8c61: " <> StringRiffle[targetDocs, ", "]];
    nbPrint[nb, "\:30bd\:30fc\:30b9\:5dee\:5206: " <> StringTake[diffText, UpTo[100]] <> "..."];
    nbPrint[nb, "\:6307\:793a: " <> StringTake[instruction, UpTo[200]] <> "\n"];
    (* \:5dee\:5206\:4ed8\:304d\:3067\:9806\:6b21\:66f4\:65b0 *)
    iUpdateDocNext[sourceCode, packageName, nb, docsDir, enrichedInstruction, targetDocs, 1,
      diffText, srcFile, <||>, mode]
    ] (* end Module mode *)
  ]]);

(* ドキュメントを順次更新する再帰関数 (差分対応版・トークン節約版) *)
iUpdateDocNext[sourceCode_String, packageName_String, nb_NotebookObject,
    docsDir_String, instruction_String, targetDocs_List, idx_Integer,
    diffText_String:"", srcFile_String:"", splitCache_Association:<||>,
    mode_String:"Update"] :=
  Module[{docFile, docPath, currentContent, fullPrompt, histDir,
          split, chunkedSource, narrowQ, savedModel, isReadme, isApi,
          promptParts, useInstruction},
    If[idx > Length[targetDocs],
      (* 全ドキュメント更新完了 → バックアップ作成 *)
      If[StringQ[srcFile] && srcFile =!= "",
        histDir = iCreateDocUpdateBackup[packageName, srcFile, docsDir, instruction];
        nbPrint[nb, "\:30d0\:30c3\:30af\:30a2\:30c3\:30d7: " <> histDir]];
      (* ドキュメントオプションを永続化 *)
      iSaveDocOptions[packageName];
      nbPrint[nb, "\:2705 \:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:66f4\:65b0\:304c\:5b8c\:4e86\:3057\:307e\:3057\:305f\:3002"];
      Return[]];
    docFile = targetDocs[[idx]];
    docPath = FileNameJoin[{docsDir, docFile}];
    (* Mode -> "Create" なら既存内容を無視して新規作成 *)
    currentContent = If[mode === "Create", "",
      If[FileExistsQ[docPath], Import[docPath, "Text"], ""]];
    isReadme = (docFile === "README.md");
    isApi = (docFile === "api.md");
    narrowQ = iIsNarrowScopeInstruction[instruction];

    (* api.md にはノートブックコンテキストは不要 → 除去 *)
    useInstruction = If[isApi,
      StringReplace[instruction,
        RegularExpression["(?s)\n\n=== ノートブックコンテキスト.*$"] -> ""],
      instruction];

    (* === ドキュメント種別ごとのプロンプト構築 ===
       api.md:        ソースコードのみ（差分・ノートブックコンテキスト不要）
       user_manual/setup/examples: ソースコード + 差分 + ノートブックコンテキスト
       README.md:     ソースコード不要。兄弟ドキュメント(api/manual/setup)の内容から生成 *)

    promptParts = {
      "You are an expert Wolfram Language / Mathematica documentation writer.\n",
      "CRITICAL: Do NOT write any files. Do NOT use file-writing tools. Output to stdout ONLY.\n",
      "You are updating the documentation for package \"" <> packageName <> "\"\n\n",
      "UPDATE INSTRUCTION:\n" <> useInstruction <> "\n\n"
    };

    (* --- 差分: api.md と README.md には不要 --- *)
    If[!isApi && !isReadme &&
       StringQ[diffText] && diffText =!= "" && diffText =!= "(\:5909\:66f4\:306a\:3057)",
      AppendTo[promptParts,
        "SOURCE CODE DIFF (since last documentation update):\n" <>
        "Focus your updates on these changed parts.\n" <>
        diffText <> "\n\n"]];

    (* --- 現在のドキュメント --- *)
    AppendTo[promptParts,
      "CURRENT DOCUMENT (" <> docFile <> "):\n" <>
      If[StringQ[currentContent] && currentContent =!= "",
        currentContent, "(empty)"] <> "\n\n"];

    (* --- README.md: 兄弟ドキュメントから生成（ソースコード不要） --- *)
    If[isReadme,
      If[narrowQ,
        AppendTo[promptParts, "(Sibling documentation files omitted \:2014 narrow-scope update)\n"],
        Module[{siblingDocs, siblingContent = ""},
          siblingDocs = Join[
            FileNames["*.md", docsDir],
            FileNames["*.md", docsDir, 2]];
          siblingDocs = Select[siblingDocs, FileNameTake[#] =!= "README.md" &];
          siblingDocs = DeleteDuplicates[siblingDocs];
          If[Length[siblingDocs] > 0,
            siblingContent = "\n=== OTHER DOCUMENTATION FILES (use as source for README overview) ===\n" <>
              StringJoin[
                Module[{relPath, txt},
                  relPath = StringReplace[#,
                    docsDir <> $PathnameSeparator -> ""];
                  txt = Quiet @ Check[Import[#, "Text"], ""];
                  If[StringQ[txt],
                    "--- " <> relPath <> " ---\n" <> StringTake[txt, UpTo[6000]] <> "\n\n",
                    ""]] & /@ siblingDocs]];
          AppendTo[promptParts, siblingContent]]
      ];
      AppendTo[promptParts,
        iBuildGitHubLinksContext[] <>
        iDocBuildRefSection[packageName] <>
        iDocBuildAcknowledgmentsPrompt[packageName] <>
        iDocBuildDisclaimerPrompt[packageName] <>
        iDocBuildLicensePrompt[packageName]]
    ];

    (* --- api.md / user_manual / setup / examples: ソースコード添付 --- *)
    If[!isReadme,
      split = If[splitCache =!= <||>, splitCache, iSplitSource[sourceCode]];
      chunkedSource = iBuildChunkedSource[split, docFile];
      AppendTo[promptParts,
        "PACKAGE SOURCE CODE (chunked for token efficiency):\n" <> chunkedSource <> "\n\n"];
      (* README 以外でもリンク捏造防止のため URL リストを提供 *)
      AppendTo[promptParts,
        iBuildGitHubLinksContext[] <>
        "\nCRITICAL RULE: \:8b1d\:8f9e (Acknowledgments), \:514d\:8cac\:4e8b\:9805 (Disclaimer) and \:30e9\:30a4\:30bb\:30f3\:30b9 (License) sections MUST ONLY exist in README.md.\n" <>
        "Do NOT add, create, or keep any \:8b1d\:8f9e, \:514d\:8cac\:4e8b\:9805 or \:30e9\:30a4\:30bb\:30f3\:30b9 section in this file.\n" <>
        "If this file currently contains such sections, REMOVE them entirely.\n\n"],
      (* README はソースコード不添付 *)
      chunkedSource = "(README.md \:306f\:30bd\:30fc\:30b9\:30b3\:30fc\:30c9\:4e0d\:8981)"
    ];

    (* --- 出力指示 --- *)
    AppendTo[promptParts,
      "Output the COMPLETE updated document directly as your response text. "];
    If[isApi,
      AppendTo[promptParts,
        iLanguageInstruction["plain"] <>
        "CRITICAL: api.md is for LLM code generation, NOT for humans.\n" <>
        "FORMAT RULES (token-efficient, high density):\n" <>
        "- Minimize blank lines: only 1 before ## section headings.\n" <>
        "- Do NOT use --- separators. Do NOT use bold labels like **\:5f15\:6570:**.\n" <>
        "- Do NOT add usage examples for trivial functions.\n" <>
        "- Only add examples for complex options or non-obvious patterns.\n" <>
        "- Simple functions: ### FuncName[args] \:2192 ReturnType\\n\:8aac\:660e(1\:884c)\n" <>
        "- Option functions: ### FuncName[args, opts]\\n\:8aac\:660e\\n\:2192 ReturnType\\nOptions: Opt1 -> Def1 (\:8aac\:660e), ...\n" <>
        "- Variables: ### $Var\\n\:578b: Type, \:521d\:671f\:5024: val\\n\:8aac\:660e\n" <>
        "- List ALL public functions and ALL options. Completeness is critical.\n"],
      AppendTo[promptParts, iLanguageInstruction["polite"]]
    ];
    AppendTo[promptParts,
      "Do NOT wrap in code fences. Do NOT include markers. Do NOT ask for file permissions.\n" <>
      "Preserve the existing structure and content that is not affected by the update instruction.\n" <>
      "Add or modify only the parts relevant to the instruction.\n"];
    If[isReadme,
      AppendTo[promptParts,
        "CRITICAL: README.md is a HIGH-LEVEL OVERVIEW document updated LAST.\n" <>
        If[!narrowQ,
          "You have access to the OTHER DOCUMENTATION FILES above \:2014 they were just updated.\n" <>
          "Use them to construct an accurate, comprehensive overview.\n" <>
          "Do NOT include source code details. Summarize features from the documentation files.\n\n",
          "This is a narrow-scope update. Focus only on the specific section mentioned in the instruction.\n\n"] <>
        "MANDATORY STRUCTURE (in this order):\n" <>
        "1. # \:30d1\:30c3\:30b1\:30fc\:30b8\:540d \:2014 \:8a2d\:8a08\:601d\:60f3\:3068\:5b9f\:88c5\:306e\:6982\:8981\n" <>
        "2. ## \:8a73\:7d30\:8aac\:660e containing:\n" <>
        "   - \:52d5\:4f5c\:74b0\:5883 (OS, Mathematica version, external tools)\n" <>
        "   - \:30a4\:30f3\:30b9\:30c8\:30fc\:30eb\n" <>
        "   - \:30af\:30a4\:30c3\:30af\:30b9\:30bf\:30fc\:30c8 (minimal working example)\n" <>
        "   - \:4e3b\:306a\:6a5f\:80fd (feature list with brief descriptions)\n" <>
        "   - \:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:4e00\:89a7 (links to setup.md, user_manual.md, api.md, examples/)\n" <>
        "3. ## \:4f7f\:7528\:4f8b\:30fb\:30c7\:30e2 \:2014 Demo URLs and usage examples go HERE (section name MUST be '\:4f7f\:7528\:4f8b\:30fb\:30c7\:30e2')\n" <>
        "4. ## \:8b1d\:8f9e (ONLY if Acknowledgments are provided \:2014 omit entirely if none)\n" <>
        "5. ## \:514d\:8cac\:4e8b\:9805\n" <>
        "6. ## \:30e9\:30a4\:30bb\:30f3\:30b9 (if present \:2014 MUST be last)\n\n" <>
        "RULES:\n" <>
        "- Do NOT copy detailed API descriptions from other docs. Keep it high-level.\n" <>
        "- Do NOT append raw instruction text, prompt fragments, or update notes.\n" <>
        "- Nothing should be added after \:30e9\:30a4\:30bb\:30f3\:30b9.\n" <>
        "- Preserve the existing design philosophy narrative.\n" <>
        "- Update feature lists and function counts to match the latest source.\n"]];

    fullPrompt = StringJoin[promptParts];

    (* プロンプト健全性チェック *)
    If[!StringQ[fullPrompt] || StringLength[fullPrompt] < 100,
      nbPrint[nb, "\:26a0 \:30d7\:30ed\:30f3\:30d7\:30c8\:69cb\:7bc9\:306b\:5931\:6557\:3057\:307e\:3057\:305f\:3002\:30b9\:30ad\:30c3\:30d7\:3057\:307e\:3059\:3002"];
      iUpdateDocNext[sourceCode, packageName, nb, docsDir, instruction,
        targetDocs, idx + 1, diffText, srcFile, split];
      Return[]];

    nbPrint[nb, "\:2500 [" <> ToString[idx] <> "/" <> ToString[Length[targetDocs]] <>
      "] " <> docFile <> " \:3092\:66f4\:65b0\:4e2d... (\:30d7\:30ed\:30f3\:30d7\:30c8: " <>
      ToString[StringLength[fullPrompt]] <> " chars, parts: " <>
      ToString[Length[promptParts]] <> ", \:30e2\:30c7\:30eb: " <>
      iDocModelOverride[] <> ")"];

    (* ドキュメント生成用モデルでクエリ実行 *)
    savedModel = $ClaudeModel;
    $ClaudeModel = iDocModelOverride[];
    iClaudeQueryAsyncWithProgress[fullPrompt,
      With[{nb2 = nb, dd = docsDir, tds = targetDocs, i = idx,
            df = docFile, dp = docPath, sc = sourceCode, pn = packageName,
            instr = instruction, dt = diffText, sf = srcFile, sp = split,
            md = mode},
        Function[response,
          Module[{writeResult},
            writeResult = iSafeWriteDoc[dp, response, pn];
            If[writeResult =!= $Failed,
              nbPrint[nb2, "  \:2713 " <> df <> " \:3092\:66f4\:65b0\:3057\:307e\:3057\:305f"],
              nbPrint[nb2, "  \:2717 " <> df <> " \:306e\:66f4\:65b0\:306b\:5931\:6557 (\:7121\:52b9\:306a\:5fdc\:7b54/\:30bf\:30a4\:30c8\:30eb\:4e0d\:6574\:5408/\:30b5\:30a4\:30ba\:9000\:884c): " <>
                StringTake[ToString[response], UpTo[200]]]
            ];
            iUpdateDocNext[sc, pn, nb2, dd, instr, tds, i + 1, dt, sf, sp, md]
          ]
        ]
      ],
      nb];
    $ClaudeModel = savedModel;
  ];


(* ============================================================
   api.md 自動更新: ClaudeUpdatePackage/ClaudeCreatePackage 後に
   api.md だけを自動再生成する。他のドキュメントは更新しない。
   ============================================================ *)

iAutoUpdateApiMd[nb_NotebookObject, packageName_String] :=
  Module[{docsDir, apiFile, srcFile, sourceCode, currentApi, prompt},
    docsDir = iPackageDocsDir[packageName];
    If[!StringQ[docsDir], Return[]];
    (* docs ディレクトリがなければ作成 *)
    If[!DirectoryQ[docsDir],
      Quiet @ CreateDirectory[docsDir, CreateIntermediateDirectories -> True]];
    apiFile = FileNameJoin[{docsDir, "api.md"}];
    srcFile = iPackageSourceFile[packageName];
    If[!FileExistsQ[srcFile], Return[]];
    sourceCode = Quiet @ Check[Import[srcFile, "Text"], ""];
    If[!StringQ[sourceCode] || sourceCode === "", Return[]];
    currentApi = If[FileExistsQ[apiFile],
      Quiet @ Check[Import[apiFile, "Text"], ""], ""];
    prompt =
      "You are an expert Wolfram Language / Mathematica documentation writer.\n" <>
      "CRITICAL: Do NOT write any files. Do NOT use file-writing tools. Output to stdout ONLY.\n" <>
      "CRITICAL RULE: Do NOT add any \:8b1d\:8f9e, \:514d\:8cac\:4e8b\:9805 or \:30e9\:30a4\:30bb\:30f3\:30b9 section. These belong ONLY in README.md.\n" <>
      "Create an LLM-optimized API reference (api.md) for package \"" <> packageName <> "\".\n" <>
      "This file is read by LLMs for code generation, NOT by humans.\n" <>
      "An LLM reading ONLY this file must write correct code using the package.\n\n" <>
      iLanguageInstruction["plain"] <> "\n" <>
      "CRITICAL FORMAT RULES (token-efficient, high density):\n" <>
      "- Minimize blank lines: only 1 before ## section headings.\n" <>
      "- Do NOT use --- separators. Do NOT use bold labels like **\:5f15\:6570:**.\n" <>
      "- Do NOT add usage examples for trivial functions.\n" <>
      "- Only add examples for complex options or non-obvious patterns.\n\n" <>
      "FORMAT for simple functions: ### FuncName[args] \:2192 ReturnType\\n\:8aac\:660e(1\:884c)\n" <>
      "FORMAT for option functions: ### FuncName[args, opts]\\n\:8aac\:660e\\n\:2192 ReturnType\\nOptions: Opt1 -> Def1 (\:8aac\:660e), ...\n" <>
      "FORMAT for complex functions: add \:4f8b: FuncName[...] line\n" <>
      "FORMAT for variables: ### $Var\\n\:578b: Type, \:521d\:671f\:5024: val\\n\:8aac\:660e\n\n" <>
      "List ALL public functions and ALL options. Completeness is critical.\n" <>
      "Format: Markdown. Output the COMPLETE document directly as your response text.\n" <>
      "Do NOT wrap in code fences. Do NOT include markers. Do NOT ask for file permissions.\n\n" <>
      If[StringQ[currentApi] && currentApi =!= "",
        "CURRENT api.md (update and keep structure where appropriate):\n" <>
        currentApi <> "\n\n",
        ""] <>
      "PACKAGE SOURCE CODE:\n" <>
      iBuildChunkedSource[iSplitSource[sourceCode], "api.md"];
    nbPrint[nb, "\:2500 api.md \:3092\:81ea\:52d5\:66f4\:65b0\:4e2d... (\:30e2\:30c7\:30eb: " <> iDocModelOverride[] <> ")"];
    Module[{savedModel = $ClaudeModel},
    $ClaudeModel = iDocModelOverride[];
    iClaudeQueryAsyncWithProgress[prompt,
      With[{nb2 = nb, af = apiFile, pn = packageName},
        Function[response,
          Module[{writeResult},
            writeResult = iSafeWriteDoc[af, response, pn];
            If[writeResult =!= $Failed,
              nbPrint[nb2, "  \:2713 " <> pn <> " \:306e api.md \:3092\:66f4\:65b0\:3057\:307e\:3057\:305f"],
              nbPrint[nb2, "  \:2717 api.md \:306e\:81ea\:52d5\:66f4\:65b0\:306b\:5931\:6557 (\:7121\:52b9\:306a\:5fdc\:7b54/\:30bf\:30a4\:30c8\:30eb\:4e0d\:6574\:5408/\:30b5\:30a4\:30ba\:9000\:884c): " <>
                StringTake[ToString[response], UpTo[100]]]
            ]]
        ]
      ],
      nb];
    $ClaudeModel = savedModel;
    ] (* end Module savedModel *)
  ];

(* ============================================================
   Paclet \:5909\:63db: \:5358\:4e00 .wl \:30d5\:30a1\:30a4\:30eb \:2192 Paclet \:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:69cb\:9020
   ============================================================ *)

(* .wl \:30d5\:30a1\:30a4\:30eb\:304b\:3089\:516c\:958b\:30b7\:30f3\:30dc\:30eb\:3068 usage \:3092\:62bd\:51fa *)
(* \:8907\:6570\:884c\:306b\:307e\:305f\:304c\:308b usage \:6587\:5b57\:5217\:3082\:6b63\:3057\:304f\:62bd\:51fa\:3057\:3001\\:XXXX \:30a8\:30b9\:30b1\:30fc\:30d7\:3092\:30c7\:30b3\:30fc\:30c9 *)
iDecodeWLUnicode[s_String] :=
  StringReplace[s, RegularExpression["\\\\:([0-9a-fA-F]{4})"] :>
    FromCharacterCode[FromDigits["$1", 16]]];

iExtractPublicSymbols[code_String] :=
  Module[{lines, i, result = <||>, name, buf, depth, line, inStr},
    lines = StringSplit[code, "\n"];
    i = 1;
    While[i <= Length[lines],
      line = lines[[i]];
      (* \:30d1\:30bf\:30fc\:30f3: SymbolName::usage = *)
      If[StringContainsQ[line, "::usage"],
        Module[{m},
          m = StringCases[line,
            RegularExpression["^\\s*(\\w+\\$?\\w*)::usage\\s*="] :> "$1"];
          If[Length[m] > 0,
            name = First[m];
            (* usage \:6587\:5b57\:5217\:5168\:4f53\:3092\:53ce\:96c6: = \:306e\:5f8c\:304b\:3089 ; \:307e\:3067 *)
            buf = StringTrim[StringReplace[line,
              RegularExpression["^\\s*\\w+\\$?\\w*::usage\\s*=\\s*"] -> ""]];
            (* \:884c\:672b\:304c ; \:3067\:7d42\:308f\:3089\:306a\:3044\:9650\:308a\:7d9a\:884c\:3092\:8aad\:3080 *)
            While[i < Length[lines] && !StringEndsQ[StringTrim[buf], ";"],
              i++;
              buf = buf <> "\n" <> lines[[i]]
            ];
            (* \:6587\:5b57\:5217\:30ea\:30c6\:30e9\:30eb\:3060\:3051\:62bd\:51fa\:3057\:3066\:7d50\:5408 *)
            Module[{strs, decoded},
              strs = StringCases[buf, "\"" ~~ Shortest[s__] ~~ "\"" :> s];
              decoded = iDecodeWLUnicode[StringJoin[strs]];
              (* \:6539\:884c\:3092\:30b9\:30da\:30fc\:30b9\:306b\:7f6e\:63db\:3057\:6574\:5f62 *)
              decoded = StringReplace[decoded, {
                "\\n" -> " ",
                RegularExpression["\\s{2,}"] -> " "
              }];
              result[name] = StringTrim[decoded]
            ]
          ]
        ]
      ];
      i++
    ];
    result
  ];

(* UTF-8 \:30d0\:30a4\:30ca\:30ea\:66f8\:304d\:51fa\:3057\:30d8\:30eb\:30d1\:30fc *)
iExportUTF8[path_String, text_String] :=
  Module[{strm},
    strm = OpenWrite[path, BinaryFormat -> True];
    BinaryWrite[strm, ToCharacterCode[text, "UTF-8"], "Byte"];
    Close[strm];
    path
  ];

(* PacletInfo.wl \:306e\:5185\:5bb9\:3092\:751f\:6210 *)
iGeneratePacletInfo[packageName_String, publicSymbols_Association] :=
  "PacletObject[\n" <>
  "  <|\n" <>
  "    \"Name\" -> \"" <> packageName <> "\",\n" <>
  "    \"Version\" -> \"1.0.0\",\n" <>
  "    \"WolframVersion\" -> \"13.0+\",\n" <>
  "    \"Description\" -> \"" <> packageName <> " package\",\n" <>
  "    \"Creator\" -> \"\",\n" <>
  "    \"Extensions\" -> {\n" <>
  "      {\"Kernel\", \"Root\" -> \"Kernel\", \"Context\" -> \"" <> packageName <> "`\"},\n" <>
  "      {\"Documentation\", \"Language\" -> \"English\"}\n" <>
  "    }\n" <>
  "  |>\n" <>
  "]";

(* Kernel/init.wl \:306e\:5185\:5bb9\:3092\:751f\:6210 *)
iGenerateKernelInit[packageName_String] :=
  "(* " <> packageName <> " Paclet - Kernel Initialization *)\n" <>
  "Get[\"" <> packageName <> "`" <> packageName <> "`\"];";

(* \:30ac\:30a4\:30c9\:30da\:30fc\:30b8 .nb \:3092 Notebook \:5f0f\:3067\:751f\:6210 *)
iGenerateGuideNB[packageName_String, publicSymbols_Association] :=
  Module[{cells, symCells},
    symCells = Map[
      Function[name,
        Cell[name <> " \[LongDash] " <> Lookup[publicSymbols, name, ""], "Item"]
      ],
      Keys[publicSymbols]
    ];
    cells = Join[
      {Cell[packageName <> " Overview", "Title"],
       Cell[packageName <> " \:30d1\:30c3\:30b1\:30fc\:30b8\:306e\:6a5f\:80fd\:4e00\:89a7", "Text"],
       Cell["\:516c\:958b\:95a2\:6570", "Subsection"]},
      symCells
    ];
    Notebook[cells, StyleDefinitions -> "Default.nb"]
  ];

(* README.md \:3092\:751f\:6210 *)
iGenerateReadme[packageName_String, publicSymbols_Association] :=
  "# " <> packageName <> "\n\n" <>
  "## \:6982\:8981\n\n" <>
  packageName <> " \:30d1\:30c3\:30b1\:30fc\:30b8\n\n" <>
  "## \:30a4\:30f3\:30b9\:30c8\:30fc\:30eb\n\n" <>
  "```mathematica\nPacletDirectoryLoad[\"path/to/" <> packageName <>
  "\"]\nNeeds[\"" <> packageName <> "`\"]\n```\n\n" <>
  "## \:4e3b\:306a\:95a2\:6570\n\n" <>
  StringJoin[Map[
    Function[name,
      "### " <> name <> "\n\n" <>
      Lookup[publicSymbols, name, ""] <> "\n\n"
    ],
    Keys[publicSymbols]
  ]] <>
  "## \:30e9\:30a4\:30bb\:30f3\:30b9\n\n(C) " <> DateString[Now, "Year"] <> "\n";

(* \:8a73\:7d30\:4ed5\:69d8\:66f8 Docs/spec.md \:3092\:751f\:6210 *)
iGenerateSpecMD[packageName_String, publicSymbols_Association, code_String] :=
  Module[{header, toc, funcSections, footer, deps, beginPkgLine},
    (* \:4f9d\:5b58\:30d1\:30c3\:30b1\:30fc\:30b8\:62bd\:51fa *)
    deps = Union @ StringCases[code,
      RegularExpression["Needs\\[\"([^\"]+)\""] :> "$1"];
    (* BeginPackage \:306e\:30b3\:30f3\:30c6\:30ad\:30b9\:30c8\:62bd\:51fa *)
    beginPkgLine = First[StringCases[code,
      RegularExpression["BeginPackage\\[([^\\]]+)\\]"] :> "$1"], ""];

    header =
      "# " <> packageName <> " \:4ed5\:69d8\:66f8\n\n" <>
      "## 1. \:6982\:8981\n\n" <>
      "- **\:30d1\:30c3\:30b1\:30fc\:30b8\:540d**: " <> packageName <> "\n" <>
      "- **\:30b3\:30f3\:30c6\:30ad\:30b9\:30c8**: " <> packageName <> "`\n" <>
      If[beginPkgLine =!= "",
        "- **BeginPackage**: `BeginPackage[" <> beginPkgLine <> "]`\n", ""] <>
      "- **\:516c\:958b\:30b7\:30f3\:30dc\:30eb\:6570**: " <> ToString[Length[publicSymbols]] <> "\n" <>
      If[Length[deps] > 0,
        "- **\:4f9d\:5b58**: " <> StringRiffle[deps, ", "] <> "\n", ""] <>
      "\n";

    toc =
      "## 2. \:516c\:958b API \:4e00\:89a7\n\n" <>
      StringJoin[MapIndexed[
        Function[{name, idx},
          ToString[First[idx]] <> ". [" <> name <> "](#" <>
          ToLowerCase[name] <> ")\n"
        ],
        Keys[publicSymbols]
      ]] <> "\n";

    funcSections =
      "## 3. \:95a2\:6570\:30ea\:30d5\:30a1\:30ec\:30f3\:30b9\n\n" <>
      StringJoin[Map[
        Function[name,
          Module[{usage, defs, defCode},
            usage = Lookup[publicSymbols, name, ""];
            (* \:95a2\:6570\:5b9a\:7fa9\:30d1\:30bf\:30fc\:30f3\:3092\:62bd\:51fa *)
            defs = StringCases[code,
              RegularExpression["(?m)^" <> StringReplace[name,
                {"$" -> "\\$"}] <>
                "\\[([^\\]]*?)\\]"] :> name <> "[$1]"];
            defCode = If[Length[defs] > 0,
              "\n\n**\:547c\:3073\:51fa\:3057\:5f62\:5f0f**:\n\n```mathematica\n" <>
              StringJoin[Riffle[Union[defs], "\n"]] <> "\n```", ""];
            "### " <> name <> "\n\n" <>
            usage <> defCode <> "\n\n---\n\n"
          ]
        ],
        Keys[publicSymbols]
      ]];

    footer =
      "## 4. \:30d5\:30a1\:30a4\:30eb\:69cb\:6210\n\n" <>
      "```\n" <>
      packageName <> "/\n" <>
      "  PacletInfo.wl\n" <>
      "  Kernel/\n" <>
      "    init.wl\n" <>
      "    " <> packageName <> ".wl\n" <>
      "  Documentation/\n" <>
      "    English/\n" <>
      "      Guides/\n" <>
      "        " <> packageName <> "Overview.nb\n" <>
      "  Docs/\n" <>
      "    spec.md\n" <>
      "  Tests/\n" <>
      "    BasicTests.wlt\n" <>
      "  README.md\n" <>
      "```\n\n" <>
      "## 5. \:5909\:66f4\:5c65\:6b74\n\n" <>
      "- " <> DateString[Now, {"Year", "-", "Month", "-", "Day"}] <>
      " v1.0.0 \:2014 Paclet \:5f62\:5f0f\:3067\:521d\:7248\:4f5c\:6210\n";

    header <> toc <> funcSections <> footer
  ];

ClaudeConvertToPaclet[packageName_String] :=
  With[{nb = EvaluationNotebook[]},
  Module[{srcFile, code, publicSymbols, pacletDir, kernelDir, docDir,
          guidesDir, tutorialsDir, refsDir, symbolsDir, testsDir, docsDir,
          bdir, timestamp, preDir},
    iPrecisionConfidentialCheck[nb];

    (* \:5143\:30d5\:30a1\:30a4\:30eb\:306e\:5b58\:5728\:78ba\:8a8d *)
    srcFile = FileNameJoin[{Global`$packageDirectory, packageName <> ".wl"}];
    If[!FileExistsQ[srcFile],
      nbPrint[nb, "\:30a8\:30e9\:30fc: " <> srcFile <> " \:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093\:3002"]; Return[$Failed]];
    If[iPacletQ[packageName],
      nbPrint[nb, "\:30a8\:30e9\:30fc: " <> packageName <> " \:306f\:65e2\:306b Paclet \:5f62\:5f0f\:3067\:3059\:3002"]; Return[$Failed]];

    code = Import[srcFile, "Text"];
    publicSymbols = iExtractPublicSymbols[code];

    (* セクションヘッダーを入力セルの直前に挿入 *)
    iWriteSectionHeaderBeforeEvalCell[nb,
      "\:25b6 ClaudeConvertToPaclet: " <> packageName <>
      " (" <> DateString[Now, {"Year", "/", "Month", "/", "Day", " ", "Hour24", ":", "Minute"}] <> ")"];

    nbPrint[nb, "\:516c\:958b\:30b7\:30f3\:30dc\:30eb: " <> ToString[Length[publicSymbols]] <> " \:500b\:691c\:51fa"];

    (* \:30d0\:30c3\:30af\:30a2\:30c3\:30d7 (ClaudeUpdatePackage \:3068\:540c\:3058\:5f62\:5f0f) *)
    timestamp = DateString[Now, {"Year","Month","Day","_","Hour24","Minute","Second"}];
    bdir = backupDir[packageName];
    preDir = FileNameJoin[{bdir, "pre_paclet_" <> timestamp}];
    CreateDirectory[preDir, CreateIntermediateDirectories -> True];
    iSaveBackupWl[preDir, srcFile, packageName, True];
    nbPrint[nb, "\:30d0\:30c3\:30af\:30a2\:30c3\:30d7: " <> preDir];

    (* \:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:69cb\:9020\:3092\:4f5c\:6210 *)
    pacletDir  = FileNameJoin[{Global`$packageDirectory, packageName}];
    kernelDir  = FileNameJoin[{pacletDir, "Kernel"}];
    docDir     = FileNameJoin[{pacletDir, "Documentation", "English"}];
    guidesDir  = FileNameJoin[{docDir, "Guides"}];
    tutorialsDir = FileNameJoin[{docDir, "Tutorials"}];
    refsDir    = FileNameJoin[{docDir, "ReferencePages"}];
    symbolsDir = FileNameJoin[{refsDir, "Symbols"}];
    testsDir   = FileNameJoin[{pacletDir, "Tests"}];
    docsDir    = FileNameJoin[{pacletDir, "Docs"}];

    Scan[CreateDirectory[#, CreateIntermediateDirectories -> True] &,
      {kernelDir, guidesDir, tutorialsDir, symbolsDir, testsDir, docsDir}];

    (* PacletInfo.wl *)
    iExportUTF8[FileNameJoin[{pacletDir, "PacletInfo.wl"}],
      iGeneratePacletInfo[packageName, publicSymbols]];

    (* Kernel/init.wl *)
    iExportUTF8[FileNameJoin[{kernelDir, "init.wl"}],
      iGenerateKernelInit[packageName]];

    (* Kernel/packageName.wl \:2190 \:5143\:306e .wl \:3092\:30b3\:30d4\:30fc *)
    CopyFile[srcFile, FileNameJoin[{kernelDir, packageName <> ".wl"}]];

    (* Documentation/English/Guides/Overview.nb \:2190 Notebook \:5f0f\:3067\:30a8\:30af\:30b9\:30dd\:30fc\:30c8 *)
    Export[FileNameJoin[{guidesDir, packageName <> "Overview.nb"}],
      iGenerateGuideNB[packageName, publicSymbols]];

    (* README.md *)
    iExportUTF8[FileNameJoin[{pacletDir, "README.md"}],
      iGenerateReadme[packageName, publicSymbols]];

    (* Docs/spec.md \:2014 \:8a73\:7d30\:4ed5\:69d8\:66f8 *)
    iExportUTF8[FileNameJoin[{docsDir, "spec.md"}],
      iGenerateSpecMD[packageName, publicSymbols, code]];

    (* Tests/BasicTests.wlt (\:30b9\:30bf\:30d6) *)
    iExportUTF8[FileNameJoin[{testsDir, "BasicTests.wlt"}],
      "(* " <> packageName <> " Basic Tests *)\n" <>
      "(* Needs[\"" <> packageName <> "`\"] *)\n\n" <>
      StringJoin[Map[
        Function[name,
          "VerificationTest[\n" <>
          "  Head[" <> name <> "],\n" <>
          "  Symbol,\n" <>
          "  TestID -> \"" <> name <> "-exists\"\n" <>
          "]\n\n"
        ],
        Keys[publicSymbols]
      ]]];

    (* \:5143\:306e .wl \:3092\:524a\:9664 *)
    Quiet[DeleteFile[srcFile]];

    nbPrint[nb, "\:2705 Paclet \:5909\:63db\:5b8c\:4e86: " <> pacletDir <>
      "\n  PacletInfo.wl  \:2714" <>
      "\n  Kernel/" <> packageName <> ".wl  \:2714" <>
      "\n  Kernel/init.wl  \:2714" <>
      "\n  Documentation/  \:2714" <>
      "\n  Docs/spec.md  \:2714" <>
      "\n  Tests/  \:2714" <>
      "\n  README.md  \:2714" <>
      "\n\n\:5143\:306e " <> packageName <> ".wl \:306f\:524a\:9664\:6e08\:307f\:ff08\:30d0\:30c3\:30af\:30a2\:30c3\:30d7: " <> preDir <> "\:ff09" <>
      "\n\:30ed\:30fc\:30c9: PacletDirectoryLoad[" <> ToString[pacletDir, InputForm] <> "]; Needs[\"" <> packageName <> "`\"]"];

    pacletDir
  ]];

(* ============================================================
   Claude Directives \:7ba1\:7406
   ClaudeAddDirective / ClaudeRestoreDirective / ClaudeListDirectives
   ============================================================ *)

(* --- \:30d1\:30b9\:89e3\:6c7a\:30d8\:30eb\:30d1\:30fc --- *)

(* \:7d76\:5bfe\:30d1\:30b9 fullPath \:304b\:3089 baseDir \:3092\:57fa\:6e96\:3068\:3057\:305f\:76f8\:5bfe\:30d1\:30b9\:3092\:8fd4\:3059\:3002
   FileNameSplit \:30d9\:30fc\:30b9\:3067OS\:975e\:4f9d\:5b58\:3002\:672b\:5c3e\:30bb\:30d1\:30ec\:30fc\:30bf\:4ed8\:304d\:306e baseDir \:3082\:5b89\:5168\:306b\:51e6\:7406\:3059\:308b\:3002 *)
iRelativePath[fullPath_String, baseDir_String] :=
  Module[{baseParts, fullParts},
    baseParts = FileNameSplit[baseDir];
    fullParts = FileNameSplit[fullPath];
    If[Length[fullParts] > Length[baseParts] &&
       Take[fullParts, Length[baseParts]] === baseParts,
      FileNameJoin[Drop[fullParts, Length[baseParts]]],
      fullPath  (* baseDir が前方一致しない場合はそのまま返す *)
    ]
  ];

(* Claude Directives \:30bd\:30fc\:30b9\:30d5\:30a9\:30eb\:30c0 *)
iDirectivesSourceDir[] :=
  Module[{pkg},
    pkg = Quiet @ Check[Global`$packageDirectory, $Failed];
    If[StringQ[pkg] && pkg =!= "",
      FileNameJoin[{pkg, "Claude Directives"}],
      $Failed]
  ];

(* target \:304b\:3089\:30bd\:30fc\:30b9\:30d5\:30a1\:30a4\:30eb\:30d1\:30b9\:3092\:5f97\:308b *)
iDirectiveFilePath[target_String] :=
  Module[{srcDir = iDirectivesSourceDir[]},
    If[srcDir === $Failed, Return[$Failed]];
    If[ToLowerCase[target] === "claude.md",
      FileNameJoin[{srcDir, "CLAUDE.md"}],
      FileNameJoin[{srcDir, "skills", target, "SKILL.md"}]
    ]
  ];

(* \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:30c7\:30a3\:30ec\:30af\:30c8\:30ea *)
iDirectiveBackupDir[] :=
  Module[{srcDir = iDirectivesSourceDir[]},
    If[srcDir === $Failed, $Failed,
      FileNameJoin[{srcDir, ".directive-backups"}]]
  ];

(* --- \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:30fb\:30ea\:30b9\:30c8\:30a2 --- *)

iBackupDirectiveFile[target_String, filePath_String] :=
  Module[{bDir, ts, bFile},
    bDir = iDirectiveBackupDir[];
    If[bDir === $Failed || !FileExistsQ[filePath], Return[$Failed]];
    ts = DateString[{"Year","Month","Day","-","Hour24","Minute","Second"}];
    bDir = FileNameJoin[{bDir, target}];
    If[!DirectoryQ[bDir],
      CreateDirectory[bDir, CreateIntermediateDirectories -> True]];
    bFile = FileNameJoin[{bDir,
      FileNameTake[filePath, -1] <> ".backup-" <> ts}];
    CopyFile[filePath, bFile];
    bFile
  ];

iLatestDirectiveBackup[target_String] :=
  Module[{bDir, files},
    bDir = iDirectiveBackupDir[];
    If[bDir === $Failed, Return[$Failed]];
    bDir = FileNameJoin[{bDir, target}];
    If[!DirectoryQ[bDir], Return[$Failed]];
    files = Sort[FileNames["*.backup-*", bDir]];
    If[Length[files] === 0, $Failed, Last[files]]
  ];

(* --- \:30c7\:30a3\:30ec\:30af\:30c6\:30a3\:30d6\:5c65\:6b74\:30d0\:30c3\:30af\:30a2\:30c3\:30d7 (ClaudeUpdateDirective/ClaudeAddDirective \:7528) --- *)

(* Claude Directives_info/history \:30c7\:30a3\:30ec\:30af\:30c8\:30ea *)
iDirectiveHistoryDir[] :=
  Module[{pkg},
    pkg = Quiet @ Check[Global`$packageDirectory, $Failed];
    If[StringQ[pkg] && pkg =!= "",
      FileNameJoin[{pkg, "Claude Directives_info", "history"}],
      $Failed]
  ];

(* \:30c7\:30a3\:30ec\:30af\:30c6\:30a3\:30d6\:66f4\:65b0\:306e\:4e8b\:524d\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:3092\:4f5c\:6210
   instruction: \:6307\:793a\:30c6\:30ad\:30b9\:30c8 (prompt.txt \:306b\:4fdd\:5b58)
   targetPaths: \:5909\:66f4\:5bfe\:8c61\:30d5\:30a1\:30a4\:30eb\:306e\:30d5\:30eb\:30d1\:30b9\:306e\:30ea\:30b9\:30c8 *)
iCreateDirectiveHistoryBackup[instruction_String, targetPaths_List] :=
  Module[{histBase, srcDir, timestamp, histDir, relPath, destFile, destDir},
    histBase = iDirectiveHistoryDir[];
    If[histBase === $Failed, Return[$Failed]];
    srcDir = iDirectivesSourceDir[];
    If[srcDir === $Failed, Return[$Failed]];
    timestamp = DateString[Now, {"Year","Month","Day","_","Hour24","Minute","Second"}];
    histDir = FileNameJoin[{histBase, timestamp}];
    CreateDirectory[histDir, CreateIntermediateDirectories -> True];
    (* prompt.txt \:306b\:6307\:793a\:3092\:4fdd\:5b58 *)
    If[instruction =!= "",
      Module[{strm},
        strm = OpenWrite[FileNameJoin[{histDir, "prompt.txt"}], BinaryFormat -> True];
        BinaryWrite[strm, ToCharacterCode[instruction, "UTF-8"]];
        Close[strm]]];
    (* \:5909\:66f4\:5bfe\:8c61\:30d5\:30a1\:30a4\:30eb\:3092\:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:69cb\:9020\:3054\:3068\:30d0\:30c3\:30af\:30a2\:30c3\:30d7 *)
    Scan[Function[fullPath,
      If[FileExistsQ[fullPath],
        (* srcDir \:304b\:3089\:306e\:76f8\:5bfe\:30d1\:30b9\:3092\:4fdd\:6301 *)
        relPath = iRelativePath[fullPath, srcDir];
        destFile = FileNameJoin[{histDir, relPath}];
        destDir = DirectoryName[destFile];
        If[!DirectoryQ[destDir],
          CreateDirectory[destDir, CreateIntermediateDirectories -> True]];
        Quiet[CopyFile[fullPath, destFile]]]],
      targetPaths];
    histDir
  ];

(* \:30c7\:30a3\:30ec\:30af\:30c6\:30a3\:30d6\:5c65\:6b74\:30a8\:30f3\:30c8\:30ea\:3092\:53d6\:5f97 *)
iDirectiveHistoryEntries[] :=
  Module[{histBase, sessionDirs, dirName, promptFile, promptText, files},
    histBase = iDirectiveHistoryDir[];
    If[histBase === $Failed || !DirectoryQ[histBase], Return[{}]];
    sessionDirs = Reverse[Sort[Select[FileNames["*", histBase], DirectoryQ]]];
    MapIndexed[Function[{dir, idx},
      dirName = FileNameTake[dir, -1];
      promptFile = FileNameJoin[{dir, "prompt.txt"}];
      promptText = If[FileExistsQ[promptFile], Quiet @ Import[promptFile, "Text"], ""];
      If[!StringQ[promptText], promptText = ""];
      (* \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:30d5\:30a1\:30a4\:30eb\:4e00\:89a7\:ff08prompt.txt\:4ee5\:5916\:ff09 *)
      files = Select[FileNames["*", dir, Infinity],
        iFileQ[#] && FileNameTake[#] =!= "prompt.txt" &];
      <|
        "Index"     -> First[idx],
        "Timestamp" -> formatTimestamp[dirName],
        "Directory" -> dir,
        "DirName"   -> dirName,
        "Prompt"    -> promptText,
        "Files"     -> Map[
          iRelativePath[#, dir] &, files],
        "FileCount" -> Length[files]
      |>
    ], sessionDirs]
  ];

(* \:30c7\:30a3\:30ec\:30af\:30c6\:30a3\:30d6\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:306e Review *)
iDirectiveBackupReview[dir_String] :=
  Module[{nb, cells, dirName, files, promptFile, promptText},
    nb = EvaluationNotebook[];
    dirName = FileNameTake[dir, -1];
    files = Select[FileNames["*", dir, Infinity],
      iFileQ[#] && FileNameTake[#] =!= "prompt.txt" &];
    promptFile = FileNameJoin[{dir, "prompt.txt"}];
    promptText = If[FileExistsQ[promptFile], Quiet @ Import[promptFile, "Text"], ""];
    If[!StringQ[promptText], promptText = ""];
    cells = {Cell["\:30c7\:30a3\:30ec\:30af\:30c6\:30a3\:30d6\:30d0\:30c3\:30af\:30a2\:30c3\:30d7: " <> dirName, "Subsection"]};
    AppendTo[cells, Cell[
      "\:30c7\:30a3\:30ec\:30af\:30c8\:30ea: " <> dir <>
      "\n\:30d5\:30a1\:30a4\:30eb\:6570: " <> ToString[Length[files]] <>
      "\n\:30d5\:30a1\:30a4\:30eb: " <> StringRiffle[
        iRelativePath[#, dir] & /@ files, ", "],
      "Text"]];
    (* prompt.txt *)
    If[promptText =!= "",
      AppendTo[cells, Cell[
        "\n--- \:6307\:793a (prompt.txt) ---\n" <> StringTake[promptText, UpTo[2000]],
        "Program"]]];
    (* \:5404\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:30d5\:30a1\:30a4\:30eb\:306e\:5185\:5bb9\:30d7\:30ec\:30d3\:30e5\:30fc *)
    Do[
      Module[{relPath, content},
        relPath = iRelativePath[f, dir];
        content = Quiet @ Import[f, "Text"];
        If[StringQ[content],
          AppendTo[cells, Cell[
            "\n--- " <> relPath <> " (" <> ToString[FileByteCount[f]] <> " bytes) ---\n" <>
            StringTake[content, UpTo[1500]],
            "Program"]]]],
      {f, Take[files, UpTo[10]]}];
    (* \:30a2\:30af\:30b7\:30e7\:30f3\:30dc\:30bf\:30f3 *)
    With[{d = dir},
      AppendTo[cells, Cell[BoxData[ToBoxes[
        Row[{
          Button["Pull (\:5fa9\:5143)",
            Print[iDirectiveBackupPull[d]],
            Method -> "Queued"],
          Spacer[20],
          Button["Delete (\:524a\:9664)",
            If[ChoiceDialog["\:672c\:5f53\:306b\:524a\:9664\:3057\:307e\:3059\:304b\:ff1f\n" <> d],
              If[iSafeDeleteBackupDir[d] =!= $Failed,
                Print["\:524a\:9664\:3057\:307e\:3057\:305f: " <> d],
                Print["\:524a\:9664\:306b\:5931\:6557\:3057\:307e\:3057\:305f\:3002"]],
              Print["\:30ad\:30e3\:30f3\:30bb\:30eb\:3057\:307e\:3057\:305f\:3002"]],
            Method -> "Queued"]
        }]
      ]], "Output"]]];
    NotebookWrite[nb, Cell[CellGroupData[cells, Open]]];
    <|"Action" -> "Review", "Directory" -> dir|>
  ];

(* \:30c7\:30a3\:30ec\:30af\:30c6\:30a3\:30d6\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:306e Pull: \:30d5\:30a1\:30a4\:30eb\:3092 Claude Directives \:306b\:5fa9\:5143\:3057 ClaudeUpdateDirective[] \:3067\:540c\:671f *)
iDirectiveBackupPull[dir_String] :=
  Module[{nb, srcDir, files, relPath, destFile, destDir, restored = 0},
    nb = EvaluationNotebook[];
    srcDir = iDirectivesSourceDir[];
    If[srcDir === $Failed,
      nbPrint[nb, "\:26a0 Claude Directives \:30bd\:30fc\:30b9\:30d5\:30a9\:30eb\:30c0\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093\:3002"];
      Return[$Failed]];
    files = Select[FileNames["*", dir, Infinity],
      iFileQ[#] && FileNameTake[#] =!= "prompt.txt" &];
    Scan[Function[f,
      relPath = iRelativePath[f, dir];
      destFile = FileNameJoin[{srcDir, relPath}];
      destDir = DirectoryName[destFile];
      If[!DirectoryQ[destDir],
        CreateDirectory[destDir, CreateIntermediateDirectories -> True]];
      Quiet[CopyFile[f, destFile, OverwriteTarget -> True]];
      nbPrint[nb, "\:5fa9\:5143: " <> relPath];
      restored++],
      files];
    nbPrint[nb, "\:5b8c\:4e86: " <> ToString[restored] <> " \:30d5\:30a1\:30a4\:30eb\:3092\:5fa9\:5143\:3057\:307e\:3057\:305f\:3002"];
    <|"Action" -> "Pull", "Directory" -> dir, "Restored" -> restored|>
  ];

(* ============================================================
   ディレクティブ用ローカルスナップショット管理
   ============================================================ *)

iDirectiveSnapshotDir[] :=
  FileNameJoin[{Global`$packageDirectory, "GithubRepositories",
    "_local_snapshot", "_directive_backup"}];

iDirectiveSnapshotHashPath[] :=
  FileNameJoin[{iDirectiveSnapshotDir[], "_snapshot_hashes.json"}];

iSaveDirectiveSnapshot[] :=
  Module[{snapDir, srcDir, hashes = <||>, allFiles, relPath, dst},
    snapDir = iDirectiveSnapshotDir[];
    If[DirectoryQ[snapDir],
      Quiet @ DeleteDirectory[snapDir, DeleteContents -> True]];
    Quiet @ CreateDirectory[snapDir, CreateIntermediateDirectories -> True];
    srcDir = iDirectivesSourceDir[];
    If[srcDir === $Failed, Return[$Failed]];
    If[!DirectoryQ[srcDir], Return[$Failed]];
    allFiles = Select[FileNames["*", srcDir, Infinity],
      FileExistsQ[#] && !DirectoryQ[#] &];
    Do[
      relPath = iRelativePath[f, srcDir];
      dst = FileNameJoin[{snapDir, relPath}];
      Quiet @ CreateDirectory[DirectoryName[dst], CreateIntermediateDirectories -> True];
      Quiet @ CopyFile[f, dst, OverwriteTarget -> True];
      hashes[StringJoin[Riffle[FileNameSplit[relPath], "/"]]] =
        Quiet @ Check[FileHash[f, "SHA256", "HexString"], ""],
      {f, allFiles}];
    Export[iDirectiveSnapshotHashPath[], hashes, "RawJSON"];
    <|"Action" -> "SaveDirectiveSnapshot",
      "SnapshotDir" -> snapDir, "HashedFiles" -> Length[hashes]|>
  ];

iRestoreDirectiveSnapshot[] :=
  Module[{snapDir, srcDir, allFiles, relPath, dst, restored = 0, nb},
    snapDir = iDirectiveSnapshotDir[];
    If[!DirectoryQ[snapDir],
      Return[Failure["NoSnapshot", <|"Message" -> "スナップショットなし"|>]]];
    srcDir = iDirectivesSourceDir[];
    If[srcDir === $Failed, Return[$Failed]];
    nb = Quiet[EvaluationNotebook[]];
    allFiles = Select[FileNames["*", snapDir, Infinity],
      FileExistsQ[#] && !DirectoryQ[#] &&
        FileNameTake[#] =!= "_snapshot_hashes.json" &];
    Do[
      relPath = iRelativePath[f, snapDir];
      dst = FileNameJoin[{srcDir, relPath}];
      Quiet @ CreateDirectory[DirectoryName[dst], CreateIntermediateDirectories -> True];
      Quiet @ CopyFile[f, dst, OverwriteTarget -> True];
      nbPrint[nb, "復元: " <> relPath];
      restored++,
      {f, allFiles}];
    nbPrint[nb, "完了: " <> ToString[restored] <> " ファイルを復元しました。"];
    <|"Action" -> "RestoreDirectiveSnapshot", "FilesRestored" -> restored|>
  ];

iDetectDirectiveChanges[] :=
  Module[{snapDir, hashPath, savedHashes, srcDir, changedFiles = {},
          allFiles, relPath, currentHash, savedHash},
    snapDir = iDirectiveSnapshotDir[];
    If[!DirectoryQ[snapDir], Return[{}]];
    hashPath = iDirectiveSnapshotHashPath[];
    savedHashes = Quiet @ Check[Import[hashPath, "RawJSON"], <||>];
    If[!AssociationQ[savedHashes], savedHashes = <||>];
    srcDir = iDirectivesSourceDir[];
    If[srcDir === $Failed || !DirectoryQ[srcDir], Return[{}]];
    allFiles = Select[FileNames["*", srcDir, Infinity],
      FileExistsQ[#] && !DirectoryQ[#] &];
    Do[
      relPath = iRelativePath[f, srcDir];
      relPath = StringJoin[Riffle[FileNameSplit[relPath], "/"]];
      currentHash = Quiet @ Check[FileHash[f, "SHA256", "HexString"], ""];
      savedHash = Lookup[savedHashes, relPath, None];
      If[savedHash === None || currentHash =!= savedHash,
        AppendTo[changedFiles, relPath]],
      {f, allFiles}];
    changedFiles
  ];

(* ディレクティブ履歴を Grid で表示 *)
ClaudeDirectiveBackupDataset[] :=
  Module[{entries, gridRows, header, localRow, outputTag, warningTag,
          gridResult, snapDir},
    (* 起動時: スナップショット保存 *)
    snapDir = iDirectiveSnapshotDir[];
    If[DirectoryQ[snapDir],
      Quiet @ DeleteDirectory[snapDir, DeleteContents -> True]];
    iSaveDirectiveSnapshot[];
    entries = iDirectiveHistoryEntries[];
    If[Length[entries] === 0,
      Print["\:30c7\:30a3\:30ec\:30af\:30c6\:30a3\:30d6\:306e\:66f4\:65b0\:5c65\:6b74\:304c\:3042\:308a\:307e\:305b\:3093\:3002"]; Return[{}]];
    outputTag = "ClaudeDirectiveBackupDataset$output";
    warningTag = "ClaudeDirectiveBackupDataset$warning";
    header = {Style["#", Bold], Style["Timestamp", Bold],
      Style["\:6307\:793a", Bold], Style["\:30d5\:30a1\:30a4\:30eb", Bold], Style["Actions", Bold]};
    (* #0 行: ローカル最新版 *)
    localRow = {
      Style[0, Bold, RGBColor[0, 0.5, 0]],
      Style["local", FontFamily -> "Courier", FontColor -> RGBColor[0, 0.5, 0]],
      "(スナップショット保存済み)",
      "ローカル最新版",
      With[{oTag = outputTag, wTag = warningTag},
        Row[{
          Button["Pull",
            Module[{newerFiles, msg, nb, outputIndices, outputIdx, cells},
              nb = Quiet[EvaluationNotebook[]];
              If[!DirectoryQ[iDirectiveSnapshotDir[]],
                Print["スナップショットが存在しません。"],
                newerFiles = iDetectDirectiveChanges[];
                If[Length[newerFiles] > 0,
                  msg = "以下の " <> ToString[Length[newerFiles]] <>
                    " ファイルがスナップショットから変更されています:\n\n" <>
                    StringRiffle[Take[newerFiles, UpTo[10]], "\n"] <>
                    If[Length[newerFiles] > 10,
                      "\n... 他 " <> ToString[Length[newerFiles] - 10] <> " ファイル", ""] <>
                    "\n\nローカル最新版で上書きすると、これらの変更は失われます。";
                  NBAccess`NBDeleteCellsByTag[nb, wTag];
                  outputIndices = NBAccess`NBCellIndicesByTag[nb, oTag];
                  If[Length[outputIndices] > 0,
                    NBAccess`NBMoveAfterCell[nb, Last[outputIndices]],
                    Quiet[SelectionMove[EvaluationCell[], After, Cell]]];
                  cells = Cell[CellGroupData[{
                    Cell["\:26a0 ローカル最新版への復元", "Subsubsection",
                      CellTags -> {wTag}],
                    Cell[msg, "Text"],
                    Cell[BoxData[ToBoxes[Row[{
                      Button["すべてローカル最新版に置き換える",
                        Module[{res, nb2},
                          nb2 = Quiet[EvaluationNotebook[]];
                          res = iRestoreDirectiveSnapshot[];
                          If[!FailureQ[res],
                            Print["ローカル最新版に復元: " <>
                              ToString[res["FilesRestored"]] <> " ファイル"],
                            Print[res]];
                          NBAccess`NBDeleteCellsByTag[nb2, wTag]],
                        Method -> "Queued"],
                      Spacer[20],
                      Button["キャンセル",
                        Module[{nb2},
                          nb2 = Quiet[EvaluationNotebook[]];
                          NBAccess`NBDeleteCellsByTag[nb2, wTag]],
                        Method -> "Queued"]
                    }]]], "Output"]
                  }, Open]];
                  NotebookWrite[nb, cells],
                  (* 変更なし *)
                  If[ChoiceDialog["ローカル最新版に復元しますか？"],
                    Module[{res},
                      res = iRestoreDirectiveSnapshot[];
                      If[!FailureQ[res],
                        Print["ローカル最新版に復元: " <>
                          ToString[res["FilesRestored"]] <> " ファイル"],
                        Print[res]]],
                    Print["キャンセルしました。"]]
                ]]],
            Method -> "Queued", ImageSize -> {52, 22}]
        }, Spacer[3]]]
    };
    gridRows = Map[
      Function[entry,
        Module[{num, ts, prompt, filesSummary, dir},
          num = entry["Index"];
          ts = entry["Timestamp"];
          prompt = entry["Prompt"];
          dir = entry["Directory"];
          filesSummary = StringRiffle[
            Function[fp, Module[{parts = FileNameSplit[fp], idx},
              Which[
                MemberQ[parts, "skills"] && MemberQ[parts, "SKILL.md"],
                  idx = FirstPosition[parts, "skills", {0}, {1}][[1]];
                  If[idx > 0 && idx < Length[parts],
                    "skills/" <> parts[[idx + 1]], Last[parts]],
                MemberQ[parts, "rules"],
                  "rules/" <> Last[parts],
                True, Last[parts]
              ]]] /@ entry["Files"], ", "];
          {num,
           ts,
           iTruncatePrompt[prompt],
           Style[StringTake[filesSummary, UpTo[25]], FontSize -> 10],
           Row[{
             With[{d = dir},
               Button["Review",
                 iDirectiveBackupReview[d],
                 Method -> "Queued", ImageSize -> {52, 22}]],
             With[{d = dir},
               Button["Pull",
                 If[ChoiceDialog["\:5fa9\:5143\:3057\:307e\:3059\:304b\:ff1f\n" <> d],
                   Print[iDirectiveBackupPull[d]],
                   Print["\:30ad\:30e3\:30f3\:30bb\:30eb\:3057\:307e\:3057\:305f\:3002"]],
                 Method -> "Queued", ImageSize -> {52, 22}]],
             With[{d = dir},
               Button["Delete",
                 If[ChoiceDialog["\:672c\:5f53\:306b\:524a\:9664\:3057\:307e\:3059\:304b\:ff1f\n" <> d],
                   If[iSafeDeleteBackupDir[d] =!= $Failed,
                     Print["\:524a\:9664\:3057\:307e\:3057\:305f: " <> d],
                     Print["\:524a\:9664\:306b\:5931\:6557\:3057\:307e\:3057\:305f\:3002"]],
                   Print["\:30ad\:30e3\:30f3\:30bb\:30eb\:3057\:307e\:3057\:305f\:3002"]],
                 Method -> "Queued", ImageSize -> {52, 22}]]
           }, Spacer[3]]}
        ]],
      entries];
    gridResult = Grid[Prepend[Prepend[gridRows, localRow], header],
      Alignment -> {Left, Center},
      Dividers -> {None, {2 -> GrayLevel[0.7]}},
      Spacings -> {1.5, 0.8},
      Background -> {None, {GrayLevel[0.95], None}},
      ItemSize -> {{3, 14, 20, 20, Automatic}, Automatic}];
    Module[{nb = Quiet[EvaluationNotebook[]]},
      NBAccess`NBDeleteCellsByTag[nb, warningTag];
      NBAccess`NBDeleteCellsByTag[nb, outputTag]];
    CellPrint[Cell[BoxData[ToBoxes[gridResult]], "Output",
      CellTags -> {outputTag}]];
  ];

(* --- ディレクティブのインストール: コピーは自動化されたため不要 --- *)
(* 旧 install-claude-directives.wl は不要 *)

iRunInstallClaudeDirectives[] := Null;

(* --- \:30c7\:30a3\:30ec\:30af\:30c6\:30a3\:30d6\:6574\:5f62\:7528\:30d7\:30ed\:30f3\:30d7\:30c8 --- *)

$directiveRefinePrompt = "\
You are editing a Claude Code directive file (CLAUDE.md or SKILL.md) for a Wolfram Language / Mathematica power user.\n\
The user gives a rough description of a rule or guideline to add.\n\
Your job:\n\
1. Read the EXISTING CONTENT of the file (provided below) to understand the context, style, and formatting.\n\
2. Rewrite the user's rough description into a precise, concise directive that matches the existing style.\n\
3. Output ONLY the new directive text to be appended (no preamble, no explanation, no markdown fences).\n\
4. Use the same heading level, bullet style, and language (English or Japanese) as the existing file.\n\
5. If the existing content uses section headers (## or ###), place your directive under an appropriate existing section or create a new one if needed.\n\
6. Start the output with a blank line for clean separation from existing content.\n\
7. NEVER output meta-commentary such as 'The rule already exists', 'No change needed', or any explanation about your decision. Output ONLY the directive text itself.\n\
8. If an equivalent rule already exists, output a refined/improved version that replaces or extends it.\n\n";

(* --- ディレクティブ書き込みガード ---
   iSafeWriteDirective: ドキュメントの iSafeWriteDoc と同様、
   サイズ退行・内容置換を検出してファイル破損を防止する。
   
   検証項目:
   1. サイズ退行: 既存の 40% 未満に縮小 → 拒否
   2. タイトル保持: CLAUDE.md の先頭 # タイトルが変わっていたら → 拒否
   3. SKILL.md のスキル名保持: name: 行が消滅 → 拒否
   
   action が "append" の場合は既存に追記するだけなのでガード不要。
   Return: True (書き込み成功) / $Failed (拒否) *)
iSafeWriteDirective[fullPath_String, content_String, action_String:"replace"] :=
  Module[{existing, existingLen, newLen, fileName, existingTitle, newTitle,
          existingSkillName, newSkillName},
    fileName = FileNameTake[fullPath];
    (* append の場合はそのまま書き込み *)
    If[action === "append" && FileExistsQ[fullPath],
      Module[{old = Import[fullPath, "Text"]},
        Export[fullPath, old <> "\n" <> content, "Text"]];
      Return[True]];
    (* === ガード1: サイズ退行チェック === *)
    If[FileExistsQ[fullPath],
      existing = Quiet @ Check[Import[fullPath, "Text"], ""];
      If[StringQ[existing] && StringLength[existing] > 100,
        existingLen = StringLength[existing];
        newLen = StringLength[StringTrim[content]];
        If[newLen < existingLen * 0.4,
          Print["  \:26a0 iSafeWriteDirective: \:30b5\:30a4\:30ba\:9000\:884c\:3092\:691c\:51fa (" <> fileName <> "): " <>
            ToString[existingLen] <> " \:2192 " <> ToString[newLen] <>
            " \:6587\:5b57 (" <> ToString[Round[100. newLen / existingLen]] <> "%)\:3002\:66f8\:304d\:8fbc\:307f\:3092\:62d2\:5426\:3057\:307e\:3057\:305f\:3002"];
          Return[$Failed]]]];
    (* === ガード2: CLAUDE.md タイトル整合性 === *)
    If[fileName === "CLAUDE.md" && FileExistsQ[fullPath],
      existing = Quiet @ Check[Import[fullPath, "Text"], ""];
      If[StringQ[existing],
        existingTitle = iExtractDocTitle[existing];
        newTitle = iExtractDocTitle[content];
        If[StringQ[existingTitle] && StringLength[existingTitle] > 0 &&
           StringQ[newTitle] && StringLength[newTitle] > 0 &&
           ToLowerCase[existingTitle] =!= ToLowerCase[newTitle],
          Print["  \:26a0 iSafeWriteDirective: CLAUDE.md \:30bf\:30a4\:30c8\:30eb\:4e0d\:6574\:5408: \"" <>
            existingTitle <> "\" \:2192 \"" <> newTitle <> "\"\:3002\:66f8\:304d\:8fbc\:307f\:3092\:62d2\:5426\:3057\:307e\:3057\:305f\:3002"];
          Return[$Failed]]]];
    (* === ガード3: SKILL.md のスキル名保持 === *)
    If[fileName === "SKILL.md" && FileExistsQ[fullPath],
      existing = Quiet @ Check[Import[fullPath, "Text"], ""];
      If[StringQ[existing],
        existingSkillName = First[StringCases[existing,
          RegularExpression["(?m)^name:\\s*(.+)$"] :> "$1", 1], ""];
        newSkillName = First[StringCases[content,
          RegularExpression["(?m)^name:\\s*(.+)$"] :> "$1", 1], ""];
        If[StringLength[existingSkillName] > 0 &&
           StringLength[newSkillName] > 0 &&
           StringTrim[existingSkillName] =!= StringTrim[newSkillName],
          Print["  \:26a0 iSafeWriteDirective: SKILL.md \:540d\:524d\:4e0d\:6574\:5408: \"" <>
            existingSkillName <> "\" \:2192 \"" <> newSkillName <> "\"\:3002\:66f8\:304d\:8fbc\:307f\:3092\:62d2\:5426\:3057\:307e\:3057\:305f\:3002"];
          Return[$Failed]]]];
    (* すべてのガードを通過 → 書き込み *)
    Export[fullPath, content, "Text"];
    True
  ];

(* --- メイン関数 --- *)

ClaudeAddDirective::nosrc = "Claude Directives \:30bd\:30fc\:30b9\:30d5\:30a9\:30eb\:30c0\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093\:3002";
ClaudeAddDirective::nofile = "\:30bf\:30fc\:30b2\:30c3\:30c8\:30d5\:30a1\:30a4\:30eb\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093: `1`";
ClaudeAddDirective::queryerr = "Claude \:30af\:30a8\:30ea\:306b\:5931\:6557\:3057\:307e\:3057\:305f\:3002";

Options[ClaudeAddDirective] = {DryRun -> False};

ClaudeAddDirective[target_String, description_String, OptionsPattern[]] :=
  Module[{filePath, existing, prompt, refined, backupFile, installResult,
          dryRunQ = TrueQ[OptionValue[DryRun]]},

    (* 1. \:30d5\:30a1\:30a4\:30eb\:30d1\:30b9\:89e3\:6c7a *)
    filePath = iDirectiveFilePath[target];
    If[filePath === $Failed,
      Message[ClaudeAddDirective::nosrc]; Return[$Failed]];
    If[!FileExistsQ[filePath],
      Message[ClaudeAddDirective::nofile, filePath]; Return[$Failed]];

    (* 2. \:65e2\:5b58\:5185\:5bb9\:3092\:8aad\:307f\:8fbc\:307f *)
    existing = Import[filePath, "Text"];

    (* 3. Claude \:3067\:6574\:5f62 *)
    Print["[Refine] Claude \:3067\:30c7\:30a3\:30ec\:30af\:30c6\:30a3\:30d6\:3092\:6574\:5f62\:4e2d..."];
    prompt = $directiveRefinePrompt <>
      "=== EXISTING FILE CONTENT ===\n" <> existing <>
      "\n=== END EXISTING CONTENT ===\n\n" <>
      "=== USER'S ROUGH DESCRIPTION ===\n" <> description <>
      "\n=== END DESCRIPTION ===\n\n" <>
      "Output the refined directive text to append:";

    refined = iClaudeQueryRaw[prompt];
    If[StringStartsQ[refined, "Error"],
      Message[ClaudeAddDirective::queryerr];
      Print[refined]; Return[$Failed]];

    (* \:78ba\:8a8d\:8868\:793a *)
    Print["\n\:2500\:2500\:2500 \:8ffd\:52a0\:3059\:308b\:30c7\:30a3\:30ec\:30af\:30c6\:30a3\:30d6 (" <> target <> ") \:2500\:2500\:2500"];
    Print[refined];
    Print["\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500\:2500"];

    If[dryRunQ,
      Print["[DryRun] \:30d5\:30a1\:30a4\:30eb\:306f\:5909\:66f4\:3055\:308c\:307e\:305b\:3093\:3002"];
      Return[<|"Target" -> target, "Refined" -> refined, "DryRun" -> True|>]];

    (* 4. \:30d0\:30c3\:30af\:30a2\:30c3\:30d7 *)
    backupFile = iBackupDirectiveFile[target, filePath];
    If[backupFile =!= $Failed,
      Print["[Backup] \:30d0\:30c3\:30af\:30a2\:30c3\:30d7: " <> backupFile],
      Print["\:26a0 \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:4f5c\:6210\:306b\:5931\:6557\:3057\:307e\:3057\:305f\:304c\:7d9a\:884c\:3057\:307e\:3059\:3002"]];
    (* \:5c65\:6b74\:30d0\:30c3\:30af\:30a2\:30c3\:30d7 *)
    Module[{histDir},
      histDir = iCreateDirectiveHistoryBackup[
        "ClaudeAddDirective[\"" <> target <> "\", \"" <> StringTake[description, UpTo[200]] <> "\"]",
        {filePath}];
      If[StringQ[histDir],
        Print["[History] " <> histDir]]];

    (* 5. \:30d5\:30a1\:30a4\:30eb\:306b\:8ffd\:52a0 *)
    Block[{strm, appendText},
      appendText = If[StringEndsQ[existing, "\n"], "", "\n"] <> "\n" <>
        StringTrim[refined] <> "\n";
      strm = OpenAppend[filePath, BinaryFormat -> True];
      BinaryWrite[strm,
        ExportString[appendText, "Text", CharacterEncoding -> "UTF-8"]];
      Close[strm];
    ];
    Print["[OK] \:30d5\:30a1\:30a4\:30eb\:3092\:66f4\:65b0: " <> filePath];

    (* 6. ディレクティブを $ClaudeWorkingDirectory へコピー *)
    Print["[Install] ClaudeUpdateDirective[] \:3092\:5b9f\:884c\:4e2d..."];
    installResult = iRunInstallClaudeDirectives[];

    <|"Target" -> target, "FilePath" -> filePath,
      "BackupFile" -> backupFile, "Refined" -> refined,
      "Installed" -> installResult|>
  ];

(* --- \:30ea\:30b9\:30c8\:30a2 --- *)

ClaudeRestoreDirective::nobackup = "\:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093: `1`";

ClaudeRestoreDirective[target_String] :=
  Module[{filePath, backupFile, installResult},
    filePath = iDirectiveFilePath[target];
    If[filePath === $Failed,
      Message[ClaudeAddDirective::nosrc]; Return[$Failed]];

    backupFile = iLatestDirectiveBackup[target];
    If[backupFile === $Failed,
      Message[ClaudeRestoreDirective::nobackup, target]; Return[$Failed]];

    (* \:30d0\:30c3\:30af\:30a2\:30c3\:30d7\:3092\:5fa9\:5143 *)
    CopyFile[backupFile, filePath, OverwriteTarget -> True];
    Print["[OK] \:5fa9\:5143\:3057\:307e\:3057\:305f: " <> backupFile <> "\n\:2192 " <> filePath];

    (* ディレクティブを $ClaudeWorkingDirectory へコピー *)
    Print["[Install] ClaudeUpdateDirective[] \:3092\:5b9f\:884c\:4e2d..."];
    installResult = iRunInstallClaudeDirectives[];

    <|"Target" -> target, "RestoredFrom" -> backupFile,
      "FilePath" -> filePath, "Installed" -> installResult|>
  ];

(* --- \:4e00\:89a7\:8868\:793a --- *)

ClaudeListDirectives[] :=
  Module[{srcDir, claudeMD, skillDirs, skills, result = {}},
    srcDir = iDirectivesSourceDir[];
    If[srcDir === $Failed,
      Print["\:26a0 Claude Directives \:30d5\:30a9\:30eb\:30c0\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093\:3002"]; Return[$Failed]];

    (* CLAUDE.md *)
    claudeMD = FileNameJoin[{srcDir, "CLAUDE.md"}];
    If[FileExistsQ[claudeMD],
      AppendTo[result, <|"Target" -> "CLAUDE.md",
        "Path" -> claudeMD,
        "Size" -> FileByteCount[claudeMD],
        "LastModified" -> DateObject[FileDate[claudeMD]],
        "LatestBackup" -> iLatestDirectiveBackup["CLAUDE.md"]|>]
    ];

    (* \:30b9\:30ad\:30eb *)
    skillDirs = FileNameJoin[{srcDir, "skills"}];
    If[DirectoryQ[skillDirs],
      skills = Select[FileNames["*", skillDirs], DirectoryQ];
      Do[
        Module[{name = FileNameTake[sd], skillFile},
          skillFile = FileNameJoin[{sd, "SKILL.md"}];
          If[FileExistsQ[skillFile],
            AppendTo[result, <|"Target" -> name,
              "Path" -> skillFile,
              "Size" -> FileByteCount[skillFile],
              "LastModified" -> DateObject[FileDate[skillFile]],
              "LatestBackup" -> iLatestDirectiveBackup[name]|>]
          ]
        ],
        {sd, Sort[skills]}
      ]
    ];

    Print["[Directives] Claude Directives (" <> srcDir <> ")"];
    Print["  \:30bf\:30fc\:30b2\:30c3\:30c8: " <> ToString[Length[result]] <> " \:30d5\:30a1\:30a4\:30eb"];
    Do[
      Print["  \:30fb " <> r["Target"] <> "  (" <> ToString[r["Size"]] <> " bytes" <>
        If[r["LatestBackup"] =!= $Failed, ", backup\:3042\:308a", ""] <> ")"],
      {r, result}
    ];

    Dataset[result]
  ];

(* ============================================================
   ClaudeSyncDirectives: 外部ディレクトリから Claude Directives への同期
   dir 側の方が新しいファイル、または dir にだけ存在するファイルをコピーする。
   Claude Directives 側にしかないファイルは何もしない。
   ============================================================ *)

ClaudeSyncDirectives[dir_String] :=
  With[{nb = Quiet[EvaluationNotebook[]]},
  Module[{srcDir, dirNorm, dirFiles, relPaths, copied = {}, skipped = 0,
          dirPath, dstPath, dstDir, workDir, dotClaude, dotPath, dotDir},
    (* Claude Directives ソースフォルダを取得 *)
    srcDir = iDirectivesSourceDir[];
    If[srcDir === $Failed,
      nbPrint[nb, "\:26a0 Claude Directives \:30bd\:30fc\:30b9\:30d5\:30a9\:30eb\:30c0\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093\:3002"];
      Return[$Failed]];
    If[!DirectoryQ[dir],
      nbPrint[nb, "\:26a0 \:6307\:5b9a\:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:304c\:5b58\:5728\:3057\:307e\:305b\:3093: " <> dir];
      Return[$Failed]];
    (* dir を正規化 (末尾セパレータ等を統一) *)
    dirNorm = FileNameJoin[FileNameSplit[dir]];
    (* dir 内の全ファイルを再帰取得し、相対パスを計算 *)
    dirFiles = FileNames["*", dirNorm, Infinity];
    dirFiles = Select[dirFiles, !DirectoryQ[#] &];
    (* .directive-backups や隠しフォルダは除外 *)
    dirFiles = Select[dirFiles,
      !MemberQ[FileNameSplit[#], s_String /; (StringStartsQ[s, "."] || s === ".directive-backups")] &];
    relPaths = iRelativePath[#, dirNorm] & /@ dirFiles;

    nbPrint[nb, "[ClaudeSyncDirectives] " <> dirNorm <> " \[RightArrow] " <> srcDir];
    If[!DirectoryQ[srcDir],
      nbPrint[nb, "\:26a0 \:30b3\:30d4\:30fc\:5148\:30c7\:30a3\:30ec\:30af\:30c8\:30ea\:304c\:5b58\:5728\:3057\:307e\:305b\:3093\:3002\:4f5c\:6210\:3057\:307e\:3059: " <> srcDir];
      Quiet @ CreateDirectory[srcDir, CreateIntermediateDirectories -> True]];
    nbPrint[nb, "  \:691c\:67fb\:5bfe\:8c61: " <> ToString[Length[relPaths]] <> " \:30d5\:30a1\:30a4\:30eb" <>
      " | \:30b3\:30d4\:30fc\:5148\:65e2\:5b58: " <> ToString[Length[Select[FileNames["*", srcDir, Infinity], !DirectoryQ[#] &]]] <> " \:30d5\:30a1\:30a4\:30eb"];

    (* 作業ディレクトリの .claude にもコピーするための準備 *)
    workDir = iEnsureClaudeWorkingDirectory[];
    dotClaude = FileNameJoin[{workDir, ".claude"}];

    Do[
      dirPath = FileNameJoin[Flatten[{dirNorm, FileNameSplit[rel]}]];
      dstPath = FileNameJoin[Flatten[{srcDir, FileNameSplit[rel]}]];
      If[FileExistsQ[dstPath],
        (* 両方に存在: ファイル内容を比較 (日時はOS/コピー操作で信頼できない) *)
        If[FileHash[dirPath, "SHA256"] =!= FileHash[dstPath, "SHA256"],
          (* 内容が異なる: コピー *)
          dstDir = DirectoryName[dstPath];
          If[!DirectoryQ[dstDir],
            Quiet @ CreateDirectory[dstDir, CreateIntermediateDirectories -> True]];
          Quiet @ CopyFile[dirPath, dstPath, OverwriteTarget -> True];
          AppendTo[copied, rel <> " (\:66f4\:65b0)"],
          (* 内容が同一: スキップ *)
          skipped++],
        (* dir にだけ存在: 新規コピー *)
        dstDir = DirectoryName[dstPath];
        If[!DirectoryQ[dstDir],
          Quiet @ CreateDirectory[dstDir, CreateIntermediateDirectories -> True]];
        Quiet @ CopyFile[dirPath, dstPath];
        AppendTo[copied, rel <> " (\:65b0\:898f)"]
      ];
      (* .claude にもコピー *)
      If[MemberQ[copied, rel <> " (\:66f4\:65b0)"] || MemberQ[copied, rel <> " (\:65b0\:898f)"],
        dotPath = FileNameJoin[Flatten[{dotClaude, FileNameSplit[rel]}]];
        dotDir = DirectoryName[dotPath];
        If[!DirectoryQ[dotDir],
          Quiet @ CreateDirectory[dotDir, CreateIntermediateDirectories -> True]];
        Quiet @ CopyFile[dirPath, dotPath, OverwriteTarget -> True]],
      {rel, relPaths}];

    (* 結果表示 *)
    If[Length[copied] > 0,
      iLoadClaudeMD[];
      nbPrint[nb, "\:2705 \:30b3\:30d4\:30fc\:3057\:305f\:30d5\:30a1\:30a4\:30eb (" <> ToString[Length[copied]] <> " \:4ef6):"];
      Do[nbPrint[nb, "  \:2022 " <> f], {f, copied}],
      nbPrint[nb, "\:2705 \:66f4\:65b0\:304c\:5fc5\:8981\:306a\:30d5\:30a1\:30a4\:30eb\:306f\:3042\:308a\:307e\:305b\:3093\:3067\:3057\:305f\:3002"]];
    If[skipped > 0,
      nbPrint[nb, "  (\:30b9\:30ad\:30c3\:30d7: " <> ToString[skipped] <> " \:30d5\:30a1\:30a4\:30eb \:2014 \:5185\:5bb9\:540c\:4e00)"]];
    copied
  ]];

(* Claude Directives ソースから作業ディレクトリへ全ファイルをコピーする *)
ClaudeUpdateDirective[] :=
  Module[{srcDir, nb},
    nb = Quiet[InputNotebook[]];
    srcDir = iDirectivesSourceDir[];
    If[srcDir === $Failed,
      nbPrint[nb, "\:26a0 Claude Directives \:30bd\:30fc\:30b9\:30d5\:30a9\:30eb\:30c0\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093\:3002"];
      Return[$Failed]];
    iLoadClaudeMD[];
    (* セクションヘッダーを入力セルの直前に挿入 *)
    iWriteSectionHeaderBeforeEvalCell[nb,
      "\:25b6 ClaudeUpdateDirective (" <>
      DateString[Now, {"Year", "/", "Month", "/", "Day", " ", "Hour24", ":", "Minute"}] <> ")"];
    nbPrint[nb, "[ClaudeUpdateDirective] \:30bd\:30fc\:30b9\:30b3\:30fc\:30c9\:3068\:306e\:6574\:5408\:6027\:30c1\:30a7\:30c3\:30af\:3092\:958b\:59cb..."];
    iCheckAndFixDirectiveConsistency[nb, srcDir]
  ];

(* ソースコードとディレクティブの整合性チェック・自動修正
   基盤パッケージ (claudecode.wl, github.wl, NBAccess.wl) の公開関数・オプションを
   ソースコードから抽出し、CLAUDE.md/rules/skills との不整合を Claude に修正させる。 *)
iCheckAndFixDirectiveConsistency[nb_NotebookObject, srcDir_String] :=
  Module[{pkgDir, sourceFiles, sourceSummaries, directiveContents,
          allFiles, prompt, response, parsed, files, path, action, content,
          fullPath, dir, updated = 0, workDir, dotClaude},
    pkgDir = Global`$packageDirectory;
    (* 基盤パッケージのソースから公開関数・オプションを抽出 *)
    sourceFiles = {
      {"claudecode", FileNameJoin[{pkgDir, "claudecode.wl"}]},
      {"github", FileNameJoin[{pkgDir, "github.wl"}]},
      {"NBAccess", FileNameJoin[{pkgDir, "NBAccess.wl"}]}
    };
    sourceSummaries = StringJoin[Map[
      Function[{pair},
        Module[{name = pair[[1]], file = pair[[2]], code, usages, opts},
          If[!FileExistsQ[file], "",
            code = Quiet @ Import[file, "Text"];
            If[!StringQ[code], "",
              (* usage 宣言から公開関数名を抽出 *)
              usages = StringCases[code,
                RegularExpression["(\\w+)::usage\\s*="] :> "$1"];
              (* Options 宣言を抽出 *)
              opts = StringCases[code,
                RegularExpression["Options\\[(\\w+)\\]\\s*=\\s*\\{([^}]+)\\}"] :>
                  {"$1", "$2"}];
              "=== " <> name <> ".wl public symbols ===\n" <>
              "Functions: " <> StringRiffle[DeleteDuplicates[usages], ", "] <> "\n" <>
              StringJoin[("Options[" <> #[[1]] <> "] = {" <> #[[2]] <> "}\n") & /@ opts] <>
              "\n"]]]],
      sourceFiles]];
    If[StringLength[sourceSummaries] < 50,
      nbPrint[nb, "  \:30bd\:30fc\:30b9\:30b3\:30fc\:30c9\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093\:3002\:30b9\:30ad\:30c3\:30d7\:3057\:307e\:3059\:3002"];
      Return[]];
    (* 現在のディレクティブ内容を収集 *)
    allFiles = Join[
      If[FileExistsQ[FileNameJoin[{srcDir, "CLAUDE.md"}]],
        {{"CLAUDE.md", Import[FileNameJoin[{srcDir, "CLAUDE.md"}], "Text"]}}, {}],
      ({"rules/" <> FileNameTake[#], Import[#, "Text"]} & /@
        FileNames["*.md", FileNameJoin[{srcDir, "rules"}]]),
      ({"skills/" <> FileNameTake[DirectoryName[#]] <> "/SKILL.md", Import[#, "Text"]} & /@
        FileNames["SKILL.md", FileNameJoin[{srcDir, "skills"}], 2])
    ];
    directiveContents = StringJoin[
      ("--- " <> #[[1]] <> " ---\n" <> #[[2]] <> "\n\n") & /@ allFiles];
    (* Claude に不整合を検出・修正させる *)
    prompt = $directiveUpdatePrompt <>
      "INSTRUCTION:\n" <>
      "Check the consistency between the source code public API and the directive files.\n" <>
      "Fix any inconsistencies found:\n" <>
      "1. Function names in directives that don't exist in source (remove or correct them)\n" <>
      "2. New functions/options in source that should be documented in directives (add them)\n" <>
      "3. Wrong option names or default values (correct them)\n" <>
      "4. Missing natural language mappings in github-operations SKILL.md\n" <>
      "5. Any factual errors about function behavior\n" <>
      "If NO changes are needed, output exactly: NO_CHANGES_NEEDED\n" <>
      "Only output files that actually need changes.\n\n" <>
      "=== SOURCE CODE PUBLIC API ===\n" <> sourceSummaries <> "\n" <>
      "=== CURRENT DIRECTIVE FILES ===\n" <> directiveContents;
    nbPrint[nb, "  Claude \:306b\:6574\:5408\:6027\:30c1\:30a7\:30c3\:30af\:3092\:4f9d\:983c\:4e2d..."];
    response = Quiet @ Check[iClaudeQueryRaw[prompt], $Failed];
    If[iIsAPIErrorResponse[response],
      nbPrint[nb, "  \:26a0 API \:30a8\:30e9\:30fc\:306e\:305f\:3081\:6574\:5408\:6027\:30c1\:30a7\:30c3\:30af\:3092\:30b9\:30ad\:30c3\:30d7\:3057\:307e\:3057\:305f\:3002"];
      Return[]];
    (* デリミタ形式パース *)
    If[StringContainsQ[response, "NO_CHANGES_NEEDED"],
      nbPrint[nb, "  \:2713 \:6574\:5408\:6027\:30c1\:30a7\:30c3\:30af\:5b8c\:4e86: \:4e0d\:6574\:5408\:306a\:3057\:3002"];
      Return[]];
    files = iParseDelimitedFileBlocks[response];
    If[Length[files] === 0,
      nbPrint[nb, "  \:6574\:5408\:6027\:30c1\:30a7\:30c3\:30af\:5b8c\:4e86: \:4e0d\:6574\:5408\:306a\:3057\:3002"];
      Return[]];
    (* 修正を適用 *)
    workDir = iEnsureClaudeWorkingDirectory[];
    dotClaude = FileNameJoin[{workDir, ".claude"}];
    Do[
      path = Lookup[f, "path", ""];
      action = Lookup[f, "action", "replace"];
      content = Lookup[f, "content", ""];
      If[path === "" || content === "", Continue[]];
      (* ソースディレクトリに書き込み *)
      fullPath = FileNameJoin[{srcDir, path}];
      dir = DirectoryName[fullPath];
      If[!DirectoryQ[dir],
        Quiet @ CreateDirectory[dir, CreateIntermediateDirectories -> True]];
      (* ガード付き書き込み (append/replace 両対応) *)
      If[iSafeWriteDirective[fullPath, content, action] === $Failed,
        nbPrint[nb, "  \:2717 \:30ac\:30fc\:30c9\:306b\:3088\:308a\:66f8\:304d\:8fbc\:307f\:62d2\:5426: " <> path];
        Continue[]];
      nbPrint[nb, "  \:2713 \:4fee\:6b63: " <> path];
      (* .claude にもコピー *)
      Module[{dotPath = FileNameJoin[{dotClaude, path}], dotDir},
        dotDir = DirectoryName[dotPath];
        If[!DirectoryQ[dotDir],
          Quiet @ CreateDirectory[dotDir, CreateIntermediateDirectories -> True]];
        Quiet @ CopyFile[fullPath, dotPath, OverwriteTarget -> True]];
      updated++,
      {f, files}];
    If[updated > 0,
      iLoadClaudeMD[];
      nbPrint[nb, "  \:6574\:5408\:6027\:4fee\:6b63\:5b8c\:4e86: " <> ToString[updated] <> " \:30d5\:30a1\:30a4\:30eb\:3092\:66f4\:65b0\:3057\:307e\:3057\:305f\:3002"]]
  ];

(* テキスト指示によるディレクティブ更新 *)

(* JSON 文字列値の中の生改行/タブだけをエスケープする (構造的改行はそのまま) *)
iRepairJSONStringLiterals[json_String] :=
  Module[{chars, n, result, inStr = False, i, ch, prev = ""},
    chars = Characters[json];
    n = Length[chars];
    result = Internal`Bag[];
    Do[
      ch = chars[[i]];
      If[ch === "\"" && prev =!= "\\", inStr = !inStr];
      If[inStr,
        Switch[ch,
          "\n", Internal`StuffBag[result, "\\"]; Internal`StuffBag[result, "n"],
          "\r", Internal`StuffBag[result, "\\"]; Internal`StuffBag[result, "r"],
          "\t", Internal`StuffBag[result, "\\"]; Internal`StuffBag[result, "t"],
          _, Internal`StuffBag[result, ch]],
        Internal`StuffBag[result, ch]];
      prev = ch,
      {i, n}];
    StringJoin[Internal`BagPart[result, All]]
  ];

(* デリミタ形式のファイルブロックをパースする *)
(* <<<FILE: path>>> / <<<ACTION: action>>> / content / <<<END_FILE>>> *)
iParseDelimitedFileBlocks[response_String] :=
  Module[{blocks, result = {}, i, block, lines, pathVal, actionVal,
          contentLines, j, headersDone},
    blocks = StringSplit[response, "<<<END_FILE>>>"];
    Do[
      block = blocks[[i]];
      If[StringContainsQ[block, "<<<FILE:"],
        lines = StringSplit[block, "\n"];
        pathVal = None; actionVal = "replace";
        headersDone = 0;
        Do[
          Which[
            StringMatchQ[lines[[j]], "<<<FILE:" ~~ __ ~~ ">>>"],
            pathVal = StringTrim @ First[
              StringCases[lines[[j]], "<<<FILE:" ~~ p__ ~~ ">>>" :> p], ""];
            headersDone = j,
            StringMatchQ[lines[[j]], "<<<ACTION:" ~~ __ ~~ ">>>"],
            actionVal = StringTrim @ First[
              StringCases[lines[[j]], "<<<ACTION:" ~~ a__ ~~ ">>>" :> a], "replace"];
            headersDone = j
          ],
          {j, Length[lines]}];
        If[StringQ[pathVal] && pathVal =!= "",
          contentLines = If[headersDone < Length[lines],
            lines[[headersDone + 1 ;;]],
            {}];
          (* 先頭末尾の空行を除去 *)
          While[Length[contentLines] > 0 && StringTrim[First[contentLines]] === "",
            contentLines = Rest[contentLines]];
          While[Length[contentLines] > 0 && StringTrim[Last[contentLines]] === "",
            contentLines = Most[contentLines]];
          AppendTo[result,
            <|"path" -> pathVal,
              "action" -> actionVal,
              "content" -> StringRiffle[contentLines, "\n"]|>]]],
      {i, Length[blocks]}];
    result
  ];

$directiveUpdatePrompt = "\
You are updating Claude Code directive files for a Wolfram Language power user.\n\
The directives are organized as:\n\
- README.md: Project overview, installation instructions, usage guide\n\
- CLAUDE.md: Entry point with skill list and basic policies\n\
- rules/XX-name.md: Absolute constraints (must never be violated)\n\
- skills/name/SKILL.md: Concrete procedures and patterns\n\n\
Given the user's instruction and the current file contents below, output the updated files using the following EXACT delimiter format. Do NOT use JSON. Do NOT add any explanation before or after the file blocks.\n\n\
For each file that needs updating, output:\n\
<<<FILE: relative/path>>>\n\
<<<ACTION: replace|create|append>>>\n\
(full file content here, with actual newlines as-is)\n\
<<<END_FILE>>>\n\n\
Rules for deciding where to write:\n\
- Installation/usage/overview changes -> README.md\n\
- Absolute prohibitions/constraints -> rules/\n\
- Concrete procedures/patterns/examples -> skills/\n\
- Skill list updates -> CLAUDE.md\n\
- If a rule or skill already exists for the topic, update it rather than creating a new one.\n\
- For new rules, use the next available number prefix (e.g. 80-name.md)\n\
- For new skills, create skillname/SKILL.md with proper frontmatter\n\
- Output ONLY the file blocks in the delimiter format above. No other text.\n\n";

ClaudeUpdateDirective[text_String] :=
  Module[{nb, srcDir, prompt, allFiles, fileContents, response,
          files, path, action, content, fullPath, dir,
          nbCtx, enrichedText},
    nb = Quiet[InputNotebook[]];
    srcDir = iDirectivesSourceDir[];
    If[srcDir === $Failed,
      nbPrint[nb, "\:26a0 Claude Directives \:30bd\:30fc\:30b9\:30d5\:30a9\:30eb\:30c0\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093\:3002"];
      Return[$Failed]];

    (* セクションヘッダーを入力セルの直前に挿入 *)
    iWriteSectionHeaderBeforeEvalCell[nb,
      "\:25b6 ClaudeUpdateDirective (" <>
      DateString[Now, {"Year", "/", "Month", "/", "Day", " ", "Hour24", ":", "Minute"}] <> ")"];

    (* ノートブックコンテキストを取得して指示に付加 *)
    nbCtx = Quiet @ Check[iCaptureNotebookContext[nb, 0], ""];
    enrichedText = If[StringQ[nbCtx] && StringLength[nbCtx] > 0,
      text <> "\n\n=== ノートブックコンテキスト（上での議論）===\n" <>
      StringTake[nbCtx, UpTo[8000]] <> "\n",
      text];

    (* 現在の全ファイル内容を収集 *)
    allFiles = Join[
      If[FileExistsQ[FileNameJoin[{srcDir, "README.md"}]],
        {FileNameJoin[{srcDir, "README.md"}]}, {}],
      If[FileExistsQ[FileNameJoin[{srcDir, "CLAUDE.md"}]],
        {FileNameJoin[{srcDir, "CLAUDE.md"}]}, {}],
      FileNames["*.md", FileNameJoin[{srcDir, "rules"}]],
      FileNames["SKILL.md", FileNameJoin[{srcDir, "skills"}], Infinity]
    ];
    fileContents = StringJoin @ Map[
      Function[f,
        Module[{rel = iRelativePath[f, srcDir]},
          "=== " <> rel <> " ===\n" <> Import[f, "Text"] <> "\n\n"]],
      allFiles];

    prompt = $directiveUpdatePrompt <>
      "=== USER INSTRUCTION ===\n" <> enrichedText <> "\n\n" <>
      "=== CURRENT FILES ===\n" <> fileContents;

    nbPrint[nb, "[ClaudeUpdateDirective] Claude \:3067\:6307\:793a\:3092\:89e3\:6790\:4e2d\:2026"];

    (* API 経由で解析 *)
    response = Module[{apiKey, provider = "anthropic",
        model = "claude-sonnet-4-20250514"},
      apiKey = Quiet[NBAccess`NBGetAPIKey[provider,
        PrivacySpec -> <|"AccessLevel" -> 1.0|>]];
      If[!StringQ[apiKey], Return[$Failed]];
      iQueryAnthropicAPI[apiKey, model, prompt]
    ];

    If[!StringQ[response],
      nbPrint[nb, "\:26a0 Claude API \:5fdc\:7b54\:306e\:53d6\:5f97\:306b\:5931\:6557\:3057\:307e\:3057\:305f\:3002"];
      Return[$Failed]];

    (* デリミタ形式をパース *)
    files = iParseDelimitedFileBlocks[response];
    If[!ListQ[files] || Length[files] === 0,
      nbPrint[nb, "\:26a0 \:5fdc\:7b54\:306e\:30d1\:30fc\:30b9\:306b\:5931\:6557\:3057\:307e\:3057\:305f\:3002"];
      nbPrint[nb, "  (\:5fdc\:7b54\:9577: " <> ToString[StringLength[response]] <>
        " \:6587\:5b57\:3001\:5148\:982d: " <>
        StringTake[response, UpTo[120]] <> ")"];
      Return[$Failed]];

    (* \:4e8b\:524d\:30d0\:30c3\:30af\:30a2\:30c3\:30d7: \:5909\:66f4\:5bfe\:8c61\:30d5\:30a1\:30a4\:30eb\:3092\:5c65\:6b74\:306b\:4fdd\:5b58 *)
    Module[{targetPaths, histDir},
      targetPaths = Map[
        FileNameJoin[Flatten[{srcDir, FileNameSplit[Lookup[#, "path", ""]]}]] &, files];
      targetPaths = Select[targetPaths, FileExistsQ];
      histDir = iCreateDirectiveHistoryBackup[text, targetPaths];
      If[StringQ[histDir],
        nbPrint[nb, "\:30d0\:30c3\:30af\:30a2\:30c3\:30d7: " <> histDir]]];

    (* ファイルを書き込み *)
    Do[
      path    = Lookup[fe, "path", ""];
      action  = Lookup[fe, "action", "replace"];
      content = Lookup[fe, "content", ""];
      If[path === "" || content === "", Continue[]];
      fullPath = FileNameJoin[Flatten[{srcDir, FileNameSplit[path]}]];
      dir = DirectoryName[fullPath];
      If[!DirectoryQ[dir],
        CreateDirectory[dir, CreateIntermediateDirectories -> True]];
      (* ガード付き書き込み *)
      If[iSafeWriteDirective[fullPath, content, action] === $Failed,
        nbPrint[nb, "  \:2717 \:30ac\:30fc\:30c9\:306b\:3088\:308a\:66f8\:304d\:8fbc\:307f\:62d2\:5426: " <> path];
        Continue[]];
      nbPrint[nb, "  " <> action <> ": " <> path],
      {fe, files}];

    nbPrint[nb, "\:30bd\:30fc\:30b9\:30d5\:30a1\:30a4\:30eb\:3092\:66f4\:65b0\:3057\:307e\:3057\:305f\:3002"];
    iLoadClaudeMD[]
  ];

(* ============================================================
   \:30bb\:30c3\:30b7\:30e7\:30f3\:4f5c\:6210\:30fb\:30ea\:30b9\:30c8\:30a2
   ============================================================ *)

(* CreateClaudeSession["\:540d\:524d"]: \:540d\:524d\:4ed8\:304d\:30bb\:30c3\:30b7\:30e7\:30f3\:ff08\:30c7\:30d5\:30a9\:30eb\:30c8\:5c65\:6b74\:3092\:7d99\:627f\:ff09 *)
CreateClaudeSession[name_String] := Module[{nb, tag},
  nb = EvaluationNotebook[];
  tag = iNamedSessionTag[name];
  NBAccess`NBHistoryCreate[nb, tag, {"fullPrompt", "response", "code"},
    <|"name" -> name, "parent" -> iSessionTag[], "inherit" -> True|>];
  Print["\:30bb\:30c3\:30b7\:30e7\:30f3\:4f5c\:6210: " <> name <> " (\:30c7\:30d5\:30a9\:30eb\:30c8\:5c65\:6b74\:3092\:7d99\:627f)"];
  <|"SessionTag" -> tag, "Notebook" -> nb,
    "Name" -> name, "InheritFrom" -> {iSessionTag[]}|>
];

(* CreateClaudeSession[parentSession]: \:65e2\:5b58\:30bb\:30c3\:30b7\:30e7\:30f3\:3092\:7d99\:627f *)
CreateClaudeSession[parent_Association] := Module[{nb, name, tag, parentTag},
  nb = EvaluationNotebook[];
  parentTag = parent["SessionTag"];
  name = "fork_" <> DateString[{"Year","Month","Day","_","Hour24","Minute","Second"}];
  tag = iNamedSessionTag[name];
  NBAccess`NBHistoryCreate[nb, tag, {"fullPrompt", "response", "code"},
    <|"name" -> name, "parent" -> parentTag, "inherit" -> True|>];
  Print["\:30bb\:30c3\:30b7\:30e7\:30f3\:4f5c\:6210: " <> name <> " (\:7d99\:627f\:5143: " <>
    Lookup[parent, "Name", parentTag] <> ")"];
  <|"SessionTag" -> tag, "Notebook" -> nb,
    "Name" -> name, "InheritFrom" -> {parentTag}|>
];

(* CreateClaudeSession[]: \:30c7\:30d5\:30a9\:30eb\:30c8\:5c65\:6b74\:3092\:7d99\:627f\:3057\:305f\:65b0\:30bb\:30c3\:30b7\:30e7\:30f3 *)
(* CreateClaudeSession[Inherit->False]: \:72ec\:7acb\:30bb\:30c3\:30b7\:30e7\:30f3 *)
Options[CreateClaudeSession] = {Inherit -> True};

CreateClaudeSession[opts:OptionsPattern[]] := Module[{nb, name, tag, inherit, parentTag},
  nb = EvaluationNotebook[];
  inherit = OptionValue[Inherit];
  parentTag = If[inherit === True, iSessionTag[], None];
  name = "s" <> DateString[{"Year","Month","Day","_","Hour24","Minute","Second"}];
  tag = iNamedSessionTag[name];
  NBAccess`NBHistoryCreate[nb, tag, {"fullPrompt", "response", "code"},
    <|"name" -> name, "parent" -> parentTag, "inherit" -> inherit|>];
  Print["\:30bb\:30c3\:30b7\:30e7\:30f3\:4f5c\:6210: " <> name <>
    If[inherit === True, " (\:30c7\:30d5\:30a9\:30eb\:30c8\:5c65\:6b74\:3092\:7d99\:627f)", " (\:72ec\:7acb)"]];
  <|"SessionTag" -> tag, "Notebook" -> nb,
    "Name" -> name,
    "InheritFrom" -> If[inherit === True, {iSessionTag[]}, {}]|>
];

(* ClaudeRestoreSession[]: \:30c7\:30d5\:30a9\:30eb\:30c8\:30bb\:30c3\:30b7\:30e7\:30f3\:3092\:30ea\:30b9\:30c8\:30a2 *)
ClaudeRestoreSession[] := Module[{nb, tag, hist},
  nb = EvaluationNotebook[];
  tag = iSessionTag[];
  hist = iSessionHistory[nb, tag];
  Print["\:30c7\:30d5\:30a9\:30eb\:30c8\:30bb\:30c3\:30b7\:30e7\:30f3\:3092\:30ea\:30b9\:30c8\:30a2 (" <>
    ToString[Length[hist]] <> " \:30a8\:30f3\:30c8\:30ea)"];
  <|"SessionTag" -> tag, "Notebook" -> nb,
    "Name" -> "default", "InheritFrom" -> {}|>
];

(* ClaudeRestoreSession["\:540d\:524d"]: \:6307\:5b9a\:540d\:306e\:30bb\:30c3\:30b7\:30e7\:30f3\:3092\:30ea\:30b9\:30c8\:30a2 *)
ClaudeRestoreSession[name_String] := Module[{nb, tag, hdr, hist, parentTag},
  nb = EvaluationNotebook[];
  tag = iNamedSessionTag[name];
  hist = iSessionHistory[nb, tag];
  hdr = iReadSessionHeader[nb, tag];
  If[Length[hist] === 0 && Lookup[hdr, "name", "$default"] === "$default",
    Print["\:30bb\:30c3\:30b7\:30e7\:30f3\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093: " <> name];
    Return[$Failed]
  ];
  parentTag = Lookup[hdr, "parent", None];
  Print["\:30bb\:30c3\:30b7\:30e7\:30f3\:3092\:30ea\:30b9\:30c8\:30a2: " <> name <>
    " (" <> ToString[Length[hist]] <> " \:30a8\:30f3\:30c8\:30ea" <>
    If[StringQ[parentTag], ", \:7d99\:627f\:5143: " <> parentTag, ""] <> ")"];
  <|"SessionTag" -> tag, "Notebook" -> nb,
    "Name" -> name,
    "InheritFrom" -> If[StringQ[parentTag], {parentTag}, {}]|>
];

(* ============================================================
   \:30bb\:30c3\:30b7\:30e7\:30f3\:4e00\:89a7\:30fb\:524a\:9664\:30fb\:5c65\:6b74\:8868\:793a
   ============================================================ *)

(* TaggingRules から "history" で始まるキーを全取得 → NBAccess 履歴DB経由 *)
iAllSessionTags[nb_NotebookObject] :=
  NBAccess`NBHistoryListTags[nb, "history"];

(* \:30bf\:30b0\:304b\:3089\:30bb\:30c3\:30b7\:30e7\:30f3\:540d\:3092\:53d6\:5f97 *)
iTagToName[tag_String] :=
  If[tag === "history", "(default)",
    StringReplace[tag, "history_" -> ""]];

(* ClaudeListSessions[]: \:5168\:30bb\:30c3\:30b7\:30e7\:30f3\:4e00\:89a7 *)
ClaudeListSessions[] := Module[{nb, tags, rows, hdr, hist, name, created},
  nb = EvaluationNotebook[];
  tags = iAllSessionTags[nb];
  If[Length[tags] === 0,
    Print["\:30bb\:30c3\:30b7\:30e7\:30f3\:304c\:3042\:308a\:307e\:305b\:3093\:3002"];
    Return[{}]
  ];
  rows = Table[
    name = iTagToName[t];
    hdr = iReadSessionHeader[nb, t];
    hist = iSessionHistory[nb, t];
    created = Lookup[hdr, "created", 0];
    <|
      "Name"    -> name,
      "Tag"     -> t,
      "Entries" -> Length[hist],
      "Parent"  -> Replace[Lookup[hdr, "parent", None],
                     {None -> "-", s_String :> iTagToName[s]}],
      "Inherit" -> Lookup[hdr, "inherit", True],
      "Created" -> If[NumericQ[created] && created > 0,
                     DateString[created, {"Year","/","Month","/","Day"," ",
                       "Hour24",":","Minute",":","Second"}], "-"]
    |>,
    {t, tags}
  ];
  Dataset[rows]
];

(* ClaudeDeleteSession["name"]: \:540d\:524d\:4ed8\:304d\:30bb\:30c3\:30b7\:30e7\:30f3\:3092\:524a\:9664 *)
ClaudeDeleteSession[name_String] := Module[{nb, tag},
  If[name === "default" || name === "(default)",
    Print["\:30c7\:30d5\:30a9\:30eb\:30c8\:30bb\:30c3\:30b7\:30e7\:30f3\:306f\:524a\:9664\:3067\:304d\:307e\:305b\:3093\:3002"];
    Return[$Failed]
  ];
  nb = EvaluationNotebook[];
  tag = iNamedSessionTag[name];
  If[!MemberQ[iAllSessionTags[nb], tag],
    Print["\:30bb\:30c3\:30b7\:30e7\:30f3\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093: " <> name];
    Return[$Failed]
  ];
  NBAccess`NBHistoryDelete[nb, tag];
  Print["\:30bb\:30c3\:30b7\:30e7\:30f3\:3092\:524a\:9664\:3057\:307e\:3057\:305f: " <> name];
];

(* ClaudeShowHistory[]: \:30c7\:30d5\:30a9\:30eb\:30c8\:30bb\:30c3\:30b7\:30e7\:30f3\:306e\:5c65\:6b74\:8868\:793a *)
ClaudeShowHistory[] := Module[{nb},
  nb = EvaluationNotebook[];
  iShowHistoryImpl[nb, iSessionTag[]]
];

(* ClaudeShowHistory[session_Association]: \:30bb\:30c3\:30b7\:30e7\:30f3\:30aa\:30d6\:30b8\:30a7\:30af\:30c8\:306e\:5c65\:6b74\:8868\:793a *)
ClaudeShowHistory[session_Association] :=
  iShowHistoryImpl[session["Notebook"], session["SessionTag"]];

(* ClaudeShowHistory["name"]: \:540d\:524d\:6307\:5b9a\:306e\:5c65\:6b74\:8868\:793a *)
ClaudeShowHistory[name_String] := Module[{nb, tag},
  nb = EvaluationNotebook[];
  tag = If[name === "default", iSessionTag[], iNamedSessionTag[name]];
  iShowHistoryImpl[nb, tag]
];

(* ============================================================
   セッションアタッチメント API
   セッションに参考資料ファイルをアタッチし、
   ClaudeQuery/ClaudeEval 時に自動的に Read 指示を注入する。
   ============================================================ *)

ClaudeAttach::notfound = "\:30d5\:30a1\:30a4\:30eb\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093: `1`";

(* デフォルトセッションにアタッチ *)
ClaudeAttach[path_String] := Module[{nb, tag, norm, atts},
  nb = EvaluationNotebook[];
  tag = iSessionTag[];
  norm = ExpandFileName[path];
  If[!FileExistsQ[norm],
    Message[ClaudeAttach::notfound, norm]; Return[$Failed]];
  atts = NBAccess`NBHistoryAddAttachment[nb, tag, norm];
  Print["\:30a2\:30bf\:30c3\:30c1: " <> FileNameTake[norm] <>
    "  (\:5408\:8a08 " <> ToString[Length[atts]] <> " \:30d5\:30a1\:30a4\:30eb)"];
  atts
];

(* セッション指定でアタッチ *)
ClaudeAttach[session_Association, path_String] := Module[{nb, tag, norm, atts},
  nb = session["Notebook"];
  tag = session["SessionTag"];
  norm = ExpandFileName[path];
  If[!FileExistsQ[norm],
    Message[ClaudeAttach::notfound, norm]; Return[$Failed]];
  atts = NBAccess`NBHistoryAddAttachment[nb, tag, norm];
  Print["\:30a2\:30bf\:30c3\:30c1: " <> FileNameTake[norm] <>
    "  (\:5408\:8a08 " <> ToString[Length[atts]] <> " \:30d5\:30a1\:30a4\:30eb)"];
  atts
];

(* デフォルトセッションからデタッチ *)
ClaudeDetach[path_String] := Module[{nb, tag, atts},
  nb = EvaluationNotebook[];
  tag = iSessionTag[];
  atts = NBAccess`NBHistoryRemoveAttachment[nb, tag, ExpandFileName[path]];
  Print["\:30c7\:30bf\:30c3\:30c1: " <> FileNameTake[path] <>
    "  (\:6b8b\:308a " <> ToString[Length[atts]] <> " \:30d5\:30a1\:30a4\:30eb)"];
  atts
];

(* セッション指定でデタッチ *)
ClaudeDetach[session_Association, path_String] := Module[{nb, tag, atts},
  nb = session["Notebook"];
  tag = session["SessionTag"];
  atts = NBAccess`NBHistoryRemoveAttachment[nb, tag, ExpandFileName[path]];
  Print["\:30c7\:30bf\:30c3\:30c1: " <> FileNameTake[path] <>
    "  (\:6b8b\:308a " <> ToString[Length[atts]] <> " \:30d5\:30a1\:30a4\:30eb)"];
  atts
];

(* アタッチメント一覧 *)
ClaudeAttachments[] :=
  NBAccess`NBHistoryGetAttachments[EvaluationNotebook[], iSessionTag[]];

ClaudeAttachments[session_Association] :=
  NBAccess`NBHistoryGetAttachments[session["Notebook"], session["SessionTag"]];

(* 全クリア *)
ClearAttachments[] := (
  NBAccess`NBHistoryClearAttachments[EvaluationNotebook[], iSessionTag[]];
  Print["\:5168\:30a2\:30bf\:30c3\:30c1\:30e1\:30f3\:30c8\:3092\:30af\:30ea\:30a2\:3057\:307e\:3057\:305f\:3002"];
);

ClearAttachments[session_Association] := (
  NBAccess`NBHistoryClearAttachments[session["Notebook"], session["SessionTag"]];
  Print["\:5168\:30a2\:30bf\:30c3\:30c1\:30e1\:30f3\:30c8\:3092\:30af\:30ea\:30a2\:3057\:307e\:3057\:305f\:3002"];
);

(* 履歴エントリの再出力: テキスト + コードセルをノートブックに書き込む *)
iHistoryReplay[nb_NotebookObject, entry_Association] :=
  Module[{response, textOnly, blocks, step, task},
    step     = Lookup[entry, "step", "?"];
    task     = Lookup[entry, "task", Lookup[entry, "instruction", ""]];
    response = Lookup[entry, "response", ""];
    If[!StringQ[response] || response === "", Return[]];
    nbPrint[nb, "\:3010\:30b9\:30c6\:30c3\:30d7 " <> ToString[step] <> " \:518d\:51fa\:529b\:3011 " <>
      StringTake[task, UpTo[200]]];
    textOnly = iStripContinueEvalGuidance @ cleanMarkdown @ StringTrim @ iStripCodeBlocks[response];
    If[textOnly =!= "",
      NBAccess`NBWriteCell[nb, iTeXMathToCell[textOnly, "Text"]]];
    blocks = iWriteResponseBlocks[nb, response, True];
  ];

(* 履歴エントリの詳細表示: fullPrompt + response をすべて Print *)
iHistoryDetail[entry_Association] :=
  Module[{step, task, fullPrompt, response, code, timeStr},
    step       = Lookup[entry, "step", "?"];
    task       = Lookup[entry, "task", Lookup[entry, "instruction", ""]];
    fullPrompt = Lookup[entry, "fullPrompt", ""];
    response   = Lookup[entry, "response", ""];
    code       = Lookup[entry, "code", ""];
    timeStr    = With[{t = Lookup[entry, "time", 0]},
      If[NumericQ[t] && t > 0,
        DateString[t, {"Year","/","Month","/","Day"," ","Hour24",":","Minute",":","Second"}],
        "-"]];
    Print[Style["\:2500\:2500\:2500 \:30b9\:30c6\:30c3\:30d7 " <> ToString[step] <> " \:8a73\:7d30 \:2500\:2500\:2500", Bold, 14, RGBColor[0.2, 0.3, 0.6]]];
    Print[Style["\:6642\:523b: ", Bold], timeStr];
    Print[Style["\:6307\:793a: ", Bold], task];
    Print[""];
    If[StringQ[fullPrompt] && fullPrompt =!= "",
      Print[Style["\:9001\:4fe1\:30d7\:30ed\:30f3\:30d7\:30c8\:5168\:4f53:", Bold]];
      Print[fullPrompt];
      Print[""],
      (* fullPrompt が保存されていない古いエントリの場合 *)
      Print[Style["(\:9001\:4fe1\:30d7\:30ed\:30f3\:30d7\:30c8\:306f\:3053\:306e\:30a8\:30f3\:30c8\:30ea\:306b\:306f\:4fdd\:5b58\:3055\:308c\:3066\:3044\:307e\:305b\:3093)", Italic, GrayLevel[0.5]]];
      Print[""]
    ];
    Print[Style["\:30ec\:30b9\:30dd\:30f3\:30b9:", Bold]];
    Print[If[StringQ[response] && response =!= "", response, "(\:306a\:3057)"]];
    If[StringQ[code] && code =!= "",
      Print[""];
      Print[Style["\:62bd\:51fa\:30b3\:30fc\:30c9:", Bold]];
      Print[code]];
  ];

(* 履歴表示の内部実装 *)
(* 差分ボタン用の内部ヘルパー: 指定フィールドの生データを Print *)
iShowDiffField[nb_NotebookObject, tag_String, stepIdx_Integer,
    stepNum_, fieldName_String, color_] :=
  Module[{raw, entry, val},
    raw = NBAccess`NBHistoryEntriesWithInherit[nb, tag, Decompress -> False];
    If[stepIdx > Length[raw],
      Print["(データなし)"]; Return[]];
    entry = raw[[stepIdx]];
    val = Lookup[entry, fieldName, "(なし)"];
    Print[Style["\[LongDash]\[LongDash]\[LongDash] Step " <> ToString[stepNum] <>
      " " <> fieldName <> " \[LongDash]\[LongDash]\[LongDash]",
      Bold, 12, color]];
    If[StringQ[val],
      Print[Style["(平文)", Italic, GrayLevel[0.5]]],
      Print[val]]
  ];

iShowHistoryImpl[nb_NotebookObject, tag_String] :=
  Module[{ownHist, fullHist, rows, name},
    name = iTagToName[tag];
    ownHist = iSessionHistory[nb, tag];
    fullHist = iSessionHistoryWithInherit[nb, tag];
    Print["\:30bb\:30c3\:30b7\:30e7\:30f3: " <> name <>
      "  (\:81ea\:8eab: " <> ToString[Length[ownHist]] <> " \:30a8\:30f3\:30c8\:30ea" <>
      If[Length[fullHist] > Length[ownHist],
        ", \:7d99\:627f\:542b\:3080\:5408\:8a08: " <> ToString[Length[fullHist]] <> " \:30a8\:30f3\:30c8\:30ea",
        ""] <> ")"];
    If[Length[fullHist] === 0,
      Print["  \:5c65\:6b74\:306f\:3042\:308a\:307e\:305b\:3093\:3002"];
      Return[{}]
    ];
    rows = MapIndexed[
      Function[{e, idx},
        Module[{entryRef = e, nbRef = nb},
        <|
          "Step" -> Lookup[e, "step", "-"],
          "Task" -> StringTake[Lookup[e, "task",
                      Lookup[e, "instruction", "-"]], UpTo[60]],
          "Time" -> With[{t = Lookup[e, "time", 0]},
                     If[NumericQ[t] && t > 0,
                       DateString[t, {"Month","/","Day"," ","Hour24",":","Minute"}],
                       "-"]],
          "\:518d\:51fa\:529b" -> Button[
            Style["\[RightTriangle] \:518d\:51fa\:529b", 10],
            iHistoryReplay[nbRef, entryRef],
            Appearance -> "Frameless", Method -> "Queued",
            ImageSize -> {60, 20}],
          "\:8a73\:7d30" -> Button[
            Style["\:8a73\:7d30...", 10],
            iHistoryDetail[entryRef],
            Appearance -> "Frameless", Method -> "Queued",
            ImageSize -> {50, 20}],
          "\:5dee\:5206" -> With[{si = First[idx], nR = nb, tR = tag,
              sn = Lookup[e, "step", "?"]},
            Row[{
              Button[Style["P", 9, Bold, RGBColor[0.3, 0.5, 0.2]],
                iShowDiffField[nR, tR, si, sn, "fullPrompt",
                  RGBColor[0.3, 0.5, 0.2]],
                Appearance -> "Frameless", Method -> "Queued",
                ImageSize -> {22, 18}],
              Button[Style["R", 9, Bold, RGBColor[0.2, 0.3, 0.6]],
                iShowDiffField[nR, tR, si, sn, "response",
                  RGBColor[0.2, 0.3, 0.6]],
                Appearance -> "Frameless", Method -> "Queued",
                ImageSize -> {22, 18}],
              Button[Style["C", 9, Bold, RGBColor[0.5, 0.3, 0.2]],
                iShowDiffField[nR, tR, si, sn, "code",
                  RGBColor[0.5, 0.3, 0.2]],
                Appearance -> "Frameless", Method -> "Queued",
                ImageSize -> {22, 18}]
            }, Spacer[3]]]
        |>]
      ],
      fullHist
    ];
    (* Step 降順（最新が上）で表示 *)
    Dataset[Reverse[rows]]
  ];

(* ============================================================
   Claude Code \:30d1\:30ec\:30c3\:30c8
   ============================================================ *)

If[!ValueQ[$claudePalette], $claudePalette = None];

SetAttributes[iClaudePaletteButton, HoldRest];
iClaudePaletteButton[label_String, color_, action_] :=
  Button[
    Style[label, Bold, 10, White],
    (* アクション実行後、フォーカスをノートブックに明示的に戻す。
       これにより IME 入力位置がパレットに移動する問題を防止 *)
    CompoundExpression[action,
      With[{inb = InputNotebook[]},
        If[Head[inb] === NotebookObject,
          SetSelectedNotebook[inb]]]],
    Appearance -> "Frameless",
    Background -> color,
    ImageSize -> {100, 22},
    FrameMargins -> {{4, 4}, {2, 2}},
    Method -> "Queued"
  ];

(* \:9078\:629e\:4e2d\:306e\:30bb\:30eb\:3092\:53d6\:5f97\:ff08\:30d1\:30ec\:30c3\:30c8\:304b\:3089\:306e\:547c\:3073\:51fa\:3057\:306b\:5bfe\:5fdc\:ff09 *)
(* \:30bb\:30eb\:30d6\:30e9\:30b1\:30c3\:30c8\:9078\:629e \:2192 SelectedCells
   \:30ab\:30fc\:30bd\:30eb\:304c\:30bb\:30eb\:5185 \:2192 EvaluationCell / SelectedNotebook \:306e\:30bb\:30eb *)
iSelectedCellIndices[] :=
  Module[{nb},
    nb = Quiet[InputNotebook[]];
    If[Head[nb] =!= NotebookObject, Return[{nb, {}}]];
    {nb, NBAccess`NBSelectedCellIndices[nb]}
  ];

(* \:2500\:2500\:2500 \:6a5f\:5bc6\:64cd\:4f5c \:2500\:2500\:2500 *)

iMarkSelectedConfidential[] :=
  Module[{nbAndIdxs, nb, idxs},
    nbAndIdxs = iSelectedCellIndices[];
    nb = nbAndIdxs[[1]];
    idxs = nbAndIdxs[[2]];
    If[Head[nb] === NotebookObject && Length[idxs] > 0,
      Scan[MarkConfidential[nb, #] &, idxs]]
  ];

iUnmarkSelectedConfidential[] :=
  Module[{nbAndIdxs, nb, idxs},
    nbAndIdxs = iSelectedCellIndices[];
    nb = nbAndIdxs[[1]];
    idxs = nbAndIdxs[[2]];
    If[Head[nb] === NotebookObject && Length[idxs] > 0,
      Scan[UnmarkConfidential[nb, #] &, idxs]]
  ];

iScanAndReport[] :=
  Module[{n, nb},
    nb = Quiet[InputNotebook[]];
    If[Head[nb] =!= NotebookObject, Return[$Failed]];
    Quiet[iInstallCellEpilog[nb]];
    ScanConfidentialCells[nb]
  ];

(* \:2500\:2500\:2500 \:30bb\:30eb\:53ce\:96c6\:30d8\:30eb\:30d1\:30fc\:ff08\:30d1\:30ec\:30c3\:30c8\:30dc\:30bf\:30f3\:7528\:ff09 \:2500\:2500\:2500 *)

(* \:9078\:629e\:30bb\:30eb\:ff08\:307e\:305f\:306f\:5168\:30bb\:30eb\:ff09\:304b\:3089\:30c6\:30ad\:30b9\:30c8\:3068\:753b\:50cf\:3092\:53ce\:96c6\:3057 iNormalizePrompt \:4e92\:63db\:30ea\:30b9\:30c8\:3092\:8fd4\:3059
   skipPrivacyFilter: True \:306e\:5834\:5408\:3001\:30e6\:30fc\:30b6\:30fc\:304c\:660e\:793a\:7684\:306b\:9078\:629e\:3057\:305f\:30bb\:30eb\:306f\:6a5f\:5bc6\:30d5\:30a3\:30eb\:30bf\:3092\:30d0\:30a4\:30d1\:30b9\:3059\:308b *)
iCollectCellContent[nb_NotebookObject, cellIndices_List, skipPrivacyFilter_:False] :=
  Module[{items = {}, tmpDir, imgIdx = 0, cellData, text, style},
    tmpDir = FileNameJoin[{$TemporaryDirectory,
      "claude_cells_" <> ToString[UnixTime[]] <> "_" <> ToString[RandomInteger[99999]]}];
    Scan[Function[cellIdx,
      If[!TrueQ[skipPrivacyFilter] &&
         Quiet[NBAccess`NBShouldExcludeFromPrompt[nb, cellIdx]] === True,
        Return[]];
      (* \:30bb\:30eb\:30b9\:30bf\:30a4\:30eb\:3092\:53d6\:5f97\:3057\:3066\:30e9\:30d9\:30eb\:4ed8\:304d\:3067\:53ce\:96c6 *)
      style = Quiet[NBAccess`NBCellStyle[nb, cellIdx]];
      If[!StringQ[style], style = "Unknown"];
      (* NBCellToText を優先使用（cellToText より堅牢） *)
      text = Quiet[NBAccess`NBCellToText[nb, cellIdx]];
      (* フォールバック: NotebookRead + ToString *)
      cellData = Quiet[NBAccess`NBCellRead[nb, cellIdx]];
      If[!StringQ[text] || StringTrim[text] === "",
        If[cellData =!= $Failed && cellData =!= {},
          text = Quiet[cellToText[cellData]]];
        If[!StringQ[text] || StringTrim[text] === "",
          If[cellData =!= $Failed && cellData =!= {},
            text = Quiet[ToString[cellData, InputForm]]]]];
      If[StringQ[text] && StringLength[StringTrim[text]] > 0,
        AppendTo[items,
          "[" <> style <> "] " <> StringTrim[text]]];
      (* 画像を含むセルはラスタライズ — 構造判定は NBAccess に委譲 *)
      If[NBAccess`NBCellHasImage[cellData],
        If[!DirectoryQ[tmpDir],
          CreateDirectory[tmpDir, CreateIntermediateDirectories -> True]];
        imgIdx++;
        With[{f = FileNameJoin[{tmpDir, "cell_img_" <> ToString[imgIdx] <> ".png"}]},
          NBAccess`NBCellRasterize[nb, cellIdx, f, ImageResolution -> 144];
          If[FileExistsQ[f], AppendTo[items, File[f]]]
        ]
      ]
    ], cellIndices];
    items
  ];

(* \:30d1\:30ec\:30c3\:30c8\:304b\:3089\:547c\:3070\:308c\:308b: \:9078\:629e\:30bb\:30eb\:ff08\:306a\:3051\:308c\:3070\:5168\:30bb\:30eb\:ff09\:3067 ClaudeEval \:3092\:5b9f\:884c
   \:30e6\:30fc\:30b6\:30fc\:306b\:6307\:793a\:3092\:5165\:529b\:3055\:305b\:3001\:9078\:629e\:30bb\:30eb\:306e\:5185\:5bb9\:3092\:30b3\:30f3\:30c6\:30ad\:30b9\:30c8\:3068\:3057\:3066\:6dfb\:4ed8\:3059\:308b *)
iRunClaudeEvalFromCells[] :=
  Module[{nb, cellIndices, items, norm, task, nCells, userInstr, selText},
    nb = Quiet[InputNotebook[]];
    If[Head[nb] =!= NotebookObject, Return[$Failed]];
    cellIndices = NBAccess`NBSelectedCellIndices[nb];
    If[Length[cellIndices] === 0,
      nCells = NBAccess`NBCellCount[nb];
      If[nCells === 0,
        MessageDialog["\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:306b\:30bb\:30eb\:304c\:3042\:308a\:307e\:305b\:3093\:3002"]; Return[$Failed]];
      cellIndices = Range[nCells]
    ];
    (* \:9078\:629e\:30bb\:30eb\:304b\:3089\:30b3\:30f3\:30c6\:30f3\:30c4\:3092\:53ce\:96c6\:ff08\:660e\:793a\:9078\:629e\:306a\:306e\:3067\:6a5f\:5bc6\:30d5\:30a3\:30eb\:30bf\:3092\:30d0\:30a4\:30d1\:30b9\:ff09 *)
    items = iCollectCellContent[nb, cellIndices, True];
    If[Length[items] === 0,
      MessageDialog["\:9078\:629e\:30bb\:30eb\:304b\:3089\:30b3\:30f3\:30c6\:30f3\:30c4\:3092\:53d6\:5f97\:3067\:304d\:307e\:305b\:3093\:3067\:3057\:305f\:3002"]; Return[$Failed]];
    selText = StringRiffle[Select[items, StringQ], "\n"];
    (* \:30e6\:30fc\:30b6\:30fc\:306b\:6307\:793a\:3092\:5165\:529b\:3055\:305b\:308b *)
    userInstr = InputString[
      "\:9078\:629e\:30bb\:30eb (" <> ToString[Length[cellIndices]] <>
      " \:30bb\:30eb) \:306b\:5bfe\:3059\:308b\:6307\:793a\:3092\:5165\:529b\:3057\:3066\:304f\:3060\:3055\:3044\:ff1a"];
    If[!StringQ[userInstr] || StringTrim[userInstr] === "", Return[$Failed]];
    task = userInstr <> "\n\n=== \:9078\:629e\:30bb\:30eb\:306e\:5185\:5bb9 ===\n" <> selText;
    NBAccess`NBMoveAfterCell[nb, Last[cellIndices]];
    $currentUseFallback = True;
    norm = iNormalizePrompt[
      Join[{task}, Select[items, MatchQ[#, _File] &]]];
    iClaudeEvalImpl[nb, iSessionTag[], norm["text"], norm["imageDirs"]]
  ];

(* \:30d1\:30ec\:30c3\:30c8\:304b\:3089\:547c\:3070\:308c\:308b: \:9078\:629e\:30bb\:30eb\:3067 ClaudeQuery \:3092\:5b9f\:884c\:ff08\:30b3\:30fc\:30c9\:751f\:6210\:3067\:306f\:306a\:304f\:8aac\:660e\:30fb\:56de\:7b54\:3092\:5f97\:308b\:ff09 *)
iRunClaudeQueryFromCells[] :=
  Module[{nb, cellIndices, items, selText, userInstr, fullPrompt,
          nCells, session, tag},
    nb = Quiet[InputNotebook[]];
    If[Head[nb] =!= NotebookObject, Return[$Failed]];
    cellIndices = NBAccess`NBSelectedCellIndices[nb];
    If[Length[cellIndices] === 0,
      nCells = NBAccess`NBCellCount[nb];
      If[nCells === 0,
        MessageDialog["\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:306b\:30bb\:30eb\:304c\:3042\:308a\:307e\:305b\:3093\:3002"]; Return[$Failed]];
      cellIndices = Range[nCells]
    ];
    items = iCollectCellContent[nb, cellIndices, True];
    If[Length[items] === 0,
      MessageDialog["\:9078\:629e\:30bb\:30eb\:304b\:3089\:30b3\:30f3\:30c6\:30f3\:30c4\:3092\:53d6\:5f97\:3067\:304d\:307e\:305b\:3093\:3067\:3057\:305f\:3002"]; Return[$Failed]];
    selText = StringRiffle[Select[items, StringQ], "\n"];
    userInstr = InputString[
      "\:9078\:629e\:30bb\:30eb (" <> ToString[Length[cellIndices]] <>
      " \:30bb\:30eb) \:306b\:3064\:3044\:3066\:306e\:8cea\:554f\:3092\:5165\:529b\:3057\:3066\:304f\:3060\:3055\:3044\:ff1a"];
    If[!StringQ[userInstr] || StringTrim[userInstr] === "", Return[$Failed]];
    fullPrompt = userInstr <> "\n\n=== \:9078\:629e\:30bb\:30eb\:306e\:5185\:5bb9 ===\n" <> selText;
    NBAccess`NBMoveAfterCell[nb, Last[cellIndices]];
    $currentUseFallback = True;
    session = iEnsureDefaultSession[nb];
    tag     = session["SessionTag"];
    iClaudeQueryImpl[nb, tag, fullPrompt, True, False]
  ];

(* \:30d1\:30ec\:30c3\:30c8\:304b\:3089\:547c\:3070\:308c\:308b: \:9078\:629e\:30bb\:30eb\:ff08\:306a\:3051\:308c\:3070\:5168\:30bb\:30eb\:ff09\:3067 ClaudeSpec \:3092\:5b9f\:884c
   \:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:672b\:5c3e\:306b\:4ed5\:69d8\:30bb\:30eb\:3092\:8ffd\:52a0\:3059\:308b *)
iRunClaudeSpecFromCells[] :=
  Module[{nb, cellIndices, items, norm, task, nCells},
    nb = Quiet[InputNotebook[]];
    If[Head[nb] =!= NotebookObject, Return[$Failed]];
    cellIndices = NBAccess`NBSelectedCellIndices[nb];
    If[Length[cellIndices] === 0,
      nCells = NBAccess`NBCellCount[nb];
      If[nCells === 0,
        MessageDialog["\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:306b\:30bb\:30eb\:304c\:3042\:308a\:307e\:305b\:3093\:3002"]; Return[$Failed]];
      cellIndices = Range[nCells];
      task = "\:3053\:306e\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:5168\:4f53\:306e\:5185\:5bb9\:3092\:5206\:6790\:3057\:3001\:60f3\:5b9a\:3055\:308c\:308b\:30d7\:30ed\:30b0\:30e9\:30e0\:306e\:4ed5\:69d8\:3092\:751f\:6210\:3057\:3066\:304f\:3060\:3055\:3044\:3002"
    , (* else *)
      task = "\:4ee5\:4e0b\:306e\:9078\:629e\:30bb\:30eb\:306e\:5185\:5bb9\:3092\:5206\:6790\:3057\:3001\:30d7\:30ed\:30b0\:30e9\:30e0\:306e\:4ed5\:69d8\:3092\:751f\:6210\:3057\:3066\:304f\:3060\:3055\:3044\:3002"
    ];
    items = iCollectCellContent[nb, cellIndices, True];
    If[Length[items] === 0,
      MessageDialog["\:9078\:629e\:30bb\:30eb\:304b\:3089\:30b3\:30f3\:30c6\:30f3\:30c4\:3092\:53d6\:5f97\:3067\:304d\:307e\:305b\:3093\:3067\:3057\:305f\:3002"]; Return[$Failed]];
    (* \:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:672b\:5c3e\:306b\:30ab\:30fc\:30bd\:30eb\:3092\:79fb\:52d5 *)
    NBAccess`NBMoveToEnd[nb];
    $currentUseFallback = True;
    PrependTo[items, task];
    norm = iNormalizePrompt[items];
    iClaudeSpecImpl[nb, iSessionTag[], norm["text"], norm["imageDirs"]]
  ];

(* \:2500\:2500\:2500 ClaudeQuery / ClaudeEval \:30c6\:30f3\:30d7\:30ec\:30fc\:30c8\:633f\:5165 \:2500\:2500\:2500 *)

iInsertClaudeQueryTemplate[] :=
  With[{nb = InputNotebook[]},
    NBAccess`NBInsertInputTemplate[nb,
      RowBox[{"ClaudeQuery", "[",
        "\"\[SelectionPlaceholder]\"", "]"}]]
  ];

iInsertClaudeEvalTemplate[] :=
  With[{nb = InputNotebook[]},
    NBAccess`NBInsertInputTemplate[nb,
      RowBox[{"ClaudeEval", "[",
        "\"\[SelectionPlaceholder]\"", "]"}]]
  ];

iInsertContinueEvalTemplate[] :=
  With[{nb = InputNotebook[]},
    NBAccess`NBInsertInputAfter[nb,
      RowBox[{"ContinueEval", "[", "]"}]]
  ];


iStripContinueEvalGuidance[text_String] :=
  Module[{t = text},
    t = StringReplace[t, {
      RegularExpression["(?ms)^.*完了。コードを実行して確認し、必要なら.*ContinueEval.*$"] -> "",
      RegularExpression["(?m)^\\s*ContinueEval\\[\\]\\s*$"] -> "",
      RegularExpression["(?m)^\\s*【ステップ\\s*[0-9]+】[^\\n]*$"] -> ""
    }];
    StringTrim[t]
  ];

iWriteContinueEvalButton[nb_NotebookObject, autoEvaluate_:True] :=
  With[{auto = TrueQ[autoEvaluate]},
    NBAccess`NBWriteCell[nb,
      Cell[
        TextData[{
          "完了。コードを実行して確認し、必要なら ",
          ButtonBox[
            "ContinueEval",
            BaseStyle -> "Hyperlink",
            ButtonFunction :> Module[{target = InputNotebook[]},
              NBAccess`NBWriteInputCellAndMaybeEvaluate[
                target,
                RowBox[{"ContinueEval", "[", "]"}],
                auto
              ]
            ],
            Evaluator -> Automatic,
            Method -> "Queued"
          ],
          "[] で継続できます。"
        }],
        "Print", FontWeight -> Bold, FontColor -> GrayLevel[0.4], FontSize -> 11,
        CellTags -> {"claudecode-notice"}
      ]
    ]
  ];

(* ClaudeUpdatePackage 完了メッセージ:
   ContinueUpdate[] ハイパーリンク + api.md 更新リンク (自動更新オフ時) *)
iWriteUpdateCompletionMessage[nb_NotebookObject, packageName_String,
    apiMdAlreadyUpdated_:False] :=
  Module[{textParts},
    textParts = {
      "完了。コードを実行して確認し、必要なら ",
      ButtonBox["ContinueUpdate",
        BaseStyle -> "Hyperlink",
        ButtonFunction :> Module[{target = InputNotebook[]},
          NotebookWrite[target,
            Cell[BoxData[RowBox[{"ContinueUpdate", "[", "]"}]], "Input"]];
          SelectionMove[target, Previous, Cell];
          SelectionMove[target, All, CellContents]],
        Evaluator -> Automatic, Method -> "Queued"],
      "[] で継続できます。"
    };
    (* api.md 自動更新がオフの場合: 更新リンクを追加 *)
    If[!TrueQ[apiMdAlreadyUpdated],
      AppendTo[textParts, "  "];
      AppendTo[textParts,
        ButtonBox["api.md を更新",
          BaseStyle -> "Hyperlink",
          ButtonFunction :> Module[{target = InputNotebook[]},
            iAutoUpdateApiMd[target, packageName]],
          Evaluator -> Automatic, Method -> "Queued"]]];
    NBAccess`NBWriteCell[nb,
      Cell[TextData[textParts], "Print",
        FontWeight -> Bold, FontColor -> GrayLevel[0.4], FontSize -> 11,
        CellTags -> {"claudecode-notice"}]]
  ];

(* \:2500\:2500\:2500 \:6a5f\:5bc6\:5909\:6570\:4e00\:89a7 \:2500\:2500\:2500 *)

iShowConfidentialVars[] :=
  Module[{nb, nCells, directVars},
    nb = Quiet[InputNotebook[]];
    If[Head[nb] =!= NotebookObject,
      MessageDialog["\:30ce\:30fc\:30c8\:30d6\:30c3\:30af\:3092\:53d6\:5f97\:3067\:304d\:307e\:305b\:3093\:3002"]; Return[]];
    nCells = NBAccess`NBCellCount[nb];
    directVars = DeleteDuplicates @ Flatten @ Table[
      With[{tag    = NBAccess`NBGetConfidentialTag[nb, i],
            depTag = NBAccess`NBCellGetTaggingRule[nb, i, {"claudecode", "dependent"}]},
        If[TrueQ[tag] && !TrueQ[depTag],
          NBAccess`NBCellExtractVarNames[nb, i], {}]],
      {i, nCells}];
    If[Length[directVars] === 0,
      MessageDialog["\:6a5f\:5bc6\:5909\:6570\:306f\:3042\:308a\:307e\:305b\:3093\:3002"],
      MessageDialog[Column[{
        Style["\:6a5f\:5bc6\:8ffd\:8de1\:4e2d\:306e\:5909\:6570:", Bold],
        Spacer[4],
        Column[Style[#, FontFamily -> "Courier"] & /@ directVars]
      }]]]
  ];

(* \:2500\:2500\:2500 \:30e1\:30a4\:30f3\:30d1\:30ec\:30c3\:30c8 \:2500\:2500\:2500 *)

ShowClaudePalette[] := (
  If[$claudePalette =!= None, Quiet@NotebookClose[$claudePalette]];
  Quiet[iInstallCellEpilog[InputNotebook[]]];
  $claudePalette = CreatePalette[
    Column[{
      Style["Claude Code", Bold, 11, RGBColor[0.2, 0.3, 0.6]],

      (* \:2500\:2500 \:6a5f\:5bc6\:30bb\:30eb\:7ba1\:7406 \:2500\:2500 *)
      Style[" \:6a5f\:5bc6\:30bb\:30eb", Bold, 8, GrayLevel[0.3]],
      iClaudePaletteButton["\[WarningSign] \:6a5f\:5bc6\:30de\:30fc\:30af",
        RGBColor[0.75, 0.15, 0.15],
        iMarkSelectedConfidential[]],
      iClaudePaletteButton["\[CircleTimes] \:6a5f\:5bc6\:89e3\:9664",
        RGBColor[0.45, 0.55, 0.45],
        iUnmarkSelectedConfidential[]],
      iClaudePaletteButton["\[RightTriangle] \:30b9\:30ad\:30e3\:30f3",
        RGBColor[0.4, 0.4, 0.65],
        iScanAndReport[]],
      Spacer[2],

      (* \:2500\:2500 Claude \:64cd\:4f5c \:2500\:2500 *)
      Style[" Claude", Bold, 8, GrayLevel[0.3]],
      iClaudePaletteButton["\[RightPointer] ClaudeQuery",
        RGBColor[0.25, 0.45, 0.7],
        iInsertClaudeQueryTemplate[]],
      iClaudePaletteButton["\[FilledRightTriangle] ClaudeEval",
        RGBColor[0.2, 0.55, 0.35],
        iInsertClaudeEvalTemplate[]],
      iClaudePaletteButton["\[RightTriangleBar] \:9078\:629e\:2192Eval",
        RGBColor[0.15, 0.45, 0.30],
        iRunClaudeEvalFromCells[]],
      iClaudePaletteButton["\[RightTriangleBar] \:9078\:629e\:2192Query",
        RGBColor[0.2, 0.38, 0.65],
        iRunClaudeQueryFromCells[]],
      iClaudePaletteButton["\[FilledDiamond] \:4ed5\:69d8\:751f\:6210",
        RGBColor[0.35, 0.3, 0.7],
        iRunClaudeSpecFromCells[]],
      iClaudePaletteButton["\[ClockwiseContourIntegral] ContinueEval",
        RGBColor[0.5, 0.4, 0.2],
        iInsertContinueEvalTemplate[]],
      Spacer[2],

      (* \:2500\:2500 \:30bb\:30c3\:30b7\:30e7\:30f3 \:2500\:2500 *)
      Style[" \:30bb\:30c3\:30b7\:30e7\:30f3", Bold, 8, GrayLevel[0.3]],
      iClaudePaletteButton["\[FilledSmallSquare] \:5c65\:6b74\:8868\:793a",
        RGBColor[0.45, 0.45, 0.55],
        With[{nb = InputNotebook[]},
          NBAccess`NBInsertAndEvaluateInput[nb,
            RowBox[{"ClaudeShowHistory", "[", "]"}]]]],
      iClaudePaletteButton["\[EmptySquare] \:30bb\:30c3\:30b7\:30e7\:30f3\:4e00\:89a7",
        RGBColor[0.5, 0.45, 0.5],
        With[{nb = InputNotebook[]},
          NBAccess`NBInsertAndEvaluateInput[nb,
            RowBox[{"ClaudeListSessions", "[", "]"}]]]],
      Spacer[2],

      (* \:2500\:2500 \:30b9\:30c6\:30fc\:30bf\:30b9 \:2500\:2500 *)
      Dynamic[
        With[{nb = InputNotebook[]},
          Style[
            " \:6a5f\:5bc6: " <> ToString[
              If[Head[nb] === NotebookObject,
                Module[{cnt = 0, n = NBAccess`NBCellCount[nb]},
                  Do[If[TrueQ[NBAccess`NBGetConfidentialTag[nb, i]] &&
                        !TrueQ[NBAccess`NBCellGetTaggingRule[nb, i, {"claudecode", "dependent"}]],
                      cnt++], {i, n}]; cnt],
                0]] <> " \:500b",
            8, GrayLevel[0.4]]]],
      Dynamic[
        Style[
          " \:8ffd\:8de1: " <> If[NBAccess`NBConfidentialEpilogInstalledQ[
              InputNotebook[], ClaudeCode`Private`iConfidentialCellEpilog],
            "\[Checkmark]", "\[Times]"],
          8, GrayLevel[0.4]]],
      Button[
        Style["\:81ea\:52d5\:8ffd\:8de1\:30a4\:30f3\:30b9\:30c8\:30fc\:30eb", 8, GrayLevel[0.4]],
        (NBAccess`NBInstallConfidentialEpilog[InputNotebook[],
           ClaudeCode`Private`iConfidentialCellEpilog[],
           ClaudeCode`Private`iConfidentialCellEpilog];
         SetSelectedNotebook[InputNotebook[]]),
        Appearance -> "Frameless", Method -> "Queued"],
      Button[
        Style["\:6a5f\:5bc6\:5909\:6570\:4e00\:89a7...", 8, GrayLevel[0.4]],
        (iShowConfidentialVars[];
         SetSelectedNotebook[InputNotebook[]]),
        Appearance -> "Frameless", Method -> "Queued"]

    }, Alignment -> Center, Spacings -> 0],
    WindowTitle -> "Claude Code",
    WindowSize -> {105, All},
    WindowFloating -> True,
    WindowClickSelect -> False,
    WindowMargins -> {{Automatic, 4}, {Automatic, 4}},
    Saveable -> False
  ]
);

(* \:2500\:2500\:2500 \:30d1\:30ec\:30c3\:30c8\:30e1\:30cb\:30e5\:30fc\:306b\:767b\:9332 \:2500\:2500\:2500 *)

AddToPalettesMenu[paletteData : {{_String, _String} ..}] :=
  Module[{itemList, dummyFunction, tempFunction, temp},
    SetAttributes[FrontEnd`AddMenuCommands, HoldRest];
    MathLink`CallFrontEnd[FrontEnd`ResetMenusPacket[{Automatic}]];
    itemList =
      Item[First[#],
        FrontEnd`KernelExecute[{EvaluatePacket[dummyFunction@Last[#]]}],
        FrontEnd`MenuEvaluator -> Automatic] & /@ paletteData;
    temp =
      Function[x,
        tempFunction[{FrontEnd`AddMenuCommands["MenuListPalettesMenu",
          x]}]][itemList] /. dummyFunction -> ToExpression;
    temp /. tempFunction -> FrontEndExecute];

(* ============================================================
   Claude Code CLI スラッシュコマンド実行
   全コマンドを CLI サブコマンド・内部データ・組み込みテキストで処理。
   ============================================================ *)

(* CLI サブコマンドとして実行 (引数リスト版) *)
iRunClaudeSubcommand[args_List] :=
  Module[{batFile, outFile, ts, strm, bc, workDir, res, raw},
    ts = ToString[UnixTime[]] <> "x" <> ToString[RandomInteger[99999]];
    outFile = FileNameJoin[{$TemporaryDirectory, "claude_cmd_" <> ts <> ".txt"}];
    batFile = FileNameJoin[{$TemporaryDirectory, "claude_cmd_" <> ts <> ".bat"}];
    workDir = iPrepareClaudeProjectDirectory[];
    bc = "@echo off\r\n" <>
         "chcp 65001 > nul\r\n" <>
         iClaudeEnvResetBatchLines[] <>
         "cd /d \"" <> workDir <> "\"\r\n" <>
         iClaudeCallPrefix[] <>
         "\"" <> $ClaudeExe <> "\" " <>
         StringRiffle[("\"" <> # <> "\"") & /@ args, " "] <>
         " > \"" <> outFile <> "\" 2>&1\r\n";
    strm = OpenWrite[batFile, BinaryFormat -> True];
    BinaryWrite[strm, ExportString[bc, "Text", CharacterEncoding -> "ASCII"]];
    Close[strm];
    res = TimeConstrained[
      RunProcess[{"cmd", "/c", batFile}, All], 60, "TIMEOUT"];
    Quiet[DeleteFile[batFile]];
    If[res === "TIMEOUT", Return["Error: \:30bf\:30a4\:30e0\:30a2\:30a6\:30c8 (60\:79d2)"]];
    If[!FileExistsQ[outFile],
      Return["Error: \:51fa\:529b\:30d5\:30a1\:30a4\:30eb\:304c\:751f\:6210\:3055\:308c\:307e\:305b\:3093\:3067\:3057\:305f"]];
    raw = Import[outFile, "Text"];
    Quiet[DeleteFile[outFile]];
    cleanOutput[stripANSI[raw]]
  ];

(* /permissions: settings.json + CLI フラグから権限情報を構築 *)
iGetPermissionsInfo[] :=
  Module[{workDir, settingsFile, json, perms, allow, deny, result},
    workDir = iClaudeWorkingDirectory[];
    settingsFile = FileNameJoin[{workDir, ".claude", "settings.json"}];
    json = If[FileExistsQ[settingsFile],
      Quiet @ Check[ImportString[Import[settingsFile, "Text"], "RawJSON"], <||>],
      <||>];
    If[!AssociationQ[json], json = <||>];
    perms = Lookup[json, "permissions", <||>];
    If[!AssociationQ[perms], perms = <||>];
    allow = Lookup[perms, "allow", {}];
    deny  = Lookup[perms, "deny", {}];
    result = "=== Claude Code Permissions ===\n\n";
    result = result <> "CLI \:30d5\:30e9\:30b0: " <> iCLIPermissionFlags[] <> "\n\n";
    result = result <> "settings.json: " <> settingsFile <> "\n\n";
    If[Length[allow] > 0,
      result = result <> "Allowed:\n" <>
        StringJoin[("  \:2705 " <> ToString[#] <> "\n") & /@ allow],
      result = result <> "Allowed: (\:306a\:3057)\n"];
    result = result <> "\n";
    If[Length[deny] > 0,
      result = result <> "Denied:\n" <>
        StringJoin[("  \:274c " <> ToString[#] <> "\n") & /@ deny],
      result = result <> "Denied: (\:306a\:3057)\n"];
    result = result <> "\n\:30a2\:30af\:30bb\:30b9\:53ef\:80fd\:30c7\:30a3\:30ec\:30af\:30c8\:30ea:\n" <>
      StringJoin[("  " <> # <> "\n") & /@
        DeleteDuplicates[iCollectAccessibleDirs[]]];
    result
  ];

(* /model: 現在のモデル情報 *)
iGetModelInfo[] :=
  "=== Claude Code Model ===\n\n" <>
  "$ClaudeModel: " <> If[$ClaudeModel === "", "(Claude Code \:30c7\:30d5\:30a9\:30eb\:30c8)", $ClaudeModel] <> "\n" <>
  "$ClaudeTestModel: " <> If[StringQ[$ClaudeTestModel] && $ClaudeTestModel =!= "",
    $ClaudeTestModel, "(= $ClaudeModel)"] <> "\n" <>
  "$ClaudeFallbackModels:\n" <>
  StringJoin[("  " <> #[[1]] <> " / " <> #[[2]] <>
    " (max:" <> ToString[NBAccess`NBGetProviderMaxAccessLevel[#[[1]]]] <> ")\n") & /@
    NBAccess`NBGetFallbackModels[]];

(* /help *)
$iSlashHelpText =
  "Claude Code \:30b9\:30e9\:30c3\:30b7\:30e5\:30b3\:30de\:30f3\:30c9\:4e00\:89a7 (ClaudeCommand \:3067\:5229\:7528\:53ef\:80fd):\n\n" <>
  "  /help              \:2192 \:3053\:306e\:30d8\:30eb\:30d7\:3092\:8868\:793a\n" <>
  "  /version           \:2192 Claude Code \:306e\:30d0\:30fc\:30b8\:30e7\:30f3 (CLI)\n" <>
  "  /config            \:2192 \:8a2d\:5b9a\:4e00\:89a7 (CLI)\n" <>
  "  /doctor            \:2192 \:74b0\:5883\:8a3a\:65ad (CLI)\n" <>
  "  /login             \:2192 \:30ed\:30b0\:30a4\:30f3 (CLI)\n" <>
  "  /logout            \:2192 \:30ed\:30b0\:30a2\:30a6\:30c8 (CLI)\n" <>
  "  /status            \:2192 \:8a8d\:8a3c\:72b6\:614b (CLI)\n" <>
  "  /permissions       \:2192 \:30d5\:30a1\:30a4\:30eb\:30a2\:30af\:30bb\:30b9\:6a29\:9650 (settings.json \:304b\:3089\:53d6\:5f97)\n" <>
  "  /model             \:2192 \:30e2\:30c7\:30eb\:60c5\:5831 (\:5185\:90e8\:5909\:6570\:304b\:3089\:53d6\:5f97)\n" <>
  "  /clear             \:2192 \:5bfe\:8a71\:30e2\:30fc\:30c9\:5c02\:7528\n" <>
  "  /compact           \:2192 \:5bfe\:8a71\:30e2\:30fc\:30c9\:5c02\:7528\n" <>
  "  /cost              \:2192 \:5bfe\:8a71\:30e2\:30fc\:30c9\:5c02\:7528\n" <>
  "\nCLI \:30b5\:30d6\:30b3\:30de\:30f3\:30c9 (\:30b9\:30e9\:30c3\:30b7\:30e5\:306a\:3057\:3067\:3082\:5b9f\:884c\:53ef):\n" <>
  "  config list         \:2192 \:8a2d\:5b9a\:4e00\:89a7\n" <>
  "  config set KEY VAL  \:2192 \:8a2d\:5b9a\:5909\:66f4\n" <>
  "  auth status         \:2192 \:8a8d\:8a3c\:72b6\:614b\n" <>
  "  doctor              \:2192 \:74b0\:5883\:8a3a\:65ad\n" <>
  "  --version           \:2192 \:30d0\:30fc\:30b8\:30e7\:30f3\:8868\:793a\n" <>
  "  --help              \:2192 CLI \:30d8\:30eb\:30d7";

(* スラッシュコマンド → CLI 等価マッピング *)
$iSlashCommandMap = <|
  "/config"      -> {"config", "list"},
  "/config list" -> {"config", "list"},
  "/version"     -> {"--version"},
  "/doctor"      -> {"doctor"},
  "/login"       -> {"auth", "login"},
  "/logout"      -> {"auth", "logout"},
  "/status"      -> {"auth", "status"}
|>;

(* 対話モード専用で未対応のコマンド *)
$iSessionOnlyCommands = {"/clear", "/compact", "/cost", "/rename"};

ClaudeCommand[command_String] :=
  Module[{trimmed, mapped},
    trimmed = StringTrim[command];
    (* /help *)
    If[trimmed === "/help" || trimmed === "/h",
      Return[$iSlashHelpText]];
    (* /permissions: settings.json から内部取得 *)
    If[trimmed === "/permissions",
      Return[iGetPermissionsInfo[]]];
    (* /model: 内部変数から返す *)
    If[trimmed === "/model",
      Return[iGetModelInfo[]]];
    (* 対話モード専用コマンド *)
    If[MemberQ[$iSessionOnlyCommands, trimmed],
      Return[trimmed <> " \:306f\:5bfe\:8a71\:30e2\:30fc\:30c9\:5c02\:7528\:30b3\:30de\:30f3\:30c9\:3067\:3059\:3002\n" <>
        "Mathematica \:304b\:3089\:306f\:5b9f\:884c\:3067\:304d\:307e\:305b\:3093\:3002\n" <>
        "\:30bf\:30fc\:30df\:30ca\:30eb\:3067 claude \:3092\:8d77\:52d5\:3057\:3066\:5b9f\:884c\:3057\:3066\:304f\:3060\:3055\:3044\:3002"]];
    (* 既知のスラッシュコマンド → CLI 等価コマンド *)
    mapped = Lookup[$iSlashCommandMap, trimmed, None];
    If[mapped =!= None,
      Return[iRunClaudeSubcommand[mapped]]];
    (* 未知のスラッシュコマンド *)
    If[StringStartsQ[trimmed, "/"],
      Return["Error: \:672a\:77e5\:306e\:30b9\:30e9\:30c3\:30b7\:30e5\:30b3\:30de\:30f3\:30c9: " <> trimmed <> "\n" <>
        "ClaudeCommand[\"/help\"] \:3067\:5229\:7528\:53ef\:80fd\:306a\:30b3\:30de\:30f3\:30c9\:3092\:78ba\:8a8d\:3067\:304d\:307e\:3059\:3002"]];
    (* CLI サブコマンド → 直接実行 *)
    iRunClaudeSubcommand[StringSplit[trimmed]]
  ];

(* ============================================================
   NBAccess 分離検証・修正
   ============================================================ *)

(* 分離検証用の内部モデルでクエリ実行 *)
iSeparationQuery[prompt_String] :=
  Module[{savedModel, result},
    savedModel = $ClaudeModel;
    $ClaudeModel = If[StringQ[$ClaudeTestModel] && $ClaudeTestModel =!= "",
      $ClaudeTestModel, savedModel];
    result = iClaudeQueryRaw[prompt];
    $ClaudeModel = savedModel;
    result
  ];

(* ターゲット解決: ファイルパス or パッケージ名 → {ファイルパスリスト, パッケージ名 or None} *)
iResolveSeparationTarget[target_String] :=
  Module[{pkgDir = Global`$packageDirectory, files, ext},
    (* ファイルパスの場合 *)
    ext = FileExtension[target];
    If[MemberQ[{"wl", "m", "nb"}, ext] && FileExistsQ[target],
      Return[{{<|"path" -> target,
               "content" -> Import[target, "Text"]|>}, None}]];
    (* $packageDirectory 内の .wl ファイル *)
    If[StringQ[pkgDir] && pkgDir =!= "",
      If[FileExistsQ[FileNameJoin[{pkgDir, target <> ".wl"}]],
        Return[{{<|"path" -> FileNameJoin[{pkgDir, target <> ".wl"}],
                  "content" -> Import[FileNameJoin[{pkgDir, target <> ".wl"}], "Text"]|>},
                target}]];
      (* Paclet *)
      If[FileExistsQ[FileNameJoin[{pkgDir, target, "PacletInfo.wl"}]],
        files = FileNames["*.wl", FileNameJoin[{pkgDir, target, "Kernel"}]];
        Return[{
          (<|"path" -> #, "content" -> Import[#, "Text"]|>) & /@ files,
          target}]]
    ];
    {{}, None}
  ];

(* ドキュメントコンテキストを収集 *)
iSeparationDocsContext[packageName_String] :=
  Module[{docsDir, docFiles},
    docsDir = iPackageDocsDir[If[StringQ[packageName], packageName, "NBAccess"]];
    If[!StringQ[docsDir] || !DirectoryQ[docsDir], Return[""]];
    docFiles = Select[FileNames["*.md", docsDir],
      StringContainsQ[FileNameTake[#],
        "api" | "design" | "specification" | "developer", IgnoreCase -> True] &];
    If[Length[docFiles] === 0, Return[""]];
    StringJoin[
      ("--- " <> FileNameTake[#] <> " ---\n" <>
       StringTake[Import[#, "Text"], UpTo[4000]] <> "\n\n") & /@
      Take[docFiles, UpTo[3]]]
  ];

(* ============================================================
   静的パターン走査: 正規表現ベースの禁止シンボル検出
   LLM 判定の前段で確実に違反候補を拾い、偽陰性を減らす。
   ============================================================ *)
iStaticSeparationScan[source_String, fileName_String] :=
  Module[{lines, results = {}, patterns, nbAccessWl, notebookExtWl},
    (* NBAccess.wl / NotebookExtensions.wl 自体は検査対象外 *)
    nbAccessWl = StringMatchQ[fileName, "*NBAccess*", IgnoreCase -> True];
    notebookExtWl = StringMatchQ[fileName, "*NotebookExtensions*", IgnoreCase -> True];
    If[nbAccessWl || notebookExtWl, Return[{}]];
    lines = StringSplit[source, "\n"];
    (* 禁止パターン定義: {regex, violationCategory, description} *)
    patterns = {
      (* --- 1. EvaluationCell / CellPrint / SetSelectedNotebook 禁止 --- *)
      {"EvaluationCell\\s*\\[", "f",
       "EvaluationCell[] 直接使用 (NBBeginJobAtEvalCell/NBWriteAnchorAfterEvalCell/NBParentNotebookOfCurrentCell を使用)"},
      {"CellPrint\\s*\\[", "f",
       "CellPrint 直接使用 (NBWriteCell/NBWritePrintNotice を使用)"},
      {"SetSelectedNotebook\\s*\\[", "f",
       "SetSelectedNotebook 直接使用 (NBAccess API に委譲)"},
      {"SelectedCells\\s*\\[", "f",
       "SelectedCells 直接使用 (NBSelectedCellIndices を使用)"},
      {"ParentNotebook\\s*\\[\\s*EvaluationCell", "f",
       "ParentNotebook[EvaluationCell[]] 直接使用 (NBParentNotebookOfCurrentCell を使用)"},

      (* --- 2. CurrentValue/SetOptions による属性直操作禁止 --- *)
      {"CurrentValue\\s*\\[[^,]+,\\s*\\{?\\s*TaggingRules", "g",
       "CurrentValue[..., TaggingRules] 直接使用 (NBCellGetTaggingRule/NBGetConfidentialTag を使用)"},
      {"AbsoluteCurrentValue\\s*\\[[^,]+,\\s*\\{?\\s*TaggingRules", "g",
       "AbsoluteCurrentValue[..., TaggingRules] 直接使用 (NBAccess API に委譲)"},
      {"SetOptions\\s*\\[[^,]+,\\s*TaggingRules", "g",
       "SetOptions[..., TaggingRules -> ...] 直接使用 (NBCellSetOptions を使用)"},
      {"CurrentValue\\s*\\[[^,]+,\\s*\\{?\\s*CellTags", "g",
       "CurrentValue[..., CellTags] 直接使用 (NBCellIndicesByTag を使用)"},
      {"SetOptions\\s*\\[[^,]+,\\s*CellTags", "g",
       "SetOptions[..., CellTags -> ...] 直接使用 (NBCellSetOptions を使用)"},
      {"CurrentValue\\s*\\[[^,]+,\\s*\\{?\\s*CellEpilog", "g",
       "CurrentValue[..., CellEpilog] 直接使用 (NBInstallCellEpilog/NBCellEpilogInstalledQ を使用)"},
      {"AbsoluteCurrentValue\\s*\\[[^,]+,\\s*\\{?\\s*CellEpilog", "g",
       "AbsoluteCurrentValue[..., CellEpilog] 直接使用 (NBAccess API に委譲)"},
      {"SetOptions\\s*\\[[^,]+,\\s*CellEpilog", "g",
       "SetOptions[..., CellEpilog ...] 直接使用 (NBInstallConfidentialEpilog を使用)"},
      {"CurrentValue\\s*\\[[^,]+,\\s*\\{?\\s*CellProlog", "g",
       "CurrentValue[..., CellProlog] 直接使用 (NBAccess API に委譲)"},
      {"SetOptions\\s*\\[[^,]+,\\s*CellProlog", "g",
       "SetOptions[..., CellProlog ...] 直接使用 (NBAccess API に委譲)"},
      {"CurrentValue\\s*\\[[^,]+,\\s*\\{?\\s*NotebookEventActions", "g",
       "CurrentValue[..., NotebookEventActions] 直接使用 (NBAccess API に委譲)"},
      {"SetOptions\\s*\\[[^,]+,\\s*NotebookEventActions", "g",
       "SetOptions[..., NotebookEventActions ...] 直接使用 (NBAccess API に委譲)"},

      (* --- 3. CellObject 漏洩検出 --- *)
      {"Cells\\s*\\[", "h",
       "Cells[] 直接使用による CellObject 取得 (NBCellIndicesByTag/NBCellIndicesByStyle を使用)"},
      {"_CellObject", "h",
       "CellObject パターン引数 (公開 API に CellObject 型を露出させない)"},

      (* --- 4. FE 状態操作禁止 --- *)
      {"SelectionEvaluate\\s*\\[", "i",
       "SelectionEvaluate 直接使用 (NBEvaluatePreviousCell/NBInsertAndEvaluateInput を使用)"},
      {"SelectionEvaluateCreateCell\\s*\\[", "i",
       "SelectionEvaluateCreateCell 直接使用 (NBAccess API に委譲)"},
      {"FrontEndTokenExecute\\s*\\[", "i",
       "FrontEndTokenExecute 直接使用 (NBAccess API に委譲)"},
      {"SelectionMove\\s*\\[", "i",
       "SelectionMove 直接使用 (NBMoveAfterCell を使用)"},

      (* --- 5. NBAccess 公開グローバルの破壊的更新 --- *)
      {"AppendTo\\s*\\[\\s*NBAccess`", "j",
       "AppendTo による NBAccess 公開グローバルの破壊的更新 (setter API を使用)"},
      {"AssociateTo\\s*\\[\\s*NBAccess`", "j",
       "AssociateTo による NBAccess 公開グローバルの破壊的更新 (setter API を使用)"},
      {"PrependTo\\s*\\[\\s*NBAccess`", "j",
       "PrependTo による NBAccess 公開グローバルの破壊的更新 (setter API を使用)"},
      {"KeyDropFrom\\s*\\[\\s*NBAccess`", "j",
       "KeyDropFrom による NBAccess 公開グローバルの破壊的更新 (setter API を使用)"},
      {"Unset\\s*\\[\\s*NBAccess`", "j",
       "Unset による NBAccess 公開グローバルの破壊的更新 (setter API を使用)"},
      {"NBAccess`\\$NB\\w+\\s*=\\s*", "j",
       "NBAccess 公開グローバルへの直接代入 (setter API を使用)"},
      {"NBAccess`\\$NB\\w+\\[", "j",
       "NBAccess 公開グローバルへの Part 代入の可能性 (setter API を使用)"},

      (* --- 既存ルール: NotebookWrite / NotebookRead 直接使用 --- *)
      {"NotebookWrite\\s*\\[", "b",
       "NotebookWrite 直接使用 (NBWriteCell/NBWriteCode/NBWriteText を使用)"},
      {"NotebookRead\\s*\\[", "b",
       "NotebookRead 直接使用 (NBCellRead を使用)"},

      (* --- 既存ルール: SystemCredential 直接使用 --- *)
      {"SystemCredential\\s*\\[", "a",
       "SystemCredential 直接使用 (NBGetAPIKey を使用)"},

      (* --- 既存ルール: NBAccess`Private` 関数呼び出し --- *)
      {"NBAccess`Private`", "d",
       "NBAccess`Private` 関数の直接呼び出し (公開 API を使用)"},

      (* --- CellGroupData 直構築 --- *)
      {"Cell\\s*\\[\\s*CellGroupData", "b",
       "CellGroupData を伴うセルグループ直構築 (NBWriteCell に Cell[CellGroupData[...]] を渡すか専用APIを使用)"}
    };
    (* 各行を走査 *)
    Do[
      Module[{line, lineNum, trimmed},
        lineNum = idx;
        line = lines[[idx]];
        (* コメント行はスキップ *)
        trimmed = StringTrim[line];
        If[StringStartsQ[trimmed, "(*"], Continue[]];
        Do[
          Module[{regex, cat, desc},
            {regex, cat, desc} = pat;
            If[StringContainsQ[line, RegularExpression[regex]],
              (* NBAccess` API 呼び出しは許可: NBAccess`NBxxxxx[ パターン *)
              If[cat === "b" && StringContainsQ[line, "NBAccess`NB"],
                Continue[]];
              (* NBWriteCell に CellGroupData を渡すのは許可 *)
              If[cat === "b" && StringContainsQ[line, RegularExpression["Cell\\s*\\[\\s*CellGroupData"]] &&
                 StringContainsQ[line, "NBAccess`NBWriteCell"],
                Continue[]];
              AppendTo[results,
                <|"line" -> lineNum,
                  "code" -> StringTake[StringTrim[line], UpTo[120]],
                  "violation" -> cat,
                  "description" -> desc,
                  "source" -> "static"|>]
            ]
          ],
        {pat, patterns}]
      ],
    {idx, Length[lines]}];
    results
  ];

(* 分離チェック実行 *)
ClaudeCheckSeparation[target_String, opts:OptionsPattern[{Fallback -> False}]] :=
  Module[{resolved, files, pkgName, prompt, result, docsCtx, ignoreList,
          nb = Quiet[InputNotebook[]]},
    $currentUseFallback = TrueQ[OptionValue[Fallback]];
    iPrecisionConfidentialCheck[nb];
    {files, pkgName} = iResolveSeparationTarget[target];
    If[Length[files] === 0,
      Print["\:30a8\:30e9\:30fc: \:30d5\:30a1\:30a4\:30eb\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093: " <> target];
      Return[$Failed]];
    (* セクションヘッダーを入力セルの直前に挿入 *)
    iWriteSectionHeaderBeforeEvalCell[nb,
      "\:25b6 ClaudeCheckSeparation: " <> target <>
      " (" <> DateString[Now, {"Year", "/", "Month", "/", "Day", " ", "Hour24", ":", "Minute"}] <> ")"];
    (* 無視リストチェック *)
    ignoreList = If[ListQ[NBAccess`$NBSeparationIgnoreList],
      NBAccess`$NBSeparationIgnoreList, {}];
    If[StringQ[pkgName] && MemberQ[ignoreList, pkgName],
      Print[target <> " \:306f\:5206\:96e2\:691c\:67fb\:306e\:7121\:8996\:30ea\:30b9\:30c8\:306b\:767b\:9332\:3055\:308c\:3066\:3044\:307e\:3059\:3002"];
      Return[{}]];
    (* NBAccess ドキュメントコンテキスト *)
    docsCtx = iSeparationDocsContext["NBAccess"];
    (* 各ファイルに対してチェック *)
    result = {};
    Do[
      Module[{fPath, fContent, checkPrompt, resp, staticHits, llmHits, merged},
        fPath = fileInfo["path"];
        fContent = fileInfo["content"];
        If[!StringQ[fContent] || StringLength[fContent] === 0, Continue[]];
        (* 無視リストのファイルパスチェック *)
        If[AnyTrue[ignoreList, StringContainsQ[fPath, # <> ".wl", IgnoreCase -> True] &],
          Continue[]];
        (* Phase 1: 静的パターン走査 *)
        staticHits = iStaticSeparationScan[fContent, FileNameTake[fPath]];
        (* Phase 2: LLM による文脈判定 *)
        checkPrompt =
          "You are a code auditor for Wolfram Language packages.\n" <>
          "Check the following source file for violations of the NBAccess separation principle.\n\n" <>
          "RULES:\n" <>
          "The following operations are VIOLATIONS when found outside of NBAccess.wl and NotebookExtensions.wl:\n" <>
          "a. SystemCredential direct usage (must use NBGetAPIKey instead)\n" <>
          "b. CellObject direct retention/manipulation (Cells[], NotebookRead[], NotebookWrite[], SelectionMove[], " <>
          "CellPrint[], Cell[CellGroupData[...]] direct construction, etc.)\n" <>
          "c. CellEpilog/CellProlog/NotebookEventActions direct manipulation " <>
          "(must use NBInstallCellEpilog/NBInstallConfidentialEpilog etc.)\n" <>
          "d. Calling NBAccess`Private` functions (internal functions starting with i)\n" <>
          "e. Directly updating NBAccess public globals ($NBConfidentialSymbols, $NBPrivacySpec etc.) " <>
          "without using the setter functions. Includes AppendTo, AssociateTo, PrependTo, KeyDropFrom, " <>
          "Unset, Part assignment on NBAccess` globals.\n" <>
          "f. Direct use of EvaluationCell[], SelectedCells[], ParentNotebook[EvaluationCell[]], " <>
          "CellPrint[], SetSelectedNotebook[] " <>
          "(must use NBBeginJobAtEvalCell, NBParentNotebookOfCurrentCell, NBWriteCell, NBWritePrintNotice etc.)\n" <>
          "g. CurrentValue/AbsoluteCurrentValue/SetOptions for TaggingRules, CellTags, CellEpilog, CellProlog, " <>
          "NotebookEventActions, CellDynamicExpression, NotebookDynamicExpression " <>
          "(must use NBCellGetTaggingRule, NBCellSetOptions, NBInstallCellEpilog etc.)\n" <>
          "h. CellObject leakage: public function arguments with _CellObject pattern, returning CellObject " <>
          "from public functions, storing CellObject in Association/global state, " <>
          "holding Cells[]/EvaluationCell[] results in non-local variables.\n" <>
          "i. FrontEnd state manipulation: SelectionEvaluate[], SelectionEvaluateCreateCell[], " <>
          "SetSelectedNotebook[], FrontEndTokenExecute[], SelectionMove[] " <>
          "(must use NBEvaluatePreviousCell, NBInsertAndEvaluateInput, NBWriteInputCellAndMaybeEvaluate, " <>
          "NBMoveAfterCell etc.)\n" <>
          "j. Destructive updates to NBAccess public globals via AppendTo, AssociateTo, PrependTo, " <>
          "KeyDropFrom, Unset, Increment, Decrement, Part assignment (x[key]=...) " <>
          "(must use NBRegisterConfidentialVar, NBSetConfidentialVars etc.)\n\n" <>
          "EXCEPTION: Calls through the NBAccess public API (NBAccess`NBxxx[...]) are ALLOWED.\n" <>
          "EXCEPTION: Passing Cell[CellGroupData[...]] as argument to NBAccess`NBWriteCell is ALLOWED.\n\n" <>
          If[Length[staticHits] > 0,
            "=== STATIC SCAN PRE-RESULTS (verify these with context) ===\n" <>
            StringJoin[
              ("L" <> ToString[#["line"]] <> " [" <> #["violation"] <> "]: " <>
               #["code"] <> "\n") & /@ Take[staticHits, UpTo[30]]] <> "\n",
            ""] <>
          "Respond in JSON format ONLY. No other text.\n" <>
          "Format: [{\"line\": <line_number>, \"code\": \"<offending code snippet>\", " <>
          "\"violation\": \"<a|b|c|d|e|f|g|h|i|j>\", \"description\": \"<explanation in " <> iLanguageName[] <> ">\"}]\n" <>
          "If no violations found, respond with: []\n\n" <>
          If[docsCtx =!= "",
            "=== NBAccess DOCUMENTATION (for reference) ===\n" <> docsCtx <> "\n", ""] <>
          "=== SOURCE FILE: " <> FileNameTake[fPath] <> " ===\n" <> fContent;
        resp = iSeparationQuery[checkPrompt];
        llmHits = {};
        If[StringQ[resp] && !StringStartsQ[resp, "Error:"],
          Module[{json, parsed},
            json = StringReplace[resp, {
              RegularExpression["^```(?:json)?\\s*\n"] -> "",
              RegularExpression["\n```\\s*$"] -> ""}];
            parsed = Quiet @ Check[
              ImportString[json, "RawJSON"],
              $Failed];
            If[ListQ[parsed],
              llmHits = parsed,
              llmHits = {<|"line" -> 0,
                "description" -> "\:89e3\:6790\:5931\:6557: " <> StringTake[resp, UpTo[300]]|>}]
          ],
          llmHits = {<|"line" -> 0,
            "description" -> "\:30af\:30a8\:30ea\:5931\:6557: " <> ToString[resp]|>}
        ];
        (* Phase 3: 静的走査結果と LLM 結果をマージ (重複排除) *)
        merged = llmHits;
        Do[
          If[!AnyTrue[merged,
            Lookup[#, "line", -1] === sh["line"] &&
            StringContainsQ[Lookup[#, "violation", ""], sh["violation"]] &],
            AppendTo[merged, KeyDrop[sh, "source"]]],
        {sh, staticHits}];
        AppendTo[result, <|"file" -> fPath, "violations" -> merged|>]
      ],
    {fileInfo, files}];
    (* キャッシュに保存 *)
    $iSeparationCheckCache[target] = result;
    (* 表示 *)
    Module[{catLabels = <|
      "a" -> "SystemCredential\:76f4\:63a5", "b" -> "\:30bb\:30eb\:76f4\:63a5\:64cd\:4f5c",
      "c" -> "CellEpilog\:76f4\:63a5", "d" -> "Private`\:547c\:3073\:51fa\:3057",
      "e" -> "\:30b0\:30ed\:30fc\:30d0\:30eb\:76f4\:63a5\:66f4\:65b0", "f" -> "EvalCell/CellPrint/SetSelectedNB",
      "g" -> "\:5c5e\:6027\:76f4\:63a5\:30a2\:30af\:30bb\:30b9", "h" -> "CellObject\:6f0f\:6d29",
      "i" -> "FE\:72b6\:614b\:64cd\:4f5c", "j" -> "\:30b0\:30ed\:30fc\:30d0\:30eb\:7834\:58ca\:7684\:66f4\:65b0"|>},
    Do[
      Module[{f = entry["file"], vs = entry["violations"]},
        If[Length[vs] === 0,
          Print[Style["\:2705 " <> FileNameTake[f] <> ": \:9055\:53cd\:306a\:3057", Bold]],
          Print[Style["\:26a0\:fe0f " <> FileNameTake[f] <> ": " <>
            ToString[Length[vs]] <> " \:4ef6\:306e\:9055\:53cd", Bold, FontColor -> RGBColor[0.8, 0, 0]]];
          Do[
            Module[{vCat = Lookup[v, "violation", ""],
                    vLabel},
              vLabel = If[StringQ[vCat] && vCat =!= "",
                "[" <> vCat <> ":" <> Lookup[catLabels, vCat, vCat] <> "]", ""];
              Print["  L" <> ToString[Lookup[v, "line", "?"]] <> ": " <>
                Lookup[v, "description", ""] <> " " <> vLabel]],
          {v, vs}]]
      ],
    {entry, result}]];
    result
  ];

(* 分離違反の修正 *)
ClaudeFixSeparation[target_String, opts:OptionsPattern[{Fallback -> False}]] :=
  Module[{resolved, files, pkgName, cached, ext, timestamp,
          nb = Quiet[InputNotebook[]]},
    $currentUseFallback = TrueQ[OptionValue[Fallback]];
    iPrecisionConfidentialCheck[nb];
    {files, pkgName} = iResolveSeparationTarget[target];
    If[Length[files] === 0,
      Print["\:30a8\:30e9\:30fc: \:30d5\:30a1\:30a4\:30eb\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093: " <> target];
      Return[$Failed]];
    (* セクションヘッダーを入力セルの直前に挿入 *)
    iWriteSectionHeaderBeforeEvalCell[nb,
      "\:25b6 ClaudeFixSeparation: " <> target <>
      " (" <> DateString[Now, {"Year", "/", "Month", "/", "Day", " ", "Hour24", ":", "Minute"}] <> ")"];
    (* キャッシュされた検査結果を確認、なければ先に検査 *)
    cached = Lookup[$iSeparationCheckCache, target, None];
    If[cached === None,
      Print["\:5206\:96e2\:691c\:67fb\:3092\:5148\:306b\:5b9f\:884c\:3057\:307e\:3059..."];
      cached = ClaudeCheckSeparation[target, Fallback -> TrueQ[OptionValue[Fallback]]];
      If[cached === $Failed, Return[$Failed]]];
    (* 違反があるか確認 *)
    If[!AnyTrue[cached, Length[#["violations"]] > 0 &],
      Print["\:9055\:53cd\:306f\:898b\:3064\:304b\:308a\:307e\:305b\:3093\:3067\:3057\:305f\:3002\:4fee\:6b63\:306f\:4e0d\:8981\:3067\:3059\:3002"];
      Return[]];
    (* ファイルパスの場合: バックアップを作成して直接修正 *)
    ext = FileExtension[target];
    If[MemberQ[{"wl", "m", "nb"}, ext] && FileExistsQ[target],
      Module[{backupPath, violationDesc},
        timestamp = DateString[Now, {"Year","Month","Day","Hour24","Minute","Second"}];
        backupPath = StringReplace[target,
          "." <> ext -> "_orig" <> timestamp <> "." <> ext];
        CopyFile[target, backupPath];
        Print["\:30d0\:30c3\:30af\:30a2\:30c3\:30d7: " <> backupPath];
        violationDesc = StringJoin[
          ("L" <> ToString[Lookup[#, "line", "?"]] <> ": " <>
           Lookup[#, "description", ""] <> "\n") & /@
          Flatten[#["violations"] & /@ cached]];
        (* ClaudeUpdatePackage 相当の修正 *)
        Module[{src, fixPrompt, fixResult},
          src = Import[target, "Text"];
          fixPrompt =
            "Fix the following NBAccess separation violations in this Wolfram Language source file.\n" <>
            "Use the NBAccess public API instead of direct operations.\n\n" <>
            "REPLACEMENT GUIDE:\n" <>
            "- NotebookWrite[nb,...] -> NBAccess`NBWriteCell[nb,...]\n" <>
            "- NotebookRead[...] -> NBAccess`NBCellRead[nb, idx]\n" <>
            "- CellPrint[...] -> NBAccess`NBWriteCell[nb,...] or NBAccess`NBWritePrintNotice[nb,...]\n" <>
            "- EvaluationCell[] -> use NBAccess`NBBeginJobAtEvalCell or NBAccess`NBWriteAnchorAfterEvalCell\n" <>
            "- ParentNotebook[EvaluationCell[]] -> NBAccess`NBParentNotebookOfCurrentCell[]\n" <>
            "- SetSelectedNotebook[nb] -> (remove or wrap in NBAccess API)\n" <>
            "- SelectionMove[...] -> NBAccess`NBMoveAfterCell[nb, idx]\n" <>
            "- SelectionEvaluate[nb] -> NBAccess`NBEvaluatePreviousCell[nb] or NBAccess`NBInsertAndEvaluateInput[nb,...]\n" <>
            "- Cells[nb, CellTags->...] -> NBAccess`NBCellIndicesByTag[nb, tag]\n" <>
            "- CurrentValue[..., TaggingRules] -> NBAccess`NBCellGetTaggingRule[nb, idx, path]\n" <>
            "- SetOptions[..., TaggingRules->...] -> NBAccess`NBCellSetOptions[nb, idx, opts]\n" <>
            "- AppendTo/AssociateTo on NBAccess` globals -> use setter APIs (NBRegisterConfidentialVar etc.)\n\n" <>
            "VIOLATIONS:\n" <> violationDesc <> "\n\n" <>
            "Output the COMPLETE corrected source file. Do NOT wrap in code fences.\n\n" <>
            "=== SOURCE ===\n" <> src;
          fixResult = iSeparationQuery[fixPrompt];
          If[StringQ[fixResult] && !StringStartsQ[fixResult, "Error:"],
            Module[{clean, isFullFile, finalCode},
              clean = StringReplace[fixResult, {
                RegularExpression["^```(?:mathematica|wolfram)?\\s*\n"] -> "",
                RegularExpression["\n```\\s*$"] -> ""}];
              (* 全ファイルか部分的レスポンスかを判定 *)
              isFullFile = StringContainsQ[clean, "BeginPackage["] &&
                           StringContainsQ[clean, "EndPackage["] &&
                           StringLength[clean] > StringLength[src] * 0.7;
              If[isFullFile,
                finalCode = clean,
                (* 部分的レスポンス: マージを試みる *)
                Module[{origBlks, updBlks, code = src, mc = 0},
                  origBlks = iExtractFunctions[src];
                  updBlks  = iExtractFunctions[clean];
                  Scan[Function[fn,
                    Module[{oldDef, newDef},
                      oldDef = Lookup[origBlks, fn, ""];
                      newDef = Lookup[updBlks, fn, ""];
                      If[oldDef =!= "" && newDef =!= "",
                        code = StringReplace[code, oldDef -> newDef, 1];
                        mc++]
                    ]
                  ], Keys[updBlks]];
                  If[mc > 0,
                    Print["\:90e8\:5206\:30ec\:30b9\:30dd\:30f3\:30b9\:3092\:30de\:30fc\:30b8: " <> ToString[mc] <> " \:500b\:306e\:95a2\:6570\:3092\:66f4\:65b0"];
                    finalCode = code,
                    (* マージ不能: 安全検証してからフォールバック *)
                    If[StringLength[clean] > StringLength[src] * 0.5,
                      finalCode = clean,
                      Print[Style["\:26a0 \:30ec\:30b9\:30dd\:30f3\:30b9\:304c\:5c0f\:3055\:3059\:304e\:307e\:3059\:3002\:30de\:30fc\:30b8\:3082\:5931\:6557\:3002\:30b9\:30ad\:30c3\:30d7\:3057\:307e\:3059\:3002",
                        FontColor -> RGBColor[0.8, 0, 0]]];
                      finalCode = None
                    ]
                  ]
                ]
              ];
              If[finalCode =!= None,
                Export[target, finalCode, "Text", CharacterEncoding -> "UTF-8"];
                Print[Style["\:2705 " <> FileNameTake[target] <> " \:3092\:4fee\:6b63\:3057\:307e\:3057\:305f", Bold]];
                $iSeparationCheckCache = KeyDrop[$iSeparationCheckCache, target],
                Print["\:30b9\:30ad\:30c3\:30d7: " <> FileNameTake[target] <> " \:306f\:5909\:66f4\:3055\:308c\:307e\:305b\:3093\:3067\:3057\:305f"]
              ]
            ],
            Print["\:30a8\:30e9\:30fc: \:4fee\:6b63\:306b\:5931\:6557: " <> StringTake[ToString[fixResult], UpTo[200]]]
          ]
        ]
      ];
      Return[]];
    (* パッケージ名のみの場合: ClaudeUpdatePackage を呼び出す *)
    If[StringQ[pkgName],
      Module[{violationDesc},
        violationDesc = StringJoin[
          (FileNameTake[#["file"]] <> ":\n" <>
           StringJoin[
             ("  L" <> ToString[Lookup[v, "line", "?"]] <> ": " <>
              Lookup[v, "description", ""] <> "\n") & /@
             #["violations"]] <> "\n") & /@
          Select[cached, Length[#["violations"]] > 0 &]];
        Print["\:30d1\:30c3\:30b1\:30fc\:30b8 " <> pkgName <> " \:3092 ClaudeUpdatePackage \:3067\:4fee\:6b63\:3057\:307e\:3059..."];
        ClaudeUpdatePackage[pkgName,
          "NBAccess\:306e\:5206\:96e2\:539f\:5247\:306b\:5f93\:3063\:3066\:4ee5\:4e0b\:306e\:9055\:53cd\:3092\:4fee\:6b63\:3057\:3066\:304f\:3060\:3055\:3044\:3002\n" <>
          "SystemCredential\:76f4\:63a5\:5229\:7528\:306fNBGetAPIKey\:306b\:3001CellObject\:76f4\:63a5\:64cd\:4f5c\:306fNBAccess\:306eAPI\:306b\:3001\n" <>
          "CellEpilog/CellProlog/NotebookEventActions\:76f4\:63a5\:64cd\:4f5c\:306fNBInstallCellEpilog\:7b49\:306b\:3001\n" <>
          "NBAccess`Private`\:95a2\:6570\:306f\:516c\:958bAPI\:306b\:7f6e\:63db\:3002\n" <>
          "EvaluationCell[]/CellPrint[]/SetSelectedNotebook[]\:306fNBAccess API\:306b\:7f6e\:63db\:3002\n" <>
          "CurrentValue/SetOptions\:306b\:3088\:308bTaggingRules/CellTags/CellEpilog\:76f4\:63a5\:30a2\:30af\:30bb\:30b9\:306fNBAccess API\:306b\:7f6e\:63db\:3002\n" <>
          "SelectionEvaluate/SelectionMove/FrontEndTokenExecute\:306fNBAccess API\:306b\:7f6e\:63db\:3002\n" <>
          "NBAccess\:516c\:958b\:30b0\:30ed\:30fc\:30d0\:30eb\:3078\:306eAppendTo/AssociateTo\:7b49\:306fsetter API\:306b\:7f6e\:63db\:3002\n\n" <>
          "\:9055\:53cd\:4e00\:89a7:\n" <> violationDesc,
          Fallback -> TrueQ[OptionValue[Fallback]]];
        $iSeparationCheckCache = KeyDrop[$iSeparationCheckCache, target]
      ];
      Return[]];
    Print["\:30a8\:30e9\:30fc: \:4fee\:6b63\:5bfe\:8c61\:3092\:7279\:5b9a\:3067\:304d\:307e\:305b\:3093\:3067\:3057\:305f: " <> target]
  ];

(* ClaudeUpdatePackage のパッケージ名のみ呼び出し: 分離違反修正 *)
ClaudeUpdatePackage[packageName_String] :=
  ClaudeFixSeparation[packageName];

(* ============================================================
   ClaudePrepareCommit: 前回コミット以降の変更を収集し
   コミットメッセージ付きの GitHubRefreshAndCommit コマンドを出力
   ============================================================ *)

(* バックアップディレクトリ名のタイムスタンプを AbsoluteTime に変換 *)
iBackupDirToAbsoluteTime[dirName_String] :=
  Module[{ts, m},
    ts = iBackupTimestampPart[dirName];
    (* YYYYMMDD_HHMMSS 形式 *)
    m = StringCases[ts,
      RegularExpression["^(\\d{4})(\\d{2})(\\d{2})_(\\d{2})(\\d{2})(\\d{2})$"] :>
        {"$1", "$2", "$3", "$4", "$5", "$6"}];
    If[Length[m] > 0,
      Quiet @ AbsoluteTime[{
        StringJoin[Riffle[First[m], {"-", "-", " ", ":", ":"}]],
        {"Year", "-", "Month", "-", "Day", " ", "Hour", ":", "Minute", ":", "Second"}}],
      (* YYYYMMDDHHMM 形式 *)
      m = StringCases[ts,
        RegularExpression["^(\\d{4})(\\d{2})(\\d{2})(\\d{2})(\\d{2})$"] :>
          {"$1", "$2", "$3", "$4", "$5"}];
      If[Length[m] > 0,
        Quiet @ AbsoluteTime[{
          StringJoin[Riffle[First[m], {"-", "-", " ", ":"}]],
          {"Year", "-", "Month", "-", "Day", " ", "Hour", ":", "Minute"}}],
        0]]];

(* 前回コミット以降のバックアップエントリから変更サマリーを収集 *)
iCollectChangeSummaries[packageName_String, sinceTime_?NumericQ] :=
  Module[{entries, filtered, summaries = {}},
    entries = iAllBackupEntries[packageName];
    (* sinceTime 以降のエントリをフィルタ *)
    filtered = Select[entries,
      iBackupDirToAbsoluteTime[#["DirName"]] > sinceTime &];
    (* pre_ バックアップは除外（更新前の保存であり変更内容ではない） *)
    filtered = Select[filtered, !StringStartsQ[#["DirName"], "pre_"] &];
    Do[
      Module[{prompt = entry["Prompt"], btype = entry["Type"]},
        If[StringQ[prompt] && StringLength[StringTrim[prompt]] > 0,
          Module[{summary = StringTrim[prompt], label},
            (* 長すぎるプロンプトは先頭を抽出 *)
            If[StringLength[summary] > 200,
              summary = StringTake[summary, 200]];
            (* INSTRUCTION: 以降を抽出 *)
            summary = First[StringCases[summary,
              "INSTRUCTION: " ~~ rest__ :> rest], summary];
            (* 定型句を除去 *)
            summary = StringReplace[summary, {
              "\:524d\:56de\:306e\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:66f4\:65b0\:4ee5\:964d\:306e\:30bd\:30fc\:30b9\:30b3\:30fc\:30c9\:5909\:66f4\:3092\:53cd\:6620\:3057\:3066\:3001\:30c9\:30ad\:30e5\:30e1\:30f3\:30c8\:3092\:66f4\:65b0\:3057\:3066\:304f\:3060\:3055\:3044\:3002" ->
                "auto-update docs"}];
            summary = StringTrim[summary];
            If[StringLength[summary] > 0,
              label = Switch[btype,
                "doc", "[docs] ",
                "update", "",
                _, ""];
              AppendTo[summaries, label <> summary]]]]],
      {entry, filtered}];
    summaries
  ];

(* 変更サマリーリストを "- " 付き72文字折り返しで整形 *)
iWrapCommitBodyLines[summaries_List] :=
  Module[{bodyLines},
    bodyLines = Map[
      Function[s,
        Module[{line = "- " <> s, wrapped = {}},
          While[StringLength[line] > 72,
            Module[{breakPos},
              breakPos = StringPosition[StringTake[line, 72], " "];
              breakPos = If[Length[breakPos] > 0, Last[breakPos][[1]], 72];
              AppendTo[wrapped, StringTake[line, breakPos]];
              line = "  " <> StringTrim[StringDrop[line, breakPos]]]];
          AppendTo[wrapped, line];
          StringJoin[Riffle[wrapped, "\n"]]]],
      summaries];
    StringJoin[Riffle[bodyLines, "\n"]]
  ];

(* 変更サマリーリストからコミットメッセージを構築。
   1行目: 50文字以内の要約
   本文: 各変更を72文字折り返しで列挙 *)
iFormatCommitMessage[packageName_String, summaries_List] :=
  Module[{subject, body},
    If[Length[summaries] === 0,
      Return["Update " <> packageName]];
    (* 1行目: 最初のサマリーをベースに短い要約を生成 *)
    subject = If[Length[summaries] === 1,
      summaries[[1]],
      summaries[[1]] <> " + " <> ToString[Length[summaries] - 1] <> " more"];
    (* 50文字に収める *)
    If[StringLength[subject] > 50,
      subject = StringTake[subject, 47] <> "..."];
    body = iWrapCommitBodyLines[summaries];
    subject <> "\n\n" <> body
  ];

Options[ClaudePrepareCommit] = {
  Fallback -> False,
  Owner -> Automatic, Repository -> Automatic,
  Branch -> Automatic, BaseBranch -> Automatic,
  DryRun -> False
};

(* 2引数版: subject を直接指定。本文は自動収集した変更点から構築。 *)
ClaudePrepareCommit[packageName_String, subject_String, opts:OptionsPattern[]] :=
  iClaudePrepareCommitImpl[packageName, subject, opts];

(* 1引数版: コミットメッセージも自動生成 *)
ClaudePrepareCommit[packageName_String, opts:OptionsPattern[]] :=
  iClaudePrepareCommitImpl[packageName, Automatic, opts];

iClaudePrepareCommitImpl[packageName_String, subjectSpec_, opts:OptionsPattern[ClaudePrepareCommit]] :=
  With[{nb = EvaluationNotebook[]},
  Module[{commits, lastCommitTime = 0, lastCommitMsg = "",
          summaries, commitMsg, escapedMsg, command, body,
          ghOpts, dryRun},
    dryRun = TrueQ[OptionValue[ClaudePrepareCommit, {opts}, DryRun]];
    ghOpts = Sequence[
      Owner -> OptionValue[ClaudePrepareCommit, {opts}, Owner],
      Repository -> OptionValue[ClaudePrepareCommit, {opts}, Repository],
      Branch -> OptionValue[ClaudePrepareCommit, {opts}, Branch],
      BaseBranch -> OptionValue[ClaudePrepareCommit, {opts}, BaseBranch],
      Fallback -> OptionValue[ClaudePrepareCommit, {opts}, Fallback]];

    (* 最新コミットを取得 *)
    Print[Style["\:25b6 " <> packageName <> " \:306e\:6700\:65b0\:30b3\:30df\:30c3\:30c8\:3092\:53d6\:5f97\:4e2d...", Bold]];
    commits = Quiet @ GitHubREST`GitHubListCommits[packageName,
      MaxItems -> 1, ghOpts];
    If[!FailureQ[commits] && ListQ[commits] && Length[commits] > 0,
      Module[{latest = First[commits], dateStr, msg},
        dateStr = Quiet @ Check[
          latest["commit"]["committer"]["date"], None];
        If[StringQ[dateStr],
          lastCommitTime = Quiet @ Check[
            AbsoluteTime[{dateStr, {"Year", "-", "Month", "-", "Day",
              "T", "Hour", ":", "Minute", ":", "Second", "Z"}}], 0]];
        msg = Quiet @ Check[
          latest["commit"]["message"], ""];
        If[StringQ[msg], lastCommitMsg = First[StringSplit[msg, "\n"], msg]];
        Print["  \:6700\:7d42\:30b3\:30df\:30c3\:30c8: ", lastCommitMsg];
        Print["  \:65e5\:6642: ", If[StringQ[dateStr], dateStr, "(\:4e0d\:660e)"]]],
      Print["  \:30b3\:30df\:30c3\:30c8\:5c65\:6b74\:306a\:3057\:ff08\:65b0\:898f\:30ea\:30dd\:30b8\:30c8\:30ea\:ff09"]];

    (* 前回コミット以降の変更サマリーを収集 *)
    Print[Style["\:25b6 \:524d\:56de\:30b3\:30df\:30c3\:30c8\:4ee5\:964d\:306e\:5909\:66f4\:3092\:53ce\:96c6\:4e2d...", Bold]];
    summaries = iCollectChangeSummaries[packageName, lastCommitTime];
    If[Length[summaries] === 0,
      Print["  \:5909\:66f4\:5c65\:6b74\:304c\:898b\:3064\:304b\:308a\:307e\:305b\:3093\:3002" <>
        If[subjectSpec === Automatic, "\:30c7\:30d5\:30a9\:30eb\:30c8\:30e1\:30c3\:30bb\:30fc\:30b8\:3092\:4f7f\:7528\:3057\:307e\:3059\:3002", ""]],
      Print["  " <> ToString[Length[summaries]] <> " \:4ef6\:306e\:5909\:66f4\:3092\:691c\:51fa"]];

    (* コミットメッセージを構築 *)
    If[subjectSpec === Automatic,
      (* 1引数版: subject も自動生成 *)
      commitMsg = iFormatCommitMessage[packageName, summaries],
      (* 2引数版: subject はユーザー指定、本文は自動収集 *)
      If[StringLength[subjectSpec] > 50,
        Print[Style["  \:26a0 subject \:304c 50\:6587\:5b57\:3092\:8d85\:3048\:3066\:3044\:307e\:3059 (" <>
          ToString[StringLength[subjectSpec]] <> "\:6587\:5b57)\:3002git \:306e\:6163\:4f8b\:3067\:306f 50\:6587\:5b57\:4ee5\:5185\:304c\:63a8\:5968\:3067\:3059\:3002",
          RGBColor[0.8, 0.4, 0]]]];
      body = If[Length[summaries] > 0,
        iWrapCommitBodyLines[summaries], ""];
      commitMsg = If[body =!= "",
        subjectSpec <> "\n\n" <> body,
        subjectSpec]];

    Print[Style["\:25b6 \:30b3\:30df\:30c3\:30c8\:30e1\:30c3\:30bb\:30fc\:30b8:", Bold]];
    Print[Style[commitMsg, FontFamily -> "Consolas", FontSize -> 10]];

    If[dryRun,
      Print["\n", Style["(DryRun: \:30b3\:30de\:30f3\:30c9\:306f\:751f\:6210\:3055\:308c\:307e\:305b\:3093)", Italic]];
      Return[commitMsg]];

    (* GitHubRefreshAndCommit コマンドを Input セルとして出力 *)
    escapedMsg = StringReplace[commitMsg, {"\\" -> "\\\\", "\"" -> "\\\"", "\n" -> "\\n"}];
    command = "GitHubRefreshAndCommit[\"" <> packageName <> "\", \"" <>
      escapedMsg <> "\"]";
    Print[""];
    Print[Style["\:25b6 \:4ee5\:4e0b\:3092\:5b9f\:884c\:3057\:3066\:30b3\:30df\:30c3\:30c8:", Bold]];
    NBAccess`NBWriteCell[nb, Cell[BoxData[command], "Input"]];
  ]];

AddToPalettesMenu[{{"Claude Code",
  "Needs[\"ClaudeCode`\"]; ClaudeCode`ShowClaudePalette[]"}}];

End[];

EndPackage[];