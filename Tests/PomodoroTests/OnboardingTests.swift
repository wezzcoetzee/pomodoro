import XCTest
@testable import Pomodoro

@MainActor
final class OnboardingTests: XCTestCase {
    private func makeSuite() -> UserDefaults {
        let suiteName = "OnboardingTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    private func makeAlertCenter(defaults: UserDefaults) -> (AlertCenter, FakeNotificationCenter, Preferences) {
        let preferences = Preferences(defaults: defaults)
        let notificationCenter = FakeNotificationCenter()
        let alertCenter = AlertCenter(preferences: preferences, notificationCenter: notificationCenter)
        return (alertCenter, notificationCenter, preferences)
    }

    func testHasCompletedOnboardingDefaultsToFalse() {
        let preferences = Preferences(defaults: makeSuite())

        XCTAssertFalse(preferences.hasCompletedOnboarding)
    }

    func testHasCompletedOnboardingRoundTripsThroughSharedSuite() {
        let defaults = makeSuite()
        let original = Preferences(defaults: defaults)

        original.hasCompletedOnboarding = true

        let restored = Preferences(defaults: defaults)
        XCTAssertTrue(restored.hasCompletedOnboarding)
    }

    func testHasCompletedOnboardingFalseLeavesOnboardingUnseen() {
        let preferences = Preferences(defaults: makeSuite())

        XCTAssertFalse(preferences.hasCompletedOnboarding)
    }

    func testRequestAuthorizationReportsGrantedThroughCompletion() {
        let (alertCenter, notificationCenter, _) = makeAlertCenter(defaults: makeSuite())
        notificationCenter.grantAuthorization = true
        var reportedGranted: Bool?

        alertCenter.requestAuthorization { granted in reportedGranted = granted }

        XCTAssertEqual(reportedGranted, true)
        XCTAssertFalse(alertCenter.authorizationDenied)
    }

    func testRequestAuthorizationReportsDeniedThroughCompletion() {
        let (alertCenter, notificationCenter, _) = makeAlertCenter(defaults: makeSuite())
        notificationCenter.grantAuthorization = false
        var reportedGranted: Bool?

        alertCenter.requestAuthorization { granted in reportedGranted = granted }

        XCTAssertEqual(reportedGranted, false)
        XCTAssertTrue(alertCenter.authorizationDenied)
    }

    func testRequestAuthorizationSuppressesSubsequentLazyRequest() {
        let (alertCenter, notificationCenter, _) = makeAlertCenter(defaults: makeSuite())

        alertCenter.requestAuthorization { _ in }
        alertCenter.requestAuthorizationIfNeeded()

        XCTAssertEqual(notificationCenter.authorizationRequestCount, 1)
    }

    func testSuppressAutomaticAuthorizationRequestBlocksLazyPath() {
        let (alertCenter, notificationCenter, _) = makeAlertCenter(defaults: makeSuite())

        alertCenter.suppressAutomaticAuthorizationRequest()
        alertCenter.requestAuthorizationIfNeeded()

        XCTAssertFalse(notificationCenter.authorizationRequested)
    }

    func testSkippingBeforeNotificationsStepLeavesLazyFallbackIntact() throws {
        let defaults = makeSuite()
        let (alertCenter, notificationCenter, preferences) = makeAlertCenter(defaults: defaults)
        preferences.hasCompletedOnboarding = true
        let engine = TimerEngine(preset: .standard)
        let store = try SessionStore(inMemory: true)
        let model = AppModel(engine: engine, store: store, preferences: preferences)
        model.alertCenter = alertCenter

        XCTAssertFalse(notificationCenter.authorizationRequested)

        model.startSession(name: "First block", ticket: nil)

        XCTAssertTrue(notificationCenter.authorizationRequested)
    }

    func testSessionStartDuringOnboardingDoesNotTriggerAuthorizationDialog() throws {
        let defaults = makeSuite()
        let (alertCenter, notificationCenter, preferences) = makeAlertCenter(defaults: defaults)
        XCTAssertFalse(preferences.hasCompletedOnboarding)
        let engine = TimerEngine(preset: .standard)
        let store = try SessionStore(inMemory: true)
        let model = AppModel(engine: engine, store: store, preferences: preferences)
        model.alertCenter = alertCenter

        model.startSession(name: "Eager block", ticket: nil)

        XCTAssertFalse(notificationCenter.authorizationRequested)
    }
}
