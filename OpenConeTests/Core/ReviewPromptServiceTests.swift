import XCTest
@testable import OpenCone

/// Pins when the app asks Apple for a rating. Each rule here, if it drifted, would either waste one of Apple's
/// three sheets a year or skip the people most worth asking.
final class ReviewPromptServiceTests: XCTestCase {

    func testAsksOnTheFirstAnswerWrittenFromTheirIndex() {
        XCTAssertEqual(ReviewPromptService.minimumSourcedAnswers, 1)
        XCTAssertTrue(ask(sourced: true, sourcedAnswers: 1, finishedAnswers: 1))
    }

    func testAsksOnTheThirdFinishedAnswer_evenWithoutPassages() {
        XCTAssertEqual(ReviewPromptService.minimumFinishedAnswers, 3)
        XCTAssertFalse(ask(sourced: false, sourcedAnswers: 0, finishedAnswers: 1))
        XCTAssertFalse(ask(sourced: false, sourcedAnswers: 0, finishedAnswers: 2))
        XCTAssertTrue(ask(sourced: false, sourcedAnswers: 0, finishedAnswers: 3))
    }

    func testAnAnswerWithoutPassages_beforeTheThird_doesNotAsk_evenAfterAnEarlierSourcedOne() {
        // The moment is the answer from their index itself, not a later one that found nothing.
        XCTAssertFalse(ask(sourced: false, sourcedAnswers: 1, finishedAnswers: 2))
    }

    /// Once per app version, as Apple's sample does.
    func testOncePerVersion() {
        XCTAssertFalse(ask(sourced: true, sourcedAnswers: 2, finishedAnswers: 5, lastAskedVersion: "3.2"))
        XCTAssertFalse(
            ask(sourced: true, sourcedAnswers: 2, finishedAnswers: 5, lastAskedVersion: "3.2", daysSince: 400))
        XCTAssertTrue(
            ask(sourced: true, sourcedAnswers: 2, finishedAnswers: 5, lastAskedVersion: "3.1", daysSince: 30))
    }

    /// Human Interface Guidelines: at least a week or two between requests, whatever the version.
    func testNeverWithinFourteenDaysOfTheLastAsk() {
        XCTAssertEqual(ReviewPromptService.minimumDaysBetweenAsks, 14)
        XCTAssertFalse(
            ask(sourced: true, sourcedAnswers: 2, finishedAnswers: 5, lastAskedVersion: "3.1", daysSince: 13.9))
        XCTAssertTrue(
            ask(sourced: true, sourcedAnswers: 2, finishedAnswers: 5, lastAskedVersion: "3.1", daysSince: 14))
    }

    func testNeverUnderTests_orWithoutAVersion() {
        XCTAssertFalse(ask(sourced: true, sourcedAnswers: 1, finishedAnswers: 1, isTesting: true))
        XCTAssertFalse(ask(sourced: false, sourcedAnswers: 0, finishedAnswers: 3, isTesting: true))
        XCTAssertFalse(ask(sourced: true, sourcedAnswers: 1, finishedAnswers: 1, version: ""))
    }

    /// The test host is the app itself: a finished answer in another test must not count or raise the request.
    @MainActor
    func testTheSharedService_countsNothingUnderTests() {
        let before = UserDefaults.standard.integer(forKey: "reviewPrompt.finishedAnswers")
        ReviewPromptService.shared.noteAnswer(sourceCount: 4)
        XCTAssertFalse(ReviewPromptService.shared.wantsPrompt)
        XCTAssertEqual(UserDefaults.standard.integer(forKey: "reviewPrompt.finishedAnswers"), before)
    }

    private func ask(
        sourced: Bool, sourcedAnswers: Int, finishedAnswers: Int, lastAskedVersion: String? = nil,
        version: String = "3.2", daysSince: Double? = nil, isTesting: Bool = false
    ) -> Bool {
        ReviewPromptService.shouldAsk(
            thisAnswerHasSources: sourced, sourcedAnswers: sourcedAnswers, finishedAnswers: finishedAnswers,
            lastAskedVersion: lastAskedVersion, currentVersion: version, daysSinceLastAsk: daysSince,
            isTesting: isTesting)
    }
}
