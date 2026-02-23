import Combine
import Foundation

@MainActor
enum DictationSessionState: Equatable {
    case idle
    case listening(DictationMode)
    case processing
    case inserting
    case error(String)
}

@MainActor
final class DictationSessionManager: ObservableObject {
    @Published private(set) var state: DictationSessionState = .idle
    @Published private(set) var partialText: String = ""
    @Published private(set) var lastTranscript: String = ""
    @Published private(set) var errorMessage: String?

    private let audioCaptureService: AudioCaptureService
    private let transcriptionEngine: any TranscriptionEngine
    private let insertionService: AccessibilityTextInsertionService
    private let repository: AppRepository
    private let modelManager: WhisperModelManager
    private let permissionManager: PermissionManager
    private let bubbleViewModel: BubbleViewModel
    private let overlayController: OverlayPanelController

    private var partialTask: Task<Void, Never>?
    private var startedAt: Date?
    private var currentTargetBundleID: String = "unknown"

    init(
        audioCaptureService: AudioCaptureService,
        transcriptionEngine: any TranscriptionEngine,
        insertionService: AccessibilityTextInsertionService,
        repository: AppRepository,
        modelManager: WhisperModelManager,
        permissionManager: PermissionManager,
        bubbleViewModel: BubbleViewModel,
        overlayController: OverlayPanelController
    ) {
        self.audioCaptureService = audioCaptureService
        self.transcriptionEngine = transcriptionEngine
        self.insertionService = insertionService
        self.repository = repository
        self.modelManager = modelManager
        self.permissionManager = permissionManager
        self.bubbleViewModel = bubbleViewModel
        self.overlayController = overlayController

        wireAudioCallbacks()
    }

    func handleHotkeyAction(_ action: GlobalHotkeyManager.Action) {
        switch action {
        case .holdDown:
            Task { await beginSession(mode: .holdToSpeak) }
        case .holdUp:
            if case .listening(.holdToSpeak) = state {
                Task { await endSession(mode: .holdToSpeak) }
            }
        case .toggle:
            switch state {
            case .listening(.toggle):
                Task { await endSession(mode: .toggle) }
            case .idle, .error:
                Task { await beginSession(mode: .toggle) }
            default:
                break
            }
        }
    }

    func cancelCurrentSession() {
        audioCaptureService.stop()
        partialTask?.cancel()
        partialTask = nil
        Task { await transcriptionEngine.cancelStreaming() }
        transitionToIdle()
    }

    private func beginSession(mode: DictationMode) async {
        switch state {
        case .idle, .error:
            break
        default:
            return
        }

        let hasMicrophoneAccess = await permissionManager.ensureMicrophoneAccess()
        guard hasMicrophoneAccess else {
            state = .error("Microphone access is required.")
            bubbleViewModel.state = .error("Microphone access denied. Grant it in Settings.")
            overlayController.updateAndShow()
            dismissBubbleAfterDelay()
            return
        }

        do {
            partialText = ""
            errorMessage = nil
            startedAt = Date()
            currentTargetBundleID = insertionService.focusedApplicationBundleID()

            state = .listening(mode)
            bubbleViewModel.mode = mode
            bubbleViewModel.partialText = "Speak now..."
            bubbleViewModel.state = .listening
            bubbleViewModel.level = 0
            overlayController.updateAndShow()

            let modelID = modelManager.defaultModelID
            try await transcriptionEngine.prepare(modelID: modelID)
            try await transcriptionEngine.startStreaming()

            try audioCaptureService.start()
            startPartialPolling()
        } catch {
            state = .error(error.localizedDescription)
            bubbleViewModel.state = .error(error.localizedDescription)
            overlayController.updateAndShow()
            dismissBubbleAfterDelay()
        }
    }

    private func endSession(mode: DictationMode) async {
        guard case .listening(let activeMode) = state, activeMode == mode else {
            return
        }

        audioCaptureService.stop()
        partialTask?.cancel()
        partialTask = nil

        state = .processing
        bubbleViewModel.state = .processing
        bubbleViewModel.level = 0
        overlayController.updateAndShow()

        do {
            let transcript = try await transcriptionEngine.finishStreaming()
            let cleanText = transcript.text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleanText.isEmpty else {
                throw NSError(domain: "OpenAuris", code: 2, userInfo: [NSLocalizedDescriptionKey: "No speech detected."])
            }

            state = .inserting
            overlayController.updateAndShow()

            let insertionResult = await insertionService.insert(cleanText)
            let insertionMethod: String

            switch insertionResult {
            case .insertedDirectly:
                insertionMethod = "accessibility"
            case .insertedViaPasteFallback:
                insertionMethod = "paste_fallback"
            case .failed(let reason):
                throw NSError(domain: "OpenAuris", code: 3, userInfo: [NSLocalizedDescriptionKey: reason])
            }

            if let startedAt {
                try repository.saveSession(
                    mode: mode,
                    partialPreview: partialText,
                    transcript: transcript,
                    modelID: modelManager.defaultModelID,
                    startedAt: startedAt,
                    endedAt: Date(),
                    insertionMethod: insertionMethod,
                    targetBundleID: currentTargetBundleID
                )
            }

            lastTranscript = cleanText
            bubbleViewModel.state = .success
            bubbleViewModel.partialText = cleanText
            overlayController.updateAndShow()
            dismissBubbleAfterDelay()

            transitionToIdle()
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            bubbleViewModel.state = .error(error.localizedDescription)
            overlayController.updateAndShow()
            dismissBubbleAfterDelay()
        }
    }

    private func wireAudioCallbacks() {
        audioCaptureService.onFrame = { [weak self] frame in
            guard let self else { return }
            Task {
                await self.transcriptionEngine.appendAudioFrame(frame)
            }
        }

        audioCaptureService.onLevel = { [weak self] level in
            guard let self else { return }
            Task { @MainActor in
                self.bubbleViewModel.level = min(max(level * 6, 0), 1)
                self.overlayController.updateAndShow()
            }
        }
    }

    private func startPartialPolling() {
        partialTask?.cancel()
        partialTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let latest = await self.transcriptionEngine.currentPartialText()
                await MainActor.run {
                    self.partialText = latest
                    if case .listening = self.state {
                        self.bubbleViewModel.partialText = latest
                        self.overlayController.updateAndShow()
                    }
                }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
    }

    private func transitionToIdle() {
        state = .idle
        startedAt = nil
    }

    private func dismissBubbleAfterDelay() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            self.bubbleViewModel.state = .hidden
            self.overlayController.updateAndShow()
        }
    }
}
