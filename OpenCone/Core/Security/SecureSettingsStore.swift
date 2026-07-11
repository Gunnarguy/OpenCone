import Foundation
import Security

/// SecureSettingsStore centralizes secure storage for API credentials using the Keychain,
/// and persists non-secret preferences (like region/cloud) in UserDefaults.
/// This provides a single, typed interface for the app to access secrets and settings.
final class SecureSettingsStore: @unchecked Sendable { 
    static let shared = SecureSettingsStore()
    private init() {
        Task { @MainActor in
            self.migrateLegacyUserDefaultsSecrets()
        }
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
        return UserDefaults.standard.string(forKey: Key.pineconeNamespaceVersion) ?? "2025-10"
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

    /// Removes all secrets from the Keychain and clears persisted Pinecone configuration preferences.
    /// Intended for "Reset App" style flows so users can revoke access to stored credentials without
    /// uninstalling the application.
    func clearSecretsAndPreferences() {
        deleteKeychainValue(forKey: Key.openAIKey)
        deleteKeychainValue(forKey: Key.pineconeKey)
        deleteKeychainValue(forKey: Key.pineconeProjectId)

        let defaults = UserDefaults.standard
        let nonSecretKeys = [
            Key.pineconeCloud,
            Key.pineconeRegion,
            Key.pineconeControlPlaneVersion,
            Key.pineconeDataPlaneVersion,
            Key.pineconeNamespaceVersion,
            Key.pineconeMetadataFetchVersion,
        ]

        nonSecretKeys.forEach { defaults.removeObject(forKey: $0) }
    }

    // MARK: - Keychain helpers

    // MARK: - Legacy Migration

    @MainActor
    func migrateLegacyUserDefaultsSecrets() {
        let defaults = UserDefaults.standard
        let logger = Logger.shared
        
        let keysToMigrate = [
            (legacyKey: "openAIAPIKey", keychainKey: Key.openAIKey),
            (legacyKey: "pineconeAPIKey", keychainKey: Key.pineconeKey),
            (legacyKey: "pineconeProjectId", keychainKey: Key.pineconeProjectId)
        ]
        
        for (legacyKey, keychainKey) in keysToMigrate {
            guard let legacyValue = defaults.string(forKey: legacyKey), !legacyValue.isEmpty else {
                continue
            }
            
            do {
                try saveKeychainString(legacyValue, forKey: keychainKey, accessibility: kSecAttrAccessibleWhenUnlocked)
                
                // Read it back to verify success
                if let verifiedValue = loadKeychainString(forKey: keychainKey), verifiedValue == legacyValue {
                    defaults.removeObject(forKey: legacyKey)
                    logger.log(level: .info, message: "Successfully migrated secret '\(legacyKey)' to Keychain and verified read-back.")
                } else {
                    logger.log(level: .error, message: "Failed to verify Keychain read-back for '\(legacyKey)'. Will retry next time.")
                }
            } catch {
                logger.log(level: .error, message: "Failed to migrate '\(legacyKey)' to Keychain: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Keychain helpers

    private let serviceIdentifier = "com.opencone.securestore"

    private func saveKeychainString(_ value: String, forKey key: String, accessibility: CFString = kSecAttrAccessibleWhenUnlocked) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.dataEncodingFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]

        // Check if item already exists
        let statusCheck = SecItemCopyMatching(query as CFDictionary, nil)

        if statusCheck == errSecSuccess {
            // Item exists, update it
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data,
                kSecAttrAccessible as String: accessibility
            ]
            let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            if status != errSecSuccess {
                throw KeychainError.unhandledStatus(status)
            }
        } else if statusCheck == errSecItemNotFound {
            // Item does not exist, add it
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = accessibility

            let status = SecItemAdd(attributes as CFDictionary, nil)
            if status != errSecSuccess {
                throw KeychainError.unhandledStatus(status)
            }
        } else {
            throw KeychainError.unhandledStatus(statusCheck)
        }
    }

    @discardableResult
    private func saveKeychainString(_ value: String, forKey key: String) -> Bool {
        do {
            try saveKeychainString(value, forKey: key, accessibility: kSecAttrAccessibleWhenUnlocked)
            return true
        } catch {
            Task { @MainActor in
                Logger.shared.log(level: .error, message: "Keychain save error: \(error.localizedDescription)")
            }
            return false
        }
    }

    private func loadKeychainString(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
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
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

// MARK: - Keychain Errors

enum KeychainError: Error, LocalizedError {
    case dataEncodingFailed
    case itemNotFound
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .dataEncodingFailed:
            return "Failed to encode or decode Keychain data."
        case .itemNotFound:
            return "The requested item was not found in the Keychain."
        case .unhandledStatus(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return "Keychain error: \(message) (code \(status))"
            }
            return "Unhandled Keychain status: \(status)"
        }
    }
}
