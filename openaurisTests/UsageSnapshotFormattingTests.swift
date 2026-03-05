import XCTest
@testable import openauris

final class UsageSnapshotFormattingTests: XCTestCase {
    func testTotalSpokenMinutesRoundsDownPartialMinute() {
        let snapshot = UsageSnapshot(
            totalWords: 0,
            totalSessions: 0,
            totalSpeakingSeconds: 179,
            averageWPM: 0,
            currentStreakDays: 0
        )

        XCTAssertEqual(snapshot.totalSpokenMinutes, 2)
    }

    func testTotalSpokenMinutesHandlesSubMinuteDurations() {
        let snapshot = UsageSnapshot(
            totalWords: 0,
            totalSessions: 0,
            totalSpeakingSeconds: 59,
            averageWPM: 0,
            currentStreakDays: 0
        )

        XCTAssertEqual(snapshot.totalSpokenMinutes, 0)
    }
}
