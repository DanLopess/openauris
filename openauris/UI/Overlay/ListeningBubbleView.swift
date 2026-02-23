import SwiftUI

struct ListeningBubbleView: View {
    @ObservedObject var viewModel: BubbleViewModel

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(lineWidth: 4)
                    .foregroundStyle(AngularGradient(colors: [Color.cyan, Color.blue, Color.pink, Color.orange], center: .center))
                    .frame(width: 42 + CGFloat(viewModel.level * 80), height: 42 + CGFloat(viewModel.level * 80))
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: viewModel.level)

                AppBrandLogo(size: 26)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(bodyText)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(width: 380)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 18, x: 0, y: 10)
    }

    private var title: String {
        switch viewModel.state {
        case .hidden: return ""
        case .listening: return "Listening"
        case .processing: return "Processing"
        case .success: return "Inserted"
        case .error: return "Error"
        }
    }

    private var bodyText: String {
        switch viewModel.state {
        case .hidden:
            return ""
        case .listening:
            return viewModel.partialText.isEmpty ? "Speak now..." : viewModel.partialText
        case .processing:
            return "Finalizing transcription..."
        case .success:
            return "Text inserted into focused app."
        case .error(let message):
            return message
        }
    }
}
