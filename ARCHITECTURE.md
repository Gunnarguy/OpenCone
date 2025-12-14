# OpenCone Architecture

## High-Level Goal

OpenCone is a privacy-first, on-device RAG (Retrieval Augmented Generation) application for iOS and macOS Catalyst. Users ingest personal documents (PDF, DOCX, images, code files), which are processed locally with text extraction and OCR, chunked semantically, embedded via OpenAI, and stored in Pinecone. Queries embed the user's question, retrieve relevant chunks from Pinecone, and stream grounded answers from OpenAI's Responses API.

## Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INGESTION PIPELINE                             │
├─────────────────────────────────────────────────────────────────────────────┤
│  Document Picker                                                            │
│       ↓                                                                     │
│  Security-Scoped Access (startAccessingSecurityScopedResource)             │
│       ↓                                                                     │
│  persistDocumentCopy → Sandbox copy with bookmark                          │
│       ↓                                                                     │
│  FileProcessorService                                                       │
│    • MIME detection (UTType fallback to extension)                         │
│    • PDFKit for PDF extraction                                             │
│    • Vision framework for OCR (images)                                     │
│       ↓                                                                     │
│  TextProcessorService                                                       │
│    • RecursiveTextSplitter chunking                                        │
│    • Token counting via NLTokenizer                                        │
│    • Content hashing (SHA256) for deduplication                            │
│       ↓                                                                     │
│  EmbeddingService                                                           │
│    • Batched requests to OpenAI (50 chunks/batch)                          │
│    • Dimension validation against index                                    │
│       ↓                                                                     │
│  PineconeService.upsertVectors                                             │
│    • Retry with exponential backoff                                        │
│    • Circuit breaker for consecutive failures                              │
│       ↓                                                                     │
│  IndexStats refresh → UI update                                            │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                              SEARCH PIPELINE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│  User Query                                                                 │
│       ↓                                                                     │
│  EmbeddingService.generateQueryEmbedding                                   │
│       ↓                                                                     │
│  PineconeService.query (top-k, metadata filters)                           │
│       ↓                                                                     │
│  Context assembly from matching chunks                                      │
│       ↓                                                                     │
│  OpenAIService.streamCompletion (Responses API)                            │
│    • Server-managed conversation OR bounded local history                  │
│    • SSE streaming with token-by-token UI updates                          │
│       ↓                                                                     │
│  Chat timeline + Sources panel update                                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI Framework | SwiftUI (iOS 17+, macOS 14 Catalyst) |
| Concurrency | Swift async/await, Combine |
| Text Extraction | PDFKit, Vision (OCR) |
| NLP | NaturalLanguage framework (tokenization) |
| Hashing | CryptoKit (SHA256) |
| Networking | URLSession with custom retry/circuit breaker |
| Vector Storage | Pinecone (serverless) |
| Embeddings | OpenAI text-embedding-3-large (3072 dim) |
| Completions | OpenAI Responses API (gpt-4o, o3-mini, etc.) |
| Secrets | iOS Keychain via SecureSettingsStore |
| Theming | Custom design system (OCTheme, ThemeManager) |

## Key Components

### App Layer (`/App`)

| File | Purpose |
|------|---------|
| `OpenConeApp.swift` | Entry point. Manages `AppState` enum (loading→welcome→main→error). Wires services and view models. Enforces no-bundled-secrets guard for release builds. |
| `MainView.swift` | Tab container (Search, Documents, Logs, Settings). Coordinates index refresh on tab switches. |
| `WelcomeView.swift` | First-run onboarding flow for API key entry with live validation. |

### Features Layer (`/Features`)

| Domain | Key Files | Responsibilities |
|--------|-----------|------------------|
| **Documents** | `DocumentsViewModel.swift`, `DocumentsView.swift` | Document add/remove, processing orchestration, progress tracking, dashboard metrics |
| **Search** | `SearchViewModel.swift`, `SearchView.swift` | Query embedding, Pinecone search, streaming answer generation, metadata filters, conversation memory |
| **Settings** | `SettingsViewModel.swift`, `SettingsView.swift` | API key management, model selection, chunk config, search presets, theme control |
| **ProcessingLog** | `ProcessingViewModel.swift`, `ProcessingView.swift` | Real-time log display, log export, level filtering |

### Services Layer (`/Services`)

| Service | Key Patterns |
|---------|--------------|
| `PineconeService` | `withRetries(maxRetries:)` for transient failures; circuit breaker (`isCircuitOpen`, `healthFailureThreshold`); host caching with TTL; rate limiting (100ms between requests) |
| `OpenAIService` | Responses API with `input` array format; SSE parsing for streaming; reasoning effort for o-series models; dimension passthrough for embeddings |
| `EmbeddingService` | Batch processing (50 chunks); dimension validation; progress callbacks |
| `FileProcessorService` | MIME detection; PDFKit page iteration; Vision `VNRecognizeTextRequest` for OCR |
| `TextProcessorService` | RecursiveTextSplitter with MIME-specific separators; content hashing; token metrics |

### Core Layer (`/Core`)

| Module | Purpose |
|--------|---------|
| `Logger` | Singleton (`Logger.shared`) with `@Published logEntries` for UI binding. Levels: debug, info, success, warning, error. |
| `SecureSettingsStore` | Keychain wrapper for secrets (OpenAI key, Pinecone key, Project ID). Non-secrets in UserDefaults. |
| `Configuration` | Static constants (embedding model, dimension, chunk size). Environment variable seeding for dev. |
| `PineconePreferenceResolver` | Persists last-used index/namespace selections. |
| `DesignSystem` | `OCButton`, `OCCard`, `OCBadge`, `OCTheme`, `ThemeManager`. Use `@Environment(\.theme)` in views. |

## Design Patterns

| Pattern | Implementation |
|---------|----------------|
| **MVVM** | Views observe `@ObservedObject` ViewModels; ViewModels call Services |
| **Dependency Injection** | Services created in `OpenConeApp`, passed to ViewModels in `createViewModels()` |
| **Singleton** | `Logger.shared`, `SecureSettingsStore.shared`, `ThemeManager.shared` |
| **Circuit Breaker** | `PineconeService.isCircuitOpen` opens after N consecutive failures, auto-resets after timeout |
| **Retry with Backoff** | `withRetries(maxRetries:)` wrapper in `PineconeService` |
| **Progress Callbacks** | Async closures passed to `EmbeddingService.generateEmbeddings(progressCallback:)` |
| **Security-Scoped Bookmarks** | Required for file access across app launches; `needsSecurityConsent` banner pattern |
