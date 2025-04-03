import SwiftUI

@main
struct OpenConeApp: App {
    // Create services
    private let fileProcessorService = FileProcessorService()
    private let textProcessorService = TextProcessorService()
    
    // Create view models with dependency injection
    @StateObject private var settingsViewModel = SettingsViewModel()
    private let logger = Logger.shared // Add logger instance
    
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
                            // Check if we need to show welcome screen FIRST
                            let isFirstLaunch = UserDefaults.standard.bool(forKey: "hasLaunchedBefore") == false
                            logger.log(level: .info, message: "Is first launch? \(isFirstLaunch)")

                            if isFirstLaunch {
                                logger.log(level: .info, message: "First launch. Will show WelcomeView.")
                                self.showingWelcomeScreen = true
                                // Mark as launched immediately for first launch scenario
                                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                                logger.log(level: .info, message: "Marked app as launched.")
                                // Set initialized to true to move past LoadingView
                                self.isInitialized = true
                                logger.log(level: .info, message: "isInitialized set to true for first launch.")

                            } else {
                                logger.log(level: .info, message: "Not first launch. Loading API keys and initializing services...")
                                // Load keys ONLY if not first launch
                                settingsViewModel.loadAPIKeys()
                                logger.log(level: .info, message: "API keys loaded. OpenAI: \(settingsViewModel.openAIAPIKey.isEmpty ? "Not Set" : "Set"), Pinecone: \(settingsViewModel.pineconeAPIKey.isEmpty ? "Not Set" : "Set"), ProjectID: \(settingsViewModel.pineconeProjectId.isEmpty ? "Not Set" : "Set")")

                                // Initialize services with API keys
                                initializeServices() // This function handles setting isInitialized based on key validity

                                // Marking as launched here is slightly redundant but harmless
                                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                                logger.log(level: .info, message: "Marked app as launched (redundant for non-first launch).")
                            }
                        }
                } else if showingWelcomeScreen {
                    // Show welcome screen for first launch
                    WelcomeView(
                        settingsViewModel: settingsViewModel,
                        onComplete: {
                            logger.log(level: .info, message: "WelcomeView completed. Initializing services...")
                            initializeServices()
                            showingWelcomeScreen = false
                            logger.log(level: .info, message: "ShowingWelcomeScreen set to false.")
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
        logger.log(level: .info, message: "initializeServices called.")
        guard !settingsViewModel.openAIAPIKey.isEmpty,
              !settingsViewModel.pineconeAPIKey.isEmpty,
              !settingsViewModel.pineconeProjectId.isEmpty else {
            logger.log(level: .error, message: "Cannot initialize services: Missing API keys or Project ID.")
            // Optionally, transition to an error state or back to welcome screen
            // For now, just log and prevent initialization
            self.isInitialized = false // Ensure we don't show main view
            self.showingWelcomeScreen = true // Force back to welcome/settings
            return
        }
        
        logger.log(level: .info, message: "Creating services...")
        // Create services with API keys
        let openAIService = OpenAIService(apiKey: settingsViewModel.openAIAPIKey)
        logger.log(level: .debug, message: "OpenAIService created.")
        
        // Create Pinecone service with API key and Project ID for JWT authentication
        let pineconeService = PineconeService(apiKey: settingsViewModel.pineconeAPIKey, projectId: settingsViewModel.pineconeProjectId)
        logger.log(level: .debug, message: "PineconeService created.")
        
        let embeddingService = EmbeddingService(openAIService: openAIService)
        logger.log(level: .debug, message: "EmbeddingService created.")
        
        // Create view models with dependencies
        let documentsVM = DocumentsViewModel(
            fileProcessorService: fileProcessorService,
            textProcessorService: textProcessorService,
            embeddingService: embeddingService,
            pineconeService: pineconeService
        )
        logger.log(level: .debug, message: "DocumentsViewModel created.")
        
        let searchVM = SearchViewModel(
            pineconeService: pineconeService,
            openAIService: openAIService,
            embeddingService: embeddingService
        )
        logger.log(level: .debug, message: "SearchViewModel created.")
        
        DispatchQueue.main.async {
            logger.log(level: .info, message: "Assigning ViewModels and setting isInitialized to true on main thread.")
            self.documentsViewModel = documentsVM
            self.searchViewModel = searchVM
            self.isInitialized = true
            logger.log(level: .info, message: "isInitialized set to true.")
            
            // Load indexes once initialized
            Task {
                logger.log(level: .info, message: "Starting background task to load indexes.")
                await documentsVM.loadIndexes()
                logger.log(level: .info, message: "DocumentsViewModel indexes loaded.")
                await searchVM.loadIndexes()
                logger.log(level: .info, message: "SearchViewModel indexes loaded.")
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
    private let logger = Logger.shared // Add logger instance
    
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
                    logger.log(level: .info, message: "WelcomeView: Next/Start button tapped. Current step: \(currentStep)")
                    if currentStep < 2 {
                        currentStep += 1
                        logger.log(level: .info, message: "WelcomeView: Moved to step \(currentStep)")
                    } else {
                        logger.log(level: .info, message: "WelcomeView: Final step. Completing setup...")
                        // Complete setup
                        logger.log(level: .info, message: "WelcomeView: Calling settingsViewModel.saveSettings()...")
                        settingsViewModel.saveSettings()
                        logger.log(level: .info, message: "WelcomeView: settingsViewModel.saveSettings() returned.")
                        
                        logger.log(level: .info, message: "WelcomeView: Calling onComplete()...")
                        onComplete()
                        logger.log(level: .info, message: "WelcomeView: onComplete() returned.")
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
