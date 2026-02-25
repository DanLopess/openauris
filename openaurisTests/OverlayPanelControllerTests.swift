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
    }

    @Test
    func panelIsPositionedAtBottomCenter() {
        let viewModel = BubbleViewModel()
        viewModel.state = .listening

        let controller = OverlayPanelController(viewModel: viewModel)
        controller.updateAndShow()
        defer { controller.hide() }

        guard let panel = controller.debugPanelForTesting else {
            Issue.record("Expected panel to be created")
            return
        }

        guard let screen = panel.screen ?? NSScreen.main else {
            Issue.record("Expected screen for panel layout")
            return
        }

        let expectedX = screen.visibleFrame.midX - panel.frame.size.width / 2
        let expectedY = screen.visibleFrame.minY + 16
        #expect(panel.frame.origin.x == expectedX)
        #expect(panel.frame.origin.y == expectedY)
    }

    @Test
    func panelBubbleHostViewDoesNotForceLayerClipping() {
        let viewModel = BubbleViewModel()
        viewModel.state = .listening

        let controller = OverlayPanelController(viewModel: viewModel)
        controller.updateAndShow()
        defer { controller.hide() }

        guard let panel = controller.debugPanelForTesting else {
            Issue.record("Expected panel to be created")
            return
        }

        guard let contentView = panel.contentView else {
            Issue.record("Expected panel content view")
            return
        }

        guard let hostingView = contentView.subviews.first else {
            Issue.record("Expected hosting view as subview")
            return
        }

        let layer = hostingView.layer
        #expect(layer?.mask == nil)
        #expect(layer?.masksToBounds == false)
    }

    @Test
    func panelUsesLiveBackdropEffectViewForBubbleBackground() {
        let previousAppearance = NSApp.appearance
        NSApp.appearance = NSAppearance(named: .aqua)
        defer { NSApp.appearance = previousAppearance }

        let viewModel = BubbleViewModel()
        viewModel.state = .listening

        let controller = OverlayPanelController(viewModel: viewModel)
        controller.updateAndShow()
        defer { controller.hide() }

        guard let effectView = controller.debugEffectViewForTesting else {
            Issue.record("Expected a backdrop effect view for live glass rendering")
            return
        }

        #expect(effectView.blendingMode == .behindWindow)
        #expect(effectView.layer?.cornerRadius == 28)
        #expect(effectView.layer?.masksToBounds == true)
    }

    @Test
    func onlyOneOverlayPanelIsVisibleAcrossControllers() {
        let firstViewModel = BubbleViewModel()
        firstViewModel.state = .listening
        let secondViewModel = BubbleViewModel()
        secondViewModel.state = .listening
        let thirdViewModel = BubbleViewModel()
        thirdViewModel.state = .listening

        let firstController = OverlayPanelController(viewModel: firstViewModel)
        let secondController = OverlayPanelController(viewModel: secondViewModel)
        let thirdController = OverlayPanelController(viewModel: thirdViewModel)

        firstController.updateAndShow()
        secondController.updateAndShow()
        thirdController.updateAndShow()
        defer {
            firstController.hide()
            secondController.hide()
            thirdController.hide()
        }

        let panels = [
            firstController.debugPanelForTesting,
            secondController.debugPanelForTesting,
            thirdController.debugPanelForTesting
        ]
        .compactMap { $0 }

        #expect(panels.count == 3)
        #expect(panels.filter(\.isVisible).count == 1)
    }
}
