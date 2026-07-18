import Combine
import XCTest
@testable import Pomodoro

@MainActor
final class SessionStoreTests: XCTestCase {
    private func makeStore() throws -> SessionStore {
        try SessionStore(inMemory: true)
    }

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return calendar().date(from: components)!
    }

    // MARK: begin/record/end lifecycle

    func testBeginSessionCreatesSessionWithDefaults() throws {
        let store = try makeStore()
        let session = store.beginSession(
            name: "Write tests",
            ticketRaw: "VLT-1234",
            ticketKind: .jira,
            plannedSeconds: 1500,
            startedAt: date(2026, 7, 17)
        )

        XCTAssertEqual(session.name, "Write tests")
        XCTAssertEqual(session.ticketRaw, "VLT-1234")
        XCTAssertEqual(session.ticketKind, .jira)
        XCTAssertEqual(session.plannedSeconds, 1500)
        XCTAssertEqual(session.completedBlocks, 0)
        XCTAssertNil(session.endedAt)
        XCTAssertEqual(session.outcome, .abandoned)
    }

    func testRecordBlockIncrementsCompletedBlocksOnlyWhenCompleted() throws {
        let store = try makeStore()
        let session = store.beginSession(
            name: "Focus block",
            ticketRaw: "",
            ticketKind: .none,
            plannedSeconds: 1500,
            startedAt: date(2026, 7, 17)
        )

        store.recordBlock(
            phase: .focus,
            startedAt: date(2026, 7, 17, hour: 9),
            endedAt: date(2026, 7, 17, hour: 9),
            wasCompleted: true,
            in: session
        )
        store.recordBlock(
            phase: .focus,
            startedAt: date(2026, 7, 17, hour: 10),
            endedAt: date(2026, 7, 17, hour: 10),
            wasCompleted: false,
            in: session
        )

        XCTAssertEqual(session.completedBlocks, 1)
    }

    func testEndSessionSetsOutcomeAndEndedAt() throws {
        let store = try makeStore()
        let session = store.beginSession(
            name: "Focus block",
            ticketRaw: "",
            ticketKind: .none,
            plannedSeconds: 1500,
            startedAt: date(2026, 7, 17)
        )
        let endMoment = date(2026, 7, 17, hour: 13)

        store.endSession(session, outcome: .completed, endedAt: endMoment)

        XCTAssertEqual(session.outcome, .completed)
        XCTAssertEqual(session.endedAt, endMoment)
    }

    // MARK: sessionsByDay

    func testSessionsByDayGroupsByCalendarDay() throws {
        let store = try makeStore()
        _ = store.beginSession(
            name: "Morning",
            ticketRaw: "",
            ticketKind: .none,
            plannedSeconds: 1500,
            startedAt: date(2026, 7, 17, hour: 8)
        )
        _ = store.beginSession(
            name: "Evening",
            ticketRaw: "",
            ticketKind: .none,
            plannedSeconds: 1500,
            startedAt: date(2026, 7, 17, hour: 20)
        )
        _ = store.beginSession(
            name: "Next day",
            ticketRaw: "",
            ticketKind: .none,
            plannedSeconds: 1500,
            startedAt: date(2026, 7, 18, hour: 8)
        )

        let grouped = store.sessionsByDay(calendar: calendar())

        XCTAssertEqual(grouped.count, 2)
        XCTAssertEqual(grouped[calendar().startOfDay(for: date(2026, 7, 17))]?.count, 2)
        XCTAssertEqual(grouped[calendar().startOfDay(for: date(2026, 7, 18))]?.count, 1)
    }

    // MARK: dailyCounts

    func testDailyCountsCountsOnlyCompletedBlocksPerDay() throws {
        let store = try makeStore()
        let session = store.beginSession(
            name: "Focus block",
            ticketRaw: "",
            ticketKind: .none,
            plannedSeconds: 1500,
            startedAt: date(2026, 7, 15)
        )

        store.recordBlock(phase: .focus, startedAt: date(2026, 7, 15), endedAt: date(2026, 7, 15), wasCompleted: true, in: session)
        store.recordBlock(phase: .focus, startedAt: date(2026, 7, 16), endedAt: date(2026, 7, 16), wasCompleted: true, in: session)
        store.recordBlock(phase: .focus, startedAt: date(2026, 7, 16), endedAt: date(2026, 7, 16), wasCompleted: true, in: session)
        store.recordBlock(phase: .focus, startedAt: date(2026, 7, 17), endedAt: date(2026, 7, 17), wasCompleted: false, in: session)

        let counts = store.dailyCounts(lastNDays: 3, referenceDate: date(2026, 7, 17), calendar: calendar())

        XCTAssertEqual(counts.count, 3)
        XCTAssertEqual(counts[0].count, 1)
        XCTAssertEqual(counts[1].count, 2)
        XCTAssertEqual(counts[2].count, 0)
        XCTAssertEqual(counts[2].date, calendar().startOfDay(for: date(2026, 7, 17)))
    }

    func testDailyCountsFillsZeroForDaysWithoutSessions() throws {
        let store = try makeStore()
        let counts = store.dailyCounts(lastNDays: 5, referenceDate: date(2026, 7, 17), calendar: calendar())

        XCTAssertEqual(counts.count, 5)
        XCTAssertTrue(counts.allSatisfy { $0.count == 0 })
    }

    // MARK: currentStreak

    func testCurrentStreakZeroWithNoCompletedBlocks() throws {
        let store = try makeStore()
        XCTAssertEqual(store.currentStreak(referenceDate: date(2026, 7, 17), calendar: calendar()), 0)
    }

    func testCurrentStreakCountsConsecutiveDaysEndingToday() throws {
        let store = try makeStore()
        let session = store.beginSession(
            name: "Streak",
            ticketRaw: "",
            ticketKind: .none,
            plannedSeconds: 1500,
            startedAt: date(2026, 7, 15)
        )

        for day in [15, 16, 17] {
            store.recordBlock(
                phase: .focus,
                startedAt: date(2026, 7, day),
                endedAt: date(2026, 7, day),
                wasCompleted: true,
                in: session
            )
        }

        XCTAssertEqual(store.currentStreak(referenceDate: date(2026, 7, 17), calendar: calendar()), 3)
    }

    func testCurrentStreakStillCountsWhenTodayHasNoBlockYetButYesterdayDoes() throws {
        let store = try makeStore()
        let session = store.beginSession(
            name: "Streak",
            ticketRaw: "",
            ticketKind: .none,
            plannedSeconds: 1500,
            startedAt: date(2026, 7, 15)
        )

        for day in [15, 16] {
            store.recordBlock(
                phase: .focus,
                startedAt: date(2026, 7, day),
                endedAt: date(2026, 7, day),
                wasCompleted: true,
                in: session
            )
        }

        XCTAssertEqual(store.currentStreak(referenceDate: date(2026, 7, 17), calendar: calendar()), 2)
    }

    func testCurrentStreakBreaksOnGapDay() throws {
        let store = try makeStore()
        let session = store.beginSession(
            name: "Streak",
            ticketRaw: "",
            ticketKind: .none,
            plannedSeconds: 1500,
            startedAt: date(2026, 7, 10)
        )

        for day in [10, 11, 15, 16, 17] {
            store.recordBlock(
                phase: .focus,
                startedAt: date(2026, 7, day),
                endedAt: date(2026, 7, day),
                wasCompleted: true,
                in: session
            )
        }

        XCTAssertEqual(store.currentStreak(referenceDate: date(2026, 7, 17), calendar: calendar()), 3)
    }

    func testCurrentStreakZeroWhenMostRecentActivityIsTwoDaysAgo() throws {
        let store = try makeStore()
        let session = store.beginSession(
            name: "Streak",
            ticketRaw: "",
            ticketKind: .none,
            plannedSeconds: 1500,
            startedAt: date(2026, 7, 15)
        )

        store.recordBlock(
            phase: .focus,
            startedAt: date(2026, 7, 15),
            endedAt: date(2026, 7, 15),
            wasCompleted: true,
            in: session
        )

        XCTAssertEqual(store.currentStreak(referenceDate: date(2026, 7, 17), calendar: calendar()), 0)
    }

    func testCurrentStreakAcrossMonthBoundary() throws {
        let store = try makeStore()
        let session = store.beginSession(
            name: "Streak",
            ticketRaw: "",
            ticketKind: .none,
            plannedSeconds: 1500,
            startedAt: date(2026, 1, 30)
        )

        let boundaryDates: [(Int, Int)] = [(1, 30), (1, 31), (2, 1), (2, 2)]
        for (month, day) in boundaryDates {
            store.recordBlock(
                phase: .focus,
                startedAt: date(2026, month, day),
                endedAt: date(2026, month, day),
                wasCompleted: true,
                in: session
            )
        }

        XCTAssertEqual(store.currentStreak(referenceDate: date(2026, 2, 2), calendar: calendar()), 4)
    }

    // MARK: change notifications

    func testStoreNotifiesObserversOnSessionAndBlockWrites() throws {
        let store = try makeStore()
        var changeCount = 0
        let cancellable = store.objectWillChange.sink { changeCount += 1 }

        let session = store.beginSession(
            name: "Observed",
            ticketRaw: "",
            ticketKind: .none,
            plannedSeconds: 1500,
            startedAt: date(2026, 7, 17)
        )
        XCTAssertEqual(changeCount, 1)

        store.recordBlock(
            phase: .focus,
            startedAt: date(2026, 7, 17),
            endedAt: date(2026, 7, 17),
            wasCompleted: true,
            in: session
        )
        XCTAssertEqual(changeCount, 2)

        store.endSession(session, outcome: .completed, endedAt: date(2026, 7, 17))
        XCTAssertEqual(changeCount, 3)

        cancellable.cancel()
    }
}
