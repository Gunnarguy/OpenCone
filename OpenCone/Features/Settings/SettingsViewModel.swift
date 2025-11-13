// MARK: - SettingsViewModel.swift
// SettingsViewModel.swift
// OpenCone
//
// Created by [Gunnar Hostetler] on [4/15/2025].
import Combine
import Foundation
import Security

/// View model for app settings
class SettingsViewModel: ObservableObject {
    private let defaults = UserDefaults.standard

    // API Keys
    @Published var openAIAPIKey: String = ""
    @Published var pineconeAPIKey: String = ""
    @Published var pineconeProjectId: String = ""
    @Published var pineconeCloud: String = SecureSettingsStore.shared.getPineconeCloud()
    @Published var pineconeRegion: String = SecureSettingsStore.shared.getPineconeRegion()

    // Configuration settings
    @Published var defaultChunkSize: Int = Configuration.defaultChunkSize
    @Published var defaultChunkOverlap: Int = Configuration.defaultChunkOverlap
    @Published var embeddingModel: String = Configuration.embeddingModel
    @Published var completionModel: String = Configuration.completionModel

    // OpenAI generation parameters
    @Published var temperature: Double = 0.3
    @Published var topP: Double = 0.95
    @Published var reasoningEffort: String = "medium" // low|medium|high
    @Published var conversationMode: String = "server" // "server" (Responses-managed) | "client" (bounded history)

    // Search defaults
    @Published var defaultTopK: Int = 10
    @Published var enforcePreferredIndex: Bool = false
    @Published var preferredIndexName: String = ""
    @Published var preferredNamespace: String = ""
    @Published var metadataPresets: [SettingsMetadataPreset] = []
    @Published var newPresetField: String = ""
    @Published var newPresetValue: String = ""
    @Published var metadataPresetError: String? = nil

    // UI preferences
    @Published var showAnswerPanelBelowChat: Bool = (UserDefaults.standard.object(forKey: "ui.showAnswerPanelBelowChat") as? Bool) ?? true {
        didSet {
            UserDefaults.standard.set(self.showAnswerPanelBelowChat, forKey: "ui.showAnswerPanelBelowChat")
        }
    }

    // Logging preferences
    @Published var logMinimumLevel: ProcessingLogEntry.LogLevel = .info

    /// Derived: whether the selected completion model is reasoning-capable
    var isReasoning: Bool { Configuration.isReasoningModel(completionModel) }

    // Appearance settings (removed isDarkMode as it's now handled by ThemeManager)

    // Error messaging
    @Published var errorMessage: String? = nil
    @Published var secureResetStatus: String? = nil

    // Available model options
    let availableEmbeddingModels = [
        "text-embedding-ada-002",
        "text-embedding-3-small",
        "text-embedding-3-large",
    ]

    // Updated completion models list with newer models
    let availableCompletionModels = [
        "gpt-5",
        "gpt-4o-mini",
        "gpt-4o",
        "gpt-4.1-nano-2025-04-14",
        "gpt-4.1-mini-2025-04-14",
        "gpt-4.1-2025-04-14",
    ]

    let availableReasoningEffortOptions = ["low", "medium", "high"]
    let availableConversationModes = ["server", "client"]
    let availableLogLevels = ProcessingLogEntry.LogLevel.allCases

    private let logger = Logger.shared
    private var cancellables = Set<AnyCancellable>()
    private let store = SecureSettingsStore.shared
    private let validator = CredentialValidator()

    // Live validation statuses
    @Published var openAIStatus: CredentialStatus = .unknown
    @Published var pineconeStatus: CredentialStatus = .unknown

    init() {
        // Load saved settings when initialized
        loadSettings()
        // Debounced live validation
        $openAIAPIKey
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.runOpenAIValidation()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest($pineconeAPIKey, $pineconeProjectId)
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.runPineconeValidation()
            }
            .store(in: &cancellables)
    }

    /// Load API keys from secure storage
    func loadAPIKeys() {
        openAIAPIKey = store.getOpenAIKey()
        pineconeAPIKey = store.getPineconeAPIKey()
        pineconeProjectId = store.getPineconeProjectId()
    }

    /// Save API keys to secure storage
    func saveAPIKeys() {
        _ = store.setOpenAIKey(openAIAPIKey)
        _ = store.setPineconeAPIKey(pineconeAPIKey)
        _ = store.setPineconeProjectId(pineconeProjectId)
        logger.log(level: .info, message: "API keys saved to Keychain")
    }

    /// Load all settings
    func loadSettings() {
        logger.log(level: .info, message: "SettingsViewModel: Loading settings")

        // Load API keys
        loadAPIKeys()
        // Load Pinecone location prefs
        pineconeCloud = store.getPineconeCloud()
        pineconeRegion = store.getPineconeRegion()

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

        // Load generation parameters
        temperature =
            (UserDefaults.standard.object(forKey: "openai.temperature") as? Double) ?? 0.3
        topP =
            (UserDefaults.standard.object(forKey: "openai.topP") as? Double) ?? 0.95
        reasoningEffort =
            UserDefaults.standard.string(forKey: "openai.reasoningEffort") ?? "medium"

        // Clamp to valid ranges
        temperature = min(max(temperature, 0.0), 2.0)
        topP = min(max(topP, 0.0), 1.0)
        if !availableReasoningEffortOptions.contains(reasoningEffort) {
            reasoningEffort = "medium"
        }

        // Conversation mode
        conversationMode = UserDefaults.standard.string(forKey: "openai.conversationMode") ?? "server"
        if !availableConversationModes.contains(conversationMode) {
            conversationMode = "server"
        }

        // Search defaults
        let storedTopK = defaults.integer(forKey: SettingsStorageKeys.searchTopK)
        defaultTopK = storedTopK > 0 ? storedTopK : 10
        enforcePreferredIndex = defaults.bool(forKey: SettingsStorageKeys.searchEnforcePreferredIndex)
        preferredIndexName = defaults.string(forKey: SettingsStorageKeys.searchPreferredIndex) ?? ""
        preferredNamespace = defaults.string(forKey: SettingsStorageKeys.searchPreferredNamespace) ?? ""
        loadMetadataPresets()

        // Logging level
        if let storedLevel = defaults.string(forKey: SettingsStorageKeys.logMinimumLevel),
           let level = ProcessingLogEntry.LogLevel(rawValue: storedLevel) {
            logMinimumLevel = level
        } else {
            logMinimumLevel = .info
        }

        // UI preferences
        showAnswerPanelBelowChat = (UserDefaults.standard.object(forKey: "ui.showAnswerPanelBelowChat") as? Bool) ?? true
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
        UserDefaults.standard.set(temperature, forKey: "openai.temperature")
        UserDefaults.standard.set(topP, forKey: "openai.topP")
        UserDefaults.standard.set(reasoningEffort, forKey: "openai.reasoningEffort")
        UserDefaults.standard.set(conversationMode, forKey: "openai.conversationMode")

        // UI preferences
        UserDefaults.standard.set(showAnswerPanelBelowChat, forKey: "ui.showAnswerPanelBelowChat")

        // Search defaults
        defaultTopK = max(1, min(defaultTopK, 100))
        defaults.set(defaultTopK, forKey: SettingsStorageKeys.searchTopK)
        defaults.set(enforcePreferredIndex, forKey: SettingsStorageKeys.searchEnforcePreferredIndex)
        let trimmedIndex = preferredIndexName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedIndex.isEmpty {
            defaults.removeObject(forKey: SettingsStorageKeys.searchPreferredIndex)
        } else {
            defaults.set(trimmedIndex, forKey: SettingsStorageKeys.searchPreferredIndex)
        }
        let trimmedNamespace = preferredNamespace.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedNamespace.isEmpty {
            defaults.removeObject(forKey: SettingsStorageKeys.searchPreferredNamespace)
        } else {
            defaults.set(trimmedNamespace, forKey: SettingsStorageKeys.searchPreferredNamespace)
        }
        persistMetadataPresets()

        // Logging
        defaults.set(logMinimumLevel.rawValue, forKey: SettingsStorageKeys.logMinimumLevel)

        // Persist Pinecone location prefs
        store.setPineconeCloud(pineconeCloud)
        store.setPineconeRegion(pineconeRegion)

        secureResetStatus = nil
        logger.log(level: .info, message: "SettingsViewModel: Settings saved to UserDefaults.")
    }

    /// Reset settings to defaults
    func resetToDefaults() {
        defaultChunkSize = Configuration.defaultChunkSize
        defaultChunkOverlap = Configuration.defaultChunkOverlap
        embeddingModel = Configuration.embeddingModel
        completionModel = Configuration.completionModel
        temperature = 0.3
        topP = 0.95
        reasoningEffort = "medium"
        conversationMode = "server"
        defaultTopK = 10
        enforcePreferredIndex = false
        preferredIndexName = ""
        preferredNamespace = ""
        metadataPresets = []
        metadataPresetError = nil
        showAnswerPanelBelowChat = true
        logMinimumLevel = .info
        secureResetStatus = nil

        logger.log(level: .info, message: "Settings reset to defaults")
    }

    /// Clears stored secrets plus onboarding markers so a user can revoke access in Settings.
    func resetSecureState() {
        logger.log(level: .info, message: "Resetting stored credentials and preferences at user request.")

        store.clearSecretsAndPreferences()
        clearPersistedSettings()
        resetToDefaults()

        openAIAPIKey = ""
        pineconeAPIKey = ""
        pineconeProjectId = ""
        pineconeCloud = store.getPineconeCloud()
        pineconeRegion = store.getPineconeRegion()

        openAIStatus = .unknown
        pineconeStatus = .unknown
        secureResetStatus = "Stored keys removed. Force-quit and relaunch OpenCone before adding new credentials."
    }

    // MARK: - Live validation

    private func runOpenAIValidation() {
        let key = openAIAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            openAIStatus = .unknown
            return
        }
        openAIStatus = .validating
        Task {
            let status = await validator.validateOpenAIKey(key)
            await MainActor.run { self.openAIStatus = status }
        }
    }

    private func runPineconeValidation() {
        let key = pineconeAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let pid = pineconeProjectId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty || !pid.isEmpty else {
            pineconeStatus = .unknown
            return
        }
        pineconeStatus = .validating
        Task {
            let status = await validator.validatePinecone(apiKey: key, projectId: pid)
            await MainActor.run { self.pineconeStatus = status }
        }
    }

    // Public validate triggers
    func validateOpenAI() { runOpenAIValidation() }
    func validatePinecone() { runPineconeValidation() }
    func validateAll() { runOpenAIValidation(); runPineconeValidation() }

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

        if defaultTopK <= 0 {
            errorMessage = "Default Top K must be greater than zero"
            return false
        }

        if metadataPresets.contains(where: { !$0.trimmed().isValid }) {
            errorMessage = "Metadata presets require both a field and value"
            return false
        }

        // Clear any previous error messages if validation passes
        errorMessage = nil
        return true
    }

    // MARK: - Metadata Presets

    func addMetadataPreset() {
        let field = newPresetField.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = newPresetValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !field.isEmpty else {
            metadataPresetError = "Preset field is required"
            return
        }

        guard !value.isEmpty else {
            metadataPresetError = "Preset value is required"
            return
        }

        guard PineconeMetadataFilter.parse(from: value) != nil else {
            metadataPresetError = "Unable to interpret preset value"
            return
        }

        metadataPresets.append(SettingsMetadataPreset(field: field, rawValue: value))
        newPresetField = ""
        newPresetValue = ""
        metadataPresetError = nil
    }

    func removeMetadataPreset(_ preset: SettingsMetadataPreset) {
        metadataPresets.removeAll { $0.id == preset.id }
        metadataPresetError = nil
    }

    private func loadMetadataPresets() {
        guard let data = defaults.data(forKey: SettingsStorageKeys.searchMetadataPresets) else {
            metadataPresets = []
            return
        }

        do {
            metadataPresets = try JSONDecoder().decode([SettingsMetadataPreset].self, from: data)
        } catch {
            metadataPresets = []
            logger.log(level: .warning, message: "Failed to decode metadata presets", context: error.localizedDescription)
        }
    }

    private func persistMetadataPresets() {
        let trimmed = metadataPresets.map { $0.trimmed() }.filter { $0.isValid }
        metadataPresets = trimmed

        guard !trimmed.isEmpty else {
            defaults.removeObject(forKey: SettingsStorageKeys.searchMetadataPresets)
            return
        }

        do {
            let data = try JSONEncoder().encode(trimmed)
            defaults.set(data, forKey: SettingsStorageKeys.searchMetadataPresets)
        } catch {
            logger.log(level: .error, message: "Failed to persist metadata presets", context: error.localizedDescription)
        }
    }

    private func clearPersistedSettings() {
        let keysToClear: [String] = [
            "defaultChunkSize",
            "defaultChunkOverlap",
            "embeddingModel",
            "completionModel",
            "openai.temperature",
            "openai.topP",
            "openai.reasoningEffort",
            "openai.conversationMode",
            "openai.conversationId",
            "ui.showAnswerPanelBelowChat",
            SettingsStorageKeys.searchTopK,
            SettingsStorageKeys.searchEnforcePreferredIndex,
            SettingsStorageKeys.searchPreferredIndex,
            SettingsStorageKeys.searchPreferredNamespace,
            SettingsStorageKeys.searchMetadataPresets,
            SettingsStorageKeys.logMinimumLevel,
            "oc.lastIndex",
            "hasLaunchedBefore",
            "SecurityScopedBookmarkConsentAcknowledged",
            "themeId",
            "isDarkMode"
        ]

        keysToClear.forEach { defaults.removeObject(forKey: $0) }

        let namespacePrefix = "oc.lastNamespace."
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(namespacePrefix) }
            .forEach { defaults.removeObject(forKey: $0) }
    }
}
