# OpenCone Privacy Policy

**Last updated:** 2026-10-01

This policy describes OpenCone 3.1, in App Review since 2026-10-01. In 3.0, the version on the App Store now, the routing request in section 2 doesn't happen (3.0 searches the index you pick), the activity log is the Logs tab, there's no Endpoints screen, and the reset is under **Settings > Data & Privacy > Reset All Data**.

OpenCone is a native RAG (Retrieval-Augmented Generation) client designed with a strong focus on privacy. This policy outlines how local files, metadata segments, and API authorization keys are processed, cached, and transmitted.

---

## 1. On-Device Processing Boundary

OpenCone runs the majority of its ingestion and synchronization pipelines directly on your iOS device:
- **Sandbox File Copies**: When you select documents, they are copied into the app's local sandbox storage directory. The app creates security-scoped bookmarks to retain access without writing to outside folders.
- **Local Text Extraction**: Conversion of formats (PDFs, plain text files) into raw text strings is executed completely on-device using iOS frameworks (e.g. `PDFKit`).
- **Microphone Transcription**: Voice input uses Apple's Speech framework with server recognition allowed (`requiresOnDeviceRecognition = false`), so your audio may be sent to Apple to transcribe.

---

## 2. Remote API Scopes & Data Transit

OpenCone communicates with third-party service providers only when necessary to perform semantic search, indexing, or generation functions:

| Destination | Data Transmitted | Purpose | Encryption & Retention |
|---|---|---|---|
| **OpenAI API** (`/v1/embeddings`) | Batched text chunks (excluding raw document frames or identifiers). | Generates 3072-dimension vectors. | HTTPS. OpenAI processes requests statefully according to their API data-usage agreements. |
| **OpenAI API** (`/v1/responses`) | RAG context package: OpenCone's instructions, the relevant passages, your question, and your last exchanges from this conversation (4 by default; 0 to 20 under Settings > Answers > Memory). With web search on, OpenAI searches the web for the answer, only on the sites you list when you list any. | Generates streamed token responses. | HTTPS, sent with `store: false`, so OpenAI keeps no conversation between questions. Data is not permanently retained by OpenCone. |
| **OpenAI API** (`/v1/responses`), routing | When Ask > Where to search is Auto and you have two or more indexes or namespaces: your question, recent chat history, the names of your indexes and namespaces, their passage counts, and each index's one-line summary. With Auto or Everything, to draft each index's summary: up to 8 sample passages from that index and its namespace names. Everything itself makes no routing call. | Picks which indexes and namespaces to search, and drafts each index's summary. | HTTPS, sent with `store: false`. Summaries and index details are kept on your iPhone. |
| **OpenAI API** (`/v1/models`) | Your OpenAI key, once per launch. | Lists the models your account can use and their shutdown dates, so the model menu shows newer models and a model about to shut down is replaced. | HTTPS. The list is kept on your iPhone. |
| **OpenAI's docs site** (`developers.openai.com/api/docs/models/<model>.md`) | Only the model's name, in the page address. No key, no personal data, no chat content. At most 3 pages per launch, each read again after 7 days. | Reads the reasoning settings of a newer model on your account that the app's built-in list doesn't name. | HTTPS. What it reads is kept on your iPhone. |
| **OpenAI API** (`/v1/embeddings`), model check | One stored passage per index, embedded with each OpenAI model that fits the index's size. | Learns which model built each index, so questions are embedded to match it. | HTTPS. The result is kept on your iPhone. |
| **Pinecone DB** | Float vectors plus each chunk's full text, a preview, the file name, the file's path on your iPhone, segment ranges, and document identifiers. | Similarity matching and index storage. | HTTPS. Stored inside your serverless Pinecone indexes. |
| **Apple Speech Services** | Your recorded audio, when you use voice input. | Transcribes speech to query text. | HTTPS. The app allows server recognition, so Apple may transcribe on its servers even when an on-device model exists. |

OpenCone does **not** host any intermediary collection servers. All network transactions travel directly from your iOS client to the destination endpoints.

---

## 3. Credentials & Keys Storage

- Users configure and provide their own personal API keys.
- Keys are written directly to the secure iOS Keychain via `SecureSettingsStore`.
- Credentials are never stored in unencrypted plist files, configuration variables, or `UserDefaults` caches.

---

## 4. Telemetry & Telemetry Boundaries

- OpenCone does **not** contain third-party analytics trackers, advertising SDKs, or remote crash reporting libraries.
- Diagnostic log items (e.g. status changes, pipeline speeds) are written solely to a local memory buffer accessible under **Settings > Advanced > Activity log**. The app never uploads these logs; they leave the device only if you copy or share them from there.
- **Settings > Advanced > Endpoints** counts the requests made since OpenCone opened: for each, which endpoint, its HTTP status and how long it took. No addresses, questions, passages or keys are kept, the record lives only in memory, and it is never uploaded.

---

## 5. Data Disposal & User Controls

Users have complete control over their local data, keys, and cloud records:
- **Document Removal**: Deleting a document inside OpenCone deletes the sandbox file copy and triggers a batch delete request to remove the associated vector indexes from Pinecone.
- **Session Wipe**: Clearing chat logs deletes dialogue histories.
- **Application Reset**: Under **Settings > General > Remove keys and reset everything**, users can wipe all Keychain credentials, clear cache values, and reset the sandbox directories, returning the app to its original onboarding state.

---

## 6. App Store Privacy Declarations

When publishing or testing OpenCone on App Store Connect, use the following configuration settings:

- **Data Collection**: Declare that you collect "User Content" (Text input/queries) and "Identifiers" (API configuration keys) *only* as configured and dispatched by the user.
- **Data Linkage**: Declare that data collected is not linked to the user's identity, as the app does not create accounts or associate data with specific users.
- **Third-Party Disclosures**: Disclose data transmission to OpenAI, Pinecone, and Apple Speech services.
