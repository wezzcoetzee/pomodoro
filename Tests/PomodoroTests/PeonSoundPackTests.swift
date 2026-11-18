import XCTest

@testable import Pomodoro

final class PeonSoundPackTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PeonSoundPackTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempDir)
    }

    private func touch(_ name: String) throws {
        try Data().write(to: tempDir.appendingPathComponent(name))
    }

    func testMatchesEventsByFilenamePrefix() throws {
        try touch("jobs-done.wav")
        try touch("me-busy.m4a")
        try touch("What.mp3")

        let pack = PeonSoundPack(directory: tempDir)

        XCTAssertEqual(pack.url(for: .focusCompleted)?.lastPathComponent, "jobs-done.wav")
        XCTAssertEqual(pack.url(for: .paused)?.lastPathComponent, "me-busy.m4a")
        XCTAssertEqual(pack.url(for: .abandoned)?.lastPathComponent, "What.mp3")
        XCTAssertNil(pack.url(for: .sessionStarted))
    }

    func testWorkWorkServesBothStartAndBackToWork() throws {
        try touch("work-work-1.wav")
        try touch("work-work-2.wav")

        let pack = PeonSoundPack(directory: tempDir)
        let first = { (urls: [URL]) -> URL? in urls.first }

        XCTAssertEqual(pack.url(for: .sessionStarted, choosing: first)?.lastPathComponent, "work-work-1.wav")
        XCTAssertEqual(pack.url(for: .backToWork, choosing: first)?.lastPathComponent, "work-work-1.wav")
        XCTAssertEqual(pack.soundCount, 2)
    }

    func testReadyToWorkPreferredNamingAlsoMatchesSessionStart() throws {
        try touch("ready-to-work.aiff")

        let pack = PeonSoundPack(directory: tempDir)

        XCTAssertEqual(pack.url(for: .sessionStarted)?.lastPathComponent, "ready-to-work.aiff")
    }

    func testIgnoresUnsupportedExtensions() throws {
        try touch("jobs-done.txt")
        try touch("jobs-done.pdf")

        let pack = PeonSoundPack(directory: tempDir)

        XCTAssertTrue(pack.isEmpty)
        XCTAssertNil(pack.url(for: .focusCompleted))
    }

    func testMissingDirectoryYieldsEmptyPack() {
        let pack = PeonSoundPack(directory: tempDir.appendingPathComponent("does-not-exist"))

        XCTAssertTrue(pack.isEmpty)
        XCTAssertNil(pack.url(for: .focusCompleted))
    }
}
