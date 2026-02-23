import Foundation
import Testing
@testable import openauris

struct StatsMathTests {
    @Test
    func wordsPerMinuteHandlesZeroDuration() {
        #expect(StatsMath.wordsPerMinute(words: 120, speakingSeconds: 0) == 0)
    }

    @Test
    func wordsPerMinuteComputesExpectedValue() {
        let wpm = StatsMath.wordsPerMinute(words: 150, speakingSeconds: 60)
        #expect(Int(wpm.rounded()) == 150)
    }

    @Test
    func currentStreakCountsContiguousDays() {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!

        let streak = StatsMath.currentStreak(
            qualifiedDates: [today, yesterday, threeDaysAgo],
            today: today,
            calendar: calendar
        )

        #expect(streak == 2)
    }
}
