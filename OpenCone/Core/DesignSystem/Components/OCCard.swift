import SwiftUI

/// Card component with consistent styling
struct OCCard<Content: View>: View {
    @Environment(\.theme) private var theme

    let content: () -> Content
    let padding: CGFloat
    let cornerRadius: CGFloat
    let showShadow: Bool

    init(
        padding: CGFloat = 16,
        cornerRadius: CGFloat = 12,
        showShadow: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.showShadow = showShadow
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(theme.cardBackgroundColor)
                    .shadow(
                        color: showShadow ? Color.black.opacity(0.1) : .clear,
                        radius: 5,
                        x: 0,
                        y: 2
                    )
            )
    }
}
