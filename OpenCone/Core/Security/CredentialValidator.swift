import Foundation

/// Result of a credential validation check
enum CredentialStatus: Equatable {
    case unknown
    case validating
    case valid
    case invalid(message: String)
    case rateLimited(retryAfterSeconds: Int)
}

/// Performs lightweight, non-destructive credential validation against provider APIs.
/// - OpenAI: GET /v1/models (cheap and fast)
/// - Pinecone: GET /indexes with Api-Key + X-Project-Id (controller endpoint)
final class CredentialValidator {
    private let logger = Logger.shared
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - OpenAI

    /// Validates the OpenAI API key by fetching the model list.
    /// - Returns: CredentialStatus indicating validity or reason for failure.
    func validateOpenAIKey(_ apiKey: String) async -> CredentialStatus {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalid(message: "API key is empty")
        }

        if !apiKey.starts(with: "sk-") {
            // Allow non-prefixed temporarily but warn
            logger.log(level: .warning, message: "OpenAI key does not start with 'sk-'; attempting validation anyway.")
        }

        guard let url = URL(string: "https://api.openai.com/v1/models") else {
            return .invalid(message: "Invalid OpenAI models endpoint")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .invalid(message: "Invalid HTTP response")
            }

            if http.statusCode == 200 {
                return .valid
            }

            let retryAfter = (http.value(forHTTPHeaderField: "retry-after")).flatMap { Int($0) }

            if http.statusCode == 401 {
                let message = decodeOpenAIErrorMessage(data) ?? "Unauthorized: Invalid API key"
                return .invalid(message: message)
            }

            if http.statusCode == 429 {
                return .rateLimited(retryAfterSeconds: retryAfter ?? 60)
            }

            let generic = decodeOpenAIErrorMessage(data) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            return .invalid(message: "OpenAI error \(http.statusCode): \(generic)")
        } catch {
            logger.log(level: .error, message: "OpenAI validation request failed: \(error.localizedDescription)")
            return .invalid(message: "Network error: \(error.localizedDescription)")
        }
    }

    private func decodeOpenAIErrorMessage(_ data: Data) -> String? {
        struct OpenAIErrorResponse: Decodable { let error: Inner; struct Inner: Decodable { let message: String } }
        if let decoded = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
            return decoded.error.message
        }
        return nil
    }

    // MARK: - Pinecone

    /// Validates the Pinecone credentials by listing indexes using controller API.
    /// - Parameters:
    ///   - apiKey: Pinecone API key (pcsk_)
    ///   - projectId: Pinecone Project ID (required for JWT auth)
    func validatePinecone(apiKey: String, projectId: String) async -> CredentialStatus {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let pid = projectId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !key.isEmpty else { return .invalid(message: "Pinecone API key is empty") }
        if !key.hasPrefix("pcsk_") {
            logger.log(level: .warning, message: "Pinecone key does not start with 'pcsk_'; attempting validation anyway.")
        }
        guard !pid.isEmpty else { return .invalid(message: "Pinecone Project ID is required") }

        guard let url = URL(string: "https://api.pinecone.io/indexes") else {
            return .invalid(message: "Invalid Pinecone controller endpoint")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "Api-Key")
        request.setValue(pid, forHTTPHeaderField: "X-Project-Id")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .invalid(message: "Invalid HTTP response")
            }

            if http.statusCode == 200 {
                return .valid
            }

            // Pinecone may return 401 or 403 for auth problems, 429 for rate limit
            if http.statusCode == 401 || http.statusCode == 403 {
                let message = decodePineconeErrorMessage(data) ?? "Unauthorized: Invalid API key or Project ID"
                return .invalid(message: message)
            }

            if http.statusCode == 429 {
                // Pinecone does not always include retry-after, default to 30s
                return .rateLimited(retryAfterSeconds: 30)
            }

            let generic = decodePineconeErrorMessage(data) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            return .invalid(message: "Pinecone error \(http.statusCode): \(generic)")
        } catch {
            logger.log(level: .error, message: "Pinecone validation request failed: \(error.localizedDescription)")
            return .invalid(message: "Network error: \(error.localizedDescription)")
        }
    }

    private func decodePineconeErrorMessage(_ data: Data) -> String? {
        struct PineconeErrorResponse: Decodable { let message: String? }
        if let decoded = try? JSONDecoder().decode(PineconeErrorResponse.self, from: data) {
            return decoded.message
        }
        return nil
    }
}
