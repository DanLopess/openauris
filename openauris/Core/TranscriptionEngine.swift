import Foundation

struct FinalTranscript: Sendable {
    let text: String
    let languageCode: String
    let confidence: Double?
    let wordCount: Int
    let durationSeconds: Double
}

protocol TranscriptionEngine: Sendable {
    func prepare(modelID: String, modelFolderPath: String?, languageOverride: String?) async throws
    func startStreaming() async throws
    func appendAudioFrame(_ frame: AudioFrame) async
    func currentPartialText() async -> String
    func finishStreaming() async throws -> FinalTranscript
    func cancelStreaming() async
}

@MainActor
protocol TextInsertionService {
    func insert(_ text: String) async -> InsertionResult
    func appendText(_ text: String) async -> InsertionResult
    func focusedApplicationBundleID() -> String
    func pressBackspace() async
}

enum InsertionResult: Sendable {
    case insertedDirectly
    case insertedViaPasteFallback
    case failed(reason: String)
}
