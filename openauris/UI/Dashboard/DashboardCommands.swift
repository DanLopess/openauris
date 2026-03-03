import SwiftUI
import AppKit

extension Notification.Name {
    static let openAurisOpenSettings = Notification.Name("com.openauris.openSettings")
}

struct DashboardCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About OpenAuris") {
                NSApplication.shared.orderFrontStandardAboutPanel(nil)
            }
        }
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                NotificationCenter.default.post(name: .openAurisOpenSettings, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        CommandGroup(replacing: .appTermination) {
            Button("Quit OpenAuris") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
