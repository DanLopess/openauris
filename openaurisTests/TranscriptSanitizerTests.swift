import Testing
@testable import openauris

struct TranscriptSanitizerTests {

    @Test
    func removesBlankAudioAndSpecialTokens() {
        let raw = "I am testing [BLANK_AUDIO] <|en|> this works."
        #expect(sanitizeTranscriptText(raw) == "I am testing this works.")
    }

    @Test
    func removesInaudibleToken() {
        #expect(sanitizeTranscriptText("Hello [INAUDIBLE] world.") == "Hello world.")
    }

    @Test
    func removesNoiseToken() {
        #expect(sanitizeTranscriptText("[NOISE] Start of sentence.") == "Start of sentence.")
    }

    @Test
    func removesLaughterAndApplause() {
        let raw = "That was funny [LAUGHTER] and impressive [APPLAUSE]."
        #expect(sanitizeTranscriptText(raw) == "That was funny and impressive.")
    }

    @Test
    func removesMusicToken() {
        #expect(sanitizeTranscriptText("[MUSIC] Some speech [MUSIC]") == "Some speech")
    }

    @Test
    func removesMultipleTokens() {
        let raw = "[BLANK_AUDIO] [INAUDIBLE] Hello [NOISE] world [SILENCE]."
        #expect(sanitizeTranscriptText(raw) == "Hello world.")
    }

    @Test
    func removesTimestampTokens() {
        let raw = "<|0.00|> Hello <|1.50|> world <|transcribe|>."
        #expect(sanitizeTranscriptText(raw) == "Hello world.")
    }

    @Test
    func collapsesDuplicateWhitespace() {
        #expect(sanitizeTranscriptText("Hello   world") == "Hello world")
    }

    @Test
    func handlesEmptyString() {
        #expect(sanitizeTranscriptText("") == "")
    }

    @Test
    func handlesOnlyTokens() {
        #expect(sanitizeTranscriptText("[BLANK_AUDIO] [INAUDIBLE] <|0.00|>") == "")
    }

    @Test
    func removesParenthesizedNoiseMarkers() {
        let raw = "Please continue (paper rustling) with the note."
        #expect(sanitizeTranscriptText(raw) == "Please continue with the note.")
    }

    @Test
    func keepsOrdinaryParentheticalSpeech() {
        let raw = "Remind me (tomorrow morning) to call Alex."
        #expect(sanitizeTranscriptText(raw) == "Remind me (tomorrow morning) to call Alex.")
    }
}
