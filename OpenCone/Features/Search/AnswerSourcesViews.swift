import SwiftUI
import UIKit

/// What a tap on a source opens: every passage behind an answer, or one passage
enum SourcesPresentation: Identifiable {
    case all(ChatMessage)
    case passage(SearchResultModel)

    var id: String {
        switch self {
        case .all(let message): return "all-\(message.id)"
        case .passage(let passage): return "passage-\(passage.id)"
        }
    }
}

struct SourcesPresentationView: View {
    let presentation: SourcesPresentation
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch presentation {
                case .all(let message):
                    AnswerSourcesList(message: message)
                case .passage(let passage):
                    SourcePassageView(passage: passage)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(uiColor: .systemGroupedBackground))
    }
}

/// Every passage an answer was written from, in the order the answer tags them
struct AnswerSourcesList: View {
    let message: ChatMessage

    var body: some View {
        List {
            Section {
                ForEach(message.sources) { passage in
                    NavigationLink {
                        SourcePassageView(passage: passage)
                    } label: {
                        SourcePassageRow(passage: passage)
                    }
                }
            } footer: {
                Text("The answer cites each passage by its tag. Scores are the vector match, or the reranker's score when reranking is on.")
            }
        }
        .navigationTitle(message.sources.count == 1 ? "1 passage" : "\(message.sources.count) passages")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SourcePassageRow: View {
    let passage: SearchResultModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let tag = passage.citationTag {
                    Text(tag)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text(SourceChips.fileName(passage.sourceDocument))
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                Text(String(format: "%.2f", passage.score))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let scope = passage.scopeLabel {
                Label(scope, systemImage: "cylinder.split.1x2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(passage.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(.vertical, 2)
    }
}

/// One passage in full: its text, where it came from, and its metadata
struct SourcePassageView: View {
    let passage: SearchResultModel
    @State private var copied = false

    private var sortedMetadata: [(key: String, value: String)] {
        passage.metadata
            .filter { !["text", "content", "chunk_text", "_node_content"].contains($0.key) }
            .sorted { $0.key < $1.key }
            .map { (key: $0.key, value: $0.value) }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        if let tag = passage.citationTag {
                            Text(tag)
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        Text(SourceChips.fileName(passage.sourceDocument))
                            .font(.headline)
                    }
                    if passage.sourceDocument != SourceChips.fileName(passage.sourceDocument) {
                        Text(passage.sourceDocument)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                if let scope = passage.scopeLabel {
                    LabeledContent("Found in", value: scope)
                }
                if let page = passage.metadata["page_number"], !page.isEmpty {
                    LabeledContent("Page", value: page)
                }
                LabeledContent("Score", value: String(format: "%.3f", passage.score))
            }

            Section {
                Text(passage.content)
                    .font(.callout)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Passage")
            }

            Section {
                Button {
                    UIPasteboard.general.string = passage.content
                    Haptics.success()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    Label(copied ? "Copied" : "Copy passage", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                ShareLink(item: "\(passage.content)\n\n\(passage.sourceDocument)") {
                    Label("Share passage", systemImage: "square.and.arrow.up")
                }
            }

            if !sortedMetadata.isEmpty {
                Section {
                    DisclosureGroup("Metadata (\(sortedMetadata.count))") {
                        ForEach(sortedMetadata, id: \.key) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.key)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                Text(entry.value)
                                    .font(.caption)
                                    .lineLimit(4)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(passage.citationTag ?? "Passage")
        .navigationBarTitleDisplayMode(.inline)
    }
}
