import SwiftUI

@main
struct SwiftRAGApp: App {
    // Create services
    private let fileProcessorService = FileProcessorService()
    private let textProcessorService = TextProcessorService()
    
    // Create view models with dependency injection
    @StateObject private var settingsViewModel = SettingsViewModel()
    
    // Other view models will be created once we have API keys
    @State private var documentsViewModel: DocumentsViewModel?
    @State private var searchViewModel: SearchViewModel?
    
    @State private var isInitialized = false
    @State private var showingWelcomeScreen = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !isInitialized {
                    // Show loading screen while initializing
                    LoadingView()
                        .onAppear {
                            // Load settings when app starts
                            settingsViewModel.loadAPIKeys()
                            
                            // Check if we need to show welcome screen
                            let isFirstLaunch = UserDefaults.standard.bool(forKey: "hasLaunchedBefore") == false
                            self.showingWelcomeScreen = isFirstLaunch
                            
                            if !isFirstLaunch {
                                // Initialize services with API keys
                                initializeServices()
                            }
                            
                            // Mark as launched
                            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                        }
                } else if showingWelcomeScreen {
                    // Show welcome screen for first launch
                    WelcomeView(
                        settingsViewModel: settingsViewModel,
                        onComplete: {
                            initializeServices()
                            showingWelcomeScreen = false
                        }
                    )
                } else if let documentsViewModel = documentsViewModel,
                          let searchViewModel = searchViewModel {
                    // Show main app once initialized
                    MainView(
                        documentsViewModel: documentsViewModel,
                        searchViewModel: searchViewModel,
                        settingsViewModel: settingsViewModel
                    )
                } else {
                    // Show error screen if initialization failed
                    ErrorView(message: "Failed to initialize app services") {
                        showingWelcomeScreen = true
                    }
                }
            }
        }
    }
    
    /// Initialize services with API keys
    private func initializeServices() {
        // Create services with API keys
        let openAIService = OpenAIService(apiKey: settingsViewModel.openAIAPIKey)
        
        // Create Pinecone service with just the API key
        let pineconeService = PineconeService(apiKey: settingsViewModel.pineconeAPIKey)
        
        let embeddingService = EmbeddingService(openAIService: openAIService)
        
        // Create view models with dependencies
        let documentsVM = DocumentsViewModel(
            fileProcessorService: fileProcessorService,
            textProcessorService: textProcessorService,
            embeddingService: embeddingService,
            pineconeService: pineconeService
        )
        
        let searchVM = SearchViewModel(
            pineconeService: pineconeService,
            openAIService: openAIService,
            embeddingService: embeddingService
        )
        
        DispatchQueue.main.async {
            self.documentsViewModel = documentsVM
            self.searchViewModel = searchVM
            self.isInitialized = true
            
            // Load indexes once initialized
            Task {
                await documentsVM.loadIndexes()
                await searchVM.loadIndexes()
            }
        }
    }
}

/// Loading view shown while app initializes
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
            
            Text("SwiftRAG")
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

/// Welcome screen for first launch
struct WelcomeView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    let onComplete: () -> Void
    
    @State private var currentStep = 0
    
    var body: some View {
        VStack {
            // Progress indicator
            HStack {
                ForEach(0..<3) { step in
                    Circle()
                        .fill(step == currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Content based on current step
            Group {
                if currentStep == 0 {
                    welcomeStep
                } else if currentStep == 1 {
                    apiKeyStep
                } else {
                    completionStep
                }
            }
            
            Spacer()
            
            // Navigation buttons
            HStack {
                Button(action: {
                    if currentStep > 0 {
                        currentStep -= 1
                    }
                }) {
                    Text("Back")
                        .padding()
                        .frame(width: 100)
                }
                .opacity(currentStep > 0 ? 1 : 0)
                
                Spacer()
                
                Button(action: {
                    if currentStep < 2 {
                        currentStep += 1
                    } else {
                        // Complete setup
                        settingsViewModel.saveSettings()
                        onComplete()
                    }
                }) {
                    Text(currentStep < 2 ? "Next" : "Start")
                        .padding()
                        .frame(width: 100)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(currentStep == 1 && (settingsViewModel.openAIAPIKey.isEmpty || settingsViewModel.pineconeAPIKey.isEmpty || settingsViewModel.pineconeProjectId.isEmpty))
            }
            .padding()
        }
        .padding()
    }
    
    /// Welcome step content
    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text("Welcome to SwiftRAG")
                .font(.largeTitle.bold())
            
            Text("SwiftRAG is a Retrieval Augmented Generation system for iOS that helps you process documents, generate vector embeddings, and perform semantic search.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "doc.fill", text: "Upload and process documents")
                FeatureRow(icon: "rectangle.and.text.magnifyingglass", text: "Extract and chunk text content")
                FeatureRow(icon: "chart.bar.doc.horizontal", text: "Generate vector embeddings")
                FeatureRow(icon: "magnifyingglass", text: "Perform semantic search")
                FeatureRow(icon: "brain", text: "Get AI-generated answers")
            }
            .padding(.top, 20)
        }
    }
    
    /// API key entry step
    private var apiKeyStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
            
            Text("API Keys Required")
                .font(.largeTitle.bold())
            
            Text("SwiftRAG needs API keys for OpenAI and Pinecone to function. These keys will be stored securely.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading) {
                    Text("OpenAI API Key")
                        .font(.headline)
                    
                    SecureField("sk-...", text: $settingsViewModel.openAIAPIKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                Text("Get an API key at openai.com")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
                
                VStack(alignment: .leading) {
                    Text("Pinecone API Key (starts with 'pcsk_')")
                        .font(.headline)
                    
                    SecureField("pcsk_...", text: $settingsViewModel.pineconeAPIKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(settingsViewModel.pineconeAPIKey.isEmpty || !settingsViewModel.pineconeAPIKey.hasPrefix("pcsk_") ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    
                    Text("Pinecone Project ID")
                        .font(.headline)
                    
                    TextField("e.g., 1234abcd-ef56-7890-gh12-345678ijklmn", text: $settingsViewModel.pineconeProjectId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(settingsViewModel.pineconeProjectId.isEmpty ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    
                    Text("IMPORTANT: Pinecone requires both an API Key (starts with 'pcsk_') AND Project ID for JWT authentication. Find both in the Pinecone console under API Keys.")
                        .font(.caption)
                        .foregroundColor((settingsViewModel.pineconeProjectId.isEmpty || settingsViewModel.pineconeAPIKey.isEmpty || !settingsViewModel.pineconeAPIKey.hasPrefix("pcsk_")) ? .red : .secondary)
                }
            }
            .padding(.top, 20)
        }
    }
    
    /// Completion step
    private var completionStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.green)
            
            Text("Ready to Go!")
                .font(.largeTitle.bold())
            
            Text("You're all set to start using SwiftRAG! Click Start to begin exploring your documents.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Here's what you can do:")
                    .font(.headline)
                    .padding(.bottom, 8)
                
                FeatureRow(icon: "1.circle.fill", text: "Add documents in the Documents tab")
                FeatureRow(icon: "2.circle.fill", text: "Process them to extract text and generate embeddings")
                FeatureRow(icon: "3.circle.fill", text: "Search across documents in the Search tab")
                FeatureRow(icon: "4.circle.fill", text: "Get AI-generated answers based on your documents")
            }
            .padding(.top, 20)
        }
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

#Preview {
    WelcomeView(settingsViewModel: SettingsViewModel()) {
        print("Setup completed")
    }
}
