import SwiftUI

/// A reusable row for settings that navigate to another view.
struct SettingsNavigationRow<Destination: View, Accessory: View>: View {  // Make Accessory generic
    let title: String
    let subtitle: String?  // Optional subtitle for more context
    let systemImage: String?  // Optional leading icon
    let destination: Destination
    let accessory: Accessory  // Use the generic Accessory type

    @Environment(\.theme) private var theme

    // Initializer accepting a @ViewBuilder closure for the accessory
    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        destination: Destination,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }  // Default to EmptyView
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.destination = destination
        self.accessory = accessory()  // Call the builder to get the view
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: OCDesignSystem.Spacing.medium) {
                // Optional leading icon
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .foregroundColor(theme.primaryColor)
                        .frame(width: 20)  // Consistent icon width
                }

                // Title and optional subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(theme.textPrimaryColor)

                    if let subtitle = subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(theme.textSecondaryColor)
                    }
                }

                Spacer()

                // Use the accessory view directly
                accessory

                // Standard chevron indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(theme.textSecondaryColor)
            }
            .contentShape(Rectangle())  // Ensure the whole row is tappable
        }
        .buttonStyle(PlainButtonStyle())  // Use PlainButtonStyle for clean navigation link appearance
    }
}

// MARK: - Preview

// Wrap the preview content in a struct to avoid macro issues with generics
struct SettingsNavigationRow_Previews: PreviewProvider {
    // Define the example destination view outside the previews property
    struct SampleDestination: View {
        var body: some View {
            Text("Sample Destination View")
                .navigationTitle("Destination")
        }
    }

    static var previews: some View {
        // Example destination view for preview - Removed from here
        // struct SampleDestination: View { ... }

        NavigationView {
            OCCard(style: .standard) {
                VStack(spacing: 0) {
                    // Example 1: Basic row
                    SettingsNavigationRow(
                        title: "Profile Settings",
                        destination: SampleDestination()  // Use the moved struct
                    )

                    Divider()

                    // Example 2: With subtitle and icon
                    SettingsNavigationRow(
                        title: "Notifications",
                        subtitle: "Manage push alerts",
                        systemImage: "bell.fill",
                        destination: SampleDestination()  // Use the moved struct
                    )

                    Divider()

                    // Example 3: With accessory view (color dots)
                    SettingsNavigationRow(
                        title: "Theme",
                        subtitle: "Midnight",
                        systemImage: "paintpalette.fill",
                        destination: SampleDestination()  // Use the moved struct
                    ) {  // Use trailing closure syntax for accessory
                        HStack(spacing: 4) {
                            Circle().fill(Color.blue).frame(width: 16, height: 16)
                            Circle().fill(Color.purple).frame(width: 16, height: 16)
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Settings Rows")
            .withTheme()
        }
    }
}
