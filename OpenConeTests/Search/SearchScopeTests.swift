import XCTest
@testable import OpenCone

// The stand-in handler runs on URLSession's thread, so what it reads lives outside the test class
private let manualsHost = "manuals-abc123.svc.aped-1234.pinecone.io"

/// Where a question is searched: every namespace of one index, indexes left out of a search
/// across indexes, and asking the last question again
@MainActor
final class SearchScopeTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    /// Keys these tests change in the app's own defaults, including every one a search writes
    /// before it starts (`SettingsViewModel.persistRequestSettings`)
    private let touchedKeys = [
        "search.allNamespaces.manuals",
        "completionModel", "useCustomModel", "customCompletionModel",
        "openai.temperature", "openai.topP", "openai.reasoningEffort", "openai.conversationMode",
        "search.maxOutputTokens", "search.webSearchEnabled", "search.codeInterpreterEnabled",
        SettingsStorageKeys.searchTopK, SettingsStorageKeys.indexRoutingEnabled, SettingsStorageKeys.searchScope,
        SettingsStorageKeys.hybridSearchEnabled, SettingsStorageKeys.hybridSearchAlpha,
        SettingsStorageKeys.rerankingEnabled, SettingsStorageKeys.rerankModel, SettingsStorageKeys.rerankTopN,
        "conversation.systemPromptOverride",
    ]
    private var saved: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        RouteMockURLProtocol.reset()
        suiteName = "SearchScopeTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        for key in touchedKeys {
            if let value = UserDefaults.standard.object(forKey: key) {
                saved[key] = value
            }
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in touchedKeys {
            if let value = saved[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        saved = [:]
        defaults.removePersistentDomain(forName: suiteName)
        RouteMockURLProtocol.reset()
        super.tearDown()
    }

    private func makeSUT(pinecone: PineconeService? = nil, store: IndexCatalogStore? = nil) -> SearchViewModel {
        let openAIService = OpenAIService(apiKey: "test")
        return SearchViewModel(
            pineconeService: pinecone ?? PineconeService(apiKey: "test", projectId: "test"),
            openAIService: openAIService,
            embeddingService: EmbeddingService(openAIService: openAIService),
            settingsViewModel: SettingsViewModel(),
            indexRouter: IndexRouter(responses: ResponsesClient(apiKey: "test")),
            indexSurveyor: nil,
            indexCatalogStore: store
        )
    }

    // MARK: - Namespaces of one index

    func testTheDefaultNamespaceIsListedFirst() {
        XCTAssertEqual(SearchViewModel.orderedNamespaces(["zeta", "", "Alpha", "beta"]), ["", "Alpha", "beta", "zeta"])
    }

    func testAllNamespacesSearchesEachOneLargestFirst() {
        let sut = makeSUT()
        sut.selectedIndex = "manuals"
        sut.namespaces = ["", "baxter", "bd"]
        sut.namespaceVectorCounts = ["": 5, "baxter": 40, "bd": 12]
        sut.selectedNamespace = nil

        XCTAssertEqual(sut.namespacesToSearch, ["baxter", "bd", nil], "nil is the default namespace")

        sut.selectedNamespace = ""
        XCTAssertEqual(sut.namespacesToSearch, [nil], "the default namespace, chosen on its own")

        sut.selectedNamespace = "bd"
        XCTAssertEqual(sut.namespacesToSearch, ["bd"])
    }

    func testAnIndexWithOneNamedNamespaceSearchesThatNamespace() {
        // Before, "All" sent no namespace, which searched the empty default namespace
        let sut = makeSUT()
        sut.selectedIndex = "manuals"
        sut.namespaces = ["baxter"]
        sut.selectedNamespace = nil
        XCTAssertEqual(sut.namespacesToSearch, ["baxter"])
    }

    func testAllNamespacesStopsAtTheFanOutLimit() {
        let sut = makeSUT()
        sut.selectedIndex = "manuals"
        sut.namespaces = (1...14).map { "ns\($0)" }
        sut.namespaceVectorCounts = Dictionary(uniqueKeysWithValues: (1...14).map { ("ns\($0)", $0) })
        sut.selectedNamespace = nil

        XCTAssertEqual(sut.namespacesToSearch.count, 10)
        XCTAssertEqual(sut.namespacesToSearch.first, "ns14")
    }

    func testChoosingAllNamespacesIsRemembered() {
        let sut = makeSUT()
        sut.selectedIndex = "manuals"

        sut.setNamespace(nil)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "search.allNamespaces.manuals"))

        sut.setNamespace("baxter")
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "search.allNamespaces.manuals"))
        XCTAssertEqual(sut.selectedNamespace, "baxter")
    }

    func testEachNamespaceIsQueriedAndTheBestMatchesAreKept() async throws {
        let pinecone = PineconeService(apiKey: "test", projectId: "test", sessionConfiguration: RouteMockURLProtocol.sessionConfiguration())
        RouteMockURLProtocol.handler = { request, body in
            if request.url?.host == "api.pinecone.io" {
                return (200, jsonData([
                    "name": "manuals", "dimension": 2, "metric": "cosine", "host": manualsHost,
                    "status": ["state": "Ready", "ready": true],
                ]))
            }
            let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            switch json?["namespace"] as? String {
            case "baxter":
                return (200, jsonData(["namespace": "baxter", "matches": [
                    ["id": "b1", "score": 0.91, "metadata": ["text": "Baxter filter", "source": "baxter.pdf"]],
                    ["id": "b2", "score": 0.42, "metadata": ["text": "Baxter misc", "source": "baxter.pdf"]],
                ]]))
            case "bd":
                return (400, jsonData(["error": ["message": "boom"]]))
            default:
                return (200, jsonData(["namespace": "", "matches": [
                    ["id": "d1", "score": 0.77, "metadata": ["text": "Default passage", "source": "general.pdf"]],
                ]]))
            }
        }
        UserDefaults.standard.set(2, forKey: SettingsStorageKeys.searchTopK)
        let sut = makeSUT(pinecone: pinecone)

        let results = try await sut.searchNamespaces(["baxter", "bd", nil], of: "manuals", vector: [1, 0], sparse: nil, filter: nil, traceId: "t")

        XCTAssertEqual(results.map(\.content), ["Baxter filter", "Default passage"], "best two across namespaces; the failed one is skipped")
        XCTAssertEqual(results.map(\.scopeLabel), ["manuals / baxter", "manuals"])

        let queries = RouteMockURLProtocol.requests.filter { $0.url.host == manualsHost }
        XCTAssertEqual(queries.count, 3)
        XCTAssertTrue(queries.contains { $0.body?["namespace"] == nil }, "the default namespace is sent by leaving the field out")
    }

    func testEveryNamespaceFailingIsAnError() async {
        let pinecone = PineconeService(apiKey: "test", projectId: "test", sessionConfiguration: RouteMockURLProtocol.sessionConfiguration())
        RouteMockURLProtocol.handler = { request, _ in
            if request.url?.host == "api.pinecone.io" {
                return (200, jsonData([
                    "name": "manuals", "dimension": 2, "metric": "cosine", "host": manualsHost,
                    "status": ["state": "Ready", "ready": true],
                ]))
            }
            return (400, jsonData(["error": ["message": "bad"]]))
        }
        let sut = makeSUT(pinecone: pinecone)

        do {
            _ = try await sut.searchNamespaces(["a", "b"], of: "manuals", vector: [1, 0], sparse: nil, filter: nil, traceId: "t")
            XCTFail("Expected an error")
        } catch {}
    }

    // MARK: - Indexes left out

    func testLeavingIndexesOutNarrowsTheSearchAcrossIndexes() async {
        let store = IndexCatalogStore(projectId: "p", defaults: defaults)
        let sut = makeSUT(store: store)
        sut.pineconeIndexes = ["manuals", "research", "scratch"]
        sut.selectedIndex = "manuals"
        sut.namespaces = [""]
        XCTAssertTrue(sut.shouldRouteSearch)

        await sut.setIndex("scratch", included: false)
        XCTAssertEqual(sut.includedIndexes, ["manuals", "research"])
        XCTAssertTrue(sut.shouldRouteSearch)
        XCTAssertEqual(store.loadExcluded(), ["scratch"], "kept for the next launch")

        await sut.setIndex("research", included: false)
        XCTAssertEqual(sut.includedIndexes, ["manuals"])
        XCTAssertFalse(sut.shouldRouteSearch, "one index with one namespace left: search it directly")

        await sut.setIndex("manuals", included: false)
        XCTAssertEqual(sut.includedIndexes, ["manuals"], "the last index stays in")

        await sut.setIndex("research", included: true)
        XCTAssertEqual(sut.includedIndexes, ["manuals", "research"])

        store.removeAll()
        XCTAssertTrue(store.loadExcluded().isEmpty, "the reset clears them with the profiles")
    }

    func testLeftOutIndexesAreLoadedAtLaunch() {
        let store = IndexCatalogStore(projectId: "p", defaults: defaults)
        store.saveExcluded(["scratch"])
        let sut = makeSUT(store: store)
        sut.pineconeIndexes = ["manuals", "scratch"]
        XCTAssertEqual(sut.includedIndexes, ["manuals"])
    }

    // MARK: - Everything

    func testEverythingSearchesEachNamespaceOfEachSearchableIndexInTurns() {
        let profiles = [
            makeProfile("research", namespaces: [("", 30)]),
            makeProfile("manuals", namespaces: [("baxter", 40), ("bd", 12), ("empty", 0)]),
            makeProfile("unknown", namespaces: [("", 50)], model: nil, check: .noMatch),
        ]

        let requests = SearchViewModel.broadSearchRequests(for: profiles, query: "filters", limit: 20)
        XCTAssertEqual(requests.map(\.scopeLabel), ["manuals / baxter", "research", "manuals / bd"],
                       "largest namespaces first, indexes in turns; empty namespaces and indexes with no known model are skipped")
        XCTAssertTrue(requests.allSatisfy { $0.query == "filters" }, "the question itself, with no model rewriting it")

        let capped = SearchViewModel.broadSearchRequests(for: profiles, query: "filters", limit: 2)
        XCTAssertEqual(capped.map(\.index), ["manuals", "research"], "a limit still reaches every index")
    }

    func testEverythingMergesByRankFirstThenScore() {
        func passage(_ text: String, _ score: Float) -> SearchResultModel {
            SearchResultModel(content: text, sourceDocument: "\(text).pdf", score: score, metadata: [:])
        }
        let merged = SearchViewModel.mergedAcrossSearches([
            [passage("a1", 0.62), passage("a2", 0.61)],
            [passage("b1", 0.80), passage("b2", 0.79), passage("b3", 0.78)],
        ])
        XCTAssertEqual(merged.map(\.content), ["b1", "a1", "b2", "a2", "b3"])
    }

    // MARK: - Asking again

    func testRetryAsksTheLastQuestionAgainInPlaceOfItsAnswer() async {
        let sut = makeSUT()
        sut.selectedIndex = "manuals"
        sut.messages = [
            ChatMessage(role: .user, text: "First question"),
            ChatMessage(role: .assistant, text: "First answer"),
            ChatMessage(role: .user, text: "How often is the filter changed?"),
            ChatMessage(role: .assistant, text: "", status: .error, error: "Generation canceled"),
        ]

        // No index host, so the Pinecone check fails at once and adds a failed answer, without a request
        await sut.retryLastAnswer()

        XCTAssertEqual(sut.messages.map(\.text), ["First question", "First answer", "How often is the filter changed?", ""])
        XCTAssertEqual(sut.messages.last?.status, .error)
        XCTAssertEqual(sut.messages.last?.error, "Pinecone didn't respond. Try again in a moment.")
        XCTAssertEqual(sut.searchQuery, "")
    }

    func testOnlyTheLatestAnswerCanBeRetried() async {
        let sut = makeSUT()
        sut.selectedIndex = "manuals"
        sut.messages = [ChatMessage(role: .user, text: "Waiting on an answer")]

        await sut.retryLastAnswer()

        XCTAssertEqual(sut.messages.count, 1, "the last message is a question, so there's nothing to retry")
    }

    // MARK: - Sources

    func testAnAnswerFindsItsPassagesByTag() {
        let tagged = PassageText.taggedContext([
            SearchResultModel(content: "One", sourceDocument: "a.pdf", score: 0.9, metadata: ["page_number": "4"]),
            SearchResultModel(content: "Two", sourceDocument: "b.pdf", score: 0.8, metadata: [:], index: "manuals", namespace: "bd"),
        ], maxCharacters: 100, namingScopes: true)

        XCTAssertEqual(tagged.text, "[S1] a.pdf, page 4\nOne\n\n[S2] b.pdf (manuals / bd)\nTwo")
        let message = ChatMessage(role: .assistant, text: "See [S2]", sources: tagged.passages)
        XCTAssertEqual(message.source(tagged: "s2")?.content, "Two")
        XCTAssertNil(message.source(tagged: "S3"))
    }
}
