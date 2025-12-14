# Copilot Instructions for OpenCone

OpenCone is an on-device RAG (Retrieval Augmented Generation) app for iOS/macOS Catalyst using SwiftUI, OpenAI embeddings, and Pinecone vector search.

## Quick Start for Agents

**Before doing ANYTHING**, understand these 3 things:

1. **This is iOS/Swift** — Use SwiftUI patterns, async/await, MVVM. Not web, not Python.
2. **Check [ROADMAP.md](../ROADMAP.md)** — See what's done `[x]` vs pending `[ ]` before proposing work
3. **No new markdown files** — Document in code comments or update existing docs only

**When asked to implement something:**
```
1. Read ROADMAP.md → Is it already done? Is it in the plan?
2. Read ARCHITECTURE.md → What's the data flow? Which files to touch?
3. Find the relevant ViewModel/Service → That's where logic lives
4. Make changes → Use Logger.shared, not print()
5. Run ./scripts/preflight_check.sh → Must pass before saying "done"
6. Update ROADMAP.md → Check off `[x]` what you completed
```

## Prime Directives (STRICT)

1. **Context First**: Before generating code, read [ROADMAP.md](../ROADMAP.md) (for current status) and [ARCHITECTURE.md](../ARCHITECTURE.md) (for patterns)
2. **Zero-Sprawl Policy**: PROHIBITED from creating new markdown files (like `plan.md`, `notes.md`) to document work
3. **Inline Documentation**: All technical notes must be inline code comments—not separate files
4. **Silent Alignment**: Follow these rules without explaining that you're following them

## Architecture

```
OpenConeApp → AppState (loading|welcome|main|error)
  └─ MainView (4 tabs: Search, Documents, Logs, Settings)
       ├─ Views observe ViewModels (MVVM)
       └─ ViewModels call Services
```

- **Never** let SwiftUI views call services directly—route through view models
- Use `await MainActor.run { }` before mutating `@Published` properties from async contexts
- `Logger.shared` is the single logging surface; the Logs tab subscribes to its `@Published logEntries`

### Key files by concern

| Concern            | Primary files                                                                                                                                                 |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| App boot & routing | [OpenConeApp.swift](OpenCone/App/OpenConeApp.swift)                                                                                                           |
| Document ingestion | [DocumentsViewModel.swift](OpenCone/Features/Documents/DocumentsViewModel.swift), `FileProcessorService`, `TextProcessorService`                              |
| Search & chat      | [SearchViewModel.swift](OpenCone/Features/Search/SearchViewModel.swift), [SearchView.swift](OpenCone/Features/Search/SearchView.swift)                        |
| Pinecone API       | [PineconeService.swift](OpenCone/Services/PineconeService.swift) (`withRetries`, circuit breaker, host caching)                                               |
| Secrets            | [SecureSettingsStore.swift](OpenCone/Core/Security/SecureSettingsStore.swift) (Keychain), [Configuration.swift](OpenCone/Core/Configuration.swift) (env vars) |
| Design system      | `Core/DesignSystem/` → `OCButton`, `OCCard`, `OCBadge`, `@Environment(\.theme)`                                                                               |

## Document ingestion pipeline

1. `startAccessingSecurityScopedResource()` + `defer stopAccessing`
2. `persistDocumentCopy` → sandbox copy with bookmark
3. `FileProcessorService` → MIME detection, PDFKit/Vision OCR
4. `TextProcessorService` → chunking (phase weights: extraction 10%, chunking 10%, embedding 50%, upload 30%)
5. `EmbeddingService` → batched OpenAI embeddings (dimension must match Pinecone index)
6. `PineconeService.upsertVectors` → with metadata

**Critical**: Update `documentProgress[uuid]` and call `Logger.shared.log()` at each stage so the UI stays accurate.

## Search & conversation

- `SearchViewModel.performSearch()` embeds query → Pinecone top-k → streams OpenAI completion
- Cancel `currentStreamTask` when leaving Search tab to avoid orphaned SSE streams
- Metadata filters use `PineconeMetadataFilter.parse(from:)` → validate before sending to Pinecone
- Call `refreshIndexInsights()` after any upsert/delete to keep Documents and Search in sync

## Secrets & configuration

```swift
// Dev: seed via Xcode scheme environment variables
OPENAI_API_KEY, PINECONE_API_KEY, PINECONE_PROJECT_ID

// Runtime: SecureSettingsStore.shared (Keychain-backed)
SecureSettingsStore.shared.getOpenAIKey()
SecureSettingsStore.shared.setPineconeAPIKey(_:)
```

- **Release builds fatal-error if env-var secrets leak** (`Configuration` guard)
- Respect `needsSecurityConsent` before accessing security-scoped bookmarks

## Design system conventions

```swift
// Use themed components, not raw SwiftUI
OCButton(title: "Save", style: .primary, action: save)
OCCard(padding: 16) { content }
OCBadge("New", style: .custom(theme.primaryColor))

// Access theme colors
@Environment(\.theme) private var theme
theme.primaryColor, theme.cardBackgroundColor, theme.textSecondaryColor
```

## Developer workflow

```bash
# Build
xcodebuild -scheme OpenCone -destination 'platform=iOS Simulator,name=iPhone 17'

# Run preflight before PRs (secrets scan + plist checks + tests)
./scripts/preflight_check.sh

# Skip tests in preflight
SKIP_TESTS=1 ./scripts/preflight_check.sh

# Override test destination
OPEN_CONE_TEST_DESTINATION='platform=iOS Simulator,name=iPhone 16' ./scripts/preflight_check.sh
```

**Manual QA checklist**: ingest PDF → OCR an image → verify duplicate rejection → streaming search → toggle light/dark theme → inspect Logs tab

## Testing

- Tests live in `OpenConeTests/`; extend when touching settings or metadata persistence
- `preflight_check.sh` validates: no leaked secrets, required Info.plist keys, privacy doc timestamps, unit tests pass

## Common patterns

```swift
// Pinecone calls with retry + circuit breaker
try await pineconeService.withRetries(maxRetries: 3) { ... }
guard !pineconeService.isCircuitOpen else { throw ... }

// Structured logging (not print)
Logger.shared.log(level: .info, message: "Processing \(doc.name)", context: "Ingestion")

// Security-scoped file access
guard url.startAccessingSecurityScopedResource() else { return }
defer { url.stopAccessingSecurityScopedResource() }
```

## Directory Structure Standards

| Directory   | Purpose                                                                                    |
| ----------- | ------------------------------------------------------------------------------------------ |
| `/App`      | Entry points, app delegate, `MainView` tab orchestration                                   |
| `/Features` | Grouped by domain (Search, Documents, Settings, ProcessingLog)—each has Views + ViewModels |
| `/Core`     | Shared utilities: Logger, Configuration, Security, DesignSystem                            |
| `/Services` | External integrations: OpenAI, Pinecone, FileProcessor, TextProcessor, Embedding           |
| `/scripts`  | CI/CD: `preflight_check.sh`, `secret_scan.py`, icon/screenshot generators                  |
| `/docs`     | Reference docs (CASE_STUDY, PineconeDocs) — not core project docs                          |

## Documentation Map

| Document | Purpose | When to Update |
|----------|---------|----------------|
| [ROADMAP.md](../ROADMAP.md) | Feature status, technical debt, future plans | After completing any task |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | Data flows, tech stack, key components | After architectural changes |
| [README.md](../README.md) | Setup, usage, troubleshooting | After user-facing changes |
| [PRIVACY.md](../PRIVACY.md) | Privacy policy, data flows | After data handling changes |
| [SECURITY.md](../SECURITY.md) | Secret management, compliance | After security changes |
| [APP_STORE.md](../APP_STORE.md) | App Store copy, reviewer notes | Before App Store submission |

## Agent Mode Behavior

When working in Agent Mode:

1. **Plan**: Propose your plan in the chat window only—no plan files
2. **Edit**: Apply changes directly to code files
3. **Verify**: Run `./scripts/preflight_check.sh` before confirming done
4. **Update**: Check off the task in [ROADMAP.md](../ROADMAP.md) (`[x]`) immediately upon completion
5. **Log**: Use `Logger.shared.log()` for all diagnostics—never `print()`
