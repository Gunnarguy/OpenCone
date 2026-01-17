// MARK: - SettingsView.swift
import SwiftUI

/// View for app settings
struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var isShowingResetAlert = false
    @State private var isSaved = false
    @State private var animateSaveIcon = false
    @State private var showSecureResetDialog = false
    @State private var showAdvancedSettings = false
    @State private var showExportSheet = false
    @State private var showImportSheet = false
    @State private var importText = ""
    @State private var exportedJSON = ""
    @State private var showClearConversationAlert = false

    private var theme: OCTheme { themeManager.currentTheme }

    var body: some View {
        NavigationStack {
            ScrollView { 
                VStack(spacing: 0) {
                    // Header
                    settingsHeader

                    // Main content
                    VStack(spacing: 24) {
                        // Quick Status Card
                        connectionStatusCard

                        // AI Configuration
                        NavigationLink {
                            AISettingsDetailView(viewModel: viewModel)
                        } label: {
                            SettingsRow(
                                icon: "brain.head.profile",
                                iconColor: .purple,
                                title: "AI Models",
                                subtitle: viewModel.completionModel,
                                showChevron: true
                            )
                        }
.buttonStyle(.plain)

                        // API Keys & Connections
                        NavigationLink {
                            ConnectionsDetailView(viewModel: viewModel)
                        } label: {
                            SettingsRow(
                                icon: "key.fill",
                                iconColor: .orange,
                                title: "API Keys & Connections",
                                subtitle: connectionsSummary,
                                badge: connectionBadge,
                                showChevron: true
                            )
                        }
.buttonStyle(.plain)

                        // Search & Retrieval
                        NavigationLink {
                            SearchSettingsDetailView(viewModel: viewModel)
                        } label: {
                            SettingsRow(
                                icon: "magnifyingglass",
                                iconColor: .blue,
                                title: "Search & Retrieval",
                                subtitle: "Top \(viewModel.defaultTopK) results",
                                showChevron: true
                            )
                        }
.buttonStyle(.plain)

                        // Document Processing
                        NavigationLink {
                            ProcessingSettingsDetailView(viewModel: viewModel)
                        } label: {
                            SettingsRow(
                                icon: "doc.text.fill",
                                iconColor: .green,
                                title: "Document Processing",
                                subtitle: "Chunk: \(viewModel.defaultChunkSize) / \(viewModel.defaultChunkOverlap)",
                                showChevron: true
                            )
                        }
.buttonStyle(.plain)

                        // AI Tools Section
                        aiToolsSection

                        // Pinecone Search Section
                        pineconeSearchSection

                        // Appearance
                        NavigationLink {
                            AppearanceSettingsView(viewModel: viewModel)
                        } label: {
                            SettingsRow(
                                icon: "paintpalette.fill",
                                iconColor: theme.primaryColor,
                                title: "Appearance", 
                                subtitle: theme.name,
                                showChevron: true,
                                accessory: {
                                        HStack(spacing: 4) {
                                            Circle().fill(theme.primaryColor).frame(width: 14, height: 14)
                                            Circle().fill(theme.secondaryColor).frame(width: 14, height: 14)
                                        }
                                }
                            )
                        }
                        .buttonStyle(.plain)

                        // Advanced
                        NavigationLink {
                            AdvancedSettingsView(viewModel: viewModel)
                        } label: {
                            SettingsRow(
                                icon: "gearshape.2.fill",
                                iconColor: .gray,
                                title: "Advanced",
                                subtitle: "Network, logging, debug",
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)

                        // Data & Privacy
                        dataPrivacySection

                        // About
                        aboutSection
                    }
                    .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
            }
            .background(theme.backgroundColor.ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Reset Settings", isPresented: $isShowingResetAlert) {
            Button("Reset", role: .destructive) { viewModel.resetToDefaults() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Reset all settings to defaults? API keys will be preserved.")
        }
        .confirmationDialog("Reset stored keys?", isPresented: $showSecureResetDialog, titleVisibility: .visible) {
            Button("Reset Everything", role: .destructive) { viewModel.resetSecureState() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes API keys, preferences, conversation history, and bookmark consent.")
        }
        .alert("Clear Conversation", isPresented: $showClearConversationAlert) {
            Button("Clear", role: .destructive) { viewModel.clearConversationHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Clear all conversation history?")
        }
        .sheet(isPresented: $showExportSheet) { exportSettingsSheet }
        .sheet(isPresented: $showImportSheet) { importSettingsSheet }
    }

    // MARK: - Header

    private var settingsHeader: some View {
        VStack(spacing: 16) {
            // App Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.primaryColor, theme.secondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "cone.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.white)
            }
            .shadow(color: theme.primaryColor.opacity(0.3), radius: 12, y: 6)

            VStack(spacing: 4) {
                Text("OpenCone")
                    .font(.title2.bold())
                    .foregroundColor(theme.textPrimaryColor)

                Text("Version 2.3")
                    .font(.caption)
                    .foregroundColor(theme.textSecondaryColor)
            }

            // Auto-save indicator
            if viewModel.autoSaveEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(theme.successColor)
                    Text("Auto-save enabled")
                        .font(.caption2)
                        .foregroundColor(theme.textSecondaryColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(theme.cardBackgroundColor))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(theme.cardBackgroundColor)
    }

    // MARK: - Connection Status Card

    private var connectionStatusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Connection Status")
                    .font(.subheadline.bold())
                    .foregroundColor(theme.textSecondaryColor)
                Spacer()
                Button {
                    viewModel.validateAll()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                        Text("Check")
                            .font(.caption)
                    }
                    .foregroundColor(theme.primaryColor)
                }
            }

            HStack(spacing: 16) {
                StatusPill(
                    label: "OpenAI",
                    status: viewModel.openAIStatus,
                    theme: theme
                )

                StatusPill(
                    label: "Pinecone",
                    status: viewModel.pineconeStatus,
                    theme: theme
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackgroundColor)
        )
    }

    // MARK: - AI Tools Section

    private var aiToolsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(theme.textSecondaryColor)
                Text("AI TOOLS")
                    .font(.caption.bold())
                    .foregroundColor(theme.textSecondaryColor)
                Spacer()
            }
            .padding(.bottom, 8)

            VStack(spacing: 1) {
                ToolToggleRow(
                    icon: "globe",
                    title: "Web Search",
                    subtitle: "Search the internet",
                    isOn: $viewModel.webSearchEnabled,
                    theme: theme
                )

                ToolToggleRow(
                    icon: "terminal",
                    title: "Code Interpreter",
                    subtitle: "Run Python code",
                    isOn: $viewModel.codeInterpreterEnabled,
                    theme: theme
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Pinecone Search Section

    private var pineconeSearchSection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass.circle")
                    .font(.caption)
                    .foregroundColor(theme.textSecondaryColor)
                Text("PINECONE SEARCH")
                    .font(.caption.bold())
                    .foregroundColor(theme.textSecondaryColor)
                Spacer()
            }
            .padding(.bottom, 8)

            VStack(spacing: 1) {
                // Hybrid Search Toggle
                ToolToggleRow(
                    icon: "arrow.triangle.merge",
                    title: "Hybrid Search",
                    subtitle: "Combine semantic + keyword search",
                    isOn: $viewModel.hybridSearchEnabled,
                    theme: theme
                )

                // Alpha Slider (only shown when hybrid is enabled)
                if viewModel.hybridSearchEnabled {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Search Balance")
                                .font(.subheadline)
                                .foregroundColor(theme.textPrimaryColor)
                            Spacer()
                            Text(hybridAlphaLabel)
                                .font(.caption)
                                .foregroundColor(theme.textSecondaryColor)
                        }

                        Slider(value: $viewModel.hybridSearchAlpha, in: 0 ... 1, step: 0.1)
                            .tint(theme.primaryColor)

                        HStack {
                            Text("Keywords")
                                .font(.caption2)
                                .foregroundColor(theme.textSecondaryColor)
                            Spacer()
                            Text("Semantic")
                                .font(.caption2)
                                .foregroundColor(theme.textSecondaryColor)
                        }
                    }
                    .padding()
                    .background(theme.cardBackgroundColor)
                }

                // Reranking Toggle
                ToolToggleRow(
                    icon: "arrow.up.arrow.down",
                    title: "Reranking",
                    subtitle: "Improve result relevance",
                    isOn: $viewModel.rerankingEnabled,
                    theme: theme
                )

                // Rerank Options (only shown when reranking is enabled)
                if viewModel.rerankingEnabled {
                    VStack(spacing: 12) {
                        // Model Picker
                        HStack {
                            Text("Model")
                                .font(.subheadline)
                                .foregroundColor(theme.textPrimaryColor)
                            Spacer()
                            Picker("", selection: $viewModel.rerankModel) {
                                ForEach(viewModel.availableRerankModels, id: \.self) { model in
                                    Text(rerankModelDisplayName(model))
                                        .tag(model)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(theme.primaryColor)
                        }

                        // Top N Stepper
                        HStack {
                            Text("Top Results")
                                .font(.subheadline)
                                .foregroundColor(theme.textPrimaryColor)
                            Spacer()
                            Stepper("\(viewModel.rerankTopN)", value: $viewModel.rerankTopN, in: 1 ... 20)
                                .labelsHidden()
                            Text("\(viewModel.rerankTopN)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundColor(theme.textSecondaryColor)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                    .padding()
                    .background(theme.cardBackgroundColor)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    /// Human-readable label for hybrid alpha value
    private var hybridAlphaLabel: String {
        let alpha = viewModel.hybridSearchAlpha
        if alpha < 0.3 {
            return "Keyword-focused"
        } else if alpha > 0.7 {
            return "Semantic-focused"
        } else {
            return "Balanced"
        }
    }

    /// Human-readable display name for rerank model
    private func rerankModelDisplayName(_ model: String) -> String {
        switch model {
        case "bge-reranker-v2-m3":
            return "BGE Reranker v2"
        case "cohere-rerank-3.5":
            return "Cohere Rerank 3.5"
        case "pinecone-rerank-v0":
            return "Pinecone Rerank"
        default:
            return model
        }
    }

    // MARK: - Data & Privacy Section

    private var dataPrivacySection: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "lock.shield")
                    .font(.caption)
                    .foregroundColor(theme.textSecondaryColor)
                Text("DATA & PRIVACY")
                    .font(.caption.bold())
                    .foregroundColor(theme.textSecondaryColor)
                Spacer()
            }
            .padding(.bottom, 8)

            VStack(spacing: 1) {
                Button {
                    showClearConversationAlert = true
                } label: {
                    SettingsActionRow(
                        icon: "bubble.left.and.bubble.right",
                        iconColor: .blue,
                        title: "Clear Conversation History",
                        theme: theme
                    )
                }
                .buttonStyle(.plain)

                Button {
                    if let json = viewModel.exportSettingsAsJSON() {
                        exportedJSON = json
                        showExportSheet = true
                    }
                } label: {
                    SettingsActionRow(
                        icon: "square.and.arrow.up",
                        iconColor: .green,
                        title: "Export Settings",
                        theme: theme
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showImportSheet = true
                } label: {
                    SettingsActionRow(
                        icon: "square.and.arrow.down",
                        iconColor: .orange,
                        title: "Import Settings",
                        theme: theme
                    )
                }
                .buttonStyle(.plain)

                Button {
                    showSecureResetDialog = true
                } label: {
                    SettingsActionRow(
                        icon: "trash",
                        iconColor: .red,
                        title: "Reset All Data",
                        isDestructive: true,
                        theme: theme
                    )
                }
                .buttonStyle(.plain)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(spacing: 12) {
            if let privacyURL = URL(string: "https://github.com/Gunnarguy/OpenCone/blob/main/PRIVACY.md") {
                Link(destination: privacyURL) {
                    SettingsActionRow(
                        icon: "doc.text",
                        iconColor: .blue,
                        title: "Privacy Policy",
                        showExternalLink: true,
                        theme: theme
                    )
                }
            }

            if let repoURL = URL(string: "https://github.com/Gunnarguy/OpenCone") {
                Link(destination: repoURL) {
                    SettingsActionRow(
                        icon: "chevron.left.forwardslash.chevron.right",
                        iconColor: .purple,
                        title: "Source Code",
                        showExternalLink: true,
                        theme: theme
                    )
                }
            }

            Text("Made with ❤️ for RAG enthusiasts")
                .font(.caption)
                .foregroundColor(theme.textSecondaryColor)
                .padding(.top, 8)
        }
    }

    // MARK: - Helpers

    private var connectionsSummary: String {
        let hasOpenAI = !viewModel.openAIAPIKey.isEmpty
        let hasPinecone = !viewModel.pineconeAPIKey.isEmpty
        if hasOpenAI && hasPinecone { return "All configured" }
        if hasOpenAI { return "OpenAI only" }
        if hasPinecone { return "Pinecone only" }
        return "Not configured"
    }

    private var connectionBadge: String? {
        let valid = (viewModel.openAIStatus == .valid ? 1 : 0) + (viewModel.pineconeStatus == .valid ? 1 : 0)
        return valid > 0 ? "\(valid)/2" : nil
    }

    // MARK: - Auto-save Status Bar

    private var autoSaveStatusBar: some View {
        HStack(spacing: 12) {
            // Auto-save toggle
            Toggle(isOn: $viewModel.autoSaveEnabled) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.autoSaveEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(viewModel.autoSaveEnabled ? themeManager.currentTheme.successColor : themeManager.currentTheme.textSecondaryColor)
                    Text("Auto-save")
                        .font(.subheadline)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: themeManager.currentTheme.primaryColor))

            Spacer()

            // Save status indicator
            if viewModel.isSaving {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Saving...")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                }
            } else if let lastSave = viewModel.lastAutoSaveTime {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(themeManager.currentTheme.successColor)
                        .font(.caption)
                    Text("Saved \(lastSave, formatter: timeFormatter)")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: OCDesignSystem.Sizing.cornerRadiusSmall)
                .fill(themeManager.currentTheme.cardBackgroundColor)
        )
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }

    // MARK: - Search UI Content

    private var searchUIContent: some View {
        VStack(alignment: .leading, spacing: OCDesignSystem.Spacing.medium) {
            Toggle("Show Answer Panel under Chat", isOn: $viewModel.showAnswerPanelBelowChat)
.toggleStyle(SwitchToggleStyle(tint: themeManager.currentTheme.primaryColor))

Text("When enabled, the Answer & Sources panel stays docked under the conversation.")
    .font(.caption)
    .foregroundColor(themeManager.currentTheme.textSecondaryColor)

Divider()

Toggle("Enable Streaming Responses", isOn: $viewModel.streamingEnabled)
    .toggleStyle(SwitchToggleStyle(tint: themeManager.currentTheme.primaryColor))

Text("When enabled, answers stream in real-time. Disable for faster complete responses.")
    .font(.caption)
    .foregroundColor(themeManager.currentTheme.textSecondaryColor)

Divider()

Toggle("Include Metadata in Results", isOn: $viewModel.includeMetadataInResults)
    .toggleStyle(SwitchToggleStyle(tint: themeManager.currentTheme.primaryColor))

Text("Show document metadata (filename, chunk info) in search results.")
    .font(.caption)
    .foregroundColor(themeManager.currentTheme.textSecondaryColor)
        }
    }

    // MARK: - Quick Actions Content

    private var quickActionsContent: some View {
        VStack(alignment: .leading, spacing: OCDesignSystem.Spacing.medium) {
            // Row 1: Connection tests
            HStack(spacing: 12) {
                OCButton(
                    title: "Test Connections",
                    icon: "antenna.radiowaves.left.and.right",
                    size: .standard,
                    fullWidth: true,
                    action: { viewModel.validateAll() }
                )
            }

            // Row 2: Conversation and Export
            HStack(spacing: 12) {
                OCButton(
                    title: "Clear Chat",
                    icon: "trash",
                    style: .secondary,
                    size: .small,
                    fullWidth: true,
                    action: { showClearConversationAlert = true }
                )

                OCButton(
                    title: "Export",
                    icon: "square.and.arrow.up",
                    style: .secondary,
                    size: .small,
                    fullWidth: true,
                    action: {
                        if let json = viewModel.exportSettingsAsJSON() {
                            exportedJSON = json
                            showExportSheet = true
                        }
                    }
                )

                OCButton(
                    title: "Import",
                    icon: "square.and.arrow.down",
                    style: .secondary,
                    size: .small,
                    fullWidth: true,
                    action: { showImportSheet = true }
                )
            }

            // Settings summary
            if viewModel.showDebugInfo {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Configuration")
                        .font(.caption.bold())
                        .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                    Text(viewModel.settingsSummary)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(themeManager.currentTheme.backgroundColor)
                        )
                }
            }
        }
    }

    // MARK: - Advanced Settings Section

    private var advancedSettingsSection: some View {
        VStack(alignment: .leading, spacing: OCDesignSystem.Spacing.medium) {
            Button(action: { withAnimation { showAdvancedSettings.toggle() } }) {
                HStack {
                    Image(systemName: "gearshape.2.fill")
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    Text("Advanced Settings")
                        .font(.headline)
                    Spacer()
                    Image(systemName: showAdvancedSettings ? "chevron.up" : "chevron.down")
                        .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                }
            }
            .buttonStyle(PlainButtonStyle())

            if showAdvancedSettings {
                VStack(spacing: OCDesignSystem.Spacing.medium) {
                    // Embedding Settings
                    OCCard(style: .standard) {
                        advancedEmbeddingContent
                    }

                    // Search Advanced
                    OCCard(style: .standard) {
                        advancedSearchContent
                    }

                    // Pinecone API Versions
                    OCCard(style: .standard) {
                        advancedPineconeContent
                    }

                    // Network Settings
                    OCCard(style: .standard) {
                        advancedNetworkContent
                    }

                    // Conversation Settings
                    OCCard(style: .standard) {
                        advancedConversationContent
                    }

                    // Debug Settings
                    OCCard(style: .standard) {
                        advancedDebugContent
                    }
                }
            }
        }
    }

    // MARK: - Advanced Embedding Content

    private var advancedEmbeddingContent: some View {
        VStack(alignment: .leading, spacing: OCDesignSystem.Spacing.medium) {
            Text("Embedding Settings")
                .font(.subheadline.bold())

            VStack(alignment: .leading, spacing: 4) {
                Text("Batch Size")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                HStack {
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.embeddingBatchSize) },
                            set: { viewModel.embeddingBatchSize = Int($0) }
                        ),
                        in: 10 ... 100,
                        step: 10
                    )
                    Text("\(viewModel.embeddingBatchSize)")
                        .font(.caption.bold())
                        .frame(width: 40, alignment: .trailing)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Vector Dimension")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                Picker("Dimension", selection: $viewModel.embeddingDimension) {
                    Text("1536 (ada-002)").tag(1536)
                    Text("1536 (3-small)").tag(1536)
                    Text("3072 (3-large)").tag(3072)
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            Text("Batch size controls how many chunks are embedded per API call. Larger batches are faster but use more memory.")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.textSecondaryColor)
        }
    }

    // MARK: - Advanced Search Content

    private var advancedSearchContent: some View {
        VStack(alignment: .leading, spacing: OCDesignSystem.Spacing.medium) {
            Text("Search Settings")
                .font(.subheadline.bold())

            VStack(alignment: .leading, spacing: 4) {
                Text("Similarity Threshold")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                HStack {
                    Slider(value: $viewModel.similarityThreshold, in: 0 ... 1, step: 0.05)
                    Text(String(format: "%.2f", viewModel.similarityThreshold))
                        .font(.caption.bold())
                        .frame(width: 40, alignment: .trailing)
                }
                Text(viewModel.similarityThreshold == 0 ? "No threshold (return all results)" : "Only return results with score ≥ \(String(format: "%.2f", viewModel.similarityThreshold))")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textSecondaryColor)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Max Context Tokens")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                HStack {
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.maxContextTokens) },
                            set: { viewModel.maxContextTokens = Int($0) }
                        ),
                        in: 1000 ... 32000,
                        step: 1000
                    )
                    Text("\(viewModel.maxContextTokens)")
                        .font(.caption.bold())
                        .frame(width: 50, alignment: .trailing)
                }
            }

            Text("Maximum tokens to include from retrieved chunks in the prompt context.")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.textSecondaryColor)
        }
    }

    // MARK: - Advanced Pinecone Content

    private var advancedPineconeContent: some View {
        VStack(alignment: .leading, spacing: OCDesignSystem.Spacing.medium) {
            Text("Pinecone API Versions")
                .font(.subheadline.bold())

            VStack(alignment: .leading, spacing: 8) {
                textFieldContainer(
                    title: "Control Plane API",
                    placeholder: "2024-07",
                    text: $viewModel.pineconeControlPlaneVersion
                )

                textFieldContainer(
                    title: "Data Plane API",
                    placeholder: "2024-07",
                    text: $viewModel.pineconeDataPlaneVersion
                )

                textFieldContainer(
                    title: "Namespace API (Preview)",
                    placeholder: "2025-01",
                    text: $viewModel.pineconeNamespaceVersion
                )

                textFieldContainer(
                    title: "Metadata Fetch API (Preview)",
                    placeholder: "2025-01",
                    text: $viewModel.pineconeMetadataFetchVersion
                )
            }

            Text("Only change these if you know what you're doing. Preview APIs may change without notice.")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.warningColor)
        }
    }

    // MARK: - Advanced Network Content

    private var advancedNetworkContent: some View {
        VStack(alignment: .leading, spacing: OCDesignSystem.Spacing.medium) {
            Text("Network Settings")
                .font(.subheadline.bold())

            VStack(alignment: .leading, spacing: 4) {
                Text("Request Timeout (seconds)")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                HStack {
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.requestTimeoutSeconds) },
                            set: { viewModel.requestTimeoutSeconds = Int($0) }
                        ),
                        in: 10 ... 120,
                        step: 5
                    )
                    Text("\(viewModel.requestTimeoutSeconds)s")
                        .font(.caption.bold())
                        .frame(width: 40, alignment: .trailing)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Max Retries")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                Stepper(value: $viewModel.maxRetries, in: 0 ... 10) {
                    Text("\(viewModel.maxRetries) retries")
                        .font(.subheadline)
                }
            }

            Text("Higher timeouts prevent premature cancellations for slow connections.")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.textSecondaryColor)
        }
    }

    // MARK: - Advanced Conversation Content

    private var advancedConversationContent: some View {
        VStack(alignment: .leading, spacing: OCDesignSystem.Spacing.medium) {
            Text("Conversation Settings")
                .font(.subheadline.bold())

            VStack(alignment: .leading, spacing: 4) {
                Text("Max Conversation Turns (Client Mode)")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                Stepper(value: $viewModel.maxConversationTurns, in: 1 ... 50) {
                    Text("\(viewModel.maxConversationTurns) turns")
                        .font(.subheadline)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("System Prompt Override")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                TextEditor(text: $viewModel.systemPromptOverride)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: OCDesignSystem.Sizing.cornerRadiusSmall)
                            .fill(themeManager.currentTheme.backgroundColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: OCDesignSystem.Sizing.cornerRadiusSmall)
                            .stroke(themeManager.currentTheme.textSecondaryColor.opacity(0.25), lineWidth: 1)
                    )
                Text("Leave empty to use the default RAG system prompt. Custom prompts override the default behavior.")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textSecondaryColor)
            }
        }
    }

    // MARK: - Advanced Debug Content

    private var advancedDebugContent: some View {
        VStack(alignment: .leading, spacing: OCDesignSystem.Spacing.medium) {
            Text("Debug Settings")
                .font(.subheadline.bold())

            Toggle("Verbose Logging", isOn: $viewModel.verboseLogging)
                .toggleStyle(SwitchToggleStyle(tint: themeManager.currentTheme.primaryColor))

            Text("Log detailed debug information for troubleshooting.")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.textSecondaryColor)

            Toggle("Show Debug Info", isOn: $viewModel.showDebugInfo)
                .toggleStyle(SwitchToggleStyle(tint: themeManager.currentTheme.primaryColor))

            Text("Display configuration summary and debug information in the UI.")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.textSecondaryColor)
        }
    }

    // MARK: - Export/Import Sheets

    private var exportSettingsSheet: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Settings Export")
                    .font(.headline)

                ScrollView {
                    Text(exportedJSON)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(themeManager.currentTheme.backgroundColor)
                        )
                }

                OCButton(
                    title: "Copy to Clipboard",
                    icon: "doc.on.doc",
                    action: {
                        UIPasteboard.general.string = exportedJSON
                        showExportSheet = false
                    }
                )

                Spacer()
            }
            .padding()
.navigationBarItems(trailing: Button("Done") { showExportSheet = false })
        }
    }

    private var importSettingsSheet: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Import Settings")
                    .font(.headline)

                Text("Paste your settings JSON below:")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textSecondaryColor)

                TextEditor(text: $importText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.currentTheme.backgroundColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.currentTheme.textSecondaryColor.opacity(0.25), lineWidth: 1)
                    )

                HStack(spacing: 12) {
                    OCButton(
                        title: "Paste from Clipboard",
                        icon: "doc.on.clipboard",
                        style: .secondary,
                        action: {
                            if let text = UIPasteboard.general.string {
                                importText = text
                            }
                        }
                    )

                    OCButton(
                        title: "Import",
                        icon: "square.and.arrow.down",
                        action: {
                            if viewModel.importSettings(from: importText) {
                                importText = ""
                                showImportSheet = false
                            }
                        }
                    )
.disabled(importText.isEmpty)
                }

                Spacer()
            }
.padding()
    .navigationBarItems(trailing: Button("Cancel") { showImportSheet = false })
        }
    }

    // Helper function to create consistent section headers
    private func settingSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: OCDesignSystem.Spacing.medium) {
            HStack(spacing: OCDesignSystem.Spacing.small) {
                Image(systemName: systemImage)
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .font(.headline)

                Text(title)
                    .font(.headline)
            }
            .padding(.bottom, 4)

            OCCard(style: .standard) {
                content()
            }
        }
    }

    // API Keys content
    private var apiKeysContent: some View {
        VStack(alignment: .leading, spacing: OCDesignSystem.Spacing.medium) {
            // Use the new SecureSettingsField component
            SecureSettingsField(title: "OpenAI API Key", text: $viewModel.openAIAPIKey)
            SecureSettingsField(title: "Pinecone API Key", text: $viewModel.pineconeAPIKey)
            SecureSettingsField(title: "Pinecone Project ID", text: $viewModel.pineconeProjectId)

            // Pinecone location preferences
            VStack(alignment: .leading, spacing: 8) {
                Text("Pinecone Location")
                    .font(.subheadline.bold())

                HStack {
                    // Cloud picker
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cloud")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                        Picker("Cloud", selection: $viewModel.pineconeCloud) {
                            Text("AWS").tag("aws")
                            Text("GCP").tag("gcp")
                        }
.pickerStyle(SegmentedPickerStyle())
                    }
                    .frame(maxWidth: 150)

                    Spacer()

                    // Region picker with all available regions
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Region")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                        Picker("Region", selection: $viewModel.pineconeRegion) { 
                            ForEach(viewModel.availableRegions, id: \.self) { region in
                                Text(region).tag(region)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: OCDesignSystem.Sizing.cornerRadiusSmall)
                                    .fill(themeManager.currentTheme.backgroundColor)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: OCDesignSystem.Sizing.cornerRadiusSmall)
                                    .stroke(themeManager.currentTheme.textSecondaryColor.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }

            // Live credential status + validate
            VStack(alignment: .leading, spacing: 8) {
                Text("Credential Status")
                    .font(.subheadline.bold())

                HStack(spacing: 8) {
                    statusBadge("OpenAI", viewModel.openAIStatus)
                    statusBadge("Pinecone", viewModel.pineconeStatus)

                    Spacer()

                    Button(action: {
                        viewModel.validateAll()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.shield")
                            Text("Validate")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(themeManager.currentTheme.primaryColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }

            Text("The Pinecone Project ID is required for API access.")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.textSecondaryColor)
        }
    }

    // Helper: status badge
    @ViewBuilder
    private func statusBadge(_ label: String, _ status: CredentialStatus) -> some View {
        let (icon, text, color): (String, String, Color) = {
            switch status {
            case .unknown:
                return ("questionmark.circle", "Unknown", themeManager.currentTheme.textSecondaryColor)
            case .validating:
                return ("hourglass", "Validating…", .orange)
            case .valid:
                return ("checkmark.circle.fill", "Valid", themeManager.currentTheme.successColor)
            case .invalid:
                return ("xmark.octagon.fill", "Invalid", themeManager.currentTheme.errorColor)
            case .rateLimited(let secs):
                return ("clock.fill", "Rate limited (\(secs)s)", .orange)
            }
        }()

        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text("\(label): \(text)")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.textPrimaryColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(themeManager.currentTheme.backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    // Processing settings content
    private var processingSettingsContent: some View {
        VStack(alignment: .leading, spacing: OCDesignSystem.Spacing.medium) {
            // Chunk Size Stepper
            VStack(alignment: .leading, spacing: 4) {
                Text("Chunk Size")
                    .font(.subheadline.bold())
                HStack {
                    // Slider for chunk size with larger step size for easier adjustment
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.defaultChunkSize) },
                            set: { viewModel.defaultChunkSize = Int($0) }
                        ),
                        in: 100...2000,
                        step: 100  // Increased step size for easier use
                    )
                    // Numeric input for direct entry
                    TextField("", value: $viewModel.defaultChunkSize, formatter: NumberFormatter())
                        .frame(width: 60)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            // Chunk Overlap Stepper
            VStack(alignment: .leading, spacing: 4) {
                Text("Chunk Overlap")
                    .font(.subheadline.bold())
                HStack {
                    // Slider for chunk overlap with larger step size for easier adjustment
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.defaultChunkOverlap) },
                            set: { viewModel.defaultChunkOverlap = Int($0) }
                        ),
                        in: 0...500,
                        step: 50  // Increased step size for easier use
                    )
                    // Numeric input for direct entry
                    TextField(
                        "", value: $viewModel.defaultChunkOverlap, formatter: NumberFormatter()
                    )
                    .frame(width: 60)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                }
            }

            Text(
                "Larger chunks preserve more context but can be less specific. Overlap helps maintain context between chunks."
            )
            .font(.caption)
            .foregroundColor(themeManager.currentTheme.textSecondaryColor)
            .padding(.top, 8)
        }
    }

    // Model selection content
    private var modelSelectionContent: some View {
        VStack(alignment: .leading, spacing: OCDesignSystem.Spacing.medium) {
            // Embedding Model Picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Embedding Model")
                    .font(.subheadline.bold())

                Picker(selection: $viewModel.embeddingModel, label: Text(viewModel.embeddingModel))
                {
                    ForEach(viewModel.availableEmbeddingModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: OCDesignSystem.Sizing.cornerRadiusSmall)
                        .fill(themeManager.currentTheme.backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: OCDesignSystem.Sizing.cornerRadiusSmall)
                        .stroke(
                            themeManager.currentTheme.textSecondaryColor.opacity(0.3), lineWidth: 1)
                )
            }

            // Completion Model Picker
            VStack(alignment: .leading, spacing: 4) {
                HStack { 
                    Text("Completion Model")
                        .font(.subheadline.bold())
                    Spacer()
                    Toggle("Custom", isOn: $viewModel.useCustomModel)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: themeManager.currentTheme.primaryColor))
                    Text("Custom")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                }

                if viewModel.useCustomModel {
                    TextField("Enter model name (e.g., gpt-5.2)", text: $viewModel.customCompletionModel)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: viewModel.customCompletionModel) { _, newValue in
                            if !newValue.isEmpty {
                                viewModel.completionModel = newValue
                            }
                        }
                    Text("Enter any OpenAI model name")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                } else { 
                    Picker(
                        selection: $viewModel.completionModel, label: Text(viewModel.completionModel)
                    ) {
                        ForEach(viewModel.availableCompletionModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: OCDesignSystem.Sizing.cornerRadiusSmall)
                            .fill(themeManager.currentTheme.backgroundColor)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: OCDesignSystem.Sizing.cornerRadiusSmall)
                            .stroke(
                                themeManager.currentTheme.textSecondaryColor.opacity(0.3), lineWidth: 1
                            )
                    )
                }
            }

            // Generation Parameters
            if viewModel.isReasoning {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reasoning Effort")
                        .font(.subheadline.bold())
                    Picker("Effort", selection: $viewModel.reasoningEffort) {
                        ForEach(viewModel.availableReasoningEffortOptions, id: \.self) { opt in
                            Text(opt.capitalized).tag(opt)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.top, 4)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Temperature")
                        .font(.subheadline.bold())
                    HStack {
                        Slider(value: $viewModel.temperature, in: 0.0...2.0, step: 0.1)
                        Text(String(format: "%.1f", viewModel.temperature))
                            .font(.caption)
                            .frame(width: 36, alignment: .trailing)
                    }

                    Text("Top P")
                        .font(.subheadline.bold())
                        .padding(.top, 6)
                    HStack {
                        Slider(value: $viewModel.topP, in: 0.0...1.0, step: 0.05)
                        Text(String(format: "%.2f", viewModel.topP))
                            .font(.caption)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
                .padding(.top, 4)
            }

            // Conversation Mode
            VStack(alignment: .leading, spacing: 6) {
                Text("Conversation Mode")
                    .font(.subheadline.bold())

                Picker("Conversation Mode", selection: $viewModel.conversationMode) {
                    Text("Server-managed (OpenAI)").tag("server")
                    Text("Client-bounded (Local)").tag("client")
                }
                .pickerStyle(SegmentedPickerStyle())

                Text(
                    viewModel.conversationMode == "server"
                    ? "Uses OpenAI Responses threads to maintain conversation across turns. Best for coherence; still grounded by RAG context each turn."
                    : "Sends a bounded local history with each request (no server thread). More deterministic prompt shape at the cost of larger tokens."
                )
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.textSecondaryColor)
            }
            .padding(.top, 8)

            Text(
                "The embedding model converts text to vectors. The completion model generates answers. Reasoning models expose Effort; other models use Temperature and Top P."
            )
            .font(.caption)
            .foregroundColor(themeManager.currentTheme.textSecondaryColor)
            .padding(.top, 8)
        }
    }

    private var searchDefaultsContent: some View {
        VStack(alignment: .leading, spacing: OCDesignSystem.Spacing.medium) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Default Result Count")
                    .font(.subheadline.bold())
                Stepper(value: $viewModel.defaultTopK, in: 1...50) {
                    HStack {
                        Text("Top K matches")
                        Spacer()
                        Text("\(viewModel.defaultTopK)")
                            .font(.caption.bold())
                            .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                    }
                }

                Text("Controls how many Pinecone matches the app requests before ranking and summarizing results.")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textSecondaryColor)
            }

            Divider()

            Toggle("Always switch to preferred index", isOn: $viewModel.enforcePreferredIndex)
                .toggleStyle(SwitchToggleStyle(tint: themeManager.currentTheme.primaryColor))

            VStack(alignment: .leading, spacing: 8) {
                textFieldContainer(
                    title: "Preferred Index",
                    placeholder: "index-name",
                    text: $viewModel.preferredIndexName
                )

                textFieldContainer(
                    title: "Preferred Namespace",
                    placeholder: "namespace (optional)",
                    text: $viewModel.preferredNamespace
                )
            }

            Text("If the preferred index or namespace exists, Search will select it automatically when indexes refresh. Leave blank to keep the last selection.")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.textSecondaryColor)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Metadata Filter Presets")
                    .font(.subheadline.bold())

                if viewModel.metadataPresets.isEmpty {
                    Text("Add presets to pre-populate the metadata filter tray each time Search loads.")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(viewModel.metadataPresets.enumerated()), id: \.element.id) { index, preset in
                            metadataPresetRow(index: index, preset: preset)
                        }
                    }
                }

                HStack(spacing: 8) {
                    minimalTextField("Field", text: $viewModel.newPresetField)
                        .onChange(of: viewModel.newPresetField) { _old, _new in
                            viewModel.metadataPresetError = nil
                        }

                    minimalTextField("Value or rule", text: $viewModel.newPresetValue)
                        .onChange(of: viewModel.newPresetValue) { _old, _new in
                            viewModel.metadataPresetError = nil
                        }

                    OCButton(
                        title: "Add",
                        icon: "plus",
                        size: .small,
                        fullWidth: false,
                        action: viewModel.addMetadataPreset
                    )
                    .disabled(
                        viewModel.newPresetField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        viewModel.newPresetValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }

                if let error = viewModel.metadataPresetError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.errorColor)
                }
            }
        }
    }

    private func metadataPresetRow(index: Int, preset: SettingsMetadataPreset) -> some View {
        HStack(spacing: 8) {
            minimalTextField(
                "Field",
                text: Binding(
                    get: { viewModel.metadataPresets[index].field },
                    set: { newValue in
                        viewModel.metadataPresets[index].field = newValue
                        viewModel.metadataPresetError = nil
                    }
                )
            )

            minimalTextField(
                "Value",
                text: Binding(
                    get: { viewModel.metadataPresets[index].rawValue },
                    set: { newValue in
                        viewModel.metadataPresets[index].rawValue = newValue
                        viewModel.metadataPresetError = nil
                    }
                )
            )

            Button {
                viewModel.removeMetadataPreset(preset)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(themeManager.currentTheme.errorColor)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(themeManager.currentTheme.errorColor.opacity(0.12))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Remove metadata preset")
        }
    }

    private func minimalTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: OCDesignSystem.Sizing.cornerRadiusSmall)
                    .fill(themeManager.currentTheme.backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: OCDesignSystem.Sizing.cornerRadiusSmall)
                    .stroke(themeManager.currentTheme.textSecondaryColor.opacity(0.25), lineWidth: 1)
            )
    }

    private func textFieldContainer(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.textSecondaryColor)
            minimalTextField(placeholder, text: text)
        }
    }

    // Appearance content
    private var appearanceContent: some View {
        VStack(alignment: .leading, spacing: OCDesignSystem.Spacing.medium) {
            // Use SettingsNavigationRow for Theme settings
            SettingsNavigationRow(
                title: "Theme",
                subtitle: themeManager.currentTheme.name,
                systemImage: "paintpalette",  // Consistent icon
                destination: ThemeSettingsView(),
                accessory: {
                    // Accessory view to show theme color previews
                    HStack(spacing: 4) {
                        Circle()
                            .fill(themeManager.currentTheme.primaryColor)
                            .frame(width: 16, height: 16)
                        Circle()
                            .fill(themeManager.currentTheme.secondaryColor)
                            .frame(width: 16, height: 16)
                    }
                }
            )

            Divider()

            // Use SettingsNavigationRow for Design System Demo
            SettingsNavigationRow(
                title: "Design System Demo",
                subtitle: nil,  // No subtitle needed
                systemImage: "ruler",  // More relevant icon
                destination: DesignSystemDemoView()
                    // No accessory needed, default EmptyView will be used
            )
        }
    }

    private var loggingContent: some View {
        VStack(alignment: .leading, spacing: OCDesignSystem.Spacing.medium) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Minimum Log Level")
                    .font(.subheadline.bold())

                Picker("Minimum Log Level", selection: $viewModel.logMinimumLevel) {
                    ForEach(viewModel.availableLogLevels, id: \.self) { level in
                        Text(level.rawValue.capitalized)
                            .tag(level)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }

            Text("Messages below this level are discarded before they reach the Logs tab.")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.textSecondaryColor)
        }
    }

    private var dataPrivacyContent: some View {
        VStack(alignment: .leading, spacing: OCDesignSystem.Spacing.medium) {
            Text("OpenCone stores sandbox copies of imported documents and only uploads derived text to the providers you configure. Use the controls below to review the data flow or revoke access.")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.textSecondaryColor)

            if let privacyURL = URL(string: "https://github.com/Gunnarguy/OpenCone/blob/main/PRIVACY.md") {
                Link("Read the detailed Privacy Overview", destination: privacyURL)
                    .font(.subheadline.bold())
            }

            Text("Resetting clears API keys, conversation history, bookmark consent, and index preferences. You'll return to the welcome flow on the next launch.")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.textSecondaryColor)

            OCButton(
                title: "Reset Stored Keys & Preferences",
                icon: "trash",
                style: .destructive,
                action: { showSecureResetDialog = true }
            )

            if let feedback = viewModel.secureResetStatus {
                Text(feedback)
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textSecondaryColor)
            }
        }
    }

    // Actions section
    private var actionsSection: some View {
        HStack(spacing: OCDesignSystem.Spacing.medium) {
            // Save button
            OCButton(
                title: "Save Settings",
                icon: isSaved ? "checkmark" : "square.and.arrow.down",
                action: {
                    if viewModel.isConfigurationValid() {
                        viewModel.saveSettings()
                        withAnimation {
                            isSaved = true
                            animateSaveIcon = true
                        }

                        // Reset saved indicator after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                isSaved = false
                                animateSaveIcon = false
                            }
                        }
                    }
                }
            )
            .scaleEffect(animateSaveIcon ? 1.05 : 1.0)

            // Reset button
            OCButton(
                title: "Reset to Defaults",
                icon: "arrow.counterclockwise",
                style: .destructive,
                action: {
                    isShowingResetAlert = true
                }
            )
        }
    }

    // About content
    private var aboutContent: some View {
        VStack(alignment: .leading, spacing: OCDesignSystem.Spacing.small) {
            HStack {
                Text("OpenCone")
                    .font(.headline)
                Spacer()
                Text("1.0.0")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textSecondaryColor)
            }

            Text(
                "An iOS Retrieval Augmented Generation system for document processing and semantic search."
            )
            .font(.caption)
            .foregroundColor(themeManager.currentTheme.textSecondaryColor)
        }
    }
}

/// Wrapper to make error messages identifiable for alerts
struct IdentifiableError: Identifiable {
    let id = UUID()
    let message: String

    init(_ message: String) {
        self.message = message
    }
}

// MARK: - Supporting Components

/// Reusable settings row with icon, title, subtitle, optional badge, and chevron
struct SettingsRow<Accessory: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    var badge: String?
    var showChevron: Bool = true
    var accessory: (() -> Accessory)?

    @ObservedObject private var themeManager = ThemeManager.shared

    init(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String? = nil,
        badge: String? = nil,
        showChevron: Bool = true,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.showChevron = showChevron
        self.accessory = accessory
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(themeManager.currentTheme.textPrimaryColor)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                }
            }

            Spacer()

            if let accessory = accessory {
                accessory()
            }

            if let badge = badge {
                Text(badge)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(themeManager.currentTheme.primaryColor))
            }

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(themeManager.currentTheme.textSecondaryColor)
            }
        }
        .padding(12)
        .background(themeManager.currentTheme.cardBackgroundColor)
        .cornerRadius(12)
    }
}

extension SettingsRow where Accessory == EmptyView {
    init(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String? = nil,
        badge: String? = nil,
        showChevron: Bool = true
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.showChevron = showChevron
        self.accessory = nil
    }
}

/// Status pill for connection indicators
struct StatusPill: View {
    let label: String
    let status: CredentialStatus
    let theme: OCTheme

    private var statusInfo: (icon: String, color: Color) {
        switch status {
        case .unknown:
            return ("questionmark.circle", theme.textSecondaryColor)
        case .validating:
            return ("hourglass", .orange)
        case .valid:
            return ("checkmark.circle.fill", theme.successColor)
        case .invalid:
            return ("xmark.circle.fill", theme.errorColor)
        case .rateLimited:
            return ("clock.fill", .orange)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: statusInfo.icon)
                .font(.caption)
                .foregroundColor(statusInfo.color)
            Text(label)
                .font(.caption)
                .foregroundColor(theme.textPrimaryColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(statusInfo.color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(statusInfo.color.opacity(0.3), lineWidth: 1)
        )
    }
}

/// Toggle row for AI tools
struct ToolToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    let theme: OCTheme

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(theme.primaryColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(theme.primaryColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(theme.textPrimaryColor)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(theme.textSecondaryColor)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: theme.primaryColor))
        }
        .padding(12)
        .background(theme.cardBackgroundColor)
    }
}

/// Action row for data/privacy section
struct SettingsActionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var isDestructive: Bool = false
    var showExternalLink: Bool = false
    let theme: OCTheme

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }

            Text(title)
                .font(.subheadline)
                .foregroundColor(isDestructive ? theme.errorColor : theme.textPrimaryColor)

            Spacer()

            if showExternalLink {
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(theme.textSecondaryColor)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(theme.textSecondaryColor)
            }
        }
        .padding(12)
        .background(theme.cardBackgroundColor)
    }
}

// MARK: - Detail Views

/// AI Models settings detail view
struct AISettingsDetailView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var themeManager = ThemeManager.shared

    private var theme: OCTheme { themeManager.currentTheme }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Embedding Model
                VStack(alignment: .leading, spacing: 12) {
                    Label("Embedding Model", systemImage: "square.stack.3d.up")
                        .font(.headline)
                        .foregroundColor(theme.textPrimaryColor)

                    Picker("Embedding Model", selection: $viewModel.embeddingModel) {
                        ForEach(viewModel.availableEmbeddingModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(theme.cardBackgroundColor))

                    Text("Converts text to vectors for semantic search")
                        .font(.caption)
                        .foregroundColor(theme.textSecondaryColor)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackgroundColor))

                // Completion Model
                VStack(alignment: .leading, spacing: 12) {
                    Label("Completion Model", systemImage: "brain")
                        .font(.headline)
                        .foregroundColor(theme.textPrimaryColor)

                    Toggle("Use Custom Model", isOn: $viewModel.useCustomModel)
                        .toggleStyle(SwitchToggleStyle(tint: theme.primaryColor))

                    if viewModel.useCustomModel {
                        TextField("Model name (e.g., gpt-5)", text: $viewModel.customCompletionModel)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .onChange(of: viewModel.customCompletionModel) { _, newValue in
                                if !newValue.isEmpty { viewModel.completionModel = newValue }
                            }
                    } else {
                        Picker("Completion Model", selection: $viewModel.completionModel) {
                            ForEach(viewModel.availableCompletionModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(theme.backgroundColor))
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackgroundColor))

                // Generation Parameters
                VStack(alignment: .leading, spacing: 12) {
                    Label("Generation Parameters", systemImage: "slider.horizontal.3")
                        .font(.headline)
                        .foregroundColor(theme.textPrimaryColor)

                    if viewModel.isReasoning {
                        Text("Reasoning Effort")
                            .font(.subheadline)
                            .foregroundColor(theme.textSecondaryColor)
                        Picker("Effort", selection: $viewModel.reasoningEffort) {
                            ForEach(viewModel.availableReasoningEffortOptions, id: \.self) { opt in
                                Text(opt.capitalized).tag(opt)
                            }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Temperature")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.1f", viewModel.temperature))
                                    .font(.caption.bold())
                                    .foregroundColor(theme.textSecondaryColor)
                            }
                            Slider(value: $viewModel.temperature, in: 0 ... 2, step: 0.1)
                                .tint(theme.primaryColor)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Top P")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.2f", viewModel.topP))
                                    .font(.caption.bold())
                                    .foregroundColor(theme.textSecondaryColor)
                            }
                            Slider(value: $viewModel.topP, in: 0 ... 1, step: 0.05)
                                .tint(theme.primaryColor)
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackgroundColor))

                // Conversation Mode
                VStack(alignment: .leading, spacing: 12) {
                    Label("Conversation Mode", systemImage: "bubble.left.and.bubble.right")
                        .font(.headline)
                        .foregroundColor(theme.textPrimaryColor)

                    Picker("Mode", selection: $viewModel.conversationMode) {
                        Text("Server-managed").tag("server")
                        Text("Client-bounded").tag("client")
                    }
                    .pickerStyle(.segmented)

                    Text(viewModel.conversationMode == "server"
                        ? "OpenAI maintains conversation threads"
                        : "Local bounded history with each request")
                        .font(.caption)
                        .foregroundColor(theme.textSecondaryColor)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackgroundColor))
            }
            .padding(16)
        }
        .background(theme.backgroundColor.ignoresSafeArea())
        .navigationTitle("AI Models")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// API Keys & Connections detail view
struct ConnectionsDetailView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var themeManager = ThemeManager.shared

    private var theme: OCTheme { themeManager.currentTheme }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // OpenAI
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("OpenAI", systemImage: "brain.head.profile")
                            .font(.headline)
                        Spacer()
                        statusBadge(viewModel.openAIStatus)
                    }

                    SecureField("API Key", text: $viewModel.openAIAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackgroundColor))

                // Pinecone
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Pinecone", systemImage: "server.rack")
                            .font(.headline)
                        Spacer()
                        statusBadge(viewModel.pineconeStatus)
                    }

                    SecureField("API Key", text: $viewModel.pineconeAPIKey)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)

                    TextField("Project ID", text: $viewModel.pineconeProjectId)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cloud")
                                .font(.caption)
                                .foregroundColor(theme.textSecondaryColor)
                            Picker("Cloud", selection: $viewModel.pineconeCloud) {
                                Text("AWS").tag("aws")
                                Text("GCP").tag("gcp")
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Region")
                                .font(.caption)
                                .foregroundColor(theme.textSecondaryColor)
                            Picker("Region", selection: $viewModel.pineconeRegion) {
                                ForEach(viewModel.availableRegions, id: \.self) { region in
                                    Text(region).tag(region)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackgroundColor))

                // Validate Button
                Button {
                    viewModel.validateAll()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.shield")
                        Text("Validate Connections")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(theme.primaryColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .padding(16)
        }
        .background(theme.backgroundColor.ignoresSafeArea())
        .navigationTitle("API Keys & Connections")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func statusBadge(_ status: CredentialStatus) -> some View {
        let (icon, color): (String, Color) = {
            switch status {
            case .unknown: return ("questionmark.circle", theme.textSecondaryColor)
            case .validating: return ("hourglass", .orange)
            case .valid: return ("checkmark.circle.fill", theme.successColor)
            case .invalid: return ("xmark.circle.fill", theme.errorColor)
            case .rateLimited: return ("clock.fill", .orange)
            }
        }()

        Image(systemName: icon)
            .foregroundColor(color)
    }
}

/// Search settings detail view
struct SearchSettingsDetailView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var themeManager = ThemeManager.shared

    private var theme: OCTheme { themeManager.currentTheme }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Top K
                VStack(alignment: .leading, spacing: 12) {
                    Label("Result Count", systemImage: "list.number")
                        .font(.headline)

                    HStack {
                        Text("Top K")
                        Spacer()
                        Text("\(viewModel.defaultTopK)")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(theme.primaryColor.opacity(0.2)))
                    }
                    Stepper("", value: $viewModel.defaultTopK, in: 1 ... 50)
                        .labelsHidden()

                    Text("Number of Pinecone matches to retrieve")
                        .font(.caption)
                        .foregroundColor(theme.textSecondaryColor)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackgroundColor))

                // Similarity Threshold
                VStack(alignment: .leading, spacing: 12) {
                    Label("Similarity Threshold", systemImage: "slider.horizontal.below.rectangle")
                        .font(.headline)

                    HStack {
                        Slider(value: $viewModel.similarityThreshold, in: 0 ... 1, step: 0.05)
                            .tint(theme.primaryColor)
                        Text(String(format: "%.2f", viewModel.similarityThreshold))
                            .font(.caption.bold())
                            .frame(width: 40)
                    }

                    Text(viewModel.similarityThreshold == 0
                        ? "No threshold - return all results"
                        : "Only results with score ≥ \(String(format: "%.2f", viewModel.similarityThreshold))")
                        .font(.caption)
                        .foregroundColor(theme.textSecondaryColor)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackgroundColor))

                // Preferred Index
                VStack(alignment: .leading, spacing: 12) {
                    Label("Preferred Index", systemImage: "star")
                        .font(.headline)

                    Toggle("Auto-switch to preferred", isOn: $viewModel.enforcePreferredIndex)
                        .toggleStyle(SwitchToggleStyle(tint: theme.primaryColor))

                    TextField("Index name", text: $viewModel.preferredIndexName)
                        .textFieldStyle(.roundedBorder)

                    TextField("Namespace (optional)", text: $viewModel.preferredNamespace)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackgroundColor))

                // UI Options
                VStack(alignment: .leading, spacing: 12) {
                    Label("Display Options", systemImage: "rectangle.3.group")
                        .font(.headline)

                    Toggle("Show Answer Panel Below Chat", isOn: $viewModel.showAnswerPanelBelowChat)
                        .toggleStyle(SwitchToggleStyle(tint: theme.primaryColor))

                    Toggle("Enable Streaming", isOn: $viewModel.streamingEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: theme.primaryColor))

                    Toggle("Include Metadata in Results", isOn: $viewModel.includeMetadataInResults)
                        .toggleStyle(SwitchToggleStyle(tint: theme.primaryColor))
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackgroundColor))
            }
            .padding(16)
        }
        .background(theme.backgroundColor.ignoresSafeArea())
        .navigationTitle("Search & Retrieval")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Document processing settings detail view
struct ProcessingSettingsDetailView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var themeManager = ThemeManager.shared

    private var theme: OCTheme { themeManager.currentTheme }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Chunk Size
                VStack(alignment: .leading, spacing: 12) {
                    Label("Chunk Size", systemImage: "rectangle.split.3x1")
                        .font(.headline)

                    HStack {
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.defaultChunkSize) },
                                set: { viewModel.defaultChunkSize = Int($0) }
                            ),
                            in: 100 ... 2000,
                            step: 100
                        )
                        .tint(theme.primaryColor)

                        Text("\(viewModel.defaultChunkSize)")
                            .font(.caption.bold())
                            .frame(width: 50)
                    }

                    Text("Characters per chunk")
                        .font(.caption)
                        .foregroundColor(theme.textSecondaryColor)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackgroundColor))

                // Chunk Overlap
                VStack(alignment: .leading, spacing: 12) {
                    Label("Chunk Overlap", systemImage: "square.on.square")
                        .font(.headline)

                    HStack {
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.defaultChunkOverlap) },
                                set: { viewModel.defaultChunkOverlap = Int($0) }
                            ),
                            in: 0 ... 500,
                            step: 50
                        )
                        .tint(theme.primaryColor)

                        Text("\(viewModel.defaultChunkOverlap)")
                            .font(.caption.bold())
                            .frame(width: 50)
                    }

                    Text("Overlap maintains context between chunks")
                        .font(.caption)
                        .foregroundColor(theme.textSecondaryColor)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackgroundColor))

                // Embedding Settings
                VStack(alignment: .leading, spacing: 12) {
                    Label("Embedding", systemImage: "cpu")
                        .font(.headline)

                    HStack {
                        Text("Batch Size")
                        Spacer()
                        Text("\(viewModel.embeddingBatchSize)")
                            .font(.caption.bold())
                    }
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.embeddingBatchSize) },
                            set: { viewModel.embeddingBatchSize = Int($0) }
                        ),
                        in: 10 ... 100,
                        step: 10
                    )
                    .tint(theme.primaryColor)

                    Picker("Dimension", selection: $viewModel.embeddingDimension) {
                        Text("1536").tag(1536)
                        Text("3072").tag(3072)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackgroundColor))
            }
            .padding(16)
        }
        .background(theme.backgroundColor.ignoresSafeArea())
        .navigationTitle("Document Processing")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Appearance settings view
struct AppearanceSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var themeManager = ThemeManager.shared

    private var theme: OCTheme { themeManager.currentTheme }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                themeSelectionSection
            }
            .padding(16)
        }
        .background(theme.backgroundColor.ignoresSafeArea())
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var themeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Theme", systemImage: "paintpalette")
                .font(.headline)

            ForEach(OCTheme.allThemes, id: \.id) { availableTheme in
                themeButton(for: availableTheme)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackgroundColor))
    }

    private func themeButton(for availableTheme: OCTheme) -> some View {
        Button {
            themeManager.setTheme(availableTheme)
        } label: {
            themeButtonLabel(for: availableTheme)
        }
    }

    private func themeButtonLabel(for availableTheme: OCTheme) -> some View {
        HStack {
            Circle().fill(availableTheme.primaryColor).frame(width: 24, height: 24)
            Circle().fill(availableTheme.secondaryColor).frame(width: 24, height: 24)

            Text(availableTheme.name)
                .foregroundColor(theme.textPrimaryColor)

            Spacer()

            if availableTheme.name == theme.name {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(theme.primaryColor)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(theme.cardBackgroundColor))
    }
}

/// Advanced settings view
struct AdvancedSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var themeManager = ThemeManager.shared

    private var theme: OCTheme { themeManager.currentTheme }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Network
                VStack(alignment: .leading, spacing: 12) {
                    Label("Network", systemImage: "network")
                        .font(.headline)

                    HStack {
                        Text("Timeout")
                        Spacer()
                        Text("\(viewModel.requestTimeoutSeconds)s")
                            .font(.caption.bold())
                    }
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.requestTimeoutSeconds) },
                            set: { viewModel.requestTimeoutSeconds = Int($0) }
                        ),
                        in: 10 ... 120,
                        step: 5
                    )
                    .tint(theme.primaryColor)

                    Stepper("Max Retries: \(viewModel.maxRetries)", value: $viewModel.maxRetries, in: 0 ... 10)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackgroundColor))

                // Context
                VStack(alignment: .leading, spacing: 12) {
                    Label("Context Window", systemImage: "text.alignleft")
                        .font(.headline)

                    HStack {
                        Text("Max Tokens")
                        Spacer()
                        Text("\(viewModel.maxContextTokens)")
                            .font(.caption.bold())
                    }
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.maxContextTokens) },
                            set: { viewModel.maxContextTokens = Int($0) }
                        ),
                        in: 1000 ... 32000,
                        step: 1000
                    )
                    .tint(theme.primaryColor)

                    Stepper("Conversation Turns: \(viewModel.maxConversationTurns)", value: $viewModel.maxConversationTurns, in: 1 ... 50)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackgroundColor))

                // System Prompt
                VStack(alignment: .leading, spacing: 12) {
                    Label("System Prompt Override", systemImage: "text.bubble")
                        .font(.headline)

                    TextEditor(text: $viewModel.systemPromptOverride)
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(theme.backgroundColor))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme.textSecondaryColor.opacity(0.3)))

                    Text("Leave empty for default RAG prompt")
                        .font(.caption)
                        .foregroundColor(theme.textSecondaryColor)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackgroundColor))

                // Debug
                VStack(alignment: .leading, spacing: 12) {
                    Label("Debugging", systemImage: "ladybug")
                        .font(.headline)

                    Toggle("Verbose Logging", isOn: $viewModel.verboseLogging)
                        .toggleStyle(SwitchToggleStyle(tint: theme.primaryColor))

                    Toggle("Show Debug Info", isOn: $viewModel.showDebugInfo)
                        .toggleStyle(SwitchToggleStyle(tint: theme.primaryColor))
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackgroundColor))

                // Pinecone API Versions
                VStack(alignment: .leading, spacing: 12) {
                    Label("Pinecone API Versions", systemImage: "number")
                        .font(.headline)
                        .foregroundColor(.orange)

                    TextField("Control Plane", text: $viewModel.pineconeControlPlaneVersion)
                        .textFieldStyle(.roundedBorder)
                    TextField("Data Plane", text: $viewModel.pineconeDataPlaneVersion)
                        .textFieldStyle(.roundedBorder)
                    TextField("Namespace (Preview)", text: $viewModel.pineconeNamespaceVersion)
                        .textFieldStyle(.roundedBorder)
                    TextField("Metadata Fetch (Preview)", text: $viewModel.pineconeMetadataFetchVersion)
                        .textFieldStyle(.roundedBorder)

                    Text("⚠️ Only change if you know what you're doing")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(theme.cardBackgroundColor))
            }
            .padding(16)
        }
        .background(theme.backgroundColor.ignoresSafeArea())
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
    }
}
