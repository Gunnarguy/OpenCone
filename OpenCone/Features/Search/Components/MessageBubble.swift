import Combine
import SwiftUI
import UIKit

/// One message, in the OpenResponses style: the question in an accent bubble on the right, the
/// answer in a gray bubble with its Markdown drawn, the documents it cites, and quick actions.
/// Equatable on what it shows, so while one answer streams the others keep their drawn Markdown
/// instead of parsing it again for every new piece of text (the closures change on every update).
struct MessageBubble: View, Equatable {
    nonisolated static func == (lhs: MessageBubble, rhs: MessageBubble) -> Bool {
        lhs.message == rhs.message && lhs.status == rhs.status && lhs.canRetry == rhs.canRetry
    }

    let message: ChatMessage
    /// What the search is doing while this answer waits for its first words
    var status: String? = nil
    /// Only the latest answer can be asked again
    var canRetry = false
    var onOpenSource: (SearchResultModel) -> Void = { _ in }
    var onShowSources: () -> Void = {}
    var onRetry: () -> Void = {}

    @ScaledMetric private var bubblePadding: CGFloat = 12
    @ScaledMetric private var cornerRadius: CGFloat = 16
    @State private var copied = false

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isUser {
                Spacer(minLength: 48)
                userBubble
            } else {
                assistantBubble
                Spacer(minLength: 0)
            }
        }
        .padding(isUser ? .trailing : .leading, 2)
        .animation(.easeInOut(duration: 0.16), value: message.status)
    }

    // MARK: - Question

    private var userBubble: some View {
        Text(message.text)
            .font(.body)
            .foregroundStyle(Color.white)
            .textSelection(.enabled)
            .padding(bubblePadding)
            .background(Color.accentColor.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contextMenu {
                Button {
                    UIPasteboard.general.string = message.text
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                ShareLink(item: message.text) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            .accessibilityLabel("Your question: \(message.text)")
    }

    // MARK: - Answer

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 10) {
            content

            if message.status != .streaming, !message.sources.isEmpty {
                SourceChips(message: message, onOpenSource: onOpenSource, onShowAll: onShowSources)
            }

            if message.status == .normal, !message.text.isEmpty {
                quickActions
            }
        }
        .padding(bubblePadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(message.status == .error ? Color.red.opacity(0.1) : Color.gray.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        switch message.status {
        case .error:
            VStack(alignment: .leading, spacing: 8) {
                if !message.text.isEmpty {
                    MarkdownText(text: message.text, onSourceTap: openTag)
                }
                Label(message.error ?? "The answer failed.", systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(Color.red)
                if canRetry {
                    Button(action: onRetry) {
                        Label("Try again", systemImage: "arrow.clockwise")
                            .font(.callout.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }

        case .streaming where message.text.isEmpty:
            HStack(spacing: 8) {
                TypingDots()
                Text(status ?? "Writing the answer")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)

        default:
            VStack(alignment: .leading, spacing: 6) {
                MarkdownText(text: message.text, onSourceTap: openTag)
                if message.status == .streaming {
                    TypingDots()
                        .padding(.top, 2)
                }
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            Button {
                UIPasteboard.general.string = message.text
                Haptics.success()
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            } label: {
                actionLabel(copied ? "checkmark" : "doc.on.doc", tint: copied ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(copied ? "Copied" : "Copy answer")

            ShareLink(item: shareText) {
                actionLabel("square.and.arrow.up", tint: .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share answer")

            if canRetry {
                Button(action: onRetry) {
                    actionLabel("arrow.clockwise", tint: .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ask again")
            }

            Spacer(minLength: 0)

            Text(message.createdAt, style: .time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func actionLabel(_ systemImage: String, tint: Color) -> some View {
        Image(systemName: systemImage)
            .font(.caption2)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12))
            .clipShape(Capsule())
    }

    /// The answer with the documents it cites, for sharing outside the app
    private var shareText: String {
        let documents = SourceChips.documents(in: message)
        guard !documents.isEmpty else { return message.text }
        let list = documents.map { "- \($0.title)" + ($0.scope.map { " (\($0))" } ?? "") }
        return message.text + "\n\nSources:\n" + list.joined(separator: "\n")
    }

    private func openTag(_ tag: String) {
        if let source = message.source(tagged: tag) {
            onOpenSource(source)
        } else {
            onShowSources()
        }
    }
}

// MARK: - Sources

/// The documents an answer cites, one chip each, and a chip for the full list of passages
struct SourceChips: View {
    let message: ChatMessage
    let onOpenSource: (SearchResultModel) -> Void
    let onShowAll: () -> Void

    struct Document: Identifiable {
        let id: String
        let title: String
        let scope: String?
        let firstPassage: SearchResultModel
        let tags: [String]
    }

    /// One entry per document and place, in the order the answer's passages were tagged
    static func documents(in message: ChatMessage) -> [Document] {
        var order: [String] = []
        var grouped: [String: (title: String, scope: String?, first: SearchResultModel, tags: [String])] = [:]
        for source in message.sources {
            let key = "\(source.scopeLabel ?? "")\u{1F}\(source.sourceDocument)"
            if var entry = grouped[key] {
                if let tag = source.citationTag { entry.tags.append(tag) }
                grouped[key] = entry
            } else {
                order.append(key)
                grouped[key] = (fileName(source.sourceDocument), source.scopeLabel, source, source.citationTag.map { [$0] } ?? [])
            }
        }
        return order.compactMap { key in
            grouped[key].map { Document(id: key, title: $0.title, scope: $0.scope, firstPassage: $0.first, tags: $0.tags) }
        }
    }

    static func fileName(_ path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }

    var body: some View {
        let documents = Self.documents(in: message)
        VStack(alignment: .leading, spacing: 6) {
            Text("Sources")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(documents) { document in
                        Button {
                            onOpenSource(document.firstPassage)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "doc.text")
                                    .font(.caption2)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(document.title)
                                        .font(.caption.weight(.medium))
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    if let scope = document.scope {
                                        Text(scope)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                    }
                                }
                                if !document.tags.isEmpty {
                                    Text(document.tags.joined(separator: " "))
                                        .font(.caption2.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .frame(maxWidth: 220, alignment: .leading)
                            .foregroundStyle(Color.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(uiColor: .systemBackground).opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Source \(document.title)" + (document.scope.map { ", in \($0)" } ?? ""))
                    }

                    Button(action: onShowAll) {
                        HStack(spacing: 4) {
                            Text(message.sources.count == 1 ? "1 passage" : "\(message.sources.count) passages")
                                .font(.caption.weight(.medium))
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(message.sources.count == 1 ? "Show the passage" : "Show all \(message.sources.count) passages")
                }
            }
        }
    }
}

// MARK: - Typing

/// Three dots that pulse while an answer is on its way
struct TypingDots: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { dot in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 6, height: 6)
                    .opacity(phase == dot ? 1 : 0.35)
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                phase = (phase + 1) % 3
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    let passages: [SearchResultModel] = {
        var first = SearchResultModel(content: "Change the water filter every 500 shots.", sourceDocument: "manuals/Aster Duo User Manual.pdf", score: 0.91, metadata: [:], index: "manuals", namespace: "espresso")
        first.citationTag = "S1"
        var second = SearchResultModel(content: "Brush the burrs every 2 weeks.", sourceDocument: "manuals/Fenn 64 Grinder Guide.pdf", score: 0.84, metadata: [:], index: "manuals", namespace: "grinder")
        second.citationTag = "S2"
        return [first, second]
    }()
    return ScrollView {
        VStack(spacing: 12) {
            MessageBubble(message: ChatMessage(role: .user, text: "How often does the Aster Duo need a new filter?"))
            MessageBubble(
                message: ChatMessage(role: .assistant, text: "Every **500 shots** [S1]. Brush the grinder's burrs every 2 weeks [S2].", sources: passages),
                canRetry: true
            )
            MessageBubble(message: ChatMessage(role: .assistant, text: "", status: .streaming), status: "Searching manuals / espresso")
            MessageBubble(message: ChatMessage(role: .assistant, text: "", status: .error, error: "Pinecone didn't respond."), canRetry: true)
        }
        .padding()
    }
}
