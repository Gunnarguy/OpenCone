import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    @ObservedObject var viewModel: DocumentsViewModel

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Configure the document picker (allow specific types, multiple selection, etc.)
        // For now, let's allow common document types.
        // Define supported UTTypes using their identifiers
        // Using force unwrap (!) as these are standard, known types.
        let supportedTypes: [UTType] = [
            .pdf, .plainText, .utf8PlainText, .text, .rtf,
            UTType("com.microsoft.word.doc")!,                 // .doc
            UTType("org.openxmlformats.wordprocessingml.document")!, // .docx
            UTType("com.microsoft.excel.xls")!,                 // .xls
            UTType("org.openxmlformats.spreadsheetml.sheet")!, // .xlsx
            UTType("com.microsoft.powerpoint.ppt")!,            // .ppt
            UTType("org.openxmlformats.presentationml.presentation")! // .pptx
            // Add other relevant UTTypes if needed, e.g., .key for Keynote
        ]
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = true // Allow selecting multiple files
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No update needed for now
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Pass the selected URLs directly to the ViewModel.
            // The ViewModel's addDocument(at:) method is responsible for
            // handling security-scoped resource access.
            for url in urls {
                parent.viewModel.addDocument(at: url)
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Handle cancellation if needed
            print("Document picker was cancelled.")
        }
    }
}
