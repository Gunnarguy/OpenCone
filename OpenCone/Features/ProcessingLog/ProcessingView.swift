import SwiftUI
import UIKit // Add import for LogExportView functionality

/// View for displaying processing logs, driven by a ViewModel.
struct ProcessingView: View {
    @StateObject private var viewModel = ProcessingViewModel() // Use StateObject for ViewModel lifecycle

    var body: some View {
        VStack {
            // Filter Controls
            // Filter Controls - Bind to ViewModel
            HStack {
                Menu {
                    Button("All Levels") {
                        viewModel.filterLevel = nil
                    }
                    
                    Divider()
                    
                    ForEach(ProcessingLogEntry.LogLevel.allCases, id: \.self) { level in
                        Button(level.rawValue) {
                            viewModel.filterLevel = level
                        }
                    }
                } label: {
                    HStack {
                        Text(viewModel.filterLevel?.rawValue ?? "All Levels") // Use viewModel state
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                TextField("Search Logs", text: $viewModel.searchText) // Bind to viewModel
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: viewModel.resetFilters) { // Call viewModel method
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .disabled(viewModel.searchText.isEmpty && viewModel.filterLevel == nil) // Use viewModel state
            }
            .padding(.horizontal)
            
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

#Preview {
    // Perform setup actions *before* returning the View
    let setupPreview: () -> Void = {
        // Add sample log entries directly via the shared logger
        // The ProcessingView's @StateObject will create its own ViewModel instance,
        // which will then subscribe to Logger.shared updates.
        let logger = Logger.shared // Assuming Logger is accessible here for preview setup
        logger.clearLogs() // Clear previous preview logs if any
        logger.log(level: .info, message: "Application started (Preview)")
        logger.log(level: .info, message: "Loading documents", context: "DocumentsViewModel (Preview)")
        logger.log(level: .warning, message: "Missing metadata for document", context: "sample.pdf (Preview)")
        logger.log(level: .error, message: "Failed to extract text from document", context: "Error: File not found (Preview)")
        logger.log(level: .success, message: "Successfully processed document", context: "Chunks: 24, Vectors: 24 (Preview)")
    }
    
    // Execute the setup
    setupPreview()
    
    // Return the View for the preview
    return NavigationView { // Explicit return is fine here, outside the setup closure
        ProcessingView() // Instantiate the view directly; @StateObject handles ViewModel creation
            .navigationTitle("Processing Log")
    }
}

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
        .background(Color(.systemGray6))
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
                        UIPasteboard.general.string = logs
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
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    /// Share logs using activity view controller
    private func shareLogs() {
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
    }
    
    /// Format current date for filename
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
}

#Preview {
    // Create sample log entries for preview
    let logger = Logger.shared
    logger.clearLogs()
    
    logger.log(level: .info, message: "Application started")
    logger.log(level: .info, message: "Loading documents", context: "DocumentsViewModel")
    logger.log(level: .warning, message: "Missing metadata for document", context: "sample.pdf")
    logger.log(level: .error, message: "Failed to extract text from document", context: "Error: File not found")
    logger.log(level: .success, message: "Successfully processed document", context: "Chunks: 24, Vectors: 24")
    
    return NavigationView {
        ProcessingView()
            .navigationTitle("Processing Log")
    }
}
