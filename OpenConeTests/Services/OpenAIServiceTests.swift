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

    func testGenerateCompletionAddsStableCacheKeyOnlyForLargeReusablePrefix() async throws {
        var requestBodies: [[String: Any]] = []
        let responseData = #"{"output_text":"ok"}"#.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let body: Data
            if let httpBody = request.httpBody {
                body = httpBody
            } else {
                let stream = try XCTUnwrap(request.httpBodyStream)
                stream.open()
                defer { stream.close() }
                var streamedBody = Data()
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
                defer { buffer.deallocate() }
                while stream.hasBytesAvailable {
                    let count = stream.read(buffer, maxLength: 4096)
                    if count < 0 {
                        throw try XCTUnwrap(stream.streamError)
                    }
                    if count == 0 { break }
                    streamedBody.append(buffer, count: count)
                }
                body = streamedBody
            }
            requestBodies.append(try JSONSerialization.jsonObject(with: body) as! [String: Any])
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: 200,
                                           httpVersion: nil,
                                           headerFields: nil)!
            return (response, responseData)
        }

        _ = try await service.generateCompletion(systemPrompt: "system", userMessage: "first", context: String(repeating: "a", count: 5000))
        _ = try await service.generateCompletion(systemPrompt: "system", userMessage: "second", context: String(repeating: "a", count: 5000))
        _ = try await service.generateCompletion(systemPrompt: "system", userMessage: "third", context: "short")

        let firstKey = try XCTUnwrap(requestBodies[0]["prompt_cache_key"] as? String)
        XCTAssertEqual(firstKey, requestBodies[1]["prompt_cache_key"] as? String)
        XCTAssertTrue(firstKey.hasPrefix("opencone:rag:v1:"))
        XCTAssertNil(requestBodies[2]["prompt_cache_key"])
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
        } catch {
            print(">>> THROWN ERROR: \(error)")
            if let apiError = error as? APIError {
                switch apiError {
                case .requestFailed(let statusCode, let message):
                    XCTAssertEqual(statusCode, 404)
                    XCTAssertEqual(message, "Model not found")
                default:
                    XCTFail("Expected requestFailed error, got \(apiError)")
                }
            } else {
                XCTFail("Expected APIError, got \(error)")
            }
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
            if case .noCompletionGenerated = error {
                // Success
            } else {
                 XCTFail("Expected noCompletionGenerated error, got \(error)")
            }
        } catch {
            XCTFail("Expected APIError, got \(error)")
        }
    }
}
