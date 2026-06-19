import XCTest
@testable import OpenCone

final class DocumentFileUtilitiesTests: XCTestCase {

    func testSanitizeFilename_noDisallowedCharacters_returnsOriginalString() {
        let original = "ValidFileName123.txt"
        let sanitized = DocumentFileUtilities.sanitizeFilename(original)
        XCTAssertEqual(sanitized, original)
    }

    func testSanitizeFilename_withDisallowedCharacters_replacesWithUnderscore() {
        let original = "File/Name\\With?Invalid%Chars*|.txt"
        let expected = "File_Name_With_Invalid_Chars__.txt"
        let sanitized = DocumentFileUtilities.sanitizeFilename(original)
        XCTAssertEqual(sanitized, expected)

        let originalQuotes = "File\"<>.txt"
        let expectedQuotes = "File___.txt"
        XCTAssertEqual(DocumentFileUtilities.sanitizeFilename(originalQuotes), expectedQuotes)
    }

    func testSanitizeFilename_onlyDisallowedCharacters_replacesAllWithUnderscore() {
        let original = "/\\?%*|\"<>"
        let expected = "_________"
        let sanitized = DocumentFileUtilities.sanitizeFilename(original)
        XCTAssertEqual(sanitized, expected)
    }

    func testSanitizeFilename_emptyString_returnsEmptyString() {
        let original = ""
        let sanitized = DocumentFileUtilities.sanitizeFilename(original)
        XCTAssertEqual(sanitized, original)
    }
}
