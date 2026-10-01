import SwiftUI

/// What OpenCone tells the model about each index when it picks where to search. Each summary is
/// drafted from a sample of the index's passages, and the person can rewrite it here.
struct IndexSummariesSheet: View {
    @ObservedObject var viewModel: SearchViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    /// Edits not yet saved, by index name
    @State private var edits: [String: String] = [:]
    @State private var redrafting: Set<String> = []

    private var profiles: [IndexProfile] {
        viewModel.pineconeIndexes.compactMap { viewModel.indexProfiles[$0] }
    }

    private var waiting: [String] {
        viewModel.pineconeIndexes.filter { viewModel.indexProfiles[$0] == nil }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("OpenCone describes each index to the model so it can choose where to search. Each summary is drafted from a sample of the index's passages. Rewrite one to make it more precise.")
                        .font(.footnote)
                        .foregroundColor(theme.textSecondaryColor)
                }

                ForEach(profiles) { profile in
                    Section {
                        TextField("What this index holds", text: summaryBinding(for: profile), axis: .vertical)
                            .lineLimit(2...5)

                        modelStatus(for: profile)

                        Button {
                            redraft(profile.name)
                        } label: {
                            if redrafting.contains(profile.name) {
                                ProgressView()
                            } else {
                                Label("Draft again", systemImage: "wand.and.stars")
                            }
                        }
                        .disabled(redrafting.contains(profile.name) || profile.vectorCount == 0)
                    } header: {
                        Text(profile.name)
                    } footer: {
                        Text(details(for: profile))
                    }
                }

                if !waiting.isEmpty {
                    Section {
                        ForEach(waiting, id: \.self) { name in
                            HStack {
                                Text(name)
                                Spacer()
                                if viewModel.isSurveyingIndexes {
                                    ProgressView()
                                } else {
                                    Text("Not checked yet")
                                        .font(.caption)
                                        .foregroundColor(theme.textSecondaryColor)
                                }
                            }
                        }
                    } header: {
                        Text("Waiting for a first look")
                    }
                }
            }
            .navigationTitle("Index summaries")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        saveEdits()
                        viewModel.recheckIndexProfiles()
                    } label: {
                        Label("Check again", systemImage: "arrow.clockwise")
                    }
                    .disabled(viewModel.isSurveyingIndexes)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveEdits()
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.scheduleIndexSurvey()
            }
            .onDisappear {
                saveEdits()
            }
        }
    }

    // MARK: - Parts

    private func summaryBinding(for profile: IndexProfile) -> Binding<String> {
        Binding(
            get: { edits[profile.name] ?? profile.summary },
            set: { edits[profile.name] = $0 }
        )
    }

    @ViewBuilder
    private func modelStatus(for profile: IndexProfile) -> some View {
        switch profile.modelCheck {
        case .matched:
            Label {
                if let similarity = profile.modelSimilarity {
                    Text("Searched with \(profile.embeddingModel ?? "its model") (match \(String(format: "%.3f", similarity)))")
                } else {
                    Text("Searched with \(profile.embeddingModel ?? "its model")")
                }
            } icon: {
                Image(systemName: "checkmark.seal")
                    .foregroundColor(theme.successColor)
            }
            .font(.caption)
        case .noMatch:
            Label {
                if let similarity = profile.modelSimilarity {
                    Text("Not searchable: no OpenAI embedding model reproduced its stored vectors (best \(String(format: "%.3f", similarity)))")
                } else {
                    Text("Not searchable: no OpenAI embedding model reproduced its stored vectors")
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(theme.warningColor)
            }
            .font(.caption)
        case .noPassage:
            Label {
                Text("Not searchable: no passage with text came back to check its model")
            } icon: {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(theme.warningColor)
            }
            .font(.caption)
        case .notChecked:
            Label("Model not checked yet", systemImage: "clock")
                .font(.caption)
                .foregroundColor(theme.textSecondaryColor)
        }
    }

    private func details(for profile: IndexProfile) -> String {
        let namespaces = profile.namespaces.count == 1 ? "1 namespace" : "\(profile.namespaces.count) namespaces"
        let author: String
        switch profile.summarySource {
        case .person: author = "Summary written by you."
        case .drafted: author = "Summary drafted from its passages."
        case .missing: author = "No summary yet."
        }
        return "\(profile.dimension) dimensions, \(profile.metric), \(profile.vectorCount) passages in \(namespaces). \(author)"
    }

    private func saveEdits() {
        for (name, text) in edits {
            viewModel.updateIndexSummary(text, for: name)
        }
        edits.removeAll()
    }

    private func redraft(_ name: String) {
        edits[name] = nil
        redrafting.insert(name)
        Task {
            await viewModel.redraftIndexSummary(for: name)
            redrafting.remove(name)
        }
    }
}
