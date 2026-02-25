import SwiftUI

enum DashboardTheme {
    static let pagePadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 18
    static let cardCornerRadius: CGFloat = 18
    static let sidebarMinWidth: CGFloat = 220
    static let sidebarIdealWidth: CGFloat = 252

    static func windowBackground(_ colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color(red: 0.06, green: 0.09, blue: 0.15), Color(red: 0.09, green: 0.15, blue: 0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        return LinearGradient(
            colors: [Color(red: 0.93, green: 0.96, blue: 0.99), Color(red: 0.89, green: 0.94, blue: 0.99)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func accentColor(for tab: DashboardTab) -> Color {
        switch tab {
        case .overview: return .cyan
        case .activity: return .blue
        case .models: return .mint
        case .insights: return .indigo
        case .milestones: return .orange
        case .preferences: return .teal
        }
    }
}
