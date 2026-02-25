import SwiftUI

struct MenuBarContentView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("OpenAuris")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }

            Divider()

            VStack(spacing: 8) {
                Button("Open Command Center", systemImage: "rectangle.grid.2x2") {
                    openDashboard()
                }
                .buttonStyle(.borderedProminent)

                Button("Toggle Dictation", systemImage: "waveform.and.mic") {
                    container.sessionManager.handleHotkeyAction(.toggle)
                }
                .buttonStyle(.bordered)
            }

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                Text("Permissions")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)

                permissionRow(title: "Microphone", granted: container.permissionManager.microphoneGranted)
                permissionRow(title: "Accessibility", granted: container.permissionManager.accessibilityGranted)
                valueRow(title: "Default Model", value: container.modelManager.defaultModelID.capitalized)
            }

            Divider()

            Button("Quit OpenAuris", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }

    private func openDashboard() {
        openWindow(id: OpenAurisConstants.dashboardWindowID)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func permissionRow(title: String, granted: Bool) -> some View {
        infoRow(
            title: title,
            value: granted ? "Granted" : "Pending",
            valueColor: granted ? .green : .orange
        )
    }

    private func valueRow(title: String, value: String) -> some View {
        infoRow(title: title, value: value, valueColor: .secondary)
    }

    private func infoRow(title: String, value: String, valueColor: Color) -> some View {
        HStack{
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(valueColor)
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
        case .error:
            return "Needs attention"
        }
    }

    private var statusColor: Color {
        switch container.sessionManager.state {
        case .idle:
            return .green
        case .listening:
            return .cyan
        case .processing, .inserting:
            return .orange
        case .error:
            return .red
        }
    }
}
