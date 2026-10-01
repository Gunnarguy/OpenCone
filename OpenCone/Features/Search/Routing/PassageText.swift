import Foundation

/// Reads a passage's text and source out of Pinecone metadata. Indexes come from OpenCone and
/// from other tools, so several field names are tried in order.
enum PassageText {
    /// The passage text, or nil when the metadata holds none.
    /// Priority: _node_content (LlamaIndex), text, content, transcript_preview, body, description, chunk_text
    static func text(from metadata: [String: JSONValue]?) -> String? {
        guard let metadata else { return nil }

        if let nodeContent = metadata["_node_content"]?.string {
            // LlamaIndex stores the node as JSON with the text inside
            if let jsonData = nodeContent.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let textContent = json["text"] as? String {
                return textContent
            }
            return nodeContent
        }

        for key in ["text", "content", "transcript_preview", "body", "description", "chunk_text"] {
            if let value = metadata[key]?.string {
                return value
            }
        }
        return nil
    }

    /// The document a passage came from
    static func source(from metadata: [String: JSONValue]?) -> String {
        metadata?["title"]?.string ??
            metadata?["source"]?.string ??
            metadata?["doc_id"]?.string ??
            "Unknown source"
    }

    /// String-valued metadata only, for display
    static func stringMetadata(from metadata: [String: JSONValue]?) -> [String: String] {
        metadata?.reduce(into: [:]) { acc, kv in
            if let s = kv.value.string {
                acc[kv.key] = s
            }
        } ?? [:]
    }

    /// A search result for one Pinecone match, labelled with where it was found when known
    static func searchResult(from match: QueryMatch, index: String? = nil, namespace: String? = nil) -> SearchResultModel {
        SearchResultModel(
            content: text(from: match.metadata) ?? "No content",
            sourceDocument: source(from: match.metadata),
            score: Float(match.score),
            metadata: stringMetadata(from: match.metadata),
            index: index,
            namespace: namespace
        )
    }

    // MARK: - Tagged context

    /// Added to the system prompt when the context's passages carry tags, so the answer cites them
    /// in a form the answer view can link back to each passage
    static let citeInstructions = """
    Each passage in the context starts with a tag such as [S2]. Cite the passages you use by their \
    tags, right after the sentence they support. If the passages don't hold the answer, say so \
    rather than guessing.
    """

    /// The document a passage came from, with its page when known
    static func location(of result: SearchResultModel) -> String {
        var location = result.sourceDocument
        if let page = result.metadata["page_number"], !page.isEmpty {
            location += ", page \(page)"
        }
        return location
    }

    /// Tag the passages S1, S2, … in order and write them as an answer's context. With
    /// `namingScopes`, each passage also names the index and namespace it came from.
    static func taggedContext(
        _ results: [SearchResultModel],
        maxCharacters: Int,
        namingScopes: Bool = false
    ) -> (text: String, passages: [SearchResultModel]) {
        var blocks: [String] = []
        var passages: [SearchResultModel] = []
        for (position, result) in results.enumerated() {
            var tagged = result
            tagged.citationTag = "S\(position + 1)"
            var heading = "[\(tagged.citationTag!)] \(location(of: result))"
            if namingScopes, let scope = result.scopeLabel {
                heading += " (\(scope))"
            }
            blocks.append("\(heading)\n\(String(result.content.prefix(maxCharacters)))")
            passages.append(tagged)
        }
        return (blocks.joined(separator: "\n\n"), passages)
    }
}
