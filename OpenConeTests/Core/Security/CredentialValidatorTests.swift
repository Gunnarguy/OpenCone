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

    func testValidateOpenAIKey_OversizedResponses() async {
        // 1. Exactly 10,239 bytes - should succeed in decoding
        CredentialValidatorMockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let prefix = "{\"error\":{\"message\":\""
            let suffix = "\"}}"
            let fillSize = 10239 - prefix.count - suffix.count
            let fillString = String(repeating: "A", count: fillSize)
            let data = (prefix + fillString + suffix).data(using: .utf8)!
            XCTAssertEqual(data.count, 10239)
            return (response, data)
        }
        let status1 = await sut.validateOpenAIKey("sk-testkey")
        if case .invalid(let msg) = status1 {
            XCTAssertTrue(msg.starts(with: "AAAA"))
        } else {
            XCTFail("Expected invalid status")
        }

        // 2. Exactly 10,240 bytes - should succeed in decoding
        CredentialValidatorMockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let prefix = "{\"error\":{\"message\":\""
            let suffix = "\"}}"
            let fillSize = 10240 - prefix.count - suffix.count
            let fillString = String(repeating: "B", count: fillSize)
            let data = (prefix + fillString + suffix).data(using: .utf8)!
            XCTAssertEqual(data.count, 10240)
            return (response, data)
        }
        let status2 = await sut.validateOpenAIKey("sk-testkey")
        if case .invalid(let msg) = status2 {
            XCTAssertTrue(msg.starts(with: "BBBB"))
        } else {
            XCTFail("Expected invalid status")
        }

        // 3. Exactly 10,241 bytes - should be rejected as oversized
        CredentialValidatorMockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            let prefix = "{\"error\":{\"message\":\""
            let suffix = "\"}}"
            let fillSize = 10241 - prefix.count - suffix.count
            let fillString = String(repeating: "C", count: fillSize)
            let data = (prefix + fillString + suffix).data(using: .utf8)!
            XCTAssertEqual(data.count, 10241)
            return (response, data)
        }
        let status3 = await sut.validateOpenAIKey("sk-testkey")
        XCTAssertEqual(status3, .invalid(message: "Network error: The server response exceeded the allowed size limit."))
    }
}
