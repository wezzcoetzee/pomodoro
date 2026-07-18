import XCTest
import UserNotifications
@testable import Pomodoro

final class FakeNotificationCenter: UserNotificationSending {
    private(set) var addedRequests: [UNNotificationRequest] = []
    private(set) var authorizationRequested = false
    private(set) var authorizationRequestCount = 0
    var grantAuthorization = true
    var authorizationStatus: UNAuthorizationStatus = .authorized

    func requestNotificationAuthorization(completionHandler: @escaping (Bool) -> Void) {
        authorizationRequested = true
        authorizationRequestCount += 1
        completionHandler(grantAuthorization)
    }

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: (@Sendable (Error?) -> Void)?) {
        addedRequests.append(request)
        completionHandler?(nil)
    }

    func fetchAuthorizationStatus(completionHandler: @escaping (UNAuthorizationStatus) -> Void) {
        completionHandler(authorizationStatus)
    }
}

@MainActor
final class FakeSoundPlayer: SystemSoundPlaying {
    private(set) var playedSoundNames: [NSSound.Name] = []

    func play(_ soundName: NSSound.Name) {
        playedSoundNames.append(soundName)
    }
}

@MainActor
final class AlertCenterTests: XCTestCase {
    private func makeAlertCenter() -> (AlertCenter, FakeNotificationCenter, FakeSoundPlayer, Preferences) {
        let suiteName = "AlertCenterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let preferences = Preferences(defaults: defaults)
        preferences.hasCompletedOnboarding = true
        let notificationCenter = FakeNotificationCenter()
        let soundPlayer = FakeSoundPlayer()
        let alertCenter = AlertCenter(
            preferences: preferences,
            notificationCenter: notificationCenter,
            soundPlayer: soundPlayer
        )
        return (alertCenter, notificationCenter, soundPlayer, preferences)
    }

    func testFireDoesNotCrashWithoutRealNotificationCenter() {
        let (alertCenter, notificationCenter, soundPlayer, _) = makeAlertCenter()
        alertCenter.fire(.focusEnded)
        XCTAssertEqual(notificationCenter.addedRequests.count, 1)
        XCTAssertEqual(soundPlayer.playedSoundNames.count, 1)
    }

    func testEachAlertKindHasDistinctCopy() {
        let kinds: [AlertKind] = [.focusEnded, .breakEnded, .cycleComplete]
        let titles = Set(kinds.map { $0.copy.title })
        let bodies = Set(kinds.map { $0.copy.body })
        XCTAssertEqual(titles.count, kinds.count)
        XCTAssertEqual(bodies.count, kinds.count)
    }

    func testFocusEndedAndBreakEndedUseDistinctSounds() {
        XCTAssertNotEqual(AlertKind.focusEnded.soundName, AlertKind.breakEnded.soundName)
    }

    func testAllThreeKindsUseDistinctSounds() {
        let names: Set<NSSound.Name> = [AlertKind.focusEnded.soundName, AlertKind.breakEnded.soundName, AlertKind.cycleComplete.soundName]
        XCTAssertEqual(names.count, 3)
    }

    func testBannerSuppressedWhenMasterNotificationsToggleOff() {
        let (alertCenter, notificationCenter, soundPlayer, preferences) = makeAlertCenter()
        preferences.alertPolicy.masterEnabled = false

        alertCenter.fire(.focusEnded)

        XCTAssertTrue(notificationCenter.addedRequests.isEmpty)
        XCTAssertEqual(soundPlayer.playedSoundNames.count, 1)
    }

    func testFocusEndedBannerIndependentlySuppressible() {
        let (alertCenter, notificationCenter, soundPlayer, preferences) = makeAlertCenter()
        preferences.alertPolicy.setBannerEnabled(false, for: .focusEnded)

        alertCenter.fire(.focusEnded)
        alertCenter.fire(.breakEnded)

        XCTAssertEqual(notificationCenter.addedRequests.count, 1)
        XCTAssertEqual(notificationCenter.addedRequests.first?.content.title, AlertKind.breakEnded.copy.title)
        XCTAssertEqual(soundPlayer.playedSoundNames.count, 2)
    }

    func testBreakEndedBannerIndependentlySuppressible() {
        let (alertCenter, notificationCenter, _, preferences) = makeAlertCenter()
        preferences.alertPolicy.setBannerEnabled(false, for: .breakEnded)

        alertCenter.fire(.focusEnded)
        alertCenter.fire(.breakEnded)

        XCTAssertEqual(notificationCenter.addedRequests.count, 1)
        XCTAssertEqual(notificationCenter.addedRequests.first?.content.title, AlertKind.focusEnded.copy.title)
    }

    func testCycleCompleteBannerIndependentlySuppressible() {
        let (alertCenter, notificationCenter, _, preferences) = makeAlertCenter()
        preferences.alertPolicy.setBannerEnabled(false, for: .cycleComplete)

        alertCenter.fire(.cycleComplete)
        alertCenter.fire(.breakEnded)

        XCTAssertEqual(notificationCenter.addedRequests.count, 1)
        XCTAssertEqual(notificationCenter.addedRequests.first?.content.title, AlertKind.breakEnded.copy.title)
    }

    func testFocusEndSoundIndependentlySuppressible() {
        let (alertCenter, notificationCenter, soundPlayer, preferences) = makeAlertCenter()
        preferences.alertPolicy.setSoundEnabled(false, for: .focusEnded)

        alertCenter.fire(.focusEnded)
        alertCenter.fire(.breakEnded)

        XCTAssertEqual(soundPlayer.playedSoundNames, [AlertKind.breakEnded.soundName])
        XCTAssertEqual(notificationCenter.addedRequests.count, 2)
    }

    func testBreakEndSoundIndependentlySuppressible() {
        let (alertCenter, _, soundPlayer, preferences) = makeAlertCenter()
        preferences.alertPolicy.setSoundEnabled(false, for: .breakEnded)

        alertCenter.fire(.focusEnded)
        alertCenter.fire(.breakEnded)

        XCTAssertEqual(soundPlayer.playedSoundNames, [AlertKind.focusEnded.soundName])
    }

    func testCycleCompleteSoundIndependentlySuppressible() {
        let (alertCenter, _, soundPlayer, preferences) = makeAlertCenter()
        preferences.alertPolicy.setSoundEnabled(false, for: .cycleComplete)

        alertCenter.fire(.cycleComplete)
        alertCenter.fire(.breakEnded)

        XCTAssertEqual(soundPlayer.playedSoundNames, [AlertKind.breakEnded.soundName])
    }

    func testSoundAndBannerAreIndependentChannels() {
        let (alertCenter, notificationCenter, soundPlayer, preferences) = makeAlertCenter()
        preferences.alertPolicy.setSoundEnabled(false, for: .focusEnded)
        preferences.alertPolicy.setBannerEnabled(true, for: .focusEnded)

        alertCenter.fire(.focusEnded)

        XCTAssertEqual(notificationCenter.addedRequests.count, 1)
        XCTAssertTrue(soundPlayer.playedSoundNames.isEmpty)
    }

    func testAllChannelsSuppressedProducesNoSideEffects() {
        let (alertCenter, notificationCenter, soundPlayer, preferences) = makeAlertCenter()
        preferences.alertPolicy.masterEnabled = false
        preferences.alertPolicy.setSoundEnabled(false, for: .focusEnded)
        preferences.alertPolicy.setSoundEnabled(false, for: .breakEnded)
        preferences.alertPolicy.setSoundEnabled(false, for: .cycleComplete)

        alertCenter.fire(.focusEnded)
        alertCenter.fire(.breakEnded)
        alertCenter.fire(.cycleComplete)

        XCTAssertTrue(notificationCenter.addedRequests.isEmpty)
        XCTAssertTrue(soundPlayer.playedSoundNames.isEmpty)
    }

    func testDeniedAuthorizationCallbackSetsDeniedState() {
        let (alertCenter, notificationCenter, _, _) = makeAlertCenter()
        notificationCenter.grantAuthorization = false

        alertCenter.requestAuthorizationIfNeeded()

        XCTAssertTrue(notificationCenter.authorizationRequested)
        XCTAssertTrue(alertCenter.authorizationDenied)
    }

    func testGrantedAuthorizationLeavesDeniedStateFalse() {
        let (alertCenter, notificationCenter, _, _) = makeAlertCenter()
        notificationCenter.grantAuthorization = true

        alertCenter.requestAuthorizationIfNeeded()

        XCTAssertFalse(alertCenter.authorizationDenied)
    }

    func testRefreshPicksUpOutOfAppDenialAndRecovery() {
        let (alertCenter, notificationCenter, _, _) = makeAlertCenter()

        notificationCenter.authorizationStatus = .denied
        alertCenter.refreshAuthorizationStatus()
        XCTAssertTrue(alertCenter.authorizationDenied)

        notificationCenter.authorizationStatus = .authorized
        alertCenter.refreshAuthorizationStatus()
        XCTAssertFalse(alertCenter.authorizationDenied)
    }

    func testAuthorizationNotRequestedWhenNotificationsDisabled() {
        let (alertCenter, notificationCenter, _, preferences) = makeAlertCenter()
        preferences.alertPolicy.masterEnabled = false

        alertCenter.requestAuthorizationIfNeeded()

        XCTAssertFalse(notificationCenter.authorizationRequested)
    }

    func testAuthorizationNotRequestedWhenNoBannerEnabled() {
        let (alertCenter, notificationCenter, _, preferences) = makeAlertCenter()
        preferences.alertPolicy.setBannerEnabled(false, for: .focusEnded)
        preferences.alertPolicy.setBannerEnabled(false, for: .breakEnded)
        preferences.alertPolicy.setBannerEnabled(false, for: .cycleComplete)

        alertCenter.requestAuthorizationIfNeeded()

        XCTAssertFalse(notificationCenter.authorizationRequested)
    }

    func testAuthorizationRequestedOncePerRun() {
        let (alertCenter, notificationCenter, _, _) = makeAlertCenter()

        alertCenter.requestAuthorizationIfNeeded()
        alertCenter.requestAuthorizationIfNeeded()

        XCTAssertEqual(notificationCenter.authorizationRequestCount, 1)
    }

    func testAuthorizationRequestedOnFirstSessionStartNotAtLaunch() throws {
        let suiteName = "AlertCenterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let preferences = Preferences(defaults: defaults)
        preferences.hasCompletedOnboarding = true
        let notificationCenter = FakeNotificationCenter()
        let alertCenter = AlertCenter(preferences: preferences, notificationCenter: notificationCenter)

        let engine = TimerEngine(preset: .standard)
        let store = try SessionStore(inMemory: true)
        let model = AppModel(engine: engine, store: store, preferences: preferences)
        model.alertCenter = alertCenter

        XCTAssertFalse(notificationCenter.authorizationRequested)

        model.startSession(name: "First block", ticket: nil)

        XCTAssertTrue(notificationCenter.authorizationRequested)
    }

    private func makePeonAlertCenter(
        resolvedURL: URL?
    ) -> (AlertCenter, FakeSoundPlayer, Preferences, () -> [URL]) {
        let suiteName = "AlertCenterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let preferences = Preferences(defaults: defaults)
        let soundPlayer = FakeSoundPlayer()
        var playedPeonURLs: [URL] = []
        let alertCenter = AlertCenter(
            preferences: preferences,
            notificationCenter: FakeNotificationCenter(),
            soundPlayer: soundPlayer,
            peonSoundResolver: { _ in resolvedURL },
            peonSoundOverride: { playedPeonURLs.append($0) }
        )
        return (alertCenter, soundPlayer, preferences, { playedPeonURLs })
    }

    func testPeonSoundReplacesSystemSoundWhenEnabled() {
        let url = URL(fileURLWithPath: "/tmp/jobs-done.wav")
        let (alertCenter, soundPlayer, preferences, playedPeonURLs) = makePeonAlertCenter(resolvedURL: url)
        preferences.peonModeEnabled = true

        alertCenter.fire(.focusEnded)

        XCTAssertEqual(playedPeonURLs(), [url])
        XCTAssertTrue(soundPlayer.playedSoundNames.isEmpty)
    }

    func testSystemSoundUsedWhenPeonModeDisabled() {
        let url = URL(fileURLWithPath: "/tmp/jobs-done.wav")
        let (alertCenter, soundPlayer, _, playedPeonURLs) = makePeonAlertCenter(resolvedURL: url)

        alertCenter.fire(.focusEnded)

        XCTAssertTrue(playedPeonURLs().isEmpty)
        XCTAssertEqual(soundPlayer.playedSoundNames.count, 1)
    }

    func testSystemSoundFallbackWhenNoPeonFileMatches() {
        let (alertCenter, soundPlayer, preferences, playedPeonURLs) = makePeonAlertCenter(resolvedURL: nil)
        preferences.peonModeEnabled = true

        alertCenter.fire(.focusEnded)

        XCTAssertTrue(playedPeonURLs().isEmpty)
        XCTAssertEqual(soundPlayer.playedSoundNames.count, 1)
    }

    func testFirePeonRespectsToggleAndSoundSuppression() {
        let url = URL(fileURLWithPath: "/tmp/me-busy.wav")
        let (alertCenter, soundPlayer, preferences, playedPeonURLs) = makePeonAlertCenter(resolvedURL: url)

        alertCenter.firePeon(.paused)
        XCTAssertTrue(playedPeonURLs().isEmpty)

        preferences.peonModeEnabled = true
        alertCenter.firePeon(.paused)
        XCTAssertEqual(playedPeonURLs(), [url])
        XCTAssertTrue(soundPlayer.playedSoundNames.isEmpty)
    }

    func testPeonSoundStillGatedByPerEventSoundToggle() {
        let url = URL(fileURLWithPath: "/tmp/jobs-done.wav")
        let (alertCenter, soundPlayer, preferences, playedPeonURLs) = makePeonAlertCenter(resolvedURL: url)
        preferences.peonModeEnabled = true
        preferences.alertPolicy.setSoundEnabled(false, for: .focusEnded)

        alertCenter.fire(.focusEnded)

        XCTAssertTrue(playedPeonURLs().isEmpty)
        XCTAssertTrue(soundPlayer.playedSoundNames.isEmpty)
    }
}
