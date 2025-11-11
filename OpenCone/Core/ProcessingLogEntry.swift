import Foundation
import SwiftUI  // Needed for Color in LogLevel
import UIKit   // Needed for UIColor in LogLevel


/// Represents a log entry in the processing log
struct ProcessingLogEntry: Identifiable {
    var id = UUID()
    var timestamp: Date
    var level: LogLevel
    var message: String
    var context: String?

    init(level: LogLevel, message: String, context: String? = nil) {
        self.timestamp = Date()
        self.level = level
        self.message = message
        self.context = context
    }

    enum LogLevel: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case success = "SUCCESS"

        /// Get the color for this log level, with optional theme support
        /// - Parameter theme: Optional theme to use for color
        /// - Returns: Color for this log level
        func color(for theme: OCTheme? = nil) -> Color {
            switch self {
            case .debug:
                return .gray
            case .info:
                return theme?.primaryColor ?? .blue
            case .warning:
                return .orange
            case .error:
                return theme?.errorColor ?? .red
            case .success:
                return .green
            }
        }

        /// Legacy color property for backward compatibility
        var color: Color {
            return self.color(for: nil)
        }

        var severityRank: Int {
            switch self {
            case .debug: return 0
            case .info: return 1
            case .success: return 2
            case .warning: return 3
            case .error: return 4
            }
        }
    }
}
