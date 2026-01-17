import UIKit

/// Simple haptic feedback wrapper
@MainActor
enum Haptics {
    private static let impact = UIImpactFeedbackGenerator(style: .medium)
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let notification = UINotificationFeedbackGenerator()
    private static let selectionGenerator = UISelectionFeedbackGenerator()

    /// Light tap feedback (for selection changes)
    static func light() {
        lightImpact.impactOccurred()
    }

    /// Medium tap feedback (for button presses)
    static func tap() {
        impact.impactOccurred()
    }

    /// Success feedback (for completed actions)
    static func success() {
        notification.notificationOccurred(.success)
    }

    /// Error feedback (for failures)
    static func error() {
        notification.notificationOccurred(.error)
    }

    /// Warning feedback (for alerts)
    static func warning() {
        notification.notificationOccurred(.warning)
    }

    /// Selection changed feedback
    static func selection() {
        selectionGenerator.selectionChanged()
    }
}
