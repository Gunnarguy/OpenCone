// MARK: - SettingsViewModel.swift
// SettingsViewModel.swift
// OpenCone
//
// Created by [Gunnar Hostetler] on [4/15/2025].
import Combine
import Foundation
import Security

/// View model for app settings
@MainActor
final class SettingsViewModel: ObservableObject { 
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
    @Published var reasoningEffort: String = "none" // none|low|medium|high|xhigh (GPT-5.2)
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
    @Published var showAnswerPanelBelowChat: Bool = (UserDefaults.standard.object(forKey: "ui.showAnswerPanelBelowChat") as? Bool) ?? true

    // Logging preferences
    @Published var logMinimumLevel: ProcessingLogEntry.LogLevel = .info

    /// Derived: whether the selected completion model is reasoning-capable
    var isReasoning: Bool { Configuration.isReasoningModel(completionModel) }

    // Appearance settings (removed isDarkMode as it's now handled by ThemeManager)

    // Error messaging
    @Published var errorMessage: String? = nil
    @Published var secureResetStatus: String? = nil

    // Custom model input for any OpenAI-compatible model
    @Published var customCompletionModel: String = ""
    @Published var useCustomModel: Bool = false

    // MARK: - Advanced Settings (NEW)

    // Auto-save status
    @Published var autoSaveEnabled: Bool = true
    @Published var lastAutoSaveTime: Date? = nil
    @Published var isSaving: Bool = false

    // Embedding settings
    @Published var embeddingBatchSize: Int = 50
    @Published var embeddingDimension: Int = Configuration.embeddingDimension

    // Search advanced settings
    @Published var similarityThreshold: Double = 0.0 // 0 = no threshold
    @Published var includeMetadataInResults: Bool = true
    @Published var maxContextTokens: Int = 32000
    @Published var maxOutputTokens: Int = 4000 // OpenAI max_output_tokens - GPT-5 supports 128K
    @Published var streamingEnabled: Bool = true
    @Published var webSearchEnabled: Bool = false // OpenAI Responses API web_search tool
    @Published var codeInterpreterEnabled: Bool = false // OpenAI code_interpreter tool

    // Hybrid Search settings (Dense + Sparse vectors)
    @Published var hybridSearchEnabled: Bool = false // Combine semantic + keyword search
    @Published var hybridSearchAlpha: Double = 0.5 // 1.0 = pure semantic, 0.0 = pure keyword
    @Published var currentIndexMetric: String? = nil // Set by SearchViewModel when index changes

    /// Returns true if the current index supports hybrid search (requires dotproduct metric)
    var indexSupportsHybridSearch: Bool {
        currentIndexMetric?.lowercased() == "dotproduct"
    }

    /// User-friendly message explaining why hybrid search is unavailable
    var hybridSearchDisabledReason: String? {
        guard let metric = currentIndexMetric else {
            return "Select an index first"
        }
        if metric.lowercased() != "dotproduct" {
            return "Requires dotproduct index (current: \(metric))"
        }
        return nil
    }

    // Reranking settings (two-stage retrieval)
    @Published var rerankingEnabled: Bool = false // Post-retrieval reranking
    @Published var rerankModel: String = "bge-reranker-v2-m3" // Default rerank model
    @Published var rerankTopN: Int = 5 // Number of results after reranking

    // Pinecone advanced settings
    @Published var pineconeControlPlaneVersion: String = "2024-07"
    @Published var pineconeDataPlaneVersion: String = "2024-07"
    @Published var pineconeNamespaceVersion: String = "2025-01"
    @Published var pineconeMetadataFetchVersion: String = "2025-01"

    // Timeouts and retries
    @Published var requestTimeoutSeconds: Int = 30
    @Published var maxRetries: Int = 3

    // Debug settings
    @Published var verboseLogging: Bool = false
    @Published var showDebugInfo: Bool = false

    // Conversation settings
    @Published var maxConversationTurns: Int = 10 // For client-bounded mode
    @Published var systemPromptOverride: String = ""

    // Available rerank models
    let availableRerankModels = [
        "bge-reranker-v2-m3",
        "cohere-rerank-3.5",
        "pinecone-rerank-v0",
    ]

    // Available model options
    let availableEmbeddingModels = [
        "text-embedding-ada-002",
        "text-embedding-3-small",
        "text-embedding-3-large",
    ]

    // OpenAI completion models - common options (user can also specify custom models)
    let availableCompletionModels = [
        "gpt-5.5",
        "gpt-5.4",
        "gpt-5.3",
        "gpt-5.2",
        "gpt-5",
        "gpt-4o",
        "gpt-4o-mini",
        "gpt-4.1-2025-04-14",
        "gpt-4.1-mini-2025-04-14",
        "gpt-4.1-nano-2025-04-14",
        "o3",
        "o3-mini",
        "o1",
        "o1-mini",
    ]

    let availableReasoningEffortOptions = ["none", "low", "medium", "high", "xhigh"]
    let availableConversationModes = ["server", "client"]
    let availableLogLevels = ProcessingLogEntry.LogLevel.allCases

    // Pinecone regions for AWS and GCP
    let awsRegions = [
        "us-east-1", "us-east-2", "us-west-1", "us-west-2",
        "eu-west-1", "eu-west-2", "eu-central-1",
        "ap-northeast-1", "ap-southeast-1", "ap-southeast-2",
    ]

    let gcpRegions = [
        "us-central1", "us-east1", "us-east4", "us-west1",
        "europe-west1", "europe-west4",
        "asia-northeast1", "asia-southeast1",
    ]

    var availableRegions: [String] {
        pineconeCloud == "gcp" ? gcpRegions : awsRegions
    }

    private let logger = Logger.shared
    private var cancellables = Set<AnyCancellable>()
    private let store = SecureSettingsStore.shared
    private let validator = CredentialValidator()

    /// Flag to prevent auto-save during initial load
    private var isInitialLoad = true

    // Live validation statuses
    @Published var openAIStatus: CredentialStatus = .unknown
    @Published var pineconeStatus: CredentialStatus = .unknown

    init() {
        // Load saved settings when initialized
        loadSettings()
        isInitialLoad = false

        setupAutoSave()
        setupValidation()
    }

    // MARK: - Auto-Save Setup

    private func setupAutoSave() {
        // Break up publishers into smaller groups to help compiler type-checking
        // Use .dropFirst() to skip initial values on subscription
        let chunkPublishers: [AnyPublisher<Void, Never>] = [
            $defaultChunkSize.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $defaultChunkOverlap.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $embeddingModel.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $completionModel.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $temperature.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $topP.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $reasoningEffort.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $conversationMode.dropFirst().map { _ in () }.eraseToAnyPublisher(),
        ]

        let searchPublishers: [AnyPublisher<Void, Never>] = [
            $defaultTopK.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $enforcePreferredIndex.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $preferredIndexName.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $preferredNamespace.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $showAnswerPanelBelowChat.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $logMinimumLevel.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $useCustomModel.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $customCompletionModel.dropFirst().map { _ in () }.eraseToAnyPublisher(),
        ]

        let advancedPublishers: [AnyPublisher<Void, Never>] = [
            $embeddingBatchSize.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $similarityThreshold.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $includeMetadataInResults.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $maxContextTokens.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $maxOutputTokens.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $streamingEnabled.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $webSearchEnabled.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $codeInterpreterEnabled.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $requestTimeoutSeconds.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $maxRetries.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $verboseLogging.dropFirst().map { _ in () }.eraseToAnyPublisher(),
        ]

        let pineconePublishers: [AnyPublisher<Void, Never>] = [
            $showDebugInfo.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $maxConversationTurns.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $systemPromptOverride.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $pineconeCloud.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $pineconeRegion.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $pineconeControlPlaneVersion.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $pineconeDataPlaneVersion.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $pineconeNamespaceVersion.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $pineconeMetadataFetchVersion.dropFirst().map { _ in () }.eraseToAnyPublisher(),
        ]

        let allPublishers = chunkPublishers + searchPublishers + advancedPublishers + pineconePublishers

        Publishers.MergeMany(allPublishers)
            .debounce(for: RunLoop.SchedulerTimeType.Stride(1.0), scheduler: RunLoop.main)
            .sink { [weak self] Void in
                guard let self = self, self.autoSaveEnabled, !self.isInitialLoad else { return }
                self.performAutoSave()
            }
            .store(in: &cancellables)
    }

    private func setupValidation() {
        // Debounced live validation for API keys
        $openAIAPIKey
.debounce(for: RunLoop.SchedulerTimeType.Stride(0.4), scheduler: RunLoop.main)
            .removeDuplicates()
.sink { [weak self] (_: String) in
                self?.runOpenAIValidation()
            }
            .store(in: &cancellables)

        Publishers.CombineLatest($pineconeAPIKey, $pineconeProjectId)
.debounce(for: RunLoop.SchedulerTimeType.Stride(0.4), scheduler: RunLoop.main)
    .sink { [weak self] (_: String, _: String) in
                self?.runPineconeValidation()
            }
            .store(in: &cancellables)

        // When cloud changes, validate region is still valid
        $pineconeCloud
            .dropFirst()
            .sink { [weak self] newCloud in
                guard let self = self else { return }
                let validRegions = newCloud == "gcp" ? self.gcpRegions : self.awsRegions
                if !validRegions.contains(self.pineconeRegion) {
                    self.pineconeRegion = validRegions.first ?? "us-east-1"
                }
            }
            .store(in: &cancellables)
    }

    private func performAutoSave() {
        guard !isInitialLoad else { return }

        // Cooldown: don't save if we saved less than 2 seconds ago
        if let lastSave = lastAutoSaveTime, Date().timeIntervalSince(lastSave) < 2.0 {
            return
        }

        isSaving = true
        saveSettings()
        lastAutoSaveTime = Date()

        // Brief visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isSaving = false
        }
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

        // Load custom model settings
        useCustomModel = UserDefaults.standard.bool(forKey: "useCustomModel")
        customCompletionModel = UserDefaults.standard.string(forKey: "customCompletionModel") ?? ""

        // If using custom model, ensure completionModel reflects the custom value
        if useCustomModel, !customCompletionModel.isEmpty {
            completionModel = customCompletionModel
        }

        // Load generation parameters
        temperature =
            (UserDefaults.standard.object(forKey: "openai.temperature") as? Double) ?? 0.3
        topP =
            (UserDefaults.standard.object(forKey: "openai.topP") as? Double) ?? 0.95
        reasoningEffort =
            UserDefaults.standard.string(forKey: "openai.reasoningEffort") ?? "none"

        // Clamp to valid ranges
        temperature = min(max(temperature, 0.0), 2.0)
        topP = min(max(topP, 0.0), 1.0)
        if !availableReasoningEffortOptions.contains(reasoningEffort) {
            reasoningEffort = "none"
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

        // MARK: - Advanced Settings Loading

        // Auto-save
        autoSaveEnabled = (defaults.object(forKey: "settings.autoSaveEnabled") as? Bool) ?? true

        // Embedding settings
        let storedBatchSize = defaults.integer(forKey: "embedding.batchSize")
        embeddingBatchSize = storedBatchSize > 0 ? storedBatchSize : 50
        let storedDimension = defaults.integer(forKey: "embedding.dimension")
        embeddingDimension = storedDimension > 0 ? storedDimension : Configuration.embeddingDimension

        // Search advanced settings
        similarityThreshold = (defaults.object(forKey: "search.similarityThreshold") as? Double) ?? 0.0
        includeMetadataInResults = (defaults.object(forKey: "search.includeMetadata") as? Bool) ?? true
        let storedMaxTokens = defaults.integer(forKey: "search.maxContextTokens")
        maxContextTokens = storedMaxTokens > 0 ? storedMaxTokens : 32000
        let storedMaxOutput = defaults.integer(forKey: "search.maxOutputTokens")
        maxOutputTokens = storedMaxOutput > 0 ? storedMaxOutput : 4000
        streamingEnabled = (defaults.object(forKey: "search.streamingEnabled") as? Bool) ?? true
        webSearchEnabled = (defaults.object(forKey: "search.webSearchEnabled") as? Bool) ?? false
        codeInterpreterEnabled = (defaults.object(forKey: "search.codeInterpreterEnabled") as? Bool) ?? false

        // Hybrid search settings
        hybridSearchEnabled = (defaults.object(forKey: SettingsStorageKeys.hybridSearchEnabled) as? Bool) ?? false
        hybridSearchAlpha = (defaults.object(forKey: SettingsStorageKeys.hybridSearchAlpha) as? Double) ?? 0.5

        // Reranking settings
        rerankingEnabled = (defaults.object(forKey: SettingsStorageKeys.rerankingEnabled) as? Bool) ?? false
        rerankModel = defaults.string(forKey: SettingsStorageKeys.rerankModel) ?? "bge-reranker-v2-m3"
        let storedRerankTopN = defaults.integer(forKey: SettingsStorageKeys.rerankTopN)
        rerankTopN = storedRerankTopN > 0 ? storedRerankTopN : 5

        // Pinecone API versions
        pineconeControlPlaneVersion = store.getPineconeControlPlaneVersion()
        pineconeDataPlaneVersion = store.getPineconeDataPlaneVersion()
        pineconeNamespaceVersion = store.getPineconeNamespaceVersion()
        pineconeMetadataFetchVersion = store.getPineconeMetadataFetchVersion()

        // Timeouts and retries
        let storedTimeout = defaults.integer(forKey: "network.timeoutSeconds")
        requestTimeoutSeconds = storedTimeout > 0 ? storedTimeout : 30
        let storedRetries = defaults.integer(forKey: "network.maxRetries")
        maxRetries = storedRetries > 0 ? storedRetries : 3

        // Debug settings
        verboseLogging = defaults.bool(forKey: "debug.verboseLogging")
        showDebugInfo = defaults.bool(forKey: "debug.showDebugInfo")

        // Conversation settings
        let storedMaxTurns = defaults.integer(forKey: "conversation.maxTurns")
        maxConversationTurns = storedMaxTurns > 0 ? storedMaxTurns : 10
        systemPromptOverride = defaults.string(forKey: "conversation.systemPromptOverride") ?? ""
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
        UserDefaults.standard.set(useCustomModel, forKey: "useCustomModel")
        UserDefaults.standard.set(customCompletionModel, forKey: "customCompletionModel")
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

        // MARK: - Advanced Settings Saving

        // Auto-save
        defaults.set(autoSaveEnabled, forKey: "settings.autoSaveEnabled")

        // Embedding settings
        defaults.set(embeddingBatchSize, forKey: "embedding.batchSize")
        defaults.set(embeddingDimension, forKey: "embedding.dimension")

        // Search advanced settings
        defaults.set(similarityThreshold, forKey: "search.similarityThreshold")
        defaults.set(includeMetadataInResults, forKey: "search.includeMetadata")
        defaults.set(maxContextTokens, forKey: "search.maxContextTokens")
        defaults.set(maxOutputTokens, forKey: "search.maxOutputTokens")
        defaults.set(streamingEnabled, forKey: "search.streamingEnabled")
        defaults.set(webSearchEnabled, forKey: "search.webSearchEnabled")
        defaults.set(codeInterpreterEnabled, forKey: "search.codeInterpreterEnabled")

        // Hybrid search settings
        defaults.set(hybridSearchEnabled, forKey: SettingsStorageKeys.hybridSearchEnabled)
        defaults.set(hybridSearchAlpha, forKey: SettingsStorageKeys.hybridSearchAlpha)

        // Reranking settings
        defaults.set(rerankingEnabled, forKey: SettingsStorageKeys.rerankingEnabled)
        defaults.set(rerankModel, forKey: SettingsStorageKeys.rerankModel)
        defaults.set(rerankTopN, forKey: SettingsStorageKeys.rerankTopN)

        // Pinecone API versions
        store.setPineconeControlPlaneVersion(pineconeControlPlaneVersion)
        store.setPineconeDataPlaneVersion(pineconeDataPlaneVersion)
        store.setPineconeNamespaceVersion(pineconeNamespaceVersion)
        store.setPineconeMetadataFetchVersion(pineconeMetadataFetchVersion)

        // Timeouts and retries
        defaults.set(requestTimeoutSeconds, forKey: "network.timeoutSeconds")
        defaults.set(maxRetries, forKey: "network.maxRetries")

        // Debug settings
        defaults.set(verboseLogging, forKey: "debug.verboseLogging")
        defaults.set(showDebugInfo, forKey: "debug.showDebugInfo")

        // Conversation settings
        defaults.set(maxConversationTurns, forKey: "conversation.maxTurns")
        defaults.set(systemPromptOverride, forKey: "conversation.systemPromptOverride")

        secureResetStatus = nil
        if verboseLogging {
            logger.log(level: .debug, message: "SettingsViewModel: All settings saved successfully.")
        }
    }

    /// Reset settings to defaults
    func resetToDefaults() {
        // Document processing
        defaultChunkSize = Configuration.defaultChunkSize
        defaultChunkOverlap = Configuration.defaultChunkOverlap

        // Models
        embeddingModel = Configuration.embeddingModel
        completionModel = Configuration.completionModel
        useCustomModel = false
        customCompletionModel = ""

        // Generation parameters
        temperature = 0.3
        topP = 0.95
        reasoningEffort = "none"
        conversationMode = "server"

        // Search
        defaultTopK = 10
        enforcePreferredIndex = false
        preferredIndexName = ""
        preferredNamespace = ""
        metadataPresets = []
        metadataPresetError = nil

        // UI
        showAnswerPanelBelowChat = true
        logMinimumLevel = .info

        // Advanced - Embedding
        embeddingBatchSize = 50
        embeddingDimension = Configuration.embeddingDimension

        // Advanced - Search
        similarityThreshold = 0.0
        includeMetadataInResults = true
        maxContextTokens = 32000
        maxOutputTokens = 4000
        streamingEnabled = true
        webSearchEnabled = false
        codeInterpreterEnabled = false
        hybridSearchEnabled = false
        hybridSearchAlpha = 0.5
        rerankingEnabled = false
        rerankModel = "bge-reranker-v2-m3"
        rerankTopN = 5

        // Advanced - Pinecone API versions
        pineconeControlPlaneVersion = "2024-07"
        pineconeDataPlaneVersion = "2024-07"
        pineconeNamespaceVersion = "2025-01"
        pineconeMetadataFetchVersion = "2025-01"

        // Advanced - Network
        requestTimeoutSeconds = 30
        maxRetries = 3

        // Advanced - Debug
        verboseLogging = false
        showDebugInfo = false

        // Advanced - Conversation
        maxConversationTurns = 10
        systemPromptOverride = ""

        // Auto-save stays enabled
        autoSaveEnabled = true

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
            "isDarkMode",
                // Advanced settings
                "settings.autoSaveEnabled",
            "embedding.batchSize",
            "embedding.dimension",
            "search.similarityThreshold",
            "search.includeMetadata",
            "search.maxContextTokens",
            "search.streamingEnabled",
            "network.timeoutSeconds",
            "network.maxRetries",
            "debug.verboseLogging",
            "debug.showDebugInfo",
            "conversation.maxTurns",
            "conversation.systemPromptOverride"
        ]

        keysToClear.forEach { defaults.removeObject(forKey: $0) }

        let namespacePrefix = "oc.lastNamespace."
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(namespacePrefix) }
            .forEach { defaults.removeObject(forKey: $0) }
    }

    // MARK: - Quick Actions

    /// Clear conversation history (removes server-side conversation ID)
    func clearConversationHistory() {
        defaults.removeObject(forKey: "openai.conversationId")
        logger.log(level: .info, message: "Conversation history cleared")
    }

    /// Export current settings as JSON for backup/sharing
    func exportSettingsAsJSON() -> String? {
        let settingsDict: [String: Any] = [
            "version": "1.0",
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "documentProcessing": [
                "chunkSize": defaultChunkSize,
                "chunkOverlap": defaultChunkOverlap,
            ],
            "models": [
                "embedding": embeddingModel,
                "completion": completionModel,
                "useCustomModel": useCustomModel,
                "customModel": customCompletionModel,
            ],
            "generation": [
                "temperature": temperature,
                "topP": topP,
                "reasoningEffort": reasoningEffort,
                "conversationMode": conversationMode,
            ],
            "search": [
                "topK": defaultTopK,
                "enforcePreferredIndex": enforcePreferredIndex,
                "preferredIndex": preferredIndexName,
                "preferredNamespace": preferredNamespace,
                "similarityThreshold": similarityThreshold,
                "includeMetadata": includeMetadataInResults,
                "maxContextTokens": maxContextTokens,
                "streamingEnabled": streamingEnabled,
            ],
            "pinecone": [
                "cloud": pineconeCloud,
                "region": pineconeRegion,
                "controlPlaneVersion": pineconeControlPlaneVersion,
                "dataPlaneVersion": pineconeDataPlaneVersion,
                "namespaceVersion": pineconeNamespaceVersion,
                "metadataFetchVersion": pineconeMetadataFetchVersion,
            ],
            "embedding": [
                "batchSize": embeddingBatchSize,
                "dimension": embeddingDimension,
            ],
            "network": [
                "timeoutSeconds": requestTimeoutSeconds,
                "maxRetries": maxRetries,
            ],
            "conversation": [
                "maxTurns": maxConversationTurns,
                "systemPromptOverride": systemPromptOverride,
            ],
            "ui": [
                "showAnswerPanelBelowChat": showAnswerPanelBelowChat,
                "logMinimumLevel": logMinimumLevel.rawValue,
                "verboseLogging": verboseLogging,
                "showDebugInfo": showDebugInfo,
            ],
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: settingsDict, options: .prettyPrinted),
              let jsonString = String(data: data, encoding: .utf8)
        else {
            logger.log(level: .error, message: "Failed to export settings as JSON")
            return nil
        }

        logger.log(level: .info, message: "Settings exported as JSON")
        return jsonString
    }

    /// Import settings from JSON
    func importSettings(from json: String) -> Bool {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            errorMessage = "Invalid settings JSON format"
            return false
        }

        // Document processing
        if let docProc = dict["documentProcessing"] as? [String: Any] {
            if let size = docProc["chunkSize"] as? Int { defaultChunkSize = size }
            if let overlap = docProc["chunkOverlap"] as? Int { defaultChunkOverlap = overlap }
        }

        // Models
        if let models = dict["models"] as? [String: Any] {
            if let emb = models["embedding"] as? String { embeddingModel = emb }
            if let comp = models["completion"] as? String { completionModel = comp }
            if let custom = models["useCustomModel"] as? Bool { useCustomModel = custom }
            if let customModel = models["customModel"] as? String { customCompletionModel = customModel }
        }

        // Generation
        if let gen = dict["generation"] as? [String: Any] {
            if let temp = gen["temperature"] as? Double { temperature = temp }
            if let tp = gen["topP"] as? Double { topP = tp }
            if let effort = gen["reasoningEffort"] as? String { reasoningEffort = effort }
            if let convMode = gen["conversationMode"] as? String { conversationMode = convMode }
        }

        // Search
        if let search = dict["search"] as? [String: Any] {
            if let topK = search["topK"] as? Int { defaultTopK = topK }
            if let enforce = search["enforcePreferredIndex"] as? Bool { enforcePreferredIndex = enforce }
            if let prefIdx = search["preferredIndex"] as? String { preferredIndexName = prefIdx }
            if let prefNs = search["preferredNamespace"] as? String { preferredNamespace = prefNs }
            if let simThresh = search["similarityThreshold"] as? Double { similarityThreshold = simThresh }
            if let incMeta = search["includeMetadata"] as? Bool { includeMetadataInResults = incMeta }
            if let maxTok = search["maxContextTokens"] as? Int { maxContextTokens = maxTok }
            if let stream = search["streamingEnabled"] as? Bool { streamingEnabled = stream }
        }

        // Pinecone
        if let pc = dict["pinecone"] as? [String: Any] {
            if let cloud = pc["cloud"] as? String { pineconeCloud = cloud }
            if let region = pc["region"] as? String { pineconeRegion = region }
            if let cpv = pc["controlPlaneVersion"] as? String { pineconeControlPlaneVersion = cpv }
            if let dpv = pc["dataPlaneVersion"] as? String { pineconeDataPlaneVersion = dpv }
            if let nsv = pc["namespaceVersion"] as? String { pineconeNamespaceVersion = nsv }
            if let mfv = pc["metadataFetchVersion"] as? String { pineconeMetadataFetchVersion = mfv }
        }

        // Embedding
        if let emb = dict["embedding"] as? [String: Any] {
            if let batch = emb["batchSize"] as? Int { embeddingBatchSize = batch }
            if let dim = emb["dimension"] as? Int { embeddingDimension = dim }
        }

        // Network
        if let net = dict["network"] as? [String: Any] {
            if let timeout = net["timeoutSeconds"] as? Int { requestTimeoutSeconds = timeout }
            if let retries = net["maxRetries"] as? Int { maxRetries = retries }
        }

        // Conversation
        if let conv = dict["conversation"] as? [String: Any] {
            if let maxTurns = conv["maxTurns"] as? Int { maxConversationTurns = maxTurns }
            if let sysPrompt = conv["systemPromptOverride"] as? String { systemPromptOverride = sysPrompt }
        }

        // UI
        if let ui = dict["ui"] as? [String: Any] {
            if let showPanel = ui["showAnswerPanelBelowChat"] as? Bool { showAnswerPanelBelowChat = showPanel }
            if let logLevel = ui["logMinimumLevel"] as? String,
               let level = ProcessingLogEntry.LogLevel(rawValue: logLevel)
            {
                logMinimumLevel = level
            }
            if let verbose = ui["verboseLogging"] as? Bool { verboseLogging = verbose }
            if let debug = ui["showDebugInfo"] as? Bool { showDebugInfo = debug }
        }

        saveSettings()
        logger.log(level: .info, message: "Settings imported from JSON")
        return true
    }

    /// Get a formatted summary of current settings for display
    var settingsSummary: String {
        """
        Model: \(useCustomModel ? customCompletionModel : completionModel)
        Embedding: \(embeddingModel) (\(embeddingDimension) dim)
        Chunk: \(defaultChunkSize) / \(defaultChunkOverlap) overlap
        Top-K: \(defaultTopK), Threshold: \(String(format: "%.2f", similarityThreshold))
        Region: \(pineconeCloud.uppercased()) / \(pineconeRegion)
        """
    }
}
