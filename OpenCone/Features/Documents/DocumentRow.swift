import SwiftUI

/// Row for displaying document information in the list
struct DocumentRow: View {
    // MARK: - Properties
    let document: DocumentModel
    let isSelected: Bool
    @Environment(\.theme) private var theme  // Access the current theme

    // MARK: - View Body
    var body: some View {
        HStack(spacing: 12) {
            // Document type icon with background
            ZStack {
                Circle()
                    .fill(document.viewIconColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: document.viewIconName)
                    .foregroundColor(document.viewIconColor)
            }

            // Document metadata information
            documentInfo

            Spacer()

            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(theme.primaryColor)
                    .font(.system(size: 20))
            }
        }
    }

    // MARK: - UI Components

    /// Document information display
    private var documentInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Document filename
            Text(document.fileName)
                .font(.headline)
                .foregroundColor(theme.textPrimaryColor)
                .lineLimit(1)

            // Document metadata row
            HStack(spacing: 6) {
                if document.isProcessed {
                    processingTag
                } else if document.processingError != nil {
                    errorTag
                }

                metadataText(document.mimeType)
                metadataDivider
                metadataText(document.formattedFileSize)

                // Chunk count for processed documents
                if document.isProcessed {
                    metadataDivider
                    HStack(spacing: 2) {
                        Image(systemName: "square.on.square")
                            .font(.system(size: 10))
                            .foregroundColor(.green.opacity(0.8))

                        Text("\(document.chunkCount)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }

    // MARK: - Internal Helper Views/Functions for DocumentRow

    /// Tag showing processed status
    private var processingTag: some View {
        Text("Processed")
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.15))
            )
            .foregroundColor(.green)
    }

    /// Tag showing error status
    private var errorTag: some View {
        Text("Error")
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(theme.errorLight)
            )
            .foregroundColor(theme.errorColor)
    }

    /// Metadata divider dot
    private var metadataDivider: some View {
        Text("•")
            .font(.caption)
            .foregroundColor(theme.textSecondaryColor)
    }

    /// Helper function for consistent metadata text styling
    private func metadataText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(theme.textSecondaryColor)
    }

}  // End of DocumentRow struct

#Preview {
    // Define sample DocumentModel instances directly
    // Ensure these initializers match your actual DocumentModel definition
    let processedDoc = DocumentModel(
        fileName: "processed_preview.pdf",
        filePath: URL(string: "file:///processed_preview.pdf")!,
        securityBookmark: nil,
        mimeType: "application/pdf",
        fileSize: 1024,
        dateAdded: Date(),
        isProcessed: true,
        processingError: nil as String?, // Corrected order and explicit type for nil
        chunkCount: 5,
        processingStats: nil as DocumentProcessingStats? // Explicit type for nil
    )

    let errorDoc = DocumentModel(
        fileName: "error_preview.doc",
        filePath: URL(string: "file:///error_preview.doc")!,
        securityBookmark: nil,
        mimeType: "application/msword",
        fileSize: 512,
        dateAdded: Date().addingTimeInterval(-86400), // 1 day ago
        isProcessed: false,
        processingError: "Preview error text", // Corrected order
        chunkCount: 0,
        processingStats: nil as DocumentProcessingStats? // Explicit type for nil
    )

    let pendingDoc = DocumentModel(
        fileName: "pending_preview.txt",
        filePath: URL(string: "file:///pending_preview.txt")!,
        securityBookmark: nil,
        mimeType: "text/plain",
        fileSize: 100,
        dateAdded: Date().addingTimeInterval(-172800), // 2 days ago
        isProcessed: false,
        processingError: nil as String?, // Corrected order and explicit type for nil
        chunkCount: 0,
        processingStats: nil as DocumentProcessingStats? // Explicit type for nil
    )

    Group {
        VStack(spacing: 10) {
            DocumentRow(document: processedDoc, isSelected: true)
            DocumentRow(document: errorDoc, isSelected: false)
            DocumentRow(document: pendingDoc, isSelected: false)
        }
        .padding()
        .withTheme() // Assuming .withTheme() is a valid ViewModifier
    }
}
