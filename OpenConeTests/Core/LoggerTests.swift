import XCTest
@testable import OpenCone

@MainActor
final class LoggerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear logs before each test
        Logger.shared.clearLogs()
        // Clear user defaults for log level to ensure default behavior
        UserDefaults.standard.removeObject(forKey: SettingsStorageKeys.logMinimumLevel)
    }

    override func tearDown() {
        Logger.shared.clearLogs()
        UserDefaults.standard.removeObject(forKey: SettingsStorageKeys.logMinimumLevel)
        super.tearDown()
    }

    func testLogAppendsToEntries() {
        // Arrange
        let logger = Logger.shared
        XCTAssertTrue(logger.logEntries.isEmpty)

        // Act
        logger.log(level: .info, message: "Test info message", context: "TestContext")

        // Assert
        XCTAssertEqual(logger.logEntries.count, 1)

        let firstEntry = logger.logEntries.first
        XCTAssertNotNil(firstEntry)
        XCTAssertEqual(firstEntry?.level, .info)
        XCTAssertEqual(firstEntry?.message, "Test info message")
        XCTAssertEqual(firstEntry?.context, "TestContext")
    }

    func testLogRespectsMinimumLevel() {
        // Arrange
        let logger = Logger.shared
        // Set minimum level to warning
        UserDefaults.standard.set(ProcessingLogEntry.LogLevel.warning.rawValue, forKey: SettingsStorageKeys.logMinimumLevel)

        // Act - this should not be logged (info < warning)
        logger.log(level: .info, message: "Test info message")

        // Assert
        XCTAssertTrue(logger.logEntries.isEmpty)

        // Act - this should be logged (error > warning)
        logger.log(level: .error, message: "Test error message")

        // Assert
        XCTAssertEqual(logger.logEntries.count, 1)
        XCTAssertEqual(logger.logEntries.first?.level, .error)
    }

    func testLogTrimsWhenExceedingMaxEntries() {
        // Arrange
        let logger = Logger.shared

        // Act
        // Generate 1005 entries (maxLogEntries is 1000)
        for i in 0..<1005 {
            logger.log(level: .info, message: "Message \(i)")
        }

        // Assert
        XCTAssertEqual(logger.logEntries.count, 1000)

        // The first element should be "Message 5" since 0-4 were dropped
        XCTAssertEqual(logger.logEntries.first?.message, "Message 5")
        // The last element should be "Message 1004"
        XCTAssertEqual(logger.logEntries.last?.message, "Message 1004")
    }

    func testExportLogs() {
        // Arrange
        let logger = Logger.shared
        logger.log(level: .info, message: "Test export info", context: "ExportCtx")
        logger.log(level: .error, message: "Test export error")

        // Act
        let exportedString = logger.exportLogs()

        // Assert
        XCTAssertTrue(exportedString.contains("OpenCone Logs"))
        XCTAssertTrue(exportedString.contains("[INFO] [ExportCtx]: Test export info"))
        XCTAssertTrue(exportedString.contains("[ERROR]: Test export error"))
    }

    func testSearchLogs() {
        // Arrange
        let logger = Logger.shared
        logger.log(level: .info, message: "Find this message", context: "Context A")
        logger.log(level: .warning, message: "Ignore this one", context: "Context B")
        logger.log(level: .error, message: "Another error", context: "Find context")

        // Act & Assert
        // Search by message content
        let messageResults = logger.search(for: "find this")
        XCTAssertEqual(messageResults.count, 1)
        XCTAssertEqual(messageResults.first?.message, "Find this message")

        // Search by context content
        let contextResults = logger.search(for: "find context")
        XCTAssertEqual(contextResults.count, 1)
        XCTAssertEqual(contextResults.first?.level, .error)

        // Search matching multiple (case-insensitive)
        let multipleResults = logger.search(for: "this")
        XCTAssertEqual(multipleResults.count, 2)

        // Empty search returns all
        let emptyResults = logger.search(for: "")
        XCTAssertEqual(emptyResults.count, 3)
    }
}
