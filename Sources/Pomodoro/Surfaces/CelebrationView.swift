import AppKit
import SwiftUI

struct CelebrationView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var animateIn = false

    private let palette = PomodoroColors.palette(for: .focus)

    var body: some View {
        if let moment = appModel.celebration {
            burst(moment)
                .onAppear {
                    trigger(); announce(moment)
                }
                .task { await autoDismiss() }
        }
    }

    private func burst(_ moment: CelebrationMoment) -> some View {
        ZStack {
            palette.canvas
                .opacity(0.86)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(palette.line, lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: animateIn ? 1 : 0)
                        .stroke(PomodoroColors.streak, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "flame.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(PomodoroColors.streak)
                }
                .frame(width: 150, height: 150)

                Text("Block done")
                    .pomodoroText(.headline)
                    .foregroundStyle(palette.ink)

                HStack(spacing: 6) {
                    Text("\(moment.streak)")
                        .font(PomodoroFont.streakNumber)
                        .foregroundStyle(PomodoroColors.streak)
                    Text("day streak")
                        .pomodoroLabelStyle()
                        .foregroundStyle(palette.inkDim)
                }

                Text(blocksTodayLine(moment))
                    .pomodoroText(.body)
                    .foregroundStyle(palette.inkDim)
            }
            .scaleEffect(reduceMotion ? 1 : (animateIn ? 1 : 0.7))
            .opacity(reduceMotion ? 1 : (animateIn ? 1 : 0))
        }
        .contentShape(Rectangle())
        .onTapGesture { appModel.dismissCelebration() }
    }

    private func blocksTodayLine(_ moment: CelebrationMoment) -> String {
        moment.blocksToday == 1 ? "1 block today" : "\(moment.blocksToday) blocks today"
    }

    private func trigger() {
        if reduceMotion {
            animateIn = true
        } else {
            withAnimation(PomodoroMotion.celebrate) {
                animateIn = true
            }
        }
    }

    private func announce(_ moment: CelebrationMoment) {
        let message = "Block done. \(moment.streak) day streak. \(blocksTodayLine(moment))."
        AccessibilityNotification.Announcement(message).post()
    }

    private func autoDismiss() async {
        try? await Task.sleep(nanoseconds: dismissDelayNanoseconds)
        appModel.dismissCelebration()
    }

    private var dismissDelayNanoseconds: UInt64 {
        if NSWorkspace.shared.isVoiceOverEnabled { return 6_000_000_000 }
        return reduceMotion ? 2_000_000_000 : 1_400_000_000
    }
}
