import Foundation
import SwiftData
import Testing
@testable import openauris

@MainActor
struct AppRepositoryTests {
    @Test
    func ensurePreferencesCreatesDefaultValues() throws {
        let container = PersistenceController.makeModelContainer(inMemory: true)
        let repository = AppRepository(context: container.mainContext)

        let preferences = try repository.ensurePreferences()

        #expect(preferences.defaultModelID == OpenAurisConstants.defaultModelID)
        #expect(preferences.onboardingCompleted == false)
        #expect(preferences.hasOpenedDashboardOnce == false)
        #expect(preferences.languageOverride == "auto")
    }

    @Test
    func saveSessionUpdatesUsageAndAchievements() throws {
        let container = PersistenceController.makeModelContainer(inMemory: true)
        let repository = AppRepository(context: container.mainContext)

        let text = String(repeating: "word ", count: 1_000)
        let startedAt = Date().addingTimeInterval(-120)
        let endedAt = Date()

        try repository.saveSession(
            mode: .toggle,
            partialPreview: "word word",
            transcript: FinalTranscript(
                text: text,
                languageCode: "en",
                confidence: nil,
                wordCount: 1_000,
                durationSeconds: 120
            ),
            modelID: "small",
            startedAt: startedAt,
            endedAt: endedAt,
            insertionMethod: "accessibility",
            targetBundleID: "com.apple.TextEdit"
        )

        let snapshot = try repository.usageSnapshot()
        #expect(snapshot.totalSessions == 1)
        #expect(snapshot.totalWords == 1_000)

        let achievements = try repository.fetchAchievements()
        #expect(achievements.contains(where: { $0.id == "first_session" && $0.unlockedAt != nil }))
        #expect(achievements.contains(where: { $0.id == "words_1000" && $0.unlockedAt != nil }))
    }

    @Test
    func streakComputesAcrossConsecutiveDays() throws {
        let container = PersistenceController.makeModelContainer(inMemory: true)
        let repository = AppRepository(context: container.mainContext)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        try repository.saveSession(
            mode: .holdToSpeak,
            partialPreview: "",
            transcript: FinalTranscript(
                text: String(repeating: "w ", count: 120),
                languageCode: "en",
                confidence: nil,
                wordCount: 120,
                durationSeconds: 40
            ),
            modelID: "small",
            startedAt: yesterday,
            endedAt: yesterday,
            insertionMethod: "accessibility",
            targetBundleID: "com.apple.TextEdit"
        )

        try repository.saveSession(
            mode: .holdToSpeak,
            partialPreview: "",
            transcript: FinalTranscript(
                text: String(repeating: "w ", count: 160),
                languageCode: "en",
                confidence: nil,
                wordCount: 160,
                durationSeconds: 40
            ),
            modelID: "small",
            startedAt: today,
            endedAt: today,
            insertionMethod: "accessibility",
            targetBundleID: "com.apple.TextEdit"
        )

        let snapshot = try repository.usageSnapshot()
        #expect(snapshot.currentStreakDays == 2)
    }

    @Test
    func upsertModelCanClearInstalledAt() throws {
        let container = PersistenceController.makeModelContainer(inMemory: true)
        let repository = AppRepository(context: container.mainContext)
        let installedAt = Date()

        try repository.upsertModel(
            modelID: "small",
            displayName: "Small",
            sizeBytes: 500_000_000,
            state: "installed",
            isDefault: true,
            installedAt: installedAt
        )

        try repository.upsertModel(
            modelID: "small",
            displayName: "Small",
            sizeBytes: 500_000_000,
            state: "not_installed",
            isDefault: true,
            installedAt: nil,
            overwriteInstalledAt: true
        )

        let model = try repository.fetchModels().first { $0.modelID == "small" }
        #expect(model != nil)
        #expect(model?.installedAt == nil)
        #expect(model?.downloadState == "not_installed")
    }

    @Test
    func ensurePreferencesMigratesLegacyPreferenceValues() throws {
        let container = PersistenceController.makeModelContainer(inMemory: true)
        let repository = AppRepository(context: container.mainContext)

        let legacy = UserPreferenceEntity(
            holdShortcutData: Data(),
            toggleShortcutData: Data("invalid".utf8),
            defaultModeRawValue: "legacy_mode",
            defaultModelID: "   ",
            languageOverride: " EN ",
            launchAtLogin: false,
            insertionPrefersAccessibility: true,
            onboardingCompleted: true,
            hasOpenedDashboardOnce: nil
        )
        container.mainContext.insert(legacy)
        try container.mainContext.save()

        let migrated = try repository.ensurePreferences()

        #expect(migrated.hasOpenedDashboardOnce == true)
        #expect(migrated.defaultModeRawValue == DictationMode.holdToSpeak.rawValue)
        #expect(migrated.defaultModelID == OpenAurisConstants.defaultModelID)
        #expect(migrated.languageOverride == "en")

        let hold = try #require(decodedShortcut(from: migrated.holdShortcutData))
        let toggle = try #require(decodedShortcut(from: migrated.toggleShortcutData))
        #expect(hold != toggle)
    }

    @Test
    func fetchRecentSessionsReturnsLatestSessionsRespectingLimit() throws {
        let container = PersistenceController.makeModelContainer(inMemory: true)
        let repository = AppRepository(context: container.mainContext)

        let now = Date()
        try saveSession(
            in: repository,
            words: 10,
            startedAt: now.addingTimeInterval(-300),
            endedAt: now.addingTimeInterval(-280),
            bundleID: "com.apple.TextEdit"
        )
        try saveSession(
            in: repository,
            words: 20,
            startedAt: now.addingTimeInterval(-200),
            endedAt: now.addingTimeInterval(-180),
            bundleID: "com.apple.Terminal"
        )
        try saveSession(
            in: repository,
            words: 30,
            startedAt: now.addingTimeInterval(-100),
            endedAt: now.addingTimeInterval(-80),
            bundleID: "com.apple.Notes"
        )

        let recent = try repository.fetchRecentSessions(limit: 2)

        #expect(recent.count == 2)
        #expect(recent.first?.targetBundleID == "com.apple.Notes")
        #expect(recent.last?.targetBundleID == "com.apple.Terminal")
    }

    @Test
    func fetchDailyStatsRangeDaysExcludesOutOfRangeDays() throws {
        let container = PersistenceController.makeModelContainer(inMemory: true)
        let repository = AppRepository(context: container.mainContext)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let oldDay = calendar.date(byAdding: .day, value: -14, to: today)!

        try saveSession(
            in: repository,
            words: 120,
            startedAt: oldDay,
            endedAt: oldDay,
            bundleID: "com.apple.TextEdit"
        )
        try saveSession(
            in: repository,
            words: 90,
            startedAt: today,
            endedAt: today,
            bundleID: "com.apple.TextEdit"
        )

        let lastSevenDays = try repository.fetchDailyStats(rangeDays: 7)

        #expect(lastSevenDays.contains(where: { calendar.isDate($0.date, inSameDayAs: today) }))
        #expect(lastSevenDays.contains(where: { calendar.isDate($0.date, inSameDayAs: oldDay) }) == false)
    }

    @Test
    func fetchTopTargetAppsAggregatesSessionsAndWords() throws {
        let container = PersistenceController.makeModelContainer(inMemory: true)
        let repository = AppRepository(context: container.mainContext)

        let now = Date()
        try saveSession(
            in: repository,
            words: 100,
            startedAt: now.addingTimeInterval(-600),
            endedAt: now.addingTimeInterval(-580),
            bundleID: "com.apple.TextEdit"
        )
        try saveSession(
            in: repository,
            words: 80,
            startedAt: now.addingTimeInterval(-500),
            endedAt: now.addingTimeInterval(-480),
            bundleID: "com.apple.TextEdit"
        )
        try saveSession(
            in: repository,
            words: 50,
            startedAt: now.addingTimeInterval(-400),
            endedAt: now.addingTimeInterval(-380),
            bundleID: "com.apple.Terminal"
        )

        let topApps = try repository.fetchTopTargetApps(limit: 2, rangeDays: 30)

        #expect(topApps.count == 2)
        #expect(topApps.first?.bundleID == "com.apple.TextEdit")
        #expect(topApps.first?.sessionCount == 2)
        #expect(topApps.first?.totalWords == 180)
    }

    private func saveSession(
        in repository: AppRepository,
        words: Int,
        startedAt: Date,
        endedAt: Date,
        bundleID: String
    ) throws {
        try repository.saveSession(
            mode: .toggle,
            partialPreview: "preview",
            transcript: FinalTranscript(
                text: String(repeating: "word ", count: words),
                languageCode: "en",
                confidence: nil,
                wordCount: words,
                durationSeconds: 60
            ),
            modelID: "small",
            startedAt: startedAt,
            endedAt: endedAt,
            insertionMethod: "accessibility",
            targetBundleID: bundleID
        )
    }

    private func decodedShortcut(from data: Data) -> ShortcutBinding? {
        try? JSONDecoder().decode(ShortcutBinding.self, from: data)
    }
}
