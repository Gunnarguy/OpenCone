import XCTest
@testable import OpenCone

final class PineconePreferenceResolverTests: XCTestCase {
    private var defaults: UserDefaults!
    private var sut: PineconePreferenceResolver!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "PineconePreferenceResolverTests")
        defaults.removePersistentDomain(forName: "PineconePreferenceResolverTests")
        sut = PineconePreferenceResolver(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "PineconePreferenceResolverTests")
        super.tearDown()
    }

    func testResolveNamespace_WithEmptyAvailableNamespaces_ReturnsNil() {
        let result = sut.resolveNamespace(
            availableNamespaces: [],
            index: "test-index",
            currentSelection: "some-namespace"
        )
        XCTAssertNil(result)
    }

    func testResolveNamespace_EnforcePreferredNamespace_Available() {
        defaults.set(true, forKey: SettingsStorageKeys.searchEnforcePreferredIndex)
        defaults.set("preferred", forKey: SettingsStorageKeys.searchPreferredNamespace)

        let result = sut.resolveNamespace(
            availableNamespaces: ["other", "preferred", "another"],
            index: "test-index",
            currentSelection: "other"
        )

        XCTAssertEqual(result, "preferred")
    }

    func testResolveNamespace_EnforcePreferredNamespace_NotAvailable() {
        defaults.set(true, forKey: SettingsStorageKeys.searchEnforcePreferredIndex)
        defaults.set("preferred", forKey: SettingsStorageKeys.searchPreferredNamespace)

        // It should fallback to current, stored, etc.
        // Here, current is "other" which is in availableNamespaces.
        let result = sut.resolveNamespace(
            availableNamespaces: ["other", "another"],
            index: "test-index",
            currentSelection: "other"
        )

        XCTAssertEqual(result, "other")
    }

    func testResolveNamespace_CurrentSelectionValid() {
        // preferred is set, but not enforced
        defaults.set(false, forKey: SettingsStorageKeys.searchEnforcePreferredIndex)
        defaults.set("preferred", forKey: SettingsStorageKeys.searchPreferredNamespace)

        let result = sut.resolveNamespace(
            availableNamespaces: ["other", "current-ns", "preferred"],
            index: "test-index",
            currentSelection: "current-ns"
        )

        XCTAssertEqual(result, "current-ns")
    }

    func testResolveNamespace_StoredNamespaceValid() {
        // No current selection, but there is a stored selection for this index
        defaults.set(false, forKey: SettingsStorageKeys.searchEnforcePreferredIndex)
        defaults.set("preferred", forKey: SettingsStorageKeys.searchPreferredNamespace)

        sut.recordNamespace("stored-ns", for: "test-index")

        let result = sut.resolveNamespace(
            availableNamespaces: ["other", "stored-ns", "preferred"],
            index: "test-index",
            currentSelection: nil
        )

        XCTAssertEqual(result, "stored-ns")
    }

    func testResolveNamespace_FallbackToPreferred() {
        // No current selection, no stored selection
        defaults.set(false, forKey: SettingsStorageKeys.searchEnforcePreferredIndex)
        defaults.set("preferred", forKey: SettingsStorageKeys.searchPreferredNamespace)

        let result = sut.resolveNamespace(
            availableNamespaces: ["other", "preferred"],
            index: "test-index",
            currentSelection: nil
        )

        XCTAssertEqual(result, "preferred")
    }

    func testResolveNamespace_FallbackToFirstAvailable() {
        // No current, no stored, no preferred
        let result = sut.resolveNamespace(
            availableNamespaces: ["first-ns", "second-ns"],
            index: "test-index",
            currentSelection: nil
        )

        XCTAssertEqual(result, "first-ns")
    }
}
