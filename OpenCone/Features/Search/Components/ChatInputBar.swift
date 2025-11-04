import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void
    let onStop: (() -> Void)?

    // Explicit initializer to ensure onStop is available at call site
    init(
        text: Binding<String>,
        isSending: Bool,
        onSend: @escaping () -> Void,
        onStop: (() -> Void)? = nil
    ) {
        self._text = text
        self.isSending = isSending
        self.onSend = onSend
        self.onStop = onStop
    }

    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool

    var body: some View {
        OCCard(padding: 10, cornerRadius: 16) {
            HStack(spacing: 10) {
                // Text input
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble")
                        .foregroundColor(isFocused ? theme.primaryColor : theme.textSecondaryColor)
                        .padding(.leading, 6)

                    TextField("Ask about your documents…", text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...4)
                        .submitLabel(.send)
                        .focused($isFocused)
                        .onSubmit {
                            guard canSend else { return }
                            isFocused = false
                            onSend()
                        }

                    if !text.isEmpty {
                        Button {
                            text = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(theme.textSecondaryColor)
                                .padding(.trailing, 6)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear input")
                    }
                }
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isFocused ? theme.primaryColor : Color.clear, lineWidth: 1.5)
                        )
                )

                // Send / Stop button
                if isSending, let onStop = onStop {
                    OCButton(
                        title: "",
                        icon: "stop.fill",
                        style: .outline
                    ) {
                        isFocused = false
                        onStop()
                    }
                    .frame(width: 44, height: 44)
                } else {
                    OCButton(
                        title: "",
                        icon: "arrow.up.circle.fill",
                        style: .primary
                    ) {
                        guard canSend else { return }
                        isFocused = false
                        onSend()
                    }
                    .frame(width: 44, height: 44)
                    .disabled(!canSend)
                    .opacity(canSend ? 1.0 : 0.5)
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isSending)
        .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }
}

#Preview {
    VStack {
        ChatInputBar(text: .constant("Ask about Q1 financials"), isSending: false, onSend: {})
        ChatInputBar(text: .constant(""), isSending: true, onSend: {})
        ChatInputBar(text: .constant("Type here"), isSending: false, onSend: {})
    }
    .padding()
}
