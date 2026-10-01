import Foundation

// MARK: - Chat Models (shared across Search UI)

enum ChatRole {
    case user
    case assistant
}

enum MessageStatus: Equatable {
    case normal
    case streaming
    case error
}

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: ChatRole
    var text: String
    var citations: [String]?
    /// "index / namespace" for each citation of a routed answer, in the same order
    var citationScopes: [String]?
    var status: MessageStatus
    let createdAt: Date
    var error: String?

    init(
        id: UUID = UUID(),
        role: ChatRole,
        text: String,
        citations: [String]? = nil,
        citationScopes: [String]? = nil,
        status: MessageStatus = .normal,
        createdAt: Date = Date(),
        error: String? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.citations = citations
        self.citationScopes = citationScopes
        self.status = status
        self.createdAt = createdAt
        self.error = error
    }

    /// The index and namespace of the citation at `position`, when the answer was routed
    func citationScope(at position: Int) -> String? {
        guard let citationScopes, citationScopes.indices.contains(position) else { return nil }
        return citationScopes[position]
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id && 
        lhs.text == rhs.text && 
        lhs.status == rhs.status && 
        lhs.citations == rhs.citations &&
        lhs.citationScopes == rhs.citationScopes &&
        lhs.error == rhs.error
    }
}
