import Foundation

/// Storage boundary. The UI only talks to this protocol, so the file store
/// can later be swapped (SwiftData, sync, etc.) without touching views.
public protocol MeetingPersisting: Sendable {
    func loadMeetings() throws -> [Meeting]
    func saveMeetings(_ meetings: [Meeting]) throws
}

public enum MeetingStoreError: Error, LocalizedError, Equatable {
    /// The file could not be decoded. It was moved to `backupURL` so nothing is lost.
    case unreadableArchive(backupURL: URL?)
    /// The file was written by a newer version of the app.
    case unsupportedVersion(Int)

    public var errorDescription: String? {
        switch self {
        case .unreadableArchive(let backupURL):
            if let backupURL {
                return "Your saved meetings could not be read. A copy was kept as \(backupURL.lastPathComponent)."
            }
            return "Your saved meetings could not be read."
        case .unsupportedVersion:
            return "Your meetings were saved by a newer version of MeetingOS. Please update the app."
        }
    }
}

struct MeetingArchive: Codable {
    static let currentVersion = 1
    var version: Int
    var meetings: [Meeting]
}

/// Saves all meetings to one JSON file with atomic writes.
public struct FileMeetingStore: MeetingPersisting {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// `Application Support/MeetingOS/meetings.json` in the app sandbox.
    public static func applicationSupport() throws -> FileMeetingStore {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let url = base
            .appendingPathComponent("MeetingOS", isDirectory: true)
            .appendingPathComponent("meetings.json", isDirectory: false)
        return FileMeetingStore(fileURL: url)
    }

    public func loadMeetings() throws -> [Meeting] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let archive: MeetingArchive
        do {
            archive = try JSONDecoder().decode(MeetingArchive.self, from: data)
        } catch {
            throw MeetingStoreError.unreadableArchive(backupURL: moveAsideUnreadableFile())
        }
        guard archive.version <= MeetingArchive.currentVersion else {
            throw MeetingStoreError.unsupportedVersion(archive.version)
        }
        return archive.meetings
    }

    public func saveMeetings(_ meetings: [Meeting]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(MeetingArchive(version: MeetingArchive.currentVersion, meetings: meetings))
        #if os(iOS)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: fileURL, options: [.atomic])
        #endif
    }

    private func moveAsideUnreadableFile() -> URL? {
        let stamp = Int(Date().timeIntervalSince1970)
        let backup = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("meetings-unreadable-\(stamp).json")
        do {
            try FileManager.default.moveItem(at: fileURL, to: backup)
            return backup
        } catch {
            return nil
        }
    }
}

/// For previews and tests.
public final class InMemoryMeetingStore: MeetingPersisting, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Meeting]
    public private(set) var saveCount = 0

    public init(meetings: [Meeting] = []) {
        self.stored = meetings
    }

    public func loadMeetings() throws -> [Meeting] {
        lock.lock(); defer { lock.unlock() }
        return stored
    }

    public func saveMeetings(_ meetings: [Meeting]) throws {
        lock.lock(); defer { lock.unlock() }
        stored = meetings
        saveCount += 1
    }
}
