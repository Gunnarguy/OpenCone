import SwiftUI

struct ThemeSettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var selectedTheme: OCTheme

    init() {
        _selectedTheme = State(initialValue: ThemeManager.shared.currentTheme)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("App Theme")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(OCTheme.allThemes, id: \.id) { theme in
                    themePreview(theme)
                        .onTapGesture {
                            selectedTheme = theme
                            themeManager.setTheme(theme)
                        }
                }
            }
        }
        .padding()
        .background(themeManager.currentTheme.backgroundColor)
    }

    private func themePreview(_ theme: OCTheme) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.backgroundColor)
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )

                VStack {
                    Circle()
                        .fill(theme.primaryColor)
                        .frame(width: 20, height: 20)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.secondaryColor)
                        .frame(width: 40, height: 6)
                }
            }

            Text(theme.name)
                .font(.caption)
                .foregroundColor(themeManager.currentTheme.textPrimaryColor)

            // Selected indicator
            if selectedTheme.id == theme.id {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .font(.callout)
            } else {
                Circle()
                    .stroke(themeManager.currentTheme.textSecondaryColor.opacity(0.3), lineWidth: 1)
                    .frame(width: 16, height: 16)
            }
        }
    }
}
