import SwiftUI

/// Main view for the OpenCone application with tab navigation: Ask, Documents and Settings
struct MainView: View {
    // MARK: - View Models
    @StateObject private var documentsViewModel: DocumentsViewModel
    @StateObject private var searchViewModel: SearchViewModel
    @StateObject private var settingsViewModel: SettingsViewModel

    @State private var selectedTab = 0

    /// Initialize the main view with its required view models
    /// - Parameters:
    ///   - documentsViewModel: View model for document management
    ///   - searchViewModel: View model for search functionality
    ///   - settingsViewModel: View model for application settings
    init(documentsViewModel: DocumentsViewModel, searchViewModel: SearchViewModel, settingsViewModel: SettingsViewModel) {
        _documentsViewModel = StateObject(wrappedValue: documentsViewModel)
        _searchViewModel = StateObject(wrappedValue: searchViewModel)
        _settingsViewModel = StateObject(wrappedValue: settingsViewModel)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // MARK: Ask Tab
            NavigationStack {
                SearchView(
                    viewModel: searchViewModel,
                    settings: settingsViewModel,
                    onRequestDocumentsTab: { selectedTab = 1 }
                )
            }
            .tabItem {
                Label("Ask", systemImage: "bubble.left.and.text.bubble.right")
            }
            .tag(0)

            // MARK: Documents Tab
            NavigationStack {
                DocumentsView(viewModel: documentsViewModel)
                    .navigationTitle("Documents")
            }
            .tabItem {
                Label("Documents", systemImage: "doc.on.doc")
            }
            .tag(1)

            // MARK: Settings Tab (the processing log lives under Advanced)
            NavigationStack {
                SettingsView(viewModel: settingsViewModel)
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(2)
        }
        .onAppear(perform: loadInitialData)
        .alert(isPresented: errorAlertBinding) {
            errorAlert
        }
        .onChange(of: selectedTab) { _, newValue in
            guard newValue == 0, !DemoMode.isActive else { return }
            Task {
                await searchViewModel.loadIndexes()
            }
        }
    }

    // MARK: - Helper Methods

    /// Load API keys and initialize data when view appears
    private func loadInitialData() {
        if DemoMode.isActive {
            switch DemoMode.screen {
            case "settings": selectedTab = 2
            case "documents", "index-details", "document": selectedTab = 1
            default: break
            }
            return
        }

        // Ensure API keys are loaded
        settingsViewModel.loadAPIKeys()

        // Load Pinecone indexes when settings are available
        Task {
            // Check if Pinecone API key is available before loading indexes
            if !settingsViewModel.pineconeAPIKey.isEmpty && !settingsViewModel.pineconeProjectId.isEmpty {
                await documentsViewModel.loadIndexes()
                await searchViewModel.loadIndexes()
            }
        }
    }

    /// Binding for error alert presentation
    private var errorAlertBinding: Binding<Bool> {
        Binding<Bool>(
            get: {
                // Ask shows its own errors in place, so only Documents and Settings alert
                documentsViewModel.errorMessage != nil ||
                settingsViewModel.errorMessage != nil
            },
            set: { _ in
                // Clear error messages when the alert is dismissed
                documentsViewModel.errorMessage = nil
                settingsViewModel.errorMessage = nil
            }
        )
    }

    /// Alert view for displaying errors from any view model
    private var errorAlert: Alert {
        // Consolidate error messages from all view models
        let errorMessages = [
            documentsViewModel.errorMessage,
            settingsViewModel.errorMessage
        ]
        .compactMap { $0 } // Remove nil values

        // Create the alert message text
        let messageText = errorMessages.isEmpty ? "Unknown error" : errorMessages.joined(separator: "\n")

        return Alert(
            title: Text("Error"),
            message: Text(messageText),
            dismissButton: .default(Text("OK"))
        )
    }
}

// MARK: - Preview Provider

#Preview {
    mainViewPreview()
}

/// Creates a preview instance of MainView with mock data and services
@MainActor
private func mainViewPreview() -> some View {
    // 1. Create Preview Settings View Model
    let settingsViewModel = SettingsViewModel()
    settingsViewModel.openAIAPIKey = "preview-openai-key"
    settingsViewModel.pineconeAPIKey = "preview-pinecone-key"
    settingsViewModel.pineconeProjectId = "preview-pinecone-project"

    // 2. Create Preview Services
    let fileProcessor = FileProcessorService()
    let textProcessor = TextProcessorService()
    let openAI = OpenAIService(apiKey: settingsViewModel.openAIAPIKey)
    let pinecone = PineconeService(
        apiKey: settingsViewModel.pineconeAPIKey,
        projectId: settingsViewModel.pineconeProjectId
    )
    let embedding = EmbeddingService(openAIService: openAI)

    // 3. Create Preview View Models using Services
    let documentsViewModel = DocumentsViewModel(
        fileProcessorService: fileProcessor,
        textProcessorService: textProcessor,
        embeddingService: embedding,
        pineconeService: pinecone
    )

    let searchViewModel = SearchViewModel(
        pineconeService: pinecone,
        openAIService: openAI,
        embeddingService: embedding,
        settingsViewModel: settingsViewModel
    )

    // 4. Return MainView with Preview View Models
    return MainView(
        documentsViewModel: documentsViewModel,
        searchViewModel: searchViewModel,
        settingsViewModel: settingsViewModel
    )
}
