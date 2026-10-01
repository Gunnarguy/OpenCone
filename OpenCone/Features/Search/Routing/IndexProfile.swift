import CryptoKit
import Foundation

/// What OpenCone knows about one of the person's indexes. Kept on the phone so a routed question
/// can describe every index to the model without a round of Pinecone calls first.
struct IndexProfile: Codable, Equatable, Identifiable {
    struct Namespace: Codable, Equatable {
        let name: String
        let vectorCount: Int
    }

    /// Outcome of re-embedding a stored passage to learn which model built the index
    enum ModelCheck: String, Codable {
        /// A model reproduced the stored vector
        case matched
        /// No OpenAI embedding model reproduced it, so a question can't be embedded to match
        case noMatch
        /// No passage with both text and a vector came back to check against
        case noPassage
        case notChecked
    }

    /// Who wrote the one-line summary the router shows the model. `missing` rather than `none`,
    /// so an optional of this type can't confuse the case with nil.
    enum SummarySource: String, Codable {
        case person
        case drafted
        case missing
    }

    let name: String
    var dimension: Int
    var metric: String
    var namespaces: [Namespace]
    var embeddingModel: String?
    var modelCheck: ModelCheck
    /// Cosine between the stored vector and the best candidate's, kept so a device run shows real values
    var modelSimilarity: Double?
    var summary: String
    var summarySource: SummarySource
    var surveyedAt: Date
    /// The index's host when surveyed. A deleted and recreated index gets a new host, so a model
    /// match is only trusted while the host is the same.
    var host: String? = nil

    var id: String { name }

    var vectorCount: Int {
        namespaces.reduce(0) { $0 + $1.vectorCount }
    }

    /// Searchable when the model that built it is known and it holds passages
    var isRoutable: Bool {
        modelCheck == .matched && embeddingModel != nil && vectorCount > 0
    }

    /// Namespace names as the router offers them, largest first; "" is the default namespace
    var namespaceNames: [String] {
        namespaces.map(\.name)
    }

    func hasNamespace(_ name: String) -> Bool {
        namespaces.contains { $0.name == name }
    }
}

/// Index profiles in UserDefaults, one set per Pinecone project so two accounts never mix.
/// The project ID is hashed into the key because the app keeps the ID itself in the Keychain.
@MainActor
final class IndexCatalogStore {
    nonisolated static let keyPrefix = "routing.indexProfiles."

    private let defaults: UserDefaults
    private let key: String

    init(projectId: String, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let digest = SHA256.hash(data: Data(projectId.utf8))
            .prefix(8)
            .map { String(format: "%02x", $0) }
            .joined()
        self.key = "\(Self.keyPrefix)\(digest)"
    }

    /// Remove every project's profiles, for the reset in Settings: they hold index and namespace
    /// names and summaries drafted from passages
    nonisolated static func removeAllProjects(from defaults: UserDefaults = .standard) {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(keyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    func load() -> [String: IndexProfile] {
        guard let data = defaults.data(forKey: key),
              let profiles = try? JSONDecoder().decode([String: IndexProfile].self, from: data)
        else {
            return [:]
        }
        return profiles
    }

    func save(_ profiles: [String: IndexProfile]) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: key)
    }

    /// Indexes the person left out of searches across indexes. Under the same prefix, so the
    /// reset in Settings clears them with the profiles.
    func loadExcluded() -> Set<String> {
        Set(defaults.stringArray(forKey: excludedKey) ?? [])
    }

    func saveExcluded(_ names: Set<String>) {
        if names.isEmpty {
            defaults.removeObject(forKey: excludedKey)
        } else {
            defaults.set(names.sorted(), forKey: excludedKey)
        }
    }

    private var excludedKey: String { "\(key).excluded" }

    func removeAll() {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: excludedKey)
    }
}

/// Finds which OpenAI model built an index by re-embedding one of its stored passages.
/// Pinecone records a model only for integrated-embedding indexes, and a dimension can't tell the
/// models apart: text-embedding-3-small defaults to 1536 and text-embedding-3-large to 3072, both
/// shorten with `dimensions`, and ada-002 is fixed at 1536
/// (developers.openai.com/api/docs/guides/embeddings, read 2026-10-01).
enum EmbeddingModelMatcher {
    /// The same text through the same model gives a cosine close to 1. Vectors from two different
    /// models share no coordinate system, so their cosine carries no meaning. A stored text that
    /// isn't exactly what was embedded (a tool that prepended metadata) scores lower than 1 but
    /// stays well clear of this line.
    static let matchThreshold = 0.6

    /// OpenAI models that can produce vectors of this size, the preferred one first
    static func candidates(forDimension dimension: Int, preferred: String?) -> [String] {
        guard dimension > 0 else { return [] }
        var models: [String] = []
        if dimension <= 1536 {
            models.append("text-embedding-3-small")
        }
        if dimension <= 3072 {
            models.append("text-embedding-3-large")
        }
        if dimension == 1536 {
            models.append("text-embedding-ada-002")
        }
        if let preferred, let position = models.firstIndex(of: preferred), position > 0 {
            models.remove(at: position)
            models.insert(preferred, at: 0)
        }
        return models
    }

    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double? {
        guard a.count == b.count, !a.isEmpty else { return nil }
        var dot = 0.0
        var normA = 0.0
        var normB = 0.0
        for i in 0..<a.count {
            let x = Double(a[i])
            let y = Double(b[i])
            dot += x * y
            normA += x * x
            normB += y * y
        }
        guard normA > 0, normB > 0 else { return nil }
        return dot / (normA.squareRoot() * normB.squareRoot())
    }
}
