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
