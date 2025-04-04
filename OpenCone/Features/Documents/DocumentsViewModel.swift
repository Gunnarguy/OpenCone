import Foundation
import Combine
import UIKit
import SwiftUI
import UniformTypeIdentifiers // Added import for UTType

/// View model for document management and processing
/// Handles loading, selecting, and processing documents for vector embeddings
class DocumentsViewModel: ObservableObject {
    // MARK: - Dependencies
    
    /// Service for processing document files and extracting text
    private let fileProcessorService: FileProcessorService
    
    /// Service for chunking and processing text
    private let textProcessorService: TextProcessorService
    
    /// Service for generating vector embeddings
    private let embeddingService: EmbeddingService
    
    /// Service for interacting with Pinecone vector database
    private let pineconeService: PineconeService
    
    /// Shared logger instance
    private let logger = Logger.shared
    
    // MARK: - Published Properties
    
    /// List of all documents added to the system
    @Published var documents: [DocumentModel] = []
    
    /// Whether document processing is currently in progress
    @Published var isProcessing = false
    
    /// Progress value between 0.0 and 1.0 for document processing
    @Published var processingProgress: Float = 0
    
    /// Set of currently selected document IDs
    @Published var selectedDocuments: Set<UUID> = []
    
    /// Error message to display in the UI
    @Published var errorMessage: String? = nil
    
    /// Available Pinecone indexes
    @Published var pineconeIndexes: [String] = []
    
    /// Available namespaces in the current index
    @Published var namespaces: [String] = []
    
    /// Currently selected Pinecone index
    @Published var selectedIndex: String? = nil
    
    /// Currently selected namespace
    @Published var selectedNamespace: String? = nil
    
    /// Statistics for the current processing operation
    @Published var processingStats: ProcessingStats? = nil
    
    /// Current status message during processing
    @Published var currentProcessingStatus: String? = nil

    /// Flag indicating if index/namespace operations are in progress
    @Published var isLoadingIndexes = false // Added for index creation loading state

    /// Flag to control the visibility of the create index dialog
    @Published var showingCreateIndexDialog = false // Added for index creation dialog

    /// Holds the name for the new index being created
    @Published var newIndexName = "" // Added for index creation dialog
    
    /// Tracks the granular progress (0.0 to 1.0) for each document being processed concurrently
    @Published private var documentProgress: [UUID: Float] = [:]
    
    /// Cancellables for managing Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants for Progress Calculation
    private let phaseWeightExtraction: Float = 0.10
    private let phaseWeightChunking: Float = 0.10
    private let phaseWeightEmbedding: Float = 0.50
    private let phaseWeightUploading: Float = 0.30
    
    // MARK: - Initialization
    
    /// Initialize with required services
    /// - Parameters:
    ///   - fileProcessorService: Service for processing document files
    ///   - textProcessorService: Service for text processing and chunking
    ///   - embeddingService: Service for generating embeddings
    ///   - pineconeService: Service for Pinecone vector database operations
    init(fileProcessorService: FileProcessorService, textProcessorService: TextProcessorService,
         embeddingService: EmbeddingService, pineconeService: PineconeService) {
        self.fileProcessorService = fileProcessorService
        self.textProcessorService = textProcessorService
        self.embeddingService = embeddingService
        self.pineconeService = pineconeService
    }
    
    // MARK: - Document Management
    
    /// Add a document to the list
    /// - Parameter url: URL of the document to add
    func addDocument(at url: URL) {
        // Check if document already exists
        if documents.contains(where: { $0.filePath == url }) {
            logger.log(level: .warning, message: "Document already exists", context: url.lastPathComponent)
            return
        }
        
        do {
            // Ensure URL is accessible and secure bookmarked if necessary
            // Ensure URL is accessible and create a persistent security bookmark
            if !url.startAccessingSecurityScopedResource() {
                logger.log(level: .warning, message: "Failed to access security-scoped resource", context: url.lastPathComponent)
                // Consider throwing an error or returning if access is critical here
            }
            
            // Create a security-scoped bookmark
            let bookmarkData = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            
            // Stop accessing the resource for now
            url.stopAccessingSecurityScopedResource()
            
            // Get file attributes (access might be needed again if path is used directly)
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            // Check file size limitations
            let maxFileSize: Int64 = 100 * 1024 * 1024 // 100MB
            if fileSize > maxFileSize {
                logger.log(level: .warning, message: "File exceeds size limit (100MB)", context: url.lastPathComponent)
                errorMessage = "File \(url.lastPathComponent) is too large (max 100MB)"
                return
            }
            
            // Create document model with determined MIME type and bookmark
            let document = DocumentModel(
                fileName: url.lastPathComponent,
                filePath: url, // Keep original URL for reference, but use bookmark for access
                securityBookmark: bookmarkData, // Store the bookmark
                mimeType: determineMimeType(for: url),
                fileSize: fileSize,
                dateAdded: Date()
            )
            
            // Add to documents list
            DispatchQueue.main.async {
                self.documents.append(document)
                self.logger.log(level: .info, message: "Document added", context: document.fileName)
            }
        } catch {
            logger.log(level: .error, message: "Failed to add document", context: "\(url.lastPathComponent): \(error.localizedDescription)")
            errorMessage = "Failed to add \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }
    
    /// Determine MIME type based on file extension and UTI
    /// - Parameter url: File URL
    /// - Returns: MIME type string
    private func determineMimeType(for url: URL) -> String {
        // Try to get UTType for more accurate MIME type detection
        if #available(iOS 14.0, *) {
            // Use UTType if available (requires import UniformTypeIdentifiers)
            if let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType,
               let mimeType = UTType(contentType.identifier)?.preferredMIMEType {
                return mimeType
            }
        }
        
        // Fallback to extension-based detection
        switch url.pathExtension.lowercased() {
        case "pdf":
            return "application/pdf"
        case "txt":
            return "text/plain"
        case "md", "markdown":
            return "text/markdown"
        case "rtf":
            return "application/rtf"
        case "html", "htm":
            return "text/html"
        case "csv":
            return "text/csv"
        case "json":
            return "application/json"
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "doc":
            return "application/msword"
        default:
            return "application/octet-stream"
        }
    }
    
    /// Remove all selected documents from the list
    func removeSelectedDocuments() {
        guard !isProcessing else {
            logger.log(level: .warning, message: "Cannot remove documents while processing")
            return
        }
        
        DispatchQueue.main.async {
            self.documents.removeAll(where: { self.selectedDocuments.contains($0.id) })
            self.selectedDocuments.removeAll()
            self.logger.log(level: .info, message: "Selected documents removed")
        }
    }
    
    /// Toggle selection status for a document
    /// - Parameter documentId: ID of the document to toggle
    func toggleDocumentSelection(_ documentId: UUID) {
        DispatchQueue.main.async {
            if self.selectedDocuments.contains(documentId) {
                self.selectedDocuments.remove(documentId)
            } else {
                self.selectedDocuments.insert(documentId)
            }
        }
    }
    
    // MARK: - Pinecone Configuration
    
    /// Load available Pinecone indexes
    func loadIndexes() async {
        do {
            let indexes = try await pineconeService.listIndexes()
            await MainActor.run {
                self.pineconeIndexes = indexes
                self.errorMessage = nil
                
                // Auto-select first index if none selected
                if !indexes.isEmpty && self.selectedIndex == nil {
                    self.selectedIndex = indexes[0]
                    // Auto-load namespaces for the selected index
                    Task {
                        await self.setIndex(indexes[0])
                    }
                }
            }
            logger.log(level: .info, message: "Loaded \(indexes.count) Pinecone indexes")
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
                self.errorMessage = nil
            }
            logger.log(level: .info, message: "Set current index to: \(indexName)")
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
                self.errorMessage = nil
                
                // Preserve current selection if it's still valid
                if self.selectedNamespace == nil || !namespaces.contains(self.selectedNamespace!) {
                    self.selectedNamespace = namespaces.first
                }
            }
            logger.log(level: .info, message: "Loaded \(namespaces.count) namespaces")
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
        DispatchQueue.main.async {
            self.selectedNamespace = namespace
            self.logger.log(level: .info, message: "Set namespace to: \(namespace ?? "default")")
        }
    }
    
    /// Create a new namespace
    /// - Parameter name: Name of the new namespace
    func createNamespace(_ name: String) {
        guard !name.isEmpty else { return }
        guard !namespaces.contains(name) else {
            logger.log(level: .warning, message: "Namespace already exists", context: name)
            return
        }
        
        DispatchQueue.main.async {
            self.selectedNamespace = name
            self.namespaces.append(name)
            self.logger.log(level: .info, message: "Namespace created", context: name)
        }
    }

    /// Create a new Pinecone index
    func createIndex() async {
        guard !newIndexName.isEmpty else {
            logger.log(level: .warning, message: "Index name cannot be empty")
            return
        }

        // Validate index name format (Pinecone requirements: lowercase alphanumeric and hyphens)
        let validNamePattern = "^[a-z0-9]+(-[a-z0-9]+)*$"
        if newIndexName.range(of: validNamePattern, options: .regularExpression) == nil {
            await MainActor.run {
                self.errorMessage = "Invalid index name. Use lowercase letters, numbers, and hyphens."
                self.logger.log(level: .error, message: "Invalid index name format", context: newIndexName)
            }
            return
        }

        await MainActor.run {
            self.isLoadingIndexes = true
            self.errorMessage = nil // Clear previous errors
        }

        do {
            logger.log(level: .info, message: "Attempting to create index", context: newIndexName)
            _ = try await pineconeService.createIndex(name: newIndexName, dimension: Configuration.embeddingDimension)
            logger.log(level: .info, message: "Index creation initiated. Waiting for index to become ready...", context: newIndexName)

            // Wait for the index to be ready before refreshing the list
            let isReady = try await pineconeService.waitForIndexReady(name: newIndexName, timeout: 120) // Wait up to 2 minutes

            if isReady {
                logger.log(level: .success, message: "Index created and ready", context: newIndexName)
                // Refresh the index list and select the new one
                await loadIndexes()
                await MainActor.run {
                    // Select the newly created index
                    if self.pineconeIndexes.contains(newIndexName) {
                        self.selectedIndex = newIndexName
                        // Trigger namespace loading for the new index
                        Task { await self.setIndex(newIndexName) }
                    }
                }
            } else {
                logger.log(level: .warning, message: "Index creation timed out. It might become ready later.", context: newIndexName)
                await MainActor.run {
                    self.errorMessage = "Index '\(newIndexName)' creation timed out. Please refresh later."
                }
                // Still refresh the list, it might appear eventually
                await loadIndexes()
            }

        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to create index '\(newIndexName)': \(error.localizedDescription)"
                self.logger.log(level: .error, message: "Failed to create index", context: "\(newIndexName): \(error.localizedDescription)")
            }
        }

        await MainActor.run {
            self.isLoadingIndexes = false
            self.showingCreateIndexDialog = false // Close dialog regardless of outcome
            self.newIndexName = "" // Clear the name field
        }
    }
    
    // MARK: - Document Processing
    
    /// Process selected documents and index them in Pinecone
    func processSelectedDocuments() async {
        guard !selectedDocuments.isEmpty else {
            logger.log(level: .warning, message: "No documents selected")
            return
        }
        
        guard selectedIndex != nil else {
            await MainActor.run {
                self.errorMessage = "No Pinecone index selected"
                self.logger.log(level: .error, message: "No Pinecone index selected")
            }
            return
        }
        
        // Get documents that need processing
        let documentsToProcess = documents.filter { selectedDocuments.contains($0.id) }
        
        // Initialize processing state
        await MainActor.run {
            self.isProcessing = true
            self.processingProgress = 0
            self.processingStats = ProcessingStats()
            self.currentProcessingStatus = "Starting..." // Initial status
            self.documentProgress = Dictionary(uniqueKeysWithValues: documentsToProcess.map { ($0.id, 0.0) }) // Initialize progress for all
            self.errorMessage = nil
        }
        
        // Process documents concurrently with a limit
        await withTaskGroup(of: Void.self) { group in
            for document in documentsToProcess {
                group.addTask {
                    await self.processDocument(document)
                }
            }
            // No need to manage concurrency explicitly here, TaskGroup handles it.
            // We update progress within processDocument now.
        }
        
        // Mark processing as complete
        await MainActor.run {
            self.isProcessing = false
            self.currentProcessingStatus = nil // Clear status on completion
            self.processingProgress = 1.0 // Ensure it reaches 100%
            self.documentProgress = [:] // Clear individual progress
            self.logger.log(level: .success, message: "Processing completed", context: "Processed \(documentsToProcess.count) documents")
        }
    }
    
    /// Process a single document through the RAG pipeline
    /// - Parameter document: The document to process
    private func processDocument(_ document: DocumentModel) async {
        logger.log(level: .info, message: "Starting to process document", context: document.fileName)
        
        // Initialize processing stats
        var processingStats = DocumentProcessingStats()
        processingStats.startTime = Date()
        
        var currentDocumentProgress: Float = 0.0
        
        do {
            // PHASE 1: Extract text from document (Weight: phaseWeightExtraction)
            await MainActor.run { self.currentProcessingStatus = "Extracting text (\(document.fileName))..." }
            let (documentText, documentMimeType) = try await extractText(from: document, stats: &processingStats)
            currentDocumentProgress += phaseWeightExtraction
            await updateOverallProgress(for: document.id, progress: currentDocumentProgress)
            
            // PHASE 2: Chunk the text (Weight: phaseWeightChunking)
            await MainActor.run { self.currentProcessingStatus = "Chunking text (\(document.fileName))..." }
            let (chunks, _) = chunkText(document, text: documentText, mimeType: documentMimeType, stats: &processingStats)
            currentDocumentProgress += phaseWeightChunking
            await updateOverallProgress(for: document.id, progress: currentDocumentProgress)
            
            // Skip processing if no chunks were generated
            guard !chunks.isEmpty else {
                throw ProcessingError.noChunksGenerated
            }
            
            // PHASE 3: Generate embeddings (Weight: phaseWeightEmbedding)
            await MainActor.run { self.currentProcessingStatus = "Generating embeddings (\(document.fileName))..." }
            let embeddingStart = Date() // Record start time for stats
            let embeddings = try await embeddingService.generateEmbeddings(for: chunks) { batchIndex, totalBatches in
                // Calculate progress within this phase based on batch completion
                let batchProgress = totalBatches > 0 ? Float(batchIndex + 1) / Float(totalBatches) : 1.0
                let phaseProgress = self.phaseWeightEmbedding * batchProgress
                await self.updateOverallProgress(for: document.id, progress: currentDocumentProgress + phaseProgress)
            }
            let embeddingEnd = Date() // Record end time for stats
            // Update stats for this phase
            processingStats.addPhase(phase: .embeddingGeneration, start: embeddingStart, end: embeddingEnd)
            // Ensure the full weight is added after the phase completes
            currentDocumentProgress += phaseWeightEmbedding
            await updateOverallProgress(for: document.id, progress: currentDocumentProgress)
            
            // Skip processing if no embeddings were generated
            guard !embeddings.isEmpty else {
                throw ProcessingError.noEmbeddingsGenerated
            }
            
            // PHASE 4: Upsert vectors to Pinecone (Weight: phaseWeightUploading)
            await MainActor.run { self.currentProcessingStatus = "Uploading vectors (\(document.fileName))..." }
            let upsertStart = Date() // Record start time for stats
            let vectorsToUpsert = embeddingService.convertToPineconeVectors(from: embeddings)
            let upsertResponse = try await pineconeService.upsertVectors(vectorsToUpsert, namespace: selectedNamespace) { batchIndex, totalBatches in
                 // Calculate progress within this phase based on batch completion
                let batchProgress = totalBatches > 0 ? Float(batchIndex + 1) / Float(totalBatches) : 1.0
                let phaseProgress = self.phaseWeightUploading * batchProgress
                await self.updateOverallProgress(for: document.id, progress: currentDocumentProgress + phaseProgress)
            }
            let upsertEnd = Date() // Record end time for stats
            // Update stats for this phase
            processingStats.addPhase(phase: .vectorUpsert, start: upsertStart, end: upsertEnd)
            processingStats.vectorsUploaded = upsertResponse.upsertedCount // Save actual count
             // Ensure the full weight is added after the phase completes
            currentDocumentProgress += phaseWeightUploading
            await updateOverallProgress(for: document.id, progress: 1.0) // Ensure it reaches 100% for this doc
            
            // Finalize processing stats
            processingStats.endTime = Date()
            
            // Update document status and stats
            await updateDocumentStatus(document, isProcessed: true, chunkCount: chunks.count)
            await updateDocumentStats(document, stats: processingStats)
            
            logger.log(level: .success, message: "Document processed successfully", context: document.fileName)
            
        } catch {
            // Mark progress as complete (even on failure) to avoid stalling average
            await updateOverallProgress(for: document.id, progress: 1.0)
            // Record end time even for failures
            processingStats.endTime = Date()
            
            // Format the error message
            let errorMessage: String
            if let processingError = error as? ProcessingError {
                errorMessage = processingError.errorDescription ?? error.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
            
            // Update document status to failure
            await updateDocumentStatus(document, isProcessed: false, error: errorMessage)
            await updateDocumentStats(document, stats: processingStats)
            
            logger.log(level: .error, message: "Failed to process document", context: "\(document.fileName): \(errorMessage)")
        }
    }
    
    /// Extract text from a document file
    /// - Parameters:
    ///   - document: Document to process
    ///   - stats: Processing stats to update
    /// - Returns: Tuple with extracted text and MIME type
    /// - Throws: Error if text extraction fails
    private func extractText(from document: DocumentModel, stats: inout DocumentProcessingStats) async throws -> (text: String, mimeType: String) {
        let textExtractionStart = Date()
        
        // Use the stored bookmark to regain access
        guard let bookmarkData = document.securityBookmark else {
            logger.log(level: .error, message: "No security bookmark available", context: document.fileName)
            throw ProcessingError.securityAccessDenied
        }
        
        var isStale = false
        var resolvedURL: URL
        
        do {
            // Resolve the bookmark to get a fresh URL. For iOS, resolve without .withSecurityScope
            // and then explicitly start access.
            resolvedURL = try URL(resolvingBookmarkData: bookmarkData, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                logger.log(level: .warning, message: "Security bookmark is stale, access may fail", context: document.fileName)
                // Consider attempting to create a new bookmark here if needed
            }
            
            if !resolvedURL.startAccessingSecurityScopedResource() {
                logger.log(level: .error, message: "Failed to access security-scoped resource despite bookmark", context: document.fileName)
                throw ProcessingError.securityAccessDenied
            }
        } catch {
            logger.log(level: .error, message: "Failed to resolve security bookmark", context: "\(document.fileName): \(error.localizedDescription)")
            throw ProcessingError.securityAccessDenied
        }
        
        // Use the resolved URL instead of the stored filePath
        defer { resolvedURL.stopAccessingSecurityScopedResource() }
        
        // Call the file processor service with the resolved URL
        let (text, mimeType) = try await fileProcessorService.processFile(at: resolvedURL)
        let textExtractionEnd = Date()
        
        guard let documentText = text, let documentMimeType = mimeType, !documentText.isEmpty else {
                throw ProcessingError.textExtractionFailed
            }
            
            // Update text extraction stats
            stats.addPhase(
                phase: .textExtraction,
                start: textExtractionStart,
                end: textExtractionEnd
            )
            stats.extractedTextLength = documentText.count
            
            logger.log(level: .info, message: "Text extracted", context: "Document: \(document.fileName), Size: \(documentText.count) characters")
            
            return (documentText, documentMimeType)
        // } // Original closing brace for autoreleasepool
    }
    
    /// Chunk text into semantic units
    /// - Parameters:
    ///   - document: Document being processed
    ///   - text: Text to chunk
    ///   - mimeType: MIME type of the document
    ///   - stats: Processing stats to update
    /// - Returns: Tuple with chunks and analytics
    // Removed async as the function body doesn't contain await
    private func chunkText(_ document: DocumentModel, text: String, mimeType: String, stats: inout DocumentProcessingStats) -> (chunks: [ChunkModel], analytics: ChunkAnalytics) {
        // Removed await from autoreleasepool call
        return autoreleasepool {
            let chunkingStart = Date()
            
            // Create metadata
            let metadata = [
                "source": document.filePath.lastPathComponent,
                "mimeType": mimeType,
                "fileName": document.fileName,
                "fileSize": String(document.fileSize),
                "dateProcessed": ISO8601DateFormatter().string(from: Date())
            ]
            
            // Perform text chunking
            let (chunks, analytics) = textProcessorService.chunkText(
                text: text,
                metadata: metadata,
                mimeType: mimeType
            )
            let chunkingEnd = Date()
            
            // Update chunking stats
            stats.addPhase(
                phase: .chunking,
                start: chunkingStart,
                end: chunkingEnd
            )
            stats.totalTokens = analytics.totalTokens
            stats.avgTokensPerChunk = analytics.avgTokensPerChunk
            stats.chunkSizes = analytics.chunkSizes
            stats.tokenDistribution = analytics.tokenDistribution
            
            logger.log(level: .info, message: "Text chunked", context: "Document: \(document.fileName), Chunks: \(chunks.count)")
            
            // Update global stats
            Task { @MainActor in
                self.processingStats?.totalDocuments += 1
                self.processingStats?.totalChunks += chunks.count
                self.processingStats?.totalTokens += analytics.totalTokens
            }
            
            return (chunks, analytics)
        }
    }
    
    /// Generate embeddings for text chunks
    /// - Parameters:
    ///   - document: Document being processed
    ///   - chunks: Text chunks to embed
    ///   - stats: Processing stats to update
    /// - Returns: Generated embeddings
    /// - Throws: Error if embedding generation fails
    // Note: Removed the separate 'WithProgress' helper methods as the main service calls now handle the callback directly.
    
    /// Update the status of a document after processing
    /// - Parameters:
    ///   - document: The document to update
    //     var totalUpserted = 0
        
    //     let batchSize = 100 // Pinecone batch size
    //     let totalBatches = (vectors.count + batchSize - 1) / batchSize
        
    //     // Report initial progress
    //     // if totalBatches > 0 { await progressCallback(0.0) } // Callback handled by caller now
        
    //     for i in stride(from: 0, to: vectors.count, by: batchSize) {
    //         let end = min(i + batchSize, vectors.count)
    //         let batch = Array(vectors[i..<end])
    //         let batchNumber = i / batchSize + 1
            
    //         logger.log(level: .info, message: "Upserting batch to Pinecone", context: "Batch: \(batchNumber)/\(totalBatches), Size: \(batch.count)")
            
    //         do {
    //             // This call internally handles retries but not batch progress reporting back
    //             let response = try await pineconeService.upsertVectors(batch, namespace: selectedNamespace) // Removed callback here
    //             totalUpserted += response.upsertedCount
                
    //             logger.log(level: .info, message: "Batch upserted", context: "Upserted: \(response.upsertedCount)")
                
    //             // Report progress after each batch completes
    //             // let batchProgress = Float(batchNumber) / Float(totalBatches) // Callback handled by caller now
    //             // await progressCallback(batchProgress) // Callback handled by caller now
                
    //             // Update global stats
    //                 await MainActor.run {
    //                     self.processingStats?.totalVectors += response.upsertedCount
    //                 }
    //             } catch {
    //                 logger.log(level: .error, message: "Upsert failed for batch \(batchNumber)", context: error.localizedDescription)
    //                 throw ProcessingError.upsertFailed(underlying: error)
    //             }
                
    //             // Add a small delay between batches to avoid rate limiting
    //             if i + batchSize < vectors.count {
    //                 try await Task.sleep(nanoseconds: 250_000_000) // 250ms
    //             }
    //         // } // Original closing brace for autoreleasepool
    //     }
        
    //     let upsertEnd = Date()
        
    //     // Update upsert stats
    //     stats.addPhase(
    //         phase: .vectorUpsert,
    //         start: upsertStart,
    //         end: upsertEnd
    //     )
    //     stats.vectorsUploaded = totalUpserted
    // }
    
    /// Update the status of a document after processing
    /// - Parameters:
    ///   - document: The document to update
    ///   - isProcessed: Whether processing was successful
    ///   - error: Optional error message
    ///   - chunkCount: Number of chunks generated
    private func updateDocumentStatus(_ document: DocumentModel, isProcessed: Bool, error: String? = nil, chunkCount: Int = 0) async {
        await MainActor.run {
            if let index = self.documents.firstIndex(where: { $0.id == document.id }) {
                // Create a new copy of the document with updated status
                var updatedDocument = self.documents[index]
                updatedDocument.isProcessed = isProcessed
                updatedDocument.processingError = error
                updatedDocument.chunkCount = chunkCount
                
                // Replace the old document with the updated copy in the array
                self.documents[index] = updatedDocument
            }
        }
    }
    
    /// Recalculates and updates the overall processing progress based on individual document progress.
    @MainActor
    private func updateOverallProgress(for documentId: UUID, progress: Float) {
        // Update the progress for the specific document
        documentProgress[documentId] = min(max(progress, 0.0), 1.0) // Clamp between 0 and 1
        
        // Calculate the average progress across all currently processing documents
        let totalProgress = documentProgress.values.reduce(0, +)
        let averageProgress = documentProgress.isEmpty ? 0 : totalProgress / Float(documentProgress.count)
        
        // Update the main progress property
        self.processingProgress = averageProgress
    }
    
    /// Update document processing statistics (remains unchanged)
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
    
    // MARK: - Helper Methods
    
    /// Checks if the document is already processed
    /// - Parameter documentId: ID of the document to check
    /// - Returns: True if the document is processed
    func isDocumentProcessed(documentId: UUID) -> Bool {
        return documents.first(where: { $0.id == documentId })?.isProcessed ?? false
    }
    
    /// Get the total size of all selected documents
    /// - Returns: Total size in bytes
    func getTotalSelectedSize() -> Int64 {
        return documents
            .filter { selectedDocuments.contains($0.id) }
            .reduce(0) { $0 + $1.fileSize }
    }
    
    // MARK: - Models
    
    /// Custom errors for document processing
    enum ProcessingError: Error, LocalizedError {
        case textExtractionFailed
        case chunkingFailed
        case securityAccessDenied // Add this new error type
        case embeddingFailed(underlying: Error)
        case embeddingCountMismatch(expected: Int, got: Int)
        case upsertFailed(underlying: Error)
        case noChunksGenerated
        case noEmbeddingsGenerated
        case invalidIndex
        case invalidNamespace
        case documentSizeTooLarge(size: Int64, maxSize: Int64)
        
        var errorDescription: String? {
            switch self {
            case .textExtractionFailed:
                return "Failed to extract text from document"
            case .chunkingFailed:
                return "Failed to chunk document text"
            case .securityAccessDenied:
                return "Security access to the document was denied. You may need to re-add the document."
            case .embeddingFailed(let error):
                return "Failed to generate embeddings: \(error.localizedDescription)"
            case .embeddingCountMismatch(let expected, let got):
                return "Embedding count mismatch: expected \(expected), got \(got)"
            case .upsertFailed(let error):
                return "Failed to upsert vectors: \(error.localizedDescription)"
            case .noChunksGenerated:
                return "No text chunks were generated"
            case .noEmbeddingsGenerated:
                return "No embeddings were generated"
            case .invalidIndex:
                return "No valid Pinecone index selected"
            case .invalidNamespace:
                return "Invalid namespace selected"
            case .documentSizeTooLarge(let size, let maxSize):
                let sizeMB = Double(size) / 1_048_576
                let maxSizeMB = Double(maxSize) / 1_048_576
                return "Document size (\(String(format: "%.2f", sizeMB))MB) exceeds maximum allowed (\(String(format: "%.2f", maxSizeMB))MB)"
            }
        }
    }
    
    /// Statistics for document processing
    struct ProcessingStats {
        var totalDocuments = 0
        var totalChunks = 0
        var totalTokens = 0
        var totalVectors = 0
        var startTime = Date()
        var processingTimeSeconds: TimeInterval {
            return Date().timeIntervalSince(startTime)
        }
    }
}
