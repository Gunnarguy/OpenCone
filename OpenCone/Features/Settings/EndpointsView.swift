import SwiftUI

/// Every endpoint OpenCone calls, OpenAI's and Pinecone's alike: what each is for, the settings
/// that shape it, its API version, and how its requests have gone since OpenCone opened
struct EndpointsView: View {
    @ObservedObject var settings: SettingsViewModel
    @ObservedObject private var activity = APIActivity.shared

    var body: some View {
        List {
            Section {
                ActivitySummary(calls: activity.calls)
            } footer: {
                Text("Counted on this iPhone while OpenCone is open. Each record keeps the endpoint, its status and how long it took: no addresses, questions, passages or keys.")
            }

            ForEach(APIService.allCases) { service in
                Section {
                    ForEach(APIEndpoint.endpoints(of: service)) { endpoint in
                        NavigationLink {
                            EndpointDetailView(endpoint: endpoint, settings: settings)
                        } label: {
                            EndpointRow(endpoint: endpoint, lastCall: activity.lastCall(to: endpoint))
                        }
                    }
                } header: {
                    Label(service.title, systemImage: service.systemImage)
                } footer: {
                    Text(footer(for: service))
                }
            }
        }
        .navigationTitle("Endpoints")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !activity.calls.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear", action: activity.clear)
                }
            }
        }
    }

    private func footer(for service: APIService) -> String {
        switch service {
        case .openAI:
            return "\(service.host), with your OpenAI key."
        case .openAIDocs:
            return "\(service.host): public pages, read without a key."
        case .pineconeControl:
            return "\(service.host), with your Pinecone key. API version \(settings.pineconeControlPlaneVersion)."
        case .pineconeInference:
            return "\(service.host), with your Pinecone key. API version \(settings.pineconeControlPlaneVersion), the control plane's."
        case .pineconeIndex:
            return "Each index has its own host, which Describe an index returns. API versions: data plane \(settings.pineconeDataPlaneVersion), namespaces \(settings.pineconeNamespaceVersion)."
        }
    }
}

// MARK: - Rows

/// An endpoint's name, request line and last result
private struct EndpointRow: View {
    let endpoint: APIEndpoint
    let lastCall: APICall?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(endpoint.title)
                Spacer(minLength: 8)
                LastCallText(call: lastCall)
            }
            HStack(spacing: 6) {
                MethodBadge(method: endpoint.method)
                Text(endpoint.path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// "200 · 4 min. ago", colored by how it went, or "Not yet"
private struct LastCallText: View {
    let call: APICall?

    var body: some View {
        if let call {
            HStack(spacing: 4) {
                Circle()
                    .fill(call.statusColor)
                    .frame(width: 7, height: 7)
                Text("\(call.statusText) · \(call.date, format: .relative(presentation: .numeric, unitsStyle: .abbreviated))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("Not yet")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

/// GET, POST or DELETE in a small capsule
struct MethodBadge: View {
    let method: String

    var body: some View {
        Text(method)
            .font(.system(.caption2, design: .monospaced).weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .accessibilityLabel(method)
    }

    private var color: Color {
        switch method {
        case "GET": return .green
        case "DELETE": return .red
        default: return .blue
        }
    }
}

/// How the requests since launch went, in three numbers
private struct ActivitySummary: View {
    let calls: [APICall]

    var body: some View {
        HStack(spacing: 0) {
            stat("\(calls.count)", calls.count == 1 ? "request" : "requests")
            Divider().frame(height: 32)
            stat("\(failures)", "didn't work", tint: failures > 0 ? .red : nil)
            Divider().frame(height: 32)
            stat(typicalTime, "typical time")
        }
        .padding(.vertical, 4)
    }

    private var failures: Int {
        calls.filter { !$0.succeeded }.count
    }

    /// The median duration
    private var typicalTime: String {
        let durations = calls.map(\.duration).sorted()
        guard !durations.isEmpty else { return "–" }
        return APICall.durationText(durations[durations.count / 2])
    }

    private func stat(_ value: String, _ label: String, tint: Color? = nil) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint ?? Color.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

extension APICall {
    var statusText: String {
        status.map(String.init) ?? "No reply"
    }

    var statusColor: Color {
        guard let status else { return .gray }
        switch status {
        case 200..<300: return .green
        case 429: return .orange
        default: return .red
        }
    }

    static func durationText(_ seconds: TimeInterval) -> String {
        seconds < 1 ? "\(Int((seconds * 1000).rounded())) ms" : String(format: "%.1f s", seconds)
    }
}

// MARK: - Detail

/// One endpoint: what it does, the settings that shape it (changeable here), and its recent requests
struct EndpointDetailView: View {
    let endpoint: APIEndpoint
    @ObservedObject var settings: SettingsViewModel
    @ObservedObject private var activity = APIActivity.shared

    var body: some View {
        Form {
            Section {
                Text(endpoint.purpose)
                LabeledContent("Request") {
                    HStack(spacing: 6) {
                        MethodBadge(method: endpoint.method)
                        Text(endpoint.path)
                            .font(.system(.subheadline, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                LabeledContent("Host", value: endpoint.service.host)
                if let group = endpoint.pineconeVersionGroup {
                    LabeledContent("API version") {
                        TextField(PineconeAPIVersions.default(for: group), text: versionBinding(group))
                            .multilineTextAlignment(.trailing)
                            .font(.body.monospacedDigit())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.numbersAndPunctuation)
                    }
                }
            } header: {
                Label(endpoint.service.title, systemImage: endpoint.service.systemImage)
            } footer: {
                if let group = endpoint.pineconeVersionGroup {
                    Text("Sent as X-Pinecone-Api-Version, the \(group.title.lowercased()) setting, which every endpoint in that group shares. A change applies after you reopen OpenCone. Pinecone's latest stable version is \(PineconeAPIVersions.latestStable).")
                }
            }

            EndpointSettingsSections(endpoint: endpoint, settings: settings)

            Section {
                let recent = Array(activity.calls(to: endpoint).suffix(25).reversed())
                if recent.isEmpty {
                    Text("None since OpenCone opened")
                        .foregroundStyle(.secondary)
                }
                ForEach(recent) { call in
                    HStack {
                        Circle()
                            .fill(call.statusColor)
                            .frame(width: 8, height: 8)
                        Text(call.statusText)
                            .font(.body.monospacedDigit())
                        Spacer()
                        Text(APICall.durationText(call.duration))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(call.date, format: .dateTime.hour().minute().second())
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Label("Recent requests", systemImage: "clock.arrow.circlepath")
            }
        }
        .navigationTitle(endpoint.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func versionBinding(_ group: PineconeVersionGroup) -> Binding<String> {
        switch group {
        case .controlPlane: return $settings.pineconeControlPlaneVersion
        case .dataPlane: return $settings.pineconeDataPlaneVersion
        case .namespaces: return $settings.pineconeNamespaceVersion
        }
    }
}

extension PineconeAPIVersions {
    static func `default`(for group: PineconeVersionGroup) -> String {
        switch group {
        case .controlPlane: return controlPlane
        case .dataPlane: return dataPlane
        case .namespaces: return namespaces
        }
    }
}

/// The settings that shape an endpoint's requests, where it has any
private struct EndpointSettingsSections: View {
    let endpoint: APIEndpoint
    @ObservedObject var settings: SettingsViewModel
    @State private var checkingModels = false

    var body: some View {
        switch endpoint {
        case .responses: responses
        case .embeddings: embeddings
        case .models: models
        case .createIndex: createIndex
        case .rerank: rerank
        case .sparseEmbed: sparse
        case .query: query
        case .upsert: upsert
        default: EmptyView()
        }
    }

    private var responses: some View {
        Section {
            LabeledContent("Model", value: settings.completionModel)
            if settings.isReasoning {
                LabeledContent("Reasoning effort", value: ReasoningEffortText.long(settings.reasoningEffort))
            } else {
                LabeledContent("Temperature", value: String(format: "%.2f", settings.temperature))
                LabeledContent("Top P", value: String(format: "%.2f", settings.topP))
            }
            LabeledContent("Longest answer", value: AnswerSettingsForm.lengthName(settings.maxOutputTokens, model: settings.completionModel))
            if settings.supportsVerbosity {
                LabeledContent("Detail", value: AnswerOptionText.verbosity(settings.verbosity))
            }
            LabeledContent("Service tier", value: AnswerOptionText.serviceTier(settings.serviceTier))
            LabeledContent("Web search", value: webSearchSummary)
            LabeledContent("Code interpreter", value: settings.supportsCodeInterpreter ? (settings.codeInterpreterEnabled ? "On" : "Off") : "Not with this model")
            LabeledContent("Earlier exchanges", value: settings.historyExchanges == 0 ? "Off" : "\(settings.historyExchanges)")
            LabeledContent("Custom instructions", value: settings.systemPromptOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "None" : "Yours")
            NavigationLink("Change answer settings") {
                AnswerSettingsForm(settings: settings)
                    .navigationTitle("Answer settings")
                    .navigationBarTitleDisplayMode(.inline)
            }
        } header: {
            Label("What shapes it", systemImage: "slider.horizontal.3")
        } footer: {
            Text("Answers stream as they're written; when 30 seconds pass with no text, the same request is made once without streaming. Requests go with store: false, so OpenAI keeps no conversation between questions. Auto's choice of where to search uses this model with a short limit of its own; index summaries use \(CurrentModelCatalog.utilityModel).")
        }
    }

    private var webSearchSummary: String {
        guard settings.webSearchEnabled else { return "Off" }
        let sites = settings.webSearchDomainList
        let reads = AnswerOptionText.searchContext(settings.webSearchContextSize).lowercased()
        return sites.isEmpty ? "On, \(reads) results" : "On, \(sites.count) site\(sites.count == 1 ? "" : "s")"
    }

    private var embeddings: some View {
        Section {
            Picker("Uploads use", selection: $settings.embeddingModel) {
                ForEach(settings.availableEmbeddingModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            Picker("New indexes", selection: $settings.embeddingDimension) {
                Text("1536 dimensions").tag(1536)
                Text("3072 dimensions").tag(3072)
            }
            LabeledContent("Passages per request", value: "\(EmbeddingService.batchSize)")
        } header: {
            Label("What shapes it", systemImage: "slider.horizontal.3")
        } footer: {
            Text("A question is embedded with the model that built the index it searches, once OpenCone has checked which that is, so the two match.")
        }
    }

    private var models: some View {
        Section {
            LabeledContent("Newer models found", value: "\(settings.accountModels.count)")
            Button {
                checkingModels = true
                Task {
                    await settings.refreshAccountModels()
                    checkingModels = false
                }
            } label: {
                HStack {
                    Label("Check now", systemImage: "arrow.clockwise")
                    if checkingModels {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(checkingModels || DemoMode.isActive)
        } header: {
            Label("What shapes it", systemImage: "slider.horizontal.3")
        } footer: {
            Text("OpenCone checks once per launch. A model your key can use that the app's list doesn't know joins the model menu, and a retired model is replaced.")
        }
    }

    private var createIndex: some View {
        Section {
            Picker("Cloud", selection: $settings.pineconeCloud) {
                ForEach(settings.availableClouds, id: \.self) { cloud in
                    Text(cloud.uppercased()).tag(cloud)
                }
            }
            Picker("Region", selection: $settings.pineconeRegion) {
                ForEach(settings.availableRegions, id: \.self) { region in
                    Text(region).tag(region)
                }
            }
            Picker("Metric", selection: $settings.newIndexMetric) {
                ForEach(settings.availableMetrics, id: \.self) { metric in
                    Text(metric).tag(metric)
                }
            }
            Picker("Dimensions", selection: $settings.embeddingDimension) {
                Text("1536").tag(1536)
                Text("3072").tag(3072)
            }
        } header: {
            Label("New indexes", systemImage: "slider.horizontal.3")
        } footer: {
            Text(NewIndexText.footer)
        }
    }

    private var rerank: some View {
        Section {
            Toggle("Rerank results", isOn: $settings.rerankingEnabled)
            Picker("Reranker", selection: $settings.rerankModel) {
                ForEach(settings.availableRerankModels, id: \.self) { model in
                    Text(AnswerSettingsForm.rerankerName(model)).tag(model)
                }
            }
            Stepper(value: $settings.rerankTopN, in: 1...20) {
                LabeledContent("Keep the best", value: "\(settings.rerankTopN)")
            }
        } header: {
            Label("What shapes it", systemImage: "slider.horizontal.3")
        } footer: {
            Text("Pinecone reads each passage beside the question and reorders them by how well each answers it.")
        }
    }

    private var sparse: some View {
        Section {
            Toggle("Hybrid search", isOn: $settings.hybridSearchEnabled)
            if settings.hybridSearchEnabled {
                SliderRow(
                    title: "Balance",
                    value: $settings.hybridSearchAlpha,
                    range: 0...1,
                    step: 0.1,
                    format: { $0 < 0.3 ? "Keywords" : ($0 > 0.7 ? "Meaning" : "Even") },
                    caption: "Left favors exact keywords, right favors meaning."
                )
            }
            LabeledContent("Model", value: "pinecone-sparse-english-v0")
        } header: {
            Label("What shapes it", systemImage: "slider.horizontal.3")
        } footer: {
            Text("Used only on indexes with the dotproduct metric, which can hold keyword vectors beside meaning vectors.")
        }
    }

    private var query: some View {
        Section {
            Picker("Search width", selection: $settings.searchScope) {
                ForEach(SearchScope.allCases, id: \.self) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            Stepper(value: $settings.defaultTopK, in: 1...30) {
                LabeledContent("Passages per search", value: "\(settings.defaultTopK)")
            }
            LabeledContent("Default metadata filters", value: settings.metadataPresets.isEmpty ? "None" : "\(settings.metadataPresets.count)")
        } header: {
            Label("What shapes it", systemImage: "slider.horizontal.3")
        } footer: {
            Text(settings.searchScope.explanation)
        }
    }

    private var upsert: some View {
        Section {
            ForEach(TextProcessorService.chunkProfiles + [TextProcessorService.otherChunkProfile], id: \.kind) { profile in
                LabeledContent(profile.kind, value: "\(profile.size.formatted()) · \(profile.overlap)")
            }
            LabeledContent("Vectors per request", value: "\(PineconeService.upsertBatchSize)")
        } header: {
            Label("How documents are split", systemImage: "scissors")
        } footer: {
            Text("Passage sizes are in characters, with the overlap each shares with the next. They're set by file type and can't be changed yet.")
        }
    }
}

/// Words for the answer options, shared by the form and the Endpoints screen
enum AnswerOptionText {
    static func verbosity(_ value: String) -> String {
        switch value {
        case "low": return "Concise"
        case "high": return "Detailed"
        default: return "Medium"
        }
    }

    static func serviceTier(_ value: String) -> String {
        switch value {
        case "default": return "Standard"
        case "flex": return "Flex"
        case "fast": return "Fast"
        default: return "Auto"
        }
    }

    static func searchContext(_ value: String) -> String {
        switch value {
        case "low": return "Fewer"
        case "high": return "More"
        default: return "Medium"
        }
    }
}

enum NewIndexText {
    static let footer = "Pinecone's Starter plan creates indexes in AWS us-east-1 only. Hybrid search needs dotproduct. An index keeps its cloud, region, metric and dimensions for good."
}
