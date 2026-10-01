import Combine
import Foundation
import SwiftUI

// MARK: - MainActor Annotation for Swift 6

// MARK: - Error Handling Enum

/// Defines specific errors that can occur during search operations.
enum SearchError: LocalizedError {
    case indexLoadingFailed(Error)
    case indexSetFailed(Error)
    case namespaceLoadingFailed(Error)
    case embeddingFailed(Error)
    case queryFailed(Error)
    case answerGenerationFailed(Error)
    case missingSelection(String)  // For cases where index/namespace/results are needed

    var errorDescription: String? {
        switch self {
        case .indexLoadingFailed: return "Failed to load Pinecone indexes."
        case .indexSetFailed: return "Failed to set the Pinecone index."
        case .namespaceLoadingFailed: return "Failed to load namespaces for the selected index."
        case .embeddingFailed: return "Failed to generate embedding for the query."
        case .queryFailed: return "Failed to query the Pinecone index."
        case .answerGenerationFailed: return "Failed to generate an answer from OpenAI."
        case .missingSelection(let item): return "Please select \(item) before proceeding."
        }
    }
    var recoverySuggestion: String? {
        switch self {
        case .indexLoadingFailed, .namespaceLoadingFailed, .queryFailed:
            return "Please check your network connection and Pinecone configuration."
        case .indexSetFailed:
            return "Please ensure the selected index exists and your configuration is correct."
        case .embeddingFailed, .answerGenerationFailed:
            return "Please check your network connection and OpenAI API key."
        case .missingSelection:
            return "Make the required selection in the configuration section."
        }
    }

    // Optionally include the underlying error for logging/debugging
    var underlyingError: Error? {
        switch self {
        case .indexLoadingFailed(let error),
            .indexSetFailed(let error),
            .namespaceLoadingFailed(let error),
            .embeddingFailed(let error),
            .queryFailed(let error),
            .answerGenerationFailed(let error):
            return error
        case .missingSelection:
            return nil
        }
    }
}

// MARK: - Pinecone Metadata Filter Representation

enum PineconeMetadataFilter: Equatable {
    case stringEquals(String)
    case numberEquals(Double)
    case boolEquals(Bool)
    case inList([String])
    case numberRange(min: Double?, max: Double?)
    case stringContains(String)

    /// Human readable representation used when logging active filters.
    var displayValue: String {
        switch self {
        case .stringEquals(let value):
            return "\"\(value)\""
        case .numberEquals(let value):
            return String(value)
        case .boolEquals(let value):
            return value ? "true" : "false"
        case .inList(let values):
            return "[" + values.joined(separator: ", ") + "]"
        case .numberRange(let min, let max):
            switch (min, max) {
            case let (min?, max?):
                return "between \(min) and \(max)"
            case let (min?, nil):
                return "≥ \(min)"
            case let (nil, max?):
                return "≤ \(max)"
            default:
                return "any"
            }
        case .stringContains(let fragment):
            return "contains \"\(fragment)\""
        }
    }

    /// Serialized predicate that matches Pinecone filter JSON structure.
    func serializedPredicate() -> [String: Any] {
        switch self {
        case .stringEquals(let value):
            return ["$eq": value]
        case .numberEquals(let value):
            return ["$eq": value]
        case .boolEquals(let value):
            return ["$eq": value]
        case .inList(let values):
            return ["$in": values]
        case .numberRange(let min, let max):
            var predicate: [String: Any] = [:]
            if let min { predicate["$gte"] = min }
            if let max { predicate["$lte"] = max }
            return predicate
        case .stringContains(let fragment):
            return ["$contains": fragment]
        }
    }

    /// Attempt to parse a user-supplied string into a metadata filter.
    static func parse(from raw: String) -> PineconeMetadataFilter? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        if lower == "true" { return .boolEquals(true) }
        if lower == "false" { return .boolEquals(false) }

        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
            let inner = trimmed.dropFirst().dropLast()
            let components = inner
                .split(separator: ",")
                .map { String($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                .filter { !$0.isEmpty }
            if !components.isEmpty {
                return .inList(components)
            }
        }

        if trimmed.contains("..") {
            let rangeParts = trimmed.components(separatedBy: "..")
            if rangeParts.count == 2,
               let min = Double(rangeParts[0].trimmingCharacters(in: .whitespacesAndNewlines)),
               let max = Double(rangeParts[1].trimmingCharacters(in: .whitespacesAndNewlines)) {
                return .numberRange(min: min, max: max)
            }
        }

        if trimmed.hasPrefix(">=") {
            let valueString = trimmed.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
            if let value = Double(valueString) {
                return .numberRange(min: value, max: nil)
            }
        }

        if trimmed.hasPrefix("<=") {
            let valueString = trimmed.dropFirst(2).trimmingCharacters(in: .whitespacesAndNewlines)
            if let value = Double(valueString) {
                return .numberRange(min: nil, max: value)
            }
        }

        if trimmed.hasPrefix("*") && trimmed.hasSuffix("*") && trimmed.count >= 3 {
            let inner = trimmed.dropFirst().dropLast()
            if !inner.isEmpty {
                return .stringContains(String(inner))
            }
        }

        if let number = Double(trimmed) {
            return .numberEquals(number)
        }

        return .stringEquals(trimmed)
    }
}

// MARK: - Search View Model

/// View model for the search functionality
@MainActor
final class SearchViewModel: ObservableObject { 

    // MARK: - Constants
    private enum Constants {
        static let topKResults = 10  // Reduced from 20 for potentially faster/cheaper generation
        static let openAISystemPrompt =
            """
            You are a helpful AI assistant with access to the user's documents. Answer questions based on the provided context.

            - If the user's query is a single word or phrase, provide a helpful summary of relevant information from the context about that topic.
            - If the user asks a specific question, answer it directly using the context.
            - If the context doesn't contain relevant information, say so clearly.
            - Be conversational and concise.
            """

        /// Transition duration for animations
        static let transitionDuration: Double = 0.3

        /// Semantic colors for result categories
        static let scoreColors: [(threshold: Float, name: String)] = [
            (0.9, "High Relevance"),
            (0.7, "Medium Relevance"),
            (0.0, "Low Relevance"),
        ]

        static let watchdogDelayNanoseconds: UInt64 = 30_000_000_000
    }

    /// Returns the effective system prompt - custom override if set, otherwise default
    private var effectiveSystemPrompt: String {
        let override = settingsViewModel.systemPromptOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        if override.isEmpty {
            return Constants.openAISystemPrompt
        }
        return "\(Constants.openAISystemPrompt)\n\nAdditional instructions:\n\(override)"
    }

    // MARK: - Dependencies
    private let pineconeService: PineconeService
    private let openAIService: OpenAIService
    private let embeddingService: EmbeddingService
    let settingsViewModel: SettingsViewModel
    // Routing across indexes; nil where the app is built without it, as in previews and tests
    private let indexRouter: IndexRouter?
    private let indexSurveyor: IndexSurveyor?
    private let indexCatalogStore: IndexCatalogStore?
    private var indexSurveyTask: Task<Void, Never>? = nil
    private var routingTask: Task<Void, Never>? = nil
    private var activeSurveys = 0
    private var summaryDraftAttempts: [String: Date] = [:]
    private let routableProfileMaxAge: TimeInterval = 60 * 60
    private let unroutableProfileMaxAge: TimeInterval = 10 * 60
    private let logger = Logger.shared
    private var themeManager = ThemeManager.shared
    private let defaults = UserDefaults.standard
    private let preferences = PineconePreferenceResolver()
    private let metadataPresetKey = SettingsStorageKeys.searchMetadataPresets
    private let topKKey = SettingsStorageKeys.searchTopK
    private var configuredTopK: Int {
        let stored = defaults.integer(forKey: topKKey)
        if stored > 0 { return stored }
        return Constants.topKResults
    }

    // Published properties for UI binding
    @Published var searchQuery = ""
    @Published var isSearching = false
    @Published var searchResults: [SearchResultModel] = []
    @Published var generatedAnswer: String = ""
    @Published var selectedResultIDs: Set<UUID> = []
    
    var selectedResults: [SearchResultModel] {
        searchResults.filter { selectedResultIDs.contains($0.id) }
    }
    @Published var errorMessage: String? = nil  // Holds user-facing error message
    @Published var pineconeIndexes: [String] = []
    @Published var namespaces: [String] = []
    @Published var selectedIndex: String? = nil
    @Published var selectedNamespace: String? = nil
    @Published var indexDimension: Int? = nil
    @Published var indexMetric: String? = nil // cosine, euclidean, or dotproduct

    /// Returns true if the current index supports hybrid search (requires dotproduct metric)
    var indexSupportsHybridSearch: Bool {
        indexMetric?.lowercased() == "dotproduct"
    }
    @Published var lastSearchTime: Date? = nil
    @Published var currentTheme: OCTheme = ThemeManager.shared.currentTheme
    @Published var messages: [ChatMessage] = []
    @Published var conversationId: String? = UserDefaults.standard.string(forKey: "openai.conversationId")
    @Published var highlightedResultID: UUID? = nil
    @Published var expandedResultIDs: Set<UUID> = []
    @Published var metadataFilters: [String: PineconeMetadataFilter] = [:]
    @Published var newFilterField: String = ""
    @Published var newFilterValue: String = ""
    @Published var filterParseError: String? = nil

    // Code interpreter outputs from current search
    @Published var codeInterpreterOutputs: [CodeInterpreterOutput] = []

    // Routing across indexes
    @Published var indexProfiles: [String: IndexProfile] = [:]
    /// What a routed search is doing before the answer starts, such as which indexes it searches
    @Published var routingStatus: String? = nil
    @Published var isSurveyingIndexes = false

    // Visual state properties
    @Published var searchResultsOpacity: Double = 0.0
    @Published var answerGenerationProgress: Double = 0.0

    // Cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    private var currentStreamTask: Task<Void, Never>? = nil

    init(
        pineconeService: PineconeService,
        openAIService: OpenAIService,
        embeddingService: EmbeddingService,
        settingsViewModel: SettingsViewModel,
        indexRouter: IndexRouter? = nil,
        indexSurveyor: IndexSurveyor? = nil,
        indexCatalogStore: IndexCatalogStore? = nil
    ) {
        self.pineconeService = pineconeService
        self.openAIService = openAIService
        self.embeddingService = embeddingService
        self.settingsViewModel = settingsViewModel
        self.indexRouter = indexRouter
        self.indexSurveyor = indexSurveyor
        self.indexCatalogStore = indexCatalogStore
        self.indexProfiles = indexCatalogStore?.load() ?? [:]

        // Subscribe to theme changes
        themeManager.$currentTheme
            .sink { [weak self] theme in
                self?.currentTheme = theme
            }
            .store(in: &cancellables)

        loadDefaultMetadataFilters()
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PineconeIndexListDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.loadIndexes()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PineconeIndexContentDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let index = notification.userInfo?["index"] as? String
            Task { @MainActor [weak self] in
                self?.indexContentDidChange(index)
            }
        }
    }

    private func loadDefaultMetadataFilters() {
        guard let data = defaults.data(forKey: metadataPresetKey) else {
            metadataFilters = [:]
            filterParseError = nil
            return
        }

        do {
            let presets = try JSONDecoder().decode([SettingsMetadataPreset].self, from: data)
            var resolved: [String: PineconeMetadataFilter] = [:]

            for preset in presets {
                let trimmed = preset.trimmed()
                guard trimmed.isValid else { continue }
                if let parsed = PineconeMetadataFilter.parse(from: trimmed.rawValue) {
                    resolved[trimmed.field] = parsed
                } else {
                    logger.log(
                        level: .warning,
                        message: "Skipping metadata preset with unparseable value",
                        context: "field=\(trimmed.field)"
                    )
                }
            }

            metadataFilters = resolved
            filterParseError = nil
        } catch {
            metadataFilters = [:]
            filterParseError = nil
            logger.log(level: .warning, message: "Failed to decode metadata presets", context: error.localizedDescription)
        }
    }

    /// Get color for a search result based on score
    func getColorForScore(_ score: Float) -> Color {
        if score > 0.9 {
            return currentTheme.successColor
        } else if score > 0.7 {
            return currentTheme.infoColor
        } else {
            return currentTheme.warningColor
        }
    }

    /// Get relevance label for a search result based on score
    func getRelevanceLabel(_ score: Float) -> String {
        for (threshold, name) in Constants.scoreColors {
            if score >= threshold {
                return name
            }
        }
        return "Low Relevance"
    }

    /// Load available Pinecone indexes
    /// Uses cached data immediately for faster startup, then refreshes in background
    func loadIndexes() async {
        // First, try to get cached indexes for instant display
        do {
            let cachedIndexes = try await pineconeService.listIndexes(forceRefresh: false)
            if !cachedIndexes.isEmpty, self.pineconeIndexes.isEmpty {
                // Show cached data immediately
                self.pineconeIndexes = cachedIndexes
                let resolvedIndex = self.preferences.resolveIndex(
                    availableIndexes: cachedIndexes,
                    currentSelection: self.selectedIndex
                )
                if resolvedIndex != nil, self.selectedIndex == nil {
                    self.selectedIndex = resolvedIndex
                }
            }
        } catch {
            // Ignore cache errors, we'll load fresh below
        }

        // Now load fresh data
        do {
            let indexes = try await pineconeService.listIndexes(forceRefresh: true)
            self.pineconeIndexes = indexes
            self.errorMessage = nil

            guard !indexes.isEmpty else {
                self.selectedIndex = nil
                self.namespaces = []
                self.selectedNamespace = nil
                self.indexDimension = nil
                return
            }

            let previousIndex = self.selectedIndex
            let resolvedIndex = self.preferences.resolveIndex(
                availableIndexes: indexes,
                currentSelection: previousIndex
            )

            self.selectedIndex = resolvedIndex

            if previousIndex != resolvedIndex {
                self.indexDimension = nil
            }

            let needsDescribe = previousIndex != resolvedIndex || self.indexDimension == nil

            if let indexName = resolvedIndex {
                if needsDescribe { 
                    await setIndex(indexName)
                } else {
                    await loadNamespaces()
                }
            }

            scheduleIndexSurvey()
        } catch {
            handleError(SearchError.indexLoadingFailed(error))
        }
    }

    /// Set the current Pinecone index
    /// - Parameter indexName: Name of the index to set
    func setIndex(_ indexName: String) async {
        do {
            // Set current index first to get the host
            try await pineconeService.setCurrentIndex(indexName)

            self.selectedIndex = indexName
            self.selectedNamespace = nil
            self.namespaces = []
            self.indexDimension = nil
            self.indexMetric = nil

            // Now describe the index to get its dimension and metric
            let indexDetails = try await pineconeService.describeIndex(name: indexName)

            self.indexDimension = indexDetails.dimension
            self.indexMetric = indexDetails.metric

            // Sync metric to SettingsViewModel for UI binding
            self.settingsViewModel.currentIndexMetric = indexDetails.metric

            // Log index capabilities
            let hybridSupported = indexDetails.metric.lowercased() == "dotproduct"
            self.logger.log(
                level: .info,
                message: "Index '\(indexName)' selected (dimension: \(indexDetails.dimension), metric: \(indexDetails.metric), hybrid: \(hybridSupported ? "supported" : "not supported"))"
            )

            preferences.recordLastIndex(indexName)

            // Load namespaces for the new index
            await loadNamespaces()
        } catch {
            handleError(SearchError.indexSetFailed(error))
        }
    }

    /// Load available namespaces for the current index
    func loadNamespaces() async {
        guard selectedIndex != nil else { 
            self.namespaces = []
            self.selectedNamespace = nil
            return
        }

        do {
            let namespaces = try await pineconeService.listNamespaces()
            self.namespaces = namespaces

            let resolvedNamespace = self.preferences.resolveNamespace(
                availableNamespaces: namespaces,
                index: self.selectedIndex,
                currentSelection: self.selectedNamespace
            )

            self.selectedNamespace = resolvedNamespace
            let persistence = (self.selectedIndex, resolvedNamespace)

            if let index = persistence.0 {
                if let namespace = persistence.1 {
                    preferences.recordNamespace(namespace, for: index)
                } else {
                    preferences.clearNamespace(for: index)
                }
            }

            // A namespace added or removed since the last survey makes that profile stale
            if let index = selectedIndex, var profile = indexProfiles[index],
               Set(profile.namespaceNames) != Set(namespaces) {
                profile.surveyedAt = .distantPast
                indexProfiles[index] = profile
            }
            scheduleIndexSurvey()
        } catch {
            handleError(SearchError.namespaceLoadingFailed(error))
        }
    }

    /// Set the current namespace
    @MainActor
    func setNamespace(_ namespace: String?) {
        let trimmed = namespace.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        selectedNamespace = trimmed

        guard let index = selectedIndex else { return }

        if let trimmed {
            preferences.recordNamespace(trimmed, for: index)
        } else {
            preferences.clearNamespace(for: index)
        }
    }

    /// Update or clear a metadata filter applied to Pinecone queries
    func setMetadataFilter(field: String, value: String?) {
        if let value, !value.isEmpty {
            metadataFilters[field] = .stringEquals(value)
        } else {
            metadataFilters.removeValue(forKey: field)
        }
        filterParseError = nil
    }

    /// Update or clear a metadata filter with a custom condition
    func setMetadataFilter(field: String, filter: PineconeMetadataFilter?) {
        if let filter {
            metadataFilters[field] = filter
        } else {
            metadataFilters.removeValue(forKey: field)
        }
        filterParseError = nil
    }

    /// Remove a metadata filter by its field key.
    func removeMetadataFilter(field: String) {
        metadataFilters.removeValue(forKey: field)
        filterParseError = nil
    }

    /// Clear all active metadata filters.
    func clearMetadataFilters() {
        metadataFilters.removeAll()
        filterParseError = nil
    }

    /// Commit a new metadata filter using the current input fields.
    func commitNewMetadataFilter() {
        let field = newFilterField.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawValue = newFilterValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !field.isEmpty else {
            filterParseError = "Filter field is required."
            return
        }

        guard !rawValue.isEmpty else {
            filterParseError = "Provide a value for the filter."
            return
        }

        guard let parsed = PineconeMetadataFilter.parse(from: rawValue) else {
            filterParseError = "Unable to interpret filter value."
            return
        }

        metadataFilters[field] = parsed
        newFilterField = ""
        newFilterValue = ""
        filterParseError = nil
    }

    /// Sorted representation of active metadata filters for presentation.
    var sortedMetadataFilters: [(String, PineconeMetadataFilter)] {
        metadataFilters.sorted { $0.key < $1.key }
    }

    /// Clear any parser error to reset validation state.
    func clearFilterError() {
        filterParseError = nil
    }

    /// Toggle selection of a search result
    func toggleResultSelection(_ result: SearchResultModel) {
        if selectedResultIDs.contains(result.id) {
            selectedResultIDs.remove(result.id)
        } else {
            selectedResultIDs.insert(result.id)
        }
    }

    /// Toggle expansion state for a search result row
    func toggleResultExpansion(for resultID: UUID) {
        if expandedResultIDs.contains(resultID) {
            expandedResultIDs.remove(resultID)
        } else {
            expandedResultIDs.insert(resultID)
        }
    }

    /// Ensure a specific source becomes visible/highlighted in the sources list
    func focusResult(for source: String) {
        guard let match = searchResults.first(where: { sourceMatches($0.sourceDocument, target: source) }) else {
            return
        }
        highlightedResultID = match.id
        expandedResultIDs.insert(match.id)
    }

    private func sourceMatches(_ candidate: String, target: String) -> Bool {
        if candidate.caseInsensitiveCompare(target) == .orderedSame { return true }
        let candidateFile = candidate.split(separator: "/").last.map(String.init) ?? candidate
        let targetFile = target.split(separator: "/").last.map(String.init) ?? target
        return candidateFile.caseInsensitiveCompare(targetFile) == .orderedSame
    }

    private func shouldUseCodeInterpreter(for query: String) -> Bool {
        guard settingsViewModel.codeInterpreterEnabled else { return false }
        let lowercased = query.lowercased()
        let keywords = [
            "chart", "plot", "graph", "visualize", "table", "csv", "excel", "spreadsheet",
            "stats", "statistics", "trend", "average", "mean", "median", "sum", "total",
            "percent", "percentage", "correlation", "regression", "histogram", "scatter",
            "bar", "line",
        ]
        let hasDigit = lowercased.rangeOfCharacter(from: .decimalDigits) != nil
        let hasKeyword = keywords.contains { lowercased.contains($0) }
        return hasDigit || hasKeyword
    }

    /// Perform a search with the current query
    func performSearch() async {
        let currentQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentQuery.isEmpty else { 
            handleError(SearchError.missingSelection("a query"))
            return
        }
        guard selectedIndex != nil else {
            handleError(SearchError.missingSelection("an index"))
            return
        }
        resetSearchState(isPreparingForSearch: true)
        // Append user message to chat history after resetting state
        self.messages.append(ChatMessage(role: .user, text: currentQuery))
        self.searchQuery = ""

        // Trace id for this search
        let traceId = UUID().uuidString
        self.logger.log(level: .info, message: "Search started", context: "traceId=\(traceId)")

        // Preflight Pinecone health
        let healthy = await pineconeService.healthCheck()
        if !healthy || pineconeService.isCircuitOpen { 
            self.isSearching = false
            self.errorMessage = "Pinecone temporarily unavailable; retrying soon."
            self.logger.log(level: .warning, message: "Pinecone preflight failed", context: "traceId=\(traceId)")
            return
        }

        // Record search start time
        let searchStartTime = Date()

        if shouldRouteSearch {
            await performRoutedSearch(query: currentQuery, traceId: traceId, searchStartTime: searchStartTime)
        } else {
            await searchOpenIndex(query: currentQuery, traceId: traceId, searchStartTime: searchStartTime)
        }
    }

    /// Search the open index and namespace, then stream the answer. Every search took this path
    /// before routing, and it is the fallback whenever routing can't run.
    private func searchOpenIndex(query currentQuery: String, traceId: String, searchStartTime: Date) async {
        do {
            // Generate embedding for query, passing the index's dimension
            let queryEmbedding = try await embeddingService.generateQueryEmbedding(for: currentQuery, dimension: indexDimension)

            // Search Pinecone - use hybrid search if enabled AND index supports it
            let filterPayload = buildMetadataFilterPayload()
            var queryResults: QueryResponse

            // Check if hybrid search is enabled and supported by this index
            let useHybridSearch = settingsViewModel.hybridSearchEnabled && indexSupportsHybridSearch

            if settingsViewModel.hybridSearchEnabled, !indexSupportsHybridSearch {
                // User wants hybrid but index doesn't support it
                logger.log(
                    level: .warning,
                    message: "Hybrid search requires dotproduct metric (index uses \(indexMetric ?? "unknown")), using dense-only",
                    context: "traceId=\(traceId)"
                )
            }

            if useHybridSearch { 
                // Generate sparse embedding for hybrid search
                logger.log(level: .info, message: "Generating sparse embedding for hybrid search", context: "traceId=\(traceId)")
                let sparseVector = try await pineconeService.generateSparseEmbedding(for: currentQuery)

                // Perform hybrid query with alpha weighting
                let alpha = Float(settingsViewModel.hybridSearchAlpha)
                logger.log(level: .info, message: "Performing hybrid search", context: "alpha=\(alpha); traceId=\(traceId)")

                queryResults = try await pineconeService.hybridQuery(
                    denseVector: queryEmbedding,
                    sparseVector: sparseVector,
                    topK: configuredTopK,
                    namespace: selectedNamespace,
                    filter: filterPayload,
                    alpha: alpha
                )
            } else {
                // Standard dense-only query
                queryResults = try await pineconeService.query(
                    vector: queryEmbedding,
                    topK: configuredTopK,
                    namespace: selectedNamespace,
                    filter: filterPayload
                )
            }

            // Map results to search result models (metadata may contain non-string values)
#if DEBUG
            // Log metadata keys only once per query to reduce verbosity
            if let metadata = queryResults.matches.first(where: { $0.metadata != nil })?.metadata {
                Logger.shared.log(level: .debug, message: "Pinecone metadata keys", context: metadata.keys.sorted().joined(separator: ", "))
            }
#endif
            let results = queryResults.matches.map { PassageText.searchResult(from: $0) }

            // Apply reranking if enabled
            let finalResults = await rerankIfEnabled(results, query: currentQuery, traceId: traceId)

            let avgScore = finalResults.isEmpty ? Float(0) : finalResults.map { $0.score }.reduce(0, +) / Float(finalResults.count)
            let filterDescription = metadataFilters.isEmpty ? "none" : metadataFilters.map { "\($0.key)=\($0.value.displayValue)" }.joined(separator: ", ")
            logger.log(
                level: .info,
                message: "Pinecone query returned \(finalResults.count) matches (avg score \(String(format: "%.3f", Double(avgScore))))",
                context: "filters: \(filterDescription)"
            )

            // Progress update for visuals
            await MainActor.run {
                self.searchResults = finalResults
                self.searchResultsOpacity = 1.0
                self.answerGenerationProgress = 0.6
                self.highlightedResultID = nil
                self.expandedResultIDs.removeAll()
            }

            // Prepare context and citations
            let useCodeInterpreter = shouldUseCodeInterpreter(for: currentQuery)
            let maxSources = useCodeInterpreter ? 3 : 5
            let maxContentChars = useCodeInterpreter ? 1200 : 4000
            let context = finalResults.prefix(maxSources).map { result in
                let trimmed = String(result.content.prefix(maxContentChars))
                return "Source: \(result.sourceDocument)\n\(trimmed)"
            }.joined(separator: "\n\n")
            let citations = finalResults.prefix(maxSources).map { $0.sourceDocument }

            if useCodeInterpreter {
                logger.log(level: .info, message: "Code interpreter context capped", context: "sources=\(maxSources); maxChars=\(maxContentChars)")
            } else if settingsViewModel.codeInterpreterEnabled {
                logger.log(level: .info, message: "Code interpreter skipped", context: "reason=heuristic; traceId=\(traceId)")
            }

            await streamAnswer(
                currentQuery: currentQuery,
                context: context,
                citations: citations,
                citationScopes: nil,
                resultCount: finalResults.count,
                useCodeInterpreter: useCodeInterpreter,
                systemPrompt: effectiveSystemPrompt,
                traceId: traceId,
                searchStartTime: searchStartTime
            )
        } catch {
            // Stop during a routed search's fallback cancels this too, which isn't a failure
            if Task.isCancelled { return }
            handleError(SearchError.queryFailed(error))
        }
    }

    /// Rerank with Pinecone when reranking is on; on failure the results keep their vector order
    private func rerankIfEnabled(_ results: [SearchResultModel], query: String, traceId: String) async -> [SearchResultModel] {
        guard settingsViewModel.rerankingEnabled, !results.isEmpty else { return results }

        do {
            let rerankModel = PineconeService.RerankModel(rawValue: settingsViewModel.rerankModel) ?? .bgeRerankerV2M3
            let topN = settingsViewModel.rerankTopN
            logger.log(level: .info, message: "Reranking \(results.count) results", context: "model=\(rerankModel.rawValue); topN=\(topN); traceId=\(traceId)")

            // Prepare documents for reranking - format as array of dictionaries with "text" key
            let documents = results.map { ["text": $0.content] }

            // Call rerank API
            let rerankResponse = try await pineconeService.rerank(
                query: query,
                documents: documents,
                model: rerankModel,
                topN: topN
            )

            // Reorder results based on rerank scores
            let reranked = rerankResponse.data.compactMap { rerankResult -> SearchResultModel? in
                guard rerankResult.index < results.count else { return nil }
                var result = results[rerankResult.index]
                // Update score to rerank score (convert from Double to Float)
                result.score = Float(rerankResult.score)
                return result
            }

            logger.log(level: .success, message: "Reranking complete", context: "reranked \(reranked.count) results; traceId=\(traceId)")
            return reranked
        } catch {
            // Log error but continue with original results
            logger.log(level: .warning, message: "Reranking failed, using original results", context: "\(error.localizedDescription); traceId=\(traceId)")
            return results
        }
    }

    // MARK: - Routed Search Across Indexes

    /// Routing needs the switch on, a router, and at least two places to search
    var shouldRouteSearch: Bool {
        guard settingsViewModel.indexRoutingEnabled, indexRouter != nil else { return false }
        return pineconeIndexes.count >= 2 || namespaces.count >= 2
    }

    /// Ask the model where to look, run those searches in parallel, then stream the answer from
    /// their passages. Falls back to searching the open index when routing can't run.
    private func performRoutedSearch(query: String, traceId: String, searchStartTime: Date) async {
        let task = Task { [weak self] in
            guard let self else { return }
            await self.routeAndAnswer(query: query, traceId: traceId, searchStartTime: searchStartTime)
        }
        routingTask = task
        await task.value
        // A search sent after Stop has its own task by now; leave that one alone
        if routingTask == task {
            routingTask = nil
        }
    }

    /// After Stop, `cancelActiveSearch` has already reset the screen and a new search may be
    /// running, so a cancelled routing task returns without touching any state
    private func routeAndAnswer(query: String, traceId: String, searchStartTime: Date) async {
        guard let router = indexRouter else {
            await searchOpenIndex(query: query, traceId: traceId, searchStartTime: searchStartTime)
            return
        }

        routingStatus = "Choosing where to look"
        let profiles = await profilesForRouting()
        if Task.isCancelled { return }

        guard profiles.contains(where: { $0.isRoutable }) else {
            routingStatus = nil
            logger.log(level: .warning, message: "Routing skipped: no index has a known embedding model yet", context: "traceId=\(traceId)")
            await searchOpenIndex(query: query, traceId: traceId, searchStartTime: searchStartTime)
            return
        }

        let decision: IndexRouter.Decision
        do {
            decision = try await router.route(
                question: query,
                history: historyBeforeCurrentQuestion(),
                profiles: profiles,
                hint: IndexRouter.Hint(index: selectedIndex, namespace: selectedNamespace),
                options: responsesModelOptions(temperature: 0)
            )
        } catch {
            if Task.isCancelled { return }
            routingStatus = nil
            logger.log(level: .warning, message: "Routing failed; searching the open index", context: "\(error.localizedDescription); traceId=\(traceId)")
            await searchOpenIndex(query: query, traceId: traceId, searchStartTime: searchStartTime)
            return
        }
        if Task.isCancelled { return }

        switch decision {
        case .answer:
            // Nothing to search. The reply still goes through the answer path, so it streams,
            // follows the person's system prompt, and joins the server conversation.
            routingStatus = nil
            logger.log(level: .info, message: "Routing chose no search", context: "traceId=\(traceId)")
            await streamAnswer(
                currentQuery: query,
                context: "No documents were searched for this message.",
                citations: [],
                citationScopes: nil,
                resultCount: 0,
                useCodeInterpreter: false,
                systemPrompt: effectiveSystemPrompt,
                traceId: traceId,
                searchStartTime: searchStartTime
            )

        case .search(let requests):
            routingStatus = "Searching " + requests.map(\.scopeLabel).joined(separator: ", ")
            logger.log(
                level: .info,
                message: "Routed \(requests.count) searches",
                context: requests.map { "\($0.scopeLabel): \($0.query)" }.joined(separator: " | ") + "; traceId=\(traceId)"
            )

            let profilesByName = Dictionary(uniqueKeysWithValues: profiles.map { ($0.name, $0) })
            let searches: [IndexRouter.RoutedSearch]
            do {
                searches = try await runRoutedSearches(requests, profiles: profilesByName, traceId: traceId)
            } catch {
                if Task.isCancelled { return }
                routingStatus = nil
                logger.log(level: .warning, message: "Routed searches failed; searching the open index", context: "\(error.localizedDescription); traceId=\(traceId)")
                await searchOpenIndex(query: query, traceId: traceId, searchStartTime: searchStartTime)
                return
            }
            if Task.isCancelled { return }

            // Every search failing is an outage, not an empty answer. The open-index search
            // reports its own error if it fails too.
            if searches.allSatisfy(\.failed) {
                routingStatus = nil
                logger.log(level: .warning, message: "Every routed search failed; searching the open index", context: "traceId=\(traceId)")
                await searchOpenIndex(query: query, traceId: traceId, searchStartTime: searchStartTime)
                return
            }

            let useCodeInterpreter = shouldUseCodeInterpreter(for: query)
            let routed = IndexRouter.context(
                for: searches,
                passagesPerSearch: useCodeInterpreter ? 3 : 5,
                maxCharacters: useCodeInterpreter ? 1200 : 2000
            )
            let failedCount = searches.filter(\.failed).count
            logger.log(
                level: failedCount > 0 ? .warning : .info,
                message: "Routed searches returned \(routed.passages.count) passages",
                context: "failed=\(failedCount) of \(searches.count); traceId=\(traceId)"
            )

            searchResults = routed.passages
            searchResultsOpacity = 1.0
            answerGenerationProgress = 0.6
            highlightedResultID = nil
            expandedResultIDs.removeAll()
            routingStatus = nil

            await streamAnswer(
                currentQuery: query,
                context: routed.text,
                citations: routed.citations,
                citationScopes: routed.citationScopes,
                resultCount: routed.passages.count,
                useCodeInterpreter: useCodeInterpreter,
                systemPrompt: "\(effectiveSystemPrompt)\n\n\(IndexRouter.answerInstructions)",
                traceId: traceId,
                searchStartTime: searchStartTime
            )
        }
    }

    /// Run the routed searches in parallel. Each question is embedded with the model that built
    /// the index it searches, once per model and dimension, so every index is searched in its own
    /// vector space and nothing is re-embedded.
    private func runRoutedSearches(
        _ requests: [IndexRouter.SearchRequest],
        profiles: [String: IndexProfile],
        traceId: String
    ) async throws -> [IndexRouter.RoutedSearch] {
        func vectorKey(_ model: String, _ dimension: Int, _ text: String) -> String {
            "\(model)|\(dimension)|\(text)"
        }

        var groups: [String: (model: String, dimension: Int, queries: [String])] = [:]
        for request in requests {
            guard let profile = profiles[request.index], let model = profile.embeddingModel else { continue }
            let groupKey = "\(model)|\(profile.dimension)"
            var group = groups[groupKey] ?? (model: model, dimension: profile.dimension, queries: [])
            if !group.queries.contains(request.query) {
                group.queries.append(request.query)
            }
            groups[groupKey] = group
        }

        var vectors: [String: [Float]] = [:]
        for group in groups.values {
            let embedded = try await embeddingService.generateQueryEmbeddings(
                for: group.queries,
                dimension: group.dimension,
                model: group.model
            )
            for (text, vector) in zip(group.queries, embedded) {
                vectors[vectorKey(group.model, group.dimension, text)] = vector
            }
        }

        let filterPayload = buildMetadataFilterPayload()
        let openIndex = selectedIndex

        // Each search starts at once on the main actor, like the rest of this view model; the
        // network waits overlap, and the results come back in the order the model asked for them
        let searches: [Task<IndexRouter.RoutedSearch, Never>] = requests.map { request in
            Task {
                guard let profile = profiles[request.index],
                      let model = profile.embeddingModel,
                      let vector = vectors[vectorKey(model, profile.dimension, request.query)]
                else {
                    return IndexRouter.RoutedSearch(request: request, results: [], failed: true)
                }
                // Metadata filters name fields of the open index, so only its searches use them
                let filter = request.index == openIndex ? filterPayload : nil
                return await self.runRoutedSearch(request, profile: profile, vector: vector, filter: filter, traceId: traceId)
            }
        }

        return await withTaskCancellationHandler {
            var completed: [IndexRouter.RoutedSearch] = []
            for search in searches {
                completed.append(await search.value)
            }
            return completed
        } onCancel: {
            searches.forEach { $0.cancel() }
        }
    }

    /// One routed search: query the index with its own vector, label the passages with where they
    /// were found, and rerank them when reranking is on. A search that errors is marked failed.
    private func runRoutedSearch(
        _ request: IndexRouter.SearchRequest,
        profile: IndexProfile,
        vector: [Float],
        filter: [String: Any]?,
        traceId: String
    ) async -> IndexRouter.RoutedSearch {
        do {
            var hybrid: (sparse: PineconeService.SparseVector, alpha: Float)?
            if settingsViewModel.hybridSearchEnabled, profile.metric.lowercased() == "dotproduct" {
                let sparse = try await pineconeService.generateSparseEmbedding(for: request.query)
                hybrid = (sparse: sparse, alpha: Float(settingsViewModel.hybridSearchAlpha))
            }

            // The default namespace is sent by leaving the field out, which every API version accepts
            let response = try await pineconeService.query(
                index: request.index,
                vector: vector,
                hybrid: hybrid,
                topK: configuredTopK,
                namespace: request.namespace.isEmpty ? nil : request.namespace,
                filter: filter
            )

            let results = response.matches.map {
                PassageText.searchResult(from: $0, index: request.index, namespace: request.namespace)
            }
            let ranked = await rerankIfEnabled(results, query: request.query, traceId: traceId)
            return IndexRouter.RoutedSearch(request: request, results: ranked)
        } catch {
            logger.log(level: .warning, message: "Routed search failed", context: "\(request.scopeLabel); \(error.localizedDescription); traceId=\(traceId)")
            return IndexRouter.RoutedSearch(request: request, results: [], failed: true)
        }
    }

    /// Earlier turns for the router, without the question just asked
    private func historyBeforeCurrentQuestion() -> [ChatMessage] {
        var earlier = messages
        if let last = earlier.last, last.role == .user {
            earlier.removeLast()
        }
        return earlier.filter { $0.status == .normal && !$0.text.isEmpty }
    }

    /// The person's completion model settings, read the way OpenAIService reads them, with the
    /// effort moved to one the model accepts
    private func responsesModelOptions(temperature: Double) -> ResponsesClient.ModelOptions {
        let model = defaults.string(forKey: "completionModel") ?? Configuration.completionModel
        let effort = defaults.string(forKey: "openai.reasoningEffort") ?? "none"
        return ResponsesClient.ModelOptions(
            model: model,
            reasoningEffort: CurrentModelCatalog.normalizedEffort(effort, model: model),
            temperature: temperature
        )
    }

    /// Drafting an index's summary is background work, so it uses the catalog's small utility model, as
    /// OpenResponses does for its background probes
    private var summaryModelOptions: ResponsesClient.ModelOptions {
        let model = CurrentModelCatalog.utilityModel
        return ResponsesClient.ModelOptions(
            model: model,
            reasoningEffort: CurrentModelCatalog.normalizedEffort("low", model: model),
            temperature: 0.2
        )
    }

    // MARK: - Index Profiles

    /// Profiles of the listed indexes. Stored ones are used as they are, even when due for a
    /// refresh. Only indexes with no profile are surveyed before the question, without a summary
    /// draft; the background survey drafts one afterwards.
    private func profilesForRouting() async -> [IndexProfile] {
        let missing = pineconeIndexes.filter { indexProfiles[$0] == nil }
        if !missing.isEmpty {
            await surveyIndexes(missing, recheckModels: false, draftSummaries: false)
            scheduleIndexSurvey()
        }
        return pineconeIndexes.compactMap { indexProfiles[$0] }
    }

    /// Survey, in the background, indexes that have no profile or are due for another look
    func scheduleIndexSurvey(recheckModels: Bool = false) {
        guard indexSurveyor != nil, settingsViewModel.indexRoutingEnabled, indexSurveyTask == nil else { return }
        guard !pineconeIndexes.isEmpty, recheckModels || shouldRouteSearch else { return }

        // Forget indexes that no longer exist
        let listed = Set(pineconeIndexes)
        if indexProfiles.keys.contains(where: { !listed.contains($0) }) {
            indexProfiles = indexProfiles.filter { listed.contains($0.key) }
            indexCatalogStore?.save(indexProfiles)
        }

        let due = pineconeIndexes.filter { name in
            guard let profile = indexProfiles[name] else { return true }
            return isDueForSurvey(profile, recheckModels: recheckModels)
        }
        guard !due.isEmpty else { return }

        indexSurveyTask = Task { [weak self] in
            await self?.surveyIndexes(due, recheckModels: recheckModels, draftSummaries: true)
            self?.indexSurveyTask = nil
        }
    }

    /// A searchable profile is looked at again after an hour, which costs two Pinecone calls while
    /// its model match and summary hold. An empty or unmatched index is looked at after ten
    /// minutes, since it may have been filled since. A searchable index without a summary gets a
    /// draft, tried at most every ten minutes.
    private func isDueForSurvey(_ profile: IndexProfile, recheckModels: Bool) -> Bool {
        if recheckModels { return true }
        let age = Date().timeIntervalSince(profile.surveyedAt)
        guard profile.isRoutable else { return age > unroutableProfileMaxAge }
        if age > routableProfileMaxAge { return true }
        let needsSummary = profile.summarySource == .missing && profile.summary.isEmpty
        let lastAttempt = summaryDraftAttempts[profile.name] ?? .distantPast
        return needsSummary && Date().timeIntervalSince(lastAttempt) > unroutableProfileMaxAge
    }

    private func surveyIndexes(_ names: [String], recheckModels: Bool, draftSummaries: Bool) async {
        guard let surveyor = indexSurveyor else { return }
        activeSurveys += 1
        isSurveyingIndexes = true
        defer {
            activeSurveys -= 1
            isSurveyingIndexes = activeSurveys > 0
        }

        for name in names {
            if draftSummaries {
                summaryDraftAttempts[name] = Date()
            }
            do {
                var profile = try await surveyor.survey(
                    index: name,
                    previous: indexProfiles[name],
                    preferredModel: settingsViewModel.embeddingModel,
                    summaryOptions: draftSummaries ? summaryModelOptions : nil,
                    recheckModel: recheckModels
                )
                // A summary the person saved while this survey ran wins over what it started from
                if let current = indexProfiles[name], current.summarySource == .person {
                    profile.summary = current.summary
                    profile.summarySource = .person
                }
                indexProfiles[name] = profile
                indexCatalogStore?.save(indexProfiles)
                logger.log(
                    level: .info,
                    message: "Index surveyed",
                    context: "index=\(name); model=\(profile.embeddingModel ?? "none"); check=\(profile.modelCheck.rawValue); namespaces=\(profile.namespaces.count)"
                )
            } catch {
                // The stored profile stays as it was; a failure is not a finding about the index
                logger.log(level: .warning, message: "Index survey failed", context: "index=\(name); \(error.localizedDescription)")
            }
        }
    }

    /// Documents uploaded to an index: look at it again before routing to it
    private func indexContentDidChange(_ index: String?) {
        if let index, var profile = indexProfiles[index] {
            profile.surveyedAt = .distantPast
            indexProfiles[index] = profile
        }
        scheduleIndexSurvey()
    }

    /// Save a person-written summary; clearing it lets the app draft one again
    func updateIndexSummary(_ text: String, for index: String) {
        guard var profile = indexProfiles[index] else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != profile.summary else { return }
        profile.summary = trimmed
        profile.summarySource = trimmed.isEmpty ? .missing : .person
        indexProfiles[index] = profile
        indexCatalogStore?.save(indexProfiles)
    }

    /// Draft an index's summary again from a fresh sample of its passages
    func redraftIndexSummary(for index: String) async {
        guard let surveyor = indexSurveyor, let profile = indexProfiles[index] else { return }
        summaryDraftAttempts[index] = Date()
        do {
            let drafted = try await surveyor.redraftSummary(of: profile, options: summaryModelOptions)
            // Only the summary changes; whatever a survey updated meanwhile stays
            guard var current = indexProfiles[index] else { return }
            current.summary = drafted.summary
            current.summarySource = drafted.summarySource
            indexProfiles[index] = current
            indexCatalogStore?.save(indexProfiles)
        } catch {
            logger.log(level: .warning, message: "Index summary redraft failed", context: "index=\(index); \(error.localizedDescription)")
        }
    }

    /// Survey every index again, including which model built it
    func recheckIndexProfiles() {
        scheduleIndexSurvey(recheckModels: true)
    }

    /// Stream the answer for a prepared context, with the watchdog and the fallbacks every search uses
    private func streamAnswer(
        currentQuery: String,
        context: String,
        citations: [String],
        citationScopes: [String]?,
        resultCount: Int,
        useCodeInterpreter: Bool,
        systemPrompt: String,
        traceId: String,
        searchStartTime: Date
    ) async {
        // Prepare streaming assistant message
        let assistantMessageId = UUID()
        await MainActor.run {
            self.generatedAnswer = ""
            self.messages.append(ChatMessage(id: assistantMessageId, role: .assistant, text: "", citations: nil, status: .streaming))
        }

        let useServer = (UserDefaults.standard.string(forKey: "openai.conversationMode") ?? "server") == "server"
        let historyArg: [ChatMessage] = useServer ? [] : await MainActor.run { self.conversationHistoryExcludingCurrentUser() }
        let convIdArg: String? = (useServer && (self.conversationId?.hasPrefix("conv") ?? false)) ? self.conversationId : nil

        // Watchdog: if no deltas within 7s, cancel stream and fallback to non-stream completion
        let watchdogTask = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: Constants.watchdogDelayNanoseconds)
            // Check if assistant message is still streaming and empty
            let shouldFallback = await MainActor.run { () -> Bool in
                if let idx = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    return self.messages[idx].status == .streaming && self.messages[idx].text.isEmpty
                }
                return false
            }
            if shouldFallback {
                await MainActor.run {
                    self.logger.log(level: .warning, message: "Watchdog fallback triggered", context: "traceId=\(traceId)")
                }
                // Cancel stream task
                self.currentStreamTask?.cancel()
                self.currentStreamTask = nil
                // Run fallback in a separate unlinked task so cancellation doesn't propagate
                Task.detached { [weak self] in
                    guard let self = self else { return }
                    let query = currentQuery
                    let fallbackHistory: [ChatMessage] = useServer ? [] : await MainActor.run { self.conversationHistoryExcludingCurrentUser() }
                    let fallbackConversationId: String? = useServer ? nil : convIdArg
                    do {
                        let fallback = try await self.openAIService.generateCompletion(
                            systemPrompt: systemPrompt,
                            userMessage: query,
                            context: context,
                            history: fallbackHistory,
                            conversationId: fallbackConversationId,
                            onConversationId: { conv in
                                UserDefaults.standard.set(conv, forKey: "openai.conversationId")
                                Task { @MainActor in
                                    self.conversationId = conv
                                    self.logger.log(level: .info, message: "OpenAI conversation established (watchdog)", context: "id=\(conv)")
                                }
                            },
                            allowCodeInterpreter: false
                        )
                        await MainActor.run {
                            if let idx = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                                var msg = self.messages[idx]
                                msg.text = fallback
                                msg.status = .normal
                                msg.citations = citations
                                msg.citationScopes = citationScopes
                                self.messages[idx] = msg
                            }
                            self.generatedAnswer = fallback
                            self.isSearching = false
                            self.answerGenerationProgress = 1.0
                            self.lastSearchTime = searchStartTime
                        }
                    } catch {
                        await MainActor.run {
                            if let idx = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                                var msg = self.messages[idx]
                                if msg.status == .streaming {
                                    msg.status = .error
                                }
                                msg.error = "No streamed response; watchdog fallback failed: \(error.localizedDescription)"
                                self.messages[idx] = msg
                            }
                            self.isSearching = false
                        }
                    }
                }
            }
        }

        self.currentStreamTask = Task {
            do {
                var deltaCount = 0
                // Clear previous code interpreter outputs
                await MainActor.run { self.codeInterpreterOutputs = [] }

                try await openAIService.streamCompletion(
                    systemPrompt: systemPrompt,
                    userMessage: currentQuery,
                    context: context,
                    history: historyArg,
                    conversationId: convIdArg,
                    onConversationId: { conv in
                        UserDefaults.standard.set(conv, forKey: "openai.conversationId")
                        Task { @MainActor in
                            self.conversationId = conv
                            self.logger.log(level: .info, message: "OpenAI conversation established", context: "id=\(conv)")
                        }
                    },
                    onTextDelta: { delta in
                        deltaCount += 1
                        Task { @MainActor in
                            self.generatedAnswer += delta
                            if let index = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                                var msg = self.messages[index]
                                msg.text += delta
                                self.messages[index] = msg
                            }
                        }
                    },
                    allowCodeInterpreter: useCodeInterpreter,
                    onCodeInterpreterOutput: { output in
                            Task { @MainActor in
                                let maxOutputs = 8
                                let maxImageChars = 1_000_000

                                if output.type == .image, output.content.count > maxImageChars {
                                    self.logger.log(level: .warning, message: "Code interpreter image dropped (too large)", context: "size=\(output.content.count)")
                                    return
                                }

                                if self.codeInterpreterOutputs.count >= maxOutputs {
                                    self.codeInterpreterOutputs.removeFirst(self.codeInterpreterOutputs.count - (maxOutputs - 1))
                                }

                                self.codeInterpreterOutputs.append(output)
                                self.logger.log(level: .info, message: "Code interpreter output received", context: "type=\(output.type.rawValue); total=\(self.codeInterpreterOutputs.count)")
                            }
                        },
                    onCompleted: {
                        // Finalize even if no deltas arrived; if empty, fallback to non-stream completion once
                        Task {
                            self.logger.log(level: .success, message: "OpenAI stream completed", context: "deltaCount=\(deltaCount); traceId=\(traceId)")
                            if let index = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                                if self.messages[index].text.isEmpty {
                                    do {
                                        let fallbackHistory: [ChatMessage] = useServer ? [] : await MainActor.run { self.conversationHistoryExcludingCurrentUser() }
                                        let fallbackConversationId: String? = useServer ? nil : convIdArg
                                        let fallbackQuery = currentQuery
                                        let fallback = try await self.openAIService.generateCompletion(
                                            systemPrompt: systemPrompt,
                                            userMessage: fallbackQuery,
                                            context: context,
                                            history: fallbackHistory,
                                            conversationId: fallbackConversationId,
                                            onConversationId: { conv in
                                                UserDefaults.standard.set(conv, forKey: "openai.conversationId")
                                                Task { @MainActor in
                                                    self.conversationId = conv
                                                    self.logger.log(level: .info, message: "OpenAI conversation established (fallback)", context: "id=\(conv)")
                                                }
                                            },
                                            allowCodeInterpreter: false
                                        )
                                        await MainActor.run {
                                            if self.messages.indices.contains(index) {
                                                var msg = self.messages[index]
                                                msg.text = fallback
                                                msg.status = .normal
                                                msg.citations = citations
                                                msg.citationScopes = citationScopes
                                                self.messages[index] = msg
                                            }
                                            self.generatedAnswer = fallback
                                        }
                                    } catch {
                                        await MainActor.run {
                                            if self.messages.indices.contains(index) {
                                                var msg = self.messages[index]
                                                if msg.status == .streaming {
                                                    msg.status = .error
                                                }
                                                msg.error = "No streamed response; fallback failed."
                                                self.messages[index] = msg
                                            }
                                        }
                                    }
                                } else {
                                    await MainActor.run {
                                        var msg = self.messages[index]
                                        msg.citations = citations
                                        msg.citationScopes = citationScopes
                                        if msg.status == .streaming {
                                            msg.status = .normal
                                        }
                                        self.messages[index] = msg
                                    }
                                }
                            }
                            await MainActor.run {
                                watchdogTask.cancel() // Clean up watchdog since stream completed successfully
                                self.isSearching = false
                                self.answerGenerationProgress = 1.0
                                self.lastSearchTime = searchStartTime
                                self.currentStreamTask = nil
                                self.logger.log(
                                    level: .success,
                                    message: "Search completed",
                                    context: "traceId=\(traceId); Found \(resultCount) results"
                                )
                            }
                        }
                    }
                )
            } catch is CancellationError {
                watchdogTask.cancel() // Clean up watchdog on cancellation
                self.logger.log(level: .info, message: "Responses streaming cancelled", context: "traceId=\(traceId)")
                // Suppress UI error; watchdog or user cancel will handle state and message finalization
            } catch {
                watchdogTask.cancel() // Clean up watchdog on error
                self.handleError(SearchError.answerGenerationFailed(error))
            }
        }
    }

    /// Generate an answer based on selected results
    func generateAnswerFromSelected() async {
        guard !selectedResults.isEmpty else {
            handleError(SearchError.missingSelection("at least one source document"))
            return
        }
        let currentQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentQuery.isEmpty else { 
            handleError(SearchError.missingSelection("a query"))
            return
        }

        self.isSearching = true
        self.generatedAnswer = ""
        self.errorMessage = nil
        self.searchQuery = ""

        let traceId = UUID().uuidString
        self.logger.log(level: .info, message: "Generate from selected started", context: "traceId=\(traceId)")

        // Build context and citations
        let useCodeInterpreter = shouldUseCodeInterpreter(for: currentQuery)
        let maxSources = useCodeInterpreter ? 3 : selectedResults.count
        let maxContentChars = useCodeInterpreter ? 1200 : 4000
        let cappedResults = Array(self.selectedResults.prefix(maxSources))
        let context = cappedResults.map { result in
            let trimmed = String(result.content.prefix(maxContentChars))
            return "Source: \(result.sourceDocument)\n\(trimmed)"
        }.joined(separator: "\n\n")
        let citations = cappedResults.map { $0.sourceDocument }

        if useCodeInterpreter {
            logger.log(level: .info, message: "Code interpreter context capped", context: "sources=\(maxSources); maxChars=\(maxContentChars)")
        } else if settingsViewModel.codeInterpreterEnabled {
            logger.log(level: .info, message: "Code interpreter skipped", context: "reason=heuristic; traceId=\(traceId)")
        }

        let assistantMessageId = UUID()
        self.generatedAnswer = ""
        self.messages.append(ChatMessage(id: assistantMessageId, role: .assistant, text: "", citations: nil, status: .streaming))

        let useServer = (UserDefaults.standard.string(forKey: "openai.conversationMode") ?? "server") == "server"
        let historyArg: [ChatMessage] = useServer ? [] : self.conversationHistoryExcludingCurrentUser()
        let convIdArg: String? = (useServer && (self.conversationId?.hasPrefix("conv") ?? false)) ? self.conversationId : nil

        // Watchdog: if no deltas within 7s, cancel stream and fallback to non-stream completion
        let watchdogTask = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: Constants.watchdogDelayNanoseconds)
            let shouldFallback = await MainActor.run { () -> Bool in
                if let idx = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    return self.messages[idx].status == .streaming && self.messages[idx].text.isEmpty
                }
                return false
            }
            if shouldFallback {
                await MainActor.run {
                    self.logger.log(level: .warning, message: "Watchdog fallback triggered", context: "traceId=\(traceId)")
                }
                self.currentStreamTask?.cancel()
                self.currentStreamTask = nil
                Task.detached { [weak self] in
                    guard let self = self else { return }
                    let query = currentQuery
                    let fallbackHistory: [ChatMessage] = useServer ? [] : await MainActor.run { self.conversationHistoryExcludingCurrentUser() }
                    let fallbackConversationId: String? = useServer ? nil : convIdArg
                    do {
                        let fallback = try await self.openAIService.generateCompletion(
                            systemPrompt: self.effectiveSystemPrompt,
                            userMessage: query,
                            context: context,
                            history: fallbackHistory,
                            conversationId: fallbackConversationId,
                            onConversationId: { conv in
                                UserDefaults.standard.set(conv, forKey: "openai.conversationId")
                                Task { @MainActor in
                                    self.conversationId = conv
                                    self.logger.log(level: .info, message: "OpenAI conversation established (watchdog)", context: "id=\(conv)")
                                }
                            },
                            allowCodeInterpreter: false
                        )
                        await MainActor.run {
                            if let idx = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                                var msg = self.messages[idx]
                                msg.text = fallback
                                msg.status = .normal
                                msg.citations = citations
                                self.messages[idx] = msg
                            }
                            self.generatedAnswer = fallback
                            self.isSearching = false
                            self.currentStreamTask = nil
                        }
                    } catch {
                        await MainActor.run {
                            if let idx = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                                var msg = self.messages[idx]
                                if msg.status == .streaming {
                                    msg.status = .error
                                }
                                msg.error = "No streamed response; watchdog fallback failed: \(error.localizedDescription)"
                                self.messages[idx] = msg
                            }
                            self.isSearching = false
                            self.currentStreamTask = nil
                        }
                    }
                }
            }
        }

        self.currentStreamTask = Task {
            do {
                var deltaCount = 0
                // Clear previous code interpreter outputs for regeneration
                await MainActor.run { self.codeInterpreterOutputs = [] }

                try await openAIService.streamCompletion(
                    systemPrompt: self.effectiveSystemPrompt,
                    userMessage: currentQuery,
                    context: context,
                    history: historyArg,
                    conversationId: convIdArg,
                    onConversationId: { conv in
                        UserDefaults.standard.set(conv, forKey: "openai.conversationId")
                        Task { @MainActor in
                            self.conversationId = conv
                            self.logger.log(level: .info, message: "OpenAI conversation established", context: "id=\(conv)")
                        }
                    },
                    onTextDelta: { delta in
                        deltaCount += 1
                        Task { @MainActor in
                            self.generatedAnswer += delta
                            if let index = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                                var msg = self.messages[index]
                                if msg.status == .streaming {
                                    msg.status = .normal
                                }
                                msg.text += delta
                                self.messages[index] = msg
                            }
                        }
                    },
                    allowCodeInterpreter: useCodeInterpreter,
                    onCodeInterpreterOutput: { output in
                            Task { @MainActor in
                                let maxOutputs = 8
                                let maxImageChars = 1_000_000

                                if output.type == .image, output.content.count > maxImageChars {
                                    self.logger.log(level: .warning, message: "Code interpreter image dropped (too large)", context: "size=\(output.content.count)")
                                    return
                                }

                                if self.codeInterpreterOutputs.count >= maxOutputs {
                                    self.codeInterpreterOutputs.removeFirst(self.codeInterpreterOutputs.count - (maxOutputs - 1))
                                }

                                self.codeInterpreterOutputs.append(output)
                                self.logger.log(level: .info, message: "Code interpreter output received", context: "type=\(output.type.rawValue); total=\(self.codeInterpreterOutputs.count)")
                            }
                        },
                    onCompleted: {
                        // Finalize even if no deltas arrived; if empty, fallback to non-stream completion once
                        Task {
                            self.logger.log(level: .success, message: "OpenAI stream completed", context: "deltaCount=\(deltaCount); traceId=\(traceId)")
                            if let index = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                                if self.messages[index].text.isEmpty {
                                    do {
                                        let fallbackHistory: [ChatMessage] = useServer ? [] : await MainActor.run { self.conversationHistoryExcludingCurrentUser() }
                                        let fallbackConversationId: String? = useServer ? nil : convIdArg
                                        let fallbackQuery = currentQuery
                                        let fallback = try await self.openAIService.generateCompletion(
                                            systemPrompt: self.effectiveSystemPrompt,
                                            userMessage: fallbackQuery,
                                            context: context,
                                            history: fallbackHistory,
                                            conversationId: fallbackConversationId,
                                            onConversationId: { conv in
                                                UserDefaults.standard.set(conv, forKey: "openai.conversationId")
                                                Task { @MainActor in
                                                    self.conversationId = conv
                                                    self.logger.log(level: .info, message: "OpenAI conversation established (fallback)", context: "id=\(conv)")
                                                }
                                            },
                                            allowCodeInterpreter: false
                                        )
                                            await MainActor.run {
                                                if self.messages.indices.contains(index) {
                                                    var msg = self.messages[index]
                                                    msg.text = fallback
                                                    msg.status = .normal
                                                    msg.citations = citations
                                                    self.messages[index] = msg
                                                }
                                                self.generatedAnswer = fallback
                                            }
                                    } catch {
                                        await MainActor.run {
                                            if self.messages.indices.contains(index) {
                                                var msg = self.messages[index]
                                                if msg.status == .streaming {
                                                    msg.status = .error
                                                }
                                                msg.error = "No streamed response; fallback failed."
                                                self.messages[index] = msg
                                            }
                                        }
                                    }
                                } else {
                                    await MainActor.run {
                                        var msg = self.messages[index]
                                        msg.citations = citations
                                        if msg.status == .streaming {
                                            msg.status = .normal
                                        }
                                        self.messages[index] = msg
                                    }
                                }
                            }
                            await MainActor.run {
                                watchdogTask.cancel() // Clean up watchdog since stream completed successfully
                                self.isSearching = false
                                self.currentStreamTask = nil
                                self.logger.log(
                                    level: .success,
                                    message: "Answer generated from selected results",
                                    context: "traceId=\(traceId); Using \(self.selectedResults.count) results"
                                )
                            }
                        }
                    }
                )
            } catch is CancellationError {
                watchdogTask.cancel() // Clean up watchdog on cancellation
                self.logger.log(level: .info, message: "Responses streaming cancelled", context: "traceId=\(traceId)")
                // Suppress UI error; watchdog or user cancel will handle state and message finalization
            } catch {
                watchdogTask.cancel() // Clean up watchdog on error
                self.handleError(SearchError.answerGenerationFailed(error))
            }
        }
    }

    // MARK: - Conversation Threads

    func newTopic() {
        // Clear server-managed conversation until a valid conv id is created/upstreamed
        UserDefaults.standard.removeObject(forKey: "openai.conversationId")
        Task { @MainActor in
            self.conversationId = nil
            self.messages.removeAll()
            self.generatedAnswer = ""
            self.errorMessage = nil
        }
    }

    // MARK: - Export Conversation

    /// Export the current conversation as Markdown
    func exportConversationAsMarkdown() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        var markdown = "# OpenCone Conversation\n\n"
        markdown += "**Exported:** \(dateFormatter.string(from: Date()))\n"

        if let index = selectedIndex {
            markdown += "**Index:** \(index)\n"
        }
        if let namespace = selectedNamespace, !namespace.isEmpty {
            markdown += "**Namespace:** \(namespace)\n"
        }
        markdown += "\n---\n\n"

        for message in messages {
            let timestamp = dateFormatter.string(from: message.createdAt)
            let role = message.role == .user ? "👤 You" : "🤖 Assistant"

            markdown += "### \(role)\n"
            markdown += "*\(timestamp)*\n\n"
            markdown += "\(message.text)\n"

            if let citations = message.citations, !citations.isEmpty {
                markdown += "\n**Sources:**\n"
                for citation in citations {
                    markdown += "- \(citation)\n"
                }
            }

            markdown += "\n---\n\n"
        }

        return markdown
    }

    /// Export conversation as JSON for backup/import
    func exportConversationAsJSON() -> Data? {
        struct ExportedMessage: Codable {
            let role: String
            let text: String
            let citations: [String]?
            let timestamp: Date
        }

        struct ExportedConversation: Codable {
            let exportDate: Date
            let index: String?
            let namespace: String?
            let messages: [ExportedMessage]
        }

        let exportedMessages = messages.map { msg in
            ExportedMessage(
                role: msg.role == .user ? "user" : "assistant",
                text: msg.text,
                citations: msg.citations,
                timestamp: msg.createdAt
            )
        }

        let export = ExportedConversation(
            exportDate: Date(),
            index: selectedIndex,
            namespace: selectedNamespace,
            messages: exportedMessages
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try? encoder.encode(export)
    }

    // MARK: - Cancellation

    func cancelActiveSearch() {
        currentStreamTask?.cancel()
        currentStreamTask = nil
        routingTask?.cancel()
        routingTask = nil
        routingStatus = nil
        Task { @MainActor in
            self.isSearching = false
            if let lastIdx = self.messages.lastIndex(where: { $0.role == .assistant }) {
                if self.messages[lastIdx].text.isEmpty {
                    var msg = self.messages[lastIdx]
                    msg.status = .error
                    msg.error = "Generation canceled"
                    self.messages[lastIdx] = msg
                }
            }
        }
    }

    // MARK: - Private Helpers

    /// Build conversation history to send to the model, excluding the current user turn.
    /// Includes only finalized (.normal) messages with non-empty text.
    private func conversationHistoryExcludingCurrentUser() -> [ChatMessage] {
        var hist = self.messages.filter { $0.status == .normal && !$0.text.isEmpty }
        if let last = hist.last, last.role == .user, last.text == self.searchQuery {
            hist.removeLast()
        }
        return hist
    }

    private func buildMetadataFilterPayload() -> [String: Any]? {
        guard let serialized = serializeMetadataFilters() else { return nil }
        if serialized.count == 1, let entry = serialized.first {
            return [entry.key: entry.value]
        }
        let clauses = serialized.map { [ $0.key: $0.value ] }
        return ["$and": clauses]
    }

    private func serializeMetadataFilters() -> [String: [String: Any]]? {
        guard !metadataFilters.isEmpty else { return nil }
        var serialized: [String: [String: Any]] = [:]
        for (field, filter) in metadataFilters {
            let predicate = filter.serializedPredicate()
            guard !predicate.isEmpty else { continue }
            serialized[field] = predicate
        }
        return serialized.isEmpty ? nil : serialized
    }

    /// Resets the search-related state variables, typically before a new search.
    @MainActor
    private func resetSearchState(isPreparingForSearch: Bool = false) {
        self.isSearching = isPreparingForSearch
        self.searchResults = []
        self.generatedAnswer = ""
        self.selectedResultIDs.removeAll()
        self.errorMessage = nil
        self.highlightedResultID = nil
        self.expandedResultIDs.removeAll()
    }

    /// Handles errors by logging them and updating the UI.
    /// - Parameter error: The SearchError that occurred.
    @MainActor
    private func handleError(_ error: SearchError) {
        self.errorMessage = "\(error.localizedDescription) \(error.recoverySuggestion ?? "")"
        self.isSearching = false

        // Mark streaming assistant message as error if present
        if let lastIdx = self.messages.lastIndex(where: { $0.role == .assistant }) {
            if self.messages[lastIdx].status == .streaming && self.messages[lastIdx].text.isEmpty {
                var msg = self.messages[lastIdx]
                msg.status = .error
                msg.error = error.localizedDescription
                self.messages[lastIdx] = msg
            }
        }

        self.logger.log(
            level: ProcessingLogEntry.LogLevel.error,
            message: error.localizedDescription,
            context: error.underlyingError?.localizedDescription ?? "No underlying error details."
        )

        // Auto-dismiss error banner after a short delay if it hasn't changed
        let currentBanner = self.errorMessage
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000) // 8s
            await MainActor.run {
                if self?.errorMessage == currentBanner {
                    self?.errorMessage = nil
                }
            }
        }
    }
}
