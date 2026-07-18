import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController {
    var onClick: (() -> Void)?

    private let statusItem: NSStatusItem
    private let engine: TimerEngine
    private let preferences: Preferences
    private var cancellables: Set<AnyCancellable> = []

    init(engine: TimerEngine, preferences: Preferences) {
        self.engine = engine
        self.preferences = preferences
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        configureButton()
        observeState()
        refresh()
    }

    var button: NSStatusBarButton? { statusItem.button }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageLeading
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else {
            onClick?()
            return
        }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            presentMenu()
        } else {
            onClick?()
        }
    }

    private func presentMenu() {
        let menu = NSMenu()

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Pomodoro", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func observeState() {
        let changes: [AnyPublisher<Void, Never>] = [
            engine.$phase.map { _ in () }.eraseToAnyPublisher(),
            engine.$runState.map { _ in () }.eraseToAnyPublisher(),
            engine.$remainingSeconds.map { _ in () }.eraseToAnyPublisher(),
            preferences.$showCountdownInMenuBar.map { _ in () }.eraseToAnyPublisher()
        ]

        Publishers.MergeMany(changes)
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.refresh() }
            .store(in: &cancellables)
    }

    private func refresh() {
        guard let button = statusItem.button else { return }

        button.image = Self.glyph(for: engine.phase)

        let showsCountdown = preferences.showCountdownInMenuBar && engine.runState != .idle
        button.attributedTitle = showsCountdown
            ? Self.countdownTitle(engine.remainingSeconds)
            : NSAttributedString(string: "")
    }

    private static func glyph(for phase: TimerPhase) -> NSImage? {
        let base = NSImage(systemSymbolName: symbolName(for: phase), accessibilityDescription: accessibilityLabel(for: phase))
        let weight = NSImage.SymbolConfiguration(pointSize: 15, weight: .bold, scale: .large)
        let color = NSImage.SymbolConfiguration(paletteColors: [tint(for: phase)])
        return base?.withSymbolConfiguration(weight.applying(color))
    }

    private static func symbolName(for phase: TimerPhase) -> String {
        switch phase {
        case .idle:
            return "timer"
        case .focus:
            return "brain.head.profile.fill"
        case .shortBreak:
            return "cup.and.saucer.fill"
        case .longBreak:
            return "figure.walk"
        }
    }

    private static func accessibilityLabel(for phase: TimerPhase) -> String {
        switch phase {
        case .idle:
            return "Pomodoro"
        case .focus:
            return "Focusing"
        case .shortBreak:
            return "Short break"
        case .longBreak:
            return "Long break"
        }
    }

    private static func tint(for phase: TimerPhase) -> NSColor {
        switch phase {
        case .idle:
            return .labelColor
        case .focus, .shortBreak, .longBreak:
            return NSColor(PomodoroColors.palette(for: phase).accent)
        }
    }

    private static func countdownTitle(_ seconds: Int) -> NSAttributedString {
        let clamped = max(0, seconds)
        let text = String(format: " %02d:%02d", clamped / 60, clamped % 60)
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        return NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: NSColor.labelColor]
        )
    }
}
