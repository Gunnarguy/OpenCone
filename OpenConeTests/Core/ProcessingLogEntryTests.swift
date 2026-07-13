import XCTest
import SwiftUI
@testable import OpenCone

final class ProcessingLogEntryTests: XCTestCase {

    func testLogLevelColorWithoutTheme() {
        XCTAssertEqual(ProcessingLogEntry.LogLevel.debug.color(for: nil), .gray)
        XCTAssertEqual(ProcessingLogEntry.LogLevel.info.color(for: nil), .blue)
        XCTAssertEqual(ProcessingLogEntry.LogLevel.warning.color(for: nil), .orange)
        XCTAssertEqual(ProcessingLogEntry.LogLevel.error.color(for: nil), .red)
        XCTAssertEqual(ProcessingLogEntry.LogLevel.success.color(for: nil), .green)
    }

    func testLogLevelColorWithTheme() {
        let theme = OCTheme.forest

        XCTAssertEqual(ProcessingLogEntry.LogLevel.debug.color(for: theme), .gray)
        XCTAssertEqual(ProcessingLogEntry.LogLevel.info.color(for: theme), theme.primaryColor)
        XCTAssertEqual(ProcessingLogEntry.LogLevel.warning.color(for: theme), .orange)
        XCTAssertEqual(ProcessingLogEntry.LogLevel.error.color(for: theme), theme.errorColor)
        XCTAssertEqual(ProcessingLogEntry.LogLevel.success.color(for: theme), .green)
    }

    func testLegacyColorProperty() {
        let debugColor: Color = ProcessingLogEntry.LogLevel.debug.color
        XCTAssertEqual(debugColor, .gray)

        let infoColor: Color = ProcessingLogEntry.LogLevel.info.color
        XCTAssertEqual(infoColor, .blue)

        let warningColor: Color = ProcessingLogEntry.LogLevel.warning.color
        XCTAssertEqual(warningColor, .orange)

        let errorColor: Color = ProcessingLogEntry.LogLevel.error.color
        XCTAssertEqual(errorColor, .red)

        let successColor: Color = ProcessingLogEntry.LogLevel.success.color
        XCTAssertEqual(successColor, .green)
    }
}
