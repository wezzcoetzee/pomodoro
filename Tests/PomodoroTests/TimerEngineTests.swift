import XCTest

@testable import Pomodoro

@MainActor
private final class ManualClock {
    var current: Date

    init(_ date: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        current = date
    }

    func now() -> Date { current }

    func advance(_ seconds: TimeInterval) {
        current = current.addingTimeInterval(seconds)
    }
}

@MainActor
final class TimerEngineTests: XCTestCase {

    private func makeEngine(
        preset: CyclePreset,
        clock: ManualClock
    ) -> TimerEngine {
        TimerEngine(preset: preset, clock: clock.now)
    }

    private func autoAdvancePreset(
        focus: Int = 5,
        short: Int = 2,
        long: Int = 4,
        blocksPerLongBreak: Int = 2
    ) -> CyclePreset {
        CyclePreset(
            focusSeconds: focus,
            shortBreakSeconds: short,
            longBreakSeconds: long,
            blocksPerLongBreak: blocksPerLongBreak,
            autoAdvance: true
        )
    }

    private func manualAdvancePreset(
        focus: Int = 5,
        short: Int = 2,
        long: Int = 4,
        blocksPerLongBreak: Int = 2
    ) -> CyclePreset {
        CyclePreset(
            focusSeconds: focus,
            shortBreakSeconds: short,
            longBreakSeconds: long,
            blocksPerLongBreak: blocksPerLongBreak,
            autoAdvance: false
        )
    }

    // MARK: - Initial state

    func testEngineStartsIdle() {
        let clock = ManualClock()
        let engine = makeEngine(preset: .standard, clock: clock)
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertEqual(engine.runState, .idle)
        XCTAssertEqual(engine.remainingSeconds, 0)
        XCTAssertEqual(engine.completedFocusBlocksInCycle, 0)
    }

    // MARK: - start()

    func testStartFromIdleBeginsFocusPhase() {
        let clock = ManualClock()
        let engine = makeEngine(preset: autoAdvancePreset(), clock: clock)

        engine.start()

        XCTAssertEqual(engine.phase, .focus)
        XCTAssertEqual(engine.runState, .running)
        XCTAssertEqual(engine.remainingSeconds, 5)
    }

    func testStartIsNoOpWhenAlreadyRunning() {
        let clock = ManualClock()
        let engine = makeEngine(preset: autoAdvancePreset(), clock: clock)
        engine.start()
        clock.advance(2)
        engine.tick()
        XCTAssertEqual(engine.remainingSeconds, 3)

        engine.start()

        XCTAssertEqual(engine.remainingSeconds, 3)
        XCTAssertEqual(engine.runState, .running)
    }

    // MARK: - Deadline-based tick / drift-free timing

    func testTickComputesRemainingFromWallClockNotAccumulation() {
        let clock = ManualClock()
        let engine = makeEngine(preset: autoAdvancePreset(focus: 100), clock: clock)
        engine.start()

        clock.advance(1)
        engine.tick()
        XCTAssertEqual(engine.remainingSeconds, 99)

        // Simulate a large, uneven jump (e.g. process suspension) rather than
        // many 1-second ticks: remaining must reflect the wall-clock gap exactly.
        clock.advance(40)
        engine.tick()
        XCTAssertEqual(engine.remainingSeconds, 59)
    }

    func testPhaseCompletesExactlyOnceWhenTickLandsPastDeadline() {
        let clock = ManualClock()
        let engine = makeEngine(preset: autoAdvancePreset(focus: 10, short: 3), clock: clock)
        var finishedEvents: [(TimerPhase, Bool)] = []
        engine.onPhaseFinished = { finishedEvents.append(($0.finishedPhase, $0.completed)) }

        engine.start()
        clock.advance(10)
        engine.tick()

        XCTAssertEqual(finishedEvents.count, 1)
        XCTAssertEqual(finishedEvents[0].0, .focus)
        XCTAssertTrue(finishedEvents[0].1)
        XCTAssertEqual(engine.phase, .shortBreak)

        // Further ticks before the new deadline must not re-fire completion.
        engine.tick()
        engine.tick()
        XCTAssertEqual(finishedEvents.count, 1)
    }

    func testTickPastDeadlineAfterSimulatedSleepCompletesPhaseOnce() {
        let clock = ManualClock()
        let engine = makeEngine(preset: autoAdvancePreset(focus: 10, short: 3), clock: clock)
        var finishedEvents: [(TimerPhase, Bool)] = []
        engine.onPhaseFinished = { finishedEvents.append(($0.finishedPhase, $0.completed)) }

        engine.start()
        // Simulate the Mac sleeping well past the deadline.
        clock.advance(500)
        engine.tick()

        XCTAssertEqual(finishedEvents.count, 1)
        XCTAssertEqual(engine.phase, .shortBreak)
        XCTAssertEqual(engine.remainingSeconds, 3)
    }

    func testTickBeforeDeadlineDoesNotComplete() {
        let clock = ManualClock()
        let engine = makeEngine(preset: autoAdvancePreset(focus: 10), clock: clock)
        var finishedCount = 0
        engine.onPhaseFinished = { _ in finishedCount += 1 }

        engine.start()
        clock.advance(9)
        engine.tick()

        XCTAssertEqual(finishedCount, 0)
        XCTAssertEqual(engine.phase, .focus)
        XCTAssertEqual(engine.remainingSeconds, 1)
    }

    func testTickWhileIdleIsNoOp() {
        let clock = ManualClock()
        let engine = makeEngine(preset: .standard, clock: clock)
        engine.tick()
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertEqual(engine.remainingSeconds, 0)
    }

    // MARK: - pause / resume

    func testPauseStoresRemainingAndClearsDeadline() {
        let clock = ManualClock()
        let engine = makeEngine(preset: autoAdvancePreset(focus: 10), clock: clock)
        engine.start()
        clock.advance(4)
        engine.tick()
        XCTAssertEqual(engine.remainingSeconds, 6)

        engine.pause()

        XCTAssertEqual(engine.runState, .paused)
        XCTAssertEqual(engine.remainingSeconds, 6)

        // Time passing while paused must not affect remaining or fire completion.
        clock.advance(100)
        engine.tick()
        XCTAssertEqual(engine.remainingSeconds, 6)
        XCTAssertEqual(engine.runState, .paused)
    }

    func testResumeRecomputesDeadlineFromRemaining() {
        let clock = ManualClock()
        let engine = makeEngine(preset: autoAdvancePreset(focus: 10), clock: clock)
        engine.start()
        clock.advance(4)
        engine.tick()
        engine.pause()

        clock.advance(50)
        engine.resume()

        XCTAssertEqual(engine.runState, .running)
        XCTAssertEqual(engine.remainingSeconds, 6)

        clock.advance(6)
        var finished = false
        engine.onPhaseFinished = { finished = $0.completed }
        engine.tick()

        XCTAssertTrue(finished)
    }

    func testPauseIsNoOpWhenNotRunning() {
        let clock = ManualClock()
        let engine = makeEngine(preset: .standard, clock: clock)
        engine.pause()
        XCTAssertEqual(engine.runState, .idle)
    }

    func testResumeIsNoOpWhenNotPaused() {
        let clock = ManualClock()
        let engine = makeEngine(preset: autoAdvancePreset(), clock: clock)
        engine.start()
        let remainingBefore = engine.remainingSeconds
        engine.resume()
        XCTAssertEqual(engine.runState, .running)
        XCTAssertEqual(engine.remainingSeconds, remainingBefore)
    }

    func testPauseResumeCyclesAtFractionalOffsetsAccumulateNoExtraTime() {
        let clock = ManualClock()
        let engine = makeEngine(preset: autoAdvancePreset(focus: 100), clock: clock)
        engine.start()

        clock.advance(0.3)
        engine.pause()
        clock.advance(10)
        engine.resume()

        clock.advance(0.3)
        engine.pause()
        clock.advance(10)
        engine.resume()

        clock.advance(0.3)
        engine.pause()
        clock.advance(10)
        engine.resume()

        // 3 running spans of 0.3s each have elapsed so far (0.9s total); the
        // remaining 100s budget is exactly 99.1s of running time. If pause/resume
        // had leaked rounding error, this final span would finish early.
        clock.advance(99.05)
        var finished = false
        engine.onPhaseFinished = { finished = $0.completed }
        engine.tick()

        XCTAssertFalse(finished)

        clock.advance(0.1)
        engine.tick()
        XCTAssertTrue(finished)
    }

    // MARK: - skip

    func testSkipEndsCurrentRunningPhaseImmediately() {
        let clock = ManualClock()
        let engine = makeEngine(preset: autoAdvancePreset(focus: 100, short: 3), clock: clock)
        var finishedEvents: [(TimerPhase, Bool)] = []
        engine.onPhaseFinished = { finishedEvents.append(($0.finishedPhase, $0.completed)) }

        engine.start()
        clock.advance(1)
        engine.skip()

        XCTAssertEqual(finishedEvents.count, 1)
        XCTAssertEqual(finishedEvents[0].0, .focus)
        XCTAssertTrue(finishedEvents[0].1)
        XCTAssertEqual(engine.phase, .shortBreak)
    }

    func testSkipEndsPausedPhase() {
        let clock = ManualClock()
        let engine = makeEngine(preset: autoAdvancePreset(focus: 10, short: 3), clock: clock)
        engine.start()
        engine.pause()

        engine.skip()

        XCTAssertEqual(engine.phase, .shortBreak)
    }

    func testSkipFromReadyStateAdvancesToNextPhase() {
        let clock = ManualClock()
        let engine = makeEngine(preset: manualAdvancePreset(focus: 5, short: 2), clock: clock)
        engine.start()
        clock.advance(5)
        engine.tick()
        XCTAssertEqual(engine.runState, .ready)
        XCTAssertEqual(engine.phase, .shortBreak)

        engine.skip()

        XCTAssertEqual(engine.phase, .focus)
        XCTAssertEqual(engine.runState, .ready)
    }

    func testSkipFromReadyDoesNotReportUnstartedPhaseAsCompleted() {
        let clock = ManualClock()
        let engine = makeEngine(preset: manualAdvancePreset(focus: 5, short: 2, blocksPerLongBreak: 4), clock: clock)
        engine.start()
        clock.advance(5)
        engine.tick()
        XCTAssertEqual(engine.phase, .shortBreak)

        engine.start()
        clock.advance(2)
        engine.tick()
        XCTAssertEqual(engine.phase, .focus)
        XCTAssertEqual(engine.runState, .ready)

        var finishedEvents: [(TimerPhase, Bool)] = []
        engine.onPhaseFinished = { finishedEvents.append(($0.finishedPhase, $0.completed)) }
        engine.skip()

        XCTAssertTrue(finishedEvents.isEmpty)
        XCTAssertEqual(engine.phase, .shortBreak)
    }

    func testSkipIsNoOpWhenIdle() {
        let clock = ManualClock()
        let engine = makeEngine(preset: .standard, clock: clock)
        engine.skip()
        XCTAssertEqual(engine.phase, .idle)
        XCTAssertEqual(engine.runState, .idle)
    }

    // MARK: - updatePreset

    func testUpdatePresetWhileReadyRefreshesPendingPhaseDuration() {
        let clock = ManualClock()
        let engine = makeEngine(preset: manualAdvancePreset(focus: 5, short: 2), clock: clock)
        engine.start()
        clock.advance(5)
        engine.tick()
        XCTAssertEqual(engine.runState, .ready)
        XCTAssertEqual(engine.phase, .shortBreak)
        XCTAssertEqual(engine.remainingSeconds, 2)

        engine.updatePreset(manualAdvancePreset(focus: 5, short: 30))

        XCTAssertEqual(engine.runState, .ready)
        XCTAssertEqual(engine.remainingSeconds, 30)

        engine.start()
        XCTAssertEqual(engine.remainingSeconds, 30)
    }

    func testUpdatePresetWhileRunningDoesNotDisturbCurrentPhase() {
        let clock = ManualClock()
        let engine = makeEngine(preset: autoAdvancePreset(focus: 100), clock: clock)
        engine.start()
        clock.advance(10)
        engine.tick()
        XCTAssertEqual(engine.remainingSeconds, 90)

        engine.updatePreset(autoAdvancePreset(focus: 5))

        XCTAssertEqual(engine.remainingSeconds, 90)
        XCTAssertEqual(engine.runState, .running)
    }

    func testUpdatePresetWhilePausedDoesNotDisturbCurrentPhase() {
        let clock = ManualClock()
        let engine = makeEngine(preset: autoAdvancePreset(focus: 100), clock: clock)
        engine.start()
        clock.advance(10)
        engine.tick()
        engine.pause()

        engine.updatePreset(autoAdvancePreset(focus: 5))

        XCTAssertEqual(engine.remainingSeconds, 90)
        XCTAssertEqual(engine.runState, .paused)
    }

    // MARK: - autoAdvance = false (ready state)

    func testAutoAdvanceFalseEntersReadyStateInsteadOfRunning() {
        let clock = ManualClock()
        let engine = makeEngine(preset: manualAdvancePreset(focus: 5, short: 2), clock: clock)
        engine.start()
        clock.advance(5)
        engine.tick()

        XCTAssertEqual(engine.phase, .shortBreak)
        XCTAssertEqual(engine.runState, .ready)
        XCTAssertEqual(engine.remainingSeconds, 2)

        // Ready phase does not count down on its own.
        clock.advance(10)
        engine.tick()
        XCTAssertEqual(engine.runState, .ready)
        XCTAssertEqual(engine.remainingSeconds, 2)
    }

    func testExplicitStartFromReadyBeginsCountdown() {
        let clock = ManualClock()
        let engine = makeEngine(preset: manualAdvancePreset(focus: 5, short: 2), clock: clock)
        engine.start()
        clock.advance(5)
        engine.tick()
        XCTAssertEqual(engine.runState, .ready)

        engine.start()

        XCTAssertEqual(engine.runState, .running)
        XCTAssertEqual(engine.remainingSeconds, 2)

        clock.advance(2)
        var finished = false
        engine.onPhaseFinished = { finished = $0.completed }
        engine.tick()
        XCTAssertTrue(finished)
        XCTAssertEqual(engine.phase, .focus)
    }

    // MARK: - long break scheduling

    func testLongBreakAfterConfiguredNumberOfFocusBlocks() {
        let clock = ManualClock()
        let preset = autoAdvancePreset(focus: 5, short: 2, long: 8, blocksPerLongBreak: 3)
        let engine = makeEngine(preset: preset, clock: clock)

        engine.start()  // focus 1
        clock.advance(5); engine.tick()  // -> shortBreak
        XCTAssertEqual(engine.phase, .shortBreak)
        clock.advance(2); engine.tick()  // -> focus 2
        XCTAssertEqual(engine.phase, .focus)
        XCTAssertEqual(engine.completedFocusBlocksInCycle, 1)

        clock.advance(5); engine.tick()  // -> shortBreak
        clock.advance(2); engine.tick()  // -> focus 3
        XCTAssertEqual(engine.phase, .focus)
        XCTAssertEqual(engine.completedFocusBlocksInCycle, 2)

        clock.advance(5); engine.tick()  // 3rd focus complete -> longBreak

        XCTAssertEqual(engine.phase, .longBreak)
        XCTAssertEqual(engine.remainingSeconds, 8)
        XCTAssertEqual(engine.completedFocusBlocksInCycle, 0)
    }

    func testCycleCounterResetsAfterLongBreakAndRepeats() {
        let clock = ManualClock()
        let preset = autoAdvancePreset(focus: 5, short: 2, long: 8, blocksPerLongBreak: 2)
        let engine = makeEngine(preset: preset, clock: clock)

        engine.start()
        clock.advance(5); engine.tick()  // shortBreak
        clock.advance(2); engine.tick()  // focus 2
        clock.advance(5); engine.tick()  // longBreak, counter resets to 0
        XCTAssertEqual(engine.phase, .longBreak)
        XCTAssertEqual(engine.completedFocusBlocksInCycle, 0)

        clock.advance(8); engine.tick()  // focus
        XCTAssertEqual(engine.phase, .focus)
        XCTAssertEqual(engine.completedFocusBlocksInCycle, 0)

        clock.advance(5); engine.tick()  // shortBreak again (not long)
        XCTAssertEqual(engine.phase, .shortBreak)
    }

    // MARK: - PhaseOutcome

    func testOutcomeReportsNextPhaseAndCycleCompletionForShortBreak() {
        let clock = ManualClock()
        let engine = makeEngine(preset: autoAdvancePreset(focus: 5, short: 2, blocksPerLongBreak: 2), clock: clock)
        var outcomes: [PhaseOutcome] = []
        engine.onPhaseFinished = { outcomes.append($0) }

        engine.start()
        clock.advance(5)
        engine.tick()

        XCTAssertEqual(outcomes.count, 1)
        XCTAssertEqual(outcomes[0].finishedPhase, .focus)
        XCTAssertTrue(outcomes[0].completed)
        XCTAssertFalse(outcomes[0].didCompleteCycle)
        XCTAssertEqual(outcomes[0].nextPhase, .shortBreak)
    }

    func testOutcomeReportsCycleCompletionWhenLongBreakIsDue() {
        let clock = ManualClock()
        let engine = makeEngine(preset: autoAdvancePreset(focus: 5, short: 2, long: 8, blocksPerLongBreak: 2), clock: clock)
        var outcomes: [PhaseOutcome] = []
        engine.onPhaseFinished = { outcomes.append($0) }

        engine.start()
        clock.advance(5); engine.tick()  // focus 1 -> shortBreak
        clock.advance(2); engine.tick()  // shortBreak -> focus 2
        clock.advance(5); engine.tick()  // focus 2 -> longBreak

        let focusCycleOutcome = outcomes.last { $0.finishedPhase == .focus }
        XCTAssertEqual(focusCycleOutcome?.nextPhase, .longBreak)
        XCTAssertEqual(focusCycleOutcome?.didCompleteCycle, true)
    }

    func testAbandonOutcomeReportsIdleNextPhaseAndNoCycleCompletion() {
        let clock = ManualClock()
        let engine = makeEngine(preset: autoAdvancePreset(focus: 100), clock: clock)
        var outcomes: [PhaseOutcome] = []
        engine.onPhaseFinished = { outcomes.append($0) }

        engine.start()
        engine.abandon()

        XCTAssertEqual(outcomes.count, 1)
        XCTAssertEqual(outcomes[0].finishedPhase, .focus)
        XCTAssertFalse(outcomes[0].completed)
        XCTAssertFalse(outcomes[0].didCompleteCycle)
        XCTAssertEqual(outcomes[0].nextPhase, .idle)
    }

    // MARK: - abandon

    func testAbandonReturnsToIdleAndReportsIncomplete() {
        let clock = ManualClock()
        let engine = makeEngine(preset: autoAdvancePreset(focus: 100), clock: clock)
        var finishedEvents: [(TimerPhase, Bool)] = []
        engine.onPhaseFinished = { finishedEvents.append(($0.finishedPhase, $0.completed)) }

        engine.start()
        clock.advance(10)
        engine.tick()

        engine.abandon()

        XCTAssertEqual(engine.phase, .idle)
        XCTAssertEqual(engine.runState, .idle)
        XCTAssertEqual(engine.remainingSeconds, 0)
        XCTAssertEqual(finishedEvents.count, 1)
        XCTAssertEqual(finishedEvents[0].0, .focus)
        XCTAssertFalse(finishedEvents[0].1)
    }

    func testAbandonFromPausedStateReturnsToIdle() {
        let clock = ManualClock()
        let engine = makeEngine(preset: autoAdvancePreset(), clock: clock)
        engine.start()
        engine.pause()

        engine.abandon()

        XCTAssertEqual(engine.phase, .idle)
        XCTAssertEqual(engine.runState, .idle)
    }

    func testAbandonFromReadyStateReturnsToIdle() {
        let clock = ManualClock()
        let engine = makeEngine(preset: manualAdvancePreset(focus: 5), clock: clock)
        engine.start()
        clock.advance(5)
        engine.tick()
        XCTAssertEqual(engine.runState, .ready)

        engine.abandon()

        XCTAssertEqual(engine.phase, .idle)
        XCTAssertEqual(engine.runState, .idle)
    }

    func testAbandonResetsFocusBlockCycleCounter() {
        let clock = ManualClock()
        let preset = autoAdvancePreset(focus: 5, short: 2, blocksPerLongBreak: 4)
        let engine = makeEngine(preset: preset, clock: clock)

        engine.start()
        clock.advance(5); engine.tick()  // shortBreak, completedFocusBlocksInCycle == 1
        XCTAssertEqual(engine.completedFocusBlocksInCycle, 1)

        engine.abandon()

        XCTAssertEqual(engine.completedFocusBlocksInCycle, 0)
    }

    func testAbandonWhileIdleIsNoOp() {
        let clock = ManualClock()
        let engine = makeEngine(preset: .standard, clock: clock)
        var fired = false
        engine.onPhaseFinished = { _ in fired = true }

        engine.abandon()

        XCTAssertFalse(fired)
        XCTAssertEqual(engine.phase, .idle)
    }

    // MARK: - CyclePreset

    func testStandardPresetDefaults() {
        let preset = CyclePreset.standard
        XCTAssertEqual(preset.focusSeconds, 25 * 60)
        XCTAssertEqual(preset.shortBreakSeconds, 5 * 60)
        XCTAssertEqual(preset.longBreakSeconds, 15 * 60)
        XCTAssertEqual(preset.blocksPerLongBreak, 4)
        XCTAssertFalse(preset.autoAdvance)
    }

    func testCyclePresetEquatable() {
        let a = CyclePreset.standard
        let b = CyclePreset.standard
        XCTAssertEqual(a, b)

        let c = CyclePreset(
            focusSeconds: 10,
            shortBreakSeconds: 2,
            longBreakSeconds: 4,
            blocksPerLongBreak: 2,
            autoAdvance: true
        )
        XCTAssertNotEqual(a, c)
    }

    func testCyclePresetRoundTripsThroughCodable() throws {
        let preset = CyclePreset.standard
        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(CyclePreset.self, from: data)
        XCTAssertEqual(preset, decoded)
    }
}
