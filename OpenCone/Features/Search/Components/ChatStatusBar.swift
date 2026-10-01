import SwiftUI

/// The compact bar above the conversation, as in OpenResponses: the model (tap to switch), its
/// reasoning effort, a badge for each tool that's on, and the answer settings
struct ChatStatusBar: View {
    @ObservedObject var settings: SettingsViewModel
    let onShowModels: () -> Void
    let onShowSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    modelBadge

                    if settings.isReasoning, settings.availableReasoningEffortOptions.count > 1 {
                        effortBadge
                    }
                    if settings.webSearchEnabled {
                        toolBadge("globe", tint: .blue, label: "Web search on")
                    }
                    if settings.codeInterpreterEnabled, settings.supportsCodeInterpreter {
                        toolBadge("chevron.left.forwardslash.chevron.right", tint: .orange, label: "Code interpreter on")
                    }
                    if settings.serviceTier == "flex" {
                        toolBadge("tortoise", tint: .green, label: "Flex tier: slower, half the price")
                    } else if settings.serviceTier == "fast" {
                        toolBadge("hare", tint: .orange, label: "Fast tier: quicker, higher price")
                    }
                    if settings.rerankingEnabled {
                        toolBadge("arrow.up.arrow.down", tint: .purple, label: "Reranking on")
                    }
                    if settings.hybridSearchEnabled, settings.indexSupportsHybridSearch {
                        toolBadge("arrow.triangle.merge", tint: .indigo, label: "Hybrid search on")
                    }
                }
            }

            Spacer(minLength: 8)

            Button(action: onShowSettings) {
                Image(systemName: "gearshape")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .fixedSize()
            .accessibilityLabel("Answer settings")
            .accessibilityShowsLargeContentViewer()
        }
        .padding(.horizontal, 16)
        .background(Color.secondary.opacity(0.05))
        .font(.caption)
    }

    // MARK: - Model

    private var modelBadge: some View {
        Menu {
            Picker("Model", selection: Binding(
                get: { settings.completionModel },
                set: { settings.selectCompletionModel($0) }
            )) {
                ForEach(settings.availableCompletionModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            Divider()
            Button(action: onShowModels) {
                Label("All models and descriptions", systemImage: "list.bullet.rectangle")
            }
        } label: {
            HStack(spacing: 4) {
                Text(settings.completionModel)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.primary) // not `.primary`, which resolves inside the badge's model color
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(modelColor.opacity(0.15))
            .foregroundStyle(modelColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .accessibilityLabel("Model")
        .accessibilityValue(CurrentModelCatalog.spokenName(for: settings.completionModel))
    }

    private var modelColor: Color {
        let model = settings.completionModel
        if CurrentModelCatalog.isModern(model) {
            return .teal
        } else if model.contains("gpt-5") {
            return .indigo
        } else if model.contains("o1") || model.contains("o3") {
            return .purple
        } else if model.contains("4o") {
            return .blue
        } else if model.contains("4") {
            return .green
        }
        return .gray
    }

    // MARK: - Effort

    private var effortBadge: some View {
        Menu {
            Picker("Reasoning effort", selection: $settings.reasoningEffort) {
                ForEach(settings.availableReasoningEffortOptions, id: \.self) { level in
                    Text(ReasoningEffortText.long(level)).tag(level)
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "brain")
                    .font(.caption2)
                Text(ReasoningEffortText.short(settings.reasoningEffort))
                    .fontWeight(.medium)
            }
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12))
            .foregroundStyle(.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .accessibilityLabel("Reasoning effort")
        .accessibilityValue(ReasoningEffortText.long(settings.reasoningEffort))
    }

    // MARK: - Tools

    private func toolBadge(_ systemImage: String, tint: Color, label: String) -> some View {
        Image(systemName: systemImage)
            .font(.caption2)
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(tint.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .accessibilityLabel(label)
    }
}

/// How reasoning efforts read in menus and badges
enum ReasoningEffortText {
    static func short(_ level: String) -> String {
        switch level {
        case "none": return "Off"
        case "minimal": return "Min"
        case "xhigh": return "XHigh"
        default: return level.capitalized
        }
    }

    static func long(_ level: String) -> String {
        switch level {
        case "none": return "Off (fastest)"
        case "minimal": return "Minimal"
        case "low": return "Low"
        case "medium": return "Medium"
        case "high": return "High"
        case "xhigh": return "Extra high"
        case "max": return "Maximum (slowest)"
        default: return level.capitalized
        }
    }
}
