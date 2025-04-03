import SwiftUI

/// Main view for the OpenCone application with tab navigation
struct MainView: View {
    @StateObject private var documentsViewModel: DocumentsViewModel
    @StateObject private var searchViewModel: SearchViewModel
    @StateObject private var settingsViewModel: SettingsViewModel
    
    @State private var selectedTab = 0
    
    init(documentsViewModel: DocumentsViewModel, searchViewModel: SearchViewModel, settingsViewModel: SettingsViewModel) {
        _documentsViewModel = StateObject(wrappedValue: documentsViewModel)
        _searchViewModel = StateObject(wrappedValue: searchViewModel)
        _settingsViewModel = StateObject(wrappedValue: settingsViewModel)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Documents Tab
            NavigationView {
                DocumentsView(viewModel: documentsViewModel)
                    .navigationTitle("Documents")
            }
            .tabItem {
                Label("Documents", systemImage: "doc.fill")
            }
            .tag(0)
            
            // Search Tab
            NavigationView {
                SearchView(viewModel: searchViewModel)
                    .navigationTitle("Search")
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(1)
            
            // Processing Log Tab
            NavigationView {
                ProcessingView()
                    .navigationTitle("Processing Log")
            }
            .tabItem {
                Label("Logs", systemImage: "list.bullet")
            }
            .tag(2)
            
            // Settings Tab
            NavigationView {
                SettingsView(viewModel: settingsViewModel)
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(3)
        }
        .onAppear {
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
        // Show alert for any errors
        .alert(isPresented: Binding<Bool>(
            get: { documentsViewModel.errorMessage != nil ||
                  searchViewModel.errorMessage != nil ||
                  settingsViewModel.errorMessage != nil },
            set: { _ in
                documentsViewModel.errorMessage = nil
                searchViewModel.errorMessage = nil
                settingsViewModel.errorMessage = nil
            }
        )) {
            Alert(
                title: Text("Error"),
                message: Text(documentsViewModel.errorMessage ??
                             searchViewModel.errorMessage ??
                             settingsViewModel.errorMessage ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

#Preview {
    mainViewPreview()
}

/// Helper function to create preview for MainView
private func mainViewPreview() -> some View {
    // Create services for preview
    let fileProcessorService = FileProcessorService()
    let textProcessorService = TextProcessorService()
    let settingsViewModel = SettingsViewModel()
    
    // Initialize with dummy API keys for preview
    settingsViewModel.openAIAPIKey = "preview-key"
    settingsViewModel.pineconeAPIKey = "preview-key"
    settingsViewModel.pineconeProjectId = "preview-project"
    
    let openAIService = OpenAIService(apiKey: settingsViewModel.openAIAPIKey)
    // Updated PineconeService initialization to match its current definition
    let pineconeService = PineconeService(apiKey: settingsViewModel.pineconeAPIKey, projectId: settingsViewModel.pineconeProjectId)
    let embeddingService = EmbeddingService(openAIService: openAIService)
    
    let documentsViewModel = DocumentsViewModel(
        fileProcessorService: fileProcessorService,
        textProcessorService: textProcessorService,
        embeddingService: embeddingService,
        pineconeService: pineconeService
    )
    
    let searchViewModel = SearchViewModel(
        pineconeService: pineconeService,
        openAIService: openAIService,
        embeddingService: embeddingService
    )
    
    return MainView(
        documentsViewModel: documentsViewModel,
        searchViewModel: searchViewModel,
        settingsViewModel: settingsViewModel
    )
}
