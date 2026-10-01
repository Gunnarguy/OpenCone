import XCTest
@testable import OpenCone

// The stand-in handler runs on URLSession's thread, so what it reads lives outside the test class
private let indexHost = "docs-abc123.svc.aped-1234.pinecone.io"
private let storedVector: [Float] = [0.1, 0.2, 0.3, 0.4]

private func describeReply(name: String, dimension: Int = 4, metric: String = "cosine") -> Data {
    jsonData([
        "name": name,
        "dimension": dimension,
        "metric": metric,
        "host": indexHost,
        "status": ["state": "Ready", "ready": true],
    ])
}

/// The model check, the parsing of Responses replies, searching any index by name, and one whole
/// survey against stand-ins for Pinecone and OpenAI
@MainActor
final class IndexSurveyTests: XCTestCase {

    override func setUp() {
        super.setUp()
        RouteMockURLProtocol.reset()
        // OpenAIService uses the shared session, so the stand-in is registered process-wide
        URLProtocol.registerClass(RouteMockURLProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(RouteMockURLProtocol.self)
        RouteMockURLProtocol.reset()
        super.tearDown()
    }

    // MARK: - Embedding model matcher

    func testCandidatesFollowWhatEachModelCanProduce() {
        XCTAssertEqual(EmbeddingModelMatcher.candidates(forDimension: 3072, preferred: nil), ["text-embedding-3-large"])
        XCTAssertEqual(
            EmbeddingModelMatcher.candidates(forDimension: 1536, preferred: nil),
            ["text-embedding-3-small", "text-embedding-3-large", "text-embedding-ada-002"]
        )
        XCTAssertEqual(
            EmbeddingModelMatcher.candidates(forDimension: 1536, preferred: "text-embedding-3-large"),
            ["text-embedding-3-large", "text-embedding-3-small", "text-embedding-ada-002"]
        )
        XCTAssertEqual(EmbeddingModelMatcher.candidates(forDimension: 1024, preferred: nil), ["text-embedding-3-small", "text-embedding-3-large"])
        XCTAssertEqual(EmbeddingModelMatcher.candidates(forDimension: 2048, preferred: "text-embedding-3-small"), ["text-embedding-3-large"])
        XCTAssertEqual(EmbeddingModelMatcher.candidates(forDimension: 4096, preferred: nil), [])
        XCTAssertEqual(EmbeddingModelMatcher.candidates(forDimension: 0, preferred: nil), [])
    }

    func testCosineSimilarity() throws {
        XCTAssertEqual(try XCTUnwrap(EmbeddingModelMatcher.cosineSimilarity([1, 2, 3], [2, 4, 6])), 1, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(EmbeddingModelMatcher.cosineSimilarity([1, 0], [0, 1])), 0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(EmbeddingModelMatcher.cosineSimilarity([1, 0], [-1, 0])), -1, accuracy: 1e-9)
        XCTAssertNil(EmbeddingModelMatcher.cosineSimilarity([1, 2], [1, 2, 3]))
        XCTAssertNil(EmbeddingModelMatcher.cosineSimilarity([0, 0], [1, 1]))
        XCTAssertNil(EmbeddingModelMatcher.cosineSimilarity([], []))
    }

    // MARK: - Responses replies

    func testParseReplyReadsMessageTextAndFunctionCalls() throws {
        let data = jsonData([
            "status": "completed",
            "output": [
                ["type": "reasoning", "summary": []],
                ["type": "message", "role": "assistant", "content": [
                    ["type": "output_text", "text": "First."],
                    ["type": "refusal", "refusal": "no"],
                    ["type": "output_text", "text": "Second."],
                ]],
                ["type": "function_call", "call_id": "call_1", "name": "search_index", "arguments": "{\"index\":\"a\"}"],
            ],
        ])

        let reply = try ResponsesClient.parseReply(data)

        XCTAssertEqual(reply.text, "First.\nSecond.")
        XCTAssertEqual(reply.functionCalls, [ResponsesClient.FunctionCall(callId: "call_1", name: "search_index", arguments: "{\"index\":\"a\"}")])
        XCTAssertEqual(reply.status, "completed")
    }

    func testParseReplyAcceptsTheSDKOutputTextField() throws {
        let reply = try ResponsesClient.parseReply(jsonData(["output_text": "ok"]))
        XCTAssertEqual(reply.text, "ok")
        XCTAssertTrue(reply.functionCalls.isEmpty)
    }

    func testCreateThrowsWithTheAPIMessageOnAnError() async {
        RouteMockURLProtocol.handler = { _, _ in
            (400, jsonData(["error": ["message": "Unsupported parameter: 'temperature'", "type": "invalid_request_error", "param": "temperature", "code": NSNull()]]))
        }
        let client = ResponsesClient(apiKey: "k", session: URLSession(configuration: RouteMockURLProtocol.sessionConfiguration()))

        do {
            _ = try await client.create(
                instructions: "i",
                input: [["role": "user", "content": "q"]],
                options: .init(model: "gpt-4o", reasoningEffort: "none", temperature: 0),
                maxOutputTokens: 10
            )
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Unsupported parameter: 'temperature'")
        }
    }

    // MARK: - Any index by name

    private func makePinecone() -> PineconeService {
        PineconeService(apiKey: "test", projectId: "test", sessionConfiguration: RouteMockURLProtocol.sessionConfiguration())
    }

    func testQueryByIndexUsesThatIndexsHostAndLeavesTheCurrentIndexAlone() async throws {
        let pinecone = makePinecone()
        RouteMockURLProtocol.handler = { request, _ in
            if request.url?.host == "api.pinecone.io" {
                return (200, describeReply(name: "docs", dimension: 4, metric: "cosine"))
            }
            return (200, jsonData([
                "matches": [["id": "v1", "score": 0.87, "values": [0.1, 0.2, 0.3, 0.4], "metadata": ["text": "Passage", "source": "a.pdf"]]],
                "namespace": "",
            ]))
        }

        let response = try await pinecone.query(index: "docs", vector: [1, 0, 0, 0], topK: 3, namespace: nil, includeValues: true)

        XCTAssertNil(pinecone.getCurrentIndex())
        XCTAssertNil(pinecone.indexHost)
        XCTAssertEqual(response.matches.first?.values, [0.1, 0.2, 0.3, 0.4])

        let queryCall = try XCTUnwrap(RouteMockURLProtocol.requests.last)
        XCTAssertEqual(queryCall.url.absoluteString, "https://\(indexHost)/query")
        let body = try XCTUnwrap(queryCall.body)
        XCTAssertEqual(body["topK"] as? Int, 3)
        XCTAssertEqual(body["includeValues"] as? Bool, true)
        XCTAssertNil(body["namespace"], "the default namespace is sent by leaving the field out")
        XCTAssertNil(body["sparseVector"])

        // The host is cached by the describe call, so a second query goes straight to the index
        _ = try await pinecone.query(index: "docs", vector: [1, 0, 0, 0], namespace: "ns1")
        XCTAssertEqual(RouteMockURLProtocol.requests.filter { $0.url.host == "api.pinecone.io" }.count, 1)
        XCTAssertEqual(RouteMockURLProtocol.requests.last?.body?["namespace"] as? String, "ns1")
    }

    func testHybridQueryByIndexWeightsBothVectors() async throws {
        let pinecone = makePinecone()
        RouteMockURLProtocol.handler = { request, _ in
            if request.url?.host == "api.pinecone.io" {
                return (200, describeReply(name: "docs", dimension: 2, metric: "dotproduct"))
            }
            return (200, jsonData(["matches": [], "namespace": "ns"]))
        }

        _ = try await pinecone.query(
            index: "docs",
            vector: [1, 1],
            hybrid: (sparse: PineconeService.SparseVector(indices: [3, 7], values: [2, 4]), alpha: 0.25),
            namespace: "ns"
        )

        let body = try XCTUnwrap(RouteMockURLProtocol.requests.last?.body)
        XCTAssertEqual(body["vector"] as? [Double], [0.25, 0.25])
        let sparse = try XCTUnwrap(body["sparseVector"] as? [String: Any])
        XCTAssertEqual(sparse["indices"] as? [Int], [3, 7])
        XCTAssertEqual(sparse["values"] as? [Double], [1.5, 3.0])
    }

    // MARK: - A whole survey

    /// Pinecone describes a 4-dimension index with two namespaces; a sample query returns one
    /// passage with its stored vector. text-embedding-3-small returns a different vector for that
    /// passage and text-embedding-3-large reproduces it, so the survey settles on 3-large.
    private func installSurveyStandIns(summary: String = "Infusion pump manuals by manufacturer.") {
        let stored = storedVector
        RouteMockURLProtocol.handler = { request, body in
            let url = request.url!
            switch (url.host, url.path) {
            case ("api.pinecone.io", "/indexes/docs"):
                return (200, describeReply(name: "docs", dimension: 4, metric: "cosine"))
            case (_, "/describe_index_stats"):
                return (200, jsonData([
                    "namespaces": ["": ["vectorCount": 3], "baxter": ["vectorCount": 5]],
                    "dimension": 4,
                    "totalVectorCount": 8,
                ]))
            case (_, "/query"):
                return (200, jsonData([
                    "matches": [["id": "v1", "score": 0.5, "values": stored,
                                 "metadata": ["text": "Clear the occlusion before restarting the infusion."]]],
                    "namespace": "",
                ]))
            case ("api.openai.com", "/v1/embeddings"):
                let json = (try? JSONSerialization.jsonObject(with: body ?? Data())) as? [String: Any]
                let model = json?["model"] as? String
                let vector: [Float] = model == "text-embedding-3-large" ? stored : [0.4, -0.3, 0.2, -0.1]
                return (200, jsonData([
                    "data": [["embedding": vector, "index": 0, "object": "embedding"]],
                    "model": model ?? "",
                    "usage": ["prompt_tokens": 9, "total_tokens": 9],
                ]))
            case ("api.openai.com", "/v1/responses"):
                return (200, jsonData(["output": [["type": "message", "content": [["type": "output_text", "text": summary]]]]]))
            default:
                return (404, Data())
            }
        }
    }

    private func makeSurveyor() -> IndexSurveyor {
        let openAI = OpenAIService(apiKey: "test")
        return IndexSurveyor(
            pinecone: makePinecone(),
            embeddings: EmbeddingService(openAIService: openAI),
            responses: ResponsesClient(apiKey: "test", session: URLSession(configuration: RouteMockURLProtocol.sessionConfiguration()))
        )
    }

    private let summaryOptions = ResponsesClient.ModelOptions(model: "gpt-4o", reasoningEffort: "none", temperature: 0.2)

    func testSurveyFindsTheModelThatReproducesTheStoredVectorAndDraftsASummary() async throws {
        installSurveyStandIns()

        let profile = try await makeSurveyor().survey(
            index: "docs",
            previous: nil,
            preferredModel: "text-embedding-3-small",
            summaryOptions: summaryOptions
        )

        XCTAssertEqual(profile.dimension, 4)
        XCTAssertEqual(profile.namespaces, [.init(name: "baxter", vectorCount: 5), .init(name: "", vectorCount: 3)])
        XCTAssertEqual(profile.embeddingModel, "text-embedding-3-large")
        XCTAssertEqual(profile.modelCheck, .matched)
        XCTAssertEqual(try XCTUnwrap(profile.modelSimilarity), 1, accuracy: 1e-6)
        XCTAssertTrue(profile.isRoutable)
        XCTAssertEqual(profile.summary, "Infusion pump manuals by manufacturer.")
        XCTAssertEqual(profile.summarySource, .drafted)

        let embeddingModels = RouteMockURLProtocol.requests
            .filter { $0.url.path == "/v1/embeddings" }
            .compactMap { $0.body?["model"] as? String }
        XCTAssertEqual(embeddingModels, ["text-embedding-3-small", "text-embedding-3-large"], "the Settings model is tried first")

        let samples = RouteMockURLProtocol.requests.filter { $0.url.path == "/query" }
        XCTAssertEqual(samples.count, 2, "one sample per namespace that holds passages")
        XCTAssertTrue(samples.allSatisfy { $0.body?["includeValues"] as? Bool == true })
        XCTAssertEqual(samples.map { $0.body?["namespace"] as? String }, ["baxter", nil], "the default namespace is left out")
        XCTAssertEqual(profile.host, indexHost)
    }

    // MARK: - Failures that may pass are not findings

    private func failing(_ path: String, status: Int, whenModel model: String? = nil) {
        let standIns = RouteMockURLProtocol.handler
        RouteMockURLProtocol.handler = { request, body in
            if request.url?.path == path {
                let json = (try? JSONSerialization.jsonObject(with: body ?? Data())) as? [String: Any]
                if model == nil || json?["model"] as? String == model {
                    return (status, jsonData(["error": ["message": "stand-in \(status)", "type": "server_error", "param": NSNull(), "code": NSNull()]]))
                }
            }
            return try standIns!(request, body)
        }
    }

    func testAnEmbeddingOutageThrowsInsteadOfRecordingNoMatch() async {
        installSurveyStandIns()
        failing("/v1/embeddings", status: 500)

        do {
            _ = try await makeSurveyor().survey(index: "docs", previous: nil, preferredModel: "text-embedding-3-small", summaryOptions: nil)
            XCTFail("A 500 from every candidate says nothing about the index")
        } catch {
            XCTAssertTrue(IndexSurveyor.mayPass(error))
        }
    }

    func testAModelTheKeyCantUseCountsAsChecked() async throws {
        installSurveyStandIns()
        failing("/v1/embeddings", status: 404, whenModel: "text-embedding-3-small")

        let profile = try await makeSurveyor().survey(index: "docs", previous: nil, preferredModel: "text-embedding-3-small", summaryOptions: nil)

        XCTAssertEqual(profile.modelCheck, .matched, "3-small refused with a 404, 3-large still matched")
        XCTAssertEqual(profile.embeddingModel, "text-embedding-3-large")
    }

    func testEverySampleFailingThrowsInsteadOfRecordingNoPassage() async {
        installSurveyStandIns()
        failing("/query", status: 400)

        do {
            _ = try await makeSurveyor().survey(index: "docs", previous: nil, preferredModel: "text-embedding-3-small", summaryOptions: nil)
            XCTFail("No sample came back, so nothing is known about the index")
        } catch {
            XCTAssertEqual(RouteMockURLProtocol.requests.filter { $0.url.path == "/v1/embeddings" }.count, 0)
        }
    }

    func testARecreatedIndexIsCheckedAgain() async throws {
        installSurveyStandIns()
        var previous = makeProfile("docs", namespaces: [("baxter", 5)], dimension: 4, model: "text-embedding-3-small", summary: "Pumps.")
        previous.host = "docs-old999.svc.aped-1234.pinecone.io"

        let profile = try await makeSurveyor().survey(index: "docs", previous: previous, preferredModel: "text-embedding-3-small", summaryOptions: nil)

        XCTAssertEqual(profile.embeddingModel, "text-embedding-3-large", "a new host means a new index, so the old match isn't trusted")
        XCTAssertEqual(profile.host, indexHost)
        XCTAssertEqual(profile.summary, "Pumps.")
    }

    func testSurveyReportsNoMatchWhenNoModelReproducesTheVector() async throws {
        installSurveyStandIns()
        let stored = storedVector
        let previousHandler = RouteMockURLProtocol.handler
        RouteMockURLProtocol.handler = { request, body in
            if request.url?.path == "/v1/embeddings" {
                return (200, jsonData([
                    "data": [["embedding": stored.map { -$0 }, "index": 0, "object": "embedding"]],
                    "model": "x",
                    "usage": ["prompt_tokens": 9, "total_tokens": 9],
                ]))
            }
            return try previousHandler!(request, body)
        }

        let profile = try await makeSurveyor().survey(index: "docs", previous: nil, preferredModel: "text-embedding-3-large", summaryOptions: nil)

        XCTAssertEqual(profile.modelCheck, .noMatch)
        XCTAssertNil(profile.embeddingModel)
        XCTAssertFalse(profile.isRoutable)
        XCTAssertEqual(profile.summarySource, .missing, "no summary options, no draft")
    }

    func testSurveyKeepsAPersonWrittenSummaryAndAnEarlierModelMatch() async throws {
        installSurveyStandIns()
        var previous = makeProfile("docs", namespaces: [("baxter", 5)], dimension: 4, model: "text-embedding-3-large", summary: "")
        previous.summary = "My pump manuals."
        previous.summarySource = .person
        previous.host = indexHost

        let profile = try await makeSurveyor().survey(index: "docs", previous: previous, preferredModel: "text-embedding-3-small", summaryOptions: summaryOptions)

        XCTAssertEqual(profile.summary, "My pump manuals.")
        XCTAssertEqual(profile.summarySource, .person)
        XCTAssertEqual(profile.embeddingModel, "text-embedding-3-large")
        XCTAssertEqual(profile.namespaces.count, 2, "namespaces are refreshed")
        XCTAssertTrue(RouteMockURLProtocol.requests.filter { $0.url.path == "/v1/embeddings" || $0.url.path == "/v1/responses" }.isEmpty,
                      "nothing to check or draft, so no OpenAI calls")
    }

    // MARK: - Profiles on the phone

    func testCatalogStoreRoundTripsAndKeepsProjectsApart() {
        let suite = "IndexSurveyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = IndexCatalogStore(projectId: "project-1", defaults: defaults)
        let second = IndexCatalogStore(projectId: "project-2", defaults: defaults)
        var profile = makeProfile("docs", summary: "Pump manuals.")
        profile.surveyedAt = Date(timeIntervalSinceReferenceDate: 800_000_000)

        first.save(["docs": profile])

        XCTAssertEqual(first.load(), ["docs": profile])
        XCTAssertEqual(second.load(), [:])
        XCTAssertFalse(defaults.dictionaryRepresentation().keys.contains { $0.contains("project-1") }, "the project ID is hashed into the key")

        first.removeAll()
        XCTAssertEqual(first.load(), [:])

        first.save(["docs": profile])
        second.save(["docs": profile])
        defaults.set("kept", forKey: "search.topK.unrelated")
        IndexCatalogStore.removeAllProjects(from: defaults)
        XCTAssertEqual(first.load(), [:])
        XCTAssertEqual(second.load(), [:])
        XCTAssertEqual(defaults.string(forKey: "search.topK.unrelated"), "kept")
    }

    func testProfilesWithoutPassagesOrAModelAreNotRoutable() {
        XCTAssertTrue(makeProfile("a").isRoutable)
        XCTAssertFalse(makeProfile("b", namespaces: [("", 0)]).isRoutable)
        XCTAssertFalse(makeProfile("c", model: nil, check: .noPassage).isRoutable)
        XCTAssertFalse(makeProfile("d", check: .notChecked).isRoutable)
    }
}
