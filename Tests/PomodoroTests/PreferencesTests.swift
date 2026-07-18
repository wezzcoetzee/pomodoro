import XCTest
@testable import Pomodoro

@MainActor
final class PreferencesTests: XCTestCase {
    private func makeSuite() -> UserDefaults {
        let suiteName = "PreferencesTests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suiteName)!
    }

    func testDefaultsMatchDocumentedValues() {
        let preferences = Preferences(defaults: makeSuite())

        XCTAssertEqual(preferences.surfaceMode, .popover)
        XCTAssertTrue(preferences.showCountdownInMenuBar)
        XCTAssertEqual(preferences.alertPolicy, .standard)
        XCTAssertFalse(preferences.launchAtLogin)
    }

    func testFullRoundTripThroughSharedSuite() {
        let defaults = makeSuite()
        let original = Preferences(defaults: defaults)

        original.surfaceMode = .pinnedPanel
        original.showCountdownInMenuBar = false
        original.alertPolicy.masterEnabled = false
        original.alertPolicy.setBannerEnabled(false, for: .focusEnded)
        original.alertPolicy.setBannerEnabled(false, for: .breakEnded)
        original.alertPolicy.setBannerEnabled(false, for: .cycleComplete)
        original.alertPolicy.setSoundEnabled(false, for: .focusEnded)
        original.alertPolicy.setSoundEnabled(false, for: .breakEnded)
        original.alertPolicy.setSoundEnabled(false, for: .cycleComplete)
        original.launchAtLogin = true

        let restored = Preferences(defaults: defaults)

        XCTAssertEqual(restored.surfaceMode, .pinnedPanel)
        XCTAssertFalse(restored.showCountdownInMenuBar)
        XCTAssertFalse(restored.alertPolicy.masterEnabled)
        XCTAssertFalse(restored.alertPolicy.rule(for: .focusEnded).bannerEnabled)
        XCTAssertFalse(restored.alertPolicy.rule(for: .breakEnded).bannerEnabled)
        XCTAssertFalse(restored.alertPolicy.rule(for: .cycleComplete).bannerEnabled)
        XCTAssertFalse(restored.alertPolicy.rule(for: .focusEnded).soundEnabled)
        XCTAssertFalse(restored.alertPolicy.rule(for: .breakEnded).soundEnabled)
        XCTAssertFalse(restored.alertPolicy.rule(for: .cycleComplete).soundEnabled)
        XCTAssertTrue(restored.launchAtLogin)
    }

    func testPartialUpdateRoundTripsIndependently() {
        let defaults = makeSuite()
        let original = Preferences(defaults: defaults)

        original.alertPolicy.setSoundEnabled(false, for: .focusEnded)

        let restored = Preferences(defaults: defaults)

        XCTAssertFalse(restored.alertPolicy.rule(for: .focusEnded).soundEnabled)
        XCTAssertTrue(restored.alertPolicy.rule(for: .breakEnded).soundEnabled)
        XCTAssertTrue(restored.alertPolicy.masterEnabled)
    }

    func testSeparateSuitesDoNotLeakState() {
        let preferencesA = Preferences(defaults: makeSuite())
        let preferencesB = Preferences(defaults: makeSuite())

        preferencesA.alertPolicy.masterEnabled = false

        XCTAssertFalse(preferencesA.alertPolicy.masterEnabled)
        XCTAssertTrue(preferencesB.alertPolicy.masterEnabled)
    }

    func testLegacyBooleanKeysMigrateIntoAlertPolicy() {
        let defaults = makeSuite()
        defaults.set(false, forKey: "focusEndSoundEnabled")
        defaults.set(true, forKey: "breakEndSoundEnabled")
        defaults.set(true, forKey: "cycleCompleteSoundEnabled")
        defaults.set(false, forKey: "notificationsEnabled")
        defaults.set(true, forKey: "focusEndedBannerEnabled")
        defaults.set(false, forKey: "breakEndedBannerEnabled")
        defaults.set(true, forKey: "cycleCompleteBannerEnabled")

        let migrated = Preferences(defaults: defaults)

        XCTAssertFalse(migrated.alertPolicy.masterEnabled)
        XCTAssertFalse(migrated.alertPolicy.rule(for: .focusEnded).soundEnabled)
        XCTAssertTrue(migrated.alertPolicy.rule(for: .breakEnded).soundEnabled)
        XCTAssertTrue(migrated.alertPolicy.rule(for: .cycleComplete).soundEnabled)
        XCTAssertTrue(migrated.alertPolicy.rule(for: .focusEnded).bannerEnabled)
        XCTAssertFalse(migrated.alertPolicy.rule(for: .breakEnded).bannerEnabled)
        XCTAssertTrue(migrated.alertPolicy.rule(for: .cycleComplete).bannerEnabled)
    }

    func testAlertPolicyTakesPrecedenceOverLegacyKeysOnceMigrated() {
        let defaults = makeSuite()
        defaults.set(false, forKey: "notificationsEnabled")
        let migrated = Preferences(defaults: defaults)
        XCTAssertFalse(migrated.alertPolicy.masterEnabled)

        migrated.alertPolicy.masterEnabled = true
        let restored = Preferences(defaults: defaults)

        XCTAssertTrue(restored.alertPolicy.masterEnabled)
    }
}
