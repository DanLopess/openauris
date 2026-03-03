import Foundation
import Observation

struct BubbleReadinessGate {
    private var awaitingFirstFrame = false

    mutating func armForStreamingStart() {
        awaitingFirstFrame = true
    }

    mutating func consumeFirstAudioFrameIfNeeded() -> Bool {
        guard awaitingFirstFrame else { return false }
        awaitingFirstFrame = false
        return true
    }

    mutating func disarm() {
        awaitingFirstFrame = false
    }
}

@MainActor
enum DictationSessionState: Equatable {
    case idle
    case listening(DictationMode)
    case processing
    case inserting
    case error(String)
}

@MainActor
@Observable
final class DictationSessionManager {
    private(set) var state: DictationSessionState = .idle
    private(set) var partialText: String = ""
    private(set) var lastTranscript: String = ""
    private(set) var errorMessage: String?

    private let audioCaptureService: AudioCaptureService
    private let transcriptionEngine: any TranscriptionEngine
    private let insertionService: any TextInsertionService
    private let repository: AppRepository
    private let modelManager: WhisperModelManager
    private let permissionManager: PermissionManager
    private let bubbleViewModel: BubbleViewModel
    private let overlayController: OverlayPanelController
    private var onModelError: (String) -> Void = { _ in }

    private var insertionStrategy: InsertionStrategy
    private var beginTask: Task<Void, Never>?
    private var bubbleReadinessGate = BubbleReadinessGate()
    private var streamingActive = false
    private var holdShortcutIsPressed = false
    private var lastToggleActionAt: Date?
    private var startedAt: Date?
    private var currentTargetBundleID: String = "unknown"
    private var isCurrentAppTerminal: Bool = false

    init(
        audioCaptureService: AudioCaptureService,
        transcriptionEngine: any TranscriptionEngine,
        insertionService: any TextInsertionService,
        repository: AppRepository,
        modelManager: WhisperModelManager,
        permissionManager: PermissionManager,
        bubbleViewModel: BubbleViewModel,
        overlayController: OverlayPanelController,
        insertionStrategy: InsertionStrategy,
        onModelError: @escaping (String) -> Void = { _ in }
    ) {
        self.audioCaptureService = audioCaptureService
        self.transcriptionEngine = transcriptionEngine
        self.insertionService = insertionService
        self.repository = repository
        self.modelManager = modelManager
        self.permissionManager = permissionManager
        self.bubbleViewModel = bubbleViewModel
        self.overlayController = overlayController
        self.insertionStrategy = insertionStrategy
        self.onModelError = onModelError

        wireAudioCallbacks()
    }
    
    func setModelErrorHandler(_ handler: @escaping (String) -> Void) {
        onModelError = handler
    }

    func setInsertionStrategy(_ strategy: InsertionStrategy) {
        guard state == .idle else { return }
        insertionStrategy = strategy
    }

    func handleHotkeyAction(_ action: GlobalHotkeyManager.Action) {
        switch action {
        case .holdDown:
            guard !holdShortcutIsPressed else { return }
            holdShortcutIsPressed = true
            startSession(mode: .holdToSpeak)
        case .holdUp:
            holdShortcutIsPressed = false
            if case .listening(.holdToSpeak) = state {
                stopSession(mode: .holdToSpeak)
            } else {
                beginTask?.cancel()
                beginTask = nil
            }
        case .toggle:
            let now = Date()
            if let lastToggleActionAt, now.timeIntervalSince(lastToggleActionAt) < 0.2 {
                return
            }
            self.lastToggleActionAt = now
            switch state {
            case .listening(let activeMode):
                stopSession(mode: activeMode)
            case .idle, .error:
                startSession(mode: .toggle)
            case .processing, .inserting:
                cancelCurrentSession()
            }
        }
    }

    func cancelCurrentSession() {
        beginTask?.cancel()
        beginTask = nil
        bubbleReadinessGate.disarm()
        audioCaptureService.stop()
        insertionStrategy.sessionDidCancel()
        Task { await transcriptionEngine.cancelStreaming() }
        bubbleViewModel.state = .hidden
        streamingActive = false
        overlayController.updateAndShow()
        transitionToIdle()
    }

    private func startSession(mode: DictationMode) {
        beginTask?.cancel()
        beginTask = Task { [weak self] in
            await self?.beginSession(mode: mode)
        }
    }

    private func stopSession(mode: DictationMode) {
        beginTask?.cancel()
        beginTask = nil
        Task { [weak self] in
            await self?.endSession(mode: mode)
        }
    }

    private func beginSession(mode: DictationMode) async {
        guard mode != .holdToSpeak || holdShortcutIsPressed else {
            return
        }

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
            guard mode != .holdToSpeak || holdShortcutIsPressed else {
                throw CancellationError()
            }

            try Task.checkCancellation()
            partialText = ""
            errorMessage = nil
            startedAt = Date()
            currentTargetBundleID = insertionService.focusedApplicationBundleID()
            isCurrentAppTerminal = isTerminalApp(currentTargetBundleID)

            state = .listening(mode)
            bubbleViewModel.state = .preparing
            bubbleViewModel.level = 0
            overlayController.updateAndShow()

            let modelID = modelManager.defaultModelID
            let languageOverride = try repository.ensurePreferences().languageOverride
            let shouldInsertRealtimePartials = RealtimeInsertionPolicy.shouldInsertPartials(
                languageOverride: languageOverride
            )
            let modelFolderPath = try await modelManager.ensureModelInstalled(modelID)
            try Task.checkCancellation()
            guard mode != .holdToSpeak || holdShortcutIsPressed else {
                throw CancellationError()
            }

            do {
                try await transcriptionEngine.prepare(
                    modelID: modelID,
                    modelFolderPath: modelFolderPath,
                    languageOverride: languageOverride
                )
            } catch {
                // Recover from partially written/corrupted local model artifacts.
                try await modelManager.reinstall(modelID: modelID)
                let repairedModelFolderPath = try await modelManager.ensureModelInstalled(modelID)
                do {
                    try await transcriptionEngine.prepare(
                        modelID: modelID,
                        modelFolderPath: repairedModelFolderPath,
                        languageOverride: languageOverride
                    )
                } catch {
                    // If recovery fails, this is a genuine model error
                    onModelError(error.localizedDescription)
                    throw error
                }
            }
            try Task.checkCancellation()
            guard mode != .holdToSpeak || holdShortcutIsPressed else {
                throw CancellationError()
            }

            try await transcriptionEngine.startStreaming()
            try Task.checkCancellation()

            bubbleReadinessGate.armForStreamingStart()
            try audioCaptureService.start()
            bubbleViewModel.state = .listening
            streamingActive = true

            insertionStrategy.sessionDidStart(
                engine: transcriptionEngine,
                insertionService: insertionService,
                shouldInsertRealtimePartials: shouldInsertRealtimePartials,
                isCurrentAppTerminal: isCurrentAppTerminal,
                onPartialText: { [weak self] text in
                    self?.partialText = text
                }
            )

            overlayController.updateAndShow()
        } catch is CancellationError {
            if case .listening(let activeMode) = state, activeMode == mode {
                bubbleReadinessGate.disarm()
                audioCaptureService.stop()
                insertionStrategy.sessionDidCancel()
                await transcriptionEngine.cancelStreaming()
                streamingActive = false
                transitionToIdle()
            }
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

        // If streaming never started (for example, hold was released during startup),
        // cancel silently instead of producing a "No speech detected" error.
        guard streamingActive else {
            bubbleReadinessGate.disarm()
            cancelCurrentSession()
            return
        }

        bubbleReadinessGate.disarm()
        audioCaptureService.stop()
        streamingActive = false

        state = .processing
        bubbleViewModel.state = .processing
        bubbleViewModel.level = 0
        overlayController.updateAndShow()

        do {
            let transcript = try await transcriptionEngine.finishStreaming()
            let cleaned = try DictationFinalization.cleanedFinalText(from: transcript.text)

            state = .inserting
            overlayController.updateAndShow()

            let insertionResult = await insertionStrategy.sessionDidEnd(
                finalText: cleaned,
                insertionService: insertionService
            )
            let hadRealtimeInsertions = insertionStrategy.hadRealtimeInsertions
            try DictationFinalization.assertInsertionSucceeded(insertionResult)
            let insertionMethod = DictationFinalization.insertionMethod(
                from: insertionResult,
                hadRealtimeInsertions: hadRealtimeInsertions
            )

            let storedTranscript = FinalTranscript(
                text: cleaned,
                languageCode: transcript.languageCode,
                confidence: transcript.confidence,
                wordCount: cleaned.openAurisWordCount,
                durationSeconds: transcript.durationSeconds
            )

            if let startedAt {
                try repository.saveSession(
                    mode: mode,
                    partialPreview: partialText,
                    transcript: storedTranscript,
                    modelID: modelManager.defaultModelID,
                    startedAt: startedAt,
                    endedAt: Date(),
                    insertionMethod: insertionMethod,
                    targetBundleID: currentTargetBundleID
                )
            }

            lastTranscript = cleaned
            bubbleViewModel.state = .success
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
                if self.bubbleReadinessGate.consumeFirstAudioFrameIfNeeded() {
                    self.bubbleViewModel.state = .listening
                }
                self.bubbleViewModel.level = min(max(level * 6, 0), 1)
                self.overlayController.updateAndShow()
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
