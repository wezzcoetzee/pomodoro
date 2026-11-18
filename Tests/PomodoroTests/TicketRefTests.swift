import XCTest

@testable import Pomodoro

final class TicketRefTests: XCTestCase {
    private struct AcceptCase {
        let input: String
        let kind: TicketKind
        let displayBadge: String
        let deepLink: String
    }

    private static let acceptCases: [AcceptCase] = [
        AcceptCase(input: "IV-123", kind: .jira, displayBadge: "IV-123", deepLink: "https://idexx.atlassian.net/browse/IV-123"),
        AcceptCase(input: "ABC-9", kind: .jira, displayBadge: "ABC-9", deepLink: "https://idexx.atlassian.net/browse/ABC-9"),
        AcceptCase(input: "  IV-123  ", kind: .jira, displayBadge: "IV-123", deepLink: "https://idexx.atlassian.net/browse/IV-123"),
        AcceptCase(
            input: "https://idexx.atlassian.net/browse/IV-123",
            kind: .jira,
            displayBadge: "IV-123",
            deepLink: "https://idexx.atlassian.net/browse/IV-123"
        ),
        AcceptCase(
            input: "https://someother.atlassian.net/browse/ABC-9",
            kind: .jira,
            displayBadge: "ABC-9",
            deepLink: "https://someother.atlassian.net/browse/ABC-9"
        ),
        AcceptCase(
            input: "https://someother.atlassian.net/browse/ABC-9/",
            kind: .jira,
            displayBadge: "ABC-9",
            deepLink: "https://someother.atlassian.net/browse/ABC-9/"
        ),
        AcceptCase(
            input: "https://github.com/owner/repo/issues/123",
            kind: .github,
            displayBadge: "repo#123",
            deepLink: "https://github.com/owner/repo/issues/123"
        ),
        AcceptCase(
            input: "https://github.com/owner/repo/pull/45",
            kind: .github,
            displayBadge: "repo#45",
            deepLink: "https://github.com/owner/repo/pull/45"
        ),
        AcceptCase(
            input: "https://github.com/owner/repo/issues/123/",
            kind: .github,
            displayBadge: "repo#123",
            deepLink: "https://github.com/owner/repo/issues/123/"
        ),
        AcceptCase(
            input: "owner/repo#123",
            kind: .github,
            displayBadge: "repo#123",
            deepLink: "https://github.com/owner/repo/issues/123"
        ),
        AcceptCase(
            input: "my-org/my-repo#7",
            kind: .github,
            displayBadge: "my-repo#7",
            deepLink: "https://github.com/my-org/my-repo/issues/7"
        ),
    ]

    private static let rejectCases: [String] = [
        "",
        "   ",
        "hello",
        "world of focus",
        "123",
        "123-456",
        "iv-123",
        "https://example.com/foo",
        "https://example.com/browse/IV-123",
        "https://jira.example.com/browse/IV-123",
        "https://github.com/owner/repo",
        "https://github.com/owner/repo/issues",
        "https://github.com/owner/repo/issues/abc",
        "owner/repo",
        "owner/repo#",
        "owner#123",
        "IV123",
        "-123",
    ]

    func testAcceptedInputsParseCorrectly() {
        for testCase in Self.acceptCases {
            guard let ticket = TicketRefParser.parse(testCase.input) else {
                XCTFail("Expected \(testCase.input) to parse")
                continue
            }
            XCTAssertEqual(ticket.kind, testCase.kind, "kind mismatch for \(testCase.input)")
            XCTAssertEqual(ticket.displayBadge, testCase.displayBadge, "displayBadge mismatch for \(testCase.input)")
            XCTAssertEqual(ticket.deepLink, URL(string: testCase.deepLink), "deepLink mismatch for \(testCase.input)")
        }
    }

    func testRejectedInputsReturnNil() {
        for input in Self.rejectCases {
            XCTAssertNil(TicketRefParser.parse(input), "Expected \(input) to be rejected")
        }
    }
}
