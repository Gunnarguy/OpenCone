import SwiftUI

// MARK: - Main Search View

/// The primary view for the search feature, orchestrating the display of configuration,
/// search bar, loading state, results, or initial prompt.
struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel // The view model managing search state and logic.

    var body: some View {
        VStack {
            // Configuration section for selecting index and namespace.
            SearchConfigurationView(viewModel: viewModel)
            // Input field for the user's query and search button.
            SearchBarView(viewModel: viewModel)

            // Conditional display based on the search state.
            if viewModel.isSearching {
                // Show loading indicator while searching.
                SearchLoadingView()
            } else if !viewModel.generatedAnswer.isEmpty {
                // Show results tabs (Answer and Sources) if an answer is generated.
                SearchResultsTabView(viewModel: viewModel)
            } else if viewModel.searchResults.isEmpty && !viewModel.searchQuery.isEmpty {
                // Show 'No Results' if search completed with no matches.
                NoResultsView()
            } else {
                // Show initial prompt view before any search.
                InitialStateView()
            }
        }
        // Add other view modifiers if necessary, e.g., navigation title.
        // .navigationTitle("Search") // Example if used within NavigationView
    }
}

// MARK: - Search Configuration Component

/// A collapsible view section allowing users to configure search parameters like
/// the active Pinecone index and namespace.
struct SearchConfigurationView: View {
    @ObservedObject var viewModel: SearchViewModel // Shared view model.
    @State private var isConfigExpanded = false // State to control the expansion of the configuration section.

    var body: some View {
        VStack(spacing: 0) {
            // Header button to toggle the configuration section's visibility.
            Button(action: {
                // Animate the expansion/collapse.
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isConfigExpanded.toggle()
                }
            }) {
                HStack {
                    Text("Search Configuration")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    // Chevron icon indicating expanded/collapsed state.
                    Image(systemName: "chevron.\(isConfigExpanded ? "up" : "down")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle()) // Use plain style to avoid default button appearance.
            .padding(.vertical, 12)

            // Show configuration options only if expanded.
            if isConfigExpanded {
                VStack(spacing: 16) {
                    // Row for selecting the Pinecone index.
                    HStack {
                        Text("Index")
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading) // Fixed width for alignment.

                        // Picker for selecting the index. Use optional binding directly.
                        Picker("", selection: $viewModel.selectedIndex) {
                            Text("Select Index").tag(String?.none) // Tag for nil selection
                            // Populate with available indexes from the view model.
                            ForEach(viewModel.pineconeIndexes, id: \.self) { index in
                                Text(index).tag(index)
                            }
                        }
                        .pickerStyle(MenuPickerStyle()) // Use menu style for dropdown appearance.
                        .onChange(of: viewModel.selectedIndex) { oldValue, newValue in
                            // Update the index in the view model when selection changes.
                            if let index = newValue, !index.isEmpty {
                                Task {
                                    await viewModel.setIndex(index)
                                }
                            }
                        }

                        // Button to refresh the list of available indexes.
                        RefreshButton {
                            Task {
                                await viewModel.loadIndexes()
                            }
                        }
                        .disabled(viewModel.isSearching) // Disable while searching.
                    }

                    // Row for selecting the Pinecone namespace.
                    HStack {
                        Text("Namespace")
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading) // Fixed width for alignment.

                        // Picker for selecting the namespace. Use optional binding directly.
                        Picker("", selection: $viewModel.selectedNamespace) {
                            Text("Default namespace").tag(String?.none) // Tag for nil selection
                            // Populate with available namespaces.
                            ForEach(viewModel.namespaces, id: \.self) { namespace in
                                Text(namespace).tag(namespace)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .onChange(of: viewModel.selectedNamespace) { oldValue, newValue in
                            // Update the namespace in the view model.
                            viewModel.setNamespace(newValue)
                        }

                        // Button to refresh the list of namespaces for the selected index.
                        RefreshButton {
                            Task {
                                await viewModel.loadNamespaces()
                            }
                        }
                        .disabled(viewModel.isSearching) // Disable while searching.
                    }
                }
                .padding(.bottom, 12)
                // Apply transition for smooth appearance/disappearance.
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal) // Horizontal padding for the entire configuration block.
        .background(Color(.systemBackground)) // Background color.
        .cornerRadius(12) // Rounded corners.
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1) // Subtle shadow.
        .padding(.horizontal) // Outer horizontal padding to inset the block.
    }
}

// MARK: - Refresh Button Component

/// A reusable circular button styled with a refresh icon.
struct RefreshButton: View {
    let action: () -> Void // The action to perform when tapped.

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
                .font(.footnote)
                .foregroundColor(.blue)
                .padding(6) // Padding inside the circle.
                .background(Color.blue.opacity(0.1)) // Light blue background.
                .clipShape(Circle()) // Make it circular.
        }
    }
}

// MARK: - Search Bar Component

/// The view containing the text input field for the search query and the button
/// to initiate the search.
struct SearchBarView: View {
    @ObservedObject var viewModel: SearchViewModel // Shared view model.

    var body: some View {
        HStack(spacing: 12) {
            // Text field container.
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)

                // Text field for user query input.
                TextField("Enter your question...", text: $viewModel.searchQuery)
                    .padding(.vertical, 12)
                    .disabled(viewModel.isSearching) // Disable input while searching.

                // Clear button (visible only when text field is not empty).
                if !viewModel.searchQuery.isEmpty {
                    Button(action: {
                        viewModel.searchQuery = "" // Clear the search query.
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .padding(.trailing, 8)
                    }
                }
            }
            .background(Color(.systemGray6)) // Background for the text field area.
            .cornerRadius(12) // Rounded corners.

            // Search execution button.
            Button(action: {
                hideKeyboard() // Dismiss keyboard before starting search.
                Task {
                    await viewModel.performSearch() // Trigger search action.
                }
            }) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44) // Fixed size for the button.
                    .background(
                        // Change background opacity based on state.
                        viewModel.searchQuery.isEmpty || viewModel.isSearching || viewModel.selectedIndex == nil
                        ? Color.blue.opacity(0.5) // Dimmed if disabled.
                        : Color.blue // Full color if enabled.
                    )
                    .cornerRadius(12) // Rounded corners.
            }
            // Disable button if query is empty, search is ongoing, or no index is selected.
            .disabled(viewModel.searchQuery.isEmpty || viewModel.isSearching || viewModel.selectedIndex == nil)
        }
        .padding(.horizontal) // Padding for the search bar elements.
        .padding(.bottom, 12)
        .padding(.top, 4)
    }
}

// MARK: - Search Loading View

/// A view displayed while the search operation is in progress, showing a
/// circular progress indicator and text.
struct SearchLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView() // System progress indicator.
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5) // Make it slightly larger.
                .padding(20)
                .background(Color(.systemGray6).opacity(0.5)) // Semi-transparent background.
                .clipShape(Circle()) // Circular shape.

            Text("Searching...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Center in available space.
        .padding()
    }
}

// MARK: - No Results View

/// A simple view displayed when a search is performed but yields no results.
struct NoResultsView: View {
    var body: some View {
        VStack {
            Spacer() // Push content to center vertically.
            Text("No results found")
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Initial State View

/// The view shown before any search is initiated, prompting the user to enter a query.
/// Includes a decorative icon.
struct InitialStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer() // Push content towards the center.

            // Decorative icon element.
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

            // Informational text.
            VStack(spacing: 8) {
                Text("Document Search")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("Ask a question to search your documents")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40) // Limit text width.
            }

            Spacer() // Balance the spacing.
        }
    }
}

// MARK: - Search Results Tab View

/// A `TabView` that organizes the search results into two tabs:
/// one for the AI-generated answer and one for the source documents.
struct SearchResultsTabView: View {
    @ObservedObject var viewModel: SearchViewModel // Shared view model.

    var body: some View {
        TabView {
            // Tab for the generated answer.
            AnswerTabView(viewModel: viewModel)
                .tabItem {
                    Label("Answer", systemImage: "text.bubble")
                }

            // Tab for the list of source documents.
            SourcesTabView(viewModel: viewModel)
                .tabItem {
                    Label("Sources", systemImage: "doc.text")
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Fill available space.
    }
}

// MARK: - Answer Tab View

/// The content view for the "Answer" tab, displaying the generated text response
/// and buttons for regenerating the answer or clearing the search.
struct AnswerTabView: View {
    @ObservedObject var viewModel: SearchViewModel // Shared view model.

    var body: some View {
        ScrollView { // Allow scrolling for potentially long answers.
            VStack(alignment: .leading, spacing: 20) {
                // Header for the answer section.
                HStack {
                    Text("Generated Answer")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    // Badge indicating the answer is AI-generated.
                    Text("AI generated")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }

                // Display the generated answer text.
                Text(viewModel.generatedAnswer)
                    .padding()
                    .background(Color(.systemGray6)) // Background for the text block.
                    .cornerRadius(12)

                // Action buttons row.
                HStack(spacing: 12) {
                    // Show Regenerate button only if results are selected.
                    if !viewModel.selectedResults.isEmpty {
                        RegenerateButton(viewModel: viewModel)
                    }
                    // Button to clear the current search state.
                    ClearResultsButton(viewModel: viewModel)
                }
                .padding(.top, 8) // Space above the buttons.
            }
            .padding() // Padding around the content.
        }
    }
}

// MARK: - Regenerate Button

/// A button that allows the user to regenerate the AI answer based on the
/// currently selected source documents.
struct RegenerateButton: View {
    @ObservedObject var viewModel: SearchViewModel // Shared view model.

    var body: some View {
        Button(action: {
            // Trigger the regeneration action in the view model.
            Task {
                await viewModel.generateAnswerFromSelected()
            }
        }) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath") // Refresh icon.
                    .font(.system(size: 14))
                Text("Regenerate")
            }
            .frame(maxWidth: .infinity) // Make button fill available width.
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent) // Prominent button style.
        .disabled(viewModel.isSearching) // Disable while an operation is in progress.
    }
}

// MARK: - Clear Results Button

/// A button that allows the user to clear the current search query, results,
/// and generated answer, resetting the search view.
struct ClearResultsButton: View {
    @ObservedObject var viewModel: SearchViewModel // Shared view model.

    var body: some View {
        Button(action: {
            // Trigger the clear action in the view model.
            viewModel.clearSearch()
        }) {
            HStack {
                Image(systemName: "xmark") // Clear icon.
                    .font(.system(size: 14))
                Text("Clear")
            }
            .frame(maxWidth: .infinity) // Make button fill available width.
            .padding(.vertical, 12)
        }
        .foregroundColor(.red) // Red color for destructive action.
        .background(Color.red.opacity(0.1)) // Light red background.
        .cornerRadius(8)
        .overlay(
            // Subtle red border.
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
        .disabled(viewModel.isSearching) // Disable while an operation is in progress.
    }
}

// MARK: - Sources Tab View

/// The content view for the "Sources" tab, displaying a list of relevant
/// source documents found during the search.
struct SourcesTabView: View {
    @ObservedObject var viewModel: SearchViewModel // Shared view model.

    var body: some View {
        ScrollView { // Allow scrolling through the list of sources.
            VStack(alignment: .leading, spacing: 8) {
                // Header for the sources list.
                Text("Source Documents")
                    .font(.headline)
                    .foregroundColor(.blue) // Use accent color for header.
                    .padding(.bottom, 8)

                // Iterate over search results and display each in a row.
                ForEach(viewModel.searchResults) { result in
                    SearchResultRow(
                        result: result,
                        isSelected: result.isSelected // Pass selection state.
                    ) {
                        // Action to toggle selection when the row is tapped.
                        viewModel.toggleResultSelection(result)
                    }
                }
            }
            .padding() // Padding around the list.
        }
    }
}

// MARK: - Search Result Row

/// A view representing a single item in the list of search results (source documents).
/// Displays metadata and allows expansion to view the document chunk content.
struct SearchResultRow: View {
    let result: SearchResultModel // Data for the result.
    let isSelected: Bool // Whether this result is currently selected.
    let onTap: () -> Void // Action to perform when the row is tapped (toggles selection).

    @State private var isExpanded = false // State to control content expansion.

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header part of the row (metadata, selection indicator, expand button).
            ResultHeaderView(
                result: result,
                isSelected: isSelected,
                isExpanded: isExpanded,
                onToggleExpand: {
                    // Animate the expansion/collapse of the content view.
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                }
            )

            // Show the content view only if expanded.
            if isExpanded {
                ResultContentView(content: result.content)
                    // Apply transition for smooth appearance/disappearance.
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.vertical, 12) // Vertical padding within the row background.
        .padding(.horizontal, 12) // Horizontal padding within the row background.
        .background(
            // Background with rounded corners and shadow.
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .overlay(
            // Border that changes color based on selection state.
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue.opacity(0.5) : Color.secondary.opacity(0.15), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle()) // Ensure the entire area is tappable.
        .onTapGesture {
            onTap() // Trigger the selection toggle action.
        }
        .padding(.vertical, 4) // Vertical padding between rows.
    }
}

// MARK: - Result Header View

/// The header portion of a `SearchResultRow`. Displays the document icon, filename,
/// relevance score, selection checkmark (if selected), and expand/collapse button.
struct ResultHeaderView: View {
    let result: SearchResultModel // Data for the result.
    let isSelected: Bool // Selection state.
    let isExpanded: Bool // Expansion state.
    let onToggleExpand: () -> Void // Action for the expand/collapse button.

    var body: some View {
        HStack(spacing: 12) {
            // Left side: Icon, filename, score badge.
            VStack(alignment: .leading, spacing: 6) {
                // Icon and filename row.
                HStack(spacing: 8) {
                    Image(systemName: getDocumentIcon(from: result.sourceDocument))
                        .foregroundColor(getDocumentColor(from: result.sourceDocument))
                    Text(sourceFileName(from: result.sourceDocument))
                        .font(.headline)
                        .lineLimit(1) // Prevent long filenames from wrapping.
                }
                // Metadata row (currently just the score).
                HStack(spacing: 12) {
                    ResultScoreBadge(score: result.score)
                    // Placeholder comment: Additional metadata could be added here.
                    // Example: Text("Page: \(result.metadata["page"] ?? "N/A")")
                }
            }

            Spacer() // Push elements to the sides.

            // Right side: Selection checkmark and expand button.
            // Show checkmark if the item is selected.
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 18))
            }

            // Expand/collapse button.
            Button(action: onToggleExpand) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }

    /// Extracts the filename from a full source path string.
    /// - Parameter source: The full path or identifier of the source document.
    /// - Returns: The extracted filename or the original string if parsing fails.
    private func sourceFileName(from source: String) -> String {
        // Simple approach: split by '/' and take the last component.
        let components = source.split(separator: "/")
        return components.last.map { String($0) } ?? source
    }

    /// Determines the appropriate SF Symbol icon name based on the file extension.
    /// - Parameter source: The source document identifier (expected to contain an extension).
    /// - Returns: An SF Symbol name string.
    private func getDocumentIcon(from source: String) -> String {
        if source.hasSuffix(".pdf") {
            return "doc.fill"
        } else if source.hasSuffix(".md") {
            return "doc.text" // Standard text icon for Markdown.
        } else if source.hasSuffix(".txt") {
            return "doc.plaintext"
        } else {
            return "doc" // Generic document icon.
        }
    }

    /// Determines the color associated with the document type based on the file extension.
    /// - Parameter source: The source document identifier.
    /// - Returns: A `Color` value.
    private func getDocumentColor(from source: String) -> Color {
        if source.hasSuffix(".pdf") {
            return .red
        } else if source.hasSuffix(".md") {
            return .blue
        } else if source.hasSuffix(".txt") {
            return .green
        } else {
            return .gray // Default color for unknown types.
        }
    }
}

// MARK: - Result Score Badge

/// A small badge view displaying the relevance score of a search result,
/// colored based on the score value.
struct ResultScoreBadge: View {
    let score: Float // The relevance score (expecting values typically between 0 and 1).

    var body: some View {
        Text("Score: \(String(format: "%.3f", score))") // Format score to 3 decimal places.
            .font(.caption)
            .foregroundColor(scoreColor) // Text color based on score.
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(scoreColor.opacity(0.1)) // Background color based on score (with low opacity).
            .cornerRadius(8) // Rounded corners for the badge.
    }

    /// Determines the color for the score badge based on the score value.
    /// Higher scores get "better" colors (green > blue > orange).
    private var scoreColor: Color {
        if score > 0.9 {
            return .green
        } else if score > 0.7 {
            return .blue
        } else {
            return .orange // Use orange for lower scores.
        }
    }
}

// MARK: - Result Content View

/// The view displayed when a `SearchResultRow` is expanded. Shows the actual
/// text content (chunk) of the source document.
struct ResultContentView: View {
    let content: String // The text content to display.

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider() // Separator between header and content.
                .padding(.vertical, 8)

            // Display the document chunk content.
            Text(content)
                .font(.body)
                .padding(16) // Padding around the text.
                .frame(maxWidth: .infinity, alignment: .leading) // Ensure text aligns left.
                .background(Color(.systemGray6)) // Background for the content block.
                .cornerRadius(8) // Rounded corners.
        }
    }
}

// MARK: - Extensions

extension View {
    /// Helper function to dismiss the keyboard programmatically.
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Previews

/// Provides a preview of the `SearchView` for development and testing in Xcode Previews.
#Preview {
    searchViewPreview() // Calls the helper function to set up the preview.
}

/// Helper function to create and configure a `SearchView` instance specifically for previews.
/// Sets up mock services and populates the view model with sample data.
/// - Returns: A configured `SearchView` wrapped in a `NavigationView`.
private func searchViewPreview() -> some View {
    // Create mock services with placeholder keys/IDs.
    let openAIService = OpenAIService(apiKey: "preview-key")
    let pineconeService = PineconeService(apiKey: "preview-key", projectId: "preview-project-id")
    let embeddingService = EmbeddingService(openAIService: openAIService)

    // Initialize the view model with mock services.
    let viewModel = SearchViewModel(
        pineconeService: pineconeService,
        openAIService: openAIService,
        embeddingService: embeddingService
    )

    // Populate the view model with sample data for previewing the results state.
    viewModel.searchQuery = "What is RAG?"
    viewModel.generatedAnswer = "RAG (Retrieval Augmented Generation) is a technique that combines retrieval-based and generation-based approaches in natural language processing. It retrieves relevant documents from a database and then uses them as context for generating responses, improving accuracy and providing sources for the information."

    // Add sample search results.
    viewModel.searchResults = [
        // Corrected Initializer: Removed explicit id and isSelected argument
        SearchResultModel(
            content: "RAG systems combine the strengths of retrieval-based and generation-based approaches. By first retrieving relevant documents and then using them as context for generation, RAG systems can produce more accurate and grounded responses.",
            sourceDocument: "intro_to_rag.pdf",
            score: 0.98,
            metadata: ["source": "intro_to_rag.pdf"]
            // Note: isSelected state is managed internally by the model or view model now
        ),
        // Corrected Initializer: Removed explicit id
        SearchResultModel(
            content: "Retrieval Augmented Generation (RAG) is an AI framework that enhances large language model outputs by incorporating relevant information fetched from external knowledge sources.",
            sourceDocument: "ai_techniques.md",
            score: 0.92,
            metadata: ["source": "ai_techniques.md"]
        ),
        // Corrected Initializer: Removed explicit id
        SearchResultModel(
            content: "The advantages of RAG include improved factual accuracy, reduced hallucinations, and the ability to access up-to-date information without retraining the model.",
            sourceDocument: "rag_benefits.txt",
            score: 0.87,
            metadata: ["source": "rag_benefits.txt"]
        )
    ]
    // Update selectedResults based on the isSelected flag in sample data
    viewModel.selectedResults = viewModel.searchResults.filter { $0.isSelected }

    // Add sample indexes and namespaces for configuration preview
    viewModel.pineconeIndexes = ["index-1", "my-main-index", "test-index"]
    viewModel.selectedIndex = "my-main-index"
    viewModel.namespaces = ["general", "project-alpha", "archive"]
    viewModel.selectedNamespace = "general"


    // Return the SearchView embedded in a NavigationView for realistic preview context.
    return NavigationView {
        SearchView(viewModel: viewModel)
            .navigationTitle("Search Preview") // Set a title for the preview navigation bar.
    }
}

// Helper extension to handle optional binding for Picker
// (You might already have this elsewhere, ensure it's available)
// REMOVED Duplicate SearchResultModel definition and Binding extension
