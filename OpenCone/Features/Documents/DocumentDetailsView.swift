import Charts
import SwiftUI

/// One document: what it is, where it was indexed, how long each step took, how its text was split,
/// and the log lines that mention it
struct DocumentDetailsView: View {
    let document: DocumentModel
    @ObservedObject private var logger = Logger.shared

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: document.viewIconName)
                        .font(.title2)
                        .foregroundStyle(tint)
                        .frame(width: 48, height: 48)
                        .background(tint.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(document.fileName)
                            .font(.headline)
                            .lineLimit(2)
                        Text("\(document.formattedFileSize) · \(document.mimeType)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                statusRow
            }

            if document.isProcessed {
                Section("Indexed") {
                    if let index = document.lastIndexedIndexName {
                        LabeledContent("Index", value: index)
                    }
                    if let namespace = document.lastIndexedNamespace {
                        LabeledContent("Namespace", value: namespace.isEmpty ? "Default namespace" : namespace)
                    }
                    LabeledContent("Passages", value: "\(document.chunkCount)")
                    if let date = document.lastIndexedAt {
                        LabeledContent("When") {
                            Text(date, format: .dateTime.day().month().year().hour().minute())
                        }
                    }
                }
            }

            if let stats = document.processingStats {
                timingSection(stats)
                passagesSection(stats)
            }

            Section("Log") {
                if documentLog.isEmpty {
                    Text("No log lines mention this document since OpenCone opened.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(documentLog) { entry in
                        LogEntryRow(entry: entry)
                            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(document.fileName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Status

    private var tint: Color {
        if document.processingError != nil { return .red }
        if document.isProcessed { return .green }
        return .accentColor
    }

    @ViewBuilder
    private var statusRow: some View {
        if let error = document.processingError {
            Label {
                Text("Indexing failed: \(error)")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.red)
            }
            .font(.subheadline)
        } else if document.isProcessed {
            Label {
                Text("Indexed, \(DocumentsView.passages(document.chunkCount))")
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
            }
            .font(.subheadline)
        } else {
            Label("Not indexed yet. Index it from the Documents list.", systemImage: "circle.dashed")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Timing

    private func timingSection(_ stats: DocumentProcessingStats) -> some View {
        Section {
            if !stats.phaseTimings.isEmpty {
                Chart(stats.phaseTimings) { phase in
                    BarMark(
                        x: .value("Seconds", phase.duration),
                        y: .value("Document", "time")
                    )
                    .foregroundStyle(by: .value("Step", phase.phase.shortName))
                }
                .chartYAxis(.hidden)
                .chartXAxisLabel("seconds")
                .chartLegend(position: .bottom, spacing: 8)
                .frame(height: 90)
                .padding(.vertical, 4)
                .accessibilityLabel("Time per step")
            }
            ForEach(stats.phaseTimings) { phase in
                LabeledContent(phase.phase.shortName, value: Self.duration(phase.duration))
            }
            LabeledContent("Total", value: Self.duration(stats.totalProcessingTime))
                .fontWeight(.semibold)
        } header: {
            Text("Time")
        }
    }

    // MARK: - Passages

    private func passagesSection(_ stats: DocumentProcessingStats) -> some View {
        Section {
            if !stats.chunkSizes.isEmpty {
                Chart {
                    ForEach(Array(stats.chunkSizes.enumerated()), id: \.offset) { position, size in
                        BarMark(
                            x: .value("Passage", position + 1),
                            y: .value("Characters", size)
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                    }
                }
                .chartXAxisLabel("passage")
                .chartYAxisLabel("characters")
                .frame(height: 160)
                .padding(.vertical, 4)
                .accessibilityLabel("Characters in each passage")
            }
            LabeledContent("Text read", value: "\(stats.extractedTextLength.formatted()) characters")
            LabeledContent("Tokens", value: stats.totalTokens.formatted())
            LabeledContent("Tokens per passage", value: String(format: "%.0f", stats.avgTokensPerChunk))
            LabeledContent("Stored in Pinecone", value: DocumentsView.passages(stats.vectorsUploaded))
        } header: {
            Text("Passages")
        }
    }

    // MARK: - Helpers

    /// Log lines that name this document
    private var documentLog: [ProcessingLogEntry] {
        logger.logEntries.filter { entry in
            entry.context?.contains(document.fileName) ?? false
        }
    }

    static func duration(_ seconds: TimeInterval) -> String {
        if seconds < 0.001 { return "<1 ms" }
        if seconds < 1 { return "\(Int(seconds * 1000)) ms" }
        if seconds < 60 { return String(format: "%.1f s", seconds) }
        return "\(Int(seconds) / 60) min \(Int(seconds) % 60) s"
    }
}

private extension DocumentProcessingStats.ProcessingPhase {
    var shortName: String {
        switch self {
        case .textExtraction: return "Read"
        case .chunking: return "Split"
        case .embeddingGeneration: return "Embed"
        case .vectorUpsert: return "Store"
        }
    }
}

#Preview {
    var stats = DocumentProcessingStats()
    let start = Date().addingTimeInterval(-120)
    stats.startTime = start
    stats.endTime = Date()
    stats.extractedTextLength = 50_000
    stats.totalTokens = 7_500
    stats.avgTokensPerChunk = 312.5
    stats.vectorsUploaded = 24
    stats.addPhase(phase: .textExtraction, start: start, end: start.addingTimeInterval(20))
    stats.addPhase(phase: .chunking, start: start.addingTimeInterval(20), end: start.addingTimeInterval(30))
    stats.addPhase(phase: .embeddingGeneration, start: start.addingTimeInterval(30), end: start.addingTimeInterval(80))
    stats.addPhase(phase: .vectorUpsert, start: start.addingTimeInterval(80), end: start.addingTimeInterval(120))
    stats.chunkSizes = (1...24).map { _ in Int.random(in: 500...2000) }

    var document = DocumentModel(
        fileName: "Baxter Sigma Spectrum Service Manual.pdf",
        filePath: URL(string: "file:///sample.pdf")!,
        mimeType: "application/pdf",
        fileSize: 1_048_576,
        dateAdded: Date(),
        isProcessed: true,
        chunkCount: 24
    )
    document.processingStats = stats
    document.lastIndexedIndexName = "manuals"
    document.lastIndexedNamespace = "baxter"
    document.lastIndexedAt = Date()
    return NavigationStack { DocumentDetailsView(document: document) }
}
