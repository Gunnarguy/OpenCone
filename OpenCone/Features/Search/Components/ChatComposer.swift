import SwiftUI

/// The question field, in the style of OpenResponses' ChatInputView: voice input, a field that
/// grows to six lines, and a round send button that becomes Stop while an answer is coming
struct ChatComposer: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let isSending: Bool
    let placeholder: String
    @ObservedObject var speechService: SpeechRecognitionService
    let onSend: () -> Void
    let onStop: () -> Void

    // Scaled, but capped, as in OpenResponses: uncapped, the row outgrew the phone at the
    // accessibility text sizes. The field itself keeps full Dynamic Type.
    @ScaledMetric private var scaledContainerPadding: CGFloat = 10
    @ScaledMetric private var inputCornerRadius: CGFloat = 20
    @ScaledMetric private var scaledSendButtonSize: CGFloat = 32
    private var containerPadding: CGFloat { min(scaledContainerPadding, 12) }
    private var sendButtonSize: CGFloat { min(scaledSendButtonSize, 44) }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VoiceInputButton(speechService: speechService) { transcription in
                text = text.isEmpty ? transcription : text + " " + transcription
                isFocused.wrappedValue = true
            }
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .accessibilityShowsLargeContentViewer()
            .accessibilityLabel(speechService.isListening ? "Stop dictation" : "Dictate a question")

            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...6)
                .textFieldStyle(.plain)
                .focused(isFocused)
                .submitLabel(.send)
                .onSubmit(send)
                .textInputAutocapitalization(.sentences)
                .padding(.vertical, 6)
                .accessibilityLabel("Question")

            Button {
                if isSending {
                    Haptics.warning()
                    onStop()
                } else {
                    send()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(isSending ? Color.red : (canSend ? Color.accentColor : Color.secondary.opacity(0.15)))
                    Image(systemName: isSending ? "stop.fill" : "arrow.up")
                        .font(.system(size: isSending ? 13 : 15, weight: .semibold))
                        .foregroundStyle(isSending || canSend ? Color.white : Color.secondary)
                }
                .frame(width: sendButtonSize, height: sendButtonSize)
            }
            .disabled(!canSend && !isSending)
            .animation(.easeInOut(duration: 0.15), value: isSending)
            .accessibilityLabel(isSending ? "Stop the answer" : "Send question")
        }
        .padding(containerPadding)
        .background(
            RoundedRectangle(cornerRadius: inputCornerRadius, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: inputCornerRadius, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func send() {
        guard canSend else { return }
        Haptics.tap()
        isFocused.wrappedValue = false
        onSend()
    }
}
