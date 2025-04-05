# OpenCone Codebase Summary

## Key Components and Their Interactions

### App Structure
- **OpenConeApp**: Main app entry point that manages app lifecycle and state transitions
- **MainView**: Primary container view once the app is initialized
- **WelcomeView**: Initial view for first-time setup and API key configuration

### Features
- **Documents Module**: 
  - `DocumentModel`: Data model for document representation
  - `DocumentsViewModel`: Business logic for document operations
  - `DocumentsView`, `DocumentDetailsView`: UI components for viewing documents
  - `DocumentPicker`: Document selection and import functionality

- **Search Module**:
  - `SearchViewModel`: Manages search queries and results
  - `SearchView`: UI for search functionality

- **Settings Module**:
  - `SettingsViewModel`: Manages user preferences and API keys
  - `SettingsView`: UI for configuration options

- **Processing Module**:
  - `ProcessingView`: Displays processing status and logs

### Core Components
- **Logger**: Centralized logging system
- **Configuration**: App configuration management
- **Extensions**: Utility extensions for Swift types

### Services
- **FileProcessorService**: File handling operations
- **TextProcessorService**: Text processing functionality
- **OpenAIService**: OpenAI API integration
- **PineconeService**: Pinecone vector database integration
- **EmbeddingService**: Text embedding generation

## Data Flow
1. Users select documents via DocumentPicker
2. Documents are processed by FileProcessorService and TextProcessorService
3. Text is converted to embeddings via EmbeddingService (using OpenAI)
4. Embeddings are stored in Pinecone through PineconeService
5. User searches are converted to embeddings and compared against stored vectors
6. Results are returned and displayed in the UI

## External Dependencies
- **OpenAI API**: Used for generating text embeddings
- **Pinecone API**: Vector database for semantic search
- **SwiftUI**: Native iOS UI framework
- **Swift Concurrency**: For asynchronous operations

## Recent Significant Changes
- **App Icon Implementation**: Configured proper app icons for all appearance modes
- **Info.plist Configuration**: Updated project settings to include required App Store keys
- **Asset Catalog Updates**: Organized and structured app assets according to Apple guidelines

## User Feedback Integration
No user feedback has been integrated yet as the app is still in development phase.
