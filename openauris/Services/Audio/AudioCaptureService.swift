import AVFoundation
import Foundation

@MainActor
final class AudioCaptureService {
    private let engine = AVAudioEngine()
    private var isRunning = false

    var onFrame: (@Sendable (AudioFrame) -> Void)?
    var onLevel: (@Sendable (Float) -> Void)?

    func start() throws {
        guard !isRunning else { return }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))

            let rms = self.computeRMS(samples: samples)
            self.onLevel?(rms)

            let frame = AudioFrame(
                samples: samples,
                sampleRate: format.sampleRate,
                timestamp: Date()
            )
            self.onFrame?(frame)
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        engine.reset()
        isRunning = false
    }

    private func computeRMS(samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let squares = samples.reduce(0) { $0 + ($1 * $1) }
        return sqrt(squares / Float(samples.count))
    }
}
