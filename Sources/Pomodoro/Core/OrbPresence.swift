import Foundation

/// How insistently the floating orb asks for a block.
///
/// The orb escalates with the time spent waiting to start (no phase running):
/// quiet at first, a "Start focus" nudge after 20 minutes, and an urgent filled
/// pill showing the idle time after 45. Any running or paused phase is `active`.
enum OrbPresence: Equatable {
    case quiet
    case nudge
    case urge(idleMinutes: Int)
    case active

    static let nudgeAfter: TimeInterval = 20 * 60
    static let urgeAfter: TimeInterval = 45 * 60

    static func resolve(runState: TimerRunState, awaitingStartSince: Date?, now: Date) -> OrbPresence {
        switch runState {
        case .running, .paused:
            return .active
        case .idle, .ready:
            let idle = now.timeIntervalSince(awaitingStartSince ?? now)
            if idle >= urgeAfter { return .urge(idleMinutes: Int(idle / 60)) }
            if idle >= nudgeAfter { return .nudge }
            return .quiet
        }
    }
}
