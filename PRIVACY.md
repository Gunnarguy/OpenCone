# OpenCone Privacy Overview

_Last updated: 2025-11-11_

OpenCone is a retrieval-augmented generation (RAG) client that lets you search your own documents using OpenAI completions and Pinecone vector search. This document describes the data flows involved so you can answer the App Store privacy questionnaire and inform reviewers and end users.

## On-Device Processing

- Source documents you import are copied into the application sandbox for indexing.
- Text extraction runs locally using PDFKit, Vision OCR, and native text utilities.
- Embedding generation queues work on a background thread; logs only record high-level status and anonymized identifiers.
- Security-scoped bookmarks created for your original files stay on-device and are stored in the Keychain.

## Data Sent Off Device

| Destination | Data | Purpose | Notes |
|-------------|------|---------|-------|
| OpenAI Responses API | Conversation history (user prompt + retrieved snippets) | Generate natural-language answers | Transmitted over HTTPS; no data stored by OpenCone after the request completes. |
| OpenAI Embeddings API | Chunked text generated from your documents | Produce vector embeddings for Pinecone | Only the text chunks being embedded are sent. |
| Pinecone Vector DB | Embedding vectors and metadata (document identifier, file name, up to 200-char preview) | Similarity search | Encrypted in transit; metadata excludes raw document bodies. |

## Keys & Authentication

- Users supply their own OpenAI and Pinecone API keys via the in-app onboarding flow.
- Keys are written to the Secure Enclave-backed Keychain and never bundled with the app.
- A Release build guard blocks launch if keys are missing.

## Retention & Deletion

- Removing a document in OpenCone deletes the sandbox copy and requests deletion of associated vectors from Pinecone.
- Clearing conversation history removes cached completions; requests to OpenAI are stateless.
- You can reset all stored data from Settings → Advanced → Reset App.

## Analytics & Tracking

- OpenCone does **not** use third-party analytics, crash reporters, or advertising SDKs.
- Only local diagnostic logs (viewable in the Logs tab) are retained on-device.

## User Consent & Transparency

- The first time you import a file, OpenCone explains that it creates a sandbox copy and may upload derived text to your configured services.
- Settings provide a link back to this document and instructions for revoking storage provider access.

## Contact

For privacy questions or data deletion help, email [support@opencone.app](mailto:support@opencone.app).
