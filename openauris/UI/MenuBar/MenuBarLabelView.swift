import SwiftUI

struct MenuBarLabelView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(Branding.menuBarIconAssetName)
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
            .accessibilityLabel(OpenAurisConstants.appName)
            .onAppear {
                openDashboardIfNeeded()
            }
            .onChange(of: container.pendingInitialDashboardOpen) { _, _ in
                openDashboardIfNeeded()
            }
    }

    private func openDashboardIfNeeded() {
        guard container.pendingInitialDashboardOpen else { return }

        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: OpenAurisConstants.dashboardWindowID)
        container.consumeInitialDashboardOpen()
    }
}
