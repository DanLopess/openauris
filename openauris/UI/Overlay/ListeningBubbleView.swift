import SwiftUI

struct ListeningBubbleView: View {
    var viewModel: BubbleViewModel
    var onDrag: ((CGSize, Bool) -> Void)? = nil

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
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 6)
        .gesture(
            DragGesture()
                .onChanged { value in onDrag?(value.translation, false) }
                .onEnded   { value in onDrag?(value.translation, true)  }
        )
    }

    // MARK: - Ring appearance

    private var ringStyle: AnyShapeStyle {
        switch viewModel.state {
        case .hidden:
            return AnyShapeStyle(Color.clear)
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
