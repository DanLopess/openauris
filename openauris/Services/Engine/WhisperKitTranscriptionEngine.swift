import Foundation
import WhisperKit

enum WhisperKitConfiguration {
    nonisolated static func normalizedModelFolderPath(_ modelFolderPath: String?) -> String? {
        guard let raw = modelFolderPath?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return (raw as NSString).standardizingPath
    }

    nonisolated static func downloadFlag(modelFolderPath: String?) -> Bool {
        normalizedModelFolderPath(modelFolderPath) == nil
    }

    nonisolated static func normalizedLanguageOverride(_ languageOverride: String?) -> String? {
        guard let raw = languageOverride?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }

        let normalized = raw.lowercased()
        return normalized == "auto" ? nil : normalized
    }

    nonisolated static func decodingOptions(languageOverride: String?) -> DecodingOptions {
        let normalized = normalizedLanguageOverride(languageOverride)
        return DecodingOptions(
            language: normalized,
            detectLanguage: normalized == nil
        )
    }
}

actor WhisperKitTranscriptionEngine: TranscriptionEngine {
    private var whisperKit: WhisperKit?

    private var currentModelID: String = "small"
    private var currentModelFolderPath: String?
    private var currentLanguageOverride: String?
    private var bufferedSamples: [Float] = []
    private var sourceSampleRate: Double = 16_000
    private var partialText = ""
    private var startedAt: Date?
    private var partialDecodeTask: Task<Void, Never>?
    private var partialDecodeInFlight = false
    private var transcriptionInFlight = false
    private var lastPartialDecodeAt: Date = .distantPast
    private var streamingSessionID = UUID()

    private let partialDecodeMinInterval: TimeInterval = 0.6
    private let minimumPartialDecodeSamples = 8_000
    private let maxPartialDecodeWindowSamples = 8 * 16_000

    func prepare(modelID: String, modelFolderPath: String?, languageOverride: String?) async throws {
        let normalizedFolderPath = WhisperKitConfiguration.normalizedModelFolderPath(modelFolderPath)
        let normalizedLanguageOverride = WhisperKitConfiguration.normalizedLanguageOverride(languageOverride)
        let shouldRecreateEngine =
            whisperKit == nil ||
            currentModelID != modelID ||
            currentModelFolderPath != normalizedFolderPath

        currentModelID = modelID
        currentModelFolderPath = normalizedFolderPath
        currentLanguageOverride = normalizedLanguageOverride

        guard shouldRecreateEngine else { return }

        whisperKit = try await WhisperKit(
            model: modelID,
            modelFolder: normalizedFolderPath,
            verbose: false,
            prewarm: true,
            load: true,
            download: WhisperKitConfiguration.downloadFlag(modelFolderPath: normalizedFolderPath)
        )
    }

    func startStreaming() async throws {
        bufferedSamples = []
        sourceSampleRate = 16_000
        partialText = ""
        startedAt = Date()
        streamingSessionID = UUID()
        partialDecodeTask?.cancel()
        partialDecodeTask = nil
        partialDecodeInFlight = false
        lastPartialDecodeAt = .distantPast
    }

    func appendAudioFrame(_ frame: AudioFrame) async {
        if bufferedSamples.isEmpty {
            sourceSampleRate = frame.sampleRate
        }

        bufferedSamples.append(contentsOf: frame.samples)

        let elapsed = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        let rounded = elapsed.formatted(.number.precision(.fractionLength(1)))
        if partialText.isEmpty || partialText.hasPrefix("Listening…") {
            partialText = "Listening… \(rounded)s"
        }

        schedulePartialDecodeIfNeeded()
    }

    func currentPartialText() async -> String {
        partialText
    }

    func finishStreaming() async throws -> FinalTranscript {
        streamingSessionID = UUID()
        partialDecodeTask?.cancel()
        partialDecodeTask = nil
        partialDecodeInFlight = false

        let start = startedAt ?? Date()
        let duration = Date().timeIntervalSince(start)
        startedAt = nil

        let audio = resampleIfNeeded(bufferedSamples, from: sourceSampleRate, to: 16_000)
        let decodeOptions = WhisperKitConfiguration.decodingOptions(languageOverride: currentLanguageOverride)

        await waitForTranscriptionSlot()
        transcriptionInFlight = true
        defer { transcriptionInFlight = false }

        let engine = try await resolveEngine()
        let results = try await engine.transcribe(audioArray: audio, decodeOptions: decodeOptions)
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
    }

    func cancelStreaming() async {
        streamingSessionID = UUID()
        partialDecodeTask?.cancel()
        partialDecodeTask = nil
        partialDecodeInFlight = false
        bufferedSamples = []
        partialText = ""
        startedAt = nil
    }

    private func schedulePartialDecodeIfNeeded() {
        guard !partialDecodeInFlight else { return }
        guard bufferedSamples.count >= minimumPartialDecodeSamples else { return }

        let now = Date()
        guard now.timeIntervalSince(lastPartialDecodeAt) >= partialDecodeMinInterval else { return }
        lastPartialDecodeAt = now
        partialDecodeInFlight = true

        let sessionID = streamingSessionID
        var snapshot = resampleIfNeeded(bufferedSamples, from: sourceSampleRate, to: 16_000)
        if snapshot.count > maxPartialDecodeWindowSamples {
            snapshot = Array(snapshot.suffix(maxPartialDecodeWindowSamples))
        }

        partialDecodeTask = Task { [weak self] in
            guard let self else { return }
            await self.decodePartialText(from: snapshot, sessionID: sessionID)
        }
    }

    private func decodePartialText(from audio: [Float], sessionID: UUID) async {
        defer { partialDecodeInFlight = false }
        guard sessionID == streamingSessionID else { return }

        do {
            await waitForTranscriptionSlot()
            guard sessionID == streamingSessionID else { return }
            transcriptionInFlight = true
            defer { transcriptionInFlight = false }

            let engine = try await resolveEngine()
            var latestProgressText = ""
            let decodeOptions = WhisperKitConfiguration.decodingOptions(languageOverride: currentLanguageOverride)
            let results: [TranscriptionResult] = try await engine.transcribe(
                audioArray: audio,
                decodeOptions: decodeOptions,
                callback: { progress in
                latestProgressText = progress.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return nil
            })
            guard sessionID == streamingSessionID else { return }

            let finalizedText = results
                .map(\.text)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let text = finalizedText.isEmpty ? latestProgressText : finalizedText
            if !text.isEmpty {
                partialText = text
            }
        } catch {
            // Keep the previous partial text and continue streaming.
        }
    }

    private func waitForTranscriptionSlot() async {
        while transcriptionInFlight {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func resampleIfNeeded(_ samples: [Float], from sourceRate: Double, to targetRate: Double) -> [Float] {
        guard !samples.isEmpty else { return [] }
        guard abs(sourceRate - targetRate) > .ulpOfOne else { return samples }

        let ratio = sourceRate / targetRate
        let outputCount = max(1, Int(Double(samples.count) / ratio))
        var output = [Float](repeating: 0, count: outputCount)
        let lastIndex = samples.count - 1

        for index in 0..<outputCount {
            let sourcePosition = Double(index) * ratio
            let lowerIndex = min(lastIndex, Int(sourcePosition))
            let upperIndex = min(lastIndex, lowerIndex + 1)

            if lowerIndex == upperIndex {
                output[index] = samples[lowerIndex]
                continue
            }

            let fractional = Float(sourcePosition - Double(lowerIndex))
            let lower = samples[lowerIndex]
            let upper = samples[upperIndex]
            output[index] = lower + (upper - lower) * fractional
        }

        return output
    }

    private func resolveEngine() async throws -> WhisperKit {
        if let whisperKit {
            return whisperKit
        }

        let created = try await WhisperKit(
            model: currentModelID,
            modelFolder: currentModelFolderPath,
            verbose: false,
            prewarm: true,
            load: true,
            download: WhisperKitConfiguration.downloadFlag(modelFolderPath: currentModelFolderPath)
        )
        whisperKit = created
        return created
    }
}
