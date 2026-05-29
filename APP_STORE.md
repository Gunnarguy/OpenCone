# App Store Submission Guide

**Last updated:** 2026-05-29

This document details the copy assets, keywords, reviewer credentials, screenshot guidelines, and submission steps required for deploying OpenCone to the Apple App Store.

---

## 1. App Store Copy Metadata

### Promotional Text
*170 characters max*
> Turn every file on your device into a private, semantic search workspace with local text extraction, Pinecone vector indexing, and streaming OpenAI answers.

### Description
*4,000 characters max*
> OpenCone is a native, privacy-first client that puts a complete Retrieval-Augmented Generation (RAG) pipeline directly on your iPhone, iPad, or Mac via Catalyst. Simply input your OpenAI and Pinecone API credentials to build a secure, searchable local knowledge base.
> 
> COMPLETE DOCUMENT PIPELINE
> - Multi-Format Processing: Import PDFs, Word documents (DOCX), plain text, Markdown, HTML, JSON, CSV, and code files into a secure local sandbox.
> - On-Device OCR: Uses Apple's Vision framework to run text recognition locally on images (PNG, JPEG, TIFF).
> - MIME-Aware Chunking: Automatically segments text into semantically cohesive chunks using recursive splitters with custom sizes and overlaps.
> - Sandbox Bookmarks: Stores security-scoped bookmarks to retain file read access across app launches without annoying prompts.
> - Fingerprint Deduplication: Pre-calculates SHA256 hashes to prevent duplicate file uploads and conserve index space.
> 
> SEMANTIC SEARCH WITH CITATIONS
> - Vector Lookup: Converts your queries into embeddings and runs similarity queries against Pinecone index namespaces.
> - Hybrid Retrieval: Balance dense semantic matches and sparse keyword lists using a simple alpha slider.
> - Advanced Reranking: Refines retrieval precision using Cohere, BGE, or Pinecone inference models.
> - Citation Sources: Reviews the exact chunks matched, showing file names, status ranges, and metadata properties.
> - Real-Time Streaming: Tokens stream into your chat window via Server-Sent Events (SSE) for instant, fluid answers.
> 
> NEXT-GEN REASONING SUPPORT
> - GPT-5 & Reasoning Models: Full support for GPT-5.2 and OpenAI reasoning endpoints.
> - Dynamic UI Controls: Automatically toggles between reasoning effort (Low, Medium, High) for reasoning models and temperature/top-p sliders for standard completions.
> 
> SECURITY & PRIVACY
> - Credentials Enclave: API keys reside in the secure Keychain and are never written to unencrypted folders.
> - Safe Telemetry: Logs reside in a local memory buffer and can be cleared instantly. No third-party trackers are integrated.
> - Application Purge: A dedicated reset action wipes Keychain keys, bookmarks, and local sandbox caches.
> 
> POLISHED SWIFTUI EXPERIENCE
> - Speech Recognition: Integrated voice query input using Apple's Speech Recognition framework with responsive waveform animations.
> - Structured Logging: Track pipelines in real time via the local Logs interface.
> - Alternate Themes: Supports clean Light and Dark modes with responsive styling.
> - Fast UI Architectures: Reactive MVVM-S patterns keep scrolling fluid during background operations.

### Keywords
*100 characters max total, comma-separated, no spaces*
`RAG,AI,OpenAI,GPT-5,Pinecone,semantic,search,OCR,vector,database,on-device,speech,iOS,iPadOS,Catalyst`

---

## 2. App Review Team Notes

Dear App Review Team,

OpenCone is a document-centric retrieval-augmented generation (RAG) utility. It runs local file extraction and OCR, uploads text embeddings to the user's Pinecone database, and queries those records to stream grounded answers.

### Test Credentials
We have provisioned sandbox environment keys for the review process:
- **OpenAI API Key**: *[Provided in App Store Connect review credentials panel]*
- **Pinecone API Key**: *[Provided in App Store Connect review credentials panel]*
- **Pinecone Project ID**: *[Provided in App Store Connect review credentials panel]*

Please paste these keys into the onboarding screen upon launching the app.

### Verification Walkthrough
1. Select the **Documents** tab and tap the **+** button.
2. Ingest the sample PDF attached to this submission.
3. Wait for the progress indicator to complete (processing states can be monitored in the **Logs** tab).
4. Select the **Search** tab.
5. Enter a test query such as: *"Summarize the ingested file content"*
6. Verify that the answer streams in and lists the document source card in the citation panel.
7. Switch to the **Settings** tab and tap **Reset Stored Keys & Preferences** to verify data is deleted.

---

## 3. Screenshot Capture Guide

### Simulator Setup
- target device: **iPhone 17 Pro Max** (for 6.7" App Store requirements).
- Ensure credentials are authenticated in debug mode.

### Execution
Run the automated capture script:
```bash
./scripts/capture_screenshots.sh Screenshots/
```
The script prompts you to stage the simulator screens, capturing the screenshots sequentially:
1. `welcome.png` — Onboarding screen showing credential validation.
2. `documents.png` — Documents Redesign tab showcasing metrics and file tiles.
3. `processing.png` — Real-time processing logs demonstrating extraction stats.
4. `search.png` — Active streaming search view illustrating answer text and citations.

---

## 4. Submission Checklist

### Build & Archiving
- [ ] Run `./scripts/preflight_check.sh` and ensure all unit tests pass.
- [ ] Confirm no environment scheme secrets are checked in.
- [ ] Run `scripts/generate_app_icons.sh` to compile necessary app icon sizes.
- [ ] Build and archive the target inside Xcode.

### Metadata Delivery
- [ ] Upload screenshots to App Store Connect.
- [ ] Populate Promotional Text, Description, and Keywords.
- [ ] Paste Support URL: `https://github.com/Gunnarguy/OpenCone`
- [ ] Copy Privacy Policy URL: `https://github.com/Gunnarguy/OpenCone/blob/main/PRIVACY.md`
- [ ] Attach reviewer credentials and the sample testing PDF document.
