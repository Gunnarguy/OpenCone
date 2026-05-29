# OpenCone Roadmap

This document outlines the development status of OpenCone, categorizing milestones into completed achievements, active developments, planned capabilities, known limitations, and technical debt.

---

## 1. Completed Milestones (The Foundation)

### App Core & Security
- [x] **App State Lifecycle**: Built a stable state machine (`loading`, `welcome`, `main`, `error`) in `OpenConeApp`.
- [x] **Keychain Secure Storage**: Implemented `SecureSettingsStore` for Keychain-level API key persistence, preventing unencrypted UserDefaults storage.
- [x] **Release Security Gate**: Integrated compile-time checks that crash the app (`enforceNoBundledSecrets`) if developer environment keys leak into non-debug production builds.
- [x] **Preflight Script Automation**: Created `scripts/preflight_check.sh` to validate secrets, verify Plist usage strings, enforce MD timestamp checks, and run unit tests.

### Document Processing
- [x] **Multi-format Extraction**: Support for PDF, DOCX, TXT, HTML, JSON, CSV, RTF, MD, and common code scripts.
- [x] **Vision OCR Engine**: Local text recognition for images (PNG, JPEG, TIFF) using native `VNRecognizeTextRequest`.
- [x] **Security Bookmarks**: Sandboxed access (`startAccessingSecurityScopedResource`) to files across app boots.
- [x] **Recursive Text Splitting**: MIME-aware chunking with custom size and overlap rules.
- [x] **Fingerprint Deduplication**: Pre-compute SHA256 hashes to prevent redundant processing.

### Retrieval & Search (RAG)
- [x] **Pinecone Integration**: Complete Control and Data plane REST wrappers, supporting circuit breakers, host caching, and retries.
- [x] **Two-Stage Retrieval**: Support for hybrid semantic + keyword search with alpha weighting controls and reranking (BGE Reranker v2 M3, Cohere, Pinecone models).
- [x] **Advanced Metadata Filters**: Full operators support ($eq, $in, $gte, $lte, $contains) for scoping queries.
- [x] **OpenAI Responses API Stream**: Real-time token streaming using Server-Sent Events (SSE).
- [x] **Speech-to-Text Transcription**: Connects `AVAudioEngine` input taps and Apple's Speech API for voice query input.

---

## 2. Active Work (In Progress)

- [ ] **Circuit Breaker User Interface Warnings**: Add visual banner overlays to alert users when Pinecone is degraded and the client-side circuit breaker is open.
- [ ] **Structured Outputs for Citations**: Implement strict JSON schemas in `text.format` OpenAI Response params to ensure structured output citation fields.
- [ ] **Integration Test Pipeline**: Add automated UI tests simulating RAG search execution and file processing states.

---

## 3. Planned Improvements (Future Scope)

- [ ] **On-Device Vector Database**: Introduce local offline embeddings (e.g. SQLite vector extensions) to allow offline searches.
- [ ] **Bookmark-Aware File Syncing**: Detect changes in source files using security bookmarks to re-index documents automatically.
- [ ] **Parallel Processing Queue**: Speed up ingestion by running parallel background worker Tasks.
- [ ] **Multimodal Visual Input**: Allow uploading images directly to OpenAI completion models without local OCR pre-processing.

---

## 4. Technical Debt & Known Gaps

- [ ] **Orphaned DocumentsView.swift File**: Remove the outdated `DocumentsView.swift` file (which has been replaced by `DocumentsViewRedesign.swift`).
- [ ] **Memory Pressure Observers**: Large document processing needs to subscribe to memory warnings (`didReceiveMemoryWarningNotification`) and pause queues.
- [ ] **VoiceOver Optimizations**: Chat bubble and source citation components lack custom `accessibilityLabel` hooks for screen readers.
- [ ] **Rate Limit Feedback**: The internal 100ms rate limiter for Pinecone operations works silently, without notifying the user when operations are being throttled.

---

## 5. Release Readiness Checklist

- [ ] Execute `scripts/preflight_check.sh` on an active Simulator target.
- [ ] Verify `secret_scan.py` returns `✅ No secret patterns detected.`
- [ ] Clean up scheme environment variable settings.
- [ ] Confirm `Info.plist` usage descriptions contain clear descriptions.
- [ ] Perform a full app reset using the in-app settings "Reset Stored Keys & Preferences".
