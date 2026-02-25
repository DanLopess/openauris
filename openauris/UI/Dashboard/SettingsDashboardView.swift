import AppKit
import SwiftUI

struct SettingsDashboardView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DashboardTheme.sectionSpacing) {
                DashboardSectionHeader(
                    title: "Preferences",
                    subtitle: "Configure launch behavior, defaults, and keyboard shortcuts."
                )

                if let preferences = container.preferences {
                    generalCard(preferences: preferences)
                    shortcutsCard(preferences: preferences)
                    permissionsCard
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DashboardTheme.pagePadding)
        }
    }

    private func generalCard(preferences: UserPreferenceEntity) -> some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("General")
                    .font(.headline)

                Toggle("Launch at login", isOn: Binding(
                    get: { preferences.launchAtLogin },
                    set: { container.setLaunchAtLogin($0) }
                ))

                Toggle("Prefer accessibility insertion", isOn: Binding(
                    get: { preferences.insertionPrefersAccessibility },
                    set: { container.setInsertionPreference(prefersAccessibility: $0) }
                ))

                Picker("Default mode", selection: Binding(
                    get: { DictationMode(rawValue: preferences.defaultModeRawValue) ?? .holdToSpeak },
                    set: { container.setDefaultMode($0) }
                )) {
                    ForEach(DictationMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }

                Picker("Language", selection: Binding(
                    get: { preferences.languageOverride },
                    set: { container.setLanguageOverride($0) }
                )) {
                    Text("Auto detect").tag("auto")
                    Text("English").tag("en")
                    Text("Portuguese").tag("pt")
                    Text("Spanish").tag("es")
                }
            }
        }
    }

    private func shortcutsCard(preferences: UserPreferenceEntity) -> some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Shortcuts")
                    .font(.headline)

                ShortcutRecorder(
                    title: "Hold to speak",
                    current: decodedShortcut(from: preferences.holdShortcutData) ?? .defaultHold,
                    sibling: decodedShortcut(from: preferences.toggleShortcutData) ?? .defaultToggle,
                    defaultShortcut: .defaultHold,
                    onSave: container.setHoldShortcut
                )

                Divider()

                ShortcutRecorder(
                    title: "Toggle start/stop",
                    current: decodedShortcut(from: preferences.toggleShortcutData) ?? .defaultToggle,
                    sibling: decodedShortcut(from: preferences.holdShortcutData) ?? .defaultHold,
                    defaultShortcut: .defaultToggle,
                    onSave: container.setToggleShortcut
                )
            }
        }
    }

    private var permissionsCard: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Permissions")
                    .font(.headline)

                permissionRow(
                    title: "Microphone",
                    isGranted: container.permissionManager.microphoneGranted,
                    actionTitle: "Open Microphone Settings"
                ) {
                    container.permissionManager.openMicrophoneSettings()
                }

                permissionRow(
                    title: "Accessibility",
                    isGranted: container.permissionManager.accessibilityGranted,
                    actionTitle: "Open Accessibility Settings"
                ) {
                    container.permissionManager.openAccessibilitySettings()
                }
            }
        }
    }

    private func permissionRow(title: String, isGranted: Bool, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            DashboardStatusPill(text: isGranted ? "Granted" : "Pending", color: isGranted ? .green : .orange)
            Button(actionTitle) {
                action()
            }
            .buttonStyle(.bordered)
        }
    }

    private func decodedShortcut(from data: Data) -> ShortcutBinding? {
        try? JSONDecoder().decode(ShortcutBinding.self, from: data)
    }
}

private struct ShortcutRecorder: View {
    let title: String
    let current: ShortcutBinding
    let sibling: ShortcutBinding
    let defaultShortcut: ShortcutBinding
    let onSave: (ShortcutBinding) -> Void

    @State private var workingShortcut: ShortcutBinding
    @State private var isRecording = false
    @State private var hint: String?
    @State private var monitor: Any?

    init(
        title: String,
        current: ShortcutBinding,
        sibling: ShortcutBinding,
        defaultShortcut: ShortcutBinding,
        onSave: @escaping (ShortcutBinding) -> Void
    ) {
        self.title = title
        self.current = current
        self.sibling = sibling
        self.defaultShortcut = defaultShortcut
        self.onSave = onSave
        _workingShortcut = State(initialValue: current)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                Text(workingShortcut.readable)
                    .font(.body.monospaced())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minWidth: 220, alignment: .leading)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Button(isRecording ? "Press keys..." : "Record Shortcut") {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Save") {
                    if workingShortcut == sibling {
                        hint = "This shortcut matches the other action. Save still works and auto-resolves conflicts."
                    } else {
                        hint = "Shortcut saved."
                    }
                    onSave(workingShortcut)
                }
                .buttonStyle(.bordered)

                Button("Reset") {
                    workingShortcut = current
                    hint = nil
                }
                .buttonStyle(.bordered)

                Button("Use Default") {
                    workingShortcut = defaultShortcut
                    hint = nil
                }
                .buttonStyle(.bordered)
            }

            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        hint = "Press any key combination. Press Esc to cancel."
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stopRecording()
                hint = "Recording cancelled."
                return nil
            }

            let relevantModifiers = event.modifierFlags.intersection([.control, .option, .command, .shift])
            let shortcut = ShortcutBinding(keyCode: UInt32(event.keyCode), modifiersRawValue: relevantModifiers.rawValue)
            workingShortcut = shortcut
            stopRecording()
            hint = "Captured \(shortcut.readable)"
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
