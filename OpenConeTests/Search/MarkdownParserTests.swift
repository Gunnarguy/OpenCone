import XCTest
@testable import OpenCone

/// How an answer's Markdown is split into the blocks the answer view draws
final class MarkdownParserTests: XCTestCase {
    func testHeadingsParagraphsAndRules() {
        let blocks = MarkdownParser.blocks(from: """
        # Title
        Some **bold** text
        on two lines.

        ---

        ### Detail ###
        """)

        XCTAssertEqual(blocks, [
            .heading(level: 1, text: "Title"),
            .paragraph("Some **bold** text\non two lines."),
            .rule,
            .heading(level: 3, text: "Detail"),
        ])
    }

    func testAHashtagIsNotAHeading() {
        XCTAssertEqual(MarkdownParser.blocks(from: "#pumps are great"), [.paragraph("#pumps are great")])
    }

    func testSetextHeadings() {
        XCTAssertEqual(MarkdownParser.blocks(from: "Summary\n======="), [.heading(level: 1, text: "Summary")])
        XCTAssertEqual(MarkdownParser.blocks(from: "Details\n---"), [.heading(level: 2, text: "Details")])
    }

    func testNestedAndOrderedLists() {
        let blocks = MarkdownParser.blocks(from: """
        1. First
        2. Second
           - nested a
             - deeper
           - nested b
        3) Third
        """)

        XCTAssertEqual(blocks, [
            .listItem(ordered: true, marker: "1.", depth: 0, checked: nil, text: "First"),
            .listItem(ordered: true, marker: "2.", depth: 0, checked: nil, text: "Second"),
            .listItem(ordered: false, marker: "•", depth: 1, checked: nil, text: "nested a"),
            .listItem(ordered: false, marker: "•", depth: 2, checked: nil, text: "deeper"),
            .listItem(ordered: false, marker: "•", depth: 1, checked: nil, text: "nested b"),
            .listItem(ordered: true, marker: "3.", depth: 0, checked: nil, text: "Third"),
        ])
    }

    func testTaskItemsAndContinuationLines() {
        let blocks = MarkdownParser.blocks(from: """
        - [x] Done
        - [ ] Open
          still the same item
        - **Bold** start

        After the list.
        """)

        XCTAssertEqual(blocks, [
            .listItem(ordered: false, marker: "•", depth: 0, checked: true, text: "Done"),
            .listItem(ordered: false, marker: "•", depth: 0, checked: false, text: "Open\nstill the same item"),
            .listItem(ordered: false, marker: "•", depth: 0, checked: nil, text: "**Bold** start"),
            .paragraph("After the list."),
        ])
    }

    func testEmphasisAtTheStartOfALineIsNotABullet() {
        XCTAssertEqual(MarkdownParser.blocks(from: "**Note:** check it"), [.paragraph("**Note:** check it")])
        XCTAssertEqual(MarkdownParser.blocks(from: "*italic* start"), [.paragraph("*italic* start")])
    }

    func testCodeFencesKeepTheirTextAndLanguage() {
        let blocks = MarkdownParser.blocks(from: """
        Run this:
        ```swift
        let x = 1
          // indented
        ```
        Done.
        """)

        XCTAssertEqual(blocks, [
            .paragraph("Run this:"),
            .code(language: "swift", text: "let x = 1\n  // indented"),
            .paragraph("Done."),
        ])
    }

    func testAnUnclosedFenceWhileStreamingRunsToTheEnd() {
        let blocks = MarkdownParser.blocks(from: "Text\n```python\nprint(1)\nprint(2")
        XCTAssertEqual(blocks, [
            .paragraph("Text"),
            .code(language: "python", text: "print(1)\nprint(2"),
        ])
    }

    func testAFenceInsideAListItemDropsTheItemsIndent() {
        let blocks = MarkdownParser.blocks(from: """
        1. Install:
           ```bash
           brew install x
           ```
        2. Run it
        """)

        XCTAssertEqual(blocks, [
            .listItem(ordered: true, marker: "1.", depth: 0, checked: nil, text: "Install:"),
            .code(language: "bash", text: "brew install x"),
            .listItem(ordered: true, marker: "2.", depth: 0, checked: nil, text: "Run it"),
        ])
    }

    func testTablesWithAlignmentEscapesAndShortRows() {
        let blocks = MarkdownParser.blocks(from: """
        | Model | Interval | Torque |
        |:------|:--------:|-------:|
        | Baxter | 500 h | 12 Nm |
        | BD \\| Alaris | 750 h |
        Next paragraph
        """)

        XCTAssertEqual(blocks, [
            .table(
                header: ["Model", "Interval", "Torque"],
                alignments: [.leading, .center, .trailing],
                rows: [["Baxter", "500 h", "12 Nm"], ["BD | Alaris", "750 h", ""]]
            ),
            .paragraph("Next paragraph"),
        ])
    }

    func testAPipeInAParagraphIsNotATable() {
        XCTAssertEqual(MarkdownParser.blocks(from: "a | b\nc"), [.paragraph("a | b\nc")])
    }

    func testQuotesJoinTheirLines() {
        XCTAssertEqual(MarkdownParser.blocks(from: "> First\n> second\n\nAfter"), [
            .quote("First\nsecond"),
            .paragraph("After"),
        ])
    }

    func testWindowsLineEndings() {
        XCTAssertEqual(MarkdownParser.blocks(from: "# A\r\nB"), [.heading(level: 1, text: "A"), .paragraph("B")])
    }

    // MARK: - Passage tags

    func testPassageTagsBecomeLinks() {
        XCTAssertEqual(
            MarkdownInline.linkingSourceTags(in: "Filters last 500 hours [S1]."),
            "Filters last 500 hours [\\[S1\\]](opencone-source://S1)."
        )
        XCTAssertEqual(
            MarkdownInline.linkingSourceTags(in: "Both agree [S2, s4]"),
            "Both agree [\\[S2\\]](opencone-source://S2)[\\[S4\\]](opencone-source://S4)"
        )
    }

    func testTagsInCodeOrAlreadyLinkedAreLeftAlone() {
        let code = "Use `array[S1]` here"
        XCTAssertEqual(MarkdownInline.linkingSourceTags(in: code), code)
        let link = "[S1](https://example.com)"
        XCTAssertEqual(MarkdownInline.linkingSourceTags(in: link), link)
        XCTAssertEqual(MarkdownInline.linkingSourceTags(in: "no tags"), "no tags")
    }

    func testALinkedTagRendersAsItsTagAndOpensItsSource() throws {
        let attributed = MarkdownInline.attributed("See [S3].")
        XCTAssertEqual(String(attributed.characters), "See [S3].")

        let link = try XCTUnwrap(attributed.runs.compactMap { $0.attributes[MarkdownInline.LinkKey.self] }.first)
        XCTAssertEqual(MarkdownInline.sourceTag(from: link), "S3")
        XCTAssertNil(MarkdownInline.sourceTag(from: URL(string: "https://example.com")!))
    }

    // MARK: Table columns

    /// A long cell takes the widest column, and wraps inside it; a short one keeps its own width
    func testColumnWidthsFollowTheWidestCellWithinTheLimits() {
        let widths = MarkdownTableView.columnWidths(
            header: ["Index", "Content found"],
            rows: [["`test`", String(repeating: "A 2019 neuroscience article on dopamine signaling. ", count: 4)]]
        )

        XCTAssertGreaterThanOrEqual(widths[0], MarkdownTableView.minColumnWidth)
        XCTAssertLessThan(widths[0], 120)
        XCTAssertEqual(widths[1], MarkdownTableView.maxColumnWidth)
    }

    /// Too wide for the answer: the narrow column keeps its width and the wide one gives way
    func testATableNarrowsItsWidestColumnToFit() {
        // 384 points less 2 x 20 of cell padding and 2 of border leaves 342
        let fitted = MarkdownTableView.fitted([120, 240], into: 384)

        XCTAssertEqual(fitted, [120, 222])
    }

    func testATableThatFitsIsLeftAlone() {
        XCTAssertEqual(MarkdownTableView.fitted([80, 120], into: 384), [80, 120])
        XCTAssertEqual(MarkdownTableView.fitted([80, 120], into: 0), [80, 120], "before the width is measured")
    }

    /// Five columns can't fit 300 points at the minimum width, so they stay at it and the table scrolls
    func testATableTooWideEvenAtTheMinimumScrolls() {
        let fitted = MarkdownTableView.fitted([100, 100, 100, 100, 100], into: 300)

        XCTAssertEqual(fitted, Array(repeating: MarkdownTableView.minColumnWidth, count: 5))
    }
}
