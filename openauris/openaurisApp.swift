import SwiftUI
import SwiftData

@main
struct OpenAurisApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environment(container)
        } label: {
            MenuBarLabelView()
        }
        .menuBarExtraStyle(.menu)

        WindowGroup(id: OpenAurisConstants.dashboardWindowID) {
            DashboardRootView()
                .environment(container)
                .modelContainer(container.modelContainer)
        }
        .defaultSize(CGSize(width: 1200, height: 760))
        .defaultLaunchBehavior(.presented)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
    }
}
