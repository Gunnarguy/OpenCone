# Current State

Updated: 2026-11-14
Branch/worktree: `main` in the iCloud tree `~/Documents/GitHub/OpenCone`; HEAD 1acafb1 = the last commit before this work
Last verified commit: 1acafb1

## Objective
From Gunnar's OpenIntelligence session, 2026-11-14: add Apple's system rating request to OpenCone, on
OpenIntelligence's pattern (`ReviewPromptService`), with a "Rate OpenCone" link in Settings and unit tests.
On 2026-11-14 OpenCone had 200 first-time downloads and 1 US rating, and the app never asked.
Commit locally; do not push, submit or open a PR.

## Status
Done and committed locally on `main`, not pushed (the commit after 1acafb1, "Rating request"). Built and tested
on the working tree that was committed. The version in the project is still 3.1, which is live (build 25, since
2026-10-02); the rating request reaches people only in a new version, and choosing its number is Gunnar's.

## What the change does
| Rule | Value |
|---|---|
| Asks on | the first finished answer written from passages of the person's own index, or the third finished answer of any kind |
| Counts as finished | the answer's status is `.normal` and it has text; failed, empty and stopped answers are not counted |
| Per version | once (`reviewPrompt.lastAskedVersion` in UserDefaults) |
| Between asks | at least 14 days (`reviewPrompt.lastAskedAt`) |
| Never | under XCTest, in `-OpenConeDemo`, at launch, from a button |
| Timing | 2 s after the answer ends, only while the scene is active and no answer is being written; otherwise held and made on the return to the foreground or when that answer ends |
| "Asked" recorded | only after `requestReview()` was called (`didAsk`) |

- `OpenCone/App/ReviewPromptService.swift` (new): counts, the pure `shouldAsk`, `wantsPrompt`, `didAsk`.
- `OpenCone/Features/Search/SearchViewModel.swift`: `noteFinishedAnswer`, called where `streamAnswer` ends an
  answer (the stream's `onCompleted` and the watchdog's non-streamed fallback).
- `OpenCone/App/MainView.swift`: `@Environment(\.requestReview)`, `askForRatingWhenInFront`, three `onChange`.
- `OpenCone/Features/Settings/SettingsView.swift`: "Rate OpenCone" in General, About, opening
  `https://apps.apple.com/app/id6744467668?action=write-review` (the id is `APP` in `scripts/asc/release.py`).
- `OpenConeTests/Core/ReviewPromptServiceTests.swift` (new): 7 tests of `shouldAsk` and of counting nothing under tests.
- `CLAUDE.md`: code map row and the new simulator UDID.
- API read in the iOS 27.0 SDK on this Mac, `_StoreKit_SwiftUI.swiftinterface` lines 523 to 536 [code_verified]:
  `RequestReviewAction`, iOS 16.0 and later, `@MainActor func callAsFunction()`, `EnvironmentValues.requestReview`.

## Active Constraints
- Simulators: on 2026-11-14 `xcrun simctl list devices` showed no OpenCone simulator: `OpenCone` `8DBC8F9E-...`,
  `OpenCone shots` `C606236C-...` and `OpenCone demo` (Gunnar's keys) were all gone [measured]. A new `OpenCone`
  `C79C772B-967A-4E85-B0A8-57B420CD63F1` (iPhone 18 Pro, iOS 27.0) was created for build and test. `OpenCone demo`
  and `OpenCone shots` were not recreated: the demo one needs keys Gunnar types in himself.
- `.gitignore` had an uncommitted change before this session (it ignores `/AGENTS.md`, `/.agents/`, `/.codex/`);
  it is not this session's and is left uncommitted. `.claude/.state/` is untracked and left alone.
- A test run rewrites `OpenConeTests/Core/Settings/PineconePreferenceResolverTests.swift.plist`;
  `gtimeout 60 git checkout --` it before committing.
- Every push to `main` starts an Xcode Cloud archive and uploads a build. Commit to `main`, no co-author
  trailers; push, ship and submit only when Gunnar asks.

## Verification
All on 2026-11-14, simulator `C79C772B-967A-4E85-B0A8-57B420CD63F1`, DerivedData `/private/tmp/opencone-dd`.
- `xcodebuild -project OpenCone.xcodeproj -scheme OpenCone -destination "id=C79C772B-..." -derivedDataPath
  /private/tmp/opencone-dd build` -> `** BUILD SUCCEEDED **`, exit 0, no error lines [build_verified].
- `xcodebuild test ... -collect-test-diagnostics never -resultBundlePath <path>` -> `** TEST SUCCEEDED **`; the
  `.xcresult` summary: 217 passed, 0 failed, 0 skipped (210 before, plus the 7 in `ReviewPromptServiceTests`,
  each listed as passed in the log) [test_verified].
- `python3 scripts/secret_scan.py` -> "No secret patterns detected."

## Blockers / Unknowns
- The rating sheet itself was not seen. It shows in a development build, so the check is on a device or the
  simulator with real keys: ask one question that returns passages, wait 2 s.
- From before, unchanged: the `v3.1` tag points at 04267d1, not eeec127; chunk size/overlap unwired; Pinecone
  control/data planes on 2024-07; unused `fetchVectors`/`fetchVectorsByMetadata`.

## Exact Next Action
Gunnar's: see the sheet once in a development build (ship to the iPhone with the commands in `CLAUDE.md`, ask one
question that returns passages, wait 2 seconds), then decide the next version number and push when ready.
