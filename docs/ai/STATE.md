# Current State

Updated: 2026-10-01
Branch/worktree: `main` in the iCloud tree `~/Documents/GitHub/OpenCone`; HEAD = origin/main
Last verified commit: d8f5d8b (the UI overhaul below was verified on the working tree, then committed after it at Gunnar's request)

## Objective
Gunnar, 2026-10-01: the app "needs a slight overhaul because its not formatting responses correctly, its kind of
clunky, its ugly, and doesnt have much intuitive control when it comes to Indexes/Namespaces/Model
selection/customization ... make it look more like OpenResponses". Mid-session he added a broad net ("all that exists
in one's pinecone project ID") beside smaller nets ("per index namespaces"). The earlier routing objective still needs
its live check (Blockers).

## Status
Overhaul built (Debug and Release) and tested on the simulator, then committed to `main` and pushed on 2026-10-01 at
Gunnar's request ("commit and push it, build it to my iphone"), in the commit after d8f5d8b. A reviewer agent was still
reviewing the change at the commit; its findings were not yet read or applied.

## Completed (committed after d8f5d8b)
- Answers render Markdown: `Features/Search/Components/MarkdownText.swift` (own block parser for headings, nested
  lists, task items, tables, quotes, rules, code fences that may still be open while streaming; inline through
  AttributedString). `[S2]` tags become `opencone-source://` links that open that passage.
- Each answer keeps its passages (`ChatMessage.sources`), tagged by `PassageText.taggedContext`; the one-index path
  now tags passages and adds `PassageText.citeInstructions` to the system prompt.
- Ask screen in OpenResponses' layout: `SearchView.swift` (rewritten), `Components/ChatStatusBar.swift` (model menu,
  effort, tool badges, gear), `MessageBubble.swift` (bubbles, source chips, copy/share/retry), `ChatComposer.swift`,
  `AnswerSettingsViews.swift` (Choose Model list ported from OpenResponses, `AnswerSettingsForm`),
  `AnswerSourcesViews.swift`, `SearchScopeViews.swift` (scope bar, Where to search sheet, `IndexDetailView`,
  metadata filters), `CodeInterpreterOutputsView.swift`.
- Three search widths (`SearchScope` in `Core/AppSettingsModels.swift`, key `search.scope`; the old
  `search.indexRoutingEnabled` bool is still written and migrates): Auto = existing routing; Everything =
  `SearchViewModel.searchEverything` (every namespace of every included index, max 20 searches taken in turns across
  indexes, merged by rank then score, one rerank when on); One index = `searchOpenIndex`, whose "all namespaces" now
  searches each namespace (`searchNamespaces`, the 10 largest) instead of only the default one. "All namespaces" is
  remembered per index under `search.allNamespaces.<index>`. Indexes can be left out (`setIndex(_:included:)`,
  `IndexCatalogStore.saveExcluded`). One-index questions are embedded with the index's surveyed model when known.
- Stop: every search path runs in `routingTask`, so Stop cancels searches too; it leaves a retryable "Stopped" answer.
  `retryLastAnswer()` re-asks the last question.
- Settings (`Features/Settings/SettingsView.swift`, rewritten): General / Answers / Advanced tabs. Removed controls that
  changed nothing (similarity threshold, context window, streaming toggle, timeouts, retries, batch size, verbose and
  debug toggles, max turns, chunk size and overlap, Pinecone cloud and region, theme picker). Removed the 2 s auto-save
  cooldown that dropped changes; `persistRequestSettings()` runs before every search; `selectCompletionModel` clears
  the old custom-model override. The log moved to Settings > Advanced > Activity log; tabs are Ask, Documents, Settings.
- Theme follows the system light/dark setting (`OCTheme.system`); no forced color scheme.
- Deleted dead files: old chat views, `IndexSummariesSheet`, `DocumentsView`, `DocumentRow`, theme and demo settings
  views, `SettingsNavigationRow`, `SecureSettingsField` (staged as deletions by `git rm`).
- `App/DemoMode.swift`: DEBUG-only `-OpenConeDemo [-OpenConeDemoScreen empty|scope|scope-one|answer-settings|models|
  sources|passage|settings]` opens sample content with no keys and no requests, for screenshots.
- Docs updated: README, ARCHITECTURE, PRIVACY (log and reset locations, Auto/Everything), CLAUDE.md code map.

## Active Constraints
- Build and test only on simulator `OpenCone` `8DBC8F9E-48CE-4D77-83C0-6AB1C349BE4D`. Never on `OpenCone demo`
  (`5D5E8E61-...`), which holds Gunnar's keys.
- Run `pgrep -x xcodebuild` first; another session (OpenResponses UI tests) built repeatedly on 2026-10-01.
- Every test run rewrites `OpenConeTests/Core/Settings/PineconePreferenceResolverTests.swift.plist` (the test uses
  `UserDefaults(suiteName: #file)`); restore it with `gtimeout 60 git checkout -- <that file>` before committing.
- Commit to `main` only when Gunnar asks; no co-author trailers; push only when he asks.

## Working Set
- `OpenCone/Features/Search/SearchViewModel.swift`: `performSearch`, `searchOpenIndex`, `searchNamespaces`,
  `searchEverything`, `broadSearchRequests`, `mergedAcrossSearches`, `routeAndAnswer`, `cancelActiveSearch`,
  `retryLastAnswer`, `setNamespace`, `namespacesToSearch`, `setIndex(_:included:)`.
- `OpenCone/Features/Settings/SettingsViewModel.swift`: `searchScope`, `persistRequestSettings`, `resetAnswerSettings`.
- The new view files listed above; `OpenConeTests/Search/` (MarkdownParserTests 15, SearchScopeTests 15).

## Verification
- `xcodebuild -project OpenCone.xcodeproj -scheme OpenCone -destination "id=8DBC8F9E-48CE-4D77-83C0-6AB1C349BE4D"
  -derivedDataPath /private/tmp/opencone-dd build` -> `** BUILD SUCCEEDED **`, no warnings beyond the 10 old
  `indexHost` ones.
- `xcodebuild test` (same project, scheme, destination, DerivedData) `-collect-test-diagnostics never -quiet` ->
  xcresult summary `{'result': 'Passed', 'totalTestCount': 157, 'passedTests': 157, 'failedTests': 0}` (2026-10-01).
- Release: `xcodebuild ... -configuration Release -destination "generic/platform=iOS Simulator" -derivedDataPath
  /private/tmp/opencone-release-dd build CODE_SIGNING_ALLOWED=NO` -> `** BUILD SUCCEEDED **`; `strings` on the binary
  finds 0 matches for the demo text "Baxter Sigma".
- `python3 scripts/secret_scan.py` -> "No secret patterns detected."
- Demo screenshots (simctl, light, dark, accessibility-large) checked: answer with table, list, quote, code block and
  source chips; empty state; Where to search in Auto and One index; answer settings; Choose Model; sources; passage;
  Settings.
- Not verified: anything against live OpenAI or Pinecone; the UI on a device; VoiceOver.

## Blockers / Unknowns
- Reviewer findings: unread at the commit. If this session ended first, run a fresh `reviewer` agent over
  `gtimeout 60 git diff d8f5d8b` with the change list above, and fix what it confirms.
- Notion roadmap not yet updated for this work (IDs in `.claude/skills/notion-roadmap/SKILL.md`): set
  "\"All\" namespaces searches only the default namespace" and "Remove the orphaned DocumentsView.swift" to fixed;
  repoint "Answer sources showed code instead of file names" `Where` to `Components/MessageBubble.swift`; add rows for
  the Ask screen overhaul, the Everything width, the dropped auto-save changes and Stop during search, and a To Do Fix
  "Chunk size, overlap, cloud and region settings never reach uploads" (`TextProcessorService` uses
  `Configuration` constants; `DocumentsViewModel.createIndex` reads `pinecone.cloud`/`pinecone.region`, keys nothing
  writes).
- Routing live check still open: needs Gunnar's iPhone with 2+ indexes or namespaces (his project had one index,
  "test", 109 vectors, one namespace). The 0.6 model-match threshold is unmeasured.

## Exact Next Action
Apply the reviewer's confirmed findings (or run the review as above), rerun the `xcodebuild test` command above and
restore the test plist, then update the Notion rows listed under Blockers. Commit and push the fixes and rebuild to
Gunnar's iPhone only when he asks, with the commands in CLAUDE.md `## Ship`.
