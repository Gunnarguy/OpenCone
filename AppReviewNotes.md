# App Review Notes

_Last updated: 2025-11-11_

Dear App Review Team,

Thank you for reviewing OpenCone, a document-centric retrieval-augmented generation (RAG) client. The app helps users ingest their own documents, store derived embeddings in Pinecone, and ask questions that are answered with OpenAI responses.

## Test Account & API Keys

We provide reviewer-specific API keys that only have access to sample Pinecone namespaces and a locked-down OpenAI project.

- OpenAI API Key: **Provided in App Store Connect reviewer notes.**
- Pinecone API Key: **Provided in App Store Connect reviewer notes.**
- Pinecone Project ID: **Provided in App Store Connect reviewer notes.**

After launching the app you will be prompted to enter these values. No other configuration is required.

## Features To Exercise

1. Add sample documents from the "Reviewer Samples" folder preloaded in the Documents tab.
2. Wait for ingestion to complete (status updates appear in the Logs tab).
3. Switch to the Search tab and run the suggested queries listed below.
4. Verify streaming responses arrive and cite document snippets.
5. Remove a document and confirm that it disappears from the Documents list and search results.

Suggested queries once the sample PDF is indexed:

- "What are the key onboarding steps for new Pinecone indexes?"
- "Summarize the architecture for OpenCone ingestion."

## Privacy & Data Flow Summary

- Imported files are copied into the app sandbox for processing.
- Text chunks are sent to OpenAI (embeddings) and Pinecone (vectors) using the reviewer keys.
- No third-party analytics or advertising SDKs are present.
- Removing a document issues a delete request to Pinecone to discard the stored vectors.

## Troubleshooting Tips

- If ingestion stalls, tap "Refresh Index Insights" in the Documents tab to fetch the latest namespace state.
- Use the Settings tab to reset the app and re-enter keys if you need a clean slate.
- Network access is required for embedding generation and answer streaming.

Thank you for your time. Please contact [support@opencone.app](mailto:support@opencone.app) if you need assistance during review.
