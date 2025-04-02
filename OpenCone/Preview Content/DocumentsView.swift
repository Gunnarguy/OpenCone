import SwiftUI
import UniformTypeIdentifiers

/// View for document management and processing
struct DocumentsView: View {
    @ObservedObject var viewModel: DocumentsViewModel
    @State private var showingDocumentPicker = false
    @State private var showingNamespaceDialog = false
    @State private var newNamespace = ""
    
    var body: some View {
        VStack {
            // Index and Namespace Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Pinecone Configuration")
                    .font(.headline)
                    .padding(.top, 4)
                
                HStack {
                    Picker("Index:", selection: $viewModel.selectedIndex.toUnwrapped(defaultValue: "")) {
                        Text("Select Index").tag("")
                        ForEach(viewModel.pineconeIndexes, id: \.self) { index in
                            Text(index).tag(index)
                        }
                    }
                    .onChange(of: viewModel.selectedIndex) { oldValue, newValue in
                        if let index = newValue, !index.isEmpty {
                            Task {
                                await viewModel.setIndex(index)
                            }
                        }
                    }
                    
                    Button(action: {
                        Task {
                            await viewModel.loadIndexes()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isProcessing)
                }
                
                HStack {
                    Picker("Namespace:", selection: $viewModel.selectedNamespace.toUnwrapped(defaultValue: "")) {
                        Text("Default namespace").tag("")
                        ForEach(viewModel.namespaces, id: \.self) { namespace in
                            Text(namespace).tag(namespace)
                        }
                    }
                    .onChange(of: viewModel.selectedNamespace) { oldValue, newValue in
                        viewModel.setNamespace(newValue)
                    }
                    
                    Button(action: {
                        showingNamespaceDialog = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .disabled(viewModel.isProcessing)
                    
                    Button(action: {
                        Task {
                            await viewModel.loadNamespaces()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isProcessing)
                }
            }
            .padding(.horizontal)
            
            // Document List
            if viewModel.documents.isEmpty {
                VStack {
                    Spacer()
                    Text("No documents added yet")
                        .foregroundColor(.secondary)
                    Text("Tap the '+' button to add documents")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(viewModel.documents) { document in
                        HStack {
                            // Main document info with selection capability
                            DocumentRow(document: document, isSelected: viewModel.selectedDocuments.contains(document.id))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.toggleDocumentSelection(document.id)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Details button as separate element
                            NavigationLink(destination: DocumentDetailsView(document: document)) {
                                Text("Details")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .padding(.trailing, 8)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
            
            // Processing Status
            if viewModel.isProcessing {
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.processingProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    if let stats = viewModel.processingStats {
                        HStack {
                            Text("Documents: \(stats.totalDocuments)")
                            Spacer()
                            Text("Chunks: \(stats.totalChunks)")
                            Spacer()
                            Text("Vectors: \(stats.totalVectors)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            
            // Action Buttons
            HStack {
                Button(action: {
                    Task {
                        await viewModel.processSelectedDocuments()
                    }
                }) {
                    Label("Process", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.selectedDocuments.isEmpty || viewModel.isProcessing || viewModel.selectedIndex == nil)
                
                Button(action: {
                    viewModel.removeSelectedDocuments()
                }) {
                    Label("Remove", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(viewModel.selectedDocuments.isEmpty || viewModel.isProcessing)
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingDocumentPicker = true
                }) {
                    Image(systemName: "plus")
                }
                .disabled(viewModel.isProcessing)
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(viewModel: viewModel)
        }
        .alert("Create Namespace", isPresented: $showingNamespaceDialog) {
            TextField("Namespace Name", text: $newNamespace)
            Button("Cancel", role: .cancel) {
                newNamespace = ""
            }
            Button("Create") {
                if !newNamespace.isEmpty {
                    viewModel.createNamespace(newNamespace)
                    newNamespace = ""
                }
            }
        } message: {
            Text("Enter a name for the new namespace:")
        }
    }
}

/// Row for displaying document information in the list
struct DocumentRow: View {
    let document: DocumentModel
    let isSelected: Bool
    
    var body: some View {
        HStack {
            // Document Icon
            Image(systemName: iconForDocument(document))
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(colorForDocument(document))
            
            // Document Information
            VStack(alignment: .leading, spacing: 4) {
                Text(document.fileName)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Text(document.mimeType)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formattedFileSize(document.fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if document.isProcessed {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(document.chunkCount) chunks")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    if let error = document.processingError {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Error: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Selection Indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
    
    /// Get icon for document based on MIME type
    private func iconForDocument(_ document: DocumentModel) -> String {
        if document.mimeType.contains("pdf") {
            return "doc.fill"
        } else if document.mimeType.contains("text") || document.mimeType.contains("markdown") {
            return "doc.text.fill"
        } else if document.mimeType.contains("image") {
            return "photo.fill"
        } else {
            return "doc.fill"
        }
    }
    
    /// Get color for document icon based on processing status
    private func colorForDocument(_ document: DocumentModel) -> Color {
        if document.processingError != nil {
            return .red
        } else if document.isProcessed {
            return .green
        } else {
            return .blue
        }
    }
    
    /// Format file size for display
    private func formattedFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

/// Document picker for selecting files
struct DocumentPicker: UIViewControllerRepresentable {
    @ObservedObject var viewModel: DocumentsViewModel
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Base list of supported types
        let supportedTypes: [UTType] = [ // Changed var to let
            .pdf,
            .plainText,
            .image,
            .jpeg,
            .png,
            .rtf,
            .html
        ]
        // Removed attempt to add markdown type due to persistent compiler errors

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                parent.viewModel.addDocument(at: url)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// Extension to handle optional binding for Picker
extension Binding where Value == String? {
    func toUnwrapped(defaultValue: String) -> Binding<String> {
        Binding<String>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0 }
        )
    }
}

#Preview {
    documentsPreview()
}

/// Helper function to create preview for DocumentsView
private func documentsPreview() -> some View {
    let fileProcessorService = FileProcessorService()
    let textProcessorService = TextProcessorService()
    let openAIService = OpenAIService(apiKey: "preview-key")
    // Updated PineconeService initialization for preview
    let pineconeService = PineconeService(apiKey: "preview-key")
    let embeddingService = EmbeddingService(openAIService: openAIService)
    
    let viewModel = DocumentsViewModel(
        fileProcessorService: fileProcessorService,
        textProcessorService: textProcessorService,
        embeddingService: embeddingService,
        pineconeService: pineconeService
    )
    
    // Add sample documents for preview
    let sampleDoc1 = DocumentModel(
        fileName: "sample1.pdf",
        filePath: URL(string: "file:///sample1.pdf")!,
        mimeType: "application/pdf",
        fileSize: 1024 * 1024,
        dateAdded: Date(),
        isProcessed: true,
        chunkCount: 24
    )
    
    let sampleDoc2 = DocumentModel(
        fileName: "sample2.txt",
        filePath: URL(string: "file:///sample2.txt")!,
        mimeType: "text/plain",
        fileSize: 512 * 1024,
        dateAdded: Date(),
        isProcessed: false,
        processingError: "Processing failed"
    )
    
    viewModel.documents = [sampleDoc1, sampleDoc2]
    
    return NavigationView {
        DocumentsView(viewModel: viewModel)
            .navigationTitle("Documents")
    }
}
