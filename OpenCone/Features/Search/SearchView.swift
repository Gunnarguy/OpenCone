import SwiftUI
import UIKit

// MARK: - Main Search View

/// The primary view for the search feature, orchestrating the display of configuration,
/// search bar, loading state, results, or initial prompt.
struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel  // The view model managing search state and logic
    @Environment(\.theme) private var theme  // Access the current theme
    var onRequestDocumentsTab: (() -> Void)? // Callback to jump to the Documents tab
    @State private var showMetadataSheet = false
    @State private var showSourcesSheet = false
    @State private var showExportSheet = false
    @StateObject private var speechService = SpeechRecognitionService()

    var body: some View {
        Group {
            if viewModel.pineconeIndexes.isEmpty {
                ScrollView {
                    NoIndexEmptyState(onShowDocuments: onRequestDocumentsTab ?? {})
                        .padding(.horizontal, 16)
                        .padding(.vertical, 24)
                }
            } else {
                VStack(spacing: 0) {
                    // Compact context selector
                    CompactContextSelector(viewModel: viewModel)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    // Chat timeline takes all available space
                    ChatTimelineView(viewModel: viewModel)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Sleek input bar
                    VStack(spacing: 0) {
                        Divider()
                            .background(theme.textSecondaryColor.opacity(0.1))

                        HStack(spacing: 8) {
                            // Left accessories
                            HStack(spacing: 4) {
                                // Quick Settings Menu
                                QuickSettingsMenu(settings: viewModel.settingsViewModel)

                                // Filters
                                if !viewModel.metadataFilters.isEmpty || viewModel.messages.isEmpty { 
                                    Button { showMetadataSheet = true } label: {
                                        Image(systemName: viewModel.metadataFilters.isEmpty ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(viewModel.metadataFilters.isEmpty ? theme.textSecondaryColor : theme.primaryColor)
.frame(width: 28, height: 28)
                                    }
.buttonStyle(.plain)
                                }

                                // Sources
                                if !viewModel.searchResults.isEmpty {
                                    Button { showSourcesSheet = true } label: {
                                        ZStack(alignment: .topTrailing) {
                                            Image(systemName: "doc.text")
                                                .font(.system(size: 16))
                                                .foregroundColor(theme.textSecondaryColor)
                                                .frame(width: 28, height: 28)

                                            Text("\(viewModel.searchResults.count)")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(.white)
                                                .frame(width: 14, height: 14)
                                                .background(Circle().fill(theme.primaryColor))
                                                .offset(x: 4, y: -2)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            // Main input
                            ChatInputBar(
                                text: Binding(
                                    get: { viewModel.searchQuery },
                                    set: { viewModel.searchQuery = $0 }
                                ),
                                isSending: viewModel.isSearching,
                                onSend: { Task { await viewModel.performSearch() } },
                                onStop: { viewModel.cancelActiveSearch() },
                                speechService: speechService
                            )
                            .disabled(viewModel.selectedIndex == nil)

                            // Export conversation
                            if viewModel.messages.count > 1 { 
                                Button { showExportSheet = true } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 16))
                                        .foregroundColor(theme.textSecondaryColor)
                                        .frame(width: 28, height: 28)
                                }
                                .buttonStyle(.plain)
                            }

                            // New topic
                            if viewModel.messages.count > 1 {
                                Button { viewModel.newTopic() } label: {
                                    Image(systemName: "plus.bubble")
                                        .font(.system(size: 16))
                                        .foregroundColor(theme.primaryColor)
.frame(width: 28, height: 28)
                                }
.buttonStyle(.plain)
    .disabled(viewModel.isSearching)
                            }
                        }
.padding(.horizontal, 12)
    .padding(.vertical, 8)
                    }
                    .background(theme.cardBackgroundColor)
                }
            }
        }
        .background(theme.backgroundColor.ignoresSafeArea())
        .sheet(isPresented: $showMetadataSheet) {
            MetadataFilterSheet(viewModel: viewModel)
        }
.sheet(isPresented: $showSourcesSheet) {
    SourcesSheet(viewModel: viewModel)
}
.sheet(isPresented: $showExportSheet) {
    ExportConversationSheet(viewModel: viewModel)
}
        .overlay(alignment: .top) {
            if let error = viewModel.errorMessage, !error.isEmpty {
                ErrorBanner(message: error)
                    .padding(.top, 8)
            }
        }
.overlay(alignment: .bottom) {
    ListeningOverlay(speechService: speechService)
        .padding(.bottom, 80)
        .animation(.spring(response: 0.3), value: speechService.isListening)
}
// Keyboard shortcuts for Mac Catalyst
.keyboardShortcut(.return, modifiers: [.command]) // Cmd+Enter to send
.onKeyPress(.escape) {
    if viewModel.isSearching {
        viewModel.cancelActiveSearch()
        return .handled
    }
    return .ignored
}
    }
}

// MARK: - Compact Context Selector (single line)

struct CompactContextSelector: View { 
    @ObservedObject var viewModel: SearchViewModel
    @Environment(\.theme) private var theme

    private var displayIndex: String {
        viewModel.selectedIndex ?? "..."
    }

    private var displayNamespace: String {
        let ns = viewModel.selectedNamespace ?? ""
        return ns.isEmpty ? "All" : ns
    }

    var body: some View {
        HStack(spacing: 6) {
            // Index menu
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
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "cylinder.fill")
                        .font(.system(size: 9))
                    Text(displayIndex)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
.background(Capsule().fill(theme.primaryLight))
    .foregroundColor(theme.primaryColor)
            }
.disabled(viewModel.isSearching)

            // Namespace menu
            if viewModel.selectedIndex != nil {
                Menu {
                    Button {
                        viewModel.setNamespace(nil)
                    } label: {
                        HStack {
                            Text("All")
                            if viewModel.selectedNamespace == nil || viewModel.selectedNamespace?.isEmpty == true {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    ForEach(viewModel.namespaces.filter { !$0.isEmpty }, id: \.self) { ns in
                        Button {
                            viewModel.setNamespace(ns)
                        } label: {
                            HStack {
                                Text(ns)
                                if viewModel.selectedNamespace == ns {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(displayNamespace)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(Capsule().fill(theme.cardBackgroundColor))
                    .foregroundColor(theme.textSecondaryColor)
                }
                .disabled(viewModel.isSearching)
            }

            Spacer()

            // Filter count (tiny)
            if !viewModel.metadataFilters.isEmpty {
                Text("\(viewModel.metadataFilters.count)")
                    .font(.system(size: 10, weight: .bold))
                    .padding(4)
                    .background(Circle().fill(theme.primaryColor))
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            if viewModel.selectedIndex == nil, let first = viewModel.pineconeIndexes.first {
                Task { await viewModel.setIndex(first) }
            }
        }
    }
}

// MARK: - Quick Settings Menu

/// Compact settings button that opens a popover with sliders and toggles
struct QuickSettingsMenu: View {
    @ObservedObject var settings: SettingsViewModel
    @Environment(\.theme) private var theme
    @State private var showSettings = false

    private var modelShortName: String {
        settings.completionModel
            .replacingOccurrences(of: "gpt-", with: "")
            .replacingOccurrences(of: "-2025-04-14", with: "")
    }

    private var isReasoningModel: Bool {
        Configuration.isReasoningModel(settings.completionModel)
    }

    private var activeToolCount: Int {
        var count = 0
        if settings.webSearchEnabled { count += 1 }
        if settings.codeInterpreterEnabled { count += 1 }
        return count
    }

    private var hasActiveTools: Bool {
        activeToolCount > 0
    }

    private var toolIcon: String {
        if settings.codeInterpreterEnabled { return "chart.bar.doc.horizontal" }
        if settings.webSearchEnabled { return "globe" }
        return "gearshape"
    }

    var body: some View {
        Button {
            showSettings = true
        } label: {
            HStack(spacing: 4) { 
                Image(systemName: toolIcon)
                    .font(.system(size: 12))
                    .foregroundColor(hasActiveTools ? theme.primaryColor : theme.textSecondaryColor)
                Text(modelShortName)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                if activeToolCount > 0 {
                    Text("•\(activeToolCount)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(theme.primaryColor))
                }
            }
            .foregroundColor(theme.textSecondaryColor)
.padding(.vertical, 4)
.padding(.horizontal, 6)
    .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.cardBackgroundColor)
                )
        }
.buttonStyle(.plain)
    .popover(isPresented: $showSettings, arrowEdge: .bottom) {
        QuickSettingsPopover(settings: settings)
            }
    }
}

/// The actual settings popover content with sliders, pickers, and toggles
struct QuickSettingsPopover: View {
    @ObservedObject var settings: SettingsViewModel
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var showAdvanced = false

    private var isReasoningModel: Bool {
        Configuration.isReasoningModel(settings.completionModel)
    }

    /// Formats token counts with K suffix for readability
    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 {
            let k = Double(count) / 1000.0
            if k == Double(Int(k)) {
                return "\(Int(k))K"
            } else {
                return String(format: "%.1fK", k)
            }
        }
        return "\(count)"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Model Picker
                    SettingsSection(title: "Model", icon: "cpu") {
                        Menu {
                            ForEach(settings.availableCompletionModels, id: \.self) { model in
                                Button {
                                    settings.completionModel = model
                                } label: {
                                    HStack {
                                        Text(model)
                                        if settings.completionModel == model {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(settings.completionModel)
                                    .foregroundColor(theme.textPrimaryColor)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondaryColor)
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(theme.cardBackgroundColor))
                        }
                    }

                    // Temperature OR Reasoning (contextual)
                    if isReasoningModel {
                        SettingsSection(title: "Reasoning Effort", icon: "brain", value: settings.reasoningEffort.uppercased()) {
                            Picker("", selection: $settings.reasoningEffort) {
                                Text("Off").tag("none")
                                Text("Low").tag("low")
                                Text("Med").tag("medium")
                                Text("High").tag("high")
                                Text("Max").tag("xhigh")
                            }
                            .pickerStyle(.segmented)
                        }
                    } else {
                        SettingsSection(title: "Temperature", icon: "thermometer.medium", value: String(format: "%.1f", settings.temperature)) {
                            VStack(spacing: 4) {
                                Slider(value: $settings.temperature, in: 0 ... 2, step: 0.1)
                                    .tint(theme.primaryColor)
                                HStack {
                                    Text("Precise").font(.caption2).foregroundColor(theme.textSecondaryColor)
                                    Spacer()
                                    Text("Creative").font(.caption2).foregroundColor(theme.textSecondaryColor)
                                }
                            }
                        }

                        SettingsSection(title: "Top-P", icon: "dial.low", value: String(format: "%.2f", settings.topP)) {
                            VStack(spacing: 4) {
                                Slider(value: $settings.topP, in: 0 ... 1, step: 0.05)
                                    .tint(theme.primaryColor)
                                HStack {
                                    Text("Focused").font(.caption2).foregroundColor(theme.textSecondaryColor)
                                    Spacer()
                                    Text("Diverse").font(.caption2).foregroundColor(theme.textSecondaryColor)
                                }
                            }
                        }
                    }

                    // Search Results
                    SettingsSection(title: "Search Results", icon: "list.number", value: "Top \(settings.defaultTopK)") {
                        Slider(value: Binding(
                            get: { Double(settings.defaultTopK) },
                            set: { settings.defaultTopK = Int($0) }
                        ), in: 1 ... 30, step: 1)
                            .tint(theme.primaryColor)
                    }

                    // Response Length
                    SettingsSection(title: "Response Length", icon: "text.alignleft", value: formatTokens(settings.maxOutputTokens)) {
                        Slider(value: Binding(
                            get: { Double(settings.maxOutputTokens) },
                            set: { settings.maxOutputTokens = Int($0) }
                        ), in: 500 ... 32000, step: 500)
                            .tint(theme.primaryColor)
                    }

                    // Tools & Features
                    SettingsSection(title: "AI Tools", icon: "sparkles") {
                        VStack(spacing: 12) {
                            Toggle(isOn: $settings.webSearchEnabled) {
                                HStack(spacing: 8) {
                                    Image(systemName: "globe")
                                        .foregroundColor(settings.webSearchEnabled ? theme.primaryColor : theme.textSecondaryColor)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Web Search")
                                            .font(.subheadline)
                                        Text("Search the web for current info")
                                            .font(.caption2)
                                            .foregroundColor(theme.textSecondaryColor)
                                    }
                                }
                            }
                            .tint(theme.primaryColor)

                            Toggle(isOn: $settings.codeInterpreterEnabled) {
                                HStack(spacing: 8) {
                                    Image(systemName: "chart.bar.doc.horizontal")
                                        .foregroundColor(settings.codeInterpreterEnabled ? theme.primaryColor : theme.textSecondaryColor)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Charts & Calculations")
                                            .font(.subheadline)
                                        Text("Visualize data, compute totals, export tables")
                                            .font(.caption2)
                                            .foregroundColor(theme.textSecondaryColor)
                                    }
                                }
                            }
                            .tint(theme.primaryColor)

                            Toggle(isOn: $settings.streamingEnabled) {
                                HStack(spacing: 8) {
                                    Image(systemName: "text.bubble")
                                        .foregroundColor(theme.textSecondaryColor)
                                    Text("Stream Response")
                                        .font(.subheadline)
                                }
                            }
                            .tint(theme.primaryColor)
                        }
                    }

                    // Advanced Section
                    DisclosureGroup(isExpanded: $showAdvanced) {
                        VStack(spacing: 16) {
                            // Conversation Mode
                            SettingsSection(title: "Conversation", icon: "bubble.left.and.bubble.right") {
                                Picker("", selection: $settings.conversationMode) {
                                    Text("Server").tag("server")
                                    Text("Local").tag("client")
                                }
                                .pickerStyle(.segmented)

                                if settings.conversationMode == "client" {
                                    HStack {
                                        Text("Max Turns")
                                            .font(.caption)
                                            .foregroundColor(theme.textSecondaryColor)
                                        Spacer()
                                        Stepper("\(settings.maxConversationTurns)", value: $settings.maxConversationTurns, in: 2 ... 20)
                                            .font(.caption)
                                    }
.padding(.top, 4)
                                }
                            }

                            // Similarity Threshold
                            SettingsSection(title: "Min Score", icon: "chart.bar", value: settings.similarityThreshold > 0 ? String(format: "%.0f%%", settings.similarityThreshold * 100) : "Off") {
                                VStack(spacing: 4) {
                                    Slider(value: $settings.similarityThreshold, in: 0 ... 0.9, step: 0.05)
                                        .tint(theme.primaryColor)
                                    HStack {
                                        Text("All").font(.caption2).foregroundColor(theme.textSecondaryColor)
                                        Spacer()
                                        Text("Strict").font(.caption2).foregroundColor(theme.textSecondaryColor)
                                    }
                                }
                            }

                            // Context Window
                            SettingsSection(title: "Context Window", icon: "doc.text", value: formatTokens(settings.maxContextTokens)) {
                                Slider(value: Binding(
                                    get: { Double(settings.maxContextTokens) },
                                    set: { settings.maxContextTokens = Int($0) }
                                ), in: 4000 ... 128_000, step: 4000)
                                    .tint(theme.primaryColor)
                            }

                            // System Prompt
                            SettingsSection(title: "Custom Instructions", icon: "text.quote") {
                                TextField("Add custom behavior...", text: $settings.systemPromptOverride, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .font(.caption)
                                    .lineLimit(3 ... 6)
                                    .padding(8)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackgroundColor))
                            }

                            // Debug toggles
                            Toggle(isOn: $settings.verboseLogging) {
                                HStack(spacing: 8) {
                                    Image(systemName: "ant")
                                        .foregroundColor(theme.textSecondaryColor)
                                    Text("Verbose Logging")
                                        .font(.caption)
                                }
                            }
                            .tint(theme.primaryColor)
                        }
                        .padding(.top, 12)
                    } label: {
                        HStack {
                            Image(systemName: "gearshape.2")
                                .foregroundColor(theme.textSecondaryColor)
                            Text("Advanced")
                                .font(.subheadline.bold())
                                .foregroundColor(theme.textSecondaryColor)
                            Spacer()
                            if !settings.systemPromptOverride.isEmpty {
                                Image(systemName: "text.badge.checkmark")
                                    .font(.caption)
                                    .foregroundColor(theme.primaryColor)
                            }
                        }
                    }
                    .tint(theme.textSecondaryColor)

                    // Quick Presets
                    SettingsSection(title: "Presets", icon: "sparkle.magnifyingglass") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                PresetButton(title: "Precise", icon: "scope") {
                                    settings.temperature = 0.1
                                    settings.topP = 0.9
                                    settings.defaultTopK = 5
                                }
                                PresetButton(title: "Balanced", icon: "equal.circle") {
                                    settings.temperature = 0.5
                                    settings.topP = 0.95
                                    settings.defaultTopK = 10
                                }
                                PresetButton(title: "Creative", icon: "paintbrush") {
                                    settings.temperature = 1.0
                                    settings.topP = 1.0
                                    settings.defaultTopK = 15
                                }
                                PresetButton(title: "Research", icon: "books.vertical") {
                                    settings.temperature = 0.3
                                    settings.topP = 0.9
                                    settings.defaultTopK = 20
                                    settings.maxOutputTokens = 2000
                                }
                            }
                        }
                    }

                    // Appearance
                    SettingsSection(title: "Appearance", icon: "paintpalette") {
                        HStack(spacing: 12) {
                            ForEach(OCTheme.allThemes.prefix(4), id: \.id) { themeOption in
                                Button {
                                    ThemeManager.shared.setTheme(themeOption)
                                } label: {
                                    VStack(spacing: 4) {
                                        Circle()
                                            .fill(themeOption.primaryColor)
                                            .frame(width: 28, height: 28)
                                            .overlay(
                                                Circle()
                                                    .stroke(ThemeManager.shared.currentTheme.id == themeOption.id ? theme.primaryColor : Color.clear, lineWidth: 2)
                                                    .padding(-2)
                                            )
                                        Text(themeOption.name)
                                            .font(.caption2)
                                            .foregroundColor(theme.textSecondaryColor)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(theme.backgroundColor)
                .navigationTitle("Quick Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .fontWeight(.semibold)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            resetToDefaults()
                        } label: {
                            Text("Reset")
                                .font(.subheadline)
                        }
                    }
                }
        }
        .frame(minWidth: 320, idealWidth: 360, minHeight: 520, idealHeight: 650)
            .presentationCompactAdaptation(.popover)
    }

    private func resetToDefaults() {
        settings.temperature = 0.3
        settings.topP = 0.95
        settings.defaultTopK = 10
        settings.maxOutputTokens = 4000
        settings.webSearchEnabled = false
        settings.codeInterpreterEnabled = false
        settings.streamingEnabled = true
        settings.maxContextTokens = 32000
        settings.systemPromptOverride = ""
        settings.similarityThreshold = 0.0
    }
}

/// Quick preset button
private struct PresetButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.caption2)
            }
.foregroundColor(theme.primaryColor)
    .frame(width: 70, height: 50)
    .background(RoundedRectangle(cornerRadius: 10).fill(theme.primaryLight))
        }
.buttonStyle(.plain)
    }
}

/// Reusable settings section component
private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    var value: String? = nil
    @ViewBuilder let content: Content
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.subheadline.bold())
                    .foregroundColor(theme.textSecondaryColor)
                Spacer()
                if let value {
                    Text(value)
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(theme.primaryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(theme.primaryLight))
                }
            }
            content
        }
    }
}

// MARK: - Sources Sheet

struct SourcesSheet: View {
    @ObservedObject var viewModel: SearchViewModel
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    private func isResultSelected(_ result: SearchResultModel) -> Bool {
        viewModel.selectedResults.contains { $0.id == result.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.searchResults) { result in
                        SearchResultRow(
                            result: result,
                            isSelected: isResultSelected(result),
                            viewModel: viewModel
                        ) {
                            viewModel.toggleResultSelection(result)
                        }
                    }
                }
                .padding(16)
            }
            .background(theme.backgroundColor)
.navigationTitle("Sources (\(viewModel.searchResults.count))")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done") { dismiss() }
                .fontWeight(.semibold)
        }
        if !viewModel.selectedResults.isEmpty {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await viewModel.generateAnswerFromSelected() }
                    dismiss()
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }
        }
.presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    }
}

// MARK: - Export Conversation Sheet

struct ExportConversationSheet: View {
    @ObservedObject var viewModel: SearchViewModel
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    @State private var exportFormat: ExportFormat = .markdown

    enum ExportFormat: String, CaseIterable {
        case markdown = "Markdown"
        case json = "JSON"
        case text = "Plain Text"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Format picker
                Picker("Format", selection: $exportFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Preview
                ScrollView {
                    Text(exportPreview)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(theme.textSecondaryColor)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(theme.cardBackgroundColor))
                .padding(.horizontal)

                // Stats
                HStack(spacing: 24) {
                    VStack {
                        Text("\(viewModel.messages.count)")
                            .font(.title2.bold())
                            .foregroundColor(theme.primaryColor)
                        Text("Messages")
                            .font(.caption)
                            .foregroundColor(theme.textSecondaryColor)
                    }

                    VStack {
                        Text("\(totalWords)")
                            .font(.title2.bold())
                            .foregroundColor(theme.primaryColor)
                        Text("Words")
                            .font(.caption)
                            .foregroundColor(theme.textSecondaryColor)
                    }

                    VStack {
                        Text("\(totalCharacters)")
                            .font(.title2.bold())
                            .foregroundColor(theme.primaryColor)
                        Text("Characters")
                            .font(.caption)
                            .foregroundColor(theme.textSecondaryColor)
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(theme.cardBackgroundColor))
                .padding(.horizontal)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button { 
                        copyToClipboard()
                    } label: {
                        HStack {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "Copied!" : "Copy to Clipboard")
                        }
.font(.headline)
    .foregroundColor(.white)
    .frame(maxWidth: .infinity)
    .padding()
    .background(RoundedRectangle(cornerRadius: 12).fill(theme.primaryColor))
                    }

                    Button {
                        shareContent()
                    } label: { 
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                        }
                        .font(.headline)
                        .foregroundColor(theme.primaryColor)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).stroke(theme.primaryColor, lineWidth: 2))
                    }
                }
                .padding(.horizontal)
                    .padding(.bottom)
            }
            .background(theme.backgroundColor)
                .navigationTitle("Export Conversation")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .fontWeight(.semibold)
                    }
            }
        }
        .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
    }

    private var exportPreview: String {
        switch exportFormat {
        case .markdown:
            return String(viewModel.exportConversationAsMarkdown().prefix(500)) + "..."
        case .json:
            if let data = viewModel.exportConversationAsJSON(),
               let string = String(data: data, encoding: .utf8)
            {
                return String(string.prefix(500)) + "..."
            }
            return "Unable to generate JSON"
        case .text:
            return plainTextExport.prefix(500) + "..."
        }
    }

    private var plainTextExport: String {
        viewModel.messages.map { msg in
            let role = msg.role == .user ? "You" : "Assistant"
            return "\(role):\n\(msg.text)\n"
        }.joined(separator: "\n")
    }

    private var fullExport: String {
        switch exportFormat {
        case .markdown:
            return viewModel.exportConversationAsMarkdown()
        case .json:
            if let data = viewModel.exportConversationAsJSON(),
               let string = String(data: data, encoding: .utf8)
            {
                return string
            }
            return "Unable to generate JSON"
        case .text:
            return plainTextExport
        }
    }

    private var totalWords: Int {
        viewModel.messages.reduce(0) { $0 + $1.text.split(separator: " ").count }
    }

    private var totalCharacters: Int {
        viewModel.messages.reduce(0) { $0 + $1.text.count }
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = fullExport
        Haptics.success()
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }

    private func shareContent() {
        let activityVC = UIActivityViewController(
            activityItems: [fullExport],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController
        {
            // Handle iPad popover
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Compact Context Bar

struct CompactContextBar: View {
    @ObservedObject var viewModel: SearchViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.sortedMetadataFilters, id: \.0) { field, filter in
                    HStack(spacing: 4) {
                        Text(field)
                            .font(.caption2.bold())
                        Text(filter.displayValue)
                            .font(.caption2)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        Capsule()
                            .fill(theme.primaryLight)
                    )
.foregroundColor(theme.primaryColor)
                }

                if viewModel.selectedResults.count > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text("\(viewModel.selectedResults.count) selected")
                            .font(.caption2.bold())
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        Capsule()
                            .fill(theme.primaryLight)
                    )
.foregroundColor(theme.primaryColor)
                }
            }
.padding(.horizontal, 4)
        }
    }
}

// MARK: - Chat Timeline

struct ChatTimelineView: View {
    @ObservedObject var viewModel: SearchViewModel
    @Environment(\.theme) private var theme
    @State private var showShareSheet = false
    @State private var shareContent = ""
    @State private var showCopiedToast = false

    var body: some View {
        ZStack(alignment: .top) { 
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.messages.isEmpty {
                            if viewModel.isSearching {
                                SearchLoadingView()
                                    .padding(.vertical, 32)
                            } else { 
                                InitialStateView(
                                    indexName: viewModel.selectedIndex,
                                    namespaceName: viewModel.selectedNamespace,
                                    codeInterpreterEnabled: viewModel.settingsViewModel.codeInterpreterEnabled,
                                    webSearchEnabled: viewModel.settingsViewModel.webSearchEnabled,
                                    onPromptTap: { prompt in
                                        viewModel.searchQuery = prompt
                                    }
                                )
                                .padding(.vertical, 24)
                            }
                        } else { 
                            // Export conversation button
                            HStack {
                                Spacer()
                                Menu {
                                    Button(action: { copyConversation() }) {
                                        Label("Copy Conversation", systemImage: "doc.on.doc")
                                    }
                                    Button(action: { shareConversation() }) {
                                        Label("Share Conversation", systemImage: "square.and.arrow.up")
                                    }
                                    Button(action: { exportAsMarkdown() }) {
                                        Label("Export as Markdown", systemImage: "doc.text")
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.system(size: 14))
                                        Text("Export")
                                            .font(.caption)
                                    }
                                    .foregroundColor(theme.textSecondaryColor)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(theme.cardBackgroundColor)
                                    )
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.bottom, 4)

                            ForEach(viewModel.messages) { message in
                                ChatBubble(
                                    message: message,
                                    onCitationTap: { source in
                                        viewModel.focusResult(for: source)
                                    },
                                    onCopy: { _ in
                                            showCopiedFeedback()
                                        },
                                    onShare: { text in
                                            shareContent = text
                                            showShareSheet = true
                                    }
                                )
                                .id(message.id)
                            }
                            .padding(.horizontal, 8)

                            // Code Interpreter outputs (charts, logs, images)
                            if !viewModel.codeInterpreterOutputs.isEmpty {
                                CodeInterpreterOutputsView(outputs: viewModel.codeInterpreterOutputs)
                                    .padding(.horizontal, 8)
                            }

                            if viewModel.isSearching {
                                TypingIndicatorView()
                                    .padding(.horizontal, 8)
                            }
                        }
                    }
                    .padding(.vertical, 18)
                }
                .background(Color.clear)
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastId = viewModel.messages.last?.id {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }
            }

            // Copied toast
            if showCopiedToast {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                    Text("Copied!")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                }
.padding(.horizontal, 16)
    .padding(.vertical, 10)
    .background(
        Capsule()
            .fill(theme.successColor)
    )
    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    .transition(.move(edge: .top).combined(with: .opacity))
    .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [shareContent])
        }
    }

    private func showCopiedFeedback() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.2)) {
                showCopiedToast = false
            }
        }
    }

    private func copyConversation() {
        let text = formatConversation(asMarkdown: false)
        UIPasteboard.general.string = text
        showCopiedFeedback()
    }

    private func shareConversation() {
        shareContent = formatConversation(asMarkdown: false)
        showShareSheet = true
    }

    private func exportAsMarkdown() {
        shareContent = formatConversation(asMarkdown: true)
        showShareSheet = true
    }

    private func formatConversation(asMarkdown: Bool) -> String {
        var output = asMarkdown ? "# OpenCone Conversation\n\n" : "OpenCone Conversation\n\n"

        for message in viewModel.messages {
            let role = message.role == .user ? "You" : "Assistant"
            if asMarkdown {
                output += "**\(role):**\n\(message.text)\n\n"
                if let citations = message.citations, !citations.isEmpty {
                    output += "_Sources:_ \(citations.joined(separator: ", "))\n\n"
                }
            } else {
                output += "\(role):\n\(message.text)\n\n"
                if let citations = message.citations, !citations.isEmpty {
                    output += "Sources: \(citations.joined(separator: ", "))\n\n"
                }
            }
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed for ShareSheet
    }
}

struct SourcesSurfaceView: View {
    @ObservedObject var viewModel: SearchViewModel

    var body: some View {
        if viewModel.searchResults.isEmpty {
            if viewModel.isSearching {
                SearchLoadingView()
                    .padding(.vertical, 24)
            } else {
                NoResultsView()
                    .padding(.vertical, 24)
            }
        } else {
            SourcesTabView(viewModel: viewModel)
                .padding(.top, 8)
        }
    }
}

private struct IconAccessoryButton: View {
    let systemIcon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemIcon)
                .font(.system(size: 16, weight: .semibold))
                .padding(10)
                .background(
                    Circle()
                        .fill(tint.opacity(0.15))
                )
                .foregroundColor(tint)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TypingIndicatorView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(theme.primaryColor)

            Text("Generating follow-up…")
                .font(.caption)
                .foregroundColor(theme.textSecondaryColor)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.cardBackgroundColor)
        )
    }
}

// MARK: - Search Bar Component

/// The view containing the text input field for the search query and the button
/// to initiate the search.
struct SearchBarView: View {
    @ObservedObject var viewModel: SearchViewModel  // Shared view model
    @Environment(\.theme) private var theme  // Access the current theme
    @State private var isEditing = false

    var body: some View {
        OCCard(padding: 14, cornerRadius: 16) {
            HStack(spacing: 12) {
                // Text field container
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(isEditing ? theme.primaryColor : theme.textSecondaryColor)
                        .padding(.leading, 8)
                        .animation(.easeInOut(duration: 0.2), value: isEditing)

                    // Text field for user query input
                    TextField(
                        "Enter your question...", text: $viewModel.searchQuery,
                        onEditingChanged: { editing in
                            withAnimation {
                                isEditing = editing
                            }
                        }
                    )
                    .padding(.vertical, 12)
                    .foregroundColor(theme.textPrimaryColor)
                    .disabled(viewModel.isSearching)  // Disable input while searching

                    // Clear button (visible only when text field is not empty)
                    if !viewModel.searchQuery.isEmpty {
                        Button(action: {
                            viewModel.searchQuery = ""  // Clear the search query
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(theme.textSecondaryColor)
                                .padding(.trailing, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    isEditing ? theme.primaryColor : Color.clear, lineWidth: 1.5)
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: isEditing)

                // Search execution button
                OCButton(
                    title: "",
                    icon: "arrow.right",
                    style: .primary,
                    action: {
                        hideKeyboard()  // Dismiss keyboard before starting search
                        Task {
                            await viewModel.performSearch()  // Trigger search action
                        }
                    }
                )
                .frame(width: 44, height: 44)
                .disabled(
                    viewModel.searchQuery.isEmpty || viewModel.isSearching
                        || viewModel.selectedIndex == nil
                )
                .opacity(
                    viewModel.searchQuery.isEmpty || viewModel.isSearching
                        || viewModel.selectedIndex == nil ? 0.5 : 1.0
                )
                .animation(
                    .easeInOut(duration: 0.2),
                    value: viewModel.searchQuery.isEmpty || viewModel.isSearching
                        || viewModel.selectedIndex == nil)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Search Loading View

/// A view displayed while the search operation is in progress, showing a
/// circular progress indicator and text.
struct SearchLoadingView: View {
    @Environment(\.theme) private var theme  // Access the current theme
    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // Pulsing background
                Circle()
                    .fill(theme.primaryLight)
                    .frame(width: 100, height: 100)
                    .scaleEffect(pulseScale)

                // Spinning progress arc
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(theme.primaryColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(Angle(degrees: rotation))

                // Search icon
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(theme.primaryColor)
            }

            VStack(spacing: 8) {
                Text("Searching...")
                    .font(.headline)
                    .foregroundColor(theme.textPrimaryColor)

                Text("Finding the most relevant information")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondaryColor)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // Center in available space
        .onAppear {
            // Start animations when view appears
            withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.2
            }
        }
    }
}

// MARK: - No Results View

/// A simple view displayed when a search is performed but yields no results.
struct NoResultsView: View {
    @Environment(\.theme) private var theme  // Access the current theme
    @State private var appearScale: CGFloat = 0.8

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Empty state illustration
            ZStack {
                Circle()
                    .fill(theme.errorLight)
                    .frame(width: 90, height: 90)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundColor(theme.errorColor)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(theme.errorColor)
                            .offset(x: 8, y: -6)
                    )
            }

            VStack(spacing: 8) {
                Text("No results found")
                    .font(.headline)
                    .foregroundColor(theme.textPrimaryColor)

                Text("Try adjusting your search or looking for different terms")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondaryColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            Spacer()
        }
        .scaleEffect(appearScale)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appearScale = 1.0
            }
        }
    }
}

// MARK: - Initial State View

/// The view shown before any search is initiated, with smart example prompts.
struct InitialStateView: View {
    let indexName: String?
    let namespaceName: String?
    let codeInterpreterEnabled: Bool
    let webSearchEnabled: Bool
    let onPromptTap: (String) -> Void

    @Environment(\.theme) private var theme
    @State private var rotation: Double = 0
    @State private var selectedCategory: PromptCategory = .discover

    enum PromptCategory: String, CaseIterable {
        case discover = "Discover"
        case analyze = "Analyze"
        case extract = "Extract"
        case compare = "Compare"

        var icon: String {
            switch self {
            case .discover: return "magnifyingglass"
            case .analyze: return "chart.bar.xaxis"
            case .extract: return "list.bullet.clipboard"
            case .compare: return "arrow.left.arrow.right"
            }
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header with context
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [theme.primaryLight, theme.primaryMedium]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
.frame(width: 80, height: 80)

                    Image(systemName: currentIcon)
                        .resizable()
                        .scaledToFit()
.frame(width: 35, height: 35)
    .foregroundColor(theme.primaryColor)
    .rotationEffect(Angle(degrees: rotation))
                }

                Text(headerTitle)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimaryColor)

                Text(headerSubtitle)
                    .font(.system(.callout, design: .rounded))
                    .foregroundColor(theme.textSecondaryColor)
                    .multilineTextAlignment(.center)
.padding(.horizontal, 40)
            }
            .padding(.top, 16)

            // Category picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PromptCategory.allCases, id: \.self) { category in
                        CategoryPill(
                            title: category.rawValue,
                            icon: category.icon,
                            isSelected: selectedCategory == category,
                            theme: theme
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategory = category
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // Example prompts
            VStack(spacing: 10) {
                ForEach(promptsForCategory(selectedCategory), id: \.self) { prompt in
                    PromptSuggestionRow(prompt: prompt, theme: theme) {
                        onPromptTap(prompt)
                    }
                }
            }
            .padding(.horizontal, 16)
            .animation(.easeInOut(duration: 0.2), value: selectedCategory)

            // Active tools indicator
            if codeInterpreterEnabled || webSearchEnabled {
                HStack(spacing: 12) {
                    if codeInterpreterEnabled {
                        Label("Charts & Calculations", systemImage: "terminal")
                            .font(.caption)
                            .foregroundColor(theme.primaryColor)
                    }
                    if webSearchEnabled {
                        Label("Web Search", systemImage: "globe")
                            .font(.caption)
                            .foregroundColor(theme.primaryColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.primaryLight.opacity(0.5))
                )
            }

            Spacer()
        }
.onAppear { 
            withAnimation(Animation.easeInOut(duration: 20).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }

    // MARK: - Dynamic Content

    private var currentIcon: String {
        if codeInterpreterEnabled { return "chart.bar.doc.horizontal" }
        if webSearchEnabled { return "globe.badge.chevron.backward" }
        return "doc.text.magnifyingglass"
    }

    private var headerTitle: String {
        if let namespace = namespaceName, !namespace.isEmpty {
            return "Search \(namespace.capitalized)"
        } else if let index = indexName {
            return "Search \(index.capitalized)"
        }
        return "Document Search"
    }

    private var headerSubtitle: String {
        if codeInterpreterEnabled {
            return "Ask questions, get answers with charts and calculations"
        } else if webSearchEnabled {
            return "Search your documents and the web together"
        }
        return "Ask anything about your documents"
    }

    private func promptsForCategory(_ category: PromptCategory) -> [String] {
        let context = contextualTerm

        switch category {
        case .discover:
            return [
                "What are the key topics covered in \(context)?",
                "Summarize the main points from \(context)",
                "What should I know first about \(context)?",
                "Give me an overview of \(context)",
            ]
        case .analyze:
            if codeInterpreterEnabled {
                return [
                    "Chart any numerical data found in \(context)",
                    "Calculate totals and averages from \(context)",
                    "Create a timeline visualization from \(context)",
                    "Analyze trends mentioned in \(context) and graph them",
                ]
            } else {
                return [
                    "What patterns or trends appear in \(context)?",
                    "Analyze the key findings from \(context)",
                    "What conclusions can be drawn from \(context)?",
                    "Identify any issues or concerns in \(context)",
                ]
            }
        case .extract:
            if codeInterpreterEnabled {
                return [
                    "Extract all dates and deadlines into a table",
                    "Pull all mentioned names and roles into CSV format",
                    "List all action items with owners and due dates",
                    "Create a structured JSON of key entities from \(context)",
                ]
            } else {
                return [
                    "List all action items mentioned in \(context)",
                    "What dates and deadlines are referenced?",
                    "Extract all names and their roles from \(context)",
                    "What are the requirements listed in \(context)?",
                ]
            }
        case .compare:
            if codeInterpreterEnabled {
                return [
                    "Compare metrics across documents and chart differences",
                    "Create a comparison table of key attributes",
                    "Calculate percentage differences between values found",
                    "Visualize how numbers changed over time in \(context)",
                ]
            } else {
                return [
                    "Compare the different approaches mentioned",
                    "What are the pros and cons discussed?",
                    "How do the options differ from each other?",
                    "What changed between versions or updates?",
                ]
            }
        }
    }

    private var contextualTerm: String {
        if let namespace = namespaceName, !namespace.isEmpty {
            return "the \(namespace) documents"
        } else if let index = indexName {
            return "my \(index) index"
        }
        return "these documents"
    }
}

// MARK: - Supporting Views

private struct CategoryPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let theme: OCTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
.font(.system(size: 12))
Text(title)
    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(isSelected ? .white : theme.primaryColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? theme.primaryColor : theme.primaryLight)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct PromptSuggestionRow: View {
    let prompt: String
    let theme: OCTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(theme.primaryColor)

                Text(prompt)
                    .font(.subheadline)
                    .foregroundColor(theme.textPrimaryColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSecondaryColor)
            }
.padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(
        RoundedRectangle(cornerRadius: 12)
            .fill(theme.cardBackgroundColor)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    )
        }
.buttonStyle(.plain)
    }
}

// MARK: - Sources Tab View

/// The content view for the "Sources" tab, displaying a list of relevant
/// source documents found during the search.
struct SourcesTabView: View {
    @ObservedObject var viewModel: SearchViewModel  // Shared view model
    @Environment(\.theme) private var theme  // Access the current theme
    @State private var selectedFilter: String? = nil
    @State private var sourceTypes: [String] = []
    @State private var selectedCount: Int = 0

    var filteredResults: [SearchResultModel] {
        if let filter = selectedFilter {
            return viewModel.searchResults.filter { result in
                let ext = result.sourceDocument.split(separator: ".").last?.lowercased() ?? ""
                return ext == filter.lowercased()
            }
        }
        return viewModel.searchResults
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Sources")
                    .font(.headline)
                    .foregroundColor(theme.textPrimaryColor)

                Spacer()

                if !viewModel.selectedResults.isEmpty {
                    OCButton(
                        title: "Regenerate",
                        icon: "arrow.triangle.2.circlepath",
                        style: .outline
                    ) {
                        Task {
                            await viewModel.generateAnswerFromSelected()
                        }
                    }
                    .disabled(viewModel.isSearching)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Filter pills row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // All filter
                    filterPill(nil, count: viewModel.searchResults.count)

                    // Extension-based filters
                    ForEach(sourceTypes, id: \.self) { ext in
                        let count = viewModel.searchResults.filter {
                            $0.sourceDocument.hasSuffix(".\(ext)")
                        }.count
                        filterPill(ext, count: count)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }

            // Selection counter
            if !viewModel.selectedResults.isEmpty {
                HStack {
                    OCBadge(
                        "\(viewModel.selectedResults.count) selected",
                        style: .custom(theme.primaryColor)
                    )
                    .padding(.leading)

                    Spacer()

                    Button(action: {
                        for result in viewModel.searchResults {
                            if !viewModel.selectedResultIDs.contains(result.id) {
                                viewModel.toggleResultSelection(result)
                            }
                        }
                    }) {
                        Text("Select All")
                            .font(.caption)
                            .foregroundColor(theme.primaryColor)
                    }
                    .padding(.trailing)
                }
                .padding(.bottom, 4)
            }

            // Results list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredResults) { result in
                            SearchResultRow(
                                result: result,
                                isSelected: viewModel.selectedResultIDs.contains(result.id),
                                viewModel: viewModel
                            ) {
                                viewModel.toggleResultSelection(result)
                            }
                            .id(result.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
                .onChange(of: viewModel.highlightedResultID) { _, newId in
                    guard let targetId = newId else { return }
                    if !filteredResults.contains(where: { $0.id == targetId }) {
                        withAnimation { selectedFilter = nil }
                    }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(targetId, anchor: .top)
                        }
                    }
                }
            }
        }
        .background(Color.clear)
        .onAppear {
            // Extract unique source types for filters
            let extensions = Set(
                viewModel.searchResults.compactMap { result -> String? in
                    let components = result.sourceDocument.split(separator: ".")
                    return components.last.map(String.init)?.lowercased()
                })
            sourceTypes = Array(extensions).sorted()

            // Count selected results
            selectedCount = viewModel.selectedResults.count
        }
        .onChange(of: viewModel.selectedResults.count) { oldCount, newCount in
            withAnimation {
                selectedCount = newCount
            }
        }
    }

    // Helper to create filter pill buttons
    private func filterPill(_ type: String?, count: Int) -> some View {
        Button(action: {
            withAnimation {
                selectedFilter = (selectedFilter == type) ? nil : type
            }
        }) {
            HStack(spacing: 4) {
                if let type = type {
                    Image(systemName: documentIcon(for: type))
                        .font(.system(size: 12))
                } else {
                    Image(systemName: "tray.full")
                        .font(.system(size: 12))
                }

                Text(type?.uppercased() ?? "ALL")
                    .font(.caption.bold())

                Text("(\(count))")
                    .font(.caption)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(selectedFilter == type ? theme.primaryLight : theme.cardBackgroundColor)
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
            )
            .foregroundColor(selectedFilter == type ? theme.primaryColor : theme.textSecondaryColor)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // Get document icon for filter pills
    private func documentIcon(for ext: String) -> String {
        switch ext.lowercased() {
        case "pdf": return "doc.fill"
        case "md": return "doc.text"
        case "txt": return "doc.plaintext"
        default: return "doc"
        }
    }
}

// MARK: - Search Result Row

/// A view representing a single item in the list of search results (source documents).
/// Displays metadata and allows expansion to view the document chunk content.
struct SearchResultRow: View {
    let result: SearchResultModel  // Data for the result
    let isSelected: Bool  // Whether this result is currently selected
    let viewModel: SearchViewModel  // Access to view model for theming
    let onTap: () -> Void  // Action to perform when the row is tapped (toggles selection)

    @Environment(\.theme) private var theme  // Access the current theme
    @State private var showShareSheet = false

    var body: some View {
        let isExpanded = viewModel.expandedResultIDs.contains(result.id)
        let isHighlighted = viewModel.highlightedResultID == result.id

        OCCard(padding: isExpanded ? 16 : 12, cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 0) {
                // Header part of the row (metadata, selection indicator, expand button)
                ResultHeaderView(
                    result: result,
                    isSelected: isSelected,
                    isExpanded: isExpanded,
                    isHighlighted: isHighlighted,
                    viewModel: viewModel,
                    onToggleExpand: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.toggleResultExpansion(for: result.id)
                        }
                    }
                )

                // Show the content view only if expanded
                if isExpanded {
                    ResultContentView(content: result.content, theme: theme)
                        // Apply transition for smooth appearance/disappearance
                        .transition(.opacity.combined(with: .move(edge: .top)))

                    // Action buttons when expanded
                    HStack(spacing: 16) {
                        Button(action: {
                            UIPasteboard.general.string = result.content
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12))
                                Text("Copy")
                                    .font(.caption)
                            }
                            .foregroundColor(theme.textSecondaryColor)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: {
                            showShareSheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 12))
                                Text("Share")
                                    .font(.caption)
                            }
                            .foregroundColor(theme.textSecondaryColor)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
        }
        .onTapGesture {
            onTap()  // Trigger the selection toggle action
        }
        .overlay(
            // Border that changes color based on selection state
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isHighlighted ? theme.primaryColor : (isSelected ? theme.primaryColor.opacity(0.6) : Color.clear),
                    lineWidth: isHighlighted ? 3 : (isSelected ? 2 : 0)
                )
        )
.contextMenu {
    Button(action: {
        UIPasteboard.general.string = result.content
    }) {
        Label("Copy Content", systemImage: "doc.on.doc")
    }

    Button(action: {
        showShareSheet = true
    }) {
        Label("Share Content", systemImage: "square.and.arrow.up")
    }

    Divider()

    Button(action: {
        let fullInfo = """
        Source: \(result.sourceDocument)
        Score: \(String(format: "%.3f", result.score))

        Content:
        \(result.content)
        """
        UIPasteboard.general.string = fullInfo
    }) {
        Label("Copy with Metadata", systemImage: "doc.text")
    }

    Button(action: {
        onTap()
    }) {
        Label(isSelected ? "Deselect" : "Select", systemImage: isSelected ? "checkmark.circle" : "circle")
    }
}
.sheet(isPresented: $showShareSheet) {
    ShareSheet(items: [result.content])
}
    }
}

// MARK: - Result Header View

/// The header portion of a `SearchResultRow`. Displays the document icon, filename,
/// relevance score, selection checkmark (if selected), and expand/collapse button.
struct ResultHeaderView: View {
    let result: SearchResultModel  // Data for the result
    let isSelected: Bool  // Selection state
    let isExpanded: Bool  // Expansion state
    let isHighlighted: Bool
    let viewModel: SearchViewModel  // Access to view model for theming
    let onToggleExpand: () -> Void  // Action for the expand/collapse button

    @Environment(\.theme) private var theme  // Access the current theme
    @State private var checkmarkScale: CGFloat = 0.4

    var body: some View {
        HStack(spacing: 12) {
            // Left side: Icon, filename, score badge
            VStack(alignment: .leading, spacing: 6) {
                // Icon and filename row
                HStack(spacing: 8) {
                    documentTypeIcon()

                    Text(sourceFileName(from: result.sourceDocument))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(isHighlighted ? theme.primaryColor : theme.textPrimaryColor)
                        .lineLimit(1)  // Prevent long filenames from wrapping
                }

                // Metadata row (score and other useful info)
                HStack(spacing: 10) {
                    // Score badge with visual representation of relevance
                    OCBadge(
                        viewModel.getRelevanceLabel(result.score),
                        style: .custom(viewModel.getColorForScore(result.score))
                    )

                    // Formatted score value
                    Text(String(format: "Score: %.3f", result.score))
                        .font(.caption)
                        .foregroundColor(theme.textSecondaryColor)
                }
            }

            Spacer()  // Push elements to the sides

            // Right side: Selection checkmark and expand button
            HStack(spacing: 10) {
                // Show checkmark if the item is selected
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.primaryColor)
                        .font(.system(size: 18))
                        .scaleEffect(checkmarkScale)
                        .onAppear {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                checkmarkScale = 1.0
                            }
                        }
                }

                // Expand/collapse button
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textSecondaryColor)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(theme.cardBackgroundColor)
                                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Circle())
            }
        }
    }

    // Create visually appealing document type icon
    private func documentTypeIcon() -> some View {
        let iconName = getDocumentIcon(from: result.sourceDocument)
        let iconColor = isHighlighted ? theme.primaryColor : viewModel.getColorForScore(result.score)

        return ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(iconColor.opacity(isHighlighted ? 0.25 : 0.15))
                .frame(width: 28, height: 28)

            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundColor(iconColor)
        }
    }

    /// Extracts the filename from a full source path string.
    private func sourceFileName(from source: String) -> String {
        let components = source.split(separator: "/")
        return components.last.map { String($0) } ?? source
    }

    /// Determines the appropriate SF Symbol icon name based on the file extension.
    private func getDocumentIcon(from source: String) -> String {
        if source.hasSuffix(".pdf") {
            return "doc.fill"
        } else if source.hasSuffix(".md") {
            return "doc.text"
        } else if source.hasSuffix(".txt") {
            return "doc.plaintext"
        } else {
            return "doc"
        }
    }
}

// MARK: - Result Content View

/// The view displayed when a `SearchResultRow` is expanded. Shows the actual
/// text content (chunk) of the source document.
struct ResultContentView: View {
    let content: String  // The text content to display
    let theme: OCTheme  // The current theme
    @State private var textOpacity = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Content divider
            Divider()
                .padding(.top, 12)

            // Document content with highlighting
            Text(content)
                .font(.callout)
                .lineSpacing(4)
                .foregroundColor(theme.textPrimaryColor)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.cardBackgroundColor)
                .cornerRadius(8)
                .opacity(textOpacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.4).delay(0.1)) {
                        textOpacity = 1.0
                    }
                }
        }
    }
}

// MARK: - Metadata Filter Sheet

struct MetadataFilterSheet: View {
    @ObservedObject var viewModel: SearchViewModel
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if let warning = viewModel.filterParseError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(theme.errorColor)
                        Text(warning)
                            .font(.caption)
                            .foregroundColor(theme.errorColor)
                    }
                    .padding(12)
                    .background(theme.errorLight)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                Form {
                    Section {
                        TextField("Field name", text: $viewModel.newFilterField)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: viewModel.newFilterField) { _, _ in
                                viewModel.clearFilterError()
                            }

                        TextField("Value", text: $viewModel.newFilterValue)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: viewModel.newFilterValue) { _, _ in
                                viewModel.clearFilterError()
                            }

                        Button("Add Filter") {
                            viewModel.commitNewMetadataFilter()
                        }
                        .disabled(!formIsValid)
                    } header: {
                        Text("New Filter")
                    } footer: {
                        Text("Filters accept exact matches, arrays, or comparison operators (e.g. >=2023).")
                    }

                    if !viewModel.metadataFilters.isEmpty {
                        Section("Active Filters") {
                            ForEach(viewModel.sortedMetadataFilters, id: \.0) { field, filter in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(field)
                                            .font(.subheadline.weight(.medium))
                                        Text(filter.displayValue)
                                            .font(.caption)
                                            .foregroundColor(theme.textSecondaryColor)
                                    }
                                    Spacer()
                                    Button {
                                        viewModel.removeMetadataFilter(field: field)
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(theme.errorColor)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Metadata Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !viewModel.metadataFilters.isEmpty {
                        Button("Clear All") {
                            viewModel.clearMetadataFilters()
                        }
                        .foregroundColor(theme.errorColor)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }

    private var formIsValid: Bool {
        !viewModel.newFilterField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !viewModel.newFilterValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Metadata Filter Editor

struct MetadataFilterEditor: View {
    @ObservedObject var viewModel: SearchViewModel
    @Environment(\.theme) private var theme
    @State private var isExpanded = false
    @State private var didInitialize = false

    var body: some View {
        OCCard(padding: 16, cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Metadata Filters")
                            .font(.headline)
                            .foregroundColor(theme.textPrimaryColor)

                        Text(summaryText)
                            .font(.caption)
                            .foregroundColor(theme.textSecondaryColor)
                    }

                    Spacer()

                    if !viewModel.metadataFilters.isEmpty {
                        Button("Clear", action: viewModel.clearMetadataFilters)
                            .font(.caption.bold())
                            .foregroundColor(theme.primaryColor)
                            .buttonStyle(PlainButtonStyle())
                    }

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(theme.cardBackgroundColor)
                            )
                            .foregroundColor(theme.textSecondaryColor)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                if isExpanded {
                    if let warning = viewModel.filterParseError {
                        Text(warning)
                            .font(.caption)
                            .foregroundColor(theme.errorColor)
                    }

                    VStack(spacing: 10) {
                        filterInputField(
                            title: "Field (e.g. doc_id)",
                            text: $viewModel.newFilterField
                        )

                        filterInputField(
                            title: "Value or rule (e.g. [policy], >=2024)",
                            text: $viewModel.newFilterValue,
                            submit: viewModel.commitNewMetadataFilter
                        )

                        OCButton(
                            title: "Add Filter",
                            icon: "line.3.horizontal.decrease.circle",
                            style: .primary,
                            action: viewModel.commitNewMetadataFilter
                        )
                        .disabled(!formIsValid)
                    }

                    if viewModel.metadataFilters.isEmpty {
                        Text("Add filters to narrow the context window. Filters accept exact matches, arrays, or comparison operators (e.g. >=2023).")
                            .font(.caption)
                            .foregroundColor(theme.textSecondaryColor)
                            .padding(.top, 4)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(viewModel.sortedMetadataFilters, id: \.0) { field, filter in
                                MetadataFilterRow(
                                    field: field,
                                    value: filter.displayValue,
                                    onRemove: { viewModel.removeMetadataFilter(field: field) }
                                )
                            }
                        }
                        .padding(.top, 4)
                    }
                } else {
                    filterChipsSummary
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            guard !didInitialize else { return }
            isExpanded = viewModel.metadataFilters.isEmpty
            didInitialize = true
        }
        .onChange(of: viewModel.metadataFilters.count) { _, newCount in
            if newCount == 0 {
                withAnimation { isExpanded = true }
            }
        }
    }

    private var summaryText: String {
        if viewModel.metadataFilters.isEmpty {
            return "No filters applied"
        }
        return "\(viewModel.metadataFilters.count) active filters"
    }

    private var formIsValid: Bool {
        !viewModel.newFilterField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !viewModel.newFilterValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private var filterChipsSummary: some View {
        if viewModel.metadataFilters.isEmpty {
            Text("Tap to add metadata gates before sending a query.")
                .font(.caption)
                .foregroundColor(theme.textSecondaryColor)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.sortedMetadataFilters, id: \.0) { field, filter in
                        MetadataFilterChip(
                            field: field,
                            value: filter.displayValue,
                            onRemove: { viewModel.removeMetadataFilter(field: field) }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func filterInputField(
        title: String,
        text: Binding<String>,
        submit: (() -> Void)? = nil
    ) -> some View {
        TextField(title, text: text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onSubmit { submit?() }
            .onChange(of: text.wrappedValue) { _, _ in
                viewModel.clearFilterError()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.cardBackgroundColor.opacity(0.8))
            )
    }
}

private struct MetadataFilterRow: View {
    let field: String
    let value: String
    let onRemove: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(field)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.textPrimaryColor)

                Text(value)
                    .font(.footnote)
                    .foregroundColor(theme.textSecondaryColor)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(theme.textSecondaryColor)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Remove filter \(field)")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.cardBackgroundColor.opacity(0.7))
        )
    }
}

private struct MetadataFilterChip: View {
    let field: String
    let value: String
    let onRemove: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Text(field)
                .font(.caption.bold())
            Text(value)
                .font(.caption)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            Capsule()
                .fill(theme.cardBackgroundColor)
        )
        .foregroundColor(theme.primaryColor)
    }
}

// Generic searchable sheet for Indexes
private struct IndexListSheet: View {
    let title: String
    let allItems: [String]
    @Binding var query: String
    let onRefresh: () -> Void
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var filtered: [String] {
        guard !query.isEmpty else { return allItems }
        return allItems.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(filtered, id: \.self) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        HStack {
                            Image(systemName: "tray.full")
                                .foregroundColor(theme.primaryColor)
                            Text(item)
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .frame(height: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .refreshable { onRefresh() }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// Generic searchable sheet for Namespaces
private struct NamespaceListSheet: View {
    let title: String
    let allItems: [String]
    @Binding var query: String
    let onRefresh: () -> Void
    let onSelect: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var filtered: [String] {
        guard !query.isEmpty else { return allItems }
        return allItems.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationView {
            List {
                // Default (nil) option
                Button {
                    onSelect(nil)
                } label: {
                    HStack {
                        Image(systemName: "circle")
                            .foregroundColor(theme.textSecondaryColor)
                        Text("Default")
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .frame(height: 48)
                }
                .buttonStyle(PlainButtonStyle())

                ForEach(filtered, id: \.self) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        HStack {
                            Image(systemName: "tag")
                                .foregroundColor(theme.primaryColor)
                            Text(item)
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .frame(height: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .refreshable { onRefresh() }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct NoIndexEmptyState: View {
    @Environment(\.theme) private var theme
    let onShowDocuments: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "server.rack")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(theme.textSecondaryColor)

            VStack(spacing: 8) {
                Text("No Pinecone Index Found")
                    .font(.title3.bold())
                    .foregroundColor(theme.textPrimaryColor)

                Text(
                    "Create a Pinecone index + namespace from the Documents tab to start searching your knowledge base.")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondaryColor)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Open the Documents tab and tap \"Add Documents\" to ingest your first file.",
                      systemImage: "1.circle")
                    .font(.footnote)
                    .foregroundColor(theme.textSecondaryColor)
                Label("During ingest, pick an index + namespace (or let the app create them).",
                      systemImage: "2.circle")
                    .font(.footnote)
                    .foregroundColor(theme.textSecondaryColor)
            }

            OCButton(
                title: "Go to Documents",
                icon: "doc.text.magnifyingglass",
                style: .primary,
                action: onShowDocuments
            )
            .frame(maxWidth: 260)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackgroundColor)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}

private struct ErrorBanner: View {
    let message: String
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(theme.errorColor)
            Text(message)
                .font(.caption)
                .foregroundColor(theme.errorColor)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.errorLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.errorColor.opacity(0.6), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        .accessibilityLabel("Error: \(message)")
    }
}

// MARK: - Extensions and Helpers

extension View {
    /// Helper function to dismiss the keyboard programmatically
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Code Interpreter Outputs View

/// Displays outputs from OpenAI's code interpreter tool (charts, logs, images)
struct CodeInterpreterOutputsView: View {
    let outputs: [CodeInterpreterOutput]
    @Environment(\.theme) private var theme
    @State private var expandedOutputs: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.primaryColor)
                Text("Code Interpreter Results")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.textPrimaryColor)
                Spacer()
                Text("\(outputs.count)")
                    .font(.caption.weight(.medium))
                    .foregroundColor(theme.textSecondaryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(theme.cardBackgroundColor))
            }

            ForEach(outputs) { output in
                outputCard(for: output)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackgroundColor)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }

    @ViewBuilder
    private func outputCard(for output: CodeInterpreterOutput) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Type badge and expand toggle
            HStack {
                Label(
                    output.type == .logs ? "Execution Output" :
                        output.type == .image ? "Generated Chart" : "Error",
                    systemImage: output.type == .logs ? "terminal" :
                        output.type == .image ? "photo" : "exclamationmark.triangle"
                )
                .font(.caption.weight(.medium))
                .foregroundColor(output.type == .error ? theme.errorColor : theme.textSecondaryColor)

                Spacer()

                if output.type == .logs && output.content.count > 200 {
                    Button {
                        if expandedOutputs.contains(output.id) {
                            expandedOutputs.remove(output.id)
                        } else {
                            expandedOutputs.insert(output.id)
                        }
                    } label: {
                        Image(systemName: expandedOutputs.contains(output.id) ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(theme.textSecondaryColor)
                    }
                }
            }

            // Content
            switch output.type {
            case .logs:
                let isExpanded = expandedOutputs.contains(output.id)
                let displayContent = isExpanded || output.content.count <= 200
                    ? output.content
                    : String(output.content.prefix(200)) + "..."

                Text(displayContent)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(theme.textPrimaryColor)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.05))
                    )
                    .textSelection(.enabled)

            case .image:
                if output.content.hasPrefix("http") {
                    // It's a URL
                    AsyncImage(url: URL(string: output.content)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(height: 200)
                        case let .success(image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure:
                            Label("Failed to load image", systemImage: "exclamationmark.triangle")
                                .foregroundColor(theme.errorColor)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    // It's base64
                    if let data = Data(base64Encoded: output.content),
                       let uiImage = UIImage(data: data)
                    {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Label("Invalid image data", systemImage: "exclamationmark.triangle")
                            .foregroundColor(theme.errorColor)
                    }
                }

            case .error:
                Text(output.content)
                    .font(.caption)
                    .foregroundColor(theme.errorColor)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.errorLight)
                    )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.textSecondaryColor.opacity(0.1), lineWidth: 1)
        )
    }
}
