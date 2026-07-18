import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appModel: AppModel

    private let palette = PomodoroColors.palette(for: .focus)

    private var streak: Int {
        appModel.store.currentStreak()
    }

    private var dailyCounts: [(date: Date, count: Int)] {
        appModel.store.dailyCounts(lastNDays: 14)
    }

    private var daySections: [(day: Date, sessions: [FocusSession])] {
        appModel.store.sessionsByDay()
            .map { (day: $0.key, sessions: $0.value.sorted { $0.startedAt > $1.startedAt }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                streakStrip
                if daySections.isEmpty {
                    emptyState
                } else {
                    ForEach(daySections, id: \.day) { section in
                        daySection(section)
                    }
                }
            }
            .padding(24)
        }
        .frame(width: SurfaceMetrics.mainWidth, height: 460)
        .background(palette.canvas)
    }

    private var streakStrip: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(PomodoroColors.streak)
                Text("\(streak)")
                    .font(PomodoroFont.streakNumber)
                    .foregroundStyle(PomodoroColors.streak)
                Text("day streak")
                    .pomodoroLabelStyle()
                    .foregroundStyle(palette.inkDim)
                    .padding(.leading, 2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(streak) day streak")
            momentumRow
        }
    }

    private var momentumRow: some View {
        let peak = max(dailyCounts.map(\.count).max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 5) {
            ForEach(dailyCounts, id: \.date) { day in
                let fraction = Double(day.count) / Double(peak)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(day.count > 0 ? palette.accent : palette.line)
                    .frame(width: 9, height: 8 + CGFloat(fraction) * 30)
                    .opacity(day.count > 0 ? 1 : 0.6)
            }
        }
        .frame(height: 40, alignment: .bottom)
    }

    private func daySection(_ section: (day: Date, sessions: [FocusSession])) -> some View {
        let blocks = section.sessions.reduce(0) { $0 + $1.completedBlocks }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(dayLabel(section.day))
                    .pomodoroText(.headline)
                    .foregroundStyle(palette.ink)
                Spacer()
                blockCount(blocks)
            }
            ForEach(section.sessions, id: \.startedAt) { session in
                sessionRow(session)
            }
        }
    }

    private func blockCount(_ blocks: Int) -> some View {
        HStack(spacing: 6) {
            Text("\(blocks)")
                .pomodoroText(.headline)
                .foregroundStyle(palette.accent)
            Text(blocks == 1 ? "block" : "blocks")
                .pomodoroLabelStyle()
                .foregroundStyle(palette.inkDim)
        }
    }

    private func sessionRow(_ session: FocusSession) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.name.isEmpty ? "Focus session" : session.name)
                    .pomodoroText(.title)
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                if let ticket = session.ticket {
                    Text(ticket.displayBadge)
                        .pomodoroText(.label)
                        .foregroundStyle(palette.inkDim)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 3) {
                ForEach(0..<max(session.completedBlocks, 0), id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(palette.accent)
                        .frame(width: 7, height: 14)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No blocks yet")
                .pomodoroText(.title)
                .foregroundStyle(palette.ink)
            Text("Finish a focus block and it shows up here. Momentum starts with one.")
                .pomodoroText(.body)
                .foregroundStyle(palette.inkDim)
        }
        .padding(.top, 8)
    }

    private func dayLabel(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: day)
    }
}
