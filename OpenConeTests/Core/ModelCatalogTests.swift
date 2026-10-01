import Foundation
import XCTest
@testable import OpenCone

/// Ported from OpenResponses (OpenResponsesTests/ModelCatalogTests.swift, 2026-10-01), without the parts OpenCone
/// leaves out (pro mode, async tools, presets): the built-in model list, settings read from OpenAI's docs pages,
/// and shutdown dates.
@MainActor
final class ModelCatalogTests: XCTestCase {
    private var directory: URL!
    private var defaults: UserDefaults!
    private let suite = "ModelCatalogTests"
    private let gpt62 = ModelCatalog.Model(id: "gpt-6.2-sol", summary: "Test model", reasoningEfforts: ["low", "medium", "high"],
                                           pro: false, asyncTools: true, released: "2026-10-01")

    /// Laid out like OpenAI's model pages (the GPT-6.1 Sol page on September 29, 2026), shortened.
    private let gpt61Page = """
    # GPT-6.1 Sol

    > For the complete documentation index, see [llms.txt](/llms.txt).

    > Near-Astra performance for complex work at a lower cost.

    Model ID: `gpt-6.1-sol`

    `reasoning.effort` supports `low`, `medium` (default), `high`, `xhigh`, and
    `max`. The `none` and `minimal` reasoning efforts are not supported.

    ## Endpoints

    | Endpoint | Route | Support |
    | --- | --- | --- |
    | Chat Completions | `v1/chat/completions` | Supported |
    | Responses | `v1/responses` | Supported |
    | Realtime | `v1/realtime` | Not supported |
    """

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        ModelCatalogStore.shared.use(ModelCatalogStore.builtIn)
        ModelCatalogStore.shared.forgetLearned()
        ModelCatalogStore.shared.recordShutdowns([:])
        UserDefaults.standard.removeObject(forKey: "accountModelShutdowns")
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    func testTheBuiltInListIsValidAndIsWhatTheMenusList() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "ModelCatalog", withExtension: "json"), "ModelCatalog.json must be in the app bundle")
        let catalog = try XCTUnwrap(ModelCatalog.decode(Data(contentsOf: url)))
        XCTAssertEqual(ModelCatalogStore.builtIn, catalog)
        XCTAssertEqual(catalog.defaultModel, "gpt-6-sol")
        XCTAssertEqual(CurrentModelCatalog.recommended, catalog.current.map(\.id))
        XCTAssertEqual(CurrentModelCatalog.recommended.first, "gpt-6.1-sol")
        XCTAssertEqual(CurrentModelCatalog.legacy, catalog.earlier)
    }

    func testListsTheAppCannotUseAreRejected() throws {
        let valid = try builtInJSON()
        XCTAssertNotNil(ModelCatalog.decode(try data(valid)))
        let models = try XCTUnwrap(valid["current"] as? [[String: Any]])
        func changingFirstModel(_ key: String, to value: Any?) -> (inout [String: Any]) -> Void {
            { json in
                var changed = models
                changed[0][key] = value
                json["current"] = changed
            }
        }
        let cases: [(String, (inout [String: Any]) -> Void)] = [
            ("a newer schema", { $0["schema"] = 2 }),
            ("an unknown effort", changingFirstModel("reasoningEfforts", to: ["low", "turbo"])),
            ("efforts out of order", changingFirstModel("reasoningEfforts", to: ["high", "low"])),
            ("a model ID with a space", changingFirstModel("id", to: "gpt 6")),
            ("an empty summary", changingFirstModel("summary", to: "")),
            ("a missing field", changingFirstModel("pro", to: nil)),
            ("a default model that is not current", { $0["defaultModel"] = "gpt-4o" }),
            ("a model listed twice", { $0["earlier"] = ["gpt-6-sol"] }),
        ]
        for (name, change) in cases {
            var json = valid
            change(&json)
            XCTAssertNil(ModelCatalog.decode(try data(json)), name)
        }
    }

    func testTheListInUseSetsTheMenusTheDefaultAndEachModelsSettings() {
        let builtIn = ModelCatalogStore.builtIn
        ModelCatalogStore.shared.use(ModelCatalog(schema: 1, revision: 2, updated: "2026-10-01", notes: nil, defaultModel: "gpt-6.2-sol",
                                                  current: [gpt62] + builtIn.current, earlier: builtIn.earlier,
                                                  retired: builtIn.retired + [.init(id: "gpt-4.5-preview", replacement: "gpt-6-luna")]))
        XCTAssertEqual(CurrentModelCatalog.defaultModel, "gpt-6.2-sol")
        XCTAssertEqual(Configuration.completionModel, "gpt-6.2-sol")
        XCTAssertEqual(CurrentModelCatalog.selectionModels(including: "gpt-6-sol").first, "gpt-6.2-sol")
        XCTAssertEqual(CurrentModelCatalog.reasoningEfforts(for: "gpt-6.2-sol-2026-10-01"), ["low", "medium", "high"])
        XCTAssertEqual(CurrentModelCatalog.description(for: "gpt-6.2-sol"), "Test model")
        XCTAssertTrue(CurrentModelCatalog.isRetired("gpt-4.5-preview-2025-02-27"))
        XCTAssertEqual(CurrentModelCatalog.replacement(for: "gpt-4.5-preview-2025-02-27"), "gpt-6-luna")
        XCTAssertEqual(CurrentModelCatalog.replacement(for: "gpt-5-mini-2025-08-07"), "gpt-5.6-terra", "the longest matching entry wins")
        XCTAssertEqual(CurrentModelCatalog.replacement(for: "gpt-5.1-codex"), "gpt-6.2-sol", "no listed replacement: the default model")
    }

    // MARK: - OpenAI's model pages

    func testAModelPageGivesItsReasoningEffortsAndSummary() {
        guard case .model(let model) = ModelCatalog.settings(fromDocsPage: gpt61Page, id: "gpt-6.1-sol", checkedOn: "2026-09-29") else {
            return XCTFail("the page should give settings")
        }
        XCTAssertEqual(model.reasoningEfforts, ["low", "medium", "high", "xhigh", "max"])
        XCTAssertEqual(model.summary, "Near-Astra performance for complex work at a lower cost")
        XCTAssertEqual(model.released, "2026-09-29")
        XCTAssertEqual(ModelCatalog.docsPageURL(for: "gpt-6.1-sol")?.absoluteString, "https://developers.openai.com/api/docs/models/gpt-6.1-sol.md")
        XCTAssertNil(ModelCatalog.docsPageURL(for: "../secrets"))
    }

    func testPagesWithoutUsableSettingsAreRecognized() {
        let noResponses = gpt61Page.replacingOccurrences(of: "| Responses | `v1/responses` | Supported |", with: "| Responses | `v1/responses` | Not supported |")
        XCTAssertEqual(ModelCatalog.settings(fromDocsPage: noResponses, id: "gpt-6.1-sol", checkedOn: "2026-09-29"), .unsupported)
        let noTable = gpt61Page.components(separatedBy: "## Endpoints")[0]
        XCTAssertEqual(ModelCatalog.settings(fromDocsPage: noTable, id: "gpt-6.1-sol", checkedOn: "2026-09-29"), .unreadable)
        let noEfforts = gpt61Page.replacingOccurrences(of: "`reasoning.effort` supports", with: "Reasoning covers")
        XCTAssertEqual(ModelCatalog.settings(fromDocsPage: noEfforts, id: "gpt-6.1-sol", checkedOn: "2026-09-29"), .unreadable)
        XCTAssertEqual(ModelCatalog.settings(fromDocsPage: "<html>Not found</html>", id: "gpt-6.1-sol", checkedOn: "2026-09-29"), .unreadable)
    }

    func testNewModelsAreLookedUpOnceKeptAndCheckedAgainAfterAWeek() async throws {
        let store = ModelCatalogStore(cacheDirectory: directory, defaults: defaults, restore: true, readsDocs: true)
        var requested: [String] = []
        let now = Date()
        let page = gpt61Page.replacingOccurrences(of: "gpt-6.1-sol", with: "gpt-6.2-sol")
        let load: (URL) async throws -> (Data, URLResponse) = { url in
            requested.append(url.lastPathComponent)
            let found = url.lastPathComponent == "gpt-6.2-sol.md"
            return (Data((found ? page : "Not found").utf8), HTTPURLResponse(url: url, statusCode: found ? 200 : 404, httpVersion: nil, headerFields: nil)!)
        }

        let changed = await store.learnSettings(for: ["gpt-6.2-sol", "gpt-7-luna"], now: now, load: load)
        XCTAssertTrue(changed)
        XCTAssertEqual(requested, ["gpt-6.2-sol.md", "gpt-7-luna.md"])
        XCTAssertEqual(store.learnedModel("gpt-6.2-sol")?.reasoningEfforts, ["low", "medium", "high", "xhigh", "max"])
        XCTAssertNil(store.learnedModel("gpt-7-luna"), "a missing page leaves the fallback settings")

        _ = await store.learnSettings(for: ["gpt-6.2-sol", "gpt-7-luna"], now: now.addingTimeInterval(86_400), load: load)
        XCTAssertEqual(requested.count, 2, "each page is read once a week at most")

        let relaunched = ModelCatalogStore(cacheDirectory: directory, defaults: defaults, restore: true, readsDocs: true)
        XCTAssertEqual(relaunched.learnedModel("gpt-6.2-sol")?.summary, "Near-Astra performance for complex work at a lower cost")
    }

    func testTheSharedStoreNeverReadsAPageUnderUnitTests() async {
        let shared = await ModelCatalogStore.shared.learnSettings(for: ["gpt-6.2-sol"]) { _ in
            XCTFail("the shared store never reads a page under unit tests")
            throw URLError(.cancelled)
        }
        XCTAssertFalse(shared)
    }

    func testSettingsFromAPageReachTheMenus() {
        let store = ModelCatalogStore.shared
        store.remember(.init(model: gpt62, checked: Date()), for: "gpt-6.2-sol")
        store.remember(.init(unsupported: true, checked: Date()), for: "gpt-6.3-sol")
        XCTAssertEqual(CurrentModelCatalog.reasoningEfforts(for: "gpt-6.2-sol"), ["low", "medium", "high"])
        XCTAssertEqual(CurrentModelCatalog.description(for: "gpt-6.2-sol"), "Test model")
        XCTAssertEqual(CurrentModelCatalog.currentAccountModels(["gpt-6.2-sol", "gpt-6.3-sol", "gpt-6-sol"]), ["gpt-6.2-sol", "gpt-6-sol"],
                       "a model whose page rules out the Responses API is left out")
        // A model with no page read yet uses the fallback: reasoning starts at low.
        XCTAssertEqual(CurrentModelCatalog.reasoningEfforts(for: "gpt-6.4-sol"), ["low", "medium", "high", "xhigh", "max"])
    }

    // MARK: - Shutdown dates

    func testShutdownDatesRetireAModelThirtyDaysAhead() {
        let store = ModelCatalogStore(cacheDirectory: directory, defaults: defaults, restore: true)
        let now = Date()
        store.recordShutdowns(["gpt-6-sol-2026-09-22": day(now, 10), "gpt-6-luna": day(now, 90), "gpt-5.5": day(now, -5), "gpt-4o": "soon"])
        XCTAssertTrue(store.isShuttingDown("gpt-6-sol-2026-09-22", now: now))
        XCTAssertFalse(store.isShuttingDown("gpt-6-luna", now: now), "90 days out is not yet retired")
        XCTAssertTrue(store.isShuttingDown("gpt-5.5", now: now))
        XCTAssertFalse(store.isShuttingDown("gpt-4o", now: now), "an unreadable date is ignored")
        XCTAssertFalse(store.isShuttingDown("gpt-6-sol", now: now), "a snapshot's date does not retire its alias")

        ModelCatalogStore.shared.recordShutdowns(["gpt-5.5": day(now, -5)])
        XCTAssertTrue(CurrentModelCatalog.isRetired("gpt-5.5"))
    }

    func testTheModelListingDecodesShutdownDates() throws {
        let json = #"""
        {"object": "list", "data": [
          {"id": "gpt-6-sol", "object": "model", "created": 1, "owned_by": "openai", "shutdown_date": "2026-10-23"},
          {"id": "gpt-6-luna", "object": "model", "created": 1, "owned_by": "openai", "shutdown_date": null},
          {"id": "gpt-6-astra", "object": "model", "created": 1, "owned_by": "openai"}]}
        """#
        let listing = try JSONDecoder().decode(OpenAIModelsResponse.self, from: Data(json.utf8))
        XCTAssertEqual(listing.data.map(\.shutdownDate), ["2026-10-23", nil, nil])
    }

    // MARK: - Helpers

    private func builtInJSON() throws -> [String: Any] {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "ModelCatalog", withExtension: "json"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private func data(_ json: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: json)
    }

    private func day(_ date: Date, _ offset: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date.addingTimeInterval(Double(offset) * 86_400))
    }
}
