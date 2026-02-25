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
