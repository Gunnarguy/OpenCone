import XCTest
@testable import OpenCone


@MainActor
final class CredentialValidatorTests: XCTestCase {

    var sut: CredentialValidator!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        sut = CredentialValidator(session: session)
    }

    override func tearDown() {
        MockURLProtocol.reset()
        sut = nil
        super.tearDown()
    }

    func testValidateOpenAIKey_EmptyKey_ReturnsInvalid() async {
        let status = await sut.validateOpenAIKey("   ")
        XCTAssertEqual(status, .invalid(message: "API key is empty"))
    }

    func testValidateOpenAIKey_Success_ReturnsValid() async {
        MockURLProtocol.mockResponse = HTTPURLResponse(url: URL(string: "https://api.openai.com/v1/models")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        MockURLProtocol.mockData = Data()

        let status = await sut.validateOpenAIKey("sk-testkey")
        XCTAssertEqual(status, .valid)
    }

    func testValidateOpenAIKey_Unauthorized_ReturnsInvalid() async {
        MockURLProtocol.mockResponse = HTTPURLResponse(url: URL(string: "https://api.openai.com/v1/models")!, statusCode: 401, httpVersion: nil, headerFields: nil)!
        let json = """
        {
            "error": {
                "message": "Incorrect API key provided"
            }
        }
        """
        MockURLProtocol.mockData = json.data(using: .utf8)!

        let status = await sut.validateOpenAIKey("sk-testkey")
        XCTAssertEqual(status, .invalid(message: "Incorrect API key provided"))
    }

    func testValidateOpenAIKey_RateLimited_ReturnsRateLimited() async {
        MockURLProtocol.mockResponse = HTTPURLResponse(url: URL(string: "https://api.openai.com/v1/models")!, statusCode: 429, httpVersion: nil, headerFields: ["retry-after": "15"])!
        MockURLProtocol.mockData = Data()

        let status = await sut.validateOpenAIKey("sk-testkey")
        XCTAssertEqual(status, .rateLimited(retryAfterSeconds: 15))
    }

    func testValidateOpenAIKey_NetworkError_ReturnsInvalid() async {
        MockURLProtocol.mockError = NSError(domain: "TestError", code: -1001, userInfo: [NSLocalizedDescriptionKey: "The request timed out."])

        let status = await sut.validateOpenAIKey("sk-testkey")
        XCTAssertEqual(status, .invalid(message: "Network error: The request timed out."))
    }
}
