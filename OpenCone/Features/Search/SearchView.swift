import SwiftUI
import UIKit

// MARK: - Main Search View

/// The primary view for the search feature, orchestrating the display of configuration,
/// search bar, loading state, results, or initial prompt.
struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel  // The view model managing search state and logic
    @Environment(\.theme) private var theme  // Access the current theme

    var body: some View {
        VStack(spacing: 8) {
            // Configuration section (index/namespace)
            QuickSwitcherView(viewModel: viewModel)

            // Metadata filter controls
            MetadataFilterEditor(viewModel: viewModel)

            // Thread controls
            HStack {
                Spacer()
                OCButton(
                    title: "New Topic",
                    icon: "bubble.left.and.bubble.right",
                    style: .outline,
                    action: { viewModel.newTopic() }
                )
                .disabled(viewModel.isSearching)
            }
            .padding(.horizontal, 16)

            // Chat messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if viewModel.messages.isEmpty && !viewModel.isSearching {
                            InitialStateView()
                                .padding(.top, 16)
                        } else {
                            ForEach(viewModel.messages) { message in
                                ChatBubble(
                                    message: message,
                                    onCitationTap: { source in
                                        viewModel.focusResult(for: source)
                                    }
                                )
                                    .id(message.id)
                            }
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                        }
                    }
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastId = viewModel.messages.last?.id {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            // Sources panel - show when we have search results
            if !viewModel.searchResults.isEmpty {
                SourcesTabView(viewModel: viewModel)
                    .frame(maxHeight: 280)
                    .transition(.opacity)
            }

            // Input bar
            ChatInputBar(
                text: Binding(
                    get: { viewModel.searchQuery },
                    set: { viewModel.searchQuery = $0 }
                ),
                isSending: viewModel.isSearching,
                onSend: {
                    Task { await viewModel.performSearch() }
                },
                onStop: {
                    viewModel.cancelActiveSearch()
                }
            )
            .disabled(viewModel.selectedIndex == nil)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(theme.backgroundColor.ignoresSafeArea())
        .overlay(alignment: .top) {
            if let error = viewModel.errorMessage, !error.isEmpty {
                ErrorBanner(message: error)
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - Search Configuration Component

/// A collapsible view section allowing users to configure search parameters like
/// the active Pinecone index and namespace.
struct SearchConfigurationView: View {
    @ObservedObject var viewModel: SearchViewModel  // Shared view model
    @State private var isConfigExpanded = false  // State to control the expansion of the configuration section
    @Environment(\.theme) private var theme  // Access the current theme

    var body: some View {
        OCCard(padding: 12) {
            VStack(spacing: 0) {
                // Header button to toggle the configuration section's visibility
                Button(action: {
                    // Animate the expansion/collapse
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isConfigExpanded.toggle()
                    }
                }) {
                    HStack {
                        Text("Search Configuration")
                            .font(.headline)
                            .foregroundColor(theme.textPrimaryColor)
                        Spacer()
                        // Chevron icon indicating expanded/collapsed state
                        Image(systemName: "chevron.\(isConfigExpanded ? "up" : "down")")
                            .font(.caption)
                            .foregroundColor(theme.textSecondaryColor)
                    }
                }
                .buttonStyle(PlainButtonStyle())  // Use plain style to avoid default button appearance
                .padding(.vertical, 8)  // Slightly reduced vertical padding

                // Show configuration options only if expanded
                if isConfigExpanded {
                    VStack(spacing: 14) {  // Slightly reduced spacing
                        // Row for selecting the Pinecone index
                        HStack {
                            Text("Index")
                                .foregroundColor(theme.textSecondaryColor)
                                .frame(width: 80, alignment: .leading)  // Fixed width for alignment

                            // Picker for selecting the index
                            Picker("", selection: $viewModel.selectedIndex) {
                                Text("Select Index").tag(String?.none)  // Tag for nil selection
                                // Populate with available indexes from the view model
                                ForEach(viewModel.pineconeIndexes, id: \.self) { index in
                                    Text(index).tag(index)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())  // Use menu style for dropdown appearance
                            .onChange(of: viewModel.selectedIndex) { oldValue, newValue in
                                // Update the index in the view model when selection changes
                                if let index = newValue, !index.isEmpty {
                                    Task {
                                        await viewModel.setIndex(index)
                                    }
                                }
                            }

                            // Button to refresh the list of available indexes
                            configRefreshButton {
                                Task {
                                    await viewModel.loadIndexes()
                                }
                            }
                            .disabled(viewModel.isSearching)  // Disable while searching
                        }

                        // Row for selecting the Pinecone namespace
                        HStack {
                            Text("Namespace")
                                .foregroundColor(theme.textSecondaryColor)
                                .frame(width: 80, alignment: .leading)  // Fixed width for alignment

                            // Picker for selecting the namespace
                            Picker("", selection: $viewModel.selectedNamespace) {
                                Text("Default namespace").tag(String?.none)  // Tag for nil selection
                                // Populate with available namespaces
                                ForEach(viewModel.namespaces, id: \.self) { namespace in
                                    Text(namespace).tag(namespace)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .onChange(of: viewModel.selectedNamespace) { oldValue, newValue in
                                // Update the namespace in the view model
                                viewModel.setNamespace(newValue)
                            }

                            // Button to refresh the list of namespaces for the selected index
                            configRefreshButton {
                                Task {
                                    await viewModel.loadNamespaces()
                                }
                            }
                            .disabled(viewModel.isSearching)  // Disable while searching
                        }
                    }
                    .padding(.vertical, 10)  // Add vertical padding inside expanded view
                    .padding(.horizontal, 4)  // Add slight horizontal padding inside
                    .background(theme.cardBackgroundColor)  // Add subtle background when expanded
                    .cornerRadius(8)  // Inner corner radius
                    .padding(.top, 8)  // Padding below the expanded section
                    // Apply transition for smooth appearance/disappearance
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.horizontal, 16)  // Consistent horizontal padding
    }

    // Custom refresh button for config section
    private func configRefreshButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.primaryColor)
                .padding(5)
                .background(theme.primaryLight)
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Search Bar Component

/// The view containing the text input field for the search query and the button
/// to initiate the search.
struct SearchBarView: View {
    @ObservedObject var viewModel: SearchViewModel  // Shared view model
    @Environment(\.theme) private var theme  // Access the current theme
    @State private var isEditing = false

    var body: some View {
        OCCard(padding: 14, cornerRadius: 16) {
            HStack(spacing: 12) {
                // Text field container
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(isEditing ? theme.primaryColor : theme.textSecondaryColor)
                        .padding(.leading, 8)
                        .animation(.easeInOut(duration: 0.2), value: isEditing)

                    // Text field for user query input
                    TextField(
                        "Enter your question...", text: $viewModel.searchQuery,
                        onEditingChanged: { editing in
                            withAnimation {
                                isEditing = editing
                            }
                        }
                    )
                    .padding(.vertical, 12)
                    .foregroundColor(theme.textPrimaryColor)
                    .disabled(viewModel.isSearching)  // Disable input while searching

                    // Clear button (visible only when text field is not empty)
                    if !viewModel.searchQuery.isEmpty {
                        Button(action: {
                            viewModel.searchQuery = ""  // Clear the search query
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(theme.textSecondaryColor)
                                .padding(.trailing, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(2)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.backgroundColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    isEditing ? theme.primaryColor : Color.clear, lineWidth: 1.5)
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: isEditing)

                // Search execution button
                OCButton(
                    title: "",
                    icon: "arrow.right",
                    style: .primary,
                    action: {
                        hideKeyboard()  // Dismiss keyboard before starting search
                        Task {
                            await viewModel.performSearch()  // Trigger search action
                        }
                    }
                )
                .frame(width: 44, height: 44)
                .disabled(
                    viewModel.searchQuery.isEmpty || viewModel.isSearching
                        || viewModel.selectedIndex == nil
                )
                .opacity(
                    viewModel.searchQuery.isEmpty || viewModel.isSearching
                        || viewModel.selectedIndex == nil ? 0.5 : 1.0
                )
                .animation(
                    .easeInOut(duration: 0.2),
                    value: viewModel.searchQuery.isEmpty || viewModel.isSearching
                        || viewModel.selectedIndex == nil)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Search Loading View

/// A view displayed while the search operation is in progress, showing a
/// circular progress indicator and text.
struct SearchLoadingView: View {
    @Environment(\.theme) private var theme  // Access the current theme
    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // Pulsing background
                Circle()
                    .fill(theme.primaryLight)
                    .frame(width: 100, height: 100)
                    .scaleEffect(pulseScale)

                // Spinning progress arc
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(theme.primaryColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(Angle(degrees: rotation))

                // Search icon
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(theme.primaryColor)
            }

            VStack(spacing: 8) {
                Text("Searching...")
                    .font(.headline)
                    .foregroundColor(theme.textPrimaryColor)

                Text("Finding the most relevant information")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondaryColor)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // Center in available space
        .onAppear {
            // Start animations when view appears
            withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.2
            }
        }
    }
}

// MARK: - No Results View

/// A simple view displayed when a search is performed but yields no results.
struct NoResultsView: View {
    @Environment(\.theme) private var theme  // Access the current theme
    @State private var appearScale: CGFloat = 0.8

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Empty state illustration
            ZStack {
                Circle()
                    .fill(theme.errorLight)
                    .frame(width: 90, height: 90)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundColor(theme.errorColor)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(theme.errorColor)
                            .offset(x: 8, y: -6)
                    )
            }

            VStack(spacing: 8) {
                Text("No results found")
                    .font(.headline)
                    .foregroundColor(theme.textPrimaryColor)

                Text("Try adjusting your search or looking for different terms")
                    .font(.subheadline)
                    .foregroundColor(theme.textSecondaryColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            Spacer()
        }
        .scaleEffect(appearScale)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                appearScale = 1.0
            }
        }
    }
}

// MARK: - Initial State View

/// The view shown before any search is initiated, prompting the user to enter a query.
/// Includes a decorative icon.
struct InitialStateView: View {
    @Environment(\.theme) private var theme  // Access the current theme
    @State private var rotation: Double = 0
    @State private var particleOffsets: [CGSize] = Array(repeating: .zero, count: 5)

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Decorative icon element
            ZStack {
                // Animated particles
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(theme.primaryColor.opacity(0.3))
                        .frame(width: 12, height: 12)
                        .offset(particleOffsets[index])
                        .opacity(0.7)
                }

                // Main circle background
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [theme.primaryLight, theme.primaryMedium]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                // Document icon
                Image(systemName: "doc.text.magnifyingglass")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(theme.primaryColor)
                    .rotationEffect(Angle(degrees: rotation))
            }

            // Informational text
            VStack(spacing: 8) {
                Text("Document Search")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(theme.textPrimaryColor)

                Text("Ask a question to search your documents")
                    .font(.system(.callout, design: .rounded))
                    .foregroundColor(theme.textSecondaryColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)
            }

            Spacer()

            // Subtle hints about the search capabilities
            VStack(spacing: 16) {
                featureRow(
                    icon: "text.magnifyingglass", text: "Semantic search across your documents")
                featureRow(icon: "brain", text: "AI-generated answers from your content")
                featureRow(icon: "checkmark.shield", text: "Context-aware responses from your data")
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .onAppear {
            // Subtle icon rotation
            withAnimation(Animation.easeInOut(duration: 20).repeatForever(autoreverses: false)) {
                rotation = 360
            }

            // Animate particles
            animateParticles()
        }
    }

    // Helper to create consistent feature rows
    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(theme.primaryColor)
                .frame(width: 24, height: 24)

            Text(text)
                .font(.callout)
                .foregroundColor(theme.textSecondaryColor)

            Spacer()
        }
    }

    // Animate particles in random patterns
    private func animateParticles() {
        for i in 0..<particleOffsets.count {
            // Generate random offset within a radius
            let randomRadius = CGFloat.random(in: 70...120)
            let randomAngle = CGFloat.random(in: 0...2 * .pi)
            let xOffset = randomRadius * cos(randomAngle)
            let yOffset = randomRadius * sin(randomAngle)

            // Animate with delay for each particle
            withAnimation(
                Animation.easeInOut(duration: Double.random(in: 10...15))
                    .repeatForever()
                    .delay(Double(i) * 0.3)
            ) {
                particleOffsets[i] = CGSize(width: xOffset, height: yOffset)
            }
        }
    }
}

// MARK: - Sources Tab View

/// The content view for the "Sources" tab, displaying a list of relevant
/// source documents found during the search.
struct SourcesTabView: View {
    @ObservedObject var viewModel: SearchViewModel  // Shared view model
    @Environment(\.theme) private var theme  // Access the current theme
    @State private var selectedFilter: String? = nil
    @State private var sourceTypes: [String] = []
    @State private var selectedCount: Int = 0

    var filteredResults: [SearchResultModel] {
        if let filter = selectedFilter {
            return viewModel.searchResults.filter { result in
                let ext = result.sourceDocument.split(separator: ".").last?.lowercased() ?? ""
                return ext == filter.lowercased()
            }
        }
        return viewModel.searchResults
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("Sources")
                    .font(.headline)
                    .foregroundColor(theme.textPrimaryColor)
                
                Spacer()
                
                if !viewModel.selectedResults.isEmpty {
                    OCButton(
                        title: "Regenerate",
                        icon: "arrow.triangle.2.circlepath",
                        style: .outline
                    ) {
                        Task {
                            await viewModel.generateAnswerFromSelected()
                        }
                    }
                    .disabled(viewModel.isSearching)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Filter pills row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // All filter
                    filterPill(nil, count: viewModel.searchResults.count)

                    // Extension-based filters
                    ForEach(sourceTypes, id: \.self) { ext in
                        let count = viewModel.searchResults.filter {
                            $0.sourceDocument.hasSuffix(".\(ext)")
                        }.count
                        filterPill(ext, count: count)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }

            // Selection counter
            if !viewModel.selectedResults.isEmpty {
                HStack {
                    OCBadge(
                        "\(viewModel.selectedResults.count) selected",
                        style: .custom(theme.primaryColor)
                    )
                    .padding(.leading)

                    Spacer()

                    Button(action: {
                        for result in viewModel.searchResults {
                            if !result.isSelected {
                                viewModel.toggleResultSelection(result)
                            }
                        }
                    }) {
                        Text("Select All")
                            .font(.caption)
                            .foregroundColor(theme.primaryColor)
                    }
                    .padding(.trailing)
                }
                .padding(.bottom, 4)
            }

            // Results list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredResults) { result in
                            SearchResultRow(
                                result: result,
                                isSelected: result.isSelected,
                                viewModel: viewModel
                            ) {
                                viewModel.toggleResultSelection(result)
                            }
                            .id(result.id)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
                .onChange(of: viewModel.highlightedResultID) { _, newId in
                    guard let targetId = newId else { return }
                    if !filteredResults.contains(where: { $0.id == targetId }) {
                        withAnimation { selectedFilter = nil }
                    }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(targetId, anchor: .top)
                        }
                    }
                }
            }
        }
        .background(theme.backgroundColor)
        .onAppear {
            // Extract unique source types for filters
            let extensions = Set(
                viewModel.searchResults.compactMap { result -> String? in
                    let components = result.sourceDocument.split(separator: ".")
                    return components.last.map(String.init)?.lowercased()
                })
            sourceTypes = Array(extensions).sorted()

            // Count selected results
            selectedCount = viewModel.selectedResults.count
        }
        .onChange(of: viewModel.selectedResults.count) { oldCount, newCount in
            withAnimation {
                selectedCount = newCount
            }
        }
    }

    // Helper to create filter pill buttons
    private func filterPill(_ type: String?, count: Int) -> some View {
        Button(action: {
            withAnimation {
                selectedFilter = (selectedFilter == type) ? nil : type
            }
        }) {
            HStack(spacing: 4) {
                if let type = type {
                    Image(systemName: documentIcon(for: type))
                        .font(.system(size: 12))
                } else {
                    Image(systemName: "tray.full")
                        .font(.system(size: 12))
                }

                Text(type?.uppercased() ?? "ALL")
                    .font(.caption.bold())

                Text("(\(count))")
                    .font(.caption)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(selectedFilter == type ? theme.primaryLight : theme.cardBackgroundColor)
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
            )
            .foregroundColor(selectedFilter == type ? theme.primaryColor : theme.textSecondaryColor)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // Get document icon for filter pills
    private func documentIcon(for ext: String) -> String {
        switch ext.lowercased() {
        case "pdf": return "doc.fill"
        case "md": return "doc.text"
        case "txt": return "doc.plaintext"
        default: return "doc"
        }
    }
}

// MARK: - Search Result Row

/// A view representing a single item in the list of search results (source documents).
/// Displays metadata and allows expansion to view the document chunk content.
struct SearchResultRow: View {
    let result: SearchResultModel  // Data for the result
    let isSelected: Bool  // Whether this result is currently selected
    let viewModel: SearchViewModel  // Access to view model for theming
    let onTap: () -> Void  // Action to perform when the row is tapped (toggles selection)

    @Environment(\.theme) private var theme  // Access the current theme

    var body: some View {
        let isExpanded = viewModel.expandedResultIDs.contains(result.id)
        let isHighlighted = viewModel.highlightedResultID == result.id

        OCCard(padding: isExpanded ? 16 : 12, cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 0) {
                // Header part of the row (metadata, selection indicator, expand button)
                ResultHeaderView(
                    result: result,
                    isSelected: isSelected,
                    isExpanded: isExpanded,
                    isHighlighted: isHighlighted,
                    viewModel: viewModel,
                    onToggleExpand: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.toggleResultExpansion(for: result.id)
                        }
                    }
                )

                // Show the content view only if expanded
                if isExpanded {
                    ResultContentView(content: result.content, theme: theme)
                        // Apply transition for smooth appearance/disappearance
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .onTapGesture {
            onTap()  // Trigger the selection toggle action
        }
        .overlay(
            // Border that changes color based on selection state
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isHighlighted ? theme.primaryColor : (isSelected ? theme.primaryColor.opacity(0.6) : Color.clear),
                    lineWidth: isHighlighted ? 3 : (isSelected ? 2 : 0)
                )
        )
    }
}

// MARK: - Result Header View

/// The header portion of a `SearchResultRow`. Displays the document icon, filename,
/// relevance score, selection checkmark (if selected), and expand/collapse button.
struct ResultHeaderView: View {
    let result: SearchResultModel  // Data for the result
    let isSelected: Bool  // Selection state
    let isExpanded: Bool  // Expansion state
    let isHighlighted: Bool
    let viewModel: SearchViewModel  // Access to view model for theming
    let onToggleExpand: () -> Void  // Action for the expand/collapse button

    @Environment(\.theme) private var theme  // Access the current theme
    @State private var checkmarkScale: CGFloat = 0.4

    var body: some View {
        HStack(spacing: 12) {
            // Left side: Icon, filename, score badge
            VStack(alignment: .leading, spacing: 6) {
                // Icon and filename row
                HStack(spacing: 8) {
                    documentTypeIcon()

                    Text(sourceFileName(from: result.sourceDocument))
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(isHighlighted ? theme.primaryColor : theme.textPrimaryColor)
                        .lineLimit(1)  // Prevent long filenames from wrapping
                }

                // Metadata row (score and other useful info)
                HStack(spacing: 10) {
                    // Score badge with visual representation of relevance
                    OCBadge(
                        viewModel.getRelevanceLabel(result.score),
                        style: .custom(viewModel.getColorForScore(result.score))
                    )

                    // Formatted score value
                    Text(String(format: "Score: %.3f", result.score))
                        .font(.caption)
                        .foregroundColor(theme.textSecondaryColor)
                }
            }

            Spacer()  // Push elements to the sides

            // Right side: Selection checkmark and expand button
            HStack(spacing: 10) {
                // Show checkmark if the item is selected
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.primaryColor)
                        .font(.system(size: 18))
                        .scaleEffect(checkmarkScale)
                        .onAppear {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                checkmarkScale = 1.0
                            }
                        }
                }

                // Expand/collapse button
                Button(action: onToggleExpand) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textSecondaryColor)
                        .padding(6)
                        .background(
                            Circle()
                                .fill(theme.cardBackgroundColor)
                                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .contentShape(Circle())
            }
        }
    }

    // Create visually appealing document type icon
    private func documentTypeIcon() -> some View {
        let iconName = getDocumentIcon(from: result.sourceDocument)
        let iconColor = isHighlighted ? theme.primaryColor : viewModel.getColorForScore(result.score)

        return ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(iconColor.opacity(isHighlighted ? 0.25 : 0.15))
                .frame(width: 28, height: 28)

            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundColor(iconColor)
        }
    }

    /// Extracts the filename from a full source path string.
    private func sourceFileName(from source: String) -> String {
        let components = source.split(separator: "/")
        return components.last.map { String($0) } ?? source
    }

    /// Get document type (extension) from source path
    private func getDocumentType(from source: String) -> String {
        let components = source.split(separator: ".")
        return components.last.map { String($0).uppercased() } ?? "DOC"
    }

    /// Determines the appropriate SF Symbol icon name based on the file extension.
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
}

// MARK: - Result Content View

/// The view displayed when a `SearchResultRow` is expanded. Shows the actual
/// text content (chunk) of the source document.
struct ResultContentView: View {
    let content: String  // The text content to display
    let theme: OCTheme  // The current theme
    @State private var textOpacity = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Content divider
            Divider()
                .padding(.top, 12)

            // Document content with highlighting
            Text(content)
                .font(.callout)
                .lineSpacing(4)
                .foregroundColor(theme.textPrimaryColor)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.cardBackgroundColor)
                .cornerRadius(8)
                .opacity(textOpacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 0.4).delay(0.1)) {
                        textOpacity = 1.0
                    }
                }
        }
    }
}

// MARK: - Metadata Filter Editor

struct MetadataFilterEditor: View {
    @ObservedObject var viewModel: SearchViewModel
    @Environment(\.theme) private var theme

    var body: some View {
        OCCard(padding: 14, cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Metadata Filters")
                        .font(.headline)
                        .foregroundColor(theme.textPrimaryColor)

                    Spacer()

                    if !viewModel.metadataFilters.isEmpty {
                        Button(action: viewModel.clearMetadataFilters) {
                            Text("Clear All")
                                .font(.caption.bold())
                                .foregroundColor(theme.primaryColor)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                if let warning = viewModel.filterParseError {
                    Text(warning)
                        .font(.caption)
                        .foregroundColor(theme.errorColor)
                }

                HStack(spacing: 8) {
                    TextField("Field (e.g. doc_id)", text: $viewModel.newFilterField)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: viewModel.newFilterField) { _, _ in
                            viewModel.clearFilterError()
                        }

                    TextField("Value or rule (e.g. [policy], >=2024)", text: $viewModel.newFilterValue)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { viewModel.commitNewMetadataFilter() }
                        .onChange(of: viewModel.newFilterValue) { _, _ in
                            viewModel.clearFilterError()
                        }

                    OCButton(
                        title: "Add",
                        icon: "line.3.horizontal.decrease.circle",
                        style: .primary,
                        size: .small,
                        fullWidth: false,
                        action: viewModel.commitNewMetadataFilter
                    )
                    .disabled(
                        viewModel.newFilterField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        viewModel.newFilterValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }

                if viewModel.metadataFilters.isEmpty {
                    Text("No filters applied. Add a field and value to narrow results.")
                        .font(.caption)
                        .foregroundColor(theme.textSecondaryColor)
                } else {
                    VStack(spacing: 8) {
                        ForEach(viewModel.sortedMetadataFilters, id: \.0) { field, filter in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(field)
                                    .font(.subheadline.bold())
                                    .foregroundColor(theme.textPrimaryColor)

                                Text(filter.displayValue)
                                    .font(.subheadline)
                                    .foregroundColor(theme.textSecondaryColor)
                                    .lineLimit(1)

                                Spacer()

                                Button {
                                    viewModel.removeMetadataFilter(field: field)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(theme.textSecondaryColor)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .accessibilityLabel("Remove filter \(field)")
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(theme.cardBackgroundColor.opacity(0.7))
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

 // MARK: - Quick Switcher (Index • Namespace)

struct QuickSwitcherView: View {
    @ObservedObject var viewModel: SearchViewModel
    @Environment(\.theme) private var theme

    @State private var showIndexSheet = false
    @State private var showNamespaceSheet = false
    @State private var indexQuery: String = ""
    @State private var namespaceQuery: String = ""

    var body: some View {
        VStack(spacing: 8) {
            // Summary pill button
            OCCard(padding: 0, cornerRadius: 14) {
                Button(action: { showIndexSheet = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "folder")
                            .foregroundColor(theme.primaryColor)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Index • Namespace")
                                .font(.caption)
                                .foregroundColor(theme.textSecondaryColor)
                            Text("\(viewModel.selectedIndex ?? "Select Index") • \(viewModel.selectedNamespace ?? "Default")")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(theme.textPrimaryColor)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(theme.textSecondaryColor)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 52) // 44+ tap target
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(viewModel.isSearching)
            }
            .padding(.horizontal, 16)

            // Namespace chips for small sets
            if !viewModel.namespaces.isEmpty && viewModel.namespaces.count <= 6 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // Default namespace (nil)
                        NamespaceChip(
                            title: "Default",
                            selected: viewModel.selectedNamespace == nil,
                            theme: theme
                        ) {
                            hapticSelection()
                            viewModel.setNamespace(nil)
                        }
                        ForEach(viewModel.namespaces, id: \.self) { ns in
                            NamespaceChip(
                                title: ns,
                                selected: viewModel.selectedNamespace == ns,
                                theme: theme
                            ) {
                                hapticSelection()
                                viewModel.setNamespace(ns)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        // Index Sheet
        .sheet(isPresented: $showIndexSheet) {
            IndexListSheet(
                title: "Select Index",
                allItems: viewModel.pineconeIndexes,
                query: $indexQuery,
                onRefresh: {
                    Task { await viewModel.loadIndexes() }
                },
                onSelect: { index in
                    hapticSelection()
                    showIndexSheet = false
                    Task {
                        await viewModel.setIndex(index)
                        // If multiple namespaces, open namespace sheet automatically
                        await MainActor.run {
                            if viewModel.namespaces.count > 1 {
                                showNamespaceSheet = true
                            }
                        }
                    }
                }
            )
        }
        // Namespace Sheet
        .sheet(isPresented: $showNamespaceSheet) {
            NamespaceListSheet(
                title: "Select Namespace",
                allItems: viewModel.namespaces,
                query: $namespaceQuery,
                onRefresh: {
                    Task { await viewModel.loadNamespaces() }
                },
                onSelect: { ns in
                    hapticSelection()
                    viewModel.setNamespace(ns)
                    showNamespaceSheet = false
                }
            )
        }
        .onAppear {
            // If no index yet but we have indexes loaded, nudge user with sheet
            if viewModel.selectedIndex == nil && !viewModel.pineconeIndexes.isEmpty {
                showIndexSheet = true
            }
        }
    }

    private func hapticSelection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}

private struct NamespaceChip: View {
    let title: String
    let selected: Bool
    let theme: OCTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if selected { Image(systemName: "checkmark.circle.fill") }
                Text(title)
                    .lineLimit(1)
            }
            .font(.system(size: 14, weight: .semibold))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                Capsule()
                    .fill(selected ? theme.primaryLight : theme.cardBackgroundColor)
            )
            .foregroundColor(selected ? theme.primaryColor : theme.textSecondaryColor)
            .overlay(
                Capsule()
                    .stroke(selected ? theme.primaryColor.opacity(0.6) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Namespace \(title)")
    }
}

// Generic searchable sheet for Indexes
private struct IndexListSheet: View {
    let title: String
    let allItems: [String]
    @Binding var query: String
    let onRefresh: () -> Void
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var filtered: [String] {
        guard !query.isEmpty else { return allItems }
        return allItems.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(filtered, id: \.self) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        HStack {
                            Image(systemName: "tray.full")
                                .foregroundColor(theme.primaryColor)
                            Text(item)
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .frame(height: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .refreshable { onRefresh() }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// Generic searchable sheet for Namespaces
private struct NamespaceListSheet: View {
    let title: String
    let allItems: [String]
    @Binding var query: String
    let onRefresh: () -> Void
    let onSelect: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var filtered: [String] {
        guard !query.isEmpty else { return allItems }
        return allItems.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationView {
            List {
                // Default (nil) option
                Button {
                    onSelect(nil)
                } label: {
                    HStack {
                        Image(systemName: "circle")
                            .foregroundColor(theme.textSecondaryColor)
                        Text("Default")
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .frame(height: 48)
                }
                .buttonStyle(PlainButtonStyle())

                ForEach(filtered, id: \.self) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        HStack {
                            Image(systemName: "tag")
                                .foregroundColor(theme.primaryColor)
                            Text(item)
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .frame(height: 48)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .refreshable { onRefresh() }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct ErrorBanner: View {
    let message: String
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(theme.errorColor)
            Text(message)
                .font(.caption)
                .foregroundColor(theme.errorColor)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.errorLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.errorColor.opacity(0.6), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
        .accessibilityLabel("Error: \(message)")
    }
}

// MARK: - Extensions and Helpers

extension View {
    /// Helper function to dismiss the keyboard programmatically
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
