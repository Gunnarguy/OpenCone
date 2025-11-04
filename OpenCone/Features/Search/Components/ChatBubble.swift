import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    let onCitationTap: ((String) -> Void)?
    @Environment(\.theme) private var theme

    init(message: ChatMessage, onCitationTap: ((String) -> Void)? = nil) {
        self.message = message
        self.onCitationTap = onCitationTap
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

                                ForEach(citations.prefix(5), id: \.self) { src in
                                    Button(action: { onCitationTap?(src) }) {
                                        HStack(spacing: 4) {
                                            Text("• \(fileName(from: src))")
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

            if !isUser { Spacer(minLength: 40) }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    private func fileName(from path: String) -> String {
        let components = path.split(separator: "/")
        return components.last.map(String.init) ?? path
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
