import Foundation
import NaturalLanguage
import CryptoKit

/// Service for processing text: chunking, tokenization, and analysis
class TextProcessorService {
    
    private let logger = Logger.shared
    
    // Tokenizer for counting tokens
    private let tokenizer: NLTokenizer
    
    init() {
        tokenizer = NLTokenizer(unit: .word)
    }
    
    /// Count tokens in a text string
    /// - Parameter text: The text to count tokens in
    /// - Returns: The token count
    func countTokens(in text: String) -> Int {
        tokenizer.string = text
        var tokenCount = 0
        
        // Use Range<String.Index> for enumerateTokens
        let stringRange = text.startIndex..<text.endIndex
        tokenizer.enumerateTokens(in: stringRange) { _, _ in
            tokenCount += 1
            return true
        }
        
        return tokenCount
    }
    
    /// Split text into chunks based on MIME type
    /// - Parameters:
    ///   - text: The text to split
    ///   - metadata: Metadata for the chunks
    ///   - mimeType: The MIME type of the original document
    /// - Returns: A tuple containing chunks and analytics
    func chunkText(text: String, metadata: [String: String], mimeType: String) -> ([ChunkModel], ChunkAnalytics) {
        guard !text.isEmpty else {
            return ([], ChunkAnalytics(
                totalChunks: 0,
                totalTokens: 0,
                tokenDistribution: [],
                chunkSizes: [],
                mimeType: mimeType,
                chunkStrategy: "None",
                avgTokensPerChunk: 0,
                avgCharsPerChunk: 0,
                minTokens: 0,
                maxTokens: 0
            ))
        }
        
        // Use autoreleasepool to manage memory during complex operation
        return autoreleasepool { () -> ([ChunkModel], ChunkAnalytics) in
            // Get the appropriate chunking strategy based on MIME type
            let (chunkSize, chunkOverlap, separators) = getChunkParametersForMimeType(mimeType)
            
            let chunkingStrategy = "RecursiveTextSplitter"
            
            // For large texts, log a progress message 
            if text.count > 100_000 {
                logger.log(level: .info, message: "Processing large text (size: \(text.count) characters)")
            }
            
            // Split the text into chunks
            let textChunks = splitTextRecursively(
                text: text,
                chunkSize: chunkSize,
                chunkOverlap: chunkOverlap,
                separators: separators
            )
            
            // Initialize analytics variables
            var tokenDistribution: [Int] = []
            tokenDistribution.reserveCapacity(textChunks.count)
            
            var chunkSizes: [Int] = []
            chunkSizes.reserveCapacity(textChunks.count)
            
            var totalTokens = 0
            
            // Create chunks array with enough capacity to avoid reallocations
            var chunks: [ChunkModel] = []
            chunks.reserveCapacity(textChunks.count)
            
            // Process chunks in batches to avoid memory spikes
            let batchSize = min(100, max(1, textChunks.count / 4))
            let batches = stride(from: 0, to: textChunks.count, by: batchSize)
            
            for batchStart in batches {
                autoreleasepool {
                    let batchEnd = min(batchStart + batchSize, textChunks.count)
                    
                    // Log batch progress for large documents
                    if textChunks.count > 200 {
                        logger.log(level: .debug, message: "Processing chunk batch \(batchStart/batchSize + 1)/\(textChunks.count / batchSize + 1)")
                    }
                    
                    // Process each chunk in this batch
                    for index in batchStart..<batchEnd {
                        let chunkText = textChunks[index]
                        
                        // Calculate token counts
                        let tokenCount = countTokens(in: chunkText)
                        totalTokens += tokenCount
                        tokenDistribution.append(tokenCount)
                        chunkSizes.append(chunkText.count)
                        
                        // Create a content hash
                        let contentHash = generateContentHash(for: chunkText)
                        
                        // Create chunk metadata
                        let chunkMetadata = ChunkMetadata(
                            source: metadata["source"] ?? "Unknown",
                            chunkIndex: index,
                            totalChunks: textChunks.count,
                            mimeType: mimeType,
                            dateProcessed: Date()
                        )
                        
                        // Create chunk model and add to chunks array
                        let chunk = ChunkModel(
                            content: chunkText,
                            sourceDocument: metadata["source"] ?? "Unknown",
                            metadata: chunkMetadata,
                            contentHash: contentHash,
                            tokenCount: tokenCount
                        )
                        
                        chunks.append(chunk)
                    }
                }
                
                // Manually trigger a memory cleanup after each batch
                Thread.sleep(forTimeInterval: 0.01)
            }
            
            // Calculate analytics
            let avgTokensPerChunk = totalTokens > 0 && !chunks.isEmpty ? Double(totalTokens) / Double(chunks.count) : 0
            let avgCharsPerChunk = !chunkSizes.isEmpty ? Double(chunkSizes.reduce(0, +)) / Double(chunkSizes.count) : 0
            let minTokens = tokenDistribution.min() ?? 0
            let maxTokens = tokenDistribution.max() ?? 0
            
            let analytics = ChunkAnalytics(
                totalChunks: chunks.count,
                totalTokens: totalTokens,
                tokenDistribution: tokenDistribution,
                chunkSizes: chunkSizes,
                mimeType: mimeType,
                chunkStrategy: chunkingStrategy,
                avgTokensPerChunk: avgTokensPerChunk,
                avgCharsPerChunk: avgCharsPerChunk,
                minTokens: minTokens,
                maxTokens: maxTokens
            )
            
            return (chunks, analytics)
        }
    }
    
    /// Get the appropriate chunking parameters based on MIME type
    /// - Parameter mimeType: The MIME type of the document
    /// - Returns: A tuple containing chunk size, overlap, and separators
    private func getChunkParametersForMimeType(_ mimeType: String) -> (Int, Int, [String]) {
        switch mimeType {
        case "application/pdf":
            return (1200, 200, ["\n\n", "\n", ". ", " ", ""])
        case "text/plain", "text/markdown", "text/rtf", "application/rtf", "text/csv", "text/tsv":
            return (800, 150, ["\n\n", "\n", ". ", " ", ""])
        case "application/x-python", "text/x-python", "application/javascript", "text/javascript", "text/css":
            return (500, 50, ["\n\n", "\n", ". ", " ", ""])
        case "text/html":
            return (1000, 200, ["\n\n", "\n", ". ", " ", ""])
        default:
            return (Configuration.defaultChunkSize, Configuration.defaultChunkOverlap, ["\n\n", "\n", ". ", " ", ""])
        }
    }
    
    /// Split text recursively using multiple separators
    /// - Parameters:
    ///   - text: The text to split
    ///   - chunkSize: Maximum size of each chunk
    ///   - chunkOverlap: Overlap between chunks
    ///   - separators: Array of separators to try in order
    /// - Returns: Array of text chunks
    private func splitTextRecursively(text: String, chunkSize: Int, chunkOverlap: Int, separators: [String]) -> [String] {
        // Guard against empty or tiny texts
        guard text.count > 10 else {
            return text.isEmpty ? [] : [text]
        }
        
        // Base case: if we're at the last separator or text is smaller than chunk size
        if separators.isEmpty || text.count <= chunkSize {
            return [text]
        }
        
        // Use autoreleasepool to free up memory sooner - important for large documents
        return autoreleasepool { () -> [String] in
            let separator = separators[0]
            let components = text.components(separatedBy: separator)
            
            // If splitting with this separator doesn't help, try the next one
            if components.count <= 1 {
                return splitTextRecursively(
                    text: text,
                    chunkSize: chunkSize,
                    chunkOverlap: chunkOverlap,
                    separators: Array(separators.dropFirst())
                )
            }
            
            var chunks: [String] = []
            chunks.reserveCapacity(max(1, text.count / (chunkSize / 2))) // Pre-allocate to avoid resizing
            var currentChunk = ""
            
            for component in components {
                // Check if we should start a new chunk
                let potentialChunk = currentChunk.isEmpty ? component : currentChunk + separator + component
                
                if potentialChunk.count <= chunkSize {
                    currentChunk = potentialChunk
                } else {
                    if !currentChunk.isEmpty {
                        chunks.append(currentChunk)
                    }
                    
                    // If the component itself is larger than the chunk size, recursively split it
                    if component.count > chunkSize {
                        let subChunks = autoreleasepool { () -> [String] in
                            return splitTextRecursively(
                                text: component,
                                chunkSize: chunkSize,
                                chunkOverlap: chunkOverlap,
                                separators: Array(separators.dropFirst())
                            )
                        }
                        chunks.append(contentsOf: subChunks)
                        currentChunk = ""
                    } else {
                        currentChunk = component
                    }
                }
            }
            
            // Add the last chunk if it's not empty
            if !currentChunk.isEmpty {
                chunks.append(currentChunk)
            }
            
            // Apply overlap if needed
            if chunkOverlap > 0 && chunks.count > 1 {
                var overlapChunks: [String] = []
                overlapChunks.reserveCapacity(chunks.count)
                
                for i in 0..<chunks.count {
                    autoreleasepool {
                        if i == 0 {
                            overlapChunks.append(chunks[i])
                        } else {
                            let previousChunk = chunks[i-1]
                            let currentChunk = chunks[i]
                            
                            // Calculate overlap from previous chunk
                            var overlapText = ""
                            if previousChunk.count > chunkOverlap {
                                let startIndex = previousChunk.index(previousChunk.endIndex, offsetBy: -chunkOverlap)
                                overlapText = String(previousChunk[startIndex...])
                            } else {
                                overlapText = previousChunk
                            }
                            
                            overlapChunks.append(overlapText + separator + currentChunk)
                        }
                    }
                }
                
                return overlapChunks
            }
            
            return chunks
        }
    }
    
    /// Generate a content hash for a text chunk
    /// - Parameter text: The text to hash
    /// - Returns: A hash string
    private func generateContentHash(for text: String) -> String {
        // For very large texts, only hash the first and last portions to improve performance
        if text.count > 5000 {
            let prefix = text.prefix(1000)
            let suffix = text.suffix(1000)
            let sampleText = "\(prefix)...\(suffix)"
            
            let data = Data(sampleText.utf8)
            let hash = CryptoKit.SHA256.hash(data: data)
            return hash.compactMap { String(format: "%02x", $0) }.joined()
        } else {
            let data = Data(text.utf8)
            let hash = CryptoKit.SHA256.hash(data: data)
            return hash.compactMap { String(format: "%02x", $0) }.joined()
        }
    }
    
    /// Tokenize text and return information about the tokens
    /// - Parameter text: The text to tokenize
    /// - Returns: Array of tokens with ranges
    func tokenizeText(_ text: String) -> [(token: String, range: NSRange)] {
        tokenizer.string = text
        var tokens: [(token: String, range: NSRange)] = []
        
        // Use Range<String.Index> for enumerateTokens
        let stringRange = text.startIndex..<text.endIndex
        tokenizer.enumerateTokens(in: stringRange) { tokenRange, _ in
            // Convert Range<String.Index> back to NSRange if needed for the return type
            let nsRange = NSRange(tokenRange, in: text)
            let token = String(text[tokenRange])
            tokens.append((token, nsRange))
            return true // Continue enumeration
        } // End of enumerateTokens closure
        
        return tokens // Return the collected tokens
    } // End of tokenizeText function
}
