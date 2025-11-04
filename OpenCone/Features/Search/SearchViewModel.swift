import Combine
import Foundation
import SwiftUI

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

// MARK: - Search View Model

/// View model for the search functionality
class SearchViewModel: ObservableObject {

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

        static let watchdogDelayNanoseconds: UInt64 = 12_000_000_000
    }

    // MARK: - Dependencies
    private let pineconeService: PineconeService
    private let openAIService: OpenAIService
    private let embeddingService: EmbeddingService
    private let logger = Logger.shared
    private var themeManager = ThemeManager.shared
    private let defaults = UserDefaults.standard
    private let lastIndexKey = "oc.lastIndex"
    private func nsKey(_ index: String) -> String { "oc.lastNamespace.\(index)" }

    // Published properties for UI binding
    @Published var searchQuery = ""
    @Published var isSearching = false
    @Published var searchResults: [SearchResultModel] = []
    @Published var generatedAnswer: String = ""
    @Published var selectedResults: [SearchResultModel] = []
    @Published var errorMessage: String? = nil  // Holds user-facing error message
    @Published var pineconeIndexes: [String] = []
    @Published var namespaces: [String] = []
    @Published var selectedIndex: String? = nil
    @Published var selectedNamespace: String? = nil
    @Published var indexDimension: Int? = nil
    @Published var lastSearchTime: Date? = nil
    @Published var currentTheme: OCTheme = ThemeManager.shared.currentTheme
    @Published var messages: [ChatMessage] = []
    @Published var conversationId: String? = UserDefaults.standard.string(forKey: "openai.conversationId")
    @Published var highlightedResultID: UUID? = nil
    @Published var expandedResultIDs: Set<UUID> = []

    // Visual state properties
    @Published var searchResultsOpacity: Double = 0.0
    @Published var answerGenerationProgress: Double = 0.0

    // Cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    private var currentStreamTask: Task<Void, Never>? = nil

    init(
        pineconeService: PineconeService,
        openAIService: OpenAIService,
        embeddingService: EmbeddingService
    ) {
        self.pineconeService = pineconeService
        self.openAIService = openAIService
        self.embeddingService = embeddingService

        // Subscribe to theme changes
        themeManager.$currentTheme
            .sink { [weak self] theme in
                self?.currentTheme = theme
            }
            .store(in: &cancellables)
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
    func loadIndexes() async {
        do {
            let indexes = try await pineconeService.listIndexes()
            await MainActor.run {
                self.pineconeIndexes = indexes
                if let saved = self.defaults.string(forKey: self.lastIndexKey), indexes.contains(saved) {
                    self.selectedIndex = saved
                    Task { await self.setIndex(saved) }
                } else if !indexes.isEmpty && self.selectedIndex == nil {
                    self.selectedIndex = indexes[0]
                }
            }
        } catch {
            await handleError(SearchError.indexLoadingFailed(error))
        }
    }

    /// Set the current Pinecone index
    /// - Parameter indexName: Name of the index to set
    func setIndex(_ indexName: String) async {
        do {
            // Set current index first to get the host
            try await pineconeService.setCurrentIndex(indexName)

            // Now describe the index to get its dimension
            let indexDetails = try await pineconeService.describeIndex(name: indexName)

            await MainActor.run {
                self.selectedIndex = indexName
                self.indexDimension = indexDetails.dimension
                self.logger.log(level: .info, message: "Index '\(indexName)' selected with dimension \(indexDetails.dimension)")
            }

            // Load namespaces for the new index
            await loadNamespaces()

            // Persist last chosen index
            defaults.set(indexName, forKey: lastIndexKey)
        } catch {
            await handleError(SearchError.indexSetFailed(error))
        }
    }

    /// Load available namespaces for the current index
    func loadNamespaces() async {
        guard selectedIndex != nil else {
            await MainActor.run {
                self.namespaces = []
                self.selectedNamespace = nil
            }
            return
        }

        do {
            let namespaces = try await pineconeService.listNamespaces()
            await MainActor.run {
                self.namespaces = namespaces
                if let idx = self.selectedIndex,
                   let savedNS = self.defaults.string(forKey: self.nsKey(idx)),
                   namespaces.contains(savedNS) {
                    self.selectedNamespace = savedNS
                } else if self.selectedNamespace == nil || !(self.selectedNamespace.map { namespaces.contains($0) } ?? false) {
                    self.selectedNamespace = namespaces.first
                }
            }
        } catch {
            await handleError(SearchError.namespaceLoadingFailed(error))
        }
    }

    /// Set the current namespace
    func setNamespace(_ namespace: String?) {
        self.selectedNamespace = namespace
        if let ns = namespace, let idx = self.selectedIndex {
            defaults.set(ns, forKey: nsKey(idx))
        }
    }

    /// Toggle selection of a search result
    func toggleResultSelection(_ result: SearchResultModel) {
        if let index = searchResults.firstIndex(where: { $0.id == result.id }) {
            searchResults[index].isSelected.toggle()

            // Update the selected results array
            if searchResults[index].isSelected {
                selectedResults.append(searchResults[index])
            } else {
                selectedResults.removeAll(where: { $0.id == result.id })
            }
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

    /// Perform a search with the current query
    func performSearch() async {
        guard !searchQuery.isEmpty else {
            await handleError(SearchError.missingSelection("a query"))
            return
        }
        guard selectedIndex != nil else {
            await handleError(SearchError.missingSelection("an index"))
            return
        }
        await resetSearchState(isPreparingForSearch: true)
        // Append user message to chat history after resetting state
        await MainActor.run {
            self.messages.append(ChatMessage(role: .user, text: self.searchQuery))
        }

        // Trace id for this search
        let traceId = UUID().uuidString
        self.logger.log(level: .info, message: "Search started", context: "traceId=\(traceId)")

        // Preflight Pinecone health
        let healthy = await pineconeService.healthCheck()
        if !healthy || pineconeService.isCircuitOpen {
            await MainActor.run {
                self.isSearching = false
                self.errorMessage = "Pinecone temporarily unavailable; retrying soon."
            }
            self.logger.log(level: .warning, message: "Pinecone preflight failed", context: "traceId=\(traceId)")
            return
        }

        // Record search start time
        let searchStartTime = Date()

        do {
            // Generate embedding for query, passing the index's dimension
            let queryEmbedding = try await embeddingService.generateQueryEmbedding(for: searchQuery, dimension: indexDimension)

            // Search Pinecone
            let queryResults = try await pineconeService.query(
                vector: queryEmbedding,
                topK: Constants.topKResults,
                namespace: selectedNamespace
            )

            // Map results to search result models (metadata may contain non-string values)
            let results = queryResults.matches.map { match in
#if DEBUG
                if let metadata = match.metadata {
                    Logger.shared.log(level: .info, message: "Pinecone match metadata keys", context: metadata.keys.joined(separator: ", "))
                }
#endif

                // Extract content - _node_content might be JSON that needs parsing
                var content = "No content"
                if let nodeContent = match.metadata?["_node_content"]?.string {
                    if let jsonData = nodeContent.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let textContent = json["text"] as? String {
                        content = textContent
                    } else {
                        content = nodeContent
                    }
                } else if let textContent = match.metadata?["text"]?.string {
                    content = textContent
                }

#if DEBUG
                Logger.shared.log(level: .info, message: "Extracted content", context: "length=\(content.count), preview=\(String(content.prefix(200)))")
#endif

                // Try multiple possible source fields
                let source = match.metadata?["title"]?.string ?? 
                            match.metadata?["source"]?.string ?? 
                            match.metadata?["doc_id"]?.string ??
                            "Unknown source"
                // Convert only string-like metadata entries into [String: String] for UI
                let metaStrings: [String: String] = match.metadata?.reduce(into: [:]) { acc, kv in
                    if let s = kv.value.string {
                        acc[kv.key] = s
                    }
                } ?? [:]
                return SearchResultModel(
                    content: content,
                    sourceDocument: source,
                    score: Float(match.score),
                    metadata: metaStrings
                )
            }

            // Progress update for visuals
            await MainActor.run {
                self.searchResults = results
                self.searchResultsOpacity = 1.0
                self.answerGenerationProgress = 0.6
                self.highlightedResultID = nil
                self.expandedResultIDs.removeAll()
            }

            // Prepare context and citations
            let context = results.prefix(5).map { result in
                "Source: \(result.sourceDocument)\n\(result.content)"
            }.joined(separator: "\n\n")
            let citations = results.prefix(5).map { $0.sourceDocument }

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
            let watchdogTask = Task {
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
                        let query = await MainActor.run { self.searchQuery }
                        let fallbackHistory: [ChatMessage] = useServer ? [] : await MainActor.run { self.conversationHistoryExcludingCurrentUser() }
                        let fallbackConversationId: String? = useServer ? nil : convIdArg
                        do {
                            let fallback = try await self.openAIService.generateCompletion(
                                systemPrompt: Constants.openAISystemPrompt,
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
                                }
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
                    try await openAIService.streamCompletion(
                        systemPrompt: Constants.openAISystemPrompt,
                        userMessage: searchQuery,
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
                            if deltaCount <= 3 {
                                self.logger.log(level: .info, message: "OpenAI delta", context: "len=\(delta.count); traceId=\(traceId)")
                            }
                            Task { @MainActor in
                                self.generatedAnswer += delta
                                if let index = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                                    var msg = self.messages[index]
                                    msg.text += delta
                                    self.messages[index] = msg
                                    if deltaCount <= 3 {
                                        self.logger.log(level: .info, message: "Updated message text to: '\(msg.text)'")
                                    }
                                }
                            }
                        },
                        onCompleted: {
                            // Finalize even if no deltas arrived; if empty, fallback to non-stream completion once
                            Task {
                                self.logger.log(level: .info, message: "OpenAI stream completed", context: "deltaCount=\(deltaCount); traceId=\(traceId)")
                                if let index = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                                    if self.messages[index].text.isEmpty {
                                        do {
                                            let fallbackHistory: [ChatMessage] = useServer ? [] : await MainActor.run { self.conversationHistoryExcludingCurrentUser() }
                                            let fallbackConversationId: String? = useServer ? nil : convIdArg
                                            let fallbackQuery = await MainActor.run { self.searchQuery }
                                            let fallback = try await self.openAIService.generateCompletion(
                                                systemPrompt: Constants.openAISystemPrompt,
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
                                                }
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
                                    self.answerGenerationProgress = 1.0
                                    self.lastSearchTime = searchStartTime
                                    self.currentStreamTask = nil
                                    self.logger.log(
                                        level: .success,
                                        message: "Search completed",
                                        context: "traceId=\(traceId); Found \(results.count) results"
                                    )
                                }
                            }
                        }
                    )
                } catch is CancellationError {
                    watchdogTask.cancel() // Clean up watchdog on cancellation
                    await MainActor.run {
                        self.logger.log(level: .info, message: "Responses streaming cancelled", context: "traceId=\(traceId)")
                    }
                    // Suppress UI error; watchdog or user cancel will handle state and message finalization
                } catch {
                    watchdogTask.cancel() // Clean up watchdog on error
                    await self.handleError(SearchError.answerGenerationFailed(error))
                }
            }
        } catch {
            await handleError(SearchError.queryFailed(error))
        }
    }

    /// Clear current search results and query
    @MainActor
    func clearSearch() {
        searchQuery = ""
        resetSearchState()
    }

    /// Generate an answer based on selected results
    func generateAnswerFromSelected() async {
        guard !selectedResults.isEmpty else {
            await handleError(SearchError.missingSelection("at least one source document"))
            return
        }
        guard !searchQuery.isEmpty else {
            await handleError(SearchError.missingSelection("a query"))
            return
        }

        await MainActor.run {
            self.isSearching = true
            self.generatedAnswer = ""
            self.errorMessage = nil
        }

        let traceId = UUID().uuidString
        self.logger.log(level: .info, message: "Generate from selected started", context: "traceId=\(traceId)")

        // Build context and citations
        let context = self.selectedResults.map { result in
            "Source: \(result.sourceDocument)\n\(result.content)"
        }.joined(separator: "\n\n")
        let citations = self.selectedResults.map { $0.sourceDocument }

        let assistantMessageId = UUID()
        await MainActor.run {
            self.generatedAnswer = ""
            self.messages.append(ChatMessage(id: assistantMessageId, role: .assistant, text: "", citations: nil, status: .streaming))
        }

        let useServer = (UserDefaults.standard.string(forKey: "openai.conversationMode") ?? "server") == "server"
        let historyArg: [ChatMessage] = useServer ? [] : await MainActor.run { self.conversationHistoryExcludingCurrentUser() }
        let convIdArg: String? = (useServer && (self.conversationId?.hasPrefix("conv") ?? false)) ? self.conversationId : nil

        // Watchdog: if no deltas within 7s, cancel stream and fallback to non-stream completion
        let watchdogTask = Task {
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
                    let query = await MainActor.run { self.searchQuery }
                    let fallbackHistory: [ChatMessage] = useServer ? [] : await MainActor.run { self.conversationHistoryExcludingCurrentUser() }
                    let fallbackConversationId: String? = useServer ? nil : convIdArg
                    do {
                        let fallback = try await self.openAIService.generateCompletion(
                            systemPrompt: Constants.openAISystemPrompt,
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
                            }
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
                try await openAIService.streamCompletion(
                    systemPrompt: Constants.openAISystemPrompt,
                    userMessage: searchQuery,
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
                        if deltaCount <= 3 {
                            self.logger.log(level: .info, message: "OpenAI delta", context: "len=\(delta.count); traceId=\(traceId)")
                        }
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
                    onCompleted: {
                        // Finalize even if no deltas arrived; if empty, fallback to non-stream completion once
                        Task {
                            self.logger.log(level: .info, message: "OpenAI stream completed", context: "deltaCount=\(deltaCount); traceId=\(traceId)")
                            if let index = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                                if self.messages[index].text.isEmpty {
                                    do {
                                        let fallbackHistory: [ChatMessage] = useServer ? [] : await MainActor.run { self.conversationHistoryExcludingCurrentUser() }
                                        let fallbackConversationId: String? = useServer ? nil : convIdArg
                                        let fallbackQuery = await MainActor.run { self.searchQuery }
                                        let fallback = try await self.openAIService.generateCompletion(
                                            systemPrompt: Constants.openAISystemPrompt,
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
                                            }
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
                await MainActor.run {
                    self.logger.log(level: .info, message: "Responses streaming cancelled", context: "traceId=\(traceId)")
                }
                // Suppress UI error; watchdog or user cancel will handle state and message finalization
            } catch {
                watchdogTask.cancel() // Clean up watchdog on error
                await self.handleError(SearchError.answerGenerationFailed(error))
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

    // MARK: - Cancellation

    func cancelActiveSearch() {
        currentStreamTask?.cancel()
        currentStreamTask = nil
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

    /// Resets the search-related state variables, typically before a new search.
    @MainActor
    private func resetSearchState(isPreparingForSearch: Bool = false) {
        self.isSearching = isPreparingForSearch
        self.searchResults = []
        self.generatedAnswer = ""
        self.selectedResults = []
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
