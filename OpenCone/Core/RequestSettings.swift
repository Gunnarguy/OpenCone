import Foundation

/// The answer settings each OpenAI request reads, by their UserDefaults keys. Settings writes them
/// (`SettingsViewModel.persistRequestSettings`); `OpenAIService` reads them for every request, so a
/// change applies to the next question. Values outside what the API accepts fall back to the default.
enum RequestSettings {
    enum Key {
        static let verbosity = "openai.verbosity"
        static let serviceTier = "openai.serviceTier"
        static let webSearchContextSize = "openai.webSearchContextSize"
        static let webSearchDomains = "openai.webSearchDomains"
        /// New in 2026-10: the older `conversation.maxTurns` was never read, so its stored 10 isn't inherited
        static let historyExchanges = "conversation.historyExchanges"
    }

    /// Long enough that reasoning doesn't use up the answer; within every current model's 128,000
    static let defaultMaxOutputTokens = 16_000
    static let defaultHistoryExchanges = 4
    static let maxHistoryExchanges = 20

    static let verbosityOptions = ["low", "medium", "high"]
    /// `auto` leaves the field out, which uses the OpenAI project's own setting. OpenAI renamed
    /// Priority processing Fast mode on 2026-07-30 and takes `fast` or `priority` for it (Fast mode guide,
    /// read 2026-10-01). Ultrafast is left out: it's access-controlled.
    static let serviceTierOptions = ["auto", "default", "flex", "fast"]
    static let searchContextOptions = ["low", "medium", "high"]

    static var verbosity: String {
        valid(UserDefaults.standard.string(forKey: Key.verbosity), in: verbosityOptions, otherwise: "medium")
    }

    /// nil for auto, so the request leaves `service_tier` out
    static var serviceTier: String? {
        let tier = valid(UserDefaults.standard.string(forKey: Key.serviceTier), in: serviceTierOptions, otherwise: "auto")
        return tier == "auto" ? nil : tier
    }

    /// The tier sent with a request for this model: the setting when the model is offered at it, and
    /// nil (Auto, the field left out) otherwise
    static func serviceTier(for model: String) -> String? {
        guard let tier = serviceTier, ModelLimits.serviceTiers(for: model).contains(tier) else { return nil }
        return tier
    }

    static var webSearchContextSize: String {
        valid(UserDefaults.standard.string(forKey: Key.webSearchContextSize), in: searchContextOptions, otherwise: "medium")
    }

    static var webSearchDomains: [String] {
        domains(from: UserDefaults.standard.string(forKey: Key.webSearchDomains) ?? "")
    }

    static var historyExchanges: Int {
        let stored = UserDefaults.standard.object(forKey: Key.historyExchanges) as? Int ?? defaultHistoryExchanges
        return min(max(stored, 0), maxHistoryExchanges)
    }

    /// "https://www.example.com/x, docs.pinecone.io" becomes ["example.com", "docs.pinecone.io"]
    static func domains(from text: String) -> [String] {
        var seen = Set<String>()
        return text
            .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" || $0 == ";" })
            .compactMap { raw -> String? in
                var domain = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                for scheme in ["https://", "http://"] where domain.hasPrefix(scheme) {
                    domain.removeFirst(scheme.count)
                }
                if let slash = domain.firstIndex(of: "/") {
                    domain = String(domain[..<slash])
                }
                // OpenAI allows a listed site's subdomains too, so "www." would only narrow it
                if domain.hasPrefix("www.") {
                    domain.removeFirst(4)
                }
                guard domain.contains("."), !domain.hasPrefix("."), !domain.hasSuffix(".") else { return nil }
                return seen.insert(domain).inserted ? domain : nil
            }
    }

    private static func valid(_ value: String?, in options: [String], otherwise fallback: String) -> String {
        guard let value, options.contains(value) else { return fallback }
        return value
    }
}
