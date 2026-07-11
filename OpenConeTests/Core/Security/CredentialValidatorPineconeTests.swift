import XCTest
@testable import OpenCone

final class CredentialValidatorPineconeTests: XCTestCase {
    private var validator: CredentialValidator!
    private var session: URLSession!

    override func setUp() {
        super.setUp()

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)

        validator = CredentialValidator(session: session)
        MockURLProtocol.reset()
    }

    override func tearDown() {
        validator = nil
        session = nil
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testValidatePinecone_emptyAPIKey_returnsInvalid() async {
        let status = await validator.validatePinecone(apiKey: "", projectId: "test-proj")
        XCTAssertEqual(status, .invalid(message: "Pinecone API key is empty"))
    }

    func testValidatePinecone_emptyProjectID_returnsInvalid() async {
        let status = await validator.validatePinecone(apiKey: "pcsk_test", projectId: "   ")
        XCTAssertEqual(status, .invalid(message: "Pinecone Project ID is required"))
    }

    func testValidatePinecone_success_returnsValid() async {
        let url = URL(string: "https://api.pinecone.io/indexes")!
        MockURLProtocol.mockResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        MockURLProtocol.mockData = Data()

        let status = await validator.validatePinecone(apiKey: "pcsk_test", projectId: "test-proj")
        XCTAssertEqual(status, .valid)
    }

    func testValidatePinecone_unauthorized_returnsInvalid() async {
        let url = URL(string: "https://api.pinecone.io/indexes")!
        MockURLProtocol.mockResponse = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)

        let errorJson = """
        {
            "message": "Invalid API key"
        }
        """
        MockURLProtocol.mockData = Data(errorJson.utf8)

        let status = await validator.validatePinecone(apiKey: "pcsk_invalid", projectId: "test-proj")
        XCTAssertEqual(status, .invalid(message: "Invalid API key"))
    }

    func testValidatePinecone_rateLimited_returnsRateLimited() async {
        let url = URL(string: "https://api.pinecone.io/indexes")!
        MockURLProtocol.mockResponse = HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: nil)
        MockURLProtocol.mockData = Data()

        let status = await validator.validatePinecone(apiKey: "pcsk_test", projectId: "test-proj")
        XCTAssertEqual(status, .rateLimited(retryAfterSeconds: 30))
    }

    func testValidatePinecone_networkError_returnsInvalid() async {
        MockURLProtocol.mockError = NSError(domain: "NetworkError", code: -1009, userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."])

        let status = await validator.validatePinecone(apiKey: "pcsk_test", projectId: "test-proj")
        XCTAssertEqual(status, .invalid(message: "Network error: The Internet connection appears to be offline."))
    }

    func testValidatePinecone_largePayload_returnsInvalid() async {
        let url = URL(string: "https://api.pinecone.io/indexes")!
        MockURLProtocol.mockResponse = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)

        // Create a payload larger than 10KB
        MockURLProtocol.mockData = Data(repeating: 0x20, count: 11 * 1024)

        let status = await validator.validatePinecone(apiKey: "pcsk_invalid", projectId: "test-proj")
        XCTAssertEqual(status, .invalid(message: "Unauthorized: Invalid API key or Project ID"))
    }
}
