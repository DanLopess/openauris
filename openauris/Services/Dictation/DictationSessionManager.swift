import Foundation
import Observation

@MainActor
protocol AudioCaptureControlling: AnyObject {
    var onFrame: (@Sendable (AudioFrame) -> Void)? { get set }
    var onLevel: (@Sendable (Float) -> Void)? { get set }
    func start() throws
    func stop()
}

@MainActor
protocol ModelManaging: AnyObject {
    var defaultModelID: String { get }
    var downloadBasePath: String? { get }
    func ensureModelInstalled(_ modelID: String) async throws -> String
    func reinstall(modelID: String) async throws
}

@MainActor
protocol PermissionManaging: AnyObject {
    func ensureMicrophoneAccess() async -> Bool
}

@MainActor
protocol OverlayPresenting: AnyObject {
    func updateAndShow()
}

extension AudioCaptureService: AudioCaptureControlling {}
extension WhisperModelManager: ModelManaging {}
extension PermissionManager: PermissionManaging {}
extension OverlayPanelController: OverlayPresenting {}

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
enum ModelPreparationState: Equatable {
    case preparing
    case ready
    case error(String)
}

private struct ModelPreparationRequest: Equatable {
    let modelID: String
    let languageOverride: String?
    let downloadBasePath: String?
}

private struct PreparedModelContext: Equatable {
    let modelID: String
    let modelFolderPath: String
    let languageOverride: String?
    let downloadBasePath: String?

    func matches(_ request: ModelPreparationRequest) -> Bool {
        modelID == request.modelID &&
        languageOverride == request.languageOverride &&
        downloadBasePath == request.downloadBasePath
    }
}

@MainActor
@Observable
final class DictationSessionManager {
    private(set) var state: DictationSessionState = .idle
    private(set) var partialText: String = ""
    private(set) var lastTranscript: String = ""
    private(set) var errorMessage: String?

    private let audioCaptureService: any AudioCaptureControlling
    private let transcriptionEngine: any TranscriptionEngine
    private let insertionService: any TextInsertionService
    private let repository: AppRepository
    private let modelManager: any ModelManaging
    private let permissionManager: any PermissionManaging
    private let bubbleViewModel: BubbleViewModel
    private let overlayController: any OverlayPresenting
    private var onModelError: (String) -> Void = { _ in }
    private var onModelPreparationStateChange: (ModelPreparationState) -> Void = { _ in }

    private var insertionStrategy: InsertionStrategy
    private var beginTask: Task<Void, Never>?
    private var bubbleReadinessGate = BubbleReadinessGate()
    private var preparedContext: PreparedModelContext?
    private var preloadRequest: ModelPreparationRequest?
    private var preloadTask: Task<PreparedModelContext, Error>?
    private var streamingActive = false
    private var holdShortcutIsPressed = false
    private var lastToggleActionAt: Date?
    private var startedAt: Date?
    private var currentTargetBundleID: String = "unknown"
    private var isCurrentAppTerminal: Bool = false

    init(
        audioCaptureService: any AudioCaptureControlling,
        transcriptionEngine: any TranscriptionEngine,
        insertionService: any TextInsertionService,
        repository: AppRepository,
        modelManager: any ModelManaging,
        permissionManager: any PermissionManaging,
        bubbleViewModel: BubbleViewModel,
        overlayController: any OverlayPresenting,
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

    func setModelPreparationStateHandler(_ handler: @escaping (ModelPreparationState) -> Void) {
        onModelPreparationStateChange = handler
    }

    func setInsertionStrategy(_ strategy: InsertionStrategy) {
        guard state == .idle else { return }
        insertionStrategy = strategy
    }

    func preloadActiveModelForImmediateUse() async throws {
        guard canPrepareModel else {
            throw NSError(
                domain: "OpenAuris.DictationSessionManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Finish the current dictation before changing the active model."]
            )
        }

        let request = try currentModelPreparationRequest()
        if let preparedContext, preparedContext.matches(request) {
            onModelPreparationStateChange(.ready)
            return
        }

        if let preloadTask, preloadRequest == request {
            _ = try await preloadTask.value
            return
        }

        onModelPreparationStateChange(.preparing)
        let task = Task { try await self.prepareContext(for: request) }
        preloadTask = task
        preloadRequest = request

        do {
            let prepared = try await task.value
            if preloadRequest == request {
                preparedContext = prepared
                preloadTask = nil
                preloadRequest = nil
            }
            onModelPreparationStateChange(.ready)
        } catch {
            if preloadRequest == request {
                preparedContext = nil
                preloadTask = nil
                preloadRequest = nil
            }
            let message = error.localizedDescription
            onModelPreparationStateChange(.error(message))
            onModelError(message)
            throw error
        }
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
            guard try isActiveModelReadyForImmediateStart() else {
                requestBackgroundPreload()
                presentPreparingFeedback()
                return
            }

            partialText = ""
            errorMessage = nil
            startedAt = Date()
            currentTargetBundleID = insertionService.focusedApplicationBundleID()
            isCurrentAppTerminal = isTerminalApp(currentTargetBundleID)

            let languageOverride = try repository.ensurePreferences().languageOverride
            let shouldInsertRealtimePartials = RealtimeInsertionPolicy.shouldInsertPartials(
                languageOverride: languageOverride
            )

            state = .listening(mode)
            bubbleViewModel.level = 0

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

    private var canPrepareModel: Bool {
        switch state {
        case .idle, .error:
            return true
        case .listening, .processing, .inserting:
            return false
        }
    }

    private func currentModelPreparationRequest() throws -> ModelPreparationRequest {
        let preferences = try repository.ensurePreferences()
        return ModelPreparationRequest(
            modelID: modelManager.defaultModelID,
            languageOverride: WhisperKitConfiguration.normalizedLanguageOverride(preferences.languageOverride),
            downloadBasePath: modelManager.downloadBasePath
        )
    }

    private func isActiveModelReadyForImmediateStart() throws -> Bool {
        guard let preparedContext else { return false }
        return preparedContext.matches(try currentModelPreparationRequest())
    }

    private func prepareContext(for request: ModelPreparationRequest) async throws -> PreparedModelContext {
        let initialFolderPath = try await modelManager.ensureModelInstalled(request.modelID)

        do {
            try await transcriptionEngine.prepare(
                modelID: request.modelID,
                modelFolderPath: initialFolderPath,
                languageOverride: request.languageOverride
            )

            return PreparedModelContext(
                modelID: request.modelID,
                modelFolderPath: initialFolderPath,
                languageOverride: request.languageOverride,
                downloadBasePath: request.downloadBasePath
            )
        } catch {
            try await modelManager.reinstall(modelID: request.modelID)
            let repairedFolderPath = try await modelManager.ensureModelInstalled(request.modelID)
            try await transcriptionEngine.prepare(
                modelID: request.modelID,
                modelFolderPath: repairedFolderPath,
                languageOverride: request.languageOverride
            )

            return PreparedModelContext(
                modelID: request.modelID,
                modelFolderPath: repairedFolderPath,
                languageOverride: request.languageOverride,
                downloadBasePath: request.downloadBasePath
            )
        }
    }

    private func requestBackgroundPreload() {
        Task { [weak self] in
            try? await self?.preloadActiveModelForImmediateUse()
        }
    }

    private func presentPreparingFeedback() {
        transitionToIdle()
        bubbleViewModel.state = .error("Model is still preparing. Try again in a moment.")
        bubbleViewModel.level = 0
        overlayController.updateAndShow()
        dismissBubbleAfterDelay()
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
