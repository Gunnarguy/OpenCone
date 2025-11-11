import XCTest
@testable import OpenCone

final class SearchViewModelMetadataPersistenceTests: XCTestCase {
    private var originalPresetData: Data?
    private let presetsKey = SettingsStorageKeys.searchMetadataPresets

    override func setUp() {
        super.setUp()
        originalPresetData = UserDefaults.standard.data(forKey: presetsKey)
        UserDefaults.standard.removeObject(forKey: presetsKey)
    }

    override func tearDown() {
        if let data = originalPresetData {
            UserDefaults.standard.set(data, forKey: presetsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: presetsKey)
        }
        super.tearDown()
    }

    func testLoadsMetadataFiltersFromStoredPresets() throws {
        let presets = [
            SettingsMetadataPreset(field: "doc_id", rawValue: "Policy.pdf"),
            SettingsMetadataPreset(field: "year", rawValue: ">=2024")
        ]
        let data = try JSONEncoder().encode(presets)
        UserDefaults.standard.set(data, forKey: presetsKey)

        let sut = makeSUT()

        XCTAssertEqual(sut.metadataFilters["doc_id"], .stringEquals("Policy.pdf"))
        XCTAssertEqual(sut.metadataFilters["year"], .numberRange(min: 2024, max: nil))
        XCTAssertEqual(sut.metadataFilters.count, 2)
    }

    func testSkipsInvalidPresetsAndKeepsValidOnes() throws {
        let presets = [
            SettingsMetadataPreset(field: "   ", rawValue: "2024"),
            SettingsMetadataPreset(field: "region", rawValue: "   "),
            SettingsMetadataPreset(field: "status", rawValue: "approved")
        ]
        let data = try JSONEncoder().encode(presets)
        UserDefaults.standard.set(data, forKey: presetsKey)

        let sut = makeSUT()

        XCTAssertEqual(sut.metadataFilters.count, 1)
        XCTAssertEqual(sut.metadataFilters["status"], .stringEquals("approved"))
        XCTAssertNil(sut.metadataFilters["region"])
    }

    func testHandlesCorruptedPresetPayloadGracefully() {
        UserDefaults.standard.set(Data("not-json".utf8), forKey: presetsKey)

        let sut = makeSUT()

        XCTAssertTrue(sut.metadataFilters.isEmpty)
    }

    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> SearchViewModel {
        let openAIService = OpenAIService(apiKey: "test")
        let embeddingService = EmbeddingService(openAIService: openAIService)
        let pineconeService = PineconeService(apiKey: "test", projectId: "test")
        let sut = SearchViewModel(
            pineconeService: pineconeService,
            openAIService: openAIService,
            embeddingService: embeddingService
        )
        return sut
    }
}
