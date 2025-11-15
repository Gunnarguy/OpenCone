# App Store Connect Copy

## Promotional Text (170 characters max)
Turn every file on your iPhone into a searchable, on-device RAG workspace with Pinecone-powered recall and streaming OpenAI answers.

---

## Description (4,000 characters max)

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

## What's New in This Version (4,000 characters max)

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

## Keywords (100 characters max, comma-separated)

RAG,AI assistant,OpenAI,Pinecone,document search,semantic search,knowledge base,OCR,vector search

---

## Support URL
https://github.com/Gunnarguy/OpenCone

---

## Marketing URL
https://github.com/Gunnarguy/OpenCone

---

## Privacy Policy URL
https://github.com/Gunnarguy/OpenCone/blob/main/PRIVACY.md

---

## FORMATTING NOTES FOR APP STORE CONNECT

1. **Line breaks**: App Store Connect preserves line breaks in description. Use single line breaks between bullet points and double line breaks between sections.

2. **Bullet points**: Use • (Option+8 on Mac) for bullet points. They render correctly in App Store.

3. **Section headers**: ALL CAPS headers stand out without requiring markdown formatting.

4. **Character limits**:
   - Promotional text: 170 chars
   - Description: 4,000 chars
   - What's New: 4,000 chars
   - Keywords: 100 chars total (not per keyword)

5. **Copy/paste order**:
   - Copy sections WITHOUT the markdown headers
   - Paste directly into App Store Connect fields
   - Preview in App Store Connect to verify formatting

6. **Keywords**: Enter as comma-separated list without spaces after commas for maximum keyword count.
