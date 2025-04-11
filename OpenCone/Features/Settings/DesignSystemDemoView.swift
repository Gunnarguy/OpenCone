import SwiftUI

struct DesignSystemDemoView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Typography Section
                sectionHeader("Typography")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Large Title").font(.largeTitle)
                    Text("Title").font(.title)
                    Text("Title 2").font(.title2)
                    Text("Title 3").font(.title3)
                    Text("Headline").font(.headline)
                    Text("Body").font(.body)
                    Text("Callout").font(.callout)
                    Text("Subheadline").font(.subheadline)
                    Text("Footnote").font(.footnote)
                    Text("Caption").font(.caption)
                    Text("Caption 2").font(.caption2)
                }
                .padding()
                .background(theme.cardBackgroundColor)
                .cornerRadius(12)

                // Colors Section
                sectionHeader("Theme Colors")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    colorItem("Primary", theme.primaryColor)
                    colorItem("Secondary", theme.secondaryColor)
                    colorItem("Background", theme.backgroundColor)
                    colorItem("Card Background", theme.cardBackgroundColor)
                    colorItem("Text Primary", theme.textPrimaryColor)
                    colorItem("Text Secondary", theme.textSecondaryColor)
                    colorItem("Accent", theme.accentColor)
                    colorItem("Success", theme.successColor)
                    colorItem("Warning", theme.warningColor)
                    colorItem("Error", theme.errorColor)
                    colorItem("Info", theme.infoColor)
                }

                // Buttons Section
                sectionHeader("Buttons")

                VStack(spacing: 16) {
                    OCButton(title: "Primary Button", icon: "star.fill", action: {})
                    OCButton(
                        title: "Secondary Button", icon: "heart.fill", style: .secondary, action: {}
                    )
                    OCButton(
                        title: "Outline Button", icon: "bookmark.fill", style: .outline, action: {})
                    OCButton(
                        title: "Destructive Button", icon: "trash.fill", style: .destructive,
                        action: {})
                    OCButton(
                        title: "Text Button", icon: "info.circle.fill", style: .text, action: {})
                }

                // Disabled Buttons
                sectionHeader("Disabled Buttons")

                VStack(spacing: 16) {
                    OCButton(title: "Primary Button", icon: "star.fill", action: {})
                        .disabled(true)
                    OCButton(
                        title: "Secondary Button", icon: "heart.fill", style: .secondary, action: {}
                    )
                    .disabled(true)
                    OCButton(
                        title: "Outline Button", icon: "bookmark.fill", style: .outline, action: {}
                    )
                    .disabled(true)
                    OCButton(
                        title: "Destructive Button", icon: "trash.fill", style: .destructive,
                        action: {}
                    )
                    .disabled(true)
                }

                // Badges Section
                sectionHeader("Badges")

                HStack(spacing: 10) {
                    OCBadge("Success", style: .success)
                    OCBadge("Error", style: .error)
                    OCBadge("Warning", style: .warning)
                    OCBadge("Info", style: .info)
                    OCBadge("Neutral", style: .neutral)
                    OCBadge("Custom", style: .custom(.purple))
                }

                // Cards Section
                sectionHeader("Cards")

                VStack(spacing: 16) {
                    OCCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Basic Card")
                                .font(.headline)
                            Text("This is a standard card with default styling.")
                                .font(.body)
                                .foregroundColor(theme.textSecondaryColor)
                        }
                    }

                    OCCard(showShadow: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Card Without Shadow")
                                .font(.headline)
                            Text("This card doesn't have a shadow effect.")
                                .font(.body)
                                .foregroundColor(theme.textSecondaryColor)
                        }
                    }
                }
            }
            .padding()
        }
        .background(theme.backgroundColor.ignoresSafeArea())
        .navigationTitle("Design System")
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.vertical, 4)
    }

    private func colorItem(_ name: String, _ color: Color) -> some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(color)
                .frame(height: 50)
                .cornerRadius(6)

            Text(name)
                .font(.caption)
                .foregroundColor(theme.textSecondaryColor)
        }
    }
}
