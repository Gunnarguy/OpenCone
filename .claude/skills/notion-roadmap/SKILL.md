---
name: notion-roadmap
description: Read or update the OpenCone roadmap in Notion, which holds the status of every plan, open fix, release, decision and trap for this app. Use whenever the user asks what is planned, next, in progress or left, what the backlog or priorities are, or mentions the roadmap or the reboot; when a task starts or finishes work that a row tracks; and before proposing a feature, because Won't Do and Decision rows record what was already decided.
---

# Notion roadmap

The Notion database holds the status: what shipped in which version, what is open, what waits on
Gunnar, and the decisions and traps behind all of it. The repo stays the source of truth for detail
(`README.md`, `ARCHITECTURE.md`, `ROADMAP.md`, `.github/copilot-instructions.md`), and each row's
`Where` names the file to open first. Never answer a roadmap question from memory; query the database.

Created 2026-09-30 for the OpenCone reboot, modelled on the OpenManual roadmap (itself built from the
OpenIntelligence and ASCDash roadmaps). OpenIntelligence's `Shipped On` and `Target OS` columns are
left out: OpenCone ships on iPhone only.

## Identifiers, hardcoded on purpose

```text
page        3eb49a74-d54f-810e-ac49-fbd36321bb42   "OpenCone - Roadmap"
database    c2f56131-efc2-484a-81dc-1b25c599d3fb
datasource  collection://6ada2feb-7308-4574-ae8a-91e32d901557
```

Query tools take the **data source** URL; `notion-fetch` takes any of the three.

**Never locate this database by workspace search.** The workspace also holds the OpenIntelligence,
OpenManual, ASCDash and OpenCore roadmaps, with overlapping Status and Priority values. A `Component`
outside the list below means you are reading the wrong database. Discard the result and say so.

## Reading

`notion-query-data-sources` runs SQLite against the data source URL used as a table name:

```sql
SELECT url, "Name", "Status", "Kind", "Priority", "Target Release", "Owner", "Evidence", "Where"
FROM "collection://6ada2feb-7308-4574-ae8a-91e32d901557"
WHERE "Status" IN ('To Do', 'In Progress')
ORDER BY "Target Release", "Priority"
```

Pass it as `{"data": {"data_source_urls": ["collection://6ada2feb-7308-4574-ae8a-91e32d901557"], "query": "..."}}`,
with `params` and `?` placeholders rather than interpolated strings. Dates are queryable only as the
split columns `date:Added:start` and `date:Completed:start`. SQL text drops rich-text formatting;
fetch the row's page for its body.

Before touching search, Pinecone or the OpenAI request, read `WHERE "Kind" = 'Trap'`. Before
proposing a feature, read `WHERE "Status" = 'Won''t Do'` and `WHERE "Kind" = 'Decision'`.

## Release scope: triage before you file

**A new row defaults to `Future Backlog`.** It gets the next release only if it passes one of these
tests, and its body names which:

1. **Data loss, corruption or a key exposure.** The person loses work, the app damages what it
   stored, or an OpenAI or Pinecone key leaves the Keychain.
2. **An advertised claim is false.** The App Store listing, the privacy label, onboarding or
   Settings says the app does something it doesn't.
3. **It blocks shipping.** The build can't go out, or can't go out honestly, until it is done.

Features, speed, refactors, tooling and test coverage don't qualify, however valuable. **State the
closing condition in the body** ("Closes when X is observed").

## Writing

- **Starting** work a row tracks: set `Status` to `In Progress`.
- **Finishing** it: set `Status` to `Completed` and `date:Completed:start` to today. `Target
  Release` is the version that carries the change.
- **Evidence** is the strongest check you actually made, in this order: `device_verified` (seen on
  a physical iPhone), `measured` (observed in a run or an App Store Connect read), `test_verified`,
  `build_verified`, `code_verified` (read, not run), `unverified` (built, never exercised). Never
  raise it without having done the thing.
- **No row exists** for durable work: create one.
- **A version goes live**: mark its `Release` row `Completed` with the date, update the release
  line in the page header, and add the next version as a `Target Release` option (below).

Update with `notion-update-page`, `command: "update_properties"`. Create with `notion-create-pages`
and `parent: {"type": "data_source_id", "data_source_id": "6ada2feb-7308-4574-ae8a-91e32d901557"}`.
Keep the title short and plain and put the detail in the page `content` as Notion-flavored Markdown.
Correct a wrong row in place with a dated note rather than deleting it.

## Schema, as created 2026-09-30

Never invent an option; the API refuses a value that isn't one.

| Property | Options |
|---|---|
| `Status` | `To Do`, `In Progress`, `Completed`, `Won't Do`, `Reference` |
| `Kind` | `Feature`, `Fix`, `Release`, `Verification` (work); `Decision`, `Trap` (knowledge) |
| `Component` | `Ingestion`, `Pinecone`, `Search & answer`, `OpenAI & models`, `UI`, `Settings & keys`, `App Store listing`, `Build & release`, `Architecture`, `Docs & agents` |
| `Priority` | `High`, `Medium`, `Low` |
| `Target Release` | `v1.0`, `v2.0`, `v2.2`, `v3`, `v3.1`, `Future Backlog` |
| `Owner` | `Agent`, `Gunnar on a device`, `Gunnar in App Store Connect`, `Gunnar decides`, `Either` |
| `Evidence` | `device_verified`, `measured`, `test_verified`, `build_verified`, `code_verified`, `unverified`. Empty means not recorded. |
| `Where` | Text: the file, symbol, script or doc to open first |
| Dates | `Added`, `Completed`, set through `date:<name>:start` |

**Adding the next release option** (`v3.2` once 3.1 is out): `notion-update-data-source` with
`ALTER COLUMN "Target Release" SET SELECT('v1.0':gray, 'v2.0':brown, 'v2.2':orange, 'v3':green, 'v3.1':blue, 'v3.2':purple, 'Future Backlog':pink) COMMENT 'The App Store version that carries the change. New work defaults to Future Backlog; the triage rule is in .claude/skills/notion-roadmap/SKILL.md.'`,
restating every existing option by name and colour so existing rows keep their values. Keep the
`COMMENT`: without it the ALTER clears the column's description (OpenManual lost it that way on
2026-09-29).

Views: Next up, By Status, By release, Needs Gunnar, Read first: traps, Decisions.

## The page is private

If it is ever published, every row becomes public writing: no unmeasured figure in a title.

## Finish by reporting the exact rows you touched, with their URLs.
