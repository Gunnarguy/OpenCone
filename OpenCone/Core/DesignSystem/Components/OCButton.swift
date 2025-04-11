import SwiftUI

/// Button styles for OpenCone app
enum OCButtonStyle {
    case primary
    case secondary
    case outline
    case destructive
    case text

    // Added size option
    enum Size {
        case small
        case standard
        case large
    }
}

/// Standard button component that matches the app theme
struct OCButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    // Button properties
    let title: String
    let icon: String?
    let style: OCButtonStyle
    let size: OCButtonStyle.Size
    let fullWidth: Bool
    let action: () -> Void

    // Button state
    @State private var isPressed = false

    init(
        title: String,
        icon: String? = nil,
        style: OCButtonStyle = .primary,
        size: OCButtonStyle.Size = .standard,
        fullWidth: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.fullWidth = fullWidth
        self.action = action
    }

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isPressed = true
            }

            // Reset the pressed state after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isPressed = false
                    action()
                }
            }
        }) {
            HStack(spacing: iconSpacing) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .medium))
                }

                Text(title)
                    .font(textFont)
                    .fontWeight(textWeight)
            }
            .frame(maxWidth: fullWidth && style != .text ? .infinity : nil)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, style == .text ? 0 : horizontalPadding)
            .background(
                buttonBackground
                    .scaleEffect(isPressed ? 0.97 : 1.0)
            )
            .foregroundColor(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: style == .outline ? 1.5 : 0)
                    .scaleEffect(isPressed ? 0.97 : 1.0)
            )
            .opacity(isEnabled ? 1.0 : 0.5)
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Computed properties

    private var buttonBackground: some View {
        switch style {
        case .primary:
            return AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [
                        theme.primaryColor,
                        theme.primaryColor.opacity(0.9),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .secondary:
            return AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [
                        theme.secondaryColor,
                        theme.secondaryColor.opacity(0.9),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .destructive:
            return AnyView(
                LinearGradient(
                    gradient: Gradient(colors: [
                        theme.errorColor,
                        theme.errorColor.opacity(0.9),
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        case .outline, .text:
            return AnyView(Color.clear)
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

    // MARK: - Size-based properties

    private var verticalPadding: CGFloat {
        switch size {
        case .small: return 6
        case .standard: return 12
        case .large: return 16
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .small: return 12
        case .standard: return 16
        case .large: return 20
        }
    }

    private var iconSize: CGFloat {
        switch size {
        case .small: return 12
        case .standard: return 16
        case .large: return 20
        }
    }

    private var iconSpacing: CGFloat {
        switch size {
        case .small: return 4
        case .standard: return 8
        case .large: return 10
        }
    }

    private var cornerRadius: CGFloat {
        switch size {
        case .small: return 8
        case .standard: return 10
        case .large: return 12
        }
    }

    private var textFont: Font {
        switch size {
        case .small: return .caption
        case .standard: return .body
        case .large: return .title3
        }
    }

    private var textWeight: Font.Weight {
        return .medium
    }
}
