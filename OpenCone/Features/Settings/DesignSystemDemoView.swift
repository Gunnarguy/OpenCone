import SwiftUI

/// View to demonstrate the OpenCone design system components
struct DesignSystemDemoView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: OCDesignSystem.Spacing.large) {
                // Header
                Text("Design System Components")
                    .font(.title.bold())
                    .padding(.bottom, OCDesignSystem.Spacing.medium)

                // Card Styles
                Group {
                    sectionHeader("Cards")

                    // Standard Card
                    OCCard(style: .standard) {
                        cardContent("Standard Card")
                    }

                    // Elevated Card
                    OCCard(style: .elevated) {
                        cardContent("Elevated Card")
                    }

                    // Subtle Card
                    OCCard(style: .subtle) {
                        cardContent("Subtle Card")
                    }

                    // Flat Card
                    OCCard(style: .flat) {
                        cardContent("Flat Card")
                    }

                    // Card without shadow
                    OCCard(showShadow: false) {
                        cardContent("Card without Shadow")
                    }
                }

                // Button Styles
                Group {
                    sectionHeader("Buttons")

                    VStack(spacing: OCDesignSystem.Spacing.standard) {
                        // Primary Button
                        OCButton(
                            title: "Primary Button",
                            icon: "checkmark.circle",
                            style: .primary
                        ) {}

                        // Secondary Button
                        OCButton(
                            title: "Secondary Button",
                            icon: "star",
                            style: .secondary
                        ) {}

                        // Outline Button
                        OCButton(
                            title: "Outline Button",
                            icon: "circle",
                            style: .outline
                        ) {}

                        // Destructive Button
                        OCButton(
                            title: "Destructive Button",
                            icon: "trash",
                            style: .destructive
                        ) {}

                        // Text Button
                        OCButton(
                            title: "Text Button",
                            icon: "text.alignleft",
                            style: .text,
                            fullWidth: false
                        ) {}
                    }
                    .padding()
                    .background(themeManager.currentTheme.backgroundColor)
                    .cornerRadius(OCDesignSystem.Sizing.cornerRadiusMedium)
                }

                // Badges
                Group {
                    sectionHeader("Badges")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: OCDesignSystem.Spacing.medium) {
                            OCBadge("Success", style: .success, icon: "checkmark")
                            OCBadge("Error", style: .error, icon: "xmark")
                            OCBadge("Warning", style: .warning, icon: "exclamationmark.triangle")
                            OCBadge("Info", style: .info, icon: "info.circle")
                            OCBadge("Neutral", style: .neutral)
                            OCBadge("Custom", style: .custom(.purple), icon: "sparkles")
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, OCDesignSystem.Spacing.small)
                }
            }
            .padding()
        }
        .background(themeManager.currentTheme.backgroundColor.ignoresSafeArea())
        .navigationTitle("Design System")
    }

    /// Create consistent section headers
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, OCDesignSystem.Spacing.medium)
    }

    /// Create consistent content for demo cards
    private func cardContent(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: OCDesignSystem.Spacing.small) {
            Text(title)
                .font(.headline)

            Text(
                "This is an example card to demonstrate the styling options available in the OpenCone design system."
            )
            .font(.caption)
            .foregroundColor(themeManager.currentTheme.textSecondaryColor)
        }
    }
}

#Preview {
    NavigationView {
        DesignSystemDemoView()
    }
}
