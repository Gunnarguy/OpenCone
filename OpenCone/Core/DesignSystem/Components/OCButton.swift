import SwiftUI

/// Button styles for OpenCone app
enum OCButtonStyle {
    case primary
    case secondary
    case outline
    case destructive
    case text
}

/// Standard button component that matches the app theme
struct OCButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    let title: String
    let icon: String?
    let style: OCButtonStyle
    let action: () -> Void

    init(
        title: String, icon: String? = nil, style: OCButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                }

                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: style == .text ? nil : .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, style == .text ? 0 : 16)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: style == .outline ? 1 : 0)
            )
            .opacity(isEnabled ? 1.0 : 0.5)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var backgroundColor: Color {
        if !isEnabled {
            return style == .outline || style == .text ? .clear : theme.cardBackgroundColor
        }

        switch style {
        case .primary:
            return theme.primaryColor
        case .secondary:
            return theme.secondaryColor
        case .destructive:
            return theme.errorColor
        case .outline, .text:
            return .clear
        }
    }

    private var foregroundColor: Color {
        if !isEnabled {
            return theme.textSecondaryColor
        }

        switch style {
        case .primary, .secondary, .destructive:
            return .white
        case .outline:
            return style == .destructive ? theme.errorColor : theme.primaryColor
        case .text:
            return style == .destructive ? theme.errorColor : theme.primaryColor
        }
    }

    private var borderColor: Color {
        if !isEnabled {
            return theme.textSecondaryColor.opacity(0.3)
        }

        switch style {
        case .outline:
            return style == .destructive ? theme.errorColor : theme.primaryColor
        default:
            return .clear
        }
    }
}
