# OpenCone Roadmap

## 1. Completed Features (The Foundation)

### Core Infrastructure

- [x] **App lifecycle & onboarding** — `AppState` enum with loading→welcome→main→error transitions; `WelcomeView` with API key validation
- [x] **Keychain-backed secrets** — `SecureSettingsStore` for OpenAI/Pinecone credentials; env-var seeding for dev; release build guard against bundled secrets
- [x] **Structured logging** — `Logger.shared` with `@Published logEntries`; Logs tab with export; configurable minimum level
- [x] **Design system** — `OCButton`, `OCCard`, `OCBadge`; `ThemeManager` with light/dark themes; `@Environment(\.theme)` accessor
- [x] **Preflight automation** — `preflight_check.sh` (secret scan, Info.plist validation, privacy doc checks, unit tests)

### Document Processing

- [x] **Multi-format document ingestion** — PDF (PDFKit), DOCX, plain text, HTML, CSV, Markdown, JSON, code files
- [x] **Vision OCR pipeline** — Image-to-text extraction via `VNRecognizeTextRequest` for PNG/JPEG/TIFF
- [x] **Security-scoped bookmarks** — Persistent file access with consent banner (`needsSecurityConsent`)
- [x] **Semantic chunking** — `RecursiveTextSplitter` with MIME-specific separators; configurable chunk size/overlap
- [x] **OpenAI embeddings** — Batched embedding generation (50/batch); dimension validation; `text-embedding-3-large` (3072 dim)
- [x] **Duplicate rejection** — `DocumentIdentifierBuilder` with content hash; 100MB size limit
- [x] **Live processing dashboard** — Document progress tracking; dashboard metrics (processed/pending/failed counts, vector totals)
- [x] **Documents tab redesign** — Clean card-based UI; floating bulk action bar; filter by status; advanced options in sheet

### Pinecone Integration

- [x] **Full Pinecone integration** — Index CRUD; namespace management; upsert/query/delete; host caching; retry with exponential backoff; circuit breaker
- [x] **Index insights** — `IndexStatsResponse` with namespace vector counts; refresh after ingest/delete
- [x] **Idempotent index selection** — `setCurrentIndex` returns early if already on requested index, reducing redundant API calls
- [x] **Multi-field content extraction** — Supports `_node_content`, `text`, `content`, `transcript_preview`, `body`, `description`, `chunk_text` metadata fields
- [x] **Hybrid search** — Combine dense (semantic) + sparse (keyword) vectors via Pinecone's `hybridQuery`; alpha weighting (0.0 = keyword, 1.0 = semantic); Settings UI with slider
- [x] **Reranking** — Two-stage retrieval using `bge-reranker-v2-m3`, `cohere-rerank-3.5`, or `pinecone-rerank-v0`; configurable top-N; Settings UI with model picker
- [x] **Metadata filters** — `PineconeMetadataFilter` enum with operators ($eq, $in, $gte, $lte, $contains); presets in Settings

### Search & Chat

- [x] **Streaming chat completion** — OpenAI Responses API with SSE parsing; token-by-token UI updates
- [x] **Conversation memory** — Server-managed (`conversationId`) and client-managed (bounded history) modes
- [x] **Search result selection** — Multi-select sources; regenerate answer from selection
- [x] **Input clearing after send** — Search input clears immediately when message is sent (captured to local variable for async flow)
- [x] **Custom system prompts** — User-configurable RAG system prompt per index/namespace

### AI Tools (OpenAI Responses API)

- [x] **Web search tool** — `type: "web_search"` with `include: ["web_search_call.action.sources"]` for source extraction
- [x] **Code interpreter tool** — `type: "code_interpreter"` with `container: { type: "auto" }` parameter; charts, calculations, data visualization
- [x] **Code interpreter efficiency** — Heuristic activation (only for queries with digits or keywords like "chart", "plot", "statistics"); context caps (3 sources, 1200 chars when active); output limits (max 8 outputs, 1MB images)
- [x] **Code interpreter UI** — `CodeInterpreterOutputsView` displays logs, charts, and errors inline; collapsible output cards
- [x] **Smart example prompts** — Contextual prompts based on index/namespace and enabled tools; categories: Discover, Analyze, Extract, Compare

### Quick Settings & UX

- [x] **Quick Settings panel** — Popover with model picker, temperature/reasoning slider, top-K, response length, AI tools toggles
- [x] **Presets** — Precise, Balanced, Creative, Research one-tap configurations
- [x] **Theme switcher** — Quick theme change from Quick Settings popover
- [x] **Voice input** — `SpeechRecognitionService` with permission prompt on first tap (fixed `.notDetermined` blocking issue)

### GPT-5 & Reasoning Models

- [x] **GPT-5.2 support** — Full support with 400K context and 128K output tokens
- [x] **Reasoning effort control** — Off, Low, Med, High, Max (xhigh) levels for reasoning models
- [x] **Dynamic parameter switching** — Shows reasoning effort for GPT-5/o-series, temperature/topP for standard models

## 2. Technical Debt (The Cracks)

- [x] **Orphaned DocumentsView.swift** — Old 1541-line view replaced by `DocumentsViewRedesign.swift` but file still exists; can be deleted
- [ ] **Web search tool value unclear** — `web_search` tool enabled but not integrated with Pinecone; consider removing or clarifying use case
- [ ] **Test coverage gaps** — Only `SearchViewModelMetadataPersistenceTests` exists; missing coverage for:
  - Document ingestion pipeline
  - Pinecone retry/circuit breaker logic
  - Streaming completion parsing
  - Embedding batch processing
  - Code interpreter heuristics
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
- [x] **Custom system prompts** — User-configurable RAG system prompt per index/namespace

## 4. API Feature Gaps

### OpenAI Responses API (Priority Order)

- [ ] **Structured Outputs** — JSON schema in `text.format` for consistent citation/answer format; guarantees type-safe responses
- [ ] **Input token counting** — `POST /v1/responses/input_tokens` for pre-flight validation before incurring cost
- [x] **Web search source extraction** — Add `include: ["web_search_call.action.sources"]` to surface where web info came from
- [x] **Code interpreter output extraction** — Add `include: ["code_interpreter_call.outputs"]` to display executed code/charts; requires `container` parameter
- [ ] **Function calling** — Define custom tools for agentic behavior (e.g., let model decide when to query Pinecone)
- [ ] **Prompt caching** — `prompt_cache_key` + `prompt_cache_retention: "24h"` for cost reduction on repeated context
- [ ] **Background processing** — `background: true` for heavy reasoning tasks; poll with `GET /v1/responses/{id}`
- [ ] **Conversation compaction** — `POST /v1/responses/compact` to compress long chats within context window
- [ ] **File Search tool** — `type: "file_search"` for OpenAI-hosted document search (alternative to Pinecone)
- [ ] **Image inputs** — Direct multimodal via `input_image` without local OCR pre-processing
- [ ] **MCP connectors** — Google Drive, SharePoint integration via `type: "mcp"`
- [ ] **Truncation strategy** — `truncation: "auto"` for graceful degradation instead of hard 400 errors
- [ ] **Parallel tool calls control** — `parallel_tool_calls: false` when ordering matters
- [ ] **Safety identifiers** — `safety_identifier` with hashed user ID for abuse detection
- [ ] **Service tier control** — `service_tier: "flex"` (cheaper) vs `"priority"` (faster)

### Pinecone API

- [ ] **Collections** — `POST /collections` for backup/restore snapshots of index data
- [ ] **Bulk import** — `POST /bulk/imports` from S3/GCS for enterprise onboarding
- [ ] **Parallel queries** — Multiple queries in single request for compound questions
- [ ] **Record-level sparse vectors** — Store `sparse_values` per-record for more accurate hybrid search
- [ ] **Metadata index configuration** — Configure which fields are indexed for faster filtering

### Quality of Life

- [ ] **Token usage display** — Parse and show `usage.input_tokens`, `usage.output_tokens` in UI
- [ ] **Cached tokens indicator** — Show when `usage.input_tokens_details.cached_tokens > 0`
- [ ] **Cost estimation** — Calculate approximate $/query based on token counts and model pricing
- [ ] **Response ID persistence** — Store `response_id` for later retrieval via `GET /v1/responses/{id}`
- [ ] **Annotations extraction** — Parse `annotations` array from responses for inline citations
- [ ] **Logprobs display** — Add `include: ["message.output_text.logprobs"]` for confidence scoring
- [ ] **OpenAI retry with backoff** — Mirror Pinecone's retry pattern for OpenAI transient failures
