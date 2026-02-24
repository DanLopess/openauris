import AppIntents
import Foundation

struct ToggleDictationIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Dictation"
    static let description = IntentDescription("Starts dictation if idle, or stops if currently listening in toggle mode.")

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .openAurisToggleDictation, object: nil)
        return .result()
    }
}

struct CancelDictationIntent: AppIntent {
    static let title: LocalizedStringResource = "Cancel Dictation"
    static let description = IntentDescription("Cancels an active dictation session.")

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .openAurisCancelDictation, object: nil)
        return .result()
    }
}

struct OpenAurisShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleDictationIntent(),
            phrases: [
                "Toggle dictation in \(.applicationName)",
                "Start dictation in \(.applicationName)"
            ],
            shortTitle: "Toggle Dictation",
            systemImageName: "waveform.and.mic"
        )
        AppShortcut(
            intent: CancelDictationIntent(),
            phrases: ["Cancel dictation in \(.applicationName)"],
            shortTitle: "Cancel Dictation",
            systemImageName: "xmark.circle"
        )
    }
}
