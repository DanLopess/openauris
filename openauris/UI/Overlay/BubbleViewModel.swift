import Combine
import Foundation

enum BubbleState: Equatable {
    case hidden
    case listening
    case processing
    case success
    case error(String)
}

@MainActor
final class BubbleViewModel: ObservableObject {
    @Published var state: BubbleState = .hidden
    @Published var level: Float = 0

    var isVisible: Bool {
        state != .hidden
    }
}
