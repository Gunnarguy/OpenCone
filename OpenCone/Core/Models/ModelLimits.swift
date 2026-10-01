import Foundation

/// What each model accepts beyond the catalog: how much it may write, how much it reads, and whether
/// it takes a verbosity. Read from each model's page on OpenAI's docs site
/// (developers.openai.com/api/docs/models/<id>, 2026-10-01): every GPT-6 and GPT-5 model writes up to
/// 128,000 tokens; gpt-4.1 and gpt-4.1-mini 32,768; gpt-4o and gpt-4o-mini 16,384. The GPT-6, 5.6, 5.5
/// and 5.4 models read 1,050,000 tokens, 5.4-mini, 5.4-nano, 5.2 and 5.1 read 400,000, gpt-4.1 about
/// 1,000,000, and gpt-4o 128,000. `text.verbosity` is in OpenAI's create-response reference, read the
/// same day.
enum ModelLimits {
    /// The model a fine-tune was made from: "ft:gpt-4o-mini-2024-07-18:org::id" is gpt-4o-mini-2024-07-18
    static func baseModel(_ model: String) -> String {
        let id = model.lowercased()
        guard id.hasPrefix("ft:") else { return id }
        return id.dropFirst(3).split(separator: ":", maxSplits: 1).first.map(String.init) ?? id
    }

    /// The most a model writes in one response, its reasoning included
    static func maxOutputTokens(for model: String) -> Int {
        let id = baseModel(model)
        if id.hasPrefix("gpt-4o") || id.hasPrefix("chatgpt-4o") { return 16_384 }
        if id.hasPrefix("gpt-4.1") { return 32_768 }
        if id.hasPrefix("gpt-4") || id.hasPrefix("gpt-3") { return 4_096 }
        // GPT-5 and GPT-6, and a later release by its version number
        return 128_000
    }

    /// The most a model reads in one request: instructions, passages, history and question together
    static func contextWindow(for model: String) -> Int? {
        let id = baseModel(model)
        if id.hasPrefix("gpt-4o") { return 128_000 }
        if id.hasPrefix("gpt-4.1") { return 1_047_576 }
        for smaller in ["gpt-5.4-mini", "gpt-5.4-nano", "gpt-5.2", "gpt-5.1"] where id.hasPrefix(smaller) {
            return 400_000
        }
        if id.hasPrefix("gpt-6") || id.hasPrefix("gpt-5.6") || id.hasPrefix("gpt-5.5") || id.hasPrefix("gpt-5.4") {
            return 1_050_000
        }
        return CurrentModelCatalog.isModern(model) ? 1_050_000 : nil
    }

    /// Every model in the menu lists code_interpreter among its tools except GPT-5.4 Pro and GPT-5.2 Pro
    /// (each model's page, read 2026-10-01); a request that names a tool the model lacks fails
    static func supportsCodeInterpreter(_ model: String) -> Bool {
        !["gpt-5.4-pro", "gpt-5.2-pro"].contains(CurrentModelCatalog.baseID(baseModel(model)))
    }

    /// The models in the Flex and Fast tables of OpenAI's pricing page (read 2026-10-01). Ultrafast,
    /// access-controlled and listed for GPT-6 Astra only, isn't offered.
    private static let flexModels: Set<String> = [
        "gpt-6-astra", "gpt-6.1-sol", "gpt-6-sol", "gpt-6-luna", "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna",
        "gpt-5.5", "gpt-5.5-pro", "gpt-5.4", "gpt-5.4-mini", "gpt-5.4-nano", "gpt-5.4-pro", "gpt-5.2", "gpt-5.1",
        "gpt-5", "gpt-5-mini", "gpt-5-nano",
    ]
    private static let fastModels: Set<String> = [
        "gpt-6-astra", "gpt-6.1-sol", "gpt-6-sol", "gpt-6-luna", "gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna",
        "gpt-5.5", "gpt-5.4", "gpt-5.4-mini", "gpt-5.2", "gpt-5.1", "gpt-5", "gpt-5-mini",
        "gpt-4.1", "gpt-4.1-mini", "gpt-4.1-nano", "gpt-4o", "gpt-4o-mini",
    ]

    /// The service tiers a model is offered at: Auto and Standard always, Flex and Fast where OpenAI
    /// prices them. A model neither table names, a newer one included, gets Auto and Standard only.
    static func serviceTiers(for model: String) -> [String] {
        var tiers = ["auto", "default"]
        // The Fast mode guide: "Fast mode doesn't support fine-tuned models"
        guard !model.lowercased().hasPrefix("ft:") else { return tiers }
        let id = CurrentModelCatalog.baseID(model)
        if flexModels.contains(id) { tiers.append("flex") }
        if fastModels.contains(id) { tiers.append("fast") }
        return tiers
    }

    /// GPT-5 and later take `text.verbosity`; earlier models reject it
    static func supportsVerbosity(_ model: String) -> Bool {
        let id = baseModel(model)
        return id.hasPrefix("gpt-5") || id.hasPrefix("gpt-6") || CurrentModelCatalog.isModern(model)
    }

    /// Answer length choices up to what the model allows
    static func lengthChoices(for model: String) -> [Int] {
        let limit = maxOutputTokens(for: model)
        var choices = [1_000, 2_000, 4_000, 8_000, 16_000, 32_000, 64_000].filter { $0 < limit }
        choices.append(limit)
        return choices
    }

    /// "128K" for a token count
    static func shortCount(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            let millions = Double(tokens) / 1_000_000
            return millions == millions.rounded() ? "\(Int(millions))M" : String(format: "%.3gM", millions)
        }
        if tokens >= 1_000 {
            let thousands = Double(tokens) / 1_000
            return thousands == thousands.rounded() ? "\(Int(thousands))K" : String(format: "%.1fK", thousands)
        }
        return "\(tokens)"
    }
}
