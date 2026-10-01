import Foundation

/// Ported from OpenResponses (Core/Models/ModelCatalog.swift, 2026-10-01); keep the two in step.
/// The model list built into the app (Resources/ModelCatalog/ModelCatalog.json): which models are current and in what
/// order, what each accepts, the default model, and where a retired model's presets move. A newer model on the
/// account that this list does not name gets its settings from its page on OpenAI's docs site instead
/// (`settings(fromDocsPage:id:checkedOn:)`, `ModelCatalogStore`). See docs/model-catalog.md.
nonisolated struct ModelCatalog: Codable, Equatable, Sendable {
    nonisolated struct Model: Codable, Equatable, Sendable {
        let id: String
        /// One line under the model's name in the model picker.
        let summary: String
        /// `reasoning.effort` values the model accepts, in `ModelCatalog.efforts` order.
        let reasoningEfforts: [String]
        /// `reasoning.mode: "pro"`.
        let pro: Bool
        /// `async: true` on function and custom tools.
        let asyncTools: Bool
        /// The day OpenAI released the model, or the day the catalog first listed it.
        var released: String?
    }

    nonisolated struct Retired: Codable, Equatable, Sendable {
        let id: String
        /// Where a preset naming this model, or one of its dated snapshots, moves; the default model when absent.
        var replacement: String?
    }

    /// The only schema this version reads; a file with another number is ignored.
    static let supportedSchema = 1
    /// Every `reasoning.effort` value, lowest first.
    static let efforts = ["none", "minimal", "low", "medium", "high", "xhigh", "max"]

    let schema: Int
    /// Raised with every change; the higher of the built-in and downloaded revisions wins.
    let revision: Int
    let updated: String
    var notes: String?
    let defaultModel: String
    /// Current general-purpose models, in menu order.
    let current: [Model]
    /// Earlier models, listed after the current ones.
    let earlier: [String]
    let retired: [Retired]

    /// Why the app cannot use this catalog, or nil when it can.
    func problem() -> String? {
        guard schema == Self.supportedSchema else { return "schema \(schema) is not \(Self.supportedSchema)" }
        guard revision >= 1 else { return "revision must be at least 1" }
        guard (1...50).contains(current.count), earlier.count <= 100, retired.count <= 200 else { return "too many or too few models" }
        var seen = Set<String>()
        for id in current.map(\.id) + earlier + retired.map(\.id) {
            guard Self.isValidID(id) else { return "invalid model ID \(id)" }
            guard seen.insert(id).inserted else { return "\(id) is listed twice" }
        }
        for model in current {
            guard !model.reasoningEfforts.isEmpty, model.reasoningEfforts == Self.efforts.filter(model.reasoningEfforts.contains) else {
                return "\(model.id): reasoning efforts must be distinct known values, lowest first"
            }
            guard (1...80).contains(model.summary.count) else { return "\(model.id): summary must be 1 to 80 characters" }
        }
        guard current.contains(where: { $0.id == defaultModel }) else { return "default model \(defaultModel) is not a current model" }
        if let bad = retired.compactMap(\.replacement).first(where: { !Self.isValidID($0) }) { return "invalid replacement \(bad)" }
        return nil
    }

    static func isValidID(_ id: String) -> Bool {
        id.range(of: "^[a-z0-9][a-z0-9.-]{0,63}$", options: .regularExpression) != nil
    }

    /// Decodes and validates a catalog file; nil when the app cannot use it.
    static func decode(_ data: Data) -> ModelCatalog? {
        guard let catalog = try? JSONDecoder().decode(ModelCatalog.self, from: data), catalog.problem() == nil else { return nil }
        return catalog
    }

    // MARK: - OpenAI's model pages

    /// What a model's docs page says about using it in this app.
    enum DocsPage: Equatable, Sendable {
        case model(Model)
        /// The page lists the Responses API as not supported, so the model cannot be used for chat here.
        case unsupported
        /// The page is missing its endpoints table or its reasoning efforts; the model keeps the fallback settings.
        case unreadable
    }

    /// The Markdown form of a model's page on OpenAI's docs site.
    static func docsPageURL(for id: String) -> URL? {
        guard isValidID(id) else { return nil }
        return URL(string: "https://developers.openai.com/api/docs/models/\(id).md")
    }

    /// Reads a model's settings from its docs page, which states them in fixed forms (the GPT-6.1 Sol page on
    /// September 29, 2026): a `> ` summary line under the title, "`reasoning.effort` supports `low`, `medium` (default),
    /// ..." in the text, and an endpoints table with a "| Responses | `v1/responses` | Supported |" row. Model pages
    /// do not state pro mode or async tool calls, so those follow the rules for models the list does not name:
    /// pro for every GPT-5.6 and later general model, async for versions after 6.0.
    static func settings(fromDocsPage page: String, id: String, checkedOn day: String) -> DocsPage {
        let text = page.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard text.range(of: #"\| Responses \| `v1/responses` \| Supported \|"#, options: .regularExpression) != nil else {
            return text.contains("| Responses |") ? .unsupported : .unreadable
        }
        guard let sentence = text.range(of: #"`reasoning\.effort` supports [^.]*\."#, options: .regularExpression) else { return .unreadable }
        // Every other piece between backticks is a code span: `reasoning.effort`, then each value.
        let spans = text[sentence].split(separator: "`", omittingEmptySubsequences: false).enumerated()
            .filter { $0.offset % 2 == 1 }.map { String($0.element) }
        let accepted = Self.efforts.filter(spans.contains)
        guard !accepted.isEmpty else { return .unreadable }

        let quote = page.split(separator: "\n").first { $0.hasPrefix("> ") && !$0.contains("documentation index") }
        var summary = quote.map { $0.dropFirst(2).trimmingCharacters(in: .whitespaces) } ?? ""
        if summary.hasSuffix(".") { summary.removeLast() }
        if summary.count > 80 {
            let cut = summary.prefix(79)
            summary = String(cut[..<(cut.lastIndex(of: " ") ?? cut.endIndex)]) + "…"
        }
        let generation = CurrentModelCatalog.generation(id)
        return .model(Model(id: id, summary: summary.isEmpty ? "Current generation model" : summary, reasoningEfforts: accepted,
                            pro: CurrentModelCatalog.isModern(id),
                            asyncTools: generation.map { ($0.major, $0.minor) > (6, 0) } ?? false,
                            released: day))
    }
}
