// MARK: - SettingsView.swift
import SwiftUI

/// View for app settings
struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var isShowingResetAlert = false
    @State private var isSaved = false
    
    var body: some View {
        Form {
            // API Keys Section
            Section(header: Text("API Keys")) {
                SecureField("OpenAI API Key", text: $viewModel.openAIAPIKey)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                SecureField("Pinecone API Key", text: $viewModel.pineconeAPIKey)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                SecureField("Pinecone Project ID", text: $viewModel.pineconeProjectId)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Text("The Pinecone Project ID is required for API access.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Chunking Configuration
            Section(header: Text("Chunking Configuration")) {
                Stepper("Chunk Size: \(viewModel.defaultChunkSize)", value: $viewModel.defaultChunkSize, in: 100...2000, step: 100)
                
                Stepper("Chunk Overlap: \(viewModel.defaultChunkOverlap)", value: $viewModel.defaultChunkOverlap, in: 0...500, step: 50)
                
                Text("Larger chunks preserve more context but can be less specific. Overlap helps maintain context between chunks.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Model Selection
            Section(header: Text("AI Models")) {
                Picker("Embedding Model", selection: $viewModel.embeddingModel) {
                    ForEach(viewModel.availableEmbeddingModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                
                Picker("Completion Model", selection: $viewModel.completionModel) {
                    ForEach(viewModel.availableCompletionModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                
                Text("The embedding model converts text to vectors. The completion model generates answers from search results.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Appearance
            Section(header: Text("Appearance")) {
                Toggle("Dark Mode", isOn: $viewModel.isDarkMode)
                    .onChange(of: viewModel.isDarkMode) { oldValue, newValue in
                        setAppearance(darkMode: newValue)
                    }
            }
            
            // Actions
            Section {
                Button(action: {
                    if viewModel.isConfigurationValid() {
                        viewModel.saveSettings()
                        isSaved = true
                        
                        // Reset saved indicator after delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isSaved = false
                        }
                    }
                }) {
                    HStack {
                        Text("Save Settings")
                        Spacer()
                        if isSaved {
                            Image(systemName: "checkmark")
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Button(action: {
                    isShowingResetAlert = true
                }) {
                    Text("Reset to Defaults")
                        .foregroundColor(.red)
                }
            }
            
            // App Info
            Section(header: Text("About")) {
                HStack {
                    Text("SwiftRAG")
                        .font(.headline)
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                Text("An iOS Retrieval Augmented Generation system for document processing and semantic search.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .alert(isPresented: $isShowingResetAlert) {
            Alert(
                title: Text("Reset Settings"),
                message: Text("Are you sure you want to reset all settings to default values? This won't clear your API keys."),
                primaryButton: .destructive(Text("Reset")) {
                    viewModel.resetToDefaults()
                },
                secondaryButton: .cancel()
            )
        }
        .alert(item: Binding<IdentifiableError?>(
            get: { viewModel.errorMessage.map { IdentifiableError($0) } },
            set: { viewModel.errorMessage = $0?.message }
        )) { error in
            Alert(
                title: Text("Error"),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    /// Set app appearance based on dark mode setting
    private func setAppearance(darkMode: Bool) {
        if #available(iOS 15.0, *) {
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            scene?.windows.first?.overrideUserInterfaceStyle = darkMode ? .dark : .light
        } else {
            UIApplication.shared.windows.first?.overrideUserInterfaceStyle = darkMode ? .dark : .light
        }
    }
}

/// Wrapper to make error messages identifiable for alerts
struct IdentifiableError: Identifiable {
    let id = UUID()
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
}

#Preview {
    let viewModel = SettingsViewModel()
    viewModel.openAIAPIKey = "sk-••••••••••••••••••••••••••••••••"
    viewModel.pineconeAPIKey = "••••••••••••••••••••••••••••••••"
    viewModel.pineconeProjectId = "••••••••••••••••••••"
    
    return NavigationView {
        SettingsView(viewModel: viewModel)
            .navigationTitle("Settings")
    }
}
