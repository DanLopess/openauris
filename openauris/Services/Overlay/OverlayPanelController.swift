import AppKit
import SwiftUI

@MainActor
final class OverlayPanelController {
    private let viewModel: BubbleViewModel
    private var panel: NSPanel?

    init(viewModel: BubbleViewModel) {
        self.viewModel = viewModel
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel

        layout(panel)
        panel.orderFrontRegardless()
    }

    func hide() {
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
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 94),
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

        let hosting = NSHostingView(rootView: ListeningBubbleView(viewModel: viewModel))
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        panel.contentView = container
        panel.ignoresMouseEvents = true
        return panel
    }

    private func layout(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }

        let width: CGFloat = 420
        let height: CGFloat = 94
        let x = screen.visibleFrame.midX - width / 2
        let y = screen.visibleFrame.minY + 42

        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}
