import SwiftUI
import UniformTypeIdentifiers

/// The Documents tab, in the grouped-list style of the rest of the app: where uploads go (index and
/// namespace, with their passage counts), what is being indexed, and the documents themselves.
/// Add with +, index everything new with one button, select several with Select, swipe to remove.
struct DocumentsView: View {
    @ObservedObject var viewModel: DocumentsViewModel
    @State private var showingImporter = false
    @State private var showingNewNamespace = false
    @State private var newNamespace = ""
    @State private var confirmingNamespaceDeletion = false
    @State private var confirmingRemoval = false
    @State private var showingIndexDetails = false
    @State private var filter: DocumentFilter = .all
    @State private var searchText = ""
    @State private var editMode: EditMode = .inactive
    /// A document opened from code rather than a tap: the demo's "document" screen
    @State private var openedDocument: DocumentModel?

    /// Where and how Create makes an index: the values `DocumentsViewModel.createIndex` reads
    private var newIndexSummary: String {
        let metric = UserDefaults.standard.string(forKey: SettingsStorageKeys.newIndexMetric) ?? "cosine"
        let storedDimension = UserDefaults.standard.integer(forKey: "embedding.dimension")
        let dimension = storedDimension > 0 ? storedDimension : Configuration.embeddingDimension
        return "\(Configuration.getPineconeCloud().uppercased()) \(Configuration.getPineconeRegion()), \(metric), \(dimension) dimensions"
    }

    enum DocumentFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case notIndexed = "Not indexed"
        case indexed = "Indexed"
        case failed = "Failed"

        var id: Self { self }
    }

    /// The types OpenCone can read text from: PDFs, text formats, and images through on-device text
    /// recognition (`FileProcessorService`). Word, Excel and PowerPoint files can't be read, so
    /// they aren't offered.
    static let importableTypes: [UTType] = {
        var types: [UTType] = [
            .pdf, .plainText, .utf8PlainText, .rtf, .html, .json, .xml, .commaSeparatedText, .javaScript,
            .png, .jpeg, .tiff, .gif, .bmp,
        ]
        for identifier in ["net.daringfireball.markdown", "public.css"] {
            if let type = UTType(identifier) {
                types.append(type)
            }
        }
        return types
    }()

    private var isEditing: Bool { editMode.isEditing }

    private var visibleDocuments: [DocumentModel] {
        viewModel.documents.filter { document in
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .notIndexed: matchesFilter = !document.isProcessed && document.processingError == nil
            case .indexed: matchesFilter = document.isProcessed
            case .failed: matchesFilter = document.processingError != nil
            }
            return matchesFilter && (searchText.isEmpty || document.fileName.localizedCaseInsensitiveContains(searchText))
        }
    }

    private var canAddDocuments: Bool {
        viewModel.selectedIndex != nil && !viewModel.needsSecurityConsent && !viewModel.isProcessing
    }

    var body: some View {
        List(selection: $viewModel.selectedDocuments) {
            if viewModel.needsSecurityConsent {
                consentSection
            }
            destinationSection
            if viewModel.isProcessing {
                progressSection
            }
            documentsSection
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, $editMode)
        .searchable(text: $searchText, prompt: "Find a document")
        .toolbar { toolbar }
        .safeAreaInset(edge: .bottom) { actionBar }
        .refreshable {
            await viewModel.loadIndexes()
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: Self.importableTypes,
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                for url in urls {
                    viewModel.addDocument(at: url)
                }
            }
        }
        .alert("New namespace", isPresented: $showingNewNamespace) {
            TextField("Name", text: $newNamespace)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) { newNamespace = "" }
            Button("Create") {
                viewModel.createNamespace(newNamespace)
                newNamespace = ""
            }
        } message: {
            Text("Lowercase letters, digits, hyphens and underscores, starting and ending with a letter or digit.")
        }
        .alert("New index", isPresented: $viewModel.showingCreateIndexDialog) {
            TextField("Name", text: $viewModel.newIndexName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) { viewModel.newIndexName = "" }
            Button("Create") { Task { await viewModel.createIndex() } }
        } message: {
            Text("A serverless index in \(newIndexSummary), as set in Settings > Advanced > New indexes. Lowercase letters, digits and hyphens.")
        }
        .confirmationDialog(
            "Delete the index \(viewModel.selectedIndex ?? "")?",
            isPresented: $viewModel.showingDeleteIndexDialog,
            titleVisibility: .visible
        ) {
            Button("Delete index", role: .destructive) {
                Task { await viewModel.deleteSelectedIndex() }
            }
        } message: {
            Text("Pinecone deletes the index and every passage in it. This can't be undone.")
        }
        .confirmationDialog(
            "Delete the namespace \(namespaceName(viewModel.selectedNamespace))?",
            isPresented: $confirmingNamespaceDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete namespace", role: .destructive) {
                Task { await viewModel.deleteSelectedNamespace() }
            }
        } message: {
            Text("Pinecone deletes every passage in it. This can't be undone.")
        }
        .confirmationDialog(
            viewModel.selectedDocuments.count == 1 ? "Remove this document?" : "Remove \(viewModel.selectedDocuments.count) documents?",
            isPresented: $confirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                viewModel.removeSelectedDocuments()
                editMode = .inactive
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes the files from OpenCone and deletes their passages from Pinecone.")
        }
        .sheet(isPresented: $showingIndexDetails) {
            IndexDetailsSheet(viewModel: viewModel)
        }
        .navigationDestination(item: $openedDocument) { document in
            DocumentDetailsView(document: document)
        }
        .task {
            switch DemoMode.screen {
            case "index-details": showingIndexDetails = true
            case "document": openedDocument = viewModel.documents.first
            default: break
            }
        }
        .onChange(of: editMode) { _, mode in
            if !mode.isEditing {
                viewModel.selectedDocuments.removeAll()
            }
        }
        .animation(.default, value: viewModel.isProcessing)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if !viewModel.documents.isEmpty {
                Button(isEditing ? "Done" : "Select") {
                    withAnimation {
                        editMode = isEditing ? .inactive : .active
                    }
                }
                .disabled(viewModel.isProcessing)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showingIndexDetails = true
                } label: {
                    Label("Index details", systemImage: "info.circle")
                }
                .disabled(viewModel.selectedIndex == nil)
                Button {
                    Task { await viewModel.refreshIndexInsights() }
                } label: {
                    Label("Refresh counts", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.selectedIndex == nil)
                Divider()
                Button {
                    showingNewNamespace = true
                } label: {
                    Label("New namespace…", systemImage: "folder.badge.plus")
                }
                .disabled(viewModel.selectedIndex == nil)
                Button {
                    viewModel.showingCreateIndexDialog = true
                } label: {
                    Label("New index…", systemImage: "plus.square.on.square")
                }
                Divider()
                Button(role: .destructive) {
                    confirmingNamespaceDeletion = true
                } label: {
                    Label("Delete namespace…", systemImage: "folder.badge.minus")
                }
                .disabled(viewModel.selectedIndex == nil || viewModel.isProcessing)
                Button(role: .destructive) {
                    viewModel.showingDeleteIndexDialog = true
                } label: {
                    Label("Delete index…", systemImage: "trash")
                }
                .disabled(viewModel.selectedIndex == nil || viewModel.isProcessing)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("More")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showingImporter = true
            } label: {
                Image(systemName: "plus")
            }
            .disabled(!canAddDocuments)
            .accessibilityLabel("Add documents")
        }
    }

    // MARK: - Sections

    private var consentSection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.title2)
                    .foregroundStyle(Color.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Allow file access")
                        .font(.headline)
                    Text("OpenCone keeps a bookmark to each file you add, so it can read the file again when it indexes it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Button("Allow") {
                viewModel.acknowledgeSecurityConsent()
            }
            .fontWeight(.semibold)
        }
    }

    private var destinationSection: some View {
        Section {
            if viewModel.isLoadingIndexes && viewModel.pineconeIndexes.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading your indexes")
                        .foregroundStyle(.secondary)
                }
            } else if viewModel.pineconeIndexes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No indexes yet")
                        .font(.headline)
                    Text("Create an index to hold your documents' passages.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button {
                    viewModel.showingCreateIndexDialog = true
                } label: {
                    Label("New index", systemImage: "plus")
                }
            } else {
                indexMenu
                if viewModel.selectedIndex != nil {
                    namespaceMenu
                }
            }
        } header: {
            Text("Upload to")
        } footer: {
            if viewModel.selectedIndex != nil {
                Text("Documents are read and split into passages on this iPhone, embedded with \(Self.embeddingModel) through OpenAI, and stored in this namespace.")
            }
        }
    }

    private var indexMenu: some View {
        Menu {
            Picker("Index", selection: Binding(
                get: { viewModel.selectedIndex ?? "" },
                set: { name in Task { await viewModel.setIndex(name) } }
            )) {
                ForEach(viewModel.pineconeIndexes, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            Divider()
            Button {
                viewModel.showingCreateIndexDialog = true
            } label: {
                Label("New index…", systemImage: "plus")
            }
        } label: {
            DestinationRow(
                systemImage: "cylinder.split.1x2",
                title: "Index",
                value: viewModel.selectedIndex ?? "Choose an index",
                detail: viewModel.indexStats.map { Self.passages($0.totalVectorCount) }
            )
        }
        .disabled(viewModel.isProcessing)
    }

    private var namespaceMenu: some View {
        Menu {
            Picker("Namespace", selection: Binding(
                get: { viewModel.selectedNamespace ?? "" },
                set: { viewModel.setNamespace($0) }
            )) {
                ForEach(viewModel.namespaces, id: \.self) { name in
                    Text(namespaceName(name)).tag(name)
                }
            }
            Divider()
            Button {
                showingNewNamespace = true
            } label: {
                Label("New namespace…", systemImage: "folder.badge.plus")
            }
        } label: {
            DestinationRow(
                systemImage: "folder",
                title: "Namespace",
                value: namespaceName(viewModel.selectedNamespace),
                detail: viewModel.indexStats == nil ? nil : Self.passages(viewModel.selectedNamespaceVectorCount)
            )
        }
        .disabled(viewModel.isProcessing)
    }

    private var progressSection: some View {
        Section("Indexing") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(viewModel.currentProcessingStatus ?? "Working…")
                        .font(.subheadline)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    Text("\(Int(viewModel.processingProgress * 100))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: Double(viewModel.processingProgress))
                if let stats = viewModel.processingStats {
                    Text("\(stats.totalDocuments) documents · \(stats.totalChunks) passages · \(stats.totalVectors) stored")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var documentsSection: some View {
        if viewModel.documents.isEmpty {
            Section {
                ContentUnavailableView {
                    Label("No documents yet", systemImage: "doc.badge.plus")
                } description: {
                    Text("Add PDFs, text, Markdown, HTML, JSON or CSV files, or photos of pages, which are read on this iPhone.")
                } actions: {
                    Button("Add documents") { showingImporter = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canAddDocuments)
                }
            }
        } else {
            Section {
                if visibleDocuments.isEmpty {
                    Text(searchText.isEmpty ? "No \(filter.rawValue.lowercased()) documents." : "No document matches \u{201C}\(searchText)\u{201D}.")
                        .foregroundStyle(.secondary)
                }
                ForEach(visibleDocuments) { document in
                    NavigationLink {
                        DocumentDetailsView(document: document)
                    } label: {
                        DocumentRow(document: document)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.selectedDocuments = [document.id]
                            confirmingRemoval = true
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if !document.isProcessed {
                            Button {
                                index([document.id])
                            } label: {
                                Label("Index", systemImage: "arrow.up.doc")
                            }
                            .tint(.accentColor)
                        }
                    }
                }
            } header: {
                HStack {
                    Text(viewModel.documents.count == 1 ? "1 document" : "\(viewModel.documents.count) documents")
                    Spacer()
                    Menu {
                        Picker("Show", selection: $filter) {
                            ForEach(DocumentFilter.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        Label(filter.rawValue, systemImage: "line.3.horizontal.decrease.circle")
                            .font(.caption)
                    }
                    .textCase(nil)
                }
            }
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var actionBar: some View {
        if isEditing {
            let count = viewModel.selectedDocuments.count
            HStack(spacing: 12) {
                Button {
                    index(viewModel.selectedDocuments)
                } label: {
                    Label(count == 0 ? "Index" : "Index \(count)", systemImage: "arrow.up.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(count == 0 || viewModel.isProcessing || viewModel.selectedIndex == nil)

                Button(role: .destructive) {
                    confirmingRemoval = true
                } label: {
                    Label(count == 0 ? "Remove" : "Remove \(count)", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(count == 0 || viewModel.isProcessing)
            }
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        } else if !viewModel.pendingDocuments.isEmpty && !viewModel.isProcessing {
            let count = viewModel.pendingDocuments.count
            Button {
                index(Set(viewModel.pendingDocuments.map(\.id)))
            } label: {
                Label(count == 1 ? "Index 1 new document" : "Index \(count) new documents", systemImage: "arrow.up.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.selectedIndex == nil)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    /// Index these documents into the chosen index and namespace
    private func index(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        viewModel.selectedDocuments = ids
        editMode = .inactive
        Task {
            await viewModel.processSelectedDocuments()
            viewModel.selectedDocuments.removeAll()
        }
    }

    // MARK: - Text

    private func namespaceName(_ name: String?) -> String {
        guard let name, !name.isEmpty else { return "Default namespace" }
        return name
    }

    static func passages(_ count: Int) -> String {
        count == 1 ? "1 passage" : "\(count.formatted()) passages"
    }

    /// The embedding model uploads use, as OpenAIService reads it
    static var embeddingModel: String {
        UserDefaults.standard.string(forKey: "embeddingModel") ?? Configuration.embeddingModel
    }
}

// MARK: - Rows

/// The index or namespace uploads go to, as a menu row
private struct DestinationRow: View {
    let systemImage: String
    let title: String
    let value: String
    let detail: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                Text(value)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens a menu to choose")
    }
}

/// One document: what it is, and whether and where it's indexed
struct DocumentRow: View {
    let document: DocumentModel

    private var tint: Color {
        if document.processingError != nil { return .red }
        if document.isProcessed { return .green }
        return .accentColor
    }

    private var detail: String {
        if let error = document.processingError {
            return "Failed: \(error)"
        }
        var parts = [document.formattedFileSize]
        if document.isProcessed {
            parts.append(DocumentsView.passages(document.chunkCount))
            if let index = document.lastIndexedIndexName {
                let namespace = document.lastIndexedNamespace.flatMap { $0.isEmpty ? nil : $0 }
                parts.append(namespace.map { "\(index) / \($0)" } ?? index)
            }
        } else {
            parts.append("not indexed yet")
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: document.viewIconName)
                .font(.body)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(document.fileName)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(document.processingError == nil ? Color.secondary : Color.red)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            statusIcon
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusIcon: some View {
        if document.processingError != nil {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.red)
                .accessibilityLabel("Failed")
        } else if document.isProcessed {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.green)
                .accessibilityLabel("Indexed")
        } else {
            Image(systemName: "circle.dashed")
                .foregroundStyle(Color.secondary)
                .accessibilityLabel("Not indexed yet")
        }
    }
}

// MARK: - Index details

/// The open index as Pinecone describes it, its namespaces, and how documents get into it
struct IndexDetailsSheet: View {
    @ObservedObject var viewModel: DocumentsViewModel
    @Environment(\.dismiss) private var dismiss

    private var namespaces: [(name: String, count: Int)] {
        (viewModel.indexStats?.namespaces ?? [:])
            .map { (name: $0.key, count: $0.value.vectorCount) }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Index") {
                    LabeledContent("Name", value: viewModel.selectedIndex ?? "None")
                    if let metadata = viewModel.indexMetadata {
                        LabeledContent("Dimensions", value: "\(metadata.dimension)")
                        LabeledContent("Metric", value: metadata.metric)
                        LabeledContent("Status", value: metadata.status.ready ? "Ready" : metadata.status.state)
                        LabeledContent("Host") {
                            Text(metadata.host)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                    if let stats = viewModel.indexStats {
                        LabeledContent("Passages", value: stats.totalVectorCount.formatted())
                    }
                }

                if !namespaces.isEmpty {
                    Section("Namespaces") {
                        ForEach(namespaces, id: \.name) { namespace in
                            LabeledContent(namespace.name.isEmpty ? "Default namespace" : namespace.name,
                                           value: DocumentsView.passages(namespace.count))
                        }
                    }
                }

                Section {
                    Group {
                        Label("Read the text on this iPhone: PDFKit for PDFs, Vision for images", systemImage: "doc.text.viewfinder")
                        Label("Split it into passages that overlap a little", systemImage: "square.split.2x1")
                        Label("Embed each passage with \(DocumentsView.embeddingModel)", systemImage: "point.3.connected.trianglepath.dotted")
                        Label("Store the passages and their text in this namespace", systemImage: "arrow.up.to.line")
                    }
                    .font(.subheadline)
                } header: {
                    Text("How documents are indexed")
                }
            }
            .navigationTitle("Index details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .task {
                guard !DemoMode.isActive else { return }
                await viewModel.refreshIndexInsights()
            }
        }
    }
}
