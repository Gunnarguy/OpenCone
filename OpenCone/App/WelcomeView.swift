import Combine
import Foundation
import SwiftUI
import UIKit

// Import the logger and view model dependencies

// MARK: - Welcome View

/// `WelcomeView` guides the user through the initial setup process on the first launch
/// or when required API keys are missing. It consists of multiple steps:
/// 1. Welcome message and feature overview.
/// 2. API Key entry (OpenAI and Pinecone).
/// 3. Completion message.
struct WelcomeView: View {
    // MARK: - Properties

    /// The view model managing application settings, including API keys.
    @ObservedObject var settingsViewModel: SettingsViewModel
    /// A closure to call when the welcome/setup process is completed successfully.
    let onComplete: () -> Void
    /// Shared logger instance for logging setup events.
    private let logger = Logger.shared

    /// State variable to track the current step in the welcome flow (0, 1, or 2).
    @State private var currentStep = 0

    // MARK: - Body

    var body: some View {
        VStack {
            // Visual indicator showing the current step in the process.
            progressIndicator

            Spacer()  // Pushes content towards the center vertically.

            // Displays the content relevant to the current step.
            currentStepContent

            Spacer()  // Pushes content towards the center vertically.

            // Contains the 'Back' and 'Next'/'Start' buttons for navigation.
            navigationButtons
        }
        .padding()  // Add padding around the main VStack.
    }

    // MARK: - View Components

    /// A horizontal row of circles indicating the total steps and the current active step.
    private var progressIndicator: some View {
        HStack {
            // Create a circle for each step (0, 1, 2).
            ForEach(0..<3) { step in
                Circle()
                    // Fill the circle blue if it's the current step, otherwise gray.
                    .fill(step == currentStep ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)  // Small circle size.
            }
        }
        .padding(.top, 40)  // Add padding at the top.
    }

    /// Dynamically displays the content view based on the `currentStep`.
    @ViewBuilder  // Allows using switch statements to return different views.
    private var currentStepContent: some View {
        Group {  // Group is used here to satisfy @ViewBuilder requirements.
            switch currentStep {
            case 0:
                welcomeStep  // Show the initial welcome message and features.
            case 1:
                apiKeyStep  // Show the API key entry form.
            default:  // case 2
                completionStep  // Show the final "Ready to Go" message.
            }
        }
    }

    /// Contains the 'Back' and 'Next'/'Start' navigation buttons at the bottom.
    private var navigationButtons: some View {
        HStack {
            backButton  // The 'Back' button.
            Spacer()  // Pushes buttons to opposite ends.
            nextButton  // The 'Next' or 'Start' button.
        }
        .padding()  // Add padding around the HStack.
    }

    /// The 'Back' button, visible only after the first step.
    private var backButton: some View {
        Button(action: {
            // Decrement the step if not on the first step.
            if currentStep > 0 {
                currentStep -= 1
            }
        }) {
            Text("Back")
                .padding()
                .frame(width: 100)  // Fixed width for consistent layout.
        }
        // Make the button invisible (but still take space) on the first step.
        .opacity(currentStep > 0 ? 1 : 0)
    }

    /// The 'Next' button, which changes to 'Start' on the final step.
    /// It's disabled on the API key step if keys are missing.
    private var nextButton: some View {
        Button(action: {
            // Handles advancing the step or completing the setup.
            handleNextButtonTapped()
        }) {
            // Button label changes on the last step.
            Text(currentStep < 2 ? "Next" : "Start")
                .padding()
                .frame(width: 100)  // Fixed width.
                .background(Color.blue)  // Blue background.
                .foregroundColor(.white)  // White text.
                .cornerRadius(8)  // Rounded corners.
        }
        // Disable the button based on validation logic.
        .disabled(isNextButtonDisabled)
    }

    /// Determines if the 'Next' button should be disabled.
    /// On step 1, requires non-empty keys and live validation to be valid (rate limited also allowed).
    private var isNextButtonDisabled: Bool {
        guard currentStep == 1 else { return false }
        // Basic emptiness checks
        guard !settingsViewModel.openAIAPIKey.isEmpty,
              !settingsViewModel.pineconeAPIKey.isEmpty,
              !settingsViewModel.pineconeProjectId.isEmpty else {
            return true
        }
        // Live validation checks
        let openAIValid: Bool = {
            switch settingsViewModel.openAIStatus {
            case .valid, .rateLimited: return true
            default: return false
            }
        }()
        let pineconeValid: Bool = {
            switch settingsViewModel.pineconeStatus {
            case .valid, .rateLimited: return true
            default: return false
            }
        }()
        return !(openAIValid && pineconeValid)
    }

    // MARK: - Step Content Views

    /// The content view for the first step (index 0).
    /// Displays a welcome message and lists the app's key features.
    private var welcomeStep: some View {
        VStack(spacing: 20) {
            // App icon representation.
            Image(systemName: "doc.text.magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.blue)

            // Main welcome title.
            Text("Welcome to OpenCone")
                .font(.largeTitle.bold())

            // App description.
            Text(
                "OpenCone is a Retrieval Augmented Generation system for iOS that helps you process documents, generate vector embeddings, and perform semantic search."
            )
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundColor(.secondary)

            // List of key features using the FeatureRow helper view.
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "doc.fill", text: "Upload and process documents")
                FeatureRow(
                    icon: "rectangle.and.text.magnifyingglass",
                    text: "Extract and chunk text content")
                FeatureRow(icon: "chart.bar.doc.horizontal", text: "Generate vector embeddings")
                FeatureRow(icon: "magnifyingglass", text: "Perform semantic search")
                FeatureRow(icon: "brain", text: "Get AI-generated answers")
            }
            .padding(.top, 20)  // Add padding above the feature list.
        }
    }

    /// The content view for the second step (index 1).
    /// Displays the `APIKeyEntryView` for entering API keys.
    private var apiKeyStep: some View {
        APIKeyEntryView(settingsViewModel: settingsViewModel)
            .onAppear {
                // Trigger initial validation when user reaches this step
                settingsViewModel.validateAll()
            }
    }

    /// The content view for the final step (index 2).
    /// Displays a confirmation message and a summary of actions.
    private var completionStep: some View {
        VStack(spacing: 20) {
            // Success icon.
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.green)

            // Completion title.
            Text("Ready to Go!")
                .font(.largeTitle.bold())

            // Confirmation message.
            Text(
                "You're all set to start using OpenCone! Click Start to begin exploring your documents."
            )
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundColor(.secondary)

            // Summary of next steps using the FeatureRow helper view.
            VStack(alignment: .leading, spacing: 12) {
                Text("Here's what you can do:")
                    .font(.headline)
                    .padding(.bottom, 8)

                FeatureRow(icon: "1.circle.fill", text: "Add documents in the Documents tab")
                FeatureRow(
                    icon: "2.circle.fill",
                    text: "Process them to extract text and generate embeddings")
                FeatureRow(icon: "3.circle.fill", text: "Search across documents in the Search tab")
                FeatureRow(
                    icon: "4.circle.fill", text: "Get AI-generated answers based on your documents")
            }
            .padding(.top, 20)  // Add padding above the steps list.
        }
    }

    // MARK: - Logic

    /// Handles the action when the 'Next' or 'Start' button is tapped.
    /// Advances the step or calls the `onComplete` closure on the final step.
    private func handleNextButtonTapped() {
        // If not on the last step, increment the current step.
        if currentStep < 2 {
            currentStep += 1
            logger.log(level: .info, message: "WelcomeView: Advanced to step \(currentStep)")
        } else {
            // On the last step, save settings and call the completion handler.
            logger.log(level: .info, message: "WelcomeView: Setup completed.")
            settingsViewModel.saveSettings()  // Persist the entered API keys.
            onComplete()  // Signal that the welcome flow is finished.
        }
    }
}

// MARK: - API Key Entry View

/// A dedicated view for entering OpenAI and Pinecone API keys and Pinecone Project ID.
struct APIKeyEntryView: View {
    /// The settings view model to bind the text fields to.
    @ObservedObject var settingsViewModel: SettingsViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Icon representing API keys.
            Image(systemName: "key.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.blue)

            // Title for the API key step.
            Text("API Keys Required")
                .font(.largeTitle.bold())

            // Informational text about API keys.
            Text(
                "OpenCone needs API keys for OpenAI and Pinecone to function. These keys will be stored securely."
            )
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundColor(.secondary)

            // Form fields for entering keys and project ID.
            VStack(alignment: .leading, spacing: 20) {
                // OpenAI API Key field using the helper function.
                apiKeyField(
                    title: "OpenAI API Key",
                    placeholder: "sk-...",  // Placeholder text.
                    text: $settingsViewModel.openAIAPIKey,  // Binding to the view model.
                    helpText: "Get your API key at:",  // Helper text.
                    helpURL: "https://platform.openai.com/api-keys",
                    isValid: true  // Basic validation (can be enhanced).
                )

                // Pinecone API Key and Project ID fields.
                VStack(alignment: .leading) {
                    Text("Pinecone API Key (starts with 'pcsk_')")
                        .font(.headline)

                    // Secure field for Pinecone API Key.
                    SecureField("pcsk_...", text: $settingsViewModel.pineconeAPIKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(
                                    isPineconeKeyValid ? Color.clear : Color.red.opacity(0.5),
                                    lineWidth: 1)
                        )

                    // Help link for Pinecone API keys
                    HStack {
                        Text("Create or find your API key at:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Link(
                            "Pinecone API Keys",
                            destination: URL(string: "https://app.pinecone.io/projects/keys")!
                        )
                        .font(.caption)
                    }
                    .padding(.bottom, 4)

                    Text("Pinecone Project ID")
                        .font(.headline)
                        .padding(.top, 8)

                    // Secure field for Pinecone Project ID so it isn't exposed during setup.
                    SecureField(
                        "e.g., 1234abcd-ef56-7890-gh12-345678ijklmn",
                        text: $settingsViewModel.pineconeProjectId
                    )
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(
                                settingsViewModel.pineconeProjectId.isEmpty
                                    ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
                    )

                    // Help link for Pinecone Projects
                    HStack {
                        Text(
                            "Find your Project ID at: (You might be met with a red banner, do not mind it)"
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                        Link(
                            "Pinecone Projects",
                            destination: URL(
                                string: "https://app.pinecone.io/organizations/projects")!
                        )
                        .font(.caption)
                    }
                    .padding(.bottom, 4)

                    // Important note about Pinecone authentication requirements.
                    Text(
                        "IMPORTANT: Pinecone requires both an API Key (starts with 'pcsk_') AND Project ID for JWT authentication."
                    )
                    .font(.caption)
                    .foregroundColor(isPineconeConfigValid ? .secondary : .red)
                }
            }

            // Live credential status and validate action
            VStack(alignment: .leading, spacing: 12) {
                Text("Credential Status")
                    .font(.subheadline)
                    .bold()

                HStack(spacing: 10) {
                    statusBadge("OpenAI", settingsViewModel.openAIStatus)
                    statusBadge("Pinecone", settingsViewModel.pineconeStatus)

                    Spacer()

                    Button {
                        settingsViewModel.validateAll()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.shield")
                            Text("Validate")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }

                // Hint text
                Group {
                    switch settingsViewModel.openAIStatus {
                    case .invalid(let msg):
                        Text("OpenAI: \(msg)").font(.caption).foregroundColor(.red)
                    case .rateLimited(let s):
                        Text("OpenAI: Rate limited, retry in \(s)s").font(.caption).foregroundColor(.orange)
                    default: EmptyView()
                    }
                }
                Group {
                    switch settingsViewModel.pineconeStatus {
                    case .invalid(let msg):
                        Text("Pinecone: \(msg)").font(.caption).foregroundColor(.red)
                    case .rateLimited(let s):
                        Text("Pinecone: Rate limited, retry in \(s)s").font(.caption).foregroundColor(.orange)
                    default: EmptyView()
                    }
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 4)

            .padding(.top, 20)
        }
    }
    
        /// Small status pill for credential state
    @ViewBuilder
    private func statusBadge(_ label: String, _ status: CredentialStatus) -> some View {
        let (icon, text, color): (String, String, Color) = {
            switch status {
            case .unknown: return ("questionmark.circle", "Unknown", .gray)
            case .validating: return ("hourglass", "Validating…", .orange)
            case .valid: return ("checkmark.circle.fill", "Valid", .green)
            case .invalid: return ("xmark.octagon.fill", "Invalid", .red)
            case .rateLimited(let secs): return ("clock.fill", "Rate limited (\(secs)s)", .orange)
            }
        }()
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text("\(label): \(text)")
                .font(.caption)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
    
    /// Validates if the Pinecone API key is not empty and starts with "pcsk_".
    private var isPineconeKeyValid: Bool {
        // Check if the key is non-empty and has the correct prefix.
        return !settingsViewModel.pineconeAPIKey.isEmpty
            && settingsViewModel.pineconeAPIKey.hasPrefix("pcsk_")
    }

    /// Validates if both the Pinecone Project ID is present and the API key format is valid.
    private var isPineconeConfigValid: Bool {
        // Check if project ID is non-empty and the key format is valid.
        return !settingsViewModel.pineconeProjectId.isEmpty && isPineconeKeyValid
    }

    /// A helper function to create a consistent input field for API keys.
    /// - Parameters:
    ///   - title: The label text for the field.
    ///   - placeholder: The placeholder text inside the field.
    ///   - text: A binding to the string variable holding the key.
    ///   - helpText: Informational text displayed below the field.
    ///   - helpURL: Optional URL where users can get their API key.
    ///   - isValid: A boolean indicating if the current input is considered valid (used for potential styling).
    /// - Returns: A configured `VStack` containing the label, secure field, and help text.
    private func apiKeyField(
        title: String, placeholder: String, text: Binding<String>, helpText: String,
        helpURL: String? = nil, isValid: Bool
    ) -> some View {
        VStack(alignment: .leading) {
            // Field title.
            Text(title)
                .font(.headline)

            // Secure input field.
            SecureField(placeholder, text: text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)

            // Helper text with optional link
            if let urlString = helpURL, let url = URL(string: urlString) {
                HStack {
                    Text(helpText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Link(
                        urlString.replacingOccurrences(of: "https://", with: ""),
                        destination: url
                    )
                    .font(.caption)
                }
            } else {
                Text(helpText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    // Provides a preview instance of the WelcomeView in Xcode Canvas.
    WelcomeView(settingsViewModel: SettingsViewModel()) {
        // Action to perform when the preview setup completes.
        print("Setup completed in Preview")
    }
}
