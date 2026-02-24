import SwiftUI

struct DashboardRootView: View {
    @Environment(AppContainer.self) private var container
    @State private var selectedTab: DashboardTab? = .home

    var body: some View {
        NavigationSplitView {
            List(DashboardTab.allCases, selection: $selectedTab) { tab in
                Label(tab.title, systemImage: tab.systemImage)
                    .tag(tab)
                    .font(.system(.body, design: .rounded))
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.16), Color.cyan.opacity(0.08), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } detail: {
            detailView
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.02), Color.blue.opacity(0.04), Color.mint.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    container.sessionManager.handleHotkeyAction(.toggle)
                } label: {
                    Label("Toggle Dictation", systemImage: "waveform.and.mic")
                }

                Button {
                    container.refreshDashboardData()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
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

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab ?? .home {
        case .home:
            HomeDashboardView()
        case .history:
            HistoryDashboardView()
        case .models:
            ModelsDashboardView()
        case .stats:
            StatsDashboardView()
        case .achievements:
            AchievementsDashboardView()
        case .settings:
            SettingsDashboardView()
        }
    }
}
