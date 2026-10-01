import XCTest
@testable import OpenCone

@MainActor
final class IndexRouterTests: XCTestCase {

    override func setUp() {
        super.setUp()
        RouteMockURLProtocol.reset()
    }

    override func tearDown() {
        RouteMockURLProtocol.reset()
        super.tearDown()
    }

    private let manuals = makeProfile(
        "manuals",
        namespaces: [("baxter", 1204), ("bd", 880)],
        summary: "Instructions for use for infusion pumps."
    )
    private let research = makeProfile("research", namespaces: [("", 312)], summary: "Papers on sleep and memory.")

    private func call(_ index: String, _ namespace: String, _ query: String) -> ResponsesClient.FunctionCall {
        let arguments = String(data: jsonData(["index": index, "namespace": namespace, "query": query]), encoding: .utf8)!
        return ResponsesClient.FunctionCall(callId: UUID().uuidString, name: IndexRouter.toolName, arguments: arguments)
    }

    // MARK: - Tool

    func testToolIsStrictAndOffersOnlyTheGivenIndexes() throws {
        let tool = IndexRouter.toolDefinition(for: [manuals, research])

        XCTAssertEqual(tool["type"] as? String, "function")
        XCTAssertEqual(tool["name"] as? String, "search_index")
        XCTAssertEqual(tool["strict"] as? Bool, true)

        let parameters = try XCTUnwrap(tool["parameters"] as? [String: Any])
        XCTAssertEqual(parameters["required"] as? [String], ["index", "namespace", "query"])
        XCTAssertEqual(parameters["additionalProperties"] as? Bool, false)
        let properties = try XCTUnwrap(parameters["properties"] as? [String: Any])
        let index = try XCTUnwrap(properties["index"] as? [String: Any])
        XCTAssertEqual(index["enum"] as? [String], ["manuals", "research"])

        let description = try XCTUnwrap(tool["description"] as? String)
        XCTAssertTrue(description.contains("- manuals: Instructions for use for infusion pumps."))
        XCTAssertTrue(description.contains("\"baxter\" with 1204 passages"))
        XCTAssertTrue(description.contains("\"\" (default) with 312 passages"))
    }

    func testToolListsAtMostFortyNamespacesPerIndex() throws {
        let many = makeProfile("big", namespaces: (0..<45).map { ("ns\($0)", 100 - $0) })
        let description = try XCTUnwrap(IndexRouter.toolDefinition(for: [many])["description"] as? String)

        XCTAssertTrue(description.contains("\"ns39\""))
        XCTAssertFalse(description.contains("\"ns40\""))
        XCTAssertTrue(description.contains("and 5 more"))
    }

    // MARK: - Checking the model's calls

    func testKeepsValidCallsAndDropsTheRest() {
        let calls = [
            call("manuals", "baxter", "occlusion alarm"),
            call("nowhere", "", "anything"),          // index not offered
            call("manuals", "philips", "alarm"),       // namespace not in the index
            call("research", "", "   "),              // empty query
            call("manuals", "baxter", "occlusion alarm"), // duplicate
            call("research", "", "sleep spindles"),
            ResponsesClient.FunctionCall(callId: "x", name: "other_tool", arguments: "{}"),
            ResponsesClient.FunctionCall(callId: "y", name: IndexRouter.toolName, arguments: "not json"),
        ]

        let requests = IndexRouter.searchRequests(from: calls, profiles: [manuals, research], cap: 5)

        XCTAssertEqual(requests, [
            IndexRouter.SearchRequest(index: "manuals", namespace: "baxter", query: "occlusion alarm"),
            IndexRouter.SearchRequest(index: "research", namespace: "", query: "sleep spindles"),
        ])
    }

    func testStopsAtTheCap() {
        let calls = (0..<7).map { call("manuals", "baxter", "query \($0)") }
        let requests = IndexRouter.searchRequests(from: calls, profiles: [manuals], cap: IndexRouter.maxSearches)
        XCTAssertEqual(requests.count, 5)
        XCTAssertEqual(requests.last?.query, "query 4")
    }

    func testResolvesNamespacesTheWayTheIndexNamesThem() {
        let single = makeProfile("single", namespaces: [("manufacturer-a", 40)])

        XCTAssertEqual(IndexRouter.resolveNamespace("", in: research), "")
        XCTAssertEqual(IndexRouter.resolveNamespace("default", in: research), "")
        XCTAssertEqual(IndexRouter.resolveNamespace("BAXTER", in: manuals), "baxter")
        XCTAssertEqual(IndexRouter.resolveNamespace("", in: single), "manufacturer-a")
        XCTAssertNil(IndexRouter.resolveNamespace("", in: manuals), "two named namespaces: no guess")
        XCTAssertNil(IndexRouter.resolveNamespace("philips", in: manuals))
    }

    func testIndexNamesMatchRegardlessOfCase() {
        let requests = IndexRouter.searchRequests(from: [call("Manuals", "bd", "flow rate")], profiles: [manuals], cap: 5)
        XCTAssertEqual(requests, [IndexRouter.SearchRequest(index: "manuals", namespace: "bd", query: "flow rate")])
    }

    // MARK: - Routing call

    private func makeRouter() -> IndexRouter {
        let session = URLSession(configuration: RouteMockURLProtocol.sessionConfiguration())
        return IndexRouter(responses: ResponsesClient(apiKey: "test-key", session: session))
    }

    private let options = ResponsesClient.ModelOptions(model: "gpt-4o", reasoningEffort: "none", temperature: 0)

    func testRouteReturnsTheSearchesTheModelAskedFor() async throws {
        RouteMockURLProtocol.handler = { _, _ in
            (200, jsonData([
                "status": "completed",
                "output": [
                    ["type": "function_call", "call_id": "c1", "name": "search_index",
                     "arguments": "{\"index\":\"manuals\",\"namespace\":\"baxter\",\"query\":\"occlusion alarm\"}"],
                    ["type": "function_call", "call_id": "c2", "name": "search_index",
                     "arguments": "{\"index\":\"research\",\"namespace\":\"\",\"query\":\"alarm fatigue\"}"],
                ],
            ]))
        }

        let decision = try await makeRouter().route(
            question: "Compare what the manuals and the research say about alarms",
            history: [ChatMessage(role: .user, text: "earlier question"), ChatMessage(role: .assistant, text: "earlier answer")],
            profiles: [manuals, research],
            hint: IndexRouter.Hint(index: "manuals", namespace: "baxter"),
            options: options
        )

        XCTAssertEqual(decision, .search([
            IndexRouter.SearchRequest(index: "manuals", namespace: "baxter", query: "occlusion alarm"),
            IndexRouter.SearchRequest(index: "research", namespace: "", query: "alarm fatigue"),
        ]))

        let body = try XCTUnwrap(RouteMockURLProtocol.requests.first?.body)
        XCTAssertEqual(RouteMockURLProtocol.requests.first?.url.absoluteString, "https://api.openai.com/v1/responses")
        XCTAssertEqual(body["store"] as? Bool, false)
        XCTAssertEqual(body["parallel_tool_calls"] as? Bool, true)
        XCTAssertEqual(body["tool_choice"] as? String, "auto")
        XCTAssertEqual(body["temperature"] as? Double, 0)
        XCTAssertNil(body["reasoning"])
        let instructions = try XCTUnwrap(body["instructions"] as? String)
        XCTAssertTrue(instructions.contains("index \"manuals\" (namespace \"baxter\") open"))
        let input = try XCTUnwrap(body["input"] as? [[String: Any]])
        XCTAssertEqual(input.count, 3)
        XCTAssertEqual(input.last?["content"] as? String, "Compare what the manuals and the research say about alarms")
        XCTAssertEqual(input.first?["role"] as? String, "user")
        XCTAssertEqual(input[1]["role"] as? String, "assistant")
    }

    func testRouteOffersOnlyIndexesWithAKnownModel() async throws {
        let unchecked = makeProfile("drafts", model: nil, check: .notChecked)
        RouteMockURLProtocol.handler = { _, _ in
            (200, jsonData(["output": [["type": "function_call", "call_id": "c1", "name": "search_index",
                                        "arguments": "{\"index\":\"research\",\"namespace\":\"\",\"query\":\"sleep\"}"]]]))
        }

        _ = try await makeRouter().route(question: "sleep?", history: [], profiles: [unchecked, research], hint: .init(index: nil, namespace: nil), options: options)

        let body = try XCTUnwrap(RouteMockURLProtocol.requests.first?.body)
        let tools = try XCTUnwrap(body["tools"] as? [[String: Any]])
        let parameters = try XCTUnwrap(tools.first?["parameters"] as? [String: Any])
        let properties = try XCTUnwrap(parameters["properties"] as? [String: Any])
        XCTAssertEqual((properties["index"] as? [String: Any])?["enum"] as? [String], ["research"])
    }

    func testRouteAnswersDirectlyWhenTheModelDoesNotSearch() async throws {
        RouteMockURLProtocol.handler = { _, _ in
            (200, jsonData(["output": [["type": "message", "role": "assistant",
                                        "content": [["type": "output_text", "text": "You're welcome."]]]]]))
        }

        let decision = try await makeRouter().route(question: "thanks!", history: [], profiles: [research], hint: .init(index: nil, namespace: nil), options: options)
        XCTAssertEqual(decision, .answer("You're welcome."))
    }

    func testRouteThrowsWhenNoIndexIsSearchable() async {
        let unchecked = makeProfile("drafts", model: nil, check: .noMatch)
        do {
            _ = try await makeRouter().route(question: "q", history: [], profiles: [unchecked], hint: .init(index: nil, namespace: nil), options: options)
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? IndexRoutingError, .noSearchableIndex)
            XCTAssertTrue(RouteMockURLProtocol.requests.isEmpty, "No model call without an index to offer")
        }
    }

    func testReasoningModelsGetReasoningInsteadOfTemperature() async throws {
        RouteMockURLProtocol.handler = { _, _ in
            (200, jsonData(["output": [["type": "function_call", "call_id": "c1", "name": "search_index",
                                        "arguments": "{\"index\":\"research\",\"namespace\":\"\",\"query\":\"sleep\"}"]]]))
        }
        let reasoning = ResponsesClient.ModelOptions(model: "gpt-5.5", reasoningEffort: "low", temperature: 0)

        _ = try await makeRouter().route(question: "sleep?", history: [], profiles: [research], hint: .init(index: nil, namespace: nil), options: reasoning)

        let body = try XCTUnwrap(RouteMockURLProtocol.requests.first?.body)
        XCTAssertEqual((body["reasoning"] as? [String: Any])?["effort"] as? String, "low")
        XCTAssertNil(body["temperature"])
        XCTAssertEqual(body["max_output_tokens"] as? Int, 4000)
    }

    // MARK: - Context for the answer

    func testContextTagsPassagesAndAlternatesCitationsBetweenSearches() {
        func result(_ document: String, _ index: String, _ namespace: String) -> SearchResultModel {
            SearchResultModel(content: "Text of \(document)", sourceDocument: document, score: 0.9, metadata: [:], index: index, namespace: namespace)
        }
        let searches = [
            IndexRouter.RoutedSearch(
                request: .init(index: "manuals", namespace: "baxter", query: "alarm"),
                results: [result("a1.pdf", "manuals", "baxter"), result("a2.pdf", "manuals", "baxter")]
            ),
            IndexRouter.RoutedSearch(
                request: .init(index: "research", namespace: "", query: "alarm fatigue"),
                results: [result("b1.pdf", "research", ""), result("b2.pdf", "research", "")]
            ),
            IndexRouter.RoutedSearch(request: .init(index: "manuals", namespace: "bd", query: "alarm"), results: []),
        ]

        let context = IndexRouter.context(for: searches, passagesPerSearch: 5, maxCharacters: 2000)

        XCTAssertTrue(context.text.contains("Search 1: index \"manuals\", namespace \"baxter\", query \"alarm\""))
        XCTAssertTrue(context.text.contains("[S1] a1.pdf\nText of a1.pdf"))
        XCTAssertTrue(context.text.contains("Search 2: index \"research\", namespace \"default\""))
        XCTAssertTrue(context.text.contains("[S3] b1.pdf"))
        XCTAssertTrue(context.text.contains("Search 3: index \"manuals\", namespace \"bd\", query \"alarm\"\nNo passages found."))
        XCTAssertEqual(context.passages.map(\.sourceDocument), ["a1.pdf", "a2.pdf", "b1.pdf", "b2.pdf"])
        XCTAssertEqual(context.passages.map(\.citationTag), ["S1", "S2", "S3", "S4"])
        XCTAssertEqual(context.citations, ["a1.pdf", "b1.pdf", "a2.pdf", "b2.pdf"])
        XCTAssertEqual(context.citationScopes, ["manuals / baxter", "research", "manuals / baxter", "research"])
    }

    func testContextSaysWhenASearchFailedRatherThanFoundNothing() {
        let searches = [
            IndexRouter.RoutedSearch(request: .init(index: "manuals", namespace: "bd", query: "alarm"), results: [], failed: true),
            IndexRouter.RoutedSearch(request: .init(index: "research", namespace: "", query: "alarm"), results: []),
        ]

        let context = IndexRouter.context(for: searches, passagesPerSearch: 5, maxCharacters: 2000)

        XCTAssertTrue(context.text.contains("namespace \"bd\", query \"alarm\"\nThis search failed, so nothing from it is included."))
        XCTAssertTrue(context.text.contains("namespace \"default\", query \"alarm\"\nNo passages found."))
        XCTAssertTrue(IndexRouter.answerInstructions.contains("If a search failed or found nothing useful"))
    }

    func testContextTrimsPassagesAndKeepsAtMostThePerSearchCount() {
        let long = SearchResultModel(content: String(repeating: "x", count: 5000), sourceDocument: "long.pdf", score: 1, metadata: ["page_number": "4"], index: "research", namespace: "")
        let searches = [IndexRouter.RoutedSearch(request: .init(index: "research", namespace: "", query: "q"), results: Array(repeating: long, count: 8))]

        let context = IndexRouter.context(for: searches, passagesPerSearch: 3, maxCharacters: 100)

        XCTAssertEqual(context.passages.count, 3)
        XCTAssertTrue(context.text.contains("[S1] long.pdf, page 4\n" + String(repeating: "x", count: 100) + "\n[S2]"))
        XCTAssertEqual(context.citations, ["long.pdf"], "the same document and place is cited once")
    }
}
