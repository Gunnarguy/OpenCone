import Foundation
import Combine

/// Centralized logging system for the app, conforming to `ObservableObject` for UI updates.
class Logger: ObservableObject {
    /// Shared singleton instance of the logger.
    static let shared = Logger()
    
    /// Published array of log entries, allowing SwiftUI views to react to changes.
    @Published var logEntries: [ProcessingLogEntry] = []
    
    /// Maximum number of log entries to retain in memory.
    private let maxLogEntries = 1000
    
    /// Private initializer to enforce singleton pattern.
    private init() {}
    
    /// Adds a log entry with the specified level, message, and optional context.
    /// Updates the `logEntries` array on the main thread for UI safety.
    /// Also prints the log message to the console for debugging.
    /// - Parameters:
    ///   - level: The severity level of the log entry (e.g., info, warning, error).
    ///   - message: The main content of the log message.
    ///   - context: Optional additional information related to the log entry.
    func log(level: ProcessingLogEntry.LogLevel, message: String, context: String? = nil) {
        let minimumLevel = currentMinimumLevel()
        guard level.severityRank >= minimumLevel.severityRank else { return }

        let entry = ProcessingLogEntry(level: level, message: message, context: context)
        
        // Update the published array on the main thread as it affects the UI.
        DispatchQueue.main.async {
            self.logEntries.append(entry)
            
            // Trim the log array if it exceeds the maximum allowed size.
            if self.logEntries.count > self.maxLogEntries {
                // Efficiently remove oldest entries by creating a new array slice.
                self.logEntries = Array(self.logEntries.dropFirst(self.logEntries.count - self.maxLogEntries))
            }
        }
        
        // Also print to the console for real-time debugging during development.
        let timestamp = ISO8601DateFormatter().string(from: entry.timestamp)
        let contextInfo = context.map { " [\($0)]" } ?? "" // Use map for cleaner optional handling.
        print("[\(timestamp)] [\(level.rawValue)]\(contextInfo): \(message)")
    }

    private func currentMinimumLevel() -> ProcessingLogEntry.LogLevel {
        if let raw = UserDefaults.standard.string(forKey: SettingsStorageKeys.logMinimumLevel),
           let level = ProcessingLogEntry.LogLevel(rawValue: raw) {
            return level
        }
        return .info
    }
    
    /// Clears all log entries from the `logEntries` array.
    /// Performs the removal on the main thread for UI safety.
    func clearLogs() {
        // Ensure UI updates happen on the main thread.
        DispatchQueue.main.async {
            self.logEntries.removeAll()
        }
    }
    
    /// Exports all current log entries into a single formatted string.
    /// - Returns: A string containing all log entries, suitable for sharing or saving.
    func exportLogs() -> String {
        // Use a local copy of logEntries to avoid potential race conditions if logs are added during export.
        let entriesToExport = self.logEntries
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var logText = "OpenCone Logs - \(dateFormatter.string(from: Date()))\n\n"
        
        // Iterate through the log entries and format them.
        for entry in entriesToExport {
            let timestamp = dateFormatter.string(from: entry.timestamp)
            let contextInfo = entry.context.map { " [\($0)]" } ?? ""
            logText += "[\(timestamp)] [\(entry.level.rawValue)]\(contextInfo): \(entry.message)\n"
        }
        
        return logText
    }
    
    /// Filters the log entries based on a specific log level.
    /// - Parameter level: The `ProcessingLogEntry.LogLevel` to filter by.
    /// - Returns: An array containing only the log entries matching the specified level.
    func filterByLevel(_ level: ProcessingLogEntry.LogLevel) -> [ProcessingLogEntry] {
        // Use the filter method on the logEntries array.
        return logEntries.filter { $0.level == level }
    }
    
    /// Searches log entries for a specific text string (case-insensitive).
    /// Checks both the message and the context fields.
    /// - Parameter searchText: The text to search for within the log entries.
    /// - Returns: An array of log entries containing the search text.
    func search(for searchText: String) -> [ProcessingLogEntry] {
        // Optimize by converting search text to lowercase once.
        let lowercasedSearchText = searchText.lowercased()
        
        // Return empty if search text is empty to avoid unnecessary filtering.
        guard !lowercasedSearchText.isEmpty else {
            return logEntries // Or return [] if empty search should yield no results.
        }
        
        // Filter entries where the message or context contains the search text.
        return logEntries.filter { entry in
            entry.message.lowercased().contains(lowercasedSearchText) ||
            (entry.context?.lowercased().contains(lowercasedSearchText) ?? false)
        }
    }
}