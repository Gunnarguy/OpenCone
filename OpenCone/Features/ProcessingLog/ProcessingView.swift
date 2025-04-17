import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Import the explicit files containing the required types
// without needing to reorganize project structure
import Foundation
// Note: Swift doesn't support file imports directly, so we
// need to use typealias to handle visibilty of types from
// other files in the same module

/// View for displaying processing logs, driven by a ViewModel.
struct ProcessingView: View {
    @StateObject private var viewModel = ProcessingViewModel() // Use StateObject for ViewModel lifecycle

    var body: some View {
        VStack {
            // Filter Controls
            // Filter Controls - Bind to ViewModel
            FilterBar(
                filterLevel: $viewModel.filterLevel,
                searchText: $viewModel.searchText,
                resetAction: viewModel.resetFilters
            )
            
            // Log Entries
            // Log Entries - Use ViewModel data
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.filteredLogs) { entry in // Iterate viewModel data
                            LogEntryRow(entry: entry)
                                .id(entry.id)
                        }
                        
                        // Bottom spacer for auto-scrolling
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding(.horizontal)
                }
                .onChange(of: viewModel.logEntries.count) { // Observe viewModel's total count
                    if viewModel.autoScroll { // Use viewModel state
                        withAnimation {
                            scrollView.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
            
            // Bottom Controls - Bind to ViewModel
            HStack {
                Toggle(isOn: $viewModel.autoScroll) { // Bind to viewModel
                    Text("Auto-scroll")
                        .font(.caption)
                }
                
                Spacer()
                
                Button(action: viewModel.clearLogs) { // Call viewModel method
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                
                Button(action: viewModel.prepareAndShowExport) { // Call viewModel method
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Text("\(viewModel.filteredLogs.count) entries") // Use viewModel data
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $viewModel.showingExportOptions) { // Bind to viewModel
            // Pass the pre-formatted string from the ViewModel
            LogExportView(logs: viewModel.exportLogString)
        }
        // No need for the filteredLogs computed property here anymore
    }
}

// LogEntryRow remains the same

// LogExportView remains the same for now, but could be simplified later

/// Row for displaying a log entry
struct LogEntryRow: View {
    let entry: ProcessingLogEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Timestamp and Level
            HStack {
                Text(formattedTime(entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(entry.level.rawValue)
                    .font(.caption.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(entry.level.color.opacity(0.2))
                    .foregroundColor(entry.level.color)
                    .cornerRadius(4)
                
                Spacer()
            }
            
            // Message
            Text(entry.message)
                .font(.body)
                .foregroundColor(.primary)
            
            // Context (if available)
            if let context = entry.context {
                Text(context)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
    
    /// Format timestamp for display
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}

/// View for exporting logs
struct LogExportView: View {
    let logs: String
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    Text(logs)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
                
                HStack {
                    Button(action: {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = logs
                        #endif
                    }) {
                        Label("Copy to Clipboard", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        shareLogs()
                    }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle("Export Logs")
            // Fix navigationBarItems which is unavailable in macOS
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }

    /// Share logs using activity view controller
    private func shareLogs() {
        #if canImport(UIKit)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        let filename = "OpenCone_Logs_\(formattedDate()).txt"
        guard let data = logs.data(using: .utf8) else { return }
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: tempURL)
            
            let activityViewController = UIActivityViewController(
                activityItems: [tempURL],
                applicationActivities: nil
            )
            
            if let popoverController = activityViewController.popoverPresentationController {
                popoverController.sourceView = window
                popoverController.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            
            rootViewController.present(activityViewController, animated: true)
        } catch {
            print("Error writing log file: \(error.localizedDescription)")
        }
        #endif
    }
    
    /// Format current date for filename
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}

#Preview {
    // Use PreviewData to create the sample view model
    // let viewModel = PreviewData.sampleProcessingViewModel // Remove this line

    // No explicit return needed
    NavigationView {
        ProcessingView() // Use the default initializer
            .navigationTitle("Processing Log")
            .withTheme() // Apply theme for consistent preview
    }
}

/// A reusable bar for selecting log level, searching text, and resetting filters.
struct FilterBar: View {
    @Binding var filterLevel: ProcessingLogEntry.LogLevel?
    @Binding var searchText: String
    let resetAction: () -> Void

    var body: some View {
        HStack {
            Menu {
                Button("All Levels") { filterLevel = nil }
                Divider()
                ForEach(ProcessingLogEntry.LogLevel.allCases, id: \.self) { level in
                    Button(level.rawValue) { filterLevel = level }
                }
            } label: {
                HStack {
                    Text(filterLevel?.rawValue ?? "All Levels")
                    Image(systemName: "chevron.down").font(.caption)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1)) // replaced systemGray6
                .cornerRadius(8)
            }

            TextField("Search Logs", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button(action: resetAction) {
                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
            }
            .disabled(searchText.isEmpty && filterLevel == nil)
        }
        .padding(.horizontal)
    }
}
