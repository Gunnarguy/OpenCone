import XCTest
@testable import OpenCone

final class SecureSettingsStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear out any existing Keychain / UserDefaults values for keys under test
        let store = SecureSettingsStore.shared
        store.clearSecretsAndPreferences()
        
        UserDefaults.standard.removeObject(forKey: "openAIAPIKey")
        UserDefaults.standard.removeObject(forKey: "pineconeAPIKey")
        UserDefaults.standard.removeObject(forKey: "pineconeProjectId")
    }

    override func tearDown() {
        let store = SecureSettingsStore.shared
        store.clearSecretsAndPreferences()
        
        UserDefaults.standard.removeObject(forKey: "openAIAPIKey")
        UserDefaults.standard.removeObject(forKey: "pineconeAPIKey")
        UserDefaults.standard.removeObject(forKey: "pineconeProjectId")
        super.tearDown()
    }

    func testLegacyMigration_success() async {
        let defaults = UserDefaults.standard
        let store = SecureSettingsStore.shared
        
        // 1. Seed legacy UserDefaults values
        defaults.set("sk-legacy-openai-key", forKey: "openAIAPIKey")
        defaults.set("pcsk-legacy-pinecone-key", forKey: "pineconeAPIKey")
        defaults.set("legacy-project-id", forKey: "pineconeProjectId")
        
        // 2. Perform migration
        await store.migrateLegacyUserDefaultsSecrets()
        
        // 3. Verify they were saved to the Keychain
        XCTAssertEqual(store.getOpenAIKey(), "sk-legacy-openai-key")
        XCTAssertEqual(store.getPineconeAPIKey(), "pcsk-legacy-pinecone-key")
        XCTAssertEqual(store.getPineconeProjectId(), "legacy-project-id")
        
        // 4. Verify they were cleared from UserDefaults
        XCTAssertNil(defaults.string(forKey: "openAIAPIKey"))
        XCTAssertNil(defaults.string(forKey: "pineconeAPIKey"))
        XCTAssertNil(defaults.string(forKey: "pineconeProjectId"))
    }

    func testKeychainSaveAndUpdate() {
        let store = SecureSettingsStore.shared
        
        // 1. Initial save
        let initialSaved = store.setOpenAIKey("sk-first-key")
        XCTAssertTrue(initialSaved)
        XCTAssertEqual(store.getOpenAIKey(), "sk-first-key")
        
        // 2. Update existing entry (test SecItemUpdate)
        let updatedSaved = store.setOpenAIKey("sk-second-key")
        XCTAssertTrue(updatedSaved)
        XCTAssertEqual(store.getOpenAIKey(), "sk-second-key")
    }
}
