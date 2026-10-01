# Current State

Updated: 2026-10-01
Branch/worktree: `main` in the iCloud tree `~/Documents/GitHub/OpenCone`, pushed to origin 2026-10-01
Last verified commit: 0032a7f (merge of origin/main's 2026-09-23 docs corrections, no code; routing and the model
catalog are ec09fb8; Gunnar's prompt-cache work stays uncommitted)

## Objective
Reboot OpenCone around one idea, in Gunnar's words (2026-09-30): "just ask once and then it
basically go and figure out whichever index it needs to query". Routing across the person's existing
Pinecone indexes and namespaces is committed and unit-tested; it closes when the live check under
Exact Next Action passes.

## Status
Committed in ec09fb8 (2026-10-01) and pushed, test_verified. Never run against real OpenAI or
Pinecone accounts. Version 3 is on the App Store; 3.1 is tagged and set as `MARKETING_VERSION` but not
released, so a release would carry this work as 3.1 or later.

## Completed
- Routing: with 2+ indexes or namespaces and Settings > Search Across Indexes on (the default), one
  non-streamed Responses call (`ResponsesClient`) offers a strict `search_index(index, namespace,
  query)` tool. `IndexRouter` keeps calls to offered indexes and existing namespaces, drops
  duplicates and caps at 5. `SearchViewModel.runRoutedSearches` embeds each query with the model
  that built its index and runs the searches in parallel. The answer streams through `streamAnswer`
  (the pre-routing code, moved by script) with passages tagged `[S1]` onward and labelled with index
  and namespace. `searchOpenIndex` (the pre-routing path) is the fallback when routing can't run or
  every routed search fails.
- Index survey (`IndexSurveyor`): namespaces and counts, a random-vector sample, the model check
  (re-embed one stored passage with each OpenAI model that fits the dimension; match at cosine
  >= 0.6), and a drafted one-line summary. Kept per hashed project ID in UserDefaults
  (`IndexCatalogStore`) and cleared by the Settings reset. Refreshed after 1 hour (searchable) or
  10 minutes (empty or unmatched), after an upload in Documents, and by "Check again" in the Index
  summaries sheet (index menu in Search).
- Gunnar's decisions on 2026-10-01 ("go nuts" to the plan): cap of 5 searches; summaries drafted by
  the app and editable; one search round until device tests say otherwise.
- Fixed: the Sources chips under every answer printed literal code since commit 0c37e06
  (2025-11-15), in `OpenCone/Features/Search/Components/ChatBubble.swift`.
- `OpenAIService.createEmbeddings`: optional `model:`, and no `dimensions` for ada-002.
- A reviewer agent's 13 findings on the first version are all fixed and covered by tests.
- Models: OpenResponses' model catalog adopted at Gunnar's request (2026-10-01): `ModelCatalog.json` copied
  unchanged apart from its notes line, `ModelCatalog`, `ModelCatalogStore`, the text-model part of
  `CurrentModelCatalog` and `OpenAIModel` ported into `OpenCone/Core/Models/`. Default model `gpt-6-sol`;
  the menu lists the account's newer models, then the catalog; a saved retired model moves to its documented
  replacement when Settings loads; efforts follow the catalog (`normalizedEffort`); GET /models runs once per
  launch (`SettingsViewModel.refreshAccountModels`); summary drafts use `gpt-6-luna`. `docs/model-catalog.md`.
- Docs: `README.md`, `ARCHITECTURE.md`, `PRIVACY.md` (what routing sends to OpenAI), `CLAUDE.md`.
- Notion roadmap (IDs in `.claude/skills/notion-roadmap/SKILL.md`): routing row "Route each
  question to the index that has the answer" is In Progress, Evidence test_verified, Owner "Gunnar
  on a device"; one new trap and five new fix rows, named under Blockers.

## Active Constraints
- `OpenCone/Services/OpenAIService.swift` (+76 lines) and `OpenConeTests/Services/OpenAIServiceTests.swift`
  (+43) still hold Gunnar's uncommitted prompt-cache work (2026-09-02); ec09fb8 left it out by staging a
  copy of the file with only this session's `createEmbeddings` change (`git hash-object -w` plus
  `git update-index --cacheinfo`). His roadmap row decides whether it is committed or dropped.
- A clone of `OpenCone demo` made for the live check (`OpenCone routing test`) was deleted at Gunnar's word on
  2026-10-01 without being used: the permission classifier blocked booting it in Auto mode as credential
  exploration. A live check with his saved keys needs a fresh clone and a session out of Auto mode.
- Build and test only on the `OpenCone` simulator `8DBC8F9E-48CE-4D77-83C0-6AB1C349BE4D`. Never on
  `OpenCone demo` (`5D5E8E61-...`): it holds Gunnar's API keys, and erasing it drops them.
- Commit to `main` only when Gunnar asks; no co-author trailers; push only when he asks.
- This repo has no DECISIONS.md: decisions live in the Notion roadmap rows (2026-10-01 note).
- Metadata filters apply only to searches of the open index, since their field names belong to it.

## Working Set
- `OpenCone/Features/Search/SearchViewModel.swift`: `performSearch` picks `performRoutedSearch` /
  `routeAndAnswer` or `searchOpenIndex`; `streamAnswer`; `scheduleIndexSurvey`, `isDueForSurvey`,
  `surveyIndexes`, `updateIndexSummary`.
- `OpenCone/Features/Search/Routing/`: `IndexRouter.swift`, `IndexSurveyor.swift`,
  `IndexProfile.swift` (profile, store, `EmbeddingModelMatcher` with the 0.6 threshold),
  `PassageText.swift`, `IndexSummariesSheet.swift`.
- `OpenCone/Services/ResponsesClient.swift`; `OpenCone/Services/PineconeService.swift`
  (`query(index:)`, `indexStats(forIndex:)`, `host(forIndex:)`).
- `OpenConeTests/Routing/` (33 tests, stand-ins for Pinecone and OpenAI in `RoutingTestSupport.swift`).
- `CLAUDE.md` (Verify commands, simulator UDID) and this file.

## Verification
- `python3 scripts/secret_scan.py` -> "No secret patterns detected." (2026-10-01)
- `xcodebuild -project OpenCone.xcodeproj -scheme OpenCone -destination
  "id=8DBC8F9E-48CE-4D77-83C0-6AB1C349BE4D" -derivedDataPath /private/tmp/opencone-dd build`
  -> BUILD SUCCEEDED; no warnings beyond the 10 pre-existing unused `indexHost` bindings.
- `xcodebuild test` (same project, scheme, destination and DerivedData)
  `-collect-test-diagnostics never -quiet` -> xcresult summary: Passed, 126 total, 126 passed,
  0 failed, 0 skipped, on the working tree with Gunnar's prompt-cache test.
- The committed tree alone (`git checkout-index -a --prefix=/private/tmp/opencone-commit-check/`,
  then the same test command with `-derivedDataPath /private/tmp/opencone-commit-dd`) -> Passed,
  125 total, 125 passed (71 from e5e40d4, 54 new: routing 33, model settings 11, model catalog 10).
- Not verified: anything against live OpenAI or Pinecone, the 0.6 cosine threshold, the UI on a
  device.

## Blockers / Unknowns
- The closing check needs Gunnar's iPhone and his keys; no agent session has them.
- Unmeasured: real cosine values for the model check. The device log line "Index model check"
  (index, model, cosine) measures them.
- Retired models: fixed in ec09fb8 by the catalog (row "Model pickers list retired models");
  the shipped app still offers `o1`, `o3-mini` (shut down by 2026-10-23) and `o1-mini` (shut down
  2025-10-27) until a release carries this.
- Other rows opened 2026-10-01: "Answer sources showed code instead of file names" (fixed in
  ec09fb8, not released); "\"All\" namespaces searches only the default namespace"; "Move off Pinecone API
  version 2024-07"; "Non-streamed fallback can show the raw reply as the answer" (in Gunnar's
  file); trap "An index's dimension doesn't say which model built it".

## Exact Next Action
Run the live check with Gunnar's saved keys (a fresh clone of `OpenCone demo`, in a session out of Auto
mode or with a permission rule for `xcrun simctl`), or on his iPhone: install ec09fb8's
build, open Search > index menu > Index summaries and wait until every index shows "Searched with
<model>", then (a) with index A open, ask something only index B holds, and (b) ask to compare two
indexes. Pass means each answer's Sources show the right index and namespace. On a pass, set the
routing row to Completed with Evidence measured (simulator) or device_verified (iPhone).
