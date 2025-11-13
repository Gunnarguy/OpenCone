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
    /// Shared resolver for index/namespace preferences
    private let preferences = PineconePreferenceResolver()
    /// UserDefaults key for tracking bookmark consent acknowledgement
    private let securityConsentKey = "SecurityScopedBookmarkConsentAcknowledged"
    
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

    /// Metadata describing the currently selected index (dimension, metric, etc.)
    @Published var indexMetadata: IndexDescribeResponse? = nil

    /// Latest index statistics including namespace counts
    @Published var indexStats: IndexStatsResponse? = nil

    /// Dimension of the currently selected Pinecone index
    @Published var indexDimension: Int? = nil

    /// Flag indicating if index/namespace operations are in progress
    @Published var isLoadingIndexes = false // Added for index creation loading state

    /// Flag to control the visibility of the create index dialog
    @Published var showingCreateIndexDialog = false // Added for index creation dialog

    /// Holds the name for the new index being created
    @Published var newIndexName = "" // Added for index creation dialog

    /// Indicates whether the user must acknowledge the security-scoped bookmark consent copy
    @Published var needsSecurityConsent: Bool
    
    /// Tracks the granular progress (0.0 to 1.0) for each document being processed concurrently
    @Published private var documentProgress: [UUID: Float] = [:]
    
    /// Cancellables for managing Combine subscriptions
    private var cancellables = Set<AnyCancellable>()

    /// Maximum allowed document size for ingestion.
    private let maxDocumentSize: Int64
    
    // MARK: - Constants for Progress Calculation
    private let phaseWeightExtraction: Float = 0.10
    private let phaseWeightChunking: Float = 0.10
    private let phaseWeightEmbedding: Float = 0.50
    private let phaseWeightUploading: Float = 0.30

    // Dashboard metrics representing the ingestion state
    struct DocumentDashboardMetrics {
        let totalDocuments: Int
        let processed: Int
        let pending: Int
        let failed: Int
        let totalChunks: Int
        let totalVectors: Int
        let averageProcessingSeconds: Double
    }
    
    // MARK: - Initialization
    
    /// Initialize with required services
    /// - Parameters:
    ///   - fileProcessorService: Service for processing document files
    ///   - textProcessorService: Service for text processing and chunking
    ///   - embeddingService: Service for generating embeddings
    ///   - pineconeService: Service for Pinecone vector database operations
    init(fileProcessorService: FileProcessorService, textProcessorService: TextProcessorService,
         embeddingService: EmbeddingService,
         pineconeService: PineconeService,
         maxDocumentSize: Int64 = 100 * 1024 * 1024) {
        self.fileProcessorService = fileProcessorService
        self.textProcessorService = textProcessorService
        self.embeddingService = embeddingService
        self.pineconeService = pineconeService
        self.needsSecurityConsent = !UserDefaults.standard.bool(forKey: securityConsentKey)
        self.maxDocumentSize = maxDocumentSize
    }

    /// Persist the user acknowledgement for the security-scoped bookmark consent banner.
    func acknowledgeSecurityConsent() {
        UserDefaults.standard.set(true, forKey: securityConsentKey)
        DispatchQueue.main.async { [weak self] in
            self?.needsSecurityConsent = false
        }
    }

    // MARK: - Derived Metrics

    /// Aggregate metrics that drive the Documents dashboard UI.
    var dashboardMetrics: DocumentDashboardMetrics {
        let totalDocuments = documents.count
        let processed = documents.filter { $0.isProcessed }.count
        let failed = documents.filter { $0.processingError != nil }.count
        let pending = max(totalDocuments - processed - failed, 0)

        let totalChunks = documents.reduce(0) { $0 + $1.chunkCount }
        let totalVectors = documents.reduce(0) { partialResult, doc in
            if let vectors = doc.processingStats?.vectorsUploaded, vectors > 0 {
                return partialResult + vectors
            }
            return partialResult + doc.chunkCount
        }

        let durations = documents.compactMap { $0.processingStats?.totalProcessingTime }
        let averageProcessingSeconds = durations.isEmpty
            ? 0
            : durations.reduce(0, +) / Double(durations.count)

        return DocumentDashboardMetrics(
            totalDocuments: totalDocuments,
            processed: processed,
            pending: pending,
            failed: failed,
            totalChunks: totalChunks,
            totalVectors: totalVectors,
            averageProcessingSeconds: averageProcessingSeconds
        )
    }

    /// Number of vectors currently stored in the selected namespace.
    var selectedNamespaceVectorCount: Int {
        guard let stats = indexStats else { return 0 }
        let namespaceKey = selectedNamespace ?? ""
        return stats.namespaces[namespaceKey]?.vectorCount ?? 0
    }

    /// Total vectors across the index according to Pinecone stats.
    var totalIndexVectorCount: Int {
        indexStats?.totalVectorCount ?? 0
    }

    /// Indicates whether any document has failed during processing.
    var hasDocumentFailures: Bool {
        documents.contains { $0.processingError != nil }
    }

    /// Most recent processed document by end time.
    var latestProcessedDocument: DocumentModel? {
        documents
            .compactMap { doc -> (DocumentModel, Date)? in
                guard let endTime = doc.processingStats?.endTime else { return nil }
                return (doc, endTime)
            }
            .max(by: { $0.1 < $1.1 })?.0
    }

    /// Documents that have been added but not processed yet.
    var pendingDocuments: [DocumentModel] {
        documents.filter { !$0.isProcessed && $0.processingError == nil }
    }
    
    // MARK: - Document Management
    
    /// Add a document to the list
    /// - Parameter url: URL of the document to add
    func addDocument(at url: URL) {
        var hasSecurityScope = false
        do {
            hasSecurityScope = url.startAccessingSecurityScopedResource()

            // Some providers return sandbox-friendly URLs that do not need security scope. Fall back to reachability if the scope call fails.
            if !hasSecurityScope {
                let reachable = (try? url.checkResourceIsReachable()) ?? FileManager.default.isReadableFile(atPath: url.path)
                guard reachable else {
                    logger.log(level: .warning, message: "Unable to read selected file", context: url.lastPathComponent)
                    errorMessage = "Unable to access \(url.lastPathComponent). Check Files permissions and try again."
                    return
                }
            }
            defer {
                if hasSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // Create a scoped bookmark so we can reopen the document in future sessions.
            // Get file attributes (access might be needed again if path is used directly)
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            let creationDate = attributes[.creationDate] as? Date
            let modificationDate = attributes[.modificationDate] as? Date
            let documentId = DocumentIdentifierBuilder.makeIdentifier(
                url: url,
                fileSize: fileSize,
                creationDate: creationDate,
                modificationDate: modificationDate
            )

            // Prevent duplicates using the stable identifier
            if documents.contains(where: { $0.documentId == documentId }) {
                logger.log(level: .warning, message: "Document already exists", context: url.lastPathComponent)
                return
            }
            
            // Check file size limitations
            if fileSize > maxDocumentSize {
                let maxSizeString = ByteCountFormatter.string(fromByteCount: maxDocumentSize, countStyle: .file)
                logger.log(level: .warning, message: "File exceeds size limit (\(maxSizeString))", context: url.lastPathComponent)
                let sizeMessage = ProcessingError.documentSizeTooLarge(size: fileSize, maxSize: maxDocumentSize).errorDescription ?? "File exceeds size limit"
                errorMessage = "\(url.lastPathComponent): \(sizeMessage)"
                return
            }
            
            // Copy the file into the app's sandbox to guarantee ongoing read access.
            let persistedURL = try persistDocumentCopy(from: url)

            // Generate a bookmark against the sandbox copy for predictable reopen behaviour.
            let bookmarkData = try persistedURL.bookmarkData(options: [.minimalBookmark], includingResourceValuesForKeys: nil, relativeTo: nil)

            // Create document model with determined MIME type and bookmark
            let document = DocumentModel(
                documentId: documentId,
                fileName: url.lastPathComponent,
                filePath: persistedURL,
                securityBookmark: bookmarkData, // Store the bookmark
                mimeType: determineMimeType(for: persistedURL),
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

        Task { [weak self] in
            guard let self else { return }

            let documentsToRemove = await MainActor.run { self.documents.filter { self.selectedDocuments.contains($0.id) } }
            guard !documentsToRemove.isEmpty else {
                self.logger.log(level: .info, message: "No documents selected for removal")
                return
            }

            var removalErrors: [String] = []
            var removedDocumentIDs = Set<UUID>()

            let originalIndex = await MainActor.run { self.selectedIndex }
            let defaultNamespace = await MainActor.run { self.selectedNamespace }
            var activeIndex = originalIndex

            for document in documentsToRemove {
                var vectorsRemoved = !document.isProcessed
                var fileRemoved = false

                let targetIndex = document.lastIndexedIndexName ?? originalIndex
                let targetNamespace = document.lastIndexedNamespace ?? defaultNamespace

                if document.isProcessed {
                    do {
                        if let indexName = targetIndex {
                            if activeIndex != indexName {
                                try await pineconeService.setCurrentIndex(indexName)
                                activeIndex = indexName
                            }
                            let response = try await pineconeService.deleteVectors(
                                ids: nil,
                                filter: ["doc_id": ["$eq": document.documentId]],
                                namespace: targetNamespace
                            )
                            if let deleted = response.deletedCount {
                                logger.log(level: .info, message: "Deleted \(deleted) vectors", context: document.fileName)
                            }
                            vectorsRemoved = true
                        } else {
                            vectorsRemoved = false
                            removalErrors.append("Missing Pinecone index for \(document.fileName); cannot delete vectors.")
                        }
                    } catch PineconeError.namespaceNotFound {
                        vectorsRemoved = true
                        logger.log(level: .warning, message: "Namespace not found during deletion; treating as already removed", context: document.fileName)
                    } catch {
                        vectorsRemoved = false
                        removalErrors.append("Failed to delete vectors for \(document.fileName): \(error.localizedDescription)")
                    }
                }

                if vectorsRemoved {
                    do {
                        let path = document.filePath.path
                        if FileManager.default.fileExists(atPath: path) {
                            try FileManager.default.removeItem(at: document.filePath)
                            fileRemoved = true
                        } else {
                            fileRemoved = true
                        }
                    } catch {
                        fileRemoved = false
                        removalErrors.append("Failed to remove local copy for \(document.fileName): \(error.localizedDescription)")
                    }
                }

                if vectorsRemoved && fileRemoved {
                    removedDocumentIDs.insert(document.id)
                    logger.log(level: .info, message: "Document removed", context: document.fileName)
                } else {
                    logger.log(level: .warning, message: "Document removal incomplete", context: document.fileName)
                }
            }

            if let originalIndex, activeIndex != originalIndex {
                do {
                    try await pineconeService.setCurrentIndex(originalIndex)
                } catch {
                    removalErrors.append("Failed to restore Pinecone index '\(originalIndex)': \(error.localizedDescription)")
                }
            }

            let removedIDsSnapshot = removedDocumentIDs
            let removalErrorsSnapshot = removalErrors

            await MainActor.run {
                if !removedIDsSnapshot.isEmpty {
                    self.documents.removeAll { removedIDsSnapshot.contains($0.id) }
                    self.selectedDocuments.subtract(removedIDsSnapshot)
                }

                if removalErrorsSnapshot.isEmpty {
                    self.errorMessage = nil
                } else {
                    self.errorMessage = removalErrorsSnapshot.joined(separator: "\n")
                }
            }

            if !removedDocumentIDs.isEmpty {
                await self.refreshIndexInsights()
            }
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
        await MainActor.run { self.isLoadingIndexes = true }
        defer { Task { @MainActor in self.isLoadingIndexes = false } }

        do {
            let indexes = try await pineconeService.listIndexes()

            let selection = await MainActor.run { () -> (index: String?, needsDescribe: Bool) in
                self.pineconeIndexes = indexes
                self.errorMessage = nil

                guard !indexes.isEmpty else {
                    self.selectedIndex = nil
                    self.selectedNamespace = nil
                    self.indexDimension = nil
                    self.indexMetadata = nil
                    self.indexStats = nil
                    self.namespaces = []
                    return (nil, false)
                }

                let previousIndex = self.selectedIndex
                let resolvedIndex = self.preferences.resolveIndex(
                    availableIndexes: indexes,
                    currentSelection: previousIndex
                )

                self.selectedIndex = resolvedIndex

                if previousIndex != resolvedIndex {
                    self.indexDimension = nil
                    self.indexMetadata = nil
                    self.indexStats = nil
                }

                let needsDescribe = previousIndex != resolvedIndex || self.indexDimension == nil
                return (resolvedIndex, needsDescribe)
            }

            if let indexName = selection.index {
                if selection.needsDescribe {
                    await setIndex(indexName)
                } else {
                    await refreshIndexInsights()
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
            await MainActor.run {
                self.selectedIndex = indexName
                self.selectedNamespace = nil
                self.namespaces = []
                self.indexDimension = nil
                self.indexMetadata = nil
                self.indexStats = nil
                self.errorMessage = nil
            }
            let indexDetails = try await pineconeService.describeIndex(name: indexName)
            await MainActor.run {
                self.indexDimension = indexDetails.dimension
                self.indexMetadata = indexDetails
            }
            preferences.recordLastIndex(indexName)
            logger.log(level: .info, message: "Index dimension set", context: "\(indexName): \(indexDetails.dimension)")
            await refreshIndexInsights()
            logger.log(level: .info, message: "Set current index to: \(indexName)")
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to set index: \(error.localizedDescription)"
                self.indexDimension = nil
                self.indexMetadata = nil
                self.indexStats = nil
                self.logger.log(level: .error, message: "Failed to set index", context: error.localizedDescription)
            }
        }
    }

    /// Load available namespaces for the current index
    func loadNamespaces() async {
        await refreshIndexInsights()
    }

    /// Refresh namespace listings and index statistics for the current index.
    func refreshIndexInsights() async {
        let currentState = await MainActor.run { (index: self.selectedIndex, namespace: self.selectedNamespace) }

        guard let activeIndex = currentState.index else {
            await MainActor.run {
                self.namespaces = []
                self.selectedNamespace = nil
                self.indexStats = nil
            }
            return
        }

        do {
            let inventory = try await pineconeService.fetchNamespaceInventory()
            var namespaceCandidates = inventory.namespaceNames

            // Always expose the default namespace option even if Pinecone omits it.
            if !namespaceCandidates.contains("") {
                namespaceCandidates.append("")
            }

            // Preserve user-preferred and most recent selections while the control plane converges.
            if let stored = preferences.storedNamespace(for: activeIndex), !stored.isEmpty,
               !namespaceCandidates.contains(stored) {
                namespaceCandidates.append(stored)
            }

            if let preferred = preferences.preferredNamespace(), !preferred.isEmpty,
               !namespaceCandidates.contains(preferred) {
                namespaceCandidates.append(preferred)
            }

            if let selected = currentState.namespace, !selected.isEmpty,
               !namespaceCandidates.contains(selected) {
                namespaceCandidates.append(selected)
            }

            let visibleNamespaces = normalizeNamespaces(namespaceCandidates)
            let stats = inventory.stats

            let persistenceContext = await MainActor.run { () -> (index: String, namespace: String?) in
                self.namespaces = visibleNamespaces
                self.indexStats = stats
                self.errorMessage = nil

                let resolvedNamespace = self.preferences.resolveNamespace(
                    availableNamespaces: visibleNamespaces,
                    index: activeIndex,
                    currentSelection: currentState.namespace
                )

                self.selectedNamespace = resolvedNamespace
                return (activeIndex, resolvedNamespace)
            }

            if let namespace = persistenceContext.namespace {
                preferences.recordNamespace(namespace, for: persistenceContext.index)
            } else {
                preferences.clearNamespace(for: persistenceContext.index)
            }

            let fallbackNames = Set(visibleNamespaces).subtracting(inventory.namespaceNames)
            let fallbackSummaryList = fallbackNames.filter { !$0.isEmpty }.sorted()
            let fallbackSummary = fallbackSummaryList.isEmpty ? "none" : fallbackSummaryList.joined(separator: ",")

            logger.log(
                level: .info,
                message: "Refreshed index stats",
                context: "visibleNamespaces=\(visibleNamespaces.count), statsNamespaces=\(stats.namespaces.count), totalVectors=\(stats.totalVectorCount), fallbackNamespaces=\(fallbackSummary)"
            )
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to refresh index stats: \(error.localizedDescription)"
            }
            logger.log(level: .error, message: "Failed to refresh index stats", context: error.localizedDescription)
        }
    }

    /// Deduplicates and sorts namespaces so the default entry remains first.
    private func normalizeNamespaces(_ namespaces: [String]) -> [String] {
        var deduped: [String] = []
        var seen = Set<String>()

        for name in namespaces {
            if seen.insert(name).inserted {
                deduped.append(name)
            }
        }

        return deduped.sorted { lhs, rhs in
            switch (lhs.isEmpty, rhs.isEmpty) {
            case (true, false):
                return true
            case (false, true):
                return false
            default:
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
        }
    }
    
    /// Set the current namespace
    /// - Parameter namespace: Namespace to set
    @MainActor
    func setNamespace(_ namespace: String?) {
        let trimmed = namespace.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let displayName = (trimmed?.isEmpty ?? true) ? "default" : (trimmed ?? "")

        selectedNamespace = trimmed
        logger.log(level: .info, message: "Set namespace to: \(displayName)")

        guard let index = selectedIndex else { return }

        if let trimmed {
            preferences.recordNamespace(trimmed, for: index)
        } else {
            preferences.clearNamespace(for: index)
        }
    }
    
    /// Create a new namespace
    /// - Parameter name: Name of the new namespace
    func createNamespace(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Pinecone namespace rules: lowercase letters, numbers, hyphen, underscore (1-64 chars, cannot start/end with symbol)
        let namespacePattern = "^[a-z0-9](?:[a-z0-9_-]{0,62}[a-z0-9])?$"
        guard trimmed.range(of: namespacePattern, options: .regularExpression) != nil else {
            logger.log(level: .warning, message: "Invalid namespace format", context: trimmed)
            Task { @MainActor in self.errorMessage = "Namespaces must start with a letter or number and can include lowercase letters, digits, hyphens, or underscores." }
            return
        }

        guard !namespaces.contains(trimmed) else {
            logger.log(level: .warning, message: "Namespace already exists", context: trimmed)
            Task { @MainActor in
                self.selectedNamespace = trimmed
                self.errorMessage = nil
                if let index = self.selectedIndex { self.preferences.recordNamespace(trimmed, for: index) }
            }
            return
        }

        Task {
            do {
                try await pineconeService.createNamespace(trimmed)
                logger.log(level: .info, message: "Namespace created", context: trimmed)
                await MainActor.run {
                    self.errorMessage = nil
                    self.selectedNamespace = trimmed
                    if let index = self.selectedIndex { self.preferences.recordNamespace(trimmed, for: index) }
                    if !self.namespaces.contains(trimmed) {
                        self.namespaces.append(trimmed)
                        self.namespaces = self.normalizeNamespaces(self.namespaces)
                    }
                }
                await refreshIndexInsights()
            } catch {
                if case PineconeError.requestFailed(let status, let message) = error,
                   status == 409 || (message?.localizedCaseInsensitiveContains("already exists") ?? false) {
                    logger.log(level: .info, message: "Namespace already existed", context: trimmed)
                    await MainActor.run {
                        self.errorMessage = nil
                        self.selectedNamespace = trimmed
                        if let index = self.selectedIndex { self.preferences.recordNamespace(trimmed, for: index) }
                        if !self.namespaces.contains(trimmed) {
                            self.namespaces.append(trimmed)
                            self.namespaces = self.normalizeNamespaces(self.namespaces)
                        }
                    }
                    await refreshIndexInsights()
                } else {
                    let fallbackMessage: String
                    if let pineconeError = error as? PineconeError,
                       case let .requestFailed(_, message) = pineconeError,
                       let message,
                       !message.isEmpty {
                        fallbackMessage = message
                    } else {
                        fallbackMessage = error.localizedDescription
                    }

                    logger.log(level: .error, message: "Failed to create namespace", context: fallbackMessage)

                    await MainActor.run {
                        self.selectedNamespace = trimmed
                        if let index = self.selectedIndex { self.preferences.recordNamespace(trimmed, for: index) }
                        self.errorMessage = "Failed to create namespace: \(fallbackMessage)"
                    }
                }
            }
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

            let namespaceSnapshot = await MainActor.run { self.selectedNamespace }
            let indexSnapshot = await MainActor.run { self.selectedIndex }
            let indexDimensionSnapshot = await MainActor.run { self.indexDimension }
            try await purgeExistingVectors(for: document, namespace: namespaceSnapshot)
            
            // PHASE 3: Generate embeddings (Weight: phaseWeightEmbedding)
            await MainActor.run { self.currentProcessingStatus = "Generating embeddings (\(document.fileName))..." }
            let embeddingStart = Date() // Record start time for stats
            let targetDimension = indexDimensionSnapshot ?? Configuration.embeddingDimension
            logger.log(level: .info, message: "Generating embeddings with dimension \(targetDimension)", context: document.fileName)
            let embeddings: [EmbeddingModel]
            do {
                embeddings = try await embeddingService.generateEmbeddings(for: chunks, dimension: targetDimension) { batchIndex, totalBatches in
                    // Calculate progress within this phase based on batch completion
                    let batchProgress = totalBatches > 0 ? Float(batchIndex + 1) / Float(totalBatches) : 1.0
                    let phaseProgress = self.phaseWeightEmbedding * batchProgress
                    await self.updateOverallProgress(for: document.id, progress: currentDocumentProgress + phaseProgress)
                }
            } catch {
                throw ProcessingError.embeddingFailed(underlying: error)
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
            let upsertResponse: UpsertResponse
            do {
                upsertResponse = try await pineconeService.upsertVectors(vectorsToUpsert, namespace: namespaceSnapshot) { batchIndex, totalBatches in
                     // Calculate progress within this phase based on batch completion
                    let batchProgress = totalBatches > 0 ? Float(batchIndex + 1) / Float(totalBatches) : 1.0
                    let phaseProgress = self.phaseWeightUploading * batchProgress
                    await self.updateOverallProgress(for: document.id, progress: currentDocumentProgress + phaseProgress)
                }
            } catch {
                throw ProcessingError.upsertFailed(underlying: error)
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
            await updateDocumentStatus(
                document,
                isProcessed: true,
                chunkCount: chunks.count,
                namespace: namespaceSnapshot,
                indexName: indexSnapshot,
                shouldUpdateContext: true
            )
            await updateDocumentStats(document, stats: processingStats)
            
            logger.log(level: .success, message: "Document processed successfully", context: document.fileName)
            await refreshIndexInsights()
            
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

    /// Removes any previously indexed vectors for the supplied document so re-processing produces a clean slate.
    private func purgeExistingVectors(for document: DocumentModel, namespace: String?) async throws {
        guard !document.documentId.isEmpty else { return }

        do {
            let response = try await pineconeService.deleteVectors(
                ids: nil,
                filter: ["doc_id": ["$eq": document.documentId]],
                namespace: namespace
            )
            if let deleted = response.deletedCount {
                logger.log(level: .info, message: "Removed \(deleted) stale vectors", context: document.fileName)
            }
        } catch PineconeError.namespaceNotFound {
            logger.log(
                level: .warning,
                message: "Namespace \(namespace ?? "<default>") missing while purging vectors",
                context: "Namespace not found"
            )
            return
        } catch {
            logger.log(level: .error, message: "Failed to purge existing vectors", context: "\(document.fileName): \(error.localizedDescription)")
            throw ProcessingError.cleanupFailed(underlying: error)
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
        var hasScope = false
        
        do {
            // Resolve the bookmark to regain access without prompting the user again.
            var resolveOptions: URL.BookmarkResolutionOptions = [.withoutUI]
            #if os(macOS)
            resolveOptions.insert(.withSecurityScope)
            #endif
            resolvedURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: resolveOptions,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                logger.log(level: .warning, message: "Security bookmark is stale, attempting refresh", context: document.fileName)
                do {
                    var refreshedOptions: URL.BookmarkCreationOptions = [.minimalBookmark]
                    #if os(macOS)
                    refreshedOptions.insert(.withSecurityScope)
                    refreshedOptions.insert(.securityScopeAllowOnlyReadAccess)
                    #endif
                    let refreshedBookmark = try resolvedURL.bookmarkData(
                        options: refreshedOptions,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    await updateDocumentSecurityBookmark(document, bookmark: refreshedBookmark)
                    logger.log(level: .info, message: "Security bookmark refreshed", context: document.fileName)
                } catch {
                    logger.log(level: .warning, message: "Failed to refresh security bookmark", context: "\(document.fileName): \(error.localizedDescription)")
                }
            }

            hasScope = resolvedURL.startAccessingSecurityScopedResource()
            if !hasScope {
                let reachable = ((try? resolvedURL.checkResourceIsReachable()) ?? false) || FileManager.default.isReadableFile(atPath: resolvedURL.path)
                guard reachable else {
                    logger.log(level: .error, message: "Failed to access security-scoped resource despite bookmark", context: document.fileName)
                    throw ProcessingError.securityAccessDenied
                }
            }
        } catch {
            logger.log(level: .error, message: "Failed to resolve security bookmark", context: "\(document.fileName): \(error.localizedDescription)")
            throw ProcessingError.securityAccessDenied
        }

        defer {
            if hasScope {
                resolvedURL.stopAccessingSecurityScopedResource()
            }
        }
        
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
        return autoreleasepool {
            let chunkingStart = Date()
            let processedAt = Date()
            let isoFormatter = ISO8601DateFormatter()

            let metadata = [
                "source": document.filePath.lastPathComponent,
                "mimeType": mimeType,
                "fileName": document.fileName,
                "fileSize": String(document.fileSize),
                "dateProcessed": isoFormatter.string(from: processedAt),
                "documentId": document.documentId,
                "sourcePath": document.filePath.path,
                "ingestSessionId": document.id.uuidString
            ]

            let (chunks, analytics) = textProcessorService.chunkText(
                text: text,
                metadata: metadata,
                mimeType: mimeType
            )
            let chunkingEnd = Date()

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
    private func updateDocumentStatus(
        _ document: DocumentModel,
        isProcessed: Bool,
        error: String? = nil,
        chunkCount: Int = 0,
        namespace: String? = nil,
        indexName: String? = nil,
        shouldUpdateContext: Bool = false
    ) async {
        await MainActor.run {
            if let index = self.documents.firstIndex(where: { $0.id == document.id }) {
                // Create a new copy of the document with updated status
                var updatedDocument = self.documents[index]
                updatedDocument.isProcessed = isProcessed
                updatedDocument.chunkCount = chunkCount

                if isProcessed {
                    updatedDocument.processingError = nil
                } else {
                    updatedDocument.processingError = error
                }

                if shouldUpdateContext {
                    updatedDocument.lastIndexedNamespace = namespace
                    updatedDocument.lastIndexedIndexName = indexName
                    if isProcessed {
                        updatedDocument.lastIndexedAt = Date()
                    }
                }
                
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

    /// Persist a refreshed security bookmark for a document so future runs have valid access.
    private func updateDocumentSecurityBookmark(_ document: DocumentModel, bookmark: Data) async {
        await MainActor.run {
            if let index = self.documents.firstIndex(where: { $0.id == document.id }) {
                self.documents[index].securityBookmark = bookmark
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

    /// Persist a user-selected document into the app's sandbox so later processing never depends on provider permissions.
    private func persistDocumentCopy(from sourceURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        try fileManager.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)

        let sanitizedName = DocumentFileUtilities.sanitizeFilename(sourceURL.lastPathComponent)
        let destinationURL = DocumentFileUtilities.makeUniqueDestinationURL(
            basedOn: sanitizedName,
            within: documentsDirectory
        )

        // Ensure we start from a clean slate if the temporary destination exists for some reason.
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
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
        case cleanupFailed(underlying: Error)
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
            case .cleanupFailed(let error):
                return "Failed to remove previously indexed vectors: \(error.localizedDescription)"
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
