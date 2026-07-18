import Foundation

enum PeonEvent: CaseIterable {
    case sessionStarted
    case focusCompleted
    case backToWork
    case paused
    case abandoned

    /// Filename prefixes (case-insensitive, extension ignored) that map a
    /// user-supplied sound file to this event. Multiple files sharing a prefix
    /// ("work-work-1", "work-work-2") act as random variants.
    var filePrefixes: [String] {
        switch self {
        case .sessionStarted: return ["ready-to-work", "work-work"]
        case .focusCompleted: return ["jobs-done"]
        case .backToWork: return ["more-work", "work-work"]
        case .paused: return ["me-busy"]
        case .abandoned: return ["what"]
        }
    }
}

/// User-supplied easter egg sounds, loaded from a drop-in folder.
///
/// The app ships no audio: the Warcraft peon lines are copyrighted, so the user
/// provides their own files and the feature stays dormant until any exist.
struct PeonSoundPack {
    static let supportedExtensions: Set<String> = ["wav", "mp3", "m4a", "aiff"]

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pomodoro/PeonSounds", isDirectory: true)
    }

    private let soundURLs: [URL]

    init(directory: URL = PeonSoundPack.defaultDirectory) {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        soundURLs = contents
            .filter { Self.supportedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    var isEmpty: Bool { soundURLs.isEmpty }
    var soundCount: Int { soundURLs.count }

    func url(for event: PeonEvent, choosing: ([URL]) -> URL? = { $0.randomElement() }) -> URL? {
        let matches = soundURLs.filter { url in
            let name = url.deletingPathExtension().lastPathComponent.lowercased()
            return event.filePrefixes.contains { name.hasPrefix($0) }
        }
        return choosing(matches)
    }
}
