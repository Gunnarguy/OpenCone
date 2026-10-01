import Combine
import Foundation

/// A service OpenCone talks to
enum APIService: String, CaseIterable, Identifiable {
    case openAI
    case openAIDocs
    case pineconeControl
    case pineconeInference
    case pineconeIndex

    var id: Self { self }

    var title: String {
        switch self {
        case .openAI: return "OpenAI"
        case .openAIDocs: return "OpenAI docs"
        case .pineconeControl: return "Pinecone, control plane"
        case .pineconeInference: return "Pinecone, inference"
        case .pineconeIndex: return "Pinecone, your index"
        }
    }

    var host: String {
        switch self {
        case .openAI: return "api.openai.com"
        case .openAIDocs: return "developers.openai.com"
        case .pineconeControl, .pineconeInference: return "api.pinecone.io"
        case .pineconeIndex: return "the index's own host"
        }
    }

    var systemImage: String {
        switch self {
        case .openAI: return "sparkles"
        case .openAIDocs: return "book"
        case .pineconeControl: return "cylinder.split.1x2"
        case .pineconeInference: return "arrow.up.arrow.down"
        case .pineconeIndex: return "magnifyingglass"
        }
    }
}

/// Every endpoint OpenCone calls: what it is, and what OpenCone uses it for. A request is matched to
/// one by its host, method and path, so the record never keeps the URL itself (an index host names
/// the index).
enum APIEndpoint: String, CaseIterable, Identifiable {
    case responses
    case embeddings
    case models
    case modelPages
    case listIndexes
    case describeIndex
    case createIndex
    case deleteIndex
    case rerank
    case sparseEmbed
    case query
    case upsert
    case deleteVectors
    case indexStats
    case listNamespaces
    case createNamespace
    case deleteNamespace

    var id: Self { self }

    var service: APIService {
        switch self {
        case .responses, .embeddings, .models: return .openAI
        case .modelPages: return .openAIDocs
        case .listIndexes, .describeIndex, .createIndex, .deleteIndex: return .pineconeControl
        case .rerank, .sparseEmbed: return .pineconeInference
        case .query, .upsert, .deleteVectors, .indexStats, .listNamespaces, .createNamespace, .deleteNamespace:
            return .pineconeIndex
        }
    }

    var method: String {
        switch self {
        case .models, .modelPages, .listIndexes, .describeIndex, .indexStats, .listNamespaces: return "GET"
        case .deleteIndex, .deleteNamespace: return "DELETE"
        default: return "POST"
        }
    }

    var path: String {
        switch self {
        case .responses: return "/v1/responses"
        case .embeddings: return "/v1/embeddings"
        case .models: return "/v1/models"
        case .modelPages: return "/api/docs/models/{model}.md"
        case .listIndexes: return "/indexes"
        case .describeIndex: return "/indexes/{index}"
        case .createIndex: return "/indexes"
        case .deleteIndex: return "/indexes/{index}"
        case .rerank: return "/rerank"
        case .sparseEmbed: return "/embed"
        case .query: return "/query"
        case .upsert: return "/vectors/upsert"
        case .deleteVectors: return "/vectors/delete"
        case .indexStats: return "/describe_index_stats"
        case .listNamespaces: return "/namespaces"
        case .createNamespace: return "/namespaces"
        case .deleteNamespace: return "/namespaces/{namespace}"
        }
    }

    /// The endpoint's name in OpenAI's or Pinecone's API reference
    var title: String {
        switch self {
        case .responses: return "Create a response"
        case .embeddings: return "Create embeddings"
        case .models: return "List models"
        case .modelPages: return "Model page"
        case .listIndexes: return "List indexes"
        case .describeIndex: return "Describe an index"
        case .createIndex: return "Create an index"
        case .deleteIndex: return "Delete an index"
        case .rerank: return "Rerank results"
        case .sparseEmbed: return "Generate sparse vectors"
        case .query: return "Query vectors"
        case .upsert: return "Upsert vectors"
        case .deleteVectors: return "Delete vectors"
        case .indexStats: return "Describe index stats"
        case .listNamespaces: return "List namespaces"
        case .createNamespace: return "Create a namespace"
        case .deleteNamespace: return "Delete a namespace"
        }
    }

    var purpose: String {
        switch self {
        case .responses: return "Writes each answer as it streams, picks where Auto searches, and drafts each index's summary"
        case .embeddings: return "Turns questions and document passages into vectors, and checks which model built each index"
        case .models: return "Lists the models your key can use, once per launch, and checks the key"
        case .modelPages: return "Reads the settings of a newer model the app's list doesn't know yet"
        case .listIndexes: return "Lists your indexes, and checks the Pinecone key"
        case .describeIndex: return "Finds an index's host, dimensions and metric"
        case .createIndex: return "Creates an index from Documents"
        case .deleteIndex: return "Deletes an index from Documents"
        case .rerank: return "Reorders the passages found when reranking is on"
        case .sparseEmbed: return "Makes the keyword vector for hybrid search"
        case .query: return "Finds the passages closest to a question"
        case .upsert: return "Stores a document's passages"
        case .deleteVectors: return "Deletes a removed document's passages"
        case .indexStats: return "Counts the passages in each namespace, and checks Pinecone is up before a search"
        case .listNamespaces: return "Lists an index's namespaces"
        case .createNamespace: return "Creates a namespace from Documents"
        case .deleteNamespace: return "Deletes a namespace from Documents"
        }
    }

    /// The endpoint a request goes to, from its host, method and path
    static func classify(_ request: URLRequest) -> APIEndpoint? {
        guard let url = request.url, let host = url.host?.lowercased() else { return nil }
        let method = (request.httpMethod ?? "GET").uppercased()
        let parts = url.path.split(separator: "/").map(String.init)

        if host == "api.openai.com" {
            switch parts.dropFirst().first {
            case "responses": return .responses
            case "embeddings": return .embeddings
            case "models": return .models
            default: return nil
            }
        }
        if host == "developers.openai.com" {
            return url.path.contains("/docs/models/") ? .modelPages : nil
        }
        if host == "api.pinecone.io" {
            switch parts.first {
            case "indexes":
                if parts.count == 1 { return method == "POST" ? .createIndex : .listIndexes }
                return method == "DELETE" ? .deleteIndex : .describeIndex
            case "rerank": return .rerank
            case "embed": return .sparseEmbed
            default: return nil
            }
        }
        if host.hasSuffix(".pinecone.io") {
            switch parts.first {
            case "query": return .query
            case "describe_index_stats": return .indexStats
            case "namespaces":
                if parts.count > 1 { return .deleteNamespace }
                return method == "POST" ? .createNamespace : .listNamespaces
            case "vectors":
                switch parts.dropFirst().first {
                case "upsert": return .upsert
                case "delete": return .deleteVectors
                default: return nil
                }
            default: return nil
            }
        }
        return nil
    }
}

/// The Pinecone API version header a request carries, by the setting that names it. The metadata
/// fetch setting has no group: nothing in OpenCone calls fetch-by-metadata.
enum PineconeVersionGroup: String, CaseIterable {
    case controlPlane
    case dataPlane
    case namespaces

    var title: String {
        switch self {
        case .controlPlane: return "Control plane"
        case .dataPlane: return "Data plane"
        case .namespaces: return "Namespaces"
        }
    }
}

extension APIEndpoint {
    /// The version setting PineconeService applies to this endpoint; nil for OpenAI
    var pineconeVersionGroup: PineconeVersionGroup? {
        switch self {
        case .listIndexes, .describeIndex, .createIndex, .deleteIndex, .rerank, .sparseEmbed: return .controlPlane
        case .query, .upsert, .deleteVectors, .indexStats: return .dataPlane
        case .listNamespaces, .createNamespace, .deleteNamespace: return .namespaces
        case .responses, .embeddings, .models, .modelPages: return nil
        }
    }

    static func endpoints(of service: APIService) -> [APIEndpoint] {
        allCases.filter { $0.service == service }
    }
}

/// One finished request: which endpoint, how it ended, and how long it took. No URL, body or key.
struct APICall: Identifiable, Equatable {
    let id = UUID()
    let endpoint: APIEndpoint
    /// The HTTP status, or nil when no response came back (offline, cancelled, timed out)
    let status: Int?
    let duration: TimeInterval
    let date: Date

    var succeeded: Bool { status.map { (200..<300).contains($0) } ?? false }
}

/// The requests made since OpenCone opened, kept in memory only, for Settings > Advanced > Endpoints
@MainActor
final class APIActivity: ObservableObject {
    static let shared = APIActivity()
    /// Pass as the `delegate` of a URLSession request to have it recorded
    nonisolated static let recorder = APIActivityRecorder()

    static let keptCalls = 300

    @Published private(set) var calls: [APICall] = []

    func record(_ call: APICall) {
        calls.append(call)
        if calls.count > Self.keptCalls {
            calls.removeFirst(calls.count - Self.keptCalls)
        }
    }

    func lastCall(to endpoint: APIEndpoint) -> APICall? {
        calls.last { $0.endpoint == endpoint }
    }

    func calls(to endpoint: APIEndpoint) -> [APICall] {
        calls.filter { $0.endpoint == endpoint }
    }

    func clear() {
        calls.removeAll()
    }
}

/// A task delegate that reports each finished request to `APIActivity`. Stateless, so one instance
/// serves every request.
final class APIActivityRecorder: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard let request = task.originalRequest, let endpoint = APIEndpoint.classify(request) else { return }
        let call = APICall(
            endpoint: endpoint,
            status: (task.response as? HTTPURLResponse)?.statusCode,
            duration: metrics.taskInterval.duration,
            date: Date()
        )
        Task { @MainActor in
            APIActivity.shared.record(call)
        }
    }
}
