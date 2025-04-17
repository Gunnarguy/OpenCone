import SwiftUI
import Combine
import Foundation
import UIKit

/// Central design system for OpenCone that provides consistent spacing, sizing, and other design elements
struct OCDesignSystem {
    // MARK: - Spacing
    struct Spacing {
        static let tiny: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let standard: CGFloat = 16
        static let large: CGFloat = 24
        static let extraLarge: CGFloat = 32
    }

    // MARK: - Sizing
    struct Sizing {
        static let buttonHeight: CGFloat = 50
        static let iconSmall: CGFloat = 16
        static let iconMedium: CGFloat = 24
        static let iconLarge: CGFloat = 32
        static let cornerRadiusSmall: CGFloat = 6
        static let cornerRadiusMedium: CGFloat = 10
        static let cornerRadiusLarge: CGFloat = 16
    }

    // MARK: - Animation
    struct Animation {
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let quick = SwiftUI.Animation.easeOut(duration: 0.2)
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.7)
    }
}

// Extension to standardize view modifiers
extension View {
    func standardCard() -> some View {
        self.padding(OCDesignSystem.Spacing.standard)
            .background(ThemeManager.shared.currentTheme.cardBackgroundColor)
            .cornerRadius(OCDesignSystem.Sizing.cornerRadiusMedium)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    func secondaryText() -> some View {
        self.font(.subheadline)
            .foregroundColor(ThemeManager.shared.currentTheme.textSecondaryColor)
    }
}
