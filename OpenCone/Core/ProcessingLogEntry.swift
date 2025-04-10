import Foundation
import SwiftUI // Needed for Color in LogLevel

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

        var color: Color {
            switch self {
            case .debug: return .gray
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            case .success: return .green
            }
        }
    }
}
