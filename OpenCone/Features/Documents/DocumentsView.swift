// Add imports for types used in this view
import Foundation  // For URL, Date etc. if not implicitly imported by SwiftUI
import SwiftUI
import UniformTypeIdentifiers

// Assuming these types are in the main module target
// import OpenConeCore // Or specific imports if needed

/// View for document management and processing
/// Allows users to select Pinecone indexes, manage namespaces, and process documents
struct DocumentsView: View {
    // MARK: - Properties
    @ObservedObject var viewModel: DocumentsViewModel
    @State private var showingDocumentPicker = false
    @State private var showingNamespaceDialog = false
    @State private var newNamespace = ""
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme: OCTheme  // Explicitly type the theme

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
        .background(theme.backgroundColor.ignoresSafeArea())
        .sheet(isPresented: $showingDocumentPicker) {
            // Assuming DocumentPicker is defined elsewhere and imported
            DocumentPicker(viewModel: viewModel)
        }
        .alert("Create Namespace", isPresented: $showingNamespaceDialog) {
            namespaceDialogContent
        } message: {
            Text("Enter a name for the new namespace:")
        }
        .alert("Create Pinecone Index", isPresented: $viewModel.showingCreateIndexDialog) {  // Added alert for index creation
            createIndexDialogContent
        } message: {
            Text("Enter a name for the new index (lowercase, alphanumeric, hyphens):")
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isProcessing)
        .animation(.easeInOut(duration: 0.2), value: viewModel.documents.count)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoadingIndexes)  // Animate loading state changes
    }

    // MARK: - UI Components

    /// Configuration section for Pinecone index and namespace selection
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pinecone Configuration")
                .font(.headline)
                .foregroundColor(theme.textPrimaryColor)
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
                    .fill(theme.cardBackgroundColor)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
    }

    /// Row for selecting Pinecone index
    private var indexSelectorRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "server.rack")
                .foregroundColor(theme.primaryColor)
                .frame(width: 24)

            Picker("Index:", selection: $viewModel.selectedIndex.toUnwrapped(defaultValue: "")) {
                Text("Select Index").tag("")
                ForEach(viewModel.pineconeIndexes, id: \.self) { index in
                    Text(index).tag(index)
                }
            }
            .foregroundColor(theme.textPrimaryColor)
            .frame(maxWidth: .infinity)
            .onChange(of: viewModel.selectedIndex) { oldValue, newValue in
                if let index = newValue, !index.isEmpty {
                    Task {
                        await viewModel.setIndex(index)
                    }
                }
            }

            HStack(spacing: 8) {  // Group index buttons
                // Create index button
                styledButton(
                    icon: "plus", color: theme.primaryColor,
                    action: {
                        viewModel.showingCreateIndexDialog = true
                    }, isDisabled: viewModel.isProcessing || viewModel.isLoadingIndexes)

                // Refresh indexes button
                styledButton(
                    icon: "arrow.clockwise", color: theme.primaryColor,
                    action: {
                        Task {
                            await viewModel.loadIndexes()
                        }
                    }, isDisabled: viewModel.isProcessing || viewModel.isLoadingIndexes)
            }
        }
    }

    /// Row for selecting or creating a namespace
    private var namespaceSelectorRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .foregroundColor(theme.primaryColor)
                .frame(width: 24)

            Picker(
                "Namespace:", selection: $viewModel.selectedNamespace.toUnwrapped(defaultValue: "")
            ) {
                Text("Default namespace").tag("")
                ForEach(viewModel.namespaces, id: \.self) { namespace in
                    Text(namespace).tag(namespace)
                }
            }
            .foregroundColor(theme.textPrimaryColor)
            .frame(maxWidth: .infinity)
            .onChange(of: viewModel.selectedNamespace) { oldValue, newValue in
                viewModel.setNamespace(newValue)
            }

            HStack(spacing: 8) {
                // Create namespace button
                styledButton(
                    icon: "plus", color: theme.primaryColor,
                    action: {
                        showingNamespaceDialog = true
                    }, isDisabled: viewModel.isProcessing || viewModel.isLoadingIndexes)

                // Refresh namespaces button
                styledButton(
                    icon: "arrow.clockwise", color: theme.primaryColor,
                    action: {
                        Task {
                            await viewModel.loadNamespaces()
                        }
                    }, isDisabled: viewModel.isProcessing || viewModel.isLoadingIndexes)
            }
        }
    }

    /// Section for displaying document list or empty state
    private var documentListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Documents")
                .font(.headline)
                .foregroundColor(theme.textPrimaryColor)

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
                .foregroundColor(theme.primaryColor.opacity(0.7))
                .padding(24)
                .background(
                    Circle()
                        .fill(theme.primaryColor.opacity(0.1))
                )

            VStack(spacing: 8) {
                Text("No documents added yet")
                    .font(.headline)
                    .foregroundColor(theme.textPrimaryColor)

                Text("Tap the '+' button to add documents")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondaryColor)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(height: 240)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackgroundColor)
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
    private func documentCard(for document: DocumentModel) -> some View {  // Ensure DocumentModel is imported/accessible
        HStack {
            // Main document info with selection capability
            DocumentRow(  // Ensure DocumentRow is imported/accessible
                document: document, isSelected: viewModel.selectedDocuments.contains(document.id)
            )
            .frame(maxWidth: .infinity, alignment: .leading)  // .infinity and .leading should be fine here

            // Details button for accessing document details
            documentDetailsButton(for: document)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.cardBackgroundColor)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            viewModel.selectedDocuments.contains(document.id)
                                ? theme.primaryColor.opacity(0.5) : Color.clear,
                            lineWidth: 2
                        )
                )
        )
        .contentShape(Rectangle())
    }

    /// Button for navigating to document details
    private func documentDetailsButton(for document: DocumentModel) -> some View {  // Ensure DocumentModel is imported/accessible
        NavigationLink(destination: DocumentDetailsView(document: document)) {  // Ensure DocumentDetailsView is imported/accessible
            Text("Details")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(theme.primaryColor)
                        .shadow(color: theme.primaryColor.opacity(0.3), radius: 3, x: 0, y: 2)
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
                            .foregroundColor(theme.textPrimaryColor)

                        Spacer()

                        Text("\(Int(viewModel.processingProgress * 100))%")
                            .font(.subheadline.bold())
                            .foregroundColor(theme.primaryColor)
                    }

                    // Progress bar for document processing
                    ProgressView(value: viewModel.processingProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: theme.primaryColor))
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)

                    // Display current status message
                    if let status = viewModel.currentProcessingStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(theme.textSecondaryColor)
                            .padding(.top, 4)
                    }

                    // Processing statistics summary
                    // Ensure DocumentsViewModel.ProcessingStats is accessible
                    if let stats = viewModel.processingStats {
                        processingStatsView(stats)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.cardBackgroundColor)
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
                )
            }
        }
    }

    /// View for displaying processing statistics
    // Ensure DocumentsViewModel.ProcessingStats is accessible
    private func processingStatsView(_ stats: DocumentsViewModel.ProcessingStats) -> some View {
        HStack(spacing: 20) {
            statItem(title: "Documents", value: "\(stats.totalDocuments)", icon: "doc.fill")
            statItem(title: "Chunks", value: "\(stats.totalChunks)", icon: "square.on.square")
            statItem(
                title: "Vectors", value: "\(stats.totalVectors)",
                icon: "point.3.connected.trianglepath.dotted")
        }
        .padding(.top, 8)
    }

    /// Individual stat item
    private func statItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(theme.primaryColor)

                Text(title)
                    .font(.caption)
                    .foregroundColor(theme.textSecondaryColor)
            }

            Text(value)
                .font(.headline)
                .foregroundColor(theme.textPrimaryColor)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.primaryColor.opacity(0.1))
        )
    }

    /// Section containing action buttons for documents
    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            // Add document button (moved from toolbar)
            Button(action: {
                showingDocumentPicker = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add File")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    viewModel.isProcessing
                        ? AnyShapeStyle(theme.primaryColor.opacity(0.3))
                        : AnyShapeStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    theme.primaryColor, theme.primaryColor.opacity(0.8),
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(
                    color: viewModel.isProcessing ? Color.clear : theme.primaryColor.opacity(0.3),
                    radius: 5, x: 0, y: 3)
            }
            .disabled(viewModel.isProcessing)
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
                viewModel.selectedDocuments.isEmpty || viewModel.isProcessing
                    || viewModel.selectedIndex == nil
                    ? AnyShapeStyle(theme.primaryColor.opacity(0.3))
                    : AnyShapeStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                theme.primaryColor, theme.primaryColor.opacity(0.8),
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(
                color: viewModel.selectedDocuments.isEmpty || viewModel.isProcessing
                    ? Color.clear : theme.primaryColor.opacity(0.3),
                radius: 5, x: 0, y: 3)
        }
        .disabled(
            viewModel.selectedDocuments.isEmpty || viewModel.isProcessing
                || viewModel.selectedIndex == nil)
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
                viewModel.selectedDocuments.isEmpty || viewModel.isProcessing
                    ? AnyShapeStyle(theme.errorColor.opacity(0.3))
                    : AnyShapeStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                theme.errorColor, theme.errorColor.opacity(0.8),
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(
                color: viewModel.selectedDocuments.isEmpty || viewModel.isProcessing
                    ? Color.clear : theme.errorColor.opacity(0.3),
                radius: 5, x: 0, y: 3)
        }
        .disabled(viewModel.selectedDocuments.isEmpty || viewModel.isProcessing)
    }

    /// Content for the namespace creation dialog
    private var namespaceDialogContent: some View {
        Group {
            TextField("Namespace Name", text: $newNamespace)
                .textInputAutocapitalization(.never)  // Correct modifier for autocapitalization
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

    /// Content for the create index dialog
    private var createIndexDialogContent: some View {
        Group {
            TextField("Index Name", text: $viewModel.newIndexName)
                .textInputAutocapitalization(.never)  // Correct modifier for autocapitalization
                .disableAutocorrection(true)
                .onSubmit {  // Allow submitting with Enter key
                    if !viewModel.newIndexName.isEmpty {
                        Task { await viewModel.createIndex() }
                    }
                }

            Button("Cancel", role: .cancel) {
                viewModel.newIndexName = ""  // Clear field on cancel
            }

            Button("Create") {
                Task { await viewModel.createIndex() }
            }
            // Disable Create button if name is empty or if loading
            .disabled(viewModel.newIndexName.isEmpty || viewModel.isLoadingIndexes)
        }
    }
}

/// Utility function to create a styled button with an icon and action
private func styledButton(
    icon: String, color: Color, action: @escaping () -> Void, isDisabled: Bool
) -> some View {
    Button(action: action) {
        Image(systemName: icon)
            .foregroundColor(color)
            .padding(8)
            .background(Circle().fill(color.opacity(0.1)))
    }
    .buttonStyle(PlainButtonStyle())
    .disabled(isDisabled)
}

