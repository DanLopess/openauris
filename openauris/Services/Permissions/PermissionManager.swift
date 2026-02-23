import AVFoundation
import AppKit
import ApplicationServices
import Combine
import Foundation

enum MicrophonePermissionState: Equatable {
    case undetermined
    case granted
    case denied
    case restricted
}

@MainActor
final class PermissionManager: ObservableObject {
    @Published private(set) var microphoneGranted: Bool = false
    @Published private(set) var microphonePermissionState: MicrophonePermissionState = .undetermined
    @Published private(set) var accessibilityGranted: Bool = false

    init() {
        refresh()
    }

    func refresh() {
        microphonePermissionState = resolveMicrophoneState()
        microphoneGranted = microphonePermissionState == .granted
        accessibilityGranted = AXIsProcessTrusted()
    }

    func ensureMicrophoneAccess() async -> Bool {
        switch resolveMicrophoneState() {
        case .granted:
            refresh()
            return true
        case .undetermined:
            NSApplication.shared.activate(ignoringOtherApps: true)
            let granted = await requestMicrophonePermissionPrompt()
            refresh()
            return granted
        case .denied, .restricted:
            refresh()
            return false
        }
    }

    func requestMicrophone() async -> Bool {
        let granted = await ensureMicrophoneAccess()

        if !granted {
            if microphonePermissionState == .denied || microphonePermissionState == .restricted {
                openMicrophoneSettings()
            }
        }

        return granted
    }

    func requestAccessibilityPrompt() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    func openMicrophoneSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func resolveMicrophoneState() -> MicrophonePermissionState {
        let captureState: MicrophonePermissionState
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            captureState = .granted
        case .denied:
            captureState = .denied
        case .restricted:
            captureState = .restricted
        case .notDetermined:
            captureState = .undetermined
        @unknown default:
            captureState = .denied
        }

        if #available(macOS 14.0, *) {
            let avAudioState: MicrophonePermissionState
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                avAudioState = .granted
            case .denied:
                avAudioState = .denied
            case .undetermined:
                avAudioState = .undetermined
            @unknown default:
                avAudioState = .denied
            }

            return mergedMicrophoneState(captureState: captureState, avAudioState: avAudioState)
        }

        return captureState
    }

    private func requestMicrophonePermissionPrompt() async -> Bool {
        let captureGranted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }

        if captureGranted {
            return true
        }

        guard #available(macOS 14.0, *) else {
            return false
        }

        if AVAudioApplication.shared.recordPermission == .undetermined {
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        return false
    }

    private func mergedMicrophoneState(
        captureState: MicrophonePermissionState,
        avAudioState: MicrophonePermissionState
    ) -> MicrophonePermissionState {
        if captureState == .granted || avAudioState == .granted {
            return .granted
        }

        if captureState == .undetermined || avAudioState == .undetermined {
            return .undetermined
        }

        if captureState == .restricted || avAudioState == .restricted {
            return .restricted
        }

        return .denied
    }
}
