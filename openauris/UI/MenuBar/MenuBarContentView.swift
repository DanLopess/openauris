import SwiftUI

struct MenuBarContentView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider().padding(.horizontal, 8)

            section {
                menuRow("Toggle Dictation", icon: "waveform.and.mic") {
                    container.sessionManager.handleHotkeyAction(.toggle)
                }
            }

            Divider().padding(.horizontal, 8)

            section {
                statusInfoRow(
                    "Microphone",
                    value: container.permissionManager.microphoneGranted ? "Granted" : "Pending",
                    valueColor: container.permissionManager.microphoneGranted ? .green : .orange
                )
                statusInfoRow(
                    "Accessibility",
                    value: container.permissionManager.accessibilityGranted ? "Granted" : "Pending",
                    valueColor: container.permissionManager.accessibilityGranted ? .green : .orange
                )
                statusInfoRow(
                    "Model",
                    value: container.modelManager.defaultModelID.capitalized,
                    valueColor: .secondary
                )
            }

            Divider().padding(.horizontal, 8)

            section {
                menuRow("Open Command Center", icon: "rectangle.grid.2x2") {
                    openDashboard()
                }
                menuRow("Settings", icon: "gearshape") {
                    openSettings()
                }
            }

            Divider().padding(.horizontal, 8)

            section {
                menuRow("Quit OpenAuris", icon: "power", tint: .red) {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .frame(width: 220)
        .padding(.vertical, 4)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("OpenAuris")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
            Spacer()
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(statusText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func section<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.vertical, 4)
    }

    private func menuRow(_ title: String, icon: String, tint: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .frame(width: 16)
                    .foregroundStyle(tint)
                Text(title)
                    .foregroundStyle(tint)
                Spacer()
            }
            .font(.body)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuItemButtonStyle())
        .padding(.horizontal, 4)
    }

    private func statusInfoRow(_ label: String, value: String, valueColor: Color) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(valueColor)
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 3)
    }

    // MARK: - Navigation

    private func openDashboard() {
        openWindow(id: OpenAurisConstants.dashboardWindowID)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func openSettings() {
        container.requestedDashboardTab = .preferences
        openWindow(id: OpenAurisConstants.dashboardWindowID)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    // MARK: - Status

    private var statusText: String {
        switch container.sessionManager.state {
        case .idle:        return "Ready"
        case .listening:   return "Listening"
        case .processing:  return "Processing"
        case .inserting:   return "Inserting"
        case .error:       return "Error"
        }
    }

    private var statusColor: Color {
        switch container.sessionManager.state {
        case .idle:                    return .green
        case .listening:               return .cyan
        case .processing, .inserting:  return .orange
        case .error:                   return .red
        }
    }
}

// MARK: - Button Style

private struct MenuItemButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill((isHovered || configuration.isPressed) ? Color.primary.opacity(0.07) : Color.clear)
            )
            .animation(.easeInOut(duration: 0.1), value: isHovered)
            .onHover { isHovered = $0 }
    }
}
