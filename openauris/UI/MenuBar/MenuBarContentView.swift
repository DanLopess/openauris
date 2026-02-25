import SwiftUI

struct MenuBarContentView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                AppBrandLogo(size: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text("OpenAuris")
                        .font(.headline)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
            }

            Divider()

            VStack(spacing: 8) {
                Button("Open Command Center", systemImage: "rectangle.grid.2x2") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openWindow(id: OpenAurisConstants.dashboardWindowID)
                }
                .buttonStyle(.borderedProminent)

                Button("Toggle Dictation", systemImage: "waveform.and.mic") {
                    container.sessionManager.handleHotkeyAction(.toggle)
                }
                .buttonStyle(.bordered)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                statusRow(title: "Microphone", granted: container.permissionManager.microphoneGranted)
                statusRow(title: "Accessibility", granted: container.permissionManager.accessibilityGranted)
                statusRow(
                    title: "Default model",
                    value: container.modelManager.defaultModelID.capitalized
                )
            }

            Divider()

            HStack {
                Button("Permissions") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openWindow(id: OpenAurisConstants.dashboardWindowID)
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Quit OpenAuris", role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: 280)
    }

    private func statusRow(title: String, granted: Bool) -> some View {
        statusRow(title: title, value: granted ? "Granted" : "Pending")
    }

    private func statusRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
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
