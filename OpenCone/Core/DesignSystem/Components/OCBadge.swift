import SwiftUI

/// Style options for badge elements
enum OCBadgeStyle {
    case success
    case error
    case warning
    case info
    case neutral
    case custom(Color)

    /// Size options for badges
    enum Size {
        case small
        case standard
        case large
    }
}

/// Badge component for displaying status indicators or labels
struct OCBadge: View {
    @Environment(\.theme) private var theme

    // Badge properties
    let text: String
    let style: OCBadgeStyle
    let size: OCBadgeStyle.Size
    let iconName: String?

    /// Initialize badge with text and optional styling
    init(
        _ text: String,
        style: OCBadgeStyle = .neutral,
        size: OCBadgeStyle.Size = .standard,
        icon: String? = nil
    ) {
        self.text = text
        self.style = style
        self.size = size
        self.iconName = icon
    }

    var body: some View {
        HStack(spacing: spacing) {
            // Optional icon
            if let iconName = iconName {
                Image(systemName: iconName)
                    .font(iconFont)
            }

            Text(text)
                .font(textFont)
                .fontWeight(.medium)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            Capsule()
                .fill(backgroundColor.opacity(0.15))
        )
        .foregroundColor(backgroundColor)
    }

    // MARK: - Computed Properties

    /// Background color based on badge style
    private var backgroundColor: Color {
        switch style {
        case .success:
            return theme.successColor
        case .error:
            return theme.errorColor
        case .warning:
            return theme.warningColor
        case .info:
            return theme.infoColor
        case .neutral:
            return theme.textSecondaryColor
        case .custom(let color):
            return color
        }
    }

    // Size-based properties
    private var textFont: Font {
        switch size {
        case .small: return .caption2
        case .standard: return .caption
        case .large: return .footnote
        }
    }

    private var iconFont: Font {
        switch size {
        case .small: return .system(size: 8)
        case .standard: return .system(size: 10)
        case .large: return .system(size: 12)
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .small: return 6
        case .standard: return 8
        case .large: return 10
        }
    }

    private var verticalPadding: CGFloat {
        switch size {
        case .small: return 2
        case .standard: return 3
        case .large: return 4
        }
    }

    private var spacing: CGFloat {
        switch size {
        case .small: return 2
        case .standard: return 3
        case .large: return 4
        }
    }
}
