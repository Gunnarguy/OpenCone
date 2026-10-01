# Current State

Updated: 2026-10-01
Branch/worktree: `main` in the iCloud tree `~/Documents/GitHub/OpenCone`; HEAD 9c9578c = origin/main
Last verified commit: 9c9578c

## Objective
Gunnar, 2026-10-01: "answer length, 32k? thats not right lol. please update the settings tab as well... make this
whole app just look crazy good and ensure every single endpoint is properly accounted for, displayed, and customizable
thats relevant", then "There's no off for the 6.1 sol reasoning. Ensure that's correct and that parameters dynamically
adjust and show based off of whichever model is selected. Keep it going". His standing flow: commit, push, build to his iPhone.

## Status
Done and shipped: 9c9578c committed, pushed, installed on "Gunnar's Hand Extension" (iPhone 16 Pro Max,
`00008140-001130DA1863C01C`). Launch failed only because the phone was locked (`BSErrorCodeDescription = Locked`);
`devicectl device info apps` lists OpenCone 3.1 (5). Nothing in it has run against live OpenAI or Pinecone yet.
Earlier commits this session, also on his phone: 807f7cc (Ask overhaul), 5242fda (review fixes), b36add9 (Documents).

## Completed in 9c9578c
- Per-model answer settings (`Core/Models/ModelLimits.swift`, `Features/Search/AnswerSettingsViews.swift`): longest
  answer up to the model's maximum (128,000 GPT-5/6, 32,768 GPT-4.1, 16,384 GPT-4o), default 16,000, a stored old 4,000
  raised once (`SettingsViewModel.answerLengthRaisedKey`); effort list per model (gpt-6.1-sol: low...max, its page says
  none/minimal unsupported); temperature/top P only without reasoning; verbosity GPT-5+; service tiers per OpenAI's
  pricing page (clamped to Auto); code interpreter absent on gpt-5.4-pro/gpt-5.2-pro; fine-tunes read as their base.
- Request options (`Core/RequestSettings.swift`, `OpenAIService.applyAnswerSettings`, `webSearchTool`): verbosity,
  service_tier, web search context size (left out at medium) and allowed domains; no `truncation`.
- Memory: always sends earlier exchanges from the phone (`SearchViewModel.conversationHistory(before:)`,
  `OpenAIService.historyToSend`, plain-string content, trimmed to the window by UTF-8 bytes / 3, in pairs); 0...20,
  default 4. The old server mode never sent history; conversation-id code removed.
- Endpoints (`Core/Networking/APIActivity.swift`, `Features/Settings/EndpointsView.swift`): 17 endpoints, recorded by a
  per-task delegate on all 27 URLSession calls (test proves a streamed request is recorded).
- Pinecone: new indexes use Settings' cloud, region, metric (`pinecone.metric`); serverless region list; invalid saved
  or imported regions corrected and stored; `PineconeAPIVersions`; a stored namespace version below 2025-10 reads as
  2025-10. Documents' New index alert names where the index will be made.
- Review: a reviewer agent's 10 findings were applied (footer facts, import normalization, code interpreter heuristic,
  namespace version, web search default, demo guard on Check now, fine-tunes, pair trimming, comments, 4,000 default).
- Docs: README, ARCHITECTURE, PRIVACY. Notion rows (IDs in `.claude/skills/notion-roadmap/SKILL.md`): "Conversation memory
  never reached OpenAI", "Answer settings follow the selected model", "Every endpoint listed, with its settings and
  requests", "Documents tab in the app's style" (all In Progress, close on a device check), "Streamed answers were
  written twice" (Completed), Trap "OpenAI's truncation: auto would drop the passages"; notes on three older rows.

## Active Constraints
- Simulator `OpenCone` `8DBC8F9E-48CE-4D77-83C0-6AB1C349BE4D` only; never `OpenCone demo` (holds Gunnar's keys). It
  shuts down after a test run: `xcrun simctl boot` it before installing.
- `pgrep -x xcodebuild` first. Test runs rewrite `OpenConeTests/Core/Settings/PineconePreferenceResolverTests.swift.plist`:
  `gtimeout 60 git checkout --` it before committing.
- Simulator-tool screenshots lag a frame; use `xcrun simctl io <udid> screenshot` after a 2 s wait.
- `CLAUDE.md` is stale in two places, left for Gunnar: its Rules still call the prompt-cache work in OpenAIService
  uncommitted (it is in 7105807), and its code map lacks ModelLimits, RequestSettings, APIActivity, EndpointsView.
- Commit to `main`, no co-author trailers; push and ship when Gunnar asks.

## Verification
- `xcodebuild test -project OpenCone.xcodeproj -scheme OpenCone -destination "id=8DBC8F9E-48CE-4D77-83C0-6AB1C349BE4D"
  -derivedDataPath /private/tmp/opencone-dd -quiet -collect-test-diagnostics never -resultBundlePath <path>` ->
  `{'result': 'Passed', 'totalTestCount': 205, 'passedTests': 205, 'failedTests': 0, 'skippedTests': 0}`.
- `python3 scripts/secret_scan.py` -> "No secret patterns detected."; no `* 2.*` conflict copies.
- Ship build from `git checkout-index` in `/private/tmp/opencone-ship-9c9578c` -> `** BUILD SUCCEEDED **`, signed
  "Apple Development: Gunnar Hostetler"; `devicectl device install app` succeeded; launch -> Locked.
- Simulator demo screenshots: Settings General, Answers for gpt-6-sol, gpt-6.1-sol, gpt-5.2-pro, gpt-4o; Advanced; Endpoints.
- Docs read 2026-10-01: OpenAI create-response reference, Flex and Fast guides, pricing page, 20 model pages; Pinecone
  versioning page, 2025 and 2026 changelogs, "Create an index" regions table.

## Blockers / Unknowns
- Live behavior unverified: plain-string history accepted by the Responses API; Flex/Fast accepted for the selected
  model; a 900 s `timeoutInterval` on `URLSession.shared`; Endpoints filling with real requests.
- Still open: chunk size/overlap never reach the chunker (Notion row To Do); Pinecone control/data planes send 2024-07
  (latest stable 2026-07); unused `fetchVectors`/`fetchVectorsByMetadata` (a task chip was offered).

## Exact Next Action
With Gunnar's iPhone unlocked, run `xcrun devicectl device process launch --terminate-existing --console --device
00008140-001130DA1863C01C AI.FascinAIting.OpenCone`, have him ask a question and then a follow-up that depends on the
first answer, and read the log for the Responses request's status; then check Settings > Advanced > Endpoints shows
those calls. Mark the four In Progress Notion rows from this session by what that shows.
