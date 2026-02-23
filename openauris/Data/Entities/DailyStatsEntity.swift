import Foundation
import SwiftData

@Model
final class DailyStatsEntity {
    @Attribute(.unique) var date: Date
    var words: Int
    var sessions: Int
    var speakingSeconds: Double
    var avgWPM: Double
    var streakQualified: Bool

    init(
        date: Date,
        words: Int = 0,
        sessions: Int = 0,
        speakingSeconds: Double = 0,
        avgWPM: Double = 0,
        streakQualified: Bool = false
    ) {
        self.date = date
        self.words = words
        self.sessions = sessions
        self.speakingSeconds = speakingSeconds
        self.avgWPM = avgWPM
        self.streakQualified = streakQualified
    }
}
