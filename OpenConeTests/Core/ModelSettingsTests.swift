import XCTest
@testable import OpenCone

/// Which completion models Settings offers, what happens to a saved model OpenAI has shut down, and which
/// reasoning effort is sent to each model, all from the model catalog shared with OpenResponses
@MainActor
final class ModelSettingsTests: XCTestCase {
    private let keys = ["completionModel", "openai.reasoningEffort", "useCustomModel", "customCompletionModel", "accountModels"]
    private var saved: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        for key in keys {
            if let value = UserDefaults.standard.object(forKey: key) {
                saved[key] = value
            }
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in keys {
            if let value = saved[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        saved = [:]
        super.tearDown()
    }

    // MARK: - Configuration

    func testGPT6AndLaterModelsAreReasoningModels() {
        XCTAssertTrue(Configuration.isReasoningModel("gpt-6.1-sol"))
        XCTAssertTrue(Configuration.isReasoningModel("gpt-6-astra"))
        XCTAssertTrue(Configuration.isReasoningModel("gpt-5.6-terra"))
        XCTAssertTrue(Configuration.isReasoningModel("gpt-7-luna"), "a later general release, by its version number")
        XCTAssertTrue(Configuration.isReasoningModel("gpt-5.5"))
        XCTAssertFalse(Configuration.isReasoningModel("gpt-4o"))
        XCTAssertFalse(Configuration.isReasoningModel("gpt-4.1"))
        XCTAssertEqual(Configuration.completionModel, "gpt-6-sol", "the catalog's default model")
    }

    func testEffortFollowsTheCatalog() {
        XCTAssertEqual(CurrentModelCatalog.normalizedEffort("none", model: "gpt-6.1-sol"), "low", "GPT-6.1 Sol rejects none")
        XCTAssertEqual(CurrentModelCatalog.normalizedEffort("minimal", model: "gpt-6-astra"), "low")
        XCTAssertEqual(CurrentModelCatalog.normalizedEffort("high", model: "gpt-6.1-sol"), "high")
        XCTAssertEqual(CurrentModelCatalog.normalizedEffort("none", model: "gpt-6-sol"), "none")
        XCTAssertEqual(CurrentModelCatalog.normalizedEffort("none", model: "gpt-6-luna"), "none")
        XCTAssertEqual(CurrentModelCatalog.normalizedEffort("max", model: "gpt-5.5"), "medium")
        XCTAssertEqual(CurrentModelCatalog.normalizedEffort("bogus", model: "gpt-6.1-sol"), "medium")
    }

    func testThePickerListsTheCatalogAndNoRetiredModel() {
        let settings = SettingsViewModel()
        XCTAssertEqual(Array(settings.availableCompletionModels.prefix(4)), ["gpt-6.1-sol", "gpt-6-sol", "gpt-6-astra", "gpt-6-luna"])
        XCTAssertFalse(settings.availableCompletionModels.contains { CurrentModelCatalog.isRetired($0) })
        XCTAssertFalse(settings.availableCompletionModels.contains("o1-mini"))
    }

    func testANewerModelOnTheAccountLeadsTheMenu() {
        let settings = SettingsViewModel()
        settings.accountModels = ["gpt-6.2-sol"]
        XCTAssertEqual(settings.availableCompletionModels.first, "gpt-6.2-sol")
    }

    // MARK: - Saved settings

    func testASavedRetiredModelMovesToItsDocumentedReplacement() {
        UserDefaults.standard.set("o3", forKey: "completionModel")
        UserDefaults.standard.set("high", forKey: "openai.reasoningEffort")

        let settings = SettingsViewModel()

        XCTAssertEqual(settings.completionModel, "gpt-5.6-sol")
        XCTAssertEqual(settings.reasoningEffort, "high")
        // OpenAIService reads these from UserDefaults, so they are stored at once
        XCTAssertEqual(UserDefaults.standard.string(forKey: "completionModel"), "gpt-5.6-sol")
    }

    func testARetiredModelWithNoReplacementMovesToTheDefault() {
        UserDefaults.standard.set("codex-mini-latest", forKey: "completionModel")

        let settings = SettingsViewModel()

        XCTAssertEqual(settings.completionModel, "gpt-6-sol")
    }

    func testAVariantFollowsItsFamilysReplacement() {
        // o1-mini has no replacement of its own; the longest retired entry with one is o1
        XCTAssertEqual(CurrentModelCatalog.replacement(for: "o1-mini"), "gpt-5.6-sol")
        XCTAssertEqual(CurrentModelCatalog.replacement(for: "o4-mini-2025-04-16"), "gpt-5.6-terra")
    }

    func testAnEffortTheModelRejectsIsFixedAndStored() {
        UserDefaults.standard.set("gpt-6.1-sol", forKey: "completionModel")
        UserDefaults.standard.set("none", forKey: "openai.reasoningEffort")

        let settings = SettingsViewModel()

        XCTAssertEqual(settings.reasoningEffort, "low")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "openai.reasoningEffort"), "low")
    }

    func testAFreshInstallStoresTheDefaultModelsEffort() {
        let settings = SettingsViewModel()

        XCTAssertEqual(settings.completionModel, "gpt-6-sol")
        XCTAssertEqual(settings.reasoningEffort, "none", "GPT-6 Sol accepts none")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "openai.reasoningEffort"), "none")
    }

    func testAModelStillServedIsKept() {
        UserDefaults.standard.set("gpt-4o", forKey: "completionModel")

        let settings = SettingsViewModel()

        XCTAssertEqual(settings.completionModel, "gpt-4o")
    }

    func testSwitchingModelsKeepsTheEffortValid() {
        UserDefaults.standard.set("gpt-6-luna", forKey: "completionModel")
        UserDefaults.standard.set("none", forKey: "openai.reasoningEffort")
        let settings = SettingsViewModel()
        XCTAssertEqual(settings.reasoningEffort, "none")
        XCTAssertEqual(settings.availableReasoningEffortOptions, ["none", "low", "medium", "high", "xhigh", "max"])

        settings.completionModel = "gpt-6-astra"

        XCTAssertEqual(settings.reasoningEffort, "low")
        XCTAssertEqual(settings.availableReasoningEffortOptions, ["low", "medium", "high", "xhigh", "max"])
    }
}
