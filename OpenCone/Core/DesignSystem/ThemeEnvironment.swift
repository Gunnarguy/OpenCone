import SwiftUI

/// Environment key to access the current theme
struct ThemeKey: EnvironmentKey {
    static let defaultValue: OCTheme = .system
}

extension EnvironmentValues {
    var theme: OCTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

/// View modifier to apply theme to a view hierarchy. The color scheme is left to the system, so
/// the app is light or dark with the rest of iOS.
struct ThemeModifier: ViewModifier {
    @ObservedObject var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        content
            .environment(\.theme, themeManager.currentTheme)
            // Apply global accent color to controls (buttons, links, toggles, etc.)
            .tint(themeManager.currentTheme.accentColor)
    }
}

extension View {
    func withTheme() -> some View {
        modifier(ThemeModifier())
    }
}
