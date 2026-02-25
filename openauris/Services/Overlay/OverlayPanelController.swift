import AppKit
import SwiftUI

@MainActor
final class OverlayPanelController {
    private static var activePanel: NSPanel?

    private let viewModel: BubbleViewModel
    private var panel: NSPanel?
    private var effectView: NSVisualEffectView?

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
            contentRect: NSRect(x: 0, y: 0, width: 56, height: 56),
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

        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.isEmphasized = false
        effectView.wantsLayer = true
        effectView.layer?.backgroundColor = NSColor.clear.cgColor
        effectView.layer?.cornerRadius = 28
        effectView.layer?.masksToBounds = true

        let hosting = TransparentHostingView(rootView: ListeningBubbleView(viewModel: viewModel))
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: effectView.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: effectView.bottomAnchor)
        ])

        panel.contentView = effectView
        self.effectView = effectView
        panel.ignoresMouseEvents = false
        return panel
    }

    private func layout(_ panel: NSPanel) {
        guard let screen = panel.screen ?? NSScreen.main else { return }

        let width: CGFloat = panel.frame.size.width
        let height: CGFloat = panel.frame.size.height

        let x = screen.visibleFrame.midX - width / 2
        let y = screen.visibleFrame.minY + 16
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

#if DEBUG
    var debugPanelForTesting: NSPanel? { panel }
    var debugEffectViewForTesting: NSVisualEffectView? { effectView }
#endif
}

private final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }
}
