import SwiftUI

struct AchievementsDashboardView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardTheme.sectionSpacing) {
                DashboardSectionHeader(
                    title: "Milestones",
                    subtitle: "Track unlocked goals and focus on the next meaningful target."
                )

                if inProgressMilestones.isEmpty && unlockedMilestones.isEmpty {
                    DashboardEmptyState(
                        title: "No milestones yet",
                        subtitle: "Complete your first session to begin milestone tracking.",
                        systemImage: "rosette"
                    )
                } else {
                    if !inProgressMilestones.isEmpty {
                        sectionTitle("In Progress")
                        ForEach(inProgressMilestones) { achievement in
                            milestoneRow(achievement)
                        }
                    }

                    if !unlockedMilestones.isEmpty {
                        sectionTitle("Unlocked")
                        ForEach(unlockedMilestones) { achievement in
                            milestoneRow(achievement)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var inProgressMilestones: [AchievementEntity] {
        container.achievements
            .filter { $0.unlockedAt == nil }
            .sorted { $0.progressValue > $1.progressValue }
    }

    private var unlockedMilestones: [AchievementEntity] {
        container.achievements
            .filter { $0.unlockedAt != nil }
            .sorted { ($0.unlockedAt ?? .distantPast) > ($1.unlockedAt ?? .distantPast) }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
    }

    private func milestoneRow(_ achievement: AchievementEntity) -> some View {
        DashboardCard {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(achievement.title)
                        .font(.headline)
                    Text(achievement.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let unlockedAt = achievement.unlockedAt {
                    VStack(alignment: .trailing, spacing: 4) {
                        DashboardStatusPill(text: "Unlocked", color: .green)
                        Text(unlockedAt, format: .dateTime.day().month().year())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("\(achievement.progressValue)/\(achievement.goalValue)")
                            .font(.caption.weight(.semibold))
                        ProgressView(
                            value: Double(achievement.progressValue),
                            total: Double(achievement.goalValue)
                        )
                        .frame(width: 130)
                    }
                }
            }
        }
    }
}
