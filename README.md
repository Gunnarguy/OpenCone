-pro-e# OpenCone iOS App

OpenCone is an iOS application implementing a Retrieval Augmented Generation (RAG) system. It allows users to process local documents, generate vector embeddings using OpenAI, store them in Pinecone, and perform semantic search to get AI-generated answers based on the document content.

## Features

*   **Document Upload & Processing:** Add documents from your device (PDF, TXT, DOCX, etc.).
*   **Text Extraction & Chunking:** Automatically extracts text and splits it into manageable chunks.
*   **Vector Embeddings:** Generates vector embeddings for text chunks using OpenAI models (e.g., `text-embedding-3-large`).
*   **Pinecone Integration:** Stores and manages embeddings in a Pinecone vector database.
*   **Semantic Search:** Search across your documents using natural language queries.
*   **AI-Generated Answers:** Get answers synthesized by an AI model (e.g., `gpt-4o`) based on the retrieved document context.
*   **Index & Namespace Management:** Select, create, and refresh Pinecone indexes and namespaces directly within the app.
*   **Detailed Processing Stats:** View detailed statistics and timelines for document processing steps.

## Prerequisites

*   **iOS:** 17.6 or later
*   **Xcode:** Version compatible with iOS 17.6 (e.g., Xcode 16.x) for building.
*   **API Keys:** You need accounts and API keys for:
    *   OpenAI
    *   Pinecone

## Setup

OpenCone requires API keys to interact with OpenAI and Pinecone services. The app will guide you through a setup process on the first launch or if keys are missing:

1.  **Launch OpenCone:** Open the app on your iOS device.
2.  **Welcome Screen:** You will be presented with a multi-step welcome screen.
3.  **API Key Entry:** Proceed to the API Key step. You will need to enter:
    *   **OpenAI API Key:** Your secret key from OpenAI (usually starts with `sk-...`).
    *   **Pinecone API Key:** Your secret key from Pinecone ( **must** start with `pcsk_...`).
    *   **Pinecone Project ID:** Your Pinecone Project ID (found in the Pinecone console under API Keys).
4.  **Complete Setup:** Once the keys are entered correctly, tap "Next" and then "Start" to begin using the app.

**Important:** Ensure you enter the correct keys in the designated fields. Using an OpenAI key in the Pinecone key field will cause authentication errors. Both the Pinecone API Key and Project ID are required.

## Usage

1.  **Configure:** Go to the "Documents" tab. Select or create a Pinecone index and optionally a namespace.
2.  **Add Documents:** Tap the '+' button to add documents from your device.
3.  **Process:** Select the documents you want to process and tap the "Process" button. The app will extract text, generate embeddings, and upload them to your selected Pinecone index/namespace. You can view processing details for each document.
4.  **Search:** Go to the "Search" tab. Ensure the correct index/namespace is selected. Enter your question in the search bar and tap the search button.
5.  **Review Results:** The app will display relevant source chunks from your documents and an AI-generated answer based on those sources. You can view the answer and the source details in separate tabs.

## Building

1.  Clone the repository.
2.  Open `OpenCone.xcodeproj` in Xcode.
3.  Configure code signing with your Apple Developer account.
4.  Build and run the app on a simulator or a physical device running iOS 17.6+.

*(Note: API keys are handled via the in-app setup flow and are expected to be stored securely by the `SettingsViewModel`, likely using Keychain in a production scenario, although the current implementation might use UserDefaults based on `WelcomeView`'s `saveSettings()` call.)*
