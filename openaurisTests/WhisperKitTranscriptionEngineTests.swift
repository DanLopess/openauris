import Testing
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
}
