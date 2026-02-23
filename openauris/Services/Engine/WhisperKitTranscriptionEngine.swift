import Foundation

#if canImport(WhisperKit)
import WhisperKit
#endif

actor WhisperKitTranscriptionEngine: TranscriptionEngine {
    #if canImport(WhisperKit)
    private var whisperKit: WhisperKit?
    #endif

    private var currentModelID: String = "small"
    private var bufferedSamples: [Float] = []
    private var sourceSampleRate: Double = 16_000
    private var partialText = ""
    private var startedAt: Date?

    func prepare(modelID: String) async throws {
        currentModelID = modelID

        #if canImport(WhisperKit)
        if whisperKit == nil {
            whisperKit = try await WhisperKit(
                model: modelID,
                verbose: false,
                prewarm: true,
                load: true,
                download: true
            )
        }
        #endif
    }

    func startStreaming() async throws {
        bufferedSamples = []
        sourceSampleRate = 16_000
        partialText = ""
        startedAt = Date()
    }

    func appendAudioFrame(_ frame: AudioFrame) async {
        if bufferedSamples.isEmpty {
            sourceSampleRate = frame.sampleRate
        }

        bufferedSamples.append(contentsOf: frame.samples)

        let elapsed = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        let rounded = String(format: "%.1f", elapsed)
        partialText = "Listening… \(rounded)s"
    }

    func currentPartialText() async -> String {
        partialText
    }

    func finishStreaming() async throws -> FinalTranscript {
        let start = startedAt ?? Date()
        let duration = Date().timeIntervalSince(start)
        startedAt = nil

        let audio = resampleIfNeeded(bufferedSamples, from: sourceSampleRate, to: 16_000)

        #if canImport(WhisperKit)
        let engine = try await resolveEngine()
        let results = try await engine.transcribe(audioArray: audio)
        let text = results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let language = results.first?.language ?? "auto"
        let wordCount = text.openAurisWordCount

        return FinalTranscript(
            text: text,
            languageCode: language,
            confidence: nil,
            wordCount: wordCount,
            durationSeconds: duration
        )
        #else
        let demoText = "[Demo Mode] Captured \(Int(duration.rounded()))s of audio. Add WhisperKit dependency to enable transcription."
        return FinalTranscript(
            text: demoText,
            languageCode: "auto",
            confidence: nil,
            wordCount: demoText.openAurisWordCount,
            durationSeconds: duration
        )
        #endif
    }

    func cancelStreaming() async {
        bufferedSamples = []
        partialText = ""
        startedAt = nil
    }

    private func resampleIfNeeded(_ samples: [Float], from sourceRate: Double, to targetRate: Double) -> [Float] {
        guard !samples.isEmpty else { return [] }
        guard abs(sourceRate - targetRate) > .ulpOfOne else { return samples }

        let ratio = sourceRate / targetRate
        let outputCount = max(1, Int(Double(samples.count) / ratio))
        var output = [Float](repeating: 0, count: outputCount)

        for index in 0..<outputCount {
            let sourceIndex = min(samples.count - 1, Int(Double(index) * ratio))
            output[index] = samples[sourceIndex]
        }

        return output
    }

    #if canImport(WhisperKit)
    private func resolveEngine() async throws -> WhisperKit {
        if let whisperKit {
            return whisperKit
        }

        let created = try await WhisperKit(
            model: currentModelID,
            verbose: false,
            prewarm: true,
            load: true,
            download: true
        )
        whisperKit = created
        return created
    }
    #endif
}
