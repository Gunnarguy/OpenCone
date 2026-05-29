# Case Study: OpenCone

On-device Retrieval-Augmented Generation (RAG) sandbox client for Apple iOS, iPadOS, and macOS via Catalyst.

---

## Problem

Modern generative AI applications are heavily dependent on cloud-based middleware (like LangChain, LlamaIndex, or cloud vector-database dashboards) to execute document extraction, semantic chunking, and similarity searches. This cloud-centric setup poses two major hurdles:
1. **User Privacy**: Handling sensitive files (such as legal contracts, research notes, or personal correspondence) on remote servers introduces compliance and privacy concerns.
2. **Infrastructure Costs**: Maintaining middle-tier databases, vector hosting engines, and processing workers requires continuous operational overhead and budget monitoring.

OpenCone was designed to prove that a **complete, high-performance RAG pipeline can be run entirely on-device** using Swift and native iOS frameworks. By keeping file ingestion, OCR extraction, text tokenization, and query coordination local, OpenCone respects privacy, reduces backend costs, and operates directly as a native mobile application.

---

## Constraints

Building an on-device RAG system on iOS presented severe engineering constraints:
- **Restricted Sandbox Permissions**: iOS sandboxing strictly limits file access. If a user imports a document, those access privileges expire when the app process is terminated unless specific security protocols are implemented.
- **Hardware Resource Limits**: Apple mobile devices have restricted CPU cores and volatile memory (RAM) budgets compared to cloud servers. Running OCR extraction models or serial embedding requests on thousands of pages can lead to system memory termination.
- **Network Unreliability**: Mobile network connections drop frequently. Embedding vectors or streaming answers over a volatile connection can cause UI freezes, API timeout failures, or duplicate vector upserts.

---

## Architecture

OpenCone implements a strict **MVVM-S (Model-View-ViewModel-Service)** architecture, driven by a central App State Machine:

- **App State Machine**: Transition logic inside `OpenConeApp` coordinates app startup, onboard validations, the main workspace, and error views.
- **Decoupled ViewModels**: Features (Search, Ingestion, Settings, and Logs) have isolated ViewModels that manage state properties (using Combine `@Published` syntax).
- **Stateless Services Layer**:
  - `FileProcessorService` uses local native libraries (`PDFKit`, `Vision` OCR) to parse document types.
  - `TextProcessorService` tokenizes and chunkifies raw text recursively using MIME boundary rules.
  - `EmbeddingService` coordinates batch vectors creation via OpenAI API clients.
  - `PineconeService` runs index CRUD, similarity queries, and deletion requests.
  - `SpeechRecognitionService` connects native Apple Speech audio taps with responsive visual waveforms.
  - `SecureSettingsStore` isolates sensitive keys in the Keychain, separating configurations from `UserDefaults`.

---

## Key Technical Challenges

### 1. Persistent Sandbox Permissions
**Challenge**: When users import files, sandbox URLs lose read rights once the application process terminates. The app cannot re-parse or sync documents without asking the user for manual permission again.
**Solution**: OpenCone implements security-scoped bookmarks. The app copies documents into its own sandbox folder and builds bookmark datas. These bookmark structures are saved in the database model and re-activated (`startAccessingSecurityScopedResource`) during index synchronization or file re-extraction.

### 2. OCR Memory Overhead
**Challenge**: Processing large images or scanned PDFs on iOS using `VNRecognizeTextRequest` generates native buffer allocations, creating high heap spikes that trigger iOS Out-Of-Memory (OOM) app crashes.
**Solution**: The `FileProcessorService` wraps individual page extractions inside serial `autoreleasepool` blocks. This ensures native memory buffers and recognized text frames are freed immediately after page parsing completes rather than waiting for the entire loop to finish.

### 3. API Throttling & Connection Interruptions
**Challenge**: Sending hundreds of vectors to Pinecone or requesting streaming answers can fail due to rate limits (429 status codes) or connection dropouts, causing UI hangs or vector store corruption.
**Solution**: OpenCone integrates:
1. **Exponential Backoff**: Up to 3 retry loops with sleeping intervals for transient faults.
2. **Circuit Breaker**: Trips the network connection state to open in `PineconeService` when consecutive errors exceed limits, preventing server flooding.
3. **SSE Watchdog**: Monitors OpenAI response stream tokens. If no token delta is received within 30 seconds, it cancels the task to save battery and shows a recovery prompt.

---

## Tradeoffs

- **OCR Speed vs Cloud Ingestion**: Local image text extraction takes more time on-device than pushing images to a cloud OCR server. We prioritized user privacy over high-speed throughput.
- **No Offline Embeddings**: The app relies on OpenAI's remote Embeddings API, meaning it requires an internet connection to ingest new documents or query indexes. This tradeoff was made to keep the bundle size small (avoiding bundling massive on-device transformer models).
- **Unencrypted Local Sandbox Cache**: While files are isolated within the sandbox, the raw text is cached in the app folder. We rely on the device-level passcode encryption framework to secure these caches, requiring users to enforce password lockouts.

---

## Outcome

OpenCone implements a production-grade, local-first RAG architecture on iOS with the following metrics:

- **APIs Integrated**: 3 major external systems (OpenAI completions, OpenAI embeddings, Pinecone serverless DB) and 3 native Apple frameworks (Vision OCR, PDFKit parsing, SFSpeechRecognizer).
- **Supported Formats**: 12 MIME types (PDF, DOCX, TXT, HTML, CSS, Markdown, JSON, XML, CSV, TSV, RTF, PNG, JPEG, TIFF).
- **Architecture Layers**: 4 decoupled layers (UI presentation, ViewModel coordinators, Service utility engines, and Enclave Keychain storage).
- **Resilience Controls**: Circuit breaker limits, exponential retry backoff delays, rate-limit sleep thresholds, and SSE timeout watchdogs.

---

## What I Would Improve Next

1. **Local Transformers**: Integrate a tiny local embedding model (like ONNX runtime or CoreML-optimized models) to allow fully offline embeddings and query encoding.
2. **Bulk Processing Queue**: Implement a concurrent background processing worker queue to parse multiple documents in parallel safely.
3. **Structured Vector Databases**: Add support for local vector stores (e.g. GRDB or SQLite vector extensions) to allow offline searches.
