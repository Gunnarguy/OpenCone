import Foundation

/// Service for interacting with OpenAI API
class OpenAIService {
    
    private let logger = Logger.shared
    private let apiKey: String
    private let embeddingModel: String
    private let completionModel: String
    private let baseURL = "https://api.openai.com/v1"
    
    init(apiKey: String, embeddingModel: String = Configuration.embeddingModel, completionModel: String = Configuration.completionModel) {
        self.apiKey = apiKey
        self.embeddingModel = embeddingModel
        self.completionModel = completionModel
    }
    
    /// Create embeddings for a list of texts
    /// - Parameter texts: Array of text strings
    /// - Returns: Array of vector embeddings
    func createEmbeddings(texts: [String]) async throws -> [[Float]] {
        guard !texts.isEmpty else {
            return []
        }
        
        let endpoint = "\(baseURL)/embeddings"
        let body: [String: Any] = [
            "input": texts,
            "model": embeddingModel,
            "dimensions": Configuration.embeddingDimension
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw APIError.invalidRequestData
        }
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                logger.log(level: .error, message: "OpenAI API error: \(errorMessage?.error.message ?? "Unknown error")")
                throw APIError.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage?.error.message)
            }
            
            let embeddingResponse = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
            return embeddingResponse.data.map { $0.embedding }
        } catch {
            logger.log(level: .error, message: "Embedding request failed: \(error.localizedDescription)")
            throw APIError.requestFailed(statusCode: 0, message: error.localizedDescription)
        }
    }
    
    /// Generate a completion using the OpenAI API
    /// - Parameters:
    ///   - systemPrompt: The system prompt
    ///   - userMessage: The user message
    ///   - context: The context from retrieved documents
    /// - Returns: Generated completion text
    func generateCompletion(systemPrompt: String, userMessage: String, context: String) async throws -> String {
        let endpoint = "\(baseURL)/chat/completions"
        
        // Construct the messages array
        let messages: [[String: String]] = [
            ["role": "system", "content": "\(systemPrompt)\n\nContext:\n\(context)"],
            ["role": "user", "content": userMessage]
        ]
        
        let body: [String: Any] = [
            "model": completionModel,
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": 1000
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw APIError.invalidRequestData
        }
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                logger.log(level: .error, message: "OpenAI API error: \(errorMessage?.error.message ?? "Unknown error")")
                throw APIError.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage?.error.message)
            }
            
            let completionResponse = try JSONDecoder().decode(CompletionResponse.self, from: data)
            
            guard let firstChoice = completionResponse.choices.first else {
                throw APIError.noCompletionGenerated
            }
            
            return firstChoice.message.content
        } catch {
            logger.log(level: .error, message: "Completion request failed: \(error.localizedDescription)")
            throw APIError.requestFailed(statusCode: 0, message: error.localizedDescription)
        }
    }
}

// MARK: - Response Models

struct EmbeddingResponse: Codable {
    let data: [EmbeddingData]
    let model: String
    let usage: Usage
}

struct EmbeddingData: Codable {
    let embedding: [Float]
    let index: Int
    let object: String
}

struct CompletionResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage
}

struct Choice: Codable {
    let index: Int
    let message: Message
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index
        case message
        case finishReason = "finish_reason"
    }
}

struct Message: Codable {
    let role: String
    let content: String
}

struct Usage: Codable {
    let promptTokens: Int
    let completionTokens: Int?
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

struct APIErrorResponse: Codable {
    let error: APIErrorDetail
}

struct APIErrorDetail: Codable {
    let message: String
    let type: String
    let param: String?
    let code: String?
}

enum APIError: Error {
    case invalidRequestData
    case invalidResponse
    case requestFailed(statusCode: Int, message: String?)
    case noCompletionGenerated
    case decodingFailed
}
