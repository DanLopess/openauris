import Testing
@testable import openauris

struct BubbleReadinessGateTests {
    @Test
    func firstFrameTransitionsToReadyOnlyAfterArming() {
        var gate = BubbleReadinessGate()

        #expect(gate.consumeFirstAudioFrameIfNeeded() == false)

        gate.armForStreamingStart()
        #expect(gate.consumeFirstAudioFrameIfNeeded() == true)
        #expect(gate.consumeFirstAudioFrameIfNeeded() == false)
    }

    @Test
    func disarmPreventsLateReadyTransition() {
        var gate = BubbleReadinessGate()

        gate.armForStreamingStart()
        gate.disarm()

        #expect(gate.consumeFirstAudioFrameIfNeeded() == false)
    }
}
