import SwiftUI
import UniformTypeIdentifiers

/// View for document management and processing
/// Allows users to select Pinecone indexes, manage namespaces, and process documents
struct DocumentsView: View {
    // MARK: - Properties
    @ObservedObject var viewModel: DocumentsViewModel
    @State private var showingDocumentPicker = false
    @State private var showingNamespaceDialog = false
    @State private var newNamespace = ""
    
    // MARK: - View Body
    var body: some View {
        VStack {
            // Configuration section for Pinecone settings
            configurationSection
            
            // Document list or empty state message
            documentListSection
            
            // Processing status indicator when documents are being processed
            processingStatusSection
            
            // Action buttons for document operations
            actionButtonsSection
        }
        .toolbar {
            addDocumentToolbarItem
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(viewModel: viewModel)
        }
        .alert("Create Namespace", isPresented: $showingNamespaceDialog) {
            namespaceDialogContent
        } message: {
            Text("Enter a name for the new namespace:")
        }
    }
    
    // MARK: - UI Components
    
    /// Configuration section for Pinecone index and namespace selection
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pinecone Configuration")
                .font(.headline)
                .padding(.top, 4)
            
            // Index selector with refresh button
            indexSelectorRow
            
            // Namespace selector with add and refresh buttons
            namespaceSelectorRow
        }
        .padding(.horizontal)
    }
    
    /// Row for selecting Pinecone index
    private var indexSelectorRow: some View {
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
            
            // Refresh indexes button
            Button(action: {
                Task {
                    await viewModel.loadIndexes()
                }
            }) {
                Image(systemName: "arrow.clockwise")
            }
            .disabled(viewModel.isProcessing)
        }
    }
    
    /// Row for selecting or creating a namespace
    private var namespaceSelectorRow: some View {
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
            
            // Create namespace button
            Button(action: {
                showingNamespaceDialog = true
            }) {
                Image(systemName: "plus")
            }
            .disabled(viewModel.isProcessing)
            
            // Refresh namespaces button
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
    
    /// Section for displaying document list or empty state
    private var documentListSection: some View {
        Group {
            if viewModel.documents.isEmpty {
                emptyDocumentsView
            } else {
                documentsListView
            }
        }
    }
    
    /// Empty state view when no documents are present
    private var emptyDocumentsView: some View {
        VStack {
            Spacer()
            Text("No documents added yet")
                .foregroundColor(.secondary)
            Text("Tap the '+' button to add documents")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    /// List view for displaying documents
    private var documentsListView: some View {
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
                    
                    // Details button for accessing document details
                    documentDetailsButton(for: document)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    /// Button for navigating to document details
    private func documentDetailsButton(for document: DocumentModel) -> some View {
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
    
    /// Section showing processing status and progress
    private var processingStatusSection: some View {
        Group {
            if viewModel.isProcessing {
                VStack(spacing: 8) {
                    // Progress bar for document processing
                    ProgressView(value: viewModel.processingProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    // Processing statistics summary
                    if let stats = viewModel.processingStats {
                        processingStatsView(stats)
                    }
                }
                .padding()
            }
        }
    }
    
    /// View for displaying processing statistics
    private func processingStatsView(_ stats: DocumentsViewModel.ProcessingStats) -> some View {
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
    
    /// Section containing action buttons for documents
    private var actionButtonsSection: some View {
        HStack {
            // Process button to start document processing
            processButton
            
            // Remove button to delete selected documents
            removeButton
        }
        .padding()
    }
    
    /// Button for processing selected documents
    private var processButton: some View {
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
    }
    
    /// Button for removing selected documents
    private var removeButton: some View {
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
    
    /// Toolbar item for adding new documents
    private var addDocumentToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
                showingDocumentPicker = true
            }) {
                Image(systemName: "plus")
            }
            .disabled(viewModel.isProcessing)
        }
    }
    
    /// Content for the namespace creation dialog
    private var namespaceDialogContent: some View {
        Group {
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
        }
    }
}

/// Row for displaying document information in the list
struct DocumentRow: View {
    // MARK: - Properties
    let document: DocumentModel
    let isSelected: Bool
    
    // MARK: - View Body
    var body: some View {
        HStack {
            // Document type icon
            documentIcon
            
            // Document metadata information
            documentInfo
            
            Spacer()
            
            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - UI Components
    
    /// Document icon based on file type
    private var documentIcon: some View {
        Image(systemName: iconForDocument(document))
            .resizable()
            .scaledToFit()
            .frame(width: 24, height: 24)
            .foregroundColor(colorForDocument(document))
    }
    
    /// Document information display
    private var documentInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Document filename
            Text(document.fileName)
                .font(.headline)
                .lineLimit(1)
            
            // Document metadata row
            HStack {
                metadataText(document.mimeType)
                metadataDivider
                metadataText(formattedFileSize(document.fileSize))
                
                // Chunk count for processed documents
                if document.isProcessed {
                    metadataDivider
                    Text("\(document.chunkCount) chunks")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                // Error message if processing failed
                if let error = document.processingError {
                    metadataDivider
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
            }
        }
    }
    
    /// Metadata divider dot
    private var metadataDivider: some View {
        Text("•")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    /// Helper function for consistent metadata text styling
    private func metadataText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    // MARK: - Helper Functions
    
    /// Determine appropriate icon based on document MIME type
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
    
    /// Select color for document icon based on processing status
    private func colorForDocument(_ document: DocumentModel) -> Color {
        if document.processingError != nil {
            return .red
        } else if document.isProcessed {
            return .green
        } else {
            return .blue
        }
    }
    
    /// Format file size with appropriate units
    private func formattedFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

/// Document picker for selecting files from the file system
struct DocumentPicker: UIViewControllerRepresentable {
    // MARK: - Properties
    @ObservedObject var viewModel: DocumentsViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - UIViewControllerRepresentable Implementation
    
    /// Create the document picker controller
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Define supported file types
        let supportedTypes: [UTType] = [
            .pdf,
            .plainText,
            .image,
            .jpeg,
            .png,
            .rtf,
            .html
        ]

        // Configure the picker
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    /// Create the coordinator to handle picker events
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    /// Coordinator class to handle UIDocumentPickerDelegate callbacks
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        /// Handle selected documents
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                parent.viewModel.addDocument(at: url)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Extensions

/// Extension to handle optional binding for Picker
extension Binding where Value == String? {
    /// Convert optional String binding to non-optional with a default value
    func toUnwrapped(defaultValue: String) -> Binding<String> {
        Binding<String>(
            get: { self.wrappedValue ?? defaultValue },
            set: { self.wrappedValue = $0 }
        )
    }
}

// MARK: - Preview

#Preview {
    documentsPreview()
}

/// Helper function to create preview for DocumentsView
private func documentsPreview() -> some View {
    // Initialize services for preview
    let fileProcessorService = FileProcessorService()
    let textProcessorService = TextProcessorService()
    let openAIService = OpenAIService(apiKey: "preview-key")
    let pineconeService = PineconeService(apiKey: "preview-key", projectId: "preview-project-id")
    let embeddingService = EmbeddingService(openAIService: openAIService)
    
    // Set up view model with sample data
    let viewModel = DocumentsViewModel(
        fileProcessorService: fileProcessorService,
        textProcessorService: textProcessorService,
        embeddingService: embeddingService,
        pineconeService: pineconeService
    )
    
    // Create sample processed document
    let sampleDoc1 = DocumentModel(
        fileName: "sample1.pdf",
        filePath: URL(string: "file:///sample1.pdf")!,
        mimeType: "application/pdf",
        fileSize: 1024 * 1024,
        dateAdded: Date(),
        isProcessed: true,
        chunkCount: 24
    )
    
    // Create sample document with error
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