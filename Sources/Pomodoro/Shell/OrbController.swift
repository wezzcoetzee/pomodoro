import AppKit
import Combine
import SwiftUI

/// Owns the floating orb's panel: keeps it above every app and Space, sized to
/// its content and pinned to a screen corner, snaps it to the nearest corner
/// after a drag, and handles hiding it for a while from the right-click menu.
@MainActor
final class OrbController {
    private enum Metrics {
        static let screenInset: CGFloat = 20
        /// How often the idle escalation is re-evaluated. Running phases already
        /// redraw every second through the engine.
        static let clockInterval: TimeInterval = 15
    }

    var onOpenTimer: (() -> Void)?

    private let model: AppModel
    private let state: OrbViewState
    private let panel: FloatingPanel
    private var dragStart: (mouse: NSPoint, origin: NSPoint)?
    private var clock: Timer?
    private var cancellables: Set<AnyCancellable> = []

    init(model: AppModel) {
        self.model = model
        state = OrbViewState(corner: model.preferences.orbCorner)
        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 56, height: 56), borderless: true)
        panel.collectionBehavior.insert([.stationary, .ignoresCycle])
        // The window shadow follows the drawn alpha, so the orb and pill get a
        // real system shadow instead of a painted one.
        panel.isOpaque = false
        panel.isMovableByWindowBackground = false

        let root = OrbView(
            state: state,
            onOpenTimer: { [weak self] in self?.onOpenTimer?() },
            onDragChanged: { [weak self] in self?.dragChanged() },
            onDragEnded: { [weak self] in self?.dragEnded() }
        )
        .environmentObject(model)
        .fixedSize()

        let host = OrbHostingView(rootView: root)
        host.onHoverChanged = { [weak self] hovering in self?.state.isHovering = hovering }
        host.onRightClick = { [weak self] event, view in self?.presentMenu(for: event, in: view) }
        panel.contentView = host

        observe()
        startClock()
        refreshVisibility()
    }

    // MARK: Visibility

    private func observe() {
        model.preferences.$showsFloatingOrb
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshVisibility() }
            .store(in: &cancellables)

        // The hosting view resizes the panel to fit the orb and pill, keeping the
        // bottom-left origin; re-anchor so the orb stays tucked into its corner.
        NotificationCenter.default.publisher(for: NSWindow.didResizeNotification, object: panel)
            .sink { [weak self] _ in
                guard let self, self.dragStart == nil else { return }
                self.place(animated: false)
                self.panel.invalidateShadow()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.place(animated: false) }
            .store(in: &cancellables)

        // Time asleep is not time spent avoiding a block.
        let workspace = NSWorkspace.shared.notificationCenter
        Publishers.Merge(
            workspace.publisher(for: NSWorkspace.didWakeNotification),
            workspace.publisher(for: NSWorkspace.screensDidWakeNotification)
        )
        .sink { [weak self] _ in
            self?.model.resetAwaitingStart()
            self?.tick()
        }
        .store(in: &cancellables)
    }

    private func startClock() {
        let timer = Timer(timeInterval: Metrics.clockInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        clock = timer
    }

    private func tick() {
        state.now = Date()
        if let hiddenUntil = model.preferences.orbHiddenUntil, state.now >= hiddenUntil {
            model.preferences.orbHiddenUntil = nil
            refreshVisibility()
        }
    }

    private func refreshVisibility() {
        let hiddenUntil = model.preferences.orbHiddenUntil
        let shouldShow = model.preferences.showsFloatingOrb && (hiddenUntil.map { $0 <= Date() } ?? true)
        if shouldShow {
            state.now = Date()
            place(animated: false)
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    private func hide(until date: Date) {
        model.preferences.orbHiddenUntil = date
        refreshVisibility()
    }

    // MARK: Placement

    private var screen: NSScreen? { panel.screen ?? NSScreen.main ?? NSScreen.screens.first }

    private func place(animated: Bool) {
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let corner = state.corner
        let inset = Metrics.screenInset
        let origin = NSPoint(
            x: corner.isLeading ? visible.minX + inset : visible.maxX - inset - size.width,
            y: corner.isTop ? visible.maxY - inset - size.height : visible.minY + inset
        )
        guard origin != panel.frame.origin else { return }
        let animate = animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.setFrame(NSRect(origin: origin, size: size), display: true, animate: animate)
        panel.invalidateShadow()
    }

    private func dragChanged() {
        let mouse = NSEvent.mouseLocation
        guard let start = dragStart else {
            dragStart = (mouse, panel.frame.origin)
            return
        }
        panel.setFrameOrigin(NSPoint(x: start.origin.x + mouse.x - start.mouse.x, y: start.origin.y + mouse.y - start.mouse.y))
    }

    private func dragEnded() {
        dragStart = nil
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        let target = NSScreen.screens.first { $0.frame.contains(center) } ?? screen
        guard let visible = target?.visibleFrame else { return }

        let corner: OrbCorner =
            switch (center.x < visible.midX, center.y > visible.midY) {
            case (true, true): .topLeft
            case (false, true): .topRight
            case (true, false): .bottomLeft
            case (false, false): .bottomRight
            }
        state.corner = corner
        model.preferences.orbCorner = corner
        place(animated: true)
    }

    // MARK: Menu

    private func presentMenu(for event: NSEvent, in view: NSView) {
        let menu = NSMenu()
        menu.addItem(ClosureMenuItem(title: "Open timer") { [weak self] in self?.onOpenTimer?() })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: "Hide for an hour") { [weak self] in self?.hide(until: Date().addingTimeInterval(3600)) })
        menu.addItem(
            ClosureMenuItem(title: "Hide until tomorrow") { [weak self] in
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
                self?.hide(until: tomorrow ?? Date().addingTimeInterval(8 * 3600))
            })
        menu.addItem(ClosureMenuItem(title: "Turn off floating timer") { [weak self] in self?.model.preferences.showsFloatingOrb = false })
        menu.addItem(.separator())
        menu.addItem(
            ClosureMenuItem(title: "Settings…") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            })
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }
}

/// Hosting view that accepts the first click (the panel never activates the app),
/// tracks hover even while another app is frontmost, and routes right-clicks to
/// an AppKit menu.
private final class OrbHostingView<Content: View>: NSHostingView<Content> {
    var onHoverChanged: ((Bool) -> Void)?
    var onRightClick: ((NSEvent, NSView) -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.filter { $0.owner === self && $0.userInfo?["orb"] != nil }.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: ["orb": true]
            ))
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHoverChanged?(false)
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event, self)
    }
}

private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func fire() { handler() }
}
