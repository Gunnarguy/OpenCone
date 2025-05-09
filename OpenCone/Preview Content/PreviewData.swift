import Foundation
import SwiftUI

#if DEBUG
    /// Provides sample data for SwiftUI previews.
    struct PreviewData {

        // MARK: - Sample Documents

        /// A collection of sample `DocumentModel` instances for previews.
        static let sampleDocuments: [DocumentModel] = [
            // Processed document
            DocumentModel(
                fileName: "Sample Report.pdf",
                filePath: URL(fileURLWithPath: "/path/to/Sample Report.pdf"),
                mimeType: "application/pdf",
                fileSize: 1_234_567,
                dateAdded: Date().addingTimeInterval(-86400),  // Added yesterday
                isProcessed: true,
                chunkCount: 42,
                processingStats: sampleDocumentStats  // Add sample stats
            ),
            // Document with processing error
            DocumentModel(
                fileName: "Corrupted Data.docx",
                filePath: URL(fileURLWithPath: "/path/to/Corrupted Data.docx"),
                mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                fileSize: 56_789,
                dateAdded: Date().addingTimeInterval(-172800),  // Added 2 days ago
                isProcessed: false,
                processingError: "Failed to extract text content."
            ),
            // Pending document (not yet processed)
            DocumentModel(
                fileName: "Presentation Slides.pptx",
                filePath: URL(fileURLWithPath: "/path/to/Presentation Slides.pptx"),
                mimeType:
                    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
                fileSize: 3_456_789,
                dateAdded: Date()  // Added today
            ),
            // Another processed document
            DocumentModel(
                fileName: "Meeting Notes.txt",
                filePath: URL(fileURLWithPath: "/path/to/Meeting Notes.txt"),
                mimeType: "text/plain",
                fileSize: 12_345,
                dateAdded: Date().addingTimeInterval(-604800),  // Added a week ago
                isProcessed: true,
                chunkCount: 5
            ),
        ]

        // MARK: - Sample Document Processing Stats

        /// Sample `DocumentProcessingStats` for previews.
        static let sampleDocumentStats: DocumentProcessingStats = {
            var stats = DocumentProcessingStats()
            let baseTime = Date()

            // Add phase timings
            stats.addPhase(
                phase: .textExtraction, start: baseTime, end: baseTime.addingTimeInterval(5.2))
            stats.addPhase(
                phase: .chunking, start: baseTime.addingTimeInterval(5.3),
                end: baseTime.addingTimeInterval(8.1))
            // Corrected enum case name
            stats.addPhase(
                phase: .embeddingGeneration, start: baseTime.addingTimeInterval(8.2),
                end: baseTime.addingTimeInterval(25.5))
            // Corrected enum case name
            stats.addPhase(
                phase: .vectorUpsert, start: baseTime.addingTimeInterval(25.6),
                end: baseTime.addingTimeInterval(30.0))

            // Add other stats
            stats.extractedTextLength = 150_000
            stats.totalTokens = 35_000
            stats.vectorsUploaded = 42  // Use vectorsUploaded instead of totalVectors
            stats.chunkSizes = (1...42).map { _ in Int.random(in: 500...1500) }
            stats.tokenDistribution = (1...42).map { _ in Int.random(in: 600...1000) }

            return stats
        }()

        // MARK: - Sample ViewModels

        /// Sample `SettingsViewModel` for previews.
        static var sampleSettingsViewModel: SettingsViewModel {
            let viewModel = SettingsViewModel()
            // Pre-populate with placeholder keys for visual representation
            viewModel.openAIAPIKey = "sk-••••••••••••••••••••••••••••••••"
            viewModel.pineconeAPIKey = "••••••••••••••••••••••••••••••••"
            viewModel.pineconeProjectId = "••••••••••••••••••••"
            // Set some default processing values
            viewModel.defaultChunkSize = 1000
            viewModel.defaultChunkOverlap = 200
            // Set default models
            viewModel.embeddingModel = "text-embedding-3-small"
            viewModel.completionModel = "gpt-4o-mini"
            return viewModel
        }

        /// Sample `DocumentsViewModel` for previews.
        static var sampleDocumentsViewModel: DocumentsViewModel {
            // Note: Creating real services might be complex for previews.
            // Consider using mock services if needed for more interactive previews.
            let fileProcessor = FileProcessorService()
            let textProcessor = TextProcessorService()
            // Provide dummy API key for OpenAI service used by EmbeddingService
            let openAI = OpenAIService(apiKey: "dummy-openai-key")
            let embedding = EmbeddingService(openAIService: openAI)  // Provide OpenAIService instance
            // Provide dummy API key and project ID for Pinecone service
            let pinecone = PineconeService(
                apiKey: "dummy-pinecone-key", projectId: "dummy-project-id")  // Provide API key and project ID

            let viewModel = DocumentsViewModel(
                fileProcessorService: fileProcessor,
                textProcessorService: textProcessor,
                embeddingService: embedding,
                pineconeService: pinecone
            )

            // Populate with sample data
            viewModel.documents = sampleDocuments
            viewModel.selectedDocuments = [sampleDocuments[0].id]  // Select the first document
            viewModel.pineconeIndexes = ["dev-index", "prod-index", "test-index"]
            viewModel.selectedIndex = "dev-index"
            viewModel.namespaces = ["project-a", "project-b", "general"]
            viewModel.selectedNamespace = "project-a"

            // Simulate processing state if needed
            // viewModel.isProcessing = true
            // viewModel.processingProgress = 0.65
            // viewModel.currentProcessingStatus = "Generating embeddings (3/5)..."
            // viewModel.processingStats = sampleOverallStats

            return viewModel
        }

        /// Sample `ProcessingViewModel` for previews.
        @MainActor  // Mark the static property as @MainActor to allow calling the MainActor-isolated init
        static var sampleProcessingViewModel: ProcessingViewModel {
            let logger = Logger.shared  // Use the shared logger
            // Add sample logs directly to the shared logger for the preview
            logger.clearLogs()  // Clear previous logs first
            logger.log(level: .info, message: "Application started.", context: "App Lifecycle")
            logger.log(level: .debug, message: "Loading settings from UserDefaults.")
            logger.log(
                level: .warning,
                message: "API Key for OpenAI not found. Please add it in Settings.",
                context: "Configuration")
            logger.log(
                level: .info, message: "Processing document: Sample Report.pdf",
                context: "Document Processing")
            logger.log(
                level: .success, message: "Document 'Sample Report.pdf' processed successfully.",
                context: "Document Processing")
            logger.log(
                level: .error, message: "Failed to extract text from 'Corrupted Data.docx'.",
                context: "FileProcessorService")
            logger.log(level: .info, message: "User initiated search.", context: "Search Feature")

            let viewModel = ProcessingViewModel(logger: logger)
            return viewModel
        }

        // MARK: - Sample Overall Processing Stats (Example)

        /// Sample overall `ProcessingStats` for the DocumentsViewModel preview.
        static let sampleOverallStats: DocumentsViewModel.ProcessingStats = {
            var stats = DocumentsViewModel.ProcessingStats()
            stats.totalDocuments = 5
            stats.totalVectors = 128
            stats.totalTokens = 95000
            // Add timing if needed
            return stats
        }()

        // MARK: - Sample Search Results

        /// Sample `SearchResultModel` instances for previews.
        static let sampleSearchResults: [SearchResultModel] = [
            SearchResultModel(
                content:
                    "The primary goal of the project is to enhance user engagement through personalized recommendations.",
                sourceDocument: "Project Proposal.pdf",
                score: 0.92,
                metadata: ["page": "3", "chunk_index": "5"]
            ),
            SearchResultModel(
                content:
                    "Recommendations are generated based on user interaction history and content similarity.",
                sourceDocument: "Technical Spec.docx",
                score: 0.85,
                metadata: ["section": "4.2", "chunk_index": "12"]
            ),
            SearchResultModel(
                content:
                    "User engagement metrics include click-through rate and time spent on recommended items.",
                sourceDocument: "Project Proposal.pdf",
                score: 0.71,
                metadata: ["page": "8", "chunk_index": "21"]
            ),
            SearchResultModel(
                content:
                    "Future work involves exploring collaborative filtering techniques for improved accuracy.",
                sourceDocument: "Roadmap Q3.pptx",
                score: 0.65,
                metadata: ["slide": "15", "chunk_index": "3"]
            ),
        ]

        /// Sample `SearchViewModel` for previews.
        static var sampleSearchViewModel: SearchViewModel {
            // Again, consider mocks for complex service interactions
            // Provide dummy API key and project ID
            let pinecone = PineconeService(
                apiKey: "dummy-pinecone-key", projectId: "dummy-project-id")
            // Provide dummy API key
            let openAI = OpenAIService(apiKey: "dummy-openai-key")
            // Provide OpenAIService instance
            let embedding = EmbeddingService(openAIService: openAI)

            let viewModel = SearchViewModel(
                pineconeService: pinecone,
                openAIService: openAI,
                embeddingService: embedding
            )

            // Populate with sample data
            viewModel.searchQuery = "user engagement recommendations"
            viewModel.searchResults = sampleSearchResults
            viewModel.selectedResults = sampleSearchResults.filter {
                $0.id == sampleSearchResults[1].id
            }
            viewModel.generatedAnswer =
                "The system enhances user engagement by providing personalized recommendations based on interaction history and content similarity. Key metrics include CTR and time spent."
            viewModel.isSearching = false
            viewModel.pineconeIndexes = ["dev-index", "prod-index"]
            viewModel.selectedIndex = "dev-index"
            viewModel.namespaces = ["project-a", "general"]
            viewModel.selectedNamespace = "project-a"

            return viewModel
        }
    }
#endif

// MARK: - Add Previews for Helper Structs if needed

#if DEBUG
    // Define formattedDuration locally for the preview
    private func formattedDuration(_ seconds: TimeInterval) -> String {
        if seconds < 0.001 {
            return "<1ms"
        } else if seconds < 1 {
            return "\(Int(seconds * 1000))ms"
        } else if seconds < 60 {
            return String(format: "%.2fs", seconds)
        } else {
            let minutes = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return "\(minutes)m \(secs)s"
        }
    }

    // Example preview for DocumentProcessingStats (if useful)
    #Preview("Document Stats") {
        // You might need a simple view to display these stats
        VStack(alignment: .leading) {
            Text("Sample Document Stats").font(.headline)
            Text("Text Length: \(PreviewData.sampleDocumentStats.extractedTextLength)")
            // Corrected property access
            Text("Total Chunks: \(PreviewData.sampleDocumentStats.chunkSizes.count)")
            Text("Total Tokens: \(PreviewData.sampleDocumentStats.totalTokens)")
            // Corrected property access
            Text("Total Vectors: \(PreviewData.sampleDocumentStats.vectorsUploaded)")
            // Use locally defined formattedDuration
            Text(
                "Total Duration: \(formattedDuration(PreviewData.sampleDocumentStats.totalProcessingTime))"
            )
        }
        .padding()
        .withTheme()
    }
#endif
