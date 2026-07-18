import Combine
import SwiftUI

struct CelebrationMoment: Equatable {
    let streak: Int
    let blocksToday: Int
}

/// View-facing composition of the engine, store, and preferences.
///
/// Surfaces observe this single object from the environment rather than reaching
/// into three separate dependencies. It owns transient UI state (the active
/// session's name and ticket, the pending celebration) while delegating timing
/// to `engine` and persistence to `store`.
@MainActor
final class AppModel: ObservableObject {
    let engine: TimerEngine
    let store: SessionStore
    let preferences: Preferences

    @Published private(set) var activeName: String = ""
    @Published private(set) var activeTicket: TicketRef?
    @Published private(set) var celebration: CelebrationMoment?

    var onAlert: ((AlertKind) -> Void)?
    var onPeonEvent: ((PeonEvent) -> Void)?
    var onRequestReplayOnboarding: (() -> Void)?
    var alertCenter: AlertCenter?

    private var activeSession: FocusSession?
    private var blockStartedAt: Date
    private var cancellables: Set<AnyCancellable> = []
    private let clock: () -> Date

    init(engine: TimerEngine, store: SessionStore? = nil, preferences: Preferences, clock: @escaping () -> Date = Date.init) {
        self.engine = engine
        self.store = store ?? AppModel.makeStore(clock: clock)
        self.preferences = preferences
        self.clock = clock
        self.blockStartedAt = clock()

        engine.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        self.store.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        engine.onPhaseFinished = { [weak self] outcome in
            self?.handlePhaseFinished(outcome)
        }
    }

    private static func makeStore(clock: @escaping () -> Date) -> SessionStore {
        if let store = try? SessionStore(clock: clock) { return store }
        return try! SessionStore(inMemory: true, clock: clock)
    }

    var phaseTotalSeconds: Int {
        switch engine.phase {
        case .idle, .focus: return engine.preset.focusSeconds
        case .shortBreak: return engine.preset.shortBreakSeconds
        case .longBreak: return engine.preset.longBreakSeconds
        }
    }

    var progress: Double {
        let total = phaseTotalSeconds
        guard total > 0 else { return 0 }
        let elapsed = Double(total - engine.remainingSeconds)
        return min(max(elapsed / Double(total), 0), 1)
    }

    var phaseLabel: String {
        switch engine.phase {
        case .idle: return "Ready"
        case .focus: return "Focus"
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }

    var showsSetup: Bool {
        engine.runState == .idle
    }

    func startSession(name: String, ticket: TicketRef?) {
        alertCenter?.requestAuthorizationIfNeeded()
        activeName = name
        activeTicket = ticket
        blockStartedAt = clock()
        activeSession = store.beginSession(
            name: name,
            ticketRaw: ticket?.raw ?? "",
            ticketKind: ticket?.kind ?? .none,
            plannedSeconds: engine.preset.focusSeconds
        )
        engine.start()
        onPeonEvent?(.sessionStarted)
    }

    private func handlePhaseFinished(_ outcome: PhaseOutcome) {
        let now = outcome.finishedAt
        let phase = outcome.finishedPhase
        let completed = outcome.completed

        if phase == .focus, let session = activeSession {
            store.recordBlock(
                phase: .focus,
                startedAt: blockStartedAt,
                endedAt: now,
                wasCompleted: completed,
                in: session
            )
        }
        blockStartedAt = now

        if completed, let alert = Self.alertKind(for: outcome) {
            onAlert?(alert)
        }

        if phase == .focus && completed {
            notifyFocusCompleted()
        }

        if !completed {
            endActiveSession(outcome: .abandoned, at: now)
            onPeonEvent?(.abandoned)
        }
    }

    private func endActiveSession(outcome: SessionOutcome, at moment: Date) {
        if let session = activeSession {
            store.endSession(session, outcome: outcome, endedAt: moment)
        }
        activeSession = nil
        activeName = ""
        activeTicket = nil
    }

    static func alertKind(for outcome: PhaseOutcome) -> AlertKind? {
        switch outcome.finishedPhase {
        case .focus:
            return outcome.didCompleteCycle ? .cycleComplete : .focusEnded
        case .shortBreak, .longBreak:
            return .breakEnded
        case .idle:
            return nil
        }
    }

    func togglePauseResume() {
        switch engine.runState {
        case .idle, .ready:
            engine.start()
        case .running:
            engine.pause()
            onPeonEvent?(.paused)
        case .paused:
            engine.resume()
        }
    }

    func skip() {
        engine.skip()
    }

    func notifyFocusCompleted() {
        celebration = CelebrationMoment(
            streak: store.currentStreak(),
            blocksToday: store.dailyCounts(lastNDays: 1).last?.count ?? 0
        )
    }

    func dismissCelebration() {
        celebration = nil
    }

    func openTicket(_ ticket: TicketRef) {
        guard let url = ticket.deepLink else { return }
        NSWorkspace.shared.open(url)
    }
}
