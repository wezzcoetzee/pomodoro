import SwiftUI

@main
struct PomodoroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(preferences: appDelegate.preferences)
                .environmentObject(appDelegate.model)
        }
    }
}
