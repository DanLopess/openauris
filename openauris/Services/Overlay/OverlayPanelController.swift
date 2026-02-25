import AppKit
import SwiftUI

@MainActor
final class OverlayPanelController {
    private static var activePanel: NSPanel?

    private let viewModel: BubbleViewModel
    private var panel: NSPanel?

    private var customOrigin: CGPoint?
    private var dragStartOrigin: CGPoint?

    init(viewModel: BubbleViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel

        if let activePanel = Self.activePanel, activePanel !== panel, activePanel.isVisible {
            activePanel.orderOut(nil)
        }

        guard !panel.isVisible else {
            Self.activePanel = panel
            return
        }

        layout(panel)
        panel.orderFrontRegardless()
        Self.activePanel = panel
    }

    func hide() {
        if let panel, Self.activePanel === panel {
            Self.activePanel = nil
        }
        panel?.orderOut(nil)
    }

    func updateAndShow() {
        if viewModel.isVisible {
            show()
        } else {
            hide()
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 64, height: 64),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false

        let hosting = TransparentHostingView(rootView: ListeningBubbleView(viewModel: viewModel, onDrag: { [weak self] translation, ended in
            self?.handleDrag(translation: translation, ended: ended)
        }))
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let container = TransparentContainerView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        panel.contentView = container
        panel.ignoresMouseEvents = false
        return panel
    }

    private func handleDrag(translation: CGSize, ended: Bool) {
        guard let panel = panel else { return }
        if dragStartOrigin == nil {
            dragStartOrigin = panel.frame.origin
        }

        let start = dragStartOrigin ?? panel.frame.origin
        var newOrigin = CGPoint(x: start.x + translation.width, y: start.y - translation.height)

        let screen = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        let width = panel.frame.size.width
        let height = panel.frame.size.height
        if let screen {
            let minX = screen.minX
            let maxX = screen.maxX - width
            let minY = screen.minY
            let maxY = screen.maxY - height
            newOrigin.x = min(max(newOrigin.x, minX), maxX)
            newOrigin.y = min(max(newOrigin.y, minY), maxY)
        }

        panel.setFrameOrigin(newOrigin)

        if ended {
            customOrigin = newOrigin
            dragStartOrigin = nil
        }
    }

    private func layout(_ panel: NSPanel) {
        guard let screen = panel.screen ?? NSScreen.main else { return }

        let width: CGFloat = panel.frame.size.width
        let height: CGFloat = panel.frame.size.height

        if let origin = customOrigin {
            panel.setFrame(NSRect(origin: origin, size: CGSize(width: width, height: height)), display: true)
            return
        }

        let x = screen.visibleFrame.midX - width / 2
        let y = screen.visibleFrame.minY + 16
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    func resetPositionForNewSession() {
        customOrigin = nil
        dragStartOrigin = nil
    }

#if DEBUG
    var debugPanelForTesting: NSPanel? { panel }
#endif
}

private final class TransparentContainerView: NSView {
    override var isOpaque: Bool { false }
}

private final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }
}
