import Testing
@testable import openauris

@MainActor
struct BubbleStateTests {
    @Test
    func preparingStateIsVisibleAndUsesPreparingRingToken() {
        let viewModel = BubbleViewModel()
        viewModel.state = .preparing

        #expect(viewModel.isVisible == true)
        #expect(viewModel.state.ringStyleToken == .preparing)
    }

    @Test
    func hiddenStateIsNotVisibleAndUsesHiddenRingToken() {
        let viewModel = BubbleViewModel()
        viewModel.state = .hidden

        #expect(viewModel.isVisible == false)
        #expect(viewModel.state.ringStyleToken == .hidden)
    }

    @Test
    func lifecycleStateRingTokensMatchExpectedColors() {
        #expect(BubbleState.preparing.ringStyleToken == .preparing) // gray while model loads
        #expect(BubbleState.listening.ringStyleToken == .listening) // gradient while speaking
        #expect(BubbleState.processing.ringStyleToken == .processing) // blue while processing
        #expect(BubbleState.success.ringStyleToken == .success) // green when done
    }
}
