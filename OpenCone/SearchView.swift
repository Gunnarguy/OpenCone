import SwiftUI

/// View for searching and displaying results from the RAG system
struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel
    @State private var isExpandedResults = false
    
    var body: some View {
        VStack {
            // Index and Namespace Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Search Configuration")
                    .font(.headline)
                    .padding(.top, 4)
                
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
                    
                    Button(action: {
                        Task {
                            await viewModel.loadIndexes()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isSearching)
                }
                
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
                    
                    Button(action: {
                        Task {
                            await viewModel.loadNamespaces()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isSearching)
                }
            }
            .padding(.horizontal)
            
            // Search Box
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
            
            if viewModel.isSearching {
                // Search Progress
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Searching...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding()
            } else if !viewModel.generatedAnswer.isEmpty {
                // Display Results in a TabView
                TabView {
                    // Answer Tab
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
                            
                            Button(action: {
                                viewModel.clearSearch()
                            }) {
                                Text("Clear Results")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.isSearching)
                        }
                        .padding()
                    }
                    .tabItem {
                        Label("Answer", systemImage: "text.bubble")
                    }
                    
                    // Sources Tab
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
                    .tabItem {
                        Label("Sources", systemImage: "doc.text")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                // No Results
                VStack {
                    Spacer()
                    Text("No results found")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                // Initial State
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
    }
}

/// Row for displaying a search result
struct SearchResultRow: View {
    let result: SearchResultModel
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                Text(result.content)
                    .font(.body)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
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
    
    /// Extract filename from source path
    private func sourceFileName(from source: String) -> String {
        let components = source.split(separator: "/")
        return components.last.map { String($0) } ?? source
    }
}

/// Extension to hide keyboard
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    searchViewPreview()
}

/// Helper function to create preview for SearchView
private func searchViewPreview() -> some View {
    let openAIService = OpenAIService(apiKey: "preview-key")
    // Updated PineconeService initialization to match its current definition
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
