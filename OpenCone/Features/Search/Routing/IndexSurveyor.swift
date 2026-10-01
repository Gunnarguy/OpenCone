import Foundation

/// Builds an `IndexProfile`: the index's size and namespaces, which OpenAI model built it, and a
/// one-line summary the router shows the model. Runs once per index, and again when it goes stale.
@MainActor
final class IndexSurveyor {
    /// A passage read back from an index, with its stored vector when one came back
    struct SampledPassage {
        let namespace: String
        let text: String
        let values: [Float]?
    }

    /// Namespaces sampled per index, largest first
    static let namespacesSampled = 3
    static let passagesPerNamespace = 4
    /// Passages shown to the model when it drafts a summary
    static let passagesForSummary = 8

    static let summaryInstructions = """
    You label a vector index so an assistant can decide which index to search. Reply with one \
    sentence of at most 30 words saying what the passages are about: the subject, the kinds of \
    documents, and any names, products, places or periods they cover. Reply with the sentence only.
    """

    private var logger: Logger { Logger.shared }
    private let pinecone: PineconeService
    private let embeddings: EmbeddingService
    private let responses: ResponsesClient

    init(pinecone: PineconeService, embeddings: EmbeddingService, responses: ResponsesClient) {
        self.pinecone = pinecone
        self.embeddings = embeddings
        self.responses = responses
    }

    /// Survey one index.
    /// - Parameters:
    ///   - name: The index
    ///   - previous: The stored profile, whose model match and person-written summary are kept
    ///   - preferredModel: The embedding model in Settings, tried first
    ///   - summaryOptions: Model settings for drafting a summary; nil skips drafting
    ///   - recheckModel: Check the model again even when an earlier check matched
    func survey(
        index name: String,
        previous: IndexProfile?,
        preferredModel: String,
        summaryOptions: ResponsesClient.ModelOptions?,
        recheckModel: Bool = false
    ) async throws -> IndexProfile {
        let described = try await pinecone.describeIndex(name: name)
        let stats = try await pinecone.indexStats(forIndex: name, forceRefresh: true)

        let namespaces = stats.namespaces
            .map { IndexProfile.Namespace(name: $0.key, vectorCount: $0.value.vectorCount) }
            .sorted { lhs, rhs in
                lhs.vectorCount == rhs.vectorCount ? lhs.name < rhs.name : lhs.vectorCount > rhs.vectorCount
            }

        var profile = IndexProfile(
            name: name,
            dimension: described.dimension,
            metric: described.metric,
            namespaces: namespaces,
            embeddingModel: nil,
            modelCheck: .notChecked,
            modelSimilarity: nil,
            summary: previous?.summary ?? "",
            summarySource: previous?.summarySource ?? .missing,
            surveyedAt: Date(),
            host: described.host
        )

        // An index doesn't change models under it, so a match stays valid while its size and host
        // hold; a deleted and recreated index comes back with a new host
        let keepsEarlierMatch = !recheckModel
            && previous?.modelCheck == .matched
            && previous?.dimension == described.dimension
            && previous?.host == described.host
            && previous?.embeddingModel != nil
        let needsSummary = summaryOptions != nil && profile.summarySource != .person && profile.summary.isEmpty

        if keepsEarlierMatch, let previous {
            profile.embeddingModel = previous.embeddingModel
            profile.modelCheck = .matched
            profile.modelSimilarity = previous.modelSimilarity
            if !needsSummary {
                return profile
            }
        }

        let samples: [SampledPassage]
        do {
            samples = try await samplePassages(index: name, dimension: described.dimension, namespaces: namespaces)
        } catch {
            // With an earlier match only the summary waits; without one the model can't be checked
            if keepsEarlierMatch {
                return profile
            }
            throw error
        }

        if !keepsEarlierMatch {
            try await checkModel(of: &profile, samples: samples, preferredModel: preferredModel)
        }

        if needsSummary, let summaryOptions, !samples.isEmpty {
            do {
                profile.summary = try await draftSummary(for: profile, samples: samples, options: summaryOptions)
                profile.summarySource = .drafted
            } catch {
                logger.log(level: .warning, message: "Index summary draft failed", context: "index=\(name); \(error.localizedDescription)")
            }
        }

        return profile
    }

    /// Draft the summary again, replacing a drafted one; a person-written summary is kept
    func redraftSummary(of profile: IndexProfile, options: ResponsesClient.ModelOptions) async throws -> IndexProfile {
        var updated = profile
        let samples = try await samplePassages(index: profile.name, dimension: profile.dimension, namespaces: profile.namespaces)
        guard !samples.isEmpty else { return updated }
        updated.summary = try await draftSummary(for: profile, samples: samples, options: options)
        updated.summarySource = .drafted
        return updated
    }

    // MARK: - Steps

    /// A few passages from the largest namespaces. A random query vector returns arbitrary
    /// neighbours, which is what a sample needs; nothing has to be listed or fetched first.
    /// Throws when every sample query failed, so an outage is never read as an empty index.
    func samplePassages(index name: String, dimension: Int, namespaces: [IndexProfile.Namespace]) async throws -> [SampledPassage] {
        guard dimension > 0 else { return [] }
        var samples: [SampledPassage] = []
        var attempts = 0
        var failures: [Error] = []

        for namespace in namespaces.filter({ $0.vectorCount > 0 }).prefix(Self.namespacesSampled) {
            attempts += 1
            do {
                let response = try await pinecone.query(
                    index: name,
                    vector: Self.randomUnitVector(dimension: dimension),
                    topK: Self.passagesPerNamespace,
                    // The default namespace is sent by leaving the field out
                    namespace: namespace.name.isEmpty ? nil : namespace.name,
                    includeValues: true
                )
                for match in response.matches {
                    guard let text = PassageText.text(from: match.metadata), !text.isEmpty else { continue }
                    samples.append(SampledPassage(namespace: namespace.name, text: text, values: match.values))
                }
            } catch {
                failures.append(error)
                logger.log(level: .warning, message: "Index sample failed", context: "index=\(name); namespace=\(namespace.name); \(error.localizedDescription)")
            }
        }

        if attempts > 0, failures.count == attempts, let failure = failures.last {
            throw failure
        }
        return samples
    }

    /// Re-embed the shortest stored passage with each model that fits the index's dimension and
    /// keep the one whose vector matches the stored one. Throws when a call failed for a reason
    /// that may pass (network, 429, 5xx) and nothing matched: a model that couldn't be asked is not
    /// a model that doesn't match, so the caller keeps what it had and tries again later.
    func checkModel(of profile: inout IndexProfile, samples: [SampledPassage], preferredModel: String) async throws {
        let probe = samples
            .filter { $0.values?.count == profile.dimension && $0.text.count >= 20 }
            .min { $0.text.count < $1.text.count }

        guard let probe, let stored = probe.values else {
            profile.modelCheck = .noPassage
            return
        }

        var best: Double?
        var passingFailure: Error?
        for model in EmbeddingModelMatcher.candidates(forDimension: profile.dimension, preferred: preferredModel) {
            do {
                let vector = try await embeddings.generateQueryEmbedding(for: probe.text, dimension: profile.dimension, model: model)
                guard let similarity = EmbeddingModelMatcher.cosineSimilarity(vector, stored) else { continue }
                logger.log(level: .info, message: "Index model check", context: "index=\(profile.name); model=\(model); cosine=\(String(format: "%.4f", similarity))")
                if similarity >= EmbeddingModelMatcher.matchThreshold {
                    profile.embeddingModel = model
                    profile.modelCheck = .matched
                    profile.modelSimilarity = similarity
                    return
                }
                best = max(best ?? similarity, similarity)
            } catch {
                if Self.mayPass(error) {
                    passingFailure = error
                }
                logger.log(level: .warning, message: "Index model check call failed", context: "index=\(profile.name); model=\(model); \(error.localizedDescription)")
            }
        }

        if let passingFailure {
            throw passingFailure
        }
        profile.modelCheck = .noMatch
        profile.modelSimilarity = best
    }

    /// Network failures, rate limits and server errors may pass; a 4xx such as a model the key
    /// can't use won't, so that candidate counts as checked
    static func mayPass(_ error: Error) -> Bool {
        if let apiError = error as? APIError, case let .requestFailed(statusCode, _) = apiError {
            return statusCode == 0 || statusCode == 429 || statusCode >= 500
        }
        return true
    }

    func draftSummary(for profile: IndexProfile, samples: [SampledPassage], options: ResponsesClient.ModelOptions) async throws -> String {
        let namespaceLine = profile.namespaces.prefix(12).map { namespace in
            let name = namespace.name.isEmpty ? "default" : namespace.name
            return "\(name) (\(namespace.vectorCount) passages)"
        }
        .joined(separator: ", ")

        let passages = samples.prefix(Self.passagesForSummary).enumerated().map { offset, sample in
            let namespace = sample.namespace.isEmpty ? "default" : sample.namespace
            return "\(offset + 1). [\(namespace)] \(String(sample.text.prefix(500)))"
        }
        .joined(separator: "\n\n")

        let prompt = """
        Index: \(profile.name)
        Namespaces: \(namespaceLine)

        Sample passages:
        \(passages)
        """

        let reply = try await responses.create(
            instructions: Self.summaryInstructions,
            input: [["role": "user", "content": prompt]],
            options: options,
            maxOutputTokens: Configuration.isReasoningModel(options.model) ? 2000 : 200
        )

        let line = reply.text
            .split(whereSeparator: \.isNewline)
            .first
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        guard !line.isEmpty else {
            throw IndexRoutingError.noUsableSearch
        }
        return String(line.prefix(240))
    }

    static func randomUnitVector(dimension: Int) -> [Float] {
        var vector = (0..<dimension).map { _ in Float.random(in: -1...1) }
        let norm = vector.reduce(0) { $0 + $1 * $1 }.squareRoot()
        if norm > 0 {
            vector = vector.map { $0 / norm }
        }
        return vector
    }
}
