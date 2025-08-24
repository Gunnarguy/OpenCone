import Foundation
import Combine
import SwiftUI
import UIKit

/// Theme definition for OpenCone app
struct OCTheme {
    let id: String
    let name: String
    let primaryColor: Color
    let secondaryColor: Color
    let backgroundColor: Color
    let cardBackgroundColor: Color
    let textPrimaryColor: Color
    let textSecondaryColor: Color
    let accentColor: Color
    let successColor: Color
    let warningColor: Color
    let errorColor: Color
    let infoColor: Color

    // Success state colors with opacity variants
    var successLight: Color { successColor.opacity(0.15) }
    var successMedium: Color { successColor.opacity(0.5) }

    // Error state colors with opacity variants
    var errorLight: Color { errorColor.opacity(0.15) }
    var errorMedium: Color { errorColor.opacity(0.5) }

    // Primary color with opacity variants
    var primaryLight: Color { primaryColor.opacity(0.15) }
    var primaryMedium: Color { primaryColor.opacity(0.5) }

    /// Built-in light theme
    static let light = OCTheme(
        id: "light",
        name: "Light",
        primaryColor: Color.blue,
        secondaryColor: Color(hex: "#6C63FF"),
        backgroundColor: Color(.systemBackground),
        cardBackgroundColor: Color(.secondarySystemBackground),
        textPrimaryColor: Color(.label),
        textSecondaryColor: Color(.secondaryLabel),
        accentColor: Color.blue,
        successColor: Color.green,
        warningColor: Color.orange,
        errorColor: Color.red,
        infoColor: Color.blue
    )

    /// Built-in dark theme
    static let dark = OCTheme(
        id: "dark",
        name: "Dark",
    // Use a deeper, high-contrast palette for a more "true dark" look
    // that matches the OpenAssistant aesthetic.
    primaryColor: Color(hex: "#3366FF"),
    secondaryColor: Color(hex: "#7E76FF"),
    backgroundColor: Color(hex: "#121A2B"), // deep desaturated blue/black
    cardBackgroundColor: Color(hex: "#1A2540"), // slightly lifted from background
    textPrimaryColor: Color.white,
    textSecondaryColor: Color.white.opacity(0.7),
    accentColor: Color(hex: "#3366FF"),
    successColor: Color(hex: "#4CD964"),
    warningColor: Color(hex: "#FF9500"),
    errorColor: Color(hex: "#FF3B30"),
    infoColor: Color(hex: "#5AC8FA")
    )

    /// Midnight blue theme
    static let midnight = OCTheme(
        id: "midnight",
        name: "Midnight",
        primaryColor: Color(hex: "#3366FF"),
        secondaryColor: Color(hex: "#6C63FF"),
        backgroundColor: Color(hex: "#121A2B"),
        cardBackgroundColor: Color(hex: "#1A2540"),
        textPrimaryColor: Color.white,
        textSecondaryColor: Color.white.opacity(0.7),
        accentColor: Color(hex: "#3366FF"),
        successColor: Color(hex: "#4CD964"),
        warningColor: Color(hex: "#FF9500"),
        errorColor: Color(hex: "#FF3B30"),
        infoColor: Color(hex: "#5AC8FA")
    )

    /// Forest green theme
    static let forest = OCTheme(
        id: "forest",
        name: "Forest",
        primaryColor: Color(hex: "#2E8B57"),
        secondaryColor: Color(hex: "#8FBC8F"),
        backgroundColor: Color(hex: "#F5F9F5"),
        cardBackgroundColor: Color(hex: "#E8F5E9"),
        textPrimaryColor: Color(hex: "#212121"),
        textSecondaryColor: Color(hex: "#757575"),
        accentColor: Color(hex: "#2E8B57"),
        successColor: Color(hex: "#4CAF50"),
        warningColor: Color(hex: "#FF9800"),
        errorColor: Color(hex: "#F44336"),
        infoColor: Color(hex: "#03A9F4")
    )

    /// All available themes
    static let allThemes: [OCTheme] = [.light, .dark, .midnight, .forest]
}
