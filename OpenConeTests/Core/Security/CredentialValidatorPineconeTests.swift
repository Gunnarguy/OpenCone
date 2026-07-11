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

    func testValidatePinecone_oversizedResponses() async {
        let url = URL(string: "https://api.pinecone.io/indexes")!
        MockURLProtocol.mockResponse = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)

        // 1. Exactly 10,239 bytes - should decode successfully
        let prefix = "{\"message\":\""
        let suffix = "\"}"
        let fillSize = 10239 - prefix.count - suffix.count
        let fillString = String(repeating: "D", count: fillSize)
        MockURLProtocol.mockData = (prefix + fillString + suffix).data(using: .utf8)!
        XCTAssertEqual(MockURLProtocol.mockData?.count, 10239)

        let status1 = await validator.validatePinecone(apiKey: "pcsk_invalid", projectId: "test-proj")
        if case .invalid(let msg) = status1 {
            XCTAssertTrue(msg.starts(with: "DDDD"))
        } else {
            XCTFail("Expected invalid status")
        }

        // 2. Exactly 10,240 bytes - should decode successfully
        let fillSize2 = 10240 - prefix.count - suffix.count
        let fillString2 = String(repeating: "E", count: fillSize2)
        MockURLProtocol.mockData = (prefix + fillString2 + suffix).data(using: .utf8)!
        XCTAssertEqual(MockURLProtocol.mockData?.count, 10240)

        let status2 = await validator.validatePinecone(apiKey: "pcsk_invalid", projectId: "test-proj")
        if case .invalid(let msg) = status2 {
            XCTAssertTrue(msg.starts(with: "EEEE"))
        } else {
            XCTFail("Expected invalid status")
        }

        // 3. Exactly 10,241 bytes - should be rejected as oversized
        let fillSize3 = 10241 - prefix.count - suffix.count
        let fillString3 = String(repeating: "F", count: fillSize3)
        MockURLProtocol.mockData = (prefix + fillString3 + suffix).data(using: .utf8)!
        XCTAssertEqual(MockURLProtocol.mockData?.count, 10241)

        let status3 = await validator.validatePinecone(apiKey: "pcsk_invalid", projectId: "test-proj")
        XCTAssertEqual(status3, .invalid(message: "Network error: The server response exceeded the allowed size limit."))
    }
}
