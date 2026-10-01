import SwiftUI

// MARK: - Model picker

/// Every model the app offers, with what each is for, as OpenResponses' "Choose Model" lists
/// them; any other model ID can be typed in
struct ModelPickerList: View {
    @ObservedObject var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var customModel = ""

    private var filtered: [String] {
        settings.availableCompletionModels.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            let current = filtered.filter { CurrentModelCatalog.isModern($0) }
            let other = filtered.filter { !CurrentModelCatalog.isModern($0) }

            if !current.isEmpty {
                Section("Current models") {
                    ForEach(current, id: \.self, content: row)
                }
            }
            if !other.isEmpty {
                Section("Other supported models") {
                    ForEach(other, id: \.self, content: row)
                }
            }
            Section {
                TextField("Enter a model or snapshot ID", text: $customModel)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(useCustomModel)
                Button("Use model ID", action: useCustomModel)
                    .disabled(customModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: {
                Text("Model ID")
            } footer: {
                Text("Any model your OpenAI account can use with the Responses API. A model the app doesn't know is sent with medium reasoning effort.")
            }
        }
        .searchable(text: $search, prompt: "Find a model")
        .navigationTitle("Choose Model")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ model: String) -> some View {
        ModelPickerRow(
            modelId: model,
            description: CurrentModelCatalog.description(for: model),
            isSelected: settings.completionModel == model
        ) {
            settings.selectCompletionModel(model)
            dismiss()
        }
    }

    private func useCustomModel() {
        let trimmed = customModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        settings.selectCompletionModel(trimmed)
        dismiss()
    }
}

/// Ported from OpenResponses (Features/Chat/Components/DynamicModelSelector.swift, 2026-10-01)
struct ModelPickerRow: View {
    let modelId: String
    let description: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(modelId)
                        .font(.body)
                        .foregroundStyle(Color.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.blue)
                        .font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(CurrentModelCatalog.spokenName(for: modelId))
        .accessibilityValue(description)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Answer settings

/// How answers are written: the model and its parameters, the request options, tools, retrieval,
/// custom instructions and memory. One form, shown from the gear above the conversation and in Settings.
struct AnswerSettingsForm: View {
    @ObservedObject var settings: SettingsViewModel
    @State private var confirmingReset = false

    var body: some View {
        Form {
            modelSection
            answerSection
            toolsSection
            retrievalSection
            instructionsSection
            memorySection

            Section {
                Button("Reset answer settings", role: .destructive) {
                    confirmingReset = true
                }
            } footer: {
                Text("Puts everything above back to its default except the model.")
            }
        }
        .confirmationDialog("Reset answer settings?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive, action: settings.resetAnswerSettings)
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Model

    private var modelSection: some View {
        Section {
            NavigationLink {
                ModelPickerList(settings: settings)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(settings.completionModel)
                            .font(.body.weight(.medium))
                        Text(CurrentModelCatalog.description(for: settings.completionModel))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ModelLimitChips(model: settings.completionModel)
                }
                .padding(.vertical, 2)
            }
            .accessibilityLabel("Model, \(CurrentModelCatalog.spokenName(for: settings.completionModel))")

            if settings.isReasoning {
                Picker("Reasoning effort", selection: $settings.reasoningEffort) {
                    ForEach(settings.availableReasoningEffortOptions, id: \.self) { level in
                        Text(ReasoningEffortText.long(level)).tag(level)
                    }
                }
            } else {
                SliderRow(
                    title: "Temperature",
                    value: $settings.temperature,
                    range: 0...2,
                    step: 0.05,
                    format: { String(format: "%.2f", $0) },
                    caption: "Lower is focused and repeatable, higher is varied."
                )
                SliderRow(
                    title: "Top P",
                    value: $settings.topP,
                    range: 0...1,
                    step: 0.05,
                    format: { String(format: "%.2f", $0) },
                    caption: "Nucleus sampling, an alternative to temperature."
                )
            }
        } header: {
            Label("Model", systemImage: "cpu")
        } footer: {
            Text(modelFooter)
        }
    }

    private var modelFooter: String {
        guard settings.isReasoning else {
            return "\(settings.completionModel) doesn't reason, so temperature and Top P shape its answers."
        }
        let efforts = settings.availableReasoningEffortOptions
        var text = "More effort means the model thinks longer before it answers: slower, and usually better on hard questions."
        if let lowest = efforts.first, let highest = efforts.last {
            text += " \(settings.completionModel) takes \(ReasoningEffortText.short(lowest)) to \(ReasoningEffortText.short(highest))"
            text += efforts.contains("none") ? "." : "; it always reasons, so it has no Off."
        }
        return text
    }

    // MARK: Answer

    private var answerSection: some View {
        Section {
            Picker("Longest answer", selection: $settings.maxOutputTokens) {
                ForEach(settings.answerLengthChoices, id: \.self) { tokens in
                    Text(Self.lengthName(tokens, model: settings.completionModel)).tag(tokens)
                }
            }

            if settings.supportsVerbosity {
                Picker("Detail", selection: $settings.verbosity) {
                    Text("Concise").tag("low")
                    Text("Medium").tag("medium")
                    Text("Detailed").tag("high")
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Detail")
            }

            Picker("Service tier", selection: $settings.serviceTier) {
                ForEach(settings.availableServiceTiers, id: \.self) { tier in
                    Text(AnswerOptionText.serviceTier(tier)).tag(tier)
                }
            }
        } header: {
            Label("Answer", systemImage: "text.alignleft")
        } footer: {
            Text(answerFooter)
        }
    }

    private var answerFooter: String {
        let limit = ModelLimits.maxOutputTokens(for: settings.completionModel)
        var text = settings.isReasoning
            ? "The longest answer includes the model's reasoning; \(settings.completionModel) writes up to \(limit.formatted()) tokens."
            : "\(settings.completionModel) writes up to \(limit.formatted()) tokens in one answer."
        if settings.isReasoning, settings.reasoningEffort != "none", settings.maxOutputTokens < 8_000 {
            text += " With reasoning on, a short limit can run out before the answer starts."
        }
        switch settings.serviceTier {
        case "flex":
            text += " Flex costs half as much and answers slower; when OpenAI is busy it turns a question away, without charging for it."
        case "fast":
            text += " Fast answers up to 2.5 times quicker for a higher price per token: twice Standard on the GPT-6 models."
        case "default":
            text += " Standard is OpenAI's usual speed and price."
        default:
            text += " Auto uses your OpenAI project's tier, which is Standard unless you changed it."
        }
        let tiers = settings.availableServiceTiers
        if !tiers.contains("flex") || !tiers.contains("fast") {
            let missing = ["flex", "fast"].filter { !tiers.contains($0) }.map(AnswerOptionText.serviceTier)
            text += " OpenAI doesn't offer \(missing.joined(separator: " or ")) for \(settings.completionModel)."
        }
        return text
    }

    /// "16K tokens", with the model's own limit marked
    static func lengthName(_ tokens: Int, model: String) -> String {
        let name = "\(ModelLimits.shortCount(tokens)) tokens"
        return tokens == ModelLimits.maxOutputTokens(for: model) ? "\(name), the most" : name
    }

    // MARK: Tools

    private var toolsSection: some View {
        Section {
            Toggle(isOn: $settings.webSearchEnabled) {
                Label("Web search", systemImage: "globe")
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))

            if settings.webSearchEnabled {
                Picker("Results read", selection: $settings.webSearchContextSize) {
                    Text("Fewer").tag("low")
                    Text("Medium").tag("medium")
                    Text("More").tag("high")
                }
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Only these sites (any site when empty)", text: $settings.webSearchDomains, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .lineLimit(1...4)
                    if !settings.webSearchDomainList.isEmpty {
                        Text(settings.webSearchDomainList.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if settings.supportsCodeInterpreter {
                Toggle(isOn: $settings.codeInterpreterEnabled) {
                    Label("Code interpreter", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .toggleStyle(SwitchToggleStyle(tint: .orange))
            } else {
                LabeledContent {
                    Text("Not with this model")
                } label: {
                    Label("Code interpreter", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .foregroundStyle(.secondary)
            }
        } header: {
            Label("Tools", systemImage: "wrench.and.screwdriver")
        } footer: {
            Text(settings.webSearchEnabled
                 ? "Web search lets the model add current information from the internet. Results read sets how much of what it finds goes into the answer: more can help, and costs more tokens. Sites are separated by commas, and their subdomains count too. Code interpreter runs Python for questions that ask for charts, tables or calculations."
                 : "Web search lets the model add current information from the internet. Code interpreter runs Python for questions that ask for charts, tables or calculations.")
        }
    }

    // MARK: Retrieval

    private var retrievalSection: some View {
        Section {
            Stepper(value: $settings.defaultTopK, in: 1...30) {
                LabeledContent("Passages per search", value: "\(settings.defaultTopK)")
            }

            Toggle(isOn: $settings.rerankingEnabled) {
                Text("Rerank results")
            }
            .toggleStyle(SwitchToggleStyle(tint: .purple))

            if settings.rerankingEnabled {
                Picker("Reranker", selection: $settings.rerankModel) {
                    ForEach(settings.availableRerankModels, id: \.self) { model in
                        Text(Self.rerankerName(model)).tag(model)
                    }
                }
                Stepper(value: $settings.rerankTopN, in: 1...20) {
                    LabeledContent("Keep the best", value: "\(settings.rerankTopN)")
                }
            }

            Toggle(isOn: $settings.hybridSearchEnabled) {
                Text("Hybrid search")
            }
            .toggleStyle(SwitchToggleStyle(tint: .indigo))

            if settings.hybridSearchEnabled, settings.indexSupportsHybridSearch {
                SliderRow(
                    title: "Balance",
                    value: $settings.hybridSearchAlpha,
                    range: 0...1,
                    step: 0.1,
                    format: { $0 < 0.3 ? "Keywords" : ($0 > 0.7 ? "Meaning" : "Even") },
                    caption: "Left favors exact keywords, right favors meaning."
                )
            }
        } header: {
            Label("Retrieval", systemImage: "magnifyingglass")
        } footer: {
            Text(retrievalFooter)
        }
    }

    private var retrievalFooter: String {
        var text = "Reranking has Pinecone reorder the passages found by how well each answers the question."
        if settings.hybridSearchEnabled, let reason = settings.hybridSearchDisabledReason {
            text += " Hybrid search mixes keyword and meaning matches; it needs an index with the dotproduct metric (\(reason.lowercased()))."
        } else {
            text += " Hybrid search mixes keyword and meaning matches on indexes with the dotproduct metric."
        }
        return text
    }

    static func rerankerName(_ model: String) -> String {
        switch model {
        case "bge-reranker-v2-m3": return "BGE Reranker v2 M3"
        case "cohere-rerank-3.5": return "Cohere Rerank 3.5"
        case "pinecone-rerank-v0": return "Pinecone Rerank v0"
        default: return model
        }
    }

    // MARK: Instructions

    private var instructionsSection: some View {
        Section {
            TextField("For example: answer in short bullet points", text: $settings.systemPromptOverride, axis: .vertical)
                .lineLimit(3...8)
        } header: {
            Label("Custom instructions", systemImage: "text.quote")
        } footer: {
            Text("Added to OpenCone's own instructions for every answer.")
        }
    }

    // MARK: Memory

    private var memorySection: some View {
        Section {
            Stepper(value: $settings.historyExchanges, in: 0...RequestSettings.maxHistoryExchanges) {
                LabeledContent("Earlier exchanges", value: settings.historyExchanges == 0 ? "Off" : "\(settings.historyExchanges)")
            }
        } header: {
            Label("Memory", systemImage: "bubble.left.and.bubble.right")
        } footer: {
            Text(memoryFooter)
        }
    }

    private var memoryFooter: String {
        let exchanges = settings.historyExchanges
        guard exchanges > 0 else {
            return "Each question goes on its own, so a follow-up doesn't see earlier answers."
        }
        var text = "Each question carries your last \(exchanges == 1 ? "exchange" : "\(exchanges) exchanges") from this iPhone, so a follow-up sees them. OpenAI keeps nothing between questions, and New chat starts fresh."
        if let window = ModelLimits.contextWindow(for: settings.completionModel) {
            text += " \(settings.completionModel) reads \(window.formatted()) tokens at once; when the passages, your question and these exchanges would pass that, the oldest exchanges are left out."
        }
        return text
    }
}

/// What a model writes and reads at most, as two small capsules under its name
struct ModelLimitChips: View {
    let model: String

    var body: some View {
        HStack(spacing: 6) {
            chip("Writes \(ModelLimits.shortCount(ModelLimits.maxOutputTokens(for: model)))", systemImage: "square.and.pencil")
            if let window = ModelLimits.contextWindow(for: model) {
                chip("Reads \(ModelLimits.shortCount(window))", systemImage: "text.book.closed")
            }
            if Configuration.isReasoningModel(model) {
                chip("Reasons", systemImage: "brain")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func chip(_ text: String, systemImage: String) -> some View {
        // An HStack, not a Label: a Label in a list row takes the row's wide icon column
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .imageScale(.small)
            Text(text)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
    }
}

/// A labelled slider with its value on the right, as in OpenResponses' settings panel
struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String
    let caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value))
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue(format(value))
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

/// The answer settings as a sheet from the gear above the conversation
struct AnswerSettingsPanel: View {
    @ObservedObject var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AnswerSettingsForm(settings: settings)
                .navigationTitle("Answer settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            settings.persistRequestSettings()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
        }
        .onDisappear(perform: settings.persistRequestSettings)
    }
}
