import SwiftUI

struct OnboardingView: View {
    enum Step: CaseIterable {
        case welcome, loop, notifications, ready
    }

    @ObservedObject var preferences: Preferences
    let alertCenter: AlertCenter
    let onComplete: () -> Void
    let onSkip: () -> Void

    @State private var step: Step
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let palette = PomodoroColors.palette(for: .focus)

    static let windowSize = CGSize(width: 440, height: 400)

    init(
        preferences: Preferences,
        alertCenter: AlertCenter,
        onComplete: @escaping () -> Void,
        onSkip: @escaping () -> Void,
        initialStep: Step = .welcome
    ) {
        self.preferences = preferences
        self.alertCenter = alertCenter
        self.onComplete = onComplete
        self.onSkip = onSkip
        _step = State(initialValue: initialStep)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            Group {
                switch step {
                case .welcome: welcomeStep
                case .loop: loopStep
                case .notifications: notificationsStep
                case .ready: readyStep
                }
            }
            .transition(reduceMotion
                ? .identity
                : .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))

            Spacer(minLength: 0)

            progressRow
        }
        .padding(28)
        .frame(width: Self.windowSize.width, height: Self.windowSize.height, alignment: .top)
        .background(palette.canvas)
    }

    private var header: some View {
        HStack {
            Text(eyebrow)
                .pomodoroLabelStyle()
                .foregroundStyle(palette.inkDim)
            Spacer()
            Button(action: onSkip) {
                Text("Skip intro")
                    .pomodoroLabelStyle()
                    .foregroundStyle(palette.inkDim)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip intro")
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Let's build some momentum.")
                .pomodoroText(.headline)
                .foregroundStyle(palette.ink)
            Text("Pomodoro turns focused work into progress you can feel. Start a block, go heads-down, and watch your streak build. This takes about a minute.")
                .pomodoroText(.body)
                .foregroundStyle(palette.inkDim)
            primaryButton("Show me") { advance(to: .loop) }
        }
    }

    private var loopStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Focus, break, repeat.")
                .pomodoroText(.headline)
                .foregroundStyle(palette.ink)
            VStack(alignment: .leading, spacing: 12) {
                loopRow("Name what you're working on, then start a focus block.")
                loopRow("Work until it ends. Pomodoro tells you when to breathe.")
                loopRow("Take the break, then go again. Finished blocks stack into streaks.")
                loopRow("Your history sits one layer back, never in the way.")
            }
            primaryButton("Next") { advance(to: .notifications) }
        }
    }

    private var notificationsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Know the moment a block ends.")
                .pomodoroText(.headline)
                .foregroundStyle(palette.ink)
            Text("You'll be heads-down in another app when the timer runs out. A notification is how Pomodoro taps you on the shoulder, so a finished block never turns into an accidental overrun. It's the only permission the app ever asks for.")
                .pomodoroText(.body)
                .foregroundStyle(palette.inkDim)
            VStack(spacing: 12) {
                primaryButton("Enable notifications") {
                    alertCenter.requestAuthorization { _ in }
                    advance(to: .ready)
                }
                Button {
                    alertCenter.suppressAutomaticAuthorizationRequest()
                    advance(to: .ready)
                } label: {
                    Text("Not now")
                        .pomodoroText(.title)
                        .foregroundStyle(palette.inkDim)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Not now")
            }
        }
    }

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Pomodoro lives up here.")
                .pomodoroText(.headline)
                .foregroundStyle(palette.ink)
            Text("Look for the timer glyph in your menu bar, up top. Click it to start a block whenever you're ready. That's your whole command center.")
                .pomodoroText(.body)
                .foregroundStyle(palette.inkDim)
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Launch at login", isOn: $preferences.launchAtLogin)
                    .toggleStyle(.switch)
                    .tint(palette.accent)
                    .pomodoroText(.title)
                    .foregroundStyle(palette.ink)
                Text("Keep Pomodoro in your menu bar every time you log in. No Dock icon, no window in the way. Change it anytime in Settings.")
                    .pomodoroText(.body)
                    .foregroundStyle(palette.inkDim)
            }
            primaryButton("Start focusing", action: onComplete)
        }
    }

    private var progressRow: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases, id: \.self) { dot in
                Circle()
                    .fill(dot == step ? palette.accent : palette.line)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func loopRow(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(palette.accent)
                .frame(width: 5, height: 5)
            Text(text)
                .pomodoroText(.body)
                .foregroundStyle(palette.ink)
        }
    }

    private func primaryButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .pomodoroText(.title)
                .foregroundStyle(palette.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(palette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func advance(to next: Step) {
        withAnimation(reduceMotion ? nil : PomodoroMotion.ringFill) {
            step = next
        }
    }

    private var eyebrow: String {
        switch step {
        case .welcome: return "Welcome"
        case .loop: return "The loop"
        case .notifications: return "Notifications"
        case .ready: return "You're set"
        }
    }
}
