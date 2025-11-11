import Foundation

/// Resolves the Pinecone index and namespace selection based on persisted preferences.
struct PineconePreferenceResolver {
    private let defaults: UserDefaults
    private let preferredIndexKey = SettingsStorageKeys.searchPreferredIndex
    private let preferredNamespaceKey = SettingsStorageKeys.searchPreferredNamespace
    private let enforcePreferredKey = SettingsStorageKeys.searchEnforcePreferredIndex
    private let lastIndexKey = "oc.lastIndex"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Returns a storage key for the last namespace used with the provided index name.
    private func namespaceStorageKey(for index: String) -> String {
        "oc.lastNamespace.\(index)"
    }

    /// Normalizes index strings for comparison by trimming whitespace and ignoring empties.
    private func normalizedIndex(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    /// Normalizes namespace strings while preserving the ability to persist the default namespace (empty string).
    private func normalizedNamespace(_ value: String?) -> String? {
        guard let raw = value else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
    }

    /// Determines which index should be selected from the available list.
    /// - Parameters:
    ///   - availableIndexes: Index names returned by Pinecone.
    ///   - currentSelection: The index currently selected in the UI, if any.
    /// - Returns: The index name that should be active, or `nil` if no indexes exist.
    func resolveIndex(availableIndexes: [String], currentSelection: String?) -> String? {
        guard !availableIndexes.isEmpty else { return nil }

        let enforcePreferred = defaults.bool(forKey: enforcePreferredKey)
        let preferred = normalizedIndex(defaults.string(forKey: preferredIndexKey))
        let last = normalizedIndex(defaults.string(forKey: lastIndexKey))
        let current = normalizedIndex(currentSelection)

        if enforcePreferred, let preferred, availableIndexes.contains(preferred) {
            return preferred
        }

        if let last, availableIndexes.contains(last) {
            return last
        }

        if let current, availableIndexes.contains(current) {
            return current
        }

        if let preferred, availableIndexes.contains(preferred) {
            return preferred
        }

        return availableIndexes.first
    }

    /// Resolves the namespace that should be selected for the supplied index.
    /// - Parameters:
    ///   - availableNamespaces: Namespace names returned by Pinecone for the index.
    ///   - index: The index currently selected.
    ///   - currentSelection: The namespace currently selected in the UI, if any.
    /// - Returns: The namespace to activate, or `nil` if none exist.
    func resolveNamespace(availableNamespaces: [String], index: String?, currentSelection: String?) -> String? {
        guard !availableNamespaces.isEmpty else { return nil }

        let enforcePreferred = defaults.bool(forKey: enforcePreferredKey)
        let preferred = normalizedNamespace(defaults.string(forKey: preferredNamespaceKey))
        let stored = normalizedNamespace(index.flatMap { defaults.string(forKey: namespaceStorageKey(for: $0)) })
        let current = normalizedNamespace(currentSelection)

        if enforcePreferred, let preferred, availableNamespaces.contains(preferred) {
            return preferred
        }

        if let stored, availableNamespaces.contains(stored) {
            return stored
        }

        if let preferred, availableNamespaces.contains(preferred) {
            return preferred
        }

        if let current, availableNamespaces.contains(current) {
            return current
        }

        return availableNamespaces.first
    }

    /// Persists the most recently used index name.
    func recordLastIndex(_ index: String) {
        guard let normalized = normalizedIndex(index) else { return }
        defaults.set(normalized, forKey: lastIndexKey)
    }

    /// Persists the most recently used namespace for the supplied index.
    func recordNamespace(_ namespace: String, for index: String) {
        guard let normalizedIndex = normalizedIndex(index) else { return }
        let key = namespaceStorageKey(for: normalizedIndex)
        defaults.set(normalizedNamespace(namespace) ?? "", forKey: key)
    }

    /// Removes any stored namespace preference for the provided index.
    func clearNamespace(for index: String) {
        guard let normalizedIndex = normalizedIndex(index) else { return }
        defaults.removeObject(forKey: namespaceStorageKey(for: normalizedIndex))
    }
}
