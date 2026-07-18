import Foundation

enum SurfaceMode: String, Codable {
    case popover
    case pinnedPanel
    case miniCard
}

@MainActor
final class Preferences: ObservableObject {
    private enum Key {
        static let surfaceMode = "surfaceMode"
        static let showCountdownInMenuBar = "showCountdownInMenuBar"
        static let launchAtLogin = "launchAtLogin"
        static let cyclePreset = "cyclePreset"
        static let peonModeEnabled = "peonModeEnabled"
        static let alertPolicy = "alertPolicy"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"

        // Superseded by alertPolicy; kept only so existing installs migrate once.
        static let legacyFocusEndSoundEnabled = "focusEndSoundEnabled"
        static let legacyBreakEndSoundEnabled = "breakEndSoundEnabled"
        static let legacyCycleCompleteSoundEnabled = "cycleCompleteSoundEnabled"
        static let legacyNotificationsEnabled = "notificationsEnabled"
        static let legacyFocusEndedBannerEnabled = "focusEndedBannerEnabled"
        static let legacyBreakEndedBannerEnabled = "breakEndedBannerEnabled"
        static let legacyCycleCompleteBannerEnabled = "cycleCompleteBannerEnabled"
    }

    private let defaults: UserDefaults
    private let loginItemRegistrar: LoginItemRegistering

    @Published var surfaceMode: SurfaceMode = .popover {
        didSet { defaults.set(surfaceMode.rawValue, forKey: Key.surfaceMode) }
    }
    @Published var showCountdownInMenuBar: Bool = true {
        didSet { defaults.set(showCountdownInMenuBar, forKey: Key.showCountdownInMenuBar) }
    }
    @Published var alertPolicy: AlertPolicy = .standard {
        didSet { persistAlertPolicy() }
    }
    @Published var launchAtLogin: Bool = false {
        didSet {
            defaults.set(launchAtLogin, forKey: Key.launchAtLogin)
            syncLoginItemRegistration()
        }
    }
    @Published var cyclePreset: CyclePreset = .standard {
        didSet { persistCyclePreset() }
    }
    @Published var peonModeEnabled: Bool = false {
        didSet { defaults.set(peonModeEnabled, forKey: Key.peonModeEnabled) }
    }
    @Published var hasCompletedOnboarding: Bool = false {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    init(defaults: UserDefaults = .standard, loginItemRegistrar: LoginItemRegistering = SMAppServiceLoginItemRegistrar()) {
        self.defaults = defaults
        self.loginItemRegistrar = loginItemRegistrar

        if let storedSurfaceMode = defaults.string(forKey: Key.surfaceMode),
           let restoredMode = SurfaceMode(rawValue: storedSurfaceMode) {
            surfaceMode = restoredMode
        }
        showCountdownInMenuBar = Self.restoredBool(defaults, Key.showCountdownInMenuBar, showCountdownInMenuBar)
        alertPolicy = Self.restoredAlertPolicy(defaults, alertPolicy)
        launchAtLogin = Self.restoredBool(defaults, Key.launchAtLogin, launchAtLogin)
        cyclePreset = Self.restoredCyclePreset(defaults, cyclePreset)
        peonModeEnabled = Self.restoredBool(defaults, Key.peonModeEnabled, peonModeEnabled)
        hasCompletedOnboarding = Self.restoredBool(defaults, Key.hasCompletedOnboarding, hasCompletedOnboarding)
    }

    private static func restoredBool(_ defaults: UserDefaults, _ key: String, _ fallback: Bool) -> Bool {
        defaults.object(forKey: key) != nil ? defaults.bool(forKey: key) : fallback
    }

    private static func restoredCyclePreset(_ defaults: UserDefaults, _ fallback: CyclePreset) -> CyclePreset {
        guard let data = defaults.data(forKey: Key.cyclePreset),
              let restored = try? JSONDecoder().decode(CyclePreset.self, from: data) else {
            return fallback
        }
        return restored
    }

    private func persistCyclePreset() {
        guard let data = try? JSONEncoder().encode(cyclePreset) else { return }
        defaults.set(data, forKey: Key.cyclePreset)
    }

    private static func restoredAlertPolicy(_ defaults: UserDefaults, _ fallback: AlertPolicy) -> AlertPolicy {
        if let data = defaults.data(forKey: Key.alertPolicy),
           let restored = try? JSONDecoder().decode(AlertPolicy.self, from: data) {
            return restored
        }
        return migratedLegacyAlertPolicy(defaults) ?? fallback
    }

    private static func migratedLegacyAlertPolicy(_ defaults: UserDefaults) -> AlertPolicy? {
        let legacyKeys = [
            Key.legacyFocusEndSoundEnabled,
            Key.legacyBreakEndSoundEnabled,
            Key.legacyCycleCompleteSoundEnabled,
            Key.legacyNotificationsEnabled,
            Key.legacyFocusEndedBannerEnabled,
            Key.legacyBreakEndedBannerEnabled,
            Key.legacyCycleCompleteBannerEnabled
        ]
        guard legacyKeys.contains(where: { defaults.object(forKey: $0) != nil }) else { return nil }

        var policy = AlertPolicy.standard
        policy.masterEnabled = restoredBool(defaults, Key.legacyNotificationsEnabled, policy.masterEnabled)
        policy.setBannerEnabled(restoredBool(defaults, Key.legacyFocusEndedBannerEnabled, true), for: .focusEnded)
        policy.setBannerEnabled(restoredBool(defaults, Key.legacyBreakEndedBannerEnabled, true), for: .breakEnded)
        policy.setBannerEnabled(restoredBool(defaults, Key.legacyCycleCompleteBannerEnabled, true), for: .cycleComplete)
        policy.setSoundEnabled(restoredBool(defaults, Key.legacyFocusEndSoundEnabled, true), for: .focusEnded)
        policy.setSoundEnabled(restoredBool(defaults, Key.legacyBreakEndSoundEnabled, true), for: .breakEnded)
        policy.setSoundEnabled(restoredBool(defaults, Key.legacyCycleCompleteSoundEnabled, true), for: .cycleComplete)
        return policy
    }

    private func persistAlertPolicy() {
        guard let data = try? JSONEncoder().encode(alertPolicy) else { return }
        defaults.set(data, forKey: Key.alertPolicy)
    }

    private func syncLoginItemRegistration() {
        do {
            if launchAtLogin {
                try loginItemRegistrar.register()
            } else {
                try loginItemRegistrar.unregister()
            }
        } catch {
            // SMAppService can throw when the login item state already matches
            // the request, or when running outside a signed .app bundle (e.g. tests).
        }
    }
}
