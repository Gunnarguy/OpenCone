import Foundation

// MARK: - Code Interpreter Output Models

/// Represents output from OpenAI's code interpreter tool
struct CodeInterpreterOutput: Identifiable, Equatable {
    let id: String
    let type: OutputType
    let content: String

    enum OutputType: String, Equatable {
        case logs // stdout/stderr from Python execution
        case image // Base64 PNG or image URL
        case error // Execution error
    }

    init(id: String = UUID().uuidString, type: OutputType, content: String) {
        self.id = id
        self.type = type
        self.content = content
    }
}

/// Service for interacting with OpenAI API
@MainActor
final class OpenAIService: Sendable {

    private var logger: Logger { Logger.shared }
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
        return UserDefaults.standard.string(forKey: "openai.reasoningEffort") ?? "none"
    }

    private func isWebSearchEnabled() -> Bool {
        return (UserDefaults.standard.object(forKey: "search.webSearchEnabled") as? Bool) ?? false
    }

    private func isCodeInterpreterEnabled() -> Bool {
        return (UserDefaults.standard.object(forKey: "search.codeInterpreterEnabled") as? Bool) ?? false
    }

    private func currentMaxOutputTokens() -> Int {
        let stored = UserDefaults.standard.integer(forKey: "search.maxOutputTokens")
        return stored > 0 ? stored : 1000
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
    func generateCompletion(systemPrompt: String, userMessage: String, context: String, history: [ChatMessage] = [], conversationId: String? = nil, onConversationId: ((String) -> Void)? = nil, allowCodeInterpreter: Bool = false) async throws -> String { 
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
        if allowCodeInterpreter, isCodeInterpreterEnabled() {
            body["tools"] = [[
                "type": "code_interpreter",
                "container": ["type": "auto"],
            ]]
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
        allowCodeInterpreter: Bool = true,
        onCodeInterpreterOutput: ((CodeInterpreterOutput) -> Void)? = nil,
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
            "max_output_tokens": currentMaxOutputTokens(),
            "store": false
        ]

        // Build include array for tool outputs
        var includes: [String] = []
        if allowCodeInterpreter, isCodeInterpreterEnabled() {
            includes.append("code_interpreter_call.outputs")
        }

        if isWebSearchEnabled() {
            includes.append("web_search_call.action.sources")
        }

        if !includes.isEmpty {
            body["include"] = includes
        }

        if Configuration.isReasoningModel(model) {
            body["reasoning"] = ["effort": currentReasoningEffort()]
        } else {
            body["temperature"] = currentTemperature()
            body["top_p"] = currentTopP()
        }

        // Build tools array from enabled features
        var tools: [[String: Any]] = []

        if isWebSearchEnabled() {
            tools.append(["type": "web_search"])
        }

        if allowCodeInterpreter, isCodeInterpreterEnabled() {
            // Code interpreter requires a container parameter
            // Using auto mode creates a new container or reuses an existing one
            tools.append([
                "type": "code_interpreter",
                "container": [
                    "type": "auto",
                ],
            ])
        }

        if !tools.isEmpty {
            body["tools"] = tools
        }

        if let convId = conversationId {
            body["conversation"] = convId
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw APIError.invalidRequestData
        }

        // Log request details for debugging
        #if DEBUG
            let toolsList = tools.compactMap { $0["type"] as? String }.joined(separator: ",")
            Logger.shared.log(level: .debug, message: "OpenAI Responses request", context: "model=\(model); tools=\(toolsList.isEmpty ? "none" : toolsList)")
        #endif

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
        var deltaCount = 0
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
                    // Only log non-delta events and first few of each type
                    let isImportantEvent = currentEvent == "response.created" ||
                        currentEvent == "response.completed" ||
                        currentEvent == "response.in_progress" ||
                        currentEvent?.contains("reasoning") == true ||
                        currentEvent == "response.output_item.added" ||
                        currentEvent == "response.output_item.done"
                    if isImportantEvent, eventCount <= 10 {
                        logger.log(level: .debug, message: "SSE event: \(currentEvent ?? "nil")")
                    }
                } else if line.hasPrefix("data:") {
                    let payload = line.replacingOccurrences(of: "data:", with: "").trimmingCharacters(in: .whitespaces)
                    // Skip logging delta data payloads entirely - too verbose
                    let isImportantEvent = currentEvent == "response.created" ||
                        currentEvent == "response.completed" ||
                        currentEvent?.contains("reasoning") == true
                    if isImportantEvent, eventCount <= 10 {
                        logger.log(level: .debug, message: "SSE data for event '\(currentEvent ?? "nil")': \(payload.prefix(200))")
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
                    // Handle text delta - check multiple event types used by Responses API
                    // response.output_text.delta - standard text streaming
                    // response.content_part.delta - alternative format with tools
                    // response.text.delta - another variant
                    let isTextDeltaEvent = currentEvent == "response.output_text.delta" ||
                        currentEvent == "response.content_part.delta" ||
                        currentEvent == "response.text.delta" ||
                        currentEvent == "response.output_item.delta"

                    if isTextDeltaEvent {
                        deltaCount += 1
                        if payload == "[DONE]" {
                            completeOnce()
                            currentEvent = nil
                            continue
                        }
                        if let data = payload.data(using: .utf8) {
                            // Try JSON decode first, then fallback to raw text
                            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                                // Try multiple possible keys for the text content
                                let delta = obj["delta"] as? String ??
                                    obj["text"] as? String ??
                                    obj["content"] as? String ??
                                    (obj["part"] as? [String: Any])?["text"] as? String

                                if let delta = delta, !delta.isEmpty {
                                    // Only log first 3 deltas at debug level
                                    if deltaCount <= 3 {
                                        logger.log(level: .debug, message: "Extracted delta: '\(delta.prefix(20))'")
                                    }
                                    onTextDelta(delta)
                                } else {
                                    // Only log warnings occasionally to avoid spam
                                    if deltaCount <= 3 {
                                        logger.log(level: .warning, message: "No text found in payload, keys: \(obj.keys)")
                                    }
                                }
                            } else {
                                if deltaCount <= 3 { 
                                    logger.log(level: .warning, message: "Failed to decode JSON, using raw payload")
                                }
                                onTextDelta(payload)
                            }
                        } else {
                            onTextDelta(payload)
                        }
                    }

                    // Handle response.output_item.done which may contain final text content
                    if currentEvent == "response.output_item.done" {
                        if let data = payload.data(using: .utf8),
                           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        {
                            // Check for message content in the done event
                            if let item = obj["item"] as? [String: Any],
                               let content = item["content"] as? [[String: Any]]
                            {
                                for c in content {
                                    if let text = c["text"] as? String, !text.isEmpty {
                                        logger.log(level: .debug, message: "Extracted final text from output_item.done: '\(text.prefix(50))'")
                                        onTextDelta(text)
                                        deltaCount += 1
                                    }
                                }
                            }

                            // Check for code interpreter output in the done event
                            if let item = obj["item"] as? [String: Any],
                               let itemType = item["type"] as? String,
                               itemType == "code_interpreter_call"
                            {
                                parseCodeInterpreterItem(item, callback: onCodeInterpreterOutput)
                            }
                        }
                    }

                    // Handle code interpreter specific events
                    let isCodeInterpreterEvent = currentEvent == "response.code_interpreter_call.completed" ||
                        currentEvent == "response.code_interpreter_call_output.done" ||
                        currentEvent == "response.code_interpreter_call.in_progress"

                    if isCodeInterpreterEvent {
                        if let data = payload.data(using: .utf8),
                           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                        {
                            parseCodeInterpreterItem(obj, callback: onCodeInterpreterOutput)
                        }
                    }
                }
            }
            // Log final stats
            if deltaCount == 0 {
                logger.log(level: .warning, message: "OpenAI stream completed with no text deltas received")
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

    // MARK: - Code Interpreter Parsing

    /// Parse code interpreter output from SSE payload
    private func parseCodeInterpreterItem(_ obj: [String: Any], callback: ((CodeInterpreterOutput) -> Void)?) {
        guard let callback = callback else { return }

        // Try to get outputs array from various possible locations
        let outputs: [[String: Any]]? = obj["outputs"] as? [[String: Any]] ??
            (obj["item"] as? [String: Any])?["outputs"] as? [[String: Any]] ??
            (obj["code_interpreter_call"] as? [String: Any])?["outputs"] as? [[String: Any]]

        if let outputs = outputs {
            for output in outputs {
                if let outputType = output["type"] as? String {
                    switch outputType {
                    case "logs":
                        if let logs = output["logs"] as? String, !logs.isEmpty {
                            logger.log(level: .info, message: "Code interpreter logs: \(logs.prefix(100))")
                            callback(CodeInterpreterOutput(type: .logs, content: logs))
                        }
                    case "image":
                        // Image can be base64 data or a URL
                        if let imageData = output["image"] as? [String: Any] {
                            if let base64 = imageData["data"] as? String {
                                logger.log(level: .info, message: "Code interpreter generated image (base64, \(base64.count) chars)")
                                callback(CodeInterpreterOutput(type: .image, content: base64))
                            } else if let url = imageData["url"] as? String {
                                logger.log(level: .info, message: "Code interpreter generated image URL")
                                callback(CodeInterpreterOutput(type: .image, content: url))
                            }
                        }
                    default:
                        logger.log(level: .debug, message: "Unknown code interpreter output type: \(outputType)")
                    }
                }
            }
        }

        // Check for error in execution
        if let error = obj["error"] as? String, !error.isEmpty {
            logger.log(level: .warning, message: "Code interpreter error: \(error)")
            callback(CodeInterpreterOutput(type: .error, content: error))
        }

        // Also check for code that was executed (useful for display)
        if let code = obj["code"] as? String ?? (obj["item"] as? [String: Any])?["code"] as? String,
           !code.isEmpty
        {
            logger.log(level: .debug, message: "Code interpreter executed: \(code.prefix(100))")
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
