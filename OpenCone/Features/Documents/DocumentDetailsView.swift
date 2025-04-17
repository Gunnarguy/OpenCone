import Charts
import SwiftUI

/// View for displaying detailed document processing information
struct DocumentDetailsView: View {
    let document: DocumentModel
    @ObservedObject private var logger = Logger.shared
    @Environment(\.theme) private var theme  // Access the current theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Document Info Header
                documentHeader
                    .padding(.bottom, 8)

                if let stats = document.processingStats {
                    // Processing Timeline
                    processingTimeline(stats: stats)

                    // Processing Phase Details
                    processingPhases(stats: stats)

                    // Chunk Visualizations
                    chunkVisualization(stats: stats)

                    // Token Distribution Chart
                    tokenDistribution(stats: stats)

                    // Statistics Summary
                    statisticsSummary(stats: stats)
                } else {
                    if document.isProcessed {
                        Text("Processing completed, but detailed statistics are not available.")
                            .foregroundColor(theme.textSecondaryColor)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else if document.processingError != nil {
                        Text("Processing failed: \(document.processingError ?? "Unknown error")")
                            .foregroundColor(theme.errorColor)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        Text("This document has not been processed yet.")
                            .foregroundColor(theme.textSecondaryColor)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    }
                }

                // Document Logs
                documentLogs
            }
            .padding()
        }
        .background(theme.backgroundColor)
        .navigationTitle(document.fileName)
    }

    // MARK: - Document Header
    private var documentHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Document icon
                Image(systemName: document.viewIconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(document.viewIconColor)

                VStack(alignment: .leading) {
                    Text(document.fileName)
                        .font(.headline)
                        .foregroundColor(theme.textPrimaryColor)

                    HStack {
                        Text(document.mimeType)
                            .font(.caption)
                            .foregroundColor(theme.textSecondaryColor)

                        Text("•")
                            .font(.caption)
                            .foregroundColor(theme.textSecondaryColor)

                        Text(document.formattedFileSize)
                            .font(.caption)
                            .foregroundColor(theme.textSecondaryColor)

                        if document.isProcessed {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(theme.textSecondaryColor)

                            Text("\(document.chunkCount) chunks")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }

                Spacer()

                // Processing status
                statusBadge
            }

            Divider()
        }
    }

    // MARK: - Status Badge
    private var statusBadge: some View {
        Group {
            if document.isProcessed {
                Text("Processed")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(4)
            } else if document.processingError != nil {
                Text("Error")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.errorLight)
                    .foregroundColor(theme.errorColor)
                    .cornerRadius(4)
            } else {
                Text("Not Processed")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.gray)
                    .cornerRadius(4)
            }
        }
    }

    // MARK: - Processing Timeline
    private func processingTimeline(stats: DocumentProcessingStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Processing Timeline")
                .font(.headline)
                .foregroundColor(theme.textPrimaryColor)

            if let startTime = stats.startTime, let endTime = stats.endTime {
                let totalDuration = endTime.timeIntervalSince(startTime)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Total time: \(formattedDuration(totalDuration))")
                        .font(.subheadline)
                        .foregroundColor(theme.textPrimaryColor)

                    // Timeline visualization
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.cardBackgroundColor)
                            .frame(height: 24)

                        // Phase segments
                        HStack(spacing: 1) {
                            ForEach(stats.phaseTimings) { phase in
                                let proportionalWidth = phase.duration / totalDuration

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(colorForPhase(phase.phase))
                                    .frame(
                                        width: max(4, CGFloat(proportionalWidth) * 300), height: 24
                                    )
                                    .overlay(
                                        Text(phase.phase.rawValue.prefix(1))
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .padding(.horizontal, 4)
                                    )
                            }
                        }
                    }

                    // Legend
                    HStack {
                        ForEach(DocumentProcessingStats.ProcessingPhase.allCases, id: \.self) {
                            phase in
                            HStack {
                                Circle()
                                    .fill(colorForPhase(phase))
                                    .frame(width: 8, height: 8)

                                Text(phase.rawValue)
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondaryColor)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }

            Divider()
        }
    }

    // MARK: - Processing Phases
    private func processingPhases(stats: DocumentProcessingStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Processing Phases")
                .font(.headline)
                .foregroundColor(theme.textPrimaryColor)

            VStack(spacing: 8) {
                ForEach(stats.phaseTimings) { phase in
                    HStack {
                        Text(phase.phase.rawValue)
                            .font(.subheadline)
                            .foregroundColor(theme.textPrimaryColor)

                        Spacer()

                        Text(formattedDuration(phase.duration))
                            .font(.subheadline)
                            .foregroundColor(theme.textSecondaryColor)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorForPhase(phase.phase).opacity(0.1))
                    )
                }
            }

            Divider()
        }
    }

    // MARK: - Chunk Visualization
    private func chunkVisualization(stats: DocumentProcessingStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chunk Size Distribution")
                .font(.headline)
                .foregroundColor(theme.textPrimaryColor)

            if !stats.chunkSizes.isEmpty {
                Chart {
                    ForEach(Array(stats.chunkSizes.enumerated()), id: \.offset) { index, size in
                        BarMark(
                            x: .value("Chunk", index),
                            y: .value("Size", size)
                        )
                        .foregroundStyle(theme.primaryColor.opacity(0.7))
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(position: .bottom) { _ in
                        AxisValueLabel {
                            Text("Chunks")
                                .foregroundColor(theme.textSecondaryColor)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue) chars")
                                    .foregroundColor(theme.textSecondaryColor)
                            }
                        }
                    }
                }
            } else {
                Text("No chunk data available")
                    .foregroundColor(theme.textSecondaryColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }

            Divider()
        }
    }

    // MARK: - Token Distribution
    private func tokenDistribution(stats: DocumentProcessingStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Token Distribution")
                .font(.headline)
                .foregroundColor(theme.textPrimaryColor)

            if !stats.tokenDistribution.isEmpty {
                Chart {
                    ForEach(Array(stats.tokenDistribution.enumerated()), id: \.offset) {
                        index, tokens in
                        BarMark(
                            x: .value("Chunk", index),
                            y: .value("Tokens", tokens)
                        )
                        .foregroundStyle(theme.secondaryColor.opacity(0.7))
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(position: .bottom) { _ in
                        AxisValueLabel {
                            Text("Chunks")
                                .foregroundColor(theme.textSecondaryColor)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue) tokens")
                                    .foregroundColor(theme.textSecondaryColor)
                            }
                        }
                    }
                }
            } else {
                Text("No token data available")
                    .foregroundColor(theme.textSecondaryColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }

            Divider()
        }
    }

    // MARK: - Statistics Summary
    private func statisticsSummary(stats: DocumentProcessingStats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Processing Statistics")
                .font(.headline)
                .foregroundColor(theme.textPrimaryColor)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                statItem(label: "Text Length", value: "\(stats.extractedTextLength) chars")
                statItem(label: "Total Tokens", value: "\(stats.totalTokens)")
                statItem(
                    label: "Avg. Tokens/Chunk",
                    value: String(format: "%.1f", stats.avgTokensPerChunk))
                statItem(label: "Vectors Uploaded", value: "\(stats.vectorsUploaded)")
                statItem(
                    label: "Processing Time", value: formattedDuration(stats.totalProcessingTime))
                statItem(label: "Chunks Created", value: "\(stats.chunkSizes.count)")
            }

            Divider()
        }
    }

    // MARK: - Document Logs
    private var documentLogs: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Document Logs")
                .font(.headline)
                .foregroundColor(theme.textPrimaryColor)

            if filteredLogs.isEmpty {
                Text("No logs available for this document")
                    .foregroundColor(theme.textSecondaryColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(filteredLogs) { entry in
                    LogEntryRow(entry: entry)
                }
            }
        }
    }

    // MARK: - Helper Views

    /// Display a single statistic
    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(theme.textSecondaryColor)

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(theme.textPrimaryColor)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackgroundColor)
        .cornerRadius(8)
    }

    // MARK: - Helper Functions

    /// Format duration in seconds to a readable string
    private func formattedDuration(_ seconds: TimeInterval) -> String {
        if seconds < 0.001 {
            return "<1ms"
        } else if seconds < 1 {
            return "\(Int(seconds * 1000))ms"
        } else if seconds < 60 {
            return String(format: "%.2fs", seconds)
        } else {
            let minutes = Int(seconds) / 60
            let secs = Int(seconds) % 60
            return "\(minutes)m \(secs)s"
        }
    }

    /// Get color for processing phase
    private func colorForPhase(_ phase: DocumentProcessingStats.ProcessingPhase) -> Color {
        switch phase {
        case .textExtraction:
            return theme.primaryColor
        case .chunking:
            return .orange
        case .embeddingGeneration:
            return theme.secondaryColor
        case .vectorUpsert:
            return .green
        }
    }

    /// Filter logs relevant to this document
    private var filteredLogs: [ProcessingLogEntry] {
        logger.logEntries.filter { entry in
            entry.context?.contains(document.fileName) ?? false
        }
    }
}

struct DocumentDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        // Create sample document with processing stats for preview
        let document = DocumentModel(
            fileName: "sample.pdf",
            filePath: URL(string: "file:///sample.pdf")!,
            mimeType: "application/pdf",
            fileSize: 1024 * 1024,
            dateAdded: Date(),
            isProcessed: true,
            chunkCount: 24
        )

        // Create sample processing stats
        var stats = DocumentProcessingStats()
        stats.startTime = Date().addingTimeInterval(-120)  // 2 minutes ago
        stats.endTime = Date()
        stats.extractedTextLength = 50000
        stats.totalTokens = 7500
        stats.avgTokensPerChunk = 312.5
        stats.vectorsUploaded = 24

        // Add phase timings
        let baseTime = Date().addingTimeInterval(-120)
        stats.addPhase(
            phase: .textExtraction,
            start: baseTime,
            end: baseTime.addingTimeInterval(20)
        )
        stats.addPhase(
            phase: .chunking,
            start: baseTime.addingTimeInterval(20),
            end: baseTime.addingTimeInterval(30)
        )
        stats.addPhase(
            phase: .embeddingGeneration,
            start: baseTime.addingTimeInterval(30),
            end: baseTime.addingTimeInterval(80)
        )
        stats.addPhase(
            phase: .vectorUpsert,
            start: baseTime.addingTimeInterval(80),
            end: baseTime.addingTimeInterval(120)
        )

        // Add sample data for visualizations
        stats.chunkSizes = (1...24).map { _ in Int.random(in: 500...2000) }
        stats.tokenDistribution = (1...24).map { _ in Int.random(in: 200...500) }

        var documentWithStats = document
        documentWithStats.processingStats = stats

        // Add sample log entries
        let logger = Logger.shared
        logger.clearLogs()
        logger.log(level: .info, message: "Starting to process document", context: "sample.pdf")
        logger.log(
            level: .info, message: "Text extracted",
            context: "Document: sample.pdf, Size: 50000 characters")
        logger.log(
            level: .info, message: "Text chunked", context: "Document: sample.pdf, Chunks: 24")
        logger.log(
            level: .info, message: "Embeddings generated",
            context: "Document: sample.pdf, Embeddings: 24")
        logger.log(
            level: .info, message: "Upserting batch to Pinecone", context: "Batch: 1, Size: 24")
        logger.log(level: .info, message: "Batch upserted", context: "Upserted: 24")
        logger.log(
            level: .success, message: "Document processed successfully", context: "sample.pdf")

        return NavigationView {
            DocumentDetailsView(document: documentWithStats)
        }
    }
}

#Preview {
    // Use PreviewData to get a sample document
    let documentWithStats = PreviewData.sampleDocuments[0]  // Document with stats
    let documentWithoutStats = PreviewData.sampleDocuments[2]  // Pending document

    return Group {
        NavigationView {
            DocumentDetailsView(document: documentWithStats)
                .navigationTitle("Details (With Stats)")
                .withTheme()
        }

        NavigationView {
            DocumentDetailsView(document: documentWithoutStats)
                .navigationTitle("Details (No Stats)")
                .withTheme()
        }
    }
}
