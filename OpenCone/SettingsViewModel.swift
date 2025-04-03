// MARK: - SettingsViewModel.swift
import Foundation
import Combine
import Security

/// View model for app settings
class SettingsViewModel: ObservableObject {
    // API Keys
    @Published var openAIAPIKey: String = ""
    @Published var pineconeAPIKey: String = ""
    @Published var pineconeProjectId: String = "" // Add this line
    
    // Configuration settings
    @Published var defaultChunkSize: Int = Configuration.defaultChunkSize
    @Published var defaultChunkOverlap: Int = Configuration.defaultChunkOverlap
    @Published var embeddingModel: String = Configuration.embeddingModel
    @Published var completionModel: String = Configuration.completionModel
    
    // Appearance settings
    @Published var isDarkMode: Bool = false
    
    // Error messaging
    @Published var errorMessage: String? = nil
    
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
        pineconeProjectId = UserDefaults.standard.string(forKey: "pineconeProjectId") ?? "" // Add this line
        
        // In a production app, this would use KeyChain instead of UserDefaults
        // This is a simplified implementation for demo purposes
    }
    
    /// Save API keys to secure storage
    func saveAPIKeys() {
        UserDefaults.standard.set(openAIAPIKey, forKey: "openAIAPIKey")
        UserDefaults.standard.set(pineconeAPIKey, forKey: "pineconeAPIKey")
        UserDefaults.standard.set(pineconeProjectId, forKey: "pineconeProjectId") // Add this line
        
        // In a production app, this would use KeyChain instead of UserDefaults
        logger.log(level: .info, message: "API keys saved")
    }
    
    /// Load all settings
    private func loadSettings() {
        loadAPIKeys()
        
        // Load configuration settings
        defaultChunkSize = UserDefaults.standard.integer(forKey: "defaultChunkSize") != 0 ?
            UserDefaults.standard.integer(forKey: "defaultChunkSize") : Configuration.defaultChunkSize
        
        defaultChunkOverlap = UserDefaults.standard.integer(forKey: "defaultChunkOverlap") != 0 ?
            UserDefaults.standard.integer(forKey: "defaultChunkOverlap") : Configuration.defaultChunkOverlap
        
        embeddingModel = UserDefaults.standard.string(forKey: "embeddingModel") ?? Configuration.embeddingModel
        completionModel = UserDefaults.standard.string(forKey: "completionModel") ?? Configuration.completionModel
        
        // Load appearance settings
        isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
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
        
        // Save appearance settings
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        
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
    
    /// Check if the configuration is valid
    func isConfigurationValid() -> Bool {
        // Check API keys
        if openAIAPIKey.isEmpty || pineconeAPIKey.isEmpty || pineconeProjectId.isEmpty { // Updated check
            errorMessage = "API keys and Project ID are required"
            return false
        }
        
        // Check chunk size and overlap
        if defaultChunkSize <= 0 {
            errorMessage = "Chunk size must be greater than zero"
            return false
        }
        
        if defaultChunkOverlap < 0 || defaultChunkOverlap >= defaultChunkSize {
            errorMessage = "Chunk overlap must be between 0 and chunk size"
            return false
        }
        
        return true
    }
    
    /// List of available OpenAI embedding models
    let availableEmbeddingModels = [
        "text-embedding-3-large",
        "text-embedding-3-small",
        "text-embedding-ada-002"
    ]
    
    /// List of available OpenAI completion models
    let availableCompletionModels = [
        "gpt-4o",
        "gpt-4-turbo",
        "gpt-4",
        "gpt-3.5-turbo"
    ]
}
