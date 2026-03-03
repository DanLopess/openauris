import AppKit
import Foundation

struct ShortcutBinding: Codable, Equatable, Sendable {
    var keyCode: UInt32
    var modifiersRawValue: UInt

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiersRawValue)
    }

    static let defaultHold = ShortcutBinding(
        keyCode: 49,
        modifiersRawValue: (NSEvent.ModifierFlags.control.union(.option)).rawValue
    )

    static let defaultToggle = ShortcutBinding(
        keyCode: 36,
        modifiersRawValue: (NSEvent.ModifierFlags.control.union(.shift)).rawValue
    )

    var readable: String {
        let pieces: [String] = [
            modifierFlags.contains(.control) ? "⌃" : nil,
            modifierFlags.contains(.option) ? "⌥" : nil,
            modifierFlags.contains(.command) ? "⌘" : nil,
            modifierFlags.contains(.shift) ? "⇧" : nil,
            keyName
        ].compactMap { $0 }
        return pieces.joined()
    }

    private var keyName: String {
        switch keyCode {
        case 36: return "↩"
        case 49: return "Space"
        default: return "Key \(keyCode)"
        }
    }
}
