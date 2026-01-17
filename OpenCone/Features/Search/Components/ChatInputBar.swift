import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void
    let onStop: (() -> Void)?
    var speechService: SpeechRecognitionService?

    init(
        text: Binding<String>,
        isSending: Bool,
        onSend: @escaping () -> Void,
        onStop: (() -> Void)? = nil,
        speechService: SpeechRecognitionService? = nil
    ) {
        self._text = text
        self.isSending = isSending
        self.onSend = onSend
        self.onStop = onStop
        self.speechService = speechService
    }

    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Voice input button (if available)
            if let speechService = speechService {
                VoiceInputButton(speechService: speechService) { transcription in
                    text = transcription
                }
            }

            // Text field with inline clear
            HStack(spacing: 0) {
                TextField("Ask anything...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
.font(.system(size: 16))
    .lineLimit(1 ... 5)
    .submitLabel(.send)
    .focused($isFocused)
.padding(.horizontal, 14)
    .padding(.vertical, 10)
.onSubmit {
    guard canSend else { return }
    isFocused = false
    onSend()
}

                if !text.isEmpty, !isSending {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
.font(.system(size: 16))
    .foregroundColor(theme.textSecondaryColor.opacity(0.6))
                    }
                    .buttonStyle(.plain)
.padding(.trailing, 8)
                }
            }
.background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(theme.backgroundColor)
            )
.overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isFocused ? theme.primaryColor.opacity(0.5) : theme.textSecondaryColor.opacity(0.2), lineWidth: 1)
            )

            // Send / Stop button
            Button {
                if isSending {
                    Haptics.warning()
                    onStop?()
                } else if canSend {
                    Haptics.tap()
                    isFocused = false
                    onSend()
                }
            } label: {
                Group {
                    if isSending {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14, weight: .semibold))
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
.foregroundColor(canSend || isSending ? .white : theme.textSecondaryColor)
    .frame(width: 32, height: 32)
    .background(
        Circle()
            .fill(isSending ? Color.red : (canSend ? theme.primaryColor : theme.textSecondaryColor.opacity(0.2)))
    )
            }
.buttonStyle(.plain)
    .disabled(!canSend && !isSending)
    .animation(.easeInOut(duration: 0.15), value: canSend)
.animation(.easeInOut(duration: 0.15), value: isSending)
        }
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }
}

#Preview {
    VStack(spacing: 20) {
        ChatInputBar(text: .constant(""), isSending: false, onSend: {})
        ChatInputBar(text: .constant("What are the key findings?"), isSending: false, onSend: {})
        ChatInputBar(text: .constant("Generating..."), isSending: true, onSend: {}, onStop: {})
    }
    .padding()
.background(Color.gray.opacity(0.1))
}
