import XCTest

@testable import Pomodoro

@MainActor
final class OrbPresenceTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func presence(_ runState: TimerRunState, idleMinutes: Double) -> OrbPresence {
        OrbPresence.resolve(runState: runState, awaitingStartSince: start, now: start.addingTimeInterval(idleMinutes * 60))
    }

    func testEscalatesAtTwentyAndFortyFiveMinutesIdle() {
        XCTAssertEqual(presence(.idle, idleMinutes: 19.9), .quiet)
        XCTAssertEqual(presence(.idle, idleMinutes: 20), .nudge)
        XCTAssertEqual(presence(.idle, idleMinutes: 44.9), .nudge)
        XCTAssertEqual(presence(.idle, idleMinutes: 52), .urge(idleMinutes: 52))
    }

    func testPhaseWaitingToStartEscalatesLikeIdle() {
        XCTAssertEqual(presence(.ready, idleMinutes: 30), .nudge)
    }

    func testRunningOrPausedIsAlwaysActive() {
        XCTAssertEqual(presence(.running, idleMinutes: 90), .active)
        XCTAssertEqual(presence(.paused, idleMinutes: 90), .active)
    }

    func testQuickStartBeginsSessionAndIdleClockRestartsWhenBlockEnds() throws {
        var now = start
        let preset = CyclePreset(focusSeconds: 60, shortBreakSeconds: 30, longBreakSeconds: 90, blocksPerLongBreak: 4, autoAdvance: false)
        let engine = TimerEngine(preset: preset, clock: { now })
        let store = try SessionStore(inMemory: true, clock: { now })
        let defaults = UserDefaults(suiteName: "OrbPresenceTests.\(UUID().uuidString)")!
        let model = AppModel(engine: engine, store: store, preferences: Preferences(defaults: defaults), clock: { now })

        XCTAssertEqual(model.awaitingStartSince, start)

        model.quickStart()
        XCTAssertEqual(engine.phase, .focus)
        XCTAssertEqual(engine.runState, .running)
        XCTAssertNil(model.awaitingStartSince)

        now = now.addingTimeInterval(60)
        engine.tick()
        XCTAssertEqual(engine.runState, .ready)
        XCTAssertEqual(model.awaitingStartSince, now)
    }
}
