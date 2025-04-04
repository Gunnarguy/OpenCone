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
    @State private var isConfigExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with disclosure button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isConfigExpanded.toggle()
                }
            }) {
                HStack {
                    Text("Search Configuration")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.\(isConfigExpanded ? "up" : "down")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.vertical, 12)
            
            if isConfigExpanded {
                VStack(spacing: 16) {
                    // Index Selection
                    HStack {
                        Text("Index")
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading)
                        
                        Picker("", selection: $viewModel.selectedIndex.toUnwrapped(defaultValue: "")) {
                            Text("Select Index").tag("")
                            ForEach(viewModel.pineconeIndexes, id: \.self) { index in
                                Text(index).tag(index)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
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
                        Text("Namespace")
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading)
                        
                        Picker("", selection: $viewModel.selectedNamespace.toUnwrapped(defaultValue: "")) {
                            Text("Default namespace").tag("")
                            ForEach(viewModel.namespaces, id: \.self) { namespace in
                                Text(namespace).tag(namespace)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
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
                .padding(.bottom, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        .padding(.horizontal)
    }
}

// MARK: - Refresh Button Component
struct RefreshButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
                .font(.footnote)
                .foregroundColor(.blue)
                .padding(6)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())
        }
    }
}

// MARK: - Search Bar Component
struct SearchBarView: View {
    @ObservedObject var viewModel: SearchViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                
                TextField("Enter your question...", text: $viewModel.searchQuery)
                    .padding(.vertical, 12)
                    .disabled(viewModel.isSearching)
                
                if !viewModel.searchQuery.isEmpty {
                    Button(action: {
                        viewModel.searchQuery = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .padding(.trailing, 8)
                    }
                }
            }
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Button(action: {
                hideKeyboard()
                Task {
                    await viewModel.performSearch()
                }
            }) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        viewModel.searchQuery.isEmpty || viewModel.isSearching || viewModel.selectedIndex == nil 
                        ? Color.blue.opacity(0.5) 
                        : Color.blue
                    )
                    .cornerRadius(12)
            }
            .disabled(viewModel.searchQuery.isEmpty || viewModel.isSearching || viewModel.selectedIndex == nil)
        }
        .padding(.horizontal)
        .padding(.bottom, 12)
        .padding(.top, 4)
    }
}

// MARK: - Search Loading View
struct SearchLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
                .padding(20)
                .background(Color(.systemGray6).opacity(0.5))
                .clipShape(Circle())
            
            Text("Searching...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "doc.text.magnifyingglass")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                Text("Document Search")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("Ask a question to search your documents")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
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
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Generated Answer")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("AI generated")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
                
                Text(viewModel.generatedAnswer)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                
                HStack(spacing: 12) {
                    if !viewModel.selectedResults.isEmpty {
                        RegenerateButton(viewModel: viewModel)
                    }
                    
                    ClearResultsButton(viewModel: viewModel)
                }
                .padding(.top, 8)
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
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 14))
                Text("Regenerate")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
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
            HStack {
                Image(systemName: "xmark")
                    .font(.system(size: 14))
                Text("Clear")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .foregroundColor(.red)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
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
        VStack(alignment: .leading, spacing: 0) {
            ResultHeaderView(
                result: result, 
                isSelected: isSelected, 
                isExpanded: isExpanded,
                onToggleExpand: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                }
            )
            
            if isExpanded {
                ResultContentView(content: result.content)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue.opacity(0.5) : Color.secondary.opacity(0.15), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Result Header View
struct ResultHeaderView: View {
    let result: SearchResultModel
    let isSelected: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: getDocumentIcon(from: result.sourceDocument))
                        .foregroundColor(getDocumentColor(from: result.sourceDocument))
                    
                    Text(sourceFileName(from: result.sourceDocument))
                        .font(.headline)
                        .lineLimit(1)
                }
                
                HStack(spacing: 12) {
                    ResultScoreBadge(score: result.score)
                    
                    // Additional metadata could go here
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 18))
            }
            
            Button(action: onToggleExpand) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }
    
    /// Extract filename from source path
    private func sourceFileName(from source: String) -> String {
        let components = source.split(separator: "/")
        return components.last.map { String($0) } ?? source
    }
    
    /// Get appropriate icon based on file type
    private func getDocumentIcon(from source: String) -> String {
        if source.hasSuffix(".pdf") {
            return "doc.fill"
        } else if source.hasSuffix(".md") {
            return "doc.text"
        } else if source.hasSuffix(".txt") {
            return "doc.plaintext"
        } else {
            return "doc"
        }
    }
    
    /// Get color based on file type
    private func getDocumentColor(from source: String) -> Color {
        if source.hasSuffix(".pdf") {
            return .red
        } else if source.hasSuffix(".md") {
            return .blue
        } else if source.hasSuffix(".txt") {
            return .green
        } else {
            return .gray
        }
    }
}

// MARK: - Result Score Badge
struct ResultScoreBadge: View {
    let score: Float  // Changed from Double to Float
    
    var body: some View {
        Text("Score: \(String(format: "%.3f", score))")
            .font(.caption)
            .foregroundColor(scoreColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(scoreColor.opacity(0.1))
            .cornerRadius(8)
    }
    
    private var scoreColor: Color {
        if score > 0.9 {
            return .green
        } else if score > 0.7 {
            return .blue
        } else {
            return .orange
        }
    }
}

// MARK: - Result Content View
struct ResultContentView: View {
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 8)
            
            Text(content)
                .font(.body)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
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