# Codebase Summary

## Overview
OpenCone is a SwiftUI iOS/macOS application for Retrieval Augmented Generation (RAG). It processes documents, creates vector embeddings, stores them in Pinecone, and enables semantic search with AI-generated answers. The app now uses the OpenAI Responses API for text generation with support for reasoning and non-reasoning model families, including streaming output.

## Key Components and Their Interactions
### App
- `OpenConeApp.swift`: Main application entry. Orchestrates setup flow, validates keys, initializes services, and injects view models.
- `MainView.swift`: Root tabbed UI hosting Search, Documents, Logs, and Settings.
- `WelcomeView.swift`: First-run/configuration flow for entering API keys.

### Core
- `Configuration.swift`: Central configuration. Now includes:
  - `reasoningModels` set and `isReasoningModel(_:)` to gate model capabilities (includes `gpt-5`).
  - Embedding/completion defaults, chunk sizing, and Pinecone config.
- `Logger.swift`, `ProcessingLogEntry.swift`: Logging structures and levels.
- `Extensions/`: Utility extensions used throughout the app.
- Design System (`Core/DesignSystem/*`): Theming and visual components.

### Features
- `Documents/`: Management of uploaded/processed documents.
  - `DocumentModel+ViewHelpers.swift` provides display helpers for icon/color/file size used by the views.
  - `DocumentsView.swift`, `DocumentsViewModel.swift`, `DocumentDetailsView.swift`, `DocumentPicker.swift`.
- `ProcessingLog/`: Processing and operational logs.
  - `ProcessingView.swift`, `ProcessingViewModel.swift`.
- `Search/`: Search over embeddings with streamed AI answers.
  - `SearchView.swift`: Main search view with Quick Switcher and chat UI. Shows inline error banner; input bar supports Stop to cancel active streaming. Adds “New Topic” button to start a fresh server-managed thread.
  - `SearchViewModel.swift`: Coordinates embedding query, Pinecone retrieval, context assembly, and streamed AI answer updates into chat; manages `.streaming` state and cancellation. Threading modes:
    - Server-managed: passes `conversationId` on all calls; provides `newTopic()` to rotate the thread
    - Client-bounded: sends trimmed prior finalized turns via the history builder
  - `Models/ChatModels.swift`: Shared chat domain models (`ChatRole`, `MessageStatus`, `ChatMessage` with status/timestamps/error).
  - `Components/ChatBubble.swift`: Displays chat messages with optional citations; renders streaming (typing), normal, and error states.
  - `Components/TypingBubble.swift`: Animated typing indicator shown while assistant is streaming but no text yet.
  - `Components/ChatInputBar.swift`: Input area for chat queries; shows Send or Stop based on streaming state.
- `Settings/`: Configuration and preferences.
  - `SettingsViewModel.swift`: Now includes `temperature`, `topP`, `reasoningEffort`, `isReasoning`, with persistence. Offers model list including `gpt-5`.
  - `SettingsView.swift`: Conditionally renders Reasoning Effort (for reasoning models) or Temperature/Top P (for non-reasoning).

### Services
- `EmbeddingService.swift`: Generates embeddings via OpenAI embedding endpoint.
- `PineconeService.swift`: Lists indexes, namespaces, queries vectors; adds preflight `healthCheck()` and a circuit breaker to avoid calls while the host is unhealthy.
- `OpenAIService.swift`: Integration with OpenAI. Recent changes:
  - Migrated to `/v1/responses` for text generation.
  - Builds structured `input` (system/user `input_text` entries).
  - Conditional parameters:
    - Reasoning models (e.g., `gpt-5`): `{ "reasoning": { "effort": "low|medium|high" } }`
    - Non-reasoning models (e.g., `gpt-4o`, `gpt-4o-mini`): `temperature`, `top_p`
  - Reads selected model and generation params from `UserDefaults` so Settings changes apply after save.
  - Added `streamCompletion(...)` SSE method, parsing `response.output_text.delta` and `response.completed`; loop is cancellation-aware.
  - Conversation support:
    - Client-bounded memory: bounded history (last ~8 finalized messages) embedded via a builder; `generateCompletion` and `streamCompletion` accept `history`
    - Server-managed threads: optional `conversation` field included when provided; both APIs accept `conversationId` to enable Responses-managed threading

## Data Flow
1) Documents:
   - User adds documents -> `FileProcessorService` extracts text -> `TextProcessorService` chunks -> `EmbeddingService` creates vectors -> `PineconeService` upserts.
2) Search:
   - User asks a question in Search view -> `EmbeddingService` creates embedding for query -> `PineconeService` returns top-K matches -> `SearchViewModel` assembles a context string with citations -> `OpenAIService` sends Responses API request.
   - If streaming, `SearchViewModel` appends an empty assistant message, then updates `generatedAnswer` and the assistant message text incrementally as `response.output_text.delta` arrives; on `response.completed`, adds citations and finalizes UI.
3) Settings:
   - User selects a completion model and configures generation parameters.
   - `SettingsViewModel` persists to `UserDefaults`. `OpenAIService` reads them dynamically for subsequent requests.
   - UI gates Reasoning Effort vs Temperature/Top P based on `Configuration.isReasoningModel(_:)`.

## External Dependencies
- OpenAI
  - Embeddings: `/v1/embeddings`
  - Text generation: `/v1/responses` (structured `input`, conditional params, SSE streaming)
- Pinecone
  - Vector DB for semantic search (indexes, namespaces, queries)

## Recent Significant Changes
- Migrated generation from Chat Completions-style to OpenAI Responses API.
- Added bounded multi-turn conversation memory to Requests; history is trimmed and excludes the in-flight user message.
- Added server-managed conversation threads (Responses “conversation” field) with a New Topic control and a Settings toggle to choose threading mode.
- Added support for reasoning-capable models (e.g., `gpt-5`) with `reasoning.effort`.
- Preserved support for non-reasoning models with `temperature` and `top_p`.
- Implemented SSE streaming in `OpenAIService.streamCompletion` and wired it into `SearchViewModel` to stream answer text into the chat UI.
- Extended `SettingsViewModel` with `temperature`, `topP`, `reasoningEffort`, `isReasoning`; added `gpt-5` to completion model list.
- Updated `SettingsView` to conditionally render Reasoning Effort vs Temperature/Top P controls.
- `Configuration.swift` now contains a capability map via `isReasoningModel(_:)`.
- Modernized chat UI: removed blocking full-screen overlay during generation; added typing indicator, error bubble styling, and cancel streaming support.
- Added inline error banner in `SearchView` to surface user-facing errors originating from Pinecone/OpenAI/network.
- Added Pinecone preflight health check and circuit breaker in `PineconeService`.
- Added per-search traceId logging in `SearchViewModel` and auto-dismiss error banner UX.

## User Feedback Integration
- Pending: copy improvements in Settings to clarify differences between reasoning and non-reasoning models, and when saving is required for changes to apply.
- Pending: additional inline help or tooltips for streaming behavior and token limits.

## Additional Documentation
- `cline_docs/projectRoadmap.md`: Updated goals, features, and progress focused on Responses API migration and streaming.
- `cline_docs/currentTask.md`: Active objective and testing guide for verifying reasoning vs non-reasoning flows, streaming behavior, and conversation continuity (server-managed and client-bounded).
- `cline_docs/userInstructions/run_and_test_conversation_memory.md`: Step-by-step guide to run the app and validate multi-turn behavior, server-managed threads vs client-bounded mode, and fallbacks.
- This document (`codebaseSummary.md`) updated to reflect architecture and recent changes.
