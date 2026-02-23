import SwiftUI

struct HomeDashboardView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    StatCard(title: "Words", value: "\(container.usageSnapshot.totalWords)", caption: "Total dictated")
                    StatCard(title: "Sessions", value: "\(container.usageSnapshot.totalSessions)", caption: "Completed")
                    StatCard(title: "Average WPM", value: String(format: "%.0f", container.usageSnapshot.averageWPM), caption: "Speech speed")
                    StatCard(title: "Streak", value: "\(container.usageSnapshot.currentStreakDays) days", caption: "100+ words/day")
                }

                quickActions

                if let startupErrorMessage = container.startupErrorMessage {
                    Text(startupErrorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("OpenAuris")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("Local-only dictation with a native macOS workflow.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            AppBrandLogo(size: 72)
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 10) {
                Button("Toggle Dictation") {
                    container.sessionManager.handleHotkeyAction(.toggle)
                }
                .buttonStyle(.borderedProminent)

                Button("Open Accessibility Settings") {
                    container.permissionManager.openAccessibilitySettings()
                }
                .buttonStyle(.bordered)

                Button("Re-run Onboarding") {
                    container.showOnboarding = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
