import XCTest
@testable import OpenCone

@MainActor
final class PineconeURLBuilderTests: XCTestCase {
    
    var service: PineconeService!
    
    override func setUp() {
        super.setUp()
        service = PineconeService(apiKey: "test-api-key", projectId: "test-project-id")
    }
    
    override func tearDown() {
        service = nil
        super.tearDown()
    }
    
    func testBuildURL_ControlPlane() throws {
        // Test control plane URL construction
        let url = try service.buildURL(isControlPlane: true, pathComponents: ["indexes", "test-index"])
        XCTAssertEqual(url.absoluteString, "https://api.pinecone.io/indexes/test-index")
    }
    
    func testBuildURL_DataPlane_NoHostSelected() {
        // Test that it throws when no host is selected
        service.indexHost = nil
        XCTAssertThrowsError(try service.buildURL(isControlPlane: false, pathComponents: ["describe_index_stats"])) { error in
            guard let pineconeError = error as? PineconeError, case .noIndexSelected = pineconeError else {
                XCTFail("Expected noIndexSelected error, got \(error)")
                return
            }
        }
    }
    
    func testBuildURL_DataPlane_ValidHost() throws {
        // Test data plane URL with a normal host
        service.indexHost = "my-index-12345.svc.us-west1-gcp.pinecone.io"
        let url = try service.buildURL(isControlPlane: false, pathComponents: ["query"])
        XCTAssertEqual(url.absoluteString, "https://my-index-12345.svc.us-west1-gcp.pinecone.io/query")
    }
    
    func testBuildURL_DataPlane_HostCleaning() throws {
        // Test that buildURL strips protocol prefixes and trailing paths from indexHost
        let hostsToTest = [
            "https://my-index.svc.pinecone.io",
            "http://my-index.svc.pinecone.io",
            "my-index.svc.pinecone.io/some/path",
            "https://my-index.svc.pinecone.io/extra/stuff"
        ]
        
        for host in hostsToTest {
            service.indexHost = host
            let url = try service.buildURL(isControlPlane: false, pathComponents: ["vectors", "fetch"])
            XCTAssertEqual(url.absoluteString, "https://my-index.svc.pinecone.io/vectors/fetch", "Failed for host: \(host)")
        }
    }
    
    func testBuildURL_WithQueryItems() throws {
        // Test that query items are appended correctly
        service.indexHost = "my-index.svc.pinecone.io"
        let queryItems = [URLQueryItem(name: "limit", value: "100"), URLQueryItem(name: "namespace", value: "test-ns")]
        let url = try service.buildURL(isControlPlane: false, pathComponents: ["namespaces"], queryItems: queryItems)
        
        XCTAssertEqual(url.absoluteString, "https://my-index.svc.pinecone.io/namespaces?limit=100&namespace=test-ns")
    }
    
    func testBuildURL_AdversarialPathComponents() throws {
        service.indexHost = "my-index.svc.pinecone.io"
        
        // Test that adversarial inputs in path components are properly percent-encoded
        let nameWithSpaces = "my index name"
        let url1 = try service.buildURL(isControlPlane: true, pathComponents: ["indexes", nameWithSpaces])
        XCTAssertEqual(url1.absoluteString, "https://api.pinecone.io/indexes/my%20index%20name")
        
        let nameWithSpecialChars = "namespace%name"
        let url2 = try service.buildURL(isControlPlane: false, pathComponents: ["namespaces", nameWithSpecialChars])
        XCTAssertEqual(url2.absoluteString, "https://my-index.svc.pinecone.io/namespaces/namespace%25name")
    }
}
