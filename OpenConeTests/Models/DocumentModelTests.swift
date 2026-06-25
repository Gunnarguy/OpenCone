import XCTest
@testable import OpenCone

final class DocumentModelTests: XCTestCase {

    func testDocumentModelEquality() {
        let id1 = UUID()
        let id2 = UUID()

        let url = URL(fileURLWithPath: "/test/path.pdf")

        let doc1 = DocumentModel(id: id1, documentId: "doc1", fileName: "test1.pdf", filePath: url, mimeType: "application/pdf", fileSize: 100, dateAdded: Date())
        let doc2 = DocumentModel(id: id1, documentId: "doc2", fileName: "test2.pdf", filePath: url, mimeType: "application/pdf", fileSize: 200, dateAdded: Date())
        let doc3 = DocumentModel(id: id2, documentId: "doc1", fileName: "test1.pdf", filePath: url, mimeType: "application/pdf", fileSize: 100, dateAdded: Date())

        // Equality is based solely on id
        XCTAssertEqual(doc1, doc2)
        XCTAssertNotEqual(doc1, doc3)
        XCTAssertNotEqual(doc2, doc3)
    }

    func testDocumentModelHashing() {
        let id1 = UUID()

        let url = URL(fileURLWithPath: "/test/path.pdf")

        let doc1 = DocumentModel(id: id1, documentId: "doc1", fileName: "test1.pdf", filePath: url, mimeType: "application/pdf", fileSize: 100, dateAdded: Date())
        let doc2 = DocumentModel(id: id1, documentId: "doc2", fileName: "test2.pdf", filePath: url, mimeType: "application/pdf", fileSize: 200, dateAdded: Date())

        var hasher1 = Hasher()
        doc1.hash(into: &hasher1)

        var hasher2 = Hasher()
        doc2.hash(into: &hasher2)

        XCTAssertEqual(hasher1.finalize(), hasher2.finalize())
    }

    func testChunkModelCodable() throws {
        let metadata = ChunkMetadata(source: "test.pdf", chunkIndex: 0, totalChunks: 1, mimeType: "application/pdf")
        let chunk = ChunkModel(content: "Test content", sourceDocument: "test.pdf", metadata: metadata, contentHash: "hash123", tokenCount: 10)

        let encoder = JSONEncoder()
        let data = try encoder.encode(chunk)

        let decoder = JSONDecoder()
        let decodedChunk = try decoder.decode(ChunkModel.self, from: data)

        XCTAssertEqual(chunk.id, decodedChunk.id)
        XCTAssertEqual(chunk.content, decodedChunk.content)
        XCTAssertEqual(chunk.sourceDocument, decodedChunk.sourceDocument)
        XCTAssertEqual(chunk.contentHash, decodedChunk.contentHash)
        XCTAssertEqual(chunk.tokenCount, decodedChunk.tokenCount)
    }

    func testChunkMetadataDocumentIdConvenienceAccessor() {
        var metadata = ChunkMetadata(source: "test.pdf", chunkIndex: 0, totalChunks: 1, mimeType: "application/pdf")
        XCTAssertNil(metadata.documentId)

        metadata.additionalMetadata = ["documentId": "doc123"]
        XCTAssertEqual(metadata.documentId, "doc123")
    }

    func testDocumentProcessingStats() throws {
        var stats = DocumentProcessingStats()
        stats.startTime = Date(timeIntervalSince1970: 0)
        stats.endTime = Date(timeIntervalSince1970: 10)

        XCTAssertEqual(stats.totalProcessingTime, 10)

        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 2)
        stats.addPhase(phase: .textExtraction, start: start, end: end)

        XCTAssertEqual(stats.textExtractionTime, 2)
        XCTAssertEqual(stats.phaseTimings.count, 1)
        XCTAssertEqual(stats.phaseTimings[0].phase, .textExtraction)
        XCTAssertEqual(stats.phaseTimings[0].duration, 2)

        let encoder = JSONEncoder()
        let data = try encoder.encode(stats)

        let decoder = JSONDecoder()
        let decodedStats = try decoder.decode(DocumentProcessingStats.self, from: data)

        XCTAssertEqual(decodedStats.textExtractionTime, 2)
        XCTAssertEqual(decodedStats.phaseTimings.count, 1)
        XCTAssertEqual(decodedStats.phaseTimings[0].phase, .textExtraction)
    }
}
