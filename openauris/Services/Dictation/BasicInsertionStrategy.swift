import Foundation

@MainActor
final class BasicInsertionStrategy: InsertionStrategy {
    private var partialTask: Task<Void, Never>?

    var hadRealtimeInsertions: Bool { false }

    func sessionDidStart(
        engine: any TranscriptionEngine,
        insertionService: any TextInsertionService,
        shouldInsertRealtimePartials: Bool,
        isCurrentAppTerminal: Bool,
        onPartialText: @escaping (String) -> Void
    ) {
        partialTask?.cancel()
        partialTask = Task { [weak self] in
            guard self != nil else { return }
            while !Task.isCancelled {
                let latest = await engine.currentPartialText()
                let sanitized = sanitizeTranscriptText(latest)
                onPartialText(sanitized)
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
    }

    func sessionDidEnd(
        finalText: String,
        insertionService: any TextInsertionService
    ) async -> InsertionResult {
        partialTask?.cancel()
        partialTask = nil

        guard !finalText.isEmpty else {
            return .failed(reason: "Transcript is empty.")
        }

        return await insertionService.appendText(finalText)
    }

    func sessionDidCancel() {
        partialTask?.cancel()
        partialTask = nil
    }
}
