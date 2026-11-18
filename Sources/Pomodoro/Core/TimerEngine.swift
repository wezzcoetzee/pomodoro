import Foundation

enum TimerPhase: String, Equatable {
    case idle
    case focus
    case shortBreak
    case longBreak
}

enum TimerRunState: Equatable {
    case idle
    case ready
    case running
    case paused
}

struct PhaseOutcome: Equatable {
    let finishedPhase: TimerPhase
    let completed: Bool
    let didCompleteCycle: Bool
    let nextPhase: TimerPhase
    let finishedAt: Date
}

@MainActor
final class TimerEngine: ObservableObject {
    @Published private(set) var phase: TimerPhase = .idle
    @Published private(set) var runState: TimerRunState = .idle
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var completedFocusBlocksInCycle: Int = 0

    private(set) var preset: CyclePreset

    var onPhaseFinished: ((PhaseOutcome) -> Void)?

    private let clock: () -> Date
    private var deadline: Date?
    private var remainingInterval: TimeInterval = 0

    init(preset: CyclePreset = .standard, clock: @escaping () -> Date = Date.init) {
        self.preset = preset
        self.clock = clock
    }

    func updatePreset(_ newPreset: CyclePreset) {
        preset = newPreset
        switch runState {
        case .idle:
            setRemaining(0)
        case .ready:
            setRemaining(TimeInterval(duration(for: phase)))
        case .running, .paused:
            break
        }
    }

    func start() {
        switch runState {
        case .idle:
            phase = .focus
            beginPhase(duration: TimeInterval(preset.focusSeconds))
        case .ready:
            beginPhase(duration: remainingInterval)
        case .running, .paused:
            break
        }
    }

    func pause() {
        guard runState == .running else { return }
        recomputeRemaining()
        deadline = nil
        runState = .paused
    }

    func resume() {
        guard runState == .paused else { return }
        deadline = clock().addingTimeInterval(remainingInterval)
        runState = .running
    }

    func skip() {
        switch runState {
        case .running, .paused:
            finishCurrentPhase(completed: true)
        case .ready:
            deadline = nil
            advanceToNextPhase(after: phase)
        case .idle:
            break
        }
    }

    func abandon() {
        guard runState != .idle else { return }
        let finishedPhase = phase
        phase = .idle
        runState = .idle
        deadline = nil
        setRemaining(0)
        completedFocusBlocksInCycle = 0
        onPhaseFinished?(
            PhaseOutcome(
                finishedPhase: finishedPhase,
                completed: false,
                didCompleteCycle: false,
                nextPhase: .idle,
                finishedAt: clock()
            ))
    }

    func tick() {
        guard runState == .running, let deadline else { return }
        let now = clock()
        if now >= deadline {
            finishCurrentPhase(completed: true)
        } else {
            setRemaining(deadline.timeIntervalSince(now))
        }
    }

    private func beginPhase(duration: TimeInterval) {
        setRemaining(duration)
        deadline = clock().addingTimeInterval(duration)
        runState = .running
    }

    private func recomputeRemaining() {
        guard let deadline else { return }
        setRemaining(max(0, deadline.timeIntervalSince(clock())))
    }

    private func setRemaining(_ interval: TimeInterval) {
        remainingInterval = interval
        remainingSeconds = Int(ceil(interval))
    }

    private func finishCurrentPhase(completed: Bool) {
        let finishedPhase = phase
        let finishedAt = clock()
        deadline = nil
        let didCompleteCycle = advanceToNextPhase(after: finishedPhase)
        onPhaseFinished?(
            PhaseOutcome(
                finishedPhase: finishedPhase,
                completed: completed,
                didCompleteCycle: didCompleteCycle,
                nextPhase: phase,
                finishedAt: finishedAt
            ))
    }

    @discardableResult
    private func advanceToNextPhase(after finishedPhase: TimerPhase) -> Bool {
        let nextPhase: TimerPhase
        var didCompleteCycle = false
        switch finishedPhase {
        case .focus:
            completedFocusBlocksInCycle += 1
            if completedFocusBlocksInCycle >= preset.blocksPerLongBreak {
                nextPhase = .longBreak
                completedFocusBlocksInCycle = 0
                didCompleteCycle = true
            } else {
                nextPhase = .shortBreak
            }
        case .shortBreak, .longBreak, .idle:
            nextPhase = .focus
        }

        phase = nextPhase
        let duration = TimeInterval(duration(for: nextPhase))
        setRemaining(duration)

        if preset.autoAdvance {
            deadline = clock().addingTimeInterval(duration)
            runState = .running
        } else {
            deadline = nil
            runState = .ready
        }

        return didCompleteCycle
    }

    private func duration(for phase: TimerPhase) -> Int {
        switch phase {
        case .idle: return 0
        case .focus: return preset.focusSeconds
        case .shortBreak: return preset.shortBreakSeconds
        case .longBreak: return preset.longBreakSeconds
        }
    }
}

#if DEBUG
    extension TimerEngine {
        /// Screenshot-mode hook: places the engine directly into a mid-phase state
        /// without waiting out real time.
        func debugConfigure(
            phase: TimerPhase,
            remainingSeconds: Int,
            runState: TimerRunState = .running,
            completedBlocksInCycle: Int = 0
        ) {
            self.phase = phase
            completedFocusBlocksInCycle = completedBlocksInCycle
            setRemaining(TimeInterval(remainingSeconds))
            deadline = runState == .running ? clock().addingTimeInterval(TimeInterval(remainingSeconds)) : nil
            self.runState = runState
        }
    }
#endif
