import SwiftUI

struct ListeningBubbleView: View {
    var viewModel: BubbleViewModel

    var body: some View {
        ZStack {
            // Animated ring — colour communicates state, size communicates audio level
            Circle()
                .stroke(lineWidth: 4)
                .foregroundStyle(ringStyle)
                .frame(
                    width: 22 + CGFloat(viewModel.level * 16),
                    height: 22 + CGFloat(viewModel.level * 16)
                )
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: viewModel.level)
                .animation(.easeInOut(duration: 0.3), value: viewModel.state)

            AppBrandLogo(size: 16)
        }
        .background(.clear)
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Ring appearance

    private var ringStyle: AnyShapeStyle {
        switch viewModel.state.ringStyleToken {
        case .hidden:
            return AnyShapeStyle(Color.clear)
        case .preparing:
            return AnyShapeStyle(Color.gray.opacity(0.65))
        case .listening:
            return AnyShapeStyle(
                AngularGradient(
                    colors: [.cyan, .blue, .pink, .orange, .cyan],
                    center: .center
                )
            )
        case .processing:
            return AnyShapeStyle(Color.blue.opacity(0.8))
        case .success:
            return AnyShapeStyle(Color.green.opacity(0.9))
        case .error:
            return AnyShapeStyle(Color.red.opacity(0.9))
        }
    }
}
