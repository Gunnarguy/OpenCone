import XCTest
import Foundation
import CryptoKit
@testable import OpenCone

final class DocumentIdentifierBuilderTests: XCTestCase {

    func testMakeIdentifier_isDeterministic() {
        let url = URL(fileURLWithPath: "/path/to/my/Document.pdf")
        let date = Date(timeIntervalSince1970: 1000)

        let id1 = DocumentIdentifierBuilder.makeIdentifier(
            url: url,
            fileSize: 1024,
            creationDate: date,
            modificationDate: date
        )

        let id2 = DocumentIdentifierBuilder.makeIdentifier(
            url: url,
            fileSize: 1024,
            creationDate: date,
            modificationDate: date
        )

        XCTAssertEqual(id1, id2)
        XCTAssertEqual(id1.count, 32)
    }

    func testMakeIdentifier_differsByPath() {
        let url1 = URL(fileURLWithPath: "/path/to/my/doc1.pdf")
        let url2 = URL(fileURLWithPath: "/path/to/my/doc2.pdf")
        let date = Date(timeIntervalSince1970: 1000)

        let id1 = DocumentIdentifierBuilder.makeIdentifier(url: url1, fileSize: 100, creationDate: date, modificationDate: date)
        let id2 = DocumentIdentifierBuilder.makeIdentifier(url: url2, fileSize: 100, creationDate: date, modificationDate: date)

        XCTAssertNotEqual(id1, id2)
    }

    func testMakeIdentifier_pathIsCaseInsensitive() {
        let url1 = URL(fileURLWithPath: "/path/to/my/DOCUMENT.pdf")
        let url2 = URL(fileURLWithPath: "/path/to/my/document.pdf")

        let id1 = DocumentIdentifierBuilder.makeIdentifier(url: url1, fileSize: 100, creationDate: nil, modificationDate: nil)
        let id2 = DocumentIdentifierBuilder.makeIdentifier(url: url2, fileSize: 100, creationDate: nil, modificationDate: nil)

        XCTAssertEqual(id1, id2)
    }

    func testMakeIdentifier_nilDatesEqualZeroEpoch() {
        let url = URL(fileURLWithPath: "/path")
        let zeroDate = Date(timeIntervalSince1970: 0)

        let idNil = DocumentIdentifierBuilder.makeIdentifier(url: url, fileSize: 50, creationDate: nil, modificationDate: nil)
        let idZero = DocumentIdentifierBuilder.makeIdentifier(url: url, fileSize: 50, creationDate: zeroDate, modificationDate: zeroDate)

        XCTAssertEqual(idNil, idZero)
    }

    func testMakeIdentifier_differsBySizeAndDates() {
        let url = URL(fileURLWithPath: "/path")
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)

        let baseId = DocumentIdentifierBuilder.makeIdentifier(url: url, fileSize: 100, creationDate: date1, modificationDate: date1)
        let diffSize = DocumentIdentifierBuilder.makeIdentifier(url: url, fileSize: 101, creationDate: date1, modificationDate: date1)
        let diffCreation = DocumentIdentifierBuilder.makeIdentifier(url: url, fileSize: 100, creationDate: date2, modificationDate: date1)
        let diffMod = DocumentIdentifierBuilder.makeIdentifier(url: url, fileSize: 100, creationDate: date1, modificationDate: date2)

        XCTAssertNotEqual(baseId, diffSize)
        XCTAssertNotEqual(baseId, diffCreation)
        XCTAssertNotEqual(baseId, diffMod)
    }
}
