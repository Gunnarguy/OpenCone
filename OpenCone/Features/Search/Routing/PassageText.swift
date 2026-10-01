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
}
