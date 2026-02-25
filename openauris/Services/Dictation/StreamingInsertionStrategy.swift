import Foundation

@MainActor
final class StreamingInsertionStrategy: InsertionStrategy {
    private var partialTask: Task<Void, Never>?

    private var lastInsertedText: String = ""
    private var insertedCharCount: Int = 0
    private var isInsertingPartial = false
    private var lastPartialInsertAt: Date = .distantPast
    private let minInsertInterval: TimeInterval = 0.8

    private var shouldInsertRealtimePartials = false
    private var isCurrentAppTerminal = false
    private var activeInsertionService: (any TextInsertionService)?

    var hadRealtimeInsertions: Bool { insertedCharCount > 0 }

    func sessionDidStart(
        engine: any TranscriptionEngine,
        insertionService: any TextInsertionService,
        shouldInsertRealtimePartials: Bool,
        isCurrentAppTerminal: Bool,
        onPartialText: @escaping (String) -> Void
    ) {
        resetInsertionState()
        self.shouldInsertRealtimePartials = shouldInsertRealtimePartials
        self.isCurrentAppTerminal = isCurrentAppTerminal
        self.activeInsertionService = insertionService

        partialTask?.cancel()
        partialTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let latest = await engine.currentPartialText()
                let sanitized = sanitizeTranscriptText(latest)
                onPartialText(sanitized)

                guard !sanitized.isEmpty,
                      !sanitized.hasPrefix("Listening\u{2026}"),
                      self.shouldInsertRealtimePartials,
                      !self.isCurrentAppTerminal,
                      sanitized != self.lastInsertedText,
                      !self.isInsertingPartial,
                      Date().timeIntervalSince(self.lastPartialInsertAt) >= self.minInsertInterval
                else {
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    continue
                }

                self.isInsertingPartial = true
                await self.insertPartialText(sanitized)
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

        if insertedCharCount > 0 {
            for _ in 0..<insertedCharCount {
                await insertionService.pressBackspace()
            }
            insertedCharCount = 0
        }

        guard !finalText.isEmpty else {
            return .failed(reason: "Transcript is empty.")
        }

        return await insertionService.appendText(finalText)
    }

    func sessionDidCancel() {
        partialTask?.cancel()
        partialTask = nil
        resetInsertionState()
    }

    // MARK: - Private

    private func insertPartialText(_ newText: String) async {
        defer { isInsertingPartial = false }

        guard newText.lowercased().hasPrefix(lastInsertedText.lowercased()) else {
            return
        }

        let delta = String(newText.dropFirst(lastInsertedText.count))
        guard !delta.isEmpty, let service = activeInsertionService else { return }

        _ = await service.appendText(delta)
        lastInsertedText = newText
        insertedCharCount += delta.count
        lastPartialInsertAt = Date()
    }

    private func resetInsertionState() {
        lastInsertedText = ""
        insertedCharCount = 0
        isInsertingPartial = false
        lastPartialInsertAt = .distantPast
    }
}
