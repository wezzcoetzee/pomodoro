import SwiftUI

/// Window-side state the orb cannot derive from `AppModel`: the escalation clock,
/// pointer hover (tracked by the hosting view so it works while another app is
/// active), and the corner the panel is snapped to.
@MainActor
final class OrbViewState: ObservableObject {
    @Published var now: Date
    @Published var isHovering = false
    @Published var corner: OrbCorner
    /// True for a moment after a focus block completes; the orb flashes Done green.
    @Published var isCelebrating = false

    init(now: Date = Date(), corner: OrbCorner) {
        self.now = now
        self.corner = corner
    }
}

/// The always-on presence: a timer ring floating over every app, with a pill
/// that slides out of it when the user has gone too long without a block.
struct OrbView: View {
    @EnvironmentObject private var appModel: AppModel
    @ObservedObject var state: OrbViewState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var onOpenTimer: () -> Void = {}
    var onDragChanged: () -> Void = {}
    var onDragEnded: () -> Void = {}

    @State private var isDragging = false

    private enum Metrics {
        static let orb: CGFloat = 56
        static let quietOrb: CGFloat = 40
        static let pillHeight: CGFloat = 40
        /// How far the pill tucks under the orb, so it reads as sliding out of it.
        static let tuck: CGFloat = 28
        static let celebrationSeconds: Double = 1.2
    }

    private var engine: TimerEngine { appModel.engine }
    private var palette: PhasePalette { PomodoroColors.palette(for: engine.phase) }

    private var presence: OrbPresence {
        OrbPresence.resolve(runState: engine.runState, awaitingStartSince: appModel.awaitingStartSince, now: state.now)
    }

    private enum PillKind: Equatable {
        case none, nudge, urge(idleMinutes: Int), controls
    }

    private var pill: PillKind {
        switch presence {
        case _ where state.isCelebrating: return .none
        case .quiet: return .none
        case .nudge: return .nudge
        case .urge(let minutes): return .urge(idleMinutes: minutes)
        case .active: return state.isHovering ? .controls : .none
        }
    }

    var body: some View {
        HStack(spacing: pill == .none ? 0 : -Metrics.tuck) {
            if state.corner.isLeading {
                orb.zIndex(1)
                pillView
            } else {
                pillView
                orb.zIndex(1)
            }
        }
        .animation(reduceMotion ? nil : PomodoroMotion.orbSlide, value: pill)
        .animation(reduceMotion ? nil : PomodoroMotion.orbSlide, value: presence == .quiet)
        .gesture(drag)
        .onChange(of: appModel.celebration) { _, moment in
            if moment != nil { celebrate() }
        }
    }

    // MARK: Orb

    private var orb: some View {
        let isQuiet = presence == .quiet
        let size = isQuiet ? Metrics.quietOrb : Metrics.orb
        let stroke: CGFloat = isQuiet ? 4 : 5
        return ZStack {
            Circle().fill(isQuiet ? palette.surface : palette.canvas)
            Circle()
                .inset(by: stroke / 2 + 2)
                .stroke(palette.line, lineWidth: stroke)
            if state.isCelebrating {
                Circle()
                    .inset(by: stroke / 2 + 2)
                    .stroke(PomodoroColors.done, lineWidth: stroke)
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.34, weight: .heavy))
                    .foregroundStyle(PomodoroColors.done)
            } else if presence == .active {
                Circle()
                    .inset(by: stroke / 2 + 2)
                    .trim(from: 0, to: appModel.progress)
                    .stroke(
                        engine.runState == .paused ? palette.accentSoft : palette.accent,
                        style: StrokeStyle(lineWidth: stroke, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : PomodoroMotion.ringFill, value: appModel.progress)
                Text("\(minutesLeft)")
                    .font(PomodoroFont.timer(18))
                    .foregroundStyle(engine.runState == .paused ? palette.accentSoft : palette.accent)
            } else {
                // Quiet stays dim until the pointer arrives; it never slides the pill out.
                Image(systemName: "play.fill")
                    .font(.system(size: size * 0.32, weight: .heavy))
                    .foregroundStyle(isQuiet && !state.isHovering ? palette.inkDim : palette.accent)
                    .offset(x: size * 0.03)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .onTapGesture { handleOrbTap() }
        .help(presence == .active ? "Open timer" : "Start focus")
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(presence == .active ? appModel.phaseLabel : "Start focus")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(presence == .active ? "Opens the timer" : "Starts a focus block")
        .accessibilityAction { handleOrbTap() }
    }

    private var minutesLeft: Int {
        Int((Double(max(0, engine.remainingSeconds)) / 60).rounded(.up))
    }

    private var accessibilityValue: String {
        switch presence {
        case .active: return "\(minutesLeft) minutes left"
        case .urge(let minutes): return "Idle for \(Self.idleText(minutes))"
        case .quiet, .nudge: return ""
        }
    }

    // MARK: Pill

    @ViewBuilder
    private var pillView: some View {
        switch pill {
        case .none:
            EmptyView()
        case .nudge:
            startButton {
                pillShell(fill: palette.canvas, outline: palette.accent) {
                    Text("Start focus")
                        .pomodoroText(.title)
                        .foregroundStyle(palette.accent)
                }
            }
            .transition(pillTransition)
        case .urge(let minutes):
            startButton {
                pillShell(fill: palette.accent, outline: nil) {
                    // Both versions share one slot sized to the wider, so hovering never
                    // resizes the panel out from under the pointer. Each hugs the outer cap,
                    // leaving any spare width on the orb side where the tuck hides it.
                    ZStack(alignment: state.corner.isLeading ? .trailing : .leading) {
                        urgeLabel(caption: "\(Self.idleText(minutes)) idle").opacity(state.isHovering ? 0 : 1)
                        urgeLabel(caption: blocksTodayText).opacity(state.isHovering ? 1 : 0)
                    }
                }
                .foregroundStyle(palette.onAccent)
            }
            .accessibilityValue("Idle for \(Self.idleText(minutes)), \(blocksTodayText)")
            .transition(pillTransition)
        case .controls:
            pillShell(fill: palette.canvas, outline: nil) {
                controlButton(
                    engine.runState == .running ? "pause.fill" : "play.fill",
                    label: engine.runState == .running ? "Pause" : "Resume",
                    action: appModel.togglePauseResume
                )
                controlButton("forward.end.fill", label: "Skip phase", action: appModel.skip)
            }
            .transition(pillTransition)
        }
    }

    private func urgeLabel(caption: String) -> some View {
        HStack(spacing: 8) {
            Text("Start focus")
                .pomodoroText(.title)
            Text(caption)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }

    private var blocksTodayText: String {
        let count = appModel.blocksToday
        return "\(count) block\(count == 1 ? "" : "s") today"
    }

    private func startButton(@ViewBuilder label: () -> some View) -> some View {
        Button(action: startIfStill, label: label)
            .buttonStyle(.plain)
            .accessibilityLabel("Start focus")
            .accessibilityHint("Starts a focus block")
    }

    private func pillShell(fill: Color, outline: Color?, @ViewBuilder content: () -> some View) -> some View {
        HStack(spacing: 8) { content() }
            .padding(.leading, state.corner.isLeading ? Metrics.tuck + 12 : 16)
            .padding(.trailing, state.corner.isLeading ? 16 : Metrics.tuck + 12)
            .frame(height: Metrics.pillHeight)
            .background {
                // Outline drawn as two fills: a stroked capsule leaves a seam where its path starts.
                ZStack {
                    if let outline { Capsule().fill(outline) }
                    Capsule().inset(by: outline == nil ? 0 : 2).fill(fill)
                }
            }
            .contentShape(Capsule())
    }

    private func controlButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 28, height: 28)
                .foregroundStyle(palette.ink)
                .background(palette.surface, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var pillTransition: AnyTransition {
        .move(edge: state.corner.isLeading ? .leading : .trailing).combined(with: .opacity)
    }

    // MARK: Interaction

    private var drag: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { _ in
                isDragging = true
                onDragChanged()
            }
            .onEnded { _ in
                onDragEnded()
                // A drag ends with a mouse-up that must not also count as a click.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { isDragging = false }
            }
    }

    /// One flash per completed block: full Done-green ring and a checkmark, then
    /// back to whatever the phase is. Under Reduce Motion the swap is instant but
    /// still held long enough to read.
    private func celebrate() {
        if reduceMotion {
            state.isCelebrating = true
        } else {
            withAnimation(PomodoroMotion.celebrate) { state.isCelebrating = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Metrics.celebrationSeconds) {
            if reduceMotion {
                state.isCelebrating = false
            } else {
                withAnimation(PomodoroMotion.orbSlide) { state.isCelebrating = false }
            }
        }
    }

    private func handleOrbTap() {
        guard !isDragging else { return }
        if presence == .active {
            onOpenTimer()
        } else {
            appModel.quickStart()
        }
    }

    private func startIfStill() {
        guard !isDragging else { return }
        appModel.quickStart()
    }

    static func idleText(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) min" : "\(minutes / 60) hr \(minutes % 60) min"
    }
}
