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

    func focusedApplicationBundleID() -> String {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"
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
        try? await Task.sleep(nanoseconds: 350_000_000)
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
