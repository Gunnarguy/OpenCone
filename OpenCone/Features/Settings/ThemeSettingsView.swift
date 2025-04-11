import SwiftUI

struct ThemeSettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var selectedTheme: OCTheme
    @State private var selectionScale: [String: CGFloat] = [:]

    init() {
        _selectedTheme = State(initialValue: ThemeManager.shared.currentTheme)

        // Initialize all themes with normal scale
        var initialScales: [String: CGFloat] = [:]
        for theme in OCTheme.allThemes {
            initialScales[theme.id] = 1.0
        }
        _selectionScale = State(initialValue: initialScales)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: OCDesignSystem.Spacing.large) {
                // Header
                VStack(spacing: OCDesignSystem.Spacing.standard) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 40))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .padding(.bottom, 8)

                    Text("Select App Theme")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("Choose a theme that matches your style and enhances readability.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(themeManager.currentTheme.textSecondaryColor)
                }
                .padding(.bottom)

                // Theme Grid
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: OCDesignSystem.Spacing.large
                ) {
                    ForEach(OCTheme.allThemes, id: \.id) { theme in
                        themePreview(theme)
                            .scaleEffect(selectionScale[theme.id] ?? 1.0)
                            .onTapGesture {
                                selectTheme(theme)
                            }
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .background(themeManager.currentTheme.backgroundColor.ignoresSafeArea())
        .navigationTitle("App Theme")
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTheme.id)
    }

    private func selectTheme(_ theme: OCTheme) {
        // First reset all scales
        for themeId in selectionScale.keys {
            selectionScale[themeId] = 1.0
        }

        // Animate the selected theme
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            selectionScale[theme.id] = 1.05
            selectedTheme = theme

            // After a short delay, reset the scale
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    selectionScale[theme.id] = 1.0
                }
            }
        }

        themeManager.setTheme(theme)
    }

    private func themePreview(_ theme: OCTheme) -> some View {
        VStack(spacing: OCDesignSystem.Spacing.small) {
            // Theme preview card
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: OCDesignSystem.Sizing.cornerRadiusMedium)
                    .fill(theme.backgroundColor)
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: OCDesignSystem.Sizing.cornerRadiusMedium)
                            .stroke(
                                selectedTheme.id == theme.id
                                    ? theme.primaryColor
                                    : themeManager.currentTheme.textSecondaryColor.opacity(0.1),
                                lineWidth: selectedTheme.id == theme.id ? 2 : 1
                            )
                    )
                    .shadow(
                        color: selectedTheme.id == theme.id
                            ? theme.primaryColor.opacity(0.3) : Color.black.opacity(0.05),
                        radius: 8,
                        x: 0,
                        y: 4
                    )

                // Theme preview content
                VStack(spacing: 12) {
                    // Header bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.primaryColor)
                        .frame(height: 8)
                        .padding(.horizontal, 16)

                    // Content preview
                    HStack(spacing: 8) {
                        // Sidebar
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.secondaryColor.opacity(0.5))
                            .frame(width: 20)

                        // Content area
                        VStack(alignment: .leading, spacing: 4) {
                            // Title
                            RoundedRectangle(cornerRadius: 2)
                                .fill(theme.textPrimaryColor.opacity(0.7))
                                .frame(width: 60, height: 6)

                            // Content lines
                            Group {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(theme.textSecondaryColor.opacity(0.4))
                                    .frame(height: 4)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(theme.textSecondaryColor.opacity(0.4))
                                    .frame(width: 80, height: 4)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)

                    // Button
                    Capsule()
                        .fill(theme.primaryColor)
                        .frame(height: 12)
                        .padding(.horizontal, 40)
                }
                .padding(12)

                // Selected indicator
                if selectedTheme.id == theme.id {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(theme.primaryColor)
                                .background(
                                    Circle()
                                        .fill(theme.backgroundColor)
                                        .padding(2)
                                )
                                .font(.system(size: 22, weight: .semibold))
                                .offset(x: 6, y: -6)
                        }
                        Spacer()
                    }
                }
            }

            // Theme name
            Text(theme.name)
                .font(.subheadline.bold())
                .foregroundColor(
                    selectedTheme.id == theme.id
                        ? themeManager.currentTheme.primaryColor
                        : themeManager.currentTheme.textPrimaryColor
                )
        }
    }
}
