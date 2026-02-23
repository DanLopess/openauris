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
    @Published var partialText: String = ""
    @Published var level: Float = 0
    @Published var mode: DictationMode = .holdToSpeak

    var isVisible: Bool {
        if case .hidden = state {
            return false
        }
        return true
    }
}
