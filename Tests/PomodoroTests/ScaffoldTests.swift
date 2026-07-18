import XCTest
@testable import Pomodoro

final class ScaffoldTests: XCTestCase {
    func testStandardPresetDefaults() {
        let preset = CyclePreset.standard
        XCTAssertEqual(preset.focusSeconds, 25 * 60)
        XCTAssertEqual(preset.shortBreakSeconds, 5 * 60)
        XCTAssertEqual(preset.longBreakSeconds, 15 * 60)
        XCTAssertEqual(preset.blocksPerLongBreak, 4)
        XCTAssertFalse(preset.autoAdvance)
    }

    @MainActor
    func testEngineStartsIdle() {
        let engine = TimerEngine()
        XCTAssertEqual(engine.phase, .idle)
    }
}
