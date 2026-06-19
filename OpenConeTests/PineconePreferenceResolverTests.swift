import XCTest
@testable import OpenCone

@MainActor
final class PineconePreferenceResolverTests: XCTestCase {
    var defaults: UserDefaults!
    var sut: PineconePreferenceResolver!

    override func setUp() {
        super.setUp()
        // Use a unique suite name to ensure tests don't affect other settings and are deterministic
        defaults = UserDefaults(suiteName: #file)
        defaults.removePersistentDomain(forName: #file)
        sut = PineconePreferenceResolver(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: #file)
        defaults = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - resolveIndex Tests

    func testResolveIndexReturnsNilWhenNoAvailableIndexes() {
        let result = sut.resolveIndex(availableIndexes: [], currentSelection: "test")
        XCTAssertNil(result)
    }

    func testResolveIndexReturnsPreferredWhenEnforcedAndAvailable() {
        defaults.set(true, forKey: SettingsStorageKeys.searchEnforcePreferredIndex)
        defaults.set("preferred", forKey: SettingsStorageKeys.searchPreferredIndex)

        let result = sut.resolveIndex(availableIndexes: ["other", "preferred", "another"], currentSelection: "other")

        XCTAssertEqual(result, "preferred")
    }

    func testResolveIndexIgnoresPreferredWhenEnforcedButNotAvailable() {
        defaults.set(true, forKey: SettingsStorageKeys.searchEnforcePreferredIndex)
        defaults.set("preferred", forKey: SettingsStorageKeys.searchPreferredIndex)
        defaults.set("last", forKey: "oc.lastIndex")

        let result = sut.resolveIndex(availableIndexes: ["other", "last"], currentSelection: nil)

        XCTAssertEqual(result, "last")
    }

    func testResolveIndexReturnsLastWhenNotEnforced() {
        defaults.set(false, forKey: SettingsStorageKeys.searchEnforcePreferredIndex)
        defaults.set("preferred", forKey: SettingsStorageKeys.searchPreferredIndex)
        defaults.set("last", forKey: "oc.lastIndex")

        let result = sut.resolveIndex(availableIndexes: ["other", "last", "preferred"], currentSelection: nil)

        XCTAssertEqual(result, "last")
    }

    func testResolveIndexReturnsCurrentWhenLastNotAvailable() {
        defaults.set("last", forKey: "oc.lastIndex")

        let result = sut.resolveIndex(availableIndexes: ["other", "current"], currentSelection: "current")

        XCTAssertEqual(result, "current")
    }

    func testResolveIndexReturnsPreferredWhenLastAndCurrentNotAvailable() {
        defaults.set("last", forKey: "oc.lastIndex")
        defaults.set("preferred", forKey: SettingsStorageKeys.searchPreferredIndex)

        let result = sut.resolveIndex(availableIndexes: ["other", "preferred"], currentSelection: "current")

        XCTAssertEqual(result, "preferred")
    }

    func testResolveIndexReturnsFirstAvailableWhenNoPreferencesAvailable() {
        defaults.set("last", forKey: "oc.lastIndex")
        defaults.set("preferred", forKey: SettingsStorageKeys.searchPreferredIndex)

        let result = sut.resolveIndex(availableIndexes: ["first", "second"], currentSelection: "current")

        XCTAssertEqual(result, "first")
    }

    func testResolveIndexNormalizesEmptyStrings() {
        defaults.set("   ", forKey: SettingsStorageKeys.searchPreferredIndex)
        defaults.set("   ", forKey: "oc.lastIndex")

        let result = sut.resolveIndex(availableIndexes: ["first", "second"], currentSelection: "   ")

        XCTAssertEqual(result, "first")
    }

    // MARK: - resolveNamespace Tests

    func testResolveNamespaceReturnsNilWhenNoAvailableNamespaces() {
        let result = sut.resolveNamespace(availableNamespaces: [], index: "index", currentSelection: "test")
        XCTAssertNil(result)
    }

    func testResolveNamespaceReturnsPreferredWhenEnforcedAndAvailable() {
        defaults.set(true, forKey: SettingsStorageKeys.searchEnforcePreferredIndex)
        defaults.set("preferred_ns", forKey: SettingsStorageKeys.searchPreferredNamespace)

        let result = sut.resolveNamespace(availableNamespaces: ["other", "preferred_ns"], index: "index", currentSelection: "other")

        XCTAssertEqual(result, "preferred_ns")
    }

    func testResolveNamespaceReturnsCurrentWhenNotEnforced() {
        defaults.set(false, forKey: SettingsStorageKeys.searchEnforcePreferredIndex)
        defaults.set("preferred_ns", forKey: SettingsStorageKeys.searchPreferredNamespace)

        let result = sut.resolveNamespace(availableNamespaces: ["other", "current", "preferred_ns"], index: "index", currentSelection: "current")

        XCTAssertEqual(result, "current")
    }

    func testResolveNamespaceReturnsStoredWhenCurrentNotAvailable() {
        sut.recordNamespace("stored", for: "index")

        let result = sut.resolveNamespace(availableNamespaces: ["other", "stored"], index: "index", currentSelection: "current")

        XCTAssertEqual(result, "stored")
    }

    func testResolveNamespaceReturnsPreferredWhenStoredNotAvailable() {
        sut.recordNamespace("stored", for: "index")
        defaults.set("preferred_ns", forKey: SettingsStorageKeys.searchPreferredNamespace)

        let result = sut.resolveNamespace(availableNamespaces: ["other", "preferred_ns"], index: "index", currentSelection: "current")

        XCTAssertEqual(result, "preferred_ns")
    }

    func testResolveNamespaceReturnsFirstWhenNoPreferencesAvailable() {
        sut.recordNamespace("stored", for: "index")
        defaults.set("preferred_ns", forKey: SettingsStorageKeys.searchPreferredNamespace)

        let result = sut.resolveNamespace(availableNamespaces: ["first", "second"], index: "index", currentSelection: "current")

        XCTAssertEqual(result, "first")
    }

    func testResolveNamespaceHandlesEmptyStringAsValidNamespace() {
        sut.recordNamespace("", for: "index")

        let result = sut.resolveNamespace(availableNamespaces: ["", "other"], index: "index", currentSelection: "current")

        XCTAssertEqual(result, "")
    }

    func testResolveNamespaceNormalizesStrings() {
        sut.recordNamespace("  stored_ns  ", for: "index")
        defaults.set("  preferred_ns  ", forKey: SettingsStorageKeys.searchPreferredNamespace)

        // Stored has priority over preferred when not enforced, if current is unavailable
        let result = sut.resolveNamespace(availableNamespaces: ["stored_ns", "preferred_ns"], index: "index", currentSelection: "  ")

        XCTAssertEqual(result, "stored_ns")
    }

    // MARK: - State Management Tests

    func testRecordAndStoredNamespace() {
        sut.recordNamespace("my_ns", for: "my_index")

        XCTAssertEqual(sut.storedNamespace(for: "my_index"), "my_ns")
        XCTAssertNil(sut.storedNamespace(for: "other_index"))
    }

    func testClearNamespace() {
        sut.recordNamespace("my_ns", for: "my_index")
        sut.clearNamespace(for: "my_index")

        XCTAssertNil(sut.storedNamespace(for: "my_index"))
    }

    func testRecordLastIndex() {
        sut.recordLastIndex("new_index")

        XCTAssertEqual(defaults.string(forKey: "oc.lastIndex"), "new_index")
    }

    func testPreferredNamespaceReturnsNormalizedValue() {
        defaults.set("  pref_ns  ", forKey: SettingsStorageKeys.searchPreferredNamespace)
        XCTAssertEqual(sut.preferredNamespace(), "pref_ns")
    }
}
