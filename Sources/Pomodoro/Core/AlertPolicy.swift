import Foundation

struct AlertPolicy: Equatable, Codable {
    struct Rule: Equatable, Codable {
        var bannerEnabled: Bool
        var soundEnabled: Bool

        static let allEnabled = Rule(bannerEnabled: true, soundEnabled: true)
    }

    var masterEnabled: Bool
    private var rulesByKind: [String: Rule]

    init(masterEnabled: Bool, rules: [AlertKind: Rule]) {
        self.masterEnabled = masterEnabled
        self.rulesByKind = Dictionary(uniqueKeysWithValues: rules.map { ($0.key.rawValue, $0.value) })
    }

    static let standard = AlertPolicy(
        masterEnabled: true,
        rules: Dictionary(uniqueKeysWithValues: AlertKind.allCases.map { ($0, .allEnabled) })
    )

    func rule(for kind: AlertKind) -> Rule {
        rulesByKind[kind.rawValue] ?? .allEnabled
    }

    func bannerEnabled(for kind: AlertKind) -> Bool {
        masterEnabled && rule(for: kind).bannerEnabled
    }

    func soundEnabled(for kind: AlertKind) -> Bool {
        rule(for: kind).soundEnabled
    }

    var anyBannerEnabled: Bool {
        AlertKind.allCases.contains { rule(for: $0).bannerEnabled }
    }

    mutating func setBannerEnabled(_ enabled: Bool, for kind: AlertKind) {
        rulesByKind[kind.rawValue, default: .allEnabled].bannerEnabled = enabled
    }

    mutating func setSoundEnabled(_ enabled: Bool, for kind: AlertKind) {
        rulesByKind[kind.rawValue, default: .allEnabled].soundEnabled = enabled
    }
}
