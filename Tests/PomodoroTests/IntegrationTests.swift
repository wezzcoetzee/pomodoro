import XCTest
@testable import Pomodoro

@MainActor
private final class TestClock {
    var current: Date
    init(_ date: Date = Date(timeIntervalSince1970: 1_700_000_000)) { current = date }
    func now() -> Date { current }
    func advance(_ seconds: TimeInterval) { current = current.addingTimeInterval(seconds) }
}

@MainActor
final class IntegrationTests: XCTestCase {
    func testFocusBlockCompletesAndLandsInStore() throws {
        let clock = TestClock()
        let preset = CyclePreset(
            focusSeconds: 2,
            shortBreakSeconds: 1,
            longBreakSeconds: 3,
            blocksPerLongBreak: 4,
            autoAdvance: false
        )
        let engine = TimerEngine(preset: preset, clock: clock.now)
        let store = try SessionStore(inMemory: true, clock: clock.now)
        let preferences = Preferences(defaults: Self.ephemeralDefaults())
        let model = AppModel(engine: engine, store: store, preferences: preferences, clock: clock.now)

        var firedAlerts: [AlertKind] = []
        model.onAlert = { firedAlerts.append($0) }

        model.startSession(name: "Ship integration", ticket: nil)
        XCTAssertEqual(engine.phase, .focus)
        XCTAssertEqual(engine.runState, .running)

        clock.advance(2)
        engine.tick()

        XCTAssertEqual(engine.phase, .shortBreak)
        XCTAssertEqual(model.celebration?.blocksToday, 1)
        XCTAssertEqual(store.dailyCounts(lastNDays: 1).last?.count, 1)
        XCTAssertEqual(firedAlerts, [.focusEnded])

        let day = store.sessionsByDay().values.first?.first
        XCTAssertEqual(day?.name, "Ship integration")
        XCTAssertEqual(day?.completedBlocks, 1)
    }

    func testFocusBlockCompletionAfterSimulatedSleepIsAttributedToTheDayItStarted() throws {
        let clock = TestClock()
        let preset = CyclePreset(
            focusSeconds: 2,
            shortBreakSeconds: 1,
            longBreakSeconds: 3,
            blocksPerLongBreak: 4,
            autoAdvance: false
        )
        let engine = TimerEngine(preset: preset, clock: clock.now)
        let store = try SessionStore(inMemory: true, clock: clock.now)
        let preferences = Preferences(defaults: Self.ephemeralDefaults())
        let model = AppModel(engine: engine, store: store, preferences: preferences, clock: clock.now)

        model.startSession(name: "Overshoot", ticket: nil)

        clock.advance(86_400 + 90)
        engine.tick()

        XCTAssertEqual(engine.phase, .shortBreak)
        XCTAssertEqual(store.dailyCounts(lastNDays: 2).first?.count, 1)
        XCTAssertEqual(store.dailyCounts(lastNDays: 2).last?.count, 0)
    }

    func testAbandonUsesSharedClockForSessionEndTimestamp() throws {
        let clock = TestClock()
        let preset = CyclePreset(
            focusSeconds: 100,
            shortBreakSeconds: 5,
            longBreakSeconds: 10,
            blocksPerLongBreak: 4,
            autoAdvance: false
        )
        let engine = TimerEngine(preset: preset, clock: clock.now)
        let store = try SessionStore(inMemory: true, clock: clock.now)
        let preferences = Preferences(defaults: Self.ephemeralDefaults())
        let model = AppModel(engine: engine, store: store, preferences: preferences, clock: clock.now)

        model.startSession(name: "Abandon me", ticket: nil)
        clock.advance(37)
        engine.abandon()

        let session = try XCTUnwrap(store.sessionsByDay().values.first?.first)
        XCTAssertEqual(session.outcome, .abandoned)
        XCTAssertEqual(session.endedAt, clock.now())
    }

    private static func ephemeralDefaults() -> UserDefaults {
        let suite = "IntegrationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}

@MainActor
final class AlertMappingTests: XCTestCase {
    private func outcome(
        finished: TimerPhase,
        completed: Bool = true,
        didCompleteCycle: Bool = false,
        next: TimerPhase = .idle
    ) -> PhaseOutcome {
        PhaseOutcome(
            finishedPhase: finished,
            completed: completed,
            didCompleteCycle: didCompleteCycle,
            nextPhase: next,
            finishedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    func testOutcomeMapsToAlertKind() {
        let cases: [(PhaseOutcome, AlertKind?)] = [
            (outcome(finished: .focus, didCompleteCycle: false, next: .shortBreak), .focusEnded),
            (outcome(finished: .focus, didCompleteCycle: true, next: .longBreak), .cycleComplete),
            (outcome(finished: .shortBreak, next: .focus), .breakEnded),
            (outcome(finished: .longBreak, next: .focus), .breakEnded),
            (outcome(finished: .idle), nil),
            (outcome(finished: .focus, completed: false, next: .idle), .focusEnded),
        ]

        for (given, expected) in cases {
            XCTAssertEqual(
                AppModel.alertKind(for: given),
                expected,
                "outcome finishing \(given.finishedPhase) didCompleteCycle=\(given.didCompleteCycle)"
            )
        }
    }
}

extension AlertKind: Equatable {
    public static func == (lhs: AlertKind, rhs: AlertKind) -> Bool {
        switch (lhs, rhs) {
        case (.focusEnded, .focusEnded), (.breakEnded, .breakEnded), (.cycleComplete, .cycleComplete):
            return true
        default:
            return false
        }
    }
}
