import Combine
import SwiftUI
import UIKit

/// Manages app-wide theme settings
class ThemeManager: ObservableObject {
    /// The currently selected theme
    @Published var currentTheme: OCTheme

    /// Singleton instance
    static let shared = ThemeManager()

    private init() {
        // Determine if a user preference was saved; otherwise match the system appearance
        let hasSavedDarkPref = UserDefaults.standard.object(forKey: "isDarkMode") != nil
        let savedThemeId = UserDefaults.standard.string(forKey: "themeId")

        let initialTheme: OCTheme = {
            if let savedThemeId, let saved = OCTheme.allThemes.first(where: { $0.id == savedThemeId }) {
                return saved
            }
            if hasSavedDarkPref {
                let isDark = UserDefaults.standard.bool(forKey: "isDarkMode")
                return isDark ? .dark : .light
            }
            // Fall back to system appearance when no preference is saved
            if #available(iOS 13.0, *) {
                let style = UIScreen.main.traitCollection.userInterfaceStyle
                return (style == .dark) ? .dark : .light
            } else {
                return .light
            }
        }()

        self.currentTheme = initialTheme

        // Ensure the app icon matches the initial appearance (no-op if not configured)
        updateAppIcon(for: currentTheme)
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

    // Attempt to align the app icon to the theme (safe if alternate icon not present)
    updateAppIcon(for: theme)
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

    /// Switches to a dark alternate app icon when using a dark theme, and back to primary for light.
    /// This is a no-op unless an alternate icon named "AppIconDark" is configured in Info.plist
    /// (CFBundleIcons -> CFBundleAlternateIcons) and included in the asset catalog.
    private func updateAppIcon(for theme: OCTheme) {
        guard UIApplication.shared.supportsAlternateIcons else { return }

        // Decide target icon name based on theme
        let targetIcon: String? = (theme.id == "dark" || theme.id == "midnight") ? "AppIconDark" : nil

        // Avoid redundant switches
        if UIApplication.shared.alternateIconName == targetIcon { return }

        // If switching to an alternate, ensure it's declared in Info.plist
        if let name = targetIcon, hasAlternateIcon(named: name) == false {
            return
        }

        UIApplication.shared.setAlternateIconName(targetIcon) { error in
            #if DEBUG
            if let error = error {
                print("[ThemeManager] Failed to set alternate icon: \(error.localizedDescription)")
            } else {
                print("[ThemeManager] Alternate icon set to: \(targetIcon ?? "primary")")
            }
            #endif
        }
    }

    /// Check if an alternate icon with the given name is declared in Info.plist
    private func hasAlternateIcon(named name: String) -> Bool {
        guard
            let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let alternates = icons["CFBundleAlternateIcons"] as? [String: Any]
        else { return false }
        return alternates[name] != nil
    }

    /// Public helper to update the app icon for a given system color scheme.
    /// This allows SwiftUI views to request an icon update when the scheme changes.
    func updateAppIcon(for colorScheme: ColorScheme) {
        let tempTheme = (colorScheme == .dark) ? OCTheme.dark : OCTheme.light
        updateAppIcon(for: tempTheme)
    }
}
