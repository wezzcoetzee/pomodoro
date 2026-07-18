import SwiftUI

struct SurfaceRootView: View {
    @EnvironmentObject private var appModel: AppModel
    var variant: TimerVariant = .full

    @State private var showingHistory: Bool

    init(variant: TimerVariant = .full, showHistory: Bool = false) {
        self.variant = variant
        _showingHistory = State(initialValue: showHistory)
    }

    var body: some View {
        switch variant {
        case .compact:
            TimerView(variant: .compact)
        case .full:
            fullSurface
        }
    }

    private var fullSurface: some View {
        ZStack {
            currentPane
                .overlay(alignment: .topTrailing) { historyToggle }
            if appModel.celebration != nil {
                CelebrationView()
            }
        }
    }

    @ViewBuilder
    private var currentPane: some View {
        if showingHistory {
            HistoryView()
        } else if appModel.showsSetup {
            SessionSetupView()
        } else {
            TimerView(variant: .full)
        }
    }

    private var historyToggle: some View {
        Button {
            showingHistory.toggle()
        } label: {
            Image(systemName: showingHistory ? "xmark" : "clock.arrow.circlepath")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PomodoroColors.palette(for: appModel.engine.phase).inkDim)
                .padding(8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(6)
        .accessibilityLabel(showingHistory ? "Close history" : "Show history")
    }
}
