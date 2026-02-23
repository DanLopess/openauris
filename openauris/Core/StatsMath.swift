import Foundation

enum StatsMath {
    static func wordsPerMinute(words: Int, speakingSeconds: Double) -> Double {
        guard speakingSeconds > 0 else { return 0 }
        return (Double(words) / speakingSeconds) * 60
    }

    static func currentStreak(
        qualifiedDates: Set<Date>,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        var streak = 0
        var cursor = calendar.startOfDay(for: today)

        while qualifiedDates.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return streak
    }
}
