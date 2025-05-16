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
            "Answer the user's question using ONLY the information provided in the context. If the answer isn't in the context, say you don't have enough information. Be concise and directly answer the question."

        /// Transition duration for animations
        static let transitionDuration: Double = 0.3

        /// Semantic colors for result categories
        static let scoreColors: [(threshold: Float, name: String)] = [
            (0.9, "High Relevance"),
            (0.7, "Medium Relevance"),
            (0.0, "Low Relevance"),
        ]
    }

    // MARK: - Dependencies
    private let pineconeService: PineconeService
    private let openAIService: OpenAIService
    private let embeddingService: EmbeddingService
    private let logger = Logger.shared
    private var themeManager = ThemeManager.shared

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
    @Published var lastSearchTime: Date? = nil
    @Published var currentTheme: OCTheme = ThemeManager.shared.currentTheme

    // Visual state properties
    @Published var searchResultsOpacity: Double = 0.0
    @Published var answerGenerationProgress: Double = 0.0

    // Cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()

    init(
        pineconeService: PineconeService, openAIService: OpenAIService,
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
                if !indexes.isEmpty && self.selectedIndex == nil {
                    self.selectedIndex = indexes[0]
                }
            }
        } catch {
            await handleError(SearchError.indexLoadingFailed(error))  // Add await
        }
    }

    /// Set the current Pinecone index
    /// - Parameter indexName: Name of the index to set
    func setIndex(_ indexName: String) async {
        do {
            try await pineconeService.setCurrentIndex(indexName)
            await loadNamespaces()
            await MainActor.run {
                self.selectedIndex = indexName
            }
        } catch {
            await handleError(SearchError.indexSetFailed(error))  // Add await
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
                if self.selectedNamespace == nil || !namespaces.contains(self.selectedNamespace!) {
                    self.selectedNamespace = namespaces.first
                }
            }
        } catch {
            await handleError(SearchError.namespaceLoadingFailed(error))  // Add await
        }
    }

    /// Set the current namespace
    /// - Parameter namespace: Namespace to set
    func setNamespace(_ namespace: String?) {
        self.selectedNamespace = namespace
    }

    /// Toggle selection of a search result
    /// - Parameter result: The search result to toggle
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

    /// Perform a search with the current query
    func performSearch() async {
        guard !searchQuery.isEmpty else {
            await handleError(SearchError.missingSelection("a query"))  // Add await
            return
        }
        guard selectedIndex != nil else {
            await handleError(SearchError.missingSelection("an index"))  // Add await
            return
        }

        await resetSearchState()  // Add await - Reset state before starting

        // Record search start time
        let searchStartTime = Date()

        do {
            // Generate embedding for query
            let queryEmbedding = try await embeddingService.generateQueryEmbedding(for: searchQuery)

            // Search Pinecone
            let queryResults = try await pineconeService.query(
                vector: queryEmbedding,
                topK: Constants.topKResults,  // Use constant
                namespace: selectedNamespace
            )

            // Map results to search result models
            let results = queryResults.matches.map { match in
                SearchResultModel(
                    content: match.metadata?["text"] ?? "No content",
                    sourceDocument: match.metadata?["source"] ?? "Unknown source",
                    score: match.score,
                    metadata: match.metadata ?? [:]
                )
            }

            // Simulate answer generation progress for visual feedback
            await MainActor.run {
                self.searchResults = results
                self.searchResultsOpacity = 1.0
                self.answerGenerationProgress = 0.3
            }

            // Generate answer using OpenAI
            let context = results.prefix(5).map { result in  // Still using top 5 for context generation
                "Source: \(result.sourceDocument)\n\(result.content)"
            }.joined(separator: "\n\n")

            // Progress update
            await MainActor.run {
                self.answerGenerationProgress = 0.6
            }

            let answer = try await openAIService.generateCompletion(
                systemPrompt: Constants.openAISystemPrompt,  // Use constant
                userMessage: searchQuery,
                context: context
            )

            await MainActor.run {
                self.generatedAnswer = answer
                self.isSearching = false
                self.answerGenerationProgress = 1.0
                self.lastSearchTime = searchStartTime
                self.logger.log(
                    level: .success, message: "Search completed",
                    context: "Found \(results.count) results")
            }
            // Removed specific catch blocks as types were not found
        } catch {
            // Log error appropriately - decide if it's embedding, query, or generation
            // For now, defaulting to queryFailed, but this could be improved if needed
            await handleError(SearchError.queryFailed(error))  // Add await - Generic fallback
        }
    }

    /// Clear current search results and query
    @MainActor  // Mark as MainActor since it calls resetSearchState
    func clearSearch() {
        searchQuery = ""
        resetSearchState()  // Use reset function
    }

    /// Generate an answer based on selected results
    func generateAnswerFromSelected() async {
        guard !selectedResults.isEmpty else {
            await handleError(SearchError.missingSelection("at least one source document"))  // Add await
            return
        }
        guard !searchQuery.isEmpty else {
            await handleError(SearchError.missingSelection("a query"))  // Add await
            return
        }

        await MainActor.run {
            self.isSearching = true
            self.generatedAnswer = ""  // Clear previous answer
            self.errorMessage = nil  // Clear previous error
        }

        do {
            // Use only selected results for context
            let context = selectedResults.map { result in  // Context from selected results
                "Source: \(result.sourceDocument)\n\(result.content)"
            }.joined(separator: "\n\n")

            let answer = try await openAIService.generateCompletion(
                systemPrompt: Constants.openAISystemPrompt,  // Use constant
                userMessage: searchQuery,
                context: context
            )

            await MainActor.run {
                self.generatedAnswer = answer
                self.isSearching = false
                self.logger.log(
                    level: .success, message: "Answer generated from selected results",
                    context: "Using \(selectedResults.count) results")
            }
            // Removed specific catch block as type was not found
        } catch {
            // Defaulting to answerGenerationFailed for any error in this block
            await handleError(SearchError.answerGenerationFailed(error))  // Add await - Generic fallback
        }
    }

    // MARK: - Private Helpers

    /// Resets the search-related state variables, typically before a new search.
    @MainActor
    private func resetSearchState() {
        self.isSearching = true
        self.searchResults = []
        self.generatedAnswer = ""
        self.selectedResults = []
        self.errorMessage = nil
    }

    /// Handles errors by logging them and updating the UI.
    /// - Parameter error: The SearchError that occurred.
    @MainActor
    private func handleError(_ error: SearchError) {
        self.errorMessage = "\(error.localizedDescription) \(error.recoverySuggestion ?? "")"
        self.isSearching = false  // Ensure searching indicator is turned off on error
        // Use the fully qualified LogLevel as defined in Logger.swift / DocumentModel.swift
        self.logger.log(
            level: ProcessingLogEntry.LogLevel.error,
            message: error.localizedDescription,
            context: error.underlyingError?.localizedDescription ?? "No underlying error details.")
    }
}

// Removed placeholder error struct definitions
