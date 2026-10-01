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

/// How answers are written: the model and its parameters, tools, retrieval, custom instructions
/// and memory. One form, shown from the gear above the conversation and in Settings.
struct AnswerSettingsForm: View {
    @ObservedObject var settings: SettingsViewModel
    @State private var confirmingReset = false

    var body: some View {
        Form {
            modelSection
            lengthSection
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.completionModel)
                    Text(CurrentModelCatalog.description(for: settings.completionModel))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
            Text(settings.isReasoning
                 ? "More effort means the model thinks longer before it answers: slower, and usually better on hard questions."
                 : "This model has no reasoning effort, so temperature and Top P shape its answers.")
        }
    }

    // MARK: Length

    private var lengthSection: some View {
        Section {
            SliderRow(
                title: "Longest answer",
                value: Binding(
                    get: { Double(settings.maxOutputTokens) },
                    set: { settings.maxOutputTokens = Int($0) }
                ),
                range: 500...32_000,
                step: 500,
                format: { "\(Int($0).formatted()) tokens" },
                caption: nil
            )
        } header: {
            Label("Answer length", systemImage: "text.alignleft")
        } footer: {
            Text("The most the model may write for one answer, its reasoning included. An answer that reaches it stops there.")
        }
    }

    // MARK: Tools

    private var toolsSection: some View {
        Section {
            Toggle(isOn: $settings.webSearchEnabled) {
                Label("Web search", systemImage: "globe")
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))

            Toggle(isOn: $settings.codeInterpreterEnabled) {
                Label("Code interpreter", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .toggleStyle(SwitchToggleStyle(tint: .orange))
        } header: {
            Label("Tools", systemImage: "wrench.and.screwdriver")
        } footer: {
            Text("Web search lets the model add current information from the internet. Code interpreter runs Python for questions that ask for charts, tables or calculations.")
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
            Picker("Conversation memory", selection: $settings.conversationMode) {
                Text("Kept by OpenAI").tag("server")
                Text("Sent from this iPhone").tag("client")
            }
        } header: {
            Label("Memory", systemImage: "bubble.left.and.bubble.right")
        } footer: {
            Text(settings.conversationMode == "server"
                 ? "OpenAI keeps the conversation, so a follow-up question sees the earlier ones. New chat starts a fresh one."
                 : "Each question carries the last 4 exchanges from this iPhone, and OpenAI keeps no conversation between questions.")
        }
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
