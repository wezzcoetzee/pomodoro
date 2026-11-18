import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section("Cycle") {
                Stepper(
                    "Focus: \(preferences.cyclePreset.focusSeconds / 60) min",
                    value: minutesBinding(\.focusSeconds),
                    in: 1...120
                )
                Stepper(
                    "Short break: \(preferences.cyclePreset.shortBreakSeconds / 60) min",
                    value: minutesBinding(\.shortBreakSeconds),
                    in: 1...60
                )
                Stepper(
                    "Long break: \(preferences.cyclePreset.longBreakSeconds / 60) min",
                    value: minutesBinding(\.longBreakSeconds),
                    in: 1...120
                )
                Stepper(
                    "Blocks per long break: \(preferences.cyclePreset.blocksPerLongBreak)",
                    value: intBinding(\.blocksPerLongBreak),
                    in: 1...12
                )
                Toggle("Auto-advance to next phase", isOn: boolBinding(\.autoAdvance))
            }

            Section("Alerts") {
                Toggle("Notifications enabled", isOn: masterAlertBinding())
                if let alertCenter = model.alertCenter {
                    NotificationAuthorizationWarning(preferences: preferences, alertCenter: alertCenter)
                }
                ForEach(AlertKind.allCases, id: \.self) { kind in
                    alertRow(
                        title: kind.settingsTitle,
                        banner: bannerBinding(for: kind),
                        sound: soundBinding(for: kind)
                    )
                }
            }

            Section("Surface") {
                Picker("Timer surface", selection: $preferences.surfaceMode) {
                    ForEach(SurfaceMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
                Text(preferences.surfaceMode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Show countdown in menu bar", isOn: $preferences.showCountdownInMenuBar)
            }

            Section("General") {
                Toggle("Launch at login", isOn: $preferences.launchAtLogin)
                Button("Show welcome again") { model.onRequestReplayOnboarding?() }
            }

            Section("Easter eggs") {
                Toggle("Peon mode", isOn: $preferences.peonModeEnabled)
                Text(peonModeCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Open sounds folder") {
                    openPeonSoundsFolder()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 420)
        .onAppear { model.alertCenter?.refreshAuthorizationStatus() }
    }

    private var peonModeCaption: String {
        let pack = PeonSoundPack()
        let base =
            "Plays your own peon voice lines for session events. "
            + "Drop sound files (wav, mp3, m4a, aiff) named ready-to-work, work-work, "
            + "jobs-done, more-work, me-busy, or what into the sounds folder."
        if pack.isEmpty {
            return base + " No sounds found yet."
        }
        return base + " \(pack.soundCount) sound\(pack.soundCount == 1 ? "" : "s") loaded."
    }

    private func openPeonSoundsFolder() {
        let directory = PeonSoundPack.defaultDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }

    private func alertRow(title: String, banner: Binding<Bool>, sound: Binding<Bool>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Toggle("Banner", isOn: banner)
            Toggle("Sound", isOn: sound)
        }
    }

    private func minutesBinding(_ keyPath: WritableKeyPath<CyclePreset, Int>) -> Binding<Int> {
        Binding(
            get: { preferences.cyclePreset[keyPath: keyPath] / 60 },
            set: { preferences.cyclePreset[keyPath: keyPath] = $0 * 60 }
        )
    }

    private func intBinding(_ keyPath: WritableKeyPath<CyclePreset, Int>) -> Binding<Int> {
        Binding(
            get: { preferences.cyclePreset[keyPath: keyPath] },
            set: { preferences.cyclePreset[keyPath: keyPath] = $0 }
        )
    }

    private func boolBinding(_ keyPath: WritableKeyPath<CyclePreset, Bool>) -> Binding<Bool> {
        Binding(
            get: { preferences.cyclePreset[keyPath: keyPath] },
            set: { preferences.cyclePreset[keyPath: keyPath] = $0 }
        )
    }

    private func masterAlertBinding() -> Binding<Bool> {
        Binding(
            get: { preferences.alertPolicy.masterEnabled },
            set: { preferences.alertPolicy.masterEnabled = $0 }
        )
    }

    private func bannerBinding(for kind: AlertKind) -> Binding<Bool> {
        Binding(
            get: { preferences.alertPolicy.rule(for: kind).bannerEnabled },
            set: { preferences.alertPolicy.setBannerEnabled($0, for: kind) }
        )
    }

    private func soundBinding(for kind: AlertKind) -> Binding<Bool> {
        Binding(
            get: { preferences.alertPolicy.rule(for: kind).soundEnabled },
            set: { preferences.alertPolicy.setSoundEnabled($0, for: kind) }
        )
    }
}

private struct NotificationAuthorizationWarning: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var alertCenter: AlertCenter

    var body: some View {
        if alertCenter.authorizationDenied && preferences.alertPolicy.masterEnabled {
            VStack(alignment: .leading, spacing: 6) {
                Text("macOS notifications are turned off for Pomodoro, so banners will not appear. Sounds still play.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Open notification settings") {
                    openNotificationSettings()
                }
            }
        }
    }

    private func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
        NSWorkspace.shared.open(url)
    }
}

private extension SurfaceMode {
    var title: String {
        switch self {
        case .popover: return "Popover"
        case .pinnedPanel: return "Pinned panel"
        case .miniCard: return "Mini card"
        }
    }

    var description: String {
        switch self {
        case .popover: return "Opens from the menu bar icon and closes when you click away."
        case .pinnedPanel: return "Stays open in a floating panel you can leave on screen."
        case .miniCard: return "A small always-visible card docked to a screen corner."
        }
    }
}

extension SurfaceMode: CaseIterable {
    public static var allCases: [SurfaceMode] { [.popover, .pinnedPanel, .miniCard] }
}
