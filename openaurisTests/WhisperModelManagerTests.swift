import Foundation
import Testing
@testable import openauris

struct WhisperModelManagerTests {
    @Test
    func downloadBaseUsesAppSupportByDefault() {
        let base = WhisperModelManager.downloadBase(for: nil)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let basePath = base.path(percentEncoded: false).trimmingCharacters(in: ["/"])
        let expectedPath = appSupport.appending(path: "OpenAuris/Models").path(percentEncoded: false).trimmingCharacters(in: ["/"])
        #expect(basePath == expectedPath)
    }

    @Test
    func downloadBaseUsesCustomPathWhenSet() {
        let custom = "/tmp/my-models"
        let base = WhisperModelManager.downloadBase(for: custom)
        #expect(base.path(percentEncoded: false) == custom)
    }

    @Test
    func downloadBaseDoesNotContainDocuments() {
        let base = WhisperModelManager.downloadBase(for: nil)
        #expect(!base.path(percentEncoded: false).contains("Documents"))
    }
}
