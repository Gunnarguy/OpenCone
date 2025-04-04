import SwiftUI

@main
struct OpenConeApp: App {
    // MARK: - Properties
    private let fileProcessorService = FileProcessorService()
    private let textProcessorService = TextProcessorService()
    private let logger = Logger.shared
    
    @StateObject private var settingsViewModel = SettingsViewModel()
    @State private var documentsViewModel: DocumentsViewModel?
    @State private var searchViewModel: SearchViewModel?
    
    // App state
    @State private var appState: AppState = .loading
    
    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            Group {
                switch appState {
                case .loading:
                    LoadingView()
                        .onAppear(perform: handleAppLaunch)
                    
                case .welcome:
                    WelcomeView(
                        settingsViewModel: settingsViewModel,
                        onComplete: handleWelcomeComplete
                    )
                    
                case .main:
                    if let documentsVM = documentsViewModel, let searchVM = searchViewModel {
                        MainView(
                            documentsViewModel: documentsVM,
                            searchViewModel: searchVM,
                            settingsViewModel: settingsViewModel
                        )
                    }
                    
                case .error(let message):
                    ErrorView(
                        message: message,
                        retryAction: { appState = .welcome }
                    )
                }
            }
        }
    }
    
    // MARK: - App Launch Logic
    
    /// Handle app launch and determine initial app state
    private func handleAppLaunch() {
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        logger.log(level: .info, message: "App launching. First launch? \(isFirstLaunch)")
        
        if isFirstLaunch {
            markAppAsLaunched()
            appState = .welcome
        } else {
            settingsViewModel.loadAPIKeys()
            initializeServices()
        }
    }
    
    /// Mark app as launched in UserDefaults
    private func markAppAsLaunched() {
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        logger.log(level: .info, message: "App marked as launched")
    }
    
    /// Handle completion of welcome flow
    private func handleWelcomeComplete() {
        logger.log(level: .info, message: "Welcome flow completed")
        settingsViewModel.saveSettings()
        initializeServices()
    }
    
    // MARK: - Service Initialization
    
    /// Initialize app services with API keys
    private func initializeServices() {
        guard validateAPIKeys() else {
            handleMissingAPIKeys()
            return
        }
        
        logger.log(level: .info, message: "Initializing services")
        
        let services = createServices()
        let viewModels = createViewModels(with: services)
        
        DispatchQueue.main.async {
            self.documentsViewModel = viewModels.0
            self.searchViewModel = viewModels.1
            self.appState = .main
            
            self.loadIndexes(documentsVM: viewModels.0, searchVM: viewModels.1)
        }
    }
    
    /// Validate that all required API keys are present
    private func validateAPIKeys() -> Bool {
        return !settingsViewModel.openAIAPIKey.isEmpty &&
               !settingsViewModel.pineconeAPIKey.isEmpty &&
               !settingsViewModel.pineconeProjectId.isEmpty
    }
    
    /// Handle case when API keys are missing
    private func handleMissingAPIKeys() {
        logger.log(level: .error, message: "Cannot initialize: Missing API keys")
        appState = .welcome
    }
    
    /// Create service instances with API keys
    private func createServices() -> (openAI: OpenAIService, pinecone: PineconeService, embedding: EmbeddingService) {
        let openAIService = OpenAIService(apiKey: settingsViewModel.openAIAPIKey)
        let pineconeService = PineconeService(
            apiKey: settingsViewModel.pineconeAPIKey, 
            projectId: settingsViewModel.pineconeProjectId
        )
        let embeddingService = EmbeddingService(openAIService: openAIService)
        
        return (openAIService, pineconeService, embeddingService)
    }
    
    /// Create view models with services
    private func createViewModels(with services: (openAI: OpenAIService, pinecone: PineconeService, embedding: EmbeddingService)) -> (DocumentsViewModel, SearchViewModel) {
        let documentsVM = DocumentsViewModel(
            fileProcessorService: fileProcessorService,
            textProcessorService: textProcessorService,
            embeddingService: services.embedding,
            pineconeService: services.pinecone
        )
        
        let searchVM = SearchViewModel(
            pineconeService: services.pinecone,
            openAIService: services.openAI,
            embeddingService: services.embedding
        )
        
        return (documentsVM, searchVM)
    }
    
    /// Load Pinecone indexes in background
    private func loadIndexes(documentsVM: DocumentsViewModel, searchVM: SearchViewModel) {
        Task {
            logger.log(level: .info, message: "Loading indexes")
            await documentsVM.loadIndexes()
            await searchVM.loadIndexes()
        }
    }
}

// MARK: - App State
enum AppState {
    case loading
    case welcome
    case main
    case error(String)
}

// MARK: - Views

/// Loading view shown while app initializes
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
            
            Text("OpenCone")
                .font(.largeTitle.bold())
            
            Text("Retrieval Augmented Generation")
                .font(.headline)
                .foregroundColor(.secondary)
            
            ProgressView()
                .padding(.top, 20)
        }
        .padding()
    }
}

/// Error view shown if initialization fails
struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.orange)
            
            Text("Initialization Error")
                .font(.largeTitle.bold())
            
            Text(message)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: retryAction) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 20)
        }
        .padding()
    }
}

/// Feature row for welcome screen
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.body)
        }
    }
}