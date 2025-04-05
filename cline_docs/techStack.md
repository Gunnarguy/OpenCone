# OpenCone Tech Stack

## iOS App Development
- **Swift**: Main programming language
- **SwiftUI**: UI framework for modern declarative interface design
- **Xcode**: Development environment

## Data Storage and Processing
- **FileProcessorService**: Handles file operations for document processing
- **TextProcessorService**: Processes text extraction and chunking

## AI and Vector Search
- **OpenAI API**: Used for text embeddings and semantic understanding
- **Pinecone**: Vector database for storing and searching embeddings
- **EmbeddingService**: Integration layer for generating embeddings via OpenAI

## Architecture Decisions
- **MVVM Architecture**: Using ViewModels to separate business logic from UI
- **Service-Oriented Design**: Separating functionality into independent services
- **State Management**: Using SwiftUI's native state management (@State, @StateObject)
- **Asynchronous Operations**: Leveraging Swift's modern async/await pattern

## UI/UX Design
- **Asset Management**: Using Xcode's asset catalog system
- **Multiple Appearance Support**: Light, dark, and tinted modes for app icons
- **System Integration**: Following iOS Human Interface Guidelines

## App Store Requirements
- **Info.plist Configuration**: Using auto-generated Info.plist with custom keys
- **App Icon Requirements**: Following iOS 11+ app icon guidelines
