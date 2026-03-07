import Foundation
import SwiftData
import Testing
@testable import openauris

@MainActor
struct DictationSessionManagerModelPreparationTests {
    @Test
    func preloadSkipsRepeatedPrepareForSameActiveModel() async throws {
        let fixture = try makeCountingFixture()

        try await fixture.manager.preloadActiveModelForImmediateUse()
        try await fixture.manager.preloadActiveModelForImmediateUse()

        #expect(await fixture.engine.prepareCallCount == 1)
    }

    @Test
    func concurrentPreloadRequestsShareOnePrepareTask() async throws {
        let engine = BlockingTranscriptionEngine()
        let fixture = try makeFixture(engine: engine)

        async let first: Void = fixture.manager.preloadActiveModelForImmediateUse()
        async let second: Void = fixture.manager.preloadActiveModelForImmediateUse()

        await engine.waitForPrepareToStart()
        await engine.allowPrepareToFinish()

        try await first
        try await second

        #expect(await engine.prepareCallCount == 1)
    }

    @Test
    func toggleWhilePreloadIsRunningShowsMessageWithoutStartingStreaming() async throws {
        let engine = BlockingTranscriptionEngine()
        let fixture = try makeFixture(engine: engine)

        let preloadTask = Task {
            try await fixture.manager.preloadActiveModelForImmediateUse()
        }

        await engine.waitForPrepareToStart()

        fixture.manager.handleHotkeyAction(GlobalHotkeyManager.Action.toggle)
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(fixture.manager.state == DictationSessionState.idle)
        #expect(fixture.audio.startCallCount == 0)
        #expect(await engine.startStreamingCallCount == 0)

        if case .error(let message) = fixture.bubble.state {
            #expect(message.localizedCaseInsensitiveContains("prepar"))
        } else {
            Issue.record("Expected preparing feedback in bubble")
        }

        await engine.allowPrepareToFinish()
        try await preloadTask.value
    }

    @Test
    func toggleStartsImmediatelyAfterModelHasBeenPreloaded() async throws {
        let fixture = try makeCountingFixture()

        try await fixture.manager.preloadActiveModelForImmediateUse()
        fixture.manager.handleHotkeyAction(GlobalHotkeyManager.Action.toggle)
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(fixture.audio.startCallCount == 1)
        #expect(await fixture.engine.startStreamingCallCount == 1)
        #expect(await fixture.engine.prepareCallCount == 1)
        #expect(fixture.bubble.state != BubbleState.preparing)
    }

    private func makeCountingFixture() throws -> SessionFixture<CountingTranscriptionEngine> {
        try makeFixture(engine: CountingTranscriptionEngine())
    }

    private func makeFixture<Engine: TranscriptionEngine>(
        engine: Engine
    ) throws -> SessionFixture<Engine> {
        let container = PersistenceController.makeModelContainer(inMemory: true)
        let repository = AppRepository(context: container.mainContext)
        let _ = try repository.ensurePreferences()
        let audio = TestAudioCaptureService()
        let bubble = BubbleViewModel()

        let manager = DictationSessionManager(
            audioCaptureService: audio,
            transcriptionEngine: engine,
            insertionService: StubTextInsertionService(),
            repository: repository,
            modelManager: TestModelManager(),
            permissionManager: TestPermissionManager(),
            bubbleViewModel: bubble,
            overlayController: TestOverlayController(),
            insertionStrategy: BasicInsertionStrategy()
        )

        return SessionFixture(
            container: container,
            manager: manager,
            audio: audio,
            bubble: bubble,
            engine: engine
        )
    }
}

@MainActor
private struct SessionFixture<Engine: TranscriptionEngine> {
    let container: ModelContainer
    let manager: DictationSessionManager
    let audio: TestAudioCaptureService
    let bubble: BubbleViewModel
    let engine: Engine
}

@MainActor
private final class TestAudioCaptureService: AudioCaptureControlling {
    var onFrame: (@Sendable (AudioFrame) -> Void)?
    var onLevel: (@Sendable (Float) -> Void)?
    private(set) var startCallCount = 0

    func start() throws {
        startCallCount += 1
        onLevel?(0.2)
    }

    func stop() {}
}

@MainActor
private final class TestPermissionManager: PermissionManaging {
    func ensureMicrophoneAccess() async -> Bool {
        true
    }
}

@MainActor
private final class TestOverlayController: OverlayPresenting {
    func updateAndShow() {}
}

@MainActor
private final class TestModelManager: ModelManaging {
    let defaultModelID = "small"
    let downloadBasePath: String? = nil

    func ensureModelInstalled(_ modelID: String) async throws -> String {
        "/tmp/openauris-tests/\(modelID)"
    }

    func reinstall(modelID: String) async throws {}
}

@MainActor
private final class StubTextInsertionService: TextInsertionService {
    func insert(_ text: String) async -> InsertionResult { .insertedViaPasteFallback }
    func appendText(_ text: String) async -> InsertionResult { .insertedViaPasteFallback }
    func focusedApplicationBundleID() -> String { "com.test.stub" }
    func pressBackspace() async {}
}

private actor CountingTranscriptionEngine: TranscriptionEngine {
    private(set) var prepareCallCount = 0
    private(set) var startStreamingCallCount = 0

    func prepare(modelID: String, modelFolderPath: String?, languageOverride: String?) async throws {
        prepareCallCount += 1
    }

    func startStreaming() async throws {
        startStreamingCallCount += 1
    }

    func appendAudioFrame(_ frame: AudioFrame) async {}
    func currentPartialText() async -> String { "" }

    func finishStreaming() async throws -> FinalTranscript {
        FinalTranscript(text: "hello", languageCode: "en", confidence: nil, wordCount: 1, durationSeconds: 1)
    }

    func cancelStreaming() async {}
}

private actor BlockingTranscriptionEngine: TranscriptionEngine {
    private(set) var prepareCallCount = 0
    private(set) var startStreamingCallCount = 0

    private var prepareStartedContinuation: CheckedContinuation<Void, Never>?
    private var prepareFinishedContinuation: CheckedContinuation<Void, Never>?
    private var didStartPrepare = false
    private var didAllowPrepareToFinish = false

    func prepare(modelID: String, modelFolderPath: String?, languageOverride: String?) async throws {
        prepareCallCount += 1
        didStartPrepare = true
        prepareStartedContinuation?.resume()
        prepareStartedContinuation = nil

        if !didAllowPrepareToFinish {
            await withCheckedContinuation { continuation in
                prepareFinishedContinuation = continuation
            }
        }
    }

    func waitForPrepareToStart() async {
        if didStartPrepare { return }
        await withCheckedContinuation { continuation in
            prepareStartedContinuation = continuation
        }
    }

    func allowPrepareToFinish() async {
        didAllowPrepareToFinish = true
        prepareFinishedContinuation?.resume()
        prepareFinishedContinuation = nil
    }

    func startStreaming() async throws {
        startStreamingCallCount += 1
    }

    func appendAudioFrame(_ frame: AudioFrame) async {}
    func currentPartialText() async -> String { "" }

    func finishStreaming() async throws -> FinalTranscript {
        FinalTranscript(text: "hello", languageCode: "en", confidence: nil, wordCount: 1, durationSeconds: 1)
    }

    func cancelStreaming() async {}
}
