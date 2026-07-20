import AppKit
import OSLog
import UserNotifications

enum AlertKind: String, CaseIterable {
    case focusEnded
    case breakEnded
    case cycleComplete
}

struct AlertCopy {
    let title: String
    let body: String
}

extension AlertKind {
    var copy: AlertCopy {
        switch self {
        case .focusEnded:
            return AlertCopy(title: "Focus block done", body: "Solid work. Step away and recharge.")
        case .breakEnded:
            return AlertCopy(title: "Break's over", body: "Let's go. Next focus block starts now.")
        case .cycleComplete:
            return AlertCopy(title: "Cycle complete", body: "Full cycle done. That's real momentum, keep it rolling.")
        }
    }

    var soundName: NSSound.Name {
        switch self {
        case .focusEnded:
            return NSSound.Name("Glass")
        case .breakEnded:
            return NSSound.Name("Pop")
        case .cycleComplete:
            return NSSound.Name("Hero")
        }
    }

    var peonEvent: PeonEvent {
        switch self {
        case .focusEnded, .cycleComplete:
            return .focusCompleted
        case .breakEnded:
            return .backToWork
        }
    }

    var settingsTitle: String {
        switch self {
        case .focusEnded:
            return "Focus block ends"
        case .breakEnded:
            return "Break ends"
        case .cycleComplete:
            return "Cycle completes"
        }
    }
}

protocol UserNotificationSending {
    func requestNotificationAuthorization(completionHandler: @escaping (Bool) -> Void)
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?)
    func fetchAuthorizationStatus(completionHandler: @escaping (UNAuthorizationStatus) -> Void)
}

extension UNUserNotificationCenter: UserNotificationSending {
    func requestNotificationAuthorization(completionHandler: @escaping (Bool) -> Void) {
        requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                Logger(subsystem: "com.wcoetzee.pomodoro.app", category: "alerts")
                    .error("Notification authorization failed: \(error.localizedDescription)")
            }
            DispatchQueue.main.async { completionHandler(granted) }
        }
    }

    func fetchAuthorizationStatus(completionHandler: @escaping (UNAuthorizationStatus) -> Void) {
        getNotificationSettings { settings in
            let status = settings.authorizationStatus
            DispatchQueue.main.async { completionHandler(status) }
        }
    }
}

protocol SystemSoundPlaying {
    func play(_ soundName: NSSound.Name)
}

struct DefaultSoundPlayer: SystemSoundPlaying {
    func play(_ soundName: NSSound.Name) {
        NSSound(named: soundName)?.play()
    }
}

@MainActor
final class AlertCenter: ObservableObject {
    @Published private(set) var authorizationDenied = false
    private var didRequestAuthorization = false

    private let preferences: Preferences
    private let notificationCenter: UserNotificationSending
    private let soundPlayer: SystemSoundPlaying
    private let peonSoundResolver: (PeonEvent) -> URL?
    private let peonSoundOverride: ((URL) -> Void)?
    // NSSound.play() is asynchronous; without retention the sound deallocates mid-playback.
    private var retainedPeonSound: NSSound?

    init(
        preferences: Preferences,
        notificationCenter: UserNotificationSending = UNUserNotificationCenter.current(),
        soundPlayer: SystemSoundPlaying = DefaultSoundPlayer(),
        peonSoundResolver: @escaping (PeonEvent) -> URL? = { PeonSoundPack().url(for: $0) },
        peonSoundOverride: ((URL) -> Void)? = nil
    ) {
        self.preferences = preferences
        self.notificationCenter = notificationCenter
        self.soundPlayer = soundPlayer
        self.peonSoundResolver = peonSoundResolver
        self.peonSoundOverride = peonSoundOverride
    }

    func requestAuthorizationIfNeeded() {
        guard !didRequestAuthorization else { return }
        // Mid-onboarding the pre-prompt owns the authorization moment; the flag
        // is set on both complete and skip, so this only defers, never strands.
        guard preferences.hasCompletedOnboarding else { return }
        let policy = preferences.alertPolicy
        guard policy.masterEnabled, policy.anyBannerEnabled else { return }
        didRequestAuthorization = true
        notificationCenter.requestNotificationAuthorization { [weak self] granted in
            self?.authorizationDenied = !granted
        }
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        didRequestAuthorization = true
        notificationCenter.requestNotificationAuthorization { [weak self] granted in
            self?.authorizationDenied = !granted
            completion(granted)
        }
    }

    func suppressAutomaticAuthorizationRequest() {
        didRequestAuthorization = true
    }

    func refreshAuthorizationStatus() {
        notificationCenter.fetchAuthorizationStatus { [weak self] status in
            self?.authorizationDenied = (status == .denied)
        }
    }

    func fire(_ kind: AlertKind) {
        let policy = preferences.alertPolicy
        if policy.bannerEnabled(for: kind) {
            postBanner(for: kind)
        }
        guard policy.soundEnabled(for: kind) else { return }
        if preferences.peonModeEnabled, let url = peonSoundResolver(kind.peonEvent) {
            playPeon(url)
        } else {
            soundPlayer.play(kind.soundName)
        }
    }

    func firePeon(_ event: PeonEvent) {
        guard preferences.peonModeEnabled, let url = peonSoundResolver(event) else { return }
        playPeon(url)
    }

    private func playPeon(_ url: URL) {
        if let peonSoundOverride {
            peonSoundOverride(url)
            return
        }
        let sound = NSSound(contentsOf: url, byReference: true)
        retainedPeonSound = sound
        sound?.play()
    }

    private func postBanner(for kind: AlertKind) {
        let content = UNMutableNotificationContent()
        content.title = kind.copy.title
        content.body = kind.copy.body
        content.sound = nil

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        notificationCenter.add(request) { [weak self] error in
            guard error != nil else { return }
            Task { @MainActor in self?.refreshAuthorizationStatus() }
        }
    }
}
