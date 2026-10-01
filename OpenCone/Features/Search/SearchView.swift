import SwiftUI
import UIKit

/// The Ask screen: a question goes to the person's Pinecone indexes, and the answer comes back
/// with the passages it cites. Laid out like OpenResponses' chat: a status bar with the model and
/// tools, where to search, the conversation, and the composer.
struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel
    @ObservedObject var settings: SettingsViewModel
    var onRequestDocumentsTab: () -> Void = {}

    @StateObject private var speechService = SpeechRecognitionService()
    @FocusState private var composerFocused: Bool
    @State private var showingScope = false
    @State private var showingAnswerSettings = false
    @State private var showingModels = false
    @State private var presentedSources: SourcesPresentation?

    /// The answer bubble shown while a search runs, before the answer's own message exists
    private static let pendingAnswerID = UUID()

    var body: some View {
        VStack(spacing: 0) {
            ChatStatusBar(
                settings: settings,
                onShowModels: { showingModels = true },
                onShowSettings: { showingAnswerSettings = true }
            )

            if !viewModel.pineconeIndexes.isEmpty {
                SearchScopeBar(viewModel: viewModel, settings: settings) {
                    showingScope = true
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(uiColor: .systemBackground))
            }
            Divider()

            conversation
        }
        .navigationTitle("Ask")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(isPresented: $showingScope) {
            SearchScopeSheet(viewModel: viewModel, settings: settings)
        }
        .sheet(isPresented: $showingAnswerSettings) {
            AnswerSettingsPanel(settings: settings)
        }
        .sheet(isPresented: $showingModels) {
            NavigationStack {
                ModelPickerList(settings: settings)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showingModels = false }
                        }
                    }
            }
        }
        .sheet(item: $presentedSources) { presentation in
            SourcesPresentationView(presentation: presentation)
        }
        .overlay(alignment: .top) {
            if let error = viewModel.errorMessage, !error.isEmpty {
                ErrorBanner(message: error) { viewModel.errorMessage = nil }
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            ListeningOverlay(speechService: speechService)
                .padding(.bottom, 90)
                .animation(.spring(response: 0.3), value: speechService.isListening)
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
        .task { await openDemoScreen() }
        .onKeyPress(.escape) {
            guard viewModel.isSearching else { return .ignored }
            viewModel.cancelActiveSearch()
            return .handled
        }
    }

    /// The screen `-OpenConeDemoScreen` asks for, in demo mode (`DemoMode`)
    private func openDemoScreen() async {
        switch DemoMode.screen {
        case "scope", "scope-one": showingScope = true
        case "answer-settings": showingAnswerSettings = true
        case "models": showingModels = true
        case "sources":
            if let answer = viewModel.messages.first(where: { $0.role == .assistant }) {
                presentedSources = .all(answer)
            }
        case "passage":
            if let passage = viewModel.messages.first(where: { $0.role == .assistant })?.sources.first {
                presentedSources = .passage(passage)
            }
        default:
            break
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            ShareLink(item: viewModel.exportConversationAsMarkdown()) {
                Image(systemName: "square.and.arrow.up")
            }
            .disabled(viewModel.messages.isEmpty)
            .accessibilityLabel("Share conversation")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                viewModel.newTopic()
                composerFocused = true
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .disabled(viewModel.messages.isEmpty || viewModel.isSearching)
            .accessibilityLabel("New chat")
        }
    }

    // MARK: - Conversation

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if viewModel.pineconeIndexes.isEmpty {
                    noIndexState
                } else if viewModel.messages.isEmpty {
                    emptyState
                } else {
                    messagesList
                }
            }
            .scrollDismissesKeyboard(.interactively)
            // A conversation opens at its latest message; an empty screen stays at the top
            .defaultScrollAnchor(viewModel.messages.isEmpty ? .top : .bottom)
            .safeAreaInset(edge: .bottom) {
                composer
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToEnd(proxy, animated: true)
            }
            .onChange(of: viewModel.isSearching) { _, _ in
                scrollToEnd(proxy, animated: true)
            }
            // Follow the answer as it streams in
            .onChange(of: viewModel.messages.last?.text.count ?? 0) { _, _ in
                guard viewModel.messages.last?.role == .assistant else { return }
                scrollToEnd(proxy, animated: false)
            }
        }
    }

    private var messagesList: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            let lastID = viewModel.messages.last?.id
            ForEach(viewModel.messages) { message in
                MessageBubble(
                    message: message,
                    status: message.id == lastID ? viewModel.routingStatus : nil,
                    canRetry: message.id == lastID && message.role == .assistant && !viewModel.isSearching,
                    onOpenSource: { presentedSources = .passage($0) },
                    onShowSources: { presentedSources = .all(message) },
                    onRetry: { Task { await viewModel.retryLastAnswer() } }
                )
                .id(message.id)
            }

            // The search runs before the answer's message exists; show where it's looking
            if viewModel.isSearching, viewModel.messages.last?.role == .user {
                MessageBubble(
                    message: ChatMessage(id: Self.pendingAnswerID, role: .assistant, text: "", status: .streaming),
                    status: viewModel.routingStatus ?? "Searching your documents"
                )
                .id(Self.pendingAnswerID)
            }

            if !viewModel.codeInterpreterOutputs.isEmpty {
                CodeInterpreterOutputsView(outputs: viewModel.codeInterpreterOutputs)
            }

            Color.clear
                .frame(height: 1)
                .id(BottomAnchor.id)
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }

    private enum BottomAnchor {
        static let id = "bottom"
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(BottomAnchor.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(BottomAnchor.id, anchor: .bottom)
        }
    }

    // MARK: - Composer

    private var composer: some View {
        ChatComposer(
            text: $viewModel.searchQuery,
            isFocused: $composerFocused,
            isSending: viewModel.isSearching,
            placeholder: composerPlaceholder,
            speechService: speechService,
            onSend: { Task { await viewModel.performSearch() } },
            onStop: viewModel.cancelActiveSearch
        )
        .disabled(viewModel.selectedIndex == nil)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    /// Auto or Everything with at least two indexes to reach
    private var searchesAcrossIndexes: Bool {
        settings.searchScope != .oneIndex && viewModel.includedIndexes.count >= 2
    }

    private var composerPlaceholder: String {
        if viewModel.selectedIndex == nil { return "Choose an index first" }
        return searchesAcrossIndexes ? "Ask anything in your indexes" : "Ask \(viewModel.selectedIndex ?? "your index")"
    }

    // MARK: - Empty states

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("Ask your documents")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(emptyStateSubtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        viewModel.searchQuery = suggestion
                        composerFocused = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkle")
                                .font(.footnote)
                                .foregroundStyle(Color.accentColor)
                            Text(suggestion)
                                .font(.subheadline)
                                .foregroundStyle(Color.primary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Answers can be wrong. Each one cites its passages, so you can check them.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 40)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    private var emptyStateSubtitle: String {
        if searchesAcrossIndexes {
            let count = viewModel.includedIndexes.count
            return settings.searchScope == .everything
                ? "Every question searches all \(count) indexes and their namespaces, and the answer cites the passages it used."
                : "OpenCone picks which of your \(count) indexes to search for each question and cites the passages it used."
        }
        guard let index = viewModel.selectedIndex else { return "Choose an index to search." }
        if let namespace = viewModel.selectedNamespace, !namespace.isEmpty {
            return "Questions search \(namespace) in \(index), and answers cite the passages they used."
        }
        return "Questions search \(index), and answers cite the passages they used."
    }

    private var suggestions: [String] {
        let included = viewModel.includedIndexes
        if searchesAcrossIndexes, included.count >= 2 {
            return [
                "What's in each of my indexes?",
                "Compare what \(included[0]) and \(included[1]) say about ",
                "Summarize the most important points",
            ]
        }
        let place = viewModel.selectedNamespace.flatMap { $0.isEmpty ? nil : $0 } ?? viewModel.selectedIndex ?? "my documents"
        return [
            "What topics does \(place) cover?",
            "Summarize the most important points",
            "What should I read first?",
        ]
    }

    @ViewBuilder
    private var noIndexState: some View {
        if !viewModel.hasLoadedIndexes {
            VStack(spacing: 12) {
                ProgressView()
                Text("Loading your indexes")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 120)
        } else {
            VStack(spacing: 20) {
                Image(systemName: "cylinder.split.1x2")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                VStack(spacing: 8) {
                    Text("No indexes yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("OpenCone answers from your Pinecone indexes. Add documents to create one, or check your Pinecone key and project in Settings.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button(action: onRequestDocumentsTab) {
                    Label("Add documents", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                Button("Try again") {
                    Task { await viewModel.loadIndexes() }
                }
                .font(.callout)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 60)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Error banner

private struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.red)
            Text(message)
                .font(.callout)
                .foregroundStyle(Color.primary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(10)
        .background(.regularMaterial)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.red.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
}
