import AppKit
import ApplicationServices
import Foundation

@MainActor
final class AccessibilityTextInsertionService: TextInsertionService {
    func insert(_ text: String) async -> InsertionResult {
        guard !text.isEmpty else {
            return .failed(reason: "Transcript is empty.")
        }

        if insertViaAccessibility(text) {
            return .insertedDirectly
        }

        if await insertViaPasteboardFallback(text) {
            return .insertedViaPasteFallback
        }

        return .failed(reason: "Unable to insert text into the focused app.")
    }

    /// Appends text at the current cursor position using paste only.
    /// Unlike `insert`, this never calls `insertViaAccessibility` which would
    /// replace the entire field value instead of appending at the cursor.
    func appendText(_ text: String) async -> InsertionResult {
        guard !text.isEmpty else {
            return .failed(reason: "Text is empty.")
        }
        if await insertViaPasteboardFallback(text) {
            return .insertedViaPasteFallback
        }
        return .failed(reason: "Unable to append text into the focused app.")
    }

    func focusedApplicationBundleID() -> String {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"
    }

    func pressBackspace() async {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: false)
        else {
            return
        }
        
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        
        // Small delay to allow the system to process
        try? await Task.sleep(nanoseconds: 5_000_000) // 5ms
    }

    private func insertViaAccessibility(_ text: String) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedRef: CFTypeRef?
        let focusedStatus = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )

        guard focusedStatus == .success, let focusedElement = focusedRef else {
            return false
        }

        let element = (focusedElement as! AXUIElement)
        let valueStatus = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            text as CFTypeRef
        )

        return valueStatus == .success
    }

    private func insertViaPasteboardFallback(_ text: String) async -> Bool {
        let pasteboard = NSPasteboard.general
        let previousString = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            return false
        }

        let eventPosted = postCommandV()

        // Restore clipboard shortly after paste.
        // 150 ms is sufficient for apps to process Cmd+V while keeping latency low.
        try? await Task.sleep(nanoseconds: 150_000_000)
        pasteboard.clearContents()
        if let previousString {
            _ = pasteboard.setString(previousString, forType: .string)
        }

        return eventPosted
    }

    private func postCommandV() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
