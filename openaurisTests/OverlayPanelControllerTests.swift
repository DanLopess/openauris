import AppKit
import Testing
@testable import openauris

@MainActor
struct OverlayPanelControllerTests {
    @Test
    func panelSubviewsAreTransparent() {
        let viewModel = BubbleViewModel()
        viewModel.state = .listening

        let controller = OverlayPanelController(viewModel: viewModel)
        controller.updateAndShow()
        defer { controller.hide() }

        guard let panel = controller.debugPanelForTesting else {
            Issue.record("Expected panel to be created")
            return
        }

        #expect(panel.isOpaque == false)
        #expect(panel.backgroundColor == NSColor.clear)

        guard let contentView = panel.contentView else {
            Issue.record("Expected panel content view")
            return
        }

        #expect(contentView.isOpaque == false)

        guard let hostingView = contentView.subviews.first else {
            Issue.record("Expected hosting view as subview")
            return
        }

        #expect(hostingView.isOpaque == false)
    }

    @Test
    func visiblePanelDoesNotRelayoutOnRepeatedUpdates() {
        let viewModel = BubbleViewModel()
        viewModel.state = .listening

        let controller = OverlayPanelController(viewModel: viewModel)
        controller.updateAndShow()
        defer { controller.hide() }

        guard let panel = controller.debugPanelForTesting else {
            Issue.record("Expected panel to be created")
            return
        }

        let movedOrigin = CGPoint(x: panel.frame.origin.x + 37, y: panel.frame.origin.y + 23)
        panel.setFrameOrigin(movedOrigin)

        controller.updateAndShow()

        #expect(panel.frame.origin == movedOrigin)
    }
}
