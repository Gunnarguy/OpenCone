import XCTest
@testable import OpenCone

/// What an answer request carries: the answer length held to the model, the Responses options from
/// Settings, the web search tool's options, and the earlier exchanges. Field names and values follow
/// OpenAI's create-response reference (read 2026-10-01).
@MainActor
final class AnswerRequestTests: XCTestCase {
    private let touchedKeys = [
        "completionModel", "openai.reasoningEffort", "search.maxOutputTokens", "search.webSearchEnabled",
        "search.codeInterpreterEnabled", RequestSettings.Key.verbosity, RequestSettings.Key.serviceTier,
        RequestSettings.Key.webSearchContextSize, RequestSettings.Key.webSearchDomains,
        RequestSettings.Key.historyExchanges,
    ]
    private var saved: [String: Any] = [:]
    private var bodies: [[String: Any]] = []

    override func setUp() {
        super.setUp()
        for key in touchedKeys {
            if let value = UserDefaults.standard.object(forKey: key) {
                saved[key] = value
            }
            UserDefaults.standard.removeObject(forKey: key)
        }
        URLProtocol.registerClass(RouteMockURLProtocol.self)
        RouteMockURLProtocol.reset()
        RouteMockURLProtocol.handler = { _, _ in
            (200, Data("event: response.completed\ndata: {\"type\":\"response.completed\",\"response\":{\"id\":\"resp_1\"}}\n\n".utf8))
        }
    }

    override func tearDown() {
        URLProtocol.unregisterClass(RouteMockURLProtocol.self)
        RouteMockURLProtocol.reset()
        for key in touchedKeys {
            if let value = saved[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        saved = [:]
        super.tearDown()
    }

    /// The JSON body of one streamed answer request
    private func streamedRequestBody(
        history: [ChatMessage] = [], context: String = "Context", codeInterpreter: Bool = false
    ) async throws -> [String: Any] {
        try await OpenAIService(apiKey: "test").streamCompletion(
            systemPrompt: "Answer.",
            userMessage: "Question",
            context: context,
            history: history,
            onTextDelta: { _ in },
            allowCodeInterpreter: codeInterpreter,
            onCompleted: {}
        )
        return try XCTUnwrap(RouteMockURLProtocol.requests.last?.body)
    }

    private func exchange(_ question: String, _ answer: String) -> [ChatMessage] {
        [ChatMessage(role: .user, text: question), ChatMessage(role: .assistant, text: answer)]
    }

    // MARK: Endpoints record

    func testAnAnswerRequestIsRecordedForEndpoints() async throws {
        UserDefaults.standard.set("gpt-5.5", forKey: "completionModel")
        APIActivity.shared.clear()

        _ = try await streamedRequestBody()

        // The task delegate reports on the main actor once the task's metrics are in
        for _ in 0..<40 where APIActivity.shared.lastCall(to: .responses) == nil {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        let call = try XCTUnwrap(APIActivity.shared.lastCall(to: .responses))
        XCTAssertEqual(call.status, 200)
        XCTAssertTrue(call.succeeded)
    }

    // MARK: Answer length

    func testAnswerLengthIsHeldToWhatTheModelWrites() async throws {
        UserDefaults.standard.set("gpt-4o", forKey: "completionModel")
        UserDefaults.standard.set(64_000, forKey: "search.maxOutputTokens")

        let body = try await streamedRequestBody()

        XCTAssertEqual(body["max_output_tokens"] as? Int, 16_384)
    }

    func testACurrentModelGetsTheFullAnswerLength() async throws {
        UserDefaults.standard.set("gpt-5.5", forKey: "completionModel")
        UserDefaults.standard.set(128_000, forKey: "search.maxOutputTokens")

        let body = try await streamedRequestBody()

        XCTAssertEqual(body["max_output_tokens"] as? Int, 128_000)
    }

    func testNoStoredLengthSendsTheDefault() async throws {
        UserDefaults.standard.set("gpt-5.5", forKey: "completionModel")

        let body = try await streamedRequestBody()

        XCTAssertEqual(body["max_output_tokens"] as? Int, RequestSettings.defaultMaxOutputTokens)
    }

    // MARK: Responses options

    func testVerbosityAndTierGoWithTheRequest() async throws {
        UserDefaults.standard.set("gpt-5.5", forKey: "completionModel")
        UserDefaults.standard.set("high", forKey: RequestSettings.Key.verbosity)
        UserDefaults.standard.set("flex", forKey: RequestSettings.Key.serviceTier)

        let body = try await streamedRequestBody()

        XCTAssertEqual((body["text"] as? [String: Any])?["verbosity"] as? String, "high")
        XCTAssertEqual(body["service_tier"] as? String, "flex")
        XCTAssertNil(body["truncation"], "auto truncation drops the passages, which come first in the input")
    }

    func testAutoTierAndAnOlderModelLeaveTheirFieldsOut() async throws {
        UserDefaults.standard.set("gpt-4o", forKey: "completionModel")
        UserDefaults.standard.set("low", forKey: RequestSettings.Key.verbosity)
        UserDefaults.standard.set("auto", forKey: RequestSettings.Key.serviceTier)

        let body = try await streamedRequestBody()

        XCTAssertNil(body["text"], "gpt-4o takes no verbosity")
        XCTAssertNil(body["service_tier"])
    }

    func testATierTheModelIsntOfferedAtIsLeftOut() async throws {
        UserDefaults.standard.set("gpt-4o", forKey: "completionModel")
        UserDefaults.standard.set("flex", forKey: RequestSettings.Key.serviceTier)

        let body = try await streamedRequestBody()

        XCTAssertNil(body["service_tier"], "OpenAI's pricing page has no Flex price for gpt-4o")
    }

    func testCodeInterpreterIsLeftOutForAModelWithoutIt() async throws {
        UserDefaults.standard.set(true, forKey: "search.codeInterpreterEnabled")
        UserDefaults.standard.set("gpt-5.2-pro", forKey: "completionModel")

        let withoutTool = try await streamedRequestBody(codeInterpreter: true)
        UserDefaults.standard.set("gpt-6.1-sol", forKey: "completionModel")
        let withTool = try await streamedRequestBody(codeInterpreter: true)

        let toolTypes = { (body: [String: Any]) in ((body["tools"] as? [[String: Any]]) ?? []).compactMap { $0["type"] as? String } }
        XCTAssertFalse(toolTypes(withoutTool).contains("code_interpreter"))
        XCTAssertTrue(toolTypes(withTool).contains("code_interpreter"))
    }

    func testAStoredValueTheAPIRejectsFallsBackToTheDefault() {
        UserDefaults.standard.set("loud", forKey: RequestSettings.Key.verbosity)
        UserDefaults.standard.set("ultrafast", forKey: RequestSettings.Key.serviceTier)
        UserDefaults.standard.set(99, forKey: RequestSettings.Key.historyExchanges)

        XCTAssertEqual(RequestSettings.verbosity, "medium")
        XCTAssertNil(RequestSettings.serviceTier)
        XCTAssertEqual(RequestSettings.historyExchanges, RequestSettings.maxHistoryExchanges)
    }

    // MARK: Web search

    func testWebSearchCarriesItsDepthAndSites() async throws {
        UserDefaults.standard.set("gpt-5.5", forKey: "completionModel")
        UserDefaults.standard.set(true, forKey: "search.webSearchEnabled")
        UserDefaults.standard.set("high", forKey: RequestSettings.Key.webSearchContextSize)
        UserDefaults.standard.set("https://www.fda.gov/drugs, who.int", forKey: RequestSettings.Key.webSearchDomains)

        let body = try await streamedRequestBody()
        let tools = try XCTUnwrap(body["tools"] as? [[String: Any]])
        let webSearch = try XCTUnwrap(tools.first { $0["type"] as? String == "web_search" })

        XCTAssertEqual(webSearch["search_context_size"] as? String, "high")
        XCTAssertEqual((webSearch["filters"] as? [String: Any])?["allowed_domains"] as? [String], ["fda.gov", "who.int"])
    }

    func testNoSitesMeansNoFilter() async throws {
        UserDefaults.standard.set("gpt-5.5", forKey: "completionModel")
        UserDefaults.standard.set(true, forKey: "search.webSearchEnabled")

        let body = try await streamedRequestBody()
        let tools = try XCTUnwrap(body["tools"] as? [[String: Any]])

        XCTAssertNil(tools.first?["filters"])
        XCTAssertNil(tools.first?["search_context_size"], "medium is the API's default, so the field is left out")
    }

    func testSitesAreCleanedUp() {
        XCTAssertEqual(
            RequestSettings.domains(from: "https://www.Example.com/path, docs.pinecone.io; who.int who.int\nlocalhost .com"),
            ["example.com", "docs.pinecone.io", "who.int"]
        )
        XCTAssertEqual(RequestSettings.domains(from: "  "), [])
    }

    // MARK: Memory

    func testEarlierExchangesGoAsPlainTextUpToTheSetting() async throws {
        UserDefaults.standard.set("gpt-5.5", forKey: "completionModel")
        UserDefaults.standard.set(2, forKey: RequestSettings.Key.historyExchanges)
        let history = exchange("First?", "One.") + exchange("Second?", "Two.") + exchange("Third?", "Three.")

        let body = try await streamedRequestBody(history: history)
        let input = try XCTUnwrap(body["input"] as? [[String: Any]])

        // The instructions with the passages, the last 2 exchanges, then the question
        XCTAssertEqual(input.count, 6)
        XCTAssertEqual(input.first?["role"] as? String, "system")
        XCTAssertEqual(input[1]["role"] as? String, "user")
        XCTAssertEqual(input[1]["content"] as? String, "Second?")
        XCTAssertEqual(input[2]["role"] as? String, "assistant")
        XCTAssertEqual(input[2]["content"] as? String, "Two.")
        XCTAssertEqual(input[4]["content"] as? String, "Three.")
        XCTAssertEqual(input.last?["role"] as? String, "user")
    }

    func testNoExchangesSendsOnlyTheQuestion() async throws {
        UserDefaults.standard.set("gpt-5.5", forKey: "completionModel")
        UserDefaults.standard.set(0, forKey: RequestSettings.Key.historyExchanges)

        let body = try await streamedRequestBody(history: exchange("First?", "One."))
        let input = try XCTUnwrap(body["input"] as? [[String: Any]])

        XCTAssertEqual(input.count, 2)
    }

    func testTheOldestExchangesGiveWayWhenTheWindowIsFull() {
        // gpt-4o reads 128,000 tokens: 16,384 go to the answer and about 100,000 to the passages,
        // which leaves room for three of these 3,000-token messages. The oldest of the three is an
        // answer whose question didn't fit, so it goes too.
        let long = String(repeating: "x", count: 9_000)
        let history = (0..<10).map { ChatMessage(role: $0.isMultiple(of: 2) ? .user : .assistant, text: "\($0)" + long) }

        let kept = OpenAIService.historyToSend(
            history, limit: 10, model: "gpt-4o", otherTextBytes: 300_000, maxOutputTokens: 16_384
        )

        XCTAssertEqual(kept.map(\.text), Array(history.suffix(2)).map(\.text))
        XCTAssertEqual(kept.first?.role, .user)
    }

    func testChineseTextCountsAsMoreTokensThanItsCharacters() {
        // 30,000 characters of Chinese are 90,000 bytes of UTF-8, about 30,000 tokens: more than the
        // room left in gpt-4o beside 280,000 bytes of passages and a 16,384-token answer
        let chinese = String(repeating: "检", count: 30_000)
        let history = [ChatMessage(role: .user, text: chinese), ChatMessage(role: .assistant, text: "好")]

        let kept = OpenAIService.historyToSend(
            history, limit: 2, model: "gpt-4o", otherTextBytes: 280_000, maxOutputTokens: 16_384
        )

        XCTAssertTrue(kept.isEmpty)
    }

    func testAModelWithoutAKnownWindowKeepsTheSetting() {
        let history = (0..<6).map { ChatMessage(role: .user, text: "\($0)") }

        let kept = OpenAIService.historyToSend(
            history, limit: 4, model: "my-fine-tune", otherTextBytes: 10_000_000, maxOutputTokens: 1_000
        )

        XCTAssertEqual(kept.map(\.text), ["2", "3", "4", "5"])
    }
}

/// What each model writes and reads, from its page on OpenAI's docs site (read 2026-10-01)
final class ModelLimitsTests: XCTestCase {
    func testMaxOutputByModel() {
        XCTAssertEqual(ModelLimits.maxOutputTokens(for: "gpt-4o"), 16_384)
        XCTAssertEqual(ModelLimits.maxOutputTokens(for: "gpt-4o-mini"), 16_384)
        XCTAssertEqual(ModelLimits.maxOutputTokens(for: "gpt-4.1"), 32_768)
        XCTAssertEqual(ModelLimits.maxOutputTokens(for: "gpt-5.5"), 128_000)
        XCTAssertEqual(ModelLimits.maxOutputTokens(for: "gpt-6-sol"), 128_000)
    }

    func testContextWindowByModel() {
        XCTAssertEqual(ModelLimits.contextWindow(for: "gpt-4o"), 128_000)
        XCTAssertEqual(ModelLimits.contextWindow(for: "gpt-5.4-mini"), 400_000)
        XCTAssertEqual(ModelLimits.contextWindow(for: "gpt-5.5"), 1_050_000)
    }

    func testLengthChoicesStopAtTheModelsLimit() {
        XCTAssertEqual(ModelLimits.lengthChoices(for: "gpt-4o"), [1_000, 2_000, 4_000, 8_000, 16_000, 16_384])
        XCTAssertEqual(ModelLimits.lengthChoices(for: "gpt-5.5").last, 128_000)
        XCTAssertTrue(ModelLimits.lengthChoices(for: "gpt-5.5").contains(64_000))
    }

    func testServiceTiersFollowOpenAIsPricingPage() {
        XCTAssertEqual(ModelLimits.serviceTiers(for: "gpt-6.1-sol"), ["auto", "default", "flex", "fast"])
        XCTAssertEqual(ModelLimits.serviceTiers(for: "gpt-4o"), ["auto", "default", "fast"])
        XCTAssertEqual(ModelLimits.serviceTiers(for: "gpt-5.5-pro"), ["auto", "default", "flex"])
        XCTAssertEqual(ModelLimits.serviceTiers(for: "gpt-5.2-pro"), ["auto", "default"])
        XCTAssertEqual(ModelLimits.serviceTiers(for: "gpt-5.4-2026-03-05"), ["auto", "default", "flex", "fast"], "a dated snapshot")
        XCTAssertEqual(ModelLimits.serviceTiers(for: "gpt-6.2-sol"), ["auto", "default"], "a model the tables don't name yet")
    }

    func testAFineTuneReadsAsTheModelItWasMadeFrom() {
        XCTAssertEqual(ModelLimits.baseModel("ft:gpt-4o-mini-2024-07-18:acme::abc123"), "gpt-4o-mini-2024-07-18")
        XCTAssertEqual(ModelLimits.maxOutputTokens(for: "ft:gpt-4o-mini-2024-07-18:acme::abc123"), 16_384)
        XCTAssertEqual(ModelLimits.contextWindow(for: "ft:gpt-4.1-2025-04-14:acme::abc123"), 1_047_576)
        XCTAssertEqual(ModelLimits.serviceTiers(for: "ft:gpt-4o-mini-2024-07-18:acme::abc123"), ["auto", "default"])
    }

    func testCodeInterpreterFollowsEachModelsTools() {
        XCTAssertTrue(ModelLimits.supportsCodeInterpreter("gpt-6.1-sol"))
        XCTAssertTrue(ModelLimits.supportsCodeInterpreter("gpt-5.5-pro"))
        XCTAssertFalse(ModelLimits.supportsCodeInterpreter("gpt-5.4-pro"))
        XCTAssertFalse(ModelLimits.supportsCodeInterpreter("gpt-5.2-pro"))
    }

    /// Each list as the model's page states it (read 2026-10-01)
    func testReasoningEffortsFollowEachModelsPage() {
        XCTAssertEqual(CurrentModelCatalog.reasoningEfforts(for: "gpt-6.1-sol"), ["low", "medium", "high", "xhigh", "max"])
        XCTAssertEqual(CurrentModelCatalog.reasoningEfforts(for: "gpt-6-astra"), ["low", "medium", "high", "xhigh", "max"])
        XCTAssertEqual(CurrentModelCatalog.reasoningEfforts(for: "gpt-6-sol"), ["none", "low", "medium", "high", "xhigh", "max"])
        XCTAssertEqual(CurrentModelCatalog.reasoningEfforts(for: "gpt-5.5"), ["none", "low", "medium", "high", "xhigh"])
        XCTAssertEqual(CurrentModelCatalog.reasoningEfforts(for: "gpt-5.5-pro"), ["medium", "high", "xhigh"])
        XCTAssertEqual(CurrentModelCatalog.reasoningEfforts(for: "gpt-5.1"), ["none", "low", "medium", "high"])
    }

    @MainActor
    func testSwitchingToAModelWithoutOffMovesTheEffortToLow() {
        let domainName = Bundle.main.bundleIdentifier ?? "AI.FascinAIting.OpenCone"
        let savedDomain = UserDefaults.standard.persistentDomain(forName: domainName)
        defer {
            if let savedDomain {
                UserDefaults.standard.setPersistentDomain(savedDomain, forName: domainName)
            } else {
                UserDefaults.standard.removePersistentDomain(forName: domainName)
            }
        }
        let settings = SettingsViewModel()
        settings.completionModel = "gpt-6-sol"
        settings.reasoningEffort = "none"
        settings.serviceTier = "flex"

        settings.completionModel = "gpt-6.1-sol"
        XCTAssertEqual(settings.reasoningEffort, "low")
        XCTAssertFalse(settings.availableReasoningEffortOptions.contains("none"))
        XCTAssertEqual(settings.serviceTier, "flex")

        settings.completionModel = "gpt-5.2-pro"
        XCTAssertEqual(settings.serviceTier, "auto", "gpt-5.2-pro has no Flex")
        XCTAssertFalse(settings.supportsCodeInterpreter)
    }

    func testVerbosityIsForGPT5AndLater() {
        XCTAssertTrue(ModelLimits.supportsVerbosity("gpt-5.5"))
        XCTAssertTrue(ModelLimits.supportsVerbosity("gpt-6-sol"))
        XCTAssertFalse(ModelLimits.supportsVerbosity("gpt-4o"))
        XCTAssertFalse(ModelLimits.supportsVerbosity("gpt-4.1"))
    }

    func testShortCounts() {
        XCTAssertEqual(ModelLimits.shortCount(128_000), "128K")
        XCTAssertEqual(ModelLimits.shortCount(16_384), "16.4K")
        XCTAssertEqual(ModelLimits.shortCount(1_050_000), "1.05M")
        XCTAssertEqual(ModelLimits.shortCount(800), "800")
    }

    @MainActor
    func testSwitchingToASmallerModelShortensTheAnswerLength() {
        // The view model saves its settings to the app's defaults; put them back afterwards
        let domainName = Bundle.main.bundleIdentifier ?? "AI.FascinAIting.OpenCone"
        let savedDomain = UserDefaults.standard.persistentDomain(forName: domainName)
        defer {
            if let savedDomain {
                UserDefaults.standard.setPersistentDomain(savedDomain, forName: domainName)
            } else {
                UserDefaults.standard.removePersistentDomain(forName: domainName)
            }
        }
        let settings = SettingsViewModel()
        settings.completionModel = "gpt-5.5"
        settings.maxOutputTokens = 64_000

        settings.completionModel = "gpt-4o"

        XCTAssertEqual(settings.maxOutputTokens, 16_384)
        XCTAssertEqual(settings.answerLengthChoices.last, 16_384)
    }
}

/// Which endpoint a request goes to, from its host, method and path
final class APIEndpointTests: XCTestCase {
    private func endpoint(_ method: String, _ url: String) -> APIEndpoint? {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = method
        return APIEndpoint.classify(request)
    }

    func testOpenAIEndpoints() {
        XCTAssertEqual(endpoint("POST", "https://api.openai.com/v1/responses"), .responses)
        XCTAssertEqual(endpoint("POST", "https://api.openai.com/v1/embeddings"), .embeddings)
        XCTAssertEqual(endpoint("GET", "https://api.openai.com/v1/models"), .models)
        XCTAssertEqual(endpoint("GET", "https://developers.openai.com/api/docs/models/gpt-6-sol.md"), .modelPages)
    }

    func testPineconeControlAndInferenceEndpoints() {
        XCTAssertEqual(endpoint("GET", "https://api.pinecone.io/indexes"), .listIndexes)
        XCTAssertEqual(endpoint("POST", "https://api.pinecone.io/indexes"), .createIndex)
        XCTAssertEqual(endpoint("GET", "https://api.pinecone.io/indexes/manuals"), .describeIndex)
        XCTAssertEqual(endpoint("DELETE", "https://api.pinecone.io/indexes/manuals"), .deleteIndex)
        XCTAssertEqual(endpoint("POST", "https://api.pinecone.io/rerank"), .rerank)
        XCTAssertEqual(endpoint("POST", "https://api.pinecone.io/embed"), .sparseEmbed)
    }

    func testIndexHostEndpoints() {
        let host = "https://manuals-abc123.svc.aped-1234.pinecone.io"
        XCTAssertEqual(endpoint("POST", "\(host)/query"), .query)
        XCTAssertEqual(endpoint("POST", "\(host)/vectors/upsert"), .upsert)
        XCTAssertEqual(endpoint("POST", "\(host)/vectors/delete"), .deleteVectors)
        XCTAssertEqual(endpoint("GET", "\(host)/describe_index_stats"), .indexStats)
        XCTAssertEqual(endpoint("GET", "\(host)/namespaces"), .listNamespaces)
        XCTAssertEqual(endpoint("POST", "\(host)/namespaces"), .createNamespace)
        XCTAssertEqual(endpoint("DELETE", "\(host)/namespaces/baxter"), .deleteNamespace)
    }

    func testOtherHostsAreNotCounted() {
        XCTAssertNil(endpoint("GET", "https://example.com/v1/responses"))
        XCTAssertNil(endpoint("GET", "https://api.openai.com/v1/files"))
    }

    func testEveryEndpointHasItsServicesMethodAndAVersionWhereItIsPinecones() {
        for endpoint in APIEndpoint.allCases {
            XCTAssertTrue(["GET", "POST", "DELETE"].contains(endpoint.method), "\(endpoint)")
            XCTAssertEqual(endpoint.pineconeVersionGroup == nil, endpoint.service == .openAI || endpoint.service == .openAIDocs, "\(endpoint)")
        }
    }
}

/// Settings stored by earlier versions that would now break a request
@MainActor
final class StoredSettingsMigrationTests: XCTestCase {
    private let domainName = Bundle.main.bundleIdentifier ?? "AI.FascinAIting.OpenCone"
    private var savedDomain: [String: Any]?

    override func setUp() {
        super.setUp()
        savedDomain = UserDefaults.standard.persistentDomain(forName: domainName)
    }

    override func tearDown() {
        if let savedDomain {
            UserDefaults.standard.setPersistentDomain(savedDomain, forName: domainName)
        } else {
            UserDefaults.standard.removePersistentDomain(forName: domainName)
        }
        super.tearDown()
    }

    func testANamespaceVersionOlderThanCreateNamespaceReadsAsTheDefault() {
        let store = SecureSettingsStore.shared
        store.setPineconeNamespaceVersion("2025-01")
        XCTAssertEqual(store.getPineconeNamespaceVersion(), PineconeAPIVersions.namespaces)

        store.setPineconeNamespaceVersion("2026-07")
        XCTAssertEqual(store.getPineconeNamespaceVersion(), "2026-07")
    }

    func testTheOldDefaultAnswerLengthIsRaisedOnce() {
        UserDefaults.standard.set(4_000, forKey: "search.maxOutputTokens")
        UserDefaults.standard.removeObject(forKey: SettingsViewModel.answerLengthRaisedKey)
        UserDefaults.standard.set("gpt-6-sol", forKey: "completionModel")

        XCTAssertEqual(SettingsViewModel().maxOutputTokens, RequestSettings.defaultMaxOutputTokens)

        // Chosen again afterwards, 4,000 stays
        UserDefaults.standard.set(4_000, forKey: "search.maxOutputTokens")
        XCTAssertEqual(SettingsViewModel().maxOutputTokens, 4_000)
    }

    func testARegionPineconeDoesntOfferIsCorrectedAndStored() {
        let store = SecureSettingsStore.shared
        store.setPineconeCloud("aws")
        store.setPineconeRegion("us-east-2")

        let settings = SettingsViewModel()

        XCTAssertEqual(settings.pineconeRegion, "us-east-1")
        XCTAssertEqual(store.getPineconeRegion(), "us-east-1", "index creation reads the stored region")
    }
}
