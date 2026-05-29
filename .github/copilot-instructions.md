# Copilot & Agent Instructions for OpenCone

OpenCone is an on-device Retrieval-Augmented Generation (RAG) iOS/macOS Catalyst sandbox application built with SwiftUI, async/await, OpenAI embeddings, and Pinecone serverless vector databases.

---

## 1. Prime Directives (STRICT)

1. **Do Not Invent Files, APIs, or Completed Features**: Always audit the code to see what exists. If a feature or path cannot be verified, state it as "Needs verification" or a gap rather than inventing.
2. **Context and Roadmap First**: Before generating code or planning architectures, read [ROADMAP.md](../ROADMAP.md) (status) and [ARCHITECTURE.md](../ARCHITECTURE.md) (design).
3. **Zero-Sprawl Policy**: Do not create new temporary markdown files (such as `plan.md` or `notes.md`) to document work. Design notes must reside in code comments or updates to existing documents.
4. **Update Docs on Changes**: If you modify the codebase architecture, update the relevant documentation files immediately.
5. **Silent Alignment**: Follow these rules without explaining or apologizing in chat responses.

---

## 2. Architecture Rules

- **Strict MVVM-S Boundaries**: Views observe ViewModels (`ObservableObject`). ViewModels invoke Services. SwiftUI views must never make direct calls to services.
- **Thread Safety**: Property modifications that mutate UI elements must be run on the main thread (using `@MainActor` or `await MainActor.run { ... }`).
- **Stateless Services**: Enforce stateless service boundaries (except Keychains or singletons like Logger), delegating session memory to ViewModels.

---

## 3. Key Files by Concern

| Concern | Primary Files |
|---|---|
| **App Boot & Routing** | [OpenConeApp.swift](OpenCone/App/OpenConeApp.swift), [MainView.swift](OpenCone/App/MainView.swift) |
| **Document Ingestion** | [DocumentsViewModel.swift](OpenCone/Features/Documents/DocumentsViewModel.swift), [DocumentsViewRedesign.swift](OpenCone/Features/Documents/DocumentsViewRedesign.swift), `FileProcessorService`, `TextProcessorService` |
| **Search & RAG** | [SearchViewModel.swift](OpenCone/Features/Search/SearchViewModel.swift), [SearchView.swift](OpenCone/Features/Search/SearchView.swift) |
| **Pinecone REST API** | [PineconeService.swift](OpenCone/Services/PineconeService.swift) |
| **OpenAI Integration** | [OpenAIService.swift](OpenCone/Services/OpenAIService.swift) |
| **Security Enclave** | [SecureSettingsStore.swift](OpenCone/Core/Security/SecureSettingsStore.swift), [Configuration.swift](OpenCone/Core/Configuration.swift) |

---

## 4. Build & Test Commands

Use the following commands to build, test, and scan the codebase:

```bash
# Build the application
xcodebuild -project OpenCone.xcodeproj -scheme OpenCone -destination "platform=iOS Simulator,name=iPhone 16" build

# Run unit tests
xcodebuild test -project OpenCone.xcodeproj -scheme OpenCone -destination "platform=iOS Simulator,name=iPhone 16" -quiet

# Run preflight verification
scripts/preflight_check.sh
```

---

## 5. Coding & Logging Conventions

- **Logging**: Always dispatch diagnostics to `Logger.shared.log(level:message:context:)`. Never use `print()` or `NSLog()` statements.
- **Memory Safety**: Wrap loops parsing multiple files (such as OCR extractions) inside local `autoreleasepool` blocks to free buffers immediately.
- **Resilience**: Wrap Pinecone calls inside the retry block:
  ```swift
  try await pineconeService.withRetries(maxRetries: 3) { ... }
  ```
- **Keychain Keys**: Retrieve all API keys from `SecureSettingsStore.shared` rather than local config files.
- **Release Guard**: Non-debug archive targets will trigger a `fatalError` if environment secrets are hardcoded.
