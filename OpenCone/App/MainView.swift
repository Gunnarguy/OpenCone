import SwiftUI

/// Main view for the OpenCone application with tab navigation
/// Coordinates between document processing, search, logs, and settings
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
            // MARK: Documents Tab
            NavigationView {
                DocumentsView(viewModel: documentsViewModel)
                    .navigationTitle("Documents")
            }
            .tabItem {
                Label("Documents", systemImage: "doc.fill")
            }
            .tag(0)
            
            // MARK: Search Tab
            NavigationView {
                SearchView(viewModel: searchViewModel)
                    .navigationTitle("Search")
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(1)
            
            // MARK: Processing Log Tab
            NavigationView {
                ProcessingView()
                    .navigationTitle("Processing Log")
            }
            .tabItem {
                Label("Logs", systemImage: "list.bullet")
            }
            .tag(2)
            
            // MARK: Settings Tab
            NavigationView {
                SettingsView(viewModel: settingsViewModel)
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(3)
        }
        .onAppear(perform: loadInitialData)
        .alert(isPresented: errorAlertBinding) {
            errorAlert
        }
    }
    
    // MARK: - Helper Methods
    
    /// Load API keys and initialize data when view appears
    private func loadInitialData() {
        // Ensure API keys are loaded
        settingsViewModel.loadAPIKeys()
        
        // Load Pinecone indexes when settings are available
        Task {
            if !settingsViewModel.pineconeAPIKey.isEmpty {
                await documentsViewModel.loadIndexes()
                await searchViewModel.loadIndexes()
            }
        }
    }
    
    /// Binding for error alert presentation
    private var errorAlertBinding: Binding<Bool> {
        Binding<Bool>(
            get: { 
                documentsViewModel.errorMessage != nil ||
                searchViewModel.errorMessage != nil ||
                settingsViewModel.errorMessage != nil 
            },
            set: { _ in
                documentsViewModel.errorMessage = nil
                searchViewModel.errorMessage = nil
                settingsViewModel.errorMessage = nil
            }
        )
    }
    
    /// Alert view for displaying errors from any view model
    private var errorAlert: Alert {
        Alert(
            title: Text("Error"),
            message: Text(
                documentsViewModel.errorMessage ??
                searchViewModel.errorMessage ??
                settingsViewModel.errorMessage ?? 
                "Unknown error"
            ),
            dismissButton: .default(Text("OK"))
        )
    }
}

// MARK: - Preview Provider

#Preview {
    mainViewPreview()
}

/// Creates a preview instance of MainView with mock data
private func mainViewPreview() -> some View {
    // Create view models with preview services
    let settingsViewModel = createPreviewSettingsViewModel()
    let services = createPreviewServices(with: settingsViewModel)
    let viewModels = createPreviewViewModels(with: services)
    
    return MainView(
        documentsViewModel: viewModels.documents,
        searchViewModel: viewModels.search,
        settingsViewModel: settingsViewModel
    )
}

// MARK: - Preview Helpers

/// Create settings view model with preview data
private func createPreviewSettingsViewModel() -> SettingsViewModel {
    let viewModel = SettingsViewModel()
    viewModel.openAIAPIKey = "preview-key"
    viewModel.pineconeAPIKey = "preview-key"
    viewModel.pineconeProjectId = "preview-project"
    return viewModel
}

/// Create service instances for preview
private func createPreviewServices(with settingsViewModel: SettingsViewModel) -> (
    fileProcessor: FileProcessorService,
    textProcessor: TextProcessorService,
    openAI: OpenAIService,
    pinecone: PineconeService,
    embedding: EmbeddingService
) {
    let fileProcessor = FileProcessorService()
    let textProcessor = TextProcessorService()
    let openAI = OpenAIService(apiKey: settingsViewModel.openAIAPIKey)
    let pinecone = PineconeService(
        apiKey: settingsViewModel.pineconeAPIKey, 
        projectId: settingsViewModel.pineconeProjectId
    )
    let embedding = EmbeddingService(openAIService: openAI)
    
    return (fileProcessor, textProcessor, openAI, pinecone, embedding)
}

/// Create view models for preview
private func createPreviewViewModels(with services: (
    fileProcessor: FileProcessorService,
    textProcessor: TextProcessorService,
    openAI: OpenAIService,
    pinecone: PineconeService,
    embedding: EmbeddingService
)) -> (documents: DocumentsViewModel, search: SearchViewModel) {
    
    let documentsViewModel = DocumentsViewModel(
        fileProcessorService: services.fileProcessor,
        textProcessorService: services.textProcessor,
        embeddingService: services.embedding,
        pineconeService: services.pinecone
    )
    
    let searchViewModel = SearchViewModel(
        pineconeService: services.pinecone,
        openAIService: services.openAI,
        embeddingService: services.embedding
    )
    
    return (documentsViewModel, searchViewModel)
}