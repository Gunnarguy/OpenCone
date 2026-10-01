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
        RequestSettings.Key.verbosity, RequestSettings.Key.serviceTier, RequestSettings.Key.webSearchContextSize,
        RequestSettings.Key.webSearchDomains, RequestSettings.Key.historyExchanges,
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
        URLProtocol.unregisterClass(RouteMockURLProtocol.self)
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

    // MARK: - Failures, Stop and scope changes

    /// Pinecone's control plane describes any index on `manualsHost`; the host answers stats (the
    /// health check) after `statsDelay`, and queries with no matches; OpenAI refuses the key
    private func installStandIns(statsDelay: TimeInterval = 0) {
        URLProtocol.registerClass(RouteMockURLProtocol.self)
        RouteMockURLProtocol.handler = { request, _ in
            switch request.url?.host {
            case "api.pinecone.io":
                let name = request.url?.lastPathComponent ?? "manuals"
                return (200, jsonData([
                    "name": name, "dimension": 2, "metric": "cosine", "host": manualsHost,
                    "status": ["state": "Ready", "ready": true],
                ]))
            case manualsHost where request.url?.path.contains("describe_index_stats") == true:
                if statsDelay > 0 { Thread.sleep(forTimeInterval: statsDelay) }
                return (200, jsonData(["namespaces": ["": ["vectorCount": 3]], "dimension": 2, "totalVectorCount": 3]))
            case manualsHost:
                return (200, jsonData(["namespace": "", "matches": []]))
            default:
                return (401, jsonData(["error": ["message": "Incorrect API key provided", "type": "invalid_request_error"]]))
            }
        }
    }

    private func makeSearchingSUT() async throws -> SearchViewModel {
        UserDefaults.standard.set(SearchScope.oneIndex.rawValue, forKey: SettingsStorageKeys.searchScope)
        let pinecone = PineconeService(apiKey: "test", projectId: "test", sessionConfiguration: RouteMockURLProtocol.sessionConfiguration())
        try await pinecone.setCurrentIndex("manuals")
        let sut = makeSUT(pinecone: pinecone)
        sut.pineconeIndexes = ["manuals"]
        sut.selectedIndex = "manuals"
        sut.namespaces = [""]
        sut.selectedNamespace = ""
        return sut
    }

    func testAFailedSearchBecomesTheQuestionsAnswer() async throws {
        installStandIns()
        let sut = try await makeSearchingSUT()
        sut.searchQuery = "How often is the filter changed?"

        await sut.performSearch()

        XCTAssertEqual(sut.messages.count, 2)
        XCTAssertEqual(sut.messages.last?.role, .assistant)
        XCTAssertEqual(sut.messages.last?.status, .error, "a failed answer that can be retried, not a question left hanging")
        XCTAssertNil(sut.errorMessage, "the failure shows in its answer, not in the banner")
        XCTAssertFalse(sut.isSearching)
    }

    func testStopDuringThePineconeCheckEndsTheSearch() async throws {
        installStandIns(statsDelay: 1.0)
        let sut = try await makeSearchingSUT()
        sut.searchQuery = "How often is the filter changed?"

        let search = Task { await sut.performSearch() }
        try await Task.sleep(nanoseconds: 300_000_000)
        sut.cancelActiveSearch()
        await search.value
        try await Task.sleep(nanoseconds: 1_200_000_000)

        XCTAssertEqual(sut.messages.map(\.status), [.normal, .error])
        XCTAssertEqual(sut.messages.last?.error, "Stopped")
        XCTAssertFalse(RouteMockURLProtocol.requests.contains { $0.url.host == "api.openai.com" },
                       "nothing was embedded after Stop")
    }

    func testRetryKeepsWhatIsBeingTyped() async {
        let sut = makeSUT()
        sut.selectedIndex = "manuals"
        sut.messages = [
            ChatMessage(role: .user, text: "First question"),
            ChatMessage(role: .assistant, text: "", status: .error, error: "Stopped"),
        ]
        sut.searchQuery = "a draft of the next question"

        await sut.retryLastAnswer()

        XCTAssertEqual(sut.messages.first?.text, "First question")
        XCTAssertEqual(sut.searchQuery, "a draft of the next question")
    }

    func testLeavingOneIndexForAutoOpensAnIncludedIndex() async throws {
        installStandIns()
        let store = IndexCatalogStore(projectId: "p", defaults: defaults)
        store.saveExcluded(["manuals"])
        let pinecone = PineconeService(apiKey: "test", projectId: "test", sessionConfiguration: RouteMockURLProtocol.sessionConfiguration())
        let sut = makeSUT(pinecone: pinecone, store: store)
        sut.pineconeIndexes = ["manuals", "research"]
        sut.selectedIndex = "manuals"

        sut.settingsViewModel.searchScope = .auto
        await sut.scopeDidChange()

        XCTAssertEqual(sut.selectedIndex, "research", "Auto falls back to the open index, which must be one it searches")
    }

    func testAnEuclideanIndexKeepsItsClosestMatches() async throws {
        installStandIns()
        RouteMockURLProtocol.handler = { request, body in
            if request.url?.host == "api.pinecone.io" {
                return (200, jsonData([
                    "name": "manuals", "dimension": 2, "metric": "euclidean", "host": manualsHost,
                    "status": ["state": "Ready", "ready": true],
                ]))
            }
            let json = body.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            let near = json?["namespace"] as? String == "a"
            return (200, jsonData(["namespace": "", "matches": [
                ["id": near ? "a1" : "b1", "score": near ? 0.12 : 0.95, "metadata": ["text": near ? "Near" : "Far", "source": "x.pdf"]],
            ]]))
        }
        UserDefaults.standard.set(1, forKey: SettingsStorageKeys.searchTopK)
        let pinecone = PineconeService(apiKey: "test", projectId: "test", sessionConfiguration: RouteMockURLProtocol.sessionConfiguration())
        let sut = makeSUT(pinecone: pinecone)
        sut.indexMetric = "euclidean"

        let results = try await sut.searchNamespaces(["a", "b"], of: "manuals", vector: [1, 0], sparse: nil, filter: nil, traceId: "t")

        XCTAssertEqual(results.map(\.content), ["Near"], "a euclidean score is a distance: the lowest is the closest")
        XCTAssertTrue(SearchViewModel.lowerScoreIsBetter(metric: "euclidean"))
        XCTAssertFalse(SearchViewModel.lowerScoreIsBetter(metric: "cosine"))
    }

    func testEverythingKeepsEverySearchsBestPassage() {
        // Raw scores from different indexes aren't comparable, so when there are more searches than
        // the usual 8 passages, each search's best passage still reaches the answer
        XCTAssertEqual(SearchViewModel.broadKeptCount(searchCount: 12, usesCodeInterpreter: false), 12)
        XCTAssertEqual(SearchViewModel.broadKeptCount(searchCount: 3, usesCodeInterpreter: false), 8)
        XCTAssertEqual(SearchViewModel.broadKeptCount(searchCount: 12, usesCodeInterpreter: true), 12)
        XCTAssertEqual(SearchViewModel.broadKeptCount(searchCount: 2, usesCodeInterpreter: true), 3)
        XCTAssertEqual(SearchViewModel.broadKeptCount(searchCount: 40, usesCodeInterpreter: false), 20)
    }

    func testEverythingReadsAEuclideanSearchsLowestScoreAsItsBest() {
        func passage(_ text: String, _ score: Float) -> SearchResultModel {
            SearchResultModel(content: text, sourceDocument: "\(text).pdf", score: score, metadata: [:])
        }
        let cosine = [passage("cos1", 0.80), passage("cos2", 0.70), passage("cos3", 0.40)]
        let euclidean = [passage("near", 0.05), passage("mid", 0.50), passage("far", 0.55)]

        let merged = SearchViewModel.mergedAcrossSearches([cosine, euclidean], lowerScoreIsBetter: [false, true])
        XCTAssertEqual(merged.first?.content, "near", "read as a similarity, the closest match would come last in its round")
        let order = merged.map(\.content)
        XCTAssertLessThan(order.firstIndex(of: "near")!, order.firstIndex(of: "mid")!, "each search keeps Pinecone's order")
        XCTAssertLessThan(order.firstIndex(of: "cos1")!, order.firstIndex(of: "cos2")!)
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
