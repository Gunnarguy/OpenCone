# Copilot Instructions for OpenCone

## Orientation

- SwiftUI MVVM RAG client; `OpenCone/App/OpenConeApp.swift` wires `OpenAIService`, `PineconeService`, `EmbeddingService` into the tab view models.
- `App/MainView.swift` hosts Search/Documents/Logs/Settings tabs; new UI surfaces should attach via these tabs or modal flows they spawn.
- README highlights architecture but lags behind recent changes—treat this file as the authoritative onboarding for agents.

## Document Ingestion

- `DocumentsViewModel` drives file copy → extraction → chunking → embedding → Pinecone upsert; extend the pipeline by reusing its async helpers and `Logger.shared` progress calls.
- Files are persisted with `persistDocumentCopy` plus security bookmarks; always wrap bookmark access in `startAccessingSecurityScopedResource()`/`defer stopAccessing`.
- `makeDocumentIdentifier` (path + size + timestamps) prevents duplicates and enforces a 100 MB cap; if storage changes, keep IDs stable or expect a full reindex.
- Phase weights feed `documentProgress` and `ProcessingStats`; adjust them when adding ingestion stages so dashboard metrics stay accurate.

## Index & Namespace Management

- `PineconePreferenceResolver` remembers last index/namespace; call `recordLastIndex`/`recordLastNamespace` when overriding selections.
- `PineconeService.setCurrentIndex` resolves hosts and resets circuit state; always invoke it before queries and rerun `refreshIndexInsights()` after writes/deletes.
- Pinecone location defaults come from `SecureSettingsStore` (cloud/region); keep new configuration knobs flowing through that store.

## Search & Conversation

- `SearchViewModel.performSearch()` embeds the query, runs Pinecone topK (defaults via `searchTopK` in `UserDefaults`), then streams completion tokens through `OpenAIService.streamCompletion`.
- Metadata filters live in `metadataFilters` and persist via `SettingsMetadataPreset`; reuse `PineconeMetadataFilter.parse` to validate user-supplied filters.
- `conversationMode` from `SettingsViewModel` toggles local history vs server-managed `conversationId`; preserve both paths when expanding chat behavior.
- Streaming uses `currentStreamTask` cancellation plus watchdog timeouts; cancel tasks when leaving the view to avoid orphaned SSE streams.

## Services & Shared Infrastructure

- `PineconeService` bundles rate limiting, retries (`withRetries`), host caching, and a circuit breaker (`isCircuitOpen`); extend those helpers rather than issuing raw `URLSession` calls.
- `OpenAIService` builds embeddings and `/v1/responses` payloads; request streamed completions through its SSE parser so UI progress and token counts remain granular.
- `EmbeddingService` batches chunk uploads to match model dimensions; keep chunk metadata aligned with `TextProcessorService` output.
- `FileProcessorService` and `TextProcessorService` perform heavy lifting off the main actor; schedule them inside `Task` blocks and marshal UI updates with `await MainActor.run {}`.

## UI & Design System

- Adopt `Core/DesignSystem` components (`OCButton`, `OCCard`, `OCBadge`, typography modifiers) and theme access via `@Environment(\.theme)` for consistent styling.
- `ThemeManager.shared` broadcasts theme changes; subscribe to its `@Published` state instead of hard-coding colors.
- Processing logs surface through `Logger.shared` → `ProcessingViewModel`; prefer structured log messages over `print` so the Logs tab stays useful.

## Developer Workflow

- Build with Xcode; provide `OPENAI_API_KEY`, `PINECONE_API_KEY`, `PINECONE_PROJECT_ID` via the Run scheme or the Welcome flow (`CredentialValidator` + `SecureSettingsStore`).
- Unit tests cover search metadata presets in `OpenConeTests/SearchViewModelMetadataPersistenceTests`; expand them when touching filter persistence or defaults.
- Manual QA remains critical: ingest a PDF, verify Pinecone stats refresh, run a streaming search, confirm settings persistence and security-consent banners.
- When adding background work, keep SwiftUI interactions inside `Task {}` and use `await MainActor.run {}` for state writes to avoid cross-actor violations.
