import AppKit

final class FloatingPanel: NSPanel {
    init(contentRect: NSRect, borderless: Bool = false) {
        let styleMask: NSWindow.StyleMask =
            borderless
            ? [.nonactivatingPanel, .borderless, .fullSizeContentView]
            : [.nonactivatingPanel, .titled, .fullSizeContentView]

        super.init(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        backgroundColor = .clear
        hasShadow = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
