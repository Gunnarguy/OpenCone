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

    var body: some View {
        // Use a ScrollView with VStack instead of Form for more customizable appearance
        ScrollView {
            VStack(spacing: OCDesignSystem.Spacing.large) {
                // API Keys section
                settingSection(
                    title: "API Keys",
                    systemImage: "key.fill"
                ) {
                    apiKeysContent
                }

                // Processing settings section
                settingSection(
                    title: "Document Processing",
                    systemImage: "gearshape.fill"
                ) {
                    processingSettingsContent
                }

                // Model selection section
                settingSection(
                    title: "AI Models",
                    systemImage: "brain.head.profile"
                ) {
                    modelSelectionContent
                }

                settingSection(
                    title: "Search Defaults",
                    systemImage: "magnifyingglass"
                ) {
                    searchDefaultsContent
                }

                // Theme settings section
                settingSection(
                    title: "Appearance",
                    systemImage: "paintpalette.fill"
                ) {
                    appearanceContent
                }

                // Search UI preferences
                settingSection(
                    title: "Search UI",
                    systemImage: "text.bubble"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Show Answer Panel under Chat", isOn: $viewModel.showAnswerPanelBelowChat)
                        Text("When enabled, the Answer & Sources panel stays docked under the conversation. Turn OFF to use a compact chat layout and open the panel on demand.")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                    }
                }

                settingSection(
                    title: "Logging",
                    systemImage: "waveform.path.ecg"
                ) {
                    loggingContent
                }

                settingSection(
                    title: "Data & Privacy",
                    systemImage: "lock.shield"
                ) {
                    dataPrivacyContent
                }

                // Actions section
                actionsSection

                // About section
                settingSection(
                    title: "About",
                    systemImage: "info.circle.fill"
                ) {
                    aboutContent
                }
            }
            .padding()
        }
        .background(themeManager.currentTheme.backgroundColor.ignoresSafeArea())
        .alert(isPresented: $isShowingResetAlert) {
            Alert(
                title: Text("Reset Settings"),
                message: Text(
                    "Are you sure you want to reset all settings to default values? This won't clear your API keys."
                ),
                primaryButton: .destructive(Text("Reset")) {
                    viewModel.resetToDefaults()
                },
                secondaryButton: .cancel()
            )
        }
        .alert(
            item: Binding<IdentifiableError?>(
                get: { viewModel.errorMessage.map { IdentifiableError($0) } },
                set: { viewModel.errorMessage = $0?.message }
            )
        ) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .confirmationDialog(
            "Reset stored keys?",
            isPresented: $showSecureResetDialog,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                viewModel.resetSecureState()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes API keys, Pinecone preferences, conversation history, and bookmark consent so you can start fresh.")
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
                    Picker("Cloud", selection: $viewModel.pineconeCloud) {
                        Text("AWS").tag("aws")
                        Text("GCP").tag("gcp")
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

                    // Region picker (basic presets; can be expanded)
                    Picker("Region", selection: $viewModel.pineconeRegion) {
                        Text("us-east-1").tag("us-east-1")
                        Text("us-west-2").tag("us-west-2")
                        Text("eu-central-1").tag("eu-central-1")
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
                Text("Completion Model")
                    .font(.subheadline.bold())

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
                            themeManager.currentTheme.textSecondaryColor.opacity(0.3), lineWidth: 1)
                )
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
