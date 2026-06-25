import XCTest
@testable import OpenCone

@MainActor
final class OpenAIServiceTests: XCTestCase {

    var service: OpenAIService!

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
        service = OpenAIService(apiKey: "test-api-key")
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        URLProtocol.unregisterClass(MockURLProtocol.self)
        service = nil
        super.tearDown()
    }

    func testGenerateCompletionReturnsFallbackForUnexpectedJSON() async throws {
        // Arrange
        let fallbackString = "This is a fallback string from unexpected JSON"
        let responseData = fallbackString.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: 200,
                                           httpVersion: nil,
                                           headerFields: nil)!
            return (response, responseData)
        }

        // Act
        let result = try await service.generateCompletion(systemPrompt: "sys", userMessage: "user", context: "ctx")

        // Assert
        XCTAssertEqual(result, fallbackString)
    }

    func testGenerateCompletionThrowsForNon200Response() async {
        // Arrange
        let errorJSON = """
        {
            "error": {
                "message": "Model not found",
                "type": "invalid_request_error"
            }
        }
        """
        let errorData = errorJSON.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: 404,
                                           httpVersion: nil,
                                           headerFields: nil)!
            return (response, errorData)
        }

        // Act
        do {
            _ = try await service.generateCompletion(systemPrompt: "sys", userMessage: "user", context: "ctx")
            XCTFail("Expected generateCompletion to throw, but it succeeded")
        } catch let error as APIError {
            // Assert
            switch error {
            case .requestFailed(let statusCode, let message):
                XCTAssertEqual(statusCode, 404)
                XCTAssertEqual(message, "Model not found")
            default:
                XCTFail("Expected requestFailed error, got \(error)")
            }
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }

    func testGenerateCompletionThrowsNoCompletionGenerated() async {
        // Arrange
        // Invalid data that cannot be parsed as ResponsesEnvelope or String fallback
        let invalidData = Data([0x00, 0x01, 0xFF]) // non utf-8 bytes

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: 200,
                                           httpVersion: nil,
                                           headerFields: nil)!
            return (response, invalidData)
        }

        // Act
        do {
            _ = try await service.generateCompletion(systemPrompt: "sys", userMessage: "user", context: "ctx")
            XCTFail("Expected generateCompletion to throw, but it succeeded")
        } catch let error as APIError {
            // Assert
            if case .requestFailed(_, let message) = error {
                XCTAssertTrue(message?.contains("The data isn’t valid") == true || message?.contains("The data could not be read") == true || message?.contains("No completion generated") == true, "Expected No completion generated or data invalid, got \(message ?? "")")
            } else {
                 XCTFail("Expected requestFailed error due to catch, got \(error)")
            }
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }
}
