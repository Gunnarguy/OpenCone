# OpenCone Roadmap

## 1. Completed Features (The Foundation)

- [x] **App lifecycle & onboarding** — `AppState` enum with loading→welcome→main→error transitions; `WelcomeView` with API key validation
- [x] **Keychain-backed secrets** — `SecureSettingsStore` for OpenAI/Pinecone credentials; env-var seeding for dev; release build guard against bundled secrets
- [x] **Multi-format document ingestion** — PDF (PDFKit), DOCX, plain text, HTML, CSV, Markdown, JSON, code files
- [x] **Vision OCR pipeline** — Image-to-text extraction via `VNRecognizeTextRequest` for PNG/JPEG/TIFF
- [x] **Security-scoped bookmarks** — Persistent file access with consent banner (`needsSecurityConsent`)
- [x] **Semantic chunking** — `RecursiveTextSplitter` with MIME-specific separators; configurable chunk size/overlap
- [x] **OpenAI embeddings** — Batched embedding generation (50/batch); dimension validation; `text-embedding-3-large` (3072 dim)
- [x] **Pinecone integration** — Index CRUD; namespace management; upsert/query/delete; host caching; retry with exponential backoff; circuit breaker
- [x] **Streaming chat completion** — OpenAI Responses API with SSE parsing; token-by-token UI updates
- [x] **Conversation memory** — Server-managed (`conversationId`) and client-managed (bounded history) modes
- [x] **Metadata filters** — `PineconeMetadataFilter` enum with operators ($eq, $in, $gte, $lte, $contains); presets in Settings
- [x] **Live processing dashboard** — Document progress tracking; dashboard metrics (processed/pending/failed counts, vector totals)
- [x] **Structured logging** — `Logger.shared` with `@Published logEntries`; Logs tab with export; configurable minimum level
- [x] **Design system** — `OCButton`, `OCCard`, `OCBadge`; `ThemeManager` with light/dark themes; `@Environment(\.theme)` accessor
- [x] **Index insights** — `IndexStatsResponse` with namespace vector counts; refresh after ingest/delete
- [x] **Search result selection** — Multi-select sources; regenerate answer from selection
- [x] **Duplicate rejection** — `DocumentIdentifierBuilder` with content hash; 100MB size limit
- [x] **Preflight automation** — `preflight_check.sh` (secret scan, Info.plist validation, privacy doc checks, unit tests)
- [x] **Hybrid search** — Combine dense (semantic) + sparse (keyword) vectors via Pinecone's `hybridQuery`; alpha weighting (0.0 = keyword, 1.0 = semantic); Settings UI with slider
- [x] **Reranking** — Two-stage retrieval using `bge-reranker-v2-m3`, `cohere-rerank-3.5`, or `pinecone-rerank-v0`; configurable top-N; Settings UI with model picker
- [x] **Documents tab redesign** — Clean card-based UI; floating bulk action bar; filter by status; advanced options in sheet; reduced from 1541 to ~650 lines
- [x] **Voice input fix** — `SpeechRecognitionService` now triggers permission prompt on first tap (was incorrectly blocking `.notDetermined` state)

## 2. Technical Debt (The Cracks)

- [ ] **No TODO/FIXME comments found** — Codebase is clean of inline debt markers
- [ ] **Test coverage gaps** — Only `SearchViewModelMetadataPersistenceTests` exists; missing coverage for:
  - Document ingestion pipeline
  - Pinecone retry/circuit breaker logic
  - Streaming completion parsing
  - Embedding batch processing
- [ ] **Error recovery UX** — Circuit breaker opens silently; consider surfacing "service degraded" banner to user
- [ ] **Memory pressure handling** — Large document processing uses `autoreleasepool` but no explicit low-memory observer
- [ ] **Accessibility** — Limited `accessibilityLabel` usage; missing VoiceOver optimization for chat timeline
- [ ] **Offline mode** — No local caching of embeddings or search results; requires network for all operations
- [ ] **Rate limit visibility** — 100ms rate limiter is internal; no user feedback when throttled

## 3. Future Trajectory

- [ ] **Local embedding cache** — Cache query embeddings locally to reduce redundant OpenAI calls
- [ ] **Document update detection** — Re-process documents when source file changes (using bookmarks to detect modifications)
- [ ] **Export conversation** — Share chat history as Markdown or PDF
- [ ] **Batch document import** — Folder picker for bulk ingestion with queue visualization
- [ ] **Widget / Spotlight integration** — iOS widget for quick search; Spotlight indexing of ingested documents
- [ ] **Multi-index search** — Query across multiple Pinecone indexes simultaneously
- [ ] **Custom system prompts** — User-configurable RAG system prompt per index/namespace
