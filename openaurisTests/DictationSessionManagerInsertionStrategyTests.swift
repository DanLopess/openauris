import Testing
@testable import openauris

@MainActor
struct DictationSessionManagerInsertionStrategyTests {
    @Test
    func terminalWithoutRealtimeInsertionsUsesAppendPath() {
        #expect(
            DictationSessionManager.shouldAppendForFinalInsertion(
                hadRealtimeInsertions: false,
                isCurrentAppTerminal: true
            ) == true
        )
    }

    @Test
    func standardAppWithoutRealtimeInsertionsUsesInsertPath() {
        #expect(
            DictationSessionManager.shouldAppendForFinalInsertion(
                hadRealtimeInsertions: false,
                isCurrentAppTerminal: false
            ) == false
        )
    }

    @Test
    func realtimeInsertionsAlwaysUseAppendPath() {
        #expect(
            DictationSessionManager.shouldAppendForFinalInsertion(
                hadRealtimeInsertions: true,
                isCurrentAppTerminal: false
            ) == true
        )
    }
}
