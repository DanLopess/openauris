import Foundation

enum MilestoneTrack: String, CaseIterable, Sendable {
    case sessions
    case words
    case streak
    case speakingTime

    var title: String {
        switch self {
        case .sessions:
            return "Sessions"
        case .words:
            return "Words"
        case .streak:
            return "Streak"
        case .speakingTime:
            return "Speaking Time"
        }
    }

    var systemImage: String {
        switch self {
        case .sessions:
            return "waveform.and.mic"
        case .words:
            return "text.word.spacing"
        case .streak:
            return "flame"
        case .speakingTime:
            return "timer"
        }
    }
}

enum MilestoneMetric: Sendable {
    case totalSessions
    case totalWords
    case currentStreakDays
    case totalSpeakingMinutes

    func progress(from snapshot: UsageSnapshot) -> Int {
        switch self {
        case .totalSessions:
            return snapshot.totalSessions
        case .totalWords:
            return snapshot.totalWords
        case .currentStreakDays:
            return snapshot.currentStreakDays
        case .totalSpeakingMinutes:
            return Int(snapshot.totalSpeakingSeconds / 60)
        }
    }
}

struct MilestoneDefinition: Sendable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let goal: Int
    let track: MilestoneTrack
    let metric: MilestoneMetric
    let order: Int

    func progress(from snapshot: UsageSnapshot) -> Int {
        min(goal, max(0, metric.progress(from: snapshot)))
    }
}

enum MilestoneCatalog {
    static let definitions: [MilestoneDefinition] = [
        // Sessions
        MilestoneDefinition(
            id: "first_session",
            title: "First Session",
            subtitle: "Complete your first dictation session.",
            goal: 1,
            track: .sessions,
            metric: .totalSessions,
            order: 10
        ),
        MilestoneDefinition(
            id: "sessions_10",
            title: "10 Sessions",
            subtitle: "Complete 10 dictation sessions.",
            goal: 10,
            track: .sessions,
            metric: .totalSessions,
            order: 20
        ),
        MilestoneDefinition(
            id: "sessions_25",
            title: "25 Sessions",
            subtitle: "Complete 25 dictation sessions.",
            goal: 25,
            track: .sessions,
            metric: .totalSessions,
            order: 30
        ),
        MilestoneDefinition(
            id: "sessions_50",
            title: "50 Sessions",
            subtitle: "Complete 50 dictation sessions.",
            goal: 50,
            track: .sessions,
            metric: .totalSessions,
            order: 40
        ),

        // Words
        MilestoneDefinition(
            id: "words_1000",
            title: "1,000 Words",
            subtitle: "Dictate a total of 1,000 words.",
            goal: 1_000,
            track: .words,
            metric: .totalWords,
            order: 10
        ),
        MilestoneDefinition(
            id: "words_5000",
            title: "5,000 Words",
            subtitle: "Dictate a total of 5,000 words.",
            goal: 5_000,
            track: .words,
            metric: .totalWords,
            order: 20
        ),
        MilestoneDefinition(
            id: "words_10000",
            title: "10,000 Words",
            subtitle: "Dictate a total of 10,000 words.",
            goal: 10_000,
            track: .words,
            metric: .totalWords,
            order: 30
        ),
        MilestoneDefinition(
            id: "words_25000",
            title: "25,000 Words",
            subtitle: "Dictate a total of 25,000 words.",
            goal: 25_000,
            track: .words,
            metric: .totalWords,
            order: 40
        ),

        // Streak
        MilestoneDefinition(
            id: "streak_3",
            title: "3-Day Streak",
            subtitle: "Reach a 3-day speaking streak.",
            goal: 3,
            track: .streak,
            metric: .currentStreakDays,
            order: 10
        ),
        MilestoneDefinition(
            id: "streak_7",
            title: "7-Day Streak",
            subtitle: "Reach a 7-day speaking streak.",
            goal: 7,
            track: .streak,
            metric: .currentStreakDays,
            order: 20
        ),
        MilestoneDefinition(
            id: "streak_14",
            title: "14-Day Streak",
            subtitle: "Reach a 14-day speaking streak.",
            goal: 14,
            track: .streak,
            metric: .currentStreakDays,
            order: 30
        ),

        // Speaking Time
        MilestoneDefinition(
            id: "speaking_10m",
            title: "10 Minutes Spoken",
            subtitle: "Accumulate 10 minutes of speaking time.",
            goal: 10,
            track: .speakingTime,
            metric: .totalSpeakingMinutes,
            order: 10
        ),
        MilestoneDefinition(
            id: "speaking_60m",
            title: "1 Hour Spoken",
            subtitle: "Accumulate 1 hour of speaking time.",
            goal: 60,
            track: .speakingTime,
            metric: .totalSpeakingMinutes,
            order: 20
        ),
        MilestoneDefinition(
            id: "speaking_300m",
            title: "5 Hours Spoken",
            subtitle: "Accumulate 5 hours of speaking time.",
            goal: 300,
            track: .speakingTime,
            metric: .totalSpeakingMinutes,
            order: 30
        )
    ]

    private static let definitionsByID: [String: MilestoneDefinition] = definitions.reduce(into: [:]) { result, definition in
        result[definition.id] = definition
    }

    static func definition(for id: String) -> MilestoneDefinition? {
        definitionsByID[id]
    }

    static func hasUniqueIDs() -> Bool {
        definitionsByID.count == definitions.count
    }
}
