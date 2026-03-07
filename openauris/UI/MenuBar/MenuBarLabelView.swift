import AppKit
import SwiftUI

struct MenuBarLabelView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var didAutoOpenDashboard = false
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("-openauris-ui-testing")

    var body: some View {
        Image(Branding.menuBarIconAssetName)
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
            .accessibilityLabel(OpenAurisConstants.appName)
            .task {
                openDashboardForUITestingIfNeeded()
            }
    }

    @MainActor
    private func openDashboardForUITestingIfNeeded() {
        guard isUITesting, !didAutoOpenDashboard else { return }

        didAutoOpenDashboard = true
        openWindow(id: OpenAurisConstants.dashboardWindowID)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
