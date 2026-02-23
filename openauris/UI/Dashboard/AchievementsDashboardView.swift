import SwiftUI

struct AchievementsDashboardView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(.largeTitle.bold())

            List(container.achievements) { achievement in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(achievement.title)
                            .font(.headline)
                        Text(achievement.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        if let unlockedAt = achievement.unlockedAt {
                            Text("Unlocked")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Text(unlockedAt, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(achievement.progressValue)/\(achievement.goalValue)")
                                .font(.caption)
                            ProgressView(value: Double(achievement.progressValue), total: Double(achievement.goalValue))
                                .frame(width: 100)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .listStyle(.inset)
        }
    }
}
