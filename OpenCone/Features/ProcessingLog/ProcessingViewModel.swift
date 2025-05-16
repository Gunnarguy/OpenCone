import SwiftUI
import Combine
import Foundation // For Date, etc. - Logger likely uses it.

// Assuming Logger and ProcessingLogEntry are defined elsewhere, possibly Core
// If they are in a specific module/file, adjust the import if needed.

/// ViewModel for managing the state and logic of the Processing Log view.
@MainActor
class ProcessingViewModel: ObservableObject {
    @Published var logEntries: [ProcessingLogEntry] = []
    @Published var filteredLogs: [ProcessingLogEntry] = []
    @Published var filterLevel: ProcessingLogEntry.LogLevel? = nil {
        didSet { applyFilters() }
    }
    @Published var searchText = "" {
        didSet { applyFilters() }
    }
    @Published var autoScroll = true
    @Published var showingExportOptions = false
    @Published var exportLogString = ""

    private var loggerCancellable: AnyCancellable?
    private let logger = Logger.shared // Keep a reference to the shared logger

    init(logger: Logger = .shared) { // Allow injecting logger for testing
        // Subscribe to logger updates
        // Subscribe to logger updates
        loggerCancellable = logger.$logEntries
            .receive(on: DispatchQueue.main) // Ensure updates are on the main thread
            .sink { [weak self] (newEntries: [ProcessingLogEntry]) in // Explicitly type newEntries
                guard let self = self else { return }
                self.logEntries = newEntries
                self.applyFilters() // Re-apply filters when logs change
            }
        
        // Initial load and filter
        self.logEntries = logger.logEntries
        self.applyFilters()
    }

    /// Applies the current search text and filter level to the log entries.
    private func applyFilters() {
        var logs = logEntries

        // Apply level filter
        if let level = filterLevel {
            logs = logs.filter { $0.level == level }
        }

        // Apply search filter
        if !searchText.isEmpty {
            logs = logs.filter {
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                ($0.context?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        self.filteredLogs = logs
    }

    /// Clears all log entries.
    func clearLogs() {
        logger.clearLogs()
        // The sink subscription will automatically update logEntries and filteredLogs
    }
    
    /// Resets the filters to default state.
    func resetFilters() {
        searchText = ""
        filterLevel = nil
        // applyFilters() is called automatically by the didSet observers
    }

    /// Prepares the log string for export and shows the export sheet.
    func prepareAndShowExport() {
        self.exportLogString = logger.exportLogs()
        self.showingExportOptions = true
    }
}
