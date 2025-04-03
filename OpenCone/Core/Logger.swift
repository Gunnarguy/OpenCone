import Foundation
import Combine

/// Centralized logging system for the app
class Logger: ObservableObject { // Added ObservableObject conformance
    static let shared = Logger()
    
    // Published log entries for UI updates
    @Published var logEntries: [ProcessingLogEntry] = []
    
    // Maximum number of log entries to keep
    private let maxLogEntries = 1000
    
    private init() {}
    
    /// Add a log entry with specified level and message
    /// - Parameters:
    ///   - level: Log level (info, warning, error, success)
    ///   - message: Log message
    ///   - context: Optional context information
    func log(level: ProcessingLogEntry.LogLevel, message: String, context: String? = nil) {
        let entry = ProcessingLogEntry(level: level, message: message, context: context)
        
        // Add to the log entries array
        DispatchQueue.main.async {
            self.logEntries.append(entry)
            
            // Trim the log if it exceeds the maximum size
            if self.logEntries.count > self.maxLogEntries {
                self.logEntries = Array(self.logEntries.dropFirst(self.logEntries.count - self.maxLogEntries))
            }
        }
        
        // Also print to console for debugging
        let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
        let contextInfo = context != nil ? " [\(context!)]" : ""
        print("[\(timestamp)] [\(level.rawValue)]\(contextInfo): \(message)")
    }
    
    /// Clear all log entries
    func clearLogs() {
        DispatchQueue.main.async {
            self.logEntries.removeAll()
        }
    }
    
    /// Export logs to a string
    /// - Returns: String representation of logs
    func exportLogs() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var logText = "OpenCone Logs - \(dateFormatter.string(from: Date()))\n\n"
        
        for entry in logEntries {
            let timestamp = dateFormatter.string(from: entry.timestamp)
            let contextInfo = entry.context != nil ? " [\(entry.context!)]" : ""
            logText += "[\(timestamp)] [\(entry.level.rawValue)]\(contextInfo): \(entry.message)\n"
        }
        
        return logText
    }
    
    /// Filter logs by level
    /// - Parameter level: Log level to filter by
    /// - Returns: Filtered log entries
    func filterByLevel(_ level: ProcessingLogEntry.LogLevel) -> [ProcessingLogEntry] {
        return logEntries.filter { $0.level == level }
    }
    
    /// Search logs for specific text
    /// - Parameter searchText: Text to search for
    /// - Returns: Matching log entries
    func search(for searchText: String) -> [ProcessingLogEntry] {
        let lowercaseSearchText = searchText.lowercased()
        return logEntries.filter {
            $0.message.lowercased().contains(lowercaseSearchText) ||
            ($0.context?.lowercased().contains(lowercaseSearchText) ?? false)
        }
    }
}
