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

    // MARK: - Dynamic settings accessors

    private func currentCompletionModel() -> String {
        return UserDefaults.standard.string(forKey: "completionModel") ?? completionModel
    }

    private func currentEmbeddingModel() -> String {
        return UserDefaults.standard.string(forKey: "embeddingModel") ?? embeddingModel
    }

    private func currentTemperature() -> Double {
        return (UserDefaults.standard.object(forKey: "openai.temperature") as? Double) ?? 0.3
    }

    private func currentTopP() -> Double {
        return (UserDefaults.standard.object(forKey: "openai.topP") as? Double) ?? 0.95
    }

    private func currentReasoningEffort() -> String {
        return UserDefaults.standard.string(forKey: "openai.reasoningEffort") ?? "medium"
    }

    // MARK: - Conversation input builder

    private let maxHistoryMessages = 8

    private func buildResponsesInput(systemPrompt: String, context: String, history: [ChatMessage], userMessage: String) -> [[String: Any]] {
        // System message includes instructions and retrieved context
        Logger.shared.log(level: .info, message: "Building Responses input", context: "contextLength=\(context.count)")
        if !context.isEmpty {
            Logger.shared.log(level: .info, message: "Context preview", context: String(context.prefix(200)))
        } else {
            Logger.shared.log(level: .warning, message: "Warning: Context is EMPTY!")
        }
        
        let systemContent: [[String: Any]] = [
            ["type": "input_text", "text": "\(systemPrompt)\n\nContext:\n\(context)"]
        ]

        // Map bounded history into Responses "input" items
        let boundedHistory = Array(history.suffix(maxHistoryMessages))
        var historyItems: [[String: Any]] = []
        for msg in boundedHistory {
            let role = (msg.role == .user) ? "user" : "assistant"
            historyItems.append([
                "role": role,
                "content": [
                    ["type": "input_text", "text": msg.text]
                ]
            ])
        }

        // Current user turn is always the last item
        let currentUser: [[String: Any]] = [
            ["role": "user", "content": [["type": "input_text", "text": userMessage]]]
        ]

        // Compose in order: system, history..., current user
        return [["role": "system", "content": systemContent]] + historyItems + currentUser
    }
    
    /// Create embeddings for a list of texts, optionally with a specific dimension
    /// - Parameters:
    ///   - texts: Array of text strings
    ///   - dimension: The desired vector dimension
    /// - Returns: Array of vector embeddings
    func createEmbeddings(texts: [String], dimension: Int? = nil) async throws -> [[Float]] {
        guard !texts.isEmpty else {
            return []
        }
        
        let endpoint = "\(baseURL)/embeddings"
        var body: [String: Any] = [
            "input": texts,
            "model": currentEmbeddingModel()
        ]
        
        // Add dimension to the request if provided, otherwise use the default
        body["dimensions"] = dimension ?? Configuration.embeddingDimension
        
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
    
    /// Generate a completion using the OpenAI Responses API (v1/responses)
    /// - Parameters:
    ///   - systemPrompt: The system prompt
    ///   - userMessage: The user message
    ///   - context: The context from retrieved documents
    /// - Returns: Generated completion text
    func generateCompletion(systemPrompt: String, userMessage: String, context: String, history: [ChatMessage] = [], conversationId: String? = nil, onConversationId: ((String) -> Void)? = nil) async throws -> String {
        let endpoint = "\(baseURL)/responses"

        // Build Responses API "input" with conversation history
        let input: [[String: Any]] = buildResponsesInput(systemPrompt: systemPrompt, context: context, history: history, userMessage: userMessage)

        let model = currentCompletionModel()
        var body: [String: Any] = [
            "model": model,
            "input": input,
            // Responses API uses max_output_tokens instead of max_tokens
            "max_output_tokens": 1000,
            "store": false
        ]

        if Configuration.isReasoningModel(model) {
            body["reasoning"] = ["effort": currentReasoningEffort()]
        } else {
            body["temperature"] = currentTemperature()
            body["top_p"] = currentTopP()
        }
        if let convId = conversationId {
            body["conversation"] = convId
        }

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
                logger.log(level: .error, message: "OpenAI Responses API error: \(errorMessage?.error.message ?? "Unknown error")")
                throw APIError.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage?.error.message)
            }

            // Prefer output_text convenience field if present; otherwise synthesize from output[].message.content[]
            struct ResponsesEnvelope: Decodable {
                let output_text: String?
                let output: [OutputItem]?
                let conversation: ConversationEnvelope?
                struct OutputItem: Decodable {
                    let type: String?
                    let message: Message?
                    struct Message: Decodable {
                        let content: [ContentItem]?
                        struct ContentItem: Decodable {
                            let type: String?
                            let text: String?
                        }
                    }
                }
                struct ConversationEnvelope: Decodable {
                    let id: String?
                }
            }

            if let envelope = try? JSONDecoder().decode(ResponsesEnvelope.self, from: data) {
                if let conv = envelope.conversation?.id, conv.hasPrefix("conv") {
                    onConversationId?(conv)
                }
                if let text = envelope.output_text, !text.isEmpty {
                    return text
                }
                if let items = envelope.output {
                    var collected = [String]()
                    for item in items {
                        // Collect message content text blocks
                        if let content = item.message?.content {
                            for c in content {
                                if let t = c.text, !t.isEmpty {
                                    collected.append(t)
                                }
                            }
                        }
                    }
                    if !collected.isEmpty {
                        return collected.joined(separator: "\n")
                    }
                }
                // Fallthrough if structure changed
            }

            // As a last resort, try to decode a minimal string from JSON
            if let fallbackString = String(data: data, encoding: .utf8) {
                logger.log(level: .warning, message: "Unexpected Responses payload; returning raw text fallback")
                return fallbackString
            }

            throw APIError.noCompletionGenerated
        } catch {
            logger.log(level: .error, message: "Responses completion request failed: \(error.localizedDescription)")
            throw APIError.requestFailed(statusCode: 0, message: error.localizedDescription)
        }
    }
    /// Stream a completion using the OpenAI Responses API (SSE events)
    /// Parses event: response.output_text.delta to stream text and response.completed to finish
    func streamCompletion(
        systemPrompt: String,
        userMessage: String,
        context: String,
        history: [ChatMessage] = [],
        conversationId: String? = nil,
        onConversationId: ((String) -> Void)? = nil,
        onTextDelta: @escaping (String) -> Void,
        onCompleted: @escaping () -> Void
    ) async throws {
        let endpoint = "\(baseURL)/responses"

        // Build Responses API "input" with conversation history
        let input: [[String: Any]] = buildResponsesInput(systemPrompt: systemPrompt, context: context, history: history, userMessage: userMessage)

        let model = currentCompletionModel()
        var body: [String: Any] = [
            "model": model,
            "input": input,
            "stream": true,
            // Responses API uses max_output_tokens instead of max_tokens
            "max_output_tokens": 1000,
            "store": false
        ]

        if Configuration.isReasoningModel(model) {
            body["reasoning"] = ["effort": currentReasoningEffort()]
        } else {
            body["temperature"] = currentTemperature()
            body["top_p"] = currentTopP()
        }
        if let convId = conversationId {
            body["conversation"] = convId
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw APIError.invalidRequestData
        }

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData

        // Use URLSession AsyncBytes to consume SSE stream
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        if httpResponse.statusCode != 200 {
            // Try to read the error body to decode the error message
            var errorData = Data()
            do {
                for try await byte in bytes {
                    errorData.append(byte)
                }
            } catch { /* ignore read error for error body */ }

            if let err = try? JSONDecoder().decode(APIErrorResponse.self, from: errorData) {
                logger.log(level: .error, message: "OpenAI Responses stream error: \(err.error.message)")
                throw APIError.requestFailed(statusCode: httpResponse.statusCode, message: err.error.message)
            }
            throw APIError.requestFailed(statusCode: httpResponse.statusCode, message: "Streaming request failed")
        }

        var currentEvent: String? = nil
        var completedCalled = false
        var eventCount = 0
        func completeOnce() {
            if !completedCalled {
                completedCalled = true
                onCompleted()
            }
        }
        do {
            for try await line in bytes.lines {
                try Task.checkCancellation()
                if line.hasPrefix("event:") {
                    currentEvent = line.replacingOccurrences(of: "event:", with: "").trimmingCharacters(in: .whitespaces)
                    eventCount += 1
                    if eventCount <= 15 || currentEvent?.contains("reasoning") == true || currentEvent?.contains("text") == true {
                        logger.log(level: .info, message: "SSE event: \(currentEvent ?? "nil")")
                    }
                } else if line.hasPrefix("data:") {
                    let payload = line.replacingOccurrences(of: "data:", with: "").trimmingCharacters(in: .whitespaces)
                    if eventCount <= 15 || currentEvent?.contains("reasoning") == true || currentEvent?.contains("text") == true {
                        logger.log(level: .info, message: "SSE data for event '\(currentEvent ?? "nil")': \(payload.prefix(200))")
                    }
                    // Handle completion (also try to capture conversation id from payload)
                    if currentEvent == "response.completed" {
                        if let data = payload.data(using: .utf8),
                           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            // Attempt multiple shapes to find conversation id
                            func extractConvId(from any: Any?) -> String? {
                                if let s = any as? String { return s }
                                if let dict = any as? [String: Any] {
                                    if let s = dict["id"] as? String { return s }
                                    if let nested = dict["conversation"] { return extractConvId(from: nested) }
                                    if let resp = dict["response"] { return extractConvId(from: resp) }
                                }
                                return nil
                            }
                            let convId = extractConvId(from: obj["conversation"]) ?? extractConvId(from: obj["response"])
                            if let conv = convId, conv.hasPrefix("conv") {
                                onConversationId?(conv)
                            }
                        }
                        completeOnce()
                        currentEvent = nil
                        continue
                    }
                    // Handle text delta
                    if currentEvent == "response.output_text.delta" {
                        if payload == "[DONE]" {
                            completeOnce()
                            currentEvent = nil
                            continue
                        }
                        if let data = payload.data(using: .utf8) {
                            // Try JSON decode first, then fallback to raw text
                            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                if let delta = obj["delta"] as? String {
                                    logger.log(level: .info, message: "Extracted delta: '\(delta)'")
                                    onTextDelta(delta)
                                } else if let text = obj["text"] as? String {
                                    logger.log(level: .info, message: "Extracted text: '\(text.prefix(50))'")
                                    onTextDelta(text)
                                } else {
                                    logger.log(level: .warning, message: "No delta or text in payload, keys: \(obj.keys)")
                                    if let s = String(data: data, encoding: .utf8) {
                                        onTextDelta(s)
                                    }
                                }
                            } else {
                                logger.log(level: .warning, message: "Failed to decode JSON, using raw payload")
                                onTextDelta(payload)
                            }
                        } else {
                            onTextDelta(payload)
                        }
                    }
                }
            }
            // If stream ended without explicit completed event, still signal completion
            completeOnce()
        } catch is CancellationError {
            logger.log(level: .info, message: "Responses streaming cancelled by user")
            throw CancellationError()
        } catch {
            logger.log(level: .error, message: "Responses streaming failed: \(error.localizedDescription)")
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

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidRequestData:
            return "Invalid request data"
        case .invalidResponse:
            return "Invalid response from server"
        case .requestFailed(let statusCode, let message):
            if let message, !message.isEmpty {
                return message
            }
            return statusCode == 0 ? "Request failed" : "Request failed with status code \(statusCode)"
        case .noCompletionGenerated:
            return "No completion generated"
        case .decodingFailed:
            return "Failed to decode response"
        }
    }
}
