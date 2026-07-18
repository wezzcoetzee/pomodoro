import Foundation

struct CyclePreset: Equatable, Codable {
    var focusSeconds: Int
    var shortBreakSeconds: Int
    var longBreakSeconds: Int
    var blocksPerLongBreak: Int
    var autoAdvance: Bool

    static let standard = CyclePreset(
        focusSeconds: 25 * 60,
        shortBreakSeconds: 5 * 60,
        longBreakSeconds: 15 * 60,
        blocksPerLongBreak: 4,
        autoAdvance: false
    )
}
