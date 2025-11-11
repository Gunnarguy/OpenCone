import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif

@main
struct OpenConeApp: App {
    // MARK: - Properties

    // Core services used throughout the app
    private let fileProcessorService = FileProcessorService()
    private let textProcessorService = TextProcessorService()
    private let logger = Logger.shared  // Centralized logging instance

    // View models managing state for different features
    @StateObject private var settingsViewModel = SettingsViewModel()  // Manages app settings and API keys
    @State private var documentsViewModel: DocumentsViewModel?  // Manages document processing
    @State private var searchViewModel: SearchViewModel?  // Manages search functionality

    // Tracks the current state of the app (loading, welcome, main, error)
    @State private var appState: AppState = .loading

    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            // Dynamically switch the root view based on the app state
            Group {
                switch appState {
                case .loading:
                    // Show loading indicator while initializing
                    LoadingView()
                        .onAppear(perform: handleAppLaunch)  // Trigger launch logic when view appears

                case .welcome:
                    // Show welcome/setup screen for first launch or missing keys
                    WelcomeView(
                        settingsViewModel: settingsViewModel,
                        onComplete: handleWelcomeComplete  // Callback when setup is done
                    )

                case .main:
                    // Show the main tabbed interface if initialization is successful
                    if let documentsVM = documentsViewModel, let searchVM = searchViewModel {
                        MainView(
                            documentsViewModel: documentsVM,
                            searchViewModel: searchVM,
                            settingsViewModel: settingsViewModel
                        )
                    } else {
                        // Fallback error view if view models are unexpectedly nil
                        ErrorView(
                            message: "Failed to load main application components.",
                            retryAction: { appState = .loading }  // Retry initialization
                        )
                    }

                case .error(let message):
                    // Show a generic error view with a retry option
                    ErrorView(
                        message: message,
                        retryAction: { appState = .welcome }  // Go back to welcome/setup on retry
                    )
                }
            }
            .withTheme()  // Apply the current theme to the entire app
        }
    }

    // MARK: - App Launch Logic

    /// Handles the initial app launch sequence.
    /// Determines whether to show the welcome screen or proceed to initialize services.
    private func handleAppLaunch() {
        // Check if this is the very first time the app is launched
        let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        logger.log(level: .info, message: "App launching. First launch? \(isFirstLaunch)")

        if isFirstLaunch {
            // If first launch, mark it and go to the welcome screen for setup
            markAppAsLaunched()
            appState = .welcome
        } else {
            // If not first launch, load saved API keys and try to initialize services
            settingsViewModel.loadAPIKeys()
            initializeServices()
        }
    }

    /// Sets a flag in UserDefaults to indicate the app has been launched at least once.
    private func markAppAsLaunched() {
        UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        logger.log(level: .info, message: "App marked as launched (hasLaunchedBefore = true)")
    }

    /// Called when the welcome/setup flow is successfully completed.
    /// Saves settings and proceeds to initialize core services.
    private func handleWelcomeComplete() {
        logger.log(level: .info, message: "Welcome flow completed by user.")
        // Save any settings configured during the welcome flow (like API keys)
        settingsViewModel.saveSettings()
        // Proceed to initialize services with the potentially new settings
        initializeServices()
    }

    // MARK: - Service Initialization

    /// Initializes core application services (OpenAI, Pinecone, Embedding).
    /// Transitions the app state to `.main` on success or `.welcome` if keys are missing.
    private func initializeServices() {
        logger.log(level: .info, message: "Attempting to initialize services...")
        // Ensure all required API keys and the Project ID are present before proceeding
        guard validateAPIKeys() else {
            // If keys are missing, redirect to the welcome screen for setup
            handleMissingAPIKeys()
            return
        }

        logger.log(level: .info, message: "API keys validated. Creating services and view models.")

        // Create instances of the core services
        let services = createServices()
        // Create view models, injecting the necessary services
        let viewModels = createViewModels(with: services)

        // Update the app state on the main thread after services and view models are ready
        DispatchQueue.main.async {
            self.documentsViewModel = viewModels.documentsVM
            self.searchViewModel = viewModels.searchVM
            self.appState = .main  // Transition to the main application view
            logger.log(
                level: .success,
                message: "Services and ViewModels initialized. App state set to .main.")

            // Start loading Pinecone indexes in the background
            self.loadIndexes(documentsVM: viewModels.documentsVM, searchVM: viewModels.searchVM)
        }
    }

    /// Validates that essential API keys (OpenAI, Pinecone) and the Pinecone Project ID are configured.
    /// - Returns: `true` if all required keys/IDs are present, `false` otherwise.
    private func validateAPIKeys() -> Bool {
        let isValid =
            !settingsViewModel.openAIAPIKey.isEmpty && !settingsViewModel.pineconeAPIKey.isEmpty
            && !settingsViewModel.pineconeProjectId.isEmpty  // Project ID is crucial for Pinecone auth
        if !isValid {
            logger.log(
                level: .warning,
                message:
                    "API Key validation failed. Missing OpenAI Key, Pinecone Key, or Pinecone Project ID."
            )
        }
        return isValid
    }

    /// Handles the scenario where required API keys are missing during initialization.
    /// Logs an error and sets the app state back to `.welcome` to prompt the user for setup.
    private func handleMissingAPIKeys() {
        logger.log(
            level: .error,
            message:
                "Cannot initialize services: Required API keys or Project ID are missing. Redirecting to Welcome screen."
        )
        // Set state to welcome to allow the user to enter keys
        appState = .welcome
    }

    /// Creates instances of the core network/processing services.
    /// Requires valid API keys to be available in `settingsViewModel`.
    /// - Returns: A tuple containing initialized `OpenAIService`, `PineconeService`, and `EmbeddingService`.
    private func createServices() -> (
        openAI: OpenAIService, pinecone: PineconeService, embedding: EmbeddingService
    ) {
        // Initialize OpenAI service with its API key
        let openAIService = OpenAIService(apiKey: settingsViewModel.openAIAPIKey)
        // Initialize Pinecone service with its API key and Project ID
        let pineconeService = PineconeService(
            apiKey: settingsViewModel.pineconeAPIKey,
            projectId: settingsViewModel.pineconeProjectId
        )
        // Initialize Embedding service, which depends on the OpenAI service
        let embeddingService = EmbeddingService(openAIService: openAIService)

        logger.log(level: .info, message: "Core services (OpenAI, Pinecone, Embedding) created.")
        return (openAIService, pineconeService, embeddingService)
    }

    /// Creates instances of the main view models, injecting their required service dependencies.
    /// - Parameter services: A tuple containing the initialized core services.
    /// - Returns: A tuple containing initialized `DocumentsViewModel` and `SearchViewModel`.
    private func createViewModels(
        with services: (
            openAI: OpenAIService, pinecone: PineconeService, embedding: EmbeddingService
        )
    ) -> (documentsVM: DocumentsViewModel, searchVM: SearchViewModel) {
        // Initialize Documents view model with its dependencies
        let documentsVM = DocumentsViewModel(
            fileProcessorService: fileProcessorService,
            textProcessorService: textProcessorService,
            embeddingService: services.embedding,
            pineconeService: services.pinecone
        )

        // Initialize Search view model with its dependencies
        let searchVM = SearchViewModel(
            pineconeService: services.pinecone,
            openAIService: services.openAI,
            embeddingService: services.embedding
        )

        logger.log(level: .info, message: "Core ViewModels (Documents, Search) created.")
        return (documentsVM, searchVM)
    }

    /// Initiates the asynchronous loading of Pinecone indexes for both Documents and Search features.
    /// - Parameters:
    ///   - documentsVM: The `DocumentsViewModel` instance.
    ///   - searchVM: The `SearchViewModel` instance.
    private func loadIndexes(documentsVM: DocumentsViewModel, searchVM: SearchViewModel) {
        // Run index loading in a background task to avoid blocking the main thread
        Task {
            logger.log(level: .info, message: "Initiating background loading of Pinecone indexes.")
            // Load indexes for the documents view
            await documentsVM.loadIndexes()
            // Load indexes for the search view
            await searchVM.loadIndexes()
        }
    }

    #if canImport(UIKit)
    /// Sets the application's user interface style (light/dark).
    /// Requires UIKit.
    /// - Parameter darkMode: A boolean indicating whether dark mode should be enabled.
    private func setAppearance(darkMode: Bool) {
        // Access the first connected window scene to set the appearance
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            logger.log(level: .warning, message: "Could not find UIWindowScene to set appearance.")
            return
        }
        // Ensure UI updates happen on the main thread
        DispatchQueue.main.async {
            // Use overrideUserInterfaceStyle to force light or dark mode
            scene.windows.first?.overrideUserInterfaceStyle = darkMode ? .dark : .light
            self.logger.log(
                level: .info, message: "App appearance set to \(darkMode ? "Dark" : "Light") Mode.")
        }
    }
    #endif // canImport(UIKit)
}

// MARK: - App State

// MARK: - App State

/// Represents the possible states of the application during its lifecycle.
enum AppState {
    /// Initial state while loading essential resources or checking configurations.
    case loading
    /// State shown on first launch or when API keys are missing, guiding the user through setup.
    case welcome
    /// The main operational state where the user interacts with the core features.
    case main
    /// State indicating an unrecoverable error occurred during initialization.
    case error(String)  // Associated value holds the error message
}

// MARK: - Helper Views

/// A simple view displayed while the application is initializing.
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            // App icon representation
            Image(systemName: "doc.text.magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)

            // App name
            Text("OpenCone")
                .font(.largeTitle.bold())

            // App tagline
            Text("Retrieval Augmented Generation")
                .font(.headline)
                .foregroundColor(.secondary)

            // Indeterminate progress indicator
            ProgressView()
                .padding(.top, 20)
        }
        .padding()  // Add padding around the content
    }
}

/// A view displayed when a critical initialization error occurs.
/// Provides an error message and a retry mechanism.
struct ErrorView: View {
    let message: String  // The error message to display
    let retryAction: () -> Void  // Action to perform when the retry button is tapped

    var body: some View {
        VStack(spacing: 20) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")  // Use filled icon for more emphasis
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)  // Slightly smaller icon
                .foregroundColor(.orange)

            // Error title
            Text("Initialization Error")
                .font(.title2.bold())  // Adjusted font size

            // Detailed error message
            Text(message)
                .font(.body)  // Use body font for better readability
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)  // Add horizontal padding

            // Retry button
            Button(action: retryAction) {
                Label("Retry Setup", systemImage: "arrow.clockwise")  // More descriptive label
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)  // Adjusted padding
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 20)
        }
        .padding()  // Add padding around the content
    }
}

/// A reusable view component for displaying a feature highlight with an icon and text.
/// Used primarily in the `WelcomeView`.
struct FeatureRow: View {
    let icon: String  // SF Symbol name for the icon
    let text: String  // Description of the feature

    var body: some View {
        HStack(spacing: 12) {
            // Icon for the feature
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24, alignment: .center)  // Ensure consistent icon alignment

            // Feature description text
            Text(text)
                .font(.body)
        }
    }
}
