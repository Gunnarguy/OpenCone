
<div align="center">
  <img src="https://raw.githubusercontent.com/gunnarhostetler/OpenCone/main/OpenCone/Assets.xcassets/AppIcon.appiconset/AppIcon-Source-1024.png" width="120" />
  <h1 align="center">OpenCone</h1>
  <h3 align="center">Advanced iOS Retrieval Augmented Generation (RAG) System</h3>
  <p align="center">
    Process, embed, and search your documents using AI on your iPhone or iPad.
  </p>
  <p align="center">
    <img src="https://img.shields.io/badge/Swift-5.9+-FA7343.svg?style=for-the-badge&logo=swift&logoColor=white" alt="Swift" />
    <img src="https://img.shields.io/badge/SwiftUI-iOS%2015+-007AFF.svg?style=for-the-badge&logo=swift&logoColor=white" alt="SwiftUI" />
    <img src="https://img.shields.io/badge/Combine-Reactive-FF7F00.svg?style=for-the-badge&logo=apple&logoColor=white" alt="Combine" />
    <img src="https://img.shields.io/badge/Xcode-15+-147EFB.svg?style=for-the-badge&logo=xcode&logoColor=white" alt="Xcode" />
    <br/>
    <img src="https://img.shields.io/badge/OpenAI-Embeddings%20&%20Completions-412991.svg?style=for-the-badge&logo=openai&logoColor=white" alt="OpenAI" />
    <img src="https://img.shields.io/badge/Pinecone-Vector%20DB-0B7DFF.svg?style=for-the-badge&logo=pinecone&logoColor=white" alt="Pinecone" />
  </p>
</div>

---

## 📚 Table of Contents

- [📍 Overview](#-overview)
- [✨ Key Features](#-key-features)
- [🛠️ Tech Stack & Architecture](#️-tech-stack--architecture)
  - [Architectural Pattern](#architectural-pattern)
  - [Core Technologies](#core-technologies)
  - [Architectural Diagram](#architectural-diagram)
- [📂 Project Structure](#-project-structure)
- [🌊 Application Flow & Usage](#-application-flow--usage)
  - [Data Flow Diagram](#data-flow-diagram)
  - [Step-by-Step Usage](#step-by-step-usage)
- [🚀 Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation & Running](#installation--running)
- [⚙️ Configuration](#️-configuration)
  - [API Keys](#api-keys)
  - [Processing Parameters](#processing-parameters)
  - [AI Models](#ai-models)
- [🤝 Contributing](#-contributing)
- [👏 Acknowledgments](#-acknowledgments)

---

## 📍 Overview

OpenCone is a sophisticated, native iOS application designed to empower users with an on-device Retrieval Augmented Generation (RAG) system. It allows for seamless uploading and processing of various document types (PDFs, text files, Word documents, and even images via OCR). Once processed, text is extracted, intelligently chunked, and converted into vector embeddings using OpenAI's state-of-the-art models. These embeddings are then stored and indexed within a Pinecone serverless vector database.

The core utility of OpenCone lies in its ability to perform semantic searches across the user's entire document corpus. Users can ask natural language questions, and the system will retrieve the most relevant document segments, which are then used as context by OpenAI's completion models (like GPT-4o) to generate concise, accurate, and contextually relevant answers.

Built entirely with SwiftUI, OpenCone offers a modern, reactive user interface. It leverages Swift's `async/await` for concurrency and Combine for managing asynchronous events. The application features a custom, themable design system (`OCDesignSystem`) ensuring a polished and consistent user experience across its various features, including document management, search, detailed processing logs, and comprehensive settings.

---

## ✨ Key Features

| Feature                         | Description                                                                                                                               |
| :------------------------------ | :---------------------------------------------------------------------------------------------------------------------------------------- |
| **📄 Document Management** | Upload, view, and manage various document types (PDF, DOCX, TXT, images with OCR). Securely handles file access using bookmarks.           |
| **⚙️ Advanced Processing Pipeline** | Automated text extraction, strategic chunking (MIME-type specific), and robust error handling during document ingestion.                  |
| **🚀 OpenAI Embeddings** | Generates high-dimensional vector embeddings for text chunks using configurable OpenAI models (e.g., `text-embedding-3-large`).          |
| **🌲 Pinecone Integration** | Full lifecycle management for Pinecone serverless indexes: create, list, select active index, and manage namespaces. Stores and indexes embeddings. |
| **🔍 Semantic Search & RAG** | Perform natural language queries. Retrieves semantically similar text chunks from Pinecone and uses them to generate AI answers via OpenAI. |
| **📊 Detailed Statistics** | View comprehensive processing statistics per document, including phase timings, token counts, and chunk size distributions.               |
| **🎨 Custom Design & Theming** | Features a bespoke UI library (`OCDesignSystem`) with `OCButton`, `OCCard`, `OCBadge`. Multiple themes (Light, Dark, Midnight, Forest). |
| **⚙️ Rich Settings** | Securely configure API keys (OpenAI, Pinecone + Project ID), processing parameters (chunk size, overlap), and AI model selection.        |
| **📜 Real-time Processing Logs** | Detailed, filterable logs for all major operations (document processing, API calls, errors) with timestamps and context.                 |
| **🔑 Guided Setup** | User-friendly `WelcomeView` for initial API key configuration and app introduction.                                                     |
| **📱 iOS Native Experience** | Built with SwiftUI for a responsive and platform-optimized experience on iPhone and iPad.                                                |

---

## 🛠️ Tech Stack & Architecture

### Architectural Pattern

OpenCone adheres to the **MVVM (Model-View-ViewModel)** architectural pattern, promoting a clean separation of concerns. This is augmented by a dedicated **Service Layer** that encapsulates business logic, external API interactions, and complex operations.

* **Models**: Plain Swift `structs` define the application's data structures (e.g., `DocumentModel`, `ChunkModel`, `EmbeddingModel`, `ProcessingLogEntry`).
* **Views**: SwiftUI `View`s are responsible for presenting the UI and capturing user input. They are lightweight and delegate logic to ViewModels.
* **ViewModels**: `ObservableObject` classes that prepare and provide data for the Views, handle user actions, and interact with the Service layer. They use `@Published` properties and Combine publishers to notify Views of changes.
* **Services**: Swift classes that perform specific tasks such as file processing (`FileProcessorService`), text manipulation (`TextProcessorService`), OpenAI API calls (`OpenAIService`), Pinecone database interactions (`PineconeService`), and embedding generation (`EmbeddingService`).

### Core Technologies

* **UI Framework**: SwiftUI (for all UI elements and layout)
* **Concurrency**:
    * Swift `async/await` for asynchronous operations.
    * Combine framework for reactive programming patterns (e.g., observing `@Published` properties, `Logger` updates).
    * `TaskGroup` for managing concurrent document processing.
* **Data Persistence (Settings & API Keys)**: `UserDefaults` (with a note that Keychain is preferred for production API key storage).
* **External APIs**:
    * **OpenAI API**: For `text-embedding` models and `chat/completions` (RAG).
    * **Pinecone API**: For vector storage, indexing, and similarity search (serverless indexes).
* **Local Processing**:
    * **Text Extraction**: `PDFKit` for PDFs, standard file operations for text-based files, `VisionKit` (VNRecognizeTextRequest) for OCR from images.
    * **Text Chunking**: Custom recursive splitting logic in `TextProcessorService`.
    * **Tokenization**: `NaturalLanguage` framework (`NLTokenizer`) for token counting.
* **Design & Theming**:
    * `OCDesignSystem`: Provides constants for spacing, sizing, and animations.
    * `OCTheme` & `ThemeManager`: Enables dynamic theme switching and provides themed colors and styles.
    * Custom SwiftUI components (`OCButton`, `OCCard`, `OCBadge`).
* **Logging**: A custom, centralized `Logger` service.

### Architectural Diagram

```mermaid
graph TD
    subgraph UserInterface [📱 User Interface (SwiftUI Views)]
        direction TB
        WelcomeView_UI[WelcomeView]
        MainView_UI[MainView Tabs]
        DocumentsView_UI[DocumentsView & Details]
        SearchView_UI[SearchView & Results]
        ProcessingLogView_UI[ProcessingLogView]
        SettingsView_UI[SettingsView & Theme]
        DesignSystem_Components[OCButton, OCCard, OCBadge]
    end

    subgraph ViewModels_Layer [🧠 ViewModels (Combine / @Published)]
        direction TB
        SettingsViewModel_VM[SettingsViewModel]
        DocumentsViewModel_VM[DocumentsViewModel]
        SearchViewModel_VM[SearchViewModel]
        ProcessingViewModel_VM[ProcessingViewModel]
        ThemeManager_Core[ThemeManager]
    end

    subgraph Services_Layer [🛠️ Services (Business Logic & API Clients)]
        direction TB
        FileProcessorService_Svc[FileProcessorService]
        TextProcessorService_Svc[TextProcessorService]
        EmbeddingService_Svc[EmbeddingService]
        OpenAIService_Svc[OpenAIService]
        PineconeService_Svc[PineconeService]
    end

    subgraph Core_Infrastructure [⚙️ Core Infrastructure]
        direction TB
        OpenConeApp_App[OpenConeApp Lifecycle]
        Configuration_Core[Configuration (Defaults & Env)]
        Logger_Core[Logger (Singleton)]
        OCDesignSystem_Core[OCDesignSystem (Constants)]
        Models_Data[Data Models (DocumentModel, etc.)]
    end

    subgraph External_Dependencies [☁️ External APIs & System Services]
        direction TB
        OpenAI_API_Ext["OpenAI API"]
        Pinecone_API_Ext["Pinecone API"]
        iOS_FileSystem_Ext["iOS File System (UIDocumentPicker, Bookmarks)"]
        VisionKit_Ext["VisionKit (OCR)"]
        UserDefaults_Ext["UserDefaults (Settings)"]
    end

    %% Connections
    UserInterface -- Observes & Interacts --> ViewModels_Layer
    ViewModels_Layer -- Uses & Delegates --> Services_Layer
    Services_Layer -- Interacts --> External_Dependencies
    ViewModels_Layer -- Uses --> Core_Infrastructure
    Services_Layer -- Uses --> Core_Infrastructure
    UserInterface -- Themed By --> ThemeManager_Core
    ThemeManager_Core -- Uses --> OCDesignSystem_Core
    UserInterface -- Uses --> DesignSystem_Components
    DesignSystem_Components -- Themed By --> ThemeManager_Core
    OpenConeApp_App -- Manages --> UserInterface
    OpenConeApp_App -- Manages --> ViewModels_Layer

    %% More specific connections for clarity
    WelcomeView_UI --> SettingsViewModel_VM
    DocumentsView_UI --> DocumentsViewModel_VM
    SearchView_UI --> SearchViewModel_VM
    ProcessingLogView_UI --> ProcessingViewModel_VM
    SettingsView_UI --> SettingsViewModel_VM
    ThemeManager_Core --> UserDefaults_Ext  # For saving theme preference

    DocumentsViewModel_VM --> FileProcessorService_Svc
    DocumentsViewModel_VM --> TextProcessorService_Svc
    DocumentsViewModel_VM --> EmbeddingService_Svc
    DocumentsViewModel_VM --> PineconeService_Svc
    SearchViewModel_VM --> EmbeddingService_Svc
    SearchViewModel_VM --> PineconeService_Svc
    SearchViewModel_VM --> OpenAIService_Svc
    ProcessingViewModel_VM -- Observes --> Logger_Core

    EmbeddingService_Svc --> OpenAIService_Svc
    OpenAIService_Svc --> OpenAI_API_Ext
    PineconeService_Svc --> Pinecone_API_Ext
    FileProcessorService_Svc --> iOS_FileSystem_Ext
    FileProcessorService_Svc --> VisionKit_Ext
    SettingsViewModel_VM --> UserDefaults_Ext

    classDef ui fill:#cde4ff,stroke:#333,stroke-width:2px,color:#333
    classDef vm fill:#ccffcc,stroke:#333,stroke-width:2px,color:#333
    classDef svc fill:#fff0cc,stroke:#333,stroke-width:2px,color:#333
    classDef core fill:#d9d2e9,stroke:#333,stroke-width:2px,color:#333
    classDef ext fill:#e0e0e0,stroke:#333,stroke-width:2px,color:#333

    class UserInterface ui
    class ViewModels_Layer vm
    class Services_Layer svc
    class Core_Infrastructure core
    class External_Dependencies ext
````

-----

## 📂 Project Structure

OpenCone's codebase is meticulously organized into the following key directories and files:

  * **`OpenCone/App/`**:
      * `OpenConeApp.swift`: The main entry point of the application, managing app lifecycle and initial state transitions.
      * `MainView.swift`: Contains the primary `TabView` orchestrating navigation between Documents, Search, Logs, and Settings features.
      * `WelcomeView.swift`: Guides users through initial setup (API key entry) on first launch or if keys are missing. Includes `APIKeyEntryView`.
  * **`OpenCone/Assets.xcassets/`**: Stores all application assets, including the app icon (`AppIcon.appiconset`) and accent colors.
  * **`OpenCone/Core/`**: Shared, foundational components:
      * `Configuration.swift`: Centralized static configuration values (default model names, chunk sizes, embedding dimensions, API keys from environment variables for debug).
      * `Logger.swift`: A singleton class for app-wide logging.
      * `ProcessingLogEntry.swift`: Data model for individual log entries.
      * **`DesignSystem/`**:
          * `OCTheme.swift`: Defines structs for different visual themes (Light, Dark, Midnight, Forest) with their color palettes.
          * `ThemeManager.swift`: A singleton class that manages the active theme and applies it app-wide.
          * `ThemeEnvironment.swift`: SwiftUI `EnvironmentKey` and modifier for easy theme access in views.
          * `OCDesignSystem.swift`: Struct containing constants for spacing, sizing, and animations.
          * `Color+Extensions.swift`: Utility for initializing `Color` from hex strings.
          * **`Components/`**: Reusable, themed SwiftUI components:
              * `OCButton.swift`: Versatile button with various styles and sizes.
              * `OCCard.swift`: Standardized card view with different elevation styles.
              * `OCBadge.swift`: For displaying status tags and labels.
      * **`Extensions/`**:
          * `Binding+Extensions.swift`: Helper to unwrap optional `Binding`s.
  * **`OpenCone/Features/`**: Distinct feature modules:
      * **`Documents/`**:
          * `DocumentsView.swift`: Main UI for the Documents tab.
          * `DocumentsViewModel.swift`: Handles logic for document listing, selection, processing orchestration, and Pinecone index/namespace management.
          * `DocumentModel.swift`: Primary data model for documents, including `ChunkModel`, `EmbeddingModel`, `PineconeVector`, `SearchResultModel`, `ChunkAnalytics`, and `DocumentProcessingStats`.
          * `DocumentModel+ViewHelpers.swift`: Extension on `DocumentModel` providing computed properties for UI display (icon, color, file size).
          * `DocumentRow.swift`: SwiftUI view for displaying a single document item in a list.
          * `DocumentDetailsView.swift`: View showing detailed processing statistics and logs for a selected document.
          * `DocumentPicker.swift`: `UIViewControllerRepresentable` wrapper for `UIDocumentPickerViewController` to allow file selection.
      * **`ProcessingLog/`**:
          * `ProcessingView.swift`: Main UI for the Logs tab.
          * `ProcessingViewModel.swift`: Manages log entries (subscribes to `Logger.shared`) and provides filtering capabilities.
      * **`Search/`**:
          * `SearchView.swift`: Main UI for the Search tab, including configuration, search bar, and results display.
          * `SearchViewModel.swift`: Handles search queries, query embedding, Pinecone querying, RAG answer generation, and Pinecone index/namespace selection.
      * **`Settings/`**:
          * `SettingsView.swift`: Main UI for the Settings tab.
          * `SettingsViewModel.swift`: Manages API keys, processing parameters, AI model selection, and persistence via `UserDefaults`.
          * `SecureSettingsField.swift`: Custom view for securely displaying/editing sensitive text fields (like API keys).
          * `SettingsNavigationRow.swift`: Reusable row component for navigation within settings screens.
          * `ThemeSettingsView.swift`: View for selecting the application theme.
          * `DesignSystemDemoView.swift`: View showcasing all custom `OCDesignSystem` components.
  * **`OpenCone/Preview Content/`**:
      * `PreviewData.swift`: Provides sample data and view model instances for SwiftUI Previews, facilitating UI development and testing.
  * **`OpenCone/Services/`**: Contains the core business logic and external API interaction layers:
      * `EmbeddingService.swift`: Orchestrates text embedding generation by interacting with `OpenAIService`. Converts embeddings to Pinecone format.
      * `FileProcessorService.swift`: Responsible for reading files, extracting text content (from PDFs, text files, and images via OCR using VisionKit), and determining MIME types.
      * `OpenAIService.swift`: Handles direct communication with the OpenAI API for creating embeddings and generating chat completions.
      * `PineconeService.swift`: Manages all interactions with the Pinecone vector database API (index management, vector upsertion, querying, retries, rate limiting).
      * `TextProcessorService.swift`: Responsible for chunking text content based on MIME-type specific strategies and generating content hashes.
  * **`OpenCone.xcodeproj/`**: Xcode project file and associated workspace data.
  * **`cline_docs/`**: Internal development documentation (not part of the compiled app).
  * **`README.md`**: This file.

-----

## 🌊 Application Flow & Usage

### Data Flow Diagram

```mermaid
graph LR
    subgraph UserAction [User Action]
        direction TB
        UploadDoc[1. Upload Document]
        TypeQuery[5. Type Search Query]
    end

    subgraph iOS_App [OpenCone iOS Application]
        direction TB
        subgraph Views [Views]
            DocumentsView_Flow[DocumentsView]
            SearchView_Flow[SearchView]
        end
        subgraph ViewModels [ViewModels]
            DocumentsViewModel_Flow[DocumentsViewModel]
            SearchViewModel_Flow[SearchViewModel]
        end
        subgraph Services_App [C. Services]
            FileProcessor_Svc[FileProcessorSvc]
            TextProcessor_Svc[TextProcessorSvc]
            Embedding_Svc[EmbeddingSvc]
            Pinecone_Svc[PineconeSvc]
            OpenAI_Svc[OpenAISvc]
        end
    end

    subgraph ExternalAPIs_Flow [External APIs]
        direction TB
        OpenAI_API_Flow[OpenAI API]
        Pinecone_API_Flow[Pinecone API]
    end

    %% Document Processing Flow
    UploadDoc --> DocumentsView_Flow
    DocumentsView_Flow -->|Triggers Process| DocumentsViewModel_Flow
    DocumentsViewModel_Flow -->|2a. Extract Text| FileProcessor_Svc
    FileProcessor_Svc -->|Raw Text| DocumentsViewModel_Flow
    DocumentsViewModel_Flow -->|2b. Chunk Text| TextProcessor_Svc
    TextProcessor_Svc -->|Text Chunks| DocumentsViewModel_Flow
    DocumentsViewModel_Flow -->|3. Generate Embeddings| Embedding_Svc
    Embedding_Svc -->|Chunks| OpenAI_Svc
    OpenAI_Svc -->|Vector Embeddings| OpenAI_API_Flow
    OpenAI_API_Flow -->|Embeddings| OpenAI_Svc
    OpenAI_Svc -->|Embeddings| Embedding_Svc
    Embedding_Svc -->|Formatted Vectors| DocumentsViewModel_Flow
    DocumentsViewModel_Flow -->|4. Upsert Vectors| Pinecone_Svc
    Pinecone_Svc -->|Vectors| Pinecone_API_Flow
    Pinecone_API_Flow -->|Success/Fail| Pinecone_Svc
    Pinecone_Svc -->|Status| DocumentsViewModel_Flow
    DocumentsViewModel_Flow -->|Update UI| DocumentsView_Flow

    %% Search & RAG Flow
    TypeQuery --> SearchView_Flow
    SearchView_Flow -->|Triggers Search| SearchViewModel_Flow
    SearchViewModel_Flow -->|6a. Embed Query| Embedding_Svc
    Embedding_Svc -->|Query Text| OpenAI_Svc
    OpenAI_Svc -->|Query Embedding| OpenAI_API_Flow
    OpenAI_API_Flow -->|Embedding| OpenAI_Svc
    OpenAI_Svc -->|Embedding| Embedding_Svc
    Embedding_Svc -->|Query Vector| SearchViewModel_Flow
    SearchViewModel_Flow -->|6b. Query Pinecone| Pinecone_Svc
    Pinecone_Svc -->|Query Vector| Pinecone_API_Flow
    Pinecone_API_Flow -->|Relevant Chunks| Pinecone_Svc
    Pinecone_Svc -->|Chunks| SearchViewModel_Flow
    SearchViewModel_Flow -->|7. Generate Answer (RAG)| OpenAI_Svc
    OpenAI_Svc -->|Original Query + Context Chunks| OpenAI_API_Flow
    OpenAI_API_Flow -->|Generated Answer| OpenAI_Svc
    OpenAI_Svc -->|Answer| SearchViewModel_Flow
    SearchViewModel_Flow -->|Update UI with Answer & Sources| SearchView_Flow

    classDef userAction fill:#f9e79f,stroke:#333,stroke-width:1px,color:#333
    classDef appLayer fill:#d6eaf8,stroke:#2980b9,stroke-width:2px,color:#333
    classDef externalApi fill:#e8daef,stroke:#8e44ad,stroke-width:2px,color:#333

    class UserAction userAction
    class iOS_App appLayer
    class ExternalAPIs_Flow externalApi
```

### Step-by-Step Usage

1.  **Launch & Setup**:
      * Upon first launch, or if API keys are not configured, the `WelcomeView` appears.
      * Follow the prompts to enter your OpenAI API Key, Pinecone API Key, and Pinecone Project ID. These are essential for the app to function.
2.  **API Key Validation & Service Initialization**:
      * Keys are validated (Pinecone key must start with `pcsk_`).
      * Core services (`OpenAIService`, `PineconeService`, `EmbeddingService`) and ViewModels are initialized.
3.  **Main Interface (`MainView`)**:
      * After successful setup, the main tabbed interface is displayed.
      * **Initial Data Load**: The app attempts to load available Pinecone indexes for selection in the Documents and Search tabs.
4.  **Documents Tab (`DocumentsView`)**:
      * **Pinecone Configuration**:
          * Select an existing Pinecone index from the dropdown or create a new one (e.g., "my-opencone-index"). The index dimension will be set according to `Configuration.embeddingDimension`.
          * Optionally, select or create a namespace within the chosen index to organize your documents.
      * **Add Documents**:
          * Tap the "Add File" button.
          * Use the system document picker (`UIDocumentPickerViewController`) to select one or more files (PDF, TXT, DOCX, images, etc.).
      * **Process Documents**:
          * Select the desired documents from the list.
          * Tap the "Process" button.
          * The app will:
            1.  Extract text (`FileProcessorService` - uses OCR for images via VisionKit).
            2.  Chunk the extracted text (`TextProcessorService`).
            3.  Generate vector embeddings for each chunk (`EmbeddingService` via `OpenAIService`).
            4.  Upload these embeddings to your selected Pinecone index and namespace (`PineconeService`).
          * Processing progress is displayed, along with status updates.
      * **View Details**: Tap "Details" on a document row to see comprehensive processing statistics, including phase timings and chunk/token distributions (`DocumentDetailsView`).
5.  **Search Tab (`SearchView`)**:
      * **Pinecone Configuration**: Select the Pinecone index and namespace you want to search within (should match where documents were processed).
      * **Enter Query**: Type your natural language question into the search bar.
      * **Perform Search**: Tap the search button.
          * The query is embedded using `EmbeddingService` (via `OpenAIService`).
          * `PineconeService` queries for semantically similar vector embeddings.
          * Relevant text chunks (sources) are retrieved and displayed.
          * `OpenAIService` generates a consolidated answer based on your query and the retrieved chunks (RAG).
      * **View Results**: The generated answer and the source document chunks are displayed in separate tabs. You can select specific sources and regenerate the answer if needed.
6.  **Logs Tab (`ProcessingView`)**:
      * View a real-time stream of detailed logs from all application operations.
      * Filter logs by level (DEBUG, INFO, WARNING, ERROR, SUCCESS) or search by text content.
      * Export logs for debugging or record-keeping.
7.  **Settings Tab (`SettingsView`)**:
      * View and update your OpenAI and Pinecone API keys and Pinecone Project ID.
      * Adjust document processing parameters:
          * `Default Chunk Size`: Target character length for text chunks.
          * `Default Chunk Overlap`: Character overlap between chunks.
      * Select the OpenAI models used for `Embedding Generation` and `Completions`.
      * Change the application's visual theme (`ThemeSettingsView`).
      * Explore the `DesignSystemDemoView` to see custom UI components.

-----

## 🚀 Getting Started

### Prerequisites

  * **Hardware**: iPhone or iPad running iOS 15.0 or later.
  * **Software**:
      * macOS with Xcode 15.0 or later.
      * Git.
  * **Accounts & Keys**:
      * An Apple Developer account (required for running on a physical device).
      * An active **OpenAI API Key**. You can obtain one from [platform.openai.com/api-keys](https://platform.openai.com/api-keys).
      * An active **Pinecone API Key** and **Project ID**.
          * Ensure you are using a **Serverless** Pinecone project.
          * API Key (starts with `pcsk_`) can be found at [app.pinecone.io/projects/(your-org)/projects/(your-project)/keys](https://www.google.com/search?q=https://app.pinecone.io/projects/\(your-org\)/projects/\(your-project\)/keys).
          * Project ID can be found at [app.pinecone.io/organizations/(your-org)/projects](https://www.google.com/search?q=https://app.pinecone.io/organizations/\(your-org\)/projects).

### Installation & Running

1.  **Clone the Repository**:

    ```bash
    git clone [https://github.com/gunnarhostetler/OpenCone.git](https://github.com/gunnarhostetler/OpenCone.git)
    cd OpenCone
    ```

2.  **API Key Configuration**:
    OpenCone needs API keys to communicate with OpenAI and Pinecone. You have two primary methods to provide them:

      * **(Recommended for Initial Setup) In-App Configuration**:

          * When you launch the app for the first time, the `WelcomeView` will guide you through entering:
              * OpenAI API Key
              * Pinecone API Key (must start with `pcsk_`)
              * Pinecone Project ID
          * These keys are stored in `UserDefaults`. You can modify them later in the "Settings" tab.

      * **(For Developers/Simulators) Environment Variables**:

          * In Xcode, go to "Product" Menu → "Scheme" → "Edit Scheme...".
          * Select the "Run" action from the sidebar.
          * Navigate to the "Arguments" tab.
          * In the "Environment Variables" section, click the "+" button to add:
              * Name: `OPENAI_API_KEY`, Value: `your_actual_openai_api_key`
              * Name: `PINECONE_API_KEY`, Value: `your_actual_pinecone_api_key`
              * Name: `PINECONE_PROJECT_ID`, Value: `your_actual_pinecone_project_id`
          * *Note: Keys provided via the in-app interface (`UserDefaults`) generally take precedence if set after environment variables are read by `Configuration.swift` during initial static property evaluation.*

3.  **Open in Xcode**:
    Navigate to the cloned directory and open the project:

    ```bash
    open OpenCone.xcodeproj
    ```

4.  **Select Target & Run**:

      * In Xcode, choose an iOS Simulator (e.g., iPhone 15 Pro) or a connected physical iOS device as the run target.
      * Click the "Play" button (or press Cmd+R) to build and run the application.
      * If it's the first launch or keys are missing (and not set via environment variables for the current scheme), the Welcome screen will appear.

-----

## ⚙️ Configuration

Beyond the initial API key setup, OpenCone offers further customization through the "Settings" tab:

### API Keys

  * **OpenAI API Key**: Your secret key for accessing OpenAI services.
  * **Pinecone API Key**: Your secret key for accessing your Pinecone project (must start with `pcsk_`).
  * **Pinecone Project ID**: The unique identifier for your Pinecone project.

### Processing Parameters

  * **Default Chunk Size**: The target number of characters for each text chunk created during document processing. Default: `1024`.
      * *Impact*: Larger chunks preserve more local context but might be less specific for retrieval. Smaller chunks are more granular but might lose broader context.
  * **Default Chunk Overlap**: The number of characters that consecutive chunks will share. Default: `256`.
      * *Impact*: Overlap helps maintain contextual flow between chunks, reducing the chance of important information being split across non-overlapping boundaries.

### AI Models

  * **Embedding Model**: Choose the OpenAI model used for generating vector embeddings.
      * Examples: `text-embedding-3-large`, `text-embedding-3-small`, `text-embedding-ada-002`.
      * Default: `text-embedding-3-large` (Dimension: `3072`).
      * *Impact*: Different models have varying embedding dimensions, performance characteristics, and costs. Ensure your Pinecone index dimension matches the selected embedding model's dimension.
  * **Completion Model**: Select the OpenAI model used for generating answers in the RAG process.
      * Examples: `gpt-4o`, `gpt-4o-mini`.
      * Default: `gpt-4o`.
      * *Impact*: Affects the quality, coherence, and cost of generated answers.

### Appearance

  * **Theme**: Customize the app's look and feel by selecting a theme (Light, Dark, Midnight, Forest). Changes are applied instantly.

-----

## 🤝 Contributing

While OpenCone is primarily a project by Gunnar Hostetler, contributions in the form of feedback, bug reports, or feature suggestions are welcome. Please feel free to open an issue on the GitHub repository to discuss potential changes or identify problems.

If you wish to contribute code:

1.  Fork the repository.
2.  Create a new branch for your feature or bug fix (`git checkout -b feature/YourFeature` or `bugfix/IssueDescription`).
3.  Commit your changes (`git commit -m 'Add some feature'`).
4.  Push to your branch (`git push origin feature/YourFeature`).
5.  Open a Pull Request against the `main` branch of the original repository.

Please ensure your code adheres to the existing style and architectural patterns.

-----

## 👏 Acknowledgments

  * **SwiftUI & Combine**: Apple's powerful frameworks for building modern, reactive iOS applications.
  * **OpenAI**: For providing the cutting-edge language models that power the embedding and generation capabilities.
  * **Pinecone**: For their efficient and developer-friendly serverless vector database service, crucial for semantic search.
  * The broader **Swift and iOS developer community** for continuous inspiration, shared knowledge, and open-source contributions.

-----

```

This README is designed to be comprehensive, well-organized, and visually appealing with the use of badges and Mermaid diagrams. It covers all the key aspects of your OpenCone application, from its high-level purpose down to setup instructions and technical details. I've also taken the liberty of suggesting an app icon in the header – you can replace the URL with a direct link to your `AppIcon-Source-1024.png` if it's hosted, or keep it as a placeholder.