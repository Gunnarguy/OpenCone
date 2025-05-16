import SwiftUI

/// A reusable view for displaying a secure text field within the settings screen.
struct SecureSettingsField: View {
    let title: String
    @Binding var text: String
    @Environment(\.theme) private var theme  // Access theme via environment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(theme.textPrimaryColor)  // Use theme color

            SecureField(title, text: $text)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: OCDesignSystem.Sizing.cornerRadiusSmall)
                        .fill(theme.backgroundColor)  // Use theme color
                )
                .overlay(
                    RoundedRectangle(cornerRadius: OCDesignSystem.Sizing.cornerRadiusSmall)
                        .stroke(
                            theme.textSecondaryColor.opacity(0.3), lineWidth: 1  // Use theme color
                        )
                )
                .foregroundColor(theme.textPrimaryColor)  // Ensure text input color matches theme
        }
    }
}

#Preview {
    // State variable for the preview binding
    @Previewable @State var previewKey = "preview-key-123"  // Add @Previewable

    // No explicit return needed
    VStack {
        SecureSettingsField(title: "Sample API Key", text: $previewKey)
    }
    .padding()
    .withTheme()  // Apply theme for consistent preview
}
