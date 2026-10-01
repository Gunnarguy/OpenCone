import Foundation
@testable import OpenCone

/// Answers each request from a handler that sees the whole request, so one test can stand in for
/// Pinecone's control plane, an index host, and OpenAI at once
final class RouteMockURLProtocol: URLProtocol {
    static var handler: ((URLRequest, Data?) throws -> (Int, Data))?
    static var requests: [(url: URL, body: [String: Any]?)] = []

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let body = Self.bodyData(of: request)
        let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        Self.requests.append((url: request.url!, body: json))

        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (status, data) = try handler(request, body)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func reset() {
        handler = nil
        requests = []
    }

    /// URLSession hands a protocol the body as a stream
    static func bodyData(of request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: bufferSize)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }

    static func sessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RouteMockURLProtocol.self]
        return configuration
    }
}

func jsonData(_ object: Any) -> Data {
    try! JSONSerialization.data(withJSONObject: object)
}

func makeProfile(
    _ name: String,
    namespaces: [(String, Int)] = [("", 10)],
    dimension: Int = 1536,
    model: String? = "text-embedding-3-small",
    check: IndexProfile.ModelCheck = .matched,
    summary: String = ""
) -> IndexProfile {
    IndexProfile(
        name: name,
        dimension: dimension,
        metric: "cosine",
        namespaces: namespaces.map { IndexProfile.Namespace(name: $0.0, vectorCount: $0.1) },
        embeddingModel: model,
        modelCheck: check,
        modelSimilarity: check == .matched ? 0.999 : nil,
        summary: summary,
        summarySource: summary.isEmpty ? .missing : .drafted,
        surveyedAt: Date()
    )
}
