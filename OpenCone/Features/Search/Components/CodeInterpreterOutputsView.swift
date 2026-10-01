import SwiftUI
import UIKit

/// What the code interpreter produced for the latest answer: charts, printed output and errors
struct CodeInterpreterOutputsView: View {
    let outputs: [CodeInterpreterOutput]
    @State private var expandedOutputs: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.orange)
                Text("Code interpreter")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(outputs.count)")
                    .font(.caption.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ForEach(outputs) { output in
                outputCard(for: output)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func outputCard(for output: CodeInterpreterOutput) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title(for: output), systemImage: icon(for: output))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(output.type == .error ? Color.red : Color.secondary)
                Spacer()
                if output.type == .logs, output.content.count > 200 {
                    Button {
                        if expandedOutputs.contains(output.id) {
                            expandedOutputs.remove(output.id)
                        } else {
                            expandedOutputs.insert(output.id)
                        }
                    } label: {
                        Image(systemName: expandedOutputs.contains(output.id) ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                    }
                    .accessibilityLabel(expandedOutputs.contains(output.id) ? "Show less" : "Show all output")
                }
            }

            switch output.type {
            case .logs:
                let showsAll = expandedOutputs.contains(output.id) || output.content.count <= 200
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(showsAll ? output.content : String(output.content.prefix(200)) + "…")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color.white)
                        .textSelection(.enabled)
                        .padding(10)
                }
                .background(Color.black.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            case .image:
                image(for: output)

            case .error:
                Text(output.content)
                    .font(.caption)
                    .foregroundStyle(Color.red)
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func image(for output: CodeInterpreterOutput) -> some View {
        if output.content.hasPrefix("http") {
            AsyncImage(url: URL(string: output.content)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 160)
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    Label("The chart didn't load", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(Color.red)
                @unknown default:
                    EmptyView()
                }
            }
        } else if let data = Data(base64Encoded: output.content), let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Generated chart")
        } else {
            Label("The chart's data couldn't be read", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(Color.red)
        }
    }

    private func title(for output: CodeInterpreterOutput) -> String {
        switch output.type {
        case .logs: return "Output"
        case .image: return "Chart"
        case .error: return "Error"
        }
    }

    private func icon(for output: CodeInterpreterOutput) -> String {
        switch output.type {
        case .logs: return "terminal"
        case .image: return "chart.bar.xaxis"
        case .error: return "exclamationmark.triangle"
        }
    }
}
