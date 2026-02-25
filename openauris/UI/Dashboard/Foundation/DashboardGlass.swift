import SwiftUI

struct DashboardGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let interactive: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            if interactive {
                content
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                content
                    .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
        }
    }
}

extension View {
    func dashboardGlassCard(cornerRadius: CGFloat = DashboardTheme.cardCornerRadius, interactive: Bool = false) -> some View {
        modifier(DashboardGlassCardModifier(cornerRadius: cornerRadius, interactive: interactive))
    }
}
