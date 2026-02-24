import Foundation
import SwiftData

enum PersistenceController {
    static func makeModelContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([
            DictationSessionEntity.self,
            ModelInstallEntity.self,
            DailyStatsEntity.self,
            AchievementEntity.self,
            UserPreferenceEntity.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }
}
