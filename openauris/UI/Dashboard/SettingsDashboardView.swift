import SwiftUI

struct SettingsDashboardView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Settings")
                .font(.largeTitle.bold())

            if let preferences = container.preferences {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
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
                } label: {
                    Text("General")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        ShortcutEditor(
                            title: "Hold to speak",
                            current: decodedShortcut(from: preferences.holdShortcutData) ?? .defaultHold,
                            onSave: container.setHoldShortcut
                        )

                        ShortcutEditor(
                            title: "Toggle start/stop",
                            current: decodedShortcut(from: preferences.toggleShortcutData) ?? .defaultToggle,
                            onSave: container.setToggleShortcut
                        )
                    }
                } label: {
                    Text("Shortcuts")
                }
            }

            Spacer()
        }
    }

    private func decodedShortcut(from data: Data) -> ShortcutBinding? {
        try? JSONDecoder().decode(ShortcutBinding.self, from: data)
    }
}

private struct ShortcutEditor: View {
    let title: String
    let current: ShortcutBinding
    let onSave: (ShortcutBinding) -> Void

    @State private var keyCode: UInt32 = 49
    @State private var useControl = true
    @State private var useOption = true
    @State private var useCommand = false
    @State private var useShift = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            HStack {
                Stepper("Key code: \(keyCode)", value: $keyCode, in: 0...127)
                Spacer()
                Text(shortcutPreview)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
            }

            HStack(spacing: 16) {
                Toggle("⌃", isOn: $useControl)
                Toggle("⌥", isOn: $useOption)
                Toggle("⌘", isOn: $useCommand)
                Toggle("⇧", isOn: $useShift)
            }
            .toggleStyle(.switch)

            HStack {
                Button("Save") {
                    onSave(buildShortcut())
                }
                .buttonStyle(.borderedProminent)

                Button("Reset") {
                    load(from: current)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task {
            load(from: current)
        }
    }

    private var shortcutPreview: String {
        buildShortcut().readable
    }

    private func buildShortcut() -> ShortcutBinding {
        var modifiers = NSEvent.ModifierFlags()
        if useControl { modifiers.insert(.control) }
        if useOption { modifiers.insert(.option) }
        if useCommand { modifiers.insert(.command) }
        if useShift { modifiers.insert(.shift) }

        return ShortcutBinding(keyCode: keyCode, modifiersRawValue: modifiers.rawValue)
    }

    private func load(from shortcut: ShortcutBinding) {
        keyCode = shortcut.keyCode
        useControl = shortcut.modifierFlags.contains(.control)
        useOption = shortcut.modifierFlags.contains(.option)
        useCommand = shortcut.modifierFlags.contains(.command)
        useShift = shortcut.modifierFlags.contains(.shift)
    }
}
