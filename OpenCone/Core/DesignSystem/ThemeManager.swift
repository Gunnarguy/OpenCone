import Combine
import SwiftUI

/// Manages app-wide theme settings
class ThemeManager: ObservableObject {
    /// The currently selected theme
    @Published var currentTheme: OCTheme

    /// Singleton instance
    static let shared = ThemeManager()

    private init() {
        // Initialize with the system appearance-based theme
        let isDark = UserDefaults.standard.bool(forKey: "isDarkMode")
        let themeId = UserDefaults.standard.string(forKey: "themeId") ?? (isDark ? "dark" : "light")

        if let savedTheme = OCTheme.allThemes.first(where: { $0.id == themeId }) {
            self.currentTheme = savedTheme
        } else {
            self.currentTheme = isDark ? .dark : .light
        }
    }

    /// Set the current theme
    func setTheme(_ theme: OCTheme) {
        self.currentTheme = theme
        UserDefaults.standard.set(theme.id, forKey: "themeId")

        // Update the app appearance
        if theme.id == "dark" || theme.id == "midnight" {
            UserDefaults.standard.set(true, forKey: "isDarkMode")
            applyDarkMode(true)
        } else {
            UserDefaults.standard.set(false, forKey: "isDarkMode")
            applyDarkMode(false)
        }
    }

    /// Apply dark mode to the whole app
    private func applyDarkMode(_ isDark: Bool) {
        if #available(iOS 15.0, *) {
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first as? UIWindowScene
            windowScene?.windows.first?.overrideUserInterfaceStyle = isDark ? .dark : .light
        } else {
            UIApplication.shared.windows.first?.overrideUserInterfaceStyle = isDark ? .dark : .light
        }
    }
}
