import Foundation

enum DashboardTab: String, CaseIterable, Identifiable {
    case overview
    case activity
    case models
    case insights
    case milestones
    case preferences

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .activity: return "Activity"
        case .models: return "Models"
        case .insights: return "Insights"
        case .milestones: return "Milestones"
        case .preferences: return "Preferences"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: return "house"
        case .activity: return "clock.arrow.circlepath"
        case .models: return "square.stack.3d.up"
        case .insights: return "chart.bar"
        case .milestones: return "rosette"
        case .preferences: return "gearshape"
        }
    }
}
