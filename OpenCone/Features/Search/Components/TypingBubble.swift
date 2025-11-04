import SwiftUI

/// Animated typing indicator used for assistant messages while streaming has not yet produced text.
struct TypingBubble: View {
    @Environment(\.theme) private var theme
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(theme.textSecondaryColor.opacity(0.8))
                    .frame(width: 6, height: 6)
                    .scaleEffect(scale(for: i))
                    .animation(
                        Animation.easeInOut(duration: 0.9)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: phase
                    )
            }
        }
        .onAppear { phase = 1 }
        .accessibilityLabel("Assistant is typing")
    }

    private func scale(for index: Int) -> CGFloat {
        // Simple wave effect across the three dots
        let base: CGFloat = 0.7
        let offset = CGFloat(index) * 0.2
        return base + 0.3 * abs(sin(phase + offset))
    }
}

#Preview {
    VStack(spacing: 16) {
        TypingBubble()
        TypingBubble().preferredColorScheme(.dark)
    }
    .padding()
}
