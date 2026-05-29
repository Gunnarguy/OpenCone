# OpenCone

<p align="center">
  <img src="Screenshots/search.png" width="300" alt="OpenCone Interface"/>
</p>

<p align="center">
  <strong>On-device Retrieval Augmented Generation (RAG) for iOS, built with SwiftUI, async/await, and first-class OpenAI + Pinecone integrations.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-5.10-orange.svg" alt="Swift"/>
  <img src="https://img.shields.io/badge/iOS-17.0%2B-blue.svg" alt="iOS"/>
  <img src="https://img.shields.io/badge/Xcode-16.0%2B-blue.svg" alt="Xcode"/>
  <img src="https://img.shields.io/badge/license-MIT-lightgrey.svg" alt="License"/>
</p>

---

## Overview
OpenCone is a local-first, native Swift/iOS application designed to transform personal documents (PDFs, Word docs, plain text, code scripts, and images) into an on-device searchable knowledge base. Designed for researchers, engineers, and privacy-conscious professionals, the app parses local files, extracts text (utilizing Vision OCR where necessary), recursively chunks content using MIME-aware rules, embeds them via OpenAI, and persists indexing vectors securely inside a serverless Pinecone database. 

During queries, OpenCone executes semantic vector lookup, performs high-efficiency reranking, manages local session memory, and streams grounded responses from OpenAI's Responses API token-by-token. OpenCone is distinguished in this portfolio as the core **RAG Sandbox**, showcasing advanced document processing pipelines, rate-limited Pinecone clients with circuit-breaker protection, Apple's Speech Recognition framework for voice query input, and dynamic theme synchronization.

---

## Product Snapshot

| Dimension | Detail |
|---|---|
| Platform | iOS 17.0+ / iPadOS 17.0+ / macOS Catalyst 14.0+ |
| Language | Swift 5.10+ |
| UI | SwiftUI (Modern declarative, custom style sheets) |
| Architecture | MVVM-S (Model-View-ViewModel-Service) with focused App State Machine |
| Primary APIs | OpenAI (Embeddings, Responses API), Pinecone REST API (Control & Data Plane), Apple Speech/Vision |
| Storage | Secure Enclave Keychain (`SecureSettingsStore`), `UserDefaults`, and local Sandboxed files |
| Status | Shipped / Portfolio Showcase |
| App Store | [Not published] |
| License | [MIT](LICENSE) |

---

## What This App Demonstrates

- **MIME-Aware Ingestion Pipeline**: Extracts structured text from multiple formats, utilizing `PDFKit` for PDF pages and Apple's native `Vision` OCR framework for images.
- **On-Device Security-Scoped Access**: Employs sandboxed bookmarks (`startAccessingSecurityScopedResource`) to retain file read permissions across system relaunches without prompts.
- **Resilient Pinecone & OpenAI Client**: Coordinates exponential backoff retries, request rate limiting (100ms pauses), and an automatic circuit-breaker to gracefully handle vector-store throttling or region failures.
- **Advanced RAG Capabilities**: Orchestrates hybrid searches (combining dense embeddings and sparse keyword vectors), custom metadata presets, and multi-model rerankers (`bge-reranker-v2-m3`, `cohere-rerank-3.5`, `pinecone-rerank-v0`).
- **Real-Time Token Streaming**: Implements Server-Sent Events (SSE) parsing to fetch incremental response deltas directly from OpenAI's chat completions.
- **Speech-to-Text Transcription**: Connects `AVAudioEngine` input taps and Apple's Speech Recognition API to transcribe microphone audio with responsive UI waveform animation.
- **Bespoke Theme System**: Centralizes look-and-feel variables under a theme environment manager, supplying customized Light and Dark color palettes.

---

## End-to-End User Journey

Below is the user path showing credential checks, onboarding validation, local file processing, vector upsert, and subsequent semantic search querying.

```mermaid
flowchart TD
    A[Launch App] --> B{Credentials configured?}
    B -->|No| C[Onboarding / Settings]
    B -->|Yes| D[Main Workspace]
    C --> E[Validate and store credentials]
    E --> D
    D --> F[User Action: Ingest or Query]
    F -->|Ingest File| G[Processing pipeline]
    F -->|Submit Query| J[Search Pipeline]
    G --> H[External OpenAI / Pinecone service]
    H --> I[Refresh Index Stats]
    I --> D
    J --> K[Retrieve & Generate answers]
    K --> L[Render Results & Citations]
    L --> D
```

---

## System Architecture

OpenCone adheres to an MVVM-S architecture. The view layer binds to observable models, which coordinate complex actions by invoking highly decoupled services.

```mermaid
flowchart TD
    subgraph UI["User Interface (SwiftUI)"]
        W[WelcomeView]
        M[MainView]
        DV[DocumentsViewRedesign]
        SV[SearchView]
        SetV[SettingsView]
        LV[ProcessingView]
    end

    subgraph ViewModels["ViewModels"]
        DVM[DocumentsViewModel]
        SVM[SearchViewModel]
        SetVM[SettingsViewModel]
        LVM[ProcessingViewModel]
    end

    subgraph Services["Services Layer"]
        FP[FileProcessorService]
        TP[TextProcessorService]
        ES[EmbeddingService]
        OA[OpenAIService]
        PC[PineconeService]
        SR[SpeechRecognitionService]
    end

    subgraph Storage["Storage & Security"]
        KEY[Keychain SecureSettingsStore]
        UD[UserDefaults]
        FILE[Sandbox Documents]
    end

    subgraph External["External APIs"]
        OpenAI[OpenAI Endpoints]
        Pinecone[Pinecone Clusters]
        AppleSpeech[Apple Speech API]
    end

    %% Wiring
    M --> DV & SV & SetV & LV
    W --> SetVM
    DV --> DVM
    SV --> SVM
    SetV --> SetVM
    LV --> LVM

    DVM --> FP & TP & ES & PC
    SVM --> ES & PC & OA & SR
    SetVM --> KEY & UD
    LVM --> Logger

    FP --> FILE
    SR --> AppleSpeech
    ES --> OA
    OA --> OpenAI
    PC --> Pinecone
    KEY -.-> OA & PC
```

---

## Core Pipeline

This diagram shows the complete sequence of text extraction, semantic chunking, batch embeddings, similarity search, reranking, and generation with sources.

```mermaid
flowchart TD
    subgraph Ingestion["Ingestion & Vector Sync"]
        A[File Picked] --> B[Security-Scoped Sandbox Access]
        B --> C{File Type?}
        C -->|PDF| D[PDFKit Parser]
        C -->|Images| E[Vision OCR Engine]
        C -->|Text/Code| F[Raw String Read]
        D & E & F --> G[RecursiveTextSplitter]
        G --> H[MIME-Aware Chunks]
        H --> I[SHA256 Fingerprint Check]
        I -->|Unique| J[Batch Chunks of 50]
        J --> K[OpenAI Embeddings /v1/embeddings]
        K --> L[Upsert Vectors to Pinecone Namespace]
    end

    subgraph QueryRAG["Retrieval & Generation"]
        M[Query Input] --> N[Speech Transcription/Text]
        N --> O[Generate Query Vector]
        O --> P[Query Pinecone Index]
        P --> Q{Rerank Enabled?}
        Q -->|Yes| R[Pinecone Rerank API]
        Q -->|No| S[Retained top-K Chunks]
        R --> S
        S --> T[Context Packing & System Prompts]
        T --> U[OpenAI Responses SSE Stream]
        U --> V[Stream Grounded Answer with Citations]
    end
```

---

## Data Flow

This chart defines the boundaries between local device memory, Keychain credentials, the network payload transport layer, and external cloud APIs.

```mermaid
flowchart LR
    subgraph LocalDevice["On-Device boundary"]
        subgraph SafeStorage["Secure Storage"]
            KC[(Secure Enclave Keychain)]
        end
        subgraph PlainStorage["Unencrypted Space"]
            UD[(UserDefaults)]
            SB[(Sandbox Files)]
        end
        subgraph LogicMemory["Processing Memory"]
            MEM[OCR Autoreleasepool]
        end
    end

    subgraph Net["Network transport"]
        HTTPS[HTTPS REST / SSE Streams]
    end

    subgraph Cloud["External APIs"]
        OAI[OpenAI Cloud]
        PCN[Pinecone Cluster]
        APL[Apple Services]
    end

    %% Flows
    KC -->|Retrieve Keys| HTTPS
    UD -->|Read Preferences| LogicMemory
    SB -->|Load Documents| LogicMemory
    LogicMemory -->|Payload| HTTPS
    HTTPS -->|POST/GET| OAI & PCN & APL
```

---

## Ingestion / Processing / Retrieval Details

### Ingestion
OpenCone ingests documents via the iOS system document picker. Bookmarks are resolved dynamically with security permissions enabled (`startAccessingSecurityScopedResource`). Supported MIME types include standard office documents (`application/pdf`, `.docx`), data tables (`.csv`, `.json`), web layouts (`.html`, `.css`), markdown (`.md`), code scripts (`.py`, `.js`), and popular images (`.png`, `.jpeg`, `.tiff`).

### Processing
1. **Extraction**: Text is extracted locally using `PDFKit` page extraction or `Vision` framework OCR. Large processing loops are wrapped inside `autoreleasepool` to prevent memory leaks during mobile image OCR operations.
2. **Chunking**: Text is split recursively using `RecursiveTextSplitter`. Chunk sizes (default `1024` chars) and overlaps (default `256` chars) adapt based on file types.
3. **Hashing**: SHA256 hashes are calculated on document contents to guarantee ingestion idempotency. Files exceeding 100MB are rejected.
4. **Batching**: Vectors are created in batches of 50 to avoid API thread exhaustion.

### Retrieval / Querying
Search executes vector comparisons using the configured embedding model output. 
- **Hybrid Search**: Fuses dense query embeddings with sparse keyword vectors inside Pinecone using a configurable weighting slider (`alpha` from `0.0` to `1.0`).
- **Metadata Filters**: Restricts searches to namespaces, filenames, or custom tag structures using $eq, $in, $gte, $lte, and $contains operators.
- **Rerank**: Intercepts matches to run reranking (`bge-reranker-v2-m3` or Cohere) before context integration.

### Generation / Output
The grounded chunks are formatted as JSON text input and submitted to the OpenAI Responses API. Tokens stream into the chat view in real time via Server-Sent Events. The OpenAI `web_search` and `code_interpreter` tools are invoked conditionally using smart heuristics. Short-term dialogue context is maintained locally (client mode) or managed via OpenAI's server session states (server mode).

---

## Key Technical Decisions

| Decision | Rationale | Tradeoff |
|---|---|---|
| **Keychain for Keys** | Prevents developers or users from writing credentials to plain text configs. | Restricts automated simulator testing unless environment scheme overrides are supplied. |
| **Circuit Breaker** | Opens automatically after N network failures to prevent UI locks and API rate exhaustion. | Requires index switches or cooldown timers to reset. |
| **MIME-Aware Splitter** | Preserves logical structures (Markdown headers, JSON nodes) in chunks. | Increased parsing complexity per document type. |
| **Security Bookmarks** | Stores file references so documents can be re-accessed securely across launches. | Requires user storage provider permission consent. |
| **Autoreleasepool for OCR** | Manages high heap overhead of image recognition frames on memory-restricted iOS devices. | Slightly increases execution duration during serial processing. |
| **Speech Audio Tap** | Uses `AVAudioEngine` for low-latency voice streaming. | Demands microphone and speech recognition permissions. |
| **Host/Stats Caching** | Caches Pinecone cluster endpoints and namespace stats with short TTLs. | Brief delays (10s-30s) in reflecting out-of-band index changes. |

---

## File Entry Points

| Concern | Files | Responsibility |
|---|---|---|
| **App Entry** | [OpenConeApp.swift](OpenCone/App/OpenConeApp.swift) | Bootstrapping, AppState machine, and Release credential check. |
| **Main UI** | [MainView.swift](OpenCone/App/MainView.swift) | Tab routing (Search, Documents, Logs, Settings) and view-model synchronization. |
| **Ingestion View** | [DocumentsViewRedesign.swift](OpenCone/Features/Documents/DocumentsViewRedesign.swift) | Document list, dashboards, and bulk action triggers. |
| **Ingestion Engine** | [DocumentsViewModel.swift](OpenCone/Features/Documents/DocumentsViewModel.swift) | Pipeline scheduling, progress tracking, and bookmarks updates. |
| **API Clients** | [PineconeService.swift](OpenCone/Services/PineconeService.swift), [OpenAIService.swift](OpenCone/Services/OpenAIService.swift) | Low-level REST connections, retry logic, SSE parsing, and circuit breakers. |
| **Text Splitter** | [TextProcessorService.swift](OpenCone/Services/TextProcessorService.swift) | Content tokenization, recursive chunking, and hashing. |
| **Audio Capture** | [SpeechRecognitionService.swift](OpenCone/Services/SpeechRecognitionService.swift) | Speech-to-text translation and real-time amplitude tracking. |
| **Security Store** | [SecureSettingsStore.swift](OpenCone/Core/Security/SecureSettingsStore.swift) | Keychain storage for OpenAI/Pinecone keys and version settings. |
| **Unit Tests** | [SearchViewModelMetadataPersistenceTests.swift](OpenConeTests/SearchViewModelMetadataPersistenceTests.swift) | Validates filter settings storage and JSON parsing. |

---

## Configuration

| Setting | Storage | Default | Required | Purpose |
|---|---|---|---|---|
| `OPENAI_API_KEY` | Keychain | None | Yes | OpenAI API requests (embeddings & completions). |
| `PINECONE_API_KEY` | Keychain | None | Yes | Pinecone database request authorization. |
| `PINECONE_PROJECT_ID` | Keychain | None | Yes | Targets Pinecone host resolutions. |
| `PINECONE_CLOUD` | Keychain | `aws` | No | Target host environment configuration. |
| `PINECONE_REGION` | Keychain | `us-east-1` | No | Targets serverless regions. |
| `defaultChunkSize` | UserDefaults | `1024` | No | Character count limit for text segmentation. |
| `defaultChunkOverlap`| UserDefaults | `256` | No | Chunk duplication boundary. |
| `completionModel` | UserDefaults | `gpt-4o` | No | Model ID used for text completion. |
| `searchTopK` | UserDefaults | `10` | No | Nearest-neighbor vector counts retrieved. |
| `hybridAlpha` | UserDefaults | `0.5` | No | Sparse vs dense search weighting (`1.0`=semantic, `0.0`=keyword). |

---

## Getting Started

### Prerequisites
- macOS Sonoma or Sequoia
- Xcode 16.0+
- iOS 17.0+ Simulator or physical device
- Active OpenAI and Pinecone Accounts

### Developer Configuration Setup
1. **Clone the repository**:
   ```bash
   git clone https://github.com/Gunnarguy/OpenCone.git
   cd OpenCone
   open OpenCone.xcodeproj
   ```
2. **Configure schemes (optional for debug)**:
   Select **Product > Scheme > Edit Scheme... > Run > Arguments**. Add these environment variables:
   - `OPENAI_API_KEY`
   - `PINECONE_API_KEY`
   - `PINECONE_PROJECT_ID`

3. **Install Dependencies**:
   OpenCone relies on Apple's standard native frameworks (PDFKit, Vision, SFSpeechRecognizer) and integrates standard packages via Swift Package Manager (managed directly by Xcode). No Cocoapods or Carthage setups are necessary.

4. **Build and Run**:
   Press **Cmd+R** to build. If keys are missing, the guided welcome flow validation will assist with Keychain entries.

---

## Testing and QA

| Validation | Command / Procedure | Expected Result |
|---|---|---|
| **Build Project** | `xcodebuild -project OpenCone.xcodeproj -scheme OpenCone -destination "platform=iOS Simulator,name=iPhone 16" build` | Compilation completes with no errors. |
| **Unit Tests** | `xcodebuild test -project OpenCone.xcodeproj -scheme OpenCone -destination "platform=iOS Simulator,name=iPhone 16" -quiet` | All unit tests pass successfully. |
| **Secret Scan** | `python3 scripts/secret_scan.py` | Prints `✅ No secret patterns detected.` and exits with code 0. |
| **Preflight check** | `scripts/preflight_check.sh` | Performs all scans, Plist verification, and runs tests. |
| **Manual Ingestion** | Run app, pick a PDF/image, inspect logs in Logs tab | Ingestion log shows success and vector counts update on dashboard. |
| **Manual RAG Search** | Enter query matching ingested file, inspect citations | Streams completion citing source names and chunks. |

---

## Privacy and Security
- **Local Sandbox**: Documents, bookmark descriptions, extraction steps, and logging occur strictly in the app sandbox.
- **Network Boundaries**: Only chunk strings are sent to OpenAI (embeddings API) and matching metadata is uploaded to Pinecone (DB API).
- **Credentials Enclave**: Keys reside in the Enclave Keychain. Release builds throw a `fatalError` if secrets are hardcoded in variables.
- **Data Disposal**: Users can delete individual docs (clearing vector entries from Pinecone) or execute a full clean slate from **Settings > Data & Privacy > Reset Stored Keys & Preferences**.

*For more details, see [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md).*

---

## Documentation Index

| Document | Purpose |
|---|---|
| [README.md](README.md) | Main project overview, features, architecture overview, and onboarding instructions. |
| [ARCHITECTURE.md](ARCHITECTURE.md) | In-depth technical systems design, service lifecycle description, and networking models. |
| [ROADMAP.md](ROADMAP.md) | Current project trajectory, known technical debt, and pending milestones. |
| [SECURITY.md](SECURITY.md) | Secure Settings Store Keychain mappings and production archive protection policies. |
| [PRIVACY.md](PRIVACY.md) | Privacy guidelines, on-device boundaries, and external APIs data disclosures. |
| [APP_STORE.md](APP_STORE.md) | App Store descriptions, screenshots staging guide, and App Review test credentials. |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Engineering guides, coding standards, branch conventions, and agent instructions. |
| [docs/CASE_STUDY.md](docs/CASE_STUDY.md) | Technical case study highlighting architecture trade-offs, solutions, and outcomes. |

---

## Roadmap

### Completed
- [x] On-device multi-format text extraction (PDF, text, images with Vision OCR).
- [x] Secure Settings Store Keychain integration and release-build secret safeguards.
- [x] Speech Recognition service integration with dynamic level animation.
- [x] Circuit breaker logic, exponential backoff retries, and rate limits for Pinecone query robustness.
- [x] Two-stage RAG queries supporting hybrid retrieval and reranking.

### In Progress
- [ ] Automated integration test coverage for streaming completions.
- [ ] Circuit breaker user status notifications.

### Planned
- [ ] Local embedding caching to avoid redundant OpenAI API calls.
- [ ] Bookmark-aware file update detection.
- [ ] Spotlights indexing for ingested document records.

---

## License
OpenCone is distributed under the [MIT License](LICENSE).
