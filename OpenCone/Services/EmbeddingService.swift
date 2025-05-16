import Foundation

/// Service for generating embeddings from text
class EmbeddingService {
    
    private let logger = Logger.shared
    private let openAIService: OpenAIService
    
    init(openAIService: OpenAIService) {
        self.openAIService = openAIService
    }
    
    /// Generate embeddings for a list of text chunks
    /// - Parameter chunks: Array of ChunkModel objects
    /// - Parameter progressCallback: Optional closure to report batch progress (batchIndex, totalBatches)
    /// - Returns: Array of EmbeddingModel objects
    func generateEmbeddings(
        for chunks: [ChunkModel],
        progressCallback: ((Int, Int) async -> Void)? = nil // Add optional callback
    ) async throws -> [EmbeddingModel] {
        guard !chunks.isEmpty else {
            logger.log(level: .warning, message: "No chunks provided to generate embeddings")
            return []
        }
        
        // For large batch of chunks, process in smaller batches to conserve memory
        if chunks.count > 50 {
            // Pass the callback down to the batch function
            return try await generateEmbeddingsInBatches(for: chunks, progressCallback: progressCallback)
        }
        
        // Process in a single batch for smaller input
        logger.log(level: .info, message: "Generating embeddings for \(chunks.count) chunks")
        
        let texts = chunks.map { $0.content }
        let embeddings = try await openAIService.createEmbeddings(texts: texts)
        
        guard embeddings.count == chunks.count else {
            logger.log(level: .error, message: "Embedding count mismatch: \(embeddings.count) embeddings for \(chunks.count) chunks")
            throw EmbeddingError.countMismatch
        }
        
        // Pre-allocate array to avoid resizing
        var embeddingModels: [EmbeddingModel] = []
        embeddingModels.reserveCapacity(chunks.count)
        
        // Use autoreleasepool for memory management during the loop
        autoreleasepool {
            for (index, vector) in embeddings.enumerated() {
                let chunk = chunks[index]
                let vectorId = "\(chunk.contentHash)_\(index)"
                
                // Only include necessary metadata to reduce memory usage
                let metadata: [String: String] = [
                    "text": chunk.content.count > 1000 ? String(chunk.content.prefix(1000)) + "..." : chunk.content,
                    "source": chunk.sourceDocument,
                    "hash": chunk.contentHash
                ]
                
                let embeddingModel = EmbeddingModel(
                    vectorId: vectorId,
                    vector: vector,
                    chunkId: chunk.id,
                    contentHash: chunk.contentHash,
                    metadata: metadata
                )
                
                embeddingModels.append(embeddingModel)
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
                let embeddings = try await openAIService.createEmbeddings(texts: texts)
                
                guard embeddings.count == batch.count else {
                    logger.log(level: .error, message: "Batch embedding count mismatch: \(embeddings.count) embeddings for \(batch.count) chunks")
                    throw EmbeddingError.countMismatch
                }
                
                var batchModels: [EmbeddingModel] = []
                batchModels.reserveCapacity(batch.count)
                
                // Process each embedding in the batch with autoreleasepool
                autoreleasepool {
                    for (idx, vector) in embeddings.enumerated() {
                        let chunk = batch[idx]
                        let vectorId = "\(chunk.contentHash)_\(idx + index * batchSize)"
                        
                        let metadata: [String: String] = [
                            "text": chunk.content.count > 1000 ? String(chunk.content.prefix(1000)) + "..." : chunk.content,
                            "source": chunk.sourceDocument,
                            "hash": chunk.contentHash
                        ]
                        
                        let embeddingModel = EmbeddingModel(
                            vectorId: vectorId,
                            vector: vector,
                            chunkId: chunk.id,
                            contentHash: chunk.contentHash,
                            metadata: metadata
                        )
                        
                        batchModels.append(embeddingModel)
                    }
                }
                
                // Add this batch's models to the overall result
                let batchEmbeddings = batchModels
                
                embeddingModels.append(contentsOf: batchEmbeddings)
                
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
    
    /// Generate a single embedding for a query text
    /// - Parameter query: The query text
    /// - Returns: A vector embedding
    func generateQueryEmbedding(for query: String) async throws -> [Float] {
        let embeddings = try await openAIService.createEmbeddings(texts: [query])
        
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
}

enum EmbeddingError: Error {
    case generationFailed
    case countMismatch
    case dimensionMismatch
    case apiError(String)
}
