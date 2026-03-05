import SwiftUI

struct AchievementsDashboardView: View {
    @Environment(AppContainer.self) private var container
    @State private var hasAnimatedIn = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardTheme.sectionSpacing) {
                DashboardSectionHeader(
                    title: "Milestones",
                    subtitle: "Track progress by track and stay focused on the next meaningful unlock."
                )

                if milestoneCards.isEmpty {
                    DashboardEmptyState(
                        title: "No milestones yet",
                        subtitle: "Complete your first session to begin milestone tracking.",
                        systemImage: "rosette"
                    )
                } else {
                    summaryCard
                    ForEach(trackSections) { section in
                        trackSection(section)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DashboardTheme.pagePadding)
        }
        .onAppear {
            withAnimation(.snappy(duration: 0.35)) {
                hasAnimatedIn = true
            }
        }
    }

    private struct MilestoneCardModel: Identifiable {
        let definition: MilestoneDefinition
        let progressValue: Int
        let unlockedAt: Date?

        var id: String { definition.id }
        var isUnlocked: Bool { unlockedAt != nil }
        var remaining: Int { max(0, definition.goal - progressValue) }
        var progressFraction: Double {
            guard definition.goal > 0 else { return 0 }
            return Double(progressValue) / Double(definition.goal)
        }
    }

    private struct TrackSectionModel: Identifiable {
        let track: MilestoneTrack
        let milestones: [MilestoneCardModel]

        var id: MilestoneTrack { track }
    }

    private var milestoneCards: [MilestoneCardModel] {
        let achievementsByID = Dictionary(uniqueKeysWithValues: container.achievements.map { ($0.id, $0) })
        return MilestoneCatalog.definitions.map { definition in
            let entity = achievementsByID[definition.id]
            let progressValue = min(definition.goal, max(0, entity?.progressValue ?? 0))
            return MilestoneCardModel(
                definition: definition,
                progressValue: progressValue,
                unlockedAt: entity?.unlockedAt
            )
        }
    }

    private var trackSections: [TrackSectionModel] {
        let grouped = Dictionary(grouping: milestoneCards, by: { $0.definition.track })
        return MilestoneTrack.allCases.compactMap { track in
            guard let milestones = grouped[track], !milestones.isEmpty else {
                return nil
            }
            return TrackSectionModel(
                track: track,
                milestones: milestones.sorted { $0.definition.order < $1.definition.order }
            )
        }
    }

    private var unlockedCount: Int {
        milestoneCards.filter(\.isUnlocked).count
    }

    private var completionPercent: Int {
        guard !milestoneCards.isEmpty else { return 0 }
        return Int((Double(unlockedCount) / Double(milestoneCards.count) * 100).rounded())
    }

    private var globalNextUp: MilestoneCardModel? {
        milestoneCards
            .filter { !$0.isUnlocked }
            .sorted {
                if $0.progressFraction != $1.progressFraction {
                    return $0.progressFraction > $1.progressFraction
                }
                if $0.remaining != $1.remaining {
                    return $0.remaining < $1.remaining
                }
                if $0.definition.track != $1.definition.track {
                    return trackSortOrder($0.definition.track) < trackSortOrder($1.definition.track)
                }
                return $0.definition.order < $1.definition.order
            }
            .first
    }

    private func trackSortOrder(_ track: MilestoneTrack) -> Int {
        MilestoneTrack.allCases.firstIndex(of: track) ?? .max
    }

    private var summaryCard: some View {
        DashboardCard {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Unlocked")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(unlockedCount)/\(milestoneCards.count)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.3), value: unlockedCount)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Completion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(completionPercent)%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                        .contentTransition(.numericText())
                        .animation(.snappy(duration: 0.3), value: completionPercent)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("Next Up")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let globalNextUp {
                        Text(globalNextUp.definition.title)
                            .font(.subheadline.weight(.semibold))
                        Text("\(globalNextUp.progressValue)/\(globalNextUp.definition.goal)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        DashboardStatusPill(text: "All Unlocked", color: .green)
                    }
                }
            }
        }
    }

    private func trackSection(_ section: TrackSectionModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: section.track.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(section.track.title)
                    .font(.headline)
            }

            let nextUpID = section.milestones.first(where: { !$0.isUnlocked })?.id
            ForEach(Array(section.milestones.enumerated()), id: \.element.id) { index, milestone in
                milestoneRow(
                    milestone,
                    isNextUp: nextUpID == milestone.id,
                    animationDelay: Double(index) * 0.03
                )
            }
        }
    }

    private func milestoneRow(
        _ milestone: MilestoneCardModel,
        isNextUp: Bool,
        animationDelay: Double
    ) -> some View {
        DashboardCard {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(milestone.definition.title)
                            .font(.headline)
                        if isNextUp && !milestone.isUnlocked {
                            DashboardStatusPill(text: "Next Up", color: .orange)
                        }
                    }

                    Text(milestone.definition.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let unlockedAt = milestone.unlockedAt {
                    VStack(alignment: .trailing, spacing: 4) {
                        DashboardStatusPill(text: "Unlocked", color: .green)
                        Text(unlockedAt, format: .dateTime.day().month().year())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("\(milestone.progressValue)/\(milestone.definition.goal)")
                            .font(.caption.weight(.semibold))
                            .contentTransition(.numericText())
                            .animation(.snappy(duration: 0.3), value: milestone.progressValue)
                        Text("\(milestone.remaining) to go")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ProgressView(
                            value: Double(milestone.progressValue),
                            total: Double(milestone.definition.goal)
                        )
                        .frame(width: 160)
                        .animation(.snappy(duration: 0.3), value: milestone.progressValue)
                    }
                }
            }
        }
        .opacity(hasAnimatedIn ? 1 : 0)
        .offset(y: hasAnimatedIn ? 0 : 8)
        .animation(.snappy(duration: 0.35).delay(animationDelay), value: hasAnimatedIn)
    }
}
