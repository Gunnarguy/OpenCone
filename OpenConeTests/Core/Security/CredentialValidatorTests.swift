import XCTest
@testable import OpenCone

final class CredentialValidatorMockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = CredentialValidatorMockURLProtocol.requestHandler else {
            fatalError("Handler is unavailable.")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

@MainActor
final class CredentialValidatorTests: XCTestCase {

    var sut: CredentialValidator!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CredentialValidatorMockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        sut = CredentialValidator(session: session)
    }

    override func tearDown() {
        CredentialValidatorMockURLProtocol.requestHandler = nil
        sut = nil
        super.tearDown()
    }

    func testValidateOpenAIKey_EmptyKey_ReturnsInvalid() async {
        let status = await sut.validateOpenAIKey("   ")
        XCTAssertEqual(status, .invalid(message: "API key is empty"))
    }

    func testValidateOpenAIKey_Success_ReturnsValid() async {
        CredentialValidatorMockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let status = await sut.validateOpenAIKey("sk-testkey")
        XCTAssertEqual(status, .valid)
    }

    func testValidateOpenAIKey_Unauthorized_ReturnsInvalid() async {
        CredentialValidatorMockURLProtocol.requestHandler = { request in
            let json = """
            {
                "error": {
                    "message": "Incorrect API key provided"
                }
            }
            """
            let data = json.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let status = await sut.validateOpenAIKey("sk-testkey")
        XCTAssertEqual(status, .invalid(message: "Incorrect API key provided"))
    }

    func testValidateOpenAIKey_RateLimited_ReturnsRateLimited() async {
        CredentialValidatorMockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: ["retry-after": "15"])!
            return (response, Data())
        }

        let status = await sut.validateOpenAIKey("sk-testkey")
        XCTAssertEqual(status, .rateLimited(retryAfterSeconds: 15))
    }

    func testValidateOpenAIKey_NetworkError_ReturnsInvalid() async {
        CredentialValidatorMockURLProtocol.requestHandler = { _ in
            throw NSError(domain: "TestError", code: -1001, userInfo: [NSLocalizedDescriptionKey: "The request timed out."])
        }

        let status = await sut.validateOpenAIKey("sk-testkey")
        XCTAssertEqual(status, .invalid(message: "Network error: The request timed out."))
    }

    func testValidateOpenAIKey_LargePayload_RejectsDecoding() async {
        CredentialValidatorMockURLProtocol.requestHandler = { request in
            // Create a payload larger than 10KB
            let largeString = String(repeating: "A", count: 15000)
            let json = "{\"error\": {\"message\": \"\(largeString)\"}}"
            let data = json.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let status = await sut.validateOpenAIKey("sk-testkey")
        // Since decoding fails, it falls back to the generic unauthorized message
        XCTAssertEqual(status, .invalid(message: "Unauthorized: Invalid API key"))
    }
}
