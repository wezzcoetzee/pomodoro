import Foundation

enum TicketKind: String, Codable {
    case jira
    case github
    case none
}

struct TicketRef: Equatable {
    let raw: String
    let kind: TicketKind
    let displayBadge: String
    let deepLink: URL?
}

enum TicketRefParser {
    static let defaultJiraBaseURL = "https://idexx.atlassian.net"

    private static let jiraKeyPattern = "^[A-Z][A-Z0-9]*-[0-9]+$"
    private static let jiraBrowseURLPattern = "^https://[A-Za-z0-9.-]+\\.atlassian\\.net/browse/([A-Z][A-Z0-9]*-[0-9]+)/?$"
    private static let githubURLPattern = "^https://github\\.com/([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)/(?:issues|pull)/([0-9]+)/?$"
    private static let githubShorthandPattern = "^([A-Za-z0-9._-]+)/([A-Za-z0-9._-]+)#([0-9]+)$"

    static func parse(_ input: String) -> TicketRef? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let key = firstMatch(jiraKeyPattern, in: trimmed) {
            return TicketRef(
                raw: trimmed,
                kind: .jira,
                displayBadge: key,
                deepLink: URL(string: "\(defaultJiraBaseURL)/browse/\(key)")
            )
        }

        if let key = capturedGroups(jiraBrowseURLPattern, in: trimmed, count: 1)?[0] {
            return TicketRef(
                raw: trimmed,
                kind: .jira,
                displayBadge: key,
                deepLink: URL(string: trimmed)
            )
        }

        if let groups = capturedGroups(githubURLPattern, in: trimmed, count: 3) {
            let repo = groups[1]
            let number = groups[2]
            return TicketRef(
                raw: trimmed,
                kind: .github,
                displayBadge: "\(repo)#\(number)",
                deepLink: URL(string: trimmed)
            )
        }

        if let groups = capturedGroups(githubShorthandPattern, in: trimmed, count: 3) {
            let owner = groups[0]
            let repo = groups[1]
            let number = groups[2]
            return TicketRef(
                raw: trimmed,
                kind: .github,
                displayBadge: "\(repo)#\(number)",
                deepLink: URL(string: "https://github.com/\(owner)/\(repo)/issues/\(number)")
            )
        }

        return nil
    }

    private static func firstMatch(_ pattern: String, in string: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, range: range),
              let matchRange = Range(match.range, in: string) else { return nil }
        return String(string[matchRange])
    }

    private static func capturedGroups(_ pattern: String, in string: String, count: Int) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, range: range), match.numberOfRanges > count else { return nil }
        var result: [String] = []
        for i in 1...count {
            guard let groupRange = Range(match.range(at: i), in: string) else { return nil }
            result.append(String(string[groupRange]))
        }
        return result
    }
}
