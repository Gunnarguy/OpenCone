import Foundation
import os

/// Ported from OpenResponses (Core/Services/ModelCatalogStore.swift, 2026-10-01); keep the two in step.
/// The model data the app uses, readable from any thread: the list built into the app, the settings read from OpenAI's
/// docs pages for newer models on the account, and the account's shutdown dates. Nothing needs updating by hand when
/// OpenAI releases a model: GET /models lists it, and `learnSettings(for:)` reads its page once.
nonisolated final class ModelCatalogStore: @unchecked Sendable {
    static let shared = ModelCatalogStore()

    /// A model whose shutdown date is this close, or past, counts as retired: hidden from the model lists, and a preset
    /// naming it moves to its replacement.
    static let shutdownWindow: TimeInterval = 30 * 24 * 60 * 60
    /// A model's docs page is read again after this long, in case OpenAI changed it or it could not be read.
    static let recheckInterval: TimeInterval = 7 * 24 * 60 * 60
    /// At most this many docs pages are read per refresh.
    static let lookupsPerRefresh = 3

    /// What the app learned about a model from its docs page.
    struct Learned: Codable, Equatable, Sendable {
        /// nil when the page could not be read; the model keeps the fallback settings.
        var model: ModelCatalog.Model?
        /// The page lists the Responses API as not supported, so the model lists leave the model out.
        var unsupported = false
        var checked: Date
    }

    private struct State: Sendable {
        var catalog: ModelCatalog
        var learned: [String: Learned]
        var shutdowns: [String: Date]
    }

    private let state: OSAllocatedUnfairLock<State>
    private let learnedURL: URL
    private let defaults: UserDefaults
    private let readsDocs: Bool
    private let shutdownsKey = "accountModelShutdowns"

    /// `restore: false` ignores saved settings and shutdown dates, and `readsDocs: false` never fetches a page. The
    /// shared store does both under unit tests, so they run against the built-in list without the network.
    init(catalog: ModelCatalog = ModelCatalogStore.builtIn, cacheDirectory: URL? = nil, defaults: UserDefaults = .standard,
         restore: Bool = !ModelCatalogStore.isRunningTests, readsDocs: Bool = !ModelCatalogStore.isRunningTests) {
        let directory = cacheDirectory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        learnedURL = directory.appendingPathComponent("LearnedModelSettings.json")
        self.defaults = defaults
        self.readsDocs = readsDocs
        var initial = State(catalog: catalog, learned: [:], shutdowns: [:])
        if restore {
            if let data = try? Data(contentsOf: learnedURL), let saved = try? JSONDecoder().decode([String: Learned].self, from: data) {
                initial.learned = saved
            }
            let dates = defaults.dictionary(forKey: shutdownsKey) as? [String: String] ?? [:]
            initial.shutdowns = dates.compactMapValues(Self.date)
        }
        state = OSAllocatedUnfairLock(initialState: initial)
    }

    /// The built-in model list.
    var catalog: ModelCatalog { state.withLock { $0.catalog } }

    /// Replaces the model list (tests).
    func use(_ catalog: ModelCatalog) {
        state.withLock { $0.catalog = catalog }
    }

    // MARK: - Settings from OpenAI's docs pages

    /// Settings read from the model's docs page, when the built-in list does not name it.
    func learnedModel(_ id: String) -> ModelCatalog.Model? {
        state.withLock { $0.learned[id]?.model }
    }

    /// True when the model's docs page says the Responses API does not support it.
    func isUnsupported(_ id: String) -> Bool {
        state.withLock { $0.learned[id]?.unsupported ?? false }
    }

    /// Reads the docs page of each model that has none on record, or whose record is older than `recheckInterval`, at
    /// most `lookupsPerRefresh` of them, and keeps what it finds for the next launch. A page that cannot be fetched is
    /// tried again on the next refresh. Returns true when a model's settings changed.
    @discardableResult
    func learnSettings(for ids: [String], now: Date = Date(),
                       load: (URL) async throws -> (Data, URLResponse) = { try await URLSession.shared.data(from: $0, delegate: APIActivity.recorder) }) async -> Bool {
        guard readsDocs else { return false }
        let due = ids.filter { id in
            guard let learned = state.withLock({ $0.learned[id] }) else { return true }
            return now.timeIntervalSince(learned.checked) >= Self.recheckInterval
        }
        var changed = false
        for id in due.prefix(Self.lookupsPerRefresh) {
            guard let url = ModelCatalog.docsPageURL(for: id), let (data, response) = try? await load(url),
                  let status = (response as? HTTPURLResponse)?.statusCode, status < 500 else { continue }
            var learned = Learned(checked: now)
            if status == 200, let page = String(data: data, encoding: .utf8) {
                switch ModelCatalog.settings(fromDocsPage: page, id: id, checkedOn: Self.day(now)) {
                case .model(let model): learned.model = model
                case .unsupported: learned.unsupported = true
                case .unreadable: break
                }
            }
            if remember(learned, for: id) { changed = true }
            Self.log("Read OpenAI's page for \(id): \(learned.model != nil ? "settings found" : learned.unsupported ? "not for Responses" : "no settings")",
                     level: .info)
        }
        return changed
    }

    /// Records what a model's page said and saves the records. Returns true when the model's settings changed.
    @discardableResult
    func remember(_ learned: Learned, for id: String) -> Bool {
        let (previous, all) = state.withLock { state -> (Learned?, [String: Learned]) in
            let previous = state.learned[id]
            state.learned[id] = learned
            return (previous, state.learned)
        }
        if let data = try? JSONEncoder().encode(all) { try? data.write(to: learnedURL, options: .atomic) }
        return previous?.model != learned.model || previous?.unsupported != learned.unsupported
    }

    /// Forgets everything read from docs pages (tests).
    func forgetLearned() {
        state.withLock { $0.learned = [:] }
        try? FileManager.default.removeItem(at: learnedURL)
    }

    // MARK: - Shutdown dates

    /// Shutdown dates from GET /models (`shutdown_date`, YYYY-MM-DD) by model ID, kept for the next launch.
    func recordShutdowns(_ dates: [String: String]) {
        state.withLock { $0.shutdowns = dates.compactMapValues(Self.date) }
        defaults.set(dates, forKey: shutdownsKey)
    }

    /// True when the account's model list gives the model a shutdown date within `shutdownWindow`, or a past one.
    func isShuttingDown(_ id: String, now: Date = Date()) -> Bool {
        guard let date = state.withLock({ $0.shutdowns[id] }) else { return false }
        return date.timeIntervalSince(now) <= Self.shutdownWindow
    }

    // MARK: - Built-in list

    /// The list built into this version (Resources/ModelCatalog/ModelCatalog.json). The unit tests check it; if it were
    /// ever unreadable, a one-model list keeps the app working.
    static let builtIn: ModelCatalog = {
        if let url = Bundle.main.url(forResource: "ModelCatalog", withExtension: "json"),
           let data = try? Data(contentsOf: url), let catalog = ModelCatalog.decode(data) {
            return catalog
        }
        log("ModelCatalog.json is missing or invalid; using a one-model list", level: .error)
        return ModelCatalog(schema: ModelCatalog.supportedSchema, revision: 1, updated: "", notes: nil, defaultModel: "gpt-6-sol",
                            current: [.init(id: "gpt-6-sol", summary: "Complex coding and agentic work",
                                            reasoningEfforts: ["none", "low", "medium", "high", "xhigh", "max"], pro: true, asyncTools: false)],
                            earlier: [], retired: [])
    }()

    static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    /// OpenCone's Logger lives on the main actor; the store is used from any thread
    private static func log(_ message: String, level: ProcessingLogEntry.LogLevel) {
        Task { @MainActor in
            Logger.shared.log(level: level, message: message)
        }
    }

    private static func formatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func date(_ text: String) -> Date? { formatter().date(from: String(text.prefix(10))) }
    private static func day(_ date: Date) -> String { formatter().string(from: date) }
}
