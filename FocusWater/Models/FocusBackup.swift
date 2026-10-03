import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// A portable, versioned backup. CSV is an analysis export, not a full backup.
struct FocusBackup: Codable, Sendable {
    struct Bottle: Codable, Sendable {
        var id: UUID
        var serialNumber: Int
        var capacityMinutes: Int
        var createdAt: Date
        var completedAt: Date?
    }
    struct Session: Codable, Sendable {
        var id: UUID
        var date: Date
        var duration: Int
        var note: String?
        var bottleID: UUID?
        var timerEntryID: UUID?
    }
    struct Preferences: Codable, Sendable {
        var dailyGoalMinutes: Int
        var languageCode: String
        var appearanceMode: String
    }
    var formatVersion = 1
    var application = "FocusWater"
    var exportedAt = Date()
    var bottles: [Bottle]
    var sessions: [Session]
    var preferences: Preferences?

    static let maximumFileBytes = 20 * 1024 * 1024

    func validated() throws -> FocusBackup {
        guard formatVersion == 1, application == "FocusWater", sessions.count <= 100_000, bottles.count <= 100_000,
            Set(sessions.map(\.id)).count == sessions.count,
            Set(bottles.map(\.id)).count == bottles.count
        else { throw BackupError.invalidFormat }
        let bottleIDs = Set(bottles.map(\.id))
        let validDates = Date(timeIntervalSince1970: 0)...Date().addingTimeInterval(86_400)
        for bottle in bottles {
            guard (1...1080).contains(bottle.capacityMinutes), (1...1_000_000).contains(bottle.serialNumber),
                validDates.contains(bottle.createdAt), bottle.completedAt.map(validDates.contains) ?? true
            else {
                throw BackupError.invalidFormat
            }
        }
        var totals: [UUID: Int] = [:]
        for session in sessions {
            guard (1...10_080).contains(session.duration), validDates.contains(session.date),
                (session.note?.count ?? 0) <= 4_000,
                session.bottleID.map(bottleIDs.contains) ?? true
            else { throw BackupError.invalidFormat }
            if let id = session.bottleID { totals[id, default: 0] += session.duration }
        }
        guard bottles.allSatisfy({ totals[$0.id, default: 0] <= $0.capacityMinutes }) else {
            throw BackupError.invalidFormat
        }
        if let preferences {
            guard (60...1080).contains(preferences.dailyGoalMinutes),
                AppLanguage(rawValue: preferences.languageCode) != nil,
                AppAppearanceMode(rawValue: preferences.appearanceMode) != nil
            else { throw BackupError.invalidFormat }
        }
        return self
    }

    func encoded() throws -> Data {
        _ = try validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumFileBytes else { throw BackupError.tooLarge }
        return data
    }

    static func decode(_ data: Data) throws -> FocusBackup {
        guard data.count <= maximumFileBytes else { throw BackupError.tooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try decoder.decode(FocusBackup.self, from: data).validated()
    }

    static func read(from url: URL) throws -> FocusBackup {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return try decode(handle.read(upToCount: maximumFileBytes + 1) ?? Data())
    }

    enum BackupError: Error {
        case invalidFormat, tooLarge, conflictingRecords
    }
}

struct FocusBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        _ = try FocusBackup.decode(data)
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
