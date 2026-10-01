import XCTest
@testable import OpenCone

@MainActor
final class SearchRoutingStateTests: XCTestCase {
    private var originalRouting: Any?
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        originalRouting = UserDefaults.standard.object(forKey: SettingsStorageKeys.indexRoutingEnabled)
        UserDefaults.standard.removeObject(forKey: SettingsStorageKeys.indexRoutingEnabled)
        suiteName = "SearchRoutingStateTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        if let originalRouting {
            UserDefaults.standard.set(originalRouting, forKey: SettingsStorageKeys.indexRoutingEnabled)
        } else {
            UserDefaults.standard.removeObject(forKey: SettingsStorageKeys.indexRoutingEnabled)
        }
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeSUT(withRouter: Bool = true, store: IndexCatalogStore? = nil) -> SearchViewModel {
        let openAIService = OpenAIService(apiKey: "test")
        let pineconeService = PineconeService(apiKey: "test", projectId: "test")
        let responses = ResponsesClient(apiKey: "test")
        return SearchViewModel(
            pineconeService: pineconeService,
            openAIService: openAIService,
            embeddingService: EmbeddingService(openAIService: openAIService),
            settingsViewModel: SettingsViewModel(),
            indexRouter: withRouter ? IndexRouter(responses: responses) : nil,
            indexSurveyor: nil,
            indexCatalogStore: store
        )
    }

    func testRoutingIsOnByDefaultWithTwoPlacesToSearch() {
        let sut = makeSUT()
        XCTAssertTrue(sut.settingsViewModel.indexRoutingEnabled)

        sut.pineconeIndexes = ["manuals"]
        sut.namespaces = [""]
        XCTAssertFalse(sut.shouldRouteSearch, "one index, one namespace: search it directly")

        sut.namespaces = ["baxter", "bd"]
        XCTAssertTrue(sut.shouldRouteSearch, "one index, two namespaces")

        sut.namespaces = [""]
        sut.pineconeIndexes = ["manuals", "research"]
        XCTAssertTrue(sut.shouldRouteSearch, "two indexes")

        sut.settingsViewModel.indexRoutingEnabled = false
        XCTAssertFalse(sut.shouldRouteSearch, "switched off in Settings")
    }

    func testNoRoutingWithoutARouter() {
        let sut = makeSUT(withRouter: false)
        sut.pineconeIndexes = ["manuals", "research"]
        XCTAssertFalse(sut.shouldRouteSearch)
    }

    func testEditingASummaryMarksItAsThePersonsAndSavesIt() {
        let store = IndexCatalogStore(projectId: "p", defaults: defaults)
        store.save(["manuals": makeProfile("manuals", summary: "Drafted line.")])
        let sut = makeSUT(store: store)
        XCTAssertEqual(sut.indexProfiles["manuals"]?.summarySource, .drafted)

        sut.updateIndexSummary("  Pump manuals, one namespace per manufacturer.  ", for: "manuals")

        XCTAssertEqual(sut.indexProfiles["manuals"]?.summary, "Pump manuals, one namespace per manufacturer.")
        XCTAssertEqual(sut.indexProfiles["manuals"]?.summarySource, .person)
        XCTAssertEqual(store.load()["manuals"]?.summarySource, .person)

        sut.updateIndexSummary("", for: "manuals")
        XCTAssertEqual(sut.indexProfiles["manuals"]?.summarySource, .missing, "cleared: the app may draft one again")
    }
}
