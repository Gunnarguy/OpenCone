import XCTest
@testable import OpenCone

}

@MainActor
final class PineconeServiceHealthCheckTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
        // Reset UserDefaults state if necessary for clean tests
        UserDefaults.standard.removeObject(forKey: "pinecone.cachedIndexList")
        UserDefaults.standard.removeObject(forKey: "pineconeCloud")
        UserDefaults.standard.removeObject(forKey: "pineconeRegion")
    }

    override func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testHealthCheck_NoIndexSelected() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let sut = PineconeService(apiKey: "test", projectId: "test", sessionConfiguration: config)
        // indexHost and currentIndex are nil by default

        let result = await sut.healthCheck()

        XCTAssertFalse(result)
        XCTAssertFalse(sut.isCircuitOpen)
    }

    func testHealthCheck_Success() async throws {

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let sut = PineconeService(apiKey: "test", projectId: "test", sessionConfiguration: config)

        // Setup handler to mock the index describe response so indexHost is set
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            if request.url?.absoluteString.contains("/indexes/") == true {
                let json = """
                {
                    "name": "test-index",
                    "host": "test-index.pinecone.io",
                    "metric": "cosine",
                    "dimension": 1536,
                    "status": {
                        "state": "Ready",
                        "ready": true
                    }
                }
                """
                return (response, json.data(using: .utf8)!)
            }
            if request.url?.absoluteString.contains("/describe_index_stats") == true {
                let json = """
                {
                    "namespaces": {},
                    "dimension": 1536,
                    "status": {
                        "state": "Ready",
                        "ready": true
                    },
                    "indexFullness": 0,
                    "totalVectorCount": 0
                }
                """
                return (response, json.data(using: .utf8)!)
            }
            return (response, Data())
        }


        // First set current index
        try await sut.setCurrentIndex("test-index")

        let result = await sut.healthCheck()

        XCTAssertTrue(result)
        XCTAssertFalse(sut.isCircuitOpen)
    }

    func testHealthCheck_ServerError() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let sut = PineconeService(apiKey: "test", projectId: "test", sessionConfiguration: config)

        MockURLProtocol.requestHandler = { request in
            if request.url?.absoluteString.contains("/indexes/") == true {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let json = """
                {
                    "name": "test-index",
                    "host": "test-index.pinecone.io",
                    "metric": "cosine",
                    "dimension": 1536,
                    "status": {
                        "state": "Ready",
                        "ready": true
                    }
                }
                """
                return (response, json.data(using: .utf8)!)
            }
            if request.url?.absoluteString.contains("/describe_index_stats") == true {
                let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        // Set index
        try await sut.setCurrentIndex("test-index")

        // Need to hit health failure threshold to open circuit
        // threshold is 2 according to PineconeService code
        let result1 = await sut.healthCheck()
        XCTAssertFalse(result1)
        XCTAssertFalse(sut.isCircuitOpen) // threshold not reached yet (1 failure)

        let result2 = await sut.healthCheck()
        XCTAssertFalse(result2)
        XCTAssertTrue(sut.isCircuitOpen) // threshold reached (2 failures)
    }

    func testHealthCheck_CircuitOpen() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let sut = PineconeService(apiKey: "test", projectId: "test", sessionConfiguration: config)

        MockURLProtocol.requestHandler = { request in
            if request.url?.absoluteString.contains("/indexes/") == true {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                let json = """
                {
                    "name": "test-index",
                    "host": "test-index.pinecone.io",
                    "metric": "cosine",
                    "dimension": 1536,
                    "status": {
                        "state": "Ready",
                        "ready": true
                    }
                }
                """
                return (response, json.data(using: .utf8)!)
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        try await sut.setCurrentIndex("test-index")

        // Trigger 2 failures to open circuit
        _ = await sut.healthCheck()
        _ = await sut.healthCheck()

        XCTAssertTrue(sut.isCircuitOpen)

        // Change handler to return 200, but health check should still fail fast because circuit is open
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let result = await sut.healthCheck()

        XCTAssertFalse(result) // Failed fast
        XCTAssertTrue(sut.isCircuitOpen) // Circuit still open
    }
}
