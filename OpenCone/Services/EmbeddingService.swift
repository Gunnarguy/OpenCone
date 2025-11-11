import Foundation

/// Service for generating embeddings from text
class EmbeddingService {
    
    private let logger = Logger.shared
    private let openAIService: OpenAIService
    private static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private let maxPreviewLength = 512
    
    init(openAIService: OpenAIService) {
        self.openAIService = openAIService
    }
    
    /// Generate embeddings for a list of text chunks
    /// - Parameter chunks: Array of ChunkModel objects
    /// - Parameter progressCallback: Optional closure to report batch progress (batchIndex, totalBatches)
    /// - Returns: Array of EmbeddingModel objects
    func generateEmbeddings(
        for chunks: [ChunkModel],
        dimension: Int? = nil,
        progressCallback: ((Int, Int) async -> Void)? = nil // Add optional callback
    ) async throws -> [EmbeddingModel] {
        guard !chunks.isEmpty else {
            logger.log(level: .warning, message: "No chunks provided to generate embeddings")
            return []
        }
        
        // For large batch of chunks, process in smaller batches to conserve memory
        if chunks.count > 50 {
            // Pass the callback down to the batch function
            return try await generateEmbeddingsInBatches(for: chunks, dimension: dimension, progressCallback: progressCallback)
        }
        
        // Process in a single batch for smaller input
        logger.log(level: .info, message: "Generating embeddings for \(chunks.count) chunks")
        
    let texts = chunks.map { $0.content }
        let targetDimension = dimension ?? Configuration.embeddingDimension
        let embeddings = try await openAIService.createEmbeddings(texts: texts, dimension: targetDimension)

        if let actualDimension = embeddings.first?.count, actualDimension != targetDimension {
            logger.log(level: .error, message: "Embedding dimension mismatch: expected \(targetDimension), received \(actualDimension)")
            throw EmbeddingError.dimensionMismatch
        }
        
        guard embeddings.count == chunks.count else {
            logger.log(level: .error, message: "Embedding count mismatch: \(embeddings.count) embeddings for \(chunks.count) chunks")
            throw EmbeddingError.countMismatch
        }
        
        // Pre-allocate array to avoid resizing
        var embeddingModels: [EmbeddingModel] = []
        embeddingModels.reserveCapacity(chunks.count)

        autoreleasepool {
            for (index, vector) in embeddings.enumerated() {
                let chunk = chunks[index]
                let model = makeEmbeddingModel(for: chunk, vector: vector, absoluteIndex: index)
                embeddingModels.append(model)
            }
        }
        
        logger.log(level: .info, message: "Successfully generated \(embeddingModels.count) embeddings")
        return embeddingModels
    }
    
    /// Generate embeddings for chunks in batches to manage memory
    /// - Parameter chunks: Array of ChunkModel objects
    /// - Parameter progressCallback: Optional closure to report batch progress
    /// - Returns: Array of EmbeddingModel objects
    private func generateEmbeddingsInBatches(
        for chunks: [ChunkModel],
        dimension: Int?,
        progressCallback: ((Int, Int) async -> Void)? = nil // Add callback parameter
    ) async throws -> [EmbeddingModel] {
        logger.log(level: .info, message: "Generating embeddings in batches for \(chunks.count) chunks")
        
        let batchSize = 50 // OpenAI can handle 50 chunks at a time efficiently
        var embeddingModels: [EmbeddingModel] = []
        embeddingModels.reserveCapacity(chunks.count)
        
        // Process chunks in batches
        let batches = stride(from: 0, to: chunks.count, by: batchSize).map {
            Array(chunks[$0..<min($0 + batchSize, chunks.count)])
        }
        
        let totalBatches = batches.count
        
        // Report initial progress if callback exists
        if totalBatches > 0 {
            await progressCallback?(0, totalBatches)
        }
        
        for (index, batch) in batches.enumerated() {
            do {
                logger.log(level: .info, message: "Processing batch \(index + 1)/\(totalBatches) with \(batch.count) chunks")
                
                // Get embeddings for this batch
                let texts = batch.map { $0.content }
                let targetDimension = dimension ?? Configuration.embeddingDimension
                let embeddings = try await openAIService.createEmbeddings(texts: texts, dimension: targetDimension)

                if let actualDimension = embeddings.first?.count, actualDimension != targetDimension {
                    logger.log(level: .error, message: "Embedding dimension mismatch in batch: expected \(targetDimension), received \(actualDimension)")
                    throw EmbeddingError.dimensionMismatch
                }
                
                guard embeddings.count == batch.count else {
                    logger.log(level: .error, message: "Batch embedding count mismatch: \(embeddings.count) embeddings for \(batch.count) chunks")
                    throw EmbeddingError.countMismatch
                }
                
                autoreleasepool {
                    for (idx, vector) in embeddings.enumerated() {
                        let chunk = batch[idx]
                        let absoluteIndex = index * batchSize + idx
                        let model = makeEmbeddingModel(for: chunk, vector: vector, absoluteIndex: absoluteIndex)
                        embeddingModels.append(model)
                    }
                }
                
                // Report progress after processing the batch
                await progressCallback?(index, totalBatches)
                
                // Small delay between batches to allow memory cleanup
                if index < totalBatches - 1 {
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }
                
            } catch {
                logger.log(level: .error, message: "Error processing batch \(index + 1): \(error.localizedDescription)")
                throw error
            }
        }
        
        logger.log(level: .info, message: "Successfully generated \(embeddingModels.count) embeddings in batches")
        return embeddingModels
    }
    
    /// Generate a single embedding for a query text, optionally with a specific dimension
    /// - Parameters:
    ///   - query: The query text
    ///   - dimension: The desired vector dimension
    /// - Returns: A vector embedding
    func generateQueryEmbedding(for query: String, dimension: Int? = nil) async throws -> [Float] {
        let embeddings = try await openAIService.createEmbeddings(texts: [query], dimension: dimension)
        
        guard let embedding = embeddings.first else {
            logger.log(level: .error, message: "Failed to generate embedding for query")
            throw EmbeddingError.generationFailed
        }
        
        return embedding
    }
    
    /// Calculate cosine similarity between two vectors
    /// - Parameters:
    ///   - a: First vector
    ///   - b: Second vector
    /// - Returns: Cosine similarity score
    func cosineSimilarity(a: [Float], b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else {
            return 0
        }
        
        let dotProduct = zip(a, b).map { $0 * $1 }.reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        
        guard magnitudeA > 0, magnitudeB > 0 else {
            return 0
        }
        
        return dotProduct / (magnitudeA * magnitudeB)
    }
    
    /// Convert embeddings to Pinecone format
    /// - Parameter embeddings: Array of EmbeddingModel objects
    /// - Returns: Array of PineconeVector objects
    func convertToPineconeVectors(from embeddings: [EmbeddingModel]) -> [PineconeVector] {
        return embeddings.map { embedding in
            PineconeVector(
                id: embedding.vectorId,
                values: embedding.vector,
                metadata: embedding.metadata
            )
        }
    }
    
    /// Local search when Pinecone is not available (for small datasets)
    /// - Parameters:
    ///   - queryEmbedding: Query vector embedding
    ///   - embeddings: Array of EmbeddingModel objects
    ///   - topK: Number of results to return
    /// - Returns: Array of search results with similarities
    func localSearch(queryEmbedding: [Float], embeddings: [EmbeddingModel], topK: Int) -> [(EmbeddingModel, Float)] {
        let similarities = embeddings.map { embedding in
            (embedding, cosineSimilarity(a: queryEmbedding, b: embedding.vector))
        }
        
        return similarities
            .sorted { $0.1 > $1.1 } // Sort by similarity (descending)
            .prefix(topK) // Take only top K results
            .map { ($0.0, $0.1) }
    }

    // MARK: - Metadata Helpers

    private func makeEmbeddingModel(for chunk: ChunkModel, vector: [Float], absoluteIndex: Int) -> EmbeddingModel {
        let vectorId = makeVectorId(for: chunk, absoluteIndex: absoluteIndex)
        let metadata = buildMetadata(for: chunk)
        return EmbeddingModel(
            vectorId: vectorId,
            vector: vector,
            chunkId: chunk.id,
            contentHash: chunk.contentHash,
            metadata: metadata
        )
    }

    private func makeVectorId(for chunk: ChunkModel, absoluteIndex: Int) -> String {
        let documentComponent = sanitizeIdentifierComponent(chunk.metadata.documentId ?? chunk.sourceDocument)
        let chunkComponent = "c\(chunk.metadata.chunkIndex)"
        let hashComponent = String(chunk.contentHash.prefix(12))

        var identifier = "\(documentComponent)_\(chunkComponent)_\(hashComponent)"
        if identifier.count > 96 {
            let truncatedDocument = String(documentComponent.prefix(48))
            identifier = "\(truncatedDocument)_\(chunkComponent)_\(hashComponent)"
        }

        if identifier.isEmpty {
            identifier = "vec_\(absoluteIndex)_\(hashComponent)"
        }

        return identifier
    }

    private func buildMetadata(for chunk: ChunkModel) -> [String: String] {
        var metadata: [String: String] = [:]
        metadata["text"] = chunk.content
        metadata["content_preview"] = makeContentPreview(from: chunk.content)
        metadata["doc_id"] = chunk.metadata.documentId ?? chunk.sourceDocument
        metadata["doc_title"] = chunk.metadata.additionalMetadata?["fileName"] ?? chunk.sourceDocument
        metadata["source"] = chunk.sourceDocument
        metadata["chunk_index"] = String(chunk.metadata.chunkIndex)
        metadata["chunk_total"] = String(chunk.metadata.totalChunks)
        metadata["chunk_hash"] = chunk.contentHash
        metadata["token_count"] = String(chunk.tokenCount)
        metadata["char_count"] = String(chunk.content.count)
        metadata["mime_type"] = chunk.metadata.additionalMetadata?["mimeType"] ?? chunk.metadata.mimeType
        metadata["processed_at"] = Self.isoDateFormatter.string(from: chunk.metadata.dateProcessed)

        if let sourcePath = chunk.metadata.additionalMetadata?["sourcePath"], !sourcePath.isEmpty {
            metadata["source_path"] = sourcePath
        }
        if let ingestId = chunk.metadata.additionalMetadata?["ingestSessionId"], !ingestId.isEmpty {
            metadata["ingest_session_id"] = ingestId
        }
        if let fileSize = chunk.metadata.additionalMetadata?["fileSize"], !fileSize.isEmpty {
            metadata["file_size"] = fileSize
        }
        if let pageNumber = chunk.metadata.position?.page {
            metadata["page_number"] = String(pageNumber)
        }

        if let additional = chunk.metadata.additionalMetadata {
            for (key, value) in additional where metadata[key] == nil && !value.isEmpty {
                metadata[key] = value
            }
        }

        return metadata.reduce(into: [String: String]()) { partialResult, entry in
            let trimmed = entry.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            partialResult[entry.key] = trimmed
        }
    }

    private func makeContentPreview(from text: String) -> String {
        guard text.count > maxPreviewLength else { return text }
        let endIndex = text.index(text.startIndex, offsetBy: maxPreviewLength)
        return String(text[text.startIndex..<endIndex]) + "…"
    }

    private func sanitizeIdentifierComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        var sanitized = ""
        sanitized.reserveCapacity(value.count)
        var previousWasDash = false

        for scalar in value.lowercased().unicodeScalars {
            if allowed.contains(scalar) {
                let character = Character(scalar)
                sanitized.append(character)
                previousWasDash = character == "-" || character == "_"
            } else if !previousWasDash {
                sanitized.append("-")
                previousWasDash = true
            }
        }

        return sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
    }
}

enum EmbeddingError: Error {
    case generationFailed
    case countMismatch
    case dimensionMismatch
    case apiError(String)
}

extension EmbeddingError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .generationFailed:
            return "Failed to generate embeddings."
        case .countMismatch:
            return "Embedding count did not match the number of requested inputs."
        case .dimensionMismatch:
            return "Embedding dimension did not match the Pinecone index requirement."
        case .apiError(let message):
            return "Embedding API error: \(message)"
        }
    }
}
