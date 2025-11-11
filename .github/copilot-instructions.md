# Copilot Instructions for OpenCone

## Big-Picture Context

- OpenCone is a SwiftUI iOS/macOS RAG client. `OpenConeApp.swift` wires up the core services (`OpenAIService`, `PineconeService`, `EmbeddingService`) and injects them into feature view models (`DocumentsViewModel`, `SearchViewModel`, `SettingsViewModel`).
- Main navigation lives in `App/MainView.swift`: tabs for **Document Search**, **Documents**, **Logs**, **Settings**. New surface areas should slot into this tab model or be presented modally from an existing tab.
- The pipeline: document ingestion (`DocumentsViewModel`) → chunking (`TextProcessorService`) → embeddings (`EmbeddingService`/`OpenAIService`) → vector storage (`PineconeService`) → retrieval & chat (`SearchViewModel` with streaming responses). Keep changes consistent with this flow.

## Key Modules & Patterns

- **Documents** (`Features/Documents`): `DocumentsViewModel.addDocument` now copies user files into the app sandbox via `persistDocumentCopy` and stores security bookmarks. When extending ingestion, respect this copy + bookmark scheme and update `document.securityBookmark` if bookmarks go stale. Clean up sandbox copies when removing documents.
- **Search** (`Features/Search`): `SearchViewModel` owns the RAG loop. Queries run embedding generation, Pinecone query, then answer generation through `OpenAIService.streamCompletion`, which parses SSE deltas. Preserve streaming expectations (update `messages`, `answerGenerationProgress`, cancellation via `currentStreamTask`).
- **Settings** (`Features/Settings`): `SettingsViewModel` persists sliders/segmented pickers into `UserDefaults` and `SecureSettingsStore`. UI components come from `OCDesignSystem`; expose new controls through the view model so they survive saves/resets.
- **Services** (`Services/`):
  - `OpenAIService` handles both embeddings and `/v1/responses` streaming; use the provided request builders (`makeResponsesPayload`, `streamCompletion`).
  - `PineconeService` already manages retries, rate limiting, and a circuit breaker (`healthCheck`, `withRetries`). Reuse these helpers instead of rolling new networking code.
  - `FileProcessorService` leverages PDFKit/Vision OCR; long-running work should stay in async functions to avoid blocking the main thread.
- **Design System** (`Core/DesignSystem`): shared theming via `ThemeManager.shared` and `@Environment(\.theme)`. Any new SwiftUI view should favor `OCButton`, `OCCard`, etc., to remain on-brand.
- **Logging**: use `Logger.shared.log(level:message:context:)`. Logs surface instantly in the Logs tab, so hook major async steps and failure branches into this logger instead of `print`.

## Developer Workflow

- Build & run with Xcode; select an iOS simulator or macOS target. For first launch, enter OpenAI & Pinecone keys in the welcome flow or set `OPENAI_API_KEY`, `PINECONE_API_KEY`, `PINECONE_PROJECT_ID` in the run scheme.
- No automated tests yet—after significant logic changes, run through manual flows: ingest a PDF, verify Pinecone sync, execute a streaming search, and tweak settings to ensure persistence.
- When adding async work invoked from SwiftUI, wrap it in `Task { await ... }` or `Task.detached` and marshal UI updates back onto `MainActor.run { ... }` like existing code.

## Integration Notes & Gotchas

- Document deduplication uses `makeDocumentIdentifier` (hash of normalized path + size + timestamps). If you change how files are stored, maintain identifier stability or reindex existing vectors.
- `SearchViewModel` stores `conversationId` for server-managed threads (`SettingsViewModel.conversationMode == "server"`). New search features must honor both server-managed and client-bounded history modes.
- Pinecone namespaces and indexes are cached; after mutations call `refreshIndexInsights()` to repopulate `namespaces`, `indexStats`, and UI badges.
- Respect the security-scope lifecycle: any URL resolved from bookmarks must call `startAccessingSecurityScopedResource()` and stop in a `defer` once finished.
- Avoid blocking operations on the main thread—document copying, embedding, and Pinecone calls are already async; keep additions off the UI thread.
