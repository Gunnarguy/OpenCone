import Foundation

/// Decides which indexes and namespaces to search for a question. The model gets one function
/// tool, `search_index`, whose description lists every searchable index with its summary and
/// namespaces, and asks for up to `maxSearches` searches in one turn. The app runs them itself
/// with the person's Pinecone key, so this works on the indexes people already have, with their
/// own embeddings.
@MainActor
final class IndexRouter {
    /// One search per index on Pinecone's Starter plan, which allows 5 indexes per project
    static let maxSearches = 5
    static let toolName = "search_index"
    /// Namespaces listed per index in the tool description, largest first
    static let maxNamespacesListed = 40
    static let maxHistoryMessages = 6
    static let maxHistoryCharacters = 1500

    struct SearchRequest: Equatable, Hashable {
        let index: String
        /// "" is the default namespace
        let namespace: String
        let query: String

        var scopeLabel: String {
            namespace.isEmpty ? index : "\(index) / \(namespace)"
        }
    }

    enum Decision: Equatable {
        case search([SearchRequest])
        /// The model answered without searching (a greeting, or a question about the conversation)
        case answer(String)
    }

    /// The index and namespace open in Search, passed to the model as a preference
    struct Hint: Equatable {
        let index: String?
        let namespace: String?
    }

    private let responses: ResponsesClient

    init(responses: ResponsesClient) {
        self.responses = responses
    }

    /// Ask the model where to search.
    /// - Parameters:
    ///   - question: The person's question
    ///   - history: Earlier messages, so a follow-up like "and in the other one?" can be resolved
    ///   - profiles: Every known index; only searchable ones are offered
    ///   - hint: The open index and namespace
    ///   - options: The person's model settings
    func route(
        question: String,
        history: [ChatMessage],
        profiles: [IndexProfile],
        hint: Hint,
        options: ResponsesClient.ModelOptions
    ) async throws -> Decision {
        let routable = profiles.filter(\.isRoutable).sorted { $0.name < $1.name }
        guard !routable.isEmpty else {
            throw IndexRoutingError.noSearchableIndex
        }

        let reply = try await responses.create(
            instructions: Self.instructions(hint: hint),
            input: Self.input(question: question, history: history),
            options: options,
            tools: [Self.toolDefinition(for: routable)],
            maxOutputTokens: Configuration.isReasoningModel(options.model) ? 4000 : 800
        )

        let requests = Self.searchRequests(from: reply.functionCalls, profiles: routable, cap: Self.maxSearches)
        if !requests.isEmpty {
            return .search(requests)
        }

        let text = reply.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if reply.functionCalls.isEmpty, !text.isEmpty {
            return .answer(text)
        }

        throw IndexRoutingError.noUsableSearch
    }

    // MARK: - Request parts

    static func toolDefinition(for profiles: [IndexProfile]) -> [String: Any] {
        let lines = profiles.map { profile -> String in
            let summary = profile.summary.isEmpty ? "No summary yet." : profile.summary
            let listed = profile.namespaces.prefix(maxNamespacesListed)
            let namespaceList = listed.map { namespace -> String in
                let name = namespace.name.isEmpty ? "\"\" (default)" : "\"\(namespace.name)\""
                return "\(name) with \(namespace.vectorCount) passages"
            }
            .joined(separator: ", ")
            let unlisted = profile.namespaces.count - listed.count
            let more = unlisted > 0 ? ", and \(unlisted) more" : ""
            return "- \(profile.name): \(summary) Namespaces: \(namespaceList)\(more)."
        }

        let description = """
        Search one of the person's Pinecone indexes and get back the passages closest to `query`. \
        Call it once for each index and namespace that could hold the answer. To compare two \
        sources, search each of them.

        Indexes:
        \(lines.joined(separator: "\n"))
        """

        return [
            "type": "function",
            "name": toolName,
            "description": description,
            "strict": true,
            "parameters": [
                "type": "object",
                "properties": [
                    "index": [
                        "type": "string",
                        "enum": profiles.map(\.name),
                        "description": "The index to search.",
                    ],
                    "namespace": [
                        "type": "string",
                        "description": "A namespace of that index, exactly as listed. Use \"\" for the default namespace.",
                    ],
                    "query": [
                        "type": "string",
                        "description": "What to look for, phrased the way the passages would say it.",
                    ],
                ],
                "required": ["index", "namespace", "query"],
                "additionalProperties": false,
            ],
        ]
    }

    static func instructions(hint: Hint) -> String {
        var text = """
        Before an answer is written, you choose where to look. The person keeps documents in the \
        Pinecone indexes listed in the search_index tool. Call search_index for each index and \
        namespace likely to hold what the question needs, all in this turn, at most \(maxSearches) \
        calls. When the question compares or contrasts two indexes, namespaces or topics, search \
        each side. Write each query the way the passages would phrase it.
        """

        if let index = hint.index, !index.isEmpty {
            var open = "index \"\(index)\""
            if let namespace = hint.namespace, !namespace.isEmpty {
                open += " (namespace \"\(namespace)\")"
            }
            text += " The person has \(open) open. Prefer it when the question could be about it, and search elsewhere when another index fits better."
        }

        text += " If the question needs nothing from the documents, such as a greeting or a question about this conversation, answer it directly and don't call the tool."
        return text
    }

    static func input(question: String, history: [ChatMessage]) -> [[String: Any]] {
        var items: [[String: Any]] = history.suffix(maxHistoryMessages).compactMap { message in
            let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return [
                "role": message.role == .user ? "user" : "assistant",
                "content": String(text.prefix(maxHistoryCharacters)),
            ]
        }
        items.append(["role": "user", "content": question])
        return items
    }

    // MARK: - Checking the model's calls

    /// Turn the model's calls into searches the app can run: the index must be offered, the
    /// namespace must exist in it, duplicates are dropped and at most `cap` survive.
    static func searchRequests(from calls: [ResponsesClient.FunctionCall], profiles: [IndexProfile], cap: Int) -> [SearchRequest] {
        var seen = Set<SearchRequest>()
        var requests: [SearchRequest] = []

        for call in calls where call.name == toolName {
            guard requests.count < cap else { break }
            guard let data = call.arguments.data(using: .utf8),
                  let arguments = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let indexName = arguments["index"] as? String,
                  let profile = profiles.first(where: { $0.name == indexName })
                      ?? profiles.first(where: { $0.name.caseInsensitiveCompare(indexName) == .orderedSame }),
                  let namespace = resolveNamespace(arguments["namespace"] as? String, in: profile)
            else {
                continue
            }

            let query = (arguments["query"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { continue }

            let request = SearchRequest(index: profile.name, namespace: namespace, query: query)
            if seen.insert(request).inserted {
                requests.append(request)
            }
        }

        return requests
    }

    /// The namespace as the index names it, or nil when the index has no such namespace
    static func resolveNamespace(_ raw: String?, in profile: IndexProfile) -> String? {
        let name = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if profile.hasNamespace(name) {
            return name
        }
        if let match = profile.namespaces.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return match.name
        }
        let asksForDefault = name.isEmpty || ["default", "(default)", "\"\""].contains(name.lowercased())
        if asksForDefault {
            if profile.hasNamespace("") {
                return ""
            }
            if profile.namespaces.count == 1 {
                return profile.namespaces[0].name
            }
        }
        return nil
    }

    // MARK: - Context for the answer

    struct RoutedSearch {
        let request: SearchRequest
        let results: [SearchResultModel]
        /// The search itself failed (an error from Pinecone or the embedding), as opposed to
        /// finding nothing, so the answer can say so
        var failed = false
    }

    struct RoutedContext {
        let text: String
        /// The passages sent, in tag order
        let passages: [SearchResultModel]
        /// One per distinct document and place, alternating between searches so the first few
        /// cover every search
        let citations: [String]
        let citationScopes: [String]
    }

    /// Added to the system prompt when the context comes from several searches
    static let answerInstructions = """
    The context holds passages from the person's indexes, grouped under the search that found \
    them. Each passage starts with a tag such as [S2]; cite the passages you use by their tags. \
    When the answer draws on more than one index or namespace, say which one each point comes \
    from. If a search failed or found nothing useful, say so rather than guessing.
    """

    static func context(for searches: [RoutedSearch], passagesPerSearch: Int, maxCharacters: Int) -> RoutedContext {
        var blocks: [String] = []
        var passages: [SearchResultModel] = []
        var tag = 0

        for (number, search) in searches.enumerated() {
            let namespace = search.request.namespace.isEmpty ? "default" : search.request.namespace
            var block = "Search \(number + 1): index \"\(search.request.index)\", namespace \"\(namespace)\", query \"\(search.request.query)\""
            let kept = Array(search.results.prefix(passagesPerSearch))
            if search.failed {
                block += "\nThis search failed, so nothing from it is included."
            } else if kept.isEmpty {
                block += "\nNo passages found."
            }
            for result in kept {
                tag += 1
                var location = result.sourceDocument
                if let page = result.metadata["page_number"], !page.isEmpty {
                    location += ", page \(page)"
                }
                block += "\n[S\(tag)] \(location)\n\(String(result.content.prefix(maxCharacters)))"
                var tagged = result
                tagged.citationTag = "S\(tag)"
                passages.append(tagged)
            }
            blocks.append(block)
        }

        // Alternate between searches so a compare-and-contrast shows both sides first
        var citations: [String] = []
        var scopes: [String] = []
        var seen = Set<String>()
        let kept = searches.map { Array($0.results.prefix(passagesPerSearch)) }
        let deepest = kept.map(\.count).max() ?? 0
        for rank in 0..<deepest {
            for (number, results) in kept.enumerated() where rank < results.count {
                let result = results[rank]
                let scope = result.scopeLabel ?? searches[number].request.scopeLabel
                let key = "\(scope)\u{1F}\(result.sourceDocument)"
                if seen.insert(key).inserted {
                    citations.append(result.sourceDocument)
                    scopes.append(scope)
                }
            }
        }

        return RoutedContext(
            text: blocks.joined(separator: "\n\n"),
            passages: passages,
            citations: citations,
            citationScopes: scopes
        )
    }
}

enum IndexRoutingError: LocalizedError {
    case noSearchableIndex
    case noUsableSearch

    var errorDescription: String? {
        switch self {
        case .noSearchableIndex:
            return "No index is ready for routed search yet."
        case .noUsableSearch:
            return "The model didn't ask for a search OpenCone could run."
        }
    }
}
