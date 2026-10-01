import Foundation

/// Ported from OpenResponses (Core/Models/OpenAIModel.swift, 2026-10-01).
/// Represents an OpenAI model from the models API endpoint.
struct OpenAIModel: Codable, Identifiable {
    let id: String
    let object: String
    let created: Int
    let ownedBy: String
    /// `shutdown_date`: when OpenAI will shut the model down (YYYY-MM-DD), or nil when none is announced
    /// (Models API reference, September 29, 2026).
    var shutdownDate: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, object, created
        case ownedBy = "owned_by"
        case shutdownDate = "shutdown_date"
    }
}

/// Response from the OpenAI models API endpoint.
struct OpenAIModelsResponse: Codable {
    let object: String
    let data: [OpenAIModel]
}
