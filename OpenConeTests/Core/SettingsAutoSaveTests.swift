import Combine
import XCTest
@testable import OpenCone

/// The debounced auto-save: one change saves once, and saving doesn't set itself off again. Saving
/// used to reassign two watched settings, which restarted the debounce; a 2-second cooldown hid
/// that, and dropped any change made within it.
@MainActor
final class SettingsAutoSaveTests: XCTestCase {
    private var savedDomain: [String: Any]?
    private let domainName = Bundle.main.bundleIdentifier ?? "AI.FascinAIting.OpenCone"

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

    private func countSaves(of settings: SettingsViewModel, during seconds: Double, after change: () -> Void) async throws -> Int {
        var saves = 0
        let watch = settings.$lastAutoSaveTime
            .dropFirst()
            .compactMap { $0 }
            .sink { _ in saves += 1 }
        change()
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        watch.cancel()
        return saves
    }

    func testOneChangeSavesOnceAndTheSaveDoesNotStartAnother() async throws {
        let settings = SettingsViewModel()
        let saves = try await countSaves(of: settings, during: 3.6) {
            settings.temperature = settings.temperature == 0.55 ? 0.6 : 0.55
        }
        XCTAssertEqual(saves, 1, "the save reassigned watched settings and saved again every second")
    }

    func testAChangeSoonAfterASaveIsSavedToo() async throws {
        let settings = SettingsViewModel()
        _ = try await countSaves(of: settings, during: 1.3) { settings.webSearchEnabled.toggle() }
        let expected = !settings.codeInterpreterEnabled
        settings.codeInterpreterEnabled = expected
        try await Task.sleep(nanoseconds: 1_400_000_000)

        XCTAssertEqual(UserDefaults.standard.object(forKey: "search.codeInterpreterEnabled") as? Bool, expected,
                       "the old cooldown dropped a change made within 2 seconds of a save")
    }

    func testSettingTheSameValueAgainDoesNotSave() async throws {
        let settings = SettingsViewModel()
        let saves = try await countSaves(of: settings, during: 1.5) {
            settings.defaultTopK = settings.defaultTopK
            settings.metadataPresets = settings.metadataPresets
        }
        XCTAssertEqual(saves, 0)
    }
}
