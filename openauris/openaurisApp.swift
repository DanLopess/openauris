import SwiftUI
import SwiftData

@main
struct OpenAurisApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(container)
        } label: {
            MenuBarLabelView()
        }
        .menuBarExtraStyle(.menu)

        WindowGroup(id: OpenAurisConstants.dashboardWindowID) {
            DashboardRootView()
                .environmentObject(container)
                .modelContainer(container.modelContainer)
        }
        .defaultSize(CGSize(width: 1200, height: 760))
        .defaultLaunchBehavior(.presented)
    }
}
