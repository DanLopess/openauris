import Testing
@testable import openauris

struct DictationFinalizationTests {
    @Test
    func cleanedFinalTextThrowsOnNoSpeech() {
        #expect(throws: DictationFinalizationError.noSpeechDetected) {
            try DictationFinalization.cleanedFinalText(from: "[NOISE] <|0.00|> [BLANK_AUDIO]")
        }
    }

    @Test
    func cleanedFinalTextReturnsSanitizedTranscript() throws {
        let text = try DictationFinalization.cleanedFinalText(from: "Hello [NOISE] world.")
        #expect(text == "Hello world.")
    }

    @Test
    func insertionFailureThrowsMeaningfulError() {
        #expect(throws: DictationFinalizationError.insertionFailed("Pasteboard unavailable")) {
            try DictationFinalization.assertInsertionSucceeded(.failed(reason: "Pasteboard unavailable"))
        }
    }

    @Test
    func insertionMethodReflectsRealtimeFlow() {
        let method = DictationFinalization.insertionMethod(
            from: .insertedViaPasteFallback,
            hadRealtimeInsertions: true
        )
        #expect(method == "paste_realtime")
    }

    @Test
    func insertionMethodReflectsFinalOnlyFlow() {
        let method = DictationFinalization.insertionMethod(
            from: .insertedDirectly,
            hadRealtimeInsertions: false
        )
        #expect(method == "accessibility_direct")
    }
}
