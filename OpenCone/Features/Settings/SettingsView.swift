import SwiftUI
import UIKit

/// Settings, laid out like OpenResponses' settings: segmented tabs over inset grouped forms.
/// General holds the keys and your data, Answers the same answer settings as the gear in Ask, and
/// Advanced the search defaults, uploads, the Pinecone API versions and the log.
struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 12) {
            Picker("Section", selection: $selectedTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsTab(viewModel: viewModel)
                case .answers:
                    AnswerSettingsForm(settings: viewModel)
                case .advanced:
                    AdvancedSettingsTab(viewModel: viewModel)
                }
            }
            .animation(.none, value: selectedTab)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum SettingsTab: CaseIterable {
    case general
    case answers
    case advanced

    var title: String {
        switch self {
        case .general: return "General"
        case .answers: return "Answers"
        case .advanced: return "Advanced"
        }
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var showingExport = false
    @State private var showingImport = false
    @State private var confirmingReset = false
    @State private var exportedJSON = ""

    var body: some View {
        Form {
            Section {
                keyRow("OpenAI API key", text: $viewModel.openAIAPIKey, status: viewModel.openAIStatus, secure: true)
                keyRow("Pinecone API key", text: $viewModel.pineconeAPIKey, status: viewModel.pineconeStatus, secure: true)
                keyRow("Pinecone project ID", text: $viewModel.pineconeProjectId, status: nil, secure: false)
                Button {
                    viewModel.validateAll()
                } label: {
                    Label("Check connections", systemImage: "checkmark.shield")
                }
            } header: {
                Label("Connections", systemImage: "key.fill")
            } footer: {
                Text(connectionsFooter)
            }

            Section {
                Button {
                    if let json = viewModel.exportSettingsAsJSON() {
                        exportedJSON = json
                        showingExport = true
                    }
                } label: {
                    Label("Export settings", systemImage: "square.and.arrow.up")
                }
                Button {
                    showingImport = true
                } label: {
                    Label("Import settings", systemImage: "square.and.arrow.down")
                }
                Button(role: .destructive) {
                    confirmingReset = true
                } label: {
                    Label("Remove keys and reset everything", systemImage: "trash")
                }
                if let status = viewModel.secureResetStatus {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("Your data", systemImage: "lock.shield")
            } footer: {
                Text("Exports never include your keys. Reset removes the keys from the Keychain, every preference, and what OpenCone learned about your indexes.")
            }

            Section {
                LabeledContent("Version", value: Self.versionText)
                if let privacy = URL(string: "https://github.com/Gunnarguy/OpenCone/blob/main/PRIVACY.md") {
                    Link(destination: privacy) {
                        Label("Privacy policy", systemImage: "hand.raised")
                    }
                }
                if let source = URL(string: "https://github.com/Gunnarguy/OpenCone") {
                    Link(destination: source) {
                        Label("Source code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
            } header: {
                Label("About", systemImage: "info.circle")
            }
        }
        .confirmationDialog("Remove keys and reset everything?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset everything", role: .destructive, action: viewModel.resetSecureState)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your API keys, preferences and index summaries. Your Pinecone indexes aren't touched.")
        }
        .sheet(isPresented: $showingExport) {
            SettingsExportSheet(json: exportedJSON)
        }
        .sheet(isPresented: $showingImport) {
            SettingsImportSheet(viewModel: viewModel)
        }
    }

    private var connectionsFooter: String {
        "Keys are kept in this iPhone's Keychain. A changed key is used after you reopen OpenCone."
    }

    private func keyRow(_ title: String, text: Binding<String>, status: CredentialStatus?, secure: Bool) -> some View {
        HStack(spacing: 8) {
            Group {
                if secure {
                    SecureField(title, text: text)
                } else {
                    TextField(title, text: text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if let status {
                CredentialStatusIcon(status: status)
            }
        }
    }

    static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

private struct CredentialStatusIcon: View {
    let status: CredentialStatus

    var body: some View {
        switch status {
        case .unknown:
            EmptyView()
        case .validating:
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Checking")
        case .valid:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.green)
                .accessibilityLabel("Works")
        case .invalid(let message):
            Image(systemName: "xmark.octagon.fill")
                .foregroundStyle(Color.red)
                .accessibilityLabel("Doesn't work: \(message)")
        case .rateLimited(let seconds):
            Image(systemName: "clock.fill")
                .foregroundStyle(Color.orange)
                .accessibilityLabel("Rate limited, try again in \(seconds) seconds")
        }
    }
}

// MARK: - Advanced

private struct AdvancedSettingsTab: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var confirmingReset = false

    var body: some View {
        Form {
            Section {
                Toggle("Always open the preferred index", isOn: $viewModel.enforcePreferredIndex)
                TextField("Preferred index", text: $viewModel.preferredIndexName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Preferred namespace", text: $viewModel.preferredNamespace)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Label("Search defaults", systemImage: "star")
            } footer: {
                Text("When the preferred index exists, Ask opens it as the index to search. Without the switch, the index you used last wins.")
            }

            Section {
                ForEach(viewModel.metadataPresets) { preset in
                    LabeledContent(preset.field, value: preset.rawValue)
                        .swipeActions {
                            Button(role: .destructive) {
                                viewModel.removeMetadataPreset(preset)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                }
                TextField("Field", text: $viewModel.newPresetField)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Value or rule", text: $viewModel.newPresetValue)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(viewModel.addMetadataPreset)
                Button("Add default filter", action: viewModel.addMetadataPreset)
                    .disabled(
                        viewModel.newPresetField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || viewModel.newPresetValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                if let error = viewModel.metadataPresetError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Color.red)
                }
            } header: {
                Label("Default metadata filters", systemImage: "line.3.horizontal.decrease.circle")
            } footer: {
                Text("Applied to every search of the open index each time OpenCone starts. Change them for one conversation under Where to search in Ask.")
            }

            Section {
                Picker("Embedding model", selection: $viewModel.embeddingModel) {
                    ForEach(viewModel.availableEmbeddingModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                Picker("Dimensions for new indexes", selection: $viewModel.embeddingDimension) {
                    Text("1536").tag(1536)
                    Text("3072").tag(3072)
                }
            } header: {
                Label("Uploads", systemImage: "square.and.arrow.up.on.square")
            } footer: {
                Text("Documents are embedded with this model. Questions use the model that built each index once OpenCone has checked it.")
            }

            Section {
                Picker("Log level", selection: $viewModel.logMinimumLevel) {
                    ForEach(viewModel.availableLogLevels, id: \.self) { level in
                        Text(level.rawValue.capitalized).tag(level)
                    }
                }
                NavigationLink {
                    ProcessingView()
                        .navigationTitle("Activity log")
                } label: {
                    Label("Activity log", systemImage: "list.bullet.rectangle")
                }
            } header: {
                Label("Diagnostics", systemImage: "stethoscope")
            } footer: {
                Text("The log stays on this iPhone unless you share it.")
            }

            Section {
                LabeledContent("Control plane") {
                    versionField("2024-07", text: $viewModel.pineconeControlPlaneVersion)
                }
                LabeledContent("Data plane") {
                    versionField("2024-07", text: $viewModel.pineconeDataPlaneVersion)
                }
                LabeledContent("Namespaces") {
                    versionField("2025-01", text: $viewModel.pineconeNamespaceVersion)
                }
                LabeledContent("Metadata fetch") {
                    versionField("2025-01", text: $viewModel.pineconeMetadataFetchVersion)
                }
            } header: {
                Label("Pinecone API versions", systemImage: "number")
            } footer: {
                Text("Change these only to follow a Pinecone API change. They're used after you reopen OpenCone.")
            }

            Section {
                Button("Reset settings to defaults", role: .destructive) {
                    confirmingReset = true
                }
            } footer: {
                Text("Your keys stay.")
            }
        }
        .confirmationDialog("Reset settings to defaults?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive, action: viewModel.resetToDefaults)
            Button("Cancel", role: .cancel) {}
        }
    }

    private func versionField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .multilineTextAlignment(.trailing)
            .font(.body.monospacedDigit())
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.numbersAndPunctuation)
    }
}

// MARK: - Export and import

private struct SettingsExportSheet: View {
    let json: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(json)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .navigationTitle("Exported settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIPasteboard.general.string = json
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: json)
                }
            }
        }
    }
}

private struct SettingsImportSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 200)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        text = UIPasteboard.general.string ?? text
                    } label: {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                } footer: {
                    Text(failed ? "That isn't settings JSON exported from OpenCone." : "Paste settings exported from OpenCone. Keys aren't part of an export.")
                        .foregroundStyle(failed ? Color.red : Color.secondary)
                }
            }
            .navigationTitle("Import settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        if viewModel.importSettings(from: text) {
                            dismiss()
                        } else {
                            failed = true
                        }
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
