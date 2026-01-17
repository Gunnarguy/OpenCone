import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    let onCitationTap: ((String) -> Void)?
    var onCopy: ((String) -> Void)?
    var onShare: ((String) -> Void)?
    var onRegenerate: (() -> Void)?
    @Environment(\.theme) private var theme
    @State private var showCopied = false

    init(message: ChatMessage, onCitationTap: ((String) -> Void)? = nil, onCopy: ((String) -> Void)? = nil, onShare: ((String) -> Void)? = nil, onRegenerate: (() -> Void)? = nil) { 
        self.message = message
        self.onCitationTap = onCitationTap
        self.onCopy = onCopy
        self.onShare = onShare
        self.onRegenerate = onRegenerate
    }

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 8) {
                // Message content with streaming/error states
                if message.status == .streaming && message.text.isEmpty && !isUser {
                    TypingBubble()
                        .padding(.vertical, 2)
                } else if message.status == .error && !isUser {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(theme.errorColor)
                            .font(.system(size: 14, weight: .semibold))
                        Text(message.error ?? "Generation failed")
                            .font(.callout)
                            .foregroundColor(theme.errorColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if !message.text.isEmpty {
                    // Always show text when it's not empty, regardless of status
                    Text(message.text)
                        .font(.body)
                        .foregroundColor(isUser ? Color.white : theme.textPrimaryColor)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
.textSelection(.enabled)

                    // Citations for assistant messages
                    if let citations = message.citations, !citations.isEmpty, !isUser {
                        Divider()
                            .opacity(0.5)

                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(theme.textSecondaryColor)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sources")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(theme.textSecondaryColor)

                                // Enumerate to guarantee stable IDs even when duplicate file names repeat
                                ForEach(Array(citations.prefix(5).enumerated()), id: \.offset) { _, src in
                                    Button(action: { onCitationTap?(src) }) {
                                        HStack(spacing: 4) {
                                            Text("• \\(fileName(from: src))")
                                                .font(.caption)
                                                .foregroundColor(theme.primaryColor)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                            Image(systemName: "arrow.up.right")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(theme.primaryColor)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .help(src)
                                }
                            }
                        }
                    }
                }

                // Action buttons for non-streaming messages
                if !message.text.isEmpty, message.status != .streaming {
                    HStack(spacing: 12) {
                        // Copy with feedback
                        Button(action: {
                            Haptics.success()
                            UIPasteboard.general.string = message.text
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCopied = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation { showCopied = false }
                            }
                            onCopy?(message.text)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 11))
                                Text(showCopied ? "Copied!" : "Copy")
                                    .font(.caption2)
                            }
                            .foregroundColor(showCopied ? theme.successColor : (isUser ? Color.white.opacity(0.7) : theme.textSecondaryColor))
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            onShare?(message.text)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 11))
                                Text("Share")
                                    .font(.caption2)
                            }
                            .foregroundColor(isUser ? Color.white.opacity(0.7) : theme.textSecondaryColor)
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Regenerate for assistant messages
                        if !isUser, let onRegenerate {
                            Button(action: onRegenerate) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 11))
                                    Text("Retry")
                                        .font(.caption2)
                                }
                                .foregroundColor(theme.textSecondaryColor)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        Spacer()

                        // Timestamp
                        Text(formatTime(message.createdAt))
                            .font(.caption2)
                            .foregroundColor(isUser ? Color.white.opacity(0.5) : theme.textSecondaryColor.opacity(0.5))

                        // Word count for assistant
                        if !isUser {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(theme.textSecondaryColor.opacity(0.4))
                            Text("\(message.text.split(separator: " ").count) words")
                                .font(.caption2)
                                .foregroundColor(theme.textSecondaryColor.opacity(0.6))
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        isUser
                        ? theme.primaryColor
                        : (message.status == .error ? theme.errorLight : theme.cardBackgroundColor)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isUser
                        ? theme.primaryMedium.opacity(0.0)
                        : (message.status == .error ? theme.errorColor.opacity(0.6) : theme.primaryLight.opacity(0.6)),
                        lineWidth: isUser ? 0 : 1
                    )
            )
            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
            .frame(maxWidth: 600, alignment: .leading)
.contextMenu {
    Button(action: {
        UIPasteboard.general.string = message.text
        onCopy?(message.text)
    }) {
        Label("Copy Message", systemImage: "doc.on.doc")
    }

    Button(action: {
        onShare?(message.text)
    }) {
        Label("Share Message", systemImage: "square.and.arrow.up")
    }

    if !isUser, let onRegenerate {
        Divider()
        Button(action: onRegenerate) {
            Label("Regenerate", systemImage: "arrow.clockwise")
        }
    }

    if let citations = message.citations, !citations.isEmpty {
        Divider()
        Button(action: {
            let citationText = citations.joined(separator: "\n")
            UIPasteboard.general.string = citationText
        }) {
            Label("Copy Sources", systemImage: "doc.text")
        }
    }
}

            if !isUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private func fileName(from path: String) -> String {
        let components = path.split(separator: "/")
        return components.last.map(String.init) ?? path
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    VStack {
        ChatBubble(
            message: ChatMessage(
                role: .assistant,
                text: "Here is an answer that references your documents and provides useful information grounded in your content.",
                citations: ["reports/q1.pdf", "notes/meeting.txt"]
            ),
            onCitationTap: { _ in }
        )
        ChatBubble(
            message: ChatMessage(
                role: .user,
                text: "How did revenue change last quarter compared to the previous one?",
                citations: nil
            ),
            onCitationTap: nil
        )
    }
    .padding()
}
