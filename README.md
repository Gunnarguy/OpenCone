# PineBud Application

PineBud is a Retrieval Augmented Generation (RAG) system for iOS designed to process documents, generate vector embeddings, and perform semantic search using both the OpenAI and Pinecone APIs.

## API Key Setup

- **OpenAI API Key:**  
  Enter your OpenAI API key (which starts with `sk-`) in the designated field.

- **Pinecone API Key:**  
  **Important:** The Pinecone API key **must** begin with `pcsk_`. If an OpenAI key (starting with `sk-`) is mistakenly entered here, authentication with the Pinecone API will fail with an "Invalid JWT format" error.

- **Pinecone Project ID:**  
  Ensure that you provide a valid Pinecone Project ID. Both the API key and project ID are required for successful JWT authentication with Pinecone.

## App Translocation Notice

On macOS, if you encounter file system permission errors—such as "Operation not permitted"—this may be due to App Translocation. App Translocation occurs when an application is run from a temporary or unapproved location. To resolve these issues, it is recommended (but not automatically enforced) to move the PineBud.app bundle to the **/Applications** folder.  
**Note:** This is an optional step meant for troubleshooting permission issues. The app itself will not move automatically.

## Setup Instructions

1. Launch PineBud and navigate to the welcome screen.
2. Enter your API keys:
   - Use an OpenAI API key that starts with `sk-`.
   - Use a Pinecone API key that starts with `pcsk_` and provide the corresponding Pinecone Project ID.
3. If you experience file system permission errors, consider moving the PineBud.app bundle to the **/Applications** folder to prevent macOS App Translocation from interfering.

For further information or troubleshooting, please refer to this documentation.
