# OpenCone: agent brief

OpenCone is Gunnar's second App Store app (id 6744467668): an iPhone RAG client that runs on the
person's own OpenAI and Pinecone keys. Documents are read and chunked on the phone, embedded with
OpenAI, stored and searched in the person's own Pinecone index, and answered through OpenAI's
Responses API with citations. Version 3 is live (since 2026-06-20). 3.1 is `MARKETING_VERSION` and
the version open in App Store Connect; `scripts/asc/release.py status` shows where it stands. The `v3.1`
git tag points at 04267d1, older than what 3.1 ships.

## Start here

1. `docs/ai/STATE.md`: where the reboot stands and the exact next action.
2. The Notion roadmap, through `.claude/skills/notion-roadmap/SKILL.md` (its IDs are there; never
   search the workspace for it). Read the Trap rows before touching search, Pinecone or the OpenAI
   request, and the Decision rows before proposing anything.
3. `README.md`, `ARCHITECTURE.md` and `ROADMAP.md` for detail.

## The reboot (2026-09-30)

The first feature: ask once, and OpenCone works out which index to search, or several, including a
compare-and-contrast across two indexes or namespaces. The design and its closing conditions are in
the roadmap row "Route each question to the index that has the answer". It works on the indexes
people already have, with their OpenAI embeddings and nothing re-embedded, through a function tool
the app runs itself. Not Pinecone's MCP: the trap row "Pinecone's MCP servers can't be the phone's
search tool yet" says why. Gunnar's call (2026-10-01, "go nuts"): the app drafts each index's
one-line summary from its passages, and the person can rewrite it. Built 2026-10-01 and unit-tested;
the closing check on a device is still open.

## Code map

| Where | What |
|---|---|
| `OpenCone/Services/OpenAIService.swift` | Responses API requests: the options from `RequestSettings` held to the model, the tools array (`web_search`, `code_interpreter`), the earlier exchanges (`historyToSend`) |
| `OpenCone/Core/RequestSettings.swift`, `OpenCone/Core/Models/ModelLimits.swift` | What each request sends (verbosity, service tier, web search options, earlier exchanges) and what each model accepts (output and context limits, verbosity, service tiers from OpenAI's pricing page, code interpreter), read from OpenAI's docs 2026-10-01 |
| `OpenCone/Core/Networking/APIActivity.swift`, `OpenCone/Features/Settings/` | Every endpoint the app calls, recorded by a per-request URLSession delegate; Settings (General, Answers, Advanced) and its Endpoints screen |
| `OpenCone/Services/ResponsesClient.swift` | Non-streamed Responses calls: the routing call and summary drafts |
| `OpenCone/Services/PineconeService.swift` | Indexes and namespaces, `query`, `hybridQuery`, the per-index host cache (`indexHostCache`); `query(index:)` and `indexStats(forIndex:)` reach any index without moving `currentIndex` |
| `OpenCone/Features/Search/SearchViewModel.swift` | The search: `performSearch` runs one cancellable task that picks, by `SearchScope`, `routeAndAnswer` (Auto), `searchEverything` (Everything) or `searchOpenIndex` (One index, with `searchNamespaces` for all namespaces); all stream through `streamAnswer` |
| `OpenCone/Features/Search/Routing/` | `IndexRouter` (the `search_index` tool, call checks, cap 5), `IndexSurveyor` (namespaces, model check, summary draft), `IndexProfile` and its store (with left-out indexes), `PassageText` (passage text and `[S#]` tagging) |
| `OpenCone/Features/Search/SearchView.swift`, `Components/`, `SearchScopeViews.swift`, `AnswerSourcesViews.swift`, `AnswerSettingsViews.swift` | The Ask screen in OpenResponses' layout (2026-10-01): status bar, where to search, Markdown answers (`MarkdownText`), sources, composer, model picker, answer settings |
| `OpenCone/App/DemoMode.swift` | Debug-only `-OpenConeDemo` launch argument: sample indexes and conversation (an invented café's equipment manuals, no real brands), no keys, no requests; `-OpenConeDemoScreen <name>` opens one screen (the list is in the file). For screenshots |
| `OpenCone/Features/Documents/` | Import, extraction, chunking, upsert; `DocumentsView` (the tab) and `DocumentDetailsView` |
| `scripts/appstore_screenshots.py`, `scripts/asc/` | App Store screenshots (captions in the script) and the release steps: listing, review notes, screenshots, attach, submit |
| `OpenCone/Core/Models/`, `OpenCone/Resources/ModelCatalog/ModelCatalog.json` | The model catalog ported from OpenResponses (2026-10-01): default model, menu, reasoning efforts, retired models; `docs/model-catalog.md`. Keep the JSON identical to OpenResponses' apart from its notes line |
| `OpenCone/Core/Configuration/`, `OpenCone/Core/Security/SecureSettingsStore.swift` | Preferences, and the keys in the Keychain |
| `OpenConeTests/` | Unit tests |

## This Mac

- The repo is in iCloud (`~/Documents`). Wrap git in `gtimeout 60`. Before debugging a strange
  build, look for conflict copies: `find . -name "* 2.*" -not -path "./.git/*"`.
- Build with a DerivedData path outside iCloud, one build at a time: run `pgrep -x xcodebuild`
  first, since other sessions build on this Mac too, and it has 18 GB of RAM. If codesign fails
  with "resource fork, Finder information, or similar detritus", build from a copy of the tree in
  `/private/tmp`.
- Simulators are shared between sessions and get deleted. Use your own: `xcrun simctl list devices
  | grep " OpenCone ("`, and if it's missing, `xcrun simctl create "OpenCone" "iPhone 18 Pro"
  com.apple.CoreSimulator.SimRuntime.iOS-27-0` (only the iOS 27 runtime is installed). Write its
  UDID here. Current: `OpenCone` `8DBC8F9E-48CE-4D77-83C0-6AB1C349BE4D` (iPhone 18 Pro, iOS 27.0,
  created 2026-10-01). Never build or test on `OpenCone demo` (`5D5E8E61-...`): it holds Gunnar's
  own API keys, and erasing it drops them. A test run leaves `OpenCone` shut down; boot it with
  `xcrun simctl boot` before installing. App Store screenshots use `OpenCone shots`
  `C606236C-157D-49D5-A378-AF37A5504B9C` (iPhone 18 Pro Max, the 6.9-inch size, created 2026-10-01).
- The README's commands name an "iPhone 16" simulator, which doesn't exist here, and
  `scripts/preflight_check.sh` picks any available iPhone, which can be another session's.
- `~/.agents/MACHINE-MAP.md` has the rest: paths, credentials by location, what runs on its own.

## Verify

```bash
python3 scripts/secret_scan.py
xcodebuild -project OpenCone.xcodeproj -scheme OpenCone -destination "id=<OpenCone simulator UDID>" -derivedDataPath /private/tmp/opencone-dd build
xcodebuild test -project OpenCone.xcodeproj -scheme OpenCone -destination "id=<OpenCone simulator UDID>" -derivedDataPath /private/tmp/opencone-dd -quiet
```

First run 2026-10-01 on `8DBC8F9E-48CE-4D77-83C0-6AB1C349BE4D`, with Gunnar's uncommitted
prompt-cache work in the tree: secret scan clean; build succeeded in 26 s from the iCloud tree (no
codesign trouble with DerivedData in `/private/tmp`); tests 72 passed, 0 failed, 0 skipped (the
`.xcresult` summary), about 74 s. The build has 10 distinct compiler warnings, all unused
`indexHost` bindings in `PineconeService.swift`.

With routing (2026-10-01): build succeeded, no new warnings; tests 105 passed, 0 failed, 0 skipped,
60 s. With the model catalog from OpenResponses (same day): tests 126 passed, 0 failed, 0 skipped. Add `-collect-test-diagnostics never` to the test command: when a test fails, xcodebuild
otherwise waits 600 s collecting diagnostics from the simulator clone, and on 2026-10-01 the
session's shell stopped answering while it did. After the Settings pass and the table and Documents
fixes (same day): tests 210 passed, 0 failed, 0 skipped. Every test run rewrites
`OpenConeTests/Core/Settings/PineconePreferenceResolverTests.swift.plist`; restore it with
`gtimeout 60 git checkout --` before committing.

## Ship

To Gunnar's iPhone (verified 2026-10-01: "Gunnar's Hand Extension", iPhone 16 Pro Max). This builds
exactly what is committed, from a copy outside iCloud, and replaces the App Store copy on the phone
with a debug build (same bundle ID and team; the next App Store update puts the store version back).

```bash
xcrun devicectl list devices    # the iPhone's UDID
SHIP=/private/tmp/opencone-ship-$(git rev-parse --short HEAD)
git checkout-index -a -f --prefix="$SHIP/"
cd "$SHIP" && xcodebuild -project OpenCone.xcodeproj -scheme OpenCone -destination 'id=<UDID>' -allowProvisioningUpdates -derivedDataPath /private/tmp/opencone-device-dd build
xcrun devicectl device install app --device <UDID> /private/tmp/opencone-device-dd/Build/Products/Debug-iphoneos/OpenCone.app
xcrun devicectl device process launch --terminate-existing --device <UDID> AI.FascinAIting.OpenCone
```

First run 2026-10-01 at 7105807: build 28 s, signed "Apple Development" with the team provisioning
profile; install printed the bundle ID and its installation URL; launch printed "Launched application
with AI.FascinAIting.OpenCone bundle identifier". Add `--console` to the launch to read the app's log
(the Logger prints every line), including the index survey's "Index model check" scores.

## App Store

Xcode Cloud's "Default" workflow archives every push to `main` and uploads build N for run N to App
Store Connect. The release steps run through `zsh -ic` (the key variables are in `~/.zshrc`); each
change is a dry run until `--go`:

```bash
zsh -ic 'python3 scripts/asc/release.py status'
zsh -ic 'python3 scripts/asc/release.py listing scripts/asc/listing-3.1.json --go'
zsh -ic 'python3 scripts/asc/release.py notes scripts/asc/review-steps-3.1.txt --go'
zsh -ic 'python3 scripts/asc/release.py shots fastlane/screenshots/en-US --go'
zsh -ic 'python3 scripts/asc/release.py attach <build> --go'
zsh -ic 'python3 scripts/asc/release.py submit --go'
```

Screenshots: capture each demo screen on `OpenCone shots` with the status bar overridden (9:41, full
battery), then `python3 scripts/appstore_screenshots.py <raw dir> fastlane/screenshots/en-US`
(1320 x 2868, no alpha; the output folder is gitignored). Captions say only what the screen shows and
no price words: App Review rejected OpenManual 1.4 under guideline 2.3.7 for "free". The review notes
in App Store Connect hold the reviewer's OpenAI and Pinecone keys; `notes` keeps those lines and never
prints them.

## Rules

- Work on `main`: no branches, no Claude co-author trailers, push only when Gunnar asks.
- Never copy an API key, the App Store Connect key ID or issuer, or `.p8` contents anywhere.
- `OpenCone/Services/OpenAIService.swift` holds Gunnar's prompt-cache work (`promptCacheKey`,
  `logPromptCacheUsage`), committed in 7105807; its roadmap row tracks finishing it. Keep the system
  message with the instructions and passages first in `input`: the cache key covers that prefix.
- Apple, OpenAI and Pinecone APIs change. Read the current docs, or the SDK's `.swiftinterface`,
  before using one, and cite what you read.
