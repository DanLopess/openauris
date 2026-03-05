import Sparkle
import SwiftData
import SwiftUI

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
        .menuBarExtraStyle(.window)

        Window("OpenAuris", id: OpenAurisConstants.dashboardWindowID) {
            DashboardRootView()
                .environment(container)
                .modelContainer(container.modelContainer)
        }
        .defaultSize(CGSize(width: 1200, height: 760))
        .defaultLaunchBehavior(.presented)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            DashboardCommands {
                container.updaterController.updater.checkForUpdates()
            }
        }
    }
}
