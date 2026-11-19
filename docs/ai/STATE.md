# Current State

Updated: 2026-11-19
Branch/worktree: `main` in the iCloud tree `~/Documents/GitHub/OpenCone`
Last verified commit: 4d3abee

## Objective
Gunnar, 2026-11-19: "also, please normalize and match my github release for this apps version.  i want this on the
app store". OpenCone 3.2 is 3.1 plus the App Store rating request (fe9d398) and the version bump (4d3abee).

## Status
Done. 3.2 is WAITING_FOR_REVIEW (submission 60bdbed2-efb9-428d-9ff5-e72f98bf80b0, 2026-11-19), build 27 attached
(Xcode Cloud run 27, commit 4d3abee, VALID, uploaded 2026-11-17), release type After Approval, so it goes live on approval.

| What | Value |
|---|---|
| What's New | `scripts/asc/listing-3.2.json` (464 characters), saved and read back |
| Review notes | `scripts/asc/review-steps-3.2.txt`: 3.1's steps plus step 6, the rating sheet and "Rate OpenCone"; the 8 credential lines kept |
| Age rating | four new questions answered No on the 3.2 app info (`socialMedia`, `socialMediaAgeRestricted`, `sharedLocation`, `datingAndRelationships`); the first submit failed with "You must provide a value for the attribute 'socialMedia'". Rating still 4+ |
| Screenshots | the 8 from 3.1, carried over by App Store Connect |
| China mainland | not sold there (`CANNOT_SELL`), so the AIGC and Security Assessment rows stay empty |
| GitHub | "Release 3.1" renamed "OpenCone 3.1" with the backfilled releases' format; tag `v3.1` moved from 04267d1 to eeec127 (run 25's commit). "OpenCone 3.2" created at 4d3abee, not marked Latest |

## Active Constraints
- Simulator `OpenCone` `C79C772B-967A-4E85-B0A8-57B420CD63F1` (created 2026-11-14; another session tested on 55AF7E43 on 2026-11-17).
  `OpenCone demo` and `OpenCone shots` were gone on 2026-11-14 and were not recreated.
- `.gitignore` has an uncommitted change that is not this work; `.claude/.state/` is untracked. Both left alone.
- A test run rewrites `OpenConeTests/Core/Settings/PineconePreferenceResolverTests.swift.plist`; restore it before committing.
- Every push to `main` without `[ci skip]` starts an Xcode Cloud archive. Push, ship and submit only at Gunnar's word.

## Verification
- `zsh -ic 'python3 scripts/asc/release.py submit --go'` -> "submission 60bdbed2-... is WAITING_FOR_REVIEW; version 3.2 is WAITING_FOR_REVIEW".
- `release.py notes ... --go` -> "saved: kept credential lines intact (1596 characters)"; `attach 27 --go` -> "attached: 27".
- Tests for the rating request: 217 passed, 0 failed (2026-11-14, simulator C79C772B); TEST SUCCEEDED (2026-11-17, 55AF7E43).
- `gh release list` shows OpenCone 1.0, 2.0, 2.2, 3, 3.1 (Latest), 3.2; `git ls-remote --tags` has v3.1 at eeec127 and v3.2 at 4d3abee.

## Blockers / Unknowns
- The rating sheet itself has not been seen on a device.
- Unchanged from before: chunk size/overlap unwired; Pinecone control/data planes on 2024-07; unused `fetchVectors`.

## Exact Next Action
When `release.py status` says 3.2 is READY_FOR_SALE: `gh release edit v3.2 -R Gunnarguy/OpenCone --latest`, change the
release's first line to "Released <date>.", and update README.md ("The App Store has version 3.1") and CLAUDE.md.
