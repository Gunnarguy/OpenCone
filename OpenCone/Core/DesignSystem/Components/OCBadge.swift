import SwiftUI

enum OCBadgeStyle {
    case success
    case error
    case warning
    case info
    case neutral
    case custom(Color)
}

struct OCBadge: View {
    @Environment(\.theme) private var theme

    let text: String
    let style: OCBadgeStyle

    init(_ text: String, style: OCBadgeStyle = .neutral) {
        self.text = text
        self.style = style
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor.opacity(0.15))
            .foregroundColor(backgroundColor)
            .cornerRadius(8)
    }

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
}
