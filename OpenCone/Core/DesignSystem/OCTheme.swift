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

    /// The only theme: system colors, which follow the light or dark appearance chosen in iOS
    static let system = OCTheme(
        id: "system",
        name: "System",
        primaryColor: Color.blue,
        secondaryColor: Color.indigo,
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
}
