import Foundation
import SwiftData

@Model
final class AchievementEntity {
    @Attribute(.unique) var id: String
    var unlockedAt: Date?
    var progressValue: Int
    var goalValue: Int
    var title: String
    var subtitle: String

    init(
        id: String,
        unlockedAt: Date? = nil,
        progressValue: Int,
        goalValue: Int,
        title: String,
        subtitle: String
    ) {
        self.id = id
        self.unlockedAt = unlockedAt
        self.progressValue = progressValue
        self.goalValue = goalValue
        self.title = title
        self.subtitle = subtitle
    }
}
