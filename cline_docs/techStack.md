# Tech Stack

## Frontend
- Language: Swift
- UI Framework: SwiftUI
- State Management: Primarily SwiftUI's built-in mechanisms (`@State`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`), Combine for asynchronous operations and ViewModel updates.

## Backend / Services
- (Specify any backend services used, e.g., Firebase, custom API)
- Pinecone: (Describe usage)
- OpenAI: (Describe usage)

## Key Libraries/Dependencies
- (List major dependencies)

## Architecture Decisions
- MVVM (Model-View-ViewModel) is being adopted for features requiring complex state management or logic separation (e.g., `ProcessingLog`, `Search`). Simpler views may use standard SwiftUI state management.
- Core components and services are separated for reusability.
