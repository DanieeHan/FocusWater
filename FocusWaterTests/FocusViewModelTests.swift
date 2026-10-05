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

    func testSuccessfulTimerSaveReplacesSnapshotWithoutClearingRemainder() throws {
        let suite = "FocusWaterTests.\(UUID().uuidString)"
        let defaults = TrackingTimerDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let persistence = FocusTimerPersistence(userDefaults: defaults)
        let clock = TestClock()
        let model = try makeViewModel(goalMinutes: 120, persistence: persistence, clock: clock.value)
        model.startTimer()
        clock.advance(125)
        model.saveTimerFocus()

        XCTAssertTrue(defaults.clearedKeys.isEmpty, "A successful save must not clear the receipt before replacing its remainder")
        XCTAssertEqual(persistence.load()?.accumulatedSeconds, 5)
        model.resetTimer()
        XCTAssertEqual(defaults.clearedKeys, [FocusTimerPersistence.defaultKey])
    }

    func testCrossMidnightTimerRecordsBothDays() throws {
        let calendar = Calendar.current
        let start = localDate(day: 1, hour: 23, minute: 30)
        let clock = TestClock(date: start)
        let model = try makeViewModel(goalMinutes: 120, clock: clock.value)
        model.startTimer()
        clock.advance(3_600)
        model.saveTimerFocus()

        let sessions = model.allSessions.sorted { $0.date < $1.date }
        XCTAssertEqual(sessions.map(\.duration), [30, 30])
        XCTAssertTrue(calendar.isDate(sessions[0].date, inSameDayAs: start))
        XCTAssertTrue(calendar.isDate(sessions[1].date, inSameDayAs: clock.date))
        XCTAssertEqual(model.totalFocusMinutes, 60)
    }

    func testMidnightRoundingAllowsSavingSixtySeconds() throws {
        let start = localDate(day: 1, hour: 23, minute: 59, second: 30)
        let clock = TestClock(date: start)
        let model = try makeViewModel(goalMinutes: 120, clock: clock.value)
        model.startTimer()
        clock.advance(60)
        model.saveTimerFocus()

        XCTAssertEqual(model.totalFocusMinutes, 1)
        XCTAssertEqual(model.timerElapsedSeconds, 0)
        XCTAssertTrue(Calendar.current.isDate(try XCTUnwrap(model.allSessions.first).date, inSameDayAs: clock.date),
                      "Equal daily remainders round toward the later day")
    }

    func testPausedTimerSavedLaterKeepsOriginalFocusDates() throws {
        let start = localDate(day: 1, hour: 10)
        let clock = TestClock(date: start)
        let model = try makeViewModel(goalMinutes: 120, clock: clock.value)
        model.startTimer()
        clock.advance(65)
        model.pauseTimer()
        clock.advance(86_400)
        model.saveTimerFocus()

        XCTAssertEqual(model.totalFocusMinutes, 1)
        XCTAssertEqual(model.timerElapsedSeconds, 5)
        XCTAssertEqual(try XCTUnwrap(model.allSessions.first).date, start)
    }

    func testPausedMidnightTimerRestoresSegmentsWithoutCountingPause() throws {
        let start = localDate(day: 1, hour: 23, minute: 58, second: 58)
        let clock = TestClock(date: start)
        let persistence = isolatedTimerPersistence()
        let model = try makeViewModel(goalMinutes: 120, persistence: persistence, clock: clock.value)
        model.startTimer()
        clock.advance(62)
        model.pauseTimer()
        clock.advance(300)
        model.startTimer()
        clock.advance(63)
        model.pauseTimer()

        let restored = FocusViewModel(timerPersistence: persistence, clock: clock.value)
        restored.configure(with: try XCTUnwrap(containers.last).mainContext, cloudSyncEnabled: false)
        restored.saveTimerFocus()

        XCTAssertEqual(restored.allSessions.sorted { $0.date < $1.date }.map(\.duration), [1, 1])
        XCTAssertEqual(restored.totalFocusMinutes, 2)
        XCTAssertEqual(restored.timerElapsedSeconds, 5)
        let remainder = try XCTUnwrap(persistence.load()?.intervals?.first)
        XCTAssertEqual(remainder.startedAt, clock.date.addingTimeInterval(-5))
    }

    func testCrossMidnightFailedSaveCanRetryWithoutLosingDates() throws {
        let clock = TestClock(date: localDate(day: 1, hour: 23, minute: 30))
        let persistence = isolatedTimerPersistence()
        var shouldFail = true
        let model = try makeViewModel(goalMinutes: 120, persistence: persistence, clock: clock.value, save: {
            if shouldFail { throw TestError.injected }
            try $0.save()
        })
        model.startTimer()
        clock.advance(3_605)
        model.saveTimerFocus()
        XCTAssertTrue(model.allSessions.isEmpty)
        XCTAssertEqual(model.timerElapsedSeconds, 3_605)
        XCTAssertEqual(persistence.load()?.intervals?.count, 1)

        shouldFail = false
        model.saveTimerFocus()
        XCTAssertEqual(model.allSessions.sorted { $0.date < $1.date }.map(\.duration), [30, 30])
        XCTAssertEqual(model.timerElapsedSeconds, 5)
    }

    func testCrossMidnightCommitRecoveryConsumesOnlySavedPrefix() throws {
        let clock = TestClock(date: localDate(day: 1, hour: 23, minute: 30))
        let persistence = isolatedTimerPersistence()
        let model = try makeViewModel(goalMinutes: 120, persistence: persistence, clock: clock.value)
        model.startTimer()
        clock.advance(3_605)
        model.pauseTimer()
        let beforeCommit = try XCTUnwrap(persistence.load())
        model.saveTimerFocus()
        // Restore the snapshot left behind by termination immediately after commit.
        persistence.save(beforeCommit)
        let restored = FocusViewModel(timerPersistence: persistence, clock: clock.value)
        restored.configure(with: try XCTUnwrap(containers.last).mainContext, cloudSyncEnabled: false)

        XCTAssertEqual(restored.totalFocusMinutes, 60)
        XCTAssertEqual(restored.timerElapsedSeconds, 5)
        XCTAssertEqual(try XCTUnwrap(persistence.load()?.intervals?.first).startedAt, clock.date.addingTimeInterval(-5))
        restored.startTimer()
        clock.advance(55)
        restored.saveTimerFocus()
        XCTAssertEqual(restored.totalFocusMinutes, 61)
        XCTAssertEqual(restored.timerElapsedSeconds, 0)
    }

    func testFractionalSecondsSurvivePauseAndSnapshot() throws {
        let clock = TestClock(date: localDate(day: 1, hour: 10))
        let persistence = isolatedTimerPersistence()
        let model = try makeViewModel(goalMinutes: 120, persistence: persistence, clock: clock.value)
        model.startTimer()
        clock.advance(0.25)
        model.pauseTimer()
        XCTAssertNotNil(persistence.load())
        let restored = FocusViewModel(timerPersistence: persistence, clock: clock.value)
        restored.configure(with: try XCTUnwrap(containers.last).mainContext, cloudSyncEnabled: false)
        restored.startTimer()
        clock.advance(59.75)
        restored.saveTimerFocus()
        XCTAssertEqual(restored.totalFocusMinutes, 1)
        XCTAssertEqual(restored.timerElapsedSeconds, 0)
    }

    func testEditingHistoricalBottleDoesNotRedirectCurrentOrNextBottle() throws {
        let model = try makeViewModel(goalMinutes: 60)
        model.addFocus(minutes: 150)
        let oldSession = try XCTUnwrap(model.allSessions.first { $0.bottle?.serialNumber == 1 })
        XCTAssertTrue(model.updateSession(oldSession, date: oldSession.date, minutes: 45, note: nil))
        XCTAssertEqual(model.currentBottle?.serialNumber, 3)
        XCTAssertEqual(model.currentBottle?.totalMinutes, 30)
        model.addFocus(minutes: 30)
        XCTAssertNil(model.currentBottle)
        model.addFocus(minutes: 5)
        XCTAssertEqual(model.currentBottle?.serialNumber, 4)
        XCTAssertEqual(oldSession.bottle?.totalMinutes, 45)
    }

    func testDeletingHistoricalSessionDoesNotRedirectCurrentBottle() throws {
        let model = try makeViewModel(goalMinutes: 60)
        model.addFocus(minutes: 30)
        model.addFocus(minutes: 120)
        let oldSession = try XCTUnwrap(model.allSessions.first { $0.bottle?.serialNumber == 1 })
        XCTAssertTrue(model.deleteSession(oldSession))
        XCTAssertEqual(model.currentBottle?.serialNumber, 3)
        model.addFocus(minutes: 10)
        XCTAssertEqual(model.currentBottle?.totalMinutes, 40)
    }

    func testDeletingLatestBottleFallsBackToLatestSurvivor() throws {
        let model = try makeViewModel(goalMinutes: 60)
        model.addFocus(minutes: 150)
        let historical = try XCTUnwrap(model.allSessions.first { $0.bottle?.serialNumber == 1 })
        XCTAssertTrue(model.updateSession(historical, date: historical.date, minutes: 45, note: nil))
        let latest = try XCTUnwrap(model.allSessions.first { $0.bottle?.serialNumber == 3 })
        XCTAssertTrue(model.deleteSession(latest))
        // Bottle 2 is completed; the reopened older bottle must not take over.
        XCTAssertNil(model.currentBottle)
        model.addFocus(minutes: 5)
        XCTAssertEqual(model.currentBottle?.serialNumber, 3)
        XCTAssertEqual(historical.bottle?.totalMinutes, 45)

        let unfinished = try makeViewModel(goalMinutes: 60)
        unfinished.addFocus(minutes: 150)
        let previous = try XCTUnwrap(unfinished.allSessions.first { $0.bottle?.serialNumber == 2 })
        XCTAssertTrue(unfinished.updateSession(previous, date: previous.date, minutes: 40, note: nil))
        let final = try XCTUnwrap(unfinished.allSessions.first { $0.bottle?.serialNumber == 3 })
        XCTAssertTrue(unfinished.deleteSession(final))
        XCTAssertEqual(unfinished.currentBottle?.serialNumber, 2)
        unfinished.addFocus(minutes: 5)
        XCTAssertEqual(unfinished.currentBottle?.totalMinutes, 45)
    }

    func testDiskStoreReopenPreservesDatesReceiptsAndCurrentBottle() throws {
        let directory = try temporaryDirectory()
        let storeURL = directory.appendingPathComponent("reopen.store")
        let schema = AppStoreCoordinator.makeSchema()
        let configuration = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        let clock = TestClock(date: localDate(day: 1, hour: 23, minute: 30))
        let persistence = isolatedTimerPersistence()
        var savedSnapshot: FocusTimerSnapshot?
        var savedSessions: [(UUID, Date, Int)] = []
        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            container.mainContext.autosaveEnabled = false
            container.mainContext.insert(FocusSettings(dailyGoalMinutes: 60,
                languageCode: AppLanguage.english.rawValue, appearanceMode: AppAppearanceMode.system.rawValue))
            try container.mainContext.save()
            let model = FocusViewModel(timerPersistence: persistence, clock: clock.value)
            model.configure(with: container.mainContext, cloudSyncEnabled: false)
            model.startTimer()
            clock.advance(3_605)
            model.pauseTimer()
            savedSnapshot = try XCTUnwrap(persistence.load())
            model.saveTimerFocus()
            model.addFocus(minutes: 5, note: "Disk round trip")
            savedSessions = model.allSessions.map { ($0.id, $0.date, $0.duration) }
        }
        // Simulate termination after the database commit but before snapshot replacement.
        persistence.save(try XCTUnwrap(savedSnapshot))
        let reopened = try ModelContainer(for: schema, configurations: configuration)
        containers.append(reopened)
        reopened.mainContext.autosaveEnabled = false
        let restored = FocusViewModel(timerPersistence: persistence, clock: clock.value)
        restored.configure(with: reopened.mainContext, cloudSyncEnabled: false)
        XCTAssertEqual(restored.totalFocusMinutes, 65)
        XCTAssertEqual(restored.timerElapsedSeconds, 5)
        XCTAssertFalse(restored.isTimerRunning)
        XCTAssertEqual(restored.currentBottle?.serialNumber, 2)
        XCTAssertEqual(restored.currentBottle?.totalMinutes, 5)
        XCTAssertEqual(restored.allSessions.count, savedSessions.count)
        for (id, date, minutes) in savedSessions {
            let session = try XCTUnwrap(restored.allSessions.first { $0.id == id })
            XCTAssertEqual(session.date, date)
            XCTAssertEqual(session.duration, minutes)
        }
        XCTAssertEqual(restored.allSessions.filter { $0.timerEntryID != nil }.count, 2)
        XCTAssertEqual(restored.allSessions.first { $0.note != nil }?.note, "Disk round trip")
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

    private func localDate(day: Int, hour: Int, minute: Int = 0, second: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: day,
                                                   hour: hour, minute: minute, second: second))!
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

private final class TrackingTimerDefaults: UserDefaults, @unchecked Sendable {
    var clearedKeys: [String] = []
    override func removeObject(forKey defaultName: String) {
        clearedKeys.append(defaultName)
        super.removeObject(forKey: defaultName)
    }
}

private final class TestClock {
    var date: Date
    var elapsed: TimeInterval = 0
    init(date: Date = Date()) { self.date = date }
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
