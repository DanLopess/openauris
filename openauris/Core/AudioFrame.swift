import Foundation

struct AudioFrame: Sendable {
    let samples: [Float]
    let sampleRate: Double
    let timestamp: Date
}
