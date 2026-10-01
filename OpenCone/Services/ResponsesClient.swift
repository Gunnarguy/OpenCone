import Foundation

/// Non-streaming Responses API calls for the parts of a search that need the model's decisions
/// rather than streamed prose: picking where to search, and drafting an index's summary.
/// The answer itself still streams through `OpenAIService.streamCompletion`.
@MainActor
final class ResponsesClient {
    struct FunctionCall: Equatable {
        let callId: String
        let name: String
        /// JSON text, as the model wrote it
        let arguments: String
    }

    struct Reply: Equatable {
        let text: String
        let functionCalls: [FunctionCall]
        let status: String?
    }

    /// The person's model choices from Settings, applied the way the answer request applies them
    struct ModelOptions: Equatable {
        let model: String
        let reasoningEffort: String
        let temperature: Double
    }

    private var logger: Logger { Logger.shared }
    private let apiKey: String
    private let session: URLSession
    private let endpoint = URL(string: "https://api.openai.com/v1/responses")!

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    /// Create one response and return its text and function calls.
    /// - Parameters:
    ///   - instructions: The system instructions
    ///   - input: Input items (messages)
    ///   - options: Model, reasoning effort and temperature
    ///   - tools: Function tools the model may call; the model may call several in one turn
    ///   - maxOutputTokens: Output budget, which reasoning models also spend on reasoning
    func create(
        instructions: String,
        input: [[String: Any]],
        options: ModelOptions,
        tools: [[String: Any]] = [],
        maxOutputTokens: Int
    ) async throws -> Reply {
        var body: [String: Any] = [
            "model": options.model,
            "instructions": instructions,
            "input": input,
            "max_output_tokens": maxOutputTokens,
            "store": false,
        ]

        if !tools.isEmpty {
            // Several calls in one turn is how a compare question searches both sides. Strict mode
            // still holds for them; OpenAI's function-calling guide (read 2026-10-01) drops it for
            // parallel calls only on fine-tuned models.
            body["tools"] = tools
            body["tool_choice"] = "auto"
            body["parallel_tool_calls"] = true
        }

        if Configuration.isReasoningModel(options.model) {
            body["reasoning"] = ["effort": options.reasoningEffort]
        } else {
            body["temperature"] = options.temperature
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw APIError.invalidRequestData
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = jsonData

        let (data, response) = try await session.data(for: request, delegate: APIActivity.recorder)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            logger.log(level: .error, message: "OpenAI Responses error: \(errorMessage?.error.message ?? "Unknown error")")
            throw APIError.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage?.error.message)
        }

        return try Self.parseReply(data)
    }

    /// The models the person's key can use, with any announced shutdown date (GET /v1/models), as OpenResponses
    /// lists them
    func listModels() async throws -> [OpenAIModel] {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.timeoutInterval = 30
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request, delegate: APIActivity.recorder)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        if httpResponse.statusCode != 200 {
            let errorMessage = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.requestFailed(statusCode: httpResponse.statusCode, message: errorMessage?.error.message)
        }

        do {
            return try JSONDecoder().decode(OpenAIModelsResponse.self, from: data).data.sorted { $0.id < $1.id }
        } catch {
            throw APIError.decodingFailed
        }
    }

    /// Read text and function calls out of a Responses API reply. Message items carry their text
    /// in `content[]` parts of type `output_text`; function calls are items of type `function_call`.
    static func parseReply(_ data: Data) throws -> Reply {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decodingFailed
        }

        var texts: [String] = []
        var calls: [FunctionCall] = []

        for item in json["output"] as? [[String: Any]] ?? [] {
            switch item["type"] as? String {
            case "message":
                for part in item["content"] as? [[String: Any]] ?? [] where part["type"] as? String == "output_text" {
                    if let text = part["text"] as? String, !text.isEmpty {
                        texts.append(text)
                    }
                }
            case "function_call":
                if let name = item["name"] as? String, let arguments = item["arguments"] as? String {
                    calls.append(FunctionCall(callId: item["call_id"] as? String ?? "", name: name, arguments: arguments))
                }
            default:
                break
            }
        }

        // SDKs expose an `output_text` convenience; accept it if a reply carries one
        if texts.isEmpty, let outputText = json["output_text"] as? String, !outputText.isEmpty {
            texts.append(outputText)
        }

        return Reply(text: texts.joined(separator: "\n"), functionCalls: calls, status: json["status"] as? String)
    }
}
