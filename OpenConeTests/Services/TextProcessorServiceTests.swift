import XCTest
@testable import OpenCone

@MainActor
final class TextProcessorServiceTests: XCTestCase {

    var sut: TextProcessorService!

    override func setUp() {
        super.setUp()
        sut = TextProcessorService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testTokenizeText_WithEmptyString_ReturnsEmptyArray() {
        // Arrange
        let text = ""

        // Act
        let tokens = sut.tokenizeText(text)

        // Assert
        XCTAssertTrue(tokens.isEmpty, "Tokens should be empty for an empty string")
    }

    func testTokenizeText_WithSingleWord_ReturnsOneToken() {
        // Arrange
        let text = "Hello"

        // Act
        let tokens = sut.tokenizeText(text)

        // Assert
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens.first?.token, "Hello")

        if let range = tokens.first?.range {
            XCTAssertEqual(range.location, 0)
            XCTAssertEqual(range.length, 5)
        } else {
            XCTFail("Range should not be nil")
        }
    }

    func testTokenizeText_WithMultipleWords_ReturnsMultipleTokens() {
        // Arrange
        let text = "Hello world test"

        // Act
        let tokens = sut.tokenizeText(text)

        // Assert
        XCTAssertEqual(tokens.count, 3)
        XCTAssertEqual(tokens[0].token, "Hello")
        XCTAssertEqual(tokens[1].token, "world")
        XCTAssertEqual(tokens[2].token, "test")

        // Verify ranges
        XCTAssertEqual(tokens[0].range.location, 0)
        XCTAssertEqual(tokens[0].range.length, 5)

        XCTAssertEqual(tokens[1].range.location, 6)
        XCTAssertEqual(tokens[1].range.length, 5)

        XCTAssertEqual(tokens[2].range.location, 12)
        XCTAssertEqual(tokens[2].range.length, 4)
    }

    func testTokenizeText_WithPunctuation_IgnoresPunctuation() {
        // Arrange
        let text = "Hello, world! How are you?"

        // Act
        let tokens = sut.tokenizeText(text)

        // Assert
        XCTAssertEqual(tokens.count, 5)
        XCTAssertEqual(tokens.map { $0.token }, ["Hello", "world", "How", "are", "you"])
    }

    func testTokenizeText_WithEmojisAndSpecialCharacters_HandlesCorrectly() {
        // Arrange
        let text = "Hello 🌍! It's a test-case 😊."

        // Act
        let tokens = sut.tokenizeText(text)

        // Assert
        // NLTokenizer behavior on special characters/punctuation can vary slightly,
        // but it should extract the distinct words.
        let extractedWords = tokens.map { $0.token }
        XCTAssertTrue(extractedWords.contains("Hello"))
        XCTAssertTrue(extractedWords.contains("It's"))
        XCTAssertTrue(extractedWords.contains("a"))
        XCTAssertTrue(extractedWords.contains("test-case") || (extractedWords.contains("test") && extractedWords.contains("case")))
    }

    func testTokenizeText_WithExtraWhitespaces_IgnoresWhitespaces() {
        // Arrange
        let text = "   Hello    world   "

        // Act
        let tokens = sut.tokenizeText(text)

        // Assert
        XCTAssertEqual(tokens.count, 2)
        XCTAssertEqual(tokens[0].token, "Hello")
        XCTAssertEqual(tokens[1].token, "world")
    }
}
