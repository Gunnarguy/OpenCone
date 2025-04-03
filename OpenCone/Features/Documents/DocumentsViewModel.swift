import Foundation
import Combine
import UIKit

/// View model for document management and processing
class DocumentsViewModel: ObservableObject {
    // Services
    private let fileProcessorService: FileProcessorService
    private let textProcessorService: TextProcessorService
    private let embeddingService: EmbeddingService
    private let pineconeService: PineconeService
    private let logger = Logger.shared
    
    // Published properties for UI binding
    @Published var documents: [DocumentModel] = []
    @Published var isProcessing = false
    @Published var processingProgress: Float = 0
    @Published var selectedDocuments: Set<UUID> = []
    @Published var errorMessage: String? = nil
    @Published var pineconeIndexes: [String] = []
    @Published var namespaces: [String] = []
    @Published var selectedIndex: String? = nil
    @Published var selectedNamespace: String? = nil
    @Published var processingStats: ProcessingStats? = nil
    
    // Cancellables for managing subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    init(fileProcessorService: FileProcessorService, textProcessorService: TextProcessorService,
         embeddingService: EmbeddingService, pineconeService: PineconeService) {
        self.fileProcessorService = fileProcessorService
        self.textProcessorService = textProcessorService
        self.embeddingService = embeddingService
        self.pineconeService = pineconeService
    }
    
    /// Add a document to the list
    /// - Parameter url: URL of the document
    func addDocument(at url: URL) {
        // Check if document already exists
        if documents.contains(where: { $0.filePath == url }) {
            logger.log(level: .warning, message: "Document already exists", context: url.lastPathComponent)
            return
        }
        
        // Get file attributes
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            // Determine MIME type
            let mimeType: String
            switch url.pathExtension.lowercased() {
            case "pdf":
                mimeType = "application/pdf"
            case "txt":
                mimeType = "text/plain"
            case "md":
                mimeType = "text/markdown"
            case "png", "jpg", "jpeg":
                mimeType = "image/\(url.pathExtension.lowercased())"
            default:
                mimeType = "application/octet-stream"
            }
            
            // Create document model
            let document = DocumentModel(
                fileName: url.lastPathComponent,
                filePath: url,
                mimeType: mimeType,
                fileSize: fileSize,
                dateAdded: Date()
            )
            
            // Add to documents list
            self.documents.append(document)
            logger.log(level: .info, message: "Document added", context: document.fileName)
        } catch {
            logger.log(level: .error, message: "Failed to add document", context: error.localizedDescription)
        }
    }
    
    /// Remove selected documents
    func removeSelectedDocuments() {
        documents.removeAll(where: { selectedDocuments.contains($0.id) })
        selectedDocuments.removeAll()
        logger.log(level: .info, message: "Selected documents removed")
    }
    
    /// Toggle document selection
    /// - Parameter documentId: ID of the document to toggle
    func toggleDocumentSelection(_ documentId: UUID) {
        if selectedDocuments.contains(documentId) {
            selectedDocuments.remove(documentId)
        } else {
            selectedDocuments.insert(documentId)
        }
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
    
    /// Create a new namespace
    /// - Parameter name: Name of the new namespace
    func createNamespace(_ name: String) {
        // Pinecone doesn't have an explicit create namespace API
        // Namespaces are created implicitly when upserting vectors
        self.selectedNamespace = name
        self.namespaces.append(name)
        logger.log(level: .info, message: "Namespace created", context: name)
    }
    
    /// Process selected documents and index them in Pinecone
    func processSelectedDocuments() async {
        guard !selectedDocuments.isEmpty else {
            logger.log(level: .warning, message: "No documents selected")
            return
        }
        
        guard selectedIndex != nil else {
            await MainActor.run {
                self.errorMessage = "No Pinecone index selected"
                logger.log(level: .error, message: "No Pinecone index selected")
            }
            return
        }
        
        let documentsToProcess = documents.filter { selectedDocuments.contains($0.id) }
        
        await MainActor.run {
            self.isProcessing = true
            self.processingProgress = 0
            self.processingStats = ProcessingStats()
        }
        
        for (index, document) in documentsToProcess.enumerated() {
            await processDocument(document)
            
            // Update progress
            let progress = Float(index + 1) / Float(documentsToProcess.count)
            await MainActor.run {
                self.processingProgress = progress
            }
        }
        
        await MainActor.run {
            self.isProcessing = false
            logger.log(level: .success, message: "Processing completed", context: "Processed \(documentsToProcess.count) documents")
        }
    }
    
    /// Process a single document
    /// - Parameter document: The document to process
    private func processDocument(_ document: DocumentModel) async {
        logger.log(level: .info, message: "Starting to process document", context: document.fileName)
        
        // Initialize processing stats
        var processingStats = DocumentProcessingStats()
        processingStats.startTime = Date()
        
        do {
            // PHASE 1: Extract text from document
            let textExtractionStart = Date()
            let (text, mimeType) = try await fileProcessorService.processFile(at: document.filePath)
            let textExtractionEnd = Date()
            
            guard let documentText = text, let documentMimeType = mimeType else {
                await updateDocumentStatus(document, isProcessed: false, error: "Failed to extract text")
                logger.log(level: .error, message: "Failed to extract text", context: document.fileName)
                return
            }
            
            // Update text extraction stats
            processingStats.addPhase(
                phase: .textExtraction,
                start: textExtractionStart,
                end: textExtractionEnd
            )
            processingStats.extractedTextLength = documentText.count
            
            logger.log(level: .info, message: "Text extracted", context: "Document: \(document.fileName), Size: \(documentText.count) characters")
            
            // Create metadata
            let metadata = [
                "source": document.filePath.lastPathComponent,
                "mimeType": documentMimeType,
                "fileName": document.fileName
            ]
            
            // PHASE 2: Chunk the text
            let chunkingStart = Date()
            let (chunks, analytics) = textProcessorService.chunkText(
                text: documentText,
                metadata: metadata,
                mimeType: documentMimeType
            )
            let chunkingEnd = Date()
            
            // Update chunking stats
            processingStats.addPhase(
                phase: .chunking,
                start: chunkingStart,
                end: chunkingEnd
            )
            processingStats.totalTokens = analytics.totalTokens
            processingStats.avgTokensPerChunk = analytics.avgTokensPerChunk
            processingStats.chunkSizes = analytics.chunkSizes
            processingStats.tokenDistribution = analytics.tokenDistribution
            
            logger.log(level: .info, message: "Text chunked", context: "Document: \(document.fileName), Chunks: \(chunks.count)")
            
            // Update global stats
            await MainActor.run {
                self.processingStats?.totalDocuments += 1
                self.processingStats?.totalChunks += chunks.count
                self.processingStats?.totalTokens += analytics.totalTokens
            }
            
            // PHASE 3: Generate embeddings
            let embeddingStart = Date()
            let embeddings = try await embeddingService.generateEmbeddings(for: chunks)
            let embeddingEnd = Date()
            
            // Update embedding stats
            processingStats.addPhase(
                phase: .embeddingGeneration,
                start: embeddingStart,
                end: embeddingEnd
            )
            
            logger.log(level: .info, message: "Embeddings generated", context: "Document: \(document.fileName), Embeddings: \(embeddings.count)")
            
            // Prepare vectors for Pinecone
            let vectors = embeddingService.convertToPineconeVectors(from: embeddings)
            
            // PHASE 4: Batch upsert to Pinecone
            let upsertStart = Date()
            var totalUpserted = 0
            
            let batchSize = 100
            for i in stride(from: 0, to: vectors.count, by: batchSize) {
                let end = min(i + batchSize, vectors.count)
                let batch = Array(vectors[i..<end])
                
                logger.log(level: .info, message: "Upserting batch to Pinecone", context: "Batch: \(i/batchSize + 1), Size: \(batch.count)")
                
                let response = try await pineconeService.upsertVectors(batch, namespace: selectedNamespace)
                totalUpserted += response.upsertedCount
                
                logger.log(level: .info, message: "Batch upserted", context: "Upserted: \(response.upsertedCount)")
                
                // Update global stats
                await MainActor.run {
                    self.processingStats?.totalVectors += response.upsertedCount
                }
            }
            
            let upsertEnd = Date()
            
            // Update upsert stats
            processingStats.addPhase(
                phase: .vectorUpsert,
                start: upsertStart,
                end: upsertEnd
            )
            processingStats.vectorsUploaded = totalUpserted
            
            // Finalize processing stats
            processingStats.endTime = Date()
            
            // Update document status and stats
            await updateDocumentStatus(document, isProcessed: true, chunkCount: chunks.count)
            await updateDocumentStats(document, stats: processingStats)
            
            logger.log(level: .success, message: "Document processed successfully", context: document.fileName)
        } catch {
            // Record end time even for failures
            processingStats.endTime = Date()
            await updateDocumentStatus(document, isProcessed: false, error: error.localizedDescription)
            await updateDocumentStats(document, stats: processingStats)
            
            logger.log(level: .error, message: "Failed to process document", context: "\(document.fileName): \(error.localizedDescription)")
        }
    }
    
    /// Update the status of a document after processing
    /// - Parameters:
    ///   - document: The document to update
    ///   - isProcessed: Whether processing was successful
    ///   - error: Optional error message
    ///   - chunkCount: Number of chunks generated
    private func updateDocumentStatus(_ document: DocumentModel, isProcessed: Bool, error: String? = nil, chunkCount: Int = 0) async {
        await MainActor.run {
            if let index = self.documents.firstIndex(where: { $0.id == document.id }) {
                self.documents[index].isProcessed = isProcessed
                self.documents[index].processingError = error
                self.documents[index].chunkCount = chunkCount
            }
        }
    }
    
    /// Update document processing statistics
    /// - Parameters:
    ///   - document: The document to update
    ///   - stats: Processing statistics to store
    private func updateDocumentStats(_ document: DocumentModel, stats: DocumentProcessingStats) async {
        await MainActor.run {
            if let index = self.documents.firstIndex(where: { $0.id == document.id }) {
                self.documents[index].processingStats = stats
            }
        }
    }
    
    /// Statistics for document processing
    struct ProcessingStats {
        var totalDocuments = 0
        var totalChunks = 0
        var totalTokens = 0
        var totalVectors = 0
    }
}
