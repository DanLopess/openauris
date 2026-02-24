import Foundation
import Observation

enum BubbleState: Equatable {
    case hidden
    case preparing
    case listening
    case processing
    case success
    case error(String)

    var ringStyleToken: BubbleRingStyleToken {
        switch self {
        case .hidden:
            return .hidden
        case .preparing:
            return .preparing
        case .listening:
            return .listening
        case .processing:
            return .processing
        case .success:
            return .success
        case .error:
            return .error
        }
    }
}

enum BubbleRingStyleToken: Equatable {
    case hidden
    case preparing
    case listening
    case processing
    case success
    case error
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
