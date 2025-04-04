import SwiftUI

/// Welcome screen for first launch
struct WelcomeView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    let onComplete: () -> Void
    private let logger = Logger.shared
    
    @State private var currentStep = 0
    
    var body: some View {
        VStack {
            // Progress indicator
            progressIndicator
            
            Spacer()
            
            // Content based on current step
            currentStepContent
            
            Spacer()
            
            // Navigation buttons
            navigationButtons
        }
        .padding()
    }
    
    // MARK: - View Components
    
    private var progressIndicator: some View {
        HStack {
            ForEach(0..<3) { step in
                Circle()
                    .fill(step == currentStep ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.top, 40)
    }
    
    private var currentStepContent: some View {
        Group {
            switch currentStep {
            case 0:
                welcomeStep
            case 1:
                apiKeyStep
            default:
                completionStep
            }
        }
    }
    
    private var navigationButtons: some View {
        HStack {
            backButton
            Spacer()
            nextButton
        }
        .padding()
    }
    
    private var backButton: some View {
        Button(action: {
            if currentStep > 0 {
                currentStep -= 1
            }
        }) {
            Text("Back")
                .padding()
                .frame(width: 100)
        }
        .opacity(currentStep > 0 ? 1 : 0)
    }
    
    private var nextButton: some View {
        Button(action: {
            handleNextButtonTapped()
        }) {
            Text(currentStep < 2 ? "Next" : "Start")
                .padding()
                .frame(width: 100)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .disabled(isNextButtonDisabled)
    }
    
    private var isNextButtonDisabled: Bool {
        return currentStep == 1 && (
            settingsViewModel.openAIAPIKey.isEmpty ||
            settingsViewModel.pineconeAPIKey.isEmpty ||
            settingsViewModel.pineconeProjectId.isEmpty
        )
    }
    
    // MARK: - Step Content
    
    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)
            
            Text("Welcome to OpenCone")
                .font(.largeTitle.bold())
            
            Text("OpenCone is a Retrieval Augmented Generation system for iOS that helps you process documents, generate vector embeddings, and perform semantic search.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "doc.fill", text: "Upload and process documents")
                FeatureRow(icon: "rectangle.and.text.magnifyingglass", text: "Extract and chunk text content")
                FeatureRow(icon: "chart.bar.doc.horizontal", text: "Generate vector embeddings")
                FeatureRow(icon: "magnifyingglass", text: "Perform semantic search")
                FeatureRow(icon: "brain", text: "Get AI-generated answers")
            }
            .padding(.top, 20)
        }
    }
    
    private var apiKeyStep: some View {
        APIKeyEntryView(settingsViewModel: settingsViewModel)
    }
    
    private var completionStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.green)
            
            Text("Ready to Go!")
                .font(.largeTitle.bold())
            
            Text("You're all set to start using OpenCone! Click Start to begin exploring your documents.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Here's what you can do:")
                    .font(.headline)
                    .padding(.bottom, 8)
                
                FeatureRow(icon: "1.circle.fill", text: "Add documents in the Documents tab")
                FeatureRow(icon: "2.circle.fill", text: "Process them to extract text and generate embeddings")
                FeatureRow(icon: "3.circle.fill", text: "Search across documents in the Search tab")
                FeatureRow(icon: "4.circle.fill", text: "Get AI-generated answers based on your documents")
            }
            .padding(.top, 20)
        }
    }
    
    // MARK: - Logic
    
    private func handleNextButtonTapped() {
        if currentStep < 2 {
            currentStep += 1
        } else {
            settingsViewModel.saveSettings()
            onComplete()
        }
    }
}

// MARK: - API Key Entry View
struct APIKeyEntryView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)
            
            Text("API Keys Required")
                .font(.largeTitle.bold())
            
            Text("OpenCone needs API keys for OpenAI and Pinecone to function. These keys will be stored securely.")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 20) {
                // OpenAI API Key
                apiKeyField(
                    title: "OpenAI API Key",
                    placeholder: "sk-...",
                    text: $settingsViewModel.openAIAPIKey,
                    helpText: "Get an API key at openai.com",
                    isValid: true
                )
                
                // Pinecone API Key and Project ID
                VStack(alignment: .leading) {
                    Text("Pinecone API Key (starts with 'pcsk_')")
                        .font(.headline)
                    
                    SecureField("pcsk_...", text: $settingsViewModel.pineconeAPIKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isPineconeKeyValid ? Color.clear : Color.red.opacity(0.5), lineWidth: 1)
                        )
                    
                    Text("Pinecone Project ID")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    TextField("e.g., 1234abcd-ef56-7890-gh12-345678ijklmn", text: $settingsViewModel.pineconeProjectId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(settingsViewModel.pineconeProjectId.isEmpty ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                    
                    Text("IMPORTANT: Pinecone requires both an API Key (starts with 'pcsk_') AND Project ID for JWT authentication. Find both in the Pinecone console under API Keys.")
                        .font(.caption)
                        .foregroundColor(isPineconeConfigValid ? .secondary : .red)
                }
            }
            .padding(.top, 20)
        }
    }
    
    private var isPineconeKeyValid: Bool {
        return !settingsViewModel.pineconeAPIKey.isEmpty && settingsViewModel.pineconeAPIKey.hasPrefix("pcsk_")
    }
    
    private var isPineconeConfigValid: Bool {
        return !settingsViewModel.pineconeProjectId.isEmpty && isPineconeKeyValid
    }
    
    private func apiKeyField(title: String, placeholder: String, text: Binding<String>, helpText: String, isValid: Bool) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.headline)
            
            SecureField(placeholder, text: text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            Text(helpText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    WelcomeView(settingsViewModel: SettingsViewModel()) {
        print("Setup completed")
    }
}
