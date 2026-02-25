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

                statusRow
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

    private var statusRow: some View {
        HStack(alignment: .top, spacing: 14) {
            DashboardCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Runtime Status")
                        .font(.headline)
                    DashboardStatusPill(text: runtimeStatus.label, color: runtimeStatus.color)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)

            DashboardCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Permissions")
                        .font(.headline)
                    statusLine("Microphone", ok: container.permissionManager.microphoneGranted)
                    statusLine("Accessibility", ok: container.permissionManager.accessibilityGranted)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)

            DashboardCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Model")
                        .font(.headline)
                    Text(container.modelManager.defaultModelID.capitalized)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(container.modelManager.isModelInstalled(container.modelManager.defaultModelID) ? "Installed and ready." : "Waiting for install.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
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
                title: "Sessions",
                value: "\(container.usageSnapshot.totalSessions)",
                caption: "Completed",
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

    private func statusLine(_ title: String, ok: Bool) -> some View {
        HStack {
            Circle()
                .fill(ok ? .green : .orange)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(ok ? "Granted" : "Pending")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var runtimeStatus: (label: String, color: Color) {
        switch container.sessionManager.state {
        case .idle:
            return ("Ready", .green)
        case .listening:
            return ("Listening", .cyan)
        case .processing, .inserting:
            return ("Busy", .orange)
        case .error:
            return ("Error", .red)
        }
    }
}
