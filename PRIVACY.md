# OpenCone Privacy Policy

**Last updated:** 2026-05-29

OpenCone is a local-first, native RAG (Retrieval-Augmented Generation) client designed with a strong focus on privacy. This policy outlines how local files, metadata segments, and API authorization keys are processed, cached, and transmitted.

---

## 1. On-Device Processing Boundary

OpenCone runs the majority of its ingestion and synchronization pipelines directly on your iOS device:
- **Sandbox File Copies**: When you select documents, they are copied into the app's local sandbox storage directory. The app creates security-scoped bookmarks to retain access without writing to outside folders.
- **Local Text Extraction**: Conversion of formats (PDFs, plain text files) into raw text strings is executed completely on-device using iOS frameworks (e.g. `PDFKit`).
- **Local OCR Processing**: Native Vision-based OCR runs locally to recognize text structures in images (PNG, JPEG, TIFF) without sending files to image-processing cloud endpoints.
- **Microphone Transcription**: Voice transcription uses Apple's native Speech APIs. Processing is handled locally on the device hardware when supported.

---

## 2. Remote API Scopes & Data Transit

OpenCone communicates with third-party service providers only when necessary to perform semantic search, indexing, or generation functions:

| Destination | Data Transmitted | Purpose | Encryption & Retention |
|---|---|---|---|
| **OpenAI API** (`/v1/embeddings`) | Batched text chunks (excluding raw document frames or identifiers). | Generates 3072-dimension vectors. | HTTPS (TLS 1.3). OpenAI processes requests statefully according to their API data-usage agreements. |
| **OpenAI API** (`/v1/responses`) | RAG context package (composed prompt template containing relevant text chunks + chat history). | Generates streamed token responses. | HTTPS (TLS 1.3). Stateless transaction. Data is not permanently retained by OpenCone. |
| **Pinecone DB** | Float vectors, segment ranges, file names, and doc identifiers. | Similarity matching and index storage. | HTTPS (TLS 1.3). Stored inside your serverless Pinecone indexes. |
| **Apple Speech Services** | Raw audio coordinates. | Transcribes speech to query text. | HTTPS (TLS 1.2+). Apple processes audio streams to convert speech to text when local engine models are unavailable. |

OpenCone does **not** host any intermediary collection servers. All network transactions travel directly from your iOS client to the destination endpoints.

---

## 3. Credentials & Keys Storage

- Users configure and provide their own personal API keys.
- Keys are written directly to the secure iOS Keychain (Secure Enclave) via `SecureSettingsStore`.
- Credentials are never stored in unencrypted plist files, configuration variables, or `UserDefaults` caches.

---

## 4. Telemetry & Telemetry Boundaries

- OpenCone does **not** contain third-party analytics trackers, advertising SDKs, or remote crash reporting libraries.
- Diagnostic log items (e.g. status changes, pipeline speeds) are written solely to a local memory buffer accessible under the **Logs** tab. These logs never leave the device.

---

## 5. Data Disposal & User Controls

Users have complete control over their local data, keys, and cloud records:
- **Document Removal**: Deleting a document inside OpenCone deletes the sandbox file copy and triggers a batch delete request to remove the associated vector indexes from Pinecone.
- **Session Wipe**: Clearing chat logs deletes dialogue histories.
- **Application Reset**: Under **Settings > Data & Privacy > Reset Stored Keys & Preferences**, users can wipe all Keychain credentials, clear cache values, and reset the sandbox directories, returning the app to its original onboarding state.

---

## 6. App Store Privacy Declarations

When publishing or testing OpenCone on App Store Connect, use the following configuration settings:

- **Data Collection**: Declare that you collect "User Content" (Text input/queries) and "Identifiers" (API configuration keys) *only* as configured and dispatched by the user.
- **Data Linkage**: Declare that data collected is not linked to the user's identity, as the app does not create accounts or associate data with specific users.
- **Third-Party Disclosures**: Disclose data transmission to OpenAI, Pinecone, and Apple Speech services.
