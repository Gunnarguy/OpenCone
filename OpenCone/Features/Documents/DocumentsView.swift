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
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - View Body
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Configuration section for Pinecone settings
                configurationSection
                
                // Document list or empty state message
                documentListSection
                
                // Processing status indicator when documents are being processed
                processingStatusSection
                
                // Action buttons for document operations
                actionButtonsSection
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
        .animation(.easeInOut(duration: 0.2), value: viewModel.isProcessing)
        .animation(.easeInOut(duration: 0.2), value: viewModel.documents.count)
    }
    
    // MARK: - UI Components
    
    /// Configuration section for Pinecone index and namespace selection
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pinecone Configuration")
                .font(.headline)
                .padding(.top, 4)
            
            VStack(spacing: 12) {
                // Index selector with refresh button
                configCard {
                    indexSelectorRow
                }
                
                // Namespace selector with add and refresh buttons
                configCard {
                    namespaceSelectorRow
                }
            }
        }
        .padding(.top, 8)
    }
    
    /// Card container for configuration items
    private func configCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
    }
    
    /// Row for selecting Pinecone index
    private var indexSelectorRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "server.rack")
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Picker("Index:", selection: $viewModel.selectedIndex.toUnwrapped(defaultValue: "")) {
                Text("Select Index").tag("")
                ForEach(viewModel.pineconeIndexes, id: \.self) { index in
                    Text(index).tag(index)
                }
            }
            .frame(maxWidth: .infinity)
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
                    .foregroundColor(.blue)
                    .padding(8)
                    .background(Circle().fill(Color.blue.opacity(0.1)))
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.isProcessing)
        }
    }
    
    /// Row for selecting or creating a namespace
    private var namespaceSelectorRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .foregroundColor(.blue)
                .frame(width: 24)
                
            Picker("Namespace:", selection: $viewModel.selectedNamespace.toUnwrapped(defaultValue: "")) {
                Text("Default namespace").tag("")
                ForEach(viewModel.namespaces, id: \.self) { namespace in
                    Text(namespace).tag(namespace)
                }
            }
            .frame(maxWidth: .infinity)
            .onChange(of: viewModel.selectedNamespace) { oldValue, newValue in
                viewModel.setNamespace(newValue)
            }
            
            HStack(spacing: 8) {
                // Create namespace button
                Button(action: {
                    showingNamespaceDialog = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Circle().fill(Color.blue.opacity(0.1)))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.isProcessing)
                
                // Refresh namespaces button
                Button(action: {
                    Task {
                        await viewModel.loadNamespaces()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Circle().fill(Color.blue.opacity(0.1)))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.isProcessing)
            }
        }
    }
    
    /// Section for displaying document list or empty state
    private var documentListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Documents")
                .font(.headline)
            
            if viewModel.documents.isEmpty {
                emptyDocumentsView
            } else {
                documentsListView
            }
        }
    }
    
    /// Empty state view when no documents are present
    private var emptyDocumentsView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "doc.badge.plus")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundColor(.blue.opacity(0.7))
                .padding(24)
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                )
            
            VStack(spacing: 8) {
                Text("No documents added yet")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Tap the '+' button to add documents")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .frame(height: 240)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    /// List view for displaying documents
    private var documentsListView: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.documents) { document in
                documentCard(for: document)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.toggleDocumentSelection(document.id)
                    }
            }
        }
    }
    
    /// Card view for a document
    private func documentCard(for document: DocumentModel) -> some View {
        HStack {
            // Main document info with selection capability
            DocumentRow(document: document, isSelected: viewModel.selectedDocuments.contains(document.id))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Details button for accessing document details
            documentDetailsButton(for: document)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            viewModel.selectedDocuments.contains(document.id) ? 
                                Color.blue.opacity(0.5) : Color.clear, 
                            lineWidth: 2
                        )
                )
        )
        .contentShape(Rectangle())
    }
    
    /// Button for navigating to document details
    private func documentDetailsButton(for document: DocumentModel) -> some View {
        NavigationLink(destination: DocumentDetailsView(document: document)) {
            Text("Details")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.blue)
                        .shadow(color: Color.blue.opacity(0.3), radius: 3, x: 0, y: 2)
                )
        }
        .buttonStyle(BorderlessButtonStyle())
    }
    
    /// Section showing processing status and progress
    private var processingStatusSection: some View {
        Group {
            if viewModel.isProcessing {
                VStack(spacing: 16) {
                    // Progress bar and percentage
                    HStack {
                        Text("Processing...")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(Int(viewModel.processingProgress * 100))%")
                            .font(.subheadline.bold())
                            .foregroundColor(.blue)
                    }
                    
                    // Progress bar for document processing
                    ProgressView(value: viewModel.processingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)
                    
                    // Processing statistics summary
                    if let stats = viewModel.processingStats {
                        processingStatsView(stats)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
                )
            }
        }
    }
    
    /// View for displaying processing statistics
    private func processingStatsView(_ stats: DocumentsViewModel.ProcessingStats) -> some View {
        HStack(spacing: 20) {
            statItem(title: "Documents", value: "\(stats.totalDocuments)", icon: "doc.fill")
            statItem(title: "Chunks", value: "\(stats.totalChunks)", icon: "square.on.square")
            statItem(title: "Vectors", value: "\(stats.totalVectors)", icon: "point.3.connected.trianglepath.dotted")
        }
        .padding(.top, 8)
    }
    
    /// Individual stat item
    private func statItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.1))
        )
    }
    
    /// Section containing action buttons for documents
    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            // Process button to start document processing
            processButton
            
            // Remove button to delete selected documents
            removeButton
        }
        .padding(.vertical, 8)
    }
    
    /// Button for processing selected documents
    private var processButton: some View {
        Button(action: {
            Task {
                await viewModel.processSelectedDocuments()
            }
        }) {
            HStack {
                Image(systemName: "gear")
                Text("Process")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                viewModel.selectedDocuments.isEmpty || viewModel.isProcessing || viewModel.selectedIndex == nil ?
                    AnyShapeStyle(Color.blue.opacity(0.3)) :
                    AnyShapeStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: viewModel.selectedDocuments.isEmpty || viewModel.isProcessing ? Color.clear : Color.blue.opacity(0.3), 
                    radius: 5, x: 0, y: 3)
        }
        .disabled(viewModel.selectedDocuments.isEmpty || viewModel.isProcessing || viewModel.selectedIndex == nil)
    }
    
    /// Button for removing selected documents
    private var removeButton: some View {
        Button(action: {
            withAnimation {
                viewModel.removeSelectedDocuments()
            }
        }) {
            HStack {
                Image(systemName: "trash")
                Text("Remove")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                viewModel.selectedDocuments.isEmpty || viewModel.isProcessing ?
                    AnyShapeStyle(Color.red.opacity(0.3)) :
                    AnyShapeStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: viewModel.selectedDocuments.isEmpty || viewModel.isProcessing ? Color.clear : Color.red.opacity(0.3), 
                    radius: 5, x: 0, y: 3)
        }
        .disabled(viewModel.selectedDocuments.isEmpty || viewModel.isProcessing)
    }
    
    /// Toolbar item for adding new documents
    private var addDocumentToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
                showingDocumentPicker = true
            }) {
                Image(systemName: "plus")
                    .foregroundColor(.blue)
            }
            .disabled(viewModel.isProcessing)
        }
    }
    
    /// Content for the namespace creation dialog
    private var namespaceDialogContent: some View {
        Group {
            TextField("Namespace Name", text: $newNamespace)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
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
        HStack(spacing: 12) {
            // Document type icon with background
            ZStack {
                Circle()
                    .fill(colorForDocument(document).opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Image(systemName: iconForDocument(document))
                    .foregroundColor(colorForDocument(document))
            }
            
            // Document metadata information
            documentInfo
            
            Spacer()
            
            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
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
                metadataText(formattedFileSize(document.fileSize))
                
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
                    .fill(Color.red.opacity(0.15))
            )
            .foregroundColor(.red)
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

// Rest of the code remains the same...
