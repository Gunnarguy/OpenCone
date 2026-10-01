import SwiftUI

// MARK: - Scope text

extension SearchScope {
    var title: String {
        switch self {
        case .auto: return "Auto"
        case .everything: return "Everything"
        case .oneIndex: return "One index"
        }
    }

    var systemImage: String {
        switch self {
        case .auto: return "arrow.triangle.branch"
        case .everything: return "square.stack.3d.up"
        case .oneIndex: return "cylinder.split.1x2"
        }
    }

    /// What a question does under this scope, for the picker's footer
    var explanation: String {
        switch self {
        case .auto:
            return "OpenCone reads each question and searches the indexes and namespaces likely to hold the answer, up to \(IndexRouter.maxSearches) at once. Ask it to compare two and it searches both. Quick and focused."
        case .everything:
            return "Every question searches every namespace of every index below, each with the embedding model that built it, and keeps the best passages from all of them. The widest net: nothing is skipped, up to 20 searches a question, at the cost of more Pinecone reads."
        case .oneIndex:
            return "Every question searches the index you pick, in one namespace or in each of them."
        }
    }
}

// MARK: - Bar

/// Where the next question is searched, as a pill in the style of OpenResponses' vector store
/// toggle. Tapping it opens the sheet that changes it.
struct SearchScopeBar: View {
    @ObservedObject var viewModel: SearchViewModel
    @ObservedObject var settings: SettingsViewModel
    let onTap: () -> Void

    /// Auto and Everything reach across indexes; with one index left they act on its namespaces
    private var reachesAcrossIndexes: Bool {
        settings.searchScope != .oneIndex && viewModel.includedIndexes.count >= 2
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onTap) {
                HStack(spacing: 6) {
                    Image(systemName: settings.searchScope.systemImage)
                        .font(.caption)

                    Text(title)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)

                    if reachesAcrossIndexes {
                        Text("\(viewModel.includedIndexes.count) indexes")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple)
                            .clipShape(Capsule())
                            .fixedSize()
                    } else if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSearching)
            .accessibilityLabel("Where to search")
            .accessibilityValue(accessibilityValue)

            if !viewModel.metadataFilters.isEmpty {
                Button(action: onTap) {
                    HStack(spacing: 3) {
                        Image(systemName: "line.3.horizontal.decrease")
                        Text("\(viewModel.metadataFilters.count)")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(viewModel.metadataFilters.count) metadata filters")
            }

            Spacer(minLength: 0)

            if viewModel.isSurveyingIndexes {
                ProgressView()
                    .controlSize(.mini)
                    .accessibilityLabel("Checking your indexes")
            }
        }
    }

    private var title: String {
        if reachesAcrossIndexes { return settings.searchScope.title }
        if settings.searchScope == .oneIndex {
            return viewModel.selectedIndex ?? "Choose an index"
        }
        // Auto or Everything with one index left in: its name, and what happens to its namespaces
        return viewModel.includedIndexes.first ?? viewModel.selectedIndex ?? "Choose an index"
    }

    /// The namespace part, when the search stays in one index
    private var detail: String? {
        switch settings.searchScope {
        case .auto:
            return viewModel.namespaces.count > 1 ? "namespaces picked per question" : nil
        case .everything:
            return viewModel.namespaces.count > 1 ? "every namespace" : nil
        case .oneIndex:
            guard viewModel.selectedIndex != nil else { return nil }
            if let namespace = viewModel.selectedNamespace {
                return namespace.isEmpty ? "default namespace" : namespace
            }
            return viewModel.namespaces.count > 1 ? "all namespaces" : nil
        }
    }

    private var accessibilityValue: String {
        if reachesAcrossIndexes {
            switch settings.searchScope {
            case .everything:
                return "Everything: all \(viewModel.includedIndexes.count) indexes and their namespaces"
            default:
                return "Auto: picked from \(viewModel.includedIndexes.count) indexes for each question"
            }
        }
        return [title, detail].compactMap { $0 }.joined(separator: ", ")
    }
}

// MARK: - Sheet

/// Choose how widely questions are searched: picked per question (Auto), every namespace of
/// every index (Everything), or one index and one or all of its namespaces
struct SearchScopeSheet: View {
    @ObservedObject var viewModel: SearchViewModel
    @ObservedObject var settings: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Search", selection: $settings.searchScope) {
                        ForEach(SearchScope.allCases, id: \.self) { scope in
                            Text(scope.title).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } footer: {
                    Text(settings.searchScope.explanation)
                }

                if settings.searchScope == .oneIndex {
                    indexSection
                    namespaceSection
                } else {
                    allIndexesSection
                }

                Section {
                    NavigationLink {
                        MetadataFiltersView(viewModel: viewModel)
                    } label: {
                        LabeledContent {
                            Text(viewModel.metadataFilters.isEmpty ? "None" : "\(viewModel.metadataFilters.count)")
                        } label: {
                            Label("Metadata filters", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                } footer: {
                    if let index = viewModel.selectedIndex {
                        Text("Filters match fields of the passages in \(index), so they apply to its searches only.")
                    }
                }
            }
            .navigationTitle("Where to search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if settings.searchScope != .oneIndex {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            viewModel.recheckIndexProfiles()
                        } label: {
                            Label("Check again", systemImage: "arrow.clockwise")
                        }
                        .disabled(viewModel.isSurveyingIndexes)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                viewModel.scheduleIndexSurvey()
            }
            .onChange(of: settings.searchScope) { _, _ in
                settings.persistRequestSettings()
                viewModel.scheduleIndexSurvey()
                Task { await viewModel.scopeDidChange() }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // Opaque, like the full-height sheets: at the medium detent the default glass let the
        // conversation behind show through as a blurred band under the title
        .presentationBackground(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: All indexes

    private var allIndexesSection: some View {
        Section {
            ForEach(viewModel.pineconeIndexes, id: \.self) { name in
                NavigationLink {
                    IndexDetailView(viewModel: viewModel, name: name)
                } label: {
                    IndexRow(
                        name: name,
                        profile: viewModel.indexProfiles[name],
                        isChecking: viewModel.isSurveyingIndexes,
                        isLeftOut: viewModel.excludedIndexes.contains(name)
                    )
                }
            }
        } header: {
            Text("Indexes")
        } footer: {
            Text(settings.searchScope == .auto
                 ? "The model picks from these by a one-line summary of each, drafted from its passages. Open one to rewrite its summary or leave it out."
                 : "Open an index to leave it out of the search or to see what OpenCone knows about it.")
        }
    }

    // MARK: One index

    private var indexSection: some View {
        Section("Index") {
            ForEach(viewModel.pineconeIndexes, id: \.self) { name in
                Button {
                    Task { await viewModel.setIndex(name) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .foregroundStyle(Color.primary)
                            if let profile = viewModel.indexProfiles[name] {
                                Text("\(Self.passageCount(profile.vectorCount)) · \(Self.namespaceCount(profile.namespaces.count))")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        Spacer()
                        if viewModel.selectedIndex == name {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityAddTraits(viewModel.selectedIndex == name ? .isSelected : [])
            }
        }
    }

    @ViewBuilder
    private var namespaceSection: some View {
        if let index = viewModel.selectedIndex, !viewModel.namespaces.isEmpty {
            Section {
                if viewModel.namespaces.count > 1 {
                    namespaceRow(
                        title: "All namespaces",
                        detail: allNamespacesDetail,
                        isSelected: viewModel.selectedNamespace == nil
                    ) {
                        viewModel.setNamespace(nil)
                    }
                }
                ForEach(viewModel.namespaces, id: \.self) { namespace in
                    namespaceRow(
                        title: namespace.isEmpty ? "Default namespace" : namespace,
                        detail: viewModel.namespaceVectorCounts[namespace].map(Self.passageCount),
                        isSelected: viewModel.selectedNamespace == namespace
                            || (viewModel.namespaces.count == 1 && viewModel.selectedNamespace == nil)
                    ) {
                        viewModel.setNamespace(namespace)
                    }
                }
            } header: {
                Text("Namespace in \(index)")
            }
        }
    }

    private var allNamespacesDetail: String {
        let count = viewModel.namespaces.count
        let limit = viewModel.namespacesToSearch.count
        if viewModel.selectedNamespace == nil, limit < count {
            return "Searches the \(limit) largest of \(count)"
        }
        return "Searches each of the \(count)"
    }

    private func namespaceRow(title: String, detail: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(Color.primary)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    static func passageCount(_ count: Int) -> String {
        count == 1 ? "1 passage" : "\(count.formatted()) passages"
    }

    static func namespaceCount(_ count: Int) -> String {
        count == 1 ? "1 namespace" : "\(count) namespaces"
    }
}

/// An index in the list of everything a question can search: its summary and whether it can be
/// searched yet
private struct IndexRow: View {
    let name: String
    let profile: IndexProfile?
    let isChecking: Bool
    let isLeftOut: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(isLeftOut ? Color.secondary : Color.primary)
                if isLeftOut {
                    Text("Left out")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            if let profile, !profile.summary.isEmpty {
                Text(profile.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            status
                .font(.caption2)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var status: some View {
        if let profile {
            switch profile.modelCheck {
            case .matched where profile.vectorCount > 0:
                Label {
                    Text("\(SearchScopeSheet.passageCount(profile.vectorCount)) · \(profile.embeddingModel ?? "model known")")
                } icon: {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.green)
                }
                .foregroundStyle(.secondary)
            case .matched, .noPassage:
                Label("No passages to search yet", systemImage: "tray")
                    .foregroundStyle(.secondary)
            case .noMatch:
                Label("Can't be searched: no OpenAI model matches its vectors", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
            case .notChecked:
                Label("Not checked yet", systemImage: "clock")
                    .foregroundStyle(.secondary)
            }
        } else if isChecking {
            Label("Checking…", systemImage: "clock")
                .foregroundStyle(.secondary)
        } else {
            Label("Not checked yet", systemImage: "clock")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Index detail

/// One index as OpenCone describes it to the model: whether it's searched, its summary, the
/// embedding model that built it, and its namespaces
struct IndexDetailView: View {
    @ObservedObject var viewModel: SearchViewModel
    let name: String
    @State private var summary = ""
    @State private var loadedSummary = ""
    @State private var redrafting = false

    private var profile: IndexProfile? { viewModel.indexProfiles[name] }

    private var isIncluded: Binding<Bool> {
        Binding(
            get: { !viewModel.excludedIndexes.contains(name) },
            set: { included in Task { await viewModel.setIndex(name, included: included) } }
        )
    }

    private var isOnlyIncludedIndex: Bool {
        viewModel.includedIndexes == [name]
    }

    var body: some View {
        List {
            Section {
                Toggle("Search this index", isOn: isIncluded)
                    .disabled(isOnlyIncludedIndex && isIncluded.wrappedValue)
            } footer: {
                Text(isOnlyIncludedIndex
                     ? "At least one index stays in the search."
                     : "Left out, Auto and Everything don't search it. You can still pick it under One index.")
            }

            if let profile {
                Section {
                    TextField("What this index holds", text: $summary, axis: .vertical)
                        .lineLimit(2...6)
                    Button {
                        redraft()
                    } label: {
                        if redrafting {
                            ProgressView()
                        } else {
                            Label("Draft again from its passages", systemImage: "wand.and.stars")
                        }
                    }
                    .disabled(redrafting || profile.vectorCount == 0)
                } header: {
                    Text("Summary")
                } footer: {
                    Text(summaryFooter(profile))
                }

                Section("Embedding model") {
                    modelStatus(profile)
                }

                Section("Namespaces") {
                    ForEach(profile.namespaces, id: \.name) { namespace in
                        LabeledContent(
                            namespace.name.isEmpty ? "Default namespace" : namespace.name,
                            value: SearchScopeSheet.passageCount(namespace.vectorCount)
                        )
                    }
                }

                Section("Details") {
                    LabeledContent("Dimensions", value: "\(profile.dimension)")
                    LabeledContent("Metric", value: profile.metric)
                    LabeledContent("Checked") {
                        Text(profile.surveyedAt, style: .relative) + Text(" ago")
                    }
                }
            } else {
                Section {
                    Label("OpenCone hasn't looked at this index yet. It checks each index in the background; tap Check again in the list to start now.", systemImage: "clock")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            summary = profile?.summary ?? ""
            loadedSummary = summary
        }
        .onChange(of: profile?.summary) { _, newValue in
            // A redraft or survey replaced it; keep an edit in progress
            guard summary == loadedSummary, let newValue else { return }
            summary = newValue
            loadedSummary = newValue
        }
        .onDisappear(perform: saveSummary)
    }

    private func summaryFooter(_ profile: IndexProfile) -> String {
        let author: String
        switch profile.summarySource {
        case .person: author = "Written by you."
        case .drafted: author = "Drafted from a sample of its passages."
        case .missing: author = "No summary yet; OpenCone drafts one once the index has passages."
        }
        return "The model reads this line when it chooses where to search. \(author)"
    }

    @ViewBuilder
    private func modelStatus(_ profile: IndexProfile) -> some View {
        switch profile.modelCheck {
        case .matched:
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.embeddingModel ?? "Known model")
                    if let similarity = profile.modelSimilarity {
                        Text("Re-embedding a stored passage matched at \(String(format: "%.3f", similarity))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color.green)
            }
        case .noMatch:
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("No OpenAI embedding model reproduced its vectors, so questions can't be embedded to match it.")
                    if let similarity = profile.modelSimilarity {
                        Text("Best match \(String(format: "%.3f", similarity))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
            }
        case .noPassage:
            Label("No passage with text came back to check its model.", systemImage: "tray")
        case .notChecked:
            Label("Not checked yet", systemImage: "clock")
                .foregroundStyle(.secondary)
        }
    }

    private func saveSummary() {
        guard summary != loadedSummary else { return }
        viewModel.updateIndexSummary(summary, for: name)
        loadedSummary = summary
    }

    private func redraft() {
        redrafting = true
        Task {
            await viewModel.redraftIndexSummary(for: name)
            summary = viewModel.indexProfiles[name]?.summary ?? summary
            loadedSummary = summary
            redrafting = false
        }
    }
}

// MARK: - Metadata filters

/// Filters on the open index's metadata fields, such as `doc_id` or `year >= 2024`
struct MetadataFiltersView: View {
    @ObservedObject var viewModel: SearchViewModel

    private var canAdd: Bool {
        !viewModel.newFilterField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !viewModel.newFilterValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("Field, such as doc_id", text: $viewModel.newFilterField)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Value, list or rule, such as >=2024", text: $viewModel.newFilterValue)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(viewModel.commitNewMetadataFilter)
                Button("Add filter", action: viewModel.commitNewMetadataFilter)
                    .disabled(!canAdd)
                if let warning = viewModel.filterParseError {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.red)
                }
            } header: {
                Text("New filter")
            } footer: {
                Text("A value matches exactly, true and false match switches, [a, b] matches any of a list, and >=2024, <=10 or 1..5 compare numbers.")
            }

            if !viewModel.metadataFilters.isEmpty {
                Section("Active") {
                    ForEach(viewModel.sortedMetadataFilters, id: \.0) { field, filter in
                        LabeledContent(field, value: filter.displayValue)
                            .swipeActions {
                                Button(role: .destructive) {
                                    viewModel.removeMetadataFilter(field: field)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                    Button("Remove all", role: .destructive, action: viewModel.clearMetadataFilters)
                }
            }
        }
        .navigationTitle("Metadata filters")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.newFilterField) { _, _ in viewModel.clearFilterError() }
        .onChange(of: viewModel.newFilterValue) { _, _ in viewModel.clearFilterError() }
    }
}
