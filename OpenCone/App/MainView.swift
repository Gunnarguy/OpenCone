import StoreKit
import SwiftUI

/// Main view for the OpenCone application with tab navigation: Ask, Documents and Settings
struct MainView: View {
    // MARK: - View Models
    @StateObject private var documentsViewModel: DocumentsViewModel
    @StateObject private var searchViewModel: SearchViewModel
    @StateObject private var settingsViewModel: SettingsViewModel

    @State private var selectedTab = 0

    @ObservedObject private var reviewPrompt = ReviewPromptService.shared
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase

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
        // Apple's rating sheet, asked for after a finished answer (`ReviewPromptService`). The system
        // decides whether it actually appears (at most three times a year).
        .onChange(of: reviewPrompt.wantsPrompt) { _, wants in
            guard wants else { return }
            askForRatingWhenInFront()
        }
        // A request held because the app wasn't in front, or because the next question was already
        // being answered, is made on the return to the foreground or when that answer ends.
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, reviewPrompt.wantsPrompt { askForRatingWhenInFront() }
        }
        .onChange(of: searchViewModel.isSearching) { _, searching in
            if !searching, reviewPrompt.wantsPrompt { askForRatingWhenInFront() }
        }
    }

    /// Hands the rating request to StoreKit two seconds after the answer, and only while the app is in
    /// front and no answer is being written. Otherwise it is held: no sheet can show in the background,
    /// and recording the ask there would spend this version's one request on nothing.
    private func askForRatingWhenInFront() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard reviewPrompt.wantsPrompt else { return }
            guard scenePhase == .active, !searchViewModel.isSearching else {
                Logger.shared.log(level: .info, message: "Rating request held", context: "scenePhase=\(scenePhase); searching=\(searchViewModel.isSearching)")
                return
            }
            requestReview()
            // Apple decides whether the sheet shows; this records only that it was asked.
            Logger.shared.log(level: .info, message: "Rating requested")
            reviewPrompt.didAsk()
        }
    }

    // MARK: - Helper Methods

    /// Load API keys and initialize data when view appears
    private func loadInitialData() {
        if DemoMode.isActive {
            switch DemoMode.screen {
            case "settings", "settings-answers", "settings-advanced", "endpoints", "endpoint":
                selectedTab = 2
                #if DEBUG
                DemoContent.seedActivity()
                #endif
            case "documents", "documents-indexing", "index-details", "document": selectedTab = 1
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
