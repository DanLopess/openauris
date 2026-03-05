import SwiftUI
import AppKit
import Sparkle

extension Notification.Name {
    static let openAurisOpenSettings = Notification.Name("com.openauris.openSettings")
}

struct DashboardCommands: Commands {
    let checkForUpdates: () -> Void

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About OpenAuris") {
                NSApplication.shared.orderFrontStandardAboutPanel(nil)
            }
        }
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") {
                checkForUpdates()
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
