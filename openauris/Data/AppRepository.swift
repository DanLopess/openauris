import Foundation
import SwiftData

struct UsageSnapshot: Sendable {
    let totalWords: Int
    let totalSessions: Int
    let totalSpeakingSeconds: Double
    let averageWPM: Double
    let currentStreakDays: Int

    var totalSpokenMinutes: Int {
        Int(totalSpeakingSeconds / 60)
    }
}

struct TopTargetAppUsage: Sendable, Identifiable {
    var id: String { bundleID }
    let bundleID: String
    let sessionCount: Int
    let totalWords: Int
    let lastUsedAt: Date

    var displayName: String {
        Self.displayName(for: bundleID)
    }

    static func displayName(for bundleID: String) -> String {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.lowercased() != "unknown" else {
            return "Unknown App"
        }

        let component = trimmed
            .split(separator: ".")
            .last
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? trimmed

        let separated = component.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")
        if separated.contains(" ") {
            return separated
                .split(whereSeparator: \.isWhitespace)
                .map { token in token.prefix(1).uppercased() + token.dropFirst().lowercased() }
                .joined(separator: " ")
        }

        if component == component.lowercased() {
            return component.prefix(1).uppercased() + component.dropFirst()
        }

        return component
    }
}

@MainActor
final class AppRepository {
    private static let supportedLanguageOverrides: Set<String> = ["auto", "en", "pt", "es"]

    private let context: ModelContext
    private let calendar = Calendar.current

    init(context: ModelContext) {
        self.context = context
    }

    func ensurePreferences() throws -> UserPreferenceEntity {
        if let existing = try context.fetch(FetchDescriptor<UserPreferenceEntity>()).first {
            return try migrateLegacyPreferencesIfNeeded(existing)
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
        overwriteInstalledAt: Bool = false,
        overwriteLastUsedAt: Bool = false,
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
        if overwriteInstalledAt {
            target.installedAt = installedAt
        } else if let installedAt {
            target.installedAt = installedAt
        }
        if overwriteLastUsedAt {
            target.lastUsedAt = lastUsedAt
        } else if let lastUsedAt {
            target.lastUsedAt = lastUsedAt
        }
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

    func syncMilestonesCatalog() throws {
        try refreshAchievements()
        try context.save()
    }

    func fetchDailyStats(rangeDays: Int? = nil) throws -> [DailyStatsEntity] {
        let all = try context.fetch(FetchDescriptor<DailyStatsEntity>(sortBy: [SortDescriptor(\.date)]))
        guard let rangeDays else { return all }

        let normalizedRange = max(1, rangeDays)
        guard let startDate = calendar.date(byAdding: .day, value: -(normalizedRange - 1), to: calendar.startOfDay(for: Date())) else {
            return all
        }

        return all.filter { calendar.startOfDay(for: $0.date) >= startDate }
    }

    func fetchRecentSessions(limit: Int) throws -> [DictationSessionEntity] {
        guard limit > 0 else { return [] }
        let descriptor = FetchDescriptor<DictationSessionEntity>(
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        )
        let all = try context.fetch(descriptor).filter { !$0.isDeleted }
        return Array(all.prefix(limit))
    }

    func fetchTopTargetApps(limit: Int, rangeDays: Int) throws -> [TopTargetAppUsage] {
        guard limit > 0 else { return [] }

        let descriptor = FetchDescriptor<DictationSessionEntity>(
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)]
        )
        let sessions = try context.fetch(descriptor).filter { !$0.isDeleted }
        let normalizedRange = max(1, rangeDays)
        let cutoff = calendar.date(
            byAdding: .day,
            value: -(normalizedRange - 1),
            to: calendar.startOfDay(for: Date())
        ) ?? .distantPast

        let inRange = sessions.filter { calendar.startOfDay(for: $0.endedAt) >= cutoff }
        var grouped: [String: (count: Int, words: Int, lastUsedAt: Date)] = [:]

        for session in inRange {
            let bundleID = session.targetBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedBundleID = bundleID.isEmpty ? "unknown" : bundleID
            var current = grouped[resolvedBundleID] ?? (0, 0, .distantPast)
            current.count += 1
            current.words += session.wordCount
            if session.endedAt > current.lastUsedAt {
                current.lastUsedAt = session.endedAt
            }
            grouped[resolvedBundleID] = current
        }

        return grouped.map { bundleID, values in
            TopTargetAppUsage(
                bundleID: bundleID,
                sessionCount: values.count,
                totalWords: values.words,
                lastUsedAt: values.lastUsedAt
            )
        }
        .sorted {
            if $0.sessionCount != $1.sessionCount {
                return $0.sessionCount > $1.sessionCount
            }
            if $0.totalWords != $1.totalWords {
                return $0.totalWords > $1.totalWords
            }
            return $0.bundleID < $1.bundleID
        }
        .prefix(limit)
        .map { $0 }
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
        precondition(MilestoneCatalog.hasUniqueIDs(), "Milestone IDs must be unique.")

        let snapshot = try usageSnapshot()
        let existingAchievements = try context.fetch(FetchDescriptor<AchievementEntity>())
        let achievementMap = Dictionary(uniqueKeysWithValues: existingAchievements.map { ($0.id, $0) })
        let validIDs = Set(MilestoneCatalog.definitions.map(\.id))

        for achievement in existingAchievements where !validIDs.contains(achievement.id) {
            context.delete(achievement)
        }

        for definition in MilestoneCatalog.definitions {
            let progress = definition.progress(from: snapshot)
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

    private func migrateLegacyPreferencesIfNeeded(_ preferences: UserPreferenceEntity) throws -> UserPreferenceEntity {
        var hasChanges = false

        if preferences.hasOpenedDashboardOnce == nil {
            preferences.hasOpenedDashboardOnce = preferences.onboardingCompleted
            hasChanges = true
        }

        let normalizedLanguage = normalizedLanguageOverride(preferences.languageOverride)
        if preferences.languageOverride != normalizedLanguage {
            preferences.languageOverride = normalizedLanguage
            hasChanges = true
        }

        if DictationMode(rawValue: preferences.defaultModeRawValue) == nil {
            preferences.defaultModeRawValue = DictationMode.holdToSpeak.rawValue
            hasChanges = true
        }

        if preferences.defaultModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            preferences.defaultModelID = OpenAurisConstants.defaultModelID
            hasChanges = true
        }

        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        let decodedHold = try? decoder.decode(ShortcutBinding.self, from: preferences.holdShortcutData)
        let decodedToggle = try? decoder.decode(ShortcutBinding.self, from: preferences.toggleShortcutData)
        let resolvedHold = decodedHold ?? .defaultHold
        var resolvedToggle = decodedToggle ?? .defaultToggle

        if resolvedHold == resolvedToggle {
            resolvedToggle = (resolvedHold == .defaultToggle) ? .defaultHold : .defaultToggle
            hasChanges = true
        }

        if decodedHold == nil || preferences.holdShortcutData.isEmpty {
            preferences.holdShortcutData = try encoder.encode(resolvedHold)
            hasChanges = true
        }

        if decodedToggle == nil || preferences.toggleShortcutData.isEmpty || resolvedToggle != decodedToggle {
            preferences.toggleShortcutData = try encoder.encode(resolvedToggle)
            hasChanges = true
        }

        if hasChanges {
            try context.save()
        }

        return preferences
    }

    private func normalizedLanguageOverride(_ rawValue: String) -> String {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalized.isEmpty, Self.supportedLanguageOverrides.contains(normalized) else {
            return "auto"
        }

        return normalized
    }
}

extension String {
    nonisolated var openAurisWordCount: Int {
        split { $0.isWhitespace || $0.isNewline }.count
    }
}
