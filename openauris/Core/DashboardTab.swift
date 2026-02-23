import Foundation

enum DashboardTab: String, CaseIterable, Identifiable {
    case home
    case history
    case models
    case stats
    case achievements
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .history: return "History"
        case .models: return "Models"
        case .stats: return "Stats"
        case .achievements: return "Achievements"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .history: return "clock.arrow.circlepath"
        case .models: return "square.stack.3d.up"
        case .stats: return "chart.bar"
        case .achievements: return "rosette"
        case .settings: return "gearshape"
        }
    }
}
