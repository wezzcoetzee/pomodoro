import Combine
import Foundation
import SwiftData

enum SessionOutcome: String, Codable {
    case completed
    case abandoned
}

@Model
final class FocusSession {
    var name: String
    var ticketRaw: String
    var ticketKindRaw: String
    var startedAt: Date
    var endedAt: Date?
    var plannedSeconds: Int
    var completedBlocks: Int
    var outcomeRaw: String

    var ticketKind: TicketKind {
        TicketKind(rawValue: ticketKindRaw) ?? .none
    }

    var outcome: SessionOutcome {
        SessionOutcome(rawValue: outcomeRaw) ?? .abandoned
    }

    var ticket: TicketRef? {
        ticketRaw.isEmpty ? nil : TicketRefParser.parse(ticketRaw)
    }

    init(
        name: String,
        ticketRaw: String,
        ticketKind: TicketKind,
        startedAt: Date,
        endedAt: Date? = nil,
        plannedSeconds: Int,
        completedBlocks: Int = 0,
        outcome: SessionOutcome = .abandoned
    ) {
        self.name = name
        self.ticketRaw = ticketRaw
        self.ticketKindRaw = ticketKind.rawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.plannedSeconds = plannedSeconds
        self.completedBlocks = completedBlocks
        self.outcomeRaw = outcome.rawValue
    }
}

@Model
final class BlockRecord {
    var phaseRaw: String
    var startedAt: Date
    var endedAt: Date?
    var wasCompleted: Bool
    var session: FocusSession?

    var phase: TimerPhase {
        TimerPhase(rawValue: phaseRaw) ?? .focus
    }

    init(phase: TimerPhase, startedAt: Date, endedAt: Date? = nil, wasCompleted: Bool = false, session: FocusSession? = nil) {
        self.phaseRaw = phase.rawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.wasCompleted = wasCompleted
        self.session = session
    }
}

@MainActor
final class SessionStore: ObservableObject {
    let modelContainer: ModelContainer
    private let clock: () -> Date

    private var context: ModelContext {
        modelContainer.mainContext
    }

    init(inMemory: Bool = false, clock: @escaping () -> Date = Date.init) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        modelContainer = try ModelContainer(
            for: FocusSession.self, BlockRecord.self,
            configurations: configuration
        )
        self.clock = clock
    }

    @discardableResult
    func beginSession(
        name: String,
        ticketRaw: String,
        ticketKind: TicketKind,
        plannedSeconds: Int,
        startedAt: Date? = nil
    ) -> FocusSession {
        let session = FocusSession(
            name: name,
            ticketRaw: ticketRaw,
            ticketKind: ticketKind,
            startedAt: startedAt ?? clock(),
            plannedSeconds: plannedSeconds
        )
        context.insert(session)
        try? context.save()
        objectWillChange.send()
        return session
    }

    @discardableResult
    func recordBlock(
        phase: TimerPhase,
        startedAt: Date,
        endedAt: Date,
        wasCompleted: Bool,
        in session: FocusSession
    ) -> BlockRecord {
        let block = BlockRecord(
            phase: phase,
            startedAt: startedAt,
            endedAt: endedAt,
            wasCompleted: wasCompleted,
            session: session
        )
        context.insert(block)
        if wasCompleted {
            session.completedBlocks += 1
        }
        try? context.save()
        objectWillChange.send()
        return block
    }

    func endSession(_ session: FocusSession, outcome: SessionOutcome, endedAt: Date? = nil) {
        session.endedAt = endedAt ?? clock()
        session.outcomeRaw = outcome.rawValue
        try? context.save()
        objectWillChange.send()
    }

    func sessionsByDay(calendar: Calendar = .current) -> [Date: [FocusSession]] {
        Dictionary(grouping: fetchAllSessions()) { calendar.startOfDay(for: $0.startedAt) }
    }

    func dailyCounts(
        lastNDays: Int,
        referenceDate: Date? = nil,
        calendar: Calendar = .current
    ) -> [(date: Date, count: Int)] {
        guard lastNDays > 0 else { return [] }

        let today = calendar.startOfDay(for: referenceDate ?? clock())
        var countsByDay: [Date: Int] = [:]
        for block in fetchAllBlockRecords() where block.wasCompleted {
            let day = calendar.startOfDay(for: block.startedAt)
            countsByDay[day, default: 0] += 1
        }

        var result: [(date: Date, count: Int)] = []
        for offset in stride(from: lastNDays - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            result.append((date: day, count: countsByDay[day] ?? 0))
        }
        return result
    }

    func currentStreak(referenceDate: Date? = nil, calendar: Calendar = .current) -> Int {
        let completedDays = Set(fetchAllBlockRecords().filter(\.wasCompleted).map { calendar.startOfDay(for: $0.startedAt) })

        let today = calendar.startOfDay(for: referenceDate ?? clock())
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }

        var cursor: Date
        if completedDays.contains(today) {
            cursor = today
        } else if completedDays.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }

        var streak = 0
        while completedDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }
        return streak
    }

    private func fetchAllSessions() -> [FocusSession] {
        (try? context.fetch(FetchDescriptor<FocusSession>())) ?? []
    }

    private func fetchAllBlockRecords() -> [BlockRecord] {
        (try? context.fetch(FetchDescriptor<BlockRecord>())) ?? []
    }
}
