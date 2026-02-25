import SwiftUI

struct DashboardRootView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: DashboardTab = .overview

    var body: some View {
        DashboardShellView {
            sidebar
                .navigationSplitViewColumnWidth(
                    min: DashboardTheme.sidebarMinWidth,
                    ideal: DashboardTheme.sidebarIdealWidth,
                    
                )
        } content: {
            detailView
        }
        .background(DashboardTheme.windowBackground(colorScheme))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ControlGroup {
                    Button("Toggle Dictation", systemImage: "waveform.and.mic") {
                        container.sessionManager.handleHotkeyAction(.toggle)
                    }

                    Button("Refresh", systemImage: "arrow.clockwise") {
                        container.refreshDashboardData()
                    }
                }
                .padding(2)
                .labelStyle(.iconOnly)
                .controlSize(.large)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { container.showOnboarding },
                set: { container.showOnboarding = $0 }
            )
        ) {
            OnboardingView()
                .frame(minWidth: 620, minHeight: 420)
        }
        .task {
            container.bootstrapIfNeeded()
            container.refreshDashboardData()
        }
        .onChange(of: container.sessionManager.state) { _, _ in
            container.refreshDashboardData()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                AppBrandLogo(size: 28)
                Text("OpenAuris")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
            }
            .padding(.horizontal, 10)

            VStack(spacing: 8) {
                ForEach(DashboardTab.allCases.filter { $0 != .preferences }) { tab in
                    sidebarTabButton(tab)
                }
            }
            .padding(8)
            .dashboardGlassCard()

            Spacer()

            DashboardCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Runtime")
                        .font(.subheadline.weight(.semibold))
                    DashboardStatusPill(text: runtimeStatus.label, color: runtimeStatus.color)
                }
            }

            VStack(spacing: 8) {
                sidebarTabButton(.preferences)
            }
            .padding(8)
            .dashboardGlassCard()
        }
        .padding(12)
    }

    private func sidebarTabButton(_ tab: DashboardTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.systemImage)
                    .font(.body.weight(.semibold))
                    .frame(width: 18)
                Text(tab.title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .foregroundStyle(selectedTab == tab ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        selectedTab == tab
                        ? DashboardTheme.accentColor(for: tab).opacity(0.9)
                        : Color.clear
                    )
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .overview:
            HomeDashboardView()
        case .activity:
            HistoryDashboardView()
        case .models:
            ModelsDashboardView()
        case .insights:
            StatsDashboardView()
        case .milestones:
            AchievementsDashboardView()
        case .preferences:
            SettingsDashboardView()
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
            return ("Needs Attention", .red)
        }
    }
}
