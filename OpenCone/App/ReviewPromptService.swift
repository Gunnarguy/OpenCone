import Combine
import Foundation

/// Asks for an App Store rating with Apple's own sheet, the only way the app asks: stars and an optional written
/// review, sent without leaving the app. The pattern is OpenIntelligence's `ReviewPromptService`.
///
/// When: on the first finished answer that was written from passages found in the person's own Pinecone index (the
/// moment the keys, the index and the search have all worked), or on the third finished answer of any kind,
/// whichever comes first. Once per app version, as Apple's sample does, and never within 14 days of the last ask
/// (Human Interface Guidelines, Ratings and reviews: "a week or two between requests"). Never on launch, never from
/// a button, never under tests or in the screenshot demo.
///
/// Apple shows the sheet at most three times in 365 days on a device, and decides itself whether to show it at all;
/// this decides only when to ask (`RequestReviewAction`, read 2026-11-14 on developer.apple.com and in the iOS 27.0
/// SDK's `_StoreKit_SwiftUI.swiftinterface`: iOS 16.0 and later, `@MainActor func callAsFunction()`).
///
/// Before this the app never asked: on 2026-11-14 it had 200 first-time downloads and 1 US rating.
@MainActor
final class ReviewPromptService: ObservableObject {
    static let shared = ReviewPromptService()

    /// Flipped true when the next good moment arrives; MainView consumes it.
    @Published private(set) var wantsPrompt = false

    private let defaults = UserDefaults.standard
    private let sourcedKey = "reviewPrompt.sourcedAnswers"
    private let finishedKey = "reviewPrompt.finishedAnswers"
    private let lastAskedKey = "reviewPrompt.lastAskedAt"
    private let lastAskedVersionKey = "reviewPrompt.lastAskedVersion"
    nonisolated static let minimumSourcedAnswers = 1
    nonisolated static let minimumFinishedAnswers = 3
    nonisolated static let minimumDaysBetweenAsks = 14.0

    /// Called for every answer that finished with text, with how many passages from the person's indexes it was
    /// written from. Answers that failed or were stopped are not reported.
    func noteAnswer(sourceCount: Int) {
        // Nothing is counted under tests or in the demo, so neither leaves counts behind in UserDefaults.
        guard !isTesting else { return }
        let sourced = sourceCount > 0
        let finished = defaults.integer(forKey: finishedKey) + 1
        defaults.set(finished, forKey: finishedKey)
        var sourcedCount = defaults.integer(forKey: sourcedKey)
        if sourced {
            sourcedCount += 1
            defaults.set(sourcedCount, forKey: sourcedKey)
        }
        let lastAsked = defaults.double(forKey: lastAskedKey)
        guard
            Self.shouldAsk(
                thisAnswerHasSources: sourced, sourcedAnswers: sourcedCount, finishedAnswers: finished,
                lastAskedVersion: defaults.string(forKey: lastAskedVersionKey), currentVersion: Self.currentVersion,
                daysSinceLastAsk: lastAsked > 0 ? (Date().timeIntervalSince1970 - lastAsked) / 86_400 : nil,
                isTesting: isTesting)
        else { return }
        wantsPrompt = true
    }

    /// MainView calls this once it has handed the request to StoreKit.
    func didAsk() {
        defaults.set(Date().timeIntervalSince1970, forKey: lastAskedKey)
        defaults.set(Self.currentVersion, forKey: lastAskedVersionKey)
        wantsPrompt = false
    }

    /// Pure, so every rule above is pinned by a test. Counts include the answer that just finished.
    nonisolated static func shouldAsk(
        thisAnswerHasSources: Bool, sourcedAnswers: Int, finishedAnswers: Int, lastAskedVersion: String?,
        currentVersion: String, daysSinceLastAsk: Double?, isTesting: Bool
    ) -> Bool {
        guard !isTesting, !currentVersion.isEmpty, lastAskedVersion != currentVersion else { return false }
        if let days = daysSinceLastAsk, days < minimumDaysBetweenAsks { return false }
        return (thisAnswerHasSources && sourcedAnswers >= minimumSourcedAnswers)
            || finishedAnswers >= minimumFinishedAnswers
    }

    private static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private var isTesting: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || DemoMode.isActive
    }
}
