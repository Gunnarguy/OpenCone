# Copilot Instructions for OpenCone

## Architecture map

- `OpenConeApp` boots shared services (`FileProcessorService`, `TextProcessorService`, `EmbeddingService`, `OpenAIService`, `PineconeService`) and routes `AppState` from `loading → welcome → main` once credentials validate.
- `MainView` hosts four tabs (Search, Documents, Logs, Settings); enhance features inside these tabs or the Welcome flow—never spawn new windows/scenes.
- View models are the only surface talking to services; keep SwiftUI views declarative and hop back to the main actor (`await MainActor.run`) before mutating `@Published` state.
- `ProcessingViewModel` mirrors `Logger.shared` output for the Logs tab; reuse that logger for any pipeline or network diagnostics.

## Document ingestion

- `DocumentsViewModel` handles copy → extraction → chunking → embedding → Pinecone upsert; extend these stages through its helpers so `documentProgress`, `ProcessingStats`, and dashboard metrics stay accurate.
- Always wrap file URLs in `startAccessingSecurityScopedResource()` / `defer stopAccessing` and persist through `persistDocumentCopy`; `DocumentIdentifierBuilder.makeIdentifier` enforces duplicate + 100 MB limits.
- Chunk metadata lives in `TextProcessorService`; adjust phase weights if you insert new ingestion steps so the UI progress bar remains truthful.
- Emit stage updates through `Logger.shared` so `ProcessingViewModel` and the Logs tab reflect user-visible progress.

## Search & conversation

- `SearchViewModel.performSearch()` embeds queries, calls Pinecone top‑k (`UserDefaults` key `searchTopK`), and streams completions via `OpenAIService.streamCompletion`; cancel `currentStreamTask` when leaving the tab to prevent orphaned SSE streams.
- Metadata filters originate from `SettingsMetadataPreset`; always validate with `PineconeMetadataFilter.parse` before sending to Pinecone.
- `PineconePreferenceResolver` records last index/namespace—call `refreshIndexInsights()` after ingest/delete so both Documents and Search stay in sync.
- `SettingsViewModel.conversationMode` switches between local transcripts and server-managed `conversationId`; keep both flows working when modifying chat logic.

## Services & cross-cutting

- `PineconeService` provides retries (`withRetries`), host caching, `setCurrentIndex`, and a circuit breaker (`isCircuitOpen`); favor these helpers over raw `URLSession`.
- `OpenAIService` owns embedding + streaming payloads; reuse its SSE parser so streaming UI and token counts remain consistent.
- `FileProcessorService` (MIME detection + OCR), `TextProcessorService` (chunking + tokens), and `EmbeddingService` (batched requests sized to the Pinecone index dimension) must stay aligned when swapping models.
- Always log through `Logger.shared` instead of `print`; the Logs tab is the canonical debugger and feeds `ProcessingView`.

## Settings, security & design system

- Secrets persist via `SecureSettingsStore`, but you can seed them with environment variables (`OPENAI_API_KEY`, `PINECONE_API_KEY`, `PINECONE_PROJECT_ID`) in the Xcode Run scheme; `CredentialValidator` handles debounced validation.
- Respect the security-consent banner (`needsSecurityConsent` / `acknowledgeSecurityConsent`) whenever you touch bookmarks or stored files.
- Release builds fatal-error if scheme-provided secrets leak (`Configuration` guard); clear overrides before archiving.
- Use `Core/DesignSystem` components (`OCButton`, `OCCard`, `OCBadge`) and `@Environment(\.theme)` accessors; `ThemeManager.shared` is the single source of truth for light/dark palettes.

## Developer workflow & QA

- Build with Xcode 16+ targeting iOS 17 / macOS 14 Catalyst; onboarding requires valid OpenAI + Pinecone keys before exposing `MainView`.
- After Pinecone writes/deletes, invoke the view-model helpers that call `pineconeService.deleteVectors` and `refreshIndexInsights()` to keep namespace counts correct.
- Preferred diagnostics flow: ingest a PDF, run an OCR image, verify duplicate rejection, execute a streaming search, toggle themes, and inspect the Logs tab for each stage.
- Asset + marketing upkeep lives in `scripts/generate_app_icons.sh` and `scripts/capture_screenshots.sh`; keep them in sync with product changes.

## Testing & automation

- Automated coverage currently lives in `OpenConeTests/SearchViewModelMetadataPersistenceTests`; extend this target when touching settings or metadata persistence.
- Run `scripts/preflight_check.sh` before PRs/releases—it runs `secret_scan.py`, checks Info.plist usage strings, verifies privacy docs contain “Last updated”, and executes `xcodebuild test -scheme OpenCone` (override via `OPEN_CONE_TEST_DESTINATION`, skip with `SKIP_TESTS=1`).
- CI/release builds will fail fast if keys ship bundled or if preflight fails; mirror that behavior locally to avoid surprises.
