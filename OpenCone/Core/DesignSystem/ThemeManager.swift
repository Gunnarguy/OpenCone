import Combine
import SwiftUI

/// The app's theme. OpenCone follows the system's light or dark appearance, as OpenResponses
/// does, so there is one theme and it is built from system colors that adapt to both.
@MainActor
final class ThemeManager: ObservableObject {
    @Published private(set) var currentTheme: OCTheme = .system

    static let shared = ThemeManager()

    private init() {}
}
