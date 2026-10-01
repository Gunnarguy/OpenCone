# Current State

Updated: 2026-10-01
Branch/worktree: `main` in the iCloud tree `~/Documents/GitHub/OpenCone`; HEAD eeec127 = origin/main
Last verified commit: eeec127

## Objective
Gunnar, 2026-10-01: "yes update claude.md too. take the proper screenshots of this app, update the ASC
metadata on all fronts, then push to review". Mid-way he reported two bugs from his iPhone: an answer's
table drew wrapped text over its own rows, and a document's row in Documents didn't change after indexing.

## Status
Done. OpenCone 3.1 is WAITING_FOR_REVIEW in App Store Connect: build 25 (Xcode Cloud run 25, commit
eeec127), submission `b6070ea6-f4e9-4d60-ae1e-02f9ddb4e477`, release type After Approval (it goes live on
approval, as every earlier version did). eeec127 is also installed and launched on Gunnar's iPhone
("Gunnar's Hand Extension", `00008140-001130DA1863C01C`). There is no active objective after this.

## Completed
- Fixes in eeec127: `MarkdownTableView` gives each column one measured width (56 to 240 points, narrowed
  to fit the answer) so wrapped cells grow their row; `DocumentModel ==` compares state, not only id, so
  an indexed document's row redraws (the id alone is still hashed).
- Demo content is an invented café's equipment manuals (no real brands); new demo screens `answer`,
  `long-table`, `documents-indexing` (`App/DemoMode.swift`).
- `scripts/appstore_screenshots.py` (captions, 1320 x 2868, no alpha) and `scripts/asc/release.py`
  (status, listing, notes, shots, attach, submit; dry run without `--go`); `scripts/asc/listing-3.1.json`,
  `scripts/asc/review-steps-3.1.txt`.
- App Store Connect, all read back: subtitle "RAG chat for your Pinecone", description (2,433 chars),
  keywords, promotional text, What's New, URLs, copyright 2026; review steps replaced below the
  reviewer's credential lines, which were kept and never printed; 8 new screenshots in `APP_IPHONE_67`
  replacing 9 from 2025; build 25 attached; submitted.
- `CLAUDE.md` (code map, release steps, prompt-cache rule, shots simulator), `APP_STORE.md` rewritten.
- Notion (IDs in `.claude/skills/notion-roadmap/SKILL.md`): "OpenCone 3.1" In Progress with the
  submission note; new Completed rows "Answer tables overlapped their own rows" and "An indexed document's
  row kept its old status"; 13 of today's rows moved to Target Release v3.1.

## Active Constraints
- Simulators: `OpenCone` `8DBC8F9E-...` for build and test; `OpenCone shots` `C606236C-157D-49D5-A378-AF37A5504B9C`
  for store screenshots; never `OpenCone demo` (Gunnar's keys).
- A test run shuts `OpenCone` down and rewrites `OpenConeTests/Core/Settings/PineconePreferenceResolverTests.swift.plist`;
  boot it before installing, `gtimeout 60 git checkout --` the plist before committing.
- Every push to `main` starts an Xcode Cloud archive and uploads a build; that is how builds reach App Store Connect.
- Commit to `main`, no co-author trailers; push, ship and submit when Gunnar asks.

## Verification
- `xcodebuild test ... -destination "id=8DBC8F9E-48CE-4D77-83C0-6AB1C349BE4D" -derivedDataPath /private/tmp/opencone-dd
  -quiet -collect-test-diagnostics never -resultBundlePath <path>` -> 210 passed, 0 failed, 0 skipped (eeec127's tree).
- `python3 scripts/secret_scan.py` -> "No secret patterns detected."
- Documents fix measured on the simulator (`-OpenConeDemoScreen documents-indexing`): old equality left the row
  "not indexed yet" while the button counted it; new equality turned it green. Table fix seen with `long-table`.
- `release.py` outputs read: listing saved and read back; notes "kept credential lines intact"; all 8
  screenshots COMPLETE and ordered; "attached: 25"; "submission b6070ea6-... is WAITING_FOR_REVIEW".
- iPhone: build succeeded from `git checkout-index` of eeec127; "App installed"; "Launched application".

## Blockers / Unknowns
- The reviewer's OpenAI and Pinecone keys in the review notes are from an earlier submission and were not
  tested; if Apple reports it can't sign in or search, Gunnar updates them in App Store Connect.
- The `v3.1` git tag points at 04267d1, not eeec127; moving it is Gunnar's call.
- Still open on the roadmap: chunk size/overlap unwired; Pinecone control/data planes on 2024-07; unused
  `fetchVectors`/`fetchVectorsByMetadata` (task chip offered).

## Exact Next Action
None. The objective is complete: 3.1 is waiting for review. Check it with
`zsh -ic 'python3 scripts/asc/release.py status'`; on approval mark the Notion "OpenCone 3.1" row Completed
and add `v3.2` as a Target Release option (the skill has the command). Otherwise ask Gunnar what to pick up.
