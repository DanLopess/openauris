import SwiftUI
import AppKit

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
        .background(_TitlebarSeparatorHider())
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
        .onAppear {
            NSApplication.shared.setActivationPolicy(.regular)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
        .onDisappear {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAurisOpenSettings)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = .preferences
            }
        }
        .onChange(of: container.sessionManager.state) { _, _ in
            container.refreshDashboardData()
        }
        .onChange(of: container.requestedDashboardTab) { _, tab in
            guard let tab else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
            container.requestedDashboardTab = nil
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
                    Text("Runtime Status")
                        .font(.subheadline.weight(.semibold))
                    DashboardStatusPill(text: runtimeStatus.label, color: runtimeStatus.color)
                    Divider()
                    Text("Active Model")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(container.modelManager.defaultModelID.capitalized)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                    Text(activeModelSummary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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

}

private struct _TitlebarSeparatorHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { view.window?.titlebarSeparatorStyle = .none }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.window?.titlebarSeparatorStyle = .none
    }
}

extension DashboardRootView {
    private var activeModelSummary: String {
        let isInstalled = container.modelManager.isModelInstalled(container.modelManager.defaultModelID)

        switch container.runtimeStatus {
        case .ready:
            return "Installed and loaded for immediate dictation."
        case .preparing:
            return isInstalled ? "Installed. Loading into memory..." : "Downloading and preparing for first use."
        case .error:
            return isInstalled ? "Installed, but not ready yet." : "Waiting for install."
        }
    }

    private var runtimeStatus: (label: String, color: Color) {
        switch container.runtimeStatus {
        case .preparing:
            return ("Preparing…", .orange)
        case .ready:
            return ("Ready", .green)
        case .error(let message):
            return ("Error: " + message, .red)
        }
    }
}
