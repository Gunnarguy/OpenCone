import Foundation
import Security

/// SecureSettingsStore centralizes secure storage for API credentials using the Keychain,
/// and persists non-secret preferences (like region/cloud) in UserDefaults.
/// This provides a single, typed interface for the app to access secrets and settings.
final class SecureSettingsStore {
    static let shared = SecureSettingsStore()
    private init() {
        // One-time migrations from UserDefaults (legacy) to Keychain-backed storage
        migrateLegacyUserDefaultsSecrets()
    }

    // MARK: - Keys

    private enum Key {
        // Secrets in Keychain
        static let openAIKey = "oc_openai_api_key"
        static let pineconeKey = "oc_pinecone_api_key"
        static let pineconeProjectId = "oc_pinecone_project_id"

        // Non-secrets in UserDefaults
        static let pineconeCloud = "oc_pinecone_cloud"     // e.g., "aws", "gcp", "azure"
        static let pineconeRegion = "oc_pinecone_region"   // e.g., "us-east-1"
        static let pineconeControlPlaneVersion = "oc_pinecone_control_plane_version"
        static let pineconeDataPlaneVersion = "oc_pinecone_data_plane_version"
        static let pineconeNamespaceVersion = "oc_pinecone_namespace_version"
        static let pineconeMetadataFetchVersion = "oc_pinecone_metadata_fetch_version"
    }

    // MARK: - Public API (Secrets)

    func getOpenAIKey() -> String {
        return loadKeychainString(forKey: Key.openAIKey) ?? ""
    }

    @discardableResult
    func setOpenAIKey(_ value: String) -> Bool {
        return saveKeychainString(value, forKey: Key.openAIKey)
    }

    func getPineconeAPIKey() -> String {
        return loadKeychainString(forKey: Key.pineconeKey) ?? ""
    }

    @discardableResult
    func setPineconeAPIKey(_ value: String) -> Bool {
        return saveKeychainString(value, forKey: Key.pineconeKey)
    }

    func getPineconeProjectId() -> String {
        return loadKeychainString(forKey: Key.pineconeProjectId) ?? ""
    }

    @discardableResult
    func setPineconeProjectId(_ value: String) -> Bool {
        return saveKeychainString(value, forKey: Key.pineconeProjectId)
    }

    // MARK: - Public API (Non-secrets)

    func getPineconeCloud() -> String {
        // Default to AWS unless user overrides in Settings
        return UserDefaults.standard.string(forKey: Key.pineconeCloud) ?? "aws"
    }

    func setPineconeCloud(_ cloud: String) {
        UserDefaults.standard.set(cloud, forKey: Key.pineconeCloud)
    }

    func getPineconeRegion() -> String {
        // Default to us-east-1 unless user overrides in Settings
        return UserDefaults.standard.string(forKey: Key.pineconeRegion) ?? "us-east-1"
    }

    func setPineconeRegion(_ region: String) {
        UserDefaults.standard.set(region, forKey: Key.pineconeRegion)
    }

    func getPineconeControlPlaneVersion() -> String {
        return UserDefaults.standard.string(forKey: Key.pineconeControlPlaneVersion) ?? "2024-07"
    }

    func setPineconeControlPlaneVersion(_ version: String) {
        UserDefaults.standard.set(version, forKey: Key.pineconeControlPlaneVersion)
    }

    func getPineconeDataPlaneVersion() -> String {
        return UserDefaults.standard.string(forKey: Key.pineconeDataPlaneVersion) ?? "2024-07"
    }

    func setPineconeDataPlaneVersion(_ version: String) {
        UserDefaults.standard.set(version, forKey: Key.pineconeDataPlaneVersion)
    }

    func getPineconeNamespaceVersion() -> String {
        return UserDefaults.standard.string(forKey: Key.pineconeNamespaceVersion) ?? "2025-04"
    }

    func setPineconeNamespaceVersion(_ version: String) {
        UserDefaults.standard.set(version, forKey: Key.pineconeNamespaceVersion)
    }

    func getPineconeMetadataFetchVersion() -> String {
        return UserDefaults.standard.string(forKey: Key.pineconeMetadataFetchVersion) ?? "2025-10"
    }

    func setPineconeMetadataFetchVersion(_ version: String) {
        UserDefaults.standard.set(version, forKey: Key.pineconeMetadataFetchVersion)
    }

    // MARK: - Migration from legacy UserDefaults keys

    private func migrateLegacyUserDefaultsSecrets() {
        // Legacy UserDefaults keys used by SettingsViewModel
        let legacyOpenAI = UserDefaults.standard.string(forKey: "openAIAPIKey")
        let legacyPineconeKey = UserDefaults.standard.string(forKey: "pineconeAPIKey")
        let legacyProjectId = UserDefaults.standard.string(forKey: "pineconeProjectId")

        if let legacyOpenAI, !legacyOpenAI.isEmpty, loadKeychainString(forKey: Key.openAIKey) == nil {
            _ = saveKeychainString(legacyOpenAI, forKey: Key.openAIKey)
            UserDefaults.standard.removeObject(forKey: "openAIAPIKey")
        }

        if let legacyPineconeKey, !legacyPineconeKey.isEmpty, loadKeychainString(forKey: Key.pineconeKey) == nil {
            _ = saveKeychainString(legacyPineconeKey, forKey: Key.pineconeKey)
            UserDefaults.standard.removeObject(forKey: "pineconeAPIKey")
        }

        if let legacyProjectId, !legacyProjectId.isEmpty, loadKeychainString(forKey: Key.pineconeProjectId) == nil {
            _ = saveKeychainString(legacyProjectId, forKey: Key.pineconeProjectId)
            UserDefaults.standard.removeObject(forKey: "pineconeProjectId")
        }
    }

    // MARK: - Keychain helpers

    @discardableResult
    private func saveKeychainString(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        // Remove any existing item
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Add new item
        var addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // Improve accessibility as needed (default generic)
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func loadKeychainString(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataRef)
        guard status == errSecSuccess, let data = dataRef as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    private func deleteKeychainValue(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}
