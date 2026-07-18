import AppKit
import Combine
import SwiftUI

@MainActor
final class SurfaceController {
    private enum Metrics {
        static let mainSize = NSSize(width: SurfaceMetrics.mainWidth, height: SurfaceMetrics.mainHeight)
        static let miniSize = NSSize(width: SurfaceMetrics.miniWidth, height: SurfaceMetrics.miniHeight)
        static let gapBelowStatusItem: CGFloat = 6
    }

    private let model: AppModel
    private weak var statusButton: NSStatusBarButton?

    private var popover: NSPopover?
    private var pinnedPanel: FloatingPanel?
    private var miniCard: FloatingPanel?

    private var cancellables: Set<AnyCancellable> = []

    init(model: AppModel) {
        self.model = model
        observeModeChanges()
    }

    func attach(statusButton: NSStatusBarButton?) {
        self.statusButton = statusButton
    }

    func toggle() {
        switch model.preferences.surfaceMode {
        case .popover:
            togglePopover()
        case .pinnedPanel:
            togglePinnedPanel()
        case .miniCard:
            toggleMiniCard()
        }
    }

    func reveal() {
        switch model.preferences.surfaceMode {
        case .popover:
            if !(popover?.isShown ?? false) { togglePopover() }
        case .pinnedPanel:
            if !(pinnedPanel?.isVisible ?? false) { presentPinnedPanel() }
        case .miniCard:
            if !(miniCard?.isVisible ?? false) { presentMiniCard() }
        }
    }

    func pin() {
        model.preferences.surfaceMode = .pinnedPanel
        presentPinnedPanel()
    }

    func unpin() {
        model.preferences.surfaceMode = .popover
        closePinnedPanel()
    }

    private func observeModeChanges() {
        model.preferences.$surfaceMode
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] mode in self?.enforceExclusivity(for: mode) }
            .store(in: &cancellables)
    }

    private func enforceExclusivity(for mode: SurfaceMode) {
        switch mode {
        case .popover:
            closePinnedPanel()
            closeMiniCard()
        case .pinnedPanel:
            closePopover()
            closeMiniCard()
        case .miniCard:
            closePopover()
            closePinnedPanel()
        }
    }

    private func togglePopover() {
        let popover = self.popover ?? makePopover()
        self.popover = popover

        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusButton {
            closePinnedPanel()
            closeMiniCard()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        }
    }

    private func togglePinnedPanel() {
        if let panel = pinnedPanel, panel.isVisible {
            panel.orderOut(nil)
        } else {
            presentPinnedPanel()
        }
    }

    private func presentPinnedPanel() {
        closePopover()
        closeMiniCard()

        let panel = pinnedPanel ?? makePinnedPanel()
        pinnedPanel = panel
        panel.setFrame(frameBelowStatusItem(size: Metrics.mainSize), display: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func toggleMiniCard() {
        if let card = miniCard, card.isVisible {
            card.orderOut(nil)
        } else {
            presentMiniCard()
        }
    }

    private func presentMiniCard() {
        closePopover()
        closePinnedPanel()

        if let card = miniCard {
            card.makeKeyAndOrderFront(nil)
            return
        }

        let card = makeMiniCard()
        miniCard = card
        card.setFrame(frameBelowStatusItem(size: Metrics.miniSize), display: true)
        card.makeKeyAndOrderFront(nil)
    }

    private func makePopover() -> NSPopover {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = Metrics.mainSize
        popover.contentViewController = NSHostingController(rootView: surfaceView(.full))
        return popover
    }

    private func makePinnedPanel() -> FloatingPanel {
        let panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: Metrics.mainSize))
        panel.contentViewController = NSHostingController(rootView: surfaceView(.full))
        return panel
    }

    private func makeMiniCard() -> FloatingPanel {
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: Metrics.miniSize),
            borderless: true
        )
        let content = surfaceView(.compact)
            .frame(width: Metrics.miniSize.width, height: Metrics.miniSize.height)
        panel.contentViewController = NSHostingController(rootView: content)
        return panel
    }

    private func surfaceView(_ variant: TimerVariant) -> some View {
        SurfaceRootView(variant: variant)
            .environmentObject(model)
    }

    private func frameBelowStatusItem(size: NSSize) -> NSRect {
        guard let button = statusButton, let window = button.window else {
            return centeredFrame(size: size)
        }

        let buttonInScreen = window.convertToScreen(button.convert(button.bounds, to: nil))
        let x = buttonInScreen.midX - size.width / 2
        let y = buttonInScreen.minY - size.height - Metrics.gapBelowStatusItem
        return NSRect(x: x, y: y, width: size.width, height: size.height)
    }

    private func centeredFrame(size: NSSize) -> NSRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func closePopover() {
        popover?.performClose(nil)
    }

    private func closePinnedPanel() {
        pinnedPanel?.orderOut(nil)
    }

    private func closeMiniCard() {
        miniCard?.orderOut(nil)
    }
}
