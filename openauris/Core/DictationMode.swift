import Foundation

enum DictationMode: String, Codable, CaseIterable, Identifiable {
    case holdToSpeak
    case toggle

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .holdToSpeak: return "Hold to Speak"
        case .toggle: return "Toggle Start/Stop"
        }
    }
}
