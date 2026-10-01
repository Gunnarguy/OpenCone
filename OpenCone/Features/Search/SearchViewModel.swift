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

    /// A failure of one question's search or answer, shown as that question's answer
    var belongsToAnswer: Bool {
        switch self {
        case .embeddingFailed, .queryFailed, .answerGenerationFailed:
            return true
        case .indexLoadingFailed, .indexSetFailed, .namespaceLoadingFailed, .missingSelection:
            return false
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

        /// Namespaces searched one by one when every namespace of an index is searched. Pinecone
        /// queries one namespace per request, so each costs a read.
        static let namespaceFanOutLimit = 10

        /// Searches an Everything question may run, one per namespace, taken in turns across indexes
        static let broadSearchLimit = 20
        /// Passages handed to the reranker from an Everything search, within its per-request limit
        static let broadRerankCandidates = 40
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
    /// The passages behind the latest answer; each answer keeps its own in `ChatMessage.sources`
    @Published var searchResults: [SearchResultModel] = []
    @Published var generatedAnswer: String = ""
    @Published var errorMessage: String? = nil  // Holds user-facing error message
    @Published var pineconeIndexes: [String] = []
    /// The first full index list has come back, or failed; until then an empty list means "loading"
    @Published var hasLoadedIndexes = false
    /// Namespaces of the open index, the default namespace ("") first
    @Published var namespaces: [String] = []
    /// Passages in each namespace of the open index
    @Published var namespaceVectorCounts: [String: Int] = [:]
    @Published var selectedIndex: String? = nil
    /// The namespace searched in the open index; nil searches every namespace
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
    @Published var metadataFilters: [String: PineconeMetadataFilter] = [:]
    @Published var newFilterField: String = ""
    @Published var newFilterValue: String = ""
    @Published var filterParseError: String? = nil

    // Code interpreter outputs from current search
    @Published var codeInterpreterOutputs: [CodeInterpreterOutput] = []

    // Routing across indexes
    @Published var indexProfiles: [String: IndexProfile] = [:]
    /// Indexes the person left out of searches across indexes
    @Published private(set) var excludedIndexes: Set<String> = []
    /// What a search is doing before the answer starts, such as which indexes it searches
    @Published var routingStatus: String? = nil
    @Published var isSurveyingIndexes = false

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
        self.excludedIndexes = indexCatalogStore?.loadExcluded() ?? []

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
        defer { hasLoadedIndexes = true }
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
            self.namespaceVectorCounts = [:]
            self.selectedNamespace = nil
            return
        }

        do {
            let counts = try await pineconeService.namespaceVectorCounts()
            let namespaces = Self.orderedNamespaces(counts.keys)
            self.namespaceVectorCounts = counts
            self.namespaces = namespaces

            // "All namespaces" is Search's own choice; the namespace preference is shared with
            // Documents, which always needs one namespace to upload to
            let resolvedNamespace: String?
            if let index = selectedIndex, searchesAllNamespaces(of: index) {
                resolvedNamespace = nil
            } else {
                resolvedNamespace = self.preferences.resolveNamespace(
                    availableNamespaces: namespaces,
                    index: self.selectedIndex,
                    currentSelection: self.selectedNamespace
                )
            }

            self.selectedNamespace = resolvedNamespace
            if let index = selectedIndex, let namespace = resolvedNamespace {
                preferences.recordNamespace(namespace, for: index)
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

    /// The default namespace first, then the rest by name
    static func orderedNamespaces<Names: Sequence>(_ names: Names) -> [String] where Names.Element == String {
        names.sorted { lhs, rhs in
            if lhs.isEmpty != rhs.isEmpty { return lhs.isEmpty }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    /// Set the namespace searched in the open index; nil searches every namespace
    @MainActor
    func setNamespace(_ namespace: String?) {
        let trimmed = namespace.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        selectedNamespace = trimmed

        guard let index = selectedIndex else { return }

        if let trimmed {
            defaults.removeObject(forKey: allNamespacesKey(for: index))
            preferences.recordNamespace(trimmed, for: index)
        } else {
            defaults.set(true, forKey: allNamespacesKey(for: index))
        }
    }

    private func allNamespacesKey(for index: String) -> String {
        "search.allNamespaces.\(index)"
    }

    /// The person chose every namespace of this index
    private func searchesAllNamespaces(of index: String) -> Bool {
        defaults.bool(forKey: allNamespacesKey(for: index))
    }

    /// Namespaces the open index search covers: the chosen one, or every namespace (the largest
    /// first, up to the fan-out limit). nil is the default namespace.
    var namespacesToSearch: [String?] {
        if let selectedNamespace {
            return [selectedNamespace.isEmpty ? nil : selectedNamespace]
        }
        guard namespaces.count > 1 else {
            return [namespaces.first.flatMap { $0.isEmpty ? nil : $0 }]
        }
        let largestFirst = namespaces.sorted {
            (namespaceVectorCounts[$0] ?? 0) > (namespaceVectorCounts[$1] ?? 0)
        }
        return largestFirst.prefix(Constants.namespaceFanOutLimit).map { $0.isEmpty ? nil : $0 }
    }

    // MARK: - Where to search

    /// Indexes a search across indexes may use: every listed index the person hasn't left out
    var includedIndexes: [String] {
        pineconeIndexes.filter { !excludedIndexes.contains($0) }
    }

    /// Leave an index out of searches across indexes, or bring it back. The last included index
    /// can't be left out, and leaving out the open one opens another.
    func setIndex(_ name: String, included: Bool) async {
        var excluded = excludedIndexes
        if included {
            excluded.remove(name)
        } else {
            guard includedIndexes.contains(where: { $0 != name }) else { return }
            excluded.insert(name)
        }
        excludedIndexes = excluded
        indexCatalogStore?.saveExcluded(excluded)

        if !included, selectedIndex == name, let replacement = includedIndexes.first {
            await setIndex(replacement)
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

    private func shouldUseCodeInterpreter(for query: String) -> Bool {
        // The model must have the tool too; otherwise the passages would be shortened for nothing
        guard settingsViewModel.codeInterpreterEnabled, settingsViewModel.supportsCodeInterpreter else { return false }
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

    /// Ask a question: the one given, or the one typed in the composer, which is then cleared
    func performSearch(question: String? = nil) async {
        let currentQuery = (question ?? searchQuery).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentQuery.isEmpty else { 
            handleError(SearchError.missingSelection("a query"))
            return
        }
        guard selectedIndex != nil else {
            handleError(SearchError.missingSelection("an index"))
            return
        }
        // The requests read the model, tools and limits from UserDefaults; a change made a moment
        // ago may still be waiting for the debounced save
        settingsViewModel.persistRequestSettings()
        resetSearchState(isPreparingForSearch: true)
        // Append user message to chat history after resetting state
        self.messages.append(ChatMessage(role: .user, text: currentQuery))
        if question == nil {
            self.searchQuery = ""
        }

        // Trace id for this search
        let traceId = UUID().uuidString
        self.logger.log(level: .info, message: "Search started", context: "traceId=\(traceId)")

        // Every step runs in one task, the Pinecone check included, so Stop cancels the whole search
        // and not only the streamed answer
        let task = Task { [weak self] in
            guard let self else { return }

            // Preflight Pinecone health
            let healthy = await self.pineconeService.healthCheck()
            if Task.isCancelled { return }
            if !healthy || self.pineconeService.isCircuitOpen {
                self.isSearching = false
                // An answer that failed, so the question can be retried from the chat
                self.messages.append(ChatMessage(
                    role: .assistant,
                    text: "",
                    status: .error,
                    error: "Pinecone didn't respond. Try again in a moment."
                ))
                self.logger.log(level: .warning, message: "Pinecone preflight failed", context: "traceId=\(traceId)")
                return
            }

            let searchStartTime = Date()
            if self.searchesEverything {
                await self.searchEverything(query: currentQuery, traceId: traceId, searchStartTime: searchStartTime)
            } else if self.shouldRouteSearch {
                await self.routeAndAnswer(query: currentQuery, traceId: traceId, searchStartTime: searchStartTime)
            } else {
                await self.searchOpenIndex(query: currentQuery, traceId: traceId, searchStartTime: searchStartTime)
            }
        }
        routingTask = task
        await task.value
        // A search sent after Stop has its own task by now; leave that one alone
        if routingTask == task {
            routingTask = nil
        }
    }

    /// Search the open index, in the chosen namespace or in each of its namespaces, then stream the
    /// answer. Every search took this path before routing, and it is the fallback whenever routing
    /// can't run.
    private func searchOpenIndex(query currentQuery: String, traceId: String, searchStartTime: Date) async {
        do {
            // Embed the question in the index's own vector space: with the model that built it once
            // the survey has matched one, and the embedding setting until then
            let indexModel = selectedIndex
                .flatMap { indexProfiles[$0] }
                .flatMap { $0.isRoutable ? $0.embeddingModel : nil }
            let queryEmbedding = try await embeddingService.generateQueryEmbedding(
                for: currentQuery,
                dimension: indexDimension,
                model: indexModel
            )
            let filterPayload = buildMetadataFilterPayload()

            // Hybrid search needs the switch on and an index whose metric supports it
            if settingsViewModel.hybridSearchEnabled, !indexSupportsHybridSearch {
                logger.log(
                    level: .warning,
                    message: "Hybrid search requires dotproduct metric (index uses \(indexMetric ?? "unknown")), using dense-only",
                    context: "traceId=\(traceId)"
                )
            }
            var sparseVector: PineconeService.SparseVector?
            if settingsViewModel.hybridSearchEnabled, indexSupportsHybridSearch {
                logger.log(level: .info, message: "Generating sparse embedding for hybrid search", context: "traceId=\(traceId)")
                sparseVector = try await pineconeService.generateSparseEmbedding(for: currentQuery)
            }

            let targets = namespacesToSearch
            let searchesSeveral = targets.count > 1
            let matches: [SearchResultModel]
            if searchesSeveral, let index = selectedIndex {
                routingStatus = "Searching \(targets.count) namespaces of \(index)"
                matches = try await searchNamespaces(
                    targets,
                    of: index,
                    vector: queryEmbedding,
                    sparse: sparseVector,
                    filter: filterPayload,
                    traceId: traceId
                )
                routingStatus = nil
            } else {
                let namespace = targets.first ?? nil
                let response: QueryResponse
                if let sparseVector {
                    let alpha = Float(settingsViewModel.hybridSearchAlpha)
                    logger.log(level: .info, message: "Performing hybrid search", context: "alpha=\(alpha); traceId=\(traceId)")
                    response = try await pineconeService.hybridQuery(
                        denseVector: queryEmbedding,
                        sparseVector: sparseVector,
                        topK: configuredTopK,
                        namespace: namespace,
                        filter: filterPayload,
                        alpha: alpha
                    )
                } else {
                    response = try await pineconeService.query(
                        vector: queryEmbedding,
                        topK: configuredTopK,
                        namespace: namespace,
                        filter: filterPayload
                    )
                }
#if DEBUG
                // Log metadata keys only once per query to reduce verbosity
                if let metadata = response.matches.first(where: { $0.metadata != nil })?.metadata {
                    Logger.shared.log(level: .debug, message: "Pinecone metadata keys", context: metadata.keys.sorted().joined(separator: ", "))
                }
#endif
                matches = response.matches.map { PassageText.searchResult(from: $0) }
            }
            if Task.isCancelled { return }

            // Apply reranking if enabled
            let finalResults = await rerankIfEnabled(matches, query: currentQuery, traceId: traceId)
            if Task.isCancelled { return }

            let avgScore = finalResults.isEmpty ? Float(0) : finalResults.map { $0.score }.reduce(0, +) / Float(finalResults.count)
            let filterDescription = metadataFilters.isEmpty ? "none" : metadataFilters.map { "\($0.key)=\($0.value.displayValue)" }.joined(separator: ", ")
            logger.log(
                level: .info,
                message: "Pinecone query returned \(finalResults.count) matches (avg score \(String(format: "%.3f", Double(avgScore))))",
                context: "filters: \(filterDescription)"
            )

            // The passages sent are tagged S1, S2, … so the answer can cite each one
            let useCodeInterpreter = shouldUseCodeInterpreter(for: currentQuery)
            let maxSources = useCodeInterpreter ? 3 : 5
            let maxContentChars = useCodeInterpreter ? 1200 : 4000
            let sent = Array(finalResults.prefix(maxSources))
            let tagged = PassageText.taggedContext(sent, maxCharacters: maxContentChars, namingScopes: searchesSeveral)
            searchResults = tagged.passages

            if useCodeInterpreter {
                logger.log(level: .info, message: "Code interpreter context capped", context: "sources=\(maxSources); maxChars=\(maxContentChars)")
            } else if settingsViewModel.codeInterpreterEnabled {
                logger.log(level: .info, message: "Code interpreter skipped", context: "reason=heuristic; traceId=\(traceId)")
            }

            await streamAnswer(
                currentQuery: currentQuery,
                context: tagged.text,
                citations: sent.map(\.sourceDocument),
                citationScopes: searchesSeveral ? sent.map { $0.scopeLabel ?? "" } : nil,
                sources: tagged.passages,
                resultCount: finalResults.count,
                useCodeInterpreter: useCodeInterpreter,
                systemPrompt: "\(effectiveSystemPrompt)\n\n\(PassageText.citeInstructions)",
                traceId: traceId,
                searchStartTime: searchStartTime
            )
        } catch {
            // Stop during a routed search's fallback cancels this too, which isn't a failure
            if Task.isCancelled { return }
            routingStatus = nil
            handleError(SearchError.queryFailed(error))
        }
    }

    /// Query each namespace of the open index with one vector and keep the best matches across
    /// them. The namespaces share the index's vector space, so their scores compare directly.
    /// A namespace that fails is skipped; only all of them failing is an error.
    func searchNamespaces(
        _ targets: [String?],
        of index: String,
        vector: [Float],
        sparse: PineconeService.SparseVector?,
        filter: [String: Any]?,
        traceId: String
    ) async throws -> [SearchResultModel] {
        let hybrid = sparse.map { (sparse: $0, alpha: Float(settingsViewModel.hybridSearchAlpha)) }
        let topK = configuredTopK

        let searches: [Task<Result<[SearchResultModel], Error>, Never>] = targets.map { namespace in
            Task {
                do {
                    let response = try await self.pineconeService.query(
                        index: index,
                        vector: vector,
                        hybrid: hybrid,
                        topK: topK,
                        namespace: namespace,
                        filter: filter
                    )
                    return .success(response.matches.map {
                        PassageText.searchResult(from: $0, index: index, namespace: namespace ?? "")
                    })
                } catch {
                    return .failure(error)
                }
            }
        }

        let outcomes = await withTaskCancellationHandler {
            var collected: [Result<[SearchResultModel], Error>] = []
            for search in searches {
                collected.append(await search.value)
            }
            return collected
        } onCancel: {
            searches.forEach { $0.cancel() }
        }

        var merged: [SearchResultModel] = []
        var firstError: Error?
        for (namespace, outcome) in zip(targets, outcomes) {
            switch outcome {
            case .success(let results):
                merged += results
            case .failure(let error):
                firstError = firstError ?? error
                logger.log(
                    level: .warning,
                    message: "Namespace search failed",
                    context: "\(index) / \(namespace ?? "default"); \(error.localizedDescription); traceId=\(traceId)"
                )
            }
        }
        if merged.isEmpty, let firstError {
            throw firstError
        }

        logger.log(level: .info, message: "Searched \(targets.count) namespaces", context: "index=\(index); matches=\(merged.count); traceId=\(traceId)")
        // A euclidean index scores by squared distance, so its best match has the lowest score
        // (docs.pinecone.io, "Create an index", similarity metrics, read 2026-10-01)
        let lowerIsBetter = Self.lowerScoreIsBetter(metric: indexMetric)
        let ordered = merged.sorted { lowerIsBetter ? $0.score < $1.score : $0.score > $1.score }
        return Array(ordered.prefix(topK))
    }

    /// Pinecone's euclidean metric returns squared distances; cosine and dotproduct return
    /// similarities
    static func lowerScoreIsBetter(metric: String?) -> Bool {
        metric?.lowercased() == "euclidean"
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

    /// Routing needs the switch on, a router, and at least two places to search among the indexes
    /// the person hasn't left out
    var shouldRouteSearch: Bool {
        guard settingsViewModel.searchScope == .auto, indexRouter != nil else { return false }
        let included = includedIndexes
        if included.count >= 2 { return true }
        guard let only = included.first else { return false }
        let namespaceCount = only == selectedIndex ? namespaces.count : (indexProfiles[only]?.namespaces.count ?? 0)
        return namespaceCount >= 2
    }

    /// Ask the model where to look, run those searches in parallel, then stream the answer from
    /// their passages. Falls back to searching the open index when routing can't run. After Stop,
    /// `cancelActiveSearch` has already reset the screen and a new search may be running, so a
    /// cancelled task returns without touching any state.
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

        // Searching across indexes has no open index to prefer; the person picked "All indexes"
        let decision: IndexRouter.Decision
        do {
            decision = try await router.route(
                question: query,
                history: historyBeforeCurrentQuestion(),
                profiles: profiles,
                hint: IndexRouter.Hint(index: nil, namespace: nil),
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
                sources: [],
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
            routingStatus = nil

            await streamAnswer(
                currentQuery: query,
                context: routed.text,
                citations: routed.citations,
                citationScopes: routed.citationScopes,
                sources: routed.passages,
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
        rerankEach: Bool = true,
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
                return await self.runRoutedSearch(request, profile: profile, vector: vector, filter: filter, rerank: rerankEach, traceId: traceId)
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
        rerank: Bool = true,
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
            let ranked = rerank ? await rerankIfEnabled(results, query: request.query, traceId: traceId) : results
            return IndexRouter.RoutedSearch(request: request, results: ranked)
        } catch {
            logger.log(level: .warning, message: "Routed search failed", context: "\(request.scopeLabel); \(error.localizedDescription); traceId=\(traceId)")
            return IndexRouter.RoutedSearch(request: request, results: [], failed: true)
        }
    }

    // MARK: - Everything

    /// Everything is chosen: every namespace of every included index is searched
    var searchesEverything: Bool {
        settingsViewModel.searchScope == .everything
    }

    /// Added to the system prompt for an Everything answer
    static let broadSearchInstructions = """
    The passages come from searches of every index and namespace the person keeps. When the \
    answer draws on more than one index or namespace, say which one each point comes from.
    """

    /// Search every namespace of every included index with the question itself, each index with
    /// the model that built it, then keep the best passages across all of them. Nothing picks
    /// where to look, so every place is searched, up to the search limit.
    private func searchEverything(query: String, traceId: String, searchStartTime: Date) async {
        routingStatus = "Looking over your indexes"
        let profiles = await profilesForRouting()
        if Task.isCancelled { return }

        let requests = Self.broadSearchRequests(for: profiles, query: query, limit: Constants.broadSearchLimit)
        guard !requests.isEmpty else {
            routingStatus = nil
            logger.log(level: .warning, message: "Everything search skipped: no index has a known embedding model yet", context: "traceId=\(traceId)")
            await searchOpenIndex(query: query, traceId: traceId, searchStartTime: searchStartTime)
            return
        }

        let indexCount = Set(requests.map(\.index)).count
        routingStatus = "Searching \(requests.count) \(requests.count == 1 ? "namespace" : "namespaces") in \(indexCount) \(indexCount == 1 ? "index" : "indexes")"
        logger.log(
            level: .info,
            message: "Everything search: \(requests.count) searches",
            context: requests.map(\.scopeLabel).joined(separator: " | ") + "; traceId=\(traceId)"
        )

        let profilesByName = Dictionary(uniqueKeysWithValues: profiles.map { ($0.name, $0) })
        let searches: [IndexRouter.RoutedSearch]
        do {
            // Reranked once, all together, below
            searches = try await runRoutedSearches(requests, profiles: profilesByName, rerankEach: false, traceId: traceId)
        } catch {
            if Task.isCancelled { return }
            routingStatus = nil
            logger.log(level: .warning, message: "Everything search failed; searching the open index", context: "\(error.localizedDescription); traceId=\(traceId)")
            await searchOpenIndex(query: query, traceId: traceId, searchStartTime: searchStartTime)
            return
        }
        if Task.isCancelled { return }

        if searches.allSatisfy(\.failed) {
            routingStatus = nil
            logger.log(level: .warning, message: "Every search failed; searching the open index", context: "traceId=\(traceId)")
            await searchOpenIndex(query: query, traceId: traceId, searchStartTime: searchStartTime)
            return
        }

        let succeeded = searches.filter { !$0.failed }
        let merged = Self.mergedAcrossSearches(
            succeeded.map(\.results),
            lowerScoreIsBetter: succeeded.map { Self.lowerScoreIsBetter(metric: profilesByName[$0.request.index]?.metric) }
        )
        let ranked = await rerankIfEnabled(Array(merged.prefix(Constants.broadRerankCandidates)), query: query, traceId: traceId)
        if Task.isCancelled { return }

        let useCodeInterpreter = shouldUseCodeInterpreter(for: query)
        let kept = Array(ranked.prefix(Self.broadKeptCount(searchCount: succeeded.count, usesCodeInterpreter: useCodeInterpreter)))
        let tagged = PassageText.taggedContext(kept, maxCharacters: useCodeInterpreter ? 1200 : 2000, namingScopes: true)
        var context = tagged.text
        let failed = searches.filter(\.failed).map(\.request.scopeLabel)
        if !failed.isEmpty {
            context = "These searches failed, so nothing from them is included: \(failed.joined(separator: ", ")).\n\n" + context
        }

        searchResults = tagged.passages
        routingStatus = nil
        logger.log(
            level: failed.isEmpty ? .info : .warning,
            message: "Everything search kept \(kept.count) of \(merged.count) passages",
            context: "failed=\(failed.count) of \(searches.count); traceId=\(traceId)"
        )

        await streamAnswer(
            currentQuery: query,
            context: context,
            citations: kept.map(\.sourceDocument),
            citationScopes: kept.map { $0.scopeLabel ?? "" },
            sources: tagged.passages,
            resultCount: merged.count,
            useCodeInterpreter: useCodeInterpreter,
            systemPrompt: "\(effectiveSystemPrompt)\n\n\(PassageText.citeInstructions)\n\n\(Self.broadSearchInstructions)",
            traceId: traceId,
            searchStartTime: searchStartTime
        )
    }

    /// Passages an Everything answer gets: the usual 8 (3 with code interpreter), or one for every
    /// search when there are more searches, so each search's best passage reaches the answer;
    /// scores from different indexes can't decide which ones to drop. At most the search limit.
    static func broadKeptCount(searchCount: Int, usesCodeInterpreter: Bool) -> Int {
        min(max(usesCodeInterpreter ? 3 : 8, searchCount), Constants.broadSearchLimit)
    }

    /// One search per namespace that holds passages, in every index whose embedding model is
    /// known, each index's largest namespaces first. Indexes take turns, so when the limit cuts
    /// the list short, every index still gets its largest namespaces searched.
    static func broadSearchRequests(for profiles: [IndexProfile], query: String, limit: Int) -> [IndexRouter.SearchRequest] {
        let perIndex: [[IndexRouter.SearchRequest]] = profiles
            .filter(\.isRoutable)
            .sorted { $0.name < $1.name }
            .map { profile in
                profile.namespaces
                    .filter { $0.vectorCount > 0 }
                    .sorted { $0.vectorCount > $1.vectorCount }
                    .map { IndexRouter.SearchRequest(index: profile.name, namespace: $0.name, query: query) }
            }

        var requests: [IndexRouter.SearchRequest] = []
        var depth = 0
        while requests.count < limit {
            let round = perIndex.compactMap { depth < $0.count ? $0[depth] : nil }
            guard !round.isEmpty else { break }
            requests += round.prefix(limit - requests.count)
            depth += 1
        }
        return requests
    }

    /// Every search's best passage first, then every search's second, and so on. Raw scores from
    /// different indexes aren't on one scale (different models, metrics and corpora), so within a
    /// round passages are ordered by how far each stands above the rest of its own search: its
    /// score's distance from that search's mean, in that search's standard deviations, flipped for
    /// a metric where lower is better.
    static func mergedAcrossSearches(_ lists: [[SearchResultModel]], lowerScoreIsBetter: [Bool] = []) -> [SearchResultModel] {
        var ranked: [(rank: Int, standing: Double, result: SearchResultModel)] = []
        for (position, list) in lists.enumerated() {
            let flip = position < lowerScoreIsBetter.count && lowerScoreIsBetter[position]
            let scores = list.map { Double($0.score) }
            let count = Double(max(scores.count, 1))
            let mean = scores.reduce(0, +) / count
            let spread = (scores.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / count).squareRoot()
            for (rank, result) in list.enumerated() {
                var standing = spread > 0 ? (Double(result.score) - mean) / spread : 0
                if flip { standing = -standing }
                ranked.append((rank: rank, standing: standing, result: result))
            }
        }
        ranked.sort { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            return lhs.standing > rhs.standing
        }
        return ranked.map { $0.result }
    }

    /// After the scope changes: Auto and Everything search only included indexes, and the open
    /// index is their fallback and the one filters apply to, so it must be one of them
    func scopeDidChange() async {
        guard settingsViewModel.searchScope != .oneIndex,
              let open = selectedIndex, excludedIndexes.contains(open),
              let replacement = includedIndexes.first
        else {
            return
        }
        await setIndex(replacement)
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
        let candidates = includedIndexes
        let missing = candidates.filter { indexProfiles[$0] == nil }
        if !missing.isEmpty {
            await surveyIndexes(missing, recheckModels: false, draftSummaries: false)
            scheduleIndexSurvey()
        }
        return candidates.compactMap { indexProfiles[$0] }
    }

    /// Survey, in the background, indexes that have no profile or are due for another look
    func scheduleIndexSurvey(recheckModels: Bool = false) {
        guard indexSurveyor != nil, settingsViewModel.indexRoutingEnabled, indexSurveyTask == nil else { return }
        guard !pineconeIndexes.isEmpty, recheckModels || shouldRouteSearch || searchesEverything else { return }

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
        sources: [SearchResultModel],
        resultCount: Int,
        useCodeInterpreter: Bool,
        systemPrompt: String,
        traceId: String,
        searchStartTime: Date
    ) async {
        // Stop pressed during the search: `cancelActiveSearch` has already answered the question
        if Task.isCancelled { return }

        // Prepare streaming assistant message; its passages are there from the start, so a tag is
        // tappable while the answer is still being written
        let assistantMessageId = UUID()
        await MainActor.run {
            self.generatedAnswer = ""
            self.messages.append(ChatMessage(id: assistantMessageId, role: .assistant, text: "", citations: nil, sources: sources, status: .streaming))
        }

        // Memory: the earlier exchanges go with each question, and OpenAIService keeps as many as the
        // person chose (RequestSettings.historyExchanges). The memory OpenCone used to offer from
        // OpenAI needed a conversation created through OpenAI's Conversations API, which OpenCone never
        // made, so that mode sent no history at all.
        let historyArg = conversationHistory(before: currentQuery)

        // Watchdog: if no text arrives within Constants.watchdogDelayNanoseconds (30 s), cancel the stream
        // and ask once without streaming
        let watchdogTask = Task { [weak self] in
            guard let self = self else { return }
            // Flex is slower by design: a fallback would ask again at the same tier and pay for both
            let model = await MainActor.run { self.settingsViewModel.completionModel }
            guard RequestSettings.serviceTier(for: model) != "flex" else { return }
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
                    let fallbackHistory = await MainActor.run { self.conversationHistory(before: query) }
                    do {
                        let fallback = try await self.openAIService.generateCompletion(
                            systemPrompt: systemPrompt,
                            userMessage: query,
                            context: context,
                            history: fallbackHistory,
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
                                        let fallbackQuery = currentQuery
                                        let fallback = try await self.openAIService.generateCompletion(
                                            systemPrompt: systemPrompt,
                                            userMessage: fallbackQuery,
                                            context: context,
                                            history: historyArg,
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

    // MARK: - Conversation Threads

    func newTopic() {
        // An OpenAI conversation id an earlier version stored; nothing reads it now
        UserDefaults.standard.removeObject(forKey: "openai.conversationId")
        Task { @MainActor in
            self.messages.removeAll()
            self.searchResults = []
            self.codeInterpreterOutputs = []
            self.generatedAnswer = ""
            self.errorMessage = nil
        }
    }

    /// Ask the question behind the latest answer again. The new answer replaces the old one, which
    /// is not sent as memory. A question being typed in the composer stays there.
    func retryLastAnswer() async {
        guard !isSearching,
              let answerPosition = messages.lastIndex(where: { $0.role == .assistant }),
              answerPosition == messages.count - 1,
              let questionPosition = messages[..<answerPosition].lastIndex(where: { $0.role == .user })
        else {
            return
        }
        let question = messages[questionPosition].text
        messages.removeSubrange(questionPosition...answerPosition)
        await performSearch(question: question)
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
            if self.messages.last?.role == .user {
                // Stopped while searching, before the answer began: leave an answer that can be retried
                self.messages.append(ChatMessage(role: .assistant, text: "", status: .error, error: "Stopped"))
            } else if let lastIdx = self.messages.lastIndex(where: { $0.role == .assistant }) {
                var msg = self.messages[lastIdx]
                if msg.text.isEmpty {
                    msg.status = .error
                    msg.error = "Stopped"
                    self.messages[lastIdx] = msg
                } else if msg.status == .streaming {
                    // What arrived before Stop stays, as a finished answer
                    msg.status = .normal
                    self.messages[lastIdx] = msg
                }
            }
        }
    }

    // MARK: - Private Helpers

    /// The finished messages before the question being answered. The question is the last user
    /// message by then and goes to OpenAI on its own, so it's left out here; this used to compare it
    /// with the composer, which is empty once a question is sent, and so sent the question twice.
    private func conversationHistory(before question: String) -> [ChatMessage] {
        var history = messages.filter { $0.status == .normal && !$0.text.isEmpty }
        if let last = history.last, last.role == .user, last.text == question {
            history.removeLast()
        }
        return history
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
        self.errorMessage = nil
    }

    /// Handles errors by logging them and updating the UI. A failure of a question's search or
    /// answer becomes that question's answer, where it can be retried; anything else shows in the
    /// banner.
    /// - Parameter error: The SearchError that occurred.
    @MainActor
    private func handleError(_ error: SearchError) {
        self.isSearching = false

        let detail = [error.localizedDescription, error.underlyingError?.localizedDescription]
            .compactMap { $0 }
            .joined(separator: " ")
        self.logger.log(
            level: ProcessingLogEntry.LogLevel.error,
            message: error.localizedDescription,
            context: error.underlyingError?.localizedDescription ?? "No underlying error details."
        )

        if error.belongsToAnswer {
            if self.messages.last?.role == .user {
                self.messages.append(ChatMessage(role: .assistant, text: "", status: .error, error: detail))
                return
            }
            if let lastIdx = self.messages.lastIndex(where: { $0.role == .assistant }),
               self.messages[lastIdx].status == .streaming {
                // Partway through: what arrived stays, marked as failed
                var msg = self.messages[lastIdx]
                msg.status = .error
                msg.error = detail
                self.messages[lastIdx] = msg
                return
            }
        }

        self.errorMessage = "\(error.localizedDescription) \(error.recoverySuggestion ?? "")"

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
