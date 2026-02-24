import Foundation
import Observation

enum BubbleState: Equatable {
    case hidden
    case listening
    case processing
    case success
    case error(String)
}

@MainActor
@Observable
final class BubbleViewModel {
    var state: BubbleState = .hidden
    var level: Float = 0

    var isVisible: Bool {
        state != .hidden
    }
}
