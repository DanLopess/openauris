import Foundation

/// Classifies a macOS application by its bundle identifier for the purpose of
/// determining the best dictation insertion strategy.
///
/// Terminal/shell applications are treated specially: incremental real-time
/// backspace-and-retype insertion is visually destructive in a shell prompt
/// (corrupts the command line), so they receive a single clean paste only after
/// the user stops speaking.
enum AppType {
    case standard
    case terminal
}

func isTerminalApp(_ bundleID: String) -> Bool {
    AppTypeClassifier.classify(bundleID) == .terminal
}

enum AppTypeClassifier {

    /// Bundle identifiers of known terminal/shell emulator applications.
    private static let terminalBundleIDs: Set<String> = [
        "com.apple.Terminal",        // macOS Terminal.app
        "com.googlecode.iterm2",     // iTerm2
        "net.kovidgoyal.kitty",      // Kitty
        "io.alacritty",              // Alacritty
        "com.mitchellh.ghostty",     // Ghostty
    ]

    static func classify(_ bundleID: String) -> AppType {
        terminalBundleIDs.contains(bundleID) ? .terminal : .standard
    }
}
