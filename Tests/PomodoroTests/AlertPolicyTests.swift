import XCTest
@testable import Pomodoro

final class AlertPolicyTests: XCTestCase {
    func testStandardPolicyEnablesEverything() {
        for kind in AlertKind.allCases {
            XCTAssertTrue(AlertPolicy.standard.bannerEnabled(for: kind))
            XCTAssertTrue(AlertPolicy.standard.soundEnabled(for: kind))
        }
    }

    func testMasterSwitchGatesBannersButNotSounds() {
        var policy = AlertPolicy.standard
        policy.masterEnabled = false

        for kind in AlertKind.allCases {
            XCTAssertFalse(policy.bannerEnabled(for: kind))
            XCTAssertTrue(policy.soundEnabled(for: kind))
        }
    }

    func testPerKindBannerAndSoundAreIndependentRows() {
        var policy = AlertPolicy.standard
        policy.setBannerEnabled(false, for: .breakEnded)
        policy.setSoundEnabled(false, for: .cycleComplete)

        XCTAssertTrue(policy.bannerEnabled(for: .focusEnded))
        XCTAssertFalse(policy.bannerEnabled(for: .breakEnded))
        XCTAssertTrue(policy.bannerEnabled(for: .cycleComplete))

        XCTAssertTrue(policy.soundEnabled(for: .focusEnded))
        XCTAssertTrue(policy.soundEnabled(for: .breakEnded))
        XCTAssertFalse(policy.soundEnabled(for: .cycleComplete))
    }

    func testAnyBannerEnabledReflectsAllRows() {
        var policy = AlertPolicy.standard
        for kind in AlertKind.allCases {
            policy.setBannerEnabled(false, for: kind)
        }
        XCTAssertFalse(policy.anyBannerEnabled)

        policy.setBannerEnabled(true, for: .breakEnded)
        XCTAssertTrue(policy.anyBannerEnabled)
    }

    func testCustomInitializerBuildsPerKindRules() {
        let policy = AlertPolicy(
            masterEnabled: true,
            rules: [
                .focusEnded: AlertPolicy.Rule(bannerEnabled: false, soundEnabled: true),
                .breakEnded: AlertPolicy.Rule(bannerEnabled: true, soundEnabled: false),
                .cycleComplete: AlertPolicy.Rule(bannerEnabled: true, soundEnabled: true)
            ]
        )

        XCTAssertFalse(policy.bannerEnabled(for: .focusEnded))
        XCTAssertTrue(policy.soundEnabled(for: .focusEnded))
        XCTAssertTrue(policy.bannerEnabled(for: .breakEnded))
        XCTAssertFalse(policy.soundEnabled(for: .breakEnded))
    }

    func testRoundTripsThroughJSONCoding() throws {
        var policy = AlertPolicy.standard
        policy.masterEnabled = false
        policy.setBannerEnabled(false, for: .focusEnded)
        policy.setSoundEnabled(false, for: .cycleComplete)

        let data = try JSONEncoder().encode(policy)
        let decoded = try JSONDecoder().decode(AlertPolicy.self, from: data)

        XCTAssertEqual(decoded, policy)
    }
}
