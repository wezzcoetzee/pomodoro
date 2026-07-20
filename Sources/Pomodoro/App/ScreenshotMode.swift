#if DEBUG
import AppKit
import SwiftUI

/// Drives the app into deterministic, presentable states for App Store
/// screenshots. Activated by launching with `-uiScreenshots -uiScreen <name>`;
/// uses an in-memory store seeded with demo data and presents the surface in a
/// regular window so `screencapture` can find it (popovers sit at a window
/// layer screenshot tooling cannot reach).
@MainActor
final class ScreenshotMode {
    static var isActive: Bool {
        CommandLine.arguments.contains("-uiScreenshots")
    }

    private let model: AppModel
    private var window: NSWindow?

    init(engine: TimerEngine, preferences: Preferences) {
        let store = Self.makeSeededStore()
        model = AppModel(engine: engine, store: store, preferences: preferences)
    }

    func present() {
        let screen = Self.requestedScreen
        configureState(for: screen)

        let root: AnyView
        let size: CGSize
        if screen == "onboarding" {
            root = AnyView(onboardingRoot)
            size = OnboardingView.windowSize
        } else {
            root = AnyView(
                SurfaceRootView(variant: .full, showHistory: screen == "history")
                    .environmentObject(model)
                    .frame(width: SurfaceMetrics.mainWidth, height: SurfaceMetrics.mainHeight)
                    .background(PomodoroColors.palette(for: model.engine.phase).canvas)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
            size = CGSize(width: SurfaceMetrics.mainWidth, height: SurfaceMetrics.mainHeight)
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.contentViewController = NSHostingController(rootView: root)
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)

        if screen == "celebration" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [model] in
                model.notifyFocusCompleted()
            }
        }

        if let out = Self.argumentValue("-uiScreenshotOut") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.writeCapture(to: out)
                NSApp.terminate(nil)
            }
        }
    }

    /// Renders the window's own content to PNG, so captures need no Screen
    /// Recording permission and never include other windows or the cursor.
    private func writeCapture(to path: String) {
        guard let view = window?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else { return }
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url)
    }

    private var onboardingRoot: some View {
        let steps: [String: OnboardingView.Step] = [
            "welcome": .welcome, "loop": .loop,
            "notifications": .notifications, "ready": .ready
        ]
        let step = Self.argumentValue("-uiOnboardingStep").flatMap { steps[$0] } ?? .welcome
        return OnboardingView(
            preferences: model.preferences,
            alertCenter: AlertCenter(preferences: model.preferences),
            onComplete: {},
            onSkip: {},
            initialStep: step
        )
    }

    private static func argumentValue(_ flag: String) -> String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    private static var requestedScreen: String {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "-uiScreen"), flag + 1 < args.count else {
            return "focus"
        }
        return args[flag + 1]
    }

    private func configureState(for screen: String) {
        switch screen {
        case "setup", "history":
            break
        case "break":
            model.startSession(name: "Fix flaky auth test", ticket: TicketRefParser.parse("IV-1287"))
            model.engine.debugConfigure(phase: .shortBreak, remainingSeconds: 3 * 60 + 47, completedBlocksInCycle: 2)
        case "celebration":
            model.startSession(name: "Ship sync engine fix", ticket: TicketRefParser.parse("IV-1287"))
            // The overlay auto-dismisses after 1.4s, so it is triggered from
            // present() shortly before the capture fires rather than here.
        default:
            model.startSession(name: "Fix flaky auth test", ticket: TicketRefParser.parse("IV-1287"))
            model.engine.debugConfigure(phase: .focus, remainingSeconds: 17 * 60 + 32, completedBlocksInCycle: 1)
        }
    }

    private static func makeSeededStore() -> SessionStore {
        let store = try! SessionStore(inMemory: true)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let days: [(offset: Int, sessions: [(name: String, ticket: String, blocks: Int)])] = [
            (0, [("Fix flaky auth test", "IV-1287", 2)]),
            (1, [("Refactor sync engine", "IV-1244", 4), ("Review release notes", "", 1)]),
            (2, [("Design review prep", "IV-1198", 3), ("Bug triage", "", 2)]),
            (3, [("Refactor sync engine", "IV-1244", 3)]),
            (4, [("Spike: widget support", "IV-1150", 2), ("Inbox zero", "", 1)]),
            (5, [("Write architecture doc", "", 4)]),
            (7, [("Onboarding flow polish", "IV-1102", 3)]),
            (8, [("Fix crash on resume", "IV-1096", 2)]),
        ]

        for day in days {
            guard let dayStart = calendar.date(byAdding: .day, value: -day.offset, to: today) else { continue }
            var blockStart = dayStart.addingTimeInterval(9 * 3600)
            for spec in day.sessions {
                let ticket = TicketRefParser.parse(spec.ticket)
                let session = store.beginSession(
                    name: spec.name,
                    ticketRaw: ticket?.raw ?? "",
                    ticketKind: ticket?.kind ?? .none,
                    plannedSeconds: 25 * 60,
                    startedAt: blockStart
                )
                for _ in 0..<spec.blocks {
                    let blockEnd = blockStart.addingTimeInterval(25 * 60)
                    store.recordBlock(
                        phase: .focus,
                        startedAt: blockStart,
                        endedAt: blockEnd,
                        wasCompleted: true,
                        in: session
                    )
                    blockStart = blockEnd.addingTimeInterval(5 * 60)
                }
                store.endSession(session, outcome: .completed, endedAt: blockStart)
                blockStart = blockStart.addingTimeInterval(30 * 60)
            }
        }
        return store
    }
}
#endif
