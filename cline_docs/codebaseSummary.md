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
- `Extensions/`: Utility extensions for standard types.
### Features
- `Documents/`: Manages document loading, display, and details.
- `ProcessingLog/`: Displays processing status/logs.
- `Search/`: Handles search functionality.
- `Settings/`: Manages application settings.
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
- (Track major changes to the codebase structure or functionality)

## User Feedback Integration
- (Describe how user feedback has influenced development, if applicable)

## Additional Documentation
- (List any other relevant documents in `cline_docs`, e.g., `styleAesthetic.md`)
