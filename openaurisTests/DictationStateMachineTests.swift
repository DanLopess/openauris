import Testing
@testable import openauris

@MainActor
struct DictationStateMachineTests {
    @Test
    func holdFlowTransitionsToProcessing() {
        var state: DictationSessionState = .idle
        state = DictationStateMachine.nextState(current: state, action: .holdDown)
        #expect(state == .listening(.holdToSpeak))

        state = DictationStateMachine.nextState(current: state, action: .holdUp)
        #expect(state == .processing)
    }

    @Test
    func toggleFlowTransitionsToProcessing() {
        var state: DictationSessionState = .idle
        state = DictationStateMachine.nextState(current: state, action: .togglePress)
        #expect(state == .listening(.toggle))

        state = DictationStateMachine.nextState(current: state, action: .togglePress)
        #expect(state == .processing)
    }

    @Test
    func togglePressStopsActiveHoldToSpeakSession() {
        let state = DictationStateMachine.nextState(current: .listening(.holdToSpeak), action: .togglePress)
        #expect(state == .processing)
    }
}
