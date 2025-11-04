# Project Roadmap

## High-Level Goals
- [x] Migrate to OpenAI Responses API for text generation
- [x] Add support for GPT-5 reasoning model with appropriate parameters
- [x] Implement streaming via SSE for incremental UI updates
- [x] Gate Settings UI controls based on model type (Reasoning Effort vs Temperature/Top P)
- [x] Bounded conversation memory (multi-turn) in Search
- [ ] Robust runtime validation and error handling for streaming and non-streaming flows
- [ ] End-to-end testing on iOS/macOS targets and refine UX copy/tooltips

## Key Features
- [x] Responses API payload builder using the "input" field with structured content
- [x] Conditional parameters:
  - Reasoning models (e.g., gpt-5): `reasoning.effort`
  - Non-reasoning models (e.g., gpt-4o, gpt-4o-mini): `temperature`, `top_p`
- [x] SSE streaming parser handling events:
  - `response.output_text.delta` → accumulate partial text
  - `response.completed` → finalize
- [x] Settings UI:
  - Model picker includes `gpt-5`
  - Conditional UI for Reasoning Effort vs Temperature/Top P
  - Persist generation params in UserDefaults
- [x] Chat UI modernization:
  - Typing indicator bubble for assistant while streaming
  - Error bubble styling with brief user-facing error text
  - Send/Stop controls (cancel active stream) in input bar
  - Removed full-screen loading overlay; transcript remains visible during generation
- [x] Conversation memory:
  - Bounded multi-turn context (last ~8 finalized messages) included in Responses input
- [x] Reliability and resilience:
  - Pinecone preflight health check (short timeout) before query
  - Circuit breaker to prevent hammering an unhealthy index host
  - Per-search traceId in logs; banner auto-dismiss after 8s
- [ ] Logging/telemetry improvements for Responses streaming and errors
- [ ] Helpful copy updates in Settings explaining model differences

## Completion Criteria
- Application can generate answers using both GPT-5 (reasoning) and non-reasoning models via the Responses API.
- Streaming answer appears incrementally in the chat UI and finalizes correctly.
- Conversation memory: follow-up user turns can reference recent context without restating, within bounded history.
- Settings dynamically show relevant controls based on selected model.
- Backward compatibility retained for existing non-reasoning models.
- Error states are surfaced to users and logged with helpful messages.

## Progress Tracker
- [x] Update `Configuration` with reasoning capability flag and `gpt-5`
- [x] Update `SettingsViewModel` to add/persist `reasoningEffort`, `temperature`, `topP`, and derive `isReasoning`
- [x] Update `SettingsView` to show Reasoning Effort or Temperature/Top P conditionally
- [x] Refactor `OpenAIService` to use `/v1/responses` with conditional parameters and add SSE `streamCompletion`
- [x] Update `SearchViewModel` to use streaming for incremental UI updates in chat
- [x] Add `ChatModels` (role/status/timestamps), `TypingBubble`, error state styling
- [x] Replace full-screen loading overlay with in-transcript typing state; add `cancelActiveSearch()` wired to Stop button
- [x] Add Pinecone preflight health check and circuit breaker in `PineconeService`
- [x] Add per-search traceId logging and auto-dismiss error banner
- [x] Add conversation history support to OpenAIService
- [x] Wire conversation history in SearchViewModel (performSearch, generateAnswerFromSelected)
- [ ] Validate compile and runtime behavior on device/simulator
- [ ] Improve error handling and logging for edge cases (timeouts, network errors, invalid params)
- [ ] Update Settings copy/help text for clarity
- [ ] Document architecture changes in `codebaseSummary.md`

## Completed Tasks
- Implemented Responses API integration with conditional parameterization (reasoning vs non-reasoning)
- Added GPT-5 model support and capability mapping in `Configuration`
- Extended Settings logic and UI to handle model-specific parameters
- Implemented SSE streaming in `OpenAIService` and wired it into `SearchViewModel` chat flow
- Modernized chat UI with typing indicator, error styling, and cancel streaming support; removed full-screen loading overlay
