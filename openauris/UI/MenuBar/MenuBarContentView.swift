import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var container: AppContainer
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("Status: \(statusText)")
            .foregroundStyle(.secondary)

        Divider()

        Button("Open Dashboard") {
            NSApplication.shared.activate(ignoringOtherApps: true)
            openWindow(id: OpenAurisConstants.dashboardWindowID)
        }

        Button("Start Toggle Dictation") {
            container.sessionManager.handleHotkeyAction(.toggle)
        }

        Button("Request Microphone Permission") {
            Task {
                _ = await container.permissionManager.requestMicrophone()
            }
        }

        Button("Request Accessibility Permission") {
            container.permissionManager.requestAccessibilityPrompt()
        }

        Divider()

        Button("Quit OpenAuris") {
            NSApplication.shared.terminate(nil)
        }
    }

    private var statusText: String {
        switch container.sessionManager.state {
        case .idle:
            return "Ready"
        case .listening(let mode):
            return "Listening (\(mode.displayName))"
        case .processing:
            return "Processing"
        case .inserting:
            return "Inserting"
        case .error(let message):
            return message
        }
    }
}
