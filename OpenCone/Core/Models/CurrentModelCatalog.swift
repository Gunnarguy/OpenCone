import Foundation

/// Ported from OpenResponses (Core/Models/CurrentModelCatalog.swift, 2026-10-01): the text-model part. OpenCone
/// leaves out image, realtime and transcription models, pro reasoning mode and async tool calls, which it does not use.
///
/// Which text models the app offers and what each accepts. The current models, their settings, the default model,
/// the earlier models and the retired ones come from the model list built into the app (`ModelCatalog`), verified
/// against OpenAI's model pages, GPT-6 guide, reasoning guide and async tool calling guide on September 29, 2026.
/// Account availability still comes from GET /models; discovery never grants capabilities.
///
/// A later general-purpose release the list does not name (for example `gpt-6.2-sol` or `gpt-7-luna`) is recognized
/// by its version number and listed once GET /models shows the account has it (`currentAccountModels`). Its settings
/// come from its page on OpenAI's docs site, read once (`ModelCatalogStore.learnSettings(for:)`), or from the fallback
/// rules below until that page has been read. Specialized variants (audio, realtime, transcription, image, search,
/// codex, cyber and similar) are not listed.
enum CurrentModelCatalog {
    /// Default for a new install and for a saved model that is retired: the catalog's `defaultModel`.
    static var defaultModel: String { ModelCatalogStore.shared.catalog.defaultModel }
    /// Small, inexpensive model for background work such as drafting an index's one-line summary.
    static let utilityModel = "gpt-6-luna"
    /// Current general-purpose models in menu order: the catalog's `current`.
    static var recommended: [String] { ModelCatalogStore.shared.catalog.current.map(\.id) }
    /// Earlier models listed after the current ones: the catalog's `earlier`. Models whose shutdown OpenAI has
    /// announced are left out; the account's model list and the custom model field reach every other model it can use.
    static var legacy: [String] { ModelCatalogStore.shared.catalog.earlier }

    /// The settings for a current model or one of its dated snapshots: its built-in entry, or what its page on OpenAI's
    /// docs site said.
    static func entry(for id: String) -> ModelCatalog.Model? {
        let key = family(id)
        let store = ModelCatalogStore.shared
        return store.catalog.current.first { $0.id == key } ?? store.learnedModel(key)
    }

    /// Variant words that mark a model as something other than a general text-and-tools model.
    private static let specializedVariants: Set<String> = [
        "audio", "realtime", "transcribe", "tts", "image", "search", "codex", "cyber", "chat", "oss",
        "live", "translate", "embedding", "moderation", "instruct", "diarize", "rosalind", "daybreak", "latest", "deep", "research",
    ]

    /// Strips a trailing dated snapshot (`-2026-09-03`) and normalizes case.
    static func baseID(_ id: String) -> String {
        let normalized = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let range = normalized.range(of: "-\\d{4}-\\d{2}-\\d{2}$", options: .regularExpression) else { return normalized }
        return String(normalized[..<range.lowerBound])
    }

    /// Parses `gpt-<major>[.<minor>][-variant...]` into its version and variant words.
    static func generation(_ id: String) -> (major: Int, minor: Int, variants: [String])? {
        let base = baseID(id)
        guard base.hasPrefix("gpt-") else { return nil }
        let parts = base.dropFirst(4).split(separator: "-").map(String.init)
        guard let version = parts.first else { return nil }
        let numbers = version.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(numbers.count), let major = Int(numbers[0]) else { return nil }
        let minor = numbers.count == 2 ? Int(numbers[1]) : 0
        guard let minor else { return nil }
        let variants = Array(parts.dropFirst())
        guard variants.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isLetter) }) else { return nil }
        return (major, minor, variants)
    }

    static func family(_ id: String) -> String {
        baseID(id)
    }

    /// Current general-purpose models: the GPT-5.6 and GPT-6 families and any later general release.
    static func isModern(_ id: String) -> Bool {
        guard let parsed = generation(id) else { return false }
        guard (parsed.major, parsed.minor) >= (5, 6) else { return false }
        if parsed.variants.contains(where: specializedVariants.contains) { return false }
        if (parsed.major, parsed.minor) == (5, 6) {
            return parsed.variants.isEmpty || ["sol", "terra", "luna"].contains(parsed.variants.joined(separator: "-"))
        }
        return parsed.variants.count <= 1
    }

    /// The model menus: current general-purpose models on the account that the catalog does not list yet, newest
    /// first, then the catalog, then the selected model if it is neither.
    static func selectionModels(including selected: String, account: [String] = []) -> [String] {
        let listed = recommended + legacy
        let models = account.filter { !listed.contains($0) } + listed
        return models.contains(selected) || selected.isEmpty ? models : models + [selected]
    }

    /// The current general-purpose models in a GET /models listing, newest version first. Dated snapshots,
    /// specialized variants, retired models and models whose docs page rules out the Responses API are left out.
    static func currentAccountModels(_ ids: [String]) -> [String] {
        var seen = Set<String>()
        let store = ModelCatalogStore.shared
        return ids
            .filter { baseID($0) == $0 && isModern($0) && !isRetired($0) && !store.isUnsupported($0) && seen.insert($0).inserted }
            .sorted { priority($0) == priority($1) ? $0 < $1 : priority($0) > priority($1) }
    }

    /// Models OpenAI has shut down or scheduled for shutdown: the catalog's `retired` (first taken from the
    /// deprecations page on September 24, 2026). They are hidden from the model lists, and a saved model that is one
    /// moves to `replacement(for:)` when Settings loads. Fine-tuned models (`ft:`) are not listed: their inference
    /// continues until the base model retires.
    static var retiredModels: [String] { ModelCatalogStore.shared.catalog.retired.map(\.id) }

    /// Where a saved model that is retired moves: the replacement of the longest matching retired entry, so
    /// `gpt-5-mini-2025-08-07` follows `gpt-5-mini` rather than `gpt-5`, otherwise the default model.
    static func replacement(for id: String) -> String {
        let full = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let catalog = ModelCatalogStore.shared.catalog
        var match: ModelCatalog.Retired?
        for entry in catalog.retired where entry.replacement != nil && (full == entry.id || full.hasPrefix(entry.id + "-")) {
            if entry.id.count > (match?.id.count ?? 0) { match = entry }
        }
        return match?.replacement ?? catalog.defaultModel
    }

    /// Retired when the catalog lists the model (or it is a dated snapshot or older variant of one), or when the
    /// account's model list says it shuts down within 30 days.
    static func isRetired(_ id: String) -> Bool {
        let full = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let base = baseID(id)
        let store = ModelCatalogStore.shared
        return retiredModels.contains { name in
            [full, base].contains { $0 == name || ($0.hasPrefix(name + "-") && !isModern($0)) }
        } || full.contains("chat-latest") || store.isShuttingDown(full) || store.isShuttingDown(base)
    }

    static func reasoningEfforts(for id: String) -> [String] {
        if let model = entry(for: id) { return model.reasoningEfforts }
        let key = family(id)
        if isModern(key) {
            // A later release the catalog does not list yet starts at low: GPT-6 Astra and GPT-6.1 Sol reject `none`
            // with HTTP 400, so offering it could break requests.
            return ["low", "medium", "high", "xhigh", "max"]
        }
        if id.contains("-pro") { return ["medium", "high", "xhigh"] }
        if ["gpt-5.5", "gpt-5.4", "gpt-5.2"].contains(where: { id.hasPrefix($0) }) { return ["none", "low", "medium", "high", "xhigh"] }
        if id.hasPrefix("gpt-5.1") { return ["none", "low", "medium", "high"] }
        if id.hasPrefix("gpt-5") { return ["minimal", "low", "medium", "high"] }
        return ["low", "medium", "high"]
    }

    static func normalizedEffort(_ effort: String, model: String) -> String {
        let options = reasoningEfforts(for: model)
        if options.contains(effort) { return effort }
        return ["none", "minimal"].contains(effort) ? "low" : "medium"
    }

    /// A model ID as VoiceOver should read it: "gpt-6-sol" becomes "GPT 6 Sol".
    static func spokenName(for id: String) -> String {
        id.split(separator: "-").map { part -> String in
            if part.lowercased() == "gpt" { return "GPT" }
            guard let first = part.first, first.isLetter else { return String(part) }
            return first.uppercased() + part.dropFirst()
        }.joined(separator: " ")
    }

    static func description(for id: String) -> String {
        if let model = entry(for: id) { return model.summary }
        if isModern(id) { return "Current generation model" }
        if isRetired(id) { return "Retired model · choose a current replacement" }
        return "Earlier model · " + (id.hasPrefix("gpt-5") || id.hasPrefix("o") ? "reasoning" : "text and chat")
    }

    static func priority(_ id: String) -> Int {
        let models = recommended + legacy
        if let index = models.firstIndex(of: family(id)) { return models.count - index }
        // A later general release sorts above everything listed, newest version first.
        if isModern(id), let parsed = generation(id) { return 1_000 + parsed.major * 100 + parsed.minor }
        return 0
    }
}
