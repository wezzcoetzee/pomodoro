import AppKit
import SwiftUI

@MainActor
final class WelcomeWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let onSkip: () -> Void

    init(
        preferences: Preferences,
        alertCenter: AlertCenter,
        onComplete: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.onSkip = onSkip

        let palette = PomodoroColors.palette(for: .focus)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 560),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(palette.canvas)
        window.contentViewController = NSHostingController(
            rootView: OnboardingView(
                preferences: preferences,
                alertCenter: alertCenter,
                onComplete: onComplete,
                onSkip: onSkip
            )
        )
        self.window = window
        super.init()
        window.delegate = self
    }

    func present() {
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func dismiss() {
        window.close()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onSkip()
        return true
    }
}
