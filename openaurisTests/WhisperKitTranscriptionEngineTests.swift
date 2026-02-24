import Testing
import WhisperKit
@testable import openauris

struct WhisperKitTranscriptionEngineTests {
    @Test
    func downloadDisabledWhenLocalModelFolderExists() {
        let shouldDownload = WhisperKitConfiguration.downloadFlag(modelFolderPath: "/tmp/openai_whisper-small")
        #expect(shouldDownload == false)
    }

    @Test
    func downloadEnabledWhenLocalModelFolderMissing() {
        let shouldDownload = WhisperKitConfiguration.downloadFlag(modelFolderPath: nil)
        #expect(shouldDownload == true)
    }

    @Test
    func autoLanguageUsesDetection() {
        let options = WhisperKitConfiguration.decodingOptions(languageOverride: "auto")
        #expect(options.language == nil)
        #expect(options.detectLanguage == true)
    }

    @Test
    func explicitLanguageDisablesDetection() {
        let options = WhisperKitConfiguration.decodingOptions(languageOverride: "en")
        #expect(options.language == "en")
        #expect(options.detectLanguage == false)
    }

    @Test
    func blankLanguageUsesDetection() {
        let options = WhisperKitConfiguration.decodingOptions(languageOverride: "  ")
        #expect(options.language == nil)
        #expect(options.detectLanguage == true)
    }
}
