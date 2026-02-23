import Foundation
import SwiftData

struct UsageSnapshot: Sendable {
    let totalWords: Int
    let totalSessions: Int
    let totalSpeakingSeconds: Double
    let averageWPM: Double
    let currentStreakDays: Int
}

struct AchievementDefinition: Sendable {
    let id: String
    let title: String
    let subtitle: String
    let goal: Int
    let progressProvider: (UsageSnapshot) -> Int
}

@MainActor
final class AppRepository {
    private let context: ModelContext
    private let calendar = Calendar.current

    init(context: ModelContext) {
        self.context = context
    }

    func ensurePreferences() throws -> UserPreferenceEntity {
        if let existing = try context.fetch(FetchDescriptor<UserPreferenceEntity>()).first {
            return existing
        }

        let encoder = JSONEncoder()
        let holdData = try encoder.encode(ShortcutBinding.defaultHold)
        let toggleData = try encoder.encode(ShortcutBinding.defaultToggle)

        let prefs = UserPreferenceEntity(
            holdShortcutData: holdData,
            toggleShortcutData: toggleData,
            defaultModeRawValue: DictationMode.holdToSpeak.rawValue,
            defaultModelID: OpenAurisConstants.defaultModelID,
            languageOverride: "auto",
            launchAtLogin: false,
            insertionPrefersAccessibility: true,
            onboardingCompleted: false,
            hasOpenedDashboardOnce: false
        )

        context.insert(prefs)
        try context.save()
        return prefs
    }

    func loadPreferences() throws -> UserPreferenceEntity {
        try ensurePreferences()
    }

    func savePreferences(_ prefs: UserPreferenceEntity) throws {
        try context.save()
    }

    func fetchSessions(search: String = "") throws -> [DictationSessionEntity] {
        let descriptor = FetchDescriptor<DictationSessionEntity>(
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        )

        let all = try context.fetch(descriptor).filter { !$0.isDeleted }
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.finalText.localizedStandardContains(trimmed) }
    }

    func markDeleted(_ session: DictationSessionEntity) throws {
        session.isDeleted = true
        try context.save()
    }

    func clearAllHistory() throws {
        let sessions = try context.fetch(FetchDescriptor<DictationSessionEntity>())
        sessions.forEach(context.delete)

        let days = try context.fetch(FetchDescriptor<DailyStatsEntity>())
        days.forEach(context.delete)

        let achievements = try context.fetch(FetchDescriptor<AchievementEntity>())
        achievements.forEach(context.delete)

        try context.save()
    }

    func saveSession(
        mode: DictationMode,
        partialPreview: String,
        transcript: FinalTranscript,
        modelID: String,
        startedAt: Date,
        endedAt: Date,
        insertionMethod: String,
        targetBundleID: String
    ) throws {
        let duration = max(0.01, transcript.durationSeconds)
        let wpm = (Double(transcript.wordCount) / duration) * 60

        let entity = DictationSessionEntity(
            startedAt: startedAt,
            endedAt: endedAt,
            modeRawValue: mode.rawValue,
            partialPreview: partialPreview,
            finalText: transcript.text,
            languageCode: transcript.languageCode,
            modelID: modelID,
            audioDurationSec: duration,
            wordCount: transcript.wordCount,
            wpm: wpm,
            insertionMethod: insertionMethod,
            targetBundleID: targetBundleID
        )
        context.insert(entity)

        try updateDailyStats(for: entity)
        try refreshAchievements()
        try context.save()
    }

    func upsertModel(
        modelID: String,
        displayName: String,
        sizeBytes: Int64,
        state: String,
        isDefault: Bool,
        installedAt: Date? = nil,
        lastUsedAt: Date? = nil,
        checksum: String = ""
    ) throws {
        let existing = try context.fetch(FetchDescriptor<ModelInstallEntity>())
            .first(where: { $0.modelID == modelID })

        let target = existing ?? ModelInstallEntity(
            modelID: modelID,
            displayName: displayName,
            sizeBytes: sizeBytes,
            isDefault: isDefault,
            downloadState: state,
            checksum: checksum
        )

        target.displayName = displayName
        target.sizeBytes = sizeBytes
        target.downloadState = state
        target.isDefault = isDefault
        target.installedAt = installedAt ?? target.installedAt
        target.lastUsedAt = lastUsedAt ?? target.lastUsedAt
        target.checksum = checksum

        if existing == nil {
            context.insert(target)
        }

        if isDefault {
            let all = try context.fetch(FetchDescriptor<ModelInstallEntity>())
            for model in all where model.modelID != modelID {
                model.isDefault = false
            }
        }

        try context.save()
    }

    func fetchModels() throws -> [ModelInstallEntity] {
        try context.fetch(FetchDescriptor<ModelInstallEntity>(sortBy: [SortDescriptor(\.displayName)]))
    }

    func fetchAchievements() throws -> [AchievementEntity] {
        try context.fetch(FetchDescriptor<AchievementEntity>(sortBy: [SortDescriptor(\.title)]))
    }

    func fetchDailyStats() throws -> [DailyStatsEntity] {
        try context.fetch(FetchDescriptor<DailyStatsEntity>(sortBy: [SortDescriptor(\.date)]))
    }

    func usageSnapshot() throws -> UsageSnapshot {
        let sessions = try context.fetch(FetchDescriptor<DictationSessionEntity>())
            .filter { !$0.isDeleted }

        let words = sessions.reduce(0) { $0 + $1.wordCount }
        let speaking = sessions.reduce(0) { $0 + $1.audioDurationSec }
        let avgWPM = speaking > 0 ? (Double(words) / speaking) * 60 : 0
        let streak = try calculateCurrentStreak()

        return UsageSnapshot(
            totalWords: words,
            totalSessions: sessions.count,
            totalSpeakingSeconds: speaking,
            averageWPM: avgWPM,
            currentStreakDays: streak
        )
    }

    private func updateDailyStats(for session: DictationSessionEntity) throws {
        let date = calendar.startOfDay(for: session.endedAt)
        let entry = try context.fetch(FetchDescriptor<DailyStatsEntity>())
            .first(where: { calendar.startOfDay(for: $0.date) == date }) ?? DailyStatsEntity(date: date)

        entry.words += session.wordCount
        entry.sessions += 1
        entry.speakingSeconds += session.audioDurationSec
        entry.avgWPM = entry.speakingSeconds > 0 ? (Double(entry.words) / entry.speakingSeconds) * 60 : 0
        entry.streakQualified = entry.words >= OpenAurisConstants.minimumDailyWordsForStreak

        if entry.modelContext == nil {
            context.insert(entry)
        }
    }

    private func calculateCurrentStreak() throws -> Int {
        let days = try context.fetch(FetchDescriptor<DailyStatsEntity>(sortBy: [SortDescriptor(\.date)]))
        guard !days.isEmpty else { return 0 }

        var streak = 0
        var dayCursor = calendar.startOfDay(for: Date())
        let dayMap = Dictionary(uniqueKeysWithValues: days.map { (calendar.startOfDay(for: $0.date), $0) })

        while let entry = dayMap[dayCursor], entry.streakQualified {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: dayCursor) else { break }
            dayCursor = previous
        }

        return streak
    }

    private func refreshAchievements() throws {
        let snapshot = try usageSnapshot()
        let existingAchievements = try context.fetch(FetchDescriptor<AchievementEntity>())
        let achievementMap = Dictionary(uniqueKeysWithValues: existingAchievements.map { ($0.id, $0) })

        let definitions: [AchievementDefinition] = [
            AchievementDefinition(id: "first_session", title: "First Session", subtitle: "Complete your first dictation session.", goal: 1, progressProvider: { $0.totalSessions }),
            AchievementDefinition(id: "words_1000", title: "1,000 Words", subtitle: "Dictate a total of 1,000 words.", goal: 1_000, progressProvider: { $0.totalWords }),
            AchievementDefinition(id: "streak_7", title: "7-Day Streak", subtitle: "Reach a 7-day speaking streak.", goal: 7, progressProvider: { $0.currentStreakDays }),
            AchievementDefinition(id: "sessions_25", title: "25 Sessions", subtitle: "Complete 25 dictation sessions.", goal: 25, progressProvider: { $0.totalSessions }),
            AchievementDefinition(id: "words_10000", title: "10,000 Words", subtitle: "Dictate a total of 10,000 words.", goal: 10_000, progressProvider: { $0.totalWords })
        ]

        for definition in definitions {
            let progress = min(definition.goal, definition.progressProvider(snapshot))
            let existing = achievementMap[definition.id]

            let entity = existing ?? AchievementEntity(
                id: definition.id,
                progressValue: 0,
                goalValue: definition.goal,
                title: definition.title,
                subtitle: definition.subtitle
            )

            entity.title = definition.title
            entity.subtitle = definition.subtitle
            entity.goalValue = definition.goal
            entity.progressValue = progress

            if progress >= definition.goal && entity.unlockedAt == nil {
                entity.unlockedAt = Date()
            }

            if existing == nil {
                context.insert(entity)
            }
        }
    }
}

extension String {
    nonisolated var openAurisWordCount: Int {
        split { $0.isWhitespace || $0.isNewline }.count
    }
}
