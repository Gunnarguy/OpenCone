# Run & Test Guide: Streaming + Conversation Memory

This guide walks through building, running, and validating the Search feature with:
- OpenAI Responses API (streaming SSE)
- Reasoning vs non-reasoning model params
- Bounded conversation memory (multi-turn context)

## Prerequisites
- Valid API keys saved in Settings:
  - OpenAI API Key
  - Pinecone API Key and Index selected (with embeddings loaded)
- Network connectivity

## Build & Run
1) Open the project in Xcode.
2) Select target:
   - iOS: pick a Simulator (e.g., iPhone) and run.
   - macOS: select “My Mac” and run the app.
3) First launch:
   - Open Settings tab.
   - Enter and Save your OpenAI and Pinecone keys.
   - Pick a completion model (see below).

## Model Parameters Validation
- Non-reasoning models (e.g., gpt-4o, gpt-4o-mini):
  - Settings shows Temperature and Top P sliders.
- Reasoning models (e.g., gpt-5):
  - Settings shows Reasoning Effort (low/medium/high).
- Switch between models and Save Settings to verify the gated UI swaps correctly.

## Conversation Mode
- In Settings > AI Models, choose Conversation Mode:
  - Server-managed (OpenAI): Uses the Responses API “conversation” field to maintain thread state on the server.
  - Client-bounded (Local): Sends a trimmed local history each turn (no server thread).
- Save Settings. Changes take effect on the next request.
- In Search:
  - Use “New Topic” to start a fresh server-managed thread (generates a new conversationId and clears transcript).
  - Follow-up turns should remain coherent within a thread; after “New Topic”, follow-ups should not rely on the prior thread.

## Streaming Behavior Checklist
In Search:
1) Configure Pinecone index/namespace if not already selected.
2) Enter a question and press Send.
3) Observe:
   - A Typing indicator bubble appears immediately for the assistant.
   - Text streams in incrementally (SSE).
   - Progressively filled assistant bubble transitions from streaming to normal.
   - Pressing Stop cancels generation quickly and marks assistant bubble with “Generation canceled”.
4) On completion:
   - Citations attach for the top sources used.
   - A “Search completed” success log appears with a traceId.

## Conversation Memory (Multi-turn) Validation
The app now includes bounded prior turns (last ~8 finalized messages) in each request.

Test script:
1) Turn A (seed):
   - Ask a question that your Pinecone corpus can answer (e.g., “Summarize the policy on refunds.”).
   - Verify streamed answer and citations.
2) Turn B (follow-up):
   - Ask, “What about digital goods?” without restating the full subject.
   - Expect the assistant to leverage Turn A context and provide a coherent continuation.
3) Turn C (clarification):
   - Ask a clarifying question referencing the prior reply (e.g., “Are exceptions allowed during holidays?”).
   - Verify the assistant continues contextually.

Notes:
- History excludes the in-flight (current) user message to avoid duplication.
- Only finalized messages with non-empty text are included in history.
- History length is bounded to maintain token budget.

## Selected Sources Flow (Optional)
1) Select a few high-relevance results from the list (checkboxes).
2) Press “Generate from Selected”.
3) Verify:
   - Streaming behavior and citations reflect only the chosen sources.
   - Conversation history is still included, enabling coherent follow-ups.

## Reliability & Fallbacks
- If no streamed deltas arrive but the stream completes, the app performs a one-shot non-streaming completion to ensure a visible answer.
- Completed events are deduplicated, preventing double-finalization bugs.
- Pinecone preflight health check prevents heavy queries if the backend is unhealthy; a non-blocking banner appears.

## Telemetry & Logs
- A per-search traceId is attached to logs.
- Open the Logs/Processing tab to inspect step-by-step entries (embedding, query, stream start/end, completion, errors).

## Troubleshooting
- Success logs but no visible answer:
  - Ensure you’re running the latest build (Clean Build Folder if needed).
  - Confirm OpenAI/Pinecone keys and index selection.
  - With the current guards + fallback, an answer should populate even if no deltas stream.
- Pinecone unreachable:
  - A banner will indicate temporary unavailability; try again shortly.
- Clearing transcript for a fresh test:
  - If a “Clear” control isn’t available in the Search UI, you can relaunch the app to reset in-memory chat state.

## Acceptance Criteria
- Answers stream and finalize correctly for both reasoning and non-reasoning models.
- Settings dynamically gate Reasoning Effort vs Temperature/Top P.
- Follow-up turns can rely on prior context without restating it (within bounded history).
- Stop cancels promptly; cancel state is clearly indicated.
- Citations attach on completion (stream or fallback).
