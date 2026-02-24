import Foundation

enum DictationFinalizationError: LocalizedError, Equatable {
    case noSpeechDetected
    case insertionFailed(String)

    var errorDescription: String? {
        switch self {
        case .noSpeechDetected:
            return "No speech detected."
        case .insertionFailed(let reason):
            return reason
        }
    }
}

enum DictationFinalization {
    static func cleanedFinalText(from raw: String) throws -> String {
        let cleaned = sanitizeTranscriptText(raw)
        guard !cleaned.isEmpty else {
            throw DictationFinalizationError.noSpeechDetected
        }
        return cleaned
    }

    static func assertInsertionSucceeded(_ result: InsertionResult) throws {
        if case .failed(let reason) = result {
            throw DictationFinalizationError.insertionFailed(reason)
        }
    }

    static func insertionMethod(from result: InsertionResult, hadRealtimeInsertions: Bool) -> String {
        switch (result, hadRealtimeInsertions) {
        case (.insertedDirectly, true):
            return "accessibility_realtime"
        case (.insertedViaPasteFallback, true):
            return "paste_realtime"
        case (.insertedDirectly, false):
            return "accessibility_direct"
        case (.insertedViaPasteFallback, false):
            return "paste_fallback"
        case (.failed, _):
            return "failed"
        }
    }
}
