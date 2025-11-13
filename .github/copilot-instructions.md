# Copilot Instructions for OpenCone

## Architecture & flow

- `OpenConeApp` wires shared `FileProcessorService`, `TextProcessorService`, `EmbeddingService`, `OpenAIService`, and `PineconeService` into `DocumentsViewModel` / `SearchViewModel`, advancing `AppState` (`loading`→`welcome`→`main`) once credentials pass validation.
- `MainView` exposes Search, Documents, Logs, and Settings tabs; extend functionality inside these surfaces or the Welcome flow instead of spawning new windows/scenes.
- `ProcessingViewModel` listens to `Logger.shared` and feeds the Logs tab—tap into the same logger for pipeline diagnostics.

## Document ingestion & storage

- `DocumentsViewModel` orchestrates copy → extraction → chunking → embedding → Pinecone upsert; reuse its async helpers so progress (`documentProgress`, `ProcessingStats`) and dashboard metrics stay accurate, and emit stage updates through `Logger.shared` so `ProcessingViewModel` reflects them.
- Persist files with `persistDocumentCopy` and minimal bookmarks; always wrap file work in `startAccessingSecurityScopedResource()` / `defer stopAccessing`.
- `DocumentIdentifierBuilder.makeIdentifier` blocks duplicates and enforces the 100 MB limit; update phase weights if you add ingestion stages.
- After deletes or resets, call the view-model helpers that wrap `pineconeService.deleteVectors` and then refresh stats so namespace counts stay current.

## Search & conversation

- `SearchViewModel.performSearch()` embeds the query, issues Pinecone top‑k (default via `UserDefaults` key `searchTopK`), then streams completions through `OpenAIService.streamCompletion`; always tear down `currentStreamTask` on tab change to avoid orphaned SSE streams.
- Metadata filters round-trip through `SettingsMetadataPreset`; validate them with `PineconeMetadataFilter.parse` before hitting Pinecone.
- `SettingsViewModel.conversationMode` toggles local transcripts versus server-managed `conversationId`; keep both modes functional during changes.
- Keep retrieved chunk metadata aligned with UI cards (`SearchResultView`) so highlighted context stays trustworthy.

## Services & infrastructure

- `PineconeService` handles retries (`withRetries`), rate limiting, host caching, and a circuit breaker (`isCircuitOpen`); prefer these helpers over manual networking and call `setCurrentIndex` before namespace operations.
- `OpenAIService` owns both embedding and streaming completion payloads; reuse its SSE parser so token counts and streaming UI stay consistent.
- `FileProcessorService` performs MIME detection + OCR, `TextProcessorService` prepares chunk metadata, and `EmbeddingService` batches requests to match the index dimension—keep them aligned when swapping models.
- Run background work inside `Task` blocks, hop to the main actor with `await MainActor.run {}` for UI changes, and log through `Logger.shared` instead of `print`.

## Settings, security & preferences

- `SettingsViewModel` persists keys via `SecureSettingsStore` and validates them with `CredentialValidator`; environment variables (`OPENAI_API_KEY`, `PINECONE_API_KEY`, `PINECONE_PROJECT_ID`) seed the same flow.
- `PineconePreferenceResolver` remembers the last index/namespace—record overrides with `recordLastIndex`/`recordLastNamespace`, and call `refreshIndexInsights()` after writes/deletes so both Documents and Search stay in sync.
- Respect the security-consent banner (`needsSecurityConsent` / `acknowledgeSecurityConsent`) and expose reset paths through Settings when touching stored secrets.
- `Configuration` surfaces scheme-provided secrets; release builds fatal-error if those values are non-empty, so clear overrides before archive automation.

## UI & design system

- Lean on `Core/DesignSystem` components (`OCButton`, `OCCard`, `OCBadge`, typography modifiers) and theme access via `@Environment(\.theme)`; `ThemeManager.shared` drives live updates.
- Keep new views SwiftUI-friendly with `ObservableObject` view models and structured logs so the Logs tab reflects user actions; `ProcessingView` reads from `ProcessingViewModel` and expects log metadata to be populated.
- Follow existing navigation patterns (NavigationView + toolbar buttons) instead of introducing custom shells, and layer in `Preview Content/PreviewData.swift` when adding SwiftUI previews for complex views.

## Developer workflow & QA

- Build/run via Xcode 16; provide API keys through the scheme or the Welcome flow, and always re-run onboarding after clearing secrets.
- After ingesting/deleting content or mutating embeddings, call `refreshIndexInsights()` and verify namespace counts in Documents/Search dashboards.
- Manual QA remains essential: ingest PDF + OCR image, validate duplicate guards, run a streaming search, toggle themes, and exercise metadata filters.
- Maintain supporting assets with `scripts/generate_app_icons.sh`; capture marketing shots with `scripts/capture_screenshots.sh`, and lean on `scripts/preflight_check.sh` for release gating.

## Testing & release

- Automated coverage currently lives in `OpenConeTests/SearchViewModelMetadataPersistenceTests`; add cases there when touching presets or defaults.
- Run `scripts/preflight_check.sh` before shipping—it invokes `secret_scan.py`, validates privacy copy, and executes `xcodebuild test` (override simulator with `OPEN_CONE_TEST_DESTINATION`).
- Release builds fatal-error if keys ship bundled (`Configuration` guard in `OpenConeApp`); clear scheme overrides before archiving or automation deploys.
