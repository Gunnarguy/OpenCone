import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main View

/// Redesigned document management view with clean, focused UI
struct DocumentsViewRedesign: View {
    @ObservedObject var viewModel: DocumentsViewModel
    @State private var showingDocumentPicker = false
    @State private var showingAdvancedSheet = false
    @State private var showingNamespaceDialog = false
    @State private var newNamespace = ""
    @State private var selectedFilter: DocumentFilter = .all
    @Environment(\.theme) private var theme: OCTheme

    enum DocumentFilter: String, CaseIterable {
        case all = "All"
        case processed = "Processed"
        case pending = "Pending"
        case failed = "Failed"
    }

    var filteredDocuments: [DocumentModel] {
        switch selectedFilter {
        case .all:
            return viewModel.documents
        case .processed:
            return viewModel.documents.filter { $0.isProcessed }
        case .pending:
            return viewModel.documents.filter { !$0.isProcessed && $0.processingError == nil }
        case .failed:
            return viewModel.documents.filter { $0.processingError != nil }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    // Security consent banner if needed
                    if viewModel.needsSecurityConsent {
                        securityBanner
                    }

                    // Knowledge base selector
                    knowledgeBaseSelector

                    // Stats row (only when index selected)
                    if viewModel.selectedIndex != nil {
                        statsRow
                    }

                    // Processing indicator
                    if viewModel.isProcessing {
                        processingCard
                    }

                    // Document list with filters
                    if !viewModel.documents.isEmpty {
                        documentList
                    } else if viewModel.selectedIndex != nil && !viewModel.isLoadingIndexes {
                        emptyState
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
                .padding(.bottom, viewModel.selectedDocuments.isEmpty ? 0 : 80)
            }
            .background(theme.backgroundColor.ignoresSafeArea())

            // Floating action bar for bulk operations
            if !viewModel.selectedDocuments.isEmpty {
                bulkActionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(viewModel: viewModel)
        }
        .sheet(isPresented: $showingAdvancedSheet) {
            AdvancedOptionsSheet(viewModel: viewModel)
        }
        .alert("Create Collection", isPresented: $showingNamespaceDialog) {
            TextField("Collection name", text: $newNamespace)
                .textInputAutocapitalization(.never)
            Button("Cancel", role: .cancel) { newNamespace = "" }
            Button("Create") {
                guard !newNamespace.isEmpty else { return }
                viewModel.createNamespace(newNamespace)
                newNamespace = ""
            }
        }
        .alert("Create Knowledge Base", isPresented: $viewModel.showingCreateIndexDialog) {
            TextField("Index Name", text: $viewModel.newIndexName)
                .textInputAutocapitalization(.never)
            Button("Cancel", role: .cancel) { viewModel.newIndexName = "" }
            Button("Create") { Task { await viewModel.createIndex() } }
                .disabled(viewModel.newIndexName.isEmpty)
        }
        .animation(.spring(duration: 0.3), value: viewModel.isProcessing)
        .animation(.spring(duration: 0.3), value: viewModel.selectedDocuments.count)
    }
}

// MARK: - Security Banner

private extension DocumentsViewRedesign {
    var securityBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundColor(theme.warningColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("File Access Required")
                    .font(.subheadline.bold())
                    .foregroundColor(theme.textPrimaryColor)
                Text("Grant access to import documents")
                    .font(.caption)
                    .foregroundColor(theme.textSecondaryColor)
            }

            Spacer()

            Button("Allow") {
                viewModel.acknowledgeSecurityConsent()
            }
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.primaryColor)
            .clipShape(Capsule())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.warningColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.warningColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Knowledge Base Selector

private extension DocumentsViewRedesign {
    var knowledgeBaseSelector: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Knowledge Base")
                        .font(.caption.bold())
                        .foregroundColor(theme.textSecondaryColor)
                        .textCase(.uppercase)

                    if viewModel.isLoadingIndexes {
                        HStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading...")
                                .font(.headline)
                                .foregroundColor(theme.textSecondaryColor)
                        }
                    } else if let index = viewModel.selectedIndex {
                        Text(index)
                            .font(.title2.bold())
                            .foregroundColor(theme.textPrimaryColor)
                    } else {
                        Text("Select a knowledge base")
                            .font(.headline)
                            .foregroundColor(theme.textSecondaryColor)
                    }
                }

                Spacer()

                // Advanced settings button
                Button {
                    showingAdvancedSheet = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20))
                        .foregroundColor(theme.textSecondaryColor)
                }
            }

            // Index picker
            if !viewModel.pineconeIndexes.isEmpty {
                Menu {
                    ForEach(viewModel.pineconeIndexes, id: \.self) { index in
                        Button {
                            Task { await viewModel.setIndex(index) }
                        } label: {
                            HStack {
                                Text(index)
                                if viewModel.selectedIndex == index { 
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Divider()

                    Button {
                        viewModel.showingCreateIndexDialog = true
                    } label: {
                        Label("Create New", systemImage: "plus")
                    }
                } label: {
                    HStack {
                        Image(systemName: "externaldrive")
                            .foregroundColor(theme.primaryColor)
                        Text(viewModel.selectedIndex ?? "Choose Index")
                            .foregroundColor(theme.textPrimaryColor)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundColor(theme.textSecondaryColor)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.cardBackgroundColor)
                    )
                }
            }

            // Namespace picker (if index selected)
            if viewModel.selectedIndex != nil && !viewModel.namespaces.isEmpty {
                Menu {
                    ForEach(viewModel.namespaces, id: \.self) { namespace in
                        Button {
                            viewModel.setNamespace(namespace)
                        } label: {
                            HStack {
                                Text(namespace.isEmpty ? "Default" : namespace)
                                if viewModel.selectedNamespace == namespace { 
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Divider()

                    Button {
                        showingNamespaceDialog = true
                    } label: {
                        Label("Create Collection", systemImage: "plus")
                    }
                } label: {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(theme.secondaryColor)
                        Text(viewModel.selectedNamespace?.isEmpty == false ? viewModel.selectedNamespace! : "Default Collection")
                            .foregroundColor(theme.textPrimaryColor)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundColor(theme.textSecondaryColor)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(theme.cardBackgroundColor)
                    )
                }
            }

            // Add Documents button
            if viewModel.selectedIndex != nil && !viewModel.needsSecurityConsent {
                Button {
                    showingDocumentPicker = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Documents")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [theme.primaryColor, theme.primaryColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(viewModel.isProcessing)
                .opacity(viewModel.isProcessing ? 0.5 : 1)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.cardBackgroundColor)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        )
    }
}

// MARK: - Stats Row

private extension DocumentsViewRedesign {
    var statsRow: some View {
        HStack(spacing: 12) {
            statCard(
                icon: "doc.text",
                value: "\(viewModel.documents.count)",
                label: "Documents",
                color: theme.primaryColor
            )

            statCard(
                icon: "cube.box",
                value: formattedCount(viewModel.selectedNamespaceVectorCount),
                label: "Vectors",
                color: theme.successColor
            )

            statCard(
                icon: "checkmark.circle",
                value: "\(viewModel.documents.filter { $0.isProcessed }.count)",
                label: "Processed",
                color: theme.infoColor
            )
        }
    }

    func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(value)
                    .font(.title3.bold().monospacedDigit())
                    .foregroundColor(theme.textPrimaryColor)
            }
            Text(label)
                .font(.caption)
                .foregroundColor(theme.textSecondaryColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.cardBackgroundColor)
        )
    }

    func formattedCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }
}

// MARK: - Processing Card

private extension DocumentsViewRedesign {
    var processingCard: some View {
        VStack(spacing: 16) {
            HStack {
                ProgressView()
                    .scaleEffect(0.9)
                Text("Processing...")
                    .font(.headline)
                    .foregroundColor(theme.textPrimaryColor)
                Spacer()

                if let status = viewModel.currentProcessingStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(theme.textSecondaryColor)
                        .lineLimit(1)
                }
            }

            // Overall progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Overall Progress")
                        .font(.caption.bold())
                        .foregroundColor(theme.textPrimaryColor)
                    Spacer()
                    Text("\(Int(viewModel.processingProgress * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(theme.textSecondaryColor)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.primaryColor.opacity(0.2))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.primaryColor)
                            .frame(width: geo.size.width * CGFloat(viewModel.processingProgress))
                    }
                }
                .frame(height: 6)
            }

            // Show processing stats if available
            if let stats = viewModel.processingStats {
                HStack(spacing: 12) {
                    processingStatTile(value: "\(stats.totalDocuments)", label: "Docs")
                    processingStatTile(value: "\(stats.totalChunks)", label: "Chunks")
                    processingStatTile(value: "\(stats.totalVectors)", label: "Vectors")
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.primaryColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(theme.primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    func processingStatTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(theme.textPrimaryColor)
            Text(label)
                .font(.caption)
                .foregroundColor(theme.textSecondaryColor)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.primaryColor.opacity(0.12))
        )
    }
}

// MARK: - Document List

private extension DocumentsViewRedesign {
    var documentList: some View {
        VStack(spacing: 16) {
            // Header with filter
            HStack {
                Text("Documents")
                    .font(.title3.bold())
                    .foregroundColor(theme.textPrimaryColor)

                Spacer()

                // Filter picker
                Menu {
                    ForEach(DocumentFilter.allCases, id: \.self) { filter in
                        Button {
                            selectedFilter = filter
                        } label: {
                            HStack {
                                Text(filter.rawValue)
                                if filter == selectedFilter {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedFilter.rawValue)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(theme.primaryColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(theme.primaryColor.opacity(0.1))
                    )
                }

                // Select all button
                Button {
                    if viewModel.selectedDocuments.count == filteredDocuments.count {
                        viewModel.selectedDocuments.removeAll()
                    } else {
                        viewModel.selectedDocuments = Set(filteredDocuments.map { $0.id })
                    }
                } label: {
                    Text(viewModel.selectedDocuments.count == filteredDocuments.count ? "Deselect" : "Select All")
                        .font(.subheadline)
                        .foregroundColor(theme.primaryColor)
                }
            }

            // Document rows
            LazyVStack(spacing: 10) {
                ForEach(filteredDocuments) { doc in
                    documentRow(doc)
                }
            }
        }
    }

    func documentRow(_ doc: DocumentModel) -> some View {
        let isSelected = viewModel.selectedDocuments.contains(doc.id)

        return HStack(spacing: 14) {
            // Selection checkbox
            Button {
                viewModel.toggleDocumentSelection(doc.id)
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? theme.primaryColor : theme.textSecondaryColor.opacity(0.5))
            }

            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(doc.viewIconColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: doc.viewIconName)
                    .font(.system(size: 18))
                    .foregroundColor(doc.viewIconColor)
            }

            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.fileName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(theme.textPrimaryColor)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(doc.formattedFileSize)
                        .font(.caption)
                        .foregroundColor(theme.textSecondaryColor)

                    statusBadge(for: doc)
                }
            }

            Spacer()

            // Navigate to details
            NavigationLink(destination: DocumentDetailsView(document: doc)) {
                Image(systemName: "info.circle")
                    .font(.system(size: 18))
                    .foregroundColor(theme.textSecondaryColor)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? theme.primaryColor.opacity(0.08) : theme.cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? theme.primaryColor.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.toggleDocumentSelection(doc.id)
        }
    }

    @ViewBuilder
    func statusBadge(for doc: DocumentModel) -> some View {
        if doc.isProcessed {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("\(doc.chunkCount) chunks")
            }
            .font(.caption)
            .foregroundColor(theme.successColor)
        } else if let error = doc.processingError {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Error")
            }
            .font(.caption)
            .foregroundColor(theme.errorColor)
            .help(error)
        } else {
            Text("Pending")
                .font(.caption)
                .foregroundColor(theme.warningColor)
        }
    }
}

// MARK: - Empty State

private extension DocumentsViewRedesign {
    var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundColor(theme.textSecondaryColor.opacity(0.5))

            VStack(spacing: 8) {
                Text("No Documents Yet")
                    .font(.title3.bold())
                    .foregroundColor(theme.textPrimaryColor)

                Text("Add PDF, Word, text, or code files to build your knowledge base")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondaryColor)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Bulk Action Bar

private extension DocumentsViewRedesign {
    var bulkActionBar: some View {
        HStack(spacing: 16) {
            // Selection count
            Text("\(viewModel.selectedDocuments.count) selected")
                .font(.subheadline.bold())
                .foregroundColor(theme.textPrimaryColor)

            Spacer()

            // Process button
            Button {
                Task { await viewModel.processSelectedDocuments() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Process")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(theme.primaryColor)
                .clipShape(Capsule())
            }
            .disabled(viewModel.isProcessing || viewModel.selectedIndex == nil)

            // Delete button
            Button {
                viewModel.removeSelectedDocuments()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundColor(theme.errorColor)
                    .padding(10)
                    .background(theme.errorColor.opacity(0.1))
                    .clipShape(Circle())
            }
            .disabled(viewModel.isProcessing)

            // Clear selection
            Button {
                viewModel.selectedDocuments.removeAll()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(theme.textSecondaryColor)
                    .padding(10)
                    .background(theme.cardBackgroundColor)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 20, y: -5)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

// MARK: - Advanced Options Sheet

struct AdvancedOptionsSheet: View {
    @ObservedObject var viewModel: DocumentsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: OCTheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Index Stats
                    indexStatsSection

                    // Actions
                    actionsSection

                    // Pipeline Info
                    pipelineInfoSection
                }
                .padding(20)
            }
            .background(theme.backgroundColor.ignoresSafeArea())
            .navigationTitle("Advanced Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var indexStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("INDEX STATISTICS")
                .font(.caption.bold())
                .foregroundColor(theme.textSecondaryColor)

            if let stats = viewModel.indexStats {
                VStack(spacing: 12) {
                    statRow(label: "Total Vectors", value: "\(stats.totalVectorCount)")
                    statRow(label: "Dimension", value: "\(stats.dimension)")

                    if !stats.namespaces.isEmpty {
                        Divider()
                        Text("Namespaces")
                            .font(.subheadline.bold())
                            .foregroundColor(theme.textPrimaryColor)

                        ForEach(Array(stats.namespaces.keys.sorted()), id: \.self) { ns in
                            if let nsStats = stats.namespaces[ns] {
                                statRow(
                                    label: ns.isEmpty ? "(default)" : ns,
                                    value: "\(nsStats.vectorCount) vectors"
                                )
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(theme.cardBackgroundColor)
                )
            } else {
                Text("No statistics available")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondaryColor)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(theme.cardBackgroundColor)
                    )
            }
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(theme.textSecondaryColor)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundColor(theme.textPrimaryColor)
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ACTIONS")
                .font(.caption.bold())
                .foregroundColor(theme.textSecondaryColor)

            VStack(spacing: 12) {
                actionButton(
                    title: "Refresh Statistics",
                    icon: "arrow.clockwise",
                    color: theme.primaryColor
                ) {
                    Task { await viewModel.refreshIndexInsights() }
                }

                actionButton(
                    title: "Reload Indexes",
                    icon: "cloud.fill",
                    color: theme.infoColor
                ) {
                    Task { await viewModel.loadIndexes() }
                }
            }
        }
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                Text(title)
                    .foregroundColor(theme.textPrimaryColor)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(theme.textSecondaryColor)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.cardBackgroundColor)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isProcessing)
    }

    private var pipelineInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PROCESSING PIPELINE")
                .font(.caption.bold())
                .foregroundColor(theme.textSecondaryColor)

            VStack(alignment: .leading, spacing: 12) {
                pipelineStep(number: 1, title: "Extract", description: "Text extraction via PDFKit, Vision OCR")
                pipelineStep(number: 2, title: "Chunk", description: "Semantic chunking with overlap")
                pipelineStep(number: 3, title: "Embed", description: "OpenAI text-embedding-3-large")
                pipelineStep(number: 4, title: "Upload", description: "Upsert vectors to Pinecone")
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.cardBackgroundColor)
            )
        }
    }

    private func pipelineStep(number: Int, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(theme.primaryColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(theme.textPrimaryColor)
                Text(description)
                    .font(.caption)
                    .foregroundColor(theme.textSecondaryColor)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    // Create mock services with test credentials for preview
    let pineconeService = PineconeService(apiKey: "test-key", projectId: "test-project")
    let openAIService = OpenAIService(apiKey: "test-key")
    let embeddingService = EmbeddingService(openAIService: openAIService)
    let fileProcessorService = FileProcessorService()
    let textProcessorService = TextProcessorService()

    return NavigationStack {
        DocumentsViewRedesign(viewModel: DocumentsViewModel(
            fileProcessorService: fileProcessorService,
            textProcessorService: textProcessorService,
            embeddingService: embeddingService,
            pineconeService: pineconeService
        ))
    }
    .withTheme()
}
