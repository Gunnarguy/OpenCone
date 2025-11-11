import Foundation

struct SettingsMetadataPreset: Identifiable, Codable, Equatable {
    var id: UUID
    var field: String
    var rawValue: String

    init(id: UUID = UUID(), field: String, rawValue: String) {
        self.id = id
        self.field = field
        self.rawValue = rawValue
    }

    var isValid: Bool {
        let trimmedField = field.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedField.isEmpty && !trimmedValue.isEmpty
    }

    func trimmed() -> SettingsMetadataPreset {
        SettingsMetadataPreset(
            id: id,
            field: field.trimmingCharacters(in: .whitespacesAndNewlines),
            rawValue: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

enum SettingsStorageKeys {
    static let searchPreferredIndex = "settings.preferredIndex"
    static let searchPreferredNamespace = "settings.preferredNamespace"
    static let searchEnforcePreferredIndex = "settings.enforcePreferredIndex"
    static let searchTopK = "search.topK"
    static let searchMetadataPresets = "search.metadataPresets"
    static let logMinimumLevel = "log.minimumLevel"
}
