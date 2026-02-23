import SwiftUI

struct DashboardRootView: View {
    @EnvironmentObject private var container: AppContainer
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
        .sheet(isPresented: $container.showOnboarding) {
            OnboardingView()
                .environmentObject(container)
                .frame(minWidth: 620, minHeight: 420)
        }
        .task {
            container.bootstrapIfNeeded()
            container.refreshDashboardData()
        }
        .onChange(of: container.sessionManager.state) { _, _ in
            container.refreshDashboardData()
        }
        .onChange(of: selectedTab) { _, value in
            if let value {
                container.selectedTab = value
            }
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
