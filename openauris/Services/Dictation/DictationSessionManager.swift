import Foundation
import Observation

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

    private var partialTask: Task<Void, Never>?
    private var beginTask: Task<Void, Never>?
    private var streamingActive = false
    private var holdShortcutIsPressed = false
    private var lastToggleActionAt: Date?
    private var startedAt: Date?
    private var shouldInsertRealtimePartials = false
    private var currentTargetBundleID: String = "unknown"
    private var isCurrentAppTerminal: Bool = false

    // Insertion tracking (normal apps only)
    private var lastInsertedText: String = ""
    private var insertedCharCount: Int = 0
    private var isInsertingPartial = false
    private var lastPartialInsertAt: Date = .distantPast
    private let minInsertInterval: TimeInterval = 0.8

    init(
        audioCaptureService: AudioCaptureService,
        transcriptionEngine: any TranscriptionEngine,
        insertionService: any TextInsertionService,
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
        audioCaptureService.stop()
        partialTask?.cancel()
        partialTask = nil
        Task { await transcriptionEngine.cancelStreaming() }
        bubbleViewModel.state = .hidden
        streamingActive = false
        resetInsertionState()
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
            resetInsertionState()

            state = .listening(mode)
            bubbleViewModel.state = .preparing
            bubbleViewModel.level = 0
            overlayController.updateAndShow()

            let modelID = modelManager.defaultModelID
            let languageOverride = try repository.ensurePreferences().languageOverride
            shouldInsertRealtimePartials = RealtimeInsertionPolicy.shouldInsertPartials(
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
                try await transcriptionEngine.prepare(
                    modelID: modelID,
                    modelFolderPath: repairedModelFolderPath,
                    languageOverride: languageOverride
                )
            }
            try Task.checkCancellation()
            guard mode != .holdToSpeak || holdShortcutIsPressed else {
                throw CancellationError()
            }

            try await transcriptionEngine.startStreaming()
            try Task.checkCancellation()

            try audioCaptureService.start()
            bubbleViewModel.state = .listening
            streamingActive = true
            startPartialPolling()
            overlayController.updateAndShow()
        } catch is CancellationError {
            if case .listening(let activeMode) = state, activeMode == mode {
                audioCaptureService.stop()
                partialTask?.cancel()
                partialTask = nil
                await transcriptionEngine.cancelStreaming()
                streamingActive = false
                transitionToIdle()
            }
        } catch {
            shouldInsertRealtimePartials = false
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
            cancelCurrentSession()
            return
        }

        audioCaptureService.stop()
        partialTask?.cancel()
        partialTask = nil
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

            let hadRealtimeInsertions = insertedCharCount > 0

            // Replace whatever we inserted incrementally with the final accurate text.
            // For terminal apps insertedCharCount is 0 (nothing was inserted during streaming),
            // so replaceInsertedText simply pastes the final text directly.
            let insertionResult = await replaceInsertedText(with: cleaned)
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
                    let sanitized = sanitizeTranscriptText(latest)
                    self.partialText = sanitized

                    if case .listening = self.state {
                        // Skip "Listening… Xs" placeholder, duplicates, concurrent inserts,
                        // terminal apps, and inserts that are too close together.
                        guard !sanitized.isEmpty,
                              !sanitized.hasPrefix("Listening…"),
                              self.shouldInsertRealtimePartials,
                              !self.isCurrentAppTerminal,
                              sanitized != self.lastInsertedText,
                              !self.isInsertingPartial,
                              Date().timeIntervalSince(self.lastPartialInsertAt) >= self.minInsertInterval
                        else { return }

                        self.isInsertingPartial = true
                        Task {
                            await self.insertPartialText(sanitized)
                        }
                    }
                }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
    }

    /// Extension-only partial insertion.
    ///
    /// Only appends text when the new partial is a case-insensitive extension of what
    /// was already inserted. Any re-decode that changes earlier words is silently skipped
    /// — the final accurate transcript will replace everything at session end.
    /// This eliminates all backspacing during the live streaming phase.
    private func insertPartialText(_ newText: String) async {
        defer { isInsertingPartial = false }

        // Case-insensitive prefix check: handles WhisperKit re-capitalising the first
        // word of a segment between decodes (e.g. "hello" → "Hello,").
        guard newText.lowercased().hasPrefix(lastInsertedText.lowercased()) else {
            return   // Not a clean extension — skip, let the final replace handle it.
        }

        let delta = String(newText.dropFirst(lastInsertedText.count))
        guard !delta.isEmpty else { return }

        _ = await insertionService.appendText(delta)
        lastInsertedText = newText
        insertedCharCount += delta.count
        lastPartialInsertAt = Date()
    }

    private func replaceInsertedText(with newText: String) async -> InsertionResult {
        let hadRealtimeInsertions = insertedCharCount > 0
        let shouldAppend = Self.shouldAppendForFinalInsertion(
            hadRealtimeInsertions: hadRealtimeInsertions,
            isCurrentAppTerminal: isCurrentAppTerminal
        )

        // Delete only what we previously inserted at the cursor.
        // For terminal apps this is always 0, so the loop is skipped.
        if hadRealtimeInsertions {
            for _ in 0..<insertedCharCount {
                await insertionService.pressBackspace()
            }
            insertedCharCount = 0
        }

        guard !newText.isEmpty else {
            return .failed(reason: "Transcript is empty.")
        }

        if shouldAppend {
            return await insertionService.appendText(newText)
        }

        return await insertionService.insert(newText)
    }

    static func shouldAppendForFinalInsertion(
        hadRealtimeInsertions: Bool,
        isCurrentAppTerminal: Bool
    ) -> Bool {
        hadRealtimeInsertions || isCurrentAppTerminal
    }

    private func resetInsertionState() {
        lastInsertedText = ""
        insertedCharCount = 0
        isInsertingPartial = false
        lastPartialInsertAt = .distantPast
        // isCurrentAppTerminal is intentionally NOT reset here — it is a session-level
        // flag set in beginSession and must survive past the insertion state reset.
    }

    private func transitionToIdle() {
        state = .idle
        startedAt = nil
        shouldInsertRealtimePartials = false
    }

    private func dismissBubbleAfterDelay() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            self.bubbleViewModel.state = .hidden
            self.overlayController.updateAndShow()
        }
    }
}
