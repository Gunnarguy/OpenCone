import Foundation
import Combine

/// View model for the search functionality
class SearchViewModel: ObservableObject {
    // Dependencies
    private let pineconeService: PineconeService
    private let openAIService: OpenAIService
    private let embeddingService: EmbeddingService
    private let logger = Logger.shared
    
    // Published properties for UI binding
    @Published var searchQuery = ""
    @Published var isSearching = false
    @Published var searchResults: [SearchResultModel] = []
    @Published var generatedAnswer: String = ""
    @Published var selectedResults: [SearchResultModel] = []
    @Published var errorMessage: String? = nil
    @Published var pineconeIndexes: [String] = []
    @Published var namespaces: [String] = []
    @Published var selectedIndex: String? = nil
    @Published var selectedNamespace: String? = nil
    
    // Cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    init(pineconeService: PineconeService, openAIService: OpenAIService, embeddingService: EmbeddingService) {
        self.pineconeService = pineconeService
        self.openAIService = openAIService
        self.embeddingService = embeddingService
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
            await MainActor.run {
                self.errorMessage = "Failed to load indexes: \(error.localizedDescription)"
                self.logger.log(level: .error, message: "Failed to load indexes", context: error.localizedDescription)
            }
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
            await MainActor.run {
                self.errorMessage = "Failed to set index: \(error.localizedDescription)"
                self.logger.log(level: .error, message: "Failed to set index", context: error.localizedDescription)
            }
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
            await MainActor.run {
                self.errorMessage = "Failed to load namespaces: \(error.localizedDescription)"
                self.logger.log(level: .error, message: "Failed to load namespaces", context: error.localizedDescription)
            }
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
            return
        }
        
        await MainActor.run {
            self.isSearching = true
            self.searchResults = []
            self.generatedAnswer = ""
            self.selectedResults = []
            self.errorMessage = nil
        }
        
        do {
            // Generate embedding for query
            let queryEmbedding = try await embeddingService.generateQueryEmbedding(for: searchQuery)
            
            // Search Pinecone
            let queryResults = try await pineconeService.query(
                vector: queryEmbedding,
                topK: 20,
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
            
            // Generate answer using OpenAI
            let context = results.prefix(5).map { result in
                "Source: \(result.sourceDocument)\n\(result.content)"
            }.joined(separator: "\n\n")
            
            let answer = try await openAIService.generateCompletion(
                systemPrompt: "Answer the user's question using ONLY the information provided in the context. If the answer isn't in the context, say you don't have enough information.",
                userMessage: searchQuery,
                context: context
            )
            
            await MainActor.run {
                self.searchResults = results
                self.generatedAnswer = answer
                self.isSearching = false
                
                self.logger.log(level: .success, message: "Search completed", context: "Found \(results.count) results")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Search failed: \(error.localizedDescription)"
                self.isSearching = false
                
                self.logger.log(level: .error, message: "Search failed", context: error.localizedDescription)
            }
        }
    }
    
    /// Clear current search results
    func clearSearch() {
        searchQuery = ""
        searchResults = []
        generatedAnswer = ""
        selectedResults = []
        errorMessage = nil
    }
    
    /// Generate an answer based on selected results
    func generateAnswerFromSelected() async {
        guard !selectedResults.isEmpty, !searchQuery.isEmpty else {
            await MainActor.run {
                self.errorMessage = "Please select at least one result and enter a query"
            }
            return
        }
        
        await MainActor.run {
            self.isSearching = true
            self.generatedAnswer = ""
        }
        
        do {
            // Use only selected results for context
            let context = selectedResults.map { result in
                "Source: \(result.sourceDocument)\n\(result.content)"
            }.joined(separator: "\n\n")
            
            let answer = try await openAIService.generateCompletion(
                systemPrompt: "Answer the user's question using ONLY the information provided in the context. If the answer isn't in the context, say you don't have enough information.",
                userMessage: searchQuery,
                context: context
            )
            
            await MainActor.run {
                self.generatedAnswer = answer
                self.isSearching = false
                
                self.logger.log(level: .success, message: "Answer generated from selected results", context: "Using \(selectedResults.count) results")
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to generate answer: \(error.localizedDescription)"
                self.isSearching = false
                
                self.logger.log(level: .error, message: "Failed to generate answer", context: error.localizedDescription)
            }
        }
    }
}
