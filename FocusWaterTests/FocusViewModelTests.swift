import XCTest
import SwiftData
@testable import FocusWater

@MainActor
final class FocusViewModelTests: XCTestCase {
    private var containers: [ModelContainer] = []

    func testAddFocusSplitsAcrossBottles() throws {
        let viewModel = try makeViewModel(goalMinutes: 120)

        viewModel.addFocus(minutes: 150, note: "Deep work")

        XCTAssertEqual(viewModel.completedBottles.count, 1)
        XCTAssertEqual(viewModel.completedBottles.first?.totalMinutes, 120)
        XCTAssertEqual(viewModel.currentBottle?.serialNumber, 2)
        XCTAssertEqual(viewModel.currentBottle?.totalMinutes, 30)
        XCTAssertEqual(viewModel.allSessions.map(\.duration).reduce(0, +), 150)
    }

    func testChangingGoalDoesNotMislabelExistingBottleCapacity() throws {
        let viewModel = try makeViewModel(goalMinutes: 120)
        viewModel.addFocus(minutes: 30)

        XCTAssertTrue(viewModel.savePreferences(
            hours: 3,
            minutes: 0,
            language: .english,
            appearance: .system
        ))

        XCTAssertEqual(viewModel.dailyGoalMinutes, 180)
        XCTAssertEqual(viewModel.currentBottle?.capacityMinutes, 120)
        XCTAssertEqual(viewModel.currentBottleCapacityText, "2h")
    }

    func testDeletingOnlySessionRemovesEmptyBottle() throws {
        let viewModel = try makeViewModel(goalMinutes: 60)
        viewModel.addFocus(minutes: 60)
        let session = try XCTUnwrap(viewModel.allSessions.first)

        XCTAssertTrue(viewModel.deleteSession(session))

        XCTAssertTrue(viewModel.allSessions.isEmpty)
        XCTAssertTrue(viewModel.completedBottles.isEmpty)
        XCTAssertNil(viewModel.currentBottle)
    }

    func testEditingAndCSVExport() throws {
        let viewModel = try makeViewModel(goalMinutes: 120)
        viewModel.addFocus(minutes: 30, note: "draft")
        let session = try XCTUnwrap(viewModel.allSessions.first)

        XCTAssertTrue(viewModel.updateSession(
            session,
            date: session.date,
            minutes: 45,
            note: "Reading, \"notes\""
        ))

        XCTAssertEqual(viewModel.currentBottle?.totalMinutes, 45)
        XCTAssertTrue(viewModel.exportCSV().contains("\"Reading, \"\"notes\"\"\""))
    }

    func testFailedTimerSaveRetainsRecoverableTime() throws {
        let clock = TestClock()
        let persistence = isolatedTimerPersistence()
        let model = try makeViewModel(goalMinutes: 120, persistence: persistence, clock: clock.value, save: { _ in throw TestError.injected })
        model.startTimer()
        clock.advance(125)
        model.saveTimerFocus()
        XCTAssertEqual(model.timerElapsedSeconds, 125)
        XCTAssertFalse(model.isTimerRunning)
        XCTAssertNotNil(persistence.load())
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(model.allSessions.isEmpty)
        XCTAssertFalse(model.showCompletionAnimation)
    }

    func testTimerKeepsPartialMinuteAndCannotDoubleSave() throws {
        let clock = TestClock()
        let model = try makeViewModel(goalMinutes: 120, clock: clock.value)
        model.startTimer()
        clock.advance(125)
        model.saveTimerFocus()
        XCTAssertEqual(model.totalFocusMinutes, 2)
        XCTAssertEqual(model.timerElapsedSeconds, 5)
        model.saveTimerFocus()
        XCTAssertEqual(model.totalFocusMinutes, 2)
    }

    func testTimerPauseResumeAndBackgroundUseElapsedClock() throws {
        let clock = TestClock()
        let model = try makeViewModel(goalMinutes: 120, clock: clock.value)
        model.startTimer()
        clock.advance(65)
        model.pauseTimer()
        clock.advance(300)
        model.startTimer()
        clock.advance(35)
        model.applicationWillResignActive()
        clock.advance(50)
        model.applicationDidBecomeActive()
        XCTAssertEqual(model.timerElapsedSeconds, 150)
        // Changing wall time within the process must not change elapsed duration.
        clock.date = clock.date.addingTimeInterval(-3_600)
        model.pauseTimer()
        XCTAssertEqual(model.timerElapsedSeconds, 150)
    }

    func testRunningTimerRestoresAfterRelaunch() throws {
        let clock = TestClock()
        let persistence = isolatedTimerPersistence()
        persistence.save(FocusTimerSnapshot(accumulatedSeconds: 40, startedAt: clock.date.addingTimeInterval(-80), isRunning: true, entryID: UUID()))
        let model = try makeViewModel(goalMinutes: 120, persistence: persistence, clock: clock.value)
        XCTAssertEqual(model.timerElapsedSeconds, 120)
        XCTAssertTrue(model.isTimerRunning)
        model.pauseTimer()
    }

    func testStartupFailureDoesNotOverwriteUnloadedTimer() {
        let persistence = isolatedTimerPersistence()
        let snapshot = FocusTimerSnapshot(accumulatedSeconds: 125, startedAt: nil, isRunning: false, entryID: UUID())
        persistence.save(snapshot)
        let unconfigured = FocusViewModel(timerPersistence: persistence)
        unconfigured.applicationWillResignActive()
        XCTAssertEqual(persistence.load(), snapshot)
    }

    func testAbnormallyLongTimerRestoresPausedForReview() throws {
        let clock = TestClock()
        let persistence = isolatedTimerPersistence()
        persistence.save(FocusTimerSnapshot(accumulatedSeconds: 0, startedAt: clock.date.addingTimeInterval(-90_000), isRunning: true))
        let model = try makeViewModel(goalMinutes: 120, persistence: persistence, clock: clock.value)
        XCTAssertFalse(model.isTimerRunning)
        XCTAssertEqual(model.timerElapsedSeconds, 90_000)
        XCTAssertNotNil(model.timerNotice)
    }

    func testReceiptMakesTimerRecordingIdempotent() throws {
        let model = try makeViewModel(goalMinutes: 60)
        let id = UUID()
        XCTAssertTrue(model.addFocus(minutes: 90, timerEntryID: id))
        XCTAssertTrue(model.addFocus(minutes: 90, timerEntryID: id))
        XCTAssertEqual(model.totalFocusMinutes, 90)
        XCTAssertEqual(model.allSessions.count, 2)
    }

    func testRestoreAfterDatabaseCommitDoesNotDuplicateTimer() throws {
        let clock = TestClock()
        let persistence = isolatedTimerPersistence()
        let model = try makeViewModel(goalMinutes: 120, persistence: persistence, clock: clock.value)
        let entryID = UUID()
        XCTAssertTrue(model.addFocus(minutes: 2, timerEntryID: entryID))
        // Simulate termination after the database commit but before preferences clear.
        persistence.save(FocusTimerSnapshot(accumulatedSeconds: 125, startedAt: nil, isRunning: false, entryID: entryID))
        let restored = FocusViewModel(timerPersistence: persistence, clock: clock.value)
        restored.configure(with: try XCTUnwrap(containers.last).mainContext, cloudSyncEnabled: false)
        XCTAssertEqual(restored.timerElapsedSeconds, 5)
        XCTAssertEqual(restored.totalFocusMinutes, 2)
        XCTAssertFalse(restored.isTimerRunning)
    }

    func testRecoveryCleanupFailureRestoresOriginals() throws {
        let directory = try temporaryDirectory()
        let store = directory.appendingPathComponent("test.store")
        let wal = directory.appendingPathComponent("test.store-wal")
        try Data("db".utf8).write(to: store)
        try Data("wal".utf8).write(to: wal)
        let files = FailingCleanupFileManager()
        let coordinator = AppStoreCoordinator(storeURL: store, fileManager: files, userDefaults: isolatedTimerPersistence().userDefaults, loadImmediately: false)
        coordinator.rebuildLocalDatabase()
        XCTAssertEqual(try Data(contentsOf: store), Data("db".utf8))
        XCTAssertEqual(try Data(contentsOf: wal), Data("wal".utf8))
        XCTAssertNotNil(coordinator.lastBackupLocation)
        XCTAssertNotNil(coordinator.recoveryIssue)
    }

    func testCSVNeutralizesFormulaNotes() throws {
        let model = try makeViewModel(goalMinutes: 120)
        model.addFocus(minutes: 5, note: "  =HYPERLINK(\"https://example.com\")")
        XCTAssertTrue(model.exportCSV().contains("'=HYPERLINK"))
        XCTAssertEqual(model.allSessions.first?.note, "=HYPERLINK(\"https://example.com\")")
    }

    func testBackupRoundTripAndRepeatedRestore() throws {
        let source = try makeViewModel(goalMinutes: 120)
        source.addFocus(minutes: 150, note: "Original note")
        let backup = try FocusBackup.decode(source.makeBackup().encoded())
        let destination = try makeViewModel(goalMinutes: 180)
        XCTAssertEqual(try destination.restoreBackup(backup), 2)
        XCTAssertEqual(destination.totalFocusMinutes, 150)
        XCTAssertEqual(try destination.restoreBackup(backup), 0)
        XCTAssertEqual(destination.totalFocusMinutes, 150)
        XCTAssertEqual(destination.dailyGoalMinutes, 180, "Restore must preserve existing preferences")
    }

    func testInvalidBackupIsRejectedWithoutMutation() throws {
        let model = try makeViewModel(goalMinutes: 120)
        model.addFocus(minutes: 30)
        var backup = try model.makeBackup()
        backup.sessions[0].duration = -1
        XCTAssertThrowsError(try model.restoreBackup(backup))
        XCTAssertEqual(model.totalFocusMinutes, 30)
        backup.formatVersion = 99
        XCTAssertThrowsError(try backup.encoded())
        XCTAssertThrowsError(try FocusBackup.decode(Data("not json".utf8)))
    }

    func testBackupFailedSaveRollsBackAllImportedRecords() throws {
        let source = try makeViewModel(goalMinutes: 120)
        source.addFocus(minutes: 150)
        let destination = try makeViewModel(goalMinutes: 120, save: { _ in throw TestError.injected })
        XCTAssertThrowsError(try destination.restoreBackup(source.makeBackup()))
        XCTAssertTrue(destination.allSessions.isEmpty)
        XCTAssertTrue(destination.completedBottles.isEmpty)
        XCTAssertNil(destination.currentBottle)
    }

    func testBackupRejectsDuplicateIDsAndMissingBottle() throws {
        let model = try makeViewModel(goalMinutes: 120)
        model.addFocus(minutes: 30)
        var backup = try model.makeBackup()
        backup.sessions.append(backup.sessions[0])
        XCTAssertThrowsError(try backup.validated())
        backup.sessions.removeLast()
        backup.sessions[0].bottleID = UUID()
        XCTAssertThrowsError(try backup.validated())
    }

    func testFailedPreferenceSaveRestoresVisibleSettings() throws {
        let model = try makeViewModel(goalMinutes: 120, save: { _ in throw TestError.injected })
        XCTAssertFalse(model.savePreferences(hours: 3, minutes: 0, language: .zhHans, appearance: .dark))
        XCTAssertEqual(model.dailyGoalMinutes, 120)
        XCTAssertEqual(model.appLanguage, .english)
    }

    func testStoreFallsBackUsingSameURLAndHonorsLocalPreference() throws {
        let directory = try temporaryDirectory()
        let url = directory.appendingPathComponent("test.store")
        let defaults = isolatedTimerPersistence().userDefaults
        var attempts: [(URL, AppStoreMode)] = []
        let builder: AppStoreCoordinator.ContainerBuilder = { schema, store, mode in
            attempts.append((store, mode))
            if mode == .cloud { throw TestError.injected }
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        }
        let coordinator = AppStoreCoordinator(storeURL: url, userDefaults: defaults, containerBuilder: builder)
        XCTAssertNotNil(coordinator.container)
        XCTAssertFalse(coordinator.cloudSyncEnabled)
        XCTAssertEqual(attempts.map(\.0), [url, url])
        XCTAssertEqual(attempts.map(\.1), [.cloud, .local])
        defaults.set(false, forKey: AppStoreCoordinator.cloudPreferenceKey)
        attempts = []
        let local = AppStoreCoordinator(storeURL: url, userDefaults: defaults, containerBuilder: builder)
        XCTAssertNotNil(local.container)
        XCTAssertEqual(attempts.map(\.1), [.local])
    }

    func testRecoveryBackupContainsEveryOriginalBeforeRebuild() throws {
        let directory = try temporaryDirectory()
        let store = directory.appendingPathComponent("test.store")
        let wal = directory.appendingPathComponent("test.store-wal")
        try Data("database".utf8).write(to: store)
        try Data("pending writes".utf8).write(to: wal)
        let coordinator = AppStoreCoordinator(storeURL: store, userDefaults: isolatedTimerPersistence().userDefaults, containerBuilder: { _, _, _ in throw TestError.injected }, loadImmediately: false)
        coordinator.rebuildLocalDatabase()
        let backup = try XCTUnwrap(coordinator.lastBackupLocation)
        XCTAssertEqual(try Data(contentsOf: backup.appendingPathComponent("test.store")), Data("database".utf8))
        XCTAssertEqual(try Data(contentsOf: backup.appendingPathComponent("test.store-wal")), Data("pending writes".utf8))
        XCTAssertNotNil(coordinator.recoveryIssue)
    }

    func testBackupCopyFailureNeverRemovesOriginalFiles() throws {
        let directory = try temporaryDirectory()
        let store = directory.appendingPathComponent("test.store")
        let wal = directory.appendingPathComponent("test.store-wal")
        try Data("db".utf8).write(to: store)
        try Data("wal".utf8).write(to: wal)
        let files = FailingCopyFileManager()
        let coordinator = AppStoreCoordinator(storeURL: store, fileManager: files, userDefaults: isolatedTimerPersistence().userDefaults, loadImmediately: false)
        coordinator.rebuildLocalDatabase()
        XCTAssertEqual(try Data(contentsOf: store), Data("db".utf8))
        XCTAssertEqual(try Data(contentsOf: wal), Data("wal".utf8))
        XCTAssertNotNil(coordinator.recoveryIssue)
    }

    func testDiagnosticsDoNotExposePathsOrRawErrorContents() throws {
        let path = try temporaryDirectory().appendingPathComponent("test.store")
        let coordinator = AppStoreCoordinator(storeURL: path, userDefaults: isolatedTimerPersistence().userDefaults, containerBuilder: { _, _, _ in
            throw NSError(domain: NSCocoaErrorDomain, code: 1, userInfo: [NSLocalizedDescriptionKey: "private note /Users/private-user/data"])
        })
        let report = coordinator.diagnosticsReport()
        XCTAssertFalse(report.contains("private note"))
        XCTAssertFalse(report.contains("/Users/"))
        XCTAssertFalse(report.contains(path.deletingLastPathComponent().path))
    }

    private func isolatedTimerPersistence() -> FocusTimerPersistence {
        let suite = "FocusWaterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return FocusTimerPersistence(userDefaults: defaults)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("FocusWaterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory
    }

    private func makeViewModel(goalMinutes: Int, persistence: FocusTimerPersistence? = nil, clock: FocusClock = .live,
                               save: @escaping (ModelContext) throws -> Void = { try $0.save() }) throws -> FocusViewModel {
        let schema = Schema([FocusSession.self, WaterBottle.self, FocusSettings.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: configuration)
        containers.append(container)
        let settings = FocusSettings(
            dailyGoalMinutes: goalMinutes,
            languageCode: AppLanguage.english.rawValue,
            appearanceMode: AppAppearanceMode.system.rawValue
        )
        container.mainContext.insert(settings)
        try container.mainContext.save()

        container.mainContext.autosaveEnabled = false
        let viewModel = FocusViewModel(timerPersistence: persistence ?? isolatedTimerPersistence(), clock: clock, saveContext: save)
        viewModel.configure(with: container.mainContext, cloudSyncEnabled: false)
        return viewModel
    }
}

private enum TestError: Error { case injected }

private final class TestClock {
    var date = Date()
    var elapsed: TimeInterval = 0
    var value: FocusClock { FocusClock(now: { self.date }, elapsedTime: { self.elapsed }) }
    func advance(_ seconds: TimeInterval) { date = date.addingTimeInterval(seconds); elapsed += seconds }
}

private final class FailingCopyFileManager: FileManager, @unchecked Sendable {
    private var copies = 0
    override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        copies += 1
        if copies == 2 { throw TestError.injected }
        try super.copyItem(at: srcURL, to: dstURL)
    }
}

private final class FailingCleanupFileManager: FileManager, @unchecked Sendable {
    private var removals = 0
    override func removeItem(at URL: URL) throws {
        removals += 1
        if removals == 2 { throw TestError.injected }
        try super.removeItem(at: URL)
    }
}
