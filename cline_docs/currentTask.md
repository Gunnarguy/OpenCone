# Current Task

## Objective
- Validate and finalize the migration to OpenAI Responses API with GPT-5 reasoning model support, SSE streaming, and conversation continuity, including:
  - Server-managed conversation threads via the Responses API “conversation” field
  - Client-bounded multi-turn memory as a fallback
- Ensure Settings conditionally expose Reasoning Effort vs Temperature/Top P and that both model types work end-to-end.

## Context
- The app previously used Chat Completions-style payloads. We migrated generation to the Responses API with structured `input`, added model capability detection, and introduced SSE streaming to the chat UI.
- Reasoning vs non-reasoning model parameters now differ:
  - Reasoning: `reasoning.effort` (low|medium|high)
  - Non-reasoning: `temperature`, `top_p`
- Settings persist generation parameters in `UserDefaults`. `OpenAIService` reads the selected model and parameters dynamically so changes take effect after saving settings.

## Changes Implemented
- Configuration
  - `Configuration.isReasoningModel(_:)` and `reasoningModels` includes `gpt-5`.
- Settings
  - `SettingsViewModel`: added `temperature`, `topP`, `reasoningEffort`, `isReasoning`, persistence and defaults; added `gpt-5` to completion models.
  - Conversation Mode toggle:
    - `SettingsViewModel`: `conversationMode` persisted in UserDefaults (`server` vs `client`)
    - `SettingsView`: segmented control to choose Server-managed (OpenAI) vs Client-bounded (Local) modes with help text
  - `SettingsView`: conditional UI to show Reasoning Effort for reasoning models; Temperature/Top P for others.
- OpenAIService
  - Using `/v1/responses` with structured `input`.
  - Conditional request params based on selected model and Settings.
  - `streamCompletion(...)` parses `response.output_text.delta` and `response.completed` SSE events.
  - Conversation support:
    - Client-bounded history builder (last ~8 finalized messages) for coherence
    - Server-managed threads: optional `conversation` field sent when enabled
    - Public APIs accept `history` and `conversationId` for both streaming and non-streaming paths
- Search UI unification and modernization
  - Added `Features/Search/Models/ChatModels.swift` with `ChatRole`, `MessageStatus`, `ChatMessage` (status, timestamps, error field).
  - Reworked `SearchViewModel` to:
    - Mark assistant message as `.streaming` until first delta, then `.normal`
    - Manage a `currentStreamTask` and `cancelActiveSearch()` for Stop support
    - Remove full-screen overlay reliance; keep transcript visible with typing state
    - Set `errorMessage` for top error banner
    - Threading:
      - Include bounded conversation history when in Client-bounded mode
      - Pass `conversationId` when in Server-managed mode
      - Added `newTopic()` to start a fresh server-managed thread (resets transcript + `conversationId`)
  - UI components:
    - `TypingBubble` shows animated typing indicator instead of empty gray bubble
    - `ChatBubble` renders streaming, normal, and error states; error styling and citations preserved
    - `ChatInputBar` now supports Send/Stop (Stop cancels active stream)
    - `SearchView`:
      - Shows inline error banner and removes full-screen loading overlay
      - Adds “New Topic” button to start a fresh server-managed thread

## Next Steps
1) Build and run (iOS/macOS)
   - Verify streaming and UI states:
     - Assistant shows TypingBubble, then progressively filled text
     - Stop cancels promptly; assistant bubble shows short error “Generation canceled”
   - Reasoning vs non-reasoning parameterization:
     - `gpt-5` honors `reasoning.effort`
     - `gpt-4o/4o-mini` honor `temperature`/`top_p`
   - Settings switching updates UI controls and request behavior
2) Reliability and telemetry
   - Add quick Pinecone health pre-flight (optional short `describe_index_stats`) and surface non-blocking banner when unreachable
   - Add traceId per search; structured logs at key steps (embedding, query, stream start/end)
   - Improve OpenAI stream error mapping to user-friendly messages
3) UX Copy
   - Refine Settings help text (reasoning vs non-reasoning; save to apply)
4) Documentation
   - Update `codebaseSummary.md` with the unified chat UI and cancellation flow
   - Keep `projectRoadmap.md` progress up-to-date

## How to Test (Guide)
1) Open Xcode, select a scheme (iOS Simulator or macOS app) and run.
2) Ensure the following new files are added to the app target (Target Membership):
   - `OpenCone/Features/Search/Models/ChatModels.swift`
   - `OpenCone/Features/Search/Components/TypingBubble.swift`
   If not, follow instructions in `cline_docs/userInstructions/add_search_ui_files_to_target.md`.
3) In Settings:
   - Enter valid OpenAI key, Save Settings.
   - Choose a non-reasoning model (e.g., `gpt-4o-mini`), adjust Temperature/Top P, Save Settings.
   - Switch to a reasoning model (`gpt-5`), set Effort (e.g., Medium), Save Settings.
   - Conversation Mode:
     - Select “Server-managed (OpenAI)” to use the Responses “conversation” field
     - Select “Client-bounded (Local)” to send bounded local history (no server thread)
4) Go to Search:
   - Configure Pinecone and select an index/namespace.
   - Ask a question. Observe:
     - TypingBubble appears, then streaming text fills the assistant bubble
     - Stop button cancels stream; assistant bubble shows “Generation canceled”
     - On success, citations attach to the assistant answer
   - Toggle models and repeat to compare behaviors.
   - Ask follow-up questions to verify multi-turn context is remembered across turns (e.g., ask a clarifying question without restating subject).
   - Use “New Topic” to start a fresh server-managed thread; verify follow-ups no longer rely on the previous conversation.

## Status
- Chat UI “gray bar” issue resolved via TypingBubble and removal of blocking overlay.
- Cancel mid-stream supported and reflected in UI.
- Conversation continuity:
  - Server-managed threads (Responses “conversation”) wired with a New Topic control
  - Client-bounded history remains as a selectable fallback
- Pending: telemetry, health checks, copy updates, final E2E validation.
