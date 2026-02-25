import Foundation

@MainActor
protocol InsertionStrategy {
    /// Called when the streaming session begins (engine is running, audio is flowing).
    /// Streaming strategy starts partial polling and insertion here; basic strategy only polls for UI.
    func sessionDidStart(
        engine: any TranscriptionEngine,
        insertionService: any TextInsertionService,
        shouldInsertRealtimePartials: Bool,
        isCurrentAppTerminal: Bool,
        onPartialText: @escaping (String) -> Void
    )

    /// Called at session end with the cleaned final transcript.
    func sessionDidEnd(
        finalText: String,
        insertionService: any TextInsertionService
    ) async -> InsertionResult

    /// Called when the session is cancelled. Cleans up any state.
    func sessionDidCancel()

    /// Whether any text was inserted into the target app during the live session.
    var hadRealtimeInsertions: Bool { get }
}
