import SwiftUI
import UIKit

/// Settings, laid out like OpenResponses' settings: segmented tabs over inset grouped forms.
/// General holds the keys and your data, Answers the same answer settings as the gear in Ask, and
/// Advanced every endpoint OpenCone calls, the search defaults, uploads, new indexes, the Pinecone API
/// versions and the log.
struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var selectedTab: SettingsTab = .demoInitial

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

    /// The tab a demo screen opens on (`DemoMode`); General otherwise
    static var demoInitial: SettingsTab {
        switch DemoMode.screen {
        case "settings-answers": return .answers
        case "settings-advanced", "endpoints", "endpoint": return .advanced
        default: return .general
        }
    }

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
                AppHeader(openAIStatus: viewModel.openAIStatus, pineconeStatus: viewModel.pineconeStatus)
            }

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

/// OpenCone's icon, version, and whether each key works
private struct AppHeader: View {
    let openAIStatus: CredentialStatus
    let pineconeStatus: CredentialStatus

    var body: some View {
        HStack(spacing: 14) {
            AppIconImage()
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 13.5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13.5, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08))
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("OpenCone")
                        .font(.title3.weight(.semibold))
                    Text("Version \(GeneralSettingsTab.versionText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    ConnectionPill(name: "OpenAI", status: openAIStatus)
                    ConnectionPill(name: "Pinecone", status: pineconeStatus)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

/// The app's own icon, read from the bundle; a symbol when it can't be
private struct AppIconImage: View {
    var body: some View {
        if let icon = Self.icon {
            Image(uiImage: icon)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "magnifyingglass")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    private static let icon: UIImage? = {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let name = files.last
        else {
            return nil
        }
        return UIImage(named: name)
    }()
}

/// "OpenAI" with a dot that says whether its key works
private struct ConnectionPill: View {
    let name: String
    let status: CredentialStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(name)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name): \(spoken)")
    }

    private var color: Color {
        switch status {
        case .valid: return .green
        case .invalid: return .red
        case .rateLimited: return .orange
        case .validating, .unknown: return .gray
        }
    }

    private var spoken: String {
        switch status {
        case .valid: return "works"
        case .invalid: return "doesn't work"
        case .rateLimited: return "rate limited"
        case .validating: return "checking"
        case .unknown: return "not checked"
        }
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
    @ObservedObject private var activity = APIActivity.shared
    @State private var confirmingReset = false
    /// Open on a demo screen (`DemoMode`)
    @State private var showingEndpoints = DemoMode.screen == "endpoints" || DemoMode.screen == "endpoint"
    @State private var showingResponsesEndpoint = DemoMode.screen == "endpoint"

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    EndpointsView(settings: viewModel)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Endpoints", systemImage: "point.3.connected.trianglepath.dotted")
                        Text(endpointsSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Label("APIs", systemImage: "network")
            } footer: {
                Text("Every OpenAI and Pinecone endpoint OpenCone calls: what each is for, the settings that shape it, and how its requests went.")
            }

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
            } header: {
                Label("Uploads", systemImage: "square.and.arrow.up.on.square")
            } footer: {
                Text("Documents are embedded with this model. Questions use the model that built each index once OpenCone has checked it.")
            }

            Section {
                Picker("Cloud", selection: $viewModel.pineconeCloud) {
                    ForEach(viewModel.availableClouds, id: \.self) { cloud in
                        Text(cloud.uppercased()).tag(cloud)
                    }
                }
                Picker("Region", selection: $viewModel.pineconeRegion) {
                    ForEach(viewModel.availableRegions, id: \.self) { region in
                        Text(region).tag(region)
                    }
                }
                Picker("Metric", selection: $viewModel.newIndexMetric) {
                    ForEach(viewModel.availableMetrics, id: \.self) { metric in
                        Text(metric).tag(metric)
                    }
                }
                Picker("Dimensions", selection: $viewModel.embeddingDimension) {
                    Text("1536").tag(1536)
                    Text("3072").tag(3072)
                }
            } header: {
                Label("New indexes", systemImage: "plus.square.on.square")
            } footer: {
                Text(NewIndexText.footer)
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
                    versionField(PineconeAPIVersions.controlPlane, text: $viewModel.pineconeControlPlaneVersion)
                }
                LabeledContent("Data plane") {
                    versionField(PineconeAPIVersions.dataPlane, text: $viewModel.pineconeDataPlaneVersion)
                }
                LabeledContent("Namespaces") {
                    versionField(PineconeAPIVersions.namespaces, text: $viewModel.pineconeNamespaceVersion)
                }
            } header: {
                Label("Pinecone API versions", systemImage: "number")
            } footer: {
                Text("Change these only to follow a Pinecone API change; Endpoints shows which endpoints each one covers. They're used after you reopen OpenCone. Pinecone's latest stable version is \(PineconeAPIVersions.latestStable).")
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
        .navigationDestination(isPresented: $showingEndpoints) {
            EndpointsView(settings: viewModel)
                .navigationDestination(isPresented: $showingResponsesEndpoint) {
                    EndpointDetailView(endpoint: .responses, settings: viewModel)
                }
        }
    }

    private var endpointsSubtitle: String {
        let count = activity.calls.count
        let failed = activity.calls.filter { !$0.succeeded }.count
        let endpoints = "\(APIEndpoint.allCases.count) endpoints"
        guard count > 0 else { return "\(endpoints), no requests yet" }
        return failed > 0
            ? "\(endpoints), \(count) requests, \(failed) didn't work"
            : "\(endpoints), \(count) requests"
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
