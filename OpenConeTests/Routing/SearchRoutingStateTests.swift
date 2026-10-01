import XCTest
@testable import OpenCone

@MainActor
final class SearchRoutingStateTests: XCTestCase {
    private let scopeKeys = [SettingsStorageKeys.indexRoutingEnabled, SettingsStorageKeys.searchScope]
    private var saved: [String: Any] = [:]
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        for key in scopeKeys {
            if let value = UserDefaults.standard.object(forKey: key) {
                saved[key] = value
            }
            UserDefaults.standard.removeObject(forKey: key)
        }
        suiteName = "SearchRoutingStateTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        for key in scopeKeys {
            if let value = saved[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        saved = [:]
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
        sut.selectedIndex = "manuals"
        sut.namespaces = [""]
        XCTAssertFalse(sut.shouldRouteSearch, "one index, one namespace: search it directly")

        sut.namespaces = ["baxter", "bd"]
        XCTAssertTrue(sut.shouldRouteSearch, "one index, two namespaces")

        sut.namespaces = [""]
        sut.pineconeIndexes = ["manuals", "research"]
        XCTAssertTrue(sut.shouldRouteSearch, "two indexes")

        sut.settingsViewModel.indexRoutingEnabled = false
        XCTAssertFalse(sut.shouldRouteSearch, "switched off in Settings")
        XCTAssertEqual(sut.settingsViewModel.searchScope, .oneIndex)

        sut.settingsViewModel.searchScope = .everything
        XCTAssertFalse(sut.shouldRouteSearch, "Everything searches every namespace instead of asking the model")
        XCTAssertTrue(sut.searchesEverything)
        XCTAssertTrue(sut.settingsViewModel.indexRoutingEnabled)
    }

    func testTheScopeIsReadFromTheOlderRoutingSwitch() {
        UserDefaults.standard.set(false, forKey: SettingsStorageKeys.indexRoutingEnabled)
        XCTAssertEqual(SettingsViewModel().searchScope, .oneIndex)

        UserDefaults.standard.set(SearchScope.everything.rawValue, forKey: SettingsStorageKeys.searchScope)
        XCTAssertEqual(SettingsViewModel().searchScope, .everything, "the scope wins once it's stored")
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
