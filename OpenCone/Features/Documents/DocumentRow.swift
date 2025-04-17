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
    // Create sample documents for preview
    let processedDoc = PreviewData.sampleDocuments[0]
    let errorDoc = PreviewData.sampleDocuments[1]
    let pendingDoc = PreviewData.sampleDocuments[2]

    return VStack(spacing: 10) {
        DocumentRow(document: processedDoc, isSelected: true)
        DocumentRow(document: errorDoc, isSelected: false)
        DocumentRow(document: pendingDoc, isSelected: false)
    }
    .padding()
    .withTheme()  // Apply theme for consistent preview
}
