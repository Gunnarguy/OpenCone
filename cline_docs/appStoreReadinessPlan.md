# OpenCone App Store Readiness Plan

_Last updated: 2025-11-11_

## Objective

Bring OpenCone from its current development state to TestFlight and App Store submission readiness within ~12 hours of focused work, emphasizing privacy compliance, secret handling, reviewer guidance, and minimal release operations.

## Guiding Principles

- **No hardcoded secrets** (OpenAI / Pinecone keys) ship in Release builds.
- **Transparent data flow**: reviewers and users know what leaves the device.
- **Low-effort, high-value** documentation and automation guardrails.
- **Single-source reference** for everyone iterating on submission work.

## High-Impact Workstreams

1. **Secret Hygiene & Release Guardrails**
   - Validate that keys are user-supplied and Keychain backed.
   - Add Release build guard and automated secret scans.
2. **Privacy Surface & Reviewer Guidance**
   - Populate Info.plist usage descriptions.
   - Author user-facing consent copy and reviewer docs.
3. **Operational Checklist**
   - Scripts, screenshots, icon validation, and TestFlight upload.
4. **Pilot Validation**
   - Internal QA run (3 testers) exercising ingestion→search flow.

## Deliverables & Owners

| Deliverable | Description | Target | Owner |
|-------------|-------------|--------|-------|
| `Info.plist` privacy keys | All required usage strings present & localized (EN) | +2h | Release eng |
| `PRIVACY.md` | One-page data flow summary for App Privacy answers | +3h | Release eng |
| `AppReviewNotes.md` | Reviewer script & credentials guidance | +3h | Release eng |
| Security consent UI | Modal/toast explaining bookmark persistence & cloud calls | +4h | iOS eng |
| `scripts/secret_scan.py` | Regex scan for secrets, integrated in CI | +5h | Release eng |
| `scripts/preflight_check.sh` | Ensures plist key check + secret scan pass | +5h | Release eng |
| Screenshots & icon audit | 4 screenshots + confirm 1024 icon | +6h | Design/eng |
| TestFlight build | Xcode archive & upload, notes from above docs | +8h | Release eng |
| Internal QA sign-off | 3 testers confirm ingestion→search | +12h | QA coord |

## Checklist Tracker

### 1. Secrets & Guardrails

- [ ] Add Release build assertion requiring user-supplied keys (no defaults).
- [ ] Commit `scripts/secret_scan.py` (exit code 1 on match).
- [ ] Commit `scripts/preflight_check.sh` (runs secret scan + plist key check).
- [ ] Document process in `SECURITY.md` (key storage, CI policy).

### 2. Privacy & Reviewer Assets

- [ ] Insert usage strings (`NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, etc.).
- [ ] Author `PRIVACY.md` (on-device vs cloud flow, retention).
- [ ] Author `AppReviewNotes.md` (step-by-step reviewer guide).
- [ ] Add security-scoped bookmark consent message + revoke instructions in Settings.

### 3. Operational Prep

- [ ] Capture 4 simulator screenshots (onboarding, import, processing, RAG answer).
- [ ] Verify app icon (1024px) and marketing assets.
- [ ] Run `preflight_check.sh` locally and in CI.
- [ ] Produce Xcode archive, upload to TestFlight, paste reviewer notes.
- [ ] Invite 3 internal testers and document feedback.

### 4. Post-Pilot Follow-up

- [ ] Triage tester feedback (UI/bugs/perf).
- [ ] Re-run ingestion + search smoke tests.
- [ ] Confirm crash-free run in TestFlight analytics before App Review submission.

## Timeline (Aggressive ETA)

| Hour | Milestone |
|------|-----------|
| 0–2  | Privacy strings + `PRIVACY.md` + `AppReviewNotes.md` drafted |
| 2–4  | Consent UI implemented, scripts added, secret scan passes |
| 4–6  | Screenshots captured, icon check, preflight script green |
| 6–8  | Xcode archive + TestFlight upload with review notes |
| 8–12 | Internal testing, defect triage, resubmission if required |

## Execution Notes

- Use `git status` after each workstream; do not leave review docs uncommitted.
- Ensure any new localized strings default to English for now.
- Add `PRIVACY.md` summary to README once approved.
- Document the API key requirements prominently in Settings (already user-supplied, reiterate in `PRIVACY.md`).
- For TestFlight notes, include sample dummy keys or instructions to obtain review-only keys.

## Next Actions (as of 2025-11-11)

1. Add privacy usage descriptions to `Info.plist` and open a PR.
2. Create `PRIVACY.md` & `AppReviewNotes.md` referencing `FileProcessorService`, `EmbeddingService`, and `PineconeService`.
3. Implement security-scoped bookmark consent banner/modal.
4. Draft secret/preflight scripts and wire them into repository tooling.

---

Use this document as the canonical checklist; update the _Last updated_ timestamp whenever progress is made.
