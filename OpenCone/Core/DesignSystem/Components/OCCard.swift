import SwiftUI

/// Card component with consistent styling
struct OCCard<Content: View>: View {
    @Environment(\.theme) private var theme

    // Style options for cards
    enum CardStyle {
        case standard
        case elevated
        case subtle
        case flat
    }

    // Content and styling properties
    private let content: Content
    private let padding: CGFloat
    private let cornerRadius: CGFloat
    private let style: CardStyle
    private let showShadow: Bool

    /// Initialize with ViewBuilder content
    init(
        style: CardStyle = .standard,
        padding: CGFloat = OCDesignSystem.Spacing.standard,
        cornerRadius: CGFloat = OCDesignSystem.Sizing.cornerRadiusMedium,
        showShadow: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.style = style
        self.showShadow = showShadow
        self.content = content()
    }

    /// Backward compatibility initializer
    init(
        padding: CGFloat = OCDesignSystem.Spacing.standard,
        cornerRadius: CGFloat = OCDesignSystem.Sizing.cornerRadiusMedium,
        showShadow: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.style = .standard
        self.showShadow = showShadow
        self.content = content()
    }

    // Main view body
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .shadow(
                        color: shadowColor,
                        radius: shadowRadius,
                        x: 0,
                        y: shadowY
                    )
            )
    }

    // Background color based on style
    private var backgroundColor: Color {
        switch style {
        case .standard, .elevated:
            return theme.cardBackgroundColor
        case .subtle:
            return theme.cardBackgroundColor.opacity(0.7)
        case .flat:
            return theme.backgroundColor
        }
    }

    // Shadow color based on style and showShadow flag
    private var shadowColor: Color {
        if !showShadow {
            return .clear
        }

        switch style {
        case .elevated:
            return Color.black.opacity(0.15)
        case .standard:
            return Color.black.opacity(0.08)
        case .subtle, .flat:
            return Color.clear
        }
    }

    // Shadow radius based on style
    private var shadowRadius: CGFloat {
        if !showShadow {
            return 0
        }

        switch style {
        case .elevated:
            return 8
        case .standard:
            return 4
        default:
            return 0
        }
    }

    // Shadow Y offset based on style
    private var shadowY: CGFloat {
        if !showShadow {
            return 0
        }

        switch style {
        case .elevated:
            return 4
        case .standard:
            return 2
        default:
            return 0
        }
    }
}
