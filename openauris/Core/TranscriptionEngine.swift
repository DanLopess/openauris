import Foundation

struct FinalTranscript: Sendable {
    let text: String
    let languageCode: String
    let confidence: Double?
    let wordCount: Int
    let durationSeconds: Double
}

protocol TranscriptionEngine: Sendable {
    func prepare(modelID: String) async throws
    func startStreaming() async throws
    func appendAudioFrame(_ frame: AudioFrame) async
    func currentPartialText() async -> String
    func finishStreaming() async throws -> FinalTranscript
    func cancelStreaming() async
}

protocol TextInsertionService: Sendable {
    func insert(_ text: String) async -> InsertionResult
}

enum InsertionResult: Sendable {
    case insertedDirectly
    case insertedViaPasteFallback
    case failed(reason: String)
}
