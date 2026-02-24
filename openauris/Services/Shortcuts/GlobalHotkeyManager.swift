import AppKit
import Carbon.HIToolbox
import Foundation

@MainActor
final class GlobalHotkeyManager {
    enum Action {
        case holdDown
        case holdUp
        case toggle
    }

    var onAction: ((Action) -> Void)?

    private var holdShortcutRef: EventHotKeyRef?
    private var toggleShortcutRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private let holdID: UInt32 = 1
    private let toggleID: UInt32 = 2

    func registerShortcuts(hold: ShortcutBinding, toggle: ShortcutBinding) {
        unregisterAll()
        installEventHandlerIfNeeded()

        let holdHotKeyID = EventHotKeyID(signature: OSType(0x4F415552), id: holdID)
        RegisterEventHotKey(
            hold.keyCode,
            carbonModifiers(for: hold.modifierFlags),
            holdHotKeyID,
            GetEventDispatcherTarget(),
            0,
            &holdShortcutRef
        )

        let toggleHotKeyID = EventHotKeyID(signature: OSType(0x4F415552), id: toggleID)
        RegisterEventHotKey(
            toggle.keyCode,
            carbonModifiers(for: toggle.modifierFlags),
            toggleHotKeyID,
            GetEventDispatcherTarget(),
            0,
            &toggleShortcutRef
        )
    }

    func unregisterAll() {
        if let holdShortcutRef {
            UnregisterEventHotKey(holdShortcutRef)
            self.holdShortcutRef = nil
        }

        if let toggleShortcutRef {
            UnregisterEventHotKey(toggleShortcutRef)
            self.toggleShortcutRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventSpecs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        let userData = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, eventRef, userData in
                guard let eventRef, let userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handle(eventRef: eventRef)
            },
            eventSpecs.count,
            &eventSpecs,
            userData,
            &eventHandlerRef
        )
    }

    private func handle(eventRef: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else {
            return status
        }

        let kind = GetEventKind(eventRef)

        switch (hotKeyID.id, kind) {
        case (holdID, UInt32(kEventHotKeyPressed)):
            onAction?(.holdDown)
        case (holdID, UInt32(kEventHotKeyReleased)):
            onAction?(.holdUp)
        case (toggleID, UInt32(kEventHotKeyPressed)):
            onAction?(.toggle)
        default:
            break
        }

        return noErr
    }

    private func carbonModifiers(for flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0

        if flags.contains(.command) {
            carbon |= UInt32(cmdKey)
        }
        if flags.contains(.control) {
            carbon |= UInt32(controlKey)
        }
        if flags.contains(.option) {
            carbon |= UInt32(optionKey)
        }
        if flags.contains(.shift) {
            carbon |= UInt32(shiftKey)
        }

        return carbon
    }
}
