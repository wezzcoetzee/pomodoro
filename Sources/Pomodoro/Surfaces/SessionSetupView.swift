import SwiftUI

struct SessionSetupView: View {
    @EnvironmentObject private var appModel: AppModel

    @State private var name: String = ""
    @State private var ticketInput: String = ""

    private let palette = PomodoroColors.palette(for: .focus)

    private var parsedTicket: TicketRef? {
        TicketRefParser.parse(ticketInput)
    }

    private var ticketInputIsInvalid: Bool {
        !ticketInput.trimmingCharacters(in: .whitespaces).isEmpty && parsedTicket == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New session")
                .pomodoroText(.headline)
                .foregroundStyle(palette.ink)

            field(label: "What are you focusing on?") {
                TextField("Name this block", text: $name)
                    .textFieldStyle(.plain)
                    .pomodoroText(.title)
                    .foregroundStyle(palette.ink)
                    .accessibilityLabel("What are you focusing on?")
            }

            field(label: "Ticket") {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Paste a Jira key or GitHub link", text: $ticketInput)
                        .textFieldStyle(.plain)
                        .pomodoroText(.body)
                        .foregroundStyle(palette.ink)
                        .accessibilityLabel("Ticket")
                    ticketFeedback
                }
            }

            presetSummary

            Button(action: start) {
                Text("Start focus")
                    .pomodoroText(.title)
                    .foregroundStyle(palette.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(palette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(28)
        .frame(width: SurfaceMetrics.mainWidth)
        .background(palette.canvas)
    }

    @ViewBuilder
    private var ticketFeedback: some View {
        if let ticket = parsedTicket {
            TicketBadge(ticket: ticket, palette: palette) {}
                .allowsHitTesting(false)
        } else if ticketInputIsInvalid {
            Text("Not a recognized ticket reference")
                .pomodoroText(.label)
                .foregroundStyle(palette.inkDim)
        }
    }

    private var presetSummary: some View {
        HStack(spacing: 6) {
            summaryChip("\(appModel.engine.preset.focusSeconds / 60)m focus")
            summaryChip("\(appModel.engine.preset.shortBreakSeconds / 60)m break")
            summaryChip("\(appModel.engine.preset.blocksPerLongBreak) per long")
        }
    }

    private func summaryChip(_ text: String) -> some View {
        Text(text)
            .pomodoroLabelStyle()
            .foregroundStyle(palette.inkDim)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(palette.surface, in: Capsule())
    }

    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .pomodoroLabelStyle()
                .foregroundStyle(palette.inkDim)
            content()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(ticketInputIsInvalid && label == "Ticket" ? palette.accentSoft : palette.line, lineWidth: 1)
                )
        }
    }

    private func start() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        appModel.startSession(name: trimmed, ticket: parsedTicket)
    }
}
