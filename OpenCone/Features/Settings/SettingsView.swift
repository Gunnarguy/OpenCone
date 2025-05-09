// MARK: - SettingsView.swift
import SwiftUI

/// View for app settings
struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var isShowingResetAlert = false
    @State private var isSaved = false
    @State private var animateSaveIcon = false

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

                // Theme settings section
                settingSection(
                    title: "Appearance",
                    systemImage: "paintpalette.fill"
                ) {
                    appearanceContent
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

            Text("The Pinecone Project ID is required for API access.")
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.textSecondaryColor)
        }
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

            Text(
                "The embedding model converts text to vectors. The completion model generates answers from search results."
            )
            .font(.caption)
            .foregroundColor(themeManager.currentTheme.textSecondaryColor)
            .padding(.top, 8)
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
