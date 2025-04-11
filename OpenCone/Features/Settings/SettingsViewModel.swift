import Combine
// MARK: - SettingsViewModel.swift
import Foundation
import Security

/// View model for app settings
class SettingsViewModel: ObservableObject {
    // API Keys
    @Published var openAIAPIKey: String = ""
    @Published var pineconeAPIKey: String = ""
    @Published var pineconeProjectId: String = ""

    // Configuration settings
    @Published var defaultChunkSize: Int = Configuration.defaultChunkSize
    @Published var defaultChunkOverlap: Int = Configuration.defaultChunkOverlap
    @Published var embeddingModel: String = Configuration.embeddingModel
    @Published var completionModel: String = Configuration.completionModel

    // Appearance settings (removed isDarkMode as it's now handled by ThemeManager)

    // Error messaging
    @Published var errorMessage: String? = nil

    // Available model options
    let availableEmbeddingModels = [
        "text-embedding-ada-002", "text-embedding-3-small", "text-embedding-3-large",
    ]
    let availableCompletionModels = ["gpt-4o-mini", "gpt-4o"]

    private let logger = Logger.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Load saved settings when initialized
        loadSettings()
    }

    /// Load API keys from secure storage
    func loadAPIKeys() {
        openAIAPIKey = UserDefaults.standard.string(forKey: "openAIAPIKey") ?? ""
        pineconeAPIKey = UserDefaults.standard.string(forKey: "pineconeAPIKey") ?? ""
        pineconeProjectId = UserDefaults.standard.string(forKey: "pineconeProjectId") ?? ""

        // In a production app, this would use KeyChain instead of UserDefaults
        // This is a simplified implementation for demo purposes
    }

    /// Save API keys to secure storage
    func saveAPIKeys() {
        UserDefaults.standard.set(openAIAPIKey, forKey: "openAIAPIKey")
        UserDefaults.standard.set(pineconeAPIKey, forKey: "pineconeAPIKey")
        UserDefaults.standard.set(pineconeProjectId, forKey: "pineconeProjectId")

        // In a production app, this would use KeyChain instead of UserDefaults
        logger.log(level: .info, message: "API keys saved")
    }

    /// Load all settings
    func loadSettings() {
        logger.log(level: .info, message: "SettingsViewModel: Loading settings")

        // Load API keys
        loadAPIKeys()

        // Load configuration settings from UserDefaults
        defaultChunkSize =
            UserDefaults.standard.integer(forKey: "defaultChunkSize") != 0
            ? UserDefaults.standard.integer(forKey: "defaultChunkSize")
            : Configuration.defaultChunkSize

        defaultChunkOverlap =
            UserDefaults.standard.integer(forKey: "defaultChunkOverlap") != 0
            ? UserDefaults.standard.integer(forKey: "defaultChunkOverlap")
            : Configuration.defaultChunkOverlap

        embeddingModel =
            UserDefaults.standard.string(forKey: "embeddingModel") ?? Configuration.embeddingModel
        completionModel =
            UserDefaults.standard.string(forKey: "completionModel") ?? Configuration.completionModel
    }

    /// Save all settings
    func saveSettings() {
        logger.log(level: .info, message: "SettingsViewModel: saveSettings() called.")
        saveAPIKeys()

        // Save configuration settings
        UserDefaults.standard.set(defaultChunkSize, forKey: "defaultChunkSize")
        UserDefaults.standard.set(defaultChunkOverlap, forKey: "defaultChunkOverlap")
        UserDefaults.standard.set(embeddingModel, forKey: "embeddingModel")
        UserDefaults.standard.set(completionModel, forKey: "completionModel")

        logger.log(level: .info, message: "SettingsViewModel: Settings saved to UserDefaults.")
    }

    /// Reset settings to defaults
    func resetToDefaults() {
        defaultChunkSize = Configuration.defaultChunkSize
        defaultChunkOverlap = Configuration.defaultChunkOverlap
        embeddingModel = Configuration.embeddingModel
        completionModel = Configuration.completionModel

        logger.log(level: .info, message: "Settings reset to defaults")
    }

    /// Validates if the Pinecone API key has the correct format
    /// - Returns: True if the key is non-empty and starts with "pcsk_"
    func isPineconeKeyValid() -> Bool {
        return !pineconeAPIKey.isEmpty && pineconeAPIKey.hasPrefix("pcsk_")
    }

    /// Check if the configuration is valid
    func isConfigurationValid() -> Bool {
        // Check OpenAI API key
        if openAIAPIKey.isEmpty {
            errorMessage = "OpenAI API key is required"
            return false
        }

        // Check Pinecone API key format
        if !isPineconeKeyValid() {
            errorMessage = "Pinecone API key must start with 'pcsk_'"
            return false
        }

        // Check Pinecone Project ID
        if pineconeProjectId.isEmpty {
            errorMessage = "Pinecone Project ID is required"
            return false
        }

        // Check chunk size and overlap
        if defaultChunkSize <= 0 {
            errorMessage = "Chunk size must be greater than zero"
            return false
        }

        if defaultChunkOverlap < 0 {
            errorMessage = "Chunk overlap cannot be negative"
            return false
        }

        if defaultChunkOverlap >= defaultChunkSize {
            errorMessage = "Chunk overlap must be less than chunk size"
            return false
        }

        // Clear any previous error messages if validation passes
        errorMessage = nil
        return true
    }
}
