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

    private func decodedShortcut(from data: Data) -> ShortcutBinding? {
        try? JSONDecoder().decode(ShortcutBinding.self, from: data)
    }
}
