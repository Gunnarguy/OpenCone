import SwiftUI
import Foundation // Needed for ByteCountFormatter

extension DocumentModel {
    
    /// Provides the system icon name based on the document's MIME type.
    var viewIconName: String {
        if mimeType.contains("pdf") {
            return "doc.fill"
        } else if mimeType.contains("text") || mimeType.contains("markdown") {
            return "doc.text.fill"
        } else if mimeType.contains("image") {
            return "photo.fill"
        } else if mimeType.contains("wordprocessingml") || mimeType.contains("msword") { // docx, doc
            return "doc.richtext.fill"
        } else if mimeType.contains("spreadsheetml") || mimeType.contains("excel") { // xlsx, xls
            return "tablecells.fill"
        } else if mimeType.contains("presentationml") || mimeType.contains("powerpoint") { // pptx, ppt
            return "display.fill"
        } else {
            return "doc.fill" // Default icon
        }
    }
    
    /// Provides the appropriate color based on the document's processing status.
    var viewIconColor: Color {
        if processingError != nil {
            return .red
        } else if isProcessed {
            return .green
        } else {
            return .blue // Default/pending color
        }
    }
    
    /// Provides a user-friendly formatted string for the file size.
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}
