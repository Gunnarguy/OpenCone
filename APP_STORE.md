# App Store Submission Guide

**Last updated:** 2025-12-13

This document consolidates all App Store submission materials: copy, reviewer notes, and screenshot guidance.

---

## Table of Contents

- [Promotional Text](#promotional-text)
- [Description](#description)
- [What's New](#whats-new)
- [Keywords](#keywords)
- [URLs](#urls)
- [App Review Notes](#app-review-notes)
- [Screenshot Capture Guide](#screenshot-capture-guide)
- [Submission Checklist](#submission-checklist)
- [Formatting Notes](#formatting-notes)

---

## Promotional Text

*170 characters max*

Turn every file on your iPhone into a searchable, on-device RAG workspace with Pinecone-powered recall and streaming OpenAI answers.

---

## Description

*4,000 characters max*

Transform your iPhone and iPad into a self-contained RAG powerhouse. Import PDFs, Word docs, code, images, and text into a secure sandbox—extraction, embedding, and semantic search happen with zero lock-in. Point the app at your OpenAI and Pinecone credentials for a private knowledge base that streams grounded, citation-backed answers in real time.

COMPLETE DOCUMENT PIPELINE
• Multi-format extraction: PDF, DOCX, TXT, HTML, Markdown, JSON, CSV, and code
• Apple Vision OCR for on-device image text recognition
• MIME-aware chunking with configurable size and overlap
• Security-scoped bookmarks preserve file access across launches
• Deduplication by path, size, and timestamp fingerprinting
• Live progress tracking with structured logs for every phase

SEMANTIC SEARCH WITH STREAMING
• One-tap queries embed prompts and run similarity search against Pinecone
• Server-Sent Events deliver incremental answer deltas—no blocking spinners
• Citations reference exact chunks with document names and source metadata
• Metadata filters scope searches to specific documents or custom tags
• Conversation memory keeps recent turns in context for coherent follow-ups

GPT-5 REASONING MODEL SUPPORT
• Choose between standard models (GPT-4o, GPT-4o mini) or GPT-5
• Dynamic controls: reasoning effort for GPT-5, temperature/top-p for others
• Unified Responses API with conditional parameterization

RESILIENCE & OBSERVABILITY
• Pinecone health checks surface outages with dismissible banners
• Circuit breaker prevents hammering unhealthy hosts
• Watchdog timers catch stalled streams and trigger fallbacks
• Per-search trace IDs and granular log levels make every stage inspectable
• Error banners auto-dismiss after 8 seconds with user-friendly summaries

SETTINGS & PRIVACY
• Credentials in Keychain via SecureSettingsStore
• Release guardrails prevent accidental key leaks
• Model selection, chunk parameters, top-k defaults, metadata presets persist
• Reset control wipes credentials and history without reinstalling
• Guided onboarding validates API keys before unlocking main interface

POLISHED SWIFTUI EXPERIENCE
• Theme manager with alternate icons and dynamic color schemes
• Reactive MVVM-S architecture decouples views from business logic
• Async/await throughout keeps UI responsive during heavy operations
• Design system components ensure consistency across all tabs

Whether building surgical references, legal research corpora, or personal knowledge vaults, OpenCone delivers production-grade RAG without vendor dashboards or billing surprises.

---

## What's New

*4,000 characters max — Version 2.0*

Version 2.0 brings foundational improvements to answer generation, reliability, and user control.

OPENAI RESPONSES API & GPT-5
• Migrated from Chat Completions to structured Responses API
• Native GPT-5 reasoning model with dynamic effort controls
• Existing models (GPT-4o, GPT-4o mini) continue with temperature/top-p
• Settings UI conditionally renders correct parameters
• Structured "input" field with system/user content arrays

SERVER-SENT EVENTS STREAMING
• Answers stream token-by-token instead of blocking
• Typing indicator appears immediately while waiting
• Stop button cancels mid-generation with clear feedback
• Watchdog timer detects stalls and triggers fallback completion

CONVERSATION MEMORY
• Bounded client mode includes last ~8 messages for context
• Server-managed threads use OpenAI conversation IDs
• Toggle between modes in Settings for privacy preferences
• Follow-ups understand prior exchanges without restating

RESILIENCE & CIRCUIT BREAKER
• Pinecone health checks run before queries with short timeout
• Circuit breaker prevents calls to unhealthy hosts
• Per-search trace IDs tie logs to specific queries
• Error banners auto-dismiss with user-friendly summaries

PRIVACY & RESET FLOWS
• Settings > Data & Privacy exposes credential reset
• Clears Keychain, conversation history, bookmark consent
• Onboarding messaging clarifies missing keys
• Preflight script blocks accidental credential leaks

CITATION STABILITY & POLISH
• Citations enumerate by offset—no duplicate ID warnings
• Logs tab filters with color-coded levels
• Index host transitions emit structured logs
• Improved keyboard handling and haptic feedback

Behind the scenes: upgraded to OpenAI Responses API, added conditional model parameterization, implemented SSE parsing with cancellation, and wired bounded conversation memory. All changes maintain backward compatibility with existing documents and Pinecone indexes.

---

## Keywords

*100 characters max, comma-separated*

```
RAG,AI assistant,OpenAI,Pinecone,document search,semantic search,knowledge base,OCR,vector search
```

---

## URLs

| Field          | URL                                                        |
| -------------- | ---------------------------------------------------------- |
| Support URL    | https://github.com/Gunnarguy/OpenCone                      |
| Marketing URL  | https://github.com/Gunnarguy/OpenCone                      |
| Privacy Policy | https://github.com/Gunnarguy/OpenCone/blob/main/PRIVACY.md |

---

## App Review Notes

*Paste this into the "Notes for Review" field in App Store Connect*

Dear App Review Team,

Thank you for reviewing OpenCone, a document-centric retrieval-augmented generation (RAG) client. The app helps users ingest their own documents, store derived embeddings in Pinecone, and ask questions answered with OpenAI responses.

### Test Credentials

We provide reviewer-specific API keys with access to sample Pinecone namespaces and a locked-down OpenAI project:

- **OpenAI API Key**: *Provided in App Store Connect reviewer notes*
- **Pinecone API Key**: *Provided in App Store Connect reviewer notes*
- **Pinecone Project ID**: *Provided in App Store Connect reviewer notes*

After launching the app you will be prompted to enter these values. No other configuration is required.

### Testing Walkthrough

1. Import the sample PDF attached to these review notes via the **+** button in Documents tab
2. Wait for ingestion to complete (status updates appear in the Logs tab)
3. Switch to Search tab and run these queries:
   - "What are the key onboarding steps for new Pinecone indexes?"
   - "Summarize the architecture for OpenCone ingestion."
4. Verify streaming responses arrive and cite document snippets
5. Remove a document and confirm it disappears from Documents and search results

### Privacy & Data Flow

- Imported files are copied into the app sandbox for processing
- Text chunks are sent to OpenAI (embeddings) and Pinecone (vectors) using the reviewer keys
- No third-party analytics or advertising SDKs are present
- Removing a document issues a delete request to Pinecone

### Troubleshooting

- If ingestion stalls, tap "Refresh Index Insights" in Documents tab
- Use Settings to reset the app and re-enter keys if needed
- Settings → Data & Privacy has "Reset Stored Keys & Preferences" for a clean slate
- Network access is required for embedding generation and answer streaming

Thank you for your time. Contact support@opencone.app for assistance during review.

---

## Screenshot Capture Guide

### Prerequisites

- Xcode 16+ with target simulator (iPhone 17 Pro Max for 6.7" class)
- Test API keys configured
- Clean build passing `./scripts/preflight_check.sh`

### Capture Flow

```bash
# Start simulator
open -a Simulator

# Run capture helper
./scripts/capture_screenshots.sh /path/to/output
```

For each prompt, stage the UI in simulator, then press **Return** to capture.

### Required Screenshots

| File             | Scene                                     | Notes                                                |
| ---------------- | ----------------------------------------- | ---------------------------------------------------- |
| `welcome.png`    | Welcome/onboarding with credential fields | Show OpenAI & Pinecone inputs with placeholders      |
| `documents.png`  | Documents tab with processed document     | At least one completed document tile                 |
| `processing.png` | Logs tab during ingestion                 | Live log entries and progress badge                  |
| `search.png`     | Search tab streaming an answer            | Sourced snippets visible, streaming indicator active |

### Post-Capture

1. Confirm resolution: 1290 x 2796 (6.7" device)
2. Export additional sizes if needed via Preview or `sips`
3. Upload to App Store Connect → iOS App → App Preview & Screenshots
4. Maintain order: welcome → documents → processing → search

---

## Submission Checklist

### Pre-Archive

- [ ] Run `./scripts/preflight_check.sh` — must pass
- [ ] Clear environment variables (`OPENAI_API_KEY`, `PINECONE_API_KEY`, `PINECONE_PROJECT_ID`) from Run scheme
- [ ] Verify app icon (1024px) via `./scripts/generate_app_icons.sh`
- [ ] Capture 4 screenshots at required resolutions

### App Store Connect

- [ ] Upload archive via Xcode Organizer
- [ ] Fill promotional text (copy from above)
- [ ] Fill description (copy from above)
- [ ] Fill What's New (copy from above)
- [ ] Add keywords (copy from above)
- [ ] Upload screenshots in order
- [ ] Set Support/Marketing/Privacy URLs
- [ ] Paste App Review Notes with test credentials
- [ ] Attach sample PDF for reviewer testing

### Post-Submit

- [ ] Invite 3 internal TestFlight testers
- [ ] Monitor crash-free rate in TestFlight analytics
- [ ] Respond to any App Review questions within 24h

---

## Formatting Notes

When copying to App Store Connect:

1. **Line breaks** — App Store Connect preserves them. Use single breaks between bullets, double between sections.
2. **Bullet points** — Use • (Option+8 on Mac). They render correctly.
3. **Section headers** — ALL CAPS stand out without markdown.
4. **Character limits**:
   - Promotional text: 170 chars
   - Description: 4,000 chars
   - What's New: 4,000 chars
   - Keywords: 100 chars total
5. **Copy/paste** — Copy sections WITHOUT markdown headers, paste directly into fields.
6. **Keywords** — Enter as comma-separated without spaces after commas for maximum count.
