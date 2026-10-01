import SwiftUI
import UIKit

// MARK: - Parsing

/// One block of an answer, parsed from the Markdown the model writes
enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    /// `marker` is the literal number for an ordered item ("3."), "•" otherwise. `checked` is set for
    /// a task item, "- [ ]" or "- [x]".
    case listItem(ordered: Bool, marker: String, depth: Int, checked: Bool?, text: String)
    case code(language: String?, text: String)
    case quote(String)
    case table(header: [String], alignments: [MarkdownTableAlignment], rows: [[String]])
    case rule
}

enum MarkdownTableAlignment: Equatable {
    case leading
    case center
    case trailing
}

/// Splits an answer into blocks. Block structure is parsed here because `AttributedString`'s
/// Markdown parser keeps headings, lists, tables and code blocks only as presentation intents,
/// which `Text` doesn't draw; each block's inline Markdown goes through `MarkdownInline`.
/// Answers arrive a few characters at a time, so an unclosed code fence is a code block running
/// to the end, not an error.
enum MarkdownParser {
    static func blocks(from markdown: String) -> [MarkdownBlock] {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")

        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        // Indentation of each open list level, outermost first
        var listIndents: [Int] = []
        var previousLineWasBlank = false
        var index = 0

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: "\n")))
            paragraph = []
        }

        func endList() {
            listIndents = []
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let indent = indentWidth(of: line)

            if trimmed.isEmpty {
                flushParagraph()
                previousLineWasBlank = true
                index += 1
                continue
            }
            defer { previousLineWasBlank = false }

            // Fenced code, also inside list items, where models indent it
            if let fence = fenceOpening(trimmed) {
                flushParagraph()
                var code: [String] = []
                index += 1
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    if isFenceClosing(candidate, opening: fence.marker) {
                        index += 1
                        break
                    }
                    code.append(removingIndent(indent, from: lines[index]))
                    index += 1
                }
                blocks.append(.code(language: fence.language, text: code.joined(separator: "\n")))
                if indent == 0 { endList() }
                continue
            }

            if let heading = heading(in: trimmed), indent < 4 {
                flushParagraph()
                endList()
                blocks.append(.heading(level: heading.level, text: heading.text))
                index += 1
                continue
            }

            // A line of = or - under a paragraph makes it a heading (setext); on its own, - - - is a rule
            if !paragraph.isEmpty, indent < 4, let level = setextLevel(trimmed) {
                let text = paragraph.joined(separator: "\n")
                paragraph = []
                blocks.append(.heading(level: level, text: text))
                index += 1
                continue
            }

            if isRule(trimmed), indent < 4 {
                flushParagraph()
                endList()
                blocks.append(.rule)
                index += 1
                continue
            }

            if trimmed.contains("|"), index + 1 < lines.count, let alignments = tableAlignments(lines[index + 1]) {
                let header = tableCells(trimmed)
                if header.count == alignments.count {
                    flushParagraph()
                    endList()
                    var rows: [[String]] = []
                    index += 2
                    while index < lines.count {
                        let rowLine = lines[index].trimmingCharacters(in: .whitespaces)
                        guard !rowLine.isEmpty, rowLine.contains("|") else { break }
                        var cells = tableCells(rowLine)
                        if cells.count < header.count {
                            cells += Array(repeating: "", count: header.count - cells.count)
                        }
                        rows.append(Array(cells.prefix(header.count)))
                        index += 1
                    }
                    blocks.append(.table(header: header, alignments: alignments, rows: rows))
                    continue
                }
            }

            if trimmed.hasPrefix(">") {
                flushParagraph()
                endList()
                var quoted: [String] = []
                while index < lines.count {
                    let quoteLine = lines[index].trimmingCharacters(in: .whitespaces)
                    guard quoteLine.hasPrefix(">") else { break }
                    var content = quoteLine.drop(while: { $0 == ">" })
                    if content.first == " " { content = content.dropFirst() }
                    quoted.append(String(content))
                    index += 1
                }
                blocks.append(.quote(quoted.joined(separator: "\n")))
                continue
            }

            if let item = listItem(in: line) {
                flushParagraph()
                let depth = listDepth(for: item.indent, levels: &listIndents)
                blocks.append(.listItem(
                    ordered: item.ordered,
                    marker: item.marker,
                    depth: depth,
                    checked: item.checked,
                    text: item.text
                ))
                index += 1
                continue
            }

            // A line under a list item continues it when indented, or when it follows straight on
            if !listIndents.isEmpty, paragraph.isEmpty, indent > 0 || !previousLineWasBlank,
               case let .listItem(ordered, marker, depth, checked, text)? = blocks.last {
                blocks[blocks.count - 1] = .listItem(
                    ordered: ordered,
                    marker: marker,
                    depth: depth,
                    checked: checked,
                    text: text + "\n" + trimmed
                )
                index += 1
                continue
            }

            endList()
            paragraph.append(trimmed)
            index += 1
        }

        flushParagraph()
        return blocks
    }

    // MARK: Lines

    /// Spaces before the first character, a tab counting as four
    static func indentWidth(of line: String) -> Int {
        var width = 0
        for character in line {
            if character == " " {
                width += 1
            } else if character == "\t" {
                width += 4
            } else {
                break
            }
        }
        return width
    }

    private static func removingIndent(_ indent: Int, from line: String) -> String {
        var removed = 0
        var rest = Substring(line)
        while removed < indent, let first = rest.first, first == " " || first == "\t" {
            removed += first == "\t" ? 4 : 1
            rest = rest.dropFirst()
        }
        return String(rest)
    }

    private static func fenceOpening(_ trimmed: String) -> (marker: String, language: String?)? {
        for fenceCharacter in ["`", "~"] {
            let run = trimmed.prefix(while: { String($0) == fenceCharacter })
            guard run.count >= 3 else { continue }
            let info = trimmed.dropFirst(run.count).trimmingCharacters(in: .whitespaces)
            // A backtick fence's info string can't hold a backtick; that line is inline code
            if fenceCharacter == "`", info.contains("`") { return nil }
            let language = info.split(separator: " ").first.map(String.init)
            return (String(run), language?.isEmpty == false ? language : nil)
        }
        return nil
    }

    private static func isFenceClosing(_ trimmed: String, opening marker: String) -> Bool {
        guard let fenceCharacter = marker.first, trimmed.count >= marker.count else { return false }
        return trimmed.allSatisfy { $0 == fenceCharacter }
    }

    private static func heading(in trimmed: String) -> (level: Int, text: String)? {
        let hashes = trimmed.prefix(while: { $0 == "#" })
        guard (1...6).contains(hashes.count) else { return nil }
        let rest = trimmed.dropFirst(hashes.count)
        guard rest.isEmpty || rest.first == " " || rest.first == "\t" else { return nil }
        var text = rest.trimmingCharacters(in: .whitespaces)
        // A closing run of #s is decoration
        if let closing = text.range(of: #"\s+#+$"#, options: .regularExpression) {
            text = String(text[..<closing.lowerBound])
        } else if text.allSatisfy({ $0 == "#" }) {
            text = ""
        }
        return (hashes.count, text)
    }

    private static func setextLevel(_ trimmed: String) -> Int? {
        if trimmed.allSatisfy({ $0 == "=" }) { return 1 }
        if trimmed.count >= 2, trimmed.allSatisfy({ $0 == "-" }) { return 2 }
        return nil
    }

    private static func isRule(_ trimmed: String) -> Bool {
        let compact = trimmed.filter { $0 != " " && $0 != "\t" }
        guard compact.count >= 3, let first = compact.first, "-*_".contains(first) else { return false }
        return compact.allSatisfy { $0 == first }
    }

    private static func listItem(in line: String) -> (indent: Int, ordered: Bool, marker: String, checked: Bool?, text: String)? {
        let indent = indentWidth(of: line)
        let content = line.trimmingCharacters(in: .whitespaces)

        var ordered = false
        var marker = ""
        var rest: Substring

        if let first = content.first, "-*+•".contains(first), content.dropFirst().first == " " {
            marker = "•"
            rest = content.dropFirst(2)
        } else {
            let digits = content.prefix(while: { $0.isASCII && $0.isNumber })
            let afterDigits = content.dropFirst(digits.count)
            guard (1...9).contains(digits.count),
                  let delimiter = afterDigits.first, delimiter == "." || delimiter == ")",
                  afterDigits.dropFirst().first == " "
            else {
                return nil
            }
            ordered = true
            marker = "\(digits)."
            rest = afterDigits.dropFirst(2)
        }

        var text = rest.trimmingCharacters(in: .whitespaces)
        var checked: Bool?
        if !ordered {
            if text.hasPrefix("[ ] ") || text == "[ ]" {
                checked = false
                text = String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            } else if text.hasPrefix("[x] ") || text.hasPrefix("[X] ") || text == "[x]" || text == "[X]" {
                checked = true
                text = String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
        }
        return (indent, ordered, marker, checked, text)
    }

    /// The nesting level of an item at this indentation, updating the open levels
    private static func listDepth(for indent: Int, levels: inout [Int]) -> Int {
        guard let deepest = levels.last else {
            levels = [indent]
            return 0
        }
        if indent > deepest {
            levels.append(indent)
        } else {
            while levels.count > 1, let last = levels.last, indent < last {
                levels.removeLast()
            }
            if let last = levels.last, indent > last {
                levels.append(indent)
            }
        }
        return levels.count - 1
    }

    // MARK: Tables

    /// The column alignments of a table's delimiter row, such as `|---|:--:|`, or nil when the line isn't one
    static func tableAlignments(_ line: String) -> [MarkdownTableAlignment]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("-"), trimmed.allSatisfy({ "|:- \t".contains($0) }) else { return nil }
        let cells = tableCells(trimmed)
        guard !cells.isEmpty, trimmed.contains("|") || cells.count > 1 else { return nil }
        var alignments: [MarkdownTableAlignment] = []
        for cell in cells {
            let dashes = cell.filter { $0 == "-" }
            guard !dashes.isEmpty, cell.allSatisfy({ $0 == "-" || $0 == ":" }) else { return nil }
            let left = cell.hasPrefix(":")
            let right = cell.hasSuffix(":")
            alignments.append(left && right ? .center : (right ? .trailing : .leading))
        }
        return alignments
    }

    /// A table row's cells, without the outer pipes; `\|` is a pipe inside a cell
    static func tableCells(_ line: String) -> [String] {
        var row = line.trimmingCharacters(in: .whitespaces)
        if row.hasPrefix("|") { row.removeFirst() }
        if row.hasSuffix("|"), !row.hasSuffix("\\|") { row.removeLast() }

        var cells: [String] = []
        var current = ""
        var escaped = false
        for character in row {
            if escaped {
                current.append(character == "|" ? "|" : "\\\(character)")
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "|" {
                cells.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(character)
            }
        }
        if escaped { current.append("\\") }
        cells.append(current.trimmingCharacters(in: .whitespaces))
        return cells
    }
}

// MARK: - Inline

/// Inline Markdown (bold, italic, code, links) through `AttributedString`, with each passage tag
/// such as [S2] turned into a link the answer view opens as that source
enum MarkdownInline {
    static let sourceScheme = "opencone-source"

    /// "S2" from a source link, or nil for any other URL
    static func sourceTag(from url: URL) -> String? {
        guard url.scheme == sourceScheme else { return nil }
        let tag = url.absoluteString.dropFirst(sourceScheme.count + 1).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return tag.isEmpty ? nil : tag.uppercased()
    }

    /// `[S1]` becomes a link to source S1, and `[S1, S3]` a link to each. Tags inside inline code
    /// and tags that are already a link's text are left alone.
    static func linkingSourceTags(in text: String) -> String {
        guard text.contains("[S") || text.contains("[s") else { return text }
        // Even segments are outside inline code
        let segments = text.components(separatedBy: "`")
        return segments.enumerated().map { position, segment in
            position.isMultiple(of: 2) ? linkTags(in: segment) : segment
        }
        .joined(separator: "`")
    }

    private static let tagGroup = try! NSRegularExpression(
        pattern: #"\[\s*([Ss]\d{1,3}(?:\s*[,;]\s*[Ss]\d{1,3})*)\s*\](?!\()"#
    )

    private static func linkTags(in segment: String) -> String {
        let range = NSRange(segment.startIndex..., in: segment)
        let matches = tagGroup.matches(in: segment, range: range)
        guard !matches.isEmpty else { return segment }

        var result = ""
        var cursor = segment.startIndex
        for match in matches {
            guard let whole = Range(match.range, in: segment), let inner = Range(match.range(at: 1), in: segment) else { continue }
            result += segment[cursor..<whole.lowerBound]
            let tags = segment[inner]
                .split(whereSeparator: { $0 == "," || $0 == ";" })
                .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            result += tags.map { "[\\[\($0)\\]](\(sourceScheme)://\($0))" }.joined()
            cursor = whole.upperBound
        }
        result += segment[cursor...]
        return result
    }

    static func attributed(_ text: String) -> AttributedString {
        let linked = linkingSourceTags(in: text)
        var options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        options.failurePolicy = .returnPartiallyParsedIfPossible
        guard var attributed = try? AttributedString(markdown: linked, options: options) else {
            return AttributedString(text)
        }

        // Attributes are read and set by key type rather than key path: those key paths aren't
        // Sendable, which Swift 6 makes an error
        for run in attributed.runs {
            if let link = run.attributes[LinkKey.self], link.scheme == sourceScheme {
                attributed[run.range][ForegroundKey.self] = .accentColor
                attributed[run.range][FontKey.self] = .footnote.weight(.semibold)
            } else if run.attributes[InlineIntentKey.self]?.contains(.code) == true {
                attributed[run.range][FontKey.self] = .system(.callout, design: .monospaced)
                attributed[run.range][BackgroundKey.self] = Color.secondary.opacity(0.15)
            }
        }
        return attributed
    }

    typealias LinkKey = AttributeScopes.FoundationAttributes.LinkAttribute
    private typealias InlineIntentKey = AttributeScopes.FoundationAttributes.InlinePresentationIntentAttribute
    private typealias ForegroundKey = AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute
    private typealias FontKey = AttributeScopes.SwiftUIAttributes.FontAttribute
    private typealias BackgroundKey = AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute
}

// MARK: - Views

/// An answer drawn from its Markdown: headings, lists, quotes, tables and code blocks, with every
/// passage tag tappable. Text the model is still writing renders the same way.
struct MarkdownText: View {
    let text: String
    /// Called with "S2" when a passage tag is tapped
    var onSourceTap: ((String) -> Void)? = nil

    var body: some View {
        let blocks = MarkdownParser.blocks(from: text)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { position, block in
                MarkdownBlockView(block: block)
                    .padding(.top, position == 0 ? 0 : Self.spacing(before: block, after: blocks[position - 1]))
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            if let tag = MarkdownInline.sourceTag(from: url) {
                onSourceTap?(tag)
                return .handled
            }
            return .systemAction
        })
    }

    /// List items sit close together; everything else gets paragraph spacing
    private static func spacing(before block: MarkdownBlock, after previous: MarkdownBlock) -> CGFloat {
        switch (previous, block) {
        case (.listItem, .listItem): return 4
        case (.heading, _): return 6
        default: return 10
        }
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock

    var body: some View {
        switch block {
        case let .heading(level, text):
            Text(MarkdownInline.attributed(text))
                .font(Self.headingFont(level))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .accessibilityAddTraits(.isHeader)

        case let .paragraph(text):
            Text(MarkdownInline.attributed(text))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

        case let .listItem(ordered, marker, depth, checked, text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Group {
                    if let checked {
                        Image(systemName: checked ? "checkmark.square.fill" : "square")
                            .foregroundStyle(checked ? Color.accentColor : Color.secondary)
                    } else if ordered {
                        Text(marker)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    } else {
                        Text(Self.bullet(depth))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: ordered ? 20 : 10, alignment: .trailing)

                Text(MarkdownInline.attributed(text))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(.leading, CGFloat(min(depth, 4)) * 16)

        case let .code(language, text):
            CodeBlockView(language: language, code: text)

        case let .quote(text):
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 3)
                Text(MarkdownInline.attributed(text))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .fixedSize(horizontal: false, vertical: true)

        case let .table(header, alignments, rows):
            MarkdownTableView(header: header, alignments: alignments, rows: rows)

        case .rule:
            Divider()
                .padding(.vertical, 2)
        }
    }

    private static func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title3.weight(.bold)
        case 2: return .headline
        default: return .subheadline.weight(.semibold)
        }
    }

    private static func bullet(_ depth: Int) -> String {
        switch depth {
        case 0: return "•"
        case 1: return "◦"
        default: return "▪︎"
        }
    }
}

/// A code block in the OpenResponses style (white monospaced text on near-black), with its
/// language and a copy button
struct CodeBlockView: View {
    let language: String?
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(language ?? "code")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.white.opacity(0.7))
                Spacer(minLength: 8)
                Button {
                    UIPasteboard.general.string = code
                    Haptics.success()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(copied ? Color.green : Color.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(copied ? "Copied" : "Copy code")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))

            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .textSelection(.enabled)
                    .padding(10)
            }
            .accessibilityLabel("Code block")
            .accessibilityHint("Swipe horizontally to view more code")
        }
        .background(Color.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// A Markdown table that scrolls sideways when wider than the answer
struct MarkdownTableView: View {
    let header: [String]
    let alignments: [MarkdownTableAlignment]
    let rows: [[String]]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(header.indices, id: \.self) { column in
                        cell(header[column], column: column)
                            .fontWeight(.semibold)
                    }
                }
                .background(Color.secondary.opacity(0.12))

                ForEach(rows.indices, id: \.self) { row in
                    Divider()
                    GridRow {
                        ForEach(header.indices, id: \.self) { column in
                            cell(column < rows[row].count ? rows[row][column] : "", column: column)
                        }
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(1)
        }
    }

    private func cell(_ text: String, column: Int) -> some View {
        let alignment = column < alignments.count ? alignments[column] : .leading
        let frameAlignment: Alignment
        let textAlignment: TextAlignment
        switch alignment {
        case .leading:
            frameAlignment = .leading
            textAlignment = .leading
        case .center:
            frameAlignment = .center
            textAlignment = .center
        case .trailing:
            frameAlignment = .trailing
            textAlignment = .trailing
        }
        return Text(MarkdownInline.attributed(text))
            .font(.footnote)
            .multilineTextAlignment(textAlignment)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minWidth: 56, maxWidth: 240, alignment: frameAlignment)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
    }
}

#Preview {
    ScrollView {
        MarkdownText(text: """
        ## Pump maintenance

        The **Baxter** pump needs a filter change every *500 hours* [S1]. Both manuals agree on the \
        torque values [S2, S4].

        1. Power down the unit
        2. Remove the `front panel`
           - keep the screws
           - [x] note the serial number
        3. Replace the filter

        > Never run the pump dry.

        | Model | Interval | Torque |
        |:------|:--------:|-------:|
        | Baxter | 500 h | 12 Nm |
        | BD | 750 h | 10 Nm |

        ```swift
        let interval = 500
        ```
        """)
        .padding()
    }
}
