# Codebase Summary

## Overview
- A brief description of the OpenCone application's purpose.

## Key Components and Their Interactions
### App
- `OpenConeApp.swift`: Main application entry point.
- `MainView.swift`: Root view managing navigation.
- `WelcomeView.swift`: Initial view shown to the user.
### Core
- `Configuration.swift`: App configuration settings.
- `Logger.swift`: Logging utility.
- `ProcessingLogEntry.swift`: Defines the structure for log entries.
- `Extensions/`: Utility extensions for standard types.
### Features
- `Documents/`: Manages document loading, display, and details (`DocumentModel.swift`, `DocumentsView.swift`, `DocumentsViewModel.swift`, `DocumentDetailsView.swift`, `DocumentPicker.swift`, `DocumentModel+ViewHelpers.swift`). Contains view-specific helpers in the `DocumentModel` extension.
- `ProcessingLog/`: Displays processing status/logs (`ProcessingView.swift`, `ProcessingViewModel.swift`).
- `Search/`: Handles search functionality (`SearchView.swift`, `SearchViewModel.swift`).
- `Settings/`: Manages application settings (`SettingsView.swift`, `SettingsViewModel.swift`).
### Services
- `EmbeddingService.swift`: Handles text embedding generation.
- `FileProcessorService.swift`: Processes input files.
- `OpenAIService.swift`: Interacts with OpenAI API.
- `PineconeService.swift`: Interacts with Pinecone API.
- `TextProcessorService.swift`: Handles text extraction and chunking.

## Data Flow
- Describe the general flow of data, e.g., User uploads document -> FileProcessorService -> TextProcessorService -> EmbeddingService -> PineconeService -> SearchViewModel retrieves results.

## External Dependencies
- Pinecone: Vector database for semantic search.
- OpenAI: Used for generating embeddings.
- (List any other significant external libraries or APIs)

## Recent Significant Changes
- Refactored `ProcessingLog` feature to use MVVM pattern (`ProcessingView` + `ProcessingViewModel`).
- Moved `ProcessingLogEntry` definition from `Features/Documents/DocumentModel.swift` to `Core/ProcessingLogEntry.swift`.
- Refactored `DocumentsView` and `DocumentDetailsView` to use view-specific helper properties defined in `DocumentModel+ViewHelpers.swift`, removing duplicated code.
- (Track major changes to the codebase structure or functionality)

## User Feedback Integration
- (Describe how user feedback has influenced development, if applicable)

## Additional Documentation
- (List any other relevant documents in `cline_docs`, e.g., `styleAesthetic.md`)
