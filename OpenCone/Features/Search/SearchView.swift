import SwiftUI

// MARK: - Main Search View
struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel
    
    var body: some View {
        VStack {
            SearchConfigurationView(viewModel: viewModel)
            SearchBarView(viewModel: viewModel)
            
            if viewModel.isSearching {
                SearchLoadingView()
            } else if !viewModel.generatedAnswer.isEmpty {
                SearchResultsTabView(viewModel: viewModel)
            } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                NoResultsView()
            } else {
                InitialStateView()
            }
        }
    }
}

// MARK: - Search Configuration Component
struct SearchConfigurationView: View {
    @ObservedObject var viewModel: SearchViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search Configuration")
                .font(.headline)
                .padding(.top, 4)
            
            // Index Selection
            HStack {
                Picker("Index:", selection: $viewModel.selectedIndex.toUnwrapped(defaultValue: "")) {
                    Text("Select Index").tag("")
                    ForEach(viewModel.pineconeIndexes, id: \.self) { index in
                        Text(index).tag(index)
                    }
                }
                .onChange(of: viewModel.selectedIndex) { oldValue, newValue in
                    if let index = newValue, !index.isEmpty {
                        Task {
                            await viewModel.setIndex(index)
                        }
                    }
                }
                
                RefreshButton {
                    Task {
                        await viewModel.loadIndexes()
                    }
                }
                .disabled(viewModel.isSearching)
            }
            
            // Namespace Selection
            HStack {
                Picker("Namespace:", selection: $viewModel.selectedNamespace.toUnwrapped(defaultValue: "")) {
                    Text("Default namespace").tag("")
                    ForEach(viewModel.namespaces, id: \.self) { namespace in
                        Text(namespace).tag(namespace)
                    }
                }
                .onChange(of: viewModel.selectedNamespace) { oldValue, newValue in
                    viewModel.setNamespace(newValue)
                }
                
                RefreshButton {
                    Task {
                        await viewModel.loadNamespaces()
                    }
                }
                .disabled(viewModel.isSearching)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Refresh Button Component
struct RefreshButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
        }
    }
}

// MARK: - Search Bar Component
struct SearchBarView: View {
    @ObservedObject var viewModel: SearchViewModel
    
    var body: some View {
        HStack {
            TextField("Enter your question...", text: $viewModel.searchQuery)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(viewModel.isSearching)
            
            Button(action: {
                hideKeyboard()
                Task {
                    await viewModel.performSearch()
                }
            }) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            .disabled(viewModel.searchQuery.isEmpty || viewModel.isSearching || viewModel.selectedIndex == nil)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// MARK: - Search Loading View
struct SearchLoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Text("Searching...")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
    }
}

// MARK: - No Results View
struct NoResultsView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("No results found")
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Initial State View
struct InitialStateView: View {
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(.secondary)
                .opacity(0.5)
            
            Text("Ask a question to search your documents")
                .foregroundColor(.secondary)
                .padding(.top)
            Spacer()
        }
    }
}

// MARK: - Search Results Tab View
struct SearchResultsTabView: View {
    @ObservedObject var viewModel: SearchViewModel
    
    var body: some View {
        TabView {
            // Answer Tab
            AnswerTabView(viewModel: viewModel)
                .tabItem {
                    Label("Answer", systemImage: "text.bubble")
                }
            
            // Sources Tab
            SourcesTabView(viewModel: viewModel)
                .tabItem {
                    Label("Sources", systemImage: "doc.text")
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Answer Tab View
struct AnswerTabView: View {
    @ObservedObject var viewModel: SearchViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Generated Answer")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                Text(viewModel.generatedAnswer)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                if !viewModel.selectedResults.isEmpty {
                    RegenerateButton(viewModel: viewModel)
                }
                
                ClearResultsButton(viewModel: viewModel)
            }
            .padding()
        }
    }
}

// MARK: - Regenerate Button
struct RegenerateButton: View {
    @ObservedObject var viewModel: SearchViewModel
    
    var body: some View {
        Button(action: {
            Task {
                await viewModel.generateAnswerFromSelected()
            }
        }) {
            Text("Regenerate from Selected")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isSearching)
    }
}

// MARK: - Clear Results Button
struct ClearResultsButton: View {
    @ObservedObject var viewModel: SearchViewModel
    
    var body: some View {
        Button(action: {
            viewModel.clearSearch()
        }) {
            Text("Clear Results")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.isSearching)
    }
}

// MARK: - Sources Tab View
struct SourcesTabView: View {
    @ObservedObject var viewModel: SearchViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Source Documents")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding(.bottom, 8)
                
                ForEach(viewModel.searchResults) { result in
                    SearchResultRow(result: result, isSelected: result.isSelected) {
                        viewModel.toggleResultSelection(result)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let result: SearchResultModel
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ResultHeaderView(
                result: result, 
                isSelected: isSelected, 
                isExpanded: isExpanded,
                onToggleExpand: { isExpanded.toggle() }
            )
            
            if isExpanded {
                ResultContentView(content: result.content)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Result Header View
struct ResultHeaderView: View {
    let result: SearchResultModel
    let isSelected: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(sourceFileName(from: result.sourceDocument))
                    .font(.headline)
                    .lineLimit(1)
                
                Text("Score: \(String(format: "%.3f", result.score))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
            
            Button(action: onToggleExpand) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    /// Extract filename from source path
    private func sourceFileName(from source: String) -> String {
        let components = source.split(separator: "/")
        return components.last.map { String($0) } ?? source
    }
}

// MARK: - Result Content View
struct ResultContentView: View {
    let content: String
    
    var body: some View {
        Text(content)
            .font(.body)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
    }
}

// MARK: - Extensions
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Previews
#Preview {
    searchViewPreview()
}

/// Helper function to create preview for SearchView
private func searchViewPreview() -> some View {
    let openAIService = OpenAIService(apiKey: "preview-key")
    let pineconeService = PineconeService(apiKey: "preview-key", projectId: "preview-project-id")
    let embeddingService = EmbeddingService(openAIService: openAIService)
    
    let viewModel = SearchViewModel(
        pineconeService: pineconeService,
        openAIService: openAIService,
        embeddingService: embeddingService
    )
    
    // Add sample results for preview
    viewModel.searchQuery = "What is RAG?"
    viewModel.generatedAnswer = "RAG (Retrieval Augmented Generation) is a technique that combines retrieval-based and generation-based approaches in natural language processing. It retrieves relevant documents from a database and then uses them as context for generating responses, improving accuracy and providing sources for the information."
    
    viewModel.searchResults = [
        SearchResultModel(
            content: "RAG systems combine the strengths of retrieval-based and generation-based approaches. By first retrieving relevant documents and then using them as context for generation, RAG systems can produce more accurate and grounded responses.",
            sourceDocument: "intro_to_rag.pdf",
            score: 0.98,
            metadata: ["source": "intro_to_rag.pdf"]
        ),
        SearchResultModel(
            content: "Retrieval Augmented Generation (RAG) is an AI framework that enhances large language model outputs by incorporating relevant information fetched from external knowledge sources.",
            sourceDocument: "ai_techniques.md",
            score: 0.92,
            metadata: ["source": "ai_techniques.md"]
        ),
        SearchResultModel(
            content: "The advantages of RAG include improved factual accuracy, reduced hallucinations, and the ability to access up-to-date information without retraining the model.",
            sourceDocument: "rag_benefits.txt",
            score: 0.87,
            metadata: ["source": "rag_benefits.txt"]
        )
    ]
    
    return NavigationView {
        SearchView(viewModel: viewModel)
            .navigationTitle("Search")
    }
}