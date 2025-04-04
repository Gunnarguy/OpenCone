import SwiftUI

/// View for displaying processing logs
struct ProcessingView: View {
    @ObservedObject private var logger = Logger.shared
    @State private var filterLevel: ProcessingLogEntry.LogLevel? = nil
    @State private var searchText = ""
    @State private var showingExportOptions = false
    @State private var autoScroll = true
    
    var body: some View {
        VStack {
            // Filter Controls
            HStack {
                Menu {
                    Button("All Levels") {
                        filterLevel = nil
                    }
                    
                    Divider()
                    
                    ForEach(ProcessingLogEntry.LogLevel.allCases, id: \.self) { level in
                        Button(level.rawValue) {
                            filterLevel = level
                        }
                    }
                } label: {
                    HStack {
                        Text(filterLevel?.rawValue ?? "All Levels")
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                TextField("Search Logs", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: {
                    searchText = ""
                    filterLevel = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .disabled(searchText.isEmpty && filterLevel == nil)
            }
            .padding(.horizontal)
            
            // Log Entries
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredLogs) { entry in
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
                .onChange(of: logger.logEntries.count) { oldValue, newValue in
                    if autoScroll {
                        withAnimation {
                            scrollView.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
            
            // Bottom Controls
            HStack {
                Toggle(isOn: $autoScroll) {
                    Text("Auto-scroll")
                        .font(.caption)
                }
                
                Spacer()
                
                Button(action: {
                    logger.clearLogs()
                }) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    showingExportOptions = true
                }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Text("\(filteredLogs.count) entries")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingExportOptions) {
            LogExportView(logs: logger.exportLogs())
        }
    }
    
    /// Filter logs based on search text and level filter
    private var filteredLogs: [ProcessingLogEntry] {
        var logs = logger.logEntries
        
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
        
        return logs
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
    private let logger = Logger.shared
    
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
            logger.log(level: .error, message: "Error writing log file: \(error.localizedDescription)")
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
