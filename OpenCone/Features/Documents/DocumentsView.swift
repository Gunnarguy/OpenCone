import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Redesigned document orchestration surface aligned with Pinecone playbooks.
struct DocumentsView: View {
    @ObservedObject var viewModel: DocumentsViewModel
    @State private var showingDocumentPicker = false
    @State private var showingNamespaceDialog = false
    @State private var newNamespace = ""
    @Environment(\.theme) private var theme: OCTheme

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                if viewModel.needsSecurityConsent {
                    securityConsentBanner
                }
                heroSection
                indexOverviewSection
                pipelineSection
                processingPanel
                documentCatalogSection
                operationsSection
                referencesSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
        }
        .background(theme.backgroundColor.ignoresSafeArea())
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(viewModel: viewModel)
        }
        .alert("Create Namespace", isPresented: $showingNamespaceDialog) {
            namespaceDialogContent
        } message: {
            Text("Enter a name for the new namespace:")
        }
        .alert("Create Pinecone Index", isPresented: $viewModel.showingCreateIndexDialog) {
            createIndexDialogContent
        } message: {
            Text("Enter a name for the new index (lowercase, alphanumeric, hyphens):")
        }
        .animation(.spring(duration: 0.25), value: viewModel.isProcessing)
        .animation(.spring(duration: 0.25), value: viewModel.documents.count)
        .animation(.spring(duration: 0.25), value: viewModel.selectedDocuments)
    }
}

private extension DocumentsView {
    // MARK: - Hero

    var heroSection: some View {
        let metrics = viewModel.dashboardMetrics
        let namespaceVectors = formattedCount(viewModel.selectedNamespaceVectorCount)
        let avgRuntime = formattedDuration(metrics.averageProcessingSeconds)

        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Document Orchestration")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimaryColor)

                Text("Flow documents through extraction → embeddings → Pinecone in lockstep with the Architecture, DataModeling, and IndexingOverview guides.")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondaryColor)
            }

            LazyVGrid(columns: heroGridColumns, spacing: 14) {
                metricTile(
                    title: "Aligned",
                    value: "\(metrics.processed)/\(metrics.totalDocuments)",
                    caption: "Documents indexed",
                    icon: "checkmark.seal.fill",
                    accent: theme.successColor
                )

                metricTile(
                    title: "Pending",
                    value: formattedCount(metrics.pending),
                    caption: "Awaiting embedding",
                    icon: "hourglass",
                    accent: theme.warningColor
                )

                metricTile(
                    title: "Namespace vectors",
                    value: namespaceVectors,
                    caption: namespaceLabel,
                    icon: "point.3.connected.trianglepath.dotted",
                    accent: theme.accentColor
                )

                metricTile(
                    title: "Avg runtime",
                    value: avgRuntime,
                    caption: "Per document processing",
                    icon: "timer",
                    accent: theme.infoColor
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [theme.primaryColor.opacity(0.22), theme.secondaryColor.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(theme.primaryColor.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 12)
        )
    }

    var securityConsentBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "lock.doc")
                    .foregroundColor(theme.warningColor)
                    .font(.system(size: 20, weight: .semibold))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Before you add files")
                        .font(.headline)
                        .foregroundColor(theme.textPrimaryColor)
                    Text("OpenCone keeps a sandbox copy of every imported file and may send derived text to OpenAI and Pinecone using the keys you provide. You can revoke access at any time from Settings -> Advanced.")
                        .font(.caption)
                        .foregroundColor(theme.textSecondaryColor)
                }
            }

            Button {
                viewModel.acknowledgeSecurityConsent()
            } label: {
                Text("I understand")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(theme.warningColor)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(theme.warningColor.opacity(0.12))
        )
    }

    var heroGridColumns: [GridItem] { [GridItem(.flexible()), GridItem(.flexible())] }

    func metricTile(title: String, value: String, caption: String, icon: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .foregroundColor(accent)
                        .font(.system(size: 18, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(.caption2)
                        .foregroundColor(theme.textSecondaryColor)
                        .tracking(0.8)

                    Text(value)
                        .font(.title2.bold())
                        .foregroundColor(theme.textPrimaryColor)
                }
            }

            Text(caption)
                .font(.caption)
                .foregroundColor(theme.textSecondaryColor)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.18))
                .blendMode(.plusLighter)
        )
    }

    var namespaceLabel: String {
        let namespace = viewModel.selectedNamespace ?? ""
        return namespace.isEmpty ? "Default namespace" : namespace
    }

    // MARK: - Index Overview

    var indexOverviewSection: some View {
        sectionContainer(
            title: "Index Alignment",
            subtitle: "TargetIndex • ManageNamespace",
            icon: "server.rack"
        ) {
            VStack(alignment: .leading, spacing: 18) {
                indexPickerRow
                namespacePickerRow

                if let metadata = viewModel.indexMetadata {
                    indexMetadataGrid(metadata)
                } else if viewModel.pineconeIndexes.isEmpty {
                    // No indexes exist - prompt to create one
                    calloutCard(
                        title: "No indexes found",
                        message: "Create your first Pinecone index to start ingesting documents. Indexes store your vector embeddings and enable semantic search.",
                        icon: "exclamationmark.triangle",
                        color: theme.warningColor
                    )
                    OCButton(
                        title: "Create Index",
                        icon: "plus.circle.fill",
                        style: .primary
                    ) {
                        viewModel.showingCreateIndexDialog = true
                    }
                    .disabled(viewModel.isLoadingIndexes)
                } else {
                    // Indexes exist but none selected
                    calloutCard(
                        title: "Select an index",
                        message: "Choose a Pinecone index from the picker above to view its configuration and start processing documents.",
                        icon: "info.circle",
                        color: theme.infoColor
                    )
                }

                if let stats = viewModel.indexStats {
                    if viewModel.namespaces.isEmpty {
                        // Index exists but no namespaces - prompt to create one
                        calloutCard(
                            title: "No namespaces found",
                            message: "Create your first namespace to organize vectors within this index. Start with 'default' or create a custom namespace.",
                            icon: "exclamationmark.triangle",
                            color: theme.warningColor
                        )
                        HStack(spacing: 12) {
                            OCButton(
                                title: "Create Namespace",
                                icon: "plus.circle.fill",
                                style: .primary
                            ) {
                                showingNamespaceDialog = true
                            }
                            OCButton(
                                title: "Use Default",
                                icon: "checkmark.circle",
                                style: .outline
                            ) {
                                viewModel.createNamespace("")
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Namespaces")
                                .font(.subheadline.bold())
                                .foregroundColor(theme.textPrimaryColor)

                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.namespaces, id: \.self) { namespace in
                                    namespaceRow(
                                        namespace,
                                        vectorCount: stats.namespaces[namespace]?.vectorCount ?? 0
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    var indexPickerRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Active index", systemImage: "server.rack")
                .font(.subheadline.bold())
                .foregroundColor(theme.textPrimaryColor)

            HStack(spacing: 12) {
                Menu {
                    if viewModel.pineconeIndexes.isEmpty {
                        Text("No indexes found")
                    } else {
                        ForEach(viewModel.pineconeIndexes, id: \.self) { index in
                            Button {
                                Task { await viewModel.setIndex(index) }
                            } label: {
                                Label(index, systemImage: viewModel.selectedIndex == index ? "checkmark" : "circle")
                            }
                        }
                    }
                } label: {
                    pickerLabel(
                        title: viewModel.selectedIndex ?? "Select a Pinecone index",
                        subtitle: "Hosts embeddings and namespaces",
                        icon: "internaldrive"
                    )
                }
                .disabled(viewModel.isProcessing || viewModel.isLoadingIndexes)

                iconCircleButton(systemName: "plus", isDisabled: viewModel.isProcessing || viewModel.isLoadingIndexes) {
                    viewModel.showingCreateIndexDialog = true
                }

                iconCircleButton(systemName: "arrow.clockwise", isDisabled: viewModel.isProcessing || viewModel.isLoadingIndexes) {
                    Task { await viewModel.loadIndexes() }
                }
            }
        }
    }

    var namespacePickerRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Namespace", systemImage: "folder")
                .font(.subheadline.bold())
                .foregroundColor(theme.textPrimaryColor)

            HStack(spacing: 12) {
                Menu {
                    if viewModel.namespaces.isEmpty {
                        Button("Default") { viewModel.setNamespace("") }
                    } else {
                        ForEach(viewModel.namespaces, id: \.self) { namespace in
                            Button {
                                viewModel.setNamespace(namespace)
                            } label: {
                                Label(namespaceDisplayName(namespace), systemImage: currentNamespaceSymbol(namespace))
                            }
                        }
                    }
                } label: {
                    pickerLabel(
                        title: namespaceDisplayName(viewModel.selectedNamespace ?? ""),
                        subtitle: "Logical group inside the index",
                        icon: "rectangle.connected.to.line.below"
                    )
                }
                .disabled(viewModel.isProcessing || viewModel.isLoadingIndexes)

                iconCircleButton(systemName: "arrow.clockwise", isDisabled: viewModel.isProcessing) {
                    Task { await viewModel.refreshIndexInsights() }
                }

                iconCircleButton(systemName: "plus", isDisabled: viewModel.isProcessing) {
                    showingNamespaceDialog = true
                }
            }
        }
    }

    func indexMetadataGrid(_ metadata: IndexDescribeResponse) -> some View {
        let dimension = formattedCount(metadata.dimension)
        let totalVectors = formattedCount(viewModel.totalIndexVectorCount)
        let state = metadata.status.ready ? "Ready" : metadata.status.state

        return LazyVGrid(columns: heroGridColumns, spacing: 14) {
            infoChip(icon: "ruler", label: "Dimension", value: dimension)
            infoChip(icon: "waveform", label: "Metric", value: metadata.metric.capitalized)
            infoChip(icon: "antenna.radiowaves.left.and.right", label: "Status", value: state)
            infoChip(icon: "square.stack.3d.up.fill", label: "Total vectors", value: totalVectors)
        }
    }

    func namespaceRow(_ namespace: String, vectorCount: Int) -> some View {
        let isSelected = (viewModel.selectedNamespace ?? "") == namespace

        return Button {
            viewModel.setNamespace(namespace)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(theme.primaryColor.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: "shippingbox")
                        .foregroundColor(theme.primaryColor)
                        .font(.system(size: 18, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(namespaceDisplayName(namespace))
                        .font(.subheadline.bold())
                        .foregroundColor(theme.textPrimaryColor)
                    Text("Vectors: \(formattedCount(vectorCount))")
                        .font(.caption)
                        .foregroundColor(theme.textSecondaryColor)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.successColor)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? theme.successLight : theme.cardBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isSelected ? theme.successColor.opacity(0.4) : theme.cardBackgroundColor, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    func pickerLabel(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.primaryColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundColor(theme.primaryColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(theme.textPrimaryColor)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(theme.textSecondaryColor)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.down")
                .foregroundColor(theme.textSecondaryColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(theme.backgroundColor)
        )
    }

    func currentNamespaceSymbol(_ namespace: String) -> String {
        (viewModel.selectedNamespace ?? "") == namespace ? "checkmark" : "circle"
    }

    // MARK: - Pipeline Readiness

    var pipelineSection: some View {
        sectionContainer(
            title: "Pipeline Readiness",
            subtitle: "Architecture • IndexingOverview",
            icon: "chart.bar.doc.horizontal"
        ) {
            LazyVGrid(columns: heroGridColumns, spacing: 16) {
                ForEach(pipelineStages) { stage in
                    stageCard(stage)
                }
            }

            if viewModel.hasDocumentFailures {
                calloutCard(
                    title: "Investigate failures",
                    message: "Some documents require attention before they can be aligned with Pinecone. Use Document Details to review the processing log and address extraction or embedding issues.",
                    icon: "exclamationmark.triangle.fill",
                    color: theme.errorColor
                )
            }
        }
    }

    var pipelineStages: [PipelineStage] {
        let metrics = viewModel.dashboardMetrics
        let pendingText = metrics.pending == 0 ? "All documents staged" : "\(formattedCount(metrics.pending)) pending"
        let processedText = "Processed \(formattedCount(metrics.processed)) • Failed \(formattedCount(metrics.failed))"
        let stageOneAccent = metrics.pending == 0 && metrics.failed == 0 ? theme.successColor : theme.warningColor

        let chunksText = "Chunks: \(formattedCount(metrics.totalChunks))"
        let vectorsText = "Vectors prepared: \(formattedCount(metrics.totalVectors))"
        let stageTwoAccent = metrics.totalChunks > 0 ? theme.accentColor : theme.warningColor

        let namespaceVectors = formattedCount(viewModel.selectedNamespaceVectorCount)
        let indexVectors = formattedCount(viewModel.totalIndexVectorCount)
        let stageThreeAccent = viewModel.selectedNamespaceVectorCount > 0 ? theme.successColor : theme.infoColor

        let lastDoc = viewModel.latestProcessedDocument
        let lastRun = formattedRelativeTime(lastDoc?.processingStats?.endTime)
        let stageFourAccent = viewModel.hasDocumentFailures ? theme.errorColor : theme.accentColor

        return [
            PipelineStage(
                title: "Source material",
                headline: pendingText,
                detail: processedText,
                icon: "tray.full",
                accent: stageOneAccent
            ),
            PipelineStage(
                title: "Vector preparation",
                headline: chunksText,
                detail: "\(vectorsText) • Avg runtime: \(formattedDuration(metrics.averageProcessingSeconds))",
                icon: "square.stack.3d.up",
                accent: stageTwoAccent
            ),
            PipelineStage(
                title: "Pinecone sync",
                headline: "Namespace vectors: \(namespaceVectors)",
                detail: "Index total: \(indexVectors)",
                icon: "point.3.connected.trianglepath.dotted",
                accent: stageThreeAccent
            ),
            PipelineStage(
                title: "Quality signals",
                headline: "Last run: \(lastRun)",
                detail: viewModel.hasDocumentFailures ? "Failures detected" : "No outstanding errors",
                icon: "waveform.path.ecg",
                accent: stageFourAccent
            )
        ]
    }

    func stageCard(_ stage: PipelineStage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(stage.accent.opacity(0.18))
                        .frame(width: 46, height: 46)
                    Image(systemName: stage.icon)
                        .foregroundColor(stage.accent)
                        .font(.system(size: 19, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(stage.title.uppercased())
                        .font(.caption2)
                        .foregroundColor(theme.textSecondaryColor)
                        .tracking(0.7)

                    Text(stage.headline)
                        .font(.subheadline.bold())
                        .foregroundColor(theme.textPrimaryColor)
                        .lineLimit(1)
                }
            }

            Text(stage.detail)
                .font(.caption)
                .foregroundColor(theme.textSecondaryColor)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(theme.cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(stage.accent.opacity(0.28), lineWidth: 1)
                )
        )
    }

    struct PipelineStage: Identifiable {
        let id = UUID()
        let title: String
        let headline: String
        let detail: String
        let icon: String
        let accent: Color
    }

    // MARK: - Processing Panel

    var processingPanel: some View {
        Group {
            if viewModel.isProcessing {
                sectionContainer(
                    title: "Live Processing",
                    subtitle: "DataModeling • UpdateRecords",
                    icon: "bolt.fill"
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            ProgressView(value: viewModel.processingProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: theme.primaryColor))
                                .scaleEffect(x: 1, y: 1.6, anchor: .center)

                            Text("\(Int(viewModel.processingProgress * 100))%")
                                .font(.footnote.bold())
                                .foregroundColor(theme.primaryColor)
                        }

                        if let status = viewModel.currentProcessingStatus {
                            Text(status)
                                .font(.caption)
                                .foregroundColor(theme.textSecondaryColor)
                        }

                        if let stats = viewModel.processingStats {
                            HStack(spacing: 12) {
                                processingStatTile(value: formattedCount(stats.totalDocuments), label: "Docs")
                                processingStatTile(value: formattedCount(stats.totalChunks), label: "Chunks")
                                processingStatTile(value: formattedCount(stats.totalVectors), label: "Vectors")
                            }
                        }
                    }
                }
            }
        }
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
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.primaryColor.opacity(0.12))
        )
    }

    // MARK: - Document Catalog

    var documentCatalogSection: some View {
        sectionContainer(
            title: "Document Catalog",
            subtitle: "DataModeling • DeleteRecords",
            icon: "doc.on.doc"
        ) {
            if viewModel.documents.isEmpty {
                calloutCard(
                    title: "Bring your knowledge base",
                    message: "Add PDFs, slide decks, spreadsheets, or notes to begin chunking and syncing with Pinecone.",
                    icon: "doc.badge.plus",
                    color: theme.accentColor
                )
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.documents) { document in
                        documentCard(for: document)
                    }
                }
            }
        }
    }

    func documentCard(for document: DocumentModel) -> some View {
        let isSelected = viewModel.selectedDocuments.contains(document.id)
        let vectors = document.processingStats?.vectorsUploaded ?? document.chunkCount
        let processedAt = document.processingStats?.endTime
        let lastRuntime = document.processingStats?.totalProcessingTime ?? 0

        return Button {
            viewModel.toggleDocumentSelection(document.id)
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(document.viewIconColor.opacity(0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: document.viewIconName)
                            .foregroundColor(document.viewIconColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.fileName)
                            .font(.headline)
                            .foregroundColor(theme.textPrimaryColor)
                            .lineLimit(1)

                        Text("Added \(formattedRelativeTime(document.dateAdded))")
                            .font(.caption)
                            .foregroundColor(theme.textSecondaryColor)
                    }

                    Spacer()

                    documentStatusBadge(for: document)
                }

                HStack(spacing: 8) {
                    metadataTag(document.mimeType, systemImage: "doc.text")
                    metadataTag(document.formattedFileSize, systemImage: "opticaldisc")
                    metadataTag(document.documentId.prefix(8) + "…", systemImage: "number")
                }

                Divider().background(theme.cardBackgroundColor)

                HStack(spacing: 12) {
                    documentStatChip(value: formattedCount(document.chunkCount), label: "Chunks", icon: "square.on.square")
                    documentStatChip(value: formattedCount(vectors), label: "Vectors", icon: "point.3.connected.trianglepath.dotted")
                    documentStatChip(value: formattedDuration(lastRuntime), label: "Runtime", icon: "clock")
                    documentStatChip(value: formattedRelativeTime(processedAt), label: "Indexed", icon: "calendar")
                }

                if let error = document.processingError {
                    calloutCard(
                        title: "Processing issue",
                        message: error,
                        icon: "exclamationmark.triangle.fill",
                        color: theme.errorColor
                    )
                }

                HStack {
                    NavigationLink(destination: DocumentDetailsView(document: document)) {
                        Label("Open telemetry", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(theme.primaryColor)

                    Spacer()

                    if isSelected {
                        Label("Selected", systemImage: "checkmark.circle.fill")
                            .font(.caption.bold())
                            .foregroundColor(theme.successColor)
                    } else {
                        Text("Tap card to select for processing")
                            .font(.caption)
                            .foregroundColor(theme.textSecondaryColor)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(theme.cardBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(isSelected ? theme.primaryColor.opacity(0.35) : theme.cardBackgroundColor, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    func documentStatusBadge(for document: DocumentModel) -> some View {
        if let _ = document.processingError {
            badgeLabel(text: "Failed", color: theme.errorColor, background: theme.errorLight, icon: "exclamationmark.triangle.fill")
        } else if document.isProcessed {
            badgeLabel(text: "Processed", color: theme.successColor, background: theme.successLight, icon: "checkmark.circle.fill")
        } else {
            badgeLabel(text: "Pending", color: theme.warningColor, background: theme.warningColor.opacity(0.15), icon: "hourglass")
        }
    }

    func badgeLabel(text: String, color: Color, background: Color, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
                .font(.caption.bold())
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(background)
        )
    }

    func metadataTag<T: StringProtocol>(_ text: T, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(String(text))
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(theme.primaryColor.opacity(0.12))
        )
        .foregroundColor(theme.textPrimaryColor)
    }

    func documentStatChip(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.caption)
            .foregroundColor(theme.textSecondaryColor)

            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(theme.textPrimaryColor)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Operations

    var operationsSection: some View {
        sectionContainer(
            title: "Operations",
            subtitle: "IndexingOverview • DeleteRecords",
            icon: "slider.horizontal.3"
        ) {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    primaryActionButton(
                        title: "Add files",
                        icon: "doc.badge.plus",
                        isEnabled: !viewModel.isProcessing && !viewModel.needsSecurityConsent
                    ) {
                        showingDocumentPicker = true
                    }

                    primaryActionButton(
                        title: "Process selection",
                        icon: "sparkles",
                        isEnabled: !viewModel.selectedDocuments.isEmpty && !viewModel.isProcessing && viewModel.selectedIndex != nil
                    ) {
                        Task { await viewModel.processSelectedDocuments() }
                    }
                }

                HStack(spacing: 16) {
                    secondaryActionButton(
                        title: "Remove",
                        icon: "trash",
                        tint: theme.errorColor,
                        isEnabled: !viewModel.selectedDocuments.isEmpty && !viewModel.isProcessing
                    ) {
                        withAnimation { viewModel.removeSelectedDocuments() }
                    }

                    secondaryActionButton(
                        title: "Refresh stats",
                        icon: "arrow.clockwise",
                        tint: theme.primaryColor,
                        isEnabled: !viewModel.isProcessing
                    ) {
                        Task { await viewModel.refreshIndexInsights() }
                    }

                    secondaryActionButton(
                        title: "Reload indexes",
                        icon: "cloud",
                        tint: theme.infoColor,
                        isEnabled: !viewModel.isProcessing
                    ) {
                        Task { await viewModel.loadIndexes() }
                    }
                }

                calloutCard(
                    title: "Pinecone tip",
                    message: "Re-run ingestion in small batches after deleting stale vectors so namespace counts stay in sync (see DeleteRecords).",
                    icon: "lightbulb.fill",
                    color: theme.accentColor
                )
            }
        }
    }

    func primaryActionButton(title: String, icon: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundColor(.white)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [theme.primaryColor, theme.primaryColor.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.45)
        .disabled(!isEnabled)
    }

    func secondaryActionButton(title: String, icon: String, tint: Color, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundColor(tint)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(tint.opacity(0.6), lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.35)
        .disabled(!isEnabled)
    }

    // MARK: - Pinecone References

    var referencesSection: some View {
        sectionContainer(
            title: "Pinecone Playbooks",
            subtitle: "Architecture • DataModeling • TargetIndex",
            icon: "book.closed"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(docReferences) { reference in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(theme.primaryColor.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: reference.symbol)
                                .foregroundColor(theme.primaryColor)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(reference.title)
                                .font(.subheadline.bold())
                                .foregroundColor(theme.textPrimaryColor)
                            Text(reference.summary)
                                .font(.caption)
                                .foregroundColor(theme.textSecondaryColor)
                        }
                        Spacer()
                    }
                }

                Text("Review these guides inside PineconeDocs to keep ingestion decisions aligned with platform best practices.")
                    .font(.caption)
                    .foregroundColor(theme.textSecondaryColor)
            }
        }
    }

    struct DocReference: Identifiable {
        let id = UUID()
        let title: String
        let summary: String
        let symbol: String
    }

    var docReferences: [DocReference] {
        [
            DocReference(
                title: "Architecture",
                summary: "Frame how ingestion, retrieval, and generation interact across services.",
                symbol: "building.columns"
            ),
            DocReference(
                title: "Data Modeling",
                summary: "Design metadata, chunking, and vector IDs that remain stable across updates.",
                symbol: "tablecells"
            ),
            DocReference(
                title: "Target Index",
                summary: "Validate dimensions, metrics, and namespace hygiene before shipping to production.",
                symbol: "target"
            )
        ]
    }

    // MARK: - Shared Helpers

    func sectionContainer<Content: View>(title: String, subtitle: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(theme.primaryColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(theme.textPrimaryColor)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(theme.textSecondaryColor)
                }
                Spacer()
            }

            content()
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(theme.cardBackgroundColor)
                .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
        )
    }

    func calloutCard(title: String, message: String, icon: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 18, weight: .semibold))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(theme.textPrimaryColor)
                Text(message)
                    .font(.caption)
                    .foregroundColor(theme.textSecondaryColor)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(color.opacity(0.12))
        )
    }

    func infoChip(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(theme.primaryColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.caption2)
                    .foregroundColor(theme.textSecondaryColor)
                    .tracking(0.7)
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundColor(theme.textPrimaryColor)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.backgroundColor)
        )
    }

    func iconCircleButton(systemName: String, isDisabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundColor(theme.primaryColor)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(theme.primaryColor.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.35 : 1)
    }

    func namespaceDisplayName(_ namespace: String) -> String {
        namespace.isEmpty ? "default" : namespace
    }

    func formattedCount(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    func formattedDuration(_ seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        if seconds < 1 {
            return String(format: "%.2fs", seconds)
        } else if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else {
            let minutes = seconds / 60
            return String(format: "%.1f min", minutes)
        }
    }

    func formattedRelativeTime(_ date: Date?) -> String {
        guard let date else { return "—" }
        return DocumentsView.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    // MARK: - Dialog Content

    var namespaceDialogContent: some View {
        Group {
            TextField("Namespace Name", text: $newNamespace)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

            Button("Cancel", role: .cancel) {
                newNamespace = ""
            }

            Button("Create") {
                guard !newNamespace.isEmpty else { return }
                viewModel.createNamespace(newNamespace)
                newNamespace = ""
            }
        }
    }

    var createIndexDialogContent: some View {
        Group {
            TextField("Index Name", text: $viewModel.newIndexName)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .onSubmit {
                    if !viewModel.newIndexName.isEmpty {
                        Task { await viewModel.createIndex() }
                    }
                }

            Button("Cancel", role: .cancel) {
                viewModel.newIndexName = ""
            }

            Button("Create") {
                Task { await viewModel.createIndex() }
            }
            .disabled(viewModel.newIndexName.isEmpty || viewModel.isLoadingIndexes)
        }
    }
}

