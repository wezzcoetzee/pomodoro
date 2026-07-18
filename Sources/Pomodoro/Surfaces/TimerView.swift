import SwiftUI

enum TimerVariant {
    case full
    case compact
}

struct TimerView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var variant: TimerVariant = .full

    private var engine: TimerEngine { appModel.engine }
    private var palette: PhasePalette { PomodoroColors.palette(for: engine.phase) }

    var body: some View {
        Group {
            switch variant {
            case .full: fullBody
            case .compact: compactBody
            }
        }
        .background(palette.canvas)
    }

    private var fullBody: some View {
        VStack(spacing: 24) {
            phaseHeader
            ring(digitSize: 76, ringSize: 240, lineWidth: 16)
            sessionIdentity
            controls
        }
        .padding(32)
        .frame(minWidth: 340)
    }

    private var compactBody: some View {
        HStack(spacing: 14) {
            ring(digitSize: 30, ringSize: 74, lineWidth: 7)
            VStack(alignment: .leading, spacing: 3) {
                Text(appModel.phaseLabel)
                    .pomodoroLabelStyle()
                    .foregroundStyle(palette.accent)
                Text(sessionTitle)
                    .pomodoroText(.title)
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            primaryButton(compact: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minWidth: 260)
    }

    private var phaseHeader: some View {
        Text(appModel.phaseLabel)
            .pomodoroLabelStyle()
            .foregroundStyle(palette.accent)
    }

    private func ring(digitSize: CGFloat, ringSize: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(palette.line, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: appModel.progress)
                .stroke(palette.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : PomodoroMotion.ringFill, value: appModel.progress)
            Text(timeString)
                .font(PomodoroFont.timer(digitSize))
                .foregroundStyle(engine.phase == .idle ? palette.inkDim : palette.ink)
        }
        .frame(width: ringSize, height: ringSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(appModel.phaseLabel)
        .accessibilityValue("\(timeString) remaining")
    }

    private var sessionIdentity: some View {
        VStack(spacing: 8) {
            Text(sessionTitle)
                .pomodoroText(.headline)
                .foregroundStyle(palette.ink)
                .lineLimit(1)
            if let ticket = appModel.activeTicket {
                TicketBadge(ticket: ticket, palette: palette) {
                    appModel.openTicket(ticket)
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            primaryButton(compact: false)
            Button(action: appModel.skip) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 46, height: 46)
                    .foregroundStyle(palette.inkDim)
                    .background(palette.surface, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(engine.runState == .idle)
            .opacity(engine.runState == .idle ? 0.4 : 1)
            .accessibilityLabel("Skip phase")
            .keyboardShortcut(.rightArrow, modifiers: [])
        }
    }

    private func primaryButton(compact: Bool) -> some View {
        Button(action: appModel.togglePauseResume) {
            Image(systemName: primaryIcon)
                .font(.system(size: compact ? 15 : 20, weight: .heavy))
                .frame(width: compact ? 40 : 64, height: compact ? 40 : 64)
                .foregroundStyle(palette.onAccent)
                .background(palette.accent, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(engine.runState == .running ? "Pause" : "Resume")
        .keyboardShortcut(.space, modifiers: [])
    }

    private var primaryIcon: String {
        engine.runState == .running ? "pause.fill" : "play.fill"
    }

    private var sessionTitle: String {
        appModel.activeName.isEmpty ? "Focus session" : appModel.activeName
    }

    private var timeString: String {
        let seconds = max(0, engine.remainingSeconds)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

struct TicketBadge: View {
    let ticket: TicketRef
    let palette: PhasePalette
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: ticket.kind == .github ? "chevron.left.forwardslash.chevron.right" : "ticket.fill")
                    .font(.system(size: 9, weight: .bold))
                Text(ticket.displayBadge)
                    .pomodoroText(.label)
            }
            .foregroundStyle(palette.onAccent)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(palette.accentSoft, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(ticket.deepLink == nil)
        .accessibilityLabel("Ticket \(ticket.displayBadge)")
        .accessibilityHint(ticket.deepLink == nil ? "" : "Opens the ticket")
    }
}
