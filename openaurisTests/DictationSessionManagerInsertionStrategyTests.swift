import Testing
@testable import openauris

@MainActor
struct DictationSessionManagerInsertionStrategyTests {
    @Test
    func basicStrategyReportsNoRealtimeInsertions() {
        let strategy = BasicInsertionStrategy()
        #expect(strategy.hadRealtimeInsertions == false)
    }

    @Test
    func basicStrategyHadRealtimeInsertionsAlwaysFalseAfterSessionEnd() async {
        let strategy = BasicInsertionStrategy()
        // Even after a session end, basic strategy never reports realtime insertions.
        let result = await strategy.sessionDidEnd(
            finalText: "",
            insertionService: StubTextInsertionService()
        )
        #expect(strategy.hadRealtimeInsertions == false)
        if case .failed = result {
            // Expected: empty text produces failed result
        } else {
            Issue.record("Expected .failed for empty text")
        }
    }

    @Test
    func streamingStrategyReportsNoRealtimeInsertionsInitially() {
        let strategy = StreamingInsertionStrategy()
        #expect(strategy.hadRealtimeInsertions == false)
    }

    @Test
    func basicStrategySessionCancelIsIdempotent() {
        let strategy = BasicInsertionStrategy()
        strategy.sessionDidCancel()
        strategy.sessionDidCancel()
        #expect(strategy.hadRealtimeInsertions == false)
    }

    @Test
    func streamingStrategySessionCancelResetsState() {
        let strategy = StreamingInsertionStrategy()
        strategy.sessionDidCancel()
        #expect(strategy.hadRealtimeInsertions == false)
    }

    @Test
    func streamingStrategyAppendsOnlyDeltaAtSessionEndWhenFinalExtendsPartial() async {
        let strategy = StreamingInsertionStrategy()
        let engine = StubStreamingEngine(partial: "hello")
        let insertionService = SpyTextInsertionService()

        strategy.sessionDidStart(
            engine: engine,
            insertionService: insertionService,
            shouldInsertRealtimePartials: true,
            isCurrentAppTerminal: false,
            onPartialText: { _ in }
        )

        await waitForRealtimeInsert(insertionService, expected: "hello")

        let result = await strategy.sessionDidEnd(
            finalText: "hello world",
            insertionService: insertionService
        )

        switch result {
        case .insertedViaPasteFallback:
            break
        default:
            Issue.record("Expected final insertion via paste fallback")
        }

        #expect(strategy.hadRealtimeInsertions == true)
        #expect(insertionService.backspaceCount == 0)
        #expect(insertionService.appendedTexts == ["hello", " world"])
    }

    private func waitForRealtimeInsert(
        _ insertionService: SpyTextInsertionService,
        expected: String
    ) async {
        for _ in 0..<30 {
            if insertionService.appendedTexts.contains(expected) {
                return
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        Issue.record("Timed out waiting for expected realtime insertion: \(expected)")
    }
}

@MainActor
private final class StubTextInsertionService: TextInsertionService {
    func insert(_ text: String) async -> InsertionResult {
        .insertedViaPasteFallback
    }

    func appendText(_ text: String) async -> InsertionResult {
        .insertedViaPasteFallback
    }

    func focusedApplicationBundleID() -> String {
        "com.test.stub"
    }

    func pressBackspace() async {}
}

private actor StubStreamingEngine: TranscriptionEngine {
    let partial: String

    init(partial: String) {
        self.partial = partial
    }

    func prepare(modelID: String, modelFolderPath: String?, languageOverride: String?) async throws {}
    func startStreaming() async throws {}
    func appendAudioFrame(_ frame: AudioFrame) async {}
    func currentPartialText() async -> String { partial }
    func finishStreaming() async throws -> FinalTranscript {
        FinalTranscript(text: partial, languageCode: "en", confidence: nil, wordCount: 1, durationSeconds: 1)
    }
    func cancelStreaming() async {}
}

@MainActor
private final class SpyTextInsertionService: TextInsertionService {
    private(set) var appendedTexts: [String] = []
    private(set) var backspaceCount = 0

    func insert(_ text: String) async -> InsertionResult {
        .insertedViaPasteFallback
    }

    func appendText(_ text: String) async -> InsertionResult {
        appendedTexts.append(text)
        return .insertedViaPasteFallback
    }

    func focusedApplicationBundleID() -> String {
        "com.test.spy"
    }

    func pressBackspace() async {
        backspaceCount += 1
    }
}
