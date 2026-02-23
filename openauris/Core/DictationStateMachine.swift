import Foundation

enum DictationHotkeyAction {
    case holdDown
    case holdUp
    case togglePress
}

struct DictationStateMachine {
    static func nextState(current: DictationSessionState, action: DictationHotkeyAction) -> DictationSessionState {
        switch (current, action) {
        case (.idle, .holdDown):
            return .listening(.holdToSpeak)
        case (.listening(.holdToSpeak), .holdUp):
            return .processing
        case (.idle, .togglePress):
            return .listening(.toggle)
        case (.listening(.toggle), .togglePress):
            return .processing
        default:
            return current
        }
    }
}
