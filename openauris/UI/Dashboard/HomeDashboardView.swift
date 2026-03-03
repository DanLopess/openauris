import SwiftUI

struct HomeDashboardView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardTheme.sectionSpacing) {
                DashboardSectionHeader(
                    title: "Overview",
                    subtitle: "Operational overview for dictation status, readiness, and recent activity."
                )

                metricsGrid
                quickActions
                recentActivity

                if let startupErrorMessage = container.startupErrorMessage {
                    DashboardCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Latest Error")
                                .font(.headline)
                            Text(startupErrorMessage)
                                .font(.callout)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DashboardTheme.pagePadding)
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            DashboardMetricCard(
                title: "Words",
                value: "\(container.usageSnapshot.totalWords)",
                caption: "Total dictated",
                accent: .cyan
            )
            DashboardMetricCard(
                title: "Minutes Spoken",
                value: "\(container.usageSnapshot.totalSpokenMinutes)",
                caption: "Total minutes spoken",
                accent: .blue
            )
            DashboardMetricCard(
                title: "Average WPM",
                value: container.usageSnapshot.averageWPM.formatted(.number.precision(.fractionLength(0))),
                caption: "Speech speed",
                accent: .mint
            )
            DashboardMetricCard(
                title: "Streak",
                value: "\(container.usageSnapshot.currentStreakDays) days",
                caption: "100+ words/day",
                accent: .orange
            )
        }
    }

    private var quickActions: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Quick Actions")
                    .font(.headline)

                HStack(spacing: 10) {
                    Button("Toggle Dictation", systemImage: "waveform.and.mic") {
                        container.sessionManager.handleHotkeyAction(.toggle)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Open Accessibility Settings", systemImage: "figure.wave") {
                        container.permissionManager.openAccessibilitySettings()
                    }
                    .buttonStyle(.bordered)

                    Button("Re-run Onboarding", systemImage: "sparkles") {
                        container.showOnboarding = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Activity")
                .font(.headline)

            if container.sessions.isEmpty {
                DashboardEmptyState(
                    title: "No sessions yet",
                    subtitle: "Start dictation to populate your activity timeline.",
                    systemImage: "clock.arrow.circlepath"
                )
            } else {
                ForEach(Array(container.sessions.prefix(5))) { session in
                    DashboardCard {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.finalText)
                                    .lineLimit(2)
                                Text(session.endedAt, format: .dateTime.day().month().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(session.wordCount) words")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

}
