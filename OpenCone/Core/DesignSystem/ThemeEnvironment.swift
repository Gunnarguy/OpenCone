import SwiftUI

/// Environment key to access the current theme
struct ThemeKey: EnvironmentKey {
    static let defaultValue: OCTheme = .light
}

extension EnvironmentValues {
    var theme: OCTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

/// View modifier to apply theme to a view hierarchy
struct ThemeModifier: ViewModifier {
    @ObservedObject var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        content
            .environment(\.theme, themeManager.currentTheme)
            // Apply global accent color to controls (buttons, links, toggles, etc.)
            .tint(themeManager.currentTheme.accentColor)
            // Ensure the theme's background color fills the screen behind all content
            .background(themeManager.currentTheme.backgroundColor.ignoresSafeArea())
            // Keep system chrome in the correct light/dark mode
            .preferredColorScheme(
                themeManager.currentTheme.id == "dark" || themeManager.currentTheme.id == "midnight"
                    ? .dark : .light)
    }
}

extension View {
    func withTheme() -> some View {
        modifier(ThemeModifier())
    }
}
